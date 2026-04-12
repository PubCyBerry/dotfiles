#!/usr/bin/env bash
# Linux dotfiles 설치 진입점 (all-in-one)
# 실행: bash install.sh
# macOS 지원은 macos/ 디렉토리에 보류
set -Eeuo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Linux dotfiles setup starting..."
echo "    Source: $DOTFILES"

# =============================================
# 1. bash dotfiles 심볼릭 링크 (config/bash/ → ~/)
# =============================================
echo ""
echo "==> Linking bash configs..."
for file in "$DOTFILES"/config/bash/.*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  [[ "$name" == ".gitconfig.local.example" ]] && continue
  ln -sf "$file" "$HOME/$name"
  echo "    linked $name"
done

# .gitconfig.local 없으면 안내
if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  echo ""
  echo "  [!] ~/.gitconfig.local 이 없습니다."
  echo "      다음 명령으로 생성하세요:"
  echo "      cp $DOTFILES/config/bash/.gitconfig.local.example ~/.gitconfig.local"
  echo "      그리고 name/email을 수정하세요."
  echo ""
fi

# =============================================
# 2. starship.toml 링크 (~/.config/)
# =============================================
echo "==> Linking config files..."
mkdir -p "$HOME/.config"
if [[ -f "$DOTFILES/config/starship.toml" ]]; then
  ln -sf "$DOTFILES/config/starship.toml" "$HOME/.config/starship.toml"
  echo "    linked starship.toml → ~/.config/starship.toml"
fi

# =============================================
# 3. TPM (tmux plugin manager)
# =============================================
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  echo "==> Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# =============================================
# 4. apt 패키지 설치 (manifests/apt.txt)
# =============================================
echo ""
echo "==> Installing apt packages..."

# 카카오 미러로 변경 (한국 네트워크 최적화)
if grep -q "archive.ubuntu.com" /etc/apt/sources.list 2>/dev/null; then
  echo "    Switching apt mirror to Kakao CDN..."
  sudo sed -i 's|http://archive.ubuntu.com/ubuntu|http://mirror.kakao.com/ubuntu|g' /etc/apt/sources.list
  sudo sed -i 's|http://security.ubuntu.com/ubuntu|http://mirror.kakao.com/ubuntu|g' /etc/apt/sources.list
fi

sudo apt-get update -qq

APT_PACKAGES=()
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  APT_PACKAGES+=("$line")
done < "$DOTFILES/manifests/apt.txt"

if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
  echo "    Installing: ${APT_PACKAGES[*]}"
  sudo apt-get install -y "${APT_PACKAGES[@]}"
fi

# Ubuntu는 bat → batcat, fd-find → fdfind 로 설치됨. symlink 생성
mkdir -p ~/.local/bin
[[ ! -f ~/.local/bin/bat ]] && ln -sf "$(which batcat 2>/dev/null)" ~/.local/bin/bat 2>/dev/null || true
[[ ! -f ~/.local/bin/fd  ]] && ln -sf "$(which fdfind 2>/dev/null)" ~/.local/bin/fd  2>/dev/null || true

# Locale 설정
echo "    Setting up locale..."
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# =============================================
# 5. apt 미지원 도구 바이너리 설치
# =============================================
echo ""
echo "==> Installing extra tools (binary)..."
mkdir -p ~/.local/bin

# eza (ls 대체)
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
  echo "    eza already installed."
fi

# delta (git diff 뷰어)
if ! command -v delta &>/dev/null; then
  echo "    Installing delta..."
  DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest \
    | grep '"tag_name"' | cut -d '"' -f 4)
  curl -fsSLo /tmp/delta.deb \
    "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/git-delta_${DELTA_VER}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb && rm /tmp/delta.deb
else
  echo "    delta already installed."
fi

# yq (YAML 처리)
if ! command -v yq &>/dev/null; then
  echo "    Installing yq..."
  curl -fsSLo ~/.local/bin/yq \
    "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"
  chmod +x ~/.local/bin/yq
else
  echo "    yq already installed."
fi

# zoxide (스마트 cd)
if ! command -v zoxide &>/dev/null; then
  echo "    Installing zoxide..."
  curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
else
  echo "    zoxide already installed."
fi

# starship (쉘 프롬프트)
if ! command -v starship &>/dev/null; then
  echo "    Installing starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir ~/.local/bin
else
  echo "    starship already installed."
fi

# ruff (Python 린터/포매터)
if ! command -v ruff &>/dev/null; then
  echo "    Installing ruff..."
  curl -LsSf https://astral.sh/ruff/install.sh | sh
else
  echo "    ruff already installed."
fi

# atuin (히스토리 강화)
if ! command -v atuin &>/dev/null; then
  echo "    Installing atuin..."
  curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh
else
  echo "    atuin already installed."
fi

# lazygit (TUI git 클라이언트)
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
  echo "    lazygit already installed."
fi

# yazi (TUI 파일매니저)
if ! command -v yazi &>/dev/null; then
  echo "    Installing yazi..."
  curl -fsSLo /tmp/yazi.zip \
    "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip"
  unzip -q /tmp/yazi.zip -d /tmp/yazi_extract
  mv /tmp/yazi_extract/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/yazi
  rm -rf /tmp/yazi.zip /tmp/yazi_extract
else
  echo "    yazi already installed."
fi

# difftastic (AST 기반 diff)
if ! command -v difft &>/dev/null; then
  echo "    Installing difftastic..."
  DIFFT_VER=$(curl -s "https://api.github.com/repos/Wilfred/difftastic/releases/latest" \
    | grep '"tag_name"' | cut -d '"' -f 4)
  curl -fsSLo /tmp/difft.tar.gz \
    "https://github.com/Wilfred/difftastic/releases/download/${DIFFT_VER}/difft-x86_64-unknown-linux-musl.tar.gz"
  tar -xzf /tmp/difft.tar.gz -C ~/.local/bin difft
  rm /tmp/difft.tar.gz
else
  echo "    difftastic already installed."
fi

# ast-grep (AST 기반 코드 검색)
if ! command -v sg &>/dev/null; then
  echo "    Installing ast-grep..."
  curl -fsSLo /tmp/ast-grep.zip \
    "https://github.com/ast-grep/ast-grep/releases/latest/download/app-x86_64-unknown-linux-gnu.zip"
  unzip -q /tmp/ast-grep.zip -d /tmp/ast_grep_extract
  mv /tmp/ast_grep_extract/sg ~/.local/bin/sg
  rm -rf /tmp/ast-grep.zip /tmp/ast_grep_extract
else
  echo "    ast-grep already installed."
fi

# =============================================
# 6. fnm 설치 → Node.js LTS
# =============================================
echo ""
echo "==> Installing fnm and Node.js..."
if ! command -v fnm &>/dev/null; then
  echo "    Installing fnm..."
  curl -fsSL https://fnm.vercel.app/install | bash
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"
else
  echo "    fnm already installed."
fi

NODE_MAJOR=24
if fnm list 2>/dev/null | grep -q "v${NODE_MAJOR}\."; then
  echo "    Node.js ${NODE_MAJOR}.x already installed, skipping"
else
  echo "    Installing Node.js ${NODE_MAJOR}..."
  fnm install "$NODE_MAJOR"
fi
fnm default "$NODE_MAJOR"
fnm use "$NODE_MAJOR"
echo "    Node $(node --version 2>/dev/null || echo 'not active yet') active."

# =============================================
# 7. npm 전역 패키지 설치 (manifests/npm-global.txt)
# =============================================
echo ""
echo "==> Installing global npm packages..."
while IFS= read -r pkg || [[ -n "$pkg" ]]; do
  [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
  if npm list -g --depth=0 "$pkg" &>/dev/null; then
    echo "    already installed: $pkg"
  else
    echo "    installing: $pkg"
    npm install -g "$pkg"
  fi
done < "$DOTFILES/manifests/npm-global.txt"

# =============================================
# 8. Claude Code 설치 (native)
# =============================================
echo ""
echo "==> Installing Claude Code..."
if ! command -v claude &>/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
  echo "    Claude Code installed."
else
  echo "    Claude Code already installed: $(claude --version)"
fi

# =============================================
# 9. RTK (Rust Token Killer) 설치
# =============================================
echo ""
echo "==> Installing RTK..."
if ! command -v rtk &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
else
  echo "    rtk already installed."
fi

# rtk hook 설치 (--hook-only: ~/.claude/hooks/rtk-rewrite.sh 생성)
if command -v rtk &>/dev/null; then
  rtk init --global --hook-only 2>/dev/null && echo "    rtk hook installed" || \
    echo "    [!] rtk hook install failed (수동 설치 필요)"
fi

# =============================================
# 10. Claude Code 설정 배포 (config/claude/ → ~/.claude/)
# =============================================
echo ""
echo "==> Deploying Claude Code config..."
CLAUDE_DIR="$HOME/.claude"
mkdir -p "$CLAUDE_DIR"

# settings.json: MCP 명령어 패치 (cmd /c npx → npx)
if [[ -f "$DOTFILES/config/claude/settings.json" ]]; then
  cp "$DOTFILES/config/claude/settings.json" "$CLAUDE_DIR/settings.json"
  python3 - "$CLAUDE_DIR/settings.json" <<'EOF'
import sys, json
path = sys.argv[1]
with open(path) as f:
    cfg = json.load(f)
mcp = cfg.get("mcpServers", {})
for name, server in mcp.items():
    if server.get("command") == "cmd" and server.get("args", [])[:2] == ["/c", "npx"]:
        server["command"] = "npx"
        server["args"] = server["args"][2:]
with open(path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
print("    patched MCP commands for Linux")
EOF
  echo "    Deployed settings.json"
fi

# CLAUDE.md: 심볼릭 링크
if [[ -f "$DOTFILES/config/claude/CLAUDE.md" ]]; then
  ln -sf "$DOTFILES/config/claude/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
  echo "    Linked CLAUDE.md"
fi

# =============================================
# 11. Claude skills 설치 (manifests/skills.txt)
# =============================================
echo ""
echo "==> Restoring Claude Code skills..."
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  if [[ "$line" =~ ^([^@]+)@(.+)$ ]]; then
    repo="${BASH_REMATCH[1]}"
    skill="${BASH_REMATCH[2]}"
    echo "    Adding skill: $skill from $repo..."
    npx skills add "$repo" --skill "$skill" -g -y 2>/dev/null || true
  fi
done < "$DOTFILES/manifests/skills.txt"
echo "    Skills restored."

echo ""
echo "==> Done! Restart your shell to apply changes."
