#!/usr/bin/env bash
# Közös: a rag-app/.env betöltése. Minden más script ezt source-olja.
# Nem `source`-oljuk a fájlt: a macOS alap Bash 3.2-n a process substitution
# (source <(sed ...)) gyakran üresen hagyja a változókat.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Nincs .env fájl."
  echo "Másold át a példát, és töltsd ki:"
  echo "  cp \"$ROOT/.env.example\" \"$ROOT/.env\""
  exit 1
fi

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ -z "$line" || "$line" == \#* ]] && continue
  [[ "$line" != *=* ]] && continue
  key="${line%%=*}"
  value="${line#*=}"
  key="${key%"${key##*[![:space:]]}"}"
  key="${key#"${key%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value#\"}"
  value="${value%\"}"
  value="${value#\'}"
  value="${value%\'}"
  export "$key=$value"
done < "$ENV_FILE"

if [[ -z "${GOOGLE_CLOUD_PROJECT:-}" || "$GOOGLE_CLOUD_PROJECT" == "REPLACE_WITH_PROJECT_ID" ]]; then
  echo "A .env fájlban a GOOGLE_CLOUD_PROJECT még nincs kitöltve."
  echo "A fájl: $ENV_FILE"
  exit 1
fi
