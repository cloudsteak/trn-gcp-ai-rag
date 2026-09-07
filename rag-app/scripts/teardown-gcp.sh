#!/usr/bin/env bash
# Törli a scriptjeink által létrehozott Cloud Run szolgáltatásokat,
# Artifact Registry tárat és service accountokat.
# Az API-kat NEM kapcsolja ki (más munka is futhat a projekten).
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

gcloud config set project "$GOOGLE_CLOUD_PROJECT"

SERVER_SA="${SERVER_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
CLIENT_SA="${CLIENT_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
BUILD_SA="${BUILD_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

echo "1) Cloud Run szolgáltatások törlése"
gcloud run services delete "$CLOUD_RUN_CLIENT_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet || true
gcloud run services delete "$CLOUD_RUN_SERVER_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet || true

echo
echo "2) Artifact Registry tár törlése (benne az image-ekkel)"
gcloud artifacts repositories delete "$ARTIFACT_REGISTRY_REPO" \
  --location "$GOOGLE_CLOUD_LOCATION" --quiet || true

echo
echo "3) Service accountok törlése"
for sa in "$SERVER_SA" "$CLIENT_SA" "$BUILD_SA"; do
  gcloud iam service-accounts delete "$sa" --quiet || true
done

echo
echo "Kész. A projekt és a bekapcsolt API-k megmaradtak."
echo "A kézzel létrehozott RAG corpust ez a script NEM törli."
