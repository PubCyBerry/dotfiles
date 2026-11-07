---
type: Standard
title: 패키지 매니페스트
description: manifests/ 파일의 형식, 도구를 추가하고 지우는 절차, 버전을 고정하지 않는 원칙을 정한다.
scope:
  - "manifests/**"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# 패키지 매니페스트

`manifests/`의 패키지 목록을 고칠 때 지키는 규칙이다. OS 사이의 대응 규칙은 [플랫폼 동등성](cross-platform.md)에, 외부 저장소를 믿을지 판단하는 기준은 [외부 코드](../../SECURITY.md#외부-코드)에 있다.

## 형식

- 각 매니페스트의 항목 형식과 install이 그 항목으로 하는 일은 그 파일의 첫머리 주석이 정한다. 형식을 바꾸면 첫머리 주석과 install 스크립트를 함께 고친다.
- 한 줄에 한 항목을 쓴다. install이 `#` 뒤를 주석으로 지우므로 항목 값에 `#`를 쓸 수 없다.
- 예외나 주의할 점은 그 줄 끝에 주석으로 쓴다(`winget.txt`의 `MikeFarah.yq` 줄).

## 도구 추가

1. winget ID를 `winget show --id <ID> --exact`로 확인한다. `--exact`는 대소문자를 구분하므로 ID를 소문자로 바꿔 쓰면 설치가 실패한다.
2. `winget.txt`와 `Brewfile`의 같은 위치에 넣는다.
3. Linux는 apt 패키지를 먼저 찾는다. 지원하는 가장 낮은 Ubuntu 버전([지원 환경](../../README.md#지원-환경))의 apt에 없거나 버전이 너무 낡았으면 `github-releases.tsv`에 넣는다. asset 이름은 최신 릴리스에서 지원하는 모든 아키텍처에 대해 확인한다.
4. 외부 저장소나 패키지(GitHub 릴리스, npm, skill, 플러그인)는 넣기 전에 [외부 코드](../../SECURITY.md#외부-코드)의 확인 항목을 따른다.
5. [플랫폼 동등성](cross-platform.md)의 함께 고칠 곳을 확인한다.

## 도구 제거

- 매니페스트에서 지워도 이미 설치된 머신에서는 지워지지 않는다. install은 아무것도 지우지 않는다.
- 기존 머신에서 정리가 필요하면 커밋 본문에 정리 방법을 쓴다. 정리할 것이 많으면 `docs/legacy-cleanup.md`처럼 임시 `Playbook` 문서를 둔다.

## 버전

- 어떤 도구도 버전을 고정하지 않는다. install은 실행할 때마다 최신을 설치한다. 이유는 [ADR 0005](../architecture/adr/0005-keep-installers-thin.md)에 있다.
- 그래서 저장소 소유자가 바뀌거나 저장소가 오염되면 그 변경이 다음 install에 그대로 들어온다. 출처를 고르는 기준은 [외부 코드](../../SECURITY.md#외부-코드)에 있다.

## 검사

자동 검사는 없다. 리뷰에서 확인한다.
