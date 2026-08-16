#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-profile.XXXXXX")"
export HOME="$work/home"
export DOTFILES_FUNCTIONS_ONLY=1
source "$repo/install.sh"
unset DOTFILES_FUNCTIONS_ONLY
trap '_cleanup; rm -rf "$work"' EXIT

assert_profile_rejected() {
    local name="$1" value="$2" file="$work/invalid-$1" before="$work/invalid-$1.before"
    printf '%s' "$value" > "$file"
    cp "$file" "$before"
    if set_profile_block "$file" managed 2> "$work/invalid-$name.err"; then
        echo "$name marker가 실패로 반환되지 않았습니다." >&2
        return 1
    fi
    cmp -s "$before" "$file"
    grep -Fq 'Invalid dotfiles marker' "$work/invalid-$name.err"
}

remove_profile_block_test() {
    local file="$1" begin='# ===== dotfiles-begin =====' end='# ===== dotfiles-end ====='
    local begin_exact end_exact begin_any end_any begin_line end_line tmp
    begin_exact="$(grep -Fxc -- "$begin" "$file" || true)"
    end_exact="$(grep -Fxc -- "$end" "$file" || true)"
    begin_any="$(grep -Fc -- "$begin" "$file" || true)"
    end_any="$(grep -Fc -- "$end" "$file" || true)"
    [[ "$begin_any" == "0" && "$end_any" == "0" ]] && return 0
    [[ "$begin_exact" == "1" && "$end_exact" == "1" &&
       "$begin_any" == "1" && "$end_any" == "1" ]] || return 1
    begin_line="$(grep -nFx -- "$begin" "$file" | cut -d: -f1)"
    end_line="$(grep -nFx -- "$end" "$file" | cut -d: -f1)"
    (( begin_line < end_line )) || return 1
    tmp="$(mktemp)"; _TMPFILES+=("$tmp")
    awk -v begin="$begin" -v end="$end" '
        BEGIN { skip = 0; found_begin = 0; found_end = 0 }
        $0 == begin { found_begin++; skip = 1; next }
        skip && $0 == end { found_end++; skip = 0; next }
        !skip { print }
        END { if (skip || found_begin != 1 || found_end != 1) exit 1 }
    ' "$file" > "$tmp" || return 1
    mv "$tmp" "$file"
}

OS=Darwin
for file in .bashrc .inputrc .zprofile .zshrc; do
    printf 'user-before-%s\n# ===== dotfiles-begin =====\nold\n# ===== dotfiles-end =====\nuser-after-%s\n' \
        "$file" "$file" > "$HOME/$file"
done

install_shell_profiles
for file in .bashrc .inputrc .zprofile .zshrc; do
    cp "$HOME/$file" "$work/${file#.}.first"
done

install_shell_profiles
for file in .bashrc .inputrc .zprofile .zshrc; do
    cmp -s "$work/${file#.}.first" "$HOME/$file"
    grep -Fxq "user-before-$file" "$HOME/$file"
    grep -Fxq "user-after-$file" "$HOME/$file"
done

grep -Fq '\builtin pwd -L' "$HOME/.bashrc"
grep -Fq '"\e[A": history-search-backward' "$HOME/.inputrc"
grep -Fq '$include /etc/inputrc' "$HOME/.inputrc"
grep -Fq 'set input-meta on' "$HOME/.inputrc"
grep -Fq 'set convert-meta off' "$HOME/.inputrc"
# include가 저장소 설정보다 먼저 와야 bell-style none / history-search 바인딩이 시스템 값을 이긴다.
[[ "$(grep -nF '$include /etc/inputrc' "$HOME/.inputrc" | cut -d: -f1)" \
   -lt "$(grep -nF 'set convert-meta off' "$HOME/.inputrc" | cut -d: -f1)" ]]
grep -Fq '/opt/homebrew/bin/brew shellenv' "$HOME/.zprofile"
grep -Fq '/usr/local/bin/brew shellenv' "$HOME/.zprofile"
grep -Fq 'fnm env --use-on-cd --shell zsh' "$HOME/.zshrc"
grep -Fq 'starship init zsh' "$HOME/.zshrc"

assert_profile_rejected inline $'custom-prefix # ===== dotfiles-begin =====\nuser-command\ncustom-suffix # ===== dotfiles-end =====\n'
assert_profile_rejected reverse $'user-before\n# ===== dotfiles-end =====\nuser-middle\n# ===== dotfiles-begin =====\nuser-after\n'
assert_profile_rejected incomplete $'user-before\n# ===== dotfiles-begin =====\ninterrupted\nuser-after\n'
assert_profile_rejected duplicate $'# ===== dotfiles-begin =====\none\n# ===== dotfiles-end =====\n# ===== dotfiles-begin =====\ntwo\n# ===== dotfiles-end =====\n'

for file in "$work"/invalid-*; do
    [[ "$file" == *.before || "$file" == *.err ]] && continue
    cp "$file" "$file.remove-before"
    if remove_profile_block_test "$file"; then
        echo "invalid marker가 제거 경로에서 실패하지 않았습니다: $file" >&2
        exit 1
    fi
    cmp -s "$file.remove-before" "$file"
done

for file in .bashrc .inputrc .zprofile .zshrc; do
    remove_profile_block_test "$HOME/$file"
    grep -Fxq "user-before-$file" "$HOME/$file"
    grep -Fxq "user-after-$file" "$HOME/$file"
    ! grep -Fq '# ===== dotfiles-' "$HOME/$file"
done

echo "shell profile idempotency checks passed"
