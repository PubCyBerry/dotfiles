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

# 공통: ~/.local/bin 경로 확보
mkdir -p ~/.local/bin

# yq (YAML 처리) -------------------------------------------------------
if ! command -v yq &>/dev/null; then
  echo "    Installing yq..."
  curl -fsSLo ~/.local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
  chmod +x ~/.local/bin/yq
else
  echo "    yq already installed: $(yq --version)"
fi

# zoxide (스마트 cd) ---------------------------------------------------
if ! command -v zoxide &>/dev/null; then
  echo "    Installing zoxide..."
  curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
  echo "    zoxide already installed: $(zoxide --version)"
fi

# starship (쉘 프롬프트) -----------------------------------------------
if ! command -v starship &>/dev/null; then
  echo "    Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir ~/.local/bin
else
  echo "    starship already installed: $(starship --version | head -1)"
fi

# ruff (Python 린터/포매터) --------------------------------------------
if ! command -v ruff &>/dev/null; then
  echo "    Installing ruff..."
  curl -LsSf https://astral.sh/ruff/install.sh | sh
else
  echo "    ruff already installed: $(ruff --version)"
fi

# atuin (히스토리 강화) ------------------------------------------------
if ! command -v atuin &>/dev/null; then
  echo "    Installing atuin..."
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
else
  echo "    atuin already installed: $(atuin --version)"
fi

# lazygit (TUI git 클라이언트) -----------------------------------------
if ! command -v lazygit &>/dev/null; then
  echo "    Installing lazygit..."
  LAZYGIT_VER=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
    | grep '"tag_name"' | cut -d '"' -f 4 | sed 's/v//')
  curl -fsSLo /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VER}_Linux_x86_64.tar.gz"
  tar -xzf /tmp/lazygit.tar.gz -C /tmp lazygit
  mv /tmp/lazygit ~/.local/bin/lazygit
  rm /tmp/lazygit.tar.gz
else
  echo "    lazygit already installed: $(lazygit --version | head -1)"
fi

# yazi (TUI 파일매니저) ------------------------------------------------
if ! command -v yazi &>/dev/null; then
  echo "    Installing yazi..."
  curl -fsSLo /tmp/yazi.zip \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip"
  unzip -q /tmp/yazi.zip -d /tmp/yazi_extract
  mv /tmp/yazi_extract/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/yazi
  rm -rf /tmp/yazi.zip /tmp/yazi_extract
else
  echo "    yazi already installed: $(yazi --version)"
fi

# difftastic (AST 기반 diff) -------------------------------------------
if ! command -v difft &>/dev/null; then
  echo "    Installing difftastic..."
  DIFFT_VER=$(curl -s "https://api.github.com/repos/Wilfred/difftastic/releases/latest" \
    | grep '"tag_name"' | cut -d '"' -f 4)
  curl -fsSLo /tmp/difft.tar.gz \
    "https://github.com/Wilfred/difftastic/releases/download/${DIFFT_VER}/difft-x86_64-unknown-linux-musl.tar.gz"
  tar -xzf /tmp/difft.tar.gz -C ~/.local/bin difft
  rm /tmp/difft.tar.gz
else
  echo "    difftastic already installed: $(difft --version)"
fi

# ast-grep (AST 기반 코드 검색) ----------------------------------------
if ! command -v sg &>/dev/null; then
  echo "    Installing ast-grep..."
  curl -fsSLo /tmp/ast-grep.zip \
    "https://github.com/ast-grep/ast-grep/releases/latest/download/app-x86_64-unknown-linux-musl.zip"
  unzip -q /tmp/ast-grep.zip -d /tmp/ast_grep_extract
  mv /tmp/ast_grep_extract/sg ~/.local/bin/sg
  rm -rf /tmp/ast-grep.zip /tmp/ast_grep_extract
else
  echo "    ast-grep already installed: $(sg --version)"
fi

echo "    Extras installed."
