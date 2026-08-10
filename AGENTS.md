# AGENTS.md

Windows 11 / Ubuntu / macOS 환경을 위한 개인 dotfiles. 터미널 설정, 패키지 설치 스크립트, AI 에이전트 설정을 관리한다.

## Agent skills

### Issue tracker

Issues live in GitHub Issues (`github.com/PubCyBerry/dotfiles`). See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary (needs-triage / needs-info / ready-for-agent / ready-for-human / wontfix). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## 설치 명령

### Windows (주 환경)

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\install.ps1
```

### Linux (Ubuntu 22.04+)

```bash
# 저장소 클론 후 단일 진입점 실행
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

## 아키텍처

```text
dotfiles/
├── install.ps1          # Windows 설치 (all-in-one)
├── install.sh           # Ubuntu 설치 (all-in-one)
├── config/
│   ├── bash/            # bash dotfiles (bashrc, inputrc) — Git Bash + Linux 공통, 마커 방식 삽입
│   ├── agents/          # AI 에이전트 공통 자산
│   │   ├── global.md    # Claude/Codex 공통 전역 지침
│   │   └── roles/       # planner/generator/evaluator — 공용 body.md + 플랫폼별 메타
│   ├── claude/          # Claude Code 설정 (settings.json, hooks, skills, claude-hud)
│   ├── codex/           # Codex 설정 (config.toml, hooks.json, hooks/)
│   ├── git/
│   │   └── gitconfig    # OS-중립. autocrlf/fileMode은 install 스크립트가 OS별 주입
│   ├── nvim/            # Neovim 설정 (lazy.nvim + yazi.nvim)
│   ├── powershell/      # Windows 전용 (profile.ps1 — fnm, zoxide, starship 초기화)
│   ├── tmux/            # tmux 설정 (tmux.windows.conf, tmux.linux.conf)
│   ├── macos/           # macOS 전용 (.macos — 시스템 기본값 설정)
│   ├── yazi/            # yazi 설정 (yazi.toml — nvim opener)
│   └── starship.toml
├── manifests/           # 패키지/스킬/플러그인 목록
│   ├── winget.txt       # Windows winget 패키지 ID
│   ├── apt.txt          # Ubuntu apt 패키지
│   ├── Brewfile         # macOS Homebrew 패키지
│   ├── npm-global.txt   # npm 전역 패키지 (@openai/codex)
│   ├── skills.txt       # Claude Code skills (owner/repo@skill-name)
│   └── plugins.txt      # Claude Code 플러그인 (marketplace + plugin@marketplace + scope)
├── scripts/
│   └── validate-agent-roles.py    # config/agents/roles/ 검증 (CI + 로컬 공용)
└── docs/
    ├── tools.md                   # CLI 도구 사용법 cheatsheet
    ├── ai-agents.md               # Claude Code, 플러그인, skills 상세
    ├── claude-hud.md              # Claude HUD 설정 가이드
    ├── uninstall.md               # 클린 언인스톨 가이드
    ├── git-commit-convention.md   # Conventional Commits 규칙
    ├── worktree-git-workflows.md  # Worktree 커밋 히스토리 관리 전략
    ├── ci-pipelines.md            # GitHub Actions CI 파이프라인 가이드
    └── github-actions.md          # GitHub Actions 핵심 개념 레퍼런스
```

### Windows install.ps1 실행 순서

1. `manifests/winget.txt` → winget 패키지 설치 (사전 잠금 프로세스 경고, 실패 시 종료 코드 원인 + winget 메시지 출력, 마지막에 요약)
   1-1. `config/git/gitconfig` → git config 병합 + Windows override (`autocrlf=true`, `fileMode=false`)
   1-2. `config/tmux/tmux.windows.conf` → `~/.tmux.conf` 복사
   1-3. `YAZI_FILE_ONE` 환경변수 설정 (Git file.exe 경로)
   1-4. `config/yazi/` → `%APPDATA%\yazi\config\` 배포 (nvim opener 설정)
   1-5. Neovim PATH 환경변수 설정 (`C:\Program Files\Neovim\bin`)
   1-6. `config/nvim/` → `$LOCALAPPDATA\nvim\` 배포 (lazy.nvim Structured Setup, 항상 덮어쓰기)
2. fnm → Node.js LTS (설치 후 활성 버전 외 구버전 자동 삭제)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code native 설치
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
4. PowerShell 프로파일 설정 (`config/powershell/profile.ps1`, 마커 방식)
5. Git Bash 프로파일 설정 (`config/bash/bashrc`, 마커 방식 → `~/.bashrc`)
6. `manifests/skills.txt` → npx skills 설치
7. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### macOS install.sh 실행 순서

1. `manifests/Brewfile` → Homebrew 패키지 설치
   1-1. `config/git/gitconfig` → git config 병합 + macOS override (`autocrlf=input`, `fileMode=true`)
   1-2. `config/tmux/tmux.linux.conf` → `~/.tmux.conf` 복사
   1-3. `config/yazi/` → `~/.config/yazi/` 배포
   1-4. `config/nvim/` → `~/.config/nvim/` 배포 (항상 덮어쓰기)
   1-5. `config/starship.toml` → `~/.config/starship.toml` 배포
   1-6. `config/macos/.macos` → macOS 시스템 기본값 적용 (`--with-defaults` 플래그 시)
2. fnm → Node.js LTS (설치 후 활성 버전 외 구버전 자동 삭제)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code native 설치 (`curl -fsSL https://claude.ai/install.sh | bash`)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json `jq -s '.[0]*.[1]'` 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
5. `manifests/skills.txt` → npx skills 설치
6. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### Linux install.sh 실행 순서

1. `manifests/apt.txt` → apt 패키지 설치 
   1-1. `config/git/gitconfig` → git config 병합 + Linux override (`autocrlf=input`, `fileMode=true`)
   1-2. `config/tmux/tmux.linux.conf` → `~/.tmux.conf` 복사
   1-3. `config/yazi/` → `~/.config/yazi/` 배포
   1-4. `config/nvim/` → `~/.config/nvim/` 배포 (lazy.nvim Structured Setup, 항상 덮어쓰기)
   1-5. `config/starship.toml` → `~/.config/starship.toml` 배포
   1-6. 공식 install 스크립트: zoxide, starship, atuin, fnm(--skip-shell), bun
   1-7. GitHub releases 바이너리: neovim(tar.gz, 0.10+), yazi(.deb), lazygit(tar.gz), git-delta(.deb), fzf(tar.gz), eza(tar.gz), yq(단일 바이너리)
2. fnm → Node.js LTS (설치 후 활성 버전 외 구버전 자동 삭제)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code native 설치 (`curl -fsSL https://claude.ai/install.sh | bash`)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json `jq -s '.[0]*.[1]'` 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
6. `manifests/skills.txt` → npx skills 설치
7. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### skills 관리

skills는 두 경로로 관리한다.

- **원격 skill**: `manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지한다. 새 skill 추가 시 manifest에만 추가 후 install 스크립트를 다시 실행하면 `npx skills add --global`로 설치된다.
- **로컬 skill**: 이 저장소가 소유한 skill은 `config/claude/skills/<name>/`에 둔다. install 스크립트의 3-1 단계가 디렉터리 단위로 `~/.claude/skills/`에 배포하며, 원격 skill 경로는 건드리지 않는다. 예: `subagent-creator`(Claude Code subagent 정의 생성 skill).

### plugin 관리

Claude Code 플러그인은 `manifests/plugins.txt`에서 관리한다. skill과 달리 마켓플레이스 등록 → 설치 두 단계라, 한 줄에 세 필드를 둔다.

```text
<marketplace-source> <plugin>@<marketplace> [scope]
```

- `marketplace-source`: GitHub repo(`owner/name`), URL, 로컬 경로
- `plugin@marketplace`: 마켓플레이스 이름까지 명시한 플러그인 ID
- `scope`: `user`(기본) / `project` / `local`

install 스크립트가 줄마다 아래를 실행한다. 둘 다 멱등이라 이미 등록·설치된 항목은 그대로 두고 exit 0으로 끝난다(`Marketplace 'x' already on disk`, `Plugin "x" is already installed`).

```bash
claude plugin marketplace add <marketplace-source> --scope <scope>
claude plugin install <plugin>@<marketplace> --scope <scope>
```

현재 목록: `claude-hud`(statusline HUD), `caveman`(응답 압축 모드), `codex`(Claude Code 안에서 Codex 사용 — 마켓플레이스 소스 `openai/codex-plugin-cc`, 마켓플레이스 이름은 `openai-codex`로 다르다). 특정 프로젝트에만 쓰는 `project`/`local` scope 플러그인은 매니페스트에 넣지 않는다 — 머신 전역 설치가 아니라 프로젝트 소유이기 때문이다.

CI는 `SKIP_PLUGINS=1`로 이 단계를 건너뛴다(`claude` CLI가 없으면 자동으로도 skip).

플러그인은 skill·agent와 배포 경로가 다르다.

| 구분 | 소스 | 배포 경로 | 설치 주체 |
|---|---|---|---|
| plugin | `manifests/plugins.txt` | `~/.claude/plugins/` | `claude plugin` CLI |
| 원격 skill | `manifests/skills.txt` | `~/.claude/skills/` | `npx skills add` |
| 로컬 skill | `config/claude/skills/` | `~/.claude/skills/` | 디렉터리 복사 |
| agent | `config/agents/roles/` | `~/.claude/agents/`, `~/.codex/agents/` | 메타+body 조립 |
| hook | `config/claude/hooks/`, `config/codex/hooks/` | `~/.claude/hooks/`, `~/.codex/hooks/` | 파일 복사 + settings.json 병합 |
| MCP | (관리 안 함) | — | — |

### agent role 관리

Claude Code와 Codex에 공통으로 배포하는 역할 정의는 `config/agents/roles/<name>/`에 둔다. 시스템 프롬프트 본문은 한 곳(`body.md`)에만 두고, 플랫폼 차이는 메타 파일로만 흡수한다 — 같은 지침을 두 벌 유지하면 반드시 어긋나기 때문이다.

```text
config/agents/roles/<name>/
├── body.md              # 공용 시스템 프롬프트 (플랫폼 중립 표현으로 작성)
├── claude.frontmatter   # YAML — name/description/tools/model
└── codex.toml           # TOML — name/description/model_reasoning_effort/sandbox_mode
```

install 스크립트가 메타 + body를 이어붙여 양쪽 모두 **subagent**로 배포한다.

| 대상 | 산출 경로 | body가 들어가는 자리 |
|---|---|---|
| Claude Code | `~/.claude/agents/<name>.md` | frontmatter 아래 본문 |
| Codex | `~/.codex/agents/<name>.toml` | `developer_instructions` 값 |

두 경우 모두 이름 단위로만 덮어쓰므로 사용자가 직접 만든 agent는 보존된다. Codex는 `spawn_agent`로 병렬 위임되며, `codex exec`에서 이름이 노출되는지로 확인할 수 있다.

```bash
codex exec --sandbox read-only "spawn_agent 툴로 띄울 수 있는 custom agent 이름만 나열해."
```

플랫폼별 메타가 흡수하는 차이는 두 가지다.

- **권한**: Claude는 `tools` 화이트리스트, Codex는 `sandbox_mode`. 파일을 쓰는 role을 Codex에서 `read-only`로 배포하면 런타임에 조용히 실패하므로, 현재 3개 role 모두 `workspace-write`다.
- **모델**: Claude는 `model: opus`처럼 별칭을 쓴다. Codex는 `model`을 지정하지 않고 `model_reasoning_effort`만 둔다 — 모델 ID를 고정하면 카탈로그가 바뀔 때 깨지고, 생략하면 사용자 기본 모델을 상속하기 때문이다.

`body.md`는 "최종 메시지로 반환" 같은 특정 플랫폼 전용 표현을 피하고 "보고한다"로 쓴다 — 양쪽에서 같은 문장이 성립해야 한다. 또 `body.md`에 `'''`를 넣으면 안 된다 — Codex 쪽 TOML literal string이 조기 종료된다(검증 스크립트가 잡는다).

> Codex 0.145.0부터 subagent(`~/.codex/agents/<name>.toml`)를 지원한다. 그 전에는 위임 프리미티브가 없어 같은 role을 skill(`~/.codex/skills/<name>/`)로 배포했다. install 스크립트가 배포 시 그 구 경로를 이름 단위로 정리한다.

- `planner`: 1~4문장 아이디어를 전체 프로젝트 스펙(문제 정의, 스코프 3층, 아키텍처, 기술 선택 근거, 리스크, 마일스톤)으로 확장한다. 고수준 설계와 프로젝트 맥락에 집중하고 코드·구현 순서는 다루지 않는다.
- `generator`: 스펙에서 기능 **하나**를 골라 구현하고, 자체 평가 후 `docs/handoff/<NNN>-<slug>.md`에 QA 인수인계 파일을 남긴다. 여러 기능은 반복 호출로 처리한다.
- `evaluator`: 구현 결과를 6축 고정 루브릭(기능성·검증·깊이·코드 품질·통합·안전성)으로 채점해 PASS/FAIL을 판정한다. 축별 하한 미달이면 FAIL이며, `docs/handoff/<NNN>-<slug>.eval.md`에 재작업 지시서를 남긴다. 코드는 직접 고치지 않는다.

기본 흐름: `planner` → 기능마다 `generator` → `evaluator` → FAIL이면 같은 기능으로 `generator` 재호출.

새 role을 추가하거나 고치면 커밋 전에 검증한다. CI(`pr-gate.yml`의 `test-agent-roles`)가 같은 스크립트를 돌린다.

```bash
python3 scripts/validate-agent-roles.py
```

Claude subagent 형식을 더 엄격히 보려면 `subagent-creator` skill의 `scripts/validate_subagent.py`를 조립 결과에 돌린다(`cat claude.frontmatter body.md > /tmp/<name>.md`).

## 설치/언인스톨 변경 지침

설치 스크립트나 에이전트 설정을 변경할 때는 Safe-Clean-Install과 Safe-Clean-Uninstall 기준을 함께 검토한다.

- Safe-Clean-Install: 새 환경과 기존 환경 모두에서 반복 실행 가능해야 한다. 이미 설치된 패키지, PATH 항목, profile 마커 블록, JSON/TOML 설정, symlink, 바이너리 파일을 중복 생성하지 않는다.
- Safe-Clean-Install: 기존 사용자 설정은 보존한다. 덮어쓰기가 필요한 파일은 이 저장소가 소유한 파일인지 확인하고, 사용자 소유 가능성이 있으면 병합·마커 블록·백업 중 하나를 사용한다.
- Safe-Clean-Install: 설치가 만든 side effect를 문서화한다. 예: 패키지, 전역 npm 패키지, profile 변경, PATH 변경, 환경변수, `~/.local/bin` 바이너리, 설정 디렉터리, 캐시/데이터 디렉터리.
- Safe-Clean-Uninstall: dotfiles가 만든 것만 제거한다. 사용자 데이터, 사용자 소유 설정, 다른 도구가 공유하는 디렉터리, 수동 설치 패키지는 명시적 선택 없이 삭제하지 않는다.
- Safe-Clean-Uninstall: 제거 대상은 소유권을 판별할 수 있어야 한다. 마커 블록, manifest, 알려진 설치 경로, 파일 내용 비교, 백업 파일을 근거로 삼고, 확실하지 않으면 보존한다.
- Safe-Clean-Uninstall: 부분 설치와 실패 후 재실행을 고려한다. 파일이나 패키지가 없어도 실패하지 않고, 제거 후 재설치가 깨끗하게 가능해야 한다.
- 설치/언인스톨 로직을 바꿀 때는 `docs/uninstall.md`와 실행 순서가 함께 맞는지 확인한다.

## 주의사항

- Windows는 PowerShell 7+ (pwsh) 기준. `install.ps1`이 PS 7+ 프로파일에만 설정을 적용한다.
- Git Bash 지원: `install.ps1`이 `~/.bashrc`에 마커 방식으로 설정을 삽입한다. Git for Windows가 설치되어 있어야 한다.
- Linux는 Ubuntu 22.04 LTS 이상(apt 기반). `install.sh`는 sudo 권한이 필요하다.
- WSL2 환경에서 GitHub CLI(`gh`)를 사용하려면 브라우저 연동을 위해 `sudo apt install wslu`를 먼저 설치해야 한다.
- macOS는 Homebrew 기반. `install.sh`가 `manifests/Brewfile`로 패키지를 설치하고 `config/macos/.macos`로 시스템 기본값을 적용한다.
