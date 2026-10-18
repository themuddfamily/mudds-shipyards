# Development roadmap

The game is a playable development alpha. **All ten phase exit gates remain
open.** This file contains the next bounded production tasks and their dependencies. The
[backlog and 36-parent crosswalk](docs/ROADMAP_BACKLOG.md),
[original specifications](docs/history/ROADMAP_SCOPE_20261017.md) and
[production roster](docs/COMPLETION_SCOPE.md) retain the full project scope.
[Completed deliveries](docs/history/ROADMAP_DELIVERIES.md) retain their recorded
source, checks, failures and limitations. Moving them does not close requirements.

Latest Windows checkpoint: **b6196a1**, with [notes](builds/windows/MuddsShipyards-b6196a1-notes.txt).
Latest Linux package: **b6196a1**, with [notes](builds/linux/MuddsShipyards-b6196a1-linux-notes.txt).
Latest runtime source: **b6196a19a** (pushed). Confirmed crew status now takes
craft name/ID from the occupied chair's ship while retaining the pilot selection.
The old runtime reproduces the passenger mismatch; focused HUD51 and role3 pass
with no diagnostics. The repaired private export profile now produces checkpoint
b6196a1: both safe exports, three strict menu startups and exact artifact checks
pass. Original failed export logs remain retained. Ordinary two-client boarding
now PASS on fff5f7221 in127.937s: both real seats, current identities/authority/
consumed HUD, host confirmation and all three actual exits0. Flight/return and
endurance remain unqualified.
Current full matrix: NOT_RUN;
last unfiltered matrix `f85957f` failed 11 of 1,045 suites. Focused passes do not
replace it. Native Windows execution and human review remain owner-excluded
mandatory gates, factually NOT_RUN. Other hardware/release gates remain open.

## Current position and next action

**36 broad parents and all ten phase gates remain open.** The
[concrete child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
separates named outcomes from missing definitions; it is not a remaining-job
count. **Physical Jovian passenger seating, passenger/pilot HUD repairs and
ordinary two-client boarding are delivered in their recorded scopes. Both
lifecycle cards PASS on frozen d7be01487.**
**Pilot HUD ownership is repaired and checkpointad596e4 is published.**
**The passenger craft-label source repair and checkpoint b6196a1 are delivered.**
The original ordinary two-client boarding route PASS on fff5f7221; this closes
boarding only, not flight, return, dedicated headless server or endurance.
VIP remains FAILED/parked after its first attempt and one syntax repair.
The passenger-seat and pilot-HUD outcomes close only their named scope; no
parent or phase gate closes.

- **Latest source delivery:** b6196a19a resolves confirmed crew craft name/ID
  through the actual chair owner without changing selection or authority.
  The expected old-runtime mismatch is reproduced; focused HUD51 and role3 pass,
  source/cache guards pass, independent review GO.
- **Latest checkpoint:** b6196a1 Windows EXE/ZIP/notes and matching Linux
  ELF/archive/notes pass both exports, three strict startups, all1515 actual
  payload-entry byte comparisons and exact archive/ZIP checks.
  The physical Jovian passenger-chair delivery6262749 remains included.
- **Latest qualifications:** LIFE-VISIBLE completes four cycles/24 rest-state
  snapshots with zero phantom failures in211.028s. LIFE-REUSE completes twelve
  sorties/all nine physical berth returns/three Main re-entries in205.716s,
  stable resources and teardown1→1 nodes/zero orphans. Both actual exit0 and
  original diagnostics0. Staged headless source behavior, not packaged ordinary play.
- **Latest ordinary route result:** fff5f7221 PASS in127.937s with152 checks,
  one original success marker and diagnostics0. Both clients walk all13 approach
  goals plus their interior goal, use their real chairs and pass current identity,
  consumed HUD, producer/host authority and final host dual-seat confirmation.
  All three actual peer exits0/.done failures0; source/cache guards unchanged.
  The unchanged held caller is now integrated; independent contract/result review GO.
- **Next:** implement/qualify NET-JOVIAN-DEPART: actual pilot input departs5m
  from the berth and brakes, while the existing independent passenger stays
  correctly seated. Static definition is complete; the departure is NOT_RUN.
- **Earlier delivered:** browser per-session generations and accurate defense
  briefing on9be5c83 retain their source/UI scopes.
- **Parked:** Fire restart, Rime shared arrival, HULK revisit, Sandbox recovery
  walk, Convoy/Patrol startup and Q4/Q5 retain their failures and repair limits.
- **External waits:** original Settings artifacts, original Aurora arrival bundle
  and final capacity choice. The original server/two-client baseline remains
  authorized independently; do not ask settled questions again.
- **Cleanup:** owned clean Ember, VIP, Jovian, lifecycle and pilot-HUD source
  checkouts are removed; the crew-HUD checkout/profile are also removed after its
  failed export; the separate successful checkpoint checkout/profiles are also
  removed after publication. The accepted boarding checkout/profile/helpers are
  also removed after integration; unique raw/public builds remain. Three older checkouts with
  unique uncommitted work stay protected. Scratch belongs under `/srv/mudds-work/`.

Report the named result, actual proof, next action and estimate. Source checks,
planning or test totals do not establish whole-parent or hardware completion.

## Next slice — ordinary shared Jovian departure and stop

NET-JOVIAN-FLIGHT-DEFINE is DONE as static planning. Forward input maps to
throttle and automatic engine demand releases the dock latch; authoritative
post-collision motion retires the berth. No missing production action is proven.
[Source seams and definition result](docs/history/ROADMAP_DELIVERIES.md#first-shared-jovian-flight-segment--bounded-departure-card-defined).
The next outcome is deliberately named departure/stop: broader flight, landing/
return and original30-minute endurance remain separate and unqualified.

| Task | Type / status / owner | Observable finish | Budget |
| --- | --- | --- | --- |
| NET-JOVIAN-DEPART | Qualification capability / READY / root | Ordinary pilot input moves the authoritative Jovian out of its berth, then brakes it to a stop while the independent passenger remains seated and sees the same craft. | Implementation/review45–75min; import600s/compile300s/one original300s route separately. |

### NET-JOVIAN-DEPART — shared departure and brake through ordinary controls

- **Parent/result:** parents16/26; reuse accepted fff5f7221 ordinary joins, all13
  station approach goals plus cabin goal, actual pilot/passenger seats and final
  host confirmation. Then travel at least5m along the initial ship nose in the
  station frame (initial nose=-global_basis.z.normalized()), leave the occupied
  berth through actual physics, and stop at
  authoritative speed<=0.5m/s. Both original Players/roles stay aboard.
- **Boundary/ownership:** root owns the existing boarding caller plus one
  select-only `tests/network/jovian_network_two_client_flight_test.gd` and its UID.
  Add default-noop scenario hooks to reuse boarding, rather than copy its route.
  Host hook belongs after host.seats_confirmed and before original retained waits;
  client hook belongs after confirmed identity/seat/HUD checks and before writing
  .retained. Preserve default boarding behavior and its original waits. New flight
  actions/receipts finish inside those hooks; cleanup and actual-exit owner stay
  inherited. No runtime, controls, protocol or existing predicate relaxation.
- **Ordinary actions:** pilot alone uses existing Input.parse_input_event action
  events: hold move_forward (default W), no steering/boost, until host confirms
  >=5m forward displacement within10s. Release forward; hold brake until host
  speed<=0.5m/s for1s within10s. Release brake. Passenger supplies no flight input.
  Neutralize all actions on every exit, including brake; retain independent abort.
  No manual ShipCommand injection, engine-start call, dock release, pose/velocity
  assignment, direct claim/private client request or shortened station approach.
- **Host proof:** record station-relative position, initial nose and current pose
  tick after both chairs are confirmed. Observe consumed positive throttle and
  brake through get_last_ship_command(), actual forward displacement, landed=false
  and this ship's berth released by production GameFlow. Require current pilot
  source/owner and both exact entity/seat generations throughout and after movement.
  A client prediction or engine animation alone cannot establish departure.
- **Client proof:** both consumed pose streams advance past the start tick and
  retain the host's pilot owner. After stopping, compare each actual craft's
  station-relative position with the host's stopped pose, tolerance<=0.5m within5s
  (existing station-frame pose tolerance). Confirm real Players remain at their
  original seat anchors and all existing identity/role/HUD/authority predicates
  still pass; passenger has no pilot producer/authority. Compare like coordinate
  frames so an origin rebase cannot count as travel or apparent convergence.
- **Command/acceptance:** freeze a clean candidate, import/explicit compile, then
  exactly one existing input-only matrix run selecting
  jovian_network_two_client_flight_test, graphical/private Xvfb, explicit x11,
  Dummy, jobs1, original timeout300/import-gate never; outer cleanup360 unchanged.
  Subclass must override its peer script path and final success marker so the
  coordinator runs flight actors and prints JOVIAN_NETWORK_TWO_CLIENT_FLIGHT_OK
  only after all actual OS exits0. Preserve zero diagnostics, source/cache guards,
  complete peer receipts, retained-seat checks and normal shutdown. Source-only;
  no packaged route, native hardware or endurance claim.
- **Budget/stop:**45–75min implementation/review; check costs separately. One
  original300s flight attempt. First failure closes FAILED with the first concrete
  action/owner/snapshot; stop for priority review before any probe, repair or rerun.
  Do not change thresholds, path or total cap to obtain a pass.
- **Close:** integrate only accepted capability, commit/push exact result, clean
  owned checkout/profile/helpers and retain unique raw. Existing checkpointb6196a1
  contains unchanged game runtime; any demonstrated runtime repair is a separate
  production card and requires its own fresh working checkpoint.

## Earlier ordinary Jovian boarding attempt — FAILED (retained history)

Earlier candidatecbbebd715 combines accepted runtimead596e474 with corrected
local identity proof and the previously reviewed failure capture. Import/compile
pass, but the one original-cap route fails at B's passenger confirmation.
The first shared abort names B; A and host retain their cascading waits. All
three actual peers exit1 with .done receipts; none are forced to137. No final
host passenger/dual-seat confirmation is established. This is one observed
wrong craft label, not proof that every other passenger condition passed.

**Priority review:** select NET-CREW-HUD-CRAFT, a demonstrated player-visible
presentation gap, over another diagnostic or parked VIP/Ember work. Task-root
creation through terminal qualification took495s; the route itself134.850s.
The source owner and finite repair boundary were known. Completed source/build
repairs preceded accepted qualification fff5f7221; no further run belongs
to this FAILED card. Earlier prerequisite, compile, diagnostic and repair limits
remain counted; new card names do not reset them.

Earlier exact compile and pilot-confirmation failures remain in
[delivery history](docs/history/ROADMAP_DELIVERIES.md#ordinary-jovian-boarding--runtime-failure-held-on27879aa62),
with the later [pilot-state diagnostic](docs/history/ROADMAP_DELIVERIES.md#jovian-pilot-state--diagnostic-complete-boarding-still-failed).
The later label repair/checkpoint and accepted boarding qualification are recorded above.

## Parked VIP round trip — first runtime guard failure

Caller57fc1122a first failed to parse. The one syntax repair64c74dd46 compiles,
boots through the real menu and reaches four supported outward checkpoints:
Central X0, Aft spine, Aft connector and Aft lower junction. At `out/stair-base`,
the continuous movement guard rejected a0.400m horizontal/0.299m vertical step
near ContinuousStairRamp (horizontal limit0.177m); actual floor support remained
on StairBaseLanding. This does not yet distinguish normal production step
assistance from a defect. No VIP door/seat/return acceptance is established.

**Priority review:** the failed attempt plus one repair has reached its limit.
Park further VIP diagnosis, threshold changes and reruns this batch; select the
independent baseline definition, now complete above, and its Jovian boarding
child. Do not relabel a monitor change as a
new task to reset the limit. A future reopening requires one source-supported
movement contract and explicit scheduling before another probe, with unchanged
full route and900s cap. The exact route/caller/check contract and both failures
remain in [delivery history](docs/history/ROADMAP_DELIVERIES.md#vip-round-trip-contract--parked-after-one-repair).

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
