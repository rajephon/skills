#!/usr/bin/env bash
# Codex CLI 위탁 실행 래퍼.
#
# 사용법: codex_run.sh <run-dir> <workdir> <prompt-file> [effort] [model]
#   run-dir      로그·결과를 저장할 디렉토리 (없으면 생성)
#   workdir      Codex가 작업할 저장소 루트 (worktree 경로 가능)
#   prompt-file  위탁 프롬프트가 담긴 파일
#   effort       model_reasoning_effort (기본: high)
#   model        모델 오버라이드 (생략 시 ~/.codex/config.toml의 설정 사용)
#
# 산출물:
#   <run-dir>/run.log          전체 실행 로그 (상단 배너에 session id 포함)
#   <run-dir>/last-message.md  Codex의 최종 보고
#   <run-dir>/exit-code        종료 코드
set -u

if [[ $# -lt 3 ]]; then
  echo "usage: codex_run.sh <run-dir> <workdir> <prompt-file> [effort] [model]" >&2
  exit 2
fi

RUN_DIR="$1"; WORKDIR="$2"; PROMPT_FILE="$3"
EFFORT="${4:-high}"; MODEL="${5:-}"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "prompt file not found: $PROMPT_FILE" >&2
  exit 2
fi
mkdir -p "$RUN_DIR"

MODEL_ARGS=()
if [[ -n "$MODEL" ]]; then MODEL_ARGS=(-m "$MODEL"); fi

# ${MODEL_ARGS[@]+...} : macOS 기본 bash 3.2에서 빈 배열 + set -u 조합의 unbound 오류 회피
codex exec \
  -C "$WORKDIR" \
  -s workspace-write \
  -c model_reasoning_effort="$EFFORT" \
  ${MODEL_ARGS[@]+"${MODEL_ARGS[@]}"} \
  --output-last-message "$RUN_DIR/last-message.md" \
  - < "$PROMPT_FILE" > "$RUN_DIR/run.log" 2>&1
EXIT=$?

echo "$EXIT" > "$RUN_DIR/exit-code"
if [[ "$EXIT" -ne 0 ]]; then
  echo "codex exec failed (exit $EXIT). see $RUN_DIR/run.log" >&2
else
  echo "codex exec done. report: $RUN_DIR/last-message.md"
fi
exit "$EXIT"
