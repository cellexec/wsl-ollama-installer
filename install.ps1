# ============================================================
# OllamaBox Installer - PowerShell (runs on Windows)
# Creates a fresh WSL Ubuntu instance and sets up Ollama + Web UI
# ============================================================

param(
    [string]$InstanceName = "OllamaBox",
    [string]$InstallDir = "$env:USERPROFILE\WSL\OllamaBox"
)

$ErrorActionPreference = "Stop"

$RootfsUrl = "https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl"
$RootfsFile = "$env:TEMP\ubuntu-24.04-rootfs.wsl"

# --- GITHUB RAW URL (update after pushing to your repo) ---
$SetupScriptUrl = "https://raw.githubusercontent.com/cellexec/wsl-ollama-installer/main/setup.sh"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  OllamaBox Installer" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check if instance already exists
$existing = wsl -l -q 2>$null | Where-Object { $_.Trim() -replace "`0","" -eq $InstanceName }
if ($existing) {
    Write-Host "Instance '$InstanceName' already exists." -ForegroundColor Yellow
    $choice = Read-Host "Start it and re-run setup? (y/N)"
    if ($choice -ne "y") {
        Write-Host "Aborted." -ForegroundColor Red
        exit 0
    }
    Write-Host "Launching existing instance..." -ForegroundColor Yellow
    wsl -d $InstanceName -- bash -c "curl -fsSL $SetupScriptUrl | bash"
    exit 0
}

# Step 1: Download Ubuntu rootfs
if (Test-Path $RootfsFile) {
    Write-Host "[1/4] Ubuntu rootfs already downloaded, reusing." -ForegroundColor Green
} else {
    Write-Host "[1/4] Downloading Ubuntu 24.04 rootfs (~500MB)..." -ForegroundColor Yellow
    Write-Host "       From: $RootfsUrl" -ForegroundColor DarkGray
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $RootfsUrl -OutFile $RootfsFile -UseBasicParsing
    $ProgressPreference = 'Continue'
    Write-Host "       Download complete." -ForegroundColor Green
}

# Step 2: Create install directory
if (-not (Test-Path $InstallDir)) {
    Write-Host "[2/4] Creating install directory: $InstallDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
} else {
    Write-Host "[2/4] Install directory exists: $InstallDir" -ForegroundColor Green
}

# Step 3: Import as new WSL instance
Write-Host "[3/4] Importing as WSL instance '$InstanceName'..." -ForegroundColor Yellow
wsl --import $InstanceName $InstallDir $RootfsFile --version 2
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to import WSL instance." -ForegroundColor Red
    exit 1
}
Write-Host "       Instance '$InstanceName' created." -ForegroundColor Green

# Step 4: Run setup script inside the new instance
Write-Host "[4/4] Running setup inside '$InstanceName'..." -ForegroundColor Yellow
Write-Host ""
wsl -d $InstanceName -- bash -c "curl -fsSL $SetupScriptUrl | bash"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Setup encountered errors. You can retry with:" -ForegroundColor Yellow
    Write-Host "  wsl -d $InstanceName -- bash -c 'curl -fsSL $SetupScriptUrl | bash'" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "  OllamaBox is ready!" -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "To start OllamaBox again later:" -ForegroundColor Cyan
    Write-Host "  wsl -d $InstanceName -- bash -c '~/start-ollama.sh'" -ForegroundColor White
    Write-Host ""
    Write-Host "To remove OllamaBox completely:" -ForegroundColor Cyan
    Write-Host "  wsl --unregister $InstanceName" -ForegroundColor White
    Write-Host ""
}
