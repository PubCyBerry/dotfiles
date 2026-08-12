"""Claude Code agent 정의 파일 CLI 검증기."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from agent_validator import validate


def main() -> int:
    parser = argparse.ArgumentParser(description="Claude Code agent 정의 파일 형식 검증기")
    parser.add_argument("path", help="검증할 agent .md 파일 경로")
    path = Path(parser.parse_args().path)
    errors, _ = validate(path)

    for error in errors:
        print(f"  [error] {error}")
    if errors:
        print(f"\nFAIL — 오류 {len(errors)}건 — {path}")
        return 1
    print(f"PASS — {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
