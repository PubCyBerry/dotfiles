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

## 데이터 처리

### jq / yq

```bash
cat data.json | jq '.users[].name'    # JSON 필드 추출
cat config.yaml | yq '.database.host' # YAML 필드 추출
yq -o=json config.yaml                # YAML → JSON 변환
```

### httpie — HTTP 클라이언트 (선택적 설치)

> winget.txt에 주석 처리되어 있다. 필요 시 주석 해제 후 `install.ps1` 재실행.

```bash
http GET https://api.example.com/users        # GET 요청
http POST https://api.example.com/users name=foo email=bar@example.com  # POST (JSON 자동)
http -a user:pass GET https://api.example.com # Basic Auth
https example.com                             # HTTPS 단축 명령
```

## 코드 품질

### ruff — Python 린터/포매터 (선택적 설치)

> winget.txt에 주석 처리되어 있다. 필요 시 주석 해제 후 `install.ps1` 재실행.

```bash
ruff check .         # 린팅
ruff check . --fix   # 자동 수정
ruff format .        # 포매팅
```

### RTK — 토큰 최적화 프록시

```bash
rtk git status      # git 명령어 압축 출력 (59-80% 절감)
rtk gh pr list      # GitHub CLI 압축 출력 (26-87% 절감)
rtk cargo test      # 테스트 실패만 출력 (90%+ 절감)
rtk gain            # 누적 토큰 절감 통계
rtk gain --history  # 명령어별 절감 히스토리
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
| Linux | 수동 설치 (`curl -fsSL https://bun.sh/install | bash`) |
| Windows | `winget install Oven-sh.Bun` |

## 셸 설정

### .inputrc — Readline 설정

`~/.inputrc`에 정의된 터미널 입력 개선 설정. bash 시작 시 자동 적용.

| 기능 | 동작 |
|------|------|
| 자동완성 대소문자 무시 | `cd doc` → `Documents` 매칭 |
| 히스토리 prefix 검색 | `git` 입력 후 `↑/↓` → git 명령어만 탐색 |
| 컬러 자동완성 | 파일 타입별 색상 표시 |
