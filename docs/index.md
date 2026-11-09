---
okf_version: "0.2"
---

# 표준

* [에이전트 작업 절차](standards/agent-workflow.md) - 작업 전에 읽을 문서, 사용자 확인이 필요한 행동, 완료 전 검증, 결과 보고 방식을 정한다.
* [글쓰기 규칙](standards/writing-style.md) - 문서, 코드 주석, 커밋 메시지, PR에 쓰는 언어와 문체, 기호, 표기 방식을 정한다.
* [문서 메타데이터](standards/metadata.md) - docs/ 문서의 YAML front matter, 파일 이름과 위치, 색인을 OKF v0.2에 맞춰 쓰는 규칙을 정한다.
* [ADR 작성 규칙](standards/adr.md) - 설계 결정을 MADR 4 양식의 ADR로 docs/architecture/adr/에 남기는 기준과 양식을 정한다.
* [커밋 규칙](standards/commit-convention.md) - 커밋 메시지 형식, 브랜치 이름, PR 제목과 본문, 병합 방식을 정한다.
* [이슈 규칙](standards/issues.md) - GitHub 이슈를 찾고 쓰고 triage하고 닫는 방법과 이슈 라벨을 정한다.
* [플랫폼 동등성](standards/cross-platform.md) - 지원하는 모든 OS에서 같은 도구와 설정을 유지하는 규칙을 정한다.
* [설치 스크립트](standards/installer.md) - install.ps1과 install.sh의 범위, 단계 구성, 실패 처리, 배포 방식 선택 규칙을 정한다.
* [패키지 매니페스트](standards/manifests.md) - manifests/ 파일의 형식, 도구를 추가하고 지우는 절차, 버전을 고정하지 않는 원칙을 정한다.
* [스크립트 작성](standards/scripts.md) - bash, zsh, PowerShell 스크립트와 셸 프로파일의 호환성, 오류 처리, 인코딩 규칙을 정한다.
* [에이전트 설정](standards/agent-config.md) - 에이전트별 설정과 hook을 모든 에이전트에서 같은 동작으로 유지하는 규칙을 정한다.

# 결정 기록

* [결정을 MADR 형식의 ADR로 기록한다](architecture/adr/0001-record-decisions-in-madr.md) - 설계 결정과 그 이유를 docs/architecture/adr/에 MADR 4 양식을 한국어로 옮긴 ADR로 남긴다.
* [docs/를 OKF v0.2 bundle로 관리한다](architecture/adr/0002-manage-docs-as-okf-bundle.md) - docs/ 아래 문서에 OKF v0.2 front matter를 붙이고 docs/index.md를 색인으로 두어, 에이전트가 문서를 열기 전에 내용과 적용 범위를 판단하게 한다.
* [AGENTS.md를 모든 에이전트의 단일 진입점으로 쓴다](architecture/adr/0003-agents-md-as-single-entry-point.md) - 저장소 루트에는 AGENTS.md만 두고 CLAUDE.md와 GEMINI.md를 만들지 않아, 모든 에이전트가 같은 지침을 읽게 한다.
* [문서와 커밋 메시지를 한국어로 쓴다](architecture/adr/0004-write-docs-and-commits-in-korean.md) - 문서, 커밋 메시지, PR을 한국어로 쓰고, Conventional Commits 키워드와 스크립트 출력은 영어로 둔다.
* [install 스크립트는 패키지 설치와 설정 배포만 한다](architecture/adr/0005-keep-installers-thin.md) - 설치 기록, 소유권 판정, 버전 고정, 백업, uninstall을 두지 않고 패키지 매니저와 공식 installer 호출, 설정 파일 배포만 한다.
* [앱이 다시 쓰는 설정 파일은 기존 값이 이기도록 병합한다](architecture/adr/0006-merge-app-managed-config.md) - 앱과 다른 도구가 스스로 고치는 JSON, TOML 설정은 덮어쓰지 않고 병합하며, 겹치는 키는 기존 값을 남긴다.
* [운영 문제는 문서 대신 GitHub 이슈로 기록한다](architecture/adr/0007-record-troubleshooting-in-github-issues.md) - 운영 중에 겪은 문제와 원인, 조치를 docs/troubleshooting.md 대신 troubleshooting 라벨의 GitHub 이슈로 기록한다.
* [이슈 triage는 상태 라벨 두 개로 최소 구성한다](architecture/adr/0008-minimal-issue-triage.md) - 이슈 triage에 status/needs-triage와 status/needs-info 라벨만 두고, 진행 상태는 열린 상태, 담당자, 연결된 PR 같은 GitHub 기본 상태로 나타낸다.

# 절차

* [구버전 설치 잔재 정리 (에이전트용 프롬프트)](legacy-cleanup.md) - #10 이전 install로 설치한 머신의 잔재를 정리하는 에이전트용 임시 절차로, 정리할 머신이 남지 않으면 지운다.

# 저장소 루트 문서

* [AGENTS.md](../AGENTS.md) - 에이전트 진입점이며 작업별로 읽을 문서를 안내한다.
* [INSTALL.md](../INSTALL.md) - 에이전트가 사용자 대신 전제 조건을 확인하고 install을 실행해 결과를 보고하는 절차다.
* [ARCHITECTURE.md](../ARCHITECTURE.md) - 저장소 구조, 설치 단계, 배포 방식, 도구별 동작을 설명한다.
* [SECURITY.md](../SECURITY.md) - 취약점 보고 방법과 비밀 정보, 외부 코드, 권한 설정의 기준을 정한다.
* [README.md](../README.md) - 지원 환경, 설치 목록, 설치 방법을 안내한다.
