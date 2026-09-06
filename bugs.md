# Bug ledger

This ledger contains only unresolved or explicitly accepted issues. Fixed and closed records are removed once their fixes are verified.

## Code review — 2026-09-06

Reviewed source: `aceff1619`. The remaining findings below are **OPEN**; verified
fixes are removed as they are committed. P1 means a major feature or gameplay path is broken; P2 means
an actionable correctness defect; P3 means a bounded lifecycle or robustness
defect. The existing accepted `RENDER-001` record remains below.

Scope: flight/boarding/combat, world activities/streaming, network transport,
startup/settings/persistence, and executable packaging/test runners. Findings
distinguish production behavior from defects reproduced through component APIs.
This is a bounded source review with focused execution, not a claim that every
bug has been found. Native Windows, physical controllers, representative GPU
performance, and human visual review were **NOT_RUN** in this review.

### FLIGHT-001 — Automatic engine idle makes coasting collisions harmless — P1

- **Location:** [`HeroShip._physics_process()`](scripts/ships/hero_ship.gd#L565).
- **Trigger:** Accelerate above the 45 m/s impact threshold, release controls for
  more than 1.5 seconds, then coast into station geometry.
- **Expected / actual:** Impact damage should depend on the collision. The
  automatically offline ship instead retains its hull: its movement branch
  calls `move_and_slide()` without `_apply_collision_damage()`. Powered flight
  does apply that damage.
- **Verified:** Two real Torrent instances started 200 m along Z at 80 m/s toward
  identical static walls. After 250 physics ticks, the naturally idled ship had
  hull **100.0**, while the comparison ship kept online had **2.144094**. Both
  reached the same relative contact position and reported one slide collision.
- **Repair:** Apply collision consequences after coasting movement as well as
  powered movement, preserving landing rules, cooldowns, and destruction guards.

### DISPLAY-001 — Display rollback countdown freezes in the settings menu — P2

- **Locations:** [`GameFlow._process()`](scripts/game/game_flow.gd#L2723),
  [`_update_display_confirmation()`](scripts/game/game_flow.gd#L15830),
  [`GameHUD.set_paused()`](scripts/ui/hud.gd#L2389).
- **Reproduce:** Open Pause → Settings, change resolution/window mode, and leave
  the displayed 15-second confirmation unanswered.
- **Expected / actual:** The display automatically reverts after 15 seconds.
  Instead, opening the menu pauses the SceneTree, and GameFlow inherits the
  pausable process mode. Its countdown does not advance until gameplay resumes.
  A player who cannot use the new display cannot rely on automatic recovery.
- **Verified:** In the production Main scene under Xvfb, after changing
  1920×1080 to 1280×720, `paused=true`, `game.can_process()=false`, and the pending
  countdown remained exactly **15.0** across an independent 0.5-second timer.
- **Repair:** Run only display confirmation timing in an owner that processes
  while paused; do not enable gameplay simulation during pause.

### DISPLAY-002 — Other settings save an unconfirmed display change — P2

- **Locations:** [`_on_setting_change_requested()`](scripts/game/game_flow.gd#L15822),
  [`_on_settings_save_requested()`](scripts/game/game_flow.gd#L16105),
  [`_revert_display_settings()`](scripts/game/game_flow.gd#L15864).
- **Reproduce:** Preview another resolution, then adjust Master volume or press
  Apply + Save before pressing Keep Display. Press Revert Display and restart.
- **Expected / actual:** An unconfirmed display choice must remain transient.
  Ordinary settings saves serialize the entire live settings object, including
  the pending resolution. Revert changes only runtime state, so the rejected
  resolution returns on the next launch.
- **Verified:** With the production Main scene and an injected in-memory store,
  changing volume during a 1280×720 preview saved **1280×720** while confirmation
  remained pending. After Revert, runtime was **1920×1080** but a fresh settings
  adapter still loaded **1280×720** from the store.
- **Repair:** Persist the last confirmed display fields during unrelated saves,
  or isolate display preview state until Keep commits it.

### DISPLAY-003 — A second preview replaces the rollback baseline — P2

- **Location:** [`_on_setting_change_requested()`](scripts/game/game_flow.gd#L15809).
- **Reproduce:** From confirmed 1920×1080, preview 1280×720; without confirming,
  preview 2560×1440, then press Revert.
- **Expected / actual:** Revert should restore the last confirmed 1920×1080.
  Each new preview replaces `prior` with the current, still-unconfirmed settings,
  so the result is **1280×720**. The settings controls remain available during
  confirmation.
- **Verified:** The production Main display probe returned 1280×720 after this
  exact sequence, with 1920×1080 as the original baseline.
- **Repair:** Keep one confirmed baseline for the whole preview transaction;
  subsequent changes should update only its candidate and deadline.

### NET-001 — Late joiners never apply canonical state snapshots — P1

- **Locations:** [`NetworkENetSessionAdapter`](scripts/network/network_enet_session_adapter.gd#L3361),
  [`_broadcast_snapshot_fragment()`](scripts/network/network_enet_session_adapter.gd#L3815),
  [`NetworkSnapshotJitterBuffer`](scripts/network/network_snapshot_jitter_buffer.gd#L65).
- **Reproduce:** Have the server publish revision 1 before a client joins, admit
  the client, then publish revisions 2–27 through the real ENet adapter.
- **Expected / actual:** The new client should initialize from current authority
  and receive subsequent updates. Initial deltas lack a decoder baseline. Even
  when periodic full revision 9 arrives, the jitter buffer still waits for
  revision 1, which will never arrive.
- **Verified:** A real ENet late-join fixture admitted the client but applied
  **zero snapshots**. Its cursor remained `next_revision=1`; pending revisions
  `[9..24]` exhausted the 16-packet buffer.
- **Impact:** This path carries production canonical ship telemetry and
  projectile snapshots. Direct replica tests bypass the broken transport path.
- **Repair:** Bootstrap each newly admitted peer with a full authoritative
  snapshot and initialize its ordering cursor to that baseline.

### NET-002 — Independent snapshot streams share one ordering cursor — P1

- **Locations:** [`consume_moving_interior_snapshot()`](scripts/network/network_enet_session_adapter.gd#L2550),
  [`_broadcast_snapshot_fragment()`](scripts/network/network_enet_session_adapter.gd#L3820).
- **Reproduce:** Deliver canonical revision 1 and then a valid moving-interior
  revision 1 to a client through the adapter's production receive paths.
- **Expected / actual:** Both independent sequences should accept their first
  packet. Both use `_snapshot_jitter`, so canonical delivery consumes revision 1
  and the interior packet is rejected as `stale_or_duplicate`. Buffered packets
  can also be released into the other stream's parser.
- **Verified:** The fragment callback applied canonical revision **1**; the
  following valid interior packet returned **`stale_or_duplicate`**.
- **Impact:** GameFlow publishes both streams in production, including walking
  inside moving craft and canonical telemetry/projectile updates.
- **Repair:** Give each stream its own jitter buffer, lifecycle resets, and
  resynchronization cursor.

### PACKAGE-001 — Distribution contains the wrong Python installer — P2

- **Location:** [`assemble_distribution()`](tools/package/windows_distribution_assembler.py#L153).
- **Reproduce:** Assemble a distribution and run
  `python3 <distribution>/install/windows_portable_installer.py --help`.
- **Expected / actual:** The packaged installer should start and display help.
  The assembler copies `Path(__file__)`—itself—under the installer's filename.
  Execution fails before argument parsing with a circular
  `ImportError: cannot import name 'LAUNCHER_NAME'`.
- **Verified:** Real assembly of fixture package inputs, followed by execution
  of the packaged file, exited **1**. Existing tests checked that the file
  existed, so they passed. The separate PowerShell installer is unaffected by
  this finding.
- **Repair:** Copy the actual sibling `windows_portable_installer.py` and
  exercise the assembled file in the existing packaging test.

### PACKAGE-002 — Progress exporter publishes source changed during export — P2

- **Locations:** [`export_and_assemble()` preflight](tools/package/export_windows_progress_build.py#L83),
  [publication](tools/package/export_windows_progress_build.py#L118).
- **Reproduce:** Start a clean progress export, then edit tracked source or
  change HEAD while Godot is exporting.
- **Expected / actual:** Publication should reject a changed source identity.
  Cleanliness and HEAD are checked only before the export. The archive can
  contain changed content while its name/manifest still claim the original
  commit.
- **Verified:** In an isolated Git fixture, an injected export runner changed
  tracked `project.godot` and produced an EXE fixture. The real assembler and
  archive verifier still published successfully under the original HEAD.
  This verifies the publication guard defect, not a native Windows export.
- **Repair:** Recheck tracked content and HEAD before assembly and publication,
  or export from an immutable isolated checkout. The separate shell candidate
  exporter already performs repeated source checks.

### TEST-001 — Legacy matrix reports failing process exits as success — P2

- **Location:** [`tools/release/run_matrix.sh`](tools/release/run_matrix.sh#L51).
- **Reproduce:** Run this runner against a fixture suite whose Godot command
  prints `PROBE_TEST_OK` and exits **7**.
- **Expected / actual:** The result must retain exit 7 and fail the matrix.
  Inside `if ! timeout ...`, `$?` is the successful negation's status, so the
  runner records **0**. With one sentinel and no diagnostics, it prints
  `MATRIX_OK` and exits **0**.
- **Verified:** An unchanged copy of the runner in an isolated one-suite Git
  fixture produced exactly that false pass.
- **Scope / repair:** This affects legacy `run_matrix.sh`, not the maintained
  `run_test_matrix.sh`. Retire/delegate the legacy runner or capture the actual
  child exit status without negating it first.

### TEST-002 — Legacy matrix source guard hashes the same filename list twice — P2

- **Locations:** [`manifest capture`](tools/release/run_matrix.sh#L35),
  [`post-run comparison`](tools/release/run_matrix.sh#L96).
- **Reproduce:** Run the legacy matrix while its fixture Godot command rewrites
  a tracked suite.
- **Expected / actual:** A source change should invalidate the run. The runner
  hashes a saved `git ls-files` list before execution and hashes the exact same
  unchanged list afterward; it never compares source bytes or refreshes the
  tracked-file inventory. It reports `manifest_unchanged=true` and `MATRIX_OK`.
- **Verified:** An isolated fixture retained both the modified tracked suite
  and the successful matrix result after execution.
- **Scope / repair:** This affects `run_matrix.sh`. Delegate to the maintained
  runner's content checks instead of preserving another acceptance path.

### TEST-003 — Settings regression expects an obsolete accessibility descriptor — P2

- **Location:** [`tests/runtime_settings_test.gd`](tests/runtime_settings_test.gd#L62).
- **Reproduce:** Run
  `godot --headless --path . --script tests/runtime_settings_test.gd`.
- **Expected / actual:** The default-settings regression should agree with the
  supported accessibility preferences. Its exact dictionary comparison omits
  `reduced_flash` and `payload_visual_intensity`, both returned by the production
  descriptor and exposed by the settings UI. It therefore fails on current
  defaults, blocking the maintained release matrix.
- **Verified:** The focused matrix recorded exit **1**, 136 passing assertions,
  and `FAIL: the accessibility descriptor exposes the five presentation presets`.
- **Repair:** Update the existing expected contract to cover the supported
  fields and defaults; preserve the runtime preferences.

### TEST-004 — Passing display HUD suite lacks the required success marker — P2

- **Location:** [`tests/display_settings_hud_integration_test.gd`](tests/display_settings_hud_integration_test.gd#L57).
- **Reproduce:** Run
  `tools/run_affected_suites.sh display_settings_hud_integration_test`.
- **Expected / actual:** A passing suite should emit the maintained runner's
  required terminal success marker. It prints only
  `display_settings_hud_integration_test: 16 assertions`, so the runner rejects
  it with `sentinel_count=0` and `no_sentinel_found`.
- **Verified:** All **16 assertions** completed, exit was **0**, and diagnostics
  were **0**, but the maintained matrix correctly reported **FAIL** because the
  suite did not meet its output contract.
- **Repair:** Emit the suite-specific `_OK` or `_PASS` marker only on successful
  completion, retaining a nonzero exit and failure output otherwise.

### WORLD-001 — Normal survey movement fails the entire Ember journey — P1

- **Locations:** [`_forward_active_relay_position()`](scripts/world/ember_surface_loop_production_binding.gd#L2394),
  [scheduler failure handling](scripts/world/ember_surface_loop_production_binding.gd#L2269).
- **Reproduce:** Reach Ember's on-foot phase and start Relay Survey away from
  its next checkpoint. Alternatively, reach the first checkpoint and remain
  there for another physics tick.
- **Expected / actual:** The survey should remain active while the player walks
  toward the next checkpoint. The route's ordinary `outside_checkpoint` result
  is converted to `relay_position_forward_rejected`, which moves the production
  scheduler into `FAILED` and stops subsequent journey advancement.
- **Verified:** A temporary extension of the real scheduler integration fixture
  passed 31 startup, landing, and walking checks. Survey start returned
  `activity_sequence_started`; the next real physics tick produced **state 4
  (`FAILED`)** and **`relay_position_forward_rejected`**. Separately, real
  surface/director components accepted checkpoint one and returned
  `outside_checkpoint` for the next stationary sample, which the forwarder
  converted to the same fatal error.
- **Repair:** Treat valid observations outside a checkpoint as no progress;
  reserve terminal failure for invalid identity/lifecycle conditions.

### WORLD-002 — Rebased player positions use the wrong survey/hazard frame — P1

- **Locations:** [`survey forwarding`](scripts/world/ember_surface_loop_production_binding.gd#L2387),
  [`hazard forwarding`](scripts/world/ember_surface_loop_production_binding.gd#L2422),
  [`authored checkpoints`](scripts/world/ember_planetary_surface_production_binding.gd#L1017).
- **Trigger:** Visit Ember after CommonWorldOrigin rebases the world.
- **Expected / actual:** The shared actor position should be converted into
  body-local coordinates before comparing it with authored survey/hazard
  geometry. The sample is checked against `actor.global_position`, then passed
  unchanged to the body-local survey API and labeled `position_body_local_m`
  for hazards. The authored coordinates retain their original frame.
- **Verified:** In the actual rebased scheduler fixture, player world position
  was `(41.5498, -59.96806, -290.4699)` and the surface bootstrap was
  `(0, -120060, -290.2366)`. The first checkpoint remains
  `(180, 120009, -44)` body-local; its rendered world position is approximately
  `(180, -51, -334.2366)`, which the unchanged forwarding cannot match. Both
  forwarding and comparison paths were traced in production source.
- **Impact / limit:** Survey progress and hazard exposure use incorrect
  positions. The hazard was not separately traversed in this review. This
  coordinate defect remains even after fixing `WORLD-001`.
- **Repair:** Convert the admitted world sample through the current body frame
  once, retain the coordinate generation, and use it for both consumers.

### WORLD-003 — Detached streaming completion strands a pending load — P2

- **Locations:** [`WorldStreamingCoordinator.complete_load()`](scripts/world/world_streaming_coordinator.gd#L190),
  [`distance-policy load decisions`](scripts/world/world_streaming_distance_policy.gd#L260).
- **Reproduce:** Request a bound scene, detach the coordinator's parent before
  deferred completion, allow that callback to execute, then reattach the parent
  while remaining inside the load radius.
- **Expected / actual:** Reentry should resume the completion or retire and
  retry the request. Completion returns `coordinator_unavailable` but retains
  `_loading`. The distance policy sees a pending load and never requests another.
- **Verified:** With the built-in deferred loader, real coordinator/policy, and
  Cinder definition, three updates after reentry each reported
  `attempted_count=0`, `loading=["cinder_reach"]`, and `loaded=[]`.
- **Scope:** Confirmed supported detach/reentry lifecycle defect, not tied to
  a demonstrated player menu action. Explicit unload/reload, or moving beyond
  the unload radius, provides a workaround.
- **Repair:** Preserve deferred completions safely across detachment or retire
  lost requests so ordinary reentry policy can retry.

### ACTIVITY-001 — Nonfinite positions complete checkpoint routes — P2

- **Location:** [`CheckpointRouteActivity.submit_position()`](scripts/activities/checkpoint_route_activity.gd#L54).
- **Reproduce:** Start the real Cinder route/race and submit
  `Vector3(NAN, 0, 0)` once per checkpoint through its public API.
- **Expected / actual:** Reject nonfinite coordinates without changing progress.
  `NaN > checkpoint_radius` evaluates false, so every sample counts as reaching
  the next checkpoint.
- **Verified:** With the actual ActivityDirector, Cinder route, and
  `CinderTimedRaceSession.new(1, 0.0, 120.0)`, five NaN samples all returned
  `checkpoint_reached`. The race finished with **0-second last and best times**.
- **Scope:** Public API validation defect. No ordinary player action producing
  NaN was demonstrated; upstream actor sampling can reject it.
- **Repair:** Require finite positions at the route authority boundary before
  performing distance comparisons.

### ACTIVITY-002 — Checkpoint callback failure is overwritten by completion — P2

- **Location:** [`CheckpointRouteActivity.submit_position()`](scripts/activities/checkpoint_route_activity.gd#L59).
- **Reproduce:** Connect a `checkpoint_reached` observer that calls
  `fail(&"actor_lost", generation)` on the final checkpoint, then reach it.
- **Expected / actual:** Either reject nested lifecycle mutation or retain the
  accepted failure and emit one terminal outcome. `fail()` succeeds and emits
  `failed`, but the outer call then sets `COMPLETED` and emits `completed`.
- **Verified:** A valid one-checkpoint route emitted `failed`, returned true from
  the callback's `fail()`, then emitted `completed`. Its final snapshot combined
  **state 2 (`COMPLETED`)** with **`failure_reason=actor_lost`**, an invalid
  combination for its persistence validator.
- **Scope:** Confirmed synchronous observer/API defect; an ordinary production
  observer causing this exact callback was not demonstrated.
- **Repair:** Guard lifecycle reentrancy or revalidate state/generation after
  emitting the checkpoint signal before committing completion.

### AUDIO-001 — Boarding cue producer is lost after scene reentry — P3

- **Location:** [`ShipBoardingArea` lifecycle](scripts/interaction/ship_boarding_area.gd#L46).
- **Reproduce:** Add a boarding area, remove its ship/parent from the tree, then
  readd the same instance.
- **Expected / actual:** Reentry should restore the cue binding alongside
  availability. `_exit_tree()` clears `_audio_binding`; initialized
  `_enter_tree()` restores only availability, and `_ready()` is not rerun.
- **Verified:** The initial binding existed; after reentry, availability was
  **true** and `get_audio_binding()` was **null**.
- **Scope:** Confirmed loss of the semantic cue producer. No production consumer
  of its getter was found; missing audible playback was not demonstrated.
- **Repair:** Restore the binding during initialized reentry.

### AUDIO-002 — Boarding cue slots become a permanent priority lockout — P3

- **Location:** [`BoardingSeatAudioBinding._admit()`](scripts/audio/boarding_seat_audio_binding.gd#L133).
- **Reproduce:** Reserve and release one boarding point three times without
  detaching it.
- **Expected / actual:** Every independent cycle should emit reserve, start,
  and release cues. The two supposedly simultaneous voice slots never expire.
  Release priority 60 eventually fills both slots, permanently rejecting reserve
  priority 45 and boarding-start priority 55.
- **Verified:** Successive cycles emitted **3, 2, then 1** semantic cues.
- **Scope:** Confirmed event suppression, with the same audible-playback
  qualification as `AUDIO-001`.
- **Repair:** Retire slots when playback completes or expires, so a concurrency
  limit does not become a lifetime priority threshold.

### Review validation

- Godot `4.7.1.stable.official.a13da4feb`; headless component/physics and real
  ENet fixtures, plus production display transactions under Xvfb with 3D drawing
  disabled and isolated user data. Display probes used Compatibility/llvmpipe;
  they do not qualify the production Forward+ visuals.
- 31 focused Python packaging/release tests passed, as did
  `tools/release/test_run_test_matrix_canonical.sh`.
- Existing production settings persistence, activity director, and streaming
  coordinator suites passed (34, 33, and 85 assertions respectively).
- Existing network adapter integration failed three movement assertions;
  existing runtime settings regression failed its descriptor assertion; the
  display HUD test passed its assertions but failed the runner's output contract.
  These are recorded above, not presented as a clean test run.
- Temporary reproduction scripts/fixtures were used for the additional
  findings. The full test matrix and native Windows package execution were not
  run; production code and existing tests were not modified.

## RENDER-001 — Seven `Texture` RIDs leak at `RenderingDevice::finalize()` on every rendered run — **ACCEPTED_RISK**

- Status: `ACCEPTED_RISK`. Severity: **P3**. Disposition: **accepted, engine-side, no code
  change** — see "Rationale for accepting" below.
- Reporter: package-build agent, 2026-08-15, from the native-Windows execution recorded in
  [`docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md`](docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md).
  Investigated and adjudicated 2026-08-15; recorded here 2026-08-16.
- Owner: **none required on this side.** Tracked upstream in
  [godotengine/godot#122498](https://github.com/godotengine/godot/issues/122498).
- Affected loop beat: **none.** It occurs only during process teardown, after every beat
  (begin shift, walk, board, start, launch, fly, fire, return, land, shut down, disembark)
  has already completed. No player-observable behaviour is involved at any beat.
- First affected source: unknown — the warning predates the records that name it, and both
  earlier ROADMAP mentions misattributed it (see below), so no first-bad commit was
  bisected. Last confirmed affected source: `e57d207` (this worktree's `main`), reproduced
  today. The package-build observation was on `ef5450c`.
- Affected artifact hashes: Windows GUI EXE `gateE-20260815-ef5450c`, SHA-256
  `2325f175e336c70bda247ccba3d4617867fad19c962772d09928e7f9fb929583`, 153,713,144 bytes,
  PE version `0.12.0.0`, embedded PCK sorted-path manifest SHA-256
  `dc0800edfdf7a553d98e8b398d493461ef7e9eaa7dd1f309debb9466fde34684`.
- Nearest owning source in this repo (**not** the defect):
  `scripts/world/shipyard_world.gd` (SHA-256
  `76b58bde7e53ff670b7ffdb5883fa808be344524e2253ee069cb7c720d6b3821`),
  `_build_central_reflection_probe()` at `:2638`, called from `:2356` via `_ready()`.
  It builds `CentralBerthReflectionProbe`, `update_mode = UPDATE_ONCE`, the only
  `ReflectionProbe` in the project.

### Current verification — 2026-09-06

Still reproduced on Godot `4.7.1.stable.official.a13da4feb` at source
`eb7416a8f`: a temporary empty project containing a camera, box mesh, and stock
`ReflectionProbe` rendered for 30 frames using Forward+ on llvmpipe, exited `0`,
and reported seven leaked Texture RIDs. The identical project with the probe
removed exited `0` without the warning. This remains an engine-side accepted
risk, not a confirmed fix. The completed native Windows RTX 5070 Ti and
Linux llvmpipe hero-cell captures also reported the same seven shutdown RIDs.

The dated source descriptions in this record are historical: the current world builds the
central probe plus four module probes. The default scene is now `scenes/boot.tscn`;
a default-scene run must enter the shipyard before it exercises these probes.

### Upstream repair candidate — checked 2026-09-06

[godotengine/godot#122498](https://github.com/godotengine/godot/issues/122498),
opened 2026-08-17, now reports this exact seven-Texture-RID leak on the same
`4.7.1.stable.official.a13da4feb` engine. It identifies missing cleanup of the
reflection atlas's six color views and color buffer and proposes freeing them
and their framebuffers in `LightStorage::_reflection_atlas_clear()`.

The official `4.7.1-stable` source was inspected independently: these resources
are allocated but omitted from that cleanup function. The issue is still open,
with no linked pull request or milestone; no released repair was found in the
bounded upstream review. The proposed patch is **not build- or runtime-verified
here** and does not close this record.

Using that patch locally would require building and qualifying a custom Godot
editor and matching Windows export templates. Selecting a patched editor with
`GODOT_BIN` alone would not fix the shipped executable: the current export
preset still selects the stock templates.

**User decision — 2026-09-06: keep official Godot.** Continue using official
Godot releases and matching official Windows export templates. Retain
`RENDER-001` as an accepted risk until a fixed official release is qualified.
This resolves the dependency choice for the bug review: this entry is an
explicitly accepted exception, not a verified fix, and remains in the ledger.

### Environment — two documented configurations, identical result

| | Configuration A (native Windows) | Configuration B (this box) |
| --- | --- | --- |
| OS | Windows 11 `10.0.26200.9168` | WSL2 Linux `6.18.33.2-microsoft-standard-WSL2` |
| CPU | Intel Core i9-14900 (32 threads) | same host, 32 threads |
| RAM | 94 GiB usable, 24 GiB swap | 94 GiB usable |
| GPU / driver | NVIDIA GeForce RTX 5070 Ti, Vulkan 1.4.341 | no `/dev/dri`; lavapipe `llvmpipe (LLVM 20.1.2, 256 bits)`, Vulkan 1.4.318 |
| Renderer profile | Forward+ | Forward+ **and** Forward Mobile, both tested |
| Display driver | as recorded: `--headless --quit-after 300` (see note) | `x11` under `xvfb-run` |
| Audio | `Dummy` | `Dummy` |
| Input | none (headless) | none (headless / scripted) |
| Resolution | default | 1280×720, 1920×1080 and 2560×1440 all tested |
| User data | clean | clean |
| Godot | 4.7.1.stable.official.a13da4feb | 4.7.1.stable.official.a13da4feb |

The count is **7 on both**, which is itself load-bearing evidence: it is neither an
llvmpipe artifact nor GPU-specific.

**Note on configuration A, unresolved:** the recorded native-Windows invocation passes
`--headless`, yet its banner reads `Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA -
NVIDIA GeForce RTX 5070 Ti` and it leaks 7. On Linux, `--headless` creates no rendering
device and leaks 0, which is the whole reason the matrix cannot see this. Whether the
exported Windows template treats the flag differently, or the flag was ineffective in that
interop invocation, was **not** determined. It does not affect the verdict — configuration
B reproduces the leak with an unambiguously real rendering device — but it should not be
read as "`--headless` opens a rendering device", because that is not established.

### Steps

1. Ensure `.godot/` exists: `godot --headless --path . --editor --quit`.
2. Run the shipped main scene with a real rendering device and no harness:
   `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --display-driver x11
   --rendering-driver vulkan --audio-driver Dummy --quit-after 300`.
3. Read the last two lines of stderr.
4. Repeat with `--quit-after 900`, and with `--rendering-method mobile`.

### Expected / actual

- **Expected:** the process exits `0` with no `Leaked` diagnostic. The playable-prototype
  gate in [`ROADMAP.md`](ROADMAP.md) names "resource-leak" diagnostics explicitly.
- **Actual:** exit `0`, and always:

  ```
  WARNING: 7 RIDs of type "Texture" were leaked.
     at: finalize (servers/rendering/rendering_device.cpp:8900)
  ```

### Failure frequency

Deterministic — but stated precisely rather than as a "10/10", because no single scenario
was run ten times. **Every** rendered run in the investigation's tables and every rendered
run performed for this record produced exactly 7, and no rendered run has ever produced a
different non-zero count: 7 at 20, 300 and 900 frames; 7 on Forward+ and on Forward
Mobile; 7 on llvmpipe and on the RTX 5070 Ti; 7 with one `ReflectionProbe` and 7 with
four; 7 from four different capture harnesses that load `ShipyardWorld`. Runs that never
render `ShipyardWorld`, and every `--headless` Linux run, produce 0. It was observed again
unprompted in today's `tests/capture_hero_cell.gd` verification runs for the now-closed CAPTURE-001
— an independent sighting on `e57d207`.

### Root cause — engine-side, proven by an empty-project reproduction

Full investigation, including the bisection table and the ruled-out candidates:
[`docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md`](docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md)
(SHA-256 `d130a8229157344a6ff1604fd887763b98cb8a1b1e69a40d82530464c94fc344`).

A ~70-line project containing only a `Camera3D`, a `MeshInstance3D` and **one stock
`ReflectionProbe`** leaks all seven. Three facts settle the attribution:

1. **No project content is involved.** `WorldEnvironment`, `BG_SKY`,
   `ProceduralSkyMaterial`, glow, and a shadow-casting `DirectionalLight3D` were each
   tested individually in that empty project and leak **0**. Adding the probe alone takes
   it to 7.
2. **The count does not scale with probe count.** One probe and four probes both leak
   exactly 7, so this is a single shared reflection atlas allocated on first use, not a
   per-probe resource. That also explains the stable "7" across unrelated scenes,
   harnesses, GPUs and drivers.
3. **Freeing the probe does not clear it.** Removing and `free()`-ing the probe ten frames
   before shutdown and rendering ten more frames still leaks 7. There is therefore no
   teardown any game code could add.

`Node.print_orphan_nodes()` printed nothing in every run — no `Node`s leak. The repo has
no `static var`s, no runtime `ImageTexture`/`NoiseTexture2D`/`GradientTexture`
construction in `scripts/`, no `SubViewport`/`ViewportTexture` outside `tests/`, and one
read-only `RenderingServer` call
(`scripts/rendering/visual_quality_controller.gd:119`). The one `const Texture2D`
cache — `scripts/effects/pulse_weapon_presentation.gd:39` — was suspected and cleared
twice independently.

Upstream references for the same class (RD-level RIDs surviving
`RenderingDevice::finalize()` in trivial projects): godotengine/godot
[#89182](https://github.com/godotengine/godot/issues/89182),
[#73577](https://github.com/godotengine/godot/issues/73577). At the original investigation date, no upstream issue naming
`ReflectionProbe` specifically was located. The matching issue found on
2026-09-06 is linked above.

### Rationale for accepting

- It is **bounded and fixed**: seven RIDs, once, at `finalize()`, immediately before the
  process exits and the OS reclaims everything. It does not grow with frame count, does
  not grow with probe count, and cannot reach a long-running session because it happens
  only during teardown.
- **No application-side repair exists.** Fact 3 above rules out teardown ordering. The
  only remaining levers are deleting `CentralBerthReflectionProbe` — a real visual
  regression to the central berth's hero lighting, traded for suppressing a cosmetic
  engine message — or suppressing the warning. Both are papering over.
- Two earlier characterisations were **wrong in their reasoning** and are corrected here:
  `ROADMAP.md` called it "the known seven-Texture-RID **llvmpipe** shutdown warning" and
  "the known seven-Texture-RID **capture** warning". It occurs identically on an RTX
  5070 Ti under a real NVIDIA driver, and it occurs in the shipped game running its own
  main scene with no harness. The severity call was right; the attribution was not, which
  is exactly why it kept resurfacing as an unowned finding.

### Known limits of this record

- The seven RD textures were **not individually named.** Godot 4.7.1 stable reports only a
  count; per-RID tracking is `RID_HANDLE_ALLOC_TRACKING_DEBUG`, a debug-build feature not
  compiled into the stable binary used here. "A shared reflection atlas" is inferred from
  the count's invariance to probe count, not read out of the engine.
- The **"0 after removing the probe" figure was measured only under lavapipe**, not
  re-measured natively on the RTX 5070 Ti. The unmodified count (7) does match the Windows
  record exactly.
- This collides with the literal wording of the playable-prototype gate ("no ...
  resource-leak ... diagnostics"). That gate wording needs an explicit carve-out for this
  shutdown warning, or every future rendered candidate run will re-open the same
  adjudication. Recorded, not silently absorbed.

### Linked reproducer / regression

**None, deliberately.** The bisection probe (`tests/zz_leak_probe.gd`) and the empty
comparison project were not committed: `tests/` is matrix-scanned and a permanent
regression asserting "the engine still leaks 7" would fail the moment upstream fixes it,
which is the wrong direction for a gate. The reproduction is the four numbered steps
above plus the empty-project recipe at the end of the investigation document. The headless
matrix structurally cannot see this — `--headless` creates no rendering device — which is
why `tools/release/run_test_matrix.sh` stays clean and is not a regression on it.
