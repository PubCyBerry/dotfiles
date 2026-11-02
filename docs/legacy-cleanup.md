# 구버전 설치 잔재 정리 (에이전트용 프롬프트)

> 2026-11 lean 리팩터링(#10) 이전 install로 설치한 머신을 정리한다. 정리할 머신이 남지 않으면 이 파일을 지운다.
>
> 사용법: dotfiles 저장소를 최신 `main`으로 pull한 뒤, 그 머신의 에이전트(Claude Code, Codex 등)에게
> "`docs/legacy-cleanup.md`를 읽고 그대로 수행해"라고 요청한다.

아래는 에이전트에게 주는 지시다.

---

이 머신에는 예전 버전의 dotfiles가 설치되어 있다. 예전 install은 설치 기록(receipt)과 백업 파일을 남겼고, 지금은 관리하지 않는 도구와 설정을 설치했다. 새 install은 그것들을 지우지 않는다. 잔재를 찾아 정리한 뒤 새 install을 실행하고 결과를 보고한다.

## 원칙

- 먼저 조사만 한다. 찾은 항목을 표(경로, 근거, 처리)로 보고한 뒤 정리한다.
- **바로 정리**로 표시한 항목은 보고 후 지운다. **확인 필요** 항목은 사용자에게 묻고 승인받은 것만 지운다.
- 이 문서에 없는 것은 지우지 않는다. 판단이 서지 않으면 남기고 보고한다.
- receipt는 맨 마지막에 지운다. 어떤 패키지를 dotfiles가 새로 설치했는지 판단하는 근거다.
- 지금 실행 중인 에이전트 자신(Claude Code, Codex)의 바이너리는 지우지 않는다. 필요하면 사용자가 별도 터미널에서 실행할 명령을 안내한다.
- 관리자 권한(UAC, sudo 비밀번호)이 필요한 명령은 직접 실행하지 말고 사용자에게 안내한다. 단, Linux에서 sudo가 비밀번호 없이 되거나 root면 실행해도 된다.

## 1. 준비

1. dotfiles 저장소(`~/dotfiles`, `%USERPROFILE%\dotfiles`)가 최신 `main`인지 확인한다. 새 버전에는 `uninstall.sh`가 없고 `manifests/github-releases.tsv`가 있다.
2. receipt를 찾는다. 같은 디렉터리의 `install-receipt.json.bak-*`도 사본이다.
   - Windows: `%LOCALAPPDATA%\dotfiles\install-receipt.json`
   - Linux·macOS: `${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install-receipt.json`
3. receipt가 있으면 dotfiles가 새로 설치한 패키지 목록을 먼저 뽑아 둔다. `winget:Gyan.FFmpeg`, `apt:ffmpeg`처럼 나온다. 목록에 없는 패키지는 dotfiles 이전부터 있던 것이다.

   ```bash
   jq -r '.packages | to_entries[] | select(.value.before.present == false) | .key' install-receipt.json
   ```

## 2. 모든 OS

| 항목 | 확인 | 처리 |
|---|---|---|
| caveman 플러그인 | `claude plugin list`에 `caveman@caveman` | 바로 정리: `claude plugin uninstall caveman@caveman --scope user`, `claude plugin marketplace remove caveman`, `~/.claude/.caveman-*`, `~/.claude/plugins/cache/caveman` |
| agent role 3종 | `~/.claude/agents/{planner,generator,evaluator}.md`, `~/.codex/agents/{planner,generator,evaluator}.toml`, `~/.codex/skills/{planner,generator,evaluator}/` | 바로 정리. 디렉터리가 비면 디렉터리도 지운다. 다른 이름의 agent는 사용자 것이므로 둔다 |
| rhwp | `~/rhwp`, MCP 등록 3곳 | 바로 정리: `claude mcp remove rhwp -s user`, `codex mcp remove rhwp`, `~/.gemini/config/mcp_config.json`에서 `.mcpServers.rhwp` 삭제. command가 `rhwp` 디렉터리를 가리키는 등록만 지운다 |
| 예전 로컬 skill 사본 | `~/.gemini/config/skills/{subagent-creator,repo-scaffold}`가 실제 디렉터리 | 바로 정리. 심볼릭 링크면 다른 도구 소유이므로 둔다. `~/.claude/skills`의 같은 이름은 새 install이 덮어쓰므로 둔다 |
| Neovim yazi 플러그인 | `lua/plugins/yazi.lua` (Windows `%LOCALAPPDATA%\nvim`, Unix `~/.config/nvim`) | 바로 정리. 새 install은 남은 파일을 지우지 않는다 |
| 백업 파일 | `~/.claude`, `~/.codex`, `~/.gemini`, `~/.tmux.conf`, herdr·yazi·nvim 설정 디렉터리의 `*.dotfiles-backup`, `*.dotfiles-backup.<숫자>` | 바로 정리. 예전 install이 덮어쓰기 전 원본을 남긴 것이고 쓰는 곳이 없다 |

새 install은 기존 값이 이기는 병합이라, 아래 옛 값이 남아 있으면 고쳐지지 않는다. 해당하면 jq·yq로 고친 뒤 결과가 올바른 JSON·TOML인지 확인하고 같은 파일에 쓴다(BOM 없는 UTF-8).

- `~/.claude/settings.json`, `~/.codex/hooks.json`: 예전 statusLine 명령(`claude-hud`를 포함하거나 정확히 `ccusage statusline`), 예전 환경변수 `CLAUDE_CODE_SUBAGENT_MODEL`, `SessionStart`에 남은 `temporal-context.sh` hook(지금은 `UserPromptSubmit`에서 돈다)을 지운다. 다른 hook(Orca 등)과 사용자가 만든 statusLine은 둔다.

  ```bash
  jq 'if ((.statusLine.command // "") | contains("claude-hud") or . == "ccusage statusline") then del(.statusLine) else . end
    | del(.env.CLAUDE_CODE_SUBAGENT_MODEL)
    | if .hooks.SessionStart then
        .hooks.SessionStart |= (map(.hooks |= map(select((.command // "") | contains("temporal-context.sh") | not))) | map(select(.hooks | length > 0)))
        | if (.hooks.SessionStart | length) == 0 then del(.hooks.SessionStart) else . end
      else . end' FILE
  ```

- herdr `config.toml`(Windows `%APPDATA%\herdr\config.toml`, Unix `~/.config/herdr/config.toml`): herdr가 남긴 빈 값(`default_shell = ""`, `shell_mode = ""`)을 지운다. 실제 값은 둔다.

  ```bash
  yq -p toml -o toml 'del(.terminal.default_shell | select(. == "")) | del(.terminal.shell_mode | select(. == ""))' FILE
  ```

## 3. Windows

| 항목 | 확인 | 처리 |
|---|---|---|
| yazi | winget `sxyazi.yazi`, `%APPDATA%\yazi`, User 환경변수 `YAZI_FILE_ONE` | 바로 정리: `winget uninstall --id sxyazi.yazi --exact --silent`, 설정 디렉터리 삭제, `HKCU\Environment`에서 `YAZI_FILE_ONE` 값 삭제 |
| yazi 미리보기 의존성 | winget `Gyan.FFmpeg`, `oschwartz10612.Poppler`, `ImageMagick.ImageMagick` | 확인 필요. receipt 목록에 있으면 dotfiles가 설치한 것이다. ImageMagick은 시스템 범위라 UAC가 뜨므로 사용자에게 명령만 안내한다 |
| 고정 버전 shellcheck | `%USERPROFILE%\.local\bin\shellcheck.exe` | 바로 정리. 남겨 두면 새 install이 winget으로 깐 shellcheck보다 앞에 잡힌다 |
| 중복 Neovim PATH | User PATH의 `C:\Program Files\Neovim\bin` | Machine PATH에도 있으면 User 쪽만 바로 정리 |
| `WINGET_PKGS` 변수 | User 환경변수 `WINGET_PKGS`, PATH의 `%WINGET_PKGS%\...` | 값이 `%LOCALAPPDATA%\Microsoft\WinGet\Packages`면 PATH 항목을 `%LOCALAPPDATA%\Microsoft\WinGet\Packages\...`로 바꾼 뒤 변수 삭제 |
| PATH 백업 | `%USERPROFILE%\env_user_backup_*.reg`, `env_system_backup_*.reg` | 확인 필요. 예전 PATH 정리 스크립트가 남긴 백업이다 |
| herdr preview 채널 | `herdr --version`에 `preview` | 바로 정리: `herdr channel set stable`. 거부되면 `herdr update`를 한 번 실행한 뒤 다시 시도한다 |
| winget으로 깐 Claude Code | `winget list --id Anthropic.ClaudeCode --exact` | 확인 필요. 새 install은 공식 installer를 쓰고 winget 목록에서 뺐으므로 업데이트가 멈춘다. 사용자에게 안내: 에이전트를 끄고 별도 터미널에서 `winget uninstall --id Anthropic.ClaudeCode --exact` 후 `irm https://claude.ai/install.ps1 \| iex` |

환경변수와 PATH는 PowerShell로 레지스트리를 직접 다룬다.

- `[Environment]::SetEnvironmentVariable(name, $null, 'User')`는 변수를 지우지 않고 빈 문자열로 남긴다. `[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true).DeleteValue(name)`을 쓴다.
- PATH는 `GetValue('Path', '', 'DoNotExpandEnvironmentNames')`로 읽고, 값 종류(`ExpandString`)를 유지해 다시 쓴다.

## 4. Linux

| 항목 | 확인 | 처리 |
|---|---|---|
| manifest에서 빠진 apt 패키지 | `fonts-firacode`, `fonts-powerline`, `ffmpeg`, `poppler-utils`, `imagemagick`, `7zip`, `file` | 확인 필요. receipt 목록에 있는 것만 후보다. `apt-get remove`가 함께 지우려는 패키지를 보여 주고 승인받는다(`file`은 다른 패키지가 의존하는 경우가 많다). 폰트를 지웠으면 `fc-cache -f` |
| 더 이상 설치하지 않는 도구 | `~/.local/bin/{atuin,yazi,ya,shellcheck}`, `~/.config/yazi` | 바로 정리. shellcheck는 apt 패키지가 대신한다 |
| atuin 데이터 | `~/.local/share/atuin`, `~/.config/atuin` | 확인 필요. 셸 기록이 들어 있을 수 있다 |
| 위치가 바뀐 fnm | `~/.local/bin/fnm`이 `~/.local/share/fnm/fnm`을 가리키는 링크 | 바로 정리: 링크와 `~/.local/share/fnm/fnm` 파일만 지운다. `~/.local/share/fnm`의 나머지(`node-versions`, `aliases`)는 절대 지우지 않는다 |
| 위치가 바뀐 bun | `~/.local/bin/bun`이 `~/.bun/bin/bun`을 가리키는 링크 | 바로 정리: 링크, `~/.bun/bin/bun`, `~/.bun/bin/bunx`(bun 링크)만 지운다. `~/.bun`의 다른 파일(전역 패키지, 캐시)은 둔다 |
| 위치가 바뀐 nvim | `~/.local/bin/nvim`이 `~/.local/opt/nvim-v*`를 가리키는 링크 | 바로 정리: 링크와 `~/.local/opt/nvim-v*`를 지운다. 새 위치는 `~/.local/opt/nvim`이다 |
| npm으로 깐 Claude Code | `npm ls -g @anthropic-ai/claude-code` | 확인 필요. 새 install은 공식 installer를 쓴다. 새 install 후 사용자에게 `fnm exec --using=<예전 Node 버전> npm uninstall -g @anthropic-ai/claude-code`를 안내한다 |

fnm·bun·nvim은 새 install이 최신 릴리스를 새 위치에 다시 받는다. 새 install을 실행하기 전에 정리해야 한다.

## 5. macOS

| 항목 | 확인 | 처리 |
|---|---|---|
| 예전 Brewfile에만 있던 formula | `atuin`, `yazi` | 바로 정리: `brew uninstall` |
| Windows와 맞추며 뺀 formula | `ruff`, `difftastic`, `ast-grep`, `wget`, `vim`, `curl` | 확인 필요. 쓰는 것이 있으면 둔다 |
| tap으로 깐 bun | `brew list oven-sh/bun/bun` | 바로 정리: `brew uninstall oven-sh/bun/bun && brew untap oven-sh/bun`. 새 Brewfile은 core `bun`을 쓴다 |
| cask로 깐 Claude Code | `brew list --cask claude-code` | 확인 필요. 사용자에게 안내: 에이전트를 끄고 `brew uninstall --cask claude-code` 후 `curl -fsSL https://claude.ai/install.sh \| bash` |
| 고정 버전 shellcheck | `~/.local/bin/shellcheck` | 바로 정리. brew `shellcheck`가 대신한다 |
| 예전 셸 블록 | `~/.zprofile`, `~/.bashrc`, `~/.inputrc`의 `# ===== dotfiles-begin =====` ~ `# ===== dotfiles-end =====` | 바로 정리: 마커를 포함해 블록만 지운다. 새 install은 `~/.zshrc`에만 블록을 둔다 |

예전에 적용한 macOS 시스템 기본값(`.macos`)은 되돌리지 않는다.

## 6. 새 install 실행

- Windows: PowerShell 7에서 `pwsh -ExecutionPolicy Bypass -File <저장소>\install.ps1`. Git Bash·tmux가 떠 있으면 Git·psmux 업그레이드가 실패할 수 있다. 실패한 패키지는 보고하고, 해당 프로세스를 닫은 뒤 다시 실행하도록 안내한다.
- Linux·macOS: `bash <저장소>/install.sh`
- 마지막의 실패 요약을 그대로 보고한다.

## 7. 설치 후 정리

1. `nvim --headless "+Lazy! clean" +qa`로 yazi.nvim, plenary.nvim을 지운다.
2. Linux: `~/.local/bin/{fnm,bun,nvim}`이 새 위치(일반 파일, `~/.local/opt/nvim`)를 가리키는지 확인한다.
3. receipt 디렉터리(Windows `%LOCALAPPDATA%\dotfiles`, Unix `~/.local/state/dotfiles`)를 지운다.
4. 확인 필요: 쓰지 않는 Node 버전. `fnm list`를 보여 주고, 사용자가 고른 버전만 `fnm uninstall <버전>`으로 지운다. 기본 버전은 남긴다.

## 8. 보고

다음을 짧게 보고한다.

- 지운 것
- 남긴 것과 이유(확인 필요 항목, 관리자 권한이 필요한 명령)
- 새 install 결과(실패한 단계와 원인)
