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
    $script:PackageCalls = 0
    $script:NpxCalls = 0
    function global:claude { $script:ClaudeCalls++; $global:LASTEXITCODE = 0 }
    function global:npx { $script:NpxCalls++; $global:LASTEXITCODE = 0 }
    $env:SKIP_PACKAGES = $env:SKIP_CLAUDE_CODE = $env:SKIP_SKILLS = $env:SKIP_PLUGINS = '1'
    Invoke-ClaudeSkillsStage (Join-Path $repo 'manifests\skills.txt')
    Invoke-ClaudePluginsStage (Join-Path $repo 'manifests\plugins.txt')
    Invoke-OptionalInstallStage 'SKIP_CLAUDE_CODE' 'claude skipped' { $script:ClaudeCalls++ }
    Invoke-OptionalInstallStage 'SKIP_PACKAGES' 'packages skipped' { $script:PackageCalls++ }
    Assert-True ($script:PackageCalls -eq 0 -and $script:ClaudeCalls -eq 0 -and $script:NpxCalls -eq 0) 'skip stage가 외부 CLI를 호출했습니다.'
    Remove-Item Env:SKIP_PACKAGES, Env:SKIP_CLAUDE_CODE, Env:SKIP_SKILLS, Env:SKIP_PLUGINS
    Invoke-OptionalInstallStage 'SKIP_CLAUDE_CODE' 'claude skipped' { $script:ClaudeCalls++ }
    Invoke-OptionalInstallStage 'SKIP_PACKAGES' 'packages skipped' { $script:PackageCalls++ }
    Assert-True ($script:PackageCalls -eq 1 -and $script:ClaudeCalls -eq 1) 'enabled optional stage action이 호출되지 않았습니다.'
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

    # shellcheck 바이너리가 아예 뜨지 못하는 환경(%TEMP% 실행을 막는 AppLocker/WDAC,
    # 파일을 잡고 있는 AV, x64 에뮬레이션 없는 ARM64)에서도 install이 끊기면 안 된다.
    # $ErrorActionPreference = 'Stop' 아래에서 native command 기동 실패는 terminating
    # error라, 가드가 없으면 1-8 한 단계가 install.ps1 전체를 끝낸다.
    $unlaunchable = Join-Path $work 'shellcheck.exe'
    Set-Content -LiteralPath $unlaunchable -Value 'not a PE image' -NoNewline
    Assert-True ($null -eq (Get-ShellCheckReportedVersion $unlaunchable)) '실행되지 않는 shellcheck 바이너리가 예외로 새어 나왔습니다.'

    # manifest validator는 install.sh의 awk validator와 같은 판정을 내려야 한다.
    # PowerShell 기본 비교는 case-insensitive라, -c* 없이는 대소문자가 틀린 행이
    # 여기만 통과하고 뒤의 case-sensitive 행 선택에서 $null 인덱싱으로 죽는다.
    function Read-ManifestRows([string]$Name) {
        @(Get-Content -LiteralPath (Join-Path $repo "manifests\$Name") |
            Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() } |
            ForEach-Object { , @($_ -split "`t") })
    }
    # platform(0)과 SHA-256(4)은 둘 다 소문자로만 유효하므로 대문자 사본은 거부되어야 한다.
    function Assert-ManifestCaseSensitivity([string]$Name, [string]$Validator) {
        $rows = Read-ManifestRows $Name
        Assert-True (& $Validator $rows) "실제 manifest가 유효하지 않습니다: $Name"
        foreach ($field in 0, 4) {
            $mutated = @($rows | ForEach-Object { , @($_) })
            $mutated[0][$field] = $mutated[0][$field].ToUpperInvariant()
            Assert-True (-not (& $Validator $mutated)) "case-insensitive 비교가 manifest를 통과시켰습니다: $Name field $field"
        }
    }
    Assert-ManifestCaseSensitivity 'shellcheck.tsv' 'Test-ShellCheckManifestRows'

    $skills = Join-Path $work 'skills.txt'
    'owner/repo@skill' | Set-Content $skills -Encoding utf8
    function global:npx { $script:NpxCalls++; $global:LASTEXITCODE = 7 }
    Assert-True (-not (Restore-ClaudeSkills $skills)) 'npx 실패가 skill 실패로 전파되지 않았습니다.'
    Assert-True ($script:NpxCalls -eq 1) 'skill fixture의 npx 호출 수가 다릅니다.'

    Write-Host 'install failure contract checks passed'
} finally {
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item Env:SKIP_PACKAGES, Env:SKIP_CLAUDE_CODE, Env:SKIP_SKILLS, Env:SKIP_PLUGINS -ErrorAction SilentlyContinue
    Remove-Item Function:\claude -ErrorAction SilentlyContinue
    Remove-Item Function:\npx -ErrorAction SilentlyContinue
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
