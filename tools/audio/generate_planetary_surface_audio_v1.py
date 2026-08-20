#!/usr/bin/env python3
"""Generate the original temperate planetary surface ambience loops v1.

The checked-in WAV files are deterministic offline renders made only from
periodic oscillator banks. Every oscillator completes an integer number of
cycles per eight-second loop, so the boundary is continuous by construction.
No recording, sample library, or historical Keth material is used.

This script authors sound assets; it is not used by the game at runtime.
Automated measurements can prove format, identity, headroom, and a bounded loop
join, but cannot prove that the result sounds good. Native listening remains a
separate acceptance step.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from dataclasses import dataclass
from pathlib import Path


SAMPLE_RATE = 24_000
CHANNELS = 1
SAMPLE_WIDTH_BYTES = 2
LOOP_SECONDS = 8.0
FRAME_COUNT = int(SAMPLE_RATE * LOOP_SECONDS)
SCHEMA_VERSION = 1
ASSET_ID = "mudds.audio.planetary.temperate_surface_loops.v1"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "planetary"
MANIFEST_FILENAME = "temperate_surface_audio_v1_asset_manifest.json"


class XorShift32:
    """Small explicitly specified PRNG used only to choose oscillator recipes."""

    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF or 0x9E3779B9

    def next_u32(self) -> int:
        value = self.state
        value ^= (value << 13) & 0xFFFFFFFF
        value ^= value >> 17
        value ^= (value << 5) & 0xFFFFFFFF
        self.state = value & 0xFFFFFFFF
        return self.state

    def unit(self) -> float:
        return self.next_u32() / 4294967296.0


@dataclass(frozen=True)
class LoopSpec:
    profile_id: str
    filename: str
    role: str
    seed: int
    partial_count: int
    minimum_cycles: int
    maximum_cycles: int
    spectral_exponent: float
    target_peak_dbfs: float
    low_tone_cycles: tuple[int, ...]
    low_tone_gain: float


LOOPS = (
    LoopSpec(
        profile_id="temperate_exterior",
        filename="temperate_exterior_wind_air_v1.wav",
        role="non-positional exterior wind and moving-air bed",
        seed=0x4B455401,
        partial_count=176,
        minimum_cycles=5,
        maximum_cycles=5200,
        spectral_exponent=0.42,
        target_peak_dbfs=-13.0,
        low_tone_cycles=(7, 11, 19),
        low_tone_gain=0.035,
    ),
    LoopSpec(
        profile_id="temperate_interior",
        filename="temperate_interior_cabin_air_v1.wav",
        role="attenuated low-passed interior and cabin air bed",
        seed=0x4B455402,
        partial_count=112,
        minimum_cycles=3,
        maximum_cycles=1100,
        spectral_exponent=0.78,
        target_peak_dbfs=-18.0,
        low_tone_cycles=(5, 9, 16, 29),
        low_tone_gain=0.065,
    ),
)


def _render(spec: LoopSpec) -> list[float]:
    random = XorShift32(spec.seed)
    partials: list[tuple[int, float, float]] = []
    cycle_span = spec.maximum_cycles - spec.minimum_cycles + 1
    for _index in range(spec.partial_count):
        cycles = spec.minimum_cycles + (random.next_u32() % cycle_span)
        phase = math.tau * random.unit()
        normalized_frequency = max(1.0, float(cycles) / float(spec.minimum_cycles))
        amplitude = (0.40 + 0.60 * random.unit()) / math.pow(
            normalized_frequency, spec.spectral_exponent
        )
        partials.append((cycles, phase, amplitude))

    tone_phases = [math.tau * random.unit() for _cycles in spec.low_tone_cycles]
    rendered: list[float] = []
    for frame in range(FRAME_COUNT):
        phase_unit = math.tau * float(frame) / float(FRAME_COUNT)
        value = 0.0
        for cycles, phase, amplitude in partials:
            value += math.sin(phase_unit * cycles + phase) * amplitude
        value /= math.sqrt(float(spec.partial_count))
        for tone_index, cycles in enumerate(spec.low_tone_cycles):
            value += math.sin(phase_unit * cycles + tone_phases[tone_index]) * (
                spec.low_tone_gain / float(tone_index + 1)
            )
        # A periodic two-rate gust envelope gives the exterior loop motion and
        # makes the interior loop breathe without introducing a boundary seam.
        gust = 0.76 + 0.16 * math.sin(phase_unit * 2.0 + 0.4) \
            + 0.08 * math.sin(phase_unit * 5.0 + 1.2)
        rendered.append(math.tanh(value * gust * 0.72))
    return rendered


def _normalise(samples: list[float], target_dbfs: float) -> list[int]:
    peak = max(abs(value) for value in samples)
    target = math.pow(10.0, target_dbfs / 20.0)
    scale = target / peak
    return [
        max(-32768, min(32767, round(value * scale * 32767.0)))
        for value in samples
    ]


def _pcm_bytes(samples: list[int]) -> bytes:
    return b"".join(struct.pack("<h", sample) for sample in samples)


def _write_wave(path: Path, pcm: bytes) -> None:
    with wave.open(str(path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(SAMPLE_WIDTH_BYTES)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def _measurement(spec: LoopSpec, path: Path, samples: list[int], pcm: bytes) -> dict:
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(float(sample) * float(sample) for sample in samples) / len(samples))
    steps = [abs(samples[index] - samples[index - 1]) for index in range(1, len(samples))]
    join_step = abs(samples[0] - samples[-1])
    return {
        "profile_id": spec.profile_id,
        "filename": spec.filename,
        "role": spec.role,
        "seed_u32": spec.seed,
        "duration_seconds": LOOP_SECONDS,
        "frame_count": len(samples),
        "target_peak_dbfs": spec.target_peak_dbfs,
        "peak_abs_pcm16": peak,
        "peak_dbfs": round(20.0 * math.log10(peak / 32767.0), 4),
        "rms_dbfs": round(20.0 * math.log10(rms / 32767.0), 4),
        "first_sample_pcm16": samples[0],
        "last_sample_pcm16": samples[-1],
        "loop_join_step_pcm16": join_step,
        "maximum_internal_step_pcm16": max(steps),
        "raw_file_sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "pcm_payload_sha256": hashlib.sha256(pcm).hexdigest(),
        "partial_count": spec.partial_count,
        "minimum_cycles_per_loop": spec.minimum_cycles,
        "maximum_cycles_per_loop": spec.maximum_cycles,
    }


def generate(output_directory: Path) -> None:
    output_directory.mkdir(parents=True, exist_ok=True)
    records = []
    for spec in LOOPS:
        samples = _normalise(_render(spec), spec.target_peak_dbfs)
        pcm = _pcm_bytes(samples)
        path = output_directory / spec.filename
        _write_wave(path, pcm)
        records.append(_measurement(spec, path, samples, pcm))

    script_path = Path(__file__).resolve()
    manifest = {
        "schema_version": SCHEMA_VERSION,
        "asset_id": ASSET_ID,
        "evidence_status": "modern_interpretation",
        "authorship": "project_original_fixed_seed_offline_periodic_synthesis",
        "recorded_or_sampled_source_material": False,
        "historically_supported": False,
        "runtime_generation": False,
        "human_listening_pass": "outstanding",
        "generator": "tools/audio/generate_planetary_surface_audio_v1.py",
        "generator_sha256": hashlib.sha256(script_path.read_bytes()).hexdigest(),
        "runtime_intent": "non-positional temperate planetary exterior and interior/cabin ambience",
        "format_contract": {
            "container": "RIFF/WAVE",
            "encoding": "linear PCM signed 16-bit little-endian",
            "sample_rate_hz": SAMPLE_RATE,
            "channels": CHANNELS,
            "channel_layout": "mono",
            "bit_depth": SAMPLE_WIDTH_BYTES * 8,
            "looped": True,
            "loop_mode": "forward",
            "loop_begin_frame": 0,
            # Godot's AudioStreamWAV LOOP_FORWARD end is an inclusive index.
            "loop_end_frame": FRAME_COUNT - 1,
        },
        "synthesis_contract": {
            "loop_seconds": LOOP_SECONDS,
            "periodic_by_construction": True,
            "integer_cycles_per_loop": True,
            "asset_count": len(LOOPS),
        },
        "mix_contract": {
            "runtime_bus": "Ambience",
            "runtime_policy_gain_is_additional": True,
            "interior_asset_is_lower_and_spectrally_restrained": True,
            "native_listening_required": True,
        },
        "content_note": (
            "Both beds are project-original modern sound design. No source authenticates "
            "planetary ambience for the original Keth Shipyards, and automated checks do "
            "not establish audibility, comfort, or mix quality."
        ),
        "loops": records,
    }
    manifest_path = output_directory / MANIFEST_FILENAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-directory", type=Path, default=DEFAULT_OUTPUT_DIRECTORY)
    arguments = parser.parse_args()
    generate(arguments.output_directory.resolve())


if __name__ == "__main__":
    main()
