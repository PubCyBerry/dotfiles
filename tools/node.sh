#!/usr/bin/env bash
set -Eeuo pipefail

# fnm이 없으면 먼저 설치
if ! command -v fnm &>/dev/null; then
  echo "    fnm not found, running fnm.sh first..."
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fnm.sh"

  # fnm 환경 로드 (설치 직후)
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"
fi

# Node LTS 설치 및 기본값 설정
echo "    Installing Node.js LTS..."
fnm install --lts
fnm default lts-latest
fnm use lts-latest

echo "    Node $(node --version) installed."

# Claude Code 설치 (네이티브 — npm 설치 시 'claude install' 마이그레이션 경고 발생)
if ! command -v claude &>/dev/null; then
  echo "    Installing Claude Code (native)..."
  curl -fsSL https://claude.ai/install.sh | bash
  echo "    Claude Code installed."
else
  echo "    Claude Code already installed: $(claude --version)"
fi
