# dotfiles

Windows 11 + WSL2 (Ubuntu 22.04) + macOS 환경을 위한 dotfiles.

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (Git Bash) | 일부 (winget 패키지, PowerShell) |
| WSL2 Ubuntu 22.04 | ✅ 완전 지원 |
| macOS | ✅ 완전 지원 |

---

## 새 머신 셋업 가이드

### WSL2 / macOS

```bash
# 1. 클론
git clone git@github.com:PubCyBerry/dotfiles.git ~/dotfiles

# 2. 설치
cd ~/dotfiles && bash install.sh

# 3. git 사용자 정보 설정 (최초 1회)
cp ~/dotfiles/bash/.gitconfig.local.example ~/.gitconfig.local
# ~/.gitconfig.local 열어서 name/email 수정

# 4. 셸 재시작
exec bash
```

### Windows 11

> **주의:** Windows에서는 bash 심볼릭 링크가 지원되지 않는다. bash 설정(`.bashrc` 등)은 WSL2에서 관리한다.

```powershell
# PowerShell (관리자 권한)
# 1. 저장소 클론
git clone git@github.com:PubCyBerry/dotfiles.git $env:USERPROFILE\dotfiles

# 2. winget 패키지 + Node.js LTS + Claude Code 설치
.\dotfiles\windows\install.ps1

# 3. git 사용자 정보 설정
git config --global user.name "PubCyBerry"
git config --global user.email "kth7186@gmail.com"

# 4. Claude Code 설정 복사 (심볼릭 링크 대신 수동 복사)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude" | Out-Null
Copy-Item "$env:USERPROFILE\dotfiles\agents\claude\settings.json" `
          "$env:USERPROFILE\.claude\settings.json" -Force
Copy-Item "$env:USERPROFILE\dotfiles\agents\claude\CLAUDE.md" `
          "$env:USERPROFILE\.claude\CLAUDE.md" -Force

# 5. Claude Code 실행 후 플러그인 설치
# claude 실행 → /plugin 명령으로 superpowers, context7 설치
```

> **MCP 서버**: `settings.json` 복사 시 `sequential-thinking` MCP가 자동 등록됨 (`cmd /c npx` 형식 포함).
> **settings.json 업데이트**: dotfiles에서 변경 사항이 있으면 4번 복사 명령을 다시 실행.

---

## 설치 순서 상세

`install.sh`는 다음 순서로 실행됩니다:

```
1. bash/ 파일들 → ~/.* 심볼릭 링크
2. OS 패키지 설치 (apt / brew)
3. Modern CLI 도구 설치 (eza, delta 등)
4. fnm 설치
5. Node.js LTS + Claude Code 설치
6. AI 에이전트 설정 (The Agency, npx skills)
```

---

## 기존 머신 업데이트

```bash
cd ~/dotfiles && git pull
# 심볼릭 링크라서 bash 설정은 pull 즉시 반영됨
# 새 패키지가 추가된 경우:
bash linux/packages.sh        # WSL
bash macos/install.sh         # macOS
```

---

## 도구 사용법

### bat — syntax-highlighted cat

```bash
cat file.js          # alias로 bat 실행
bat file.js          # 직접 실행
bat -n file.js       # 줄 번호만 (색상 없이)
bat --plain file.js  # 순수 텍스트 출력
```

### eza — 컬러 ls 대체

```bash
ls           # 기본 목록 (아이콘 포함)
ll           # 상세 목록
la           # 숨김 파일 포함 상세 목록
lt           # 트리 뷰 (2 depth)
eza --tree --level=3  # 트리 뷰 (depth 직접 지정)
eza -lh --git         # git 상태 포함 상세 목록
```

### fzf — 퍼지 파인더

```bash
# 파일 검색
fzf

# 히스토리 검색 (Ctrl+R 대체)
# 터미널에서 Ctrl+R 입력 시 fzf로 인터랙티브 검색

# 명령어와 조합
cat $(fzf)            # fzf로 파일 선택 후 cat
code $(fzf)           # fzf로 파일 선택 후 VS Code로 열기
```

### fd — 빠른 find 대체

```bash
fd                    # 현재 디렉토리의 모든 파일
fd pattern            # 이름에 pattern이 포함된 파일
fd -e js              # .js 확장자 파일만
fd -t d               # 디렉토리만
fd pattern src/       # src/ 안에서 검색
fd --hidden           # 숨김 파일 포함
```

### rg (ripgrep) — 빠른 grep 대체

```bash
rg "검색어"            # 현재 디렉토리 재귀 검색
rg "검색어" src/       # 특정 디렉토리에서 검색
rg -t js "검색어"      # .js 파일만 검색
rg -l "검색어"         # 파일명만 출력
rg -i "검색어"         # 대소문자 무시
rg --no-ignore "검색어" # .gitignore 무시하고 검색
```

### delta — git diff 뷰어

`git diff`, `git show`, `git log -p` 실행 시 자동으로 delta가 적용됩니다.

```bash
git diff              # delta로 예쁘게 표시
git show HEAD         # 마지막 커밋 diff
git log -p            # 전체 히스토리 diff

# delta 직접 실행
delta file1 file2
```

### shell functions

`~/.functions`에 정의된 유틸리티 함수 모음.

```bash
mkcd my-project     # mkdir + cd 한번에
up 2                # 2단계 위 디렉토리로 이동 (기본값: 1)
extract file.tar.gz # 확장자 자동 감지 후 압축 해제
```

WSL2 전용 (Windows 클립보드 연동):

```bash
echo "hello" | clip  # Windows 클립보드로 복사
paste                 # 클립보드 내용 출력
wpath ~/dotfiles      # WSL 경로 → Windows 경로
upath "C:\Users\foo"  # Windows 경로 → WSL 경로
```

### bun — JavaScript 런타임 & 패키지 매니저

Node.js 호환 런타임. npx보다 빠른 스크립트 실행과 패키지 관리에 사용.

| OS | 설치 방법 |
|----|-----------|
| macOS | `brew install oven-sh/bun/bun` (Brewfile 자동) |
| WSL2/Linux | `curl -fsSL https://bun.sh/install \| bash` (install.sh 자동) |
| Windows | `winget install Oven-sh.Bun` (install.ps1 자동) |

```bash
bun --version      # 설치 확인
bunx <package>     # npx 대체
bun install        # npm install 대체 (빠름)
```

---

## git 설정

### 전역 alias

| alias | 원래 명령 |
|-------|-----------|
| `git st` | `git status -sb` |
| `git co` | `git checkout` |
| `git br` | `git branch` |
| `git lg` | `git log --oneline --graph --decorate --all` |
| `git last` | `git log -1 HEAD` |
| `git undo` | `git reset --soft HEAD~1` |

### 머신별 설정 (~/.gitconfig.local)

```ini
[user]
  name = PubCyBerry
  email = kth7186@gmail.com
```

> 회사 컴퓨터는 회사 이메일로 수정하세요.

---

## AI 에이전트

### Claude Code 설정

| 파일 | 위치 | 내용 |
|------|------|------|
| `agents/claude/CLAUDE.md` | `~/.claude/CLAUDE.md` | 전역 Claude 행동 설정 |
| `agents/claude/settings.json` | `~/.claude/settings.json` | Claude Code 설정 (플러그인, MCP, statusLine 포함) |

### 플러그인

Claude Code 플러그인은 `settings.json`의 `enabledPlugins`로 관리된다.
`agents/setup.sh`로 settings.json을 링크하면 활성화 목록은 자동 복원되지만,
**플러그인 파일 자체는 Claude Code 내에서 별도 설치 필요:**

```
/plugin   # 플러그인 마켓에서 superpowers, context7 검색 후 설치
```

| 플러그인 | 설명 |
|----------|------|
| `superpowers@claude-plugins-official` | Skills 시스템, 에이전트 워크플로우 |
| `context7@claude-plugins-official` | 라이브러리 최신 문서 조회 MCP 서버 제공 |

superpowers 플러그인이 제공하는 주요 skills (플러그인 설치 후 자동 제공, 별도 설치 불필요):

| skill | 설명 |
|-------|------|
| `superpowers:subagent-driven-development` | 플랜을 서브에이전트로 병렬 실행 |
| `superpowers:writing-plans` | 구현 전 상세 계획 수립 |
| `superpowers:test-driven-development` | TDD 방식 구현 가이드 |
| `superpowers:systematic-debugging` | 버그/실패 원인 체계적 분석 |
| `superpowers:requesting-code-review` | 구현 완료 후 코드 리뷰 요청 |

### MCP 서버

`agents/claude/settings.json`의 `mcpServers`로 전역 MCP 서버를 관리한다.
settings.json 링크 후 Claude Code 재시작 시 자동 등록된다.

| MCP 서버 | 패키지 | 설명 |
|----------|--------|------|
| `sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | 단계적 사고 도구 |

> **주의 — Windows vs macOS/Linux:**
> 현재 `settings.json`의 MCP 명령은 Windows 전용(`cmd /c npx ...`)이다.
> macOS/Linux에서는 `settings.json`의 `sequential-thinking` 항목을 아래와 같이 수정:
> ```json
> "sequential-thinking": {
>   "type": "stdio",
>   "command": "npx",
>   "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
> }
> ```

### ccstatusline

터미널 상태 표시줄에 Claude Code 세션 정보를 표시.
`agents/setup.sh`가 실행 설정(settings.json)과 레이아웃 설정 모두 자동 링크함.
별도 설치 불필요 (npx로 자동 실행).

| 파일 | 링크 위치 | 내용 |
|------|-----------|------|
| `agents/claude/ccstatusline-settings.json` | `~/.config/ccstatusline/settings.json` | 레이아웃 설정 |

현재 레이아웃:
- 1줄: `모델 | Thinking Effort | Context % | Cost | Session Wall time`
- 2줄: `git branch | git worktree | changes`

### 에이전트/스킬 복원

새 머신에서 `install.sh`가 자동으로 실행하지만, 수동으로 재설치할 경우:

```bash
# The Agency 서브에이전트 재설치
bash ~/dotfiles/agents/restore-agents.sh

# npx skills 재설치
bash ~/dotfiles/agents/restore-skills.sh
```

### 설치된 npx skills 목록

| 스킬 | 설명 |
|------|------|
| `pdf`, `docx`, `pptx`, `xlsx` | 문서 처리 |
| `bash-defensive-patterns` | 프로덕션용 bash 스크립트 패턴 |
| `shellcheck-configuration` | shell 스크립트 린팅 |
| `powershell-windows` | PowerShell 패턴 |
| `skill-creator` | 새 skill 생성 |
| `find-skills` | skill 검색/설치 |

---

## 파일 구조

```
dotfiles/
  install.sh                  # 메인 진입점
  bash/
    .bashrc                   # 셸 초기화
    .bash_profile             # 로그인 셸
    .aliases                  # 명령어 단축키
    .exports                  # 환경변수
    .gitconfig                # git 전역 설정 (공유)
    .gitconfig.local.example  # 머신별 설정 템플릿
    .gitignore_global         # 전역 gitignore
  tools/
    fnm.sh                    # fnm 설치
    node.sh                   # Node LTS + Claude Code 설치
  linux/
    packages.sh               # apt 패키지 (카카오 미러)
    install-extras.sh         # eza, delta (apt 미지원 도구)
  macos/
    install.sh                # Homebrew + Brewfile
    Brewfile                  # macOS 패키지 목록
  windows/
    install.ps1               # winget 패키지 설치
  agents/
    setup.sh                  # Claude 설정 링크 + 에이전트 설치
    restore-agents.sh         # The Agency 재설치
    restore-skills.sh         # npx skills 재설치
    skills-manifest.txt       # 설치할 skills 목록
    claude/
      CLAUDE.md               # Claude 전역 행동 설정
      settings.json           # Claude Code 설정
```

---

## TODO

### 중기
- [ ] MCP 서버 cross-platform 자동화 — `agents/setup.sh`에서 OS별 분기 처리 (`cmd /c npx` → `npx`)
- [ ] `bash/.functions` — 자주 쓰는 셸 함수 모음 (`mkcd`, `extract` 등)
- [ ] `bash/.inputrc` — 히스토리 검색, 단축키 개선
- [ ] `.wslconfig` — WSL2 메모리/CPU 제한 최적화
- [ ] WSL ↔ Windows 클립보드/경로 변환 함수
- [ ] `tools/global-packages.txt` — npm 전역 패키지 목록 관리
- [ ] `windows/agents-setup.ps1` — PowerShell에서 Claude 설정 자동 복사 (현재 수동)

### 장기
- [ ] `macos/.macos` — macOS 시스템 설정 자동화
- [ ] Gemini CLI, antigravity 설정 추가
- [ ] README.md 한국어/영어 분리
