$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-direct-$([guid]::NewGuid())"
$env:DOTFILES_FUNCTIONS_ONLY = '1'
$env:DOTFILES_RECEIPT_PATH = Join-Path $temp 'state\receipt.json'
$oldLocal = $env:LOCALAPPDATA; $oldProfile = $env:USERPROFILE
$env:LOCALAPPDATA = Join-Path $temp 'local'; $env:USERPROFILE = Join-Path $temp 'home'
try {
    New-Item -ItemType Directory -Force $temp | Out-Null
    . (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'install.ps1')
    if (-not (Initialize-InstallReceipt)) { throw 'receipt init failed' }

    Begin-ManagedPackage 'winget:test-transient' $false '' | Out-Null
    New-Item -ItemType File -Force (Join-Path $temp 'actual-mutation') | Out-Null
    $status = Complete-ManagedWingetPackage 'winget:test-transient' $false '' 55 1 '' $true
    if ($status -ne 55 -or -not $script:Receipt.packages['winget:test-transient'].pending) { throw 'transient query discarded pending mutation' }

    Begin-ManagedPackage 'winget:test-absent' $false '' | Out-Null
    $absent = -1978335212 # 0x8A150014
    $status = Complete-ManagedWingetPackage 'winget:test-absent' $false '' 55 $absent '' $false
    if ($status -ne 55 -or $script:Receipt.packages.Contains('winget:test-absent')) { throw 'definitive absence did not cancel pending entry' }

    Begin-ManagedPackage 'winget:test-sequence' $false '' | Out-Null
    $status = Complete-ManagedWingetPackage 'winget:test-sequence' $false '' 55 1 '' $true
    if ($status -ne 55 -or -not $script:Receipt.packages['winget:test-sequence'].pending) { throw 'partial mutation did not stay pending' }
    $resolved = Complete-PendingManagedWingetPackage 'winget:test-sequence' 0 '2.0.0' $true
    if (-not $resolved -or $script:Receipt.packages['winget:test-sequence'].pending -or $script:Receipt.packages['winget:test-sequence'].installed -ne '2.0.0') { throw 'pending retry did not finalize exact identity' }

    Begin-ManagedPackage 'winget:test-pending-transient' $false '' | Out-Null
    $resolved = Complete-PendingManagedWingetPackage 'winget:test-pending-transient' 1 '' $false
    if ($resolved -or -not $script:Receipt.packages['winget:test-pending-transient'].pending) { throw 'pending transient query discarded journal' }

    Begin-ManagedPackage 'winget:test-pending-absent' $false '' | Out-Null
    $resolved = Complete-PendingManagedWingetPackage 'winget:test-pending-absent' $absent '' $false
    if (-not $resolved -or $script:Receipt.packages.Contains('winget:test-pending-absent')) { throw 'pending definitive absence was not reconciled' }
    Write-Host 'Windows direct artifact package journal: PASS'
} finally {
    $env:LOCALAPPDATA = $oldLocal; $env:USERPROFILE = $oldProfile
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item Env:DOTFILES_RECEIPT_PATH -ErrorAction SilentlyContinue
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
