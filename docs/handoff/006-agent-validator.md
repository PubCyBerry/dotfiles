# Agent validator 단일화

- 상태: 완료
- 스펙 출처: GitHub Issue #12
- 날짜: 2026-08-12

## 무엇을 만들었나

Claude role 조립 검증과 `subagent-creator`의 단일 파일 검증이 같은 PyYAML 기반 engine을 사용한다. 최신 Claude frontmatter field, `fable`을 포함한 model 값, core/MCP tool 표기를 처리하며 malformed YAML·알 수 없는 key·tool 오타는 실패한다. 로컬과 CI 실행은 격리된 Python 3.11/PyYAML을 제공하는 동일한 `uv run` 명령을 사용한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `config/claude/skills/subagent-creator/scripts/agent_validator.py` | Claude YAML 공용 검증 engine 추가 |
| `scripts/validate-agent-roles.py` | 자체 YAML schema/parser를 제거하고 공용 engine 재사용 |
| `config/claude/skills/subagent-creator/scripts/validate_subagent.py` | 배포 후에도 인접 공용 engine을 호출하는 얇은 CLI로 축소 |
| `tests/test_agent_role_validation.py` | 신규 field, fable, MCP·filtered/forbidden core tool, malformed/unknown/typed 오류와 독립 배포 회귀 검증 |
| `.github/workflows/pr-gate.yml` | `setup-uv`와 Issue 검증 명령 추가, tests 경로 trigger 추가 |
| `config/claude/skills/subagent-creator/SKILL.md` | 최신 field와 uv 실행 절차 반영 |
| `config/claude/skills/subagent-creator/references/agent-format.md` | 현재 Claude frontmatter field 문서화 |
| `AGENTS.md`, `docs/ai-agents.md`, `docs/ci-pipelines.md` | uv validator와 공용 registry merge 동작으로 설명 갱신 |
| `CONTEXT.md` | 완료된 과거 작업 인계를 제거하고 장기 도메인 용어만 유지 |

## 설계 결정

- 공용 engine을 `subagent-creator/scripts/`에 둬 root validator가 가져다 쓰고, installer가 skill 디렉터리를 복사한 뒤에도 wrapper가 독립 동작하게 했다. 별도 패키징·설치 로직은 추가하지 않았다.
- model은 Claude alias뿐 아니라 provider별 model/deployment 이름도 받을 수 있어 비어 있지 않은 문자열만 검증한다. 따라서 `fable`과 이후 alias가 validator 갱신 없이 통과한다.
- core tool은 공식 subagent filter 후 실제 노출 가능한 이름만 exact allowlist로 두고, 모든 subagent에서 제거되는 tool과 현재 문서에 없는 legacy 이름은 거부한다. MCP tool은 공식 server/exact/wildcard 패턴으로 동적 이름을 허용한다.

## 가정

- role source에서는 저장소 규약대로 `name`이 role 디렉터리명과 같고, 단일 agent 파일에서는 파일 stem과 같아야 한다.
- `hooks`와 `mcpServers`는 이번 scope에서 top-level 자료형만 검사하고 Claude의 전체 nested schema를 복제하지 않는다.

## 검증

| 명령 | 결과 |
|---|---|
| `uv run --with pyyaml --python 3.11 scripts/validate-agent-roles.py` | PASS (`role 3개: evaluator, generator, planner`) |
| `uv run --with pyyaml --python 3.11 -m unittest discover -s tests -p test_agent_role_validation.py` | PASS (`Ran 9 tests`, `OK`) |
| `yq eval '.' .github/workflows/pr-gate.yml` | PASS |
| `git diff --check` | PASS |
| stale 명령/병합 설명 `rg` 검사 | PASS(의도한 uv 명령 외 일치 없음) |

두 `uv` 실행은 성공했지만, host의 uv managed Python 디렉터리에 존재하는 unrelated malformed entry(`exts`, `extscache`, `extsDeprecated`, `extsPhysics`, `isaacsim`) 경고가 stderr에 출력됐다. validator 결과에는 영향을 주지 않았다.

## QA 확인 필요

1. 테스트의 valid agent를 각 신규 field별로 줄여도 통과하고, field 이름을 `tool`처럼 바꾸면 오류와 exit 1이 나오는지 확인한다.
2. `mcp__server`, `mcp__server__*`, `mcp__server__tool`, `disallowedTools: mcp__*`는 통과하고 빈 segment(`mcp____tool`)는 실패하는지 확인한다.
3. Claude의 subagent filter 뒤에도 유효한 core tool 9개가 `tools`와 `disallowedTools`에서 통과하고 근접 오타 `CronCreat`는 실패하는지 확인한다.
4. 모든 subagent에서 제거되는 7개 tool과 현재 공식 문서에 없는 legacy tool 5개가 `tools`와 `disallowedTools` 양쪽에서 실패하는지 확인한다. `ExitPlanMode`와 `Agent`는 조건부 가용하므로 통과해야 한다.
5. `config/claude/skills/subagent-creator/scripts/`만 임시 디렉터리에 복사한 뒤 wrapper를 `uv run`으로 실행해 repo root 없이 동작하는지 확인한다.
6. GitHub Actions `test-agent-roles`가 setup-uv 후 두 검증 명령을 통과하는지 확인한다.

## 알려진 제약

- Claude의 subagent tool filter 결과가 바뀌면 typo 검출을 유지하기 위해 `CORE_TOOLS` 갱신이 필요하다. 현재 `ExitPlanMode`는 `permissionMode: plan`, `Agent`는 delegation depth 등 runtime 조건에 따라 실제 노출 여부가 달라지며, 문서에서 사라진 legacy 이름은 근거 없이 유지하지 않는다.
- hook event 내부와 inline MCP server 설정의 전체 schema는 Claude Code 자체가 최종 검증한다.
- 실제 Claude Code 프로세스에 agent를 load하는 runtime test는 실행하지 않았다.

## 자체 평가

- **스펙 충족도**: Issue #12의 parser 단일화, 오류 검출, 최신 field/model 처리, skill 재사용, uv CI/로컬 명령, stale 문서 정리를 모두 구현했다.
- **검증 상태**: 명시된 두 uv 명령과 workflow YAML, whitespace 검증이 통과했다. 실제 Claude Code load와 원격 GitHub Actions 실행은 미검증이다.
- **약한 곳**: 동적으로 늘어나는 core tool allowlist와 Claude가 소유한 nested hook/MCP schema는 후속 upstream 변경에 민감하다.
- **부작용 위험**: 과거에는 경고였던 알 수 없는 tool을 오류로 바꿨으므로, 새 공식 tool이 추가되면 validator와 allowlist를 함께 갱신해야 한다.
- **판정**: 완료.

## 후속 작업

- Issue #13: macOS fresh-install 경로와 문서를 현재 설치 계약에 맞게 정리한다.
