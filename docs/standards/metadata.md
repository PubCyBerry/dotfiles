---
type: Standard
title: 문서 메타데이터
description: docs/ 문서의 YAML front matter, 파일 이름과 위치, 색인을 OKF v0.2에 맞춰 쓰는 규칙을 정한다.
scope:
  - "**/*.md"
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format (OKF) v0.2
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-06T23:01:34+09:00 }
---

# 문서 메타데이터

`docs/` 아래 문서의 front matter, 파일 이름과 위치, 색인을 정한다. 기본은 OKF v0.2를 따르고[^okf-spec], 이 문서에는 이 저장소가 고른 필드와 추가한 규칙만 쓴다. 결정 배경은 [ADR 0002](../architecture/adr/0002-manage-docs-as-okf-bundle.md)에 있다.

## 대상

- `docs/`가 OKF bundle이다. `docs/` 아래의 `.md` 파일은 OKF 예약 파일(`index.md`, `log.md`)을 빼고 모두 front matter를 가진다.
- [파일 이름과 위치](#파일-이름과-위치)에 정한 저장소 루트 문서는 bundle 밖에 있으므로 front matter를 두지 않는다. GitHub는 README와 SECURITY를 관례 이름으로 인식해 front matter를 표로 그려 보이고, `AGENTS.md`는 에이전트가 매번 읽는 진입점이라 짧게 유지한다.
- `.github/`의 이슈 템플릿과 PR 템플릿은 GitHub가 정한 형식을 따르므로 OKF front matter를 넣지 않는다.
- `config/` 아래의 `.md`는 문서가 아니라 배포되는 설정이다. 전역 지침 원본에 front matter를 넣으면 모든 에이전트의 지침에 그대로 들어가므로 넣지 않는다.

## 필드

| 키 | 필수 여부 | 값 |
|---|---|---|
| `type` | 필수 | [type 값](#type-값) 표의 값 중 하나 |
| `title` | 필수 | 한국어 제목. 본문 H1과 같다 |
| `description` | 필수 | 문서를 요약하는 한 문장. `docs/index.md` 항목에 그대로 쓴다 |
| `scope` | `Standard`는 필수, 나머지는 선택 | 이 문서를 읽어야 하는 저장소 경로의 glob 목록 |
| `status` | 선택 | `draft` 또는 `deprecated`. 생략하면 `stable`이다 |
| `stale_after` | 선택 | 내용이 낡는 시점 |
| `generated` | 에이전트가 쓰거나 고친 문서는 필수 | `{ by: <actor>, at: <시각> }` |
| `verified` | 사람만 추가한다 | `{ by: human:<id>, at: <시각> }` 또는 그 목록 |
| `sources` | 외부 자료에서 가져온 내용이 있으면 필수 | `id`, `resource`, `title`을 가진 항목 목록 |

이 표에 없는 OKF 필드는 쓰지 않는다. 문서 분류는 `type`과 디렉터리로, 적용 범위는 `scope`로 나타낸다. ADR에만 쓰는 키는 [ADR 작성 규칙](adr.md)에 있다.

## type 값

OKF는 `type` 값을 정해 두지 않는다. 에이전트마다 다른 값을 만들지 않도록 이 저장소에서 쓰는 값을 아래로 제한한다. 새 값이 필요하면 이 표에 먼저 추가한다.

| 값 | 내용 | 위치 |
|---|---|---|
| `Standard` | 지켜야 하는 규칙 | `docs/standards/` |
| `Decision` | 설계 결정과 그 이유(ADR) | `docs/architecture/adr/` |
| `Playbook` | 순서대로 따라 하는 절차. 운영 문제 기록은 문서가 아니라 [이슈](issues.md)로 남긴다 | `docs/` |
| `Reference` | 동작 설명, 사실 기록 | `docs/` |

## scope

- 저장소 루트 기준 glob으로 쓴다. `**`는 여러 단계의 디렉터리와 일치한다(`config/claude/**`).
- 값은 큰따옴표로 감싼다. YAML은 `*`로 시작하는 값을 alias로 해석한다.
- 모든 변경에 적용되는 문서는 `"**"` 하나만 쓴다.
- 에이전트는 고칠 파일 경로를 각 문서의 `scope`와 비교해 읽을 문서를 고른다. `grep -A8 '^scope:' docs/standards/*.md`로 모든 `scope`를 한 번에 볼 수 있다.

## status와 stale_after

- `draft`는 아직 적용하지 않는 초안이다. 에이전트는 `draft` 문서의 규칙을 따르지 않아도 되고, 리뷰 근거로 쓰지 않는다. 사용자가 `status: draft`를 지우면 적용된다.
- `deprecated`는 ADR에만 쓴다. 다른 문서는 쓰지 않게 되면 지운다. 지운 내용은 git 기록에 남는다.
- `stale_after`는 기한이 정해진 임시 문서에만 쓴다. 현재 시각이 그 값을 지났으면 에이전트는 문서를 따르기 전에 아직 유효한지 사용자에게 확인한다.

## generated와 verified

- actor는 OKF 표기를 따른다. 에이전트는 `<에이전트>/<모델 ID>`(예: `claude-code/claude-opus-5-5`)로, 사람은 `human:<GitHub 사용자 이름>`으로 쓴다.
- 에이전트가 문서를 만들거나 규칙이나 사실을 바꾸면 `generated`를 자신과 현재 시각으로 바꾼다. 오탈자, 링크, 서식만 고쳤으면 그대로 둔다.
- 시각은 [표기](writing-style.md#표기)에 정한 형식으로 쓴다. 현재 시각은 시각 주입 hook이 대화에 넣어 준 값이나 `date` 명령으로 확인한다.
- `verified`는 사람이 내용을 검토한 뒤 직접 추가한다. 에이전트는 `verified`를 추가하거나 고치지 않는다.
- `verified`가 없거나 가장 최근 `verified`의 `at`이 `generated.at`보다 이르면, 그 문서에는 사람이 검토하지 않은 내용이 있다. 이런 문서를 다루는 방법은 [문서와 코드가 다를 때](agent-workflow.md#문서와-코드가-다를-때)에 있다.

## sources

- 외부 문서(규격, 공식 문서)에서 가져온 내용이 있으면 `sources`에 `id`, `resource`, `title`을 적는다.
- 본문에서는 `id`를 라벨로 쓰는 각주로 출처를 단다(`...따른다.[^okf-spec]`). 목록의 순서 번호가 아니라 `id`로 연결하므로 목록 순서가 바뀌어도 출처가 어긋나지 않는다.

## 파일 이름과 위치

- `docs/` 아래 파일 이름은 소문자 ASCII kebab-case로 쓴다(`cross-platform.md`). 한글 파일 이름은 셸 인용과 URL 인코딩이 필요해 쓰지 않는다.
- OKF 예약 파일 이름은 일반 문서 이름으로 쓰지 않는다. 변경 기록은 `log.md` 대신 git 기록으로 남긴다.
- 문서 위치는 [type 값](#type-값) 표를 따른다.
- 저장소 루트에는 `README.md`, `AGENTS.md`, `ARCHITECTURE.md`, `INSTALL.md`, `SECURITY.md`만 문서로 둔다. `CLAUDE.md`와 `GEMINI.md`는 만들지 않는다. 다른 도구가 이 파일을 만들었으면 내용을 `AGENTS.md`나 `docs/standards/`로 옮기고 지운다. 이유는 [ADR 0003](../architecture/adr/0003-agents-md-as-single-entry-point.md)에 있다.

## 색인

- `docs/index.md`는 OKF 색인 형식을 따른다. front matter에는 `okf_version`만 두고, 본문은 `#` 절 아래에 `* [title](경로) - description` 항목을 나열한다.
- 문서를 추가하거나 지우거나 `title`이나 `description`을 바꾸면 같은 변경에서 `docs/index.md`도 고친다.
- 새 `Standard`를 추가하면 `AGENTS.md`의 [작업별 문서](../../AGENTS.md#작업별-문서) 표에도 넣는다.

## 예시

```yaml
---
type: Standard
title: 설치 스크립트
description: install.ps1과 install.sh의 범위, 단계 구성, 실패 처리, 배포 방식 선택 규칙을 정한다.
scope:
  - "install.ps1"
  - "install.sh"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---
```

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| 문서 추가나 삭제, `title`이나 `description` 변경 | `docs/index.md` |
| `Standard` 추가나 삭제 | `AGENTS.md`의 작업별 문서 표 |
| `type` 값 추가 | 이 문서의 [type 값](#type-값) 표 |

## 검사

자동 검사는 없다. 리뷰에서 front matter와 `docs/index.md` 항목이 맞는지 확인한다.

[^okf-spec]: Open Knowledge Format (OKF) v0.2
