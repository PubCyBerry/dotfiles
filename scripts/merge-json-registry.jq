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

def merge_hooks($old; $managed):
  reduce (($managed // {}) | keys_unsorted[]) as $event
    ($old // {};
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
