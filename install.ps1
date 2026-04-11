# Windows dotfiles 설치 진입점
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot

Write-Host "==> Windows dotfiles setup starting..."
Write-Host "    Source: $root"

Write-Host ""
pwsh -ExecutionPolicy Bypass -File "$root\windows\install.ps1"

Write-Host ""
pwsh -ExecutionPolicy Bypass -File "$root\windows\agents-setup.ps1" -DotfilesDir $root

Write-Host ""
Write-Host "==> Done! Restart your terminal."
