#requires -Version 7.0
<#
.SYNOPSIS
    이 머신의 상태가 저장소가 배포하기로 한 것과 일치하는지 확인한다.

.DESCRIPTION
    install.ps1이 "성공"으로 끝나도 실제로 배포되지 않은 것이 있을 수 있다. 소유권
    게이트가 조용히 보존을 택하거나, PATH 항목이 죽어 도구가 사라지는 경우가 그렇다.
    이 스크립트는 결과물만 본다 — install의 로그가 아니라 파일·레지스트리·PATH를
    직접 읽어서 대조한다.

    병합(merge)으로 배포하는 설정은 destination 우선이라 사용자 값이 이겨야 정상이다.
    그래서 "값이 같은가"가 아니라 "관리 키가 존재하는가"를 본다. 저장소 기본값과
    달라진 키는 실패가 아니라 INFO로 보고한다.

    네트워크를 타지 않는다. winget/npm 조회는 로컬 상태만 읽는다.

.PARAMETER Quiet
    통과한 항목을 출력하지 않고 실패와 INFO만 낸다.
#>
[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script:Failures = [Collections.Generic.List[string]]::new()
$script:Infos = [Collections.Generic.List[string]]::new()
$script:Passed = 0

function Write-Section([string]$Title) { Write-Host "`n== $Title ==" }

function Test-Item([string]$Name, [scriptblock]$Body) {
    try {
        $reason = & $Body
        if ($reason -is [string] -and $reason) {
            $script:Failures.Add("$Name -> $reason")
            Write-Host ("  FAIL {0}: {1}" -f $Name, $reason)
        } else {
            $script:Passed++
            if (-not $Quiet) { Write-Host ("  ok   {0}" -f $Name) }
        }
    } catch {
        $script:Failures.Add("$Name -> $_")
        Write-Host ("  FAIL {0}: {1}" -f $Name, $_)
    }
}

function Add-Info([string]$Message) {
    $script:Infos.Add($Message)
    Write-Host ("  info {0}" -f $Message)
}

function Get-ManifestLine([string]$Path) {
    Get-Content $Path | ForEach-Object { ($_ -split '#')[0].Trim() } | Where-Object { $_ }
}

# 새 셸이 실제로 받게 될 PATH를 본다. 현재 프로세스의 PATH는 언제 떴는지에 따라
# 낡아 있어 판정 근거가 되지 못한다. CreateEnvironmentBlock은 Windows가 로그온
# 환경을 만들 때 쓰는 바로 그 API다.
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices; using System.Collections.Generic;
public static class DotfilesVerifyEnv {
  [DllImport("userenv.dll")] public static extern bool CreateEnvironmentBlock(out IntPtr e, IntPtr t, bool i);
  [DllImport("userenv.dll")] public static extern bool DestroyEnvironmentBlock(IntPtr e);
  [DllImport("advapi32.dll")] public static extern bool OpenProcessToken(IntPtr h, uint a, out IntPtr t);
  [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  // 실패를 빈 문자열로 뭉개면 도구가 전부 missing으로 떠서 원인이 구분되지 않는다.
  // 호출자가 "PATH를 못 읽었다"와 "PATH에 없다"를 나눠 보고하도록 null을 준다.
  //
  // PATH만 뽑지 않고 블록 전체를 준다. 이 API는 사용자 PATH의 %VAR%를 확장하지 않은
  // 채로 넘기므로(%LOCALAPPDATA% 같은 시스템 변수도 마찬가지다) 무엇으로 풀어야 하는지
  // 알려면 같은 블록의 변수들이 필요하다.
  public static string[] GetBlock() {
    IntPtr tok;
    if (!OpenProcessToken(GetCurrentProcess(), 0x0008, out tok)) return null;
    try {
      IntPtr blk; if (!CreateEnvironmentBlock(out blk, tok, false)) return null;
      var list = new List<string>(); IntPtr p = blk;
      while (true) { string s = Marshal.PtrToStringUni(p); if (string.IsNullOrEmpty(s)) break;
        list.Add(s); p = (IntPtr)((long)p + (s.Length + 1) * 2); }
      DestroyEnvironmentBlock(blk); return list.ToArray();
    } finally { CloseHandle(tok); } }
}
'@

# 이 API는 사용자 PATH를 미확장 상태로 넘긴다. 실측: %WINGET_PKGS%뿐 아니라
# %LOCALAPPDATA%\... 항목까지 전부 문자열 그대로 돌아온다(관리자/비관리자 동일,
# 토큰 권한을 올려도 동일). 반면 실제 로그온 셸의 PATH에는 그 항목들이 전부 실경로로
# 들어 있다 — 중첩 참조(%WINGET_PKGS% -> %LOCALAPPDATA%\... -> 실경로)까지 풀린다.
#
# 그래서 "문자열에 %가 남아 있다"를 죽은 항목의 근거로 삼으면 멀쩡한 PATH가 통째로
# 실패로 뜬다. 판정은 블록이 실어 온 변수들로 직접 확장해 본 뒤에 한다. 그 변수 집합이
# 새 로그온이 실제로 갖게 될 것이므로, 거기에도 없는 변수를 쓰는 항목만 죽은 항목이다.
$freshBlock = [DotfilesVerifyEnv]::GetBlock()
$freshVars = @{}
$freshRawPath = $null
if ($null -ne $freshBlock) {
    foreach ($line in $freshBlock) {
        $eq = $line.IndexOf('=')
        if ($eq -lt 1) { continue }
        $name = $line.Substring(0, $eq)
        $value = $line.Substring($eq + 1)
        if ($name -ieq 'Path') { $freshRawPath = $value } else { $freshVars[$name] = $value }
    }
}

function Expand-FreshValue([string]$Value) {
    $result = $Value
    # 값이 다시 변수를 참조할 수 있어 고정점까지 반복한다. 순환 참조는 횟수로 끊는다.
    for ($i = 0; $i -lt 8; $i++) {
        $next = [regex]::Replace($result, '%([^%]+)%', {
            param($m)
            $name = $m.Groups[1].Value
            if ($freshVars.ContainsKey($name)) { return $freshVars[$name] }
            return $m.Value
        })
        if ($next -ceq $result) { break }
        $result = $next
    }
    return $result
}

$freshSegments = if ($null -eq $freshRawPath) { @() } else {
    @($freshRawPath -split ';' | Where-Object { $_ } | ForEach-Object { Expand-FreshValue $_ })
}

function Test-OnFreshPath([string]$Exe) {
    foreach ($seg in $freshSegments) {
        if (Test-Path -LiteralPath (Join-Path $seg $Exe)) { return $true }
    }
    return $false
}

Write-Section 'PATH'
Test-Item '새 로그온 PATH를 읽을 수 있음' {
    if ($null -eq $freshRawPath) { 'CreateEnvironmentBlock 실패 — 아래 PATH 검사는 근거가 없다' }
}
Test-Item '새 셸 PATH에 해석되지 않는 %VAR% 없음' {
    # 새 로그온이 갖게 될 변수 집합으로도 풀리지 않는 항목만 죽은 항목이다.
    $bad = @($freshSegments | Where-Object { $_ -match '%[^%]+%' })
    if ($bad) { "unresolvable: $($bad -join ', ')" }
}
Test-Item 'User PATH 항목이 모두 실재' {
    $raw = (Get-ItemProperty 'HKCU:\Environment' -Name Path -ErrorAction SilentlyContinue).Path
    $dead = @($raw -split ';' | Where-Object { $_ } |
        Where-Object { -not (Test-Path -LiteralPath (Expand-FreshValue $_)) })
    if ($dead) { "dead: $($dead -join ', ')" }
}
Test-Item '배포 CLI 도구가 새 셸 PATH에서 해석됨' {
    $tools = @(
        'jq.exe','yq.exe','fnm.exe','fd.exe','bat.exe','rg.exe','eza.exe','delta.exe','uv.exe',
        'bun.exe','zoxide.exe','lazygit.exe','yazi.exe','ffmpeg.exe','fzf.exe','psmux.exe',
        'pdftotext.exe','git.exe','nvim.exe','starship.exe','gh.exe','shellcheck.exe'
    )
    $missing = @($tools | Where-Object { -not (Test-OnFreshPath $_) })
    if ($missing) { "missing: $($missing -join ', ')" }
}

Write-Section '패키지'
Test-Item 'manifests/winget.txt 전부 설치' {
    $exported = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-verify-winget-$PID.json"
    try {
        winget export -o $exported --disable-interactivity --accept-source-agreements 2>$null | Out-Null
        if (-not (Test-Path $exported)) { return 'winget export failed' }
        $installed = @{}
        foreach ($src in (Get-Content $exported -Raw | ConvertFrom-Json).Sources) {
            foreach ($pkg in $src.Packages) { $installed[$pkg.PackageIdentifier] = $true }
        }
        $missing = @(Get-ManifestLine (Join-Path $root 'manifests\winget.txt') | Where-Object { -not $installed.ContainsKey($_) })
        if ($missing) { "missing: $($missing -join ', ')" }
    } finally { Remove-Item $exported -Force -ErrorAction SilentlyContinue }
}
Test-Item 'manifests/npm-global.txt 전부 설치' {
    $npmRoot = npm root -g 2>$null
    if (-not $npmRoot) { return 'npm root -g failed' }
    $missing = @(Get-ManifestLine (Join-Path $root 'manifests\npm-global.txt') |
        Where-Object { -not (Test-Path (Join-Path $npmRoot "$_\package.json")) })
    if ($missing) { "missing: $($missing -join ', ')" }
}

Write-Section 'takeover 배포 파일 (소스와 바이트 동일해야 함)'
$copies = @(
    @{ Src = 'config\agents\global.md';                  Dst = "$HOME\.claude\CLAUDE.md" }
    @{ Src = 'config\agents\global.md';                  Dst = "$HOME\.codex\AGENTS.md" }
    @{ Src = 'config\agents\global.md';                  Dst = "$HOME\.gemini\GEMINI.md" }
    @{ Src = 'config\agents\global.md';                  Dst = "$HOME\.gemini\config\GEMINI.md" }
    @{ Src = 'config\claude\statusline.sh';              Dst = "$HOME\.claude\statusline.sh" }
    @{ Src = 'config\claude\claude-hud.json';            Dst = "$HOME\.claude\claude-hud.json" }
    @{ Src = 'config\claude\hooks\temporal-context.sh';  Dst = "$HOME\.claude\hooks\temporal-context.sh" }
    @{ Src = 'config\codex\hooks\temporal-context.sh';   Dst = "$HOME\.codex\hooks\temporal-context.sh" }
    @{ Src = 'config\tmux\tmux.windows.conf';            Dst = "$HOME\.tmux.conf" }
)
foreach ($copy in $copies) {
    $src = Join-Path $root $copy.Src
    $dst = $copy.Dst
    Test-Item ("{0} <- {1}" -f (Split-Path $dst -Leaf), $copy.Src) {
        if (-not (Test-Path -LiteralPath $dst)) { return "missing: $dst" }
        if ((Get-FileHash $src -Algorithm SHA256).Hash -ne (Get-FileHash $dst -Algorithm SHA256).Hash) { 'content differs' }
    }
}

Write-Section 'agent role'
$roles = @(Get-ChildItem (Join-Path $root 'config\agents\roles') -Directory | Select-Object -ExpandProperty Name)
Test-Item 'Claude agents 배포됨' {
    $missing = @($roles | Where-Object { -not (Test-Path "$HOME\.claude\agents\$_.md") })
    if ($missing) { "missing: $($missing -join ', ')" }
}
Test-Item 'Codex agents 배포됨' {
    $missing = @($roles | Where-Object { -not (Test-Path "$HOME\.codex\agents\$_.toml") })
    if ($missing) { "missing: $($missing -join ', ')" }
}

Write-Section '병합 설정 (관리 키가 들어가 있는가)'
# 최상위에서 그대로 읽으면 파일이 없는 머신에서 $ErrorActionPreference = 'Stop'에 걸려
# 검증 스크립트 전체가 죽는다. 없다는 사실이야말로 보고할 결과이므로 FAIL 한 줄로 낸다.
function Read-JsonOrNull([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { return $null }
}
$claudeSettings = Read-JsonOrNull "$HOME\.claude\settings.json"
$claudeManaged = Read-JsonOrNull (Join-Path $root 'config\claude\settings.json')

Test-Item 'settings.json 읽기' {
    if ($null -eq $claudeSettings) { "읽을 수 없음: $HOME\.claude\settings.json — 아래 병합 검사는 근거가 없다" }
    elseif ($null -eq $claudeManaged) { '읽을 수 없음: config\claude\settings.json' }
}

Test-Item 'settings.json: statusLine이 저장소 wrapper' {
    # statusLine은 registry 병합의 예외로 저장소가 값을 소유한다(purge_legacy_statusline).
    if ($claudeSettings.statusLine.command -ne $claudeManaged.statusLine.command) {
        "got '$($claudeSettings.statusLine.command)'"
    }
}
Test-Item 'settings.json: temporal hook이 UserPromptSubmit에만 등록' {
    $events = @()
    foreach ($prop in $claudeSettings.hooks.PSObject.Properties) {
        foreach ($group in $prop.Value) {
            if (@($group.hooks | Where-Object { $_.command -like '*temporal-context*' })) { $events += $prop.Name }
        }
    }
    $events = @($events | Sort-Object -Unique)
    if ($events.Count -ne 1 -or $events[0] -ne 'UserPromptSubmit') { "events: $($events -join ',')" }
}
Test-Item 'settings.json: 관리 스칼라 키가 모두 존재' {
    $missing = @()
    foreach ($prop in $claudeManaged.PSObject.Properties) {
        if ($prop.Name -in 'hooks','statusLine') { continue }
        if ($null -eq $claudeSettings.($prop.Name)) { $missing += $prop.Name; continue }
        if ($prop.Value -isnot [psobject] -and "$($claudeSettings.($prop.Name))" -ne "$($prop.Value)") {
            Add-Info ("settings.json .{0} = '{1}' (저장소 기본값 '{2}') — 병합은 destination 우선이라 정상" -f $prop.Name, $claudeSettings.($prop.Name), $prop.Value)
        }
    }
    if ($missing) { "missing keys: $($missing -join ', ')" }
}
Test-Item 'codex hooks.json: temporal hook 등록' {
    $raw = Get-Content "$HOME\.codex\hooks.json" -Raw
    if ($raw -notmatch 'temporal-context') { 'not registered' }
}
Test-Item 'gemini hooks.json: temporal hook 등록' {
    $raw = Get-Content "$HOME\.gemini\config\hooks.json" -Raw
    if ($raw -notmatch 'temporal-context') { 'not registered' }
}
Test-Item 'codex config.toml: 관리 최상위 키가 모두 존재' {
    $managedKeys = @((& yq -p=toml -o=json 'keys | .[]' (Join-Path $root 'config\codex\config.toml')) -replace '"','')
    $deployedKeys = @((& yq -p=toml -o=json 'keys | .[]' "$HOME\.codex\config.toml") -replace '"','')
    $missing = @($managedKeys | Where-Object { $_ -and $_ -notin $deployedKeys })
    if ($missing) { "missing keys: $($missing -join ', ')" }
    $got = ((& yq -p=toml -o=json '.model_reasoning_effort' "$HOME\.codex\config.toml") | Out-String).Trim().Trim('"')
    $want = ((& yq -p=toml -o=json '.model_reasoning_effort' (Join-Path $root 'config\codex\config.toml')) | Out-String).Trim().Trim('"')
    if ($got -ne $want) {
        Add-Info "codex config.toml .model_reasoning_effort = '$got' (저장소 기본값 '$want') — 병합은 destination 우선이라 정상"
    }
}
Test-Item 'herdr config.toml: default_shell이 실재하는 경로' {
    $shell = ((& yq -p=toml -o=json '.terminal.default_shell' "$env:APPDATA\herdr\config.toml") | Out-String).Trim().Trim('"')
    if (-not $shell -or -not (Test-Path -LiteralPath $shell)) { "default_shell='$shell'" }
}

Write-Section 'MCP 등록'
Test-Item 'codex MCP rhwp' {
    $cmd = ((& yq -p=toml -o=json '.mcp_servers.rhwp.command' "$HOME\.codex\config.toml") | Out-String).Trim().Trim('"')
    if (-not $cmd -or -not (Test-Path -LiteralPath $cmd)) { "command='$cmd'" }
}
Test-Item 'claude MCP rhwp' {
    $cmd = ((& jq -r '.mcpServers.rhwp.command // empty' "$HOME\.claude.json") | Out-String).Trim()
    if (-not $cmd -or -not (Test-Path -LiteralPath $cmd)) { "command='$cmd'" }
}
Test-Item 'gemini MCP rhwp' {
    $cmd = ((& jq -r '.mcpServers.rhwp.command // empty' "$HOME\.gemini\config\mcp_config.json") | Out-String).Trim()
    if (-not $cmd -or -not (Test-Path -LiteralPath $cmd)) { "command='$cmd'" }
}

Write-Section 'pinned artifact 버전'
Test-Item 'rhwp 버전이 manifest와 일치' {
    $row = @(Get-ManifestLine (Join-Path $root 'manifests\rhwp.tsv') | Where-Object { $_ -clike 'windows-x86_64*' })[0] -split "`t"
    $got = ((& "$HOME\rhwp\rhwp.exe" --version) | Out-String).Trim()
    if ($got -ne "rhwp v$($row[1])") { "got '$got' want 'rhwp v$($row[1])'" }
}
Test-Item 'shellcheck 버전이 manifest와 일치' {
    $row = @(Get-ManifestLine (Join-Path $root 'manifests\shellcheck.tsv') | Where-Object { $_ -clike 'windows-x86_64*' })[0] -split "`t"
    $line = (& "$HOME\.local\bin\shellcheck.exe" --version) | Where-Object { $_ -like 'version:*' }
    $got = ($line -split ':')[1].Trim()
    if ($got -ne $row[1]) { "got '$got' want '$($row[1])'" }
}

Write-Section 'skills / plugins'
Test-Item 'manifests/skills.txt 전부 설치' {
    $missing = @()
    foreach ($line in Get-ManifestLine (Join-Path $root 'manifests\skills.txt')) {
        $name = ($line -split '@')[-1]
        if (-not (Test-Path "$HOME\.claude\skills\$name")) { $missing += $name }
    }
    if ($missing) { "missing: $($missing -join ', ')" }
}
Test-Item 'manifests/plugins.txt 전부 활성' {
    $missing = @()
    foreach ($line in Get-ManifestLine (Join-Path $root 'manifests\plugins.txt')) {
        $id = ($line -split '\s+')[1]
        if ($claudeSettings.enabledPlugins.$id -ne $true) { $missing += $id }
    }
    if ($missing) { "missing: $($missing -join ', ')" }
}

Write-Section '셸 프로파일 마커 블록'
$profiles = @(
    "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
    "$HOME\.bashrc", "$HOME\.inputrc", "$HOME\.bash_profile"
)
foreach ($path in $profiles) {
    Test-Item ("마커 1쌍: {0}" -f (Split-Path $path -Leaf)) {
        if (-not (Test-Path $path)) { return 'missing' }
        $text = Get-Content $path -Raw
        $begin = ([regex]::Matches($text, 'dotfiles-begin')).Count
        $end = ([regex]::Matches($text, 'dotfiles-end')).Count
        if ($begin -ne 1 -or $end -ne 1) { "begin=$begin end=$end" }
    }
}

Write-Section 'install receipt'
Test-Item 'receipt에 pending 상태가 남아 있지 않음' {
    $receiptPath = Join-Path $env:LOCALAPPDATA 'dotfiles\install-receipt.json'
    if (-not (Test-Path $receiptPath)) { return "missing: $receiptPath" }
    $receipt = Get-Content $receiptPath -Raw | ConvertFrom-Json
    $pending = @()
    foreach ($prop in $receipt.artifacts.PSObject.Properties) { if ($prop.Value.pending) { $pending += $prop.Name } }
    foreach ($prop in $receipt.packages.PSObject.Properties) { if ($prop.Value.pending) { $pending += $prop.Name } }
    foreach ($prop in $receipt.values.PSObject.Properties) { if ($prop.Value.pending) { $pending += $prop.Name } }
    if ($pending) { "pending: $($pending -join ', ')" }
    # 사라진 managed 파일은 실패가 아니다. install이 만들었고 그 뒤 소유자가 바뀐
    # 경로(구 로컬 skill 배포분의 __pycache__ 등)가 여기 남는다. uninstall이
    # before.exists=false + 파일 없음으로 보고 entry만 지운다.
    foreach ($prop in $receipt.artifacts.PSObject.Properties) {
        if (-not (Test-Path -LiteralPath $prop.Name)) { Add-Info "receipt artifact 없음(정리 대상): $($prop.Name)" }
    }
}

Write-Host ("`n==== {0} passed, {1} failed, {2} info ====" -f $script:Passed, $script:Failures.Count, $script:Infos.Count)
if ($script:Failures.Count) {
    Write-Host "`n실패:"
    $script:Failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}
exit 0
