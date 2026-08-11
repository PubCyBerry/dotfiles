# 평가: fnm 비파괴 설치와 실행 경로 관리

- **판정: PASS**
- 대상 인수인계: `docs/handoff/003-fnm-non-destructive.md`
- 스펙 출처: GitHub Issue #9 및 평가 위임 acceptance criteria
- 날짜: 2026-08-11

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | 기본 prune 차단과 opt-in 분기는 `install.ps1:194-212`, `install.sh:263-279`; Unix link 소유권 처리는 `install.sh:281-304`; statusLine 갱신은 `install.ps1:214-243`, `install.sh:306-328`; PowerShell 우선순위는 `config/powershell/profile.ps1:13-29`에 구현됨. |
| 검증 | 4 | 4 | Windows fixture, WSL Ubuntu fixture, ShellCheck, Bash 구문 검사, PowerShell AST, `git diff --check`를 직접 재실행해 모두 통과함. |
| 깊이 | 4 | 3 | 기존 global package sentinel, destructive helper 자체의 opt-in guard, 정확한 legacy dangling link, 임의 사용자 symlink/file, no-op, target missing, malformed/non-object JSON, slash/backslash, optional `bin`, `node.exe`, semver 정렬, 반복 profile 실행을 검증함(`tests/fnm/non-destructive-install.sh:31-92`, `tests/fnm/profile-precedence.ps1:16-100`). |
| 코드 품질 | 4 | 3 | 플랫폼별 동작을 작은 함수로 격리하고 기존 installer 진입점에서 호출함. 새 dependency나 speculative abstraction이 없고 정책 문서도 함께 갱신됨. |
| 통합 | 4 | 3 | 실제 Node 설치 단계가 helper를 호출하며(`install.ps1:451-475`, `install.sh:330-355,731`), `FNM_DIR`, `APPDATA`, `CLAUDE_DIR`, `LOCAL_BIN` 기존 경로 계약을 유지함. 전체 외부 다운로드 installer는 fixture 범위 밖임. |
| 안전성 | 4 | 4 | 파괴 작업은 정확히 `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 실행되고, user-owned link는 보존함. statusLine은 target 확인 후 같은 디렉터리 임시 파일을 검증·교체하며 성공 후에만 로그를 남김. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| 기본 설치에서 양 플랫폼 기존 Node versions/global packages 보존 | 충족 | 기본 경로에는 uninstall 호출이 없고 fixture가 이전 버전의 `node_modules/sentinel`을 확인함(`tests/fnm/non-destructive-install.sh:46-51`, `tests/fnm/profile-precedence.ps1:88-90`). |
| `DOTFILES_PRUNE_NODE_VERSIONS=1`만 prune | 충족 | 두 destructive helper가 문자열 `1`을 직접 비교하며, direct helper 호출과 installer 호출 양쪽에서 inactive version 하나만 제거되는지 검증함(`install.ps1:195`, `install.sh:265`, Windows test `:88-93`, Unix test `:46-54,90-92`). |
| Unix `aliases/default/bin/{node,npm,npx}` executable link | 충족 | target별 `-x` 확인 후 생성하고 최종 link 실행 가능성을 검증함(`install.sh:281-304`, Unix test `:57-68`). |
| 정확한 legacy dangling만 교체하고 임의 user file/symlink 보존 | 충족 | `-L`, dangling, exact legacy target 세 조건을 모두 요구함(`install.sh:295-301`); fixture가 legacy `node`, user symlink `npm`, user file `npx`를 분리 검증함. |
| Unix/Windows statusLine은 target 존재·실제 변경 시에만 atomic write와 성공 로그 | 충족 | 사전 target 검사, no-op 검사, same-directory temp+검증+move 후 로그 순서가 확인됨(`install.sh:309-327`, `install.ps1:215-238`). |
| malformed/no-op/target missing은 원본 bytes 보존·정상 반환 | 충족 | 양 플랫폼 fixture가 SHA/cmp와 성공 로그 부재를 검증함(`tests/fnm/non-destructive-install.sh:70-88`, `tests/fnm/profile-precedence.ps1:53-87`). |
| Windows `FNM_DIR`, separator 변형, optional `bin`, `node.exe` 지원 | 충족 | separator-neutral regex와 optional segment가 구현되고 custom path/space/slash fixture가 통과함(`install.ps1:222-228`, Windows test `:43-73`). |
| PowerShell fnm multishell이 direct fallback보다 우선 | 충족 | fallback을 PATH 끝에 1회 추가하고, 테스트가 두 경로 존재 및 index 순서를 확인함(`config/powershell/profile.ps1:16-28`, Windows test `:30-41`). |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `pwsh -NoProfile -File tests/fnm/profile-precedence.ps1` | PASS | statusLine 변형/보존, opt-in prune, multishell 우선순위 포함 |
| `wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/taehunkim/dotfiles && bash tests/fnm/non-destructive-install.sh'` | PASS | 비파괴 설치, link 소유권, statusLine, opt-in prune 포함 |
| `wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/Users/taehunkim/dotfiles && shellcheck -x -e SC2016,SC2317 install.sh tests/fnm/non-destructive-install.sh'` | PASS | 출력 없음 |
| `bash -n install.sh` | PASS | 출력 없음 |
| PowerShell AST parse: `install.ps1`, `config/powershell/profile.ps1`, `tests/fnm/profile-precedence.ps1` | PASS | parse error 0건 |
| `git diff --check` | PASS | CRLF 변환 warning만 있고 오류 없음 |
| `Update-FnmStatusLine`에 존재하지 않는 Windows target 전달 후 SHA256 비교 | PASS | 원본 bytes 유지, 성공 로그 없음 |

## 결함

차단 결함 없음.

## 자체 평가 대조

인수인계의 구현·검증 주장은 재실행 결과와 일치한다. 실제 외부 다운로드를 포함한 전체 installer를 실행하지 않았다는 제약도 정확히 명시되어 있다.
