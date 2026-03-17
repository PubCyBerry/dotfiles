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

Write-Host ""
Write-Host "==> Done! Restart your terminal."
