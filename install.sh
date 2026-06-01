#!/usr/bin/env bash
# Linux(Ubuntu) dotfiles 설치 진입점 (all-in-one)
# 실행: bash install.sh
# 지원: Ubuntu 22.04+ (apt 기반)

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"

APPLY_DEFAULTS=false
for arg in "$@"; do
  [[ "$arg" == "--with-defaults" ]] && APPLY_DEFAULTS=true
done

# =============================================
# 경로 상수
# =============================================
CLAUDE_DIR="$HOME/.claude"
CODEX_DIR="$HOME/.codex"
LOCAL_BIN="$HOME/.local/bin"
NVIM_CONFIG_DIR="$HOME/.config/nvim"
YAZI_CONFIG_DIR="$HOME/.config/yazi"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
ARCH="$(dpkg --print-architecture 2>/dev/null || echo amd64)"   # amd64, arm64, ...

mkdir -p "$LOCAL_BIN" "$HOME/.config"

# =============================================
# 헬퍼 함수
# =============================================
_TMPFILES=()
_cleanup() { if [[ ${#_TMPFILES[@]} -gt 0 ]]; then rm -rf "${_TMPFILES[@]}"; fi; }
trap _cleanup EXIT

manifest_lines() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    LC_ALL=C sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$path" | awk '{$1=$1; print}'
}

set_profile_block() {
    local file="$1" content="$2"
    local begin="# ===== dotfiles-begin ====="
    local end="# ===== dotfiles-end ====="
    local block tmp
    block="$(printf '%s\n%s\n%s' "$begin" "$content" "$end")"

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    if grep -qF "$begin" "$file" && grep -qF "$end" "$file"; then
        tmp="$(mktemp)"; _TMPFILES+=("$tmp")
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
    local path="$1"
    if [[ ! -f "$path" ]]; then
        echo "    [!] $path not found, skipping."
        return 0
    fi

    local section="" trimmed key value existing_val
    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        if [[ "$trimmed" =~ ^\[(.+)\]$ ]]; then
            section="${BASH_REMATCH[1]}"
        elif [[ -n "$trimmed" && "${trimmed:0:1}" != "#" && -n "$section" ]]; then
            if [[ "$trimmed" =~ ^([^[:space:]=]+)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                key="${BASH_REMATCH[1]}"
                value="${BASH_REMATCH[2]}"
                existing_val=$(git config --global "$section.$key" 2>/dev/null || true)
                if [[ -z "$existing_val" ]]; then
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

merge_codex_config() {
    local src="$1" dst="$2"
    local curSec="" line t key mapKey k sec_part

    if [[ ! -f "$src" ]]; then
        echo "    [!] $src not found, skipping."
        return 0
    fi
    if [[ ! -f "$dst" ]]; then
        cp -f "$src" "$dst"
        echo "    Copied config.toml"
        return 0
    fi

    # Parse source: srcKeys["sec\x1fkey"] = rawLine; srcSecOrder tracks section order
    declare -A srcKeys doneKeys seenSec
    local srcSecOrder=("")
    curSec=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        t="${line#"${line%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
        if [[ "$t" =~ ^\[(.+)\]$ ]]; then
            curSec="${BASH_REMATCH[1]}"
            local _f=0
            for _s in "${srcSecOrder[@]}"; do [[ "$_s" == "$curSec" ]] && _f=1 && break; done
            [[ $_f -eq 0 ]] && srcSecOrder+=("$curSec")
        elif [[ -n "$t" && "${t:0:1}" != "#" && "$t" =~ ^([^[:space:]=]+)[[:space:]]*= ]]; then
            srcKeys["${curSec}"$'\x1f'"${BASH_REMATCH[1]}"]="$line"
        fi
    done < "$src"

    local tmp; tmp="$(mktemp)"; _TMPFILES+=("$tmp")
    curSec=""

    while IFS= read -r line || [[ -n "$line" ]]; do
        t="${line#"${line%%[![:space:]]*}"}"; t="${t%"${t##*[![:space:]]}"}"
        if [[ "$t" =~ ^\[(.+)\]$ ]]; then
            # Flush source keys missing from outgoing section
            for k in "${!srcKeys[@]}"; do
                sec_part="${k%%$'\x1f'*}"
                [[ "$sec_part" != "$curSec" || -n "${doneKeys[$k]+x}" ]] && continue
                printf '%s\n' "${srcKeys[$k]}" >> "$tmp"
                echo "    Added [${curSec}] ${k#*$'\x1f'}"
            done
            curSec="${BASH_REMATCH[1]}"; seenSec["$curSec"]="1"
            printf '%s\n' "$line" >> "$tmp"
        elif [[ -n "$t" && "${t:0:1}" != "#" && "$t" =~ ^([^[:space:]=]+)[[:space:]]*= ]]; then
            key="${BASH_REMATCH[1]}"; mapKey="${curSec}"$'\x1f'"${key}"
            doneKeys["$mapKey"]="1"
            if [[ -n "${srcKeys[$mapKey]+x}" ]]; then
                printf '%s\n' "${srcKeys[$mapKey]}" >> "$tmp"
                [[ "${srcKeys[$mapKey]}" != "$line" ]] && echo "    Override [${curSec}] ${key}"
            else
                printf '%s\n' "$line" >> "$tmp"
            fi
        else
            printf '%s\n' "$line" >> "$tmp"
        fi
    done < "$dst"

    # Flush missing keys for last section
    for k in "${!srcKeys[@]}"; do
        sec_part="${k%%$'\x1f'*}"
        [[ "$sec_part" != "$curSec" || -n "${doneKeys[$k]+x}" ]] && continue
        printf '%s\n' "${srcKeys[$k]}" >> "$tmp"
        echo "    Added [${curSec}] ${k#*$'\x1f'}"
    done

    # Prepend missing top-level keys
    local topMissing=()
    for k in "${!srcKeys[@]}"; do
        [[ "${k%%$'\x1f'*}" != "" || -n "${doneKeys[$k]+x}" ]] && continue
        topMissing+=("${srcKeys[$k]}")
        echo "    Added top-level ${k#*$'\x1f'}"
    done
    if [[ ${#topMissing[@]} -gt 0 ]]; then
        local tmpTop; tmpTop="$(mktemp)"; _TMPFILES+=("$tmpTop")
        printf '%s\n' "${topMissing[@]}" > "$tmpTop"
        printf '\n' >> "$tmpTop"
        cat "$tmp" >> "$tmpTop"
        mv "$tmpTop" "$tmp"
    fi

    # Append entirely missing sections
    local sec
    for sec in "${srcSecOrder[@]}"; do
        [[ "$sec" == "" || -n "${seenSec[$sec]+x}" ]] && continue
        printf '\n[%s]\n' "$sec" >> "$tmp"
        for k in "${!srcKeys[@]}"; do
            [[ "${k%%$'\x1f'*}" == "$sec" ]] && printf '%s\n' "${srcKeys[$k]}" >> "$tmp"
        done
        echo "    Added section [$sec]"
    done

    mv "$tmp" "$dst"
    echo "    Merged config.toml (source overrides destination)"
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
    # 최신 release tag (v 접두사 포함). GITHUB_TOKEN 설정 시 rate limit 5000/hr
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        curl -fsSL -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$1/releases/latest" \
            | jq -r '.tag_name // empty'
    else
        curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
            | jq -r '.tag_name // empty'
    fi
}

arch_triple() {
    # ARCH에 맞는 triple 반환. schema 예: "amd64:x86_64-linux-musl|arm64:aarch64-linux-musl"
    local schema="$1" entry
    for entry in $(echo "$schema" | tr '|' ' '); do
        if [[ "${entry%%:*}" == "$ARCH" ]]; then
            echo "${entry#*:}"; return
        fi
    done
}

install_gh_tar() {
    # tar.gz → /usr/local/bin/$name. $1=name $2=url $3=bin_in_archive(default:$1)
    local name="$1" url="$2" bin="${3:-$1}"
    command -v "$name" >/dev/null 2>&1 && { echo "    $name already installed."; return; }
    local TMP; TMP="$(mktemp -d)"; _TMPFILES+=("$TMP")
    curl --retry 3 --retry-delay 2 -fsSL -o "$TMP/$name.tar.gz" "$url"
    tar -xzf "$TMP/$name.tar.gz" -C "$TMP"
    run_privileged install -m 755 "$TMP/$bin" "/usr/local/bin/$name"
    hash -r 2>/dev/null || true
    echo "    $name installed."
}

install_gh_deb() {
    # .deb → apt-get install. $1=name $2=url
    local name="$1" url="$2"
    command -v "$name" >/dev/null 2>&1 && { echo "    $name already installed."; return; }
    local TMP_DEB; TMP_DEB="$(mktemp --suffix=.deb)"; _TMPFILES+=("$TMP_DEB")
    curl --retry 3 --retry-delay 2 -fsSL -o "$TMP_DEB" "$url"
    chmod 644 "$TMP_DEB"
    DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$TMP_DEB"
    echo "    $name installed."
}

install_gh_bin() {
    # 단일 바이너리 → /usr/local/bin/$name. $1=name $2=url
    local name="$1" url="$2"
    command -v "$name" >/dev/null 2>&1 && { echo "    $name already installed."; return; }
    local TMP; TMP="$(mktemp -d)"; _TMPFILES+=("$TMP")
    curl --retry 3 --retry-delay 2 -fsSL -o "$TMP/$name" "$url"
    run_privileged install -m 755 "$TMP/$name" "/usr/local/bin/$name"
    echo "    $name installed."
}

echo "==> Unix dotfiles setup starting..."
echo "    Source: $ROOT"
echo "    OS:     ${OS:-unknown}"
echo "    Arch:   $ARCH"

if [[ "$OS" == "Darwin" ]]; then
    # =============================================
    # [macOS] Homebrew 및 Brewfile
    # =============================================
    echo
    if ! command -v brew >/dev/null 2>&1; then
      echo "    Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      if [[ "$(uname -m)" == "arm64" ]]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
      else
          eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    BREWFILE="$ROOT/manifests/Brewfile"
    echo "    Installing packages from Brewfile..."
    if [[ -f "$BREWFILE" ]]; then
        brew bundle --file="$BREWFILE"
    else
        echo "    [!] manifests/Brewfile not found, skipping."
    fi

    if $APPLY_DEFAULTS; then
      echo "==> Applying macOS system defaults..."
      MACOS_DEFAULTS="$ROOT/config/macos/.macos"
      if [[ -f "$MACOS_DEFAULTS" ]]; then
          bash "$MACOS_DEFAULTS"
      fi
    fi

    echo
    echo "==> Merging git config (macOS)..."
    merge_gitconfig "$ROOT/config/git/gitconfig"
    git config --global core.autocrlf input
    git config --global core.fileMode true

elif [[ "$OS" == "Linux" ]]; then
    # =============================================
    # [Linux] apt 및 github releases
    # =============================================
    echo
    echo "==> Installing packages via apt..."
    APT_FILE="$ROOT/manifests/apt.txt"
    if [[ -f "$APT_FILE" ]]; then
        run_privileged apt-get update -y
        # shellcheck disable=SC2046
        DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y \
            $(manifest_lines "$APT_FILE") --no-install-recommends
    else
        echo "    [!] manifests/apt.txt not found, skipping."
    fi

    echo "    Setting timezone to Asia/Seoul..."
    run_privileged ln -snf /usr/share/zoneinfo/Asia/Seoul /etc/localtime
    echo "Asia/Seoul" | run_privileged tee /etc/timezone > /dev/null

    echo "    Refreshing font cache..."
    fc-cache -vf

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
fi

# =============================================
# 1-2. tmux 설정 복사 (config/tmux/tmux.linux.conf → ~/.tmux.conf)
# =============================================
echo
TMUX_SRC="$ROOT/config/tmux/tmux.linux.conf"
if [[ -f "$TMUX_SRC" ]]; then
    cp -f "$TMUX_SRC" "$HOME/.tmux.conf"
    echo "    Copied tmux.linux.conf to .tmux.conf (Unix)"
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
# 1-4. Neovim 설정 배포 (config/nvim/ → ~/.config/nvim/)
# =============================================
echo
echo "==> Setting up lazy.nvim (Neovim Plugin Manager - Structured Setup)..."
if [[ ! -f "$ROOT/config/nvim/init.lua" ]]; then
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
    # --bin-dir로 사용자 디렉토리 지정 → sudo 없이 설치 (zoxide 기본도 ~/.local/bin이지만 명시)
    curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh \
        | sh -s -- --bin-dir "$LOCAL_BIN"
else
    echo "    zoxide already installed."
fi

echo
echo "==> Installing starship (official script)..."
if ! command -v starship >/dev/null 2>&1; then
    # -b 로 사용자 디렉토리 지정 → sudo 비밀번호 prompt 회피 (starship 기본은 /usr/local/bin)
    curl -sS https://starship.rs/install.sh | sh -s -- -b "$LOCAL_BIN" -y
else
    echo "    starship already installed."
fi

echo
echo "==> Installing atuin (official script, non-interactive)..."
if ! command -v atuin >/dev/null 2>&1; then
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
if [[ -x "$HOME/.local/share/fnm/fnm" ]] && [[ ! -e "$LOCAL_BIN/fnm" ]]; then
    ln -sf "$HOME/.local/share/fnm/fnm" "$LOCAL_BIN/fnm"
    echo "    Linked $LOCAL_BIN/fnm -> fnm"
fi

echo
echo "==> Installing bun (official script)..."
if ! command -v bun >/dev/null 2>&1 && [[ ! -x "$HOME/.bun/bin/bun" ]]; then
    curl -fsSL https://bun.sh/install | bash
else
    echo "    bun already installed."
fi
if [[ -x "$HOME/.bun/bin/bun" ]] && [[ ! -e "$LOCAL_BIN/bun" ]]; then
    ln -sf "$HOME/.bun/bin/bun" "$LOCAL_BIN/bun"
    echo "    Linked $LOCAL_BIN/bun -> bun"
fi

add_to_path_runtime "$LOCAL_BIN"
add_to_path_runtime "$HOME/.bun/bin"
add_to_path_runtime "$HOME/.local/share/fnm"

# macOS already installed most of these via Brewfile. Skip Linux-only binary installs on macOS.
if [[ "$OS" == "Linux" ]]; then
    # =============================================
    # 1-7. GitHub releases 바이너리 (yazi, lazygit, neovim, delta, fzf, eza, yq)
    # =============================================

# GitHub API tag를 3개 병렬 선행 조회 (lazygit·delta·fzf에서 사용)
_TAG_DIR="$(mktemp -d)"; _TMPFILES+=("$_TAG_DIR")
gh_release_tag jesseduffield/lazygit > "$_TAG_DIR/lazygit"   &
gh_release_tag dandavison/delta      > "$_TAG_DIR/delta"     &
gh_release_tag junegunn/fzf          > "$_TAG_DIR/fzf"       &
wait

echo
echo "==> Installing yazi from GitHub releases..."
# musl 정적 빌드 사용 → glibc 버전 무관 (22.04 glibc 2.35 등 구버전에서도 동작)
YAZI_TRIPLE="$(arch_triple "amd64:x86_64-unknown-linux-musl|arm64:aarch64-unknown-linux-musl")"
if command -v yazi >/dev/null 2>&1 && yazi --version >/dev/null 2>&1; then
    echo "    yazi already installed: $(yazi --version | head -1)"
elif [[ -n "$YAZI_TRIPLE" ]]; then
    TMP_DEB="$(mktemp --suffix=.deb)"; _TMPFILES+=("$TMP_DEB")
    curl -fsSL -o "$TMP_DEB" \
        "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${YAZI_TRIPLE}.deb"
    chmod 644 "$TMP_DEB"
    DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y "$TMP_DEB"
    hash -r 2>/dev/null || true
    echo "    yazi installed: $(yazi --version | head -1)"
else
    echo "    [!] Unsupported arch for yazi: $ARCH (skipping)"
fi

echo
echo "==> Installing lazygit from GitHub releases..."
LG_ARCH="$(arch_triple "amd64:Linux_x86_64|arm64:Linux_arm64")"
if [[ -n "$LG_ARCH" ]]; then
    LG_TAG="$(cat "$_TAG_DIR/lazygit")"
    LG_VER="${LG_TAG#v}"
    install_gh_tar "lazygit" \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LG_VER}_${LG_ARCH}.tar.gz"
else
    echo "    [!] Unsupported arch for lazygit: $ARCH (skipping)"
fi

echo
echo "==> Installing neovim from GitHub releases..."
# 22.04 apt의 nvim은 0.6.x → lazy.nvim(>=0.8) 및 본 설정(0.10+) 미만이면 GitHub releases로 강제 업그레이드
NVIM_MIN_VER="0.10.0"
nvim_needs_install=true
if command -v nvim >/dev/null 2>&1; then
    nvim_cur_ver="$(nvim --version 2>/dev/null | head -1 \
        | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
    if [[ -n "$nvim_cur_ver" ]] \
        && dpkg --compare-versions "$nvim_cur_ver" ge "$NVIM_MIN_VER"; then
        nvim_needs_install=false
        echo "    neovim already installed: $(nvim --version | head -1)"
    else
        echo "    nvim ${nvim_cur_ver:-unknown} < ${NVIM_MIN_VER}, upgrading from GitHub releases..."
    fi
fi
if $nvim_needs_install; then
    NVIM_ARCH="$(arch_triple "amd64:x86_64|arm64:aarch64")"
    if [[ -n "$NVIM_ARCH" ]]; then
        TMP_DIR="$(mktemp -d)"; _TMPFILES+=("$TMP_DIR")
        curl -fsSL -o "$TMP_DIR/nvim.tar.gz" \
            "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${NVIM_ARCH}.tar.gz"
        tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$TMP_DIR"
        NVIM_DIR="$(find "$TMP_DIR" -maxdepth 1 -type d -name 'nvim-linux-*' 2>/dev/null | head -1)"
        run_privileged cp -r "${NVIM_DIR}/." /usr/local/
        hash -r 2>/dev/null || true
        echo "    neovim installed: $(nvim --version | head -1)"
    else
        echo "    [!] Unsupported arch for neovim: $ARCH (skipping)"
    fi
fi

echo
echo "==> Installing git-delta from GitHub releases..."
DELTA_ARCH="$(arch_triple "amd64:amd64|arm64:arm64")"
if [[ -n "$DELTA_ARCH" ]]; then
    DELTA_TAG="$(cat "$_TAG_DIR/delta")"
    DELTA_VER="${DELTA_TAG#v}"
    install_gh_deb "delta" \
        "https://github.com/dandavison/delta/releases/download/${DELTA_TAG}/git-delta_${DELTA_VER}_${DELTA_ARCH}.deb"
else
    echo "    [!] Unsupported arch for delta: $ARCH (skipping)"
fi

echo
echo "==> Installing fzf from GitHub releases..."
# 22.04 apt의 fzf는 0.29, --bash 플래그는 0.48.0+ 필요 → 0.48.0+ 강제
FZF_MIN_VER="0.48.0"
fzf_needs_install=true
if command -v fzf >/dev/null 2>&1; then
    fzf_cur_ver="$(fzf --version 2>/dev/null \
        | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
    if [[ -n "$fzf_cur_ver" ]] \
        && dpkg --compare-versions "$fzf_cur_ver" ge "$FZF_MIN_VER"; then
        fzf_needs_install=false
        echo "    fzf already installed: $(fzf --version)"
    else
        echo "    fzf ${fzf_cur_ver:-unknown} < ${FZF_MIN_VER}, upgrading from GitHub releases..."
    fi
fi
if $fzf_needs_install; then
    FZF_ARCH="$(arch_triple "amd64:linux_amd64|arm64:linux_arm64")"
    if [[ -n "$FZF_ARCH" ]]; then
        FZF_TAG="$(cat "$_TAG_DIR/fzf")"
        FZF_VER="${FZF_TAG#v}"
        TMP_DIR="$(mktemp -d)"; _TMPFILES+=("$TMP_DIR")
        curl -fsSL -o "$TMP_DIR/fzf.tar.gz" \
            "https://github.com/junegunn/fzf/releases/download/${FZF_TAG}/fzf-${FZF_VER}-${FZF_ARCH}.tar.gz"
        tar -xzf "$TMP_DIR/fzf.tar.gz" -C "$TMP_DIR" fzf
        run_privileged install -m 755 "$TMP_DIR/fzf" /usr/local/bin/fzf
        hash -r 2>/dev/null || true
        echo "    fzf installed: $(fzf --version)"
    else
        echo "    [!] Unsupported arch for fzf: $ARCH (skipping)"
    fi
fi

echo
echo "==> Installing eza from GitHub releases..."
EZA_TRIPLE="$(arch_triple "amd64:x86_64-unknown-linux-gnu|arm64:aarch64-unknown-linux-gnu")"
if [[ -n "$EZA_TRIPLE" ]]; then
    install_gh_tar "eza" \
        "https://github.com/eza-community/eza/releases/latest/download/eza_${EZA_TRIPLE}.tar.gz"
else
    echo "    [!] Unsupported arch for eza: $ARCH (skipping)"
fi

echo
echo "==> Installing yq from GitHub releases..."
YQ_ARCH="$(arch_triple "amd64:linux_amd64|arm64:linux_arm64")"
if [[ -n "$YQ_ARCH" ]]; then
    install_gh_bin "yq" \
        "https://github.com/mikefarah/yq/releases/latest/download/yq_${YQ_ARCH}"
    else
    echo "    [!] Unsupported arch for yq: $ARCH (skipping)"
    fi

    fi

    # =============================================
    # 2. Node.js LTS (fnm)
    # =============================================
    echo
    echo "==> Installing Node.js LTS via fnm..."
    if command -v fnm >/dev/null 2>&1 || [[ -x "$HOME/.local/share/fnm/fnm" ]]; then
        eval "$(fnm env --shell bash)"
        if fnm install --lts; then
            # fnm uses the exact version number, but we can set default to the installed lts
            LTS_VER=$(fnm ls | grep "lts-latest" | awk '{print $2}' || true)
            if [[ -z "$LTS_VER" ]]; then
                LTS_VER=$(fnm ls | grep -o 'v[0-9]*\.[0-9]*\.[0-9]*' | tail -1)
            fi
            if [[ -n "$LTS_VER" ]]; then
                fnm default "$LTS_VER"
                fnm use "$LTS_VER"
            else
                # fallback
                fnm default lts-latest || true
                fnm use lts-latest || true
            fi
            echo "    Node $(node --version 2>/dev/null || echo 'not active yet') active."

            # statusLine.command의 fnm node 버전 경로 갱신 (버전 업 시 깨지는 절대 경로 수정)
            if [[ -f "$CLAUDE_DIR/settings.json" ]] && command -v jq >/dev/null 2>&1; then
                _node_ver="$(node --version 2>/dev/null || true)"
                _old_ver="$(jq -r '.statusLine.command // ""' "$CLAUDE_DIR/settings.json" \
                    | grep -oE 'fnm/node-versions/v[0-9]+\.[0-9]+\.[0-9]+' | head -1 \
                    | sed 's|fnm/node-versions/||' || true)"
                if [[ -n "$_old_ver" && "$_old_ver" != "$_node_ver" ]]; then
                    _tmp="$(mktemp)"; _TMPFILES+=("$_tmp")
                    jq --arg old "$_old_ver" --arg new "$_node_ver" \
                        '.statusLine.command |= gsub("/fnm/node-versions/" + $old + "/installation/node"; "/fnm/node-versions/" + $new + "/installation/node")' \
                        "$CLAUDE_DIR/settings.json" > "$_tmp" && mv "$_tmp" "$CLAUDE_DIR/settings.json"
                    echo "    Patched statusLine node path: $_old_ver → $_node_ver"
                elif [[ -n "$_old_ver" ]]; then
                    echo "    statusLine node path already up to date ($_node_ver)"
                fi
            fi
        else
            echo "    [!] fnm install --lts failed (network issue?). Run manually: fnm install --lts"
        fi
    else
        echo "    [!] fnm not found. Restart terminal and run:"
        echo "        fnm install --lts"
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
# 2-2. Codex 설정 배포 (config/codex/ + config/agents/global.md → ~/.codex/)
# =============================================
echo
echo "==> Deploying Codex config..."
mkdir -p "$CODEX_DIR"
merge_codex_config "$ROOT/config/codex/config.toml" "$CODEX_DIR/config.toml"

AGENTS_GLOBAL_SRC="$ROOT/config/agents/global.md"
if [[ -f "$AGENTS_GLOBAL_SRC" ]]; then
    cp -f "$AGENTS_GLOBAL_SRC" "$CODEX_DIR/AGENTS.md"
    echo "    Copied global agent instructions to AGENTS.md"
else
    echo "    [!] config/agents/global.md not found"
fi

# hooks.json: 단순 복사
CODEX_HOOKS_JSON_SRC="$ROOT/config/codex/hooks.json"
if [[ -f "$CODEX_HOOKS_JSON_SRC" ]]; then
    cp -f "$CODEX_HOOKS_JSON_SRC" "$CODEX_DIR/hooks.json"
    echo "    Copied hooks.json"
else
    echo "    [!] config/codex/hooks.json not found"
fi

# hooks/temporal-context.sh 배포
CODEX_HOOKS_DIR="$CODEX_DIR/hooks"
TEMPORAL_SRC="$ROOT/config/claude/hooks/temporal-context.sh"
if [[ -f "$TEMPORAL_SRC" ]]; then
    mkdir -p "$CODEX_HOOKS_DIR"
    cp -f "$TEMPORAL_SRC" "$CODEX_HOOKS_DIR/temporal-context.sh"
    chmod +x "$CODEX_HOOKS_DIR/temporal-context.sh"
    echo "    Copied temporal-context.sh to ~/.codex/hooks/ and set +x"
else
    echo "    [!] config/claude/hooks/temporal-context.sh not found, skipping."
fi

# =============================================
# 3. Claude Code 네이티브 설치
# =============================================
echo
if [[ "${SKIP_CLAUDE_CODE:-0}" == "1" ]]; then
    echo "==> [CI] Skipping Claude Code installation (SKIP_CLAUDE_CODE=1)"
else
    echo "==> Installing Claude Code (native)..."
    if command -v claude >/dev/null 2>&1; then
        echo "    Claude Code already installed: $(claude --version 2>/dev/null || echo unknown)"
    else
        curl -fsSL https://claude.ai/install.sh | bash
        echo "    Claude Code installed."
    fi

    # =============================================
    # 3-1. Claude Code 설정 배포 (config/claude/ + config/agents/global.md → ~/.claude/)
    # =============================================
    echo
    echo "==> Deploying Claude Code config..."
    mkdir -p "$CLAUDE_DIR"

    SETTINGS_SRC="$ROOT/config/claude/settings.json"
    SETTINGS_DST="$CLAUDE_DIR/settings.json"
    if [[ -f "$SETTINGS_SRC" ]]; then
        if [[ -f "$SETTINGS_DST" ]] && command -v jq >/dev/null 2>&1; then
            # 기존 키 보존(claude-hud의 statusLine 등) + 새 키 덮어쓰기/추가
            TMP="$(mktemp)"; _TMPFILES+=("$TMP")
            if jq -s '.[0] * .[1]' "$SETTINGS_DST" "$SETTINGS_SRC" > "$TMP" \
                && [[ -s "$TMP" ]]; then
                mv "$TMP" "$SETTINGS_DST"
                echo "    Merged settings.json"
            else
                echo "    [!] jq merge failed, keeping existing settings.json"
            fi
        else
            cp -f "$SETTINGS_SRC" "$SETTINGS_DST"
            echo "    Copied settings.json"
        fi
    else
        echo "    [!] config/claude/settings.json not found"
    fi

    if [[ -f "$AGENTS_GLOBAL_SRC" ]]; then
        cp -f "$AGENTS_GLOBAL_SRC" "$CLAUDE_DIR/CLAUDE.md"
        echo "    Copied global agent instructions to CLAUDE.md"
    else
        echo "    [!] config/agents/global.md not found"
    fi

    # hooks/: 배포 (temporal-context.sh 등) + 실행 권한
    HOOKS_SRC="$ROOT/config/claude/hooks"
    HOOKS_DST="$CLAUDE_DIR/hooks"
    if [[ -d "$HOOKS_SRC" ]]; then
        mkdir -p "$HOOKS_DST"
        cp -rf "$HOOKS_SRC/." "$HOOKS_DST/"
        chmod +x "$HOOKS_DST"/*.sh 2>/dev/null || true
        echo "    Copied hooks/ and set +x"
    else
        echo "    [!] config/claude/hooks not found, skipping."
    fi
fi

# =============================================
# 3-2. RTK (Rust Token Killer) + Claude hook
# =============================================
echo
if [[ "${SKIP_RTK:-0}" == "1" ]]; then
    echo "==> [CI] Skipping RTK installation (SKIP_RTK=1)"
else
    echo "==> Installing RTK (Rust Token Killer)..."
    # 공식 install.sh — ~/.local/bin 에 binary 배치
    if curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh; then
        echo "    RTK installed."
    else
        echo "    [!] RTK install failed. Manual: cargo install --git https://github.com/rtk-ai/rtk"
    fi

    # Claude hook 등록은 config/claude/settings.json의 `rtk hook claude` 엔트리로 미리 정의되어 있고 3-1 단계의 jq deep-merge로 ~/.claude/settings.json에 반영됨
fi

# =============================================
# 4. bash 프로파일 설정 (~/.bashrc, ~/.inputrc, 마커 방식)
# =============================================
echo
echo "==> Updating bash profile..."
for _profile in bashrc inputrc; do
    _src="$ROOT/config/bash/$_profile"
    if [[ -f "$_src" ]]; then
        set_profile_block "$HOME/.$_profile" "$(cat "$_src")"
    elif [[ "$_profile" == "bashrc" ]]; then
        echo "    [!] config/bash/bashrc not found, skipping bashrc."
    fi
done

# =============================================
# 6. Claude Code skills 설치 (manifests/skills.txt)
# =============================================
echo
if [[ "${SKIP_SKILLS:-0}" == "1" ]]; then
    echo "==> [CI] Skipping Claude Code skills (SKIP_SKILLS=1)"
else
    echo "==> Restoring Claude Code skills..."
    SKILLS_FILE="$ROOT/manifests/skills.txt"
    if [[ -f "$SKILLS_FILE" ]] && command -v npx >/dev/null 2>&1; then
        while IFS= read -r line; do
            [[ "$line" =~ ^([^@]+)@(.+)$ ]] || continue
            repo="${BASH_REMATCH[1]}"
            skill="${BASH_REMATCH[2]}"
            echo "    Adding skill: $skill from $repo..."
            if ! npx -y skills add "$repo" --skill "$skill" --global --yes --agent claude-code </dev/null >/dev/null 2>&1; then
                echo "    [!] Failed: $repo@$skill"
            fi
        done < <(manifest_lines "$SKILLS_FILE")
        echo "    Skills restored."
    else
        echo "    [!] manifests/skills.txt or npx not found, skipping skills."
    fi
fi

echo
echo "==> Done! Restart your terminal, Codex, and Claude Code to apply all changes."
