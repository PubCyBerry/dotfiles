# macOS fresh 및 재설치 계약

- 상태: 완료
- 스펙 출처: GitHub Issue #13
- 날짜: 2026-08-12

## 무엇을 만들었나

macOS `Brewfile`에 Neovim을 추가해 fresh install에서도 Git과 Yazi가 지정한 editor를 실제로 실행할 수 있게 했다. PR Gate는 격리된 Git config와 기존 Codex/zsh sentinel을 준비한 뒤 stock `/bin/bash`로 설치를 두 번 실행하고, 도구 가용성·설정 보존·profile 멱등성을 검증한다.

## 변경 파일

| 파일 | 변경 내용 |
|---|---|
| `manifests/Brewfile` | Homebrew Neovim 설치 항목 추가 |
| `.github/workflows/pr-gate.yml` | macOS fresh/update 2회 설치와 계약 assertion 추가 |
| `docs/ci-pipelines.md` | macOS PR Gate 검증 범위 문서화 |
| `docs/handoff/007-macos-install.md` | 구현 및 QA 인수인계 기록 |

## 설계 결정

- `install.sh`의 associative array 의존성은 Issue #7에서 이미 제거됐으므로 shell bootstrap이나 parser를 다시 만들지 않았다. macOS 기본 `/bin/bash`를 CI에서 명시해 현재 portable 경로를 직접 검증한다.
- 별도 테스트 helper를 만들지 않고 disposable macOS runner의 job 안에서 사용자 설정을 seed하고 결과를 assertion한다.
- `GIT_CONFIG_GLOBAL`은 runner 임시 경로로 격리해 runner 기본 Git 설정과 테스트 결과가 서로 영향을 주지 않게 했다.

## 가정

- `macos-latest` runner의 `$HOME`은 job 종료 시 폐기되므로 Codex/zsh sentinel seed가 사용자 데이터를 침범하지 않는다.
- `Brewfile`이 설치하는 mikefarah `yq`가 TOML parse와 Yazi opener 조회를 제공한다.

## 검증

| 명령 | 결과 |
|---|---|
| `yq eval '.' .github/workflows/pr-gate.yml` | PASS |
| `bash -n install.sh` | PASS |
| `git diff --check` | PASS |
| `yq -p=toml -o=json '.' config/codex/config.toml` | PASS |
| `yq -p=toml -o=json '.' config/yazi/yazi.toml` | PASS |
| `yq -p=toml -r '.opener.edit[] \| select(.for == "unix") \| .run' config/yazi/yazi.toml` | PASS (`nvim "%s"`) |
| Brewfile Neovim 항목 및 workflow 2회 실행 정적 assertion | PASS |

## QA 확인 필요

1. GitHub Actions `test-macos-install`에서 first/second install이 모두 exit 0인지 확인한다.
2. first install 직후 `nvim --version`, second install 뒤 `brew list --formula --versions neovim`과 `nvim --version`이 성공하는지 확인한다.
3. 격리된 global Git config의 `core.editor`가 정확히 `nvim -f`이며 `nvim`이 executable인지 확인한다.
4. 배포된 Yazi TOML의 Unix opener가 `nvim "%s"`이고 해당 command가 executable인지 확인한다.
5. 기존 Codex `sentinel = "keep"`, `.zshrc`의 `# user-sentinel`이 남고 dotfiles begin/end marker가 각각 하나인지 확인한다.

## 알려진 제약

- 로컬 환경 보호를 위해 실제 macOS 설치는 실행하지 않았다. 전체 설치와 Homebrew package 가용성 검증은 macOS GitHub-hosted runner가 담당한다.
- macOS defaults의 개별 값은 기존 범위대로 실행 성공만 확인하며 전체 상태를 assertion하지 않는다.

## 자체 평가

- **스펙 충족도**: Neovim 설치, stock Bash 2회 실행, Git/Yazi executable, Codex/zsh sentinel 보존을 모두 CI 계약에 포함했다.
- **검증 상태**: workflow/YAML/TOML/Yazi query/shell 문법과 diff 정적 검증은 통과했다. 실제 macOS runner 실행은 미검증이다.
- **약한 곳**: Homebrew와 macOS upstream 상태는 로컬에서 재현하지 않았으며 원격 job에서 최종 확인해야 한다.
- **부작용 위험**: macOS CI 시간이 두 번째 `brew bundle`만큼 늘 수 있으나, 이미 설치된 formula의 idempotent 확인 경로라 추가 설치는 없다.
- **판정**: 완료.

## 후속 작업

- Issue #16: direct-download binary와 symlink를 install receipt 소유권에 포함한다.
