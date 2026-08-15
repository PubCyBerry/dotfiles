#!/usr/bin/env bash
# Antigravity PreInvocation 훅: 현재 시간 컨텍스트 주입
NOW="$(date '+%Y-%m-%d %H:%M:%S %Z')"
cat <<EOF
{
  "injectSteps": [
    {
      "ephemeralMessage": "[System Time] 현재 로컬 시각: ${NOW}"
    }
  ]
}
EOF
