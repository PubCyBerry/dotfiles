# GitHub Actions 개요

GitHub Actions는 저장소의 `.github/workflows/` 디렉토리에 YAML 파일을 두면 GitHub 서버에서 자동으로 실행되는 CI/CD 플랫폼이다.

---

## Workflow 구조

```yaml
name: 워크플로우 이름        # Actions 탭에 표시되는 이름

on: ...                     # 트리거 (언제 실행할지)

jobs:
  job-이름:
    runs-on: ubuntu-24.04   # 실행 환경
    steps:
      - uses: actions/checkout@v4   # 외부 Action 재사용
      - run: echo "hello"           # 직접 셸 명령 실행
```

### 핵심 키워드

| 키 | 역할 |
|---|---|
| `on` | 트리거 이벤트 정의 |
| `jobs` | 병렬 또는 순차 실행 단위 |
| `steps` | job 내 순서대로 실행되는 개별 작업 |
| `uses` | 공개된 Action을 재사용 (marketplace) |
| `run` | 셸 명령어 직접 실행 |
| `needs` | job 간 의존성 선언 (순차 실행) |
| `if` | 조건부 실행 |
| `env` | 환경변수 설정 |
| `with` | Action에 파라미터 전달 |

---

## 트리거 유형

```yaml
on:
  # 브랜치 push 시
  push:
    branches: [master]
    paths:
      - "install.sh"       # 특정 파일 변경 시만 실행

  # PR 이벤트 시
  pull_request:
    types: [opened, synchronize]
    paths:
      - "install.sh"

  # 스케줄 (cron 형식)
  schedule:
    - cron: "0 10 * * 1"  # 매주 월요일 10:00 UTC

  # 수동 실행 (Actions 탭 → Run workflow)
  workflow_dispatch:
```

cron 형식: `분 시 일 월 요일` (0=일요일, 1=월요일, ..., 6=토요일)

---

## 자주 쓰는 Actions

### actions/checkout@v4

저장소 코드를 runner에 체크아웃한다. 대부분의 workflow 첫 step에서 사용.

```yaml
- uses: actions/checkout@v4
```

### actions/cache@v4

파일/디렉토리를 캐싱해 재실행 시 속도를 높인다.

```yaml
- uses: actions/cache@v4
  with:
    path: /var/cache/apt/archives
    key: apt-ubuntu-24.04-${{ hashFiles('manifests/apt.txt') }}
    restore-keys: apt-ubuntu-24.04-
```

- `key`: 정확히 일치하면 캐시 hit
- `restore-keys`: 접두사 매칭으로 부분 hit (캐시 miss 시 fallback)
- `hashFiles()`: 파일 내용이 바뀌면 다른 키 생성 → 자동 무효화

### actions/upload-artifact@v4

파일을 아티팩트로 저장해 workflow 실행 후 다운로드 가능하게 한다.

```yaml
- uses: actions/upload-artifact@v4
  if: always()              # 실패해도 아티팩트 업로드
  with:
    name: phase1-versions
    path: /tmp/phase1.txt
    retention-days: 7
```

---

## 환경변수와 Secrets

```yaml
env:
  MY_VAR: "값"              # 일반 환경변수 (로그에 노출됨)

# secrets는 Settings → Secrets and variables → Actions에서 설정
env:
  TOKEN: ${{ secrets.MY_SECRET }}   # 마스킹됨, 로그에 *** 표시
```

`GITHUB_TOKEN`은 GitHub이 자동으로 주입하는 토큰이다. 별도 설정 없이 `${{ secrets.GITHUB_TOKEN }}`으로 사용 가능하며, GitHub API 인증에 활용하면 rate limit이 60→5000 req/hr로 늘어난다.

---

## Job 의존성과 조건부 실행

```yaml
jobs:
  build:
    runs-on: ubuntu-24.04
    steps: ...

  test:
    needs: build          # build가 성공해야 시작
    runs-on: ubuntu-24.04
    steps: ...

  summary:
    needs: [build, test]
    if: always()          # 앞 job이 실패해도 반드시 실행
    runs-on: ubuntu-24.04
    steps:
      - run: echo "build=${{ needs.build.result }}, test=${{ needs.test.result }}"
```

`needs` 없이 정의된 job들은 병렬로 실행된다.

---

## Concurrency 제어

같은 브랜치에서 여러 실행이 겹칠 때 이전 실행을 취소한다.

```yaml
concurrency:
  group: pr-gate-${{ github.ref }}
  cancel-in-progress: true
```

PR 브랜치에서 연속 push 시 불필요한 실행을 자동 취소해 비용을 줄인다.

---

## ubuntu-24.04 runner 특징

GitHub-hosted runner는 매번 새 가상 머신에서 시작하므로 이전 실행 상태가 남지 않는다.

| 항목 | 값 |
|---|---|
| 홈 디렉토리 | `/home/runner` |
| sudo | 패스워드 없이 사용 가능 |
| 기본 설치 도구 | git, curl, jq, Node.js, Python 등 |
| 임시 디렉토리 | `$RUNNER_TEMP` |
| 아키텍처 | amd64 (arm64 runner는 별도 설정) |

사전 설치 도구 전체 목록: [GitHub Actions runner-images](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2404-Readme.md)
