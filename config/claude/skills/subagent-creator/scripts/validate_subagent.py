#!/usr/bin/env python3
"""Claude Code subagent 정의(.claude/agents/<name>.md) 형식 검증기.

표준 라이브러리만 사용한다(외부 의존성 없음). frontmatter와 시스템 프롬프트 본문을
검사해 흔한 정의 실수를 잡는다.

사용법:
    python validate_subagent.py <path-to-agent>.md

종료 코드:
    0  통과 또는 경고만 있음
    1  오류 있음(또는 파일을 열 수 없음)
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Windows 콘솔(cp949 등)에서 한글/기호 출력이 깨지거나 크래시하지 않도록 UTF-8로 맞춘다.
for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

# Claude Code 코어 도구 이름(자주 바뀔 수 있어 경고용 allowlist로만 쓴다).
# 여기 없는 이름이라고 무조건 틀린 건 아니므로 오류가 아니라 경고로 처리한다.
KNOWN_TOOLS = {
    "Task", "Bash", "BashOutput", "KillShell", "KillBash",
    "Glob", "Grep", "Read", "Edit", "MultiEdit", "Write",
    "NotebookEdit", "WebFetch", "WebSearch", "TodoWrite", "SlashCommand",
}
# model 표준 별칭. 그 외에도 전체 모델 ID(claude-...)가 유효할 수 있어 경고로만 둔다.
KNOWN_MODEL_ALIASES = {"sonnet", "opus", "haiku", "inherit"}

KEBAB_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def parse_frontmatter(text: str):
    """선두 YAML frontmatter 블록을 파싱한다.

    반환: (fields dict, body str) 또는 frontmatter 블록이 없으면 (None, text).
    중첩 없는 단순 `key: value` 형태만 다룬다(subagent frontmatter는 평면 구조).
    """
    if not text.startswith("---"):
        return None, text
    # 첫 줄(---) 다음부터 닫는 --- 까지.
    lines = text.splitlines()
    if lines[0].strip() != "---":
        return None, text
    end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end = i
            break
    if end is None:
        return None, text

    fields: dict[str, str] = {}
    for line in lines[1:end]:
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2).strip()
        # 양끝 따옴표 제거.
        if len(val) >= 2 and val[0] == val[-1] and val[0] in ("'", '"'):
            val = val[1:-1]
        fields[key] = val

    body = "\n".join(lines[end + 1:]).strip()
    return fields, body


def validate(path: Path):
    """파일을 검증해 (errors, warnings) 리스트를 반환한다."""
    errors: list[str] = []
    warnings: list[str] = []

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as exc:
        return [f"파일을 읽을 수 없음: {exc}"], warnings

    fields, body = parse_frontmatter(text)
    if fields is None:
        errors.append("YAML frontmatter 블록(--- ... ---)을 찾을 수 없음")
        return errors, warnings

    # name: 필수, kebab-case, 파일명과 일치.
    name = fields.get("name")
    if not name:
        errors.append("`name` 필드가 없음(필수)")
    else:
        if not KEBAB_RE.match(name):
            errors.append(f"`name`이 kebab-case가 아님: {name!r}")
        stem = path.stem
        if name != stem:
            errors.append(f"`name`({name!r})이 파일명({stem!r})과 일치하지 않음")

    # description: 필수, 비어있지 않음.
    description = fields.get("description")
    if not description:
        errors.append("`description` 필드가 없거나 비어있음(필수, 위임 트리거)")

    # tools: 선택. 알 수 없는 이름은 경고.
    tools = fields.get("tools")
    if tools:
        for raw in tools.split(","):
            tool = raw.strip()
            if not tool:
                continue
            if tool.startswith("mcp__"):
                continue  # MCP 도구는 통과.
            if tool not in KNOWN_TOOLS:
                warnings.append(f"알 수 없는 도구 이름(오타 가능): {tool!r}")

    # model: 선택. 표준 별칭/claude- 접두사 외는 경고.
    model = fields.get("model")
    if model and model not in KNOWN_MODEL_ALIASES and not model.startswith("claude"):
        warnings.append(
            f"비표준 model 값: {model!r} "
            f"(표준 별칭: {', '.join(sorted(KNOWN_MODEL_ALIASES))})"
        )

    # 본문(시스템 프롬프트): 비어있지 않음.
    if not body:
        errors.append("시스템 프롬프트 본문이 비어있음(frontmatter 뒤에 내용 필요)")

    return errors, warnings


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Claude Code subagent 정의 파일 형식 검증기"
    )
    parser.add_argument("path", help="검증할 subagent .md 파일 경로")
    args = parser.parse_args()

    path = Path(args.path)
    errors, warnings = validate(path)

    for w in warnings:
        print(f"  [warn] {w}")
    for e in errors:
        print(f"  [error] {e}")

    if errors:
        print(f"\nFAIL: 검증 실패 — 오류 {len(errors)}건, 경고 {len(warnings)}건 — {path}")
        return 1
    if warnings:
        print(f"\nPASS (경고 {len(warnings)}건) — {path}")
    else:
        print(f"\nPASS — {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
