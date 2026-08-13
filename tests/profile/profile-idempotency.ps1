$ErrorActionPreference = "Stop"

$repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$work = Join-Path $PSScriptRoot ".profile-idempotency-$PID"

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-ProfileRejected([string]$Path, [string]$Value, [string]$Case) {
    $Value | Set-Content $Path -Encoding utf8 -NoNewline
    $before = (Get-FileHash $Path).Hash
    $failed = $false
    try {
        Set-ProfileBlock $Path "managed"
    } catch {
        $failed = $true
    }
    Assert-True $failed "$Case marker가 실패로 반환되지 않았습니다."
    Assert-True ($before -eq (Get-FileHash $Path).Hash) "$Case marker에서 원본이 변경됐습니다."
}

try {
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    $env:DOTFILES_FUNCTIONS_ONLY = "1"
    . (Join-Path $repo "install.ps1")
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY

    $installSource = Get-Content (Join-Path $repo "install.ps1") -Raw
    Assert-True ($installSource.Contains('$PROFILE.CurrentUserCurrentHost')) "platform profile 경로를 사용하지 않습니다."
    Assert-True (-not $installSource.Contains('$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1')) "Documents profile 경로가 hard-code되었습니다."

    $localizedProfile = Join-Path $work "문서\PowerShell\Microsoft.PowerShell_profile.ps1"
    $nl = [Environment]::NewLine
    New-Item -ItemType Directory -Force -Path (Split-Path $localizedProfile) | Out-Null
    "user-before${nl}# ===== dotfiles-begin =====${nl}old${nl}# ===== dotfiles-end =====${nl}user-after${nl}" |
        Set-Content $localizedProfile -Encoding utf8 -NoNewline
    $block = "`$HOME\literal`nfunction global:ccd { claude @args }"
    Set-ProfileBlock $localizedProfile $block
    $firstHash = (Get-FileHash $localizedProfile).Hash
    Set-ProfileBlock $localizedProfile $block
    Assert-True ($firstHash -eq (Get-FileHash $localizedProfile).Hash) "PowerShell profile 2회 적용 결과가 다릅니다."

    $content = Get-Content $localizedProfile -Raw
    Assert-True ($content.Contains("user-before$nl")) "PowerShell profile 앞 sentinel이 손상됐습니다."
    Assert-True ($content.Contains("${nl}user-after$nl")) "PowerShell profile 뒤 sentinel이 손상됐습니다."
    Assert-True ($content.Contains('$HOME\literal')) "PowerShell profile literal content가 손상됐습니다."

    $bashProfile = Join-Path $work ".bash_profile"
    "bash-before`nbash-after`n" | Set-Content $bashProfile -Encoding utf8 -NoNewline
    Set-ProfileBlock $bashProfile "[[ -f ~/.bashrc ]] && . ~/.bashrc"
    Set-ProfileBlock $bashProfile "[[ -f ~/.bashrc ]] && . ~/.bashrc"
    $bashContent = Get-Content $bashProfile -Raw
    Assert-True ($bashContent.Contains("bash-before`n")) ".bash_profile 앞 sentinel이 손상됐습니다."
    Assert-True ($bashContent.Contains("`nbash-after`n")) ".bash_profile 뒤 sentinel이 손상됐습니다."
    Assert-True ((Select-String -Path $bashProfile -SimpleMatch "[[ -f ~/.bashrc ]] && . ~/.bashrc").Count -eq 1) ".bashrc source가 중복됐습니다."

    $invalidProfile = Join-Path $work "invalid-profile.ps1"
    $begin = "# ===== dotfiles-begin ====="
    $end = "# ===== dotfiles-end ====="
    Assert-ProfileRejected $invalidProfile "custom-prefix $begin${nl}user-command${nl}custom-suffix $end${nl}" "inline"
    Assert-ProfileRejected $invalidProfile "user-before${nl}$end${nl}user-middle${nl}$begin${nl}user-after${nl}" "reverse"
    Assert-ProfileRejected $invalidProfile "user-before${nl}$begin${nl}interrupted${nl}user-after${nl}" "incomplete"
    Assert-ProfileRejected $invalidProfile "$begin${nl}one${nl}$end${nl}$begin${nl}two${nl}$end${nl}" "duplicate"

    $beginMatch = [regex]::Match($content, "(?m)^$([regex]::Escape($begin))(?=\r?$)")
    $endMatch = [regex]::Match($content, "(?m)^$([regex]::Escape($end))(?=\r?$)")
    $afterEnd = $endMatch.Index + $endMatch.Length
    if ($content.Substring($afterEnd).StartsWith("`r`n")) { $afterEnd += 2 }
    elseif ($content.Substring($afterEnd).StartsWith("`n")) { $afterEnd++ }
    $removed = $content.Substring(0, $beginMatch.Index) + $content.Substring($afterEnd)
    Assert-True ($removed -eq "user-before${nl}user-after${nl}") "제거 후 사용자 sentinel 줄이 그대로 보존되지 않았습니다."

    Write-Host "PowerShell profile idempotency checks passed"
} finally {
    Remove-Item Env:DOTFILES_FUNCTIONS_ONLY -ErrorAction SilentlyContinue
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
