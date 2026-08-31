#!/usr/bin/env bash
# Claude Code statusline: claude-hud(경로·git·컨텍스트) + ccusage(비용·소진 속도).
#
# Claude Code는 statusline 명령에 상태 JSON을 stdin으로 한 번 흘린다. 두 도구 모두 그
# JSON을 읽으므로, 한 번 읽어 버퍼에 담고 같은 바이트를 둘에게 나눠 먹인다.
#
# 이 저장소가 statusLine 명령을 직접 소유하는 이유는 `/claude-hud:setup`이 만들어 주던
# 명령줄에 fnm의 특정 Node 경로와 플러그인 캐시 경로가 박혀 있었기 때문이다. Node를 올리거나
# 플러그인이 업데이트되면 그 경로가 죽고, 저장소가 그 값을 소유하지 않아 install이 고칠 수도
# 없었다. 여기서는 실행 시점에 탐색하므로 그 결합이 없다.
set -u

input="$(cat)"

# --- claude-hud ---------------------------------------------------------------
# 플러그인 entrypoint를 실행 시점에 찾는다. 경로를 고정하면 마켓플레이스가 업데이트될 때
# 조용히 죽는다. 여러 버전이 남아 있을 수 있으므로 가장 최근 것을 고른다.
hud_entry=""
for candidate in \
    "$HOME"/.claude/plugins/cache/*/claude-hud/*/dist/index.js \
    "$HOME"/.claude/plugins/cache/*/claude-hud/dist/index.js \
    "$HOME"/.claude/plugins/claude-hud/dist/index.js
do
    [[ -f "$candidate" ]] || continue
    [[ -z "$hud_entry" || "$candidate" -nt "$hud_entry" ]] && hud_entry="$candidate"
done

hud_out=""
if [[ -n "$hud_entry" ]] && command -v node >/dev/null 2>&1; then
    hud_out="$(printf '%s' "$input" | node "$hud_entry" 2>/dev/null)"
fi

# --- fallback: claude-hud가 없으면 경로만이라도 --------------------------------
# 플러그인 설치는 install의 마지막 단계라 첫 실행 중이거나, node가 PATH에 없거나, 사용자가
# 플러그인을 지웠을 수 있다. 그때 statusline이 경로를 통째로 잃지 않게 한다.
if [[ -z "$hud_out" ]] && command -v jq >/dev/null 2>&1; then
    dir="$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)" || dir=""
    if [[ -n "$dir" ]]; then
        command -v cygpath >/dev/null 2>&1 && dir="$(cygpath -u "$dir" 2>/dev/null || printf '%s' "$dir")"
        case "$dir" in
            "$HOME"/*) dir="~${dir#"$HOME"}" ;;
            "$HOME")   dir="~" ;;
        esac
        hud_out="$(printf '\033[33m%s\033[0m' "$dir")"
    fi
fi

# --- ccusage -------------------------------------------------------------------
# 컨텍스트(🧠) 필드는 걷어낸다. claude-hud가 같은 값을 바까지 붙여 이미 보여주고, 그쪽은
# Claude Code가 stdin으로 주는 네이티브 퍼센트라 /context와 정확히 일치한다.
# ccusage에는 세그먼트를 끄는 옵션이 없어 출력에서 잘라내는 수밖에 없다.
usage_out=""
if command -v ccusage >/dev/null 2>&1; then
    usage_out="$(printf '%s' "$input" | ccusage statusline 2>/dev/null | awk -v FS=' [|] ' -v OFS=' | ' '
        { out = ""
          for (i = 1; i <= NF; i++) {
              if (index($i, "🧠")) continue
              out = (out == "" ? $i : out OFS $i)
          }
          print out }')"
fi

[[ -n "$hud_out" ]] && printf '%s\n' "$hud_out"
[[ -n "$usage_out" ]] && printf '%s\n' "$usage_out"
exit 0
