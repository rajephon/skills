#!/usr/bin/env bash
# Serve a copy of one HTML file over http://127.0.0.1 so Playwright can open it
# (Playwright MCP blocks file:// URLs).
#
#   preview_server.sh start <file.html> [port]   -> prints the URL (exit 1 if it could not start)
#   preview_server.sh stop
#
# The file is copied into a private state dir as index.html, so nothing else in the
# source folder is exposed. `stop` kills the server and removes the state dir.
set -euo pipefail

# Per-user state dir (mode 700, owned by us). When TMPDIR is unset the base is the shared
# /tmp, so a fixed name there could be pre-created or symlinked by another local user to
# redirect our writes or plant a PID for us to kill. We refuse any dir we do not own.
BASE="${TMPDIR:-/tmp}"
BASE="${BASE%/}/doc-visual-explainer-preview-$(id -u)"
SITE_DIR="$BASE/site"
PID_FILE="$BASE/server.pid"

responds() { curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$1/"; }

base_is_ours() { [ -d "$BASE" ] && [ ! -L "$BASE" ] && [ -O "$BASE" ]; }

ensure_base() {
  [ -e "$BASE" ] || [ -L "$BASE" ] || mkdir -m 700 "$BASE" 2>/dev/null || true
  if ! base_is_ours; then
    echo "refusing to use $BASE: not a directory owned by $(id -un)" >&2
    exit 1
  fi
  chmod 700 "$BASE"
}

# Kill only the http.server this script started for SITE_DIR: the PID file may be stale
# and its number reused by an unrelated process.
stop_server() {
  [ -f "$PID_FILE" ] || return 0
  local pid cmd
  pid="$(cat "$PID_FILE")"
  cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
  case "$cmd" in
    *http.server*"$SITE_DIR"*) kill "$pid" 2>/dev/null || true; sleep 0.3 ;;
  esac
  rm -f "$PID_FILE"
}

case "${1:-}" in
  start)
    file="${2:?usage: preview_server.sh start <file.html> [port]}"
    port="${3:-8765}"
    [ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
    ensure_base
    stop_server
    # Something else already answers on this port: our server would fail to bind and the
    # URL would show that other server's content instead of the page.
    if responds "$port"; then
      echo "port $port is already in use; pick another: preview_server.sh start <file.html> <port>" >&2
      exit 1
    fi
    rm -rf "$SITE_DIR"; mkdir -m 700 "$SITE_DIR"
    cp "$file" "$SITE_DIR/index.html"
    # Start the server process itself in the background (no wrapping subshell), with all
    # standard streams detached, so `$(preview_server.sh start ...)` returns immediately
    # and $! is the server's own PID.
    nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$SITE_DIR" </dev/null >/dev/null 2>&1 &
    pid=$!
    echo "$pid" > "$PID_FILE"
    ok=""
    for _ in $(seq 1 20); do
      kill -0 "$pid" 2>/dev/null || break
      if responds "$port"; then ok=1; break; fi
      sleep 0.2
    done
    if [ -z "$ok" ] || ! kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      rm -rf "$SITE_DIR" "$PID_FILE"
      echo "preview server did not start on port $port" >&2
      exit 1
    fi
    echo "http://127.0.0.1:$port/"
    ;;
  stop)
    if base_is_ours; then
      stop_server
      rm -rf "$BASE"
    fi
    echo "stopped"
    ;;
  *)
    echo "usage: preview_server.sh start <file.html> [port] | stop" >&2
    exit 2
    ;;
esac
