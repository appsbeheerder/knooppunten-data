"""Schrijft per regio een regel: id, maxzoom, west, zuid, oost, noord (tab-gescheiden)."""
import json
import sys

regions = json.load(open(sys.argv[1], encoding="utf-8"))["regions"]
wanted = set(sys.argv[2:])
for r in regions:
    if wanted and r["id"] not in wanted:
        continue
    south, west, north, east = r["bbox"]
    # Heel Nederland alleen als overzicht, de provincies in detail.
    maxzoom = 9 if r["id"] == "nl" else 14
    print("\t".join(str(v) for v in (r["id"], maxzoom, west, south, east, north)))
