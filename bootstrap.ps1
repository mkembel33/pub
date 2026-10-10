# bootstrap.ps1 — download and run the encrypted Windows host provisioner
#
# Usage (run in an elevated PowerShell):
#   irm https://raw.githubusercontent.com/mkembel33/pub/main/bootstrap.ps1 | iex
#
# To pass installer flags through the piped form, set $env:INSTALL_ARGS first:
#   $env:INSTALL_ARGS = "-WSL -Tailscale"
#   irm https://raw.githubusercontent.com/mkembel33/pub/main/bootstrap.ps1 | iex
#
# Or download then run directly:
#   irm https://raw.githubusercontent.com/mkembel33/pub/main/bootstrap.ps1 -OutFile bootstrap.ps1
#   .\bootstrap.ps1 -InstallArgs "-WSL"
#
# Flags map to installmysoftware.ps1: -WSL (install WSL + tmux), -Tailscale.

param([string]$InstallArgs = "")

$ErrorActionPreference = 'Stop'
$RepoUrl = "https://raw.githubusercontent.com/mkembel33/pub/main"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Host Provisioning Bootstrap (Windows)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Update-PathFromRegistry {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('PATH', 'User')
}

# ─── winget is required (ships with the Windows 11 App Installer) ──────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: winget not found. Install 'App Installer' from the Microsoft Store, then re-run." -ForegroundColor Red
    exit 1
}

# ─── Install age if not present ───────────────────────────────────────────────
if (Get-Command age -ErrorAction SilentlyContinue) {
    Write-Host "age already installed: $(age --version)" -ForegroundColor DarkGray
} else {
    Write-Host "Installing age encryption tool..." -ForegroundColor Cyan
    winget install --id FiloSottile.age -e --silent --accept-package-agreements --accept-source-agreements
    Update-PathFromRegistry
    if (-not (Get-Command age -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: could not install/find age. Install manually: https://github.com/FiloSottile/age" -ForegroundColor Red
        exit 1
    }
    Write-Host "age installed." -ForegroundColor Green
}

# ─── Download + decrypt + run ─────────────────────────────────────────────────
$workDir = Join-Path $env:TEMP ("hostconfig-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
try {
    $ageFile = Join-Path $workDir "installer.ps1.age"
    $ps1File = Join-Path $workDir "installer.ps1"

    Write-Host ""
    Write-Host "Downloading encrypted installer..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "$RepoUrl/installmysoftware.ps1.age" -OutFile $ageFile -UseBasicParsing
    Write-Host "Downloaded." -ForegroundColor Green

    # Layer 1: age prompts for the master password on the console.
    Write-Host ""
    Write-Host "Enter the installer password when prompted:" -ForegroundColor Yellow
    age -d -o $ps1File $ageFile
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ps1File)) {
        Write-Host "ERROR: Wrong password or corrupt file." -ForegroundColor Red
        exit 1
    }

    Unblock-File $ps1File
    Write-Host ""
    Write-Host "Installer decrypted — launching..." -ForegroundColor Green
    Write-Host ""

    # Pass flags from -InstallArgs (file form) or $env:INSTALL_ARGS (piped form).
    $flags = if ($InstallArgs) { $InstallArgs } elseif ($env:INSTALL_ARGS) { $env:INSTALL_ARGS } else { "" }
    Invoke-Expression "& `"$ps1File`" $flags"
}
finally {
    Remove-Item -Recurse -Force $workDir -ErrorAction SilentlyContinue
}
