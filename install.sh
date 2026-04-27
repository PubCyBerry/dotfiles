#!/usr/bin/env bash
# Linux(Ubuntu) dotfiles 설치 진입점 (all-in-one)
# 실행: bash install.sh
# 지원: Ubuntu 22.04+ (apt 기반)

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================
# 경로 상수
# =============================================
CLAUDE_DIR="$HOME/.claude"
LOCAL_BIN="$HOME/.local/bin"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"   # amd64, arm64, ...

mkdir -p "$LOCAL_BIN" "$HOME/.config"

# =============================================
# 헬퍼 함수
# =============================================
manifest_lines() {
    # 주석/공백 제거 + 인라인 '#' 주석 제거
    local path="$1"
    [[ -f "$path" ]] || return 0
    sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$path" | awk '{$1=$1; print}'
}

set_profile_block() {
    # 마커 블록 멱등 삽입/교체
    local file="$1" content="$2"
    local begin="# ===== dotfiles-begin ====="
    local end="# ===== dotfiles-end ====="
    local block tmp
    block="$(printf '%s\n%s\n%s' "$begin" "$content" "$end")"

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    if grep -qF "$begin" "$file" && grep -qF "$end" "$file"; then
        # 기존 블록 교체 (sed 멀티라인)
        tmp="$(mktemp)"
        awk -v begin="$begin" -v end="$end" -v repl="$block" '
            BEGIN { skip = 0 }
            $0 == begin { print repl; skip = 1; next }
            skip && $0 == end { skip = 0; next }
            !skip { print }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
        echo "    Updated dotfiles block in $file"
    else
        printf '\n%s\n' "$block" >> "$file"
        echo "    Appended dotfiles block to $file"
    fi
}

merge_gitconfig() {
    # 기존 git config 키 보존, 미설정인 키만 추가
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "    [!] $path not found, skipping."
        return 0
    fi

    declare -A existing
    while IFS='=' read -r k v; do
        [[ -n "$k" ]] && existing["$k"]="$v"
    done < <(git config --global --list 2>/dev/null || true)

    local section="" trimmed key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"   # ltrim
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"   # rtrim
        if [[ "$trimmed" =~ ^\[(.+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
        elif [[ -n "$trimmed" && "${trimmed:0:1}" != "#" && -n "$section" ]]; then
            if [[ "$trimmed" =~ ^([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                if [[ -z "${existing[$section.$key]+x}" ]]; then
                    git config --global "$section.$key" "$value"
                    echo "    Added [$section] $key = $value"
                else
                    echo "    Skip  [$section] $key (already set)"
                fi
            fi
        fi
    done < "$path"
    echo "    gitconfig merged."
}

add_to_path_runtime() {
    # 현재 셸 PATH 에 추가 (idempotent)
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) export PATH="$dir:$PATH" ;;
    esac
}

run_privileged() {
    # root면 직접 실행, 일반 유저면 sudo 경유
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

gh_release_tag() {
    # 최신 release tag (v 접두사 포함)
    curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
        | grep -o '"tag_name":[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]+)"$/\1/'
}

echo "==> Linux (Ubuntu) dotfiles setup starting..."
echo "    Source: $ROOT"
echo "    Arch:   $ARCH"

# =============================================
# 1. apt 패키지 설치 (manifests/apt.txt)
# =============================================
echo
echo "==> Installing packages via apt..."
APT_FILE="$ROOT/manifests/apt.txt"
if [[ -f "$APT_FILE" ]]; then
    run_privileged apt-get update -y
    # shellcheck disable=SC2046
    DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y $(manifest_lines "$APT_FILE")
else
    echo "    [!] manifests/apt.txt not found, skipping."
fi

# 22.04에서 'bat'은 batcat 으로, 'fd'는 fdfind 로 설치됨 → ~/.local/bin 심볼릭 링크
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
    ln -sf "$(command -v batcat)" "$LOCAL_BIN/bat"
    echo "    Linked $LOCAL_BIN/bat -> batcat"
fi
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
    ln -sf "$(command -v fdfind)" "$LOCAL_BIN/fd"
    echo "    Linked $LOCAL_BIN/fd -> fdfind"
fi

# =============================================
# 1-1. gitconfig 병합 + Linux 전용 override
# =============================================
echo
echo "==> Merging git config..."
merge_gitconfig "$ROOT/config/git/gitconfig"
git config --global core.autocrlf input
git config --global core.fileMode true
echo "    Set core.autocrlf=input, core.fileMode=true (Linux)"

# =============================================
# 1-2. tmux 설정 복사 (config/linux/tmux.conf → ~/.tmux.conf)
# =============================================
echo
TMUX_SRC="$ROOT/config/linux/tmux.conf"
if [[ -f "$TMUX_SRC" ]]; then
    cp -f "$TMUX_SRC" "$HOME/.tmux.conf"
    echo "    Copied .tmux.conf (tmux default shell: bash)"
fi

# =============================================
# 1-3. yazi 설정 배포 (config/yazi/ → ~/.config/yazi/)
# =============================================
echo
echo "==> Deploying yazi config..."
if [[ -d "$ROOT/config/yazi" ]]; then
    mkdir -p "$YAZI_CONFIG_DIR"
    cp -rf "$ROOT/config/yazi/." "$YAZI_CONFIG_DIR/"
    echo "    yazi config deployed to $YAZI_CONFIG_DIR"
else
    echo "    [!] config/yazi not found, skipping."
fi

# =============================================
# 1-4. Neovim 설정 배포 (config/nvim/ → ~/.config/nvim/, 기존 있으면 skip)
# =============================================
echo
echo "==> Setting up lazy.nvim (Neovim Plugin Manager - Structured Setup)..."
if [[ -f "$NVIM_CONFIG_DIR/init.lua" ]]; then
    echo "    Neovim config already exists, skipping."
elif [[ ! -f "$ROOT/config/nvim/init.lua" ]]; then
    echo "    [!] config/nvim/init.lua not found, skipping."
else
    mkdir -p "$NVIM_CONFIG_DIR"
    cp -rf "$ROOT/config/nvim/." "$NVIM_CONFIG_DIR/"
    echo "    lazy.nvim config deployed to $NVIM_CONFIG_DIR"
    echo "    Run nvim to auto-install lazy.nvim on first launch."
fi

# =============================================
# 1-5. starship 설정 배포 (config/starship.toml → ~/.config/starship.toml)
# =============================================
echo
if [[ -f "$ROOT/config/starship.toml" ]]; then
    cp -f "$ROOT/config/starship.toml" "$STARSHIP_CONFIG"
    echo "    Copied starship.toml to $STARSHIP_CONFIG"
fi

# =============================================
# 1-6. apt에 없거나 오래된 도구 — 공식 install one-liner
# =============================================
echo
echo "==> Installing zoxide (official script)..."
if ! command -v zoxide >/dev/null 2>&1; then
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
else
    echo "    zoxide already installed."
fi

echo
echo "==> Installing starship (official script)..."
if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y
else
    echo "    starship already installed."
fi

echo
echo "==> Installing atuin (official script, non-interactive)..."
if ! command -v atuin >/dev/null 2>&1; then
    # ATUIN_NO_MODIFY_PATH=1: install.sh가 직접 PATH 처리 (bashrc 수정은 우리가 담당)
    curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh \
        | sh -s -- --non-interactive || echo "    [!] atuin install returned non-zero (check log)."
else
    echo "    atuin already installed."
fi

echo
echo "==> Installing fnm (official script, --skip-shell)..."
if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
else
    echo "    fnm already installed."
fi

echo
echo "==> Installing bun (official script)..."
if ! command -v bun >/dev/null 2>&1 && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
    curl -fsSL https://bun.sh/install | bash
else
    echo "    bun already installed."
fi

# 현재 셸에서 도구를 사용 가능하도록 PATH 보강
add_to_path_runtime "$LOCAL_BIN"
add_to_path_runtime "$HOME/.bun/bin"
add_to_path_runtime "$HOME/.local/share/fnm"

# =============================================
# 1-7. GitHub releases 바이너리 (yazi, lazygit, delta)
# =============================================
echo
echo "==> Installing yazi from GitHub releases..."
if ! command -v yazi >/dev/null 2>&1; then
    case "$ARCH" in
        amd64) YAZI_TRIPLE="x86_64-unknown-linux-gnu" ;;
        arm64) YAZI_TRIPLE="aarch64-unknown-linux-gnu" ;;
        *)     YAZI_TRIPLE="" ;;
    esac
    if [[ -n "$YAZI_TRIPLE" ]]; then
        TMP_DEB="$(mktemp --suffix=.deb)"
        curl -fsSL -o "$TMP_DEB" \
            "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_TRIPLE}.deb"
        DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
        echo "    yazi installed."
    else
        echo "    [!] Unsupported arch for yazi: $ARCH (skipping)"
    fi
else
    echo "    yazi already installed."
fi

echo
echo "==> Installing lazygit from GitHub releases..."
if ! command -v lazygit >/dev/null 2>&1; then
    case "$ARCH" in
        amd64) LG_ARCH="Linux_x86_64" ;;
        arm64) LG_ARCH="Linux_arm64" ;;
        *)     LG_ARCH="" ;;
    esac
    if [[ -n "$LG_ARCH" ]]; then
        LG_TAG="$(gh_release_tag jesseduffield/lazygit)"     # vX.Y.Z
        LG_VER="${LG_TAG#v}"
        TMP_DIR="$(mktemp -d)"
        curl -fsSL -o "$TMP_DIR/lazygit.tar.gz" \
            "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_${LG_ARCH}.tar.gz"
        tar -xzf "$TMP_DIR/lazygit.tar.gz" -C "$TMP_DIR" lazygit
        run_privileged install -m 755 "$TMP_DIR/lazygit" /usr/local/bin/lazygit
        rm -rf "$TMP_DIR"
        echo "    lazygit installed."
    else
        echo "    [!] Unsupported arch for lazygit: $ARCH (skipping)"
    fi
else
    echo "    lazygit already installed."
fi

echo
echo "==> Installing git-delta from GitHub releases..."
if ! command -v delta >/dev/null 2>&1; then
    case "$ARCH" in
        amd64) DELTA_ARCH="amd64" ;;
        arm64) DELTA_ARCH="arm64" ;;
        *)     DELTA_ARCH="" ;;
    esac
    if [[ -n "$DELTA_ARCH" ]]; then
        DELTA_TAG="$(gh_release_tag dandavison/delta)"        # 0.X.Y (no 'v')
        DELTA_VER="${DELTA_TAG#v}"
        TMP_DEB="$(mktemp --suffix=.deb)"
        curl -fsSL -o "$TMP_DEB" \
            "https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/git-delta_${DELTA_VER}_${DELTA_ARCH}.deb"
        DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$TMP_DEB"
        rm -f "$TMP_DEB"
        echo "    git-delta installed."
    else
        echo "    [!] Unsupported arch for delta: $ARCH (skipping)"
    fi
else
    echo "    delta already installed."
fi

# =============================================
# 2. Node.js LTS (fnm)
# =============================================
echo
echo "==> Installing Node.js LTS via fnm..."
if command -v fnm >/dev/null 2>&1 || [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
    add_to_path_runtime "$HOME/.local/share/fnm"
    eval "$(fnm env --shell bash)"
    fnm install --lts
    fnm default lts-latest
    fnm use lts-latest
    echo "    Node.js LTS installed."
else
    echo "    [!] fnm not found. Restart terminal and run:"
    echo "        fnm install --lts && fnm default lts-latest"
fi

# =============================================
# 2-1. npm 전역 패키지 (manifests/npm-global.txt)
# =============================================
echo
echo "==> Installing global npm packages..."
NPM_FILE="$ROOT/manifests/npm-global.txt"
if [[ -f "$NPM_FILE" ]] && command -v npm >/dev/null 2>&1; then
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        if npm install -g "$pkg" >/dev/null 2>&1; then
            echo "    Installed $pkg"
        else
            echo "    [!] Failed: $pkg"
        fi
    done < <(manifest_lines "$NPM_FILE")
else
    echo "    [!] manifests/npm-global.txt or npm not found, skipping."
fi

# =============================================
# 3. Claude Code 네이티브 설치
# =============================================
echo
echo "==> Installing Claude Code (native)..."
add_to_path_runtime "$LOCAL_BIN"
if command -v claude >/dev/null 2>&1; then
    echo "    Claude Code already installed: $(claude --version 2>/dev/null || echo unknown)"
else
    curl -fsSL https://claude.ai/install.sh | bash
    echo "    Claude Code installed."
fi

# =============================================
# 3-1. Claude Code 설정 배포 (config/claude/ → ~/.claude/)
# =============================================
echo
echo "==> Deploying Claude Code config..."
mkdir -p "$CLAUDE_DIR"

SETTINGS_SRC="$ROOT/config/claude/settings.json"
SETTINGS_DST="$CLAUDE_DIR/settings.json"
if [[ -f "$SETTINGS_SRC" ]]; then
    if [[ -f "$SETTINGS_DST" ]] && command -v jq >/dev/null 2>&1; then
        # 기존 키 보존(claude-hud의 statusLine 등) + 새 키 덮어쓰기/추가
        TMP="$(mktemp)"
        jq -s '.[0] * .[1]' "$SETTINGS_DST" "$SETTINGS_SRC" > "$TMP"
        mv "$TMP" "$SETTINGS_DST"
        echo "    Merged settings.json"
    else
        cp -f "$SETTINGS_SRC" "$SETTINGS_DST"
        echo "    Copied settings.json"
    fi
else
    echo "    [!] config/claude/settings.json not found"
fi

CLAUDE_MD_SRC="$ROOT/config/claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD_SRC" ]]; then
    cp -f "$CLAUDE_MD_SRC" "$CLAUDE_DIR/CLAUDE.md"
    echo "    Copied CLAUDE.md"
else
    echo "    [!] config/claude/CLAUDE.md not found"
fi

# =============================================
# 3-2. RTK (Rust Token Killer) + Claude hook
# =============================================
echo
echo "==> Installing RTK (Rust Token Killer)..."
if command -v rtk >/dev/null 2>&1; then
    echo "    RTK already installed: $(rtk --version 2>/dev/null | head -1 || echo unknown)"
else
    # 공식 install.sh — ~/.local/bin 에 binary 배치
    if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh; then
        echo "    RTK installed."
    else
        echo "    [!] RTK install failed. Manual: cargo install --git https://github.com/rtk-ai/rtk"
    fi
fi

# Claude Code hook 직접 다운로드 (install.ps1과 동일 방식)
rtk init -g --hook-only     # Hook only, no RTK.md
# mkdir -p "$CLAUDE_DIR/hooks"
# HOOK_PATH="$CLAUDE_DIR/hooks/rtk-rewrite.sh"
# if curl -fsSL "https://raw.githubusercontent.com/rtk-ai/rtk/master/hooks/claude/rtk-rewrite.sh" -o "$HOOK_PATH"; then
#     chmod +x "$HOOK_PATH"
#     echo "    RTK hook installed at $HOOK_PATH"
# else
#     echo "    [!] RTK hook download failed."
# fi

# =============================================
# 4. bash 프로파일 설정 (~/.bashrc, ~/.inputrc, 마커 방식)
# =============================================
echo
echo "==> Updating bash profile..."
BASHRC_SRC="$ROOT/config/bash/bashrc"
if [[ -f "$BASHRC_SRC" ]]; then
    BASHRC_CONTENT="$(cat "$BASHRC_SRC")"
    set_profile_block "$HOME/.bashrc" "$BASHRC_CONTENT"
else
    echo "    [!] config/bash/bashrc not found, skipping bashrc."
fi

INPUTRC_SRC="$ROOT/config/bash/inputrc"
if [[ -f "$INPUTRC_SRC" ]]; then
    INPUTRC_CONTENT="$(cat "$INPUTRC_SRC")"
    set_profile_block "$HOME/.inputrc" "$INPUTRC_CONTENT"
fi

# =============================================
# 6. Claude Code skills 설치 (manifests/skills.txt)
# =============================================
echo
echo "==> Restoring Claude Code skills..."
SKILLS_FILE="$ROOT/manifests/skills.txt"
if [[ -f "$SKILLS_FILE" ]] && command -v npx >/dev/null 2>&1; then
    while IFS= read -r line; do
        [[ "$line" =~ ^([^@]+)@(.+)$ ]] || continue
        repo="${BASH_REMATCH[1]}"
        skill="${BASH_REMATCH[2]}"
        echo "    Adding skill: $skill from $repo..."
        npx skills add "$repo" --skill "$skill" --global --yes --agent claude-code >/dev/null 2>&1 \
            || echo "    [!] Failed: $repo@$skill"
    done < <(manifest_lines "$SKILLS_FILE")
    echo "    Skills restored."
else
    echo "    [!] manifests/skills.txt or npx not found, skipping skills."
fi

echo
echo "==> Done! Restart your terminal and Claude Code to apply all changes."
