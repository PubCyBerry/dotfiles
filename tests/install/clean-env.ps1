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

    # Load Clean-PathString & Compress-PathEntry functions
    . (Join-Path $repo 'scripts\clean-env.ps1')

    # Test 1: Dead path removal and deduplication
    $rawPath = "$validDir1;$deadDir;$validDir1;$validDir2;$validUserDir"
    $result = Clean-PathString -rawPath $rawPath -scopeName "User" -useWingetPkgs $true

    Assert-True ($result.Modified -eq $true) "Path should be modified"
    Assert-True ($result.Removed.Count -eq 2) "Should remove 2 entries (1 dead, 1 duplicate)"
    Assert-True ($result.WinGetCount -eq 2) "Should count 2 winget packages"
    Assert-True ($result.Cleaned.Contains('%WINGET_PKGS%\pkg1\bin')) "Should compress to %WINGET_PKGS%"
    Assert-True ($result.Cleaned.Contains('%WINGET_PKGS%\pkg2\bin')) "Should compress to %WINGET_PKGS%"
    Assert-True ($result.Cleaned.Contains('%USERPROFILE%\.local\bin')) "Should compress to %USERPROFILE%"
    Assert-True (-not $result.Cleaned.Contains('does_not_exist')) "Dead path must not be in cleaned result"

    # Test 2: NoCompress mode
    $resultNoComp = Clean-PathString -rawPath $rawPath -scopeName "User" -useWingetPkgs $false
    Assert-True ($resultNoComp.Cleaned.Contains($validDir1) -or $resultNoComp.Cleaned.Contains('%LOCALAPPDATA%')) "Without winget compress, preserves base path"

    # Test 3: Relative .\ normalization
    $dotPath = "$localApp\.\Microsoft\WinGet\Packages\pkg1\bin"
    $resultDot = Clean-PathString -rawPath $dotPath -scopeName "User" -useWingetPkgs $true
    Assert-True ($resultDot.Cleaned -eq '%WINGET_PKGS%\pkg1\bin') "Should normalize .\ in path"

    Write-Host "clean-env unit tests: PASS" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
