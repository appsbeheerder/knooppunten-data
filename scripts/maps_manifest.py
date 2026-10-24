"""Maakt maps-manifest.json voor de kaartbestanden in een map."""
import hashlib
import json
import os
import re
import sys

src, regions_path, out = sys.argv[1:4]
m = re.search(r"/(\d{4})(\d{2})(\d{2})\.pmtiles$", src)
if not m:
    sys.exit("Bron heeft geen datum")
regions = json.load(open(regions_path, encoding="utf-8"))["regions"]
maps = []
for r in regions:
    path = os.path.join(out, r["id"] + ".pmtiles")
    if not os.path.exists(path):
        continue
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    maps.append({
        "id": r["id"],
        "name": r["name"],
        "file": r["id"] + ".pmtiles",
        "size": os.path.getsize(path),
        "sha256": h.hexdigest(),
        "bbox": r["bbox"],
        "maxZoom": 9 if r["id"] == "nl" else 14,
    })
manifest = {
    "version": 1,
    "source": src,
    "sourceDate": "%s-%s-%s" % m.groups(),
    "license": "ODbL 1.0 (Produced Work), © OpenStreetMap-bijdragers; basiskaart Protomaps",
    "maps": maps,
}
with open(os.path.join(out, "maps-manifest.json"), "w", encoding="utf-8") as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("%d kaarten, %d bytes" % (len(maps), sum(x["size"] for x in maps)))
