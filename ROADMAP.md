# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **7dd70a9**, with [notes](builds/windows/MuddsShipyards-7dd70a9-notes.txt).
Latest matching Linux package: **7dd70a9**, with [notes](builds/linux/MuddsShipyards-7dd70a9-linux-notes.txt).
Includes optional ordinary-input HULK arrival, interior walking and breaker automation.
Earlier installed Guided/recovery results keep their exact source-specific scopes.
Current full matrix: NOT_RUN;
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

**Latest accepted task: HULK-BREAKER-INPUT — DONE outbound/interior only.**
Full ordinary route passes81.864s,76.79m interior walk, one committed cell and
separate repeated E refusing another credit. Paired checkpoint7dd70a9 is ready;
Linux is the exact tested binary. Home return/revisit are the next two children.
[Result and exact limits](docs/history/ROADMAP_DELIVERIES.md#hulk-ordinary-breaker--done-checkpoint7dd70a9a4).
Latest home attempt52e3e7f69 stops at the unchanged clearance guard; see the
failed repair and next15m diagnosis below. No home/revisit pass is claimed.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

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

## HULK — arrival and breaker DONE; two journey children remain

The ordinary outbound/interior route now works through `--route hulk-breaker`:
normal Guided prelude, physical streamed docking/exit,76.79m continuous interior
walk, actual breaker Interact, normal restoration and exactly one cell. Separate
second E refuses another reward. Exact drivera531ac6b8/game7dd70a9 passes81.864s
at original300s cap, zero diagnostics. Paired checkpoint7dd70a9 and owned cleanup
are complete. Earlier failures, tiny numeric comparison correction and limits
remain in [completed deliveries](docs/history/ROADMAP_DELIVERIES.md#hulk-ordinary-breaker--done-checkpoint7dd70a9a4).
This does not close the full HULK parent. Split its remaining physical journey
at the observable home-exit boundary, rather than one expanding return/revisit job.

### HULK-HOME-INPUT — FAILED qualification; candidate withheld

- **Parent/result:** [HULK](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys).
  Add an opt-in release qualification route continuing the accepted breaker run
  back through the interior, reboard, fly home, dock/shut down/exit and walk on
  supported yard collision with cell count1 retained. This checks existing
  gameplay; it does not claim new gameplay until a demonstrated defect is fixed.
- **Owner/boundary:** root integration, `hulk_home_implement` implementation;
  candidateef67f3e95 from base9c2653f02 (prior runtime81536a7b3). Existing native Python
  runner, read-only observer, startup mode allowlist and focused existing tests.
  No gameplay/pose/timing/ledger changes without a reproduced defect.
- **Normal sequence:** reverse recorded walk through unchanged interior/aperture
  points to actual exit, approach live ship boarding position, no conflicting
  station candidate, ordinary E. Completed Guided flag makes later thrust go
  START_ENGINES→FREE_FLIGHT. Fly existing home approach, capture/one L, strict
  occupied home dock, neutral OFFLINE/one E, actual supported walking exit.
- **Proof:** proposed select-only `--route hulk-home`, distinct
  `NATIVE_HULK_HOME_OK` (implemented; full route FAILED), original cumulative300s cap.
  Preserve complete breaker receipt; same Player/ship/capsule and authored
  controls; occupied HULK lease actually released before actual Cinder unload;
  strict home token/occupant/exact parking, controllable unseated supported exit.
  Use existing20-tick ordinary walk criterion (>0.25m/<5m, on floor) for usable
  home exit. Cell count1/receipt/generation1 unchanged throughout.
- **Budget/stop:**45–90m implementation, checks/export/one300s route separately.
  Stop first unsupported control/actual failure or estimate boundary; no retries,
  rescue, direct boarding/docking calls or clock changes.
- **Actual result:** candidate37 Python checks, clean Godot import/observer parse/
  privacy, Linux export and direct/archive strict startup pass. One cumulative
  route failed its unchanged300s deadline in `home_flight`;303.781s includes
  cleanup. Guided/HULK/breaker/duplicate refusal/reverse walk/reboarding completed.
  Last position(-4.636,8.549,-125.468), FREE_FLIGHT/ONLINE, cell1/generation1;
  Cinder still loaded at583.468m, no home docking/unload/exit proof. No diagnostics.
- **Close:** six setup/package stages pass, route FAIL. Source/index/engine/cache
  stable; all61 observed owned identities absent, inputs released and private
  display257/authority/sockets closed. Candidateef67f3e95 retained on
  `hold/hulk-home-input-20261017`, excluded from main and published checkpoints.
  Implementation worktree removed. Raw: `/srv/mudds-work/hulk-home-results-20261017/`.
  Windows checkpoint was not launched; latest accepted package remains7dd70a9.
  Full route repair is a separate card; revisit remains gated.

### HULK-HOME-CLEARANCE — FAILED qualification; candidate withheld

- **Parent/result:** HULK-HOME-INPUT. Correct the release driver's inbound line
  so Torrent flies under the existing range header before approaching home.
  This repairs automation; production geometry and gameplay remain unchanged.
- **Finding:** completed15m-bounded HOME-STALL source/log diagnosis identifies
  `RangeHeader` at(0,9,-120), size(63,1,1). Frame4819 forward speed79.81→0 and
  hull89→36.61 show impact at ship y8.68. Direct return interpolation crossed
  that valid collider; the documented shared clearance band is y1.4–3.8,
  aim2.7. The approach was111m away, outside86.55m braking threshold.
- **Owner/boundary:** one implementation agent owns existing native Python
  driver/tests in the retained candidate checkout; root reviews/runs/closes.
  Add one inbound staging point near(0,2.7,-150), physically settle before
  continuing home. Preserve all original route classes, accepted prefix, actors,
  controls, geometry, timing, cumulative300s cap and home physical criteria.
- **Proof:** focused driver regressions, then one full packaged `hulk-home`
  attempt with the same ef67f3e95 game binary. Record safe header crossing in
  documented clearance band without further hull loss, actual fade/unload and
  strict home docking/shutdown/exit/20-tick walk, same cell/receipt/generation1.
  Only external Python driver/tests may differ from the accepted package source.
- **Budget/stop:**30–45m implementation; one300s route separately. Stop at
  first concrete failure or estimate boundary. No extra probe, new framework,
  checkpoint export or unchanged startup checks before the route result.
- **Actual result:** driver52e3e7f69,39 focused Python checks pass; same exact
  ef67f3e95 Linux binary/cache. The single full route stops154.594s at its first
  clearance guard failure. Actual staging reached frame5005 at
  (-.355,2.856,-150.747); next flight enters the guarded interval at frame5081,
  (3.302,1.266,-129.544), below the unchanged1.4m lower bound. Hull stays89.
  Header crossing, Cinder unload, home docking/exit/walk remain unqualified.
- **Close:** no third attempt or criterion relaxation. Source/index/engine/cache
  guards pass, zero diagnostics, all8 observed owned identities independently
  absent, inputs released and private display264/authority/sockets closed; both
  runtime lanes available. Candidate52e3e7f69 held on
  `hold/hulk-home-clearance-20261017`, excluded from main/published checkpoints.
  Both owned worktrees removed. Exact failed Linux binary/archive/metadata moved
  into retained raw (hashes verified), rather than exported again.
  Raw: `/srv/mudds-work/hulk-home-results-20261017/clearance/`; relocation map:
  `/srv/mudds-work/hulk-home-results-20261017/retained-artifacts.json`.

### HULK-HOME-ATTITUDE — READY bounded diagnosis; not started

- **Parent/result:** HULK-HOME-INPUT. Identify why the first ordinary departure
  from a settled clearance waypoint loses altitude below the existing safe band.
  Diagnosis is separate from a delivered gameplay or release capability.
- **Owner/boundary:** root assigns one read-only source/log reviewer; inspect
  held driver52e3e7f69 and retained ef67f3e95 trace, especially frames5005–5081.
  One hypothesis: thrust resumes while craft attitude/vertical velocity still
  drives descent after the staging target changes. No engine, edits or retry.
- **Proof:** identify the exact controller/input boundary and smallest repair
  with file/line plus retained observations, or report the single missing fact
  for one later probe. Settled position alone is not proof of flight readiness.
- **Budget/stop:**15m, stop at causal seam or missing fact. Keep original300s
  cumulative route, clearance band1.4–3.8 and all home physical criteria.
- **Next action:** inspect first staging→home approach transition against the
  existing mouse/thrust response and retained attitude/velocity observations.
  Schedule any implementation or engine probe as a separate bounded task.
- **Close:** record result/source and next action, commit/push; retain failures.

### HULK-REVISIT-INPUT — GATED on home route

- **One result:** after that actual home exit, reboard, revisit a genuinely new
  streamed HULK, walk to its breaker and refuse a second cell.
- **Owner/boundary:** root; same native runner/read-only observer/allowlist and
  focused tests. Preserve all accepted outbound/breaker/home criteria.
- **Required ordinary step:** walk more than7m from live home boarding position
  to clear the production reboard block, then approach/candidate/E. Immediate
  exit→E is unsupported. Later sortie is FREE_FLIGHT; no tutorial/menu/reset.
- **Proof:** proposed `--route hulk-revisit`/`NATIVE_HULK_REVISIT_OK`, cumulative
  original300s cap, exact successor command/source frozen before READY. Observe
  actual prior unload and newer Cinder load generation/counters, distinct
  HULK/berth/breaker identities, same Player/ship. Normal dock/shutdown/exit and
  authored interior walk; new live breaker E refuses duplicate, restored light
  properties and cell count1/receipt/activity-generation1 retained. Streaming
  generation is separate; do not hardcode normal1→3 or treat replacement as resume.
- **Budget/stop:**45–90m implementation after home, check runtime separately.
  Stop first failure/estimate boundary; no automatic extra probe or route retry.
- **Next action after dependency:** freeze home-clearance waypoint/support and
  explicit unload/reload observations, then extend the driver. The old prefix's
  unclaimed/old-HULK checks must not be applied to the already-earned revisit.
- **Close:** record observed result/source/build, commit/push, checkpoint/cleanup.
  Fresh disk reload/OS interruption, endurance, shared and hardware remain open.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
