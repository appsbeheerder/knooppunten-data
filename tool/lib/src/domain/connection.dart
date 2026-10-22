import 'geo_point.dart';

/// Fietstraject tussen twee knooppunten. De graaf is ongericht.
///
/// Knooppunten worden herkend aan hun id (nummers zijn alleen binnen één
/// netwerk uniek); [fromNumber] en [toNumber] zijn labels.
///
/// [segments] zijn de lijnstukken (ways) van het traject, bij voorkeur in
/// volgorde van [fromId] naar [toId]. De lengte is de som per lijnstuk, dus
/// sprongen tussen losse stukken tellen niet mee.
class Connection {
  Connection({
    required this.fromId,
    required this.toId,
    required this.fromNumber,
    required this.toNumber,
    required this.segments,
  }) : distanceMeters = segments.fold(0.0, (sum, s) => sum + polylineLength(s));

  final int fromId;
  final int toId;
  final String fromNumber;
  final String toNumber;
  final List<List<GeoPoint>> segments;
  final double distanceMeters;

  /// Het knooppunt aan de andere kant, of null als [id] er niet bij hoort.
  int? otherEnd(int id) {
    if (id == fromId) return toId;
    if (id == toId) return fromId;
    return null;
  }

  @override
  String toString() =>
      'Connection($fromNumber-$toNumber, ${distanceMeters.round()} m)';
}
