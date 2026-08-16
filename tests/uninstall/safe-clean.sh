#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"; command -v cygpath >/dev/null 2>&1 && TMP="$(cygpath -m "$TMP")"; trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" FNM_DIR="$TMP/home/.local/share/fnm" DOTFILES_RECEIPT_PATH="$TMP/home/.state/receipt.json" DOTFILES_FUNCTIONS_ONLY=1
mkdir -p "$HOME" "$(dirname "$DOTFILES_RECEIPT_PATH")"
source "$ROOT/uninstall.sh"
fail() { echo "FAIL: $*" >&2; exit 1; }

# Actual installer receipt allowlist를 stub 없이 검증한다.
while IFS= read -r key; do value_key_allowed "git:$key" || fail "git-value-allowlist:$key"; done < <(
  awk '/^[[:space:]]*\[/ { section=$0; sub(/^[[:space:]]*\[/,"",section); sub(/\].*$/,"",section); next }
       /^[[:space:]]*[^#[:space:]][^=]*=/ { key=$0; sub(/^[[:space:]]*/,"",key); sub(/[[:space:]]*=.*/,"",key); print section "." key }' "$ROOT/config/git/gitconfig"
)
value_key_allowed git:core.autocrlf || fail git-autocrlf-allowlist
value_key_allowed git:core.fileMode || fail git-filemode-allowlist
! value_key_allowed git:user.name || fail unmanaged-git-value-allowed
artifact_allowed "$HOME/.local/share/fnm/fnm" || fail fnm-anchor-allowlist
artifact_allowed "$HOME/.bun/bin/bun" || fail bun-anchor-allowlist
artifact_allowed "$HOME/.bun/bin/bunx" || fail bunx-anchor-allowlist
! artifact_allowed "$HOME/.local/bin/nested/node" || fail nested-bin-rejected
artifact_allowed "$HOME/.codex/agents/planner.toml" || fail codex-agent-allowlist
! artifact_allowed "$HOME/.codex/agents/nested/planner.toml" || fail nested-agent-rejected
! artifact_allowed "$HOME/.codex/agents/planner.md" || fail agent-extension-rejected
# 구 로컬 skill 배포분: 소스가 사라져도 기존 머신 receipt entry를 정리할 수 있어야 한다.
# 이 판정이 막히면 preflight가 uninstall 전체를 중단시킨다.
artifact_allowed "$HOME/.claude/skills/subagent-creator/SKILL.md" || fail legacy-claude-skill-allowlist
artifact_allowed "$HOME/.claude/skills/repo-scaffold/assets/scaffold.sh" || fail legacy-claude-skill-nested-allowlist
artifact_allowed "$HOME/.gemini/config/skills/subagent-creator/SKILL.md" || fail legacy-gemini-skill-allowlist
# npx가 설치한 다른 skill은 receipt에 없다 — 이름 목록 밖은 여전히 거부한다.
! artifact_allowed "$HOME/.claude/skills/pdf/SKILL.md" || fail npx-skill-rejected
! artifact_allowed "$HOME/.claude/skills/subagent-creator" || fail legacy-skill-root-rejected
package_key_allowed 'brew:oven-sh/bun/bun' || fail brew-tap-allowlist
package_key_allowed 'cask:claude-code' || fail cask-allowlist
! package_key_allowed 'cask:codexbar' || fail unmanaged-cask-rejected
npm_prefix_allowed "$HOME/.local/share/fnm/node-versions/v22/installation" || fail npm-prefix-allowlist
! npm_prefix_allowed "$HOME/project/node-versions/v22/installation" || fail npm-project-prefix-rejected
( FNM_DIR="" OS="Darwin" npm_prefix_allowed "$HOME/Library/Application Support/fnm/node-versions/v22/installation" ) || fail npm-macos-prefix-allowlist
RECEIPT_PATH="$DOTFILES_RECEIPT_PATH"; jq -n '{packages:{"brew:oven-sh/bun/bun":{before:{present:false},installed:"1"}},artifacts:{},values:{},schemaVersion:1}' > "$RECEIPT_PATH"
brew(){ [[ "$1" == list && "$3" == 'oven-sh/bun/bun' ]] && printf 'bun 1.2.3\n'; }
query_package 'brew:oven-sh/bun/bun'; [[ "$PACKAGE_STATE:$PACKAGE_VERSION" == present:1.2.3 ]] || fail brew-short-name-query
unset -f brew

# Marker: exact block만 제거하고 duplicate/inline은 보존한다.
printf 'user\n# ===== dotfiles-begin =====\nmanaged\n# ===== dotfiles-end =====\nafter\n' > "$HOME/.bashrc"
remove_marker_block "$HOME/.bashrc"; grep -Fxq user "$HOME/.bashrc"; ! grep -q dotfiles-begin "$HOME/.bashrc" || fail marker-not-removed
printf '# ===== dotfiles-begin =====\nx\n# ===== dotfiles-begin =====\nx\n# ===== dotfiles-end =====\n' > "$HOME/.inputrc"
before="$(file_hash "$HOME/.inputrc")"; ! remove_marker_block "$HOME/.inputrc" || fail marker-duplicate-accepted; [[ "$(file_hash "$HOME/.inputrc")" == "$before" ]] || fail marker-duplicate
printf 'inline # ===== dotfiles-begin =====\n# ===== dotfiles-end =====\n' > "$HOME/.zshrc"
before="$(file_hash "$HOME/.zshrc")"; ! remove_marker_block "$HOME/.zshrc" || fail marker-inline-accepted; [[ "$(file_hash "$HOME/.zshrc")" == "$before" ]] || fail marker-inline

mkdir -p "$HOME/.config/yazi" "$HOME/.codex" "$HOME/.claude" "$HOME/.local/bin" "$HOME/.local/opt/nvim-v1.2.3" "$HOME/.local/opt/nvim-v2.0.0" "$HOME/.local/share/fnm/node-versions/v22/installation"
printf managed > "$HOME/.tmux.conf"; fresh_hash="$(file_hash "$HOME/.tmux.conf")"; chmod 640 "$HOME/.tmux.conf"; fresh_mode="$(file_mode "$HOME/.tmux.conf")"
printf managed > "$HOME/.config/starship.toml"; restore_hash="$(file_hash "$HOME/.config/starship.toml")"; restore_mode="$(file_mode "$HOME/.config/starship.toml")"; printf original > "$HOME/.config/starship.toml.dotfiles-backup"; backup_hash="$(file_hash "$HOME/.config/starship.toml.dotfiles-backup")"; chmod 600 "$HOME/.config/starship.toml.dotfiles-backup"; backup_mode="$(file_mode "$HOME/.config/starship.toml.dotfiles-backup")"
printf changed > "$HOME/.config/yazi/yazi.toml"
printf target > "$HOME/.codex/AGENTS.md"; target_hash="$(file_hash "$HOME/.codex/AGENTS.md")"; chmod 644 "$HOME/.codex/AGENTS.md"
printf before > "$HOME/.claude/CLAUDE.md"; previous_hash="$(file_hash "$HOME/.claude/CLAUDE.md")"
printf other > "$HOME/.claude/settings.json"
printf unsafe > "$HOME/unsafe.txt"; unsafe_hash="$(file_hash "$HOME/unsafe.txt")"
printf tree > "$HOME/.local/opt/nvim-v1.2.3/nvim"; tree_hash_ok="$(tree_hash "$HOME/.local/opt/nvim-v1.2.3")"
printf tree > "$HOME/.local/opt/nvim-v2.0.0/nvim"; tree_hash_extra="$(tree_hash "$HOME/.local/opt/nvim-v2.0.0")"; printf user > "$HOME/.local/opt/nvim-v2.0.0/user"
ln -s /managed/node "$HOME/.local/bin/node" 2>/dev/null || true

export GIT_CONFIG_GLOBAL="$TMP/gitconfig"
git config --global core.editor installed

jq -n \
  --arg fresh "$HOME/.tmux.conf" --arg fh "$fresh_hash" --arg fm "$fresh_mode" \
  --arg restore "$HOME/.config/starship.toml" --arg rh "$restore_hash" --arg rm "$restore_mode" --arg backup "$HOME/.config/starship.toml.dotfiles-backup" --arg bh "$backup_hash" --arg bm "$backup_mode" \
  --arg modified "$HOME/.config/yazi/yazi.toml" --arg unsafe "$HOME/unsafe.txt" --arg uh "$unsafe_hash" \
  --arg target "$HOME/.codex/AGENTS.md" --arg th "$target_hash" --arg previous "$HOME/.claude/CLAUDE.md" --arg ph "$previous_hash" --arg other "$HOME/.claude/settings.json" \
  --arg tree "$HOME/.local/opt/nvim-v1.2.3" --arg trh "$tree_hash_ok" --arg extra "$HOME/.local/opt/nvim-v2.0.0" --arg exh "$tree_hash_extra" --arg link "$HOME/.local/bin/node" --arg npmPrefix "$HOME/.local/share/fnm/node-versions/v22/installation" '
  {schemaVersion:1,artifacts:{},packages:{},values:{
    "git:core.editor":{before:{present:true,value:"user"},installed:"installed"}
  }} |
  .artifacts[$fresh]={before:{exists:false,hash:null,mode:null,backup:null},installedHash:$fh,installedMode:$fm,pending:false} |
  .artifacts[$restore]={before:{exists:true,hash:$bh,mode:$bm,backup:$backup},installedHash:$rh,installedMode:$rm,pending:false} |
  .artifacts[$modified]={before:{exists:false},installedHash:"not-current",installedMode:"644",pending:false} |
  .artifacts[$target]={before:{exists:false},installedHash:null,pending:true,targetHash:$th,targetMode:"644",previousExists:false} |
  .artifacts[$previous]={before:{exists:true,hash:$ph,mode:"644",backup:($previous+".dotfiles-backup")},installedHash:null,pending:true,targetHash:"different",targetMode:"644",previousExists:true,previousHash:$ph,previousMode:"644"} |
  .artifacts[$other]={before:{exists:false},installedHash:null,installedMode:"644",pending:true,targetHash:"different",targetMode:"644",previousExists:false} |
  .artifacts[$tree]={before:{exists:false,type:"missing"},installedTreeHash:$trh,pending:false} |
  .artifacts[$extra]={before:{exists:false,type:"missing"},installedTreeHash:$exh,pending:false} |
  .artifacts[$link]={before:{exists:false,type:"missing",target:null},installedTarget:"/managed/node",pending:false} |
  .packages={
    "npm:@openai/codex":{before:{present:false,value:null},installed:"2",prefix:$npmPrefix},
    "apt:git":{before:{present:true,value:"1"},installed:"2"},
    "apt:curl":{before:{present:false,value:null},installed:"1"},
    "apt:wget":{before:{present:false,value:null},installed:null,pending:{previousPresent:false,previousValue:null,newEntry:true}},
    "apt:vim":{before:{present:false,value:null},installed:null,pending:{previousPresent:false,previousValue:null,newEntry:true}},
    "apt:tmux":{before:{present:true,value:"1"},installed:"2",pending:{previousPresent:true,previousValue:"2",newEntry:false}}
  }' > "$DOTFILES_RECEIPT_PATH"
[[ -f "$DOTFILES_RECEIPT_PATH" ]] || fail receipt-fixture
[[ " ${_TMPFILES[*]} " != *" $DOTFILES_RECEIPT_PATH "* ]] || fail receipt-temp-collision

REMOVED_PACKAGES=''
query_package() {
  case " $REMOVED_PACKAGES " in *" $1 "*) PACKAGE_STATE=absent; PACKAGE_VERSION=''; return;; esac
  case "$1" in npm:@openai/codex) PACKAGE_STATE=present;PACKAGE_VERSION=2;; apt:git) PACKAGE_STATE=present;PACKAGE_VERSION=2;; apt:curl) PACKAGE_STATE=present;PACKAGE_VERSION=9;; apt:wget) PACKAGE_STATE=present;PACKAGE_VERSION=3;; apt:vim) PACKAGE_STATE=absent;PACKAGE_VERSION='';; apt:tmux) PACKAGE_STATE=present;PACKAGE_VERSION=9;; *) return 1;; esac
}
remove_package() { REMOVED_PACKAGES="$REMOVED_PACKAGES $1"; }

main || { [[ -f "$DOTFILES_RECEIPT_PATH" ]] && jq . "$DOTFILES_RECEIPT_PATH" >/dev/null; }
[[ ! -e "$HOME/.tmux.conf" ]] || fail fresh-delete
[[ "$(cat "$HOME/.config/starship.toml")" == original ]] || fail backup-restore
[[ "$(cat "$HOME/.config/yazi/yazi.toml")" == changed ]] || fail modified-preserve
[[ "$(cat "$HOME/unsafe.txt")" == unsafe ]] || fail unsafe-preserve
[[ ! -e "$HOME/.local/opt/nvim-v1.2.3" ]] || fail tree-delete
[[ -f "$HOME/.local/opt/nvim-v2.0.0/user" ]] || fail tree-extra-preserve
[[ ! -e "$HOME/.local/bin/node" && ! -L "$HOME/.local/bin/node" ]] || fail symlink-delete
[[ ! -e "$HOME/.codex/AGENTS.md" ]] || fail pending-target
[[ "$(cat "$HOME/.claude/CLAUDE.md")" == before ]] || fail pending-previous
[[ "$(cat "$HOME/.claude/settings.json")" == other ]] || fail pending-other
[[ "$(git config --global core.editor)" == user ]] || fail git-restore
jq -e '.packages|has("npm:@openai/codex")|not' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail package-fresh
jq -e '.packages|has("apt:git")|not' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail package-preexisting
jq -e '.packages|has("apt:vim")|not' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail package-pending-previous
jq -e '.packages|has("apt:curl") and has("apt:wget") and has("apt:tmux")' "$DOTFILES_RECEIPT_PATH" >/dev/null || fail package-preserve
receipt_before="$(file_hash "$DOTFILES_RECEIPT_PATH")"; main || true; [[ "$(file_hash "$DOTFILES_RECEIPT_PATH")" == "$receipt_before" ]] || fail rerun

# receipt absent는 marker만, invalid/symlink receipt는 artifact를 건드리지 않는다.
rm -f "$DOTFILES_RECEIPT_PATH" "$HOME/.inputrc" "$HOME/.zshrc"; printf '# ===== dotfiles-begin =====\nx\n# ===== dotfiles-end =====\n' > "$HOME/.bashrc"; main; ! grep -q dotfiles-begin "$HOME/.bashrc" || fail receipt-absent-marker
printf invalid > "$DOTFILES_RECEIPT_PATH"; printf keep > "$HOME/.tmux.conf"; ! main || fail invalid-receipt-exit; [[ "$(cat "$HOME/.tmux.conf")" == keep ]] || fail invalid-receipt
mv "$DOTFILES_RECEIPT_PATH" "$TMP/target"; ln -s "$TMP/target" "$DOTFILES_RECEIPT_PATH"; ! main || fail receipt-symlink-exit; [[ "$(cat "$TMP/target")" == invalid ]] || fail receipt-symlink

# Whole-receipt zero mutation + arbitrary backup 차단.
rm -f "$DOTFILES_RECEIPT_PATH"; printf '# ===== dotfiles-begin =====\nx\n# ===== dotfiles-end =====\n' > "$HOME/.bashrc"
printf user > "$HOME/user-backup"; printf managed > "$HOME/.tmux.conf"; mh="$(file_hash "$HOME/.tmux.conf")"
jq -n --arg p "$HOME/.tmux.conf" --arg b "$HOME/user-backup" --arg h "$mh" '{schemaVersion:1,artifacts:{($p):{before:{exists:true,hash:$h,mode:"644",backup:$b},installedHash:$h,installedMode:"644",pending:false}},packages:{},values:{}}' > "$DOTFILES_RECEIPT_PATH"
! main || fail arbitrary-backup-exit; grep -q dotfiles-begin "$HOME/.bashrc"; [[ "$(cat "$HOME/user-backup")" == user ]] || fail arbitrary-backup

# Mixed artifact discriminator는 whole preflight에서 zero mutation이다.
jq -n --arg p "$HOME/.tmux.conf" --arg h "$mh" '{schemaVersion:1,artifacts:{($p):{before:{exists:false},installedHash:$h,installedMode:"644",installedTreeHash:$h,pending:false}},packages:{},values:{}}' > "$DOTFILES_RECEIPT_PATH"
! main || fail mixed-kind-exit; grep -q dotfiles-begin "$HOME/.bashrc"; [[ "$(cat "$HOME/.tmux.conf")" == managed ]] || fail mixed-kind-zero-mutation

# Stable pending previous는 pending만 취소하고 기존 identity를 같은 호출에서 제거한다.
rm -f "$DOTFILES_RECEIPT_PATH"; printf stable > "$HOME/.tmux.conf"; sh="$(file_hash "$HOME/.tmux.conf")"
jq -n --arg p "$HOME/.tmux.conf" --arg h "$sh" '{schemaVersion:1,artifacts:{($p):{before:{exists:false},installedHash:$h,installedMode:"644",pending:true,targetHash:"new",targetMode:"644",previousExists:true,previousHash:$h,previousMode:"644"}},packages:{},values:{}}' > "$DOTFILES_RECEIPT_PATH"
main; [[ ! -e "$HOME/.tmux.conf" && ! -e "$DOTFILES_RECEIPT_PATH" ]] || fail pending-stable

# Restore 뒤 receipt commit 실패도 before identity + canonical backup 부재로 재실행 수렴한다.
printf managed > "$HOME/.config/starship.toml"; managed_hash="$(file_hash "$HOME/.config/starship.toml")"; chmod 644 "$HOME/.config/starship.toml"; managed_mode="$(file_mode "$HOME/.config/starship.toml")"
printf original > "$HOME/.config/starship.toml.dotfiles-backup"; original_hash="$(file_hash "$HOME/.config/starship.toml.dotfiles-backup")"; chmod 600 "$HOME/.config/starship.toml.dotfiles-backup"; original_mode="$(file_mode "$HOME/.config/starship.toml.dotfiles-backup")"
jq -n --arg p "$HOME/.config/starship.toml" --arg b "$HOME/.config/starship.toml.dotfiles-backup" --arg mh "$managed_hash" --arg mm "$managed_mode" --arg oh "$original_hash" --arg om "$original_mode" '{schemaVersion:1,artifacts:{($p):{before:{exists:true,hash:$oh,mode:$om,backup:$b},installedHash:null,pending:true,targetHash:$mh,targetMode:$mm,previousExists:true,previousHash:$oh,previousMode:$om}},packages:{},values:{}}' > "$DOTFILES_RECEIPT_PATH"
eval "$(declare -f drop_entry | sed '1s/drop_entry/drop_entry_real/')"
drop_entry(){ return 1; }
! uninstall_artifact "$HOME/.config/starship.toml" || fail restore-commit-fault
[[ "$(cat "$HOME/.config/starship.toml")" == original && ! -e "$HOME/.config/starship.toml.dotfiles-backup" ]] || fail restore-before-commit
drop_entry(){ drop_entry_real "$@"; }
uninstall_artifact "$HOME/.config/starship.toml"; [[ ! -e "$DOTFILES_RECEIPT_PATH" || "$(jq '.artifacts|length' "$DOTFILES_RECEIPT_PATH")" == 0 ]] || fail restore-commit-retry

# jq terminal marker: keep/changed/absent가 정확히 수렴한다.
printf 'dotfiles-jq-terminal-v1\tapt\t1\n' > "$DOTFILES_RECEIPT_PATH"
KEEP_PACKAGES=true; query_terminal_jq(){ TERMINAL_STATE=present;TERMINAL_VERSION=1; }; recover_terminal_jq "$(cat "$DOTFILES_RECEIPT_PATH")"; [[ ! -e "$DOTFILES_RECEIPT_PATH" ]] || fail terminal-keep
printf 'dotfiles-jq-terminal-v1\tapt\t1\n' > "$DOTFILES_RECEIPT_PATH"; KEEP_PACKAGES=false; query_terminal_jq(){ TERMINAL_STATE=present;TERMINAL_VERSION=9; }; ! recover_terminal_jq "$(cat "$DOTFILES_RECEIPT_PATH")" || fail terminal-changed-exit; [[ -f "$DOTFILES_RECEIPT_PATH" ]] || fail terminal-changed
query_terminal_jq(){ TERMINAL_STATE=absent;TERMINAL_VERSION=''; }; recover_terminal_jq "$(cat "$DOTFILES_RECEIPT_PATH")"; [[ ! -e "$DOTFILES_RECEIPT_PATH" ]] || fail terminal-absent
printf 'dotfiles-jq-terminal-v1\tapt\t1\ninjected\n' > "$DOTFILES_RECEIPT_PATH"; ! recover_terminal_jq "$(cat "$DOTFILES_RECEIPT_PATH")" || fail terminal-multiline-exit; [[ -f "$DOTFILES_RECEIPT_PATH" ]] || fail terminal-multiline

echo 'safe-clean uninstall bash: PASS'
