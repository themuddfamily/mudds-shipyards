# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next two executable tasks. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **ef67f3e**, with [notes](builds/windows/MuddsShipyards-ef67f3e-notes.txt).
Latest Linux package: **ef67f3e**, with [notes](builds/linux/MuddsShipyards-ef67f3e-linux-notes.txt).
Includes optional ordinary-input HULK home-return release qualification. The exact
Linux binary passes; Windows payload startup/privacy passes separately. Strict
cross-platform payload-byte parity fails for 65 generated scenes; notes disclose it.
Earlier installed Guided/recovery results keep their exact source-specific scopes.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Rules that prevent loops

- Select one named delivery with one observable outcome. Split implementation
  expected to exceed 90 minutes before starting; estimate check time separately.
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
- Schedule at most the next 3–5 concrete deliveries when their contracts are known.
  Uninstantiated backlog templates are not scheduled work or measurable progress.
- Every scheduled task must fit the task card below. A broad parent such as
  “finish planetary travel” stays in the backlog until specific children exist.
- A failed check ends the qualification task with a recorded failure. Diagnosis
  and repair are separate bounded tasks; neither silently extends the original.
  After one inconclusive diagnostic probe, report the missing fact and choose
  the next task explicitly before doing more investigation.
- After a failed task and one attempted repair, review priorities before any
  further diagnosis, repair or rerun. Record the unresolved player/build outcome,
  time spent, competing READY task and selected next action. Renaming a card or
  finding a different defect does not reset this limit. This is a scheduling
  decision, not a new permission request.
- Report progress as the named result, proof obtained, remaining action and
  revised time estimate. Planning, diagnostics and test infrastructure do not
  count as a delivered gameplay outcome.

## Required card for the next scheduled tasks

Keep cards here, beside the work, rather than creating another tracking system.
Define at most the next 3–5 tasks; refine later backlog items when their dependencies
are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Start with tasks expected to take 30–90 minutes of implementation. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Current position

**36 broad parent outcomes remain open; the remaining executable-job count is
not yet known.** Parent scope lives in the backlog. Only named cards below are
scheduled tasks; their steps are not separate delivered outcomes. Planning and
diagnosis are reported separately from playable changes.

Recent accepted results: Ember completed physical source journey on bf452ed868,
Aurora coastal benchmark route on c47b5cd55, Linux first-install recovery/package
b41c3cc, and managed installed Guided3/3. See
[completed deliveries](docs/history/ROADMAP_DELIVERIES.md) for exact proof/limits.
These do not close their broad parents or the ten phase gates.

**Latest accepted task: EMBER-ABANDON-SOURCE — DONE.**
Clean integrated source `e85157b4d` passes the original physical ABANDON round
trip: actual outbound/landing, abandonment/reboard/ascent, return cruise, occupied
home dock, disembarkation and supported walking. Exit 0, exact 31 assertions,
approximately 2,474.7 s under the original 7,200 s cap, no diagnostics. This uses
Torrent/MemoryFilesystem and documented fixtures; packaged/durable-reward/shared/
hardware gates remain open. [Actual result and limits](docs/history/ROADMAP_DELIVERIES.md#ember-abandonment--integrated-source-journey-done-on-e85157b4d).
Latest public checkpoint remains `ef67f3e`; accepted HULK home and failed revisit
results retain their exact scopes. No unchanged Ember rerun is selected.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Previous batch closed — 1 accepted, 1 failed, 1 gated

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Next batch — two tasks, one new benchmark capability

| Order / task | Status | Observable finish | Work estimate; separate check allowance |
| --- | --- | --- | --- |
| 1. [RIME-BENCH-ROUTE](#rime-bench-route--ready) | READY | Select `rime_surface_walk_route` in the existing runner and physically walk the authored icefall survey/return trail, recording a valid diagnostic report. | Implementation 60–90 min; cold import up to 600 s and four focused modes up to 300 s each. |
| 2. [RIME-BENCH-CHECKPOINT](#rime-bench-checkpoint--gated-on-route-acceptance) | GATED on task 1 | Accepted source integrated, matching development packages/startup results and accurate source-benchmark instructions published. | Integration/package/closure 30–45 min; exports up to 930 s each, three strict startups up to 330 s each and privacy up to 300 s. |

The actual gap is one missing selectable benchmark route, not missing Rime
terrain, survey gameplay or native performance evidence. Existing surface walks
cover Ember and Aurora. Two cards separate executable route acceptance from
artifact publication; they are not two new gameplay features. Unknown work is
not added to this batch merely to fill a task count. No task is running yet.

### RIME-BENCH-ROUTE — READY

- **Parent/result:** [PERF-ROUTE](docs/ROADMAP_BACKLOG.md#performance-controls-accessibility-and-audio).
  Add the missing Rime icefall survey/return walk to the existing benchmark runner,
  alongside the delivered Ember/Aurora surface selections.
- **Owner/boundary:** one implementation agent; root review and guarded runtime
  checks. Own `tools/performance/benchmark_runner.gd`, its existing focused test
  `tests/performance_benchmark_runner_test.gd`, and the scenario allowlist in
  `tools/performance/run_native_windows_benchmark.ps1`. Root owns documentation,
  source freeze, integration and packaging. No nested agents or new benchmark/
  validator system. Read existing `rime_glacial_authored_scene.gd` trail constants
  and region/world/terrain definitions; production world/Player/gravity/streaming
  owners remain unchanged.
- **Behavior:** select-only `rime_surface_walk_route`; original two default
  scenarios remain unchanged. Stream the real Rime scene through Main's existing
  binding and commit its origin frame. Disclose any benchmark observation/gravity
  adapter, as for Aurora. One initial placement before timing; held production
  movement then visits every ordered SURVEY_TRAIL and RETURN_TRAIL point and
  returns to the start without further placement. Resolve waypoints in the live
  region frame after origin changes. Record real support, control, path and
  gravity continuity; active abort releases held input/cursor, restores gravity
  and frees Main.
- **Proof:** extend the existing benchmark test with select-only
  `KETH_BENCHMARK_TEST_RIME_SURFACE=1`, headless/Dummy, original 300 s focused cap.
  Require exit 0, the existing success marker/catalog and explicit new route
  assertions: real streamed identity, one placement, full supported walk,
  every ordered survey/return waypoint and a completed loop back within 0.5 m
  horizontally of its start (recorded at loop closure), valid JSON round trip,
  wrong-world/gravity/refused progress rejection and actual mid-walk abort cleanup. Freeze the mode's exact
  assertion count before launching. Run existing default/Ember/Aurora focused
  modes once because their shared helper is affected; preserve their original
  limits. Review PowerShell's selection contract without executing native Windows.
- **Budget/stop:** 60–90 min implementation; separate cold import 600 s, focused
  Rime/default/Ember/Aurora caps 300 s each. Stop first concrete failure or work
  budget boundary, retain raw and record a separate bounded repair if justified.
  No automatic extra probe, route rescue, geometry change or timing relaxation.
  Full benchmark still requires at least 3,600 frames/60 s warmup and
  18,000 frames/600 s measurement. Focused diagnostics do not qualify those floors,
  native GPU timing, hardware, real audio, canonical travel or survey rewards.
- **Next action:** freeze a clean implementation source, implement only this
  selection through the existing surface staging/walker/report/abort owners,
  then root reviews source and freezes the four commands before running them.
- **Close:** record actual source/result, commit/push candidate. PASS unlocks the
  checkpoint; failure ends this card and does not silently extend implementation.

### RIME-BENCH-CHECKPOINT — GATED on route acceptance

- **Parent/result:** [PACKAGE-WIN / PACKAGE-LINUX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
  Publish a paired development checkpoint from the accepted source, with exact
  package/startup results and usable instructions for selecting its source benchmark.
- **Owner/dependency:** root; task 1 must PASS, including affected existing modes.
  Preserve the exact accepted commit through integration and export from its
  clean checkout using existing release scripts. No new packaging framework.
- **Proof:** fresh Windows EXE/ZIP/notes in `builds/windows/` and matching Linux
  ELF/archive/notes in `builds/linux/`; exact artifact bytes/modes, inventory and
  ZIP/archive checks. Direct/archive Linux startup and silent Windows-payload
  startup require exit 0 plus `STARTUP_MENU_READY_OK`; existing privacy test must
  pass. Reuse the accepted source/import cache; record actual cross-platform
  payload differences without inferring equivalence. Do not run native Windows,
  hosted CI, active-desktop or audible tests.
- **Scope:** the source checkout runs the benchmark tool. Exported game packages
  exclude `tools/`; notes must state this and must not claim the EXE exposes the
  benchmark, new Rime gameplay, native performance or full-release acceptance.
  This is a development checkpoint, with native/human/hardware gates NOT_RUN.
- **Budget/stop:** integration/package/closure 30–45 min; separate Linux/Windows
  exports 930 s each, three startup stages 330 s each, privacy 300 s. Stop at first
  required-gate failure; preserve the accepted route and latest public `ef67f3e`
  checkpoint. No parity investigation or unchanged qualification retry follows.
- **Next action after task 1 PASS:** review exact source and existing safe export
  commands, run the conditional package checks once, publish and update references.
- **Close:** commit/push integration and concise honest notes/references; verify
  published bytes and remove owned clean disposable checkout/duplicate packages.
  Preserve exact source refs, unique raw results and published artifacts.

## Decomposing later work

This batch does not claim all 36 parents have been decomposed. At its boundary,
select at most the next 3–5 known instances. Each needs the required card above;
unknown acceptance gets one bounded definition task. Archive closed cards and
failures in existing delivery history. A planning pass has a 30–45 min budget,
no engine runs, and ends with reviewed cards and a commit/push. Planning and
benchmark diagnostics do not count as delivered gameplay or native performance.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
