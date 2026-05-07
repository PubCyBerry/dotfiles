# CI

이 저장소의 CI는 설치 스크립트가 깨지지 않는지 빠르게 확인하고, 외부 도구 release 변화도 추적한다.

## PR Gate

`.github/workflows/pr-gate.yml`

검증 항목:

- `shellcheck -x install.sh scripts/install/lib.sh`
- PowerShell parse check for `install.ps1`, `scripts/install/lib.ps1`
- Bash/PowerShell dry-run smoke test
- Ubuntu install smoke test
- config와 manifest syntax check
- 임시 HOME에서 config update를 2회 실행하는 idempotency check

## Freshness Check

`.github/workflows/freshness-check.yml`

`manifests/tools.tsv`의 GitHub repo 목록을 읽어 최신 release tag를 주 1회 수집한다. 결과는 Actions artifact로 저장된다.

## 로컬 검증

```bash
shellcheck -x install.sh scripts/install/lib.sh
bash install.sh --dry-run --only configs
```

```powershell
.\install.ps1 --dry-run --only configs
```
