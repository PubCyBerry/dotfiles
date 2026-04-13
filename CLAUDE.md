# CLAUDE.md

Windows 11 + Linux 환경을 위한 개인 dotfiles. bash 설정, 패키지 설치 스크립트, Claude Code 에이전트 설정을 관리한다.

## 설치 명령

### Windows (주 환경)

```powershell
# 1. PowerShell 7+ 설치 (관리자 권한)
winget install --id Microsoft.PowerShell --source winget

# 2. 저장소 클론 후 단일 진입점 실행 (pwsh, 관리자 권한)
pwsh -ExecutionPolicy Bypass -File .\dotfiles\install.ps1
```

### Linux

```bash
# 전체 설치
bash install.sh

# bash 설정만 다시 링크
for file in config/bash/.*; do [[ -f "$file" ]] && ln -sf "$(pwd)/$file" "$HOME/$(basename $file)"; done

# skills만 재설치
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  [[ "$line" =~ ^([^@]+)@(.+)$ ]] && npx skills add "${BASH_REMATCH[1]}" --skill "${BASH_REMATCH[2]}" -g -y
done < manifests/skills.txt
```

## 아키텍처

```
dotfiles/
├── install.ps1          # Windows 설치 (all-in-one)
├── install.sh           # Linux 설치 (all-in-one)
├── config/
│   ├── bash/            # bash dotfiles (.bashrc, .aliases 등) — Linux용 심볼릭 링크 대상
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
2. `config/windows/tmux.conf` → `~/.tmux.conf` 복사
3. fnm → Node.js LTS
4. `manifests/npm-global.txt` → npm 전역 패키지
5. Claude Code native 설치
6. `config/claude/` → `~/.claude/` 배포 (settings.json 병합, CLAUDE.md 단순 복사)
7. RTK 바이너리 설치 + hook 생성 (`~/.local/bin/rtk`, `~/.claude/hooks/rtk-rewrite.sh`)
8. PowerShell 프로파일 설정 (`config/windows/profile.ps1`, 마커 방식)
9. `manifests/skills.txt` → npx skills 설치

### Linux install.sh 실행 순서

1. `config/bash/.*` → `~/.*` 심볼릭 링크 (`.gitconfig.local.example` 제외)
2. `config/starship.toml` → `~/.config/starship.toml` 링크
3. TPM (tmux plugin manager) 설치
4. `manifests/apt.txt` → apt 패키지 (카카오 미러 적용)
5. eza, delta, yq, zoxide, starship, ruff, atuin, lazygit, yazi, difftastic, ast-grep 바이너리 설치
6. fnm → Node.js 24
7. `manifests/npm-global.txt` → npm 전역 패키지
8. Claude Code native 설치
9. RTK 설치 + hook 생성
10. `config/claude/settings.json` → `~/.claude/` (MCP cmd /c 패치)
11. `config/claude/CLAUDE.md` → `~/.claude/` 심볼릭 링크
12. `manifests/skills.txt` → npx skills 설치

### bash 설정 로딩 체인 (Linux)

`.bash_profile` → `.bashrc` → `.exports`, `.aliases`, `.functions`, `.extra`(머신별 개인 설정, git 제외) 순으로 source.
심볼릭 링크이므로 `git pull` 후 즉시 반영된다.

### skills 관리

`manifests/skills.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지한다. 새 skill 추가 시 manifest에만 추가 후 install 스크립트를 다시 실행한다.

## 주의사항

- `~/.gitconfig.local`은 머신별 user.name/email을 담으며 저장소에 포함되지 않는다. 신규 머신 설정 시 `config/bash/.gitconfig.local.example`을 복사해 수동 수정 필요.
- Windows는 PowerShell 7+ (pwsh) 기준. `install.ps1`이 PS 7+ 프로파일에만 설정을 적용한다.
- macOS 지원은 `macos/` 디렉토리에 보류 중이며 현재 설치 스크립트에 포함되지 않는다.
