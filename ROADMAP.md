# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **b6af782**, with [notes](builds/windows/MuddsShipyards-b6af782-notes.txt).
Latest Linux package: **b41c3cc**, with [notes](builds/linux/MuddsShipyards-b41c3cc-linux-notes.txt),
including first-install and update interruption recovery. The last paired gameplay checkpoint is
b6af782, including the browser Disconnect improvement. Current full matrix: NOT_RUN;
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
- Schedule at most the next 3–5 concrete deliveries when their contracts are known.
  Uninstantiated backlog templates are not scheduled work or measurable progress.
- Every scheduled task must fit the task card below. A broad parent such as
  “finish planetary travel” stays in the backlog until specific children exist.
- A failed check ends the qualification task with a recorded failure. Diagnosis
  and repair are separate bounded tasks; neither silently extends the original.
  After one inconclusive diagnostic probe, report the missing fact and choose
  the next task explicitly before doing more investigation.
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
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, and one exact next action. |
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

**Latest closed task: SANDBOX-SETTLE-FACING — FAILED qualification.** The one
original300s trial reached recovery_walk after all54 waypoints/eight initial
sorties/crash/recall/regeneration, but did not finish recovery/reuse. Local mouse
correction worked without early waypoint admission; full acceptance failed.
Candidate7cb633d52 withheld, raw retained, owned processes/display closed and
clean disposable worktrees removed.
[Result](docs/history/ROADMAP_DELIVERIES.md#sandbox-settle-facing--qualification-failed-candidate-withheld).
No automatic retry or further pacing investigation. Convoy/Q4 also remain parked.

## ROADMAP-SPLIT — ongoing planning rule

**Outcome:** turn the next selected parent into a small executable task before
resuming implementation. This initial rewrite distinguishes eligible templates
from scheduled jobs, closes the stale live-run entry, and prepares bounded
children below. It does not claim that all36 parents have been decomposed.

For each subsequent batch, select at most3–5 children; do not pad the queue with
unverified tasks. Each child must have one player/build outcome, exact affected
component, dependencies, acceptance, work estimate, check duration and stop.
Use ordinary language in progress updates: what finished, what failed, what is
next, and the estimate for that task. Never infer a whole-project ETA from the
number of parent headings.

**Owner:** root. **Budget:** 30–45 minutes per batch of decomposition, no engine
runs. **Done:** cards are independently startable, linked to their parent, and
each ends at an observable result or precise blocker. Review docs/links, commit/
push. **Stop:** unknown acceptance becomes a bounded definition task, rather
than an open-ended implementation assignment. Refining future parents happens
when their dependencies are known; it must not become another giant planning loop.

## Prepared child: EMBER-ABANDON-SOURCE — qualification, not started

- **Parent/result:** [WORLD-ABANDON](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys).
  Qualify one existing physical Ember ABANDON round trip: outbound flight,
  surface exit/abandon/reboard/ascent, physical home return/dock/walking exit.
- **Boundary:** existing `tests/ember_transit_movement_soak.gd` ABANDON branch,
  Torrent and MemoryFilesystem. Initial guided state/on-foot placement and short
  canopy/boarding timings are fixtures. No completed-survey, durable disk reward,
  package, shared, hardware or whole-world acceptance. Completed52 journey stays DONE.
- **Proof:** [existing mode command](docs/EMBER_LOOP_SOAK.md),
  `KETH_EMBER_PHYSICAL_RETURN=1`, `--headless --audio-driver Dummy --fixed-fps 60`,
  original7200s route cap; arrival diagnostic unset, no completed-return argument.
  Exit0 plus `EMBER_TRANSIT_MOVEMENT_TEST_OK: 31 assertions`, clean diagnostics,
  actual physical route checks and owned cleanup. Do not attribute the other
  mode's disk/reward assertions to this mode.
- **Budget:** preparation/closure30–45m; separate cold import allowance600s and
  route allowance7200s. Long qualification duration is explicit, not an expanding
  implementation estimate. Stop at first actual failure or unchanged cap.
- **Execution:** root; PLANNED pending completion of roadmap planning and freezing
  a clean exact source. Next action: record source/runner identity and existing
  guarded invocation before launch; this planning task does not launch it.
- **Close:** retain actual result/source/raw; remove owned disposable checkout.
  Failure ends this card; any repair needs a separate named defect card.

## HULK-ORDINARY-CONTRACT — DONE definition

Read-only inspection on88fc84a34 found the exact gap: there is no ordinary-input
HULK journey driver. Existing regression stages flight, berth reservation/occupancy,
craft pose and Player exit; later fringe/rebase checks also reposition the Player
and invoke the breaker directly. Preserve the completed continuous interior walk.

Ordinary breaker dispatch already exists: Player's `interact` edge → GameFlow
`_on_interact_requested` → current facing/proximity candidate →
`HulkPowerBreaker.interact` → activity's actual4m reach check/3s restoration.
No missing runtime dispatch or gameplay defect is established by this inspection.
The native runner currently accepts only Guided/Sandbox-walk/Sandbox; its startup
allowlist and read-only observer also have no HULK mode. No existing full ordinary
HULK command can honestly be claimed. Definition stops here; no engine run.

Three dependent children replace the broad “finish HULK” assignment below. All
link to [HULK](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys). Only the
first is ready for implementation; later cards must freeze their exact invocation
after their dependency exists. These are scenario capabilities, not phase completion.

### HULK-ARRIVAL-INPUT — IN PROGRESS implementation

- **One result:** the existing native-input release runner can fly Torrent from
  its actual yard berth to the streamed HULK dock and exit onto the shelf.
- **Source/owner:** root integration, `hulk_arrival_implement` implementation,
  base785442ee3 (runtime unchanged from88fc84a34). Ownership: existing
  `tools/release/run_native_sortie.py`, `scripts/diagnostics/native_sortie_observer.gd`
  and explicit mode allowlist in `scripts/game/startup_loader.gd`; focused existing
  runner tests only as needed. Gameplay changes require a reproduced defect first.
- **Boundary:** add select-only HULK arrival using ordinary menu/keyboard/mouse
  inputs and default sampler. Observer remains read-only. No pose/velocity writes,
  direct reserve/occupy/landing calls, timing overrides, new validator or framework.
  Breaker, reward, return/revisit remain the next children. Fresh title startup
  requires the normal Guided range/interceptor prelude before RETURN_TO_YARD
  permits landing. This mode must complete that prelude before diverting to HULK;
  no saved-ready fixture or bypass is implied.
- **Proof:** intended new command is `python3 tools/release/run_native_sortie.py
  builds/linux/<exact-clean-build>.x86_64 --route hulk-arrival --output <new-run-dir>`.
  This command is not implemented yet. Require actual physical departure, streamed
  destination, production landing contract accepted for `cinder_hulk_dock`, berth
  occupant equal to the flown craft, normal shutdown/Interact exit, unseated
  controllable Player on actual HULK collision. Exact mode/marker must be added
  explicitly; generic Guided success cannot stand in for these observations.
- **Budget/stop:**60–90m implementation; separately cold import/export/startup and
  one arrival run using the runner's existing300s cap. Stop at first unsupported
  control/actual failure or estimate boundary; record exact blocker before repair.
  Keep existing Guided/Sandbox behavior and caps unchanged.
- **Candidate:**6426fa7b1490b2fa311a3f088124004cad6a43a8, reviewed;22 focused
  Python tests pass, actual route unqualified. Author checkout
  `/srv/mudds-work/hulk-arrival-20261017` retained until integration.
- **Next action:** observe existing clean-checkout import/privacy/Linux export/
  direct+archive startup/one arrival workflow. Outer driver PID380709/start
  ticks107810387; raw and exact stage owners/status/abort:
  `/srv/mudds-work/hulk-arrival-results-20261017/`. Acceptance checkout
  `/srv/mudds-work/hulk-arrival-check-20261017`, pinned to candidate. Do not
  relaunch on observation timeout. First actual failure ends this qualification.
  After a working route, clean-source Windows EXE/ZIP/notes are still required.
  All automated runtime remains isolated X11/Dummy with owned abort/cleanup.
- **Close:** exact source/build/raw outcome, commit/push, remove owned disposable
  worktrees. No full salvage journey claim from arrival alone.

### HULK-BREAKER-INPUT — GATED on arrival

- **One result:** extend the same run from actual disembarkation through all
  authored interior spaces; ordinary Interact engages the breaker and earns one
  cell. Repeated Interact must not earn another.
- **Owner/boundary:** root; same runner/read-only observer. Reuse authored route
  and production interaction/reward owners. No additional Player placement, direct
  breaker call, timer acceleration or replacement reward ledger.
- **Proof:** extend the successful arrival mode on its frozen successor, retain
  identity/support/continuous movement checks and actual Interact dispatch; observe
  committed `hulk_auxiliary_power_cell` count exactly1 and restored bus lighting.
  A memory-only check does not establish disk persistence or OS interruption.
- **Budget/stop:**45–90m implementation; original existing runner cap remains300s
  for this cumulative route. Freeze exact mode/command before execution. If that
  contract cannot fit or an interaction fails, record it; do not silently extend.
- **Next action after dependency:** append held-input interior walking and an
  actual released-then-pressed Interact at the live panel. Commit/build/cleanup
  with observed result; full home/revisit remains gated.

### HULK-RETURN-REVISIT — GATED on breaker

- **One result:** from that same run, walk back, reboard, fly home, dock/exit,
  then revisit the streamed HULK without receiving a second power cell.
- **Owner/boundary:** root; same runner/observer and existing flight/berth/streaming
  owners. Preserve physical travel, normal lease release and supported exits.
  Disk reload, installed interruption, repeated-use endurance and hardware stay
  separate requirements; do not infer them from one live session.
- **Proof:** exact cumulative command/source and runtime budget must be defined
  from the accepted preceding route before marking READY. Require ordinary home
  dock/exit, actual unload/reload/new HULK generation, restored lighting, cell
  count still1 after another breaker press, and usable craft/Player state.
- **Budget/stop:**45–90m implementation after dependency, check duration separately.
  Stop at first failure or estimate boundary; no automatic second journey attempt.
- **Next action after dependency:** freeze the physical return/revisit route and
  its explicit cap, then implement it in the existing driver. Close with exact
  result/source/build, commit/push and owned scratch cleanup.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
