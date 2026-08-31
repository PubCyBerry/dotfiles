$ErrorActionPreference = 'Stop'
$temp = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-direct-$([guid]::NewGuid())"
$env:DOTFILES_FUNCTIONS_ONLY = '1'
$env:DOTFILES_RECEIPT_PATH = Join-Path $temp 'state\receipt.json'
$oldLocal = $env:LOCALAPPDATA; $oldProfile = $env:USERPROFILE; $oldUpgrade = $env:DOTFILES_UPGRADE_DIRECT
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

    # direct file 버전 게이트 — tests/ownership/direct-artifacts.sh의 direct_anchor_state
    # 단언과 같은 계약이다. manifest 버전이 올라가도 DOTFILES_UPGRADE_DIRECT=1 없이는
    # 바꾸지 않아야 한다(shellcheck처럼 버전이 곧 규칙 집합인 artifact가 여기 걸린다).
    $v1 = Join-Path $temp 'v1'; Set-Content -LiteralPath $v1 -Value 'v1' -NoNewline
    $tool = Join-Path $env:USERPROFILE 'bin\tool'
    if (-not (Install-ManagedFile $v1 $tool Skip)) { throw 'direct file install failed' }
    if ((Get-DirectFileState $tool '1').State -ne 'recover') { throw 'missing directVersion did not fall back to recover' }
    if (-not (Set-DirectFileVersion $tool '1')) { throw 'directVersion was not recorded' }
    if ((Get-DirectFileState $tool '1').State -ne 'current') { throw 'matching version was not current' }
    $blocked = Get-DirectFileState $tool '2'
    if ($blocked.State -ne 'upgrade-blocked' -or $blocked.InstalledVersion -cne '1') { throw 'upgrade gate did not block' }
    $env:DOTFILES_UPGRADE_DIRECT = '1'
    if ((Get-DirectFileState $tool '2').State -ne 'upgrade') { throw 'upgrade opt-in was not honored' }
    $env:DOTFILES_UPGRADE_DIRECT = $null
    Set-Content -LiteralPath $tool -Value 'tampered' -NoNewline
    if ((Get-DirectFileState $tool '2').State -ne 'modified') { throw 'tampered file did not win over upgrade gate' }
    $env:DOTFILES_UPGRADE_DIRECT = '1'
    if ((Get-DirectFileState $tool '2').State -ne 'modified') { throw 'tampered file was overwritten under upgrade opt-in' }
    $env:DOTFILES_UPGRADE_DIRECT = $null

    Write-Host 'Windows direct artifact package journal: PASS'
} finally {
    $env:LOCALAPPDATA = $oldLocal; $env:USERPROFILE = $oldProfile; $env:DOTFILES_UPGRADE_DIRECT = $oldUpgrade
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item Env:DOTFILES_RECEIPT_PATH -ErrorAction SilentlyContinue
    if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
}
