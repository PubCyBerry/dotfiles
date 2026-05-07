# AGENTS.md

Windows 11 / Ubuntu / macOS 환경을 위한 개인 dotfiles. 터미널 설정, 패키지 설치 스크립트, AI 에이전트 설정을 관리한다.

## 설치와 업데이트

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

기존 머신 업데이트는 저장소를 pull 한 뒤 같은 설치 명령을 다시 실행한다.

## 재실행 계약

- `install.sh`와 `install.ps1`은 최초 설치와 반복 업데이트를 모두 지원한다.
- dotfiles가 관리하는 config는 repo 버전을 우선 적용하고 기존 대상은 `.dotfiles-backup/<timestamp>/`에 백업한다.
- marker block, PATH 항목, package install은 반복 실행해도 중복/파손이 없어야 한다.
- `gitconfig`는 기존 사용자 값을 보존하고 OS별 override만 명시적으로 갱신한다.

## 주요 옵션

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

## 구조

```text
dotfiles/
├── install.sh
├── install.ps1
├── scripts/install/
│   ├── lib.sh
│   └── lib.ps1
├── config/
├── manifests/
│   ├── apt.txt
│   ├── winget.txt
│   ├── Brewfile
│   ├── npm-global.txt
│   ├── skills.txt
│   └── tools.tsv
└── docs/
```

## 문서

- 설치/업데이트: `docs/install.md`
- CI: `docs/ci.md`
- 언인스톨: `docs/uninstall.md`
- 도구: `docs/tools.md`
- AI 에이전트: `docs/ai-agents.md`
- 작업 흐름: `docs/workflows.md`

## Worktree 작업 지침

작업 완료 후 main에 합칠 때 커밋 성격에 따라 전략을 선택한다.

- wip/임시 커밋이 많은 경우: squash merge
- 독립적인 의미를 가진 커밋이 여러 개인 경우: rebase + fast-forward merge

자세한 내용은 `docs/workflows.md`와 `docs/worktree-git-workflows.md`를 참고한다.
