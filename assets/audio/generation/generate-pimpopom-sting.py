#!/usr/bin/env python3
"""Generate the original Pim-Po-Pom formant-synth launch sting.

The cue is synthesized entirely from deterministic oscillators and seeded noise.
It uses no voice recording, model, or third-party sample.
"""

from __future__ import annotations

import math
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 48_000
ROOT = Path(__file__).resolve().parents[3]
MASTER_PATH = ROOT / "assets/audio/masters/pimpopom-launch-sting-24bit.wav"
RUNTIME_PATH = ROOT / "App/Resources/Audio/audio-pimpopom-sting.wav"
RNG = np.random.default_rng(0x50494D504F504F4D)


def smooth_envelope(length: int, attack_seconds: float, release_seconds: float) -> np.ndarray:
    envelope = np.ones(length, dtype=np.float64)
    attack = min(length, int(attack_seconds * SAMPLE_RATE))
    release = min(length, int(release_seconds * SAMPLE_RATE))
    if attack:
        envelope[:attack] = np.sin(np.linspace(0, math.pi / 2, attack)) ** 2
    if release:
        envelope[-release:] = np.cos(np.linspace(0, math.pi / 2, release)) ** 2
    return envelope


def voiced_source(
    duration: float,
    start_pitch: float,
    end_pitch: float,
    formants: tuple[tuple[float, float, float], ...],
) -> np.ndarray:
    length = int(duration * SAMPLE_RATE)
    pitch = np.linspace(start_pitch, end_pitch, length)
    phase = np.cumsum((2 * math.pi * pitch) / SAMPLE_RATE)
    mean_pitch = (start_pitch + end_pitch) / 2
    signal = np.zeros(length, dtype=np.float64)

    for harmonic in range(1, 35):
        frequency = harmonic * mean_pitch
        spectral_gain = 0.035
        for center, bandwidth, gain in formants:
            spectral_gain += gain * math.exp(-0.5 * ((frequency - center) / bandwidth) ** 2)
        signal += (spectral_gain / harmonic) * np.sin(harmonic * phase + harmonic * 0.071)

    peak = np.max(np.abs(signal))
    return signal / peak if peak else signal


def plosive(length: int) -> np.ndarray:
    burst_length = min(length, int(0.018 * SAMPLE_RATE))
    burst = RNG.normal(0, 1, burst_length)
    burst = np.concatenate(([burst[0]], np.diff(burst)))
    burst *= np.sin(np.linspace(0, math.pi, burst_length)) ** 2
    output = np.zeros(length, dtype=np.float64)
    output[:burst_length] = burst * 0.22
    return output


def syllable(
    duration: float,
    start_pitch: float,
    end_pitch: float,
    vowel: tuple[tuple[float, float, float], ...],
    nasal_tail: bool,
) -> np.ndarray:
    length = int(duration * SAMPLE_RATE)
    onset = int(0.026 * SAMPLE_RATE)
    voice = voiced_source(duration - onset / SAMPLE_RATE, start_pitch, end_pitch, vowel)
    voiced_length = len(voice)

    if nasal_tail:
        tail_length = min(voiced_length, int(0.085 * SAMPLE_RATE))
        nasal = voiced_source(
            tail_length / SAMPLE_RATE,
            end_pitch,
            end_pitch * 0.98,
            ((250, 90, 1.0), (1_000, 180, 0.42), (2_100, 260, 0.10)),
        )
        blend = np.linspace(0, 1, tail_length) ** 1.5
        voice[-tail_length:] = voice[-tail_length:] * (1 - blend) + nasal * blend

    voice *= smooth_envelope(voiced_length, 0.022, 0.060)
    output = plosive(length)
    output[onset : onset + voiced_length] += voice * 0.72
    return output


def generate() -> np.ndarray:
    short_i = ((410, 120, 0.90), (1_900, 230, 0.62), (2_600, 300, 0.18))
    round_o = ((460, 130, 0.95), (920, 190, 0.70), (2_450, 330, 0.12))
    parts = [
        np.zeros(int(0.035 * SAMPLE_RATE)),
        syllable(0.285, 158, 174, short_i, nasal_tail=True),
        np.zeros(int(0.055 * SAMPLE_RATE)),
        syllable(0.275, 205, 224, round_o, nasal_tail=False),
        np.zeros(int(0.055 * SAMPLE_RATE)),
        syllable(0.315, 258, 286, round_o, nasal_tail=True),
        np.zeros(int(0.050 * SAMPLE_RATE)),
    ]
    signal = np.concatenate(parts)
    signal -= np.mean(signal)
    signal *= 0.88 / np.max(np.abs(signal))
    return signal


def write_pcm16(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(np.clip(signal, -1, 1) * 32_767).astype("<i2")
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm.tobytes())


def write_pcm24(path: Path, signal: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(np.clip(signal, -1, 1) * 8_388_607).astype(np.int32)
    unsigned = np.where(pcm < 0, pcm + (1 << 24), pcm).astype(np.uint32)
    packed = np.empty((len(unsigned), 3), dtype=np.uint8)
    packed[:, 0] = unsigned & 0xFF
    packed[:, 1] = (unsigned >> 8) & 0xFF
    packed[:, 2] = (unsigned >> 16) & 0xFF
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(3)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(packed.tobytes())


if __name__ == "__main__":
    samples = generate()
    write_pcm24(MASTER_PATH, samples)
    write_pcm16(RUNTIME_PATH, samples)
    print(f"Generated {len(samples) / SAMPLE_RATE:.3f}s Pim-Po-Pom launch sting")
