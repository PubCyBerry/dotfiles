# 평가: Windows·Unix·macOS profile 배포 멱등화

- **판정: PASS**
- 대상 인수인계: `docs/handoff/002-profile-idempotency.md`
- 스펙 출처: GitHub Issue #8 / `AGENTS.md` Safe-Clean-Install·Uninstall 기준
- 날짜: 2026-08-11

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | `$PROFILE.CurrentUserCurrentHost`, 기존 `.bash_profile` upsert, literal Unix 본문, macOS zsh 초기화와 정상 제거가 요구사항대로 동작한다. `install.ps1:634,672-673`, `install.sh:43-120`, `docs/uninstall.md:323-418` |
| 검증 | 5 | 4 | 두 플랫폼 회귀 테스트, PowerShell AST, `bash -n`, `git diff --check`가 통과했다. 이전 inline·역순 손실 재현도 별도로 실행해 nonzero와 원본 hash/byte 보존을 확인했다. |
| 깊이 | 4 | 3 | inline·불완전·역순·중복 marker를 모두 fail-closed 처리하고 테스트한다. Unix는 교체 `awk` 자체도 정상 단일 쌍 처리 여부를 재확인한 뒤에만 `mv`한다. `install.sh:50-92`, `tests/profile/profile-idempotency.sh:12-62` |
| 코드 품질 | 4 | 3 | 추가 dependency 없이 플랫폼 기본 regex/grep/awk를 사용한다. marker 검사 조건과 실제 교체 경계가 exact-line·단일·정순으로 일치한다. |
| 통합 | 4 | 3 | 기존 all-in-one 흐름과 함수 source-only 검증 경로를 유지하면서 Windows, Git Bash, Linux, macOS profile 배포에 연결됐다. 실제 macOS host 미검증은 인수인계에 명시됐다. |
| 안전성 | 4 | 4 | 쓰기 전에 marker 상태를 검증하며 비정상 상태는 명확한 경고와 nonzero로 중단한다. 재현에서 사용자 원본이 byte-for-byte 보존됐다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| localized/redirected Documents에서 실제 PowerShell profile 갱신 | 충족 | `install.ps1:634`가 `$PROFILE.CurrentUserCurrentHost`를 사용한다. 현재 호스트에서도 `C:\Users\taehunkim\문서\PowerShell\Microsoft.PowerShell_profile.ps1`로 확인했다. |
| 기존 `.bash_profile`에 marker 방식으로 `.bashrc` source 보장 | 충족 | `install.ps1:671-673`; 테스트가 기존 sentinel과 단일 source를 확인한다. |
| Unix profile 본문 literal 보존 | 충족 | `install.sh:46-47,72-77`이 본문을 임시 파일로 전달한다. `\builtin`, `\e[A` assertion이 통과했다. |
| 설치 2회 byte 멱등성 | 충족 | PowerShell hash 및 Unix `cmp` 검증 통과. `tests/profile/profile-idempotency.ps1:40-42`, `tests/profile/profile-idempotency.sh:69-81` |
| 제거 후 앞뒤 사용자 줄 보존 | 충족 | 정상 exact-line marker 제거 후 sentinel 보존 테스트 통과. 비정상 marker는 제거 helper도 원본을 보존하며 실패한다. |
| macOS 새 zsh에서 Homebrew/fnm/starship 초기화 | 충족 | `install.sh:107-119`에 Apple Silicon/Intel Homebrew와 `fnm`/`starship` 초기화가 배포된다. 격리 테스트에서 내용과 멱등성을 확인했다. |
| 부분 설치·실패 후 재실행에서 사용자 설정 보존 | 충족 | exact-line 단일 정순 쌍 외 상태는 쓰기 전에 거부한다. `install.ps1:65-78`, `install.sh:50-92` |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `pwsh -NoProfile -File tests/profile/profile-idempotency.ps1` | PASS | 정상 profile, `.bash_profile`, 2회 hash, inline·역순·불완전·중복 원본 hash 보존 |
| `bash tests/profile/profile-idempotency.sh` | PASS | literal escape, zsh block, 2회 `cmp`, 정상 제거, 네 비정상 marker 원본 보존 |
| PowerShell AST parse (`install.ps1`, PowerShell test) | PASS | parse error 없음 |
| `bash -n install.sh tests/profile/profile-idempotency.sh` | PASS | 출력 없음 |
| `git diff --check -- install.ps1 install.sh docs/uninstall.md tests/profile docs/handoff/002-profile-idempotency.md` | PASS | CRLF 안내 warning 외 오류 없음 |
| 이전 PowerShell inline marker 재현 | PASS | `Set-ProfileBlock`이 경고 후 throw; 전후 SHA-256 동일 |
| 이전 Unix 역순 marker 재현 | PASS | helper가 nonzero; `cmp` 성공, `user-after` 유지 |

## 결함

통과를 막는 범위 내 결함 없음.

## 자체 평가 대조

인수인계의 구현·검증 주장과 재실행 결과가 일치한다. 실제 macOS 새 zsh process를 실행하지 못한 제약도 정확히 공개되어 있다.
