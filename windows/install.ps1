# Windows setup script
# Run in PowerShell as Administrator

$packages = @(
    "Git.Git",
    "GitHub.cli",
    "Schniz.fnm",
    "Microsoft.WindowsTerminal",
    # Modern CLI (기존)
    "sharkdp.bat",
    "junegunn.fzf",
    "eza-community.eza",
    "sharkdp.fd",
    "dandavison.delta",
    "BurntSushi.ripgrep.MSVC",
    "Oven-sh.Bun",
    "jqlang.jq",
    # 추가 CLI 도구
    "ajeetdsouza.zoxide",
    "mikefarah.yq",
    "JesseDuffield.lazygit",
    "sxyazi.yazi",
    "Starship.Starship",
    "astral-sh.ruff",
    "httpie.httpie"
)

Write-Host "==> Installing packages via winget..."
foreach ($pkg in $packages) {
    Write-Host "    Installing $pkg..."
    winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements
}

# Node.js LTS + Claude Code 설치
Write-Host ""
Write-Host "==> Installing Node.js LTS and Claude Code..."
Write-Host "    Refreshing PATH to pick up fnm..."
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" +
            $env:PATH
if (Get-Command fnm -ErrorAction SilentlyContinue) {
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    npm install -g @anthropic-ai/claude-code
    Write-Host "    Claude Code installed."
} else {
    Write-Host "    [!] fnm not found. Restart terminal and run:"
    Write-Host "        fnm install --lts && fnm default lts-latest"
    Write-Host "        npm install -g @anthropic-ai/claude-code"
}

# RTK (Rust Token Killer) 설치
Write-Host ""
Write-Host "==> Installing RTK (Rust Token Killer)..."
$rtkDir = "$env:USERPROFILE\rtk"
$rtkExe = "$rtkDir\rtk.exe"
if (-not (Test-Path $rtkExe) -and -not (Test-Path "$rtkDir\rtk")) {
    # GitHub Releases에서 최신 Windows 바이너리 다운로드
    $releaseApi = "https://api.github.com/repos/rtk-ai/rtk/releases/latest"
    try {
        $release = Invoke-RestMethod -Uri $releaseApi -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            New-Item -ItemType Directory -Force -Path $rtkDir | Out-Null
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$rtkDir\rtk.zip"
            Expand-Archive -Path "$rtkDir\rtk.zip" -DestinationPath $rtkDir -Force
            Remove-Item "$rtkDir\rtk.zip" -Force
            # PATH에 추가 (User 범위)
            $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
            if ($userPath -notlike "*$rtkDir*") {
                [System.Environment]::SetEnvironmentVariable("PATH", "$rtkDir;$userPath", "User")
            }
            $env:PATH = "$rtkDir;$env:PATH"
            Write-Host "    RTK installed: $rtkDir"
        } else {
            Write-Host "    [!] RTK Windows binary not found in releases. Install manually from:"
            Write-Host "        https://github.com/rtk-ai/rtk/releases"
        }
    } catch {
        Write-Host "    [!] Failed to fetch RTK release info. Install manually."
    }
} else {
    Write-Host "    RTK already installed: $rtkExe"
}

# ast-grep / difftastic — winget 미지원, GitHub Releases에서 직접 다운로드
$toolsDir = "$env:USERPROFILE\.local\bin"
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null

# PATH에 $toolsDir 추가
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
if ($userPath -notlike "*$toolsDir*") {
    [System.Environment]::SetEnvironmentVariable("PATH", "$toolsDir;$userPath", "User")
}
$env:PATH = "$toolsDir;$env:PATH"

# ast-grep (sg.exe)
Write-Host ""
Write-Host "==> Installing ast-grep (sg)..."
if (-not (Test-Path "$toolsDir\sg.exe")) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/ast-grep/ast-grep/releases/latest" `
            -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$env:TEMP\ast-grep.zip"
            Expand-Archive -Path "$env:TEMP\ast-grep.zip" -DestinationPath "$env:TEMP\ast-grep" -Force
            $sgExe = Get-ChildItem -Path "$env:TEMP\ast-grep" -Recurse -Filter "sg.exe" | Select-Object -First 1
            if ($sgExe) {
                Move-Item $sgExe.FullName "$toolsDir\sg.exe" -Force
                Write-Host "    ast-grep installed: $toolsDir\sg.exe"
            }
            Remove-Item "$env:TEMP\ast-grep.zip", "$env:TEMP\ast-grep" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "    [!] ast-grep Windows binary not found. Install manually from:"
            Write-Host "        https://github.com/ast-grep/ast-grep/releases"
        }
    } catch {
        Write-Host "    [!] Failed to download ast-grep: $_"
    }
} else {
    Write-Host "    ast-grep already installed: $toolsDir\sg.exe"
}

# difftastic (difft.exe)
Write-Host ""
Write-Host "==> Installing difftastic (difft)..."
if (-not (Test-Path "$toolsDir\difft.exe")) {
    try {
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/Wilfred/difftastic/releases/latest" `
            -Headers @{Accept="application/vnd.github.v3+json"}
        $asset = $release.assets | Where-Object { $_.name -like "*x86_64-pc-windows-msvc*" } | Select-Object -First 1
        if ($asset) {
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile "$env:TEMP\difft.zip"
            Expand-Archive -Path "$env:TEMP\difft.zip" -DestinationPath "$env:TEMP\difft" -Force
            $difftExe = Get-ChildItem -Path "$env:TEMP\difft" -Recurse -Filter "difft.exe" | Select-Object -First 1
            if ($difftExe) {
                Move-Item $difftExe.FullName "$toolsDir\difft.exe" -Force
                Write-Host "    difftastic installed: $toolsDir\difft.exe"
            }
            Remove-Item "$env:TEMP\difft.zip", "$env:TEMP\difft" -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Host "    [!] difftastic Windows binary not found. Install manually from:"
            Write-Host "        https://github.com/Wilfred/difftastic/releases"
        }
    } catch {
        Write-Host "    [!] Failed to download difftastic: $_"
    }
} else {
    Write-Host "    difftastic already installed: $toolsDir\difft.exe"
}

Write-Host ""
Write-Host "==> Done! Restart your terminal."
