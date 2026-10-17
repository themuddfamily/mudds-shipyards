# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest playable: **b6af782**, with [Windows build notes](builds/windows/MuddsShipyards-b6af782-notes.txt)
and [Linux build notes](builds/linux/MuddsShipyards-b6af782-linux-notes.txt).
The browser Disconnect improvement is playable there. Later benchmark/test-only
changes do not require a new gameplay checkpoint. Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Rules that prevent loops

- Select one named delivery with one observable outcome. Split implementation
  expected to exceed 30–120 minutes before starting; estimate check time separately.
- Write the affected component, exact acceptance, source/build, owner and next
  action before execution. At handoff, resume that action instead of rediscovering it.
- Use at most three steps: implement, verify, package/close. A passing check ends
  its step. Repeat only after a relevant change or a specific unresolved concern.
- Stop at the first concrete failure. Record the defect, unchanged acceptance,
  remaining action and revised estimate before scheduling its bounded repair.
  One diagnostic hypothesis permits one probe, not an unlimited investigation.
- At the estimate boundary, record done/failed/waiting and remaining work. Do not
  silently extend scope, lower physical criteria or shorten required test durations.
- Close by recording the actual result, committing/pushing, and removing owned
  disposable clean worktrees/scratch. Preserve unique work and raw failures.
- Schedule only the next 3–5 concrete deliveries when their contracts are known.
  Uninstantiated backlog templates are not scheduled work or measurable progress.

## Active delivery: E2 · Ember surface walking benchmark

**Outcome:** the existing runner can select a real, supported Ember surface
walk with ordinary movement and honest partial reports. This provides a runnable
benchmark scenario; it does not qualify a canonical journey or native performance.

**Owner/component:** root integrates `ember_surface_benchmark`; existing runner,
Windows wrapper, runner test and usage document only. Parent: performance §5.
**Last completed:** implementation/review committed at `00ffaa045`.
**Remaining:** one delivery, with the three sequential steps below. Full-project
remaining tasks cannot yet be counted: backlog templates still require named instances.

| Step | State | Pass/fail and stopping point | Remaining estimate |
| --- | --- | --- | --- |
| E2.1 · Preserve existing routes | READY | On clean `00ffaa045`, run existing runner test in default and combat modes, each at original 300s cap. Require exit 0, `PERFORMANCE_BENCHMARK_RUNNER_TEST_OK`, no diagnostics and unchanged inputs. Stop at first failure. | 10–15 min including preparation |
| E2.2 · Accept the new walk | GATED on E2.1 | Same test with `KETH_BENCHMARK_TEST_EMBER_SURFACE=1`, original 300s cap. Require marker/exit 0, real sampled walking/full-path visits, report roundtrip, rejection cases and abort/gravity/input cleanup. Stop at first failure. | 5–10 min |
| E2.3 · Close delivery | GATED on accepted checks | Review actual results and owned process cleanup, update route support/status, remove the clean temporary checkout, commit/push. No new EXE for these export-excluded changes. | 10–15 min |

**Next single action:** sync the clean owned checkout to `00ffaa045`, copy the
existing donor cache, then launch the already prepared guarded source-check
batch at `/srv/mudds-work/ember-surface-benchmark-results-20261017/run.py`
with that full commit. It runs E2.1 then E2.2, stops on failure, and preserves raw
results. No check has been launched yet. Its independent abort is adjacent
`abort.py`. Never restart solely because a status observation expires.

**Exact test:** `/tmp/mudds-tools/godot-4.7.1/godot --headless --audio-driver Dummy
--path <clean-checkout> --script res://tests/performance_benchmark_runner_test.gd`.
The existing `tools/release/suite_process.py` enforces each 300s deadline. Default
has neither mode variable; combat sets `KETH_BENCHMARK_TEST_COMBAT=1`; surface
sets only `KETH_BENCHMARK_TEST_EMBER_SURFACE=1`. The prepared batch owns private
profiles, runtime lanes, source/cache guards and process teardown. These focused
checks retain the public full-duration benchmark floors below.

### E2 acceptance contract

Parent: original performance §5 / planetary surface
route. One implementer owns the same existing runner/wrapper/test/usage doc.
Reuse the five outbound and four return leg boundaries from
`tests/ember_loop_soak_evidence.gd::_walk_surface_route` on the real loaded
Ember LandingRegion/WalkablePatch. Stage the enabled unseated player once at
local(-5,0.2,0.5), outside timing; the real coordinator/bootstrap/common-origin
owner must load Ember and commit its rebase. Normal held movement follows and
repeats the finite pad-egress/staging path (~135m first loop). No further actor
placement, health writes, fake Host/session flags or claimed landing completion.

The solo Host applies gravity only during a genuine journey. This surface-only
benchmark explicitly composes the existing pure PlanetarySurfaceGravityPolicy
and its existing tangent projection through a benchmark adapter/public player
multiplier; it does not qualify the solo Host binding. Record that gravity
source, actual multiplier and world/frame identity; restore the original
multiplier on every completion/abort/error path. Sampled movement, live terrain
support, enabled unseated control and gravity must hold throughout. Smoke proves
positive sampled walking; a separate bounded45s focused path proves outbound and
return visits. Reject idle, warm-up-only, unsupported, wrong-world/gravity and
forged progress; verify saved JSON plus abort/input/cursor release. Keep schema1,
default two routes, selected false/null and full3,600/60s plus18,000/600s floors.
Use a separate mode in the existing test so its original300s cap stays intact.
Commit the exact invocation before execution. Root reviews and runs silent
headless/isolated checks. No canonical journey, native/rendered performance,
native wrapper or final-release claim. Implementation is committed as `00ffaa045`; runtime acceptance is NOT_RUN.
Next action: execute step E2.1 above. Stop at the first concrete failure or
accepted route, then close the owned checkout.

## Selecting the next delivery

After E2 closes, select a named production gap from the backlog and write its
outcome, component, dependencies, acceptance, estimate and stop point here.
Do not automatically launch another diagnostic or expand benchmark coverage.
A newly found E2 defect gets one bounded repair card before an unrelated task.
Unresolved capacity choice, missing original Settings artifacts and missing
Aurora reproduction inputs remain in the backlog; do not ask again without new information.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
