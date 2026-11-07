---
type: Standard
title: 플랫폼 동등성
description: 지원하는 모든 OS에서 같은 도구와 설정을 유지하는 규칙을 정한다.
scope:
  - "manifests/**"
  - "install.ps1"
  - "install.sh"
  - "config/bash/**"
  - "config/zsh/**"
  - "config/powershell/**"
  - "config/tmux/**"
  - "config/herdr/**"
generated: { by: claude-code/claude-opus-5-5, at: 2026-11-03T00:19:10+09:00 }
---

# 플랫폼 동등성

지원하는 모든 OS에서 같은 도구를 같은 방식으로 쓰도록 유지하는 규칙이다. 지원하는 OS는 `README.md`의 [지원 환경](../../README.md#지원-환경)에 있다. 주 환경은 Windows이고, macOS는 Windows와 같은 도구 구성을 유지한다. Linux도 같은 도구를 목표로 하되, apt와 GitHub 릴리스로 구할 수 있는 범위에서 맞춘다.

## 도구 목록

- `manifests/winget.txt`와 `manifests/Brewfile`은 같은 도구를 같은 순서로 담는다. 순서가 같아야 파일을 나란히 놓고 빠진 도구를 찾을 수 있다.
- 한쪽에만 있어야 하는 도구는 그 줄에 이유를 주석으로 쓴다(`Brewfile`의 `herdr` 줄).
- Linux는 `manifests/apt.txt`에서 먼저 찾고, apt에 없거나 너무 낡았으면 `manifests/github-releases.tsv`에 넣는다. 매니페스트 규칙은 [패키지 매니페스트](manifests.md)에 있다.
- Ubuntu에서 실행 파일 이름이 다른 apt 패키지는 `install.sh`의 `apt packages` 단계가 원래 이름으로 연결한다. 이런 도구를 추가하면 그 단계에 연결을 추가한다.

## 설정 파일

- 설정 파일을 추가하면 `install.ps1`과 `install.sh`의 `config files` 단계에 같은 순서로 넣는다. 순서가 같아야 빠진 줄을 찾을 수 있다.
- OS마다 내용이 달라야 하면 파일을 나눈다. Windows용 파일은 이름에 `.windows`를 붙이고(`config/herdr/config.windows.toml`), macOS와 Linux는 접미사가 없거나 `.linux`가 붙은 파일을 함께 쓴다.

## 셸 프로파일

- `config/bash/`, `config/zsh/`, `config/powershell/`의 셸 프로파일은 같은 도구를 같은 방식으로 초기화한다. OS별로 어느 프로파일을 쓰는지는 `ARCHITECTURE.md`의 [구조](../../ARCHITECTURE.md#구조)에 있다.
- 별칭이나 도구 초기화를 한 프로파일에 추가하면 나머지 프로파일에도 추가한다. 한쪽에만 필요한 내용은 이유를 주석으로 쓴다.
- 프로파일 작성 규칙은 [셸 프로파일](scripts.md#셸-프로파일)에 있다.

## Windows SSH 세션

Windows OpenSSH 세션은 네트워크 로그온이라 WinGet 심볼릭 링크와 fnm junction을 거치는 실행이 막힌다. 증상과 원리는 [이슈 #13](https://github.com/PubCyBerry/dotfiles/issues/13)에 있다.

- 새 WinGet 도구의 실행 파일이 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\` 아래에 설치되면(portable 패키지) `config/bash/bashrc`의 WinGet 우회 목록에 넣는다. 그룹을 나누는 기준은 그 목록의 주석에 있다.
- 우회 목록의 디렉터리 이름은 매니페스트 ID가 아니라 실제 폴더 이름의 대소문자를 따른다(`MikeFarah.yq`, `Oven-sh.Bun`). bash glob은 대소문자를 구분한다.
- PowerShell 프로파일에서는 `Resolve-ExePath`로 링크가 가리키는 실제 경로를 찾아 쓴다.
- OS 보안 정책을 완화해서 우회하지 않는다. 기준은 [권한과 정책](../../SECURITY.md#권한과-정책)에 있다.

## 줄바꿈과 인코딩

- 줄바꿈은 `.gitattributes`가 정한다.
- OS별 git 줄바꿈 설정(`core.autocrlf`, `core.fileMode`)은 install 스크립트의 `git config` 단계가 넣는다.
- PowerShell에서 파일을 쓰는 방법은 [PowerShell](scripts.md#powershell)에 있다.

## 경로와 OS 판별

- bash에서 Windows 위치는 `$HOME/AppData/...`처럼 쓴다. OS는 `$OSTYPE`이나 `uname -s`로 판별한다.
- 병합으로 배포하는 TOML 설정에 Windows 경로를 쓰는 방법은 [병합 대상 파일](installer.md#병합-대상-파일)에 있다.

## 함께 고칠 곳

| 바꾸는 것 | 함께 고칠 곳 |
|---|---|
| `winget.txt` 또는 `Brewfile` | 다른 쪽 파일, Linux 매니페스트, portable 패키지면 `bashrc`의 WinGet 우회 목록 |
| 한 install 스크립트의 설정 배포 줄 | 다른 install 스크립트의 같은 위치 |
| 한 셸 프로파일의 별칭이나 초기화 | 나머지 셸 프로파일 |

## 검사

자동 검사는 없다. 리뷰에서 대응하는 매니페스트, install 스크립트, 셸 프로파일을 나란히 놓고 확인한다.
