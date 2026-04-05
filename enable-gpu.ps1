# ============================================================
# OllamaBox GPU Enabler — installs NVIDIA CUDA support in WSL
# Must be run as Administrator
# ============================================================

$ErrorActionPreference = "Stop"
$InstanceName = "OllamaBox"

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  OllamaBox GPU Setup" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "This script must be run as Administrator." -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator', then try again." -ForegroundColor Yellow
    exit 1
}

# Check OllamaBox exists
$existing = wsl -l -q 2>$null | Where-Object { $_.Trim() -replace "`0","" -eq $InstanceName }
if (-not $existing) {
    Write-Host "OllamaBox is not installed. Run the main installer first." -ForegroundColor Red
    exit 1
}

# Check if NVIDIA driver is installed on Windows
Write-Host "[1/3] Checking NVIDIA driver on Windows..." -ForegroundColor Yellow

$nvidiaSmi = "$env:SystemRoot\System32\nvidia-smi.exe"
if (Test-Path $nvidiaSmi) {
    $gpuInfo = & $nvidiaSmi --query-gpu=name,driver_version --format=csv,noheader 2>$null
    Write-Host "       Found: $gpuInfo" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  NVIDIA driver not found on Windows." -ForegroundColor Red
    Write-Host ""
    Write-Host "  You need to install it first:" -ForegroundColor Yellow
    Write-Host "  1. Go to https://www.nvidia.com/Download/index.aspx" -ForegroundColor White
    Write-Host "  2. Download and install the latest driver for your GPU" -ForegroundColor White
    Write-Host "  3. Restart your PC" -ForegroundColor White
    Write-Host "  4. Run this script again" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Install CUDA toolkit inside WSL
Write-Host "[2/3] Installing CUDA support inside OllamaBox..." -ForegroundColor Yellow

$cudaScript = @'
#!/bin/bash
set -e

# Check if GPU is already visible
if nvidia-smi > /dev/null 2>&1; then
    echo "  GPU already accessible inside WSL:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
    echo ""
else
    echo "  Installing NVIDIA CUDA toolkit for WSL..."
    apt-get update -qq
    apt-get install -y -qq nvidia-cuda-toolkit > /dev/null 2>&1 || true
fi

# Restart Ollama to pick up GPU
echo "  Restarting Ollama..."
pkill ollama 2>/dev/null || true
sleep 1
ollama serve > /tmp/ollama.log 2>&1 &
sleep 3

# Verify
if nvidia-smi > /dev/null 2>&1; then
    echo ""
    echo "  GPU detected:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader
    echo ""
    echo "  SUCCESS: Ollama will now use your GPU."
else
    echo ""
    echo "  WARNING: GPU still not visible inside WSL."
    echo "  Try: wsl --shutdown  (in PowerShell) then start OllamaBox again."
fi
'@

wsl -d $InstanceName -- bash -c $cudaScript

# Restart WSL to ensure clean GPU passthrough
Write-Host "[3/3] Restarting OllamaBox for clean GPU passthrough..." -ForegroundColor Yellow
wsl --terminate $InstanceName 2>$null

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  GPU setup complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Start OllamaBox:" -ForegroundColor Cyan
Write-Host "  wsl -d OllamaBox -- bash -c '~/start-ollama.sh'" -ForegroundColor White
Write-Host ""
Write-Host "Verify GPU is active:" -ForegroundColor Cyan
Write-Host "  wsl -d OllamaBox -- bash -c 'ollama ps'" -ForegroundColor White
Write-Host ""
Write-Host "It should now show '100% GPU' instead of '100% CPU'." -ForegroundColor Green
Write-Host ""
