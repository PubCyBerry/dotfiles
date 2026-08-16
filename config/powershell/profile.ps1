# windows/profile.ps1 — PowerShell $PROFILE에 추가할 dotfiles 설정
# 직접 실행하지 않음. agents-setup.ps1이 $PROFILE에 마커 블록으로 삽입.

# WinGet 심볼릭 링크를 실제 경로로 해석 (SSH 세션에서 링크 탐색 불가 우회)
function private:Resolve-ExePath($Name) {
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $cmd) { return $null }
    $item = Get-Item $cmd.Source -ErrorAction SilentlyContinue
    if ($item -and $item.Target) { return $item.Target }
    return $cmd.Source
}

# fnm (Node.js 버전 관리)
$fnmExe = Resolve-ExePath 'fnm'
if ($fnmExe) {
    & $fnmExe env --use-on-cd --shell powershell | Out-String | Invoke-Expression

    # SSH(원격 로그온)에서는 fnm이 node를 노출하는 junction/reparse 경로 탐색이
    # 막혀 bash hook 등 자식 프로세스에서 `node`를 못 찾는다. 실제 설치 디렉터리
    # (reparse 아님)를 PATH 뒤에 fallback으로 추가한다. fnm multishell 경로가 앞에
    # 남으므로 `fnm use`/`--use-on-cd`가 선택한 버전을 덮어쓰지 않는다.
    $fnmRoot = if ($env:FNM_DIR) { $env:FNM_DIR } else { "$env:APPDATA\fnm" }
    $nodeVerDir = Get-ChildItem "$fnmRoot\node-versions" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\installation\node.exe" } |
        Sort-Object { [version]$_.Name.TrimStart('v') } -Descending | Select-Object -First 1
    if ($nodeVerDir) {
        $nodeDir = "$($nodeVerDir.FullName)\installation"
        if (($env:PATH -split ';') -notcontains $nodeDir) { $env:PATH = "$env:PATH;$nodeDir" }
    }
}

# tmux/psmux (Windows): WinGet Links 심링크는 SSH(원격 로그온)에서 "untrusted
# mount point"로 실행이 막힌다(R2L 정책으로도 안 풀림). 실제 패키지 디렉터리를
# PATH에 추가해 pwsh/bash 모두에서 tmux가 실경로로 해석되게 한다.
$tmuxExe = Resolve-ExePath 'tmux'
if ($tmuxExe) {
    $tmuxDir = Split-Path $tmuxExe
    if ($env:PATH -notlike "*$tmuxDir*") { $env:PATH = "$tmuxDir;$env:PATH" }
}

# zoxide (스마트 cd — z 명령어)
$zoxideExe = Resolve-ExePath 'zoxide'
if ($zoxideExe) {
    Invoke-Expression (& { (& $zoxideExe init powershell | Out-String) })
}

# starship 프롬프트
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}

# fzf (PSFzf 모듈 필요: Install-Module PSFzf -Scope CurrentUser)
if (Get-Module -ListAvailable -Name PSFzf -ErrorAction SilentlyContinue) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# eza / bat 별칭
#
# PowerShell의 명령 해석 순서는 Alias > Function > Cmdlet이다. Windows PowerShell이
# 기본 제공하는 `ls`(Get-ChildItem), `cat`(Get-Content) 별칭이 같은 이름의 함수를
# 가려서, function global:ls를 정의해도 `ls`는 계속 Get-ChildItem으로 해석됐다.
# (Get-Command ls).Definition으로 확인할 수 있다. 내장 별칭을 먼저 걷어내야 한다.
# `ll`/`lt`는 대응하는 내장 별칭이 없어 영향을 받지 않는다.
#
# 이 프로파일은 마커 블록으로 여러 번 로드될 수 있으므로 이미 지워진 경우를 무시한다.
function private:Remove-ShadowingAlias([string]$Name) {
    if (Get-Alias $Name -ErrorAction SilentlyContinue) {
        Remove-Alias $Name -Force -Scope Global -ErrorAction SilentlyContinue
    }
}

if (Get-Command eza -ErrorAction SilentlyContinue) {
    Remove-ShadowingAlias 'ls'
    function global:ls  { eza @args }
    function global:ll  { eza -la @args }
    function global:lt  { eza --tree @args }
}

if (Get-Command bat -ErrorAction SilentlyContinue) {
    Remove-ShadowingAlias 'cat'
    function global:cat { bat @args }
}

# Claude Code 단축 별칭
if (Get-Command claude -ErrorAction SilentlyContinue) {
    function global:ccd { claude --dangerously-skip-permissions @args }
}

# bash → Git Bash 고정 (PATH 순서 상관없이. tmux pane은 WSL bash.exe가 먼저 잡혀서 명시 고정 필요)
$gitBash = "$env:ProgramFiles\Git\bin\bash.exe"
if (Test-Path $gitBash) {
    function global:bash { & $gitBash @args }
}

# ~/.local/bin (claude native 바이너리 등)
$localBin = "$env:USERPROFILE\.local\bin"
if ((Test-Path $localBin) -and ($env:PATH -notlike "*$localBin*")) {
    $env:PATH = "$localBin;$env:PATH"
}
