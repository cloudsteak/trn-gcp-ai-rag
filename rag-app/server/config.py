"""Környezeti beállítások. Helyben a .env fájlból, Cloud Run-on a szolgáltatás env változóiból jönnek."""

import os
from pathlib import Path

from dotenv import load_dotenv

# A rag-app/.env fájlt olvassuk, ha létezik (helyi futtatás).
load_dotenv(Path(__file__).resolve().parent.parent / ".env")

PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "")
LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "europe-west1")

LLM_LOCATION = os.environ.get("LLM_LOCATION", "global")
LLM_MODEL = os.environ.get("LLM_MODEL", "gemini-3.5-flash-lite")

RAG_CORPUS = os.environ.get("RAG_CORPUS", "")
RAG_TOP_K = int(os.environ.get("RAG_TOP_K", "10"))
RAG_RANKER = os.environ.get("RAG_RANKER", "semantic-ranker-default@latest")


def rag_location() -> str:
    """A RAG Engine regionális. A corpus névből olvassuk ki, különben LOCATION."""
    parts = RAG_CORPUS.split("/")
    if "locations" in parts:
        i = parts.index("locations")
        if i + 1 < len(parts):
            return parts[i + 1]
    return LOCATION
