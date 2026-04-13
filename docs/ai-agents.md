# AI 에이전트 설정

Claude Code와 관련 에이전트/스킬 설정 상세.

## Claude Code 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 행동 설정 (도구 사용 규칙) |
| `config/claude/settings.json` | `~/.claude/settings.json` | 언어, 권한 설정 |

Linux에서는 CLAUDE.md는 심볼릭 링크, settings.json은 MCP 명령어 패치 후 복사된다. Windows에서는 settings.json은 기존 키를 보존하는 병합으로, CLAUDE.md는 단순 복사로 설정된다.

## claude-hud

터미널 상태 표시줄에 Claude Code 세션 정보(모델, 컨텍스트, 토큰, git 상태 등)를 표시하는 플러그인.  
→ 상세 설치/설정 가이드: [docs/claude-hud.md](claude-hud.md)  
→ 기본 설정 파일: `config/claude/claude-hud.json`

## npx skills

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, `install.ps1` / `install.sh`가 일괄 설치한다.

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 |
| `skill-creator` | 새 skill 생성 |
| `find-skills` | skill 검색/설치 |
| `impeccable` | 디자인 관련 스킬 |
