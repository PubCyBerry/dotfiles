# 세션 기억 체계 재설계: 프로젝트 밖 메모리 저장소 + /handoff + mempalace

## 컨텍스트

전역 규칙이 CONTEXT.md를 세션 인계 파일로 쓰게 하지만 교체/아카이브 정책이 없어 인계 섹션이 무한 append됨 (konan147 SO101-Sim2Real **1,594줄/209KB**·인계 50+개, Windows LeRobot-VLA **1,172줄/147KB**·30개. 세션당 8~145회 재참조로 컨텍스트 잠식). `/compact`는 유실이 심해 기피 → "인계 파일 + 새 세션" 패턴 자체는 유지하되 저장 구조를 바꿔야 함.

사용자가 지적한 repo 내 파일 방식의 구조적 결함 4가지 (worklog도 동일 해당):
1. 커밋하면 공개 시 노출 위험 / 안 하면 동기화 불가
2. worktree 병행 작업 시 작업별 분류 없이 쌓이고 머지 처리 곤란
3. 작업이 길어지면 파일 증식
4. 암묵지(예: SO-101 ee-pose ≠ 그리퍼 중심점이라 큐브 윗면을 찌름, URDF 변환 시 z축 90도 회전)를 인계 로그와 분리 관리하기 어려움

**조사로 확정된 사실**: 소규모 프로젝트 5개는 auto-memory 토픽 파일(13~31줄)만으로 잘 운영됨. LeRobot-VLA의 memory/ 6개 토픽 파일이 정확히 4번 암묵지 패턴의 성공 사례. 비대화는 "인계 append" 정책에서만 발생.

**사용자 결정**:
- 머신 간 동기화 불요 (담당 작업 분리, 이어받기 드묾) → 메모리 저장소는 머신 로컬
- 파일 최소화: worklog 파일 폐지, 과거 이력은 검색 + git 히스토리로
- 외부 메모리 도구 도입 의향, 단 **과금 절대 불가**

**4종 비교 결론** (mem0, claude-mem, mempalace, agentmemory 소스 직접 분석):

| | 무과금 | 데몬 | Windows | 결격 |
|---|---|---|---|---|
| **mempalace v3.4.0** | **기본값** (로컬 ONNX 임베딩+ChromaDB, LLM 전부 opt-in) | **없음** | 전용 CI job, 수정 30+건 | 없음 → **채택** |
| claude-mem | OAuth 구독 quota 소모 (압축에 LLM 필수) | Bun worker 상주 | 지원 | quota 소모 + 주입이 handoff 훅과 중복 |
| agentmemory | 로컬 임베딩+noop 가능 | Rust 엔진 상시 (포트 4개) | connect는 WSL2 권장 | 데몬 필수, v0.9.x churn |
| mem0 | Ollama 직접 설치해야 가능 (기본 OpenAI 키) | 사실상 Ollama | 훅 WSL2 권장 | 핵심 가치(LLM 추출)=과금 지점 |

mempalace 채택 이유: verbatim 저장(요약·압축 없음 = quota 0 + 유실 0), Stop/PreCompact 훅 자동 캡처, 시맨틱+BM25 하이브리드 검색.

## 아키텍처

```text
[Tier 1 — 메모리 저장소: 프로젝트 repo 밖, 머신 로컬, git init만]
~/agent-memory/
└── <repo-key>/                  # 예: SO101-Sim2Real
    ├── knowledge/
    │   ├── INDEX.md             # 토픽 한 줄 요약 목록 (≤50줄, 세션 시작 시 자동 주입)
    │   └── <topic>.md           # 암묵지 상세 (필요할 때만 Read)
    ├── handoff/
    │   └── <branch>.md          # 브랜치/worktree별 인계. 항상 교체식, ≤100줄
    └── archive/                 # 마이그레이션 등 일회성 보관물

[Tier 2 — 에피소드 검색: mempalace 플러그인 (체험 도입)]
~/.mempalace/                    # ChromaDB(SQLite 기반) + 지식그래프. 로컬 ONNX 임베딩, API 0
Stop/PreCompact 훅(플러그인 소유)  # 대화 verbatim 자동 캡처
/mempalace:search, MCP search    # 시맨틱+BM25 하이브리드 검색

[Tier 3 — 운영 패턴]
마일스톤 → /handoff → 새 세션 사이클 (컴팩션 의존 탈피). 무거운 탐색은 서브에이전트.
```

**사용자 암기 부담 0 원칙** — 동작 전부 자동 트리거:

| 시점 | 행위자 | 자동 동작 |
|---|---|---|
| 세션 시작 | memory-inject 훅 | knowledge INDEX 항상 + handoff 조건부 주입 |
| 마일스톤/중단 직전 | 에이전트 (global.md 규칙) | handoff 교체 갱신 + 암묵지 knowledge 승격 + 커밋 |
| handoff 비대·append 시도 | handoff-guard 훅 | 에이전트에 경고 → /handoff 절차 수행 |
| 과거 이력 질문 ("그때 어떻게…") | mempalace skill 자동 트리거 | 시맨틱 검색 |
| 기존 CONTEXT.md 인계 발견 | /handoff 마이그레이션 모드 | 일괄 이전 |

**설계 메모**:
- repo-key: `git rev-parse --path-format=absolute --git-common-dir` → main repo basename. worktree 전부가 같은 key → knowledge 공유, handoff만 브랜치별 분리. non-git은 cwd basename
- handoff mtime 7일 초과: 전문 대신 한 줄 포인터만 주입 ("오래된 인계 있음: <경로>") → 색다른/가벼운 세션은 자연 필터
- 프로젝트 repo 내 CONTEXT.md: 도메인 문서 전용으로 회귀, 작업 인계 기록 금지
- 이력: ~/agent-memory에 git commit → 과거 인계는 `git -C ~/agent-memory log -p`로

## 구현 대상 (한 세션 분량)

### 1. `config/agents/global.md` — `## 작업 지속성` 섹션 교체

```markdown
## 작업 지속성
- 여러 단계가 있거나 파일을 수정하는 작업은 `~/agent-memory/<repo>/handoff/<branch>.md`를 세션 인계 파일로 사용한다. repo는 git main repo 이름(worktree 공통), branch는 현재 브랜치. git이 아니면 디렉터리 이름과 `main`을 쓴다.
- 작업 시작 시 해당 handoff 파일이 있으면 먼저 읽는다 (Claude Code는 훅이 자동 주입).
- handoff는 항상 전체 교체로 갱신하고 100줄 이하로 유지한다. 섹션을 추가(append)하지 않는다. 프로젝트 repo 안에는 인계 기록을 만들지 않는다.
- 여러 세션에서 재사용할 지식(트러블슈팅 해법, 하드웨어 특성, 환경 제약, 빌드/실행 명령)은 인계가 아니라 `~/agent-memory/<repo>/knowledge/<topic>.md`에 쓰고 `INDEX.md`에 한 줄 요약을 등록한다. 프로젝트에 공유해도 되는 결정은 repo의 `docs/adr/`에 기록한다.
- 기록 항목: 목표, 현재 상태, 완료한 일, 남은 일, 변경한 파일, 검증 결과, 결정, 가정, 블로커, 다음에 실행할 명령.
- 갱신 시점: 계획 확정, 의미 있는 파일 수정, 테스트/검증 완료, 블로커 발견, 중단 직전. 갱신 후 `~/agent-memory`에 git commit 한다.
- 과거 작업 이력이 궁금하면 mempalace 검색(Claude Code) 또는 `git -C ~/agent-memory log -p`.
- 비밀값, 토큰, 개인정보, 긴 로그 전문은 기록하지 않는다. 위치와 요약만 남긴다.
- 장시간 자율 작업은 컴팩션에 의존하지 말고 마일스톤 단위로 인계를 갱신한 뒤 새 세션에서 이어받는다. 무거운 탐색·로그 분석은 서브에이전트에 위임한다.
- 단발성 조회처럼 이어받을 상태가 없는 작업은 생략할 수 있다.
```

### 2. `config/claude/hooks/memory-inject.sh` (신규)

SessionStart(matcher `""`) 훅. 조건부 주입:
- `knowledge/INDEX.md`: 있으면 항상
- `handoff/<branch>.md`: 있으면 주입, mtime 7일 초과 시 한 줄 포인터만
- 파일 없으면 exit 0

구현 시 확인: matcher `""`가 compact source에도 발동하는지, SessionStart stdout 주입 형식.

### 3. `config/claude/hooks/handoff-guard.sh` (신규)

PostToolUse(matcher `Write|Edit`) 훅. `agent-memory/*/handoff/` 100줄 초과 또는 `knowledge/INDEX.md` 50줄 초과 시 exit 2 + 경고.

구현 시 확인: PostToolUse stdin 스키마(`tool_input.file_path`), exit 2 피드백 동작.

### 4. `config/claude/settings.json` 훅 등록

```json
"SessionStart": [
  { "matcher": "", "hooks": [
    { "type": "command", "command": "bash ~/.claude/hooks/temporal-context.sh" },
    { "type": "command", "command": "bash ~/.claude/hooks/memory-inject.sh" }
  ]}
],
"PostToolUse": [
  { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/handoff-guard.sh" }] }
]
```

### 5. `config/claude/skills/handoff/SKILL.md` (신규)

트리거: "인계", "handoff", "세션 마무리", 가드 경고 수신.
절차: ① repo-key+branch 해석 → ② handoff 파일 전체 교체(≤100줄) → ③ 재사용 지식 knowledge/ 승격 + INDEX.md 등록 → ④ 끝난 브랜치 handoff 삭제 → ⑤ `git -C ~/agent-memory add -A && commit`.

**마이그레이션 모드**: cwd CONTEXT.md에 `## 작업 인계` 섹션 발견 시 → archive/ 보존, knowledge/ 추출, handoff 변환, repo CONTEXT.md에서 인계 섹션 제거.

### 6. mempalace 플러그인 (체험)

```bash
claude plugin marketplace add MemPalace/mempalace
claude plugin install --scope user mempalace
# Claude Code 안에서: /mempalace:init
```

- 기본값 = 무과금: 로컬 ONNX 임베딩 + ChromaDB. LLM 기능 비활성.
- install 스크립트에 넣지 않음(체험). 1~2주 SO101 작업 병행 후 합격/불합격 판정.
- 불합격 시: `claude plugin uninstall mempalace` + `~/.mempalace/` 삭제 → fallback: DIY FTS5 /recall 스킬

### 7. install 스크립트 — ~/agent-memory 초기화

멱등 단계: `~/agent-memory` 없으면 `git init` + 빈 README.

### 8. 문서 갱신

- `AGENTS.md`: 아키텍처 트리·실행 순서에 훅 2개, handoff 스킬, agent-memory 초기화 반영
- `docs/agents/domain.md`: CONTEXT.md = 도메인 문서 전용 명시
- `docs/ai-agents.md`: 메모리 저장소 구조, /handoff, mempalace 체험 도입
- `docs/uninstall.md`: 훅 2개·handoff 스킬 제거, `~/agent-memory`(보존)·`~/.mempalace/`(삭제) 구분
- `.gitignore`: `ref_repos/` 추가

## 명시적으로 하지 않는 것

- claude-mem / agentmemory / mem0: 탈락
- mempalace LLM 기능(rerank, 분류): 비활성
- DIY /recall: mempalace 불합격 시만 fallback
- 메모리 저장소 remote 동기화: 머신별 독립 (나중에 필요하면 추가)
- worklog 파일: 폐지
- PreCompact 자체 훅, auto-compact 임계: 불요

## 검증

1. `jq empty config/claude/settings.json`, `bash -n` 훅 2개
2. worktree에서 `bash memory-inject.sh` — repo key 해석 확인, 101줄 더미로 guard exit 2
3. `pwsh -File install.ps1` 멱등 재실행 → `~/.claude/hooks/`, `~/.claude/skills/handoff/`, `~/agent-memory` git repo 확인
4. mempalace: `/mempalace:search feetech` 캡처·검색 확인, API 키 없이 정상 동작 = 무과금 증명
5. dotfiles에서 /handoff → handoff 파일 + commit 확인. /compact 1회로 inject 훅 재주입 확인

## 후속 (저장소 밖)

1. **konan147**: git pull + install.sh 재실행. mempalace는 Windows 합격 후
2. **마이그레이션** (각 프로젝트에서 /handoff 1회):
   - Windows SO101-LeRobot-VLA (1,172줄) — auto-memory 토픽 6개도 knowledge/로
   - konan147 SO101-Sim2Real (1,594줄) — North Star는 CONTEXT.md 잔류, ee-pose/URDF는 knowledge/로
