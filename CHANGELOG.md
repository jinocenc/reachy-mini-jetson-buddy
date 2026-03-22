# Changelog

## [0.2] — 2026-03-21

### Reachy Gets Friendlier + Vision Analysis Requirements + Demo Mode

**Personality rename:** "Attention Warden" → "Reachy." The surveillance-gargoyle persona is dead. Reachy is now a warm, supportive study buddy — "like a good friend who actually wants to see you succeed." All system prompts, few-shot examples, and PRD language updated to match.

**Demo mode:** New `pomodoro` config section with `mode: "demo"` option. Demo timers: 5 min work / 2 min break / 3 min long break / 2 cycles. Designed for presentations, testing, and first-time setup where nobody wants to wait 25 minutes to see if escalation works.

**Vision frame analysis requirements (FR-12 through FR-31):** The PRD now defines exactly what Reachy should expect to see in each camera frame and how to respond:

- **Person at desk:** Focused (no action), phone distraction (escalate), disengaged/idle (gentle check-in), social distraction (during work only), brief stretching (never a distraction).
- **Empty workspace:** ABSENT classification. During work periods, note it and welcome back. During breaks, expected behavior.
- **Screen content visible:** Classify by application *category* not specific text. Study content (docs, IDEs, lecture slides) = on track. Distraction content (social media, streaming, games) = escalate during work. Ambiguous content (YouTube, Wikipedia, Stack Overflow) = default to no alert. Never read or log specific text — privacy boundary.
- **Obstructed view:** Dark, blurry, covered = notify user once, fall back to audio-only. Never fabricate scene details.

**Files changed:**
- `config/settings.yaml` — All "Attention Warden" references → "Reachy." Prompts rewritten warmer. Vision system prompt now includes structured image classification instructions (PERSON AT DESK, EMPTY WORKSPACE, SCREEN VISIBLE, OBSTRUCTED). Few-shot examples updated ("Hey Reachy" not "Hey Warden"). New `pomodoro` section with `standard` and `demo` timing configs.
- `app/config.py` — Added `PomodoroTimingConfig` and `PomodoroConfig` dataclasses. `PomodoroConfig` has a `.active` property that returns the timing config for the current mode. Config loader updated to handle nested Pomodoro YAML structure.
- `PRD.md` — Version 0.2. Renamed throughout. Added FR-12 through FR-31 (vision frame analysis). Added FR-07 (demo mode). Updated escalation language to be warm not punitive. Added demo mode to Pomodoro section (6.2). Added vision classification accuracy to success metrics. Added open question about ambiguous screen content and demo mode escalation timer compression.

---

## [0.1] — 2026-03-21

### The Study Buddy Fork

Forked from [NVIDIA's Reachy Mini Jetson Assistant](https://github.com/NVIDIA-AI-IOT/reachy-mini-jetson-assistant) and retooled as an embodied AI study buddy — a stationary robot with emotive capabilities and tactile feedback that observes the user during study sessions, manages Pomodoro timers, detects distractions via camera and microphone, and uses an escalating alert system to bring focus back without being obnoxious about it.

All inference runs locally on the Jetson Orin Nano via llama.cpp (Docker) and native Python packages. No cloud. No data leaves the device.

---

### What Changed and Why

#### Identity — Reachy Mini Assistant becomes the Attention Warden

The original repo was a general-purpose conversational robot assistant. Every system prompt, few-shot example, and persona reference has been rewritten around the study buddy use case.

**Files changed:**
- `config/settings.yaml` — System prompts for both the text LLM (`llm.system_prompt`, `llm.system_prompt_no_rag`) and the vision model (`vision.system_prompt`) now identify as the Attention Warden and instruct the model to manage Pomodoro sessions, detect distractions, and respond with encouragement. Few-shot examples replaced with study session interactions ("Hey Warden, let's study" / "Let's do it. Starting a twenty-five minute Pomodoro.").
- `config/settings.yaml` — `llm.max_tokens` increased from 128 to 256 to allow slightly longer distraction analysis responses.

#### Model Registry — From 3 Models to a Full Arsenal

The original repo shipped with three models: Cosmos-Reason2-2B (VLM), Gemma 3 1B (text), and BGE-Small (embeddings). The Attention Warden needs more options — different VLMs for different accuracy/speed tradeoffs, and a dedicated reasoning model for session management logic.

**New file:** `config/models.yaml`

Six GGUF model profiles added:

| Model | Role | Why |
|---|---|---|
| NVIDIA Nemotron-Mini-4B-Instruct | Reasoning | Primary text LLM for distraction analysis, Pomodoro session management, and natural conversation. NVIDIA-optimized for Jetson. |
| NVIDIA Nemotron Nano 2 VL | Vision | NVIDIA's edge VLM for gaze tracking and activity classification. Highest accuracy option for distraction detection. |
| Cosmos Reason 2 2B | Vision | Already in the original repo. Spatial reasoning for scene understanding. Kept as the lightweight VLM default. |
| Gemma 3 4B IT | Vision | Upgraded from 1B to 4B. Google's compact VLM for general vision-language tasks. |
| Qwen3-VL-2B-Instruct | Vision | Strong multilingual vision understanding from Alibaba. |
| Qwen3.5-VL-2B | Vision | Latest Qwen VL with improved visual grounding and reasoning. |

Three deployment profiles defined:
- **study_buddy_lite** — Cosmos-2B + Whisper base + Piper TTS. Prioritizes responsiveness.
- **study_buddy_balanced** — Qwen3.5-VL + Whisper small + Kokoro TTS. Best default.
- **study_buddy_full** — Nemotron-Nano-VL + Whisper small + Kokoro TTS. Maximum accuracy.

#### Piper TTS — A Second Voice

Kokoro TTS produces beautiful, natural speech but it's not the fastest on Jetson. For rapid-fire distraction alerts ("Hey, you've been on your phone for thirty seconds"), latency matters more than prosody richness.

**New files:**
- `app/tts_piper.py` — Full Piper TTS backend. MIT-licensed (no subprocess isolation needed unlike Kokoro's GPL chain). Auto-downloads voice models from HuggingFace on first use. Supports `en_US-amy-medium` and `en_US-lessac-medium` voices out of the box.

**Modified files:**
- `app/tts.py` — `create_tts()` factory function updated to accept `engine="piper"` parameter. Routes to `PiperTTS` class instead of `KokoroTTS` when selected.
- `app/config.py` — `TTSConfig` dataclass gained an `engine` field (default: `"kokoro"`). Accepts `"kokoro"` or `"piper"`.
- `config/settings.yaml` — New `tts.engine` field documented with both engine options.
- `requirements.txt` — Added `piper-tts>=1.2.0` dependency.

#### Automation Scripts — One Command to Rule Them All

The original SETUP.md was a 240-line manual with 7 copy-paste steps. Good documentation, but nobody wants to type all that on a fresh Jetson.

**New files:**

- `scripts/setup_jetson.sh` — Automates the entire setup sequence: preflight checks (Jetson model, JetPack version, CUDA, Docker, Reachy Mini detection), system dependency installation, udev rules, NVMe swap configuration, Python virtual environment creation, pip package installation (including ONNX Runtime GPU from Jetson-specific index, Reachy Mini SDK, Piper TTS, NumPy pinning), CTranslate2 CUDA source build, Docker image pull, model download, permission setting, and installation verification. Supports partial runs via flags (`--deps-only`, `--ctranslate2`, `--models`, `--docker`, `--verify`).

- `scripts/download_models.sh` — Pre-downloads all models for fully offline operation. Handles GGUF models via `huggingface-cli` (with Docker fallback), Faster Whisper CTranslate2 models, Kokoro TTS assets (311 MB model + 30 MB voices), Piper TTS voice ONNX files from HuggingFace rhasspy/piper-voices, and the DistilBERT emotion classifier. Supports selective download via flags (`--reasoning`, `--vision`, `--speech`, `--tts`, `--embeddings`, `--emotion`).

- `scripts/launch_model.sh` — One-command model launcher wrapping `run_llama_cpp.sh`. Launch by role (`reasoning`, `vision`, `embeddings`), by specific model name (`vision qwen3.5`), or by full profile (`study_buddy_lite`, `study_buddy_balanced`, `study_buddy_full`). Includes `stop` command to clean up all Warden Docker containers.

#### Knowledge Base — Pomodoro Context for RAG

**New file:** `knowledge_base/pomodoro_technique.md`

RAG context document covering the Pomodoro Technique: standard configuration (25/5/15 timing), the six rules, common modifications (shorter/longer sprints, extended breaks), and guidance on when to suggest modifications to the user. Automatically loaded into the ChromaDB vector store by the existing `KnowledgeBase.sync_directory()` mechanism so the Warden can reference it during sessions.

#### SETUP.md — Rewritten for the Attention Warden

The original SETUP.md referenced the upstream NVIDIA repo URL, only documented three models, and had no awareness of the new scripts or TTS options.

**Replaced with:**
- Quick Start section pointing to `setup_jetson.sh` for automated setup
- Full manual installation steps (preserved from original, updated with Piper TTS and correct clone URL)
- Complete model registry table with all six VLMs, three Whisper tiers, both TTS engines, and embeddings
- Model download and launch instructions using the new scripts
- TTS configuration examples for both Kokoro and Piper
- Three run modes documented (web vision, terminal vision, voice-only, CLI)
- Expanded troubleshooting covering OOM, Docker container management, and the `launch_model.sh stop` command

---

### Files Summary

```
NEW     app/tts_piper.py                    Piper TTS backend (fast, lightweight, MIT)
NEW     config/models.yaml                  Model registry (6 VLMs, 3 STT, 2 TTS, profiles)
NEW     knowledge_base/pomodoro_technique.md  RAG context for Pomodoro method
NEW     scripts/download_models.sh          Pre-download all models for offline use
NEW     scripts/launch_model.sh             One-command model/profile launcher
NEW     scripts/setup_jetson.sh             Automated Jetson setup (deps → verify)
MODIFIED app/config.py                      Added engine field to TTSConfig
MODIFIED app/tts.py                         create_tts() factory supports engine="piper"
MODIFIED config/settings.yaml               Attention Warden identity, prompts, tts.engine
MODIFIED requirements.txt                   Added piper-tts>=1.2.0
REWRITTEN SETUP.md                          Full rewrite for Attention Warden stack
NEW     CHANGELOG.md                        This file
```

### What Was NOT Changed

The following were intentionally left untouched — they work as-is and the study buddy features (Pomodoro state machine, distraction detection pipeline, escalation tiers) will be built on top of them in subsequent work:

- `app/llm.py` — LLM/VLM client (OpenAI-compatible API, streaming)
- `app/stt.py` — Faster Whisper speech-to-text
- `app/tts_worker.py` — Kokoro TTS subprocess worker
- `app/camera.py` — Ring buffer camera with background capture
- `app/pipeline.py` — Audio I/O, VAD, mic recording, TTS streaming
- `app/reachy.py` — Reachy Mini SDK connection and daemon management
- `app/movements.py` — Emotion-driven robot behaviors
- `app/emotion.py` — Sentiment classification (DistilBERT ONNX)
- `app/audio.py` — PulseAudio/ALSA device discovery
- `app/rag.py` — ChromaDB vector store + embeddings
- `app/monitor.py` — System stats (CPU/GPU/RAM)
- `app/web.py` — FastAPI + WebSocket server
- `app/cli.py` — Typer CLI
- `run_vision_chat.py` — Terminal vision chat entry point
- `run_web_vision_chat.py` — Web + terminal vision chat
- `run_voice_chat.py` — Text LLM with optional RAG
- `run_llama_cpp.sh` — Docker LLM/VLM server launcher
- `run_llama_embedding.sh` — Docker embedding server launcher
- `static/index.html` — Browser UI
- `main.py` — CLI entry point
