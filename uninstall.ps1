param([switch]$KeepPackages)

$ErrorActionPreference = 'Stop'
$script:Root = $PSScriptRoot
$script:ReceiptPath = if ($env:DOTFILES_RECEIPT_PATH) { $env:DOTFILES_RECEIPT_PATH } else { Join-Path $env:LOCALAPPDATA 'dotfiles\install-receipt.json' }
$script:Receipt = $null

function Write-Preserve([string]$Message) { Write-Warning $Message }
function Get-DotfilesUserEnvironment([string]$Name) { [Environment]::GetEnvironmentVariable($Name, 'User') }
function Set-DotfilesUserEnvironment([string]$Name, [AllowNull()][object]$Value) { [Environment]::SetEnvironmentVariable($Name, $Value, 'User') }

function Save-UninstallReceipt {
    $dir = Split-Path $script:ReceiptPath
    $tmp = Join-Path $dir ".uninstall-receipt.$([guid]::NewGuid()).tmp"
    try {
        $script:Receipt | ConvertTo-Json -Depth 12 | Out-File $tmp -Encoding utf8 -NoNewline
        $null = Get-Content $tmp -Raw | ConvertFrom-Json -AsHashtable
        Move-Item -LiteralPath $tmp -Destination $script:ReceiptPath -Force
    } finally { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
}

function Remove-ReceiptEntry([string]$Group, [string]$Key) {
    $script:Receipt[$Group].Remove($Key)
    Save-UninstallReceipt
}

function Test-ArtifactAllowed([string]$Path) {
    if ($Path -match '\\(?:\.{1,2})(?:\\|$)' -or $Path -match '\\\\') { return $false }
    $full = [IO.Path]::GetFullPath($Path)
    $homeRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    if (-not $full.StartsWith("$homeRoot\", [StringComparison]::OrdinalIgnoreCase)) { return $false }
    $exact = @(
        (Join-Path $homeRoot '.tmux.conf'),
        (Join-Path $homeRoot '.codex\AGENTS.md'), (Join-Path $homeRoot '.codex\config.toml'), (Join-Path $homeRoot '.codex\hooks.json'),
        (Join-Path $homeRoot '.claude\CLAUDE.md'), (Join-Path $homeRoot '.claude\settings.json')
    )
    if ($exact -contains $full) { return $true }
    $pairs = @(
        @((Join-Path $script:Root 'config\yazi'), (Join-Path $env:APPDATA 'yazi\config')),
        @((Join-Path $script:Root 'config\nvim'), (Join-Path $env:LOCALAPPDATA 'nvim')),
        @((Join-Path $script:Root 'config\codex\hooks'), (Join-Path $homeRoot '.codex\hooks')),
        @((Join-Path $script:Root 'config\claude\hooks'), (Join-Path $homeRoot '.claude\hooks')),
        @((Join-Path $script:Root 'config\claude\skills'), (Join-Path $homeRoot '.claude\skills'))
    )
    foreach ($pair in $pairs) {
        $prefix = [IO.Path]::GetFullPath($pair[1]).TrimEnd('\') + '\'
        if ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $relative = [IO.Path]::GetRelativePath($pair[1], $full)
            return Test-Path -LiteralPath (Join-Path $pair[0] $relative) -PathType Leaf
        }
    }
    foreach ($spec in @(@('.codex\agents\','.toml'),@('.claude\agents\','.md'))) {
        $prefix = Join-Path $homeRoot $spec[0]
        if ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $relative = $full.Substring($prefix.Length)
            if ($relative.Contains('\') -or [IO.Path]::GetExtension($relative) -cne $spec[1]) { return $false }
            return Test-Path -LiteralPath (Join-Path $script:Root "config\agents\roles\$([IO.Path]::GetFileNameWithoutExtension($relative))") -PathType Container
        }
    }
    return $false
}

function Test-PlainFileHash([string]$Path, [string]$Hash) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    $item -is [IO.FileInfo] -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and
        (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() -eq $Hash
}

function Test-SafeParentChain([string]$Path) {
    $homeRoot = [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\')
    $parent = [IO.Directory]::GetParent([IO.Path]::GetFullPath($Path))
    while ($parent -and -not $parent.FullName.Equals($homeRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $item = Get-Item -LiteralPath $parent.FullName -Force -ErrorAction SilentlyContinue
        if ($item -and ($item -isnot [IO.DirectoryInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))) { return $false }
        $parent = $parent.Parent
    }
    return $null -ne $parent
}
function Test-CanonicalBackup([string]$Path, [AllowNull()][string]$Backup) {
    -not $Backup -or $Backup -match ('^' + [regex]::Escape($Path + '.dotfiles-backup') + '(\.\d+)?$')
}
function Test-ReceiptSchema {
    foreach ($key in $script:Receipt.artifacts.Keys) {
        $entry=$script:Receipt.artifacts[$key]
        if ($key -match '\\(?:\.{1,2})(?:\\|$)' -or $key -match '\\\\' -or -not (Test-ArtifactAllowed $key) -or -not (Test-SafeParentChain $key) -or $entry.before -isnot [Collections.IDictionary] -or $entry.before.exists -isnot [bool] -or -not (Test-CanonicalBackup $key $entry.before.backup)) { return $false }
        if ($entry.Contains('pending') -and $entry.pending -isnot [bool]) { return $false }
        if (-not $entry.Contains('installedHash') -or (($null -eq $entry.installedHash) -and -not $entry.pending) -or (($null -ne $entry.installedHash) -and ($entry.installedHash -isnot [string]))) { return $false }
        if ($entry.before.exists -and ($entry.before.hash -isnot [string] -or $entry.before.backup -isnot [string] -or -not $entry.before.backup)) { return $false }
        if ($entry.pending -and ($entry.targetHash -isnot [string] -or $entry.previousExists -isnot [bool] -or ($entry.previousExists -and $entry.previousHash -isnot [string]))) { return $false }
    }
    foreach ($key in $script:Receipt.packages.Keys) {
        $entry=$script:Receipt.packages[$key]
        if ($key -notmatch '^(winget:[^/\s]+|npm:(@[^/\s]+/)?[^/\s]+)$' -or $entry.before.present -isnot [bool] -or (($null -eq $entry.installed) -and -not $entry.pending) -or (($null -ne $entry.installed) -and $entry.installed -isnot [string]) -or ($entry.before.present -and $entry.before.value -isnot [string])) { return $false }
        if (-not (Test-PackageKeyAllowed $key) -or ($key.StartsWith('npm:') -and (-not (Test-NpmPrefixAllowed $entry.prefix)))) { return $false }
        if ($entry.pending -and ($entry.pending.previousPresent -isnot [bool] -or $entry.pending.newEntry -isnot [bool] -or ($entry.pending.previousPresent -and $entry.pending.previousValue -isnot [string]))) { return $false }
    }
    foreach ($key in $script:Receipt.values.Keys) {
        $entry=$script:Receipt.values[$key]
        if (-not (Test-ValueKeyAllowed $key) -or $entry.before.present -isnot [bool] -or (($null -eq $entry.installed) -and -not $entry.pending) -or (($null -ne $entry.installed) -and $entry.installed -isnot [string]) -or ($entry.before.present -and $entry.before.value -isnot [string])) { return $false }
        if ($entry.pending -and ($entry.pending.previousPresent -isnot [bool] -or $entry.pending.target -isnot [string] -or ($entry.pending.previousPresent -and $entry.pending.previousValue -isnot [string]))) { return $false }
        if ($key.StartsWith('env:PATH:') -and ($entry.before.present -ne $false -or $entry.installed -cne 'present' -or ($entry.pending -and ($entry.pending.previousPresent -ne $false -or $entry.pending.target -cne 'present')))) { return $false }
    }
    return $true
}
function Test-PackageKeyAllowed([string]$Key) {
    if ($Key -eq 'winget:Anthropic.ClaudeCode') { return $true }
    $kind,$name=$Key -split ':',2
    $manifest=if($kind -eq 'winget'){Join-Path $script:Root 'manifests\winget.txt'}elseif($kind -eq 'npm'){Join-Path $script:Root 'manifests\npm-global.txt'}else{return $false}
    return @(Get-Content $manifest | ForEach-Object{($_ -split '#')[0].Trim()} | Where-Object{$_ -ceq $name}).Count -eq 1
}
function Test-ValueKeyAllowed([string]$Key) {
    if ($Key -in @('git:core.pager','git:core.editor','git:core.fileMode','git:core.autocrlf','git:core.eol','git:core.quotepath','git:init.defaultBranch','git:interactive.diffFilter','git:delta.navigate','git:delta.dark','git:delta.side-by-side','git:delta.line-numbers','git:merge.conflictStyle','git:credential.credentialStore','env:YAZI_FILE_ONE','env:PATH:C:\Program Files\Neovim\bin')) { return $true }
    $fnmRoot=[IO.Path]::GetFullPath($(if($env:FNM_DIR){$env:FNM_DIR}else{Join-Path $env:APPDATA 'fnm'})).TrimEnd('\')
    $Key -ieq ('env:PATH:' + (Join-Path $fnmRoot 'aliases\default'))
}
function Test-NpmPrefixAllowed([string]$Prefix) {
    if (-not $Prefix -or $Prefix -match '\\(?:\.{1,2})(?:\\|$)' -or $Prefix -match '\\\\') { return $false }
    $homeRoot=[IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\');$full=[IO.Path]::GetFullPath($Prefix)
    $fnmRoot=[IO.Path]::GetFullPath($(if($env:FNM_DIR){$env:FNM_DIR}else{Join-Path $env:APPDATA 'fnm'})).TrimEnd('\')
    $full.StartsWith("$homeRoot\",[StringComparison]::OrdinalIgnoreCase) -and $full -match ('^'+[regex]::Escape($fnmRoot)+'\\node-versions\\[^\\]+\\installation$') -and (Test-SafeParentChain (Join-Path $full package.json))
}

function Remove-ManagedArtifact([string]$Path) {
    if (-not (Test-ArtifactAllowed $Path) -or -not (Test-SafeParentChain $Path)) { Write-Preserve "Unsafe receipt artifact preserved: $Path"; return $false }
    $entry = $script:Receipt.artifacts[$Path]
    if (-not $entry.Contains('installedHash')) { Write-Preserve "Unsupported receipt artifact preserved: $Path"; return $false }
    $installed = $entry.installedHash
    if ($entry.before.exists -and $entry.before.backup -and -not (Get-Item -LiteralPath $entry.before.backup -Force -ErrorAction SilentlyContinue) -and (Test-PlainFileHash $Path $entry.before.hash)) { Remove-ReceiptEntry artifacts $Path; return $true }
    if ($entry.pending) {
        if ($entry.targetHash -and (Test-PlainFileHash $Path $entry.targetHash)) { $installed = $entry.targetHash }
        else {
            $previousExists = if ($entry.Contains('previousExists')) { [bool]$entry.previousExists } else { [bool]$entry.before.exists }
            $previousHash = if ($entry.Contains('previousHash')) { $entry.previousHash } else { $entry.before.hash }
            if ((-not $previousExists -and -not (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) -or
                ($previousExists -and (Test-PlainFileHash $Path $previousHash))) {
                if ($null -eq $entry.installedHash) { Remove-ReceiptEntry artifacts $Path; return $true }
                foreach($field in @('pending','targetHash','previousExists','previousHash')){$entry.Remove($field)}; Save-UninstallReceipt; $installed=$entry.installedHash
            } else { Write-Preserve "Pending artifact changed; preserved: $Path"; return $false }
        }
    }
    if ((-not $entry.before.exists -and -not (Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue)) -or
        ($entry.before.exists -and (Test-PlainFileHash $Path $entry.before.hash))) {
        if (-not (Test-CanonicalBackup $Path $entry.before.backup)) { Write-Preserve "Unsafe backup preserved: $($entry.before.backup)"; return $false }
        if ($entry.before.backup -and (Test-Path -LiteralPath $entry.before.backup)) { if (-not (Test-PlainFileHash $entry.before.backup $entry.before.hash)) { Write-Preserve "Invalid backup preserved: $($entry.before.backup)"; return $false }; Remove-Item -LiteralPath $entry.before.backup -Force }
        Remove-ReceiptEntry artifacts $Path; return $true
    }
    if (-not (Test-PlainFileHash $Path $installed)) { Write-Preserve "Modified artifact preserved: $Path"; return $false }
    if (-not $entry.before.exists) { Remove-Item -LiteralPath $Path -Force }
    else {
        $backup = [string]$entry.before.backup
        if (-not (Test-CanonicalBackup $Path $backup) -or -not (Test-PlainFileHash $backup $entry.before.hash)) {
            Write-Preserve "Invalid backup preserved: $backup"; return $false
        }
        Move-Item -LiteralPath $backup -Destination $Path -Force
    }
    Remove-ReceiptEntry artifacts $Path
    return $true
}

function Remove-DotfilesMarkerBlock([string]$Path) {
    if (-not (Test-SafeParentChain $Path)) { Write-Preserve "Unsafe profile parent preserved: $Path"; return $false }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $true }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Write-Preserve "Profile path type preserved: $Path"; return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    $begin = '# ===== dotfiles-begin ====='; $end = '# ===== dotfiles-end ====='
    $beginExact = [regex]::Matches($text, '(?m)^' + [regex]::Escape($begin) + '(?=\r?$)')
    $endExact = [regex]::Matches($text, '(?m)^' + [regex]::Escape($end) + '(?=\r?$)')
    if (-not $text.Contains($begin) -and -not $text.Contains($end)) { return $true }
    if ($beginExact.Count -ne 1 -or $endExact.Count -ne 1 -or $beginExact[0].Index -ge $endExact[0].Index -or
        [regex]::Matches($text, [regex]::Escape($begin)).Count -ne 1 -or [regex]::Matches($text, [regex]::Escape($end)).Count -ne 1) {
        Write-Preserve "Invalid marker state preserved: $Path"; return $false
    }
    $after = $endExact[0].Index + $endExact[0].Length
    $newText = $text.Substring(0, $beginExact[0].Index) + $text.Substring($after)
    $tmp = Join-Path (Split-Path $Path) ".profile.$([guid]::NewGuid()).tmp"
    try { [IO.File]::WriteAllText($tmp, $newText, [Text.UTF8Encoding]::new($false)); Move-Item $tmp $Path -Force }
    finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
    return $true
}

function Get-CurrentPackage([string]$Key) {
    $script:PackageState = 'error'; $script:PackageVersion = ''
    $manager, $name = $Key -split ':', 2
    if ($manager -eq 'npm') {
        $prefix = $script:Receipt.packages[$Key].prefix; if (-not $prefix) { return $false }
        $root = npm root -g --prefix $prefix 2>$null; if ($LASTEXITCODE -ne 0) { return $false }
        $json = Join-Path $root "$name\package.json"
        if (-not (Test-Path -LiteralPath $json)) { $script:PackageState = 'absent'; return $true }
        try { $script:PackageVersion = (& jq -er '.version|strings|select(length>0)' $json 2>$null); if ($LASTEXITCODE -ne 0) { return $false } } catch { return $false }
        $script:PackageState = 'present'; return $true
    }
    if ($manager -eq 'winget') {
        $out = (winget list --id $name --exact --accept-source-agreements 2>&1 | Out-String); $status = $LASTEXITCODE
        foreach ($line in ($out -split "`r?`n")) { $tokens = @($line -split '\s+' | Where-Object { $_ }); for ($i=0; $i -lt $tokens.Count-1; $i++) { if ($tokens[$i] -ieq $name) { $script:PackageVersion=$tokens[$i+1]; $script:PackageState='present'; return $true } } }
        if (('{0:X8}' -f $status) -eq '8A150014') { $script:PackageState='absent'; return $true }
    }
    return $false
}

function Remove-DotfilesPackage([string]$Key) {
    $manager, $name = $Key -split ':', 2
    if ($manager -eq 'npm') { npm uninstall -g --prefix $script:Receipt.packages[$Key].prefix $name | Out-Null; return $LASTEXITCODE -eq 0 }
    if ($manager -eq 'winget') { winget uninstall --id $name --exact --silent --accept-source-agreements | Out-Null; return $LASTEXITCODE -eq 0 }
    return $false
}

function Remove-ManagedPackage([string]$Key) {
    if ($KeepPackages) { Remove-ReceiptEntry packages $Key; return $true }
    if (-not (Get-CurrentPackage $Key)) { Write-Preserve "Package identity unavailable; preserved: $Key"; return $false }
    $entry = $script:Receipt.packages[$Key]
    $installed = $entry.installed
    if ($entry.pending) {
        if (($script:PackageState -eq 'absent' -and -not $entry.pending.previousPresent) -or
                ($script:PackageState -eq 'present' -and $entry.pending.previousPresent -and $script:PackageVersion -eq $entry.pending.previousValue)) {
            if ($entry.pending.newEntry -and $null -eq $entry.installed) { Remove-ReceiptEntry packages $Key; return $true }
            $entry.Remove('pending'); Save-UninstallReceipt; $installed = $entry.installed
        } else { Write-Preserve "Pending package changed; preserved: $Key"; return $false }
    }
    if ($entry.before.present) {
        if ($script:PackageState -eq 'present' -and ($script:PackageVersion -eq $installed -or $script:PackageVersion -eq $entry.before.value)) { Remove-ReceiptEntry packages $Key; return $true }
        Write-Preserve "Changed pre-existing package preserved: $Key"; return $false
    }
    if ($script:PackageState -eq 'absent') { Remove-ReceiptEntry packages $Key; return $true }
    if ($script:PackageVersion -ne $installed) { Write-Preserve "Changed package preserved: $Key"; return $false }
    if ($Key.StartsWith('npm:') -and -not $entry.prefix) { Write-Preserve "npm prefix provenance missing; preserved: $Key"; return $false }
    $entry.uninstallPending = $true; Save-UninstallReceipt
    if (-not (Remove-DotfilesPackage $Key) -or -not (Get-CurrentPackage $Key) -or $script:PackageState -ne 'absent') { Write-Preserve "Package removal failed/ambiguous: $Key"; return $false }
    Remove-ReceiptEntry packages $Key
    return $true
}

function Remove-ManagedValue([string]$Key) {
    $entry = $script:Receipt.values[$Key]
    if ($Key.StartsWith('git:')) {
        $name = $Key.Substring(4); $current = git config --global --get $name 2>$null; $present = $LASTEXITCODE -eq 0
        if ($entry.pending) {
            if ($present -and $current -ceq $entry.pending.target) { $entry.installed = $entry.pending.target }
            elseif ($present -eq [bool]$entry.pending.previousPresent -and (-not $present -or $current -ceq $entry.pending.previousValue)) { if ($null -eq $entry.installed) { Remove-ReceiptEntry values $Key; return $true } else { $entry.Remove('pending'); Save-UninstallReceipt } }
            else { Write-Preserve "Pending value changed; preserved: $Key"; return $false }
        }
        if ($present -and $current -ceq $entry.installed) { if ($entry.before.present) { git config --global $name $entry.before.value } else { git config --global --unset-all $name 2>$null } }
        elseif ($present -ne [bool]$entry.before.present -or ($present -and $current -cne $entry.before.value)) { Write-Preserve "Modified value preserved: $Key"; return $false }
        $check=git config --global --get $name 2>$null;$checkPresent=$LASTEXITCODE -eq 0
        if($checkPresent -ne [bool]$entry.before.present -or ($checkPresent -and $check -cne $entry.before.value)){Write-Preserve "Git restore verification failed: $Key";return $false}
    } elseif ($Key -eq 'env:YAZI_FILE_ONE') {
        $current = Get-DotfilesUserEnvironment 'YAZI_FILE_ONE'; $present = $null -ne $current
        if ($entry.pending) {
            if ($present -and $current -ceq $entry.pending.target) { $entry.installed=$entry.pending.target }
            elseif ($present -eq [bool]$entry.pending.previousPresent -and (-not $present -or $current -ceq $entry.pending.previousValue)) { if ($null -eq $entry.installed) { Remove-ReceiptEntry values $Key; return $true }; $entry.Remove('pending'); Save-UninstallReceipt }
            else { Write-Preserve "Pending YAZI value changed; preserved"; return $false }
        }
        if ($present -and $current -ceq $entry.installed) { if($entry.before.present){Set-DotfilesUserEnvironment 'YAZI_FILE_ONE' $entry.before.value}else{Set-DotfilesUserEnvironment 'YAZI_FILE_ONE' $null} }
        elseif ($present -ne [bool]$entry.before.present -or ($present -and $current -cne $entry.before.value)) { Write-Preserve "Modified value preserved: $Key"; return $false }
        $check=Get-DotfilesUserEnvironment 'YAZI_FILE_ONE'; $checkPresent=$null -ne $check
        if ($checkPresent -ne [bool]$entry.before.present -or ($checkPresent -and $check -cne $entry.before.value)) { Write-Preserve "YAZI restore verification failed"; return $false }
    } elseif ($Key.StartsWith('env:PATH:')) {
        if ($entry.before.present -ne $false -or $entry.installed -cne 'present' -or ($entry.pending -and ($entry.pending.previousPresent -ne $false -or $entry.pending.target -cne 'present'))) { Write-Preserve "Invalid PATH receipt preserved: $Key"; return $false }
        $segment = $Key.Substring(9); $current = Get-DotfilesUserEnvironment 'PATH'; if($null -eq $current){$current=''}; $parts = @($current.Split(';', [StringSplitOptions]::None)); $matches = @($parts | Where-Object { $_.Equals($segment, [StringComparison]::OrdinalIgnoreCase) }); $count = $matches.Count
        if ($entry.pending) {
            if ($count -eq 1) { $entry.installed='present' }
            elseif ($count -eq 0 -and -not $entry.pending.previousPresent) { if($null -eq $entry.installed){Remove-ReceiptEntry values $Key;return $true};$entry.Remove('pending');Save-UninstallReceipt }
            else { Write-Preserve "Pending/ambiguous PATH segment preserved: $segment"; return $false }
        }
        if ($count -eq 1 -and $entry.installed -eq 'present') { $removed=$false; $new=@($parts | Where-Object { if (-not $removed -and $_.Equals($segment,[StringComparison]::OrdinalIgnoreCase)) { $removed=$true; $false } else { $true } }); Set-DotfilesUserEnvironment 'PATH' ($new -join ';') }
        elseif ($count -eq 0 -and -not $entry.before.present) { }
        else { Write-Preserve "Ambiguous PATH segment preserved: $segment"; return $false }
        $check=Get-DotfilesUserEnvironment 'PATH';if($null -eq $check){$check=''};$checkCount=@($check.Split(';',[StringSplitOptions]::None)|Where-Object{$_.Equals($segment,[StringComparison]::OrdinalIgnoreCase)}).Count
        if($entry.before.present){Write-Preserve "Unsupported pre-existing PATH receipt preserved";return $false}elseif($checkCount -ne 0){Write-Preserve "PATH restore verification failed";return $false}
    } else { Write-Preserve "Unsupported managed value preserved: $Key"; return $false }
    Remove-ReceiptEntry values $Key
    return $true
}

function Invoke-SafeCleanUninstall {
    $failures = 0
    $profilePath = if ($env:DOTFILES_PS_PROFILE_PATH) { $env:DOTFILES_PS_PROFILE_PATH } else { $PROFILE.CurrentUserCurrentHost }
    $item = Get-Item -LiteralPath $script:ReceiptPath -Force -ErrorAction SilentlyContinue
    if (-not $item) { foreach ($path in @($profilePath, (Join-Path $env:USERPROFILE '.bashrc'), (Join-Path $env:USERPROFILE '.inputrc'), (Join-Path $env:USERPROFILE '.bash_profile'))) { if (-not (Remove-DotfilesMarkerBlock $path)) { $failures++ } }; Write-Host 'Dotfiles marker cleanup complete (receipt absent).'; return $failures }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not (Test-SafeParentChain $script:ReceiptPath)) { Write-Preserve "Invalid receipt path preserved: $script:ReceiptPath"; return 1 }
    try {
        $script:Receipt = Get-Content $script:ReceiptPath -Raw | ConvertFrom-Json -AsHashtable
        if ($script:Receipt.schemaVersion -ne 1 -or $script:Receipt.artifacts -isnot [Collections.IDictionary] -or $script:Receipt.packages -isnot [Collections.IDictionary] -or $script:Receipt.values -isnot [Collections.IDictionary] -or
            @($script:Receipt.artifacts.Values | Where-Object { $_.before -isnot [Collections.IDictionary] }).Count -or
            @($script:Receipt.packages.Values | Where-Object { $_.before -isnot [Collections.IDictionary] -or $_.before.present -isnot [bool] }).Count -or
            @($script:Receipt.values.Values | Where-Object { $_.before -isnot [Collections.IDictionary] -or $_.before.present -isnot [bool] }).Count) { throw 'schema' }
    } catch { Write-Preserve "Invalid receipt preserved: $script:ReceiptPath"; return 1 }
    if (-not (Test-ReceiptSchema)) { Write-Preserve "Invalid receipt entry preserved: $script:ReceiptPath"; return 1 }
    foreach ($path in @($profilePath, (Join-Path $env:USERPROFILE '.bashrc'), (Join-Path $env:USERPROFILE '.inputrc'), (Join-Path $env:USERPROFILE '.bash_profile'))) { if (-not (Remove-DotfilesMarkerBlock $path)) { $failures++ } }
    foreach ($key in @($script:Receipt.packages.Keys | Where-Object { $_ -like 'npm:*' })) { if (-not (Remove-ManagedPackage $key)) { $failures++ } }
    foreach ($key in @($script:Receipt.values.Keys | Where-Object { $_ -like 'git:*' })) { if (-not (Remove-ManagedValue $key)) { $failures++ } }
    foreach ($key in @($script:Receipt.packages.Keys | Where-Object { $_ -notlike 'npm:*' })) { if (-not (Remove-ManagedPackage $key)) { $failures++ } }
    foreach ($key in @($script:Receipt.values.Keys | Where-Object { $_ -notlike 'git:*' })) { if (-not (Remove-ManagedValue $key)) { $failures++ } }
    foreach ($key in @($script:Receipt.artifacts.Keys)) { if (-not (Remove-ManagedArtifact $key)) { $failures++ } }
    if ($script:Receipt.artifacts.Count -eq 0 -and $script:Receipt.packages.Count -eq 0 -and $script:Receipt.values.Count -eq 0) { Remove-Item -LiteralPath $script:ReceiptPath -Force }
    if ($failures -eq 0) { Write-Host 'Safe-Clean-Uninstall complete.' }
    return $failures
}

if ($env:DOTFILES_FUNCTIONS_ONLY -ne '1') { exit (Invoke-SafeCleanUninstall) }
