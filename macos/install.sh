#!/usr/bin/env bash
set -Eeuo pipefail

echo "==> Running macOS setup..."

# Homebrew 설치
if ! command -v brew &>/dev/null; then
  echo "    Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Brewfile로 패키지 설치
BREWFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Brewfile"
echo "    Installing packages from Brewfile..."
brew bundle --file="$BREWFILE"

echo "==> macOS setup complete."
