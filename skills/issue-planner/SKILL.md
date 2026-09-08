---
name: issue-planner
description: GitHub 이슈 URL을 받아 구현 계획을 수립하는 스킬. 이슈 내용과 코드베이스를 분석하여 구체적인 작업 계획을 세우고, 정보 부족 시 clarification 질문을 제공합니다. 계획 확정 후 브랜치 생성, GitHub Projects 상태 업데이트, 이슈 코멘트를 자동으로 처리합니다. 이슈에 대한 구현 계획 수립이나 작업 착수가 목적일 때 이 스킬을 사용하세요 - "이 이슈 작업해줘", "이슈 플래닝", "이슈 분석", "issue plan", "이슈 계획 세워줘", "이 티켓 분석해줘", "작업 계획", 이슈 번호나 GitHub issue URL(github.com/.../issues/숫자)과 함께 작업 요청이 올 때. 이슈 내용을 조회하거나 요약만 원하는 경우에는 이 스킬 대신 gh issue view로 직접 답합니다.
---

# Issue Planner

GitHub 이슈를 분석하고 구현 계획을 수립하는 스킬. 이슈 내용의 충분성을 판단하여 부족하면 질문하고, 코드베이스를 탐색하여 구체적인 구현 방향을 제시한 뒤, 브랜치 생성과 프로젝트 상태 업데이트까지 자동으로 처리한다.

## 원칙

- **계획은 실측 위에 세운다.** 계획에 적는 파일 경로·줄번호·함수명은 직접 Read로 확인한 것만, 검증 명령은 해당 레포 CLAUDE.md에 있는 것만 적는다. 탐색 에이전트의 보고는 후보 목록이고, 확인은 플래너의 일이다. 이 규칙이 없을 때 계획의 전제가 구현 단계에서 뒤집히는 일이 반복됐다.
- **질문은 계획을 실질적으로 바꾸는 것만 한다.** 이슈·코드베이스에서 답을 찾을 수 있으면 찾고, 답에 따라 계획이 달라지지 않으면 가정을 명시하고 진행한다.
- **프로젝트 규칙이 스킬 기본값보다 우선한다.** 브랜치 생성 방식, 명령 실행 디렉토리, 패키지 매니저는 작업 대상 레포(또는 워크스페이스)의 CLAUDE.md를 먼저 읽고 따른다.

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

체크리스트에 빈 항목이 있으면 먼저 이슈 코멘트·연결된 PR·코드베이스에서 답을 찾는다 (Phase 2의 가벼운 탐색을 앞당겨도 된다). 그래도 남은 항목 중 **답에 따라 계획이 실질적으로 달라지는 것**만 Clarification으로 묻는다. 계획이 달라지지 않는 항목은 가정을 정해 플랜의 "리스크/주의사항"에 명시하고 진행한다.

### Clarification (정보 부족 시)

이슈 타입에 맞는 질문을 AskUserQuestion으로 한다.

**질문 설계 원칙:**
- 이슈·코멘트·코드베이스에서 이미 답을 얻을 수 있는 것은 묻지 않고 직접 확인한다
- 답에 따라 구현 방향이 갈리는 것만 질문한다. 답이 무엇이든 계획이 같다면 가정으로 처리한다
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

**탐색 방식 선택**

- 이슈가 파일 1~2개, 모듈 하나에 국한되면 (단순 버그, 문구·스타일 수정) 직접 Grep/Read로 탐색한다. 에이전트 스폰은 왕복 시간과 토큰을 쓰므로 이 경우엔 오히려 느리다.
- 변경이 모듈 2개 이상에 걸치거나, 관련 코드 탐색과 컨벤션 조사가 서로 독립적인 작업이면 Explore 에이전트를 병렬로 스폰한다. 기본 2개, 영향 범위 조사가 별도로 필요할 때만 3개.
- 크로스 레포 워크스페이스(frontend/backend가 형제 디렉토리)에서는 이슈가 어느 레포를 건드리는지 먼저 정하고, 에이전트마다 대상 디렉토리를 명시한다.

**에이전트 프롬프트 템플릿**

에이전트는 발췌만 읽고 돌아오므로, 무엇을 어떤 형식으로 가져올지 정해주지 않으면 결과 형태가 매번 달라진다. 아래 구조를 쓴다. 이슈 본문을 위에, 요청을 아래에 둔다.

```
<issue>
제목: {이슈 제목}
{이슈 본문 핵심 — 기대 동작, 재현 단계 등}
</issue>

<target>
대상 디렉토리: {레포 경로, 예: /path/to/saju-ai-frontend}
탐색 폭: {medium | very thorough}
</target>

<task>
{에이전트별 임무 — 아래 세 가지 중 하나}
</task>

<output_format>
다음 형식으로만 보고한다:
1. 관련 파일 목록 — 각 항목은 `경로:줄번호` + 그 위치가 하는 일 한 줄
2. 재사용 후보 — 기존 컴포넌트/훅/유틸의 `경로:줄번호` + 함수명 + 재사용 이유
3. 따라야 할 컨벤션 — 근거가 되는 파일 경로와 함께
4. 확인하지 못한 것 — 추측하지 말고 "미확인"으로 표시
</output_format>
```

에이전트별 `<task>`:

- **직접 관련 코드**: "이 이슈를 구현하려면 수정해야 할 컴포넌트·페이지·훅·API 호출·라우트를 찾고, 핵심 로직의 위치를 파악한다."
- **패턴 및 컨벤션**: "이 프로젝트에서 {유사 기능}이 어떻게 구현되어 있는지 찾는다. 새 코드가 같은 패턴을 따라야 하므로 스타일링·상태 관리·에러 처리·테스트 방식을 파악한다."
- **영향 범위** (필요할 때만): "{관련 모듈}을 import하거나 호출하는 파일을 찾아 변경 시 영향받는 범위를 파악한다."

**탐색 결과 처리**

에이전트 보고는 후보 목록이다. 계획에 옮기기 전에 플래너가 해당 파일을 직접 Read하여 경로·줄번호·함수명이 맞는지 확인한다. 보고에 "미확인"으로 표시된 항목은 플래너가 직접 확인하거나 계획의 리스크로 적는다.

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
6. 검증 방법 — 해당 레포 CLAUDE.md의 lint/typecheck/test 명령 + 수동 테스트 항목
7. 예상 리스크/주의사항 — Clarification 없이 가정한 항목 포함

**작업 단계는 검증 가능한 단위로 쓴다.** 좋은 항목은 대상 위치, 변경 내용, 따를 패턴이 들어 있어 구현자가 바로 시작할 수 있고 완료 여부를 판정할 수 있다.

<example>
모호함: - [ ] 프로필 페이지 리팩토링
좋음:   - [ ] `src/pages/Profile.tsx:42-88`의 인라인 fetch를 `useProfile()` 훅으로 추출 (기존 `src/hooks/useUser.ts:12` 패턴과 동일하게)
</example>

플랜 파일을 `templates/plan-template.md` 템플릿 구조를 참고하여 작성한다.

**저장 경로:** `docs/plans/issue-{number}-{slug}.md`
- `docs/plans/` 디렉토리가 없으면 생성
- slug는 이슈 제목에서 파생 (kebab-case, 30자 이내)
- 크로스 레포 워크스페이스에서는 워크스페이스 루트의 `docs/plans/`에 둔다 (한쪽 레포 `docs/`에 넣으면 반쪽만 담는 곳에 놓인다)

**승인 요청 전 자기점검**

아래를 모두 확인한 뒤에만 사용자에게 계획을 보인다. 하나라도 어긋나면 계획을 고친다.

- 수정/생성 파일 표의 모든 경로가 실제로 존재하는가 (신규 파일은 "신규"로 표시)
- 재사용할 기존 코드의 줄번호·함수명을 직접 Read로 확인했는가
- 검증 방법의 명령이 해당 레포 CLAUDE.md에 있는 명령인가 (추측한 `npm test` 류는 쓰지 않는다)
- 크로스 레포 작업이면 워크스페이스 CLAUDE.md의 검증 게이트 순서(백엔드 통과 후 프론트엔드)를 따르는가
- Clarification에서 묻지 않고 가정한 항목이 리스크/주의사항에 적혀 있는가

작성 후 사용자에게 계획을 보여주고 승인을 요청한다. 승인 선택지에 **"설계 리뷰 후 진행"** 옵션을 함께 제공한다:

- **승인, 진행** — Phase 4로 이동
- **설계 리뷰 후 진행** — `/design-review` 스킬을 호출하여 전문가 에이전트 리뷰를 거친 뒤, 승인되면 Phase 4로 이동
- **수정 필요** — 피드백 반영 후 재승인 요청

사용자가 수정 요청하면 반영한 뒤 다시 승인을 요청한다.

### Phase 4: 브랜치 생성 및 상태 업데이트

사용자 승인 후 아래 작업을 수행한다. 각 작업 전에 사용자에게 한 번에 확인받는다 — 개별 확인이 아니라 "브랜치 생성, 프로젝트 상태 변경, 이슈 코멘트를 진행할까요?" 형태로 묶어서 물어본다. 프로젝트 상태 변경과 이슈 코멘트는 다른 사람에게 보이는 액션이므로 확인 없이 실행하지 않는다.

**1. 브랜치 생성**

브랜치 생성 방식은 **작업 대상 레포(또는 워크스페이스)의 CLAUDE.md를 먼저 읽고** 따른다. 메인 체크아웃에서의 브랜치 전환을 금지하고 worktree를 요구하는 프로젝트가 있고, 이를 어기면 같은 체크아웃을 쓰는 다른 세션의 커밋이 엉뚱한 브랜치에 얹힌다.

**중요: 브랜치명은 반드시 ASCII 영문으로 작성한다.** 한글/유니코드가 포함되면 GitHub에서 hidden characters 경고가 발생하고 CLI 호환성 문제를 일으킨다.

- `<type>`: feat, fix, refactor, chore 등 (이슈 타입에 맞게)
- `<english-slug>`: 이슈 내용을 영문 kebab-case로 요약 (30자 이내)
- 예시: `refactor/issue-87-profile-page-revamp`, `feat/issue-55-push-notification`

**(a) worktree를 요구하는 프로젝트** (CLAUDE.md에 "Worktree 격리" 류의 규칙이 있는 경우):

```bash
# 이슈에 연결된 원격 브랜치만 만들고, 메인 체크아웃은 건드리지 않는다
gh issue develop <number> --repo <owner/repo> --name <type>/issue-<number>-<english-slug>
git fetch origin
git worktree add ../<repo>-worktrees/<english-slug> <type>/issue-<number>-<english-slug>
```

worktree 경로 규칙과 생성 후 개발 환경 준비(.env 복사, 의존성 설치)는 해당 레포 CLAUDE.md의 "Git Worktree 사용 시" 절을 따른다. 크로스 레포 작업이면 양쪽 레포에 같은 브랜치명으로 각각 만든다.

실패 시 fallback:
```bash
git worktree add ../<repo>-worktrees/<english-slug> -b <type>/issue-<number>-<english-slug> origin/main
```

**(b) 그 외 프로젝트:**

```bash
gh issue develop <number> --repo <owner/repo> --checkout --name <type>/issue-<number>-<english-slug>
```

실패 시 fallback:
```bash
git checkout -b <type>/issue-<number>-<english-slug>
```

생성된 브랜치명(과 worktree 경로)을 기록해둔다 — 코멘트에 포함하고, 플랜 파일 frontmatter의 `branch`를 채우고 `status`를 `approved`로 갱신한다.

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
- 브랜치: <branch-name>
- 작업 위치: <worktree 경로> (worktree 프로젝트) / 현재 체크아웃 (그 외)
- 프로젝트 상태: In Progress (또는 "수동 변경 필요")
- 이슈 코멘트: 작업 계획 게시 완료

다음 단계: 구현을 시작하세요.
```

## Error Recovery

| 상황 | 대응 |
|------|------|
| `gh auth` 실패 | "gh auth login을 실행해주세요" 안내 후 중단 |
| `gh issue view` 실패 | 이슈 번호/repo 확인 요청 |
| `gh issue develop` 실패 | 수동 브랜치 생성 fallback (worktree 프로젝트는 `git worktree add -b`) |
| `git worktree add` 실패 | `git worktree list`로 같은 브랜치/경로의 기존 worktree 확인 후 안내 |
| Projects v2 권한 없음 | `gh auth refresh -s project` 안내 + 수동 변경 안내 |
| Projects v2 jq 파싱 실패 | 수동 변경 안내, 워크플로우 계속 진행 |
| 이슈 코멘트 실패 | 코멘트 내용을 로컬에 저장하고 사용자에게 수동 게시 안내 |

## Examples

### Example 1: 충분한 정보의 UI 이슈 (worktree 프로젝트)

**사용자:** "https://github.com/myorg/myrepo/issues/42 이 이슈 작업해줘"

**동작:**
1. 이슈 조회 → 제목/본문/라벨 확인, UI 타입 분류
2. 구체적 변경 항목이 명시되어 있으므로 → 바로 코드베이스 분석
3. 변경이 페이지 컴포넌트와 공용 훅 두 모듈에 걸치므로 Explore 에이전트 2개 스폰 (관련 파일 + 컨벤션), 보고된 경로·줄번호를 직접 Read로 확인
4. 구현 계획 작성 → `docs/plans/issue-42-profile-page-refactor.md`, 자기점검 통과
5. 사용자에게 계획 제시 + 외부 액션 승인 요청
6. 승인 후: 레포 CLAUDE.md가 worktree를 요구하므로 `gh issue develop --name`으로 원격 브랜치 생성 → `git worktree add` → 상태 업데이트 → 코멘트 작성

### Example 2: 정보 부족한 feature 이슈

**사용자:** "이슈 #55 분석하고 계획 세워줘"

**동작:**
1. 이슈 조회 → "알림 기능 추가" 제목만, 본문에 구체적 내용 없음
2. feature 타입 판단 → 코드베이스에 알림 관련 코드가 전혀 없어 방향이 답에 따라 갈리므로 clarification 질문:
   - "어떤 종류의 알림인가요?" (푸시 알림 / 인앱 알림 / 이메일)
   - "알림 트리거 조건이 있나요?" (운세 업데이트 / 이벤트 / 커스텀)
   - "UI 레퍼런스가 있나요?" (디자인 파일 / 기존 앱 참고 / 자유)
3. 사용자 답변 반영하여 코드베이스 분석
4. 구체적 계획 수립 후 진행

### Example 3: 단일 파일 버그, 프로젝트 미연결 이슈

**사용자:** "github.com/myorg/myrepo/issues/15 플래닝해줘"

**동작:**
1. 이슈 조회 → 재현 단계와 기대 동작이 명확한 bug, projectItems가 빈 배열
2. 스택 트레이스가 파일 하나를 가리키므로 에이전트 없이 직접 Grep/Read로 탐색
3. 계획 수립 (검증 명령은 레포 CLAUDE.md에서 인용)
4. 브랜치 생성 (CLAUDE.md에 worktree 규칙이 없으므로 `gh issue develop --checkout`)
5. Projects v2 상태 변경 → 건너뜀 ("프로젝트에 연결되지 않아 상태 변경을 건너뜁니다")
6. 이슈 코멘트 작성
