# 구조와 동작

이 저장소의 구조와 install의 동작을 설명한다. 지켜야 하는 규칙은 `docs/standards/`에, 주요 결정과 그 이유는 `docs/architecture/adr/`에 있고, 전체 문서 목록은 [docs/index.md](docs/index.md)에 있다. 운영 중에 겪은 문제는 GitHub 이슈에 기록한다([이슈 규칙](docs/standards/issues.md)).

## 개요

개인 dotfiles 저장소다. 패키지 목록(`manifests/`)과 설정 파일(`config/`)을 두고, OS별 install 스크립트가 패키지 매니저와 공식 installer를 불러 설치한 뒤 설정 파일을 배포한다. 지원하는 OS와 설치 명령은 [README.md](README.md)에 있다.

install은 여러 번 실행해도 된다. 실행할 때마다 패키지 매니저와 각 도구의 `update` 명령으로 도구를 최신으로 올리고, 설정 파일을 다시 배포한다. 실패한 단계는 마지막에 모아 보여 주고 종료 코드 1로 끝난다. 설치 기록, uninstall, 버전 고정은 두지 않는다. 이유는 [ADR 0005](docs/architecture/adr/0005-keep-installers-thin.md)에 있다.

## 구조

| 경로 | 내용 |
|---|---|
| `install.ps1` | Windows install 스크립트 |
| `install.sh` | macOS와 Linux install 스크립트 |
| `manifests/` | 패키지 목록. 파일마다 첫머리 주석에 형식과 설치 방법이 있다 |
| `config/` | 배포할 설정 파일의 원본. 도구별 디렉터리로 나뉜다 |
| `config/agents/global.md` | 모든 에이전트에 배포하는 전역 지침의 원본 |
| `config/bash/` | Git Bash와 Linux의 bash 프로파일 |
| `config/zsh/` | macOS의 zsh 프로파일 |
| `config/powershell/` | Windows의 PowerShell 프로파일 |
| `config/macos/.macos` | macOS 시스템 기본값. Finder와 Dock을 재시작하므로 install이 실행하지 않고, 필요할 때 직접 실행한다 |
| `docs/` | 문서(OKF bundle). 전체 목록은 `docs/index.md`에 있다 |
| `.github/` | CI, 이슈 템플릿, PR 템플릿 |
| `AGENTS.md` | 에이전트 진입점과 작업별 문서 색인 |
| `INSTALL.md` | 에이전트가 설치를 대신 수행하는 절차 |
| `SECURITY.md` | 보안 정책 |

## 설치 단계

설치 단계와 순서는 각 install 스크립트의 단계 호출이 정한다. install 스크립트들은 같은 단계를 같은 순서로 실행하고, 뒤 단계는 앞 단계가 설치한 도구를 쓴다.

- 패키지 매니저로 도구를 설치한 뒤에 git 설정과 설정 파일 배포를 한다.
- fnm으로 Node.js LTS를 설치한 뒤에 npm 전역 패키지와 skills를 설치한다. 둘 다 Node.js가 필요하다.
- 공식 installer로 Claude Code를 설치한 뒤에 Claude Code 플러그인을 설치한다.
- git 설정은 `config/git/gitconfig`의 키 중 아직 값이 없는 것만 넣는다. 이미 있는 값은 사용자 설정으로 본다.
- 셸 밖에서 실행된 프로세스(hook 등)도 node를 찾도록, Node.js 단계가 fnm 기본 버전을 셸 프로파일과 무관한 위치에 연결한다.

## 배포 방식

설정 파일은 아래 방식 중 하나로 배포한다. 파일별 방식은 install 스크립트의 `config files`와 `shell profiles` 단계가 정하고, 새 파일의 방식을 고르는 기준은 [배포 방식 선택](docs/standards/installer.md#배포-방식-선택)에 있다.

| 방식 | 동작 |
|---|---|
| 덮어쓰기 | 매번 저장소 파일로 덮어쓴다. 원본은 git에 있으므로 백업하지 않는다 |
| 병합 | 저장소 파일 위에 기존 파일을 겹친다. 겹치는 키는 기존 값이 이긴다 |
| 마커 블록 | install 스크립트가 정한 시작 줄과 끝 줄 사이만 교체하고, 블록 밖의 내용은 그대로 둔다 |

병합은 기존 값이 이기므로, 이미 그 키가 있는 머신에는 저장소에서 바꾼 값이 들어가지 않는다. 배열도 통째로 기존 값이 이긴다. 저장소 값을 다시 넣으려면 대상 파일에서 그 키를 지우고 install을 다시 실행한다. 다른 도구(Orca 등)가 `settings.json`에 넣는 hook이 지워지지 않는 것도 이 동작 덕분이다. 이유는 [ADR 0006](docs/architecture/adr/0006-merge-app-managed-config.md)에 있다.

## 도구별 동작

- statusline: Claude Code의 statusline 명령이 `config/claude/statusline.sh`를 부르고, 이 스크립트가 claude-hud와 ccusage 출력을 합친다. claude-hud 경로는 실행할 때 찾으므로 Node나 플러그인이 업데이트돼도 동작한다. 표시 항목은 `config/claude/claude-hud.json`과 `statusline.sh`의 출력 처리가 정한다.
- 시각 주입 hook: 에이전트가 사용자 입력을 처리하기 전에 현재 시각을 대화에 넣는다. 에이전트별 등록 위치는 [에이전트 사이의 동작 일치](docs/standards/agent-config.md#에이전트-사이의-동작-일치)에 있다.
- output style: `config/claude/settings.json`의 `outputStyle`은 플러그인이 제공하는 스타일을 가리킨다. 새 머신에서는 플러그인 단계가 끝날 때까지 기본 스타일로 보인다.
- herdr: Windows용 설정은 `config/herdr/config.windows.toml`이다. Windows에서는 `shell_mode`를 지정하지 않는다. 0.8 preview에서 `login`으로 두면 cmd.exe가 실행됐다. herdr를 먼저 실행해 `config.toml`이 생긴 머신에서는 병합에서 기존 값이 이기므로, 그 파일을 지우고 install을 다시 실행한다.
- Windows SSH: WinGet 심볼릭 링크와 fnm junction은 SSH(네트워크 로그온) 세션에서 실행이 막힌다. `config/bash/bashrc`와 `config/powershell/profile.ps1`이 실제 경로를 PATH에 넣어 우회한다. 증상과 조치는 [이슈 #13](https://github.com/PubCyBerry/dotfiles/issues/13)에 있다.

## CI

`.github/workflows/lint.yml`이 정적 검사를 한다. 설치 동작은 CI에서 확인하지 않으므로 실제 머신에서 확인한다.
