# Development roadmap

**Next: ordinary cargo selection and offline Jovian boarding only; thrust and delivery are separate cards.**
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
| Fresh playable checkpoint **1cf1022** | [Windows notes](builds/windows/MuddsShipyards-1cf1022-notes.txt), [Linux notes](builds/linux/MuddsShipyards-1cf1022-linux-notes.txt). Conflict choices reveal after layout; disappearing repair action hands focus to live Save. Both exports, three strict startups and exact package audits pass. |
| Ordinary two-client Jovian short sortie and physical home return | Source `4c9c764e9` PASS in138.915s: normal boarding/real seats,5m departure/brake, accepted landing, strict home dock/lease/landed commit and both retained clients consume original pilot/ownership generations and arrival. All three peers exit 0; marker 1; diagnostics 0. |
| Actual on-foot recovery in exported/archive Linux checkpoint | f90547c real-file SIGKILL/distinct restart; supported awake unseated player, ordinary walk0.525555m+Interact boarding, conserved convoy and receipts1→2 once. Private headless/Dummy and disclosed craft-placement fixtures; no fullflight/native-device claim. |
| Pause/options16:10 selected source qualification | 1cf102298 PASS:26 focused repair assertions;948 layout assertions/96 observations,32 states at requested.75/1/1.6. Original criteria/caps retained; device/render/persistence transactions and other aspects remain open. |
| Fresh hub→Annex service→hub |9af57671d selected route PASS81.387s: same supported Player, actual kits5→6 and one Annex update/Aft unchanged. Active-craft/kit-spend fixtures disclosed; default caller unchanged. |
| Earlier passenger chair/HUD, lifecycle, browser/briefing deliveries | Retain their recorded scopes; no whole craft, parent or phase closes. |

The on-foot batch's failed UI qualification is now resolved by two bounded
production fixes at `1cf102298`. Its original failures, fixture correction,
first conflict correction's repair-focus failure and final unchanged acceptance
remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md). The paired
checkpoint and postdock source definition are complete. Definitions and test
counts are not gameplay features or a whole-project percentage.

**Still unqualified:** dedicated server, postdock exit/reuse, canonical shared
world journeys,30-minute endurance, devices/native GPU/audio and final release.
Current full matrix NOT_RUN; last unfiltered f85957f failed 11 of 1,045 suites.
Native Windows/human-review owner exclusions remain factual NOT_RUN.

## Working queue: eight bounded cards

**1 IN PROGRESS, 1 READY, 6 GATED.** Root owns integration and closure.
Two definitions are complete: offline Jovian delivery and residual Halyard
server gameplay. They split into the eight concrete outcomes below. This is a
local work queue, not a remaining-project job count. Original36 parents and all
ten phase gates remain open. The accepted Annex route and parked Jovian exit/
reuse cards remain in the [backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
and delivery history; they do not consume active queue slots.

| Task | State | Observable finish | Implementation estimate; checks separate |
| --- | --- | --- | --- |
| KIT-BOARD | IN PROGRESS | Fresh player selects cargo, walks to Jovian and takes the real solo pilot seat. |30–45 min; compile300s + one route300s/outer360s |
| KIT-DEPART | GATED on KIT-BOARD | Ordinary thrust leaves berth, starts delivery automatically, then brakes. |30–60 min; one extended route at unchanged caps |
| KIT-DELIVER | GATED on KIT-DEPART | Physical home return transfers two kits, pays once and leaves player walking outside. |45–60 min; one extended route at unchanged caps |
| KIT-RELOAD | GATED on KIT-DELIVER | Distinct process reloads accepted delivery without duplicate kits or reward. |20–40 min; compile300s + one restore30s |
| HALYARD-APPROACH | READY planning | Freeze one ordinary spawn→airstair→hatch input route and exact caller. |30 min static comparison; no engine |
| HALYARD-BOARD | GATED on HALYARD-APPROACH | Two independent clients ordinarily board distinct pilot/passenger seats. |45–60 min; compile300s + one route300s/outer360s |
| HALYARD-MOVING-CABIN | GATED on HALYARD-BOARD | Actual departure and supported passenger walk/sit/stand/reseat while moving. |45–60 min; one extended route at unchanged caps |
| HALYARD-AUTHORITY-STOP | GATED on HALYARD-MOVING-CABIN | Real server shutdown restores both occupants to usable solo operation. |30–60 min; one selected route at unchanged caps |

**Common execution/closure:** use the named existing caller, one clean source
pin, explicit selected mode/marker and first-failure stop. Root reviews a candidate,
then runs one compile and one selected check; actual exit0, exactlyone marker and
original full-raw diagnostics0 are required. Every Godot invocation uses Dummy
audio; input runs use private Xvfb/explicit x11 and the existing input-only dummy
renderer, with independent abort and input/cursor/process cleanup. No active
user desktop. Work/check estimates are separate; split implementation before90
minutes, and keep time cumulative across diagnosis/repair. First failure records
actor/boundary/owner before a separate bounded next task; one hypothesis permits
one probe. Failed task plus one attempted repair requires priority review before
any more. Close with actual result/pin/limits, commit/push and owned cleanup,
retaining unique raw/work. Caller-only work needs no identical checkpoint;
accepted runtime repairs require separate cards and fresh paired builds.

### KIT-BOARD — select cargo and board one offline Jovian

- **Parents/result:**7/13. Same fresh Player uses normal Intro/menu, selects
  cargo, walks from actual hub spawn and uses ordinary hatch Interact to take
  the existing solo pilot seat. Stop before thrust or activity start.
- **Boundary:** root; only `tests/cargo_delivery_production_integration_test.gd`,
  proposed `--ordinary-jovian-kit-board`, default staged/recovery branch preserved.
  Plain UserDataStore with a distinct private real-file path, configured before
  Main enters the tree; no activity/save-state fixtures or injected failures.
- **Proof:** real IntroBeginShiftButton; Pause→ActivityBoardButton→
  CargoDeliveryActivityButton→ActivitySelectionBackButton→ResumeButton via
  focused ordinary activation. Use accepted network boarding STATION_APPROACH
  and its final two goals as input geometry only. Offline production boarding
  goes directly through authored waypoints to pilot; no network-cabin claims.
  Same Player/real seat, active Jovian, enabled original Input-backed source,
  START_ENGINES, physically occupied valid home freight-berth lease; selected
  cargo IDLE generation0, manifest generations1/source6/destination0.
- **Next/check:** IN PROGRESS/root. Isolated branch
  `work/jovian-kit-board-20261018`; implement/review early selector and existing
  look/walk/Interact helpers, no pose/phase/claim/candidate/start_shift/HUD-state
  writes. Compile300s, ONE selected300s/outer360s route. Preserve15s/waypoint,
  .30m horizontal/15 supported settled ticks/<.8m vertical and12s boarding.
  Selected marker `JOVIAN_KIT_ORDINARY_BOARD_OK`; no departure/landing/reload work.
- **Stop/close:** first failure ends boarding qualification; record concrete
  snapshot and next owner. Accepted seat access does not qualify delivery.
  Commit/push and owned cleanup under common rules.

### KIT-DEPART — start cargo through real departure

- **Parents/result:**13. Extend accepted KIT-BOARD with ordinary forward demand,
  actual berth release and at least5m departure along initial nose, then brake
  to≤.5m/s for one second. Never directly start or advance the activity.
- **Boundary/proof:** same existing cargo caller, accepted predecessor source.
  `_update_pilot_flow` naturally enters FREE_FLIGHT and calls existing
  `_start_default_free_flight_activity`/`request_activity_start`. Require first
  ACTIVE generation1/return objective/departure checkpoint, source6/destination0,
  current same pilot/source and actual released berth. Keep180s physics deadline
  from automatic start; no clock reset, tuning change or forced landed flag.
- **Next/check:** GATED on KIT-BOARD. Freeze a new selected continuation/marker
  before implementation.30–60 min; compile300s and one full extended300s route,
  outer360s; preserve prior approach/boarding and10s departure/10s brake bounds.
- **Stop/close:** first failure records actual input/engine/berth/activity owner;
  no automatic runtime fix. Landing/transfer/reward remain KIT-DELIVER.
  Record result/pin/limits, commit/push and owned cleanup.

### KIT-DELIVER — return two kits and walk clear

- **Parents/result:**13. Extend accepted departure with ordinary landing_assist,
  strict physical home return, exactlyone transfer/reward and usable exterior exit.
- **Boundary/proof:** same existing cargo caller and offline runtime flow;
  physical landing invokes `_on_landing_completed`/`_complete_cargo_delivery_on_return`.
  Require accepted capture/fit, strict docking, occupied valid same-hull home
  lease and SHUT_DOWN. Neutral controls until actual automatic OFFLINE; ordinary
  Interact invokes authored production disembark, then≥.5m supported controllable
  unseated ground movement by same Player. This is not manual cabin walking.
  COMPLETED generation1, source6→4/destination0→2, exactlyone accepted transfer
  `jovian_fabrication_kit_delivery_g1`, reward0→1 and none owed; normal ticks cannot
  duplicate it. No remote landing path: it deliberately skips cargo completion.
- **Next/check:** GATED on KIT-DEPART;45–60 min implementation/review. Freeze
  selected continuation/marker/pin; compile300s and one full300s/outer360s route,
  preserving180s activity deadline,8s acceptance/120s physical dock and all prior
  bounds. Exit cap is authored2×canopy_motion_time+disembarking_motion_time+1s,
  then15s ground walk. No rescue, geometry/phase mutation or deadline growth.
- **Stop/close:** record first failing owner. Preserve this run's private real
  store for KIT-RELOAD rather than fabricate/recreate completion. Keep exact
  runtime/source reference and raw; commit/push, remove disposable helpers and
  checkouts when safe, retaining the store until its consumer closes.

### KIT-RELOAD — consume the delivered save in a distinct process

- **Parents/result:**13/31. Load KIT-DELIVER's actual private store in a new OS
  process; completed delivery survives without extra cargo or reward.
- **Boundary/proof:** same cargo caller, proposed restore-only selector and
  same production persistence format/runtime. Existing MemoryFilesystem class
  delegates to real FileAccess/flush; older fresh-Main checks are disk integration
  in one OS process and remain credited. Modern Jovian save owner is
  `scripts/persistence/jovian_cargo_session_persistence.gd`, not Cinder's owner.
  Require generation1 COMPLETED/source4/destination2, same transfer receipt and
  one reward receipt after normal startup/retry ticks. No reset/start/state fixture.
- **Next/check:** GATED on KIT-DELIVER's retained real store;20–40 min. Freeze
  selector/marker/pin and prior runtime compatibility before execution; compile300s,
  ONE restore-only process30s using that exact private XDG data directory.
  Do not silently replay the already-accepted route; relevant runtime changes
  require requalification rather than transferring proof.
- **Stop/close:** mismatch is a named persistence boundary, not permission for
  new save formats or validators. Record actual result/source/store, commit/push,
  retain necessary raw and remove the consumed private profile after closure.

### HALYARD-APPROACH — define one actual airstair approach

- **Parents/result/type:**16/26; planning only. Resolve the missing ordinary
  spawn-to-Halyard input waypoint chain, ending at real boarding candidate.
- **Boundary/proof:** root; static comparison of
  `tests/network/halyard_network_passenger_route_test.gd`, accepted Jovian input
  helpers and authored Halyard airstair/station access. Existing D2 moving-cabin
  source7412a6e50 stages approach/flight and is retained in that scope. Do not
  call an unchanged D2 run ordinary boarding or invent a standalone server binary.
- **Next/budget/stop:** READY;30 min, no engine. Write exact start/waypoints/end,
  supported actions/roles, existing caller seam and caps, or one precise missing
  fact. End at that finite contract; no station/fleet audit or runtime fix.
- **Close:** record source refs and executable HALYARD-BOARD handoff/blocker,
  commit/push. No gameplay/baseline/phase closure from this definition.

### HALYARD-BOARD — two original occupants board normally

- **Parents/result:**16/26. Non-playing Main authority plus two independent
  original clients use normal menus/spawn/approach/boarding; one physical pilot
  and one passenger at crew_port_00. Neither craft nor actors are staged.
- **Boundary/proof:** existing Halyard passenger caller; proposed select-only
  ordinary profile, inherited private process orchestration and accepted input
  helpers. Actual authenticated peer/avatar/Player, body/frame/seat/ownership
  generations agree on host and consumed clients; distinct exclusive claims,
  correct supported controls and real seats. Existing remote-pilot actions are
  supported by `_client_loadmaster_pilot`; no new authority implementation presumed.
- **Next/check:** GATED on HALYARD-APPROACH;45–60 min. Freeze exact selector,
  source/marker; compile300s, ONE selected300s/outer360s route,15s walking,
  8s role transitions/10s owned exit grace. Require all three actual OS exits0
  before coordinator success. No flight, moving walk or recovery in this card.
- **Stop/close:** first actual failure identifies production/caller owner,
  separate bounded next task; record proof/limits, commit/push and owned cleanup.

### HALYARD-MOVING-CABIN — use the cabin during actual departure

- **Parents/result:**16/24/26. After ordinary boarding, original pilot physically
  departs>5m; original passenger walks>.6m, sits, stands and reseats while hull
  genuinely moves, with supported current body/frame/role ownership.
- **Boundary/proof:** extend accepted HALYARD-BOARD in existing passenger caller,
  actual sampled helm and body intents. No initial flight envelope, transform,
  authority or cabin-body injection. Preserve same original actors/generations
  with legitimate ownership transitions and consumed peer presentation.
- **Next/check:** GATED on HALYARD-BOARD;45–60 min. Freeze selected continuation/
  marker/pin; compile300s and one full300s/outer360s route at inherited stage
  bounds. Actual three zero exits and cleanup required. No endurance/late join/
  world journey or postdock reuse scope; those remain separate backlog outcomes.
- **Stop/close:** record first actual boundary before repair; commit/push result,
  raw and owned cleanup. Accepted short movement does not close full baseline.

### HALYARD-AUTHORITY-STOP — restore solo controls after real server stop

- **Parents/result:**16/26. While both original remote occupants remain aboard,
  authoritative Main calls existing shutdown_network_session once. Both clients
  receive production server_disconnected and recover usable ordinary solo controls.
- **Boundary/proof:** extend accepted moving profile in existing passenger caller.
  Adapter `_on_server_disconnected`→GameFlow `_on_network_session_stopped` owns
  grant/prediction/body/seat/helm retirement and solo restoration. Require actual
  original client events, no live retired grants, supported former passenger
  ordinary walk>.6m and real UI response. Do not invoke client handler directly.
  Existing surviving-host generation rotation/client-initiated leave/shared
  server stop after clients depart do not cover this case.
- **Next/check:** GATED on HALYARD-MOVING-CABIN;30–60 min. Freeze distinct
  authority-stop selector/marker/source; compile300s and one300s/outer360s route,
  original15s walking/8s transitions/10s exit grace. All three actual zero exits.
- **Stop/close:** first failure names actual cleanup/recovery owner; no automatic
  migration rewrite. Graceful server-stop proof is not SIGKILL, reconnect,
  migration or endurance qualification. Record proof, commit/push, owned cleanup.

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

Owned completed helm/return/on-foot/UI checkouts, profiles/helpers and duplicate builds are removed;
unique raw/source refs and public builds remain. Three older dirty retired
checkouts remain protected. Scratch belongs under `/srv/mudds-work/`. The failed passenger-exit candidate is retained by source refs/raw;
its disposable checkout/profile/helper files are removed after closure. Annex raw results remain under `/srv/mudds-work/annex-round-trip-20261018/results/`;
its completed disposable checkout/profiles/helpers are removed.

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
