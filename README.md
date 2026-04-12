# dotfiles

Windows 11 + Linux 환경을 위한 개인 dotfiles.
bash 설정, CLI 도구, Claude Code 에이전트 설정을 관리한다.

## 목차

- [dotfiles](#dotfiles)
  - [목차](#목차)
  - [지원 환경](#지원-환경)
  - [새 머신 셋업](#새-머신-셋업)
    - [Windows 11](#windows-11)
    - [Linux](#linux)
  - [기존 머신 업데이트](#기존-머신-업데이트)
  - [git 설정](#git-설정)
  - [파일 구조](#파일-구조)
  - [References](#references)
    - [Dotfiles](#dotfiles-1)
    - [Harness](#harness)
    - [Skills](#skills)
    - [Tools](#tools)

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (PowerShell 7+) | 완전 지원 (주 환경) |
| Ubuntu 22.04 | 완전 지원 |
| macOS | 보류 (`macos/` 디렉토리에 코드 보관) |

## 새 머신 셋업

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

<details>
<summary><code>install.ps1</code> 실행 순서</summary>

1. `manifests/winget.txt` → winget 패키지 설치 (Git, fnm, bat, fzf, eza, fd, delta, rg, bun, jq 등)
2. Node.js LTS 설치 (fnm)
3. `manifests/npm-global.txt` → npm 전역 패키지 설치
4. Claude Code 네이티브 설치
5. RTK 바이너리 설치 + rtk-wrapper
6. ast-grep, difftastic 바이너리 설치
7. `config/claude/` → `~/.claude/` 복사 (`settings.json`, `CLAUDE.md`)
8. RTK hook 생성 (`~/.claude/hooks/rtk-rewrite.sh`)
9. PowerShell 프로파일 설정 (PS 7+, `config/windows/profile.ps1`)
10. `config/windows/tmux.conf` → `~/.tmux.conf` 복사
11. `manifests/skills.txt` → npx skills 복원

</details>

> **설정 업데이트**: dotfiles 변경 사항 적용 시 `install.ps1`을 다시 실행.

### Linux

```bash
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh
cp ~/dotfiles/config/bash/.gitconfig.local.example ~/.gitconfig.local
# ~/.gitconfig.local 열어서 name/email 수정
exec bash
```

## 기존 머신 업데이트

```powershell
# Windows
cd $env:USERPROFILE\dotfiles && git pull
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

```bash
# Linux
cd ~/dotfiles && git pull
bash install.sh
```

## git 설정

**전역 alias:**

| alias | 원래 명령 |
|-------|-----------|
| `git st` | `git status -sb` |
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git lg` | `git log --oneline --graph --decorate --all` |
| `git last` | `git log -1 HEAD` |
| `git undo` | `git reset --soft HEAD~1` |

**머신별 설정:** `~/.gitconfig.local`에 user.name/email을 설정한다. `config/bash/.gitconfig.local.example`을 복사해 수정.

## 파일 구조

```
dotfiles/
  install.ps1                      # Windows 설치 (all-in-one)
  install.sh                       # Linux 설치 (all-in-one)
  config/
    bash/
      .bashrc                      # 셸 초기화 (starship/zoxide/fzf/atuin init)
      .bash_profile                # 로그인 셸
      .aliases                     # 명령어 단축키 (eza, bat, git, ccd 등)
      .exports                     # 환경변수 (PATH, EDITOR, HISTSIZE 등)
      .functions                   # 유틸리티 함수 (mkcd, up, extract)
      .inputrc                     # Readline 설정
      .gitconfig                   # git 전역 설정 (공유)
      .gitconfig.local.example     # 머신별 설정 템플릿
      .extra.example               # 머신별 개인 설정 템플릿 (git 제외)
      .gitignore_global            # 전역 gitignore
      .tmux.conf                   # tmux 설정 (Linux용)
    claude/
      CLAUDE.md                    # Claude 전역 행동 설정
      settings.json                # Claude Code 설정 (hook, env, permissions)
    windows/
      profile.ps1                  # PowerShell $PROFILE 설정 (fnm, zoxide, starship 등)
      tmux.conf                    # tmux 설정 (pwsh 기본 셸)
    starship.toml                  # Starship 프롬프트 설정 → ~/.config/
  manifests/
    winget.txt                     # Windows winget 패키지 목록
    apt.txt                        # Linux apt 패키지 목록
    npm-global.txt                 # npm 전역 패키지 목록
    skills.txt                     # Claude Code skills 목록
  macos/                           # macOS 지원 (보류)
  docs/
    tools.md                       # CLI 도구 사용법 cheatsheet
    ai-agents.md                   # Claude Code, 플러그인, skills 상세
    uninstall.md                   # 클린 언인스톨 가이드
```

## References

이 dotfiles를 구성하는 데 참고하거나 참고할 자료 목록.

### Dotfiles

| 저장소 | 설명 |
|--------|------|
| [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles) | dotfiles 구성 참고 |

### Harness

| 저장소 | 설명 |
|--------|------|
| [yeachan-heo/oh-my-claudecode](https://github.com/yeachan-heo/oh-my-claudecode) | Harness 구성 참고 |
| [code-yeongyu/oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) | Harness 구성 참고 |
| [obra/superpowers](https://github.com/obra/superpowers) | Harness 구성 참고 |

### Skills

| 저장소 | 설명 |
|--------|------|
| [vercel-labs/skills](https://github.com/vercel-labs/skills) | Skills 프레임워크 |
| [msitarzewski/agency-agents](https://github.com/msitarzewski/agency-agents) | 에이전트 모음 |
| [pbakaus/impeccable](https://github.com/pbakaus/impeccable) | 디자인 관련 스킬 |

### Tools

| 저장소 | 설명 |
|--------|------|
| [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud) | Claude HUD statusline |
| [rtk-ai/rtk](https://github.com/rtk-ai/rtk) | RTK 토큰 최적화 도구 |
