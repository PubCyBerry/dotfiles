# 평가: macOS fresh 및 재설치 계약

- **판정: PASS**
- 대상 인수인계: `docs/handoff/007-macos-install.md`
- 스펙 출처: GitHub Issue #13 `fix(macos): fresh 및 2회 설치 계약 완성`
- 날짜: 2026-08-12

## 점수

| 축 | 점수 | 하한 | 근거 |
|---|---:|---:|---|
| 기능성 | 4 | 4 | `manifests/Brewfile:8`이 Neovim을 설치하고, `.github/workflows/pr-gate.yml:127-168`이 기존 Codex/zsh sentinel을 seed한 뒤 `/bin/bash`로 설치를 두 번 실행하며 nvim, Git editor, Yazi opener, marker 단일성을 검증한다. |
| 검증 | 4 | 4 | workflow YAML·계약 query, workflow run block와 `install.sh`의 Bash 문법, Brewfile 정적 assertion, TOML/Yazi query, Issue #7/#8 회귀 테스트, `git diff --check`를 직접 재실행해 모두 통과했다. 실제 macOS runner는 아직 실행되지 않았으나 구현 산출물 자체가 해당 runtime acceptance job이며 인수인계가 이 제약을 정확히 공개한다. |
| 깊이 | 4 | 3 | first/second install을 분리하고 second install 뒤 formula와 executable을 재검증한다. 기존 설정과 profile sentinel, begin/end marker exact-once를 함께 검사하며 `set -euo pipefail` 아래 pipeline 없이 핵심 명령의 실패를 전파한다. `.github/workflows/pr-gate.yml:137-168` |
| 코드 품질 | 4 | 3 | 제품 변경은 기존 Homebrew manifest에 `brew "neovim"` 한 줄뿐이며, Issue #7의 portable `yq` merge를 재구현하지 않았다. CI assertion도 별도 helper 없이 해당 job에 응집돼 있다. |
| 통합 | 4 | 3 | 기존 macOS installer 흐름(`install.sh:728-806`), Codex merge(`install.sh:465-506`), profile marker 처리(`install.sh:349-430`)를 그대로 사용한다. macOS job은 summary dependency에도 포함된다. `.github/workflows/pr-gate.yml:297-313` |
| 안전성 | 4 | 4 | sentinel seed는 폐기되는 GitHub-hosted runner `$HOME`에 한정되고 global Git config는 `$RUNNER_TEMP`로 격리된다. 사용자 Codex TOML과 zsh sentinel 보존 assertion 및 기존 병합/profile fail-closed 회귀 테스트가 통과했다. `.github/workflows/pr-gate.yml:127-135,165-168` |

## 요구사항 대조

| 스펙 요구사항 | 상태 | 근거 |
|---|---|---|
| Brewfile에 Neovim 추가 | 충족 | `manifests/Brewfile:8`; exact-line 정적 assertion이 정확히 1개를 확인 |
| stock macOS shell에서 두 번 설치 성공 | 충족 | `.github/workflows/pr-gate.yml:137-148`이 두 실행 모두 `/bin/bash install.sh`를 사용하며 각 step의 nonzero가 job 실패로 전파됨 |
| Issue #7 portable Codex merge 사용, Bash 3.2 문제 미재구현 | 충족 | `install.sh:465-506`의 기존 `yq` merge를 사용한다. `install.sh`에서 `declare -A`, `mapfile`, `readarray`, nameref 등 Bash 4+ token 검색 결과 없음; Issue #7 회귀 테스트 PASS |
| fresh 및 second install에서 nvim 확인 | 충족 | first install 직후 `command -v nvim`, `nvim --version` (`.github/workflows/pr-gate.yml:140-145`); second install 뒤 formula, command, version 재검증 (`:150-155`) |
| Git editor가 실제 executable 사용 | 충족 | `core.editor == "nvim -f"`와 첫 token의 `command -v` 검증 (`.github/workflows/pr-gate.yml:157-159`); source는 `config/git/gitconfig:5` |
| Yazi opener가 실제 executable 사용 | 충족 | 배포 TOML을 `yq -p=toml`로 읽어 `nvim "%s"`와 실행 파일을 확인 (`.github/workflows/pr-gate.yml:161-163`); source는 `config/yazi/yazi.toml:2-5` |
| 사용자 config/profile sentinel 보존 | 충족 | seed는 `.github/workflows/pr-gate.yml:127-135`, 최종 TOML/zsh sentinel assertion은 `:165-166`; 격리 회귀 테스트도 PASS |
| profile marker가 재설치 후 정확히 한 번 존재 | 충족 | begin/end에 각각 `grep -Fxc ... == 1` 적용 (`.github/workflows/pr-gate.yml:167-168`); profile 2회 멱등 회귀 테스트 PASS |
| global Git config를 runner 상태에서 격리 | 충족 | 빈 `$RUNNER_TEMP/dotfiles-gitconfig`를 만들고 다음 step 전에 `$GITHUB_ENV`에 `GIT_CONFIG_GLOBAL` 기록 (`.github/workflows/pr-gate.yml:133-135`) |
| workflow 실패 전파와 summary 통합 | 충족 | 검증 block의 `set -euo pipefail` (`.github/workflows/pr-gate.yml:129,142,152`) 및 summary `needs`/결과 검사 (`:297-324`) |

## 재실행한 검증

| 명령 | 결과 | 비고 |
|---|---|---|
| `yq eval '.' .github/workflows/pr-gate.yml` | PASS | YAML parse 성공 |
| `yq -o=json '.' .github/workflows/pr-gate.yml \| jq -e '<macOS job contract assertions>'` | PASS | runner, skip env, seed, `/bin/bash` 2회, 검증 block, summary dependency 확인 |
| `bash -n install.sh` | PASS | shell 문법 정상 |
| `yq -r '.jobs["test-macos-install"].steps[].run // ""' .github/workflows/pr-gate.yml \| bash -n` | PASS | 새 macOS job의 모든 run block 문법 정상 |
| Brewfile `^brew "neovim"$` exact-once assertion | PASS | `8:brew "neovim"` 한 건 |
| `yq -p=toml -o=json '.' config/codex/config.toml \| jq -e '<required keys>'` | PASS | Codex source TOML parse/query 성공 |
| `yq -p=toml -r '.opener.edit[] \| select(.for == "unix") \| .run' config/yazi/yazi.toml` | PASS | 결과 `nvim "%s"` |
| `bash tests/install/config-merge.sh` | PASS | 기존 TOML sentinel, malformed 입력 보존, 2회 멱등 경로 포함 |
| `bash tests/profile/profile-idempotency.sh` | PASS | macOS zprofile/zshrc sentinel, 2회 적용, marker 처리 포함 |
| `bash -n tests/install/config-merge.sh tests/profile/profile-idempotency.sh` | PASS | 회귀 테스트 문법 정상 |
| `git diff --check` | PASS | whitespace 오류 없음 |

로컬 호스트 보호 조건 때문에 all-in-one macOS 설치 자체는 재실행하지 않았다. `actionlint`와 `shellcheck`는 현재 호스트에 없어 실행하지 못했으나, 새 macOS job에는 GitHub expression 추가가 없고 YAML 구조·shell block·summary 연결을 각각 검증했다.

## 결함

평가 범위 내 통과를 막는 결함 없음.

## 자체 평가 대조

인수인계의 변경 파일, 설계 결정, 정적 검증 PASS, 실제 macOS runner 미실행 제약이 코드 및 재실행 결과와 일치한다.
