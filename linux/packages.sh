#!/usr/bin/env bash
set -Eeuo pipefail

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
