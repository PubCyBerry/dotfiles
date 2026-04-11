#!/usr/bin/env bash
set -Eeuo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS detection
is_linux() { [[ "$OSTYPE" == "linux-gnu"* ]]; }
is_macos() { [[ "$OSTYPE" == "darwin"* ]]; }

echo "==> Dotfiles setup starting..."
echo "    Source: $DOTFILES_DIR"

# Bash configs (.gitconfig.local.example 제외하고 링크)
echo "==> Linking bash configs..."
for file in "$DOTFILES_DIR"/bash/.*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  [[ "$name" == ".gitconfig.local.example" ]] && continue
  ln -sf "$file" "$HOME/$name"
  echo "    linked $name"
done

# XDG config 파일 링크 (~/.config/*)
echo "==> Linking config files..."
mkdir -p "$HOME/.config"
for file in "$DOTFILES_DIR"/config/*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  ln -sf "$file" "$HOME/.config/$name"
  echo "    linked $name → ~/.config/$name"
done

# .gitconfig.local 없으면 안내
if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  echo ""
  echo "  [!] ~/.gitconfig.local 이 없습니다."
  echo "      다음 명령으로 생성하세요:"
  echo "      cp $DOTFILES_DIR/bash/.gitconfig.local.example ~/.gitconfig.local"
  echo "      그리고 name/email을 수정하세요."
  echo ""
fi

# OS-specific (패키지 먼저 - tools 의존성 충족)
if is_macos; then
  echo "==> Running macOS setup..."
  bash "$DOTFILES_DIR/macos/install.sh"
elif is_linux; then
  echo "==> Running Linux setup..."
  bash "$DOTFILES_DIR/linux/packages.sh"
  bash "$DOTFILES_DIR/linux/install-extras.sh"
fi

# TPM (tmux plugin manager)
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# Tools
echo "==> Installing tools..."
bash "$DOTFILES_DIR/tools/fnm.sh"
bash "$DOTFILES_DIR/tools/node.sh"
bash "$DOTFILES_DIR/tools/bun.sh"
bash "$DOTFILES_DIR/tools/global-packages.sh"
bash "$DOTFILES_DIR/tools/rtk.sh"

# Agents
echo "==> Linking agent configs..."
bash "$DOTFILES_DIR/agents/setup.sh"

echo ""
echo "==> Done! Restart your shell to apply changes."
