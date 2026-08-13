# 평가: Installer 실패 전파와 실제 CI 계약

- **판정: PASS**
- 대상 인수인계: `docs/handoff/010-installer-failure-contract.md`
- 스펙 출처: GitHub Issue #15 `fix(ci): 실제 installer 계약과 실패 전파를 검증`
- 날짜: 2026-08-13

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | skip guard와 production stage가 `install.ps1:117-148`, `install.sh:135-163`에 연결되고, 최종 실패 종료는 `install.ps1:1305-1306`, `install.sh:1645`에서 강제된다. 실제 2회 install/sentinel 검증은 `.github/workflows/pr-gate.yml:36-134`, `:136-192`, `:194-239`, 실제 2회 uninstall은 `.github/workflows/uninstall-validation.yml:18-51`, `:53-98`에 있다. |
| 검증 | 4 | 4 | PowerShell/Bash failure contract, config merge, ShellCheck, AST, 양 플랫폼 uninstall 회귀, agent validator를 독립 재실행해 모두 exit 0을 확인했다. |
| 깊이 | 4 | 3 | empty/invalid/대소문자 scope/추가 필드/CLI 실패/manifest read 오류/validation 이후 파일 변경을 검사한다(`tests/install/failure-contract.ps1:45-78`, `tests/install/failure-contract.sh:45-101`). Windows native 명령은 호출 직후 `$LASTEXITCODE`를 보존한다(`install.ps1:80-89`, `:818-824`, `:982-990`, `:1021-1057`). |
| 코드 품질 | 4 | 3 | 두 installer 모두 기존 manifest reader와 native shell/PowerShell 기능만 재사용한다. 복제 workflow를 삭제하고 공통 stage helper로 실패 처리와 검증 경로를 모았다. ShellCheck와 `git diff --check`가 통과했다. |
| 통합 | 4 | 3 | 기존 config merge와 Safe-Clean-Uninstall 양 플랫폼 테스트가 모두 통과했다. PR Gate summary 의존성도 제거된 중복 job에 맞게 갱신됐다(`.github/workflows/pr-gate.yml:311-335`). |
| 안전성 | 4 | 4 | invalid manifest는 mutation 전에 차단되고, fake HOME/USERPROFILE/Git config에서 sentinel을 검증한다. host `~/.claude/settings.json` SHA-256은 평가 전후 `82E2B525826128C7AFD8AC8720CD32041AA0C869241078CD34E26B3D8313EEC0`로 동일했다. |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| `SKIP_CLAUDE_CODE`, `SKIP_SKILLS`, `SKIP_PLUGINS` 사용 시 대응 외부 CLI 0-call | 충족 | production guard `install.ps1:117-148`, `install.sh:135-163`; 직접 호출 회귀 `tests/install/failure-contract.ps1:31-42`, `tests/install/failure-contract.sh:21-43` |
| 필수 설치 실패가 nonzero이며 `Done`을 출력하지 않음 | 충족 | ledger/finalizer `install.ps1:45-60`, `:1305-1306`; `install.sh:43-59`, `:1645`; 양쪽 failure contract 재실행 PASS |
| plugin/skill manifest 전체 snapshot 선검증 후 mutation | 충족 | PowerShell은 rows 전체 검증 후 실행(`install.ps1:62-114`, `:136-148`), Bash는 단일 `content` snapshot을 검증·실행(`install.sh:61-133`)한다. invalid fixture에서 `claude`/`npx` 0-call을 확인했다. |
| invalid manifest fixture가 실패함 | 충족 | 필드 수, scope, ID, skill 형식을 양 플랫폼에서 검사(`tests/install/failure-contract.ps1:45-65`, `tests/install/failure-contract.sh:45-62`) |
| Windows native CLI 종료 코드를 다음 명령 전에 확인 | 충족 | plugin/skill `install.ps1:80-89`, `:108-112`; winget `:813-824`; fnm `:982-990`; npm `:1021-1057` |
| 실제 installer를 OS별 2회 실행하고 사용자 sentinel 보존 | 충족 | Ubuntu `.github/workflows/pr-gate.yml:63-134`, macOS `:153-192`, Windows `:210-239` |
| 실제 installer/uninstaller를 2회씩 실행 | 충족 | `.github/workflows/uninstall-validation.yml:27-51`, `:60-98` |
| CI가 installer/uninstaller 로직을 복제하지 않음 | 충족 | `.github/workflows/precision-validation.yml` 삭제; 남은 workflow는 실제 entrypoint를 직접 호출한다. |
| dead Codex flags와 apt 중복 제거 | 충족 | `config/codex/config.toml:8-9`에는 `hooks`만 남고, `manifests/apt.txt:11`의 `git`은 1건이다. config merge 회귀가 dead key 부재를 검증한다. |
| `python3` 호출 제거 | 충족 | `rg -n '\bpython3\b' .github docs/ci-pipelines.md install.ps1 install.sh tests/install` 결과 일치 없음. Agent 검증은 명시적 `uv ... --python 3.11`만 사용한다. |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| PowerShell parser로 `install.ps1` AST parse | PASS | parse error 0건 |
| `pwsh -NoProfile -File tests/install/failure-contract.ps1` | PASS | skip 0-call, invalid snapshot, CLI exit 실패, Done 억제 |
| `wsl bash -lc 'bash -n install.sh tests/install/failure-contract.sh tests/install/config-merge.sh'` | PASS | Bash 문법 |
| `wsl bash -lc 'shellcheck -x install.sh tests/install/failure-contract.sh tests/install/config-merge.sh'` | PASS | 경고/오류 없음 |
| `wsl bash -lc 'bash tests/install/failure-contract.sh'` | PASS | production helper 직접 검증 |
| `pwsh -NoProfile -File tests/install/config-merge.ps1` | PASS | 사용자 TOML/JSON 보존 및 dead key 부재 |
| `wsl bash -lc 'bash tests/install/config-merge.sh'` | PASS | 사용자 TOML/JSON 보존 및 dead key 부재 |
| `pwsh -NoProfile -File tests/uninstall/safe-clean.ps1` | PASS | Windows Safe-Clean-Uninstall 회귀 |
| `wsl bash -lc 'bash tests/uninstall/safe-clean.sh'` | PASS | Unix Safe-Clean-Uninstall 회귀 |
| `uv run --with pyyaml --python 3.11 scripts/validate-agent-roles.py` | PASS | role 3개 |
| `uv run --with pyyaml --python 3.11 -m unittest discover -s tests -p test_agent_role_validation.py` | PASS | 9 tests |
| `yq '.' .github/workflows/pr-gate.yml` 및 `uninstall-validation.yml` | PASS | workflow YAML 파싱 |
| `yq -p=toml '.' config/codex/config.toml` | PASS | TOML 파싱 |
| `git diff --check` | PASS | whitespace 오류 없음 |
| host settings SHA-256 전/후 비교 | PASS | 동일: `82E2B525826128C7AFD8AC8720CD32041AA0C869241078CD34E26B3D8313EEC0` |

## 결함

판정을 바꿀 결함 없음. GitHub-hosted runner의 실제 install/uninstall 실행 결과는 PR에서 확인해야 하나, 인수인계가 이를 미실행으로 명시했고 로컬에서 안전하게 재실행 가능한 제품 경로와 회귀 검증은 모두 통과했다.

## 자체 평가 대조

일치. 인수인계는 로컬 검증 결과와 GitHub Actions 확인 필요 항목을 구분해 보고했으며, 재실행 결과와 모순되지 않았다.
