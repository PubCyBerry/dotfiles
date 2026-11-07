---
type: Standard
title: 스크립트 작성
description: bash, zsh, PowerShell 스크립트와 셸 프로파일의 호환성, 오류 처리, 인코딩 규칙을 정한다.
scope:
  - "**/*.sh"
  - "**/*.ps1"
  - "config/bash/**"
  - "config/zsh/**"
  - "config/macos/.macos"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# 스크립트 작성

셸 스크립트, PowerShell 스크립트, 셸 프로파일을 고칠 때 지키는 규칙이다. 주석은 [코드 주석](writing-style.md#코드-주석)을 따른다.

## bash 3.2 호환

macOS의 기본 bash는 3.2다. macOS에서 `bash`로 실행되는 모든 파일은 bash 3.2에서 동작해야 한다. `install.sh`, hook 스크립트, `config/claude/statusline.sh`, `config/macos/.macos`가 여기에 해당한다. `config/bash/bashrc`는 macOS에서 쓰지 않으므로 해당하지 않는다.

해당하는 파일에서는 아래 기능을 쓰지 않는다.

| 기능 | 도입 버전 | 대신 쓰는 방법 |
|---|---|---|
| `mapfile`, `readarray` | bash 4.0 | `while IFS= read -r line; do ...; done < <(명령)` |
| 연관 배열(`declare -A`) | bash 4.0 | 줄 단위 목록, `case` |
| 대소문자 변환(`${var,,}`, `${var^^}`) | bash 4.0 | `tr '[:upper:]' '[:lower:]'` |
| `\|&`, `&>>` | bash 4.0 | `2>&1 \|`, `>> file 2>&1` |
| `shopt -s globstar` | bash 4.0 | `find` |
| nameref(`declare -n`) | bash 4.3 | 변수 이름 대신 값을 넘긴다 |

- `set -u` 상태에서 빈 배열을 `"${arr[@]}"`로 펼치면 bash 4.4 미만에서 unbound variable 오류가 난다. 길이(`${#arr[@]}`)를 먼저 확인한다.
- macOS의 BSD 도구에 없는 GNU 전용 옵션을 쓰지 않는다. `sed -i`(BSD는 백업 접미사 인자가 필요하다)와 `grep -P`가 대표적이다.

## bash 스크립트

- 실행하는 스크립트는 `#!/usr/bin/env bash`로 시작한다.
- `install.sh`는 `set -euo pipefail`을 쓰고, 단계 실패는 종료하지 않고 기록한다. 실패 처리 규칙은 [실패 처리](installer.md#실패-처리)에 있다.
- 외부 도구는 쓰기 전에 `command -v`로 있는지 확인한다.
- shellcheck 경고는 고친다. 고칠 수 없으면 그 줄 위에 `# shellcheck disable=SCxxxx  # 이유` 주석을 단다.

## 셸 프로파일

install이 마커 블록으로 넣는 셸 프로파일은 직접 실행하지 않는다. 어떤 파일이 마커 블록으로 배포되는지는 install 스크립트의 `shell profiles` 단계에 있다.

- 여러 번 로드돼도 결과가 같아야 한다. PATH에 넣기 전에 이미 있는지 확인한다(`[[ ":$PATH:" != *":$dir:"* ]]`, `($env:PATH -split ';') -notcontains $dir`).
- 도구가 설치되지 않은 머신에서도 오류 없이 로드돼야 한다. 도구 초기화와 별칭은 도구가 있는지 확인한 뒤에 둔다.
- `bashrc`에서 비대화형 셸을 끝내는 가드(`case $- in *i*) ;; *) return ;; esac`) 위에는 hook, scp, rsync 같은 비대화형 프로세스에도 필요한 PATH 설정만 둔다. 프롬프트, `eval` 초기화, 별칭은 가드 아래에 둔다. 비대화형 SSH 세션에서 `eval` 초기화가 무언가를 출력하면 scp와 git over ssh가 깨지기 때문이다.

## PowerShell

- PowerShell 7 기준으로 쓴다. Windows PowerShell 5.1은 지원하지 않는다(`install.ps1`의 `#Requires`).
- 기본 설정에서 외부 명령의 실패는 `$ErrorActionPreference = 'Stop'`으로 잡히지 않는다. `$LASTEXITCODE`로 확인한다.
- 파일을 쓸 때는 `install.ps1`의 `Write-Text`처럼 BOM 없는 UTF-8과 LF로 쓴다. Git Bash가 읽는 파일에 CR이 섞이면 안 된다.

## 검사

| 규칙 | 확인 |
|---|---|
| shellcheck 경고 | CI의 shellcheck 단계 |
| PowerShell 구문 | CI의 PowerShell 구문 단계 |
| bash 3.2 호환, BSD 도구 | 리뷰. 가능하면 macOS에서 실행해 확인한다 |
| 셸 프로파일 로드 | 새 셸을 열어 오류가 없는지 확인한다 |
