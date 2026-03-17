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
Write-Host ""
Write-Host "==> Updating PowerShell profile..."
$profileSrc = "$DotfilesDir\windows\profile.ps1"
if (Test-Path $profileSrc) {
    $markerBegin = "# ===== dotfiles-begin ====="
    $markerEnd   = "# ===== dotfiles-end ====="
    $newBlock    = "$markerBegin`n$(Get-Content $profileSrc -Raw)`n$markerEnd"

    # $PROFILE 디렉토리 생성
    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
    }
    # $PROFILE 파일이 없으면 빈 파일 생성
    if (-not (Test-Path $PROFILE)) {
        New-Item -ItemType File -Force -Path $PROFILE | Out-Null
    }

    $existing = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    if ($null -eq $existing) { $existing = "" }

    if ($existing -match [regex]::Escape($markerBegin)) {
        # 기존 마커 블록 교체
        $updated = $existing -replace "(?s)$([regex]::Escape($markerBegin)).*?$([regex]::Escape($markerEnd))", $newBlock
        $updated | Out-File -FilePath $PROFILE -Encoding utf8 -NoNewline
        Write-Host "    Updated dotfiles block in $PROFILE"
    } else {
        # 마커 블록 추가 (기존 내용 뒤에 추가)
        "`n$newBlock" | Add-Content -Path $PROFILE -Encoding utf8
        Write-Host "    Appended dotfiles block to $PROFILE"
    }
} else {
    Write-Host "    [!] $profileSrc not found, skipping profile setup"
}

Write-Host ""
Write-Host "==> Claude Code config setup complete."
Write-Host "    Run 'claude' and install plugins with /plugin (superpowers, context7)"
Write-Host "    Restart PowerShell to apply profile changes."
