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

### Automatisch

De GitHub Action `Bouw pakketten` (`.github/workflows/build.yml`) draait elke maand op de 3e en is
ook handmatig te starten. Per land wordt het Geofabrik-bestand gedownload en gecontroleerd (MD5),
gefilterd en omgezet. Daarna controleert `tool/bin/validate.dart` elk pakket (SHA-256, formaat,
aantallen, grootte). Alleen als alles klopt worden de pakketten en `manifest.json` bij de releases
`data-latest` en `data-JJJJ-MM` gezet.

De omgrenzingen in `regions.json` zijn rechthoeken. Ze zijn bewust ruim en overlappen, zodat een
verbinding over een grens in beide pakketten staat. Voor Nederland is er een pakket `nl` (het hele
land) en een pakket per provincie.

### Zelf bouwen (voorbeeld Utrecht)

Nodig: `osmium-tool` en de Dart SDK.

```
bash scripts/filter.sh utrecht-latest.osm.pbf opl

cd tool
dart pub get
dart run bin/build.dart --opl ../opl --regions ../regions.json --out ../out --timestamp "$(cat ../opl/timestamp.txt)"
```

Voor een los bestand zonder `nl`-regio gebruik je een eigen `regions.json`.

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
