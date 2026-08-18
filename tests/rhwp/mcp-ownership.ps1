# rhwp tree + MCP entry의 소유권 계약을 install.ps1 / uninstall.ps1 양쪽에서 검증한다.
# 네트워크를 타지 않는다 — manifest 검증과 소유권 상태 전이만 다룬다.
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot)
$temp = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-rhwp-$([guid]::NewGuid())"
$old = @{ profile=$env:USERPROFILE; local=$env:LOCALAPPDATA; app=$env:APPDATA; receipt=$env:DOTFILES_RECEIPT_PATH; functions=$env:DOTFILES_FUNCTIONS_ONLY; git=$env:GIT_CONFIG_GLOBAL }

function Assert($ok, $message) { if (-not $ok) { throw "rhwp mcp: FAIL: $message" } }

try {
    $env:USERPROFILE = Join-Path $temp 'home'
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
    $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
    $env:DOTFILES_RECEIPT_PATH = Join-Path $env:USERPROFILE '.state\receipt.json'
    $env:GIT_CONFIG_GLOBAL = Join-Path $temp 'gitconfig'
    $env:DOTFILES_FUNCTIONS_ONLY = '1'
    New-Item -ItemType Directory -Force $env:USERPROFILE, $env:LOCALAPPDATA, $env:APPDATA,
        (Split-Path $env:DOTFILES_RECEIPT_PATH), (Join-Path $env:USERPROFILE '.codex') | Out-Null

    if (-not (Get-Command yq -ErrorAction SilentlyContinue) -or -not (Get-Command jq -ErrorAction SilentlyContinue)) {
        Write-Host 'rhwp mcp: SKIP (yq/jq unavailable)'
        exit 0
    }

    . (Join-Path $root 'install.ps1')
    Assert (Initialize-InstallReceipt) 'receipt-init'

    # -----------------------------------------
    # manifest 계약
    # -----------------------------------------
    $manifestPath = Join-Path $root 'manifests\rhwp.tsv'
    $rows = @(Get-Content -LiteralPath $manifestPath |
        Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
        ForEach-Object { , @($_ -split "`t") })
    Assert (Test-RhwpManifestRows $rows) 'manifest-valid'
    Assert (@($rows | ForEach-Object { $_[1] } | Sort-Object -Unique).Count -eq 1) 'manifest-single-version'

    $latest = @($rows | ForEach-Object { , @($_[0], $_[1], $_[2], ($_[3] -replace '/download/v[\d.]+/', '/download/latest/'), $_[4]) })
    Assert (-not (Test-RhwpManifestRows $latest)) 'manifest-latest-url'
    $shortSum = @($rows | ForEach-Object { , @($_[0], $_[1], $_[2], $_[3], 'deadbeef') })
    Assert (-not (Test-RhwpManifestRows $shortSum)) 'manifest-short-checksum'
    Assert (-not (Test-RhwpManifestRows @($rows | Select-Object -First 3))) 'manifest-missing-platform'
    $dupe = @(); foreach ($i in 0, 1, 2, 0) { $dupe += , $rows[$i] }
    Assert (-not (Test-RhwpManifestRows $dupe)) 'manifest-duplicate-platform'

    # -----------------------------------------
    # Codex MCP entry: 신규 등록 → 멱등 → 사용자 수정 보존
    # -----------------------------------------
    $codexConfig = Join-Path $env:USERPROFILE '.codex\config.toml'
    [IO.File]::WriteAllText($codexConfig, "[user]`nsentinel = `"keep`"`n", [Text.UTF8Encoding]::new($false))
    $desired = '{"command":"C:\\Users\\test\\rhwp\\rhwp.exe","args":["mcp-serve"]}'
    $canonical = ConvertTo-CanonicalJson $desired

    Assert (Install-ManagedMcpServer codex 'rhwp' $codexConfig $desired) 'codex-register'
    Assert (Get-McpEntry codex 'rhwp' $codexConfig) 'codex-read'
    Assert ($script:McpValue -ceq $canonical) 'codex-entry'
    Assert ((& yq -p=toml -o=json -r '.user.sentinel' $codexConfig) -ceq 'keep') 'codex-user-preserved'
    Assert ($null -ne $script:Receipt.values['mcp:codex:rhwp'].installed) 'codex-receipt'
    Assert (-not $script:Receipt.values['mcp:codex:rhwp'].pending) 'codex-receipt-pending'

    $beforeHash = (Get-FileHash -LiteralPath $codexConfig -Algorithm SHA256).Hash
    Assert (Install-ManagedMcpServer codex 'rhwp' $codexConfig $desired) 'codex-idempotent'
    Assert ((Get-FileHash -LiteralPath $codexConfig -Algorithm SHA256).Hash -ceq $beforeHash) 'codex-idempotent-write'

    # 사용자가 우리 entry를 고쳤으면 덮어쓰지 않는다.
    Assert (Set-McpEntry codex 'rhwp' $codexConfig '{"command":"C:\\user\\rhwp.exe","args":["mcp-serve"]}') 'codex-seed-modified'
    Assert (-not (Install-ManagedMcpServer codex 'rhwp' $codexConfig $desired)) 'codex-modified-overwritten'
    Assert ((& yq -p=toml -o=json -r '.mcp_servers.rhwp.command' $codexConfig) -ceq 'C:\user\rhwp.exe') 'codex-modified-preserve'

    # 사용자가 먼저 만든 동명 entry는 receipt에 없으므로 손대지 않는다.
    $userConfig = Join-Path $temp 'user.toml'
    [IO.File]::WriteAllText($userConfig, "[mcp_servers.rhwp]`ncommand = `"C:\\opt\\user\\rhwp.exe`"`n", [Text.UTF8Encoding]::new($false))
    Assert (-not (Install-ManagedMcpServer codex 'rhwp' $userConfig $desired)) 'codex-unowned-taken'
    Assert ((& yq -p=toml -o=json -r '.mcp_servers.rhwp.command' $userConfig) -ceq 'C:\opt\user\rhwp.exe') 'codex-unowned-changed'

    # -----------------------------------------
    # Claude MCP entry: 파일이 없으면 만들고, 다른 키는 건드리지 않는다.
    # -----------------------------------------
    $claudeJson = Join-Path $env:USERPROFILE '.claude.json'
    Assert (Install-ManagedMcpServer claude 'rhwp' $claudeJson $desired) 'claude-register'
    Assert (Get-McpEntry claude 'rhwp' $claudeJson) 'claude-read'
    Assert ($script:McpValue -ceq $canonical) 'claude-entry'
    $withUserKey = @(& jq '. + {"hasCompletedOnboarding":true}' $claudeJson)
    ($withUserKey -join "`n") | Out-File $claudeJson -Encoding utf8 -NoNewline
    Assert (Install-ManagedMcpServer claude 'rhwp' $claudeJson $desired) 'claude-idempotent'
    & jq -e '.hasCompletedOnboarding == true' $claudeJson | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'claude-user-key-lost'

    # -----------------------------------------
    # Gemini MCP entry: ~/.gemini/config/mcp_config.json 등록 및 멱등성
    # -----------------------------------------
    $geminiJson = Join-Path $env:USERPROFILE '.gemini\config\mcp_config.json'
    # 0바이트 registry에서 시작한다. 존재한다는 이유만으로 그대로 파서에 넘기면 jq가 빈
    # 출력을 내 등록이 통째로 실패했다("Failed to write MCP entry") — 실제로 겪은 회귀다.
    New-Item -ItemType Directory -Force -Path (Split-Path $geminiJson) | Out-Null
    [IO.File]::WriteAllText($geminiJson, '', [Text.UTF8Encoding]::new($false))
    Assert (Install-ManagedMcpServer gemini 'rhwp' $geminiJson $desired) 'gemini-register'
    Assert (Get-McpEntry gemini 'rhwp' $geminiJson) 'gemini-read'
    Assert ($script:McpValue -ceq $canonical) 'gemini-entry'
    $withGeminiUserKey = @(& jq '. + {"customSetting":123}' $geminiJson)
    ($withGeminiUserKey -join "`n") | Out-File $geminiJson -Encoding utf8 -NoNewline
    Assert (Install-ManagedMcpServer gemini 'rhwp' $geminiJson $desired) 'gemini-idempotent'
    & jq -e '.customSetting == 123' $geminiJson | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'gemini-user-key-lost'

    # -----------------------------------------
    # 공백뿐인 registry도 seed 대상이다. 반면 내용이 있는데 깨진 파일은 아니다 — 빈
    # 파일과 달리 사용자 데이터가 들어 있을 수 있어 보존해야 한다.
    # receipt에 낯선 key를 남기지 않도록 Set/Get-McpEntry를 직접 부른다.
    # -----------------------------------------
    $wsJson = Join-Path $env:USERPROFILE '.gemini\config\whitespace-registry.json'
    [IO.File]::WriteAllText($wsJson, "`n  `n", [Text.UTF8Encoding]::new($false))
    Assert (Set-McpEntry gemini 'probe' $wsJson $canonical) 'whitespace-registry-write'
    Assert (Get-McpEntry gemini 'probe' $wsJson) 'whitespace-registry-read'
    Assert ($script:McpValue -ceq $canonical) 'whitespace-registry-entry'

    $brokenJson = Join-Path $env:USERPROFILE '.gemini\config\broken-registry.json'
    [IO.File]::WriteAllText($brokenJson, '{', [Text.UTF8Encoding]::new($false))
    Assert (-not (Set-McpEntry gemini 'probe' $brokenJson $canonical)) 'broken-registry-written'
    Assert ([IO.File]::ReadAllText($brokenJson) -ceq '{') 'broken-registry-clobbered'

    # -----------------------------------------
    # tree artifact: 정확한 tree 해시일 때만 배치/제거한다.
    # -----------------------------------------
    $source = Join-Path $temp 'src\rhwp'
    New-Item -ItemType Directory -Force $source | Out-Null
    Set-Content -LiteralPath (Join-Path $source 'rhwp.exe') -Value 'binary' -NoNewline
    Set-Content -LiteralPath (Join-Path $source 'LICENSE') -Value 'license' -NoNewline
    Assert (Install-ManagedDirectTree $source $RhwpDir '0.8.4') 'tree-install'
    Assert (Test-Path -LiteralPath (Join-Path $RhwpDir 'rhwp.exe')) 'tree-content'
    Assert (Install-ManagedDirectTree $source $RhwpDir '0.8.4') 'tree-idempotent'
    $treeKey = Get-ManagedPath $RhwpDir
    Assert ($script:Receipt.artifacts[$treeKey].directVersion -ceq '0.8.4') 'tree-version'

    # 사용자가 tree 안을 고치면 그 뒤로는 손대지 않는다.
    Set-Content -LiteralPath (Join-Path $RhwpDir 'user-note') -Value 'user' -NoNewline
    Assert (-not (Install-ManagedDirectTree $source $RhwpDir '0.8.4')) 'tree-modified-overwritten'
    Assert (Test-Path -LiteralPath (Join-Path $RhwpDir 'user-note')) 'tree-modified-lost'

    # -----------------------------------------
    # uninstall: allowlist + 정확한 identity
    # -----------------------------------------
    $installReceipt = $script:Receipt
    . (Join-Path $root 'uninstall.ps1')
    $script:Receipt = $installReceipt

    Assert (Test-ValueKeyAllowed 'mcp:codex:rhwp') 'value-allowlist-codex'
    Assert (Test-ValueKeyAllowed 'mcp:claude:rhwp') 'value-allowlist-claude'
    Assert (Test-ValueKeyAllowed 'mcp:gemini:rhwp') 'value-allowlist-gemini'
    Assert (-not (Test-ValueKeyAllowed 'mcp:codex:other')) 'value-allowlist-open'
    Assert (-not (Test-ValueKeyAllowed 'mcp:other:rhwp')) 'value-allowlist-host'
    Assert (Test-ArtifactAllowed $RhwpDir) 'artifact-allowlist'
    Assert (-not (Test-ArtifactAllowed (Join-Path $RhwpDir 'rhwp.exe'))) 'artifact-allowlist-child'
    Assert (Test-ReceiptSchema) 'tree-schema'

    # 고쳐진 tree는 보존한다.
    Assert (-not (Remove-ManagedArtifact $treeKey)) 'tree-modified-removed'
    Assert (Test-Path -LiteralPath (Join-Path $RhwpDir 'user-note')) 'tree-modified-deleted'
    Remove-Item -LiteralPath (Join-Path $RhwpDir 'user-note') -Force
    Assert (Remove-ManagedArtifact $treeKey) 'tree-remove'
    Assert (-not (Test-Path -LiteralPath $RhwpDir)) 'tree-left'

    # 고쳐진 MCP entry는 보존한다 (위에서 C:\user\rhwp.exe로 바꿔 두었다).
    Assert (-not (Remove-ManagedValue 'mcp:codex:rhwp')) 'codex-uninstall-modified'
    Assert ((& yq -p=toml -o=json -r '.mcp_servers.rhwp.command' $codexConfig) -ceq 'C:\user\rhwp.exe') 'codex-uninstall-clobbered'
    Assert ($script:Receipt.values.Contains('mcp:codex:rhwp')) 'codex-receipt-dropped'

    # 값을 되돌려 놓으면 entry만 제거되고 사용자 테이블은 남는다.
    Assert (Set-McpEntry codex 'rhwp' $codexConfig $canonical) 'codex-restore-seed'
    Assert (Remove-ManagedValue 'mcp:codex:rhwp') 'codex-uninstall'
    & yq -p=toml -o=json -e '.mcp_servers' $codexConfig 2>$null | Out-Null
    Assert ($LASTEXITCODE -ne 0) 'codex-empty-table-left'
    Assert ((& yq -p=toml -o=json -r '.user.sentinel' $codexConfig) -ceq 'keep') 'codex-uninstall-user-lost'
    Assert (-not $script:Receipt.values.Contains('mcp:codex:rhwp')) 'codex-receipt-kept'

    # Claude entry 제거 후 다른 키가 남아 있으면 파일을 남긴다.
    Assert (Remove-ManagedValue 'mcp:claude:rhwp') 'claude-uninstall'
    Assert (Test-Path -LiteralPath $claudeJson) 'claude-json-removed-with-user-keys'
    & jq -e '(.mcpServers | has("rhwp") | not) and .hasCompletedOnboarding == true' $claudeJson | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'claude-entry-kept'

    # 우리가 만든 형태 그대로면 파일까지 걷어낸다.
    [IO.File]::WriteAllText($claudeJson, '{"mcpServers":{}}', [Text.UTF8Encoding]::new($false))
    Remove-EmptyJsonMcpFile $claudeJson
    Assert (-not (Test-Path -LiteralPath $claudeJson)) 'claude-json-not-pruned'

    # Gemini entry 제거 후 다른 키가 남아 있으면 파일을 남긴다.
    Assert (Remove-ManagedValue 'mcp:gemini:rhwp') 'gemini-uninstall'
    Assert (Test-Path -LiteralPath $geminiJson) 'gemini-json-removed-with-user-keys'
    & jq -e '(.mcpServers | has("rhwp") | not) and .customSetting == 123' $geminiJson | Out-Null
    Assert ($LASTEXITCODE -eq 0) 'gemini-entry-kept'

    [IO.File]::WriteAllText($geminiJson, '{"mcpServers":{}}', [Text.UTF8Encoding]::new($false))
    Remove-EmptyJsonMcpFile $geminiJson
    Assert (-not (Test-Path -LiteralPath $geminiJson)) 'gemini-json-not-pruned'

    Write-Host 'rhwp mcp ownership pwsh: PASS'
} finally {
    $env:USERPROFILE = $old.profile; $env:LOCALAPPDATA = $old.local; $env:APPDATA = $old.app
    $env:DOTFILES_RECEIPT_PATH = $old.receipt; $env:DOTFILES_FUNCTIONS_ONLY = $old.functions; $env:GIT_CONFIG_GLOBAL = $old.git
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
