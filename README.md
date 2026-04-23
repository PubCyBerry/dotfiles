# dotfiles

Windows 11 환경을 위한 개인 dotfiles.
터미널 설정, CLI 도구, Claude Code 에이전트 설정을 관리한다.

## 목차


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
    windows/
      profile.ps1                  # PowerShell $PROFILE 설정 (fnm, zoxide, starship 등)
      tmux.conf                    # tmux 설정
    starship.toml                  # Starship 프롬프트 설정
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
