# 보안 정책

개인 dotfiles 저장소의 보안 정책이다. 취약점을 알리는 방법과, 저장소에 넣지 않을 것, 믿을 외부 코드, 권한 설정의 기준을 정한다.

## 지원 범위

`main` 브랜치의 최신 상태만 지원한다. 릴리스와 버전은 따로 두지 않는다.

## 취약점 보고

취약점은 공개 이슈에 쓰지 않는다. 저장소의 Security 탭에서 Report a vulnerability로 비공개로 알린다.

## 비밀 정보

- 토큰, API 키, 비밀번호, 개인 키를 커밋하지 않는다. `config/`의 설정 파일은 모든 머신에 그대로 배포되므로 여기에도 넣지 않는다.
- 머신마다 다른 비밀 정보는 저장소 밖(홈 디렉터리의 파일, 환경 변수, OS 자격 증명 저장소)에 둔다.
- `.gitignore`에서 비밀 정보 파일을 막는 패턴을 지우지 않는다.
- 비밀 정보를 커밋했으면 git 기록에서 지우는 것으로 끝내지 않는다. push한 뒤라면 이미 복제됐을 수 있으므로 그 값을 바로 폐기하고 새로 발급한다.

## 외부 코드

install은 버전을 고정하지 않고 실행할 때마다 최신을 받는다([ADR 0005](docs/architecture/adr/0005-keep-installers-thin.md)). 따라서 어떤 출처를 넣을지 고르는 단계에서 위험을 걸러야 한다.

| 출처 | 위치 | 믿는 근거 |
|---|---|---|
| OS 패키지 매니저 | `manifests/`의 OS별 패키지 목록 | 카탈로그 관리 주체의 검토 |
| 공식 installer와 각 도구의 `update` 명령 | install 스크립트의 공식 installer 단계 | 제작자 도메인의 HTTPS URL, 제작자가 만든 update 명령 |
| GitHub 최신 릴리스 | `manifests/github-releases.tsv` | 제작자 저장소 |
| npm 패키지 | `manifests/npm-global.txt` | 제작자 계정 |
| skill, Claude Code 플러그인 | `manifests/skills.txt`, `manifests/plugins.txt` | 저장소 소유자 |

새 항목을 넣기 전에 다음을 확인하고, 확인한 결과를 PR 본문에 쓴다.

1. 저장소나 패키지의 소유자가 도구의 제작자다. 포크나 이름이 비슷한 저장소가 아니다.
2. 최근까지 관리되고 있다. 마지막 커밋과 릴리스 날짜를 본다.
3. 설치하거나 실행할 때 돌아가는 코드를 읽었다. install 스크립트, npm `postinstall`, 플러그인의 hook과 MCP 서버 설정이 대상이다. 플러그인 hook은 에이전트 이벤트마다 명령을 실행할 수 있다.
4. 공식 installer URL은 제작자 도메인의 HTTPS 주소다.

## 권한과 정책

- 에이전트의 권한과 샌드박스를 넓히는 변경은 사용자가 요청한 경우에만 한다. `config/claude/settings.json`의 `permissions`와 `skipDangerousModePermissionPrompt`, `config/codex/config.toml`의 `sandbox`가 대상이다.
- OS 보안 정책을 완화해서 문제를 우회하지 않는다. Windows SSH 세션의 심볼릭 링크 문제는 `fsutil behavior set SymlinkEvaluation`이 아니라 실제 경로를 PATH에 넣어 해결한다([이슈 #13](https://github.com/PubCyBerry/dotfiles/issues/13)).
- PowerShell 실행 정책은 실행할 때 `-ExecutionPolicy Bypass`로만 넘기고, 시스템 정책을 바꾸지 않는다.
