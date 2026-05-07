# dotfiles

Windows 11을 주 환경으로, Ubuntu와 macOS를 함께 관리하는 개인 dotfiles 저장소다.
설치 스크립트는 최초 부트스트랩뿐 아니라 같은 명령을 반복 실행하는 업데이트 흐름까지 지원한다.

## 지원 환경

| 환경 | 상태 |
|---|---|
| Windows 11 + PowerShell 7+ | 주 환경 |
| Ubuntu 22.04+ | 지원 |
| macOS + Homebrew | 지원 |

## Quickstart

### Windows

```powershell
winget install --id Microsoft.PowerShell --source winget
git clone https://github.com/PubCyBerry/dotfiles.git $env:USERPROFILE\dotfiles
pwsh -ExecutionPolicy Bypass -File $env:USERPROFILE\dotfiles\install.ps1
```

### Ubuntu

```bash
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

### macOS

```bash
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh --with-defaults
```

## 업데이트

저장소를 최신 커밋으로 당긴 뒤 같은 설치 명령을 다시 실행한다.

```bash
cd ~/dotfiles
git pull
bash install.sh
```

```powershell
cd $env:USERPROFILE\dotfiles
git pull
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

반복 실행 계약:

- 이미 설치된 패키지와 도구는 건너뛰거나 필요한 경우만 갱신한다.
- dotfiles가 관리하는 설정은 repo 버전을 우선 적용한다.
- 기존 대상 파일/디렉터리는 `$HOME/.dotfiles-backup/<timestamp>/` 또는 `%USERPROFILE%\.dotfiles-backup\<timestamp>\` 아래에 백업한다.
- profile marker block과 PATH 항목은 중복 생성하지 않는다.
- `gitconfig`는 기존 사용자 값을 보존하고 OS별 override만 명시적으로 갱신한다.

## 옵션

```bash
bash install.sh --dry-run
bash install.sh --only configs
bash install.sh --skip claude,rtk,skills
bash install.sh --profile minimal
```

```powershell
.\install.ps1 --dry-run
.\install.ps1 --only configs
.\install.ps1 --skip claude,rtk,skills
.\install.ps1 --profile minimal
```

단계 이름은 `packages`, `configs`, `node`, `claude`, `rtk`, `skills`다.

CI나 계정 없는 환경에서는 다음 환경변수를 사용할 수 있다.

- `SKIP_CLAUDE_CODE=1`
- `SKIP_RTK=1`
- `SKIP_SKILLS=1`

## 구조

```text
dotfiles/
  install.sh
  install.ps1
  scripts/install/
    lib.sh
    lib.ps1
  config/
  manifests/
    apt.txt
    winget.txt
    Brewfile
    npm-global.txt
    skills.txt
    tools.tsv
  docs/
```

## 문서

- [설치와 업데이트](docs/install.md)
- [클린 언인스톨](docs/uninstall.md)
- [CI](docs/ci.md)
- [CLI 도구](docs/tools.md)
- [AI 에이전트 설정](docs/ai-agents.md)
- [작업 흐름](docs/workflows.md)
