---
type: Standard
title: 커밋 규칙
description: 커밋 메시지 형식, 브랜치 이름, PR 제목과 본문, 병합 방식을 정한다.
scope:
  - "**"
sources:
  - id: conventional-commits
    resource: https://www.conventionalcommits.org/ko/v1.0.0/
    title: Conventional Commits 1.0.0
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-07T21:11:08+09:00 }
---

# 커밋 규칙

커밋 메시지, 브랜치, PR을 같은 형식으로 남긴다. 형식은 Conventional Commits 1.0.0을 따르고[^conventional-commits], 제목과 본문은 [글쓰기 규칙](writing-style.md)대로 한국어로 쓴다.

## 메시지 형식

```text
<type>(<scope>)<!>: <제목>

<본문>
```

- `type`과 `scope`는 영어 소문자로, 제목과 본문은 한국어로 쓴다.
- 제목은 한 줄로 쓰고 명사형(`추가`, `제거`, `수정`, `변경`)으로 끝낸다. 마침표를 찍지 않는다.
  - `fix(bash): Windows PATH에서 쪼개진 경로 조각 제거`
  - `feat(manifests): 모든 플랫폼 매니페스트에 prek 추가`
- 본문에는 무엇을 왜 바꿨는지 `~한다`체로 쓴다. 제목만으로 충분하면 생략한다.
- 커밋 하나에는 논리적인 변경 하나를 담는다.
- 기존 설치본에 수동 조치가 필요하면 본문에 조치 방법을 쓴다. 병합 대상 파일의 기존 키 값을 바꾼 경우와 도구를 제거한 경우가 해당한다. 병합 동작은 [병합 대상 파일](installer.md#병합-대상-파일)에 있다.

## type

| type | 쓰는 경우 |
|---|---|
| `feat` | 도구, 설정, 기능을 추가하거나 동작을 바꾼다 |
| `fix` | 잘못된 동작을 고친다 |
| `refactor` | 동작은 그대로 두고 구조를 바꾼다 |
| `docs` | 문서만 바꾼다 |
| `ci` | `.github/workflows/`만 바꾼다 |
| `chore` | 도구 제거, 정리처럼 위에 해당하지 않는 변경 |

## scope

바꾼 영역의 이름을 쓴다. 여러 영역에 걸치거나 `type`이 `docs`나 `ci`면 생략한다.

| scope | 대상 |
|---|---|
| `manifests` | `manifests/`. 예전 커밋의 `npm`, `plugins`도 이 이름으로 쓴다 |
| `install` | `install.ps1`, `install.sh` |
| `github` | `.github/`의 이슈 템플릿과 PR 템플릿 |
| `config/` 아래 디렉터리 이름이나 확장자를 뺀 파일 이름 | 그 디렉터리나 파일(`claude`, `bash`, `herdr`, `starship`) |

## 호환성을 깨는 변경

기존 설치본에 영향을 주는 변경에는 `type` 뒤에 `!`를 붙인다. 배포 위치나 방식이 바뀌거나, 기존 머신에서 수동 정리가 필요한 경우다(#10의 `refactor!`). 본문에 영향 범위와 조치를 쓴다.

## 서명

커밋과 PR에 에이전트 서명(`Co-Authored-By`, `Generated with ...`, 세션 URL)을 넣지 않는다. Claude Code의 서명 설정은 `config/claude/settings.json`에 있고, 서명 설정이 없는 에이전트도 이 규칙을 따른다.

## 브랜치와 PR

- `main`에 직접 커밋하지 않는다. `<type>/<영문-kebab-case-설명>` 브랜치에서 작업한다(`feat/prek`, `fix/bashrc-msys-path-sanitize`).
- PR 제목은 커밋 메시지 제목 형식을 따른다. squash 병합하면 브랜치의 커밋 제목이 아니라 PR 제목 뒤에 `(#번호)`가 붙어 `main`의 커밋 제목이 된다.
- PR 본문은 `.github/pull_request_template.md`의 절을 채워 쓴다. 해당 없는 절은 지운다. `gh pr create`로 만들 때도 템플릿의 절을 그대로 옮겨 `--body-file`로 넘긴다.
- 이슈를 해결하는 PR은 [해결과 닫기](issues.md#해결과-닫기)를 따른다.
- 병합은 squash로 한다. PR 하나가 `main`에 커밋 하나로 남는다.
- 병합한 PR의 원격 브랜치는 GitHub가 지운다. squash 병합은 새 커밋을 만들므로 `git branch -d`로는 로컬 브랜치가 지워지지 않는다. `main`을 최신으로 맞추고 `gh pr view <브랜치> --json state`로 병합됐는지 확인한 뒤 `git branch -D`로 지운다.

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| 병합 방식, 병합 후 브랜치 삭제, squash 커밋 제목에 관한 규칙 | GitHub 저장소 설정 |

## 검사

| 규칙 | 확인 |
|---|---|
| 병합 방식, 병합 후 브랜치 삭제, squash 커밋 제목 | GitHub 저장소 설정이 강제한다. `gh api repos/PubCyBerry/dotfiles`의 `allow_squash_merge`, `allow_merge_commit`, `allow_rebase_merge`, `delete_branch_on_merge`, `squash_merge_commit_title`로 확인한다 |
| 커밋 메시지 형식, 브랜치 이름, PR 본문, 서명 | 리뷰 |

[^conventional-commits]: Conventional Commits 1.0.0
