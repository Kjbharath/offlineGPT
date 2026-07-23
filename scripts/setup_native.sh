#!/usr/bin/env bash
# ============================================================
# OfflineGPT — Native Setup Script (No-Docker)
# ============================================================
# Sets up Python virtual environment and downloads offline pip wheels
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "============================================================"
echo "🚀 OfflineGPT Native Setup (No-Docker Portable Deployment)"
echo "============================================================"

# 1. Check Python
if ! command -v python3 &>/dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "Please ask your system admin or run: sudo apt install python3 python3-venv python3-pip"
    exit 1
fi

echo "✅ Python version: $(python3 --version)"

# 2. Create Python Virtual Environment (venv)
if [ ! -d "$PROJECT_ROOT/venv" ]; then
    echo "📦 Creating Python virtual environment in ./venv..."
    python3 -m venv "$PROJECT_ROOT/venv" || {
        echo "⚠️ Failed to create venv. Trying with --without-pip..."
        python3 -m venv --without-pip "$PROJECT_ROOT/venv"
    }
else
    echo "✅ Python virtual environment already exists at ./venv"
fi

# Activate venv
source "$PROJECT_ROOT/venv/bin/activate"

# Ensure pip is installed inside venv
if ! command -v pip &>/dev/null; then
    echo "📦 Bootstrapping pip inside venv..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python
fi

# 3. Install Open WebUI and Dashboard requirements
echo "📦 Installing Open WebUI & Dashboard dependencies into local venv..."

# Try installing from offline pip_wheels if present, else install online & cache to pip_wheels
if [ -d "$PROJECT_ROOT/pip_wheels" ] && [ "$(ls -A "$PROJECT_ROOT/pip_wheels" 2>/dev/null)" ]; then
    echo "📡 Found offline wheels in ./pip_wheels/ — Installing offline..."
    pip install --no-index --find-links="$PROJECT_ROOT/pip_wheels" open-webui fastapi "uvicorn[standard]" psutil python-multipart pyjwt httpx jinja2
else
    echo "🌐 Downloading & caching wheels into ./pip_wheels for offline transfer..."
    mkdir -p "$PROJECT_ROOT/pip_wheels"
    pip wheel --wheel-dir="$PROJECT_ROOT/pip_wheels" open-webui fastapi "uvicorn[standard]" psutil python-multipart pyjwt httpx jinja2
    pip install --find-links="$PROJECT_ROOT/pip_wheels" open-webui fastapi "uvicorn[standard]" psutil python-multipart pyjwt httpx jinja2

fi

echo ""
echo "============================================================"
echo "🎉 Native Setup Complete!"
echo "You can now run: bash scripts/start_native.sh"
echo "============================================================"
