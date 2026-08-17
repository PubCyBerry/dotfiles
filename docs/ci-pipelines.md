# CI 파이프라인 가이드

이 저장소는 설치, 설정, 언인스톨 계약을 검증하는 세 가지 GitHub Actions 파이프라인을 운영한다.

---

## 파이프라인 개요

| 파이프라인 | 파일 | 트리거 | 목적 | 소요 시간 |
|---|---|---|---|---|
| **PR Gate** | `pr-gate.yml` | push/PR 자동 | 실제 installer의 fresh/update 및 실패 계약 | ~20분 |
| **Freshness Check** | `freshness-check.yml` | 매주 월요일 | 업스트림 변경 감지 | ~5분 |
| **Uninstall Validation** | `uninstall-validation.yml` | PR 자동, 수동 | Safe-Clean-Uninstall 계약 검증 | ~10분 |

---

## 파이프라인 1: PR Gate

`install.sh`, `install.ps1`, `uninstall.sh`, `uninstall.ps1`, `config/`, `manifests/`, `scripts/`, `tests/` 변경 시 자동 실행되는 게이트 파이프라인이다. `tests/**`가 통째로 들어 있으므로 계약 스크립트를 새로 붙일 때 트리거를 따로 넓힐 필요가 없다 — 그 스크립트를 실행하는 단계만 잡에 추가하면 된다.

### 실행 흐름

```
lint       Ubuntu/macOS/Windows 실제 install 2회       config/manifest/agent 검증
  └──────────────────────────┬───────────────────────────────────────────┘
                           summary
```

job이 병렬로 실행되어 전체 소요 시간을 줄인다.

### Job 상세

**lint**
- `git ls-files '*.sh'`로 저장소 전체 셸 스크립트를 `shellcheck -x` 정적 분석
- 문법 오류, 불안전한 패턴(따옴표 누락 등)을 사전 차단
- **러너 이미지의 사전 설치본을 쓰지 않는다.** `manifests/shellcheck.tsv`가 pin한 버전을 받아 SHA-256을 검증하고 PATH 앞에 둔다. install 스크립트도 같은 파일을 보므로 CI와 로컬이 한 버전으로 모인다 ([shellcheck 관리](../AGENTS.md#shellcheck-관리))
- 내려받기 직후 `command -v shellcheck`와 `--version`으로 실제 해석되는 바이너리가 pin한 그 버전인지 단언한다. 이 단언이 없으면 PATH 해석이 바뀌는 순간 게이트가 조용히 뜻을 잃는다

**test-apt-install**
- apt 패키지 캐시 복원 후 `install.sh`를 두 번 실행
- Claude Code, skills는 CI 모드로 skip ([CI 모드 참고](#installsh-ci-모드))
- 완료 후 주요 도구 `--version` 확인: `git`, `tmux`, `jq`, `gh`, `rg`, `bat`, `fd`, `nvim`, `lazygit`, `delta`, `fzf`, `yazi`, `zoxide`, `starship`, `fnm`, `bun`
- 사용자 Codex 설정, shell profile, Claude statusLine sentinel 보존과 marker 멱등성을 확인
- `tests/install/failure-contract.sh`로 failure ledger, plugin 전체 사전검증, skip guard, shellcheck manifest validator와 구 패키지 안내를 확인
- `tests/ownership/install-receipt.sh`, `tests/ownership/direct-artifacts.sh`로 receipt 소유권과 direct artifact 버전 게이트를 확인. 실제 install 잡은 매번 새 HOME이라 `new` → `current` 전이만 지나므로, `upgrade`/`upgrade-blocked`/`modified`를 지나는 검사는 이 두 스크립트뿐이다
- `direct-artifacts.sh`는 install 스크립트에 pin되지 않은 원격 실행(`curl \| sh`, `latest`/`HEAD` 경로)이 새로 들어오는지도 정적으로 막는다. 면제는 herdr와 Antigravity CLI 두 installer뿐이며, 그 두 줄 **전체**와 일치할 때만 성립한다 — 호스트 이름이 줄 어딘가에 있으면 통과시키는 부분 일치를 쓰면 같은 줄 주석 한 마디로 제3의 호스트를 들여올 수 있다. 스크립트가 그 우회를 직접 단언한다
- `config/agents/roles/`의 실제 조립 결과를 `yq`로 검증한다

**test-macos-install**
- `/bin/bash install.sh --with-defaults`와 `/bin/bash install.sh`를 이어서 실행해 fresh 및 update 경로를 검증
- Homebrew Neovim, Git editor, Yazi opener가 실제 `nvim` executable을 가리키는지 확인
- 기존 Codex TOML과 `.zshrc` sentinel이 보존되고 profile marker가 중복되지 않는지 확인
- `tests/ownership/install-receipt.sh`, `tests/ownership/direct-artifacts.sh`를 Ubuntu 잡과 같이 돌린다. 두 스크립트는 `file_mode`/`tree_hash`의 BSD 경로(`stat -f`, `find -printf` 없음, `tar --sort` 없음)를 지나므로, 여기서 돌지 않으면 macOS 전용 회귀를 잡는 검사가 하나도 없다. `jq`/`rg`를 Brewfile이 주므로 install 뒤에 둔다

**test-windows-install**
- fake `USERPROFILE`/`HOME`/`GIT_CONFIG_GLOBAL`에서 `install.ps1`을 두 번 실행
- 사용자 Codex config/hook, PowerShell profile, Git 설정, 환경변수와 기존 PATH entry 보존 확인
- `tests/install/failure-contract.ps1`로 failure ledger, plugin 사전검증, shellcheck manifest validator의 case-sensitivity, 실행되지 않는 shellcheck 바이너리가 install을 끊지 않는지를 확인
- `tests/ownership/install-receipt.ps1`, `tests/ownership/direct-artifacts.ps1`로 receipt 소유권과 `Get-DirectFileState`/`Set-DirectFileVersion`의 버전 게이트를 확인. Ubuntu 잡의 같은 이름 스크립트와 짝을 이루는 계약이다
- 이 두 스크립트는 receipt를 `jq`로 읽으므로 `Ensure yq and jq` 단계가 `yq`와 함께 확보한다 (`SKIP_PACKAGES=1`이라 winget 단계가 깔지 않는다)

**test-configs**
- `git config --file config/git/gitconfig --list`: gitconfig 문법 검증
- `jq empty config/claude/*.json`: JSON 파일 문법 검증
- `yq -p=toml`: `config/codex/config.toml` TOML 문법 검증

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

## 파이프라인 2: Freshness Check

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

## 파이프라인 3: Uninstall Validation

`install.sh`, `install.ps1`, `config/`, `docs/uninstall.md` 변경 시 자동 실행되는 언인스톨 계약 검증 파이프라인이다.

### 검증 방식

GitHub Actions의 disposable runner에서 실제 installer와 uninstaller를 각각 두 번 실행한다. HOME/USERPROFILE과 Git config는 fake 경로로 격리한다.

검증 대상:

- dotfiles 마커 블록 제거 후 사용자 profile 내용 보존
- `~/.claude/CLAUDE.md`, `~/.codex/AGENTS.md`, hooks 파일 제거
- dotfiles agent role 제거: `~/.claude/agents/<name>.md`, `~/.codex/agents/<name>.toml`, 그리고 구 배포 경로 `~/.codex/skills/<name>/`
- 구 로컬 skill 배포분(`~/.claude/skills/`, `~/.gemini/config/skills/`의 `{subagent-creator,repo-scaffold}`) 소유권 판정 — 소스가 저장소에서 사라졌어도 receipt entry를 정리할 수 있어야 한다. 이 판정이 막히면 receipt preflight가 uninstall 전체를 중단시킨다. `tests/uninstall/safe-clean.{sh,ps1}`가 fresh install로는 재현되지 않는 이 경로를 직접 검증한다.
- 사용자 소유 agent/skill과 Codex 번들 skill(`~/.codex/skills/.system/`) 보존
- Claude `settings.json`에서 dotfiles 관리 키 제거 후 사용자 `statusLine` 보존
- Codex `config.toml`에서 dotfiles 기본값 제거 후 사용자 섹션 보존
- yazi/nvim/starship/tmux 설정 제거 시 사용자 파일 보존
- git 전역 설정에서 dotfiles 관리 키만 제거하고 사용자 키 보존

### Job 상세

| Job | 검증 내용 |
|---|---|
| unix | Linux/macOS 계열 경로와 bash profile 마커 정리 검증 |
| windows | Windows 경로와 PowerShell/Git Bash profile 마커 정리 검증 |

패키지 매니저의 실제 uninstall은 runner가 일회용 환경이라 검증하지 않는다. 대신 dotfiles가 관리한 설정 side effect만 안전하게 되돌릴 수 있는지 검증한다.

### 수동 실행 방법

Actions 탭 → **Uninstall Validation** → **Run workflow**로 실행한다.

---

## 설치 스크립트 CI 모드

`install.sh`와 `install.ps1`은 계정이 필요하거나 외부 서비스에 의존하는 단계를 같은 환경변수로 skip한다.

| 환경변수 | 스킵 대상 | 이유 |
|---|---|---|
| `SKIP_PACKAGES=1` | OS package manager, direct artifact, fnm/Node.js, npm 전역 패키지와 Windows package-dependent User 환경변수 | Windows entrypoint 및 config/profile uninstall 검증을 외부 package repository와 HKCU 환경변수에서 분리 |
| `SKIP_CLAUDE_CODE=1` | Claude Code 설치 + 설정 배포 | 계정/토큰 필요 |
| `SKIP_SKILLS=1` | Claude Code skills 설치 | Claude Code 의존 |
| `SKIP_PLUGINS=1` | Claude Code plugins 설치 | 외부 marketplace 의존 |
| `SKIP_HERDR=1` | herdr 설치 + 설정 배포 | pin되지 않은 원격 installer(`curl \| sh`, `irm`) |
| `SKIP_AGY_CLI=1` | Antigravity CLI(`agy`) 설치 | pin되지 않은 원격 installer(`curl \| bash`, `irm`). 이 값만으로는 Gemini MCP 등록이 꺼지지 않는다 — 3-3의 조건은 `~/.gemini` 존재 **또는** `agy` PATH이고, 설정 배포가 그 디렉터리를 먼저 만든다 |
| `SKIP_AGY=1` | Antigravity 설정 배포 (`config/agy/` → `~/.gemini/`) | CLI와 소유자가 달라 플래그도 별개 |
| `SKIP_SHELLCHECK=1` | pinned shellcheck 설치 | 로컬에서 다른 버전을 쓰려는 경우. **CI는 쓰지 않는다** — pin된 artifact라 설치 경로를 그대로 검증한다 |
| `SKIP_RHWP=1` | rhwp 설치 + MCP 등록 | pinned artifact 다운로드를 제외할 때 |
| `GITHUB_TOKEN=...` | `gh_release_tag()` 함수 | API rate limit 우회 |

Safe-Clean-Uninstall의 config/profile 시나리오처럼 외부 패키지 설치를 제외해 실행하려면:

```bash
SKIP_PACKAGES=1 SKIP_CLAUDE_CODE=1 SKIP_SKILLS=1 SKIP_PLUGINS=1 bash install.sh
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
