# 병렬 오케스트레이션 절차

여러 Codex 에이전트가 같은 저장소를 동시에 수정하면 반드시 충돌합니다. git worktree로 각 태스크에 독립된 작업 사본과 브랜치를 주고, 완료 후 Claude가 통합합니다.

## 1. 분할 확정

- SKILL.md 1단계의 기준(파일 겹침 없음, 순서 의존성 없음, 독립 테스트 가능)을 통과한 2~4개 태스크로 분할.
- **파일 소유권 표**를 만드세요: 태스크별로 수정 허용 파일/디렉토리를 나열하고 겹침이 없는지 확인. 겹치는 파일이 나오면 그 파일을 공유 계약으로 승격시켜 선처리하거나, 두 태스크를 하나로 합치세요.
- 공유 계약(스키마, API 명세, 공용 타입, 라우트 인덱스)은 worktree 생성 **전에** 확정하고 base 브랜치에 반영해 두세요. 그래야 모든 worktree가 확정된 계약 위에서 출발합니다.

## 2. worktree 준비

현재 작업 브랜치(base)에서 태스크별 worktree를 만듭니다. worktree는 scratchpad 아래에 두세요 — 저장소 내부에 만들면 파일 탐색·빌드 도구가 오염됩니다.

```bash
git -C <repo> worktree add <scratchpad>/wt-<task> -b codex/<task>
```

주의: 미커밋 변경(스테이징 포함)은 worktree에 복사되지 않습니다. 공유 계약 선처리분이 미커밋 상태라면 worktree 생성 전에 커밋하거나 사용자와 처리 방법을 합의하세요.

의존성 설치가 필요한 프로젝트라면 각 worktree에서 설치를 먼저 실행하세요 (예: `pnpm install` — pnpm은 하드링크를 써서 비용이 작습니다). Codex가 테스트를 실행하려면 필요합니다.

## 3. 병렬 실행

태스크별로 프롬프트 파일을 작성한 뒤(작성 원칙은 `delegation-prompt.md`), **같은 턴에** 모두 백그라운드로 스폰합니다:

```bash
# 각각 별도의 Bash 호출, run_in_background: true
bash ~/.claude/skills/codex-delegate/scripts/codex_run.sh \
  <scratchpad>/codex-runs/<task> <scratchpad>/wt-<task> \
  <scratchpad>/codex-runs/<task>/prompt.md high
```

## 4. 완료 처리와 부분 실패

- 완료 알림이 오는 대로 해당 태스크의 `last-message.md`와 `exit-code`를 확인하고, worktree에서 `git -C <worktree> diff`로 1차 리뷰하세요. 다른 태스크를 기다리며 놀지 않습니다.
- 실패한 태스크는 `run.log`에서 원인을 파악해 `codex exec resume <session-id>`(session id는 run.log 배너)로 재지시하세요. 같은 문제로 2회 실패하면 Claude가 해당 worktree에서 직접 마무리합니다.
- 한 태스크의 실패가 다른 태스크의 결과를 무효화하지 않습니다 — 성공분은 정상 통합 절차로 진행하세요.

## 5. 통합

병합은 커밋 단위로 이뤄집니다. 각 worktree에서 검증(테스트 통과)을 마친 뒤, 변경이 미커밋 상태라면 해당 worktree에서 커밋하세요:

```bash
git -C <worktree> add -A && git -C <worktree> commit -m "<task 요약>"
```

그다음 base 브랜치(원래 작업 브랜치)로 순차 병합합니다:

```bash
git -C <repo> merge --no-ff codex/<task1>
git -C <repo> merge --no-ff codex/<task2>
```

- 순서는 의존성이 없다는 전제이므로 임의여도 되지만, 변경량이 큰 것부터 병합하면 충돌 파악이 쉽습니다.
- 충돌이 나면 Claude가 직접 해결합니다 (파일 소유권 분할이 제대로 됐다면 충돌은 거의 없어야 정상 — 충돌이 많다면 분할이 잘못된 것이니 다음 위탁에서 교훈으로 반영).
- **병합 완료 후 전체 테스트·빌드를 반드시 다시 실행하세요.** 태스크별로는 통과해도 합치면 깨질 수 있습니다 (예: 둘 다 같은 유틸을 다른 시그니처로 추가).

## 6. 정리

```bash
git -C <repo> worktree remove <scratchpad>/wt-<task>
git -C <repo> branch -d codex/<task>   # 병합 확인 후
```

실패해서 병합하지 않은 브랜치는 지우지 말고 사용자에게 보고 시 언급하세요.
