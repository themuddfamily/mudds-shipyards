# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **4270d71**, with [notes](builds/windows/MuddsShipyards-4270d71-notes.txt).
Latest Linux package: **4270d71**, with [notes](builds/linux/MuddsShipyards-4270d71-linux-notes.txt).
This development checkpoint includes source-tested native Ember observations.
Paired exports, three strict startups, packed privacy232 and all1515 payload
bytes pass. Native observer window-close smoke FAILED/open; full physical
journey, durable-save/shared and hardware/release acceptance remain separate.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Current position and next action

**36 broad parents and all ten phase gates remain open.** The
[concrete child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
separates named outcomes from missing definitions; it is not a remaining-job
count. The next batch has **one player outcome in two execution steps**, below.
Do not report those steps as two gameplay features or a project percentage.

- **Latest source delivery:** native Ember observer on4270d7187; private routing,
  actual active-craft/lifecycle observations and read-only source checks232/20 pass.
  Paired development checkpoint4270d71 is published. Native window-close smoke
  FAILED and stays open; no physical journey is qualified.
- **Next:** run the committed ordinary-input VIP caller once through the full
  outward/interaction/return route. Caller implementation and cold import are
  complete; walking is NOT_RUN. Do not restart Ember window diagnostics.
- **Earlier delivered:** browser per-session generations and accurate defense
  briefing on9be5c83 retain their source/UI scopes.
- **Parked:** Fire restart, Rime shared arrival, HULK revisit, Sandbox recovery
  walk, Convoy/Patrol startup and Q4/Q5 retain their failures and repair limits.
- **External waits:** original Settings artifacts, original Aurora arrival bundle
  and final capacity choice. The original server/two-client baseline remains
  authorized independently; do not ask settled questions again.
- **Cleanup:** this task's owned clean source checkout is removed after artifact
  audit; raw/public builds remain. Three older checkouts with unique uncommitted
  work stay protected. Scratch belongs under `/srv/mudds-work/`.

Report the named result, actual proof, next action and estimate. Source checks,
planning or test totals do not establish whole-parent or hardware completion.

## Next batch — VIP reception round trip

**Player outcome:** from a fresh ordinary spawn, walk to VIP reception, open its
normal door, sit and stand using Interact, and walk back to the original spawn
without rescue. This is qualification of existing gameplay, not a claimed new
feature. STATION-ROUTE[VIP] stays open until this whole route passes. Other station
branches and all 36 parents retain their original scope in the backlog.

| Step | Status / owner | Exact finish | Estimate and stop |
| --- | --- | --- | --- |
| STATION-VIP-CALLER | DONE (implementation only) / root | One source test drives the real menu and player input through the route below, with no actor/camera pose writes or direct interaction calls. | 45–75min implementation; stop at75min if unfinished and record the precise remaining work. |
| STATION-VIP-WALK | READY / root | One uninterrupted run passes the complete route, seat interaction and supported return with the same player. | Up to900s route check; cold import/preflight estimated separately at10–15min. First failure ends this qualification attempt. |

Two steps are sufficient for this batch; do not invent extra tasks to fill a
quota. A demonstrated runtime defect gets its own bounded repair card before
work starts. A clean passing route closes this child without speculative repairs.

### Shared source-derived route and acceptance

Definition was a read-only source pass against `cee707916`; no engine or walking
check ran. Mapping and limitations are recorded in
[delivery history](docs/history/ROADMAP_DELIVERIES.md#vip-route-definition--static-only).

- Start fresh Main through the production boot path with an isolated empty
  profile. Boot `scenes/boot.tscn`, wait for initialized Main and activate the
  actual HUD `IntroBeginShiftButton` through UI input; dismiss a visible
  `RuntimeStatusDismissButton` through the same input path.
  Keep the authored `PlayerSpawn` at world `(-8.5, 0.18, 11)`.
- Walk via central X0, Z30, Aft approach `(0,0.15,46.3)`, lower junction
  `(0,0.15,55.2)`, stair base `(-5.7,0.15,51)` and top `(-5.7,4.35,60.8)`.
  Use the upper bypass `(-4.6,4.2,63)`, `(-3.6,4.2,63)`, `(-3.6,4.2,67)`;
  then approach VIP at `(-5.15,4.35,68.9)`.
- Use ordinary Interact on `AftJunctionStack/VIPAccess`; wait for its actual OPEN
  state and removed blocker before crossing. The upper floor and threshold meet
  at world Z70.6. The suite origin is `(-5.15,4.2,70.6)`.
- Enter through suite-local `(0,0.15,1.5)` and reception `(-1.3,0.15,4.6)`.
  Approach `Structure/Fitout/Armchair03/StationSeatInteraction` across the front
  plate near local Z5.5, then along X≈1.99 to its entry near `(1.99,0,7.49)`.
  This final approach is derived from geometry and remains untested. HostDesk
  and HostDeskReader are geometry, not interactions. Require the normal SIT and
  STAND actions on `RECEPTION ARMCHAIR 03`.
- Reverse the supported lanes and return within0.5m horizontally of the original
  spawn, on the original central deck, with ordinary movement still usable.
  Observe the same player identity throughout, real ground/collision support
  except the normal stair/seat transitions, and no recovery/rescue teleport.
  Never stage positions, respawn actors, force door/seat state or call private
  coordinator interaction methods to make the route pass.

### STATION-VIP-CALLER — implement one ordinary-input route

- **Ownership/boundary:** root owns `tests/vip_reception_round_trip_test.gd` and
  its Godot UID only. Exercise real Main, menu, player, door and StationSeat.
  No runtime geometry, art, renderer, native observer or unrelated test changes.
- **Input seam:** dispatch UI accept and gameplay action press/release through
  `Input.parse_input_event`; use ordinary mouse-motion/controller look input
  through PlayerController (`get_look_yaw()` and mouse sensitivity are read-only
  steering observations). Do not set body/camera transforms or inject an
  interaction candidate. Reuse the existing production-boot/menu activation
  conventions in `tests/network/game_flow_server_browser_integration_test.gd`
  rather than calling `game.start_shift()` directly.
- **Proof:** declare `test-matrix-display: input-only` and the existing applicable
  `test-matrix-timeout-seconds: 900`. Fail fast with the named route leg and
  actual obstruction/state. Success requires the full shared acceptance, one
  `VIP_RECEPTION_ROUND_TRIP_OK` marker and exit0. Release all held actions,
  restore mouse capture and free Main on success/failure; outer process cleanup
  remains independent of the game's menu. Preserve raw failures.
- **Implementation result:** the caller and generated UID are committed with
  this card update. Static review/catalog discovery and isolated cold import
  pass; no route has run yet. It contains32 walking legs and normal door/seat
  interactions. Caller completion is test capability, not a walking pass.
- **Failure/close:** at the implementation estimate boundary, record the missing
  seam or unfinished code. Do not turn fixture work into a renderer investigation.

### STATION-VIP-WALK — qualify the complete player outcome once

- **Dependency/source:** the committed caller, pinned existing Godot4.7.1 editor,
  fresh clean source checkout and accepted cold import. Record exact source and
  engine identity before running; do not qualify a dirty or unspecified source.
- **Command:** from that checkout, with `GODOT_BIN` set to the pinned editor:

  ```sh
  GODOT_BIN=/tmp/mudds-tools/godot-4.7.1/godot
  xvfb-run -a -s '-screen 0 1280x720x24' env -u WAYLAND_DISPLAY \
    bash tools/release/run_test_matrix.sh --godot "$GODOT_BIN" \
    --mode graphical --display-driver x11 --audio-driver Dummy --jobs 1 \
    --scope vip_reception_round_trip_test --timeout 900 --import-gate never \
    --results-dir /srv/mudds-work/vip-round-trip-results
  ```

  The existing input-only runner selects the dummy renderer with real physics
  and input. It must never use the active desktop. Run import separately within
  its established600s cap; the900s route cap is unchanged. Use the existing
  independent supervisor/abort and verify owned process/input/display cleanup.
- **Finish:** exit0, exact success marker, no diagnostics and every shared route
  criterion, including physical return. A timeout, missing interaction or rescue
  is FAILED; test totals and menu startup alone cannot pass this card. This is a
  source/input qualification, not native GPU, Windows or human acceptance.
- **After failure:** record the first leg/obstruction and stop; define one
  diagnosis/repair card with unchanged acceptance before another attempt. After
  one failed task plus one attempted repair, review priorities before further
  probes. No cap extensions, route clipping or unchanged reruns.
- **Close:** record actual result in delivery history, commit/push the updated
  status and remove this task's owned disposable checkout after preserving raw.
  If a separate runtime repair is required, its meaningful gameplay checkpoint
  must include a fresh safe Windows build and strict package startup checks.
  This caller-only batch does not justify re-exporting unchanged gameplay.

## Parked Ember qualification — source shipped, native smoke still open

Checkpoint4270d71 contains the source-checked native observer. The exact native
normal-window-close smoke remains FAILED: first dummy-renderer close timeout,
then no visible protocol-capable window, then software-GL V-Sync warning. Required
priority review parks all further native-window work this batch; do not rerun or
filter diagnostics. The published development build has actual strict startup/
artifact acceptance, not completed native observer/journey qualification.

The unchanged external SceneTree driver remains unsupported on frozen9be5c83;
no full packaged abandonment journey ran or inherited source acceptance. Exact
contracts, all failed raw, source232/20 passes, package results and limitations
remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md#ember-native-observer-checkpoint--published-with-native-smoke-open).
Native-window and full physical/durable/shared/release gates remain open.

## Station finding still missing — DEFINE/GATED

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

## Working constraints

Follow [AGENTS.md](AGENTS.md): Dummy audio for every automated Godot invocation;
headless/private display, explicit x11 under Xvfb, independent abort and owned
input/process cleanup. Keep GitHub Actions disabled and respect the Windows
execution hold. Meaningful runtime/graphics checkpoints require clean Windows
EXE/ZIP/notes and strict startup exit 0 plus `STARTUP_MENU_READY_OK`; artifacts
belong in repository `builds/`. Scratch belongs under `/srv/mudds-work/`.
Project completion still requires every original promise and final-candidate gate,
or an explicit owner deferral beside that promise. No percentage from tests or commits.
