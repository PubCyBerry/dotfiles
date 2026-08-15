#!/usr/bin/env bash
# rhwp tree + MCP entry의 소유권 계약을 install/uninstall 양쪽에서 검증한다.
# 네트워크를 타지 않는다 — manifest 검증과 소유권 상태 전이만 다룬다.
# shellcheck disable=SC2016
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; command -v cygpath >/dev/null 2>&1 && TMP="$(cygpath -m "$TMP")"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" TMPDIR="$TMP"
export DOTFILES_FUNCTIONS_ONLY=1
export DOTFILES_RECEIPT_PATH="$TMP/state/install-receipt.json"
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
mkdir -p "$HOME/.codex" "$HOME/.config"

fail() { echo "rhwp mcp: FAIL: $*" >&2; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "rhwp mcp: SKIP (yq unavailable)"; exit 0; }

source "$ROOT/install.sh"
receipt_init || fail receipt-init

# ---------------------------------------------
# manifest 계약
# ---------------------------------------------
MANIFEST="$ROOT/manifests/rhwp.tsv"
validate_rhwp_manifest "$MANIFEST" || fail manifest-valid
[[ "$(awk -F '\t' '$1=="windows-x86_64"{print $2}' "$MANIFEST")" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail manifest-version
# 네 플랫폼이 모두 같은 버전을 가리켜야 한 릴리즈를 pin한 것이 된다.
[[ "$(awk -F '\t' '!/^#/ && NF==5 {print $2}' "$MANIFEST" | sort -u | wc -l)" -eq 1 ]] || fail manifest-single-version

bad="$TMP/bad.tsv"
sed 's|/download/v[0-9.]*/|/download/latest/|' "$MANIFEST" > "$bad"; ! validate_rhwp_manifest "$bad" || fail manifest-latest-url
sed 's/\t[0-9a-f]\{64\}$/\tdeadbeef/' "$MANIFEST" > "$bad"; ! validate_rhwp_manifest "$bad" || fail manifest-short-checksum
grep -v '^macos-aarch64' "$MANIFEST" > "$bad"; ! validate_rhwp_manifest "$bad" || fail manifest-missing-platform
{ cat "$MANIFEST"; awk -F '\t' '$1=="linux-x86_64"' "$MANIFEST"; } > "$bad"; ! validate_rhwp_manifest "$bad" || fail manifest-duplicate-platform

# ---------------------------------------------
# Codex MCP entry: 신규 등록 → 멱등 → 사용자 수정 보존
# ---------------------------------------------
CODEX_CONFIG="$HOME/.codex/config.toml"
printf '[user]\nsentinel = "keep"\n' > "$CODEX_CONFIG"
DESIRED="$(jq -cn --arg cmd "$HOME/rhwp/rhwp" '{command:$cmd,args:["mcp-serve"]}')"
# 저장된 entry는 항상 정규화된 형태로 되읽힌다.
CANONICAL="$(printf '%s' "$DESIRED" | jq -cS '.')"

install_managed_mcp_server codex rhwp "$CODEX_CONFIG" "$DESIRED" || fail codex-register
[[ "$(yq -p=toml -o=json '.mcp_servers.rhwp' "$CODEX_CONFIG" | jq -cS .)" == "$CANONICAL" ]] || fail codex-entry
[[ "$(yq -p=toml -o=json -r '.user.sentinel' "$CODEX_CONFIG")" == keep ]] || fail codex-user-preserved
jq -e --arg k mcp:codex:rhwp '.values[$k].installed != null and (.values[$k].pending|not)' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail codex-receipt

before_hash="$(file_hash "$CODEX_CONFIG")"
install_managed_mcp_server codex rhwp "$CODEX_CONFIG" "$DESIRED" || fail codex-idempotent
[[ "$(file_hash "$CODEX_CONFIG")" == "$before_hash" ]] || fail codex-idempotent-write

# 사용자가 우리 entry를 고쳤으면 덮어쓰지 않는다.
yq -i -p=toml -o=toml '.mcp_servers.rhwp.command = "/user/rhwp"' "$CODEX_CONFIG" 2>/dev/null
! install_managed_mcp_server codex rhwp "$CODEX_CONFIG" "$DESIRED" || fail codex-modified-overwritten
[[ "$(yq -p=toml -o=json -r '.mcp_servers.rhwp.command' "$CODEX_CONFIG")" == /user/rhwp ]] || fail codex-modified-preserve

# ---------------------------------------------
# 사용자가 먼저 만든 동명 entry는 receipt에 없으므로 손대지 않는다.
# ---------------------------------------------
USER_CONFIG="$TMP/user.toml"
printf '[mcp_servers.rhwp]\ncommand = "/opt/user/rhwp"\n' > "$USER_CONFIG"
! install_managed_mcp_server codex rhwp "$USER_CONFIG" "$DESIRED" || fail codex-unowned-taken
[[ "$(yq -p=toml -o=json -r '.mcp_servers.rhwp.command' "$USER_CONFIG")" == /opt/user/rhwp ]] || fail codex-unowned-changed

# ---------------------------------------------
# Claude MCP entry: 파일이 없으면 만들고, 다른 키는 건드리지 않는다.
# ---------------------------------------------
CLAUDE_JSON="$HOME/.claude.json"
install_managed_mcp_server claude rhwp "$CLAUDE_JSON" "$DESIRED" || fail claude-register
[[ "$(jq -cS '.mcpServers.rhwp' "$CLAUDE_JSON")" == "$CANONICAL" ]] || fail claude-entry
jq -n '{"hasCompletedOnboarding":true}' > "$TMP/seed.json"
jq -s '.[0] * .[1]' "$TMP/seed.json" "$CLAUDE_JSON" > "$TMP/merged.json" && mv "$TMP/merged.json" "$CLAUDE_JSON"
# 사용자 키가 붙은 뒤에도 우리 entry는 그대로이므로 재실행이 멱등이다.
install_managed_mcp_server claude rhwp "$CLAUDE_JSON" "$DESIRED" || fail claude-idempotent
jq -e '.hasCompletedOnboarding == true' "$CLAUDE_JSON" >/dev/null || fail claude-user-key-lost

# ---------------------------------------------
# direct tree: 신규 배치 → 멱등 → 사용자 수정 보존
# ---------------------------------------------
SRC_TREE="$TMP/src/rhwp"; mkdir -p "$SRC_TREE"
printf binary > "$SRC_TREE/rhwp"; chmod 755 "$SRC_TREE/rhwp"
printf license > "$SRC_TREE/LICENSE"
install_managed_direct_tree "$SRC_TREE" "$HOME/rhwp" 0.8.4 || fail tree-install
# exec bit을 그대로 옮겼는지까지 본다. 파일시스템이 exec bit을 무시할 수 있으므로
# `-x`가 아니라 원본과의 mode 일치로 확인한다.
[[ -f "$HOME/rhwp/rhwp" && -f "$HOME/rhwp/LICENSE" ]] || fail tree-content
[[ "$(file_mode "$HOME/rhwp/rhwp")" == "$(file_mode "$SRC_TREE/rhwp")" ]] || fail tree-mode
install_managed_direct_tree "$SRC_TREE" "$HOME/rhwp" 0.8.4 || fail tree-idempotent
[[ "$(jq -r --arg p "$HOME/rhwp" '.artifacts[$p].directVersion' "$DOTFILES_RECEIPT_PATH")" == 0.8.4 ]] || fail tree-version
printf user > "$HOME/rhwp/user-note"
! install_managed_direct_tree "$SRC_TREE" "$HOME/rhwp" 0.8.4 || fail tree-modified-overwritten
[[ -f "$HOME/rhwp/user-note" ]] || fail tree-modified-lost

# ---------------------------------------------
# uninstall: 정확히 우리 identity일 때만 되돌린다.
# ---------------------------------------------
unset -f main
source "$ROOT/uninstall.sh"
RECEIPT_PATH="$DOTFILES_RECEIPT_PATH"

# Codex entry가 우리가 심은 값과 다르면 보존한다 (위에서 /user/rhwp로 바꿔 두었다).
! uninstall_value mcp:codex:rhwp || fail codex-uninstall-modified
[[ "$(yq -p=toml -o=json -r '.mcp_servers.rhwp.command' "$CODEX_CONFIG")" == /user/rhwp ]] || fail codex-uninstall-clobbered
jq -e '.values | has("mcp:codex:rhwp")' "$RECEIPT_PATH" >/dev/null || fail codex-receipt-dropped

# 값을 되돌려 놓으면 entry만 제거되고 사용자 테이블은 남는다.
yq -i -p=toml -o=toml ".mcp_servers.rhwp = $DESIRED" "$CODEX_CONFIG" 2>/dev/null
uninstall_value mcp:codex:rhwp || fail codex-uninstall
yq -p=toml -o=json -e '.mcp_servers' "$CODEX_CONFIG" >/dev/null 2>&1 && fail codex-empty-table-left
[[ "$(yq -p=toml -o=json -r '.user.sentinel' "$CODEX_CONFIG")" == keep ]] || fail codex-uninstall-user-lost
jq -e '.values | has("mcp:codex:rhwp") | not' "$RECEIPT_PATH" >/dev/null || fail codex-receipt-kept

# Claude entry 제거 후 다른 키가 있으면 파일을 남긴다.
uninstall_value mcp:claude:rhwp || fail claude-uninstall
[[ -f "$CLAUDE_JSON" ]] || fail claude-json-removed-with-user-keys
jq -e '.mcpServers | has("rhwp") | not' "$CLAUDE_JSON" >/dev/null || fail claude-entry-kept
jq -e '.hasCompletedOnboarding == true' "$CLAUDE_JSON" >/dev/null || fail claude-user-key-lost-on-uninstall

# 우리가 만든 형태 그대로면 파일까지 걷어낸다.
printf '%s' '{"mcpServers":{}}' > "$CLAUDE_JSON"
prune_empty_claude_json
[[ ! -e "$CLAUDE_JSON" ]] || fail claude-json-not-pruned

# ---------------------------------------------
# rhwp tree: 정확한 tree 해시일 때만 제거한다.
# ---------------------------------------------
value_key_allowed mcp:codex:rhwp || fail value-allowlist-codex
value_key_allowed mcp:claude:rhwp || fail value-allowlist-claude
! value_key_allowed mcp:codex:other || fail value-allowlist-open
! value_key_allowed mcp:other:rhwp || fail value-allowlist-host
artifact_allowed "$HOME/rhwp" || fail artifact-allowlist
! artifact_allowed "$HOME/rhwp/rhwp" || fail artifact-allowlist-child

# tree_hash는 GNU find -printf / tar --sort가 없는 BSD(macOS)에서도 성립해야 한다.
# 그 분기를 강제해 안정성·내용 민감도·구조 민감도를 확인한다.
mkdir -p "$TMP/th/sub"; printf a > "$TMP/th/f"; printf b > "$TMP/th/sub/g"
(
  tree_hash_supports_gnu_find() { return 1; }
  base="$(tree_hash "$TMP/th")" || fail tree-hash-bsd-failed
  [[ "$base" =~ ^[0-9a-f]{64}$ ]] || fail tree-hash-bsd-format
  [[ "$base" == "$(tree_hash "$TMP/th")" ]] || fail tree-hash-bsd-unstable
  printf c > "$TMP/th/sub/g"
  [[ "$base" != "$(tree_hash "$TMP/th")" ]] || fail tree-hash-bsd-content-blind
  printf b > "$TMP/th/sub/g"
  mkdir -p "$TMP/th/added"
  [[ "$base" != "$(tree_hash "$TMP/th")" ]] || fail tree-hash-bsd-structure-blind
  rmdir "$TMP/th/added"
  [[ "$base" == "$(tree_hash "$TMP/th")" ]] || fail tree-hash-bsd-not-restored
) || exit 1

# install이 실제로 남긴 receipt를 그대로 쓴다 — 합성 fixture로는 두 스크립트가
# 같은 tree_hash 규칙을 쓰는지 검증되지 않는다.
receipt_schema_valid || fail tree-schema
! uninstall_artifact "$HOME/rhwp" || fail tree-modified-removed
[[ -f "$HOME/rhwp/user-note" ]] || fail tree-modified-lost
rm -f "$HOME/rhwp/user-note"
uninstall_artifact "$HOME/rhwp" || fail tree-remove
[[ ! -e "$HOME/rhwp" ]] || fail tree-left
jq -e --arg p "$HOME/rhwp" '.artifacts | has($p) | not' "$RECEIPT_PATH" >/dev/null || fail tree-receipt-kept

echo 'rhwp mcp ownership bash: PASS'
