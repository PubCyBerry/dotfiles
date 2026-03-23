#!/usr/bin/env bash
set -Eeuo pipefail

# RTK(Rust Token Killer) 설치 및 Claude Code hook 등록
# settings.json의 PreToolUse hook은 agents/claude/settings.json에서 관리

if command -v rtk &>/dev/null; then
  echo "    rtk already installed: $(rtk --version 2>/dev/null || echo 'unknown')"
else
  echo "    Installing rtk..."
  if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
    # macOS: Homebrew (Brewfile에도 포함됨, 이미 설치됐을 수 있음)
    brew install rtk
  else
    # Linux / WSL2: 공식 install.sh (pre-built 바이너리)
    curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  fi
fi

# hook 스크립트 설치 (CLAUDE.md와 settings.json은 dotfiles에서 관리)
# --hook-only: ~/.claude/hooks/rtk-rewrite.sh 생성만 수행
if command -v rtk &>/dev/null; then
  rtk init --global --hook-only 2>/dev/null && echo "    rtk hook installed" || \
    echo "    [!] rtk hook install skipped (Windows는 래퍼로 워닝 억제)"
fi

# Windows(Git Bash): ~/.local/bin/rtk 래퍼 설치
# rtk init이 Windows에서 hook hash를 갱신할 수 없어 "Hook outdated" 워닝이
# 매 명령마다 stderr에 출력됨 → 래퍼로 필터링
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OS" == "Windows_NT" ]]; then
  WRAPPER_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rtk-wrapper"
  WRAPPER_DST="$HOME/.local/bin/rtk"
  if [[ -f "$WRAPPER_SRC" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$WRAPPER_SRC" "$WRAPPER_DST"
    chmod +x "$WRAPPER_DST"
    echo "    rtk wrapper installed → ~/.local/bin/rtk"
  fi
fi

echo "    rtk setup complete."
