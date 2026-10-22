// Bouwt regiopakketten uit osmium-uitvoer (OPL).
//
//   dart run bin/build.dart --opl <map met rcn.opl en nodes.opl> \
//       --regions ../regions.json --out <uitvoermap> --timestamp <ISO-datum>
//
// Opties: `--country nl` bouwt alleen de regio's van dat land, `--manifest naam.json` is de
// naam van het manifest (standaard manifest.json) en `--base-url` is de map waar de
// pakketten later te downloaden zijn.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:knooppunten_tool/knp.dart';
import 'package:knooppunten_tool/opl.dart';
import 'package:knooppunten_tool/src/data/osm_network_parser.dart';

const _defaultBase =
    'https://github.com/appsbeheerder/knooppunten-data/releases/download/data-latest';

Future<void> main(List<String> args) async {
  final opts = _parse(args);
  final oplDir = opts['opl'], regionsFile = opts['regions'], outDir = opts['out'];
  final timestamp = opts['timestamp'];
  if (oplDir == null || regionsFile == null || outDir == null || timestamp == null) {
    stderr.writeln(
      'Gebruik: dart run bin/build.dart --opl <map> --regions <regions.json> '
      '--out <map> --timestamp <ISO-datum> [--base-url <url>]',
    );
    exit(64);
  }
  final base = opts['base-url'] ?? _defaultBase;

  final sw = Stopwatch()..start();
  final json = await oplToOverpassJson(
    routesOpl: '$oplDir/rcn.opl',
    nodesOpl: '$oplDir/nodes.opl',
  );
  final parser = OsmNetworkParser();
  final network = parser.parse(nodesJson: json.nodes, routesJson: json.routes);
  stdout.writeln(
    'Netwerk: ${network.junctions.length} knooppunten, '
    '${parser.skippedRelations.length} relaties overgeslagen (${sw.elapsed.inSeconds} s)',
  );

  final country = opts['country'];
  final regions = [
    for (final r in (jsonDecode(File(regionsFile).readAsStringSync()) as Map)['regions'] as List)
      if (country == null || (r as Map)['country'] == country) r,
  ];
  if (regions.isEmpty) {
    stderr.writeln('Geen regios gevonden${country == null ? '' : ' voor land $country'}.');
    exit(1);
  }
  Directory(outDir).createSync(recursive: true);
  final entries = <Map<String, dynamic>>[];
  for (final r in regions.cast<Map<String, dynamic>>()) {
    final id = r['id'] as String;
    final bbox = [for (final v in r['bbox'] as List) (v as num).toDouble()];
    final skipped = <String>{};
    final package = buildPackage(
      network,
      region: id,
      bbox: bbox,
      osmTimestamp: timestamp,
      onSkipped: skipped.add,
    );
    if (skipped.isNotEmpty) {
      stdout.writeln('  $id: verbindingen met ongeldig nummer overgeslagen: '
          '${(skipped.toList()..sort()).take(15).join(', ')}');
    }
    final bytes = packageToBytes(package);
    final file = '$id.knp.gz';
    File('$outDir/$file').writeAsBytesSync(bytes);
    final junctions = (package['junctions'] as List).length;
    final connections = (package['connections'] as List).length;
    entries.add({
      'id': id,
      'name': r['name'],
      'country': r['country'],
      'bbox': bbox,
      'osmTimestamp': timestamp,
      'url': '$base/$file',
      'bytes': bytes.length,
      'sha256': sha256.convert(bytes).toString(),
      'junctions': junctions,
      'connections': connections,
    });
    stdout.writeln('$id: $junctions knooppunten, $connections verbindingen, ${bytes.length} bytes');
  }
  final manifest = {
    'format': knpFormat,
    'license': 'ODbL-1.0',
    'attribution': '© OpenStreetMap-bijdragers (ODbL), data via Geofabrik',
    'regions': entries,
  };
  File('$outDir/${opts['manifest'] ?? 'manifest.json'}')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  stdout.writeln('Klaar: ${entries.length} regio(\'s) in $outDir');
}

Map<String, String> _parse(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i + 1 < args.length; i += 2) {
    if (!args[i].startsWith('--')) break;
    out[args[i].substring(2)] = args[i + 1];
  }
  return out;
}
