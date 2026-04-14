# Everything Claude Code (ECC) 설치 가이드

ECC는 두 가지 설치 방법이 **상호 보완적**으로 설계되어 있다. 공식 README에 "plugins cannot distribute rules automatically", "complementary; neither approach makes the other obsolete"라고 명시.

## 각 설치 방법이 제공하는 것

### 플러그인 (`/plugin install ecc@ecc`)

`plugin.json`에 선언된 항목만 `ecc:` prefix로 Claude Code 런타임에 로드:

- Agents 38개 (`ecc:architect`, `ecc:code-reviewer` 등)
- Skills 181개 (`ecc:code-review`, `ecc:plan` 등)
- Commands 79개 (`ecc:build-fix`, `ecc:verify` 등)

**제공하지 않는 것:** Rules, Hooks, Scripts, MCP configs

### install.ps1 (`--profile full`)

`install-modules.json` 매니페스트 기준 20개 모듈 601개 파일을 `~/.claude/`에 복사:

| 모듈 | 대상 경로 | 플러그인과 중복? |
|------|-----------|:---:|
| rules-core | `~/.claude/rules/` (15개 언어) | 고유 |
| hooks-runtime | `~/.claude/hooks/`, `scripts/hooks/` (34개), `scripts/lib/` (20+개) | 고유 |
| platform-configs | `.claude-plugin/`, `mcp-configs/` 등 | 고유 |
| agents-core | `~/.claude/.agents/`, `AGENTS.md` | 부분 중복 |
| commands-core | `~/.claude/commands/` (79개) | **완전 중복** |
| skill 모듈 15개 | `~/.claude/skills/` (149개) | **완전 중복** |

## 중복 없는 권장 설치 방법

```powershell
# 1. 플러그인 → agents, skills, commands (ecc: prefix)
/plugin marketplace add https://github.com/affaan-m/everything-claude-code
/plugin install ecc@ecc

# 2. 플러그인이 제공하지 않는 고유 모듈만 설치
cd everything-claude-code
.\install.ps1 --modules rules-core,hooks-runtime,platform-configs
```

`--profile full`로 실행하면 commands-core와 skill 모듈이 prefix 없는 버전으로 중복 설치된다. `--modules`로 고유 모듈만 지정하면 중복이 발생하지 않는다.

## 업데이트

- 플러그인 업데이트 (`/plugin update ecc@ecc`): skills/commands/agents만 갱신
- rules/hooks 업데이트 필요 시: `.\install.ps1 --modules rules-core,hooks-runtime,platform-configs` 재실행
- `--profile full` 재실행 시 중복 재발하므로 피할 것
