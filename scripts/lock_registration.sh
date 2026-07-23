#!/bin/bash
# ============================================================
# OfflineGPT - Lock Registration
# ============================================================
# Run this script AFTER all team members have created their
# accounts. It disables the "Sign Up" button so no new
# users can register.
#
# Usage:  bash scripts/lock_registration.sh
#
# To re-enable registration later:
#   bash scripts/lock_registration.sh --unlock
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"

echo ""

if [ "$1" == "--unlock" ]; then
    # Re-enable registration
    echo -e "${YELLOW}🔓 Re-enabling user registration...${NC}"
    sed -i "s|^ENABLE_SIGNUP=.*|ENABLE_SIGNUP=true|" "$ENV_FILE"
    echo -e "${GREEN}✓  Registration is now OPEN.${NC}"
    echo -e "   New users can create accounts again."
else
    # Lock registration
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         OfflineGPT - Lock User Registration              ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}⚠  This will DISABLE new user registration.${NC}"
    echo -e "   Existing accounts will NOT be affected."
    echo ""
    read -p "Are you sure? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo -e "Cancelled."
        exit 0
    fi

    sed -i "s|^ENABLE_SIGNUP=.*|ENABLE_SIGNUP=false|" "$ENV_FILE"
    echo ""
    echo -e "${GREEN}✓  Registration is now LOCKED.${NC}"
    echo -e "   No new accounts can be created."
fi

echo ""
echo -e "${BLUE}Restarting Open WebUI to apply changes...${NC}"
cd "$PROJECT_DIR"
docker compose up -d open-webui
echo ""
echo -e "${GREEN}✅ Done! Changes are now active.${NC}"
echo ""
echo -e "   To undo: ${CYAN}bash scripts/lock_registration.sh --unlock${NC}"
echo ""
