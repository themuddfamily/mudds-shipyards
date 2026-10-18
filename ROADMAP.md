# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file records the closed batch and next bounded planning task. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **a39e93a**, with [notes](builds/windows/MuddsShipyards-a39e93a-notes.txt).
Latest Linux package: **a39e93a**, with [notes](builds/linux/MuddsShipyards-a39e93a-linux-notes.txt).
Server Browser now offers Cancel Connection during pending Manual Join. Actual
source UI cancellation/reuse passes twice; clean paired exports, three strict
startups, privacy207 and all1,515 payload-entry bytes pass. Exported packages
have startup/artifact acceptance, not a repeated live cancellation route.
Earlier gameplay/installed transaction proofs retain their exact scopes.
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

**Latest accepted delivery: BROWSER-CANCEL and checkpointa39e93a — DONE.**
Cancel pending Manual Join from the browser; real source UI cancellation/reuse
passes twice, with paired startup/artifact acceptance. This is one production
UI outcome. Fire restart qualification remains parked at its recorded visible-
row failure after one fixture repair; neither candidate is integrated.

**Earlier accepted task: RIME-BENCH-ROUTE and checkpoint — DONE.**
Source `a8f563e39` adds select-only walking through every authored Rime survey/
return waypoint, supported by Main's real streaming/gravity owners. Focused
Rime33/default152/Ember24/Aurora27 pass. This delivers benchmark coverage,
not new planetary gameplay or native performance qualification. Paired
checkpoint `a8f563e` is published; details and limits are in delivery history.
Ember ABANDON source `e85157b4d` remains DONE (physical home dock/walk, exact31),
with packaged/durable-save/shared/hardware gates open. HULK revisit stays parked.
Sandbox, Convoy and Q4 remain parked at their recorded failures; no automatic retries.

## Earlier accepted/parked work

EMBER-ABANDON-SOURCE is DONE on `e85157b4d` (exact 31, physical home dock/walk).
HULK revisit failed its original 300 s deadline on `2298e4889`; that candidate
remains withheld, and its checkpoint is GATED. Both results and the priority
review are retained in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
No unchanged Ember rerun or further HULK diagnosis/repair is selected.
Retired-directory cleanup removed 16 clean checkouts; three containing uncommitted
work remain intact, with source refs and unique raw results preserved.

## Batch closed — one production UI delivery

BROWSER-CANCEL and paired checkpointa39e93a are DONE. RACE-PAGE-RESET static
diagnosis found an intentional owner separation, with no justified repair.
FIRE-RESTART failed before capture; its one viewport fixture repair failed the
same visible-row requirement. Both fixture candidates are withheld; no restart
or persistence defect/acceptance is claimed. Required priority review chose the
independent planning task below. No further Fire diagnosis/probe/repair/run is
selected. [Actual outcomes and archived contracts](docs/history/ROADMAP_DELIVERIES.md#fire-viewport-repair--failed-required-priority-review-complete).

Owned browser and Fire clean checkouts are removed; published builds and unique
raw are retained. Fire source38e475960 and its failed parentb5b3c5a76 are preserved
by remote hold `hold/fire-restart-viewport-20261018`. Earlier Rime/HULK/startup
failures remain parked; renaming a card does not reset the one-repair limit.

## Next task — PLAN-VISIBLE-DELIVERIES (planning, READY)

- **Parent/result:** [PLAN-ASSIGN](docs/ROADMAP_BACKLOG.md#baseline-and-ordinary-controls).
  Publish three independent, concrete player-visible implementation cards from
  the retained36-parent backlog. Planning is not a new gameplay delivery.
- **Owner/dependency:** root; clean current main after this batch. Use one
  bounded reader for an independent component if it shortens mapping. No shared
  production edits or new worktrees during this planning pass.
- **Boundary:** existing roadmap/backlog/history and read-only runtime seams.
  Prefer an actual missing control, station, activity, content or network
  behavior. Avoid a queue dominated by requalification of previously passing
  tests, new validators or a renamed parked investigation. A genuinely missing
  acceptance contract gets one bounded definition card, not an invented fix.
- **Proof:** each selected card links its original parent, identifies one exact
  player result and evidenced gap, files/owner, dependency/status, unchanged
  observable acceptance, existing verification seam, work/check budgets,
  first action, stop/repair rule and checkpoint/cleanup close. Preserve every
  original requirement and factual external gate. No speculative whole-project
  job count or release date.
- **Budget/stop:**30–45min, no engine/test/capture runs. Finish with the three
  reviewed cards or explicitly named missing facts; do not expand into research
  or implementation. Split implementation exceeding90min before execution.
- **Next/close:** compare concrete candidates in independent runtime owners,
  select three, record exact next action and commit/push. Start implementation
  after planning closes. Leave parked Fire/Rime/HULK/startup paths untouched.

## Later decomposition

Keep only the next3–5 executable cards here; archive closed cards in existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md). Other36-parent instances
remain unscheduled in the backlog. Unknown work gets one bounded definition
child. Finishing this queue does not close the whole parent, all settings,
all networking or the ten phase gates. Do not count diagnosis, tests or build
artifacts as extra gameplay features.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
