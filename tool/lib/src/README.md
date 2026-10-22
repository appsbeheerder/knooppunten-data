# Gekopieerde bestanden uit de app

De mappen `data/` en `domain/` hier zijn een **kopie** van dezelfde bestanden in de app
Knooppunten-planner (`lib/data/osm_network_parser.dart`, `lib/domain/...`). Zo rekent dit script
precies hetzelfde als de app. Wijzig ze niet hier: pas ze in de app aan en kopieer ze opnieuw.
De test met echte data (`KNP_UTRECHT_DIR`) vangt verschillen op: 03 -> 61 = 8,66 km en de
ANWB-testroute = 41,75 km.

De bestanden hebben dezelfde licentie als de rest van `tool/` (GNU GPL v3).
