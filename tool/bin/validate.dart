// Controleert gebouwde pakketten voordat ze worden gepubliceerd.
//
//   dart run bin/validate.dart <uitvoermap> <regions.json> [<manifest.json>]
//
// Faalt (exitcode 1) bij een ontbrekend bestand, verkeerde grootte of SHA-256, een
// pakket dat de lezer weigert, afwijkende aantallen, een te groot pakket of te weinig
// knooppunten.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:knooppunten_tool/knp.dart';

const _maxPackageBytes = 40 * 1024 * 1024;

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('Gebruik: dart run bin/validate.dart <uitvoermap> <regions.json> [<manifest.json>]');
    exit(64);
  }
  final dir = args[0];
  final manifestName = args.length > 2 ? args[2] : 'manifest.json';
  final regions = {
    for (final r in (jsonDecode(File(args[1]).readAsStringSync()) as Map)['regions'] as List)
      (r as Map)['id'] as String: r,
  };
  final manifest = jsonDecode(File('$dir/$manifestName').readAsStringSync()) as Map;
  final problems = <String>[];
  if (manifest['format'] != knpFormat) problems.add('manifest: onbekend formaat');
  if (manifest['license'] != 'ODbL-1.0') problems.add('manifest: licentie ontbreekt');
  final entries = (manifest['regions'] as List).cast<Map>();
  if (entries.isEmpty) problems.add('manifest: geen regio\'s');

  for (final e in entries) {
    final id = e['id'] as String;
    final file = File('$dir/$id.knp.gz');
    if (!file.existsSync()) {
      problems.add('$id: bestand ontbreekt');
      continue;
    }
    final bytes = file.readAsBytesSync();
    if (bytes.length != e['bytes']) problems.add('$id: grootte ${bytes.length} != ${e['bytes']}');
    if (bytes.length > _maxPackageBytes) problems.add('$id: te groot (${bytes.length} bytes)');
    if (sha256.convert(bytes).toString() != e['sha256']) problems.add('$id: SHA-256 klopt niet');
    try {
      final p = readPackageBytes(bytes);
      if (p.region != id) problems.add('$id: regio in pakket is ${p.region}');
      final junctions = p.network.junctions.length;
      if (junctions != e['junctions']) problems.add('$id: aantal knooppunten wijkt af');
      final min = (regions[id]?['minJunctions'] as int?) ?? 1;
      if (junctions < min) problems.add('$id: slechts $junctions knooppunten (minimaal $min)');
      stdout.writeln('$id: ok ($junctions knooppunten, ${bytes.length} bytes)');
    } on FormatException catch (x) {
      problems.add('$id: pakket ongeldig: ${x.message}');
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('PROBLEMEN:');
    for (final p in problems) {
      stderr.writeln(' - $p');
    }
    exit(1);
  }
  stdout.writeln('Alles in orde: ${entries.length} regio(\'s).');
}
