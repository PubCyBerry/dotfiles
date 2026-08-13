#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-failure-contract.XXXXXX")"
export HOME="$work/home" DOTFILES_FUNCTIONS_ONLY=1
mkdir -p "$work/bin"
source "$repo/install.sh"
unset DOTFILES_FUNCTIONS_ONLY
trap '_cleanup; rm -rf "$work"' EXIT

validate_plugin_manifest "$repo/manifests/plugins.txt"

record_install_failure 'fixture failure' 2>/dev/null
if output="$(finish_install)"; then echo 'failure ledger returned success' >&2; exit 1; fi
[[ "$output" != *'==> Done!'* ]]
INSTALL_FAILURES=""
output="$(finish_install)"
[[ "$output" == *'==> Done!'* ]]

export CALL_LOG="$work/claude.log"
cat > "$work/bin/claude" <<'SH'
#!/usr/bin/env bash
printf 'call\n' >> "$CALL_LOG"
SH
chmod +x "$work/bin/claude"
export PATH="$work/bin:$PATH"
cat > "$work/bin/npx" <<'SH'
#!/usr/bin/env bash
printf 'call\n' >> "$CALL_LOG"
SH
chmod +x "$work/bin/npx"

export SKIP_CLAUDE_CODE=1 SKIP_SKILLS=1 SKIP_PLUGINS=1
run_skills_stage "$repo/manifests/skills.txt"
run_plugins_stage "$repo/manifests/plugins.txt"
mock_claude_stage() { printf 'call\n' >> "$CALL_LOG"; }
run_optional_stage SKIP_CLAUDE_CODE 'claude skipped' mock_claude_stage
[[ ! -e "$CALL_LOG" ]]
unset SKIP_CLAUDE_CODE SKIP_SKILLS SKIP_PLUGINS
run_optional_stage SKIP_CLAUDE_CODE 'claude skipped' mock_claude_stage
[[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" == 1 ]]
rm -f "$CALL_LOG"

for invalid in \
    'owner/market valid@market user extra' \
    'owner/market valid@market system' \
    'owner/market valid@market USER' \
    'owner/market invalid user'; do
    printf '%s\n%s\n' 'owner/market valid@market user' "$invalid" > "$work/plugins-invalid.txt"
    INSTALL_FAILURES=""
    run_plugins_stage "$work/plugins-invalid.txt"
    [[ -n "$INSTALL_FAILURES" ]]
done
[[ ! -e "$CALL_LOG" ]]

printf '%s\n' 'owner/repo@skill' 'invalid skill' > "$work/skills-invalid.txt"
INSTALL_FAILURES=""
run_skills_stage "$work/skills-invalid.txt"
[[ ! -e "$CALL_LOG" ]]
if output="$(finish_install)"; then echo 'stage failure returned success' >&2; exit 1; fi
[[ "$output" != *'==> Done!'* ]]

printf '%s\n' 'owner/market valid@market local' > "$work/plugins-valid.txt"
restore_claude_plugins "$work/plugins-valid.txt"
[[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" == 2 ]]
cat > "$work/bin/claude" <<'SH'
#!/usr/bin/env bash
exit 7
SH
if restore_claude_plugins "$work/plugins-valid.txt"; then echo 'claude failure swallowed' >&2; exit 1; fi

original_manifest_lines="$(declare -f manifest_lines)"
manifest_lines() {
    printf '%s\n' 'owner/market valid@market user'
    if [[ ! -e "$work/read-once" ]]; then : > "$work/read-once"; else printf '%s\n' 'owner/market invalid user'; fi
}
rm -f "$CALL_LOG"
cat > "$work/bin/claude" <<'SH'
#!/usr/bin/env bash
printf 'call\n' >> "$CALL_LOG"
SH
restore_claude_plugins ignored
[[ "$(wc -l < "$CALL_LOG" | tr -d ' ')" == 2 ]]
eval "$original_manifest_lines"

manifest_lines() { return 7; }
if validate_plugin_manifest ignored || restore_claude_plugins ignored || restore_claude_skills ignored; then
    echo 'manifest read error swallowed' >&2
    exit 1
fi
eval "$original_manifest_lines"

cat > "$work/bin/npx" <<'SH'
#!/usr/bin/env bash
exit 7
SH
chmod +x "$work/bin/npx"
printf '%s\n' 'owner/repo@skill' > "$work/skills.txt"
if restore_claude_skills "$work/skills.txt"; then echo 'npx failure swallowed' >&2; exit 1; fi

echo 'install failure contract checks passed'
