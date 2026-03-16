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
)

echo "    Installing packages: ${PACKAGES[*]}"
sudo apt-get install -y "${PACKAGES[@]}"

echo "    Linux packages installed."
