# 평가: 설치 소유권 receipt

- **판정: PASS**
- 대상 인수인계: `docs/handoff/005-install-receipt.md`
- 스펙 출처: GitHub Issue #10 `feat(install): managed artifact ownership receipt 도입`, 저장소 `AGENTS.md` Safe-Clean-Install 계약
- 날짜: 2026-08-12

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | 양 플랫폼 단일 receipt, immutable `before`, 1회 backup, hash gate, package/Git/env provenance와 재실행 복구가 요구대로 동작한다. `install.ps1:38-318`, `install.sh:43-325` |
| 검증 | 4 | 4 | Windows·Git Bash·WSL ownership, CI 동일 ShellCheck, config/profile/runtime/fnm 회귀, 실제 Git manifest merge, apt/brew/jq partial mock을 직접 재실행해 모두 통과했다. |
| 깊이 | 4 | 3 | invalid/partial receipt, journal write 실패, post-mutation crash, directory·broken/final/intermediate symlink, backup collision, user hash mismatch, jq bootstrap, bulk partial failure를 fail-closed 또는 복구 fixture로 검증한다. |
| 코드 품질 | 4 | 3 | 공용 file/tree/package/value helper로 mutation-before journal 규칙이 모였고, parent-chain과 민감 key 판정도 양 플랫폼의 단일 helper에 응집됐다. 불필요한 dependency는 추가하지 않았다. `install.ps1:103-212,278-296`, `install.sh:139-260,299-318` |
| 통합 | 4 | 3 | 기존 config/profile/runtime/fnm 계약이 유지되고 실제 `config/git/gitconfig`의 모든 정상 경로가 적용된다. `credential.credentialStore=dpapi`도 value와 receipt에 함께 기록된다. |
| 안전성 | 4 | 4 | receipt·destination path type, 모든 중간 parent symlink/reparse point, user-modified hash, secret-bearing value name을 보존한다. exact safe key만 허용하며 실제 host settings는 모든 테스트 전후 동일했다. `install.ps1:70-129,278-296`, `install.sh:47-81,139-164,299-318` |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| 플랫폼별 단일 JSON receipt | 충족 | Windows `%LOCALAPPDATA%\dotfiles\install-receipt.json`, Unix `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-receipt.json`. `install.ps1:38-42,70-96`, `install.sh:43,51-81` |
| receipt atomic 교체와 fail-closed validation | 충족 | fresh/update/bootstrap 모두 sibling temp에 쓰고 JSON 검증·mode 설정 후 move한다. invalid schema, directory, symlink receipt는 원본을 보존하고 mutation을 막는다. |
| 최초 `before` 불변, takeover 1회 backup, installed hash gate | 충족 | mutation 전에 pending을 저장하고 backup hash를 확인한다. managed mismatch는 보존하며 final receipt save crash는 target hash로 복구한다. `install.ps1:117-212`, `install.sh:152-238` |
| settings statusLine을 포함한 managed config 보호 | 충족 | statusLine 후보와 TOML/JSON merge 결과 모두 공용 artifact helper를 거친다. 최초 원본 backup과 사용자 수정 후 보존 fixture가 통과했다. `install.ps1:434-512,534-566`, `install.sh:461-539,623-650` |
| directory·symlink·중간 parent collision fail-closed | 충족 | final item뿐 아니라 destination parent chain의 symlink/reparse point를 검사한다. 양 플랫폼 intermediate tree fixture에서 외부 sentinel·receipt가 그대로 보존됐다. `install.ps1:103-129`, `install.sh:139-164` |
| 동명 skill/agent/hook과 destination extra 보존 | 충족 | skill은 미소유 root 전체를 보존하고 agent/hook은 final collision을 `Skip`한다. tree는 source file만 순회해 unrelated destination file을 제거하지 않는다. |
| legacy 이름 기반 자동 삭제 제거 | 충족 | role 이름만으로 기존 skill directory를 삭제하는 경로가 제거됐고, 임시 파일 cleanup 외 broad delete를 찾지 못했다. |
| winget/brew/apt/npm 이전 상태와 성공 delta 기록 | 충족 | mutation 전 pending, 최초 package state 불변, 성공 delta finalize가 구현됐다. apt/brew bulk partial failure와 jq bootstrap nonzero mock에서 성공 항목 기록 후 원 status 전파를 확인했다. |
| Git/env 이전 상태 기록 및 사용자 변경 보존 | 충족 | 일반 Git key, PATH, YAZI, pending recovery가 동작한다. exact safe `git:credential.credentialStore`는 허용되고 token/secret/password/credential 일반 key는 거부된다. `install.ps1:278-355`, `install.sh:299-342` |
| 실제 Git manifest의 정상 key 적용 | 충족 | isolated fresh `merge_gitconfig config/git/gitconfig` 결과 `core.pager=delta`, `credential.credentialStore=dpapi`, receipt `before.present=false`, `installed=dpapi`를 확인했다. |
| receipt에 비밀 값 미저장 | 충족 | 민감 이름 fixture는 receipt에 나타나지 않고 exact allowlist는 semantic상 backend 이름인 `credentialStore` 하나뿐이다. `tests/ownership/install-receipt.ps1:141-146,199-203`, `tests/ownership/install-receipt.sh:107-112,162-166` |
| 부분 실패·재실행에도 receipt 비손상 | 충족 | pre-mutation journal 실패는 destination/backup을 바꾸지 않고, post-mutation failure는 pending receipt로 재시도 시 finalize한다. invalid/partial main receipt도 덮어쓰지 않는다. |
| direct official/GitHub binary·symlink ownership | 후속 범위 | GitHub Issue #16 Scope/Acceptance에 mutation 전 `before`, exact hash/target과 user collision 보존이 명시되고 #16이 #10에 blocked, #14가 #16에 blocked로 설정됐다. 이번 기능 감점 대상이 아니다. |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `pwsh -NoProfile -File tests/ownership/install-receipt.ps1` | PASS | source 전 USERPROFILE/HOME/LOCALAPPDATA/APPDATA/receipt 격리; Windows reparse fixture 실행 |
| `bash tests/ownership/install-receipt.sh` | PASS | Git Bash; source 전 HOME/receipt 격리 |
| WSL `bash tests/ownership/install-receipt.sh` | PASS | 실제 Linux broken/intermediate symlink semantics 포함 |
| WSL `shellcheck -x install.sh` | PASS | `.github/workflows/pr-gate.yml`과 동일 명령 |
| isolated actual `config/git/gitconfig` merge | PASS | `core.pager=delta`, `credential.credentialStore=dpapi`, receipt valid |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS | TOML/JSON merge 회귀 |
| `bash tests/install/config-merge.sh` | PASS | TOML/JSON merge 회귀 |
| `pwsh -NoProfile -File tests/profile/profile-idempotency.ps1` | PASS | PowerShell/Git Bash profile marker 회귀 |
| `bash tests/profile/profile-idempotency.sh` | PASS | Bash/zsh profile marker 회귀 |
| `bash tests/claude/runtime-contract.sh` | PASS | Claude runtime 계약 |
| `pwsh -NoProfile -File tests/fnm/profile-precedence.ps1` | PASS | Windows fnm 비파괴·statusLine 회귀 |
| WSL `bash tests/fnm/non-destructive-install.sh` | PASS | Unix fnm 비파괴 계약 |
| apt bulk partial mock | PASS | 한 항목 설치 후 exit 42; delta 기록 후 42 전파 |
| brew bulk partial mock | PASS | 한 항목 설치 후 exit 43; delta 기록 후 43 전파 |
| jq bootstrap partial mock | PASS | jq 설치 후 exit 42; `apt:jq` finalize, bootstrap marker 제거, 42 전파 |
| PowerShell parser: `install.ps1`, ownership test | PASS | parse error 0 |
| `bash -n install.sh tests/ownership/install-receipt.sh` | PASS | syntax |
| `git diff --check` | PASS | whitespace |
| 실제 host settings SHA-256 전후 비교 | PASS | 검증 시작 전 이미 전달된 과거 기준과 달라 외부 변경으로 분류했고 복원하지 않았다. 현재 baseline `82E2B525826128C7AFD8AC8720CD32041AA0C869241078CD34E26B3D8313EEC0`는 모든 테스트 전후 불변이며 JSON도 유효하다. |

## 결함

통과를 막는 범위 내 결함 없음.

## 자체 평가 대조

- atomic receipt, immutable `before`, 1회 backup, managed hash gate, package/Git/env provenance 주장은 코드와 재실행 결과가 일치한다.
- 제공 ownership/config/profile/runtime/fnm 및 ShellCheck PASS 주장은 일치한다.
- 실제 macOS package manager와 Windows winget mutation을 이 host에서 수행하지 않았다는 제한은 인수인계에 명시돼 있고, isolated state-transition 및 partial mock으로 범위 내 실패 경로를 검증했다.
- direct downloaded artifact/symlink ownership을 #16으로 미룬다는 명시는 현재 GitHub 스펙과 dependency graph에 부합한다.

Issue #10은 다음 기능으로 진행 가능하다.
