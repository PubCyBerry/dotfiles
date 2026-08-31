# 마이그레이션: statusline 명령이 두 번 옮겨졌다. claude-hud 플러그인이 만들어 준 명령줄
# → `ccusage statusline` → 지금은 둘을 합치는 `bash ~/.claude/statusline.sh`다. 이 파일은
# destination 우선 merge라, 기존 설치에 남은 옛 명령이 managed 값을 영구히 덮는다. 그대로
# 두면 claude-hud 명령은 가리키던 dist/index.js가 사라져 statusline이 죽고, `ccusage
# statusline`은 죽지는 않지만 경로가 영원히 안 나온다 — 어느 쪽이든 사용자는 원인을 알 방법이
# 없다. 이 저장소가 과거에 심은 값과 일치할 때만 걷어내고, 사용자가 직접 넣은 statusLine은
# 그대로 둔다. 판정 근거를 두 갈래로 나눈 이유는 값의 모양이 다르기 때문이다. claude-hud
# 명령줄은 머신마다 경로가 달라 부분 일치로 볼 수밖에 없고, ccusage 쪽은 이 저장소가 배포한
# 고정 문자열이라 정확히 그 값일 때만 소유로 인정하면 된다.
def purge_legacy_statusline:
  ((.statusLine.command // "") | if type == "string" then . else "" end) as $cmd
  | if (.statusLine | type) == "object"
       and (($cmd | test("claude-hud")) or ($cmd == "ccusage statusline"))
    then del(.statusLine)
    else . end;

def hook_id:
  if type == "object" and .type == "command" and (.command | type) == "string"
  then ["command", .command]
  else .
  end;

def merge_hook_entries($old; $managed):
  reduce ($managed // [])[] as $entry
    ($old // [];
      reduce ($entry.hooks // [])[] as $hook
        (.;
          ($hook | hook_id) as $id
          | map(.hooks = [(.hooks // [])[] | select((hook_id) != $id)])
          | map(select((.hooks // []) | length > 0))
          | ($entry.matcher // "") as $matcher
          | (map(.matcher // "") | index($matcher)) as $index
          | if $index == null then
              . + [($entry + {"hooks": [$hook]})]
            else
              .[$index].hooks = ((.[$index].hooks // []) + [$hook])
            end));

def managed_hook_ids($managed):
  [ ($managed // {}) | to_entries[] | (.value // [])[]? | (.hooks // [])[]? | hook_id ];

# 관리 hook이 다른 event로 옮겨가면 옛 event에 남은 사본을 걷어낸다. managed에 없는 event만
# 훑으므로 사용자 hook은 그대로 남고, 비게 된 matcher group과 event key만 사라진다.
# 이게 없으면 event를 옮긴 뒤 기존 설치에서 옛 자리와 새 자리 양쪽이 함께 발동한다.
def purge_relocated_hooks($old; $managed):
  managed_hook_ids($managed) as $ids
  | (($managed // {}) | keys) as $managed_events
  | reduce (($old // {}) | keys_unsorted[]) as $event
      ($old // {};
        if ($managed_events | index($event)) != null or (.[$event] | type) != "array" then .
        else
          .[$event] = [ .[$event][]
                        | if type == "object" then
                            .hooks = [ (.hooks // [])[]
                                       | . as $hook
                                       | select([$ids[] | . == ($hook | hook_id)] | any | not) ]
                          else . end ]
          | .[$event] |= map(select(type != "object" or ((.hooks // []) | length) > 0))
          | if (.[$event] | length) == 0 then del(.[$event]) else . end
        end);

def merge_hooks($old; $managed):
  reduce (($managed // {}) | keys_unsorted[]) as $event
    (purge_relocated_hooks($old; $managed);
      .[$event] = merge_hook_entries(.[$event]; $managed[$event]));

def append_unique($old; $managed):
  reduce (($old // []) + ($managed // []))[] as $item
    ([]; if any(.[]; . == $item) then . else . + [$item] end);

def merge_permissions($old; $managed):
  reduce (($managed // {}) | keys_unsorted[]) as $key
    ($old // {};
      .[$key] =
        if (.[$key] | type) == "array" and ($managed[$key] | type) == "array" then
          append_unique(.[$key]; $managed[$key])
        elif (.[$key] | type) == "object" and ($managed[$key] | type) == "object" then
          $managed[$key] * .[$key]
        elif has($key) then
          .[$key]
        else
          $managed[$key]
        end);

(.[0] | purge_legacy_statusline) as $old
| .[1] as $managed
| ($managed * $old)
| if (($old | has("permissions")) or ($managed | has("permissions"))) then
    .permissions = merge_permissions($old.permissions; $managed.permissions)
  else . end
| if (($old | has("hooks")) or ($managed | has("hooks"))) then
    .hooks = merge_hooks($old.hooks; $managed.hooks)
  else . end
| if (.env | type) == "object" then del(.env.CLAUDE_CODE_SUBAGENT_MODEL) else . end
