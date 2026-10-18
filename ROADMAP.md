# Development roadmap

**Next: strict cargo home return, two-kit transfer and usable exit. Halyard boarding is parked after its bounded retry failed.**
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
| Ordinary offline Jovian cargo selection and boarding |62bc7c823 PASS66.158s: normal UI/spawn walk/hatch boarding to real local pilot seat, occupied home lease, cargo remainsIDLE0/source6/destination0. No departure/delivery acceptance. |
| Ordinary offline Jovian cargo departure |b91019562 PASS70.350s: real≥5m departure/berth release, automatic ACTIVEg1/return objective and≤.5m/s brake for1s, original180s clock. No home delivery/transfer/reload proof. |
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

**1 IN PROGRESS, 1 FAILED/PARKED, 3 GATED, 3 DONE (two qualifications, one definition).** Root owns integration and closure.
Two definitions are complete: offline Jovian delivery and residual Halyard
server gameplay. They split into the eight concrete outcomes below. This is a
local work queue, not a remaining-project job count. Original36 parents and all
ten phase gates remain open. The accepted Annex route and parked Jovian exit/
reuse cards remain in the [backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
and delivery history; they do not consume active queue slots.

| Task | State | Observable finish | Implementation estimate; checks separate |
| --- | --- | --- | --- |
| KIT-BOARD | DONE | Fresh player selects cargo, walks to Jovian and takes the real solo pilot seat. |Accepted62bc7c823;66.158s at original300s cap |
| KIT-DEPART | DONE | Ordinary thrust leaves berth, starts delivery automatically, then brakes. |Acceptedb91019562;70.350s at original300s cap |
| KIT-DELIVER | IN PROGRESS | Physical home return transfers two kits, pays once and leaves player walking outside. |45–60 min; one extended route at unchanged caps |
| KIT-RELOAD | GATED on KIT-DELIVER | Distinct process reloads accepted delivery without duplicate kits or reward. |20–40 min; compile300s + one restore30s |
| HALYARD-APPROACH | DONE definition | Freeze one ordinary spawn→airstair→hatch input route and exact caller. |30 min static comparison; no engine |
| HALYARD-BOARD | FAILED/PARKED | Two independent clients ordinarily board distinct pilot/passenger seats. |Both attempts failed; priority review selects KIT-DELIVER |
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
  implemented `--ordinary-jovian-kit-board`, default staged/recovery branch preserved.
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
- **Accepted/check:** DONE/root at62bc7c823, integrated on main. Selected route
  PASS66.158s,49 assertions, actualexit0/marker1/original diagnostics0. Preserved
  initial failure and accepted caller-only lifetime/completion correction.
  Early selector and existing
  look/walk/Interact helpers use no pose/phase/claim/candidate/start_shift/HUD-state
  writes. Corrected compile PASS; ONE selected300s/outer360s route accepted. Preserve15s/waypoint,
  .30m horizontal/15 supported settled ticks/<.8m vertical and12s boarding.
  Selected marker `JOVIAN_KIT_ORDINARY_BOARD_OK`; no departure/landing/reload work.
- **First attempt/next repair:**8630531ac import/compile PASS; selected run
  FAILED before walking at RuntimeStatusDismissButton: activation retires the
  button and caller reads its name after await. Engine exit0/marker1 is rejected
  by original full-log SCRIPT ERROR diagnostic. No boarding acceptance.
  KIT-BOARD-CALLER-LIFETIME is the accepted caller-only repair: retain name
  before activation and require explicit end-of-scenario completion before success.
  Preserve failed source/raw, freeze corrected pin, one compile and ONE unchanged
  selected route PASS. No gameplay/criteria/cap change; no further retry selected.
- **Stop/close:** first failure ends boarding qualification; record concrete
  snapshot and next owner. Accepted seat access does not qualify departure or
  delivery. All5 supervisors terminal/all19 PID identities absent, source and
  non-import cache unchanged. Commit/push, remove owned checkout/profiles/helpers;
  unique raw retained under `/srv/mudds-work/jovian-kit-board-20261018/results/`.

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
- **Accepted/check:** DONE/root onb91019562, integrated on main. Corrected
  compile and ONE unchanged selected route PASS70.350s,52 assertions, actual0/
  marker1/original fullraw diagnostics0. Original normal boarding plus sampled
  thrust/actual≥5m berth release, automatic ACTIVEg1/return objective/minimap and
  ordinary sampled brake≤.5m/s for1s pass; cargo stays source6/destination0 and
  original180s physics clock remains. Same Player/source/hatch/home/hull retained.
  Selector `--ordinary-jovian-kit-depart`, marker `JOVIAN_KIT_ORDINARY_DEPART_OK`;
  default/staged and accepted board paths preserved. No landing/delivery proof.
  Existing300s route/outer360s,15s waypoints/12s boarding/10s departure/10s brake
  remain; input-only private x11/Dummy, no rendered/device qualification.
- **First attempt/repair:** e2cf6ce64 import/compile PASS; route FAILED before
  thrust at cargo destination identity. Snapshot source6/destination0 is correct,
  but caller compared JovianFreightBerth service node to the distinct ShipBerth
  physical lease owner. One static raw/source comparison identifies this caller
  error. Accepted KIT-DEPART-CALLER-OWNER uses the actual service accessor
  for cargo identity and retains physical ShipBerth lease checks. Failed source/
  raw remain beside accepted proof; no runtime/criterion/timeout changes.
- **Stop/close:** first failure records actual input/engine/berth/activity owner;
  no automatic runtime fix. Landing/transfer/reward remain KIT-DELIVER.
  All5 owners terminal/all19 PID identities absent; source/non-import cache
  intact. Result/pin/limits recorded, commit/push and owned checkout/profile/helper
  cleanup; unique raw `/srv/mudds-work/jovian-kit-depart-20261018/results/`.

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
- **Next/check:** IN PROGRESS/root; KIT-DEPART accepted.45–60 min implementation/review. Freeze
  selected continuation/marker/pin; compile300s and one full300s/outer360s route,
  preserving180s activity deadline,8s acceptance/120s physical dock and all prior
  bounds. Exit cap is authored2×canopy_motion_time+disembarking_motion_time+1s,
  then15s ground walk. No rescue, geometry/phase mutation or deadline growth.
- **First failure/one repair:**1b2931b38 clean import PASS, compile FAIL at
  line360: multiline lambda return lacks grouping. No gameplay route ran.
  Select ONE5min caller syntax correction grouping both new multiline lambda
  returns. Root owns this trivial correction; no further delegation needed.
  One corrected compile, then one unchanged route only if it passes. Any further
  failure requires cumulative priority review before more repair or rerun.
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
- **Resolved route:** DONE definition, no engine. Fresh spawn(-8.5,.18,11),
  then world goals(0,0,15.5),(0,0,39),(0,0,46.3),(0,0,51),(-5.7,0,51),
  (-5.7,4.2,61.2),(-3.5,4.2,61.5),(-3.5,4.2,64.2),(-3.5,4.2,68.3),
  (6,4.2,68.3),(13,4.2,68.3),(22,4.2,68.3),(37,4.2,68.3),
  (32.4,4.2,68.2),(32,4.2,62.2),(32,4.2,54.2), then actual boarding point,
  initially(32.1,4.2,48.5). Native route1269–1285/1475–1476 supplies chain;
  final extension follows authored berth/BoardingPoint, not collision proof.
- **Handoff:** same supported Player must see actual Halyard boarding_candidate,
  _near_ship and its ShipBoardingArea among nearby interactables. Aim marker+UP1.2,
  ordinary Interact→supported IN_FLIGHT_CABIN/bound authenticated intent within12s.
  Existing passenger `_client` owns that admission. Physical ShipCabinHatch is
  farther inboard; requiring its station candidate at the exterior marker is wrong.
  Keep15s/.30m/15 settled ticks/.8m vertical,12s boarding/8s roles/300s total.
- **Close:** finite source-backed route handed to READY HALYARD-BOARD; no
  gameplay/server/phase acceptance from this definition. Commit/push, no scratch.

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
- **Next/check:** FAILED/PARKED/root; no further boarding attempt selected.
  Proposed selector `--ordinary-two-client-board`, unique
  `HALYARD_ORDINARY_TWO_CLIENT_BOARD_OK`, isolated branch
  `work/halyard-ordinary-board-20261018`. Freeze exact clean
  source/marker; compile300s, ONE selected300s/outer360s route,15s walking,
  8s role transitions/10s owned exit grace. Require all three actual OS exits0
  before coordinator success. No flight, moving walk or recovery in this card.
- **First attempt/selected repair:**6b17c130f import/compile PASS; ordinary route
  FAIL135.904s after both actual seats. Both clients consumed current ship
  ownership, but caller demanded a pilot row from empty legacy `sections.boarding`.
  Main uses a separate boarding ledger; no runtime seating defect is established.
  HALYARD-CALLER-CONSUMER is the ONE selected15min caller-only correction: match
  each actual received boarding claim to its host seat record, preserving actual
  seats, exclusive authority, ownership/body/frame generations and honest roles.
  Guard detached diagnostic nodes before get_path. Freeze corrected source;
  one compile and one unchanged selected route, no added cap or runtime change.
- **Stop/close:** corrected source f3d53bda6 compiles; ONE unchanged retry FAILS
  135.833s at consumed-state comparison after both actual seats. Boarding remains
  unqualified; failed caller stays unmerged. Priority review selects READY
  KIT-DELIVER, a distinct physical delivery outcome, over further Halyard diagnosis.
  The two route attempts total271.737s, excluding import/compile and implementation/
  review; the15min correction is cumulative, not a new budget reset. No further
  diagnosis/repair/run selected. All5 owners terminal/all34 observed PID identities
  absent, source/cache intact;96 copied peer raw files byte-identical. Source refs
  and raw retained; owned disposable checkout/profiles/helpers removed at closure.

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
its completed disposable checkout/profiles/helpers are removed. KIT-BOARD raw is retained
at `/srv/mudds-work/jovian-kit-board-20261018/results/`; its completed checkout,
profiles and helpers are removed after closure.

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
