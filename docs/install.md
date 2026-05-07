# 설치와 업데이트

`install.sh`와 `install.ps1`은 같은 명령을 반복 실행해도 안전하게 최신 dotfiles 상태를 적용하는 updater로 동작한다.

## 기본 실행

```bash
bash install.sh
```

```powershell
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

macOS 기본값까지 적용하려면:

```bash
bash install.sh --with-defaults
```

## 단계 선택

단계 이름:

| 단계 | 내용 |
|---|---|
| `packages` | apt, Homebrew, winget, GitHub release, 공식 installer 기반 도구 |
| `configs` | git, tmux, yazi, nvim, starship, shell profile |
| `node` | fnm Node.js LTS와 npm global packages |
| `claude` | Claude Code와 Claude config |
| `rtk` | RTK 바이너리 |
| `skills` | Claude Code skills |

```bash
bash install.sh --only configs
bash install.sh --skip claude,rtk,skills
bash install.sh --profile minimal
```

```powershell
.\install.ps1 --only configs
.\install.ps1 --skip claude,rtk,skills
.\install.ps1 --profile minimal
```

`minimal` profile은 기본적으로 `packages,configs`만 실행한다.

## Dry-run

실제 파일 변경과 설치 없이 실행 계획만 확인한다.

```bash
bash install.sh --dry-run
```

```powershell
.\install.ps1 --dry-run
```

## 재실행 계약

- 같은 명령을 여러 번 실행해도 profile block과 PATH 항목은 중복되지 않는다.
- dotfiles가 관리하는 config 파일과 디렉터리는 repo 버전으로 갱신된다.
- 기존 대상은 `.dotfiles-backup/<timestamp>/` 아래에 백업된다.
- `gitconfig` 병합은 기존 사용자 값을 덮어쓰지 않는다.
- OS별 git override는 항상 명시적으로 적용된다.

## CI skip

CI나 로그인 없는 환경에서는 계정/외부 서비스 의존 단계를 건너뛴다.

```bash
SKIP_CLAUDE_CODE=1 SKIP_RTK=1 SKIP_SKILLS=1 bash install.sh
```

```powershell
$env:SKIP_CLAUDE_CODE = "1"
$env:SKIP_RTK = "1"
$env:SKIP_SKILLS = "1"
.\install.ps1
```
