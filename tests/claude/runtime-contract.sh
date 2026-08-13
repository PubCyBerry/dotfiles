#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

jq -e '
  ((.env // {} | has("CLAUDE_CODE_SUBAGENT_MODEL")) | not) and
  ([ (.hooks // {}) | .. | strings | select(test("caveman"; "i")) ] | length == 0)
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
  .[0].hookSpecificOutput.hookEventName == "SessionStart" and
  (.[0].hookSpecificOutput.additionalContext | test("^Current date/time: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}$")) and
  (.[0] | has("suppressOutput") | not) and
  (.[0] | has("currentDateTime") | not)
' "$output_file" >/dev/null

echo "Claude runtime contract: PASS"
