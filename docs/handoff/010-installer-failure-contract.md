# Installer 실패 전파와 실제 CI 계약

- 상태: 완료
- 스펙 출처: GitHub Issue #15
- 날짜: 2026-08-13

## 무엇을 만들었나

Windows와 Unix installer가 필수 단계 실패를 공통 ledger에 모아 마지막에 명시적인 exit code로 종료하며 실패 시 `Done`을 출력하지 않는다. Plugin manifest는 어떤 `claude` mutation보다 먼저 전체 검증하고, PR Gate는 중복 workflow 대신 실제 installer의 fresh/update 경로를 실행한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.ps1`, `install.sh` | failure ledger, 필수 CLI/manifest 실패 전파, plugin/skill 사전검증 |
| `tests/install/failure-contract.*` | ledger, Done 억제, skip zero-call, manifest snapshot, CLI 실패 계약 |
| `.github/workflows/pr-gate.yml` | Ubuntu 중복 job 통합, Windows fake profile 2회, Python shim 호출 제거 |
| `.github/workflows/uninstall-validation.yml` | Windows HOME/Git config 격리 강화 |
| `.github/workflows/precision-validation.yml` | 실제 installer를 복제하던 workflow 삭제 |
| `config/codex/config.toml`, `tests/install/config-merge.*` | 제거된 feature flag 삭제 및 부재 회귀 |
| `manifests/apt.txt` | 중복 `git` 제거 |
| `docs/ci-pipelines.md` | 현재 3개 workflow와 검증 계약 동기화 |

## 설계 결정

기존 receipt의 즉시 fatal 경로는 그대로 두고, 과거 경고로 삼키던 package/fnm/npm/skill/plugin 실패만 하나의 ledger로 모은다. 실패 후에도 독립적인 설정 배포는 계속해 한 번의 실행에서 필요한 재시도 항목을 모두 보여주되 최종 성공은 주장하지 않는다. Plugin/skill parser는 installer helper 하나를 테스트에서도 직접 호출한다.

## 가정

`SKIP_*`는 해당 외부 단계 전체를 명시적으로 제외하는 CI 계약이다. 사용자 저장소에 이미 배포된 제거 대상 Codex feature key는 migration하지 않고 source default에서만 제거한다.

## 검증

| 명령 | 결과 |
|---|---|
| `pwsh -NoProfile -File tests/install/failure-contract.ps1` | PASS |
| `bash tests/install/failure-contract.sh` | PASS |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS |
| `bash tests/install/config-merge.sh` | PASS |
| `bash -n install.sh tests/install/failure-contract.sh tests/install/config-merge.sh` | PASS |
| `wsl bash -lc '... shellcheck -x install.sh tests/install/failure-contract.sh tests/install/config-merge.sh'` | PASS |
| `yq '.' .github/workflows/pr-gate.yml` | PASS |
| `yq '.' .github/workflows/uninstall-validation.yml` | PASS |
| `rg -n 'python3|precision-validation|test-idempotent' .github docs/ci-pipelines.md` | PASS(일치 없음) |
| `git diff --check` | PASS |

## QA 확인 필요

1. GitHub Actions에서 Ubuntu/macOS/Windows 실제 install 2회가 통과하는지 확인한다.
2. Windows disposable runner에서 profile/Git 경로가 격리되고 User PATH/YAZI가 uninstall 후 exact 복원되는지 확인한다.
3. 실제 외부 package manager가 실패할 때 summary가 `Done` 없이 nonzero인지 확인한다.

## 알려진 제약

로컬 Windows에서는 host installer를 실행하지 않았다. Failure ledger가 생긴 뒤 후속 독립 설정 단계는 계속 실행된다.

## 후속 작업

없음.
