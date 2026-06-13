# Registra el repo en Codemagic y lanza build iOS (requiere CODEMAGIC_API_TOKEN).
# Uso: .\scripts\setup-codemagic.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $RepoRoot ".local\server.credentials.env"

function Read-EnvFile($path) {
    $vars = @{}
    if (-not (Test-Path $path)) { return $vars }
    Get-Content $path | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $vars[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    return $vars
}

$envVars = Read-EnvFile $EnvFile
$token = $envVars["CODEMAGIC_API_TOKEN"]
# Cambia esta URL por la de tu repo GitHub
$repoUrl = "https://github.com/ytmness/Parserc.git"
$workflowId = "ios-testflight-manual"

Write-Host ""
Write-Host "=== Parcec (OpenParsec) - Setup Codemagic ===" -ForegroundColor Cyan
Write-Host "Repo: $repoUrl"
Write-Host "Workflows: ios-testflight | ios-testflight-manual | ios-adhoc-manual"
Write-Host ""

if (-not $token) {
    Write-Host "Falta CODEMAGIC_API_TOKEN en .local/server.credentials.env" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Pasos en codemagic.io:"
    Write-Host "  1. Add application - GitHub - tu repo Parcec"
    Write-Host "  2. Branch main - Check for configuration file"
    Write-Host "  3. Team integrations - Developer Portal - key name: PARSEC"
    Write-Host "  4. Environment variables - grupo: parcec - APP_STORE_APPLE_ID (opcional)"
    Write-Host "  5. Start build - iOS TestFlight (manual) - NO Default Workflow"
    Write-Host ""
    Write-Host "API token: User settings - API token - pegar en server.credentials.env"
    Write-Host "Guia completa: docs/CODEMAGIC.md"
    exit 0
}

$headers = @{
    "Content-Type" = "application/json"
    "x-auth-token" = $token
}

Write-Host "Listando apps..." -ForegroundColor Gray
$appsResp = Invoke-RestMethod -Uri "https://api.codemagic.io/apps" -Headers $headers -Method Get
$app = $appsResp.applications | Where-Object {
    ($_.repository -match "parcec") -or ($_.repository -match "OpenParsec") -or ($_.repository -match "Parserc")
} | Select-Object -First 1

if (-not $app) {
    Write-Host "Registrando app..." -ForegroundColor Green
    try {
        $created = Invoke-RestMethod -Uri "https://api.codemagic.io/apps" -Headers $headers -Method Post -Body (@{
            repositoryUrl = $repoUrl
        } | ConvertTo-Json)
        $appId = $created._id
        if (-not $appId) { $appId = $created.application._id }
        Write-Host "App creada: $appId"
    } catch {
        Write-Host "Conecta GitHub en codemagic.io primero:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message
        exit 1
    }
} else {
    $appId = $app._id
    Write-Host "App existente: $($app.appName) ($appId)" -ForegroundColor Green
}

if ($envVars["CODEMAGIC_APP_ID"]) {
    $appId = $envVars["CODEMAGIC_APP_ID"]
}

Write-Host "Iniciando build $workflowId en main..." -ForegroundColor Green
$buildBody = @{
    appId      = $appId
    workflowId = $workflowId
    branch     = "main"
} | ConvertTo-Json

try {
    $build = Invoke-RestMethod -Uri "https://api.codemagic.io/builds" -Headers $headers -Method Post -Body $buildBody
    Write-Host ""
    Write-Host "Build ID: $($build.buildId)" -ForegroundColor Green
    Write-Host "https://codemagic.io/apps"
} catch {
    Write-Host "Error al iniciar build:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message }
    Write-Host "Configura integracion PARSEC y grupo parcec en la UI."
    exit 1
}
