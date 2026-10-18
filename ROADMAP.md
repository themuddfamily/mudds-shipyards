# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
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
or persistence defect/acceptance is claimed. Required priority review chose an
independent planning pass, now closed with the production queue below. No further Fire diagnosis/probe/repair/run is
selected. [Actual outcomes and archived contracts](docs/history/ROADMAP_DELIVERIES.md#fire-viewport-repair--failed-required-priority-review-complete).

Owned browser and Fire clean checkouts are removed; published builds and unique
raw are retained. Fire source38e475960 and its failed parentb5b3c5a76 are preserved
by remote hold `hold/fire-restart-viewport-20261018`. Earlier Rime/HULK/startup
failures remain parked; renaming a card does not reset the one-repair limit.

## Next queue — two production fixes and a checkpoint

PLAN-VISIBLE-DELIVERIES is DONE on baseline `1d1795625`: two independent runtime
changes are grounded in source; the requested third station implementation has
no evidenced defect and remains gated as described below. No engine/test/capture
runs or scratch worktrees were created during planning. This is planning progress,
not delivered gameplay. Root owns integration and final decisions.

| Task | Status / owner | Player-visible finish | Work budget; separate checks |
| --- | --- | --- | --- |
| BROWSER-SESSION-GENERATIONS | DONE on9be5c833a / root | A valid session remains listed when another host has a higher capacity generation. | 60–90min; focused checks≤10min, original300s each. |
| DEFENSE-BRIEFING | DONE on9be5c833a / root | Defense briefing names the actual physical-board start/reset and protected-assets objective. | 30–45min; focused checks≤10min, original300s each. |
| VISIBLE-CHECKPOINT | IN PROGRESS / root | Paired playable packages contain accepted changes with actual startup/artifact results. | 30–45min setup/closure; existing caps below. |

### BROWSER-SESSION-GENERATIONS — retain independently valid sessions

Accepted browser source74ddbea911 and defense source79996ba87d are combined
in clean frozen `9be5c833a8608900e7af71b344be948dd5d23722`. One cold import and
four focused suites pass: browser presenter83, browser HUD40, tutorial319,
board presentation16; each exits0 with exactly one expected terminal marker,
no diagnostics and unchanged source/index/cache/engine. All13 observed owned
process identities close. Independent code/helper review GO. Raw commands,
results and snapshots: `/srv/mudds-work/visible-fixes-20261018/results/focused/`.
Browser proof uses real directory inputs and presenter/HUD, not running host
migration peers. VISIBLE-CHECKPOINT now exports this exact accepted source.

- **Parent/result:** [NET-BROWSER](docs/ROADMAP_BACKLOG.md#multiplayer). Two
  independently valid directory rows must both be listed when their hosts have
  different capacity generations; updating one host must not hide the other.
- **Evidenced gap:** `scripts/ui/server_browser_presenter.gd::present_result`
  computes one global `_latest_capacity_generation` across every row, then drops
  rows below that maximum. Existing `tests/ui_server_browser_presenter_test.gd`
  even expects generation4 session `new` to hide distinct generation3 session
  `stale`. But `network_server_browser.gd::_validate_entry` retains capacity
  generation per row, and `network_enet_session_adapter.gd::_decorate_hosted_directory`
  sets it from that hosted session's migration generation. These are not a shared
  clock across unrelated hosts. LAN entries independently begin at generation1.
  This is a source-grounded suppression bug; no runtime reproduction ran in planning.
- **Owner/boundary:** one implementer owns only the presenter and
  `tests/ui_server_browser_presenter_test.gd`, with a minimal row-visibility
  regression in `tests/server_browser_hud_integration_test.gd`. Real directory
  owner is a fixture seam, not a rewrite target. Leave transport, migration,
  browser cancel behavior, protocol/schema versions and validators unchanged.
  No dependency beyond the clean baseline; disjoint from DEFENSE-BRIEFING.
- **Proof:** use the existing real directory/presenter path with two valid
  distinct host/session entries at capacity generations4 and1; both rows and
  their exact occupancy appear in presentation/HUD. Advance hostA while hostB
  remains1: both remain. An older capacity update for the *same* session must
  still be ignored, without hiding another valid session. Existing stale
  request/source-directory/tick fencing and close-view reset checks remain.
  Close/reopen the view and accept fresh generation1 sessions; any per-session
  retained state must be bounded to supported rows and have explicit close/expiry
  behavior. Do not replace directory freshness with capacity counters.
- **Budget/stop:**60–90min implementation; two focused suites≤300s each. Cold
  import/setup separately≤600s if needed. Run headless/Dummy in private profiles
  via existing `suite_process.py` and assess existing suite sentinels/diagnostics.
  Record exact frozen commit and commands before running. Stop first failure;
  any bounded repair is a separate card. Failure plus one repair triggers priority
  review before further diagnosis/run; no larger networking investigation.
- **Next/close:** add the two-host regression, replace the global comparison
  with identity-scoped handling preserving actual freshness, run focused checks,
  commit/push and hand accepted source to VISIBLE-CHECKPOINT. Clean only owned
  disposable checkout after publication, retaining unique failures. This qualifies
  the selected listing behavior, not real-host migration or full multiplayer.

### DEFENSE-BRIEFING — describe the physical-board controls

Accepted source79996ba87d is integrated through frozen9be5c833a above.
Defense-specific semantic, keyboard/controller/accessibility/remap and real HUD
composition checks pass in tutorial319; existing board presentation16 also passes.
Physical start-to-briefing and full combat qualification remain separate.

- **Parent/result:** [CONTROL-FIX](docs/ROADMAP_BACKLOG.md#baseline-and-ordinary-controls),
  control/tutorial tuning. Station-defense instructions must explain the actual
  on-foot board admission, combat-craft/protected-assets objective, and returning
  on foot to that board to Reset/retry when required by its current state.
- **Evidenced gap:** `scripts/ui/activity_tutorial_presenter.gd` defense copy
  says stay in a perimeter ring and fall back to the ring. GameFlow
  `_start_physical_station_defense_board` / `_reset_physical_station_defense_board`
  gate both actions on foot and within the real board's range. The existing
  `nearby_sector_activity_presenter.gd` already says protect station assets and
  Reset at the defense board; the production
  objective protects real station assets. Ring entry is not a start/reset or
  resume-authority mechanism; preserve any existing resumable/lull semantics.
- **Owner/boundary:** one implementer owns only
  `scripts/ui/activity_tutorial_presenter.gd` and
  `tests/activity_tutorial_presenter_test.gd`. No HUD/GameFlow/combat/persistence
  changes, no new recovery/resume UI and no edits to other briefings. Dependency:
  clean baseline only; can proceed alongside the browser presenter task.
- **Proof:** extend existing semantic briefing checks for defense keyboard,
  controller and accessible copy, resolved Interact/Fire prompts, truthful next
  action and board Reset/retry. Use existing real HUD composition coverage in
  the tutorial suite, and retain `station_defense_activity_board_readability_test`
  terminal/recovery presentation and direct-interaction behavior. The player
  inspection recipe is on-foot board arrival → nearby-page Start within range →
  first briefing naming the actual start/next action. Automated acceptance for
  this copy-only task is the real HUD composition for defense/device variants,
  plus existing board presentation checks. The current tutorial accepted-start
  loop excludes defense; do not claim automated physical start-to-briefing or
  full combat qualification. Guidance must name board Reset/retry when required,
  without claiming ring entry resumes combat or reset is always mandatory.
- **Budget/stop:**30–45min implementation; two existing suites≤300s each, import
  setup separately≤600s. Use headless/private display/Dummy and original limits;
  write the exact focused commands before running. Do not build a large new
  admission/flight fixture for the copy change; physical route qualification
  remains a separate backlog instance. Stop first failure;
  one separately recorded repair then priority review, no automatic reruns.
- **Next/close:** add defense-specific semantic assertions, correct only authored
  copy, verify, commit/push and package via VISIBLE-CHECKPOINT. Remove the owned
  clean checkout after integration/publication; preserve unique failed raw. Native
  device/audio/human review and full combat/route gates stay open.

### VISIBLE-CHECKPOINT — package accepted runtime changes

- **Parent/result:** [PACKAGE-WIN / PACKAGE-LINUX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
  Root exports paired playable artifacts from the exact clean integrated source.
  GATED on at least one accepted production card and its focused checks; failure
  of the independent other card does not block publishing an accepted change.
- **Boundary/proof:** existing safe export scripts, Windows EXE/ZIP/notes in
  repository `builds/windows/`, matching Linux ELF/archive/notes/export result in
  `builds/linux/`. Require actual exit0+STARTUP_MENU_READY_OK for direct/archive
  Linux and Windows-payload startup; existing privacy, strict PCK entry-byte
  parity, stock PE, exact tar membership/bytes/modes and exact EXE/notes ZIP CRC.
  Preserve factual source-only UI proof versus exported startup/artifact scope.
- **Budget/stop:**30–45min setup/closure; import≤600s if needed, exports≤930s each,
  startups≤330s each, privacy≤300s. Reuse a verified unchanged import/cache rather
  than repeating it. Headless/Dummy, owned abort/reap and no active desktop.
  Stop first required failure, retain accepted checkpointa39e93a and record repair
  separately. No CI, Downloads, native Windows or new qualification claims.
- **Next/close:** after focused acceptance integrate disjoint changes, export,
  publish verified artifacts with player-visible notes and actual limits,
  independently review artifact identity/scope, update latest build, commit/push
  and remove owned clean scratch. Native hardware/device/audio/human, matrix,
  signing/endurance/release gates remain open.

### Third implementation candidate — station finding still missing

STATION-FINDING[Central operational view] is DEFINE/GATED, not a READY repair.
Root needs one source-tied current image or ordinary-action reproduction showing
an actual layout/readability defect before assigning production ownership. The
bounded station/help/role read found implemented paths rather than a supported
missing behavior. Original `capture-station-operations` remains parked at0/7
images and its unchanged300s software-renderer compilation stall; that does not
identify an art defect and is not scheduled for another unchanged run.

Once usable existing source-identified evidence or a separately justified changed
capture environment exists, one30min definition task may compare one Central
view with its ordinary walk/Interact route, preserving collision/berth clearance.
It ends with one concrete finding and a separate30–90min repair card, or the exact
missing artifact. No unsupported topology, new capture workaround or speculative
signage/art task is authorized by this placeholder. Original STATION-ART/
ART-FINDING parent scope remains in the backlog.

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
