# 클린 언인스톨

dotfiles가 설치한 모든 항목을 제거하는 방법. 필요한 항목만 선택적으로 제거 가능.

## Linux

### 1. 심볼릭 링크 제거 (bash 설정)

```bash
# dotfiles가 생성한 심볼릭 링크 제거
for file in ~/dotfiles/bash/.*; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  [[ "$name" == ".gitconfig.local.example" ]] && continue
  target="$HOME/$name"
  [[ -L "$target" ]] && rm "$target" && echo "removed $target"
done

# XDG config 심볼릭 링크 제거
rm -f ~/.config/starship.toml
```

### 2. Claude Code 설정 제거

```bash
rm -f ~/.claude/CLAUDE.md ~/.claude/settings.json
rm -f ~/.claude/hooks/rtk-rewrite.sh

# npx skills 제거
npx skills list -g                     # 설치된 skills 확인
npx skills remove <skill-name> -g      # 개별 제거
```

### 3. 런타임 & 도구 제거

```bash
rm -rf ~/.local/share/fnm              # fnm + Node.js
rm -rf ~/.bun                          # bun (curl 설치)
rm -rf ~/.rtk                          # RTK (curl 설치)
claude uninstall                       # Claude Code
rm -f ~/.local/bin/{yq,starship,lazygit,yazi,difft,sg,bat,fd,rtk}
```

### 4. npm 전역 패키지 제거

```bash
npm uninstall -g @google/gemini-cli @musistudio/claude-code-router @openai/codex opencode-ai
```

### 5. apt 패키지 제거 (선택)

```bash
sudo apt remove --purge bat fzf fd-find ripgrep jq httpie tmux eza delta shellcheck
sudo rm -f /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
sudo apt update
```

### 6. apt 미러 복원 (선택)

```bash
sudo sed -i 's|mirror.kakao.com|archive.ubuntu.com|g' /etc/apt/sources.list
sudo apt update
```

### 7. 셸 초기화 잔여물 정리

`.bashrc`에서 fnm, zoxide, atuin, starship의 `eval` / `source` 라인은 심볼릭 링크 제거(1단계)와 함께 사라진다. 수동으로 `.bashrc`를 작성한 경우, 해당 도구의 init 라인을 직접 제거한다.

## macOS

### 1. 심볼릭 링크 제거

Linux와 동일 (위 1단계).

### 2. Claude Code 설정 제거

Linux와 동일 (위 2단계).

### 3. Homebrew 패키지 제거

```bash
# Brewfile에 정의된 패키지 일괄 제거
cd ~/dotfiles && brew bundle cleanup --force

# 또는 개별 제거
brew uninstall bat fzf eza fd delta ripgrep zoxide yq lazygit yazi \
  starship ruff httpie difftastic ast-grep atuin tmux rtk oven-sh/bun/bun fnm gh
```

### 4. Claude Code + npm 전역 패키지 제거

```bash
claude uninstall
npm uninstall -g @google/gemini-cli @musistudio/claude-code-router @openai/codex opencode-ai
```

### 5. macOS 시스템 설정 복원 (선택)

`.macos`로 변경한 설정은 수동 복원 필요:

```bash
# Dock
defaults delete com.apple.dock autohide
defaults write com.apple.dock show-recents -bool true
defaults write com.apple.dock tilesize -int 64
killall Dock

# Finder
defaults write com.apple.finder AppleShowAllFiles -bool false
defaults delete com.apple.finder _FXShowPosixPathInTitle
killall Finder

# 키보드
defaults delete NSGlobalDomain KeyRepeat
defaults delete NSGlobalDomain InitialKeyRepeat
```

전체 복원은 **시스템 설정 > 일반 > 전송 또는 재설정**에서 가능.

## Windows

### 1. PowerShell 프로파일 정리

```powershell
# PS 7+ 프로파일에서 dotfiles 블록 제거
$prof = "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
$content = Get-Content $prof -Raw
$cleaned = $content -replace '(?s)# ===== dotfiles-begin =====.*?# ===== dotfiles-end =====\r?\n?', ''
$cleaned | Out-File $prof -Encoding utf8

# PS 5.1 프로파일도 동일하게 처리
$prof5 = "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $prof5) {
    $content = Get-Content $prof5 -Raw
    $cleaned = $content -replace '(?s)# ===== dotfiles-begin =====.*?# ===== dotfiles-end =====\r?\n?', ''
    $cleaned | Out-File $prof5 -Encoding utf8
}
```

### 2. Claude Code 설정 제거

```powershell
Remove-Item "$HOME\.claude\CLAUDE.md", "$HOME\.claude\settings.json" -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.claude\hooks\rtk-rewrite.sh" -Force -ErrorAction SilentlyContinue
```

### 3. RTK + 수동 설치 바이너리 제거

```powershell
Remove-Item "$HOME\rtk" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.local\bin\sg.exe", "$HOME\.local\bin\difft.exe" -Force -ErrorAction SilentlyContinue
```

### 4. winget 패키지 제거 (선택)

```powershell
$packages = @(
    "Microsoft.PowerShell", "Git.Git", "GitHub.cli", "Schniz.fnm",
    "Microsoft.WindowsTerminal", "psmux",
    "sharkdp.bat", "junegunn.fzf", "eza-community.eza", "sharkdp.fd",
    "dandavison.delta", "BurntSushi.ripgrep.MSVC", "Oven-sh.Bun", "jqlang.jq",
    "ajeetdsouza.zoxide", "mikefarah.yq", "JesseDuffield.lazygit",
    "sxyazi.yazi", "Starship.Starship", "astral-sh.ruff", "httpie.httpie"
)
foreach ($pkg in $packages) { winget uninstall --id $pkg }
```

### 5. Claude Code 제거

```powershell
claude uninstall
npm uninstall -g @google/gemini-cli @musistudio/claude-code-router @openai/codex opencode-ai
```

## dotfiles 저장소 자체 제거

모든 OS 공통으로, 위 정리가 끝나면 저장소를 삭제한다:

```bash
rm -rf ~/dotfiles
```
