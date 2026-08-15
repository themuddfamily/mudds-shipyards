#!/usr/bin/env python3
"""Generate the original Mudds Shipyards station-rest music/ambient bed v1.

Three seamless mono loops make up one slow non-combat bed for the station at
rest.  As with the combat one-shot library, the synthesis is deliberately
offline: the checked-in PCM WAV files are the runtime-ready authored assets and
this fixed-seed standard-library script is their reproducible editable source.
No recorded, sampled, or third-party audio is used, and nothing here claims to
reconstruct or recover any historical Keth Shipyards music.

Musical intent (modern interpretation, not recovered material):

* One static modal centre in D natural minor at A4 = 440 Hz: the bed never
  resolves and never states a cadence, so it has no arrival point to compete
  with whatever gameplay is doing. Yielding to combat is the runtime bed's job,
  not the mode's.
* ``drone``      - 16 s sustained root/fifth deck drone.
* ``harmonics``  - 12 s Dm9 swell layer whose five voices each breathe at their
                   own rate (1 to 5 swells per loop).
* ``motif``      - 20 s sparse descending bell motif with silence at both ends.
* The three loop lengths are pairwise chosen so the exact combination of all
  three layers only repeats every 240 s (4 minutes).

Every partial and every modulation rate in the two sustaining layers is snapped
to an integer multiple of its own loop fundamental, so each file loops without a
seam by construction rather than by a crossfade.  The motif layer instead starts
and ends in exact silence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Sequence


SAMPLE_RATE = 22_050
CHANNELS = 1
SAMPLE_WIDTH_BYTES = 2
SCHEMA_VERSION = 1
ASSET_ID = "mudds.audio.music.station_rest_bed.v1"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "music"
MANIFEST_FILENAME = "station_music_v1_asset_manifest.json"
COMBINED_CYCLE_SECONDS = 240.0

# Equal temperament, A4 = 440 Hz. Spelled out so the intent is readable.
D1 = 36.7081
D2 = 73.4162
A2 = 110.0000
D3 = 146.8324
F3 = 174.6141
A3 = 220.0000
C4 = 261.6256
D4 = 293.6648
E4 = 329.6276


class Phases:
    """Deterministic per-partial starting phases from one fixed seed.

    A tiny explicitly specified xorshift32 keeps the phase set stable across
    Python builds. It only chooses constant offsets: no sample of the output is
    a random value, so every rendered layer stays perfectly periodic.
    """

    def __init__(self, seed: int) -> None:
        self.state = seed & 0xFFFFFFFF
        if self.state == 0:
            self.state = 0x9E3779B9

    def next_phase(self) -> float:
        value = self.state
        value ^= (value << 13) & 0xFFFFFFFF
        value ^= value >> 17
        value ^= (value << 5) & 0xFFFFFFFF
        self.state = value & 0xFFFFFFFF
        return math.tau * (float(self.state) / 4294967296.0)


def clamp(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))


def smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    normalized = clamp((value - edge0) / (edge1 - edge0), 0.0, 1.0)
    return normalized * normalized * (3.0 - 2.0 * normalized)


def snap_to_loop(frequency_hz: float, loop_seconds: float) -> float:
    """Round a frequency to the nearest whole number of cycles per loop.

    This is what makes the sustaining layers seamless: after ``loop_seconds``
    every snapped oscillator is back at exactly its starting phase.
    """
    cycles = max(1, round(frequency_hz * loop_seconds))
    return cycles / loop_seconds


@dataclass(frozen=True)
class Partial:
    frequency_hz: float
    amplitude: float
    lfo_cycles_per_loop: int
    lfo_depth: float
    overtone_amplitudes: Sequence[float] = field(default_factory=tuple)


@dataclass(frozen=True)
class BellNote:
    onset_seconds: float
    frequency_hz: float
    amplitude: float
    decay_per_second: float


@dataclass(frozen=True)
class LayerSpec:
    layer_id: str
    filename: str
    role: str
    musical_note: str
    loop_seconds: float
    peak_dbfs: float
    seed: int
    renderer: Callable[["LayerSpec"], list[float]]


def render_sustained(spec: LayerSpec, partials: Sequence[Partial]) -> list[float]:
    """Sum snapped partials, each breathing under its own snapped LFO."""
    frame_count = round(spec.loop_seconds * SAMPLE_RATE)
    phases = Phases(spec.seed)
    voices = []
    for partial in partials:
        base_hz = snap_to_loop(partial.frequency_hz, spec.loop_seconds)
        lfo_hz = partial.lfo_cycles_per_loop / spec.loop_seconds
        overtones = [
            (
                snap_to_loop(partial.frequency_hz * (index + 2), spec.loop_seconds),
                amplitude,
                phases.next_phase(),
            )
            for index, amplitude in enumerate(partial.overtone_amplitudes)
        ]
        voices.append(
            (
                base_hz,
                partial.amplitude,
                phases.next_phase(),
                lfo_hz,
                partial.lfo_depth,
                phases.next_phase(),
                overtones,
            )
        )

    samples: list[float] = []
    for index in range(frame_count):
        time = index / SAMPLE_RATE
        total = 0.0
        for base_hz, amplitude, phase, lfo_hz, depth, lfo_phase, overtones in voices:
            breath = 1.0 - depth + depth * (0.5 + 0.5 * math.sin(math.tau * lfo_hz * time + lfo_phase))
            tone = math.sin(math.tau * base_hz * time + phase)
            for overtone_hz, overtone_amplitude, overtone_phase in overtones:
                tone += math.sin(math.tau * overtone_hz * time + overtone_phase) * overtone_amplitude
            total += tone * amplitude * breath
        samples.append(math.tanh(total * 0.72))
    return samples


def render_drone(spec: LayerSpec) -> list[float]:
    partials = (
        # Root and fifth carry the layer; the faint minor third is what makes it
        # read as D minor rather than an untuned hum.
        Partial(D1, 0.50, 1, 0.22),
        Partial(D2, 0.82, 2, 0.26, (0.14, 0.05)),
        Partial(A2, 0.40, 3, 0.30, (0.10,)),
        Partial(D3, 0.21, 5, 0.34, (0.07,)),
        Partial(F3, 0.095, 7, 0.42),
        Partial(A3, 0.062, 4, 0.38),
        # A very soft upper band keeps the drone from sounding like a test tone.
        Partial(660.0, 0.011, 9, 0.55),
        Partial(880.0, 0.008, 11, 0.60),
        Partial(1108.7, 0.006, 13, 0.65),
    )
    return render_sustained(spec, partials)


def render_harmonics(spec: LayerSpec) -> list[float]:
    partials = (
        # Dm9 stacked D-F-A-C-E. Deep LFOs make the voices cross-fade past each
        # other so no single chord shape is ever held flat.
        Partial(D3, 0.50, 1, 0.55, (0.18, 0.07)),
        Partial(F3, 0.42, 2, 0.58, (0.16, 0.06)),
        Partial(A3, 0.38, 3, 0.60, (0.15, 0.05)),
        Partial(C4, 0.30, 4, 0.62, (0.13, 0.04)),
        Partial(E4, 0.22, 5, 0.66, (0.11, 0.03)),
    )
    return render_sustained(spec, partials)


def render_motif(spec: LayerSpec) -> list[float]:
    """Sparse descending bell phrase that begins and ends in silence."""
    frame_count = round(spec.loop_seconds * SAMPLE_RATE)
    phases = Phases(spec.seed)
    # A slow descent through the mode, then one low answer. Nothing resolves to
    # the tonic on a strong beat, so the phrase can repeat indefinitely.
    notes = (
        BellNote(0.40, D4, 1.00, 1.85),
        BellNote(2.90, A3, 0.86, 1.70),
        BellNote(5.85, F3, 0.80, 1.65),
        BellNote(9.10, E4, 0.58, 1.95),
        BellNote(12.35, D3, 0.90, 1.55),
        BellNote(15.70, A2, 0.62, 1.90),
    )
    # Inharmonic bell partials with faster decay higher up.
    partial_ratios = (1.0, 2.0, 2.76, 5.404)
    partial_amplitudes = (1.0, 0.40, 0.21, 0.085)
    partial_decays = (1.0, 1.6, 2.3, 3.6)
    note_phases = [[phases.next_phase() for _ in partial_ratios] for _ in notes]

    samples = [0.0] * frame_count
    for note_index, note in enumerate(notes):
        start_frame = round(note.onset_seconds * SAMPLE_RATE)
        for frame in range(start_frame, frame_count):
            local_time = (frame - start_frame) / SAMPLE_RATE
            attack = smoothstep(0.0, 0.006, local_time)
            value = 0.0
            for partial_index, ratio in enumerate(partial_ratios):
                decay = math.exp(-note.decay_per_second * partial_decays[partial_index] * local_time)
                if decay < 1.0e-5:
                    continue
                value += (
                    math.sin(
                        math.tau * note.frequency_hz * ratio * local_time
                        + note_phases[note_index][partial_index]
                    )
                    * partial_amplitudes[partial_index]
                    * decay
                )
            samples[frame] += value * note.amplitude * attack

    # Guarantee exact silence at both loop boundaries so the join is inaudible
    # without any crossfade.
    for frame in range(frame_count):
        time = frame / SAMPLE_RATE
        guard = smoothstep(0.0, 0.30, time) * smoothstep(0.0, 0.90, spec.loop_seconds - time)
        samples[frame] = math.tanh(samples[frame] * 0.62) * guard
    return samples


LAYER_SPECS = (
    LayerSpec(
        layer_id="drone",
        filename="station_bed_drone_v1.wav",
        role="sustained root/fifth deck drone; the always-present floor of the bed",
        musical_note="D natural minor drone on D1/D2 with A2 fifth and a faint F3 third",
        loop_seconds=16.0,
        peak_dbfs=-12.0,
        seed=0x4D554D31,
        renderer=render_drone,
    ),
    LayerSpec(
        layer_id="harmonics",
        filename="station_bed_harmonics_v1.wav",
        role="mid-register swell layer; breathing Dm9 colour above the drone",
        musical_note="Dm9 (D3-F3-A3-C4-E4) with five independent slow swells",
        loop_seconds=12.0,
        peak_dbfs=-15.0,
        seed=0x4D554D32,
        renderer=render_harmonics,
    ),
    LayerSpec(
        layer_id="motif",
        filename="station_bed_motif_v1.wav",
        role="sparse bell motif; the only foreground gesture, reserved for the station at rest",
        musical_note="descending D4-A3-F3-E4-D3-A2 bell phrase, silent at both loop boundaries",
        loop_seconds=20.0,
        peak_dbfs=-13.0,
        seed=0x4D554D33,
        renderer=render_motif,
    ),
)


def quantize(samples: Sequence[float], peak_dbfs: float) -> list[int]:
    maximum = max(abs(sample) for sample in samples)
    if maximum <= 0.0:
        raise ValueError("cannot normalize a silent layer")
    target = (10.0 ** (peak_dbfs / 20.0)) * 32767.0
    scale = target / maximum
    return [int(round(clamp(sample * scale, -32767.0, 32767.0))) for sample in samples]


def render_layer(spec: LayerSpec) -> list[int]:
    return quantize(spec.renderer(spec), spec.peak_dbfs)


def write_wave(path: Path, samples: Sequence[int]) -> None:
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


def analyse(samples: Sequence[int]) -> dict[str, float | int]:
    peak = max(abs(sample) for sample in samples)
    rms = math.sqrt(sum(float(sample * sample) for sample in samples) / len(samples))
    mean = sum(samples) / len(samples)
    internal_steps = [
        abs(samples[index] - samples[index - 1]) for index in range(1, len(samples))
    ]
    return {
        "frame_count": len(samples),
        "duration_seconds": round(len(samples) / SAMPLE_RATE, 6),
        "peak_abs_pcm16": peak,
        "peak_dbfs": round(20.0 * math.log10(peak / 32767.0), 4),
        "rms_dbfs": round(20.0 * math.log10(rms / 32767.0), 4),
        "dc_offset_pcm16": round(mean, 4),
        "first_sample_pcm16": samples[0],
        "last_sample_pcm16": samples[-1],
        # The wrap from the final sample back to the first must be no larger
        # than an ordinary step inside the file, or the loop would tick.
        "loop_join_step_pcm16": abs(samples[0] - samples[-1]),
        "maximum_internal_step_pcm16": max(internal_steps),
    }


def generate(output_directory: Path) -> dict[str, object]:
    output_directory.mkdir(parents=True, exist_ok=True)
    layer_records: list[dict[str, object]] = []
    for spec in LAYER_SPECS:
        samples = render_layer(spec)
        output_path = output_directory / spec.filename
        write_wave(output_path, samples)
        measurements = analyse(samples)
        if measurements["loop_join_step_pcm16"] > measurements["maximum_internal_step_pcm16"]:
            raise ValueError("layer %s does not loop seamlessly" % spec.layer_id)
        layer_records.append(
            {
                "layer_id": spec.layer_id,
                "filename": spec.filename,
                "role": spec.role,
                "musical_note": spec.musical_note,
                "loop_seconds": spec.loop_seconds,
                "seed_u32": spec.seed,
                "target_peak_dbfs": spec.peak_dbfs,
                "sha256": sha256(output_path),
                **measurements,
            }
        )

    manifest: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "asset_id": ASSET_ID,
        "authorship": "original_fixed_seed_offline_procedural_synthesis",
        "license": "project_original",
        "recorded_or_sampled_source_material": False,
        "runtime_generation": False,
        "runtime_intent": "seamless non-positional music/ambient bed for the non-combat station state",
        "historically_supported": False,
        "evidence_status": "modern_interpretation",
        "content_note": (
            "The key, voicing, loop lengths, bell motif, and layer levels are project-original "
            "modern composition. No surviving source authenticates any music for the original "
            "Keth Shipyards, and nothing here is presented as recovered or authentic Keth audio."
        ),
        "human_listening_pass": "outstanding",
        "generator": "tools/audio/generate_station_music_v1.py",
        "generator_sha256": sha256(Path(__file__).resolve()),
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
            "loop_end_frame": "final frame of each file",
        },
        "musical_contract": {
            "tuning_a4_hz": 440.0,
            "mode": "D natural minor (Aeolian)",
            "tempo": "free; no metrical pulse",
            "layer_count": len(LAYER_SPECS),
            "combined_cycle_seconds": COMBINED_CYCLE_SECONDS,
            "combined_cycle_note": (
                "16 s, 12 s, and 20 s loops only realign every 240 s, so the exact "
                "three-layer combination repeats once every four minutes."
            ),
            "seamlessness": (
                "sustaining layers snap every partial and LFO to an integer number of "
                "cycles per loop; the motif layer is silent at both boundaries."
            ),
        },
        "mix_contract": {
            "maximum_allowed_peak_dbfs": -10.0,
            "normalization": "per-layer integer sample peak",
            "runtime_gain_note": (
                "assets deliberately retain deep headroom; the runtime bed applies further "
                "per-layer trim and the Music bus carries the authored -6 dB mix offset"
            ),
        },
        "layer_count": len(layer_records),
        "layers": layer_records,
    }
    manifest_path = output_directory / MANIFEST_FILENAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the station-rest music bed v1.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
        help="destination for WAV files and the deterministic manifest",
    )
    arguments = parser.parse_args()
    manifest = generate(arguments.output_dir.resolve())
    for layer in manifest["layers"]:
        print(
            f"{layer['filename']}: {layer['duration_seconds']:.3f}s "
            f"{layer['peak_dbfs']:.2f} dBFS join={layer['loop_join_step_pcm16']} "
            f"max_step={layer['maximum_internal_step_pcm16']} {layer['sha256']}"
        )
    print(f"wrote {arguments.output_dir.resolve() / MANIFEST_FILENAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
