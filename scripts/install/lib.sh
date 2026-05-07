#!/usr/bin/env bash

DOTFILES_BEGIN_MARKER="# ===== dotfiles-begin ====="
DOTFILES_END_MARKER="# ===== dotfiles-end ====="

DOTFILES_DRY_RUN="${DOTFILES_DRY_RUN:-false}"
DOTFILES_BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"

_TMPFILES=()
cleanup_tmpfiles() {
    if [[ ${#_TMPFILES[@]} -gt 0 ]]; then
        rm -rf "${_TMPFILES[@]}"
    fi
}

log_step() { printf '\n==> %s\n' "$*"; }
log_ok() { printf '    [ok] %s\n' "$*"; }
log_skip() { printf '    [skip] %s\n' "$*"; }
log_warn() { printf '    [warn] %s\n' "$*"; }
log_fail() { printf '    [fail] %s\n' "$*"; }

is_dry_run() {
    [[ "$DOTFILES_DRY_RUN" == "true" ]]
}

run_cmd() {
    if is_dry_run; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

manifest_lines() {
    local path="$1"
    [[ -f "$path" ]] || return 0
    LC_ALL=C sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$path" | awk '{$1=$1; print}'
}

comma_has() {
    local list="$1" item="$2"
    [[ -z "$list" ]] && return 1
    case ",$list," in
        *",$item,"*) return 0 ;;
        *) return 1 ;;
    esac
}

should_run_step() {
    local step="$1" only="${DOTFILES_ONLY:-}" skip="${DOTFILES_SKIP:-}"
    if [[ -n "$only" ]] && ! comma_has "$only" "$step"; then
        return 1
    fi
    if comma_has "$skip" "$step"; then
        return 1
    fi
    return 0
}

backup_path_for() {
    local target="$1" rel
    rel="${target#"$HOME"/}"
    if [[ "$rel" == "$target" ]]; then
        rel="${target#/}"
    fi
    printf '%s/%s' "$DOTFILES_BACKUP_ROOT" "$rel"
}

backup_existing() {
    local target="$1" backup
    [[ -e "$target" || -L "$target" ]] || return 0
    backup="$(backup_path_for "$target")"
    if is_dry_run; then
        log_skip "Would back up $target -> $backup"
        return 0
    fi
    mkdir -p "$(dirname "$backup")"
    if [[ -d "$target" && ! -L "$target" ]]; then
        cp -a "$target" "$backup"
    else
        cp -a "$target" "$backup"
    fi
    log_ok "Backed up $target -> $backup"
}

copy_managed_file() {
    local src="$1" dst="$2"
    if [[ ! -f "$src" ]]; then
        log_warn "$src not found, skipping"
        return 0
    fi
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        log_skip "$dst already up to date"
        return 0
    fi
    backup_existing "$dst"
    if is_dry_run; then
        log_skip "Would copy $src -> $dst"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    cp -f "$src" "$dst"
    log_ok "Copied $src -> $dst"
}

copy_managed_dir() {
    local src="$1" dst="$2"
    if [[ ! -d "$src" ]]; then
        log_warn "$src not found, skipping"
        return 0
    fi
    if [[ -d "$dst" ]] && diff -qr "$src" "$dst" >/dev/null 2>&1; then
        log_skip "$dst already up to date"
        return 0
    fi
    backup_existing "$dst"
    if is_dry_run; then
        log_skip "Would replace $dst with $src"
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -rf "$src/." "$dst/"
    log_ok "Deployed $src -> $dst"
}

set_profile_block() {
    local file="$1" content="$2"
    local block tmp
    block="$(printf '%s\n%s\n%s' "$DOTFILES_BEGIN_MARKER" "$content" "$DOTFILES_END_MARKER")"

    backup_existing "$file"
    if is_dry_run; then
        log_skip "Would update marker block in $file"
        return 0
    fi

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    if grep -qF "$DOTFILES_BEGIN_MARKER" "$file" && grep -qF "$DOTFILES_END_MARKER" "$file"; then
        tmp="$(mktemp)"; _TMPFILES+=("$tmp")
        awk -v begin="$DOTFILES_BEGIN_MARKER" -v end="$DOTFILES_END_MARKER" -v repl="$block" '
            BEGIN { skip = 0 }
            $0 == begin { print repl; skip = 1; next }
            skip && $0 == end { skip = 0; next }
            !skip { print }
        ' "$file" > "$tmp"
        mv "$tmp" "$file"
        log_ok "Updated dotfiles block in $file"
    else
        printf '\n%s\n' "$block" >> "$file"
        log_ok "Appended dotfiles block to $file"
    fi
}

merge_gitconfig() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        log_warn "$path not found, skipping"
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
                    run_cmd git config --global "$section.$key" "$value"
                    log_ok "Added [$section] $key = $value"
                else
                    log_skip "[$section] $key already set"
                fi
            fi
        fi
    done < "$path"
}

add_to_path_runtime() {
    local dir="$1"
    case ":$PATH:" in
        *":$dir:"*) ;;
        *) export PATH="$dir:$PATH" ;;
    esac
}

run_privileged() {
    if [[ "$(id -u)" -eq 0 ]]; then
        run_cmd "$@"
    else
        run_cmd sudo "$@"
    fi
}

retry_curl() {
    curl --retry 3 --retry-delay 2 --connect-timeout 15 -fsSL "$@"
}

gh_release_tag() {
    local repo="$1"
    if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        retry_curl -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$repo/releases/latest" \
            | jq -r '.tag_name // empty'
    else
        retry_curl "https://api.github.com/repos/$repo/releases/latest" \
            | jq -r '.tag_name // empty'
    fi
}

arch_triple() {
    local schema="$1" arch="$2" entry
    for entry in $(echo "$schema" | tr '|' ' '); do
        if [[ "${entry%%:*}" == "$arch" ]]; then
            echo "${entry#*:}"
            return 0
        fi
    done
}

version_ge() {
    local have="$1" need="$2"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg --compare-versions "$have" ge "$need"
    else
        [[ "$have" == "$need" || "$(printf '%s\n%s\n' "$need" "$have" | sort -V | head -1)" == "$need" ]]
    fi
}
