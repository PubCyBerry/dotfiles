#!/usr/bin/env python3
"""config/agents/roles/ 소스와 조립 결과를 검증한다.

install 스크립트는 frontmatter + body.md를 이어붙여 두 곳에 배포한다:
  Claude → ~/.claude/agents/<name>.md      (subagent)
  Codex  → ~/.codex/skills/<name>/SKILL.md (skill)

두 산출물 모두 frontmatter를 파싱할 수 있어야 하고, name이 디렉터리 이름과
같아야 한다. 조립 후에야 알 수 있는 오류(예: body 첫 줄이 `---`여서 frontmatter
경계가 깨지는 경우)를 잡기 위해 소스가 아니라 조립 결과를 검사한다.

사용: python3 scripts/validate-agent-roles.py [roles_dir]
"""

import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML이 필요하다: pip install pyyaml")

REQUIRED_FILES = ("body.md", "claude.frontmatter", "codex.frontmatter", "openai.yaml")

# Claude subagent frontmatter에서 허용하는 키 (name/description은 필수)
CLAUDE_KEYS = {"name", "description", "tools", "model"}
CLAUDE_MODELS = {"sonnet", "opus", "haiku", "inherit"}

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

    # Codex: frontmatter + body 조립 결과
    codex = parse_frontmatter(
        (d / "codex.frontmatter").read_text(encoding="utf-8") + body, role, "codex"
    )
    if codex:
        if codex.get("name") != role:
            fail(role, f"codex: name({codex.get('name')!r})이 디렉터리 이름과 다르다")
        if not str(codex.get("description", "")).strip():
            fail(role, "codex: description이 비었다")
        # Codex는 tools/model을 지원하지 않는다 — 넣으면 조용히 무시되므로 오해를 막는다
        for key in ("tools", "model"):
            if key in codex:
                fail(role, f"codex: `{key}`는 Codex skill에서 지원하지 않는다")
        meta = codex.get("metadata")
        if not isinstance(meta, dict) or not str(meta.get("short-description", "")).strip():
            fail(role, "codex: metadata.short-description이 없다")

    # Codex UI 메타
    try:
        oy = yaml.safe_load((d / "openai.yaml").read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        fail(role, f"openai.yaml: YAML 파싱 실패 — {e}")
        return
    if not isinstance(oy, dict):
        fail(role, "openai.yaml: 매핑이 아니다")
        return
    iface = oy.get("interface")
    if not isinstance(iface, dict):
        fail(role, "openai.yaml: interface 절이 없다")
        return
    for key in ("display_name", "short_description", "default_prompt"):
        if not str(iface.get(key, "")).strip():
            fail(role, f"openai.yaml: interface.{key}가 없다")
    prompt = str(iface.get("default_prompt", ""))
    if f"${role}" not in prompt:
        fail(role, f"openai.yaml: default_prompt에 `${role}` 언급이 없다")


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
