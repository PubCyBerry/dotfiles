# 평가: Receipt 기반 Safe-Clean-Uninstall

- **판정: PASS**
- 대상 인수인계: `docs/handoff/009-safe-clean-uninstall.md`
- 스펙 출처: GitHub Issue #14, `AGENTS.md`의 Safe-Clean-Install/Safe-Clean-Uninstall 계약
- 날짜: 2026-08-13

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | Windows/Unix 실행기, exact identity 복원·제거, 변경 항목 보존, partial/retry, repeated uninstall, keep-packages가 구현되고 직접 fixture를 통과했다. |
| 검증 | 4 | 4 | PowerShell/Git Bash/WSL uninstall fixture, 전체 ownership/config/profile/fnm/Claude 회귀, AST/syntax/lint/YAML/diff와 별도 adversarial을 재실행했다. |
| 깊이 | 4 | 3 | invalid whole receipt, mixed kind, symlink shape, pending type/state, commit fault, package query/post-verify, terminal crash marker, parent reparse를 보수적으로 처리한다. |
| 코드 품질 | 3 | 3 | 플랫폼별 구현은 크지만 manifest/source 기반 allowlist와 명시적 state reconciliation으로 응집되어 있고 임시 TODO나 swallowed destructive failure가 없다. |
| 통합 | 4 | 3 | install receipt의 npm prefix/file mode 변경과 실제 direct artifact 경로가 uninstall 계약과 맞고 기존 회귀 suite가 모두 통과했다. |
| 안전성 | 4 | 4 | mutation 전 schema/path/key 검증, canonical backup, exact hash/mode/target/version, post-verify와 atomic receipt 저장으로 user-owned 상태 삭제 경로를 차단한다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| 실행 가능한 `uninstall.ps1` 및 `uninstall.sh` | 충족 | 두 파일이 존재하며 PowerShell AST, `bash -n`, `shellcheck` 및 제공 fixture를 통과했다. |
| receipt와 exact managed identity/hash 기준 제거·복원 | 충족 | `uninstall.sh:54-85,204-269`, `uninstall.ps1:82-103,123-158`; file/symlink/tree 및 backup restore fixture PASS. |
| 사용자 hook/env/config section/package 보존 | 충족 | `.github/workflows/uninstall-validation.yml:33-50,66-88`이 actual scripts 2회와 각 sentinel 보존을 검사한다. Windows env post-verify fixture도 PASS. |
| 새로 만든 unchanged artifact만 제거 | 충족 | exact hash/mode/target/tree hash가 일치해야 제거하며 modified file/tree/other pending은 receipt와 함께 보존됐다. |
| 변경된 managed file 보존 및 경고 | 충족 | Unix/Windows 제공 fixture에서 modified artifact가 유지되고 재실행 receipt hash도 유지됐다. |
| partial install 및 interruption retry | 충족 | stable pending file/symlink, fresh pending package, target/previous/other, backup restore 뒤 receipt commit fault 재시도가 수렴했다. |
| repeated uninstall 성공 | 충족 | 제공 fixture 및 workflow의 실제 uninstall 2회 계약이 있다. 완료 receipt는 제거되고 두 번째 실행은 marker-only/no-op로 성공한다. |
| pre-existing package 및 keep 옵션 보존 | 충족 | before-present package는 ownership entry만 해제하고, keep 옵션은 package 제거 없이 receipt를 정리한다. terminal `jq`도 exact state만 처리한다. |
| Windows, Ubuntu, macOS 절차 제공 | 충족 | PowerShell과 Unix script, Ubuntu/macOS matrix 및 Windows job이 존재한다. handoff는 macOS를 “workflow 등록, 로컬 실행 환경 없음”으로 정확히 제한 보고한다. |
| CI와 문서에 cleanup 로직 복사본 없음 | 충족 | workflow는 실제 `install.*`/`uninstall.*`만 호출하며 `rm -rf`, recursive `Remove-Item`, `sed -i` cleanup 복제 scan이 비어 있다. |
| receipt 없는 legacy 설치의 공격적 삭제 금지 | 충족 | receipt absent에서는 exact marker block만 처리하며 legacy artifact/package를 추측 삭제하지 않는다. |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `pwsh -NoProfile -File tests/uninstall/safe-clean.ps1` | PASS | Windows allowlist, env, backup, pending, invalid receipt |
| Git Bash `bash tests/uninstall/safe-clean.sh` | PASS | handoff 기재 명령 재현 |
| WSL `bash tests/uninstall/safe-clean.sh` | PASS | Linux filesystem semantics 재확인 |
| WSL `bash -n install.sh && bash -n uninstall.sh` | PASS | syntax |
| WSL `shellcheck -x install.sh uninstall.sh` | PASS | lint |
| PowerShell `[scriptblock]::Create(Get-Content -Raw uninstall.ps1)` | PASS | parser error 없음 |
| `yq '.' .github/workflows/uninstall-validation.yml` | PASS | YAML parse |
| `git diff --check` | PASS | whitespace |
| PowerShell ownership/direct-artifact/config/profile/fnm tests | PASS | 5개 회귀 명령 모두 exit 0 |
| WSL ownership/direct-artifact/config/profile/fnm/Claude tests | PASS | 6개 회귀 명령 모두 exit 0 |
| Bash 3 전용 정적 scan | PASS | `declare -A`, `mapfile`, `readarray`, `coproc` 등 없음 |
| workflow cleanup 복제 scan | PASS | destructive cleanup 구현 없음 |
| fixture allowlist override scan | PASS | Unix/PowerShell test가 제품 allowlist/schema 함수를 재정의하지 않음 |
| actual direct anchors | PASS | `$HOME/.local/share/fnm/fnm`, `$HOME/.bun/bin/bun`, `bunx` 허용 |
| brew slash formula/cask | PASS | `brew:oven-sh/bun/bun`, `cask:codexbar`, short-name version query |
| arbitrary fnm-like npm prefix/PATH | PASS | project 아래 유사 prefix와 PATH key 거부, exact configured FNM root만 허용 |
| fresh pending current-present package | PASS | package 제거 호출 없이 receipt 보존 |
| backup restore mutation → receipt commit fault → retry | PASS | original 복원 후 다음 실행에서 receipt 수렴 |
| mixed artifact kind | PASS | whole receipt 거부, marker/artifact zero mutation |
| malformed symlink shapes 3종 | PASS | missing before type, null before target, missing pending fields 거부 |
| Windows pending type 6종 | PASS | bool만 허용; string/int/object/array 거부, package bool pending 거부 |
| impossible Windows PATH | PASS | whole preflight 거부, PATH/marker zero mutation |
| Windows wrong/nested agent path | PASS | `.toml` direct child만 허용, wrong extension/nested path zero mutation |
| terminal multiline/CR/extra-tab/NUL | PASS | recovery 실행·package 제거 없이 marker 보존 |

평가 전후 `C:\Users\taehunkim\.claude\settings.json` SHA-256은 `82E2B525826128C7AFD8AC8720CD32041AA0C869241078CD34E26B3D8313EEC0`으로 동일하다. `.codex/`는 변경하지 않았다.

## 결함

통과를 막는 결함 없음.

## 자체 평가 대조

- handoff의 PowerShell/Git Bash fixture, syntax/lint/YAML/diff 및 회귀 PASS 주장은 재실행 결과와 일치한다.
- “전체 entry shape와 allowlist를 mutation 전에 검증”, “exact direct child”, “exact single-line marker”, “npm은 configured FNM prefix만 허용” 주장은 코드와 adversarial 결과에 일치한다.
- macOS는 workflow matrix 등록과 로컬 실행 환경 부재만 주장하므로 실행 결과를 과장하지 않았다.
