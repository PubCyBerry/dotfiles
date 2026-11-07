---
type: Standard
title: 이슈 규칙
description: GitHub 이슈를 찾고 쓰고 triage하고 닫는 방법과 이슈 라벨을 정한다.
scope:
  - ".github/ISSUE_TEMPLATE/**"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-06T20:25:42+09:00 }
---

# 이슈 규칙

운영 중에 겪은 문제(설치 실패, 셸이나 SSH 세션 오류, 에이전트 설정 문제)와 변경 제안을 GitHub 이슈로 다루는 규칙이다. 운영 문제를 문서 대신 이슈로 기록하는 이유는 [ADR 0007](../architecture/adr/0007-record-troubleshooting-in-github-issues.md)에, triage를 최소 구성으로 정한 이유는 [ADR 0008](../architecture/adr/0008-minimal-issue-triage.md)에 있다.

## 찾기

- 오류나 이상 동작을 조사하기 전에 `troubleshooting` 라벨 이슈에서 같은 사례를 찾는다. 해결된 사례는 닫혀 있으므로 상태와 무관하게 검색한다.

  ```bash
  gh issue list --label troubleshooting --state all --search "<오류 메시지나 키워드>"
  gh issue view <번호>
  ```

- 같은 사례가 있으면 그 이슈의 조치를 따른다. 조치가 맞지 않거나 새로 알게 된 사실이 있으면 그 이슈에 댓글로 남긴다.

## 작성

- 운영 문제는 `docs/`에 문서로 쓰지 않고 이슈로 기록한다.
- 이슈는 `.github/ISSUE_TEMPLATE/`에서 목적에 맞는 템플릿(각 파일의 `about`)을 골라 쓴다. 템플릿 없는 빈 이슈를 만들지 않는다.
- `gh issue create`로 만들 때는 템플릿 파일의 절을 그대로 옮겨 채운 본문을 `--body-file`로 넘기고, 템플릿 front matter의 `labels`에 적힌 라벨을 각각 `--label`로 넘긴다.
- 제목에는 증상이나 제안을 한국어로 쓴다. 검색에 쓰일 오류 메시지는 본문의 증상 절에 그대로 붙여 넣는다.
- 해당 없는 절은 지우고, 원인처럼 아직 모르는 절은 비워 둔 뒤 알게 되면 채운다.
- 보안 취약점은 이슈로 올리지 않는다. [SECURITY.md](../../SECURITY.md)를 따른다.
- 이슈 생성, 댓글, 라벨 변경, 닫기는 [사용자 확인이 필요한 행동](agent-workflow.md#사용자-확인이-필요한-행동)이다.

## triage

열린 이슈 중 `status/needs-triage`가 붙은 이슈는 아직 다루기로 정하지 않은 이슈다. 작업을 시작하기 전에 triage한다.

```bash
gh issue list --label "status/needs-triage"
```

1. [찾기](#찾기)에 따라 같은 사례가 있는지 확인한다.
2. 제목이 증상이나 제안을 드러내지 않으면 고친다.
3. 종류 라벨이 내용과 맞는지 확인하고, 맞지 않으면 바꾼다.
4. 판단에 필요한 정보가 충분한지 확인한다.
5. 아래 표에서 다음 상태를 고르고, 다음에 할 일이 분명하지 않으면 댓글로 남긴다.

| 판단 | 처리 |
|---|---|
| 같은 사례가 이미 있다 | 원래 이슈를 링크하고 duplicate로 닫는다 |
| 다루지 않기로 했다 | 이유를 댓글로 남기고 not planned로 닫는다 |
| 판단에 필요한 정보가 부족하다 | `status/needs-triage`를 떼고 `status/needs-info`를 붙인 뒤, 필요한 정보를 댓글로 묻는다 |
| 이미 조치로 끝난 기록이다 | [해결과 닫기](#해결과-닫기)에 따라 닫는다 |
| 진행한다 | `status/needs-triage`를 떼고 열린 상태로 둔다. 맡은 사람이 있으면 담당자로 지정한다 |

- `status/needs-info` 이슈에 정보가 오면 `status/needs-info`를 떼고 `status/needs-triage`를 다시 붙인다.
- 닫았던 이슈를 다시 열면 `status/needs-triage`를 붙인다.
- 진행 중이나 완료 같은 상태는 라벨로 만들지 않는다. 열린 상태, 담당자, 연결된 PR, 닫힌 이유가 그 상태를 나타낸다.

## 해결과 닫기

- 저장소를 고쳐 해결하면 PR 본문에 `Closes #번호`를 써서 병합할 때 이슈가 닫히게 한다.
- 저장소를 고치지 않고 조치로 끝나면, 원인과 조치 절을 채운 뒤 completed로 닫는다.
- 닫을 때 `status/` 라벨을 뗀다. 닫힌 이슈에는 종류 라벨만 남긴다.
- 닫힌 이슈는 지우지 않는다. 같은 문제를 다시 만났을 때 찾는 기록이다.

## 라벨

이 표가 이슈 라벨의 원본이다. 표에 없는 라벨은 이슈에 붙이지 않는다.

| 라벨 | 축 | 뜻 | 붙이는 때 |
|---|---|---|---|
| `troubleshooting` | 종류 | 운영 문제의 기록 | 문제 해결 템플릿으로 만들 때 |
| `enhancement` | 종류 | 도구나 설정의 변경 제안 | 변경 제안 템플릿으로 만들 때 |
| `status/needs-triage` | 상태 | 아직 triage하지 않았다 | 템플릿으로 만들 때, 다시 열 때, 요청한 정보가 왔을 때 |
| `status/needs-info` | 상태 | 판단에 필요한 정보를 기다린다 | triage에서 정보가 부족하다고 판단했을 때 |

- 종류 라벨은 하나만 붙이고, 상태 라벨은 열린 이슈에만 하나까지 붙인다.
- 라벨을 추가하거나 바꾸려면 이 표를 먼저 고치고, 같은 변경에서 GitHub 라벨(`gh label create`, `gh label edit`)과 템플릿의 `labels` 값을 맞춘다.

## 문서와의 관계

- 이슈는 문제 하나의 기록이다. 문제에서 얻은 규칙(예: 새 WinGet 도구는 SSH 우회 목록에 넣는다)은 해당 규칙 문서에 쓰고, 근거로 그 이슈를 링크한다.
- 저장소 문서에서 이슈를 가리킬 때는 전체 URL로 링크한다. 저장소 파일에 쓴 `#번호`는 GitHub가 링크로 바꾸지 않는다.

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| [라벨](#라벨) 표 | GitHub 저장소의 라벨 목록, 템플릿 front matter의 `labels` 값 |
| 템플릿 추가나 삭제 | [라벨](#라벨) 표의 종류 라벨 |

## 검사

자동 검사는 없다. 리뷰에서 확인하고, `gh label list`로 GitHub 라벨이 [라벨](#라벨) 표와 같은지 본다.
