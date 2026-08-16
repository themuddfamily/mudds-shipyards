# Performance benchmark runner

`tools/performance/benchmark_runner.gd` is the first production-scene timing
framework. It is a recorder, not a performance result. In particular, output
from llvmpipe, another software renderer, a headless display, an undeclared
machine, or hardware that differs from the declared target profile is always
labelled nonrepresentative.

## Scenarios and sampling

Each scenario gets a fresh instance of `scenes/main.tscn`, the selected visual
quality profile, a fixed global RNG seed, its own warm-up, and its own sample
window. Scenario order and inputs are frozen in the JSON:

1. `station_embodied_route` starts the shift at the production player spawn and
   drives the real `PlayerController` with four equal movement segments:
   forward, forward+right, forward, and forward+left.
2. `nearby_sector_ship_flight_route` places the production Torrent at the
   production nearby-sector approach-lane point, aims it at the dock gate, and
   drives its `LocalShipInputSource` with forward thrust plus boost for the
   middle half of the route.

Neither scenario can pass by sampling an idle scene. Each records the actor's
start and end transforms, accumulated path, and maximum displacement. The
station route must show horizontal movement by the real, enabled
`PlayerController`. The flight must observe one command tick where accepted
forward demand and `ONLINE` propulsion agree, actual motion toward the dock-gate
target, and a positive, undestroyed hull throughout. A full flight must enter
the 20 m endpoint radius; the short smoke is explicitly allowed to prove only
bounded positive progress.

Defaults are deliberately explicit: 3,600 warm-up frames and 18,000 measured
frames per scenario, at 1920×1080 High. Those counts are configuration, not an
assumption about achieved frame rate. A representative acceptance record should
retain the defaults unless its record explains a different reviewed protocol.

Frame delta is the wall interval, in milliseconds, between consecutive
`process_frame` signals measured with `Time.get_ticks_usec()`. The JSON records
nearest-rank p50, p95, p99, and maximum. It also records per-frame summaries for
Godot's available FPS, process, physics, navigation, render-object, primitive,
draw-call, node, resource, and static-memory monitors. Static and peak process
RAM, scene counts, Main instantiation/ready time, warm-up frames, and sample
counts are recorded per scenario.

Godot does not expose a reliable portable per-frame GPU timer to this harness,
and renderer memory counters do not establish comparable dedicated VRAM use.
The schema therefore records `gpu_frame_time_ms` and `vram_bytes` with
`available: false`, `value: null`, and a reason. Zero is never substituted for
an unavailable measurement.

## Target profile and representative-pass gate

The target is a separate JSON file supplied with
`KETH_BENCHMARK_TARGET_PROFILE`. It must contain the same nested fields as the
observed environment for:

- `os.name`
- `cpu.name`
- `gpu.adapter`
- `gpu.driver`
- `render.method`
- `render.display_server`
- `render.resolution`
- `profile.quality_name`

All fields must match exactly. Missing fields, mismatches, a headless display,
or an adapter name containing `llvmpipe`, `softpipe`, `software`, or
`swiftshader` force `hardware_match` and `representative_pass` false. A dirty
source tree also refuses `representative_pass`. The report keeps every reason.
`performance_budget_pass` remains null: this runner
does not turn route completion into proof that the proposed p95/p99/RAM budgets
were met. A later native-Windows acceptance procedure must evaluate those
thresholds and supply GPU/VRAM evidence from suitable platform tooling.

Example target profile:

```json
{
  "os": {"name": "Windows"},
  "cpu": {"name": "Exact processor string"},
  "gpu": {
    "adapter": "Exact adapter string",
    "driver": ["Exact driver string returned by Godot"]
  },
  "render": {
    "method": "gl_compatibility",
    "display_server": "windows",
    "resolution": [1920, 1080]
  },
  "profile": {"quality_name": "High"}
}
```

Capture the observed metadata from a nonrepresentative smoke first, then author
and review the target file independently. Do not copy an arbitrary run into a
target file and call the same machine representative.

## Commands

Long-form run on the machine being evaluated:

```bash
KETH_BENCHMARK_TARGET_PROFILE=/absolute/path/target.json \
KETH_BENCHMARK_JSON=/absolute/path/result.json \
godot --path /absolute/path/to/repository \
  --script res://tools/performance/benchmark_runner.gd
```

Optional configuration variables are:

- `KETH_BENCHMARK_RESOLUTION=1920x1080`
- `KETH_BENCHMARK_QUALITY_LEVEL=2` (`0` Low, `1` Medium, `2` High)
- `KETH_BENCHMARK_WARMUP_FRAMES=3600`
- `KETH_BENCHMARK_SAMPLE_FRAMES=18000`
- `KETH_BENCHMARK_SMOKE=1` (two warm-up and four sample frames per scenario)

The smoke exists only to check startup, scenario execution, JSON writing,
schema integrity, and bounded live progress. It need not reach the distant
flight endpoint, but both actors must really move and the flight must accept
healthy `ONLINE` propulsion. Its report records
`policy: bounded_progress_smoke`, adds that policy to the nonrepresentative
reasons, and cannot claim `representative_pass` even on matching clean hardware:

```bash
KETH_BENCHMARK_SMOKE=1 \
KETH_BENCHMARK_JSON=/tmp/keth-benchmark-smoke.json \
godot --headless --audio-driver Dummy --path /absolute/path/to/repository \
  --script res://tools/performance/benchmark_runner.gd
```

The focused regression uses an even shorter in-process smoke alongside
mutation-sensitive percentile, metadata, representativeness, and schema
fixtures:

```bash
godot --headless --audio-driver Dummy --path /absolute/path/to/repository \
  --script res://tests/performance_benchmark_runner_test.gd
```

## JSON interpretation

Every report has schema version `1`, source Git SHA and dirty flag, Godot
version, OS/distribution, CPU and logical processor count, GPU adapter/vendor,
driver/API strings, runtime and project render methods, display server,
resolution, visual profile, scenario inputs, startup time, frame percentiles,
engine monitors, RAM, scene counts, and per-scenario start/end/progress evidence.
A dirty record remains useful for local comparison but is not release evidence.
Hardware matching only establishes that the route ran on the declared profile;
it does not replace package identity,
native-Windows review, long-session coverage, GPU timing, VRAM measurement, or
budget evaluation.
