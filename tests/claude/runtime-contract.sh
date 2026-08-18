#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

jq -e '
  ((.env // {} | has("CLAUDE_CODE_SUBAGENT_MODEL")) | not) and
  ([ (.hooks // {}) | .. | strings | select(test("caveman"; "i")) ] | length == 0) and
  ((.hooks // {}) | keys) == ["UserPromptSubmit"]
' \
  "$repo_root/config/claude/settings.json" >/dev/null

jq -e -f "$repo_root/scripts/merge-json-registry.jq" <<'JSON' | jq -e '
  (.env | has("CLAUDE_CODE_SUBAGENT_MODEL") | not) and
  .env.USER_SENTINEL == "keep" and .env.REPO_VALUE == "1" and
  .hooks.UserPromptSubmit[0].hooks[0].command == "user-hook-sentinel"
' >/dev/null
[
  {
    "env": {"CLAUDE_CODE_SUBAGENT_MODEL": "haiku", "USER_SENTINEL": "keep"},
    "hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "user-hook-sentinel"}]}]}
  },
  {"env": {"REPO_VALUE": "1"}}
]
JSON

role_models="$(yq eval-all -N -r 'select(.model != null) | .model' \
  "$repo_root/config/agents/roles/planner/claude.frontmatter" \
  "$repo_root/config/agents/roles/generator/claude.frontmatter" \
  "$repo_root/config/agents/roles/evaluator/claude.frontmatter")"
test "$role_models" = $'opus\nopus\nopus'

bash "$repo_root/config/claude/hooks/temporal-context.sh" >"$output_file"
test "$(wc -l <"$output_file")" -eq 1
jq -e -s '
  length == 1 and
  .[0].hookSpecificOutput.hookEventName == "UserPromptSubmit" and
  (.[0].hookSpecificOutput.additionalContext | test("^Current date/time: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}$")) and
  (.[0] | has("suppressOutput") | not) and
  (.[0] | has("currentDateTime") | not)
' "$output_file" >/dev/null

# 스크립트가 보고하는 event와 settings.json이 등록한 event가 어긋나면 host가 출력을 버린다.
# 이 저장소가 실제로 겪은 회귀라 두 값을 직접 대조한다.
script_event="$(jq -r '.hookSpecificOutput.hookEventName' "$output_file")"
registry_event="$(jq -r '.hooks | keys[0]' "$repo_root/config/claude/settings.json")"
test "$script_event" = "$registry_event"

# Codex도 같은 wire 계약(UserPromptSubmitHookSpecificOutputWire)을 쓴다.
bash "$repo_root/config/codex/hooks/temporal-context.sh" >"$output_file"
jq -e -s '
  length == 1 and .[0].hookSpecificOutput.hookEventName == "UserPromptSubmit"
' "$output_file" >/dev/null
test "$(jq -r '.hooks | keys[0]' "$repo_root/config/codex/hooks.json")" = "UserPromptSubmit"

# Antigravity는 PreInvocation이라 이미 턴 단위다. %Z는 Git Bash에서 빈 값이 되므로 %z를 요구한다.
bash "$repo_root/config/agy/hooks/temporal-context.sh" >"$output_file"
jq -e '
  (.injectSteps | length) == 1 and
  (.injectSteps[0].ephemeralMessage | test("[+-][0-9]{4}$"))
' "$output_file" >/dev/null

echo "Claude runtime contract: PASS"
