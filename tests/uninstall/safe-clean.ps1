$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot)
$temp = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-uninstall-$([guid]::NewGuid())"
$old = @{ profile=$env:USERPROFILE; local=$env:LOCALAPPDATA; app=$env:APPDATA; fnm=$env:FNM_DIR; receipt=$env:DOTFILES_RECEIPT_PATH; functions=$env:DOTFILES_FUNCTIONS_ONLY; git=$env:GIT_CONFIG_GLOBAL }
try {
    $env:USERPROFILE=Join-Path $temp home; $env:LOCALAPPDATA=Join-Path $env:USERPROFILE 'AppData\Local'; $env:APPDATA=Join-Path $env:USERPROFILE 'AppData\Roaming'; $env:FNM_DIR=Join-Path $env:APPDATA fnm; $env:DOTFILES_RECEIPT_PATH=Join-Path $env:USERPROFILE '.state\receipt.json'; $env:DOTFILES_FUNCTIONS_ONLY='1'; $env:GIT_CONFIG_GLOBAL=Join-Path $temp gitconfig
    New-Item -ItemType Directory -Force $env:USERPROFILE,$env:LOCALAPPDATA,$env:APPDATA,(Split-Path $env:DOTFILES_RECEIPT_PATH) | Out-Null
    . (Join-Path $root uninstall.ps1)
    function Assert($ok,$message) { if (-not $ok) { throw $message } }
    $nullProbe = "DOTFILES_NULL_PROBE_$PID"
    [Environment]::SetEnvironmentVariable($nullProbe,'managed','Process'); [Environment]::SetEnvironmentVariable($nullProbe,(ConvertTo-DotfilesEnvironmentValue $null),'Process')
    Assert ($null -eq [Environment]::GetEnvironmentVariable($nullProbe,'Process')) env_delete_null
    $section = ''
    foreach ($line in Get-Content (Join-Path $root 'config\git\gitconfig')) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\[(.+)\]$') { $section = $Matches[1] }
        elseif ($trimmed -match '^([^#\s=]+)\s*=') { Assert (Test-ValueKeyAllowed "git:$section.$($Matches[1])") "git_value_allowlist:$section.$($Matches[1])" }
    }
    Assert (Test-ValueKeyAllowed 'git:core.autocrlf') git_autocrlf_allowlist
    Assert (Test-ValueKeyAllowed 'git:core.fileMode') git_filemode_allowlist
    Assert (-not (Test-ValueKeyAllowed 'git:user.name')) unmanaged_git_value_allowed
    Assert (Test-ArtifactAllowed (Join-Path $env:USERPROFILE '.codex\agents\planner.toml')) agent_allowlist
    Assert (-not (Test-ArtifactAllowed (Join-Path $env:USERPROFILE '.codex\agents\planner.md'))) agent_extension
    Assert (-not (Test-ArtifactAllowed (Join-Path $env:USERPROFILE '.codex\agents\nested\planner.toml'))) agent_nested
    $goodPrefix=Join-Path $env:APPDATA 'fnm\node-versions\v22\installation'
    New-Item -ItemType Directory -Force $goodPrefix | Out-Null
    Assert (Test-NpmPrefixAllowed $goodPrefix) npm_prefix
    Assert (-not (Test-NpmPrefixAllowed (Join-Path $env:USERPROFILE 'project\node-versions\v22\installation'))) npm_project_prefix
    Assert (Test-ValueKeyAllowed ('env:PATH:'+(Join-Path $env:FNM_DIR 'aliases\default'))) fnm_path
    Assert (-not (Test-ValueKeyAllowed ('env:PATH:'+(Join-Path $env:USERPROFILE 'project\fnm\aliases\default')))) fnm_project_path
    $script:MockEnv=@{PATH='A;;C:\Tools;B;';YAZI_FILE_ONE='managed'}
    function Get-DotfilesUserEnvironment([string]$Name) { $script:MockEnv[$Name] }
    function Set-DotfilesUserEnvironment([string]$Name,[AllowNull()][object]$Value) { if($null -eq $Value){$script:MockEnv.Remove($Name)}else{$script:MockEnv[$Name]=$Value} }
    $profile=Join-Path $env:USERPROFILE profile.ps1
    [IO.File]::WriteAllText($profile,"user`n# ===== dotfiles-begin =====`nmanaged`n# ===== dotfiles-end =====`nafter`n")
    Assert (Remove-DotfilesMarkerBlock $profile) marker; Assert (-not (Get-Content $profile -Raw).Contains('dotfiles-begin')) marker_removed
    [IO.File]::WriteAllText($profile,"# ===== dotfiles-begin =====`nx`n# ===== dotfiles-begin =====`n# ===== dotfiles-end =====")
    $h=(Get-FileHash $profile).Hash; Assert (-not (Remove-DotfilesMarkerBlock $profile)) marker_duplicate; Assert ((Get-FileHash $profile).Hash -eq $h) marker_preserved

    $fresh=Join-Path $env:USERPROFILE .tmux.conf; Set-Content $fresh managed -NoNewline; $fh=(Get-FileHash $fresh).Hash.ToLowerInvariant()
    $unsafe=Join-Path $env:USERPROFILE unsafe.txt; Set-Content $unsafe keep -NoNewline; $uh=(Get-FileHash $unsafe).Hash.ToLowerInvariant()
    git config --global core.editor installed
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{
        $fresh=[ordered]@{before=[ordered]@{exists=$false;hash=$null;backup=$null};installedHash=$fh;pending=$false}
        $unsafe=[ordered]@{before=[ordered]@{exists=$false};installedHash=$uh;pending=$false}
    };packages=[ordered]@{};values=[ordered]@{
        'git:core.editor'=[ordered]@{before=[ordered]@{present=$true;value='user'};installed='installed'}
        'env:PATH:C:\Tools'=[ordered]@{before=[ordered]@{present=$false};installed='present'}
        'env:YAZI_FILE_ONE'=[ordered]@{before=[ordered]@{present=$true;value='user-yazi'};installed='managed'}
    }}
    Save-UninstallReceipt
    Assert (Remove-ManagedArtifact $fresh) fresh; Assert (-not (Test-Path $fresh)) fresh_removed
    Assert (-not (Remove-ManagedArtifact $unsafe)) unsafe; Assert ((Get-Content $unsafe -Raw) -eq 'keep') unsafe_preserved
    Assert (Remove-ManagedValue 'git:core.editor') git_value; Assert ((git config --global core.editor) -eq 'user') git_restored
    Assert (Remove-ManagedValue 'env:PATH:C:\Tools') path_value; Assert ($script:MockEnv.PATH -eq 'A;;B;') path_exact
    Assert (Remove-ManagedValue 'env:YAZI_FILE_ONE') yazi; Assert ($script:MockEnv.YAZI_FILE_ONE -eq 'user-yazi') yazi_restored
    $script:Receipt.values['env:YAZI_FILE_ONE']=[ordered]@{before=[ordered]@{present=$false;value=$null};installed=$null;pending=[ordered]@{previousPresent=$false;previousValue=$null;target='target'}}; $script:MockEnv.YAZI_FILE_ONE='target'; Save-UninstallReceipt
    Assert (Remove-ManagedValue 'env:YAZI_FILE_ONE') yazi_pending_target; Assert ($null -eq $script:MockEnv.YAZI_FILE_ONE) yazi_pending_restored
    $script:Receipt.values['env:PATH:C:\Tools']=[ordered]@{before=[ordered]@{present=$false};installed='present'}; $script:MockEnv.PATH='A;c:\tools;B'; Save-UninstallReceipt
    Assert (Remove-ManagedValue 'env:PATH:C:\Tools') path_case; Assert ($script:MockEnv.PATH -eq 'A;B') path_case_restored
    $script:Receipt.values['env:PATH:C:\Tools']=[ordered]@{before=[ordered]@{present=$false};installed='present'}; $script:MockEnv.PATH='C:\Tools;c:\tools'; Save-UninstallReceipt
    Assert (-not (Remove-ManagedValue 'env:PATH:C:\Tools')) path_duplicate; Assert ($script:Receipt.values.Contains('env:PATH:C:\Tools')) path_duplicate_receipt
    $savedSetter=(Get-Command Set-DotfilesUserEnvironment).ScriptBlock
    function Set-DotfilesUserEnvironment([string]$Name,[AllowNull()][object]$Value) { }
    $script:Receipt.values['env:YAZI_FILE_ONE']=[ordered]@{before=[ordered]@{present=$false;value=$null};installed='managed'};$script:MockEnv.YAZI_FILE_ONE='managed';Save-UninstallReceipt
    Assert (-not (Remove-ManagedValue 'env:YAZI_FILE_ONE')) yazi_noop_setter;Assert ($script:Receipt.values.Contains('env:YAZI_FILE_ONE')) yazi_noop_receipt
    Set-Item Function:Set-DotfilesUserEnvironment $savedSetter

    # Actual Invoke: stable pending은 같은 호출에서 제거한다.
    $stable=Join-Path $env:USERPROFILE .tmux.conf;Set-Content $stable stable -NoNewline;$stableHash=(Get-FileHash $stable).Hash.ToLowerInvariant()
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{$stable=[ordered]@{before=[ordered]@{exists=$false};installedHash=$stableHash;pending=$true;targetHash='new';previousExists=$true;previousHash=$stableHash}};packages=[ordered]@{};values=[ordered]@{}}
    Save-UninstallReceipt;Set-Content $profile '# user';$env:DOTFILES_PS_PROFILE_PATH=$profile
    Assert ((Invoke-SafeCleanUninstall) -eq 0) pending_stable_invoke;Assert (-not (Test-Path $stable)) pending_stable_removed

    # Restore 뒤 receipt save 실패도 before identity + canonical backup 부재로 재실행 수렴한다.
    $restore=Join-Path $env:USERPROFILE '.tmux.conf';$backup="$restore.dotfiles-backup";Set-Content $restore managed -NoNewline;Set-Content $backup original -NoNewline
    $managedHash=(Get-FileHash $restore).Hash.ToLowerInvariant();$originalHash=(Get-FileHash $backup).Hash.ToLowerInvariant()
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{$restore=[ordered]@{before=[ordered]@{exists=$true;hash=$originalHash;backup=$backup};installedHash=$null;pending=$true;targetHash=$managedHash;previousExists=$true;previousHash=$originalHash}};packages=[ordered]@{};values=[ordered]@{}}
    Save-UninstallReceipt;$savedSave=(Get-Command Save-UninstallReceipt).ScriptBlock
    function Save-UninstallReceipt { throw 'fault' }
    $faulted=$false;try{Remove-ManagedArtifact $restore|Out-Null}catch{$faulted=$true};Assert $faulted restore_commit_fault
    Assert ((Get-Content $restore -Raw) -eq 'original' -and -not (Test-Path $backup)) restore_before_commit
    Set-Item Function:Save-UninstallReceipt $savedSave;$script:Receipt=Get-Content $env:DOTFILES_RECEIPT_PATH -Raw|ConvertFrom-Json -AsHashtable
    Assert (Remove-ManagedArtifact $restore) restore_commit_retry

    # Fresh pending인데 package가 현재 존재하면 installer 소유임을 증명할 수 없어 보존한다.
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{};packages=[ordered]@{'winget:Git.Git'=[ordered]@{before=[ordered]@{present=$false};installed=$null;pending=[ordered]@{previousPresent=$false;newEntry=$true}}};values=[ordered]@{}}
    $script:PackageRemoved=$false
    function Get-CurrentPackage([string]$Key){$script:PackageState='present';$script:PackageVersion='9';$true}
    function Remove-DotfilesPackage([string]$Key){$script:PackageRemoved=$true;$true}
    Assert (-not (Remove-ManagedPackage 'winget:Git.Git')) pending_fresh_present_preserved
    Assert (-not $script:PackageRemoved -and $script:Receipt.packages.Contains('winget:Git.Git')) pending_fresh_present_no_remove

    # Arbitrary backup은 whole preflight에서 marker 포함 zero mutation.
    $managed=Join-Path $env:USERPROFILE .tmux.conf;$sentinel=Join-Path $env:USERPROFILE user-backup.txt;Set-Content $managed same -NoNewline;Set-Content $sentinel same -NoNewline;$sameHash=(Get-FileHash $managed).Hash.ToLowerInvariant()
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{$managed=[ordered]@{before=[ordered]@{exists=$true;hash=$sameHash;backup=$sentinel};installedHash=$sameHash;pending=$false}};packages=[ordered]@{};values=[ordered]@{}}
    Save-UninstallReceipt;Set-Content $profile "# ===== dotfiles-begin =====`nx`n# ===== dotfiles-end ====="
    Assert ((Invoke-SafeCleanUninstall) -eq 1) arbitrary_backup_preflight;Assert ((Test-Path $sentinel)) arbitrary_backup_sentinel;Assert ((Get-Content $profile -Raw) -match 'dotfiles-begin') arbitrary_backup_zero_mutation
    # Impossible PATH provenance는 mutation 전에 whole receipt를 거부한다.
    $script:Receipt=[ordered]@{schemaVersion=1;artifacts=[ordered]@{};packages=[ordered]@{};values=[ordered]@{'env:PATH:C:\Tools'=[ordered]@{before=[ordered]@{present=$true;value='present'};installed='present'}}}
    Save-UninstallReceipt;$script:MockEnv.PATH='A;C:\Tools;B';Set-Content $profile "# ===== dotfiles-begin =====`nx`n# ===== dotfiles-end ====="
    Assert ((Invoke-SafeCleanUninstall) -eq 1) impossible_path_schema;Assert ($script:MockEnv.PATH -eq 'A;C:\Tools;B') impossible_path_no_mutation;Assert ((Get-Content $profile -Raw) -match 'dotfiles-begin') impossible_path_zero_marker
    Remove-Item $env:DOTFILES_RECEIPT_PATH -Force; [IO.File]::WriteAllText($profile,"# ===== dotfiles-begin =====`nx`n# ===== dotfiles-end =====")
    $env:DOTFILES_PS_PROFILE_PATH=$profile; Assert ((Invoke-SafeCleanUninstall) -eq 0) absent; Assert (-not ((Get-Content $profile -Raw) -match 'dotfiles-begin')) absent_marker
    Set-Content $env:DOTFILES_RECEIPT_PATH invalid -NoNewline; [IO.File]::WriteAllText($profile,"# ===== dotfiles-begin =====`nx`n# ===== dotfiles-end =====")
    Assert ((Invoke-SafeCleanUninstall) -eq 1) invalid; Assert ((Get-Content $profile -Raw).Contains('dotfiles-begin')) invalid_no_mutation
    'safe-clean uninstall PowerShell: PASS'
} finally {
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
    foreach($k in $old.Keys){$name= switch($k){profile{'USERPROFILE'}local{'LOCALAPPDATA'}app{'APPDATA'}fnm{'FNM_DIR'}receipt{'DOTFILES_RECEIPT_PATH'}functions{'DOTFILES_FUNCTIONS_ONLY'}git{'GIT_CONFIG_GLOBAL'}}; if($null -eq $old[$k]){Remove-Item "Env:$name" -ErrorAction SilentlyContinue}else{Set-Item "Env:$name" $old[$k]}}
    Remove-Item Env:DOTFILES_PS_PROFILE_PATH -ErrorAction SilentlyContinue
}
