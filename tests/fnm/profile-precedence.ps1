$ErrorActionPreference = "Stop"
$repoRoot = Split-Path (Split-Path $PSScriptRoot)
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "dotfiles-fnm-$([guid]::NewGuid())"
$oldPath = $env:PATH
$oldHome = $env:USERPROFILE
$oldAppData = $env:APPDATA
$oldFnmDir = $env:FNM_DIR
$oldFunctionsOnly = $env:DOTFILES_FUNCTIONS_ONLY
$oldPrune = $env:DOTFILES_PRUNE_NODE_VERSIONS

try {
    $stubBin = Join-Path $testRoot "stub-bin"
    $env:USERPROFILE = Join-Path $testRoot "home"
    $env:APPDATA = Join-Path $testRoot "unused-appdata"
    $env:FNM_DIR = Join-Path $testRoot "custom fnm"
    $fallback = Join-Path $env:FNM_DIR "node-versions\v22.18.0\installation"
    $oldFallback = Join-Path $env:FNM_DIR "node-versions\v9.11.2\installation"
    New-Item -ItemType Directory -Force $stubBin, $fallback, $oldFallback | Out-Null
    New-Item -ItemType File -Force (Join-Path $fallback "node.exe") | Out-Null
    New-Item -ItemType File -Force (Join-Path $oldFallback "node.exe") | Out-Null
    @'
@echo off
echo $env:PATH = 'C:\fnm-multishell;' + $env:PATH
'@ | Set-Content (Join-Path $stubBin "fnm.cmd") -Encoding ascii
    $env:PATH = "$stubBin;$env:SystemRoot\System32"
    $env:DOTFILES_FUNCTIONS_ONLY = "1"
    . (Join-Path $repoRoot "install.ps1")
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY

    & (Join-Path $repoRoot "config\powershell\profile.ps1")
    & (Join-Path $repoRoot "config\powershell\profile.ps1")
    $parts = $env:PATH -split ';'
    $multishellIndex = [Array]::IndexOf($parts, 'C:\fnm-multishell')
    $fallbackIndex = [Array]::IndexOf($parts, $fallback)
    if ($multishellIndex -lt 0 -or $fallbackIndex -lt 0 -or $multishellIndex -ge $fallbackIndex) {
        throw "fnm multishell path must precede the direct fallback"
    }
    if (@($parts | Where-Object { $_ -eq $fallback }).Count -ne 1) {
        throw "direct fallback must be added exactly once"
    }
    if ($parts -contains (Join-Path $env:APPDATA "fnm\node-versions\v22.18.0\installation")) {
        throw "FNM_DIR must override APPDATA/fnm"
    }

    $settings = Join-Path $testRoot "settings.json"
    $staleBackslash = Join-Path $env:FNM_DIR "node-versions\v18.20.0\installation\node.exe"
    @{ statusLine = @{ command = "$staleBackslash --hud" } } |
        ConvertTo-Json -Depth 3 | Set-Content $settings -Encoding utf8 -NoNewline
    $firstOutput = (Update-FnmStatusLine $settings $env:FNM_DIR "v22.18.0" 6>&1 | Out-String)
    if ($firstOutput -notmatch 'Patched statusLine node path') { throw "actual update must log success" }
    $expectedNode = Join-Path $fallback "node.exe"
    if ((Get-Content $settings -Raw | ConvertFrom-Json).statusLine.command -ne "$expectedNode --hud") {
        throw "backslash/node.exe statusLine was not updated"
    }
    $before = (Get-FileHash $settings -Algorithm SHA256).Hash
    $secondOutput = (Update-FnmStatusLine $settings $env:FNM_DIR "v22.18.0" 6>&1 | Out-String)
    if ($secondOutput -match 'Patched statusLine node path') { throw "no-op update must not log success" }
    if ($before -ne (Get-FileHash $settings -Algorithm SHA256).Hash) {
        throw "no-op update must preserve settings bytes"
    }

    $missingOutput = (Update-FnmStatusLine $settings $env:FNM_DIR "v99.0.0" 6>&1 | Out-String)
    if ($missingOutput -match 'Patched statusLine node path' -or
        $before -ne (Get-FileHash $settings -Algorithm SHA256).Hash) {
        throw "missing target must preserve settings without success log"
    }

    $slashRoot = $env:FNM_DIR -replace '\\', '/'
    @{ statusLine = @{ command = "$slashRoot/node-versions/v18.20.0/installation/bin/node --hud" } } |
        ConvertTo-Json -Depth 3 | Set-Content $settings -Encoding utf8 -NoNewline
    $null = Update-FnmStatusLine $settings $env:FNM_DIR "v22.18.0"
    if ((Get-Content $settings -Raw | ConvertFrom-Json).statusLine.command -ne "$expectedNode --hud") {
        throw "slash/installation/bin/node statusLine was not updated"
    }
    Set-Content $settings '{invalid' -Encoding utf8 -NoNewline
    $malformed = (Get-FileHash $settings -Algorithm SHA256).Hash
    $malformedOutput = (Update-FnmStatusLine $settings $env:FNM_DIR "v22.18.0" 6>&1 | Out-String)
    if ($malformedOutput -match 'Patched statusLine node path' -or
        $malformed -ne (Get-FileHash $settings -Algorithm SHA256).Hash) {
        throw "malformed settings must remain unchanged without success log"
    }
    Set-Content $settings '[]' -Encoding utf8 -NoNewline
    $nonObject = (Get-FileHash $settings -Algorithm SHA256).Hash
    $nonObjectOutput = (Update-FnmStatusLine $settings $env:FNM_DIR "v22.18.0" 6>&1 | Out-String)
    if ($nonObjectOutput -match 'Patched statusLine node path' -or
        $nonObject -ne (Get-FileHash $settings -Algorithm SHA256).Hash) {
        throw "non-object settings must remain unchanged without success log"
    }

    $pruneLog = Join-Path $testRoot "prune.log"
    function global:fnm {
        if ($args[0] -eq 'current') { 'v22.18.0' }
        elseif ($args[0] -eq 'list') { 'v18.20.0'; 'v22.18.0' }
        elseif ($args[0] -eq 'uninstall') { Add-Content $pruneLog $args[1]; $global:LASTEXITCODE = 0 }
    }
    Remove-Item Env:DOTFILES_PRUNE_NODE_VERSIONS -ErrorAction SilentlyContinue
    Invoke-FnmPruneIfRequested
    if (Test-Path $pruneLog) { throw "default install must not prune Node versions" }
    $env:DOTFILES_PRUNE_NODE_VERSIONS = "1"
    Invoke-FnmPruneIfRequested
    if ((Get-Content $pruneLog -Raw).Trim() -ne 'v18.20.0') { throw "opt-in prune did not remove only the inactive version" }
    Remove-Item function:fnm
    Write-Output "PASS: fnm multishell selection precedes the direct fallback"
} finally {
    $env:PATH = $oldPath
    $env:USERPROFILE = $oldHome
    $env:APPDATA = $oldAppData
    if ($null -eq $oldFnmDir) { Remove-Item Env:FNM_DIR -ErrorAction SilentlyContinue } else { $env:FNM_DIR = $oldFnmDir }
    if ($null -eq $oldFunctionsOnly) { Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue } else { $env:DOTFILES_FUNCTIONS_ONLY = $oldFunctionsOnly }
    if ($null -eq $oldPrune) { Remove-Item Env:DOTFILES_PRUNE_NODE_VERSIONS -ErrorAction SilentlyContinue } else { $env:DOTFILES_PRUNE_NODE_VERSIONS = $oldPrune }
    Remove-Item function:fnm -ErrorAction SilentlyContinue
    Remove-Item $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
