# Közös: a rag-app/.env betöltése PowerShellben.
$PSNativeCommandUseErrorActionPreference = $false
$Root = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $Root ".env"

if (-not (Test-Path $EnvFile)) {
    Write-Host "Nincs .env fájl."
    Write-Host "Másold át a példát, és töltsd ki:"
    Write-Host "  copy `"$Root\.env.example`" `"$Root\.env`""
    exit 1
}

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $eq = $line.IndexOf("=")
    if ($eq -lt 1) { return }
    $name = $line.Substring(0, $eq).Trim()
    $value = $line.Substring($eq + 1).Trim().Trim('"').Trim("'")
    Set-Item -Path "Env:$name" -Value $value
}

if (-not $env:GOOGLE_CLOUD_PROJECT -or $env:GOOGLE_CLOUD_PROJECT -eq "REPLACE_WITH_PROJECT_ID") {
    Write-Host "A .env fájlban a GOOGLE_CLOUD_PROJECT még nincs kitöltve."
    exit 1
}
