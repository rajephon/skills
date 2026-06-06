---
name: ticket-wrapup
description: PR 머지/리뷰 완료 후 작업을 마무리하는 스킬. GitHub Projects v2 티켓 상태를 In Review 또는 Done으로 변경하고, 이슈에 완료/리뷰요청 코멘트를 남기고, 작업하던 git worktree를 안전하게 정리합니다. issue-planner가 작업의 시작(브랜치·In Progress·플랜 코멘트)을 담당한다면 이 스킬은 작업의 종료를 담당하는 짝 스킬입니다. 다음 상황에서 반드시 이 스킬을 사용하세요 — "작업 마무리", "티켓 마무리", "마무리해줘", "이슈 닫아줘", "PR 머지 끝났어", "wrap up", "티켓 Done으로", "In Review로 옮겨줘", "worktree 정리", "작업 정리", PR을 머지한 직후 정리를 요청할 때. 단일 레포와 크로스 레포(프론트+백엔드) 작업을 모두 지원합니다.
---

# Ticket Wrapup

작업의 *종료*를 담당하는 스킬. PR이 머지/리뷰 단계에 들어간 뒤 세 가지를 한 번에 처리한다:

1. **GitHub Projects v2 티켓 상태**를 In Review 또는 Done으로 변경
2. **이슈에 완료/리뷰요청 코멘트** 작성
3. **작업하던 git worktree 정리** (안전 가드 통과 시에만)

`issue-planner`(시작: 브랜치 생성·In Progress·플랜 코멘트)와 짝을 이루므로, Projects v2 동적 조회 절차와 Error Recovery 표현을 그대로 계승한다.

## Prerequisites

- `gh` CLI 인증 완료 (`gh auth status`로 확인)
- GitHub Projects v2 상태 변경 시: `gh auth refresh -s project` 필요 (권한 없으면 안내만 하고 워크플로우는 계속)

## 핵심 원칙

- **외부 액션은 배치 확인.** 상태 변경·코멘트·worktree 제거는 실행 전 한 번에 묶어 확인받는다 — 개별 확인이 아니라 "상태 변경 + 코멘트 + worktree 정리를 진행할까요?" 형태로.
- **파괴적 작업(worktree 제거)은 특히 신중히.** 미푸시 커밋이나 미커밋 변경을 발견하면 절대 임의 삭제하지 않는다.
- **gh/git 명령은 대상 디렉토리 기준으로.** 각 레포(또는 worktree) 디렉토리에서 실행하거나 `-C <경로>`를 사용한다. 크로스 레포면 프론트/백엔드를 따로 다룬다.
- **ID는 하드코딩하지 않는다.** 프로젝트/필드/옵션/아이템 ID는 매번 동적으로 조회한다 (Phase 2 참조).

## Workflow

### Phase 0: 컨텍스트 파악

**1. 이슈 식별**

- 사용자가 이슈 URL/번호를 주면 거기서 owner, repo, issue number를 파싱한다.
  - 전체 URL: `https://github.com/owner/repo/issues/123`
  - 짧은 형태: `owner/repo#123`
  - 현재 repo 기준 번호: `#123` 또는 `123`
- 입력이 없으면 현재 브랜치/worktree에서 추론한다:
  - 브랜치명에서 `issue-<N>` 패턴 추출, 또는 worktree 경로의 `...-issue-<N>` 패턴
  - owner/repo는 `gh repo view --json owner,name`으로 추출

```bash
gh issue view <number> --repo <owner/repo> --json number,title,state,projectItems,url
```

**2. 관련 PR 조회**

이슈에 연결된 PR과 상태(open/merged)를 확인한다. 크로스 레포면 양쪽 레포 모두 조회한다.

```bash
# 이슈에 연결된 PR (각 레포에서)
gh pr list --repo <owner/repo> --search "<issue-number> in:body" --state all \
  --json number,title,state,url,mergedAt

# 또는 현재 브랜치의 PR
gh pr view --repo <owner/repo> --json number,title,state,url,mergedAt
```

각 PR의 `state`(OPEN/MERGED/CLOSED)와 `mergedAt`을 기록한다 — Phase 1의 상태 판단과 Phase 4의 안전 가드에 모두 쓰인다.

**3. worktree 후보 탐색 + 상태 사전 점검**

각 레포에서 worktree 목록을 확인하고, 이슈 번호로 대상을 좁힌다.

```bash
git -C <main-repo> worktree list
```

워크스페이스에 worktree 네이밍 컨벤션이 있으면 sibling 경로로도 추론할 수 있다
(예: `<repo>-frontend-issue-<N>`, `<repo>-backend-issue-<N>`).

대상 worktree마다 아래 3가지를 미리 점검한다 (실제 제거는 Phase 4에서):

```bash
# (a) 브랜치가 원격에 푸시됨 — 미푸시 커밋이 없어야 함
git -C <worktree> status -sb            # ahead/behind 확인
git -C <worktree> log --oneline @{u}..  # 출력이 있으면 미푸시 커밋 존재

# (b) 추적 파일의 미커밋 변경 없음
git -C <worktree> status --porcelain     # 출력 비어야 안전 (?? 미추적은 별도 판단)

# (c) 관련 PR 머지됨 — Phase 0-2 결과 사용
```

점검 결과를 기록해 두고, **하나라도 불충족이면 그 worktree는 자동 제거 대상에서 제외**하여 사용자에게 보고한다.

### Phase 1: 목표 상태 결정 (In Review vs Done)

Phase 0에서 모은 PR 상태로 판단한다:

| PR 상태 | 제안 상태 |
|---------|-----------|
| PR이 열려있고 미머지 (리뷰 대기) | **In Review** |
| 모든 관련 PR이 머지됨 (크로스 레포면 양쪽 다) | **Done** |
| 일부만 머지 (크로스 레포에서 한쪽만) | **In Review** (나머지 머지 대기) |

자동 판단이 애매하면 (예: PR을 못 찾음, 상태 혼재) `AskUserQuestion`으로 In Review / Done 중 확인한다.

### 실행 확인 (배치)

Phase 2~4를 실행하기 전에 계획을 한 번에 묶어 확인받는다. 사전 점검 결과도 함께 보고한다:

```
정리 계획 (이슈 #<N> <제목>):
- Projects v2 상태: <현재> → <In Review / Done>
- 이슈 코멘트: <완료 / 리뷰요청> 템플릿 게시
- worktree 정리:
  - <경로> ✅ 제거 가능 (푸시됨·clean·PR 머지)
  - <경로> ⚠️ 보류 (미커밋 변경 있음 / 미푸시 커밋 / PR 미머지)

진행할까요? (상태 변경 + 코멘트 + 안전한 worktree 정리)
```

⚠️ 표시된 worktree는 동의 없이 제거하지 않는다.

### Phase 2: Projects v2 상태 변경

이슈의 `projectItems`가 비어있으면 이 단계를 건너뛰고 안내한다 ("프로젝트에 연결되지 않아 상태 변경을 건너뜁니다").

`projectItems`에 프로젝트가 있으면 아래 **5단계 동적 조회**로 Status를 목표 상태로 변경한다. ID는 절대 하드코딩하지 않는다:

```bash
# 1) 프로젝트 번호
gh project list --owner <owner> --format json \
  --jq '.projects[] | select(.title=="<project-title>") | .number'

# 2) Status 필드 ID + 옵션 목록 (In review / Done 등 옵션 id 확인)
gh project field-list <project-number> --owner <owner> --format json \
  --jq '.fields[] | select(.name=="Status") | {fieldId: .id, options: .options}'

# 3) 이슈의 project item ID
gh project item-list <project-number> --owner <owner> --format json --limit 200 \
  --jq '.items[] | select(.content.number==<issue-number>) | .id'

# 4) 프로젝트 global ID (item-edit에 필요)
gh project view <project-number> --owner <owner> --format json --jq '.id'

# 5) 상태 변경
gh project item-edit \
  --id <item-id> \
  --field-id <status-field-id> \
  --project-id <project-global-id> \
  --single-select-option-id <target-option-id>
```

**옵션 이름 매칭:** 보드마다 표기가 다르다("In review" vs "In Review", "Done" vs "Completed"). 2단계 `options` 목록에서 목표 상태에 해당하는 옵션을 **대소문자·공백 무시하고 매칭**해 그 `id`를 쓴다. 적절한 옵션이 없으면 옵션 목록을 사용자에게 보여주고 확인한다.

**실패 시:** jq 파싱 실패나 권한 오류가 나면 워크플로우를 중단하지 말고 "수동 변경 필요: <보드명> → <상태>"라고 안내한 뒤 다음 단계로 진행한다.

### Phase 3: 이슈 코멘트

목표 상태에 맞는 템플릿으로 코멘트를 작성한다:

- **Done** → `templates/comment-done.md`
- **In Review** → `templates/comment-review.md`

```bash
gh issue comment <number> --repo <owner/repo> --body "$(cat <<'EOF'
<템플릿 채워서>
EOF
)"
```

본문 구성: 한 줄 요약 + PR 링크(표) + 최종 상태 + (있으면) 후속 작업/릴리스 게이트 + footer. **크로스 레포면 양쪽 PR을 모두 표에 링크**한다.

### Phase 4: git worktree 정리

Phase 0-3의 사전 점검을 통과한 worktree만 제거한다.

**안전 가드 (중요):** 제거 전 각 worktree가 아래 3가지를 모두 충족하는지 재확인한다. 하나라도 불충족이면 제거하지 말고 사용자에게 보고/확인:

1. 브랜치가 원격에 푸시됨 (미푸시 커밋 없음)
2. 추적 파일의 미커밋 변경 없음
3. 관련 PR 머지됨

**제거:**

```bash
git -C <main-repo> worktree remove <worktree-path>
```

- `.env` 복사본, `dist/`, `node_modules/` 같은 **미추적 파일** 때문에 막히면, `git -C <worktree> status --porcelain`으로 그 내용을 사용자에게 보여주고 "버려도 되는지" 확인한 **뒤에만** `--force`를 사용한다. **무단 `--force` 금지.**

```bash
# 미추적 파일 내용 확인 후, 사용자 동의가 있을 때만
git -C <main-repo> worktree remove --force <worktree-path>
```

**정리 후:**

```bash
git -C <main-repo> worktree prune
```

로컬 브랜치 삭제는 선택 사항이다. 머지가 확인된 경우에만 안내하고, 사용자 동의 시 삭제한다:

```bash
git -C <main-repo> branch -d <branch-name>   # 머지 확인된 경우만 (-D 강제삭제 금지)
```

## Output Summary

모든 작업 완료 후 사용자에게 보여줄 요약:

```
이슈 #<number> 마무리 완료

- 프로젝트 상태: <In Review / Done> (또는 "수동 변경 필요")
- 이슈 코멘트: <완료 / 리뷰요청> 게시 완료
- worktree 정리:
  - <경로> 제거됨
  - <경로> 보류 (사유)
- 로컬 브랜치: <삭제됨 / 유지>
```

## Error Recovery

| 상황 | 대응 |
|------|------|
| `gh auth` 실패 | "gh auth login을 실행해주세요" 안내 후 중단 |
| `gh issue view` 실패 | 이슈 번호/repo 확인 요청 |
| 관련 PR을 못 찾음 | 목표 상태를 AskUserQuestion으로 확인 |
| Projects v2 권한 없음 | `gh auth refresh -s project` 안내 + 수동 변경 안내, 워크플로우 계속 |
| Projects v2 jq 파싱 실패 | 수동 변경 안내("<보드> → <상태>"), 워크플로우 계속 진행 |
| 목표 상태에 맞는 옵션 없음 | 옵션 목록 제시 후 사용자 확인 |
| 이슈 코멘트 실패 | 코멘트 내용을 로컬에 저장하고 수동 게시 안내 |
| worktree dirty (미커밋 변경) | 제거 보류, `status --porcelain` 결과 보고, 사용자 판단 요청 |
| worktree에 미푸시 커밋 | 제거 보류, "푸시 후 다시 정리하세요" 안내 (절대 임의 삭제 금지) |
| 미머지 PR | 해당 worktree·브랜치 유지, 상태는 In Review로 |
| `worktree remove` 미추적 파일로 실패 | 내용 보여주고 동의받은 뒤에만 `--force` |

## Examples

### Example 1: 단일 레포, 전부 머지 → Done

**사용자:** "이슈 #42 PR 머지 끝났어, 마무리해줘"

**동작:**
1. 이슈 #42 + 연결 PR 조회 → PR 1개 MERGED 확인
2. worktree `<repo>-frontend-issue-42` 탐색 → 푸시됨·clean·PR 머지 (안전 가드 통과)
3. 목표 상태 = **Done** 판단
4. 배치 확인 ("상태 Done + 완료 코멘트 + worktree 제거 진행할까요?")
5. 승인 후: Projects v2 → Done → `comment-done.md` 코멘트 → `worktree remove` → `prune`

### Example 2: 크로스 레포, 백엔드만 머지 → In Review

**사용자:** "이 티켓 In Review로 옮겨줘"

**동작:**
1. 현재 브랜치에서 이슈 #55 추론, owner/repo 추출
2. 백엔드 PR MERGED, 프론트엔드 PR OPEN 확인
3. 일부만 머지 → 목표 상태 = **In Review**
4. worktree 점검: 백엔드 worktree는 안전, 프론트엔드 worktree는 PR 미머지로 **보류**
5. 배치 확인 (보류 worktree 명시)
6. 승인 후: Projects v2 → In Review → `comment-review.md`(양쪽 PR 링크) → 백엔드 worktree만 제거, 프론트엔드는 유지

### Example 3: worktree dirty로 정리 보류

**사용자:** "작업 정리해줘"

**동작:**
1. 이슈·PR·worktree 식별
2. 사전 점검에서 worktree에 미커밋 변경 발견 (`status --porcelain` 출력 있음)
3. 상태 변경 + 코멘트는 진행하되, worktree 제거는 **보류**
4. 미커밋 변경 내용을 사용자에게 보여주고 "커밋/스태시 후 다시 정리하세요" 안내 — 임의 삭제하지 않음
