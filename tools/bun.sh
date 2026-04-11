#!/usr/bin/env bash
set -Eeuo pipefail

# Windows(Git Bash/MSYS)에서는 winget(install.ps1)으로 설치
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OS" == "Windows_NT" ]]; then
  echo "    [skip] Windows detected — install Bun via install.ps1 (winget)"
  exit 0
fi

if command -v bun &>/dev/null; then
  echo "    bun already installed: $(bun --version)"
  exit 0
fi

if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
  # macOS: Homebrew로 설치
  brew install oven-sh/bun/bun
elif [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux-gnu"* ]]; then
  # macOS (brew 없음) / Linux: 공식 설치 스크립트
  curl -fsSL https://bun.sh/install | bash
fi

echo "    bun installed."
