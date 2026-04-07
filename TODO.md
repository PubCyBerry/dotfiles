# TODO

## dotfiles 개선

### 단기 (간단한 작업)
- [x] `.extra` 빈 템플릿 파일 추가 + `.gitignore`에서 제외 처리
- [x] 루트 `.gitignore` 추가 (`.extra`, `.gitconfig.local` 보호)
- [x] `starship.toml` 기본 설정 추가 (`~/.config/starship.toml`)
- [x] Windows에서 `ast-grep`/`difftastic` 바이너리 직접 다운로드 지원

### 중기
- [ ] `uv` (Python 환경 관리) 설치 스크립트 추가 (Linux/macOS/Windows)
- [ ] SSH config 템플릿 (`~/.ssh/config.example`)
- [ ] README 한국어/영어 분리

### Claude Code 확장 — MCP 서버
- [ ] **GitHub MCP** (`@modelcontextprotocol/server-github`) — PR/이슈/저장소 자동화
- [ ] **Playwright MCP** (`@playwright/mcp`) — 웹 자동화, E2E 테스트
- [ ] **Filesystem MCP** (`@modelcontextprotocol/server-filesystem`) — 로컬 파일 직접 접근

### Claude Code 확장 — Skills
현재: pdf, pptx, docx, xlsx, bash-defensive-patterns, shellcheck-configuration, powershell-windows, find-skills, skill-creator
- [ ] **antigravity-awesome-skills** — 1,234+ skill 라이브러리 (`npx antigravity-awesome-skills`)
- [ ] **Valyu** — 웹 검색 + SEC/PubMed/FRED 등 36+ 데이터소스
- [ ] **anthropic/frontend-design** — 프론트엔드 전문 skill

### 기타
- [ ] Gemini CLI + antigravity 설정 추가 (`agents/gemini/` 디렉토리, Claude 구독 소진 시 대안)

