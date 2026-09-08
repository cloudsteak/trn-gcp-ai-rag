# GCP előkészítés / pótlás: API-k, service accountok, IAM.
# Nyugodtan futtasd újra: ami megvan, azt kihagyja; ami hiányzik, azt berakja.
# Saját Artifact Registry tárat NEM hoz létre: a Console Cloud Build a sajátját használja.
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\load-env.ps1"

Write-Host "Projekt: $($env:GOOGLE_CLOUD_PROJECT)"
Write-Host "Régió:   $($env:GOOGLE_CLOUD_LOCATION)"
Write-Host "A hiányzó beállításokat pótolja, a meglévőket nem bántja."
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

$ServerSa = "$($env:SERVER_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ClientSa = "$($env:CLIENT_SA_NAME)@$($env:GOOGLE_CLOUD_PROJECT).iam.gserviceaccount.com"
$ProjectNumber = gcloud projects describe $env:GOOGLE_CLOUD_PROJECT --format="value(projectNumber)"
$DefaultBuild = "$ProjectNumber@cloudbuild.gserviceaccount.com"
$ComputeSa = "$ProjectNumber-compute@developer.gserviceaccount.com"

function Create-Sa([string]$Email, [string]$Display) {
    $name = $Email.Split("@")[0]
    gcloud iam service-accounts describe $Email 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        gcloud iam service-accounts create $name --display-name="$Display"
        Write-Host "   Létrehozva: $Email"
    } else {
        Write-Host "   Már létezik: $Email"
    }
}

Write-Host ""
Write-Host "2) Service accountok"
Create-Sa $ServerSa "rag-app server (LLM + RAG)"
Create-Sa $ClientSa "rag-app client"

function Bind-Project([string]$Member, [string]$Role) {
    Write-Host "   $Role  →  $Member"
    gcloud projects add-iam-policy-binding $env:GOOGLE_CLOUD_PROJECT `
      --member="serviceAccount:$Member" `
      --role=$Role `
      --condition=None `
      --quiet | Out-Null
}

Write-Host ""
Write-Host "3) Jogosultságok (IAM) — a hiányzó szerepek felkerülnek"
Bind-Project $ServerSa "roles/aiplatform.user"
Bind-Project $ServerSa "roles/discoveryengine.viewer"
Bind-Project $ServerSa "roles/logging.logWriter"
Bind-Project $ServerSa "roles/storage.objectViewer"
Bind-Project $ClientSa "roles/logging.logWriter"

foreach ($sa in @($DefaultBuild, $ComputeSa)) {
    Bind-Project $sa "roles/run.admin"
    Bind-Project $sa "roles/artifactregistry.writer"
    Bind-Project $sa "roles/logging.logWriter"
    Bind-Project $sa "roles/cloudbuild.builds.builder"
    Bind-Project $sa "roles/storage.objectAdmin"
}

foreach ($runtime in @($ServerSa, $ClientSa)) {
    foreach ($actor in @($DefaultBuild, $ComputeSa)) {
        gcloud iam service-accounts add-iam-policy-binding $runtime `
          --member="serviceAccount:$actor" `
          --role="roles/iam.serviceAccountUser" `
          --quiet | Out-Null
    }
}

Write-Host ""
Write-Host "Kész. Ami hiányzott, az most bent van."
Write-Host "  Ha a Cloud Run client már megy: várj ~20 mp, küldd újra a kérdést. Új deploy nem kell."
Write-Host "  Ha még helyben vagy:  .\scripts\run-local.ps1"
Write-Host "  Ha még nincs Cloud Run: Console → Connect repository (először server, aztán client)"
Write-Host ""
Write-Host "Service accountok:"
Write-Host "  server: $ServerSa"
Write-Host "  client: $ClientSa"
