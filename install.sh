#!/usr/bin/env bash
# Linux(Ubuntu 22.04+)·macOS 설치. 실행: bash install.sh
# 여러 번 실행해도 된다. 실패한 단계는 마지막에 모아 보여 주고 종료 코드 1로 끝난다.
# macOS 기본 bash(3.2)에서도 돌아야 하므로 mapfile 같은 bash 4 기능은 쓰지 않는다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"
BIN="$HOME/.local/bin"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
FAILED=()

mkdir -p "$BIN"
export PATH="$BIN:$PATH"

step() { printf '\n==> %s\n' "$1"; }
fail() { echo "    [!] $1" >&2; FAILED+=("$1"); }
as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
quiet() { "$@" >/dev/null 2>&1 </dev/null; }

# 매니페스트에서 주석과 빈 줄을 뺀 항목
manifest() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$ROOT/manifests/$1"; }

# 저장소 파일이나 디렉터리를 덮어쓴다. 원본은 git에 있으므로 백업하지 않는다.
deploy() {
    if [[ -d "$ROOT/$1" ]]; then
        mkdir -p "$2" && cp -R "$ROOT/$1/." "$2/"
    else
        mkdir -p "$(dirname "$2")" && cp "$ROOT/$1" "$2"
    fi
}

# 앱이 스스로 다시 쓰는 설정 파일은 병합한다. 겹치는 키는 기존 값이 이긴다.
merge_config() {
    if [[ ! -f $2 ]]; then deploy "$1" "$2"; return; fi
    local merged
    case $1 in
        *.json) merged="$(jq -s '.[0] * .[1]' "$ROOT/$1" "$2")" ;;
        *) merged="$(yq eval-all -p toml -o toml 'select(fileIndex == 0) * select(fileIndex == 1)' "$ROOT/$1" "$2")" ;;
    esac || { fail "merge failed: $2"; return; }
    printf '%s\n' "$merged" > "$2"
}

# 마커 사이 블록만 교체한다. 블록 밖의 사용자 내용은 그대로 둔다.
set_profile_block() {
    local begin='# ===== dotfiles-begin =====' end='# ===== dotfiles-end ====='
    touch "$1"
    awk -v b="$begin" -v e="$end" '$0 == b { skip = 1 } !skip { print } $0 == e { skip = 0 }' "$1" > "$TMP/profile"
    { cat "$TMP/profile"; printf '%s\n%s\n%s\n' "$begin" "$2" "$end"; } > "$1"
}

# GitHub 최신 릴리스를 받아 ~/.local/bin에 둔다. 이미 최신이면 건너뛴다.
install_release() {
    local name=$1 repo=$2 asset=$3 url tag version dir
    url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")" || return 1
    tag="${url##*/}"
    version="${tag##*v}"
    if [[ "$("$BIN/$name" --version 2>/dev/null)" == *"$version"* ]]; then
        echo "    $name $version"
        return 0
    fi
    asset="${asset//\{v\}/$version}"
    dir="$TMP/$name"
    mkdir -p "$dir"
    curl -fsSL -o "$dir/$asset" "https://github.com/$repo/releases/download/$tag/$asset" || return 1
    case $asset in
        *.tar.gz) tar -xzf "$dir/$asset" -C "$dir" ;;
        *.zip) unzip -qo "$dir/$asset" -d "$dir" ;;
        *) mv "$dir/$asset" "$dir/$name" ;;
    esac || return 1
    if [[ $name == nvim ]]; then
        rm -rf "$HOME/.local/opt/nvim"
        mkdir -p "$HOME/.local/opt"
        mv "$dir"/nvim-linux-*/ "$HOME/.local/opt/nvim" || return 1
        ln -sf "$HOME/.local/opt/nvim/bin/nvim" "$BIN/nvim"
    else
        install -m 755 "$(find "$dir" -type f -name "$name" | head -n 1)" "$BIN/$name" || return 1
    fi
    if [[ $name == bun ]]; then ln -sf bun "$BIN/bunx"; fi
    echo "    $name $version"
}

# 없으면 공식 installer로 설치하고, 있으면 도구의 update 명령으로 최신을 맞춘다.
install_or_update() {
    if command -v "$1" >/dev/null; then "$1" update || fail "$1 update failed"; return; fi
    curl -fsSL "$2" | bash || fail "$1 installer failed: $2"
}

if [[ $OS == Darwin ]]; then
    step 'Homebrew packages'
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [[ -x $brew_bin ]]; then eval "$("$brew_bin" shellenv)"; break; fi
    done
    if ! command -v brew >/dev/null; then echo 'Homebrew is required: https://brew.sh' >&2; exit 1; fi
    brew bundle --file="$ROOT/manifests/Brewfile" || fail 'brew bundle'
else
    step 'apt packages'
    as_root apt-get update || fail 'apt-get update'
    # shellcheck disable=SC2046  # 매니페스트 항목을 인자로 펼친다
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $(manifest apt.txt) ||
        fail 'apt-get install'
    # Ubuntu는 bat과 fd를 batcat, fdfind라는 이름으로 설치한다
    if command -v batcat >/dev/null; then ln -sf "$(command -v batcat)" "$BIN/bat"; fi
    if command -v fdfind >/dev/null; then ln -sf "$(command -v fdfind)" "$BIN/fd"; fi

    step 'GitHub releases'
    while IFS=$'\t' read -r name repo x86_64 aarch64; do
        asset=$x86_64
        if [[ $(uname -m) == aarch64 ]]; then asset=$aarch64; fi
        install_release "$name" "$repo" "$asset" || fail "$name ($repo)"
    done < <(manifest github-releases.tsv)
fi

step 'git config'
# gitconfig의 키 중 아직 값이 없는 것만 넣는다. 이미 있는 값은 사용자 설정이다.
git config --file "$ROOT/config/git/gitconfig" --list | while IFS='=' read -r key value; do
    git config --global --get "$key" >/dev/null || git config --global "$key" "$value"
done
git config --global core.autocrlf input
git config --global core.fileMode true

step 'config files'
merge_config config/claude/settings.json "$HOME/.claude/settings.json"
deploy config/claude/hooks "$HOME/.claude/hooks"
deploy config/claude/statusline.sh "$HOME/.claude/statusline.sh"
deploy config/claude/claude-hud.json "$HOME/.claude/claude-hud.json"
merge_config config/codex/config.toml "$HOME/.codex/config.toml"
merge_config config/codex/hooks.json "$HOME/.codex/hooks.json"
deploy config/codex/hooks "$HOME/.codex/hooks"
merge_config config/agy/hooks.json "$HOME/.gemini/config/hooks.json"
deploy config/agy/hooks "$HOME/.gemini/hooks"
merge_config config/herdr/config.toml "$HOME/.config/herdr/config.toml"
deploy config/tmux/tmux.linux.conf "$HOME/.tmux.conf"
deploy config/nvim "$HOME/.config/nvim"
deploy config/starship.toml "$HOME/.config/starship.toml"

step 'Node.js LTS (fnm)'
if command -v fnm >/dev/null; then
    eval "$(fnm env --shell bash)"
    fnm install --lts || fail 'fnm install --lts'
    fnm default lts-latest || fail 'fnm default lts-latest'
    fnm use lts-latest || fail 'fnm use lts-latest'
    # 셸 밖에서 뜬 프로세스(Claude Code hook 등)도 node를 찾도록 fnm 기본 버전을 ~/.local/bin에 연결한다
    for node_bin in node npm npx; do ln -sf "$FNM_DIR/aliases/default/bin/$node_bin" "$BIN/$node_bin"; done
else
    fail 'fnm not found'
fi

step 'npm global packages'
# shellcheck disable=SC2046  # 매니페스트 항목을 인자로 펼친다
npm install -g $(manifest npm-global.txt) || fail 'npm install -g'

step 'Claude Code, Antigravity CLI, herdr'
install_or_update claude https://claude.ai/install.sh
install_or_update agy https://antigravity.google/cli/install.sh
if [[ $OS != Darwin ]]; then install_or_update herdr https://herdr.dev/install.sh; fi

step 'shell profiles'
if [[ $OS == Darwin ]]; then
    set_profile_block "$HOME/.zshrc" "$(cat "$ROOT/config/zsh/zshrc")"
else
    set_profile_block "$HOME/.bashrc" "$(cat "$ROOT/config/bash/bashrc")"
    set_profile_block "$HOME/.inputrc" "$(cat "$ROOT/config/bash/inputrc")"
fi

step 'skills'
while IFS='@' read -r repo name; do
    if quiet npx -y skills add "$repo" --skill "$name" --global --yes --agent claude-code; then
        echo "    $repo@$name"
    else
        fail "skill $repo@$name"
    fi
done < <(manifest skills.txt)

step 'Claude Code plugins'
# add·install은 이미 있으면 아무것도 하지 않으므로, 카탈로그를 새로 받고 update로 최신을 맞춘다
while read -r marketplace plugin; do
    if quiet claude plugin marketplace add "$marketplace" &&
        quiet claude plugin marketplace update "${plugin#*@}" &&
        quiet claude plugin install "$plugin" &&
        quiet claude plugin update "$plugin"; then
        echo "    $plugin"
    else
        fail "plugin $plugin"
    fi
done < <(manifest plugins.txt)

if (( ${#FAILED[@]} )); then
    printf '\n==> %d step(s) failed\n' "${#FAILED[@]}"
    printf '    [!] %s\n' "${FAILED[@]}"
    exit 1
fi
printf '\n==> Done. Restart the shell and Claude Code.\n'
