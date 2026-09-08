# Feltölti a servert és a clientet Cloud Run-ra (gcloud run deploy --source).
# Opcionális: a képzésen a Console Cloud Run varázsló a lényeg.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\load-env.ps1"

$ServerSa = "$($env:SERVER_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ClientSa = "$($env:CLIENT_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"

gcloud config set project $env:GOOGLE_CLOUD_PROJECT

Write-Host "1) Server deploy"
gcloud run deploy $env:CLOUD_RUN_SERVER_NAME `
  --source "$Root\server" `
  --region $env:GOOGLE_CLOUD_LOCATION `
  --service-account $ServerSa `
  --allow-unauthenticated `
  --memory 1Gi `
  --cpu 1 `
  --timeout 300 `
  --set-env-vars "GOOGLE_CLOUD_PROJECT=$($env:GOOGLE_CLOUD_PROJECT),GOOGLE_CLOUD_LOCATION=$($env:GOOGLE_CLOUD_LOCATION),LLM_LOCATION=$($env:LLM_LOCATION),LLM_MODEL=$($env:LLM_MODEL),RAG_CORPUS=$($env:RAG_CORPUS),RAG_TOP_K=$($env:RAG_TOP_K),RAG_RANKER=$($env:RAG_RANKER)"

$ServerUrl = gcloud run services describe $env:CLOUD_RUN_SERVER_NAME `
  --region $env:GOOGLE_CLOUD_LOCATION `
  --format="value(status.url)"

Write-Host ""
Write-Host "2) Client deploy  (API_URL=$ServerUrl)"
gcloud run deploy $env:CLOUD_RUN_CLIENT_NAME `
  --source "$Root\client" `
  --region $env:GOOGLE_CLOUD_LOCATION `
  --service-account $ClientSa `
  --allow-unauthenticated `
  --memory 256Mi `
  --cpu 1 `
  --timeout 60 `
  --set-env-vars "API_URL=$ServerUrl"

$ClientUrl = gcloud run services describe $env:CLOUD_RUN_CLIENT_NAME `
  --region $env:GOOGLE_CLOUD_LOCATION `
  --format="value(status.url)"

Write-Host ""
Write-Host "Kész."
Write-Host "  Server: $ServerUrl"
Write-Host "  Client (ezt nyisd meg): $ClientUrl"
