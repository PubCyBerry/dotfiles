# CLAUDE.md

Windows 11 환경을 위한 개인 dotfiles. 터미널 설정, 패키지 설치 스크립트, AI 에이전트 설정을 관리한다.

## 설치 명령

### Windows (주 환경)

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\install.ps1
```

## 아키텍처

```text
dotfiles/
├── install.ps1          # Windows 설치 (all-in-one)
├── install.sh           # Linux 설치 (all-in-one)
├── config/
│   ├── bash/            # bash dotfiles (bashrc) — Git Bash(Windows) 마커 방식 삽입
│   ├── claude/          # Claude Code 설정 (settings.json, CLAUDE.md)
│   ├── windows/         # Windows 전용 설정 (profile.ps1, tmux.conf)
│   └── starship.toml
├── manifests/           # 패키지/스킬 목록
│   ├── winget.txt       # Windows winget 패키지 ID
│   ├── apt.txt          # Linux apt 패키지
│   ├── npm-global.txt   # npm 전역 패키지
│   └── skills.txt       # Claude Code skills (owner/repo@skill-name)
├── macos/               # macOS 지원 (보류)
└── docs/
```

### Windows install.ps1 실행 순서

1. `manifests/winget.txt` → winget 패키지 설치
   1-1. `config/git/gitconfig` → git config 병합
   1-2. `config/windows/tmux.conf` → `~/.tmux.conf` 복사
   1-3. `YAZI_FILE_ONE` 환경변수 설정 (Git file.exe 경로)
   1-4. Neovim PATH 환경변수 설정 (`C:\Program Files\Neovim\bin`)
2. fnm → Node.js LTS
   2-1. `manifests/npm-global.txt` → npm 전역 패키지
3. Claude Code native 설치
   3-1. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, CLAUDE.md 단순 복사)
   3-2. RTK 바이너리 설치 + hook 생성 (`~/.local/bin/rtk`, `~/.claude/hooks/rtk-rewrite.sh`)
4. PowerShell 프로파일 설정 (`config/windows/profile.ps1`, 마커 방식)
5. Git Bash 프로파일 설정 (`config/bash/bashrc`, 마커 방식 → `~/.bashrc`)
6. `manifests/skills.txt` → npx skills 설치

### skills 관리

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지한다. 새 skill 추가 시 manifest에만 추가 후 install 스크립트를 다시 실행한다.

## 주의사항

- Windows는 PowerShell 7+ (pwsh) 기준. `install.ps1`이 PS 7+ 프로파일에만 설정을 적용한다.
- Git Bash 지원: `install.ps1`이 `~/.bashrc`에 마커 방식으로 설정을 삽입한다. Git for Windows가 설치되어 있어야 한다.
- macOS 지원은 `macos/` 디렉토리에 보류 중이며 현재 설치 스크립트에 포함되지 않는다.
