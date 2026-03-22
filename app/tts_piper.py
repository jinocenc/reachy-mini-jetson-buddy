# Attention Warden — Piper TTS Backend
#
# Lightweight, fast TTS using Piper (ONNX-based).
# Lower latency than Kokoro, smaller footprint — ideal for rapid
# distraction alerts where speed matters more than prosody richness.
#
# Piper voices are small ONNX models (~60-80 MB each) from:
# https://huggingface.co/rhasspy/piper-voices
#
# No GPL isolation needed — Piper is MIT-licensed.

import json
import wave
import subprocess
from typing import Dict, Any, Optional
from pathlib import Path

import numpy as np


PIPER_DIR = Path(__file__).resolve().parent.parent / "voices" / "piper"

# Voice model URLs (HuggingFace rhasspy/piper-voices)
PIPER_VOICE_BASE = "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US"


def _download_piper_voice(voice: str) -> bool:
    """Download a Piper voice model if not present."""
    PIPER_DIR.mkdir(parents=True, exist_ok=True)
    onnx_path = PIPER_DIR / f"{voice}.onnx"
    json_path = PIPER_DIR / f"{voice}.onnx.json"

    if onnx_path.exists() and json_path.exists():
        return True

    # Parse voice name: en_US-amy-medium → amy/medium
    parts = voice.replace("en_US-", "").split("-")
    if len(parts) < 2:
        print(f"Piper: cannot parse voice name '{voice}'")
        return False

    speaker, quality = parts[0], parts[1]
    onnx_url = f"{PIPER_VOICE_BASE}/{speaker}/{quality}/{voice}.onnx"
    json_url = f"{PIPER_VOICE_BASE}/{speaker}/{quality}/{voice}.onnx.json"

    try:
        import httpx
    except ImportError:
        print("Piper: install httpx to auto-download voices (pip install httpx)")
        return False

    for url, path, label in [(onnx_url, onnx_path, f"{voice}.onnx"),
                              (json_url, json_path, f"{voice}.onnx.json")]:
        if path.exists():
            continue
        print(f"Downloading Piper voice: {label} ...")
        try:
            with httpx.stream("GET", url, follow_redirects=True, timeout=60.0) as r:
                r.raise_for_status()
                with open(path, "wb") as f:
                    for chunk in r.iter_bytes(chunk_size=262144):
                        f.write(chunk)
            print(f"  Saved {path}")
        except Exception as e:
            print(f"  Download failed: {e}")
            return False

    return True


class PiperTTS:
    """Piper TTS — fast, lightweight, MIT-licensed neural TTS."""

    def __init__(self, voice: str = "en_US-amy-medium", speed: float = 1.0, **_kwargs):
        self.voice = voice
        self.speed = speed
        self._sample_rate = 22050
        self.backend_name = "Piper"
        self.provider = "onnxruntime"
        self._synth = None

    def load(self) -> bool:
        onnx_path = PIPER_DIR / f"{self.voice}.onnx"
        json_path = PIPER_DIR / f"{self.voice}.onnx.json"

        if not onnx_path.exists() or not json_path.exists():
            if not _download_piper_voice(self.voice):
                return False

        try:
            from piper import PiperVoice
            self._synth = PiperVoice.load(str(onnx_path), str(json_path))

            # Read sample rate from config
            with open(json_path) as f:
                config = json.load(f)
                self._sample_rate = config.get("audio", {}).get("sample_rate", 22050)

            self.provider = "piper-onnx"
            return True
        except ImportError:
            print("Piper TTS not installed. Install with: pip install piper-tts")
            return False
        except Exception as e:
            print(f"Piper TTS load failed: {e}")
            return False

    def synthesize(self, text: str) -> Dict[str, Any]:
        if not text.strip():
            return {"audio": None, "error": "Empty"}
        if self._synth is None:
            return {"audio": None, "error": "Piper not loaded"}

        try:
            # Piper synthesize returns a generator of audio chunks
            import io
            wav_buffer = io.BytesIO()
            with wave.open(wav_buffer, "wb") as wf:
                self._synth.synthesize(
                    text,
                    wf,
                    length_scale=1.0 / max(self.speed, 0.1),
                )
            wav_buffer.seek(0)

            with wave.open(wav_buffer, "rb") as wf:
                frames = wf.readframes(wf.getnframes())
                audio = np.frombuffer(frames, dtype=np.int16)
                sample_rate = wf.getframerate()

            return {"audio": audio, "sample_rate": sample_rate}
        except Exception as e:
            return {"audio": None, "error": str(e)}

    def synthesize_to_file(self, text: str, path: str) -> bool:
        r = self.synthesize(text)
        if r.get("audio") is None:
            return False
        with wave.open(path, "wb") as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(r["sample_rate"])
            wf.writeframes(r["audio"].tobytes())
        return True

    def health_check(self) -> bool:
        return self._synth is not None

    def unload(self):
        self._synth = None
