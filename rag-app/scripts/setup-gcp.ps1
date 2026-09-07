# GCP előkészítés: API-k, Artifact Registry, service accountok, IAM.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\load-env.ps1"

Write-Host "Projekt: $($env:GOOGLE_CLOUD_PROJECT)"
Write-Host "Régió:   $($env:GOOGLE_CLOUD_LOCATION)"
gcloud config set project $env:GOOGLE_CLOUD_PROJECT

Write-Host ""
Write-Host "1) Szükséges Google Cloud API-k bekapcsolása"
gcloud services enable `
  run.googleapis.com `
  cloudbuild.googleapis.com `
  artifactregistry.googleapis.com `
  aiplatform.googleapis.com `
  discoveryengine.googleapis.com `
  iam.googleapis.com `
  iamcredentials.googleapis.com `
  cloudresourcemanager.googleapis.com `
  serviceusage.googleapis.com

Write-Host ""
Write-Host "2) Artifact Registry tárhely a Docker image-eknek"
$repoCheck = gcloud artifacts repositories describe $env:ARTIFACT_REGISTRY_REPO --location=$env:GOOGLE_CLOUD_LOCATION 2>&1
if ($LASTEXITCODE -ne 0) {
    gcloud artifacts repositories create $env:ARTIFACT_REGISTRY_REPO `
      --repository-format=docker `
      --location=$env:GOOGLE_CLOUD_LOCATION `
      --description="rag-app Cloud Run image-ek"
} else {
    Write-Host "   Már létezik: $($env:ARTIFACT_REGISTRY_REPO)"
}

$ServerSa = "$($env:SERVER_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ClientSa = "$($env:CLIENT_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$BuildSa = "$($env:BUILD_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ProjectNumber = gcloud projects describe $env:GOOGLE_CLOUD_PROJECT --format="value(projectNumber)"
$DefaultBuild = "$ProjectNumber@cloudbuild.gserviceaccount.com"
$ComputeSa = "$ProjectNumber-compute@developer.gserviceaccount.com"

function Create-Sa([string]$Email, [string]$Display) {
    $name = $Email.Split("@")[0]
    gcloud iam service-accounts describe $Email 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        gcloud iam service-accounts create $name --display-name="$Display"
    } else {
        Write-Host "   Már létezik: $Email"
    }
}

Write-Host ""
Write-Host "3) Service accountok"
Create-Sa $ServerSa "rag-app server (LLM + RAG)"
Create-Sa $ClientSa "rag-app client"
Create-Sa $BuildSa "rag-app Cloud Build"

function Bind-Project([string]$Member, [string]$Role) {
    gcloud projects add-iam-policy-binding $env:GOOGLE_CLOUD_PROJECT `
      --member="serviceAccount:$Member" `
      --role=$Role `
      --condition=None `
      --quiet | Out-Null
}

Write-Host ""
Write-Host "4) Jogosultságok (IAM)"
Bind-Project $ServerSa "roles/aiplatform.user"
Bind-Project $ServerSa "roles/logging.logWriter"
Bind-Project $ServerSa "roles/storage.objectViewer"
Bind-Project $ClientSa "roles/logging.logWriter"

foreach ($sa in @($BuildSa, $DefaultBuild, $ComputeSa)) {
    Bind-Project $sa "roles/run.admin"
    Bind-Project $sa "roles/artifactregistry.writer"
    Bind-Project $sa "roles/logging.logWriter"
    Bind-Project $sa "roles/cloudbuild.builds.builder"
    Bind-Project $sa "roles/storage.objectAdmin"
}

foreach ($runtime in @($ServerSa, $ClientSa)) {
    foreach ($actor in @($BuildSa, $DefaultBuild, $ComputeSa)) {
        gcloud iam service-accounts add-iam-policy-binding $runtime `
          --member="serviceAccount:$actor" `
          --role="roles/iam.serviceAccountUser" `
          --quiet | Out-Null
    }
}

Write-Host ""
Write-Host "Kész. Következő lépések:"
Write-Host "  - Helyi futtatás:  .\scripts\run-local.ps1"
Write-Host "  - Deploy:          .\scripts\deploy.ps1"
Write-Host ""
Write-Host "Service accountok:"
Write-Host "  server: $ServerSa"
Write-Host "  client: $ClientSa"
Write-Host "  build:  $BuildSa"
