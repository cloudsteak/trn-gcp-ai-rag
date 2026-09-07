#!/usr/bin/env bash
# Feltölti a servert és a clientet Cloud Run-ra (gcloud run deploy --source).
# A Cloud Build-et a gcloud hívja meg, cloudbuild.yaml nem kell.
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

SERVER_SA="${SERVER_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
CLIENT_SA="${CLIENT_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

gcloud config set project "$GOOGLE_CLOUD_PROJECT"

echo "1) Server deploy"
gcloud run deploy "$CLOUD_RUN_SERVER_NAME" \
  --source "$ROOT/server" \
  --region "$GOOGLE_CLOUD_LOCATION" \
  --service-account "$SERVER_SA" \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --timeout 300 \
  --set-env-vars "GOOGLE_CLOUD_PROJECT=${GOOGLE_CLOUD_PROJECT},GOOGLE_CLOUD_LOCATION=${GOOGLE_CLOUD_LOCATION},LLM_LOCATION=${LLM_LOCATION},LLM_MODEL=${LLM_MODEL},RAG_CORPUS=${RAG_CORPUS},RAG_TOP_K=${RAG_TOP_K},RAG_RANKER=${RAG_RANKER}"

SERVER_URL="$(gcloud run services describe "$CLOUD_RUN_SERVER_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" \
  --format='value(status.url)')"

echo
echo "2) Client deploy  (API_URL=$SERVER_URL)"
gcloud run deploy "$CLOUD_RUN_CLIENT_NAME" \
  --source "$ROOT/client" \
  --region "$GOOGLE_CLOUD_LOCATION" \
  --service-account "$CLIENT_SA" \
  --allow-unauthenticated \
  --memory 256Mi \
  --cpu 1 \
  --timeout 60 \
  --set-env-vars "API_URL=${SERVER_URL}"

CLIENT_URL="$(gcloud run services describe "$CLOUD_RUN_CLIENT_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" \
  --format='value(status.url)')"

echo
echo "Kész."
echo "  Server: $SERVER_URL"
echo "  Client (ezt nyisd meg): $CLIENT_URL"
