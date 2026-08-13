#!/usr/bin/env python3
"""Generate the original Mudds Shipyards combat-audio v1 one-shot library.

The synthesis is deliberately offline: the checked-in PCM WAV files are the
runtime-ready authored assets, while this fixed-seed standard-library script is
their reproducible editable source.  No recorded, sampled, or third-party audio
is used.
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
from typing import Callable, Iterable


SAMPLE_RATE = 48_000
CHANNELS = 1
SAMPLE_WIDTH_BYTES = 2
SCHEMA_VERSION = 1
ASSET_ID = "mudds.audio.combat.one_shots.v1"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "combat"
MANIFEST_FILENAME = "combat_audio_v1_asset_manifest.json"


@dataclass(frozen=True)
class CueSpec:
    filename: str
    role: str
    duration_seconds: float
    peak_dbfs: float
    seed: int
    synthesizer: Callable[[int, float, "Noise"], float]


class Noise:
    """Small explicitly specified xorshift32 source for cross-run stability."""

    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF
        if self.state == 0:
            self.state = 0xA341316C

    def uniform_signed(self) -> float:
        value = self.state
        value ^= (value << 13) & 0xFFFFFFFF
        value ^= value >> 17
        value ^= (value << 5) & 0xFFFFFFFF
        self.state = value & 0xFFFFFFFF
        return (float(self.state) / 2147483647.5) - 1.0


def clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    normalized = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return normalized * normalized * (3.0 - 2.0 * normalized)


def attack_release(time: float, duration: float, attack: float, release: float) -> float:
    attack_gain = smoothstep(0.0, max(attack, 1.0 / SAMPLE_RATE), time)
    release_gain = smoothstep(0.0, max(release, 1.0 / SAMPLE_RATE), duration - time)
    return attack_gain * release_gain


def chirp_phase(time: float, start_hz: float, end_hz: float, duration: float) -> float:
    slope = (end_hz - start_hz) / duration
    return math.tau * (start_hz * time + 0.5 * slope * time * time)


def synth_player_pulse(index: int, time: float, noise: Noise) -> float:
    duration = 0.36
    progress = time / duration
    envelope = attack_release(time, duration, 0.0025, 0.045) * math.exp(-4.6 * progress)
    phase = chirp_phase(time, 1_460.0, 245.0, duration)
    coherent = math.sin(phase) * 0.76
    coherent += math.sin(phase * 1.997 + 0.42) * 0.23
    coherent += math.sin(math.tau * 86.0 * time) * math.exp(-14.0 * progress) * 0.36
    transient = noise.uniform_signed() * math.exp(-52.0 * progress) * 0.22
    return math.tanh((coherent + transient) * envelope * 1.32)


def synth_defender_pulse(index: int, time: float, noise: Noise) -> float:
    duration = 0.42
    progress = time / duration
    envelope = attack_release(time, duration, 0.004, 0.06) * math.exp(-3.65 * progress)
    phase = chirp_phase(time, 835.0, 118.0, duration)
    warble = 0.12 * math.sin(math.tau * 31.0 * time)
    coherent = math.sin(phase + warble) * 0.69
    coherent += math.sin(phase * 0.503 + 1.17) * 0.31
    coherent += math.sin(phase * 2.007) * 0.13
    transient = noise.uniform_signed() * math.exp(-38.0 * progress) * 0.18
    return math.tanh((coherent + transient) * envelope * 1.28)


def make_impact_synth(
    duration: float,
    fundamental_hz: float,
    noise_amount: float,
    decay_rate: float,
) -> Callable[[int, float, Noise], float]:
    low_noise = 0.0
    mid_noise = 0.0

    def synth(index: int, time: float, noise: Noise) -> float:
        nonlocal low_noise, mid_noise
        if index == 0:
            low_noise = 0.0
            mid_noise = 0.0
        progress = time / duration
        white = noise.uniform_signed()
        low_noise += (white - low_noise) * 0.035
        mid_noise += (white - mid_noise) * 0.19
        envelope = attack_release(time, duration, 0.0015, min(0.09, duration * 0.18))
        decay = math.exp(-decay_rate * progress)
        shell = math.sin(math.tau * fundamental_hz * time + 0.2) * 0.62
        shell += math.sin(math.tau * fundamental_hz * 1.47 * time + 1.1) * 0.27
        shell += math.sin(math.tau * fundamental_hz * 2.19 * time + 0.58) * 0.13
        crack = (mid_noise * 0.72 + white * 0.28) * noise_amount
        body = low_noise * (noise_amount * 1.35)
        return math.tanh((shell + crack + body) * envelope * decay * 1.42)

    return synth


def make_explosion_synth() -> Callable[[int, float, Noise], float]:
    low_noise = 0.0
    mid_noise = 0.0
    high_noise = 0.0

    def synth(index: int, time: float, noise: Noise) -> float:
        nonlocal low_noise, mid_noise, high_noise
        if index == 0:
            low_noise = 0.0
            mid_noise = 0.0
            high_noise = 0.0
        duration = 2.8
        progress = time / duration
        white = noise.uniform_signed()
        low_noise += (white - low_noise) * 0.012
        mid_noise += (white - mid_noise) * 0.075
        high_noise += (white - high_noise) * 0.34
        initial = attack_release(time, duration, 0.0015, 0.22)
        blast = (low_noise * 1.8 + mid_noise * 0.72 + high_noise * 0.18)
        blast *= math.exp(-5.2 * progress)
        rumble = math.sin(math.tau * (47.0 - 14.0 * progress) * time + 0.3) * 0.58
        rumble += math.sin(math.tau * 71.0 * time + 1.4) * 0.27
        rumble *= math.exp(-3.35 * progress)
        # Three delayed structural bursts keep the long tail alive without a
        # copied sample or a reverb plug-in.
        debris = 0.0
        for onset, frequency, strength in (
            (0.19, 128.0, 0.32),
            (0.47, 83.0, 0.25),
            (0.91, 54.0, 0.19),
        ):
            local_time = time - onset
            if local_time >= 0.0:
                debris += math.sin(math.tau * frequency * local_time) * math.exp(-5.8 * local_time) * strength
        tail = low_noise * 0.52 * math.exp(-1.75 * progress)
        tail += math.sin(math.tau * 31.0 * time) * 0.11 * math.exp(-1.42 * progress)
        return math.tanh((blast + rumble + debris + tail) * initial * 1.7)

    return synth


def synth_dry_fire_click(index: int, time: float, noise: Noise) -> float:
    duration = 0.12
    progress = time / duration
    strike = math.exp(-74.0 * progress)
    return attack_release(time, duration, 0.0008, 0.012) * (
        math.sin(math.tau * 2_420.0 * time) * strike * 0.58
        + math.sin(math.tau * 1_190.0 * time + 0.7) * strike * 0.29
        + noise.uniform_signed() * strike * 0.13
        + math.sin(math.tau * 235.0 * time) * math.exp(-24.0 * progress) * 0.17
    )


CUE_SPECS = (
    CueSpec(
        "player_pulse_fire_v1.wav",
        "player pulse-fire transient; bright descending energy report",
        0.36,
        -3.0,
        0x4D554401,
        synth_player_pulse,
    ),
    CueSpec(
        "defender_pulse_fire_v1.wav",
        "defender pulse-fire transient; lower hostile tonal signature",
        0.42,
        -3.5,
        0x4D554402,
        synth_defender_pulse,
    ),
    CueSpec(
        "hull_impact_light_v1.wav",
        "light hull impact; short high-metal strike",
        0.38,
        -4.5,
        0x4D554411,
        make_impact_synth(0.38, 184.0, 0.31, 7.8),
    ),
    CueSpec(
        "hull_impact_medium_v1.wav",
        "medium hull impact; broader structural thud",
        0.58,
        -3.8,
        0x4D554412,
        make_impact_synth(0.58, 119.0, 0.43, 5.65),
    ),
    CueSpec(
        "hull_impact_heavy_v1.wav",
        "heavy hull impact; low resonant stress hit",
        0.88,
        -3.0,
        0x4D554413,
        make_impact_synth(0.88, 72.0, 0.56, 4.15),
    ),
    CueSpec(
        "ship_explosion_v1.wav",
        "ship explosion with a 2.8-second debris-and-rumble tail",
        2.8,
        -2.5,
        0x4D554421,
        make_explosion_synth(),
    ),
    CueSpec(
        "dry_fire_click_v1.wav",
        "safe dry-fire mechanical click; deliberately restrained peak",
        0.12,
        -9.0,
        0x4D554431,
        synth_dry_fire_click,
    ),
)


def quantize(samples: Iterable[float], peak_dbfs: float) -> list[int]:
    source = list(samples)
    maximum = max(abs(sample) for sample in source)
    if maximum <= 0.0:
        raise ValueError("cannot normalize a silent cue")
    target = (10.0 ** (peak_dbfs / 20.0)) * 32767.0
    scale = target / maximum
    result = [int(round(clamp(sample * scale, -32767.0, 32767.0))) for sample in source]
    # Boundary zeroes prevent player start/stop discontinuities.  They occur
    # before manifest analysis and are therefore part of the frozen asset.
    result[0] = 0
    result[-1] = 0
    return result


def render_cue(spec: CueSpec) -> list[int]:
    frame_count = round(spec.duration_seconds * SAMPLE_RATE)
    noise = Noise(spec.seed)
    samples = [spec.synthesizer(index, index / SAMPLE_RATE, noise) for index in range(frame_count)]
    return quantize(samples, spec.peak_dbfs)


def write_wave(path: Path, samples: list[int]) -> None:
    packed = struct.pack("<%dh" % len(samples), *samples)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(CHANNELS)
        output.setsampwidth(SAMPLE_WIDTH_BYTES)
        output.setframerate(SAMPLE_RATE)
        output.setcomptype("NONE", "not compressed")
        output.writeframes(packed)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def analyse(samples: list[int]) -> dict[str, float | int]:
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(float(sample * sample) for sample in samples) / len(samples))
    mean = sum(samples) / len(samples)
    return {
        "frame_count": len(samples),
        "duration_seconds": round(len(samples) / SAMPLE_RATE, 6),
        "peak_abs_pcm16": peak,
        "peak_dbfs": round(20.0 * math.log10(peak / 32767.0), 4),
        "rms_dbfs": round(20.0 * math.log10(rms / 32767.0), 4),
        "dc_offset_pcm16": round(mean, 4),
        "first_sample_pcm16": samples[0],
        "last_sample_pcm16": samples[-1],
    }


def generate(output_directory: Path) -> dict[str, object]:
    output_directory.mkdir(parents=True, exist_ok=True)
    cue_records: list[dict[str, object]] = []
    for spec in CUE_SPECS:
        samples = render_cue(spec)
        output_path = output_directory / spec.filename
        write_wave(output_path, samples)
        cue_records.append(
            {
                "filename": spec.filename,
                "role": spec.role,
                "seed_u32": spec.seed,
                "target_peak_dbfs": spec.peak_dbfs,
                "sha256": sha256(output_path),
                **analyse(samples),
            }
        )

    manifest: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "asset_id": ASSET_ID,
        "authorship": "original_fixed_seed_offline_procedural_synthesis",
        "license": "project_original",
        "recorded_or_sampled_source_material": False,
        "runtime_generation": False,
        "runtime_intent": "non-looping positional one-shot combat cues",
        "generator": "tools/audio/generate_combat_audio_v1.py",
        "generator_sha256": sha256(Path(__file__).resolve()),
        "format_contract": {
            "container": "RIFF/WAVE",
            "encoding": "linear PCM signed 16-bit little-endian",
            "sample_rate_hz": SAMPLE_RATE,
            "channels": CHANNELS,
            "channel_layout": "mono",
            "bit_depth": SAMPLE_WIDTH_BYTES * 8,
            "looped": False,
        },
        "mix_contract": {
            "maximum_allowed_peak_dbfs": -2.0,
            "dry_fire_maximum_peak_dbfs": -8.0,
            "normalization": "per-cue integer sample peak",
            "runtime_gain_note": "assets retain headroom; final loudness belongs to the positional mix",
        },
        "cue_count": len(cue_records),
        "cues": cue_records,
    }
    manifest_path = output_directory / MANIFEST_FILENAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
        help="destination for WAV files and the deterministic manifest",
    )
    arguments = parser.parse_args()
    manifest = generate(arguments.output_dir.resolve())
    for cue in manifest["cues"]:
        print(
            f"{cue['filename']}: {cue['duration_seconds']:.3f}s "
            f"{cue['peak_dbfs']:.2f} dBFS {cue['sha256']}"
        )
    print(f"wrote {arguments.output_dir.resolve() / MANIFEST_FILENAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
