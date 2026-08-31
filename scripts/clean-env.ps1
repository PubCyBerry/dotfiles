#requires -Version 5.1
<#
.SYNOPSIS
    Windows 사용자 및 시스템 환경변수(PATH 등)를 안전하게 검사하고 정리하는 스크립트.

.DESCRIPTION
    - 유효하지 않은 경로(존재하지 않는 디렉터리) 제거
    - 중복 등록된 PATH 항목 제거
    - PATH 항목 내 불필요한 '.\' 상대 경로 정규화
    - 긴 경로 접두사를 환경변수로 압축 (%LOCALAPPDATA%, %USERPROFILE%, %SystemRoot%)
    - 옛 버전이 만든 %WINGET_PKGS% 압축을 실경로 기준으로 되돌리고, 참조가 사라지면 변수도 제거
    - 끝에 세미콜론(;)이 포함된 단일 환경변수 값 정리
    - 변경 전 레지스트리 백업(.reg) 자동 생성
    - REG_EXPAND_SZ 형식 보존 (%LOCALAPPDATA%, %USERPROFILE%, %SystemRoot% — 시스템이 확장하는 변수만)
    - sysdm.cpl 2047자 제한 준수 여부 및 절감 통계 출력
    - 환경변수 변경 사항 브로드캐스트(WM_SETTINGCHANGE) 전송

.PARAMETER Apply
    실제 변경 사항을 레지스트리에 적용합니다. (지정하지 않으면 미리보기/Dry-Run 모드로 동작)

.PARAMETER BackupDir
    백업 파일이 저장될 디렉터리 경로 (기본값: $HOME)

.PARAMETER NoCompress
    경로 접두사(%LOCALAPPDATA%, %USERPROFILE%, %SystemRoot%) 압축을 비활성화합니다.
#>

[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$BackupDir = "$HOME",
    [switch]$NoCompress
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Broadcast-EnvChange {
    try {
        if (-not ([System.Management.Automation.PSTypeName]'Win32.NativeMethods').Type) {
            Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
"@ -ErrorAction SilentlyContinue
        }
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x001A
        $SMTO_ABORTIFHUNG = 0x0002
        $result = [UIntPtr]::Zero
        [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, 3000, [ref]$result) | Out-Null
    } catch {
        Write-Warning "환경변수 변경 브로드캐스트 전송 중 알림: $_"
    }
}

function Backup-Environment([string]$destDir) {
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $userRegFile = Join-Path $destDir "env_user_backup_$timestamp.reg"
    $sysRegFile = Join-Path $destDir "env_system_backup_$timestamp.reg"

    Write-Host "[백업] 사용자 환경변수 백업 중: $userRegFile" -ForegroundColor Cyan
    Start-Process -FilePath "reg.exe" -ArgumentList "export `"HKCU\Environment`" `"$userRegFile`" /y" -Wait -NoNewWindow | Out-Null

    if (Test-IsAdmin) {
        Write-Host "[백업] 시스템 환경변수 백업 중: $sysRegFile" -ForegroundColor Cyan
        Start-Process -FilePath "reg.exe" -ArgumentList "export `"HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment`" `"$sysRegFile`" /y" -Wait -NoNewWindow | Out-Null
    } else {
        Write-Host "[백업 건너뜀] 시스템 환경변수 백업은 관리자 권한이 필요합니다." -ForegroundColor Yellow
    }
}

function Compress-PathEntry([string]$entry, [string]$scopeName) {
    if ($NoCompress) { return $entry }

    $localAppData = if ($env:LOCALAPPDATA) { [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\') } else { $null }
    $userProfile  = if ($env:USERPROFILE)  { [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') } else { $null }
    $systemRoot   = if ($env:SystemRoot)   { [IO.Path]::GetFullPath($env:SystemRoot).TrimEnd('\') } else { 'C:\WINDOWS' }

    $result = $entry

    if ($scopeName -eq "User") {
        # %WINGET_PKGS% 같은 "사용자 정의" 보조 변수로는 압축하지 않는다.
        #
        # 로그온 환경 자체는 그 변수도 푼다 — 중첩 참조(%WINGET_PKGS% -> %LOCALAPPDATA%\...
        # -> 실경로)까지 해석된다. 문제는 그 값을 읽고 판정하는 쪽이다. 확장을 프로세스
        # 환경으로만 하던 시절, WINGET_PKGS를 모르는 프로세스에서 install을 돌리자
        # %WINGET_PKGS%\... 가 풀리지 않아 Test-Path가 실패했고 14개가 "경로 미존재"로
        # 한꺼번에 삭제됐다. jq/yq/fnm/delta가 사라지고 git까지 죽은 실제 회귀다.
        #
        # 판정 쪽 방어는 아래 Expand-ScopedEnvVariables와 branch 0이 맡는다. 압축을
        # 시스템 변수로 한정하는 것은 그 위의 예방이다 — 레지스트리를 직접 읽거나
        # 프로세스 환경만 보는 소비자에게 단일 실패점을 만들지 않기 위해서다.
        #
        # 입력은 언제나 확장된 실경로다(Clean-PathString이 그렇게 넘긴다). 그래서 이미
        # %WINGET_PKGS%로 압축돼 있던 기존 항목도 이 지점을 지나며 허용된 변수로 다시
        # 압축된다 — 새로 만들지 않는 것만으로는 이미 그 상태인 머신이 고쳐지지 않는다.
        #
        # 1. %LOCALAPPDATA% 치환
        if ($localAppData -and $result.StartsWith($localAppData, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%LOCALAPPDATA%" + $result.Substring($localAppData.Length)
        }
        # 2. %USERPROFILE% 치환
        elseif ($userProfile -and $result.StartsWith($userProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%USERPROFILE%" + $result.Substring($userProfile.Length)
        }
    } elseif ($scopeName -eq "System") {
        # 3. 시스템 변수: %SystemRoot% 치환
        if ($systemRoot -and $result.StartsWith($systemRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%SystemRoot%" + $result.Substring($systemRoot.Length)
        }
    }

    return $result
}

# PATH 항목의 %VAR%를 "레지스트리 스코프" 기준으로 확장한다.
#
# [Environment]::ExpandEnvironmentVariables()는 현재 프로세스의 환경 블록만 본다.
# 그런데 PATH에는 이 스크립트가 만들지 않은 사용자 정의 변수가 들어 있을 수 있다.
# 그 변수를 모르는 프로세스에서 실행하면 %VAR%가 확장되지 않고,
# Test-Path가 실패해 그 변수를 쓰는 항목 전부가 "경로 미존재"로 삭제된다.
# 실제로 그렇게 WinGet 포터블 패키지 경로 14개가 한 번에 날아갔다.
# 그래서 확장은 Machine + User 레지스트리 값을 먼저 보고, 프로세스 값은 보완으로만 쓴다.
$script:ScopedEnvMap = $null
function Get-ScopedEnvMap {
    if ($script:ScopedEnvMap) { return $script:ScopedEnvMap }
    $map = @{}
    foreach ($scope in 'Process', 'Machine', 'User') {
        try { $vars = [Environment]::GetEnvironmentVariables($scope) } catch { continue }
        foreach ($key in $vars.Keys) { $map[[string]$key] = [string]$vars[$key] }
    }
    $script:ScopedEnvMap = $map
    return $map
}

function Expand-ScopedEnvVariables([string]$value) {
    if ([string]::IsNullOrEmpty($value)) { return $value }
    $map = Get-ScopedEnvMap
    $evaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $name = $m.Groups[1].Value
        if ($map.ContainsKey($name)) { return $map[$name] }
        return $m.Value
    }
    $result = $value
    # 변수가 변수를 참조할 수 있어 고정점까지 반복한다. 순환 참조는 횟수로 끊는다.
    for ($i = 0; $i -lt 8; $i++) {
        $next = [regex]::Replace($result, '%([^%]+)%', $evaluator)
        if ($next -ceq $result) { break }
        $result = $next
    }
    return $result
}

# 옛 버전이 만든 %WINGET_PKGS% 보조 변수를 정리한다.
#
# 압축이 시스템 변수만 쓰도록 바뀌면서 이 변수를 참조하던 PATH 항목은 위에서 실경로를
# 거쳐 %LOCALAPPDATA%로 되돌아간다. 그래도 변수 자체는 레지스트리에 남아 side effect가
# 된다. 지우는 조건은 셋을 모두 만족할 때뿐이다 — 값이 옛 스크립트가 쓴 것과 정확히
# 같고, User/System PATH 어디도 더는 참조하지 않을 때. 사용자가 다른 용도로 만든 동명
# 변수를 지우지 않기 위한 게이트다.
function Remove-StaleWingetPkgsVariable([Microsoft.Win32.RegistryKey]$userRegKey, [string]$cleanedUserPath, [string]$rawSystemPath) {
    if (-not $userRegKey) { return }
    $value = $userRegKey.GetValue('WINGET_PKGS', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($null -eq $value) { return }
    if ([string]$value -cne '%LOCALAPPDATA%\Microsoft\WinGet\Packages') {
        Write-Host "  [보존] WINGET_PKGS 값이 이 스크립트가 만든 것과 다릅니다: $value" -ForegroundColor DarkGray
        return
    }
    if ("$cleanedUserPath;$rawSystemPath" -match '%WINGET_PKGS%') {
        Write-Host "  [보존] WINGET_PKGS를 아직 참조하는 PATH 항목이 있습니다." -ForegroundColor DarkGray
        return
    }
    $userRegKey.DeleteValue('WINGET_PKGS', $false)
    Write-Host "✓ 옛 WINGET_PKGS 변수를 제거했습니다 (PATH가 더는 참조하지 않습니다)." -ForegroundColor Green
}

function Clean-PathString([string]$rawPath, [string]$scopeName) {
    if ([string]::IsNullOrWhiteSpace($rawPath)) {
        return @{ Cleaned = ""; Removed = @(); Modified = $false; BeforeLen = 0; AfterLen = 0; WinGetCount = 0 }
    }

    $entries = $rawPath -split ';'
    $cleanedList = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $removedList = [System.Collections.Generic.List[string]]::new()
    $wingetCount = 0

    foreach ($rawEntry in $entries) {
        if ([string]::IsNullOrWhiteSpace($rawEntry)) {
            continue
        }

        $entry = $rawEntry.Trim()

        # .\ 표기 정규화 (예: ...\.\bun-windows-x64 -> ...\bun-windows-x64)
        $normalized = $entry -replace '\\\.\\', '\'
        $expanded = Expand-ScopedEnvVariables $normalized

        # 시스템 루트 정규화 비교용 키
        $normKey = $expanded.TrimEnd('\')

        # 0. 확장되지 않은 %VAR%가 남았으면 판정하지 않고 보존한다.
        #    어느 스코프에도 없는 변수라 존재 여부를 알 수 없고, 모르는 것을 지우면
        #    이 스크립트가 만든 %WINGET_PKGS% 참조처럼 멀쩡한 항목이 통째로 사라진다.
        if ($expanded -match '%[^%]+%') {
            [void]$seen.Add($normKey)
            $cleanedList.Add($normalized)
            continue
        }

        # 1. 경로 존재 여부 검사
        $exists = Test-Path -LiteralPath $expanded -ErrorAction SilentlyContinue
        if (-not $exists) {
            $removedList.Add("$entry (원인: 경로 미존재 -> $expanded)")
            continue
        }

        # 2. 중복 검사
        if ($seen.Contains($normKey)) {
            $removedList.Add("$entry (원인: 중복 경로 -> $expanded)")
            continue
        }

        if ($normKey -match 'Microsoft\\WinGet\\Packages') {
            $wingetCount++
        }

        [void]$seen.Add($normKey)

        # 3. 경로 압축 적용. 저장된 형태가 아니라 확장된 실경로를 넘긴다 —
        #    옛 %WINGET_PKGS% 항목을 허용된 변수로 되돌리는 것이 이 인자다.
        $compressed = Compress-PathEntry $expanded $scopeName
        $cleanedList.Add($compressed)
    }

    $newPath = $cleanedList -join ';'
    $isModified = ($rawPath -ne $newPath)

    return @{
        Cleaned     = $newPath
        Removed     = $removedList
        Modified    = $isModified
        BeforeLen   = $rawPath.Length
        AfterLen    = $newPath.Length
        WinGetCount = $wingetCount
    }
}

function Invoke-CleanEnvironment {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "         Windows 환경변수 안전 정리 도구                 " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green

    if (-not $Apply) {
        Write-Host " [안내] 현재는 미리보기(Dry-Run) 모드입니다." -ForegroundColor Yellow
        Write-Host " 실제 레지스트리에 적용하려면 -Apply 옵션을 주고 실행하세요." -ForegroundColor Yellow
        Write-Host " 예: pwsh scripts/clean-env.ps1 -Apply`n" -ForegroundColor Gray
    }

    # ---------------------------------------------------------
    # 1. 사용자(User) 환경변수 점검 및 정리
    # ---------------------------------------------------------
    Write-Host "▶ [1/2] 사용자(User) 환경변수 검사" -ForegroundColor Cyan

    $userRegKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $Apply)
    $rawUserPath = if ($userRegKey) { $userRegKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { "" }

    $userPathResult = Clean-PathString -rawPath $rawUserPath -scopeName "User"

    if ($userPathResult.Removed.Count -gt 0) {
        Write-Host "  [User Path 제거 대상 항목]" -ForegroundColor Yellow
        foreach ($item in $userPathResult.Removed) {
            Write-Host "    - $item" -ForegroundColor Red
        }
    } else {
        Write-Host "  [User Path] 정리할 잘못된 경로가 없습니다." -ForegroundColor Green
    }

    # 길이 통계 및 2047자 제한 점검
    $userBefore = $userPathResult.BeforeLen
    $userAfter = $userPathResult.AfterLen
    $savedChars = $userBefore - $userAfter
    Write-Host "  [User Path 길이] $userBefore 자 -> $userAfter 자 (절감: $savedChars 자)" -ForegroundColor Gray

    if ($userAfter -gt 2047) {
        Write-Host "  ⚠ [경고] 정리 후에도 User PATH가 2047자를 초과합니다 ($userAfter / 2047). sysdm.cpl 대화상자 저장 불가." -ForegroundColor Red
    } else {
        Write-Host "  ✓ [정상] User PATH 길이가 2047자 제한 이내입니다 ($userAfter / 2047)." -ForegroundColor Green
    }

    # 개별 사용자 변수 끝 세미콜론 검사
    $userVarFixes = @{}
    if ($userRegKey) {
        foreach ($valName in $userRegKey.GetValueNames()) {
            if ($valName -eq "Path") { continue }
            $val = $userRegKey.GetValue($valName, "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($val -is [string] -and $val.EndsWith(';') -and -not [string]::IsNullOrWhiteSpace($val.TrimEnd(';'))) {
                $trimmedVal = $val.TrimEnd(';')
                $userVarFixes[$valName] = $trimmedVal
                Write-Host "  [User Variable 수정 대상] $valName : '$val' -> '$trimmedVal'" -ForegroundColor Yellow
            }
        }
    }

    # ---------------------------------------------------------
    # 2. 시스템(Machine) 환경변수 검사
    # ---------------------------------------------------------
    Write-Host "`n▶ [2/2] 시스템(Machine) 환경변수 검사" -ForegroundColor Cyan

    $isAdmin = Test-IsAdmin
    $sysRegKey = if ($isAdmin -and $Apply) {
        [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment", $true)
    } else {
        [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment", $false)
    }

    $rawSysPath = if ($sysRegKey) { $sysRegKey.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) } else { "" }
    $sysPathResult = Clean-PathString -rawPath $rawSysPath -scopeName "System"

    if ($sysPathResult.Removed.Count -gt 0) {
        Write-Host "  [System Path 제거 대상 항목]" -ForegroundColor Yellow
        foreach ($item in $sysPathResult.Removed) {
            Write-Host "    - $item" -ForegroundColor Red
        }
    } else {
        Write-Host "  [System Path] 정리할 잘못된 경로가 없습니다." -ForegroundColor Green
    }

    $sysBefore = $sysPathResult.BeforeLen
    $sysAfter = $sysPathResult.AfterLen
    $sysSaved = $sysBefore - $sysAfter
    Write-Host "  [System Path 길이] $sysBefore 자 -> $sysAfter 자 (절감: $sysSaved 자)" -ForegroundColor Gray

    if (-not $isAdmin) {
        Write-Host "  [참고] 시스템 환경변수를 실제로 수정하려면 관리자 권한(Run as Administrator)으로 실행해야 합니다." -ForegroundColor DarkGray
    }

    # ---------------------------------------------------------
    # 3. 적용 (Apply 모드인 경우)
    # ---------------------------------------------------------
    if ($Apply) {
        Write-Host "`n==========================================================" -ForegroundColor Cyan
        Write-Host "                  변경 사항 적용 중...                     " -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan

        Backup-Environment -destDir $BackupDir

        # User Path 적용 (REG_EXPAND_SZ 형식 보존)
        if ($userPathResult.Modified -and $userRegKey) {
            $userRegKey.SetValue("Path", $userPathResult.Cleaned, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            Write-Host "✓ User Path 가 정리되었습니다." -ForegroundColor Green
        }

        # 옛 보조 변수 정리 (PATH를 먼저 쓴 뒤에 본다)
        Remove-StaleWingetPkgsVariable $userRegKey $userPathResult.Cleaned ([string]$rawSysPath)

        # User 개별 변수 적용
        if ($userRegKey) {
            foreach ($k in $userVarFixes.Keys) {
                $v = $userVarFixes[$k]
                $kind = $userRegKey.GetValueKind($k)
                $userRegKey.SetValue($k, $v, $kind)
                Write-Host "✓ User 변수 '$k'의 끝 세미콜론이 제거되었습니다." -ForegroundColor Green
            }
        }

        # System Path 적용
        if ($isAdmin -and $sysPathResult.Modified -and $sysRegKey) {
            $sysRegKey.SetValue("Path", $sysPathResult.Cleaned, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            Write-Host "✓ System Path 가 정리되었습니다." -ForegroundColor Green
        } elseif (-not $isAdmin -and $sysPathResult.Modified) {
            Write-Host "⚠ 시스템 Path 수정은 관리자 권한이 없어 건너뛰었습니다." -ForegroundColor Yellow
        }

        if ($userRegKey) { $userRegKey.Close() }
        if ($sysRegKey) { $sysRegKey.Close() }

        Write-Host "`n환경변수 변경 브로드캐스트 알림을 전송하는 중..." -ForegroundColor Cyan
        Broadcast-EnvChange
        Write-Host "✓ 완료되었습니다. 새로 여는 터미널 및 프로그램부터 적용됩니다." -ForegroundColor Green
    } else {
        if ($userRegKey) { $userRegKey.Close() }
        if ($sysRegKey) { $sysRegKey.Close() }
        Write-Host "`n미리보기가 완료되었습니다. 적용을 원하시면 -Apply 옵션을 붙여 실행하세요." -ForegroundColor Cyan
    }
}

if ($MyInvocation.InvocationName -ne '.' -and -not $env:DOTFILES_FUNCTIONS_ONLY) {
    Invoke-CleanEnvironment
}
