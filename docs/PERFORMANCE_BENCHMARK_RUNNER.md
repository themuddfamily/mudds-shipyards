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
   registered Cinder navigation anchor, waits outside the measured window for
   the production physics binding and coordinator to commit the one real
   streamed NearbySectorCluster generation, then resolves that generation's
   approach-lane point and dock gate. It aims the Torrent at the dock gate and
   drives its `LocalShipInputSource` with forward thrust plus boost for the
   middle half of the route. Missing streaming composition, a failed load, or
   invalid route markers fail staging; there is no unrelated coordinate
   fallback.

The additional **select-only** `halyard_cabin_walk_route` starts a fresh Main
and Begin Shift with the healthy, unpiloted Halyard at its occupied home berth.
It stages the enabled, unseated production player once on the cabin aisle,
waits for floor support and registered moving-interior occupancy, then shuttles
between endpoints derived from the live crew-seat anchors. Camera-yaw steering
and normal forward Input drive every subsequent step; actor transforms are
never written after staging. It records craft-local path and displacement,
movement during sampling, out-and-back visits, and continued floor support,
occupancy, cabin bounds, enabled unseated control, stationary hull and health.
Smoke waits for a physics tick per recorded cabin frame and requires positive
local movement during sampling; full routes retain the normal frame timer and
require both endpoint visits plus at least one aisle length of sampled movement. Idle, blocked, warm-up-only, unsupported or
out-of-cabin runs fail completion.


The select-only `torrent_range_combat_reuse_route` stages the registered
production Torrent 35 metres beyond existing `DRONE-01`, facing back toward
the target from the exterior side. This keeps the station launch SignalMast
behind the target rather than between the camera and target. Staging
settles the production chase arm and translates the ship to align its actual
camera centre ray with the live target's base marker, then requires the same
read-only production reticle collision query to hit that target before timing.
The staging ray/collider and first actual authority-shot status/target remain in
the existing report for diagnosing blocked aim. It retains authored target
motion, health, collision, adapter and Main's `LiveCombatAuthority`. During
recording it offers normal local `fire` Input through the piloted ship, with no
ship, camera or target transform writes. After an authoritative hit actually
destroys the target, it waits one second for presentation, then calls the
existing `ShipyardWorld.reset_range_target_for_reuse`. This deliberately measures
repeated range destruction/reuse load; it does not repeat mission rewards.

Combat progress records production projectile events, accepted authority shots,
matched damage hits, adapter damage events, destructions and successful reuse
counts, separately for the whole route and sampling. Reuse requires the same
target, adapter, authority and registered source identity, and the next adapter
generation. Completion requires actual sampling shots/hits/destruction/reuse
(at least two cycles for a full route, one for smoke), correlated damage events,
continued healthy piloting, and no shot or target-hit gap above ten seconds
including the start and end of sampling. Idle, warm-up-only, unregistered,
unmatched/direct-damage or stalled fire cannot complete. Stationary shooting
uses this combat contract rather than a movement threshold.

Combat smoke alone extends sampling to at least eight elapsed seconds plus its
requested frame quota so unmodified targets can be destroyed and reused through
production combat. Other smoke routes retain their short frame windows. Full
combat selection retains the original 3,600/60-second warm-up and
18,000/600-second sampling floors and remains diagnostic-only. This route covers
one staged range target, not surface combat, an entire journey, native hardware
performance or release qualification.


The select-only `ember_surface_walk_route` stages the production Player once at
Ember's authored caldera pad egress, initially (-5, 0.2, 0.5) metres in the
landing-region frame. The production coordinate frame converts that authored
body coordinate to the initial world position. Main's normal
`PlanetaryJourneyCoordinator.advance_world` observes the real on-foot actor;
its existing Ember streaming binding loads the real `EmberMoonAuthoredScene`,
and `CommonWorldOriginRebaseOwner` commits the required world translation.
Staging requires that committed frame generation, the actual Main-owned
loaded scene, and floor contact with its own `LandingRegion/WalkablePatch`.
There is no standalone surface scene, simulated Host, or manufactured travel,
phase, admission, landing or session state.

The route freezes the same ordered boundaries as
`tests/ember_loop_soak_evidence.gd::_walk_surface_route`: outbound x≤-9,
z≥8, x≥17.5, z≤0.5, x≥41.5; return x≤18.5, z≥8, x≤-9, z≤0.5.
Camera heading maps forward to region +X and right to +Z; the original held
forward/back/left/right actions walk those legs continuously and repeat the
finite path. There are no actor pose or health writes after staging. One
repeat covers about 131 metres at the live player's 5.8 m/s walking speed.

The runner's small surface adapter composes the **existing**
`PlanetarySurfaceGravityPolicy` at Ember's authored 1.62 m/s² reference and
reuses GameFlow's read-only `_network_ember_passenger_gravity` projection helper
without a network session. It applies only the public player gravity multiplier
and restores its original value before Main exits, including failed staging and
abort. Reports label this `gravity_source=production_policy_benchmark_adapter`;
this does not qualify the solo Host's journey gravity binding. Per-physics
observations record actual projected gravity and player multiplier ranges,
player/scene/landing-region/floor identities and generations, held input,
floor support, enabled unseated control, bounded steps, local path and endpoint
visits. Sampling has separate path, observations and endpoint counts. Idle,
warm-up-only, unsupported, wrong-world or discontinuous movement fails.
Full routes require both sampled endpoint visits and at least 100 metres of
sampled walking. Full selection retains the original 3,600/60-second warm-up
and 18,000/600-second sample floors; short smoke requires positive sampled
walking only. Surface staging/loading/settling is outside measurement.

This is a staged planetary walking benchmark only. Outbound travel, landing,
return travel, rewards, endurance, Host journey gravity binding, native hardware
and release qualification remain open. Exercise its independent focused fixture
with `KETH_BENCHMARK_TEST_EMBER_SURFACE=1` in the existing
`tests/performance_benchmark_runner_test.gd` (silent, isolated automation only).
It checks selected smoke/JSON round trip, failure mutations, a 45-second
physical out-and-back primitive, and Escape during sampled walking with gravity
restoration. The original default fixture workload and 300-second cap are
unchanged; this focused mode has its own 300-second supervisor cap.

The select-only `aurora_surface_walk_route` uses that same surface observation,
input guard and gravity restoration machinery. It places the production Player
**once, before timing**, at (-7, 0.2, -17) in Aurora's landing-region frame.
Main's existing streaming binding must load its real `AuroraTemperateAuthoredScene`
and Main must commit an origin rebase; staging fails if that scene's own
`LandingRegion/WalkablePatch` does not support the player. The benchmark does
not construct an expedition, complete a landing, or manufacture journey state.

Main's ordinary solo world cadence observes Ember; Aurora's binding ordinarily
receives actor observations only during an admitted expedition. For this staged
surface selection, the runner explicitly feeds Main's real
`_capture_cinder_actor_sample()` into its existing `aurora_streaming_binding`
once per staging iteration and once per walker physics tick. That production
binding loads and observes the actual scene; the runner never constructs a
surface fixture or calls a scene loader directly. Reports disclose this as
`streaming_cadence=benchmark_adapter_main_owned_binding_real_actor_sample`,
alongside the existing gravity adapter. Main retains common-origin ownership;
normal Main teardown frees the binding and loaded surface. This observation
adapter does not qualify the expedition's admission or travel cadence.

Held forward input follows the existing coastal trail/sign/lookout points from
`tests/aurora_visit_loop_test.gd`: (-7,-17), (8,-17), (20,-7), (25,2), (29,1),
(33,2), (43,-8), (55,-20), (60,-20), (66,-17), then the same points in reverse
(X/Z metres, Y=0). Each leg resolves its world target from the current region
transform on every input tick. Observations use region-local deltas and accept
monotonically committed frame generations, so a common origin translation does
not leave a cached waypoint behind. There are no actor placements during the
warm-up or sample. The adapter configures the existing production gravity
policy with Aurora's world/terrain/frame and 9.8 m/s² reference, using the same
world-aware read-only projection helper as Ember.

Support must be the actual landing patch, a generated terrain collider owned
by that loaded scene's `TerrainClipmap`, or the exact authored
`CoastalExploration/LookoutStep` and `CoastalLookoutDeck` floor colliders. Other
props and floor bodies do not qualify. Full-path validation additionally
requires sampled generated terrain support beyond the patch, sampled lookout
floor support, both sampled endpoint visits, and at least
100 metres of sampled physical walking. The full public selection retains
3,600 frames/60 seconds of warm-up and 18,000 frames/600 seconds of sampling.
A short selected smoke requires positive sampled movement and retains
`representative_pass=false` and `performance_budget_pass=null`.

The independent consolidated fixture mode is
`KETH_BENCHMARK_TEST_AURORA_SURFACE=1`. After importing the clean checkout,
run it headlessly with Dummy audio under an external 300-second supervisor:

```sh
KETH_BENCHMARK_TEST_AURORA_SURFACE=1 timeout 300s godot --headless --audio-driver Dummy --path /path/to/clean/checkout --script res://tests/performance_benchmark_runner_test.gd
```

Use a private test user profile, as with the other benchmark fixtures. This
mode checks selected smoke and JSON round trip, rejection mutations, a focused
45-second sampled physical out-and-back (not full-protocol timing), generated
terrain support, and Escape during sampled walking with original gravity,
inputs and cursor restored. Existing default, combat and Ember fixture modes
remain separate and retain their original 300-second caps. Native performance,
canonical flight/landing/return, rewards, save qualification, the Host journey
gravity binding and human review remain `NOT_RUN` for this staged benchmark.

Omit selection to run both scenarios in the order above. Set
`KETH_BENCHMARK_SCENARIO=station_embodied_route` or
`KETH_BENCHMARK_SCENARIO=nearby_sector_ship_flight_route` or
`KETH_BENCHMARK_SCENARIO=halyard_cabin_walk_route` or
`KETH_BENCHMARK_SCENARIO=torrent_range_combat_reuse_route` or
`KETH_BENCHMARK_SCENARIO=ember_surface_walk_route` or
`KETH_BENCHMARK_SCENARIO=aurora_surface_walk_route` to run only that route.
Unknown names fail before Main instantiation. A selected run keeps the same
per-route timing and progress requirements but is diagnostic-only: its
`configuration.scenario_order` contains only the selected name,
`representative_pass` is always false, and `performance_budget_pass` stays null.
The runner's default `validate_report` and the native benchmark-record gate
still require both routes. Only `validate_selected_diagnostic_report(report,
scenario_name)` accepts the single-route structure, preserving every per-route
check; it cannot grant full-protocol acceptance.

Neither scenario can pass by sampling an idle scene. Each records the actor's
start and end transforms, accumulated path, and maximum displacement. The
station route must show horizontal movement by the real, enabled
`PlayerController`. The flight must observe one command tick where accepted
forward demand and `ONLINE` propulsion agree, actual motion toward the dock-gate
target, and a positive, undestroyed hull throughout. A full flight must enter
the 20 m endpoint radius; the short smoke is explicitly allowed to prove only
bounded positive progress.

Full runs require both 3,600 warm-up frames **and at least 60 elapsed seconds**,
then 18,000 measured frames **and at least 600 elapsed seconds**, per scenario,
at 1920×1080 High. Larger `budgets.warmup_seconds` / `budgets.sample_seconds`
values in the reviewed target extend these windows; smaller values cannot lower
the production floors. Frame overrides below 3,600/18,000 are also clamped
to those floors for full runs, including selected runs. Both phases use `Time.get_ticks_usec()` and record their
actual frame counts and `warmup_elapsed_seconds` / `sample_elapsed_seconds`.
A full run therefore takes at least 22 minutes for two scenarios, plus startup;
low frame rates or larger reviewed budgets can extend it further.

Route segments retain their original order and frame-quota proportions across
warm-up and sampling. Within each phase, route progress follows the slower of
frame-quota progress and elapsed-time progress, so fast frames cannot skip the
movement or boost segments while the time window is still running. Smoke keeps
its tiny frame-only windows and remains nonrepresentative.

After each Main instance applies its saved display settings, the runner reapplies
the requested window size and disables content scaling for a one-to-one render
viewport. Outside timing, it reads the rendered image before and after each
scenario and records `resolution_before` / `resolution_after` with requested,
window, viewport, and actual framebuffer dimensions. Qualification rejects any
mismatch. Headless smoke records its logical viewport and explicitly unavailable
framebuffer; it cannot qualify as a full run. Environment resolution is observed
before the caller's original display is restored.

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
The existing report validator rejects missing, non-finite, or short elapsed
windows, even if the frame quota was met. The native benchmark-record acceptance
consumer independently enforces the same floors and longer target durations.
`performance_budget_pass` remains null: this runner
does not turn route completion into proof that the proposed p95/p99/RAM budgets
were met. A later native-Windows acceptance procedure must evaluate those
thresholds and supply GPU/VRAM evidence from suitable platform tooling.

The repository includes a reviewable template at
`tools/performance/benchmark_target_profile.example.json`. Copy it outside the
repository, replace the identity placeholders with values captured on the
evaluated machine, and preserve the budget fields as the acceptance record's
protocol. The runner compares only the identity fields; the budget values are
intentionally retained for the later native-Windows gate rather than being
silently treated as measured results.

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
godot --audio-driver Dummy --path /absolute/path/to/repository \
  --script res://tools/performance/benchmark_runner.gd
```

Optional configuration variables are:

- `KETH_BENCHMARK_SCENARIO=station_embodied_route` (or another route listed above; omit for the original two)
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
fixtures, each selected route, the default combined run, invalid selection, and
abort/input cleanup, and a focused cabin aisle out-and-back with motion
during sampling. The cabin check uses shortened internal windows for functional
validation; full selected runs still enforce 3,600/18,000 frames and 60/600 seconds:

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

## Native Windows launcher

Run rendered automation on a dedicated test machine or inside an isolated
Windows guest with its viewer closed. Do not launch it on the user's active
desktop without explicit authorization for that desktop run. The benchmark
activates production camera controls; a private user-data directory does not
isolate mouse capture, keyboard focus or the displayed window.

The runner owns an emergency abort independently of the game's pause menu:
physical **Escape**, closing the window or losing window focus cancels the run,
releases injected inputs and returns the cursor. The command-line runner exits
with code `130` and writes no completed benchmark report after cancellation.
This does not prevent production camera code from capturing the cursor during
normal staging; display isolation is still required.

For routine checks, use headless Godot or a private Xvfb display on Linux with
`--display-driver x11` to avoid an inherited Wayland/WSLg desktop connection.
A Windows Hyper-V guest can run headless commands and exchange files through
[PowerShell Direct](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell-direct)
without opening VMConnect. Rendered guest tests need a working guest graphics
backend and an interactive guest session, with the viewer closed during
automation. When using VMConnect interactively, its default host input release
is **Ctrl+Alt+Left Arrow**, followed by moving the pointer outside the viewer;
**Ctrl+Alt+Break** leaves full screen. See
[Microsoft's VMConnect controls](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/virtual-machine-connection).

[Windows Sandbox](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file)
is a disposable alternative with startup commands and configurable GPU sharing.
Guest rendering compatibility must be checked. VM, remote-display and software
rendering measurements do not qualify the physical minimum/target GPU budgets.
Keep `--audio-driver Dummy` in every automated guest invocation as well.

`tools/performance/run_native_windows_benchmark.ps1` launches the existing
runner with Dummy audio, an isolated user-data directory, explicit working
directory, clean Git checks before and after execution, a timeout, and separate
logs. It records the actual CIM CPU/GPU/driver/RAM identity and executable hash,
plus one-second Windows process working-set samples. Optional `nvidia-smi`
before/after snapshots describe **whole-board** usage, not process VRAM or GPU
frame time. Missing GPU timing and process VRAM stay unavailable; the launcher
does not grant budget acceptance.

Use a native Windows checkout on a local drive with Windows Git on PATH.
A WSL worktree's `.git` file contains Linux paths that Windows Git cannot use;
make a normal clone instead. Use the matching portable Windows editor from the
[official Godot 4.7.1 archive](https://godotengine.org/download/archive/4.7.1-stable/).
Extract its ZIP outside the checkout; no installer or service is needed. With
the matching Linux editor installed, prepare resources from WSL (choose unused paths):

```bash
git clone --no-hardlinks /root/mudds-shipyards /mnt/c/Temp/keth-benchmark/source
godot --headless --audio-driver Dummy --editor \
  --path /mnt/c/Temp/keth-benchmark/source --import
```

The installed Windows release template rejects `--path` because it was built
without path overrides; use the portable editor executable for this runner.
A matching native Windows editor can also import the checkout with
`--headless --audio-driver Dummy --editor --path <checkout> --import` first.
Verify the checkout is still clean after import. Do not discard source changes
to force a passing identity check; resolve and commit genuine resource changes,
then prepare a fresh checkout of that revision.

Run in Windows PowerShell, using a new output directory each time. The rendered
full command requires the isolated guest or dedicated machine described above:

```powershell
$launcher = 'C:\Temp\keth-benchmark\source\tools\performance\run_native_windows_benchmark.ps1'
& $launcher -Godot C:\Temp\keth-benchmark\Godot_v4.7.1-stable_win64.exe `
  -Project C:\Temp\keth-benchmark\source `
  -OutputDirectory C:\Temp\keth-benchmark\preflight -PreflightOnly
& $launcher -Godot C:\Temp\keth-benchmark\Godot_v4.7.1-stable_win64.exe `
  -Project C:\Temp\keth-benchmark\source `
  -OutputDirectory C:\Temp\keth-benchmark\smoke -Smoke -Headless
# On the isolated test guest or dedicated machine, after target-profile review:
& $launcher -Godot C:\Temp\keth-benchmark\Godot_v4.7.1-stable_win64.exe `
  -Project C:\Temp\keth-benchmark\source `
  -OutputDirectory C:\Temp\keth-benchmark\full `
  -TargetProfile C:\Temp\keth-benchmark\target.json
```

Pass `-Scenario station_embodied_route` or
`-Scenario nearby_sector_ship_flight_route` or
`-Scenario halyard_cabin_walk_route` to the launcher for one diagnostic
route; omitting it runs both. The launcher validates the name, records it in
`invocation.json`, forwards it through `KETH_BENCHMARK_SCENARIO`, and clears any
inherited selection before setting its own. It restores the caller's selection
alongside the other benchmark environment variables after execution.

`-Smoke -Headless` is a readiness check that needs no rendered window. Headless
full runs are rejected. `-PreflightOnly` records hardware and checks the clean
source without launching Godot. The launcher removes inherited benchmark
protocol overrides for its child and restores the caller's environment after
execution; full runs use the documented runner defaults.

Review `benchmark.json` scenario completion, recorded phase durations, and frame
percentiles together with `process-summary.json`, logs, and the copied target
profile. The default full runner now enforces the target template's 60-second
warm-up / 600-second sampling floors alongside its frame minima. Process peak sampling covers
startup and both scenarios and is separate from Godot's static-memory monitor.
GPU frame-time tooling and per-process dedicated VRAM collection remain separate
requirements for complete acceptance.

A Windows 11 / i9-14900 / RTX 5070 Ti host is useful for an explicitly declared
observational profile. Results on that host do **not** validate the published
minimum specification or RTX 3060 target. Native normal-control playthroughs and
audible review are separate human gates and remain `NOT_RUN` until performed.


The existing test file has a separate combat fixture to preserve the original
suite's 300-second cap. In a clean imported checkout run silently/headlessly:

```sh
KETH_BENCHMARK_TEST_COMBAT=1 timeout 300 godot --headless --audio-driver Dummy --path . --script res://tests/performance_benchmark_runner_test.gd
```

This runs an actual selected combat smoke, focused invalid-progress mutations,
and Escape during active production fire. Omit that environment variable to run
the original default/flight/cabin fixture. Rendered checks require an isolated
display and explicit `--display-driver x11` under Xvfb.
