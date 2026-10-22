# Pakketformaat `.knp.gz` (formaat 1)

Een pakket is een **gzip-gecomprimeerd JSON-bestand**. De naam is `<regio-id>.knp.gz`.

```json
{
  "format": 1,
  "region": "nl-utrecht",
  "network": "rcn",
  "osmTimestamp": "2026-10-20T20:23:47Z",
  "bbox": [51.85, 4.79, 52.31, 5.63],
  "junctions": [[44643839, "52", 51.9677326, 5.2154052]],
  "connections": [[44643839, 44604813, "52", "42", ["<lijn>", "<lijn>"]]]
}
```

| Veld | Betekenis |
|---|---|
| `format` | Versienummer van dit formaat. Een lezer weigert een onbekend nummer. |
| `region` | Id van de regio (bijv. `nl-utrecht`). |
| `network` | Soort netwerk, nu `rcn` (fiets). |
| `osmTimestamp` | Datum van de OSM-data waaruit het pakket is gemaakt (UTC). |
| `bbox` | Omgrenzing van de regio: `[zuid, west, noord, oost]` in graden. |
| `junctions` | Lijst `[id, nummer, breedtegraad, lengtegraad]`. `id` is de OSM-node. |
| `connections` | Lijst `[van-id, naar-id, van-nummer, naar-nummer, lijnen]`. |

**Lijnen:** elke verbinding bestaat uit een of meer aaneengesloten lijnen, in rijrichting van
`van` naar `naar`. Elke lijn is een *encoded polyline* (het algoritme van Google) met **6
decimalen**. De afstand van een verbinding is de som van de lijnlengtes.

**Knooppunten** zijn per regel de eindpunten van de verbindingen in dit pakket. Een knooppunt of
verbinding kan in meer dan één pakket voorkomen (op de grens van regio's). Lezers voegen samen op
knooppunt-id; een verbinding is gelijk als van, naar, nummers en lijnen gelijk zijn.

**Nummers** zijn per netwerk uniek, niet per land. Het id is de identiteit, het nummer is het label.

## Regels voor lezers
Het pakket komt van buiten en wordt niet vertrouwd:
- weiger een onbekend `format`;
- controleer typen, lengtes en coördinaatbereik (breedtegraad ±90, lengtegraad ±180);
- begrens het aantal knooppunten, verbindingen en lijnen, en de grootte na uitpakken;
- controleer de SHA-256 uit `manifest.json` vóór het uitpakken.

De referentie-implementatie staat in `tool/lib/knp.dart`.

## `manifest.json`

```json
{
  "format": 1,
  "license": "ODbL-1.0",
  "attribution": "© OpenStreetMap-bijdragers (ODbL), data via Geofabrik",
  "regions": [
    {
      "id": "nl-utrecht", "name": "Nederland - Utrecht", "country": "nl",
      "bbox": [51.85, 4.79, 52.31, 5.63],
      "osmTimestamp": "2026-10-20T20:23:47Z",
      "url": "https://github.com/appsbeheerder/knooppunten-data/releases/download/data-latest/nl-utrecht.knp.gz",
      "bytes": 276674, "sha256": "...", "junctions": 732, "connections": 1070
    }
  ]
}
```
