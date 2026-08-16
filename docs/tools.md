# 도구 사용법

dotfiles가 설치하는 CLI 도구 cheatsheet.

## 파일 & 탐색

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

### fd — 빠른 find 대체

```bash
fd                    # 현재 디렉토리의 모든 파일
fd pattern            # 이름에 pattern이 포함된 파일
fd -e js              # .js 확장자 파일만
fd -t d               # 디렉토리만
fd pattern src/       # src/ 안에서 검색
fd --hidden           # 숨김 파일 포함
```

### yazi — TUI 파일 매니저

```bash
yazi           # 현재 디렉토리에서 실행
```

`hjkl`로 탐색, `Enter`로 열기, `y`로 복사, `d`로 삭제.

## 검색

### fzf — 퍼지 파인더

```bash
fzf                   # 파일 검색
cat $(fzf)            # fzf로 파일 선택 후 cat
code $(fzf)           # fzf로 파일 선택 후 VS Code로 열기
```

터미널에서 `Ctrl+R` 입력 시 fzf로 인터랙티브 히스토리 검색.

### rg (ripgrep) — 빠른 grep 대체

```bash
rg "검색어"            # 현재 디렉토리 재귀 검색
rg "검색어" src/       # 특정 디렉토리에서 검색
rg -t js "검색어"      # .js 파일만 검색
rg -l "검색어"         # 파일명만 출력
rg -i "검색어"         # 대소문자 무시
rg --no-ignore "검색어" # .gitignore 무시하고 검색
```

### ast-grep — AST 기반 코드 검색/리팩터 (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 필요 시 직접 설치: `winget install ast-grep.ast-grep`

문자열이 아닌 코드 구조로 검색. `sg` 명령어로 실행.

```bash
sg -p 'console.log($A)' src/          # console.log 호출 검색
sg -p 'console.log($A)' -r 'logger.info($A)' src/  # 일괄 치환
sg -p 'useState($A)' -l ts            # TypeScript 파일에서 useState 검색
```

### mgrep — 시맨틱 코드 검색 (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 별도 API 키가 필요하다. 필요 시 직접 설치: `npm install -g @mixedbread-ai/mgrep`

텍스트 매칭이 아닌 의미(semantic) 기반으로 코드·문서·이미지·PDF를 검색한다.

```bash
mgrep "인증 처리 로직"    # 의미적으로 관련된 코드 검색
mgrep "error handling" src/
```

## Git

### delta — git diff 뷰어

`git diff`, `git show`, `git log -p` 실행 시 자동으로 delta가 적용된다.

```bash
git diff              # delta로 예쁘게 표시
git show HEAD         # 마지막 커밋 diff
git log -p            # 전체 히스토리 diff
delta file1 file2     # delta 직접 실행
```

### lazygit — TUI git 클라이언트

```bash
lazygit        # 현재 저장소에서 실행
```

`space`로 스테이징, `c`로 커밋, `P`로 푸시. `?`로 단축키 목록.

### difftastic — AST 기반 diff (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 필요 시 직접 설치: `winget install Wilfred.difftastic`

```bash
difft file1.js file2.js   # AST 기반 비교 (공백/포매팅 무시)
GIT_EXTERNAL_DIFF=difft git diff  # git diff에서 사용
```

## 셸 환경

### zoxide — 스마트 cd

```bash
z foo          # 'foo'가 포함된 자주 간 디렉토리로 이동
z foo bar      # 'foo'와 'bar' 모두 포함된 경로로 이동
zi             # fzf로 히스토리 대화형 선택
```

### starship — 셸 프롬프트

`~/.config/starship.toml`로 커스터마이징. 기본값으로 git 브랜치/상태, 언어 버전 자동 표시.

```bash
starship preset --list          # 프리셋 목록
starship preset pastel-powerline -o ~/.config/starship.toml  # 프리셋 적용
```

### atuin — 히스토리 강화 (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 필요 시 직접 설치: `winget install atuinsh.atuin`

셸 히스토리를 SQLite DB로 관리. 검색 속도와 컨텍스트(작업 디렉토리, 종료 코드 등)가 향상됨.

```bash
atuin search <키워드>   # 히스토리 검색
atuin stats            # 명령어 사용 통계
```

`Ctrl+R` 입력 시 atuin 검색 UI 자동 바인딩.

### navi — 대화형 cheatsheet (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 필요 시 직접 설치: `winget install denisidoro.navi`

명령어와 설명을 인터랙티브하게 탐색하고 실행한다.

```bash
navi                  # 전체 cheatsheet 탐색
navi --query git      # git 관련 항목 검색
navi --print          # 명령어만 출력 (실행 안 함, 클립보드 확인용)
```

### tmux — 터미널 멀티플렉서

```bash
tmux                    # 새 세션 시작
tmux new -s dev         # 이름 있는 세션 시작
tmux ls                 # 세션 목록
tmux attach -t dev      # 세션 복원
```

주요 단축키 (prefix: `Ctrl+B`): `c` 새 창, `d` 분리, `%` 수직 분할, `"` 수평 분할.

| OS | 설치 방법 |
|----|-----------|
| Ubuntu | apt 자동 (`manifests/apt.txt`) |
| Windows (네이티브) | `winget install psmux` (tmux 대체) |

### herdr — 코딩 에이전트용 터미널 멀티플렉서

workspace / tab / pane 위에 pane 안에서 도는 코딩 에이전트를 인식하는 레이어를 얹는다. `herdr` CLI로 세션을 조작할 수 있어 에이전트가 다른 에이전트를 띄우고 출력을 읽는 것도 된다.

```bash
herdr                              # 세션 시작 또는 attach
herdr status                       # 클라이언트/서버 상태
herdr pane list                    # pane 목록 (JSON)
herdr pane split --current --direction right --no-focus
herdr pane run <pane-id> "just test"
herdr pane read <pane-id> --source recent-unwrapped --lines 120
herdr agent list                   # 인식된 에이전트 목록
herdr update                       # 자체 업데이트
herdr channel set stable           # stable / preview 채널 전환
```

기본 단축키는 prefix(`Ctrl+B`) 기반: `v` 수직 분할, `-` 수평 분할, `x` pane 닫기, `z` zoom, `b` 사이드바. 이 저장소 설정은 여기에 `prefix+alt+p`(pwsh 7 pane, Windows 전용)를 더한다.

설정은 `%APPDATA%\herdr\config.toml`(Windows) / `~/.config/herdr/config.toml`(Linux·macOS). 이 저장소가 `config/herdr/`에서 default merge로 배포하며, 직접 고친 값은 다음 설치에서도 보존된다.

| OS | 설치 방법 |
|----|-----------|
| Ubuntu | `install.sh`가 공식 installer 실행 (이미 있으면 건너뜀) |
| macOS | Homebrew 자동 (`manifests/Brewfile`) |
| Windows | `install.ps1`이 공식 installer 실행 (이미 있으면 건너뜀) |

> Windows는 stable 릴리즈에 바이너리가 없어 preview 빌드가 설치된다. 버전 관리는 herdr 자체 업데이터가 맡으므로 이 저장소는 바이너리를 pin하지 않는다.

Windows pane이 Git Bash 대신 `cmd.exe`로 뜨면 `config.toml`에 `shell_mode`가 들어갔는지 본다 — herdr 0.8.0-preview는 Windows에서 `shell_mode = "login"`을 만나면 `default_shell`을 버리고 `cmd.exe`로 조용히 fallback한다.

## 데이터 처리

### jq / yq

```bash
cat data.json | jq '.users[].name'    # JSON 필드 추출
cat config.yaml | yq '.database.host' # YAML 필드 추출
yq -o=json config.yaml                # YAML → JSON 변환
```

### rhwp — HWP/HWPX 읽기·쓰기

install 스크립트가 `manifests/rhwp.tsv`의 pinned release를 `~/rhwp`(Windows `%USERPROFILE%\rhwp`)에 통째로 배치한다. PATH에는 넣지 않으므로 절대 경로로 부른다.

```bash
~/rhwp/rhwp --version                       # 설치된 버전 확인
~/rhwp/rhwp capabilities --mcp | jq '.tools[].name'   # 제공 도구 목록
```

MCP 서버(`rhwp mcp-serve`)는 install이 Codex(`~/.codex/config.toml`)와 Claude Code(`~/.claude.json`)에 같은 절대 경로로 등록한다. 등록 후에는 두 호스트를 재시작해야 도구가 보인다.

```bash
yq -p=toml -o=json '.mcp_servers.rhwp' ~/.codex/config.toml   # Codex 등록 확인
jq '.mcpServers.rhwp' ~/.claude.json                          # Claude Code 등록 확인
```

## 코드 품질

### ruff — Python 린터/포매터 (선택적 설치)

> winget.txt에 주석 처리되어 있다. 필요 시 주석 해제 후 `install.ps1` 재실행.

```bash
ruff check .         # 린팅
ruff check . --fix   # 자동 수정
ruff format .        # 포매팅
```

### hyperfine — 커맨드라인 벤치마킹 (선택적 설치)

> winget.txt에 포함되지 않아 자동 설치되지 않는다. 필요 시 직접 설치: `winget install sharkdp.hyperfine`

두 명령어의 실행 시간을 통계적으로 비교한다.

```bash
hyperfine 'sleep 0.3'                      # 단일 명령 벤치마크
hyperfine 'find . -name "*.md"' 'fd .md'   # 두 명령 비교
hyperfine --warmup 3 'rg pattern .'        # 워밍업 포함 (캐시 안정화)
hyperfine --export-markdown bench.md 'cmd' # 결과를 마크다운 테이블로 저장
```

## 런타임

### bun — JavaScript 런타임 & 패키지 매니저

Node.js 호환 런타임. npx보다 빠른 스크립트 실행과 패키지 관리에 사용.

```bash
bun --version      # 설치 확인
bunx <package>     # npx 대체
bun install        # npm install 대체 (빠름)
```

| OS | 설치 방법 |
|----|-----------|
| Linux | `install.sh` (`manifests/direct-artifacts.tsv` pin·SHA-256 검증) |
| Windows | `winget install Oven-sh.Bun` |

## 셸 설정

### .inputrc — Readline 설정

`~/.inputrc`에 정의된 터미널 입력 개선 설정. bash 시작 시 자동 적용.

| 기능 | 동작 |
|------|------|
| 자동완성 대소문자 무시 | `cd doc` → `Documents` 매칭 |
| 히스토리 prefix 검색 | `git` 입력 후 `↑/↓` → git 명령어만 탐색 |
| 컬러 자동완성 | 파일 타입별 색상 표시 |

## 유틸리티 스크립트 (Windows)

### clean-env.ps1 — 환경변수(PATH) 안전 점검 및 압축

Windows의 `sysdm.cpl`(시스템 속성 대화상자) 2,047자 제한 초과를 방지하기 위해 사용자/시스템 PATH를 점검·정리한다.

```powershell
# 미리보기 (Dry-Run)
pwsh scripts/clean-env.ps1

# 실제 적용 (.reg 자동 백업 후 적용 및 환경변수 브로드캐스트)
pwsh scripts/clean-env.ps1 -Apply
```

- 미존재(Dead) 경로 및 중복 경로 제거
- WinGet 포터블 패키지 경로를 `%WINGET_PKGS%` / `%LOCALAPPDATA%` / `%USERPROFILE%` 로 압축
- `REG_EXPAND_SZ` 형식 보존 및 끝 세미콜론 정리
