# Claude Code subagent 정의 형식 레퍼런스

subagent는 `<name>.md` 파일 하나로 정의한다. **YAML frontmatter**(메타데이터) + **Markdown 본문**(시스템 프롬프트) 구조다.

```markdown
---
name: test-runner
description: Use proactively to run tests and fix failures when code changes.
tools: Read, Edit, Bash
model: sonnet
---

너는 테스트 실행 전문가다. ...(시스템 프롬프트)...
```

## frontmatter 필드

| 필드 | 필수 | 형식 | 설명 |
|------|------|------|------|
| `name` | O | kebab-case 문자열 | 고유 식별자. **파일명(확장자 제외)과 같아야 한다.** 예: `code-reviewer.md` → `name: code-reviewer` |
| `description` | O | 자연어 문장 | 이 subagent를 **언제 위임할지** 설명. Claude Code의 자동 위임 판단 기준이 되는 가장 중요한 필드 |
| `tools` | X | 콤마 구분 목록 | 이 subagent가 쓸 수 있는 도구 allowlist. **생략하면 메인 스레드가 가진 모든 도구를 상속**한다 |
| `disallowedTools` | X | 콤마 구분 목록 | 상속하거나 지정한 도구 중 금지할 목록 |
| `model` | X | 별칭 또는 모델 ID | 이 subagent를 구동할 모델. 생략 시 시스템 기본값 |
| `permissionMode` | X | 문자열 | `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `manual`, `plan` 중 하나 |
| `maxTurns` | X | 양의 정수 | 최대 agentic turn 수 |
| `skills` | X | 문자열 목록 | 시작할 때 preload할 skill |
| `mcpServers` | X | 목록 또는 매핑 | 이 agent가 사용할 MCP server |
| `hooks` | X | 매핑 | 이 agent에만 적용할 lifecycle hook |
| `memory` | X | 문자열 | `user`, `project`, `local` 중 persistent memory 범위 |
| `background` | X | boolean | 항상 background task로 실행할지 여부 |
| `effort` | X | 문자열 | `low`, `medium`, `high`, `xhigh`, `max` 중 하나 |
| `isolation` | X | 문자열 | `worktree`이면 임시 git worktree에서 실행 |
| `color` | X | 문자열 | task 목록과 transcript의 표시 색상 |
| `initialPrompt` | X | 문자열 | main session agent로 실행할 때 첫 user turn |

## model 옵션

| 값 | 의미 |
|----|------|
| `haiku` | 가장 빠르고 저렴. 단순·반복·결정적 작업에 적합 |
| `sonnet` | 균형. 일반적인 코딩/분석 작업 |
| `opus` | 가장 강력한 추론. 복잡한 설계·디버깅 |
| `inherit` | 메인 대화와 동일한 모델 사용 |
| `fable` 등 | Claude Code가 제공하는 다른 model alias |
| `claude-...` | 전체 모델 ID를 직접 지정(고급) |

작업 난이도에 맞춰 고른다. 위임 작업 대부분은 `haiku`/`sonnet`로 충분하고, 깊은 추론이 필요할 때만 `opus`를 쓴다.

## 대표 tools 이름

자주 쓰는 코어 도구. **그 일에 꼭 필요한 것만** 나열한다(최소 권한).

| 분류 | 도구 |
|------|------|
| 읽기/탐색 | `Read`, `Grep`, `Glob` |
| 편집/쓰기 | `Edit`, `Write`, `NotebookEdit` |
| 실행 | `Bash`, `PowerShell`, `Monitor` |
| 웹 | `WebFetch`, `WebSearch` |
| 위임/협업 | `Agent`, `ListAgents`, `SendMessage`, `TaskCreate`, `TaskGet`, `TaskList`, `TaskUpdate` |
| MCP | `mcp__<server>__<tool>` 형식(서버별로 다름) |

읽기 전용 분석 에이전트에는 `Read`, `Grep`, `Glob` 정도만 주고 `Write`/`Edit`/`Bash`는 빼는 식으로 권한을 좁힌다.
정확한 field와 tool 경계는 공식 [subagent 문서](https://code.claude.com/docs/en/sub-agents)와 [tools reference](https://code.claude.com/docs/en/tools-reference)를 기준으로 한다.
foreground/background, teammate, 기능과 `permissionMode`·delegation depth에 따라 가용성이 달라지므로 실제 agent에 노출되는 tool만 지정하고, 모든 subagent에서 제거되는 tool은 나열하지 않는다.

## 저장 위치와 우선순위

| 범위 | 경로 | 특징 |
|------|------|------|
| 프로젝트 | `<repo>/.claude/agents/<name>.md` | 해당 저장소에서만. 커밋되어 팀과 공유 (**기본 권장**) |
| 전역 | `~/.claude/agents/<name>.md` | 모든 프로젝트에서. 개인용 |

같은 `name`이 양쪽에 있으면 **프로젝트 정의가 전역보다 우선**한다.

## 호출 방식

1. **자동 위임** — Claude Code가 작업 내용과 각 subagent의 `description`을 대조해 적합하면 자동으로 위임한다. 그래서 `description`에 "언제 쓰는지"가 분명해야 한다. "Use proactively ..." 같은 문구는 능동적 위임을 유도한다.
2. **명시 호출** — 사용자가 "code-reviewer 에이전트로 검토해줘"처럼 이름을 직접 지목해 호출할 수 있다.
