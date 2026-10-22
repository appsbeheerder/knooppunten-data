import 'geo_point.dart';

/// Genummerd knooppunt in het fietsnetwerk.
///
/// Het nummer is alleen uniek binnen een regio; [id] is de bronidentiteit
/// (bij OpenStreetMap het node-id).
class Junction {
  const Junction({
    required this.id,
    required this.number,
    required this.location,
  });

  final int id;
  final String number;
  final GeoPoint location;

  @override
  String toString() => 'Junction($number)';
}
