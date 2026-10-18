# Development roadmap

**Next: keep input-binding conflict choices visible and reachable in Options.**
The game is a playable development alpha. **All 36 broad requirements and all ten
phase gates remain open.** This file holds the executable queue; the
[named backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes),
[36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes),
[original specification](docs/history/ROADMAP_SCOPE_20261017.md) and
[delivery history](docs/history/ROADMAP_DELIVERIES.md) retain full scope/results.

## Current delivered position

| Outcome | Actual proof / limit |
| --- | --- |
| Immediate client landing edge retained exactly once | Runtime `2c73494a4`; old-runtime failure reproduced, consumer40/ship_command79 pass. Source/ownership/session boundaries revoke pending input. |
| Fresh playable checkpoint **f90547c** | [Windows notes](builds/windows/MuddsShipyards-f90547c-notes.txt), [Linux notes](builds/linux/MuddsShipyards-f90547c-linux-notes.txt). Adds on-foot release-driver support; both exports, three strict startups,1515 matching payload entries and exact archives pass. |
| Ordinary two-client Jovian short sortie and physical home return | Source `4c9c764e9` PASS in138.915s: normal boarding/real seats,5m departure/brake, accepted landing, strict home dock/lease/landed commit and both retained clients consume original pilot/ownership generations and arrival. All three peers exit 0; marker 1; diagnostics 0. |
| Actual on-foot recovery in exported/archive Linux checkpoint | f90547c real-file SIGKILL/distinct restart; supported awake unseated player, ordinary walk0.525555m+Interact boarding, conserved convoy and receipts1→2 once. Private headless/Dummy and disclosed craft-placement fixtures; no fullflight/native-device claim. |
| Earlier passenger chair/HUD, lifecycle, browser/briefing deliveries | Retain their recorded scopes; no whole craft, parent or phase closes. |

The latest four-card batch ends with **3 DONE, 1 FAILED**: on-foot driver,
paired checkpoint and actual exported/archive recovery pass; the 16:10 UI check
stops at offscreen binding-conflict choices. Original same-frame fixture and
compile failures, their single corrections and all raw remain in
[delivery history](docs/history/ROADMAP_DELIVERIES.md). Qualification is not a new
gameplay feature or a whole-project percentage. Earlier two-client return remains
its accepted source-specific scope.

**Still unqualified:** dedicated server, postdock exit/reuse, canonical shared
world journeys,30-minute endurance, devices/native GPU/audio and final release.
Current full matrix NOT_RUN; last unfiltered f85957f failed 11 of 1,045 suites.
Native Windows/human-review owner exclusions remain factual NOT_RUN.

## Next two cards

**1 READY, 1 GATED.** These are executable task instances, not the remaining
whole-project job count. Root owns integration. Do not reopen parked failures.

| Task | Type / state | Observable finish | Work estimate; checks separate |
| --- | --- | --- | --- |
| UI-CONFLICT-REVEAL | Production UI / READY | Binding-conflict choices remain visible and focused when Options scrolls at1920x1200. |30–45 min implementation/review; compile300s and existing selected check300s. |
| CHECKPOINT-PAUSE-CONFLICT | Build / GATED on accepted repair | Fresh paired package contains the accepted UI repair. |15–25 min artifact work; export900s/platform and startup300s each. |

### UI-CONFLICT-REVEAL — make the focused conflict choice visible

- **Parents/result:**12/29. A player rebinding a conflicting key can see and
  reach Replace/Cancel in the live Options scroller at the authored UI scales.
- **Reproduction:** existing `tests/ultrawide_layout_test.gd` at `4128526c9`,
  `-- --pause-16x10-only`, actual Main1920x1200/headless/Dummy, original300s.
  At requested0.75, binding_conflict focuses InputBindingConflictReplaceButton
  at(681.75,1815.75,252.75,24), outside safe bounds and clip; scroll450.
  Eighteen observations precede the failure; later states/scales are NOT_RUN.
  Ordinary options re-entry passes after the recorded fixture timing correction.
- **Ownership/boundary:** existing conflict presentation/focus/scroll owners in
  `scripts/ui/hud.gd`; existing fixture only for a demonstrated fixture defect.
  Preserve capture/conflict decisions, persistence, focus identity and scroller
  liveness checks. No broad Options redesign or new harness/validator.
- **Proof:** explicit compile and one existing full selected fixture under its
  original300s cap at0.75/1.0/1.6 and finite pause/options roster. The focused
  choice must fit both safe bounds and its scroll clip, with live focus. Preserve
  every existing criterion and requested/effective scale reporting. Native
  devices, rendered readability and actual persistence transactions stay separate.
- **Execution:** READY/root; inspect the demonstrated conflict reveal/scroll
  ordering and make one bounded production correction. One diagnostic hypothesis
  permits one probe if needed. Budget30–45 min; split before90. First new failure
  stops with source/view/control/scale recorded; no automatic second repair.
  Initial qualification and fixture-correction failures remain cumulative.
- **Close:** actual result/source/limits, commit/push, fresh checkpoint if accepted,
  and cleanup of owned disposable work. This does not close every UI aspect group.

### CHECKPOINT-PAUSE-CONFLICT — ship the accepted UI correction

- **Parents/result:**6/32; gate on accepted clean UI repair source. Use the same
  existing safe sequential Windows/Linux export and publication workflow as
  checkpointf90547c, pinned engine/templates/private XDG; preserve HOME/CODEX_HOME.
- **Proof:** relevant focused checks, actual PCK byte parity, exact archives and
  metadata/stock PE checks, direct/archive Linux and actual Windows payload each
  strict startup exit0+exactlyone STARTUP_MENU_READY_OK/no original diagnostics.
  EXE/ZIP/notes and matching Linux artifacts belong in repository builds/.
- **Execution/budget:** GATED/root;15–25 min artifact work, original900s/platform
  exports and300s/startup separately. One export/platform; first failure stops.
  Record actual scope/limits, commit/push notes/index and remove owned duplicates.
  Native Windows/GPU/device/human/full-release gates remain open.

## Parked work and external waits

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox
recovery, Convoy/Patrol/Q4/Q5 and the two software-renderer capture stalls retain
their original failures/reopen conditions. No unchanged retry is selected.
Settings originals, Aurora original arrival bundle and release capacity choice
remain existing external waits; do not ask settled questions again. The dedicated
server/two-client baseline remains authorized independently of larger capacity.
Bomber comparison now identifies one further precise interpretation: additional
role/count, concrete navigation action and physical access are unspecified. It
is not an approved pilot-only deferral; no invented crew feature is scheduled.

Owned helm/return/on-foot/UI checkouts, profiles/helpers and duplicate builds are removed;
unique raw/source refs and public builds remain. Three older dirty retired
checkouts remain protected. Scratch belongs under `/srv/mudds-work/`.

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
- Keep at most eight bounded cards visible; run only READY cards and at most one dependent
  chain at a time. Review priorities before replenishing the queue.
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
Keep at most eight cards in this queue; refine later backlog items when their
dependencies are known. Do not turn every possible test combination into a speculative queue.

| Field | Required content |
| --- | --- |
| Task / parent | Stable short name, linked parent requirement and one concrete instance. |
| Result | One sentence describing what the player can do, what the build delivers, or which existing behavior is being qualified. Label qualification and planning explicitly. |
| Boundary | Affected component/files and explicit exclusions; new findings become separate tasks. |
| Proof | Existing command or ordinary player action, exact expected result, source/build and unchanged limits. A test count alone is insufficient. |
| Budget | Implementation/diagnosis estimate, check runtime separately, and the point at which work stops for reassessment. |
| Execution | Owner, dependency, READY/GATED/IN PROGRESS/DONE/FAILED/WAITING, one exact next action, and the action after failure. |
| Close | Actual result and limitation, commit/build reference, cleanup of owned disposable files. |

Prefer tasks expected to take 30–60 minutes of implementation; 90 minutes is
the split boundary, not a target. Split larger
work before execution. Long established checks retain their required duration
and are estimated separately. A parent closes only when its original acceptance
holds; completing a small child does not close the parent.

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
