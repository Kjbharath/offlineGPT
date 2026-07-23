#!/usr/bin/env bash
# ============================================================
# OfflineGPT — Native Start Launcher (No-Docker)
# ============================================================
# Launches Ollama, Open WebUI, and Admin Dashboard natively in background
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Load environment variables from .env if present
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

CHAT_PORT="${PORT:-67}"
DASH_PORT="${DASHBOARD_PORT:-68}"
DASH_PWD="${DASHBOARD_PASSWORD:-admin123}"
MODEL="${MODEL_FILE:-phi4-mini}"

mkdir -p "$PROJECT_ROOT/data/pids" "$PROJECT_ROOT/data/logs"

echo "============================================================"
echo "🚀 Starting OfflineGPT (Native Portable Deployment)"
echo "============================================================"

# Check venv
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    echo "⚠️ Python virtual environment not found. Running setup..."
    bash "$SCRIPT_DIR/setup_native.sh"
fi

source "$PROJECT_ROOT/venv/bin/activate"

# 1. Start Ollama AI Engine
echo "🧠 [1/3] Starting Ollama AI Engine (Port 11434)..."
export OLLAMA_HOST="0.0.0.0:11434"
export OLLAMA_MODELS="$PROJECT_ROOT/models"
export LD_LIBRARY_PATH="$PROJECT_ROOT/bin/lib/ollama:$LD_LIBRARY_PATH"

if [ -f "$PROJECT_ROOT/bin/ollama" ]; then
    nohup "$PROJECT_ROOT/bin/ollama" serve > "$PROJECT_ROOT/data/logs/ollama.log" 2>&1 &
    echo $! > "$PROJECT_ROOT/data/pids/ollama.pid"
    echo "   Ollama started (PID: $(cat "$PROJECT_ROOT/data/pids/ollama.pid"))"
else
    echo "❌ Binary ./bin/ollama not found!"
    exit 1
fi

# 2. Start Open WebUI Chat Interface
echo "💬 [2/3] Starting Open WebUI Chat Interface (Port ${CHAT_PORT})..."
export DATA_DIR="$PROJECT_ROOT/data"
export WEBUI_SECRET_KEY="${WEBUI_SECRET_KEY:-OfflineGPT-SecureKey}"
export OLLAMA_BASE_URL="http://127.0.0.1:11434"
export ENABLE_SIGNUP="${ENABLE_SIGNUP:-true}"
export DEFAULT_USER_ROLE="user"
export WEBUI_NAME="Open WebUI"

nohup open-webui serve --port "$CHAT_PORT" > "$PROJECT_ROOT/data/logs/webui.log" 2>&1 &
echo $! > "$PROJECT_ROOT/data/pids/webui.pid"
echo "   Open WebUI started (PID: $(cat "$PROJECT_ROOT/data/pids/webui.pid"))"

# 3. Start Admin Dashboard
echo "🎛️ [3/3] Starting Admin Dashboard (Port ${DASH_PORT})..."
export DASHBOARD_PASSWORD="$DASH_PWD"
export OLLAMA_URL="http://127.0.0.1:11434"
export WEBUI_DB_PATH="$PROJECT_ROOT/data/webui.db"
export ENV_FILE_PATH="$PROJECT_ROOT/.env"

nohup python3 "$PROJECT_ROOT/dashboard/app.py" > "$PROJECT_ROOT/data/logs/dashboard.log" 2>&1 &
echo $! > "$PROJECT_ROOT/data/pids/dashboard.pid"
echo "   Admin Dashboard started (PID: $(cat "$PROJECT_ROOT/data/pids/dashboard.pid"))"

echo ""
echo "============================================================"
echo "🎉 OfflineGPT Services Started Successfully!"
echo "============================================================"
echo "💬 User Chat UI:       http://localhost:${CHAT_PORT} (or http://ai.local:${CHAT_PORT})"
echo "🎛️ Admin Dashboard:    http://localhost:${DASH_PORT} (or http://ai.local:${DASH_PORT})"
echo "🧠 Ollama API Engine:   http://localhost:11434"
echo "============================================================"
echo "To stop services:      bash scripts/stop_native.sh"
echo "To view logs:          tail -f data/logs/*.log"
echo "============================================================"
