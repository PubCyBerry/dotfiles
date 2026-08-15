# AI 에이전트 설정

Claude Code, Codex와 관련 에이전트/스킬 설정 상세.

## Claude Code 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/agents/global.md` | `~/.claude/CLAUDE.md` | 공통 전역 행동 설정 |
| `config/claude/settings.json` | `~/.claude/settings.json` | 언어, 권한, hook 설정 |

모든 OS에서 settings.json은 공용 `scripts/merge-json-registry.jq` 규칙으로 병합한다. dotfiles가 등록하는 env·hook 항목만 갱신하고 사용자 키와 사용자 registry 항목은 보존한다. `config/agents/global.md`는 Claude가 읽는 파일명에 맞춰 `~/.claude/CLAUDE.md`로 복사된다.

## Codex 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/agents/global.md` | `~/.codex/AGENTS.md` | 공통 전역 행동 설정 |
| `config/codex/config.toml` | `~/.codex/config.toml` | 모델 기본값 |
| `config/codex/hooks.json` | `~/.codex/hooks.json` | Codex hook 등록 |
| `config/codex/hooks/temporal-context.sh` | `~/.codex/hooks/temporal-context.sh` | SessionStart 시간 컨텍스트 주입 |
| `config/agents/roles/<name>/` | `~/.codex/agents/<name>.toml` | subagent 정의 (`spawn_agent` 대상) |

설치 스크립트는 `config.toml` 전체를 덮어쓰지 않는다. 기존 Codex 파일에 `model`, `model_reasoning_effort`가 없을 때만 dotfiles 기본값을 추가해 프로젝트 trust, 플러그인, Desktop 상태, 머신별 경로를 보존한다. `config/codex/config.toml`에 `[mcp_servers.openaiDeveloperDocs]`를 추가하면 같은 병합 경로로 Docs MCP 설정도 배포할 수 있다. `config/agents/global.md`는 Codex가 읽는 파일명에 맞춰 `~/.codex/AGENTS.md`로 복사된다. Codex hook은 Claude Code hook과 출력 포맷이 달라 `config/codex/hooks/`에서 별도로 관리한다.

agent role은 Codex 0.145.0부터 subagent(`~/.codex/agents/<name>.toml`)로 배포한다. `codex.toml` 메타에 `body.md`가 `developer_instructions` 값으로 들어간다. 그 전에는 위임 프리미티브가 없어 같은 role을 skill(`~/.codex/skills/<name>/`)로 배포했고, install 스크립트가 그 구 경로를 이름 단위로 정리한다. 노출 확인:

```bash
codex exec --sandbox read-only "spawn_agent 툴로 띄울 수 있는 custom agent 이름만 나열해."
```

## Antigravity (AGY) 설정 파일

| 파일 | 설치 위치 | 내용 |
|------|-----------|------|
| `config/agents/global.md` | `~/.gemini/config/GEMINI.md`, `~/.gemini/GEMINI.md` | 공통 전역 행동 설정 |
| `config/agy/hooks.json` | `~/.gemini/config/hooks.json` | Antigravity hook 등록 |
| `config/agy/hooks/temporal-context.sh` | `~/.gemini/hooks/temporal-context.sh` | PreInvocation 시간 컨텍스트 주입 |
| `config/claude/skills/<name>/` | `~/.gemini/config/skills/<name>/` | 로컬 스킬 공유 배포 |
| `manifests/rhwp.tsv` | `~/.gemini/config/mcp_config.json` | rhwp stdio MCP 서버 등록 |

Antigravity는 `~/.gemini/config/GEMINI.md` 및 `~/.gemini/GEMINI.md`를 전역 룰로 참조한다. `hooks.json`은 공용 `scripts/merge-json-registry.jq` 규칙으로 병합되며, `hooks/` 디렉터리에 실행 스크립트가 배치된다. MCP 설정은 `~/.gemini/config/mcp_config.json`의 `.mcpServers` 맵에 등록된다.

## 플러그인

`manifests/plugins.txt`에 `<marketplace-source> <plugin>@<marketplace> [scope]` 형식으로 목록을 유지하고, install 스크립트가 `claude plugin marketplace add` → `claude plugin install`을 순서대로 실행한다. 두 명령 모두 멱등이라 반복 실행해도 안전하다.

| 플러그인 | 마켓플레이스 | 설명 |
|---|---|---|
| `claude-hud` | `jarrodwatts/claude-hud` | statusline에 세션 정보(모델, 컨텍스트, 토큰, git 상태) 표시 |
| `caveman` | `JuliusBrussee/caveman` | 응답 압축 모드 — 토큰 사용량 감소 |
| `codex` | `openai/codex-plugin-cc` (마켓플레이스 이름 `openai-codex`) | Claude Code 세션 안에서 Codex 호출 |

플러그인은 `~/.claude/plugins/`에 CLI가 직접 설치하므로, 저장소가 파일을 복사하지 않는다. 제거도 CLI로만 한다(`docs/uninstall.md` 7번 참고) — 디렉터리를 통째로 지우면 매니페스트 밖의 플러그인까지 사라진다.

### claude-hud

→ 상세 설치/설정 가이드: [docs/claude-hud.md](claude-hud.md)  
→ 기본 설정 파일: `config/claude/claude-hud.json` (템플릿. install 스크립트가 배포하지 않으며 `~/.claude/plugins/claude-hud/config.json`로 수동 복사한다)

## npm 전역 패키지

`manifests/npm-global.txt`에 목록을 유지하고, fnm으로 설치된 Node.js의 npm으로 일괄 설치한다.

| 패키지 | 설명 |
|--------|------|
| `@openai/codex` | OpenAI Codex CLI — 코드 생성/수정 에이전트 |

## npx skills (원격)

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, install 스크립트가 `npx skills add --global`로 일괄 설치한다.

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 (읽기/생성/편집) |
| `skill-creator` | 새 skill 생성 및 최적화 |

## 로컬 skill

이 저장소가 직접 소유하는 skill은 `config/claude/skills/<name>/`에 둔다. install 스크립트의 3-1 단계가 **디렉터리 단위로** `~/.claude/skills/`에 배포하며, `npx skills`로 설치된 원격 skill 경로는 건드리지 않는다. 새 로컬 skill을 추가하려면 `config/claude/skills/`에 디렉터리를 만들고 install 스크립트를 다시 실행한다.

| 스킬 | 설명 |
|------|------|
| `subagent-creator` | Claude Code subagent 정의(`.claude/agents/<name>.md`) 대화형 생성·검증 |
| `repo-scaffold` | 저장소를 에이전트 탐색용 형태로 스캐폴딩 — AGENTS.md 문서 인덱스 자동 생성, `docs/` 계층과 front matter 규약, pre-commit 검증 훅 |

### repo-scaffold

에이전트가 사전학습 기억이 아니라 저장소 안 문서를 근거로 판단하게 만드는 것이 목적이다. 세 가지를 한 번에 깐다.

- `AGENTS.md`의 문서 인덱스 — `git ls-files`로 `.md`/`.mdx`를 훑어 디렉터리별 한 줄로 직렬화하고, 마커 사이에 삽입한다
- `docs/{standards,guides,references,generated}/` 계층 — 디렉터리명과 front matter `type`이 1:1이라 위치만 보고 성격을 안다
- pre-commit 훅 4개 — 인덱스 갱신, 문서 규약, `.env` 키 동기화, 자격 증명 스캔. 전부 `repo: local`이라 폐쇄망에서도 clone 실패로 막히지 않는다

```bash
SKILL_DIR="$HOME/.claude/skills/repo-scaffold"
bash "$SKILL_DIR/assets/scaffold.sh" --target /path/to/repo --name MYREPO --dry-run
```

기존 파일은 덮어쓰지 않고 `SKIP`으로 보고만 한다. 여러 번 돌려도 결과가 같아서, 이미 파일이 있는 저장소에 얹을 때는 `--dry-run` 출력이 그대로 진단 결과가 된다.
