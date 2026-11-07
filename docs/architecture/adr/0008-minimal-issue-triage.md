---
type: Decision
title: 이슈 triage는 상태 라벨 두 개로 최소 구성한다
description: 이슈 triage에 status/needs-triage와 status/needs-info 라벨만 두고, 진행 상태는 열린 상태, 담당자, 연결된 PR 같은 GitHub 기본 상태로 나타낸다.
date: 2026-11-06
decision-makers: [human:PubCyBerry]
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-06T20:25:42+09:00 }
---

# 이슈 triage는 상태 라벨 두 개로 최소 구성한다

## 맥락과 문제

저장소 소유자가 이슈 triage를 쓰기로 정했다. 결정 당시 이 저장소는 한 사람이 관리하는 개인 dotfiles였고, 라벨은 GitHub 기본 라벨과 `troubleshooting`뿐이었다. 사용자의 `repo-scaffold` skill에는 종류, 상태, 우선순위 축의 라벨과 stale 자동화를 갖춘 triage 구성이 있다. triage를 어느 규모로 둘 것인가?

## 판단 기준

- 새 이슈가 분류 전인지 바로 알 수 있어야 한다
- 한 사람이 관리할 수 있을 만큼 라벨이 적어야 한다
- GitHub가 이미 나타내는 상태를 라벨로 다시 만들지 않아야 한다

## 검토한 선택지

- 최소 구성: `status/needs-triage`, `status/needs-info`만 추가한다
- repo-scaffold 방식: `kind/*`, `status/*`, `priority/*` 축으로 라벨을 정리한다
- repo-scaffold 방식에 stale 자동화 워크플로를 더한다

## 결정

"최소 구성"을 선택한다. 저장소 소유자가 골랐다. 종류는 기존 `troubleshooting`과 `enhancement` 라벨이 나타내고, 진행과 완료는 열린 상태, 담당자, 연결된 PR, 닫힌 이유가 나타낸다. 절차와 라벨 정의는 [이슈 규칙](../../standards/issues.md)에 있다.

### 결과

- 장점: 새로 만든 라벨이 두 개뿐이라 관리할 것이 적다
- 장점: `status/` 라벨 이름이 repo-scaffold 방식과 같아, 나중에 그 방식으로 넓혀도 이름을 바꾸지 않는다
- 단점: 우선순위를 나타낼 수단이 없다
- 단점: 정보를 기다리는 이슈가 오래 멈춰도 자동으로 알려 주거나 닫지 않는다

### 확인 방법

리뷰에서 [라벨](../../standards/issues.md#라벨) 표에 없는 라벨이 이슈에 붙지 않았는지 확인한다.

## 추가 정보

- 기여자가 늘거나 열린 이슈가 많아져 우선순위와 stale 처리가 필요해지면 repo-scaffold 방식을 다시 검토한다.
