#!/usr/bin/env bash
# Törli a scriptjeink által létrehozott Cloud Run szolgáltatásokat és service accountokat.
# Az API-kat NEM kapcsolja ki (más munka is futhat a projekten).
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

gcloud config set project "$GOOGLE_CLOUD_PROJECT"

SERVER_SA="${SERVER_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
CLIENT_SA="${CLIENT_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

echo "1) Cloud Run szolgáltatások törlése"
gcloud run services delete "$CLOUD_RUN_CLIENT_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet || true
gcloud run services delete "$CLOUD_RUN_SERVER_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet || true

echo
echo "2) Service accountok törlése"
for sa in "$SERVER_SA" "$CLIENT_SA"; do
  gcloud iam service-accounts delete "$sa" --quiet || true
done

echo
echo "Kész. A projekt és a bekapcsolt API-k megmaradtak."
echo "A kézzel létrehozott RAG corpust ez a script NEM törli."
echo "A Console Cloud Build saját Artifact Registry tárát (ha van) sem."
