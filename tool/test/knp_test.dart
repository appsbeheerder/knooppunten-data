import 'dart:convert';
import 'dart:io';

import 'package:knooppunten_tool/knp.dart';
import 'package:knooppunten_tool/opl.dart';
import 'package:knooppunten_tool/polyline.dart';
import 'package:knooppunten_tool/src/data/osm_network_parser.dart';
import 'package:knooppunten_tool/src/domain/connection.dart';
import 'package:knooppunten_tool/src/domain/cycle_network.dart';
import 'package:knooppunten_tool/src/domain/junction.dart';
import 'package:knooppunten_tool/src/domain/geo_point.dart';
import 'package:knooppunten_tool/src/domain/route_engine.dart';
import 'package:test/test.dart';

Future<CycleNetwork> miniNetwork() async {
  final json = await oplToOverpassJson(
    routesOpl: 'test/fixtures/mini.rcn.opl',
    nodesOpl: 'test/fixtures/mini.nodes.opl',
  );
  return OsmNetworkParser().parse(nodesJson: json.nodes, routesJson: json.routes);
}

double totalMeters(CycleNetwork n) {
  final seen = <Object>{};
  var m = 0.0;
  for (final j in n.junctions.values) {
    for (final c in n.connectionsAt(j.id)) {
      if (seen.add(c)) m += c.distanceMeters;
    }
  }
  return m;
}

void main() {
  group('polyline', () {
    test('standaardvoorbeeld van Google (precisie 5)', () {
      const points = [
        GeoPoint(38.5, -120.2),
        GeoPoint(40.7, -120.95),
        GeoPoint(43.252, -126.453),
      ];
      expect(encodePolyline(points, precision: 5), '_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      final back = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
      expect(back.length, 3);
      expect(back[2].lat, closeTo(43.252, 1e-9));
      expect(back[2].lon, closeTo(-126.453, 1e-9));
    });

    test('rondreis met precisie 6, ook negatieve en lege lijst', () {
      const points = [GeoPoint(52.123456, 5.654321), GeoPoint(52.123999, 5.600001), GeoPoint(-33.8, 151.2)];
      final back = decodePolyline(encodePolyline(points));
      for (var i = 0; i < points.length; i++) {
        expect(back[i].lat, closeTo(points[i].lat, 1e-6));
        expect(back[i].lon, closeTo(points[i].lon, 1e-6));
      }
      expect(decodePolyline(''), isEmpty);
    });

    test('ongeldige tekst geeft een FormatException', () {
      expect(() => decodePolyline('_p~iF~ps|'), throwsFormatException);
      expect(() => decodePolyline('\u0001\u0002'), throwsFormatException);
    });
  });

  group('OPL en netwerk', () {
    test('twee knooppuntverbindingen; themaroute zonder nummers wordt overgeslagen', () async {
      final n = await miniNetwork();
      expect(n.junctions.length, 3);
      final a = n.withNumber('01').single.id, b = n.withNumber('02').single.id;
      final c = n.directConnection(a, b)!;
      expect(c.distanceMeters, closeTo(685, 5)); // 0,01 graad lengte op 52 NB
      expect(n.directConnection(b, n.withNumber('03').single.id)!.distanceMeters, closeTo(1112, 5));
    });
  });

  group('pakket', () {
    test('rondreis: bouwen, inpakken, uitpakken en vergelijken', () async {
      final n = await miniNetwork();
      final pkg = buildPackage(n,
          region: 'test', bbox: [51.9, 4.9, 52.1, 5.1], osmTimestamp: '2026-01-01T00:00:00Z');
      final back = readPackageBytes(packageToBytes(pkg));
      expect(back.region, 'test');
      expect(back.network.junctions.length, 3);
      expect(totalMeters(back.network), closeTo(totalMeters(n), totalMeters(n) * 0.001));
      final engine = RouteEngine(back.network);
      final r = engine.fromNumbers(['01', '02', '03']);
      expect(r.junctionNumbers, ['01', '02', '03']);
    });

    test('uitvoer is deterministisch', () async {
      final n = await miniNetwork();
      String make() => jsonEncode(buildPackage(n,
          region: 'test', bbox: [51.9, 4.9, 52.1, 5.1], osmTimestamp: 't'));
      expect(make(), make());
    });

    test('verbindingen met een naam als nummer worden overgeslagen en gemeld', () {
      const a = GeoPoint(52.0, 5.0), b = GeoPoint(52.0, 5.01), c = GeoPoint(52.0, 5.02);
      Connection conn(int x, int y, String nx, String ny, GeoPoint p, GeoPoint q) => Connection(
          fromId: x, toId: y, fromNumber: nx, toNumber: ny, segments: [[p, q]]);
      final n = CycleNetwork(
        junctions: [
          const Junction(id: 1, number: '01', location: a),
          const Junction(id: 2, number: '02', location: b),
          const Junction(id: 3, number: 'GrootStokkert', location: c),
        ],
        connections: [conn(1, 2, '01', '02', a, b), conn(2, 3, '02', 'GrootStokkert', b, c)],
      );
      final skipped = <String>[];
      final pkg = buildPackage(n,
          region: 'x', bbox: [51, 4, 53, 6], osmTimestamp: 't', onSkipped: skipped.add);
      expect((pkg['connections'] as List).length, 1);
      expect((pkg['junctions'] as List).length, 2);
      expect(skipped, ['GrootStokkert']);
      expect(readPackage(pkg).network.junctions.length, 2);
    });

    test('een regio buiten het netwerk is leeg', () async {
      final n = await miniNetwork();
      final pkg = buildPackage(n, region: 'leeg', bbox: [10, 10, 11, 11], osmTimestamp: 't');
      expect(pkg['connections'], isEmpty);
      expect(pkg['junctions'], isEmpty);
    });

    test('een regio die één verbinding raakt, bevat alleen die en haar knooppunten', () async {
      final n = await miniNetwork();
      final pkg = buildPackage(n,
          region: 'deel', bbox: [51.995, 4.995, 52.005, 5.007], osmTimestamp: 't');
      expect((pkg['connections'] as List).length, 1);
      expect((pkg['junctions'] as List).length, 2);
    });
  });

  group('inlezen wijst ongeldige pakketten af', () {
    Map<String, dynamic> valid() => {
          'format': 1,
          'region': 'x',
          'network': 'rcn',
          'osmTimestamp': 't',
          'bbox': [51.0, 4.0, 53.0, 6.0],
          'junctions': [
            [1, '01', 52.0, 5.0],
            [2, '02', 52.0, 5.01],
          ],
          'connections': [
            [1, 2, '01', '02', [encodePolyline(const [GeoPoint(52.0, 5.0), GeoPoint(52.0, 5.01)])]],
          ],
        };

    test('het voorbeeld zelf is geldig', () {
      expect(readPackage(valid()).network.junctions.length, 2);
    });

    test('onbekend formaat', () {
      expect(() => readPackage({...valid(), 'format': 2}), throwsFormatException);
    });

    test('verbinding naar onbekend knooppunt', () {
      final p = valid();
      (p['connections'] as List)[0][1] = 99;
      expect(() => readPackage(p), throwsFormatException);
    });

    test('coördinaat buiten bereik', () {
      final p = valid();
      (p['junctions'] as List)[0][2] = 95.0;
      expect(() => readPackage(p), throwsFormatException);
    });

    test('ontbrekend veld, verkeerd type en geen object', () {
      final p = valid()..remove('junctions');
      expect(() => readPackage(p), throwsFormatException);
      expect(() => readPackage(valid()..['region'] = 5), throwsFormatException);
      expect(() => readPackage([1, 2]), throwsFormatException);
    });

    test('te grote uitgepakte omvang wordt geweigerd', () {
      final bytes = packageToBytes(valid());
      expect(() => readPackageBytes(bytes, maxUnpackedBytes: 50), throwsFormatException);
    });

    test('geen gzip', () {
      expect(() => readPackageBytes(utf8.encode('{}')), throwsFormatException);
    });
  });

  // Alleen met een met osmium gemaakte uitsnede; zie README.
  final dir = Platform.environment['KNP_UTRECHT_DIR'];
  group('Utrecht (echte data)', () {
    test('aantallen en routes kloppen met de app', () async {
      final json = await oplToOverpassJson(
        routesOpl: '$dir/rcn.opl',
        nodesOpl: '$dir/nodes.opl',
      );
      final n = OsmNetworkParser().parse(nodesJson: json.nodes, routesJson: json.routes);
      expect(n.junctions.length, 732);
      final pkg = buildPackage(n,
          region: 'nl-utrecht', bbox: [51.85, 4.79, 52.31, 5.63], osmTimestamp: 't');
      final back = readPackageBytes(packageToBytes(pkg)).network;
      expect(totalMeters(back), closeTo(totalMeters(n), totalMeters(n) * 0.001));

      GeoPoint at = const GeoPoint(52.05, 5.31);
      List<int> resolve(List<String> numbers) {
        final ids = <int>[];
        for (final num in numbers) {
          final j = back.withNumber(num).reduce(
              (x, y) => x.location.distanceTo(at) <= y.location.distanceTo(at) ? x : y);
          ids.add(j.id);
          at = j.location;
        }
        return ids;
      }

      final engine = RouteEngine(back);
      final two = resolve(['03', '61']);
      expect(engine.shortestPath(two[0], two[1]).totalMeters / 1000, closeTo(8.66, 0.05));
      at = const GeoPoint(52.05, 5.31);
      final anwb = '61-09-08-10-52-69-65-42-49-40-85-16-65-52-10-08-61'.split('-');
      expect(engine.fromJunctions(resolve(anwb)).totalMeters / 1000, closeTo(41.75, 0.1));
    }, skip: dir == null ? 'KNP_UTRECHT_DIR niet ingesteld' : false);
  });
}
