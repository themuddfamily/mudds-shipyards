# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded planning task. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **a8f563e**, with [notes](builds/windows/MuddsShipyards-a8f563e-notes.txt).
Latest Linux package: **a8f563e**, with [notes](builds/linux/MuddsShipyards-a8f563e-linux-notes.txt).
Paired development checkpoint for the new source Rime benchmark selection.
Clean exports, three strict startups and privacy207 pass; all1,515 payload entries
match byte-for-byte. The benchmark requires a source checkout; exported games
exclude tools. Earlier HULK/home, Ember journey and installed recovery proofs
retain their exact source/binary scopes; no full-route proof transfers to these bytes.
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

**Latest accepted task: RIME-BENCH-ROUTE and checkpoint — DONE.**
Source `a8f563e39` adds select-only walking through every authored Rime survey/
return waypoint, supported by Main's real streaming/gravity owners. Focused
Rime33/default152/Ember24/Aurora27 pass. This delivers benchmark coverage,
not new planetary gameplay or native performance qualification. Paired
checkpoint `a8f563e` is published; details and limits are below.
Ember ABANDON source `e85157b4d` remains DONE (physical home dock/walk, exact31),
with packaged/durable-save/shared/hardware gates open. HULK revisit stays parked.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Previous batch closed — 1 accepted, 1 failed, 1 gated

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Next task — ROADMAP-SLICE (planning only)

**READY; root owns this task. Estimated 30–45 minutes; no engine runs.**
The completed Rime task contracts are in
[delivery history](docs/history/ROADMAP_DELIVERIES.md#accepted-rime-batch--original-task-contracts).
No implementation or qualification batch starts as part of this planning task.

- **Result:** replace the next priority's placeholder with 3–5 named, achievable
  child tasks. Start with `WORLD-SHARED[Rime baseline full outbound/return]`,
  the integrated remote-crew journey identified in the production roster.
  Preserve all other original promises in the backlog.
- **Boundary:** inspect existing journey owners/tests and recorded results only
  far enough to distinguish delivered behavior from missing behavior. No new
  runtime investigation, validators, test runs, fixes or package exports.
  Aurora's missing original bundle and parked repairs remain separate.
- **Required output:** each child names the exact player/crew action and finish,
  runtime owner, existing check or missing check, dependencies, estimate, failure
  stop and next action. Label implementation, qualification and external gates
  explicitly. An already delivered behavior is not a new implementation task.
  Each implementation child should take 30–90 minutes; checks have separate
  unchanged allowances. Unknown commands/contracts are marked DEFINE, not READY.
- **Journey boundaries to resolve:** ordinary departure/transit; physical landing
  and crew exit; survey with durable once-only reward; reboard/ascent/home dock.
  These are candidate boundaries, not accepted or scheduled child tasks. The
  final continuous journey must still pass; isolated stages cannot close it.
  Late join, reconnect, pilot loss and interruption remain later separate cases.
- **Proof of planning completion:** 3–5 concrete child cards in this file; each
  links its original requirement and can be executed without choosing a world,
  participant profile, success criterion or investigation scope mid-task.
  Explicitly name any missing fact that prevents a card becoming READY. Give
  the scheduled-task count separately from the 36 open parent outcomes.
- **Stop:** commit/push the cards and stop this planning task. If a contract is
  still unknown at 45 minutes, record the missing fact and a bounded definition
  task; do not turn planning into a runtime repair. Do not claim gameplay
  progress for this task. Retain the first failed result of any later execution;
  repairs are separately scheduled under the rules above.

## Decomposing later work

The backlog is not yet fully decomposed. After ROADMAP-SLICE,
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
