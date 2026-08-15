$ErrorActionPreference = 'Stop'

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-receipt-$([guid]::NewGuid())"
$old = @{
    functions = $env:DOTFILES_FUNCTIONS_ONLY
    receipt = $env:DOTFILES_RECEIPT_PATH
    git = $env:GIT_CONFIG_GLOBAL
    userprofile = $env:USERPROFILE
    home = $env:HOME
    localappdata = $env:LOCALAPPDATA
    appdata = $env:APPDATA
}

function Assert([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force -Path $temp | Out-Null
    $env:USERPROFILE = Join-Path $temp 'home'
    $env:HOME = $env:USERPROFILE
    $env:LOCALAPPDATA = Join-Path $temp 'localappdata'
    $env:APPDATA = Join-Path $temp 'appdata'
    New-Item -ItemType Directory -Force -Path $env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA | Out-Null
    $env:DOTFILES_FUNCTIONS_ONLY = '1'
    $env:DOTFILES_RECEIPT_PATH = Join-Path $temp 'state\install-receipt.json'
    $env:GIT_CONFIG_GLOBAL = Join-Path $temp 'gitconfig'
    . (Join-Path $root 'install.ps1')
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY
    foreach ($path in @($ClaudeDir,$CodexDir,$LocalBin,$NvimConfigDir,$script:ReceiptPath)) {
        Assert ([IO.Path]::GetFullPath($path).StartsWith([IO.Path]::GetFullPath($temp), [StringComparison]::OrdinalIgnoreCase)) "installer user path escaped temp root: $path"
    }

    Assert (Initialize-InstallReceipt) 'fresh receipt initialization failed'
    $src = Join-Path $temp 'source.txt'
    $dst = Join-Path $temp 'managed\file.txt'
    New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
    Set-Content $src 'v1' -NoNewline
    Set-Content $dst 'user' -NoNewline
    Assert (Install-ManagedFile $src $dst Takeover) 'generic takeover failed'
    Assert ((Get-Content $dst -Raw) -eq 'v1') 'generic destination not installed'
    Assert ((Get-Content "$dst.dotfiles-backup" -Raw) -eq 'user') 'first backup missing'

    Set-Content $src 'v2' -NoNewline
    Assert (Install-ManagedFile $src $dst Takeover) 'managed update failed'
    Assert ((Get-Content $dst -Raw) -eq 'v2') 'managed update content mismatch'
    Assert (@(Get-ChildItem (Split-Path $dst) -Filter 'file.txt.dotfiles-backup*').Count -eq 1) 'backup repeated'

    $identicalDst = Join-Path $temp 'identical.txt'
    Set-Content $identicalDst 'v2' -NoNewline
    Assert (Install-ManagedFile $src $identicalDst Takeover) 'identical unowned file was rejected'
    Assert (-not $script:Receipt.artifacts.Contains([IO.Path]::GetFullPath($identicalDst))) 'identical unowned file was claimed'
    Assert (-not (Test-Path "$identicalDst.dotfiles-backup")) 'identical unowned file was backed up'

    $pendingDst = Join-Path $temp 'pending.txt'
    Set-Content $pendingDst 'before' -NoNewline
    $pendingHash = (Get-FileHash $pendingDst -Algorithm SHA256).Hash.ToLowerInvariant()
    $pendingKey = [IO.Path]::GetFullPath($pendingDst)
    $pendingReceipt = "$env:DOTFILES_RECEIPT_PATH.pending"
    & jq --arg path $pendingKey --arg hash $pendingHash '.artifacts[$path]={before:{exists:true,hash:$hash,backup:null},installedHash:null,pending:true}' $env:DOTFILES_RECEIPT_PATH |
        Set-Content $pendingReceipt -NoNewline
    Move-Item $pendingReceipt $env:DOTFILES_RECEIPT_PATH -Force
    Assert (Initialize-InstallReceipt) 'pending receipt reload failed'
    Assert (Install-ManagedFile $src $pendingDst Takeover) 'pending artifact did not recover'
    Assert ((Get-Content $pendingDst -Raw) -eq 'v2') 'pending artifact content mismatch'

    $pendingBackupDst = Join-Path $temp 'pending-backup.txt'
    Set-Content $pendingBackupDst 'original' -NoNewline
    $pendingBackupHash = (Get-FileHash $pendingBackupDst -Algorithm SHA256).Hash.ToLowerInvariant()
    $pendingBackupKey = [IO.Path]::GetFullPath($pendingBackupDst)
    $script:Receipt.artifacts[$pendingBackupKey] = [ordered]@{
        before = [ordered]@{ exists = $true; hash = $pendingBackupHash; backup = "$pendingBackupDst.dotfiles-backup" }
        installedHash = $null; pending = $true
        targetHash = (Get-FileHash $src -Algorithm SHA256).Hash.ToLowerInvariant()
        previousHash = $pendingBackupHash; previousExists = $true
    }
    Save-InstallReceipt
    Assert (Initialize-InstallReceipt) 'pending backup receipt reload failed'
    Assert (Install-ManagedFile $src $pendingBackupDst Takeover) 'pending backup did not recover'
    Assert ((Get-Content "$pendingBackupDst.dotfiles-backup" -Raw) -eq 'original') 'pending backup missed original content'

    Set-Content $dst 'user-edit' -NoNewline
    Set-Content $src 'v3' -NoNewline
    Assert (-not (Install-ManagedFile $src $dst Takeover)) 'hash mismatch was overwritten'
    Assert ((Get-Content $dst -Raw) -eq 'user-edit') 'hash mismatch content not preserved'

    $collision = Join-Path $temp 'collision.txt'
    Set-Content $collision 'sentinel' -NoNewline
    Assert (-not (Install-ManagedFile $src $collision Skip)) 'unowned collision was overwritten'
    Assert ((Get-Content $collision -Raw) -eq 'sentinel') 'collision sentinel changed'

    $directoryCollision = Join-Path $temp 'as-directory'
    New-Item -ItemType Directory -Force -Path $directoryCollision | Out-Null
    Assert (-not (Install-ManagedFile $src $directoryCollision Skip)) 'directory collision was claimed as file'
    Assert (@(Get-ChildItem $directoryCollision -Force).Count -eq 0) 'directory collision received temp children'
    Assert (-not $script:Receipt.artifacts.Contains([IO.Path]::GetFullPath($directoryCollision))) 'directory collision entered receipt'

    $treeSrc = Join-Path $temp 'tree-src'
    $treeDst = Join-Path $temp 'tree-dst'
    New-Item -ItemType Directory -Force -Path $treeSrc,$treeDst | Out-Null
    Set-Content (Join-Path $treeSrc 'managed.txt') 'managed' -NoNewline
    Set-Content (Join-Path $treeDst 'extra.txt') 'extra' -NoNewline
    $null = Install-ManagedTree $treeSrc $treeDst Takeover
    Assert ((Get-Content (Join-Path $treeDst 'extra.txt') -Raw) -eq 'extra') 'destination extra file was removed'
    $treeRootFile = Join-Path $temp 'tree-root-file'
    Set-Content $treeRootFile 'sentinel' -NoNewline
    Assert (-not (Install-ManagedTree $treeSrc $treeRootFile Takeover)) 'regular file accepted as tree root'
    Assert ((Get-Content $treeRootFile -Raw) -eq 'sentinel') 'tree root file changed'

    $linkTreeSrc = Join-Path $temp 'link-tree-src'
    $linkTreeDst = Join-Path $temp 'link-tree-dst'
    $linkOutside = Join-Path $temp 'link-tree-outside'
    New-Item -ItemType Directory -Force -Path (Join-Path $linkTreeSrc 'nested'),$linkTreeDst,$linkOutside | Out-Null
    Set-Content (Join-Path $linkTreeSrc 'nested\managed.txt') 'managed' -NoNewline
    Set-Content (Join-Path $linkOutside 'managed.txt') 'sentinel' -NoNewline
    $treeLinkCreated = $false
    try { New-Item -ItemType SymbolicLink -Path (Join-Path $linkTreeDst 'nested') -Target $linkOutside -ErrorAction Stop | Out-Null; $treeLinkCreated = $true } catch { }
    if ($treeLinkCreated) {
        Assert (-not (Install-ManagedTree $linkTreeSrc $linkTreeDst Takeover)) 'intermediate tree symlink was followed'
        Assert ((Get-Content (Join-Path $linkOutside 'managed.txt') -Raw) -eq 'sentinel') 'intermediate tree symlink overwrote external file'
        Assert (-not $script:Receipt.artifacts.Contains([IO.Path]::GetFullPath((Join-Path $linkTreeDst 'nested\managed.txt')))) 'intermediate tree symlink entered receipt'
    }

    $skillSrc = Join-Path $temp 'skill-src'
    $skillDst = Join-Path $temp 'skill-dst'
    New-Item -ItemType Directory -Force -Path $skillSrc,$skillDst | Out-Null
    Set-Content (Join-Path $skillSrc 'SKILL.md') 'managed' -NoNewline
    Set-Content (Join-Path $skillDst 'user.txt') 'sentinel' -NoNewline
    Assert (-not (Install-ManagedTree $skillSrc $skillDst Skip $true)) 'unowned skill root was adopted'
    Assert (-not (Test-Path (Join-Path $skillDst 'SKILL.md'))) 'skill collision deployed a file'

    Record-ManagedPackage 'test:same' $true '1' '1'
    Record-ManagedPackage 'test:fresh' $false '' '2'
    Record-ManagedPackage 'test:upgrade' $true '1' '2'
    Record-ManagedPackage 'test:upgrade' $true 'ignored' '3'
    Assert (Begin-ManagedPackage 'test:crash-package' $false '') 'package pending journal failed'
    Assert (Initialize-InstallReceipt) 'package pending reload failed'
    Assert (Begin-ManagedPackage 'test:crash-package' $true '1') 'package pending reconcile failed'
    Cancel-ManagedPackage 'test:crash-package'

    # fnm은 셸마다 새 multishell 링크를 만든다. prefix를 링크째로 기록하면 매 실행 소유권 판정이 깨진다.
    $stablePrefix = Join-Path $env:APPDATA 'fnm\node-versions\v1.0.0\installation'
    $ephemeralPrefix = Join-Path $env:LOCALAPPDATA 'fnm_multishells\1234_5678'
    Assert (Test-EphemeralNpmPrefix $ephemeralPrefix) 'multishell prefix not detected as ephemeral'
    Assert (-not (Test-EphemeralNpmPrefix $stablePrefix)) 'stable prefix flagged as ephemeral'
    New-Item -ItemType Directory -Force -Path $stablePrefix | Out-Null
    $prefixLinkCreated = $false
    try {
        New-Item -ItemType Directory -Force -Path (Split-Path $ephemeralPrefix) | Out-Null
        New-Item -ItemType SymbolicLink -Path $ephemeralPrefix -Target $stablePrefix -ErrorAction Stop | Out-Null
        $prefixLinkCreated = $true
    } catch { }
    if ($prefixLinkCreated) {
        Assert ((Resolve-ManagedLinkPath $ephemeralPrefix) -eq (Get-ManagedPath $stablePrefix).TrimEnd('\')) 'ephemeral prefix link not resolved'
    }

    Assert (Begin-ManagedPackage 'npm:test-prefix' $false '' $stablePrefix) 'npm prefix journal failed'
    Record-ManagedPackage 'npm:test-prefix' $false '' '1' $stablePrefix
    Assert (Begin-ManagedPackage 'npm:test-prefix' $true '1' $stablePrefix) 'matching npm prefix was rejected'
    Cancel-ManagedPackage 'npm:test-prefix'
    Assert (-not (Begin-ManagedPackage 'npm:test-prefix' $true '1' (Join-Path $env:APPDATA 'other\prefix'))) 'changed npm prefix was adopted'
    Assert (-not (Begin-ManagedPackage 'npm:test-prefix' $true '1' $ephemeralPrefix)) 'ephemeral npm prefix was recorded'
    Assert ($script:Receipt.packages['npm:test-prefix'].prefix -eq $stablePrefix) 'rejected npm prefix overwrote receipt'

    # 이전 버그가 남긴 multishell prefix는 안정 경로로 교정되어야 한다.
    $script:Receipt.packages['npm:test-prefix'].prefix = $ephemeralPrefix
    Assert (Begin-ManagedPackage 'npm:test-prefix' $true '1' $stablePrefix) 'ephemeral npm prefix was not repaired'
    Assert ($script:Receipt.packages['npm:test-prefix'].prefix -eq $stablePrefix) 'repaired npm prefix not persisted'
    # 낡은 prefix에서 잰 before는 새 위치에 대해 무의미하므로 지금 측정값으로 다시 잡혀야 한다.
    Assert ($script:Receipt.packages['npm:test-prefix'].before.present -eq $true) 'repaired before.present not rebased'
    Assert ($script:Receipt.packages['npm:test-prefix'].before.value -eq '1') 'repaired before.value not rebased'
    Cancel-ManagedPackage 'npm:test-prefix'
    Assert ((Resolve-ManagedLinkPath '') -eq '') 'empty link path did not resolve to empty'

    # 설치 후 외부 CLI가 관리 파일을 다시 써도 소유권을 잃지 않아야 한다.
    $syncDst = Join-Path $temp 'sync-target.txt'
    Assert (Install-ManagedFile $src $syncDst Takeover) 'sync fixture install failed'
    Assert (-not (Sync-ManagedFileHash $syncDst)) 'unchanged managed file was restamped'
    Set-Content $syncDst 'rewritten-by-external-tool' -NoNewline
    Assert (Sync-ManagedFileHash $syncDst) 'externally rewritten managed file was not restamped'
    $syncEntry = $script:Receipt.artifacts[[IO.Path]::GetFullPath($syncDst)]
    Assert ($syncEntry.installedHash -eq (Get-FileHash $syncDst -Algorithm SHA256).Hash.ToLowerInvariant()) 'restamped hash mismatch'
    Assert (Install-ManagedFile $src $syncDst Takeover) 'restamped file was preserved on next install'
    Assert ((Get-Content $syncDst -Raw) -eq (Get-Content $src -Raw)) 'restamped file was not updated'
    Assert (-not (Sync-ManagedFileHash (Join-Path $temp 'never-managed.txt'))) 'unmanaged path was restamped'

    Record-ManagedValue 'env:PATH:C:\Tools' $false $null 'present' $false
    Record-ManagedValue 'env:SECRET_TOKEN' $true 'do-not-store' 'new-secret'
    git config --global test.receipt before
    Set-ManagedGitValue test.receipt after
    Set-ManagedGitValue credential.credentialStore dpapi
    Assert ((git config --global --get credential.credentialStore) -eq 'dpapi') 'safe credentialStore setting was blocked'

    git config --global test.save-failure before
    $saveReceipt = ${function:Save-InstallReceipt}
    function Save-InstallReceipt { throw 'forced receipt save failure' }
    try { Set-ManagedGitValue test.save-failure after } catch { }
    Assert ((git config --global --get test.save-failure) -eq 'before') 'Git mutated after receipt save failure'
    $failedDst = Join-Path $temp 'failed-receipt-file'
    Set-Content $failedDst 'user' -NoNewline
    try { $null = Install-ManagedFile $src $failedDst Takeover } catch { }
    Assert ((Get-Content $failedDst -Raw) -eq 'user') 'artifact changed after receipt save failure'
    Assert (-not (Test-Path "$failedDst.dotfiles-backup")) 'backup was created before receipt journal'
    Set-Item Function:Save-InstallReceipt $saveReceipt

    $crashSrc = Join-Path $temp 'crash-source.txt'
    $crashDst = Join-Path $temp 'crash-destination.txt'
    Set-Content $crashSrc 'v1' -NoNewline
    Assert (Install-ManagedFile $crashSrc $crashDst Takeover) 'crash fixture initial install failed'
    Set-Content $crashSrc 'v2' -NoNewline
    $script:OriginalSaveInstallReceipt = ${function:Save-InstallReceipt}
    $script:SaveInstallReceiptCalls = 0
    function Save-InstallReceipt {
        $script:SaveInstallReceiptCalls++
        if ($script:SaveInstallReceiptCalls -eq 2) { throw 'forced final receipt save failure' }
        & $script:OriginalSaveInstallReceipt
    }
    try { $null = Install-ManagedFile $crashSrc $crashDst Takeover } catch { }
    finally { Set-Item Function:Save-InstallReceipt $script:OriginalSaveInstallReceipt }
    Assert ($script:SaveInstallReceiptCalls -eq 2) 'managed update did not journal before mutation'
    Assert ((Get-Content $crashDst -Raw) -eq 'v2') 'managed update fixture did not reach post-mutation crash'
    Assert (Initialize-InstallReceipt) 'post-mutation pending receipt reload failed'
    Assert (Install-ManagedFile $crashSrc $crashDst Takeover) 'post-mutation pending receipt did not recover'
    $crashEntry = $script:Receipt.artifacts[[IO.Path]::GetFullPath($crashDst)]
    Assert (-not $crashEntry.pending -and -not $crashEntry.Contains('targetHash')) 'post-mutation pending receipt not finalized'

    git config --global test.pending before
    Assert (Begin-ManagedValue 'git:test.pending' $true 'before' 'after') 'value pending journal failed'
    git config --global test.pending after
    Assert (Initialize-InstallReceipt) 'pending value receipt reload failed'
    Set-ManagedGitValue test.pending after
    Assert (-not $script:Receipt.values['git:test.pending'].Contains('pending')) 'pending value not reconciled'

    & jq -e '
      (.schemaVersion == 1) and
      (.packages | has("test:same") | not) and
      (.packages["test:fresh"].before.present == false) and
      (.packages["test:upgrade"].before.value == "1") and
      (.packages["test:upgrade"].installed == "3") and
      (.packages["test:crash-package"].before.present == false) and
      (.packages["test:crash-package"].installed == "1") and
      (.packages["test:crash-package"] | has("pending") | not) and
      (.values["env:PATH:C:\\Tools"].before == {"present":false}) and
      (.values | has("env:SECRET_TOKEN") | not) and
      (.values["git:test.receipt"].before.value == "before") and
      (.values["git:test.receipt"].installed == "after") and
      (.values["git:credential.credentialStore"].before.present == false) and
      (.values["git:credential.credentialStore"].installed == "dpapi")
    ' $env:DOTFILES_RECEIPT_PATH | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'receipt package/value contract failed'

    $invalid = Join-Path $temp 'invalid.json'
    Set-Content $invalid '{partial' -NoNewline
    $script:ReceiptPath = $invalid
    $script:ReceiptReady = $false
    $invalidDst = Join-Path $temp 'invalid-dst.txt'
    Set-Content $invalidDst 'keep' -NoNewline
    Assert (-not (Initialize-InstallReceipt)) 'invalid receipt accepted'
    Assert (-not (Install-ManagedFile $src $invalidDst Takeover)) 'write proceeded with invalid receipt'
    Assert ((Get-Content $invalid -Raw) -eq '{partial') 'invalid receipt overwritten'
    Assert ((Get-Content $invalidDst -Raw) -eq 'keep') 'destination changed with invalid receipt'

    $partial = Join-Path $temp 'partial.json'
    Set-Content $partial '{"schemaVersion":1,"artifacts":{},"packages":{}}' -NoNewline
    $script:ReceiptPath = $partial
    Assert (-not (Initialize-InstallReceipt)) 'partial receipt accepted'
    Assert ((Get-Content $partial -Raw) -eq '{"schemaVersion":1,"artifacts":{},"packages":{}}') 'partial receipt overwritten'

    $receiptDirectory = Join-Path $temp 'receipt-as-directory'
    New-Item -ItemType Directory -Force -Path $receiptDirectory | Out-Null
    $script:ReceiptPath = $receiptDirectory
    Assert (-not (Initialize-InstallReceipt)) 'receipt directory path accepted'
    Assert (@(Get-ChildItem $receiptDirectory -Force).Count -eq 0) 'receipt directory received temp children'

    $receiptTarget = Join-Path $temp 'receipt-target.json'
    $receiptLink = Join-Path $temp 'receipt-link.json'
    Copy-Item $env:DOTFILES_RECEIPT_PATH $receiptTarget
    $targetHash = (Get-FileHash $receiptTarget -Algorithm SHA256).Hash
    $linkCreated = $false
    try { New-Item -ItemType SymbolicLink -Path $receiptLink -Target $receiptTarget -ErrorAction Stop | Out-Null; $linkCreated = $true } catch { }
    if ($linkCreated) {
        $script:ReceiptPath = $receiptLink
        Assert (-not (Initialize-InstallReceipt)) 'receipt symlink path accepted'
        Assert ((Get-Item $receiptLink -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) 'receipt symlink was replaced'
        Assert ((Get-FileHash $receiptTarget -Algorithm SHA256).Hash -eq $targetHash) 'receipt symlink target changed'
    }

    $script:ReceiptPath = $env:DOTFILES_RECEIPT_PATH
    Assert (Initialize-InstallReceipt) 'receipt reload failed'
    git config --global test.receipt user-edit
    Set-ManagedGitValue test.receipt should-not-win
    Assert ((git config --global --get test.receipt) -eq 'user-edit') 'modified managed Git value overwritten'
    Assert (@(Get-ChildItem (Split-Path $env:DOTFILES_RECEIPT_PATH) -Filter '.install-receipt.*.tmp').Count -eq 0) 'receipt temp file leaked'

    $fnmRoot = Join-Path $temp 'fnm'
    $settings = Join-Path $temp 'claude\settings.json'
    New-Item -ItemType Directory -Force -Path (Join-Path $fnmRoot 'node-versions\v22.0.0\installation'),(Split-Path $settings) | Out-Null
    Set-Content (Join-Path $fnmRoot 'node-versions\v22.0.0\installation\node.exe') 'node' -NoNewline
    "{`"statusLine`":{`"command`":`"$($fnmRoot.Replace('\','/'))/node-versions/v21.0.0/installation/node.exe hud`"}}" | Set-Content $settings -NoNewline
    $script:ReceiptPath = $env:DOTFILES_RECEIPT_PATH
    Assert (Initialize-InstallReceipt) 'receipt reload before fnm failed'
    Assert (Update-FnmStatusLine $settings $fnmRoot 'v22.0.0') 'receipt-aware fnm update failed'
    $fnmBackup = "$settings.dotfiles-backup"
    Assert ((Get-Content $fnmBackup -Raw) -match 'v21\.0\.0') 'fnm first backup missed original settings'
    $userSettings = (Get-Content $settings -Raw).Replace('hud', 'user-hud')
    Set-Content $settings $userSettings -NoNewline
    New-Item -ItemType Directory -Force -Path (Join-Path $fnmRoot 'node-versions\v23.0.0\installation') | Out-Null
    Set-Content (Join-Path $fnmRoot 'node-versions\v23.0.0\installation\node.exe') 'node' -NoNewline
    Assert (-not (Update-FnmStatusLine $settings $fnmRoot 'v23.0.0')) 'fnm overwrote user-modified settings'
    Assert ((Get-Content $settings -Raw) -match 'user-hud') 'fnm user modification not preserved'

    Write-Host 'Windows install receipt: PASS'
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    if ($null -eq $old.functions) { Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue } else { $env:DOTFILES_FUNCTIONS_ONLY = $old.functions }
    if ($null -eq $old.receipt) { Remove-Item Env:DOTFILES_RECEIPT_PATH -ErrorAction SilentlyContinue } else { $env:DOTFILES_RECEIPT_PATH = $old.receipt }
    if ($null -eq $old.git) { Remove-Item Env:GIT_CONFIG_GLOBAL -ErrorAction SilentlyContinue } else { $env:GIT_CONFIG_GLOBAL = $old.git }
    foreach ($name in @('USERPROFILE','HOME','LOCALAPPDATA','APPDATA')) {
        $value = $old[$name.ToLowerInvariant()]
        if ($null -eq $value) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue } else { Set-Item "Env:$name" $value }
    }
}
