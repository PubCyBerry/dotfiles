---
type: Decision
title: AGENTS.md를 모든 에이전트의 단일 진입점으로 쓴다
description: 저장소 루트에는 AGENTS.md만 두고 CLAUDE.md와 GEMINI.md를 만들지 않아, 모든 에이전트가 같은 지침을 읽게 한다.
date: 2026-11-02
decision-makers: [human:PubCyBerry]
sources:
  - id: claude-code-changelog
    resource: https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md
    title: Claude Code CHANGELOG
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# AGENTS.md를 모든 에이전트의 단일 진입점으로 쓴다

## 맥락과 문제

결정 당시 이 저장소는 Claude Code, Codex, Antigravity CLI로 작업했다. 에이전트마다 기본으로 읽는 지침 파일 이름이 달라(`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`), 파일을 여러 개 두면 내용이 서로 어긋난다. #10에서는 Claude Code가 `AGENTS.md`를 직접 읽는다는 이유로 `CLAUDE.md`를 지웠다. 어떤 파일을 진입점으로 두고, 그 파일에 무엇을 쓸 것인가?

## 판단 기준

- 모든 에이전트가 같은 지침을 읽어야 한다
- 지침 원본은 하나여야 한다
- 진입점은 세션마다 읽히므로 짧아야 한다

## 검토한 선택지

- `AGENTS.md` 하나만 둔다
- `AGENTS.md`를 두고, `CLAUDE.md`와 `GEMINI.md`에는 `AGENTS.md`를 가져오는 줄만 둔다
- 에이전트별 지침 파일을 각각 관리한다

## 결정

"`AGENTS.md` 하나만 둔다"를 선택한다. 결정 당시 이 저장소에서 쓰는 에이전트가 모두 `AGENTS.md`를 읽었으므로 다른 파일이 필요 없다.

- Codex는 `AGENTS.md`를 읽는다.
- Claude Code는 2.1.277부터 `CLAUDE.md`가 없는 프로젝트에서 `AGENTS.md`를 읽는다.[^claude-code-changelog] 결정 당시 2.1.316에서 이 저장소의 `AGENTS.md`가 프로젝트 지침으로 들어오는 것을 확인했다.
- Antigravity CLI도 프로젝트의 `AGENTS.md`를 읽는다고 알려져 있다. 이 저장소에서 직접 확인하지는 않았다.

`AGENTS.md`에는 작업별로 읽을 문서를 안내하는 색인만 두고, 규칙은 `docs/standards/`에 쓴다.

### 결과

- 장점: 지침 원본이 하나라 에이전트 사이에 내용이 어긋나지 않는다
- 장점: `AGENTS.md`가 짧아 세션마다 읽는 비용이 작고, 필요한 규칙 문서만 골라 읽는다
- 단점: 저장소에 `CLAUDE.md`가 생기면 Claude Code는 기본 설정에서 `AGENTS.md`를 읽지 않는다
- 단점: 에이전트가 색인을 보고 규칙 문서를 직접 열어야 한다. 열지 않으면 규칙을 모른다

### 확인 방법

- 리뷰에서 저장소 루트에 `CLAUDE.md`와 `GEMINI.md`가 없는지 확인한다
- 새 에이전트나 새 버전을 쓰기 시작하면 `AGENTS.md`의 내용을 아는지 물어 확인한다

## 선택지별 장단점

### `AGENTS.md` 하나만 둔다

- 장점: 관리할 파일이 하나다
- 단점: 각 에이전트의 `AGENTS.md` 지원에 의존한다

### `CLAUDE.md`와 `GEMINI.md`에 가져오는 줄만 둔다

- 장점: `AGENTS.md`를 읽지 않는 버전이나 설정에서도 동작한다
- 단점: 관리할 파일이 늘고, 가져오는 줄만 있어야 할 파일에 내용이 덧붙으면 원본이 둘이 된다

### 에이전트별 지침 파일을 각각 관리한다

- 장점: 에이전트마다 다른 지침을 줄 수 있다
- 단점: 같은 규칙을 여러 번 써야 하고 내용이 어긋난다

## 추가 정보

- Claude Code가 어느 파일을 프로젝트 지침으로 읽을지는 `/config`의 Project instructions에서 바꿀 수 있다.[^claude-code-changelog]
- `AGENTS.md`를 읽지 않는 에이전트나 설정을 써야 하면 가져오는 줄만 둔 파일을 추가하는 선택지를 다시 검토한다.
- 파일 위치 규칙: [파일 이름과 위치](../../standards/metadata.md#파일-이름과-위치)

[^claude-code-changelog]: Claude Code CHANGELOG
