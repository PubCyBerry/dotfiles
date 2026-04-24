# dotfiles

Windows 11 환경을 위한 개인 dotfiles.
터미널 설정, CLI 도구, Claude Code 에이전트 설정을 관리한다.

## 목차

- [dotfiles](#dotfiles)
  - [목차](#목차)
  - [지원 환경](#지원-환경)
  - [Quickstart](#quickstart)
    - [Windows 11](#windows-11)
  - [파일 구조](#파일-구조)
  - [References](#references)

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (PowerShell 7+) | 완전 지원 (주 환경) |
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

## 파일 구조

```text
dotfiles/
  install.ps1                      # 설치 스크립트(Windows 11)
  config/
    claude/
      claude-hud.json              # claude-hud 설정
      CLAUDE.md                    # Claude 전역 지침 설정
      settings.json                # Claude Code 설정 (hook, env, permissions)
    git/
      gitconfig                    # git 설정 (delta pager 포함)
    windows/
      profile.ps1                  # PowerShell $PROFILE 설정 (fnm, zoxide, starship 등)
      tmux.conf                    # tmux 설정
    bash/
      bashrc                       # Git Bash 설정
      inputrc                      # Git Bash readline 설정
    starship.toml                  # Starship 프롬프트 설정
  manifests/
    winget.txt                     # Windows winget 패키지 목록 (Neovim 포함)
    apt.txt                        # Linux apt 패키지 목록
    npm-global.txt                 # npm 전역 패키지 목록
    skills.txt                     # Claude Code skills 목록
  macos/                           # macOS 지원 (보류)
  docs/
    tools.md                       # CLI 도구 사용법 cheatsheet
    ai-agents.md                   # Claude Code, 플러그인, skills 상세
    claude-hud.md                  # Claude HUD 설정 가이드
    uninstall.md                   # 클린 언인스톨 가이드
```

## References

이 dotfiles를 구성하는 데 참고하거나 참고할 자료 목록.

| 카테고리 | 저장소 | 설명 | Stars |
|----------|--------|------|-------|
| Dotfiles | [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) | dotfiles 구성 참고 | <img src="https://img.shields.io/github/stars/mathiasbynens/dotfiles?style=flat&label=%E2%AD%90" alt="stars"> |
| Harness | [yeachan-heo/oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode) | Harness 구성 참고 | <img src="https://img.shields.io/github/stars/yeachan-heo/oh-my-claudecode?style=flat&label=%E2%AD%90" alt="stars"> |
| Harness | [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | Harness 구성 참고 | <img src="https://img.shields.io/github/stars/code-yeongyu/oh-my-openagent?style=flat&label=%E2%AD%90" alt="stars"> |
| Harness | [obra/superpowers](https://github.com/obra/superpowers) | Harness 구성 참고 | <img src="https://img.shields.io/github/stars/obra/superpowers?style=flat&label=%E2%AD%90" alt="stars"> |
| Skills | [vercel-labs/skills](https://github.com/vercel-labs/skills) | Skills 프레임워크 | <img src="https://img.shields.io/github/stars/vercel-labs/skills?style=flat&label=%E2%AD%90" alt="stars"> |
| Skills | [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) | 에이전트 모음 | <img src="https://img.shields.io/github/stars/msitarzewski/agency-agents?style=flat&label=%E2%AD%90" alt="stars"> |
| Skills | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 디자인 관련 스킬 | <img src="https://img.shields.io/github/stars/pbakaus/impeccable?style=flat&label=%E2%AD%90" alt="stars"> |
| Tools | [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud) | Claude HUD statusline | <img src="https://img.shields.io/github/stars/jarrodwatts/claude-hud?style=flat&label=%E2%AD%90" alt="stars"> |
| Tools | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | RTK 토큰 최적화 도구 | <img src="https://img.shields.io/github/stars/rtk-ai/rtk?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [cli/cli](https://github.com/cli/cli) | GitHub CLI | <img src="https://img.shields.io/github/stars/cli/cli?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [Schniz/fnm](https://github.com/Schniz/fnm) | Node.js 버전관리 | <img src="https://img.shields.io/github/stars/Schniz/fnm?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [oven-sh/bun](https://github.com/oven-sh/bun) | JavaScript runtime & toolkit | <img src="https://img.shields.io/github/stars/oven-sh/bun?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [psmux/psmux](https://github.com/psmux/psmux) | tmux on Windows PowerShell | <img src="https://img.shields.io/github/stars/psmux/psmux?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [sharkdp/bat](https://github.com/sharkdp/bat) | `cat` with syntax highlighting | <img src="https://img.shields.io/github/stars/sharkdp/bat?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [junegunn/fzf](https://github.com/junegunn/fzf) | command-line fuzzy finder | <img src="https://img.shields.io/github/stars/junegunn/fzf?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [eza-community/eza](https://github.com/eza-community/eza) | alternative to `ls` | <img src="https://img.shields.io/github/stars/eza-community/eza?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [sharkdp/fd](https://github.com/sharkdp/fd) | alternative to `find` | <img src="https://img.shields.io/github/stars/sharkdp/fd?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [dandavison/delta](https://github.com/dandavison/delta) | syntax-highlighting pager for git | <img src="https://img.shields.io/github/stars/dandavison/delta?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | recursively search with regex | <img src="https://img.shields.io/github/stars/BurntSushi/ripgrep?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [jqlang/jq](https://github.com/jqlang/jq) | command-line JSON processor | <img src="https://img.shields.io/github/stars/jqlang/jq?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [mikefarah/yq](https://github.com/mikefarah/yq) | command-line YAML/JSON/XML processor | <img src="https://img.shields.io/github/stars/mikefarah/yq?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide) | smarter `cd` command | <img src="https://img.shields.io/github/stars/ajeetdsouza/zoxide?style=flat&label=%E2%AD%90" alt="stars"> |
| CLI Tools | [starship/starship](https://github.com/starship/starship) | customizable prompt for any shell | <img src="https://img.shields.io/github/stars/starship/starship?style=flat&label=%E2%AD%90" alt="stars"> |
