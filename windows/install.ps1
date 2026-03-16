# Windows setup script
# Run in PowerShell as Administrator

$packages = @(
    "Git.Git",
    "GitHub.cli",
    "Schniz.fnm",
    "Microsoft.WindowsTerminal"
)

Write-Host "==> Installing packages via winget..."
foreach ($pkg in $packages) {
    Write-Host "    Installing $pkg..."
    winget install --id $pkg --silent --accept-package-agreements --accept-source-agreements
}

Write-Host ""
Write-Host "==> Done! Restart your terminal."
