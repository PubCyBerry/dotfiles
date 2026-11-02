# Windows 설치. 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1
# 여러 번 실행해도 된다. 실패한 단계는 마지막에 모아 보여 주고 종료 코드 1로 끝난다.
#Requires -Version 7

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8   # jq·yq·winget 출력의 한글이 깨지지 않게 한다

$Root = $PSScriptRoot
$UserHome = $env:USERPROFILE
$Failed = [Collections.Generic.List[string]]::new()
$env:PATH = "$UserHome\.local\bin;$env:PATH"        # Claude Code 공식 installer가 설치하는 위치

function Fail([string]$Message) { Write-Warning $Message; $Failed.Add($Message) }

# 단계 하나가 예외로 끝나도 다음 단계는 계속한다
function Invoke-Step([string]$Name, [scriptblock]$Action) {
    Write-Host "`n==> $Name"
    try { & $Action } catch { Fail "${Name}: $($_.Exception.Message)" }
}

# 매니페스트에서 주석과 빈 줄을 뺀 항목
function Get-Manifest([string]$Name) {
    Get-Content (Join-Path $Root "manifests\$Name") |
        ForEach-Object { ($_ -replace '#.*').Trim() } |
        Where-Object { $_ }
}

# BOM 없는 UTF-8, LF로 쓴다. Git Bash가 읽는 파일에 CR이 섞이면 안 된다.
function Write-Text([string]$Path, [string]$Text) {
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n").TrimEnd() + "`n", [Text.UTF8Encoding]::new($false))
}

# 새로 설치된 도구를 이 세션에서도 찾도록 레지스트리의 PATH를 덧붙인다
function Sync-Path {
    $have = $env:PATH -split ';'
    $registry = [Environment]::GetEnvironmentVariable('PATH', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('PATH', 'User')
    $env:PATH = (@($have) + @($registry -split ';' | Where-Object { $_ -and $have -notcontains $_ })) -join ';'
}

function Add-UserPath([string]$Dir) {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
    $path = [string]$key.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
    $entries = $path -split ';' | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_) }
    if ($entries -notcontains $Dir) { $key.SetValue('Path', "$path;$Dir".Trim(';'), 'ExpandString') }
    $key.Close()
}

# 저장소 파일이나 디렉터리를 덮어쓴다. 원본은 git에 있으므로 백업하지 않는다.
function Deploy([string]$Source, [string]$Dest) {
    $src = Join-Path $Root $Source
    if (Test-Path $src -PathType Leaf) {
        New-Item -ItemType Directory -Force -Path (Split-Path $Dest) | Out-Null
        Copy-Item -LiteralPath $src -Destination $Dest -Force
        return
    }
    foreach ($file in Get-ChildItem $src -Recurse -File) {
        $to = Join-Path $Dest ([IO.Path]::GetRelativePath($src, $file.FullName))
        New-Item -ItemType Directory -Force -Path (Split-Path $to) | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $to -Force
    }
}

# 앱이 스스로 다시 쓰는 설정 파일은 병합한다. 겹치는 키는 기존 값이 이긴다.
function Merge-Config([string]$Source, [string]$Dest) {
    if (-not (Test-Path $Dest)) { return Deploy $Source $Dest }
    $src = Join-Path $Root $Source
    $merged = if ($Source.EndsWith('.json')) {
        jq -s '.[0] * .[1]' $src $Dest
    } else {
        yq eval-all -p toml -o toml 'select(fileIndex == 0) * select(fileIndex == 1)' $src $Dest
    }
    if ($LASTEXITCODE -or -not $merged) { return Fail "merge failed: $Dest" }
    Write-Text $Dest ($merged -join "`n")
}

# 마커 사이 블록만 교체한다. 블록 밖의 사용자 내용은 그대로 둔다.
function Set-ProfileBlock([string]$Path, [string]$Content) {
    $begin, $end = '# ===== dotfiles-begin =====', '# ===== dotfiles-end ====='
    $kept = [Collections.Generic.List[string]]::new()
    $inBlock = $false
    foreach ($line in @(if (Test-Path $Path) { Get-Content $Path })) {
        if ($line -eq $begin) { $inBlock = $true }
        if (-not $inBlock) { $kept.Add($line) }
        if ($line -eq $end) { $inBlock = $false }
    }
    Write-Text $Path ((@($kept) + $begin + $Content.Trim() + $end) -join "`n")
}

# 스스로 업데이트하는 도구는 없을 때만 공식 installer로 설치한다.
# installer 안의 exit가 이 스크립트를 끝내지 않도록 별도 프로세스에서 실행한다.
function Install-IfMissing([string]$Command, [string]$Url) {
    if (Get-Command $Command -ErrorAction SilentlyContinue) { return Write-Host "    $Command (installed)" }
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "irm $Url | iex"
    if ($LASTEXITCODE) { Fail "$Command installer failed: $Url" }
    Sync-Path
}

Invoke-Step 'winget packages' {
    foreach ($id in Get-Manifest 'winget.txt') {
        $out = winget install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1
        # 0x8A15002B: 이미 최신이라 업그레이드할 것이 없다
        if ($LASTEXITCODE -in 0, -1978335189) { Write-Host "    $id"; continue }
        $reason = $out | Where-Object { "$_".Trim().Length -gt 3 } | Select-Object -Last 1
        Fail ('winget {0}: 0x{1:X8} {2}' -f $id, $LASTEXITCODE, $reason)
    }
    Sync-Path
}

Invoke-Step 'git config' {
    # gitconfig의 키 중 아직 값이 없는 것만 넣는다. 이미 있는 값은 사용자 설정이다.
    foreach ($entry in git config --file (Join-Path $Root 'config\git\gitconfig') --list) {
        $name, $value = $entry -split '=', 2
        git config --global --get $name *> $null
        if ($LASTEXITCODE) { git config --global $name $value }
    }
    git config --global core.autocrlf true
    git config --global core.fileMode false
}

Invoke-Step 'config files' {
    $agentsMd = 'config\agents\global.md'
    Merge-Config 'config\claude\settings.json' "$UserHome\.claude\settings.json"
    Deploy $agentsMd "$UserHome\.claude\CLAUDE.md"
    Deploy 'config\claude\hooks' "$UserHome\.claude\hooks"
    Deploy 'config\claude\statusline.sh' "$UserHome\.claude\statusline.sh"
    Deploy 'config\claude\claude-hud.json' "$UserHome\.claude\claude-hud.json"
    Merge-Config 'config\codex\config.toml' "$UserHome\.codex\config.toml"
    Merge-Config 'config\codex\hooks.json' "$UserHome\.codex\hooks.json"
    Deploy $agentsMd "$UserHome\.codex\AGENTS.md"
    Deploy 'config\codex\hooks' "$UserHome\.codex\hooks"
    Merge-Config 'config\agy\hooks.json' "$UserHome\.gemini\config\hooks.json"
    Deploy $agentsMd "$UserHome\.gemini\GEMINI.md"
    Deploy $agentsMd "$UserHome\.gemini\config\GEMINI.md"
    Deploy 'config\agy\hooks' "$UserHome\.gemini\hooks"
    Merge-Config 'config\herdr\config.windows.toml' "$env:APPDATA\herdr\config.toml"
    Deploy 'config\tmux\tmux.windows.conf' "$UserHome\.tmux.conf"
    Deploy 'config\nvim' "$env:LOCALAPPDATA\nvim"
    Deploy 'config\starship.toml' "$UserHome\.config\starship.toml"
}

Invoke-Step 'Node.js LTS (fnm)' {
    fnm env --shell powershell | Out-String | Invoke-Expression
    foreach ($fnmArgs in @('install', '--lts'), @('default', 'lts-latest'), @('use', 'lts-latest')) {
        fnm @fnmArgs
        if ($LASTEXITCODE) { Fail "fnm $fnmArgs" }
    }
    # 셸 밖에서 뜬 프로세스(Claude Code hook 등)도 node를 찾도록 fnm 기본 버전을 User PATH에 둔다
    Add-UserPath (Join-Path $env:FNM_DIR 'aliases\default')
}

Invoke-Step 'npm global packages' {
    npm install -g @(Get-Manifest 'npm-global.txt')
    if ($LASTEXITCODE) { Fail 'npm install -g' }
}

Invoke-Step 'Claude Code, Antigravity CLI, herdr' {
    Install-IfMissing claude 'https://claude.ai/install.ps1'
    Install-IfMissing agy 'https://antigravity.google/cli/install.ps1'
    Install-IfMissing herdr 'https://herdr.dev/install.ps1'
}

Invoke-Step 'shell profiles' {
    Set-ProfileBlock $PROFILE.CurrentUserCurrentHost (Get-Content -Raw (Join-Path $Root 'config\powershell\profile.ps1'))
    Set-ProfileBlock "$UserHome\.bashrc" (Get-Content -Raw (Join-Path $Root 'config\bash\bashrc'))
    Set-ProfileBlock "$UserHome\.inputrc" (Get-Content -Raw (Join-Path $Root 'config\bash\inputrc'))
    Set-ProfileBlock "$UserHome\.bash_profile" '[[ -f ~/.bashrc ]] && . ~/.bashrc'
}

Invoke-Step 'skills' {
    foreach ($skill in Get-Manifest 'skills.txt') {
        $repo, $name = $skill -split '@', 2
        npx -y skills add $repo --skill $name --global --yes --agent claude-code *> $null
        if ($LASTEXITCODE) { Fail "skill $skill" } else { Write-Host "    $skill" }
    }
}

Invoke-Step 'Claude Code plugins' {
    # add·install은 이미 있으면 아무것도 하지 않으므로, 카탈로그를 새로 받고 update로 최신을 맞춘다
    foreach ($line in Get-Manifest 'plugins.txt') {
        $marketplace, $plugin = -split $line
        claude plugin marketplace add $marketplace *> $null
        if (-not $LASTEXITCODE) { claude plugin marketplace update ($plugin -split '@')[1] *> $null }
        if (-not $LASTEXITCODE) { claude plugin install $plugin *> $null }
        if (-not $LASTEXITCODE) { claude plugin update $plugin *> $null }
        if ($LASTEXITCODE) { Fail "plugin $plugin" } else { Write-Host "    $plugin" }
    }
}

if ($Failed.Count) {
    Write-Host "`n==> $($Failed.Count) step(s) failed"
    $Failed | ForEach-Object { Write-Host "    [!] $_" }
    exit 1
}
Write-Host "`n==> Done. Restart the terminal and Claude Code."
