# Chroma Vektoralapú adatbázis használat metaadatokkal

Ez a rövid kód bemutatja, hogyan lehet alapvetően használni a Chroma vektoralapú adatbázist. Itt metaadatokkal is kiegészítjük a dokumentumokat. Emellett nem csak memóriában tároljuk az adatokat, hanem helyileg is létrehozunk egy collection-t.
A hivatalos dokumentáción alapul: https://docs.trychroma.com/docs/overview/getting-started

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["Szöveg + metadata"]) --> B(["Chroma<br/>chroma_data adatfájl"])
  B --> C(["Szűrt keresés"])

  classDef in fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef db fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a
  classDef out fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a

  class A in
  class B db
  class C out

  linkStyle 0 stroke:#c2410c,stroke-width:3px
  linkStyle 1 stroke:#6d28d9,stroke-width:3px
```

## Telepítés és futtatás

1. A virtuális környezetet kell létrehozni és aktiválni:

```bash
python -m venv venv
source venv/bin/activate  # Linux/macOS
venv\Scripts\activate     # Windows
```

Ezután telepíthetjük a Chroma könyvtárat (egy ismert hiba miatt az 1.5.7-es verziót kell használni):

```bash
pip install chromadb==1.5.7
```

2. Kód futtatása:

```bash
python chroma.py
```

## Adatok megtekintése

Használjuk a chroma cli-t az adatok megtekintéséhez.

### Helyi szerver indítása

1. Nyiss egy új terminált vagy parancssort.
2. Navigálj a 02-es mappába: `vectordb/chroma/02-metaadat`
3. Ellenőrizd, hogy a virtuális környezet aktív-e. Ha nem, aktiváld a fent leírt módon.
4. Indítsd el a Chroma helyi szervert a metaadat_collection megtekintéséhez.

```bash
chroma run --path ./chroma_data
```

### Metaadat_collection megtekintése

1. Menjünk vissza az előző terminálhoz, ahol az adatokat betöltöttük.
2. Győződjünk meg róla, hogy a virtuális környezet aktív.
3. Futtassuk a következő parancsot a metaadat_collection megtekintéséhez:

```bash
chroma browse metaadat_collection --local
```

## Ismert problémák

### Hibás 1.5.8 és 1.5.9

A Chroma CLI 1.4.4-es verziója nem képes helyesen olvasni az adatokat. Javasolt az 1.4.3-as verzió használata. Itt elérhető: https://github.com/chroma-core/chroma/releases/tag/cli-1.4.3

Az 1.4.3-as verziót a chromadb csomag 1.5.7-es verziója tartalmazza.

Telepítése:

```bash
pip install chromadb==1.5.7
```

_Megjegyzés: A lényeg, hogy a hiba az 1.5.9-es és az 1.5.8-as verzióban van. Ha lesz újabb verzió, az lehet működni fog._
