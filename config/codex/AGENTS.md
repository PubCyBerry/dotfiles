# Global Agent Configuration

## 언어 및 문서
- 답변 언어: 한국어 (기술 용어·코드·고유명사는 원어 유지)
- Markdown 문서(README 등): 한국어로 작성

## 실행 환경
- 현재 날짜: 세션 시작 시 `date` 명령으로 확인

## 도구 사용 규칙

### 데이터 처리
- JSON → `jq` 파이프라인
- YAML/TOML → `yq`

### GitHub 작업
- 모든 GitHub 작업 → `gh`

### 범용 규칙
- 외부 CLI: 비대화형 모드 (`--yes`, `--quiet`, `--no-interactive`)
- JSON 출력 지원 CLI: `--json` 플래그 우선
- CLI 명령어 안내: Windows → Git Bash, Linux → Bash
