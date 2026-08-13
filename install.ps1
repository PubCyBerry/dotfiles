# Windows dotfiles 설치 진입점 (all-in-one)
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT = $PSScriptRoot
$script:InstallFailures = [Collections.Generic.List[string]]::new()

# =============================================
# 경로 상수
# =============================================
$ClaudeDir     = Join-Path $env:USERPROFILE ".claude"
$CodexDir      = Join-Path $env:USERPROFILE ".codex"
$LocalBin      = Join-Path $env:USERPROFILE ".local\bin"
$NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$NvimBin       = "C:\Program Files\Neovim\bin"
$GitBashPaths  = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)
$GitFileExePaths = @(
    "C:\Program Files\Git\usr\bin\file.exe",
    "C:\Program Files (x86)\Git\usr\bin\file.exe"
)

# =============================================
# 헬퍼 함수
# =============================================
function Get-ManifestLines([string]$Path) {
    Get-Content $Path |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } |
        ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^([^#]+)#') { $Matches[1].Trim() } else { $line }
        }
}

$script:ReceiptPath = if ($env:DOTFILES_RECEIPT_PATH) {
    $env:DOTFILES_RECEIPT_PATH
} else {
    Join-Path $env:LOCALAPPDATA "dotfiles\install-receipt.json"
}

function Add-InstallFailure([string]$Message) {
    Write-Warning $Message
    $script:InstallFailures.Add($Message)
}

function Complete-Install {
    if ($script:InstallFailures.Count -gt 0) {
        Write-Host ""
        Write-Host "==> Installation failed ($($script:InstallFailures.Count))"
        $script:InstallFailures | ForEach-Object { Write-Host "    [!] $_" }
        return $false
    }
    Write-Host ""
    Write-Host "==> Done! Restart your terminal, Codex, and Claude Code to apply all changes."
    return $true
}

function Get-ValidatedPluginRows([string]$Path) {
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($line in (Get-ManifestLines $Path)) {
        $fields = @($line -split '\s+')
        if ($fields.Count -notin 2, 3) { throw "Invalid plugins manifest field count: $line" }
        $scope = if ($fields.Count -eq 3) { $fields[2] } else { 'user' }
        if ($scope -cnotin 'user', 'project', 'local') { throw "Invalid plugin scope: $line" }
        if ($fields[1] -notmatch '^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$') { throw "Invalid plugin ID: $line" }
        $rows.Add([pscustomobject]@{ Market = $fields[0]; Plugin = $fields[1]; Scope = $scope })
    }
    if ($rows.Count -eq 0) { throw "plugins manifest has no entries: $Path" }
    return $rows.ToArray()
}

function Restore-ClaudePlugins([object[]]$Rows) {
    $ok = $true
    foreach ($row in $rows) {
        Write-Host "    Adding marketplace: $($row.Market) (scope: $($row.Scope))..."
        claude plugin marketplace add $row.Market --scope $row.Scope 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed to add marketplace: $($row.Market)"
            $ok = $false
            continue
        }
        Write-Host "    Installing plugin: $($row.Plugin) (scope: $($row.Scope))..."
        claude plugin install $row.Plugin --scope $row.Scope 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed to install plugin: $($row.Plugin)"
            $ok = $false
        }
    }
    return $ok
}

function Restore-ClaudeSkills([string]$Path) {
    $rows = @(Get-ManifestLines $Path)
    if ($rows.Count -eq 0) { throw "skills manifest has no entries: $Path" }
    foreach ($row in $rows) {
        if ($row -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$') {
            throw "Invalid skills manifest row: $row"
        }
    }
    $ok = $true
    foreach ($row in $rows) {
        $repoSlug, $skillName = $row -split '@', 2
        Write-Host "    Adding skill: $skillName from $repoSlug..."
        npx -y skills add $repoSlug --skill $skillName --global --yes --agent claude-code 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Failed: $row"
            $ok = $false
        }
    }
    return $ok
}

function Test-InstallStageSkipped([string]$Name) {
    [Environment]::GetEnvironmentVariable($Name) -eq '1'
}

function Invoke-OptionalInstallStage([string]$Name, [string]$SkipMessage, [scriptblock]$Action) {
    if (Test-InstallStageSkipped $Name) { Write-Host $SkipMessage; return }
    & $Action
}

function Invoke-ClaudeSkillsStage([string]$Path) {
    if (Test-InstallStageSkipped 'SKIP_SKILLS') { Write-Host "    [CI] Skills skipped."; return }
    if (-not (Test-Path $Path)) { Add-InstallFailure "Required manifest missing: manifests\skills.txt"; return }
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) { Add-InstallFailure "npx is required for manifests\skills.txt."; return }
    try {
        if (Restore-ClaudeSkills $Path) { Write-Host "    Skills restored." }
        else { Add-InstallFailure "One or more Claude skills failed." }
    } catch { Add-InstallFailure $_.Exception.Message }
}

function Invoke-ClaudePluginsStage([string]$Path) {
    if (Test-InstallStageSkipped 'SKIP_PLUGINS') { Write-Host "    [CI] Plugins skipped."; return }
    if (-not (Test-Path $Path)) { Add-InstallFailure "Required manifest missing: manifests\plugins.txt"; return }
    try {
        $rows = @(Get-ValidatedPluginRows $Path)
        if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
            Add-InstallFailure "claude is required for manifests\plugins.txt."
        } elseif (Restore-ClaudePlugins $rows) {
            Write-Host "    Plugins restored."
        } else {
            Add-InstallFailure "One or more Claude plugins failed."
        }
    } catch { Add-InstallFailure $_.Exception.Message }
}

function Get-WingetVersion([string]$Text, [string]$Id) {
    foreach ($line in ($Text -split "`r?`n")) {
        $tokens = @($line -split '\s+' | Where-Object { $_ })
        for ($i = 0; $i -lt $tokens.Count - 1; $i++) {
            if ($tokens[$i] -ieq $Id) { return $tokens[$i + 1] }
        }
    }
    return ''
}

function Test-WingetDefinitiveAbsent([int]$Status) {
    ('{0:X8}' -f $Status) -eq '8A150014'
}

function Complete-ManagedWingetPackage(
    [string]$Name, [bool]$BeforePresent, [string]$BeforeVersion,
    [int]$ManagerStatus, [int]$QueryStatus, [string]$AfterVersion,
    [bool]$InstalledCommandPresent = $false
) {
    if ($AfterVersion) {
        if ((-not $BeforePresent) -or $AfterVersion -ne $BeforeVersion) {
            Record-ManagedPackage $Name $BeforePresent $BeforeVersion $AfterVersion
        } else { Cancel-ManagedPackage $Name }
    } elseif ($ManagerStatus -ne 0 -and -not $BeforePresent -and -not $InstalledCommandPresent -and (Test-WingetDefinitiveAbsent $QueryStatus)) {
        Cancel-ManagedPackage $Name
    }
    if ($ManagerStatus -ne 0) { return $ManagerStatus }
    if (-not $AfterVersion) { return 1 }
    return 0
}

function Complete-PendingManagedWingetPackage(
    [string]$Name, [int]$QueryStatus, [string]$AfterVersion,
    [bool]$InstalledCommandPresent = $false
) {
    $entry = $script:Receipt.packages[$Name]
    if (-not $entry.pending) { return $true }
    if ($AfterVersion) {
        if ($entry.pending.previousPresent -and $AfterVersion -eq $entry.pending.previousValue) {
            Cancel-ManagedPackage $Name
        } else {
            Record-ManagedPackage $Name $entry.before.present $entry.before.value $AfterVersion
        }
        return $true
    }
    if (-not $entry.pending.previousPresent -and -not $InstalledCommandPresent -and (Test-WingetDefinitiveAbsent $QueryStatus)) {
        Cancel-ManagedPackage $Name
        return $true
    }
    return $false
}
$script:Receipt = $null
$script:ReceiptReady = $false
$script:FunctionsOnlyMode = $env:DOTFILES_FUNCTIONS_ONLY -eq '1'

function Save-InstallReceipt {
    $dir = Split-Path $script:ReceiptPath
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $tmp = Join-Path $dir ".install-receipt.$([guid]::NewGuid()).tmp"
    try {
        $script:Receipt | ConvertTo-Json -Depth 10 | Out-File $tmp -Encoding utf8 -NoNewline
        $null = Get-Content $tmp -Raw | ConvertFrom-Json -AsHashtable
        Move-Item $tmp $script:ReceiptPath -Force
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Initialize-InstallReceipt {
    $receiptItem = Get-Item -LiteralPath $script:ReceiptPath -Force -ErrorAction SilentlyContinue
    if ($receiptItem -and ($receiptItem -isnot [IO.FileInfo] -or ($receiptItem.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        Write-Warning "Invalid install receipt path type; preserving it: $script:ReceiptPath"
        $script:ReceiptReady = $false
        return $false
    }
    if ($receiptItem) {
        try {
            $receipt = Get-Content $script:ReceiptPath -Raw | ConvertFrom-Json -AsHashtable
            if ($receipt.schemaVersion -ne 1 -or
                $receipt.artifacts -isnot [Collections.IDictionary] -or
                $receipt.packages -isnot [Collections.IDictionary] -or
                $receipt.values -isnot [Collections.IDictionary]) { throw "invalid schema" }
            $script:Receipt = $receipt
            $script:ReceiptReady = $true
            return $true
        } catch {
            Write-Warning "Invalid install receipt; preserving it and skipping managed writes: $script:ReceiptPath"
            $script:ReceiptReady = $false
            return $false
        }
    }
    $script:Receipt = [ordered]@{ schemaVersion = 1; artifacts = [ordered]@{}; packages = [ordered]@{}; values = [ordered]@{} }
    $script:ReceiptReady = $true
    Save-InstallReceipt
    return $true
}

function Get-ManagedPath([string]$Path) {
    [IO.Path]::GetFullPath($Path)
}

function Test-ManagedParentPath([string]$Path) {
    $parent = [IO.Path]::GetDirectoryName((Get-ManagedPath $Path))
    $boundary = if ($env:USERPROFILE) { (Get-ManagedPath $env:USERPROFILE).TrimEnd('\') } else { $null }
    while ($parent) {
        if ($boundary -and $parent.Equals($boundary, [StringComparison]::OrdinalIgnoreCase)) { return $true }
        $item = Get-Item -LiteralPath $parent -Force -ErrorAction SilentlyContinue
        if ($item -and ($item -isnot [IO.DirectoryInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint))) { return $false }
        $next = [IO.Directory]::GetParent($parent)
        if (-not $next) { break }
        $parent = $next.FullName
    }
    return $true
}

function Install-ManagedFile([string]$SourcePath, [string]$DestPath, [ValidateSet('Takeover','Skip')] [string]$Collision = 'Takeover') {
    if (-not $script:ReceiptReady -or -not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { return $false }
    if (-not (Test-ManagedParentPath $DestPath)) {
        Write-Warning "Unsupported destination parent path; preserving: $DestPath"
        return $false
    }
    $key = Get-ManagedPath $DestPath
    $entry = $script:Receipt.artifacts[$key]
    $destItem = Get-Item -LiteralPath $DestPath -Force -ErrorAction SilentlyContinue
    if ($destItem -and ($destItem -isnot [IO.FileInfo] -or ($destItem.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        Write-Warning "Unsupported destination type; preserving: $DestPath"
        return $false
    }
    $exists = $null -ne $destItem
    $beforeHash = if ($exists) { (Get-FileHash -LiteralPath $DestPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null }
    $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($entry) {
        if ($entry.pending -and $exists -and $beforeHash -eq $entry.targetHash) {
            $entry.installedHash = $entry.targetHash
            $entry.pending = $false
            foreach ($field in @('targetHash','previousHash','previousExists')) { $null = $entry.Remove($field) }
            Save-InstallReceipt
            if ($beforeHash -eq $sourceHash) { return $true }
        }
        $expectedHash = if ($entry.pending -and $entry.Contains('previousHash')) { $entry.previousHash } elseif ($entry.pending) { $entry.before.hash } else { $entry.installedHash }
        $expectedExists = if ($entry.pending -and $entry.Contains('previousExists')) { [bool]$entry.previousExists } elseif ($entry.pending) { [bool]$entry.before.exists } else { $true }
        if ($exists -ne $expectedExists -or ($exists -and $beforeHash -ne $expectedHash)) {
            Write-Warning "Managed file changed or missing; preserving: $DestPath"
            return $false
        }
        if (-not $entry.pending -and $beforeHash -eq $sourceHash) { return $true }
    } elseif ($exists -and $Collision -eq 'Skip') {
        Write-Warning "Unowned file collision; preserving: $DestPath"
        return $false
    } elseif ($exists -and $beforeHash -eq $sourceHash) {
        return $true
    } else {
        $backup = $null
        if ($exists) {
            $backup = "$DestPath.dotfiles-backup"
            $n = 0
            while (Get-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue) { $n++; $backup = "$DestPath.dotfiles-backup.$n" }
        }
        $script:Receipt.artifacts[$key] = [ordered]@{
            before = [ordered]@{ exists = $exists; hash = $beforeHash; backup = $backup }
            installedHash = $null
        }
        $entry = $script:Receipt.artifacts[$key]
    }

    $entry.pending = $true
    $entry.targetHash = $sourceHash
    $entry.previousHash = $beforeHash
    $entry.previousExists = $exists
    Save-InstallReceipt

    $backup = $entry.before.backup
    if ($entry.before.exists -and $null -eq $entry.installedHash -and $backup) {
        $backupItem = Get-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue
        if ($backupItem) {
            if ($backupItem -isnot [IO.FileInfo] -or ($backupItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                (Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.before.hash) {
                Write-Warning "Managed backup collision; preserving destination: $DestPath"
                return $false
            }
        } else {
            $backupTmp = "$backup.$([guid]::NewGuid()).tmp"
            try {
                Copy-Item -LiteralPath $DestPath -Destination $backupTmp
                if ((Get-FileHash -LiteralPath $backupTmp -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.before.hash) {
                    Write-Warning "Destination changed before backup; preserving: $DestPath"
                    return $false
                }
                Move-Item -LiteralPath $backupTmp -Destination $backup
            } finally {
                Remove-Item -LiteralPath $backupTmp -Force -ErrorAction SilentlyContinue
            }
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $DestPath) | Out-Null
    $tmp = Join-Path (Split-Path $DestPath) ".$([IO.Path]::GetFileName($DestPath)).$([guid]::NewGuid()).tmp"
    try {
        Copy-Item -LiteralPath $SourcePath -Destination $tmp -Force
        Move-Item -LiteralPath $tmp -Destination $DestPath -Force
        $entry = $script:Receipt.artifacts[$key]
        $entry.installedHash = $sourceHash
        $entry.pending = $false
        foreach ($field in @('targetHash','previousHash','previousExists')) { $null = $entry.Remove($field) }
        Save-InstallReceipt
        return $true
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Test-ReceiptOwnsPrefix([string]$Path) {
    $prefix = (Get-ManagedPath $Path).TrimEnd('\') + '\'
    @($script:Receipt.artifacts.Keys | Where-Object { $_.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
}

function Install-ManagedTree([string]$SourceDir, [string]$DestDir, [ValidateSet('Takeover','Skip')] [string]$Collision = 'Takeover', [bool]$SkipExistingRoot = $false) {
    if (-not $script:ReceiptReady -or -not (Test-Path $SourceDir -PathType Container)) { return $false }
    $destRoot = Get-Item -LiteralPath $DestDir -Force -ErrorAction SilentlyContinue
    if ($destRoot -and ($destRoot -isnot [IO.DirectoryInfo] -or ($destRoot.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        Write-Warning "Unsupported destination tree root; preserving: $DestDir"
        return $false
    }
    if ($SkipExistingRoot -and (Test-Path $DestDir) -and -not (Test-ReceiptOwnsPrefix $DestDir)) {
        Write-Warning "Unowned directory collision; preserving: $DestDir"
        return $false
    }
    $success = $true
    Get-ChildItem $SourceDir -Recurse -File | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($SourceDir, $_.FullName)
        if (-not (Install-ManagedFile $_.FullName (Join-Path $DestDir $relative) $Collision)) { $success = $false }
    }
    return $success
}

function Record-ManagedPackage([string]$Name, [bool]$BeforePresent, [string]$BeforeValue, [string]$InstalledValue, [string]$Prefix = '') {
    if (-not $script:ReceiptReady -or ($BeforePresent -and $BeforeValue -eq $InstalledValue)) { return }
    if (-not $BeforePresent -and -not $InstalledValue) { return }
    if (-not $script:Receipt.packages.Contains($Name)) {
        $script:Receipt.packages[$Name] = [ordered]@{ before = [ordered]@{ present = $BeforePresent; value = $(if ($BeforePresent) { $BeforeValue } else { $null }) }; installed = $InstalledValue }
    } else {
        $script:Receipt.packages[$Name].installed = $InstalledValue
    }
    if ($Prefix) { $script:Receipt.packages[$Name].prefix = $Prefix }
    $null = $script:Receipt.packages[$Name].Remove('pending')
    Save-InstallReceipt
}

function Begin-ManagedPackage([string]$Name, [bool]$BeforePresent, [string]$BeforeValue, [string]$Prefix = '') {
    if (-not $script:ReceiptReady) { return $false }
    $existing = $script:Receipt.packages[$Name]
    if ($Prefix -and $existing -and ((-not $existing.prefix) -or $existing.prefix -cne $Prefix)) {
        Write-Warning "npm prefix changed or missing in receipt; preserving package ownership: $Name"
        return $false
    }
    if ($existing.pending -and ($BeforePresent -ne $existing.pending.previousPresent -or ($BeforePresent -and $BeforeValue -ne $existing.pending.previousValue))) {
        Record-ManagedPackage $Name $existing.before.present $existing.before.value $BeforeValue
    }
    $isNew = -not $script:Receipt.packages.Contains($Name)
    if ($isNew) {
        $script:Receipt.packages[$Name] = [ordered]@{
            before = [ordered]@{ present = $BeforePresent; value = $(if ($BeforePresent) { $BeforeValue } else { $null }) }
            installed = $null
        }
    }
    $script:Receipt.packages[$Name].pending = [ordered]@{ previousPresent = $BeforePresent; previousValue = $(if ($BeforePresent) { $BeforeValue } else { $null }); newEntry = $isNew }
    if ($Prefix) { $script:Receipt.packages[$Name].prefix = $Prefix }
    Save-InstallReceipt
    return $true
}

function Cancel-ManagedPackage([string]$Name) {
    if (-not $script:ReceiptReady -or -not $script:Receipt.packages.Contains($Name)) { return }
    if ($script:Receipt.packages[$Name].pending.newEntry -and $null -eq $script:Receipt.packages[$Name].installed) {
        $script:Receipt.packages.Remove($Name)
    } else {
        $null = $script:Receipt.packages[$Name].Remove('pending')
    }
    Save-InstallReceipt
}

function Test-SensitiveManagedValue([string]$Name) {
    $Name -ine 'git:credential.credentialStore' -and $Name -match '(?i)(token|secret|password|credential)'
}

function Record-ManagedValue([string]$Name, [bool]$BeforePresent, [string]$BeforeValue, [string]$InstalledValue, [bool]$StoreBeforeValue = $true) {
    if (-not $script:ReceiptReady -or (Test-SensitiveManagedValue $Name)) { return }
    if (-not $script:Receipt.values.Contains($Name)) {
        $before = [ordered]@{ present = $BeforePresent }
        if ($StoreBeforeValue) { $before.value = $BeforeValue }
        $script:Receipt.values[$Name] = [ordered]@{ before = $before; installed = $InstalledValue }
    } else {
        $script:Receipt.values[$Name].installed = $InstalledValue
    }
    $null = $script:Receipt.values[$Name].Remove('pending')
    Save-InstallReceipt
}

function Begin-ManagedValue([string]$Name, [bool]$BeforePresent, [string]$BeforeValue, [string]$TargetValue, [bool]$StoreBeforeValue = $true) {
    if (-not $script:ReceiptReady -or (Test-SensitiveManagedValue $Name)) { return $false }
    if (-not $script:Receipt.values.Contains($Name)) {
        $before = [ordered]@{ present = $BeforePresent }
        if ($StoreBeforeValue) { $before.value = $BeforeValue }
        $script:Receipt.values[$Name] = [ordered]@{ before = $before; installed = $null }
    }
    $pending = [ordered]@{ previousPresent = $BeforePresent; target = $TargetValue }
    if ($StoreBeforeValue) { $pending.previousValue = $BeforeValue }
    $script:Receipt.values[$Name].pending = $pending
    Save-InstallReceipt
    return $true
}

function Set-ManagedGitValue([string]$Name, [string]$Value) {
    if (-not $script:ReceiptReady) { return }
    $before = git config --global --get $Name 2>$null
    $present = $LASTEXITCODE -eq 0
    $receiptKey = "git:$Name"
    $entry = $script:Receipt.values[$receiptKey]
    if ($entry) {
        if ($entry.pending) {
            if ($present -and $before -ceq $entry.pending.target) {
                Record-ManagedValue $receiptKey $entry.before.present $entry.before.value $entry.pending.target
                return
            }
            if ($present -ne $entry.pending.previousPresent -or ($present -and $before -cne $entry.pending.previousValue)) {
                Write-Warning "Managed value changed; preserving: $Name"
                return
            }
        } elseif (($present -ne ($entry.installed -ne $null)) -or ($present -and $before -cne $entry.installed)) {
            Write-Warning "Managed value changed; preserving: $Name"
            return
        }
    }
    if (-not $present -or $before -cne $Value) {
        if (-not (Begin-ManagedValue $receiptKey $present $before $Value)) { return }
        git config --global $Name $Value
        if ($LASTEXITCODE -eq 0) { Record-ManagedValue $receiptKey $present $before $Value }
    }
}

function Add-ToUserPath([string]$Dir) {
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $present = @($userPath -split ';' | Where-Object { $_ }) -contains $Dir
    $pathKey = "env:PATH:$Dir"
    $pathEntry = if ($script:ReceiptReady) { $script:Receipt.values[$pathKey] } else { $null }
    if ($present -and $pathEntry.pending) {
        Record-ManagedValue $pathKey $pathEntry.before.present $null "present" $false
        return $false
    }
    if (-not $present) {
        if ($pathEntry -and -not $pathEntry.pending) {
            Write-Warning "Managed PATH entry was removed; preserving user choice: $Dir"
            return $false
        }
        if (-not (Begin-ManagedValue $pathKey $false $null "present" $false)) { return $false }
        $newUserPath = if ($userPath) { "$userPath;$Dir" } else { $Dir }
        [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
        $env:PATH = "$env:PATH;$Dir"
        Record-ManagedValue $pathKey $false $null "present" $false
        return $true
    }
    return $false
}

function Set-ProfileBlock([string]$FilePath, [string]$Content) {
    $begin = "# ===== dotfiles-begin ====="
    $end   = "# ===== dotfiles-end ====="
    $block = "$begin`n$Content`n$end"
    if (-not (Test-Path $FilePath)) { New-Item -ItemType File -Path $FilePath | Out-Null }

    $existing = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $existing) { $existing = "" }

    $beginPattern = "(?m)^" + [regex]::Escape($begin) + "(?=\r?$)"
    $endPattern   = "(?m)^" + [regex]::Escape($end) + "(?=\r?$)"
    $beginMatches = [regex]::Matches($existing, $beginPattern)
    $endMatches   = [regex]::Matches($existing, $endPattern)
    $beginCount   = [regex]::Matches($existing, [regex]::Escape($begin)).Count
    $endCount     = [regex]::Matches($existing, [regex]::Escape($end)).Count

    if ($beginCount -eq 0 -and $endCount -eq 0) {
        $newContent = "$existing`n$block"
        Write-Host "    Appended dotfiles block to $FilePath"
    } elseif ($beginCount -eq 1 -and $endCount -eq 1 -and
              $beginMatches.Count -eq 1 -and $endMatches.Count -eq 1 -and
              $beginMatches[0].Index -lt $endMatches[0].Index) {
        $afterEnd = $endMatches[0].Index + $endMatches[0].Length
        $newContent = $existing.Substring(0, $beginMatches[0].Index) +
                      $block + $existing.Substring($afterEnd)
        Write-Host "    Updated dotfiles block in $FilePath"
    } else {
        Write-Warning "Invalid dotfiles marker state in $FilePath; keeping the file unchanged."
        throw "Profile marker validation failed: $FilePath"
    }
    $newContent | Out-File -FilePath $FilePath -Encoding utf8 -NoNewline
}

function Merge-GitConfig([string]$FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Host "    [!] $FilePath not found, skipping."
        return
    }
    # 기존 global git 설정을 해시테이블로 로드 (중복 방지용)
    $existingConfig = @{}
    git config --global --list 2>$null | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $existingConfig[$Matches[1]] = $Matches[2] }
    }
    $currentSection = $null
    foreach ($line in (Get-Content $FilePath)) {
        $trimmed = $line.Trim()
        # [section] 헤더 감지
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
        # 주석·빈 줄 제외, key = value 항목만 처리
        } elseif ($trimmed -and -not $trimmed.StartsWith('#') -and $currentSection) {
            if ($trimmed -match '^(\S+)\s*=\s*(.*)$') {
                $key   = $Matches[1]
                $value = $Matches[2].Trim()
                # 이미 설정된 항목은 건너뜀 (사용자 커스텀 설정 보존)
                if (-not $existingConfig.ContainsKey("$currentSection.$key")) {
                    Set-ManagedGitValue "$currentSection.$key" $value
                    $installed = git config --global --get "$currentSection.$key" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $installed -ceq $value) {
                        Write-Host "    Added [$currentSection] $key = $value"
                    }
                } else {
                    Write-Host "    Skip  [$currentSection] $key (already set)"
                }
            }
        }
    }
    Write-Host "    gitconfig merged."
}

function Merge-CodexConfig([string]$SourcePath, [string]$DestPath) {
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [!] $SourcePath not found, skipping."
        return
    }
    if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
        Write-Host "    [!] yq not found, keeping existing config.toml"
        return
    }
    & yq -p=toml -o=json '.' $SourcePath 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] source config.toml is invalid, keeping existing config.toml"
        return
    }
    if (-not (Test-Path $DestPath)) {
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) { Copy-Item $SourcePath $DestPath -Force; Write-Host "    Copied config.toml" }
        elseif (Install-ManagedFile $SourcePath $DestPath Takeover) { Write-Host "    Copied config.toml" }
        return
    }
    & yq -p=toml -o=json '.' $DestPath 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [!] existing config.toml is invalid, keeping it unchanged"
        return
    }

    $tmp = New-TemporaryFile
    try {
        $merged = @(& yq eval-all -p=toml -o=toml 'select(fileIndex == 0) * select(fileIndex == 1)' $SourcePath $DestPath 2>$null)
        if ($LASTEXITCODE -ne 0 -or $merged.Count -eq 0) {
            Write-Host "    [!] config.toml merge failed, keeping existing config.toml"
            return
        }
        ($merged -join "`n") | Out-File $tmp -Encoding utf8 -NoNewline
        & yq -p=toml -o=json '.' $tmp 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] merged config.toml is invalid, keeping existing config.toml"
            return
        }
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) {
            Move-Item $tmp $DestPath -Force
            Write-Host "    Merged config.toml (existing values preserved)"
        } elseif (Install-ManagedFile $tmp $DestPath Takeover) {
            Write-Host "    Merged config.toml (existing values preserved)"
        }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Merge-JsonRegistry([string]$SourcePath, [string]$DestPath) {
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [!] $SourcePath not found, skipping."
        return
    }
    if (-not (Test-Path $DestPath)) {
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) { Copy-Item $SourcePath $DestPath -Force; Write-Host "    Copied $(Split-Path $DestPath -Leaf)" }
        elseif (Install-ManagedFile $SourcePath $DestPath Takeover) { Write-Host "    Copied $(Split-Path $DestPath -Leaf)" }
        return
    }
    if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host "    [!] jq not found, keeping existing $(Split-Path $DestPath -Leaf)"
        return
    }
    $filterPath = Join-Path $ROOT "scripts\merge-json-registry.jq"
    if (-not (Test-Path $filterPath)) {
        Write-Host "    [!] merge-json-registry.jq not found, keeping existing $(Split-Path $DestPath -Leaf)"
        return
    }

    $tmp = New-TemporaryFile
    try {
        & jq -s -f $filterPath $DestPath $SourcePath 2>$null | Out-File $tmp -Encoding utf8 -NoNewline
        if ($LASTEXITCODE -ne 0 -or (Get-Item $tmp).Length -eq 0) {
            Write-Host "    [!] jq merge failed, keeping existing $(Split-Path $DestPath -Leaf)"
            return
        }
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) {
            Move-Item $tmp $DestPath -Force
            Write-Host "    Merged $(Split-Path $DestPath -Leaf)"
        } elseif (Install-ManagedFile $tmp $DestPath Takeover) {
            Write-Host "    Merged $(Split-Path $DestPath -Leaf)"
        }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-FnmPruneIfRequested {
    if ($env:DOTFILES_PRUNE_NODE_VERSIONS -ne "1") { return }
    $activeVer = (fnm current 2>$null)
    if ($activeVer -notmatch '^v\d') {
        Write-Host "    [!] fnm current를 읽지 못해 구버전 정리를 건너뜀."
        return
    }
    $installedVers = @(fnm list 2>$null | ForEach-Object {
        if ($_ -match '(v\d+\.\d+\.\d+)') { $Matches[1] }
    } | Select-Object -Unique)
    foreach ($ver in ($installedVers | Where-Object { $_ -ne $activeVer })) {
        fnm uninstall $ver 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Removed old Node: $ver"
        } else {
            Write-Host "    [!] Node $ver 삭제 실패 — 해당 버전을 쓰는 셸이 열려 있는지 확인."
        }
    }
}

function Update-FnmStatusLine([string]$SettingsPath, [string]$FnmRoot, [string]$NodeVersion) {
    $nodeExe = Join-Path $FnmRoot "node-versions\$NodeVersion\installation\node.exe"
    if (-not (Test-Path $SettingsPath -PathType Leaf) -or
        -not (Test-Path $nodeExe -PathType Leaf)) { return $false }
    try {
        $settings = Get-Content $SettingsPath -Raw | ConvertFrom-Json
        $cmd = $settings.statusLine.command
        if (-not ($cmd -is [string])) { return $false }
        $rootPattern = ((($FnmRoot.TrimEnd('\', '/')) -split '[\\/]') |
            ForEach-Object { [regex]::Escape($_) }) -join '[\\/]'
        $nodePattern = "$rootPattern[\\/]node-versions[\\/]v\d+\.\d+\.\d+[\\/]installation(?:[\\/]bin)?[\\/]node(?:\.exe)?"
        $match = [regex]::Match($cmd, $nodePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $match.Success) { return $false }
        $newCmd = $cmd.Remove($match.Index, $match.Length).Insert($match.Index, $nodeExe)
        if ($newCmd -ceq $cmd) { return $false }

        $settings.statusLine.command = $newCmd
        $tmp = Join-Path (Split-Path $SettingsPath) ".settings.$([guid]::NewGuid()).tmp"
        try {
            $settings | ConvertTo-Json -Depth 10 | Out-File $tmp -Encoding utf8 -NoNewline
            if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) {
                Move-Item $tmp $SettingsPath -Force
                Write-Host "    Patched statusLine node path: $($match.Value) -> $nodeExe"
                return $true
            }
            if (Install-ManagedFile $tmp $SettingsPath Takeover) {
                Write-Host "    Patched statusLine node path: $($match.Value) -> $nodeExe"
                return $true
            }
            return $false
        } finally {
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "    [!] statusLine node path update failed; keeping settings.json."
        return $false
    }
}

if ($env:DOTFILES_FUNCTIONS_ONLY -eq "1") { return }

if (-not (Initialize-InstallReceipt)) { throw "Install receipt validation failed." }

Write-Host "==> Windows dotfiles setup starting..."
Write-Host "    Source: $ROOT"

# =============================================
# 1. winget 패키지 설치 (manifests/winget.txt)
# =============================================
function Invoke-WingetPackagesStage {
Write-Host ""
Write-Host "==> Installing packages via winget..."
$wingetFile = Join-Path $ROOT "manifests\winget.txt"
if (Test-Path $wingetFile) {
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        # 사전 점검: 실행 중인 프로세스가 대상 파일을 잠그면 설치 관리자가 실패한다.
        #   Git.Git(Inno Setup) — bash/ssh가 살아 있으면 "process(es) use Git for Windows"
        #                         메시지 박스가 억제된 채 Cancel 처리되어 exit 1 → 0x8A150006
        #   marlocarlo.psmux(portable) — tmux.exe 교체 시 "Access is denied" → 0x8A150052
        # 설치 전에 알려야 사용자가 세션을 정리하고 재실행할 수 있다.
        $LockBlockers = @{
            'Git.Git'          = @('bash', 'sh', 'ssh', 'git')
            'marlocarlo.psmux' = @('tmux')
        }
        foreach ($entry in $LockBlockers.GetEnumerator()) {
            $running = @($entry.Value |
                ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } |
                Group-Object ProcessName |
                ForEach-Object { "$($_.Name) x$($_.Count)" })
            if ($running.Count -gt 0) {
                Write-Host "    [warn] $($entry.Key): 파일을 잠그는 프로세스 실행 중 — $($running -join ', ')"
                Write-Host "           업그레이드 실패 시 해당 프로세스 종료 후 재실행 필요."
            }
        }

        $WingetLogDir = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"

        $packageStates = Get-ManifestLines $wingetFile | ForEach-Object {
            $listOut = (winget list --id $_ --exact --accept-source-agreements 2>&1 | Out-String)
            $present = $LASTEXITCODE -eq 0
            $version = if ($present) { Get-WingetVersion $listOut $_ } else { '' }
            if (-not (Begin-ManagedPackage "winget:$_" $present $version)) { throw "winget receipt journal failed: $_" }
            [pscustomobject]@{ Package = $_; BeforePresent = $present; BeforeVersion = $version }
        }

        $results = $packageStates | ForEach-Object -Parallel {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $package = $_.Package
            $logDir  = $using:WingetLogDir

            # winget 종료 코드 → 원인. $LASTEXITCODE는 부호 있는 int라 두 자리 보수 hex로 비교한다.
            $codes = @{
                '8A15002B' = '최신 버전 — 적용할 업데이트 없음'
                '8A150006' = '설치 관리자가 실패 코드 반환 — 대상 파일 사용 중이거나 권한 부족'
                '8A150011' = '적용 가능한 installer 없음 — 아키텍처/스코프 불일치'
                '8A150014' = '일치하는 패키지 없음 — --exact는 ID 대소문자를 구분한다'
                '8A150044' = '패키지 사용 계약 미동의'
                '8A150052' = 'portable 설치 실패 — 교체 대상 exe가 실행 중'
                '8A150056' = '설치 위치 사용 불가'
            }

            # `winget list` 출력에서 설치 버전 추출.
            # 헤더가 로케일별로 다르므로 컬럼명 대신 ID 토큰 다음 토큰을 읽는다.
            #   예: "yq   MikeFarah.yq 4.53.3 winget" → 4.53.3
            $parseVer = {
                param($text, $id)
                foreach ($line in ($text -split "`r?`n")) {
                    $t = @($line -split '\s+' | Where-Object { $_ })
                    for ($i = 0; $i -lt $t.Count - 1; $i++) {
                        if ($t[$i] -ieq $id) { return $t[$i + 1] }
                    }
                }
                return ''
            }

            $isInstalled = $_.BeforePresent
            $beforeVer = $_.BeforeVersion
            $afterVer = ''

            if (-not $isInstalled) {
                $verb = 'install'
                $out  = (winget install --id $package --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
            } else {
                $verb = 'upgrade'
                $out  = (winget upgrade --id $package --exact --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String)
            }
            $code = $LASTEXITCODE
            $hex  = '{0:X8}' -f $code
            $why  = if ($codes.ContainsKey($hex)) { " — $($codes[$hex])" } else { '' }
            $pad  = $package.PadRight(28)
            $afterOut = (winget list --id $package --exact --accept-source-agreements 2>&1 | Out-String)
            $afterCode = $LASTEXITCODE
            $afterVer = & $parseVer $afterOut $package

            if ($code -eq 0 -and -not $afterVer) {
                $afterHex = '{0:X8}' -f $afterCode
                Write-Host "    [!] $verb identity check failed: $pad 0x$afterHex"
                $status = 'failed'
                $hex = $afterHex
            } elseif ($code -eq 0) {
                if ($verb -eq 'install') {
                    Write-Host "    [install]  $pad $afterVer"
                    $status = 'install'
                } else {
                    $delta = if ($beforeVer -and $afterVer -and $beforeVer -ne $afterVer) { "$beforeVer -> $afterVer" } else { $afterVer }
                    Write-Host "    [upgrade]  $pad $delta"
                    $status = 'upgrade'
                }
            } elseif ($hex -eq '8A15002B') {
                Write-Host "    [current]  $pad $beforeVer"
                $status = 'current'
            } else {
                Write-Host "    [!] $verb failed: $pad 0x$hex$why"
                # winget이 출력한 마지막 실질 메시지 — 코드만으로는 안 보이는 실패 사유가 여기 있다.
                $tail = @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Last 2)
                foreach ($t in $tail) { Write-Host "           winget: $t" }
                Write-Host "           상세 로그: $logDir"
                $status = 'failed'
            }

            [pscustomobject]@{
                Package = $package; Status = $status; Code = $hex
                BeforePresent = $isInstalled; BeforeVersion = $beforeVer; AfterVersion = $afterVer
            }
        } -ThrottleLimit 4

        # 요약 — 실패 목록을 마지막에 다시 모아 스크롤 위로 사라지지 않게 한다.
        $byStatus = $results | Group-Object Status | ForEach-Object { "$($_.Name) $($_.Count)" }
        Write-Host "    ---- winget 요약: $($byStatus -join ' / ')"
        $failed = @($results | Where-Object { $_.Status -eq 'failed' })
        foreach ($f in $failed) {
            Write-Host "    [!] 실패: $($f.Package) (0x$($f.Code))"
            Add-InstallFailure "winget package failed: $($f.Package) (0x$($f.Code))"
        }
        foreach ($r in $results) {
            if ($r.AfterVersion -and ((-not $r.BeforePresent) -or $r.BeforeVersion -ne $r.AfterVersion)) {
                Record-ManagedPackage "winget:$($r.Package)" $r.BeforePresent $r.BeforeVersion $r.AfterVersion
            } else {
                Cancel-ManagedPackage "winget:$($r.Package)"
            }
        }
    } else {
        Add-InstallFailure "winget is required for manifests\winget.txt."
    }
} else {
    Add-InstallFailure "Required manifest missing: manifests\winget.txt"
}
}
Invoke-OptionalInstallStage 'SKIP_PACKAGES' "==> [CI] Skipping winget packages (SKIP_PACKAGES=1)" { Invoke-WingetPackagesStage }

# =============================================
# 1-1. gitconfig 설정 병합 (config/git/gitconfig)
# =============================================
Write-Host ""
Write-Host "==> Merging git config..."
Merge-GitConfig (Join-Path $ROOT "config\git\gitconfig")

# Windows 전용 git 설정 주입 (공유 gitconfig는 OS-중립)
Set-ManagedGitValue core.autocrlf true
Set-ManagedGitValue core.fileMode false

# =============================================
# 1-2. tmux 설정 복사
# =============================================
Write-Host ""
$tmuxSrc = Join-Path $ROOT "config\tmux\tmux.windows.conf"
if (Test-Path $tmuxSrc) {
    if (Install-ManagedFile $tmuxSrc (Join-Path $env:USERPROFILE ".tmux.conf") Takeover) { Write-Host "    Copied .tmux.conf (tmux default shell: pwsh)" }
}

# =============================================
# 1-3. YAZI_FILE_ONE 환경 변수 설정 (Git file.exe)
# =============================================
Invoke-OptionalInstallStage 'SKIP_PACKAGES' "==> [CI] Skipping package-dependent YAZI_FILE_ONE (SKIP_PACKAGES=1)" {
Write-Host ""
Write-Host "==> Setting YAZI_FILE_ONE environment variable..."
$gitFileExe = $GitFileExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($gitFileExe) {
    $beforeYazi = [System.Environment]::GetEnvironmentVariable("YAZI_FILE_ONE", "User")
    $yaziEntry = if ($script:ReceiptReady) { $script:Receipt.values['env:YAZI_FILE_ONE'] } else { $null }
    if (-not $script:ReceiptReady) {
        Write-Warning "Receipt unavailable; preserving YAZI_FILE_ONE."
    } elseif ($yaziEntry.pending -and $beforeYazi -ceq $yaziEntry.pending.target) {
        Record-ManagedValue "env:YAZI_FILE_ONE" $yaziEntry.before.present $yaziEntry.before.value $yaziEntry.pending.target
        $env:YAZI_FILE_ONE = $beforeYazi
        Write-Host "    YAZI_FILE_ONE = $beforeYazi"
    } elseif ($yaziEntry.pending -and $beforeYazi -cne $yaziEntry.pending.previousValue) {
        Write-Warning "Managed YAZI_FILE_ONE changed; preserving user value."
    } elseif ($yaziEntry -and -not $yaziEntry.pending -and $beforeYazi -cne $yaziEntry.installed) {
        Write-Warning "Managed YAZI_FILE_ONE changed; preserving user value."
    } else {
        if ($beforeYazi -cne $gitFileExe -and -not (Begin-ManagedValue "env:YAZI_FILE_ONE" ($null -ne $beforeYazi) $beforeYazi $gitFileExe)) {
            Write-Warning "Could not journal YAZI_FILE_ONE; preserving user value."
            throw "YAZI_FILE_ONE receipt journal failed."
        }
        [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $gitFileExe, "User")
        $env:YAZI_FILE_ONE = $gitFileExe
        if ($beforeYazi -cne $gitFileExe) { Record-ManagedValue "env:YAZI_FILE_ONE" ($null -ne $beforeYazi) $beforeYazi $gitFileExe }
        Write-Host "    YAZI_FILE_ONE = $gitFileExe"
    }
} else {
    Write-Host "    [!] Git file.exe not found. Install Git for Windows first."
    Write-Host "        winget install --id Git.Git"
}
}

# =============================================
# 1-4. yazi 설정 파일 배포
# =============================================
Write-Host ""
Write-Host "==> Deploying yazi config..."
$yaziConfigSrc = Join-Path $ROOT "config\yazi"
$yaziConfigDst = Join-Path $env:APPDATA "yazi\config"
if (Test-Path $yaziConfigSrc) {
    if (Install-ManagedTree $yaziConfigSrc $yaziConfigDst Takeover) { Write-Host "    yazi config deployed to $yaziConfigDst" }
} else {
    Write-Host "    [!] config\yazi not found, skipping."
}

# =============================================
# 1-5. Neovim PATH 환경변수 설정
# =============================================
Invoke-OptionalInstallStage 'SKIP_PACKAGES' "==> [CI] Skipping package-dependent User PATH (SKIP_PACKAGES=1)" {
Write-Host ""
Write-Host "==> Adding Neovim to PATH..."
if (Test-Path $NvimBin) {
    if (Add-ToUserPath $NvimBin) { Write-Host "    Added Neovim to PATH: $NvimBin" }
    elseif (@([System.Environment]::GetEnvironmentVariable("PATH", "User") -split ';') -contains $NvimBin) { Write-Host "    Neovim already in PATH." }
} else {
    Write-Host "    [!] Neovim not found at $NvimBin. Install via winget: Neovim.Neovim"
}
}

# =============================================
# 1-6. lazy.nvim Structured Setup
# =============================================
Write-Host ""
Write-Host "==> Setting up lazy.nvim (Neovim Plugin Manager - Structured Setup)..."
$nvimSrc = Join-Path $ROOT "config\nvim"

if (-not (Test-Path (Join-Path $nvimSrc "init.lua"))) {
    Write-Host "    [!] config\nvim\init.lua not found, skipping."
} else {
    if (Install-ManagedTree $nvimSrc $NvimConfigDir Takeover) {
        Write-Host "    lazy.nvim config deployed to $NvimConfigDir"
        Write-Host "    Run nvim to auto-install lazy.nvim on first launch."
    }
}

# =============================================
# 2. Node.js LTS 설치 (fnm)
# =============================================
function Invoke-NodePackagesStage {
Write-Host ""
Write-Host "==> Installing Node.js LTS..."
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    $fnmOk = $true
    $fnmEnv = fnm env --shell powershell | Out-String
    if ($LASTEXITCODE -ne 0) { Add-InstallFailure "fnm env failed."; $fnmOk = $false }
    else { $fnmEnv | Invoke-Expression }
    fnm install --lts
    if ($LASTEXITCODE -ne 0) { Add-InstallFailure "fnm install --lts failed."; $fnmOk = $false }
    fnm default lts-latest
    if ($LASTEXITCODE -ne 0) { Add-InstallFailure "fnm default lts-latest failed."; $fnmOk = $false }
    fnm use lts-latest
    if ($LASTEXITCODE -ne 0) { Add-InstallFailure "fnm use lts-latest failed."; $fnmOk = $false }
    if ($fnmOk) { Write-Host "    Node.js LTS installed." }

    Invoke-FnmPruneIfRequested

    # fnm aliases\default → User PATH 영구 등록 (MCP 서버 등 비쉘 프로세스에서 npx 접근 가능)
    $fnmRoot = if ($env:FNM_DIR) { $env:FNM_DIR } else { Join-Path $env:APPDATA "fnm" }
    $fnmDefaultPath = Join-Path $fnmRoot "aliases\default"
    if (Test-Path (Join-Path $fnmDefaultPath "node.exe") -PathType Leaf) {
        if (Add-ToUserPath $fnmDefaultPath) { Write-Host "    Added fnm aliases\default to User PATH: $fnmDefaultPath" }
        elseif (@([System.Environment]::GetEnvironmentVariable("PATH", "User") -split ';') -contains $fnmDefaultPath) { Write-Host "    fnm aliases\default already in User PATH." }
    } else {
        Write-Host "    [!] fnm aliases\default\node.exe not found. Run: fnm default lts-latest"
    }

    # statusLine.command의 fnm node 버전 경로 갱신 (버전 업 시 깨지는 절대 경로 수정)
    $nodeVersionOutput = node --version 2>$null
    $nodeVer = if ($nodeVersionOutput -match '^v\d+\.\d+\.\d+$') { $nodeVersionOutput } else { $null }
    $settingsPath = Join-Path $ClaudeDir "settings.json"
    if ($nodeVer) { $null = Update-FnmStatusLine $settingsPath $fnmRoot $nodeVer }
} else {
    Add-InstallFailure "fnm is required to install Node.js LTS."
}

# =============================================
# 2-1. npm 전역 패키지 설치 (manifests/npm-global.txt)
# =============================================
Write-Host ""
Write-Host "==> Installing global npm packages..."
$npmFile = Join-Path $ROOT "manifests\npm-global.txt"
if ((Test-Path $npmFile) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    $npmRoot = npm root -g 2>$null
    $npmRootStatus = $LASTEXITCODE
    $npmPrefix = npm prefix -g 2>$null
    $npmPrefixStatus = $LASTEXITCODE
    $jqPath = (Get-Command jq -ErrorAction SilentlyContinue).Source
    if ($npmRootStatus -ne 0 -or $npmPrefixStatus -ne 0 -or -not $npmRoot -or -not $npmPrefix) {
        Add-InstallFailure "npm global root/prefix query failed."
        $npmResults = @()
    } elseif (-not $jqPath) {
        Add-InstallFailure "jq is required to record npm package provenance."
        $npmResults = @()
    } else {
        $npmStates = Get-ManifestLines $npmFile | ForEach-Object {
            $packageJson = Join-Path $npmRoot "$_\package.json"
            $beforeVersion = if (Test-Path $packageJson) { (& $jqPath -r '.version // empty' $packageJson 2>$null) } else { '' }
            if (-not (Begin-ManagedPackage "npm:$_" ([bool]$beforeVersion) $beforeVersion $npmPrefix)) { throw "npm receipt journal failed: $_" }
            [pscustomobject]@{ Package = $_; BeforeVersion = $beforeVersion }
        }
        $npmResults = $npmStates | ForEach-Object -Parallel {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $package = $_.Package
        $packageJson = Join-Path $using:npmRoot "$package\package.json"
        $beforeVersion = $_.BeforeVersion
        npm install -g $package 2>&1 | Out-Null
        $success = $LASTEXITCODE -eq 0
        $afterVersion = if (Test-Path $packageJson) { (& $using:jqPath -r '.version // empty' $packageJson 2>$null) } else { '' }
        if ($success) {
            Write-Host "    Installed $package"
            [pscustomobject]@{ Package = $package; Success = $true; BeforeVersion = $beforeVersion; AfterVersion = $afterVersion }
        } else {
            Write-Host "    [!] Failed: $package (exit: $LASTEXITCODE)"
            [pscustomobject]@{ Package = $package; Success = $false; BeforeVersion = $beforeVersion; AfterVersion = $afterVersion }
        }
        } -ThrottleLimit 4
    }
    foreach ($r in $npmResults) {
        if (-not $r.Success) { Add-InstallFailure "npm package failed: $($r.Package)" }
        if ($r.AfterVersion -and $r.BeforeVersion -ne $r.AfterVersion) {
            Record-ManagedPackage "npm:$($r.Package)" ([bool]$r.BeforeVersion) $r.BeforeVersion $r.AfterVersion $npmPrefix
        } else {
            Cancel-ManagedPackage "npm:$($r.Package)"
        }
    }
} elseif (-not (Test-Path $npmFile)) {
    Add-InstallFailure "Required manifest missing: manifests\npm-global.txt"
} else {
    Add-InstallFailure "npm is required for manifests\npm-global.txt."
}
}
Invoke-OptionalInstallStage 'SKIP_PACKAGES' "==> [CI] Skipping Node.js and npm packages (SKIP_PACKAGES=1)" { Invoke-NodePackagesStage }

# =============================================
# 2-2. Codex 설정 배포 (config/codex/ + config/agents/global.md → ~/.codex/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Codex config..."
New-Item -ItemType Directory -Force -Path $CodexDir | Out-Null

Merge-CodexConfig `
    (Join-Path $ROOT "config\codex\config.toml") `
    (Join-Path $CodexDir "config.toml")

$agentsGlobalSrc = Join-Path $ROOT "config\agents\global.md"
$rolesSrc = Join-Path $ROOT "config\agents\roles"
if (Test-Path $agentsGlobalSrc) {
    if (Install-ManagedFile $agentsGlobalSrc (Join-Path $CodexDir "AGENTS.md") Takeover) { Write-Host "    Copied global agent instructions to AGENTS.md" }
} else {
    Write-Host "    [!] config\agents\global.md not found"
}

# 공용 role: config\agents\roles\<name>\ = codex.toml + body.md 조립
# → ~\.codex\agents\<name>.toml (Codex subagent. body.md는 developer_instructions 값이 된다)
if (Test-Path $rolesSrc) {
    $codexAgentsDst = Join-Path $CodexDir "agents"
    New-Item -ItemType Directory -Force -Path $codexAgentsDst | Out-Null
    Get-ChildItem $rolesSrc -Directory | ForEach-Object {
        $meta = Join-Path $_.FullName "codex.toml"
        $body = Join-Path $_.FullName "body.md"
        if ((Test-Path $meta) -and (Test-Path $body)) {
            $metaText = (Get-Content $meta -Raw)
            $bodyText = (Get-Content $body -Raw)
            if (-not $metaText.EndsWith("`n")) { $metaText += "`n" }
            if (-not $bodyText.EndsWith("`n")) { $bodyText += "`n" }
            # TOML literal multi-line string(''') — 이스케이프 해석이 없어 body를 그대로 담는다
            $content = $metaText + "developer_instructions = '''`n" + $bodyText + "'''`n"
            $tmpAgent = New-TemporaryFile
            try {
                Set-Content -Path $tmpAgent -Value $content -NoNewline -Encoding utf8
                if (Install-ManagedFile $tmpAgent (Join-Path $codexAgentsDst "$($_.Name).toml") Skip) {
                    Write-Host "    Deployed agent: $($_.Name)"
                }
            } finally { Remove-Item $tmpAgent -Force -ErrorAction SilentlyContinue }
        }
    }
}

# hooks.json: 사용자 hook 보존 + dotfiles 관리 command upsert
$codexHooksJsonSrc = Join-Path $ROOT "config\codex\hooks.json"
if (Test-Path $codexHooksJsonSrc) {
    Merge-JsonRegistry $codexHooksJsonSrc (Join-Path $CodexDir "hooks.json")
} else {
    Write-Host "    [!] config\codex\hooks.json not found"
}

# hooks/temporal-context.sh 배포
$codexHooksDir = Join-Path $CodexDir "hooks"
$temporalSrc   = Join-Path $ROOT "config\codex\hooks\temporal-context.sh"
if (Test-Path $temporalSrc) {
    if (Install-ManagedFile $temporalSrc (Join-Path $codexHooksDir "temporal-context.sh") Skip) {
        Write-Host "    Copied temporal-context.sh to ~/.codex/hooks/"
    }
} else {
    Write-Host "    [!] config\codex\hooks\temporal-context.sh not found, skipping."
}

# =============================================
# 3. Claude Code 설치 (WinGet)
# =============================================
Write-Host ""
Invoke-OptionalInstallStage 'SKIP_CLAUDE_CODE' "==> [CI] Skipping Claude Code installation and config (SKIP_CLAUDE_CODE=1)" {
    Write-Host "==> Installing Claude Code via WinGet..."
if ($script:Receipt.packages['winget:Anthropic.ClaudeCode'].pending) {
    $pendingOut = (winget list --id Anthropic.ClaudeCode --exact --accept-source-agreements 2>&1 | Out-String)
    $pendingStatus = $LASTEXITCODE
    $pendingVersion = Get-WingetVersion $pendingOut 'Anthropic.ClaudeCode'
    if (-not (Complete-PendingManagedWingetPackage 'winget:Anthropic.ClaudeCode' $pendingStatus $pendingVersion ([bool](Get-Command claude -ErrorAction SilentlyContinue)))) {
        throw "Pending Claude Code WinGet identity unavailable: $pendingStatus"
    }
}
if (Get-Command claude -ErrorAction SilentlyContinue) {
    Write-Host "    Claude Code already installed: $(claude --version)"
} else {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { throw "WinGet is required to install Claude Code." }
    $claudePackage = 'Anthropic.ClaudeCode'
    $beforeOut = (winget list --id $claudePackage --exact --accept-source-agreements 2>&1 | Out-String)
    $beforeStatus = $LASTEXITCODE
    $beforeVersion = Get-WingetVersion $beforeOut $claudePackage
    if ($beforeStatus -eq 0 -and $beforeVersion) { $beforePresent = $true }
    elseif (Test-WingetDefinitiveAbsent $beforeStatus) { $beforePresent = $false }
    else { throw "Claude Code WinGet identity unavailable before installation: $beforeStatus" }
    if (-not (Begin-ManagedPackage "winget:$claudePackage" $beforePresent $beforeVersion)) { throw "Claude Code receipt journal failed." }
        winget install --id $claudePackage --exact --silent --accept-package-agreements --accept-source-agreements
        $managerStatus = $LASTEXITCODE
        $afterOut = (winget list --id $claudePackage --exact --accept-source-agreements 2>&1 | Out-String)
        $afterStatus = $LASTEXITCODE
        $afterVersion = Get-WingetVersion $afterOut $claudePackage
        $completionStatus = Complete-ManagedWingetPackage "winget:$claudePackage" $beforePresent $beforeVersion $managerStatus $afterStatus $afterVersion ([bool](Get-Command claude -ErrorAction SilentlyContinue))
        if ($completionStatus -ne 0) { throw "Claude Code WinGet installation/identity failed: $completionStatus (receipt pending when mutation is uncertain)" }
}


# =============================================
# 3-1. Claude Code 설정 배포 (config/claude/ + config/agents/global.md → ~/.claude/)
# =============================================
Write-Host ""
Write-Host "==> Deploying Claude Code config..."
New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null

# settings.json: 사용자 nested 설정 보존 + dotfiles 관리 hook upsert
$settingsSrc = Join-Path $ROOT "config\claude\settings.json"
$settingsDst = Join-Path $ClaudeDir "settings.json"
if (Test-Path $settingsSrc) {
    Merge-JsonRegistry $settingsSrc $settingsDst
} else {
    Write-Host "    [!] config\claude\settings.json not found"
}

if (Test-Path $agentsGlobalSrc) {
    if (Install-ManagedFile $agentsGlobalSrc (Join-Path $ClaudeDir "CLAUDE.md") Takeover) { Write-Host "    Copied global agent instructions to CLAUDE.md" }
} else {
    Write-Host "    [!] config\agents\global.md not found"
}

# hooks/: 배포 (temporal-context.sh 등)
$hooksSrc = Join-Path $ROOT "config\claude\hooks"
$hooksDst = Join-Path $ClaudeDir "hooks"
if (Test-Path $hooksSrc) {
    if (Install-ManagedTree $hooksSrc $hooksDst Skip) { Write-Host "    Copied hooks/" }
} else {
    Write-Host "    [!] config\claude\hooks not found, skipping."
}

# 로컬 skills/: dotfiles 소유 skill만 디렉터리 단위 배포 (원격 npx skill 보존)
$skillsLocalSrc = Join-Path $ROOT "config\claude\skills"
if (Test-Path $skillsLocalSrc) {
    $skillsDst = Join-Path $ClaudeDir "skills"
    New-Item -ItemType Directory -Force -Path $skillsDst | Out-Null
    Get-ChildItem $skillsLocalSrc -Directory | ForEach-Object {
        if (Install-ManagedTree $_.FullName (Join-Path $skillsDst $_.Name) Skip $true) {
            Write-Host "    Deployed local skill: $($_.Name)"
        }
    }
}

# 공용 role: config\agents\roles\<name>\ = claude.frontmatter + body.md 조립
# → ~\.claude\agents\<name>.md (사용자가 직접 만든 다른 agent 파일은 보존)
if (Test-Path $rolesSrc) {
    $agentsDst = Join-Path $ClaudeDir "agents"
    New-Item -ItemType Directory -Force -Path $agentsDst | Out-Null
    Get-ChildItem $rolesSrc -Directory | ForEach-Object {
        $fm = Join-Path $_.FullName "claude.frontmatter"
        $body = Join-Path $_.FullName "body.md"
        if ((Test-Path $fm) -and (Test-Path $body)) {
            $content = (Get-Content $fm -Raw) + (Get-Content $body -Raw)
            $tmpAgent = New-TemporaryFile
            try {
                Set-Content -Path $tmpAgent -Value $content -NoNewline -Encoding utf8
                if (Install-ManagedFile $tmpAgent (Join-Path $agentsDst "$($_.Name).md") Skip) {
                    Write-Host "    Deployed agent: $($_.Name)"
                }
            } finally { Remove-Item $tmpAgent -Force -ErrorAction SilentlyContinue }
        }
    }
}

}

# =============================================
# 4. PowerShell 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating PowerShell profiles..."
$profileSrc = Join-Path $ROOT "config\powershell\profile.ps1"
if (Test-Path $profileSrc) {
    $profileContent = Get-Content $profileSrc -Raw
    $claudeAlias = "function global:ccd { claude --dangerously-skip-permissions @args }"
    $block = "$profileContent`n$claudeAlias"

    $profilePaths = @(if ($env:DOTFILES_PS_PROFILE_PATH) { $env:DOTFILES_PS_PROFILE_PATH } else { $PROFILE.CurrentUserCurrentHost })
    foreach ($prof in $profilePaths) {
        New-Item -ItemType Directory -Force -Path (Split-Path $prof) | Out-Null
        Set-ProfileBlock $prof $block
    }
} else {
    Write-Host "    [!] config\windows\profile.ps1 not found, skipping profile setup."
}

# =============================================
# 5. Git Bash 프로파일 설정 (마커 방식)
# =============================================
Write-Host ""
Write-Host "==> Updating Git Bash profile..."
$bashrcSrc = Join-Path $ROOT "config\bash\bashrc"
if (Test-Path $bashrcSrc) {
    $gitBashFound = $GitBashPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $gitBashFound) {
        Write-Host "    [!] Git Bash not found. Install Git for Windows first."
        Write-Host "        winget install --id Git.Git"
    } else {
        $bashrcContent = Get-Content $bashrcSrc -Raw
        $bashrcPath = Join-Path $env:USERPROFILE ".bashrc"
        Set-ProfileBlock $bashrcPath $bashrcContent

        # .inputrc 배포 (마커 방식)
        $inputrcSrc = Join-Path $ROOT "config\bash\inputrc"
        if (Test-Path $inputrcSrc) {
            $inputrcContent = Get-Content $inputrcSrc -Raw
            $inputrcPath = Join-Path $env:USERPROFILE ".inputrc"
            Set-ProfileBlock $inputrcPath $inputrcContent
        }

        # Git Bash 로그인 셸에서 ~/.bashrc를 로드하도록 사용자 설정을 보존하며 추가
        $bashProfilePath = Join-Path $env:USERPROFILE ".bash_profile"
        Set-ProfileBlock $bashProfilePath "[[ -f ~/.bashrc ]] && . ~/.bashrc"
    }
} else {
    Write-Host "    [!] config\bash\bashrc not found, skipping Git Bash setup."
}

# =============================================
# 6. Claude skills 설치 (manifests/skills.txt)
# =============================================
Write-Host ""
Write-Host "==> Restoring Claude Code skills..."
$skillsFile = Join-Path $ROOT "manifests\skills.txt"
Invoke-ClaudeSkillsStage $skillsFile

# =============================================
# 7. Claude Code 플러그인 설치 (manifests/plugins.txt)
# =============================================
Write-Host ""
Write-Host "==> Restoring Claude Code plugins..."
$pluginsFile = Join-Path $ROOT "manifests\plugins.txt"
Invoke-ClaudePluginsStage $pluginsFile

if (-not (Complete-Install)) { exit 1 }
exit 0
