#!/usr/bin/env bash
set -Eeuo pipefail

if command -v bun &>/dev/null; then
  echo "    bun already installed: $(bun --version)"
  exit 0
fi

if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
  # macOS: Homebrew로 설치
  brew install oven-sh/bun/bun
elif [[ "$OSTYPE" == "darwin"* ]] || grep -qi microsoft /proc/version 2>/dev/null || [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # macOS (brew 없음) / Linux / WSL2: 공식 설치 스크립트
  curl -fsSL https://bun.sh/install | bash
fi

echo "    bun installed."
