# Reachy Study Buddy — Session State Manager
#
# Thread-safe Pomodoro session state machine. Pure in-memory — no disk I/O,
# no serialization, no race conditions with the vision pipeline.
#
# Architecture:
#   - In-memory SessionState (dataclass) is the sole source of truth
#   - threading.Lock protects all state reads/writes
#   - Background daemon thread ticks at 1s, checks phase transitions
#   - Callbacks fire outside the lock for phase changes and escalation
#   - If the process crashes, the session is gone — user says "let's study" again
#
# State machine:
#   IDLE → WORK → SHORT_BREAK → WORK → ... → LONG_BREAK → WORK → ... → COMPLETE
#                                                                           ↓
#   IDLE ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ← ←
#
# Threading model:
#   - Camera thread calls report_focus() → acquires lock, updates state, releases
#   - Tick thread acquires lock, checks elapsed time, transitions if needed
#   - Main thread calls snapshot(), remaining_secs(), etc. → acquires lock, reads, releases
#   - Callbacks (on_phase_change, on_escalation) fire on the tick thread AFTER lock release

import time
import threading
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Callable, Dict, List, Optional


class Phase(str, Enum):
    IDLE = "idle"
    WORK = "work"
    SHORT_BREAK = "short_break"
    LONG_BREAK = "long_break"
    PAUSED = "paused"
    COMPLETE = "complete"


class DistractionLevel(str, Enum):
    NONE = "none"
    L1_NUDGE = "l1_nudge"
    L2_LOOK = "l2_look"
    L3_CHECKIN = "l3_checkin"
    L4_DIRECT = "l4_direct"


@dataclass
class DistractionEvent:
    timestamp: float                    # time.monotonic() when detected
    wall_time: float                    # time.time() for human readability
    classification: str                 # PHONE_DISTRACTION, DISENGAGED, etc.
    confidence: float
    escalation_level: str               # DistractionLevel value
    duration_secs: float = 0.0          # how long the distraction lasted


@dataclass
class SessionState:
    # Phase
    phase: str = Phase.IDLE
    phase_start_mono: float = 0.0       # time.monotonic() when current phase started

    # Pomodoro tracking
    current_cycle: int = 0              # 0-indexed, increments after each WORK phase
    total_cycles: int = 4               # cycles before long break
    work_minutes: float = 25.0
    short_break_minutes: float = 5.0
    long_break_minutes: float = 15.0

    # Session stats
    session_start_mono: float = 0.0
    total_focus_secs: float = 0.0       # accumulated focused time (excludes distractions)
    total_distracted_secs: float = 0.0
    distraction_count: int = 0
    completed_pomodoros: int = 0

    # Distraction tracking within the current work phase
    # total_distracted_secs accumulates across the entire session.
    # _phase_distracted_secs tracks distraction within the current work phase only,
    # so that focus = phase_elapsed - phase_distracted when the phase ends.
    phase_distracted_secs: float = 0.0

    # Current distraction state
    escalation_level: str = DistractionLevel.NONE
    distraction_start_mono: float = 0.0 # when current distraction began (0 = not distracted)
    last_focus_classification: str = "" # last vision classification

    # Pause state
    paused_phase: str = ""              # phase before pausing
    pause_start_mono: float = 0.0

    # Distraction event log (capped for memory)
    distraction_events: List = field(default_factory=list)


# Escalation thresholds (seconds of sustained distraction before each level)
DEFAULT_ESCALATION_THRESHOLDS = {
    DistractionLevel.L1_NUDGE: 15.0,
    DistractionLevel.L2_LOOK: 30.0,
    DistractionLevel.L3_CHECKIN: 60.0,
    DistractionLevel.L4_DIRECT: 120.0,
}

MAX_DISTRACTION_LOG = 50


class SessionManager:
    """Thread-safe, in-memory Pomodoro session manager.

    Usage:
        manager = SessionManager(config.pomodoro)
        manager.on_phase_change = my_callback     # (old_phase, new_phase, snapshot)
        manager.on_escalation = my_escalation_cb  # (level, snapshot)
        manager.start_session()
        ...
        manager.report_focus("FOCUSED", 0.9)      # called from vision pipeline
        manager.report_focus("PHONE_DISTRACTION", 0.85)
        ...
        manager.stop_session()
    """

    def __init__(self, pomodoro_config=None,
                 escalation_thresholds: Optional[Dict] = None):
        self._state = SessionState()
        self._lock = threading.Lock()
        self._tick_thread: Optional[threading.Thread] = None
        self._running = threading.Event()

        # Pending callbacks (set under lock, fired after lock release)
        self._pending_phase_change: Optional[tuple] = None
        self._pending_escalation: Optional[tuple] = None

        # Callbacks — assigned by the caller, fired on the tick thread
        self.on_phase_change: Optional[Callable] = None     # (old_phase, new_phase, snapshot)
        self.on_escalation: Optional[Callable] = None       # (level, snapshot)
        self.on_tick: Optional[Callable] = None             # (snapshot) — every second

        # Escalation config
        self._escalation_thresholds = escalation_thresholds or dict(DEFAULT_ESCALATION_THRESHOLDS)

        # Apply pomodoro config if provided
        if pomodoro_config is not None:
            active = pomodoro_config.active
            self._state.work_minutes = active.work_minutes
            self._state.short_break_minutes = active.short_break_minutes
            self._state.long_break_minutes = active.long_break_minutes
            self._state.total_cycles = active.cycles_before_long_break

    # ──────────────────────────────────────────────────────────────
    # Session lifecycle
    # ──────────────────────────────────────────────────────────────

    def start_session(self, work_minutes: float = 0, short_break_minutes: float = 0,
                      long_break_minutes: float = 0, total_cycles: int = 0):
        """Start a new Pomodoro session. Overrides config values if provided."""
        with self._lock:
            now = time.monotonic()
            self._state = SessionState(
                phase=Phase.WORK,
                phase_start_mono=now,
                session_start_mono=now,
                current_cycle=0,
                total_cycles=total_cycles or self._state.total_cycles,
                work_minutes=work_minutes or self._state.work_minutes,
                short_break_minutes=short_break_minutes or self._state.short_break_minutes,
                long_break_minutes=long_break_minutes or self._state.long_break_minutes,
            )

        self._fire_phase_change(Phase.IDLE, Phase.WORK)
        self._start_tick_thread()

    def stop_session(self):
        """End the current session."""
        self._running.clear()
        with self._lock:
            old_phase = self._state.phase
            if old_phase == Phase.WORK:
                self._finalize_work_phase()
            self._state.phase = Phase.COMPLETE
            self._state.escalation_level = DistractionLevel.NONE
            self._state.distraction_start_mono = 0.0

        self._fire_phase_change(old_phase, Phase.COMPLETE)

    def pause_session(self):
        """Pause the current session. Timer stops, escalation resets."""
        with self._lock:
            if self._state.phase in (Phase.IDLE, Phase.COMPLETE, Phase.PAUSED):
                return
            old_phase = self._state.phase
            self._state.paused_phase = old_phase
            if old_phase == Phase.WORK:
                self._finalize_work_phase()
            self._state.phase = Phase.PAUSED
            self._state.pause_start_mono = time.monotonic()
            self._state.escalation_level = DistractionLevel.NONE
            self._state.distraction_start_mono = 0.0

        self._fire_phase_change(old_phase, Phase.PAUSED)

    def resume_session(self):
        """Resume from pause. Adjusts phase start time to account for pause duration."""
        with self._lock:
            if self._state.phase != Phase.PAUSED:
                return
            now = time.monotonic()
            pause_duration = now - self._state.pause_start_mono
            # Shift phase start forward so elapsed doesn't include pause
            self._state.phase_start_mono += pause_duration
            resumed_phase = self._state.paused_phase
            self._state.phase = resumed_phase
            self._state.paused_phase = ""
            self._state.pause_start_mono = 0.0

        self._fire_phase_change(Phase.PAUSED, resumed_phase)

    def reset(self):
        """Reset to idle. Preserves timing config."""
        self._running.clear()
        with self._lock:
            self._state = SessionState(
                work_minutes=self._state.work_minutes,
                short_break_minutes=self._state.short_break_minutes,
                long_break_minutes=self._state.long_break_minutes,
                total_cycles=self._state.total_cycles,
            )

    # ──────────────────────────────────────────────────────────────
    # Focus / distraction reporting (called from vision pipeline)
    # ──────────────────────────────────────────────────────────────

    def report_focus(self, classification: str, confidence: float = 1.0):
        """Report a vision classification from the VLM pipeline.

        Args:
            classification: One of FOCUSED, PHONE_DISTRACTION, DISENGAGED,
                          SOCIAL_DISTRACTION, ABSENT, STUDY_CONTENT,
                          DISTRACTION_CONTENT, OBSTRUCTED
            confidence: Model confidence score (0.0 - 1.0)
        """
        pending_esc = None
        with self._lock:
            if self._state.phase != Phase.WORK:
                return

            self._state.last_focus_classification = classification
            now = time.monotonic()

            is_distracted = classification in (
                "PHONE_DISTRACTION", "DISENGAGED", "SOCIAL_DISTRACTION",
                "ABSENT", "DISTRACTION_CONTENT",
            )

            if is_distracted and confidence >= 0.7:
                pending_esc = self._handle_distraction(now, classification, confidence)
            else:
                self._handle_focus_restored(now)

        # Fire escalation callback outside the lock
        if pending_esc is not None:
            level, snap = pending_esc
            if self.on_escalation:
                try:
                    self.on_escalation(level, snap)
                except Exception:
                    pass

    def _handle_distraction(self, now: float, classification: str,
                            confidence: float) -> Optional[tuple]:
        """Update distraction state and check escalation. Lock must be held.

        Returns (level, snapshot) if escalation changed, else None.
        """
        if self._state.distraction_start_mono == 0.0:
            # New distraction event
            self._state.distraction_start_mono = now
            self._state.distraction_count += 1

        distracted_secs = now - self._state.distraction_start_mono
        new_level = self._compute_escalation_level(distracted_secs)

        if new_level != self._state.escalation_level:
            self._state.escalation_level = new_level

            # Log the event
            event = DistractionEvent(
                timestamp=now,
                wall_time=time.time(),
                classification=classification,
                confidence=confidence,
                escalation_level=new_level,
                duration_secs=distracted_secs,
            )
            self._state.distraction_events.append(asdict(event))
            if len(self._state.distraction_events) > MAX_DISTRACTION_LOG:
                self._state.distraction_events = self._state.distraction_events[-MAX_DISTRACTION_LOG:]

            return (new_level, self._snapshot_unlocked())

        return None

    def _handle_focus_restored(self, now: float):
        """User returned to focus. Reset escalation. Lock must be held."""
        if self._state.distraction_start_mono > 0.0:
            distracted_duration = now - self._state.distraction_start_mono
            self._state.total_distracted_secs += distracted_duration
            self._state.phase_distracted_secs += distracted_duration
            self._state.distraction_start_mono = 0.0
            self._state.escalation_level = DistractionLevel.NONE

    def _compute_escalation_level(self, distracted_secs: float) -> str:
        """Determine escalation level from distraction duration."""
        level = DistractionLevel.NONE
        for lvl in (DistractionLevel.L1_NUDGE, DistractionLevel.L2_LOOK,
                    DistractionLevel.L3_CHECKIN, DistractionLevel.L4_DIRECT):
            threshold = self._escalation_thresholds.get(lvl, float("inf"))
            if distracted_secs >= threshold:
                level = lvl
        return level

    # ──────────────────────────────────────────────────────────────
    # State queries (thread-safe)
    # ──────────────────────────────────────────────────────────────

    def snapshot(self) -> dict:
        """Return a thread-safe copy of the current state as a dict."""
        with self._lock:
            return self._snapshot_unlocked()

    def _snapshot_unlocked(self) -> dict:
        """Snapshot without acquiring lock. Caller must hold self._lock."""
        s = asdict(self._state)
        now = time.monotonic()

        # Computed: elapsed / remaining
        if self._state.phase in (Phase.WORK, Phase.SHORT_BREAK, Phase.LONG_BREAK):
            elapsed = now - self._state.phase_start_mono
            duration = self._phase_duration_secs()
            s["phase_elapsed_secs"] = elapsed
            s["phase_remaining_secs"] = max(0, duration - elapsed)
        else:
            s["phase_elapsed_secs"] = 0.0
            s["phase_remaining_secs"] = 0.0

        # Computed: focus percentage
        s["focus_percent"] = self._focus_percent_unlocked()

        # Computed: current distraction info
        s["is_distracted"] = self._state.distraction_start_mono > 0.0
        if s["is_distracted"]:
            s["current_distraction_secs"] = now - self._state.distraction_start_mono
        else:
            s["current_distraction_secs"] = 0.0

        # Computed: session duration
        if self._state.session_start_mono > 0:
            s["session_elapsed_secs"] = now - self._state.session_start_mono
        else:
            s["session_elapsed_secs"] = 0.0

        return s

    @property
    def phase(self) -> str:
        with self._lock:
            return self._state.phase

    @property
    def is_active(self) -> bool:
        with self._lock:
            return self._state.phase in (Phase.WORK, Phase.SHORT_BREAK, Phase.LONG_BREAK)

    @property
    def is_work_phase(self) -> bool:
        with self._lock:
            return self._state.phase == Phase.WORK

    def remaining_secs(self) -> float:
        """Seconds remaining in the current phase."""
        with self._lock:
            if self._state.phase not in (Phase.WORK, Phase.SHORT_BREAK, Phase.LONG_BREAK):
                return 0.0
            elapsed = time.monotonic() - self._state.phase_start_mono
            return max(0, self._phase_duration_secs() - elapsed)

    def remaining_formatted(self) -> str:
        """Human-readable remaining time, e.g. '4:32'."""
        secs = self.remaining_secs()
        mins = int(secs // 60)
        s = int(secs % 60)
        return f"{mins}:{s:02d}"

    def focus_percent(self) -> float:
        """Percentage of work time spent focused (0-100)."""
        with self._lock:
            return self._focus_percent_unlocked()

    def _focus_percent_unlocked(self) -> float:
        total = self._state.total_focus_secs + self._state.total_distracted_secs
        if total <= 0:
            return 100.0
        return round(100.0 * self._state.total_focus_secs / total, 1)

    def session_summary(self) -> dict:
        """Summary stats for end-of-session reporting."""
        with self._lock:
            now = time.monotonic()
            return {
                "completed_pomodoros": self._state.completed_pomodoros,
                "total_focus_secs": round(self._state.total_focus_secs, 1),
                "total_distracted_secs": round(self._state.total_distracted_secs, 1),
                "focus_percent": self._focus_percent_unlocked(),
                "distraction_count": self._state.distraction_count,
                "total_cycles": self._state.total_cycles,
                "session_elapsed_secs": round(now - self._state.session_start_mono, 1)
                    if self._state.session_start_mono > 0 else 0.0,
            }

    # ──────────────────────────────────────────────────────────────
    # Timer tick thread
    # ──────────────────────────────────────────────────────────────

    def _start_tick_thread(self):
        """Start the background timer thread."""
        if self._tick_thread and self._tick_thread.is_alive():
            return
        self._running.set()
        self._tick_thread = threading.Thread(target=self._tick_loop, daemon=True,
                                             name="reachy-session-tick")
        self._tick_thread.start()

    def _tick_loop(self):
        """Background thread: checks phase transitions every second."""
        while self._running.is_set():
            pending_phase = None

            with self._lock:
                if self._state.phase in (Phase.WORK, Phase.SHORT_BREAK, Phase.LONG_BREAK):
                    elapsed = time.monotonic() - self._state.phase_start_mono
                    duration = self._phase_duration_secs()
                    if elapsed >= duration:
                        pending_phase = self._transition_phase()

            # Fire phase change callback outside the lock
            if pending_phase is not None:
                old_p, new_p = pending_phase
                self._fire_phase_change(old_p, new_p)

            # Fire tick callback
            if self.on_tick:
                try:
                    self.on_tick(self.snapshot())
                except Exception:
                    pass

            # Sleep 1 second between ticks
            self._running.wait(timeout=1.0)

    def _phase_duration_secs(self) -> float:
        """Duration of the current phase in seconds. Lock must be held."""
        if self._state.phase == Phase.WORK:
            return self._state.work_minutes * 60
        elif self._state.phase == Phase.SHORT_BREAK:
            return self._state.short_break_minutes * 60
        elif self._state.phase == Phase.LONG_BREAK:
            return self._state.long_break_minutes * 60
        return 0.0

    def _transition_phase(self) -> Optional[tuple]:
        """Move to the next phase. Lock must be held.

        Returns (old_phase, new_phase) for the callback, or None.
        """
        old_phase = self._state.phase
        now = time.monotonic()

        if old_phase == Phase.WORK:
            self._finalize_work_phase()
            self._state.completed_pomodoros += 1
            self._state.current_cycle += 1

            if self._state.current_cycle >= self._state.total_cycles:
                new_phase = Phase.LONG_BREAK
                self._state.current_cycle = 0
            else:
                new_phase = Phase.SHORT_BREAK

        elif old_phase == Phase.SHORT_BREAK:
            new_phase = Phase.WORK

        elif old_phase == Phase.LONG_BREAK:
            new_phase = Phase.COMPLETE

        else:
            return None

        self._state.phase = new_phase
        self._state.phase_start_mono = now
        self._state.phase_distracted_secs = 0.0
        self._state.escalation_level = DistractionLevel.NONE
        self._state.distraction_start_mono = 0.0

        return (old_phase, new_phase)

    def _finalize_work_phase(self):
        """Accumulate focus/distraction time for the ending work phase. Lock must be held."""
        if self._state.phase != Phase.WORK:
            return
        now = time.monotonic()
        phase_elapsed = now - self._state.phase_start_mono

        # Close out any in-progress distraction
        if self._state.distraction_start_mono > 0.0:
            current = now - self._state.distraction_start_mono
            self._state.total_distracted_secs += current
            self._state.phase_distracted_secs += current
            self._state.distraction_start_mono = 0.0

        # Focus = phase time minus distracted time within this phase
        focused = max(0, phase_elapsed - self._state.phase_distracted_secs)
        self._state.total_focus_secs += focused

    # ──────────────────────────────────────────────────────────────
    # Callbacks (fired outside the lock)
    # ──────────────────────────────────────────────────────────────

    def _fire_phase_change(self, old_phase: str, new_phase: str):
        if self.on_phase_change:
            try:
                self.on_phase_change(old_phase, new_phase, self.snapshot())
            except Exception:
                pass
