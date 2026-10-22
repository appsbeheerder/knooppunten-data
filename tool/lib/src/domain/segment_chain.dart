import 'geo_point.dart';

/// Zet de ways van een route-relatie in volgorde en richting, van een van de
/// [starts] naar een van de [ends] (kandidaat-knooppunten met hetzelfde nummer;
/// het dichtstbijzijnde wordt gekozen). Ways sluiten aan via gelijke eindpunten; zijtakken vallen weg.
///
/// Geeft `null` als er geen aaneengesloten pad van begin naar eind bestaat.
List<List<GeoPoint>>? chainSegments(
  List<List<GeoPoint>> ways,
  List<GeoPoint> starts,
  List<GeoPoint> ends, {
  double maxSnapMeters = 100,
}) {
  String key(GeoPoint p) =>
      '${p.lat.toStringAsFixed(7)},${p.lon.toStringAsFixed(7)}';
  final points = <String, GeoPoint>{};
  final edges =
      <String, List<(int, String)>>{}; // eindpunt -> (way, andere kant)
  for (var i = 0; i < ways.length; i++) {
    final a = key(ways[i].first);
    final b = key(ways[i].last);
    points[a] = ways[i].first;
    points[b] = ways[i].last;
    (edges[a] ??= []).add((i, b));
    (edges[b] ??= []).add((i, a));
  }
  if (points.isEmpty) return null;

  if (starts.isEmpty || ends.isEmpty) return null;
  double gap(GeoPoint p, List<GeoPoint> c) =>
      c.map((q) => q.distanceTo(p)).reduce((a, b) => a < b ? a : b);
  String nearest(List<GeoPoint> c) => points.entries
      .reduce((x, y) => gap(x.value, c) <= gap(y.value, c) ? x : y)
      .key;
  final s = nearest(starts);
  final t = nearest(ends);
  if (s == t) return null;
  if (gap(points[s]!, starts) > maxSnapMeters ||
      gap(points[t]!, ends) > maxSnapMeters) {
    return null;
  }

  final dist = <String, double>{s: 0};
  final prev = <String, (String, int)>{};
  final todo = <String>{s};
  while (todo.isNotEmpty) {
    final u = todo.reduce((x, y) => dist[x]! <= dist[y]! ? x : y);
    todo.remove(u);
    if (u == t) break;
    for (final (way, v) in edges[u] ?? const <(int, String)>[]) {
      final d = dist[u]! + polylineLength(ways[way]);
      if (d < (dist[v] ?? double.infinity)) {
        dist[v] = d;
        prev[v] = (u, way);
        todo.add(v);
      }
    }
  }
  if (!prev.containsKey(t)) return null;

  final result = <List<GeoPoint>>[];
  for (var at = t; at != s;) {
    final (from, way) = prev[at]!;
    result.add(
      key(ways[way].first) == from ? ways[way] : ways[way].reversed.toList(),
    );
    at = from;
  }
  return result.reversed.toList();
}
