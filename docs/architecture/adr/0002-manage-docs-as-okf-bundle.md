---
type: Decision
title: docs/를 OKF v0.2 bundle로 관리한다
description: docs/ 아래 문서에 OKF v0.2 front matter를 붙이고 docs/index.md를 색인으로 두어, 에이전트가 문서를 열기 전에 내용과 적용 범위를 판단하게 한다.
date: 2026-11-02
decision-makers: [human:PubCyBerry]
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format (OKF) v0.2
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# docs/를 OKF v0.2 bundle로 관리한다

## 맥락과 문제

어떤 모델과 에이전트가 작업해도 같은 규칙을 따르게 하려면, 에이전트가 필요한 규칙 문서를 스스로 찾을 수 있어야 한다. 문서가 늘어나면 모든 문서를 읽을 수 없으므로, 열기 전에 무엇을 다루는 문서인지 알 수 있는 메타데이터가 필요하다. 어떤 메타데이터 형식을 쓸 것인가?

## 판단 기준

- 별도 도구 없이 `cat`과 `grep`으로 읽을 수 있어야 한다
- 에이전트마다 다른 키를 만들지 않도록 기준이 되는 규격이 있어야 한다
- 고칠 파일 경로로 관련 규칙을 찾을 수 있어야 한다
- 사람이 검토한 문서인지 구분할 수 있어야 한다

## 검토한 선택지

- OKF v0.2
- 저장소 자체 front matter 규격
- front matter 없이 색인 문서만 둔다

## 결정

"OKF v0.2"를 선택한다. 저장소 소유자가 OKF를 기본으로 지정했고, markdown과 YAML front matter만으로 이루어진 공개 규격이라 판단 기준을 충족한다.[^okf-spec] OKF가 정하지 않은 부분은 다음과 같이 정한다.

- bundle 루트는 `docs/`다. 저장소 루트 문서는 bundle 밖에 둔다.
- `type` 값을 정해 둔 목록으로 제한한다.
- 확장 키 `scope`로 문서가 적용되는 저장소 경로를 나타낸다.
- 링크는 bundle 기준 절대 경로(`/...`) 대신 상대 경로를 쓴다. GitHub가 `/`를 저장소 루트로 해석하기 때문이다.

세부 규칙은 [문서 메타데이터](../../standards/metadata.md)에 있다.

### 결과

- 장점: 에이전트가 front matter만 읽고 문서를 열지 고를 수 있다
- 장점: `generated`와 `verified`로 에이전트가 쓴 내용과 사람이 검토한 내용을 구분한다
- 단점: 문서를 고칠 때마다 front matter와 `docs/index.md`를 함께 고쳐야 한다
- 단점: 결정 당시 OKF는 막 나온 v0.2 규격이라 바뀔 수 있다. major 버전이 바뀌면 이 결정을 다시 검토한다

### 확인 방법

리뷰에서 front matter와 `docs/index.md` 항목을 확인한다. 결정 당시 자동 검사는 없다.

## 선택지별 장단점

### OKF v0.2

- 장점: 필수 키가 `type`뿐이라 시작 비용이 작다
- 장점: 출처(`sources`), 검토(`verified`), 수명(`status`, `stale_after`) 필드가 정해져 있다
- 단점: 데이터 카탈로그용 필드는 이 저장소에 맞지 않아 쓰지 않는다

### 저장소 자체 front matter 규격

- 장점: 필요한 키만 정할 수 있다
- 단점: 키의 뜻을 모두 직접 정의하고 문서화해야 한다

### front matter 없이 색인 문서만 둔다

- 장점: 문서 파일에 추가할 내용이 없다
- 단점: 문서를 열지 않고는 적용 범위와 검토 여부를 알 수 없다

[^okf-spec]: Open Knowledge Format (OKF) v0.2
