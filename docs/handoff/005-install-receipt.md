# 설치 소유권 receipt

- 상태: 완료
- 스펙 출처: GitHub Issue #10 `feat(install): managed artifact ownership receipt 도입`
- 날짜: 2026-08-12

## 무엇을 만들었나

Windows는 `%LOCALAPPDATA%\dotfiles\install-receipt.json`, Unix는 `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-receipt.json` 하나에 설치 전 상태와 마지막 설치 상태를 기록한다. generic 설정 파일은 mutation 전에 pending 상태를 저장하고 첫 takeover 때 한 번만 backup한다. 이후에는 현재 hash가 마지막 설치 hash와 같을 때만 갱신하며, 중단 후에는 target hash로 안전하게 복구한다. 동명 skill·agent·hook과 사용자가 수정한 managed 값은 경고 후 보존한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.ps1` | atomic receipt, artifact/package/Git/env 기록, 파일별 안전 배포, winget/npm snapshot |
| `install.sh` | jq 기반 atomic receipt, 파일별 안전 배포, brew/apt/npm snapshot, fresh jq bootstrap |
| `tests/ownership/install-receipt.ps1` | Windows ownership 계약 회귀 테스트 |
| `tests/ownership/install-receipt.sh` | Unix ownership 계약 회귀 테스트 |

## 설계 결정

- receipt는 `artifacts`, `packages`, `values` 세 map만 둔다. `before`는 최초 기록 후 바꾸지 않고 성공한 설치 상태만 갱신한다.
- 최초 takeover와 이후 managed update 모두 copy 전에 `pending` entry를 atomic 저장한다. backup도 journal 뒤에 한 번만 만들고, 중단 후에는 previous/target hash 중 하나가 일치할 때만 복구한다.
- 기존 파일이 source와 이미 동일하면 backup하거나 receipt 소유권을 주장하지 않는다. receipt 경로의 directory·symlink와 artifact 경로의 directory·symlink는 fail-closed한다.
- tmux/Yazi/Neovim/Starship/global instructions와 semantic merge 결과는 generic takeover 대상으로 삼는다. directory는 source 파일만 순회해 destination의 extra 파일을 보존한다.
- skill은 existing root 전체를 사용자 소유로 보고, agent와 hook은 동명 파일만 충돌로 본다.
- historical legacy Codex skill은 정확한 고정 identity가 없으므로 기존 이름 기반 자동 삭제를 제거했다. 추정 hash manifest는 만들지 않았다.
- Windows receipt JSON은 winget으로 jq가 설치되기 전에도 기록해야 하므로 PowerShell 내장 JSON 변환을 bootstrap 경로로 사용한다. 검증 assertion은 jq로 수행한다.
- PATH는 전체 값을 저장하지 않고 installer가 추가한 entry와 `before.present`만 기록한다. token/secret/password/credential 이름의 scalar는 기록하지 않되, 값이 비밀이 아닌 repo 관리 Git 설정 `credential.credentialStore`만 명시적으로 허용한다.
- managed file은 destination의 모든 parent component를 검사해 중간 symlink/reparse point를 따라가지 않는다.

## 가정

- package receipt 대상은 manifest 기반 package manager 항목(winget, brew, apt, npm global)이다. 공식 install script와 GitHub release binary의 provenance/checksum은 Issue #16 범위다.
- 기존 legacy skill의 안전한 제거는 receipt 또는 검증 가능한 known hash가 생긴 뒤에만 가능하다.

## 검증

| 명령 | 결과 |
|---|---|
| `pwsh -NoProfile -File tests/ownership/install-receipt.ps1` | PASS |
| `bash tests/ownership/install-receipt.sh` | PASS |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS |
| `bash tests/install/config-merge.sh` | PASS |
| `pwsh -NoProfile -File tests/profile/profile-idempotency.ps1` | PASS |
| `bash tests/profile/profile-idempotency.sh` | PASS |
| PowerShell parser: `install.ps1`, `tests/ownership/install-receipt.ps1` | PASS |
| `bash -n install.sh tests/ownership/install-receipt.sh` | PASS |
| `git diff --check` | PASS |
| WSL `shellcheck -x install.sh tests/ownership/install-receipt.sh` | PASS |
| WSL `bash tests/ownership/install-receipt.sh` | PASS |

## QA 확인 필요

1. 양 ownership 테스트를 재실행한다. 테스트 자체가 HOME/USERPROFILE/APPDATA/receipt를 임시 root 아래로 격리하고, sentinel, 1회 backup, managed update 중단 복구, mismatch preserve, invalid/partial/symlink receipt, no-secret, package/Git/PATH entry를 검증한다.
2. Linux fresh VM에서 jq가 없는 상태로 installer를 실행한다. jq가 단독 bootstrap되고 receipt가 유효한 JSON으로 생성된 뒤 apt bulk가 진행되어야 한다.
3. brew/apt bulk를 일부 성공 후 실패하도록 mock한다. 성공한 before→after delta가 기록된 뒤 원래 실패 코드가 전파되어야 한다.
4. 기존 hook directory에 unrelated 파일과 동명 hook sentinel을 둔다. unrelated 파일과 동명 sentinel은 보존되고, 충돌하지 않는 source hook만 추가되어야 한다.

## 자체 평가

- 스펙 충족도: 플랫폼별 atomic receipt, immutable before, hash gate, collision policy, package/Git/env 기록, legacy 이름 삭제 제거를 구현했다.
- 검증 상태: Windows/Git Bash/WSL functions-only 격리 테스트, 기존 config/profile/runtime/fnm 회귀와 CI 동일 ShellCheck 명령을 통과했다. 실제 winget/brew/apt 실행은 호스트 변경을 피하려고 수행하지 않았다.
- 약한 곳: macOS 기본 Bash/Homebrew와 실제 Linux package partial failure는 이 Windows host에서 실행 검증하지 못했다.
- 부작용 위험: semantic merge 파일도 artifact hash gate를 적용하므로 설치 후 사용자가 수정하면 다음 실행은 새 repo default를 merge하지 않고 파일 전체를 보존한다. 이는 overwrite 방지 우선 정책이다.
- 판정: 완료.

## 알려진 제약

- Windows backup은 `%LOCALAPPDATA%`/사용자 profile의 기존 ACL을 상속한다. Unix backup과 receipt는 mode 0600, receipt directory는 0700으로 설정한다.
- legacy Codex skill cleanup은 수행하지 않는다. 이름만으로 사용자 directory를 판별할 수 없기 때문이다.
- 전체 transactional rollback은 제공하지 않는다. pending receipt가 중단 후 안전한 재시도를 담당한다.

## 후속 작업

- Issue #12: validator/문서 계약 정리
- Issue #13: macOS fresh/second install 검증
- Issue #16: 직접 다운로드 artifact/symlink의 pin·checksum·receipt identity
- Issue #14: receipt 기반 safe uninstall과 검증 가능한 legacy cleanup
