# Törli a scriptjeink által létrehozott Cloud Run szolgáltatásokat és service accountokat.
$ErrorActionPreference = "Continue"
. "$PSScriptRoot\load-env.ps1"

gcloud config set project $env:GOOGLE_CLOUD_PROJECT

$ServerSa = "$($env:SERVER_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ClientSa = "$($env:CLIENT_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"

Write-Host "1) Cloud Run szolgáltatások törlése"

$serviceNames = @($env:CLOUD_RUN_CLIENT_NAME, $env:CLOUD_RUN_SERVER_NAME)
foreach ($service in $serviceNames) {
    try {
        gcloud run services delete $service --region $env:GOOGLE_CLOUD_LOCATION --quiet 2>$null
        Write-Host "   ✓ $service törölve"
    } catch {
        Write-Host "   ⊘ $service nem található (már törölt?)"
    }
}

Write-Host ""
Write-Host "2) Service accountok törlése"
foreach ($sa in @($ServerSa, $ClientSa)) {
    try {
        gcloud iam service-accounts delete $sa --quiet 2>$null
        Write-Host "   ✓ $sa törölve"
    } catch {
        Write-Host "   ⊘ $sa nem található (már törölt?)"
    }
}

Write-Host ""
Write-Host "Kész. A projekt és a bekapcsolt API-k megmaradtak."
Write-Host "A kézzel létrehozott RAG corpust ez a script NEM törli."
Write-Host "A Console Cloud Build saját Artifact Registry tárát (ha van) sem."
