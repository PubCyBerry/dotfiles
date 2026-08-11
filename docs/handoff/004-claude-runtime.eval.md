# 평가: Claude role 모델과 SessionStart context 복구

- **판정: PASS**
- 대상 인수인계: `docs/handoff/004-claude-runtime.md`
- 스펙 출처: GitHub Issue #11 `fix(claude): role 모델 선택과 SessionStart context 전달 복구`
- 날짜: 2026-08-11

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | `config/claude/settings.json:4-10`에 global model override가 없고, `scripts/merge-json-registry.jq:55`가 기존 설치의 legacy key도 제거한다. 세 role은 각각 `claude.frontmatter:5`에서 `model: opus`이며 hook은 `config/claude/hooks/temporal-context.sh:3-4`에서 공식 SessionStart JSON을 출력한다. |
| 검증 | 4 | 4 | feature contract, Bash/PowerShell installer 회귀, shell syntax, JSON parse, issue 원문 validation을 모두 재실행해 exit 0을 확인했다. 실제 Claude Code 세션의 model telemetry는 실행하지 않았지만 인수인계가 이를 제약으로 정확히 공개했다. |
| 깊이 | 4 | 3 | `tests/claude/runtime-contract.sh:14-26`이 legacy key 삭제와 사용자 env/hook 보존을 함께 검사하고, `tests/install/config-merge.sh:136-174` 및 PowerShell 대응 테스트가 재실행 멱등성·invalid JSON 보존·Codex 공용 filter 파급을 검사한다. 동일 SessionStart matcher의 사용자 hook 보존도 추가 경계 입력으로 확인했다. |
| 코드 품질 | 4 | 3 | 두 installer가 이미 공유하는 단일 jq filter에 tombstone 한 줄만 추가해 경로별 중복을 만들지 않았다. hook도 기존 4줄 구조를 유지하며 임시 abstraction이나 신규 dependency가 없다. |
| 통합 | 4 | 3 | Windows `Merge-JsonRegistry` 호출은 `install.ps1:593-598`, Bash 호출은 `install.sh:834-838`에서 같은 filter로 연결된다. 양 플랫폼 회귀가 PASS했고 Codex registry의 기존 sentinel/dedupe 결과도 유지됐다. |
| 안전성 | 4 | 4 | 삭제 대상은 정확히 `.env.CLAUDE_CODE_SUBAGENT_MODEL` 하나이며 다른 사용자 env/hook은 보존됐다. 기존 JSON이 invalid이면 installer가 원본을 유지하고, hook의 날짜 문자열은 고정 형식이라 JSON 주입 표면이 없다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| 전역 subagent model override 제거 | 충족 | `config/claude/settings.json:4-10`, `scripts/merge-json-registry.jq:55`; Issue validation `jq -e '.env.CLAUDE_CODE_SUBAGENT_MODEL == null' ...` PASS |
| planner/generator/evaluator의 `model: opus` 적용 | 충족 | 각 `config/agents/roles/*/claude.frontmatter:5`; 공식 model 선택 순위에서 env가 frontmatter보다 우선하므로 legacy env 삭제 후 frontmatter가 유효함 |
| 기존 destination의 legacy key만 제거하고 사용자 env/hooks 보존 | 충족 | `tests/claude/runtime-contract.sh:14-26`; shared filter 직접 경계 입력 결과 `true`; 양 installer가 filter를 호출하는 경로 확인 |
| `hookEventName`이 `SessionStart` | 충족 | `config/claude/hooks/temporal-context.sh:4`, runtime contract `:38` |
| `additionalContext`에 현재 날짜/시간 포함 | 충족 | hook `:3-4`, runtime contract의 정규식 `:39`; 공식 SessionStart context schema와 일치 |
| stdout은 한 줄 valid JSON이고 `suppressOutput`/`currentDateTime`에 의존하지 않음 | 충족 | runtime contract `:34-42`; 실제 실행 및 jq parse PASS |
| temporal hook 유지, caveman hook 비복원 | 충족 | `config/claude/settings.json:18-29`에는 temporal hook만 있고 runtime contract `:8-12`가 hooks 내 caveman 문자열 부재를 검증 |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `bash tests/claude/runtime-contract.sh` | PASS | `Claude runtime contract: PASS` |
| `bash tests/install/config-merge.sh` | PASS | `config merge regression checks passed` |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS | `config merge regression checks passed` |
| `bash -n config/claude/hooks/temporal-context.sh tests/claude/runtime-contract.sh` | PASS | exit 0 |
| `jq -e . config/claude/settings.json` | PASS | valid JSON |
| `git diff --check -- config/claude/hooks/temporal-context.sh config/claude/settings.json scripts/merge-json-registry.jq tests/claude/runtime-contract.sh docs/handoff/004-claude-runtime.md` | PASS | exit 0 |
| `bash config/claude/hooks/temporal-context.sh \| jq -e '...'` | PASS | `true`; Issue의 hook validation 재실행 |
| `jq -e '.env.CLAUDE_CODE_SUBAGENT_MODEL == null' config/claude/settings.json` | PASS | `true`; Issue의 settings validation 재실행 |
| legacy env + 동일 SessionStart 사용자/관리 hook을 shared filter에 입력 | PASS | `true`; legacy key만 삭제되고 두 sentinel 및 관리 hook이 각각 1개 유지됨 |

## 결함

확인된 결함 없음.

## 자체 평가 대조

일치. 인수인계가 보고한 모든 검증을 재실행해 같은 결과를 얻었다. 실제 Claude Code 프로세스를 통한 model/context 관찰은 수행하지 않았다는 제약도 정확히 명시되어 있다. `config/claude/settings.json`의 override 삭제가 작업 전 사용자 변경이라는 provenance 역시 보존되어 있다.

## 판정 근거

공식 Claude Code 문서는 `CLAUDE_CODE_SUBAGENT_MODEL`이 role frontmatter보다 우선한다고 명시하고, SessionStart context 출력으로 `hookSpecificOutput.hookEventName`과 `additionalContext`를 제시한다. 구현은 이 계약과 일치하며 모든 축이 하한 이상이고 FAIL 규칙에 해당하지 않는다.
