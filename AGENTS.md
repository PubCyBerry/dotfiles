# AGENTS.md

개인 dotfiles 저장소다. 이 파일은 이 저장소에서 작업하는 모든 에이전트가 읽는 진입점이며, 작업에 맞는 문서를 찾는 색인만 둔다. 규칙과 설명은 아래 문서에 있다.

## 먼저 읽을 문서

파일을 바꾸는 작업이면 시작하기 전에 읽는다.

- [에이전트 작업 절차](docs/standards/agent-workflow.md): 작업 순서, 사용자 확인이 필요한 행동, 검증, 보고
- [글쓰기 규칙](docs/standards/writing-style.md): 문서, 주석, 커밋 메시지의 언어와 문체
- [ARCHITECTURE.md](ARCHITECTURE.md): 저장소 구조, 설치 단계, 배포 방식

## 작업별 문서

| 작업 | 읽을 문서 |
|---|---|
| 이 머신에 dotfiles 설치 | [INSTALL.md](INSTALL.md) |
| 매니페스트에 도구 추가나 삭제 | [패키지 매니페스트](docs/standards/manifests.md), [플랫폼 동등성](docs/standards/cross-platform.md), [SECURITY.md](SECURITY.md) |
| install 스크립트 수정 | [설치 스크립트](docs/standards/installer.md), [스크립트 작성](docs/standards/scripts.md), [플랫폼 동등성](docs/standards/cross-platform.md) |
| 셸 스크립트, 셸 프로파일 수정 | [스크립트 작성](docs/standards/scripts.md), [플랫폼 동등성](docs/standards/cross-platform.md) |
| 에이전트 설정, hook, skill, 플러그인 | [에이전트 설정](docs/standards/agent-config.md), [SECURITY.md](SECURITY.md) |
| 문서 추가나 수정 | [문서 메타데이터](docs/standards/metadata.md) |
| 설계 결정 기록 | [ADR 작성 규칙](docs/standards/adr.md) |
| 커밋, 브랜치, PR | [커밋 규칙](docs/standards/commit-convention.md) |
| 오류나 이상 동작 조사, 이슈 작성과 triage | [이슈 규칙](docs/standards/issues.md) |

표에 없는 파일을 고칠 때는 `grep -A8 '^scope:' docs/standards/*.md`로 각 문서의 `scope`를 보고, 고칠 파일이 들어 있는 문서를 읽는다. 결정 기록(ADR)을 포함한 전체 문서 목록은 [docs/index.md](docs/index.md)에 있다.
