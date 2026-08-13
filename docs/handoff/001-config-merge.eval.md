# 평가: Codex·Claude 사용자 설정 보존 병합

- **판정: PASS**
- 대상 인수인계: `docs/handoff/001-config-merge.md`
- 스펙 출처: GitHub Issue #7 `fix(install): Codex·Claude 설정 병합에서 사용자 설정 보존`
- 날짜: 2026-08-11

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | 일반 table, section-only, AOT, dotted key에서 기존 값을 보존하고 누락 source 값만 추가한다. Claude/Codex hook도 sentinel 보존과 managed command 단일화를 충족한다. |
| 검증 | 4 | 4 | Windows와 Bash 회귀 테스트, PowerShell AST parse, `bash -n`, `git diff --check`를 직접 재실행해 모두 통과했다. |
| 깊이 | 4 | 3 | malformed TOML/JSON 원본 보존, inline section comment, AOT 경계, dotted section identity, 두 번째 실행 byte 멱등성을 검증한다. |
| 코드 품질 | 4 | 3 | TOML은 공용 `yq` semantic merge로 단순화했고 JSON 병합 규칙은 공용 jq filter로 통합했다. handwritten parser 중복이 제거됐다. |
| 통합 | 4 | 3 | Windows와 Unix가 같은 add-if-missing 의미를 제공하며 기존 scalar, nested 설정, 다른 event hook과 사용자 model/sandbox 값을 보존한다. |
| 안전성 | 4 | 4 | invalid 입력이나 병합 실패 시 원본을 유지하고, 임시 파일 검증 후 교체하며 사용자의 sandbox·permission·hook 선택을 덮어쓰지 않는다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| Codex top-level key를 한 번만 출력 | 충족 | section-only와 AOT fixture에서 top-level `model`의 위치·개수 및 TOML 유효성 검증 통과 |
| 기존 사용자 model/section 값을 보존 | 충족 | `model = "user-model"`, `windows.sandbox = "unelevated"`, `features.hooks = false` 유지 검증 통과 |
| 누락 source key만 add-if-missing | 충족 | dotted 입력의 사용자 값을 보존하면서 누락 `features.remote_control = true`를 semantic table에 추가함 |
| Claude env/permissions/hooks를 identity 기준으로 병합 | 충족 | 사용자 env 충돌값, permission allow, SessionStart/PreToolUse sentinel 보존 및 managed hook dedupe 검증 통과 |
| Codex hooks registry의 managed command upsert/dedupe | 충족 | 사용자 sentinel 보존과 temporal-context 단일화 검증 통과 |
| Windows와 Unix 병합 의미 통일 | 충족 | 양 플랫폼 테스트가 동일한 fixture와 semantic assertion을 통과 |
| 두 번째 실행 결과 동일 | 충족 | TOML, dotted TOML, Claude settings, Codex hooks의 hash/cmp 검증 통과 |
| malformed 입력 원본 보존 | 충족 | malformed TOML과 JSON의 원본 hash/cmp 검증 통과 |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS | table/AOT/dotted TOML, malformed source/destination, yq 부재, JSON sentinel, 멱등성 |
| `bash tests/install/config-merge.sh` | PASS | Windows와 동일한 회귀 시나리오 |
| PowerShell AST parse (`install.ps1`) | PASS | parser error 0건 |
| `bash -n install.sh tests/install/config-merge.sh` | PASS | shell syntax 정상 |
| `git diff --check` | PASS | whitespace 오류 없음 |

malformed JSON fixture의 parse error는 의도한 실패 경로이며, 테스트는 원본 byte가 유지됐음을 확인한 뒤 통과했다.

## 결함

평가 범위 내 통과를 막는 결함 없음.

## 자체 평가 대조

인수인계의 구현 설명, 알려진 제약, QA 기대와 검증 PASS 주장은 실제 코드와 재실행 결과에 일치한다.
