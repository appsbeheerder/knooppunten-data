// Voegt de manifesten per land samen tot één manifest.
//
//   dart run bin/merge_manifests.dart <uitvoerbestand> <manifest-1.json> [<manifest-2.json> ...]

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Gebruik: dart run bin/merge_manifests.dart <uitvoer> <manifest>...');
    exit(64);
  }
  Map<String, dynamic>? first;
  final regions = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final path in args.skip(1)) {
    final m = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
    first ??= m;
    for (final r in (m['regions'] as List).cast<Map<String, dynamic>>()) {
      if (!ids.add(r['id'] as String)) {
        stderr.writeln('Dubbele regio: ${r['id']}');
        exit(1);
      }
      regions.add(r);
    }
  }
  regions.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  final merged = {
    'format': first!['format'],
    'license': first['license'],
    'attribution': first['attribution'],
    'regions': regions,
  };
  File(args[0]).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(merged));
  stdout.writeln('${regions.length} regio\'s in ${args[0]}');
}
