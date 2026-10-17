# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the current three-task batch. The
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

**Latest accepted task: HULK-HOME-INPUT / HULK-HOME-ALIGN — DONE.**
Complete ordinary route passes in 191.886 s under original 300 s: Guided, HULK arrival,
breaker/reward/duplicate refusal, reverse walk, reboard, safe header clearance,
actual Cinder fade/unload and home dock/shutdown/exit/20-tick supported walk.
Cell count 1 and exact receipt retained. Checkpoint `ef67f3e` is ready; Linux is the
exact successful route binary. Revisit is the remaining ordinary-journey child;
disk/interruption and broader parent gates stay open.
[Actual result, earlier failures and limits](docs/history/ROADMAP_DELIVERIES.md#hulk-home-return--done-checkpoint-ef67f3e).
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Current batch — 0 accepted, 1 failed, 1 gated, 1 ready

This is a count of **two qualifications and one conditional package delivery**,
not three new gameplay features or a project completion estimate. The departure
repair is saved, but its one full-route attempt FAILED at the original deadline.
No task is running. Task 3 is selected next; task 2 remains gated.
The 36 parent outcomes and all ten phase gates remain open.

| Order / task | Kind / status | Observable finish | Work estimate; separate check allowance |
| --- | --- | --- | --- |
| 1. [HULK-REVISIT-DEPARTURE](#1-hulk-revisit-departure--failed-at-original-deadline) | Qualification; FAILED, candidate withheld | Return to a newly streamed HULK and prove its breaker refuses a second cell after the full home journey. | Preparation/review/closure 30–45 min; setup/export/startups up to 47 min, then one 300 s route plus 45 s supervisor cleanup allowance. |
| 2. [HULK-REVISIT-CHECKPOINT](#2-hulk-revisit-checkpoint--gated-on-task-1) | Build delivery; GATED on task 1 PASS | Accepted source integrated and matching playable Windows/Linux packages, with accurate notes, published in repository builds. | Packaging/integration/closure 30–45 min; export/payload checks up to 26 min. |
| 3. [EMBER-ABANDON-SOURCE](#3-ember-abandon-source--ready-independent-of-hulk) | Qualification; READY, independent of HULK | Physically abandon an Ember visit, reboard, fly home, dock and walk out. | Preparation/closure 30–45 min; cold import up to 600 s, route up to 7,200 s. |

**Priority review after task 1:** the original revisit attempt failed, its bounded
repair was implemented, and the one changed-candidate qualification also failed.
Six setup stages passed; the route consumed its original 300 s allowance
(304.438 s including cleanup). The unreached result is the new HULK's full
interior walk and fresh duplicate-reward refusal. Independent Ember ABANDON is
READY and tests a different required journey. **Select task 3 next**, leaving
HULK parked and task 2 GATED. No further HULK diagnosis, repair or rerun is selected.
This decision does not change the route limit or claim a gameplay cause.
If task 3 fails, close it FAILED and explicitly select the next bounded task.

### 1. HULK-REVISIT-DEPARTURE — FAILED at original deadline

- **Parent/result:** [HULK](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys).
  Qualify the existing full home-and-revisit journey with the external driver
  corrected to follow the home berth's actual optional lift configuration.
- **State/source:** candidate `2298e48893163dfc8d6d174fcd3957a20fc4739b`,
  saved on `hold/hulk-revisit-departure-20261017`, excluded from main/public builds.
  Agent's 53 focused Python checks pass; all six setup stages pass, including
  privacy 226, fresh Linux export and strict direct/archive startup. The single
  full attempt FAILS at the original 300 s deadline, 304.438 s including cleanup,
  with no diagnostics. Latest public checkpoint remains `ef67f3e`.
  [Failure, achieved route and retained artifacts](docs/history/ROADMAP_DELIVERIES.md#hulk-revisit-departure--deadline-failure-on-2298e4889).
- **Owner/boundary:** root qualified the saved agent work; the owned temporary
  checkout has been removed after retaining exact artifacts. Repair touched only
  `scripts/diagnostics/native_sortie_observer.gd`,
  `tools/release/run_native_sortie.py`, and its existing Python tests.
  Zero configured lift requires actual released, inactive FREE_FLIGHT departure;
  positive lift still requires observed active then inactive. No further
  implementation, geometry, controls, timing or cap changes belong to this card.
- **Proof:** fresh clean import, observer parse, existing privacy test, Linux
  export and direct/archive strict startup; then exactly one existing
  `run_native_sortie.py <fresh ELF> --route hulk-revisit --output <owned-run>`.
  Require exit 0, `NATIVE_HULK_REVISIT_OK`, original cumulative 300 s cap, clean
  diagnostics and owned input/process/display cleanup. Full accepted HOME prefix,
  supported walk-away/reboard, real departure, pre-leg attitude fences, safe
  outward header, actual prior unload followed by newer streamed HULK/berth/
  breaker, strict dock, supported authored interior walk and fresh ordinary E
  dispatch/refusal all remain required. Same player/craft/capsule, one cell,
  exact receipt/activity generation and restored bus lighting must be retained.
  Frozen numeric fences in the saved driver/prepared runner remain unchanged:
  boarding separation >7 m; each flight leg starts at speed ≤.01 m/s, alignment
  ≥.9999 and pitch error ≤.5°; header z−130…−110 m stays within y1.4…3.8 m
  without hull loss. Neither an old refusal dictionary nor focused tests proves
  this route.
- **Budget/stop:** 30–45 min review/preparation/closure, no remaining repair
  budget. Separate existing stage caps: import 600 s, parse 300 s, privacy 300 s,
  export 930 s, two startups 330 s each, route supervisor 345 s enclosing the
  unchanged 300 s route. Stop at first failure or budget boundary; close this
  attempt and apply the priority review above.
- **Actual result:** home prefix completes at frame 5883; ordinary zero-height
  departure advances at 6239. New HULK generation 3/request 2 loads after the
  original unload; strict docking, shutdown and supported exit pass. Deadline
  stops `revisit_walk` at last processed frame 8798. Fresh new-breaker event count
  is 0; its stale refusal dictionary is not accepted as a new interaction.
- **Close/next action:** FAILED and parked; no remaining action in this card.
  Independent reviewer confirmed all 44 owned process identities absent, inputs
  released, helper/game/Xvfb reaped and display 189/socket/authority/profile cleanup.
  All source/index/engine/cache guards passed. Exact ELF/archive/export metadata
  and raw results are retained under
  `/srv/mudds-work/hulk-revisit-results-20261017/departure/`; the relocation manifest
  records hashes/former paths. Conditional Windows helper was not launched.
  Task 2 stays gated; task 3 is the selected next action.

### 2. HULK-REVISIT-CHECKPOINT — GATED on task 1

- **Parent/result:** [PACKAGE-WIN / PACKAGE-LINUX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
  Deliver the accepted revisit release capability and matching checkpoint packages.
  Player notes must distinguish qualified existing gameplay from a new feature.
- **Owner/dependency:** root; task 1 failed. A future explicitly selected and
  successful revisit qualification is required before this card can run. Integrate
  the candidate with its source identity retained after exporting from its clean
  qualified checkout using existing release scripts. No new packaging framework
  or gameplay work.
- **Proof:** conditional Windows export and silent isolated payload startup/privacy
  using the existing safe Linux-engine workflow. Startup requires exit 0 and
  `STARTUP_MENU_READY_OK`. Inspect exact EXE/ZIP/notes, stock PE metadata and
  Linux archive members/modes; retain the exact task-1-tested ELF. Compare actual
  embedded payload inventories and disclose any differences; never infer full
  cross-platform behavior from source identity or startup alone. Publish EXE,
  ZIP and notes in `builds/windows/`, matching ELF/archive/notes in `builds/linux/`.
  Native Windows execution, hardware and human-review gates stay NOT_RUN.
- **Budget/stop:** 30–45 min integration/packaging/closure; separate export 930 s,
  startup 330 s, privacy 300 s caps. Stop at first required-gate failure, retain
  raw results and latest accepted `ef67f3e` packages. A parity mismatch must be
  disclosed with its actual scope; it is not permission for an investigation loop.
- **Next action:** none while gated. After an explicitly selected successful
  revisit qualification, rebind the prepared conditional runner
  `/srv/mudds-work/hulk-revisit-results-20261017/departure/checkpoint/run.py`
  to that accepted source/checkout and require all seven stages and exact
  source/cache/ELF. Do not launch its now-retired checkout path. Run it once,
  integrate accepted source, package and update the latest checkpoint references.
- **Close:** commit/push integration and accurate notes/references, verify published
  artifacts, remove the owned disposable clean checkout and duplicate scratch
  packages. Preserve exact published bytes, source refs and raw failures.

### 3. EMBER-ABANDON-SOURCE — READY, independent of HULK

- **Parent/result:** [WORLD-ABANDON](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys).
  Qualify one physical Ember ABANDON round trip: outbound flight, surface exit/
  abandon/reboard/ascent, physical home return/dock/walking exit.
- **Owner/boundary:** root; freeze current clean integrated source in an owned
  checkout before launch. No HULK prerequisite. Existing
  `tests/ember_transit_movement_soak.gd` ABANDON branch, Torrent and
  MemoryFilesystem only. Initial guided state/on-foot placement and short
  canopy/boarding timings are fixtures. Accepted completed-survey journey stays
  DONE; this card claims no completed survey, durable disk reward, package, shared
  journey, hardware or whole-world acceptance.
- **Proof:** [existing mode command](docs/EMBER_LOOP_SOAK.md#what-is-real-and-what-is-staged),
  pinned Godot 4.7.1, `KETH_EMBER_PHYSICAL_RETURN=1`,
  `--headless --audio-driver Dummy --fixed-fps 60`, existing script and original
  7,200 s route cap. Unset arrival diagnostic; omit completed-return argument.
  Require exit 0, `EMBER_TRANSIT_MOVEMENT_TEST_OK: 31 assertions`, clean diagnostics,
  physical route/occupied home lease/supported walking checks and owned cleanup.
- **Budget/stop:** preparation/closure 30–45 min; separate cold import cap 600 s
  and route cap 7,200 s. This long existing journey is explicitly a qualification,
  not a two-hour implementation task. Do not split away required travel or shorten
  it to make the estimate look smaller. Stop at first failure or unchanged cap.
- **Next action (selected by the priority review above):** freeze full
  source/engine/runner identity and the existing
  guarded invocation, use fresh private profiles and record an independent abort
  path before launch. Reuse existing process supervisor; no new validator family.
- **Close:** record actual result/source/raw, commit/push and remove the owned
  disposable checkout. Failure ends this card. Packaged ABANDON acceptance and
  other WORLD-ABANDON requirements remain open even if this source run passes.

## Decomposing later work

This batch replaces the stale active cards; it does not claim all 36 parents
have been decomposed. At the end of these tasks, select only the next 3–5 known
instances from the backlog. Each needs the required card above. Unknown acceptance
gets one bounded definition task before implementation. Keep original parent
requirements and dependencies linked; archive closed cards and failures in the
existing delivery history, rather than growing this file into a run log.

A planning pass has a 30–45 min budget and ends with reviewed cards and a commit/
push. It performs no game runs and counts as planning progress only. Progress
updates give the named outcome, accepted/failed result, next action and separate
work/check estimates; they do not turn broad parent counts into a project ETA.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
