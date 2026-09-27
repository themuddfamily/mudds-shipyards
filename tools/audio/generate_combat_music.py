#!/usr/bin/env python3
"""Generate the original Mudds Shipyards adaptive combat music layer.

The station, flight and surface beds (``generate_station_music_v1.py`` and
``generate_flight_music_v1.py``) score the calm states and deliberately yield
to a fight. This script authors what plays *during* the fight and when it ends:

* three synchronous combat stems that the runtime ``CombatMusicLayer`` stacks
  as the encounter escalates:

  - ``combat_floor``  - a driving low eighth-note ostinato on the
                        i-VI-VII-V progression (Dm | Bb | C | A);
  - ``combat_drive``  - synthetic percussion: a low body on every beat and a
                        filtered noise snap on two and four;
  - ``combat_lead``   - a sustained brass-like upper voicing of the same
                        progression, only brought in against several hostiles;

* two one-shot stingers:

  - ``combat_victory`` - a rising A-to-D cadence that lands on D *major*
                         (a Picardy third), the only major chord in the score;
  - ``combat_failure`` - a subdued, low descending D-minor line that fades out.

Everything stays in D natural minor at A4 = 440 Hz, exactly like the calm
beds, so the cross-fade between a bed and the combat stems changes energy and
density rather than key. The stems run at 96 BPM, four times the surface bed's
24 BPM pulse, and loop every four bars (10 s), so all three stems share one
loop and the runtime keeps them sample-locked by starting them together.

Fixed-seed offline synthesis with numpy (and scipy for filtering) only; mono
16-bit 22050 Hz linear-PCM RIFF/WAVE exactly like every other music asset. The
checked-in WAV files are the runtime-ready authored assets; nothing here is
synthesised at runtime. No recorded, sampled, or third-party audio is used,
and nothing claims to reconstruct any historical Keth Shipyards music.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import wave
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np
from scipy import signal

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_station_music_v1 import (  # noqa: E402
    CHANNELS,
    SAMPLE_RATE,
    SAMPLE_WIDTH_BYTES,
    analyse,
    sha256,
    write_wave,
)

SCHEMA_VERSION = 1
ASSET_ID = "mudds.audio.music.combat_layer.v1"
REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "assets" / "audio" / "music"
MANIFEST_FILENAME = "combat_music_v1_asset_manifest.json"

TEMPO_BPM = 96.0
BEAT_SECONDS = 60.0 / TEMPO_BPM  # 0.625 s
BEATS_PER_BAR = 4
BAR_SECONDS = BEAT_SECONDS * BEATS_PER_BAR  # 2.5 s
BARS_PER_LOOP = 4
LOOP_SECONDS = BAR_SECONDS * BARS_PER_LOOP  # 10.0 s
LOOP_FRAMES = int(round(LOOP_SECONDS * SAMPLE_RATE))


def note(midi: int) -> float:
    """Equal temperament frequency of a MIDI note, A4 (69) = 440 Hz."""
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# MIDI numbers, spelled for readability.
A1, BB1, C2, D2 = 33, 34, 36, 38
A2, D3, E3, F3, FS3, A3 = 45, 50, 52, 53, 54, 57
BB3, C4, CS4, D4, E4, F4, FS4, G4, A4, BB4, C5 = 58, 60, 61, 62, 64, 65, 66, 67, 69, 70, 72
D5, FS5, A5 = 74, 78, 81

# i - VI - VII - V in D minor; the V is a real A major (C#) for pull back to i.
PROGRESSION = (
    {"name": "Dm", "root": D2, "upper": (D4, F4, A4)},
    {"name": "Bb", "root": BB1, "upper": (D4, F4, BB4)},
    {"name": "C", "root": C2, "upper": (E4, G4, C5)},
    {"name": "A", "root": A1, "upper": (E4, A4, CS4 + 12)},
)


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    kind: str  # "stem" (seamless loop) or "stinger" (one-shot)
    filename: str
    role: str
    musical_note: str
    seconds: float
    peak_dbfs: float
    seed: int
    renderer: Callable[["AssetSpec"], np.ndarray]


def envelope_ar(length: int, attack: float, decay_per_second: float) -> np.ndarray:
    t = np.arange(length) / SAMPLE_RATE
    attack_curve = np.clip(t / max(attack, 1.0e-4), 0.0, 1.0)
    return attack_curve * np.exp(-decay_per_second * t)


def add_wrapped(buffer: np.ndarray, start_frame: int, voice: np.ndarray) -> None:
    """Adds ``voice`` into a loop buffer, wrapping any tail over the join.

    Every stem is periodic by construction this way: a note struck near the
    end of the loop rings on into its beginning exactly as it would on the
    next pass, so the loop join is just another sample step.
    """
    indices = (start_frame + np.arange(voice.size)) % buffer.size
    np.add.at(buffer, indices, voice)


def saw_like(frequency: float, length: int, phase: float, partials: int) -> np.ndarray:
    """Band-limited sawtooth built from a fixed number of harmonics."""
    t = np.arange(length) / SAMPLE_RATE
    out = np.zeros(length)
    for k in range(1, partials + 1):
        if frequency * k >= SAMPLE_RATE * 0.45:
            break
        out += np.sin(2.0 * np.pi * frequency * k * t + phase * k) / k
    return out


def render_floor(spec: AssetSpec) -> np.ndarray:
    """Low eighth-note ostinato: root, root, octave, root with beat accents."""
    rng = np.random.default_rng(spec.seed)
    buffer = np.zeros(LOOP_FRAMES)
    eighth = BEAT_SECONDS / 2.0
    note_frames = int(round(eighth * 1.6 * SAMPLE_RATE))
    lowpass = signal.butter(2, 900.0, btype="low", fs=SAMPLE_RATE, output="sos")
    pattern = (0, 0, 12, 0, 0, 7, 12, 0)  # semitone offsets over the root
    for bar_index, chord in enumerate(PROGRESSION):
        for step in range(BEATS_PER_BAR * 2):
            onset = bar_index * BAR_SECONDS + step * eighth
            midi = chord["root"] + pattern[step]
            accent = 1.0 if step % 2 == 0 else 0.62
            if step == 0:
                accent = 1.15
            voice = saw_like(note(midi), note_frames, rng.uniform(0, 2 * np.pi), 10)
            voice = signal.sosfilt(lowpass, voice)
            voice *= envelope_ar(note_frames, 0.006, 6.5) * accent
            add_wrapped(buffer, int(round(onset * SAMPLE_RATE)), voice)
    # A quiet sustained sub root under each bar keeps the floor continuous.
    for bar_index, chord in enumerate(PROGRESSION):
        length = int(round(BAR_SECONDS * 1.25 * SAMPLE_RATE))
        t = np.arange(length) / SAMPLE_RATE
        sub = np.sin(2.0 * np.pi * note(chord["root"]) * t) * 0.35
        window = np.sin(np.pi * np.clip(t / (BAR_SECONDS * 1.25), 0.0, 1.0)) ** 2
        add_wrapped(buffer, int(round(bar_index * BAR_SECONDS * SAMPLE_RATE)), sub * window)
    return np.tanh(buffer * 0.9)


def render_drive(spec: AssetSpec) -> np.ndarray:
    """Synthetic percussion: pitched low body on beats, noise snap on 2 and 4."""
    rng = np.random.default_rng(spec.seed)
    buffer = np.zeros(LOOP_FRAMES)
    body_frames = int(round(0.45 * SAMPLE_RATE))
    t_body = np.arange(body_frames) / SAMPLE_RATE
    # Pitch drops from 110 Hz to 48 Hz: a drum body rather than a note.
    body_frequency = 48.0 + 62.0 * np.exp(-t_body * 28.0)
    body_phase = 2.0 * np.pi * np.cumsum(body_frequency) / SAMPLE_RATE
    body = np.sin(body_phase) * envelope_ar(body_frames, 0.002, 9.0)
    snap_frames = int(round(0.22 * SAMPLE_RATE))
    band = signal.butter(2, (900.0, 4200.0), btype="band", fs=SAMPLE_RATE, output="sos")
    ghost_band = signal.butter(2, (3000.0, 8000.0), btype="band", fs=SAMPLE_RATE, output="sos")
    total_beats = BARS_PER_LOOP * BEATS_PER_BAR
    for beat in range(total_beats):
        onset = int(round(beat * BEAT_SECONDS * SAMPLE_RATE))
        weight = 1.0 if beat % BEATS_PER_BAR == 0 else 0.78
        add_wrapped(buffer, onset, body * weight)
        if beat % 2 == 1:
            noise = rng.standard_normal(snap_frames)
            snap = signal.sosfilt(band, noise) * envelope_ar(snap_frames, 0.001, 22.0)
            add_wrapped(buffer, onset, snap * 1.6)
        # Quiet off-beat ticks keep the eighth-note motion in the drums.
        tick_frames = int(round(0.06 * SAMPLE_RATE))
        tick = signal.sosfilt(ghost_band, rng.standard_normal(tick_frames))
        tick *= envelope_ar(tick_frames, 0.0005, 60.0) * 0.55
        add_wrapped(buffer, onset + int(round(BEAT_SECONDS * 0.5 * SAMPLE_RATE)), tick)
    # A two-beat fill into the loop join on the final bar's last beat.
    for sixteenth in range(4):
        onset_seconds = (total_beats - 1) * BEAT_SECONDS + sixteenth * BEAT_SECONDS / 4.0
        noise = rng.standard_normal(snap_frames)
        snap = signal.sosfilt(band, noise) * envelope_ar(snap_frames, 0.001, 26.0)
        add_wrapped(buffer, int(round(onset_seconds * SAMPLE_RATE)), snap * (0.5 + 0.2 * sixteenth))
    return np.tanh(buffer * 0.8)


def render_lead(spec: AssetSpec) -> np.ndarray:
    """Sustained brass-like upper voicing, one chord per bar, cross-faded."""
    rng = np.random.default_rng(spec.seed)
    buffer = np.zeros(LOOP_FRAMES)
    overlap = 0.35
    length = int(round((BAR_SECONDS + overlap) * SAMPLE_RATE))
    t = np.arange(length) / SAMPLE_RATE
    # Swell in, hold, and release across the overlap into the next bar.
    envelope = np.clip(t / 0.18, 0.0, 1.0) * np.clip((BAR_SECONDS + overlap - t) / overlap, 0.0, 1.0)
    swell = 0.85 + 0.15 * np.sin(2.0 * np.pi * t / BAR_SECONDS - np.pi / 2.0)
    brass = signal.butter(2, 2400.0, btype="low", fs=SAMPLE_RATE, output="sos")
    for bar_index, chord in enumerate(PROGRESSION):
        voice = np.zeros(length)
        for voice_index, midi in enumerate(chord["upper"]):
            detune = 1.0 + (voice_index - 1) * 0.0015
            voice += saw_like(note(midi) * detune, length, rng.uniform(0, 2 * np.pi), 14) * (
                1.0 - 0.12 * voice_index
            )
        voice = signal.sosfilt(brass, voice) * envelope * swell
        add_wrapped(buffer, int(round(bar_index * BAR_SECONDS * SAMPLE_RATE)), voice)
    return np.tanh(buffer * 0.55)


def fade_tail(samples: np.ndarray, fade_seconds: float) -> np.ndarray:
    fade_frames = int(round(fade_seconds * SAMPLE_RATE))
    out = samples.copy()
    out[-fade_frames:] *= np.linspace(1.0, 0.0, fade_frames) ** 2
    out[: int(0.003 * SAMPLE_RATE)] *= np.linspace(0.0, 1.0, int(0.003 * SAMPLE_RATE))
    return out


def render_victory(spec: AssetSpec) -> np.ndarray:
    """A-major pickup into a held D-major chord: the score's only major landing."""
    rng = np.random.default_rng(spec.seed)
    frames = int(round(spec.seconds * SAMPLE_RATE))
    out = np.zeros(frames)
    brass = signal.butter(2, 2800.0, btype="low", fs=SAMPLE_RATE, output="sos")
    pickup = (A3, CS4, E4)
    landing = (D3, A3, D4, FS4, A4, D5)
    pickup_seconds = BEAT_SECONDS * 1.5
    pickup_frames = int(round(pickup_seconds * SAMPLE_RATE))
    for midi in pickup:
        tone = saw_like(note(midi), pickup_frames, rng.uniform(0, 2 * np.pi), 12)
        tone *= envelope_ar(pickup_frames, 0.02, 1.2)
        out[:pickup_frames] += signal.sosfilt(brass, tone) * 0.55
    start = pickup_frames
    hold_frames = frames - start
    t = np.arange(hold_frames) / SAMPLE_RATE
    for voice_index, midi in enumerate(landing):
        tone = saw_like(note(midi), hold_frames, rng.uniform(0, 2 * np.pi), 12)
        tone *= np.clip(t / 0.06, 0.0, 1.0) * np.exp(-t * 0.55)
        out[start:] += signal.sosfilt(brass, tone) * (0.8 - 0.07 * voice_index)
    # Bright struck F#5/A5 on the landing so the major third is unmistakable.
    for midi, level in ((FS5, 0.35), (A5, 0.25)):
        tone = np.sin(2.0 * np.pi * note(midi) * t) * envelope_ar(hold_frames, 0.004, 2.2)
        out[start:] += tone * level
    # Low drum hit on the landing, shared with the drive stem's voice.
    body_frames = min(hold_frames, int(round(0.6 * SAMPLE_RATE)))
    tb = np.arange(body_frames) / SAMPLE_RATE
    body_phase = 2.0 * np.pi * np.cumsum(46.0 + 64.0 * np.exp(-tb * 24.0)) / SAMPLE_RATE
    out[start:start + body_frames] += np.sin(body_phase) * envelope_ar(body_frames, 0.002, 6.0) * 1.2
    return fade_tail(np.tanh(out * 0.6), 1.2)


def render_failure(spec: AssetSpec) -> np.ndarray:
    """A soft, low descending D-minor line over a fading D pedal."""
    rng = np.random.default_rng(spec.seed)
    frames = int(round(spec.seconds * SAMPLE_RATE))
    out = np.zeros(frames)
    t = np.arange(frames) / SAMPLE_RATE
    dark = signal.butter(2, 700.0, btype="low", fs=SAMPLE_RATE, output="sos")
    pedal = saw_like(note(D2), frames, rng.uniform(0, 2 * np.pi), 8)
    out += signal.sosfilt(dark, pedal) * np.clip(t / 0.4, 0.0, 1.0) * np.exp(-t * 0.35) * 0.7
    line = (D4, C4, BB3, A3)
    step_seconds = BEAT_SECONDS * 1.5
    for index, midi in enumerate(line):
        onset = int(round(index * step_seconds * SAMPLE_RATE))
        length = min(frames - onset, int(round(step_seconds * 2.2 * SAMPLE_RATE)))
        tl = np.arange(length) / SAMPLE_RATE
        tone = np.sin(2.0 * np.pi * note(midi) * tl) + 0.25 * np.sin(4.0 * np.pi * note(midi) * tl)
        tone *= np.clip(tl / 0.12, 0.0, 1.0) * np.exp(-tl * 1.1) * (0.6 - 0.07 * index)
        out[onset:onset + length] += tone
    # The last chord is a bare Dm (D3-F3-A3) left to decay: unresolved, quiet.
    chord_onset = int(round(len(line) * step_seconds * SAMPLE_RATE))
    tc = np.arange(frames - chord_onset) / SAMPLE_RATE
    for midi in (D3, F3, A3):
        out[chord_onset:] += np.sin(2.0 * np.pi * note(midi) * tc) * np.clip(tc / 0.3, 0.0, 1.0) * np.exp(-tc * 0.9) * 0.3
    return fade_tail(np.tanh(out * 0.8), 1.6)


ASSET_SPECS = (
    AssetSpec(
        asset_id="combat_floor",
        kind="stem",
        filename="combat_stem_floor_v1.wav",
        role="driving low ostinato; the always-present floor of the engaged state",
        musical_note="eighth-note root/fifth/octave ostinato on Dm | Bb | C | A at 96 BPM with a sub root",
        seconds=LOOP_SECONDS,
        peak_dbfs=-12.0,
        seed=0x4D434D31,
        renderer=render_floor,
    ),
    AssetSpec(
        asset_id="combat_drive",
        kind="stem",
        filename="combat_stem_drive_v1.wav",
        role="synthetic percussion; the pulse of the engaged state",
        musical_note="pitch-dropping low body on every beat, band-limited noise snap on 2 and 4, off-beat ticks, fill into the loop",
        seconds=LOOP_SECONDS,
        peak_dbfs=-13.0,
        seed=0x4D434D32,
        renderer=render_drive,
    ),
    AssetSpec(
        asset_id="combat_lead",
        kind="stem",
        filename="combat_stem_lead_v1.wav",
        role="sustained brass-like upper voicing; only brought in against several hostiles",
        musical_note="close-voiced Dm (D4-F4-A4) | Bb (D4-F4-Bb4) | C (E4-G4-C5) | A (E4-A4-C#5) swells",
        seconds=LOOP_SECONDS,
        peak_dbfs=-15.0,
        seed=0x4D434D33,
        renderer=render_lead,
    ),
    AssetSpec(
        asset_id="combat_victory",
        kind="stinger",
        filename="combat_stinger_victory_v1.wav",
        role="one-shot victory stinger when an encounter is cleared",
        musical_note="A major pickup (A3-C#4-E4) into a held D major (D3-A3-D4-F#4-A4-D5), a Picardy landing",
        seconds=4.5,
        peak_dbfs=-11.0,
        seed=0x4D434D34,
        renderer=render_victory,
    ),
    AssetSpec(
        asset_id="combat_failure",
        kind="stinger",
        filename="combat_stinger_failure_v1.wav",
        role="subdued one-shot failure stinger when an encounter is lost",
        musical_note="descending D4-C4-Bb3-A3 over a fading D2 pedal, ending on a bare D minor",
        seconds=5.5,
        peak_dbfs=-17.0,
        seed=0x4D434D35,
        renderer=render_failure,
    ),
)


def quantize(samples: np.ndarray, peak_dbfs: float) -> list[int]:
    maximum = float(np.max(np.abs(samples)))
    if maximum <= 0.0:
        raise ValueError("cannot normalize a silent asset")
    target = (10.0 ** (peak_dbfs / 20.0)) * 32767.0
    scaled = np.clip(np.round(samples * (target / maximum)), -32767, 32767)
    return [int(value) for value in scaled.astype(np.int32)]


def pcm_sha256(path: Path) -> str:
    with wave.open(str(path), "rb") as source:
        return hashlib.sha256(source.readframes(source.getnframes())).hexdigest()


def generate(output_directory: Path) -> dict[str, object]:
    output_directory.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    for spec in ASSET_SPECS:
        samples = quantize(spec.renderer(spec), spec.peak_dbfs)
        output_path = output_directory / spec.filename
        write_wave(output_path, samples)
        measurements = analyse(samples)
        if spec.kind == "stem":
            if measurements["frame_count"] != LOOP_FRAMES:
                raise ValueError("stem %s is not exactly one loop long" % spec.asset_id)
            if measurements["loop_join_step_pcm16"] > measurements["maximum_internal_step_pcm16"]:
                raise ValueError("stem %s does not loop seamlessly" % spec.asset_id)
        elif abs(samples[-1]) > 64:
            raise ValueError("stinger %s does not end in silence" % spec.asset_id)
        records.append(
            {
                "asset_id": spec.asset_id,
                "kind": spec.kind,
                "filename": spec.filename,
                "role": spec.role,
                "musical_note": spec.musical_note,
                "looped": spec.kind == "stem",
                "seed_u32": spec.seed,
                "target_peak_dbfs": spec.peak_dbfs,
                "sha256": sha256(output_path),
                "pcm_sha256": pcm_sha256(output_path),
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
        "runtime_intent": (
            "adaptive combat layer: three sample-locked stems cross-faded over the ducked "
            "calm bed while an encounter is live, a victory or failure stinger when it ends, "
            "then a hold before the prior bed returns"
        ),
        "runtime_consumer": "scripts/audio/combat_music_layer.gd",
        "historically_supported": False,
        "evidence_status": "modern_interpretation",
        "content_note": (
            "The progression, tempo, voicing, percussion and stingers are project-original "
            "modern composition. No surviving source authenticates any music for the original "
            "Keth Shipyards, and nothing here is presented as recovered or authentic Keth audio."
        ),
        "human_listening_pass": "outstanding",
        "generator": "tools/audio/generate_combat_music.py",
        "generator_sha256": sha256(Path(__file__).resolve()),
        "generator_dependencies": ["numpy", "scipy"],
        "companion_generators": [
            "tools/audio/generate_station_music_v1.py",
            "tools/audio/generate_flight_music_v1.py",
        ],
        "format_contract": {
            "container": "RIFF/WAVE",
            "encoding": "linear PCM signed 16-bit little-endian",
            "sample_rate_hz": SAMPLE_RATE,
            "channels": CHANNELS,
            "channel_layout": "mono",
            "bit_depth": SAMPLE_WIDTH_BYTES * 8,
            "stems": "looped forward, loop_begin_frame 0 to the final frame",
            "stingers": "one-shot, not looped, ending in silence",
        },
        "musical_contract": {
            "tuning_a4_hz": 440.0,
            "mode": "D natural minor (Aeolian); the V chord is A major and the victory lands on D major",
            "tempo_bpm": TEMPO_BPM,
            "tempo_note": "four times the surface bed's 24 BPM pulse",
            "progression": [chord["name"] for chord in PROGRESSION],
            "loop_seconds": LOOP_SECONDS,
            "loop_bars": BARS_PER_LOOP,
            "shared_key_note": (
                "all combat material sits in the calm beds' D natural minor at A4 = 440 Hz, so "
                "entering and leaving combat changes energy rather than key."
            ),
            "seamlessness": (
                "every stem is rendered into a loop-length buffer with every tail wrapped across "
                "the join, so each stem is periodic by construction; all stems share one length "
                "and the runtime starts them together so they stay sample-locked."
            ),
        },
        "mix_contract": {
            "maximum_allowed_peak_dbfs": -10.0,
            "normalization": "per-asset integer sample peak",
            "runtime_gain_note": (
                "the runtime layer applies per-stem trim on the Music bus; the failure stinger is "
                "authored 6 dB under the victory stinger so a loss is subdued rather than loud"
            ),
        },
        "asset_count": len(records),
        "assets": records,
    }
    manifest_path = output_directory / MANIFEST_FILENAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate the adaptive combat music layer v1.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
        help="destination for WAV files and the deterministic manifest",
    )
    arguments = parser.parse_args()
    manifest = generate(arguments.output_dir.resolve())
    for record in manifest["assets"]:
        print(
            f"{record['filename']}: {record['duration_seconds']:.3f}s "
            f"{record['peak_dbfs']:.2f} dBFS join={record['loop_join_step_pcm16']} "
            f"max_step={record['maximum_internal_step_pcm16']} {record['sha256']}"
        )
    print(f"wrote {arguments.output_dir.resolve() / MANIFEST_FILENAME}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
