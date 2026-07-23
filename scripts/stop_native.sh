#!/usr/bin/env bash
# ============================================================
# OfflineGPT — Native Stop Script (llama.cpp Backend)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "============================================================"
echo "🛑 Stopping OfflineGPT Native Services..."
echo "============================================================"

# Stop PIDs from pidfiles
PID_DIR="$PROJECT_ROOT/data/pids"
if [ -d "$PID_DIR" ]; then
    for pidfile in "$PID_DIR"/*.pid; do
        if [ -f "$pidfile" ]; then
            pid=$(cat "$pidfile")
            name=$(basename "$pidfile" .pid)
            if kill -0 "$pid" 2>/dev/null; then
                echo "Stopping $name (PID: $pid)..."
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pidfile"
        fi
    done
fi

# Kill any remaining instances owned by user
pkill -f "llama-server" 2>/dev/null || true
pkill -f "open-webui serve" 2>/dev/null || true
pkill -f "dashboard/app.py" 2>/dev/null || true
pkill -f "ollama serve" 2>/dev/null || true

echo "✅ All native OfflineGPT services stopped."
