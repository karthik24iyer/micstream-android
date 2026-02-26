# setup_rnnoise.ps1 — Download RNNoise source for Android NDK compilation
#
# Usage (PowerShell): .\scripts\setup_rnnoise.ps1
# Run this once before building the APK. Requires git.

$ErrorActionPreference = "Stop"

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$TargetDir  = Join-Path $ProjectDir "android\app\src\main\cpp\rnnoise"

Write-Host "MicQ - Phase 4: RNNoise setup"
Write-Host "Target: $TargetDir"

if (Test-Path (Join-Path $TargetDir ".git")) {
    Write-Host "RNNoise source already present. Pulling latest..."
    git -C $TargetDir pull --ff-only
    Write-Host "Done."
    exit 0
}

if (Test-Path $TargetDir) {
    Write-Host "Directory exists but is not a git repo — removing and re-cloning..."
    Remove-Item -Recurse -Force $TargetDir
}

Write-Host "Cloning xiph/rnnoise (shallow)..."
git clone --depth 1 https://github.com/xiph/rnnoise.git $TargetDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "git clone failed. Check your internet connection and git installation."
    exit 1
}

Write-Host ""
Write-Host "OK RNNoise source ready at:"
Write-Host "  $TargetDir"
Write-Host ""
Write-Host "Next step - build the release APK:"
Write-Host "  flutter build apk --release"
