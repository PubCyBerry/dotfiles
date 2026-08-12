# 평가: 직접 설치 artifact pin·검증·소유권

- **판정: PASS**
- 대상 인수인계: `docs/handoff/008-direct-artifacts.md`
- 스펙 출처: GitHub Issue #16 `security(install): 원격 installer와 release asset을 pin·검증`
- 날짜: 2026-08-12

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | 22개 architecture별 asset을 고정 version·SHA-256으로 설치하고 direct file/tree/symlink의 receipt, user modification 보존, 명시적 upgrade gate를 구현했다(`manifests/direct-artifacts.tsv:2-23`, `install.sh:243-458`, `install.sh:919-1034`). |
| 검증 | 4 | 4 | Git Bash·WSL actual symlink·PowerShell fixture, shellcheck/AST/bash-n, pinned download, upstream digest 22건, 기존 ownership/config/profile/fnm/Claude 회귀와 세 OS actual-stage package journal mock이 모두 PASS했다. |
| 깊이 | 4 | 3 | checksum-before-mutation, malformed/duplicate manifest, symlink/tree pending, target drift, FIFO/socket/root mode, unowned·modified artifact, transient/definitive-absent package query, partial failure→retry를 검증한다(`tests/ownership/direct-artifacts.sh:12-138`, `tests/ownership/direct-artifacts.ps1:11-35`). |
| 코드 품질 | 4 | 3 | direct artifact manifest와 install helper가 응집되어 있고, Claude package query/reconcile/complete 상태 전이를 공통 helper로 분리했다(`install.sh:497-560`, `install.ps1:54-94`). 정적 검사도 모두 통과했다. |
| 통합 | 4 | 3 | Windows WinGet, macOS Homebrew cask, Linux npm과 #10 receipt 상태 기계가 연결되며 기존 ownership/config/profile/fnm/Claude runtime 회귀를 깨뜨리지 않았다. 문서·manifest도 설치 경로와 일치한다. |
| 안전성 | 4 | 4 | remote installer 실행과 unpinned URL·privileged direct write가 제거됐다. checksum 불일치는 mutation 전에 중단되고 identity 미확정 시 pending journal과 사용자 artifact를 보존한다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| 직접 다운로드 release version/tag pin | 충족 | `manifests/direct-artifacts.tsv:2-23`의 amd64/arm64 URL이 모두 고정 release tag를 사용한다. |
| architecture별 SHA-256 또는 signed checksum 검증 | 충족 | `download_verified`가 temp download를 hash 검증한 뒤에만 destination으로 이동한다(`install.sh:327-339`). manifest 22개 checksum 모두 GitHub upstream asset digest와 일치했다. |
| curl pipe 제거, 다운로드 후 검증하고 실행 | 충족 | banned remote execution scan exit 1. checksum mismatch fixture에서 기존 destination 내용과 receipt hash가 모두 불변이었다. |
| package manager가 제공하는 도구는 native package 우선 | 충족 | zoxide는 apt로 이동했고 Claude는 Windows WinGet, macOS Homebrew cask, Linux npm을 사용한다(`manifests/apt.txt`, `install.ps1:1001-1034`, `install.sh:1370-1406`). |
| version bump를 manifest 또는 한 상수에서 수행 | 충족 | version·URL·checksum이 `manifests/direct-artifacts.tsv` 한 파일에 모여 있고 설치 전에 schema·중복·필수 architecture를 검증한다(`install.sh:930-943`). |
| direct binary/symlink의 mutation 전 before와 성공 후 exact identity receipt | 충족 | managed file `install.sh:152-240`, symlink `install.sh:243-306`, direct tree `install.sh:408-458`가 pre-mutation pending과 post-mutation hash/target/version을 기록한다. |
| receipt identity와 다른 기존 path는 overwrite하지 않고 보존 | 충족 | actual symlink, unowned file/tree, modified file/symlink/tree fixture가 경고+nonzero이며 원본 내용·target을 보존했다. |
| 명시적 upgrade mode와 설치 version 보고 | 충족 | `direct_anchor_state`가 identity를 먼저 검사하고 version 변경은 `DOTFILES_UPGRADE_DIRECT=1`에서만 허용한다(`install.sh:346-369`). current/upgrade-blocked/upgrade 메시지에 version을 포함한다. |
| 부분 실패 후 성공 artifact만 exact identity로 판별 | 충족 | Windows·Linux npm·macOS cask actual-stage mock에서 fresh partial failure는 pending을 유지하고 다음 실행에서 exact `2.0.0` identity로 finalize했다(`install.ps1:58-94`, `install.sh:497-560`). |
| latest/main/HEAD URL과 privileged direct write 제거 | 충족 | 관련 `rg` scan 네 건이 모두 no-match(exit 1)였다. direct artifact는 `~/.local`, `~/.bun` 아래에 설치된다. |
| 설치/제거 문서 동기화 | 충족 | `AGENTS.md:93-130`, `docs/tools.md:242`, `docs/uninstall.md:512`가 package-manager Claude와 receipt-managed direct artifact 경로·제거 주의를 반영한다. |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `gh issue view 16 --repo PubCyBerry/dotfiles --json ...` | PASS | Issue 원문과 Acceptance criteria 재확인. |
| Git Bash `bash tests/ownership/direct-artifacts.sh` | PASS | checksum/tree/package-state/static 검증 PASS; Windows 권한상 symlink assertion만 명시적으로 skip. |
| WSL `bash tests/ownership/direct-artifacts.sh` | PASS | actual symlink, pending/finalize, FIFO/socket/root mode, target drift, unowned·modified tree 모두 PASS. |
| `pwsh -NoProfile -File tests/ownership/direct-artifacts.ps1` | PASS | WinGet transient/definitive absence, fresh partial→retry exact finalize PASS. |
| WSL `bash tests/fnm/non-destructive-install.sh` | PASS | temp receipt를 사용한 managed fnm link와 사용자 npm/npx 보존 PASS. |
| WSL `shellcheck -x install.sh tests/ownership/direct-artifacts.sh` | PASS | 출력 없음, exit 0. |
| `bash -n install.sh tests/ownership/direct-artifacts.sh tests/fnm/non-destructive-install.sh` | PASS | exit 0. |
| PowerShell AST parse `install.ps1` | PASS | parse error 0건. |
| `git diff --check` | PASS | whitespace error 없음. |
| `bash tests/ownership/install-receipt.sh` / `pwsh ...install-receipt.ps1` | PASS | Unix/Windows ownership 회귀 PASS. |
| `bash tests/install/config-merge.sh` / `pwsh ...config-merge.ps1` | PASS | config merge 회귀 PASS. |
| `bash tests/profile/profile-idempotency.sh` / `pwsh ...profile-idempotency.ps1` | PASS | profile 회귀 PASS. |
| `pwsh -NoProfile -File tests/fnm/profile-precedence.ps1` | PASS | fnm multishell precedence 회귀 PASS. |
| `bash tests/claude/runtime-contract.sh` | PASS | Claude runtime contract PASS. |
| evaluator Windows actual Claude-stage mock | PASS | `SKIP`/external은 manager call 0; pending transient는 `pending=True` 유지+중단; fresh partial은 pending 유지 후 retry에서 `installed=2.0.0`, pending 제거. |
| evaluator Linux npm actual Claude-stage mock | PASS | fresh manager rc 9/query transient에서 pending 유지; retry exact identity `2.0.0` finalize. `SKIP`/external은 npm call 0. |
| evaluator macOS cask actual Claude-stage mock | PASS | fresh manager rc 9/query transient에서 pending 유지; retry exact identity `2.0.0` finalize. |
| evaluator WSL composite archive mock | PASS | fresh와 partial reconciliation에서 `yazi/ya/fnm/bun/bunx/nvim/tree` 모두 정상; modified `ya`·nvim tree 보존, rc 1. |
| evaluator manifest malformed/duplicate fixture | PASS | malformed row와 duplicate name/arch 모두 validation rc 1. |
| `rg -n 'curl.*\|.*(sh|bash)|/latest/|/HEAD/|/main/' install.ps1 install.sh` | PASS | no match, exit 1. remote exec/release alias/privileged direct write 추가 scan도 no match. |
| yq v4.53.3 amd64 temp download + `Get-FileHash SHA256` | PASS | `fa52a4e758c63d38299163fbdd1edfb4c4963247918bf9c1c5d31d84789eded4`, manifest와 일치. |
| `gh api <release> | jq <asset.digest>` manifest 전수 대조 | PASS | 22/22 upstream `sha256:` digest 일치, missing 0. |

## 결함

차단 결함 없음.

## 자체 평가 대조

일치. 인수인계에 기록된 검증 명령을 직접 재실행해 모두 PASS했고, 알려진 제약인 실제 package manager 설치 미실행은 temp manager mock으로 상태 전이를 검증했다. 이전 평가의 Windows/Linux/macOS pending-query 결함은 공통 reconcile helper와 연속 partial→retry fixture로 해소됐다.
