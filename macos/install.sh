#!/usr/bin/env bash
set -Eeuo pipefail

# 사용법: bash macos/install.sh [--with-defaults]
#   --with-defaults : macOS 시스템 설정(.macos)도 함께 적용

APPLY_DEFAULTS=false
for arg in "$@"; do
  [[ "$arg" == "--with-defaults" ]] && APPLY_DEFAULTS=true
done

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

# macOS 시스템 설정 (--with-defaults 플래그 시에만 실행)
if $APPLY_DEFAULTS; then
  echo "==> Applying macOS system defaults..."
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.macos"
fi

echo "==> macOS setup complete."
