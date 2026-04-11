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

# .tmux.conf 복사
$src = "$DotfilesDir\windows\.tmux.conf"
if (Test-Path $src) {
    Copy-Item $src "$env:USERPROFILE\.tmux.conf" -Force
    Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)"
} else {
    Write-Host "    [!] $src not found, skipping .tmux.conf"
}

# .wslconfig 복사 (선택적)
$src = "$DotfilesDir\windows\.wslconfig"
if (Test-Path $src) {
    Copy-Item $src "$env:USERPROFILE\.wslconfig" -Force
    Write-Host "    Copied .wslconfig (run 'wsl --shutdown' to apply)"
} else {
    Write-Host "    [!] $src not found, skipping .wslconfig"
}

# RTK hook 스크립트 생성 (Windows용 수동 설치 — rtk init --global이 Windows 미지원)
Write-Host ""
Write-Host "==> Setting up RTK hook for Claude Code..."
$hooksDir = "$claudeDir\hooks"
New-Item -ItemType Directory -Force -Path $hooksDir | Out-Null
$hookScript = "$hooksDir\rtk-rewrite.sh"
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
$rtkHookContent | Out-File -FilePath $hookScript -Encoding utf8 -NoNewline
Write-Host "    Created RTK hook: $hookScript"

# PowerShell $PROFILE 관리 (마커 방식 — 기존 내용 보존, 반복 실행 안전)
# PS 5.1과 PS 7+ 프로파일 경로가 다르므로 양쪽 모두 업데이트
Write-Host ""
Write-Host "==> Updating PowerShell profiles..."
$profileSrc = "$DotfilesDir\windows\profile.ps1"
if (Test-Path $profileSrc) {
    $markerBegin = "# ===== dotfiles-begin ====="
    $markerEnd   = "# ===== dotfiles-end ====="
    $profileContent = Get-Content $profileSrc -Raw
    $claudeAlias = "`nfunction global:ccd { claude --dangerously-skip-permissions @args }"
    $newBlock    = "$markerBegin`n$profileContent`n$claudeAlias`n$markerEnd"

    # 현재 $PROFILE + PS 7+ 프로파일 경로 모두 수집
    $profilePaths = @($PROFILE)
    $ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    $ps5Profile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
    if ($profilePaths -notcontains $ps7Profile) { $profilePaths += $ps7Profile }
    if ($profilePaths -notcontains $ps5Profile) { $profilePaths += $ps5Profile }

    foreach ($prof in $profilePaths) {
        # 디렉토리 생성
        $profileDir = Split-Path $prof
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
        }
        # 파일이 없으면 빈 파일 생성
        if (-not (Test-Path $prof)) {
            New-Item -ItemType File -Force -Path $prof | Out-Null
        }

        $existing = Get-Content $prof -Raw -ErrorAction SilentlyContinue
        if ($null -eq $existing) { $existing = "" }

        if ($existing -match [regex]::Escape($markerBegin)) {
            $updated = $existing -replace "(?s)$([regex]::Escape($markerBegin)).*?$([regex]::Escape($markerEnd))", $newBlock
            $updated | Out-File -FilePath $prof -Encoding utf8 -NoNewline
            Write-Host "    Updated dotfiles block in $prof"
        } else {
            "`n$newBlock" | Add-Content -Path $prof -Encoding utf8
            Write-Host "    Appended dotfiles block to $prof"
        }
    }
} else {
    Write-Host "    [!] $profileSrc not found, skipping profile setup"
}

Write-Host ""
Write-Host "==> Claude Code config setup complete."
Write-Host "    Restart Claude Code to apply settings."
Write-Host "    Restart PowerShell to apply profile changes."
