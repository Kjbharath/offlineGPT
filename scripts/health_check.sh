#!/bin/bash
# ============================================================
# OfflineGPT - Health Check
# ============================================================
# Checks if all parts of OfflineGPT are running correctly.
# Run this if users report problems.
#
# Usage:  bash scripts/health_check.sh
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$PROJECT_DIR/.env" 2>/dev/null || true

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             OfflineGPT - Health Check                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES=0

# --- Check 1: Docker containers running ---
echo -e "${BLUE}[1/5]${NC} Docker containers..."
LLAMA_STATUS=$(docker inspect -f '{{.State.Status}}' offlinegpt-llama-server 2>/dev/null || echo "not found")
WEBUI_STATUS=$(docker inspect -f '{{.State.Status}}' offlinegpt-webui 2>/dev/null || echo "not found")

if [ "$LLAMA_STATUS" == "running" ]; then
    echo -e "  ${GREEN}✓${NC} llama-server: running"
else
    echo -e "  ${RED}✗${NC} llama-server: $LLAMA_STATUS"
    ISSUES=$((ISSUES + 1))
fi

if [ "$WEBUI_STATUS" == "running" ]; then
    echo -e "  ${GREEN}✓${NC} open-webui: running"
else
    echo -e "  ${RED}✗${NC} open-webui: $WEBUI_STATUS"
    ISSUES=$((ISSUES + 1))
fi

# --- Check 2: GPU status ---
echo -e "${BLUE}[2/5]${NC} NVIDIA GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_UTIL=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    GPU_TEMP=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓${NC} $GPU_NAME"
    echo -e "      VRAM: $GPU_MEM_USED / $GPU_MEM_TOTAL"
    echo -e "      GPU Load: $GPU_UTIL | Temperature: ${GPU_TEMP}°C"
else
    echo -e "  ${RED}✗${NC} nvidia-smi not available"
    ISSUES=$((ISSUES + 1))
fi

# --- Check 3: llama-server health endpoint ---
echo -e "${BLUE}[3/5]${NC} AI Engine (llama-server)..."
LLAMA_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
if [ "$LLAMA_HEALTH" == "200" ]; then
    echo -e "  ${GREEN}✓${NC} llama-server API is healthy (HTTP 200)"
else
    # Try via docker network
    LLAMA_HEALTH_DOCKER=$(docker exec offlinegpt-webui curl -s -o /dev/null -w "%{http_code}" http://llama-server:8080/health 2>/dev/null || echo "000")
    if [ "$LLAMA_HEALTH_DOCKER" == "200" ]; then
        echo -e "  ${GREEN}✓${NC} llama-server API is healthy (internal network)"
    else
        echo -e "  ${RED}✗${NC} llama-server API not responding (HTTP $LLAMA_HEALTH)"
        echo -e "      The model may still be loading. Wait 2-3 minutes and try again."
        ISSUES=$((ISSUES + 1))
    fi
fi

# --- Check 4: Open WebUI ---
echo -e "${BLUE}[4/5]${NC} Chat Interface (Open WebUI)..."
WEBUI_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT:-3000} 2>/dev/null || echo "000")
if [ "$WEBUI_HEALTH" == "200" ] || [ "$WEBUI_HEALTH" == "303" ] || [ "$WEBUI_HEALTH" == "302" ]; then
    echo -e "  ${GREEN}✓${NC} Open WebUI is reachable (HTTP $WEBUI_HEALTH)"
else
    echo -e "  ${RED}✗${NC} Open WebUI not responding (HTTP $WEBUI_HEALTH)"
    echo -e "      Check logs: ${CYAN}docker compose logs open-webui${NC}"
    ISSUES=$((ISSUES + 1))
fi

# --- Check 5: Network accessibility ---
echo -e "${BLUE}[5/5]${NC} Network access..."
echo -e "  Your server IPs:"
for IP in $(hostname -I 2>/dev/null); do
    echo -e "    ${CYAN}➜${NC}  http://${IP}:${PORT:-3000}"
done

echo ""

# --- Summary ---
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ✅  Everything looks good! OfflineGPT is healthy.        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ⚠  $ISSUES issue(s) detected. See details above.         ${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo -e "  • View container logs:  ${CYAN}docker compose logs -f${NC}"
    echo -e "  • Restart everything:   ${CYAN}docker compose down && bash scripts/start.sh${NC}"
    echo -e "  • Check GPU in Docker:  ${CYAN}docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu24.04 nvidia-smi${NC}"
fi
echo ""
