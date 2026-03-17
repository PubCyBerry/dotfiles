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
bash agents/restore-agents.sh   # The Agency 서브에이전트
bash agents/restore-skills.sh   # npx skills
```

## 아키텍처

### 진입점: `install.sh`

실행 순서:
1. `bash/.*` → `~/.*` 심볼릭 링크 생성 (`.gitconfig.local.example` 제외)
2. OS 감지 후 패키지 설치 (`macos/install.sh` 또는 `linux/packages.sh` + `linux/install-extras.sh`)
3. `tools/fnm.sh` → fnm 설치
4. `tools/node.sh` → Node.js LTS + Claude Code 설치
5. `agents/setup.sh` → Claude 설정 링크 + The Agency + npx skills 설치

### bash 설정 로딩 체인

`.bash_profile` → `.bashrc` → `.exports`, `.aliases`, `.functions`, `.extra`(머신별 개인 설정, git 제외) 순으로 source.
심볼릭 링크이므로 `git pull` 후 즉시 반영된다.

### Claude Code 설정

`agents/claude/` 파일들이 심볼릭 링크된다:
- `CLAUDE.md` → `~/.claude/CLAUDE.md` (전역 Claude 행동 설정)
- `settings.json` → `~/.claude/settings.json` (플러그인, MCP, statusLine, 언어, 권한 포함)
- `ccstatusline-settings.json` → `~/.config/ccstatusline/settings.json` (상태 표시줄 레이아웃)

### 플러그인 & MCP 서버

`settings.json`의 `enabledPlugins`로 관리:

| 플러그인 | 설명 |
|----------|------|
| `superpowers@claude-plugins-official` | Skills 시스템, 에이전트 워크플로우 |
| `context7@claude-plugins-official` | 라이브러리 문서 조회 MCP 서버 제공 |

플러그인 재설치:
```bash
# Claude Code 내에서
/plugin
# 목록에서 superpowers, context7 선택
```

`agents/claude/settings.json`의 `mcpServers`로 전역 MCP 서버를 관리한다:

| MCP 서버 | 패키지 | 설명 |
|----------|--------|------|
| `sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | 단계적 사고 도구 |

> **참고**: `command: "cmd"` + `args: ["/c", "npx", ...]` 형식은 Windows 전용이다. macOS/Linux에서는 `command: "npx"`, `args: ["-y", ...]`로 변경 필요.

### skills 관리

`agents/skills-manifest.txt`에 `owner/repo@skill-name` 형식으로 목록을 유지하고, `restore-skills.sh`가 `npx skills add ... -g -y`로 일괄 설치한다. 새 skill 추가 시 manifest에만 추가하면 된다.

## 주의사항

- `~/.gitconfig.local`은 머신별 user.name/email을 담으며 저장소에 포함되지 않는다. 신규 머신 설정 시 `.gitconfig.local.example`을 복사해 수동 수정 필요.
- `linux/packages.sh`는 카카오 CDN 미러(`mirror.kakao.com`)를 사용한다.
- Windows는 `windows/install.ps1` (winget)만 지원하며, bash 설정 링크는 지원하지 않는다.
