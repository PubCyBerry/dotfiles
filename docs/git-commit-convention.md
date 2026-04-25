# Git Commit Convention

[Conventional Commits](https://www.conventionalcommits.org/) 스펙을 기반으로 한 커밋 메시지 작성 규칙.

## 기본 포맷

```
<type>(<scope>): <subject>

[body]

[footer]
```

- **type**: 변경 성격 (필수)
- **scope**: 영향 범위, 괄호 포함 (선택)
- **subject**: 변경 내용 요약 (필수)
- **body**: 상세 설명 — what, why (선택)
- **footer**: Breaking change, 이슈 참조 (선택)

## Type 목록

| type | 용도 |
|------|------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `docs` | 문서만 변경 |
| `style` | 코드 스타일 변경 (로직 무관 — 공백, 세미콜론 등) |
| `refactor` | 기능 변경 없는 코드 구조 개선 |
| `perf` | 성능 개선 |
| `test` | 테스트 추가 또는 수정 |
| `chore` | 빌드, 설정, 의존성 변경 |
| `ci` | CI/CD 설정 변경 |
| `revert` | 이전 커밋 되돌리기 |
| `wip` | 작업 중 임시 저장 커밋 (머지 전 squash 필수) |

## 작성 규칙

### subject

- **50자 이내** 권장 (72자 초과 금지)
- **명령형** 동사로 시작: "추가", "수정", "제거" (과거형 금지)
- **마침표 없음**
- 첫 글자 대문자 불필요 (일관성 우선)

### body

- subject와 **빈 줄 하나**로 구분
- **72자**마다 줄바꿈
- **무엇을, 왜** 변경했는지 설명 (어떻게는 코드에서 드러남)

### footer

```
BREAKING CHANGE: <이전 동작과의 차이 설명>

Closes #123
```

> **주의:** `BREAKING CHANGE:`가 있으면 major 버전 증가에 해당한다. scope 뒤에 `!`를 붙여도 동일하게 표기할 수 있다 (`feat!: ...`).

## 이 저장소의 관행

### 언어

커밋 메시지는 `<type>: <한국어 설명>` 패턴을 사용한다.

```
feat: lazygit 패키지 활성화 및 README 레퍼런스 추가
fix: SSH 세션에서 WinGet 심볼릭 링크 탐색 실패 우회
docs: worktree Git 히스토리 관리 전략 문서 추가
refactor: delta.gitconfig → gitconfig 리네임 및 core 기본 설정 추가
```

### scope 사용

변경 범위가 뚜렷할 때만 scope를 붙인다.

```
feat(nvim): lazy.nvim Structured Setup 추가
fix(bash): Git Bash .inputrc 경로 수정
chore(deps): winget 패키지 목록 갱신
```

### wip 커밋 처리

`wip:` 커밋은 작업 도중 임시 저장 용도로만 사용한다. main에 합치기 전에 반드시 squash 또는 interactive rebase로 정리한다. 자세한 내용은 [worktree-git-workflows.md](worktree-git-workflows.md) 참조.

## 좋은 예 / 나쁜 예

### subject

| 나쁜 예 | 좋은 예 |
|---------|---------|
| `fixed bug` | `fix: 프로파일 로드 실패 시 기본값 사용` |
| `update` | `docs: uninstall 가이드 업데이트` |
| `WIP` | `wip: nvim 키맵 작업 중` |
| `feat: 새로운 기능을 추가하였습니다.` | `feat: yazi에서 nvim을 기본 에디터로 설정` |

### body가 필요한 경우

```
fix: SSH 세션에서 WinGet 심볼릭 링크 탐색 실패 우회

SSH로 접속한 세션은 WinGet이 심볼릭 링크를 통해
실행 파일을 탐색하지 못하는 버그가 있다.
절대 경로를 직접 지정하는 방식으로 우회한다.
```

## 커밋 단위 가이드

- **하나의 논리적 변경 = 하나의 커밋**: 파일 수가 아닌 의도 단위로 나눈다.
- 기능 추가와 버그 수정이 동시에 발생했다면 두 개로 분리한다.
- 리뷰어가 `git revert`로 변경을 되돌릴 수 있는 단위가 이상적이다.

**함께 묶을 수 있는 경우**
- 동일 기능을 위한 여러 파일 변경
- 문서와 그 문서가 설명하는 설정 파일 변경

**분리해야 하는 경우**
- 리팩터링 + 기능 추가 (각각 `refactor:`, `feat:`)
- 의존성 업데이트 + 코드 수정 (각각 `chore:`, `fix:`)
