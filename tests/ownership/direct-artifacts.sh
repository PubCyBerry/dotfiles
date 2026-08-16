#!/usr/bin/env bash
# shellcheck disable=SC2016
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; SOCKET_PID=""; trap '[[ -z "$SOCKET_PID" ]] || kill "$SOCKET_PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT
export HOME="$TMP/home" DOTFILES_RECEIPT_PATH="$TMP/state/install-receipt.json" DOTFILES_FUNCTIONS_ONLY=1
mkdir -p "$HOME" "$TMP/bin"; export PATH="$TMP/bin:$PATH"
source "$ROOT/install.sh"
receipt_init
fail() { echo "direct artifacts: FAIL: $*" >&2; exit 1; }

npm() { return 42; }
if query_claude_npm_package || [[ "$CLAUDE_QUERY_STATE" != error ]]; then fail npm-query-transient; fi
npm() { printf '%s\n' "$TMP/npm-root"; }
if ! query_claude_npm_package || [[ "$CLAUDE_QUERY_STATE" != absent ]]; then fail npm-query-absent; fi
mkdir -p "$TMP/npm-root/@anthropic-ai/claude-code"; printf '{invalid\n' > "$TMP/npm-root/@anthropic-ai/claude-code/package.json"
if query_claude_npm_package || [[ "$CLAUDE_QUERY_STATE" != error ]]; then fail npm-query-invalid; fi
printf '{"version":"1.2.3"}\n' > "$TMP/npm-root/@anthropic-ai/claude-code/package.json"
if ! query_claude_npm_package || [[ "$CLAUDE_QUERY_STATE" != present || "$CLAUDE_QUERY_VERSION" != 1.2.3 ]]; then fail npm-query-present; fi
unset -f npm

brew() { return 42; }
if query_claude_cask || [[ "$CLAUDE_QUERY_STATE" != error ]]; then fail cask-query-transient; fi
brew() { [[ "$*" == 'list --cask' ]] && return 0; return 1; }
if ! query_claude_cask || [[ "$CLAUDE_QUERY_STATE" != absent ]]; then fail cask-query-absent; fi
unset -f brew

query_transient() { CLAUDE_QUERY_STATE=error; CLAUDE_QUERY_VERSION=""; return 1; }
query_absent() { CLAUDE_QUERY_STATE=absent; CLAUDE_QUERY_VERSION=""; return 0; }
query_present() { CLAUDE_QUERY_STATE=present; CLAUDE_QUERY_VERSION=2.0.0; return 0; }
for package in npm:sequence cask:sequence; do
  begin_managed_package "$package" false ""
  if complete_managed_claude_package "$package" query_transient false "" 9 true; then fail "$package-partial-accepted"; fi
  jq -e --arg name "$package" '.packages[$name].pending != null' "$RECEIPT_PATH" >/dev/null || fail "$package-partial-journal"
  reconcile_pending_claude_package "$package" query_present true || fail "$package-retry"
  jq -e --arg name "$package" '.packages[$name].installed == "2.0.0" and (.packages[$name] | has("pending") | not)' "$RECEIPT_PATH" >/dev/null || fail "$package-retry-journal"
done
begin_managed_package npm:test false ""
! reconcile_pending_claude_package npm:test query_transient false || fail pending-query-transient-accepted
jq -e '.packages["npm:test"].pending != null' "$RECEIPT_PATH" >/dev/null || fail pending-query-transient-journal
reconcile_pending_claude_package npm:test query_absent false || fail pending-query-absent
jq -e '.packages | has("npm:test") | not' "$RECEIPT_PATH" >/dev/null || fail pending-query-absent-journal
begin_managed_package cask:test false ""
! reconcile_pending_claude_package cask:test query_absent true || fail pending-command-mutation-accepted
jq -e '.packages["cask:test"].pending != null' "$RECEIPT_PATH" >/dev/null || fail pending-command-mutation-journal
cancel_managed_package cask:test

validate_direct_manifest "$ROOT/manifests/direct-artifacts.tsv" || fail manifest-valid
cp "$ROOT/manifests/direct-artifacts.tsv" "$TMP/invalid.tsv"; printf 'evil\t1.0.0\tamd64\tbin\thttps://github.com/x/y/releases/latest/x\t%064d\textra\n' 0 >> "$TMP/invalid.tsv"
! validate_direct_manifest "$TMP/invalid.tsv" || fail manifest-invalid-row

printf good > "$TMP/source"
expected="$(file_hash "$TMP/source")"
curl() { local i out; for ((i=1;i<=$#;i++)); do [[ "${!i}" == -o ]] && { i=$((i+1)); out="${!i}"; cp "$TMP/source" "$out"; return; }; done; return 1; }
download_verified fixture "$expected" "$TMP/good" || fail checksum-good
[[ "$(cat "$TMP/good")" == good ]] || fail checksum-good-content
printf keep > "$TMP/destination"
receipt_before="$(file_hash "$RECEIPT_PATH")"
! download_verified fixture bad "$TMP/destination" || fail checksum-mismatch-accepted
[[ "$(cat "$TMP/destination")" == keep && "$(file_hash "$RECEIPT_PATH")" == "$receipt_before" ]] || fail checksum-mismatch-mutated

mkdir -p "$TMP/targets"; printf x > "$TMP/targets/a"; chmod +x "$TMP/targets/a"
if ln -s "$TMP/targets/a" "$TMP/symlink-probe" 2>/dev/null && [[ -L "$TMP/symlink-probe" ]]; then
rm -f "$TMP/symlink-probe"
install_managed_symlink "$TMP/bin/a" "$TMP/targets/a" || fail symlink-fresh
[[ "$(command readlink "$TMP/bin/a")" == "$TMP/targets/a" ]] || fail symlink-target
ln -s "$TMP/targets/user" "$TMP/bin/user"
! install_managed_symlink "$TMP/bin/user" "$TMP/targets/a" || fail symlink-unowned
ln -s "$TMP/targets/missing" "$TMP/bin/dangling"
! install_managed_symlink "$TMP/bin/dangling" "$TMP/targets/a" || fail symlink-dangling
ln -s "$TMP/targets/legacy" "$TMP/bin/legacy"
install_managed_symlink "$TMP/bin/legacy" "$TMP/targets/a" "$TMP/targets/legacy" || fail symlink-legacy
ln -sfn "$TMP/targets/user-edit" "$TMP/bin/a"
! install_managed_symlink "$TMP/bin/a" "$TMP/targets/a" || fail symlink-modified

pending="$TMP/bin/pending"
receipt_commit --arg path "$pending" --arg target "$TMP/targets/a" '.artifacts[$path]={before:{exists:false,type:"missing",target:null},installedTarget:null,pending:true,targetTarget:$target,previousExists:false,previousType:"missing",previousTarget:null}'
ln -s "$TMP/targets/a" "$pending"
install_managed_symlink "$pending" "$TMP/targets/a" || fail symlink-pending
jq -e --arg path "$pending" '.artifacts[$path].pending == false and .artifacts[$path].installedTarget != null' "$RECEIPT_PATH" >/dev/null || fail symlink-pending-receipt
else
echo '    symlink assertions skipped: platform did not create a real symlink'
fi

printf v1 > "$TMP/v1"; install_managed_file "$TMP/v1" "$TMP/bin/tool" skip; record_direct_version "$TMP/bin/tool" 1
direct_anchor_state "$TMP/bin/tool" 2; [[ "$DIRECT_STATE" == upgrade-blocked ]] || fail upgrade-gate
DOTFILES_UPGRADE_DIRECT=1 direct_anchor_state "$TMP/bin/tool" 2; [[ "$DIRECT_STATE" == upgrade ]] || fail upgrade-opt-in
printf tampered > "$TMP/bin/tool"
direct_anchor_state "$TMP/bin/tool" 2; [[ "$DIRECT_STATE" == modified ]] || fail tampered-before-upgrade-gate
DOTFILES_UPGRADE_DIRECT=1 direct_anchor_state "$TMP/bin/tool" 2; [[ "$DIRECT_STATE" == modified ]] || fail tampered-upgrade-opt-in

mkdir "$TMP/tree-src"; printf tree > "$TMP/tree-src/file"
base_tree_hash="$(tree_hash "$TMP/tree-src")"
if [[ "$(uname -s)" != MINGW* ]]; then
  base_tree_mode="$(stat -c '%a' "$TMP/tree-src")"; chmod 711 "$TMP/tree-src"
  [[ "$(tree_hash "$TMP/tree-src")" != "$base_tree_hash" ]] || fail tree-root-mode-identity
  chmod "$base_tree_mode" "$TMP/tree-src"
fi
mkfifo "$TMP/tree-src/extra.fifo"
[[ "$(tree_hash "$TMP/tree-src")" != "$base_tree_hash" ]] || fail tree-fifo-identity
rm "$TMP/tree-src/extra.fifo"
if command -v ruby >/dev/null 2>&1; then
  ruby -rsocket -e 'server=UNIXServer.new(ARGV[0]); sleep 30' "$TMP/tree-src/extra.sock" & SOCKET_PID=$!
  for _ in 1 2 3 4 5; do [[ -S "$TMP/tree-src/extra.sock" ]] && break; sleep 1; done
  [[ -S "$TMP/tree-src/extra.sock" && "$(tree_hash "$TMP/tree-src")" != "$base_tree_hash" ]] || fail tree-socket-identity
  kill "$SOCKET_PID"; wait "$SOCKET_PID" 2>/dev/null || true; SOCKET_PID=""; rm -f "$TMP/tree-src/extra.sock"
fi
install_managed_direct_tree "$TMP/tree-src" "$TMP/tree" 1 || fail tree-fresh
install_managed_direct_tree "$TMP/tree-src" "$TMP/tree" 1 || fail tree-finalized-noop
tree_target="$(tree_hash "$TMP/tree")"
receipt_commit --arg path "$TMP/tree" --arg hash "$tree_target" '.artifacts[$path].installedTreeHash=null | .artifacts[$path].pending=true | .artifacts[$path].targetTreeHash=$hash'
install_managed_direct_tree "$TMP/tree-src" "$TMP/tree" 1 || fail tree-pending
printf changed > "$TMP/tree/file"
! install_managed_direct_tree "$TMP/tree-src" "$TMP/tree" 1 || fail tree-modified
mkdir "$TMP/tree-retry-src"; printf retry > "$TMP/tree-retry-src/file"
retry_hash="$(tree_hash "$TMP/tree-retry-src")"; retry_dst="$TMP/tree-retry"
receipt_commit --arg path "$retry_dst" --arg hash "$retry_hash" '.artifacts[$path]={before:{exists:false,type:"missing"},installedTreeHash:null,pending:true,targetTreeHash:$hash,previousExists:false}'
printf drift > "$TMP/tree-retry-src/file"
! install_managed_direct_tree "$TMP/tree-retry-src" "$retry_dst" 1 || fail tree-pending-target-change
[[ ! -e "$retry_dst" ]] || fail tree-pending-target-change-mutated
printf retry > "$TMP/tree-retry-src/file"
install_managed_direct_tree "$TMP/tree-retry-src" "$retry_dst" 1 || fail tree-pre-mutation-retry
[[ "$(cat "$retry_dst/file")" == retry ]] || fail tree-pre-mutation-content
! find "$retry_dst" -mindepth 1 -name '.dotfiles-tree.*' -print -quit | grep -q . || fail tree-temp-nested
mkdir "$TMP/tree-user"; printf user > "$TMP/tree-user/user"
! install_managed_direct_tree "$TMP/tree-src" "$TMP/tree-user" 1 || fail tree-unowned-collision
[[ "$(cat "$TMP/tree-user/user")" == user ]] || fail tree-unowned-collision-mutated

# 원격 스크립트 실행과 unpinned 경로 금지. 예외는 herdr 하나뿐이다 — Windows stable
# 릴리즈에 바이너리가 없어 pin할 semver가 존재하지 않고, herdr가 자체 업데이터로
# 바이너리를 교체하므로 receipt로 해시를 잡으면 그 다음 실행부터 굳는다.
# 근거는 AGENTS.md "herdr 관리"에 있다.
#
# 예외는 herdr installer를 직접 가리키는 줄로만 한정한다. 다른 도구가 같은 패턴을
# 들여오면 그대로 실패한다. [scriptblock]::Create는 이 예외가 생기면서 함께 막는다 —
# 내려받은 문자열을 실행하는 우회 경로이기 때문이다 (bare Invoke-Expression은
# `fnm env` 출력 평가 같은 로컬 용도라 여기서 다루지 않는다).
#
# 면제 패턴은 herdr URL을 담은 변수명과 호스트로만 좁힌다. 단순히 "herdr"라는 단어가
# 줄 어딘가에 있으면 통과시키면, 무관한 도구를 같은 줄 주석 한 마디로 들여올 수 있다.
remote_hits="$(rg -n 'curl.*\|.*(sh|bash)|/latest/|/HEAD/|/main/|Invoke-RestMethod.*Invoke-Expression|scriptblock\]::Create' \
    "$ROOT/install.sh" "$ROOT/install.ps1" "$ROOT/manifests/direct-artifacts.tsv" || true)"
remote_hits="$(printf '%s' "$remote_hits" | rg -v 'HERDR_INSTALL_URL|HerdrInstallUrl|herdr\.dev' || true)"
[[ -z "$remote_hits" ]] || { printf '%s\n' "$remote_hits" >&2; fail static-remote-path; }
! rg -n '(install|cp|mv|ln).*/usr/local/(bin|share|lib)' "$ROOT/install.sh" || fail static-privileged-direct
grep -Fq 'Begin-ManagedPackage "winget:$claudePackage"' "$ROOT/install.ps1" || fail windows-claude-receipt
grep -Fq 'begin_managed_package npm:@anthropic-ai/claude-code' "$ROOT/install.sh" || fail linux-claude-receipt
grep -Fq 'begin_managed_package cask:claude-code' "$ROOT/install.sh" || fail macos-claude-receipt
echo 'Direct artifacts: PASS'
