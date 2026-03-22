# PRD: The Attention Warden

### A Study Buddy That Won't Let You Scroll Into the Abyss

**Version:** 0.1 — *The Fear and Loathing Draft*
**Date:** 2026-03-21
**Author:** A machine, on behalf of a human who dared to build a machine that watches humans

---

## 1. The Problem (Or: Why We Can't Be Trusted)

We are living in the golden age of distraction. A thousand dopamine slot machines live in our pockets, our tabs multiply like rabbits, and the average study session has the structural integrity of wet cardboard. The human attention span didn't shrink — it was *mugged*.

Enter **The Attention Warden**: a stationary, emotive, tactile robot that sits on your desk like a sentient gargoyle and does the one thing no app, extension, or sticky note has ever successfully done — it makes you *feel watched*. Because you are. By a machine that cares. Or at least performs caring with unsettling conviction.

This is not another productivity app. This is a physical presence. It has cameras. It has microphones. It *feels* things (tactile feedback). And when you reach for your phone during a Pomodoro sprint, it will let you know — not with a polite notification you can swipe away, but with the full embodied disappointment of a robot that believed in you.

---

## 2. Vision

A locally-powered, privacy-respecting embodied AI companion that transforms solitary study into an accountable, structured, and — against all odds — *enjoyable* experience. No cloud. No subscriptions. No data leaving the building. Just you, your work, and a small robot that refuses to let you waste your own time.

---

## 3. System Architecture

### 3.1 Hardware

| Component | Description |
|---|---|
| **Stationary Robot Chassis** | Desktop-mounted form factor. No locomotion. It doesn't need to chase you — it knows you're not going anywhere. |
| **Omni-Directional Microphones** | 360° audio capture for voice command detection, ambient noise analysis, and distraction event classification (TV audio, phone calls, side conversations). |
| **Camera Array** | Multi-angle visual input for gaze tracking, posture analysis, presence detection, and activity classification (reading, writing, phone-scrolling, staring into the void). |
| **Emotive Output System** | LED arrays, servo-driven expressive elements (eyebrows, head tilt), and/or a small display capable of rendering emotional states — encouragement, concern, gentle disapproval, celebration. |
| **Tactile Feedback Actuators** | Vibration motors, haptic pads, or pneumatic elements embedded in or near the unit. Used for non-visual, non-auditory alerts — a tap on the desk, a pulse, a nudge. The kind of feedback you can't ignore by looking away. |
| **Speaker** | For verbal prompts, timer announcements, ambient study sounds, and the occasional motivational gut-punch. |
| **NVIDIA Jetson Nano** | The brain. Tethered compute unit running all inference locally. No cloud calls. Your study habits stay between you and the gargoyle. |

### 3.2 Software Stack

| Layer | Technology |
|---|---|
| **LLM Inference** | Local models sourced from HuggingFace, optimized for Jetson Nano (quantized, GGUF/ONNX). Candidates: small instruction-tuned models (e.g., Phi-3-mini, TinyLlama, Gemma 2B) capable of conversational interaction and decision-making within resource constraints. |
| **Vision Pipeline** | On-device CV models for gaze estimation, pose detection, object recognition (phone, book, laptop screen). MediaPipe, YOLO-nano, or equivalent edge-optimized models. |
| **Audio Pipeline** | Wake-word detection, voice activity detection (VAD), ambient sound classification. Whisper-tiny or equivalent for speech-to-text. |
| **Behavior Engine** | State machine / rule engine governing robot personality, session management, distraction response escalation, and emotional expression mapping. |
| **Productivity Framework Module** | Pluggable system for productivity methodologies. **MVP: Pomodoro Technique.** |
| **Hardware Abstraction Layer** | Unified API for controlling emotive displays, tactile actuators, LEDs, and servos. |

---

## 4. Functional Requirements

### 4.1 Study Session Lifecycle

| ID | Requirement |
|---|---|
| **FR-01** | The user SHALL be able to initiate a study session via voice command ("Hey Warden, let's study") or physical interaction (button press, tap gesture). |
| **FR-02** | Upon session initiation, the system SHALL propose a productivity framework. MVP: Pomodoro Method (25 min work / 5 min break, with a 15–30 min long break after 4 cycles). |
| **FR-03** | The user SHALL be able to accept, modify (adjust durations), or decline the proposed framework via voice. |
| **FR-04** | The system SHALL announce the start of each work period and break period via audio and emotive display. |
| **FR-05** | The system SHALL track elapsed time and provide ambient progress indicators (LED progression, subtle display changes) without being intrusive during focus periods. |
| **FR-06** | The system SHALL announce session completion with a celebratory emotive response. You finished. The gargoyle is proud. |

### 4.2 Observation & Distraction Detection

| ID | Requirement |
|---|---|
| **FR-07** | During active work periods, the system SHALL continuously monitor the user via camera and microphone inputs. |
| **FR-08** | The system SHALL detect distraction events including but not limited to: phone pickup/scrolling, prolonged gaze away from work materials, absence from the study area, non-study-related conversation, and extended idle periods. |
| **FR-09** | The system SHALL classify detected events with a confidence score and only trigger alerts above a configurable threshold (default: 0.7). No false-alarm tyranny. |
| **FR-10** | Distraction detection SHALL operate entirely on-device. No frames, audio, or behavioral data leave the Jetson Nano. Ever. |

### 4.3 Distraction Response & Escalation

The Warden doesn't scream at you the second your eyes wander. It escalates. Like a patient but increasingly concerned friend.

| ID | Requirement | Escalation Level |
|---|---|---|
| **FR-11** | **Level 1 — The Nudge:** Subtle tactile pulse and/or a gentle shift in emotive display (curious expression). No audio. | Soft |
| **FR-12** | **Level 2 — The Look:** More pronounced emotive response (concerned expression), soft chime, tactile feedback intensifies. | Medium |
| **FR-13** | **Level 3 — The Call-Out:** Verbal prompt from the LLM. Context-aware, not canned. "You've been on your phone for two minutes. Your Pomodoro has 8 minutes left — you've got this." | Firm |
| **FR-14** | **Level 4 — The Intervention:** Full emotive expression (disappointed face), sustained tactile feedback, direct verbal engagement. "This is the third time this cycle. Want to take your break early, or do you want to lock in?" | Direct |
| **FR-15** | Escalation timing SHALL be configurable. Default: L1 at 15s, L2 at 30s, L3 at 60s, L4 at 120s of sustained distraction. |  |
| **FR-16** | The system SHALL reset escalation state when the user returns to focused activity. Forgiveness is instant. Grudges are not productive. |  |

### 4.4 Emotive & Tactile Feedback

| ID | Requirement |
|---|---|
| **FR-17** | The robot SHALL express a minimum of 6 distinct emotional states: Idle/Neutral, Encouraging, Focused (mirroring user), Curious/Concerned, Disappointed, and Celebratory. |
| **FR-18** | Emotional state transitions SHALL be smooth, not jarring. No jump-scares. |
| **FR-19** | Tactile feedback SHALL support at least 3 distinct patterns: gentle pulse (nudge), rhythmic tap (attention), sustained buzz (urgent). |
| **FR-20** | The user SHALL be able to adjust tactile intensity or disable it entirely via voice command. |

### 4.5 Conversational Interaction

| ID | Requirement |
|---|---|
| **FR-21** | The system SHALL support natural language interaction for session control, preference adjustment, and casual check-ins. |
| **FR-22** | LLM responses SHALL be generated locally on the Jetson Nano with target latency under 3 seconds for short responses. |
| **FR-23** | The system SHALL maintain session context (current Pomodoro cycle, distraction count, elapsed time) and reference it in conversation. "That was your cleanest sprint yet — zero distractions." |
| **FR-24** | The system SHALL NOT engage in extended conversation during active work periods unless explicitly prompted. It's a study buddy, not a chat buddy. |

---

## 5. Non-Functional Requirements

| ID | Requirement |
|---|---|
| **NFR-01** | **Privacy:** All processing — vision, audio, LLM inference — SHALL execute locally on the Jetson Nano. Zero network calls during operation. The device SHOULD function with no network interface enabled. |
| **NFR-02** | **Performance:** Distraction detection pipeline SHALL achieve end-to-end latency of < 2 seconds from event to Level 1 response. |
| **NFR-03** | **Resource Constraints:** Total system resource usage SHALL remain within Jetson Nano capabilities (4GB RAM, 128-core Maxwell GPU). Models must be quantized appropriately (4-bit / 8-bit). |
| **NFR-04** | **Reliability:** The system SHALL sustain a 4-hour continuous study session without degradation, memory leaks, or thermal throttling beyond acceptable limits. |
| **NFR-05** | **Configurability:** Distraction thresholds, escalation timing, Pomodoro durations, tactile intensity, and emotive expressiveness SHALL all be user-configurable. |
| **NFR-06** | **Graceful Degradation:** If any single input modality fails (camera occlusion, mic noise), the system SHALL continue operating on remaining inputs and notify the user. |

---

## 6. Productivity Framework: Pomodoro Method (MVP)

The first and only framework at launch. Others can come later. Get this one right.

### 6.1 Standard Configuration

| Parameter | Default | Configurable |
|---|---|---|
| Work period | 25 minutes | Yes |
| Short break | 5 minutes | Yes |
| Long break | 15 minutes | Yes |
| Cycles before long break | 4 | Yes |

### 6.2 Warden Behavior by Phase

| Phase | Robot Behavior |
|---|---|
| **Work Period** | Focused expression. Ambient progress indication. Active distraction monitoring. Minimal unprompted interaction. |
| **Short Break** | Relaxed expression. Distraction monitoring disabled. Optional: suggest stretching, hydration, eye rest. |
| **Long Break** | Celebratory transition. Full break mode. Optional: session stats summary ("You were focused 87% of that block — that's up from last time"). |
| **Session End** | Full celebration. Summary of total focus time, distraction events, completed cycles. The robot is genuinely happy for you. Or performing happiness. Same difference. |

---

## 7. Data & Privacy

This section is short because the answer to most questions is "it doesn't leave the device."

- No cloud connectivity required or used during operation.
- No study session data is transmitted externally.
- Camera and microphone streams are processed in real-time and not stored unless the user explicitly enables session logging for personal review.
- If session logging is enabled, data is stored locally on the Jetson Nano's storage and encrypted at rest.
- The user SHALL have a one-command option to wipe all stored session data.

---

## 8. Hardware-Software Interface

```
┌─────────────────────────────────────────────────┐
│                  JETSON NANO                     │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Vision   │  │  Audio   │  │  LLM Engine   │  │
│  │ Pipeline  │  │ Pipeline │  │  (HuggingFace │  │
│  │ (CV/Gaze) │  │ (VAD/STT)│  │   Local)      │  │
│  └─────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│        │              │                │          │
│        └──────┬───────┘                │          │
│               │                        │          │
│        ┌──────▼───────┐         ┌──────▼───────┐  │
│        │  Behavior    │◄───────►│  Session     │  │
│        │  Engine      │         │  Manager     │  │
│        └──────┬───────┘         └──────────────┘  │
│               │                                   │
│        ┌──────▼───────┐                           │
│        │  Hardware    │                           │
│        │  Abstraction │                           │
│        │  Layer       │                           │
│        └──────┬───────┘                           │
└───────────────┼───────────────────────────────────┘
                │
    ┌───────────┼───────────────┐
    │           │               │
┌───▼───┐  ┌───▼───┐  ┌───────▼────────┐
│Emotive│  │Tactile│  │  Mic/Camera    │
│Display│  │Haptics│  │  Array         │
└───────┘  └───────┘  └────────────────┘
```

---

## 9. MVP Scope

**In:**
- Single-user, single-session operation
- Pomodoro framework only
- Distraction detection via gaze tracking + phone detection
- 4-tier escalation response
- Basic emotive expression (LED + display)
- Tactile nudge feedback
- Voice-initiated session control
- Fully local inference on Jetson Nano

**Out (Future):**
- Multi-user profiles
- Additional productivity frameworks (Flowtime, 52/17, Time Blocking)
- Learning/adapting to individual distraction patterns over time
- Integration with external study tools (Anki, Notion, calendar)
- Mobile companion app for session history review
- Multi-room / multi-device setups
- Ambient music / soundscape generation

---

## 10. Success Metrics

Because if you can't measure it, it's just a desk ornament.

| Metric | Target |
|---|---|
| Distraction detection accuracy | > 85% precision, > 80% recall |
| False positive rate (alerts during actual focus) | < 10% |
| User-reported focus improvement after 2 weeks | > 20% increase in self-assessed productivity |
| Session completion rate (started vs. finished Pomodoros) | > 75% |
| LLM response latency | < 3 seconds (p95) |
| System uptime per session | > 99% (no crashes in a 4-hour window) |

---

## 11. Open Questions

The things that keep the gargoyle up at night:

1. **Model Selection:** Which HuggingFace model threads the needle between "smart enough to be contextual" and "small enough to run on a Jetson Nano without catching fire"? Phi-3-mini quantized to 4-bit is the current front-runner. Needs benchmarking.
2. **Emotive Design Language:** How expressive is too expressive? A study buddy that looks *too* disappointed might cause anxiety rather than motivation. User testing required.
3. **Distraction Granularity:** Is checking your phone for 5 seconds the same as scrolling TikTok for 5 minutes? The escalation model needs nuance. Quick glance ≠ doom scroll.
4. **Break Enforcement:** Should the Warden nudge users to *stop* working when their break starts? Overwork is also a failure mode.
5. **Personality Configuration:** Should users be able to choose between "gentle encourager" and "drill sergeant"? How many personality presets?
6. **Thermal Management:** Running continuous CV + LLM inference on a Jetson Nano in a sealed robot enclosure. Cooling strategy is a hardware concern that will directly impact software performance.

---

*This document was written under the watchful eye of no robot at all, which is exactly the problem it aims to solve.*
