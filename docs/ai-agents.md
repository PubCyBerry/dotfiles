# AI 에이전트 설정

Claude Code와 관련 에이전트/스킬 설정 상세.

## Claude Code 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `agents/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 행동 설정 (RTK 규칙, 도구 사용 규칙) |
| `agents/claude/settings.json` | `~/.claude/settings.json` | 플러그인, MCP, 언어, 권한 설정 |

Linux/macOS에서는 심볼릭 링크, Windows에서는 파일 복사로 설정된다.

## 플러그인

`settings.json`의 `enabledPlugins`로 관리. settings.json을 링크/복사하면 활성화 목록은 자동 복원되지만, **플러그인 파일 자체는 Claude Code 내에서 별도 설치 필요:**

```
/plugin   # 플러그인 마켓에서 검색 후 설치
```

| 플러그인 | 설명 |
|----------|------|
| `superpowers@claude-plugins-official` | Skills 시스템, 에이전트 워크플로우 |
| `context7@claude-plugins-official` | 라이브러리 최신 문서 조회 MCP 서버 |

## superpowers 주요 skills

플러그인 설치 후 자동 제공, 별도 설치 불필요.

| skill | 설명 |
|-------|------|
| `superpowers:subagent-driven-development` | 플랜을 서브에이전트로 병렬 실행 |
| `superpowers:writing-plans` | 구현 전 상세 계획 수립 |
| `superpowers:test-driven-development` | TDD 방식 구현 가이드 |
| `superpowers:systematic-debugging` | 버그/실패 원인 체계적 분석 |
| `superpowers:requesting-code-review` | 구현 완료 후 코드 리뷰 요청 |

## claude-hud

터미널 상태 표시줄에 Claude Code 세션 정보(모델, 컨텍스트, 토큰, git 상태 등)를 표시하는 플러그인.

**설치 절차** (모든 OS 공통):

1. bun 또는 node가 설치되어 있어야 함
2. Claude Code에서 `/plugin install claude-hud` 실행
3. `/claude-hud:setup` 실행하여 statusLine 명령어 생성
4. Claude Code 재시작

## npx skills

`agents/skills-manifest.txt`에 목록을 유지하고, `restore-skills.sh`가 일괄 설치한다.

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 |
| `bash-defensive-patterns` | 프로덕션용 bash 스크립트 패턴 |
| `shellcheck-configuration` | shell 스크립트 린팅 |
| `powershell-windows` | PowerShell 패턴 |
| `skill-creator` | 새 skill 생성 |
| `find-skills` | skill 검색/설치 |
