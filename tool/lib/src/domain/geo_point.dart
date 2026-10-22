import 'dart:math' as math;

/// Een punt op aarde in graden (WGS84).
class GeoPoint {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  /// Afstand in meters (haversine).
  double distanceTo(GeoPoint other) {
    const earthRadius = 6371000.0;
    final p1 = _rad(lat);
    final p2 = _rad(other.lat);
    final dp = p2 - p1;
    final dl = _rad(other.lon - lon);
    final h =
        math.pow(math.sin(dp / 2), 2) +
        math.cos(p1) * math.cos(p2) * math.pow(math.sin(dl / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(h));
  }

  static double _rad(double deg) => deg * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);

  @override
  String toString() => 'GeoPoint($lat, $lon)';
}

/// Lengte in meters van één lijn. Tel nooit punten van verschillende lijnen
/// aaneen: dat telt de sprongen ertussen mee.
double polylineLength(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 0; i < points.length - 1; i++) {
    total += points[i].distanceTo(points[i + 1]);
  }
  return total;
}
