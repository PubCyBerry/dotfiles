#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_CONFIG_DIR"

# Claude settings.json
if [[ -f "$DOTFILES_DIR/agents/claude/settings.json" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]] || grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # macOS/Linux: cmd /c npx 형식을 npx 형식으로 패치한 복사본 생성
    cp "$DOTFILES_DIR/agents/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
    python3 - "$CLAUDE_CONFIG_DIR/settings.json" <<'EOF'
import sys, json

path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)

mcp = cfg.get("mcpServers", {})
for name, server in mcp.items():
    # cmd /c npx ... → npx ... 로 변환
    if server.get("command") == "cmd" and server.get("args", [])[:2] == ["/c", "npx"]:
        server["command"] = "npx"
        server["args"] = server["args"][2:]  # "/c", "npx" 제거

with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")

print("    patched MCP commands for macOS/Linux")
EOF
  else
    # Windows (Git Bash 등): 심볼릭 링크 유지
    ln -sf "$DOTFILES_DIR/agents/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
  fi
  echo "    linked settings.json"
fi

# Claude global CLAUDE.md
if [[ -f "$DOTFILES_DIR/agents/claude/CLAUDE.md" ]]; then
  ln -sf "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  echo "    linked CLAUDE.md"
fi

# ccstatusline 설정
CCSTATUSLINE_CONFIG_DIR="$HOME/.config/ccstatusline"
if [[ -f "$DOTFILES_DIR/agents/claude/ccstatusline-settings.json" ]]; then
  mkdir -p "$CCSTATUSLINE_CONFIG_DIR"
  ln -sf "$DOTFILES_DIR/agents/claude/ccstatusline-settings.json" "$CCSTATUSLINE_CONFIG_DIR/settings.json"
  echo "    linked ccstatusline settings.json"
fi

# The Agency 서브에이전트 설치
echo "    Installing subagents (The Agency)..."
bash "$DOTFILES_DIR/agents/restore-agents.sh"

# npx skills 복원
echo "    Restoring skills..."
bash "$DOTFILES_DIR/agents/restore-skills.sh"

echo "    Agent setup complete."
