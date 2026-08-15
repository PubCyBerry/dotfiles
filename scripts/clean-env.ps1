#requires -Version 5.1
<#
.SYNOPSIS
    Windows 사용자 및 시스템 환경변수(PATH 등)를 안전하게 검사하고 정리하는 스크립트.

.DESCRIPTION
    - 유효하지 않은 경로(존재하지 않는 디렉터리) 제거
    - 중복 등록된 PATH 항목 제거
    - PATH 항목 내 불필요한 '.\' 상대 경로 정규화
    - 반복되는 WinGet 포터블 패키지 경로를 %WINGET_PKGS% 보조 환경변수로 압축
    - 긴 경로 접두사를 환경변수로 압축 (%LOCALAPPDATA%, %USERPROFILE%, %SystemRoot%)
    - 끝에 세미콜론(;)이 포함된 단일 환경변수 값 정리
    - 변경 전 레지스트리 백업(.reg) 자동 생성
    - REG_EXPAND_SZ 형식 보존 (%LOCALAPPDATA%, %USERPROFILE%, %WINGET_PKGS% 등 확장 유지)
    - sysdm.cpl 2047자 제한 준수 여부 및 절감 통계 출력
    - 환경변수 변경 사항 브로드캐스트(WM_SETTINGCHANGE) 전송

.PARAMETER Apply
    실제 변경 사항을 레지스트리에 적용합니다. (지정하지 않으면 미리보기/Dry-Run 모드로 동작)

.PARAMETER BackupDir
    백업 파일이 저장될 디렉터리 경로 (기본값: $HOME)

.PARAMETER NoCompress
    경로 접두사(%WINGET_PKGS%, %LOCALAPPDATA%, %USERPROFILE% 등) 압축을 비활성화합니다.
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

function Compress-PathEntry([string]$entry, [string]$scopeName, [bool]$hasWingetPkgs) {
    if ($NoCompress) { return $entry }

    $localAppData = if ($env:LOCALAPPDATA) { [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\') } else { $null }
    $userProfile  = if ($env:USERPROFILE)  { [IO.Path]::GetFullPath($env:USERPROFILE).TrimEnd('\') } else { $null }
    $systemRoot   = if ($env:SystemRoot)   { [IO.Path]::GetFullPath($env:SystemRoot).TrimEnd('\') } else { 'C:\WINDOWS' }

    $result = $entry

    if ($scopeName -eq "User") {
        # 1. WinGet 포터블 패키지 경로를 %WINGET_PKGS% 로 압축
        if ($hasWingetPkgs -and $localAppData) {
            $wingetPkgFull = Join-Path $localAppData "Microsoft\WinGet\Packages"
            if ($result.StartsWith($wingetPkgFull, [System.StringComparison]::OrdinalIgnoreCase)) {
                return "%WINGET_PKGS%" + $result.Substring($wingetPkgFull.Length)
            }
            if ($result.StartsWith("%LOCALAPPDATA%\Microsoft\WinGet\Packages", [System.StringComparison]::OrdinalIgnoreCase)) {
                return "%WINGET_PKGS%" + $result.Substring("%LOCALAPPDATA%\Microsoft\WinGet\Packages".Length)
            }
        }

        # 2. %LOCALAPPDATA% 치환
        if ($localAppData -and $result.StartsWith($localAppData, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%LOCALAPPDATA%" + $result.Substring($localAppData.Length)
        }
        # 3. %USERPROFILE% 치환
        elseif ($userProfile -and $result.StartsWith($userProfile, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%USERPROFILE%" + $result.Substring($userProfile.Length)
        }
    } elseif ($scopeName -eq "System") {
        # 시스템 변수: %SystemRoot% 치환
        if ($systemRoot -and $result.StartsWith($systemRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $result = "%SystemRoot%" + $result.Substring($systemRoot.Length)
        }
    }

    return $result
}

function Clean-PathString([string]$rawPath, [string]$scopeName, [bool]$useWingetPkgs = $true) {
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
        $expanded = [System.Environment]::ExpandEnvironmentVariables($normalized)

        # 시스템 루트 정규화 비교용 키
        $normKey = $expanded.TrimEnd('\')

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

        # 3. 경로 압축 적용
        $compressed = Compress-PathEntry $normalized $scopeName $useWingetPkgs
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

    $userPathResult = Clean-PathString -rawPath $rawUserPath -scopeName "User" -useWingetPkgs (-not $NoCompress)

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

    if ($userPathResult.WinGetCount -gt 0 -and (-not $NoCompress)) {
        Write-Host "  [WinGet 포터블 패키지] $($userPathResult.WinGetCount)개 경로를 %WINGET_PKGS% 로 압축합니다." -ForegroundColor Cyan
    }

    if ($userAfter -gt 2047) {
        Write-Host "  ⚠ [경고] 정리 후에도 User PATH가 2047자를 초과합니다 ($userAfter / 2047). sysdm.cpl 대화상자 저장 불가." -ForegroundColor Red
    } else {
        Write-Host "  ✓ [정상] User PATH 길이가 2047자 제한 이내입니다 ($userAfter / 2047)." -ForegroundColor Green
    }

    # 개별 사용자 변수 끝 세미콜론 검사
    $userVarFixes = @{}
    if ($userRegKey) {
        foreach ($valName in $userRegKey.GetValueNames()) {
            if ($valName -eq "Path" -or $valName -eq "WINGET_PKGS") { continue }
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
    $sysPathResult = Clean-PathString -rawPath $rawSysPath -scopeName "System" -useWingetPkgs $false

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

        # WINGET_PKGS 보조 변수 등록 (포터블 패키지가 있고 NoCompress가 아닐 때)
        if ($userPathResult.WinGetCount -gt 0 -and (-not $NoCompress) -and $userRegKey) {
            $userRegKey.SetValue("WINGET_PKGS", "%LOCALAPPDATA%\Microsoft\WinGet\Packages", [Microsoft.Win32.RegistryValueKind]::ExpandString)
            Write-Host "✓ WINGET_PKGS 변수 등록: %LOCALAPPDATA%\Microsoft\WinGet\Packages" -ForegroundColor Green
        }

        # User Path 적용 (REG_EXPAND_SZ 형식 보존)
        if ($userPathResult.Modified -and $userRegKey) {
            $userRegKey.SetValue("Path", $userPathResult.Cleaned, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            Write-Host "✓ User Path 가 정리되었습니다." -ForegroundColor Green
        }

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
