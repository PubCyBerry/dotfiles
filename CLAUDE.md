# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 이 저장소

Windows 11 + WSL2 (Ubuntu 22.04) + macOS 환경을 위한 개인 dotfiles. bash 설정, 패키지 설치 스크립트, Claude Code 에이전트 설정을 관리한다.

## 설치 명령

```bash
# 전체 설치 (WSL2/macOS)
bash install.sh

# bash 설정만 다시 링크
for file in bash/.*; do [[ -f "$file" ]] && ln -sf "$(pwd)/$file" "$HOME/$(basename $file)"; done

# OS별 패키지만 설치
bash linux/packages.sh && bash linux/install-extras.sh   # WSL2/Linux
bash macos/install.sh                                     # macOS

# 에이전트/스킬만 재설치
bash agents/restore-skills.sh   # npx skills
```

## 아키텍처

### 진입점: `install.sh`

실행 순서:
1. `bash/.*` → `~/.*` 심볼릭 링크 생성 (`.gitconfig.local.example` 제외)
2. OS 감지 후 패키지 설치 (`macos/install.sh` 또는 `linux/packages.sh` + `linux/install-extras.sh`)
3. `tools/fnm.sh` → fnm 설치
4. `tools/node.sh` → Node.js LTS + Claude Code 설치
5. `agents/setup.sh` → Claude 설정 링크 + npx skills 설치

### bash 설정 로딩 체인

`.bash_profile` → `.bashrc` → `.exports`, `.aliases`, `.functions`, `.extra`(머신별 개인 설정, git 제외) 순으로 source.
심볼릭 링크이므로 `git pull` 후 즉시 반영된다.

### Claude Code 설정

`agents/claude/` 파일들이 심볼릭 링크된다:
- `CLAUDE.md` → `~/.claude/CLAUDE.md` (전역 Claude 행동 설정)
- `settings.json` → `~/.claude/settings.json` (언어, 권한 포함)

### skills 관리

`agents/skills-manifest.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, `restore-skills.sh`가 `npx skills add ... -g -y`로 일괄 설치한다. 새 skill 추가 시 manifest에만 추가하면 된다.

### Windows 설치 (PowerShell 7+ 기준)

Windows는 PowerShell 7+ (pwsh)을 기본 셸로 사용한다.

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. Windows Terminal → Settings → Default profile → PowerShell 7 선택

# 3. 패키지 설치 (pwsh에서 관리자 권한으로 실행)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\windows\install.ps1

# 4. Claude Code 설정 + 프로파일 적용
pwsh -ExecutionPolicy Bypass -File .\dotfiles\windows\agents-setup.ps1
```

`agents-setup.ps1`은 PS 5.1(`Documents\WindowsPowerShell`)과 PS 7+(`Documents\PowerShell`) 프로파일 양쪽에 dotfiles 블록과 `ccd` 별칭을 삽입한다.

## 주의사항

- `~/.gitconfig.local`은 머신별 user.name/email을 담으며 저장소에 포함되지 않는다. 신규 머신 설정 시 `.gitconfig.local.example`을 복사해 수동 수정 필요.
- `linux/packages.sh`는 카카오 CDN 미러(`mirror.kakao.com`)를 사용한다.
- Windows는 PowerShell 7+ (pwsh) 기준으로 설정한다. `install.ps1`이 pwsh를 포함한 도구를 설치하고, `agents-setup.ps1`이 PS 5.1/7+ 프로파일 양쪽에 설정을 적용한다.
