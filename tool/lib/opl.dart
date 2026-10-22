import 'dart:convert';
import 'dart:io';

/// Leest de tekstuitvoer van `osmium cat -f opl` en zet die om naar het
/// JSON-formaat van Overpass, zodat de parser van de app er ongewijzigd mee
/// kan werken.
///
/// - [routesOpl]: relaties `route=bicycle` + `network=rcn` met hun ways en nodes.
/// - [nodesOpl]: nodes met `rcn_ref`.
Future<({String nodes, String routes})> oplToOverpassJson({
  required String routesOpl,
  required String nodesOpl,
}) async {
  final coords = <int, (double, double)>{};
  final ways = <int, List<int>>{};
  final relations = <Map<String, dynamic>>[];
  final memberLists = <int, List<(int, String)>>{};

  await for (final obj in _objects(routesOpl)) {
    switch (obj.type) {
      case 'n':
        coords[obj.id] = (double.parse(obj.fields['y']!), double.parse(obj.fields['x']!));
      case 'w':
        ways[obj.id] = [
          for (final n in (obj.fields['N'] ?? '').split(','))
            if (n.isNotEmpty) int.parse(n.substring(1)),
        ];
      case 'r':
        final members = <(int, String)>[];
        for (final m in (obj.fields['M'] ?? '').split(',')) {
          if (!m.startsWith('w')) continue;
          final at = m.indexOf('@');
          members.add((int.parse(m.substring(1, at)), m.substring(at + 1)));
        }
        memberLists[obj.id] = members;
        relations.add({'type': 'relation', 'id': obj.id, 'tags': _tags(obj.fields['T'] ?? '')});
    }
  }
  for (final r in relations) {
    r['members'] = [
      for (final (w, role) in memberLists[r['id']]!)
        {
          'type': 'way',
          'ref': w,
          'role': role,
          'geometry': [
            for (final n in ways[w] ?? const <int>[])
              coords[n] == null ? null : {'lat': coords[n]!.$1, 'lon': coords[n]!.$2},
          ],
        },
    ];
  }

  final nodes = <Map<String, dynamic>>[];
  await for (final obj in _objects(nodesOpl)) {
    if (obj.type != 'n') continue;
    nodes.add({
      'type': 'node',
      'id': obj.id,
      'lat': double.parse(obj.fields['y']!),
      'lon': double.parse(obj.fields['x']!),
      'tags': _tags(obj.fields['T'] ?? ''),
    });
  }
  return (
    nodes: jsonEncode({'elements': nodes}),
    routes: jsonEncode({'elements': relations}),
  );
}

class _Obj {
  _Obj(this.type, this.id, this.fields);

  final String type;
  final int id;

  /// Eerste teken van een veld is de sleutel (`x`, `y`, `T`, `N`, `M`, ...).
  final Map<String, String> fields;
}

Stream<_Obj> _objects(String path) async* {
  final lines = File(path).openRead().transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.isEmpty) continue;
    final parts = line.split(' ');
    final head = parts[0];
    final fields = <String, String>{};
    for (final p in parts.skip(1)) {
      if (p.isNotEmpty) fields[p[0]] = p.substring(1);
    }
    yield _Obj(head[0], int.parse(head.substring(1)), fields);
  }
}

String _unescape(String s) => s.replaceAllMapped(
      RegExp(r'%([0-9a-fA-F]+)%'),
      (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
    );

Map<String, String> _tags(String t) {
  final out = <String, String>{};
  if (t.isEmpty) return out;
  for (final kv in t.split(',')) {
    final i = kv.indexOf('=');
    if (i > 0) out[_unescape(kv.substring(0, i))] = _unescape(kv.substring(i + 1));
  }
  return out;
}
