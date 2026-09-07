# Helyi futtatás Docker Compose-szal (Windows).
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\load-env.ps1"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Hiányzik a docker parancs. Telepítsd a Docker Desktopot."
    exit 1
}
if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Write-Host "Hiányzik a gcloud parancs."
    exit 1
}

gcloud auth application-default print-access-token 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Még nincs ADC. Ugyanazzal a Google-fiókkal lépj be, aki a projekt tagja."
    gcloud auth application-default login
}
gcloud auth application-default set-quota-project $env:GOOGLE_CLOUD_PROJECT
if ($LASTEXITCODE -ne 0) {
    Write-Host "A quota-project beállítása nem sikerült (GOOGLE_CLOUD_PROJECT=$($env:GOOGLE_CLOUD_PROJECT))."
    Write-Host "Részletek: rag-app/README.md → serviceusage.services.use"
    exit 1
}

$env:GCLOUD_CONFIG_DIR = if ($env:CLOUDSDK_CONFIG) { $env:CLOUDSDK_CONFIG } else { Join-Path $env:APPDATA "gcloud" }
if (-not (Test-Path $env:GCLOUD_CONFIG_DIR)) {
    Write-Host "Nem találom a gcloud config mappát: $($env:GCLOUD_CONFIG_DIR)"
    exit 1
}

Write-Host "Client: http://localhost:3000"
Write-Host "Server: http://localhost:8080"
docker compose -f "$Root\docker-compose.yml" up --build
