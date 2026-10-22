import 'connection.dart';

/// Route: de geordende lijst knooppunten die de gebruiker kiest, met de
/// verbindingen ertussen. Knooppunten en verbindingen mogen vaker voorkomen;
/// elk gebruik telt mee in de afstand.
class CycleRoute {
  CycleRoute({
    required this.junctionIds,
    required this.junctionNumbers,
    required this.legs,
  }) : assert(junctionIds.length == legs.length + 1),
       assert(junctionNumbers.length == junctionIds.length);

  final List<int> junctionIds;

  /// Nummers (labels) bij [junctionIds].
  final List<String> junctionNumbers;
  final List<Connection> legs;

  double get totalMeters => legs.fold(0.0, (sum, c) => sum + c.distanceMeters);

  @override
  String toString() =>
      'CycleRoute(${junctionNumbers.join('-')}, '
      '${(totalMeters / 1000).toStringAsFixed(2)} km)';
}
