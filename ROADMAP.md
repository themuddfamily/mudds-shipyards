# Development roadmap

**Fresh playable checkpointb86264f retains mixed button/stick controls in help, including the prior camera-distance fix. Cargo restart and Halyard remain parked.**
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
| Fresh playable checkpoint **b86264f** | [Windows notes](builds/windows/MuddsShipyards-b86264f-notes.txt), [Linux notes](builds/linux/MuddsShipyards-b86264f-linux-notes.txt). Grouped help retains buttons beside stick directions in either order; default shorthand stays. Glyph40/camera27/help20, both exports/three strict startups/actual1515-entry audit pass. Earlier7718a5a camera and1cf1022 layout/focus corrections retained. |
| Ordinary two-client Jovian short sortie and physical home return | Source `4c9c764e9` PASS in138.915s: normal boarding/real seats,5m departure/brake, accepted landing, strict home dock/lease/landed commit and both retained clients consume original pilot/ownership generations and arrival. All three peers exit 0; marker 1; diagnostics 0. |
| Actual on-foot recovery in exported/archive Linux checkpoint | f90547c real-file SIGKILL/distinct restart; supported awake unseated player, ordinary walk0.525555m+Interact boarding, conserved convoy and receipts1→2 once. Private headless/Dummy and disclosed craft-placement fixtures; no fullflight/native-device claim. |
| Pause/options16:10 selected source qualification | 1cf102298 PASS:26 focused repair assertions;948 layout assertions/96 observations,32 states at requested.75/1/1.6. Original criteria/caps retained; device/render/persistence transactions and other aspects remain open. |
| Fresh hub→Annex service→hub |9af57671d selected route PASS81.387s: same supported Player, actual kits5→6 and one Annex update/Aft unchanged. Active-craft/kit-spend fixtures disclosed; default caller unchanged. |
| Ordinary offline Jovian cargo selection and boarding |62bc7c823 PASS66.158s: normal UI/spawn walk/hatch boarding to real local pilot seat, occupied home lease, cargo remainsIDLE0/source6/destination0. No departure/delivery acceptance. |
| Ordinary offline Jovian cargo departure |b91019562 PASS70.350s: real≥5m departure/berth release, automatic ACTIVEg1/return objective and≤.5m/s brake for1s, original180s clock. No home delivery/transfer/reload proof. |
| Ordinary offline cargo home delivery and usable exterior exit |28a5e354e PASS79.213s: strict occupied home dock, kits6→4/0→2, one transfer/reward, automatic OFFLINE and ordinary authored exit plus supported walk≥.5m. Actual save retained; distinct-process restore remains open. |
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

**1 READY, 2 FAILED/PARKED, 2 GATED, 3 DONE (one qualification, two production fixes).** Root owns integration and closure.
Completed HALYARD-APPROACH and RELOAD-BOUNDARY definitions are retained below;
their reused queue slot now holds the camera-distance prompt correction. The
completed KIT-BOARD/KIT-DEPART cards remain below; their slots now hold mixed
control prompts and the cargo supply-status correction. Two definitions are complete: offline Jovian delivery and residual Halyard
server gameplay. They split into the eight concrete outcomes below. This is a
local work queue, not a remaining-project job count. Original36 parents and all
ten phase gates remain open. The accepted Annex route and parked Jovian exit/
reuse cards remain in the [backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
and delivery history; they do not consume active queue slots.

| Task | State | Observable finish | Implementation estimate; checks separate |
| --- | --- | --- | --- |
| MIXED-CONTROL-PROMPTS | DONE | Grouped movement help retains a remapped button alongside stick directions in either order. |b86264f; glyph40/camera27/help20, paired checkpoint/startups/audits pass |
| HUD-CARGO-SUPPLY | READY | After the six-kit supply is exhausted and the run reset, the Activity Board reports insufficient kits; other activities remain selectable. |30–60 min implementation/review; existing focused check up to300s, packaging/checks separate |
| KIT-DELIVER | DONE | Physical home return transfers two kits, pays once and leaves player walking outside. |Accepted28a5e354e;79.213s at original300s cap |
| KIT-RELOAD | FAILED/PARKED | Distinct process reloads accepted delivery without duplicate kits or reward. |Compile passed; restore30s timed out before runtime acceptance |
| CAMERA-DISTANCE-PROMPTS | DONE | Piloting Controls shows both current camera-distance bindings after remap. |7718a5a; focused27/help20, paired checkpoint/startups/audits pass |
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

### HUD-CARGO-SUPPLY — show when delivery kits have run out

- **Parent/result:**13. After three two-kit deliveries exhaust the Jovian's
  six-kit supply, resetting or reselecting cargo shows insufficient kits rather
  than READY. Race and other activity choices remain available.
- **Boundary/owner:** root integrates one implementation agent. Only the existing
  GameFlow activity-selection presentation, HUD status copy and existing
  `tests/cargo_delivery_production_integration_test.gd` depletion scenario.
  Read the existing cargo authority; preserve its start refusal, inventories,
  rewards, generations and selection locks. No refill, persistence or restart work.
- **Proof:** extend the existing scenario that performs three real transfers,
  checks source0/destination6, resets and verifies `insufficient_source_quantity`.
  Assert truthful board status after reset and reselection, unchanged start
  refusal, and ordinary Race selection. Reproduce the new assertion against the
  old runtime, then pass it with the fix. Keep the existing300s check cap;
  a timeout is a failure, not permission to weaken or replace the acceptance.
- **Budget/next:** READY;30–60min implementation/review, split before90min.
  Check runtime is separate: focused check up to300s per selected run, plus
  import/compile and paired checkpoint exports/startups. Next action is the
  bounded implementation; stop at its first unexpected failure and record the
  exact boundary before choosing one separate repair.
- **Close:** accepted runtime change, focused proof and fresh paired playable
  checkpoint with actual validation/limits; commit/push and owned scratch cleanup.
  This closes only the supply-status defect, not cargo persistence or parent13.

### HUD-CARGO-FINDING — DONE, source definition only

The bounded read-only comparison found the supply-status discrepancy above.
`request_activity_start` already refuses insufficient kits, but activity-selection
presentation receives no supply status and falls back to READY after reset.
The existing depletion scenario supplies the implementation seam and acceptance.
No engine run or gameplay completion is claimed by this definition. Its queue
slot now holds HUD-CARGO-SUPPLY; no further broad cargo audit is selected.

### MIXED-CONTROL-PROMPTS — retain buttons beside stick directions

- **Parents/result:**8/29. A generic-pad move_forward remapped to Misc Button
  remains visible beside other Left Stick movement controls in the actual MOVE
  help row. Action order must not hide a distinct binding; normal all-stick
  directions still abbreviate to Left Stick.
- **Boundary/owner:** root integrates one implementation agent; only HUD
  `_action_prompts` and existing runtime_input_glyph_hud_integration_test.
  Current source sentinel is order-dependent: leading non-stick leaves empty
  shared_stick, allowing a later direction to replace the entire row.
- **Proof/budget:**30min implementation/review in isolated
  `fix/mixed-control-prompts-20261018`. One test-only old HUD reproduction,
  corrected compile/focused run and existing help/camera regression checks,
  original300s caps/private x11/Dummy. No actual input/persistence authority change.
- **Accepted/close:** DONE atb86264f3d092f6c7e7f1fd5dff0718841b946847,
  integrated on main. Old17a74d915 fails exactly leading-button/helper and MOVE
  row assertions; corrected glyph40/camera27/help20 pass, no unexpected failure.
  Both safe clean exports/three strict silent startups/fullraw diagnostics and
  actual1515-entry payload/stock PE/archive audit pass. EXE/checkpoint ZIP/notes
  in builds/windows and matching Linux checkpoint in builds/linux.
  All12 owners terminal/all57 observed PID identities absent; source/index and
  non-export cache unchanged. Raw/source refs/public builds retained; disposable
  checkout/profiles/helpers removed. No physical device/rendered/native Windows/
  GPU/audio/whole remap-flight qualification; original parents/gates stay open.

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
- **Accepted/check:** DONE/root at28a5e354e, integrated on main. PASS79.213s,
  actualexit0/marker1/fullraw diagnostics0. Original selected limits retained.
  Selector `--ordinary-jovian-kit-deliver`; marker
  `JOVIAN_KIT_ORDINARY_DELIVER_OK`. Compile300s/full300s/outer360s route,
  preserving180s activity deadline,8s acceptance/120s physical dock and all prior
  bounds. Exit cap is authored2×canopy_motion_time+disembarking_motion_time+1s,
  then15s ground walk. No rescue, geometry/phase mutation or deadline growth.
- **History:** original syntax failure, queued-brake handoff failure and explicit
  cumulative priority review remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md).
- **Close:** corrected compile PASS16.489s; ONE corrected route PASS79.213s,
  55 assertions. Actual home dock/lease, COMPLETEDg1 source4/destination2, one
  transfer/reward with none owed, automatic OFFLINE, authored exit and supported
  same-Player≥.5m walk;60 normal ticks preserve completion. No reload acceptance.
  All6 owners terminal/all16 observed PID identities absent; source/cache intact.
  Retain failures/raw under `/srv/mudds-work/jovian-kit-deliver-20261018/results/`
  and accepted store's original private XDG data directory named by
  `results/accepted-store-location.txt`. Owned checkout/helpers/other profiles
  removed after closure; caller-only change needs no identical checkpoint.

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
- **Actual/check:** source972efd906 import/compile PASS; ONE strict30s restore
  exits124 after30.225s, no marker. Exact primary/hash and saved completed/paid
  baseline accepted before Main tree entry; runtime startup/tick acceptance was
  not reached. No persistence rejection is demonstrated. Candidate stays unmerged.
- **Bounded diagnosis/next:** source/log comparison complete, no further engines.
  Last observed boundary spans synchronous Main child readiness/_start_up and
  four awaited physics/process pairs. Startup bookkeeping reached session2,
  physics tick0; logs cannot isolate the stall. No narrower runtime fix supported.
  Before any retry, select a separate finite startup-boundary diagnostic with
  elapsed tree-entry/ready/frame receipts and original30s OS clock. Do not extend
  the timeout, move preload outside timing or revive parked Q4 startup profiling.
  No repair or rerun is selected at this closure; replenish queue by priority review.
- **Close:** all3 owners terminal/all6 observed PID identities absent, source/
  index/non-import cache unchanged. Saved cargo/reward slots exactly preserved;
  startup changed unrelated store bookkeeping/hash. Retain original byte-exact
  accepted input plus modified real store and raw under
  `/srv/mudds-work/jovian-kit-reload-20261018/results/reload/`. Source branch pushed;
  owned checkout/helpers/profiles removed. No new build or restart qualification.

### CAMERA-DISTANCE-PROMPTS — show live distance bindings

- **Parents/result:**8/29. After remapping camera distance in/out to F13/F14,
  piloting Controls shows both keys instead of the hardcoded Mouse Wheel hint.
  Distinct controller remaps likewise show both; authored wheel/stick hints remain accurate.
- **Boundary/owner:** root integrates one implementation agent in isolated
  `fix/camera-distance-prompts-20261018`. Only HUD `_view_distance_prompts` and
  existing `runtime_input_rebind_hud_integration_test.gd`; no input authority changes.
- **Proof/budget:**30min implementation/review; compile300s, one focused test
  against old HUD to demonstrate regression and one against corrected HUD.
  Capture both keys through existing HUD flow, inspect actual piloting help row,
  reset and verify authored hint. No broad remap matrix or physical device claim.
- **Accepted/close:** DONE at7718a5a7afe590c2106f5b10da71235096bb4fda,
  integrated on main. Old HUD demonstrates missing keyboard labels; final focused
  rebind HUD27 and existing help-overlay20 pass after one test event-route repair.
  Both clean safe exports/three strict startups/fullraw diagnostics and actual
 1515-entry cross-platform payload/stock PE/archive metadata audit pass. Fresh
  EXE/checkpoint ZIP/notes in builds/windows; matching Linux in builds/linux.
- **History/limits:** initial pad test bypassed device observation; caller-only
  correction is recorded in delivery history. Windows startup's private review
  parser excluded colon; unchanged raw proves actualexit0/exactone marker, no
  rerun or criteria change. No physical device/rendered/native Windows/GPU/audio
  or whole remap/persistence/flight qualification. All13 owners terminal/all59
  observed PID identities absent; source/index/non-export cache unchanged.
  Owned checkout/profiles/helpers removed, raw/source refs/public builds retained.

### CONTROL-FINDINGS — select one actual binding/help defect

- **Parents/result/type:**8/29; bounded source definition before product work.
  One exact ordinary trigger where shipping help/prompts or apply/remap behavior
  disagrees with actual supported input; finite no-finding is valid.
- **Selection/boundary:** priority review parks cargo startup and Halyard; no
  further probes. One read-only agent compares existing HUD prompts/settings
  remapping owners with InputMap/local input source.10min, no engines or edits.
  Root reconciles stale backlog cargo statuses and owns any later implementation.
- **Close/next:** DONE definition: HUD1372 hardcodes desktop distance and only
  resolves controller distance out despite both actions being remappable/live.
  Select CAMERA-DISTANCE-PROMPTS with existing focused HUD test.
  No speculative feature or new audit/test framework. Runtime delivery requires
  actual correction, focused before/after proof and clean paired checkpoint.

### RELOAD-BOUNDARY — locate the missing startup boundary

- **Parent/result/type:**13/31; one diagnostic, not a restart qualification.
  Distinguish synchronous Main tree-entry/readiness from the following four
  ordinary physics/process pairs; stop with observed boundary/owner or missing fact.
- **Selection/boundary:** priority review finds no READY competitor in this queue.
  Existing failed cargo caller only, one implementation agent/root review;
  `--ordinary-jovian-kit-reload-trace` alongside unchanged reload/path/hash flags.
  Read-only elapsed receipts at entry/instantiate/tree entry, child/Main ready,
  after tree entry, each existing tick pair and cleanup. No runtime/staging changes.
- **Check/budget:**15min instrumentation; clean compile300s then ONE30s OS probe.
  Recreate original private XDG path with byte-identical archived accepted input
  SHAe5000c06734eff363c70cab9e394bb378b1de59b79254ec07a3b6a78a870ee0c;
  preserve archive and post-timeout store. Do not fabricate/reset completion,
  move preload outside clock, extend timeout or repeat parked Q4 profiling.
- **Actual/close:**f432bd630 import PASS20.618s/compile PASS16.272s;
  ONE30s probe exits124 after30.240s. Scenario starts at engine15.929s,
  tree entry15.953s, ShipyardWorld ready21.037s, final child27.047s,
  Main ready27.762s with initialized=true/paused=false/cargo COMPLETEDg1/
  restore accepted. First frame-pair wait begins27.762s; no return before timeout.
  Thus synchronous startup completes; remaining gap is ordinary frame progress
  plus remaining acceptance within the same total budget. Not a persistence rejection.
- **Next/stop:** diagnostic DONE; KIT-RELOAD remains FAILED/PARKED, caller unmerged.
  No narrower runtime fix or further probe selected. Replenish queue by priority
  review; do not spend successive cards profiling each startup subsection.
  A future repair must improve actual startup/frame behavior and retain original
  process clock, full runtime/geometry and60-tick acceptance. No parked Q4 rerun.
  All3 owners terminal/all6 PID identities absent, source/cache intact; saved
  cargo/reward slots unchanged. Source/raw/accepted input and post-probe data
  retained in task results; owned checkout/helpers/profiles removed.

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
