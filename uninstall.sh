#!/usr/bin/env bash
# receipt v1에 기록된 exact identity만 되돌린다.
# shellcheck disable=SC2016
[[ "${DOTFILES_FUNCTIONS_ONLY:-0}" == 1 ]] || set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECEIPT_PATH="${DOTFILES_RECEIPT_PATH:-${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-receipt.json}"
KEEP_PACKAGES=false
case "${1:-}" in '') ;; --keep-packages) KEEP_PACKAGES=true ;; *) echo "Usage: $0 [--keep-packages]" >&2; exit 2;; esac
_TMPFILES=()
trap '(( ${#_TMPFILES[@]} == 0 )) || rm -rf "${_TMPFILES[@]}"' EXIT

warn() { printf '    [!] %s\n' "$*" >&2; }
manifest_lines() { sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$1" | awk '{$1=$1;print}'; }
file_hash() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
file_mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
managed_parent_is_safe() {
    local path="$1" parent next
    parent="$(dirname "$path")"
    while [[ "$parent" != "$HOME" && "$parent" != / && "$parent" != . ]]; do
        [[ ! -L "$parent" && ( ! -e "$parent" || -d "$parent" ) ]] || return 1
        next="$(dirname "$parent")"; [[ "$next" != "$parent" ]] || break; parent="$next"
    done
    [[ "$parent" == "$HOME" ]]
}
backup_is_canonical() { case "$2" in ''|"$1.dotfiles-backup") return 0;; "$1.dotfiles-backup."*) [[ "${2#"$1.dotfiles-backup."}" =~ ^[0-9]+$ ]];; *) return 1;; esac; }
receipt_is_safe() {
    local parent next
    [[ -f "$RECEIPT_PATH" && ! -L "$RECEIPT_PATH" ]] || return 1
    parent="$(dirname "$RECEIPT_PATH")"
    while [[ "$parent" != "$HOME" && "$parent" != / && "$parent" != . ]]; do [[ ! -L "$parent" && -d "$parent" ]] || return 1; next="$(dirname "$parent")"; [[ "$next" != "$parent" ]] || break; parent="$next"; done
    [[ "$parent" == "$HOME" ]]
}
package_key_allowed() {
    local key="$1" kind name
    kind="${key%%:*}"; name="${key#*:}"
    case "$key" in npm:@anthropic-ai/claude-code|cask:claude-code) return 0;; esac
    case "$kind" in
      apt) manifest_lines "$ROOT/manifests/apt.txt" | grep -Fxq "$name";;
      brew|cask) awk -F'"' '/^(brew|cask) "/ { kind=$1; sub(/[[:space:]]+$/, "", kind); print kind ":" $2 }' "$ROOT/manifests/Brewfile" | grep -Fxq "$key";;
      npm) manifest_lines "$ROOT/manifests/npm-global.txt" | grep -Fxq "$name";;
      *) return 1;;
    esac
}
value_key_allowed() {
    case "$1" in git:core.pager|git:core.editor|git:core.fileMode|git:core.autocrlf|git:core.eol|git:interactive.diffFilter|git:delta.navigate|git:delta.dark|git:delta.side-by-side|git:delta.line-numbers|git:merge.conflictStyle) return 0;; esac
    return 1
}
npm_prefix_allowed() {
    local prefix="$1" fnm_root="${FNM_DIR:-$HOME/.local/share/fnm}" relative
    [[ "$fnm_root" == "$HOME/"* && "$prefix" == "$fnm_root/node-versions/"*"/installation" && "$prefix" != *'/../'* && "$prefix" != *'/./'* ]] || return 1
    relative="${prefix#"$fnm_root/node-versions/"}"; [[ "${relative%/installation}" != */* ]] && managed_parent_is_safe "$prefix/package.json"
}
receipt_schema_valid() {
    jq -e --arg home "$HOME" '
      .schemaVersion==1 and (.artifacts|type)=="object" and (.packages|type)=="object" and (.values|type)=="object" and
      all(.artifacts|to_entries[];
        (.key|startswith($home+"/")) and ((.key|contains("/../"))|not) and ((.key|contains("/./"))|not) and ((.key|contains("//"))|not) and
        (.value.before|type)=="object" and (.value.before.exists|type)=="boolean" and
        ([.value|has("installedHash"),has("installedTarget"),has("installedTreeHash")]|map(select(.))|length)==1 and
        (if .value|has("installedHash") then
          ((.value.installedHash|type)=="string" or (.value.pending==true and .value.installedHash==null)) and
          (if .value.before.exists then ((.value.before.hash|type)=="string" and (.value.before.mode|type)=="string" and (.value.before.backup|type)=="string" and (.value.before.backup|length)>0) else true end) and
          ((.value.installedHash==null) or (.value.installedMode|type)=="string") and
          (if .value.pending==true then (.value.targetHash|type)=="string" and (.value.targetMode|type)=="string" and (.value.previousExists|type)=="boolean" else (.value.pending==false) end)
        elif .value|has("installedTarget") then
          ((.value.installedTarget|type)=="string" or (.value.pending==true and .value.installedTarget==null)) and
          (if .value.before.exists then .value.before.type=="symlink" and (.value.before.target|type)=="string" else .value.before.type=="missing" and .value.before.target==null end) and
          (if .value.pending==true then (.value.targetTarget|type)=="string" and (.value.previousExists|type)=="boolean" and (if .value.previousExists then .value.previousType=="symlink" and (.value.previousTarget|type)=="string" else .value.previousType=="missing" and .value.previousTarget==null end) else (.value.pending==false) end)
        elif .value|has("installedTreeHash") then
          (.value.before.exists==false) and ((.value.installedTreeHash|type)=="string" or (.value.pending==true and .value.installedTreeHash==null)) and
          (if .value.pending==true then (.value.targetTreeHash|type)=="string" and .value.previousExists==false else (.value.pending==false) end)
        else false end)) and
      all(.packages|to_entries[];
        (.key|(test("^(apt|cask):[^/[:space:]]+$") or test("^brew:[^[:space:]]+$") or test("^npm:(@[^/[:space:]]+/)?[^/[:space:]]+$"))) and (.value.before.present|type)=="boolean" and
        ((.value.installed|type)=="string" or ((.value|has("pending")) and .value.installed==null)) and
        (if .value.before.present then (.value.before.value|type)=="string" else true end) and
        (if ((.key|startswith("npm:")) and (.value|has("prefix"))) then (.value.prefix|type)=="string" and (.value.prefix|length)>0 else true end) and
        (if .value|has("pending") then (.value.pending.previousPresent|type)=="boolean" and (.value.pending.newEntry|type)=="boolean" and (if .value.pending.previousPresent then (.value.pending.previousValue|type)=="string" else true end) else true end)) and
      all(.values|to_entries[];
        (.key|test("^git:[A-Za-z0-9.-]+$")) and (.value.before.present|type)=="boolean" and
        ((.value.installed|type)=="string" or ((.value|has("pending")) and .value.installed==null)) and
        (if .value.before.present then (.value.before.value|type)=="string" else true end) and
        (if .value|has("pending") then (.value.pending.previousPresent|type)=="boolean" and (.value.pending.target|type)=="string" and (if .value.pending.previousPresent then (.value.pending.previousValue|type)=="string" else true end) else true end))
    ' "$RECEIPT_PATH" >/dev/null
}
tree_hash() {
    local root="$1"
    {
        printf 'root\0%s\0' "$(file_mode "$root")"
        if find "$root" -mindepth 1 -printf '' >/dev/null 2>&1; then
            find "$root" -mindepth 1 -printf '%P\t%y\t%m\t%l\t%s\0' | LC_ALL=C sort -z
        else
            find "$root" -mindepth 1 -exec stat -f '%N\t%HT\t%Lp\t%Y\t%z' {} \; | LC_ALL=C sort
        fi
        printf 'content\0'
        tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner -cf - -C "$root" . 2>/dev/null
    } | { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
}

receipt_commit() {
    local tmp
    tmp="$(mktemp "$(dirname "$RECEIPT_PATH")/.uninstall-receipt.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    jq "$@" "$RECEIPT_PATH" > "$tmp" && jq empty "$tmp" && chmod 600 "$tmp" && mv "$tmp" "$RECEIPT_PATH"
}

finish_jq_package() {
    local key manager installed marker tmp before
    key="$(jq -r '.packages|keys[]|select(test("^(apt|brew):jq$"))' "$RECEIPT_PATH")"
    [[ -n "$key" ]] || return 0
    if $KEEP_PACKAGES; then drop_entry packages "$key"; return; fi
    jq -e '(.artifacts|length)==0 and (.values|length)==0 and (.packages|length)==1' "$RECEIPT_PATH" >/dev/null || { warn "jq kept until all other receipt entries resolve."; return 1; }
    manager="${key%%:*}"; installed="$(jq -r --arg k "$key" '.packages[$k].installed' "$RECEIPT_PATH")"
    before="$(jq -r --arg k "$key" '.packages[$k].before.present' "$RECEIPT_PATH")"
    query_package "$key" || return 1
    if [[ "$before" == true ]]; then
        [[ "$PACKAGE_STATE" == present && ( "$PACKAGE_VERSION" == "$installed" || "$PACKAGE_VERSION" == "$(jq -r --arg k "$key" '.packages[$k].before.value' "$RECEIPT_PATH")" ) ]] || { warn "pre-existing jq changed; preserving."; return 1; }
        drop_entry packages "$key"; return
    fi
    [[ "$PACKAGE_STATE" == absent ]] && { rm -f "$RECEIPT_PATH"; return; }
    [[ "$PACKAGE_VERSION" == "$installed" && "$(jq -r --arg k "$key" '.packages[$k].before.present' "$RECEIPT_PATH")" == false ]] || { warn "jq package changed/pre-existing; preserving."; return 1; }
    [[ "$installed" =~ ^[A-Za-z0-9._+~:-]+$ ]] || return 1
    printf -v marker 'dotfiles-jq-terminal-v1\t%s\t%s' "$manager" "$installed"
    tmp="$(mktemp "$(dirname "$RECEIPT_PATH")/.uninstall-terminal.XXXXXX")" || return 1; printf '%s\n' "$marker" > "$tmp" && chmod 600 "$tmp" && mv "$tmp" "$RECEIPT_PATH" || return 1
    remove_package "$key" || return 1
    query_terminal_jq "$manager" || return 1
    [[ "$TERMINAL_STATE" == absent ]] && rm -f "$RECEIPT_PATH"
}
query_terminal_jq() {
    local manager="$1" out status
    TERMINAL_STATE=error; TERMINAL_VERSION=""
    if [[ "$manager" == apt ]]; then
        status=0; out="$(dpkg-query -W -f='${Status}\t${Version}' jq 2>/dev/null)" || status=$?
        if (( status == 0 )) && [[ "$out" == 'install ok installed'$'\t'* ]]; then TERMINAL_STATE=present; TERMINAL_VERSION="${out#*$'\t'}"; return; fi
        if (( status == 1 )) && [[ -z "$out" ]]; then TERMINAL_STATE=absent; return; fi
        return 1
    fi
    if out="$(brew list --versions jq 2>/dev/null)"; then TERMINAL_VERSION="$(awk '$1=="jq"{print $2;exit}' <<< "$out")"; [[ -n "$TERMINAL_VERSION" ]] || return 1; TERMINAL_STATE=present; return; fi
    brew list >/dev/null 2>&1 || return 1; TERMINAL_STATE=absent
}
recover_terminal_jq() {
    local marker="$1" tag manager installed extra expected
    [[ "$marker" != *$'\n'* && "$marker" != *$'\r'* ]] || return 2
    IFS=$'\t' read -r tag manager installed extra <<< "$marker"
    [[ "$tag" == dotfiles-jq-terminal-v1 && ( "$manager" == apt || "$manager" == brew ) && "$installed" =~ ^[A-Za-z0-9._+~:-]+$ && -z "$extra" ]] || return 2
    printf -v expected 'dotfiles-jq-terminal-v1\t%s\t%s' "$manager" "$installed"
    [[ "$marker" == "$expected" ]] && cmp -s "$RECEIPT_PATH" <(printf '%s\n' "$expected") || return 2
    $KEEP_PACKAGES && { rm -f "$RECEIPT_PATH"; return; }
    query_terminal_jq "$manager" || { warn "terminal jq identity unavailable; preserved."; return 1; }
    [[ "$TERMINAL_STATE" == absent ]] && { rm -f "$RECEIPT_PATH"; return; }
    [[ "$TERMINAL_VERSION" == "$installed" ]] || { warn "terminal jq changed; preserved."; return 1; }
    if [[ "$manager" == apt ]]; then sudo apt-get remove -y jq || return 1; else brew uninstall jq || return 1; fi
    query_terminal_jq "$manager" || return 1
    [[ "$TERMINAL_STATE" == absent ]] && rm -f "$RECEIPT_PATH"
}
drop_entry() { receipt_commit --arg group "$1" --arg key "$2" 'del(.[$group][$key])'; }

artifact_allowed() {
    local path="$1" rel name
    case "$path" in
        "$HOME/.tmux.conf"|"$HOME/.config/starship.toml") return 0 ;;
        "$HOME/.local/bin/"*)
            name="${path##*/}"
            [[ "${path#"$HOME/.local/bin/"}" == "$name" ]] || return 1
            case "$name" in starship|atuin|fnm|bun|bunx|yazi|ya|lazygit|fzf|nvim|delta|bat|fd|eza|yq|node|npm|npx) return 0;; esac ;;
        "$HOME/.local/share/fnm/fnm"|"$HOME/.bun/bin/bun"|"$HOME/.bun/bin/bunx") return 0 ;;
        "$HOME/.local/opt/nvim-v"*) [[ "${path#"$HOME/.local/opt/nvim-v"}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && return 0 ;;
    esac
    for pair in \
        "$ROOT/config/yazi|$HOME/.config/yazi" "$ROOT/config/nvim|$HOME/.config/nvim" \
        "$ROOT/config/codex/hooks|$HOME/.codex/hooks" "$ROOT/config/claude/hooks|$HOME/.claude/hooks" \
        "$ROOT/config/claude/skills|$HOME/.claude/skills"; do
        src="${pair%%|*}" dst="${pair#*|}"
        case "$path" in "$dst/"*) rel="${path#"$dst/"}"; [[ -f "$src/$rel" ]] && return 0;; esac
    done
    case "$path" in
        "$HOME/.codex/AGENTS.md"|"$HOME/.codex/config.toml"|"$HOME/.codex/hooks.json"|"$HOME/.claude/CLAUDE.md"|"$HOME/.claude/settings.json") return 0 ;;
        "$HOME/.codex/agents/"*.toml) name="${path#"$HOME/.codex/agents/"}"; [[ "$name" != */* && "$name" == *.toml && -d "$ROOT/config/agents/roles/${name%.toml}" ]] && return 0 ;;
        "$HOME/.claude/agents/"*.md) name="${path#"$HOME/.claude/agents/"}"; [[ "$name" != */* && "$name" == *.md && -d "$ROOT/config/agents/roles/${name%.md}" ]] && return 0 ;;
    esac
    return 1
}

remove_marker_block() {
    local file="$1" begin='# ===== dotfiles-begin =====' end='# ===== dotfiles-end =====' bc ec bl el tmp
    managed_parent_is_safe "$file" || { warn "unsafe profile parent preserved: $file"; return 1; }
    [[ ! -e "$file" && ! -L "$file" ]] && return 0
    [[ -f "$file" && ! -L "$file" ]] || { warn "profile path type preserved: $file"; return 1; }
    bc="$(grep -Fxc "$begin" "$file" || true)"; ec="$(grep -Fxc "$end" "$file" || true)"
    [[ "$bc" == 0 && "$ec" == 0 ]] && return 0
    bl="$(grep -nFx "$begin" "$file" | cut -d: -f1)"; el="$(grep -nFx "$end" "$file" | cut -d: -f1)"
    if [[ "$bc" != 1 || "$ec" != 1 || "$bl" -ge "$el" ]] || grep -Fq "$begin" <(grep -FvFx "$begin" "$file") || grep -Fq "$end" <(grep -FvFx "$end" "$file"); then
        warn "invalid marker state preserved: $file"; return 1
    fi
    tmp="$(mktemp "$(dirname "$file")/.profile.XXXXXX")" || return 1; _TMPFILES+=("$tmp")
    awk -v b="$bl" -v e="$el" 'NR < b || NR > e' "$file" > "$tmp" && chmod "$(file_mode "$file")" "$tmp" && mv "$tmp" "$file"
}

current_file_matches() {
    local path="$1" hash="$2" mode="${3:-}"
    [[ -f "$path" && ! -L "$path" && "$(file_hash "$path")" == "$hash" && ( -z "$mode" || "$(file_mode "$path")" == "$mode" ) ]]
}

uninstall_artifact() {
    local path="$1" kind before_exists installed target previous_exists before_hash before_mode backup tmp current
    [[ "$path" != *'/../'* && "$path" != *'/./'* && "$path" != *'//'* ]] || { warn "non-canonical receipt artifact preserved: $path"; return 1; }
    if ! artifact_allowed "$path" || ! managed_parent_is_safe "$path"; then warn "unsafe receipt artifact preserved: $path"; return 1; fi
    [[ "$path" == "$HOME/"* || "$path" == "$HOME/.tmux.conf" ]] || { warn "out-of-home artifact preserved: $path"; return 1; }
    kind="$(jq -r --arg p "$path" '.artifacts[$p] | if has("installedTreeHash") then "tree" elif has("installedTarget") then "symlink" elif has("installedHash") then "file" else "unknown" end' "$RECEIPT_PATH")"
    before_exists="$(jq -r --arg p "$path" '.artifacts[$p].before.exists // false' "$RECEIPT_PATH")"
    if [[ "$kind" == file ]]; then
        installed="$(jq -r --arg p "$path" '.artifacts[$p].installedHash // empty' "$RECEIPT_PATH")"
        installed_mode="$(jq -r --arg p "$path" '.artifacts[$p].installedMode // empty' "$RECEIPT_PATH")"
        before_hash="$(jq -r --arg p "$path" '.artifacts[$p].before.hash // empty' "$RECEIPT_PATH")"
        before_mode="$(jq -r --arg p "$path" '.artifacts[$p].before.mode // empty' "$RECEIPT_PATH")"
        backup="$(jq -r --arg p "$path" '.artifacts[$p].before.backup // empty' "$RECEIPT_PATH")"
        if [[ "$before_exists" == true && -n "$backup" && ! -e "$backup" && ! -L "$backup" ]] && current_file_matches "$path" "$before_hash" "$before_mode"; then drop_entry artifacts "$path"; return; fi
        if jq -e --arg p "$path" '.artifacts[$p].pending == true' "$RECEIPT_PATH" >/dev/null; then
            target="$(jq -r --arg p "$path" '.artifacts[$p].targetHash // empty' "$RECEIPT_PATH")"
            target_mode="$(jq -r --arg p "$path" '.artifacts[$p].targetMode // empty' "$RECEIPT_PATH")"
            previous_exists="$(jq -r --arg p "$path" '.artifacts[$p].previousExists // .artifacts[$p].before.exists' "$RECEIPT_PATH")"
            previous="$(jq -r --arg p "$path" '.artifacts[$p].previousHash // .artifacts[$p].before.hash // empty' "$RECEIPT_PATH")"
            if [[ -n "$target" ]] && current_file_matches "$path" "$target" "$target_mode"; then installed="$target"; installed_mode="$target_mode"
            elif [[ "$previous_exists" == false && ! -e "$path" && ! -L "$path" ]] || { [[ "$previous_exists" == true ]] && current_file_matches "$path" "$previous" "$(jq -r --arg p "$path" '.artifacts[$p].previousMode // empty' "$RECEIPT_PATH")"; }; then
                if [[ -z "$installed" ]]; then drop_entry artifacts "$path"; return; fi
                receipt_commit --arg p "$path" 'del(.artifacts[$p].pending,.artifacts[$p].targetHash,.artifacts[$p].targetMode,.artifacts[$p].previousExists,.artifacts[$p].previousHash,.artifacts[$p].previousMode)' || return 1
                installed="$(jq -r --arg p "$path" '.artifacts[$p].installedHash' "$RECEIPT_PATH")"; installed_mode="$(jq -r --arg p "$path" '.artifacts[$p].installedMode' "$RECEIPT_PATH")"
            else warn "pending artifact changed; preserved: $path"; return 1; fi
        fi
        [[ -n "$installed_mode" ]] || { warn "file mode provenance missing; preserved: $path"; return 1; }
        [[ "$before_exists" == false || -n "$before_mode" ]] || { warn "before mode provenance missing; preserved: $path"; return 1; }
        backup_is_canonical "$path" "$backup" || { warn "unsafe backup path preserved: $backup"; return 1; }
        if [[ "$before_exists" == false && ! -e "$path" && ! -L "$path" ]] || { [[ "$before_exists" == true ]] && current_file_matches "$path" "$before_hash" "$before_mode"; }; then
            if [[ -n "$backup" && ( -e "$backup" || -L "$backup" ) ]]; then current_file_matches "$backup" "$before_hash" "$before_mode" || { warn "invalid backup preserved: $backup"; return 1; }; rm -f "$backup"; fi
            drop_entry artifacts "$path"; return
        fi
        current_file_matches "$path" "$installed" "$installed_mode" || { warn "modified artifact preserved: $path"; return 1; }
        if [[ "$before_exists" == false ]]; then rm -f "$path"
        else
            backup_is_canonical "$path" "$backup" || { warn "unsafe backup path preserved: $backup"; return 1; }
            current_file_matches "$backup" "$before_hash" "$before_mode" || { warn "invalid backup preserved: $backup"; return 1; }
            mv -f "$backup" "$path"
        fi
        drop_entry artifacts "$path"
    elif [[ "$kind" == symlink ]]; then
        installed="$(jq -r --arg p "$path" '.artifacts[$p].installedTarget // empty' "$RECEIPT_PATH")"
        if jq -e --arg p "$path" '.artifacts[$p].pending == true' "$RECEIPT_PATH" >/dev/null; then
            target="$(jq -r --arg p "$path" '.artifacts[$p].targetTarget // empty' "$RECEIPT_PATH")"
            previous_exists="$(jq -r --arg p "$path" '.artifacts[$p].previousExists // false' "$RECEIPT_PATH")"
            previous="$(jq -r --arg p "$path" '.artifacts[$p].previousTarget // empty' "$RECEIPT_PATH")"
            if [[ -L "$path" && "$(readlink "$path")" == "$target" ]]; then installed="$target"
            elif [[ "$previous_exists" == false && ! -e "$path" && ! -L "$path" ]] || { [[ "$previous_exists" == true && -L "$path" && "$(readlink "$path")" == "$previous" ]]; }; then
                if [[ -z "$installed" ]]; then drop_entry artifacts "$path"; return; fi
                receipt_commit --arg p "$path" 'del(.artifacts[$p].pending,.artifacts[$p].targetTarget,.artifacts[$p].previousExists,.artifacts[$p].previousType,.artifacts[$p].previousTarget)' || return 1
                installed="$(jq -r --arg p "$path" '.artifacts[$p].installedTarget' "$RECEIPT_PATH")"
            else warn "pending symlink changed; preserved: $path"; return 1; fi
        fi
        before_target="$(jq -r --arg p "$path" '.artifacts[$p].before.target // empty' "$RECEIPT_PATH")"
        if [[ "$before_exists" == false && ! -e "$path" && ! -L "$path" ]] || { [[ "$before_exists" == true && -L "$path" && "$(readlink "$path")" == "$before_target" ]]; }; then drop_entry artifacts "$path"; return; fi
        [[ -L "$path" && "$(readlink "$path")" == "$installed" ]] || { warn "modified symlink preserved: $path"; return 1; }
        if [[ "$before_exists" == false ]]; then rm -f "$path"; else tmp="$(mktemp "$(dirname "$path")/.link.XXXXXX")"; rm -f "$tmp"; ln -s "$before_target" "$tmp" && mv -f "$tmp" "$path"; fi
        drop_entry artifacts "$path"
    elif [[ "$kind" == tree ]]; then
        installed="$(jq -r --arg p "$path" '.artifacts[$p].installedTreeHash // .artifacts[$p].targetTreeHash // empty' "$RECEIPT_PATH")"
        [[ "$before_exists" == false ]] || { warn "unsupported tree restore preserved: $path"; return 1; }
        if [[ ! -e "$path" && ! -L "$path" ]]; then drop_entry artifacts "$path"; return; fi
        [[ -d "$path" && ! -L "$path" && "$(tree_hash "$path")" == "$installed" ]] || { warn "modified tree preserved: $path"; return 1; }
        rm -rf -- "$path" && drop_entry artifacts "$path"
    else warn "unknown receipt artifact preserved: $path"; return 1
    fi
}

query_package() {
    local key="$1" manager name root json out prefix args
    manager="${key%%:*}"; name="${key#*:}"
    PACKAGE_STATE=error; PACKAGE_VERSION=""
    case "$manager" in
        npm) prefix="$(jq -r --arg k "$key" '.packages[$k].prefix // empty' "$RECEIPT_PATH")"; [[ -n "$prefix" ]] || return 1; root="$(npm root -g --prefix "$prefix" 2>/dev/null)" || return 1; json="$root/$name/package.json"; [[ -e "$json" || -L "$json" ]] || { PACKAGE_STATE=absent; return 0; }; [[ -f "$json" ]] || return 1; PACKAGE_VERSION="$(jq -er '.version|strings|select(length>0)' "$json" 2>/dev/null)" || return 1; PACKAGE_STATE=present ;;
        apt) status=0; out="$(dpkg-query -W -f='${Status}\t${Version}' "$name" 2>/dev/null)" || status=$?; if (( status == 1 )) && [[ -z "$out" ]]; then PACKAGE_STATE=absent; return; fi; (( status == 0 )) || return 1; [[ "$out" == 'install ok installed'$'\t'* ]] || return 1; PACKAGE_VERSION="${out#*$'\t'}"; PACKAGE_STATE=present ;;
        brew|cask)
            args=(list --versions); [[ "$manager" == cask ]] && args=(list --cask --versions)
            if ! out="$(brew "${args[@]}" "$name" 2>/dev/null)"; then
                if [[ "$manager" == cask ]]; then brew list --cask >/dev/null 2>&1 || return 1; else brew list >/dev/null 2>&1 || return 1; fi
                PACKAGE_STATE=absent; return 0
            fi
            PACKAGE_VERSION="$(awk 'NF {print $2;exit}' <<< "$out")"; [[ -n "$PACKAGE_VERSION" ]] || return 1; PACKAGE_STATE=present ;;
        *) return 1 ;;
    esac
}
remove_package() { local key="$1" manager name prefix; manager="${key%%:*}"; name="${key#*:}"; case "$manager" in npm) prefix="$(jq -r --arg k "$key" '.packages[$k].prefix' "$RECEIPT_PATH")"; npm uninstall -g --prefix "$prefix" "$name";; apt) sudo apt-get remove -y "$name";; brew) brew uninstall "$name";; cask) brew uninstall --cask "$name";; *) return 1;; esac; }

uninstall_package() {
    local key="$1" before installed previous_present previous_value prefix final_tmp
    if $KEEP_PACKAGES; then drop_entry packages "$key"; return; fi
    query_package "$key" || { warn "package identity unavailable; preserved: $key"; return 1; }
    before="$(jq -r --arg k "$key" '.packages[$k].before.present' "$RECEIPT_PATH")"; installed="$(jq -r --arg k "$key" '.packages[$k].installed // empty' "$RECEIPT_PATH")"
    if jq -e --arg k "$key" '.packages[$k].pending != null' "$RECEIPT_PATH" >/dev/null; then
        previous_present="$(jq -r --arg k "$key" '.packages[$k].pending.previousPresent' "$RECEIPT_PATH")"; previous_value="$(jq -r --arg k "$key" '.packages[$k].pending.previousValue // empty' "$RECEIPT_PATH")"
        if [[ "$PACKAGE_STATE" == absent && "$previous_present" == false ]] || [[ "$PACKAGE_STATE" == present && "$previous_present" == true && "$PACKAGE_VERSION" == "$previous_value" ]]; then
            if jq -e --arg k "$key" '.packages[$k].pending.newEntry and .packages[$k].installed == null' "$RECEIPT_PATH" >/dev/null; then drop_entry packages "$key"; return; fi
            receipt_commit --arg k "$key" 'del(.packages[$k].pending)' || return 1
            installed="$(jq -r --arg k "$key" '.packages[$k].installed // empty' "$RECEIPT_PATH")"
        else warn "pending package changed; preserved: $key"; return 1; fi
    fi
    if [[ "$before" == true ]]; then
        [[ "$PACKAGE_STATE" == present && ( "$PACKAGE_VERSION" == "$installed" || "$PACKAGE_VERSION" == "$(jq -r --arg k "$key" '.packages[$k].before.value' "$RECEIPT_PATH")" ) ]] || { warn "changed pre-existing package preserved: $key"; return 1; }
        drop_entry packages "$key"; return
    fi
    [[ "$PACKAGE_STATE" == absent ]] && { drop_entry packages "$key"; return; }
    [[ "$PACKAGE_VERSION" == "$installed" ]] || { warn "changed package preserved: $key"; return 1; }
    if [[ "$key" == npm:* ]]; then prefix="$(jq -r --arg k "$key" '.packages[$k].prefix // empty' "$RECEIPT_PATH")"; [[ -n "$prefix" ]] || { warn "npm prefix provenance missing; preserved: $key"; return 1; }; fi
    receipt_commit --arg k "$key" '.packages[$k].uninstallPending=true' || return 1
    final_tmp="$(mktemp "$(dirname "$RECEIPT_PATH")/.uninstall-final.XXXXXX")" || return 1; _TMPFILES+=("$final_tmp")
    jq --arg k "$key" 'del(.packages[$k])' "$RECEIPT_PATH" > "$final_tmp" || return 1
    remove_package "$key" || { warn "package removal failed: $key"; return 1; }
    query_package "$key" || { warn "package post-query failed: $key"; return 1; }
    [[ "$PACKAGE_STATE" == absent ]] || { warn "package still present: $key"; return 1; }
    chmod 600 "$final_tmp" && mv "$final_tmp" "$RECEIPT_PATH"
}

uninstall_value() {
    local key="$1" name current present=false installed before_present before_value
    [[ "$key" == git:* ]] || { warn "unsupported managed value preserved: $key"; return 1; }
    name="${key#git:}"; current="$(git config --global --get "$name" 2>/dev/null)" && present=true
    if jq -e --arg k "$key" '.values[$k].pending != null' "$RECEIPT_PATH" >/dev/null; then
        target="$(jq -r --arg k "$key" '.values[$k].pending.target' "$RECEIPT_PATH")"; pp="$(jq -r --arg k "$key" '.values[$k].pending.previousPresent' "$RECEIPT_PATH")"; pv="$(jq -r --arg k "$key" '.values[$k].pending.previousValue // empty' "$RECEIPT_PATH")"
        if [[ "$present" == true && "$current" == "$target" ]]; then installed="$target"
        elif [[ "$present" == "$pp" && ( "$present" == false || "$current" == "$pv" ) ]]; then
            if jq -e --arg k "$key" '.values[$k].installed == null' "$RECEIPT_PATH" >/dev/null; then drop_entry values "$key"; return; fi
            receipt_commit --arg k "$key" 'del(.values[$k].pending)' || return 1
        else warn "pending value changed; preserved: $key"; return 1; fi
    fi
    installed="$(jq -r --arg k "$key" '.values[$k].installed // empty' "$RECEIPT_PATH")"; before_present="$(jq -r --arg k "$key" '.values[$k].before.present' "$RECEIPT_PATH")"; before_value="$(jq -r --arg k "$key" '.values[$k].before.value // empty' "$RECEIPT_PATH")"
    if [[ "$present" == true && "$current" == "$installed" ]]; then if [[ "$before_present" == true ]]; then git config --global "$name" "$before_value"; else git config --global --unset-all "$name"; fi
    elif [[ "$present" == "$before_present" && ( "$present" == false || "$current" == "$before_value" ) ]]; then :
    else warn "modified value preserved: $key"; return 1; fi
    check="$(git config --global --get "$name" 2>/dev/null)" && check_present=true || check_present=false
    [[ "$check_present" == "$before_present" && ( "$check_present" == false || "$check" == "$before_value" ) ]] || { warn "value restore verification failed: $key"; return 1; }
    drop_entry values "$key"
}

main() {
    local failures=0 key
    if [[ ! -e "$RECEIPT_PATH" && ! -L "$RECEIPT_PATH" ]]; then for file in "$HOME/.bashrc" "$HOME/.inputrc" "$HOME/.zprofile" "$HOME/.zshrc"; do remove_marker_block "$file" || failures=1; done; echo "Dotfiles marker cleanup complete (receipt absent)."; return "$failures"; fi
    receipt_is_safe || { warn "invalid receipt path preserved: $RECEIPT_PATH"; return 1; }
    marker="$(cat "$RECEIPT_PATH" 2>/dev/null)"
    terminal_status=0; recover_terminal_jq "$marker" || terminal_status=$?
    (( terminal_status != 2 )) && return "$terminal_status"
    if ! command -v jq >/dev/null 2>&1; then
        warn "jq is required while receipt exists."; return 1
    fi
    receipt_schema_valid || { warn "invalid receipt preserved: $RECEIPT_PATH"; return 1; }
    while IFS= read -r pair; do path="${pair%%$'\t'*}"; backup="${pair#*$'\t'}"; if ! artifact_allowed "$path" || ! managed_parent_is_safe "$path" || ! backup_is_canonical "$path" "$backup"; then warn "invalid receipt path/backup preserved: $path"; return 1; fi; done < <(jq -r '.artifacts|to_entries[]|[.key,(.value.before.backup//"")]|@tsv' "$RECEIPT_PATH" | tr -d '\r')
    while IFS= read -r key; do package_key_allowed "$key" || { warn "unmanaged package key preserved: $key"; return 1; }; if [[ "$key" == npm:* ]]; then prefix="$(jq -r --arg k "$key" '.packages[$k].prefix // empty' "$RECEIPT_PATH")"; npm_prefix_allowed "$prefix" || { warn "unsafe npm prefix preserved: $prefix"; return 1; }; fi; done < <(jq -r '.packages|keys[]' "$RECEIPT_PATH" | tr -d '\r')
    while IFS= read -r key; do value_key_allowed "$key" || { warn "unmanaged value key preserved: $key"; return 1; }; done < <(jq -r '.values|keys[]' "$RECEIPT_PATH" | tr -d '\r')
    for file in "$HOME/.bashrc" "$HOME/.inputrc" "$HOME/.zprofile" "$HOME/.zshrc"; do remove_marker_block "$file" || failures=1; done
    while IFS= read -r key; do uninstall_value "$key" || failures=1; done < <(jq -r '.values|keys[]' "$RECEIPT_PATH" | tr -d '\r')
    while IFS= read -r key; do [[ -n "$key" ]] && uninstall_package "$key" || failures=1; done < <(jq -r '.packages|keys[]|select(startswith("npm:"))' "$RECEIPT_PATH" | tr -d '\r')
    while IFS= read -r key; do uninstall_artifact "$key" || failures=1; done < <(jq -r '.artifacts|keys[]' "$RECEIPT_PATH" | tr -d '\r')
    while IFS= read -r key; do [[ -n "$key" ]] && uninstall_package "$key" || failures=1; done < <(jq -r '.packages|keys[]|select((startswith("npm:") or test("^(apt|brew):jq$"))|not)' "$RECEIPT_PATH" | tr -d '\r')
    jq -e '.packages|keys[]|test("^(apt|brew):jq$")' "$RECEIPT_PATH" >/dev/null 2>&1 && { finish_jq_package || failures=1; }
    if jq -e '(.artifacts|length)==0 and (.packages|length)==0 and (.values|length)==0' "$RECEIPT_PATH" >/dev/null; then rm -f "$RECEIPT_PATH"; fi
    (( failures == 0 )) && echo "Safe-Clean-Uninstall complete."
    return "$failures"
}

[[ "${DOTFILES_FUNCTIONS_ONLY:-0}" == 1 ]] || main "$@"
