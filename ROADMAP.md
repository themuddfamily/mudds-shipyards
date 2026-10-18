# Development roadmap

**Next: review the preserved Jovian passenger-exit candidate, then run its single selected check.**
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

**4 READY, 4 GATED, 0 accepted in this queue.** Root owns integration and closure.
READY means its stated next action can start; it does not mean gameplay passed.
Three READY cards are finite route/coverage definitions, explicitly labelled below.
Choose one independent READY card if the active chain blocks. Do not run every
card merely because it appears here. Review priorities before replenishment.

| Order / task | Type / state | One finish line | Work budget; checks separate |
| --- | --- | --- | --- |
| 1. NET-JOVIAN-PASSENGER-EXIT | Caller + qualification / READY review | Passenger walks from chair through real hatch to supported berth ground; pilot retains helm. |20–30 min remaining review; compile 300s + one route 300s/outer 360s |
| 2. NET-JOVIAN-PASSENGER-REBOARD | Caller + qualification / GATED on 1 | Same passenger walks back aboard and reclaims the original co-pilot chair. |30–60 min; one selected route at original limits |
| 3. NET-JOVIAN-PILOT-EXIT | Caller + qualification / GATED on 2 | Original pilot releases helm and walks onto berth ground; passenger remains seated. |30–60 min; one selected route at original limits |
| 4. NET-JOVIAN-PILOT-RECLAIM | Caller + qualification / GATED on 3 | Original pilot boards the same hull and reacquires helm with current authority. |30–60 min; one selected route at original limits |
| 5. NET-JOVIAN-REDEPART | Caller + qualification / GATED on 4 | Reused hull departs at least 5m and brakes; both original clients stay valid. |30–60 min; one selected route at original limits |
| 6. WALK-ANNEX-ROUTE | Planning / READY | Freeze fresh hub→Annex console→hub actions, caller and limits. |30 min; static source comparison, no engine |
| 7. PLAY-JOVIAN-KIT-ROUTE | Planning / READY | Freeze one ordinary two-kit delivery sortie and durable completion criterion. |30 min; static source comparison, no engine |
| 8. SERVER-BASELINE-DEFINE | Planning / READY | Name the residual Halyard two-client baseline and one uncovered recovery case. |30–45 min; static source comparison, no engine |

**Count meanings:** 36 is the number of broad open requirements, eight is this
working queue, and four is the number currently actionable. None is a count of
all remaining implementation jobs. The [36-parent crosswalk](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
retains the whole project; the backlog's generic families are not executable tasks.
A definition ends with one executable successor or an exact missing fact, not
another open-ended audit. Reaching its budget ends that definition.
Successor implementation estimates are provisional until their prerequisite
passes; reassess before starting, with 90 minutes as the split boundary.

### NET-JOVIAN-PASSENGER-EXIT — one actual postdock passenger exit

- **Parents/result:**16/20/26. Extend the accepted ordinary Jovian return with
  one selected client_b co-pilot passenger stand/walk/hatch/ground exit. The
  original first client stays pilot. Reboard and another departure are later
  outcomes; original return/default behavior stays its accepted scope.
- **Ownership/boundary:** existing
  `tests/network/jovian_network_two_client_return_test.gd`, plus only the smallest
  existing coordinator selector propagation if necessary. Reuse ordinary
  look/walk/Interact and process/first-failure/input cleanup helpers. No new
  harness or speculative networking/physics fix. Freeze any actual failing
  production owner before scheduling its separate repair.
- **Proof:** original Main host/two clients and all existing ordinary approach,
  seats, departure, landing, strict home lease and consumed arrival. Then actual
  chair release, supported cabin movement, hatch exit, released cabin/hatch/body
  claims and measurable supported ground locomotion. Retain original peer/avatar/
  Player identity; consume current body/ship/frame/seat/ownership generations,
  with legitimate retirement rather than resurrected bindings. Pilot source/
  stream/delivery epoch, helm/ownership and occupied landed home lease remain.
  No teleport, direct seat/phase/body mutation or fabricated completion.
- **Execution:** READY/root for candidate review. Candidate `8054a2cc4` is
  preserved on `work/jovian-passenger-exit-20261018`, not merged or accepted.
  It changes only the return caller (+376/-1); engines NOT_RUN. Review its
  select-only `--postdock-passenger-exit` mode and final retention predicate; do not apply the
  seated predicate to a legitimately exited actor. Freeze exact clean source,
  command/selection and old limits before engines. Compile 300s; one original 300s
  route/peer bound (outer 360s),15s/waypoint, existing 8s transitions,120s physical
  return and 5s arrival convergence. Headless coordinator/private Xvfb peers,
  explicit x11 and Dummy audio; actual three peer exits0 and one success marker.
- **Budget/stop/close:** about 30 min implementation already spent; 20–30 min
  remaining review/integration, cumulative split boundary 90 min; checks separate.
  First next action is read-only lifecycle/default-route review of 8054a2cc4.
  If accepted, freeze a clean source pin, compile once and run the selected route
  once; expected marker `JOVIAN_NETWORK_TWO_CLIENT_PASSENGER_EXIT_OK` exactly once.
  A review failure ends review with a concrete correction; an engine failure ends
  qualification. Neither silently authorizes a runtime repair. Preserve the exact
  actor/boundary/owner and raw failure.
  One hypothesis permits one probe; no automatic correction or deadline growth.
  Actual result/source/limits, commit/push and owned cleanup. Caller-only work
  does not need an identical rebuild; an accepted runtime repair requires a fresh
  paired checkpoint. Native/device/canonical-world/endurance gates stay open.

### NET-JOVIAN-PASSENGER-REBOARD — reclaim one passenger chair

- **Parents/result:**16/20/26. After card 1's actual exterior walk, the original
  client_b walks back through the authored hatch and sits in its original
  `co_pilot_station`; original pilot retains helm and occupied home berth.
- **Boundary/owner:** root; same existing return caller and inherited normal
  input helpers as card 1. No engineer, craft swap, pilot release or departure.
  Start from card 1's accepted clean source, not staged ground/seat state.
- **Proof:** ordinary look/walk/Interact; same authenticated peer/avatar/Player;
  host and consumed client agree on current boarding/body/frame/seat generations
  and exactly one chair claim, with released exterior claims retired. Original
  pilot source/ownership and strict home lease remain valid. No pose/claim writes.
- **Next/budget/stop:** GATED until 1 passes. Then freeze proposed select-only
  continuation/marker before implementation; 30–60 min, split before 90. Preserve
  existing 300s route/peer,15s waypoint,8s transition,120s landing,5s convergence
  limits; one compile 300s and one route/outer 360s after clean pin/review.
  First failure records exact owner and ends the card; no automatic repair.
- **Close:** actual result/pin/limits, commit/push and owned cleanup. Caller-only
  acceptance needs no identical rebuild; any runtime repair is a separate card
  with focused proof and fresh paired checkpoint.

### NET-JOVIAN-PILOT-EXIT — release helm and reach ground

- **Parents/result:**16/20/26. After 2, original pilot stands and walks through
  the real hatch to supported berth ground and walks at least 1m; passenger stays
  in its original chair. Reclaim and departure are cards 4/5.
- **Boundary/owner:** root; existing return caller/ordinary input helpers. Use
  accepted 2 source and actual prior route. Do not keep a seated-pilot predicate
  as the success condition for an exited pilot or give the passenger the helm.
- **Proof:** original actors persist; actual pilot seat/source/ownership releases
  are reflected by host and clients, old commands cannot move the hull, no stale
  cabin/chair/hatch/body claim survives exit, and the same hull retains occupied
  home lease/committed landed generation. Require ground by authored exit before
  further walking; spawn relocation cannot satisfy the result.
- **Next/budget/stop:** GATED on 2. Freeze selected continuation/marker and clean
  source; 30–60 min, split before 90. Compile 300s, one route 300s/outer 360s and the
  same15/8/120/5s stage limits. First failure ends qualification with exact owner.
- **Close:** actual result/source/limits, commit/push, cleanup; fresh paired
  checkpoint only for a separately accepted runtime repair.

### NET-JOVIAN-PILOT-RECLAIM — reacquire the same helm

- **Parents/result:**16/20/26. Original exterior pilot walks back aboard the
  same Jovian and takes the real pilot seat; passenger remains seated.
- **Boundary/owner:** root; existing return caller, starting from accepted 3.
  No second flight, replacement client, fabricated authority or forced seat.
- **Proof:** ordinary walk/look/Interact; same peer/avatar/Player, current host
  ownership and client-consumed seat/source/stream/delivery epoch agree; released
  generations stay retired and old commands remain refused. Physically occupied
  home lease and landed state remain valid until card 5.
- **Next/budget/stop:** GATED on 3. Freeze selected continuation/marker/source;
 30–60 min, split before 90. Compile 300s and one route 300s/outer 360s, existing
 15/8/120/5s stage limits. First failure records owner and ends the card.
- **Close:** actual proof/pin, commit/push, owned cleanup; same runtime-checkpoint
  condition as 3. Reclaim does not count as repeat-departure proof.

### NET-JOVIAN-REDEPART — depart once after actual reuse

- **Parents/result:**16/20/26. After accepted 4's physical exit/reboard/reclaim,
  same pilot launches same hull at least 5m from home berth and brakes to the
  existing departure test's zero-speed tolerance, with original passenger seated.
- **Boundary/owner:** root; existing return/flight callers. Reuse their ordinary
  engine/thrust/brake actions; no second landing, endurance or additional craft.
- **Proof:** berth release comes from actual departure; current pilot authority,
  passenger chair/body/frame and consumed peer poses remain valid. Retired
  pre-exit commands/claims do not regain authority. No direct ship/phase mutation.
- **Next/budget/stop:** GATED on 4. Freeze selected continuation/marker/source;
 30–60 min, split before 90. Compile 300s, one route 300s/outer 360s and original
 stage limits. If the cumulative route cannot fit, stop and record the blocked
 acceptance/design decision before any engine run; do not enlarge deadlines,
 shorten the prerequisite route or replace physical reuse with staging. First
 failure ends qualification.
- **Close:** actual result/pin/limits, commit/push and cleanup. Runtime repairs
  need their separate focused proof/checkpoint. Parent20/endurance stay open.

### WALK-ANNEX-ROUTE — specify one complete supported walk

- **Parents/result/type:**7/9; planning only. Freeze one fresh normal hub spawn
  →Fabrication Annex service console→same hub return, with actual prompt/Interact.
- **Boundary/owner:** root; inspect only the relevant route in
  `tests/ship_service_console_production_test.gd`,
  `scripts/world/fabrication_annex.gd`, `shipyard_world.gd`'s console/spawn owners
  and `game_flow.gd::_on_ship_service_console_requested`.
- **Known proof gap:** existing test teleports to connector mouth(50,.38,28),
  then ordinarily walks to the console and restocks. Preserve that accepted
  segment; missing qualification is fresh hub access and supported reverse walk,
  not a new console implementation. Sandbox/VIP parked failures stay parked.
- **Next/proof/budget:** READY; 30 min static comparison, no engine. Write exact
  normal start/end, authored waypoint route, existing caller/selection, unchanged
  applicable caps, same-Player/floor/input criteria and one executable successor
  here. No guessed cap or READY qualification before those facts are frozen.
- **Stop/close:** exact successor or named missing fact at budget; record result
  in this card/backlog, commit/push. No new route framework or unbounded station audit.

### PLAY-JOVIAN-KIT-ROUTE — specify one ordinary delivery

- **Parents/result/type:**13; planning only. Freeze normal boarding, departure,
  two-kit delivery return and usable landed exit at actual freight berth.
- **Boundary/owner:** root; existing `tests/cargo_delivery_production_integration_test.gd`,
  `scripts/game/game_flow.gd` cargo binding/constants,
  `scripts/cargo/cargo_delivery_activity.gd` and
  `scripts/persistence/cinder_cargo_delivery_persistence.gd`.
- **Known proof gap:** existing test stages the hull at berth+3m, clears landed
  and marks departure directly. Its integration pass is retained, but does not
  prove this ordinary sortie. No cargo runtime rewrite is presumed necessary.
- **Next/proof/budget:** READY; 30 min static comparison, no engine. Freeze
  existing ordinary-input caller, route, normal activity trigger/start/end and
  original applicable caps. Preserve 180s activity deadline; source 6→4,
  destination 0→2, exactly one durable reward receipt and usable landed exit are
  explicit successor acceptance. Write one caller/qualification card, not an
  all-activities test matrix; no rescue or forced departure in the ordinary leg.
- **Stop/close:** executable successor or exact missing fact; commit/push. No
  activity run or runtime correction until separately bounded/frozen.

### SERVER-BASELINE-DEFINE — specify residual two-client gameplay

- **Parents/result/type:**16/26; planning only. Credit accepted Jovian boarding,
  flight and return; identify one remaining ordinary Halyard moving-cabin route
  and separately one actually uncovered recovery boundary.
- **Boundary/owner:** root; `docs/COMPLETION_SCOPE.md` first acceptance profile,
  `tests/network/jovian_network_two_client_boarding_test.gd::_host`, inherited
  flight/return and `halyard_network_passenger_route_test.gd`. Existing non-playing
  Main already hosts two independent clients. Do not invent a standalone server
  executable requirement or wait for the separate larger-capacity decision.
- **Next/proof/budget:** READY; 30–45 min static comparison, no engine. Record
  exact existing caller/command, supported actors/actions/authority criteria,
  prior accepted scopes and one finite successor per uncovered boundary. Name
  any missing fact instead of scheduling an unchanged baseline rerun. Keep the
  original 30-minute endurance and network-profile cases separate.
- **Stop/close:** executable successor(s) or precise blocker at budget;
  commit/push. No new harness, crowd expansion, qualification run or claimed
  baseline completion from this definition.

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
checkouts remain protected. Scratch belongs under `/srv/mudds-work/`. The unverified passenger-exit candidate
and its prepared private runner remain intentionally retained until review.

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
