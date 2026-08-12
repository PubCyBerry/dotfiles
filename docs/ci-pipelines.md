# CI 파이프라인 가이드

이 저장소는 설치, 설정, 언인스톨 계약을 검증하는 네 가지 GitHub Actions 파이프라인을 운영한다.

---

## 파이프라인 개요

| 파이프라인 | 파일 | 트리거 | 목적 | 소요 시간 |
|---|---|---|---|---|
| **PR Gate** | `pr-gate.yml` | push/PR 자동 | 빠른 피드백 | ~15분 |
| **Precision Validation** | `precision-validation.yml` | 수동 또는 PR | 단계별 세부 검증 | ~30-40분 |
| **Freshness Check** | `freshness-check.yml` | 매주 월요일 | 업스트림 변경 감지 | ~5분 |
| **Uninstall Validation** | `uninstall-validation.yml` | push/PR 자동, 수동 | Safe-Clean-Uninstall 계약 검증 | ~10분 |

---

## 파이프라인 1: PR Gate

`install.sh`, `config/`, `manifests/`, `scripts/` 변경 시 자동 실행되는 게이트 파이프라인이다.

### 실행 흐름

```
lint (ShellCheck)
test-apt-install (전체 install.sh, CI 모드)   test-configs    test-manifest-syntax    test-agent-roles
                      ↓                              ↓                  ↓                     ↓
                                            summary (항상 실행)
```

job이 병렬로 실행되어 전체 소요 시간을 줄인다.

### Job 상세

**lint**
- `shellcheck -x install.sh`로 셸 스크립트 정적 분석
- 문법 오류, 불안전한 패턴(따옴표 누락 등)을 사전 차단

**test-apt-install**
- apt 패키지 캐시 복원 후 `install.sh` 실행
- Claude Code, skills는 CI 모드로 skip ([CI 모드 참고](#installsh-ci-모드))
- 완료 후 주요 도구 `--version` 확인: `git`, `tmux`, `jq`, `gh`, `rg`, `bat`, `fd`, `nvim`, `lazygit`, `delta`, `fzf`, `yazi`, `zoxide`, `starship`, `fnm`, `bun`
- `config/agents/roles/`가 `~/.codex/agents/<name>.toml`로 실제 조립 배포됐는지 확인 — TOML 파싱, `name` 일치, `developer_instructions`와 소스 `body.md` 일치. 구 skill 경로(`~/.codex/skills/<name>/`)가 남지 않았는지도 함께 본다 (`SKIP_CLAUDE_CODE=1`이라 Claude 쪽 배포는 이 job에서 검증하지 않는다)

**test-macos-install**
- `/bin/bash install.sh --with-defaults`와 `/bin/bash install.sh`를 이어서 실행해 fresh 및 update 경로를 검증
- Homebrew Neovim, Git editor, Yazi opener가 실제 `nvim` executable을 가리키는지 확인
- 기존 Codex TOML과 `.zshrc` sentinel이 보존되고 profile marker가 중복되지 않는지 확인

**test-configs**
- `git config --file config/git/gitconfig --list`: gitconfig 문법 검증
- `jq empty config/claude/*.json`: JSON 파일 문법 검증
- Python `tomllib`: `config/codex/config.toml` TOML 문법 검증

**test-manifest-syntax**
- `manifests/apt.txt`: 각 줄이 유효한 apt 패키지명 패턴인지 확인
- `manifests/npm-global.txt`: `@scope/package` 형식 확인
- `manifests/skills.txt`: `owner/repo@skill-name` 형식 확인

**test-agent-roles**
- `uv run --with pyyaml --python 3.11 scripts/validate-agent-roles.py`: `config/agents/roles/` 소스 검증. 메타를 body와 조립한 뒤 PyYAML/TOML로 파싱하므로 조립 후에야 드러나는 오류도 잡는다
- Claude agent와 `subagent-creator`는 같은 공용 engine으로 malformed YAML, 알 수 없는 key·tool, field type을 검사한다. unittest가 최신 field와 model alias의 회귀를 고정한다
- Codex 쪽 허용 키·`model_reasoning_effort`·`sandbox_mode`, 파일을 쓰는 role의 `read-only` sandbox도 검사한다
- `body.md`에 플랫폼 고유 표현(`메인 스레드`, `서브에이전트`, `subagent`, `SKILL.md`, `Task 도구`)이 없는지 확인. 같은 문장이 Claude·Codex 양쪽에서 성립해야 한다

### apt 캐시 전략

`manifests/apt.txt` 해시를 캐시 키로 사용한다. 패키지 목록이 바뀌면 자동으로 캐시가 무효화된다.

```
캐시 키: apt-ubuntu-24.04-<sha256(manifests/apt.txt)>
경로: /var/cache/apt/archives
```

---

## 파이프라인 2: Precision Validation

각 설치 단계를 독립적인 job으로 분리해 실패 위치를 명확히 파악할 수 있다.

### 실행 흐름

```
phase1-apt (apt 패키지)
    ├── phase2-official-scripts (zoxide, starship, atuin, fnm, bun)
    │       └── phase4-nodejs-npm (fnm → Node LTS → npm packages)
    ├── phase3-github-releases (yazi, lazygit, nvim, delta, fzf)     ← phase2와 병렬
    └── phase5-configs (설정 파일 배포)                              ← phase3와 병렬
                            ↓
                    final-summary (항상 실행)
```

phase2와 phase3는 phase1이 끝나면 동시에 시작된다.

### Job 상세

| Job | 검증 내용 | 아티팩트 |
|---|---|---|
| phase1-apt | apt 패키지 설치, bat/fd 심볼릭 링크 | `phase1-versions.txt` |
| phase2-official-scripts | 공식 설치 스크립트 5개 | `phase2-versions.txt` |
| phase3-github-releases | GitHub releases 바이너리 5개 | `phase3-versions.txt` |
| phase4-nodejs-npm | Node LTS, npm 전역 패키지 | `phase4-versions.txt` |
| phase5-configs | 설정 파일 배포 시뮬레이션 | 없음 |

### 수동 실행 방법

1. GitHub 저장소 → **Actions** 탭
2. 왼쪽 목록에서 **Precision Validation** 클릭
3. 오른쪽 상단 **Run workflow** 버튼 클릭

### 아티팩트 확인

각 job 완료 후 Actions 탭 → 해당 실행 → Artifacts 섹션에서 `phase*-versions.txt` 다운로드 가능. 설치된 도구 버전을 추적하거나 문제 진단에 활용한다.

---

## 파이프라인 3: Freshness Check

업스트림 도구의 최신 버전을 주 1회 수집해 GitHub releases URL 변경이나 새 버전을 조기에 감지한다.

### 실행 일정

매주 월요일 10:00 UTC (한국 시간 19:00)에 자동 실행된다.

### 점검 대상 도구

zoxide, starship, atuin, fnm, bun, yazi, lazygit, neovim, git-delta, fzf

### 결과 확인

Actions 탭 → **Freshness Check** → 가장 최근 실행 → Artifacts → `upstream-report-<run-id>` 다운로드

```
zoxide     v0.9.4
starship   v1.20.1
atuin      v18.3.0
fnm        v1.36.0
bun        bun-v1.1.20
yazi       v0.3.0
lazygit    v0.41.0
neovim     v0.10.1
git-delta  0.17.0
fzf        v0.53.0
```

---

## 파이프라인 4: Uninstall Validation

`install.sh`, `install.ps1`, `config/`, `scripts/`, `docs/uninstall.md` 변경 시 자동 실행되는 언인스톨 계약 검증 파이프라인이다.

### 검증 방식

GitHub Actions runner의 실제 사용자 환경을 지우지 않고, 격리된 fake HOME/USERPROFILE 아래에 dotfiles가 만드는 대표 side effect를 심은 뒤 제거한다.

검증 대상:

- dotfiles 마커 블록 제거 후 사용자 profile 내용 보존
- `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, hooks 파일 제거
- dotfiles agent role 제거: `~/.claude/agents/<name>.md`, `~/.codex/agents/<name>.toml`, 그리고 구 배포 경로 `~/.codex/skills/<name>/`
- dotfiles 로컬 skill 제거: `~/.claude/skills/<name>/`
- 사용자 소유 agent/skill과 Codex 번들 skill(`~/.codex/skills/.system/`) 보존
- Claude `settings.json`에서 dotfiles 관리 키 제거 후 사용자 `statusLine` 보존
- Codex `config.toml`에서 dotfiles 기본값 제거 후 사용자 섹션 보존
- yazi/nvim/starship/tmux 설정 제거 시 사용자 파일 보존
- git 전역 설정에서 dotfiles 관리 키만 제거하고 사용자 키 보존

### Job 상세

| Job | 검증 내용 |
|---|---|
| ubuntu-safe-clean-uninstall | Linux/macOS 계열 경로와 bash profile 마커 정리 검증 |
| windows-safe-clean-uninstall | Windows 경로와 PowerShell/Git Bash profile 마커 정리 검증 |

패키지 매니저의 실제 uninstall은 runner가 일회용 환경이라 검증하지 않는다. 대신 dotfiles가 관리한 설정 side effect만 안전하게 되돌릴 수 있는지 검증한다.

### 수동 실행 방법

Actions 탭 → **Uninstall Validation** → **Run workflow**로 실행한다.

---

## install.sh CI 모드

파이프라인은 계정이 필요하거나 외부 서비스에 의존하는 단계를 환경변수로 skip한다.

| 환경변수 | 스킵 대상 | 이유 |
|---|---|---|
| `SKIP_CLAUDE_CODE=1` | Claude Code 설치 + 설정 배포 | 계정/토큰 필요 |
| `SKIP_SKILLS=1` | Claude Code skills 설치 | Claude Code 의존 |
| `GITHUB_TOKEN=...` | `gh_release_tag()` 함수 | API rate limit 우회 |

로컬에서 CI와 동일하게 실행하려면:

```bash
SKIP_CLAUDE_CODE=1 SKIP_SKILLS=1 bash install.sh
```

---

## 로컬에서 파이프라인 재현: act

[`act`](https://github.com/nektos/act)는 GitHub Actions를 로컬 Docker 환경에서 실행하는 도구다.

```bash
# 설치 (macOS/Linux)
brew install act
# 또는
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

# pr-gate workflow 로컬 실행
act push --workflows .github/workflows/pr-gate.yml

# uninstall-validation workflow 로컬 실행
act push --workflows .github/workflows/uninstall-validation.yml

# 특정 job만 실행
act push --job lint

# secrets 전달
act push --secret GITHUB_TOKEN="$(gh auth token)"
```

> Ubuntu 22.04 이상에서는 `ubuntu-24.04` 이미지를 로컬에서 사용하려면 Docker가 설치되어 있어야 하며, 이미지 크기(~1-20GB)에 따라 초기 다운로드에 시간이 걸린다.
