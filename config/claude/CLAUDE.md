# Global Claude Configuration

<!-- 모든 프로젝트에 적용되는 전역 설정 -->

## 도구 사용 규칙

### 파일 시스템
- `find` → **`fd`**
- `grep` → **`rg`** (ripgrep)
- `cat` → **`bat`**
- `ls` → **`eza`**
- `cd` → **`z`** (zoxide)
- 코드 구조 검색/리팩터 → **`sg`** (ast-grep)

### 데이터 처리
- JSON → **`jq`** 파이프라인
- YAML/TOML → **`yq`**
- HTTP 요청 → **`httpie`** (`http`/`https` 명령어)

### 코드 품질
- Python 린팅/포매팅 → **`ruff`** (flake8+black+isort 대체)
- AST diff → **`difft`** (difftastic)

### GitHub 작업
- 모든 GitHub 작업 → **`gh`**
- 비대화형 플래그 명시: `--json`, `--yes`, `--quiet`

### 범용 규칙
- 외부 CLI는 비대화형 모드 (`--yes`, `--quiet`, `--no-interactive`)
- JSON 출력 지원 CLI는 `--json` 플래그 우선
