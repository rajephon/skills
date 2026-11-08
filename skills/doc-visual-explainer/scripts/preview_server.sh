#!/usr/bin/env bash
# Serve a copy of one HTML file over http://127.0.0.1 so Playwright can open it
# (Playwright MCP blocks file:// URLs).
#
#   preview_server.sh start <file.html> [port]   -> prints the URL (exit 1 if it could not start)
#   preview_server.sh stop
#
# The file is copied into a temp dir as index.html, so nothing else in the
# source folder is exposed. `stop` kills the server and removes the temp dir.
set -euo pipefail

STATE_DIR="${TMPDIR:-/tmp}/doc-visual-explainer-preview"
PID_FILE="$STATE_DIR.pid"

responds() { curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$1/"; }

case "${1:-}" in
  start)
    file="${2:?usage: preview_server.sh start <file.html> [port]}"
    port="${3:-8765}"
    [ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
    if [ -f "$PID_FILE" ]; then
      kill "$(cat "$PID_FILE")" 2>/dev/null || true
      rm -f "$PID_FILE"
      sleep 0.3
    fi
    # Something else already answers on this port: our server would fail to bind and the
    # URL would show that other server's content instead of the page.
    if responds "$port"; then
      echo "port $port is already in use; pick another: preview_server.sh start <file.html> <port>" >&2
      exit 1
    fi
    rm -rf "$STATE_DIR"; mkdir -p "$STATE_DIR"
    cp "$file" "$STATE_DIR/index.html"
    # Start the server process itself in the background (no wrapping subshell), with all
    # standard streams detached, so `$(preview_server.sh start ...)` returns immediately
    # and $! is the server's own PID.
    nohup python3 -m http.server "$port" --bind 127.0.0.1 --directory "$STATE_DIR" </dev/null >/dev/null 2>&1 &
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
      rm -rf "$STATE_DIR" "$PID_FILE"
      echo "preview server did not start on port $port" >&2
      exit 1
    fi
    echo "http://127.0.0.1:$port/"
    ;;
  stop)
    if [ -f "$PID_FILE" ]; then kill "$(cat "$PID_FILE")" 2>/dev/null || true; fi
    rm -rf "$STATE_DIR" "$PID_FILE"
    echo "stopped"
    ;;
  *)
    echo "usage: preview_server.sh start <file.html> [port] | stop" >&2
    exit 2
    ;;
esac
