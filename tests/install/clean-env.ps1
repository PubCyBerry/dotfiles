$ErrorActionPreference = 'Stop'

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$work = Join-Path $PSScriptRoot ".clean-env-test-$PID"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force $work | Out-Null
    $homeDir = Join-Path $work 'home'
    $localApp = Join-Path $homeDir 'AppData\Local'
    $wingetPkgs = Join-Path $localApp 'Microsoft\WinGet\Packages'
    $validDir1 = Join-Path $wingetPkgs 'pkg1\bin'
    $validDir2 = Join-Path $wingetPkgs 'pkg2\bin'
    $validUserDir = Join-Path $homeDir '.local\bin'
    $deadDir = Join-Path $homeDir 'does_not_exist'

    New-Item -ItemType Directory -Force $validDir1, $validDir2, $validUserDir | Out-Null

    $env:USERPROFILE = $homeDir
    $env:LOCALAPPDATA = $localApp
    # 옛 스크립트가 만들던 보조 변수. Get-ScopedEnvMap이 첫 호출에서 캐시하므로
    # 스크립트를 dot-source 하기 전에 심어 둔다.
    $env:WINGET_PKGS = $wingetPkgs

    # Load Clean-PathString & Compress-PathEntry functions
    . (Join-Path $repo 'scripts\clean-env.ps1')

    # Test 1: Dead path removal and deduplication
    $rawPath = "$validDir1;$deadDir;$validDir1;$validDir2;$validUserDir"
    $result = Clean-PathString -rawPath $rawPath -scopeName "User"

    Assert-True ($result.Modified -eq $true) "Path should be modified"
    Assert-True ($result.Removed.Count -eq 2) "Should remove 2 entries (1 dead, 1 duplicate)"
    Assert-True ($result.WinGetCount -eq 2) "Should count 2 winget packages"
    Assert-True ($result.Cleaned.Contains('%LOCALAPPDATA%\Microsoft\WinGet\Packages\pkg1\bin')) "Should compress to %LOCALAPPDATA%"
    Assert-True ($result.Cleaned.Contains('%LOCALAPPDATA%\Microsoft\WinGet\Packages\pkg2\bin')) "Should compress to %LOCALAPPDATA%"
    Assert-True ($result.Cleaned.Contains('%USERPROFILE%\.local\bin')) "Should compress to %USERPROFILE%"
    Assert-True (-not $result.Cleaned.Contains('does_not_exist')) "Dead path must not be in cleaned result"

    # 사용자 정의 변수로는 절대 압축하지 않는다. 로그온은 그 변수도 풀지만, 레지스트리를
    # 직접 읽거나 프로세스 환경만 보는 소비자는 못 푼다. 실제로 그 상태에서 이 스크립트
    # 자신이 항목 14개를 "경로 미존재"로 지운 적이 있다.
    Assert-True (-not $result.Cleaned.Contains('%WINGET_PKGS%')) "Must not compress with a user-defined variable"

    # Test 2: NoCompress mode. 압축을 끄는 것은 -NoCompress 스위치 하나뿐이므로
    # (Compress-PathEntry가 스크립트 스코프에서 직접 읽는다) 그 값을 세워서 본다.
    $NoCompress = $true
    try {
        $resultNoComp = Clean-PathString -rawPath $rawPath -scopeName "User"
        Assert-True ($resultNoComp.Cleaned.Contains($validDir1)) "NoCompress must keep the full literal path"
        Assert-True (-not $resultNoComp.Cleaned.Contains('%LOCALAPPDATA%')) "NoCompress must not substitute a variable"
    } finally { $NoCompress = $false }

    # Test 3: Relative .\ normalization
    $dotPath = "$localApp\.\Microsoft\WinGet\Packages\pkg1\bin"
    $resultDot = Clean-PathString -rawPath $dotPath -scopeName "User"
    Assert-True ($resultDot.Cleaned -eq '%LOCALAPPDATA%\Microsoft\WinGet\Packages\pkg1\bin') "Should normalize .\ in path"

    # Test 4: 확장되지 않는 %VAR%가 남은 항목은 판정하지 않고 보존한다.
    # 어느 스코프에도 없는 변수라 존재 여부를 알 수 없다. 모르는 것은 지우지 않는다.
    $unknown = '%DOTFILES_NO_SUCH_VAR%\bin'
    $resultUnknown = Clean-PathString -rawPath "$unknown;$validUserDir" -scopeName "User"
    Assert-True ($resultUnknown.Cleaned.Contains($unknown)) "Unresolvable %VAR% entry must be preserved"
    Assert-True (@($resultUnknown.Removed | Where-Object { $_ -like "*DOTFILES_NO_SUCH_VAR*" }).Count -eq 0) "Unresolvable %VAR% entry must not be reported as removed"

    # Test 5: 확장은 레지스트리 스코프를 본다. 프로세스 환경만 보면 그 프로세스가
    # 모르는 변수를 못 풀어 멀쩡한 항목이 통째로 사라진다.
    Assert-True ((Expand-ScopedEnvVariables '%LOCALAPPDATA%\x') -eq (Join-Path $localApp 'x')) "Scoped expansion must resolve system variables"
    Assert-True ((Expand-ScopedEnvVariables $unknown) -eq $unknown) "Unknown variable must be left as-is"

    # Test 6: 이미 %WINGET_PKGS%로 압축된 항목은 허용된 변수로 되돌아와야 한다.
    # 새로 만들지 않는 것만으로는 이미 그 상태인 머신이 고쳐지지 않는다 — 그 항목은
    # 로그온 환경 블록에서 확장되지 않아 죽은 채로 남는다.
    $legacy = '%WINGET_PKGS%\pkg1\bin'
    $resultLegacy = Clean-PathString -rawPath "$legacy;$validUserDir" -scopeName "User"
    Assert-True (-not $resultLegacy.Cleaned.Contains('%WINGET_PKGS%')) "Legacy user-defined variable must be rewritten"
    Assert-True ($resultLegacy.Cleaned.Contains('%LOCALAPPDATA%\Microsoft\WinGet\Packages\pkg1\bin')) "Legacy entry must be recompressed with an expandable variable"
    Assert-True (@($resultLegacy.Removed).Count -eq 0) "Legacy entry must be rewritten, not removed"

    Write-Host "clean-env unit tests: PASS" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
