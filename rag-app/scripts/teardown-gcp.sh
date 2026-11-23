#!/usr/bin/env bash
# Törli a scriptjeink által létrehozott Cloud Run szolgáltatásokat és service accountokat.
# Az API-kat NEM kapcsolja ki (más munka is futhat a projekten).
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

gcloud config set project "$GOOGLE_CLOUD_PROJECT"

SERVER_SA="${SERVER_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
CLIENT_SA="${CLIENT_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"

echo "1) Cloud Run szolgáltatások törlése"
if gcloud run services delete "$CLOUD_RUN_CLIENT_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet 2>/dev/null; then
  echo "   ✓ $CLOUD_RUN_CLIENT_NAME törölve"
else
  echo "   ⊘ $CLOUD_RUN_CLIENT_NAME nem található (már törölt?)"
fi

if gcloud run services delete "$CLOUD_RUN_SERVER_NAME" \
  --region "$GOOGLE_CLOUD_LOCATION" --quiet 2>/dev/null; then
  echo "   ✓ $CLOUD_RUN_SERVER_NAME törölve"
else
  echo "   ⊘ $CLOUD_RUN_SERVER_NAME nem található (már törölt?)"
fi

echo
echo "2) Service accountok törlése"
for sa in "$SERVER_SA" "$CLIENT_SA"; do
  if gcloud iam service-accounts delete "$sa" --quiet 2>/dev/null; then
    echo "   ✓ $sa törölve"
  else
    echo "   ⊘ $sa nem található (már törölt?)"
  fi
done

echo
echo "Kész. A projekt és a bekapcsolt API-k megmaradtak."
echo "A kézzel létrehozott RAG corpust ez a script NEM törli."
echo "A Console Cloud Build saját Artifact Registry tárát (ha van) sem."
