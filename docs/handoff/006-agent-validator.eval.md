# 평가: Agent validator 단일화

- **판정: PASS**
- 대상 인수인계: `docs/handoff/006-agent-validator.md`
- 스펙 출처: GitHub Issue #12 `refactor(validation): agent validator와 관련 문서를 단일화`
- 날짜: 2026-08-12
- 재평가: 두 차례 재작업을 반영한 최신 working tree 기준

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | 공용 engine, malformed/unknown/tool 오류 검출, 최신 field/model, 공식 tool·MCP 경계, Claude/Codex 조립 및 독립 배포 요구를 모두 충족한다. |
| 검증 | 5 | 4 | 명시된 uv 명령 2개, unittest 9개, 독립 wrapper, workflow YAML, diff 검사와 별도 positive/negative tool probe가 모두 통과했다. |
| 깊이 | 4 | 3 | malformed YAML, field 자료형·경계값, unknown key/tool, MCP 빈 segment, subagent filter, 조건부 tool, 독립 배포와 양 플랫폼 조립 실패 경로를 검사한다. |
| 코드 품질 | 4 | 3 | 두 CLI가 작은 공용 engine 하나를 재사용한다(`scripts/validate-agent-roles.py:23-32`, `validate_subagent.py:9`). 공식·legacy·조건부 tool 정책이 코드, 테스트, 문서에서 일치한다. |
| 통합 | 4 | 3 | repository role 3개 조립이 parse되고, skill scripts만 복사한 환경에서도 wrapper가 동작하며, 동일 검증이 PR Gate에 연결됐다. |
| 안전성 | 5 | 4 | `yaml.safe_load`를 사용하고(`agent_validator.py:146`) 검증기는 읽기·파싱만 수행한다. tool 검증은 fail-closed이며 데이터 손실·비밀 노출·권한 우회 경로가 없다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| PyYAML/TOML 기반 공용 validator 하나로 통합 | 충족 | `scripts/validate-agent-roles.py:23-32`와 `config/claude/skills/subagent-creator/scripts/validate_subagent.py:9`가 같은 `agent_validator.py`를 import한다. |
| malformed YAML, unknown key, tool 오타 실패 | 충족 | `agent_validator.py:119-127`, `agent_validator.py:145-154`; `tests/test_agent_role_validation.py:90-108`, `tests/test_agent_role_validation.py:118-122`. |
| `effort`, `maxTurns`, `skills`, `isolation`, `hooks`, `fable` 통과 | 충족 | valid fixture `tests/test_agent_role_validation.py:20-56`와 `test_current_fields_and_fable_pass`; unittest 9개 통과. |
| 최신 Claude field와 `permissionMode: manual` 처리 | 충족 | `CLAUDE_KEYS`와 enum이 공식 supported fields 및 `manual` alias를 포함한다(`agent_validator.py:18-35`, `agent_validator.py:77-85`). |
| 공식 core/MCP tool 경계 처리 | 충족 | 유효 9개는 두 field에서 통과하고, 모든-subagent 금지 7개와 undocumented legacy 5개는 두 field에서 실패한다(`tests/test_agent_role_validation.py:57-83`, `tests/test_agent_role_validation.py:110-133`). `ExitPlanMode`, `Agent`, `Task`는 유지됨을 별도 probe로 확인했다. |
| Windows에서 `python3`/전역 PyYAML 없이 실행 | 충족 | PowerShell에서 `$env:PYTHONDONTWRITEBYTECODE='1'`과 두 `uv run --with pyyaml --python 3.11` 명령이 exit 0. 오래된 validator 실행문 검색도 일치 없음. |
| 현재 Claude/Codex 조립 결과 parse | 충족 | repository validator가 `PASS — role 3개: evaluator, generator, planner`; 조립 회귀 테스트도 통과했다. |
| scripts 디렉터리만 배포된 wrapper 동작 | 충족 | `tests/test_agent_role_validation.py:163-176`; 대상 단일 unittest가 exit 0. |
| 로컬/CI 명령을 uv로 통일 | 충족 | `.github/workflows/pr-gate.yml:238-244`, `AGENTS.md`, 직접 재실행 결과. |
| stale CONTEXT와 관련 문서 정리 | 충족 | `CONTEXT.md:1-14`; `rg -n "caveman" CONTEXT.md` 결과 없음. `agent-format.md:64-65`에 공식 링크와 availability 경계가 추가됐다. |

## 공식 Claude 대조

- 평가 시 설치본: `claude --version` → `2.1.228 (Claude Code)`.
- [공식 subagent 문서](https://code.claude.com/docs/en/sub-agents)의 supported fields, `fable`, `permissionMode: manual`, MCP server/exact/wildcard 표기와 구현이 일치한다.
- [공식 tools reference](https://code.claude.com/docs/en/tools-reference)의 current tool 이름 및 subagent filter를 기준으로 대조했다.
- 모든 subagent에서 제거되는 7개(`AskUserQuestion`, `EndConversation`, `EnterPlanMode`, `ScheduleWakeup`, `TaskOutput`, `WaitForMcpServers`, `Workflow`)와 현재 문서에 없는 legacy 5개(`BashOutput`, `KillBash`, `KillShell`, `MultiEdit`, `SlashCommand`)는 두 tool field에서 모두 거부된다.
- 조건부로 유효한 `ExitPlanMode`, `Agent`와 공식 backward-compatible alias `Task`는 두 tool field에서 통과한다. 문서도 foreground/background, teammate, 기능, `permissionMode`, delegation depth에 따른 가용성 차이를 명시한다(`agent-format.md:64-65`).

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `$env:PYTHONDONTWRITEBYTECODE='1'; uv run --with pyyaml --python 3.11 scripts/validate-agent-roles.py` | PASS | exit 0, role 3개. unrelated uv managed-Python 경고는 인수인계와 동일. |
| `$env:PYTHONDONTWRITEBYTECODE='1'; uv run --with pyyaml --python 3.11 -m unittest discover -s tests -p test_agent_role_validation.py` | PASS | exit 0, `Ran 9 tests`, `OK`. |
| `$env:PYTHONDONTWRITEBYTECODE='1'; uv run --with pyyaml --python 3.11 -m unittest tests.test_agent_role_validation.ClaudeAgentValidatorTests.test_subagent_creator_wrapper_uses_same_rules` | PASS | exit 0, scripts-only 독립 배포 wrapper. |
| inline uv probe: 유효 9개 × `tools`/`disallowedTools` | PASS | 18개 모두 오류 없음. |
| inline uv probe: 금지 7개 + legacy 5개 × 두 field | PASS | 24개 모두 해당 tool 이름을 포함한 오류 반환. |
| inline uv probe: `ExitPlanMode`, `Agent`, `Task` × 두 field 및 `CronCreat` | PASS | 조건부/alias 6개 오류 없음, 근접 오타는 오류. |
| `yq eval '.' .github/workflows/pr-gate.yml` | PASS | exit 0, workflow YAML 출력. |
| `git diff --check` | PASS | exit 0, 출력 없음. |
| `rg -n "caveman" CONTEXT.md` | PASS | 기대대로 일치 없음. |
| 오래된 `python3 ...validate-agent-roles`/`python ...validate_subagent` 실행문 `rg` 검색 | PASS | 대상 문서·workflow에서 일치 없음. |

## 결함

확인된 결함 없음.

## 자체 평가 대조

일치. 인수인계의 validator/unittest/yq/diff 결과, tool filter 정책, 알려진 runtime 미검증 범위를 실제 코드·문서 및 재실행 결과와 대조했다.
