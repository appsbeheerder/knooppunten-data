#!/usr/bin/env bash
# Snijdt kaartpakketten (PMTiles, vector) per regio uit de dagelijkse
# Protomaps-basiskaart. Gebruik: maps.sh <pmtiles-programma> <uitvoermap> [regio-id ...]
# Zonder regio-id's worden alle regio's uit regions.json gemaakt.
set -euo pipefail

pm="$1"; out="$2"; shift 2
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$out"

# Nieuwste dagbouw: probeer vandaag en de dagen ervoor.
src=""
for back in 0 1 2 3 4; do
  d="$(date -u -d "-$back day" +%Y%m%d)"
  if curl -sfI "https://build.protomaps.com/$d.pmtiles" >/dev/null; then
    src="https://build.protomaps.com/$d.pmtiles"; break
  fi
done
[ -n "$src" ] || { echo "Geen Protomaps-bouw gevonden" >&2; exit 1; }
echo "Bron: $src"

# Het plan komt op Windows met regeleinde CR LF; die CR hoort niet bij de waarde.
python3 -I "$here/maps_plan.py" "$here/../regions.json" "$@" | while IFS=$'\t\r' read -r id maxzoom west south east north; do
  echo "== $id (tot zoom $maxzoom)"
  "$pm" extract "$src" "$out/$id.pmtiles" \
    --bbox="$west,$south,$east,$north" --maxzoom="$maxzoom" </dev/null >/dev/null 2>&1
done

python3 -I "$here/maps_manifest.py" "$src" "$here/../regions.json" "$out"
