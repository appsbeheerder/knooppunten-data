import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'polyline.dart';
import 'src/domain/connection.dart';
import 'src/domain/cycle_network.dart';
import 'src/domain/geo_point.dart';
import 'src/domain/junction.dart';

/// Versie van het pakketformaat (zie docs/FORMAT.md).
const knpFormat = 1;

/// Een ingelezen pakket.
class KnpPackage {
  KnpPackage({
    required this.region,
    required this.network,
    required this.osmTimestamp,
    required this.bbox,
    required this.networkType,
  });

  final String region;
  final CycleNetwork network;
  final String osmTimestamp;

  /// [zuid, west, noord, oost]
  final List<double> bbox;

  /// Bijvoorbeeld `rcn`.
  final String networkType;
}

/// Een geldig knooppuntnummer: 1 tot 10 letters of cijfers.
bool isValidNumber(String n) => RegExp(r'^[A-Za-z0-9]{1,10}$').hasMatch(n);

/// Bouwt het pakket voor één regio: de verbindingen die [bbox] raken en hun
/// knooppunten. De uitvoer is deterministisch (vaste volgorde).
///
/// Verbindingen waarvan een nummer geen geldig knooppuntnummer is (zie [isValidNumber];
/// in OSM staan soms namen in `rcn_ref`) worden overgeslagen en aan [onSkipped] gemeld.
Map<String, dynamic> buildPackage(
  CycleNetwork network, {
  required String region,
  required List<double> bbox,
  required String osmTimestamp,
  String networkType = 'rcn',
  void Function(String number)? onSkipped,
}) {
  assert(bbox.length == 4);
  final connections = <Connection>{};
  final dropped = <Connection>{};
  for (final j in network.junctions.values) {
    for (final c in network.connectionsAt(j.id)) {
      if (!_touches(c, bbox)) continue;
      final bad = [c.fromNumber, c.toNumber].where((n) => !isValidNumber(n));
      if (bad.isNotEmpty) {
        if (dropped.add(c)) onSkipped?.call(bad.first);
        continue;
      }
      connections.add(c);
    }
  }
  final encoded = [
    for (final c in connections)
      (
        c,
        [for (final s in c.segments) encodePolyline(s)],
      ),
  ]..sort((a, b) {
      final x = a.$1, y = b.$1;
      final byFrom = x.fromId.compareTo(y.fromId);
      if (byFrom != 0) return byFrom;
      final byTo = x.toId.compareTo(y.toId);
      if (byTo != 0) return byTo;
      return a.$2.join('|').compareTo(b.$2.join('|'));
    });
  final used = <int>{
    for (final e in encoded) ...[e.$1.fromId, e.$1.toId],
  };
  final junctions = [
    for (final id in used.toList()..sort()) network.junctions[id]!,
  ];
  return {
    'format': knpFormat,
    'region': region,
    'network': networkType,
    'osmTimestamp': osmTimestamp,
    'bbox': bbox,
    'junctions': [
      for (final j in junctions)
        [j.id, j.number, _round7(j.location.lat), _round7(j.location.lon)],
    ],
    'connections': [
      for (final e in encoded)
        [e.$1.fromId, e.$1.toId, e.$1.fromNumber, e.$1.toNumber, e.$2],
    ],
  };
}

double _round7(double v) => (v * 1e7).round() / 1e7;

bool _touches(Connection c, List<double> bbox) {
  var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
  for (final s in c.segments) {
    for (final p in s) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }
  }
  return maxLat >= bbox[0] && minLat <= bbox[2] && maxLon >= bbox[1] && minLon <= bbox[3];
}

/// Gzip-JSON van een pakket.
Uint8List packageToBytes(Map<String, dynamic> package) =>
    Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(package))));

/// Leest een pakket uit gzip-bytes. De uitgepakte grootte is begrensd.
KnpPackage readPackageBytes(List<int> bytes, {int maxUnpackedBytes = 64 * 1024 * 1024}) {
  final sink = _LimitedSink(maxUnpackedBytes);
  final conversion = gzip.decoder.startChunkedConversion(sink);
  try {
    conversion.add(bytes);
    conversion.close();
  } on FormatException {
    rethrow;
  } on Object catch (e) {
    throw FormatException('Ongeldig gzip-bestand: $e');
  }
  return readPackage(jsonDecode(utf8.decode(sink.takeBytes())));
}

class _LimitedSink extends ByteConversionSinkBase {
  _LimitedSink(this.max);

  final int max;
  final BytesBuilder _builder = BytesBuilder(copy: false);

  Uint8List takeBytes() => _builder.takeBytes();

  @override
  void add(List<int> chunk) {
    if (_builder.length + chunk.length > max) {
      throw const FormatException('Pakket is na uitpakken te groot.');
    }
    _builder.add(chunk);
  }

  @override
  void close() {}
}

const _maxJunctions = 200000;
const _maxConnections = 500000;

/// Controleert en leest een pakket. Gooit een [FormatException] bij alles wat
/// niet klopt: het pakket komt van buiten en wordt niet vertrouwd.
KnpPackage readPackage(Object? json) {
  if (json is! Map) throw const FormatException('Pakket is geen object.');
  if (json['format'] != knpFormat) {
    throw FormatException('Onbekend pakketformaat: ${json['format']}');
  }
  final region = _str(json['region'], 'region', max: 80);
  final type = _str(json['network'], 'network', max: 10);
  final timestamp = _str(json['osmTimestamp'], 'osmTimestamp', max: 40);
  final bboxRaw = json['bbox'];
  if (bboxRaw is! List || bboxRaw.length != 4) throw const FormatException('Ongeldige bbox.');
  final bbox = [
    _num(bboxRaw[0], 90), _num(bboxRaw[1], 180), _num(bboxRaw[2], 90), _num(bboxRaw[3], 180),
  ];
  final jl = json['junctions'], cl = json['connections'];
  if (jl is! List || cl is! List) throw const FormatException('Lijsten ontbreken.');
  if (jl.length > _maxJunctions || cl.length > _maxConnections) {
    throw const FormatException('Pakket bevat te veel items.');
  }
  final junctions = <Junction>[];
  for (final j in jl) {
    if (j is! List || j.length != 4) throw const FormatException('Ongeldig knooppunt.');
    final id = j[0];
    if (id is! int) throw const FormatException('Ongeldig knooppunt-id.');
    junctions.add(Junction(
      id: id,
      number: _number(j[1]),
      location: GeoPoint(_num(j[2], 90), _num(j[3], 180)),
    ));
  }
  final known = {for (final j in junctions) j.id};
  final connections = <Connection>[];
  for (final c in cl) {
    if (c is! List || c.length != 5) throw const FormatException('Ongeldige verbinding.');
    final from = c[0], to = c[1], lines = c[4];
    if (from is! int || to is! int || !known.contains(from) || !known.contains(to)) {
      throw const FormatException('Verbinding verwijst naar onbekend knooppunt.');
    }
    if (lines is! List || lines.isEmpty || lines.length > 5000) {
      throw const FormatException('Ongeldige geometrie.');
    }
    final segments = <List<GeoPoint>>[];
    for (final l in lines) {
      if (l is! String || l.length > 2000000) throw const FormatException('Ongeldige lijn.');
      final pts = decodePolyline(l);
      for (final p in pts) {
        if (p.lat.abs() > 90 || p.lon.abs() > 180) {
          throw const FormatException('Coördinaat buiten bereik.');
        }
      }
      segments.add(pts);
    }
    connections.add(Connection(
      fromId: from,
      toId: to,
      fromNumber: _number(c[2]),
      toNumber: _number(c[3]),
      segments: segments,
    ));
  }
  return KnpPackage(
    region: region,
    network: CycleNetwork(junctions: junctions, connections: connections),
    osmTimestamp: timestamp,
    bbox: bbox,
    networkType: type,
  );
}

String _str(Object? v, String name, {required int max}) {
  if (v is! String || v.isEmpty || v.length > max) {
    final shown = v is String && v.length > 40 ? '${v.substring(0, 40)}...' : v;
    throw FormatException('Ongeldig veld $name: "$shown"');
  }
  return v;
}

String _number(Object? v) {
  if (v is! String || !isValidNumber(v)) {
    throw FormatException('Ongeldig knooppuntnummer: "${v is String && v.length > 40 ? v.substring(0, 40) : v}"');
  }
  return v;
}

double _num(Object? v, double limit) {
  if (v is! num || !v.isFinite || v.abs() > limit) {
    throw const FormatException('Ongeldig getal.');
  }
  return v.toDouble();
}
