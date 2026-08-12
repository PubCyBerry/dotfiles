# 직접 설치 artifact pin·검증·소유권

- 상태: 완료
- 스펙 출처: GitHub Issue #16 `security(install): 원격 installer와 release asset을 pin·검증`
- 날짜: 2026-08-12

## 무엇을 만들었나

Linux direct artifact를 아키텍처별 pinned URL·SHA-256 manifest로 설치하고, 검증이 완료된 파일만 `~/.local` 아래 receipt-managed file/tree/symlink로 배포한다. 사용자가 바꾼 artifact는 보존하며 버전 변경은 `DOTFILES_UPGRADE_DIRECT=1`에서만 허용한다. Claude Code는 remote script 실행 대신 Windows WinGet, macOS Homebrew cask, Linux npm(Node 22+)을 사용한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `install.sh` | checksum download, direct file/tree/symlink receipt, upgrade gate, package-manager Claude |
| `install.ps1` | Claude remote PowerShell 제거, WinGet receipt·skip guard |
| `manifests/direct-artifacts.tsv` | amd64/arm64 pinned URL·SHA-256 |
| `manifests/apt.txt` | zoxide를 apt로 전환, direct artifact 주석 동기화 |
| `manifests/Brewfile`, `manifests/npm-global.txt` | Claude Code 설치 단계 주석 동기화 |
| `tests/ownership/direct-artifacts.sh` | checksum, symlink/tree/FIFO/socket, upgrade gate, static scan |
| `tests/ownership/direct-artifacts.ps1` | WinGet partial mutation·transient query receipt 보존, definitive absent 취소 |
| `tests/fnm/non-destructive-install.sh` | receipt-managed fnm link의 격리 회귀 검증 |
| `AGENTS.md`, `docs/tools.md`, `docs/uninstall.md` | 설치·제거·도구 문서 동기화 |

## 설계 결정

- Neovim은 `~/.local/opt/nvim-v<version>` 트리를 canonical tar hash 하나로 journal하고 `~/.local/bin/nvim` symlink로 노출한다.
- Neovim versioned tree는 in-place replacement를 하지 않는다. fresh missing target, mutation 전 pending retry, target hash가 완성된 pending finalize만 허용하고 기존/modified tree는 보존한다.
- tree identity는 root mode와 모든 child의 path/type/mode/link target/size, regular content를 포함해 FIFO·Unix socket·추가 file도 변조로 감지한다.
- 기존 package manager가 충분한 zoxide는 apt로 이동했다. Ubuntu 22.04 fzf는 `fzf --bash` 계약에 낮아 pinned direct artifact로 유지했다.
- Homebrew가 없는 macOS에서는 remote HEAD bootstrap 대신 prerequisite 오류로 종료한다.

## 가정

- Linux direct artifact는 Ubuntu amd64/arm64만 지원한다.
- Linux Claude Code는 fnm이 활성화한 Node.js 22+와 npm을 사용한다.

## 검증

| 명령 | 결과 |
|---|---|
| `bash tests/ownership/direct-artifacts.sh` | PASS (Windows Git Bash symlink assertion은 OS 권한으로 skip) |
| WSL `bash tests/ownership/direct-artifacts.sh` | PASS (actual symlink 경로 포함) |
| `pwsh -NoProfile -File tests/ownership/direct-artifacts.ps1` | PASS |
| WSL `bash tests/fnm/non-destructive-install.sh` | PASS |
| WSL `shellcheck -x install.sh tests/ownership/direct-artifacts.sh` | PASS |
| `curl.exe` yq v4.53.3 amd64 temp download + `Get-FileHash -Algorithm SHA256` | PASS (`fa52a4...eded4`) |
| `bash tests/ownership/install-receipt.sh` | PASS |
| `pwsh -NoProfile -File tests/ownership/install-receipt.ps1` | PASS |
| `bash tests/install/config-merge.sh` | PASS |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS |
| `bash tests/profile/profile-idempotency.sh` | PASS |
| `pwsh -NoProfile -File tests/profile/profile-idempotency.ps1` | PASS |
| PowerShell AST parse (`install.ps1`) | PASS |
| `bash -n install.sh tests/ownership/direct-artifacts.sh` | PASS |
| `git diff --check` | PASS |

## 선택 검증

- 실제 package 설치를 허용하는 disposable Linux VM에서 full install을 두 번 실행한다.

## 알려진 제약

- 이 Windows host에서 실제 Linux release 설치와 macOS Homebrew를 실행하지 않았다.
- Windows Git Bash에서 skip된 symlink assertion은 WSL actual symlink로 통과했다.

## 후속 작업

- Issue #14: receipt identity가 일치하는 direct file/tree/symlink만 safe uninstall에서 제거

## 자체 평가

- 스펙 충족도: remote/latest/privileged direct 설치를 제거하고 pin·checksum·receipt·upgrade gate를 구현했다.
- 검증 상태: Unix/Windows ownership·config·profile 회귀는 통과했으나 실제 Linux/macOS 설치는 미검증이다.
- 약한 곳: 실제 package manager 설치는 host 변경 방지를 위해 실행하지 않았다.
- 부작용 위험: Linux 도구 설치 경로가 `/usr/local`에서 user-local로 변경되며 PATH 우선순위에 영향을 받는다.
- 판정: 완료.
