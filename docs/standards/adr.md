---
type: Standard
title: ADR 작성 규칙
description: 설계 결정을 MADR 4 양식의 ADR로 docs/architecture/adr/에 남기는 기준과 양식을 정한다.
scope:
  - "docs/architecture/adr/**"
sources:
  - id: madr-template
    resource: https://github.com/adr/madr/blob/develop/template/adr-template.md
    title: MADR adr-template.md
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# ADR 작성 규칙

설계 결정과 그 이유를 ADR(Architectural Decision Record)로 남기는 기준과 양식을 정한다. 양식은 MADR 4 템플릿을 한국어로 옮긴 것이다.[^madr-template] MADR을 고른 배경은 [ADR 0001](../architecture/adr/0001-record-decisions-in-madr.md)에 있다.

## 언제 쓰는가

다음 중 하나에 해당하면 ADR을 쓴다.

- 되돌리기 어렵거나 여러 파일과 문서에 영향을 주는 결정
- 일부러 하지 않기로 한 결정. 에이전트가 개선이라고 여겨 다시 도입할 수 있는 것(버전 고정, 백업, uninstall)
- 여러 선택지를 비교해 고른 결정

규칙 문서는 무엇을 지키는지를, ADR은 왜 그렇게 정했는지를 쓴다. 규칙 문서에서 이유가 길어지면 ADR로 옮기고 링크한다.

## 파일

- 위치는 `docs/architecture/adr/`이다.
- 이름은 `NNNN-<영문-kebab-case-제목>.md`로 쓴다. `NNNN`은 0001부터 시작하는 네 자리 일련번호이며, 지운 번호도 다시 쓰지 않는다.
- 새 ADR을 추가하면 `docs/index.md`의 결정 기록 절에 항목을 넣는다.

## front matter

[문서 메타데이터](metadata.md)의 규칙에 아래 키를 더한다. MADR의 `consulted`와 `informed`는 쓰지 않는다.

| 키 | 값 |
|---|---|
| `type` | `Decision` |
| `title` | 결정을 한 문장으로 쓴 제목. 본문 H1과 같다 |
| `date` | 결정을 마지막으로 바꾼 날짜(`YYYY-MM-DD`) |
| `decision-makers` | 결정한 사람의 actor 목록 |
| `superseded_by` | 대체됐을 때만 쓴다. 대체한 ADR의 파일 이름 |

MADR의 `status` 값은 OKF의 `status`로 바꿔 쓴다. OKF를 읽는 쪽은 `status`를 문서 수명으로 해석하기 때문이다.

| MADR | 이 저장소 |
|---|---|
| proposed | `status: draft` |
| accepted | `status`를 쓰지 않는다(`stable`) |
| deprecated | `status: deprecated` |
| superseded by ADR-NNNN | `status: deprecated`와 `superseded_by` |
| rejected | 쓰지 않는다. 하지 않기로 한 결정은 "X를 하지 않는다"는 제목의 ADR로 쓴다 |

## 상태와 수정

- 에이전트가 새 결정을 제안할 때는 `status: draft`로 쓴다. `draft`를 지워 결정을 확정하는 것은 사용자가 한다.
- 사용자가 이미 내린 결정을 기록할 때는 `draft` 없이 쓰고, `decision-makers`에 결정한 사람을 쓴다.
- 확정된 ADR의 본문은 고치지 않는다. 결정이 바뀌면 새 ADR을 쓰고, 이전 ADR에는 `status: deprecated`와 `superseded_by`만 추가한다. 오탈자와 깨진 링크는 고쳐도 된다.

## 양식

판단 기준, 결과, 확인 방법, 선택지별 장단점, 추가 정보는 MADR처럼 선택 절이다. 쓸 내용이 없으면 절을 지운다.

```markdown
---
type: Decision
title: {문제와 해법을 담은 짧은 제목}
description: {결정을 요약하는 한 문장}
date: {YYYY-MM-DD}
decision-makers: [human:{GitHub 사용자 이름}]
generated: { by: {actor}, at: {시각} }
---

# {title과 같은 제목}

## 맥락과 문제

{상황과 문제를 두세 문장으로 쓴다. 질문 형태로 써도 된다. 결정이 미치는 범위(파일, 디렉터리, 도구)를 밝힌다.}

## 판단 기준

- {원하는 품질, 제약, 우려}

## 검토한 선택지

- {선택지 1}
- {선택지 2}

## 결정

"{선택지 1}"을 선택한다. {판단 기준을 어떻게 충족하는지 쓴다.}

### 결과

- 장점: {좋아지는 점}
- 단점: {나빠지는 점, 감수하는 비용}

### 확인 방법

{결정을 지키는지 확인하는 방법. CI 검사, 실제 실행, 리뷰 항목}

## 선택지별 장단점

### {선택지 1}

- 장점: {근거}
- 중립: {근거}
- 단점: {근거}

### {선택지 2}

- 장점: {근거}
- 단점: {근거}

## 추가 정보

{관련 PR, 다른 ADR, 다시 검토할 조건}
```

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| ADR 추가 | `docs/index.md`의 결정 기록 절, 이유를 링크할 규칙 문서 |
| ADR 대체 | 이전 ADR의 `status`와 `superseded_by`, 이전 ADR을 링크하던 문서 |

## 검사

자동 검사는 없다. 리뷰에서 확인한다.

[^madr-template]: MADR adr-template.md
