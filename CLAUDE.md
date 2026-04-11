# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소

Windows 11 + macOS 환경을 위한 개인 dotfiles. bash 설정, 패키지 설치 스크립트, Claude Code 에이전트 설정을 관리한다.

## 설치 명령

### Windows (주 환경)

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\install.ps1
```

`install.ps1`은 `windows\install.ps1` → `windows\agents-setup.ps1` 순으로 실행한다.

### macOS / Linux

```bash
# 전체 설치
bash install.sh

# bash 설정만 다시 링크
for file in bash/.*; do [[ -f "$file" ]] && ln -sf "$(pwd)/$file" "$HOME/$(basename $file)"; done

# OS별 패키지만 설치
bash macos/install.sh      # macOS
bash linux/packages.sh && bash linux/install-extras.sh  # Linux

# 에이전트/스킬만 재설치
bash agents/restore-skills.sh
```

## 아키텍처

### Windows 진입점: `install.ps1` (루트)

실행 순서:
1. `windows\install.ps1` → winget 패키지, Node.js LTS, npm 전역 패키지, Claude Code, RTK, ast-grep, difftastic 설치
2. `windows\agents-setup.ps1` → Claude 설정 복사, RTK hook 생성, PowerShell 프로파일 설정, npx skills 복원

### macOS/Linux 진입점: `install.sh`

실행 순서:
1. `bash/.*` → `~/.*` 심볼릭 링크 생성 (`.gitconfig.local.example` 제외)
2. OS 감지 후 패키지 설치 (`macos/install.sh` 또는 `linux/packages.sh` + `linux/install-extras.sh`)
3. `tools/fnm.sh` → fnm 설치
4. `tools/node.sh` → Node.js LTS + Claude Code 설치
5. `agents/setup.sh` → Claude 설정 링크 + npx skills 설치

### bash 설정 로딩 체인 (macOS/Linux)

`.bash_profile` → `.bashrc` → `.exports`, `.aliases`, `.functions`, `.extra`(머신별 개인 설정, git 제외) 순으로 source.
심볼릭 링크이므로 `git pull` 후 즉시 반영된다.

### Claude Code 설정

- **Windows**: `agents/claude/` 파일들이 `~/.claude/`로 복사된다.
- **macOS/Linux**: `agents/claude/CLAUDE.md` → `~/.claude/CLAUDE.md` 심볼릭 링크, `settings.json` 복사 후 MCP 명령어 패치.

### skills 관리

`agents/skills-manifest.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, `restore-skills.sh`가 `npx skills add ... -g -y`로 일괄 설치한다. 새 skill 추가 시 manifest에만 추가하면 된다.

## 주의사항

- `~/.gitconfig.local`은 머신별 user.name/email을 담으며 저장소에 포함되지 않는다. 신규 머신 설정 시 `.gitconfig.local.example`을 복사해 수동 수정 필요.
- Windows는 PowerShell 7+ (pwsh) 기준으로 설정한다. `agents-setup.ps1`이 PS 5.1/7+ 프로파일 양쪽에 설정을 적용한다.
