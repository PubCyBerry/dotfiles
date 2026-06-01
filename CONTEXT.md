# CONTEXT.md

## 작업 인계

- 목표: Codex/Claude Code 설치 설정에서 caveman hook 제거 후 커밋, 푸시.
- 현재 상태: 완료. caveman hook 제거, JSON 검증, 커밋/푸시 수행.
- 완료한 일: temporal context hook과 Claude RTK hook은 유지.
- 남은 일: 없음.
- 변경한 파일: `config/codex/hooks.json`, `config/claude/settings.json`, `CONTEXT.md`.
- 검증 결과: `jq empty config/codex/hooks.json`, `jq empty config/claude/settings.json` 통과. `rg -n "CAVEMAN|caveman mode|Loading caveman mode" config install.ps1 install.sh docs AGENTS.md README.md manifests` 결과 없음.
