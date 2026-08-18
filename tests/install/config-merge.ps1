$ErrorActionPreference = "Stop"

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$work = Join-Path $PSScriptRoot ".config-merge-$PID"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $env:DOTFILES_FUNCTIONS_ONLY = "1"
    . (Join-Path $repo "install.ps1")
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY

    yq -p=toml -o=json '.' (Join-Path $repo 'config\codex\config.toml') | jq -e '
      (.features | has("js_repl") | not) and
      (.features | has("remote_control") | not) and
      .desktop.followUpQueueMode == "steer"
    ' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) '실제 Codex config에 dead key가 남았거나 stable key가 없습니다.'

    $tomlSrc = Join-Path $work "source.toml"
    $tomlDst = Join-Path $work "destination.toml"
    @'
model = "repo-model"
model_reasoning_effort = "xhigh"

[features]
hooks = true

[desktop]
followUpQueueMode = "steer"

[windows]
sandbox = "elevated"
'@ | Set-Content $tomlSrc -Encoding utf8 -NoNewline
    @'
model = "user-model"

[features]
hooks = false
user_sentinel = true

[custom]
sentinel = "keep"
'@ | Set-Content $tomlDst -Encoding utf8 -NoNewline

    Merge-CodexConfig $tomlSrc $tomlDst
    yq -p=toml -o=json '.' $tomlDst | jq -e '
      .model == "user-model" and
      .model_reasoning_effort == "xhigh" and
      .features.hooks == false and
      (.features | has("js_repl") | not) and
      (.features | has("remote_control") | not) and
      .features.user_sentinel == true and
      .custom.sentinel == "keep" and
      .desktop.followUpQueueMode == "steer" and
      .windows.sandbox == "elevated"
    ' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "TOML 병합 결과가 기대와 다릅니다."
    $tomlFirst = Get-FileHash $tomlDst
    Merge-CodexConfig $tomlSrc $tomlDst
    Assert-True ($tomlFirst.Hash -eq (Get-FileHash $tomlDst).Hash) "TOML 두 번째 병합 결과가 달라졌습니다."
    Assert-True ((Select-String -Path $tomlDst -Pattern '^model\s*=').Count -eq 1) "model 키가 중복되었습니다."

    $sectionOnlyDst = Join-Path $work "section-only.toml"
    "[features] # user section`nhooks = false" | Set-Content $sectionOnlyDst -Encoding utf8 -NoNewline
    Merge-CodexConfig $tomlSrc $sectionOnlyDst
    yq -p=toml -o=json '.' $sectionOnlyDst | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "section-only TOML 병합 결과가 유효하지 않습니다."
    Assert-True ((Select-String -Path $sectionOnlyDst -Pattern '^model\s*=').Count -eq 1) "section-only TOML에 model 키가 중복되었습니다."
    Assert-True ((Select-String -Path $sectionOnlyDst -Pattern '^\[features\]').Count -eq 1) "inline comment section이 중복되었습니다."

    $arrayDst = Join-Path $work "array-table.toml"
    @'
[[mcp_servers]]
name = "user-server"
'@ | Set-Content $arrayDst -Encoding utf8 -NoNewline
    Merge-CodexConfig $tomlSrc $arrayDst
    yq -p=toml -o=json '.' $arrayDst | jq -e '
      .model == "repo-model" and
      .model_reasoning_effort == "xhigh" and
      .mcp_servers[0].name == "user-server"
    ' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "array-of-tables 경계에서 top-level 기본값 위치가 잘못되었습니다."

    $dottedDst = Join-Path $work "dotted.toml"
    @'
model = "user-model"
windows.sandbox = "unelevated"
features.hooks = false
'@ | Set-Content $dottedDst -Encoding utf8 -NoNewline
    Merge-CodexConfig $tomlSrc $dottedDst
    yq -p=toml -o=json '.' $dottedDst | jq -e '
      .model == "user-model" and
      .windows.sandbox == "unelevated" and
      .features.hooks == false and
      .desktop.followUpQueueMode == "steer"
    ' | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "dotted TOML 사용자 값이 보존되지 않았습니다."
    $dottedFirst = Get-FileHash $dottedDst
    Merge-CodexConfig $tomlSrc $dottedDst
    Assert-True ($dottedFirst.Hash -eq (Get-FileHash $dottedDst).Hash) "dotted TOML 두 번째 병합 결과가 달라졌습니다."

    $invalidDst = Join-Path $work "invalid.toml"
    "model =" | Set-Content $invalidDst -Encoding utf8 -NoNewline
    $invalidBefore = Get-FileHash $invalidDst
    Merge-CodexConfig $tomlSrc $invalidDst
    Assert-True ($invalidBefore.Hash -eq (Get-FileHash $invalidDst).Hash) "invalid TOML 원본이 변경되었습니다."

    $invalidSrc = Join-Path $work "invalid-source.toml"
    $sourceProtectedDst = Join-Path $work "source-protected.toml"
    "model =" | Set-Content $invalidSrc -Encoding utf8 -NoNewline
    Copy-Item $tomlDst $sourceProtectedDst
    $sourceProtectedBefore = Get-FileHash $sourceProtectedDst
    Merge-CodexConfig $invalidSrc $sourceProtectedDst
    Assert-True ($sourceProtectedBefore.Hash -eq (Get-FileHash $sourceProtectedDst).Hash) "invalid source TOML이 기존 설정을 변경했습니다."

    $noYqDst = Join-Path $work "no-yq.toml"
    Copy-Item $tomlDst $noYqDst
    $noYqBefore = Get-FileHash $noYqDst
    $originalPath = $env:PATH
    try {
        $env:PATH = Join-Path $work "no-yq"
        Merge-CodexConfig $tomlSrc $noYqDst
    } finally {
        $env:PATH = $originalPath
    }
    Assert-True ($noYqBefore.Hash -eq (Get-FileHash $noYqDst).Hash) "yq 부재 시 기존 TOML이 변경되었습니다."

    $claudeSrc = Join-Path $work "claude-source.json"
    $claudeDst = Join-Path $work "claude-destination.json"
    @'
{
  "language": "한국어",
  "env": {"REPO_VALUE": "1", "SHARED": "repo"},
  "permissions": {"allow": ["Bash(repo:*)"]},
  "hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}]}]}
}
'@ | Set-Content $claudeSrc -Encoding utf8 -NoNewline
    # destination은 event 이동 전에 설치된 머신 상태다: 관리 hook이 SessionStart에 남아 있고
    # 사용자 hook이 같은 group에 섞여 있으며, 새 event 쪽에는 중복이 들어 있다.
    @'
{
  "language": "English",
  "statusLine": {"command": "user-sentinel"},
  "env": {"USER_SENTINEL": "keep", "SHARED": "user"},
  "permissions": {"allow": ["Read(*)"]},
  "hooks": {
    "SessionStart": [{"matcher": "", "hooks": [
      {"type": "command", "command": "user-session-sentinel"},
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}, {"matcher": "legacy-only", "hooks": [
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}],
    "UserPromptSubmit": [{"matcher": "", "hooks": [
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"},
      {"type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh"}
    ]}],
    "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "user-event-sentinel"}]}]
  }
}
'@ | Set-Content $claudeDst -Encoding utf8 -NoNewline

    Merge-JsonRegistry $claudeSrc $claudeDst
    jq -e '
      .language == "English" and .statusLine.command == "user-sentinel" and
      .env.USER_SENTINEL == "keep" and .env.REPO_VALUE == "1" and .env.SHARED == "user" and
      (.permissions.allow | index("Read(*)")) != null and
      (.permissions.allow | index("Bash(repo:*)")) != null and
      ([.hooks.UserPromptSubmit[].hooks[] | select(.command == "bash ~/.claude/hooks/temporal-context.sh")] | length) == 1 and
      ([.hooks.SessionStart[].hooks[] | select(.command == "bash ~/.claude/hooks/temporal-context.sh")] | length) == 0 and
      ([.hooks.SessionStart[].hooks[] | select(.command == "user-session-sentinel")] | length) == 1 and
      ([.hooks.SessionStart[] | select(.matcher == "legacy-only")] | length) == 0 and
      all(.hooks[][]; (.hooks | length) > 0) and
      .hooks.PreToolUse[0].hooks[0].command == "user-event-sentinel"
    ' $claudeDst | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "Claude settings 병합 결과가 기대와 다릅니다."
    Assert-True $script:LastJsonRegistryDeployed "병합 성공인데 배포 플래그가 서지 않았습니다."
    $claudeFirst = Get-FileHash $claudeDst
    Merge-JsonRegistry $claudeSrc $claudeDst
    Assert-True ($claudeFirst.Hash -eq (Get-FileHash $claudeDst).Hash) "Claude settings 두 번째 병합 결과가 달라졌습니다."

    # 옛 event에 관리 hook만 있었다면 group과 event key가 통째로 사라져야 한다.
    $legacyOnlyDst = Join-Path $work "legacy-only.json"
    @'
{"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.claude/hooks/temporal-context.sh"}]}]}}
'@ | Set-Content $legacyOnlyDst -Encoding utf8 -NoNewline
    Merge-JsonRegistry $claudeSrc $legacyOnlyDst
    jq -e '(.hooks | has("SessionStart")) | not' $legacyOnlyDst | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "옛 event key가 비었는데도 남았습니다."

    $invalidJson = Join-Path $work "invalid.json"
    '{' | Set-Content $invalidJson -Encoding utf8 -NoNewline
    $invalidJsonBefore = Get-FileHash $invalidJson
    Merge-JsonRegistry $claudeSrc $invalidJson
    Assert-True ($invalidJsonBefore.Hash -eq (Get-FileHash $invalidJson).Hash) "invalid JSON 원본이 변경되었습니다."
    Assert-True (-not $script:LastJsonRegistryDeployed) "병합 실패인데 배포 플래그가 섰습니다."

    $codexSrc = Join-Path $work "codex-source.json"
    $codexDst = Join-Path $work "codex-destination.json"
    @'
{"hooks":{"UserPromptSubmit":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}]}}
'@ | Set-Content $codexSrc -Encoding utf8 -NoNewline
    @'
{"user":{"sentinel":true},"hooks":{"SessionStart":[{"matcher":"","hooks":[{"type":"command","command":"user-codex-sentinel"},{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}],"UserPromptSubmit":[{"matcher":"","hooks":[{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"},{"type":"command","command":"bash ~/.codex/hooks/temporal-context.sh"}]}]}}
'@ | Set-Content $codexDst -Encoding utf8 -NoNewline

    Merge-JsonRegistry $codexSrc $codexDst
    jq -e '
      .user.sentinel == true and
      ([.hooks.SessionStart[].hooks[] | select(.command == "user-codex-sentinel")] | length) == 1 and
      ([.hooks.SessionStart[].hooks[] | select(.command == "bash ~/.codex/hooks/temporal-context.sh")] | length) == 0 and
      ([.hooks.UserPromptSubmit[].hooks[] | select(.command == "bash ~/.codex/hooks/temporal-context.sh")] | length) == 1
    ' $codexDst | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "Codex hooks 병합 결과가 기대와 다릅니다."
    $codexFirst = Get-FileHash $codexDst
    Merge-JsonRegistry $codexSrc $codexDst
    Assert-True ($codexFirst.Hash -eq (Get-FileHash $codexDst).Hash) "Codex hooks 두 번째 병합 결과가 달라졌습니다."

    # agy hooks.json은 top-level hooks key가 없어 event 병합/정리 대상이 아니다.
    $agySrc = Join-Path $work "agy-source.json"
    $agyDst = Join-Path $work "agy-destination.json"
    @'
{"temporal-context":{"PreInvocation":[{"type":"command","command":"bash ~/.gemini/hooks/temporal-context.sh"}]}}
'@ | Set-Content $agySrc -Encoding utf8 -NoNewline
    @'
{"user-hook":{"PreInvocation":[{"type":"command","command":"user-agy-sentinel"}]}}
'@ | Set-Content $agyDst -Encoding utf8 -NoNewline
    Merge-JsonRegistry $agySrc $agyDst
    jq -e '
      ."user-hook".PreInvocation[0].command == "user-agy-sentinel" and
      ."temporal-context".PreInvocation[0].command == "bash ~/.gemini/hooks/temporal-context.sh" and
      (has("hooks") | not)
    ' $agyDst | Out-Null
    Assert-True ($LASTEXITCODE -eq 0) "agy hooks 병합 결과가 기대와 다릅니다."

    jq empty $claudeDst $codexDst $agyDst $legacyOnlyDst
    Assert-True ($LASTEXITCODE -eq 0) "JSON 결과가 유효하지 않습니다."
    Write-Host "config merge regression checks passed"
} finally {
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
