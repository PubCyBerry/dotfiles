#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2317
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

INSTALL_FAILURES=""
record_install_failure() {
    echo "    [!] $1" >&2
    INSTALL_FAILURES="${INSTALL_FAILURES}${INSTALL_FAILURES:+
}$1"
}

finish_install() {
    if [[ -n "$INSTALL_FAILURES" ]]; then
        echo
        echo "==> Installation failed"
        while IFS= read -r failure; do echo "    [!] $failure"; done <<< "$INSTALL_FAILURES"
        return 1
    fi
    echo
    echo "==> Done! Restart your terminal, Codex, and Claude Code to apply all changes."
}

validate_plugin_manifest() {
    local path="$1" content line market plugin scope extra count=0
    content="$(manifest_lines "$path")" || return 1
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        count=$((count + 1))
        read -r market plugin scope extra <<< "$line"
        [[ -n "$market" && -n "$plugin" && -z "$extra" ]] || {
            echo "Invalid plugins manifest field count: $line" >&2; return 1;
        }
        scope="${scope:-user}"
        [[ "$scope" =~ ^(user|project|local)$ ]] || {
            echo "Invalid plugin scope: $line" >&2; return 1;
        }
        [[ "$plugin" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$ ]] || {
            echo "Invalid plugin ID: $line" >&2; return 1;
        }
    done <<< "$content"
    (( count > 0 )) || { echo "plugins manifest has no entries: $path" >&2; return 1; }
}

restore_claude_plugins() {
    local path="$1" content line market plugin scope extra failed=0 count=0
    content="$(manifest_lines "$path")" || return 1
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        count=$((count + 1))
        read -r market plugin scope extra <<< "$line"
        [[ -n "$market" && -n "$plugin" && -z "$extra" ]] || return 1
        scope="${scope:-user}"
        [[ "$scope" =~ ^(user|project|local)$ && "$plugin" =~ ^[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$ ]] || return 1
    done <<< "$content"
    (( count > 0 )) || return 1
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        read -r market plugin scope <<< "$line"
        scope="${scope:-user}"
        echo "    Adding marketplace: $market (scope: $scope)..."
        if ! claude plugin marketplace add "$market" --scope "$scope" </dev/null >/dev/null 2>&1; then
            echo "    [!] Failed to add marketplace: $market"
            failed=1
            continue
        fi
        echo "    Installing plugin: $plugin (scope: $scope)..."
        if ! claude plugin install "$plugin" --scope "$scope" </dev/null >/dev/null 2>&1; then
            echo "    [!] Failed to install plugin: $plugin"
            failed=1
        fi
    done <<< "$content"
    (( failed == 0 ))
}

restore_claude_skills() {
    local path="$1" content row repo skill failed=0 count=0
    content="$(manifest_lines "$path")" || return 1
    while IFS= read -r row; do
        [[ -n "$row" ]] || continue
        count=$((count + 1))
        [[ "$row" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+@[A-Za-z0-9._-]+$ ]] || {
            echo "Invalid skills manifest row: $row" >&2; return 1;
        }
    done <<< "$content"
    (( count > 0 )) || { echo "skills manifest has no entries: $path" >&2; return 1; }
    while IFS= read -r row; do
        repo="${row%@*}"; skill="${row##*@}"
        echo "    Adding skill: $skill from $repo..."
        if ! npx -y skills add "$repo" --skill "$skill" --global --yes --agent claude-code </dev/null >/dev/null 2>&1; then
            echo "    [!] Failed: $row"
            failed=1
        fi
    done <<< "$content"
    (( failed == 0 ))
}

stage_is_skipped() { [[ "${!1:-0}" == 1 ]]; }

run_optional_stage() {
    local flag="$1" message="$2" action="$3"
    if stage_is_skipped "$flag"; then echo "$message"; return; fi
    "$action"
}

run_skills_stage() {
    local path="$1"
    if stage_is_skipped SKIP_SKILLS; then echo "==> [CI] Skipping Claude Code skills (SKIP_SKILLS=1)"; return; fi
    echo "==> Restoring Claude Code skills..."
    if [[ ! -f "$path" ]]; then record_install_failure "Required manifest missing: manifests/skills.txt"
    elif ! command -v npx >/dev/null 2>&1; then record_install_failure "npx is required for manifests/skills.txt."
    elif restore_claude_skills "$path"; then echo "    Skills restored."
    else record_install_failure "One or more Claude skills failed."
    fi
}

run_plugins_stage() {
    local path="$1"
    if stage_is_skipped SKIP_PLUGINS; then echo "==> [CI] Skipping Claude Code plugins (SKIP_PLUGINS=1)"; return; fi
    echo "==> Restoring Claude Code plugins..."
    if [[ ! -f "$path" ]]; then record_install_failure "Required manifest missing: manifests/plugins.txt"
    elif ! validate_plugin_manifest "$path"; then record_install_failure "Invalid manifests/plugins.txt."
    elif ! command -v claude >/dev/null 2>&1; then record_install_failure "claude is required for manifests/plugins.txt."
    elif restore_claude_plugins "$path"; then echo "    Plugins restored."
    else record_install_failure "One or more Claude plugins failed."
    fi
}

RECEIPT_PATH="${DOTFILES_RECEIPT_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-receipt.json}"
RECEIPT_READY=false
FUNCTIONS_ONLY_MODE="${DOTFILES_FUNCTIONS_ONLY:-0}"

receipt_path_is_safe() {
    [[ ! -L "$RECEIPT_PATH" && ( ! -e "$RECEIPT_PATH" || -f "$RECEIPT_PATH" ) ]]
}

receipt_init() {
    if ! receipt_path_is_safe; then
        echo "    [!] Invalid install receipt path type; preserving it: $RECEIPT_PATH" >&2
        RECEIPT_READY=false
        return 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "    [!] jq unavailable; skipping receipt-managed writes." >&2
        RECEIPT_READY=false
        return 1
    fi
    if [[ -f "$RECEIPT_PATH" ]]; then
        if jq -e '.schemaVersion == 1 and (.artifacts|type)=="object" and (.packages|type)=="object" and (.values|type)=="object"' "$RECEIPT_PATH" >/dev/null 2>&1; then
            RECEIPT_READY=true
            return 0
        fi
        echo "    [!] Invalid install receipt; preserving it and skipping managed writes: $RECEIPT_PATH" >&2
        RECEIPT_READY=false
        return 1
    fi
    local dir tmp
    dir="$(dirname "$RECEIPT_PATH")"
    mkdir -p "$dir" || return 1
    chmod 700 "$dir" || return 1
    tmp="$(mktemp "$dir/.install-receipt.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    printf '%s\n' '{"schemaVersion":1,"artifacts":{},"packages":{},"values":{}}' > "$tmp" || return 1
    jq -e '.schemaVersion == 1 and (.artifacts|type)=="object" and (.packages|type)=="object" and (.values|type)=="object"' "$tmp" >/dev/null || return 1
    chmod 600 "$tmp" || return 1
    mv "$tmp" "$RECEIPT_PATH" || return 1
    RECEIPT_READY=true
}

receipt_preflight() {
    if ! receipt_path_is_safe; then
        return 1
    elif [[ -f "$RECEIPT_PATH" ]] && ! command -v jq >/dev/null 2>&1; then
        receipt_is_jq_bootstrap
    elif [[ -f "$RECEIPT_PATH" ]]; then receipt_init
    elif command -v jq >/dev/null 2>&1; then receipt_init
    fi
}

receipt_is_jq_bootstrap() {
    local actual apt_expected brew_expected
    actual="$(cat "$RECEIPT_PATH" 2>/dev/null)" || return 1
    apt_expected='{"schemaVersion":1,"bootstrap":"dotfiles-apt-jq-v1","artifacts":{},"packages":{"apt:jq":{"before":{"present":false,"value":null},"installed":null,"pending":{"previousPresent":false,"previousValue":null,"newEntry":true}}},"values":{}}'
    brew_expected='{"schemaVersion":1,"bootstrap":"dotfiles-brew-jq-v1","artifacts":{},"packages":{"brew:jq":{"before":{"present":false,"value":null},"installed":null,"pending":{"previousPresent":false,"previousValue":null,"newEntry":true}}},"values":{}}'
    [[ "$actual" == "$apt_expected" || "$actual" == "$brew_expected" ]]
}

receipt_bootstrap_jq() {
    local manager="$1" before_present="${2:-false}" dir tmp marker
    [[ "$manager" == apt || "$manager" == brew ]] || return 1
    if [[ "$before_present" == true ]]; then
        echo "    [!] jq package exists but its executable is unavailable; preserving package ownership." >&2
        return 1
    fi
    receipt_path_is_safe || return 1
    if [[ -e "$RECEIPT_PATH" ]]; then receipt_is_jq_bootstrap; return; fi
    dir="$(dirname "$RECEIPT_PATH")"
    mkdir -p "$dir" || return 1
    chmod 700 "$dir" || return 1
    tmp="$(mktemp "$dir/.install-receipt.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    marker="dotfiles-$manager-jq-v1"
    printf '{"schemaVersion":1,"bootstrap":"%s","artifacts":{},"packages":{"%s:jq":{"before":{"present":false,"value":null},"installed":null,"pending":{"previousPresent":false,"previousValue":null,"newEntry":true}}},"values":{}}\n' \
        "$marker" "$manager" > "$tmp" || return 1
    chmod 600 "$tmp" || return 1
    mv "$tmp" "$RECEIPT_PATH" || return 1
}

receipt_commit() {
    local tmp
    tmp="$(mktemp "$(dirname "$RECEIPT_PATH")/.install-receipt.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    if jq "$@" "$RECEIPT_PATH" > "$tmp" && jq empty "$tmp"; then
        chmod 600 "$tmp" || return 1
        mv "$tmp" "$RECEIPT_PATH" || return 1
    else
        rm -f "$tmp"
        return 1
    fi
}

file_hash() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
    else shasum -a 256 "$1" | awk '{print $1}'
    fi
}
file_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }

# symlink 체인을 끝까지 풀어 실경로를 얻는다.
# fnm은 셸마다 `<tmp>/fnm_multishells/<pid>_<timestamp>` 링크를 새로 만들기 때문에
# `npm prefix -g` 결과를 그대로 쓰면 실행마다 값이 달라진다. `cd -P`는 POSIX라 macOS에서도 동작한다.
resolve_link_path() {
    local path="$1"
    [[ -n "$path" ]] || return 1
    if [[ -d "$path" ]]; then (cd -P -- "$path" 2>/dev/null && pwd -P) && return 0; fi
    printf '%s\n' "${path%/}"
}

# fnm multishell 경로는 셸 수명 동안만 유효하다. receipt에 남아 있으면 링크를 풀지 않고 기록한 잔재다.
is_ephemeral_npm_prefix() {
    local path="${1:-}" tmp="${TMPDIR:-/tmp}"
    [[ -n "$path" ]] || return 1
    case "${path%/}/" in "${tmp%/}/fnm_multishells/"*|/tmp/fnm_multishells/*) return 0 ;; esac
    return 1
}

managed_parent_is_safe() {
    local path="$1" parent next boundary=""
    case "$path" in "$HOME"/*) boundary="${HOME%/}"; [[ -n "$boundary" ]] || boundary=/ ;; esac
    parent="$(dirname "$path")"
    while [[ -n "$parent" && "$parent" != "$boundary" && "$parent" != / && "$parent" != . ]]; do
        if [[ -L "$parent" || ( -e "$parent" && ! -d "$parent" ) ]]; then return 1; fi
        next="$(dirname "$parent")"
        [[ "$next" != "$parent" ]] || break
        parent="$next"
    done
    return 0
}

install_managed_file() {
    local src="$1" dst="$2" collision="${3:-takeover}"
    local entry_hash="" before_hash="" source_hash backup="" n=0 tmp pending expected_hash expected_exists current_exists=false
    local before_exists installed_hash backup_tmp before_mode="" current_mode="" expected_mode="" source_mode
    $RECEIPT_READY && [[ -f "$src" ]] || return 1
    if ! managed_parent_is_safe "$dst"; then
        echo "    [!] Unsupported destination parent path; preserving: $dst" >&2
        return 1
    fi
    if [[ -e "$dst" || -L "$dst" ]] && { [[ ! -f "$dst" ]] || [[ -L "$dst" ]]; }; then
        echo "    [!] Unsupported destination type; preserving: $dst" >&2
        return 1
    fi
    source_hash="$(file_hash "$src")"
    source_mode="$(file_mode "$src")"
    if [[ -f "$dst" ]]; then before_hash="$(file_hash "$dst")"; before_mode="$(file_mode "$dst")"; fi
    entry_hash="$(jq -r --arg path "$dst" '.artifacts[$path].installedHash // empty' "$RECEIPT_PATH")"
    pending="$(jq -r --arg path "$dst" '.artifacts[$path].pending // false' "$RECEIPT_PATH")"

    if jq -e --arg path "$dst" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
        if [[ "$pending" == true && -f "$dst" && "$before_hash" == "$(jq -r --arg path "$dst" '.artifacts[$path].targetHash // empty' "$RECEIPT_PATH")" ]]; then
            [[ "$(file_mode "$dst")" == "$(jq -r --arg path "$dst" '.artifacts[$path].targetMode // empty' "$RECEIPT_PATH")" ]] || { echo "    [!] Pending managed file mode changed; preserving: $dst" >&2; return 1; }
            receipt_commit --arg path "$dst" --arg mode "$(file_mode "$dst")" '.artifacts[$path].installedHash=.artifacts[$path].targetHash | .artifacts[$path].installedMode=$mode | .artifacts[$path].pending=false | del(.artifacts[$path].targetHash,.artifacts[$path].targetMode,.artifacts[$path].previousHash,.artifacts[$path].previousMode,.artifacts[$path].previousExists)' || return 1
            pending=false
            entry_hash="$before_hash"
            [[ "$before_hash" != "$source_hash" ]] || return 0
        fi
        expected_hash="$entry_hash"; expected_exists=true
        if [[ "$pending" == "true" ]]; then
            expected_hash="$(jq -r --arg path "$dst" '.artifacts[$path] | if has("previousHash") then .previousHash // "" else .before.hash // "" end' "$RECEIPT_PATH")"
            expected_exists="$(jq -r --arg path "$dst" '.artifacts[$path] | if has("previousExists") then .previousExists else .before.exists end' "$RECEIPT_PATH")"
        fi
        if [[ -f "$dst" ]]; then current_exists=true; fi
        if [[ -f "$dst" ]]; then current_mode="$(file_mode "$dst")"; fi
        expected_mode="$(jq -r --arg path "$dst" '.artifacts[$path] | if .pending then (.previousMode // .before.mode // "") else (.installedMode // "") end' "$RECEIPT_PATH")"
        if [[ "$current_exists" != "$expected_exists" || ( -f "$dst" && ( "$before_hash" != "$expected_hash" || ( -n "$expected_mode" && "$current_mode" != "$expected_mode" ) ) ) ]]; then
            echo "    [!] Managed file changed or missing; preserving: $dst" >&2
            return 1
        fi
        [[ "$pending" == true || "$before_hash" != "$source_hash" || "$current_mode" != "$source_mode" ]] || return 0
    elif [[ -f "$dst" && "$collision" == "skip" ]]; then
        echo "    [!] Unowned file collision; preserving: $dst" >&2
        return 1
    elif [[ -f "$dst" && "$before_hash" == "$source_hash" ]]; then
        return 0
    elif jq -e --arg path "$dst" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
        echo "    [!] Receipt kind collision; preserving: $dst" >&2
        return 1
    else
        if [[ -f "$dst" ]]; then
            backup="$dst.dotfiles-backup"
            while [[ -e "$backup" || -L "$backup" ]]; do n=$((n + 1)); backup="$dst.dotfiles-backup.$n"; done
        fi
        receipt_commit --arg path "$dst" --arg hash "$before_hash" --arg mode "$before_mode" --arg backup "$backup" --arg installed "$source_hash" \
            --arg source_mode "$source_mode" '.artifacts[$path] = {before:{exists:($hash != ""),hash:(if $hash=="" then null else $hash end),mode:(if $mode=="" then null else $mode end),backup:(if $backup=="" then null else $backup end)},installedHash:null,pending:true,targetHash:$installed,targetMode:$source_mode,previousHash:(if $hash=="" then null else $hash end),previousMode:(if $mode=="" then null else $mode end),previousExists:($hash != "")}' || return 1
        pending=true
    fi

    if [[ "$pending" != true ]]; then
        receipt_commit --arg path "$dst" --arg installed "$source_hash" --arg previous_hash "$before_hash" --arg previous_mode "$before_mode" --argjson previous_exists "$current_exists" \
            --arg source_mode "$source_mode" '.artifacts[$path].pending=true | .artifacts[$path].targetHash=$installed | .artifacts[$path].targetMode=$source_mode | .artifacts[$path].previousHash=(if $previous_hash=="" then null else $previous_hash end) | .artifacts[$path].previousMode=(if $previous_mode=="" then null else $previous_mode end) | .artifacts[$path].previousExists=$previous_exists' || return 1
    elif [[ "$(jq -r --arg path "$dst" '.artifacts[$path].targetHash // empty' "$RECEIPT_PATH")" != "$source_hash" || "$(jq -r --arg path "$dst" '.artifacts[$path].targetMode // empty' "$RECEIPT_PATH")" != "$source_mode" ]]; then
        receipt_commit --arg path "$dst" --arg installed "$source_hash" --arg previous_hash "$before_hash" --arg previous_mode "$before_mode" --argjson previous_exists "$current_exists" \
            --arg source_mode "$source_mode" '.artifacts[$path].targetHash=$installed | .artifacts[$path].targetMode=$source_mode | .artifacts[$path].previousHash=(if $previous_hash=="" then null else $previous_hash end) | .artifacts[$path].previousMode=(if $previous_mode=="" then null else $previous_mode end) | .artifacts[$path].previousExists=$previous_exists' || return 1
    fi

    before_exists="$(jq -r --arg path "$dst" '.artifacts[$path].before.exists' "$RECEIPT_PATH")"
    installed_hash="$(jq -r --arg path "$dst" '.artifacts[$path].installedHash // empty' "$RECEIPT_PATH")"
    backup="$(jq -r --arg path "$dst" '.artifacts[$path].before.backup // empty' "$RECEIPT_PATH")"
    if [[ "$before_exists" == true && -z "$installed_hash" && -n "$backup" ]]; then
        if [[ -e "$backup" || -L "$backup" ]]; then
            if [[ ! -f "$backup" || -L "$backup" || "$(file_hash "$backup")" != "$(jq -r --arg path "$dst" '.artifacts[$path].before.hash' "$RECEIPT_PATH")" ]]; then
                echo "    [!] Managed backup collision; preserving destination: $dst" >&2
                return 1
            fi
        else
            backup_tmp="$(mktemp "$(dirname "$backup")/.dotfiles-backup.XXXXXX")" || return 1; _TMPFILES+=("$backup_tmp")
            cp -p "$dst" "$backup_tmp" || return 1
            if [[ "$(file_hash "$backup_tmp")" != "$(jq -r --arg path "$dst" '.artifacts[$path].before.hash' "$RECEIPT_PATH")" ]]; then
                rm -f "$backup_tmp"
                echo "    [!] Destination changed before backup; preserving: $dst" >&2
                return 1
            fi
            chmod "$before_mode" "$backup_tmp" || return 1
            mv "$backup_tmp" "$backup" || return 1
        fi
    fi

    mkdir -p "$(dirname "$dst")" || return 1
    tmp="$(mktemp "$(dirname "$dst")/.$(basename "$dst").XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    cp -p "$src" "$tmp" || return 1
    mv "$tmp" "$dst" || return 1
    receipt_commit --arg path "$dst" --arg installed "$source_hash" --arg mode "$(file_mode "$dst")" '.artifacts[$path].installedHash = $installed | .artifacts[$path].installedMode=$mode | .artifacts[$path].pending = false | del(.artifacts[$path].targetHash,.artifacts[$path].targetMode,.artifacts[$path].previousHash,.artifacts[$path].previousMode,.artifacts[$path].previousExists)' || return 1
}

install_managed_symlink() {
    local dst="$1" target="$2" legacy_target="${3:-}" current_target="" installed="" pending=false
    local previous_exists=false previous_type=missing previous_target="" tmp
    $RECEIPT_READY || return 1
    if ! managed_parent_is_safe "$dst"; then
        echo "    [!] Unsupported symlink parent path; preserving: $dst" >&2
        return 1
    fi
    if [[ -L "$dst" ]]; then
        previous_exists=true; previous_type=symlink; current_target="$(readlink "$dst")"; previous_target="$current_target"
    elif [[ -e "$dst" ]]; then
        echo "    [!] Unowned file collision; preserving: $dst" >&2
        return 1
    fi

    if jq -e --arg path "$dst" '.artifacts[$path] | has("installedTarget")' "$RECEIPT_PATH" >/dev/null; then
        installed="$(jq -r --arg path "$dst" '.artifacts[$path].installedTarget' "$RECEIPT_PATH")"
        pending="$(jq -r --arg path "$dst" '.artifacts[$path].pending // false' "$RECEIPT_PATH")"
        if [[ "$pending" == true && -L "$dst" && "$current_target" == "$(jq -r --arg path "$dst" '.artifacts[$path].targetTarget' "$RECEIPT_PATH")" ]]; then
            receipt_commit --arg path "$dst" '.artifacts[$path].installedTarget=.artifacts[$path].targetTarget | .artifacts[$path].pending=false | del(.artifacts[$path].targetTarget,.artifacts[$path].previousExists,.artifacts[$path].previousType,.artifacts[$path].previousTarget)' || return 1
            installed="$current_target"; pending=false
        fi
        if [[ "$pending" == true ]]; then
            previous_exists="$(jq -r --arg path "$dst" '.artifacts[$path].previousExists' "$RECEIPT_PATH")"
            previous_type="$(jq -r --arg path "$dst" '.artifacts[$path].previousType' "$RECEIPT_PATH")"
            previous_target="$(jq -r --arg path "$dst" '.artifacts[$path].previousTarget // empty' "$RECEIPT_PATH")"
            if [[ "$previous_exists" != true && ( -e "$dst" || -L "$dst" ) ]] ||
               [[ "$previous_exists" == true && ( ! -L "$dst" || "$current_target" != "$previous_target" ) ]]; then
                echo "    [!] Pending managed symlink changed; preserving: $dst" >&2
                return 1
            fi
        elif [[ ! -L "$dst" || "$current_target" != "$installed" ]]; then
            echo "    [!] Managed symlink changed or missing; preserving: $dst" >&2
            return 1
        elif [[ "$installed" == "$target" ]]; then
            return 0
        fi
    elif jq -e --arg path "$dst" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
        echo "    [!] Receipt kind collision; preserving: $dst" >&2
        return 1
    else
        if [[ -L "$dst" ]]; then
            if [[ -n "$legacy_target" && ! -e "$dst" && "$current_target" == "$legacy_target" ]]; then
                echo "    Migrating exact legacy dangling link: $dst"
            else
                echo "    [!] Unowned symlink collision; preserving: $dst" >&2
                return 1
            fi
        fi
        receipt_commit --arg path "$dst" --argjson exists "$previous_exists" --arg type "$previous_type" --arg previous "$previous_target" --arg target "$target" '
          .artifacts[$path]={before:{exists:$exists,type:$type,target:(if $type=="symlink" then $previous else null end)},installedTarget:null,pending:true,targetTarget:$target,previousExists:$exists,previousType:$type,previousTarget:(if $type=="symlink" then $previous else null end)}' || return 1
        pending=true
    fi
    if [[ "$pending" != true ]]; then
        receipt_commit --arg path "$dst" --arg target "$target" --argjson exists "$previous_exists" --arg type "$previous_type" --arg previous "$previous_target" '
          .artifacts[$path].pending=true | .artifacts[$path].targetTarget=$target | .artifacts[$path].previousExists=$exists | .artifacts[$path].previousType=$type | .artifacts[$path].previousTarget=(if $type=="symlink" then $previous else null end)' || return 1
    fi
    mkdir -p "$(dirname "$dst")" || return 1
    tmp="$(mktemp "$(dirname "$dst")/.dotfiles-link.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    rm -f "$tmp" || return 1
    ln -s "$target" "$tmp" || return 1
    [[ -L "$tmp" && "$(readlink "$tmp")" == "$target" ]] || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$dst" || return 1
    receipt_commit --arg path "$dst" --arg target "$target" '.artifacts[$path].installedTarget=$target | .artifacts[$path].pending=false | del(.artifacts[$path].targetTarget,.artifacts[$path].previousExists,.artifacts[$path].previousType,.artifacts[$path].previousTarget)' || return 1
}

ensure_managed_symlink() {
    local dst="$1" target="$2" legacy_target="${3:-}"
    if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then
        if [[ -L "$dst" && "$(readlink "$dst")" == "$target" ]]; then return 0; fi
        if [[ -L "$dst" && ! -e "$dst" && -n "$legacy_target" && "$(readlink "$dst")" == "$legacy_target" ]]; then
            ln -sfn "$target" "$dst"
            return
        fi
        if [[ ! -e "$dst" && ! -L "$dst" ]]; then mkdir -p "$(dirname "$dst")"; ln -s "$target" "$dst"; return; fi
        return 1
    fi
    if [[ -L "$dst" && "$(readlink "$dst")" == "$target" ]] && ! jq -e --arg path "$dst" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
        echo "    Exact external symlink preserved: $dst -> $target"
        return 0
    fi
    install_managed_symlink "$dst" "$target" "$legacy_target"
}

download_verified() {
    local url="$1" expected="$2" dst="$3" tmp actual
    mkdir -p "$(dirname "$dst")" || return 1
    tmp="$(mktemp "$(dirname "$dst")/.download.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    curl --retry 3 --retry-delay 2 -fsSL -o "$tmp" "$url" || return 1
    actual="$(file_hash "$tmp")"
    if [[ "$actual" != "$expected" ]]; then
        echo "    [!] SHA-256 mismatch: $url" >&2
        rm -f "$tmp"
        return 1
    fi
    mv "$tmp" "$dst"
}

record_direct_version() {
    local path="$1" version="$2"
    receipt_commit --arg path "$path" --arg version "$version" '.artifacts[$path].directVersion=$version'
}

direct_anchor_state() {
    local path="$1" version="$2" installed current
    DIRECT_STATE=new; DIRECT_INSTALLED_VERSION=""
    jq -e --arg path "$path" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null || return 0
    if jq -e --arg path "$path" '.artifacts[$path].pending == true' "$RECEIPT_PATH" >/dev/null; then
        DIRECT_STATE=recover
        return 0
    fi
    installed="$(jq -r --arg path "$path" '.artifacts[$path].directVersion // empty' "$RECEIPT_PATH")"
    DIRECT_INSTALLED_VERSION="$installed"
    [[ -n "$installed" ]] || { DIRECT_STATE=recover; return 0; }
    if jq -e --arg path "$path" '.artifacts[$path] | has("installedTarget")' "$RECEIPT_PATH" >/dev/null; then
        current="$(readlink "$path" 2>/dev/null || true)"
        [[ -L "$path" && "$current" == "$(jq -r --arg path "$path" '.artifacts[$path].installedTarget' "$RECEIPT_PATH")" ]] || DIRECT_STATE=modified
    else
        [[ -f "$path" && "$(file_hash "$path")" == "$(jq -r --arg path "$path" '.artifacts[$path].installedHash // empty' "$RECEIPT_PATH")" ]] || DIRECT_STATE=modified
    fi
    [[ "$DIRECT_STATE" == modified ]] && return 0
    if [[ "$installed" != "$version" ]]; then
        if [[ "${DOTFILES_UPGRADE_DIRECT:-0}" != 1 ]]; then DIRECT_STATE=upgrade-blocked; else DIRECT_STATE=upgrade; fi
        return 0
    fi
    [[ "$DIRECT_STATE" == new ]] && DIRECT_STATE=current
}

receipt_owns_prefix() {
    local prefix="${1%/}/"
    jq -e --arg prefix "$prefix" '.artifacts | keys | any(startswith($prefix))' "$RECEIPT_PATH" >/dev/null
}

install_managed_tree() {
    local src="$1" dst="$2" collision="${3:-takeover}" skip_root="${4:-false}" file relative status=0
    $RECEIPT_READY && [[ -d "$src" ]] || return 1
    if [[ -e "$dst" || -L "$dst" ]] && { [[ ! -d "$dst" ]] || [[ -L "$dst" ]]; }; then
        echo "    [!] Unsupported destination tree root; preserving: $dst" >&2
        return 1
    fi
    if [[ "$skip_root" == "true" && -d "$dst" ]] && ! receipt_owns_prefix "$dst"; then
        echo "    [!] Unowned directory collision; preserving: $dst" >&2
        return 1
    fi
    while IFS= read -r -d '' file; do
        relative="${file#"$src"/}"
        install_managed_file "$file" "$dst/$relative" "$collision" || status=1
    done < <(find "$src" -type f -print0)
    return "$status"
}

tree_hash() {
    local root="$1"
    {
        printf 'root\0%s\0' "$(file_mode "$root")"
        find "$root" -mindepth 1 -printf '%P\t%y\t%m\t%l\t%s\0' | LC_ALL=C sort -z
        printf 'content\0'
        tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -cf - -C "$root" . 2>/dev/null
    } | {
        if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
        else shasum -a 256 | awk '{print $1}'
        fi
    }
}

install_managed_direct_tree() {
    local src="$1" dst="$2" version="$3" source_hash current_hash="" pending target_hash previous_exists tmp
    $RECEIPT_READY && [[ -d "$src" ]] || return 1
    managed_parent_is_safe "$dst" || { echo "    [!] Unsafe direct tree parent; preserving: $dst" >&2; return 1; }
    source_hash="$(tree_hash "$src")" || return 1
    if jq -e --arg path "$dst" '.artifacts[$path] | has("installedTreeHash")' "$RECEIPT_PATH" >/dev/null; then
        [[ -d "$dst" && ! -L "$dst" ]] && current_hash="$(tree_hash "$dst")"
        pending="$(jq -r --arg path "$dst" '.artifacts[$path].pending // false' "$RECEIPT_PATH")"
        target_hash="$(jq -r --arg path "$dst" '.artifacts[$path].targetTreeHash // empty' "$RECEIPT_PATH")"
        if [[ "$pending" == true && ( -z "$target_hash" || "$source_hash" != "$target_hash" ) ]]; then
            echo "    [!] Pending direct tree target changed; preserving: $dst" >&2
            return 1
        fi
        if [[ "$pending" == true && -n "$current_hash" && "$current_hash" == "$target_hash" ]]; then
            receipt_commit --arg path "$dst" '.artifacts[$path].installedTreeHash=.artifacts[$path].targetTreeHash | .artifacts[$path].pending=false | del(.artifacts[$path].targetTreeHash,.artifacts[$path].previousExists)' || return 1
            record_direct_version "$dst" "$version"
            return
        fi
        if [[ "$pending" == true ]]; then
            previous_exists="$(jq -r --arg path "$dst" '.artifacts[$path].previousExists // .artifacts[$path].before.exists' "$RECEIPT_PATH")"
            if [[ "$previous_exists" != false || -e "$dst" || -L "$dst" ]]; then
                echo "    [!] Pending direct tree is not a recoverable fresh versioned target; preserving: $dst" >&2
                return 1
            fi
        elif [[ "$current_hash" != "$(jq -r --arg path "$dst" '.artifacts[$path].installedTreeHash' "$RECEIPT_PATH")" ]]; then
            echo "    [!] Managed direct tree changed; preserving: $dst" >&2
            return 1
        fi
        if [[ "$pending" != true ]]; then
            if [[ "$current_hash" == "$source_hash" ]]; then record_direct_version "$dst" "$version"; return; fi
            echo "    [!] Versioned direct tree content differs; preserving: $dst" >&2
            return 1
        fi
    elif jq -e --arg path "$dst" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
        echo "    [!] Receipt kind collision; preserving: $dst" >&2
        return 1
    elif [[ -e "$dst" || -L "$dst" ]]; then
        echo "    [!] Unowned direct tree collision; preserving: $dst" >&2
        return 1
    else
        receipt_commit --arg path "$dst" --arg hash "$source_hash" '.artifacts[$path]={before:{exists:false,type:"missing"},installedTreeHash:null,pending:true,targetTreeHash:$hash,previousExists:false}' || return 1
        pending=true
    fi
    [[ "$pending" == true ]] || return 1
    mkdir -p "$(dirname "$dst")" || return 1
    tmp="$(mktemp -d "$(dirname "$dst")/.dotfiles-tree.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    cp -a "$src/." "$tmp/" || return 1
    chmod --reference="$src" "$tmp" || return 1
    [[ "$(tree_hash "$tmp")" == "$source_hash" ]] || return 1
    mv -T "$tmp" "$dst" || return 1
    receipt_commit --arg path "$dst" --arg hash "$source_hash" --arg version "$version" '.artifacts[$path].installedTreeHash=$hash | .artifacts[$path].directVersion=$version | .artifacts[$path].pending=false | del(.artifacts[$path].targetTreeHash,.artifacts[$path].previousExists)' || return 1
}

record_managed_package() {
    local name="$1" before_present="$2" before_value="$3" installed="$4" prefix="${5:-}"
    $RECEIPT_READY || return 0
    [[ "$before_present" != "true" || "$before_value" != "$installed" ]] || return 0
    [[ "$before_present" == "true" || -n "$installed" ]] || return 0
    receipt_commit --arg name "$name" --argjson present "$before_present" --arg before "$before_value" --arg installed "$installed" --arg prefix "$prefix" '
        (if .packages[$name] then .packages[$name].installed=$installed | del(.packages[$name].pending)
        else .packages[$name]={before:{present:$present,value:(if $present then $before else null end)},installed:$installed} end) |
        (if $prefix != "" then .packages[$name].prefix=$prefix else . end) | del(.bootstrap)'
}

begin_managed_package() {
    local name="$1" present="$2" before="$3" prefix="${4:-}" current_previous current_present original_present original_before
    $RECEIPT_READY || return 1
    if [[ -n "$prefix" ]] && jq -e --arg name "$name" '.packages|has($name)' "$RECEIPT_PATH" >/dev/null; then
        current_prefix="$(jq -r --arg name "$name" '.packages[$name].prefix // empty' "$RECEIPT_PATH")"
        if [[ -z "$current_prefix" || "$current_prefix" != "$prefix" ]]; then
            # 이전 버전은 링크를 풀지 않은 fnm multishell 경로를 기록했다. 그 값은 셸마다 달라져
            # 소유권 판단에 쓸 수 없으므로, 새 prefix가 안정 경로일 때만 잔재를 교정하고 진행한다.
            if ! is_ephemeral_npm_prefix "$current_prefix" || is_ephemeral_npm_prefix "$prefix"; then
                echo "    [!] npm prefix changed or missing in receipt; preserving package ownership: $name" >&2
                return 1
            fi
            echo "    [!] Repairing ephemeral npm prefix recorded in receipt: $name" >&2
        fi
    fi
    if jq -e --arg name "$name" '.packages[$name].pending != null' "$RECEIPT_PATH" >/dev/null; then
        current_previous="$(jq -r --arg name "$name" '.packages[$name].pending.previousValue // empty' "$RECEIPT_PATH")"
        current_present="$(jq -r --arg name "$name" '.packages[$name].pending.previousPresent' "$RECEIPT_PATH")"
        if [[ "$present" != "$current_present" || ( "$present" == true && "$before" != "$current_previous" ) ]]; then
            original_present="$(jq -r --arg name "$name" '.packages[$name].before.present' "$RECEIPT_PATH")"
            original_before="$(jq -r --arg name "$name" '.packages[$name].before.value // empty' "$RECEIPT_PATH")"
            record_managed_package "$name" "$original_present" "$original_before" "$before" || return 1
        fi
    fi
    receipt_commit --arg name "$name" --argjson present "$present" --arg before "$before" --arg prefix "$prefix" '
        (.packages|has($name)|not) as $new |
        if $new then .packages[$name]={before:{present:$present,value:(if $present then $before else null end)},installed:null} else . end |
        .packages[$name].pending={previousPresent:$present,previousValue:(if $present then $before else null end),newEntry:$new} |
        (if $prefix != "" then .packages[$name].prefix=$prefix else . end)'
}

cancel_managed_package() {
    local name="$1"
    $RECEIPT_READY || return 0
    receipt_commit --arg name "$name" '
        (if .packages[$name].pending.newEntry and .packages[$name].installed == null then del(.packages[$name])
        else del(.packages[$name].pending) end) | del(.bootstrap)'
}

query_claude_npm_package() {
    local npm_root package_json prefix="${CLAUDE_NPM_PREFIX:-}"
    CLAUDE_QUERY_STATE=error; CLAUDE_QUERY_VERSION=""
    [[ -n "$prefix" ]] || prefix="$(npm prefix -g 2>/dev/null)" || return 1
    npm_root="$(npm root -g --prefix "$prefix" 2>/dev/null)" || return 1
    [[ -n "$npm_root" ]] || return 1
    package_json="$npm_root/@anthropic-ai/claude-code/package.json"
    if [[ ! -e "$package_json" && ! -L "$package_json" ]]; then CLAUDE_QUERY_STATE=absent; return 0; fi
    [[ -f "$package_json" ]] || return 1
    CLAUDE_QUERY_VERSION="$(jq -er '.version | strings | select(length > 0)' "$package_json" 2>/dev/null)" || return 1
    CLAUDE_QUERY_STATE=present
}

query_claude_cask() {
    local output installed
    CLAUDE_QUERY_STATE=error; CLAUDE_QUERY_VERSION=""
    if output="$(brew list --cask --versions claude-code 2>&1)"; then
        CLAUDE_QUERY_VERSION="$(awk '$1 == "claude-code" && NF >= 2 { print $2; exit }' <<< "$output")"
        [[ -n "$CLAUDE_QUERY_VERSION" ]] || return 1
        CLAUDE_QUERY_STATE=present
        return 0
    fi
    installed="$(brew list --cask 2>/dev/null)" || return 1
    grep -Fxq claude-code <<< "$installed" && return 1
    CLAUDE_QUERY_STATE=absent
}

reconcile_pending_claude_package() {
    local name="$1" query="$2" command_present="$3" previous_present previous_value before_present before_value
    "$query" || return 1
    previous_present="$(jq -r --arg name "$name" '.packages[$name].pending.previousPresent' "$RECEIPT_PATH")"
    previous_value="$(jq -r --arg name "$name" '.packages[$name].pending.previousValue // empty' "$RECEIPT_PATH")"
    if [[ "$CLAUDE_QUERY_STATE" == present ]]; then
        if [[ "$previous_present" == true && "$CLAUDE_QUERY_VERSION" == "$previous_value" ]]; then
            cancel_managed_package "$name"
        else
            before_present="$(jq -r --arg name "$name" '.packages[$name].before.present' "$RECEIPT_PATH")"
            before_value="$(jq -r --arg name "$name" '.packages[$name].before.value // empty' "$RECEIPT_PATH")"
            record_managed_package "$name" "$before_present" "$before_value" "$CLAUDE_QUERY_VERSION"
        fi
    elif [[ "$CLAUDE_QUERY_STATE" == absent && "$previous_present" == false && "$command_present" == false ]]; then
        cancel_managed_package "$name"
    else
        return 1
    fi
}

complete_managed_claude_package() {
    local name="$1" query="$2" before_present="$3" before_value="$4" manager_status="$5" command_present="$6" prefix="${7:-}"
    if "$query"; then
        if [[ "$CLAUDE_QUERY_STATE" == present ]]; then
            if [[ "$before_present" != true || "$CLAUDE_QUERY_VERSION" != "$before_value" ]]; then
                record_managed_package "$name" "$before_present" "$before_value" "$CLAUDE_QUERY_VERSION" "$prefix" || return 1
            else
                cancel_managed_package "$name" || return 1
            fi
            (( manager_status == 0 )) && return 0
            return "$manager_status"
        fi
        if [[ "$CLAUDE_QUERY_STATE" == absent && "$before_present" == false && "$command_present" == false ]]; then
            cancel_managed_package "$name" || return 1
        fi
    fi
    (( manager_status != 0 )) && return "$manager_status"
    return 1
}

managed_value_is_sensitive() {
    [[ "$1" != 'git:credential.credentialStore' && "$1" =~ [Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Cc][Rr][Ee][Dd][Ee][Nn][Tt][Ii][Aa][Ll] ]]
}

record_managed_value() {
    local name="$1" before_present="$2" before_value="$3" installed="$4" store_before="${5:-true}"
    $RECEIPT_READY || return 0
    ! managed_value_is_sensitive "$name" || return 0
    receipt_commit --arg name "$name" --argjson present "$before_present" --arg before "$before_value" --arg installed "$installed" --argjson store "$store_before" '
        if .values[$name] then .values[$name].installed=$installed | del(.values[$name].pending)
        else .values[$name]={before:({present:$present} + if $store then {value:(if $present then $before else null end)} else {} end),installed:$installed} end'
}

begin_managed_value() {
    local name="$1" present="$2" before="$3" target="$4" store="${5:-true}"
    $RECEIPT_READY || return 1
    ! managed_value_is_sensitive "$name" || return 1
    receipt_commit --arg name "$name" --argjson present "$present" --arg before "$before" --arg target "$target" --argjson store "$store" '
        if (.values|has($name)|not) then .values[$name]={before:({present:$present} + if $store then {value:(if $present then $before else null end)} else {} end),installed:null} else . end |
        .values[$name].pending=({previousPresent:$present,target:$target} + if $store then {previousValue:(if $present then $before else null end)} else {} end)'
}

set_managed_git_value() {
    local name="$1" value="$2" before="" present=false entry="" pending_target="" pending_previous="" pending_present=false
    $RECEIPT_READY || return 0
    if before="$(git config --global --get "$name" 2>/dev/null)"; then present=true; fi
    entry="$(jq -r --arg name "git:$name" '.values[$name].installed // empty' "$RECEIPT_PATH")"
    if jq -e --arg name "git:$name" '.values[$name].pending != null' "$RECEIPT_PATH" >/dev/null; then
        pending_target="$(jq -r --arg name "git:$name" '.values[$name].pending.target' "$RECEIPT_PATH")"
        pending_previous="$(jq -r --arg name "git:$name" '.values[$name].pending.previousValue // empty' "$RECEIPT_PATH")"
        pending_present="$(jq -r --arg name "git:$name" '.values[$name].pending.previousPresent' "$RECEIPT_PATH")"
        if [[ "$present" == true && "$before" == "$pending_target" ]]; then
            record_managed_value "git:$name" "$present" "$before" "$pending_target"
            return 0
        fi
        if [[ "$present" != "$pending_present" || ( "$present" == true && "$before" != "$pending_previous" ) ]]; then
            echo "    [!] Managed value changed; preserving: $name" >&2
            return 0
        fi
    elif jq -e --arg name "git:$name" '.values | has($name)' "$RECEIPT_PATH" >/dev/null && [[ "$before" != "$entry" ]]; then
        echo "    [!] Managed value changed; preserving: $name" >&2
        return 0
    fi
    if [[ "$present" != "true" || "$before" != "$value" ]]; then
        begin_managed_value "git:$name" "$present" "$before" "$value" || return 1
        git config --global "$name" "$value" || return 1
        record_managed_value "git:$name" "$present" "$before" "$value" || return 1
    fi
}

set_profile_block() {
    local file="$1" content="$2"
    local begin="# ===== dotfiles-begin ====="
    local end="# ===== dotfiles-end ====="
    local block_file tmp begin_exact end_exact begin_any end_any begin_line end_line
    block_file="$(mktemp)"; _TMPFILES+=("$block_file")
    printf '%s\n%s\n%s\n' "$begin" "$content" "$end" > "$block_file"

    mkdir -p "$(dirname "$file")"
    [[ -f "$file" ]] || : > "$file"

    begin_exact="$(grep -Fxc -- "$begin" "$file" || true)"
    end_exact="$(grep -Fxc -- "$end" "$file" || true)"
    begin_any="$(grep -Fc -- "$begin" "$file" || true)"
    end_any="$(grep -Fc -- "$end" "$file" || true)"

    if [[ "$begin_any" == "0" && "$end_any" == "0" ]]; then
        printf '\n' >> "$file"
        cat "$block_file" >> "$file"
        echo "    Appended dotfiles block to $file"
    elif [[ "$begin_exact" == "1" && "$end_exact" == "1" &&
            "$begin_any" == "1" && "$end_any" == "1" ]]; then
        begin_line="$(grep -nFx -- "$begin" "$file" | cut -d: -f1)"
        end_line="$(grep -nFx -- "$end" "$file" | cut -d: -f1)"
        if (( begin_line >= end_line )); then
            echo "    [!] Invalid dotfiles marker order in $file; keeping the file unchanged." >&2
            return 1
        fi

        tmp="$(mktemp)"; _TMPFILES+=("$tmp")
        if ! awk -v begin="$begin" -v end="$end" -v block_file="$block_file" '
            BEGIN { skip = 0; found_begin = 0; found_end = 0 }
            $0 == begin {
                while ((getline line < block_file) > 0) print line
                close(block_file)
                found_begin++
                skip = 1
                next
            }
            skip && $0 == end { found_end++; skip = 0; next }
            !skip { print }
            END { if (skip || found_begin != 1 || found_end != 1) exit 1 }
        ' "$file" > "$tmp"; then
            echo "    [!] Failed to replace dotfiles marker block in $file; keeping the file unchanged." >&2
            return 1
        fi
        mv "$tmp" "$file"
        echo "    Updated dotfiles block in $file"
    else
        echo "    [!] Invalid dotfiles marker state in $file; keeping the file unchanged." >&2
        return 1
    fi
}

install_shell_profiles() {
    local profile src
    echo "==> Updating shell profiles..."
    for profile in bashrc inputrc; do
        src="$ROOT/config/bash/$profile"
        if [[ -f "$src" ]]; then
            set_profile_block "$HOME/.$profile" "$(cat "$src")"
        elif [[ "$profile" == "bashrc" ]]; then
            echo "    [!] config/bash/bashrc not found, skipping bashrc."
        fi
    done

    if [[ "$OS" == "Darwin" ]]; then
        set_profile_block "$HOME/.zprofile" 'if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi'
        set_profile_block "$HOME/.zshrc" 'typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.bun/bin" "$HOME/.local/share/fnm" $path)

if command -v fnm >/dev/null 2>&1; then
    eval "$(fnm env --use-on-cd --shell zsh)"
fi
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi'
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
                    if set_managed_git_value "$section.$key" "$value" &&
                       [[ "$(git config --global --get "$section.$key" 2>/dev/null || true)" == "$value" ]]; then
                        echo "    Added [$section] $key = $value"
                    fi
                else
                    echo "    Skip  [$section] $key (already set)"
                fi
            fi
        fi
    done < "$path"
    echo "    gitconfig merged."
}

merge_codex_config() {
    local src="$1" dst="$2" tmp

    if [[ ! -f "$src" ]]; then
        echo "    [!] $src not found, skipping."
        return 0
    fi
    if ! command -v yq >/dev/null 2>&1; then
        echo "    [!] yq not found, keeping existing config.toml"
        return 0
    fi
    if ! yq -p=toml -o=json '.' "$src" >/dev/null 2>&1; then
        echo "    [!] source config.toml is invalid, keeping existing config.toml"
        return 0
    fi
    if [[ ! -f "$dst" ]]; then
        if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then cp -f "$src" "$dst" || return 1
        else install_managed_file "$src" "$dst" takeover || return 0
        fi
        echo "    Copied config.toml"
        return 0
    fi
    if ! yq -p=toml -o=json '.' "$dst" >/dev/null 2>&1; then
        echo "    [!] existing config.toml is invalid, keeping it unchanged"
        return 0
    fi

    tmp="$(mktemp)"; _TMPFILES+=("$tmp")
    if yq eval-all -p=toml -o=toml \
        'select(fileIndex == 0) * select(fileIndex == 1)' \
        "$src" "$dst" > "$tmp" 2>/dev/null \
        && [[ -s "$tmp" ]] \
        && yq -p=toml -o=json '.' "$tmp" >/dev/null 2>&1; then
        if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then
            mv "$tmp" "$dst"
            echo "    Merged config.toml (existing values preserved)"
        elif install_managed_file "$tmp" "$dst" takeover; then
            echo "    Merged config.toml (existing values preserved)"
        fi
    else
        echo "    [!] merged config.toml is invalid, keeping existing config.toml"
    fi
}

merge_json_registry() {
    local src="$1" dst="$2" tmp
    if [[ ! -f "$src" ]]; then
        echo "    [!] $src not found, skipping."
        return 0
    fi
    if [[ ! -f "$dst" ]]; then
        if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then cp -f "$src" "$dst" || return 1
        else install_managed_file "$src" "$dst" takeover || return 0
        fi
        echo "    Copied $(basename "$dst")"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "    [!] jq not found, keeping existing $(basename "$dst")"
        return 0
    fi
    local filter="$ROOT/scripts/merge-json-registry.jq"
    if [[ ! -f "$filter" ]]; then
        echo "    [!] merge-json-registry.jq not found, keeping existing $(basename "$dst")"
        return 0
    fi

    tmp="$(mktemp)"; _TMPFILES+=("$tmp")
    if jq -s -f "$filter" "$dst" "$src" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then
            mv "$tmp" "$dst"
            echo "    Merged $(basename "$dst")"
        elif install_managed_file "$tmp" "$dst" takeover; then
            echo "    Merged $(basename "$dst")"
        fi
    else
        echo "    [!] jq merge failed, keeping existing $(basename "$dst")"
    fi
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

prune_node_versions() {
    local current old
    [[ "${DOTFILES_PRUNE_NODE_VERSIONS:-0}" == "1" ]] || return 0
    current="$(fnm current 2>/dev/null || true)"
    if [[ ! "$current" =~ ^v[0-9] ]]; then
        echo "    [!] fnm current를 읽지 못해 구버전 정리를 건너뜀."
        return
    fi
    while read -r old; do
        [[ -n "$old" && "$old" != "$current" ]] || continue
        if fnm uninstall "$old" >/dev/null 2>&1; then
            echo "    Removed old Node: $old"
        else
            echo "    [!] Node $old 삭제 실패 — 해당 버전을 쓰는 셸이 열려 있는지 확인."
        fi
    done < <(fnm ls 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
}

link_fnm_default_bins() {
    local default_path="${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default"
    local bin target link legacy_target
    for bin in node npm npx; do
        target="$default_path/bin/$bin"
        link="$LOCAL_BIN/$bin"
        legacy_target="$default_path/$bin"
        if [[ ! -x "$target" ]]; then
            echo "    [!] fnm default $bin is not executable: $target"
            continue
        fi
        if ensure_managed_symlink "$link" "$target" "$legacy_target"; then
            echo "    Linked $link -> fnm default"
        fi
    done
}

update_fnm_statusline() {
    local node_ver="$1" fnm_root="${FNM_DIR:-$HOME/.local/share/fnm}"
    local target settings command rest old="" tmp
    target="$fnm_root/node-versions/$node_ver/installation/bin/node"
    settings="$CLAUDE_DIR/settings.json"
    [[ -x "$target" && -f "$settings" ]] || return 0
    command="$(jq -r '.statusLine.command // ""' "$settings" 2>/dev/null || true)"
    [[ "$command" == *"$fnm_root/node-versions/"* ]] || return 0
    rest="${command#*"$fnm_root/node-versions/"}"
    rest="${rest%%/*}"
    for candidate in "$fnm_root/node-versions/$rest/installation/node" \
                     "$fnm_root/node-versions/$rest/installation/bin/node"; do
        [[ "$command" == *"$candidate"* ]] && old="$candidate" && break
    done
    [[ -n "$old" && "$old" != "$target" ]] || return 0

    tmp="$(mktemp "$CLAUDE_DIR/.settings.json.XXXXXX")"; _TMPFILES+=("$tmp")
    if jq --arg old "$old" --arg new "$target" \
        '.statusLine.command |= (split($old) | join($new))' "$settings" > "$tmp" &&
       jq empty "$tmp"; then
        if [[ "$FUNCTIONS_ONLY_MODE" == 1 && "$RECEIPT_READY" == false ]]; then
            mv "$tmp" "$settings"
            echo "    Patched statusLine node path: $old -> $target"
        elif install_managed_file "$tmp" "$settings" takeover; then
            echo "    Patched statusLine node path: $old -> $target"
        fi
    fi
}

install_node_lts() {
    echo
    echo "==> Installing Node.js LTS via fnm..."
    if ! command -v fnm >/dev/null 2>&1 && [[ ! -x "$HOME/.local/share/fnm/fnm" ]]; then
        echo "    [!] fnm not found. Restart terminal and run:"
        echo "        fnm install --lts"
        return 1
    fi

    local fnm_env
    if ! fnm_env="$(fnm env --shell bash)"; then
        echo "    [!] fnm env failed"
        return 1
    fi
    eval "$fnm_env"
    if ! fnm install --lts; then
        echo "    [!] fnm install --lts failed (network issue?). Run manually: fnm install --lts"
        return 1
    fi
    if ! fnm default lts-latest; then echo "    [!] fnm default lts-latest failed"; return 1; fi
    if ! fnm use lts-latest; then echo "    [!] fnm use lts-latest failed"; return 1; fi

    local node_ver
    node_ver="$(node --version 2>/dev/null || true)"
    echo "    Node ${node_ver:-not active yet} active."
    prune_node_versions
    link_fnm_default_bins
    if [[ "$node_ver" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        update_fnm_statusline "$node_ver"
    fi
    return 0
}

install_direct_file() {
    local name="$1" version="$2" src="$3" dst="$4"
    chmod 755 "$src" || return 1
    if install_managed_file "$src" "$dst" skip; then
        record_direct_version "$dst" "$version" || return 1
        echo "    $name $version -> $dst"
        return 0
    fi
    return 1
}

validate_direct_manifest() {
    local manifest="$1"
    awk -F '\t' '
      /^#/ || /^[[:space:]]*$/ { next }
      NF != 6 || $1 !~ /^(starship|atuin|fnm|bun|yazi|lazygit|fzf|nvim|delta|eza|yq)$/ || $2 !~ /^[0-9]+\.[0-9]+\.[0-9]+$/ || $3 !~ /^(amd64|arm64)$/ || $4 !~ /^(tgz|zip|bin)$/ || $5 !~ /^https:\/\/github\.com\/[^[:space:]]+\/releases\/download\/[^[:space:]]+$/ || $5 ~ /\/(latest|HEAD|main)\// || $6 !~ /^[0-9a-f]{64}$/ { bad=1; exit }
      seen[$1 SUBSEP $3]++ { bad=1 }
      { count[$1]++ }
      END {
        split("starship atuin fnm bun yazi lazygit fzf nvim delta eza yq", names, " ")
        for (i in names) if (count[names[i]] != 2) bad=1
        exit bad
      }
    ' "$manifest"
}

install_direct_artifacts() {
    local manifest="$ROOT/manifests/direct-artifacts.tsv" name version arch format url checksum
    local work archive extract member anchor state tree target current failed=0
    [[ "$ARCH" == amd64 || "$ARCH" == arm64 ]] || { echo "    [!] Unsupported direct artifact architecture: $ARCH" >&2; return 1; }
    [[ -f "$manifest" ]] || { echo "    [!] $manifest not found" >&2; return 1; }
    validate_direct_manifest "$manifest" || { echo "    [!] Invalid direct artifact manifest: $manifest" >&2; return 1; }
    while IFS=$'\t' read -r name version arch format url checksum; do
        [[ -n "$name" && "$name" != \#* && "$arch" == "$ARCH" ]] || continue
        case "$name" in
            fnm) anchor="$HOME/.local/share/fnm/fnm" ;;
            bun) anchor="$HOME/.bun/bin/bun" ;;
            *) anchor="$LOCAL_BIN/$name" ;;
        esac
        if [[ "$name" == nvim && ( -e "$anchor" || -L "$anchor" ) ]] && ! jq -e --arg path "$anchor" '.artifacts | has($path)' "$RECEIPT_PATH" >/dev/null; then
            echo "    [!] Unowned nvim launcher collision; preserving: $anchor" >&2
            failed=1
            continue
        fi
        direct_anchor_state "$anchor" "$version"; state="$DIRECT_STATE"
        case "$state" in
            current)
                case "$name" in
                    fnm) ensure_managed_symlink "$LOCAL_BIN/fnm" "$anchor" || failed=1; continue ;;
                    bun)
                        ensure_managed_symlink "$LOCAL_BIN/bun" "$anchor" || failed=1
                        ensure_managed_symlink "$HOME/.bun/bin/bunx" bun || failed=1
                        continue ;;
                    yazi)
                        direct_anchor_state "$LOCAL_BIN/ya" "$version"
                        case "$DIRECT_STATE" in
                            current) echo "    yazi $version already installed: $anchor"; continue ;;
                            modified) echo "    [!] Managed ya artifact changed; preserving: $LOCAL_BIN/ya" >&2; failed=1; continue ;;
                            upgrade-blocked) echo "    [!] ya version change requires DOTFILES_UPGRADE_DIRECT=1" >&2; failed=1; continue ;;
                        esac ;;
                    nvim)
                        target="$HOME/.local/opt/nvim-v$version"
                        if [[ -d "$target" && ! -L "$target" ]] &&
                           [[ "$(tree_hash "$target")" == "$(jq -r --arg path "$target" '.artifacts[$path].installedTreeHash // empty' "$RECEIPT_PATH")" ]]; then
                            echo "    nvim $version already installed: $target"
                            continue
                        fi
                        echo "    [!] Managed nvim tree changed or missing; preserving: $target" >&2
                        failed=1; continue ;;
                    *) echo "    $name $version already installed: $anchor"; continue ;;
                esac ;;
            modified) echo "    [!] Managed direct artifact changed; preserving: $anchor" >&2; failed=1; continue ;;
            upgrade-blocked)
                if [[ "$name" == fnm ]] && ! ensure_managed_symlink "$LOCAL_BIN/fnm" "$anchor"; then failed=1; fi
                echo "    [!] $name $DIRECT_INSTALLED_VERSION -> $version requires DOTFILES_UPGRADE_DIRECT=1" >&2
                failed=1; continue ;;
            upgrade) echo "    Upgrading $name: $DIRECT_INSTALLED_VERSION -> $version" ;;
            new)
                if command -v "$name" >/dev/null 2>&1; then
                    if [[ "$name" == nvim ]]; then
                        current="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
                        [[ -n "$current" ]] && dpkg --compare-versions "$current" ge 0.10.0 && { echo "    nvim already provided outside the direct-artifact receipt: $(command -v nvim)"; continue; }
                    elif [[ "$name" == fzf ]]; then
                        current="$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1 || true)"
                        [[ -n "$current" ]] && dpkg --compare-versions "$current" ge 0.48.0 && { echo "    fzf already provided outside the direct-artifact receipt: $(command -v fzf)"; continue; }
                    else
                        echo "    $name already provided outside the direct-artifact receipt: $(command -v "$name")"
                        continue
                    fi
                fi ;;
        esac

        work="$(mktemp -d)"; _TMPFILES+=("$work")
        archive="$work/artifact"
        if ! download_verified "$url" "$checksum" "$archive"; then failed=1; continue; fi
        extract="$work/extract"; mkdir -p "$extract"
        case "$format" in
            tgz) tar -xzf "$archive" -C "$extract" || { failed=1; continue; } ;;
            zip) unzip -q "$archive" -d "$extract" || { failed=1; continue; } ;;
            bin) cp "$archive" "$extract/$name" || { failed=1; continue; } ;;
            *) echo "    [!] Unsupported direct artifact format: $format" >&2; failed=1; continue ;;
        esac

        if [[ "$name" == nvim ]]; then
            tree="$(find "$extract" -mindepth 1 -maxdepth 1 -type d -name 'nvim-linux-*' -print -quit)"
            target="$HOME/.local/opt/nvim-v$version"
            if [[ -z "$tree" ]] || ! install_managed_direct_tree "$tree" "$target" "$version"; then failed=1; continue; fi
            if install_managed_symlink "$anchor" "$target/bin/nvim"; then
                record_direct_version "$anchor" "$version" || { failed=1; continue; }
                echo "    nvim $version -> $target"
            else failed=1
            fi
            continue
        fi

        member="$(find "$extract" -type f -name "$name" -print -quit)"
        if [[ -z "$member" ]] || ! install_direct_file "$name" "$version" "$member" "$anchor"; then failed=1; continue; fi
        case "$name" in
            yazi)
                member="$(find "$extract" -type f -name ya -print -quit)"
                [[ -n "$member" ]] && install_direct_file ya "$version" "$member" "$LOCAL_BIN/ya" || failed=1
                ;;
            fnm)
                ensure_managed_symlink "$LOCAL_BIN/fnm" "$anchor" || failed=1
                ;;
            bun)
                ensure_managed_symlink "$LOCAL_BIN/bun" "$anchor" || failed=1
                ensure_managed_symlink "$HOME/.bun/bin/bunx" bun || failed=1
                ;;
        esac
    done < "$manifest"
    hash -r 2>/dev/null || true
    return "$failed"
}

if [[ "${DOTFILES_FUNCTIONS_ONLY:-0}" == "1" ]]; then
    return 0 2>/dev/null || exit 0
fi

receipt_preflight || exit 1

echo "==> Unix dotfiles setup starting..."
echo "    Source: $ROOT"
echo "    OS:     ${OS:-unknown}"
echo "    Arch:   $ARCH"

if [[ "$OS" == "Darwin" ]]; then
    install_system_packages() {
    # =============================================
    # [macOS] Homebrew 및 Brewfile
    # =============================================
    echo
    if ! command -v brew >/dev/null 2>&1; then
      echo "    [!] Homebrew is required. Install it first from https://brew.sh/" >&2
      exit 1
    fi

    BREWFILE="$ROOT/manifests/Brewfile"
    BREW_BEFORE="$(mktemp)"; _TMPFILES+=("$BREW_BEFORE")
    if [[ -f "$BREWFILE" ]]; then
        awk -F'"' '/^(brew|cask) "/ {kind=$1; sub(/ .*/, "", kind); print kind "\t" $2}' "$BREWFILE" | while IFS=$'\t' read -r kind package; do
            before="$(brew list --"${kind/brew/formula}" --versions "$package" 2>/dev/null | awk '{print $2}' || true)"
            before_present=false; if [[ -n "$before" ]]; then before_present=true; fi
            printf '%s\t%s\t%s\t%s\n' "$kind" "$package" "$before_present" "$before"
        done > "$BREW_BEFORE"
    else
        record_install_failure "Required manifest missing: manifests/Brewfile"
        finish_install
        exit 1
    fi
    if ! $RECEIPT_READY; then
        jq_before="$(awk -F'\t' '$1=="brew" && $2=="jq" {print $3 "\t" $4}' "$BREW_BEFORE")"
        IFS=$'\t' read -r jq_before_present jq_before_version <<< "$jq_before"
        receipt_bootstrap_jq brew "${jq_before_present:-false}" || exit 1
        jq_status=0
        brew install jq || jq_status=$?
        jq_after="$(brew list --formula --versions jq 2>/dev/null | awk '{print $2}' || true)"
        if command -v jq >/dev/null 2>&1; then
            receipt_init || exit 1
            if [[ -n "$jq_after" && "$jq_after" != "${jq_before_version:-}" ]]; then
                record_managed_package brew:jq "${jq_before_present:-false}" "${jq_before_version:-}" "$jq_after"
            else
                cancel_managed_package brew:jq
            fi
        fi
        (( jq_status == 0 )) || exit "$jq_status"
        $RECEIPT_READY || exit 1
    fi
    while IFS=$'\t' read -r kind package before_present before; do
        [[ -n "$package" ]] || continue
        begin_managed_package "$kind:$package" "$before_present" "$before" || exit 1
    done < "$BREW_BEFORE"
    echo "    Installing packages from Brewfile..."
    brew_status=0
    if [[ -f "$BREWFILE" ]]; then
        brew bundle --file="$BREWFILE" || brew_status=$?
    else
        echo "    [!] manifests/Brewfile not found, skipping."
    fi

    if ! receipt_init; then (( brew_status == 0 )) || exit "$brew_status"; exit 1; fi
    while IFS=$'\t' read -r kind package before_present before; do
        [[ -n "$package" ]] || continue
        after="$(brew list --"${kind/brew/formula}" --versions "$package" 2>/dev/null | awk '{print $2}' || true)"
        if [[ -n "$after" && ( "$before_present" != true || "$after" != "$before" ) ]]; then
            record_managed_package "$kind:$package" "$before_present" "$before" "$after"
        else
            cancel_managed_package "$kind:$package"
        fi
    done < "$BREW_BEFORE"
    (( brew_status == 0 )) || exit "$brew_status"
    }
    run_optional_stage SKIP_PACKAGES "==> [CI] Skipping Homebrew packages (SKIP_PACKAGES=1)" install_system_packages

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
    set_managed_git_value core.autocrlf input
    set_managed_git_value core.fileMode true

elif [[ "$OS" == "Linux" ]]; then
    install_system_packages() {
    # =============================================
    # [Linux] apt 및 github releases
    # =============================================
    echo
    echo "==> Installing packages via apt..."
    APT_FILE="$ROOT/manifests/apt.txt"
    if [[ -f "$APT_FILE" ]]; then
        APT_BEFORE="$(mktemp)"; _TMPFILES+=("$APT_BEFORE")
        while IFS= read -r package; do
            dpkg_state="$(dpkg-query -W -f='${db:Status-Abbrev}\t${Version}' "$package" 2>/dev/null || true)"
            IFS=$'\t' read -r dpkg_status dpkg_version <<< "$dpkg_state"
            before=""; [[ "$dpkg_status" == 'ii ' ]] && before="$dpkg_version"
            before_present=false; if [[ -n "$before" ]]; then before_present=true; fi
            printf '%s\t%s\t%s\n' "$package" "$before_present" "$before"
        done < <(manifest_lines "$APT_FILE") > "$APT_BEFORE"
        run_privileged apt-get update -y
        if ! $RECEIPT_READY; then
            jq_before="$(awk -F'\t' '$1=="jq" {print $2 "\t" $3}' "$APT_BEFORE")"
            IFS=$'\t' read -r jq_before_present jq_before_version <<< "$jq_before"
            receipt_bootstrap_jq apt "${jq_before_present:-false}" || exit 1
            jq_status=0
            DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y jq --no-install-recommends || jq_status=$?
            jq_state="$(dpkg-query -W -f='${db:Status-Abbrev}\t${Version}' jq 2>/dev/null || true)"
            IFS=$'\t' read -r jq_dpkg_status jq_dpkg_version <<< "$jq_state"
            jq_after=""; [[ "$jq_dpkg_status" == 'ii ' ]] && jq_after="$jq_dpkg_version"
            if command -v jq >/dev/null 2>&1; then
                receipt_init || exit 1
                if [[ -n "$jq_after" && "$jq_after" != "${jq_before_version:-}" ]]; then
                    record_managed_package apt:jq "${jq_before_present:-false}" "${jq_before_version:-}" "$jq_after"
                else
                    cancel_managed_package apt:jq
                fi
            fi
            (( jq_status == 0 )) || exit "$jq_status"
            $RECEIPT_READY || exit 1
        fi
        while IFS=$'\t' read -r package before_present before; do
            [[ -n "$package" ]] || continue
            begin_managed_package "apt:$package" "$before_present" "$before" || exit 1
        done < "$APT_BEFORE"
        apt_status=0
        # shellcheck disable=SC2046
        DEBIAN_FRONTEND=noninteractive run_privileged apt-get install -y \
            $(manifest_lines "$APT_FILE") --no-install-recommends || apt_status=$?
        if ! receipt_init; then (( apt_status == 0 )) || exit "$apt_status"; exit 1; fi
        while IFS=$'\t' read -r package before_present before; do
            [[ -n "$package" ]] || continue
            dpkg_state="$(dpkg-query -W -f='${db:Status-Abbrev}\t${Version}' "$package" 2>/dev/null || true)"
            IFS=$'\t' read -r dpkg_status dpkg_version <<< "$dpkg_state"
            after=""; [[ "$dpkg_status" == 'ii ' ]] && after="$dpkg_version"
            if [[ -n "$after" && ( "$before_present" != true || "$after" != "$before" ) ]]; then
                record_managed_package "apt:$package" "$before_present" "$before" "$after"
            else
                cancel_managed_package "apt:$package"
            fi
        done < "$APT_BEFORE"
        (( apt_status == 0 )) || exit "$apt_status"
    else
        record_install_failure "Required manifest missing: manifests/apt.txt"
        receipt_init || exit 1
    fi

    echo "    Refreshing font cache..."
    fc-cache -vf

    # 22.04에서 'bat'은 batcat 으로, 'fd'는 fdfind 로 설치됨 → ~/.local/bin 심볼릭 링크
    if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
        if ensure_managed_symlink "$LOCAL_BIN/bat" "$(command -v batcat)"; then echo "    Linked $LOCAL_BIN/bat -> batcat"; fi
    fi
    if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
        if ensure_managed_symlink "$LOCAL_BIN/fd" "$(command -v fdfind)"; then echo "    Linked $LOCAL_BIN/fd -> fdfind"; fi
    fi
    }
    run_optional_stage SKIP_PACKAGES "==> [CI] Skipping apt packages (SKIP_PACKAGES=1)" install_system_packages

    # =============================================
    # 1-1. gitconfig 병합 + Linux 전용 override
    # =============================================
    echo
    echo "==> Merging git config..."
    merge_gitconfig "$ROOT/config/git/gitconfig"
    set_managed_git_value core.autocrlf input
    set_managed_git_value core.fileMode true
fi

# =============================================
# 1-2. tmux 설정 복사 (config/tmux/tmux.linux.conf → ~/.tmux.conf)
# =============================================
echo
TMUX_SRC="$ROOT/config/tmux/tmux.linux.conf"
if [[ -f "$TMUX_SRC" ]]; then
    if install_managed_file "$TMUX_SRC" "$HOME/.tmux.conf" takeover; then echo "    Copied tmux.linux.conf to .tmux.conf (Unix)"; fi
fi

# =============================================
# 1-3. yazi 설정 배포 (config/yazi/ → ~/.config/yazi/)
# =============================================
echo
echo "==> Deploying yazi config..."
if [[ -d "$ROOT/config/yazi" ]]; then
    if install_managed_tree "$ROOT/config/yazi" "$YAZI_CONFIG_DIR" takeover; then echo "    yazi config deployed to $YAZI_CONFIG_DIR"; fi
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
    if install_managed_tree "$ROOT/config/nvim" "$NVIM_CONFIG_DIR" takeover; then
        echo "    lazy.nvim config deployed to $NVIM_CONFIG_DIR"
        echo "    Run nvim to auto-install lazy.nvim on first launch."
    fi
fi

# =============================================
# 1-5. starship 설정 배포 (config/starship.toml → ~/.config/starship.toml)
# =============================================
echo
if [[ -f "$ROOT/config/starship.toml" ]]; then
    if install_managed_file "$ROOT/config/starship.toml" "$STARSHIP_CONFIG" takeover; then echo "    Copied starship.toml to $STARSHIP_CONFIG"; fi
fi

add_to_path_runtime "$LOCAL_BIN"
add_to_path_runtime "$HOME/.bun/bin"
add_to_path_runtime "$HOME/.local/share/fnm"

# macOS는 Brewfile을 사용하고 Linux만 pinned, checksum-verified artifact를 설치한다.
install_runtime_packages() {
if [[ "$OS" == "Linux" ]]; then
    echo
    echo "==> Installing pinned direct artifacts..."
    install_direct_artifacts || exit 1
fi

    # =============================================
    # 2. Node.js LTS (fnm)
    # =============================================
    install_node_lts || record_install_failure "Node.js LTS installation failed."
# =============================================
# 2-1. npm 전역 패키지 (manifests/npm-global.txt)
# =============================================
echo
echo "==> Installing global npm packages..."
NPM_FILE="$ROOT/manifests/npm-global.txt"
if [[ -f "$NPM_FILE" ]] && command -v npm >/dev/null 2>&1; then
    npm_root="$(npm root -g)"; npm_prefix="$(npm prefix -g)"
    # fnm multishell 링크를 풀어 셸 간 안정적인 prefix로 기록한다. uninstall도 이 실경로를 요구한다.
    npm_prefix="$(resolve_link_path "$npm_prefix")"
    npm_failed=0
    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        package_json="$npm_root/$pkg/package.json"
        before="$(jq -r '.version // empty' "$package_json" 2>/dev/null || true)"
        before_present=false; if [[ -n "$before" ]]; then before_present=true; fi
        # 소유권을 판정할 수 없는 패키지 하나 때문에 이후 설치 단계 전체를 중단하지 않는다.
        if ! begin_managed_package "npm:$pkg" "$before_present" "$before" "$npm_prefix"; then
            record_install_failure "npm receipt journal failed; skipping package: $pkg"
            continue
        fi
        if npm install -g "$pkg" >/dev/null 2>&1; then
            echo "    Installed $pkg"
        else
            echo "    [!] Failed: $pkg"
            npm_failed=1
        fi
        after="$(jq -r '.version // empty' "$package_json" 2>/dev/null || true)"
        if [[ -n "$after" && ( "$before_present" != true || "$before" != "$after" ) ]]; then
            record_managed_package "npm:$pkg" "$before_present" "$before" "$after" "$npm_prefix"
        else
            cancel_managed_package "npm:$pkg"
        fi
    done < <(manifest_lines "$NPM_FILE")
    (( npm_failed == 0 )) || record_install_failure "One or more npm packages failed."
elif [[ ! -f "$NPM_FILE" ]]; then
    record_install_failure "Required manifest missing: manifests/npm-global.txt"
else
    record_install_failure "npm is required for manifests/npm-global.txt."
fi
}
run_optional_stage SKIP_PACKAGES "==> [CI] Skipping direct, Node.js, and npm packages (SKIP_PACKAGES=1)" install_runtime_packages

# =============================================
# 2-2. Codex 설정 배포 (config/codex/ + config/agents/global.md → ~/.codex/)
# =============================================
echo
echo "==> Deploying Codex config..."
mkdir -p "$CODEX_DIR"
merge_codex_config "$ROOT/config/codex/config.toml" "$CODEX_DIR/config.toml"

AGENTS_GLOBAL_SRC="$ROOT/config/agents/global.md"
ROLES_SRC="$ROOT/config/agents/roles"
if [[ -f "$AGENTS_GLOBAL_SRC" ]]; then
    if install_managed_file "$AGENTS_GLOBAL_SRC" "$CODEX_DIR/AGENTS.md" takeover; then echo "    Copied global agent instructions to AGENTS.md"; fi
else
    echo "    [!] config/agents/global.md not found"
fi

# 공용 role: config/agents/roles/<name>/ = codex.toml + body.md 조립
# → ~/.codex/agents/<name>.toml (Codex subagent. body.md는 developer_instructions 값이 된다)
if [[ -d "$ROLES_SRC" ]]; then
    mkdir -p "$CODEX_DIR/agents"
    for d in "$ROLES_SRC"/*/; do
        [[ -f "$d/codex.toml" && -f "$d/body.md" ]] || continue
        name="$(basename "$d")"
        # TOML literal multi-line string(''') — 이스케이프 해석이 없어 body를 그대로 담는다
        tmp_agent="$(mktemp)"; _TMPFILES+=("$tmp_agent")
        {
            cat "$d/codex.toml"
            printf "developer_instructions = '''\n"
            cat "$d/body.md"
            printf "'''\n"
        } > "$tmp_agent"
        if install_managed_file "$tmp_agent" "$CODEX_DIR/agents/$name.toml" skip; then echo "    Deployed agent: $name"; fi
    done
fi

# hooks.json: 사용자 hook 보존 + dotfiles 관리 command upsert
CODEX_HOOKS_JSON_SRC="$ROOT/config/codex/hooks.json"
if [[ -f "$CODEX_HOOKS_JSON_SRC" ]]; then
    merge_json_registry "$CODEX_HOOKS_JSON_SRC" "$CODEX_DIR/hooks.json"
else
    echo "    [!] config/codex/hooks.json not found"
fi

# hooks/temporal-context.sh 배포
CODEX_HOOKS_DIR="$CODEX_DIR/hooks"
TEMPORAL_SRC="$ROOT/config/codex/hooks/temporal-context.sh"
if [[ -f "$TEMPORAL_SRC" ]]; then
    if install_managed_file "$TEMPORAL_SRC" "$CODEX_HOOKS_DIR/temporal-context.sh" skip; then
        echo "    Copied temporal-context.sh to ~/.codex/hooks/ and set +x"
    fi
else
    echo "    [!] config/codex/hooks/temporal-context.sh not found, skipping."
fi

# =============================================
# 3. Claude Code package-manager 설치
# =============================================
echo
install_claude_code_stage() {
    echo "==> Installing Claude Code via package manager..."
    if [[ "$OS" == Darwin ]] && jq -e '.packages["cask:claude-code"].pending != null' "$RECEIPT_PATH" >/dev/null; then
        command_present=false; command -v claude >/dev/null 2>&1 && command_present=true
        reconcile_pending_claude_package cask:claude-code query_claude_cask "$command_present" || {
            echo "    [!] Pending Claude cask identity unavailable; receipt left pending." >&2; exit 1;
        }
    elif [[ "$OS" == Linux ]] && jq -e '.packages["npm:@anthropic-ai/claude-code"].pending != null' "$RECEIPT_PATH" >/dev/null; then
        CLAUDE_NPM_PREFIX="$(jq -r '.packages["npm:@anthropic-ai/claude-code"].prefix // empty' "$RECEIPT_PATH")"
        [[ -n "$CLAUDE_NPM_PREFIX" ]] || { echo "    [!] Pending Claude npm prefix missing; receipt preserved." >&2; exit 1; }
        command_present=false; command -v claude >/dev/null 2>&1 && command_present=true
        reconcile_pending_claude_package npm:@anthropic-ai/claude-code query_claude_npm_package "$command_present" || {
            echo "    [!] Pending Claude npm identity unavailable; receipt left pending." >&2; exit 1;
        }
    fi
    if command -v claude >/dev/null 2>&1; then
        echo "    Claude Code already installed: $(claude --version 2>/dev/null || echo unknown)"
    elif [[ "$OS" == Darwin ]]; then
        query_claude_cask || { echo "    [!] Claude cask identity query failed before installation." >&2; exit 1; }
        before="$CLAUDE_QUERY_VERSION"; before_present=false; [[ "$CLAUDE_QUERY_STATE" == present ]] && before_present=true
        begin_managed_package cask:claude-code "$before_present" "$before" || exit 1
        manager_status=0; brew install --cask claude-code || manager_status=$?
        command_present=false; command -v claude >/dev/null 2>&1 && command_present=true
        complete_managed_claude_package cask:claude-code query_claude_cask "$before_present" "$before" "$manager_status" "$command_present" || exit $?
    elif command -v npm >/dev/null 2>&1 && [[ "$(node --version 2>/dev/null | sed 's/^v//' | cut -d. -f1)" -ge 22 ]]; then
        CLAUDE_NPM_PREFIX="$(npm prefix -g)" || exit 1
        # npm 전역 패키지와 같은 이유로 fnm multishell 링크를 풀어 안정 경로로 기록한다.
        CLAUDE_NPM_PREFIX="$(resolve_link_path "$CLAUDE_NPM_PREFIX")"
        query_claude_npm_package || { echo "    [!] Claude npm identity query failed before installation." >&2; exit 1; }
        before="$CLAUDE_QUERY_VERSION"; before_present=false; [[ "$CLAUDE_QUERY_STATE" == present ]] && before_present=true
        npm_prefix="$CLAUDE_NPM_PREFIX"
        begin_managed_package npm:@anthropic-ai/claude-code "$before_present" "$before" "$npm_prefix" || exit 1
        manager_status=0; npm install -g @anthropic-ai/claude-code || manager_status=$?
        command_present=false; command -v claude >/dev/null 2>&1 && command_present=true
        complete_managed_claude_package npm:@anthropic-ai/claude-code query_claude_npm_package "$before_present" "$before" "$manager_status" "$command_present" "$npm_prefix" || exit $?
    else
        echo "    [!] Claude Code requires npm with Node.js 22+ on Linux." >&2
        exit 1
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
        merge_json_registry "$SETTINGS_SRC" "$SETTINGS_DST"
    else
        echo "    [!] config/claude/settings.json not found"
    fi

    if [[ -f "$AGENTS_GLOBAL_SRC" ]]; then
        if install_managed_file "$AGENTS_GLOBAL_SRC" "$CLAUDE_DIR/CLAUDE.md" takeover; then echo "    Copied global agent instructions to CLAUDE.md"; fi
    else
        echo "    [!] config/agents/global.md not found"
    fi

    # hooks/: 배포 (temporal-context.sh 등) + 실행 권한
    HOOKS_SRC="$ROOT/config/claude/hooks"
    HOOKS_DST="$CLAUDE_DIR/hooks"
    if [[ -d "$HOOKS_SRC" ]]; then
        hook_status=0
        while IFS= read -r -d '' hook_src; do
            hook_rel="${hook_src#"$HOOKS_SRC"/}"
            managed_hook="$hook_src"
            if [[ "$hook_src" == *.sh ]]; then
                managed_hook="$(mktemp)"; _TMPFILES+=("$managed_hook")
                if ! cp -p "$hook_src" "$managed_hook" || ! chmod +x "$managed_hook"; then hook_status=1; continue; fi
            fi
            if ! install_managed_file "$managed_hook" "$HOOKS_DST/$hook_rel" skip; then
                hook_status=1
            fi
        done < <(find "$HOOKS_SRC" -type f -print0)
        if (( hook_status == 0 )); then echo "    Copied hooks/ and set +x"; fi
    else
        echo "    [!] config/claude/hooks not found, skipping."
    fi

    # 로컬 skills/: dotfiles 소유 skill만 디렉터리 단위 배포 (원격 npx skill 보존)
    SKILLS_LOCAL_SRC="$ROOT/config/claude/skills"
    if [[ -d "$SKILLS_LOCAL_SRC" ]]; then
        mkdir -p "$CLAUDE_DIR/skills"
        for d in "$SKILLS_LOCAL_SRC"/*/; do
            [[ -d "$d" ]] || continue
            name="$(basename "$d")"
            if install_managed_tree "$d" "$CLAUDE_DIR/skills/$name" skip true; then echo "    Deployed local skill: $name"; fi
        done
    fi

    # 공용 role: config/agents/roles/<name>/ = claude.frontmatter + body.md 조립
    # → ~/.claude/agents/<name>.md (사용자가 직접 만든 다른 agent 파일은 보존)
    if [[ -d "$ROLES_SRC" ]]; then
        mkdir -p "$CLAUDE_DIR/agents"
        for d in "$ROLES_SRC"/*/; do
            [[ -f "$d/claude.frontmatter" && -f "$d/body.md" ]] || continue
            name="$(basename "$d")"
            tmp_agent="$(mktemp)"; _TMPFILES+=("$tmp_agent")
            cat "$d/claude.frontmatter" "$d/body.md" > "$tmp_agent"
            if install_managed_file "$tmp_agent" "$CLAUDE_DIR/agents/$name.md" skip; then echo "    Deployed agent: $name"; fi
        done
    fi
}
run_optional_stage SKIP_CLAUDE_CODE "==> [CI] Skipping Claude Code installation (SKIP_CLAUDE_CODE=1)" install_claude_code_stage

# =============================================
# 4. shell 프로파일 설정 (bash + macOS zsh, 마커 방식)
# =============================================
echo
install_shell_profiles

# =============================================
# 6. Claude Code skills 설치 (manifests/skills.txt)
# =============================================
echo
run_skills_stage "$ROOT/manifests/skills.txt"

# =============================================
# 7. Claude Code 플러그인 설치 (manifests/plugins.txt)
# =============================================
echo
run_plugins_stage "$ROOT/manifests/plugins.txt"

finish_install || exit 1
