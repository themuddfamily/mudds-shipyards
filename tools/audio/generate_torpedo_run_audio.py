#!/usr/bin/env python3
"""Generate the original Mudds Shipyards Torpedo Run cue bank.

Fixed-seed offline synthesis with the standard library only: no wall-clock, no
unseeded randomness, no recorded, sampled or third-party material. The checked-in
PCM WAVs under ``assets/audio/combat/torpedo_run/`` are the runtime assets and
this script is their reproducible editable source.

Cues:
  torpedo_launch_v1         rising ignition hiss over a tube kick (one-shot)
  torpedo_seeker_lock_v1    short lime seeker pip, pitched per lock step (one-shot)
  torpedo_flight_loop_v1    motor drone, integer cycles per loop (seamless loop)
  torpedo_intercept_v1      bright crackling pop of a shot-down torpedo (one-shot)
  torpedo_detonation_v1     heavy low warhead boom (one-shot)
  torpedo_board_armed_v1    two rising board tones: contract armed (one-shot)
  torpedo_board_cleared_v1  three rising board tones: contract cleared (one-shot)
  torpedo_board_failed_v1   two falling board tones: contract failed (one-shot)

Usage: python3 tools/audio/generate_torpedo_run_audio.py [--output-directory DIR]
"""

from __future__ import annotations

import argparse
import math
import struct
import wave
from pathlib import Path
from typing import Callable

SAMPLE_RATE = 48_000
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "combat" / "torpedo_run"
TAU = math.tau


class Noise:
    """Explicit xorshift32 so output is stable across Python builds."""

    def __init__(self, seed: int) -> None:
        self.state = (seed & 0xFFFFFFFF) or 0xA341316C

    def next(self) -> float:
        value = self.state
        value ^= (value << 13) & 0xFFFFFFFF
        value ^= value >> 17
        value ^= (value << 5) & 0xFFFFFFFF
        self.state = value & 0xFFFFFFFF
        return (float(self.state) / 2147483647.5) - 1.0


class OnePole:
    def __init__(self, cutoff_hz: float) -> None:
        self.set(cutoff_hz)
        self.value = 0.0

    def set(self, cutoff_hz: float) -> None:
        self.alpha = 1.0 - math.exp(-TAU * max(cutoff_hz, 1.0) / SAMPLE_RATE)

    def __call__(self, sample: float) -> float:
        self.value += self.alpha * (sample - self.value)
        return self.value


def envelope(t: float, attack: float, decay: float) -> float:
    if t < attack:
        return t / attack if attack > 0.0 else 1.0
    return math.exp(-(t - attack) / decay)


def tail_fade(t: float, duration: float, fade: float = 0.02) -> float:
    return min(1.0, max(0.0, (duration - t) / fade))


def render(duration: float, fn: Callable[[float, int], float]) -> list[float]:
    frames = int(round(duration * SAMPLE_RATE))
    return [fn(i / SAMPLE_RATE, i) for i in range(frames)]


def launch() -> list[float]:
    noise = Noise(0x7041_0001)
    hiss = OnePole(900.0)
    body = OnePole(180.0)
    duration = 0.95

    def sample(t: float, _i: int) -> float:
        hiss.set(900.0 + 5200.0 * min(1.0, t / 0.55))
        raw = noise.next()
        ignition = hiss(raw) * envelope(t, 0.06, 0.38) * 0.9
        kick = math.sin(TAU * (70.0 - 30.0 * min(t / 0.18, 1.0)) * t) * envelope(t, 0.004, 0.09)
        rumble = body(raw) * envelope(t, 0.02, 0.25) * 1.6
        return (ignition + kick * 0.8 + rumble) * tail_fade(t, duration)

    return render(duration, sample)


def seeker_lock() -> list[float]:
    duration = 0.14

    def sample(t: float, _i: int) -> float:
        tone = math.sin(TAU * 1760.0 * t) + 0.35 * math.sin(TAU * 3520.0 * t)
        return tone * envelope(t, 0.003, 0.045) * tail_fade(t, duration, 0.01)

    return render(duration, sample)


def flight_loop() -> list[float]:
    # One second: every partial and modulation rate is an integer number of
    # cycles per loop, and the noise bed is crossfaded across the join.
    duration = 1.0
    frames = SAMPLE_RATE
    noise = Noise(0x7041_0003)
    filt = OnePole(1400.0)
    bed = [filt(noise.next()) for _ in range(frames)]
    fade = SAMPLE_RATE // 10
    # Render one extra fade length, then wrap that overhang into the head so the
    # last sample flows straight into the first.
    bed += [filt(noise.next()) for _ in range(fade)]
    looped = bed[:frames]
    for i in range(fade):
        w = i / fade
        looped[i] = bed[i] * w + bed[frames + i] * (1.0 - w)

    def sample(t: float, i: int) -> float:
        wobble = 1.0 + 0.18 * math.sin(TAU * 6.0 * t)
        motor = (
            math.sin(TAU * 110.0 * t)
            + 0.5 * math.sin(TAU * 220.0 * t)
            + 0.22 * math.sin(TAU * 330.0 * t)
        ) * wobble
        return motor * 0.55 + looped[i] * 1.4

    return render(duration, sample)


def intercept() -> list[float]:
    noise = Noise(0x7041_0004)
    bright = OnePole(6500.0)
    duration = 0.6

    def sample(t: float, _i: int) -> float:
        raw = noise.next()
        crackle = bright(raw) * envelope(t, 0.002, 0.07)
        sparkle = (raw if (int(t * 900.0) % 7) == 0 else 0.0) * envelope(t, 0.0, 0.2) * 0.5
        ring = math.sin(TAU * (880.0 - 300.0 * t) * t) * envelope(t, 0.002, 0.16) * 0.5
        return (crackle + sparkle + ring) * tail_fade(t, duration)

    return render(duration, sample)


def detonation() -> list[float]:
    noise = Noise(0x7041_0005)
    low = OnePole(260.0)
    mid = OnePole(1800.0)
    duration = 1.5

    def sample(t: float, _i: int) -> float:
        raw = noise.next()
        boom = math.sin(TAU * (58.0 - 26.0 * min(t / 0.4, 1.0)) * t) * envelope(t, 0.004, 0.32)
        body = low(raw) * envelope(t, 0.006, 0.5) * 2.4
        crack = mid(raw) * envelope(t, 0.001, 0.05)
        return (boom + body + crack) * tail_fade(t, duration, 0.08)

    return render(duration, sample)


def board_tones(notes: list[float], step: float, duration: float) -> list[float]:
    def sample(t: float, _i: int) -> float:
        total = 0.0
        for index, frequency in enumerate(notes):
            start = index * step
            if t >= start:
                local = t - start
                total += (
                    math.sin(TAU * frequency * local)
                    + 0.25 * math.sin(TAU * frequency * 2.0 * local)
                ) * envelope(local, 0.006, 0.22)
        return total * tail_fade(t, duration, 0.05)

    return render(duration, sample)


# D minor at A4 = 440 Hz, matching the music beds.
CUES: dict[str, Callable[[], list[float]]] = {
    "torpedo_launch_v1.wav": launch,
    "torpedo_seeker_lock_v1.wav": seeker_lock,
    "torpedo_flight_loop_v1.wav": flight_loop,
    "torpedo_intercept_v1.wav": intercept,
    "torpedo_detonation_v1.wav": detonation,
    "torpedo_board_armed_v1.wav": lambda: board_tones([587.33, 880.0], 0.11, 0.55),
    "torpedo_board_cleared_v1.wav": lambda: board_tones([587.33, 739.99, 880.0], 0.12, 0.8),
    "torpedo_board_failed_v1.wav": lambda: board_tones([587.33, 440.0], 0.16, 0.7),
}
PEAK_DBFS = -3.0


def write_wave(path: Path, samples: list[float]) -> None:
    peak = max((abs(s) for s in samples), default=0.0) or 1.0
    gain = (10.0 ** (PEAK_DBFS / 20.0)) / peak
    pcm = bytearray()
    for s in samples:
        pcm += struct.pack("<h", int(round(max(-1.0, min(1.0, s * gain)) * 32767.0)))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(bytes(pcm))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-directory", type=Path, default=DEFAULT_OUTPUT_DIRECTORY)
    args = parser.parse_args()
    args.output_directory.mkdir(parents=True, exist_ok=True)
    for filename, synthesizer in CUES.items():
        write_wave(args.output_directory / filename, synthesizer())
        print(filename)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
