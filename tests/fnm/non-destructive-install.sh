#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# 이 테스트는 fnm alias/`~/.local/bin` 링크를 다루므로 진짜 symlink가 필요하다.
# Git Bash는 개발자 모드나 관리자 권한이 없으면 `ln -s`를 복사로 처리해, 검증 대상이
# 아예 만들어지지 않는다. 그 상태를 회귀로 오인하지 않도록 능력을 직접 재고 건너뛴다.
_symlink_probe="$(mktemp -d)"
: > "$_symlink_probe/target"
ln -s "$_symlink_probe/target" "$_symlink_probe/link" 2>/dev/null || true
if [[ ! -L "$_symlink_probe/link" ]]; then
    rm -rf "$_symlink_probe"
    echo 'fnm non-destructive install: SKIP (symlinks unavailable in this shell)'
    exit 0
fi
rm -rf "$_symlink_probe"

TEST_ROOT="$(mktemp -d)"; command -v cygpath >/dev/null 2>&1 && TEST_ROOT="$(cygpath -m "$TEST_ROOT")"
export HOME="$TEST_ROOT/home"
export FNM_DIR="$HOME/custom-fnm"
export FNM_CALL_LOG="$TEST_ROOT/fnm-calls"
export DOTFILES_FUNCTIONS_ONLY=1
export DOTFILES_RECEIPT_PATH="$TEST_ROOT/state/install-receipt.json"
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
touch "$TEST_ROOT/user-owned-npm"
ln -s "$FNM_DIR/node-versions/v22.18.0/installation" "$FNM_DIR/aliases/default"

# ~/.local/bin의 링크는 세 가지 상태를 함께 세운다. install이 이 셋을 다르게 다뤄야 한다.
#
#   node : 구 레이아웃(aliases/default/<bin>)을 가리키는 "끊어진" 링크.
#          그 자리에 파일을 만들지 않아 일부러 dangling으로 둔다. 이것만 인수해서
#          현재 레이아웃(aliases/default/bin/<bin>)으로 다시 건다.
#   npm  : 전혀 다른 곳을 가리키는 "살아 있는" 링크 = 사용자 소유. 보존해야 한다.
#   npx  : symlink가 아닌 일반 파일. 역시 사용자 소유라 보존해야 한다.
#
# 살아 있는 링크를 인수하지 않는 것이 핵심이다. receipt에 없는 멀쩡한 링크는 남의
# 것이므로 판정이 서지 않고, 그때는 보존한다(Safe-Clean-Install).
ln -s "$FNM_DIR/aliases/default/node" "$HOME/.local/bin/node"
ln -s "$TEST_ROOT/user-owned-npm" "$HOME/.local/bin/npm"
printf '#!/usr/bin/env bash\n' > "$HOME/.local/bin/npx"
chmod +x "$HOME/.local/bin/npx"
cat > "$HOME/.claude/settings.json" <<EOF
{"statusLine":{"command":"$FNM_DIR/node-versions/v18.20.0/installation/node /mock/hud"}}
EOF

# PATH 항목만은 POSIX 형태여야 한다. Git Bash에서는 위의 `cygpath -m`이 TEST_ROOT를
# `C:/...`로 바꿔 두는데, MSYS bash는 그런 항목에서 명령을 찾지 않는다. 그대로 두면
# 아래 fnm 스텁이 해석되지 않고 머신에 설치된 진짜 fnm이 불려 테스트가 무의미해진다.
FNM_STUB_BIN="$HOME/bin"
command -v cygpath >/dev/null 2>&1 && FNM_STUB_BIN="$(cygpath -u "$FNM_STUB_BIN")"
export PATH="$FNM_STUB_BIN:$PATH"
# shellcheck source=/dev/null
source "$ROOT/install.sh"
trap 'rm -rf "$TEST_ROOT"' EXIT
receipt_init

# 실패 지점을 말해 준다. 맨 `test`만 두면 `set -e`가 조용히 죽어서 CI 로그로는
# 어느 단언이 깨졌는지 알 수 없다.
fail() { echo "FAIL: $*" >&2; exit 1; }

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
test -d "$FNM_DIR/node-versions/v18.20.0/installation/lib/node_modules/sentinel" \
    || fail 'inactive Node version lost its global packages'
test "$(readlink "$HOME/.local/bin/node")" = "$FNM_DIR/aliases/default/bin/node" \
    || fail "dangling legacy link not migrated: $(readlink "$HOME/.local/bin/node")"
test "$(readlink "$HOME/.local/bin/npm")" = "$TEST_ROOT/user-owned-npm" \
    || fail "live user-owned symlink was taken over: $(readlink "$HOME/.local/bin/npm")"
test ! -L "$HOME/.local/bin/npx" || fail 'user-owned regular file was replaced by a symlink'
test -x "$HOME/.local/bin/node" || fail 'migrated node link is not executable'
grep -Fq "Patched statusLine node path" <<<"$output" || fail 'statusLine patch not reported'
jq -e --arg expected "$FNM_DIR/node-versions/v22.18.0/installation/bin/node /mock/hud" \
    '.statusLine.command == $expected' "$HOME/.claude/settings.json" >/dev/null \
    || fail 'statusLine was not repointed to the active Node'

rm "$HOME/.local/bin/npm" "$HOME/.local/bin/npx"
link_fnm_default_bins >/dev/null
test -x "$HOME/.local/bin/npm" || fail 'npm link not recreated after removal'
test -x "$HOME/.local/bin/npx" || fail 'npx link not recreated after removal'

cp "$HOME/.claude/settings.json" "$TEST_ROOT/settings.before"
status_output="$(update_fnm_statusline v22.18.0)"
[[ -z "$status_output" ]] || fail "no-op statusLine update reported work: $status_output"
cmp -s "$TEST_ROOT/settings.before" "$HOME/.claude/settings.json" || fail 'no-op statusLine update rewrote settings'

status_output="$(update_fnm_statusline v99.0.0)"
[[ -z "$status_output" ]] || fail "missing Node version reported work: $status_output"
cmp -s "$TEST_ROOT/settings.before" "$HOME/.claude/settings.json" || fail 'missing Node version rewrote settings'

printf '{invalid\n' > "$HOME/.claude/settings.json"
cp "$HOME/.claude/settings.json" "$TEST_ROOT/malformed.before"
status_output="$(update_fnm_statusline v22.18.0)"
[[ -z "$status_output" ]] || fail "malformed settings reported work: $status_output"
cmp -s "$TEST_ROOT/malformed.before" "$HOME/.claude/settings.json" || fail 'malformed settings were rewritten'
printf '[]\n' > "$HOME/.claude/settings.json"
cp "$HOME/.claude/settings.json" "$TEST_ROOT/non-object.before"
status_output="$(update_fnm_statusline v22.18.0)"
[[ -z "$status_output" ]] || fail "non-object settings reported work: $status_output"
cmp -s "$TEST_ROOT/non-object.before" "$HOME/.claude/settings.json" || fail 'non-object settings were rewritten'

export DOTFILES_PRUNE_NODE_VERSIONS=1
install_node_lts >/dev/null
grep -q '^uninstall v18.20.0$' "$FNM_CALL_LOG" || fail 'opt-in prune did not remove the inactive version'
echo "PASS: fnm install preserves versions and user-owned links by default"
