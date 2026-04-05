#!/usr/bin/env bash
# ============================================================
# OllamaBox Setup - runs inside the WSL Ubuntu instance
# Installs Ollama, picks a model, launches Open WebUI
# ============================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

banner() {
    echo ""
    echo -e "${CYAN}=========================================${RESET}"
    echo -e "${CYAN}  $1${RESET}"
    echo -e "${CYAN}=========================================${RESET}"
    echo ""
}

step() {
    echo -e "${GREEN}[$1]${RESET} $2"
}

warn() {
    echo -e "${YELLOW}  WARNING: $1${RESET}"
}

fail() {
    echo -e "${RED}  ERROR: $1${RESET}"
    exit 1
}

# ============================================================
banner "OllamaBox Setup"
# ============================================================

# --------------------------------------------------
# Step 1: System dependencies
# --------------------------------------------------
step "1/6" "Installing system dependencies..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget git zstd python3 python3-pip python3-venv build-essential > /dev/null 2>&1

echo -e "       ${DIM}Done.${RESET}"

# --------------------------------------------------
# Step 2: Install Ollama
# --------------------------------------------------
step "2/6" "Installing Ollama..."

if command -v ollama &> /dev/null; then
    echo -e "       ${DIM}Ollama already installed.${RESET}"
else
    curl -fsSL https://ollama.com/install.sh | bash
fi

# Start Ollama if not running
if curl -s http://127.0.0.1:11434/ > /dev/null 2>&1; then
    echo -e "       ${DIM}Ollama is already running.${RESET}"
else
    echo -e "       ${DIM}Starting Ollama...${RESET}"
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
    if ! curl -s http://127.0.0.1:11434/ > /dev/null 2>&1; then
        fail "Ollama failed to start. Check /tmp/ollama.log"
    fi
fi

echo -e "       ${DIM}Done.${RESET}"

# --------------------------------------------------
# Step 3: Scan system resources
# --------------------------------------------------
step "3/6" "Scanning system resources..."

TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_MB / 1024))
CPU_CORES=$(nproc)
FREE_DISK_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')

HAS_GPU="no"
GPU_NAME="none"
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 || echo "none")
    if [ "$GPU_NAME" != "none" ] && [ -n "$GPU_NAME" ]; then
        HAS_GPU="yes"
        GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 || echo "0")
    fi
fi

echo -e "       RAM:        ${BOLD}${TOTAL_RAM_GB} GB${RESET}"
echo -e "       CPU cores:  ${BOLD}${CPU_CORES}${RESET}"
echo -e "       Free disk:  ${BOLD}${FREE_DISK_GB} GB${RESET}"
if [ "$HAS_GPU" = "yes" ]; then
    echo -e "       GPU:        ${BOLD}${GPU_NAME} (${GPU_VRAM} MB VRAM)${RESET}"
else
    echo -e "       GPU:        ${DIM}Not detected (CPU-only mode)${RESET}"
fi
echo ""

# --------------------------------------------------
# Step 4: Recommend and select a model
# --------------------------------------------------
step "4/6" "Selecting a model..."
echo ""

# Build model list based on available RAM
# Each entry: "model_tag|display_name|size_info|min_ram_gb"
MODELS=()
MODELS+=("tinyllama|TinyLlama 1.1B|~700 MB download|2")
MODELS+=("phi3:mini|Phi-3 Mini 3.8B|~2.3 GB download|4")
MODELS+=("llama3.1|Llama 3.1 8B|~4.7 GB download|8")
MODELS+=("gemma2|Gemma 2 9B|~5.4 GB download|10")
MODELS+=("mistral-nemo|Mistral Nemo 12B|~7.1 GB download|12")
MODELS+=("qwen2.5:14b|Qwen 2.5 14B|~8.7 GB download|16")
MODELS+=("llama3.1:70b|Llama 3.1 70B|~40 GB download|48")

# Find the best model that fits in RAM (leave ~2GB for system + Open WebUI)
AVAILABLE_FOR_MODEL=$((TOTAL_RAM_GB - 2))
RECOMMENDED_IDX=0

for i in "${!MODELS[@]}"; do
    IFS='|' read -r tag name size min_ram <<< "${MODELS[$i]}"
    if [ "$AVAILABLE_FOR_MODEL" -ge "$min_ram" ]; then
        RECOMMENDED_IDX=$i
    fi
done

# Display the menu
echo -e "  Based on your ${BOLD}${TOTAL_RAM_GB} GB RAM${RESET}, these models are available:"
echo ""

for i in "${!MODELS[@]}"; do
    IFS='|' read -r tag name size min_ram <<< "${MODELS[$i]}"

    if [ "$i" -eq "$RECOMMENDED_IDX" ]; then
        echo -e "  ${GREEN}>>> [$((i+1))] ${BOLD}${name}${RESET}${GREEN} — ${size} (RECOMMENDED)${RESET}"
    elif [ "$AVAILABLE_FOR_MODEL" -ge "$min_ram" ]; then
        echo -e "  ${RESET}    [$((i+1))] ${name} — ${size}${RESET}"
    else
        echo -e "  ${DIM}    [$((i+1))] ${name} — ${size} (needs ${min_ram}GB+ RAM)${RESET}"
    fi
done

echo ""
DEFAULT_NUM=$((RECOMMENDED_IDX + 1))

# Detect if running interactively (piped scripts have no terminal on stdin)
if [ -t 0 ]; then
    read -r -p "  Choose a model [1-${#MODELS[@]}] (default: ${DEFAULT_NUM}): " MODEL_CHOICE
    echo ""

    # Default to recommended
    if [ -z "$MODEL_CHOICE" ]; then
        MODEL_CHOICE=$DEFAULT_NUM
    fi

    # Validate
    if ! [[ "$MODEL_CHOICE" =~ ^[0-9]+$ ]] || [ "$MODEL_CHOICE" -lt 1 ] || [ "$MODEL_CHOICE" -gt "${#MODELS[@]}" ]; then
        warn "Invalid choice, using recommended model."
        MODEL_CHOICE=$DEFAULT_NUM
    fi
else
    echo -e "  ${DIM}Non-interactive mode detected, auto-selecting recommended model.${RESET}"
    echo ""
    MODEL_CHOICE=$DEFAULT_NUM
fi

SELECTED_IDX=$((MODEL_CHOICE - 1))
IFS='|' read -r SELECTED_TAG SELECTED_NAME SELECTED_SIZE SELECTED_MIN <<< "${MODELS[$SELECTED_IDX]}"

# Check disk space
NEEDED_DISK=${SELECTED_SIZE//[^0-9.]/}
NEEDED_DISK_INT=${NEEDED_DISK%.*}
if [ "$FREE_DISK_GB" -lt "$((NEEDED_DISK_INT + 5))" ]; then
    warn "You may not have enough disk space (${FREE_DISK_GB} GB free, model needs ~${NEEDED_DISK_INT} GB + overhead)."
    if [ -t 0 ]; then
        read -r -p "  Continue anyway? (y/N): " DISK_CONFIRM
        if [ "$DISK_CONFIRM" != "y" ] && [ "$DISK_CONFIRM" != "Y" ]; then
            fail "Aborted. Free up disk space and try again."
        fi
    else
        warn "Continuing anyway (non-interactive mode)."
    fi
fi

echo -e "  Pulling ${BOLD}${SELECTED_NAME}${RESET} (${SELECTED_SIZE})..."
echo -e "  ${DIM}This may take a few minutes depending on your connection.${RESET}"
echo ""

ollama pull "$SELECTED_TAG"

echo ""
echo -e "       ${DIM}Model ready.${RESET}"

# --------------------------------------------------
# Step 5: Install Open WebUI
# --------------------------------------------------
step "5/6" "Installing Open WebUI..."

# Create venv and data directory for Open WebUI
VENV_DIR="/opt/ollamabox/venv"
DATA_DIR="/opt/ollamabox/data"
mkdir -p /opt/ollamabox "$DATA_DIR"

if [ -d "$VENV_DIR" ]; then
    echo -e "       ${DIM}Virtual environment exists, reusing.${RESET}"
else
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"

pip install --upgrade pip -q
pip install open-webui -q

echo -e "       ${DIM}Done.${RESET}"

# --------------------------------------------------
# Create a reusable start script
# --------------------------------------------------
START_SCRIPT="$HOME/start-ollama.sh"
cat > "$START_SCRIPT" << 'STARTEOF'
#!/usr/bin/env bash
# Start OllamaBox services

GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

echo ""
echo -e "${CYAN}Starting OllamaBox...${RESET}"
echo ""

# Start Ollama if not running
if curl -s http://127.0.0.1:11434/ > /dev/null 2>&1; then
    echo -e "  Ollama:   ${GREEN}already running${RESET}"
else
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 2
    echo -e "  Ollama:   ${GREEN}started${RESET}"
fi

# Start Open WebUI
source /opt/ollamabox/venv/bin/activate
export DATA_DIR="/opt/ollamabox/data"
export HOME="/root"
cd /opt/ollamabox

echo -e "  Open WebUI: ${GREEN}starting...${RESET}"
echo ""
echo -e "${CYAN}=========================================${RESET}"
echo -e "${CYAN}  ${BOLD}Open this link in your browser:${RESET}"
echo ""
echo -e "  ${BOLD}http://localhost:8080${RESET}"
echo ""
echo -e "${CYAN}=========================================${RESET}"
echo -e "  ${GREEN}Press Ctrl+C to stop.${RESET}"
echo ""

open-webui serve --port 8080
STARTEOF
chmod +x "$START_SCRIPT"

# --------------------------------------------------
# Step 6: Launch!
# --------------------------------------------------
step "6/6" "Launching Open WebUI..."
echo ""

echo -e "${CYAN}=========================================${RESET}"
echo -e "${CYAN}  ${BOLD}Setup complete!${RESET}"
echo -e "${CYAN}=========================================${RESET}"
echo ""
echo -e "  ${BOLD}Open this link in your browser:${RESET}"
echo ""
echo -e "     ${GREEN}${BOLD}http://localhost:8080${RESET}"
echo ""
echo -e "  ${DIM}(Create a local account on first visit — it stays on your machine)${RESET}"
echo -e "  ${DIM}You can upload PDFs directly in the chat interface.${RESET}"
echo ""
echo -e "  ${CYAN}To start OllamaBox again later:${RESET}"
echo -e "  ${BOLD}  wsl -d OllamaBox -- bash -c '~/start-ollama.sh'${RESET}"
echo ""
echo -e "  ${CYAN}To remove OllamaBox completely:${RESET}"
echo -e "  ${BOLD}  wsl --unregister OllamaBox${RESET}"
echo ""
echo -e "  ${GREEN}Press Ctrl+C to stop the server.${RESET}"
echo ""

# Launch Open WebUI (blocking — keeps the terminal open)
source "$VENV_DIR/bin/activate"
export DATA_DIR="/opt/ollamabox/data"
export HOME="/root"
cd /opt/ollamabox
open-webui serve --port 8080
