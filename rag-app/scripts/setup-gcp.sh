#!/usr/bin/env bash
# GCP előkészítés / pótlás: API-k, service accountok, IAM.
# Nyugodtan futtasd újra: ami megvan, azt kihagyja; ami hiányzik, azt berakja.
# Saját Artifact Registry tárat NEM hoz létre: a Console Cloud Build a sajátját használja.
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/load-env.sh"

echo "Projekt: $GOOGLE_CLOUD_PROJECT"
echo "Régió:   $GOOGLE_CLOUD_LOCATION"
echo "A hiányzó beállításokat pótolja, a meglévőket nem bántja."
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
    echo "   Létrehozva: $email"
  fi
}

echo
echo "2) Service accountok"
create_sa "$SERVER_SA" "rag-app server (LLM + RAG)"
create_sa "$CLIENT_SA" "rag-app client"

bind_project() {
  local member="$1"
  local role="$2"
  echo "   $role  →  $member"
  gcloud projects add-iam-policy-binding "$GOOGLE_CLOUD_PROJECT" \
    --member="serviceAccount:${member}" \
    --role="$role" \
    --condition=None \
    --quiet >/dev/null
}

echo
echo "3) Jogosultságok (IAM) — a hiányzó szerepek felkerülnek"
echo "   Server SA: Agent Platform (LLM + RAG), ranker, dokumentumok"
bind_project "$SERVER_SA" "roles/aiplatform.user"
bind_project "$SERVER_SA" "roles/discoveryengine.viewer"
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
echo "Kész. Ami hiányzott, az most bent van."
echo "  Ha a Cloud Run client már megy: várj ~20 mp, küldd újra a kérdést. Új deploy nem kell."
echo "  Ha még helyben vagy:  ./scripts/run-local.sh"
echo "  Ha még nincs Cloud Run: Console → Connect repository (először server, aztán client)"
echo
echo "Service accountok:"
echo "  server: $SERVER_SA"
echo "  client: $CLIENT_SA"
