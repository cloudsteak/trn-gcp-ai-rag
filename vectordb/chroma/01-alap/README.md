# Alap Chroma Vektoralapú adatbázis használat

Ez a rövid kód bemutatja, hogyan lehet alapvetően használni a Chroma vektoralapú adatbázist.
A hivatalos dokumentáción alapul: https://docs.trychroma.com/docs/overview/getting-started

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["Szövegek"]) --> B(["Chroma<br/>memóriában"])
  B --> C(["Hasonló találatok"])

  classDef in fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef db fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a
  classDef out fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a

  class A in
  class B db
  class C out

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#6d28d9,stroke-width:3px
```


## Telepítés

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
