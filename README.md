# dotfiles

Windows 11, macOS, Ubuntu에서 같은 터미널 환경과 AI 코딩 에이전트 환경을 만드는 개인 dotfiles다. 스크립트 하나를 실행하면 CLI 도구와 에이전트를 설치하고 셸, 에디터, git, 에이전트 설정을 배포한다.

## 목차 <!-- omit from toc -->

- [지원 환경](#지원-환경)
- [설치 목록](#설치-목록)
- [Quickstart](#quickstart)
- [더 알아보기](#더-알아보기)

## 지원 환경

| 환경 | 패키지 | 셸 |
|------|--------|----|
| Windows 11 (주 환경) | winget | PowerShell 7, Git Bash |
| macOS | Homebrew (Windows와 같은 도구 구성) | zsh |
| Ubuntu 22.04+ | apt + GitHub 릴리스 | bash |

## 설치 목록

버전은 고정하지 않는다. install을 실행할 때마다 각 도구의 최신 버전을 설치하거나 최신으로 올린다. 정확한 패키지 목록은 [`manifests/`](manifests)에 있다.

### CLI 도구

| 도구 | 용도 |
|------|------|
| git, gh | 버전 관리, GitHub CLI |
| Neovim | 에디터. lazy.nvim 플러그인 매니저 설정 포함 |
| tmux | 터미널 멀티플렉서. Windows에서는 psmux |
| fnm, Node.js LTS | Node.js 버전 관리. install이 LTS를 설치하고 기본 버전으로 정한다 |
| bun | JavaScript 런타임 |
| uv | Python 패키지와 버전 관리 |
| ripgrep, fd, fzf | 텍스트 검색, 파일 찾기, 퍼지 검색 |
| bat, eza, delta | 문법 강조 `cat`, `ls` 대체, git diff pager |
| jq, yq | JSON, YAML, TOML 처리 |
| zoxide, starship | 자주 가는 디렉터리로 이동(`z`), 셸 프롬프트 |
| lazygit | git TUI |
| prek, shellcheck | pre-commit hook 실행기, 셸 스크립트 검사 |
| herdr | 코딩 에이전트용 터미널 멀티플렉서 |

### AI 코딩 에이전트

| 도구 | 설치 방법 |
|------|-----------|
| Claude Code | 공식 installer |
| Antigravity CLI (`agy`) | 공식 installer |
| Codex CLI | npm 전역 패키지 |
| pi coding agent | npm 전역 패키지 |
| ccusage | npm 전역 패키지. 에이전트 토큰 사용량과 비용 리포트 |
| defuddle | npm 전역 패키지. 웹 페이지 본문 추출 |

Claude Code에는 플러그인([`manifests/plugins.txt`](manifests/plugins.txt))과 skill([`manifests/skills.txt`](manifests/skills.txt))도 설치한다.

- 플러그인: Codex 연동(codex), statusline(claude-hud), 한국어 출력 스타일(fluent-korean), YAGNI 모드(ponytail)
- skill: 문서 파일 처리(pdf, docx, pptx, xlsx), skill과 subagent 작성(skill-creator, subagent-creator), 저장소 스캐폴딩(repo-scaffold), herdr 제어(herdr)

### 설정

| 대상 | 내용 |
|------|------|
| 셸 프로파일 | fnm, zoxide, starship, fzf 초기화. `ls`, `ll`, `lt`를 eza로, `cat`을 bat으로 연결한다 |
| git | delta pager, Neovim 편집기, 한글 파일명 그대로 표시, 기본 브랜치 `main`, `zdiff3` 충돌 표시 |
| tmux | 마우스, truecolor, Neovim과 Claude Code에 맞춘 키 입력 설정 |
| Claude Code | 현재 시각 주입 hook, statusline(claude-hud와 ccusage), 한국어 출력 스타일, 커밋 서명 끄기 |
| Codex, Antigravity | 현재 시각 주입 hook |
| herdr, starship | 각 도구의 설정 파일 |

install을 다시 실행할 때 직접 바꾼 설정이 남는지는 파일마다 다르다. git 설정은 아직 값이 없는 키만 넣고, 에이전트 설정 파일(`~/.claude/settings.json` 등)은 기존 값이 이기도록 병합하고, 셸 프로파일은 dotfiles가 넣은 블록만 교체한다. 나머지 설정 파일(Neovim, tmux, starship 등)은 매번 저장소 내용으로 덮어쓴다. 파일별 배포 방식은 [배포 방식](ARCHITECTURE.md#배포-방식)에 있다.

## Quickstart

에이전트에게 설치를 맡기려면 이 저장소의 `INSTALL.md`를 읽고 설치하라고 요청한다. 에이전트가 전제 조건을 확인하고 install을 실행한 뒤, 실패와 남은 할 일을 보고한다. 직접 설치하려면 아래 OS별 명령을 실행한다.

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

PowerShell에서 fzf 키 바인딩(`Ctrl+t`, `Ctrl+r`)을 쓰려면 `Install-Module PSFzf -Scope CurrentUser`로 PSFzf 모듈을 따로 설치한다.

### macOS / Ubuntu

macOS는 [Homebrew](https://brew.sh)가 먼저 설치되어 있어야 한다. Ubuntu는 sudo 권한이 필요하다.

```bash
# 1. 저장소 클론 후 실행
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh

# 2. git 사용자 정보 설정 (최초 1회)
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# 3. (macOS, 선택) 시스템 기본값 적용. Finder와 Dock이 재시작된다
bash ~/dotfiles/config/macos/.macos
```

### 업데이트

같은 스크립트를 다시 실행한다. 패키지를 최신으로 올리고 설정을 다시 배포한다.

```bash
cd ~/dotfiles && git pull
bash install.sh                                      # macOS / Ubuntu
pwsh -ExecutionPolicy Bypass -File .\install.ps1     # Windows
```

#10(2026-11) 이전 버전으로 설치한 머신은 먼저 에이전트에게 [docs/legacy-cleanup.md](docs/legacy-cleanup.md)를 실행시켜 예전 설치 잔재를 정리한다.

## 더 알아보기

- [ARCHITECTURE.md](ARCHITECTURE.md): 저장소 구조, 설치 단계, 설정 배포 방식
- [INSTALL.md](INSTALL.md): 에이전트가 설치를 대신 수행하는 절차
- [AGENTS.md](AGENTS.md): 이 저장소에서 작업하는 에이전트가 읽는 문서 색인
- [SECURITY.md](SECURITY.md): 보안 정책
