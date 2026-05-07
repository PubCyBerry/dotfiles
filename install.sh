#!/usr/bin/env bash
# Unix dotfiles installer/updater.
# Usage: bash install.sh [--profile minimal|default|full] [--only steps] [--skip steps] [--dry-run] [--with-defaults]

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/install/lib.sh
source "$ROOT/scripts/install/lib.sh"
trap cleanup_tmpfiles EXIT

OS="$(uname -s)"
ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
PROFILE="default"
APPLY_DEFAULTS=false
DOTFILES_ONLY=""
DOTFILES_SKIP=""
DOTFILES_DRY_RUN=false

usage() {
    cat <<'EOF'
Usage: bash install.sh [options]

Options:
  --profile minimal|default|full   Installation profile (default: default)
  --only a,b,c                     Run only selected steps: packages,configs,node,claude,rtk,skills
  --skip a,b,c                     Skip selected steps
  --dry-run                        Print planned changes without mutating files
  --with-defaults                  Apply macOS defaults
  -h, --help                       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --profile) PROFILE="${2:-}"; shift 2 ;;
        --profile=*) PROFILE="${1#*=}"; shift ;;
        --only) DOTFILES_ONLY="${2:-}"; shift 2 ;;
        --only=*) DOTFILES_ONLY="${1#*=}"; shift ;;
        --skip) DOTFILES_SKIP="${2:-}"; shift 2 ;;
        --skip=*) DOTFILES_SKIP="${1#*=}"; shift ;;
        --dry-run) DOTFILES_DRY_RUN=true; shift ;;
        --with-defaults) APPLY_DEFAULTS=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) log_fail "Unknown option: $1"; usage; exit 2 ;;
    esac
done

case "$PROFILE" in
    minimal)
        [[ -z "$DOTFILES_ONLY" ]] && DOTFILES_ONLY="packages,configs"
        ;;
    default)
        ;;
    full)
        ;;
    *)
        log_fail "Invalid profile: $PROFILE"
        exit 2
        ;;
esac

export DOTFILES_DRY_RUN DOTFILES_ONLY DOTFILES_SKIP

CLAUDE_DIR="$HOME/.claude"
LOCAL_BIN="$HOME/.local/bin"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
STARSHIP_CONFIG="$HOME/.config/starship.toml"

if ! is_dry_run; then
    mkdir -p "$LOCAL_BIN" "$HOME/.config"
fi

log_step "Unix dotfiles setup starting"
printf '    Source: %s\n' "$ROOT"
printf '    OS:     %s\n' "${OS:-unknown}"
printf '    Arch:   %s\n' "$ARCH"
printf '    Profile:%s\n' "$PROFILE"
is_dry_run && printf '    Mode:   dry-run\n'
printf '    Backup: %s\n' "$DOTFILES_BACKUP_ROOT"

install_packages() {
    if [[ "$OS" == "Darwin" ]]; then
        log_step "Installing packages via Homebrew"
        if ! command -v brew >/dev/null 2>&1; then
            if is_dry_run; then
                log_skip "Would install Homebrew"
                return 0
            fi
            retry_curl https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash
            if [[ "$(uname -m)" == "arm64" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
        if [[ -f "$ROOT/manifests/Brewfile" ]]; then
            run_cmd brew bundle --file="$ROOT/manifests/Brewfile"
        else
            log_warn "manifests/Brewfile not found, skipping"
        fi
        if $APPLY_DEFAULTS; then
            log_step "Applying macOS system defaults"
            [[ -f "$ROOT/config/macos/.macos" ]] && run_cmd bash "$ROOT/config/macos/.macos"
        fi
    elif [[ "$OS" == "Linux" ]]; then
        log_step "Installing packages via apt"
        if [[ -f "$ROOT/manifests/apt.txt" ]]; then
            run_privileged apt-get update -y
            mapfile -t apt_packages < <(manifest_lines "$ROOT/manifests/apt.txt")
            if [[ ${#apt_packages[@]} -gt 0 ]]; then
                DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "${apt_packages[@]}" --no-install-recommends
            fi
        else
            log_warn "manifests/apt.txt not found, skipping"
        fi

        log_step "Configuring Linux compatibility links"
        run_privileged ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
        if ! is_dry_run; then
            echo "Asia/Seoul" | run_privileged tee /etc/timezone > /dev/null
        else
            log_skip "Would set /etc/timezone to Asia/Seoul"
        fi
        if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
            run_cmd ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
        fi
        if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
            run_cmd ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
        fi
    else
        log_warn "Unsupported OS: $OS"
    fi
}

install_official_scripts() {
    [[ "$OS" == "Darwin" ]] && return 0

    log_step "Installing official-script tools"
    if is_dry_run; then
        log_skip "Would install/update zoxide, starship, atuin, fnm, bun"
        return 0
    fi
    if ! command -v zoxide >/dev/null 2>&1; then
        retry_curl https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- --bin-dir "$LOCAL_BIN"
    else
        log_skip "zoxide already installed"
    fi

    if ! command -v starship >/dev/null 2>&1; then
        retry_curl https://starship.rs/install.sh | sh -s -- -b "$LOCAL_BIN" -y
    else
        log_skip "starship already installed"
    fi

    if ! command -v atuin >/dev/null 2>&1; then
        curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh -s -- --non-interactive || log_warn "atuin install returned non-zero"
    else
        log_skip "atuin already installed"
    fi

    if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
        retry_curl https://fnm.vercel.app/install | bash -s -- --skip-shell
    else
        log_skip "fnm already installed"
    fi
    if [[ -x "$HOME/.local/share/fnm/fnm" && ! -e "$LOCAL_BIN/fnm" ]]; then
        run_cmd ln -sf "$HOME/.local/share/fnm/fnm" "$LOCAL_BIN/fnm"
    fi

    if ! command -v bun >/dev/null 2>&1 && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
        retry_curl https://bun.sh/install | bash
    else
        log_skip "bun already installed"
    fi
    if [[ -x "$HOME/.bun/bin/bun" && ! -e "$LOCAL_BIN/bun" ]]; then
        run_cmd ln -sf "$HOME/.bun/bin/bun" "$LOCAL_BIN/bun"
    fi

    add_to_path_runtime "$LOCAL_BIN"
    add_to_path_runtime "$HOME/.bun/bin"
    add_to_path_runtime "$HOME/.local/share/fnm"
}

install_gh_tar() {
    local name="$1" url="$2" bin="${3:-$1}"
    if command -v "$name" >/dev/null 2>&1; then
        log_skip "$name already installed"
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"; _TMPFILES+=("$tmp")
    retry_curl -o "$tmp/$name.tar.gz" "$url"
    tar -xzf "$tmp/$name.tar.gz" -C "$tmp"
    run_privileged install -m 755 "$tmp/$bin" "/usr/local/bin/$name"
    hash -r 2>/dev/null || true
    log_ok "$name installed"
}

install_gh_deb() {
    local name="$1" url="$2"
    if command -v "$name" >/dev/null 2>&1; then
        log_skip "$name already installed"
        return 0
    fi
    local tmp_deb
    tmp_deb="$(mktemp --suffix=.deb)"; _TMPFILES+=("$tmp_deb")
    retry_curl -o "$tmp_deb" "$url"
    chmod 644 "$tmp_deb"
    DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$tmp_deb"
    log_ok "$name installed"
}

install_gh_bin() {
    local name="$1" url="$2"
    if command -v "$name" >/dev/null 2>&1; then
        log_skip "$name already installed"
        return 0
    fi
    local tmp
    tmp="$(mktemp -d)"; _TMPFILES+=("$tmp")
    retry_curl -o "$tmp/$name" "$url"
    run_privileged install -m 755 "$tmp/$name" "/usr/local/bin/$name"
    log_ok "$name installed"
}

install_github_releases() {
    [[ "$OS" == "Linux" ]] || return 0
    log_step "Installing GitHub release tools"
    if is_dry_run; then
        log_skip "Would install/update GitHub release tools from manifests/tools.tsv"
        return 0
    fi

    local tag_dir
    tag_dir="$(mktemp -d)"; _TMPFILES+=("$tag_dir")
    gh_release_tag jesseduffield/lazygit > "$tag_dir/lazygit" &
    gh_release_tag dandavison/delta > "$tag_dir/delta" &
    gh_release_tag junegunn/fzf > "$tag_dir/fzf" &
    gh_release_tag steipete/CodexBar > "$tag_dir/codexbar" &
    wait

    local yazi_triple
    yazi_triple="$(arch_triple "amd64:x86_64-unknown-linux-musl|arm64:aarch64-unknown-linux-musl" "$ARCH")"
    if command -v yazi >/dev/null 2>&1; then
        log_skip "yazi already installed"
    elif [[ -n "$yazi_triple" ]]; then
        install_gh_deb "yazi" "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${yazi_triple}.deb"
    else
        log_warn "Unsupported arch for yazi: $ARCH"
    fi

    local lg_arch lg_tag lg_ver
    lg_arch="$(arch_triple "amd64:Linux_x86_64|arm64:Linux_arm64" "$ARCH")"
    if [[ -n "$lg_arch" ]]; then
        lg_tag="$(cat "$tag_dir/lazygit")"; lg_ver="${lg_tag#v}"
        install_gh_tar "lazygit" "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${lg_ver}_${lg_arch}.tar.gz"
    fi

    local nvim_min="0.10.0" nvim_needs=true nvim_cur nvim_arch tmp nvim_dir
    if command -v nvim >/dev/null 2>&1; then
        nvim_cur="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
        if [[ -n "$nvim_cur" ]] && version_ge "$nvim_cur" "$nvim_min"; then
            nvim_needs=false
            log_skip "neovim already satisfies >= $nvim_min"
        fi
    fi
    if $nvim_needs; then
        nvim_arch="$(arch_triple "amd64:x86_64|arm64:aarch64" "$ARCH")"
        if [[ -n "$nvim_arch" ]]; then
            tmp="$(mktemp -d)"; _TMPFILES+=("$tmp")
            retry_curl -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz"
            tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
            nvim_dir="$(find "$tmp" -maxdepth 1 -type d -name 'nvim-linux-*' 2>/dev/null | head -1)"
            run_privileged cp -r "${nvim_dir}/." /usr/local/
            log_ok "neovim installed"
        fi
    fi

    local delta_arch delta_tag delta_ver
    delta_arch="$(arch_triple "amd64:amd64|arm64:arm64" "$ARCH")"
    if [[ -n "$delta_arch" ]]; then
        delta_tag="$(cat "$tag_dir/delta")"; delta_ver="${delta_tag#v}"
        install_gh_deb "delta" "https://github.com/dandavison/delta/releases/download/${delta_tag}/git-delta_${delta_ver}_${delta_arch}.deb"
    fi

    local fzf_min="0.40.0" fzf_needs=true fzf_cur fzf_arch fzf_tag fzf_ver
    if command -v fzf >/dev/null 2>&1; then
        fzf_cur="$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
        if [[ -n "$fzf_cur" ]] && version_ge "$fzf_cur" "$fzf_min"; then
            fzf_needs=false
            log_skip "fzf already satisfies >= $fzf_min"
        fi
    fi
    if $fzf_needs; then
        fzf_arch="$(arch_triple "amd64:linux_amd64|arm64:linux_arm64" "$ARCH")"
        if [[ -n "$fzf_arch" ]]; then
            fzf_tag="$(cat "$tag_dir/fzf")"; fzf_ver="${fzf_tag#v}"
            tmp="$(mktemp -d)"; _TMPFILES+=("$tmp")
            retry_curl -o "$tmp/fzf.tar.gz" "https://github.com/junegunn/fzf/releases/download/${fzf_tag}/fzf-${fzf_ver}-${fzf_arch}.tar.gz"
            tar -xzf "$tmp/fzf.tar.gz" -C "$tmp" fzf
            run_privileged install -m 755 "$tmp/fzf" /usr/local/bin/fzf
            log_ok "fzf installed"
        fi
    fi

    local eza_triple yq_arch cb_arch cb_tag
    eza_triple="$(arch_triple "amd64:x86_64-unknown-linux-gnu|arm64:aarch64-unknown-linux-gnu" "$ARCH")"
    [[ -n "$eza_triple" ]] && install_gh_tar "eza" "https://github.com/eza-community/eza/releases/latest/download/eza_${eza_triple}.tar.gz"
    yq_arch="$(arch_triple "amd64:linux_amd64|arm64:linux_arm64" "$ARCH")"
    [[ -n "$yq_arch" ]] && install_gh_bin "yq" "https://github.com/mikefarah/yq/releases/latest/download/yq_${yq_arch}"
    cb_arch="$(arch_triple "amd64:x86_64|arm64:aarch64" "$ARCH")"
    if [[ -n "$cb_arch" ]]; then
        cb_tag="$(cat "$tag_dir/codexbar")"
        install_gh_tar "codexbar" "https://github.com/steipete/CodexBar/releases/latest/download/CodexBarCLI-${cb_tag}-linux-${cb_arch}.tar.gz" "codexbar"
    fi
}

deploy_configs() {
    log_step "Deploying config files"
    if [[ "$OS" == "Darwin" ]]; then
        merge_gitconfig "$ROOT/config/git/gitconfig"
        run_cmd git config --global core.autocrlf input
        run_cmd git config --global core.fileMode true
    elif [[ "$OS" == "Linux" ]]; then
        merge_gitconfig "$ROOT/config/git/gitconfig"
        run_cmd git config --global core.autocrlf input
        run_cmd git config --global core.fileMode true
    fi

    copy_managed_file "$ROOT/config/tmux/tmux.linux.conf" "$HOME/.tmux.conf"
    copy_managed_dir "$ROOT/config/yazi" "$YAZI_CONFIG_DIR"
    copy_managed_dir "$ROOT/config/nvim" "$NVIM_CONFIG_DIR"
    copy_managed_file "$ROOT/config/starship.toml" "$STARSHIP_CONFIG"

    for profile in bashrc inputrc; do
        local src="$ROOT/config/bash/$profile"
        [[ -f "$src" ]] && set_profile_block "$HOME/.$profile" "$(cat "$src")"
    done
}

install_node() {
    log_step "Installing Node.js LTS via fnm"
    if is_dry_run; then
        log_skip "Would install/use Node.js LTS via fnm"
    elif ! command -v fnm >/dev/null 2>&1 && [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
        add_to_path_runtime "$HOME/.local/share/fnm"
    fi
    if ! is_dry_run && command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env --shell bash)"
        fnm install --lts
        local lts_ver
        lts_ver="$(fnm ls | grep "lts-latest" | awk '{print $2}' || true)"
        [[ -z "$lts_ver" ]] && lts_ver="$(fnm ls | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tail -1)"
        if [[ -n "$lts_ver" ]]; then
            fnm default "$lts_ver"
            fnm use "$lts_ver"
        else
            fnm default lts-latest || true
            fnm use lts-latest || true
        fi
        log_ok "Node $(node --version 2>/dev/null || echo 'not active yet') active"
    elif ! is_dry_run; then
        log_warn "fnm not found. Restart terminal and run: fnm install --lts"
    fi

    log_step "Installing global npm packages"
    if [[ -f "$ROOT/manifests/npm-global.txt" ]] && { is_dry_run || command -v npm >/dev/null 2>&1; }; then
        while IFS= read -r pkg; do
            [[ -z "$pkg" ]] && continue
            if is_dry_run; then
                log_skip "Would npm install -g $pkg"
            elif npm install -g "$pkg" >/dev/null 2>&1; then
                log_ok "Installed $pkg"
            else
                log_warn "Failed: $pkg"
            fi
        done < <(manifest_lines "$ROOT/manifests/npm-global.txt")
    else
        log_warn "manifests/npm-global.txt or npm not found, skipping"
    fi
}

install_claude() {
    if [[ "${SKIP_CLAUDE_CODE:-0}" == "1" ]]; then
        log_skip "Claude Code installation skipped (SKIP_CLAUDE_CODE=1)"
        return 0
    fi
    log_step "Installing Claude Code and config"
    if command -v claude >/dev/null 2>&1; then
        log_skip "Claude Code already installed"
    else
        retry_curl https://claude.ai/install.sh | bash
        log_ok "Claude Code installed"
    fi

    if ! is_dry_run; then
        mkdir -p "$CLAUDE_DIR"
    fi
    local settings_src="$ROOT/config/claude/settings.json" settings_dst="$CLAUDE_DIR/settings.json"
    if [[ -f "$settings_src" ]]; then
        backup_existing "$settings_dst"
        if is_dry_run; then
            log_skip "Would merge $settings_src -> $settings_dst"
        elif [[ -f "$settings_dst" ]] && command -v jq >/dev/null 2>&1; then
            local tmp
            tmp="$(mktemp)"; _TMPFILES+=("$tmp")
            if jq -s '.[0] * .[1]' "$settings_dst" "$settings_src" > "$tmp" && [[ -s "$tmp" ]]; then
                mv "$tmp" "$settings_dst"
                log_ok "Merged settings.json"
            else
                log_warn "jq merge failed, keeping existing settings.json"
            fi
        else
            copy_managed_file "$settings_src" "$settings_dst"
        fi
    fi
    copy_managed_file "$ROOT/config/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
}

install_rtk() {
    if [[ "${SKIP_RTK:-0}" == "1" ]]; then
        log_skip "RTK installation skipped (SKIP_RTK=1)"
        return 0
    fi
    log_step "Installing RTK"
    if command -v rtk >/dev/null 2>&1; then
        log_skip "RTK already installed"
    else
        retry_curl https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh || log_warn "RTK install failed"
    fi
}

install_skills() {
    if [[ "${SKIP_SKILLS:-0}" == "1" ]]; then
        log_skip "Claude Code skills skipped (SKIP_SKILLS=1)"
        return 0
    fi
    log_step "Restoring Claude Code skills"
    if [[ -f "$ROOT/manifests/skills.txt" ]] && command -v npx >/dev/null 2>&1; then
        while IFS= read -r line; do
            [[ "$line" =~ ^([^@]+)@(.+)$ ]] || continue
            repo="${BASH_REMATCH[1]}"
            skill="${BASH_REMATCH[2]}"
            if is_dry_run; then
                log_skip "Would add skill $repo@$skill"
            elif npx -y skills add "$repo" --skill "$skill" --global --yes --agent claude-code </dev/null >/dev/null 2>&1; then
                log_ok "Added $repo@$skill"
            else
                log_warn "Failed: $repo@$skill"
            fi
        done < <(manifest_lines "$ROOT/manifests/skills.txt")
    else
        log_warn "manifests/skills.txt or npx not found, skipping"
    fi
}

if should_run_step packages; then
    install_packages
    install_official_scripts
    install_github_releases
else
    log_skip "packages step skipped"
fi

if should_run_step configs; then deploy_configs; else log_skip "configs step skipped"; fi
if should_run_step node; then install_node; else log_skip "node step skipped"; fi
if should_run_step claude; then install_claude; else log_skip "claude step skipped"; fi
if should_run_step rtk; then install_rtk; else log_skip "rtk step skipped"; fi
if should_run_step skills; then install_skills; else log_skip "skills step skipped"; fi

log_step "Done"
log_ok "Restart your terminal and Claude Code to apply all changes."
