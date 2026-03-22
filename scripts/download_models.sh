#!/bin/bash
# Reachy Study Buddy — Model Download Script
# Pre-downloads all GGUF models and speech assets for offline operation.
#
# Usage:
#   ./scripts/download_models.sh              # Download all models
#   ./scripts/download_models.sh --reasoning  # Reasoning LLMs only
#   ./scripts/download_models.sh --vision     # Vision VLMs only
#   ./scripts/download_models.sh --speech     # STT + TTS only
#   ./scripts/download_models.sh --tts        # TTS voices only

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
HF_CACHE="$HOME/.cache/huggingface"
VOICES_DIR="$PROJECT_DIR/voices"
PIPER_DIR="$PROJECT_DIR/voices/piper"
MODELS_DIR="$PROJECT_DIR/models"

mkdir -p "$HF_CACHE" "$VOICES_DIR" "$PIPER_DIR" "$MODELS_DIR"

# ─────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────

info()  { echo "▸ $*"; }
ok()    { echo "✓ $*"; }
warn()  { echo "⚠ $*"; }
fail()  { echo "✗ $*" >&2; }

download_hf_gguf() {
    local name="$1" repo="$2" quant="$3"
    info "Downloading $name ($quant) from $repo ..."

    # Use huggingface-cli if available, otherwise Docker pull will handle it
    if command -v huggingface-cli &>/dev/null; then
        huggingface-cli download "$repo" --include "*${quant}*" --cache-dir "$HF_CACHE" \
            && ok "$name cached" \
            || warn "$name: huggingface-cli download failed — will download on first Docker launch"
    else
        # Pre-warm via Docker dry run (pulls model into HF cache)
        local image="ghcr.io/nvidia-ai-iot/llama_cpp:b8095-r36.4-tegra-aarch64-cu126-22.04"
        if docker image inspect "$image" &>/dev/null; then
            docker run --rm \
                -v "$HF_CACHE:/root/.cache/huggingface" \
                "$image" \
                huggingface-cli download "$repo" --include "*${quant}*" \
                && ok "$name cached via Docker" \
                || warn "$name: will download on first launch"
        else
            warn "$name: no huggingface-cli or Docker image — will download on first launch"
            info "  Install: pip install huggingface-hub[cli]"
        fi
    fi
}

# ─────────────────────────────────────────────────────────────────
# Reasoning LLMs
# ─────────────────────────────────────────────────────────────────

download_reasoning() {
    echo ""
    echo "═══ REASONING LLMs ═══"
    download_hf_gguf "Nemotron-Mini-4B-Instruct" \
        "bartowski/Nemotron-Mini-4B-Instruct-GGUF" "Q4_K_M"
}

# ─────────────────────────────────────────────────────────────────
# Vision VLMs
# ─────────────────────────────────────────────────────────────────

download_vision() {
    echo ""
    echo "═══ VISION VLMs ═══"
    download_hf_gguf "Cosmos-Reason2-2B" \
        "Kbenkhaled/Cosmos-Reason2-2B-GGUF" "Q4_K_M"

    download_hf_gguf "Gemma-3-4B-IT" \
        "ggml-org/gemma-3-4b-it-GGUF" "Q4_K_M"

    download_hf_gguf "Qwen3-VL-2B-Instruct" \
        "Qwen/Qwen3-VL-2B-Instruct-GGUF" "Q4_K_M"

    download_hf_gguf "Qwen3.5-VL-2B" \
        "Qwen/Qwen3.5-VL-2B-Instruct-GGUF" "Q4_K_M"

    download_hf_gguf "Nemotron-Nano-VL-8B" \
        "bartowski/Nemotron-Nano-VL-8B-v1-GGUF" "Q4_K_M"
}

# ─────────────────────────────────────────────────────────────────
# Speech — STT (Faster Whisper models auto-download via CTranslate2)
# ─────────────────────────────────────────────────────────────────

download_stt() {
    echo ""
    echo "═══ SPEECH-TO-TEXT (Faster Whisper) ═══"
    info "Faster Whisper models (tiny.en, base.en, small.en) download automatically"
    info "on first use via CTranslate2. No manual download needed."

    # Pre-download if Python env is available
    if python3 -c "import faster_whisper" 2>/dev/null; then
        info "Pre-downloading Whisper models for offline use..."
        python3 -c "
from faster_whisper import WhisperModel
for model in ['tiny.en', 'base.en', 'small.en']:
    print(f'  Downloading {model}...')
    try:
        WhisperModel(model, device='cpu', compute_type='int8')
        print(f'  ✓ {model} cached')
    except Exception as e:
        print(f'  ⚠ {model}: {e}')
" || warn "Could not pre-download Whisper models (faster-whisper not installed)"
    else
        info "Install faster-whisper to pre-download: pip install faster-whisper"
    fi
}

# ─────────────────────────────────────────────────────────────────
# Speech — TTS (Kokoro + Piper)
# ─────────────────────────────────────────────────────────────────

download_tts() {
    echo ""
    echo "═══ TEXT-TO-SPEECH ═══"

    # Kokoro TTS
    echo ""
    info "Kokoro TTS models..."
    if [ ! -f "$VOICES_DIR/kokoro-v1.0.onnx" ]; then
        wget -q --show-progress -O "$VOICES_DIR/kokoro-v1.0.onnx" \
            "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx" \
            && ok "kokoro-v1.0.onnx" \
            || fail "kokoro-v1.0.onnx download failed"
    else
        ok "kokoro-v1.0.onnx (already present)"
    fi

    if [ ! -f "$VOICES_DIR/voices-v1.0.bin" ]; then
        wget -q --show-progress -O "$VOICES_DIR/voices-v1.0.bin" \
            "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin" \
            && ok "voices-v1.0.bin" \
            || fail "voices-v1.0.bin download failed"
    else
        ok "voices-v1.0.bin (already present)"
    fi

    # Piper TTS
    echo ""
    info "Piper TTS voice models..."
    PIPER_VOICES=(
        "en_US-amy-medium"
        "en_US-lessac-medium"
    )
    PIPER_BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US"

    for voice in "${PIPER_VOICES[@]}"; do
        # Parse voice name: en_US-amy-medium → amy/medium
        speaker=$(echo "$voice" | sed 's/en_US-//' | cut -d'-' -f1)
        quality=$(echo "$voice" | sed 's/en_US-//' | cut -d'-' -f2)
        voice_url="${PIPER_BASE_URL}/${speaker}/${quality}/${voice}.onnx"
        json_url="${PIPER_BASE_URL}/${speaker}/${quality}/${voice}.onnx.json"

        if [ ! -f "$PIPER_DIR/${voice}.onnx" ]; then
            info "Downloading Piper voice: $voice"
            wget -q --show-progress -O "$PIPER_DIR/${voice}.onnx" "$voice_url" 2>/dev/null \
                && ok "$voice.onnx" \
                || fail "$voice.onnx download failed"
            wget -q -O "$PIPER_DIR/${voice}.onnx.json" "$json_url" 2>/dev/null \
                && ok "$voice.onnx.json" \
                || fail "$voice.onnx.json download failed"
        else
            ok "$voice (already present)"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────
# Embeddings
# ─────────────────────────────────────────────────────────────────

download_embeddings() {
    echo ""
    echo "═══ EMBEDDINGS ═══"
    download_hf_gguf "BGE-Small-EN-v1.5" \
        "ggml-org/bge-small-en-v1.5-Q8_0-GGUF" "Q8_0"
}

# ─────────────────────────────────────────────────────────────────
# Emotion model
# ─────────────────────────────────────────────────────────────────

download_emotion() {
    echo ""
    echo "═══ EMOTION MODEL ═══"
    local emo_dir="$MODELS_DIR/emotion"
    mkdir -p "$emo_dir"

    if [ ! -f "$emo_dir/model.onnx" ]; then
        info "Downloading DistilBERT emotion classifier..."
        wget -q --show-progress -O "$emo_dir/model.onnx" \
            "https://huggingface.co/distilbert/distilbert-base-uncased-finetuned-sst-2-english/resolve/main/onnx/model.onnx" \
            && ok "emotion/model.onnx"
        wget -q -O "$emo_dir/tokenizer.json" \
            "https://huggingface.co/distilbert/distilbert-base-uncased-finetuned-sst-2-english/resolve/main/onnx/tokenizer.json" \
            && ok "emotion/tokenizer.json"
    else
        ok "Emotion model (already present)"
    fi
}

# ─────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════╗"
echo "║   Reachy Study Buddy — Model Download             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Cache directory: $HF_CACHE"
echo "Voices directory: $VOICES_DIR"

case "${1:-all}" in
    --reasoning) download_reasoning ;;
    --vision)    download_vision ;;
    --speech)    download_stt; download_tts ;;
    --stt)       download_stt ;;
    --tts)       download_tts ;;
    --embeddings) download_embeddings ;;
    --emotion)   download_emotion ;;
    all|*)
        download_reasoning
        download_vision
        download_stt
        download_tts
        download_embeddings
        download_emotion
        ;;
esac

echo ""
echo "═══ DONE ═══"
echo "Models are cached and ready for offline operation."
