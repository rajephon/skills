---
name: issue-planner
description: GitHub 이슈 URL을 받아 구현 계획을 수립하는 스킬. 이슈 내용과 코드베이스를 분석하여 구체적인 작업 계획을 세우고, 정보 부족 시 clarification 질문을 제공합니다. 계획 확정 후 브랜치 생성, GitHub Projects 상태 업데이트, 이슈 코멘트를 자동으로 처리합니다. 다음 상황에서 반드시 이 스킬을 사용하세요 - "이 이슈 작업해줘", "이슈 플래닝", "이슈 분석", GitHub 이슈 URL이 주어졌을 때, "issue plan", "이슈 계획 세워줘", "이 티켓 분석해줘", "작업 계획", 이슈 번호와 함께 작업 요청이 올 때. GitHub issue URL 패턴(github.com/.../issues/숫자)이 메시지에 포함되어 있으면 이 스킬을 우선 활성화하세요.
---

# Issue Planner

GitHub 이슈를 분석하고 구현 계획을 수립하는 스킬. 이슈 내용의 충분성을 판단하여 부족하면 질문하고, 코드베이스를 탐색하여 구체적인 구현 방향을 제시한 뒤, 브랜치 생성과 프로젝트 상태 업데이트까지 자동으로 처리한다.

## Prerequisites

- `gh` CLI 인증 완료 (`gh auth status`로 확인)
- GitHub Projects v2 상태 변경 시: `gh auth refresh -s project` 필요

## Workflow

### Phase 1: 이슈 조회 및 분석

**1. 이슈 URL에서 정보 추출**

사용자가 제공한 URL 또는 이슈 번호에서 owner, repo, issue number를 파싱한다.

지원하는 입력 형태:
- 전체 URL: `https://github.com/owner/repo/issues/123`
- 짧은 형태: `owner/repo#123`
- 현재 repo 기준 번호: `#123` 또는 `123`

현재 repo 기준 번호인 경우, `gh repo view --json owner,name`으로 owner/repo를 자동 추출한다.

**2. 이슈 상세 정보 조회**

```bash
gh issue view <number> --repo <owner/repo> --json title,body,labels,assignees,milestone,projectItems,comments
```

**3. 이슈 타입 분류 및 충분성 판단**

먼저 라벨과 내용으로 이슈 타입을 분류한다:

| 타입 | 판단 기준 | 필수 정보 |
|------|----------|----------|
| **feature** | 라벨에 feature/enhancement, 또는 새 기능 요청 내용 | 기대 동작, UI/UX 명세, 데이터 소스 |
| **bug** | 라벨에 bug, 또는 오류/수정 관련 내용 | 재현 단계, 기대 동작, 실제 동작 |
| **refactor** | 라벨에 refactor, 또는 구조 개선 내용 | 변경 범위, 목표 구조 |
| **ui** | 라벨에 UI/UX, 또는 디자인/스타일 변경 | 변경 대상, 시각적 명세 |

타입별 충분성 체크리스트:

**공통 (모든 타입):**
- 왜 이 작업이 필요한지 명확한가?
- 무엇을 해야 하는지 구체적인가?

**feature 추가:**
- 기대하는 동작/결과가 기술되어 있는가?
- 데이터 소스(API, 로컬)가 명시되어 있는가?
- 디자인/와이어프레임이 있거나 불필요한가?

**bug 추가:**
- 재현 가능한 단계가 있는가?
- 기대 동작 vs 실제 동작이 구분되어 있는가?

**ui 추가:**
- 변경 대상 UI 요소가 특정되어 있는가?
- 시각적 변경 사항이 구체적인가? (색상값, 크기 등)

모든 필수 정보가 충분하면 → Phase 2로 진행
하나라도 부족하면 → Clarification 단계

### Clarification (정보 부족 시)

이슈 타입에 맞는 질문을 AskUserQuestion으로 한다.

**질문 설계 원칙:**
- 이슈에서 이미 답변된 내용을 다시 묻지 않는다
- 구현 방향에 직접 영향을 미치는 것만 질문한다
- 가능하면 선택지를 제공하되, 열린 답변도 허용한다
- 한 번에 최대 4개 질문 (AskUserQuestion 제한)
- 코드베이스를 미리 간단히 탐색하여 선택지에 구체적 파일/패턴을 포함한다

**타입별 질문 템플릿:**

feature:
```
- "데이터는 어디서 가져오나요?" → 기존 API / 새 API / 로컬
- "UI 레퍼런스가 있나요?" → 디자인 파일 / 기존 페이지 참고 / 자유 구현
- "인증이 필요한 기능인가요?" → 로그인 필수 / 비로그인도 가능
```

bug:
```
- "이 버그가 발생하는 조건이 있나요?" → 특정 브라우저 / 특정 데이터 / 항상
- "우회 방법이 있나요?" → 있음 (설명) / 없음
```

ui:
```
- "구체적인 색상값이 있나요?" → 디자인 시스템 참조 / 자유 판단 / 구체값 제공
- "모바일/데스크탑 모두 적용인가요?" → 모바일만 / 모두 / 데스크탑만
```

사용자 답변을 받은 후 Phase 2로 진행한다. 답변이 여전히 불충분하면 한 번 더 질문할 수 있지만, 최대 2회까지만 — 그 이상은 이해한 범위에서 계획을 수립하고 불확실한 부분을 명시한다.

### Phase 2: 코드베이스 분석

이슈 내용을 바탕으로 관련 코드를 탐색한다. Explore 에이전트를 2~3개 병렬로 스폰한다.

**에이전트 구성:**

에이전트 1 — 직접 관련 코드:
> "{이슈 제목}과 관련된 파일을 찾아줘. 컴포넌트, 페이지, 훅, API 호출 등을 확인하고 핵심 로직과 줄 번호를 파악해줘."

에이전트 2 — 패턴 및 컨벤션:
> "이 프로젝트에서 {유사 기능}이 어떻게 구현되어 있는지 찾아줘. 동일한 패턴을 따라야 하므로 컨벤션을 파악해줘."

에이전트 3 (변경 범위가 클 때만) — 영향 범위:
> "{관련 모듈}을 import하거나 사용하는 다른 파일들을 찾아줘. 변경 시 영향받는 범위를 파악해줘."

**탐색 결과에서 반드시 수집할 정보:**
- 수정 대상 파일 경로 + 줄 번호
- 재사용할 기존 컴포넌트/훅/유틸리티
- 프로젝트의 관련 컨벤션 (스타일링 패턴, 상태 관리 방식 등)
- 잠재적 영향 범위 (이 파일을 import하는 다른 파일)

### Phase 3: 구현 계획 수립

분석 결과를 종합하여 구현 계획을 작성한다.

**계획에 포함할 내용:**
1. 작업 요약 — 이슈 제목 + 한 줄 설명
2. 구현 방향 — 접근 방식, 아키텍처 결정, 선택 이유
3. 작업 단계 — 체크리스트 형태, 의존성 순서대로
4. 수정/생성할 파일 목록 — 경로 + 변경 내용 요약
5. 재사용할 기존 코드 — 파일 경로:줄번호 + 함수명
6. 검증 방법 — lint, build, 수동 테스트 항목
7. 예상 리스크/주의사항

플랜 파일을 `templates/plan-template.md` 템플릿 구조를 참고하여 작성한다.

**저장 경로:** `docs/plans/issue-{number}-{slug}.md`
- `docs/plans/` 디렉토리가 없으면 생성
- slug는 이슈 제목에서 파생 (kebab-case, 30자 이내)

작성 후 사용자에게 계획을 보여주고 승인을 요청한다. 승인 선택지에 **"설계 리뷰 후 진행"** 옵션을 함께 제공한다:

- **승인, 진행** — Phase 4로 이동
- **설계 리뷰 후 진행** — `/design-review` 스킬을 호출하여 전문가 에이전트 리뷰를 거친 뒤, 승인되면 Phase 4로 이동
- **수정 필요** — 피드백 반영 후 재승인 요청

사용자가 수정 요청하면 반영한 뒤 다시 승인을 요청한다.

### Phase 4: 브랜치 생성 및 상태 업데이트

사용자 승인 후 아래 작업을 수행한다. 각 작업 전에 사용자에게 한 번에 확인받는다 — 개별 확인이 아니라 "브랜치 생성, 프로젝트 상태 변경, 이슈 코멘트를 진행할까요?" 형태로 묶어서 물어본다.

**1. 브랜치 생성**

**중요: 브랜치명은 반드시 ASCII 영문으로 작성한다.** 한글/유니코드가 포함되면 GitHub에서 hidden characters 경고가 발생하고 CLI 호환성 문제를 일으킨다.

이슈 제목에서 영문 slug를 생성하여 `--name` (`-n`) 플래그로 지정한다:

```bash
gh issue develop <number> --repo <owner/repo> --checkout --name <type>/issue-<number>-<english-slug>
```

- `<type>`: feat, fix, refactor, chore 등 (이슈 타입에 맞게)
- `<english-slug>`: 이슈 내용을 영문 kebab-case로 요약 (30자 이내)
- 예시: `refactor/issue-87-profile-page-revamp`, `feat/issue-55-push-notification`

실패 시 fallback:
```bash
git checkout -b <type>/issue-<number>-<english-slug>
```

생성된 브랜치명을 기록해둔다 — 코멘트에 포함해야 한다.

**2. GitHub Projects v2 상태 업데이트**

이슈의 `projectItems`가 비어있으면 이 단계를 건너뛴다.

`projectItems`에 프로젝트 정보가 있으면 아래 절차로 Status를 "In Progress"로 변경한다:

```bash
# 1) 프로젝트 목록에서 해당 프로젝트의 번호 확인
gh project list --owner <owner> --format json --jq '.projects[] | select(.title=="<project-title>") | .number'

# 2) Status 필드의 ID와 "In Progress" 옵션 ID 확인
gh project field-list <project-number> --owner <owner> --format json \
  --jq '.fields[] | select(.name=="Status") | {fieldId: .id, options: .options}'

# 3) 이슈의 project item ID 확인
gh project item-list <project-number> --owner <owner> --format json \
  --jq '.items[] | select(.content.number==<issue-number>) | .id'

# 4) 프로젝트의 global ID 확인 (item-edit에 필요)
gh project view <project-number> --owner <owner> --format json --jq '.id'

# 5) 상태 변경
gh project item-edit \
  --id <item-id> \
  --field-id <status-field-id> \
  --project-id <project-global-id> \
  --single-select-option-id <in-progress-option-id>
```

이 과정에서 jq 파싱이 실패하거나 권한 오류가 발생하면:
- 사용자에게 "프로젝트 상태를 수동으로 변경해주세요: {프로젝트명} → In Progress"라고 안내
- 전체 워크플로우를 중단하지 않고 다음 단계로 진행

**3. 이슈 코멘트 작성**

계획 요약을 이슈 코멘트로 남긴다. 코멘트 내용은 Phase 3에서 작성한 계획의 핵심만 추출한다:

```bash
gh issue comment <number> --repo <owner/repo> --body "$(cat <<'EOF'
## Work Plan

**Branch:** `<branch-name>`

### Approach
<1-2문장 구현 방향>

### Tasks
- [ ] <task-1>
- [ ] <task-2>
- [ ] <task-3>

### Files to modify
- `<path>` — <변경 내용>

---
_Generated by Issue Planner_
EOF
)"
```

## Output Summary

모든 작업 완료 후 사용자에게 보여줄 요약:

```
이슈 #<number> 작업 준비 완료

- 플랜: docs/plans/issue-<number>-<slug>.md
- 브랜치: <branch-name> (checked out)
- 프로젝트 상태: In Progress (또는 "수동 변경 필요")
- 이슈 코멘트: 작업 계획 게시 완료

다음 단계: 구현을 시작하세요.
```

## Error Recovery

| 상황 | 대응 |
|------|------|
| `gh auth` 실패 | "gh auth login을 실행해주세요" 안내 후 중단 |
| `gh issue view` 실패 | 이슈 번호/repo 확인 요청 |
| `gh issue develop` 실패 | 수동 브랜치 생성 fallback |
| Projects v2 권한 없음 | `gh auth refresh -s project` 안내 + 수동 변경 안내 |
| Projects v2 jq 파싱 실패 | 수동 변경 안내, 워크플로우 계속 진행 |
| 이슈 코멘트 실패 | 코멘트 내용을 로컬에 저장하고 사용자에게 수동 게시 안내 |

## Examples

### Example 1: 충분한 정보의 UI 이슈

**사용자:** "https://github.com/myorg/myrepo/issues/42 이 이슈 작업해줘"

**동작:**
1. 이슈 조회 → 제목/본문/라벨 확인, UI 타입 분류
2. 구체적 변경 항목이 명시되어 있으므로 → 바로 코드베이스 분석
3. Explore 에이전트 2개로 관련 파일 + 컨벤션 탐색
4. 구현 계획 작성 → `docs/plans/issue-42-profile-page-refactor.md`
5. 사용자에게 계획 제시 + 외부 액션 승인 요청
6. 승인 후: 브랜치 생성 → 상태 업데이트 → 코멘트 작성

### Example 2: 정보 부족한 feature 이슈

**사용자:** "이슈 #55 분석하고 계획 세워줘"

**동작:**
1. 이슈 조회 → "알림 기능 추가" 제목만, 본문에 구체적 내용 없음
2. feature 타입 판단 → clarification 질문:
   - "어떤 종류의 알림인가요?" (푸시 알림 / 인앱 알림 / 이메일)
   - "알림 트리거 조건이 있나요?" (운세 업데이트 / 이벤트 / 커스텀)
   - "UI 레퍼런스가 있나요?" (디자인 파일 / 기존 앱 참고 / 자유)
3. 사용자 답변 반영하여 코드베이스 분석
4. 구체적 계획 수립 후 진행

### Example 3: 프로젝트 미연결 이슈

**사용자:** "github.com/myorg/myrepo/issues/15 플래닝해줘"

**동작:**
1. 이슈 조회 → projectItems가 빈 배열
2. 코드베이스 탐색 후 계획 수립
3. 브랜치 생성 (gh issue develop)
4. Projects v2 상태 변경 → 건너뜀 ("프로젝트에 연결되지 않아 상태 변경을 건너뜁니다")
5. 이슈 코멘트 작성
