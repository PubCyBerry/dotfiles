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

.[0] as $old
| .[1] as $managed
| ($managed * $old)
| if (($old | has("permissions")) or ($managed | has("permissions"))) then
    .permissions = merge_permissions($old.permissions; $managed.permissions)
  else . end
| if (($old | has("hooks")) or ($managed | has("hooks"))) then
    .hooks = merge_hooks($old.hooks; $managed.hooks)
  else . end
| if (.env | type) == "object" then del(.env.CLAUDE_CODE_SUBAGENT_MODEL) else . end
