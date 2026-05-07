# 작업 흐름

## 업데이트

기존 머신은 저장소를 최신화한 뒤 같은 설치 명령을 다시 실행한다.

```bash
git pull
bash install.sh
```

```powershell
git pull
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

## Worktree

Codex 작업은 별도 worktree에서 진행한다. PR을 만들 때는 `codex/` prefix 브랜치를 사용한다.

임시 커밋이 많은 경우 main에 합칠 때 squash merge를 사용하고, 의미 있는 커밋이 여러 개인 경우 rebase 후 fast-forward merge를 사용한다.

## 커밋

Conventional Commits를 따른다.

예:

```text
feat: add idempotent installer update flow
refactor: split install helpers
docs: document update contract
```
