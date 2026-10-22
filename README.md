# knooppunten-data

Regiopakketten met **fietsknooppunten** (netwerk `rcn`) en de verbindingen ertussen, gemaakt uit
OpenStreetMap-data. Bedoeld voor de app Knooppunten-planner, maar vrij te gebruiken onder de
licenties hieronder.

Een pakket bevat per regio de knooppunten (nummer en plaats) en de verbindingen (de route tussen
twee knooppunten, als lijn). Dat is sneller en betrouwbaarder dan de gegevens elke keer via
Overpass op te halen.

## Pakketten downloaden

De pakketten en `manifest.json` staan bij de release `data-latest`:
`https://github.com/appsbeheerder/knooppunten-data/releases/download/data-latest/manifest.json`

`manifest.json` beschrijft per regio het adres, de grootte, de SHA-256, de datum van de data en
het aantal knooppunten en verbindingen. Het formaat staat in [docs/FORMAT.md](docs/FORMAT.md).

## Hoe het wordt gemaakt

1. Het bestand van het land van [Geofabrik](https://download.geofabrik.de/) (`.osm.pbf`) wordt
   gedownload. Op landniveau, omdat een provinciebestand de verbindingen over de grens mist.
2. `osmium` filtert de fietsknooppuntrelaties (`route=bicycle`, `network=rcn`) met hun ways en
   de knooppunten (`rcn_ref`) en schrijft ze als tekst (OPL).
3. `tool/bin/build.dart` ordent de ways, koppelt de verbindingen aan de knooppunten en snijdt het
   netwerk in regio's volgens `regions.json`.

### Zelf bouwen (voorbeeld Utrecht)

Nodig: `osmium-tool` en de Dart SDK.

```
osmium tags-filter utrecht-latest.osm.pbf r/route=bicycle -o bic.osm.pbf
osmium tags-filter bic.osm.pbf r/network=rcn -o rcn.osm.pbf
osmium tags-filter utrecht-latest.osm.pbf n/rcn_ref -o nodes.osm.pbf
osmium cat rcn.osm.pbf -f opl -o opl/rcn.opl
osmium cat nodes.osm.pbf -f opl -o opl/nodes.opl

cd tool
dart pub get
dart run bin/build.dart --opl ../opl --regions ../regions.json --out ../out --timestamp 2026-10-20T20:23:47Z
```

De tijdstempel staat in de kop van het Geofabrik-bestand (`osmium fileinfo`).

### Testen

```
cd tool
dart test
# met een echte uitsnede (map met rcn.opl en nodes.opl):
KNP_UTRECHT_DIR=../opl dart test
```

## Licenties

- **Code** (`tool/`): GNU General Public License versie 3, zie [LICENSE](LICENSE). Wie op deze
  code voortbouwt en het resultaat verspreidt, moet de broncode onder dezelfde licentie delen.
- **Data** (de pakketten): Open Database License (ODbL) 1.0, zie [LICENSE-DATA](LICENSE-DATA) en
  [ATTRIBUTION.md](ATTRIBUTION.md). De pakketten zijn afgeleid van OpenStreetMap-gegevens:
  © OpenStreetMap-bijdragers.

Dit project is onafhankelijk en niet verbonden met de ANWB of andere beheerders van
knooppuntennetwerken.

© 2026 Eric M. Kok - Eric de Magiër - appsbeheerder
