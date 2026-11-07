---
type: Decision
title: 결정을 MADR 형식의 ADR로 기록한다
description: 설계 결정과 그 이유를 docs/architecture/adr/에 MADR 4 양식을 한국어로 옮긴 ADR로 남긴다.
date: 2026-11-03
decision-makers: [human:PubCyBerry]
sources:
  - id: madr-template
    resource: https://github.com/adr/madr/blob/develop/template/adr-template.md
    title: MADR adr-template.md
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# 결정을 MADR 형식의 ADR로 기록한다

## 맥락과 문제

이 저장소의 결정과 그 배경은 PR 본문과 `AGENTS.md`에 흩어져 있었다. 예를 들어 #10에서 설치 기록, 버전 고정, uninstall을 걷어낸 사실은 PR 본문에만 있다. 이유를 모르는 에이전트는 일부러 뺀 기능을 결함으로 보고 다시 넣으려 할 수 있다. 결정과 이유를 어디에, 어떤 형식으로 남길 것인가?

## 판단 기준

- 에이전트가 저장소 파일만 읽고 결정과 이유를 찾을 수 있어야 한다
- 문서 front matter 규칙(OKF)과 함께 쓸 수 있어야 한다
- 따로 설명하지 않아도 이해할 수 있는 널리 쓰이는 형식이어야 한다

## 검토한 선택지

- MADR 4 양식의 ADR
- Michael Nygard 형식의 ADR
- PR 본문과 커밋 메시지에만 남긴다

## 결정

"MADR 4 양식의 ADR"을 선택한다. 저장소 소유자가 MADR 템플릿을 지정했고[^madr-template], 검토한 선택지와 장단점을 함께 남기는 양식이라 다른 방법을 쓰지 않은 이유까지 기록된다. 양식은 한국어로 옮기고, MADR의 `status`는 OKF의 `status`로 바꿔 쓴다. 세부 규칙은 [ADR 작성 규칙](../../standards/adr.md)에 있다.

### 결과

- 장점: 결정마다 파일이 하나씩 생기고, `docs/index.md`와 front matter로 찾을 수 있다
- 장점: 규칙 문서는 짧게 두고 이유는 ADR로 링크한다
- 단점: MADR과 OKF가 `status`를 다른 뜻으로 쓰므로 값을 바꿔 쓰는 규칙이 필요하다

### 확인 방법

리뷰에서 [ADR 작성 규칙](../../standards/adr.md)을 따르는지 확인한다.

## 선택지별 장단점

### MADR 4 양식의 ADR

- 장점: 검토한 선택지와 장단점을 정해진 절에 쓴다
- 장점: 메타데이터를 front matter에 두므로 OKF와 함께 쓸 수 있다
- 단점: 절이 많아 작은 결정에는 무겁다. 선택 절은 지워서 줄인다

### Michael Nygard 형식의 ADR

- 장점: 상태, 맥락, 결정, 결과만 쓰므로 짧다
- 단점: 검토한 선택지를 쓰는 절이 없다

### PR 본문과 커밋 메시지에만 남긴다

- 장점: 파일이 늘지 않는다
- 단점: 에이전트가 GitHub를 조회하거나 git 기록을 뒤져야 찾을 수 있고, 결정이 바뀐 과정을 따라가기 어렵다

[^madr-template]: MADR adr-template.md
