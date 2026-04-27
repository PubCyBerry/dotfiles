# CLAUDE.md

Windows 11 / Ubuntu 환경을 위한 개인 dotfiles. 터미널 설정, 패키지 설치 스크립트, AI 에이전트 설정을 관리한다.

## 설치 명령

### Windows (주 환경)

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\install.ps1
```

### Linux (Ubuntu 22.04+)

```bash
# 저장소 클론 후 단일 진입점 실행
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles
bash ~/dotfiles/install.sh
```

## 아키텍처

```text
dotfiles/
├── install.ps1          # Windows 설치 (all-in-one)
├── install.sh           # Ubuntu 설치 (all-in-one)
├── config/
│   ├── bash/            # bash dotfiles (bashrc, inputrc) — Git Bash + Linux 공통, 마커 방식 삽입
│   ├── claude/          # Claude Code 설정 (settings.json, CLAUDE.md)
│   ├── git/
│   │   └── gitconfig    # OS-중립. autocrlf/fileMode은 install 스크립트가 OS별 주입
│   ├── nvim/            # Neovim 설정 (lazy.nvim + yazi.nvim)
│   ├── windows/         # Windows 전용 (profile.ps1, tmux.conf — default-shell=pwsh)
│   ├── linux/           # Linux 전용 (tmux.conf — default-shell=bash)
│   ├── yazi/            # yazi 설정 (yazi.toml — nvim opener)
│   └── starship.toml
├── manifests/           # 패키지/스킬 목록
│   ├── winget.txt       # Windows winget 패키지 ID
│   ├── apt.txt          # Ubuntu apt 패키지
│   ├── npm-global.txt   # npm 전역 패키지
│   └── skills.txt       # Claude Code skills (owner/repo@skill-name)
├── macos/               # macOS 지원 (보류)
└── docs/
```

### Windows install.ps1 실행 순서

1. `manifests/winget.txt` → winget 패키지 설치
   1-1. `config/git/gitconfig` → git config 병합 + Windows override (`autocrlf=true`, `fileMode=false`)
   1-2. `config/windows/tmux.conf` → `~/.tmux.conf` 복사
   1-3. `YAZI_FILE_ONE` 환경변수 설정 (Git file.exe 경로)
   1-4. `config/yazi/` → `%APPDATA%\yazi\config\` 배포 (nvim opener 설정)
   1-5. Neovim PATH 환경변수 설정 (`C:\Program Files\Neovim\bin`)
   1-6. `config/nvim/` → `$LOCALAPPDATA\nvim\` 배포 (lazy.nvim Structured Setup, 기존 설정 있으면 건너뜀)
2. fnm → Node.js LTS
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
3. Claude Code native 설치
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, CLAUDE.md 단순 복사)
   3-2. RTK 바이너리 설치 + hook 생성 (`~/.local/bin/rtk`, `~/.claude/hooks/rtk-rewrite.sh`)
4. PowerShell 프로파일 설정 (`config/windows/profile.ps1`, 마커 방식)
5. Git Bash 프로파일 설정 (`config/bash/bashrc`, 마커 방식 → `~/.bashrc`)
6. `manifests/skills.txt` → npx skills 설치

### Linux install.sh 실행 순서

1. `manifests/apt.txt` → apt 패키지 설치 
   1-1. `config/git/gitconfig` → git config 병합 + Linux override (`autocrlf=input`, `fileMode=true`)
   1-2. `config/linux/tmux.conf` → `~/.tmux.conf` 복사
   1-3. `config/yazi/` → `~/.config/yazi/` 배포
   1-4. `config/nvim/` → `~/.config/nvim/` 배포 (lazy.nvim Structured Setup, 기존 설정 있으면 건너뜀)
   1-5. `config/starship.toml` → `~/.config/starship.toml` 배포
   1-6. 공식 install 스크립트: zoxide, starship, atuin, fnm(--skip-shell), bun
   1-7. GitHub releases 바이너리: neovim(tar.gz, 0.10+), yazi(.deb), lazygit(tar.gz), git-delta(.deb)
2. fnm → Node.js LTS
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
3. Claude Code native 설치 (`curl -fsSL https://claude.ai/install.sh | bash`)
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json `jq -s '.[0]*.[1]'` 병합, CLAUDE.md 단순 복사)
   3-2. RTK 공식 install.sh + hook 다운로드 (`~/.local/bin/rtk`, `~/.claude/hooks/rtk-rewrite.sh`)
4. bash 프로파일 설정 (`config/bash/bashrc` → `~/.bashrc`, `config/bash/inputrc` → `~/.inputrc`, 마커 방식)
6. `manifests/skills.txt` → npx skills 설치

### skills 관리

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지한다. 새 skill 추가 시 manifest에만 추가 후 install 스크립트를 다시 실행한다.

## Worktree 작업 지침

worktree 세션에서 작업 완료 후 main에 합칠 때 커밋 성격에 따라 전략을 선택한다.

- **wip/임시 커밋이 많은 경우** → Squash Merge: 브랜치 전체를 커밋 하나로 압축
  ```bash
  git switch main
  git merge --squash <브랜치명>
  git commit -m "<의미 있는 커밋 메시지>"
  git branch -d <브랜치명>
  ```
- **독립적인 의미를 가진 커밋이 여러 개인 경우** → Rebase + FF: 커밋 이력을 보존하며 선형화
  ```bash
  git switch <브랜치명>
  git rebase main
  git switch main
  git merge --ff-only <브랜치명>
  git branch -d <브랜치명>
  ```

자세한 워크플로우와 Before/After 예시는 [`docs/worktree-git-workflows.md`](docs/worktree-git-workflows.md) 참고.

## 주의사항

- Windows는 PowerShell 7+ (pwsh) 기준. `install.ps1`이 PS 7+ 프로파일에만 설정을 적용한다.
- Git Bash 지원: `install.ps1`이 `~/.bashrc`에 마커 방식으로 설정을 삽입한다. Git for Windows가 설치되어 있어야 한다.
- Linux는 Ubuntu 22.04 LTS 이상(apt 기반). `install.sh`는 sudo 권한이 필요하다.
- macOS 지원은 `macos/` 디렉토리에 보류 중이며 현재 설치 스크립트에 포함되지 않는다.
