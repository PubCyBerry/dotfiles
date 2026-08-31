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

# statusline: settings.json이 부르는 명령과 이 저장소가 배포하는 파일 이름이 어긋나면 statusline이
# 조용히 죽는다. hook의 event 대조와 같은 종류의 회귀라 두 값을 직접 맞춰 본다.
statusline_cmd="$(jq -r '.statusLine.command' "$repo_root/config/claude/settings.json")"
test "$statusline_cmd" = "bash ~/.claude/statusline.sh"
# 실행 권한은 저장소가 아니라 install이 준다(hook 스크립트와 같다 — Windows는 fileMode=false라
# 저장소 mode를 신뢰할 수 없다). 여기서는 파일의 존재만 본다.
test -f "$repo_root/config/claude/statusline.sh"

# wrapper 계약 두 가지: (1) claude-hud가 없어도 경로는 반드시 나온다 — 없으면 애초에 이 wrapper를
# 둘 이유가 없다. (2) 컨텍스트(🧠)는 한 번만 나온다 — ccusage 쪽을 걷어내는 것이 그 장치다.
# HOME을 빈 임시 디렉터리로 두어 플러그인을 못 찾는 상태(첫 설치, node 부재, 사용자가 삭제)를 만든다.
statusline_home="$(mktemp -d)"
trap 'rm -f "$output_file"; rm -rf "$statusline_home"' EXIT
# 실제 ccusage는 사용자 데이터에 따라 출력이 달라진다. 잘라내기 계약만 봐야 하므로 모양이 같은
# 가짜를 PATH 앞에 세운다.
mkdir -p "$statusline_home/bin"
cat > "$statusline_home/bin/ccusage" <<'FAKE'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '🤖 Opus 5 | 💰 $1.00 session / $1.00 today / $1.00 block (4h left) | 🔥 $2.00/hr | 🧠 114,498 (11%)'
FAKE
chmod +x "$statusline_home/bin/ccusage"
HOME="$statusline_home" PATH="$statusline_home/bin:$PATH" \
  bash "$repo_root/config/claude/statusline.sh" >"$output_file" <<'JSON'
{"hook_event_name":"Status","session_id":"contract","transcript_path":"","cwd":"/dotfiles-statusline-contract","model":{"id":"claude-opus-5","display_name":"Opus 5"},"workspace":{"current_dir":"/dotfiles-statusline-contract","project_dir":"/dotfiles-statusline-contract"},"version":"2.0.0"}
JSON
grep -q '/dotfiles-statusline-contract' "$output_file"
grep -q '2.00/hr' "$output_file"
test "$(grep -c '🧠' "$output_file" || true)" -eq 0

# Antigravity는 PreInvocation이라 이미 턴 단위다. %Z는 Git Bash에서 빈 값이 되므로 %z를 요구한다.
bash "$repo_root/config/agy/hooks/temporal-context.sh" >"$output_file"
jq -e '
  (.injectSteps | length) == 1 and
  (.injectSteps[0].ephemeralMessage | test("[+-][0-9]{4}$"))
' "$output_file" >/dev/null

echo "Claude runtime contract: PASS"
