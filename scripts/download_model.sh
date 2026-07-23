#!/bin/bash
# ============================================================
# OfflineGPT - Model Downloader
# ============================================================
# This script downloads AI models from Hugging Face.
# Run this BEFORE placing the server in an air-gapped network.
#
# Usage:
#   bash scripts/download_model.sh
#   bash scripts/download_model.sh <HUGGING_FACE_MODEL_URL>
#
# Examples:
#   bash scripts/download_model.sh
#   bash scripts/download_model.sh https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF/resolve/main/qwen2.5-7b-instruct-q4_k_m.gguf
# ============================================================

set -e

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_DIR/models"

# Create models directory if it doesn't exist
mkdir -p "$MODELS_DIR"

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           OfflineGPT - AI Model Downloader               ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Pre-configured model options (all Q4_K_M for efficient VRAM)
declare -A MODELS
MODELS["1,name"]="Phi-4-mini-instruct (Recommended - Microsoft 3.8B Fast & Accurate)"
MODELS["1,url"]="https://huggingface.co/unsloth/phi-4-mini-instruct-GGUF/resolve/main/phi-4-mini-instruct-Q4_K_M.gguf"
MODELS["1,file"]="phi-4-mini-instruct-Q4_K_M.gguf"

MODELS["2,name"]="Qwen2.5-7B-Instruct (Alibaba 7B)"
MODELS["2,url"]="https://huggingface.co/bartowski/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf"
MODELS["2,file"]="Qwen2.5-7B-Instruct-Q4_K_M.gguf"

MODELS["3,name"]="Llama-3.1-8B-Instruct (Meta's 8B)"
MODELS["3,url"]="https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"
MODELS["3,file"]="Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf"


# If user provided argument, check if it's a URL or choice number
if [ -n "$1" ]; then
    if [[ "$1" =~ ^https?:// ]]; then
        DOWNLOAD_URL="$1"
        FILENAME=$(basename "$DOWNLOAD_URL")
    elif [[ "$1" =~ ^[1-3]$ ]]; then
        CHOICE="$1"
        DOWNLOAD_URL="${MODELS["$CHOICE,url"]}"
        FILENAME="${MODELS["$CHOICE,file"]}"
    fi

    echo -e "${BLUE}Downloading model...${NC}"
    echo -e "  URL:  ${YELLOW}$DOWNLOAD_URL${NC}"
    echo -e "  File: ${YELLOW}$FILENAME${NC}"
    echo ""

    if [ -f "$MODELS_DIR/$FILENAME" ]; then
        echo -e "${YELLOW}⚠  File exists ($MODELS_DIR/$FILENAME). Resuming download if incomplete...${NC}"
    fi

    echo -e "${BLUE}⬇  Downloading... (this may take 2-5 minutes)${NC}"
    wget -c --show-progress -O "$MODELS_DIR/$FILENAME" "$DOWNLOAD_URL"
    echo ""
    echo -e "${GREEN}✅ Download complete!${NC}"
    echo -e "   Model saved to: ${CYAN}$MODELS_DIR/$FILENAME${NC}"
    echo ""

    # Auto-update .env if needed
    source "$PROJECT_DIR/.env" 2>/dev/null || true
    if [ "$MODEL_FILE" != "$FILENAME" ]; then
        echo -e "${YELLOW}📝 Updating .env with: MODEL_FILE=$FILENAME${NC}"
        sed -i "s|^MODEL_FILE=.*|MODEL_FILE=$FILENAME|" "$PROJECT_DIR/.env"
        echo -e "${GREEN}✓  .env updated automatically.${NC}"
    fi
    exit 0
fi

# Interactive model selection
echo -e "${BLUE}Available models (optimized for 12GB VRAM GPU):${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} ${MODELS["1,name"]}"
echo -e "  ${GREEN}2)${NC} ${MODELS["2,name"]}"
echo -e "  ${GREEN}3)${NC} ${MODELS["3,name"]}"
echo -e "  ${GREEN}4)${NC} Enter a custom download URL"
echo ""

read -p "Choose a model (1-4) [default: 1]: " CHOICE
CHOICE=${CHOICE:-1}

if [ "$CHOICE" == "4" ]; then
    echo ""
    read -p "Enter the full download URL for the .gguf file: " CUSTOM_URL
    if [ -z "$CUSTOM_URL" ]; then
        echo -e "${RED}✗  No URL provided. Exiting.${NC}"
        exit 1
    fi
    DOWNLOAD_URL="$CUSTOM_URL"
    FILENAME=$(basename "$DOWNLOAD_URL")
elif [[ "$CHOICE" =~ ^[1-3]$ ]]; then
    DOWNLOAD_URL="${MODELS["$CHOICE,url"]}"
    FILENAME="${MODELS["$CHOICE,file"]}"
    echo ""
    echo -e "${BLUE}Selected: ${MODELS["$CHOICE,name"]}${NC}"
else
    echo -e "${RED}✗  Invalid choice. Exiting.${NC}"
    exit 1
fi

echo -e "  File: ${YELLOW}$FILENAME${NC}"
echo ""

# Check if already downloaded
if [ -f "$MODELS_DIR/$FILENAME" ]; then
    FILE_SIZE=$(du -h "$MODELS_DIR/$FILENAME" | cut -f1)
    echo -e "${YELLOW}⚠  File already exists: $FILENAME ($FILE_SIZE)${NC}"
    read -p "   Overwrite? (y/N): " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✓  Using existing file.${NC}"
        echo ""
        echo -e "${YELLOW}📝 Make sure .env has:${NC}"
        echo -e "   MODEL_FILE=$FILENAME"
        exit 0
    fi
fi

# Check for wget
if ! command -v wget &> /dev/null; then
    echo -e "${RED}✗  'wget' is not installed.${NC}"
    echo -e "   Install it with: ${CYAN}sudo apt install wget${NC}"
    exit 1
fi

echo -e "${BLUE}⬇  Downloading... (this may take 10-30 minutes depending on internet speed)${NC}"
echo ""
wget -c --show-progress -O "$MODELS_DIR/$FILENAME" "$DOWNLOAD_URL"

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Model downloaded successfully!                      ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "   Model saved to: ${CYAN}$MODELS_DIR/$FILENAME${NC}"
echo ""

# Auto-update .env if the filename is different
source "$PROJECT_DIR/.env" 2>/dev/null || true
if [ "$MODEL_FILE" != "$FILENAME" ]; then
    echo -e "${YELLOW}📝 Updating .env with: MODEL_FILE=$FILENAME${NC}"
    sed -i "s|^MODEL_FILE=.*|MODEL_FILE=$FILENAME|" "$PROJECT_DIR/.env"
    echo -e "${GREEN}✓  .env updated automatically.${NC}"
fi

echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Start the server: ${GREEN}bash scripts/start.sh${NC}"
echo ""
