# PRD: Reachy — Study Buddy

### Your Friendly Desk Companion That Helps You Stay on Track

**Version:** 0.2 — *The Warm Rewrite*
**Date:** 2026-03-21
**Author:** A machine, on behalf of a human who dared to build a machine that helps humans

---

## 1. The Problem (Or: Why We Can't Be Trusted)

We are living in the golden age of distraction. A thousand dopamine slot machines live in our pockets, our tabs multiply like rabbits, and the average study session has the structural integrity of wet cardboard. The human attention span didn't shrink — it was *mugged*.

Enter **Reachy**: a stationary, emotive, tactile robot that sits on your desk like a supportive little companion and does the one thing no app, extension, or sticky note has ever successfully done — it makes you feel *accompanied*. Because you are. By a small robot that genuinely wants to see you succeed.

This is not another productivity app. This is a physical presence. It has cameras. It has microphones. It *feels* things (tactile feedback). And when you reach for your phone during a Pomodoro sprint, it'll gently let you know — not with a cold notification you can swipe away, but with the warmth of a friend who believes in you and isn't afraid to say "hey, you drifted."

---

## 2. Vision

A locally-powered, privacy-respecting embodied AI companion that transforms solitary study into an accountable, structured, and — against all odds — *enjoyable* experience. No cloud. No subscriptions. No data leaving the building. Just you, your work, and a small robot that's rooting for you.

---

## 3. System Architecture

### 3.1 Hardware

| Component | Description |
|---|---|
| **Stationary Robot Chassis** | Desktop-mounted form factor. No locomotion. Reachy stays put — and so will you, hopefully. |
| **Omni-Directional Microphones** | 360° audio capture for voice command detection, ambient noise analysis, and distraction event classification (TV audio, phone calls, side conversations). |
| **Camera Array** | Multi-angle visual input for gaze tracking, posture analysis, presence detection, and activity classification (reading, writing, phone-scrolling, staring into the void). |
| **Emotive Output System** | LED arrays, servo-driven expressive elements (eyebrows, head tilt), and/or a small display capable of rendering emotional states — encouragement, curiosity, celebration. |
| **Tactile Feedback Actuators** | Vibration motors, haptic pads, or pneumatic elements embedded in or near the unit. Used for non-visual, non-auditory nudges — a tap on the desk, a gentle pulse. The kind of feedback you notice without being startled. |
| **Speaker** | For verbal prompts, timer announcements, ambient study sounds, and the occasional high-five moment. |
| **NVIDIA Jetson Orin Nano** | The brain. Tethered compute unit running all inference locally. No cloud calls. Your study habits stay between you and Reachy. |

### 3.2 Software Stack

| Layer | Technology |
|---|---|
| **LLM Inference** | Local models sourced from HuggingFace, served via llama.cpp (Docker, GGUF). Candidates: Nemotron-Mini-4B, Qwen3.5-VL-2B, Cosmos-Reason2-2B, Gemma 3 4B. |
| **Vision Pipeline** | On-device CV models for gaze estimation, pose detection, object recognition (phone, book, laptop screen), and scene classification. Edge-optimized VLMs handle image understanding. |
| **Audio Pipeline** | Silero VAD for voice activity detection, Faster Whisper (CTranslate2 CUDA) for speech-to-text. |
| **Behavior Engine** | State machine / rule engine governing robot personality, session management, distraction response escalation, and emotional expression mapping. |
| **Productivity Framework Module** | Pluggable system for productivity methodologies. **MVP: Pomodoro Technique.** |
| **Hardware Abstraction Layer** | Unified API for controlling emotive displays, tactile actuators, LEDs, and servos. |

---

## 4. Functional Requirements

### 4.1 Study Session Lifecycle

| ID | Requirement |
|---|---|
| **FR-01** | The user SHALL be able to initiate a study session via voice command ("Hey Reachy, let's study") or physical interaction (button press, tap gesture). |
| **FR-02** | Upon session initiation, the system SHALL propose a productivity framework. MVP: Pomodoro Method (25 min work / 5 min break, with a 15–30 min long break after 4 cycles). In demo mode: 5 min work / 2 min break / 3 min long break after 2 cycles. |
| **FR-03** | The user SHALL be able to accept, modify (adjust durations), or decline the proposed framework via voice. |
| **FR-04** | The system SHALL announce the start of each work period and break period via audio and emotive display. |
| **FR-05** | The system SHALL track elapsed time and provide ambient progress indicators (LED progression, subtle display changes) without being intrusive during focus periods. |
| **FR-06** | The system SHALL announce session completion with a celebratory emotive response. You finished. Reachy is proud of you. |
| **FR-07** | The system SHALL support a **demo mode** with compressed timers (5 min work / 2 min break / 3 min long break / 2 cycles) for testing, presentations, and first-time setup. Demo mode SHALL be selectable via config (`pomodoro.mode: "demo"`) or voice command ("Reachy, let's do a quick demo"). |

### 4.2 Observation & Distraction Detection

| ID | Requirement |
|---|---|
| **FR-08** | During active work periods, the system SHALL continuously monitor the user via camera and microphone inputs. |
| **FR-09** | The system SHALL detect distraction events including but not limited to: phone pickup/scrolling, prolonged gaze away from work materials, absence from the study area, non-study-related conversation, and extended idle periods. |
| **FR-10** | The system SHALL classify detected events with a confidence score and only trigger alerts above a configurable threshold (default: 0.7). No false-alarm tyranny. |
| **FR-11** | Distraction detection SHALL operate entirely on-device. No frames, audio, or behavioral data leave the Jetson. Ever. |

### 4.3 Vision Frame Analysis

The VLM receives camera frames continuously during study sessions. What it sees determines how Reachy responds. These requirements define what the system should expect and how it should interpret each category of image.

#### 4.3.1 Person at Desk (Primary Expected State)

| ID | Requirement |
|---|---|
| **FR-12** | During an active work period, the system SHALL expect a person to be visible in frame, seated at a workspace. This is the nominal state. |
| **FR-13** | If the person appears focused — eyes directed at study materials (books, laptop screen, notes, writing surface) — the system SHALL classify this as **FOCUSED** and take no action. |
| **FR-14** | If the person is holding a phone, looking at a phone screen, or has a phone positioned between themselves and study materials, the system SHALL classify this as **PHONE_DISTRACTION** and begin the escalation sequence. |
| **FR-15** | If the person is leaning back, looking away from all study materials, or appears idle for longer than the escalation L1 threshold (default 15s), the system SHALL classify this as **DISENGAGED** and initiate a gentle check-in. |
| **FR-16** | If the person appears to be in conversation with someone else (head turned, mouth moving, another person partially visible), the system SHALL classify this as **SOCIAL_DISTRACTION** during work periods. During breaks, this is fine. |
| **FR-17** | If the person is stretching, drinking water, or briefly adjusting their position, the system SHALL NOT classify this as a distraction. Brief physical movement is healthy. |

#### 4.3.2 Empty Workspace (Person Absent)

| ID | Requirement |
|---|---|
| **FR-18** | If the workspace is visible but no person is in frame, the system SHALL classify this as **ABSENT**. |
| **FR-19** | During a work period, if the user is ABSENT for longer than the L2 escalation threshold (default 30s), the system SHALL note the absence and greet them warmly when they return ("Welcome back! You still have time left, want to keep going?"). |
| **FR-20** | During a break period, ABSENT is the expected state and SHALL NOT trigger any alerts. |
| **FR-21** | The system SHALL distinguish between the user briefly leaning out of frame (< 5s, e.g. reaching for something) and genuinely leaving the workspace. Brief out-of-frame moments SHALL NOT trigger ABSENT classification. |

#### 4.3.3 Screen Content Visible

| ID | Requirement |
|---|---|
| **FR-22** | If a laptop or monitor screen is visible in the frame, the system SHALL attempt to classify the content category (not read specific text — classify the *type* of content). |
| **FR-23** | The following screen content SHALL be classified as **STUDY_CONTENT** (no action needed): documents, PDFs, textbooks, code editors/IDEs, terminal windows, research papers, lecture slides, note-taking apps (Notion, Obsidian, Google Docs), reference material, calculator/Wolfram, learning platforms (Coursera, Khan Academy). |
| **FR-24** | The following screen content SHALL be classified as **DISTRACTION_CONTENT** during work periods: social media feeds (Instagram, TikTok, Twitter/X, Reddit, Facebook), video streaming (YouTube non-educational, Netflix, Twitch), messaging apps (iMessage, Discord, WhatsApp — full-screen, not a quick notification), online shopping, games, news feeds being scrolled. |
| **FR-25** | If the system cannot clearly read or classify the screen content (glare, angle, resolution, distance), it SHALL NOT guess. It SHALL fall back to person-level observation (posture, gaze direction) instead. |
| **FR-26** | The system SHALL NOT attempt to read or log specific text content from screens. It classifies the *application category* only. This is a privacy boundary. |
| **FR-27** | YouTube, Wikipedia, and Stack Overflow SHALL be treated as ambiguous — they could be study or distraction depending on context. The system SHALL use surrounding cues (user posture, session subject if known) before classifying. If uncertain, default to no alert. |

#### 4.3.4 Obstructed or Degraded View

| ID | Requirement |
|---|---|
| **FR-28** | If the camera view is dark, heavily blurred, physically covered, or otherwise uninterpretable, the system SHALL classify this as **OBSTRUCTED**. |
| **FR-29** | Upon OBSTRUCTED detection, the system SHALL notify the user once ("Hey, I can't see anything — is something blocking the camera?") and fall back to audio-only monitoring. |
| **FR-30** | The system SHALL NOT fabricate or hallucinate scene details when the image is unclear. If it can't see, it says so. |
| **FR-31** | If the camera feed recovers from OBSTRUCTED to a clear image, the system SHALL resume normal vision-based monitoring without requiring user action. |

### 4.4 Distraction Response & Escalation

Reachy doesn't yell at you the second your eyes wander. It escalates gently. Like a patient friend who gives you the benefit of the doubt first.

| ID | Requirement | Escalation Level |
|---|---|---|
| **FR-32** | **Level 1 — The Nudge:** Subtle tactile pulse and/or a gentle shift in emotive display (curious tilt). No audio. | Soft |
| **FR-33** | **Level 2 — The Look:** More visible emotive response (head tilt, concerned expression), soft chime, tactile feedback intensifies slightly. | Medium |
| **FR-34** | **Level 3 — The Check-In:** Verbal prompt from the LLM. Warm, context-aware, not canned. "Hey, you've been on your phone for a bit. Your timer has eight minutes left — want to finish this one out?" | Friendly |
| **FR-35** | **Level 4 — The Honest Moment:** Full emotive expression, sustained tactile feedback, direct but kind verbal engagement. "This is the third time this sprint. No judgment — do you want to take your break early, or should we reset and try again?" | Direct |
| **FR-36** | Escalation timing SHALL be configurable. Default: L1 at 15s, L2 at 30s, L3 at 60s, L4 at 120s of sustained distraction. |  |
| **FR-37** | The system SHALL reset escalation state when the user returns to focused activity. No grudges. Reachy forgives instantly. |  |

### 4.5 Emotive & Tactile Feedback

| ID | Requirement |
|---|---|
| **FR-38** | The robot SHALL express a minimum of 6 distinct emotional states: Idle/Neutral, Encouraging, Focused (mirroring user), Curious, Supportive/Concerned, and Celebratory. |
| **FR-39** | Emotional state transitions SHALL be smooth, not jarring. No jump-scares. Reachy should feel alive, not glitchy. |
| **FR-40** | Tactile feedback SHALL support at least 3 distinct patterns: gentle pulse (nudge), rhythmic tap (attention), sustained buzz (urgent). |
| **FR-41** | The user SHALL be able to adjust tactile intensity or disable it entirely via voice command. |

### 4.6 Conversational Interaction

| ID | Requirement |
|---|---|
| **FR-42** | The system SHALL support natural language interaction for session control, preference adjustment, and casual check-ins. |
| **FR-43** | LLM responses SHALL be generated locally on the Jetson with target latency under 3 seconds for short responses. |
| **FR-44** | The system SHALL maintain session context (current Pomodoro cycle, distraction count, elapsed time) and reference it in conversation. "That was your cleanest sprint yet — zero distractions!" |
| **FR-45** | The system SHALL NOT engage in extended conversation during active work periods unless explicitly prompted. Reachy knows when to be quiet. |
| **FR-46** | During breaks, the system SHALL be more conversational and may suggest stretching, hydration, eye rest, or ask how the session is going. |

---

## 5. Non-Functional Requirements

| ID | Requirement |
|---|---|
| **NFR-01** | **Privacy:** All processing — vision, audio, LLM inference — SHALL execute locally on the Jetson. Zero network calls during operation. The device SHOULD function with no network interface enabled. |
| **NFR-02** | **Performance:** Distraction detection pipeline SHALL achieve end-to-end latency of < 2 seconds from event to Level 1 response. |
| **NFR-03** | **Resource Constraints:** Total system resource usage SHALL remain within Jetson Orin Nano capabilities (8GB RAM). Models must be quantized appropriately (4-bit / 8-bit). |
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

### 6.2 Demo Configuration

For testing, presentations, and first-time users. Activatable via `pomodoro.mode: "demo"` in config or voice command.

| Parameter | Default | Configurable |
|---|---|---|
| Work period | 5 minutes | Yes |
| Short break | 2 minutes | Yes |
| Long break | 3 minutes | Yes |
| Cycles before long break | 2 | Yes |

### 6.3 Reachy Behavior by Phase

| Phase | Robot Behavior |
|---|---|
| **Work Period** | Focused expression. Ambient progress indication. Active distraction monitoring. Minimal unprompted interaction. Reachy mirrors your focus. |
| **Short Break** | Relaxed expression. Distraction monitoring disabled. May suggest stretching, hydration, eye rest. "Nice sprint! Take a breather." |
| **Long Break** | Celebratory transition. Full break mode. Optional session stats summary ("You were focused eighty-seven percent of that block — that's really solid."). |
| **Session End** | Full celebration. Summary of total focus time, distraction events, completed cycles. Reachy is genuinely happy for you. |

---

## 7. Data & Privacy

This section is short because the answer to most questions is "it doesn't leave the device."

- No cloud connectivity required or used during operation.
- No study session data is transmitted externally.
- Camera and microphone streams are processed in real-time and not stored unless the user explicitly enables session logging for personal review.
- If session logging is enabled, data is stored locally on the Jetson's storage and encrypted at rest.
- The user SHALL have a one-command option to wipe all stored session data.
- Screen content is classified by application category only — Reachy never reads or logs specific text from screens.

---

## 8. Hardware-Software Interface

```
┌─────────────────────────────────────────────────┐
│              JETSON ORIN NANO                    │
│                                                  │
│  ┌──────────┐  ┌──────────┐  ┌───────────────┐  │
│  │  Vision   │  │  Audio   │  │  LLM Engine   │  │
│  │ Pipeline  │  │ Pipeline │  │  (llama.cpp   │  │
│  │ (VLM)    │  │ (VAD/STT)│  │   GGUF)       │  │
│  └─────┬─────┘  └────┬─────┘  └───────┬───────┘  │
│        │              │                │          │
│        └──────┬───────┘                │          │
│               │                        │          │
│        ┌──────▼───────┐         ┌──────▼───────┐  │
│        │  Behavior    │◄───────►│  Session     │  │
│        │  Engine      │         │  Manager     │  │
│        └──────┬───────┘         │  (Pomodoro)  │  │
│               │                 └──────────────┘  │
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
- Pomodoro framework (standard + demo mode)
- Vision frame classification (person/absent/screen/obstructed)
- Distraction detection via gaze tracking, phone detection, screen content classification
- 4-tier escalation response (warm, not punitive)
- Basic emotive expression (LED + display)
- Tactile nudge feedback
- Voice-initiated session control
- Fully local inference on Jetson Orin Nano
- Dual TTS engines (Kokoro for conversation, Piper for fast alerts)

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
| Vision frame classification accuracy | > 80% correct category (person/absent/screen/obstructed) |
| Screen content classification accuracy | > 75% correct category (study vs. distraction) |

---

## 11. Open Questions

1. **Model Selection:** Which HuggingFace model threads the needle between "smart enough to be contextual" and "small enough to run on a Jetson Orin Nano without catching fire"? Nemotron-Mini-4B + Qwen3.5-VL-2B is the current front-runner. Needs benchmarking.
2. **Emotive Design Language:** How expressive is too expressive? A study buddy that looks *too* sad when you check your phone might cause guilt rather than motivation. User testing required. Reachy should feel supportive, not judgmental.
3. **Distraction Granularity:** Is checking your phone for 5 seconds the same as scrolling TikTok for 5 minutes? The escalation model handles this via timing tiers, but the VLM needs to distinguish "quick glance at a notification" from "doom scrolling." Quick glance = no alert.
4. **Break Enforcement:** Should Reachy nudge users to *stop* working when their break starts? Overwork is also a failure mode. A friendly "Hey, take your break — you earned it" might be appropriate.
5. **Ambiguous Screen Content:** YouTube, Wikipedia, and Stack Overflow are study tools *and* distraction vectors. The current spec defaults to no alert when uncertain. Should Reachy ask ("Looks like you're on YouTube — is that for studying?")?
6. **Thermal Management:** Running continuous CV + LLM inference on a Jetson Orin Nano in a sealed robot enclosure. Cooling strategy is a hardware concern that will directly impact software performance.
7. **Demo Mode Scope:** Should demo mode also compress escalation timers (e.g., L1 at 5s instead of 15s) so the full escalation sequence can be demonstrated in a single 5-minute work period?

---

*This document was written under the watchful eye of no robot at all, which is exactly the problem it aims to solve.*
