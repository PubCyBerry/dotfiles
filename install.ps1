# Windows dotfiles 설치 진입점 (all-in-one)
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT = $PSScriptRoot
Write-Host "==> Windows dotfiles setup starting..."
Write-Host "    Source: $ROOT"

# =============================================
# 1. winget 패키지 설치 (manifests/winget.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing packages via winget..."
$wingetFile = Join-Path $ROOT "manifests\winget.txt"
if (Test-Path $wingetFile) {
    Get-Content $wingetFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            Write-Host "    Installing $line..."
            winget install --id $line --silent --accept-package-agreements --accept-source-agreements
        }
    }
} else {
    Write-Host "    [!] manifests\winget.txt not found, skipping."
}

# =============================================
# 2. Node.js LTS 설치 (fnm)
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
# 3. npm 전역 패키지 설치 (manifests/npm-global.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing global npm packages..."
$npmFile = Join-Path $ROOT "manifests\npm-global.txt"
if (Test-Path $npmFile) {
    Get-Content $npmFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            Write-Host "    Installing $line..."
            npm install -g $line
        }
    }
} else {
    Write-Host "    [!] manifests\npm-global.txt not found, skipping."
}

# =============================================
# 4. Claude Code 설치 (native)
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
# 5. RTK (Rust Token Killer) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing RTK (Rust Token Killer)..."
$rtkDir = "$env:USERPROFILE\rtk"
$rtkExe = "$rtkDir\rtk.exe"
if (-not (Test-Path $rtkExe) -and -not (Test-Path "$rtkDir\rtk")) {
    $releaseApi = "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releaseApi -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            New-Item -ItemType Directory -Force -Path $rtkDir | Out-Null
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$rtkDir\rtk.zip"
            Expand-Archive -Path "$rtkDir\rtk.zip" -DestinationPath $rtkDir -Force
            Remove-Item "$rtkDir\rtk.zip" -Force
            $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if ($userPath -notlike "*$rtkDir*") {
                [System.Environment]::SetEnvironmentVariable("PATH", "$rtkDir;$userPath", "User")
            }
            $env:PATH = "$rtkDir;$env:PATH"
            Write-Host "    RTK installed: $rtkDir"
        } else {
            Write-Host "    [!] RTK Windows binary not found in releases. Install manually."
        }
    } catch {
        Write-Host "    [!] Failed to fetch RTK release info. Install manually."
    }
} else {
    Write-Host "    RTK already installed: $rtkExe"
}

# rtk-wrapper: Git Bash에서 "Hook outdated" 경고 필터링
$localBin = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force -Path $localBin | Out-Null
$wrapperContent = @'
#!/bin/bash
# RTK wrapper for Windows Git Bash
# filters "Hook outdated" stderr warning (hash baseline can't be set on Windows)
if [[ -x "$HOME/rtk/rtk.exe" ]]; then
  RTK_BIN="$HOME/rtk/rtk.exe"
elif [[ -x "$HOME/rtk/rtk" ]]; then
  RTK_BIN="$HOME/rtk/rtk"
else
  RTK_BIN="$(PATH="${PATH//$HOME\/.local\/bin:/}" command -v rtk 2>/dev/null)"
fi
"${RTK_BIN}" "$@" 2> >(grep -v "\[rtk\].*Hook outdated" >&2)
'@
$wrapperContent | Out-File -FilePath "$localBin\rtk" -Encoding utf8 -NoNewline
Write-Host "    rtk-wrapper installed → $localBin\rtk"

# =============================================
# 6. $USERPROFILE\.local\bin PATH 설정
# =============================================
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$localBin*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$localBin;$userPath", "User")
}
$env:PATH = "$localBin;$env:PATH"

# =============================================
# 7. ast-grep (sg.exe) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing ast-grep (sg)..."
if (-not (Test-Path "$localBin\sg.exe")) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ast-grep/ast-grep/releases/latest" `
            -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$env:TEMP\ast-grep.zip"
            Expand-Archive -Path "$env:TEMP\ast-grep.zip" -DestinationPath "$env:TEMP\ast-grep" -Force
            $sgExe = Get-ChildItem -Path "$env:TEMP\ast-grep" -Recurse -Filter "sg.exe" | Select-Object -First 1
            if ($sgExe) {
                Move-Item $sgExe.FullName "$localBin\sg.exe" -Force
                Write-Host "    ast-grep installed: $localBin\sg.exe"
            }
            Remove-Item "$env:TEMP\ast-grep.zip", "$env:TEMP\ast-grep" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "    [!] ast-grep Windows binary not found."
        }
    } catch {
        Write-Host "    [!] Failed to download ast-grep: $_"
    }
} else {
    Write-Host "    ast-grep already installed."
}

# =============================================
# 8. difftastic (difft.exe) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing difftastic (difft)..."
if (-not (Test-Path "$localBin\difft.exe")) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/Wilfred/difftastic/releases/latest" `
            -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$env:TEMP\difft.zip"
            Expand-Archive -Path "$env:TEMP\difft.zip" -DestinationPath "$env:TEMP\difft" -Force
            $difftExe = Get-ChildItem -Path "$env:TEMP\difft" -Recurse -Filter "difft.exe" | Select-Object -First 1
            if ($difftExe) {
                Move-Item $difftExe.FullName "$localBin\difft.exe" -Force
                Write-Host "    difftastic installed: $localBin\difft.exe"
            }
            Remove-Item "$env:TEMP\difft.zip", "$env:TEMP\difft" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "    [!] difftastic Windows binary not found."
        }
    } catch {
        Write-Host "    [!] Failed to download difftastic: $_"
    }
} else {
    Write-Host "    difftastic already installed."
}

# =============================================
# 9. Claude Code 설정 배포 (config/claude/ → ~/.claude/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Claude Code config..."
$claudeDir = "$env:USERPROFILE\.claude"
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
# 10. RTK hook 생성 (~/.claude/hooks/rtk-rewrite.sh)
# =============================================
Write-Host ""
Write-Host "==> Setting up RTK hook for Claude Code..."
$hooksDir = "$claudeDir\hooks"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
$rtkHookContent = @'
#!/bin/bash
# RTK PreToolUse hook — Bash 명령어를 rtk 래퍼로 자동 변환
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.command // ""' 2>/dev/null)
if [ -z "$CMD" ]; then echo "$INPUT"; exit 0; fi
REWRITTEN=$(rtk rewrite "$CMD" 2>/dev/null)
if [ -n "$REWRITTEN" ] && [ "$REWRITTEN" != "$CMD" ]; then
    echo "$INPUT" | jq --arg cmd "$REWRITTEN" '.command = $cmd'
else
    echo "$INPUT"
fi
'@
$rtkHookContent | Out-File -FilePath "$hooksDir\rtk-rewrite.sh" -Encoding utf8 -NoNewline
Write-Host "    Created RTK hook: $hooksDir\rtk-rewrite.sh"

# =============================================
# 11. PowerShell 프로파일 설정 (마커 방식)
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
# 12. tmux 설정 복사
# =============================================
$tmuxSrc = Join-Path $ROOT "config\windows\tmux.conf"
if (Test-Path $tmuxSrc) {
    Copy-Item $tmuxSrc "$env:USERPROFILE\.tmux.conf" -Force
    Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)"
}

# =============================================
# 13. Claude skills 설치 (manifests/skills.txt)
# =============================================
Write-Host ""
Write-Host "==> Restoring Claude Code skills..."
$skillsFile = Join-Path $ROOT "manifests\skills.txt"
if (Test-Path $skillsFile) {
    Get-Content $skillsFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            if ($line -match '^([^@]+)@(.+)$') {
                $repoSlug  = $Matches[1]
                $skillName = $Matches[2]
                Write-Host "    Adding skill: $skillName from $repoSlug..."
                npx skills add $repoSlug --skill $skillName -g -y 2>&1 | Out-Null
            }
        }
    }
    Write-Host "    Skills restored."
} else {
    Write-Host "    [!] manifests\skills.txt not found, skipping skills."
}

Write-Host ""
Write-Host "==> Done! Restart your terminal and Claude Code to apply all changes."
