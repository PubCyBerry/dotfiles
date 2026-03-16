#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_CONFIG_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_CONFIG_DIR"

# Link Claude global CLAUDE.md
if [[ -f "$DOTFILES_DIR/agents/claude/CLAUDE.md" ]]; then
  ln -sf "$DOTFILES_DIR/agents/claude/CLAUDE.md" "$CLAUDE_CONFIG_DIR/CLAUDE.md"
  echo "    linked CLAUDE.md"
fi

# Link Claude settings.json
if [[ -f "$DOTFILES_DIR/agents/claude/settings.json" ]]; then
  ln -sf "$DOTFILES_DIR/agents/claude/settings.json" "$CLAUDE_CONFIG_DIR/settings.json"
  echo "    linked claude settings.json"
fi

# Link subagents
if [[ -d "$DOTFILES_DIR/agents/claude/subagents" ]]; then
  mkdir -p "$CLAUDE_CONFIG_DIR/agents"
  for f in "$DOTFILES_DIR/agents/claude/subagents"/*.md; do
    [[ -f "$f" ]] || continue
    ln -sf "$f" "$CLAUDE_CONFIG_DIR/agents/$(basename "$f")"
    echo "    linked subagent: $(basename "$f")"
  done
fi

# Link skills
if [[ -d "$DOTFILES_DIR/agents/claude/skills" ]]; then
  mkdir -p "$CLAUDE_CONFIG_DIR/skills"
  for f in "$DOTFILES_DIR/agents/claude/skills"/*.md; do
    [[ -f "$f" ]] || continue
    ln -sf "$f" "$CLAUDE_CONFIG_DIR/skills/$(basename "$f")"
    echo "    linked skill: $(basename "$f")"
  done
fi

echo "    Agent configs linked."
