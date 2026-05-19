# Troubleshooting

## SSH 터미널을 powershell 7+ / Git Bash로 설정

관리자 권한으로 powershell 실행 후 다음 명령어를 실행:

```powershell
# Powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\PowerShell\7\pwsh.exe" -PropertyType String -Force
# Git Bash
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell -Value "C:\Program Files\Git\bin\bash.exe" -PropertyType String -Force
```

## SSH 세션에서 WinGet CLI 도구 오류 (`Permission denied` / `Function not implemented`)

WinGet으로 설치한 CLI 도구는 모두 `%LOCALAPPDATA%\Microsoft\WinGet\Links\`의 reparse symlink로 노출된다. Windows OpenSSH는 NETWORK logon 토큰으로 셸을 띄우는데, 이 토큰에서 해당 symlink 평가가 거부되어 호출 경로에 따라 두 가지 증상이 나타난다.

- **사용자가 직접 호출** → `bash: .../fnm: Permission denied` (EACCES)
- **다른 프로세스가 자동 spawn** → `error: cannot spawn delta: Function not implemented` / `fatal: unable to execute pager 'delta'` (ENOSYS). `git diff`가 `core.pager = delta`를 spawn하다 죽는 게 대표 사례.

셸별 우회:

- **PowerShell 7+**: 프로파일 로딩 시 `ResourceUnavailable`. `profile.ps1`의 `Resolve-ExePath` 헬퍼가 심볼릭 링크를 실제 실행 파일 경로로 해석해 우회.
- **Git Bash**: `config/bash/bashrc`가 `$HOME/AppData/Local/Microsoft/WinGet/Packages/<pkg>_Microsoft.Winget.Source_*` 하위의 실제 바이너리 경로를 PATH 앞에 prepend해 symlink 평가 자체를 회피. 두 그룹으로 나눠 처리한다.
  - 그룹 A (exe가 패키지 디렉토리 직속): `Schniz.fnm`, `ajeetdsouza.zoxide`, `junegunn.fzf`, `eza-community.eza`, `jqlang.jq`, `MikeFarah.yq`, `JesseDuffield.lazygit`
  - 그룹 B (exe가 버전/아키텍처 서브 디렉토리 안): `sharkdp.bat/bat-v*`, `sharkdp.fd/fd-v*`, `BurntSushi.ripgrep.MSVC/ripgrep-*`, `dandavison.delta/delta-*`, `Oven-sh.Bun/bun-windows-x64`, `sxyazi.yazi/yazi-x86_64-pc-windows-msvc`

> **새 WinGet 도구를 추가할 때**: `manifests/winget.txt`뿐 아니라 `config/bash/bashrc`의 두 그룹 중 적절한 쪽에도 등록해야 SSH 세션에서 깨지지 않는다. 디렉토리 케이스는 매니페스트가 아니라 실제 폴더명을 따른다 (bash glob은 case-sensitive). 예: `MikeFarah.yq`(대문자 M·F), `Oven-sh.Bun`(하이픈).

별도 조치 불필요. 진단 단서: `whoami /groups`에 `NT AUTHORITY\NETWORK`가 포함되고 `INTERACTIVE`가 빠져 있으면 이 케이스다.

## SSH 비대화형 세션에서 scp/rsync/git 깨짐

`ssh host 'cmd'`, scp, rsync, git over ssh 등 비대화형 세션도 `~/.bashrc`를 source한다. starship/fzf의 `eval` 초기화가 stderr를 출력하면 파일 전송 프로토콜이 깨지거나 git이 비정상 종료된다.

`config/bash/bashrc` 상단의 `case $- in *i*) ;; *) return ;; esac` 가드가 비대화형 셸을 즉시 return시켜 prompt/eval/alias 초기화를 모두 건너뛴다. PATH 설정(`~/.local/bin`, WinGet 우회)은 가드 위에 있어 비대화형에서도 적용된다.

## SSH 세션에서 Starship이 Administrator 표시

Windows OpenSSH 서버는 Administrators 그룹 계정으로 접속 시 UAC 필터를 거치지 않고 **전체 관리자 토큰**으로 셸을 실행한다. 일반 데스크탑 로그인은 제한된 토큰으로 시작하는 것과 달리, SSH 세션은 처음부터 관리자 컨텍스트로 동작한다. Starship의 `username` 모듈이 SSH 세션에서 이를 반영해 표시하는 것이다.

표시를 끄려면 `config/starship.toml`에 추가:

```toml
[username]
show_always = false
```

## Windows OpenSSH 서버에 공개키 등록 (authorized_keys)

Windows OpenSSH는 계정 유형에 따라 authorized_keys 파일 위치가 다르다.

| 계정 유형 | authorized_keys 경로 |
|-----------|----------------------|
| 일반 사용자 | `C:\Users\<username>\.ssh\authorized_keys` |
| Administrators 그룹 | `C:\ProgramData\ssh\administrators_authorized_keys` |

**관리자 계정 공개키 등록** (관리자 권한 PowerShell):

```powershell
# administrators_authorized_keys에 공개키 추가
$pubkey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
Add-Content "C:\ProgramData\ssh\administrators_authorized_keys" $pubkey

# 권한 설정: SYSTEM과 Administrators 그룹만 접근 허용
icacls "C:\ProgramData\ssh\administrators_authorized_keys" /inheritance:r /grant "SYSTEM:(F)" /grant "BUILTIN\Administrators:(F)"

Restart-Service sshd
```

**일반 사용자 공개키 등록** (관리자 권한 PowerShell):

기본 `sshd_config`에는 Administrators 그룹 멤버에게 `administrators_authorized_keys`를 강제하는 블록이 있어 사용자별 경로가 무시된다. 해당 블록을 주석 처리해야 한다.

```powershell
# sshd_config에서 Match Group administrators 블록 주석 처리
$sshd_config = "C:\ProgramData\ssh\sshd_config"
(Get-Content $sshd_config) `
    -replace '^(Match Group administrators)', '#$1' `
    -replace '^(\s+AuthorizedKeysFile __PROGRAMDATA__.*)', '#$1' |
    Set-Content $sshd_config

# authorized_keys 파일 생성 및 공개키 추가
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
$pubkey = Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
Add-Content "$env:USERPROFILE\.ssh\authorized_keys" $pubkey

# 권한 설정
icacls "$env:USERPROFILE\.ssh" /inheritance:r /grant "$env:USERNAME:(OI)(CI)F"
icacls "$env:USERPROFILE\.ssh\authorized_keys" /inheritance:r /grant "$env:USERNAME:(F)"

Restart-Service sshd
```

진단 단서: `Get-Content C:\ProgramData\ssh\sshd_config | Select-String "Match Group"` 으로 블록 활성화 여부 확인.

## SSH 세션에서 GitHub HTTPS 인증 실패

SSH로 접속한 비대화형 세션에서 `git fetch`/`git push` 시 다음 오류가 발생한다.

```
fatal: Unable to persist credentials with the 'wincredman' credential store.
remote: Invalid username or token. Password authentication is not supported for Git operations.
fatal: Authentication failed for 'https://github.com/...'
```

fatal이 안 떠도 username/password 프롬프트가 떠서 통과 못 하는 경우도 같은 원인이다.

**원인**:

- Git for Windows의 system gitconfig가 `credential.helper = manager`(GCM)를 박아놓고, GCM의 기본 store는 `wincredman`(Windows Credential Manager)이다. 이 store는 **대화형 데스크톱 세션**이 있어야 동작해, SSH 비대화형 세션에서는 fatal로 helper chain이 끊긴다.
- `gh auth setup-git`이 추가하는 URL-specific gh helper도 chain이 끊겨 호출 안 되고, 호출되더라도 `gh`의 keyring 자체가 `wincredman` 기반이라 SSH 세션에서 토큰을 못 읽는다.

**해결**: GitHub는 **SSH 키 인증**으로 전환. GitHub 외 HTTPS 호스트(GitLab 등)는 GCM `credentialStore`를 `dpapi`로 변경해 `wincredman` 의존성을 제거한다.

```bash
# 1. GitHub용 SSH 키 생성 + 등록 (gh 토큰에 admin:public_key scope 필요)
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519_$(hostname) -N ""
gh ssh-key add ~/.ssh/id_ed25519_$(hostname).pub --title "$(hostname)"

# 2. ~/.ssh/config에 GitHub 항목 추가
cat >> ~/.ssh/config <<EOF

Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519_$(hostname)
    IdentitiesOnly yes
EOF

# 3. 기존 HTTPS remote를 SSH로 전환
git remote set-url origin git@github.com:<user>/<repo>.git

# 4. 검증
ssh -T git@github.com   # → "Hi <user>! You've successfully authenticated..."
git fetch
```

GitHub 외 호스트용 `dpapi` 설정은 `config/git/gitconfig`에 반영되어 있다. DPAPI는 사용자 프로필 기반이라 SSH 비대화형 세션에서도 동작한다.
