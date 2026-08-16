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
│   │   ├── global.md    # Claude/Codex/Antigravity 공통 전역 지침
│   │   └── roles/       # planner/generator/evaluator — 공용 body.md + 플랫폼별 메타
│   ├── agy/             # Antigravity (AGY) 설정 (hooks.json, hooks/)
│   ├── claude/          # Claude Code 설정 (settings.json, hooks, skills, claude-hud)
│   ├── codex/           # Codex 설정 (config.toml, hooks.json, hooks/)
│   ├── git/
│   │   └── gitconfig    # OS-중립. autocrlf/fileMode은 install 스크립트가 OS별 주입
│   ├── herdr/           # herdr(터미널 멀티플렉서) 설정 — default merge로 배포
│   │   ├── config.toml         # Linux/macOS
│   │   └── config.windows.toml # Windows (default_shell은 install이 주입)
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
│   ├── direct-artifacts.tsv # Linux direct artifact 버전·URL·SHA-256
│   ├── rhwp.tsv         # rhwp pinned release 플랫폼·버전·URL·SHA-256 (전 OS 공통)
│   ├── skills.txt       # Claude Code skills (owner/repo@skill-name)
│   └── plugins.txt      # Claude Code 플러그인 (marketplace + plugin@marketplace + scope)
├── scripts/
│   └── validate-agent-roles.py    # config/agents/roles/ 검증 (CI + 로컬 공용)
├── tests/
│   └── rhwp/                      # rhwp tree + MCP entry 소유권 계약 (네트워크 없음)
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
   1-7. herdr 설치(공식 installer, 이미 있으면 건너뜀) + `config/herdr/config.windows.toml` → `%APPDATA%\herdr\config.toml` 배포 (`SKIP_HERDR=1`이면 건너뜀)
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code WinGet 설치 (`SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 및 `skills/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `%USERPROFILE%\rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
4. PowerShell 프로파일 설정 (`config/powershell/profile.ps1`, 마커 방식)
5. Git Bash 프로파일 설정 (`config/bash/bashrc`, 마커 방식 → `~/.bashrc`)
6. `manifests/skills.txt` → npx skills 설치
7. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### macOS install.sh 실행 순서

1. 사전 설치된 Homebrew로 `manifests/Brewfile` 패키지 설치
   1-1. `config/git/gitconfig` → git config 병합 + macOS override (`autocrlf=input`, `fileMode=true`)
   1-2. `config/tmux/tmux.linux.conf` → `~/.tmux.conf` 복사
   1-3. `config/yazi/` → `~/.config/yazi/` 배포
   1-4. `config/nvim/` → `~/.config/nvim/` 배포 (항상 덮어쓰기)
   1-5. `config/starship.toml` → `~/.config/starship.toml` 배포
   1-6. `config/macos/.macos` → macOS 시스템 기본값 적용 (`--with-defaults` 플래그 시)
   1-7. herdr 설치 확인(Brewfile이 담당) + `config/herdr/config.toml` → `~/.config/herdr/config.toml` 배포 (`SKIP_HERDR=1`이면 건너뜀). 설정 병합에 yq가 필요해 실제 실행은 2-1 뒤다.
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code Homebrew cask 설치 (`SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json registry 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 및 `skills/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `~/rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
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
   1-6. `manifests/direct-artifacts.tsv` → pinned release를 SHA-256 검증 후 `~/.local` 아래에 receipt-managed 설치
   1-7. herdr 설치(공식 installer, 이미 있으면 건너뜀) + `config/herdr/config.toml` → `~/.config/herdr/config.toml` 배포 (`SKIP_HERDR=1`이면 건너뜀). 설정 병합에 yq가 필요해 실제 실행은 2-1 뒤다.
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code npm package 설치 (Node.js 22+, `SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json registry 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/claude/skills/` → `~/.claude/skills/` 로컬 skill 디렉터리 단위 배포, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 및 `skills/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `~/rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
6. `manifests/skills.txt` → npx skills 설치
7. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### skills 관리

skills는 두 경로로 관리한다.

- **원격 skill**: `manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지한다. 새 skill 추가 시 manifest에만 추가 후 install 스크립트를 다시 실행하면 `npx skills add --global`로 설치된다.
- **로컬 skill**: 이 저장소가 소유한 skill은 `config/claude/skills/<name>/`에 둔다. install 스크립트의 3-1 단계가 디렉터리 단위로 `~/.claude/skills/`에 배포하며, 원격 skill 경로는 건드리지 않는다. 현재 `subagent-creator`(Claude Code subagent 정의 생성), `repo-scaffold`(저장소를 에이전트 탐색용 형태로 스캐폴딩) 두 개다.

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
| 로컬 skill | `config/claude/skills/` | `~/.claude/skills/`, `~/.gemini/config/skills/` | 디렉터리 복사 |
| agent | `config/agents/roles/` | `~/.claude/agents/`, `~/.codex/agents/` | 메타+body 조립 |
| hook | `config/claude/hooks/`, `config/codex/hooks/`, `config/agy/hooks/` | `~/.claude/hooks/`, `~/.codex/hooks/`, `~/.gemini/hooks/` | 파일 복사 + settings.json / hooks.json 병합 |
| MCP | `manifests/rhwp.tsv` | `~/.codex/config.toml`, `~/.claude.json`, `~/.gemini/config/mcp_config.json` | install 스크립트 (receipt `values`) |

### rhwp와 MCP 관리

rhwp(HWP/HWPX 읽기·쓰기 CLI + stdio MCP 서버)는 `manifests/rhwp.tsv`에 pinned release로 관리한다. runtime `latest` 조회는 하지 않는다 — 검토하지 않은 바이너리가 조용히 들어오면 공급망 계약이 깨지기 때문이다.

```text
<platform>	<version>	<format>	<URL>	<SHA-256>
```

`platform`은 `windows-x86_64` / `linux-x86_64` / `macos-x86_64` / `macos-aarch64` 네 개이며, 네 행이 모두 같은 버전을 가리켜야 한 릴리즈를 pin한 것이 된다. 버전을 올릴 때는 upstream `SHA256SUMS.txt`의 값을 그대로 옮긴다.

install 스크립트는 순서대로 다음을 확인한 뒤에만 파일을 만진다.

1. manifest 형식(플랫폼 4종, 세 자리 버전, `latest`/`HEAD`가 없는 release URL, 64자 SHA-256)
2. 내려받은 archive의 SHA-256
3. archive 구조 — 최상위가 `rhwp/` 하나이고 그 아래가 파일·디렉터리뿐인지
4. 바이너리가 `rhwp v<version>`을 보고하는지

여기까지 통과하면 **archive 전체**를 `~/rhwp`(Windows `%USERPROFILE%\rhwp`)에 receipt-managed direct tree로 배치한다. 바이너리만 뽑아 `~/.local/bin`에 넣지 않는다 — LICENSE와 README가 함께 있어야 배포 조건이 성립하고, tree 하나를 identity로 잡아야 uninstall이 "정확히 이 상태일 때만 제거"를 판정할 수 있다.

MCP 등록은 호스트의 **공식 저장소**에만 한다.

| 호스트 | 파일 | 키 |
|---|---|---|
| Codex | `~/.codex/config.toml` | `[mcp_servers.rhwp]` |
| Claude Code | `~/.claude.json` | `.mcpServers.rhwp` |
| Antigravity (Gemini) | `~/.gemini/config/mcp_config.json` | `.mcpServers.rhwp` |

`~/.claude/settings.json`은 Claude Code 계약상 MCP 정의 파일이 **아니다**. 지원되지 않는 키를 만들지 않는다.

`command`는 PATH가 아니라 위 tree 안의 절대 경로(`~/rhwp/rhwp`, Windows는 `rhwp.exe`)를 쓴다. PATH에 넣지 않기로 한 이상 host가 `rhwp`를 이름으로 찾을 수 없기 때문이다.

entry는 receipt `values`의 `mcp:<host>:<name>` 키로 소유권을 잡는다. 사용자가 만든 동명 entry는 receipt에 없으므로 손대지 않고, 우리가 심은 뒤 사용자가 고쳤으면 그 다음 실행부터 보존한다. Codex 쪽은 TOML 편집이라 `yq`가 필요하며, 없으면 `config.toml` 병합과 같은 정책으로 건너뛴다(설치 전체를 실패시키지 않는다).

`SKIP_RHWP=1`로 이 단계 전체를 건너뛸 수 있다.

소유권 계약은 네트워크 없이 검증한다. CI(`pr-gate.yml`, `uninstall-validation.yml`)가 같은 스크립트를 돌린다.

```bash
bash tests/rhwp/mcp-ownership.sh
pwsh -NoProfile -File tests/rhwp/mcp-ownership.ps1
```

### herdr 관리

herdr(코딩 에이전트용 터미널 멀티플렉서)는 이 저장소의 pinned artifact 계약에서 **예외**다. 바이너리는 소유하지 않고 설정만 소유한다.

| 대상 | 소유자 | 경로 |
|---|---|---|
| 바이너리 (Windows) | 공식 installer (`https://herdr.dev/install.ps1`) | `%LOCALAPPDATA%\Programs\Herdr\bin` |
| 바이너리 (Linux) | 공식 installer (`https://herdr.dev/install.sh`) | installer 기본 경로 |
| 바이너리 (macOS) | Homebrew (`manifests/Brewfile`의 `brew "herdr"`) | brew prefix |
| 설정 | **이 저장소** (receipt-managed) | `%APPDATA%\herdr\config.toml`, `~/.config/herdr/config.toml` |

`manifests/rhwp.tsv`나 `manifests/direct-artifacts.tsv`처럼 URL + SHA-256으로 pin하지 않는 이유가 둘이다.

1. **pin할 semver가 없다.** v0.7.3\~v0.8.0 stable 릴리즈의 asset은 linux/macos 넷뿐이고, `herdr-windows-x86_64.zip`은 preview 태그에만 올라온다. 주 환경인 Windows에 stable 바이너리가 존재하지 않는다.
2. **herdr가 스스로 업데이트한다.** `herdr update`, `herdr channel set <stable|preview>`가 자체 채널로 바이너리를 교체한다. receipt로 tree 해시를 잡으면 사용자가 업데이트하는 순간 해시가 어긋나 그 다음 실행부터 "changed; preserving"으로 굳는다.

그래서 install은 `herdr`가 이미 PATH에 있으면 **아무것도 하지 않는다**. 없을 때만 공식 installer를 한 번 돌려 부트스트랩하고, 이후 버전 관리는 herdr에 맡긴다. uninstall도 같은 이유로 바이너리를 건드리지 않고 `config.toml`만 소유권을 판정해 제거한다.

#### 공식 installer가 만드는 side effect

부트스트랩이 한 번 도는 그 실행에서 installer가 **이 저장소의 receipt 밖에** 남기는 것들이다. 소유하지 않기로 한 대가이므로 uninstall이 되돌리지 않는다. 지우려면 직접 정리한다.

| 플랫폼 | side effect |
|---|---|
| Windows | `HKCU\Environment`의 `Path` 맨 앞에 `%LOCALAPPDATA%\Programs\Herdr\bin` prepend (`WM_SETTINGCHANGE` 브로드캐스트) |
| Windows | `%USERPROFILE%\.herdr\packages\standalone\` 아래 릴리즈 디렉터리 + `current` / bin junction (`HERDR_HOME`으로 위치 변경 가능) |
| Windows | `%LOCALAPPDATA%\Programs\Herdr\bin` 실행 파일 |
| Linux | `~/.local/bin/herdr` 실행 파일 하나. 프로파일은 건드리지 않고, PATH에 없으면 경고만 낸다 (`HERDR_INSTALL_DIR`로 위치 변경 가능) |
| macOS | Homebrew가 관리하므로 `brew uninstall herdr` |

Windows PATH는 이 저장소의 `Add-ToUserPath` + receipt 경로를 타지 않는다. 다른 항목과 달리 uninstall이 그 segment를 지우지 않으므로 `%LOCALAPPDATA%\Programs\Herdr\bin`은 남는다. installer 쪽 PATH 갱신 자체는 멱등이라(같은 항목을 지우고 다시 prepend) 반복 실행으로 늘어나지는 않는다.

installer는 자식 프로세스(`pwsh -NoProfile -NonInteractive -File <임시파일>`)로 격리해서 돌린다. 받은 문자열을 scriptblock으로 만들어 같은 프로세스에서 호출하면 그 안의 `exit`가 `try/catch`를 무시하고 install 전체를 끝내기 때문이다 — pin되지 않은 스크립트라 upstream이 `exit 0` 한 줄만 늘려도 이후 단계가 통째로 건너뛰어지고 종료 코드는 0이라 성공으로 보인다.

부트스트랩 실패는 경고로 끝난다 — `record_install_failure`/`Add-InstallFailure`를 타지 않는다. rhwp는 SHA-256으로 pin한 artifact를 이 저장소가 소유하므로 실패가 곧 계약 위반이지만, herdr 바이너리는 소유하지 않기로 한 서드파티 CDN이다. 일시적 장애가 dotfiles 설치 전체를 실패로 만드는 것은 그 결정과 어긋난다. 실패하면 설정 배포만 건너뛰고, 다음 실행이나 `herdr update`로 복구된다.

설정은 default merge로 배포한다 — herdr UI가 onboarding에서 `[ui]`를 스스로 기록하므로 통째로 덮어쓰면 사용자·UI 값이 날아간다.

단 herdr가 **자기 손으로 쓰는 빈 값**은 그 예외다. `default_shell = ""`나 `shell_mode = ""`는 사용자 선택이 아니라 placeholder인데, destination 우선 merge를 그대로 적용하면 그 빈 값이 dotfiles 기본값을 영구히 덮는다. 비어 있을 때만 다시 채우고, 사용자가 직접 넣은 값은 보존한다.

| 플랫폼 | 예외 키 | 덮이면 생기는 일 |
|---|---|---|
| Windows | `terminal.default_shell` | install이 주입한 Git Bash 경로가 죽고 pane이 PowerShell 5.1로 떨어진다 |
| Linux/macOS | `terminal.shell_mode` | `"auto"`가 죽어 macOS에서 login 셸이 안 뜬다 (`config.toml`의 존재 이유) |

Unix 쪽은 `merge_codex_config`에 placeholder 키를 가변 인자로 넘겨 처리한다 — 병합 전에 destination에서 그 키가 빈 문자열일 때만 걷어내면, 나머지는 기존 default merge 규칙 그대로다.

```bash
merge_codex_config "$src" "$dst" .terminal.shell_mode
```

`config/herdr/`에 파일이 둘인 이유는 셸 설정이 플랫폼마다 다르기 때문이다.

- `config.toml` (Linux/macOS): `default_shell`을 비워 `$SHELL`을 따르고, `shell_mode = "auto"`로 macOS에서만 login 셸을 쓴다.
- `config.windows.toml`: `default_shell`을 Git Bash로 고정한다. 값은 커밋하지 않고 install.ps1이 실제로 찾아낸 경로(`Program Files` / `Program Files (x86)`)를 yq로 주입한다.

Windows 설정에서 알아 둘 두 가지가 있다.

- **`shell_mode`를 Windows에서 설정하지 않는다.** herdr 0.8.0-preview에서 `shell_mode = "login"`을 주면 `default_shell` spawn이 조용히 실패하고 bare `cmd.exe`로 fallback한다. 서버 로그에도 에러가 남지 않고 `pane.spawned outcome="ok"`로 찍혀 원인 추적이 어렵다. 경로 표기(forward slash / backslash / 8.3 단축경로)와 무관하며 `shell_mode`를 지우면 그대로 Git Bash가 뜬다. 설정하지 않아도 pty에 붙은 bash는 interactive non-login으로 떠서 `~/.bashrc`를 읽으므로 잃는 것이 없다.
- **경로는 forward slash로 쓴다.** yq의 TOML 인코더가 백슬래시를 온전히 이스케이프하지 못해 `C:\Program Files\Git\bin\bash.exe`가 `\b`(백스페이스)로 깨진다. herdr는 forward slash 경로를 그대로 받는다.

`default_shell`은 단일 문자열이고 herdr에 fallback 체인이 없다(내장 fallback은 값이 비었을 때만 `$SHELL` → PowerShell/`/bin/sh`로 간다). Windows에서 두 번째 셸이 필요하면 `[[keys.command]]` 키바인딩으로 붙인다 — `config.windows.toml`이 `prefix+alt+p`에 pwsh 7 pane을 걸어 둔다.

`SKIP_HERDR=1`로 이 단계 전체를 건너뛸 수 있다. CI는 Linux/Windows 잡에서만 이 값을 쓴다 — 그쪽만 공식 installer(`curl | sh`, `Invoke-RestMethod`)를 타기 때문이다.

**macOS 잡은 `SKIP_HERDR`를 걸지 않는다.** 바이너리를 Brewfile이 주므로 `install_herdr`가 `command -v herdr`에서 바로 통과하고 원격 스크립트는 한 줄도 실행되지 않는다. 덕분에 설정 경로를 공급망 리스크 없이 CI가 검증한다. `pr-gate.yml`의 macOS 잡은 herdr가 config를 다시 쓴 뒤의 상태(`shell_mode = ""` + 사용자가 고른 `agent_panel_sort = "name"`)를 seed한 뒤 install을 두 번 돌리고, 다음 두 가지를 확인한다.

- `ui.agent_panel_sort == "name"` — 사용자 값이 보존된다
- `terminal.shell_mode == "auto"` — placeholder가 dotfiles 기본값으로 다시 채워진다

### agent role 관리

Claude Code와 Codex에 공통으로 배포하는 역할 정의는 `config/agents/roles/<name>/`에 둔다. 시스템 프롬프트 본문은 한 곳(`body.md`)에만 두고, 플랫폼 차이는 메타 파일로만 흡수한다 — 같은 지침을 두 벌 유지하면 반드시 어긋나기 때문이다.

```text
config/agents/roles/<name>/
├── body.md              # 공용 시스템 프롬프트 (플랫폼 중립 표현으로 작성)
├── claude.frontmatter   # YAML — Claude agent frontmatter fields
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
uv run --with pyyaml --python 3.11 scripts/validate-agent-roles.py
```

단일 Claude agent 파일은 같은 공용 engine을 쓰는 `subagent-creator` validator로 검사한다.

```bash
uv run --with pyyaml --python 3.11 config/claude/skills/subagent-creator/scripts/validate_subagent.py <agent.md>
```

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
