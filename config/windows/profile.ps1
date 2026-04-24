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

# RTK PATH (install.ps1이 $USERPROFILE\rtk에 설치)
$rtkPath = "$env:USERPROFILE\rtk"
if ((Test-Path $rtkPath) -and ($env:PATH -notlike "*$rtkPath*")) {
    $env:PATH = "$rtkPath;$env:PATH"
}
