from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# 검증 engine은 저장소가 소유한다. skill 사본(PubCyBerry/subagent-creator)의
# validate_subagent.py wrapper는 그 저장소에서 테스트한다.
VALIDATOR_DIR = ROOT / "scripts"
sys.path.insert(0, str(VALIDATOR_DIR))

from agent_validator import validate_text  # noqa: E402


VALID_AGENT = """---
name: current-agent
description: 현재 Claude agent field를 검증한다.
tools:
  - Read
  - Agent(worker, researcher)
  - PowerShell
  - ToolSearch
  - mcp__demo
  - mcp__demo__*
  - mcp__demo__lookup
disallowedTools:
  - Write
  - mcp__*
model: fable
permissionMode: manual
maxTurns: 12
skills:
  - ponytail
mcpServers:
  - demo
hooks:
  PreToolUse:
    - matcher: Bash
      hooks:
        - type: command
          command: ./check.sh
memory: project
background: false
effort: max
isolation: worktree
color: cyan
initialPrompt: 시작한다.
---

agent 본문이다.
"""
FILTERED_CORE_TOOLS = (
    "CronCreate",
    "CronDelete",
    "CronList",
    "ListAgents",
    "PushNotification",
    "RemoteTrigger",
    "ReportFindings",
    "SendUserFile",
    "ShareOnboardingGuide",
)
FORBIDDEN_SUBAGENT_TOOLS = (
    "AskUserQuestion",
    "EndConversation",
    "EnterPlanMode",
    "ScheduleWakeup",
    "TaskOutput",
    "WaitForMcpServers",
    "Workflow",
)
UNDOCUMENTED_LEGACY_TOOLS = (
    "BashOutput",
    "KillBash",
    "KillShell",
    "MultiEdit",
    "SlashCommand",
)


class ClaudeAgentValidatorTests(unittest.TestCase):
    def test_current_fields_and_fable_pass(self) -> None:
        self.assertEqual([], validate_text(VALID_AGENT, "current-agent"))

    def test_malformed_yaml_fails(self) -> None:
        errors = validate_text("---\nname: [broken\n---\nbody\n", "broken")
        self.assertTrue(any("YAML 파싱 실패" in error for error in errors), errors)

    def test_unknown_key_and_tool_typo_fail(self) -> None:
        unknown = validate_text(
            "---\nname: typo\ndescription: test\ntool: Read\n---\nbody\n", "typo"
        )
        typo = validate_text(
            "---\nname: typo\ndescription: test\ntools: Read, Reaad\n---\nbody\n",
            "typo",
        )
        bad_mcp = validate_text(
            "---\nname: typo\ndescription: test\ntools: mcp____lookup\n---\nbody\n",
            "typo",
        )
        self.assertTrue(any("알 수 없는 키" in error for error in unknown), unknown)
        self.assertTrue(any("Reaad" in error for error in typo), typo)
        self.assertTrue(any("mcp____lookup" in error for error in bad_mcp), bad_mcp)

    def test_filtered_core_tools_pass_but_typo_fails(self) -> None:
        tool_list = ", ".join(FILTERED_CORE_TOOLS)
        for field in ("tools", "disallowedTools"):
            text = (
                f"---\nname: filtered\ndescription: test\n{field}: {tool_list}\n"
                "---\nbody\n"
            )
            self.assertEqual([], validate_text(text, "filtered"), field)
        errors = validate_text(
            "---\nname: filtered\ndescription: test\ntools: CronCreat\n---\nbody\n",
            "filtered",
        )
        self.assertTrue(any("CronCreat" in error for error in errors), errors)

    def test_tools_removed_from_all_subagents_fail(self) -> None:
        for field in ("tools", "disallowedTools"):
            for tool in FORBIDDEN_SUBAGENT_TOOLS + UNDOCUMENTED_LEGACY_TOOLS:
                with self.subTest(field=field, tool=tool):
                    text = (
                        f"---\nname: filtered\ndescription: test\n{field}: {tool}\n"
                        "---\nbody\n"
                    )
                    errors = validate_text(text, "filtered")
                    self.assertTrue(any(tool in error for error in errors), errors)

    def test_invalid_typed_fields_fail(self) -> None:
        errors = validate_text(
            """---
name: invalid
description: test
effort: extreme
maxTurns: 0
skills: ponytail
isolation: shared
hooks: command
tools: []
permissionMode: []
---
body
""",
            "invalid",
        )
        for field in (
            "effort",
            "maxTurns",
            "skills",
            "isolation",
            "hooks",
            "tools",
            "permissionMode",
        ):
            self.assertTrue(any(field in error for error in errors), (field, errors))

    def test_composed_claude_and_codex_role_pass(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            roles = Path(tmp) / "roles"
            role = roles / "current-agent"
            role.mkdir(parents=True)
            frontmatter, body = VALID_AGENT.split("---\n\n", 1)
            (role / "claude.frontmatter").write_text(
                frontmatter + "---\n\n", encoding="utf-8"
            )
            (role / "body.md").write_text(body, encoding="utf-8")
            (role / "codex.toml").write_text(
                'name = "current-agent"\n'
                'description = "test"\n'
                'model_reasoning_effort = "high"\n'
                'sandbox_mode = "workspace-write"\n',
                encoding="utf-8",
            )
            result = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "validate-agent-roles.py"),
                    str(roles),
                ],
                cwd=ROOT,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                check=False,
            )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)

    def test_repository_roles_pass(self) -> None:
        result = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "validate-agent-roles.py")],
            cwd=ROOT,
            encoding="utf-8",
            errors="replace",
            capture_output=True,
            check=False,
        )
        self.assertEqual(0, result.returncode, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
