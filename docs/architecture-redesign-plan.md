# Dotfiles Redesign Plan: Component-First Optimization

## Objective
Redesign the dotfiles project structure to improve maintainability, consistency, and optimization across Windows, MacOS, and Ubuntu platforms. The strategy focuses on a "Component-First" directory structure, unified Unix installation scripts, automated GitHub Actions testing, and maintaining a clear history of changes.

## Background & Motivation
The current project structure handles platforms inconsistently:
- **Windows/Ubuntu:** Managed via root-level scripts (`install.ps1`, `install.sh`), central `manifests/` (apt, winget), and a mix of OS-specific (`config/windows`) and component-specific (`config/bash`) configs.
- **MacOS:** Isolated in a `macos/` directory containing its own `install.sh`, `Brewfile`, and `.macos` configurations, completely bypassing the root `install.sh` logic.
This makes maintaining cross-platform features, syncing updates, and understanding the project's entry points difficult.

## Key Files & Context
- **Manifests:** `manifests/apt.txt`, `manifests/winget.txt`, `macos/Brewfile`
- **Configs:** `config/linux/tmux.conf`, `config/windows/tmux.conf`, `config/windows/profile.ps1`, `macos/.macos`
- **Scripts:** `install.sh`, `install.ps1`, `macos/install.sh`
- **Documentation:** `docs/`

## Proposed Solution & Implementation Steps

### Phase 1: Unify Manifests
Centralize all package manager dependencies into the `manifests/` directory.
1. Move `macos/Brewfile` to `manifests/Brewfile` (or `manifests/brew.txt` for naming consistency).
2. Ensure `manifests/apt.txt`, `manifests/winget.txt`, and `manifests/npm-global.txt` are clean and explicitly referenced.

### Phase 2: Component-First Configuration Restructure
Eliminate OS-centric configuration folders (`config/linux`, `config/windows`) in favor of app-centric folders.
1. **Tmux:** Create `config/tmux/`. Move `config/linux/tmux.conf` to `config/tmux/tmux.linux.conf` and `config/windows/tmux.conf` to `config/tmux/tmux.windows.conf`.
2. **PowerShell:** Create `config/powershell/`. Move `config/windows/profile.ps1` to `config/powershell/profile.ps1`.
3. **MacOS Defaults:** Create `config/macos/`. Move `macos/.macos` to `config/macos/.macos`.
4. Delete the now-empty `config/linux/`, `config/windows/`, and `macos/` directories.

### Phase 3: Unified Installers
Standardize the entry points for the dotfiles.
1. **Windows:** Retain `install.ps1` as the dedicated Windows entry point. Update references to `config/windows/profile.ps1` and `config/windows/tmux.conf` to their new locations.
2. **Unix (Ubuntu + MacOS):** Modify the root `install.sh` to handle both Ubuntu and MacOS using `uname -s`.
   - **Linux logic:** Keep existing apt, github-releases, and path setups.
   - **MacOS logic:** Integrate Homebrew installation, read `manifests/Brewfile`, and optionally run `config/macos/.macos`.
   - **Shared logic:** Execute shared setup for bash/inputrc, node (fnm), Claude native, Neovim, Yazi, Starship, and Git configurations for both Unix-like platforms.

### Phase 4: Documentation & History Tracking
Ensure architectural decisions and task progress are permanently recorded.
1. Save this finalized plan as `docs/architecture-redesign-plan.md`.
2. Create a `docs/work-history.md` (or similar changelog) to record the step-by-step implementation details of this redesign.

## Verification & Testing (Automated via GitHub Actions)
Instead of manual verification, testing will be fully automated through GitHub Actions workflows (e.g., in `.github/workflows/`):
1. **Windows Workflow:** A matrix job running `install.ps1` on `windows-latest` to ensure no syntax errors and successful execution of PowerShell/winget setups.
2. **Ubuntu Workflow:** A matrix job running `install.sh` on `ubuntu-latest` to verify `apt` and GitHub release binary workflows.
3. **MacOS Workflow:** A matrix job running `install.sh` on `macos-latest` to verify Homebrew bundle success and proper shared config deployment.
These workflows will be implemented to run on PRs and main branch pushes.