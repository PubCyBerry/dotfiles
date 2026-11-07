---
type: Decision
title: 운영 문제는 문서 대신 GitHub 이슈로 기록한다
description: 운영 중에 겪은 문제와 원인, 조치를 docs/troubleshooting.md 대신 troubleshooting 라벨의 GitHub 이슈로 기록한다.
date: 2026-11-06
decision-makers: [human:PubCyBerry]
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-06T20:22:12+09:00 }
---

# 운영 문제는 문서 대신 GitHub 이슈로 기록한다

## 맥락과 문제

결정 당시 운영 문제의 증상과 조치는 `docs/troubleshooting.md` 한 파일에 절로 쌓여 있었다. 문제마다 해결 여부와 관련 PR을 표시할 곳이 없었고, 에이전트가 필요한 사례를 찾으려면 파일 전체를 읽어야 했다. 운영 문제를 어디에 기록할 것인가?

## 판단 기준

- 문제 하나를 따로 찾고 링크할 수 있어야 한다
- 해결 여부와 관련 PR을 문제마다 남길 수 있어야 한다
- 에이전트가 오류 메시지나 키워드로 검색할 수 있어야 한다

## 검토한 선택지

- GitHub 이슈
- `docs/troubleshooting.md` 한 파일
- 문제마다 `docs/` 아래 `Playbook` 문서

## 결정

"GitHub 이슈"를 선택한다. 저장소 소유자가 정했다. `troubleshooting` 라벨과 문제 해결 이슈 템플릿으로 기록하고, 기존 `docs/troubleshooting.md`의 절은 이슈로 옮긴 뒤 파일을 지웠다. 기록하고 찾는 방법은 [이슈 규칙](../../standards/issues.md)에 있다.

### 결과

- 장점: 문제마다 상태(열림, 닫힘), 댓글, 관련 PR이 남는다
- 장점: `gh issue list`로 라벨과 키워드를 함께 검색한다
- 단점: GitHub에 접근할 수 없으면(오프라인, `gh` 인증 없음) 기록을 읽을 수 없다
- 단점: 저장소를 clone해도 기록이 따라오지 않는다
- 단점: 이슈 생성과 댓글은 외부에 보이는 행동이라, 에이전트가 사용자 확인 없이 기록할 수 없다

### 확인 방법

리뷰에서 `docs/`에 운영 문제를 기록한 문서가 새로 생기지 않는지 확인한다.

## 선택지별 장단점

### GitHub 이슈

- 장점: 상태, 라벨, PR 연결을 GitHub가 관리한다
- 단점: 저장소 밖에 있어 GitHub 접근이 필요하다

### `docs/troubleshooting.md` 한 파일

- 장점: 저장소 안에 있어 오프라인에서도 읽을 수 있다
- 단점: 해결 여부와 관련 PR을 표시할 곳이 없고, 파일 하나가 계속 길어진다

### 문제마다 `Playbook` 문서

- 장점: 문제마다 front matter로 찾을 수 있다
- 단점: 문서가 문제 수만큼 늘고, 상태와 댓글을 직접 관리해야 한다

## 추가 정보

- 옮긴 기록: [troubleshooting 라벨 이슈](https://github.com/PubCyBerry/dotfiles/issues?q=label%3Atroubleshooting)
