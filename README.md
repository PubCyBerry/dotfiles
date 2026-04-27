# dotfiles

Windows 11 / Ubuntu 환경을 위한 개인 dotfiles.
터미널 설정, CLI 도구, Claude Code 에이전트 설정을 관리한다.

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (PowerShell 7+) | 완전 지원 (주 환경) |
| Ubuntu 24.04 | 완전 지원 (apt 기반) |
| macOS | 보류 (`macos/` 디렉토리에 코드 보관) |

## Quickstart

### Windows 11

PowerShell 7+ (pwsh)을 기본 셸로 사용한다.

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
git clone https://github.com/PubCyBerry/dotfiles.git $env:USERPROFILE\dotfiles
pwsh -ExecutionPolicy Bypass -File $env:USERPROFILE\dotfiles\install.ps1

# 3. git 사용자 정보 설정 (최초 1회)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

기존 머신 업데이트:

```powershell
# Windows
cd $env:USERPROFILE\dotfiles && git pull
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

### Ubuntu (24.04)

bash + apt 기반. sudo 권한이 필요하다.

```bash
# 1. 저장소 클론 후 단일 진입점 실행
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh

# 2. git 사용자 정보 설정 (최초 1회)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

기존 머신 업데이트:

```bash
cd ~/dotfiles && git pull
bash install.sh
```

## 파일 구조

```text
dotfiles/
  install.ps1                      # 설치 스크립트 (Windows 11)
  install.sh                       # 설치 스크립트 (Ubuntu)
  config/
    claude/
      claude-hud.json              # claude-hud 설정
      CLAUDE.md                    # Claude 전역 지침 설정
      settings.json                # Claude Code 설정 (hook, env, permissions)
    git/
      gitconfig                    # git 설정 (delta pager 포함, OS-중립)
    windows/
      profile.ps1                  # PowerShell $PROFILE 설정 (fnm, zoxide, starship 등)
      tmux.conf                    # tmux 설정 (default-shell=pwsh)
    linux/
      tmux.conf                    # tmux 설정 (default-shell=bash)
    bash/
      bashrc                       # bash 설정 (Git Bash + Linux 공통)
      inputrc                      # readline 설정
    nvim/
      init.lua                     # Neovim 진입점 (lazy.nvim 로드)
      lua/config/lazy.lua          # lazy.nvim 부트스트랩 및 설정
      lua/plugins/yazi.lua         # yazi.nvim 플러그인 설정
    yazi/
      yazi.toml                    # yazi 설정 (nvim 기본 에디터 설정)
    starship.toml                  # Starship 프롬프트 설정
  manifests/
    winget.txt                     # Windows winget 패키지 목록 (Neovim 포함)
    apt.txt                        # Ubuntu apt 패키지 목록
    npm-global.txt                 # npm 전역 패키지 목록
    skills.txt                     # Claude Code skills 목록
  macos/                           # macOS 지원 (보류)
  docs/
    tools.md                       # CLI 도구 사용법 cheatsheet
    ai-agents.md                   # Claude Code, 플러그인, skills 상세
    claude-hud.md                  # Claude HUD 설정 가이드
    uninstall.md                   # 클린 언인스톨 가이드
    git-commit-convention.md       # Git Commit Convention (Conventional Commits)
    worktree-git-workflows.md      # Worktree 커밋 히스토리 관리 전략
```

## Neovim 키맵

`<leader>` = **Space**

### yazi.nvim

| 키 | 동작 |
|----|------|
| `Space` + `-` | 현재 파일 위치에서 yazi 열기 |
| `Space` + `c` + `w` | nvim 작업 디렉토리에서 yazi 열기 |
| `Ctrl` + `↑` | 마지막 yazi 세션 토글 |

## References

이 dotfiles를 구성하는 데 참고하거나 참고할 자료 목록.

### Dotfiles

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) | dotfiles 구성 참고 | <img src="https://img.shields.io/github/stars/mathiasbynens/dotfiles?style=flat&label=%E2%AD%90" alt="stars"> |
| [gpakosz/.tmux](https://github.com/gpakosz/.tmux) | tmux 설정 레퍼런스 | <img src="https://img.shields.io/github/stars/gpakosz/.tmux?style=flat&label=%E2%AD%90" alt="stars"> |

### Agent

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [openai/codex](https://github.com/openai/codex) | OpenAI Codex CLI | <img src="https://img.shields.io/github/stars/openai/codex?style=flat&label=%E2%AD%90" alt="stars"> |
| [anthropics/claude-code](https://github.com/anthropics/claude-code) | Anthropic Claude Code CLI | <img src="https://img.shields.io/github/stars/anthropics/claude-code?style=flat&label=%E2%AD%90" alt="stars"> |
| [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) | Google Gemini CLI | <img src="https://img.shields.io/github/stars/google-gemini/gemini-cli?style=flat&label=%E2%AD%90" alt="stars"> |
| [nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent) | Nous Research Hermes 에이전트 | <img src="https://img.shields.io/github/stars/nousresearch/hermes-agent?style=flat&label=%E2%AD%90" alt="stars"> |
| [openclaw/openclaw](https://github.com/openclaw/openclaw) | 자율 에이전트 오픈 소스 프로젝트 | <img src="https://img.shields.io/github/stars/openclaw/openclaw?style=flat&label=%E2%AD%90" alt="stars"> |

### Harness

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [yeachan-heo/oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode) | Codex 기반 멀티 에이전트 오케스트레이전 | <img src="https://img.shields.io/github/stars/yeachan-heo/oh-my-claudecode?style=flat&label=%E2%AD%90" alt="stars"> |
| [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | OpenCode 기반 멀티 에이전트 오케스트레이션 | <img src="https://img.shields.io/github/stars/code-yeongyu/oh-my-openagent?style=flat&label=%E2%AD%90" alt="stars"> |
| [obra/superpowers](https://github.com/obra/superpowers) | Harness 구성 참고 | <img src="https://img.shields.io/github/stars/obra/superpowers?style=flat&label=%E2%AD%90" alt="stars"> |
| [Yeachan-Heo/oh-my-codex](https://github.com/Yeachan-Heo/oh-my-codex) | Codex 기반 멀티 에이전트 오케스트레이션 | <img src="https://img.shields.io/github/stars/Yeachan-Heo/oh-my-codex?style=flat&label=%E2%AD%90" alt="stars"> |
| [garrytan/gstack](https://github.com/garrytan/gstack) | CEO·Designer·EM·QA 등 23개 전문가 페르소나 Claude Code Skills | <img src="https://img.shields.io/github/stars/garrytan/gstack?style=flat&label=%E2%AD%90" alt="stars"> |

### Skills

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | Skills 프레임워크 | <img src="https://img.shields.io/github/stars/vercel-labs/skills?style=flat&label=%E2%AD%90" alt="stars"> |
| [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) | 에이전트 모음 | <img src="https://img.shields.io/github/stars/msitarzewski/agency-agents?style=flat&label=%E2%AD%90" alt="stars"> |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 디자인 관련 스킬 | <img src="https://img.shields.io/github/stars/pbakaus/impeccable?style=flat&label=%E2%AD%90" alt="stars"> |
| [safishamsi/graphify](https://github.com/safishamsi/graphify) | 코드·문서를 queryable knowledge graph로 변환하는 AI 어시스턴트 스킬 | <img src="https://img.shields.io/github/stars/safishamsi/graphify?style=flat&label=%E2%AD%90" alt="stars"> |
| [kepano/obsidian-skills](https://github.com/kepano/obsidian-skills) | Obsidian 노트 작성을 위한 Skills 모음 | <img src="https://img.shields.io/github/stars/kepano/obsidian-skills?style=flat&label=%E2%AD%90" alt="stars"> |

### Tools

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud) | Claude HUD statusline | <img src="https://img.shields.io/github/stars/jarrodwatts/claude-hud?style=flat&label=%E2%AD%90" alt="stars"> |
| [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline) | Claude Code 상태줄 표시 도구 | <img src="https://img.shields.io/github/stars/sirmalloc/ccstatusline?style=flat&label=%E2%AD%90" alt="stars"> |
| [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | RTK 토큰 최적화 도구 | <img src="https://img.shields.io/github/stars/rtk-ai/rtk?style=flat&label=%E2%AD%90" alt="stars"> |

### Vim

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [neovim/neovim](https://github.com/neovim/neovim) | Neovim 텍스트 에디터 | <img src="https://img.shields.io/github/stars/neovim/neovim?style=flat&label=%E2%AD%90" alt="stars"> |
| [folke/lazy.nvim](https://github.com/folke/lazy.nvim) | Neovim 플러그인 매니저 | <img src="https://img.shields.io/github/stars/folke/lazy.nvim?style=flat&label=%E2%AD%90" alt="stars"> |
| [mikavilpas/yazi.nvim](https://github.com/mikavilpas/yazi.nvim) | Neovim용 yazi 파일 매니저 플러그인 | <img src="https://img.shields.io/github/stars/mikavilpas/yazi.nvim?style=flat&label=%E2%AD%90" alt="stars"> |

### Tmux

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [tmux-plugins/tpm](https://github.com/tmux-plugins/tpm) | tmux 플러그인 매니저 | <img src="https://img.shields.io/github/stars/tmux-plugins/tpm?style=flat&label=%E2%AD%90" alt="stars"> |
| [tmux-plugins/tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) | tmux 세션 복원 | <img src="https://img.shields.io/github/stars/tmux-plugins/tmux-resurrect?style=flat&label=%E2%AD%90" alt="stars"> |
| [psmux/psmux](https://github.com/psmux/psmux) | tmux on Windows PowerShell | <img src="https://img.shields.io/github/stars/psmux/psmux?style=flat&label=%E2%AD%90" alt="stars"> |
| [manaflow-ai/cmux](https://github.com/manaflow-ai/cmux) | tmux multiplexer wrapper | <img src="https://img.shields.io/github/stars/manaflow-ai/cmux?style=flat&label=%E2%AD%90" alt="stars"> |

### CLI Tools

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [cli/cli](https://github.com/cli/cli) | GitHub CLI | <img src="https://img.shields.io/github/stars/cli/cli?style=flat&label=%E2%AD%90" alt="stars"> |
| [Schniz/fnm](https://github.com/Schniz/fnm) | Node.js 버전관리 | <img src="https://img.shields.io/github/stars/Schniz/fnm?style=flat&label=%E2%AD%90" alt="stars"> |
| [oven-sh/bun](https://github.com/oven-sh/bun) | JavaScript runtime & toolkit | <img src="https://img.shields.io/github/stars/oven-sh/bun?style=flat&label=%E2%AD%90" alt="stars"> |
| [sxyazi/yazi](https://github.com/sxyazi/yazi) | 터미널 파일 매니저 | <img src="https://img.shields.io/github/stars/sxyazi/yazi?style=flat&label=%E2%AD%90" alt="stars"> |
| [sharkdp/bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | <img src="https://img.shields.io/github/stars/sharkdp/bat?style=flat&label=%E2%AD%90" alt="stars"> |
| [junegunn/fzf](https://github.com/junegunn/fzf) | command-line fuzzy finder | <img src="https://img.shields.io/github/stars/junegunn/fzf?style=flat&label=%E2%AD%90" alt="stars"> |
| [eza-community/eza](https://github.com/eza-community/eza) | alternative to `ls` | <img src="https://img.shields.io/github/stars/eza-community/eza?style=flat&label=%E2%AD%90" alt="stars"> |
| [sharkdp/fd](https://github.com/sharkdp/fd) | alternative to `find` | <img src="https://img.shields.io/github/stars/sharkdp/fd?style=flat&label=%E2%AD%90" alt="stars"> |
| [file/file](https://github.com/file/file) | Unix file 명령어 | <img src="https://img.shields.io/github/stars/file/file?style=flat&label=%E2%AD%90" alt="stars"> |
| [dandavison/delta](https://github.com/dandavison/delta) | syntax-highlighting pager for git | <img src="https://img.shields.io/github/stars/dandavison/delta?style=flat&label=%E2%AD%90" alt="stars"> |
| [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | recursively search with regex | <img src="https://img.shields.io/github/stars/BurntSushi/ripgrep?style=flat&label=%E2%AD%90" alt="stars"> |
| [atuinsh/atuin](https://github.com/atuinsh/atuin) | 셸 히스토리 검색 | <img src="https://img.shields.io/github/stars/atuinsh/atuin?style=flat&label=%E2%AD%90" alt="stars"> |
| [httpie/cli](https://github.com/httpie/cli) | HTTP CLI 클라이언트 | <img src="https://img.shields.io/github/stars/httpie/cli?style=flat&label=%E2%AD%90" alt="stars"> |
| [jqlang/jq](https://github.com/jqlang/jq) | command-line JSON processor | <img src="https://img.shields.io/github/stars/jqlang/jq?style=flat&label=%E2%AD%90" alt="stars"> |
| [mikefarah/yq](https://github.com/mikefarah/yq) | command-line YAML/JSON/XML processor | <img src="https://img.shields.io/github/stars/mikefarah/yq?style=flat&label=%E2%AD%90" alt="stars"> |
| [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) | smarter `cd` command | <img src="https://img.shields.io/github/stars/ajeetdsouza/zoxide?style=flat&label=%E2%AD%90" alt="stars"> |
| [jesseduffield/lazygit](https://github.com/jesseduffield/lazygit) | terminal UI for git commands | <img src="https://img.shields.io/github/stars/jesseduffield/lazygit?style=flat&label=%E2%AD%90" alt="stars"> |
| [starship/starship](https://github.com/starship/starship) | customizable prompt for any shell | <img src="https://img.shields.io/github/stars/starship/starship?style=flat&label=%E2%AD%90" alt="stars"> |
| [microsoft/winget-cli](https://github.com/microsoft/winget-cli) | Windows 패키지 매니저 | <img src="https://img.shields.io/github/stars/microsoft/winget-cli?style=flat&label=%E2%AD%90" alt="stars"> |
| [mixedbread-ai/mgrep](https://github.com/mixedbread-ai/mgrep) | 코드·이미지·PDF를 시맨틱 검색하는 CLI | <img src="https://img.shields.io/github/stars/mixedbread-ai/mgrep?style=flat&label=%E2%AD%90" alt="stars"> |
| [sharkdp/hyperfine](https://github.com/sharkdp/hyperfine) | 커맨드라인 벤치마킹 도구 | <img src="https://img.shields.io/github/stars/sharkdp/hyperfine?style=flat&label=%E2%AD%90" alt="stars"> |
| [denisidoro/navi](https://github.com/denisidoro/navi) | 대화형 cheatsheet CLI 도구 | <img src="https://img.shields.io/github/stars/denisidoro/navi?style=flat&label=%E2%AD%90" alt="stars"> |

### Tips

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [ykdojo/claude-code-tips](https://github.com/ykdojo/claude-code-tips#tip-0-customize-your-status-line) | Claude Code 활용 팁 모음 | <img src="https://img.shields.io/github/stars/ykdojo/claude-code-tips?style=flat&label=%E2%AD%90" alt="stars"> |

## Troubleshooting

### SSH 터미널을 powershell 7+ / Git Bash로 설정

관리자 권한으로 powershell 실행 후 다음 명령어를 실행:

```powershell
# Powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
# Git Bash
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\Git\bin\bash.exe" -PropertyType String -Force
```

### SSH 세션에서 fnm / zoxide 오류

WinGet으로 설치한 도구(`fnm`, `zoxide`, `fzf`, `eza`, `bat`)는 `%LOCALAPPDATA%\Microsoft\WinGet\Links\`의 reparse symlink로 노출된다. Windows OpenSSH는 NETWORK logon 토큰으로 셸을 띄우는데, 이 토큰에서 해당 symlink 평가가 거부되어 셸별로 다음 오류가 발생한다.

- **PowerShell 7+**: 프로파일 로딩 시 `ResourceUnavailable`. `profile.ps1`의 `Resolve-ExePath` 헬퍼가 심볼릭 링크를 실제 실행 파일 경로로 해석해 우회.
- **Git Bash**: `bash: .../fnm: Permission denied`. `config/bash/bashrc`가 `$HOME/AppData/Local/Microsoft/WinGet/Packages/<pkg>_Microsoft.Winget.Source_*` 하위의 실제 바이너리 경로를 PATH 앞에 prepend해 symlink 평가 자체를 회피.

별도 조치 불필요. 진단 단서: `whoami /groups`에 `NT AUTHORITY\NETWORK`가 포함되고 `INTERACTIVE`가 빠져 있으면 이 케이스다.

### SSH 비대화형 세션에서 scp/rsync/git 깨짐

`ssh host 'cmd'`, scp, rsync, git over ssh 등 비대화형 세션도 `~/.bashrc`를 source한다. starship/fzf의 `eval` 초기화가 stderr를 출력하면 파일 전송 프로토콜이 깨지거나 git이 비정상 종료된다.

`config/bash/bashrc` 상단의 `case $- in *i*) ;; *) return ;; esac` 가드가 비대화형 셸을 즉시 return시켜 prompt/eval/alias 초기화를 모두 건너뛴다. PATH 설정(`~/.local/bin`, WinGet 우회)은 가드 위에 있어 비대화형에서도 적용된다.

### SSH 세션에서 Starship이 Administrator 표시

Windows OpenSSH 서버는 Administrators 그룹 계정으로 접속 시 UAC 필터를 거치지 않고 **전체 관리자 토큰**으로 셸을 실행한다. 일반 데스크탑 로그인은 제한된 토큰으로 시작하는 것과 달리, SSH 세션은 처음부터 관리자 컨텍스트로 동작한다. Starship의 `username` 모듈이 SSH 세션에서 이를 반영해 표시하는 것이다.

표시를 끄려면 `config/starship.toml`에 추가:

```toml
[username]
show_always = false
```

### SSH 세션에서 GitHub HTTPS 인증 실패

SSH로 접속한 비대화형 세션에서 `git fetch`/`git push` 시 다음 오류가 발생한다.

```
fatal: Unable to persist credentials with the 'wincredman' credential store.
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/...'
```

fatal이 안 떠도 username/password 프롬프트가 떠서 통과 못 하는 경우도 같은 원인이다.

**원인**:

- Git for Windows의 system gitconfig가 `credential.helper = manager`(GCM)를 박아놓고, GCM의 기본 store는 `wincredman`(Windows Credential Manager)이다. 이 store는 **대화형 데스크톱 세션**이 있어야 동작해, SSH 비대화형 세션에서는 fatal로 helper chain이 끊긴다.
- `gh auth setup-git`이 추가하는 URL-specific gh helper도 chain이 끊겨 호출 안 되고, 호출되더라도 `gh`의 keyring 자체가 `wincredman` 기반이라 SSH 세션에서 토큰을 못 읽는다.

**해결**: GitHub는 **SSH 키 인증**으로 전환. GitHub 외 HTTPS 호스트(GitLab 등)는 GCM `credentialStore`를 `dpapi`로 변경해 `wincredman` 의존성을 제거한다.

```bash
# 1. GitHub용 SSH 키 생성 + 등록 (gh 토큰에 admin:public_key scope 필요)
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_$(hostname) -N ""
gh ssh-key add ~/.ssh/id_ed25519_$(hostname).pub --title "$(hostname)"

# 2. ~/.ssh/config에 GitHub 항목 추가
cat >> ~/.ssh/config <<EOF

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_$(hostname)
    IdentitiesOnly yes
EOF

# 3. 기존 HTTPS remote를 SSH로 전환
git remote set-url origin git@github.com:<user>/<repo>.git

# 4. 검증
ssh -T git@github.com   # → "Hi <user>! You've successfully authenticated..."
git fetch
```

GitHub 외 호스트용 `dpapi` 설정은 `config/git/gitconfig`에 반영되어 있다. DPAPI는 사용자 프로필 기반이라 SSH 비대화형 세션에서도 동작한다.
