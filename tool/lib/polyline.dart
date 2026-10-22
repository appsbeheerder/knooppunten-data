import 'src/domain/geo_point.dart';

/// Codeert punten als "encoded polyline" (het algoritme van Google; hier met
/// instelbare precisie, standaard 6 decimalen).
String encodePolyline(List<GeoPoint> points, {int precision = 6}) {
  final factor = _pow10(precision);
  final out = StringBuffer();
  var lastLat = 0, lastLon = 0;
  for (final p in points) {
    final lat = (p.lat * factor).round();
    final lon = (p.lon * factor).round();
    _write(lat - lastLat, out);
    _write(lon - lastLon, out);
    lastLat = lat;
    lastLon = lon;
  }
  return out.toString();
}

/// Het omgekeerde van [encodePolyline]. Gooit een [FormatException] bij een
/// ongeldige tekst.
List<GeoPoint> decodePolyline(String s, {int precision = 6}) {
  final factor = _pow10(precision);
  final points = <GeoPoint>[];
  var i = 0, lat = 0, lon = 0;
  int next() {
    var result = 0, shift = 0, b;
    do {
      if (i >= s.length) throw const FormatException('Onvolledige polyline.');
      b = s.codeUnitAt(i++) - 63;
      if (b < 0 || b > 63 || shift > 30) throw const FormatException('Ongeldige polyline.');
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (i < s.length) {
    lat += next();
    lon += next();
    points.add(GeoPoint(lat / factor, lon / factor));
  }
  return points;
}

void _write(int value, StringBuffer out) {
  var v = value < 0 ? ~(value << 1) : value << 1;
  while (v >= 0x20) {
    out.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  out.writeCharCode(v + 63);
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
