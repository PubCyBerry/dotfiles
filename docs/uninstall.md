# 클린 언인스톨

dotfiles가 설치한 모든 항목을 제거하는 방법. 필요한 항목만 선택적으로 제거 가능.

## Windows

`install.ps1`의 실행 순서와 동일한 번호로 구성. PowerShell 7+ (pwsh)에서 실행.

> **주의**: `>` 표시 항목은 사용자 데이터까지 삭제될 수 있으므로 주의해서 실행할 것.

---

### 1. winget 패키지 제거

개별 제거:

```powershell
winget uninstall --id <패키지ID>
```

manifests/winget.txt 기반 일괄 제거:

```powershell
Get-Content .\manifests\winget.txt |
    Where-Object { $_.Trim() -and -not $_.Trim().StartsWith('#') } |
    ForEach-Object { ($_ -split '#')[0].Trim() } |
    Where-Object { $_ } |
    ForEach-Object { winget uninstall --id $_ --silent }
```

패키지 목록:

| ID | 용도 |
|----|------|
| `Git.Git` | Git for Windows (Git Bash 포함) |
| `GitHub.cli` | GitHub CLI (`gh`) |
| `Neovim.Neovim` | 텍스트 에디터 |
| `Schniz.fnm` | Node.js 버전 관리 |
| `Oven-sh.Bun` | JavaScript 런타임 |
| `marlocarlo.psmux` | tmux on Windows PowerShell |
| `sharkdp.bat` | 구문 강조 `cat` |
| `junegunn.fzf` | 퍼지 파인더 |
| `eza-community.eza` | 현대적 `ls` |
| `sharkdp.fd` | 현대적 `find` |
| `dandavison.delta` | git diff pager |
| `BurntSushi.ripgrep.MSVC` | 고속 grep (`rg`) |
| `jqlang.jq` | JSON 처리 |
| `mikefarah.yq` | YAML/TOML/JSON 처리 |
| `ajeetdsouza.zoxide` | 스마트 cd (`z`) |
| `Starship.Starship` | 셸 프롬프트 |
| `sxyazi.yazi` | 터미널 파일 매니저 |
| `Gyan.FFmpeg` | 동영상 처리 |
| `oschwartz10612.Poppler` | PDF 처리 |
| `ImageMagick.ImageMagick` | 이미지 처리 |

---

### 1-1. Git 전역 설정 제거

dotfiles가 병합한 항목만 선택적 제거:

```powershell
git config --global --unset core.pager
git config --global --unset core.editor
git config --global --unset core.fileMode
git config --global --unset core.autocrlf
git config --global --unset core.eol
git config --global --unset interactive.diffFilter
git config --global --unset delta.navigate
git config --global --unset delta.dark
git config --global --unset delta.side-by-side
git config --global --unset delta.line-numbers
git config --global --unset merge.conflictStyle
```

> **전체 삭제** (사용자 커스텀 설정도 함께 삭제됨):
> ```powershell
> Remove-Item "$env:USERPROFILE\.gitconfig" -Force
> ```

---

### 1-2. tmux 설정 제거

```powershell
Remove-Item "$env:USERPROFILE\.tmux.conf" -Force
```

---

### 1-3. YAZI_FILE_ONE 환경 변수 제거

```powershell
[System.Environment]::SetEnvironmentVariable("YAZI_FILE_ONE", $null, "User")
```

확인:

```powershell
[System.Environment]::GetEnvironmentVariable("YAZI_FILE_ONE", "User")  # 아무것도 출력 안 되면 성공
```

---

### 1-4. Yazi 설정 제거

> **사용자가 추가한 yazi 설정도 함께 삭제됨.**

```powershell
Remove-Item "$env:APPDATA\yazi\config" -Recurse -Force
```

---

### 1-5. Neovim PATH 제거

User PATH에서 Neovim bin 경로 제거:

```powershell
$nvimBin  = "C:\Program Files\Neovim\bin"
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$newPath  = ($userPath -split ';' | Where-Object { $_ -ne $nvimBin }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

---

### 1-6. Neovim 설정 제거

> **lazy.nvim으로 설치된 모든 플러그인과 사용자 추가 설정까지 삭제됨.**

```powershell
# 설정 파일 (init.lua, lua/)
Remove-Item "$env:LOCALAPPDATA\nvim" -Recurse -Force

# 플러그인 캐시 및 데이터
Remove-Item "$env:LOCALAPPDATA\nvim-data" -Recurse -Force
```

---

### 2. Node.js LTS (fnm) 제거

특정 버전만 제거:

```powershell
fnm uninstall lts-latest
```

fnm 자체 제거 (winget):

```powershell
winget uninstall --id Schniz.fnm
```

fnm 데이터 디렉토리 제거:

```powershell
Remove-Item "$env:LOCALAPPDATA\fnm" -Recurse -Force
```

User PATH에서 fnm aliases/default 제거:

```powershell
$fnmDefault = "$env:APPDATA\fnm\aliases\default"
$userPath   = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$newPath    = ($userPath -split ';' | Where-Object { $_ -ne $fnmDefault }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

---

### 2-2. Codex 설정 제거

선택적 제거 (권장):

```powershell
# dotfiles가 복사한 공통 지침과 hooks 제거
Remove-Item "$env:USERPROFILE\.codex\AGENTS.md" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.codex\hooks.json" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:USERPROFILE\.codex\hooks" -Recurse -Force -ErrorAction SilentlyContinue
```

`config.toml`에는 프로젝트 trust, 플러그인, Desktop 상태, 머신별 경로처럼 Codex가 직접 관리하는 값이 함께 들어갈 수 있다. 전체 삭제보다 dotfiles 기본값만 제거한다.

```powershell
$configPath = "$env:USERPROFILE\.codex\config.toml"
if (Test-Path $configPath) {
    $managedTop = @("model", "model_reasoning_effort")
    $managedSections = @("windows", "desktop", "features")
    $current = ""
    $skip = $false
    $out = [System.Collections.Generic.List[string]]::new()

    foreach ($line in Get-Content $configPath) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') {
            $current = $Matches[1]
            $skip = $managedSections -contains $current
            if (-not $skip) { $out.Add($line) }
            continue
        }
        if ($skip) { continue }
        if (-not $current -and $trimmed -match '^([^=\s]+)\s*=') {
            if ($managedTop -contains $Matches[1]) { continue }
        }
        $out.Add($line)
    }

    $newContent = (($out -join "`n").Trim() + "`n")
    if ($newContent.Trim()) {
        $newContent | Out-File $configPath -Encoding utf8 -NoNewline
    } else {
        Remove-Item $configPath -Force
    }
}
```

> **전체 삭제** (Codex trust, 플러그인, Desktop 상태까지 함께 삭제될 수 있음):
> ```powershell
> Remove-Item "$env:USERPROFILE\.codex" -Recurse -Force
> ```

---

### 3. Claude Code 제거

Windows 설정 > 앱에서 "Claude Code" 검색 후 제거, 또는:

```powershell
Remove-Item -Path "$env:USERPROFILE\.local\bin\claude.exe" -Force
Remove-Item -Path "$env:USERPROFILE\.local\share\claude" -Recurse -Force
```

> Claude Code 설정(`~/.claude/`)은 아래 3-1에서 별도로 제거.

---

### 3-1. Claude Code 설정 제거

선택적 제거 (권장):

```powershell
# dotfiles가 복사한 CLAUDE.md만 제거
Remove-Item "$env:USERPROFILE\.claude\CLAUDE.md" -Force

# settings.json에서 dotfiles가 넣은 hook만 제거 (SessionStart — temporal-context)
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$settings.hooks.PSObject.Properties.Remove("SessionStart")
$settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
```

settings.json에서 dotfiles가 추가한 키 제거:

```powershell
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
# 필요한 키만 제거 (예: hooks)
$settings.PSObject.Properties.Remove("hooks")
$settings.PSObject.Properties.Remove("env")
$settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
```

> **전체 삭제** (대화 기록, 메모리, 모든 설정 포함):
> ```powershell
> Remove-Item "$env:USERPROFILE\.claude" -Recurse -Force
> Remove-Item -Path "$env:USERPROFILE\.claude.json" -Force
> ```

---

### 3-2. RTK (Rust Token Killer) 제거 — 레거시

> 현재 install 스크립트는 RTK를 설치하지 않는다. 과거 버전으로 설치한 머신에만 필요하다.
> `settings.json` 병합은 기존 키를 보존하므로, 저장소에서 hook을 지워도 이미 배포된
> `~/.claude/settings.json`의 엔트리는 남는다. 아래로 직접 제거한다.

```powershell
# 1. 바이너리
Remove-Item "$env:USERPROFILE\.local\bin\rtk.exe" -Force -ErrorAction SilentlyContinue

# 2. Claude hook — PreToolUse에서 rtk 항목만 골라 제거 (다른 hook은 보존)
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.hooks.PreToolUse) {
        $kept = @($settings.hooks.PreToolUse | ForEach-Object {
            $_.hooks = @($_.hooks | Where-Object { $_.command -notmatch '^\s*rtk\b' })
            $_
        } | Where-Object { $_.hooks.Count -gt 0 })
        if ($kept.Count -gt 0) { $settings.hooks.PreToolUse = $kept }
        else { $settings.hooks.PSObject.Properties.Remove("PreToolUse") }
        $settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
    }
}

# 3. 캐시/통계 디렉터리 (rtk gain 히스토리)
Remove-Item "$env:LOCALAPPDATA\rtk" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\rtk"      -Recurse -Force -ErrorAction SilentlyContinue
```

Linux/macOS:

```bash
rm -f ~/.local/bin/rtk
rm -rf ~/.cache/rtk ~/.local/share/rtk ~/.config/rtk
jq '(.hooks.PreToolUse // []) |= (map(.hooks |= map(select((.command // "") | test("^\\s*rtk\\b") | not)))
     | map(select((.hooks | length) > 0)))' ~/.claude/settings.json > /tmp/s.json \
  && mv /tmp/s.json ~/.claude/settings.json
brew uninstall rtk 2>/dev/null || true   # macOS에서 Brewfile로 설치한 경우
```

> `~/.local/bin`은 claude native 바이너리도 쓰므로 PATH에서 지우지 않는다.

---

### 4. PowerShell 프로파일 정리

dotfiles 마커 블록(`# ===== dotfiles-begin =====` ~ `# ===== dotfiles-end =====`) 제거:

```powershell
function Remove-DotfilesProfileBlock([string]$Path) {
    if (-not (Test-Path $Path)) { return }
    $begin = "# ===== dotfiles-begin ====="
    $end = "# ===== dotfiles-end ====="
    $content = Get-Content $Path -Raw
    if ($null -eq $content) { $content = "" }
    $beginMatches = [regex]::Matches($content, "(?m)^$([regex]::Escape($begin))(?=\r?$)")
    $endMatches = [regex]::Matches($content, "(?m)^$([regex]::Escape($end))(?=\r?$)")
    $beginCount = [regex]::Matches($content, [regex]::Escape($begin)).Count
    $endCount = [regex]::Matches($content, [regex]::Escape($end)).Count

    if ($beginCount -eq 0 -and $endCount -eq 0) { return }
    if ($beginCount -ne 1 -or $endCount -ne 1 -or
        $beginMatches.Count -ne 1 -or $endMatches.Count -ne 1 -or
        $beginMatches[0].Index -ge $endMatches[0].Index) {
        throw "Invalid dotfiles marker state in $Path; file was not changed."
    }

    $afterEnd = $endMatches[0].Index + $endMatches[0].Length
    if ($content.Substring($afterEnd).StartsWith("`r`n")) { $afterEnd += 2 }
    elseif ($content.Substring($afterEnd).StartsWith("`n")) { $afterEnd++ }
    $content = $content.Substring(0, $beginMatches[0].Index) + $content.Substring($afterEnd)
    $content | Out-File $Path -Encoding utf8 -NoNewline
    Write-Host "dotfiles 블록 제거 완료: $Path"
}

Remove-DotfilesProfileBlock $PROFILE.CurrentUserCurrentHost
```

---

### 5. Git Bash 프로파일 정리

`.bashrc`, `.inputrc`, `.bash_profile`, macOS zsh profile에서 마커 블록 제거:

```bash
remove_profile_block() {
    file="$1"
    [ -f "$file" ] || return 0
    begin='# ===== dotfiles-begin ====='
    end='# ===== dotfiles-end ====='
    begin_exact=$(grep -Fxc -- "$begin" "$file" || true)
    end_exact=$(grep -Fxc -- "$end" "$file" || true)
    begin_any=$(grep -Fc -- "$begin" "$file" || true)
    end_any=$(grep -Fc -- "$end" "$file" || true)

    [ "$begin_any" -eq 0 ] && [ "$end_any" -eq 0 ] && return 0
    if [ "$begin_exact" -ne 1 ] || [ "$end_exact" -ne 1 ] ||
       [ "$begin_any" -ne 1 ] || [ "$end_any" -ne 1 ]; then
        echo "[!] Invalid dotfiles marker state in $file; file was not changed." >&2
        return 1
    fi
    begin_line=$(grep -nFx -- "$begin" "$file" | cut -d: -f1)
    end_line=$(grep -nFx -- "$end" "$file" | cut -d: -f1)
    if [ "$begin_line" -ge "$end_line" ]; then
        echo "[!] Invalid dotfiles marker order in $file; file was not changed." >&2
        return 1
    fi

    tmp=$(mktemp "${TMPDIR:-/tmp}/dotfiles-profile.XXXXXX")
    if ! awk -v begin="$begin" -v end="$end" '
        BEGIN { skip = 0; found_begin = 0; found_end = 0 }
        $0 == begin { found_begin++; skip = 1; next }
        skip && $0 == end { found_end++; skip = 0; next }
        !skip { print }
        END { if (skip || found_begin != 1 || found_end != 1) exit 1 }
    ' "$file" > "$tmp"; then
        rm -f "$tmp"
        echo "[!] Failed to remove dotfiles block from $file; file was not changed." >&2
        return 1
    fi
    mv "$tmp" "$file"
    echo "dotfiles 블록 제거 완료: $file"
}

status=0
for file in ~/.bashrc ~/.inputrc ~/.bash_profile ~/.zprofile ~/.zshrc; do
    remove_profile_block "$file" || status=1
done
[ "$status" -eq 0 ]
```

---

### 6. Claude Code Skills 제거

dotfiles 로컬 skill(저장소 소유, `config/claude/skills/`에서 배포) 제거:

```powershell
Remove-Item "$env:USERPROFILE\.claude\skills\subagent-creator" -Recurse -Force -ErrorAction SilentlyContinue
```

```bash
rm -rf "$HOME/.claude/skills/subagent-creator"
```

> dotfiles가 만든 로컬 skill 디렉터리만 제거하며, 아래 원격 skill과 사용자가 만든 subagent는 보존한다.

dotfiles agent role(저장소 소유, `config/agents/roles/`에서 조립 배포) 제거. Claude는 `~/.claude/agents/<name>.md`, Codex는 `~/.codex/agents/<name>.toml`에 배포된다. 구버전 dotfiles는 Codex 쪽을 `~/.codex/skills/<name>/`에 skill로 배포했으므로 그 경로도 함께 지운다:

```powershell
"planner","generator","evaluator" | ForEach-Object {
    Remove-Item "$env:USERPROFILE\.claude\agents\$_.md" -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:USERPROFILE\.codex\agents\$_.toml" -Force -ErrorAction SilentlyContinue
    # 구 배포 경로 (skill 시절)
    Remove-Item "$env:USERPROFILE\.codex\skills\$_" -Recurse -Force -ErrorAction SilentlyContinue
}
```

```bash
for n in planner generator evaluator; do
    rm -f "$HOME/.claude/agents/$n.md"
    rm -f "$HOME/.codex/agents/$n.toml"
    # 구 배포 경로 (skill 시절)
    rm -rf "$HOME/.codex/skills/$n"
done
```

> `config/agents/roles/`에 있는 이름만 대응해 제거한다. 사용자가 직접 만든 다른 agent/skill과 Codex 번들 skill(`~/.codex/skills/.system/`)은 남긴다.

원격 skill 개별 제거:

```powershell
npx skills remove anthropics/skills --skill skill-creator -g
npx skills remove anthropics/skills --skill pdf -g
npx skills remove anthropics/skills --skill pptx -g
npx skills remove anthropics/skills --skill docx -g
npx skills remove anthropics/skills --skill xlsx -g
```

설치된 전체 skills 확인:

```powershell
npx skills list -g
```

---

### 7. Claude Code 플러그인 제거

`manifests/plugins.txt`에 있는 플러그인만 제거한다. 플러그인 제거 후 마켓플레이스 등록도 함께 해제한다.

```powershell
# 플러그인 → 마켓플레이스 순서 (Windows / Linux / macOS 공통)
claude plugin uninstall claude-hud@claude-hud --scope user
claude plugin uninstall caveman@caveman --scope user
claude plugin uninstall codex@openai-codex --scope user

claude plugin marketplace remove claude-hud
claude plugin marketplace remove caveman
claude plugin marketplace remove openai-codex
```

설치 상태 확인:

```powershell
claude plugin list
claude plugin marketplace list
```

> `manifests/plugins.txt`에 있는 이름만 제거한다. 사용자가 직접 설치한 다른 플러그인과 `project`/`local` scope 플러그인은 남긴다. `~/.claude/plugins/` 디렉터리 전체를 지우면 그것들까지 사라지므로 CLI로만 제거한다.

---

## 완전 초기화 순서

모든 항목을 한 번에 제거할 경우 아래 순서를 권장:

1. **7** — Claude Code 플러그인 제거 (`claude` CLI 사용 가능할 때 먼저)
2. **6** — Claude Code Skills 제거 (npx skills 명령어 사용 가능할 때 먼저)
3. **3-2** — RTK 제거 (레거시 설치본이 있을 때만)
4. **3-1** — Claude Code 설정 제거
5. **3** — Claude Code 제거
6. **2-2** — Codex 설정 제거
7. **4** — PowerShell 프로파일 정리
8. **5** — Git Bash 프로파일 정리
9. **1-6** — Neovim 설정 제거
10. **1-5** — Neovim PATH 제거
11. **1-4** — Yazi 설정 제거
12. **1-3** — YAZI_FILE_ONE 환경 변수 제거
13. **1-2** — tmux 설정 제거
14. **1-1** — Git 전역 설정 제거
15. **2** — Node.js (fnm) 제거
16. **1** — winget 패키지 제거

---

## 선택적 제거 가이드

### Claude 관련만 제거

```powershell
# 플러그인 → Skills → 설정 → 앱 순서 (레거시 RTK는 3-2 참고)
claude plugin uninstall claude-hud@claude-hud --scope user
claude plugin uninstall caveman@caveman --scope user
claude plugin uninstall codex@openai-codex --scope user
claude plugin marketplace remove claude-hud
claude plugin marketplace remove caveman
claude plugin marketplace remove openai-codex
npx skills remove anthropics/skills --skill skill-creator -g
npx skills remove anthropics/skills --skill pdf -g
npx skills remove anthropics/skills --skill pptx -g
npx skills remove anthropics/skills --skill docx -g
npx skills remove anthropics/skills --skill xlsx -g
Remove-Item "$env:USERPROFILE\.claude\CLAUDE.md" -Force -ErrorAction SilentlyContinue
winget uninstall --id Anthropic.Claude
```

### 설정 파일만 제거 (패키지는 유지)

```powershell
# 마커 블록 제거
# 위 4절의 fail-closed helper를 정의한 뒤 실행
Remove-DotfilesProfileBlock $PROFILE.CurrentUserCurrentHost

# Git 설정 제거
git config --global --unset core.pager
git config --global --unset core.editor
git config --global --unset delta.navigate
git config --global --unset delta.dark
git config --global --unset delta.side-by-side
git config --global --unset delta.line-numbers
git config --global --unset interactive.diffFilter
git config --global --unset merge.conflictStyle

# 기타 설정 파일
Remove-Item "$env:USERPROFILE\.tmux.conf" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:APPDATA\yazi\config" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\nvim" -Recurse -Force -ErrorAction SilentlyContinue
```
