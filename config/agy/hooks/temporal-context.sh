#!/usr/bin/env bash
# Antigravity PreInvocation 훅: 턴마다 현재 시간 컨텍스트 주입
# %Z는 Git Bash(MSYS)에서 한국어 타임존 이름이 깨져 빈 값이 되므로 숫자 오프셋(%z)을 쓴다.
NOW="$(date '+%Y-%m-%d %H:%M:%S %z')"
cat <<EOF
{
  "injectSteps": [
    {
      "ephemeralMessage": "[System Time] 현재 로컬 시각: ${NOW}"
    }
  ]
}
EOF
