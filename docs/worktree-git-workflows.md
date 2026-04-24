# Claude Code Worktree: 커밋 히스토리 관리 전략

Claude Code worktree로 복수 세션을 병렬 실행하면 각 세션이 독립 브랜치에 커밋을 쌓고,
이를 main에 순서 없이 merge할 때 merge commit이 난립해 히스토리가 뒤엉킨다.

## 문제 상황

3개 워크트리 세션을 순서 없이 merge하면 아래처럼 히스토리가 얽힌다.

```
*   f3a1b2c (HEAD -> main) Merge branch 'claude/fix-shell'
|\
| * 9e2d4f1 fix: 오타
| * 3c7a8b0 wip: 저장
* |   b1d5e3a Merge branch 'claude/add-yazi'
|\ \
| * | 7f4c2d9 feat: yazi 키맵
| * | 2a8e1b5 feat: yazi 플러그인
* | |   e9c3f7d Merge branch 'claude/refactor'
|\ \ \
| * | | 4b6d2e8 wip: 임시
| * | | 1f9a3c7 refactor: 섹션 분리
| |/ /
* | / 0d4e8f2 (origin/main) docs: README 수정
|/ /
* / 5c1b9a3 feat: lazy.nvim 구조
|/
* 3e7d104 feat: 초기 설정
```

---

## 전략 비교

| 전략 | 히스토리 형태 | 세부 이력 보존 | 충돌 해결 위험 | 추천 상황 |
|------|------------|-------------|-------------|---------|
| Squash Merge | 선형 | 브랜치당 1커밋 | 낮음 | 단기 작업, wip 커밋 많을 때 |
| Rebase + FF | 선형 | 전체 보존 | 중간 | 긴 feature, 이력 중요할 때 |
| Interactive Rebase | 선형 | 선택적 보존 | 중간 | 커밋을 골라서 정리할 때 |
| GitHub PR Squash | 선형 | PR당 1커밋 | 낮음 | 원격 저장소, 협업 환경 |

---

## Workflow 1: Squash Merge

브랜치의 모든 커밋을 하나로 압축해 main에 추가한다. wip 커밋이 많을 때 가장 깔끔하다.

**Before**
```
* a3f1c2e (claude/fix-nvim-shell) fix: 오타 수정
* 91bcd34 wip: 중간 저장
* 4e7a012 fix: shell 경로 수정
* 7d2e901 (main) feat: yazi.nvim 추가
```

```bash
git switch main
git merge --squash claude/fix-nvim-shell
git commit -m "fix: nvim Windows shell 설정 수정"
git branch -d claude/fix-nvim-shell
```

**After**
```
* c9f3a11 (HEAD -> main) fix: nvim Windows shell 설정 수정
* 7d2e901 feat: yazi.nvim 추가
```

> **주의:** squash 후 브랜치를 삭제하지 않으면 나중에 같은 브랜치를 다시 merge할 때
> 이미 반영된 커밋이 중복으로 들어올 수 있다. merge 후 즉시 `git branch -d`로 삭제한다.

---

## Workflow 2: Rebase + Fast-forward Merge

브랜치 커밋들을 main 위로 재배치한 뒤 fast-forward로 이어붙인다.
커밋 이력을 그대로 보존하면서 선형 히스토리를 만든다.

**Before**
```
* b2e4f01 (claude/add-yazi-plugin) feat: yazi 키맵 추가
* 8c1d3a2 feat: yazi.nvim 플러그인 설치
| * f5a9b3c (main) docs: README 업데이트
|/
* 3e7d104 feat: lazy.nvim 구조 추가
```

```bash
git switch claude/add-yazi-plugin
git rebase main
git switch main
git merge --ff-only claude/add-yazi-plugin
git branch -d claude/add-yazi-plugin
```

**After**
```
* d4c8e21 (HEAD -> main) feat: yazi 키맵 추가
* 9a2f7b3 feat: yazi.nvim 플러그인 설치
* f5a9b3c docs: README 업데이트
* 3e7d104 feat: lazy.nvim 구조 추가
```

**충돌 발생 시**
```bash
# 충돌 파일 수정 후
git add <충돌 파일>
git rebase --continue

# 포기하고 원래 상태로 되돌리려면
git rebase --abort
```

> **주의:** 이미 원격에 push된 브랜치를 rebase하면 강제 push(`git push --force-with-lease`)가 필요하다.
> Claude Code worktree 브랜치는 원칙적으로 공유하지 않으므로 일반적으로 문제없다.

---

## Workflow 3: Interactive Rebase

커밋을 골라서 합치거나 순서를 바꾼 뒤 main에 이어붙인다.
wip 커밋은 버리고 의미 있는 커밋만 선별하고 싶을 때 쓴다.

**Before**
```
* e1b5c09 (claude/refactor-install) fix: 오타
* 7f3a2d1 wip: 저장
* 2c8e4b6 wip: 임시
* 0d9f1a3 refactor: install.ps1 섹션 분리
* 3e7d104 (main) feat: lazy.nvim 구조 추가
```

```bash
git switch claude/refactor-install
git rebase -i main
```

에디터가 열리면 각 커밋 앞의 명령어를 수정한다.

```
pick 0d9f1a3 refactor: install.ps1 섹션 분리
squash 2c8e4b6 wip: 임시
squash 7f3a2d1 wip: 저장
fixup  e1b5c09 fix: 오타
```

| 명령어 | 동작 |
|--------|------|
| `pick` | 커밋을 그대로 유지 |
| `squash` | 위 커밋에 합치고 커밋 메시지 편집 |
| `fixup` | 위 커밋에 합치고 메시지는 버림 |
| `drop` | 커밋 삭제 |

```bash
# 에디터 저장 후 main으로 merge
git switch main
git merge --ff-only claude/refactor-install
git branch -d claude/refactor-install
```

**After**
```
* a7d3f02 (HEAD -> main) refactor: install.ps1 섹션 분리
* 3e7d104 feat: lazy.nvim 구조 추가
```

---

## Workflow 4: GitHub PR Squash and Merge

원격 저장소를 사용할 때 GitHub의 "Squash and merge"로 브랜치 전체를 커밋 하나로 압축한다.
로컬에서 별도 정리 없이 PR 단위로 히스토리를 관리할 수 있다.

**Before** (PR merge 전)
```
* 4b1e8c3 (origin/claude/update-readme) docs: 링크 수정
* 9f2d7a1 docs: References 카테고리 추가
* c3a8e54 docs: README 초안
* 7d2e901 (origin/main) feat: yazi.nvim 추가
```

```bash
git push origin claude/update-readme
gh pr create --title "docs: README 업데이트" --body "워크트리 세션에서 작업"
gh pr merge --squash --delete-branch
```

GitHub UI를 쓴다면: PR 페이지 → **"Squash and merge"** 드롭다운 선택 → Confirm

**After**
```
* 1f9c2b7 (origin/main) docs: README 업데이트 (#3)
* 7d2e901 feat: yazi.nvim 추가
```

> **주의:** `--squash`로 merge하면 브랜치 커밋들이 origin에 남는다. `--delete-branch` 또는
> PR 설정의 "Automatically delete head branches"로 정리한다.

---

## 워크트리 정리

merge 후에는 worktree와 브랜치를 함께 제거한다.

```bash
# 현재 워크트리 목록 확인
git worktree list

# 워크트리 제거 (브랜치는 별도 삭제 필요)
git worktree remove .worktrees/claude/fix-nvim-shell

# 로컬 브랜치 삭제
git branch -d claude/fix-nvim-shell

# 원격 브랜치까지 삭제
git push origin --delete claude/fix-nvim-shell

# 이미 merge된 브랜치 일괄 삭제 (main 제외)
git branch --merged main | grep -v "^\* main" | xargs git branch -d
```

---

## 전략 선택 가이드

```
로컬 작업인가?
├── Yes
│   ├── wip 커밋이 많고 이력 불필요 → Workflow 1: Squash Merge
│   ├── 커밋 이력을 모두 보존하고 싶다 → Workflow 2: Rebase + FF
│   └── 커밋을 골라서 정리하고 싶다 → Workflow 3: Interactive Rebase
└── No (GitHub 원격 저장소)
    └── Workflow 4: GitHub PR Squash and Merge
```

Claude Code worktree의 일반적인 단기 작업에는 **Workflow 1 (Squash Merge)** 이 가장 실용적이다.
