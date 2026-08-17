# Renderer-independent audio voice census

This census freezes the scene-graph side of the production audio budget. It inventories `AudioStreamPlayer`, `AudioStreamPlayer2D`, and `AudioStreamPlayer3D` nodes; their exposed `max_polyphony`; bus and component ownership; and unique reachable `AudioStream` payloads. It does not render or start a native audio backend.

## Frozen production scenarios

Both scenarios use Godot's `Dummy` audio driver, settle eight idle frames plus one physics and one idle frame, and then disable `Main` processing before measurement.

| Metric | `station_resident` | `cinder_loaded` | Loaded delta |
| --- | ---: | ---: | ---: |
| Player nodes | 56 | 56 | 0 |
| `AudioStreamPlayer` | 8 | 8 | 0 |
| `AudioStreamPlayer2D` | 0 | 0 | 0 |
| `AudioStreamPlayer3D` | 48 | 48 | 0 |
| Currently playing nodes | 0 | 0 | 0 |
| Exposed summed polyphony ceiling | 56 | 56 | 0 |
| Unique retained streams | 97 | 97 | 0 |
| Exact retained WAV payload bytes | 4,052,420 | 4,052,420 | 0 |

The loaded case is one real coordinator-owned Cinder generation, not a fixture. Its exact zero delta means that generation currently contributes no audio players or reachable streams. It does not imply that future Cinder content has a zero budget.

The resident player split is:

| Bus | Players |
| --- | ---: |
| Ambience | 9 |
| Engines | 20 |
| Music | 3 |
| UI | 9 |
| Weapons | 15 |

| Component bucket | Players |
| --- | ---: |
| ArrowReconShip | 6 |
| AudioDirector | 5 |
| CombatAudioPresentation | 10 |
| HalyardCrewTransport | 6 |
| JovianLightFreighter | 6 |
| ShipyardWorld/OperationalLattice | 8 |
| StationMusicBed | 3 |
| TorrentInterceptor | 6 |
| ZenithInterceptor | 6 |

The checked-in measurement fingerprints are `82010c305363de8fff2a992d6fab523870cd6cb4f93644e4a7adba8f3038fe55` for `station_resident` and `8b599a221d0ab771f6cbbba71608ad177e778b417a7e89c19e93353a76176f7b` for `cinder_loaded`. The fingerprint covers scenario identity, stable player paths and states, buses, component buckets, polyphony fields, and retained stream descriptors. Freed-object traversal telemetry remains visible in a report but is deliberately excluded because it is not audio budget currency.

## Interpretation boundaries

`currently_playing_nodes` is the Godot node property observed under the declared Dummy profile. The lower bound counts those playing nodes once; the upper bound sums their exposed polyphony. The full `summed_max_polyphony_ceiling` is configuration capacity, not proof that native voices were allocated. Zero playing nodes under Dummy must not be presented as a mixer measurement or as evidence that production audio is silent.

Retained bytes are exact `AudioStreamWAV.data` payload bytes reachable from the frozen scene graph. Shared resources count once. Unknown stream payloads are counted separately instead of guessed. These numbers exclude decoded backend buffers, native mixer voices and memory, audio-thread CPU, process RAM, frame time, and renderer cost.

## Reproduction and change control

Run the focused checks only:

```bash
godot --headless --audio-driver Dummy --path . --script res://tests/audio_voice_census_fixture_test.gd
godot --headless --audio-driver Dummy --path . --script res://tests/audio_voice_census_scenario_test.gd
```

To write an individual full report:

```bash
KETH_AUDIO_CENSUS_SCENARIO=station_resident \
KETH_AUDIO_CENSUS_JSON=/tmp/audio-station-resident.json \
godot --headless --audio-driver Dummy --path . \
  --script res://tools/performance/audio_voice_census.gd

KETH_AUDIO_CENSUS_SCENARIO=cinder_loaded \
KETH_AUDIO_CENSUS_JSON=/tmp/audio-cinder-loaded.json \
godot --headless --audio-driver Dummy --path . \
  --script res://tools/performance/audio_voice_census.gd
```

The full report contract is [audio_voice_census.schema.json](../tools/performance/audio_voice_census.schema.json), and the production freeze is [audio_voice_census_baseline.json](../tools/performance/audio_voice_census_baseline.json). A baseline update must include both production scenarios, explain every changed component or stream owner, and preserve the explicit authority exclusions. Do not refresh a fingerprint merely to make a test green.

The JSON Schema is the portable report contract; the focused GDScript validator enforces its top-level shapes and deterministic fingerprint inside Godot. The foundation does not bundle a general JSON Schema evaluator.
