# AI 에이전트 설정

Claude Code, Codex와 관련 에이전트/스킬 설정 상세.

## Claude Code 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 행동 설정 (도구 사용 규칙) |
| `config/claude/settings.json` | `~/.claude/settings.json` | 언어, 권한, `rtk hook claude` hook 설정 |

Linux에서는 settings.json은 `jq -s '.[0]*.[1]'`로 기존 설정과 병합, CLAUDE.md는 단순 복사된다. Windows에서는 settings.json은 기존 키를 보존하는 병합으로, CLAUDE.md는 단순 복사로 설정된다. 현재 dotfiles는 `settings.json` 안에 `rtk hook claude`를 미리 포함해 배포하며, 별도 `rtk-rewrite.sh` 파일은 전제하지 않는다.

## Codex 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/codex/AGENTS.md` | `~/.codex/AGENTS.md` | 전역 행동 설정 (도구 사용 규칙 등) |
| `config/codex/config.toml` | `~/.codex/config.toml` | 모델 기본값 |

설치 스크립트는 `config.toml` 전체를 덮어쓰지 않는다. 기존 Codex 파일에 `model`, `model_reasoning_effort`가 없을 때만 dotfiles 기본값을 추가해 프로젝트 trust, 플러그인, Desktop 상태, 머신별 경로를 보존한다. `config/codex/config.toml`에 `[mcp_servers.openaiDeveloperDocs]`를 추가하면 같은 병합 경로로 Docs MCP 설정도 배포할 수 있다. `AGENTS.md`는 전역 지침 파일이라 단순 복사한다.

## claude-hud

터미널 상태 표시줄에 Claude Code 세션 정보(모델, 컨텍스트, 토큰, git 상태 등)를 표시하는 플러그인.  
→ 상세 설치/설정 가이드: [docs/claude-hud.md](claude-hud.md)  
→ 기본 설정 파일: `config/claude/claude-hud.json`

## npm 전역 패키지

`manifests/npm-global.txt`에 목록을 유지하고, fnm으로 설치된 Node.js의 npm으로 일괄 설치한다.

| 패키지 | 설명 |
|--------|------|
| `@openai/codex` | OpenAI Codex CLI — 코드 생성/수정 에이전트 |

## npx skills

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, install 스크립트가 일괄 설치한다.

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 (읽기/생성/편집) |
| `skill-creator` | 새 skill 생성 및 최적화 |
