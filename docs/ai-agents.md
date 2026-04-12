# AI 에이전트 설정

Claude Code와 관련 에이전트/스킬 설정 상세.

## Claude Code 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 행동 설정 (RTK 규칙, 도구 사용 규칙) |
| `config/claude/settings.json` | `~/.claude/settings.json` | 언어, 권한 설정 |

Linux에서는 CLAUDE.md는 심볼릭 링크, settings.json은 MCP 명령어 패치 후 복사된다. Windows에서는 파일 복사로 설정된다.

## claude-hud

터미널 상태 표시줄에 Claude Code 세션 정보(모델, 컨텍스트, 토큰, git 상태 등)를 표시하는 플러그인.

**설치 절차** (모든 OS 공통):

1. bun 또는 node가 설치되어 있어야 함
2. Claude Code에서 `/plugin install claude-hud` 실행
3. `/claude-hud:setup` 실행하여 statusLine 명령어 생성
4. Claude Code 재시작

## npx skills

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, `install.ps1` / `install.sh`가 일괄 설치한다.

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 |
| `skill-creator` | 새 skill 생성 |
| `find-skills` | skill 검색/설치 |
| `impeccable` | 디자인 관련 스킬 |
