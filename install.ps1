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
        ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^([^#]+)#') { $Matches[1].Trim() } else { $line }
        }
}

function Add-ToUserPath([string]$Dir) {
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    if ($userPath -notlike "*$Dir*") {
        [System.Environment]::SetEnvironmentVariable("PATH", "$userPath;$Dir", "User")
        $env:PATH = "$env:PATH;$Dir"
        return $true
    }
    return $false
}

function Set-ProfileBlock([string]$FilePath, [string]$Content) {
    $begin = "# ===== dotfiles-begin ====="
    $end   = "# ===== dotfiles-end ====="
    $block = "$begin`n$Content`n$end"
    New-Item -ItemType File -Force -Path $FilePath | Out-Null
    $existing = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $existing) { $existing = "" }
    $escaped = [regex]::Escape($begin)
    if ($existing -match $escaped) {
        $before = ($existing -split $escaped)[0]
        $after  = ($existing -split [regex]::Escape($end))[-1]
        "$before$block$after" | Out-File -FilePath $FilePath -Encoding utf8 -NoNewline
        Write-Host "    Updated dotfiles block in $FilePath"
    } else {
        "`n$block" | Add-Content -Path $FilePath -Encoding utf8
        Write-Host "    Appended dotfiles block to $FilePath"
    }
}

$WINGET_ALREADY_INSTALLED = @(0x8A150015, 43, -1978335189)

Write-Host "==> Windows dotfiles setup starting..."
Write-Host "    Source: $ROOT"

# =============================================
# 1. winget 패키지 설치 (manifests/winget.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing packages via winget..."
$wingetFile = Join-Path $ROOT "manifests\winget.txt"
if (Test-Path $wingetFile) {
    Get-ManifestLines $wingetFile | ForEach-Object -Parallel {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $package = $_
        winget install --id $package --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Installed $package"
        } elseif ($using:WINGET_ALREADY_INSTALLED -contains $LASTEXITCODE) {
            Write-Host "    Already installed $package"
        } else {
            Write-Host "    [!] Failed: $package (exit: $LASTEXITCODE)"
        }
    } -ThrottleLimit 4
} else {
    Write-Host "    [!] manifests\winget.txt not found, skipping."
}

# =============================================
# 1-1. gitconfig 설정 병합 (config/git/gitconfig)
# =============================================
Write-Host ""
Write-Host "==> Merging git config..."
$gitConfig = Join-Path $ROOT "config\git\gitconfig"
if (Test-Path $gitConfig) {
    # 기존 global git 설정을 해시테이블로 로드 (중복 방지용)
    $existingConfig = @{}
    git config --global --list 2>$null | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $existingConfig[$Matches[1]] = $Matches[2] }
    }
    $currentSection = $null
    foreach ($line in (Get-Content $gitConfig)) {
        $trimmed = $line.Trim()
        # [section] 헤더 감지
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
        # 주석·빈 줄 제외, key = value 항목만 처리
        } elseif ($trimmed -and -not $trimmed.StartsWith('#') -and $currentSection) {
            if ($trimmed -match '^(\S+)\s*=\s*(.*)$') {
                $key   = $Matches[1]
                $value = $Matches[2].Trim()
                # 이미 설정된 항목은 건너뜀 (사용자 커스텀 설정 보존)
                if (-not $existingConfig.ContainsKey("$currentSection.$key")) {
                    git config --global "$currentSection.$key" $value
                    Write-Host "    Added [$currentSection] $key = $value"
                } else {
                    Write-Host "    Skip  [$currentSection] $key (already set)"
                }
            }
        }
    }
    Write-Host "    gitconfig merged."
} else {
    Write-Host "    [!] config\git\gitconfig not found, skipping."
}

# =============================================
# 1-2. tmux 설정 복사
# =============================================
Write-Host ""
$tmuxSrc = Join-Path $ROOT "config\windows\tmux.conf"
if (Test-Path $tmuxSrc) {
    Copy-Item $tmuxSrc "$env:USERPROFILE\.tmux.conf" -Force
    Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)"
}

# =============================================
# 1-3. YAZI_FILE_ONE 환경 변수 설정 (Git file.exe)
# =============================================
Write-Host ""
Write-Host "==> Setting YAZI_FILE_ONE environment variable..."
$gitFileExePaths = @(
    "C:\Program Files\Git\usr\bin\file.exe",
    "C:\Program Files (x86)\Git\usr\bin\file.exe"
)
$gitFileExe = $gitFileExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($gitFileExe) {
    [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $gitFileExe, "User")
    $env:YAZI_FILE_ONE = $gitFileExe
    Write-Host "    YAZI_FILE_ONE = $gitFileExe"
} else {
    Write-Host "    [!] Git file.exe not found. Install Git for Windows first."
    Write-Host "        winget install --id Git.Git"
}

# =============================================
# 1-4. Neovim PATH 환경변수 설정
# =============================================
Write-Host ""
Write-Host "==> Adding Neovim to PATH..."
$nvimBin = "C:\Program Files\Neovim\bin"
if (Test-Path $nvimBin) {
    if (Add-ToUserPath $nvimBin) { Write-Host "    Added Neovim to PATH: $nvimBin" }
    else { Write-Host "    Neovim already in PATH." }
} else {
    Write-Host "    [!] Neovim not found at $nvimBin. Install via winget: Neovim.Neovim"
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
    fnm env --shell powershell | Out-String | Invoke-Expression
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    Write-Host "    Node.js LTS installed."
} else {
    Write-Host "    [!] fnm not found. Restart terminal and run:"
    Write-Host "        fnm install --lts && fnm default lts-latest"
}

# =============================================
# 2-1. npm 전역 패키지 설치 (manifests/npm-global.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing global npm packages..."
$npmFile = Join-Path $ROOT "manifests\npm-global.txt"
if (Test-Path $npmFile) {
    Get-ManifestLines $npmFile | ForEach-Object -Parallel {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $package = $_
        npm install -g $package 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Installed $package"
        } else {
            Write-Host "    [!] Failed: $package (exit: $LASTEXITCODE)"
        }
    } -ThrottleLimit 4
} else {
    Write-Host "    [!] manifests\npm-global.txt not found, skipping."
}

# =============================================
# 3. Claude Code 설치 (native)
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
# 3-1. Claude Code 설정 배포 (config/claude/ → ~/.claude/)
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
# 3-2. RTK (Rust Token Killer) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing RTK (Rust Token Killer)..."
$localBin = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force -Path $localBin | Out-Null

if (Add-ToUserPath $localBin) { Write-Host "    Added $localBin to User PATH" }
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
# 4. PowerShell 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating PowerShell profiles..."
$profileSrc = Join-Path $ROOT "config\windows\profile.ps1"
if (Test-Path $profileSrc) {
    $profileContent = Get-Content $profileSrc -Raw
    $claudeAlias = "function global:ccd { claude --dangerously-skip-permissions @args }"
    $block = "$profileContent`n$claudeAlias"

    $profilePaths = @("$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1")
    foreach ($prof in $profilePaths) {
        New-Item -ItemType Directory -Force -Path (Split-Path $prof) | Out-Null
        Set-ProfileBlock $prof $block
    }
} else {
    Write-Host "    [!] config\windows\profile.ps1 not found, skipping profile setup."
}

# =============================================
# 5. Git Bash 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating Git Bash profile..."
$bashrcSrc = Join-Path $ROOT "config\bash\bashrc"
if (Test-Path $bashrcSrc) {
    $gitBashPaths = @(
        "C:\Program Files\Git\bin\bash.exe",
        "C:\Program Files (x86)\Git\bin\bash.exe"
    )
    $gitBashFound = $gitBashPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $gitBashFound) {
        Write-Host "    [!] Git Bash not found. Install Git for Windows first."
        Write-Host "        winget install --id Git.Git"
    } else {
        $bashrcContent = Get-Content $bashrcSrc -Raw
        $bashrcPath = "$env:USERPROFILE\.bashrc"
        Set-ProfileBlock $bashrcPath $bashrcContent

        # .inputrc 배포 (마커 방식)
        $inputrcSrc = Join-Path $ROOT "config\bash\inputrc"
        if (Test-Path $inputrcSrc) {
            $inputrcContent = Get-Content $inputrcSrc -Raw
            $inputrcPath = "$env:USERPROFILE\.inputrc"
            Set-ProfileBlock $inputrcPath $inputrcContent
        }

        # ~/.bash_profile이 없으면 생성 (Git Bash 로그인 셸 경고 방지)
        $bashProfilePath = "$env:USERPROFILE\.bash_profile"
        if (-not (Test-Path $bashProfilePath)) {
            Set-Content $bashProfilePath "[[ -f ~/.bashrc ]] && . ~/.bashrc" -Encoding utf8
            Write-Host "    Created $bashProfilePath"
        }
    }
} else {
    Write-Host "    [!] config\bash\bashrc not found, skipping Git Bash setup."
}

# =============================================
# 6. Claude skills 설치 (manifests/skills.txt)
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
