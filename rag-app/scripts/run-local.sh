#!/usr/bin/env bash
# Helyi futtatás Docker nélkül (Mac / Linux).
# Server: uv + FastAPI  |  Client: Python HTTP server
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Hiányzik a(z) '$1' parancs. A README telepítési része leírja, hogyan tedd fel."
    exit 1
  }
}

need gcloud
need uv
need python3

echo "ADC (helyi Google bejelentkezés) ellenőrzése"
if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Még nincs ADC. Egy böngészős bejelentkezés következik."
  echo "Ugyanazzal a Google-fiókkal lépj be, aki a projekt tagja."
  gcloud auth application-default login
fi
if ! gcloud auth application-default set-quota-project "$GOOGLE_CLOUD_PROJECT"; then
  echo
  echo "A quota-project beállítása nem sikerült (GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT)."
  echo "Gyakori ok: az ADC-ben másik Google-fiók van, mint aki a projekt Owner-e."
  echo "  gcloud auth list"
  echo "  gcloud projects list"
  echo "  gcloud auth application-default login"
  echo "Részletek: rag-app/README.md → „serviceusage.services.use”"
  exit 1
fi
gcloud config set project "$GOOGLE_CLOUD_PROJECT"

cp "$ROOT/client/config.example.js" "$ROOT/client/config.js"

echo
echo "Server:  http://localhost:8080"
echo "Client:  http://localhost:3000   ← ezt nyisd meg a böngészőben"
echo "Kilépés: Ctrl+C"
echo

cleanup() {
  kill "${SERVER_PID:-}" "${CLIENT_PID:-}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

(
  cd "$ROOT/server"
  uv sync --frozen
  uv run uvicorn main:app --reload --host 127.0.0.1 --port 8080
) &
SERVER_PID=$!

python3 -m http.server 3000 --directory "$ROOT/client" >/dev/null &
CLIENT_PID=$!

wait "$SERVER_PID"
