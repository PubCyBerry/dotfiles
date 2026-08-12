"""Claude Code agent YAML frontmatter 공용 검증기."""

from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass


CLAUDE_KEYS = {
    "name",
    "description",
    "tools",
    "disallowedTools",
    "model",
    "permissionMode",
    "maxTurns",
    "skills",
    "mcpServers",
    "hooks",
    "memory",
    "background",
    "effort",
    "isolation",
    "color",
    "initialPrompt",
}
CORE_TOOLS = {
    "Agent",
    "Artifact",
    "Bash",
    "CronCreate",
    "CronDelete",
    "CronList",
    "Edit",
    "EnterWorktree",
    "ExitPlanMode",
    "ExitWorktree",
    "Glob",
    "Grep",
    "LSP",
    "ListMcpResourcesTool",
    "ListAgents",
    "Monitor",
    "NotebookEdit",
    "PowerShell",
    "PushNotification",
    "Read",
    "ReadMcpResourceTool",
    "RemoteTrigger",
    "ReportFindings",
    "SendMessage",
    "SendUserFile",
    "ShareOnboardingGuide",
    "Skill",
    "Task",
    "TaskCreate",
    "TaskGet",
    "TaskList",
    "TaskStop",
    "TaskUpdate",
    "TodoWrite",
    "ToolSearch",
    "WebFetch",
    "WebSearch",
    "Write",
}
EFFORTS = {"low", "medium", "high", "xhigh", "max"}
PERMISSION_MODES = {
    "default",
    "acceptEdits",
    "auto",
    "dontAsk",
    "bypassPermissions",
    "manual",
    "plan",
}
MEMORY_SCOPES = {"user", "project", "local"}
COLORS = {"red", "blue", "green", "yellow", "purple", "orange", "pink", "cyan"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
FRONTMATTER_RE = re.compile(
    r"\A---[ \t]*\r?\n(?P<yaml>.*?)\r?\n---[ \t]*(?:\r?\n|\Z)", re.DOTALL
)
TOOL_RE = re.compile(r"^(?P<name>[A-Za-z][A-Za-z0-9]*)(?:\([^()]*\))?$")
MCP_TOOL_RE = re.compile(
    r"^mcp__(?:[A-Za-z0-9.-]+(?:_[A-Za-z0-9.-]+)*"
    r"(?:__(?:\*|[A-Za-z0-9.-]+(?:_[A-Za-z0-9.-]+)*))?|\*)$"
)


def _strings(value: object, field: str, errors: list[str]) -> list[str]:
    if isinstance(value, str) and field in {"tools", "disallowedTools"}:
        items = [
            part.strip()
            for part in re.split(r",\s*(?![^()]*\))", value)
            if part.strip()
        ]
        if not items:
            errors.append(f"`{field}`는 비어 있지 않은 문자열 목록이어야 한다")
        return items
    if (
        isinstance(value, list)
        and value
        and all(isinstance(item, str) and item.strip() for item in value)
    ):
        return [item.strip() for item in value]
    errors.append(f"`{field}`는 비어 있지 않은 문자열 목록이어야 한다")
    return []


def _check_tools(value: object, field: str, errors: list[str]) -> None:
    for tool in _strings(value, field, errors):
        if MCP_TOOL_RE.fullmatch(tool) and (
            tool != "mcp__*" or field == "disallowedTools"
        ):
            continue
        match = TOOL_RE.fullmatch(tool)
        if not match or match.group("name") not in CORE_TOOLS:
            errors.append(f"`{field}`에 알 수 없는 도구 이름이 있다: {tool!r}")


def _check_enum(
    fields: dict, field: str, allowed: set[str], errors: list[str]
) -> None:
    value = fields.get(field)
    if value is not None and (not isinstance(value, str) or value not in allowed):
        errors.append(f"`{field}`({value!r})가 {sorted(allowed)} 밖이다")


def validate_text(text: str, expected_name: str | None = None) -> list[str]:
    """조립된 Claude agent 문서를 검증해 오류 목록을 반환한다."""
    errors: list[str] = []
    match = FRONTMATTER_RE.match(text.lstrip("\ufeff"))
    if not match:
        return ["YAML frontmatter 블록(`--- ... ---`)을 찾을 수 없다"]

    try:
        fields = yaml.safe_load(match.group("yaml"))
    except yaml.YAMLError as exc:
        return [f"YAML 파싱 실패 — {exc}"]
    if not isinstance(fields, dict):
        return ["YAML frontmatter가 매핑이 아니다"]

    unknown = set(fields) - CLAUDE_KEYS
    if unknown:
        errors.append(f"알 수 없는 키 {sorted(map(str, unknown))}")

    name = fields.get("name")
    if not isinstance(name, str) or not NAME_RE.fullmatch(name):
        errors.append("`name`은 kebab-case 문자열이어야 한다")
    elif expected_name is not None and name != expected_name:
        errors.append(f"`name`({name!r})이 예상 이름({expected_name!r})과 다르다")

    description = fields.get("description")
    if not isinstance(description, str) or not description.strip():
        errors.append("`description`이 없거나 비어 있다")

    for field in ("tools", "disallowedTools"):
        if field in fields:
            _check_tools(fields[field], field, errors)

    model = fields.get("model")
    # alias(fable 포함) 외에도 provider별 model/deployment 이름을 받으므로 문자열만 고정한다.
    if model is not None and (not isinstance(model, str) or not model.strip()):
        errors.append("`model`은 비어 있지 않은 문자열이어야 한다")

    _check_enum(fields, "effort", EFFORTS, errors)

    max_turns = fields.get("maxTurns")
    if max_turns is not None and (
        isinstance(max_turns, bool) or not isinstance(max_turns, int) or max_turns < 1
    ):
        errors.append("`maxTurns`는 1 이상의 정수여야 한다")

    if "skills" in fields:
        _strings(fields["skills"], "skills", errors)

    isolation = fields.get("isolation")
    if isolation is not None and isolation != "worktree":
        errors.append("`isolation`은 `worktree`만 허용한다")

    _check_enum(fields, "permissionMode", PERMISSION_MODES, errors)
    _check_enum(fields, "memory", MEMORY_SCOPES, errors)

    background = fields.get("background")
    if background is not None and not isinstance(background, bool):
        errors.append("`background`는 boolean이어야 한다")

    _check_enum(fields, "color", COLORS, errors)

    initial_prompt = fields.get("initialPrompt")
    if initial_prompt is not None and (
        not isinstance(initial_prompt, str) or not initial_prompt.strip()
    ):
        errors.append("`initialPrompt`는 비어 있지 않은 문자열이어야 한다")

    hooks = fields.get("hooks")
    if hooks is not None and not isinstance(hooks, dict):
        errors.append("`hooks`는 매핑이어야 한다")

    mcp_servers = fields.get("mcpServers")
    if mcp_servers is not None and not isinstance(mcp_servers, (list, dict)):
        errors.append("`mcpServers`는 목록 또는 매핑이어야 한다")

    if not text.lstrip("\ufeff")[match.end() :].strip():
        errors.append("시스템 프롬프트 본문이 비어 있다")
    return errors


def validate(path: Path, expected_name: str | None = None) -> tuple[list[str], list[str]]:
    """파일을 읽어 검증한다. 두 번째 반환값은 CLI 호환용 경고 목록이다."""
    try:
        text = path.read_text(encoding="utf-8-sig")
    except OSError as exc:
        return [f"파일을 읽을 수 없다: {exc}"], []
    if expected_name is None:
        expected_name = path.stem
    return validate_text(text, expected_name), []
