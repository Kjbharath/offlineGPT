#!/bin/bash
# ============================================================
# OfflineGPT - Server Starter
# ============================================================
# This script checks everything is ready, then starts the
# AI chat server. Users can then open their browser to chat.
#
# Usage:  bash scripts/start.sh
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              OfflineGPT - Server Startup                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

ERRORS=0

# --- Check 1: Docker ---
echo -e "${BLUE}[1/5]${NC} Checking Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} $DOCKER_VERSION"
else
    echo -e "  ${RED}✗  Docker is NOT installed!${NC}"
    echo -e "      See README.md → Step 1 for installation instructions."
    ERRORS=$((ERRORS + 1))
fi

# --- Check 2: Docker Compose ---
echo -e "${BLUE}[2/5]${NC} Checking Docker Compose..."
if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} $COMPOSE_VERSION"
else
    echo -e "  ${RED}✗  Docker Compose is NOT available!${NC}"
    echo -e "      Install it with: sudo apt install docker-compose-plugin"
    ERRORS=$((ERRORS + 1))
fi

# --- Check 3: NVIDIA GPU ---
echo -e "${BLUE}[3/5]${NC} Checking NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} $GPU_NAME ($GPU_VRAM)"
else
    echo -e "  ${RED}✗  NVIDIA GPU driver NOT found!${NC}"
    echo -e "      See README.md → Step 2 for installation instructions."
    ERRORS=$((ERRORS + 1))
fi

# --- Check 4: NVIDIA Container Toolkit ---
echo -e "${BLUE}[4/5]${NC} Checking NVIDIA Container Toolkit..."
if docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} GPU is accessible inside Docker containers"
else
    echo -e "  ${RED}✗  GPU is NOT accessible in Docker!${NC}"
    echo -e "      See README.md → Step 3 for NVIDIA Container Toolkit setup."
    ERRORS=$((ERRORS + 1))
fi

# --- Check 5: Model file ---
echo -e "${BLUE}[5/5]${NC} Checking AI model file..."
source "$PROJECT_DIR/.env" 2>/dev/null || true
MODEL_PATH="$PROJECT_DIR/models/${MODEL_FILE:-not_set}"
if [ -f "$MODEL_PATH" ]; then
    MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo -e "  ${GREEN}✓${NC} Found: $MODEL_FILE ($MODEL_SIZE)"
else
    echo -e "  ${RED}✗  Model file NOT found: ${MODEL_FILE:-'(not set in .env)'}${NC}"
    echo -e "      Download a model first: ${CYAN}bash scripts/download_model.sh${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Stop if there are errors
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ✗  $ERRORS problem(s) found. Fix them before starting.   ${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    exit 1
fi

# All checks passed - start the server
echo -e "${GREEN}All checks passed! Starting OfflineGPT...${NC}"
echo ""

# Navigate to project directory and start containers
cd "$PROJECT_DIR"
docker compose up -d

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  OfflineGPT is starting up!                           ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get server IP addresses
echo -e "${BOLD}📡 Access the chat interface at:${NC}"
echo ""

# Show all non-loopback IPs
for IP in $(hostname -I 2>/dev/null); do
    echo -e "   ${CYAN}➜${NC}  http://${IP}:${PORT:-3000}"
done
echo -e "   ${CYAN}➜${NC}  http://localhost:${PORT:-3000}  (from this computer)"
echo ""

echo -e "${YELLOW}⏳ Note: The AI model takes 1-3 minutes to load into the GPU.${NC}"
echo -e "   The chat page may show 'loading' until the model is ready."
echo ""
echo -e "${BLUE}Useful commands:${NC}"
echo -e "   View logs:     ${CYAN}docker compose logs -f${NC}"
echo -e "   Stop server:   ${CYAN}docker compose down${NC}"
echo -e "   Health check:  ${CYAN}bash scripts/health_check.sh${NC}"
echo ""
