# Development roadmap

**Playable development alpha; a completion date is not yet defensible.**
All **36 original parent outcomes** and **ten phase gates** remain open.
Nine of the eventual 17 craft exist; eight still need supported specifications
and implementation. Partial acceptance is retained in the backlog; it is not
whole-feature completion.

Latest playable checkpoint: **4196ad0**. The complete Courier intercept now
passes: kill the first runner before escape, finish the defender, return home,
dock, shut down and physically exit. Existing weapon/health/AI/encounter limits
are retained. Complete Beacon and Cinder outcomes remain included.
[Windows ZIP](builds/windows/MuddsShipyards-4196ad0-checkpoint.zip),
[Windows notes](builds/windows/MuddsShipyards-4196ad0-notes.txt),
[Linux notes](builds/linux/MuddsShipyards-4196ad0-notes.txt).

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

**AUDIO-NAVIGATOR-CLIENT-REJECTION completed onc2c72a223; checkpointc2c72a2.**
Fresh authenticated current navigator refusals now reach only their requester,
including unavailable consumer. Distinct equal refusals each produce one existing
UI alert request/caption; stale/replayed/foreign responses stay silent. Actual
accepted/clear and genuine host-local feedback remain independent. Six focused
suites and the complete two-peer profile PASS252 checks/119.770s with zero failures,
including two missing-callback and two detached-bridge real FIRE presses, replay/
foreign delivery, original reseat/migration/disconnect. Paired packages, three
strict startups and actual payload/archive audit pass. Windows EXE/ZIP/notes are
in builds/. [Actual delivery and scope](docs/history/ROADMAP_DELIVERIES.md#navigator-requester-rejection-feedback-completed--2026-10-21).

Freight interface509703300/checkpoint5097033 and shared Hauler custody6bcbea302/
checkpoint6bcbea3 remain completed. All five owner decisions remain accepted;
Beacon60s and Bomber seat-retake refill qualification remain queued. Full ordinary
Hauler delivery/cold inventory and WALK-FREIGHT/KIT-RELOAD remain open/parked.
Owned scratch is archived/removed. No new working branch/worktree; accepted
history integrated/pushed in main, retained unqualified contexts preserved.
Select one bounded next delivery before further implementation.

**Prior Rime diagnosis closed, journey remains open.**
The selected original Rime run failed its unchanged peer landing gate after
1624.422s. It yielded105 usable sampled script frames, but no final accumulated
total: the peer timeout stopped the host before profiler flush. The controller
leg field was also unavailable. These samples locate costs but establish no
production repair or completed journey; there is no automatic retry. Temporary
source is bundled, all owned processes are absent, and64 scratch entries were
archived/verified/removed. Latest playable checkpoint is nowc2c72a2 (navigator requester refusals).

The earlier 45 remote heads included `main`, duplicate attempts, diagnostics and
already-integrated work; they were not 45 independent unfinished features.
There is now only `main` locally and remotely. Of the retained 20-candidate
inventory, eleven are accepted/superseded and nine remain unqualified across
these six problems. Archival and branch deletion do not complete these outcomes.

| Existing problem (candidate count) | What remains before completion |
| --- | --- |
| Browser/network timeout (2) | Obtain matching Windows/Linux templates and pass the original complete timeout/retry journey. Windows compilation exhausted its previous budgets; callback cause/repair remains unverified. |
| UI transition, Mining and Observation (3) | Identify the original popup/connection-removal failure, prove a repair against that event, and finish the full Mining and Observation journeys. Later clean Beacon/tooltip runs did not establish a UI fix. |
| Defense (1) | Finish all four kills, payment, home, Reset and next Deploy. The last first kill took about30s of the34s encounter, with10.5s mandatory wave delays remaining; a feasible ordinary plan or an explicit clock-owner decision is needed. |
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

**PLAY-DEFENSE remains OPEN/PARKED — candidate `0b11486e0` withheld.**
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
Owner clock-start choice is now pending: preserve board-start timing, or arm at
the board and begin the34s encounter on launch. Current board-start rule stays
in force until answered. Read-only timing review found no proven clear-fire plan;
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
| [TRAVEL-LIMIT Beacon outbound](docs/ROADMAP_BACKLOG.md#beacon-outbound-travel-envelope--proposal-awaiting-decision) | DECIDED: maximum60s unpaused elapsed from engine-start input at occupied Torrent berth to controlled first Beacon. | Implement/qualify existing exact clock/route with original whole-sortie limits; return/other routes remain separate. |
| BOMBER-REARM-POLICY | DECIDED: refill ammunition when the pilot retakes the seat. | Preserve this same-hull seat re-entry entitlement and qualify actual reboarding; broader role/payload/recovery cases remain open. |

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
| PLAY-DEFENSE ordinary route /13 | Autonomous enemy escape fixed and checkpointed3767687. Prior full caller0b11486e0 reached ordinary boarding/departure and one actual player kill, then aborted near34s; payment/home/reset/UIexit not reached. | Full journey OPEN. Prior first kill about30s leaves less than remaining10.5s authored delays; establish a feasible ordinary combat plan before rerun. No timer/contract change selected. Failed source/results retained; owned scratch cleaned. |
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
