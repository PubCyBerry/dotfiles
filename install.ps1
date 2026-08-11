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
    if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
        Write-Host "    [!] yq not found, keeping existing config.toml"
        return
    }
    & yq -p=toml -o=json '.' $SourcePath 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] source config.toml is invalid, keeping existing config.toml"
        return
    }
    if (-not (Test-Path $DestPath)) {
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "    Copied config.toml"
        return
    }
    & yq -p=toml -o=json '.' $DestPath 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] existing config.toml is invalid, keeping it unchanged"
        return
    }

    $tmp = New-TemporaryFile
    try {
        $merged = @(& yq eval-all -p=toml -o=toml 'select(fileIndex == 0) * select(fileIndex == 1)' $SourcePath $DestPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $merged.Count -eq 0) {
            Write-Host "    [!] config.toml merge failed, keeping existing config.toml"
            return
        }
        ($merged -join "`n") | Out-File $tmp -Encoding utf8 -NoNewline
        & yq -p=toml -o=json '.' $tmp 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] merged config.toml is invalid, keeping existing config.toml"
            return
        }
        Move-Item $tmp $DestPath -Force
        Write-Host "    Merged config.toml (existing values preserved)"
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Merge-JsonRegistry([string]$SourcePath, [string]$DestPath) {
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [!] $SourcePath not found, skipping."
        return
    }
    if (-not (Test-Path $DestPath)) {
        Copy-Item $SourcePath $DestPath -Force
        Write-Host "    Copied $(Split-Path $DestPath -Leaf)"
        return
    }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host "    [!] jq not found, keeping existing $(Split-Path $DestPath -Leaf)"
        return
    }
    $filterPath = Join-Path $ROOT "scripts\merge-json-registry.jq"
    if (-not (Test-Path $filterPath)) {
        Write-Host "    [!] merge-json-registry.jq not found, keeping existing $(Split-Path $DestPath -Leaf)"
        return
    }

    $tmp = New-TemporaryFile
    try {
        & jq -s -f $filterPath $DestPath $SourcePath 2>$null | Out-File $tmp -Encoding utf8 -NoNewline
        if ($LASTEXITCODE -ne 0 -or (Get-Item $tmp).Length -eq 0) {
            Write-Host "    [!] jq merge failed, keeping existing $(Split-Path $DestPath -Leaf)"
            return
        }
        Move-Item $tmp $DestPath -Force
        Write-Host "    Merged $(Split-Path $DestPath -Leaf)"
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

if ($env:DOTFILES_FUNCTIONS_ONLY -eq "1") { return }

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
        # 사전 점검: 실행 중인 프로세스가 대상 파일을 잠그면 설치 관리자가 실패한다.
        #   Git.Git(Inno Setup) — bash/ssh가 살아 있으면 "process(es) use Git for Windows"
        #                         메시지 박스가 억제된 채 Cancel 처리되어 exit 1 → 0x8A150006
        #   marlocarlo.psmux(portable) — tmux.exe 교체 시 "Access is denied" → 0x8A150052
        # 설치 전에 알려야 사용자가 세션을 정리하고 재실행할 수 있다.
        $LockBlockers = @{
            'Git.Git'          = @('bash', 'sh', 'ssh', 'git')
            'marlocarlo.psmux' = @('tmux')
        }
        foreach ($entry in $LockBlockers.GetEnumerator()) {
            $running = @($entry.Value |
                ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } |
                Group-Object ProcessName |
                ForEach-Object { "$($_.Name) x$($_.Count)" })
            if ($running.Count -gt 0) {
                Write-Host "    [warn] $($entry.Key): 파일을 잠그는 프로세스 실행 중 — $($running -join ', ')"
                Write-Host "           업그레이드 실패 시 해당 프로세스 종료 후 재실행 필요."
            }
        }

        $WingetLogDir = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"

        $results = Get-ManifestLines $wingetFile | ForEach-Object -Parallel {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $package = $_
            $logDir  = $using:WingetLogDir

            # winget 종료 코드 → 원인. $LASTEXITCODE는 부호 있는 int라 두 자리 보수 hex로 비교한다.
            $codes = @{
                '8A15002B' = '최신 버전 — 적용할 업데이트 없음'
                '8A150006' = '설치 관리자가 실패 코드 반환 — 대상 파일 사용 중이거나 권한 부족'
                '8A150011' = '적용 가능한 installer 없음 — 아키텍처/스코프 불일치'
                '8A150014' = '일치하는 패키지 없음 — --exact는 ID 대소문자를 구분한다'
                '8A150044' = '패키지 사용 계약 미동의'
                '8A150052' = 'portable 설치 실패 — 교체 대상 exe가 실행 중'
                '8A150056' = '설치 위치 사용 불가'
            }

            # `winget list` 출력에서 설치 버전 추출.
            # 헤더가 로케일별로 다르므로 컬럼명 대신 ID 토큰 다음 토큰을 읽는다.
            #   예: "yq   MikeFarah.yq 4.53.3 winget" → 4.53.3
            $parseVer = {
                param($text, $id)
                foreach ($line in ($text -split "`r?`n")) {
                    $t = @($line -split '\s+' | Where-Object { $_ })
                    for ($i = 0; $i -lt $t.Count - 1; $i++) {
                        if ($t[$i] -ieq $id) { return $t[$i + 1] }
                    }
                }
                return ''
            }

            $listOut = (winget list --id $package --exact --accept-source-agreements 2>&1 | Out-String)
            $isInstalled = ($LASTEXITCODE -eq 0)
            $beforeVer = if ($isInstalled) { & $parseVer $listOut $package } else { '' }

            if (-not $isInstalled) {
                $verb = 'install'
                $out  = (winget install --id $package --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
            } else {
                $verb = 'upgrade'
                $out  = (winget upgrade --id $package --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
            }
            $code = $LASTEXITCODE
            $hex  = '{0:X8}' -f $code
            $why  = if ($codes.ContainsKey($hex)) { " — $($codes[$hex])" } else { '' }
            $pad  = $package.PadRight(28)

            if ($code -eq 0) {
                $afterOut = (winget list --id $package --exact --accept-source-agreements 2>&1 | Out-String)
                $afterVer = & $parseVer $afterOut $package
                if ($verb -eq 'install') {
                    Write-Host "    [install]  $pad $afterVer"
                    $status = 'install'
                } else {
                    $delta = if ($beforeVer -and $afterVer -and $beforeVer -ne $afterVer) { "$beforeVer -> $afterVer" } else { $afterVer }
                    Write-Host "    [upgrade]  $pad $delta"
                    $status = 'upgrade'
                }
            } elseif ($hex -eq '8A15002B') {
                Write-Host "    [current]  $pad $beforeVer"
                $status = 'current'
            } else {
                Write-Host "    [!] $verb failed: $pad 0x$hex$why"
                # winget이 출력한 마지막 실질 메시지 — 코드만으로는 안 보이는 실패 사유가 여기 있다.
                $tail = @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Last 2)
                foreach ($t in $tail) { Write-Host "           winget: $t" }
                Write-Host "           상세 로그: $logDir"
                $status = 'failed'
            }

            [pscustomobject]@{ Package = $package; Status = $status; Code = $hex }
        } -ThrottleLimit 4

        # 요약 — 실패 목록을 마지막에 다시 모아 스크롤 위로 사라지지 않게 한다.
        $byStatus = $results | Group-Object Status | ForEach-Object { "$($_.Name) $($_.Count)" }
        Write-Host "    ---- winget 요약: $($byStatus -join ' / ')"
        $failed = @($results | Where-Object { $_.Status -eq 'failed' })
        foreach ($f in $failed) {
            Write-Host "    [!] 실패: $($f.Package) (0x$($f.Code))"
        }
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

    # 구버전 정리 — LTS가 올라가면 이전 버전은 디스크만 차지한다(버전당 ~100MB).
    # 현재 활성(=default) 버전만 남긴다. 다른 셸이 구버전을 쓰고 있었다면 그 셸의
    # fnm junction이 끊기므로 정리 후에는 셸을 새로 열어야 한다.
    $activeVer = (fnm current 2>$null)
    if ($activeVer -match '^v\d') {
        $installedVers = @(fnm list 2>$null | ForEach-Object {
            if ($_ -match '(v\d+\.\d+\.\d+)') { $Matches[1] }
        } | Select-Object -Unique)
        $staleVers = @($installedVers | Where-Object { $_ -ne $activeVer })
        foreach ($ver in $staleVers) {
            fnm uninstall $ver 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Removed old Node: $ver"
            } else {
                Write-Host "    [!] Node $ver 삭제 실패 — 해당 버전을 쓰는 셸이 열려 있는지 확인."
            }
        }
        if ($staleVers.Count -eq 0) { Write-Host "    No old Node versions ($activeVer only)." }
    } else {
        Write-Host "    [!] fnm current를 읽지 못해 구버전 정리를 건너뜀."
    }

    # fnm aliases\default → User PATH 영구 등록 (MCP 서버 등 비쉘 프로세스에서 npx 접근 가능)
    $fnmDefaultPath = Join-Path $env:APPDATA "fnm\aliases\default"
    if (Test-Path $fnmDefaultPath) {
        if (Add-ToUserPath $fnmDefaultPath) { Write-Host "    Added fnm aliases\default to User PATH: $fnmDefaultPath" }
        else { Write-Host "    fnm aliases\default already in User PATH." }
    } else {
        Write-Host "    [!] fnm aliases\default not found. Run: fnm default lts-latest"
    }

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
# 2-2. Codex 설정 배포 (config/codex/ + config/agents/global.md → ~/.codex/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Codex config..."
New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null

Merge-CodexConfig `
    (Join-Path $ROOT "config\codex\config.toml") `
    (Join-Path $CodexDir "config.toml")

$agentsGlobalSrc = Join-Path $ROOT "config\agents\global.md"
$rolesSrc = Join-Path $ROOT "config\agents\roles"
if (Test-Path $agentsGlobalSrc) {
    Copy-Item $agentsGlobalSrc (Join-Path $CodexDir "AGENTS.md") -Force
    Write-Host "    Copied global agent instructions to AGENTS.md"
} else {
    Write-Host "    [!] config\agents\global.md not found"
}

# 공용 role: config\agents\roles\<name>\ = codex.toml + body.md 조립
# → ~\.codex\agents\<name>.toml (Codex subagent. body.md는 developer_instructions 값이 된다)
if (Test-Path $rolesSrc) {
    $codexAgentsDst = Join-Path $CodexDir "agents"
    New-Item -ItemType Directory -Force -Path $codexAgentsDst | Out-Null
    Get-ChildItem $rolesSrc -Directory | ForEach-Object {
        $meta = Join-Path $_.FullName "codex.toml"
        $body = Join-Path $_.FullName "body.md"
        if ((Test-Path $meta) -and (Test-Path $body)) {
            $metaText = (Get-Content $meta -Raw)
            $bodyText = (Get-Content $body -Raw)
            if (-not $metaText.EndsWith("`n")) { $metaText += "`n" }
            if (-not $bodyText.EndsWith("`n")) { $bodyText += "`n" }
            # TOML literal multi-line string(''') — 이스케이프 해석이 없어 body를 그대로 담는다
            $content = $metaText + "developer_instructions = '''`n" + $bodyText + "'''`n"
            Set-Content -Path (Join-Path $codexAgentsDst "$($_.Name).toml") -Value $content -NoNewline -Encoding utf8
            Write-Host "    Deployed agent: $($_.Name)"

            # 구 배포물 정리: 이전에는 같은 role을 skill로 배포했다 (~\.codex\skills\<name>\)
            $legacySkill = Join-Path $CodexDir "skills\$($_.Name)"
            if (Test-Path (Join-Path $legacySkill "SKILL.md")) {
                Remove-Item $legacySkill -Recurse -Force
                Write-Host "    Removed legacy skill: $($_.Name)"
            }
        }
    }
}

# hooks.json: 사용자 hook 보존 + dotfiles 관리 command upsert
$codexHooksJsonSrc = Join-Path $ROOT "config\codex\hooks.json"
if (Test-Path $codexHooksJsonSrc) {
    Merge-JsonRegistry $codexHooksJsonSrc (Join-Path $CodexDir "hooks.json")
} else {
    Write-Host "    [!] config\codex\hooks.json not found"
}

# hooks/temporal-context.sh 배포
$codexHooksDir = Join-Path $CodexDir "hooks"
$temporalSrc   = Join-Path $ROOT "config\codex\hooks\temporal-context.sh"
if (Test-Path $temporalSrc) {
    New-Item -ItemType Directory -Force -Path $codexHooksDir | Out-Null
    Copy-Item $temporalSrc $codexHooksDir -Force
    Write-Host "    Copied temporal-context.sh to ~/.codex/hooks/"
} else {
    Write-Host "    [!] config\codex\hooks\temporal-context.sh not found, skipping."
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

# claude native 바이너리는 ~\.local\bin 에 설치된다. 셸이 아닌 프로세스(MCP 서버 등)도
# 찾을 수 있도록 User PATH에 등록한다.
New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null
if (Add-ToUserPath $LocalBin) { Write-Host "    Added $LocalBin to User PATH" }

# =============================================
# 3-1. Claude Code 설정 배포 (config/claude/ + config/agents/global.md → ~/.claude/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Claude Code config..."
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

# settings.json: 사용자 nested 설정 보존 + dotfiles 관리 hook upsert
$settingsSrc = Join-Path $ROOT "config\claude\settings.json"
$settingsDst = Join-Path $ClaudeDir "settings.json"
if (Test-Path $settingsSrc) {
    Merge-JsonRegistry $settingsSrc $settingsDst
} else {
    Write-Host "    [!] config\claude\settings.json not found"
}

if (Test-Path $agentsGlobalSrc) {
    Copy-Item $agentsGlobalSrc (Join-Path $ClaudeDir "CLAUDE.md") -Force
    Write-Host "    Copied global agent instructions to CLAUDE.md"
} else {
    Write-Host "    [!] config\agents\global.md not found"
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

# 로컬 skills/: dotfiles 소유 skill만 디렉터리 단위 배포 (원격 npx skill 보존)
$skillsLocalSrc = Join-Path $ROOT "config\claude\skills"
if (Test-Path $skillsLocalSrc) {
    $skillsDst = Join-Path $ClaudeDir "skills"
    New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
    Get-ChildItem $skillsLocalSrc -Directory | ForEach-Object {
        Copy-Item $_.FullName $skillsDst -Recurse -Force
        Write-Host "    Deployed local skill: $($_.Name)"
    }
}

# 공용 role: config\agents\roles\<name>\ = claude.frontmatter + body.md 조립
# → ~\.claude\agents\<name>.md (사용자가 직접 만든 다른 agent 파일은 보존)
if (Test-Path $rolesSrc) {
    $agentsDst = Join-Path $ClaudeDir "agents"
    New-Item -ItemType Directory -Force -Path $agentsDst | Out-Null
    Get-ChildItem $rolesSrc -Directory | ForEach-Object {
        $fm = Join-Path $_.FullName "claude.frontmatter"
        $body = Join-Path $_.FullName "body.md"
        if ((Test-Path $fm) -and (Test-Path $body)) {
            $content = (Get-Content $fm -Raw) + (Get-Content $body -Raw)
            Set-Content -Path (Join-Path $agentsDst "$($_.Name).md") -Value $content -NoNewline -Encoding utf8
            Write-Host "    Deployed agent: $($_.Name)"
        }
    }
}

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

# =============================================
# 7. Claude Code 플러그인 설치 (manifests/plugins.txt)
# =============================================
Write-Host ""
Write-Host "==> Restoring Claude Code plugins..."
$pluginsFile = Join-Path $ROOT "manifests\plugins.txt"
if ((Test-Path $pluginsFile) -and (Get-Command claude -ErrorAction SilentlyContinue)) {
    Get-ManifestLines $pluginsFile | ForEach-Object {
        # <marketplace-source> <plugin>@<marketplace> [scope]
        $fields = $_ -split '\s+'
        if ($fields.Count -lt 2) { return }
        $market = $fields[0]
        $plugin = $fields[1]
        $scope  = if ($fields.Count -ge 3 -and $fields[2]) { $fields[2] } else { "user" }

        Write-Host "    Adding marketplace: $market (scope: $scope)..."
        claude plugin marketplace add $market --scope $scope 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed to add marketplace: $market"
            return
        }

        Write-Host "    Installing plugin: $plugin (scope: $scope)..."
        claude plugin install $plugin --scope $scope 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed to install plugin: $plugin"
        }
    }
    Write-Host "    Plugins restored."
} else {
    Write-Host "    [!] manifests\plugins.txt or claude not found, skipping plugins."
}

Write-Host ""
Write-Host "==> Done! Restart your terminal, Codex, and Claude Code to apply all changes."
