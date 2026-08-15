# Safe-Clean-Uninstall

설치 receipt에 기록된 소유권과 현재 identity가 정확히 일치하는 항목만 제거하거나 설치 전 상태로 복원한다.

## 실행

Windows PowerShell 7+:

```powershell
pwsh -ExecutionPolicy Bypass -File .\uninstall.ps1
```

Ubuntu/macOS:

```bash
bash uninstall.sh
```

패키지를 그대로 두고 dotfiles 소유권만 넘기려면 `-KeepPackages`(Windows) 또는 `--keep-packages`(Unix)를 사용한다.

## 안전 계약

- receipt가 없으면 정확히 한 쌍의 순서가 정상인 `dotfiles-begin`/`dotfiles-end` profile block만 제거한다.
- receipt가 invalid, directory, symlink이거나 entry path/key가 installer manifest와 exact allowlist 밖이면 marker를 포함해 아무것도 변경하지 않고 경고한다. `fnm`/`bun` anchor, direct-child binary와 agent의 정확한 확장자만 허용한다.
- unchanged file/symlink/direct tree만 제거한다. 설치 전 파일은 검증된 sibling backup에서 원래 mode로 복원한다.
- direct tree에 파일, socket 등 항목이 하나라도 추가되거나 mode/content가 바뀌면 전체 tree를 보존한다.
- Git 설정, `YAZI_FILE_ONE`, User `PATH`는 현재 값이 설치 identity와 정확히 일치할 때만 복원한다. PATH는 대소문자 무시 exact segment가 한 번 있을 때만 그 한 항목을 제거한다.
- rhwp는 `~/rhwp`(Windows `%USERPROFILE%\rhwp`) direct tree 하나로 관리한다. tree 해시가 receipt와 정확히 일치할 때만 통째로 제거하고, 안에 파일이 하나라도 추가·변경되면 전체를 보존한다. 설치 전부터 그 자리에 tree가 있었다면 install이 애초에 소유하지 않으므로 uninstall도 손대지 않는다.
- MCP entry(`~/.codex/config.toml`의 `[mcp_servers.rhwp]`, `~/.claude.json`의 `.mcpServers.rhwp`)는 현재 값이 설치한 값과 정확히 같을 때만 제거한다. 사용자가 만든 동명 entry나 우리가 심은 뒤 수정된 entry는 보존한다. 마지막 entry였으면 빈 `[mcp_servers]` 테이블까지 걷어내고, install이 직접 만든 `~/.claude.json`이 정확히 `{"mcpServers":{}}`로 남았을 때만 그 파일도 제거한다. `~/.claude/settings.json`은 MCP 정의 파일이 아니므로 이 경로에 관여하지 않는다.
- 설치 전부터 있던 패키지는 제거하거나 downgrade하지 않는다. 새로 설치된 unchanged 패키지만 제거한다. npm은 receipt의 설치 당시 global prefix가 exact `FNM_DIR/node-versions/<version>/installation`이 아니면 보존한다.
- `~/.claude/settings.json`은 설치 마지막 단계의 `claude plugin` CLI가 다시 쓴다. install은 그 직후 소유권 해시를 설치 종료 시점 내용으로 갱신하므로, uninstall이 이 파일을 backup에서 복원할 수 있고 그 과정에서 `enabledPlugins`/`extraKnownMarketplaces` 등록도 함께 사라진다. `~/.claude/plugins/` 자체는 범위 밖이라 디스크에 남는다. 갱신은 install이 실제로 그 파일을 배포한 실행에서만 일어난다 — 보존으로 끝난 파일은 소유권에 들어가지 않는다.
- 각 항목 완료 직후 receipt를 atomic 저장하므로 중단 후 다시 실행할 수 있다. 두 번째 실행은 no-op이다.

자동 제거하지 않는 범위: receipt에 없는 Node 버전, remote skills, plugins/marketplaces, macOS defaults, legacy Codex skills, cache와 사용자 data.

변경되거나 provenance가 부족해 보존된 항목은 경고와 receipt entry가 남는다. 사용자가 내용을 확인하고 직접 정리하거나 원래 identity로 되돌린 뒤 스크립트를 다시 실행한다.
