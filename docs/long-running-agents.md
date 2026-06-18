# 멈추지 않는 장기 실행 AI 에이전트 — 구축·활용 리서치

> **조사 범위**: 장기 과업(long-horizon) 실행 + 오케스트레이션 런타임
> **출처**: GitHub(star 정렬, `gh` CLI 실측), GeekNews(news.hada.io), 1차 엔지니어링 블로그(Anthropic·Temporal·Cognition 등), Claude Code 소스 미러 해부
> **조사일**: 2026-06-17 (star = `gh api` 실측)

---

## Context — 왜 이 조사를

"long-running non-stopping agent"는 단일 의미가 아님. 초점 2개:

1. **장기 과업 실행** — 컨텍스트 윈도 한계 너머로 시간/일 단위 과업 지속 (컨텍스트 관리·체크포인트·resume·세션 간 메모리)
2. **오케스트레이션 런타임** — 에이전트를 살아있게 유지하는 인프라 (durable execution·상태머신·멀티에이전트 감독)

핵심 통찰 (3개 출처 교차 확인):

> **모델은 실행 사이에 잊는다. 저장소는 안 잊는다.**
> 멈추지 않는 에이전트 = 컨텍스트 윈도가 아니라 **디스크/DB에 상태를 외부화**하는 시스템.

장난감 에이전트와 프로덕션 에이전트를 가르는 단 하나의 선. 이 리포트는 그 외부화를 (A)패턴 (B)도구 랜드스케이프 (C)실전 사례 로 정리.

---

## 1. 5대 아키텍처 패턴 (멈추지 않게 만드는 메커니즘)

| # | 패턴 | 작동 원리 | 해결 문제 |
|---|------|----------|----------|
| 1 | **컨텍스트 압축(Compaction)** | 토큰 사용량 임계 도달 시 대화 히스토리를 구조화 요약으로 압축→교체. 핵심 결정·진행상태만 보존하고 윈도 비움 | 컨텍스트 윈도 한계 |
| 2 | **체크포인트 & Durable Execution** | 모든 의미있는 스텝(API콜·DB쓰기·sleep)을 영속 저장소에 journal. 크래시 시 journal replay — 완료 스텝은 캐시 결과 즉시 반환, 실패 지점부터 계속. 개발자는 선형 코드만 작성 | 크래시/재시작 생존 |
| 3 | **계층형 메모리(Tiered Memory)** | OS式 3계층: Core(컨텍스트 내 고정) / Recall(검색가능 히스토리) / Archival(벡터·그래프 DB). 에이전트가 function call로 계층 간 데이터 이동 → 가상 무한 메모리 | 세션 간 기억 상실 |
| 4 | **멀티에이전트 오케스트레이션(Supervisor)** | 중앙 supervisor가 메시지 수신→의도 분류→전문 에이전트 라우팅→복귀. **읽기 과업은 병렬화 잘됨, 쓰기 과업은 컨텍스트 분열·충돌 위험** | 단일 컨텍스트 과부하 |
| 5 | **상시가동 이벤트 루프(Always-On)** | cron이 메시지버스에 트리거 발행→에이전트 폴링/모니터 루프 진입. 무한루프 방지=하드 반복제한·루프감지(반복 tool call=stuck)·토큰 예산·외부 가드레일 | 자율 지속 + 폭주 방지 |

**패턴 1↔2 차이 (자주 혼동)**: 압축=*컨텍스트 윈도*를 살림(같은 세션 내). Durable=*프로세스*를 살림(크래시 넘어). 둘 다 필요.

**4번 논쟁 (필독)**: Anthropic은 멀티에이전트 리서치 시스템 옹호 vs Cognition "Don't Build Multi-Agents"는 쓰기 과업의 컨텍스트 분열 경고. 결론: **읽기/리서치=멀티, 쓰기/코딩=단일 우선**.

출처:
- 컨텍스트 엔지니어링 — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- 장기 에이전트 하네스 — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Durable Execution — https://temporal.io/blog/durable-execution-meets-ai-why-temporal-is-the-perfect-foundation-for-ai · https://www.restate.dev/what-is-durable-execution
- 계층 메모리 — https://www.letta.com/blog/agent-memory/
- 멀티 vs 단일 — https://cognition.ai/blog/dont-build-multi-agents

---

## 2. GitHub 도구 랜드스케이프 (star 정렬, `gh` CLI 실측)

### 두 스택으로 양분

```
멈추지 않는 에이전트
├── 오케스트레이션 런타임 (프로세스를 살림)
│   ├── Durable Execution: Temporal, Restate, DBOS, Inngest
│   └── 워크플로/로우코드:   n8n, Dify, Flowise, Trigger.dev
└── 메모리-퍼스트 (기억을 살림)
    └── Letta(MemGPT), Mem0, Cognee, Zep, Hindsight
+ 에이전트 프레임워크: LangChain, LangGraph, CrewAI, AutoGPT, MetaGPT, Swarm, Pydantic AI
+ 코딩 에이전트 (파일컨텍스트 지속): OpenHands, Cline, Aider
```

### 카테고리별 핵심 리포

| 카테고리 | 리포 | ⭐실측(06-17) | 역할 (장기실행 관점) |
|---|---|---|---|
| **Durable Execution** | temporalio/temporal | 21,017 | journal+replay, 정확한 상태 복원. "non-stopping"의 정석 |
| | inngest/inngest | 5,501 | 서버리스 durable step, retry/resume 내장 |
| | restatedev/restate | 4,020 | fault-tolerant 워크플로, 자동 크래시 복구 |
| | dbos-inc/dbos-transact-ts | 1,245 | DB-backed durable TS 워크플로, 트랜잭션 영속 |
| **워크플로/로우코드** | n8n-io/n8n | 192,890 | DAG 노드형, 400+ 연동, 크래시 복구 |
| | langgenius/dify | 145,593 | 프로덕션 agentic 워크플로, 자동 resume |
| | FlowiseAI/Flowise | 53,677 | drag-drop 에이전트 캔버스 |
| | triggerdotdev/trigger.dev | 15,377 | 백그라운드 job durability |
| **상태머신/오케스트레이션** | microsoft/autogen | 59,029 | MS 멀티에이전트, 대화형 에이전트 팀 |
| | crewAIInc/crewAI | 53,762 | role기반 팀, 위계 위임 |
| | langchain-ai/langgraph | 35,004 | 상태머신 그래프, 스텝별 checkpoint·persistence |
| | openai/openai-agents-python | 27,205 | **Swarm 정식 후속** — hand-off, 프로덕션용 |
| | openai/swarm | 21,644 | archived(실험용). → Agents SDK 사용 권장 |
| | kyegomez/swarms | 6,857 | 엔터프라이즈 위계 트리 |
| **메모리-퍼스트** | mem0ai/mem0 | 58,774 | 범용 메모리 레이어, 세션 간 영속 |
| | letta-ai/letta (MemGPT) | 23,375 | 계층 메모리 원조, 자동 recall |
| | topoteretes/cognee | 17,868 | 지식그래프+에피소드 recall |
| | vectorize-io/hindsight | 16,508 | 멀티세션 압축+experience replay |
| | getzep/zep | 4,676 | 대화형 AI 메모리 레이어 |
| **에이전트 프레임워크** | Significant-Gravitas/AutoGPT | 184,988 | 자율 plan·execute 원조 |
| | langchain-ai/langchain | 139,538 | 기반 프레임워크, 메모리/retrieval 체인 |
| | FoundationAgents/MetaGPT | 68,857 | 멀티에이전트 SW회사 시뮬 |
| | pydantic/pydantic-ai | 17,805 | 타입세이프 에이전트 |
| **코딩 에이전트** | All-Hands-AI/OpenHands | 77,475 | 이벤트소싱 상태+결정론 replay, 시간단위 비동기 |
| | cline/cline | 63,417 | 파일컨텍스트·디버깅 메모리 유지 |
| | Aider-AI/aider | 46,356 | 영속 edit 메모리, 코드베이스 진화 추적 |
| **(특이)** | thedotmack/claude-mem | 82,885 | Claude Code용 메모리 플러그인. mem0보다 star 높음(실측 확인) |

### 랜드스케이프 통찰

1. **양분화**: durable-execution(프로세스 생존) vs memory-first(기억 생존). 프로덕션은 **둘 조합** (예: Temporal/LangGraph + Mem0).
2. **워크플로 엔진이 채택 1위**: n8n(193K)·Dify(146K) 코드전용 프레임워크보다 우세 — durable + 비주얼 UI 시너지.
3. **세션 간 메모리 = 최대 미충족 영역**: 대부분 매 실행 fresh 컨텍스트 가정. Mem0·Letta만 본격 대응.
4. **프레임워크 단일승자 없음**: 선택 기준 = 에이전트 품질이 아니라 **오케스트레이션 모델**(상태머신 vs hand-off vs 위계).

---

## 3. GeekNews(news.hada.io) — 한국 개발자 커뮤니티 시각

| 주제 | URL | 핵심 |
|---|---|---|
| 루프 엔지니어링 | https://news.hada.io/topic?id=30336 | 직접 프롬프팅→자가지속 프레임워크. "모델은 잊지만 저장소는 안 잊는다" — 메모리는 디스크의 markdown/보드에 |
| OpenClaw (에이전트 OS) | https://news.hada.io/topic?id=26914 | 영속 백그라운드 런타임 + cron + 일별 markdown 로그 + 멀티채널. 에이전트를 "AI 직원"으로 |
| 코드 에이전트 오케스트라 | https://news.hada.io/topic?id=28303 | 독립 컨텍스트 멀티에이전트 비동기 조율, subagent 3x 처리량. 병목=생성→검증 이동 |
| 코딩 에이전트 6구성요소 | https://news.hada.io/topic?id=28232 | 하네스 아키텍처: repo컨텍스트·프롬프트캐싱·tool·컨텍스트관리·세션메모리·subagent. 같은 LLM도 하네스가 성능 좌우 |
| Agent Executor (Google) | https://news.hada.io/topic?id=30158 | K8s 네이티브 분산 런타임, 이벤트駆動 상태, 자동복구. `fork`(체크포인트 분기)·놓친 이벤트만 replay |
| 에이전트 거버넌스 스택 (Google) | https://news.hada.io/topic?id=28810 | 5계층: identity·registry·gateway·anomaly·dashboard. 대규모 fleet 통제 |
| OpenWorkflow | https://news.hada.io/topic?id=24647 | Postgres 1개로 durable 워크플로, memoize 중복방지, 장시간 pause가 worker 안 점유 |
| Entire 플랫폼 | https://news.hada.io/topic?id=26583 | 체크포인트=전체 세션(대화·파일변경·토큰·tool call) 캡처+Git커밋 연결, re-prompt 없이 resume |
| Hermes Agent | https://news.hada.io/topic?id=28101 | 경험에서 스킬 자동생성, 재시작 시 세션 컨텍스트 replay |
| DeerFlow (ByteDance) | https://news.hada.io/topic?id=20886 | 멀티에이전트 deep research(planner·researcher·reporter), 격리 컨텍스트+Docker 샌드박스 |
| 에이전트 경제 | https://news.hada.io/topic?id=29171 | chat AI(22-25)→자율실행 에이전트(26+) 구조전환. MCP로 tool콜·상태유지가 SaaS 모델 침식 |
| 에이전트 프로토콜 가이드 | https://news.hada.io/topic?id=27636 | MCP·A2A·UCP·AP2·A2UI·AG-UI — 멀티에이전트 오케스트레이션 기반 |

> ⚠ topic ID는 에이전트가 WebFetch로 수집. 인용 전 1~2개 클릭 검증 권장.

**한국 커뮤니티 3대 테마**:
1. **영속성은 필수** — 메모리를 markdown/DB/Git브랜치로 외부화 (컨텍스트 윈도 신뢰 금지)
2. **거버넌스·오케스트레이션 > 순수 성능** — fleet 통제(Google 5계층)·조율(오케스트라 팀)에 집중, 병목은 검증/품질게이트
3. **모듈형 런타임이 새 비즈니스 모델 견인** — MCP/A2A·체크포인트 분기·스킬 시스템 = 조합형 컴포넌트

---

## 4. 실전 사례 (배포·문서화된 것)

| 사례 | 유형 | 핵심 | 출처 |
|---|---|---|---|
| **Project Vend** (Anthropic) | 자율 비즈니스 | Claude가 자판기 사업 운영(재고·가격·CRM), 3개 도시, 한 달+ 지속. long-horizon 의사결정 실증(+사회공학 취약점) | https://www.anthropic.com/research/project-vend-2 |
| **Claude Code 장기세션** | 코딩 | 30시간+ 멀티스텝 코딩, 컨텍스트 압축+진행파일+git으로 윈도 리셋 생존 | https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents |
| **Devin** (Cognition) | 코딩 | 격리 VM(쉘·브라우저·에디터)+영속 메모리(코드 스냅샷·replay 타임라인), 요구→PR 자동 | https://devin.ai/agents101 |
| **OpenHands** | 코딩 | "agents that don't stop when you do" — 이벤트소싱+결정론 replay, 시간단위 비동기 | https://www.openhands.dev/ |
| **DeerFlow 2.0** (ByteDance) | Deep Research | 멀티에이전트 리서치 하네스, 시간단위 과업, 웹검색+Python+크롤링 | https://news.hada.io/topic?id=20886 |
| **Mem0 + LangGraph** | Deep Research | 세션 간 메모리+엔티티 링킹으로 중복쿼리 방지, 풀컨텍스트 대비 91% 레이턴시↓ | https://www.digitalocean.com/community/tutorials/langgraph-mem0-integration-long-term-ai-memory |
| **OpenClaw** | 상시 운영 | 30분마다 이메일 체크·일일 SNS 포스팅·멀티채널, 무인 cron | https://news.hada.io/topic?id=26914 |
| **24/7 고객지원** | 운영 | RAG 기반 라운드클락, 응답 4.2분(사람)→<8초, 복잡건만 사람 에스컬레이션 | https://www.outrightcrm.com/blog/ai-agents-for-customer-support/ |

벤치마크: **SWE-Bench Pro** (1,865 과업/41 repo) — 멀티파일 패치·시간단위 long-horizon 코딩 측정. https://arxiv.org/pdf/2509.16941

---

## 5. 실천 가이드 — 무엇을 골라 어떻게 조합?

| 필요 | 1순위 도구 | 이유 | 주의 |
|---|---|---|---|
| 크래시 복구·resume | Temporal / Restate | 트랜잭션 durability, 정확한 상태 replay | 인프라 필요, embedded 아님 |
| 세션 간 시맨틱 메모리 | Mem0 / Letta | 윈도 한계 넘는 cross-session recall | 외부 DB+LLM콜 오버헤드 |
| 멀티에이전트 조율 | OpenAI Agents SDK / CrewAI | hand-off+위임, 메모리 공유 | 쓰기 과업은 단일 우선(§1.4) |
| durable 서버리스 | Inngest / Trigger.dev | resumable job, retry 내장 | 실행 과금 |
| 비주얼+durable(로우코드) | Dify / n8n | 노코드 조합+워크플로 durability | 세밀제어↓, 무거움 |
| 상태그래프 | LangGraph | 노드별 checkpoint, 메모리 흐름 가시화 | Python 한정, LangChain 종속 |

**최소 프로덕션 조합 권장**: 오케스트레이션(LangGraph or Temporal) + 메모리(Mem0 or Letta) + 가드레일(하드 반복제한·토큰예산·HITL 체크포인트). 디스크 외부화 = 비협상.

---

## 6. Claude Code Compaction / Auto-Compaction 다루기

> **조사 경로 (2단계)**: 이 기기 Claude Code = 컴파일 바이너리(`claude.exe` 235MB, JS 소스 없음) → 로컬 grep 불가. **2차 시도에서 GitHub 소스 미러(`chauncygu/collection-claude-code-source-code`, npm 2.1.179) 확보 → 실제 `src/services/compact/*.ts` 코드 실측** = ground truth. 신뢰도: 🟢번들미러실측 / 🟡공식문서 / 🔴2차출처(gist·issue, 미검증·일부 반박됨).

### 6.1 이 기기에서 실측된 것 🟢

`~/.claude/settings.json` 에 **auto-compact 설정 없음**. 현재 설정된 env (실측):
```json
{ "env": {
  "CLAUDE_CODE_SUBAGENT_MODEL": "haiku",
  "MAX_THINKING_TOKENS": "10000",
  "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
  "ENABLE_PROMPT_CACHING_1H": "1",
  "FORCE_PROMPT_CACHING_5M": "0",
  "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING": "1"
}}
```

### 6.2 진짜 메커니즘 — 번들 소스 실측 🟢

> **소스**: GitHub 미러 `chauncygu/collection-claude-code-source-code` (npm **2.1.179**, `src/services/compact/*.ts`). ⚠ 공식 Anthropic repo 아닌 **3자 미러/디obfuscate 재구성** — 동작·문자열 일치도 높아 신뢰하나 100% 공식 아님. 일부(cached MC·budget) ant-only 파일은 미러에 없음(404).

**4중 압축. 핵심 반전: 4개 중 3개가 GrowthBook 기본 OFF.** "무음 상시 작동"이라는 통념은 **틀림**.

| 메커니즘 | 파일:행 | 트리거 | 동작 | **기본상태** | 제어 |
|---|---|---|---|---|---|
| Time-based MC | `microCompact.ts:422` | 마지막 assistant 후 gap **>60분** | 최근 5개 빼고 tool결과→`[Old tool result content cleared]` | **OFF** (`tengu_slate_heron.enabled=false`) | GrowthBook |
| Cached MC | `microCompact.ts:305`(ant-only stub) | count 임계 | `cache_edits`로 서버캐시만 삭제(로컬 messages 보존) | **OFF** (ant gate) | GrowthBook |
| Session memory compact | `sessionMemoryCompact.ts:57` | 토큰 임계 | 오래된 msg prune+디스크 요약(`~/.claude/session-memory/`) | **OFF** (`tengu_session_memory`+`tengu_sm_compact`=false) | GrowthBook / `EN/DISABLE_CLAUDE_CODE_SM_COMPACT` env |
| **Autocompact** | `autoCompact.ts:60` | 토큰 > (window − **13,000**) | 전체 대화 요약 재작성 | **ON** (유일 상시) | `DISABLE_AUTO_COMPACT`·`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` |

**핵심 사실**:
- Time-based MC: gap **>60분**일 때만 (앱 오래 놔둔 경우). 최근 **5개** tool결과 유지. 대상 8툴만(`FILE_READ·BASH·GREP·GLOB·WEB_SEARCH·WEB_FETCH·FILE_EDIT·FILE_WRITE`) — Task·MCP 제외.
- SM compact: 코드 기본 minTokens **10K**/maxTokens **40K** (원격 override 2K/20K 관측). 그러나 **기본 OFF**.
- Autocompact 임계 = "~95%"가 아니라 **윈도−13K 토큰** (`AUTOCOMPACT_BUFFER_TOKENS=13_000`).
- microcompact "항상 무음 작동" = **반박됨**. 기본 꺼짐. 단 GrowthBook 서버플래그라 **Anthropic이 언제든 켤 수 있음** — 그게 진짜 리스크.

### 6.3 실제 env var (번들 `process.env` 실측) 🟢

| 변수 | 효과 | 실재? |
|---|---|---|
| `DISABLE_COMPACT` | auto+manual 전부 차단 | ✅ |
| `DISABLE_AUTO_COMPACT` | autocompact만 차단, `/compact` 유지 | ✅ |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=N` | 윈도 N%서 트리거 | ✅ (line 79) |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | 윈도 크기 override | ✅ |
| `CLAUDE_CODE_BLOCKING_LIMIT_OVERRIDE` | manual hard limit override | ✅ |
| `ENABLE/DISABLE_CLAUDE_CODE_SM_COMPACT` | SM compact 강제 on/off | ✅ |
| `CLAUDE_INTERNAL_FC_OVERRIDES` | 플래그 JSON override (ant) | ✅ |
| ~~`DISABLE_MICROCOMPACT`~~ | — | ❌ 번들에 없음 |
| ~~`CLAUDE_CODE_MAX_CONTEXT_TOKENS`~~ | — | ❌ (→`AUTO_COMPACT_WINDOW` 사용) |

> 참고: `MAX_THINKING_TOKENS`(이 기기 설정됨)는 실재하나 **compaction과 무관**(thinking 예산).

### 6.4 실제 요약 프롬프트 🟢 (`prompt.ts`)

3변형: `BASE_COMPACT_PROMPT`(전체) / `PARTIAL`(최근만) / `PARTIAL_UP_TO`(캐시분할 prefix). 9섹션 강제:
> 1.Primary Request·Intent 2.Key Technical Concepts 3.Files·Code 4.Errors·fixes 5.Problem Solving 6.**All user messages**(tool결과 아닌 전부) 7.Pending Tasks 8.Current Work 9.Optional Next Step

`<analysis>`(품질용 scratchpad, 출력시 제거) + `<summary>`(보존) 블록. `NO_TOOLS_PREAMBLE`로 요약 턴엔 tool 호출 금지. **→ 커스텀 `/compact` 지시는 이 9섹션에 얹힘.**

### 6.5 다루는 법 — 실전

**A. CONTEXT.md/MEMORY.md 디스크 외부화 (🟢 유일 확실)** — 압축이 뭘 지우든 디스크는 안 지움. §7 확장 레이아웃 참조. 압축 무력화에 의존 말고 **상태를 컨텍스트 밖에 둠**이 정답.

**B. 선제 `/compact` 커스텀 지시 (🟡 안전)**
```
/compact
보존: 완료 과업+이유 / 수정파일+현재상태 / 결정 / 실패+교훈 / 블로커 / 다음 단계
폐기: 루틴 출력 / 파일 리스팅 / 디버그 로그
```
(위 9섹션 구조에 주입됨)

**C. env 튜닝 (🟢 번들 확인)**
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=70~85` — 기본(window−13K, ≈최대치)보다 일찍 압축해 과업 중간 중단 회피
- 완전 끄려면 `DISABLE_AUTO_COMPACT=true` (단 윈도 꽉 차면 결국 막힘). `DISABLE_COMPACT`=manual까지 차단
- microcompact는 기본 OFF라 별도 끌 필요 없음

**D. `/clear` vs `/compact`**: clear=전체 wipe(무관 과업), compact=요약 유지(핸드오프).

### 6.6 미검증/한계 🔴

1. **cached MC 본체** = ant-only(`cachedMicrocompact.ts` 404). 미러엔 stub만.
2. **budget 플래그**(`tengu_hawthorn_window`=200K, `tengu_pewter_kestrel` per-tool cap) — 분석문서 주장이나 공개소스 미확인. ant-only/서버측 가능.
3. **미러 신뢰성** — 디obfuscate 재구성이라 file:line은 미러 기준. 자기 설치본과 버전 다르면 상이.
4. GrowthBook 메모리 내 갱신 타이밍 = 네트워크 인터셉트 없이 미확인.

**출처**: 🟢 미러 `chauncygu/collection-claude-code-source-code` (npm 2.1.179) · 🔴 GitHub issues anthropics/claude-code #42542·#42394·#7176

---

## 7. 확장성 — 시간 지나도 관리되는 메모리

> **문제**: 단일 CONTEXT.md를 무한 append = **선형 증가**. 재읽기 비용↑·컨텍스트 bloat·stale 누적. "컨텍스트는 RAM이지 저장소 아님" — 큰 윈도가 답 아니라 **아키텍처 분리**가 답.
> ⚠ 신뢰도: 아래 패턴의 일부 arxiv 출처는 미검증(🔴). 단 패턴 자체는 정립 CS(LSM-tree·RAG·event-sourcing)라 유효. 🟡=공식문서 신뢰.

### 7.1 monolithic 핸드오프 실패 모드 (🟡 다수 공식)

| 실패 | 원인 | 증상 |
|---|---|---|
| Context rot | 신호:잡음 비 하락 | 턴 늘수록 초기 지시 위반 (compliance 73%@턴5→33%@턴16) |
| Lost-in-the-middle | attention이 앞/끝 집중 | 중간 30~50% 내용 무시 |
| Token bloat | tool결과 선형 누적 | 26K토큰/17s → 7K/1.4s (정리 시) |
| 행동 drift | 신규가 구지시 덮음, dedup 없음 | 이전 제약 망각, 비결정적 |

### 7.2 bounded 7패턴 (핵심 = 읽기/컨텍스트 비용을 총량과 분리)

| # | 패턴 | 비용 상한 메커니즘 | 도구/출처 | 신뢰 |
|---|---|---|---|---|
| 1 | **인덱스+leaf lazy load** | 작은 인덱스(1줄/항목) 항상로드 + 디테일 on-demand. 읽기 O(인덱스)+O(k) | Claude Code auto-memory(`MEMORY.md`+leaf), Cognee | 🟡 |
| 2 | **hot/cold 계층** | in-context 상수크기 + 외부 archive, promotion/eviction | Letta core/recall/archival, Anthropic Memory Tool | 🟡 |
| 3 | **append-log + 주기 rollup** | snapshot 후 truncate. replay O(snapshot 이후) | event sourcing, LSM-tree(RocksDB), Claude Compaction | 🟡 |
| 4 | **RAG 검색(load-all 회피)** | embed→top-k 검색. 읽기 O(log n), 총량 무관 | Mem0(consolidate+dedup, 저장 60%↓), Zep, 벡터DB | 🟡 |
| 5 | **bounded 재귀요약** | 고정크기 요약 재귀 갱신. in-context O(1) | recursive summarization | 🔴 |
| 6 | **샤딩(topic/date/component)** | 관련 shard만 로드. 검색 O(k·log) k≪N | topic 분할, MoE 라우팅 | 🔴 |
| 7 | **GC/prune/TTL/dedup** | obsolete·중복·만료 능동 삭제. 단조증가 방지 | Mem0 prune, MongoDB TTL+LangGraph | 🟡/🔵 |

### 7.3 권장 — Claude Code 장기 워크플로 레이아웃

**조합 = 패턴 1+2+3+7**. Claude Code auto-memory가 이미 패턴1 사용 중 → 확장.

```
.claude/
├── MEMORY.md                  # 인덱스, 항상로드, ≤500토큰 (1줄/항목)
└── memories/
    ├── session_log/<date>.md  # 세션 디테일, lazy (별개 work stream마다)
    ├── decisions/*.md         # 결정·핀·블로커 (durable)
    ├── reference/*.md         # 파일위치·명령 cheatsheet
    └── archive/<YYYY-MM>/     # 월별 rollup (압축됨)
```

**라이프사이클(상한 트리거)**:
| 지표 | 액션 |
|---|---|
| MEMORY.md >500토큰 | decisions/session 인덱스 분리 |
| session_log >8파일 | 오래된 월 archive, 현재+직전월만 활성 |
| 단일 세션 >5KB | subtopic 분할 |
| memories/ >20MB | 벡터 임베딩+검색 도입(패턴4) |

**월별 rollup**: 지난달 세션→durable 사실만 추출→`archive/<월>/rollup.md`(≤500토큰)→원본 세션 삭제/이동→인덱스가 rollup 가리킴.

**서브에이전트 핸드오프**: CONTEXT.md 전체 복사 ❌. "MEMORY.md 먼저 읽어라 + 관련 session 파일 링크" 만 전달, 서브는 1~2KB 요약 반환.

**Anthropic 도구 연계** (🟡, 버전문자열 미검증): Memory Tool(`memory_*` — `.claude/memories/` 노트) + Context Editing(`clear_tool_uses_*` — 오래된 tool read 정리) + Compaction(세션 ~15K 초과 시 요약+archive). CLAUDE.md hook: "요청 처리 전 MEMORY.md·블로커 먼저 읽기".

> **핵심 한 줄**: monolithic 금지. **항상로드(작은 인덱스) / lazy(디테일) / 압축(rollup) / 삭제(GC)** 4분리 = 시간 무관 상수 비용.

---

## 검증(Verification) — 리포트 신뢰도 확인법

리서치 결과물이므로 코드 테스트 대신 **출처 검증**:

1. **star 수치**: ✅ `gh api` 실측 완료(2026-06-17). claude-mem 82,885·swarm 21,644 모두 실측 확인. swarm은 archived → openai-agents-python(27,205)이 정식 후속
2. **GeekNews URL**: topic ID 1~2개 브라우저 클릭, 제목 일치 확인
3. **1차 출처**: Anthropic·Temporal·Cognition 블로그 URL 직접 열람 (가장 신뢰)
4. **Claude Code §6**: 자기 설치본에서 `/compact` 동작·env 테스트로 동작 관찰 (미러는 npm 2.1.179 기준)
5. **§7 arxiv 출처**: 일부 미검증(🔴), 패턴 원리는 정립 CS라 별도 검증 불요
