#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2218
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# 물리 경로로 풀어서 받는다. macOS의 `mktemp -d`는 `/var/folders/...`를 주는데 `/var`가
# symlink라 `managed_parent_is_safe`가 상위 경로를 거부한다 — 실제 설치 대상은 `$HOME`
# 아래라 그 walk가 boundary에서 멈추므로 제품 동작이 아니라 fixture 위치의 문제다.
# `/private/var/...`로 풀면 그 차이가 사라지고, Linux·Git Bash에서는 값이 그대로다.
TMP="$(cd -P "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
# TMPDIR도 격리한다. fnm multishell fixture가 실제 임시 디렉터리에 잔재를 남기면 안 된다.
export TMPDIR="$TMP"
mkdir -p "$HOME/.config" "$HOME/.local/bin"
export DOTFILES_FUNCTIONS_ONLY=1
export DOTFILES_RECEIPT_PATH="$TMP/state/install-receipt.json"
export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
source "$ROOT/install.sh"
unset DOTFILES_FUNCTIONS_ONLY

for user_path in "$CLAUDE_DIR" "$CODEX_DIR" "$LOCAL_BIN" "$NVIM_CONFIG_DIR" "$YAZI_CONFIG_DIR" "$STARSHIP_CONFIG" "$RECEIPT_PATH"; do
  case "$user_path" in
    "$TMP"/*) ;;
    *) echo "FAIL: installer user path escaped isolated HOME: $user_path" >&2; exit 1 ;;
  esac
done

fail() { echo "FAIL: $*" >&2; exit 1; }
receipt_init

src="$TMP/source.txt"; dst="$TMP/managed/file.txt"
mkdir -p "$(dirname "$dst")"
printf user > "$dst"; printf v1 > "$src"
install_managed_file "$src" "$dst" takeover || fail 'generic takeover'
[[ "$(cat "$dst")" == v1 && "$(cat "$dst.dotfiles-backup")" == user ]] || fail 'takeover/backup content'

printf v2 > "$src"
install_managed_file "$src" "$dst" takeover || fail 'managed update'
[[ "$(cat "$dst")" == v2 ]] || fail 'managed update content'
[[ "$(find "$(dirname "$dst")" -maxdepth 1 -name 'file.txt.dotfiles-backup*' | wc -l | tr -d ' ')" == 1 ]] || fail 'backup repeated'

identical_dst="$TMP/identical.txt"; printf v2 > "$identical_dst"
install_managed_file "$src" "$identical_dst" takeover || fail 'identical unowned file rejected'
jq -e --arg path "$identical_dst" '.artifacts | has($path) | not' "$RECEIPT_PATH" >/dev/null || fail 'identical unowned file claimed'
[[ ! -e "$identical_dst.dotfiles-backup" ]] || fail 'identical unowned file backed up'

pending_dst="$TMP/pending.txt"; printf before > "$pending_dst"
pending_hash="$(file_hash "$pending_dst")"
jq --arg path "$pending_dst" --arg hash "$pending_hash" '.artifacts[$path]={before:{exists:true,hash:$hash,backup:null},installedHash:null,pending:true}' \
  "$RECEIPT_PATH" > "$RECEIPT_PATH.pending"
mv "$RECEIPT_PATH.pending" "$RECEIPT_PATH"
receipt_init
install_managed_file "$src" "$pending_dst" takeover || fail 'pending artifact recovery'
[[ "$(cat "$pending_dst")" == v2 ]] || fail 'pending artifact content'

pending_backup_dst="$TMP/pending-backup.txt"; printf original > "$pending_backup_dst"
pending_backup_hash="$(file_hash "$pending_backup_dst")"
receipt_commit --arg path "$pending_backup_dst" --arg hash "$pending_backup_hash" --arg target "$(file_hash "$src")" \
  '.artifacts[$path]={before:{exists:true,hash:$hash,backup:($path+".dotfiles-backup")},installedHash:null,pending:true,targetHash:$target,previousHash:$hash,previousExists:true}'
receipt_init
install_managed_file "$src" "$pending_backup_dst" takeover || fail 'pending backup recovery'
[[ "$(cat "$pending_backup_dst.dotfiles-backup")" == original ]] || fail 'pending backup missed original content'

printf user-edit > "$dst"; printf v3 > "$src"
! install_managed_file "$src" "$dst" takeover || fail 'hash mismatch overwritten'
[[ "$(cat "$dst")" == user-edit ]] || fail 'hash mismatch not preserved'

collision="$TMP/collision.txt"; printf sentinel > "$collision"
! install_managed_file "$src" "$collision" skip || fail 'unowned collision overwritten'
[[ "$(cat "$collision")" == sentinel ]] || fail 'collision sentinel changed'

directory_collision="$TMP/as-directory"; mkdir "$directory_collision"
! install_managed_file "$src" "$directory_collision" skip || fail 'directory collision claimed as file'
[[ -z "$(find "$directory_collision" -mindepth 1 -print -quit)" ]] || fail 'directory collision received temp child'
jq -e --arg path "$directory_collision" '.artifacts | has($path) | not' "$RECEIPT_PATH" >/dev/null || fail 'directory collision entered receipt'

broken_collision="$TMP/broken-link"
if ln -s "$TMP/missing-target" "$broken_collision" 2>/dev/null; then
  ! install_managed_file "$src" "$broken_collision" skip || fail 'broken symlink collision claimed'
  [[ -L "$broken_collision" && "$(readlink "$broken_collision")" == "$TMP/missing-target" ]] || fail 'broken symlink changed'
fi

mkdir -p "$TMP/tree-src" "$TMP/tree-dst"
printf managed > "$TMP/tree-src/managed.txt"; printf extra > "$TMP/tree-dst/extra.txt"
install_managed_tree "$TMP/tree-src" "$TMP/tree-dst" takeover
[[ "$(cat "$TMP/tree-dst/extra.txt")" == extra ]] || fail 'destination extra removed'
tree_root_file="$TMP/tree-root-file"; printf sentinel > "$tree_root_file"
! install_managed_tree "$TMP/tree-src" "$tree_root_file" takeover || fail 'regular file accepted as tree root'
[[ "$(cat "$tree_root_file")" == sentinel ]] || fail 'tree root file changed'

mkdir -p "$TMP/link-tree-src/nested" "$TMP/link-tree-dst" "$TMP/link-tree-outside"
printf managed > "$TMP/link-tree-src/nested/managed.txt"; printf sentinel > "$TMP/link-tree-outside/managed.txt"
if ln -s "$TMP/link-tree-outside" "$TMP/link-tree-dst/nested" 2>/dev/null && [[ -L "$TMP/link-tree-dst/nested" ]]; then
  ! install_managed_tree "$TMP/link-tree-src" "$TMP/link-tree-dst" takeover || fail 'intermediate tree symlink followed'
  [[ "$(cat "$TMP/link-tree-outside/managed.txt")" == sentinel ]] || fail 'intermediate tree symlink overwrote external file'
  jq -e --arg path "$TMP/link-tree-dst/nested/managed.txt" '.artifacts | has($path) | not' "$RECEIPT_PATH" >/dev/null || fail 'intermediate tree symlink entered receipt'
fi

mkdir -p "$TMP/skill-src" "$TMP/skill-dst"
printf managed > "$TMP/skill-src/SKILL.md"; printf sentinel > "$TMP/skill-dst/user.txt"
! install_managed_tree "$TMP/skill-src" "$TMP/skill-dst" skip true || fail 'unowned skill adopted'
[[ ! -e "$TMP/skill-dst/SKILL.md" ]] || fail 'skill collision deployed file'

record_managed_package test:same true 1 1
record_managed_package test:fresh false '' 2
record_managed_package test:upgrade true 1 2
record_managed_package test:upgrade true ignored 3
begin_managed_package test:crash-package false ''
receipt_init
begin_managed_package test:crash-package true 1
cancel_managed_package test:crash-package

# fnm은 셸마다 새 multishell 링크를 만든다. prefix를 링크째로 기록하면 매 실행 소유권 판정이 깨진다.
stable_prefix="$HOME/.local/share/fnm/node-versions/v1.0.0/installation"
ephemeral_prefix="${TMPDIR:-/tmp}/fnm_multishells/1234_5678"
is_ephemeral_npm_prefix "$ephemeral_prefix" || fail 'multishell prefix not detected as ephemeral'
! is_ephemeral_npm_prefix "$stable_prefix" || fail 'stable prefix flagged as ephemeral'
mkdir -p "$stable_prefix" "$(dirname "$ephemeral_prefix")"
# Git Bash는 기본적으로 symlink 대신 디렉터리를 복사하므로 링크가 실제로 생겼을 때만 검증한다.
ln -sfn "$stable_prefix" "$ephemeral_prefix" 2>/dev/null || true
if [[ -L "$ephemeral_prefix" ]]; then
    [[ "$(resolve_link_path "$ephemeral_prefix")" == "$(cd -P "$stable_prefix" && pwd -P)" ]] || fail 'ephemeral prefix link not resolved'
fi

begin_managed_package npm:test-prefix false '' "$stable_prefix" || fail 'npm prefix journal'
record_managed_package npm:test-prefix false '' 1 "$stable_prefix"
begin_managed_package npm:test-prefix true 1 "$stable_prefix" || fail 'matching npm prefix rejected'
cancel_managed_package npm:test-prefix
! begin_managed_package npm:test-prefix true 1 "$HOME/other/prefix" || fail 'changed npm prefix adopted'
! begin_managed_package npm:test-prefix true 1 "$ephemeral_prefix" || fail 'ephemeral npm prefix recorded'
[[ "$(jq -r '.packages["npm:test-prefix"].prefix' "$RECEIPT_PATH")" == "$stable_prefix" ]] || fail 'rejected npm prefix overwrote receipt'

# 이전 버그가 남긴 multishell prefix는 안정 경로로 교정되어야 한다.
receipt_commit --arg prefix "$ephemeral_prefix" '.packages["npm:test-prefix"].prefix=$prefix'
begin_managed_package npm:test-prefix true 1 "$stable_prefix" || fail 'ephemeral npm prefix not repaired'
[[ "$(jq -r '.packages["npm:test-prefix"].prefix' "$RECEIPT_PATH")" == "$stable_prefix" ]] || fail 'repaired npm prefix not persisted'
# 낡은 prefix에서 잰 before는 새 위치에 대해 무의미하므로 지금 측정값으로 다시 잡혀야 한다.
[[ "$(jq -r '.packages["npm:test-prefix"].before.present' "$RECEIPT_PATH")" == true ]] || fail 'repaired before.present not rebased'
[[ "$(jq -r '.packages["npm:test-prefix"].before.value' "$RECEIPT_PATH")" == 1 ]] || fail 'repaired before.value not rebased'
cancel_managed_package npm:test-prefix

# 빈 입력은 실패가 아니라 빈 값이어야 한다. `set -e` 아래에서 설치가 통째로 중단되기 때문이다.
[[ -z "$(resolve_link_path "")" ]] || fail 'empty resolve_link_path returned a value'
resolve_link_path "" >/dev/null || fail 'empty resolve_link_path returned failure'

# 설치 후 외부 CLI가 관리 파일을 다시 써도 소유권을 잃지 않아야 한다.
sync_dst="$TMP/sync-target.txt"
install_managed_file "$src" "$sync_dst" takeover || fail 'sync fixture install'
! sync_managed_file_hash "$sync_dst" || fail 'unchanged managed file restamped'
printf rewritten-by-external-tool > "$sync_dst"
sync_managed_file_hash "$sync_dst" || fail 'externally rewritten managed file not restamped'
[[ "$(jq -r --arg p "$sync_dst" '.artifacts[$p].installedHash' "$RECEIPT_PATH")" == "$(file_hash "$sync_dst")" ]] || fail 'restamped hash mismatch'
install_managed_file "$src" "$sync_dst" takeover || fail 'restamped file preserved on next install'
[[ "$(cat "$sync_dst")" == "$(cat "$src")" ]] || fail 'restamped file not updated'
! sync_managed_file_hash "$TMP/never-managed.txt" || fail 'unmanaged path restamped'

record_managed_value 'env:PATH:/tools' false '' present false
record_managed_value env:SECRET_TOKEN true do-not-store new-secret
git config --global test.receipt before
set_managed_git_value test.receipt after
set_managed_git_value credential.credentialStore dpapi
[[ "$(git config --global --get credential.credentialStore)" == dpapi ]] || fail 'safe credentialStore setting blocked'

git config --global test.save-failure before
original_receipt_commit="$(declare -f receipt_commit)"
receipt_commit() { return 73; }
! set_managed_git_value test.save-failure after || fail 'Git mutation proceeded after receipt save failure'
[[ "$(git config --global --get test.save-failure)" == before ]] || fail 'Git changed after receipt save failure'
failed_dst="$TMP/failed-receipt-file"; printf user > "$failed_dst"
! install_managed_file "$src" "$failed_dst" takeover || fail 'artifact mutation proceeded after receipt save failure'
[[ "$(cat "$failed_dst")" == user ]] || fail 'artifact changed after receipt save failure'
[[ ! -e "$failed_dst.dotfiles-backup" ]] || fail 'backup created before receipt journal'
eval "$original_receipt_commit"

crash_src="$TMP/crash-source.txt"; crash_dst="$TMP/crash-destination.txt"
printf v1 > "$crash_src"
install_managed_file "$crash_src" "$crash_dst" takeover || fail 'crash fixture initial install'
printf v2 > "$crash_src"
original_receipt_commit="$(declare -f receipt_commit)"
eval "$(declare -f receipt_commit | sed '1s/receipt_commit/receipt_commit_real/')"
receipt_commit_calls=0
receipt_commit() {
  receipt_commit_calls=$((receipt_commit_calls + 1))
  (( receipt_commit_calls != 2 )) || return 73
  receipt_commit_real "$@"
}
! install_managed_file "$crash_src" "$crash_dst" takeover || fail 'post-mutation receipt failure did not propagate'
[[ "$receipt_commit_calls" == 2 && "$(cat "$crash_dst")" == v2 ]] || fail 'managed update was not journaled before mutation'
eval "$original_receipt_commit"; unset -f receipt_commit_real
receipt_init
install_managed_file "$crash_src" "$crash_dst" takeover || fail 'post-mutation pending receipt recovery'
jq -e --arg path "$crash_dst" '.artifacts[$path].pending == false and (.artifacts[$path] | has("targetHash") | not)' "$RECEIPT_PATH" >/dev/null || fail 'post-mutation pending receipt not finalized'

git config --global test.pending before
begin_managed_value git:test.pending true before after
git config --global test.pending after
receipt_init
set_managed_git_value test.pending after
jq -e '.values["git:test.pending"] | has("pending") | not' "$RECEIPT_PATH" >/dev/null || fail 'pending value not reconciled'

jq -e '
  (.schemaVersion == 1) and
  (.packages | has("test:same") | not) and
  (.packages["test:fresh"].before.present == false) and
  (.packages["test:upgrade"].before.value == "1") and
  (.packages["test:upgrade"].installed == "3") and
  (.packages["test:crash-package"].before.present == false) and
  (.packages["test:crash-package"].installed == "1") and
  (.packages["test:crash-package"] | has("pending") | not) and
  (.values["env:PATH:/tools"].before == {"present":false}) and
  (.values | has("env:SECRET_TOKEN") | not) and
  (.values["git:test.receipt"].before.value == "before") and
  (.values["git:test.receipt"].installed == "after") and
  (.values["git:credential.credentialStore"].before.present == false) and
  (.values["git:credential.credentialStore"].installed == "dpapi")
' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail 'package/value receipt contract'

invalid="$TMP/invalid.json"; printf '{partial' > "$invalid"
RECEIPT_PATH="$invalid"; RECEIPT_READY=false
invalid_dst="$TMP/invalid-dst.txt"; printf keep > "$invalid_dst"
! receipt_preflight || fail 'invalid receipt accepted by preflight'
! install_managed_file "$src" "$invalid_dst" takeover || fail 'invalid receipt allowed write'
[[ "$(cat "$invalid")" == '{partial' && "$(cat "$invalid_dst")" == keep ]] || fail 'invalid receipt/destination changed'

partial="$TMP/partial.json"; printf '%s' '{"schemaVersion":1,"artifacts":{},"packages":{}}' > "$partial"
RECEIPT_PATH="$partial"; RECEIPT_READY=false
! receipt_preflight || fail 'partial receipt accepted by preflight'
[[ "$(cat "$partial")" == '{"schemaVersion":1,"artifacts":{},"packages":{}}' ]] || fail 'partial receipt changed'

receipt_directory="$TMP/receipt-as-directory"; mkdir "$receipt_directory"
RECEIPT_PATH="$receipt_directory"; RECEIPT_READY=false
! receipt_preflight || fail 'receipt directory path accepted'
[[ -z "$(find "$receipt_directory" -mindepth 1 -print -quit)" ]] || fail 'receipt directory received temp child'

receipt_target="$TMP/receipt-target.json"; receipt_link="$TMP/receipt-link.json"
cp "$DOTFILES_RECEIPT_PATH" "$receipt_target"
if ln -s "$receipt_target" "$receipt_link" 2>/dev/null && [[ -L "$receipt_link" ]]; then
  target_hash="$(file_hash "$receipt_target")"
  RECEIPT_PATH="$receipt_link"; RECEIPT_READY=false
  ! receipt_preflight || fail 'receipt symlink path accepted'
  [[ -L "$receipt_link" && "$(file_hash "$receipt_target")" == "$target_hash" ]] || fail 'receipt symlink or target changed'
fi

bootstrap_receipt="$TMP/bootstrap/install-receipt.json"
RECEIPT_PATH="$bootstrap_receipt"; RECEIPT_READY=false
receipt_bootstrap_jq apt || fail 'jq bootstrap receipt creation'
receipt_is_jq_bootstrap || fail 'jq bootstrap receipt identity'
jq empty "$bootstrap_receipt" || fail 'jq bootstrap receipt invalid JSON'
receipt_init || fail 'jq bootstrap receipt validation'
record_managed_package apt:jq false '' 1.0
jq -e '.packages["apt:jq"].before.present == false and .packages["apt:jq"].installed == "1.0" and (has("bootstrap")|not)' "$bootstrap_receipt" >/dev/null || fail 'jq bootstrap provenance finalize'

preexisting_bootstrap="$TMP/bootstrap-preexisting/install-receipt.json"
RECEIPT_PATH="$preexisting_bootstrap"; RECEIPT_READY=false
! receipt_bootstrap_jq apt true || fail 'pre-existing jq package was claimed as fresh bootstrap'
[[ ! -e "$preexisting_bootstrap" ]] || fail 'pre-existing jq bootstrap receipt was created'

RECEIPT_PATH="$DOTFILES_RECEIPT_PATH"; receipt_init
git config --global test.receipt user-edit
set_managed_git_value test.receipt should-not-win
[[ "$(git config --global --get test.receipt)" == user-edit ]] || fail 'modified managed Git value overwritten'
if [[ "$(uname -s)" == Linux || "$(uname -s)" == Darwin ]]; then
  [[ "$(stat -c '%a' "$dst.dotfiles-backup" 2>/dev/null || stat -f '%Lp' "$dst.dotfiles-backup")" == "$(jq -r --arg path "$dst" '.artifacts[$path].before.mode' "$RECEIPT_PATH")" ]] || fail 'backup mode did not preserve original'
fi
[[ -z "$(find "$(dirname "$RECEIPT_PATH")" -maxdepth 1 -name '.install-receipt.*' -print -quit)" ]] || fail 'receipt temp file leaked'

fnm_root="$TMP/fnm"; settings="$CLAUDE_DIR/settings.json"
FNM_DIR="$fnm_root"
mkdir -p "$fnm_root/node-versions/v22.0.0/installation/bin" "$fnm_root/node-versions/v23.0.0/installation/bin" "$(dirname "$settings")"
printf '#!/usr/bin/env bash\n' > "$fnm_root/node-versions/v22.0.0/installation/bin/node"
printf '#!/usr/bin/env bash\n' > "$fnm_root/node-versions/v23.0.0/installation/bin/node"
chmod +x "$fnm_root"/node-versions/*/installation/bin/node
printf '{"statusLine":{"command":"%s/node-versions/v21.0.0/installation/node hud"}}\n' "$fnm_root" > "$settings"
update_fnm_statusline v22.0.0
[[ "$(cat "$settings.dotfiles-backup")" == *v21.0.0* ]] || fail 'fnm first backup missed original settings'
sed 's/hud/user-hud/' "$settings" > "$settings.user"; mv "$settings.user" "$settings"
user_settings="$(cat "$settings")"
update_fnm_statusline v23.0.0
[[ "$(cat "$settings")" == "$user_settings" ]] || fail 'fnm overwrote user-modified settings'

! grep -Fq 'chmod +x "$HOOKS_DST"/*.sh' "$ROOT/install.sh" || fail 'Claude hook wildcard chmod returned'
grep -Fq 'chmod +x "$managed_hook"' "$ROOT/install.sh" || fail 'managed Claude hook identity missing'

echo 'Unix install receipt: PASS'
