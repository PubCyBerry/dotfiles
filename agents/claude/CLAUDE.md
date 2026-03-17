# Global Claude Configuration

<!-- 모든 프로젝트에 적용되는 전역 설정 -->

## Persona
- 한국어로 대화
- 간결하고 직접적인 응답 선호
- 불필요한 설명 생략

## Code Style
- 간결하고 읽기 쉬운 코드 우선
- 불필요한 주석 추가 금지
- 이모지 사용 금지 (명시적 요청 시 제외)

---

## RTK (Rust Token Killer) — 토큰 최적화

### 황금 규칙

**모든 명령어에 `rtk` 접두사를 붙인다.** RTK 전용 필터가 있으면 압축하고, 없으면 그대로 통과. 항상 안전하게 사용 가능.

`&&` 체인에서도 모든 명령어에 rtk 사용:
```bash
# ❌ 잘못된 예
git add . && git commit -m "msg" && git push

# ✅ 올바른 예
rtk git add . && rtk git commit -m "msg" && rtk git push
```

### 워크플로우별 명령어

| 카테고리 | 명령어 | 절감율 |
|----------|--------|--------|
| **Git** | `rtk git status/log/diff/add/commit/push/pull/branch` | 59-80% |
| **GitHub** | `rtk gh pr/issue/run list/view` | 26-87% |
| **테스트** | `rtk cargo test`, `rtk vitest run`, `rtk playwright test` | 90-99% |
| **빌드** | `rtk cargo build/check/clippy`, `rtk tsc`, `rtk next build` | 70-87% |
| **패키지** | `rtk pnpm/npm install/list`, `rtk npx` | 70-90% |
| **Docker** | `rtk docker ps/images/logs` | 85% |
| **파일** | `rtk ls`, `rtk grep`, `rtk find`, `rtk diff` | 60-75% |
| **분석** | `rtk err <cmd>`, `rtk log <file>`, `rtk summary <cmd>` | 70-90% |

> rg/fd/eza/bat/ast-grep은 이미 간결한 출력 → RTK 불필요, 직접 사용.

---

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
- 모든 GitHub 작업 → **`rtk gh`**
- 비대화형 플래그 명시: `--json`, `--yes`, `--quiet`

### 범용 규칙
- 외부 CLI는 비대화형 모드 (`--yes`, `--quiet`, `--no-interactive`)
- JSON 출력 지원 CLI는 `--json` 플래그 우선
- RTK 미설치 환경에서는 RTK 관련 규칙 무시, 원본 명령어 사용
