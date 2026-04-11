# dotfiles

Windows 11 + macOS 환경을 위한 개인 dotfiles.
bash 설정, CLI 도구, Claude Code 에이전트 설정을 관리한다.

## 목차

- [지원 환경](#지원-환경)
- [새 머신 셋업](#새-머신-셋업)
- [기존 머신 업데이트](#기존-머신-업데이트)
- [git 설정](#git-설정)
- [파일 구조](#파일-구조)
- [도구 사용법](docs/tools.md)
- [AI 에이전트 설정](docs/ai-agents.md)
- [클린 언인스톨](docs/uninstall.md)
- [References](docs/references.md)

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (PowerShell 7+) | 완전 지원 (주 환경) |
| macOS | 완전 지원 |
| Ubuntu 22.04 | 완전 지원 |

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

**windows\install.ps1:**
1. winget 패키지 설치 (Git, fnm, bat, fzf, eza, fd, delta, rg, bun, jq 등)
2. Node.js LTS 설치 (fnm)
3. npm 전역 패키지 설치 (gemini-cli, codex, opencode 등)
4. Claude Code 네이티브 설치
5. RTK 바이너리 설치
6. ast-grep, difftastic 바이너리 설치

**windows\agents-setup.ps1:**
7. Claude Code 설정 복사 (`settings.json`, `CLAUDE.md`)
8. `.tmux.conf` 복사 (pwsh 기본 셸)
9. RTK hook 생성
10. PowerShell 프로파일 설정 (PS 5.1 + PS 7+ 양쪽)
11. npx skills 복원

</details>

> **설정 업데이트**: dotfiles 변경 사항 적용 시 `install.ps1`을 다시 실행.

### macOS / Linux

```bash
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
cd ~/dotfiles && bash install.sh
cp ~/dotfiles/bash/.gitconfig.local.example ~/.gitconfig.local
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
# macOS / Linux
cd ~/dotfiles && git pull
bash macos/install.sh   # macOS
bash linux/packages.sh  # Linux
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

**머신별 설정:** `~/.gitconfig.local`에 user.name/email을 설정한다. `.gitconfig.local.example`을 복사해 수정.

## 파일 구조

```
dotfiles/
  install.ps1                 # Windows 진입점 (단일 명령으로 전체 설치)
  install.sh                  # macOS/Linux 진입점
  bash/
    .bashrc                   # 셸 초기화 (starship/zoxide/fzf/atuin init)
    .bash_profile             # 로그인 셸
    .aliases                  # 명령어 단축키 (eza, bat, git, ccd 등)
    .exports                  # 환경변수 (PATH, EDITOR, HISTSIZE 등)
    .functions                # 유틸리티 함수 (mkcd, up, extract)
    .inputrc                  # Readline 설정
    .gitconfig                # git 전역 설정 (공유)
    .gitconfig.local.example  # 머신별 설정 템플릿
    .extra.example            # 머신별 개인 설정 템플릿 (git 제외)
    .gitignore_global         # 전역 gitignore
  config/
    starship.toml             # Starship 프롬프트 설정 → ~/.config/
  tools/
    fnm.sh                    # fnm 설치
    node.sh                   # Node LTS + Claude Code 설치
    bun.sh                    # bun 설치 (OS별 분기)
    global-packages.sh        # npm 전역 패키지 설치
    global-packages.txt       # 전역 패키지 목록
    rtk.sh                    # RTK 설치 및 hook 등록
  linux/
    packages.sh               # apt 패키지 (카카오 미러)
    install-extras.sh         # apt 미지원 도구 바이너리 설치
  macos/
    install.sh                # Homebrew + Brewfile
    Brewfile                  # macOS 패키지 목록
    .macos                    # macOS 시스템 설정 자동화
  windows/
    install.ps1               # winget 패키지 + npm 전역 패키지 + RTK 바이너리
    agents-setup.ps1          # Claude Code 설정 복사 + $PROFILE 관리 + skills 복원
    profile.ps1               # PowerShell $PROFILE 설정 (fnm, zoxide, starship 등)
    .tmux.conf                # tmux 설정 (pwsh 기본 셸)
  agents/
    setup.sh                  # Claude 설정 링크 + 에이전트 설치
    restore-skills.sh         # npx skills 재설치
    skills-manifest.txt       # 설치할 skills 목록
    claude/
      CLAUDE.md               # Claude 전역 행동 설정
      settings.json           # Claude Code 설정 (플러그인, hook, statusLine)
  docs/
    tools.md                  # CLI 도구 사용법 cheatsheet
    ai-agents.md              # Claude Code, 플러그인, skills 상세
    uninstall.md              # 클린 언인스톨 가이드
```
