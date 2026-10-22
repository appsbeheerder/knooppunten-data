#!/usr/bin/env bash
# Filtert de fietsknooppunten uit een OSM-bestand van Geofabrik.
#
#   scripts/filter.sh <invoer.osm.pbf> <uitvoermap>
#
# Schrijft in de uitvoermap: rcn.opl (relaties met ways en nodes), nodes.opl (nodes met
# rcn_ref) en timestamp.txt (datum van de OSM-data). Vereist osmium-tool.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Gebruik: $0 <invoer.osm.pbf> <uitvoermap>" >&2
  exit 64
fi
in="$1"
out="$2"
mkdir -p "$out"

osmium tags-filter "$in" r/route=bicycle -o "$out/bic.osm.pbf" --overwrite
osmium tags-filter "$out/bic.osm.pbf" r/network=rcn -o "$out/rcn.osm.pbf" --overwrite
osmium tags-filter "$in" n/rcn_ref -o "$out/nodes.osm.pbf" --overwrite
osmium cat "$out/rcn.osm.pbf" -f opl -o "$out/rcn.opl" --overwrite
osmium cat "$out/nodes.osm.pbf" -f opl -o "$out/nodes.opl" --overwrite
osmium fileinfo -g header.option.osmosis_replication_timestamp "$in" > "$out/timestamp.txt"

echo "Klaar: $(wc -l < "$out/rcn.opl") regels in rcn.opl, $(wc -l < "$out/nodes.opl") in nodes.opl, data van $(cat "$out/timestamp.txt")"
