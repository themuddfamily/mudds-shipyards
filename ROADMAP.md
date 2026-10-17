# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **2f68711**, with [notes](builds/windows/MuddsShipyards-2f68711-notes.txt).
Latest matching Linux package: **2f68711**, with [notes](builds/linux/MuddsShipyards-2f68711-linux-notes.txt).
Includes HULK objective correction and optional ordinary-input arrival automation.
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

**Latest closed task: HULK-ARRIVAL-INPUT — DONE arrival only.** Corrected driver
passes61.306s on retained150dbb1 game; fresh paired checkpoint2f68711 passes
startup/privacy/artifact checks. Breaker/reward/home/revisit remain separate.
[Result and exact limits](docs/history/ROADMAP_DELIVERIES.md#hulk-ordinary-arrival--done-checkpoint2f687110e).
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

## HULK arrival — DONE; next child is breaker interaction

The broad ordinary HULK journey was split into arrival, interior breaker, and
return/revisit. Arrival now works through the existing OS-input runner's
`--route hulk-arrival`: normal Guided prelude, physical streamed-dock flight,
strict landing, neutral shutdown and actual supported shelf exit. No staging.

Actual qualification: driver60c86ce8a/game150dbb1,61.306s, original300s cap,
NATIVE_HULK_ARRIVAL_OK, zero diagnostics. Integrated main2f687110e and fresh
Windows/Linux checkpoint2f68711 have strict startup/privacy/artifact acceptance.
The new checkpoint bytes were not separately flown to HULK. Exact checks,
source identities, earlier failures, supported correction, cleanup and limitations
are in [completed deliveries](docs/history/ROADMAP_DELIVERIES.md#hulk-ordinary-arrival--done-checkpoint2f687110e).
Clean author/acceptance worktrees and duplicate scratch builds removed; raw kept.

### HULK-BREAKER-INPUT — IN PROGRESS implementation

- **One result:** extend the same run from actual disembarkation through all
  authored interior spaces; ordinary Interact engages the breaker and earns one
  cell. Repeated Interact must not earn another.
- **Owner/boundary:** root integration, `hulk_breaker_implement` implementation;
  base72e3f07e8 (runtime2f687110e). Existing native runner,
  read-only observer and startup allowlist, plus focused existing tests. Reuse authored route
  and production interaction/reward owners. No additional Player placement, direct
  breaker call, timer acceleration or replacement reward ledger.
- **Proof:** intended select-only `--route hulk-breaker` (not implemented yet),
  distinct `NATIVE_HULK_BREAKER_OK`, on its frozen successor. Retain
  identity/support/continuous movement checks and actual Interact dispatch; observe
  committed `hulk_auxiliary_power_cell` count exactly1 and restored bus lighting.
  A memory-only check does not establish disk persistence or OS interruption.
- **Budget/stop:**45–90m implementation; original existing runner cap remains300s
  for this cumulative route. Freeze exact mode/command before execution. If that
  contract cannot fit or an interaction fails, record it; do not silently extend.
- **Candidate:**7dd70a9a467621f4590f97ac8c1a725cd20b1e5e, root reviewed;
  Python30 tests pass. Existing Guided/Sandbox/HULK arrival/OS helpers AST-identical.
  Actual supported exit replaces exterior route start0; authored1–5 unchanged.
- **Next action:** observe ONE existing guarded cold-import/observer-parse/privacy/
  Linux export/direct+archive startup/breaker qualification. Outer driver PID391026/
  start ticks107975389; raw/stage owners/status/abort:
  `/srv/mudds-work/hulk-breaker-results-20261017/`. Exact clean candidate checkout
  `/srv/mudds-work/hulk-breaker-check-20261017`.
  Original300s route/345s outer cleanup; first actual failure stops, no relaunch
  on polling timeout. A reused-supervisor read-path alias was aligned before
  any route launch; raw note records it. No candidate/criteria changes.
- **Close:** record actual outcome, integrate/push and build working checkpoint;
  preserve failures/unique work, remove owned disposable scratch. Home/revisit
  remains separate and gated.

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
