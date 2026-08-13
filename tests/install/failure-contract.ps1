$ErrorActionPreference = 'Stop'

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$work = Join-Path $PSScriptRoot ".failure-contract-$PID"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

try {
    New-Item -ItemType Directory -Force $work | Out-Null
    $env:USERPROFILE = Join-Path $work 'home'
    $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
    $env:DOTFILES_FUNCTIONS_ONLY = '1'
    . (Join-Path $repo 'install.ps1')

    Assert-True (@(Get-ValidatedPluginRows (Join-Path $repo 'manifests\plugins.txt')).Count -gt 0) '실제 plugins manifest가 유효하지 않습니다.'
    Add-InstallFailure 'fixture failure' 3>$null
    $all = @(Complete-Install 6>&1)
    $output = $all | Out-String
    Assert-True ($all[-1] -eq $false) 'failure ledger가 실패를 반환하지 않았습니다.'
    Assert-True (-not $output.Contains('==> Done!')) '실패인데 Done을 출력했습니다.'

    $script:InstallFailures.Clear()
    $all = @(Complete-Install 6>&1)
    $output = $all | Out-String
    Assert-True ($all[-1] -eq $true) '빈 failure ledger가 성공을 반환하지 않았습니다.'
    Assert-True $output.Contains('==> Done!') '성공인데 Done을 출력하지 않았습니다.'

    $script:ClaudeCalls = 0
    $script:NpxCalls = 0
    function global:claude { $script:ClaudeCalls++; $global:LASTEXITCODE = 0 }
    function global:npx { $script:NpxCalls++; $global:LASTEXITCODE = 0 }
    $env:SKIP_CLAUDE_CODE = $env:SKIP_SKILLS = $env:SKIP_PLUGINS = '1'
    Invoke-ClaudeSkillsStage (Join-Path $repo 'manifests\skills.txt')
    Invoke-ClaudePluginsStage (Join-Path $repo 'manifests\plugins.txt')
    Invoke-OptionalInstallStage 'SKIP_CLAUDE_CODE' 'claude skipped' { $script:ClaudeCalls++ }
    Assert-True ($script:ClaudeCalls -eq 0 -and $script:NpxCalls -eq 0) 'skip stage가 외부 CLI를 호출했습니다.'
    Remove-Item Env:SKIP_CLAUDE_CODE, Env:SKIP_SKILLS, Env:SKIP_PLUGINS
    Invoke-OptionalInstallStage 'SKIP_CLAUDE_CODE' 'claude skipped' { $script:ClaudeCalls++ }
    Assert-True ($script:ClaudeCalls -eq 1) 'enabled Claude stage action이 호출되지 않았습니다.'
    $script:ClaudeCalls = 0

    foreach ($invalid in @(
        'owner/market valid@market user extra',
        'owner/market valid@market system',
        'owner/market valid@market USER',
        'owner/market invalid user'
    )) {
        $invalidPlugins = Join-Path $work 'plugins-invalid.txt'
        @('owner/market valid@market user', $invalid) | Set-Content $invalidPlugins -Encoding utf8
        $script:InstallFailures.Clear()
        Invoke-ClaudePluginsStage $invalidPlugins
        Assert-True ($script:InstallFailures.Count -eq 1) "invalid plugin manifest가 ledger에 기록되지 않았습니다: $invalid"
    }
    Assert-True ($script:ClaudeCalls -eq 0) '전체 검증 전에 claude가 호출되었습니다.'

    $invalidSkills = Join-Path $work 'skills-invalid.txt'
    @('owner/repo@skill', 'invalid skill') | Set-Content $invalidSkills -Encoding utf8
    $script:InstallFailures.Clear()
    Invoke-ClaudeSkillsStage $invalidSkills
    Assert-True ($script:NpxCalls -eq 0) '전체 skill 검증 전에 npx가 호출되었습니다.'
    $all = @(Complete-Install 6>&1); $output = $all | Out-String
    Assert-True ($all[-1] -eq $false -and -not $output.Contains('==> Done!')) 'stage 실패가 final failure/Done 억제로 연결되지 않았습니다.'

    $validPlugins = Join-Path $work 'plugins-valid.txt'
    'owner/market valid@market project' | Set-Content $validPlugins -Encoding utf8
    Assert-True (Restore-ClaudePlugins @(Get-ValidatedPluginRows $validPlugins)) 'valid scoped plugin fixture가 실패했습니다.'
    Assert-True ($script:ClaudeCalls -eq 2) 'plugin restore가 정확히 두 CLI 호출을 하지 않았습니다.'
    function global:claude { $script:ClaudeCalls++; $global:LASTEXITCODE = 7 }
    Assert-True (-not (Restore-ClaudePlugins @(Get-ValidatedPluginRows $validPlugins))) 'claude 실패가 plugin 실패로 전파되지 않았습니다.'

    $skills = Join-Path $work 'skills.txt'
    'owner/repo@skill' | Set-Content $skills -Encoding utf8
    function global:npx { $script:NpxCalls++; $global:LASTEXITCODE = 7 }
    Assert-True (-not (Restore-ClaudeSkills $skills)) 'npx 실패가 skill 실패로 전파되지 않았습니다.'
    Assert-True ($script:NpxCalls -eq 1) 'skill fixture의 npx 호출 수가 다릅니다.'

    Write-Host 'install failure contract checks passed'
} finally {
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item Env:SKIP_CLAUDE_CODE, Env:SKIP_SKILLS, Env:SKIP_PLUGINS -ErrorAction SilentlyContinue
    Remove-Item Function:\claude -ErrorAction SilentlyContinue
    Remove-Item Function:\npx -ErrorAction SilentlyContinue
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
