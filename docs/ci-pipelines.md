# CI 파이프라인 가이드

이 저장소는 `install.sh`(Ubuntu 설치 스크립트)의 동작을 검증하는 세 가지 GitHub Actions 파이프라인을 운영한다.

---

## 파이프라인 개요

| 파이프라인 | 파일 | 트리거 | 목적 | 소요 시간 |
|---|---|---|---|---|
| **PR Gate** | `pr-gate.yml` | push/PR 자동 | 빠른 피드백 | ~15분 |
| **Precision Validation** | `precision-validation.yml` | 수동 또는 PR | 단계별 세부 검증 | ~30-40분 |
| **Freshness Check** | `freshness-check.yml` | 매주 월요일 | 업스트림 변경 감지 | ~5분 |

---

## 파이프라인 1: PR Gate

`install.sh`, `config/`, `manifests/` 변경 시 자동 실행되는 게이트 파이프라인이다.

### 실행 흐름

```
lint (ShellCheck)
test-apt-install (전체 install.sh, CI 모드)   test-configs    test-manifest-syntax
                      ↓                              ↓                  ↓
                                      summary (항상 실행)
```

4개 job이 병렬로 실행되어 전체 소요 시간을 줄인다.

### Job 상세

**lint**
- `shellcheck -x install.sh`로 셸 스크립트 정적 분석
- 문법 오류, 불안전한 패턴(따옴표 누락 등)을 사전 차단

**test-apt-install**
- apt 패키지 캐시 복원 후 `install.sh` 실행
- Claude Code, RTK, skills는 CI 모드로 skip ([CI 모드 참고](#installsh-ci-모드))
- 완료 후 주요 도구 `--version` 확인: `git`, `tmux`, `jq`, `gh`, `rg`, `bat`, `fd`, `nvim`, `lazygit`, `delta`, `fzf`, `yazi`, `zoxide`, `starship`, `fnm`, `bun`

**test-configs**
- `git config --file config/git/gitconfig --list`: gitconfig 문법 검증
- `jq empty config/claude/*.json`: JSON 파일 문법 검증
- Python `tomllib`: `config/codex/config.toml` TOML 문법 검증

**test-manifest-syntax**
- `manifests/apt.txt`: 각 줄이 유효한 apt 패키지명 패턴인지 확인
- `manifests/npm-global.txt`: `@scope/package` 형식 확인
- `manifests/skills.txt`: `owner/repo@skill-name` 형식 확인

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

## install.sh CI 모드

파이프라인은 계정이 필요하거나 외부 서비스에 의존하는 단계를 환경변수로 skip한다.

| 환경변수 | 스킵 대상 | 이유 |
|---|---|---|
| `SKIP_CLAUDE_CODE=1` | Claude Code 설치 + 설정 배포 | 계정/토큰 필요 |
| `SKIP_RTK=1` | RTK 설치 + `settings.json` hook 설정 준비 | 독점 외부 서비스 |
| `SKIP_SKILLS=1` | Claude Code skills 설치 | Claude Code 의존 |
| `GITHUB_TOKEN=...` | `gh_release_tag()` 함수 | API rate limit 우회 |

로컬에서 CI와 동일하게 실행하려면:

```bash
SKIP_CLAUDE_CODE=1 SKIP_RTK=1 SKIP_SKILLS=1 bash install.sh
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

# 특정 job만 실행
act push --job lint

# secrets 전달
act push --secret GITHUB_TOKEN="$(gh auth token)"
```

> Ubuntu 22.04 이상에서는 `ubuntu-24.04` 이미지를 로컬에서 사용하려면 Docker가 설치되어 있어야 하며, 이미지 크기(~1-20GB)에 따라 초기 다운로드에 시간이 걸린다.
