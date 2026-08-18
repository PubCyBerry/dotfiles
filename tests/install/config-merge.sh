#!/usr/bin/env bash
set -Eeuo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-config-merge.XXXXXX")"
export HOME="$work/home"
export DOTFILES_FUNCTIONS_ONLY=1
source "$repo/install.sh"
unset DOTFILES_FUNCTIONS_ONLY
trap '_cleanup; rm -rf "$work"' EXIT

yq -p=toml -o=json '.' "$repo/config/codex/config.toml" | jq -e '
  (.features | has("js_repl") | not) and
  (.features | has("remote_control") | not) and
  .desktop.followUpQueueMode == "steer"
' >/dev/null

toml_src="$work/source.toml"
toml_dst="$work/destination.toml"
cat > "$toml_src" <<'TOML'
model = "repo-model"
model_reasoning_effort = "xhigh"

[features]
hooks = true

[desktop]
followUpQueueMode = "steer"

[windows]
sandbox = "elevated"
TOML
cat > "$toml_dst" <<'TOML'
model = "user-model"

[features]
hooks = false
user_sentinel = true

[custom]
sentinel = "keep"
TOML

merge_codex_config "$toml_src" "$toml_dst"
yq -p=toml -o=json '.' "$toml_dst" | jq -e '
  .model == "user-model" and
  .model_reasoning_effort == "xhigh" and
  .features.hooks == false and
  (.features | has("js_repl") | not) and
  (.features | has("remote_control") | not) and
  .features.user_sentinel == true and
  .custom.sentinel == "keep" and
  .desktop.followUpQueueMode == "steer" and
  .windows.sandbox == "elevated"
' >/dev/null
cp "$toml_dst" "$work/toml-first"
merge_codex_config "$toml_src" "$toml_dst"
cmp -s "$work/toml-first" "$toml_dst"
[[ "$(awk '/^model[[:space:]]*=/{count++} END{print count+0}' "$toml_dst")" == "1" ]]

section_only_dst="$work/section-only.toml"
printf '[features] # user section\nhooks = false\n' > "$section_only_dst"
merge_codex_config "$toml_src" "$section_only_dst"
yq -p=toml -o=json '.' "$section_only_dst" >/dev/null
[[ "$(awk '/^model[[:space:]]*=/{count++} END{print count+0}' "$section_only_dst")" == "1" ]]
[[ "$(awk '/^\[features\]/{count++} END{print count+0}' "$section_only_dst")" == "1" ]]

array_dst="$work/array-table.toml"
cat > "$array_dst" <<'TOML'
[[mcp_servers]]
name = "user-server"
TOML
merge_codex_config "$toml_src" "$array_dst"
yq -p=toml -o=json '.' "$array_dst" | jq -e '
  .model == "repo-model" and
  .model_reasoning_effort == "xhigh" and
  .mcp_servers[0].name == "user-server"
' >/dev/null

dotted_dst="$work/dotted.toml"
cat > "$dotted_dst" <<'TOML'
model = "user-model"
windows.sandbox = "unelevated"
features.hooks = false
TOML
merge_codex_config "$toml_src" "$dotted_dst"
yq -p=toml -o=json '.' "$dotted_dst" | jq -e '
  .model == "user-model" and
  .windows.sandbox == "unelevated" and
  .features.hooks == false and
  .desktop.followUpQueueMode == "steer"
' >/dev/null
cp "$dotted_dst" "$work/dotted-first"
merge_codex_config "$toml_src" "$dotted_dst"
cmp -s "$work/dotted-first" "$dotted_dst"

invalid_dst="$work/invalid.toml"
printf 'model =' > "$invalid_dst"
cp "$invalid_dst" "$work/invalid-first"
merge_codex_config "$toml_src" "$invalid_dst"
cmp -s "$work/invalid-first" "$invalid_dst"

invalid_src="$work/invalid-source.toml"
source_protected_dst="$work/source-protected.toml"
printf 'model =' > "$invalid_src"
cp "$toml_dst" "$source_protected_dst"
cp "$source_protected_dst" "$work/source-protected-first"
merge_codex_config "$invalid_src" "$source_protected_dst"
cmp -s "$work/source-protected-first" "$source_protected_dst"

no_yq_dst="$work/no-yq.toml"
cp "$toml_dst" "$no_yq_dst"
cp "$no_yq_dst" "$work/no-yq-first"
PATH="$work/no-yq" merge_codex_config "$toml_src" "$no_yq_dst"
cmp -s "$work/no-yq-first" "$no_yq_dst"

claude_src="$work/claude-source.json"
claude_dst="$work/claude-destination.json"
cat > "$claude_src" <<'JSON'
{
  "language": "한국어",
  "env": {"REPO_VALUE": "1", "SHARED": "repo"},
  "permissions": {"allow": ["Bash(repo:*)"]},
  "hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}]}]}
}
JSON
# destination은 event 이동 전에 설치된 머신 상태다: 관리 hook이 SessionStart에 남아 있고
# 사용자 hook이 같은 group에 섞여 있으며, 새 event 쪽에는 중복이 들어 있다.
cat > "$claude_dst" <<'JSON'
{
  "language": "English",
  "statusLine": {"command": "user-sentinel"},
  "env": {"USER_SENTINEL": "keep", "SHARED": "user"},
  "permissions": {"allow": ["Read(*)"]},
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [
      {"type": "command", "command": "user-session-sentinel"},
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}, {"matcher": "legacy-only", "hooks": [
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"},
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "user-event-sentinel"}]}]
  }
}
JSON

merge_json_registry "$claude_src" "$claude_dst"
jq -e '
  .language == "English" and .statusLine.command == "user-sentinel" and
  .env.USER_SENTINEL == "keep" and .env.REPO_VALUE == "1" and .env.SHARED == "user" and
  (.permissions.allow | index("Read(*)")) != null and
  (.permissions.allow | index("Bash(repo:*)")) != null and
  ([.hooks.UserPromptSubmit[].hooks[] | select(.command == "bash ~/.claude/hooks/temporal-context.sh")] | length) == 1 and
  ([.hooks.SessionStart[].hooks[] | select(.command == "bash ~/.claude/hooks/temporal-context.sh")] | length) == 0 and
  ([.hooks.SessionStart[].hooks[] | select(.command == "user-session-sentinel")] | length) == 1 and
  ([.hooks.SessionStart[] | select(.matcher == "legacy-only")] | length) == 0 and
  all(.hooks[][]; (.hooks | length) > 0) and
  .hooks.PreToolUse[0].hooks[0].command == "user-event-sentinel"
' "$claude_dst" >/dev/null
[[ "$LAST_JSON_REGISTRY_DEPLOYED" == true ]] || { echo "FAIL: 병합 성공인데 배포 플래그가 서지 않았습니다." >&2; exit 1; }
cp "$claude_dst" "$work/claude-first"
merge_json_registry "$claude_src" "$claude_dst"
cmp -s "$work/claude-first" "$claude_dst"

# 옛 event에 관리 hook만 있었다면 group과 event key가 통째로 사라져야 한다.
legacy_only_dst="$work/legacy-only.json"
cat > "$legacy_only_dst" <<'JSON'
{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.claude/hooks/temporal-context.sh"}]}]}}
JSON
merge_json_registry "$claude_src" "$legacy_only_dst"
jq -e '(.hooks | has("SessionStart")) | not' "$legacy_only_dst" >/dev/null

invalid_json="$work/invalid.json"
printf '{' > "$invalid_json"
cp "$invalid_json" "$work/invalid-json-first"
merge_json_registry "$claude_src" "$invalid_json"
cmp -s "$work/invalid-json-first" "$invalid_json"
[[ "$LAST_JSON_REGISTRY_DEPLOYED" == false ]] || { echo "FAIL: 병합 실패인데 배포 플래그가 섰습니다." >&2; exit 1; }

codex_src="$work/codex-source.json"
codex_dst="$work/codex-destination.json"
cat > "$codex_src" <<'JSON'
{"hooks":{"UserPromptSubmit":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}]}}
JSON
cat > "$codex_dst" <<'JSON'
{"user":{"sentinel":true},"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"user-codex-sentinel"},{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}],"UserPromptSubmit":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"},{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}]}}
JSON

merge_json_registry "$codex_src" "$codex_dst"
jq -e '
  .user.sentinel == true and
  ([.hooks.SessionStart[].hooks[] | select(.command == "user-codex-sentinel")] | length) == 1 and
  ([.hooks.SessionStart[].hooks[] | select(.command == "bash ~/.codex/hooks/temporal-context.sh")] | length) == 0 and
  ([.hooks.UserPromptSubmit[].hooks[] | select(.command == "bash ~/.codex/hooks/temporal-context.sh")] | length) == 1
' "$codex_dst" >/dev/null
cp "$codex_dst" "$work/codex-first"
merge_json_registry "$codex_src" "$codex_dst"
cmp -s "$work/codex-first" "$codex_dst"

# agy hooks.json은 top-level hooks key가 없어 event 병합/정리 대상이 아니다.
agy_src="$work/agy-source.json"
agy_dst="$work/agy-destination.json"
cat > "$agy_src" <<'JSON'
{"temporal-context":{"PreInvocation":[{"type":"command","command":"bash ~/.gemini/hooks/temporal-context.sh"}]}}
JSON
cat > "$agy_dst" <<'JSON'
{"user-hook":{"PreInvocation":[{"type":"command","command":"user-agy-sentinel"}]}}
JSON
merge_json_registry "$agy_src" "$agy_dst"
jq -e '
  ."user-hook".PreInvocation[0].command == "user-agy-sentinel" and
  ."temporal-context".PreInvocation[0].command == "bash ~/.gemini/hooks/temporal-context.sh" and
  (has("hooks") | not)
' "$agy_dst" >/dev/null

jq empty "$claude_dst" "$codex_dst" "$agy_dst" "$legacy_only_dst"
echo "config merge regression checks passed"
