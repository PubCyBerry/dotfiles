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

# settings.json: 병합 (기존에 없는 키 보존 — claude-hud의 statusLine 등)
$settingsSrc = Join-Path $ROOT "config\claude\settings.json"
$settingsDst = "$claudeDir\settings.json"
if (Test-Path $settingsSrc) {
    $newSettings = Get-Content $settingsSrc -Raw | ConvertFrom-Json
    if (Test-Path $settingsDst) {
        $existing = Get-Content $settingsDst -Raw | ConvertFrom-Json
        foreach ($prop in $newSettings.PSObject.Properties) {
            $existing | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
        }
        $existing | ConvertTo-Json -Depth 10 | Out-File $settingsDst -Encoding utf8 -NoNewline
        Write-Host "    Merged settings.json"
    } else {
        Copy-Item $settingsSrc $settingsDst -Force
        Write-Host "    Copied settings.json"
    }
} else {
    Write-Host "    [!] config\claude\settings.json not found"
}

# CLAUDE.md: 단순 복사
$claudeMdSrc = Join-Path $ROOT "config\claude\CLAUDE.md"
if (Test-Path $claudeMdSrc) {
    Copy-Item $claudeMdSrc "$claudeDir\CLAUDE.md" -Force
    Write-Host "    Copied CLAUDE.md"
} else {
    Write-Host "    [!] config\claude\CLAUDE.md not found"
}

# =============================================
# 7. RTK (Rust Token Killer) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing RTK (Rust Token Killer)..."
$localBin = "$env:USERPROFILE\.local\bin"
if (-not (Test-Path $localBin)) {
    New-Item -ItemType Directory -Force -Path $localBin | Out-Null
}

# User PATH에 ~/.local/bin 추가 (영구)
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$localBin*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$localBin", "User")
    Write-Host "    Added $localBin to User PATH"
}
$env:PATH = "$env:PATH;$localBin"

if (Get-Command rtk -ErrorAction SilentlyContinue) {
    Write-Host "    RTK already installed."
} else {
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.zip$" } | Select-Object -First 1
        if ($asset) {
            $tmpZip = "$env:TEMP\rtk-windows.zip"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing
            Expand-Archive -Path $tmpZip -DestinationPath $localBin -Force
            Remove-Item $tmpZip -Force
            Write-Host "    RTK installed."
        } else {
            Write-Host "    [!] RTK Windows 바이너리를 찾을 수 없음. 수동 설치: cargo install rtk"
        }
    } catch {
        Write-Host "    [!] RTK 설치 실패: $_"
    }
}

# RTK hook 등록 (~/.claude/hooks/rtk-rewrite.sh 다운로드)
# rtk init --hook-only는 Windows 미지원 → GitHub에서 직접 다운로드
New-Item -ItemType Directory -Force -Path "$claudeDir\hooks" | Out-Null
$hookUrl  = "https://raw.githubusercontent.com/rtk-ai/rtk/master/hooks/claude/rtk-rewrite.sh"
$hookPath = "$claudeDir\hooks\rtk-rewrite.sh"
try {
    Invoke-WebRequest -Uri $hookUrl -OutFile $hookPath -UseBasicParsing
    Write-Host "    RTK hook installed"
} catch {
    Write-Host "    [!] RTK hook download failed: $_"
}

# =============================================
# 8. PowerShell 프로파일 설정 (마커 방식)
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
# 9. Claude skills 설치 (manifests/skills.txt)
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
