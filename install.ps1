# Windows dotfiles 설치 진입점 (all-in-one)
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT = $PSScriptRoot

# =============================================
# 경로 상수
# =============================================
$ClaudeDir     = Join-Path $env:USERPROFILE ".claude"
$CodexDir      = Join-Path $env:USERPROFILE ".codex"
$LocalBin      = Join-Path $env:USERPROFILE ".local\bin"
$NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$NvimBin       = "C:\Program Files\Neovim\bin"
$GitBashPaths  = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)
$GitFileExePaths = @(
    "C:\Program Files\Git\usr\bin\file.exe",
    "C:\Program Files (x86)\Git\usr\bin\file.exe"
)

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

    # 기존 마커 블록을 정규식으로 완전 교체 (Singleline으로 개행 포함 매칭)
    $pattern    = [regex]::Escape($begin) + ".*?" + [regex]::Escape($end)
    $newContent = [regex]::Replace($existing, $pattern, $block,
                      [System.Text.RegularExpressions.RegexOptions]::Singleline)

    if ($newContent -eq $existing) {
        $newContent = "$existing`n$block"
        Write-Host "    Appended dotfiles block to $FilePath"
    } else {
        Write-Host "    Updated dotfiles block in $FilePath"
    }
    $newContent | Out-File -FilePath $FilePath -Encoding utf8 -NoNewline
}

function Merge-GitConfig([string]$FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Host "    [!] $FilePath not found, skipping."
        return
    }
    # 기존 global git 설정을 해시테이블로 로드 (중복 방지용)
    $existingConfig = @{}
    git config --global --list 2>$null | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $existingConfig[$Matches[1]] = $Matches[2] }
    }
    $currentSection = $null
    foreach ($line in (Get-Content $FilePath)) {
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
}

function Merge-CodexConfig([string]$SourcePath, [string]$DestPath) {
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [!] $SourcePath not found, skipping."
        return
    }

    if (-not (Test-Path $DestPath)) {
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "    Copied config.toml"
        return
    }

    # Parse source: srcData[section][key] = rawLine ("" = top-level)
    $srcData = [ordered]@{ "" = [ordered]@{} }
    $curSec  = ""
    foreach ($line in (Get-Content $SourcePath)) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') {
            $curSec = $Matches[1]
            if (-not $srcData.Contains($curSec)) { $srcData[$curSec] = [ordered]@{} }
        } elseif ($t -and -not $t.StartsWith('#') -and $t -match '^([^=\s]+)\s*=') {
            $srcData[$curSec][$Matches[1]] = $line
        }
    }

    # Walk destination: override matching keys, flush missing keys on section boundary
    $out     = [System.Collections.Generic.List[string]]::new()
    $seen    = @{ "" = [System.Collections.Generic.HashSet[string]]::new() }
    $seenSec = [System.Collections.Generic.HashSet[string]]@("")
    $curSec  = ""

    $flushMissing = {
        param($sec)
        if ($srcData.Contains($sec)) {
            foreach ($k in $srcData[$sec].Keys) {
                if (-not $seen[$sec].Contains($k)) {
                    $out.Add($srcData[$sec][$k])
                    Write-Host "    Added [$sec] $k"
                }
            }
        }
    }

    foreach ($line in (Get-Content $DestPath)) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') {
            & $flushMissing $curSec
            $curSec = $Matches[1]
            $seenSec.Add($curSec) | Out-Null
            if (-not $seen.ContainsKey($curSec)) { $seen[$curSec] = [System.Collections.Generic.HashSet[string]]::new() }
            $out.Add($line)
        } elseif ($t -and -not $t.StartsWith('#') -and $t -match '^([^=\s]+)\s*=') {
            $key = $Matches[1]
            if (-not $seen.ContainsKey($curSec)) { $seen[$curSec] = [System.Collections.Generic.HashSet[string]]::new() }
            $seen[$curSec].Add($key) | Out-Null
            if ($srcData.Contains($curSec) -and $srcData[$curSec].Contains($key)) {
                $out.Add($srcData[$curSec][$key])
                if ($srcData[$curSec][$key] -ne $line) { Write-Host "    Override [$curSec] $key" }
            } else {
                $out.Add($line)
            }
        } else {
            $out.Add($line)
        }
    }
    & $flushMissing $curSec

    # Prepend missing top-level keys
    $topMissing = [System.Collections.Generic.List[string]]::new()
    foreach ($k in $srcData[""].Keys) {
        if (-not $seen[""].Contains($k)) {
            $topMissing.Add($srcData[""][$k])
            Write-Host "    Added top-level $k"
        }
    }
    if ($topMissing.Count -gt 0) { $out.InsertRange(0, $topMissing) }

    # Append missing sections
    foreach ($s in $srcData.Keys) {
        if ($s -eq "" -or $seenSec.Contains($s)) { continue }
        $out.Add("")
        $out.Add("[$s]")
        foreach ($k in $srcData[$s].Keys) { $out.Add($srcData[$s][$k]) }
        Write-Host "    Added section [$s]"
    }

    ($out -join "`n") | Out-File $DestPath -Encoding utf8 -NoNewline
    Write-Host "    Merged config.toml (source overrides destination)"
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
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Get-ManifestLines $wingetFile | ForEach-Object -Parallel {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $package = $_
            $alreadyInstalled = @(0x8A150015, 43, -1978335189)
            winget install --id $package --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Installed $package"
            } elseif ($alreadyInstalled -contains $LASTEXITCODE) {
                Write-Host "    Already installed $package"
            } else {
                Write-Host "    [!] Failed: $package (exit: $LASTEXITCODE)"
            }
        } -ThrottleLimit 4
    } else {
        Write-Host "    [!] winget not found. Skipping package installation."
    }
} else {
    Write-Host "    [!] manifests\winget.txt not found, skipping."
}

# =============================================
# 1-1. gitconfig 설정 병합 (config/git/gitconfig)
# =============================================
Write-Host ""
Write-Host "==> Merging git config..."
Merge-GitConfig (Join-Path $ROOT "config\git\gitconfig")

# Windows 전용 git 설정 주입 (공유 gitconfig는 OS-중립)
git config --global core.autocrlf true
git config --global core.fileMode false
Write-Host "    Set core.autocrlf=true, core.fileMode=false (Windows)"

# =============================================
# 1-2. tmux 설정 복사
# =============================================
Write-Host ""
$tmuxSrc = Join-Path $ROOT "config\tmux\tmux.windows.conf"
if (Test-Path $tmuxSrc) {
    Copy-Item $tmuxSrc (Join-Path $env:USERPROFILE ".tmux.conf") -Force
    Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)"
}

# =============================================
# 1-3. YAZI_FILE_ONE 환경 변수 설정 (Git file.exe)
# =============================================
Write-Host ""
Write-Host "==> Setting YAZI_FILE_ONE environment variable..."
$gitFileExe = $GitFileExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($gitFileExe) {
    [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $gitFileExe, "User")
    $env:YAZI_FILE_ONE = $gitFileExe
    Write-Host "    YAZI_FILE_ONE = $gitFileExe"
} else {
    Write-Host "    [!] Git file.exe not found. Install Git for Windows first."
    Write-Host "        winget install --id Git.Git"
}

# =============================================
# 1-4. yazi 설정 파일 배포
# =============================================
Write-Host ""
Write-Host "==> Deploying yazi config..."
$yaziConfigSrc = Join-Path $ROOT "config\yazi"
$yaziConfigDst = Join-Path $env:APPDATA "yazi\config"
if (Test-Path $yaziConfigSrc) {
    New-Item -ItemType Directory -Force -Path $yaziConfigDst | Out-Null
    Copy-Item "$yaziConfigSrc\*" $yaziConfigDst -Recurse -Force
    Write-Host "    yazi config deployed to $yaziConfigDst"
} else {
    Write-Host "    [!] config\yazi not found, skipping."
}

# =============================================
# 1-5. Neovim PATH 환경변수 설정
# =============================================
Write-Host ""
Write-Host "==> Adding Neovim to PATH..."
if (Test-Path $NvimBin) {
    if (Add-ToUserPath $NvimBin) { Write-Host "    Added Neovim to PATH: $NvimBin" }
    else { Write-Host "    Neovim already in PATH." }
} else {
    Write-Host "    [!] Neovim not found at $NvimBin. Install via winget: Neovim.Neovim"
}

# =============================================
# 1-6. lazy.nvim Structured Setup
# =============================================
Write-Host ""
Write-Host "==> Setting up lazy.nvim (Neovim Plugin Manager - Structured Setup)..."
$nvimSrc = Join-Path $ROOT "config\nvim"

if (-not (Test-Path (Join-Path $nvimSrc "init.lua"))) {
    Write-Host "    [!] config\nvim\init.lua not found, skipping."
} else {
    New-Item -ItemType Directory -Force -Path $NvimConfigDir | Out-Null
    Copy-Item "$nvimSrc\*" $NvimConfigDir -Recurse -Force
    Write-Host "    lazy.nvim config deployed to $NvimConfigDir"
    Write-Host "    Run nvim to auto-install lazy.nvim on first launch."
}

# =============================================
# 2. Node.js LTS 설치 (fnm)
# =============================================
Write-Host ""
Write-Host "==> Installing Node.js LTS..."
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm env --shell powershell | Out-String | Invoke-Expression
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    Write-Host "    Node.js LTS installed."

    # statusLine.command의 fnm node 버전 경로 갱신 (버전 업 시 깨지는 절대 경로 수정)
    $nodeVer = "v$((node --version 2>$null).TrimStart('v'))"
    $settingsPath = Join-Path $ClaudeDir "settings.json"
    if ((Test-Path $settingsPath) -and $nodeVer -match '^v\d') {
        $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
        $cmd = $settings.statusLine.command
        if ($cmd -match '/fnm/node-versions/(v[\d.]+)/installation/node') {
            $oldVer = $Matches[1]
            if ($oldVer -ne $nodeVer) {
                $settings.statusLine.command = $cmd -replace [regex]::Escape("/fnm/node-versions/$oldVer/installation/node"), "/fnm/node-versions/$nodeVer/installation/node"
                $settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
                Write-Host "    Patched statusLine node path: $oldVer → $nodeVer"
            } else {
                Write-Host "    statusLine node path already up to date ($nodeVer)"
            }
        }
    }
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
# 2-2. Codex 설정 배포 (config/codex/ → ~/.codex/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Codex config..."
New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null

Merge-CodexConfig `
    (Join-Path $ROOT "config\codex\config.toml") `
    (Join-Path $CodexDir "config.toml")

$codexAgentsSrc = Join-Path $ROOT "config\codex\AGENTS.md"
if (Test-Path $codexAgentsSrc) {
    Copy-Item $codexAgentsSrc (Join-Path $CodexDir "AGENTS.md") -Force
    Write-Host "    Copied AGENTS.md"
} else {
    Write-Host "    [!] config\codex\AGENTS.md not found"
}

# hooks.json: 단순 복사
$codexHooksJsonSrc = Join-Path $ROOT "config\codex\hooks.json"
if (Test-Path $codexHooksJsonSrc) {
    Copy-Item $codexHooksJsonSrc (Join-Path $CodexDir "hooks.json") -Force
    Write-Host "    Copied hooks.json"
} else {
    Write-Host "    [!] config\codex\hooks.json not found"
}

# hooks/temporal-context.sh 배포
$codexHooksDir = Join-Path $CodexDir "hooks"
$temporalSrc   = Join-Path $ROOT "config\claude\hooks\temporal-context.sh"
if (Test-Path $temporalSrc) {
    New-Item -ItemType Directory -Force -Path $codexHooksDir | Out-Null
    Copy-Item $temporalSrc $codexHooksDir -Force
    Write-Host "    Copied temporal-context.sh to ~/.codex/hooks/"
} else {
    Write-Host "    [!] config\claude\hooks\temporal-context.sh not found, skipping."
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
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

# settings.json: 병합 (기존에 없는 키 보존 — claude-hud의 statusLine 등)
$settingsSrc = Join-Path $ROOT "config\claude\settings.json"
$settingsDst = Join-Path $ClaudeDir "settings.json"
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
    Copy-Item $claudeMdSrc (Join-Path $ClaudeDir "CLAUDE.md") -Force
    Write-Host "    Copied CLAUDE.md"
} else {
    Write-Host "    [!] config\claude\CLAUDE.md not found"
}

# hooks/: 배포 (temporal-context.sh 등)
$hooksSrc = Join-Path $ROOT "config\claude\hooks"
$hooksDst = Join-Path $ClaudeDir "hooks"
if (Test-Path $hooksSrc) {
    New-Item -ItemType Directory -Force -Path $hooksDst | Out-Null
    Copy-Item "$hooksSrc\*" $hooksDst -Recurse -Force
    Write-Host "    Copied hooks/"
} else {
    Write-Host "    [!] config\claude\hooks not found, skipping."
}

# =============================================
# 3-2. RTK (Rust Token Killer) 설치
# =============================================
Write-Host ""
Write-Host "==> Installing RTK (Rust Token Killer)..."
New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null

if (Add-ToUserPath $LocalBin) { Write-Host "    Added $LocalBin to User PATH" }

try {
    $release = Invoke-RestMethod "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.zip$" } | Select-Object -First 1
    if ($asset) {
        $tmpZip = "$env:TEMP\rtk-windows.zip"
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing
        Expand-Archive -Path $tmpZip -DestinationPath $LocalBin -Force
        Remove-Item $tmpZip -Force
        Write-Host "    RTK installed."
    } else {
        Write-Host "    [!] RTK Windows 바이너리를 찾을 수 없음. 수동 설치: cargo install rtk"
    }
} catch {
    Write-Host "    [!] RTK 설치 실패: $_"
}

# Claude hook 등록은 config\claude\settings.json의 `rtk hook claude` 엔트리로 미리 정의되어 있고 3-1 단계의 settings.json 병합으로 반영됨

# =============================================
# 4. PowerShell 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating PowerShell profiles..."
$profileSrc = Join-Path $ROOT "config\powershell\profile.ps1"
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
    $gitBashFound = $GitBashPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $gitBashFound) {
        Write-Host "    [!] Git Bash not found. Install Git for Windows first."
        Write-Host "        winget install --id Git.Git"
    } else {
        $bashrcContent = Get-Content $bashrcSrc -Raw
        $bashrcPath = Join-Path $env:USERPROFILE ".bashrc"
        Set-ProfileBlock $bashrcPath $bashrcContent

        # .inputrc 배포 (마커 방식)
        $inputrcSrc = Join-Path $ROOT "config\bash\inputrc"
        if (Test-Path $inputrcSrc) {
            $inputrcContent = Get-Content $inputrcSrc -Raw
            $inputrcPath = Join-Path $env:USERPROFILE ".inputrc"
            Set-ProfileBlock $inputrcPath $inputrcContent
        }

        # ~/.bash_profile이 없으면 생성 (Git Bash 로그인 셸 경고 방지)
        $bashProfilePath = Join-Path $env:USERPROFILE ".bash_profile"
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
            npx -y skills add $repoSlug --skill $skillName --global --yes --agent claude-code 2>&1 | Out-Null
        }
    }
    Write-Host "    Skills restored."
} else {
    Write-Host "    [!] manifests\skills.txt not found, skipping skills."
}

Write-Host ""
Write-Host "==> Done! Restart your terminal, Codex, and Claude Code to apply all changes."
