# Development roadmap

**Playable development alpha; a completion date is not yet defensible.**
All **36 original parent outcomes** and **ten phase gates** remain open.
Nine of the eventual 17 craft exist; eight still need supported specifications
and implementation. Partial acceptance is retained in the backlog; it is not
whole-feature completion.

Latest playable checkpoint: **bcd268c**. Network Halyard passengers now receive
accurate feedback for an occupied chair and can retry normally after it is freed.
Includes host-driven cabin roster/repair displays, multiplayer destruction
recovery/reboarding, host-authoritative bunks, Bomber seat refill and Defense
Deploy arming. Full Defense combat, full component repair, multiplayer baseline and
native gates remain open.
[Windows ZIP](builds/windows/MuddsShipyards-bcd268c-checkpoint.zip),
[build notes](builds/windows/MuddsShipyards-bcd268c-notes.txt).

This page is the working queue. The
[36-parent crosswalk and named children](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
retain complete remaining scope; the
[original ten phases](docs/history/ROADMAP_SCOPE_20261017.md)
retain the completion promises. Attempt details belong in
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not this queue.

## What finishing requires

These are delivery groups, not equally sized tasks or a percentage. They may
proceed independently where their actual dependencies permit. No release of the
current nine craft silently removes the remaining eight original commitments.

| Delivery group | Completion check | Smallest next boundary |
| --- | --- | --- |
| Fleet, station and combat | Applicable ordinary craft/role/weapon/damage/recovery/home/reuse journeys; remaining original craft built; station branches and actual art findings resolved | Select one named capability or complete journey from the existing inventory. Missing craft require SPEC, then actual build cards; no whole-ship assignment. |
| Activities and worlds | All twelve activities and required repeats; three canonical world returns and 21 shared-world cells, with rewards/save/recovery | One named activity journey or world/case at a time, preserving the complete outbound→result→usable home contract. |
| Multiplayer | Browser, helm, crew, damage/actor and postdock cases; dedicated-server/two-client baseline, original 30-minute endurance and chosen capacity | A named independently runnable case. Parked handback/boarding failures remain dependencies, not automatic retries. |
| Saves and recovery | Expected continuation, actual interruption/restart and usable controls for required contexts; conserved progress/rewards and protected invalid data | One context and durable boundary with its expected resume/safe-home behavior settled first. Four active terminal-owner policies remain unresolved. |
| Presentation, controls, audio and performance | Applicable views/captures, physical devices, authorized listening and representative native measurements; demonstrated defects fixed | One actual defect or one explicitly selected qualification case. Headless/software results retain their limits. |
| Final release | Frozen integrated candidate; full local matrix, packages, installation, rights/signing and authorized distribution with matching bytes | Final-candidate work follows required integration. Desktop targets, rights/signing inputs and applicable external gates remain open. |

The remaining task count is still unknown: missing-craft build splits, actual
presentation findings, unresolved policies and measurement cases have not all
been defined. Do not turn test counts, commits or row counts into project progress.

## Execution now

**SERVER-BASELINE-LATE-JOIN DONE — `437fe903d`.**
The original pilot boards normally and flies5.019m before the late client's
process starts. The new station Player receives current airborne craft/pilot/
ownership state without a crew grant. One sampled landing input produces actual
strict home docking and a committed landing received by both clients. The late
player walks the complete authored route, boards normally and completes the
original two-seat BOARD and all seven MOVING cabin stages with the same pilot.

Full case passes303 checks in225.667s; all three peers complete/exit0 with clean
logs. Actual B process starts0.158s after departure; exact original pilotclaim2/
seatgen1/bodyframe1/ownership1 survive docking. Both clients consume the committed
landing record at the actual authored dock. Two earlier caller failures remain
recorded: sole-pilot no-echo semantics and an absent wire-field assumption. The
existing authority predicate and actual landing contract resolve those checks;
no runtime, role, endpoint or deadline was changed.

Three candidate commits are integrated into pushed main; independent source/raw
review passes. All47 observed process identities are absent,380 scratch entries
verified/removed and results consolidated. No task branch/worktree was created.
Runtime/content/export inputs are unchanged; playable checkpoint stays **bcd268c**.
Source Linux/private-Xvfb input qualification only; full baseline, endurance,
exported/native/device/human and all36 parent/ten phase gates remain open.
[Result and retained failures](docs/history/ROADMAP_DELIVERIES.md#server-baseline-late-join--accepted--2026-10-24).

Next action: define the original SERVER-BASELINE passenger reconnect case using
actual transport loss and normal Manual Join, retaining the server/pilot and
requiring a usable physical return to crew. Its complete route and bounds must
be settled before selecting implementation or an engine trial. No parked case
is automatically retried; Actions remains disabled.

**SERVER-BASELINE-SEAT-RACE DONE — `99c9fc1af`.**
The complete original non-playing authority/two-client BOARD and seven MOVING
stages now continue through ordinary helm release, two supported contenders and
one shared chair race. The host records one claim and one occupied-seat refusal;
the original loser receives one accurate toast, then physically takes the same
chair after its winner stands. Both regain their original roles and prove renewed
authoritative flight before the complete terminal handshake.

Full case passes451 checks in170.190s, all three actual peer exits0 and clean logs.
Same-chair claim sequence7→10/currentgeneration1; original pilot ownership1→3,
pilot claim2→5 and original passenger claim12. All approach legs share the
original15s; walkers complete3.777s, approach4.600s. Three earlier caller failures
and their bounded readiness, collision-safe path and JSON comparison corrections
remain recorded. No deadline, role-fixed destination or acceptance was relaxed.

All four candidate commits are integrated into pushed main. Independent source/
raw-result review passes;66 observed process identities are absent,811 owned
scratch entries verified/removed, and results consolidated. No task branch or
worktree was created. Runtime/content/export inputs are unchanged; playable
checkpoint stays **bcd268c**. Source Linux/private-Xvfb input qualification only;
full baseline, endurance, exported/native/device/human and all36 parent/ten phase
gates remain open. Actions stays disabled.
[Result and retained failures](docs/history/ROADMAP_DELIVERIES.md#server-baseline-seat-race--accepted--2026-10-24).

The next late-join case is separately bounded above. No parked case is automatically retried.


**HALYARD occupied-chair feedback DONE — `bcd268c75`; checkpoint `bcd268c`.**
An actual host occupied-chair verdict now answers the exact current remote
passenger request once, through the existing snapshot. The client shows accurate
feedback, stays supported/usable and retries normally when the host stands.
Retained snapshots, foreign data and retired/superseded requests cannot replay
it. Seat arbitration, accepted/stand paths and the four-second expiry stay intact.

The complete original host/client passenger route plus two fresh refusals passes
107 checks in107.305s, both actual peer exits0 and clean logs. It retains host
ordinary stand/walk-clear, client retry/stand/walk/reseat, migration/rebind and
disconnect. Focused input101/body36/current consumer66/role6/panel40/privacy pass;
unchanged checks were reused by exact source comparison. Expected missing-receipt
RED, null numeric handling caught by strict logs and a test-parser correction
remain preserved. No deadline or acceptance was relaxed.

All four candidate commits are integrated into pushed main. Fresh Windows EXE/
ZIP/notes are `builds/windows/MuddsShipyards-bcd268c*`, with matching Linux packages.
Three strict startups, actual1527-entry payload/archive audit and independent
source/result/checkpoint review pass. Owned scratch and processes are cleaned;
results are consolidated. No task branch/worktree was created. This covers one
host/client and the Halyard passenger occupied-chair result. Full two-client
moving seat race/transfer, other reasons/roles, baseline/endurance, native/human
and all broader gates remain open. Actions stays disabled.
[Acceptance and retained failures](docs/history/ROADMAP_DELIVERIES.md#halyard-occupied-chair-feedback--accepted--2026-10-24).

**HALYARD network cabin roster DONE — `a0764f281`; checkpoint `a0764f2`.**
The physical panel now presents compact host crew occupancy, readiness, engineer
routing and handoff facts through the existing engineer snapshot. Ordinary
standing opens the engineer row; local refresh preserves host facts. Missing
current data shows a detached roster; leave/stop/detach retires it. Client local
crew gameplay, repair stock and component authority remain unchanged.

Focused integration passes40 assertions after reproducing two real roster
failures. The original independent Main/ENet engineer route passes82 checks in
101.641s, both actual peer exits0, retaining selection/FIRE/repair/standing/
reseat/refusal/migration/disconnect and original deadlines. It is a functional
**PASS_WITH_ENVIRONMENT_WARNING**: one Xvfb/llvmpipe V-Sync capability warning,
zero game errors; strict logs remain NOT_CLEAN. Companion regressions pass.

Both accepted commits are integrated into pushed main. Fresh Windows EXE/ZIP/
notes are in `builds/windows/MuddsShipyards-a0764f2*`; matching Linux packages,
three strict menu startups and actual1527-entry cross-platform/package audit
pass. Independent source/result/package review GO. Owned scratch is removed and
results consolidated; no task branch/worktree was created. Positive pilot
readiness is covered in the staged focused consumer; real route pilot is open.
Active emergency handoff, full crew/damage/baseline/endurance, native/human and
all broader gates remain open. Actions stays disabled.
[Acceptance and limits](docs/history/ROADMAP_DELIVERIES.md#halyard-network-cabin-roster--accepted--2026-10-24).

**COURIER-WITHDRAW-DISTANCE full ordinary outcome DONE — `719fe364a`.**
The first packaged attempt passes in 92.585s under the original 300s/outer330
limits. After four range kills and real defender preparation, ordinary flight
clears the actual encounter origin and every active craft for seven physics
seconds. WITHDRAWN occurs with the first Courier unhurt and only 59.83% through
its escape. All dispatched actors remain stood down through physical return,
actual defender defeat, strict home landing, OFFLINE and physical exit.

All 144 driver tests, observer/privacy checks, private export, menu startup,
payload audit and independent raw review pass. The accepted source is integrated
into pushed main. Owned scratch and loose qualification packages are removed;
results occupy one verified archive plus closeout.json. No branch/worktree was
created. That qualification kept gameplay checkpoint ce2329a; the current checkpoint is above.
[Full acceptance and limits](docs/history/ROADMAP_DELIVERIES.md#courier-distance-withdrawal--accepted-ordinary-flight-and-home--2026-10-24).
This closes the selected first unhurt instance; escorted instances, recovery,
repeats, native/human and parent11 remain open. GitHub Actions stays disabled.

**COURIER-WITHDRAW-PHASE full ordinary outcome DONE — `ccfaa63b8`.**
The complete packaged journey passes56.522s under original300s/outer330:
four range kills and real85→51→17 preparation, observed first live unhurt
courier, then an authoritative player kill of the original defender. The kill
callback records normal RETURN_TO_YARD while the courier is still running;
the next physics step produces WITHDRAWN. Every actually dispatched actor stays
inactive/unauthorized with no further fire through the60-frame hold and original
strict home landing, OFFLINE shutdown, disembark animation and physical exit.
Actual maximum encounter-origin radius63.412m excludes distance withdrawal.

Game package source08118186f and corrected external driverccfaa63b8 are pinned
separately: only the driver/tests changed after the clean export/startup/audit,
and all packaged runtime blobs are identical. Final141 Python tests pass. The
first full attempt caught a caller guard missing normal DISEMBARKING; the fix
admits only that phase and still requires final physical completion. Its failed
run is retained. No gameplay, encounter, tuning, placement or cap change.

Both candidate commits are integrated into pushed main. Owned scratch is removed
and116 result members are consolidated into one verified archive plus
closeout.json. No branch/worktree was created. The public checkpoint at
acceptance was ce2329a. [Full ordering proof, source pair and retained limits](docs/history/ROADMAP_DELIVERIES.md#courier-phase-withdrawal--accepted-live-dispatch-and-home--2026-10-24).
This unhurt first-courier phase instance is accepted. Distance withdrawal is
qualified separately above; escorted instances, recovery, repeats, separate
walk/UI quit, native/human and parent11 remain open. GitHub Actions stays disabled.

**COURIER-ESCAPE full ordinary outcome DONE — `393733212`.**
The complete packaged journey passes103.179s under original300s/outer330:
four range kills, two real defender wounds85→51→17, first unhurt courier
crossing1,400m/ESCAPED, all actually dispatched actors stood down, physical return
to the saved attack position, actual defender kill, strict occupied home landing,
OFFLINE shutdown and physical exit. Same Player/ship/default controls throughout;
zero game diagnostics and owned input/helper/game/display cleanup complete.

The caller now recovers only from a fresh authoritative harmless-miss receipt;
the successful run exercises that path once. A later diagnostic proved stationary
waiting had disabled the player's weapon component. The accepted waiting leg
uses fixed ordinary-flight waypoints inside the actual encounter-origin bound,
then physically returns before the inherited fight/home route. No gameplay,
damage, AI, tuning, boost, encounter constants or deadline changed. Earlier
failed attempts, the component diagnostic and a caught arrival-steering test
failure remain preserved. Final134 Python tests, observer/privacy checks and
fresh private package/startup/payload audits pass; independent acceptance GO.

All four candidate commits are integrated into pushed main. Source-specific
Linux qualification packages/raw are privately archived; public playable
checkpointce2329a retained the same gameplay at acceptance. Owned scratch and
reconstructable test caches are cleaned. No branch/worktree was created; the
original exact failedf7 source remains under its historical withheld archive tag.
[Full result, corrections, retained failures and limits](docs/history/ROADMAP_DELIVERIES.md#courier-escape--accepted-ordinary-flight-and-home--2026-10-24).
The first phase/distance withdrawals are qualified separately above. Recovery,
repeats, escort-specific cases, separate walk/UI quit, native/human qualification
and parent11 remain open.

**HALYARD network cabin repair readout DONE — `ce2329a82`.**
The physical cabin repair row now shows accepted current host progress,
completion/interruption, cooldown and stock, including for a walking occupant.
Local refresh cannot replace it with unused local stock. Missing current data
shows AWAITING HOST; cabin/session lifecycle retirement restores local display.
Client repair inventory, component health and authority remain unchanged.

Focused authored-panel coverage passes28 assertions after reproducing three real
presentation failures. The complete existing independent Main/ENet engineer route
passes79 checks in103.961s, both actual peer exits0: ordinary selector/FIRE, host
repair/one kit spent, physical progress/completion/KITS5/6, standing/local refresh,
reseating, refusals, migration and disconnect. Original route/caps are retained.
That run is **PASS_WITH_ENVIRONMENT_WARNING**: one Xvfb/llvmpipe V-Sync capability
warning, zero game errors; its strict diagnostic gate is NOT_CLEAN. Existing
local regressions and the unchanged382-check destruction/reuse journey pass.

Both candidate commits are integrated into pushed main. Fresh paired exports,
strict startup and package audit pass; playable Windows EXE/ZIP/notes are in
`builds/windows/MuddsShipyards-ce2329a*`. Owned scratch is removed,71 observed
process identities are absent, and results are consolidated into one verified
archive plus closeout.json. No branch/worktree was created or retained.
[Acceptance and retained limits](docs/history/ROADMAP_DELIVERIES.md#halyard-network-cabin-repair-readout--accepted--2026-10-24).
Full crew gameplay qualification, full NET-DAMAGE, broader baseline/endurance and native/human
qualification remain open. No parent or phase gate is closed.

**HALYARD passenger destruction recovery and ordinary reuse DONE — `f5b71e06e`.**
Actual host craft loss now retires the passenger's current cabin/chair/body state
and returns the same Player to supported station controls. Exact host boarding
claims retire with the destroyed hull. Recovery clears stale platform carry, the
former pilot stops old propulsion, and historical chair updates cannot interact
with a newly admitted body. Damage and regeneration remain host-owned.

The complete independent host/two-client journey passes **382 checks, zero
failures**, all three actual process exits zero, 197.131s. It retains original
boarding and seven moving-flight stages, then actual host destruction, both
same-Player recoveries, pause/Resume, normal regeneration, full ordinary station
return/hatch entry, new physical bodies and movement streams, fresh seat/ownership
grants and renewed flight. The final focused passenger case passes 69 checks;
the crew-cache regression and eleven existing local suites also pass. Routes,
strict supported-spawn checks and original deadlines remain unchanged.

All ten candidate commits are integrated into pushed `main`. Fresh Windows EXE,
checkpoint ZIP and notes are in `builds/windows/MuddsShipyards-f5b71e0*`, with a
matching Linux package. Strict startup and actual package audits pass. Owned
scratch is removed; all 187 observed process identities are absent. Results are
consolidated into one verified archive plus `closeout.json`; diagnostic-only
source is preserved under an archive tag and excluded from production.
[Acceptance, failed attempts and retained gates](docs/history/ROADMAP_DELIVERIES.md#halyard-passenger-destruction-recovery-and-reuse--accepted--2026-10-24).

This closes the selected recovery/reuse boundary under parents 21/26. Full
hull/component damage and repair NET-DAMAGE, wider craft/role cases, exported
multiplayer/baseline, migration/endurance, native Windows/GPU and human gates
remain open. No parent or phase gate is advanced; GitHub Actions stays disabled.

**SERVER-BASELINE contested bunk authority DONE — `f6803cf26`.**
The real host/client reproduction confirmed that the host selected Starboard while
the client received that sleep pose but still reserved and slept in Port. GameFlow
now waits for the current host posture and uniquely matched authored bunk before
presenting local rest. Host refusal leaves the player awake without a lease or
overlay; an unconfirmed request gives feedback after four seconds and permits retry.
Wake follows the host outcome. The existing host selection policy and protocol
are retained. Session/body/frame/claim fences retire this consumer's rest state;
recovery uses the current owned bunk exit, including same-frame hull movement.

The focused independent Main/ENet case passes all three occupancy phases, ordinary
E sleep/wake, refusal feedback, freed-bunk retry, actual sleeping-client shutdown,
current-exit recovery and subsequent solo sleep/wake: 116 checks, zero failures,
both actual process exits zero, 97.541s. Physical approach, host reservations and
the final hull-pose fixture are disclosed setup; this is component qualification.
The complete original three-Main moving sleep journey also passes: 428 checks,
zero failures, all three process exits zero, 162.130s, original route/caps intact.
Existing solo gameplay (31 assertions), rest lifecycle (9), berth content and
startup privacy checks pass. Review covered the authority and lifecycle changes.

Fresh checkpoint EXE, ZIP and notes are in `builds/windows/MuddsShipyards-f6803cf*`,
with the matching Linux package in `builds/linux/`. Strict startup passes for the
Linux binary/archive and Windows embedded game data under Linux Godot; all 1,527
packaged entries match and package payload checks pass. Native Windows/GPU,
rendered/device/listening/human, custom RPC-template, full baseline/endurance and
release gates remain open. No parent or cross-project percentage is advanced.

All six candidate commits are integrated into pushed `main`; no task branch or
worktree was created. Owned scratch is removed and 104 observed process identities
are absent. All 475 result members were verified into
`/srv/mudds-work/network-bunk-authority-20261024/results/case-records.tar.gz`
(SHA256 `2a41e7c51728ff71bce3692ec41794ddc765d815245c38804f752655f30e6448`),
leaving only that archive and `closeout.json`. The 21 stages include four retained
failures: intended RED, a compile type annotation, an early wake-completion fixture
and a hull-fixture settling boundary. Existing parked detached worktrees remain
untouched; GitHub Actions remains disabled.

**PLAY-DEFENSE first-point journey stopped — combat remains unqualified.**
Actual ordinary flight reached[-70.914,10.140,-90.916] with live whole-hull
clearance. In combat, two actual Arrow hits reduced Alpha85→37; no hostile was
killed. The run stopped94.626s/encounter elapsed28.15s when the caller wrongly
rejected an authored miss sentinel. That representation is corrected and157
Python tests pass, but no new full trial followed. Four kills/payment/home/Reset/
next Deploy/UIexit remain unqualified under unchanged34/300/360s limits.

Recorded first-hit windows were brief and world/core obstructions intermittent.
Camera and hull directions agree; no camera-basis repair is supported. The miss
fix alone cannot establish the full remaining wave sequence inside5.85s. No
unchanged retry, alternate point, boost, gameplay/tuning/mask or cap change selected.
Five-file candidateaae77205a is archived/unmerged; public9af4851 stays current.
All8 stages terminal/32 sampled identities absent,88 scratch entries verified/
removed. Private package moved out of builds and duplicate ELF removed.107 result
members are preserved in one verified case-records.tar.gz plus closeout.json.
[Outcome, scope and preserved archive](docs/history/ROADMAP_DELIVERIES.md#defense-first-point-journey--stopped--2026-10-24).

**SERVER-BASELINE moving sleep/wake case DONE —8b0845486.**
Full ordinary BOARD/seven MOVING, physical Port-bunk approach, sleep/wake,
supported1.212m walk and physical original-chair return/reseat pass159.806s
under the original300s cap. Host/local reservations and posture agree, both
clients consume sleeping/walking states, wake UI is present, and the original
chair earns claim7 on the same generation1. Pilot ownership/helm and genuine
hull motion remain throughout.428 checks/zero failures; all three actual OS0
and clean logs. Independent source/result review GO; exact tested file integrated.

The initial full run stopped before bunk approach because the new caller required
the pilot's walking-body stream to stay bound. Production intentionally unbinds
that stream on helm claim; the corrected guard requires pilot unbound/passenger
bound and retains identities/grants. Two parser failures and the initial full
failure remain preserved. Six owners terminal/32 sampled identities absent;
397 scratch entries archived/verified/removed. Runtime/export inputs and playable
9af4851 remain unchanged. Full baseline/endurance/native gates stay open.
[Complete result and limits](docs/history/ROADMAP_DELIVERIES.md#server-baseline-moving-sleepwake--accepted--2026-10-24).

**SERVER-BASELINE passenger-disconnect case DONE —503350e32.**
Full ordinary BOARD and all seven MOVING stages, one real passenger shutdown,
once-only body/frame/seat retirement and retained original pilot ownership/helm
pass142.626s under the original300s cap. Fresh ordinary pilot throttle reaches
the authority; departing same Player walks0.616m supported in solo mode and uses
real pause/Resume.310 checks/zero failures, all three actual OS exits0/clean logs.

The earlier barrier failures were caller assumptions: JSON number representation,
then a last-sent cache that correctly stays unset when the pilot is the sole peer
and receives no own-body echo. The corrected case verifies live registered seated
authority/current wire and actual empty audience. Shared helper/full prefix/caps
remain unchanged. Independent source/result review GO; exact tested file integrated.
Six new stages terminal/34 sampled process identities absent;366 scratch entries
archived/verified/removed. Original failures and exact diagnosis remain preserved.
Runtime/export inputs and playable9af4851 are unchanged; no duplicate checkpoint.
Full baseline/endurance/native gates remain open; no next case auto-selected.
[Complete case, cause and limits](docs/history/ROADMAP_DELIVERIES.md#server-baseline-passenger-disconnect--accepted--2026-10-24).

**DEFENSE-CLEAR-FIRE stopped — the fixed approach fails live clearance.**
The western settling adjustment reached boarding and actual departure. At the
staging stop, the first segment cleared; the full second conservative hull sweep
failed and its endpoint overlapped active PerimeterRaiderAlpha. A signed Godot
resource-ID guard was corrected; replay of the retained state then rejected the
blocked full sweep as intended. This does not prove the oriented hull cannot
travel there. No staging flight, firing, four kills, reward, home, Reset/next
Deploy or normal UI exit was qualified. No further trial or alternate route is
selected; the original full contract and time limits remain unchanged.

The five-file candidate637bc513f is unmerged and preserved under
`archive/withheld/defense-clear-fire-20261024`, with verified bundle/source/patch
and private package. Public checkpoint9af4851 remains current. All12 stage owners
are terminal,35 sampled process identities absent, and124 scratch entries
archived/verified/removed. The private package is outside builds; its duplicate
executable was removed. Final156 Python tests pass; full Defense remains open.
[Attempt details](docs/history/ROADMAP_DELIVERIES.md#defense-clear-fire--blocked-approach--2026-10-24).

**DEFENSE-LAUNCH-ARM delivered9af48515a; checkpoint9af4851.**
Owner-approved Deploy arms the encounter; actual live seated pilot departure and
authoritative occupied-berth release start enemies and the unchanged34s timer.
Board/Nearby UI says ARMED; cancel/reset/Main retirement clear the runtime-only
arm, coldload is unarmed, unpaid rewards and competing Heavy arming stay guarded.
Seven focused runtime suites and public CLI privacy pass. Actual ordinary input
retains one arm/idle0/four inactive enemies for1,028 prelaunch samples through
boarding/engine wake, then starts once at actual release. Accepted source is
byte-identical to those tested production files; fresh paired packages/three
strict startups/actual1,527-entry payload and archive checks pass. Full source
and scoped actual-result/notes reviews GO; EXE/ZIP/notes in builds/.

**Earlier full PLAY-DEFENSE failure remains retained.** The archived caller clears only two
of four hostiles before true timeout34.0167s; zero reward, home/reset/next Deploy/
normal UI exit not reached. Of57 Arrow shots,23 miss,13 hit friendly blocks and
12 hit world blocks. Alignment-only stationary firing does not establish clear
line of sight. No further combat retry, aim/geometry/timer relaxation or scope
reduction is selected; define a feasible ordinary clear-fire plan first.
Original four kills/payment/home/reset/UIexit and300/360s caps remain required.
Five failed qualification files are excluded from main, retained under verified
archive/withheld/defense-launch-route-20261024 plus bundle/patch/exact source.
[Delivery, failures and preserved scope](docs/history/ROADMAP_DELIVERIES.md#defense-deploy-arm--accepted-runtime-full-combat-still-open--2026-10-24).

All31 stage owners are terminal;108 sampled process identities absent. Owned
scratch454 entries archived/verified/removed; withheld candidate packages moved
out of builds and preserved. No working branch/worktree created; accepted work
pushed to main. Eight protected detached registrations and the original nine
unqualified candidate outcomes remain retained. No broad parent/gate closes.

**BOMBER-REBOARD-PRESENTATION completed255f8df2b; checkpoint255f8df.**
Actual refill qualification exposed a detached visual pool after seat retake.
Successful payload-session starts now reactivate it; rejected starts preserve
live effects. Existing integration25 assertions and driver122 tests pass.
The complete original-cap ordinary Bomber rearm route passes66.146s: physical
walk/board, four releases4→0, fifth exhausted refusal, OFFLINE exit/walk clear,
same-seat new-generation4, fresh release3 and final supported OFFLINE exit.
All five releases now report release_presented, including after reboard.
Paired exports, three strict menu startups and actual1527-entry payload/archive
checks pass. Independent source/result/notes reviews GO. EXE/ZIP/notes in builds/.
[Delivery and limits](docs/history/ROADMAP_DELIVERIES.md#bomber-reboard-payload-presentation--completed2026-10-21).

All five owner decisions are now resolved and their bounded outcomes delivered:
Freight interface509703300, shared Hauler custody6bcbea302, navigator requester
feedbackc2c72a223, Beacon outbound252ed6bfc/10.510574s≤60, Bomber seat-retake
refill4a0d82bff plus presentation repair255f8df2b. These do not close parent
outcomes. Select one bounded next production card from the retained inventory;
no automatic parked retry. Full Bomber flight/combat/roles/recovery, other travel
limits, full ordinary Hauler/cold inventory and WALK-FREIGHT/KIT-RELOAD remain
open. All owned scratch verified archived/removed; main only local/live branch,
accepted work pushed; protected older unqualified work retained.

**Prior Rime diagnosis closed, journey remains open.**
The selected original Rime run failed its unchanged peer landing gate after
1624.422s. It yielded105 usable sampled script frames, but no final accumulated
total: the peer timeout stopped the host before profiler flush. The controller
leg field was also unavailable. These samples locate costs but establish no
production repair or completed journey; there is no automatic retry. Temporary
source is bundled, all owned processes are absent, and64 scratch entries were
archived/verified/removed. Latest playable checkpoint is now9af4851 (Defense Deploy arming).

The earlier 45 remote heads included `main`, duplicate attempts, diagnostics and
already-integrated work; they were not 45 independent unfinished features.
There is now only `main` locally and remotely. Of the retained 20-candidate
inventory, eleven are accepted/superseded and nine remain unqualified across
these six problems. Archival and branch deletion do not complete these outcomes.

| Existing problem (candidate count) | What remains before completion |
| --- | --- |
| Browser/network timeout (2) | Obtain matching RPC-cache-patched Windows/Linux templates and pass the original complete timeout/retry journey. Current stock4.7.1 pair does not satisfy this dependency; patched Windows compilation exhausted its previous budgets. Callback cause/repair remains unverified. |
| UI transition, Mining and Observation (3) | Identify the original popup/connection-removal failure, prove a repair against that event, and finish the full Mining and Observation journeys. Later clean Beacon/tooltip runs did not establish a UI fix. |
| Defense (1) | Launch-start rule delivered9af48515a. Earlier full caller2/4 kills/timeout34.0167s retained. Latest first-point flight succeeds, but combat stops at28.15s with Alpha37/no kills on valid-miss caller bug. Sentinel corrected/Python-only; tracking, occlusion and brief input-window timing remain unqualified. Full four kills/payment/home/Reset/next Deploy/UIexit retained; no retry selected. |
| Hulk revisit (1) | Complete physical revisit and once-only breaker/cell/reward within the original300s. Last capture showed continuing supported movement; stage costs remain unlocalized. |
| Rime crew arrival (1) | Original full cost capture still fails peer landing gate1624.422s.105 sampled function frames identify costs, but missing accumulated/native attribution and actual controller leg prevent a supported repair. No retry selected; full two-crew survey/reward/save/home remains required. |
| Jovian reload (1) | Restore usable normal continuation within the original30s. State restoration succeeded at27.762s, but the first normal frame pair did not complete; no startup repair is established. |

Finish one supported correction with its full original acceptance, integration,
push and owned cleanup before selecting another. If no supported correction is
available, report that blocker explicitly; do not substitute more unrelated work.
The [original candidate names](docs/history/ROADMAP_DELIVERIES.md#every-remaining-remote-candidate)
and [45-head accounting](docs/history/ROADMAP_DELIVERIES.md#branch-accountability-and-race-timeout-diagnosis--2026-10-20)
remain preserved. Eight older detached worktrees are retained exceptions, not
active branches; their contents remain protected.

**Closed diagnosis: full Ember surface integration still times out.**
The already-running unchanged full suite stopped at its original300s cap:
90 checks passed, no assertion failed; `retired` and `local_loss` completed,
then `session` reached host-session start at299.975s. The remaining scenarios
were not completed. This identifies the boundary, not a production repair or
full-suite acceptance. Diagnostic source was bundled rather than merged; owned
processes are absent and all45 scratch entries archived/verified/removed.
No follow-up run or new implementation task is selected.

**Closed outcome: COURIER-CLEAR — full first intercept and home journey — DONE.**
The packaged original full contract passes **55.973s within its unchanged300s cap**:
ordinary Start Shift/walk/board/departure and four range targets; initial defender
kept alive through first Courier dispatch and an actual accepted/resolved player
kill before1400m, director CLEARED; then defender defeated and genuine return,
strict occupied home dock/contract/lease, automatic OFFLINE and physical E exit.
Same Player/ship, default sampler and tuning; final hull89/exit error0.17m.

The ordinary caller now prepares the defender with two controlled nonlethal hits
during the existing dispatch delay. Observed85→51→17 health/input records include
separate acknowledgments/releases and actual weapon readiness; they are not
serialized authority shot receipts. The Courier kill has its real source/target/
generation1/sequence15 lethal receipt,0.817 encounter seconds and0.582% escape.
No gameplay/balance/AI/physics/encounter change: all1524 other payload entries
match the shipped damage-fix checkpoint4cfa417; only the passive observer differs.
Underlying late-provider damage repair431aae remains included.

All113 driver tests, observer compile/privacy, paired clean exports, three strict
menu startups and1525-entry matching Windows/Linux payload audit pass. Independent
source and actual-route review GO. Accepted source4196ad0 is merged and pushed;
checkpoint EXE/ZIP/notes are available above. All ten stage owners terminal,
15 observed PID/start identities absent; both runs' named game/helper/display PIDs
also absent. All132 owned scratch entries archived/byte-mode-link verified/removed.
No branch/worktree created; all eight protected worktrees untouched. No next task
is active. Original20 inventory is now eleven closed/nine unqualified.

Prior original70.377s/no-damage capture70.465s, post-fix67.554s, weapon capture76.628s
and rejected reverse55.829s remain recorded. First preparation attempt41.436s
stopped safely with no confirmed wound: normal cooldown omitted the longer actual
overheat gate. A separately selected readiness-only correction produced the pass.
The original full kill/home/deadline contract remains intact, not replaced by
the kill prefix. Original bounded process cleanup does not establish normal UI
quit/gameOS0 or a separate supported walk. Other Courier escape/withdrawal/recovery,
repeats/reload, native hardware/human and all broader parents/gates remain open.
[Full result, retained failures and cleanup](docs/history/ROADMAP_DELIVERIES.md#courier--full-first-intercept-and-home-journey-accepted--2026-10-21).

**Closed outcome: PLAY-BEACON — complete ordinary home journey — DONE.**
The original full Home caller is restored on current source, with one narrow
mouse correction for its demonstrated alignment stall. All original 0.5°/0.9999,
header-clearance, combat, paid-file, landing and supported-walking checks remain.
The complete packaged journey passes **112.031s within the original 300s cap**:
all four beacons, one durable reward and 60 stable ticks; safe RangeHeader crossing
at hull100; four range targets/interceptor defeated; actual strict occupied home
dock, automatic OFFLINE, one acknowledged/released L and E, and 0.969m supported
walking with the same Player/capsule. Zero game diagnostics; all cleanup flags true.
Independent source and actual-route review GO.

The recorded rolled-sample regression fails the archived zero-input method and
passes the fine correction while withholding thrust until observed alignment.
All 105 existing driver tests and startup privacy pass. Fresh paired checkpoint
bc48b2a, three strict startup checks and all 1525 matching Windows/Linux payload
entries pass; source is merged and pushed. All eight stage owners are terminal,
14 observed process identities absent; owned scratch archived/verified/removed.
No working branch/worktree was created. This Beacon outcome is closed.
[Complete result, original failures and cleanup](docs/history/ROADMAP_DELIVERIES.md#beacon--complete-original-home-journey-accepted--2026-10-21).

The preceding UI capture used the actual original Home payload and did not
reproduce the old popup error. Its cause remains unresolved; this passing journey
does not declare UI-BOARD-FOCUS fixed or waive Mining/Observation failures. Original
37.713s UI failure and 307.042s alignment timeout remain recorded. The Home caller
uses its original bounded process cleanup after walking, not normal UI quit/gameOS0
acceptance. Cold restart, ten-run repetition and native hardware/human review remain open.

**Closed outcome: ACT-WRITE — Cinder saved unpaid payment retry — DONE.**
Ordinary Start now retries the exact saved earned generation. The flight objective
and activity board retain retry guidance during refused payment. After one
durable credit, flight retry guidance clears and the board shows the paid receipt. Manifests, transfer proof, unrelated data,
stale-generation and replay fences are preserved. Runtime 7ecdfec and external
cold-process launcher correction 2461d5eee are merged and pushed.

Existing persistence regression passes 27 assertions on source and against the
exact Windows embedded game data under Linux Godot; all three separate actual-file
earn/pay/paid children load that same package, exit0 and are reaped. Real files
advance unpaid generation 2→paid 3 with one credit, then remain unchanged on paid
reload. Three strict startup checks and 1525-entry Windows/Linux payload audit pass;
fresh Windows/Linux checkpoint 7ecdfec is available above. Independent review GO.
The initial packaged child-launch context failure remains recorded; the test-only
correction changes no exported runtime input and did not require identical builds.

All 9 stage owners are terminal and 30 observed process identities absent. Owned
scratch was archived, all 168 entries verified, then removed. No working branch
or worktree was created. This payment-retry outcome is closed.
[Result and limits](docs/history/ROADMAP_DELIVERIES.md#cinder-saved-unpaid-payment--ordinary-start-retry--2026-10-21).
The new Start/refused-write checks use a focused production fixture; no complete
ordinary-input payment-outage journey or native Windows claim is made. Active
manifest restore, restock/entitlement policy and four legacy cargo access
assertions remain separate; their missing-persistence fixture prerequisite is
not counted as four demonstrated runtime bugs.

**Closed outcome: PLAY-CINDER-SUPPLY — DONE, merged and pushed as9ed9a0709.**
The complete original ordinary-input packaged journey passes216.291s within its
unchanged300s limit; the supply activity completes within120s. All13 station,
6 outbound cargo,6 reverse cargo,5 additional reboard-clearance and1 home walking
arrivals pass. Actual one-crate transfer, one durable payment, duplicate refusal
and exact protected file conservation through home include the unrelated race
record. Strict home dock, automatic OFFLINE, authored physical exit, supported
1.234m walk and normal UI quit reach actual gameOS0. Independent review GO.

The reboard controller now approaches nearby goals without yaw orbiting. Runtime
repairs remove per-timer unrelated nearby-directory/persistence refreshes and
preserve the current sortie when reboarding the same craft at a live occupied
remote berth. Home/new-hull resets, explicit race starts and original clocks,
physics, input sampler, waypoints and strict conservation checks remain intact.
The real boarding regression fails only its two conservation checks against the
old package and passes all26 checks on corrected source; activity integration49
and startup privacy checks pass.

Fresh Windows/Linux checkpoint9ed9a07, three strict startup checks and the complete
1525-entry matching payload audit pass. Owned scratch is archived/verified/removed;
three duplicate executables removed after archive-byte checks. No working branch
or worktree was created; main remains the sole local/live remote branch and eight
protected detached worktrees are untouched. No successor task has been started.
[Full result, actual causes, checkpoint and cleanup](docs/history/ROADMAP_DELIVERIES.md#cinder-supply--complete-ordinary-delivery-and-home-return--2026-10-21).

This closes the first funded supply journey, not repeat/restock/Hauler policy or
the four separate broader cargo activity/lifecycle failures. Native Windows,
native GPU, physical devices, audible listening and human review remain NOT_RUN;
all36 original parents and ten phase gates remain open. GitHub Actions stays off.

**Existing working-branch backlog cleared; unfinished product outcomes remain open.**

Resolve one existing branch at a time. Before selecting another, either merge and
push accepted work and delete the branch, or preserve its unique source/results
and record the exact unmet requirement and blocker. A failed check does not
automatically authorize an adjacent task or retry.

**184 local and 110 live remote branches deleted; main is the sole local and
live remote branch (zero non-main branches).** Counts describe refs,
not completed features. [Branch accounting and closeouts](docs/history/ROADMAP_DELIVERIES.md#branch-accountability-and-race-timeout-diagnosis--2026-10-20)
preserve the underlying roadmap requirements.

Earlier duplicate cleanup removed 15 local branches already integrated in pushed
main: one by ancestry, 14 through 20 exact patch matches. Their 15 clean,
unowned worktrees are removed; original cherry-picked histories are retained in a
verified bundle. The superseded original Jovian exit caller is archived under a
pushed tag and its local/remote branch deleted. Its retained docked-pilot
successor is now accepted and closed below.

The five local-only exceptions are now accounted for and removed. Cargo capture
and the durable suite launcher are already integrated; the original native and
Sandbox route tooling are superseded by main. The withheld settle-facing guard
remains absent and failed. Exact original histories survive in a verified bundle;
three diagnostic histories also have pushed archive tags. Two clean cache-only
worktrees are removed. Full Sandbox/recovery/reuse remains FAILED/open.
[Five-branch closeout](docs/history/ROADMAP_DELIVERIES.md#five-local-only-branches-accounted-and-closed--2026-10-20).

All 20 candidates in the [earlier inventory](docs/history/ROADMAP_DELIVERIES.md#remaining-branch-status-after-duplicate-closeouts--2026-10-20)
are now accounted for: eleven outcomes closed through accepted/superseded work,
and nine candidates still unqualified. Courier clear/home is now accepted on4196ad0;
Beacon Home remains accepted onbc48b2a after its complete ordinary route. Fire restart, Halyard
gunner damage and Salvage retain their accepted scopes; archive tags retain failed histories.
This clears the branch queue; it does not close remaining gameplay,
qualification or release requirements. No unaccepted source was merged to reduce
a branch count. Eight previously protected detached worktrees remain unchanged.

**SERVER-BASELINE pilot-disconnect case DONE — `21817ab4b`.**
After the full ordinary boarding and moving-cabin route, the original pilot
leaves once. The server retires that pilot's authority, while the same passenger
stays connected and can stand/reseat; the departing pilot has usable solo
throttle and pause/Resume. All three game processes exit0 with clean logs in
145.446s. Accepted Linux-source case merged/pushed; owned scratch removed.
Full baseline/endurance/package/native gates remain open. Runtime3767687 is
unchanged; no identical checkpoint rebuild.
[Case, command and validation](docs/history/ROADMAP_DELIVERIES.md#server-baseline--ordinary-client-pilot-disconnect-accepted--2026-10-21).

**UI blocker remains parked after two bounded captures.**
Correct native coordinates admit the real Destination tooltip, but ordinary Exit
closes cleanly. A clean Linux release capture of the shared Beacon entry prefix
also passes: both Activity Board transitions have no visible popup or popup-owned
root connections. Neither result reproduces the original Beacon-home error.
No runtime repair or full journey accepted. The missing fact is the popup and
connection-removal event in that original caller; another generic probe is not
scheduled. Diagnostic source/results are preserved and owned scratch removed.
[Latest result and limits](docs/history/ROADMAP_DELIVERIES.md#activity-board-synchronous-transition-capture--2026-10-21).

**Existing FIRE-RESTART DONE — source `3a45c4d79`.**
Visible Fire-row raw F13 capture and real-file Apply+Save pass. A distinct
process loads that exact file; its visible row, InputMap and production input
sampler agree on F13 press/release, with former F and left mouse rejected.
Original gamepad bindings and unrelated saved data remain exact. Both processes
exit0 with clean logs under their original300s limits; independent review GO.

The reader caller previously sampled before Godot dispatched its queued raw
input. It now flushes through the actual engine dispatcher before sampling,
matching existing raw-input fixtures. No logical-action/provider/flag override
or expected-result change. Previous failures and their preserved source remain
recorded. Accepted caller merged/pushed; owned scratch verified/removed and all5
observed process identities absent. Main remains the sole working branch.
This closes the original Linux-source composition; physical-device/fullSettings/
OS-input/native/final-package gates remain separate. Runtime3767687 unchanged,
no identical rebuild.
[Full original result, source cause and cleanup](docs/history/ROADMAP_DELIVERIES.md#existing-fire-restart--full-raw-dispatch-and-separate-process-contract-qualified--2026-10-20).

**Existing Salvage ordinary journey DONE in current Linux source scope.**
The normal hub approach, all three inspections and authored grades, published
real-file manifest, separate-process restoration, physical revisit and full
return to the retained hub spawn are accepted. ACCESS9749f742c,
INSPECT5189436f1 and REVISITf7abac379 retain every original outward/reverse goal
and movement/time limit. Inspection passes103.609s; revisit passes107.025s.

The first reader failed because normal saved-session recovery starts at the
Torrent exit, making its assumed first leg too long. The sole correction records
that actual recovery and walks to the retained hub before the original route;
no recovery bypass, profile change or cap increase. The authentic writer profile
is read before the new Main exists. All four physical repeat interactions retain
the actual file payload/generation; the full return conserves the published slot.

Independent final review GO, source merged/pushed, both owned scratch roots
archived/verified/removed and their processes absent. No new branch/worktree.
This qualifies existing gameplay through InputEvent/held controls and isolated
Xvfb, not production Boot/OS-XTest/native hardware or final-package acceptance.
Runtime/current3767687 checkpoint unchanged; no identical rebuild.
[Inspection/publication](docs/history/ROADMAP_DELIVERIES.md#existing-salvage-inspection-and-publication-qualified--2026-10-20),
[fresh-process revisit and recovery correction](docs/history/ROADMAP_DELIVERIES.md#existing-salvage-durable-physical-revisit-qualified--2026-10-20).

**Existing Halyard gunner damage task DONE — source `c28f7ffa3`.**
The original moving-cabin/co-pilot/remapped-FIRE route now reaches one actual
52-damage hit through GameFlow, live combat authority, resolver and the target's
production damageable, then standing/walking/helm return/reseat/lifecycle cleanup.
All49 assertions pass52.341s, exit0, clean logs. The earlier failures used a
headless backend although this test declares input-only: mouse capture stayed
visible and look events were ignored. The unchanged test passes with private
Xvfb/explicitx11/Dummy/dummy renderer; no guessed walk or gameplay repair.

Original exterior and target fixtures remain disclosed; this is focused source
qualification, not OS-XTest/network/native-GPU acceptance. Caller-only changes
merged/pushed; current runtime/checkpoint3767687 unchanged, no identical rebuild.
All3 owners terminal/7 observed identities absent;51 profile entries verified
before owned scratch removal. No new branch/worktree; protected worktrees intact.
[Acceptance and preserved failures](docs/history/ROADMAP_DELIVERIES.md#existing-halyard-gunner-damage-qualified-on-its-declared-input-display--2026-10-20).

**Defense autonomous-flight defect fixed — shipped on `37676874f`.**
The relief enemies' authored stand-off exceeded the available arena, so ordinary
retreat crossed the leash and ended the encounter. Their mover now limits its
next velocity inside the unchanged encounter-local boundary. Five seconds of
real enabled relief flight reaches the former escape face without leaving;
external escape still aborts and real resolver destruction still works. No actor
placement or changes to tactics, speeds, health, damage or the34s limit.

Five focused suites and three strict packaged startups pass; actual1525-entry
Windows/Linux payloads match. Fresh Windows EXE/ZIP/notes are in builds/windows;
independent scoped review GO. Accepted source merged/pushed; all12 test/export/
startup owners terminal,18 observed identities absent,201 profile entries verified
before owned scratch removal. No new branch/worktree; protected worktrees intact.
[Fix, validation and limits](docs/history/ROADMAP_DELIVERIES.md#defense-autonomous-flight-boundary-fixed-and-checkpointed--2026-10-20).

**Historical PLAY-DEFENSE candidate `0b11486e0` remains unqualified.**
Current first-point failure and next-action limits are recorded at Execution now.
The completed-motion correction now passes the original walking route, real
Arrow boarding and departure. One actual player kill is recorded. The full
encounter then aborts at frame3184 with three hostiles remaining and elapsed
33.9999999999994s. This is recorded as **aborted**, not an explicit timeout.
Source/raw positions indicate gamma crossing the authored origin leash; the
actual leash-exit receipt was not captured, so that trigger remains an inference.
No completion, payment, home, physical Reset, next Deploy or normal UI exit.

105 focused checks, privacy, fresh paired exports, three strict startup checks
and actual1525-entry package comparison pass. The ONE full journey fails88.261s;
whole34s/CAP300/outer360 and every required outcome remain unchanged. Cumulative
measured stages/audit946.376s retain all prior failures. That full journey stays
NO-GO despite the separately accepted runtime fix above. Its first kill at about30s
left less than the remaining10.5s authored delays, even with instantaneous other
kills. Establish a feasible ordinary boarding/combat plan before another full
qualification; no full retry, shorter contract or timer change is selected.
Owner approved2026-10-24: arm at Deploy, start the34s encounter on actual launch.
DEFENSE-LAUNCH-ARM is delivered9af48515a; newer full caller still times out with2/4 kills and remains archived/unmerged, as above. Original failed trajectory remains retained. Read-only timing review found no proven clear-fire plan;
no new engine attempt was made.

Unique source survives in pushed `archive/withheld/defense-completed-motion-20261020`
and verified incremental bundle/patch/five-file tar. Eight unqualified artifacts
moved out of public builds into private results. The fresh scoped checkpoint
above uses its own accepted clean source; it does not promote these failed bytes.
All10 owners terminal/23 observed identities absent;134 profile entries verified
before owned scratch removal21:20:52UTC. Eight protected worktrees untouched.
Main is the sole local/live remote branch; unaccepted code remains unmerged.
[Exact outcome and retained source](docs/history/ROADMAP_DELIVERIES.md#defense-completed-motion--boarding-and-one-kill-full-journey-aborted--2026-10-20).

**NET-JOVIAN-REDEPART DONE — source `bc7f9f9c4`.**
The complete ordinary Jovian journey now covers initial boarding/flight/home
landing, passenger physical exit/reboard, pilot physical exit/groundwalk/reclaim,
then departure again with the same crew and hull. Actual forward travel reaches
5.208m before braking; final host travel is11.655m and speed0. The old home lease,
occupant/reservation and bookkeeping release, and both clients consume flying
landing generation2 with fresh stopped poses. Pilot/passenger authority stays
current; the retired stream was refused during the full prerequisite journey.

Full route PASS168.850s, three actual OS0 and clean logs; independent final GO.
Pilot and passenger stop errors0.493m/0m are within the original0.5m tolerance;
both actual seat-anchor errors0. No larger cap, staging, second landing or
production edit. A pre-launch review moved the client strict-stop flag after
actual local convergence, preserving its original5s allowance. All three owners
terminal/18 observed identities absent;226 profile entries archived/verified
before exact owned scratch removal. Accepted source integrated/pushed; main sole
local/live remote branch, no new worktree or attempt ref.
Runtime/assets/tools match49bc7b736; latest playable49bc7b7 remains current.
[Proof and limits](docs/history/ROADMAP_DELIVERIES.md#jovian-departure-after-physical-crew-reuse--accepted--2026-10-20).
Other supported craft/roles, distinct second landing, full baseline/endurance and
all parent/phase/native/human gates remain open. No adjacent case selected.

**NET-JOVIAN-PILOT-RECLAIM DONE — source `07ec703c7`.**
After the complete passenger exit/reboard and pilot exit/groundwalk journey,
the same original pilot clears the hatch lockout, walks back through the authored
hatch/cabin and takes the real helm using ordinary movement/look/Interact.
Host and both clients confirm current ownership/seat/source and higher wire epoch;
one reconstructed retired-stream probe receives an actual stale_stream refusal.
Passenger keeps its exact co-pilot chair, strict occupied home lease and landed
generation1 persist, and hull displacement/speed remain0. No redeparture proved.

Full route PASS165.990s/6571checks, three actual OS0 and clean logs; independent
final GO. Original failed169.246s attempt is retained: the new caller wrongly
required an owning pilot to receive its intentionally excluded seated echo.
The corrected pilot checks its actual swap/local seat/producer/fresh hull pose;
the passenger still requires the exact remote seated relationship. No game-code
change or cap increase. All five owners terminal/32 observed identities absent;
409 archived profile entries verified before owned scratch removal. Accepted
source integrated/pushed; main remains the sole branch, no new worktree.
Runtime/assets/tools match49bc7b736; latest playable49bc7b7 remains current.
[Proof and limits](docs/history/ROADMAP_DELIVERIES.md#jovian-original-pilot-helm-reclaim--accepted--2026-10-20).
Repeat departure is now accepted above; full parent/phase gates remain open.

**NET-JOVIAN-PILOT-EXIT DONE — source `63186dc80`.**
The full original passenger boarding/departure/home landing/exit/reboard/chair
journey passes, then the original pilot uses normal Interact to physically leave
through all authored hatch/airstair waypoints and walks1.255m supported on berth
ground. Host retires its exact old pilot source, command queue, ownership, seat,
body/publication and relationship; both clients consume that retirement. The same
passenger stays in its exact co-pilot chair, hull error/speed remain0 and the
strict occupied home lease/landed generation hold through final release.

Full route PASS153.310s,4338 checks/zero failures, three actual OS0 and clean logs.
The first153.970s failure is retained: the new caller incorrectly expected a
coasting pose header's pilot attribution to become0. That field never emits0;
actual ownership already retired correctly. A reviewed observation correction
requires a fresh same-hull pose after the host retirement boundary instead.
No production behavior or original scope/cap changed. Independent final GO.
Owned scratch removed after348 profile entries verified;30 observed identities
absent. Accepted source pushed; no new branch/worktree. Redundant attempt tag
removed after its failed source became reachable through accepted pushed main.
Runtime/assets match49bc7b736 exactly, so latest playable remains49bc7b7 without
an identical rebuild. Pilot reclaim/redeparture are now accepted above; full
baseline/endurance/native and all parent/phase gates remain open.
[Original requirement, failed check and full acceptance](docs/history/ROADMAP_DELIVERIES.md#jovian-original-pilot-exit--accepted--2026-10-20).

**NET-JOVIAN-PASSENGER-REBOARD DONE — source `49bc7b736`.**
The full original ordinary boarding/departure/home landing/physical exit/ground
walk/reboard/requested co-pilot chair journey passes149.242s, all three actual
OS0, one marker and clean logs. Host and passenger first agree on a fresh standing
body with no chair assignment, then both clients consume the deliberate chair
claim. Original pilot/source and strict occupied home lease remain current.

Actual tracing identified the missed case: exit Interact ID3 was accepted but
never consumed before old body retirement at consumed ID2. The rebound neutral
opening carried3 and claimed a chair. The accepted producer change snapshots its
counter on bind and emits0 until a fresh post-bind press; lifetime IDs and retry
behavior remain intact. Source98 and real-body42 assertions pass, including a
real queued-but-unconsumed regression. The insufficient owner-floor fix stays
absent. Diagnostic tracing stays archived and absent from production tests.

Fresh paired exports, three strict menu checks and matching1525-entry package
audit pass; Windows EXE/ZIP/notes are in builds/windows. Independent review GO.
All12 owners terminal,45 observed identities absent;445 profile entries verified
before owned scratch removal. No new branch/worktree; main remains sole branch.
Prior failed candidates and caps remain recorded. Native Windows/GPU/devices/
human, full multiplayer baseline/endurance and all36 parents/ten phase gates
remain open. Pilot exit/reclaim/redeparture are now accepted above.
[Actual cause, full acceptance, checkpoint and cleanup](docs/history/ROADMAP_DELIVERIES.md#jovian-passenger-reboard--accepted--2026-10-20).

**HALYARD-AUTHORITY-STOP DONE — current source `082da79c9`.**
The complete ordinary boarding/departure/moving walk/chair sequence passes, then
its non-playing host stops once while the original pilot and passenger remain
aboard. Both original clients receive actual transport server_disconnected and
production session_stopped events. Old boarding, prediction, body, crew-seat and
helm bindings retire. The pilot samples usable local throttle; the same former
passenger walks 0.616 metres supported in the solo cabin. Both use real pause
and Resume controls. All three actual game processes exit0; one marker and zero
runtime diagnostics in142.082s within the original300s/outer360s limits.
Two compile failures were corrected only by grouping lambda expressions and
explicit WeakRef types; no route or acceptance changes. Independent review GO;
accepted source pushed to main. Owned profiles archived/verified and removed,
all17 observed identities absent; no new branch/worktree. Current Linux source
qualification only: full server baseline, endurance, reconnect/migration,
native/hardware and final-candidate gates remain open. No game-code change or
identical rebuild; latest playable checkpoint remains0070248.
[Original case, actual results and cleanup](docs/history/ROADMAP_DELIVERIES.md#halyard-real-authority-stop--accepted--2026-10-20).

**HALYARD-MOVING-CABIN DONE — current source `2e117e64f`.**
The original non-playing authority and two independent clients complete ordinary
boarding, then the same pilot physically departs 5.175 metres. The same passenger
stands, walks 1.181 metres, sits, stands and reseats while the hull genuinely
moves. Host physical support/identity checks and both clients' consumed current
state pass at every stage; chair claims advance 1→3→5. All three actual game
processes exit 0 with clean logs and one completion marker.
The existing caller now has one complete moving selector. Its first attempt
failed an invalid passenger-local engine check; one bounded correction consumes
the existing accepted host engine presentation instead, preserving ONLINE and
all original route/ownership/motion checks. Both attempts remain recorded.
Original 300-second route, 360-second outer, 15-second walk and 8-second role
limits are unchanged. Independent final review passed; source/cache unchanged.
Owned profiles are preserved/removed and all 30 observed process identities are
absent. No new branch or worktree; accepted source is pushed in main.
This qualifies current Linux source with isolated input-only Xvfb sessions.
Authority-stop is accepted separately above. Endurance, native/hardware, full
role journeys and the complete server baseline remain open; no successor is
scheduled. No gameplay change or new checkpoint; latest playable build remains `0070248`.
[Full original case, failure, correction and cleanup](docs/history/ROADMAP_DELIVERIES.md#halyard-ordinary-moving-cabin--accepted--2026-10-20).

**Ember first-relay cold recovery DONE on package `923d7b3`.**
The full named check passes: save the unpaid first relay, kill and reap the game,
restart through Boot into the safe yard with exact progress retained, board
again, complete the original survey and receive exactly one durable reward.
Actual process exits are -9 and 0, logs are clean, and source/cache stay unchanged.
The original archive and external metadata were verified before staging; no game
or comparison change. Caller `6112944d0` qualifies the immutable `923d7b326`
package with the original 300-second process and 660-second overall limits.
Earlier failures remain recorded. Independent review passed; temporary staging
and profiles are removed, and all five observed process identities are absent.
Cleanup took 7.72 minutes within the selected 15-minute window. Main remains the
sole working branch; latest playable build `0070248` is unchanged.
Canonical outbound, normal controls and native GPU remain NOT_RUN; standing-pose
restoration remains NOT_SUPPORTED. Other world/recovery requirements stay open.
[Full result, timing and retained scope](docs/history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-recovery--exact-package-accepted--2026-10-20).

**Remaining ten working branches accounted for and deleted.**
Browser-cache diagnostic and network-timeout acceptance preparation, Courier,
Defense, Halyard damage, Salvage access, Jovian reload, Fire restart, HULK revisit
and Rime crew arrival have verified source bundles, binary patches and exact
source archives, with pushed `archive/withheld/<original-branch-leaf>` tags.
All 19 unique commits/32 source-file entries are preserved; current live tips,
remote tag objects/peeled tips and registered ownership were checked before
expected-OID branch deletion. Main is the sole local/remote working branch.
Original failures and budgets remain retained. Halyard gunner damage and Salvage
access have since been accepted above; other missing outcomes remain in the backlog. Accepted fixture, physical E Deploy and other partial scopes
remain distinct. No engines, compile, route retry, new branch, gameplay acceptance
or checkpoint. Closed at 17:31 UTC inside the selected 17:28–17:48 accounting window.
[Exact source identities and ten retained gaps](docs/history/ROADMAP_DELIVERIES.md#remaining-ten-working-branches-accounted--2026-10-20).

**UI, Mining and Beacon-home working branches accounted for and deleted.**
Seven unique commits across the three branches survive in independently verified
Git bundles, binary patches, exact source archives and pushed WITHHELD tags:
`archive/withheld/ui-board-focus-20261018`,
`archive/withheld/mining-first-play-20261018` and
`archive/withheld/beacon-home-20261020`. No unqualified source was merged.
The UI branch contains diagnostic instrumentation; Mining and Beacon-home contain
opt-in qualification tooling whose original journeys failed at the Activity Board.
UI component9.627798881s, Mining61.9252887s failed cumulative and Beacon37.713s
actual route retain their original budgets and full acceptance contracts.
Original Main popup identity/root recipients and the prior connection-removal
cause remain unknown. UI remains PARKED/OPEN; Mining six-second extraction,
persisted capacity receipt and home return, and Beacon home/dock/shutdown/usable
exit remain unaccepted. Accepted Beacon traversal/settlement remains in main.
No engines, gameplay changes or new checkpoint; playable0070248 unchanged.
The group closed at17:26 UTC within its selected17:21–17:41 accounting window.
[Source preservation and remaining gaps](docs/history/ROADMAP_DELIVERIES.md#ui-mining-and-beacon-working-branches-accounted--2026-10-20).

**Tooltip candidate accounted for as WITHHELD; working branch deleted.**
All five unique commits/seven exact source files survive in verified bundle,
binary patch, source archive and pushed tag
`archive/withheld/exit-tooltip-order-20261020`. Its10-line close-time GUI-input
change is unmerged and unqualified. The private Observation route passed, but
never exercised the original visible embedded TooltipPanel; later baseline also
failed to produce it. Original814.146s checks remain preserved. No new engine,
implementation, acceptance or checkpoint; playable0070248 unchanged.
Local/remote/tracking branch removed after archive/tag/live-tip/ownership checks.
WALK-OBSERVATION and the actual tooltip-close regression remain OPEN. Before any
further repair attempt, observe the real visible tooltip/root bindings and
actual hover owner/pointer/window/foreground state; retain original normal-close
and complete travel/view/home acceptance. Historical source must be adapted to
current owners rather than overwriting newer observer/driver/startup work.
[Withheld archive and unmet requirement](docs/history/ROADMAP_DELIVERIES.md#tooltip-candidate-accounted-and-archived--unqualified--2026-10-20).

**Passenger-role fix and full yaw/handback accepted; both related branches closed.**
Source007024839 merged and pushed in main2f75e834b. Confirmed standing passenger
HUD uses the current cabin claim/craft, preserving pilot/crew precedence and
all ownership. Full136.675s ordinary three-peer route PASS clean: both yaw turns,
normal helm Interact, owner0/generation+1, source/capture retirement, same supported
former pilot, honest PASSENGER HUD and original seated co-pilot. Ordinary lateral
chair clearance then the original backward walk satisfy every original>=0.6m
localhost gate plus additional backward projection after clearance. Walk completes
1.617s within the same15s deadline; all three actual OS exits0. Paired exports,
three strict startups and actual1525-entry package audit PASS; checkpoint0070248.
All65 final process identities absent;280 profile entries verified; owned scratch
removed20.68min within original45min. The role branch is deleted local/remote/
tracking. Its older handback precursor is also deleted after exact patch/blob
matches to accepted9d2173e85, with original history/source in a verified bundle
and two-file archive. Failed first controller attempt remains preserved; total
known stages933.225s includes all original423.260s and failed204.498s, no reset.
Other action-specific handback, physical devices, native/endurance/final gates
and postdock reboard/pilot exit/reclaim/redeparture remain open.
[Acceptance and both branch closeouts](docs/history/ROADMAP_DELIVERIES.md#passenger-hud-and-yaw-handback-accepted-both-branches-closed--2026-10-20).

**Jovian passenger exit accepted; existing branch merged and deleted.**
Source861c4d39b is integrated in pushed main2352d18c3. Original ordinary host/two-
client journey138.470s PASS: deliberate exit E, all seven physical route poses,
same supported player/ground walk, passenger claim/body retirement, retained
pilot and all three actual OS exits0; zero diagnostics. Focused station targeting,
pose and support checks pass. Paired exports, strict three-startup checks and
actual1525-entry payload audit pass; checkpoint861c4d3 published in builds/.
All65 final-run process identities absent;267 profile entries verified; owned
worktree/profile/helpers removed23.65min within original45min. Local/remote/
tracking branch deleted after exact-tip/ownership/pushed-main checks.
Failed fixture and receipt-diagnostic attempts remain preserved in history;
combined current stages1860.013s plus original parser failures are accounted.
Postdock reboard, pilot exit/reclaim/redeparture, other craft and second landing
remain open; no broad parent/phase or native/human gate closes.
[Accepted result and closeout](docs/history/ROADMAP_DELIVERIES.md#physical-jovian-passenger-exit-accepted-and-branch-closed--2026-10-20).

**Existing Halyard boarding branch finished and merged on 4bc0e3b38.**
Full original ordinary menus/spawn/continuous walks and real pilot/passenger
boarding pass in 130.472s under unchanged 300s suite/360s outer limits.
Non-playing authority and both original independent clients retain exact peer/
avatar/ownership/body/frame/seat/claim generations, supported controls and honest
PILOT/PASSENGER HUD; all three actual OS processes exit0 and complete the terminal
handshake. Scalar comparison projections now use the same JSON representation;
no runtime/network/placement/deadline/criteria changes. Source and actual-result
review: GO. Moving-cabin/departure/server-stop/native/human remain separate/open.

Existing branch is merged/pushed/deleted. All 21
observed owned identities absent; raw receipts/logs, profiles and helpers preserved;
owned worktree/profile/helpers removed in 8.74min
inside 30min. New stages 166.878s; earlier two failed routes 271.737s remain
recorded separately (old setup time NOT_RECORDED). Current playable checkpoint
c78e0ac and all 11 public artifact hashes remain unchanged; this changes only an
excluded qualification test. No identical rebuild or adjacent case was selected.
[Delivery](docs/history/ROADMAP_DELIVERIES.md#halyard-ordinary-boarding-branch-finished--2026-10-20).

**Existing Breach interruption branch finished and merged.** Full original
BREACH-INTERRUPTION earned-debt release case passes on c78e0ac: genuine unpaid
completion, live owned kill/reap, distinct normal cold Resume/real pilot/exit/
physical board retry, one atomic receipt+acknowledgement, and third cold paid
replay. Both source and exact archive-extracted executable complete all three
processes. Setup/target-damage fixtures remain disclosed; ordinary combat and
active-combat restoration are not qualified by this case.

The old failure sampled shared-store metadata after payment's next tutorial save.
The existing probe captures the actual primary at the board signal, before
tutorial publication, and requires receipt and paid terminal in that same document.
A second proven caller correction serializes only the expected live integer ledger
for comparison with the JSON-decoded ledger; all eight checks remain exact.
All previous assertions and original 1000s/child300s limits remain.
Fresh privacy/compile, paired exports, three strict menu startups and actual
package audit pass. Independent source and final-result review: GO.

Existing `feat/breach-interruption-fixed-boot-20261018` is merged/pushed/deleted;
owned worktree/profile/helpers removed after verified preservation. New stages
352.043s plus retained 249.405s/four failures give 601.447s. Only this
attempt's `results/` remains. Native Windows/GPU/devices/audio/human/final gates
remain NOT_RUN/open and CI disabled.
[Delivery and limits](docs/history/ROADMAP_DELIVERIES.md#breach-interruption-branch-finished--2026-10-20).

The original active-tooltip runtime candidate remains unmerged and archived.
The current UI blocker and exact reopening condition are recorded above;
[historical attempts and retained budgets](docs/history/ROADMAP_DELIVERIES.md#existing-tooltip-hover-admission--original-close-error-not-reproduced--2026-10-20)
remain unchanged.

**Existing Perimeter branch finished and merged.** Runtime/admission integration
is shipped in fdae1cb above. The original Breach test remains byte-identical;
its 48 assertions pass in 76.650s and the separate actual-Main Hold case passes 19
assertions under their unchanged 90s limits. Director/asset/board/HUD/staged Hold/
Wing checks, paired exports, three strict menu startups and actual package audit
all pass. Independent source/result review accepted the scoped delivery.

Existing `feat/perimeter-live-20261020` is contained in pushed main; its local,
remote and tracking refs and owned worktree/profile/helpers are removed after
verified preservation. Only this attempt's `results/` remains. New supervised
stages 378.870s plus retained 363.897s give 742.767s; original failed attempts
remain recorded. Full ordinary Hold and parent 11 remain OPEN. Native Windows,
GPU/devices/audio/human/final gates stay NOT_RUN/open; CI stays disabled.
[Delivery and actual limits](docs/history/ROADMAP_DELIVERIES.md#perimeter-live-branch-finished--2026-10-20).

**All three prepared production cards completed: Freight interface, shared Hauler manifest and navigator requester refusals.**
Courier remains closed. All five choices below are settled; no completed diagnostic schedules an adjacent probe.

### Completed production repair — Jovian passenger reboard

NET-JOVIAN-PASSENGER-REBOARD is accepted on49bc7b736 with its fresh checkpoint
and full original journey, as recorded above. Original pilot exit and
[NET-JOVIAN-PILOT-RECLAIM](docs/ROADMAP_BACKLOG.md#net-jovian-pilot-reclaim--reacquire-the-same-helm)
and repeat departure are also accepted above. Other craft/roles and full parent gates remain open.

### Next three production deliveries

These three prepared cards are now completed; their existing acceptance contracts
remain below. Root selects one next child before assigning implementation.
Freeze exact files, commands/caps and estimates at that point. The checks below
are acceptance intent, not permission to run an unfrozen engine command.

| Existing child / parents | Player result and implementation boundary | Done for this card | Dependency and cost |
| --- | --- | --- | --- |
| [FREIGHT-TERMINAL-INTERFACE /7,9,13](docs/ROADMAP_BACKLOG.md#freight-terminals--physical-interface-and-existing-transfer-owner) | Ordinary E at existing Freight fittings reaches the genuine cargo job/manifests/receipt. Owners: JovianFreightBerth fittings, FreightJobTerminal and GameFlow cargo composition. | Actual Main interaction, range/re-entry/refusal/current-owner checks; existing conserved stock and once-only settlement preserved; fresh playable checkpoint. This does not close full Freight delivery/reload/walk. | DONE on509703300/checkpoint5097033: staged actual-Main initial and saved interaction checks, existing conserved/once-only suite, focused companions and package startup pass. Full ordinary walk/cold reload remain open; no new inventory. |
| [HAULER-CARGO-MANIFEST /10,13](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries) | Hauler joins the real supply contract with the correct conserved stock owner. Owner: NearbySectorActivityBinding admission/custody; existing generation-floor API and CargoTransferAuthority retained. | Jovian→Hauler→Jovian current ownership, stale-handle refusal, no recreated stock, exact conserved destination/receipt; fresh playable checkpoint. Full ordinary Hauler delivery stays separate. | DONE6bcbea302/checkpoint6bcbea3: same-manifest shared custody, two staged conserved deliveries and exhausted reacquisition; focused/access/debt checks, paired checkpoint and package startup pass. Full ordinary Hauler delivery/cold inventory remain separate. |
| [AUDIO-NAVIGATOR-CLIENT-REJECTION /30](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next) | The actual requesting client gets one accurate refusal cue/caption for its current request. Existing passenger binding, ENet adapter, GameFlow and navigator audio lifetime owners carry the response. | Distinct equal refusals each present once; stale/replayed/foreign responses stay silent; accepted/clear behavior and full existing peer route retained; fresh playable checkpoint. Dummy checks establish dispatch, not listening. | DONEc2c72a223/checkpointc2c72a2: six focused suites and full252-check actual peer profile, current missing-consumer/bridge refusals, paired packages/startups/audit and independent review PASS. Listening/native/full-travel gates remain open. |

A card closes on its stated result, then commit/push, record actual time and clean
owned scratch. Its downstream delivery, reload, full branch or final-candidate
qualification becomes a separate selection with the original acceptance retained.
No card expands silently to cover every adjacent defect.

### Owner decisions — accepted2026-10-21

The user explicitly answered all five choices. Implement them without asking again;
keep their remaining acceptance requirements and other unrelated decisions open.

| Child | Required input | Result after the dependency resolves |
| --- | --- | --- |
| FREIGHT-TERMINAL-WORKFLOW | DECIDED: physical terminals select existing job/show manifests and receipt; transfer remains automatic on landing. | Interface DONE on509703300/checkpoint5097033; full walk/reload/same-ship requirements retained. |
| [AUDIO-NAVIGATOR-CLIENT-REJECTION](docs/COMPLETION_SCOPE.md#client-navigator-rejection-response--bounded-definition-next) | DECIDED: feedback on every fresh current authenticated rejection, including unavailable consumer. | DONEc2c72a223/checkpointc2c72a2: actual requester-correlated response/cue/caption, silent stale/replayed/foreign inputs/results; actual two-peer continuation accepted. Listening/native/full travel stay open. |
| [HAULER-CARGO-MANIFEST](docs/ROADMAP_BACKLOG.md#hauler-supply-integration-boundaries) | DECIDED: share the existing stock between Jovian and Hauler. | Shared custody DONE6bcbea302/checkpoint6bcbea3; conserved ownership/generation floors and no recreated cargo/duplicate receipts. Full ordinary Hauler delivery and cold physical inventory remain required. |
| [TRAVEL-LIMIT Beacon outbound](docs/ROADMAP_BACKLOG.md#beacon-outbound-travel-envelope--approved60second-maximum) | DECIDED: maximum60s unpaused elapsed from engine-start input at occupied Torrent berth to controlled first Beacon. | DONE252ed6bfc:10.510574s outbound and full original111.908s journey; checkpointc2c72a2 reused. Return/other routes remain separate. |
| BOMBER-REARM-POLICY | DECIDED: refill ammunition when the pilot retakes the seat. | Entitlement DONE4a0d82bff actual4→0/refusal/physicalretake4/freshshot3; post-retake presentation repaired255f8df2b/checkpoint255f8df. Broader craft/roles/recovery remain open. |

Other scope, evidence, hardware and authorization dependencies remain in the
[backlog](docs/ROADMAP_BACKLOG.md#external-dependencies-outside-the-ready-queue).
[Parked failures](#parked-failures-and-dependent-work) require their recorded
reopening conditions; they are not the next executable queue.

## Turning a broad point into one task

Use the existing [child inventory](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes).
Do not create another tracker. A task is executable only when it has:

1. One player/content/build result, its existing child and original parent.
2. Satisfied prerequisites, exact production files and one responsible implementer.
3. A decisive action/check, expected result, exact command and fixed duration.
4. Implementation and check estimates; prefer 30–60min implementation and split
   before 90min into independently useful capabilities.
5. A stop condition and closure: actual result/time, source or package scope,
   commit/push, owned cleanup and one next action.

Label capability, qualification and planning separately. A capability task changes
the game/content/build pipeline; qualification proves an existing result. Do not
close a full craft, world, multiplayer parent or phase using a narrow source check.
No more than three executable cards; prepare dependent work without scheduling it.

A new failure ends the attempt. Any correction needs a separate selection;
failed work plus one attempted repair requires cumulative priority review.
Parked work additionally needs a concrete fact/change addressing its retained
failure. Renaming a card, shrinking acceptance, increasing a cap or selecting an
adjacent probe does not reset that boundary. A pass ends verification unless a
relevant change or unresolved concern justifies another run.

Completing one helm action never schedules the next action, a new fixture or a
handback retry. Before more qualification, choose the larger player journey it
advances and state its remaining blocker. Prefer an independently useful production
capability when one is ready; if none is ready, name its actual missing dependency.
Do not fill the implementation queue with tests or invent unapproved behavior.

## Accepted work — source limits retained

The backlog preserves accepted child scopes and remaining gates. The existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md) preserves sources, actual
results, timings and cleanup. Recent palette, controls, station service, recovery,
Arrow and helm work remains accepted only within those recorded boundaries.
Caller-only qualification needs no identical playable rebuild. Checkpoint4196ad0
is the latest accepted playable result; full craft combat/damage/recovery,
cross-craft/Main, hardware/native and final release gates remain open.

## Parked failures and dependent work

Jovian reboard's earlier failures remain preserved; the Interact replay repair
49bc7b736 and full pilot/co-pilot physical reuse through repeat departure
bc7f9f9c4 are accepted above. They are completed work, not a parked repair queue.
Other craft/roles and distinct second landing remain separate open requirements.

These are unfinished outcomes, not candidates for an unchanged retry. Exact
contracts and cumulative attempt records remain in the retained history.

| Outcome | Last actual result | Condition before more work |
| --- | --- | --- |
| PLAY-DEFENSE ordinary route /13 | Deploy-arm/launch-start9af48515a delivered. Earlier2/4 timeout retained. Latest first-point arrival succeeds; two Alpha hits/no kills, stops on valid-miss representation at elapsed28.15. World/core blockers and short clear windows remain; no basis defect. | OPEN. Miss sentinel corrected/Python-only, candidate archived; no new trial justified by that fix alone. Need a supported tracking/visibility/input-timing correction before selection; preserve full34s/four kills/payment/home/reset/nextDeploy/UIexit and300/360s. |
| Jovian postdock reuse /16,20,26 | DONEbc7f9f9c4: complete ordinary passenger exit/reboard, pilot exit/reclaim and repeat departure/braked stop, full original journey and three actual OS0. Reboard runtime repair49bc7b736; Jovian-specific paired checkpoint49bc7b7, included in current3767687. | Source integrated/pushed and owned scratch removed. Existing working refs already deleted; other supported craft/roles, distinct second landing and full parent gates remain open. |
| Habitat common-entry view /9,12 | [Source8a6339b91](docs/history/ROADMAP_DELIVERIES.md#habitat-arrival-view--readback-timed-out-before-image): import passes; full-Main player-height readback times out180.842s before PNG or view metadata. Cumulative201.494s; no observed defect/no-finding. | PARKED. Concrete supported capture-boundary change before selection; no renderer/room substitute, cap increase or unchanged retry. Actual eye stage was not proved reached; accepted Habitat runtime scopes remain. |
| Courier clear /11 | DONE4196ad0: complete original first-clear/home journey PASS55.973s/original300. Controlled actual nonlethal85→51→17 feedback/readiness preparation keeps defender alive; actual Courier player kill/gen1/seq15 and CLEARED before1400m, then defender defeated/strict home dock/OFFLINE/physical exit. Original failures and first41.436s overheat-related preparation failure retained. | Source merged/pushed; fresh checkpoint/three strict startups/1525-entry audit/review GO; owned cleanup done. Original20 candidate closed. Other Courier escape/two withdrawals/recovery/repeats/reload/native remain OPEN. No normal UI quit/gameOS0 or separate supported-walk claim. |
| Matching RPC-cache templates /25,32 | [Linux built; Windows cold/incremental compilation timed out](docs/history/ROADMAP_DELIVERIES.md#matching-rpc-cache-templates--stopped-at-windows-compilation-budget). No accepted matching pair; callback repair is unverified. Browser diagnostic/prepared acceptance source archived WITHHELD; working refs deleted. | PARKED; no further compilation or dependent browser attempt selected. Existing recipe/JSON fixture remain delivered; empty callable metadata and similar Window errors establish no cause. |
| BROWSER-ORDINARY /25 | Candidatee944f52:89Python/privacy/35join/package checks pass, actual routeFAIL40.554s at NetworkSession tree_exited disconnect error; cleanup fixture command rejected. | PARKED/unmerged/withheld; diagnostic and prepared acceptance refs deleted after source archival. Subsequent passive capture identifies retained native RPC-cache callback; it does not qualify the route. Full continuation NOT_RUN. Original raw data/eight builds preserved; scratch cleaned. |
| AFT-CONSOLE-VIEW /9,12 | Standalone actual-module Xvfb/Forward+/llvmpipe capture FAIL120.485s after camera setup; no image or visual finding. | PARKED; source/root cause unproven. No cap increase, alternate backend/view or retry selected. Owned scratch cleaned; raw results retained. |
| WALK-OBSERVATION /7,9 | Original full route fails rootWindow disconnect after Exit. Privatebae551d58 later passes54-goal travel/view/home/Exit, but lacks original visible TooltipPanel; repair INCONCLUSIVE. All five unique commits/seven files archived under pushed archive/withheld/exit-tooltip-order-20261020; working refs deleted, runtime unmerged. | OPEN. Actual-Main real tooltip/root bindings/hover/native pointer now observed after caller stretch correction; ordinary HUD close exits0 with no original errors. Runtime repair remains unqualified: identify the actual popup/connection-removal event in the original failing journey before selecting a repair or retry. Full integrated travel/view/home acceptance retained. |
| PERIMETER-LIVE /11 | Runtime/admission shipped fdae1cb: all selected focused/production checks, paired exports, three strict startups and package audit PASS. Existing branch merged/pushed/deleted and owned scratch cleaned. | Scoped integration DONE; full ordinary weapons/home/recovery/repeats/network/native remains OPEN. Prior 363.897s/three failures retained; total stages 742.767s. |
| PLAY-BEACON-HOME /13 | DONE bc48b2a: complete original ordinary trip passes112.031s under300s with all four beacons/one saved reward, actual safe header crossing/combat/strict home dock/OFFLINE/E/supported0.969m walk. Restored original caller plus narrow mouse precision correction; prior UI37.713s failure and actual307.042s alignment timeout retained. | Accepted source merged/pushed, fresh checkpoint and strict startups/package audit PASS; cleanup complete. Original UI cause remains unresolved, no diagnostics waived. Original generic process cleanup does not establish normal UI quit/gameOS0; cold restart, repeats and native/human gates stay open. |
| HALYARD-GUNNER-DAMAGE /11,16 | DONEc28f7ffa3: original49assertions pass52.341s/exit0. Admitted gunner remapped FIRE produces exactly one52damage commit through actual GameFlow/authority/resolver/adapter, then original lifecycle checks. | Accepted source merged/pushed; earlier headless failures preserved and explained by missing mousecapture. Declared input-only mode now exercised on isolatedXvfb. Fixtures disclosed; broader OS-input/network/native/full-combat gates remain. Owned scratch removed; current3767687 runtime unchanged. |
| WALK-SALVAGE-ACCESS / 7,9 | DONE9749f742c: full29outbound/29reverse goals plus retained hub spawn,64assertions/103.697s/OS0/cleanlogs, same supported on-foot Player and unchanged inspection state. | Accepted source merged/pushed; original240-loop/.20arrival/4-settle/300s limits retained. Added two existing-floor clearance points around roof columns, no destination removed. INSPECT5189436f1 and fresh-process REVISITf7abac379 are now accepted separately above; original access-only result stays scoped. Owned scratch removed; no runtime change or duplicate rebuild. |
| KIT-RELOAD /13,31 | Mainready/restoreaccepted27.762s/pausedfalse; firstnormalphysics/process pair incomplete by30s. Source audit finds standardSceneTree awaits, no callerpause defect or concrete currentstartuprepair. | PARKED/open; trace lacksafterphysics/beforeprocess boundary. Original30s/includespreload/full60ticks preserved; no retry/probe/clockmove/capchange selected. No corrupt/duplicatecargo observed. |
| FIRE-RESTART /8,29,31 | DONE3a45c4d79: visibleFire/rawF13/real-file Save; distinctsame-filereader row/InputMap/production sampler F13press/release/formerF+leftmouseoff/gamepads+sentinel allPASS. Writer31.188s/reader31.012s/OS0/cleanlogs. | Original300s/process/visibility/predicates retained; actualengine queue flushed before read, no input/provider/flag override. Reviewed/merged/pushed and owned scratch cleaned. Originalfailedsource/costs preserved; physicaldevice/fullSettings/native/final gates separate. |
| HULK-REVISIT /13,31 | Original departure failure and repair retain300s limit. Raw audit confirms47.393m ongoing supported movement after reload/dock/exit, rather than an established interior stall; deadline precedes freshbreaker. | PARKED/open; no supported runtime/caller change or qualifying currentrepair found. Missing stage walltiming tolocalize cost; no retry/probe/capchange selected. Fullphysical revisit/once-onlycell/reward retained. |
| SHARED-RIME-BASELINE /3,27 | Original parse failure and typed caller repair retained; repair reaches approach but fails original120s physical landing gate. Survey/home not accepted. Source archived WITHHELD; working refs deleted. | OPEN/PARKED; landing cause unestablished. Preserve full two-crew outbound/survey/reward/save/home and original limits; no automatic rerun. |
| HALYARD-AUTHORITY-STOP /16,26 | DONE082da79c9: complete BOARD/MOVING prefix, actual one host shutdown with both original occupants aboard, real disconnect events/old-binding retirement, pilot throttle, passenger solo walk0.616m and both real pause/Resume;142.082s, three actual OS0. | Current Linux-source scope only. Full baseline/endurance/native/reconnect/migration remain open; [accepted original case](docs/history/ROADMAP_DELIVERIES.md#halyard-real-authority-stop--accepted--2026-10-20). |

VIP, Ember native close smoke, Rime arrival, HULK revisit, Fire restart, Sandbox,
Convoy/Patrol/Q4/Q5 and software-renderer capture stalls retain their existing
failure budgets and reopen conditions in the backlog/history. Settings originals,
Aurora original arrival bundle, final capacity, hardware/devices and signing retain
specific external waits. Do not repeat already-asked questions or infer approval.
Dedicated server/two-client baseline remains authorized independently of capacity.

## Validation and final release

Follow [AGENTS.md](AGENTS.md): every automated Godot invocation uses Dummy audio;
headless/private display and explicit x11 under Xvfb; independent abort and owned
input/process cleanup. Never enable or dispatch GitHub Actions. Respect the
existing native Windows execution hold. Scratch belongs in `/srv/mudds-work/`;
protect unrelated and unique work when cleaning.

Meaningful accepted runtime/graphics changes require clean paired Windows/Linux
checkpoints in repository `builds/`, focused checks and strict silent startup
exit0 plus `STARTUP_MENU_READY_OK`. Caller-only qualification does not require
an identical rebuild. Package notes state actual validation and limits.

Current full matrix NOT_RUN; last unfiltered f85957f failed11/1,045 suites.
Native GPU/device/audio/human gates remain unperformed where recorded; VM,
software-renderer or source checks cannot replace them. Project completion requires
every original promise accepted or explicitly owner-deferred beside that promise,
all applicable final-candidate gates passed, and distributed bytes matching the
qualified candidate. No broad parent or phase closes in this reorganization.
