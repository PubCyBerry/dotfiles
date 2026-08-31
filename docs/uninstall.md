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
- MCP entry(`~/.codex/config.toml`의 `[mcp_servers.rhwp]`, `~/.claude.json`의 `.mcpServers.rhwp`, `~/.gemini/config/mcp_config.json`의 `.mcpServers.rhwp`)는 현재 값이 설치한 값과 정확히 같을 때만 제거한다. 사용자가 만든 동명 entry나 우리가 심은 뒤 수정된 entry는 보존한다. 마지막 entry였으면 빈 `[mcp_servers]` 테이블까지 걷어내고, install이 직접 만든 `~/.claude.json` 또는 `~/.gemini/config/mcp_config.json`이 정확히 `{"mcpServers":{}}`로 남았을 때만 그 파일도 제거한다. `~/.claude/settings.json`은 MCP 정의 파일이 아니므로 이 경로에 관여하지 않는다.
- shellcheck는 `manifests/shellcheck.tsv`가 pin한 direct artifact다. `~/.local/bin/shellcheck`(Windows `%USERPROFILE%\.local\bin\shellcheck.exe`)가 설치 당시 내용과 정확히 같을 때만 제거하고, 사용자가 바꿨으면 보존한다. 설치가 User `PATH`나 셸 프로파일을 건드리지 않으므로(이 저장소가 배포하는 프로파일이 이미 `~/.local/bin`을 PATH 앞에 둔다) 되돌릴 PATH 항목도 없다.
- Antigravity CLI(`agy`) 바이너리는 제거 대상이 아니다. herdr와 같은 이유로 install이 애초에 소유하지 않는다 — 공식 installer가 설치하고 CLI가 스스로 업데이트한다. `~/.gemini/` 아래 **설정**만 소유권 판정을 거쳐 제거한다.
- 그래서 Antigravity CLI 부트스트랩이 남긴 아래 항목은 uninstall 뒤에도 그대로 있다. 근거는 `AGENTS.md`의 "Antigravity CLI 관리 → 공식 installer가 만드는 side effect"에 있다.
  - Windows: `%LOCALAPPDATA%\agy\bin\agy.exe`, `%LOCALAPPDATA%\antigravity\staging`
  - Linux/macOS: `~/.local/bin/agy`, `~/.cache/antigravity/staging`
  - installer 마지막 단계의 `agy install`이 설정한 셸 환경
- herdr는 설정만 제거 대상이다. `%APPDATA%\herdr\config.toml`(Windows) / `~/.config/herdr/config.toml`(Linux·macOS)이 설치 당시 내용과 정확히 같을 때만 제거·복원한다. 바이너리는 공식 installer(macOS는 Homebrew)가 설치하고 herdr가 스스로 업데이트하므로 install이 애초에 소유하지 않는다 — uninstall도 손대지 않는다.
- 그래서 herdr 부트스트랩이 남긴 아래 항목은 uninstall 뒤에도 그대로 있다. 지우려면 직접 정리한다. 근거는 `AGENTS.md`의 "herdr 관리 → 공식 installer가 만드는 side effect"에 있다.
  - Windows User `PATH`(`HKCU\Environment`)의 `%LOCALAPPDATA%\Programs\Herdr\bin` segment. 이 항목만 install의 `Add-ToUserPath` + receipt 경로를 타지 않아 다른 PATH 항목과 달리 복원 대상이 아니다.
  - `%LOCALAPPDATA%\Programs\Herdr\bin`, `%USERPROFILE%\.herdr\`(릴리즈 디렉터리 + junction), Linux는 `~/.local/bin/herdr`.
  - macOS는 Homebrew 소유이므로 `brew uninstall herdr`.
- 설치 전부터 있던 패키지는 제거하거나 downgrade하지 않는다. 새로 설치된 unchanged 패키지만 제거한다. npm은 receipt의 설치 당시 global prefix가 exact `FNM_DIR/node-versions/<version>/installation`이 아니면 보존한다.
- `~/.claude/settings.json`은 설치 마지막 단계의 `claude plugin` CLI가 다시 쓴다. install은 그 직후 소유권 해시를 설치 종료 시점 내용으로 갱신하므로, uninstall이 이 파일을 backup에서 복원할 수 있고 그 과정에서 `enabledPlugins`/`extraKnownMarketplaces` 등록도 함께 사라진다. `~/.claude/plugins/` 자체는 범위 밖이라 디스크에 남는다. 갱신은 install이 실제로 그 파일을 배포한 실행에서만 일어난다 — 보존으로 끝난 파일은 소유권에 들어가지 않는다.
- 각 항목 완료 직후 receipt를 atomic 저장하므로 중단 후 다시 실행할 수 있다. 두 번째 실행은 no-op이다.

- 구 apt/brew shellcheck 설치분(`apt:shellcheck`, `brew:shellcheck`)은 `manifests/apt.txt`·`manifests/Brewfile`에서 빠졌지만 그 시절 설치본을 쓰던 머신 receipt에는 남아 있다. 그래서 이 두 key만 고정 목록으로 소유권을 인정한다 — 인정하지 않으면 preflight가 uninstall 전체를 중단시켜 무관한 항목까지 하나도 정리되지 않는다. 제거 여부는 여전히 설치 당시 버전과의 대조가 정하므로, 사용자가 직접 올린 패키지는 보존된다.
  - install은 이 패키지를 지우지 않는다. manifest에서 뺐다는 것은 앞으로 설치하지 않는다는 뜻일 뿐이라, 업그레이드한 머신에는 구 `/usr/bin/shellcheck`가 그대로 남아 pin한 `~/.local/bin/shellcheck`와 공존한다. 직접 정리하는 명령은 [docs/tools.md의 shellcheck 절](tools.md#shellcheck--셸-스크립트-정적-분석)에 있다. 먼저 지우고 나서 uninstall을 돌려도 문제없다 — 패키지가 없으면 receipt entry만 조용히 걷힌다.


- statusline은 파일 둘을 소유한다: wrapper(`~/.claude/statusline.sh`)와 claude-hud 설정 override(`~/.claude/claude-hud.json`). 둘 다 receipt 소유권 판정을 거쳐 제거되며, 사용자가 고쳤으면 보존된다. `claude-hud` 플러그인 자체는 `claude plugin` CLI 소유라 receipt 범위 밖이라 install도 uninstall도 지우지 않는다 — 필요하면 직접 정리한다.

  ```bash
  claude plugin uninstall claude-hud@claude-hud
  claude plugin marketplace remove claude-hud
  ```

  `settings.json`의 `statusLine` 키는 dotfiles 관리 키라 uninstall이 걷어낸다. 기존 설치에 남은 옛 statusline 명령(`/claude-hud:setup`이 만든 명령줄, `ccusage statusline`)은 다음 install의 병합이 교체한다 — `AGENTS.md`의 "statusline 관리" 참고.

- 구 로컬 skill 배포분(`~/.claude/skills/{subagent-creator,repo-scaffold}/`, `~/.gemini/config/skills/{subagent-creator,repo-scaffold}/`)은 소스가 저장소에서 사라졌지만 receipt entry는 남아 있다. 그래서 이 두 이름만 고정 목록으로 소유권을 인정하고, unchanged 파일에 한해 제거한다. `npx skills`가 새로 설치한 skill은 receipt에 없으므로 이 경로에 걸리지 않는다.

자동 제거하지 않는 범위: receipt에 없는 Node 버전, `npx skills`가 설치한 skills(`npx skills remove`로 지운다), plugins/marketplaces, macOS defaults, legacy Codex skills, cache와 사용자 data.

변경되거나 provenance가 부족해 보존된 항목은 경고와 receipt entry가 남는다. 사용자가 내용을 확인하고 직접 정리하거나 원래 identity로 되돌린 뒤 스크립트를 다시 실행한다.
