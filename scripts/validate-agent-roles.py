#!/usr/bin/env python3
"""config/agents/roles/ 소스와 조립 결과를 검증한다.

install 스크립트는 body.md를 플랫폼별 메타와 이어붙여 두 곳에 배포한다:
  Claude → ~/.claude/agents/<name>.md    (claude.frontmatter + body)
  Codex  → ~/.codex/agents/<name>.toml   (codex.toml + developer_instructions = body)

두 산출물 모두 파싱 가능해야 하고, name이 디렉터리 이름과 같아야 한다. 조립
후에야 알 수 있는 오류(예: body 첫 줄이 `---`여서 frontmatter 경계가 깨지거나,
body에 `'''`가 있어 TOML literal string이 조기 종료되는 경우)를 잡기 위해
소스가 아니라 조립 결과를 검사한다.

사용: python3 scripts/validate-agent-roles.py [roles_dir]
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML이 필요하다: pip install pyyaml")

try:
    import tomllib
except ImportError:  # Python 3.10 이하
    sys.exit("Python 3.11+ 가 필요하다 (tomllib)")

REQUIRED_FILES = ("body.md", "claude.frontmatter", "codex.toml")

# Claude subagent frontmatter에서 허용하는 키 (name/description은 필수)
CLAUDE_KEYS = {"name", "description", "tools", "model"}
CLAUDE_MODELS = {"sonnet", "opus", "haiku", "inherit"}

# Codex subagent TOML에서 허용하는 키 (name/description/developer_instructions는 필수)
CODEX_KEYS = {
    "name",
    "description",
    "developer_instructions",
    "model",
    "model_reasoning_effort",
    "sandbox_mode",
    "mcp_servers",
}
CODEX_EFFORTS = {"minimal", "low", "medium", "high", "xhigh"}
CODEX_SANDBOX = {"read-only", "workspace-write", "danger-full-access"}

errors: list[str] = []


def fail(role: str, msg: str) -> None:
    errors.append(f"{role}: {msg}")


def parse_frontmatter(text: str, role: str, label: str):
    """조립된 문서에서 frontmatter dict를 꺼낸다."""
    if not text.startswith("---\n"):
        fail(role, f"{label}: frontmatter가 `---` 로 시작하지 않는다")
        return None
    end = text.find("\n---\n", 3)
    if end == -1:
        fail(role, f"{label}: frontmatter 종료 구분자(`---`)가 없다")
        return None
    try:
        data = yaml.safe_load(text[4:end + 1])
    except yaml.YAMLError as e:
        fail(role, f"{label}: YAML 파싱 실패 — {e}")
        return None
    if not isinstance(data, dict):
        fail(role, f"{label}: frontmatter가 매핑이 아니다")
        return None
    body = text[end + 5:]
    if not body.strip():
        fail(role, f"{label}: 본문이 비었다")
    return data


def check_role(d: Path) -> None:
    role = d.name

    for f in REQUIRED_FILES:
        if not (d / f).is_file():
            fail(role, f"필수 파일 누락: {f}")
    if errors and any(e.startswith(f"{role}: 필수 파일") for e in errors):
        return

    body = (d / "body.md").read_text(encoding="utf-8")
    if body.lstrip().startswith("---"):
        fail(role, "body.md가 `---`로 시작하면 조립 시 frontmatter 경계가 깨진다")

    # Claude: frontmatter + body 조립 결과
    claude = parse_frontmatter(
        (d / "claude.frontmatter").read_text(encoding="utf-8") + body, role, "claude"
    )
    if claude:
        if claude.get("name") != role:
            fail(role, f"claude: name({claude.get('name')!r})이 디렉터리 이름과 다르다")
        if not str(claude.get("description", "")).strip():
            fail(role, "claude: description이 비었다")
        unknown = set(claude) - CLAUDE_KEYS
        if unknown:
            fail(role, f"claude: 알 수 없는 키 {sorted(unknown)}")
        model = claude.get("model")
        if model is not None and model not in CLAUDE_MODELS and "-" not in str(model):
            fail(role, f"claude: model({model!r})이 별칭도 모델 ID도 아니다")
        tools = claude.get("tools")
        if tools is not None and not str(tools).strip():
            fail(role, "claude: tools가 비었다 (생략하면 전체 상속)")

    # Codex: codex.toml + developer_instructions = body 조립 결과
    if "'''" in body:
        fail(role, "body.md에 `'''`가 있으면 TOML literal string이 조기 종료된다")
    meta_text = (d / "codex.toml").read_text(encoding="utf-8")
    if not meta_text.endswith("\n"):
        meta_text += "\n"
    body_text = body if body.endswith("\n") else body + "\n"
    assembled = f"{meta_text}developer_instructions = '''\n{body_text}'''\n"
    try:
        codex = tomllib.loads(assembled)
    except tomllib.TOMLDecodeError as e:
        fail(role, f"codex: TOML 파싱 실패 — {e}")
        return
    if codex.get("name") != role:
        fail(role, f"codex: name({codex.get('name')!r})이 디렉터리 이름과 다르다")
    if not str(codex.get("description", "")).strip():
        fail(role, "codex: description이 비었다")
    if not str(codex.get("developer_instructions", "")).strip():
        fail(role, "codex: developer_instructions(=body.md)가 비었다")
    if "developer_instructions" in tomllib.loads(meta_text):
        fail(role, "codex.toml에 developer_instructions를 직접 두면 조립 시 키가 중복된다")
    unknown = set(codex) - CODEX_KEYS
    if unknown:
        fail(role, f"codex: 알 수 없는 키 {sorted(unknown)}")
    effort = codex.get("model_reasoning_effort")
    if effort is not None and effort not in CODEX_EFFORTS:
        fail(role, f"codex: model_reasoning_effort({effort!r})가 {sorted(CODEX_EFFORTS)} 밖이다")
    sandbox = codex.get("sandbox_mode")
    if sandbox is not None and sandbox not in CODEX_SANDBOX:
        fail(role, f"codex: sandbox_mode({sandbox!r})가 {sorted(CODEX_SANDBOX)} 밖이다")
    # Claude subagent는 tools 목록으로 권한을 좁힌다. Codex는 sandbox_mode가 그 역할을
    # 하므로, 파일을 쓰는 role이 read-only로 배포되면 런타임에 조용히 실패한다.
    if sandbox == "read-only" and "docs/" in body:
        fail(role, "codex: body가 파일 작성을 지시하는데 sandbox_mode가 read-only다")


def main() -> int:
    roles_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "config/agents/roles")
    if not roles_dir.is_dir():
        sys.exit(f"디렉터리를 찾을 수 없다: {roles_dir}")

    dirs = sorted(p for p in roles_dir.iterdir() if p.is_dir())
    if not dirs:
        sys.exit(f"role이 하나도 없다: {roles_dir}")

    for d in dirs:
        check_role(d)

    if errors:
        print(f"FAIL — {len(errors)}건")
        for e in errors:
            print(f"  - {e}")
        return 1

    print(f"PASS — role {len(dirs)}개: {', '.join(d.name for d in dirs)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
