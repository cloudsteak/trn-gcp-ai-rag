# AI a céges dokumentációban - RAG alapok kezdőknek

Kiegészítő segédlet a Mentor Klub "AI a céges dokumentációban - RAG alapok kezdőknek" című képzéséhez.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["Docling<br/>dokumentum-előkészítés"]) --> B(["Vektor DB / pipeline"])
  B --> C(["rag-app<br/>chat + RAG Engine"])

  classDef prep fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef store fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a
  classDef app fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a

  class A prep
  class B store
  class C app

  linkStyle 0 stroke:#c2410c,stroke-width:3px
  linkStyle 1 stroke:#6d28d9,stroke-width:3px
```

## Vektor adatbázis

Egy helyileg futtatható, chroma alapú vektor adatbázis, amely lehetővé teszi a dokumentumok gyors és hatékony keresését vektoralapú lekérdezések segítségével.

Ehhez találsz két példás is: [vectordb/chroma](vectordb/chroma/README.md)


## Docling

A Docling egy eszköz, amely segít a dokumentumok vektoralapú adatbázisok számára történő előkészítésében.

Ehhez itt találsz segédletet: [docling](docling/README.md)


## RAG pipeline bemutatása

A `rag-pipeline` mappa tartalmaz különböző típusú fájlokat, amelyeket bármilyen RAG rendszerbe betölthetünk. 
Előtte azonban azokat át kell alakítanunk a RAG számára értelmezhwtő és kezelhető formátumra.
A Doclong segítségével ezeket a fájlokat könnyen átalakíthatjuk.

**[rag-pipeline](rag-pipeline)**

## RAG chat alkalmazás (3-rétegű)

A `rag-app` mappa egy teljes chat alkalmazás: böngészős felület, FastAPI backend, Gemini (Agent Platform) és a korábban beállított RAG Engine.

Helyben (Mac / Windows / Linux) és Cloud Run-on is futtatható. Részletes, kezdőknek szóló telepítés:

**[rag-app/README.md](rag-app/README.md)**
