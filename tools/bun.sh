#!/usr/bin/env bash
set -Eeuo pipefail

if command -v bun &>/dev/null; then
  echo "    bun already installed: $(bun --version)"
  exit 0
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS: Homebrew로 설치 (macos/install.sh에서 brew 설치 완료 후 실행됨)
  brew install oven-sh/bun/bun
elif grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # Linux / WSL2: 공식 설치 스크립트
  curl -fsSL https://bun.sh/install | bash
fi

echo "    bun installed."
