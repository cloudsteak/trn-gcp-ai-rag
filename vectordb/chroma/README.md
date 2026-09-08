# Chroma vektor adatbázis

Két példa:

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A(["01-alap<br/>memória"]) --> C(["Chroma"])
  B(["02-metaadat<br/>lemez + szűrés"]) --> C

  classDef basic fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef meta fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef db fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a

  class A basic
  class B meta
  class C db

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#c2410c,stroke-width:3px
```

1. Egyszerű példa a Chroma vektor adatbázis használatára. [01-alap](01-alap/README.md)
2. Metaadattal kiegészített példa a Chroma vektor adatbázis használatára. [02-metaadat](02-metaadat/README.md)
