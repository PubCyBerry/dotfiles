#!/usr/bin/env bash
set -Eeuo pipefail

# apt에 없거나 버전이 너무 낮은 도구를 GitHub 릴리즈에서 설치

# eza (ls 대체) -------------------------------------------------------
if ! command -v eza &>/dev/null; then
  echo "    Installing eza..."
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list > /dev/null
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -qq
  sudo apt-get install -y eza
else
  echo "    eza already installed: $(eza --version | head -1)"
fi

# delta (git diff 뷰어) -----------------------------------------------
if ! command -v delta &>/dev/null; then
  echo "    Installing delta..."
  DELTA_VERSION=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)
  curl -fsSLo /tmp/delta.deb \
    "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/git-delta_${DELTA_VERSION}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb
  rm /tmp/delta.deb
else
  echo "    delta already installed: $(delta --version)"
fi

echo "    Extras installed."
