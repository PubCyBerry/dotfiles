# Windows setup script
# Run in PowerShell as Administrator

$packages = @(
    "Git.Git",
    "GitHub.cli",
    "Schniz.fnm",
    "Microsoft.WindowsTerminal",
    # Modern CLI
    "sharkdp.bat",
    "junegunn.fzf",
    "eza-community.eza",
    "sharkdp.fd",
    "dandavison.delta",
    "BurntSushi.ripgrep.MSVC",
    "Oven-sh.Bun"
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

Write-Host ""
Write-Host "==> Done! Restart your terminal."
