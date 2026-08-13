# Windows·Unix·macOS profile 배포 멱등화

- 상태: 조건부 완료
- 스펙 출처: GitHub Issue #8 `fix(profile): Windows·Unix·macOS profile 배포를 멱등화`
- 날짜: 2026-08-11

## 무엇을 만들었나

PowerShell installer가 localized/redirected Documents 경로 대신 `$PROFILE.CurrentUserCurrentHost`를 사용하고, 기존 profile을 비우지 않으며 marker block만 멱등적으로 교체한다. Git Bash의 기존 `.bash_profile`에도 사용자 줄을 보존하며 `.bashrc` source block을 추가한다. PowerShell·Unix 모두 exact-line marker가 단일 정순 쌍일 때만 교체·제거하고 inline·불완전·역순·중복 상태는 경고와 nonzero로 실패하며 원본 byte를 보존한다. Unix는 profile 본문을 `awk -v`로 전달하지 않고 임시 파일에서 literal로 삽입하며, macOS는 `.zprofile`/`.zshrc`에 Homebrew·fnm·starship 초기화를 영속화한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.ps1` | platform-native PowerShell profile 경로, 비파괴적 marker 교체, `.bash_profile` marker 배포 |
| `install.sh` | literal marker 교체, shell profile 배포 helper, macOS zsh 초기화 |
| `docs/uninstall.md` | 실제 PowerShell profile 경로 사용, marker만 제거하며 사용자 줄 개행 보존 |
| `tests/profile/profile-idempotency.ps1` | localized profile, sentinel, `.bash_profile`, 2회 적용·제거 회귀 검증 |
| `tests/profile/profile-idempotency.sh` | bash/inputrc literal, macOS zsh block, byte 멱등성·제거 회귀 검증 |

## 설계 결정

Unix의 block 본문은 `mktemp` 파일로 전달해 macOS 기본 Bash 3.2에서도 backslash를 그대로 보존한다. write 전에 exact/substring marker 개수와 순서를 검증하고, `awk` 또한 begin/end를 각각 한 번 처리해 정상 종료한 경우에만 `mv`한다. PowerShell도 raw marker 개수와 multiline exact-line match 개수가 다르거나 단일 정순 쌍이 아니면 write 전에 `throw`한다.

## 가정

- macOS 기본 interactive shell은 zsh이며 login shell에서 `.zprofile`, interactive shell에서 `.zshrc`를 로드한다.
- Homebrew는 Apple Silicon에서 `/opt/homebrew`, Intel Mac에서 `/usr/local`의 표준 경로를 사용한다.
- marker 제거는 dotfiles marker 안의 내용만 소유한다.

## 검증

| 명령 | 결과 |
|---|---|
| `pwsh -NoProfile -File tests/profile/profile-idempotency.ps1` | PASS — localized profile, 사용자 sentinel, `.bash_profile`, byte 멱등성, 제거 후 줄 보존, inline·불완전·역순·중복 fail-closed |
| `bash tests/profile/profile-idempotency.sh` | PASS — bashrc/inputrc backslash literal, macOS zprofile/zshrc, byte 멱등성, 제거 후 sentinel, inline·불완전·역순·중복 fail-closed |
| PowerShell AST parse (`install.ps1`, PowerShell test) | PASS |
| `bash -n install.sh tests/profile/profile-idempotency.sh` | PASS |
| `git diff --check` | PASS |

## QA 확인 필요

1. localized 또는 Known Folder redirect가 적용된 Windows에서 installer를 2회 실행한다. `$PROFILE.CurrentUserCurrentHost`에만 block이 하나 존재하고 기존 사용자 줄의 byte가 바뀌지 않아야 한다.
2. 기존 `.bash_profile`의 marker 앞뒤에 sentinel을 두고 Windows installer를 2회 실행한다. sentinel은 그대로고 `.bashrc` source는 한 번만 존재해야 한다.
3. macOS Intel·Apple Silicon에서 installer 실행 후 새 login zsh를 연다. `brew`, `fnm`, `node`, `starship`이 추가 조치 없이 활성화되어야 한다.
4. 문서의 marker 제거 명령을 실행한다. 블록 앞뒤 sentinel은 각각 독립된 줄로 남고 사용자 profile 파일 자체는 제거되지 않아야 한다.
5. inline·불완전·역순·중복 marker profile에 installer와 제거 helper를 실행한다. 명확한 경고와 nonzero를 반환하고 원본 hash는 같아야 한다.

## 알려진 제약

- 실제 macOS 호스트와 새 zsh process에서는 검증하지 못했고, 격리 HOME에 `OS=Darwin`을 적용한 회귀 테스트로 검증했다.
- package 설치 등 host side effect가 있는 all-in-one installer 전체는 실행하지 않고 profile helper만 격리 실행했다.
- Windows profile 기존 줄의 개행 문자는 최초 marker 교체 시 PowerShell `Out-File` 표준으로 재직렬화될 수 있지만, 두 번째 적용부터는 byte 멱등이다.

## 후속 작업

- Issue #9: fnm 버전과 실행 경로를 비파괴적으로 관리
