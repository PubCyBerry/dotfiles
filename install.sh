#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS detection
is_wsl()   { grep -qi microsoft /proc/version 2>/dev/null; }
is_linux() { [[ "$OSTYPE" == "linux-gnu"* ]]; }
is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }

echo "==> Dotfiles setup starting..."
echo "    Source: $DOTFILES_DIR"

# Bash configs
echo "==> Linking bash configs..."
for file in "$DOTFILES_DIR"/bash/.*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  ln -sf "$file" "$HOME/$name"
  echo "    linked $name"
done

# Tools
echo "==> Installing tools..."
bash "$DOTFILES_DIR/tools/fnm.sh"

# OS-specific
if is_macos; then
  echo "==> Running macOS setup..."
  bash "$DOTFILES_DIR/macos/install.sh"
elif is_wsl || is_linux; then
  echo "==> Running Linux setup..."
  bash "$DOTFILES_DIR/linux/packages.sh"
fi

# Agents
echo "==> Linking agent configs..."
bash "$DOTFILES_DIR/agents/setup.sh"

echo ""
echo "==> Done! Restart your shell to apply changes."
