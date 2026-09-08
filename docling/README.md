# Docling

Docling egy eszköz, amely segít a dokumentumok vektoralapú adatbázisok számára történő előkészítésében. A Docling egy új generációs, nyílt forráskódú megoldás, ami nem csak kiolvassa a szöveget a fájlokból, hanem látja és érti is az oldalak szerkezetét (Layout Analysis).

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["PDF / DOCX / PPTX"]) --> B(["Docling<br/>Layout Analysis"])
  B --> C(["Markdown / chunkok"])
  C --> D(["RAG / vektor DB"])

  classDef file fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef tool fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef text fill:#fde047,stroke:#ca8a04,stroke-width:3px,color:#0f172a
  classDef rag fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a

  class A file
  class B tool
  class C text
  class D rag

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#c2410c,stroke-width:3px
  linkStyle 2 stroke:#047857,stroke-width:3px
```


## Kész eszköz

Itt találsz egy előre elkészített eszközt, amivel Te is könnyedén konvertálhatod a dokumentumaidat vektoralapú adatbázisok számára megfelelő formátumba.

[CloudMentor RAG Converter](https://github.com/cloudsteak/docling-rag-converter.git)

## További hasznos linkek:

- [Docling cikk](https://cloudmentor.hu/docling-igy-keszits-tokeletes-adatot-barmilyen-rag-hez/)
- [Docling hivatalos oldal](https://docling.ai)
