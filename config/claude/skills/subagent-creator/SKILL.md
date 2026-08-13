---
name: subagent-creator
description: Create new Claude Code subagents — the `.claude/agents/<name>.md` definition files that Claude Code delegates tasks to. Use whenever the user wants to make, create, design, scaffold, or set up a subagent, custom agent, or specialized agent for Claude Code — including phrasings like "make an agent that reviews migrations", "I want a test-writer agent", "서브에이전트 만들어줘", "에이전트 하나 만들어줘", even when the word "subagent" is never used. Guides choosing the name, description (delegation triggers), tools allowlist, model, and system prompt, then writes and validates the definition file.
---

# Subagent Creator

Claude Code의 **subagent 정의 파일**(`.claude/agents/<name>.md`)을 대화형으로 만들어주는 skill이다. 사용자가 "X를 하는 에이전트를 만들어줘"라고 하면, 역할을 구체화하고 frontmatter와 시스템 프롬프트를 작성한 뒤 검증까지 마친 정의 파일을 생성한다.

subagent는 Claude Code가 특정 작업을 **위임(delegate)**할 수 있는 독립 에이전트다. 자체 컨텍스트 창과 도구 권한, 시스템 프롬프트를 가지며, 메인 대화의 컨텍스트를 어지럽히지 않고 전문화된 일을 수행한다. 잘 만든 subagent의 핵심은 **언제 위임될지**(description)와 **무엇을 어떻게 하는지**(시스템 프롬프트)가 명확한 것이다.

## subagent 정의 형식

정의 파일은 YAML frontmatter + Markdown 본문(시스템 프롬프트)으로 구성된다.

```markdown
---
name: code-reviewer
description: Expert code review specialist. Use proactively right after writing or modifying code, before committing.
tools: Read, Grep, Glob, Bash
model: sonnet
---

너는 코드 리뷰 전문가다. ...(시스템 프롬프트 본문)...
```

| 필드 | 필수 | 설명 |
|------|------|------|
| `name` | O | kebab-case 식별자. **파일명(확장자 제외)과 일치**해야 한다 |
| `description` | O | **언제 위임할지**를 설명. 자동 위임 판단의 핵심 |
| `tools` | X | 콤마 구분 도구 allowlist. **생략 시 메인 스레드의 모든 도구를 상속** |
| `model` | X | 모델 별칭(`sonnet`, `opus`, `haiku`, `fable` 등) 또는 전체 모델 ID. 생략 시 기본값 |
| `effort` | X | `low` / `medium` / `high` / `xhigh` / `max` |
| `maxTurns` | X | 최대 agentic turn 수(1 이상의 정수) |
| `skills` | X | 시작할 때 preload할 skill 이름 목록 |
| `isolation` | X | `worktree`이면 임시 git worktree에서 실행 |
| `hooks` | X | 이 agent에만 적용할 lifecycle hook 매핑 |

본문 전체가 subagent의 **시스템 프롬프트**다. 필드별 상세·도구 목록·경로 규칙은 `references/agent-format.md`를 참고한다.

## 생성 절차

### 1. 의도 파악

먼저 무엇을 만들지 명확히 한다. 대화에 이미 단서가 있으면(예: "방금 짠 이 작업을 에이전트로") 거기서 추출하고, 부족하면 묻는다.

- 이 subagent가 **무슨 일**을 하는가? (단일 책임으로 좁힌다)
- **언제** 위임되어야 하는가? (어떤 상황·트리거)
- 입력과 **출력 형식**은? (메인 스레드에 무엇을 돌려주는가)

### 2. frontmatter 결정

- **`description`이 가장 중요하다.** Claude Code는 이 문장만 보고 위임 여부를 판단한다. 단순히 "코드를 리뷰한다"가 아니라, 위임 상황을 구체적으로 적는다. 능동적으로 쓰이길 원하면 "Use proactively when ..." 같은 트리거 문구를 넣는다. 한국어 사용자가 한국어로 호출할 수 있으니, 필요하면 한국어 트리거 표현도 함께 넣는다.
- **`tools`는 최소 권한으로.** 그 일에 꼭 필요한 도구만 나열한다. 읽기 전용 분석 에이전트에 `Write`/`Edit`를 주지 않는다. 확신이 없으면 생략해 전체 상속하되, 위임 에이전트는 최소 권한이 기본이라는 점을 의식한다.
- **`model`은 작업 난이도에 맞춘다.** 단순·반복 작업은 `haiku`, 복잡한 추론은 `opus`/`sonnet`, 메인과 동일하게 하려면 `inherit`.

### 3. 시스템 프롬프트(본문) 작성

본문은 subagent의 행동을 정의한다. 다음을 명령형으로 담는다.

- **역할과 목표**: 너는 무엇을 하는 전문가인가.
- **절차**: 어떤 순서로 일하는가. 단계가 있으면 번호로.
- **출력 형식**: 메인 스레드에 무엇을, 어떤 구조로 반환하는가.
- **경계**: 하지 말아야 할 것, 범위 밖의 일.

규칙을 나열하기보다 **왜** 그렇게 해야 하는지 짧게 설명한다. 오늘날의 모델은 이유를 알면 더 잘 따른다. `ALWAYS`/`NEVER` 같은 경직된 표현이 늘어나면 한 번 더 풀어 설명할 수 있는지 본다.

### 4. 저장 위치 결정

- **기본: 프로젝트** — `<repo>/.claude/agents/<name>.md`. 해당 프로젝트에서만 쓰이고 저장소에 커밋된다.
- **전역** — `~/.claude/agents/<name>.md`. 사용자가 "전역으로", "모든 프로젝트에서" 같이 **명시 요청할 때만** 사용한다.

같은 이름이면 프로젝트가 전역보다 우선한다. 기존 파일을 덮어쓰기 전에 내용을 확인한다.

### 5. 파일 작성 후 검증

정의 파일을 쓴 뒤 검증 스크립트를 돌려 형식 오류를 잡는다.

```bash
uv run --with pyyaml --python 3.11 config/claude/skills/subagent-creator/scripts/validate_subagent.py <path-to-agent>.md
```

스크립트가 설치된 위치에서도 같은 `uv run --with pyyaml --python 3.11` 명령과 skill 디렉터리 기준 경로를 쓴다(예: `~/.claude/skills/subagent-creator/scripts/validate_subagent.py`). 공용 validator가 malformed YAML, 알 수 없는 field와 tool 이름을 오류로 처리한다. 오류를 고친 뒤 다시 돌려 통과를 확인한다.

## 작성 모범 사례

- **단일 책임.** 하나의 subagent는 한 가지 일을 잘하게 한다. "리뷰도 하고 배포도 하는" 에이전트보다 좁고 명확한 에이전트가 위임도 잘 되고 동작도 예측 가능하다.
- **description은 위임 트리거다.** 무엇을 하는지뿐 아니라 **언제** 호출되어야 하는지를 써야 자동 위임이 동작한다.
- **tools 최소화.** 권한이 좁을수록 안전하고, 모델이 곁길로 새지 않는다.
- **출력 계약을 명시.** subagent의 최종 메시지가 메인 스레드로 돌아간다. 무엇을 반환할지 본문에 정해두면 결과를 다루기 쉽다.

## 예시: 코드 리뷰어 subagent

**Input:** "방금 수정한 코드를 커밋 전에 리뷰해주는 에이전트 만들어줘"

**Output** (`.claude/agents/code-reviewer.md`):
```markdown
---
name: code-reviewer
description: 코드 리뷰 전문가. 코드를 작성·수정한 직후, 커밋 전에 proactively 사용한다. "리뷰해줘", "커밋 전에 봐줘" 같은 요청에도 위임한다.
tools: Read, Grep, Glob, Bash
model: sonnet
---

너는 시니어 코드 리뷰어다. 변경된 코드의 정확성·가독성·보안을 점검한다.

호출되면:
1. `git diff`로 변경 사항을 파악한다.
2. 버그·엣지케이스·보안 문제·중복을 우선 검토한다.
3. 발견을 심각도(치명/경고/제안)별로 분류해 보고한다.

각 지적은 파일:라인과 함께 구체적 수정안을 제시한다. 범위 밖의 리팩터링은 제안하되 강요하지 않는다.
```
