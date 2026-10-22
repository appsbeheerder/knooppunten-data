import 'connection.dart';
import 'cycle_network.dart';
import 'cycle_route.dart';

enum RouteError {
  unknownJunction,
  ambiguousJunction,
  tooFewJunctions,
  consecutiveEqual,
  startEqualsEnd,
  noRoute,
}

/// Fout bij het berekenen van een route. Bevat alleen een soort en
/// gegevens; de tekst voor de gebruiker maakt de presentatielaag.
class RouteException implements Exception {
  RouteException(this.error, {this.from, this.to});

  final RouteError error;

  /// Knooppunt (nummer of id) waar de fout over gaat.
  final String? from;

  /// Tweede knooppunt, bij [RouteError.noRoute].
  final String? to;

  @override
  String toString() => 'RouteException: $error ($from, $to)';
}

/// Berekent routes over een [CycleNetwork]. Platformonafhankelijk.
class RouteEngine {
  RouteEngine(this.network);

  final CycleNetwork network;

  /// Zoals [fromJunctions], met nummers. Een nummer dat bij meerdere
  /// knooppunten hoort (overlappende netwerken) is een fout.
  CycleRoute fromNumbers(List<String> numbers) {
    final ids = <int>[];
    for (final n in numbers) {
      final found = network.withNumber(n);
      if (found.isEmpty)
        throw RouteException(RouteError.unknownJunction, from: n);
      if (found.length > 1)
        throw RouteException(RouteError.ambiguousJunction, from: n);
      ids.add(found.first.id);
    }
    return fromJunctions(ids);
  }

  /// Bouwt een route langs de door de gebruiker gekozen knooppunten, in die
  /// volgorde. Zijn twee opeenvolgende knooppunten niet direct verbonden, dan
  /// wordt het stuk ertussen aangevuld met het kortste pad.
  CycleRoute fromJunctions(List<int> chosen) {
    if (chosen.length < 2) {
      throw RouteException(RouteError.tooFewJunctions);
    }
    for (final id in chosen) {
      if (!network.junctions.containsKey(id)) {
        throw RouteException(RouteError.unknownJunction, from: '$id');
      }
    }
    final ids = <int>[chosen.first];
    final legs = <Connection>[];
    for (var i = 0; i < chosen.length - 1; i++) {
      final a = chosen[i];
      final b = chosen[i + 1];
      if (a == b) {
        throw RouteException(RouteError.consecutiveEqual, from: _label(a));
      }
      final direct = network.directConnection(a, b);
      if (direct != null) {
        legs.add(direct);
        ids.add(b);
      } else {
        final path = shortestPath(a, b);
        legs.addAll(path.legs);
        ids.addAll(path.junctionIds.skip(1));
      }
    }
    return _route(ids, legs);
  }

  /// Kortste pad tussen twee knooppunten (Dijkstra).
  CycleRoute shortestPath(int from, int to) {
    for (final id in [from, to]) {
      if (!network.junctions.containsKey(id)) {
        throw RouteException(RouteError.unknownJunction, from: '$id');
      }
    }
    if (from == to) {
      throw RouteException(RouteError.startEqualsEnd, from: _label(from));
    }
    final dist = <int, double>{from: 0};
    final prev = <int, Connection>{};
    final done = <int>{};
    while (true) {
      int? u;
      for (final e in dist.entries) {
        if (!done.contains(e.key) && (u == null || e.value < dist[u]!)) {
          u = e.key;
        }
      }
      if (u == null) {
        throw RouteException(
          RouteError.noRoute,
          from: _label(from),
          to: _label(to),
        );
      }
      if (u == to) break;
      done.add(u);
      for (final c in network.connectionsAt(u)) {
        final v = c.otherEnd(u)!;
        final nd = dist[u]! + c.distanceMeters;
        if (nd < (dist[v] ?? double.infinity)) {
          dist[v] = nd;
          prev[v] = c;
        }
      }
    }
    final ids = <int>[to];
    final legs = <Connection>[];
    var at = to;
    while (at != from) {
      final c = prev[at]!;
      legs.add(c);
      at = c.otherEnd(at)!;
      ids.add(at);
    }
    return _route(ids.reversed.toList(), legs.reversed.toList());
  }

  String _label(int id) => network.junctions[id]?.number ?? '$id';

  CycleRoute _route(List<int> ids, List<Connection> legs) => CycleRoute(
    junctionIds: ids,
    junctionNumbers: [for (final id in ids) _label(id)],
    legs: legs,
  );
}
