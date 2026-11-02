# AGENTS.md

Windows 11 · macOS · Ubuntu용 개인 dotfiles. 패키지 목록(`manifests/`)과 설정 파일(`config/`)을 두고, install 스크립트가 패키지 매니저와 공식 installer를 불러 설치한다. 주 환경은 Windows이고, macOS는 Windows와 같은 도구 구성을 유지한다.

## 설치

```powershell
# Windows: PowerShell 7에서 실행한다
winget install --id Microsoft.PowerShell --exact
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

```bash
# macOS(Homebrew 필요) / Ubuntu 22.04+(sudo 필요)
bash install.sh
```

여러 번 실행해도 된다. 실행할 때마다 패키지를 최신으로 올리고 설정 파일을 다시 배포한다. 실패한 단계는 마지막에 모아 보여 주고 종료 코드 1로 끝난다.

## 구조

```text
install.ps1                  Windows
install.sh                   macOS, Linux
manifests/
  winget.txt                 Windows 패키지
  Brewfile                   macOS 패키지 (winget.txt와 같은 도구)
  apt.txt                    Linux 패키지
  github-releases.tsv        Linux에서 apt에 없거나 낡은 도구 (GitHub 최신 릴리스)
  npm-global.txt             npm 전역 패키지
  skills.txt                 npx skills
  plugins.txt                Claude Code 플러그인
config/
  agents/global.md           CLAUDE.md, Codex AGENTS.md, GEMINI.md의 공통 원본
  claude/ codex/ agy/        각 에이전트 설정과 hook
  bash/ zsh/ powershell/     셸 프로파일 (Git Bash·Linux는 bash, macOS는 zsh)
  git/ tmux/ nvim/ herdr/ starship.toml
docs/TROUBLESHOOTING.md      Windows SSH 세션 등 운영 문제
```

## 설치 순서

1. 패키지: Windows는 `winget install`(설치되어 있으면 업그레이드), macOS는 `brew bundle`, Linux는 `apt-get install`과 `github-releases.tsv`
2. git config: `config/git/gitconfig`의 키 중 아직 값이 없는 것만 `--global`에 넣고, OS별 `core.autocrlf`·`core.fileMode`를 설정한다
3. 설정 파일 배포 (아래 "배포 규칙")
4. fnm으로 Node.js LTS를 설치하고 기본값으로 지정한 뒤 `npm-global.txt`를 설치한다. 셸 밖에서 뜬 프로세스도 node를 찾도록 fnm 기본 버전을 Windows는 User PATH, Unix는 `~/.local/bin`에 둔다
5. 공식 installer: Claude Code, Antigravity CLI(`agy`), herdr(macOS는 Brewfile). 이미 있으면 건너뛴다. 셋 다 스스로 업데이트한다
6. 셸 프로파일 마커 블록
7. `skills.txt`(`npx skills add`, 이미 있으면 최신으로 덮어씀), `plugins.txt`(마켓플레이스 추가·갱신 → `claude plugin install` → `claude plugin update`)

## 배포 규칙

| 방식 | 대상 | 동작 |
|---|---|---|
| 덮어쓰기 | hook 스크립트, `statusline.sh`, `claude-hud.json`, `global.md` 사본, `.tmux.conf`, nvim, `starship.toml` | 매번 저장소 파일로 덮어쓴다. 원본은 git에 있으므로 백업하지 않는다 |
| 병합 | `~/.claude/settings.json`, `~/.codex/config.toml`, 각 `hooks.json`, herdr `config.toml` | 앱이 스스로 다시 쓰는 파일이다. 겹치는 키는 기존 값이 이긴다 |
| 마커 블록 | `~/.bashrc`, `~/.inputrc`, `~/.bash_profile`, `~/.zshrc`, PowerShell `$PROFILE` | `# ===== dotfiles-begin/end =====` 사이만 교체한다 |

병합은 기존 값이 이기므로, 이미 그 키가 있는 머신에는 저장소에서 바꾼 값이 들어가지 않는다. 배열도 통째로 기존 값이 이긴다(이미 `UserPromptSubmit` hook이 있는 머신에는 저장소 hook이 추가되지 않는다). 저장소 값을 다시 넣으려면 대상 파일에서 그 키를 지우고 다시 실행한다. Orca 같은 도구가 `settings.json`에 넣는 hook이 지워지지 않는 것도 이 규칙 덕분이다.

uninstall 스크립트와 설치 기록은 두지 않는다. 지울 때는 패키지 매니저와 각 도구의 방법을 쓴다.

## 도구별 메모

- statusline: `settings.json`의 `statusLine`이 `bash ~/.claude/statusline.sh`를 부르고, 이 wrapper가 claude-hud(경로·git·컨텍스트)와 ccusage(비용·소진 속도) 출력을 합친다. claude-hud 경로는 실행할 때 찾으므로 Node나 플러그인이 업데이트돼도 깨지지 않는다. 모델명은 claude-hud에서 끄고, 컨텍스트(🧠)는 ccusage 출력에서 잘라 낸다. claude-hud 설정은 `config/claude/claude-hud.json`(`~/.claude/claude-hud.json`)을 고친다.
- 시각 주입 hook: Claude Code·Codex는 `UserPromptSubmit`, Antigravity는 `PreInvocation`에서 현재 시각을 넣는다. 스크립트가 출력하는 `hookEventName`과 등록한 event 이름이 같아야 한다. 타임존은 `%z`를 쓴다(Git Bash에서 `%Z`가 비어 나온다).
- output style: `outputStyle`은 `fluent-korean` 플러그인의 스타일을 가리킨다. 새 머신에서는 플러그인 단계가 끝날 때까지 기본 스타일로 보인다.
- herdr: Windows는 `default_shell`을 Git Bash로 두고 `prefix+alt+p`로 pwsh pane을 연다. 경로는 forward slash로 쓴다(yq TOML 인코더가 `\b`를 백스페이스로 바꾼다). Windows에서 `shell_mode`는 지정하지 않는다(0.8 preview에서 `login`이면 cmd.exe로 떨어졌다). herdr를 먼저 실행해 `config.toml`이 생긴 뒤라면 병합에서 기존 값이 이기므로, 그 파일을 지우고 다시 실행한다. 설정 TOML에는 주석을 두지 않는다(yq 병합이 주석을 매번 다시 붙인다).
- Windows SSH: WinGet Links 심볼릭 링크와 fnm junction은 SSH(네트워크 로그온) 세션에서 실행이 막힌다. `config/bash/bashrc`와 `config/powershell/profile.ps1`이 실제 경로를 PATH에 넣어 우회한다. 증상과 조치는 `docs/TROUBLESHOOTING.md`에 있다.
- 버전 고정: 어떤 도구도 버전을 고정하지 않는다. skills, 플러그인, Linux GitHub 릴리스는 실행할 때마다 최신이 들어오므로, `skills.txt`·`plugins.txt`에 저장소를 추가할 때는 그 저장소를 직접 확인한다.

## 변경 지침

- 새 도구는 OS별 매니페스트에 한 줄 추가한다. `winget.txt`와 `Brewfile`은 같은 도구 목록을 유지한다.
- 설정 파일을 추가하면 `install.ps1`과 `install.sh` 양쪽 배포 목록에 넣는다.
- `install.sh`는 macOS 기본 bash 3.2에서도 돌아야 한다. `mapfile`, 연관 배열 같은 bash 4 기능을 쓰지 않는다.
- CI(`.github/workflows/lint.yml`)는 shellcheck, PowerShell 구문, JSON·TOML 구문만 본다. 설치 동작은 실제 머신에서 확인한다.
