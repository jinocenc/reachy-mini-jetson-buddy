# Reachy Study Buddy — Setup Guide

Complete installation instructions for flashing and running the Reachy Study Buddy study buddy on a Reachy Mini robot tethered to an NVIDIA Jetson Orin Nano.

---

## Prerequisites

### Hardware

| Component | Details |
|---|---|
| **NVIDIA Jetson Orin Nano** (8GB) | Primary compute unit. Other Jetson modules may work but are untested. |
| **Reachy Mini Lite** | Developer version — provides camera, omni-directional microphone, speaker, and 9-DOF motor control over a single USB connection. [Getting started guide](https://huggingface.co/docs/reachy_mini/platforms/reachy_mini_lite/get_started). [Buy Reachy Mini](https://www.hf.co/reachy-mini/). |
| **NVMe SSD** | Required for swap space and model storage. Running the full stack (STT + VLM + TTS + CV) exceeds 8GB RAM without swap. |
| **USB-C power supply** | Jetson Orin Nano requires a stable 5V/3A supply. |

If you're new to Reachy Mini, start with the [official docs](https://huggingface.co/docs/reachy_mini/index) and the [Python SDK reference](https://huggingface.co/docs/reachy_mini/SDK/readme) covering movement, camera, audio, and AI integrations.

### Software

| Requirement | Version |
|---|---|
| **JetPack** | 6.x (L4T r36.x, Ubuntu 22.04, CUDA 12.6) |
| **Python** | 3.10 (ships with JetPack 6) |
| **Docker** | With NVIDIA runtime (`nvidia-container-toolkit`) |
| **PulseAudio** | For mic/speaker multiplexing |

> **Important:** This project requires **Python 3.10** specifically. The Jetson ONNX Runtime GPU wheels, CTranslate2 builds, and Reachy Mini SDK are all compiled against Python 3.10 on JetPack 6. Using a different Python version will cause binary incompatibilities.

---

## Quick Start (Automated)

The fastest path from a fresh JetPack flash to a running Reachy:

```bash
git clone https://github.com/jinocenc/reachy-mini-jetson-buddy.git
cd reachy-mini-jetson-buddy
chmod +x scripts/setup_jetson.sh
./scripts/setup_jetson.sh
```

This automates everything below — system deps, udev rules, swap, Python venv, CTranslate2 CUDA build, Docker image pull, model downloads, and verification. Takes 30-60 minutes depending on network speed and CTranslate2 compilation.

For partial runs:
```bash
./scripts/setup_jetson.sh --deps-only    # System deps + Python env only
./scripts/setup_jetson.sh --ctranslate2  # Build CTranslate2 only
./scripts/setup_jetson.sh --models       # Download models only
./scripts/setup_jetson.sh --docker       # Pull Docker image only
./scripts/setup_jetson.sh --verify       # Verify installation
```

If you prefer to do it step-by-step, follow the manual instructions below.

---

## Manual Installation

### Step 1: System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
  python3.10-venv \
  portaudio19-dev \
  libasound2-dev \
  pulseaudio-utils \
  libcudnn9-dev-cuda-12 \
  wget curl git
```

### Step 2: Reachy Mini USB Setup

Connect Reachy Mini Lite to the Jetson via USB, then add udev rules so the SDK can access the serial ports without root:

```bash
echo 'SUBSYSTEM=="tty", ATTRS{idVendor}=="2e8a", ATTRS{idProduct}=="000a", MODE="0666", SYMLINK+="reachy_mini"' \
  | sudo tee /etc/udev/rules.d/99-reachy-mini.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
```

Add your user to the `dialout` group:

```bash
sudo usermod -aG dialout $USER
sudo reboot
```

Verify after reboot:
```bash
ls -la /dev/ttyACM*
# Should show /dev/ttyACM0, /dev/ttyACM1, etc.
```

### Step 3: NVMe Swap (Required for 8GB Jetson)

Running the full pipeline (STT + VLM + TTS + camera + emotion) peaks at ~7.5 GB RAM. Swap prevents OOM kills:

```bash
sudo fallocate -l 8G /mnt/nvme/swapfile   # adjust path to your NVMe mount
sudo chmod 600 /mnt/nvme/swapfile
sudo mkswap /mnt/nvme/swapfile
sudo swapon /mnt/nvme/swapfile

# Persist across reboots:
echo '/mnt/nvme/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Step 4: Clone and Create Virtual Environment

```bash
git clone https://github.com/jinocenc/reachy-mini-jetson-buddy.git
cd reachy-mini-jetson-buddy
python3.10 -m venv venv
source venv/bin/activate
```

### Step 5: Install Python Packages

```bash
pip install --upgrade pip wheel
pip install -r requirements.txt
```

### Step 6: Install ONNX Runtime GPU (Jetson-Specific)

The default `onnxruntime` from pip is CPU-only. For GPU inference (Kokoro TTS, Silero VAD) on Jetson:

```bash
pip install onnxruntime-gpu --extra-index-url https://pypi.jetson-ai-lab.io/jp6/cu126
```

> If `CUDAExecutionProvider` isn't listed after install, uninstall the CPU version first:
> `pip uninstall onnxruntime && pip install onnxruntime-gpu --extra-index-url https://pypi.jetson-ai-lab.io/jp6/cu126`

### Step 7: Install Reachy Mini SDK

```bash
pip install reachy-mini
```

### Step 8: Pin NumPy (Compatibility Fix)

The Jetson `onnxruntime-gpu` wheel requires NumPy 1.x:

```bash
pip install "numpy==1.26.4"
```

### Step 9: Build CTranslate2 with CUDA (GPU-Accelerated STT)

The pip `ctranslate2` package is CPU-only. For GPU-accelerated Faster Whisper on Jetson, build from source. This step takes 10-20 minutes:

```bash
pip install pybind11

cd ~
git clone --depth 1 https://github.com/OpenNMT/CTranslate2.git
cd CTranslate2
git submodule update --init --recursive

mkdir build && cd build
export PATH=/usr/local/cuda/bin:$PATH
export CUDA_HOME=/usr/local/cuda
cmake .. -DWITH_CUDA=ON -DWITH_CUDNN=ON -DCMAKE_BUILD_TYPE=Release \
         -DCUDA_ARCH_LIST="8.7" -DOPENMP_RUNTIME=NONE -DWITH_MKL=OFF

make -j$(nproc)
cmake --install . --prefix ~/.local

export LD_LIBRARY_PATH=~/.local/lib:$LD_LIBRARY_PATH
cd ../python
pip install .
```

Persist the library path in your venv activation script:

```bash
echo 'export LD_LIBRARY_PATH=$HOME/.local/lib:$LD_LIBRARY_PATH' >> ~/reachy-mini-jetson-buddy/venv/bin/activate
```

### Step 10: Pull the llama.cpp Docker Image

```bash
docker pull ghcr.io/nvidia-ai-iot/llama_cpp:b8095-r36.4-tegra-aarch64-cu126-22.04
```

### Verify Installation

```bash
source venv/bin/activate
python3 -c "
import ctranslate2; print('CTranslate2 CUDA devices:', ctranslate2.get_cuda_device_count())
import onnxruntime; print('ONNX providers:', onnxruntime.get_available_providers())
from reachy_mini import ReachyMini; print('Reachy Mini SDK: OK')
import faster_whisper; print('faster-whisper: OK')
import kokoro_onnx; print('kokoro-onnx: OK')
from piper import PiperVoice; print('piper-tts: OK')
"
```

Expected output:
```
CTranslate2 CUDA devices: 1
ONNX providers: ['CUDAExecutionProvider', 'CPUExecutionProvider']
Reachy Mini SDK: OK
faster-whisper: OK
kokoro-onnx: OK
piper-tts: OK
```

---

## Models

### Inference Engine

All LLM/VLM models run via **llama.cpp** in a Docker container with full GPU offload. Models are served as an OpenAI-compatible API on `localhost:8080`. This was chosen over Ollama (unnecessary HTTP daemon overhead) and TensorRT-LLM (limited Maxwell/Orin support) for minimum memory footprint and maximum HuggingFace GGUF compatibility.

### Model Registry

The full model inventory is defined in `config/models.yaml`. All models use Q4_K_M quantization to fit within the Jetson Orin Nano's 8GB RAM alongside the CV and audio pipelines.

#### Reasoning LLMs

| Model | HuggingFace Repo | Role |
|---|---|---|
| NVIDIA Nemotron-Mini-4B-Instruct | `bartowski/Nemotron-Mini-4B-Instruct-GGUF` | Primary reasoning — distraction analysis, session management, conversation |

#### Vision-Language Models (VLMs)

| Model | HuggingFace Repo | Role |
|---|---|---|
| NVIDIA Nemotron Nano 2 VL | `bartowski/Nemotron-Nano-VL-8B-v1-GGUF` | Gaze tracking, activity classification, distraction detection |
| Cosmos Reason 2 2B | `Kbenkhaled/Cosmos-Reason2-2B-GGUF` | Spatial reasoning, scene understanding |
| Gemma 3 4B IT | `ggml-org/gemma-3-4b-it-GGUF` | General vision-language tasks |
| Qwen3-VL-2B-Instruct | `Qwen/Qwen3-VL-2B-Instruct-GGUF` | Multilingual vision understanding |
| Qwen3.5-VL-2B | `Qwen/Qwen3.5-VL-2B-Instruct-GGUF` | Latest Qwen VL — improved visual grounding |

#### Speech-to-Text (ASR)

| Model | Engine | Notes |
|---|---|---|
| Whisper small.en | Faster Whisper (CTranslate2 CUDA) | Default — best accuracy/speed tradeoff |
| Whisper base.en | Faster Whisper | Lighter, faster |
| Whisper tiny.en | Faster Whisper | Minimum footprint |

#### Text-to-Speech (TTS)

| Model | Engine | Notes |
|---|---|---|
| Kokoro TTS | kokoro-onnx (ONNX Runtime GPU) | High-quality neural TTS, natural prosody. Default for conversational responses. Subprocess-isolated for GPL compliance. |
| Piper TTS | piper-tts (ONNX) | Fast, lightweight, MIT-licensed. Ideal for rapid distraction alerts where latency matters more than prosody. |

#### Embeddings & Support Models

| Model | Role |
|---|---|
| BGE-Small-EN-v1.5 (Q8) | RAG embeddings for knowledge retrieval |
| DistilBERT SST-2 (ONNX) | Emotion/sentiment classification for robot reactions |

### Downloading Models

Pre-download everything for offline operation:

```bash
./scripts/download_models.sh                # All models
./scripts/download_models.sh --reasoning    # Reasoning LLMs only
./scripts/download_models.sh --vision       # Vision VLMs only
./scripts/download_models.sh --speech       # STT + TTS only
./scripts/download_models.sh --tts          # TTS voices only
```

Models are cached in `~/.cache/huggingface` (GGUF models) and `voices/` (TTS assets).

### Launching Models

Use the profile launcher for one-command startup:

```bash
./scripts/launch_model.sh study_buddy_lite       # Cosmos-2B + Whisper base + Piper
./scripts/launch_model.sh study_buddy_balanced    # Qwen3.5-VL + Whisper small + Kokoro
./scripts/launch_model.sh study_buddy_full        # Nemotron-Nano-VL + Whisper small + Kokoro
```

Or launch individual models:

```bash
./scripts/launch_model.sh reasoning               # Nemotron-Mini-4B on :8080
./scripts/launch_model.sh vision cosmos            # Cosmos-Reason2-2B on :8080
./scripts/launch_model.sh vision qwen3.5           # Qwen3.5-VL-2B on :8080
./scripts/launch_model.sh vision nemotron          # Nemotron-Nano-VL on :8080
./scripts/launch_model.sh embeddings               # BGE-Small on :8081
```

Or use the raw Docker launcher directly:

```bash
NP=1 ./run_llama_cpp.sh Kbenkhaled/Cosmos-Reason2-2B-GGUF:Q4_K_M
./run_llama_cpp.sh bartowski/Nemotron-Mini-4B-Instruct-GGUF:Q4_K_M
./run_llama_embedding.sh ggml-org/bge-small-en-v1.5-Q8_0-GGUF:Q8_0
```

### TTS Configuration

Switch between TTS engines in `config/settings.yaml`:

```yaml
tts:
  engine: "kokoro"          # High quality, natural prosody
  voice: "af_sarah"         # kokoro voices: af_sarah, af_bella, am_adam, bf_emma, bm_george

tts:
  engine: "piper"           # Fast, lightweight
  voice: "en_US-amy-medium" # piper voices: en_US-amy-medium, en_US-lessac-medium
```

Kokoro TTS voices (~340 MB) and Piper voices (~60-80 MB each) download automatically on first use.

To pre-download for offline:
```bash
# Kokoro
wget -P voices/ https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
wget -P voices/ https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin

# Piper (handled by download_models.sh --tts)
./scripts/download_models.sh --tts
```

---

## Running the Reachy Study Buddy

### Full Vision + Web UI (Recommended)

```bash
source venv/bin/activate

# 1. Launch model stack
./scripts/launch_model.sh study_buddy_balanced

# 2. Start Reachy
python3 run_web_vision_chat.py

# 3. Open the web UI
# http://<jetson-ip>:8090
```

### Terminal-Only Vision Chat

```bash
python3 run_vision_chat.py
```

### Voice-Only Chat (No Camera)

```bash
python3 run_voice_chat.py          # With RAG
python3 run_voice_chat.py --no-rag # Without RAG
```

### CLI Text Chat

```bash
python3 main.py chat -t
python3 main.py ask "How does the Pomodoro technique work?"
python3 main.py info
```

---

## Troubleshooting

**`CUDAExecutionProvider` not available:**
```bash
pip uninstall onnxruntime
pip install onnxruntime-gpu --extra-index-url https://pypi.jetson-ai-lab.io/jp6/cu126
```

**CTranslate2 not finding CUDA:**
```bash
export LD_LIBRARY_PATH=$HOME/.local/lib:$LD_LIBRARY_PATH
```

**VLM server not responding:**
```bash
docker ps                    # Check container is running
docker logs reachy-vlm       # View logs (or assistant-llm for raw launches)
```

**OOM kills / system freezing:**
- Verify swap is active: `free -h` should show 8GB+ swap
- Use the `study_buddy_lite` profile instead of `full`
- Switch STT to `tiny.en` in `config/settings.yaml`
- Switch TTS to `piper` (smaller footprint than Kokoro)

**Process won't exit / robot stays awake after Ctrl+C:**
```bash
pkill -9 -f run_web_vision_chat
pkill -f reachy-mini-daemon
```

**Port 8090 already in use:**
```bash
lsof -ti :8090 | xargs kill -9
```

**Camera not found:**
```bash
ls /dev/video*                # Check device exists
fuser -k /dev/video0          # Kill process holding it
```

**Docker model containers won't start:**
```bash
./scripts/launch_model.sh stop   # Clean up all Reachy containers
./scripts/launch_model.sh study_buddy_balanced   # Relaunch
```
