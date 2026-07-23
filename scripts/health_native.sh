#!/usr/bin/env bash
# ============================================================
# OfflineGPT — Native Health Check (llama.cpp Backend)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "🩺 OfflineGPT Native Health Check (llama.cpp Backend)"
echo "============================================================"

check_port() {
    local name="$1"
    local port="$2"
    if curl -sI "http://localhost:${port}" >/dev/null 2>&1 || curl -s "http://localhost:${port}/health" >/dev/null 2>&1 || curl -s "http://localhost:${port}/v1/models" >/dev/null 2>&1; then
        echo "✅ ${name} (Port ${port}) — RUNNING"
    else
        echo "❌ ${name} (Port ${port}) — NOT RESPONDING"
    fi
}

check_port "llama.cpp AI Engine" 8080
check_port "Open WebUI Chat" 67
check_port "Admin Dashboard" 68

echo ""
if command -v nvidia-smi &>/dev/null; then
    echo "🎮 GPU Status:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader
fi
echo "============================================================"
