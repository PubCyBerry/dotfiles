#!/usr/bin/env bash
set -Eeuo pipefail

# Install fnm (Fast Node Manager) if not already installed
if command -v fnm &>/dev/null; then
  echo "    fnm already installed: $(fnm --version)"
  return 0 2>/dev/null || exit 0
fi

echo "    Installing fnm..."
curl -fsSL https://fnm.vercel.app/install | bash

echo "    fnm installed. Restart your shell or run:"
echo '    eval "$(fnm env --use-on-cd --shell bash)"'
