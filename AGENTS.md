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
│   ├── claude/          # Claude Code 설정 (settings.json, hooks)
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
│   ├── npm-global.txt   # npm 전역 패키지 (@openai/codex, ccusage)
│   ├── direct-artifacts.tsv # Linux direct artifact 버전·URL·SHA-256
│   ├── rhwp.tsv         # rhwp pinned release 플랫폼·버전·URL·SHA-256 (전 OS 공통)
│   ├── shellcheck.tsv   # shellcheck pinned release (전 OS + CI 공통 — 버전 drift 차단)
│   ├── skills.txt       # Claude Code skills (owner/repo@skill-name)
│   └── plugins.txt      # Claude Code 플러그인 (marketplace + plugin@marketplace + scope)
├── scripts/
│   ├── agent_validator.py         # Claude agent frontmatter 검증 engine
│   └── validate-agent-roles.py    # config/agents/roles/ 검증 (CI + 로컬 공용)
├── tests/
│   ├── install/                   # failure ledger + manifest validator 계약 (네트워크 없음)
│   ├── ownership/                 # receipt 소유권 + direct artifact 버전 게이트 계약 (네트워크 없음)
│   ├── rhwp/                      # rhwp tree + MCP entry 소유권 계약 (네트워크 없음)
│   └── uninstall/                 # receipt 소유권 판정 계약 (구 로컬 skill legacy 경로 포함)
└── docs/
    ├── tools.md                   # CLI 도구 사용법 cheatsheet
    ├── ai-agents.md               # Claude Code, 플러그인, skills 상세
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
   1-8. `manifests/shellcheck.tsv` → `%USERPROFILE%\.local\bin\shellcheck.exe` (pinned release, `SKIP_SHELLCHECK=1`이면 건너뜀)
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code WinGet 설치 (`SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. Antigravity CLI(`agy`) 설치(공식 installer, 이미 있으면 건너뜀, `SKIP_AGY_CLI=1`이면 건너뜀) + `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `%USERPROFILE%\rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
4. PowerShell 프로파일 설정 (`config/powershell/profile.ps1`, 마커 방식)
5. Git Bash 프로파일 설정 (`config/bash/bashrc`, 마커 방식 → `~/.bashrc`)
6. `manifests/skills.txt` → npx skills 설치·업데이트
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
   1-8. `manifests/shellcheck.tsv` → `~/.local/bin/shellcheck` (pinned release, `SKIP_SHELLCHECK=1`이면 건너뜀). receipt 기록에 jq가 필요해 실제 실행은 2-1 뒤다.
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code Homebrew cask 설치 (`SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json registry 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. Antigravity CLI(`agy`) 설치(공식 installer, 이미 있으면 건너뜀, `SKIP_AGY_CLI=1`이면 건너뜀) + `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `~/rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
5. `manifests/skills.txt` → npx skills 설치·업데이트
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
   1-8. `manifests/shellcheck.tsv` → `~/.local/bin/shellcheck` (pinned release, `SKIP_SHELLCHECK=1`이면 건너뜀). receipt 기록에 jq가 필요해 실제 실행은 2-1 뒤다.
2. fnm → Node.js LTS (기존 버전 보존, `DOTFILES_PRUNE_NODE_VERSIONS=1`일 때만 비활성 버전 정리)
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
   2-2. `config/codex/` → `~/.codex/` 배포 (`config.toml` 기본값 병합, `config/agents/global.md` → `AGENTS.md` 복사, `config/codex/hooks/` → `~/.codex/hooks/` 복사, `config/agents/roles/` → `~/.codex/agents/` subagent 조립 배포)
3. Claude Code npm package 설치 (Node.js 22+, `SKIP_CLAUDE_CODE=1`이면 설정과 함께 건너뜀)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json registry 병합, `config/agents/global.md` → `CLAUDE.md` 복사, `config/agents/roles/` → `~/.claude/agents/` subagent 조립 배포)
   3-2. Antigravity CLI(`agy`) 설치(공식 installer, 이미 있으면 건너뜀, `SKIP_AGY_CLI=1`이면 건너뜀) + `config/agy/` → `~/.gemini/` 배포 (`config/agents/global.md` → `GEMINI.md` 복사, `hooks.json` 병합, `hooks/` 배포, `SKIP_AGY=1`이면 건너뜀)
   3-3. `manifests/rhwp.tsv` → `~/rhwp` receipt-managed tree + Codex/Claude/Gemini MCP 등록 (`SKIP_RHWP=1`이면 건너뜀)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
6. `manifests/skills.txt` → npx skills 설치·업데이트
7. `manifests/plugins.txt` → `claude plugin marketplace add` + `claude plugin install`

### skills 관리

skill은 전부 `npx skills`가 관리한다. 이 저장소는 skill 파일을 배포하지 않는다 — 같은 skill을 두 벌 유지하면 어긋나고, 소유 skill도 자기 저장소에서 버전이 흐르는 편이 낫기 때문이다. `manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록만 유지한다.

install 스크립트는 줄마다 아래를 판단한다.

- `~/.agents/.skill-lock.json`이 그 이름을 **같은 source로** 추적 중이면 `npx skills update <name> --global --yes`
- 아니면(미설치, 구 로컬 배포 잔재, 다른 source의 동명 skill) `npx skills add <owner/repo> --skill <name> --global --yes --agent claude-code`

lock을 근거로 삼는 이유는 디렉터리 존재만으로는 npx가 관리하는 skill인지 구분되지 않기 때문이다. `npx skills list -g`가 그런 항목을 `Source: local`로 보고한다 — update 대상이 아니다. bash 쪽은 판정에 `jq`를 쓰며, 없으면 add로 처리한다(add는 언제나 안전하다).

update가 실패하면 add로 내려간다. upstream이 skill을 옮기거나 이름을 바꾸면 lock에는 옛 이름이 남아 update 분기만 타게 되는데, fallback이 없으면 그 머신의 install이 영구히 실패한다.

이 저장소가 소유한 skill도 같은 경로로 들어온다: `PubCyBerry/subagent-creator@subagent-creator`, `PubCyBerry/repo-scaffold@repo-scaffold`.

**skill은 pin되지 않는다.** `npx skills`에 버전 고정 옵션이 없어 실행할 때마다 upstream HEAD가 들어온다. `manifests/rhwp.tsv`가 release를 pin하는 것과 정책이 다르며, 이 비대칭은 CLI 한계지 의도한 완화가 아니다. 그래서 manifest에 저장소를 추가할 때는 그 저장소를 직접 검토한다. 현재 신뢰 근거는 `anthropics/skills`(1st party), `PubCyBerry/*`(본인 소유), `herdrdev/herdr`(외부 — 검토 후 추가)다.

> 마이그레이션: 예전에는 `config/claude/skills/`를 직접 복사했다. 그 시절 설치본을 쓰던 머신에는 `~/.claude/skills/`와 `~/.gemini/config/skills/`의 `{subagent-creator,repo-scaffold}`가 receipt entry와 함께 남는다. Claude 쪽은 다음 install에서 `npx skills add`가 덮어쓴다. uninstall은 이 두 이름을 고정 목록으로 알고 있어 unchanged 파일에 한해 정리한다 — 소스가 사라져 소유권 판정이 성립하지 않는 문제 때문에 `uninstall.sh` / `uninstall.ps1`에 legacy 허용 목록이 들어 있다.

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

현재 목록: `caveman`(응답 압축 모드), `codex`(Claude Code 안에서 Codex 사용 — 마켓플레이스 소스 `openai/codex-plugin-cc`, 마켓플레이스 이름은 `openai-codex`로 다르다). 특정 프로젝트에만 쓰는 `project`/`local` scope 플러그인은 매니페스트에 넣지 않는다 — 머신 전역 설치가 아니라 프로젝트 소유이기 때문이다.

CI는 `SKIP_PLUGINS=1`로 이 단계를 건너뛴다(`claude` CLI가 없으면 자동으로도 skip).

플러그인은 skill·agent와 배포 경로가 다르다.

| 구분 | 소스 | 배포 경로 | 설치 주체 |
|---|---|---|---|
| plugin | `manifests/plugins.txt` | `~/.claude/plugins/` | `claude plugin` CLI |
| skill | `manifests/skills.txt` | `~/.claude/skills/` | `npx skills add` / `npx skills update` |
| agent | `config/agents/roles/` | `~/.claude/agents/`, `~/.codex/agents/` | 메타+body 조립 |
| hook | `config/claude/hooks/`, `config/codex/hooks/`, `config/agy/hooks/` | `~/.claude/hooks/`, `~/.codex/hooks/`, `~/.gemini/hooks/` | 파일 복사 + settings.json / hooks.json 병합 |
| MCP | `manifests/rhwp.tsv` | `~/.codex/config.toml`, `~/.claude.json`, `~/.gemini/config/mcp_config.json` | install 스크립트 (receipt `values`) |

### statusline 관리

Claude Code statusline은 `config/claude/settings.json`의 `statusLine` 키로 관리한다. 명령은 `ccusage statusline` 하나이며, 실행 파일은 `manifests/npm-global.txt`의 npm 전역 패키지가 준다.

```json
{ "statusLine": { "type": "command", "command": "ccusage statusline", "padding": 0 } }
```

**플러그인이 아니라 설정으로 관리하는 이유.** 이전에는 `claude-hud` 플러그인이 이 자리를 채웠는데, 명령줄을 만드는 주체가 `/claude-hud:setup`이었다. 그 결과 statusLine 값에 fnm의 특정 Node 버전 경로와 플러그인 캐시 경로가 그대로 박혀, Node를 올리거나 플러그인 캐시가 바뀌면 statusline이 조용히 죽었다. 이 저장소는 그 값을 소유하지 않아 install이 고칠 수도 없었다. `ccusage statusline`은 PATH에서 이름 하나로 해석되므로 그 결합이 사라진다 — 세 OS가 같은 문자열을 쓴다.

`ccusage statusline`은 기본이 offline 모드다(캐시된 가격표를 쓰고 네트워크를 타지 않는다). 최신 가격이 필요하면 `--no-offline`을 붙인다.

**기존 설치 마이그레이션.** `settings.json`은 destination 우선 merge라 이미 깔린 claude-hud 명령이 managed 값을 영구히 덮는다. 플러그인이 매니페스트에서 빠지면 그 명령이 가리키는 `dist/index.js`는 사라지므로, 그대로 두면 statusline이 죽은 채 굳는다. 그래서 `scripts/merge-json-registry.jq`의 `purge_legacy_statusline`이 **claude-hud를 가리키는 statusLine만** 병합 전에 걷어낸다. 사용자가 직접 넣은 statusLine은 identity가 다르므로 보존된다 — hook의 `purge_relocated_hooks`와 같은 방식이다.

플러그인 바이너리와 마켓플레이스 등록은 이 저장소가 소유하지 않으므로 install이 지우지 않는다. 업그레이드하는 머신에서 한 번 직접 정리한다.

```bash
claude plugin uninstall claude-hud@claude-hud
claude plugin marketplace remove claude-hud
```

검증은 네트워크 없이 돌아간다(사용자 statusLine 보존 + claude-hud 값 교체를 한 실행에서 함께 단언한다).

```bash
bash tests/install/config-merge.sh
pwsh -NoProfile -File tests/install/config-merge.ps1
```

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

registry 파일이 **0바이트이거나 공백뿐이면 없는 것과 같이 취급해 seed한다.** 존재한다는 이유만으로 그대로 파서에 넘기면 `jq`가 빈 출력을 내거나(`Failed to write MCP entry`) `jq -e '.'`가 4로 끝나(`MCP registry unreadable`) 등록이 통째로 실패한다. 반대로 **내용이 있는데 깨진 파일은 seed하지 않는다** — 사용자 데이터가 들어 있을 수 있어 파서 실패로 남기고 보존하는 편이 맞다. 두 경우의 경계를 `tests/rhwp/mcp-ownership.{sh,ps1}`이 단언한다.

`SKIP_RHWP=1`로 이 단계 전체를 건너뛸 수 있다.

소유권 계약은 네트워크 없이 검증한다. CI(`pr-gate.yml`, `uninstall-validation.yml`)가 같은 스크립트를 돌린다.

```bash
bash tests/rhwp/mcp-ownership.sh
pwsh -NoProfile -File tests/rhwp/mcp-ownership.ps1
```

### shellcheck 관리

ShellCheck는 `manifests/shellcheck.tsv`에 pinned release로 관리한다. rhwp와 같은 계약이고 형식도 같지만, 플랫폼이 다섯 개(`windows-x86_64` / `linux-x86_64` / `linux-aarch64` / `macos-x86_64` / `macos-aarch64`)다. 다섯 행이 모두 같은 버전을 가리켜야 한 릴리즈를 pin한 것이 되며, validator가 그렇지 않은 manifest를 막는다.

```text
<platform>	<version>	<format>	<URL>	<SHA-256>
```

패키지 매니저를 쓰지 않는 이유는 **어느 것도 한 버전으로 모이지 않기 때문**이다. lint는 도구 버전이 곧 규칙 집합이라, 버전이 갈리면 같은 스크립트가 한쪽에서는 통과하고 다른 쪽에서는 실패한다.

| 경로 | 주는 버전 | pin 가능? |
|---|---|---|
| GitHub Actions `ubuntu-24.04` 러너 사전 설치본 | 0.9.0 (`shellcheck 0.9.0-1`) | 아니오 — 러너 이미지를 따라 움직인다 |
| Ubuntu apt | 22.04 = 0.8.0-2, 24.04 = 0.9.0-1, 26.04 = 0.11.0-2 | 아니오 — 배포판에 묶인다 |
| Homebrew `shellcheck` | 0.11.0 (formula 최신) | 아니오 — `versioned_formulae`가 비어 있다 |
| winget `koalaman.shellcheck` | 0.11.0 (최신) | 부분적 — `--version`은 되지만 다른 OS를 맞추지 못한다 |
| upstream release 바이너리 | 지정한 값 | **예** |

버전 차이가 실제로 만드는 결과는 0.11.0 릴리즈 노트에 그대로 있다. SC2002(useless use of cat)가 기본 비활성으로 바뀌고, SC2236/SC2237이 optional로 내려갔으며, SC2327~SC2332와 SC3062가 새로 생겼다. 0.9.0에서 깨끗한 스크립트가 0.11.0에서 새 경고를 받고, 0.11.0 기준으로 고친 코드가 0.9.0에서는 SC2002를 다시 맞는다.

그래서 install 스크립트와 CI(`pr-gate.yml`의 `lint` 잡)가 **같은 파일 하나**를 본다. lint 잡은 러너 사전 설치본을 쓰지 않고 manifest에서 받아 SHA-256을 검증한 뒤, 실제로 해석되는 `shellcheck`가 그 바이너리이고 그 버전을 보고하는지까지 단언한다. 이 단언이 없으면 PATH 해석이 바뀌는 순간 게이트가 조용히 뜻을 잃는다.

install 스크립트는 rhwp와 같은 순서로 확인한 뒤에만 파일을 만진다.

1. manifest 형식(플랫폼 5종, 단일 버전, 세 자리 semver, `latest`/`HEAD`가 없는 koalaman release URL, 64자 SHA-256)
2. 내려받은 archive의 SHA-256
3. archive 안의 경로 — Unix tarball은 `shellcheck-v<version>/shellcheck`, Windows zip은 최상위 `shellcheck.exe`
4. 바이너리가 `version: <version>`을 보고하는지

`SHA256SUMS`를 upstream이 게시하지 않으므로 값은 두 경로로 대조해서 넣는다. 내려받은 파일의 `sha256sum`과, GitHub가 서버에서 계산해 API로 노출하는 asset digest(`gh api repos/koalaman/shellcheck/releases/tags/v<ver> --jq '.assets[].digest'`)다. Windows 행은 `microsoft/winget-pkgs`의 `koalaman.shellcheck` manifest에 있는 `InstallerSha256`과도 일치한다.

배치 위치는 OS마다 다르되 결과는 같다 — 이 저장소가 배포하는 셸 프로파일이 이미 PATH 앞에 두는 자리에 넣는다.

| 플랫폼 | 경로 | PATH에 오르는 경로 |
|---|---|---|
| Linux/macOS | `~/.local/bin/shellcheck` | `config/bash/bashrc`가 `$HOME/.local/bin`을 PATH 맨 앞에 둔다 |
| Windows | `%USERPROFILE%\.local\bin\shellcheck.exe` | `config/powershell/profile.ps1`(pwsh)과 `config/bash/bashrc`(Git Bash)가 같은 일을 한다 |

Windows에서 어느 행을 쓸지는 **OS 비트수 하나로** 정한다. upstream이 Windows용으로 `windows-x86_64` 하나만 내고, Windows 11 ARM64는 그 x86_64 PE를 에뮬레이션으로 그대로 실행하기 때문이다. `PROCESSOR_ARCHITECTURE`로 가르면 같은 ARM64 머신에서도 install을 네이티브 pwsh로 띄웠는지(`ARM64` → 건너뜀) x64 에뮬레이션으로 띄웠는지(`AMD64` → 설치)에 따라 결과가 갈린다 — 프로세스 비트수는 pin 계약과 아무 상관이 없다. 정말 실행되지 않는 환경은 설치 직전의 `--version` 대조가 실패로 잡는다. 32비트 Windows만 지원 밖으로 두고 경고 후 건너뛴다(Unix의 `shellcheck_platform`이 지원하지 않는 아키텍처를 다루는 방식과 같다 — 설치 실패로 기록하지 않는다).

**User PATH(레지스트리)는 건드리지 않는다.** 프로파일이 이미 그 디렉터리를 앞에 두므로 새 side effect를 만들 이유가 없다. 이 선택 덕분에 배포판이 apt로 깔아 둔 `/usr/bin/shellcheck`가 남아 있어도 **셸 프로파일을 읽는 경로에서는** pin한 쪽이 먼저 잡힌다 — 그 상태를 CI의 Ubuntu 잡이 `command -v shellcheck`로 단언한다.

`manifests/apt.txt`와 `manifests/Brewfile`에서는 shellcheck를 뺐다. 소유자가 둘이면 PATH 순서에 따라 어느 쪽이 잡힐지가 환경마다 달라지고, 그것이 애초에 없애려던 문제다.

#### 마이그레이션: 기존 Linux·macOS 머신에서 구 패키지를 직접 지운다

manifest에서 빼는 것은 **앞으로 설치하지 않는다**는 뜻일 뿐, 이미 깔린 패키지를 지우지 않는다. install이 남의 소유 패키지를 제거하지 않기 때문이다(Safe-Clean-Install). 그래서 이 PR 이전에 프로비저닝한 머신에는 `/usr/bin/shellcheck`(또는 brew prefix)와 `~/.local/bin/shellcheck`가 **둘 다** 남고, 어느 쪽이 잡히는지는 그 순간의 PATH가 정한다.

`~/.bashrc` 마커 블록을 읽지 않는 소비자는 여전히 옛 버전을 본다 — VS Code ShellCheck 확장이 `/usr/bin/shellcheck`를 해석하는 경우, 프로파일을 거치지 않은 셸에서 실행된 Makefile, PATH가 씻긴 `sudo` 등이다. 그쪽에서는 CI가 통과시킨 코드에 0.8.0이 SC2002를 다시 붙인다.

문서만으로는 알아차릴 계기가 없으므로 install이 직접 알린다. `install_shellcheck`가 성공한 자리에서 `dpkg -s shellcheck` / `brew list --formula shellcheck`로 구 패키지가 남아 있는지 보고, 남아 있으면 두 줄짜리 안내를 출력한다. 알림에 그치고 `record_install_failure`를 타지 않는다 — 남의 소유 패키지라 이 스크립트가 지울 대상이 아니다(Safe-Clean-Install). `dpkg`/`brew`가 없는 환경에서는 `command -v`에서 바로 빠져 비용이 없다.

**업그레이드하는 머신에서 한 번 실행한다.**

```bash
# Ubuntu — apt가 깔아 둔 구버전 제거
dpkg -s shellcheck >/dev/null 2>&1 && sudo apt-get remove -y shellcheck

# macOS — brew formula 제거
brew list --formula shellcheck >/dev/null 2>&1 && brew uninstall shellcheck

# 확인: pin한 경로 하나만 남아야 한다
command -v shellcheck && shellcheck --version | awk -F': *' '$1=="version"'
```

> receipt 쪽 마이그레이션은 따로 있다. 예전 설치본을 쓰던 머신의 receipt에는 `apt:shellcheck` / `brew:shellcheck`가 남는데, manifest에서 빠졌으므로 `package_key_allowed`의 조회로는 잡히지 않고, 그대로 두면 uninstall preflight가 **전체를 중단**시킨다(무관한 항목까지 하나도 정리되지 않는다). 그래서 `uninstall.sh`가 이 두 key를 고정 목록으로 인정한다 — 구 로컬 skill 배포분과 같은 처리다. 제거 여부는 여전히 설치 당시 버전과의 대조가 정하므로, 위 명령으로 이미 지웠거나 사용자가 직접 올린 패키지는 문제가 되지 않는다. Windows는 `winget.txt`에 shellcheck가 있던 적이 없어 해당 없다.

**손으로 둔 `~/.local/bin/shellcheck`는 install을 매 실행 실패시킨다.** receipt에 없는 파일이 그 자리에 있으면 `install_managed_file … skip`이 보존을 택하고 `install_shellcheck`가 그것을 실패로 기록한다 — 남의 파일을 덮지 않기 때문이다(Safe-Clean-Install). 다른 direct artifact는 `new` 상태에서 `command -v <name>`으로 기존 설치본에 양보하지만 shellcheck는 그럴 수 없다. 양보하면 `/usr/bin/shellcheck` 0.9.0이 pin을 이겨 이 절의 목적이 사라진다. 그래서 그 상태를 실패 메시지가 직접 구분해 대응 방법까지 적는다(`… exists but is not managed by dotfiles. Remove it and re-run`). rhwp의 unowned tree 충돌도 같은 모양이며, 안내는 `docs/tools.md`에 있다.

버전을 올릴 때는 다섯 행을 함께 올린다. 이미 설치된 머신은 **세 OS 모두** `DOTFILES_UPGRADE_DIRECT=1`을 요구한다 — 다른 direct artifact와 같은 규칙이며, lint 규칙 집합이 조용히 바뀌지 않게 하려는 것이다. 근거는 receipt에 기록한 `directVersion`이다. Unix는 `direct_anchor_state`가, Windows는 같은 계약을 파일 단위로 옮긴 `Get-DirectFileState`가 판정하며, 둘 다 manifest 버전과 다르면 플래그 없이는 `upgrade-blocked`로 멈춘다(설치 실패로 기록되고 바이너리는 그대로 둔다).

이 게이트는 `tests/ownership/direct-artifacts.{sh,ps1}`가 단언한다. CI의 실제 install 잡은 매번 새 HOME에서 도는 탓에 `new` → `current` 전이만 지나므로, `upgrade` / `upgrade-blocked` / `modified`를 지나는 검사는 이 두 스크립트뿐이다. `pr-gate.yml`의 **세 install 잡 모두**가 돌린다 — bash 쪽은 `file_mode`/`tree_hash`의 BSD 경로(`stat -f`, `find -printf` 없음)를 지나므로 macOS에서 돌지 않으면 그쪽 회귀를 잡는 검사가 없다.

```bash
bash tests/ownership/direct-artifacts.sh
pwsh -NoProfile -File tests/ownership/direct-artifacts.ps1
```

manifest validator는 두 벌(awk / PowerShell)이라 판정이 어긋날 수 있다. awk 정규식은 대소문자를 가리고 PowerShell의 `-in`/`-match`/`-eq`는 기본이 그렇지 않으므로, `Test-ShellCheckManifestRows`는 비교를 전부 `-c*`로 쓴다. 그러지 않으면 `Windows-x86_64` 같은 행이 PowerShell validator만 통과하고, 뒤의 case-sensitive 행 선택이 `$null`을 집어 terminating error로 install 전체를 끊는다. 같은 이유로 archive 안 바이너리의 `--version` 호출도 `try/catch`로 감싼다 — `$ErrorActionPreference = 'Stop'` 아래에서 실행 자체가 실패하면(`%TEMP%` 실행을 막는 AppLocker/WDAC, 파일을 잡고 있는 AV, x64 에뮬레이션 없는 ARM64) 그 예외가 `Add-InstallFailure` 계약을 우회한다. `tests/install/failure-contract.{sh,ps1}`가 두 경로를 모두 단언한다.

`SKIP_SHELLCHECK=1`로 이 단계 전체를 건너뛸 수 있다. CI는 이 값을 쓰지 않는다 — pin된 artifact라 설치 경로를 그대로 검증한다.

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

### Antigravity CLI 관리

Antigravity CLI(바이너리 이름은 `agy`)는 herdr와 같은 예외다. **바이너리는 소유하지 않고 설정만 소유한다.** 설정(`config/agy/` → `~/.gemini/`)은 예전부터 이 저장소가 배포해 왔고, 이번에 CLI 자체의 설치가 붙었다.

| 대상 | 소유자 | 경로 |
|---|---|---|
| 바이너리 (Windows) | 공식 installer (`https://antigravity.google/cli/install.ps1`) | `%LOCALAPPDATA%\agy\bin\agy.exe` |
| 바이너리 (Linux/macOS) | 공식 installer (`https://antigravity.google/cli/install.sh`) | `~/.local/bin/agy` |
| 설정 | **이 저장소** (receipt-managed) | `~/.gemini/`, `~/.gemini/config/` |

pin하지 않는 이유가 둘이다.

1. **CLI가 스스로 업데이트한다.** 공식 installer가 그렇게 밝힌다 — "The Antigravity CLI automatically self-updates in the background during regular runs". receipt로 바이너리 해시를 잡으면 첫 실행 직후 어긋나 그 다음 실행부터 "changed; preserving"으로 굳는다. herdr와 똑같은 구조의 문제다.
2. **pin할 대상이 없다.** 배포가 버전 없는 auto-updater manifest 엔드포인트(`/manifests/<platform>.json`)를 거쳐 항상 최신을 해석하고, `google-antigravity/antigravity-cli` 릴리즈는 2~3일에 하나씩 나온다. 그 속도로 SHA-256을 옮기는 것은 `manifests/*.tsv`가 지키려는 "검토한 바이너리만 들어온다"와 실질이 다르다.

winget에 `Google.AntigravityCLI`가 있지만 쓰지 않는다. Google이 올린 것이 아니라 봇(`YamlCreate.ps1 Dumplings Mod`)이 만든 커뮤니티 manifest이고, `portable` 타입이라 바이너리가 다른 두 OS와 또 다른 자리(`%LOCALAPPDATA%\Microsoft\WinGet\Packages`·`Links`)에 놓인다. 무엇보다 위 1번 때문에 winget이 기록한 버전은 첫 실행 직후 낡는다 — 소유권을 주장하지만 실제로는 추적하지 못하는 상태가 되는데, 그것이 이 저장소가 피하려는 바로 그 상태다.

그래서 install은 `agy`가 이미 있으면 **아무것도 하지 않는다**. 없을 때만 공식 installer를 한 번 돌려 부트스트랩한다. installer 자체도 같은 판단을 해서, 대상 경로에 바이너리가 있으면 안내만 출력하고 `exit 0`으로 끝난다.

부트스트랩 실패는 경고로 끝난다 — `record_install_failure`/`Add-InstallFailure`를 타지 않는다. herdr와 같은 이유이며, 소유하지 않기로 한 서드파티 CDN의 일시적 장애가 dotfiles 설치 전체를 실패로 만들지 않는다.

순서는 3-2에 둔다. 뒤따르는 3-3(rhwp)은 `~/.gemini`가 있거나 `agy`가 PATH에 있을 때 Gemini MCP를 등록한다. 3-2의 설정 배포가 그 디렉터리를 먼저 만들므로 `SKIP_AGY`를 걸지 않은 실행에서는 디렉터리 조건이 먼저 성립하고, `agy` 조회는 그때 판정에 관여하지 않는다. CLI를 앞에 두는 것이 실제로 값을 하는 경우는 `SKIP_AGY=1`로 설정 배포를 건너뛰어 디렉터리가 없는 실행이다 — 그때도 MCP 등록이 이뤄진다. 뒤집어 말하면 `SKIP_AGY_CLI=1`만으로는 Gemini MCP 등록이 꺼지지 않는다(CI가 세 OS 모두 그 상태로 돌고 등록은 그대로 이뤄진다).

Unix 쪽은 `sh`가 아니라 **`bash`로 파이프한다**. installer가 `set -euo pipefail`을 쓰는데 우분투의 `/bin/sh`(dash)에는 `pipefail`이 없어 첫 줄에서 죽는다. Windows 쪽은 herdr와 같이 자식 프로세스(`pwsh -NoProfile -NonInteractive -File <임시파일>`)로 격리한다 — 이 installer도 sourcing이 아닐 때 최상위에서 `exit $exitCode`를 호출하므로, 같은 프로세스에서 돌리면 그 `exit`가 `try/catch`를 무시하고 install 전체를 끝낸다.

#### 공식 installer가 만드는 side effect

소유하지 않기로 한 대가이므로 uninstall이 되돌리지 않는다. 지우려면 직접 정리한다.

| 플랫폼 | side effect |
|---|---|
| Windows | `%LOCALAPPDATA%\agy\bin\agy.exe` 실행 파일 |
| Windows | `%LOCALAPPDATA%\antigravity\staging` (installer가 성공·실패와 무관하게 정리하지만 디렉터리는 남는다) |
| Linux/macOS | `~/.local/bin/agy` 실행 파일 하나 |
| Linux/macOS | `~/.cache/antigravity/staging` (installer의 `trap`이 내용물을 지운다) |
| 공통 | installer 마지막 단계가 `agy install`을 호출해 셸 환경을 설정한다. 이 저장소는 그 동작을 소유하지 않으며 정확한 범위를 검증하지 않았다. |
| 공통 | `agy` 첫 실행 시 Google Sign-In이 필요하다. 설치 자체는 비대화형이고, 인증은 사용자가 처음 쓸 때 일어난다. |

`~/.local/bin/agy`가 이 저장소의 direct artifact들과 같은 디렉터리에 놓이지만 uninstall의 소유권 목록에는 없다. 그 이름은 `artifact_allowed`/`Test-ArtifactAllowed`가 거부하며, `tests/uninstall/`이 그 거부를 단언한다.

`SKIP_AGY_CLI=1`로 이 단계를 건너뛸 수 있다. 설정 배포를 끄는 `SKIP_AGY`와 별개다 — 소유자가 다르기 때문이다. CI는 세 OS 모두 `SKIP_AGY_CLI=1`을 쓴다(pin되지 않은 원격 installer라 실행하지 않는다).

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

frontmatter 검증 engine은 `scripts/agent_validator.py`다. 단일 Claude agent 파일 하나는 같은 engine을 쓰는 `subagent-creator` skill의 wrapper로 검사한다(skill은 `npx skills`가 설치한다).

```bash
uv run --with pyyaml --python 3.11 ~/.claude/skills/subagent-creator/scripts/validate_subagent.py <agent.md>
```

> `scripts/agent_validator.py`는 `PubCyBerry/subagent-creator`의 `skills/subagent-creator/scripts/agent_validator.py`와 **동기화 대상**이다. 한쪽을 고치면 다른 쪽도 고친다. skill 사본을 없애지 못하는 이유는 CI(`test-agent-roles`)가 skill 설치 없이 돌아야 해서 저장소 안에 engine이 있어야 하기 때문이다. 이 저장소는 engine만 소유한다 — `validate_subagent.py` wrapper와 그 테스트는 upstream 저장소에 있다.

### temporal context hook 관리

세 에이전트 호스트 모두에 현재 시각을 주입하는 훅을 배포한다. 본문은 `date` 한 줄과 JSON 출력이 전부이고, 차이는 **언제 발동하느냐**와 **어떤 wire 형식으로 뱉느냐**뿐이다.

| 호스트 | registry | event | 산출 |
|---|---|---|---|
| Claude Code | `config/claude/settings.json` → `.hooks` | `UserPromptSubmit` | `hookSpecificOutput.additionalContext` |
| Codex | `config/codex/hooks.json` → `.hooks` | `UserPromptSubmit` | `hookSpecificOutput.additionalContext` |
| Antigravity | `config/agy/hooks.json` | `PreInvocation` | `injectSteps[].ephemeralMessage` |

**`SessionStart`가 아니라 `UserPromptSubmit`인 이유.** SessionStart는 세션당 한 번만 돈다. 주입된 시각이 그 순간에 얼어붙어 긴 세션에서는 몇 시간 밀린 값을 사실처럼 들고 있게 된다 — 시각을 주입하는 훅으로서는 목적이 사라지는 실패 모드다. `UserPromptSubmit`은 턴마다 발동하므로 매 요청이 그 시점의 시각을 본다. Antigravity의 `PreInvocation`은 처음부터 턴 단위였고, 이제 세 호스트가 같은 시점 계약을 쓴다.

Claude Code와 Codex는 출력 계약이 같아 스크립트가 사실상 동일하다. Codex 0.147.0 바이너리의 `UserPromptSubmitHookSpecificOutputWire`가 `hookEventName`(필수) + `additionalContext`(선택)로 Claude Code와 같은 모양이다. **스크립트가 뱉는 `hookEventName`과 registry가 등록한 event key는 반드시 같아야 한다** — 어긋나면 host가 출력을 조용히 버리고, 훅은 도는데 아무것도 주입되지 않는 상태가 된다. `tests/claude/runtime-contract.sh`가 두 값을 직접 대조하는 이유다.

타임존은 `%Z`가 아니라 **`%z`(숫자 오프셋)** 를 쓴다. Git Bash(MSYS)에서 한국어 타임존 이름이 깨져 `%Z`가 빈 문자열이 되고, 결과적으로 타임존 정보가 통째로 사라진다.

#### 마이그레이션: event를 옮기면 옛 자리의 사본을 걷어내야 한다

registry는 merge 방식이라 사용자 hook을 보존하는데, 그 대가로 `scripts/merge-json-registry.jq`의 `merge_hooks`는 **managed 쪽에 있는 event key만** 훑는다. 그래서 관리 hook을 다른 event로 옮기면 기존 설치의 옛 event에 남은 사본이 영원히 방치되고, 다음 install부터 옛 자리와 새 자리가 **함께** 발동한다.

`purge_relocated_hooks`가 이를 처리한다. managed 문서에 등장하는 hook의 identity(`["command", <command>]`)를 모아, managed에 **없는** event key에서 같은 identity를 제거하고, 비게 된 matcher group과 event key를 지운다. 하드코딩한 명령 문자열이 없으므로 앞으로 다른 hook을 옮길 때도 그대로 동작한다. 사용자 hook은 identity가 다르므로 남는다.

#### 훅 스크립트는 `takeover`로 배포한다

`~/.claude/hooks/temporal-context.sh` 같은 경로는 이 저장소가 이름으로 소유한다. `skip`이면 receipt에 그 항목이 없는 순간(다른 도구가 디렉터리를 만들었거나 receipt가 초기화된 경우) 구버전 사본이 "사용자 파일"로 판정돼 영구히 보존되고, registry만 갱신되어 **훅이 조용히 낡는다**. 실제로 그 상태가 발생해 `hookEventName`이 맞지 않는 옛 스크립트가 남아 있었다. `takeover`는 덮어쓰기 전에 `.dotfiles-backup`을 남기므로 Safe-Clean-Install 기준을 지키면서 이 실패 모드를 없앤다.

검증은 네트워크 없이 돌아간다.

```bash
bash tests/claude/runtime-contract.sh
bash tests/install/config-merge.sh
pwsh -NoProfile -File tests/install/config-merge.ps1
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
