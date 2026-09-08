# Törli a scriptjeink által létrehozott Cloud erőforrásokat.
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\load-env.ps1"

gcloud config set project $env:GOOGLE_CLOUD_PROJECT

$ServerSa = "$($env:SERVER_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ClientSa = "$($env:CLIENT_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$BuildSa = "rag-app-build@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"

Write-Host "1) Cloud Run szolgáltatások törlése"
gcloud run services delete $env:CLOUD_RUN_CLIENT_NAME --region $env:GOOGLE_CLOUD_LOCATION --quiet
gcloud run services delete $env:CLOUD_RUN_SERVER_NAME --region $env:GOOGLE_CLOUD_LOCATION --quiet

Write-Host ""
Write-Host "2) Artifact Registry tár törlése"
gcloud artifacts repositories delete $env:ARTIFACT_REGISTRY_REPO --location $env:GOOGLE_CLOUD_LOCATION --quiet

Write-Host ""
Write-Host "3) Service accountok törlése"
foreach ($sa in @($ServerSa, $ClientSa, $BuildSa)) {
    gcloud iam service-accounts delete $sa --quiet
}

Write-Host ""
Write-Host "Kész. A projekt és a bekapcsolt API-k megmaradtak."
Write-Host "A kézzel létrehozott RAG corpust ez a script NEM törli."
