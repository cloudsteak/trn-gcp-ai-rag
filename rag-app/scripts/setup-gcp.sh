#!/usr/bin/env bash
# GCP előkészítés: API-k, Artifact Registry, service accountok, IAM.
# Ezt EGYSZER kell futtatni egy projekten, a Cloud Run (Console) előtt.
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

echo "Projekt: $GOOGLE_CLOUD_PROJECT"
echo "Régió:   $GOOGLE_CLOUD_LOCATION"
gcloud config set project "$GOOGLE_CLOUD_PROJECT"

echo
echo "1) Szükséges Google Cloud API-k bekapcsolása"
gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  aiplatform.googleapis.com \
  discoveryengine.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com

echo
echo "2) Artifact Registry tárhely a Docker image-eknek"
if gcloud artifacts repositories describe "$ARTIFACT_REGISTRY_REPO" \
    --location="$GOOGLE_CLOUD_LOCATION" >/dev/null 2>&1; then
  echo "   Már létezik: $ARTIFACT_REGISTRY_REPO"
else
  gcloud artifacts repositories create "$ARTIFACT_REGISTRY_REPO" \
    --repository-format=docker \
    --location="$GOOGLE_CLOUD_LOCATION" \
    --description="rag-app Cloud Run image-ek"
fi

SERVER_SA="${SERVER_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
CLIENT_SA="${CLIENT_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
PROJECT_NUMBER="$(gcloud projects describe "$GOOGLE_CLOUD_PROJECT" --format='value(projectNumber)')"
DEFAULT_BUILD="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"
COMPUTE_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

create_sa() {
  local email="$1"
  local name="${email%%@*}"
  local display="$2"
  if gcloud iam service-accounts describe "$email" >/dev/null 2>&1; then
    echo "   Már létezik: $email"
  else
    gcloud iam service-accounts create "$name" --display-name="$display"
  fi
}

echo
echo "3) Service accountok"
create_sa "$SERVER_SA" "rag-app server (LLM + RAG)"
create_sa "$CLIENT_SA" "rag-app client"

bind_project() {
  local member="$1"
  local role="$2"
  gcloud projects add-iam-policy-binding "$GOOGLE_CLOUD_PROJECT" \
    --member="serviceAccount:${member}" \
    --role="$role" \
    --condition=None \
    --quiet >/dev/null
}

echo
echo "4) Jogosultságok (IAM)"
echo "   Server SA: Agent Platform (LLM + RAG) hívása + dokumentumok olvasása"
bind_project "$SERVER_SA" "roles/aiplatform.user"
bind_project "$SERVER_SA" "roles/logging.logWriter"
bind_project "$SERVER_SA" "roles/storage.objectViewer"
bind_project "$CLIENT_SA" "roles/logging.logWriter"

echo "   Alap Cloud Build / Compute SA: image build és Cloud Run deploy"
for sa in "$DEFAULT_BUILD" "$COMPUTE_SA"; do
  bind_project "$sa" "roles/run.admin"
  bind_project "$sa" "roles/artifactregistry.writer"
  bind_project "$sa" "roles/logging.logWriter"
  bind_project "$sa" "roles/cloudbuild.builds.builder"
  bind_project "$sa" "roles/storage.objectAdmin"
done

echo "   A Cloud Build impersonálhatja a runtime SA-kat"
for runtime in "$SERVER_SA" "$CLIENT_SA"; do
  for actor in "$DEFAULT_BUILD" "$COMPUTE_SA"; do
    gcloud iam service-accounts add-iam-policy-binding "$runtime" \
      --member="serviceAccount:${actor}" \
      --role="roles/iam.serviceAccountUser" \
      --quiet >/dev/null
  done
done

echo
echo "Kész. Következő lépések:"
echo "  - Helyi futtatás:  ./scripts/run-local.sh"
echo "  - Utána Cloud Run: Console → Connect repository (először server, aztán client)"
echo
echo "Service accountok:"
echo "  server: $SERVER_SA"
echo "  client: $CLIENT_SA"
