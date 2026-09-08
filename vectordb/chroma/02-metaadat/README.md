# Chroma Vektoralapú adatbázis használat metaadatokkal

Ez a rövid kód bemutatja, hogyan lehet alapvetően használni a Chroma vektoralapú adatbázist. Itt metaadatokkal is kiegészítjük a dokumentumokat. Emellett nem csak memóriában tároljuk az adatokat, hanem helyileg is létrehozunk egy collection-t.
A hivatalos dokumentáción alapul: https://docs.trychroma.com/docs/overview/getting-started

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["Szöveg + metadata"]) --> B(["Chroma<br/>lemezre"])
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

Ezután telepíthetjük a Chroma könyvtárat:

```bash
pip install chromadb
```

2. Kód futtatása:

```bash
python chroma.py
```


## Adatok megtekintése

Használjuk a chroma cli-t az adatok megtekintéséhez:

```bash
chroma browse metaadat_collection --path ./chroma_data
```