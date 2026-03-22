#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# Attention Warden — Jetson Orin Nano Setup
# Automates the full SETUP.md installation sequence.
#
# Prerequisites:
#   - NVIDIA Jetson Orin Nano (8GB) with JetPack 6.x flashed
#   - NVMe SSD mounted (recommended)
#   - Internet connection
#   - Reachy Mini Lite connected via USB
#
# Usage:
#   chmod +x scripts/setup_jetson.sh
#   ./scripts/setup_jetson.sh              # Full setup
#   ./scripts/setup_jetson.sh --deps-only  # System deps + Python env only
#   ./scripts/setup_jetson.sh --models     # Download models only
#   ./scripts/setup_jetson.sh --verify     # Verify installation
# ══════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}▸${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}⚠${NC} $*"; }
fail()  { echo -e "${RED}✗${NC} $*" >&2; }

banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Attention Warden — Jetson Setup                ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 0: Preflight checks
# ─────────────────────────────────────────────────────────────────

preflight() {
    echo "═══ PREFLIGHT CHECKS ═══"

    # Check we're on a Jetson
    if [ -f /proc/device-tree/model ]; then
        MODEL=$(tr -d '\0' < /proc/device-tree/model)
        ok "Platform: $MODEL"
    else
        warn "Not running on Jetson — setup may not work correctly"
    fi

    # Check JetPack / L4T version
    if [ -f /etc/nv_tegra_release ]; then
        L4T=$(head -1 /etc/nv_tegra_release)
        ok "L4T: $L4T"
    fi

    # Check Python version
    PY_VER=$(python3 --version 2>/dev/null || echo "not found")
    if echo "$PY_VER" | grep -q "3.10"; then
        ok "Python: $PY_VER"
    else
        warn "Python: $PY_VER (expected 3.10 — see SETUP.md)"
    fi

    # Check CUDA
    if command -v nvcc &>/dev/null; then
        CUDA_VER=$(nvcc --version | grep release | awk '{print $5}' | tr -d ',')
        ok "CUDA: $CUDA_VER"
    else
        warn "CUDA not found in PATH"
    fi

    # Check Docker
    if command -v docker &>/dev/null; then
        ok "Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
        if docker info 2>/dev/null | grep -q "nvidia"; then
            ok "NVIDIA Container Runtime: available"
        else
            warn "NVIDIA Container Runtime not detected — install nvidia-container-toolkit"
        fi
    else
        fail "Docker not installed — required for llama.cpp server"
    fi

    # Check Reachy Mini
    if ls /dev/ttyACM* &>/dev/null; then
        ok "Reachy Mini: $(ls /dev/ttyACM* | head -1) detected"
    else
        warn "Reachy Mini not detected on /dev/ttyACM* — connect via USB"
    fi

    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 1: System dependencies
# ─────────────────────────────────────────────────────────────────

install_system_deps() {
    echo "═══ SYSTEM DEPENDENCIES ═══"
    info "Installing system packages..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq \
        python3.10-venv \
        portaudio19-dev \
        libasound2-dev \
        pulseaudio-utils \
        libcudnn9-dev-cuda-12 \
        wget \
        curl \
        git
    ok "System packages installed"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 2: Reachy Mini udev rules
# ─────────────────────────────────────────────────────────────────

setup_reachy_udev() {
    echo "═══ REACHY MINI USB RULES ═══"
    if [ -f /etc/udev/rules.d/99-reachy-mini.rules ]; then
        ok "udev rules already configured"
    else
        info "Adding Reachy Mini udev rules..."
        echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000a", MODE="0666", SYMLINK+="reachy_mini"' \
            | sudo tee /etc/udev/rules.d/99-reachy-mini.rules > /dev/null
        sudo udevadm control --reload-rules && sudo udevadm trigger
        ok "udev rules installed"

        if ! groups "$USER" | grep -q dialout; then
            info "Adding $USER to dialout group..."
            sudo usermod -aG dialout "$USER"
            warn "You'll need to reboot for group changes to take effect"
        fi
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 3: NVMe swap
# ─────────────────────────────────────────────────────────────────

setup_swap() {
    echo "═══ SWAP SPACE ═══"
    SWAP_SIZE="8G"

    # Check if swap already active
    CURRENT_SWAP=$(free -g | awk '/Swap/ {print $2}')
    if [ "$CURRENT_SWAP" -ge 4 ]; then
        ok "Swap already configured: ${CURRENT_SWAP}GB"
        echo ""
        return
    fi

    # Look for NVMe mount
    NVME_MOUNT=""
    if mount | grep -q "/mnt/nvme"; then
        NVME_MOUNT="/mnt/nvme"
    elif mount | grep -q "/media"; then
        NVME_MOUNT=$(mount | grep "/media" | head -1 | awk '{print $3}')
    fi

    if [ -n "$NVME_MOUNT" ]; then
        SWAP_FILE="$NVME_MOUNT/swapfile"
        info "Setting up ${SWAP_SIZE} swap on NVMe ($SWAP_FILE)..."
    else
        SWAP_FILE="/swapfile"
        warn "No NVMe mount detected — creating swap on root filesystem"
        info "Setting up ${SWAP_SIZE} swap at $SWAP_FILE..."
    fi

    if [ -f "$SWAP_FILE" ]; then
        ok "Swap file already exists at $SWAP_FILE"
    else
        sudo fallocate -l "$SWAP_SIZE" "$SWAP_FILE"
        sudo chmod 600 "$SWAP_FILE"
        sudo mkswap "$SWAP_FILE"
        sudo swapon "$SWAP_FILE"

        # Persist across reboots
        if ! grep -q "$SWAP_FILE" /etc/fstab; then
            echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null
        fi
        ok "Swap configured: $SWAP_SIZE at $SWAP_FILE"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 4: Python virtual environment
# ─────────────────────────────────────────────────────────────────

setup_python_env() {
    echo "═══ PYTHON ENVIRONMENT ═══"
    cd "$PROJECT_DIR"

    if [ ! -d "venv" ]; then
        info "Creating virtual environment..."
        python3.10 -m venv venv
        ok "venv created"
    else
        ok "venv already exists"
    fi

    source venv/bin/activate
    info "Upgrading pip..."
    pip install --upgrade pip wheel -q

    info "Installing Python packages..."
    pip install -r requirements.txt -q
    ok "Python packages installed"

    # ONNX Runtime GPU (Jetson-specific)
    info "Installing ONNX Runtime GPU (Jetson)..."
    pip install onnxruntime-gpu --extra-index-url https://pypi.jetson-ai-lab.io/jp6/cu126 -q 2>/dev/null \
        && ok "onnxruntime-gpu installed" \
        || warn "onnxruntime-gpu install failed — see SETUP.md"

    # Reachy Mini SDK
    info "Installing Reachy Mini SDK..."
    pip install reachy-mini -q 2>/dev/null \
        && ok "reachy-mini SDK installed" \
        || warn "reachy-mini SDK install failed"

    # Pin NumPy for Jetson ONNX compatibility
    pip install "numpy==1.26.4" -q

    # Piper TTS
    info "Installing Piper TTS..."
    pip install piper-tts -q 2>/dev/null \
        && ok "piper-tts installed" \
        || warn "piper-tts install failed — Kokoro TTS will still work"

    # Persist LD_LIBRARY_PATH for CTranslate2
    if ! grep -q "LD_LIBRARY_PATH" venv/bin/activate 2>/dev/null; then
        echo 'export LD_LIBRARY_PATH=$HOME/.local/lib:$LD_LIBRARY_PATH' >> venv/bin/activate
    fi

    ok "Python environment ready"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 5: Build CTranslate2 with CUDA
# ─────────────────────────────────────────────────────────────────

build_ctranslate2() {
    echo "═══ CTRANSLATE2 (GPU-ACCELERATED STT) ═══"

    # Check if already built
    if python3 -c "import ctranslate2; print(ctranslate2.get_cuda_device_count())" 2>/dev/null | grep -q "1"; then
        ok "CTranslate2 with CUDA already installed"
        echo ""
        return
    fi

    info "Building CTranslate2 from source with CUDA support..."
    info "This takes 10-20 minutes on Jetson Orin Nano."

    pip install pybind11 -q

    cd "$HOME"
    if [ ! -d "CTranslate2" ]; then
        git clone --depth 1 https://github.com/OpenNMT/CTranslate2.git
    fi
    cd CTranslate2
    git submodule update --init --recursive

    mkdir -p build && cd build
    export PATH=/usr/local/cuda/bin:$PATH
    export CUDA_HOME=/usr/local/cuda

    cmake .. -DWITH_CUDA=ON -DWITH_CUDNN=ON -DCMAKE_BUILD_TYPE=Release \
             -DCUDA_ARCH_LIST="8.7" -DOPENMP_RUNTIME=NONE -DWITH_MKL=OFF

    make -j$(nproc)
    cmake --install . --prefix ~/.local

    export LD_LIBRARY_PATH=~/.local/lib:$LD_LIBRARY_PATH
    cd ../python
    pip install .

    ok "CTranslate2 built and installed"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 6: Pull Docker image
# ─────────────────────────────────────────────────────────────────

pull_docker_image() {
    echo "═══ DOCKER IMAGE ═══"
    IMAGE="ghcr.io/nvidia-ai-iot/llama_cpp:b8095-r36.4-tegra-aarch64-cu126-22.04"

    if docker image inspect "$IMAGE" &>/dev/null; then
        ok "llama.cpp Docker image already present"
    else
        info "Pulling llama.cpp Docker image (~2-4 GB)..."
        docker pull "$IMAGE"
        ok "Docker image pulled"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 7: Download models
# ─────────────────────────────────────────────────────────────────

download_models() {
    echo "═══ MODELS ═══"
    info "Downloading all models for offline operation..."
    bash "$SCRIPT_DIR/download_models.sh"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Step 8: Make scripts executable
# ─────────────────────────────────────────────────────────────────

set_permissions() {
    echo "═══ PERMISSIONS ═══"
    chmod +x "$PROJECT_DIR/run_llama_cpp.sh"
    chmod +x "$PROJECT_DIR/run_llama_embedding.sh"
    chmod +x "$SCRIPT_DIR/download_models.sh"
    chmod +x "$SCRIPT_DIR/launch_model.sh"
    chmod +x "$SCRIPT_DIR/setup_jetson.sh"
    ok "Scripts marked executable"
    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Verify installation
# ─────────────────────────────────────────────────────────────────

verify() {
    echo "═══ VERIFICATION ═══"
    cd "$PROJECT_DIR"

    if [ -d "venv" ]; then
        source venv/bin/activate
    fi

    python3 -c "
import sys
results = []

def check(name, test):
    try:
        result = test()
        print(f'  ✓ {name}: {result}')
        results.append(True)
    except Exception as e:
        print(f'  ✗ {name}: {e}')
        results.append(False)

check('CTranslate2 CUDA', lambda: f'{__import__(\"ctranslate2\").get_cuda_device_count()} device(s)')
check('ONNX Runtime', lambda: ', '.join(__import__('onnxruntime').get_available_providers()))
check('faster-whisper', lambda: __import__('faster_whisper') and 'OK')
check('kokoro-onnx', lambda: __import__('kokoro_onnx') and 'OK')
check('Reachy Mini SDK', lambda: __import__('reachy_mini') and 'OK')

try:
    from piper import PiperVoice
    print('  ✓ piper-tts: OK')
    results.append(True)
except ImportError:
    print('  ⚠ piper-tts: not installed (optional)')

passed = sum(results)
total = len(results)
print(f'')
print(f'  {passed}/{total} checks passed')
" 2>/dev/null || warn "Verification requires activated venv"

    echo ""
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────

banner

case "${1:-full}" in
    --deps-only)
        preflight
        install_system_deps
        setup_reachy_udev
        setup_swap
        setup_python_env
        set_permissions
        ;;
    --ctranslate2)
        build_ctranslate2
        ;;
    --models)
        download_models
        ;;
    --docker)
        pull_docker_image
        ;;
    --verify)
        verify
        ;;
    full|*)
        preflight
        install_system_deps
        setup_reachy_udev
        setup_swap
        setup_python_env
        build_ctranslate2
        pull_docker_image
        download_models
        set_permissions
        verify
        echo "═══ SETUP COMPLETE ═══"
        echo ""
        echo "Next steps:"
        echo "  1. Reboot if prompted (for dialout group)"
        echo "  2. Activate the environment:  source venv/bin/activate"
        echo "  3. Launch a model profile:    ./scripts/launch_model.sh study_buddy_balanced"
        echo "  4. Start the Warden:          python3 run_web_vision_chat.py"
        echo "  5. Open the web UI:           http://$(hostname -I | awk '{print $1}'):8090"
        echo ""
        ;;
esac
