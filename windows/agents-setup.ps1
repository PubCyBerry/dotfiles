# agents-setup.ps1 - Windows에서 Claude Code 설정 자동 복사
# 실행: PowerShell에서 .\dotfiles\windows\agents-setup.ps1
# 또는: powershell -ExecutionPolicy Bypass -File .\dotfiles\windows\agents-setup.ps1

param(
    [string]$DotfilesDir = "$env:USERPROFILE\dotfiles"
)

Write-Host "==> Setting up Claude Code config..."

# .claude 디렉토리 생성
$claudeDir = "$env:USERPROFILE\.claude"
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

# settings.json 복사
$src = "$DotfilesDir\agents\claude\settings.json"
if (Test-Path $src) {
    Copy-Item $src "$claudeDir\settings.json" -Force
    Write-Host "    Copied settings.json"
} else {
    Write-Host "    [!] $src not found"
}

# CLAUDE.md 복사
$src = "$DotfilesDir\agents\claude\CLAUDE.md"
if (Test-Path $src) {
    Copy-Item $src "$claudeDir\CLAUDE.md" -Force
    Write-Host "    Copied CLAUDE.md"
} else {
    Write-Host "    [!] $src not found"
}

# ccstatusline 설정 복사
$ccstatuslineDir = "$env:USERPROFILE\.config\ccstatusline"
New-Item -ItemType Directory -Force -Path $ccstatuslineDir | Out-Null
$src = "$DotfilesDir\agents\claude\ccstatusline-settings.json"
if (Test-Path $src) {
    Copy-Item $src "$ccstatuslineDir\settings.json" -Force
    Write-Host "    Copied ccstatusline settings.json"
} else {
    Write-Host "    [!] $src not found"
}

# .wslconfig 복사 (선택적)
$src = "$DotfilesDir\windows\.wslconfig"
if (Test-Path $src) {
    Copy-Item $src "$env:USERPROFILE\.wslconfig" -Force
    Write-Host "    Copied .wslconfig (run 'wsl --shutdown' to apply)"
} else {
    Write-Host "    [!] $src not found, skipping .wslconfig"
}

Write-Host ""
Write-Host "==> Claude Code config setup complete."
Write-Host "    Run 'claude' and install plugins with /plugin (superpowers, context7)"
