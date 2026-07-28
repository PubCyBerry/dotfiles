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

# settings.json의 RTK hook만 제거
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
$settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
$settings.hooks.PSObject.Properties.Remove("PreToolUse")
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

### 3-2. RTK (Rust Token Killer) 제거

```powershell
# 바이너리 제거
Remove-Item "$env:USERPROFILE\.local\bin\rtk.exe" -Force -ErrorAction SilentlyContinue

# Claude hook 제거 (settings.json 엔트리)
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.hooks -and $settings.hooks.PreToolUse) {
        $settings.hooks.PSObject.Properties.Remove("PreToolUse")
        $settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
    }
}

# .local\bin에 다른 도구가 없을 경우 PATH에서도 제거
$localBin = "$env:USERPROFILE\.local\bin"
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$newPath  = ($userPath -split ';' | Where-Object { $_ -ne $localBin }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $newPath, "User")
```

---

### 4. PowerShell 프로파일 정리

dotfiles 마커 블록(`# ===== dotfiles-begin =====` ~ `# ===== dotfiles-end =====`) 제거:

```powershell
$prof = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $prof) {
    $content = Get-Content $prof -Raw
    $content = $content -replace '(?s)\r?\n?# ===== dotfiles-begin =====(.*?)# ===== dotfiles-end =====\r?\n?', ''
    $content | Out-File $prof -Encoding utf8 -NoNewline
    Write-Host "dotfiles 블록 제거 완료: $prof"
}
```

---

### 5. Git Bash 프로파일 정리

`.bashrc`와 `.inputrc`에서 마커 블록 제거 (Git Bash에서 실행):

```bash
for file in ~/.bashrc ~/.inputrc; do
    if [ -f "$file" ]; then
        sed -i '/# ===== dotfiles-begin =====/,/# ===== dotfiles-end =====/d' "$file"
        echo "dotfiles 블록 제거 완료: $file"
    fi
done
```

install.ps1이 생성한 `.bash_profile` 제거:

```powershell
# 내용이 dotfiles 생성본인지 확인 후 삭제
Get-Content "$env:USERPROFILE\.bash_profile"
# 확인 후:
Remove-Item "$env:USERPROFILE\.bash_profile" -Force
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

claude plugin marketplace remove claude-hud
claude plugin marketplace remove caveman
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
3. **3-2** — RTK 제거
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
# 플러그인 → Skills → RTK → 설정 → 앱 순서
claude plugin uninstall claude-hud@claude-hud --scope user
claude plugin uninstall caveman@caveman --scope user
claude plugin marketplace remove claude-hud
claude plugin marketplace remove caveman
npx skills remove anthropics/skills --skill skill-creator -g
npx skills remove anthropics/skills --skill pdf -g
npx skills remove anthropics/skills --skill pptx -g
npx skills remove anthropics/skills --skill docx -g
npx skills remove anthropics/skills --skill xlsx -g
Remove-Item "$env:USERPROFILE\.local\bin\rtk.exe" -Force -ErrorAction SilentlyContinue
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
    if ($settings.hooks -and $settings.hooks.PreToolUse) {
        $settings.hooks.PSObject.Properties.Remove("PreToolUse")
        $settings | ConvertTo-Json -Depth 10 | Out-File $settingsPath -Encoding utf8 -NoNewline
    }
}
Remove-Item "$env:USERPROFILE\.claude\CLAUDE.md" -Force -ErrorAction SilentlyContinue
winget uninstall --id Anthropic.Claude
```

### 설정 파일만 제거 (패키지는 유지)

```powershell
# 마커 블록 제거
$prof = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
(Get-Content $prof -Raw) -replace '(?s)\r?\n?# ===== dotfiles-begin =====(.*?)# ===== dotfiles-end =====\r?\n?', '' |
    Out-File $prof -Encoding utf8 -NoNewline

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
