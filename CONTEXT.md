# CONTEXT.md

이 파일은 완료된 작업 인계가 아니라 저장소의 장기 도메인 용어만 설명한다.

## Agent role

- **role source**: `config/agents/roles/<name>/`의 공용 `body.md`와 플랫폼별 메타 파일.
- **assembled role**: installer가 role source를 조립해 배포한 Claude Markdown 또는 Codex TOML subagent.
- **agent validator**: source를 assembled role과 같은 형태로 조립한 뒤 Claude YAML과 Codex TOML을 검사하는 공용 검증 경로.

## 설정 병합

- **registry merge**: dotfiles가 등록하는 배열 항목은 관리 identity로 갱신하고, 사용자 항목은 보존하는 JSON 병합 방식.
- **default merge**: dotfiles 기본값은 destination에 키가 없을 때만 채우는 TOML 병합 방식.
