# dotfiles

Windows 11 / macOS / Ubuntu 환경을 위한 개인 dotfiles.
터미널 설정, CLI 도구, AI 에이전트(Claude Code, Codex, Antigravity) 설정을 관리한다.
구조와 동작 방식은 [AGENTS.md](AGENTS.md)에 있다.

## 목차 <!-- omit from toc -->

- [지원 환경](#지원-환경)
- [Quickstart](#quickstart)
- [References](#references)

## 지원 환경

| 환경 | 패키지 | 셸 |
|------|--------|----|
| Windows 11 (주 환경) | winget | PowerShell 7, Git Bash |
| macOS | Homebrew (Windows와 같은 도구 구성) | zsh |
| Ubuntu 22.04+ | apt + GitHub 릴리스 | bash |

## Quickstart

### Windows 11

```powershell
# 1. PowerShell 7 설치
winget install --id Microsoft.PowerShell --exact

# 2. 저장소 클론 후 실행 (pwsh, 관리자 권한이면 설치 중 UAC 창이 뜨지 않는다)
git clone https://github.com/PubCyBerry/dotfiles.git $env:USERPROFILE\dotfiles
pwsh -ExecutionPolicy Bypass -File $env:USERPROFILE\dotfiles\install.ps1

# 3. git 사용자 정보 설정 (최초 1회)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"
```

### macOS / Ubuntu

macOS는 [Homebrew](https://brew.sh)가 먼저 설치되어 있어야 한다. Ubuntu는 sudo 권한이 필요하다.

```bash
# 1. 저장소 클론 후 실행
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh

# 2. git 사용자 정보 설정 (최초 1회)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# 3. (macOS, 선택) 시스템 기본값 적용. Finder·Dock이 재시작된다
bash ~/dotfiles/config/macos/.macos
```

### 업데이트

같은 스크립트를 다시 실행한다. 패키지를 최신으로 올리고 설정을 다시 배포한다.
#10(2026-11) 이전 버전으로 설치한 머신은 먼저 에이전트에게 [docs/legacy-cleanup.md](docs/legacy-cleanup.md)를 실행시켜 예전 설치 잔재를 정리한다.

```bash
cd ~/dotfiles && git pull
bash install.sh                                      # macOS / Ubuntu
pwsh -ExecutionPolicy Bypass -File .\install.ps1     # Windows
```

## References

이 dotfiles를 구성하는 데 참고하거나 참고할 자료 목록.

### Dotfiles

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) | dotfiles 구성 참고 | <img src="https://img.shields.io/github/stars/mathiasbynens/dotfiles?style=flat&label=%E2%AD%90" alt="stars"> |
| [gpakosz/.tmux](https://github.com/gpakosz/.tmux) | tmux 설정 레퍼런스 | <img src="https://img.shields.io/github/stars/gpakosz/.tmux?style=flat&label=%E2%AD%90" alt="stars"> |
| [citypaul/.dotfiles](https://github.com/citypaul/.dotfiles) | dotfiles 구성 참고 | <img src="https://img.shields.io/github/stars/citypaul/.dotfiles?style=flat&label=%E2%AD%90" alt="stars"> |
| [SeniorMars/dotfiles](https://github.com/SeniorMars/dotfiles) | Neovim 중심 rice 설정 dotfiles | <img src="https://img.shields.io/github/stars/SeniorMars/dotfiles?style=flat&label=%E2%AD%90" alt="stars"> |

### Agent

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [openai/codex](https://github.com/openai/codex) | OpenAI Codex CLI | <img src="https://img.shields.io/github/stars/openai/codex?style=flat&label=%E2%AD%90" alt="stars"> |
| [anthropics/claude-code](https://github.com/anthropics/claude-code) | Anthropic Claude Code CLI | <img src="https://img.shields.io/github/stars/anthropics/claude-code?style=flat&label=%E2%AD%90" alt="stars"> |
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
| [anthropics/skills](https://github.com/anthropics/skills) | Anthropic 공식 Agent Skills 저장소 | <img src="https://img.shields.io/github/stars/anthropics/skills?style=flat&label=%E2%AD%90" alt="stars"> |
| [openai/skills](https://github.com/openai/skills) | OpenAI Codex Skills 카탈로그 | <img src="https://img.shields.io/github/stars/openai/skills?style=flat&label=%E2%AD%90" alt="stars"> |
| [multica-ai/andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) | Karpathy의 LLM 코딩 인사이트 기반 CLAUDE.md | <img src="https://img.shields.io/github/stars/multica-ai/andrej-karpathy-skills?style=flat&label=%E2%AD%90" alt="stars"> |
| [mattpocock/skills](https://github.com/mattpocock/skills) | 실무 엔지니어용 Claude Code Skills | <img src="https://img.shields.io/github/stars/mattpocock/skills?style=flat&label=%E2%AD%90" alt="stars"> |
| [nexu-io/open-design](https://github.com/nexu-io/open-design) | 19개 Skills·71개 디자인 시스템을 포함한 로컬 오픈소스 AI 디자인 도구 | <img src="https://img.shields.io/github/stars/nexu-io/open-design?style=flat&label=%E2%AD%90" alt="stars"> |
| [NomaDamas/k-skill](https://github.com/NomaDamas/k-skill) | 한국형 서비스 전용 Skills 모음 (SRT, KTX, 카카오톡, 주식 등) | <img src="https://img.shields.io/github/stars/NomaDamas/k-skill?style=flat&label=%E2%AD%90" alt="stars"> |
| [chojondocho/vowline](https://github.com/chojondocho/vowline) | 에이전트 작업 범위·근거·검증 기준을 고정하는 휴대용 운영 규약 skill | <img src="https://img.shields.io/github/stars/chojondocho/vowline?style=flat&label=%E2%AD%90" alt="stars"> |

### Tools

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [ccusage/ccusage](https://github.com/ccusage/ccusage) | 코딩 에이전트 CLI 토큰 사용량·비용 리포트 + Claude Code statusline | <img src="https://img.shields.io/github/stars/ccusage/ccusage?style=flat&label=%E2%AD%90" alt="stars"> |
| [sirmalloc/ccstatusline](https://github.com/sirmalloc/ccstatusline) | Claude Code 상태줄 표시 도구 | <img src="https://img.shields.io/github/stars/sirmalloc/ccstatusline?style=flat&label=%E2%AD%90" alt="stars"> |

### Vim

| 저장소 | 설명 | Stars |
|--------|------|-------|
| [neovim/neovim](https://github.com/neovim/neovim) | Neovim 텍스트 에디터 | <img src="https://img.shields.io/github/stars/neovim/neovim?style=flat&label=%E2%AD%90" alt="stars"> |
| [folke/lazy.nvim](https://github.com/folke/lazy.nvim) | Neovim 플러그인 매니저 | <img src="https://img.shields.io/github/stars/folke/lazy.nvim?style=flat&label=%E2%AD%90" alt="stars"> |

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
| [sharkdp/bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | <img src="https://img.shields.io/github/stars/sharkdp/bat?style=flat&label=%E2%AD%90" alt="stars"> |
| [junegunn/fzf](https://github.com/junegunn/fzf) | command-line fuzzy finder | <img src="https://img.shields.io/github/stars/junegunn/fzf?style=flat&label=%E2%AD%90" alt="stars"> |
| [eza-community/eza](https://github.com/eza-community/eza) | alternative to `ls` | <img src="https://img.shields.io/github/stars/eza-community/eza?style=flat&label=%E2%AD%90" alt="stars"> |
| [sharkdp/fd](https://github.com/sharkdp/fd) | alternative to `find` | <img src="https://img.shields.io/github/stars/sharkdp/fd?style=flat&label=%E2%AD%90" alt="stars"> |
| [dandavison/delta](https://github.com/dandavison/delta) | syntax-highlighting pager for git | <img src="https://img.shields.io/github/stars/dandavison/delta?style=flat&label=%E2%AD%90" alt="stars"> |
| [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | recursively search with regex | <img src="https://img.shields.io/github/stars/BurntSushi/ripgrep?style=flat&label=%E2%AD%90" alt="stars"> |
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
