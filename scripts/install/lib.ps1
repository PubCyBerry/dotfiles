$script:DotfilesBeginMarker = "# ===== dotfiles-begin ====="
$script:DotfilesEndMarker = "# ===== dotfiles-end ====="

if (-not $script:DotfilesBackupRoot) {
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $script:DotfilesBackupRoot = Join-Path $env:USERPROFILE ".dotfiles-backup\$stamp"
}

function Write-Step([string]$Message) { Write-Host ""; Write-Host "==> $Message" }
function Write-Ok([string]$Message) { Write-Host "    [ok] $Message" }
function Write-Skip([string]$Message) { Write-Host "    [skip] $Message" }
function Write-Warn([string]$Message) { Write-Host "    [warn] $Message" }
function Write-Fail([string]$Message) { Write-Host "    [fail] $Message" }

function Test-DryRun {
    return [bool]$script:DryRun
}

function Invoke-DotfilesCommand {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$ScriptBlock,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (Test-DryRun) {
        Write-Host "    [dry-run] $Description"
        return
    }

    & $ScriptBlock
}

function Get-ManifestLines([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    Get-Content $Path |
        Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } |
        ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^([^#]+)#') { $Matches[1].Trim() } else { $line }
        } |
        Where-Object { $_ }
}

function Test-StepEnabled([string]$Step) {
    $onlyItems = @()
    $skipItems = @()
    if ($script:OnlyCsv) { $onlyItems = $script:OnlyCsv -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
    elseif ($script:OnlySteps) { $onlyItems = @($script:OnlySteps) }
    if ($script:SkipCsv) { $skipItems = $script:SkipCsv -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
    elseif ($script:SkipSteps) { $skipItems = @($script:SkipSteps) }

    if ($onlyItems.Count -gt 0 -and -not ($onlyItems -contains $Step)) { return $false }
    if ($skipItems -contains $Step) { return $false }
    return $true
}

function Get-BackupPath([string]$Target) {
    $full = [System.IO.Path]::GetFullPath($Target)
    $homePath = [System.IO.Path]::GetFullPath($env:USERPROFILE)
    if ($full.StartsWith($homePath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $full.Substring($homePath.Length).TrimStart('\', '/')
    } else {
        $rel = $full -replace '^[A-Za-z]:\\?', '' -replace '^\\+', ''
    }
    return Join-Path $script:DotfilesBackupRoot $rel
}

function Backup-Existing([string]$Target) {
    if (-not (Test-Path $Target)) { return }
    $backup = Get-BackupPath $Target
    if (Test-DryRun) {
        Write-Skip "Would back up $Target -> $backup"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $backup) | Out-Null
    Copy-Item $Target $backup -Recurse -Force
    Write-Ok "Backed up $Target -> $backup"
}

function Copy-ManagedFile([string]$Source, [string]$Destination) {
    if (-not (Test-Path $Source)) {
        Write-Warn "$Source not found, skipping"
        return
    }
    if ((Test-Path $Destination) -and ((Get-FileHash $Source).Hash -eq (Get-FileHash $Destination).Hash)) {
        Write-Skip "$Destination already up to date"
        return
    }
    Backup-Existing $Destination
    if (Test-DryRun) {
        Write-Skip "Would copy $Source -> $Destination"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
    Copy-Item $Source $Destination -Force
    Write-Ok "Copied $Source -> $Destination"
}

function Copy-ManagedDirectory([string]$Source, [string]$Destination) {
    if (-not (Test-Path $Source)) {
        Write-Warn "$Source not found, skipping"
        return
    }
    if (Test-Path $Destination) {
        $srcFiles = Get-ChildItem $Source -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring((Get-Item $Source).FullName.Length).TrimStart('\', '/')
            $hash = (Get-FileHash $_.FullName).Hash
            "${rel}:$hash"
        } | Sort-Object
        $dstFiles = Get-ChildItem $Destination -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring((Get-Item $Destination).FullName.Length).TrimStart('\', '/')
            $hash = (Get-FileHash $_.FullName).Hash
            "${rel}:$hash"
        } | Sort-Object
        if (($srcFiles -join "`n") -eq ($dstFiles -join "`n")) {
            Write-Skip "$Destination already up to date"
            return
        }
    }
    Backup-Existing $Destination
    if (Test-DryRun) {
        Write-Skip "Would replace $Destination with $Source"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
    if (Test-Path $Destination) { Remove-Item $Destination -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    Copy-Item (Join-Path $Source '*') $Destination -Recurse -Force
    Write-Ok "Deployed $Source -> $Destination"
}

function Add-ToUserPath([string]$Dir) {
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $parts = @()
    if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ } }
    if ($parts -contains $Dir) {
        Write-Skip "$Dir already in User PATH"
        return
    }
    if (Test-DryRun) {
        Write-Skip "Would add $Dir to User PATH"
        return
    }
    $newPath = (@($parts) + $Dir) -join ';'
    [System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
    if (($env:PATH -split ';') -notcontains $Dir) { $env:PATH = "$env:PATH;$Dir" }
    Write-Ok "Added $Dir to User PATH"
}

function Set-ProfileBlock([string]$FilePath, [string]$Content) {
    $block = "$script:DotfilesBeginMarker`n$Content`n$script:DotfilesEndMarker"
    Backup-Existing $FilePath
    if (Test-DryRun) {
        Write-Skip "Would update marker block in $FilePath"
        return
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $FilePath) | Out-Null
    New-Item -ItemType File -Force -Path $FilePath | Out-Null
    $existing = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $existing) { $existing = "" }

    $pattern = [regex]::Escape($script:DotfilesBeginMarker) + ".*?" + [regex]::Escape($script:DotfilesEndMarker)
    $newContent = [regex]::Replace($existing, $pattern, $block, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($newContent -eq $existing) {
        $newContent = "$existing`n$block"
        Write-Ok "Appended dotfiles block to $FilePath"
    } else {
        Write-Ok "Updated dotfiles block in $FilePath"
    }
    $newContent | Out-File -FilePath $FilePath -Encoding utf8 -NoNewline
}

function Merge-GitConfig([string]$FilePath) {
    if (-not (Test-Path $FilePath)) {
        Write-Warn "$FilePath not found, skipping"
        return
    }
    $existingConfig = @{}
    git config --global --list 2>$null | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $existingConfig[$Matches[1]] = $Matches[2] }
    }
    $currentSection = $null
    foreach ($line in (Get-Content $FilePath)) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
        } elseif ($trimmed -and -not $trimmed.StartsWith('#') -and $currentSection) {
            if ($trimmed -match '^(\S+)\s*=\s*(.*)$') {
                $key = $Matches[1]
                $value = $Matches[2].Trim()
                $configKey = "$currentSection.$key"
                if (-not $existingConfig.ContainsKey($configKey)) {
                    Invoke-DotfilesCommand -Description "git config --global $configKey $value" -ScriptBlock {
                        git config --global $configKey $value
                    }
                    Write-Ok "Added [$currentSection] $key = $value"
                } else {
                    Write-Skip "[$currentSection] $key already set"
                }
            }
        }
    }
}
