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
    # Windows (Git Bash): ln -sf는 관리자 권한 없이 실패하므로 cp 사용
    cp "$DOTFILES_DIR/agents/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
  fi
  echo "    copied settings.json"
fi

# Claude global CLAUDE.md
if [[ -f "$DOTFILES_DIR/agents/claude/CLAUDE.md" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]] || grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ln -sf "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  else
    cp "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  fi
  echo "    copied CLAUDE.md"
fi

# claude-hud 설정
CLAUDE_HUD_CONFIG_DIR="$CLAUDE_CONFIG_DIR/plugins/claude-hud"
if [[ -f "$DOTFILES_DIR/agents/claude/claude-hud-config.json" ]]; then
  mkdir -p "$CLAUDE_HUD_CONFIG_DIR"
  if [[ "$OSTYPE" == "darwin"* ]] || grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
    ln -sf "$DOTFILES_DIR/agents/claude/claude-hud-config.json" "$CLAUDE_HUD_CONFIG_DIR/config.json"
  else
    cp "$DOTFILES_DIR/agents/claude/claude-hud-config.json" "$CLAUDE_HUD_CONFIG_DIR/config.json"
  fi
  echo "    copied claude-hud config.json"
  echo "    [!] Install claude-hud: run /plugin install claude-hud in Claude Code"
  echo "    [!] Then run /claude-hud:setup to finalize the statusLine command"
fi

# The Agency 서브에이전트 설치
echo "    Installing subagents (The Agency)..."
bash "$DOTFILES_DIR/agents/restore-agents.sh"

# npx skills 복원
echo "    Restoring skills..."
bash "$DOTFILES_DIR/agents/restore-skills.sh"

echo "    Agent setup complete."
