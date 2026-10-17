# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next four bounded tasks. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **505d419**, with [notes](builds/windows/MuddsShipyards-505d419-notes.txt).
Latest Linux package: **505d419**, with [notes](builds/linux/MuddsShipyards-505d419-linux-notes.txt).
The bundled Linux manager now safely retries the named interrupted uninstall.
Actual shipped-manager SIGKILL/retry/repeat preserves protected bytes and modes.
Clean exports, three strict startups, privacy207 and all1,515 payload-entry bytes
pass. This is one installer recovery delivery; earlier gameplay proofs retain
their original source/binary scopes.
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

## Next queue — four bounded tasks

ROADMAP-NEXT-CARDS is **DONE**: read-only source mapping produced these four
cards and archived the completed installer contracts. No engine checks ran in
this planning pass. No gameplay or parent completion is claimed for planning.
Baseline for selection: main `8e254a7d0`; each execution records its exact clean
candidate before running. Root owns integration, verification, commit/push and
cleanup. Implementers use separate owned worktrees; do not edit shared files
concurrently. Priority1 runs first. The two independent investigations can be
assigned alongside it without authorizing runtime edits to shared HUD/GameFlow.

| Priority / task | Status / type | Observable finish | Work budget; checks separately |
| --- | --- | --- | --- |
| 1 BROWSER-CANCEL | DONE on a39e93af4 / production UI change | Cancel a pending Manual Join from the browser and start another attempt. | 60–90 min; focused/live checks ≤15 min, original300s suite limits. |
| 2 FIRE-RESTART | READY / qualification | A Fire binding selected in Settings survives real process restart and reaches the production input sampler. | 45–60 min fixture/setup; two processes ≤300s each. |
| 3 RACE-PAGE-RESET | DONE / bounded diagnosis; contract question retained | Identify whether the ordinary Cinder race Reset/Start path agrees with durable state, or report the specific missing fact. | 30 min mapping; at most one ≤300s probe if needed. |
| 4 NEXT-CHECKPOINT | IN PROGRESS / release delivery | Playable paired packages contain accepted runtime changes with actual startup results. | 30–45 min setup/closure; established export/startup caps below. |

### BROWSER-CANCEL — pending Manual Join

Result: accepted clean source `a39e93af4e3083d002ad15b8610fe70620f5e983`.
Cold import, HUD integration33, focus navigation57 and live cancellation59 all
pass with exit0 and no diagnostics. Actual Xvfb/x11/Dummy actor performs two
visible Manual Join/ui_accept Cancel cycles, observes inactive/disconnected
transport and reusable browser, and exits0. Owned loopback endpoint receives
real handshake traffic. Source/index/cache/engine guards pass; all15 observed
owned process identities and display:99 close. Raw commands/receipts/results:
`/srv/mudds-work/browser-cancel-20261018/results/focused/`.
This delivers pending-connection cancellation; reconnect/migration/native-device
qualification remains open. NEXT-CHECKPOINT now exports this exact clean source.

- **Parent/result:** [NET-BROWSER](docs/ROADMAP_BACKLOG.md#multiplayer).
  While Manual Join is connecting, the browser presents a focusable
  **Cancel Connection** action. Activating it closes the attempt, keeps the
  browser usable and permits a new attempt. Connected sessions retain Disconnect.
- **Known gap:** `scripts/ui/hud.gd::_update_server_browser_disconnect` and
  `_request_server_browser_disconnect` only permit connected state. Existing
  `tests/server_browser_hud_integration_test.gd` explicitly expects the button
  disabled while connecting. The session status presenter already advertises
  cancel; GameFlow already routes that intent to shutdown. This is an absent
  browser affordance, not a diagnosed transport defect.
- **Owner/boundary:** root assigns one medium-effort implementer who owns `scripts/ui/hud.gd`,
  `tests/server_browser_hud_integration_test.gd`,
  `tests/server_browser_focus_navigation_test.gd` and a bounded cancellation mode
  in `tests/network/game_flow_server_browser_integration_test.gd`. Reuse
  `scripts/ui/network_session_status_presenter.gd` and GameFlow's existing cancel
  route. Dependency: none beyond a clean baseline checkout.
  No transport rewrite, planetary routes, capacity or hardware work.
  Reconnect/migration qualification remains separate; derive labels/actions from
  the existing presenter rather than inventing a second session state machine.
- **Proof:** actual visible Manual Join → pending session → focus/activate Cancel
  Connection → inactive transport/disconnected presentation → browser navigation
  still works → new Manual Join starts. Use ordinary UI accept activation. Also
  require offline button disabled, connected Disconnect preserved and a newer
  tutorial card unable to hide the browser action. Extend the two existing HUD
  tests and add only the missing live cancellation scenario to the existing
  coordinator. Give the fixture an owned non-admitting endpoint/controlled
  handshake so pending state lasts until Cancel is activated; an arbitrary
  unreachable address is not a deterministic precondition. The current live
  modes prove admission/disconnect; they do not
  already prove cancellation. Write its exact command before the first run.
- **Budget/stop:** implementation60–90min; checks separately≤15min; cold import≤600s counts as setup, outside
  the three300s checks. Use existing
  `tools/release/suite_process.py` with300s per focused/live suite, not a reduced
  deadline. Live coordinator retains original internal limits and owned private
  Xvfb peers with x11/Dummy; headless HUD checks use Dummy. Stop first failure;
  record source/defect and schedule a separate repair. After one repair, priority
  review is mandatory before another probe/run.
- **Next/close:** inspect the two named HUD methods and reuse presenter action
  state; commit the candidate before checks. Integrate accepted behavior, record
  exact focused/live results and gate NEXT-CHECKPOINT on it. Remove owned clean
  checkout after publication; preserve unique work/failure logs.

### FIRE-RESTART — one keyboard binding

- **Parent/result:** [INPUT-REMAP](docs/ROADMAP_BACKLOG.md#performance-controls-accessibility-and-audio).
  Qualify changing Fire to F13 from the visible Settings row, saving to the real
  private production store, exiting and reloading in a distinct process. The
  reloaded row, InputMap and production local input sampler must agree.
- **Known evidence boundary:** `tests/settings_ui_test.gd` covers row capture
  and live map; `tests/runtime_settings_production_persistence_test.gd` injects
  a fake filesystem and recreates Main in-process. Neither inspected fixture
  proves this exact real-file/distinct-process composition. No remapping bug is
  claimed. This does not replace the externally blocked original Settings route.
- **Owner/boundary:** root (may delegate to one medium-effort qualification agent);
  fixture ownership stays under `tests/` beside the existing settings tests.
  Reuse HUD `begin_input_binding_capture`, GameFlow's production settings store
  and `scripts/control/local_ship_input_source.gd` sampling. No production edits
  until a specific defect is reproduced; any repair becomes a separate card.
  Dependency: none beyond a clean baseline checkout and private writable store.
  No physical-device, controller or full Settings acceptance claim.
- **Proof:** writer uses the visible row and raw F13 key event, production save,
  and exits0. A different PID loads the same private disk store through normal
  Main startup, shows F13 for Fire and samples Fire on F13 press/release through
  the production input source; former desktop binding must not fire. Preserve
  existing gamepad bindings and unrelated seeded store data. Do not substitute
  `Input.action_press`, direct profile seeding or MemoryFilesystem for this path.
  Both processes must exit0 with explicit stage completion, then be reaped.
- **Budget/stop:**45–60min fixture/setup; one writer and one reader≤300s each,
  headless/Dummy/private XDG. First action: extend the smallest existing fixture
  with writer/reader modes and record exact invocation/isolation before execution.
  If no clean way to observe the sampler is found within the budget, stop with
  that missing seam; do not build a generic framework. Stop first failure; retain
  source and exact bytes. A pass closes this case without a gratuitous rerun.
- **Close:** record exact commit/process/file/result scope, commit/push useful
  qualification fixture and remove owned disposable checkout. No new build is
  required for a test-only pass; a runtime repair requires NEXT-CHECKPOINT.

### RACE-PAGE-RESET — reconcile one ordinary route

Result: static trace complete on `29a8d9d75` source (unchanged production
files on current main). Cinder page owns a separate best-result/receipt-only
session; Activity Board owns the durable GameFlow race session. Existing comments
and `cinder_race_best_persistence_roundtrip_test.gd` explicitly require fresh
binding idle with retained best, consumed receipt and no replayable completion.
Page Select chooses a presenter card, not GameFlow's selected activity. No defect
is established and no engine/probe ran. Do not silently unify these owners. A
future unification needs an explicit product requirement; this diagnosis is not
fresh-process runtime qualification. Exact trace is in delivery history.

- **Parent/result:** [ACT-HUD](docs/ROADMAP_BACKLOG.md#activities-and-planetary-journeys),
  Race only. This is diagnosis: establish whether completed/paid race → Cinder
  page Reset → select Race → Start → fresh Main agrees with persisted state.
  No discrepancy or repair is assumed.
- **Known seam:** GameFlow `_reset_nearby_activity` dispatches the Cinder race
  to `nearby_sector_activity_binding.gd::reset_race`; production lifecycle tests
  instead exercise `reset_active_activity`. Detached retained-feedback tests
  supply snapshots. Trace whether both paths actually share durable ownership.
- **Owner/boundary:** root (may delegate to one medium-effort reader), read-only
  production ownership. Dependency: none beyond a clean baseline checkout.
  Inspect `scripts/game/game_flow.gd`,
  `scripts/world/nearby_sector_activity_binding.gd` and
  `scripts/ui/nearby_sector_activity_presenter.gd`; anchors are existing
  `tests/cinder_race_retained_feedback_test.gd` and
  `tests/cinder_race_session_save_restore_test.gd`. Do not rerun the known-timeout
  full lifecycle suite or touch other activity families.
- **Proof/budget:**30min static trace, at most one concrete hypothesis and one
  ≤300s headless/Dummy/private-store probe if necessary. Record authority state,
  durable race record, rendered row and enabled actions across reset/start and
  fresh Main; check pending reward, retained best and generation/once-only state.
  Seed only declared fixture preconditions; do not claim canonical flight or a
  real completed journey. Write exact probe command before running it.
- **Next/stop/close:** trace the two reset paths first. End with either an exact
  reproduced mismatch and responsible runtime owner plus a30–90min repair card,
  a demonstrated consistent route (no repair), or the precise unresolved fact.
  No second hypothesis/probe, production edits, new validators or checkpoint
  during diagnosis. Record actual result, commit/push and clean owned scratch.

### NEXT-CHECKPOINT — accepted runtime changes only

- **Parents/result:** [PACKAGE-WIN / PACKAGE-LINUX](docs/ROADMAP_BACKLOG.md#recovery-packages-captures-and-release).
  Publish paired playable packages exposing BROWSER-CANCEL and any separately
  accepted runtime fix. This is release work, not a second gameplay outcome.
- **Dependency/owner:** root; now ungated by accepted a39e93af4, exporting that clean commit.
  Requires a clean integrated runtime commit and
  its focused checks pass. FIRE-RESTART/RACE-PAGE-RESET do not block a passing UI
  change merely because their independent qualification/diagnosis is unfinished.
- **Boundary/proof:** existing safe export scripts; Windows EXE/ZIP/notes in
  `builds/windows/`, matching Linux ELF/archive/notes/export result in
  `builds/linux/`. Require direct/archive Linux and Windows-payload startup exit0
  plus STARTUP_MENU_READY_OK, existing privacy check, exact package membership,
  manager/binary bytes and modes, ZIP CRC, stock PE and strict PCK entry-byte
  comparison. Record actual mismatches; do not silently accept them. Native
  Windows remains NOT_RUN under the execution hold.
- **Budget/stop:**30–45min setup/closure; import≤600s, each export≤930s, each
  startup≤330s, privacy≤300s. Existing focused checks retain their limits; no
  automatic whole-matrix or unrelated installed-transaction rerun. Headless/Dummy,
  independent abort and owned child cleanup. Stop at first required failure,
  retain previous accepted505d419 and schedule any repair separately.
- **Next/close:** once ungated export from the exact clean accepted commit;
  publish verified artifacts with concise player-visible notes and actual limits.
  Independently review package scope, remove the owned clean source checkout,
  retain unique raw results, update latest checkpoint and commit/push. No hosted
  CI, Downloads, native hardware/audio/human/full-release claim.

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
