# Chroma Vektoralapú adatbázis használat metaadatokkal

Ez a rövid kód bemutatja, hogyan lehet alapvetően használni a Chroma vektoralapú adatbázist. Itt metaadatokkal is kiegészítjük a dokumentumokat. Emellett nem csak memóriában tároljuk az adatokat, hanem helyileg is létrehozunk egy collection-t.
A hivatalos dokumentáción alapul: https://docs.trychroma.com/docs/overview/getting-started

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