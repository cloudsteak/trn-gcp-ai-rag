# Helyi futtatás Docker nélkül (Windows).
$ErrorActionPreference = "Stop"
. "$PSScriptRoot\load-env.ps1"

function Need-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        Write-Host "Hiányzik a(z) '$Name' parancs. A README telepítési része leírja, hogyan tedd fel."
        exit 1
    }
}

Need-Command gcloud
Need-Command uv

$Python = $null
foreach ($c in @("python", "py")) {
    if (Get-Command $c -ErrorAction SilentlyContinue) { $Python = $c; break }
}
if (-not $Python) {
    Write-Host "Hiányzik a Python. Telepítsd a python.org-ról, és pipáld be a PATH-ba."
    exit 1
}

Write-Host "ADC (helyi Google bejelentkezés) ellenőrzése"
gcloud auth application-default print-access-token 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Még nincs ADC. Egy böngészős bejelentkezés következik."
    Write-Host "Ugyanazzal a Google-fiókkal lépj be, aki a projekt tagja."
    gcloud auth application-default login
}
gcloud auth application-default set-quota-project $env:GOOGLE_CLOUD_PROJECT
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "A quota-project beállítása nem sikerült (GOOGLE_CLOUD_PROJECT=$($env:GOOGLE_CLOUD_PROJECT))."
    Write-Host "Gyakori ok: az ADC-ben másik Google-fiók van, mint aki a projekt Owner-e."
    Write-Host "  gcloud auth list"
    Write-Host "  gcloud projects list"
    Write-Host "  gcloud auth application-default login"
    Write-Host "Részletek: rag-app/README.md → serviceusage.services.use"
    exit 1
}
gcloud config set project $env:GOOGLE_CLOUD_PROJECT

Copy-Item "$Root\client\config.example.js" "$Root\client\config.js" -Force

Write-Host ""
Write-Host "Server:  http://localhost:8080"
Write-Host "Client:  http://localhost:3000   ← ezt nyisd meg a böngészőben"
Write-Host "Kilépés: Ctrl+C"
Write-Host ""

Push-Location "$Root\server"
uv sync --frozen
Pop-Location

$server = Start-Process -FilePath "uv" -WorkingDirectory "$Root\server" `
  -ArgumentList @("run", "uvicorn", "main:app", "--reload", "--host", "127.0.0.1", "--port", "8080") `
  -PassThru -NoNewWindow

$clientArgs = @("-m", "http.server", "3000", "--directory", "$Root\client")
if ($Python -eq "py") { $clientArgs = @("-3") + $clientArgs }
$client = Start-Process -FilePath $Python -ArgumentList $clientArgs -PassThru -NoNewWindow

try {
    Wait-Process -Id $server.Id
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $client.Id -Force -ErrorAction SilentlyContinue
}
