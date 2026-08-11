# fnm 비파괴 설치와 실행 경로 관리

- 상태: 완료
- 스펙 출처: GitHub Issue #9
- 날짜: 2026-08-11

## 무엇을 만들었나

기본 설치는 기존 fnm Node 버전과 그 버전의 global package를 보존하고, `DOTFILES_PRUNE_NODE_VERSIONS=1`을 명시한 경우에만 비활성 버전을 제거한다. Unix의 비셸 실행 경로는 실행 가능한 `aliases/default/bin/{node,npm,npx}`만 연결하며, 기존 installer가 만든 잘못된 dangling link만 복구하고 사용자 파일·symlink는 보존한다. Claude `statusLine`은 현재 Node의 실제 실행 파일이 확인되고 명령이 달라질 때만 같은 디렉터리의 임시 파일을 거쳐 교체한다. PowerShell profile의 실경로 fallback은 fnm multishell 뒤에 배치해 `fnm use`가 우선한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.sh` | opt-in prune, 안전한 default bin link, Unix statusLine atomic update를 공용 Node 단계로 묶음 |
| `install.ps1` | opt-in prune helper, `FNM_DIR` 기반 default/statusLine 경로, separator·`node.exe` 호환 atomic update |
| `config/powershell/profile.ps1` | 실경로 fallback을 PATH 뒤로 이동하고 semver 순으로 선택 |
| `tests/fnm/non-destructive-install.sh` | 버전·global package 보존, link 소유권, statusLine 변경·무변경·손상 JSON 회귀 검증 |
| `tests/fnm/profile-precedence.ps1` | fnm 우선순위, `FNM_DIR`, Windows 경로 변형, opt-in prune 회귀 검증 |
| `AGENTS.md` | 기본 보존과 prune opt-in 정책 문서화 |
| `docs/TROUBLESHOOTING.md` | PowerShell direct fallback의 PATH 우선순위 설명 수정 |

## 설계 결정

- Unix link는 새 target이 실행 가능할 때만 생성한다. 기존 link가 정확히 과거 installer target인 `aliases/default/<bin>`을 가리키며 dangling 상태일 때만 교체한다.
- statusLine은 기존 명령 전체를 재생성하지 않고 확인된 Node 경로 부분만 바꾼다. JSON parse 실패, non-object JSON, target 부재, 동일 경로는 원본 byte를 유지한다.
- prune 판단은 installer 진입점이 아니라 호출 helper 안에도 둬, 기본값을 격리 테스트로 직접 고정했다.

## 가정

- fnm의 Unix default alias는 `<FNM_DIR>/aliases/default`에서 installation 디렉터리를 가리키며 실행 파일은 그 아래 `bin/`에 있다.
- Windows fnm 설치 실행 파일은 `<FNM_DIR>/node-versions/<version>/installation/node.exe`에 있다.

## 검증

| 명령 | 결과 |
|---|---|
| `wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/taehunkim/dotfiles && bash tests/fnm/non-destructive-install.sh'` | PASS |
| `pwsh -NoProfile -File tests/fnm/profile-precedence.ps1` | PASS |
| `wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/taehunkim/dotfiles && shellcheck -x -e SC2016,SC2317 install.sh tests/fnm/non-destructive-install.sh'` | PASS |
| `bash -n install.sh` | PASS |
| PowerShell AST parse: `install.ps1`, `config/powershell/profile.ps1`, `tests/fnm/profile-precedence.ps1` | PASS |
| `git diff --check` | PASS |

## QA 확인 필요

1. 실제 fnm에 두 Node 버전과 서로 다른 global package를 설치한 뒤 기본 installer를 실행한다. 두 버전과 package가 모두 남아야 한다.
2. Unix에서 installer 실행 후 `test -x ~/.local/bin/{node,npm,npx}`가 모두 성공하고 각 `readlink`가 `aliases/default/bin/<name>`을 가리켜야 한다.
3. Windows에서 `fnm use <old-version>` 후 새 PowerShell을 열어 `Get-Command node`가 fnm multishell 경로를 가리키는지 확인한다.
4. 읽기 전용 또는 교체 실패를 유도한 `settings.json`에서 원본이 보존되고 성공 로그가 출력되지 않는지 확인한다.

## 알려진 제약

- 전체 installer의 외부 다운로드·winget 단계는 격리 테스트에서 실행하지 않았고 fnm CLI 응답은 fixture로 대체했다.
- Git Bash는 이 Windows 호스트에서 native dangling symlink fixture를 만들 수 없어 Unix link 검증은 WSL Ubuntu에서 실행했다.
- ShellCheck 제외 코드 `SC2016`, `SC2317`은 기존 macOS profile literal과 functions-only guard에서 발생하며 이번 Node 변경 범위 밖이다.

## 후속 작업

- Issue #11: Claude model/hook runtime 정합성 수정
