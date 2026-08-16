# Windows dotfiles 설치 진입점 (all-in-one)
# 실행: pwsh -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT = $PSScriptRoot
$script:InstallFailures = [Collections.Generic.List[string]]::new()

# =============================================
# 경로 상수
# =============================================
$ClaudeDir       = Join-Path $env:USERPROFILE ".claude"
$CodexDir        = Join-Path $env:USERPROFILE ".codex"
$GeminiDir       = Join-Path $env:USERPROFILE ".gemini"
$GeminiConfigDir = Join-Path $GeminiDir "config"
$LocalBin        = Join-Path $env:USERPROFILE ".local\bin"
$RhwpDir       = Join-Path $env:USERPROFILE "rhwp"
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
$agentsGlobalSrc = Join-Path $ROOT "config\agents\global.md"
$rolesSrc        = Join-Path $ROOT "config\agents\roles"

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

# npx skills는 설치한 skill을 ~\.agents\.skill-lock.json에 source와 함께 기록한다.
# 기록이 없거나 source가 다르면 우리가 심은 skill이 아니므로 update 대상이 아니다.
function Test-NpxTrackedSkill([string]$Name, [string]$Repo) {
    $lock = Join-Path $env:USERPROFILE '.agents\.skill-lock.json'
    if (-not (Test-Path -LiteralPath $lock -PathType Leaf)) { return $false }
    try { $data = Get-Content -Raw -LiteralPath $lock | ConvertFrom-Json } catch { return $false }
    if ($null -eq $data -or $null -eq $data.skills) { return $false }
    $entry = $data.skills.PSObject.Properties[$Name]
    return ($null -ne $entry -and $entry.Value.source -eq $Repo)
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
    # npx가 같은 source로 이미 추적 중인 skill만 update로 갱신한다.
    # 추적되지 않는 이름(구 로컬 skill 배포분, 다른 source의 동명 skill)은 add로 manifest source에 맞춘다.
    # update가 실패하면 add로 내려간다 — upstream이 skill을 옮기거나 이름을 바꾸면 lock에는
    # 옛 이름이 남아 update 분기만 타게 되고, fallback이 없으면 install이 영구히 실패한다.
    foreach ($row in $rows) {
        $repoSlug, $skillName = $row -split '@', 2
        if (Test-NpxTrackedSkill $skillName $repoSlug) {
            npx -y skills update $skillName --global --yes 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    Updated skill: $skillName"
                continue
            }
            Write-Host "    Update failed, falling back to add: $skillName"
        }
        npx -y skills add $repoSlug --skill $skillName --global --yes --agent claude-code 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    Added skill: $skillName from $repoSlug"
        } else {
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

function Resolve-ManagedLinkPath([string]$Path) {
    # reparse point 체인을 끝까지 따라가 실제 경로를 얻는다.
    # fnm은 셸마다 `fnm_multishells\<PID>_<timestamp>` 링크를 새로 만들기 때문에
    # `npm prefix -g` 결과를 그대로 쓰면 실행마다 값이 달라진다.
    if (-not $Path) { return '' }
    $current = Get-ManagedPath $Path
    for ($hop = 0; $hop -lt 8; $hop++) {
        $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
        if (-not $item -or -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or -not $item.LinkTarget) { break }
        $target = $item.LinkTarget
        if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path (Split-Path $current -Parent) $target }
        $current = Get-ManagedPath $target
    }
    return $current.TrimEnd('\')
}

function Test-EphemeralNpmPrefix([string]$Path) {
    # fnm multishell 경로는 셸 수명 동안만 유효하다. receipt에 남아 있으면 링크를 풀지 않고 기록한 잔재다.
    if (-not $Path -or -not $env:LOCALAPPDATA) { return $false }
    $root = (Get-ManagedPath (Join-Path $env:LOCALAPPDATA 'fnm_multishells')).TrimEnd('\') + '\'
    (Get-ManagedPath $Path).StartsWith($root, [StringComparison]::OrdinalIgnoreCase)
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
    Get-ChildItem $SourceDir -Recurse -File | Where-Object { $_.FullName -notmatch '[\\/](__pycache__|\.git)[\\/]' } | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($SourceDir, $_.FullName)
        if (-not (Install-ManagedFile $_.FullName (Join-Path $DestDir $relative) $Collision)) { $success = $false }
    }
    return $success
}

function Get-ManagedTreeHash([string]$Root) {
    # 트리 전체를 하나의 identity로 접는다. 상대경로/종류/크기/파일해시만 보므로
    # 타임스탬프처럼 재현되지 않는 값에 흔들리지 않는다.
    $rootFull = (Get-ManagedPath $Root).TrimEnd('\')
    $rootItem = Get-Item -LiteralPath $rootFull -Force -ErrorAction SilentlyContinue
    if ($rootItem -isnot [IO.DirectoryInfo] -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $null }
    $entries = [Collections.Generic.List[string]]::new()
    foreach ($child in @(Get-ChildItem -LiteralPath $rootFull -Recurse -Force -ErrorAction SilentlyContinue)) {
        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { return $null }
        $relative = [IO.Path]::GetRelativePath($rootFull, $child.FullName).Replace('\', '/')
        if ($child -is [IO.DirectoryInfo]) { $entries.Add("d`t$relative") }
        elseif ($child -is [IO.FileInfo]) {
            $fileHash = (Get-FileHash -LiteralPath $child.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            $entries.Add("f`t$relative`t$($child.Length)`t$fileHash")
        } else { return $null }
    }
    $sorted = [string[]]$entries.ToArray()
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    $bytes = [Text.Encoding]::UTF8.GetBytes((($sorted -join "`n") + "`n"))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes)) -replace '-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Install-ManagedDirectTree([string]$SourceDir, [string]$DestDir, [string]$Version) {
    # 버전이 박힌 artifact tree를 통째로 소유한다. 파일 단위 소유권과 달리 tree 해시가
    # 하나라도 어긋나면 손대지 않는다 — 사용자가 그 안을 고쳤다는 뜻이기 때문이다.
    if (-not $script:ReceiptReady -or -not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return $false }
    if (-not (Test-ManagedParentPath $DestDir)) { Write-Warning "Unsafe direct tree parent; preserving: $DestDir"; return $false }
    $key = Get-ManagedPath $DestDir
    $sourceHash = Get-ManagedTreeHash $SourceDir
    if (-not $sourceHash) { Write-Warning "Unsupported source tree; preserving: $DestDir"; return $false }
    $destItem = Get-Item -LiteralPath $DestDir -Force -ErrorAction SilentlyContinue
    if ($destItem -and ($destItem -isnot [IO.DirectoryInfo] -or ($destItem.Attributes -band [IO.FileAttributes]::ReparsePoint))) {
        Write-Warning "Unsupported destination tree root; preserving: $DestDir"; return $false
    }
    $currentHash = if ($destItem) { Get-ManagedTreeHash $DestDir } else { $null }
    $entry = $script:Receipt.artifacts[$key]
    if ($entry) {
        if (-not $entry.Contains('installedTreeHash')) { Write-Warning "Receipt kind collision; preserving: $DestDir"; return $false }
        if ($entry.pending) {
            if (-not $entry.targetTreeHash -or $entry.targetTreeHash -cne $sourceHash) {
                Write-Warning "Pending direct tree target changed; preserving: $DestDir"; return $false
            }
            if ($currentHash -ceq $entry.targetTreeHash) {
                $entry.installedTreeHash = $entry.targetTreeHash
                $entry.directVersion = $Version
                $entry.pending = $false
                foreach ($field in @('targetTreeHash','previousExists')) { $null = $entry.Remove($field) }
                Save-InstallReceipt
                return $true
            }
            if ($destItem) { Write-Warning "Pending direct tree is not a recoverable fresh target; preserving: $DestDir"; return $false }
        } else {
            if ($currentHash -cne $entry.installedTreeHash) { Write-Warning "Managed direct tree changed; preserving: $DestDir"; return $false }
            if ($currentHash -ceq $sourceHash) { $entry.directVersion = $Version; Save-InstallReceipt; return $true }
            Write-Warning "Versioned direct tree content differs; preserving: $DestDir"; return $false
        }
    } elseif ($destItem) {
        Write-Warning "Unowned direct tree collision; preserving: $DestDir"; return $false
    } else {
        $script:Receipt.artifacts[$key] = [ordered]@{
            before = [ordered]@{ exists = $false; type = 'missing' }
            installedTreeHash = $null
            pending = $true
            targetTreeHash = $sourceHash
            previousExists = $false
        }
        Save-InstallReceipt
        $entry = $script:Receipt.artifacts[$key]
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $DestDir -Parent) | Out-Null
    $tmp = Join-Path (Split-Path $DestDir -Parent) ".dotfiles-tree.$([guid]::NewGuid()).tmp"
    try {
        Copy-Item -LiteralPath $SourceDir -Destination $tmp -Recurse -Force
        if ((Get-ManagedTreeHash $tmp) -cne $sourceHash) { Write-Warning "Direct tree copy verification failed: $DestDir"; return $false }
        Move-Item -LiteralPath $tmp -Destination $DestDir -Force
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
    $entry.installedTreeHash = $sourceHash
    $entry.directVersion = $Version
    $entry.pending = $false
    foreach ($field in @('targetTreeHash','previousExists')) { $null = $entry.Remove($field) }
    Save-InstallReceipt
    return $true
}

function Sync-ManagedFileHash([string]$Path) {
    # `claude plugin`처럼 설치 스크립트가 직접 호출한 도구가 관리 파일을 뒤이어 다시 쓰면
    # receipt의 installedHash가 그 자리에서 낡아 다음 실행이 파일을 보존해 버린다.
    # 설치가 끝난 시점의 내용으로 도장을 다시 찍어 소유권을 유지한다.
    if (-not $script:ReceiptReady) { return $false }
    $key = Get-ManagedPath $Path
    $entry = $script:Receipt.artifacts[$key]
    if (-not $entry -or $entry.pending) { return $false }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    $hash = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -eq $entry.installedHash) { return $false }
    $entry.installedHash = $hash
    Save-InstallReceipt
    return $true
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
        # 이전 버전은 링크를 풀지 않은 fnm multishell 경로를 기록했다. 그 값은 셸마다 달라져
        # 소유권 판단에 쓸 수 없으므로, 새 prefix가 안정 경로일 때만 잔재를 교정하고 진행한다.
        if (-not (Test-EphemeralNpmPrefix $existing.prefix) -or (Test-EphemeralNpmPrefix $Prefix)) {
            Write-Warning "npm prefix changed or missing in receipt; preserving package ownership: $Name"
            return $false
        }
        Write-Warning "Repairing ephemeral npm prefix recorded in receipt: $Name"
        # 낡은 prefix가 어느 위치를 가리켰는지 알 수 없으므로 before 스냅샷도 지금 측정값으로 다시 잡는다.
        # 그대로 두면 다른 위치에서 잰 "설치 전 없음"이 남아 uninstall이 사용자 설치를 지운다.
        $existing.before = [ordered]@{ present = $BeforePresent; value = $(if ($BeforePresent) { $BeforeValue } else { $null }) }
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
    $userRegKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $false)
    $rawPath = if ($userRegKey) { $userRegKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { [System.Environment]::GetEnvironmentVariable("PATH", "User") }
    if ($userRegKey) { $userRegKey.Close() }

    $userPath = if ($rawPath) { [string]$rawPath } else { "" }
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
        $writeKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
        if ($writeKey) {
            $writeKey.SetValue("Path", $newUserPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            $writeKey.Close()
        } else {
            [System.Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
        }
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
    # 이번 실행에서 실제로 파일을 썼는지 남긴다. 나중 단계가 그 파일을 다시 쓸 때만
    # 소유권 해시를 갱신하기 위한 것이라, 보존으로 끝난 경우와 반드시 구분해야 한다.
    $script:LastJsonRegistryDeployed = $false
    if (-not (Test-Path $SourcePath)) {
        Write-Host "    [!] $SourcePath not found, skipping."
        return
    }
    if (-not (Test-Path $DestPath)) {
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) { Copy-Item $SourcePath $DestPath -Force; Write-Host "    Copied $(Split-Path $DestPath -Leaf)"; $script:LastJsonRegistryDeployed = $true }
        elseif (Install-ManagedFile $SourcePath $DestPath Takeover) { Write-Host "    Copied $(Split-Path $DestPath -Leaf)"; $script:LastJsonRegistryDeployed = $true }
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
            $script:LastJsonRegistryDeployed = $true
        } elseif (Install-ManagedFile $tmp $DestPath Takeover) {
            Write-Host "    Merged $(Split-Path $DestPath -Leaf)"
            $script:LastJsonRegistryDeployed = $true
        }
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------
# MCP server 등록 (receipt values로 소유권 관리)
#
# Codex는 ~/.codex/config.toml의 [mcp_servers.<name>], Claude Code는 공식 저장소인
# ~/.claude.json의 .mcpServers.<name>에 둔다. ~/.claude/settings.json은 MCP 정의 파일이
# 아니므로 건드리지 않는다. 사용자가 만든 동명 entry는 언제나 보존한다.
# ---------------------------------------------

# 비교는 항상 정규화된 JSON으로 한다. TOML/JSON 왕복에서 키 순서가 바뀌어도
# 같은 entry를 "변경됨"으로 오판하지 않기 위해서다.
function ConvertTo-CanonicalJson([string]$Text) {
    if (-not $Text) { return $null }
    $out = @($Text | & jq -cS '.' 2>$null)
    if ($LASTEXITCODE -ne 0 -or $out.Count -eq 0) { return $null }
    return [string]$out[0]
}

function Get-McpEntry([string]$McpHost, [string]$Name, [string]$Path) {
    $script:McpPresent = $false
    $script:McpValue = $null
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $true }
    if ($item -isnot [IO.FileInfo] -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    $raw = $null
    if ($McpHost -eq 'codex') {
        if (-not (Get-Command yq -ErrorAction SilentlyContinue)) { return $false }
        & yq -p=toml -o=json '.' $Path 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { return $false }
        $lines = @(& yq -p=toml -o=json ".mcp_servers.`"$Name`"" $Path 2>$null)
        if ($LASTEXITCODE -ne 0) { return $false }
        $raw = ($lines -join "`n").Trim()
        if (-not $raw -or $raw -ceq 'null') { return $true }
    } else {
        if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { return $false }
        $lines = @(& jq -c --arg n $Name '.mcpServers | if type=="object" then (.[$n] // empty) else empty end' $Path 2>$null)
        if ($LASTEXITCODE -ne 0) { return $false }
        $raw = ($lines -join "`n").Trim()
        if (-not $raw) { return $true }
    }
    $canonical = ConvertTo-CanonicalJson $raw
    if (-not $canonical) { return $false }
    $script:McpValue = $canonical
    $script:McpPresent = $true
    return $true
}

function Set-McpEntry([string]$McpHost, [string]$Name, [string]$Path, [AllowNull()][string]$Value) {
    $dir = Split-Path $Path -Parent
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    if (-not (Test-Path -LiteralPath $Path)) {
        $seed = if ($McpHost -eq 'codex') { '' } else { '{}' }
        [IO.File]::WriteAllText($Path, $seed, [Text.UTF8Encoding]::new($false))
    }
    $tmp = Join-Path $dir ".mcp.$([guid]::NewGuid()).tmp"
    try {
        if ($McpHost -eq 'codex') {
            $expr = if ($Value) { ".mcp_servers.`"$Name`" = $Value" }
                    else { "del(.mcp_servers.`"$Name`") | del(.mcp_servers | select(length == 0))" }
            $out = @(& yq -p=toml -o=toml $expr $Path 2>$null)
            if ($LASTEXITCODE -ne 0) { return $false }
            ($out -join "`n") | Out-File $tmp -Encoding utf8 -NoNewline
            & yq -p=toml -o=json '.' $tmp 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { return $false }
        } else {
            $out = if ($Value) {
                @(& jq --arg n $Name --argjson v $Value '.mcpServers = ((.mcpServers // {}) | .[$n] = $v)' $Path 2>$null)
            } else {
                @(& jq --arg n $Name 'if (.mcpServers|type)=="object" then .mcpServers |= del(.[$n]) else . end' $Path 2>$null)
            }
            if ($LASTEXITCODE -ne 0 -or $out.Count -eq 0) { return $false }
            ($out -join "`n") | Out-File $tmp -Encoding utf8 -NoNewline
            & jq empty $tmp 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) { return $false }
        }
        Move-Item -LiteralPath $tmp -Destination $Path -Force
        return $true
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Install-ManagedMcpServer([string]$McpHost, [string]$Name, [string]$Path, [string]$Desired) {
    if (-not $script:ReceiptReady) { return $false }
    $desiredCanonical = ConvertTo-CanonicalJson $Desired
    if (-not $desiredCanonical) { return $false }
    $key = "mcp:${McpHost}:${Name}"
    if (-not (Get-McpEntry $McpHost $Name $Path)) { Write-Warning "MCP registry unreadable; preserving: $Path"; return $false }
    $entry = $script:Receipt.values[$key]
    if ($entry) {
        if ($entry.pending) {
            if ($script:McpPresent -and $script:McpValue -ceq $entry.pending.target) {
                Record-ManagedValue $key $entry.before.present $entry.before.value $entry.pending.target
            } elseif ($script:McpPresent -ne [bool]$entry.pending.previousPresent -or
                      ($script:McpPresent -and $script:McpValue -cne $entry.pending.previousValue)) {
                Write-Warning "Pending MCP entry changed; preserving: $key"; return $false
            }
        }
        $installed = $script:Receipt.values[$key].installed
        if ($installed -and (-not $script:McpPresent -or $script:McpValue -cne $installed)) {
            Write-Warning "Managed MCP entry changed; preserving: $key"; return $false
        }
        if ($script:McpValue -ceq $desiredCanonical) { Write-Host "    MCP already registered: $key"; return $true }
    } elseif ($script:McpPresent) {
        Write-Warning "Unowned MCP entry collision; preserving: $key"; return $false
    }
    $beforePresent = $script:McpPresent
    $beforeValue = $script:McpValue
    if (-not (Begin-ManagedValue $key $beforePresent $beforeValue $desiredCanonical)) { return $false }
    if (-not (Set-McpEntry $McpHost $Name $Path $desiredCanonical)) { Write-Warning "Failed to write MCP entry: $key"; return $false }
    if (-not (Get-McpEntry $McpHost $Name $Path) -or -not $script:McpPresent -or $script:McpValue -cne $desiredCanonical) {
        Write-Warning "MCP entry verification failed: $key"; return $false
    }
    Record-ManagedValue $key $beforePresent $beforeValue $desiredCanonical
    $null = Sync-ManagedFileHash $Path
    Write-Host "    Registered MCP server: $key"
    return $true
}

# ---------------------------------------------
# rhwp: 공식 archive 전체를 ~/rhwp tree에 두고 MCP를 등록한다.
# ---------------------------------------------
function Test-RhwpManifestRows([object[]]$Rows) {
    if ($Rows.Count -ne 4) { return $false }
    $platforms = @('windows-x86_64','linux-x86_64','macos-x86_64','macos-aarch64')
    $seen = @{}
    foreach ($row in $Rows) {
        if ($row.Count -ne 5) { return $false }
        $platform, $version, $format, $url, $checksum = $row
        if ($platform -notin $platforms -or $seen.ContainsKey($platform)) { return $false }
        $seen[$platform] = $true
        if ($version -notmatch '^\d+\.\d+\.\d+$' -or $format -notin @('tgz','zip')) { return $false }
        if ($url -notmatch '^https://github\.com/edwardkim/rhwp/releases/download/v\d+\.\d+\.\d+/\S+$' -or $url -match '/(latest|HEAD|main)/') { return $false }
        if ($checksum -notmatch '^[0-9a-f]{64}$') { return $false }
    }
    return $true
}

function Install-Rhwp {
    $manifest = Join-Path $ROOT 'manifests\rhwp.tsv'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { Add-InstallFailure 'Required manifest missing: manifests\rhwp.tsv'; return $false }
    $rows = @(Get-Content -LiteralPath $manifest |
        Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
        ForEach-Object { , @($_ -split "`t") })
    if (-not (Test-RhwpManifestRows $rows)) { Add-InstallFailure 'Invalid manifests\rhwp.tsv'; return $false }
    if ([Environment]::Is64BitOperatingSystem -eq $false -or
        $env:PROCESSOR_ARCHITECTURE -notin @('AMD64','x86')) {
        Write-Host "    [!] Unsupported rhwp platform: $env:PROCESSOR_ARCHITECTURE; skipping."
        return $true
    }
    $row = $rows | Where-Object { $_[0] -ceq 'windows-x86_64' } | Select-Object -First 1
    $version = $row[1]; $url = $row[3]; $checksum = $row[4]
    $desired = "{`"command`":$(ConvertTo-Json ((Join-Path $RhwpDir 'rhwp.exe')) -Compress),`"args`":[`"mcp-serve`"]}"

    $key = Get-ManagedPath $RhwpDir
    $entry = $script:Receipt.artifacts[$key]
    $installedTree = if ($entry) { $entry.installedTreeHash } else { $null }
    if ($installedTree -and $entry.directVersion -ceq $version -and (Get-ManagedTreeHash $RhwpDir) -ceq $installedTree) {
        Write-Host "    rhwp $version already installed: $RhwpDir"
    } else {
        $work = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-rhwp.$([guid]::NewGuid())"
        New-Item -ItemType Directory -Force -Path $work | Out-Null
        try {
            $archive = Join-Path $work 'rhwp.zip'
            try { Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 2 }
            catch { Add-InstallFailure "rhwp download failed: $url"; return $false }
            $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -cne $checksum) { Add-InstallFailure "rhwp SHA-256 mismatch: $url"; return $false }
            $extract = Join-Path $work 'extract'
            try { Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force }
            catch { Add-InstallFailure "rhwp archive extraction failed: $url"; return $false }

            # 공식 archive는 rhwp\ 한 겹 아래에 binary와 문서를 담는다. 그 구조를 확인하고
            # archive 전체를 그대로 배치한다 — binary만 뽑아 쓰지 않는다.
            $top = @(Get-ChildItem -LiteralPath $extract -Force)
            if ($top.Count -ne 1 -or $top[0] -isnot [IO.DirectoryInfo] -or $top[0].Name -cne 'rhwp') {
                Add-InstallFailure "Unexpected rhwp archive layout: $url"; return $false
            }
            $tree = $top[0].FullName
            if (@(Get-ChildItem -LiteralPath $tree -Recurse -Force | Where-Object { $_ -isnot [IO.FileInfo] -and $_ -isnot [IO.DirectoryInfo] }).Count -gt 0) {
                Add-InstallFailure "Unsupported member type in rhwp archive: $url"; return $false
            }
            $binary = Join-Path $tree 'rhwp.exe'
            if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { Add-InstallFailure "rhwp binary missing in archive: $url"; return $false }
            $reported = (@(& $binary --version 2>$null) -join "`n").Trim()
            if ($reported -cne "rhwp v$version") {
                Add-InstallFailure "rhwp binary reports '$reported', expected 'rhwp v$version'"; return $false
            }
            if (-not (Install-ManagedDirectTree $tree $RhwpDir $version)) { Add-InstallFailure "rhwp tree not installed: $RhwpDir"; return $false }
            Write-Host "    rhwp $version -> $RhwpDir"
        } finally {
            Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $ok = $true
    # Codex 쪽은 TOML 편집이라 yq가 필요하다. 없으면 config.toml 병합과 같은 정책으로
    # 파일을 건드리지 않고 넘어간다 — 도구 부재로 설치 전체를 실패시키지 않는다.
    if (Get-Command yq -ErrorAction SilentlyContinue) {
        if (-not (Install-ManagedMcpServer codex 'rhwp' (Join-Path $CodexDir 'config.toml') $desired)) { $ok = $false }
    } else {
        Write-Host '    [!] yq not found; skipping Codex MCP registration.'
    }
    $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
    if ((Test-Path -LiteralPath $claudeJson) -or (Get-Command claude -ErrorAction SilentlyContinue)) {
        if (-not (Install-ManagedMcpServer claude 'rhwp' $claudeJson $desired)) { $ok = $false }
    } else {
        Write-Host "    Claude Code not present; skipping ~/.claude.json MCP registration."
    }
    $geminiMcpJson = Join-Path $GeminiConfigDir 'mcp_config.json'
    if ((Test-Path -LiteralPath $GeminiDir) -or (Get-Command agy -ErrorAction SilentlyContinue)) {
        if (-not (Install-ManagedMcpServer gemini 'rhwp' $geminiMcpJson $desired)) { $ok = $false }
    } else {
        Write-Host "    Antigravity not present; skipping ~/.gemini/config/mcp_config.json MCP registration."
    }
    if (-not $ok) { Add-InstallFailure 'rhwp MCP registration incomplete.'; return $false }
    return $true
}

# ---------------------------------------------
# ShellCheck: pinned release 하나를 CI와 세 OS가 함께 쓴다.
#
# 패키지 매니저를 쓰지 않는 이유는 어느 것도 한 버전으로 모이지 않기 때문이다.
# winget의 koalaman.shellcheck는 최신으로 흐르고, apt는 배포판에 묶여
# 22.04=0.8.0 / 24.04=0.9.0을 주며, GitHub Actions ubuntu-24.04 러너의 사전 설치본은
# 러너 이미지를 따라 움직인다(현재 0.9.0).
#
# 버전 차이는 그대로 오탐·미탐이 된다. 0.11.0에서 SC2002가 기본 비활성으로 바뀌고
# SC2327~SC2332, SC3062가 새로 생겼다 — 같은 스크립트가 로컬에서는 통과하고 CI에서는
# 실패한다(반대도 마찬가지다). 그래서 rhwp와 같은 pinned artifact 계약으로 관리한다.
# ---------------------------------------------
function Test-ShellCheckManifestRows([object[]]$Rows) {
    if ($Rows.Count -ne 5) { return $false }
    $platforms = @('windows-x86_64','linux-x86_64','linux-aarch64','macos-x86_64','macos-aarch64')
    $seen = @{}
    $pinned = $null
    foreach ($row in $Rows) {
        if ($row.Count -ne 5) { return $false }
        $platform, $version, $format, $url, $checksum = $row
        if ($platform -notin $platforms -or $seen.ContainsKey($platform)) { return $false }
        $seen[$platform] = $true
        if ($version -notmatch '^\d+\.\d+\.\d+$' -or $format -notin @('tgz','zip')) { return $false }
        # 다섯 행이 같은 버전을 가리켜야 한 릴리즈를 pin한 것이 된다.
        if (-not $pinned) { $pinned = $version } elseif ($version -cne $pinned) { return $false }
        if ($url -notmatch '^https://github\.com/koalaman/shellcheck/releases/download/v\d+\.\d+\.\d+/\S+$' -or $url -match '/(latest|HEAD|main)/') { return $false }
        if ($checksum -notmatch '^[0-9a-f]{64}$') { return $false }
    }
    return $true
}

# `shellcheck --version`은 여러 줄을 뱉고 그중 `version: <ver>` 줄만 버전이다.
function Get-ShellCheckReportedVersion([string]$Exe) {
    foreach ($line in @(& $Exe --version 2>$null)) {
        if ($line -match '^\s*version:\s*(\S+)\s*$') { return $Matches[1] }
    }
    return $null
}

function Install-ShellCheck {
    $manifest = Join-Path $ROOT 'manifests\shellcheck.tsv'
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) { Add-InstallFailure 'Required manifest missing: manifests\shellcheck.tsv'; return $false }
    $rows = @(Get-Content -LiteralPath $manifest |
        Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
        ForEach-Object { , @($_ -split "`t") })
    if (-not (Test-ShellCheckManifestRows $rows)) { Add-InstallFailure 'Invalid manifests\shellcheck.tsv'; return $false }
    if (-not [Environment]::Is64BitOperatingSystem -or
        $env:PROCESSOR_ARCHITECTURE -notin @('AMD64','x86')) {
        Write-Host "    [!] Unsupported shellcheck platform: $env:PROCESSOR_ARCHITECTURE; skipping."
        return $true
    }
    $row = $rows | Where-Object { $_[0] -ceq 'windows-x86_64' } | Select-Object -First 1
    $version = $row[1]; $format = $row[2]; $url = $row[3]; $checksum = $row[4]
    if ($format -cne 'zip') { Add-InstallFailure "Unsupported shellcheck archive format for Windows: $format"; return $false }

    # ~\.local\bin은 config\powershell\profile.ps1과 config\bash\bashrc가 세션 PATH 앞에
    # 두므로 pwsh와 Git Bash 양쪽에서 잡힌다. User PATH(레지스트리)는 건드리지 않는다.
    $dest = Join-Path $LocalBin 'shellcheck.exe'
    if ($script:ReceiptReady) {
        $entry = $script:Receipt.artifacts[(Get-ManagedPath $dest)]
        # 소유권(installedHash)과 identity(--version)가 둘 다 맞을 때만 내려받기를 건너뛴다.
        if ($entry -and -not $entry.pending -and $entry.installedHash -and (Test-Path -LiteralPath $dest -PathType Leaf) -and
            (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $entry.installedHash -and
            (Get-ShellCheckReportedVersion $dest) -ceq $version) {
            Write-Host "    shellcheck $version already installed: $dest"
            return $true
        }
    }

    $work = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-shellcheck.$([guid]::NewGuid())"
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    try {
        $archive = Join-Path $work 'shellcheck.zip'
        try { Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing -MaximumRetryCount 3 -RetryIntervalSec 2 }
        catch { Add-InstallFailure "shellcheck download failed: $url"; return $false }
        $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $checksum) { Add-InstallFailure "shellcheck SHA-256 mismatch: $url"; return $false }
        $extract = Join-Path $work 'extract'
        try { Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force }
        catch { Add-InstallFailure "shellcheck archive extraction failed: $url"; return $false }

        # Windows zip은 Unix tarball과 달리 최상위에 파일을 바로 담는다
        # (LICENSE.txt / README.txt / shellcheck.exe). 감쌀 디렉터리가 없다.
        $binary = Join-Path $extract 'shellcheck.exe'
        if (-not (Test-Path -LiteralPath $binary -PathType Leaf)) { Add-InstallFailure "shellcheck binary missing in archive: $url"; return $false }
        $reported = Get-ShellCheckReportedVersion $binary
        if ($reported -cne $version) {
            Add-InstallFailure "shellcheck binary reports '$reported', expected '$version'"; return $false
        }
        # Skip: 사용자가 직접 둔 shellcheck.exe가 있으면 보존한다.
        if (-not (Install-ManagedFile $binary $dest Skip)) { Add-InstallFailure "shellcheck not installed: $dest"; return $false }
        Write-Host "    shellcheck $version -> $dest"
    } finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $true
}

# ---------------------------------------------
# herdr: 공식 installer에 맡기고, 설정만 이 저장소가 소유한다.
#
# rhwp와 달리 pinned artifact로 관리하지 않는다. 이유가 둘이다.
#  1. Windows용 stable 바이너리가 없다 — v0.7.3~v0.8.0 릴리즈 asset은 linux/macos
#     뿐이고, herdr-windows-x86_64.zip은 preview 태그에만 올라온다. pin할 semver가
#     애초에 존재하지 않는다.
#  2. herdr는 자체 업데이터를 갖는다(`herdr update`, `herdr channel set`). receipt로
#     tree 해시를 잡으면 사용자가 업데이트하는 순간 해시가 어긋나 그 다음 실행부터
#     "changed; preserving"으로 아무것도 못 하게 된다.
# 그래서 바이너리는 소유하지 않고, 이미 있으면 건드리지 않는다.
# ---------------------------------------------
$HerdrInstallUrl = 'https://herdr.dev/install.ps1'
$HerdrBinDir     = Join-Path $env:LOCALAPPDATA 'Programs\Herdr\bin'

function Get-HerdrCommand {
    $cmd = Get-Command herdr -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $known = Join-Path $HerdrBinDir 'herdr.exe'
    if (Test-Path -LiteralPath $known -PathType Leaf) { return $known }
    return $null
}

function Install-Herdr {
    $existing = Get-HerdrCommand
    if ($existing) {
        Write-Host "    herdr already installed: $existing"
        Write-Host "    herdr manages its own updates (herdr update / herdr channel set)."
        return $true
    }
    # 공식 installer는 실행 시점에 최신 빌드를 해석한다. manifests/*.tsv의 pinned
    # SHA-256 계약에서 herdr만 예외라는 뜻이라 AGENTS.md에 근거를 남겨 둔다.
    #
    # 이 함수의 실패는 경고로만 남긴다(Add-InstallFailure 아님). rhwp는 SHA-256으로
    # pin한 artifact를 이 저장소가 소유하므로 실패가 곧 계약 위반이지만, herdr
    # 바이너리는 소유하지 않기로 한 서드파티 CDN이다. 일시적 장애가 dotfiles 설치
    # 전체를 실패로 만드는 것은 그 결정과 어긋난다 — 다음 실행이나 `herdr update`로
    # 복구된다. 호출부가 $false를 받으면 설정 배포만 건너뛴다.
    Write-Host "    Running the official herdr installer: $HerdrInstallUrl"
    try {
        $herdrInstaller = Invoke-RestMethod -Uri $HerdrInstallUrl -UseBasicParsing
    } catch {
        Write-Host "    [!] herdr installer download failed: $HerdrInstallUrl (config deployment skipped)"
        return $false
    }
    if (-not $herdrInstaller) {
        Write-Host "    [!] herdr installer returned an empty script: $HerdrInstallUrl (config deployment skipped)"
        return $false
    }
    # 자식 프로세스로 격리해서 실행한다. 받은 문자열을 scriptblock으로 만들어 같은
    # 프로세스에서 호출하면 내려받은 스크립트의 `exit`가
    # try/catch를 무시하고 install.ps1 자체를 끝낸다. upstream installer는 지금도
    # bare `exit 1`을 다섯 군데 갖고 있고(24, 540, 545, 550, 566행) pin되지 않아
    # 언제든 바뀐다 — `if (upToDate) { exit 0 }` 한 줄만 늘어도 이후 단계(Node,
    # Codex, Claude, 프로파일, skills, plugins)가 통째로 건너뛰어지고 종료 코드는
    # 0이라 사용자는 성공으로 본다. 자식으로 돌리면 그 exit는 종료 코드로만 온다.
    $pwshExe = Join-Path $PSHOME 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwshExe -PathType Leaf)) {
        Write-Host "    [!] herdr installer skipped: could not locate pwsh.exe in $PSHOME"
        return $false
    }
    $installerFile = Join-Path ([IO.Path]::GetTempPath()) ("herdr-install-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $installerFile -Value $herdrInstaller -Encoding utf8
        & $pwshExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installerFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] herdr installer failed (exit $LASTEXITCODE): $HerdrInstallUrl (config deployment skipped)"
            return $false
        }
    } catch {
        Write-Host "    [!] herdr installer failed: $($_.Exception.Message) (config deployment skipped)"
        return $false
    } finally {
        Remove-Item -LiteralPath $installerFile -Force -ErrorAction SilentlyContinue
    }
    # installer가 User PATH를 고쳐도 현재 프로세스에는 반영되지 않는다. 뒤따르는
    # 설정 배포와 검증이 herdr를 찾을 수 있도록 이번 세션 PATH에만 얹는다.
    if ((Test-Path -LiteralPath $HerdrBinDir) -and (($env:PATH -split ';') -notcontains $HerdrBinDir)) {
        $env:PATH = "$HerdrBinDir;$env:PATH"
    }
    $installed = Get-HerdrCommand
    if (-not $installed) {
        Write-Host '    [!] herdr installer finished but herdr was not found (config deployment skipped).'
        return $false
    }
    Write-Host "    herdr installed: $installed"
    return $true
}

function Deploy-HerdrConfig {
    $src = Join-Path $ROOT 'config\herdr\config.windows.toml'
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        Write-Host '    [!] config\herdr\config.windows.toml not found, skipping.'
        return
    }
    if (-not (Get-Command yq -ErrorAction SilentlyContinue)) {
        Write-Host '    [!] yq not found, keeping existing herdr config.toml'
        return
    }
    # default_shell은 실제로 찾아낸 Git Bash 경로로만 쓴다. 없으면 그 키를 아예 넣지
    # 않는다 — 존재하지 않는 셸을 지정하면 herdr가 pane을 못 띄운다.
    $gitBash = $GitBashPaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    $staged = New-TemporaryFile
    try {
        Copy-Item -LiteralPath $src -Destination $staged -Force
        if ($gitBash) {
            # forward slash로 넣는다. yq의 TOML 인코더는 백슬래시를 온전히 이스케이프하지
            # 못해 \b가 백스페이스로 깨진다. herdr는 forward slash 경로를 그대로 받는다.
            $shellPath = $gitBash -replace '\\', '/'
            & yq -i -p=toml -o=toml ".terminal.default_shell = `"$shellPath`"" $staged 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host '    [!] Could not set herdr default_shell, keeping existing herdr config.toml'
                return
            }
        } else {
            # 키가 하나도 없는 [terminal]을 남기면 안 된다. yq의 TOML 인코더가 그 주석
            # 블록을 어느 테이블에도 붙이지 못해 merge마다 다시 방출하고, 배포된
            # config.toml이 실행할 때마다 20줄씩 자란다(멱등성 위반).
            & yq -i -p=toml -o=toml 'with(select(.terminal | length == 0); del(.terminal))' $staged 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host '    [!] Could not normalize herdr config.toml, keeping existing herdr config.toml'
                return
            }
            Write-Host '    [!] Git Bash not found; deploying herdr config without default_shell.'
        }
        $dst = Join-Path $env:APPDATA 'herdr\config.toml'
        New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null

        # default merge(destination 우선) — herdr UI가 onboarding에서 기록한 [ui] 값을
        # 보존한다. Merge-CodexConfig를 그대로 부르지 않는 이유는 default_shell 하나가
        # 그 규칙의 예외여야 하기 때문이다(아래).
        if (Test-Path -LiteralPath $dst -PathType Leaf) {
            & yq -p=toml -o=json '.' $dst 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host '    [!] existing herdr config.toml is invalid, keeping it unchanged'
                return
            }
            $merged = @(& yq eval-all -p=toml -o=toml 'select(fileIndex == 0) * select(fileIndex == 1)' $staged $dst 2>$null)
            if ($LASTEXITCODE -ne 0 -or $merged.Count -eq 0) {
                Write-Host '    [!] herdr config.toml merge failed, keeping existing herdr config.toml'
                return
            }
            ($merged -join "`n") | Out-File -LiteralPath $staged -Encoding utf8 -NoNewline

            # default_shell만 destination 우선의 예외다. herdr가 스스로 기록하는
            # default_shell = "" 는 사용자 선택이 아니라 placeholder인데, destination이
            # 이기면 그 빈 값이 주입한 Git Bash 경로를 영구히 덮는다 — herdr를 한 번이라도
            # 띄운 머신에서는 이 배포가 아무 효과 없이 pane이 PowerShell 5.1로 떨어진다.
            # 비어 있거나("") 키가 없을 때만 다시 채운다. 사용자가 넣은 실제 경로는 보존한다.
            if ($gitBash) {
                $current = (& yq -p=toml -o=json '.terminal.default_shell' $staged 2>$null | Out-String).Trim()
                if ($LASTEXITCODE -eq 0 -and ($current -eq '""' -or $current -eq 'null' -or -not $current)) {
                    & yq -i -p=toml -o=toml ".terminal.default_shell = `"$shellPath`"" $staged 2>$null
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host '    [!] Could not restore herdr default_shell, keeping existing herdr config.toml'
                        return
                    }
                }
            }

            & yq -p=toml -o=json '.' $staged 2>$null | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Host '    [!] merged herdr config.toml is invalid, keeping existing herdr config.toml'
                return
            }
        }
        if ($script:FunctionsOnlyMode -and -not $script:ReceiptReady) {
            Copy-Item -LiteralPath $staged -Destination $dst -Force
            Write-Host '    Deployed herdr config.toml'
        } elseif (Install-ManagedFile $staged $dst Takeover) {
            Write-Host '    Deployed herdr config.toml (existing values preserved)'
        }
    } finally {
        Remove-Item -LiteralPath $staged -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------
# Antigravity CLI(agy): 공식 installer에 맡기고, 설정만 이 저장소가 소유한다.
#
# herdr와 같은 예외이며 근거도 같은 모양이다.
#  1. CLI가 스스로 업데이트한다. 공식 installer가 "The Antigravity CLI automatically
#     self-updates in the background during regular runs"라고 직접 밝힌다. receipt로
#     바이너리를 잡으면 첫 실행 직후 해시가 어긋나 "changed; preserving"으로 굳는다.
#  2. pin할 대상이 없다. 배포가 버전 없는 auto-updater manifest 엔드포인트를 거치고,
#     GitHub 릴리즈는 2~3일에 하나씩 나온다.
#
# winget에도 Google.AntigravityCLI가 있지만 쓰지 않는다. Google이 올린 것이 아니라
# 봇(YamlCreate Dumplings Mod)이 만든 커뮤니티 manifest이고, portable 타입이라
# 바이너리가 다른 두 OS와 또 다른 자리(WinGet Packages/Links)에 놓인다. 게다가 위
# 1번 때문에 winget이 기록한 버전은 첫 실행 직후 낡는다.
# ---------------------------------------------
$AgyInstallUrl = 'https://antigravity.google/cli/install.ps1'
$AgyBinDir     = Join-Path $env:LOCALAPPDATA 'agy\bin'

function Get-AgyCommand {
    $cmd = Get-Command agy -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $known = Join-Path $AgyBinDir 'agy.exe'
    if (Test-Path -LiteralPath $known -PathType Leaf) { return $known }
    return $null
}

function Install-AgyCli {
    $existing = Get-AgyCommand
    if ($existing) {
        Write-Host "    Antigravity CLI already installed: $existing"
        Write-Host "    agy manages its own updates (background self-update on regular runs)."
        return $true
    }
    # 실패는 경고로만 남긴다(Add-InstallFailure 아님) — herdr와 같은 이유다. 소유하지
    # 않기로 한 서드파티 CDN의 일시적 장애가 dotfiles 설치 전체를 실패로 만들지 않는다.
    Write-Host "    Running the official Antigravity CLI installer: $AgyInstallUrl"
    try {
        $agyInstaller = Invoke-RestMethod -Uri $AgyInstallUrl -UseBasicParsing
    } catch {
        Write-Host "    [!] Antigravity CLI installer download failed: $AgyInstallUrl"
        return $false
    }
    if (-not $agyInstaller) {
        Write-Host "    [!] Antigravity CLI installer returned an empty script: $AgyInstallUrl"
        return $false
    }
    # herdr와 같은 이유로 자식 프로세스에 격리한다. 이 installer도 sourcing이 아닐 때
    # 최상위에서 `exit $exitCode`를 호출하므로, 같은 프로세스에서 돌리면 그 exit가
    # try/catch를 무시하고 install.ps1 자체를 끝낸다 — 이후 단계(Codex, Claude,
    # 프로파일, skills, plugins)가 통째로 건너뛰어지고 종료 코드는 0이라 성공으로 보인다.
    $pwshExe = Join-Path $PSHOME 'pwsh.exe'
    if (-not (Test-Path -LiteralPath $pwshExe -PathType Leaf)) {
        Write-Host "    [!] Antigravity CLI installer skipped: could not locate pwsh.exe in $PSHOME"
        return $false
    }
    $installerFile = Join-Path ([IO.Path]::GetTempPath()) ("agy-install-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    try {
        Set-Content -LiteralPath $installerFile -Value $agyInstaller -Encoding utf8
        & $pwshExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $installerFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [!] Antigravity CLI installer failed (exit $LASTEXITCODE): $AgyInstallUrl"
            return $false
        }
    } catch {
        Write-Host "    [!] Antigravity CLI installer failed: $($_.Exception.Message)"
        return $false
    } finally {
        Remove-Item -LiteralPath $installerFile -Force -ErrorAction SilentlyContinue
    }
    # installer가 User PATH를 고쳐도 현재 프로세스에는 반영되지 않는다. 뒤따르는
    # 3-3(rhwp)이 `Get-Command agy`로 Gemini MCP 등록 여부를 판단하므로 이번 세션
    # PATH에만 얹는다.
    if ((Test-Path -LiteralPath $AgyBinDir) -and (($env:PATH -split ';') -notcontains $AgyBinDir)) {
        $env:PATH = "$AgyBinDir;$env:PATH"
    }
    $installed = Get-AgyCommand
    if (-not $installed) {
        Write-Host '    [!] Antigravity CLI installer finished but agy was not found.'
        return $false
    }
    Write-Host "    Antigravity CLI installed: $installed"
    return $true
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
        $LockBlockers = @{
            'Git.Git'          = @('bash', 'sh', 'ssh', 'git')
            'marlocarlo.psmux' = @('tmux')
        }

        $WingetLogDir = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir"

        $packageStates = Get-ManifestLines $wingetFile | ForEach-Object {
            $listOut = (winget list --id $_ --exact --accept-source-agreements 2>&1 | Out-String)
            $present = $LASTEXITCODE -eq 0
            $version = if ($present) { Get-WingetVersion $listOut $_ } else { '' }
            if (-not (Begin-ManagedPackage "winget:$_" $present $version)) { throw "winget receipt journal failed: $_" }
            [pscustomobject]@{ Package = $_; BeforePresent = $present; BeforeVersion = $version }
        }

        # 사전 점검: 실제 설치(미설치) 또는 업그레이드 대상인 패키지만 잠금 프로세스를 검사한다.
        #   Git.Git(Inno Setup) — bash/ssh가 살아 있으면 exit 1 → 0x8A150006
        #   marlocarlo.psmux(portable) — tmux.exe 교체 시 "Access is denied" → 0x8A150052
        $upgradeList = $null
        foreach ($entry in $LockBlockers.GetEnumerator()) {
            $pkgState = $packageStates | Where-Object { $_.Package -eq $entry.Key } | Select-Object -First 1
            if (-not $pkgState) { continue }

            $needsAction = $false
            if (-not $pkgState.BeforePresent) {
                $needsAction = $true
            } else {
                if ($null -eq $upgradeList) {
                    $upgradeList = (winget list --upgrade-available --accept-source-agreements 2>&1 | Out-String)
                }
                if ($upgradeList -match "(?m)^\s*.*\s+$([regex]::Escape($entry.Key))\s+") {
                    $needsAction = $true
                }
            }

            if ($needsAction) {
                $running = @($entry.Value |
                    ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } |
                    Group-Object ProcessName |
                    ForEach-Object { "$($_.Name) x$($_.Count)" })
                if ($running.Count -gt 0) {
                    Write-Host "    [warn] $($entry.Key): 파일을 잠그는 프로세스 실행 중 — $($running -join ', ')"
                    Write-Host "           업그레이드 실패 시 해당 프로세스 종료 후 재실행 필요."
                }
            }
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
                if ($hex -eq '8A150006' -or $hex -eq '8A150052') {
                    $blockers = $using:LockBlockers
                    if ($blockers -and $blockers.ContainsKey($package)) {
                        $running = @($blockers[$package] |
                            ForEach-Object { Get-Process -Name $_ -ErrorAction SilentlyContinue } |
                            Group-Object ProcessName |
                            ForEach-Object { "$($_.Name) x$($_.Count)" })
                        if ($running.Count -gt 0) {
                            Write-Host "           잠금 의심 프로세스: $($running -join ', ') (해당 프로세스 종료 후 재실행 필요)"
                        }
                    }
                }
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

        # WinGet 포터블 패키지 설치 후 dead path 및 중복 정리 (User PATH 2047자 초과 방지)
        try {
            $cleanEnvScript = Join-Path $ROOT "scripts\clean-env.ps1"
            if (Test-Path -LiteralPath $cleanEnvScript) {
                & $cleanEnvScript -Apply | Out-Null
            }
        } catch {
            Write-Warning "User PATH 환경변수 정리 중 알림: $_"
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
# 1-7. herdr 설치 + 설정 배포 (config\herdr\config.windows.toml → %APPDATA%\herdr)
#
# winget 단계 뒤에 둔다 — 설정 병합에 yq가 필요하다.
# =============================================
Invoke-OptionalInstallStage 'SKIP_HERDR' "==> [CI] Skipping herdr (SKIP_HERDR=1)" {
    Write-Host ""
    Write-Host "==> Installing herdr and deploying config..."
    if (Install-Herdr) { Deploy-HerdrConfig }
}

# =============================================
# 1-8. shellcheck 설치 (manifests\shellcheck.tsv → ~\.local\bin\shellcheck.exe)
#
# CI(pr-gate.yml의 lint 잡)와 같은 pinned 버전을 쓴다.
# =============================================
Invoke-OptionalInstallStage 'SKIP_SHELLCHECK' "==> [CI] Skipping shellcheck (SKIP_SHELLCHECK=1)" {
    Write-Host ""
    Write-Host "==> Installing pinned shellcheck..."
    $null = Install-ShellCheck
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
    $npmPrefixRaw = npm prefix -g 2>$null
    $npmPrefixStatus = $LASTEXITCODE
    # fnm multishell 링크를 풀어 셸 간 안정적인 prefix로 기록한다.
    # uninstall의 npm prefix allowlist는 `<fnm_root>\node-versions\<version>\installation`만 받는다.
    $npmPrefix = Resolve-ManagedLinkPath $npmPrefixRaw
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
            if (-not (Begin-ManagedPackage "npm:$_" ([bool]$beforeVersion) $beforeVersion $npmPrefix)) {
                # 소유권을 판정할 수 없는 패키지 하나 때문에 이후 설치 단계 전체를 중단하지 않는다.
                Add-InstallFailure "npm receipt journal failed; skipping package: $_"
                return
            }
            [pscustomobject]@{ Package = $_; BeforeVersion = $beforeVersion }
        }
        $npmResults = @($npmStates) | Where-Object { $_ } | ForEach-Object -Parallel {
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
    $script:ClaudeSettingsDeployed = $script:LastJsonRegistryDeployed
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

# skill은 이 저장소가 배포하지 않는다 — 전부 manifests\skills.txt의 npx skills 설치다 (6단계).

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
# 3-2. Antigravity CLI(agy) 설치 + 설정 배포 (config/agy/ + config/agents/global.md → ~/.gemini/)
#
# CLI를 먼저 세운다. 뒤따르는 3-3(rhwp)이 `Get-Command agy`로 Gemini MCP 등록 여부를
# 판단하므로, 순서가 뒤집히면 첫 설치에서 MCP 등록이 조용히 건너뛰어진다.
# 바이너리(SKIP_AGY_CLI)와 설정(SKIP_AGY)은 소유자가 달라 플래그도 따로 둔다.
# =============================================
Invoke-OptionalInstallStage 'SKIP_AGY_CLI' "==> [CI] Skipping Antigravity CLI (SKIP_AGY_CLI=1)" {
    Write-Host ""
    Write-Host "==> Installing Antigravity CLI (agy)..."
    $null = Install-AgyCli
}

Write-Host ""
Invoke-OptionalInstallStage 'SKIP_AGY' "==> [CI] Skipping Antigravity (AGY) config (SKIP_AGY=1)" {
    Write-Host "==> Deploying Antigravity (AGY) config..."
    New-Item -ItemType Directory -Force -Path $GeminiDir | Out-Null
    New-Item -ItemType Directory -Force -Path $GeminiConfigDir | Out-Null

    if (Test-Path $agentsGlobalSrc) {
        if (Install-ManagedFile $agentsGlobalSrc (Join-Path $GeminiConfigDir "GEMINI.md") Takeover) {
            Write-Host "    Copied global agent instructions to ~/.gemini/config/GEMINI.md"
        }
        if (Install-ManagedFile $agentsGlobalSrc (Join-Path $GeminiDir "GEMINI.md") Takeover) {
            Write-Host "    Copied global agent instructions to ~/.gemini/GEMINI.md"
        }
    } else {
        Write-Host "    [!] config\agents\global.md not found"
    }

    $agyHooksJsonSrc = Join-Path $ROOT "config\agy\hooks.json"
    $agyHooksJsonDst = Join-Path $GeminiConfigDir "hooks.json"
    if (Test-Path $agyHooksJsonSrc) {
        Merge-JsonRegistry $agyHooksJsonSrc $agyHooksJsonDst
    } else {
        Write-Host "    [!] config\agy\hooks.json not found"
    }

    $agyHooksSrc = Join-Path $ROOT "config\agy\hooks"
    $agyHooksDst = Join-Path $GeminiDir "hooks"
    if (Test-Path $agyHooksSrc) {
        if (Install-ManagedTree $agyHooksSrc $agyHooksDst Skip) { Write-Host "    Copied hooks/ to ~/.gemini/hooks/" }
    } else {
        Write-Host "    [!] config\agy\hooks not found, skipping."
    }

}

# =============================================
# 3-3. rhwp 설치 + MCP 등록 (manifests\rhwp.tsv → ~\rhwp, Codex/Claude/Gemini MCP)
#
# Claude Code / Antigravity 설치 뒤에 둔다.
# =============================================
Invoke-OptionalInstallStage 'SKIP_RHWP' "==> [CI] Skipping rhwp (SKIP_RHWP=1)" {
    Write-Host ""
    Write-Host "==> Installing rhwp and registering MCP..."
    $null = Install-Rhwp
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
# 6. Claude skills 설치·업데이트 (manifests/skills.txt)
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

# 플러그인 CLI가 settings.json을 자기 형식으로 다시 쓰므로 3-1이 기록한 해시가 낡는다.
# 3-1이 실제로 배포한 경우에만 갱신한다 — 보존으로 끝난 파일까지 소유권에 넣지 않는다.
if ($script:ClaudeSettingsDeployed -and (Sync-ManagedFileHash (Join-Path $ClaudeDir 'settings.json'))) {
    Write-Host "    Refreshed settings.json ownership hash."
}

if (-not (Complete-Install)) { exit 1 }
exit 0
