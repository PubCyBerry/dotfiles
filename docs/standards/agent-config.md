---
type: Standard
title: 에이전트 설정
description: 에이전트별 설정과 hook을 모든 에이전트에서 같은 동작으로 유지하는 규칙을 정한다.
scope:
  - "config/agents/**"
  - "config/claude/**"
  - "config/codex/**"
  - "config/agy/**"
  - "manifests/skills.txt"
  - "manifests/plugins.txt"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# 에이전트 설정

`config/`의 에이전트 설정을 고칠 때 지키는 규칙이다. 설정 파일별 배포 위치와 방식은 install 스크립트의 `config files` 단계와 `ARCHITECTURE.md`의 [배포 방식](../../ARCHITECTURE.md#배포-방식)에 있다.

## 지침 파일

- 전역 지침의 원본은 `config/agents/global.md` 하나다. install이 이 파일을 각 에이전트의 전역 지침 위치로 복사한다. 에이전트별 지침 파일을 따로 만들지 않는다.
- 이 저장소에서만 지킬 규칙은 전역 지침이 아니라 `docs/standards/`에 쓴다. 전역 지침은 모든 프로젝트에 들어간다.
- 저장소의 진입점은 `AGENTS.md` 하나다. 규칙은 [파일 이름과 위치](metadata.md#파일-이름과-위치)에 있다.

## 에이전트 사이의 동작 일치

- 에이전트 동작을 바꾸는 설정(hook, 지침)은 `config/`에 설정이 있는 모든 에이전트에 함께 넣는다. 어느 에이전트가 지원하지 않으면 아래 표에 그 사실을 쓴다.
- skill, 플러그인, output style은 에이전트마다 지원 여부와 설치 대상이 다르다. 모든 에이전트가 따라야 하는 규칙은 이런 기능에만 두지 않고 `docs/standards/`에 쓴다.

| 동작 | Claude Code | Codex | Antigravity |
|---|---|---|---|
| 현재 시각 주입 | `config/claude/settings.json`의 `hooks` | `config/codex/hooks.json` | `config/agy/hooks.json` |
| 한국어 문체 | `config/claude/settings.json`의 `outputStyle` | 설정 없음. [글쓰기 규칙](writing-style.md)으로 맞춘다 | 설정 없음. 글쓰기 규칙으로 맞춘다 |
| 커밋 서명 끄기 | `config/claude/settings.json`의 `attribution` | 설정 없음. [커밋 규칙](commit-convention.md)으로 맞춘다 | 설정 없음. 커밋 규칙으로 맞춘다 |

## hook

- hook 스크립트는 `config/<에이전트>/hooks/`에 두고, 각 에이전트의 hook 설정에 `bash`로 실행하는 명령으로 등록한다. Windows에서도 Git Bash로 실행된다.
- hook이 출력하는 event 이름(Claude Code와 Codex의 `hookEventName`)은 등록한 event 이름과 같아야 한다. 에이전트는 출력에 적힌 event 이름을 보고 결과를 해석한다.
- 시간대는 `date`의 `%Z` 대신 `%z`로 출력한다. Git Bash에서 `%Z`는 한국어 타임존 이름이 깨져 빈 값이 된다.
- hook과 statusline은 비대화형 bash로 실행되므로 셸 프로파일의 별칭과 초기화가 적용되지 않는다. 외부 도구는 `command -v`로 확인하고, 도구가 없어도 오류 없이 끝나게 한다(`config/claude/statusline.sh`).

## 설정 병합

- 병합으로 배포되는 에이전트 설정은 기존 머신에 이미 있는 키가 저장소 값으로 바뀌지 않는다. 규칙은 [병합 대상 파일](installer.md#병합-대상-파일)에 있다.
- 다른 도구(Orca 등)가 에이전트 설정에 넣은 hook과 머신마다 다른 값은 저장소 파일에 옮겨 적지 않는다. 병합이 기존 머신의 값을 보존한다.

## statusline

- claude-hud의 실행 경로는 `config/claude/statusline.sh`가 실행할 때 찾는다. Node 버전이나 플러그인 캐시 경로를 설정에 고정하지 않는다. Node나 플러그인이 업데이트되면 그 경로가 바뀐다.
- claude-hud 표시 설정은 `config/claude/claude-hud.json`에서 고친다.

## 플러그인과 skill

- `plugins.txt`에서 플러그인을 빼면 `config/claude/settings.json`에서 그 플러그인을 가리키는 값(`outputStyle` 등)도 함께 뺀다. 가리키는 대상이 없는 값은 기본 동작으로 바뀐다.
- 플러그인과 skill 저장소는 추가하기 전에 [외부 코드](../../SECURITY.md#외부-코드)의 확인 항목을 따른다.

## 모델과 권한

- 모델과 추론 설정(`config/codex/config.toml`의 모델 키, `config/claude/settings.json`의 `env`)은 사용자가 고른 값이다. 사용자가 요청하지 않으면 바꾸지 않는다.
- 권한과 샌드박스 설정의 기준은 [권한과 정책](../../SECURITY.md#권한과-정책)에 있다.

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| 한 에이전트의 hook | 다른 에이전트의 hook, 이 문서의 표 |
| 플러그인 추가나 제거 | `config/claude/settings.json`에서 그 플러그인을 가리키는 키 |
| 배포하는 설정 파일 | `install.ps1`과 `install.sh`의 `config files` 단계 |

## 검사

| 규칙 | 확인 |
|---|---|
| JSON, TOML 구문 | CI의 JSON, TOML 구문 단계 |
| hook 스크립트 셸 문법 | CI의 shellcheck 단계 |
| hook 동작, 에이전트 사이의 동작 일치 | 각 에이전트에서 실행해 확인한다 |
