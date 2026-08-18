#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook: 턴마다 현재 날짜/시간을 컨텍스트로 주입
date_str="$(date '+%Y-%m-%d %H:%M:%S %z')"
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Current date/time: %s"}}\n' "$date_str"
