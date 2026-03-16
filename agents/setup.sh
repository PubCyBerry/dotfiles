#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_CONFIG_DIR"

# Claude settings.json
if [[ -f "$DOTFILES_DIR/agents/claude/settings.json" ]]; then
  ln -sf "$DOTFILES_DIR/agents/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
  echo "    linked settings.json"
fi

# Claude global CLAUDE.md
if [[ -f "$DOTFILES_DIR/agents/claude/CLAUDE.md" ]]; then
  ln -sf "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  echo "    linked CLAUDE.md"
fi

# The Agency 서브에이전트 설치
echo "    Installing subagents (The Agency)..."
bash "$DOTFILES_DIR/agents/restore-agents.sh"

# npx skills 복원
echo "    Restoring skills..."
bash "$DOTFILES_DIR/agents/restore-skills.sh"

echo "    Agent setup complete."
