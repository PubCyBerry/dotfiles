#!/usr/bin/env bash
set -Eeuo pipefail

# The Agency (https://github.com/msitarzewski/agency-agents) 설치
# Claude Code, Gemini CLI, OpenCode 등에 서브에이전트를 설치합니다.

AGENCY_DIR="$HOME/.agency-agents"

echo "==> Installing The Agency subagents..."

if [[ -d "$AGENCY_DIR" ]]; then
  echo "    Updating existing installation..."
  git -C "$AGENCY_DIR" pull
else
  echo "    Cloning The Agency..."
  git clone https://github.com/msitarzewski/agency-agents.git "$AGENCY_DIR"
fi

echo "    Running install script..."
bash "$AGENCY_DIR/scripts/install.sh" --no-interactive

echo "==> The Agency install complete."
