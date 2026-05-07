# Windows dotfiles installer/updater.
# Usage: pwsh -ExecutionPolicy Bypass -File .\install.ps1 [-Profile default] [-Only configs] [-Skip claude,rtk,skills] [-DryRun]

$ErrorActionPreference = "Stop"
Set-ExecutionPolicy Bypass -Scope Process -Force

$ROOT = $PSScriptRoot
$Profile = "default"
$Only = ""
$Skip = ""
$script:DryRun = $false

$i = 0
while ($i -lt $args.Count) {
    $arg = [string]$args[$i]
    if ($arg -eq "--profile" -or $arg -eq "-Profile") {
        $i++
        $Profile = [string]$args[$i]
    } elseif ($arg.StartsWith("--profile=")) {
        $Profile = $arg.Substring("--profile=".Length)
    } elseif ($arg -eq "--only" -or $arg -eq "-Only") {
        $i++
        $Only = [string]$args[$i]
    } elseif ($arg.StartsWith("--only=")) {
        $Only = $arg.Substring("--only=".Length)
    } elseif ($arg -eq "--skip" -or $arg -eq "-Skip") {
        $i++
        $Skip = [string]$args[$i]
    } elseif ($arg.StartsWith("--skip=")) {
        $Skip = $arg.Substring("--skip=".Length)
    } elseif ($arg -eq "--dry-run" -or $arg -eq "-DryRun") {
        $script:DryRun = $true
    } elseif ($arg -eq "--help" -or $arg -eq "-h") {
        Write-Host "Usage: .\install.ps1 [--profile minimal|default|full] [--only steps] [--skip steps] [--dry-run]"
        exit 0
    } else {
        throw "Unknown option: $arg"
    }
    $i++
}

if (@("minimal", "default", "full") -notcontains $Profile) {
    throw "Invalid profile: $Profile"
}
$script:OnlySteps = @()
$script:SkipSteps = @()
$script:OnlyCsv = $Only
$script:SkipCsv = $Skip
if ($Only) { $script:OnlySteps = $Only -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
if ($Skip) { $script:SkipSteps = $Skip -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
if ($Profile -eq "minimal" -and $script:OnlySteps.Count -eq 0) {
    $script:OnlySteps = @("packages", "configs")
}

. (Join-Path $ROOT "scripts\install\lib.ps1")

function Is-StepEnabled([string]$Step) {
    $onlyItems = @()
    $skipItems = @()
    if ($Only) { $onlyItems = $Only -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
    if ($Skip) { $skipItems = $Skip -split '[,\s]+' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }
    if ($onlyItems.Count -gt 0 -and -not ($onlyItems -contains $Step)) { return $false }
    if ($skipItems -contains $Step) { return $false }
    return $true
}

$ClaudeDir = Join-Path $env:USERPROFILE ".claude"
$LocalBin = Join-Path $env:USERPROFILE ".local\bin"
$NvimConfigDir = Join-Path $env:LOCALAPPDATA "nvim"
$NvimBin = "C:\Program Files\Neovim\bin"
$GitBashPaths = @(
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
)
$GitFileExePaths = @(
    "C:\Program Files\Git\usr\bin\file.exe",
    "C:\Program Files (x86)\Git\usr\bin\file.exe"
)

Write-Step "Windows dotfiles setup starting"
Write-Host "    Source:  $ROOT"
Write-Host "    Profile: $Profile"
if (Test-DryRun) { Write-Host "    Mode:    dry-run" }
Write-Host "    Backup:  $script:DotfilesBackupRoot"

function Install-Packages {
    Write-Step "Installing packages via winget"
    $wingetFile = Join-Path $ROOT "manifests\winget.txt"
    if (-not (Test-Path $wingetFile)) {
        Write-Warn "manifests\winget.txt not found, skipping"
        return
    }
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Warn "winget not found, skipping package installation"
        return
    }

    foreach ($package in (Get-ManifestLines $wingetFile)) {
        if (Test-DryRun) {
            Write-Skip "Would winget install --id $package"
            continue
        }
        $alreadyInstalled = @(0x8A150015, 43, -1978335189)
        winget install --id $package --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Installed $package"
        } elseif ($alreadyInstalled -contains $LASTEXITCODE) {
            Write-Skip "Already installed $package"
        } else {
            Write-Warn "Failed: $package (exit: $LASTEXITCODE)"
        }
    }
}

function Deploy-Configs {
    Write-Step "Deploying config files"
    Merge-GitConfig (Join-Path $ROOT "config\git\gitconfig")
    Invoke-DotfilesCommand -Description "git config --global core.autocrlf true" -ScriptBlock {
        git config --global core.autocrlf true
    }
    Invoke-DotfilesCommand -Description "git config --global core.fileMode false" -ScriptBlock {
        git config --global core.fileMode false
    }

    Copy-ManagedFile (Join-Path $ROOT "config\tmux\tmux.windows.conf") (Join-Path $env:USERPROFILE ".tmux.conf")

    Write-Step "Setting YAZI_FILE_ONE"
    $gitFileExe = $GitFileExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($gitFileExe) {
        Invoke-DotfilesCommand -Description "Set YAZI_FILE_ONE=$gitFileExe" -ScriptBlock {
            [System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $gitFileExe, "User")
            $env:YAZI_FILE_ONE = $gitFileExe
        }
        Write-Ok "YAZI_FILE_ONE = $gitFileExe"
    } else {
        Write-Warn "Git file.exe not found. Install Git for Windows first."
    }

    Copy-ManagedDirectory (Join-Path $ROOT "config\yazi") (Join-Path $env:APPDATA "yazi\config")
    if (Test-Path $NvimBin) {
        Add-ToUserPath $NvimBin
    } else {
        Write-Warn "Neovim not found at $NvimBin"
    }
    Copy-ManagedDirectory (Join-Path $ROOT "config\nvim") $NvimConfigDir
}

function Install-NodeAndNpm {
    Write-Step "Installing Node.js LTS"
    if (Get-Command fnm -ErrorAction SilentlyContinue) {
        if (Test-DryRun) {
            Write-Skip "Would install/use Node.js LTS via fnm"
        } else {
            fnm env --shell powershell | Out-String | Invoke-Expression
            fnm install --lts
            fnm default lts-latest
            fnm use lts-latest
            Write-Ok "Node.js LTS installed"
        }
    } else {
        Write-Warn "fnm not found. Restart terminal and run: fnm install --lts"
    }

    Write-Step "Installing global npm packages"
    $npmFile = Join-Path $ROOT "manifests\npm-global.txt"
    if (-not (Test-Path $npmFile)) {
        Write-Warn "manifests\npm-global.txt not found, skipping"
        return
    }
    if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Warn "npm not found, skipping"
        return
    }
    foreach ($package in (Get-ManifestLines $npmFile)) {
        if (Test-DryRun) {
            Write-Skip "Would npm install -g $package"
            continue
        }
        npm install -g $package 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Ok "Installed $package" } else { Write-Warn "Failed: $package" }
    }
}

function Install-Claude {
    if ($env:SKIP_CLAUDE_CODE -eq "1") {
        Write-Skip "Claude Code installation skipped (SKIP_CLAUDE_CODE=1)"
        return
    }

    Write-Step "Installing Claude Code and config"
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        Write-Skip "Claude Code already installed"
    } elseif (Test-DryRun) {
        Write-Skip "Would install Claude Code"
    } else {
        Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression
        Write-Ok "Claude Code installed"
    }

    if (-not (Test-DryRun)) { New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null }
    $settingsSrc = Join-Path $ROOT "config\claude\settings.json"
    $settingsDst = Join-Path $ClaudeDir "settings.json"
    if (Test-Path $settingsSrc) {
        Backup-Existing $settingsDst
        if (Test-DryRun) {
            Write-Skip "Would merge $settingsSrc -> $settingsDst"
        } else {
            $newSettings = Get-Content $settingsSrc -Raw | ConvertFrom-Json
            if (Test-Path $settingsDst) {
                $existing = Get-Content $settingsDst -Raw | ConvertFrom-Json
                foreach ($prop in $newSettings.PSObject.Properties) {
                    $existing | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
                }
                $existing | ConvertTo-Json -Depth 10 | Out-File $settingsDst -Encoding utf8 -NoNewline
                Write-Ok "Merged settings.json"
            } else {
                Copy-Item $settingsSrc $settingsDst -Force
                Write-Ok "Copied settings.json"
            }
        }
    }
    Copy-ManagedFile (Join-Path $ROOT "config\claude\CLAUDE.md") (Join-Path $ClaudeDir "CLAUDE.md")
}

function Install-RTK {
    if ($env:SKIP_RTK -eq "1") {
        Write-Skip "RTK installation skipped (SKIP_RTK=1)"
        return
    }

    Write-Step "Installing RTK"
    if (-not (Test-DryRun)) { New-Item -ItemType Directory -Force -Path $LocalBin | Out-Null }
    Add-ToUserPath $LocalBin
    if (Get-Command rtk -ErrorAction SilentlyContinue) {
        Write-Skip "RTK already installed"
        return
    }
    if (Test-DryRun) {
        Write-Skip "Would install RTK from GitHub releases"
        return
    }
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
        $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -match "\.zip$" } | Select-Object -First 1
        if ($asset) {
            $tmpZip = Join-Path $env:TEMP "rtk-windows.zip"
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmpZip -UseBasicParsing
            Expand-Archive -Path $tmpZip -DestinationPath $LocalBin -Force
            Remove-Item $tmpZip -Force
            Write-Ok "RTK installed"
        } else {
            Write-Warn "RTK Windows binary not found. Manual: cargo install rtk"
        }
    } catch {
        Write-Warn "RTK install failed: $_"
    }
}

function Update-Profiles {
    Write-Step "Updating PowerShell profile"
    $profileSrc = Join-Path $ROOT "config\powershell\profile.ps1"
    if (Test-Path $profileSrc) {
        $profileContent = Get-Content $profileSrc -Raw
        $claudeAlias = "function global:ccd { claude --dangerously-skip-permissions @args }"
        $block = "$profileContent`n$claudeAlias"
        Set-ProfileBlock "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" $block
    } else {
        Write-Warn "config\powershell\profile.ps1 not found, skipping"
    }

    Write-Step "Updating Git Bash profile"
    $bashrcSrc = Join-Path $ROOT "config\bash\bashrc"
    if (-not (Test-Path $bashrcSrc)) {
        Write-Warn "config\bash\bashrc not found, skipping"
        return
    }
    $gitBashFound = $GitBashPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $gitBashFound) {
        Write-Warn "Git Bash not found. Install Git for Windows first."
        return
    }
    Set-ProfileBlock (Join-Path $env:USERPROFILE ".bashrc") (Get-Content $bashrcSrc -Raw)
    $inputrcSrc = Join-Path $ROOT "config\bash\inputrc"
    if (Test-Path $inputrcSrc) {
        Set-ProfileBlock (Join-Path $env:USERPROFILE ".inputrc") (Get-Content $inputrcSrc -Raw)
    }
    $bashProfilePath = Join-Path $env:USERPROFILE ".bash_profile"
    if (-not (Test-Path $bashProfilePath)) {
        if (Test-DryRun) {
            Write-Skip "Would create $bashProfilePath"
        } else {
            Set-Content $bashProfilePath "[[ -f ~/.bashrc ]] && . ~/.bashrc" -Encoding utf8
            Write-Ok "Created $bashProfilePath"
        }
    }
}

function Install-Skills {
    if ($env:SKIP_SKILLS -eq "1") {
        Write-Skip "Claude Code skills skipped (SKIP_SKILLS=1)"
        return
    }

    Write-Step "Restoring Claude Code skills"
    $skillsFile = Join-Path $ROOT "manifests\skills.txt"
    if (-not (Test-Path $skillsFile)) {
        Write-Warn "manifests\skills.txt not found, skipping"
        return
    }
    if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
        Write-Warn "npx not found, skipping"
        return
    }
    foreach ($line in (Get-ManifestLines $skillsFile)) {
        if ($line -match '^([^@]+)@(.+)$') {
            $repoSlug = $Matches[1]
            $skillName = $Matches[2]
            if (Test-DryRun) {
                Write-Skip "Would add skill $repoSlug@$skillName"
            } else {
                npx -y skills add $repoSlug --skill $skillName --global --yes --agent claude-code 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { Write-Ok "Added $repoSlug@$skillName" } else { Write-Warn "Failed: $repoSlug@$skillName" }
            }
        }
    }
}

if (Is-StepEnabled "packages") { Install-Packages } else { Write-Skip "packages step skipped" }
if (Is-StepEnabled "configs") {
    Deploy-Configs
    Update-Profiles
} else {
    Write-Skip "configs step skipped"
}
if (Is-StepEnabled "node") { Install-NodeAndNpm } else { Write-Skip "node step skipped" }
if (Is-StepEnabled "claude") { Install-Claude } else { Write-Skip "claude step skipped" }
if (Is-StepEnabled "rtk") { Install-RTK } else { Write-Skip "rtk step skipped" }
if (Is-StepEnabled "skills") { Install-Skills } else { Write-Skip "skills step skipped" }

Write-Step "Done"
Write-Ok "Restart your terminal and Claude Code to apply all changes."
