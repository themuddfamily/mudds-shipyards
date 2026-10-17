# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the active delivery only. The
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

**Latest accepted task: HULK-HOME-INPUT / HULK-HOME-ALIGN — DONE.**
Complete ordinary route passes in 191.886 s under original 300 s: Guided, HULK arrival,
breaker/reward/duplicate refusal, reverse walk, reboard, safe header clearance,
actual Cinder fade/unload and home dock/shutdown/exit/20-tick supported walk.
Cell count 1 and exact receipt retained. Checkpoint `ef67f3e` is ready; Linux is the
exact successful route binary. Revisit is the remaining ordinary-journey child;
disk/interruption and broader parent gates stay open.
[Actual result, earlier failures and limits](docs/history/ROADMAP_DELIVERIES.md#hulk-home-return--done-checkpoint-ef67f3e).
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

## HULK — arrival, breaker and home DONE; revisit remains

`--route hulk-home` / `NATIVE_HULK_HOME_OK` now qualifies the complete ordinary
outbound/breaker/home journey through existing production gameplay. Driver `7e251f8af`
against game `ef67f3e95` passes in 191.886 s at original 300 s cap, zero diagnostics. The
release driver stages outside the range header and waits for observed attitude
alignment; there are no gameplay, geometry, tuning or timer changes.

Proof includes 76.790 m outbound / 79.947 m reverse supported walking, real E/normal
restoration/separate duplicate refusal, ordinary reboarding, actual HULK lease
release, 30 safe header samples (y2.370–2.594m, hull89 retained), zero-opacity
retirement/actual Cinder unload at 673.080 m, strict occupied home dock, OFFLINE/
ordinary exit and a 20-tick, 0.713 m supported walk. Same actors/capsule, cell count 1/receipt/
activity generation 1 retained. Full parent, revisit and disk recovery remain open.

Checkpoint `ef67f3e` EXE/ZIP/notes and exact tested Linux ELF/archive/notes are in
repository builds. Strict Windows-payload startup/privacy (207 assertions) pass under Linux
Godot; native Windows/human review are NOT_RUN. All 1,515 entry paths match but strict
payload-byte parity fails for 65 generated scenes; no full parity claim. Earlier
failures and the bounded inconclusive comparison probe remain recorded in
[completed deliveries](docs/history/ROADMAP_DELIVERIES.md#hulk-home-return--done-checkpoint-ef67f3e).
Both owned implementation/acceptance checkouts and large scratch duplicates are
removed; exact published artifacts and raw failures are retained.

### HULK-REVISIT-CONTRACT — READY definition task; not started

- **Parent/result:** HULK-REVISIT-INPUT. Freeze one ordinary home walk-away/
  reapproach route and the accepted unload→new-generation observations before
  assigning revisit implementation. Definition is not a gameplay delivery.
- **Owner/boundary:** root assigns one bounded read-only reviewer. Existing
  driver `7e251f8af`, production boarding/support owners and final accepted home
  observations. No engine, gameplay edits, reset or new evidence framework.
- **Proof:** name supported waypoint(s) for the source-required >7m clearance,
  live boarding candidate/no conflicting station action, and driver extension
  seam preserving the full accepted prefix. Require actual prior unload, newer
  streaming generation/distinct HULK, retained receipt/activity generation 1.
- **Budget/stop:**15–20 minutes, stop when ownership, route and acceptance are known or
  report one missing fact. Keep original cumulative300s cap and physical criteria.
- **Next action:** inspect final home exit/support/boarding observations against
  the existing reboard-block owner; freeze the next implementation card.
- **Close:** record finite contract/blocker, commit/push; no speculative queue.

### HULK-REVISIT-INPUT — GATED on bounded departure contract

- **One result:** after the now-qualified home exit, reboard, revisit a genuinely new
  streamed HULK, walk to its breaker and refuse a second cell.
- **Owner/boundary:** root; same native runner/read-only observer/allowlist and
  focused tests. Preserve all accepted outbound/breaker/home criteria.
- **Required ordinary step:** walk more than7m from live home boarding position
  to clear the production reboard block, then approach/candidate/E. Immediate
  exit→E is unsupported. Later sortie is FREE_FLIGHT; no tutorial/menu/reset.
- **Proof:** proposed `--route hulk-revisit`/`NATIVE_HULK_REVISIT_OK`, cumulative
  original 300 s cap, exact successor command/source frozen before READY. Observe
  actual prior unload and newer Cinder load generation/counters, distinct
  HULK/berth/breaker identities, same Player/ship. Normal dock/shutdown/exit and
  authored interior walk; new live breaker E refuses duplicate, restored light
  properties and cell count 1/receipt/activity-generation 1 retained. Streaming
  generation is separate; do not hardcode normal1→3 or treat replacement as resume.
- **Budget/stop:**45–90 minutes implementation after home, check runtime separately.
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
