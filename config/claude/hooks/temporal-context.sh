#!/usr/bin/env bash
# Claude Code SessionStart hook: 현재 날짜/시간을 세션 컨텍스트로 주입
date_str="$(date '+%Y-%m-%d %H:%M:%S %z')"
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"Current date/time: %s"}}\n' "$date_str"
