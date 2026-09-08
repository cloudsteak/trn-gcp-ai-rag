# Kiemelt — 5 perc

A labor lépései a [README.md](README.md)-ben vannak. Itt csak az, amiről beszélni érdemes.

---

## 1. Miből áll az app

Három darab. A chat a böngészőben van. A szabályok és a Google-hívások a szerveren. A Google adja a választ, és — ha kell — a céges dokumentumokból keres.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart LR
  A([Böngésző]) --> B([Szerver])
  B --> C([Gemini])
  B --> D([Céges dokumentumok])

  classDef ui fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef app fill:#fbbf24,stroke:#b45309,stroke-width:3px,color:#0f172a
  classDef llm fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a
  classDef rag fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a

  class A ui
  class B app
  class C llm
  class D rag

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#6d28d9,stroke-width:3px
  linkStyle 2 stroke:#047857,stroke-width:3px
```

A böngészőben lévő kódot bárki átírhatja. Ezért az utasítások a modellnek a szerveren vannak, a [`main.py`](server/main.py) elején. Onnan a támadó nem cserélheti ki őket.

A böngésző csak a kérdést küldi. A szerver dönti el, mit kap a modell.

---

## 2. Promptok

A prompt = amit a modellnek mondunk, mielőtt válaszol.

Három van, mind a [`server/main.py`](server/main.py) elején. A szerver [itt választ](server/main.py#L459-L465) közülük egyet.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart TD
  Q([Jön a kérdés]) --> R{RAG be van kapcsolva?}
  R -->|nem| L[SYSTEM_PROMPT_LLM]
  R -->|igen| S{Csak köszönés?}
  S -->|igen| T[SYSTEM_PROMPT_SMALLTALK]
  S -->|nem| G[SYSTEM_PROMPT_RAG]
  L --> M([Gemini])
  T --> M
  G --> M

  classDef start fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef ask fill:#fde047,stroke:#ca8a04,stroke-width:3px,color:#0f172a
  classDef llm fill:#67e8f9,stroke:#0e7490,stroke-width:3px,color:#0f172a
  classDef talk fill:#f9a8d4,stroke:#be185d,stroke-width:3px,color:#0f172a
  classDef rag fill:#86efac,stroke:#15803d,stroke-width:3px,color:#0f172a
  classDef model fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a

  class Q start
  class R,S ask
  class L llm
  class T talk
  class G rag
  class M model

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#0e7490,stroke-width:3px
  linkStyle 2 stroke:#ca8a04,stroke-width:3px
  linkStyle 3 stroke:#be185d,stroke-width:3px
  linkStyle 4 stroke:#15803d,stroke-width:3px
  linkStyle 5 stroke:#0e7490,stroke-width:3px
  linkStyle 6 stroke:#be185d,stroke-width:3px
  linkStyle 7 stroke:#15803d,stroke-width:3px
```

| Prompt | Hol | Mikor | Mit mond |
| --- | --- | --- | --- |
| `SYSTEM_PROMPT_RAG` | [55–62](server/main.py#L55-L62) | Dokumentumkérdés | Olvasd el a kapott részleteket. Magyarul, röviden. |
| `SYSTEM_PROMPT_LLM` | [71–77](server/main.py#L71-L77) | RAG ki | Nincs céges doksi. Általános tudásból válaszolj. |
| `SYSTEM_PROMPT_SMALLTALK` | [64–69](server/main.py#L64-L69) | Köszönöm, szia, oké | Egy-két mondat. Ne keress dokumentumot. |

RAG-nál a talált szöveget a szerver [hozzáírja a kérdéshez](server/main.py#L310-L327). A modell csak ezt látja, nem a teljes irattárat.

---

## 3. Két Google-hívás

Először keresés (ha kell), aztán a modell.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart TD
  A([Kérdés]) --> B{Dokumentum kell?}
  B -->|nem| E([Gemini])
  B -->|igen| C([Keresés a corpusban])
  C --> D([Rerank])
  D --> E
  E --> F([Válasz a chatben])

  classDef start fill:#38bdf8,stroke:#0369a1,stroke-width:3px,color:#0f172a
  classDef ask fill:#fde047,stroke:#ca8a04,stroke-width:3px,color:#0f172a
  classDef search fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a
  classDef rank fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef model fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a
  classDef out fill:#f9a8d4,stroke:#be185d,stroke-width:3px,color:#0f172a

  class A start
  class B ask
  class C search
  class D rank
  class E model
  class F out

  linkStyle 0 stroke:#0369a1,stroke-width:3px
  linkStyle 1 stroke:#6d28d9,stroke-width:3px
  linkStyle 2 stroke:#047857,stroke-width:3px
  linkStyle 3 stroke:#c2410c,stroke-width:3px
  linkStyle 4 stroke:#6d28d9,stroke-width:3px
  linkStyle 5 stroke:#be185d,stroke-width:3px
```

**Keresés** (`retrieve_contexts`): a kérdéshez hasonló bekezdéseket hoz a feltöltött fájlokból. Kb. 10 darabot.

**Rerank** (ugyanebben a hívásban, a keresés után): ezeket a darabokat **újrasorrendezi**, hogy elöl legyen, ami tényleg válasz. A sima keresés gyakran címsort vagy példakérdést talál, nem a magyarázatot.

**Gemini**: megkapja az utasítást + a kérdést + a részleteket, és ír.

A rerank az LLM **előtt** van. Ha a jó bekezdés be se került a találatokba, a modell nem tudja kitalálni.

---

## 4. Jogosultság dokumentumonként

Ma a corpus **egyben** nyitott: a szerver minden fájlt kereshet. A GCP IAM a corpusra vonatkozik, nem a `hr-szabaly.md`-re. Dokumentumszintű ACL-t a RAG Engine **fájl-metadatájával** lehet megcsinálni.

```mermaid
%%{init: {"theme": "base", "themeVariables": {"fontSize": "16px", "lineColor": "#334155"}, "flowchart": {"curve": "basis", "padding": 12}}}%%
flowchart TD
  A([1. Bejelentkezés]) --> B([2. User csoportjai])
  C([3. Feltöltéskor: fájlhoz metadata]) --> D([corpus])
  B --> E([4. retrieve + metadata_filter])
  D --> E
  E --> F([Csak a neki szóló chunkok])
  F --> G([Gemini])
  B --> H([5. GET /source ugyanaz a szabály])

  classDef id fill:#60a5fa,stroke:#1d4ed8,stroke-width:3px,color:#0f172a
  classDef group fill:#22d3ee,stroke:#0e7490,stroke-width:3px,color:#0f172a
  classDef meta fill:#fb923c,stroke:#c2410c,stroke-width:3px,color:#0f172a
  classDef store fill:#a3e635,stroke:#4d7c0f,stroke-width:3px,color:#0f172a
  classDef lock fill:#f87171,stroke:#b91c1c,stroke-width:3px,color:#0f172a
  classDef ok fill:#34d399,stroke:#047857,stroke-width:3px,color:#0f172a
  classDef model fill:#c084fc,stroke:#6d28d9,stroke-width:3px,color:#0f172a
  classDef file fill:#f9a8d4,stroke:#be185d,stroke-width:3px,color:#0f172a

  class A id
  class B group
  class C meta
  class D store
  class E lock
  class F ok
  class G model
  class H file

  linkStyle 0 stroke:#1d4ed8,stroke-width:3px
  linkStyle 1 stroke:#c2410c,stroke-width:3px
  linkStyle 2 stroke:#b91c1c,stroke-width:3px
  linkStyle 3 stroke:#4d7c0f,stroke-width:3px
  linkStyle 4 stroke:#047857,stroke-width:3px
  linkStyle 5 stroke:#6d28d9,stroke-width:3px
  linkStyle 6 stroke:#be185d,stroke-width:3px
```

1. **Identitás.** IAP vagy céges belépés a client elé. A szerver tudja: email, csoportok (`hr`, `it`, …).
2. **Séma a corpuson.** `RagDataSchema`, pl. `audience` (`STRING`) vagy `groups` (`LIST`). Enélkül a szűrő nem értelmezhető.
3. **Metadata minden fájlra.** Feltöltés után `RagMetadata` a `RagFile`-ra: HR-szabályzat → `audience = "hr"`, mindenkinek szóló → `"all"`.
4. **Szűrés kereséskor**, ne utána. A mai [`retrieve()`](server/main.py#L140-L168) `top_k` + ranker. Mellé: `rag_retrieval_config.filter.metadata_filter` (CEL), pl.  
   `audience == "all" || audience == "hr"`  
   Amit a filter kizár, az **be sem kerül** a promptba.
5. **A [`GET /source`](server/main.py#L346-L360) ugyanez.** Ma bármelyik `gs://` URI-t kiadja. ACL nélkül a chat szűrt, a „forrás megnyitása” nem.

A promptba írt „ne idézz HR-t” nem ACL. Ami bekerült a modell elé, azt kiadhatja.
