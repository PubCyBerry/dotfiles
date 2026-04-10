#!/usr/bin/env bash
set -Eeuo pipefail

# fnm이 없으면 먼저 설치
if ! command -v fnm &>/dev/null; then
  echo "    fnm not found, running fnm.sh first..."
  bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fnm.sh"

  # fnm 환경 로드 (설치 직후)
  export PATH="$HOME/.local/share/fnm:$PATH"
  eval "$(fnm env --shell bash)"
fi

# Node LTS 설치 및 기본값 설정
# 메이저 버전 고정: fnm은 버전마다 별도 디렉토리를 사용하므로
# 패치가 올라가면 글로벌 패키지가 사라진다. 이미 설치된 버전이 있으면 건너뛴다.
# 새 메이저 LTS 전환 시 NODE_MAJOR를 수동으로 올린다.
NODE_MAJOR=24
if fnm list 2>/dev/null | grep -q "v${NODE_MAJOR}\."; then
  echo "    Node.js ${NODE_MAJOR}.x already installed, skipping"
else
  echo "    Installing Node.js ${NODE_MAJOR}..."
  fnm install "$NODE_MAJOR"
fi
fnm default "$NODE_MAJOR"
fnm use "$NODE_MAJOR"

echo "    Node $(node --version) active."

# Claude Code 설치 (네이티브 — npm 설치 시 'claude install' 마이그레이션 경고 발생)
if ! command -v claude &>/dev/null; then
  echo "    Installing Claude Code (native)..."
  curl -fsSL https://claude.ai/install.sh | bash
  echo "    Claude Code installed."
else
  echo "    Claude Code already installed: $(claude --version)"
fi
