#!/usr/bin/env python3
"""Generate the original Mudds Shipyards flight and surface music beds v1.

The station-rest bed (``generate_station_music_v1.py``) covers one place. This
script authors the two beds the player reaches by leaving it:

* ``flight``  - orbit and open space. Sparser, higher and colder than the
                station bed: an open D/A fifth with no minor third in the
                sustaining floor, upper-register colour, and a handful of thin
                high signals instead of a bell phrase.
* ``surface`` - standing on a planet. Warmer than the station bed: the same
                mode with a fuller low-overtone floor, a wide Dm11 pad, and a
                slow 24 BPM low pulse that the other two beds deliberately
                lack, so a surface arrival is recognisable in one bar.

Both beds stay in D natural minor at A4 = 440 Hz, exactly like the station bed,
so the runtime cross-fade between any two of the three is a change of register,
density and colour rather than a change of key.

Everything here is the same contract as the station generator and reuses its
primitives directly: fixed-seed offline standard-library synthesis, mono 16-bit
22050 Hz linear-PCM RIFF/WAVE, seamless by construction, and the checked-in WAV
files are the runtime-ready authored assets rather than something the game
synthesises at runtime. No recorded, sampled, or third-party audio is used, and
nothing here claims to reconstruct or recover any historical Keth Shipyards
music.

Every layer shares the station bed's loop geometry (16 s / 12 s / 20 s, which
only realign every 240 s). That is a runtime requirement, not a coincidence:
the bed swaps one loop slot at a time while the other slots keep sounding, so
the three beds must agree on slot lengths for the hand-off to stay inside one
fixed three-voice budget.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import wave
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Sequence

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_station_music_v1 import (  # noqa: E402
    CHANNELS,
    COMBINED_CYCLE_SECONDS,
    SAMPLE_RATE,
    SAMPLE_WIDTH_BYTES,
    Partial,
    Phases,
    analyse,
    quantize,
    render_sustained,
    sha256,
    smoothstep,
    write_wave,
)

SCHEMA_VERSION = 1
ASSET_ID = "mudds.audio.music.flight_surface_bed.v1"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "music"
MANIFEST_FILENAME = "flight_music_v1_asset_manifest.json"

# Equal temperament, A4 = 440 Hz, spelled out so the intent stays readable.
A1 = 55.0000
D2 = 73.4162
F2 = 87.3071
A2 = 110.0000
D3 = 146.8324
F3 = 174.6141
A3 = 220.0000
C4 = 261.6256
D4 = 293.6648
F4 = 349.2282
G4 = 391.9954
A4 = 440.0000
C5 = 523.2511
D5 = 587.3295
E5 = 659.2551
E6 = 1318.5102
A6 = 1760.0000


@dataclass(frozen=True)
class Struck:
    """One struck event: an onset, a pitch, a level and a decay rate."""

    onset_seconds: float
    frequency_hz: float
    amplitude: float
    decay_per_second: float


@dataclass(frozen=True)
class StruckVoice:
    """The fixed timbre shared by every event in a struck layer."""

    partial_ratios: Sequence[float]
    partial_amplitudes: Sequence[float]
    partial_decays: Sequence[float]
    attack_seconds: float
    saturation: float


@dataclass(frozen=True)
class LayerSpec:
    bed_id: str
    layer_id: str
    slot_id: str
    filename: str
    role: str
    musical_note: str
    loop_seconds: float
    peak_dbfs: float
    seed: int
    renderer: Callable[["LayerSpec"], list[float]]
    partials: Sequence[Partial] = field(default_factory=tuple)
    events: Sequence[Struck] = field(default_factory=tuple)
    voice: StruckVoice | None = None


def render_partials(spec: LayerSpec) -> list[float]:
    return render_sustained(spec, spec.partials)


def render_struck(spec: LayerSpec, wrap: bool) -> list[float]:
    """Render decaying struck events over one loop.

    ``wrap`` selects between the two seamlessness strategies. A wrapped layer
    lets every tail continue across the loop join, so the result is periodic by
    construction and a regular pulse keeps its spacing across the join. An
    unwrapped layer instead fades to exact silence at both boundaries, which
    suits sparse gestures that must not tick.
    """
    voice = spec.voice
    if voice is None:
        raise ValueError("layer %s has no struck voice" % spec.layer_id)
    frame_count = round(spec.loop_seconds * SAMPLE_RATE)
    phases = Phases(spec.seed)
    event_phases = [
        [phases.next_phase() for _ in voice.partial_ratios] for _ in spec.events
    ]

    samples = [0.0] * frame_count
    for event_index, event in enumerate(spec.events):
        start_frame = round(event.onset_seconds * SAMPLE_RATE)
        first_frame = 0 if wrap else start_frame
        for frame in range(first_frame, frame_count):
            offset = frame - start_frame
            if wrap:
                offset %= frame_count
            local_time = offset / SAMPLE_RATE
            attack = smoothstep(0.0, voice.attack_seconds, local_time)
            value = 0.0
            for partial_index, ratio in enumerate(voice.partial_ratios):
                decay = math.exp(
                    -event.decay_per_second * voice.partial_decays[partial_index] * local_time
                )
                if decay < 1.0e-5:
                    continue
                value += (
                    math.sin(
                        math.tau * event.frequency_hz * ratio * local_time
                        + event_phases[event_index][partial_index]
                    )
                    * voice.partial_amplitudes[partial_index]
                    * decay
                )
            samples[frame] += value * event.amplitude * attack

    for frame in range(frame_count):
        value = math.tanh(samples[frame] * voice.saturation)
        if not wrap:
            time = frame / SAMPLE_RATE
            value *= smoothstep(0.0, 0.30, time) * smoothstep(
                0.0, 0.90, spec.loop_seconds - time
            )
        samples[frame] = value
    return samples


def render_guarded_struck(spec: LayerSpec) -> list[float]:
    return render_struck(spec, wrap=False)


def render_wrapped_struck(spec: LayerSpec) -> list[float]:
    return render_struck(spec, wrap=True)


SIGNAL_VOICE = StruckVoice(
    # Nearly harmonic and thin: a cold instrument panel ping rather than a bell.
    partial_ratios=(1.0, 2.0, 3.01, 4.97),
    partial_amplitudes=(1.0, 0.30, 0.12, 0.05),
    partial_decays=(1.0, 1.7, 2.4, 3.4),
    attack_seconds=0.004,
    saturation=0.58,
)
PULSE_VOICE = StruckVoice(
    # Strictly harmonic with a soft attack: a warm low body, not a transient.
    partial_ratios=(1.0, 2.0, 3.0, 4.0),
    partial_amplitudes=(1.0, 0.34, 0.14, 0.06),
    partial_decays=(1.0, 1.5, 2.1, 2.8),
    attack_seconds=0.014,
    saturation=0.66,
)


LAYER_SPECS = (
    LayerSpec(
        bed_id="flight",
        layer_id="flight_drift",
        slot_id="drone",
        filename="flight_bed_drift_v1.wav",
        role="sustained open-fifth drift; the always-present floor of the orbit bed",
        musical_note=(
            "open D/A drift on a distant D2 with A3-D4-A4 above and no minor third, "
            "so the floor reads as cold and unresolved rather than minor-warm"
        ),
        loop_seconds=16.0,
        peak_dbfs=-13.0,
        seed=0x4D554D41,
        renderer=render_partials,
        partials=(
            Partial(D2, 0.22, 1, 0.30),
            Partial(A3, 0.46, 2, 0.42, (0.08,)),
            Partial(D4, 0.40, 3, 0.46, (0.06,)),
            Partial(A4, 0.26, 5, 0.52),
            Partial(D5, 0.14, 4, 0.55),
            Partial(E5, 0.10, 7, 0.60),
            Partial(E6, 0.012, 11, 0.70),
            Partial(A6, 0.008, 13, 0.75),
        ),
    ),
    LayerSpec(
        bed_id="flight",
        layer_id="flight_shimmer",
        slot_id="harmonics",
        filename="flight_bed_shimmer_v1.wav",
        role="upper-register swell layer; thin Dm9 colour an octave above the station pad",
        musical_note="Dm9 (D4-F4-A4-C5-E5) with five deep independent swells",
        loop_seconds=12.0,
        peak_dbfs=-17.0,
        seed=0x4D554D42,
        renderer=render_partials,
        partials=(
            # Deeper LFOs than the station pad: voices drop nearly to nothing, so
            # the chord is rarely complete and the layer reads as sparse.
            Partial(D4, 0.34, 1, 0.70, (0.10,)),
            Partial(F4, 0.20, 2, 0.72),
            Partial(A4, 0.28, 3, 0.74, (0.08,)),
            Partial(C5, 0.18, 5, 0.76),
            Partial(E5, 0.14, 4, 0.78),
        ),
    ),
    LayerSpec(
        bed_id="flight",
        layer_id="flight_signal",
        slot_id="motif",
        filename="flight_bed_signal_v1.wav",
        role="sparse high signal pings; the orbit bed's only foreground gesture",
        musical_note="five-ping A4-D5-E5-A4-F4 figure, silent at both loop boundaries",
        loop_seconds=20.0,
        peak_dbfs=-15.0,
        seed=0x4D554D43,
        renderer=render_guarded_struck,
        events=(
            Struck(1.10, A4, 0.85, 2.6),
            Struck(5.30, D5, 0.70, 2.8),
            Struck(9.90, E5, 0.50, 3.0),
            Struck(13.40, A4, 0.60, 2.6),
            Struck(16.85, F4, 0.75, 2.4),
        ),
        voice=SIGNAL_VOICE,
    ),
    LayerSpec(
        bed_id="surface",
        layer_id="surface_warmth",
        slot_id="drone",
        filename="surface_bed_warmth_v1.wav",
        role="sustained low warmth; the always-present floor of the surface bed",
        musical_note=(
            "D natural minor floor on D1/D2 with the A2 fifth, the F3 third and "
            "strong low overtones, so the floor reads as warm ground rather than vacuum"
        ),
        loop_seconds=16.0,
        peak_dbfs=-12.0,
        seed=0x4D554D44,
        renderer=render_partials,
        partials=(
            Partial(36.7081, 0.42, 1, 0.18),
            Partial(D2, 0.88, 2, 0.22, (0.22, 0.10, 0.05)),
            Partial(A2, 0.46, 3, 0.26, (0.16, 0.06)),
            Partial(D3, 0.30, 4, 0.28, (0.12, 0.05)),
            Partial(F3, 0.22, 5, 0.32, (0.10,)),
            Partial(A3, 0.12, 6, 0.34),
            Partial(C4, 0.06, 7, 0.40),
        ),
    ),
    LayerSpec(
        bed_id="surface",
        layer_id="surface_choir",
        slot_id="harmonics",
        filename="surface_bed_choir_v1.wav",
        role="wide mid-register pad; the surface bed's sustained colour",
        musical_note="Dm11 (D3-F3-A3-C4-G4) with slow shallow swells and full overtones",
        loop_seconds=12.0,
        peak_dbfs=-15.0,
        seed=0x4D554D45,
        renderer=render_partials,
        partials=(
            Partial(D3, 0.52, 1, 0.45, (0.22, 0.09)),
            Partial(F3, 0.44, 2, 0.48, (0.20, 0.08)),
            Partial(A3, 0.36, 3, 0.50, (0.18, 0.07)),
            Partial(C4, 0.26, 4, 0.52, (0.15, 0.05)),
            Partial(G4, 0.18, 5, 0.55, (0.12, 0.04)),
        ),
    ),
    LayerSpec(
        bed_id="surface",
        layer_id="surface_pulse",
        slot_id="motif",
        filename="surface_bed_pulse_v1.wav",
        role="slow low pulse; the one gesture neither the station nor the orbit bed has",
        musical_note=(
            "eight low strikes at 2.5 s (24 BPM) over the 20 s loop, varied in pitch "
            "and weight across A1-D2-F2-A2 so the figure spans the whole loop"
        ),
        loop_seconds=20.0,
        peak_dbfs=-14.0,
        seed=0x4D554D46,
        renderer=render_wrapped_struck,
        events=(
            Struck(0.0, D2, 1.00, 1.15),
            Struck(2.5, A2, 0.55, 1.30),
            Struck(5.0, D2, 0.80, 1.15),
            Struck(7.5, F2, 0.50, 1.25),
            Struck(10.0, D2, 0.95, 1.10),
            Struck(12.5, A2, 0.52, 1.30),
            Struck(15.0, D2, 0.85, 1.15),
            Struck(17.5, A1, 0.62, 1.00),
        ),
        voice=PULSE_VOICE,
    ),
)

BED_CONTRACTS = {
    "flight": {
        "bed_id": "flight",
        "presentation_states": ["planetary", "orbit"],
        "intent": (
            "orbit and open space; sparser, higher and colder than the station bed, "
            "with no minor third in the sustaining floor"
        ),
    },
    "surface": {
        "bed_id": "surface",
        "presentation_states": ["surface"],
        "intent": (
            "standing on a planet; warmer than the station bed, with a slow 24 BPM low "
            "pulse that neither other bed has"
        ),
    },
}


def render_layer(spec: LayerSpec) -> list[int]:
    return quantize(spec.renderer(spec), spec.peak_dbfs)


def pcm_sha256(path: Path) -> str:
    """Digest of the PCM payload alone, which is what the engine imports.

    The runtime bed pins this value rather than the file digest so a re-container
    that keeps the samples identical does not read as a content change, while any
    change to the samples themselves fails the runtime audit.
    """
    with wave.open(str(path), "rb") as source:
        return hashlib.sha256(source.readframes(source.getnframes())).hexdigest()


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
                "bed_id": spec.bed_id,
                "layer_id": spec.layer_id,
                "slot_id": spec.slot_id,
                "filename": spec.filename,
                "role": spec.role,
                "musical_note": spec.musical_note,
                "loop_seconds": spec.loop_seconds,
                "seed_u32": spec.seed,
                "target_peak_dbfs": spec.peak_dbfs,
                "sha256": sha256(output_path),
                "pcm_sha256": pcm_sha256(output_path),
                **measurements,
            }
        )

    beds: list[dict[str, object]] = []
    for bed_id, contract in BED_CONTRACTS.items():
        record = dict(contract)
        record["layer_ids"] = [
            layer["layer_id"] for layer in layer_records if layer["bed_id"] == bed_id
        ]
        beds.append(record)

    manifest: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "asset_id": ASSET_ID,
        "authorship": "original_fixed_seed_offline_procedural_synthesis",
        "license": "project_original",
        "recorded_or_sampled_source_material": False,
        "runtime_generation": False,
        "runtime_intent": (
            "seamless non-positional music beds for the orbit/open-space and planetary "
            "surface states, cross-faded against the station-rest bed"
        ),
        "historically_supported": False,
        "evidence_status": "modern_interpretation",
        "content_note": (
            "The key, voicing, loop lengths, signal and pulse figures, and layer levels are "
            "project-original modern composition. No surviving source authenticates any music "
            "for the original Keth Shipyards, and nothing here is presented as recovered or "
            "authentic Keth audio."
        ),
        "human_listening_pass": "outstanding",
        "generator": "tools/audio/generate_flight_music_v1.py",
        "generator_sha256": sha256(Path(__file__).resolve()),
        "companion_generator": "tools/audio/generate_station_music_v1.py",
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
            "tempo": (
                "free in the flight bed; the surface pulse layer strikes every 2.5 s (24 BPM)"
            ),
            "bed_count": len(BED_CONTRACTS),
            "layer_count": len(LAYER_SPECS),
            "combined_cycle_seconds": COMBINED_CYCLE_SECONDS,
            "combined_cycle_note": (
                "every bed reuses the station bed's 16 s, 12 s and 20 s slot lengths, so each "
                "bed also only repeats exactly every 240 s and the runtime can hand one slot "
                "over at a time inside one fixed three-voice budget."
            ),
            "shared_key_note": (
                "all three beds sit in D natural minor at A4 = 440 Hz, so a cross-fade between "
                "them changes register, density and colour rather than key."
            ),
            "seamlessness": (
                "sustaining layers snap every partial and LFO to an integer number of cycles "
                "per loop; the flight signal layer is silent at both boundaries; the surface "
                "pulse layer wraps every tail across the join so it is periodic by construction."
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
        "beds": beds,
        "layer_count": len(layer_records),
        "layers": layer_records,
    }
    manifest_path = output_directory / MANIFEST_FILENAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate the flight and surface music beds v1."
    )
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
