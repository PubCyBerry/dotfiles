#!/usr/bin/env bash
set -Eeuo pipefail

# 카카오 미러로 변경 (한국 네트워크 최적화)
SOURCES="/etc/apt/sources.list"
if grep -q "archive.ubuntu.com" "$SOURCES" 2>/dev/null; then
  echo "    Switching apt mirror to Kakao CDN..."
  sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror.kakao.com/ubuntu|g' "$SOURCES"
  sudo sed -i 's|http://security.ubuntu.com/ubuntu|http://mirror.kakao.com/ubuntu|g' "$SOURCES"
fi

echo "    Updating apt..."
sudo apt-get update -qq

PACKAGES=(
  git
  curl
  wget
  vim
  unzip
  build-essential
  shellcheck
  # Modern CLI (apt 버전)
  bat          # syntax-highlighted cat (Ubuntu에서 binary명: batcat)
  fzf          # 퍼지 파인더
  fd-find      # 빠른 find 대체 (Ubuntu에서 binary명: fdfind)
  ripgrep      # 빠른 grep 대체 (rg)
)

echo "    Installing packages: ${PACKAGES[*]}"
sudo apt-get install -y "${PACKAGES[@]}"

echo "    Linux packages installed."

# Ubuntu는 bat → batcat, fd-find → fdfind 로 설치됨. symlink 생성
mkdir -p ~/.local/bin
[[ ! -f ~/.local/bin/bat ]] && ln -sf "$(which batcat 2>/dev/null)" ~/.local/bin/bat 2>/dev/null || true
[[ ! -f ~/.local/bin/fd  ]] && ln -sf "$(which fdfind 2>/dev/null)" ~/.local/bin/fd  2>/dev/null || true

# Locale 설정
echo "    Setting up locale..."
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
