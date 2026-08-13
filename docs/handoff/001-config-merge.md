# Codex·Claude 사용자 설정 보존 병합

- 상태: 완료
- 스펙 출처: GitHub Issue #7 `fix(install): Codex·Claude 설정 병합에서 사용자 설정 보존`
- 날짜: 2026-08-11

## 무엇을 만들었나

Windows와 Unix installer가 기존 Codex TOML 값을 우선하고, 저장소의 누락된 값만 추가하도록 통일했다. Claude `settings.json`과 Codex `hooks.json`은 사용자 scalar/nested 설정과 hook을 보존하며, dotfiles가 관리하는 hook command만 canonical 값으로 upsert·dedupe한다. 동일 입력의 두 번째 병합은 결과를 바꾸지 않으며, 유효하지 않은 기존 TOML은 수정하지 않는다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.ps1` | `yq` 기반 TOML 사용자 우선 병합, 유효성 검사·임시 파일 교체, 공용 JSON 병합 호출 |
| `install.sh` | Windows와 같은 TOML/JSON 병합 의미 적용 |
| `scripts/merge-json-registry.jq` | 사용자 우선 deep merge와 managed hook command identity upsert 규칙 |
| `tests/install/config-merge.ps1` | Windows 병합 회귀 검증 |
| `tests/install/config-merge.sh` | Unix 병합 회귀 검증 |

## 설계 결정

TOML은 두 installer 모두 `yq eval-all`의 `source * existing-destination` semantic merge를 사용한다. 따라서 일반 table, dotted key, array-of-tables를 별도 parser 없이 처리하고 기존 사용자 값이 충돌 시 이긴다. source와 destination을 먼저 parse하고, 병합 결과도 다시 parse한 뒤 임시 파일로 교체하므로 어느 단계든 실패하면 기존 destination은 바뀌지 않는다.

JSON 병합 규칙은 두 installer에 복제하지 않고 `scripts/merge-json-registry.jq` 한 파일로 공유한다. 일반 scalar와 nested 충돌은 기존 사용자 값이 이기며, 예외는 command 문자열로 identity가 명확한 저장소 관리 hook뿐이다. 관리 hook은 기존 중복을 제거한 뒤 source의 canonical 항목을 한 번 추가한다.

## 가정

- `jq`와 `yq`는 각 플랫폼 package 단계에서 설치된다.
- 저장소가 관리하는 hook의 identity는 `type=command`일 때의 `command` 문자열이다.
- 저장소 source JSON/TOML 자체의 유효성은 CI 정적 검증이 보장한다.

## 검증

| 명령 | 결과 |
|---|---|
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS — TOML/AOT/dotted/JSON 병합, malformed source/destination·yq 부재 시 원본 보존, hook dedupe, 멱등성 |
| `bash tests/install/config-merge.sh` | PASS — Windows와 동일 시나리오 |
| PowerShell AST parse (`install.ps1`) | PASS |
| `bash -n install.sh tests/install/config-merge.sh` | PASS |
| `jq -s -f scripts/merge-json-registry.jq` smoke check | PASS |
| `git diff --check` | PASS |

## QA 확인 필요

1. 기존 `~/.codex/config.toml`에 `[features] # user`만 둔 뒤 설치한다. 결과가 `yq -p=toml -o=json '.'`을 통과하고 top-level `model`이 한 번만 존재하는지 확인한다.
2. Claude/Codex SessionStart에 사용자 sentinel과 temporal-context 중복 command를 넣고 설치를 두 번 실행한다. sentinel은 남고 temporal-context는 정확히 하나이며 두 번째 결과가 첫 번째와 동일해야 한다.
3. 기존 사용자 `model`, `env` 충돌 값, `language`, `permissions`를 source와 다르게 지정한다. 설치 후 사용자 값이 유지되고 source의 누락 항목만 추가되어야 한다.
4. malformed source/destination TOML/JSON을 입력하거나 `yq`가 없는 상태로 실행한다. 경고 후 원본 byte가 바뀌지 않아야 한다.
5. `[[mcp_servers]]` 같은 array-of-tables로 시작하는 기존 TOML을 병합한다. source top-level 기본값이 배열 항목이 아니라 문서 top-level에 추가되어야 한다.
6. `windows.sandbox = "unelevated"`와 `features.hooks = false`를 dotted key로 지정한다. 사용자 값은 유지되고 누락된 source key만 동일한 TOML 의미로 추가되어야 한다.

## 알려진 제약

- 실제 all-in-one installer는 package 설치 등 호스트 side effect 때문에 실행하지 않았고 병합 함수를 격리 실행했다.
- `yq` semantic merge는 TOML을 재직렬화하므로 최초 병합 때 사용자 comment와 formatting이 정규화될 수 있다. 이후 같은 입력의 결과는 byte 단위로 멱등이다.
- 기존 JSON을 병합할 때 `jq`, 기존 TOML을 병합할 때 `yq`가 없으면 안전을 위해 기존 파일을 그대로 둔다.

## 후속 작업

- Issue #8: Windows·Unix·macOS profile 배포 멱등화
