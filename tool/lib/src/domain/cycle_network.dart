import 'connection.dart';
import 'junction.dart';

/// Het netwerk als graaf: knooppunten en de verbindingen ertussen.
///
/// Knooppunten worden herkend aan hun id. Meerdere netwerken met dezelfde
/// nummers kunnen naast elkaar bestaan.
class CycleNetwork {
  CycleNetwork({
    required Iterable<Junction> junctions,
    required Iterable<Connection> connections,
  }) : junctions = {for (final j in junctions) j.id: j},
       _byJunction = {},
       _byNumber = {} {
    for (final j in this.junctions.values) {
      _byNumber.putIfAbsent(j.number, () => []).add(j);
    }
    for (final c in connections) {
      _byJunction.putIfAbsent(c.fromId, () => []).add(c);
      if (c.toId != c.fromId) {
        _byJunction.putIfAbsent(c.toId, () => []).add(c);
      }
    }
  }

  /// Knooppunten op id.
  final Map<int, Junction> junctions;
  final Map<int, List<Connection>> _byJunction;
  final Map<String, List<Junction>> _byNumber;

  /// Alle knooppunten met dit nummer (meer dan één bij overlappende netwerken).
  List<Junction> withNumber(String number) => _byNumber[number] ?? const [];

  /// Verbindingen die bij [id] beginnen of eindigen.
  List<Connection> connectionsAt(int id) => _byJunction[id] ?? const [];

  /// Kortste directe verbinding tussen twee knooppunten, of null.
  Connection? directConnection(int a, int b) {
    Connection? best;
    for (final c in connectionsAt(a)) {
      if (c.otherEnd(a) == b &&
          (best == null || c.distanceMeters < best.distanceMeters)) {
        best = c;
      }
    }
    return best;
  }
}
