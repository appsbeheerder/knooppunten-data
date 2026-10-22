import 'dart:convert';

import '../domain/connection.dart';
import '../domain/cycle_network.dart';
import '../domain/geo_point.dart';
import '../domain/junction.dart';
import '../domain/segment_chain.dart';

/// Leest Overpass-JSON (knooppunten met `rcn_ref` en `route=bicycle`-relaties
/// met `network=rcn`, opgehaald met `out geom`) en valideert de invoer.
///
/// Gooit een [FormatException] bij ongeldige gegevens. Relaties waarvan de
/// `ref` niet de vorm `van-naar` heeft (lussen zoals `15`) worden overgeslagen
/// en staan in [skippedRelations].
class OsmNetworkParser {
  OsmNetworkParser({this.maxElements = 200000, this.center, this.radiusMeters});

  final int maxElements;

  /// Beperkt het netwerk tot knooppunten binnen [radiusMeters] van [center].
  /// Nodig omdat knooppuntnummers alleen binnen één netwerk uniek zijn.
  final GeoPoint? center;
  final double? radiusMeters;

  /// Relaties die niet als verbinding zijn gebruikt.
  final List<String> skippedRelations = [];

  /// Nummers die bij meerdere knooppunten horen (overlappende netwerken).
  final List<String> duplicateNumbers = [];

  CycleNetwork parse({required String nodesJson, required String routesJson}) {
    final all = <String, List<Junction>>{};
    for (final e in _elements(nodesJson)) {
      if (e['type'] != 'node') continue;
      final tags = _tags(e);
      final number = tags['rcn_ref'];
      if (number == null || number.isEmpty) continue;
      final id = _int(e['id'], 'id');
      final lat = _coord(e['lat'], 90, 'lat');
      final lon = _coord(e['lon'], 180, 'lon');
      final c = center, r = radiusMeters;
      if (c != null && r != null && c.distanceTo(GeoPoint(lat, lon)) > r)
        continue;
      all
          .putIfAbsent(number, () => [])
          .add(Junction(id: id, number: number, location: GeoPoint(lat, lon)));
    }

    // Punten binnen 100 m van hetzelfde nummer zijn één kruising.
    final reps = <String, List<Junction>>{};
    for (final entry in all.entries) {
      final list = <Junction>[];
      for (final j in entry.value) {
        if (list.every((k) => k.location.distanceTo(j.location) >= 100))
          list.add(j);
      }
      reps[entry.key] = list;
    }

    Junction nearest(List<Junction> list, GeoPoint p) => list.reduce(
      (x, y) => x.location.distanceTo(p) <= y.location.distanceTo(p) ? x : y,
    );

    final found = <(Connection, Junction, Junction)>[];
    for (final e in _elements(routesJson)) {
      if (e['type'] != 'relation') continue;
      final ref = _tags(e)['ref'] ?? '';
      final parts = ref.split('-');
      if (parts.length != 2 || parts.any((p) => p.isEmpty)) {
        skippedRelations.add(ref);
        continue;
      }
      final members = e['members'];
      if (members is! List) {
        throw const FormatException('Relatie zonder members.');
      }
      final segments = <List<GeoPoint>>[];
      for (final m in members) {
        if (m is! Map || m['type'] != 'way') continue;
        final geometry = m['geometry'];
        if (geometry is! List || geometry.length < 2) continue;
        // Bijgesneden antwoorden bevatten lege plekken (null) waar de way buiten
        // het opgehaalde gebied valt: elk aaneengesloten deel is een eigen stuk.
        var run = <GeoPoint>[];
        for (final p in geometry) {
          if (p == null) {
            if (run.length >= 2) segments.add(run);
            run = <GeoPoint>[];
            continue;
          }
          run.add(GeoPoint(
            _coord((p as Map)['lat'], 90, 'lat'),
            _coord(p['lon'], 180, 'lon'),
          ));
        }
        if (run.length >= 2) segments.add(run);
      }
      final a = reps[parts[0]];
      final b = reps[parts[1]];
      if (segments.isEmpty || a == null || b == null) {
        skippedRelations.add(ref);
        continue;
      }
      final ordered = chainSegments(
        segments,
        [for (final j in a) j.location],
        [for (final j in b) j.location],
      );
      if (ordered == null) {
        // Uiteinden liggen niet bij knooppunten met deze nummers, of geen
        // aaneengesloten pad.
        skippedRelations.add(ref);
        continue;
      }
      final from = nearest(a, ordered.first.first);
      final to = nearest(b, ordered.last.last);
      found.add((
        Connection(
          fromId: from.id,
          toId: to.id,
          fromNumber: parts[0],
          toNumber: parts[1],
          segments: ordered,
        ),
        from,
        to,
      ));
    }

    // Knooppunten worden herkend aan id; overlappende netwerken met dezelfde
    // nummers blijven zo gescheiden.
    final connections = <Connection>[];
    final used = <int, Junction>{};
    for (final (c, from, to) in found) {
      connections.add(c);
      used[from.id] = from;
      used[to.id] = to;
    }
    final seen = <String>{};
    for (final j in used.values) {
      if (!seen.add(j.number) && !duplicateNumbers.contains(j.number)) {
        duplicateNumbers.add(j.number);
      }
    }
    return CycleNetwork(junctions: used.values, connections: connections);
  }

  List<Map<String, dynamic>> _elements(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('Geen geldige JSON.');
    }
    if (decoded is! Map || decoded['elements'] is! List) {
      throw const FormatException('Overpass-JSON zonder "elements".');
    }
    final list = decoded['elements'] as List;
    if (list.length > maxElements) {
      throw const FormatException('Te veel elementen in de invoer.');
    }
    return [
      for (final e in list)
        if (e is Map<String, dynamic>)
          e
        else
          throw const FormatException('Ongeldig element.'),
    ];
  }

  Map<String, String> _tags(Map<String, dynamic> e) {
    final t = e['tags'];
    if (t is! Map) return const {};
    return {for (final entry in t.entries) '${entry.key}': '${entry.value}'};
  }

  int _int(Object? v, String name) {
    if (v is int) return v;
    throw FormatException('Ongeldig $name.');
  }

  double _coord(Object? v, double limit, String name) {
    if (v is num && v.abs() <= limit) return v.toDouble();
    throw FormatException('Ongeldige coördinaat ($name).');
  }
}
