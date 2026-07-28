# claude-hud 설치 가이드 (Windows + PowerShell)

터미널 statusline에 Claude Code 세션 정보를 실시간으로 표시하는 플러그인.

```
[Sonnet | Pro] │ dotfiles  git:(main* ↑1)
Context ████████░░ 78% │ Usage ██░░░░░░░░ 25% (1h 15m / 5h)  ⏱ 32m
◐ Edit: install.ps1 | ✓ Read ×3
▸ claude-hud 설정 추가 (2/4)
```

---

## 사전 요구사항

| 항목 | 최소 버전 | 비고 |
|------|-----------|------|
| Claude Code | v1.0.80+ | — |
| Node.js | 18+ | bun은 Windows에서 불안정 → node 사용 |

Node.js는 `install.ps1`이 fnm으로 설치한다. 버전 확인:

```powershell
node --version
```

---

## 설치

install 스크립트가 `manifests/plugins.txt`를 읽어 아래 두 줄을 이미 실행한다. 수동으로 할 때만 직접 친다.

```bash
claude plugin marketplace add jarrodwatts/claude-hud --scope user
claude plugin install claude-hud@claude-hud --scope user
```

설치 후 Claude Code 세션에서 statusline을 연결한다(이 단계는 스크립트가 하지 않는다).

```
/claude-hud:setup
```

`/claude-hud:setup`이 완료되면 **Claude Code를 재시작**해야 HUD가 표시된다.  
(setup을 실행한 세션에서는 HUD가 나타나지 않는다.)

---

## Ghost 설치 정리

이전에 설치가 실패했거나 플러그인 상태가 꼬인 경우, `/claude-hud:setup`이 자동으로 감지하고 안내한다.  
수동으로 정리할 때는 PowerShell에서 아래를 실행한다.

```powershell
# 플러그인 파일 삭제
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\plugins\claude-hud" -ErrorAction SilentlyContinue

# 임시 캐시 삭제
Get-ChildItem "$env:APPDATA" -Filter "claude-hud-*" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Get-ChildItem "$env:TEMP" -Filter "claude-hud*" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
```

정리 후 `/plugin install claude-hud`부터 다시 실행한다.

---

## setup이 하는 일

`/claude-hud:setup`은 내부적으로 다음을 수행한다.

1. **Platform 감지** — `win32` + PowerShell 확인
2. **Runtime 선택** — Windows에서는 bun 대신 `node` 선택
3. **소스 파일** — TypeScript 원본 대신 컴파일된 JavaScript (`dist/index.js`) 사용
4. **명령어 생성** — 다음 형태로 statusLine 명령어 결정:
   ```
   node C:\Users\<user>\.claude\plugins\claude-hud\dist\index.js
   ```
5. **settings.json 수정** — 기존 설정을 보존하면서 `statusLine` 키 추가:
   ```json
   {
     "statusLine": {
       "command": "node C:\\Users\\<user>\\.claude\\plugins\\claude-hud\\dist\\index.js"
     }
   }
   ```

> `settings.json` 경로: `~/.claude/settings.json`

---

## 설정 커스터마이즈

### 방법 A — 가이드 모드

Claude Code에서 실행:

```
/claude-hud:configure
```

Layout → Preset → 켜고/끄기 선택 → 미리보기 확인 → 저장.

### 방법 B — 직접 편집

설정 파일 위치: `~/.claude/plugins/claude-hud/config.json`

`config/claude/claude-hud.json`의 템플릿을 복사해서 시작한다:

```powershell
$src = Join-Path $PSScriptRoot "config\claude\claude-hud.json"
$dst = "$env:USERPROFILE\.claude\plugins\claude-hud\config.json"
Copy-Item $src $dst
```

---

## 프리셋 비교

| 항목 | Full | Essential | Minimal |
|------|:----:|:---------:|:-------:|
| Tools 활동 | ✓ | ✓ | — |
| Agents 상태 | ✓ | ✓ | — |
| Todo 진행 | ✓ | ✓ | — |
| Git 상태 | ✓ | ✓ | ✓ |
| Usage 한도 | ✓ | — | — |
| 세션 시간 | ✓ | ✓ | — |
| 토큰 내역 | ✓ | — | — |
| Config 수 | ✓ | — | — |
| Session name | ✓ | — | — |

`config/claude/claude-hud.json`은 Essential 기반에 Usage bar + git ahead/behind를 추가한 구성이다.

---

## 설정 키 참조

| 표시 항목 | 설정 키 |
|-----------|---------|
| Tools 활동 | `display.showTools` |
| Agents 상태 | `display.showAgents` |
| Todo 진행 | `display.showTodos` |
| 프로젝트 이름 | `display.showProject` |
| Git 상태 | `gitStatus.enabled` |
| Config 수 | `display.showConfigCounts` |
| 토큰 내역 | `display.showTokenBreakdown` |
| 출력 속도 | `display.showSpeed` |
| Usage 한도 | `display.showUsage` |
| Usage 바 스타일 | `display.usageBarEnabled` |
| Session name | `display.showSessionName` |
| 세션 시간 | `display.showDuration` |
| 커스텀 라인 | `display.customLine` |

Layout 옵션:

| 레이아웃 | `lineLayout` | `showSeparators` |
|----------|:------------:|:----------------:|
| Expanded | `"expanded"` | `false` |
| Compact | `"compact"` | `false` |
| Compact + Separators | `"compact"` | `true` |

Git 스타일 옵션:

| 스타일 | `showDirty` | `showAheadBehind` | `showFileStats` |
|--------|:-----------:|:-----------------:|:---------------:|
| Branch only | — | — | — |
| Branch + dirty | ✓ | — | — |
| Full details | ✓ | ✓ | — |
| File stats | ✓ | — | ✓ |

---

## 업데이트 / 재설치

```
/plugin update claude-hud
```

또는 제거 후 재설치:

```
/plugin uninstall claude-hud
/plugin install claude-hud
/claude-hud:setup
```

---

## 트러블슈팅

### HUD가 표시되지 않는다

1. Claude Code 재시작 여부 확인 (setup 후 필수)
2. `~/.claude/settings.json`에 `statusLine.command` 키가 있는지 확인
3. node 경로 확인:
   ```powershell
   Get-Command node | Select-Object -ExpandProperty Source
   ```
4. 명령어를 직접 실행해서 출력 확인:
   ```powershell
   node "$env:USERPROFILE\.claude\plugins\claude-hud\dist\index.js"
   ```

### `statusLine` 키가 settings.json에 없다

`/claude-hud:setup`을 다시 실행한다. setup 완료 후 `settings.json`을 직접 확인:

```powershell
Get-Content "$env:USERPROFILE\.claude\settings.json" | ConvertFrom-Json | Select-Object statusLine
```

### node를 찾지 못한다

fnm으로 설치한 Node.js가 PATH에 없는 경우. PowerShell 프로파일에 fnm 초기화가 있는지 확인:

```powershell
fnm env --use-on-cd | Out-String | Invoke-Expression
```
