#!/usr/bin/env bash
# Helyi futtatás Docker Compose-szal. ADC-t a gcloud mappa mountolásával adjuk be.
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Hiányzik a(z) '$1' parancs."
    exit 1
  }
}
need docker
need gcloud

if ! gcloud auth application-default print-access-token >/dev/null 2>&1; then
  echo "Még nincs ADC. Ugyanazzal a Google-fiókkal lépj be, aki a projekt tagja."
  gcloud auth application-default login
fi
if ! gcloud auth application-default set-quota-project "$GOOGLE_CLOUD_PROJECT"; then
  echo
  echo "A quota-project beállítása nem sikerült (GOOGLE_CLOUD_PROJECT=$GOOGLE_CLOUD_PROJECT)."
  echo "Részletek: rag-app/README.md → „serviceusage.services.use”"
  exit 1
fi

export GCLOUD_CONFIG_DIR="${CLOUDSDK_CONFIG:-$HOME/.config/gcloud}"
if [[ ! -d "$GCLOUD_CONFIG_DIR" ]]; then
  echo "Nem találom a gcloud config mappát: $GCLOUD_CONFIG_DIR"
  exit 1
fi

echo "Client: http://localhost:3000"
echo "Server: http://localhost:8080"
docker compose -f "$ROOT/docker-compose.yml" up --build
