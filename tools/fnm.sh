#!/usr/bin/env bash
set -Eeuo pipefail

# Install fnm (Fast Node Manager) if not already installed
if command -v fnm &>/dev/null; then
  echo "    fnm already installed: $(fnm --version)"
  return 0 2>/dev/null || exit 0
fi

# macOS: Homebrew가 있으면 brew로 설치 (macos/install.sh 가 먼저 실행되므로 여기선 건너뜀)
if [[ "$OSTYPE" == "darwin"* ]] && command -v brew &>/dev/null; then
  echo "    fnm will be installed via Homebrew (Brewfile)"
  return 0 2>/dev/null || exit 0
fi

echo "    Installing fnm via installer script..."
curl -fsSL https://fnm.vercel.app/install | bash

echo "    fnm installed. Restart your shell or run:"
echo '    eval "$(fnm env --use-on-cd --shell bash)"'
