# Windows dotfiles 설치 진입점 (all-in-one)
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT      = $PSScriptRoot
$claudeDir = "$env:USERPROFILE\.claude"

# =============================================
# 헬퍼 함수
# =============================================
function Get-ManifestLines([string]$Path) {
    Get-Content $Path |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } |
        ForEach-Object { $_.Trim() }
}

Write-Host "==> Windows dotfiles setup starting..."
Write-Host "    Source: $ROOT"

# =============================================
# 1. winget 패키지 설치 (manifests/winget.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing packages via winget..."
$wingetFile = Join-Path $ROOT "manifests\winget.txt"
if (Test-Path $wingetFile) {
    Get-ManifestLines $wingetFile | ForEach-Object {
        Write-Host "    Installing $_..."
        winget install --id $_ --silent --accept-package-agreements --accept-source-agreements
    }
} else {
    Write-Host "    [!] manifests\winget.txt not found, skipping."
}

# =============================================
# 2. tmux 설정 복사
# =============================================
Write-Host ""
$tmuxSrc = Join-Path $ROOT "config\windows\tmux.conf"
if (Test-Path $tmuxSrc) {
    Copy-Item $tmuxSrc "$env:USERPROFILE\.tmux.conf" -Force
    Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)"
}

# =============================================
# 3. Node.js LTS 설치 (fnm)
# =============================================
Write-Host ""
Write-Host "==> Installing Node.js LTS..."
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" +
            $env:PATH
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    Write-Host "    Node.js LTS installed."
} else {
    Write-Host "    [!] fnm not found. Restart terminal and run:"
    Write-Host "        fnm install --lts && fnm default lts-latest"
}

# =============================================
# 4. npm 전역 패키지 설치 (manifests/npm-global.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing global npm packages..."
$npmFile = Join-Path $ROOT "manifests\npm-global.txt"
if (Test-Path $npmFile) {
    Get-ManifestLines $npmFile | ForEach-Object {
        Write-Host "    Installing $_..."
        npm install -g $_
    }
} else {
    Write-Host "    [!] manifests\npm-global.txt not found, skipping."
}

# =============================================
# 5. Claude Code 설치 (native)
# =============================================
Write-Host ""
Write-Host "==> Installing Claude Code (native)..."
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "    Claude Code already installed: $(claude --version)"
} else {
    Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
    Write-Host "    Claude Code installed."
}

# =============================================
# 6. Claude Code 설정 배포 (config/claude/ → ~/.claude/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Claude Code config..."
New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

foreach ($file in @("settings.json", "CLAUDE.md")) {
    $src = Join-Path $ROOT "config\claude\$file"
    if (Test-Path $src) {
        Copy-Item $src "$claudeDir\$file" -Force
        Write-Host "    Copied $file"
    } else {
        Write-Host "    [!] $src not found"
    }
}

# =============================================
# 7. PowerShell 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating PowerShell profiles..."
$profileSrc = Join-Path $ROOT "config\windows\profile.ps1"
if (Test-Path $profileSrc) {
    $markerBegin = "# ===== dotfiles-begin ====="
    $markerEnd   = "# ===== dotfiles-end ====="
    $profileContent = Get-Content $profileSrc -Raw
    $claudeAlias = "`nfunction global:ccd { claude --dangerously-skip-permissions @args }"
    $newBlock    = "$markerBegin`n$profileContent`n$claudeAlias`n$markerEnd"

    $profilePaths = @("$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1")

    foreach ($prof in $profilePaths) {
        $profileDir = Split-Path $prof
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
        }
        if (-not (Test-Path $prof)) {
            New-Item -ItemType File -Force -Path $prof | Out-Null
        }

        $existing = Get-Content $prof -Raw -ErrorAction SilentlyContinue
        if ($null -eq $existing) { $existing = "" }

        if ($existing -match [regex]::Escape($markerBegin)) {
            $beforeMarker = ($existing -split [regex]::Escape($markerBegin))[0]
            $afterMarker  = ($existing -split [regex]::Escape($markerEnd))[-1]
            $updated = "$beforeMarker$newBlock$afterMarker"
            $updated | Out-File -FilePath $prof -Encoding utf8 -NoNewline
            Write-Host "    Updated dotfiles block in $prof"
        } else {
            "`n$newBlock" | Add-Content -Path $prof -Encoding utf8
            Write-Host "    Appended dotfiles block to $prof"
        }
    }
} else {
    Write-Host "    [!] config\windows\profile.ps1 not found, skipping profile setup."
}

# =============================================
# 8. Claude skills 설치 (manifests/skills.txt)
# =============================================
Write-Host ""
Write-Host "==> Restoring Claude Code skills..."
$skillsFile = Join-Path $ROOT "manifests\skills.txt"
if (Test-Path $skillsFile) {
    Get-ManifestLines $skillsFile | ForEach-Object {
        if ($_ -match '^([^@]+)@(.+)$') {
            $repoSlug  = $Matches[1]
            $skillName = $Matches[2]
            Write-Host "    Adding skill: $skillName from $repoSlug..."
            npx --yes skills add $repoSlug --skill $skillName -g -y 2>&1 | Out-Null
        }
    }
    Write-Host "    Skills restored."
} else {
    Write-Host "    [!] manifests\skills.txt not found, skipping skills."
}

Write-Host ""
Write-Host "==> Done! Restart your terminal and Claude Code to apply all changes."
