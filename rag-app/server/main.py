"""
rag-app server — a 3-rétegű alkalmazás közepe.

A böngésző ide küldi a chat üzenetet. Itt:
  1. (opcionális) RAG Engine-től dokumentumrészleteket kérünk
  2. az LLM-et (Gemini, Agent Platform) streamelve hívjuk
  3. a választ és a tanítási debug eseményeket SSE-n küldjük vissza

Authentikáció: helyben ADC, Cloud Run-on a szolgáltatás service accountja.
"""

import json
import re
import time
import warnings

import agentplatform
from agentplatform import types as ap_types
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from google.cloud import storage
from google import genai
from google.genai import types as genai_types
from pydantic import BaseModel, Field

import config

# A RAG Engine Python SDK jelenleg experimental — a laborban ez várható.
warnings.filterwarnings("ignore", message=".*rag module is experimental.*")

app = FastAPI(title="rag-app-server")

# A client másik origin-ről fut (localhost:3000 vagy másik Cloud Run URL).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# LLM: globális modell (gemini-3.5-flash-lite) → location = "global"
llm_client = genai.Client(
    enterprise=True,
    project=config.PROJECT_ID,
    location=config.LLM_LOCATION,
)

# RAG Engine: regionális (alapból europe-west1)
rag_client = agentplatform.Client(
    project=config.PROJECT_ID,
    location=config.rag_location(),
)

SYSTEM_PROMPT_RAG = (
    "Te egy céges dokumentum-asszisztens vagy. Magyarul, röviden válaszolj. "
    "Dokumentumrészleteket kaptál: olvasd el az összeset. "
    "A rövid példakérdés, tartalomjegyzék vagy beállítási lista nem a válasz. "
    "Ha van hosszabb, magyarázó bekezdés a fogalomról, azt használd — "
    "akkor is, ha más részletekben csak példaként szerepel a szó. "
    "Csak akkor mondd, hogy nincs információ, ha egyik részlet sem magyarázza a fogalmat."
)

SYSTEM_PROMPT_SMALLTALK = (
    "Te egy céges dokumentum-asszisztens vagy. Magyarul, röviden válaszolj. "
    "A felhasználó most nem új kérdést tett fel (köszönés, köszönet, oké). "
    "Egy-két udvarias mondat elég. Ne ismételd az előző magyarázatot, "
    "ne kezdj új témát, és ne hivatkozz dokumentumokra."
)

SYSTEM_PROMPT_LLM = (
    "Te egy segítőkész asszisztens vagy. Magyarul, röviden válaszolj. "
    "A RAG ki van kapcsolva: nincsenek céges dokumentumok. "
    "Általános tudásod alapján válaszolj. "
    "Ne hivatkozz belső szabályzatra, dokumentumrészletre, és ne mondd, "
    "hogy a dokumentumokban nincs információ."
)


class ChatMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    message: str
    history: list[ChatMessage] = Field(default_factory=list)
    use_rag: bool = True


def sse(event: str, data: dict) -> str:
    """Egy Server-Sent Event sor. A böngésző ezt parse-olja."""
    return f"event: {event}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


def is_quota_error(exc: Exception) -> bool:
    text = str(exc)
    return "429" in text or "RESOURCE_EXHAUSTED" in text


def quota_message() -> str:
    return (
        "429 RESOURCE_EXHAUSTED: a Google most nem adott kapacitást "
        f"(modell: {config.LLM_MODEL}). Várj 30–60 másodpercet, és küldd újra. "
        "Képzésen a gemini-3.5-flash-lite szokott menni; az újabb Flash modelleknek "
        "kisebb a kvótája. Console: IAM & Admin → Quotas → generate_content."
    )


def is_smalltalk(message: str) -> bool:
    """Köszönöm / oké / szia: ne fusson RAG-keresés, különben random doksi jön vissza."""
    return bool(
        re.match(
            r"(?is)^\s*("
            r"köszönöm(\s+szépen)?|köszi(\s+szépen)?|koszi|thanks|thx|thank you|"
            r"oké?|oke|rendben|jó|persze|igen|nem|aha|"
            r"szia|helló|hello|szevasz|jó\s+napot|jó\s+reggelt|viszlát|bye|"
            r"szuper|tökéletes|király|nagyszerű"
            r")[\s!.?]*$",
            message.strip(),
        )
    )


def rag_search_text(question: str) -> str:
    """A nyers „Mi az a Webhook?” gyakran a példakérdés-chunkot találja meg, nem a definíciót."""
    q = question.strip()
    match = re.match(r"(?i)^\s*mi\s+az\s+(?:a|az)?\s*(.+?)\s*\??\s*$", q)
    if match:
        term = match.group(1).strip(" ?!.")
        return f"{term}\n{term} definíció magyarázat jelentése működés"
    return q


def prefer_explanatory(chunks: list[dict]) -> list[dict]:
    """A rövid FAQ / címsor darabok menjenek hátra, a magyarázó bekezdések előre."""
    return sorted(chunks, key=lambda c: len(c.get("text") or ""), reverse=True)


def retrieve(question: str) -> list[dict]:
    """RAG Engine: vektoros keresés, ha lehet kulcsszóval kiegészítve, majd ranker."""
    ranking = None
    if config.RAG_RANKER:
        ranking = genai_types.RagRetrievalConfigRanking(
            rank_service=genai_types.RagRetrievalConfigRankingRankService(
                model_name=config.RAG_RANKER
            )
        )

    def call(hybrid: bool):
        retrieval = {"top_k": config.RAG_TOP_K}
        if ranking:
            retrieval["ranking"] = ranking
        if hybrid:
            retrieval["hybrid_search"] = genai_types.RagRetrievalConfigHybridSearch(
                alpha=0.4
            )
        return rag_client.rag.retrieve_contexts(
            vertex_rag_store=genai_types.VertexRagStore(
                rag_resources=[
                    genai_types.VertexRagStoreRagResource(rag_corpus=config.RAG_CORPUS)
                ]
            ),
            query=ap_types.RagQuery(
                text=question,
                rag_retrieval_config=genai_types.RagRetrievalConfig(**retrieval),
            ),
        )

    try:
        response = call(hybrid=True)
    except Exception as exc:
        if is_quota_error(exc):
            raise
        response = call(hybrid=False)

    chunks = []
    for ctx in getattr(getattr(response, "contexts", None), "contexts", []) or []:
        text = getattr(ctx, "text", None) or ""
        if not text:
            chunk = getattr(ctx, "chunk", None)
            text = getattr(chunk, "text", "") if chunk is not None else ""
        chunks.append(
            {
                "source": getattr(ctx, "source_uri", "")
                or getattr(ctx, "source_display_name", ""),
                "text": text,
                "distance": getattr(ctx, "distance", None),
                "score": getattr(ctx, "score", None),
            }
        )
    return chunks


_ACCENT = str.maketrans("áéíóöőúüű", "aeioouuuu")


def _fold(text: str) -> str:
    return (text or "").lower().translate(_ACCENT)


def _tokens(text: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]{3,}", _fold(text)))


def _token_hit(query_token: str, doc_token: str) -> bool:
    if query_token == doc_token:
        return True
    if len(query_token) >= 4 and len(doc_token) >= 4:
        return query_token.startswith(doc_token) or doc_token.startswith(query_token)
    return False


def _overlap_count(query_tokens: set[str], text: str) -> int:
    doc_tokens = _tokens(text)
    hits = 0
    for query_token in query_tokens:
        if any(_token_hit(query_token, doc_token) for doc_token in doc_tokens):
            hits += 1
    return hits


def relevant_sources(question: str, chunks: list[dict], max_docs: int = 3) -> list[dict]:
    """Csak a kérdéshez illő források. A top_k találatban sok irreleváns doksi is van."""
    query_tokens = _tokens(question)
    by_uri: dict[str, dict] = {}
    for index, chunk in enumerate(chunks):
        uri = (chunk.get("source") or "").strip()
        if not uri:
            continue
        score = chunk.get("score")
        try:
            score = float(score) if score is not None else None
        except (TypeError, ValueError):
            score = None
        name = uri.rstrip("/").rsplit("/", 1)[-1]
        current = by_uri.get(uri)
        if current is None:
            by_uri[uri] = {
                "uri": uri,
                "name": name,
                "score": score,
                "index": index,
                "text": chunk.get("text") or "",
            }
            continue
        current["text"] += "\n" + (chunk.get("text") or "")
        current["index"] = min(current["index"], index)
        if score is not None and (current["score"] is None or score > current["score"]):
            current["score"] = score

    docs = list(by_uri.values())
    if not docs:
        return []

    needed = 2 if len(query_tokens) >= 2 else 1
    related = [
        doc
        for doc in docs
        if _overlap_count(query_tokens, f"{doc['name']}\n{doc['text']}") >= needed
    ]
    if related:
        name_hits = [_overlap_count(query_tokens, doc["name"]) for doc in related]
        best_name = max(name_hits)
        if best_name >= 1:
            related = [
                doc for doc, hits in zip(related, name_hits) if hits == best_name
            ]
    docs.sort(
        key=lambda doc: (
            -(doc["score"] if doc["score"] is not None else -1e9),
            doc["index"],
        )
    )
    picked = related or docs[:1]

    has_scores = any(doc["score"] is not None for doc in picked)
    if has_scores:
        picked.sort(
            key=lambda doc: (
                -(doc["score"] if doc["score"] is not None else -1e9),
                doc["index"],
            )
        )
        best = next((doc["score"] for doc in picked if doc["score"] is not None), None)
        if best is not None and best > 0:
            picked = [
                doc
                for doc in picked
                if doc["score"] is not None and doc["score"] >= best * 0.85
            ]
    else:
        picked.sort(key=lambda doc: doc["index"])
        picked = picked[:1]

    return [{"uri": doc["uri"], "name": doc["name"]} for doc in picked[:max_docs]]


def to_history(history: list[ChatMessage]) -> list[genai_types.Content]:
    """Előző körök a Chat sessionnek. Az aktuális kérdés külön megy."""
    contents = []
    for msg in history:
        role = "user" if msg.role == "user" else "model"
        contents.append(
            genai_types.Content(role=role, parts=[genai_types.Part(text=msg.content)])
        )
    return contents


def build_user_text(message: str, chunks: list[dict] | None) -> str:
    if not chunks:
        return message
    parts = [
        f"Felhasználó kérdése:\n{message}",
        "",
        "A RAG Engine az alábbi dokumentumrészleteket adta vissza:",
    ]
    for i, chunk in enumerate(chunks, start=1):
        source = chunk.get("source") or "(nincs forrás)"
        parts.append(f"\n--- {i}. részlet ({source}) ---\n{chunk.get('text', '')}")
    parts.append(
        "\nOlvasd el az összes részletet. Válaszolj a kérdésre ezek alapján. "
        "Ha a definíció vagy a magyarázat valamelyik részletben megvan, azt használd, "
        "akkor is, ha más részletekben csak példaként szerepel a szó. "
        "Csak akkor mondd, hogy nincs elég információ, ha egyik részlet sem tartalmazza a választ."
    )
    return "\n".join(parts)


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/info")
def info():
    """A UI-nak: milyen modell / régió van beállítva (titkot nem adunk ki)."""
    return {
        "model": config.LLM_MODEL,
        "llm_location": config.LLM_LOCATION,
        "rag_location": config.rag_location(),
        "rag_configured": bool(config.RAG_CORPUS),
    }


@app.get("/source")
def read_source(uri: str):
    """A RAG gs:// forrásának teljes szövege — a client ebből mutatja a dokumentumot."""
    if not uri.startswith("gs://"):
        raise HTTPException(400, "Csak gs:// hivatkozás nyitható.")
    path = uri[5:]
    bucket_name, _, blob_name = path.partition("/")
    if not bucket_name or not blob_name:
        raise HTTPException(400, "Hibás gs:// URI.")
    blob = storage.Client(project=config.PROJECT_ID).bucket(bucket_name).blob(blob_name)
    return {
        "uri": uri,
        "name": blob_name.rsplit("/", 1)[-1],
        "text": blob.download_as_text(encoding="utf-8"),
    }


@app.post("/chat")
def chat(req: ChatRequest):
    """SSE stream: debug események + tokenek. POST, mert a history a body-ban van."""

    def events():
        try:
            yield sse(
                "debug",
                {
                    "kind": "backend",
                    "title": "A client üzenete megérkezett a serverre",
                    "detail": {
                        "path": "POST /chat",
                        "use_rag": req.use_rag,
                        "message": req.message,
                        "history_length": len(req.history),
                        "project": config.PROJECT_ID,
                    },
                },
            )

            chunks = []
            cited = []
            smalltalk = is_smalltalk(req.message)
            if req.use_rag and smalltalk:
                yield sse(
                    "debug",
                    {
                        "kind": "rag",
                        "title": "RAG kihagyva: ez nem dokumentumkérdés",
                        "detail": {"skipped": True, "reason": "smalltalk", "message": req.message},
                    },
                )
            elif req.use_rag:
                if not config.RAG_CORPUS:
                    yield sse(
                        "debug",
                        {
                            "kind": "rag",
                            "title": "RAG kihagyva: RAG_CORPUS nincs beállítva",
                            "detail": {"rag_corpus": ""},
                        },
                    )
                    yield sse(
                        "token",
                        {
                            "text": "A RAG be van kapcsolva, de a szerveren nincs RAG_CORPUS. "
                            "Állítsd be a rag-app/.env fájlban."
                        },
                    )
                    yield sse("done", {})
                    return

                search = rag_search_text(req.message)
                yield sse(
                    "debug",
                    {
                        "kind": "rag",
                        "title": "RAG Engine hívás indul",
                        "detail": {
                            "method": "rag.retrieve_contexts",
                            "corpus": config.RAG_CORPUS,
                            "location": config.rag_location(),
                            "top_k": config.RAG_TOP_K,
                            "ranker": config.RAG_RANKER,
                            "user_question": req.message,
                            "search_text": search,
                        },
                    },
                )
                chunks = retrieve(search)
                cited = relevant_sources(req.message, chunks)
                chunks = prefer_explanatory(chunks)
                yield sse(
                    "debug",
                    {
                        "kind": "rag",
                        "title": "RAG Engine válasz",
                        "detail": {
                            "chunk_count": len(chunks),
                            "cited_count": len(cited),
                            "cited": cited,
                            "chunks": chunks,
                        },
                    },
                )
            else:
                yield sse(
                    "debug",
                    {
                        "kind": "rag",
                        "title": "RAG ki van kapcsolva",
                        "detail": {"skipped": True},
                    },
                )

            user_text = build_user_text(req.message, chunks if req.use_rag and not smalltalk else None)
            if not req.use_rag:
                system_prompt = SYSTEM_PROMPT_LLM
            elif smalltalk:
                system_prompt = SYSTEM_PROMPT_SMALLTALK
            else:
                system_prompt = SYSTEM_PROMPT_RAG
            llm_config = genai_types.GenerateContentConfig(
                system_instruction=system_prompt,
                automatic_function_calling=genai_types.AutomaticFunctionCallingConfig(
                    disable=True
                ),
            )

            yield sse(
                "debug",
                {
                    "kind": "llm",
                    "title": "LLM hívás indul (stream)",
                    "detail": {
                        "sdk": "google.genai",
                        "enterprise": True,
                        "model": config.LLM_MODEL,
                        "location": config.LLM_LOCATION,
                        "method": "chats.send_message_stream",
                        "use_rag": req.use_rag,
                        "system_instruction": system_prompt,
                        "user_text": user_text,
                    },
                },
            )

            session = llm_client.chats.create(
                model=config.LLM_MODEL,
                config=llm_config,
                history=to_history(req.history),
            )
            try:
                stream = session.send_message_stream(user_text)
            except Exception as exc:
                if not is_quota_error(exc):
                    raise
                time.sleep(8)
                stream = session.send_message_stream(user_text)
            for chunk in stream:
                text = getattr(chunk, "text", None)
                if text:
                    yield sse("token", {"text": text})

            if req.use_rag and cited:
                yield sse("sources", {"items": cited})
            yield sse("done", {})
        except Exception as exc:
            yield sse("debug", {"kind": "error", "title": "Hiba", "detail": {"error": str(exc)}})
            text = quota_message() if is_quota_error(exc) else f"Hiba: {exc}"
            yield sse("token", {"text": text})
            yield sse("done", {})

    return StreamingResponse(
        events(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
