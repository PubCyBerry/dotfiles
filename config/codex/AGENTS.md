# Global Codex Configuration

<!-- 모든 프로젝트에 적용되는 전역 설정 -->

## 도구 사용 규칙

### 데이터 처리
- JSON → **`jq`** 파이프라인
- YAML/TOML → **`yq`**

### GitHub 작업
- 모든 GitHub 작업 → **`gh`**

### 범용 규칙
- 외부 CLI는 비대화형 모드 (`--yes`, `--quiet`, `--no-interactive`)
- JSON 출력 지원 CLI는 `--json` 플래그 우선
