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
    # (reparse 아님)를 PATH에 직접 prepend 해서 어디서든 node를 찾도록 한다.
    $fnmRoot = if ($env:FNM_DIR) { $env:FNM_DIR } else { "$env:APPDATA\fnm" }
    $nodeVerDir = Get-ChildItem "$fnmRoot\node-versions" -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path "$($_.FullName)\installation\node.exe" } |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($nodeVerDir) {
        $nodeDir = "$($nodeVerDir.FullName)\installation"
        if ($env:PATH -notlike "*$nodeDir*") { $env:PATH = "$nodeDir;$env:PATH" }
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

# eza 별칭
if (Get-Command eza -ErrorAction SilentlyContinue) {
    function global:ls  { eza @args }
    function global:ll  { eza -la @args }
    function global:lt  { eza --tree @args }
}

# bat 별칭
if (Get-Command bat -ErrorAction SilentlyContinue) {
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
