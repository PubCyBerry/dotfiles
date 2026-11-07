# 에이전트 설치 절차

에이전트가 이 저장소의 dotfiles를 머신에 설치하는 절차다. 사용자는 install 스크립트를 직접 실행하는 대신 에이전트에게 "INSTALL.md를 읽고 설치해"라고 요청한다. 이 요청은 [사용자 확인이 필요한 행동](docs/standards/agent-workflow.md#사용자-확인이-필요한-행동) 중 install 실행을 요청한 것으로 본다. 이 문서에서 따로 묻도록 한 행동은 그 단계에서 다시 묻는다.

## 원칙

- 설치는 install 스크립트로만 한다. 스크립트가 하는 일을 명령으로 하나씩 따라 하지 않는다.
- 비밀번호 입력이나 UAC 승인처럼 사람이 해야 하는 일은 에이전트가 대신하지 않는다. 사용자에게 할 일을 안내한다.
- 실패를 고치려고 install 스크립트나 설정 파일을 바꾸지 않는다. 원인과 조치를 보고한다. 저장소를 고쳐야 하면 설치와 별개의 작업으로 사용자에게 제안한다.
- 이 문서에 없는 정리나 삭제는 하지 않는다.

## 1. 저장소 준비

1. 저장소 밖에서 이 문서를 받았으면, `README.md`의 [Quickstart](README.md#quickstart)에 있는 위치로 저장소를 clone한다. git이 없으면 사용자에게 알리고 OS 패키지 매니저로 설치할지 묻는다.
2. 저장소가 이미 있으면 `main` 브랜치에서 `git pull --ff-only`로 최신을 받는다. 커밋하지 않은 변경이 있거나 fast-forward가 되지 않으면 멈추고 사용자에게 알린다.

## 2. 실행 전 확인

OS별 전제 조건을 확인한다. 충족하지 않으면 실행하지 않고 오른쪽 처리를 따른다.

| OS | 확인 | 충족하지 않을 때 |
|---|---|---|
| Windows | `pwsh`가 있다 | `README.md`의 [Quickstart](README.md#quickstart)에 있는 PowerShell 설치 명령을 실행할지 묻는다 |
| macOS | `brew`가 있다 | Homebrew 설치에는 비밀번호 입력이 필요하므로, 사용자가 [brew.sh](https://brew.sh)의 방법으로 설치하도록 안내한다 |
| Linux | `sudo -n true`가 성공하거나 root로 실행 중이다 | 사용자가 터미널에서 `install.sh`를 직접 실행하도록 안내하고, 사용자가 준 출력으로 [5. 결과 확인](#5-결과-확인)부터 진행한다 |

이어서 다음을 확인하고, 해당하면 사용자에게 알린다.

- 예전 버전 설치본: [docs/legacy-cleanup.md](docs/legacy-cleanup.md)의 준비 절에 있는 설치 기록(receipt)이 있으면, 그 문서를 먼저 수행할지 묻는다.
- Windows에서 Git Bash 창이나 tmux가 떠 있으면 Git과 psmux 업그레이드가 실패할 수 있다([이슈 #19](https://github.com/PubCyBerry/dotfiles/issues/19)). 사용자에게 닫을 수 있는지 묻고, 닫지 않으면 그 실패를 감수하고 진행한다.
- Windows에서는 설치 중 UAC 창이 뜰 수 있고, 사용자가 승인해야 진행된다. 언제 뜨지 않는지는 `README.md`의 Quickstart 주석에 있다.

## 3. 실행

install은 몇 분 걸린다. 명령 시간 제한을 20분 이상으로 두거나 백그라운드로 실행한다. 도구 출력이 잘려도 마지막의 실패 요약을 읽을 수 있도록 로그 파일로도 남긴다.

Windows는 PowerShell에서 실행한다. 에이전트에 PowerShell 도구가 있으면 그것을 쓴다. Git Bash에서 실행하면 실행 중인 `bash.exe` 때문에 Git 업그레이드가 실패할 수 있다.

```powershell
# Windows: 저장소 루트에서
pwsh -NoProfile -ExecutionPolicy Bypass -File .\install.ps1 *>&1 | Tee-Object -FilePath "$env:TEMP\dotfiles-install.log"; "exit: $LASTEXITCODE"
```

```bash
# macOS, Linux: 저장소 루트에서
bash install.sh 2>&1 | tee "${TMPDIR:-/tmp}/dotfiles-install.log"; echo "exit: ${PIPESTATUS[0]}"
```

## 4. 실행 중

- install은 에이전트 자신(Claude Code, npm 전역 패키지인 Codex 등)도 업데이트한다. 실행 중인 자신의 업데이트가 실패하면, 세션을 끝낸 뒤 사용자가 그 도구를 업데이트하도록 안내한다. 업데이트 방법은 install을 다시 실행하는 것이다.
- 응답 없이 멈춘 것처럼 보이면 UAC 창이나 다른 입력을 기다리는지 사용자에게 확인한다. 임의로 프로세스를 끝내지 않는다.

## 5. 결과 확인

1. 종료 코드가 0이 아니면 로그 끝의 실패 요약에서 실패한 단계를 모은다.
2. 실패마다 [찾기](docs/standards/issues.md#찾기)에 따라 같은 사례의 이슈를 찾는다.
   - 조치가 있으면 보고에 적는다. 조치가 프로세스 종료, 관리자 권한, 비밀번호 입력처럼 사용자 행동을 요구하면 실행하지 않고 안내한다.
   - 같은 사례가 없으면 새 이슈를 만들지 사용자에게 묻는다.
3. 사용자가 조치를 마쳤다고 하면 [3. 실행](#3-실행)을 다시 한다. install은 여러 번 실행해도 된다.

## 6. 설치 후 작업

- git 사용자 정보: `git config --global user.name`과 `git config --global user.email`이 비어 있으면 사용자에게 값을 묻고 넣는다. 값을 추측하지 않는다.
- macOS 시스템 기본값: `config/macos/.macos`는 Finder와 Dock을 재시작하므로 적용할지 사용자에게 묻는다.
- 재시작: 셸 프로파일과 PATH 변경은 새 터미널과 새 에이전트 세션부터 적용된다. 사용자에게 터미널과 에이전트를 다시 시작하라고 안내한다.

## 7. 보고

[보고](docs/standards/agent-workflow.md#보고) 형식에 더해 다음을 쓴다.

- 실패한 단계와 원인, 찾은 이슈
- 사용자가 할 일(프로세스를 닫고 다시 실행, UAC 승인, 재시작 등)
- 로그 파일 위치
