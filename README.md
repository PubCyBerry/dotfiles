# dotfiles

Windows 11 + WSL2 (Ubuntu 22.04) + macOS 환경을 위한 dotfiles.

## 지원 환경

| 환경 | 지원 |
|------|------|
| Windows 11 (Git Bash) | 일부 (winget 패키지, PowerShell) — ast-grep/difftastic GitHub Releases 자동 다운로드 |
| Ubuntu 22.04 (WSL2 / 네이티브) | ✅ 완전 지원 |
| macOS | ✅ 완전 지원 |

---

## 새 머신 셋업 가이드

### Linux / macOS

```bash
# 1. 클론
git clone https://github.com/PubCyBerry/dotfiles.git ~/dotfiles

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
git clone https://github.com/PubCyBerry/dotfiles.git $env:USERPROFILE\dotfiles

# 2. winget 패키지 + Node.js LTS + Claude Code (네이티브) 설치
.\dotfiles\windows\install.ps1

# 3. git 사용자 정보 설정
git config --global user.name "PubCyBerry"
git config --global user.email "kth7186@gmail.com"

# 4. Claude Code 설정 복사 + PowerShell $PROFILE 설정 + RTK hook 등록
.\dotfiles\windows\agents-setup.ps1

# 5. Claude Code에서 플러그인 설치
# claude 실행 후 /plugin 명령으로 superpowers, context7 설치
```

> **MCP 서버**: `settings.json` 복사 시 `sequential-thinking` MCP가 자동 등록됨.
> **설정 업데이트**: dotfiles 변경 사항 적용 시 `agents-setup.ps1`을 다시 실행.

---

## 설치 순서 상세

`install.sh`는 다음 순서로 실행됩니다:

```
1. bash/ 파일들 → ~/.* 심볼릭 링크
2. OS 패키지 설치 (apt / brew)
3. Modern CLI 도구 설치 (eza, delta, zoxide, starship 등)
4. fnm 설치
5. Node.js LTS 설치 + Claude Code 네이티브 설치
6. bun 설치
7. npm 전역 패키지 설치 (gemini-cli, codex, opencode 등)
8. RTK 설치 및 hook 등록
9. AI 에이전트 설정 (The Agency, npx skills)
```

---

## 기존 머신 업데이트

```bash
cd ~/dotfiles && git pull
# 심볼릭 링크라서 bash 설정은 pull 즉시 반영됨
# 새 패키지가 추가된 경우:
bash linux/packages.sh        # Linux/Ubuntu
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

### zoxide — 스마트 cd

```bash
z foo          # 'foo'가 포함된 자주 간 디렉토리로 이동
z foo bar      # 'foo'와 'bar' 모두 포함된 경로로 이동
zi             # fzf로 히스토리 대화형 선택
```

### lazygit — TUI git 클라이언트

```bash
lazygit        # 현재 저장소에서 실행
```
`space`로 스테이징, `c`로 커밋, `P`로 푸시. `?`로 단축키 목록.

### yazi — TUI 파일 매니저

```bash
yazi           # 현재 디렉토리에서 실행
```
`hjkl`로 탐색, `Enter`로 열기, `y`로 복사, `d`로 삭제.

### starship — 쉘 프롬프트

`~/.config/starship.toml`로 커스터마이징. 기본값으로 git 브랜치/상태, 언어 버전 자동 표시.

```bash
starship preset --list          # 프리셋 목록
starship preset pastel-powerline -o ~/.config/starship.toml  # 프리셋 적용
```

### RTK — 토큰 최적화 프록시

```bash
rtk git status      # git 명령어 압축 출력 (59-80% 절감)
rtk gh pr list      # GitHub CLI 압축 출력 (26-87% 절감)
rtk cargo test      # 테스트 실패만 출력 (90%+ 절감)
rtk gain            # 누적 토큰 절감 통계
rtk gain --history  # 명령어별 절감 히스토리
```

### ruff — Python 린터/포매터

```bash
ruff check .         # 린팅
ruff check . --fix   # 자동 수정
ruff format .        # 포매팅
```

### jq / yq — 데이터 처리

```bash
cat data.json | jq '.users[].name'    # JSON 필드 추출
cat config.yaml | yq '.database.host' # YAML 필드 추출
yq -o=json config.yaml                # YAML → JSON 변환
```

### difftastic — AST 기반 diff

```bash
difft file1.js file2.js   # AST 기반 비교 (공백/포매팅 무시)
# git diff에서 자동 사용: GIT_EXTERNAL_DIFF=difft git diff
```

### atuin — 히스토리 강화

셸 히스토리를 SQLite DB로 관리. 검색 속도와 컨텍스트(작업 디렉토리, 종료 코드 등)가 향상됨.

```bash
# Ctrl+R 대신 atuin 검색 UI 사용 (자동 바인딩)
# 또는 직접 실행:
atuin search <키워드>
atuin stats          # 명령어 사용 통계
```

### ast-grep — AST 기반 코드 검색/리팩터

문자열이 아닌 코드 구조로 검색. `sg` 명령어로 실행.

```bash
sg -p 'console.log($A)' src/          # console.log 호출 검색
sg -p 'console.log($A)' -r 'logger.info($A)' src/  # 일괄 치환
sg -p 'useState($A)' -l ts            # TypeScript 파일에서 useState 검색
```

### httpie — HTTP 클라이언트

```bash
http GET https://api.example.com/users        # GET 요청
http POST https://api.example.com/users name=foo email=bar@example.com  # POST (JSON 자동)
http -a user:pass GET https://api.example.com # Basic Auth
https example.com                             # HTTPS 단축 명령
```

### .inputrc — Readline 설정

`~/.inputrc`에 정의된 터미널 입력 개선 설정. bash 시작 시 자동 적용.

| 기능 | 동작 |
|------|------|
| 자동완성 대소문자 무시 | `cd doc` → `Documents` 매칭 |
| 히스토리 prefix 검색 | `git` 입력 후 `↑/↓` → git 명령어만 탐색 |
| Tab 한 번에 목록 표시 | 두 번 누를 필요 없음 |
| 컬러 자동완성 | 파일 타입별 색상 표시 |

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
| Linux/Ubuntu | `curl -fsSL https://bun.sh/install \| bash` (install.sh 자동) |
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

> **Windows vs macOS/Linux:**
> `settings.json`의 MCP 명령은 Windows 전용(`cmd /c npx ...`)으로 저장되어 있다.
> macOS/Linux에서는 `agents/setup.sh`가 설치 시 자동으로 `npx` 형식으로 패치하므로 수동 수정 불필요.

### ccstatusline

터미널 상태 표시줄에 Claude Code 세션 정보를 표시.
`agents/setup.sh`가 실행 설정(settings.json)과 레이아웃 설정 모두 자동 링크함.
별도 설치 불필요 (npx로 자동 실행).

| 파일 | 링크 위치 | 내용 |
|------|-----------|------|
| `agents/claude/ccstatusline-settings.json` | `~/.config/ccstatusline/settings.json` | 레이아웃 설정 |

현재 레이아웃:
- 1줄: `model | thinking-effort | git-branch | git-worktree | git-changes`
- 2줄: `tokens-output | tokens-cached | tokens-total | context-length | context-percentage-usable`
- 3줄: `context-bar | session-cost | session-clock`

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
    .bashrc                   # 셸 초기화 (starship/zoxide/fzf/atuin init 포함)
    .bash_profile             # 로그인 셸
    .aliases                  # 명령어 단축키 (eza, bat, git 단축 등)
    .exports                  # 환경변수 (PATH, EDITOR, HISTSIZE 등)
    .functions                # 셸 유틸리티 함수 (mkcd, up, extract, WSL 연동)
    .inputrc                  # Readline 설정 (자동완성, 히스토리 검색)
    .gitconfig                # git 전역 설정 (공유)
    .gitconfig.local.example  # 머신별 설정 템플릿
    .extra.example            # 머신별 개인 설정 템플릿 (git 제외)
    .gitignore_global         # 전역 gitignore
  config/
    starship.toml             # Starship prompt 기본 설정 → ~/.config/starship.toml
  tools/
    fnm.sh                    # fnm 설치
    node.sh                   # Node LTS + Claude Code 설치
    bun.sh                    # bun 설치 (OS별 분기)
    global-packages.sh        # npm 전역 패키지 설치
    global-packages.txt       # 전역 패키지 목록 (gemini-cli, codex 등)
    rtk.sh                    # RTK 설치 및 hook 등록
  linux/
    packages.sh               # apt 패키지 (카카오 미러)
    install-extras.sh         # apt 미지원 도구 바이너리 설치
                              # (zoxide, starship, ruff, atuin, lazygit,
                              #  yazi, difftastic, ast-grep, yq 등)
  macos/
    install.sh                # Homebrew + Brewfile (--with-defaults 플래그로 .macos도 실행)
    Brewfile                  # macOS 패키지 목록
    .macos                    # macOS 시스템 설정 자동화 (Dock, Finder, 키보드 등)
  windows/
    install.ps1               # winget 패키지 설치 + RTK 바이너리 다운로드
    agents-setup.ps1          # Claude Code 설정 자동 복사 + $PROFILE 관리
    profile.ps1               # PowerShell $PROFILE에 추가할 설정
    .wslconfig                # WSL2 전역 설정 템플릿
  agents/
    setup.sh                  # Claude 설정 링크 + 에이전트 설치
    restore-agents.sh         # The Agency 재설치
    restore-skills.sh         # npx skills 재설치
    skills-manifest.txt       # 설치할 skills 목록
    claude/
      CLAUDE.md               # Claude 전역 행동 설정 (RTK 규칙, 도구 사용 규칙 포함)
      settings.json           # Claude Code 설정 (플러그인, MCP, hook, statusLine)
      ccstatusline-settings.json  # ccstatusline 레이아웃 설정
```

