# Claude role 모델과 SessionStart context 복구

- 상태: 완료
- 스펙 출처: GitHub Issue #11
- 날짜: 2026-08-11

## 무엇을 만들었나

Claude `SessionStart` hook이 현재 날짜/시간을 공식 `hookSpecificOutput.additionalContext` 계약으로 출력한다. 설치 병합 시 기존 환경에 남은 `CLAUDE_CODE_SUBAGENT_MODEL`만 제거해 role별 `model: opus`가 적용되며, 다른 사용자 env와 hook은 보존한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `config/claude/hooks/temporal-context.sh` | `SessionStart`의 공식 JSON context 출력으로 교체 |
| `scripts/merge-json-registry.jq` | 기존 설치의 legacy subagent model override를 병합 결과에서 제거 |
| `tests/claude/runtime-contract.sh` | model override tombstone, role frontmatter, hook JSON 계약 회귀 검증 |

`config/claude/settings.json`의 `CLAUDE_CODE_SUBAGENT_MODEL` 삭제는 이 작업 시작 전에 존재한 사용자 변경이다. 이 작업에서는 파일을 수정하거나 해당 변경의 저자권을 주장하지 않고 검증 입력으로만 사용했다.

## 설계 결정

- 이미 두 installer가 공유하는 JSON 병합 필터에서 legacy 키 하나만 제거한다. 설치 경로별 정리 코드는 추가하지 않았다.
- hook 출력은 저장소의 Codex temporal hook과 같은 구조를 사용한다.
- 모델 우선순위와 hook 출력은 Claude Code 공식 문서의 [subagent model 선택](https://code.claude.com/docs/en/sub-agents#choose-a-model), [SessionStart hook 계약](https://code.claude.com/docs/en/hooks#sessionstart)을 기준으로 했다.

## 가정

- `CLAUDE_CODE_SUBAGENT_MODEL`은 이 저장소가 과거에 배포한 전역 override이므로 기존 destination에 남아 있어도 제거 대상이다.
- 사용자별 model 선택은 각 role의 `claude.frontmatter`에서 관리한다.

## 검증

| 명령 | 결과 |
|---|---|
| `bash tests/claude/runtime-contract.sh` | PASS (`Claude runtime contract: PASS`) |
| `bash tests/install/config-merge.sh` | PASS (`config merge regression checks passed`) |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS (`config merge regression checks passed`) |
| `bash -n config/claude/hooks/temporal-context.sh tests/claude/runtime-contract.sh` | PASS |
| `jq -e . config/claude/settings.json` | PASS |
| `git diff --check -- config/claude/hooks/temporal-context.sh scripts/merge-json-registry.jq tests/claude/runtime-contract.sh` | PASS |

## QA 확인 필요

1. 기존 `~/.claude/settings.json`에 `CLAUDE_CODE_SUBAGENT_MODEL=haiku`, 사용자 env, 사용자 hook을 함께 둔 뒤 installer를 실행한다. legacy key만 제거되고 나머지는 남아야 한다.
2. hook stdout을 `jq`로 읽어 JSON 객체가 하나이며 `hookEventName=SessionStart`와 현재 시각 형식의 `additionalContext`만 전달되는지 확인한다.
3. 배포된 planner/generator/evaluator가 각 frontmatter의 `model: opus`로 선택되는지 실제 Claude Code 세션에서 확인한다.

## 알려진 제약

- 실제 Claude Code 프로세스의 모델 선택과 context 주입은 실행하지 않았고, 공식 설정·hook 계약을 정적/프로세스 테스트로 검증했다.
- shared JSON 병합 필터는 현재 Claude settings와 Codex hook registry가 함께 사용하므로 legacy 키 제거는 양쪽 입력에 적용되지만, Codex registry에는 해당 env 키가 없어 결과 변화가 없다.

## 후속 작업

- Issue #10: installer side effect 소유권 receipt 추가
