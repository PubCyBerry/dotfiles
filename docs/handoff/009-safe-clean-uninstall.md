# Receipt 기반 Safe-Clean-Uninstall

- 상태: 완료
- 스펙 출처: GitHub Issue #14
- 날짜: 2026-08-13

## 무엇을 만들었나

Windows, Ubuntu, macOS에서 receipt v1의 exact identity만 되돌리는 `uninstall.ps1`/`uninstall.sh`를 추가했다. 변경되거나 provenance가 부족한 artifact, value, package는 그대로 두고 receipt entry와 경고를 남기며, 완료 entry마다 receipt를 atomic 저장한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `uninstall.sh`, `uninstall.ps1` | Safe-Clean-Uninstall 실행기 |
| `install.sh`, `install.ps1` | npm prefix와 Unix file mode provenance 보강 |
| `tests/uninstall/safe-clean.*` | 격리된 representative safety fixture |
| `tests/ownership/install-receipt.sh` | mode provenance 계약 동기화 |
| `.github/workflows/uninstall-validation.yml` | 복제 cleanup 제거, 실제 script 2회 실행 |
| `docs/uninstall.md` | 실행법과 exact safety contract |

## 설계 결정

receipt path, 전체 entry shape, artifact/package/value key를 mutation 전에 allowlist 검증한다. artifact path는 repo source에서 파생되는 leaf, 고정 direct binary와 versioned nvim tree만 허용하고 agent/direct-bin은 exact direct child만 받는다. package key는 manifest와 OS별 Claude package에서만 파생하며 npm은 exact `FNM_DIR/node-versions/<version>/installation` recorded prefix에서만 조회·제거한다. jq terminal removal은 exact single-line marker byte와 제거 후 definitive-absent query로 crash retry를 수렴시킨다.

## 가정

Windows receipt artifact는 file entry만 생성한다. Unix direct tree는 현재 installer 계약대로 fresh versioned target만 역변환한다.

## 검증

| 명령 | 결과 |
|---|---|
| `pwsh -NoProfile -File tests/uninstall/safe-clean.ps1` | PASS |
| Git Bash `bash tests/uninstall/safe-clean.sh` | PASS (`safe-clean uninstall bash: PASS`) |
| macOS matrix `bash tests/uninstall/safe-clean.sh` | workflow에 동일 fixture 등록(Bash 3.2 case mock, Darwin direct-tree mock); 로컬 macOS 실행 환경 없음 |
| `bash -n install.sh && bash -n uninstall.sh` | PASS |
| Git Bash `shellcheck -x install.sh uninstall.sh` | PASS |
| `yq '.' .github/workflows/uninstall-validation.yml` | PASS |
| `git diff --check` | PASS |
| `pwsh -NoProfile -File tests/ownership/install-receipt.ps1` | PASS |
| Git Bash `bash tests/ownership/install-receipt.sh` | PASS (`Unix install receipt: PASS`) |
| Git Bash `bash tests/ownership/direct-artifacts.sh` | PASS (`Direct artifacts: PASS`) |
| Git Bash `bash tests/fnm/non-destructive-install.sh` | PASS |

## QA 확인 필요

없음.

## 알려진 제약

macOS에서는 direct tree receipt를 만들지 않으므로 GNU `find`/`tar` 기반 direct-tree 역변환을 실행하지 않는다. receipt에 없는 legacy artifact는 자동 제거하지 않는다.

## 후속 작업

Issue #15 CI/installer 실패 계약 정리.
