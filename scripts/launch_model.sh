#!/bin/bash
# Attention Warden — Model Launcher
# Launches llama.cpp Docker containers by profile name.
#
# Usage:
#   ./scripts/launch_model.sh reasoning              # Nemotron-Mini-4B
#   ./scripts/launch_model.sh vision                  # Default VLM (Cosmos-Reason2-2B)
#   ./scripts/launch_model.sh vision qwen3_vl_2b      # Specific VLM
#   ./scripts/launch_model.sh embeddings              # BGE embeddings
#   ./scripts/launch_model.sh study_buddy_lite        # Full profile (reasoning + vision)
#   ./scripts/launch_model.sh study_buddy_balanced    # Full profile
#   ./scripts/launch_model.sh study_buddy_full        # Full profile

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

launch_llm() {
    local repo="$1" quant="$2" port="${3:-8080}" ctx="${4:-4096}" np="${5:-1}" name="${6:-assistant-llm}"
    echo "▸ Launching $repo ($quant) on port $port ..."
    PORT="$port" CTX="$ctx" NP="$np" NAME="$name" \
        "$PROJECT_DIR/run_llama_cpp.sh" "${repo}:${quant}"
}

launch_embed() {
    local repo="$1" quant="$2" port="${3:-8081}"
    echo "▸ Launching embeddings $repo ($quant) on port $port ..."
    PORT="$port" "$PROJECT_DIR/run_llama_embedding.sh" "${repo}:${quant}"
}

# ─────────────────────────────────────────────────────────────────
# Model definitions
# ─────────────────────────────────────────────────────────────────

# Reasoning
NEMOTRON_MINI_4B_REPO="bartowski/Nemotron-Mini-4B-Instruct-GGUF"
NEMOTRON_MINI_4B_QUANT="Q4_K_M"

# Vision
COSMOS_REASON2_REPO="Kbenkhaled/Cosmos-Reason2-2B-GGUF"
COSMOS_REASON2_QUANT="Q4_K_M"

NEMOTRON_NANO_VL_REPO="bartowski/Nemotron-Nano-VL-8B-v1-GGUF"
NEMOTRON_NANO_VL_QUANT="Q4_K_M"

GEMMA3_4B_REPO="ggml-org/gemma-3-4b-it-GGUF"
GEMMA3_4B_QUANT="Q4_K_M"

QWEN3_VL_2B_REPO="Qwen/Qwen3-VL-2B-Instruct-GGUF"
QWEN3_VL_2B_QUANT="Q4_K_M"

QWEN3_5_VL_2B_REPO="Qwen/Qwen3.5-VL-2B-Instruct-GGUF"
QWEN3_5_VL_2B_QUANT="Q4_K_M"

# Embeddings
BGE_SMALL_REPO="ggml-org/bge-small-en-v1.5-Q8_0-GGUF"
BGE_SMALL_QUANT="Q8_0"

# ─────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────

case "${1:-help}" in
    reasoning)
        launch_llm "$NEMOTRON_MINI_4B_REPO" "$NEMOTRON_MINI_4B_QUANT" 8080 4096 1 "warden-reasoning"
        ;;

    vision)
        case "${2:-cosmos}" in
            cosmos|cosmos_reason2_2b)
                launch_llm "$COSMOS_REASON2_REPO" "$COSMOS_REASON2_QUANT" 8080 4096 1 "warden-vision"
                ;;
            nemotron|nemotron_nano_2_vl)
                launch_llm "$NEMOTRON_NANO_VL_REPO" "$NEMOTRON_NANO_VL_QUANT" 8080 4096 1 "warden-vision"
                ;;
            gemma|gemma3_4b)
                launch_llm "$GEMMA3_4B_REPO" "$GEMMA3_4B_QUANT" 8080 4096 1 "warden-vision"
                ;;
            qwen3|qwen3_vl_2b)
                launch_llm "$QWEN3_VL_2B_REPO" "$QWEN3_VL_2B_QUANT" 8080 4096 1 "warden-vision"
                ;;
            qwen3.5|qwen3_5_vl_2b)
                launch_llm "$QWEN3_5_VL_2B_REPO" "$QWEN3_5_VL_2B_QUANT" 8080 4096 1 "warden-vision"
                ;;
            *)
                echo "Unknown vision model: $2"
                echo "Available: cosmos, nemotron, gemma, qwen3, qwen3.5"
                exit 1
                ;;
        esac
        ;;

    embeddings)
        launch_embed "$BGE_SMALL_REPO" "$BGE_SMALL_QUANT" 8081
        ;;

    # ── Full profiles ──────────────────────────────────────────

    study_buddy_lite)
        launch_llm "$COSMOS_REASON2_REPO" "$COSMOS_REASON2_QUANT" 8080 4096 1 "warden-vlm"
        echo ""
        launch_embed "$BGE_SMALL_REPO" "$BGE_SMALL_QUANT" 8081
        echo ""
        echo "✓ study_buddy_lite profile active"
        echo "  VLM (reasoning+vision): Cosmos-Reason2-2B on :8080"
        echo "  Embeddings: BGE-Small on :8081"
        echo "  STT: Faster Whisper base.en (loads in Python)"
        echo "  TTS: Piper (loads in Python)"
        ;;

    study_buddy_balanced)
        launch_llm "$QWEN3_5_VL_2B_REPO" "$QWEN3_5_VL_2B_QUANT" 8080 4096 1 "warden-vlm"
        echo ""
        launch_embed "$BGE_SMALL_REPO" "$BGE_SMALL_QUANT" 8081
        echo ""
        echo "✓ study_buddy_balanced profile active"
        echo "  VLM (reasoning+vision): Qwen3.5-VL-2B on :8080"
        echo "  Embeddings: BGE-Small on :8081"
        echo "  STT: Faster Whisper small.en (loads in Python)"
        echo "  TTS: Kokoro (loads in Python)"
        ;;

    study_buddy_full)
        launch_llm "$NEMOTRON_NANO_VL_REPO" "$NEMOTRON_NANO_VL_QUANT" 8080 4096 1 "warden-vlm"
        echo ""
        launch_embed "$BGE_SMALL_REPO" "$BGE_SMALL_QUANT" 8081
        echo ""
        echo "✓ study_buddy_full profile active"
        echo "  VLM (reasoning+vision): Nemotron-Nano-VL on :8080"
        echo "  Embeddings: BGE-Small on :8081"
        echo "  STT: Faster Whisper small.en (loads in Python)"
        echo "  TTS: Kokoro (loads in Python)"
        ;;

    stop)
        echo "Stopping all Warden containers..."
        docker stop warden-reasoning warden-vision warden-vlm warden-embed assistant-llm assistant-embed 2>/dev/null || true
        docker rm warden-reasoning warden-vision warden-vlm warden-embed assistant-llm assistant-embed 2>/dev/null || true
        echo "✓ All stopped"
        ;;

    help|*)
        echo "Attention Warden — Model Launcher"
        echo ""
        echo "Usage: $0 <command> [model]"
        echo ""
        echo "Commands:"
        echo "  reasoning                    Launch Nemotron-Mini-4B (text reasoning)"
        echo "  vision [model]               Launch a VLM (default: cosmos)"
        echo "    cosmos                       Cosmos-Reason2-2B"
        echo "    nemotron                     Nemotron-Nano-VL-8B"
        echo "    gemma                        Gemma-3-4B-IT"
        echo "    qwen3                        Qwen3-VL-2B-Instruct"
        echo "    qwen3.5                      Qwen3.5-VL-2B"
        echo "  embeddings                   Launch BGE-Small embedding server"
        echo ""
        echo "Profiles (launches full stack):"
        echo "  study_buddy_lite             Cosmos-2B + Whisper base + Piper"
        echo "  study_buddy_balanced         Qwen3.5-VL + Whisper small + Kokoro"
        echo "  study_buddy_full             Nemotron-Nano-VL + Whisper small + Kokoro"
        echo ""
        echo "  stop                         Stop all Warden containers"
        ;;
esac
