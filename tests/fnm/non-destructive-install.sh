#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_ROOT="$(mktemp -d)"
export HOME="$TEST_ROOT/home"
export FNM_DIR="$HOME/custom-fnm"
export FNM_CALL_LOG="$TEST_ROOT/fnm-calls"
export DOTFILES_FUNCTIONS_ONLY=1
mkdir -p "$HOME/bin" "$FNM_DIR/node-versions/v18.20.0/installation/bin" \
    "$FNM_DIR/node-versions/v22.18.0/installation/bin" "$FNM_DIR/aliases" \
    "$HOME/.claude" "$HOME/.local/bin"

cat > "$HOME/bin/fnm" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$FNM_CALL_LOG"
case "$1" in
    env) printf 'export PATH=%q:$PATH\n' "$FNM_DIR/aliases/default/bin" ;;
    current) echo v22.18.0 ;;
    ls) printf '* v22.18.0 default\n  v18.20.0\n' ;;
esac
EOF
chmod +x "$HOME/bin/fnm"
for version in v18.20.0 v22.18.0; do
    for bin in node npm npx; do
        printf '#!/usr/bin/env bash\n[[ %s == node ]] && echo %s\n' "$bin" "$version" \
            > "$FNM_DIR/node-versions/$version/installation/bin/$bin"
        chmod +x "$FNM_DIR/node-versions/$version/installation/bin/$bin"
    done
done
mkdir -p "$FNM_DIR/node-versions/v18.20.0/installation/lib/node_modules/sentinel"
ln -s "$FNM_DIR/node-versions/v22.18.0/installation" "$FNM_DIR/aliases/default"
ln -s "$FNM_DIR/aliases/default/node" "$HOME/.local/bin/node"
ln -s "$TEST_ROOT/user-owned-npm" "$HOME/.local/bin/npm"
printf '#!/usr/bin/env bash\n' > "$HOME/.local/bin/npx"
chmod +x "$HOME/.local/bin/npx"
cat > "$HOME/.claude/settings.json" <<EOF
{"statusLine":{"command":"$FNM_DIR/node-versions/v18.20.0/installation/node /mock/hud"}}
EOF

export PATH="$HOME/bin:$PATH"
# shellcheck source=/dev/null
source "$ROOT/install.sh"
trap 'rm -rf "$TEST_ROOT"' EXIT

output="$(install_node_lts)"
if grep -q '^uninstall ' "$FNM_CALL_LOG"; then
    echo "default install pruned a Node version" >&2
    exit 1
fi
prune_node_versions
if grep -q '^uninstall ' "$FNM_CALL_LOG"; then
    echo "unguarded prune helper removed a Node version" >&2
    exit 1
fi
test -d "$FNM_DIR/node-versions/v18.20.0/installation/lib/node_modules/sentinel"
test "$(readlink "$HOME/.local/bin/node")" = "$FNM_DIR/aliases/default/bin/node"
test "$(readlink "$HOME/.local/bin/npm")" = "$TEST_ROOT/user-owned-npm"
test ! -L "$HOME/.local/bin/npx"
test -x "$HOME/.local/bin/node"
grep -Fq "Patched statusLine node path" <<<"$output"
jq -e --arg expected "$FNM_DIR/node-versions/v22.18.0/installation/bin/node /mock/hud" \
    '.statusLine.command == $expected' "$HOME/.claude/settings.json" >/dev/null

rm "$HOME/.local/bin/npm" "$HOME/.local/bin/npx"
link_fnm_default_bins >/dev/null
test -x "$HOME/.local/bin/npm"
test -x "$HOME/.local/bin/npx"

cp "$HOME/.claude/settings.json" "$TEST_ROOT/settings.before"
status_output="$(update_fnm_statusline v22.18.0)"
test -z "$status_output"
cmp -s "$TEST_ROOT/settings.before" "$HOME/.claude/settings.json"

status_output="$(update_fnm_statusline v99.0.0)"
test -z "$status_output"
cmp -s "$TEST_ROOT/settings.before" "$HOME/.claude/settings.json"

printf '{invalid\n' > "$HOME/.claude/settings.json"
cp "$HOME/.claude/settings.json" "$TEST_ROOT/malformed.before"
status_output="$(update_fnm_statusline v22.18.0)"
test -z "$status_output"
cmp -s "$TEST_ROOT/malformed.before" "$HOME/.claude/settings.json"
printf '[]\n' > "$HOME/.claude/settings.json"
cp "$HOME/.claude/settings.json" "$TEST_ROOT/non-object.before"
status_output="$(update_fnm_statusline v22.18.0)"
test -z "$status_output"
cmp -s "$TEST_ROOT/non-object.before" "$HOME/.claude/settings.json"

export DOTFILES_PRUNE_NODE_VERSIONS=1
install_node_lts >/dev/null
grep -q '^uninstall v18.20.0$' "$FNM_CALL_LOG"
echo "PASS: fnm install preserves versions and user-owned links by default"
