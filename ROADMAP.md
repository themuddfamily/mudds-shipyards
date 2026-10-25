# Development roadmap

**Playable alpha; full original scope remains unfinished.** Latest playable build:
[0d77125 Windows checkpoint](builds/windows/MuddsShipyards-0d77125-checkpoint.zip)
([changes and validation](builds/windows/MuddsShipyards-0d77125-notes.txt)).
Nine of the promised 17 craft exist. All 36 original parent outcomes and ten phase
exit gates remain open; completed child results are retained, not counted as whole
features. There is no evidence-backed project percentage or completion date.

## What finishing means

The full original scope is retained. A smaller release would require an explicit
scope decision; this plan does not make one.

| Delivery | Concrete finish line | Canonical goals |
| --- | --- | --- |
| Complete game loop and station | Final-package Guided 3/3, original all-nine/54-waypoint Sandbox/recovery 1/1 and original Settings/re-entry 1/1; all nine named station branches physically usable, required interactions/revisit complete | [Core and station proof](docs/ROADMAP_BACKLOG.md#proof-core) |
| All 17 craft | All twelve originals plus five modern additions exist; each passes its specified boarding, flight, actual functions, damage/recovery, strict home landing/exit/reuse, cross-craft and Main re-entry checks | [Craft proof and missing specifications](docs/ROADMAP_BACKLOG.md#proof-craft) |
| Combat and twelve activities | Real player weapons achieve the named encounter results; every activity completes its actual objective, durable result and usable home return; all twelve required ten-run repeats and Hulk revisit pass | [Combat](docs/ROADMAP_BACKLOG.md#proof-combat), [activity proof](docs/ROADMAP_BACKLOG.md#proof-activity) |
| Three worlds and shared travel | Complete Ember, Aurora and Rime canonical physical round trips, required survey/reward/save/abandonment outcomes and all 21 explicitly named shared-world cases | [World proof](docs/ROADMAP_BACKLOG.md#proof-world) |
| Supported multiplayer | Complete server/two-client baseline and remaining role/helm/actor/browser/reconnect cases; original 30-minute session with required adverse networking; chosen supported capacity qualified | [Multiplayer proof](docs/ROADMAP_BACKLOG.md#proof-network) |
| Durable recovery | Named real-file interruptions restart in the settled supported state, preserve accepted progress/debt, pay once and permit ordinary continuation; migration/corrupt/unsupported data handled correctly | [Recovery proof](docs/ROADMAP_BACKLOG.md#proof-recovery) |
| Presentation and hardware quality | Existing 13 capture sets/143 PNGs reviewed; required UI/device/comfort/audio cases pass; representative actual hardware meets declared performance budgets | [Quality proof](docs/ROADMAP_BACKLOG.md#proof-quality) |
| Ship the exact candidate | Unfiltered local matrix, required ordinary routes, packages/install transactions, rights, trusted signing and authorized downloadable-byte identity pass on one integrated candidate | [Release proof](docs/ROADMAP_BACKLOG.md#proof-release) |

Parents 3/27 share the same 21 world cases; 6/35 share one final matrix; 11/21
share the damage work. Breach/Torpedo combat and activity journeys are reused,
not counted as duplicate deliveries. [All 36 promises and ten gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes).

## Execution now

**Selected continuation: HAULER-CARGO-DELIVERY — observe genuine ramp support.**
Original case/budget retained:30min prior closeout; original start04:00:25UTC,
hard90min including this causal review/implementation/checks/closure. Exact five
candidate files70de2ea83 restored for one continuation. Root/independent source
and raw geometry prove the failed home walk is on BoardingRampSupport: capsule
ramp gap1.660mm within2mm margin, slope30.54° below50° floor limit. The WORLD-only
ray misses this SHIP-layer floor; the actual ramp hit is inside its unchanged reach.

One implementer owns passive observer and existing Hauler physics tests. Query
Hauler's actual physical WORLD/SHIP mask and collision exceptions, exclude Player,
require current PhysicsBody/floor-compatible normal; preserve default Jovian query.
Keep actual grounding, control, motion continuity, strict home lease/contract,
≥1m supported walk and normal UI OS0. No geometry/pose/provider/policy mutation,
longer ray, new validator/schema/framework or replacement route.

Proof: focused real-ramp physics case plus grounded/normal/self/mask refusals,
existing Python/import/parser/privacy, fresh clean Linux export/strict startup/
PCK inventory and ONE unchanged full ordinary package journey underCAP300/
outer360/cargo120. Estimate10implementation+15checks/route+10closure, original
90min cumulative hard stop. First unexpected failure stops without another
automatic correction. Accepted source only may merge/push; preserve unaccepted
work, release/reap owned inputs/processes and consolidate scratch at closure.
Normal gameplay unchanged means public0d77125 stays current. All prior failures
remain below and in the original archive; no whole-goal completion assumed.

Focused fixture stopped on five errors: PROCESS_MODE_DISABLED removed the test
Player/ramp from physics. The initial log-tail assessment was withdrawn. One
root/independent cumulative review permits a fixture-only correction: keep bodies
active, disable controller callbacks and perform the manual move in a physics
frame. All assertions remain; no export/whole route ran. Next fixture failure
parks without another correction; original case clock and full result unchanged.

**PARKED: HAULER-CARGO-DELIVERY — home walk support check failed.**
Unaccepted candidatesc0c5ff2b7/70de2ea83 complete ordinary station walking,
Hauler boarding/departure, actual Cinder load/gate/redock, ten-point terminal walk,
one conserved crate/payment, duplicate refusal, reverse walk and reboard.
First trial times out at home capture because88.255755° tilt exceeds75°.
One independently reviewed controller correction uses normal brake/hover;
the corrected run docks exactly at home, OFFLINE, hull220 and physical exit.

The corrected run then FAILS at home_walk frame9169: groundedtrue but supportedfalse/
empty support collider after0.416854m, before required≥1m/UI exit0. Driver184.343s,
diagnostics0; all five actual save captures preserve the paid result/protected data.
No further correction or retry selected. Both source/raw/package trials are archived,
unaccepted source remains unmerged, and owned test files/processes are cleaned.
Reopen only with a demonstrated support/route cause and bounded correction retaining
the full journey, CAP300/outer360/cargo120 and cumulative clock.
[Exact failures, partial results and cleanup](docs/history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-parked-20261025).
Existing shared stock/access/manifest behavior and playable0d77125 remain current.
No new gameplay completion is claimed; no next implementation is selected.

**PARKED: PLAY-PATROL[platform_sweep] — final normal quit did not finish.**
Candidate `ff3fbab08` passed focused checks and reached all five real platform
holds, payment, strict home, shutdown, physical exit and supported walking.
The original300s deadline expired at `quit_wait`; actual normal UI process exit0
and orderly-close save proof are missing. The complete journey therefore FAILS.
Driver304.890s includes cleanup; no longer cap or retry is selected. Unaccepted
source and raw results are preserved outside the repository; accepted relay code
and playable checkpoint0d77125 remain current.
[Failure and reopening condition](docs/history/ROADMAP_DELIVERIES.md#patrol-platform-first-play-parked-20261025).

**Delivered: fixed task boundaries and explicit acceptance blockers.**
Every named goal must have a literal pass condition or an exact missing input and
owner. Required scenario membership is fixed before execution; one passing case
cannot close a family. The remaining comfort/UI coverage, capacity-journey and
travel-leg definition gaps are explicit blockers in the existing inventory.
The documentation review is complete; it delivers no gameplay completion and
selects no new run.

**Delivered: PLAY-PATROL[relay_sweep] — full ordinary relay branch.**
Sourcec3d369e0f passes the complete packaged journey in227.070s under original
CAP300: genuine Guided, actual pause-board Patrol/Relay selection, supported
reboard clearance/same-Torrent departure, safe low-header crossing, five ordered
holds of120 continuous occupied60Hz ticks each, one durable relay payment,
strict Central dock/90neutral OFFLINE ticks/physical exit/supported.969m walk and
normal UI exit0. Five actual-file captures preserve the paid terminal/ledger,
justified tutorial additions and all other protected siblings. Independent
source/raw review GO; runtime diagnostics0.

The first300s attempt remains recorded: its outbound caller path contacted the
range header before checkpoint1. One source/raw-supported correction uses the
existing low-clearance waypoints; no geometry/tuning/timer/phase change. Full
route and cleanup stay on the original90min task clock.
[Exact proof, first failure and cleanup](docs/history/ROADMAP_DELIVERIES.md#patrol-relay-first-play-accepted-20261025).

This closes the relay instance only. Platform sweep remains required and
parked after its failed full journey, so PLAY-PATROL stays open. Repeat/cold-recovery, parked
thirty-Main Patrol suite, UI-BOARD-FOCUS, native/device and final-candidate gates
remain open. No new implementation is selected by this closeout. Normal gameplay
is unchanged; playable checkpoint0d77125 remains current.

**Delivered: PLAY-RACE — complete ordinary packaged race and home return.**
Source7997b2b37 passes the full original journey in276.690s underCAP300:
normal menu/Guided/physical exit/actual reboard clearance/same-Torrent departure,
production2s countdown/five ordered32m gates in16.116667s, one durable payment,
safe approach/strict Central dock/90 neutral OFFLINE ticks/physical exit,
supported0.969m walk over25frames and normal UI exit0. No runtime diagnostics;
root and independent source/raw review GO.

The existing release runner now offers `--route race-home` for an exact exported
Linux binary. Tutorial preservation checks only the two
approach-driven IDs justified by actual accepted samples/resident markers within
250m; all other save data stays protected. Five actual-file captures retain the
once-only payment/terminal through orderly close. Earlier failed stages remain
recorded on the original90min clock; no deadline or gameplay rule was relaxed.
[Full proof, earlier failures and cleanup](docs/history/ROADMAP_DELIVERIES.md#race-first-play-accepted-20261025).

Normal gameplay is unchanged; playable checkpoint0d77125 remains current.
This accepts the named Linux/Xvfb OS-input first-play route only. Race ten-run
repeat/recovery, physical devices/native GPU and full activity/final gates stay
open. No new implementation is selected by this closeout.

**Previously closed: BROWSER-JOIN — actual LAN join and usable solo return.**
Source `80abab3b1`: the existing ordinary two-Main route now checks both players
walking while connected and again after normal Disconnect/Refresh/Back/Resume.
The full route passed294 assertions in86.310s, actual peer exits0, no diagnostics;
each of four supported walks covered1.002774m with twelve fresh neutral ticks and
zero drift. This is source input automation with real ENet under isolated Xvfb,
not package/device/native GPU/endurance or whole multiplayer acceptance.
[Full result, first failure and cleanup](docs/history/ROADMAP_DELIVERIES.md#browser-join-supported-walking-20261025).

**Roadmap task breakdown is recorded in the existing canonical inventory.**
All337 IDs retain their Done means, dependencies and original proof limits;
all36 parent outcomes and ten phase gates remain. Each next assignment must use
the [execution card](#turning-a-goal-into-one-assignment) below. Family containers
are not runnable jobs; missing values/decisions keep their rows blocked. Decision
approval, a single audio case and a source inventory cannot close their respective
implementation, whole-roster or visual acceptance goals. This documentation work
adds no gameplay completion or new implementation assignment.

**Prepared: concrete modern proposals for all eight missing craft — owner choices pending.**

| Craft | Fixed proposed function | Bounded draft cards |
| --- | --- | --- |
| [Titan](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md) | Pilot, two physical passengers, four conserved inert parcels, defensive cannon | 13 |
| [Vortex](docs/design/VORTEX_IMPLEMENTATION_PROPOSAL.md) | Pilot, four physical passengers, defensive cannon | 14 |
| [Paradox](docs/design/PARADOX_IMPLEMENTATION_PROPOSAL.md) | Pilot cannon, independent physical gunner, one passenger | 16 |
| [Katana](docs/design/KATANA_IMPLEMENTATION_PROPOSAL.md) | Single-pilot braking fighter | 13 |
| [Predator](docs/design/PREDATOR_IMPLEMENTATION_PROPOSAL.md) | Unarmed pilot/guard/voluntary-detainee transport with a real cell | 15 |
| [Dynamic](docs/design/DYNAMIC_IMPLEMENTATION_PROPOSAL.md) | Compact single-pilot short-range gunship | 13 |
| [Utopia](docs/design/UTOPIA_IMPLEMENTATION_PROPOSAL.md) | Conserved supply dropship with finite live hostile approach and two chairs | 18 |
| [Salyut](docs/design/SALYUT_IMPLEMENTATION_PROPOSAL.md) | Unarmed pilot/two-passenger transport | 15 |

Each fixes numeric hull/access/berth, all16 tuning fields, actual functions and
ownership, component/service/reset/save/reuse, production files/visible results/
proof/stops, early checkpoint and full craft acceptance. Titan's older missing
geometry/tuning and unsupported existing-cargo assumption are corrected in place;
Vortex's proposed drag1.8→1.85 resolves its13-axis Bomber overlap. Root source
comparison now finds all17 numeric profiles/136 pairs meet≥14 differences and
existing extrema/non-dominance; this is arithmetic, **not runtime qualification**.

All eight are explicitly UNAPPROVED modern interpretations, not authenticated
historical models. The [decision register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
assigns interpretation/design choices to the owner. Approve a named baseline,
revise exact fields, or retain historical freeze; do not infer an answer from
continuation or repeat completed proposal preparation. This delivers no craft,
approved SPEC/build split, capacity or phase. Actual fleet remains9/17; all
original historical/rights/device/final gates remain. No engine/runtime/export/
CI work was performed. [Preparation and limits](docs/history/ROADMAP_DELIVERIES.md#remaining-craft-proposals-and-titan-completion--2026-10-25).

Recent shipped results and failed attempts are recorded in the existing
[delivery history](docs/history/ROADMAP_DELIVERIES.md), with their source/build,
actual proof and remaining limits. Completed child checks stay accepted for their
recorded scope; they are not automatically rerun or counted as finished parents.

| Parked goal | Required evidence before selecting another attempt |
| --- | --- |
| WALK-AFT | Source/raw-supported collision-clear route and bounded arrival strategy; retain the full door/board/stairs/Zenith/home journey and original limits. [Failed trial](docs/history/ROADMAP_DELIVERIES.md#aft-station-journey--first-package-trial-not-accepted--2026-10-25). |
| PLAY-TORPEDO | Demonstrated gameplay/control cause for the failed boat engagement and bounded correction; retain full Heavy→Torpedo→usable Paired Wing journey. [Three unaccepted trials](docs/history/ROADMAP_DELIVERIES.md#torpedo-second-boarding-readiness--whole-journey-not-accepted--2026-10-25). |
| PLAY-DEFENSE | Demonstrated cause and bounded correction for two remaining hostiles at the unchanged34s limit; require four actual kills/payment/home/Reset/next Deploy. [Failed trial](docs/history/ROADMAP_DELIVERIES.md#defense-consumed-fire-qualification--not-accepted--2026-10-24). |
| UI-BOARD-FOCUS | Actual offending popup/removal identity and causal evidence; existing raw does not establish it. Mining/Threading remain dependent. |

These are reopening conditions, not active assignments. The canonical inventory
retains all other parked outcomes and their original proof limits. No unchanged
retry or longer timer is selected by this summary.

<a id="next-three-production-deliveries"></a>
## Work order

One implementation at a time. Select the earliest **ready product outcome** below;
if blocked, name the missing input and use the next ready one. Do not select an
unrelated test just because its harness is convenient.

1. **Close finite scope decisions.** Eight missing craft specifications, Bomber
   extra roles, final guest/host capacity and desktop list; four active-recovery
   policies; legitimate cargo replenishment/turnover. Each has named answer fields
   and a completion artifact in the [decision register](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources).
2. **Complete playable outcomes.** Finish the open core/station/craft and first-play
   activity/world goals. A failure selects its demonstrated gameplay/build/driver
   repair; retain the complete original journey as the finish line. Prioritize
   full combat/activity completion and missing craft over extra Halyard edge cases.
3. **Close lifecycle and durability.** Remaining repeats, cargo cold reload/Hulk
   revisit, recovery, shared-world and multiplayer cases follow their real baseline
   dependencies. Reuse accepted results; fix actual defects, not evidence formats.
4. **Qualify and ship the stable integrated candidate.** Device/audio/performance,
   final captures, full matrix, install/rights/sign/distribution use the exact final
   bytes. Relevant runtime changes invalidate only affected results.

This order is not a claim that unknown specifications are already estimated.
[Concrete blocked inputs](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources)
are resolved once; they do not authorize an endless research or definition loop.

## Turning a goal into one assignment

Every selected task must be small enough to finish or fail in one bounded
assignment. A broad delivery heading is never a runnable task.

Before work starts, copy its existing ID, **Done means**, dependencies and protected
scope into a short execution card. Add exact production files/owner, action or
command, expected visible result, implementation/check estimate and time budget.
No card may say only “finish”, “polish”, “improve” or “support” a family.

Freeze the complete required case list before the first case runs. Missing
criteria or membership make the goal GATED, with the exact input and its owner
recorded in the existing row. New cases require an identified uncovered original
requirement. Report the first failed predicate and cumulative time; never extend
the finish line or reset the budget after seeing a result.

Use this compact card for every selected task; fill each field before editing:

| Field | Required content |
| --- | --- |
| Goal and boundary | One existing goal ID plus this bounded capability; list what remains in its parent. |
| Starting state | Exact source/package, normal player/session state and satisfied dependencies. |
| Visible result | What the player can do after this change, or the exact finite answer for a decision task. |
| Pass condition | Literal action → expected state/value for every required endpoint; fixed numeric limits/tolerances/counts and exact existing check/ordinary route. No unresolved “works”, “usable” or “specified” wording. |
| Proof and blockers | Exact command/route, source/package, participants/device, expected output/file/visible result; list each missing input and who supplies it. Missing inputs keep the assignment GATED/WAITING. |
| Ownership and budget | Exact production files, implementer, estimate and hard stop; split implementation before90min, include prior attempts in the same cumulative clock, retain the original full acceptance gate. |
| Closure | PASS with proof, FAIL with first unmet predicate, GATED/WAITING with exact input, or PARKED with reopening condition; actual cumulative time, remaining work, pushed source/build where required and process/worktree/branch cleanup. |

Do not silently expand a failed card into a new project. At the hard stop,
record the failed predicate or missing input and leave the parent open. A further
attempt needs a concrete cause, bounded correction and cumulative priority review;
renaming a task or creating a new branch never resets its budget. Before selecting
a different task, close or explicitly park the current card with its unique work
accounted for. Definitions already finished are reused, not recreated.
Each cumulative review must record total elapsed cost and choose either
**park/switch** or **one bounded continuation** with new causal evidence and an
explicit next stop. A review alone never authorizes an indefinite retry loop.

- Codex owns implementation/checks/integration; the user owns product decisions,
  external credentials and access. Each selected risky lifecycle change gets one
  independent reviewer. The exact file owner is set before editing.
- Decision/handoff preparation: normally 15–30 minutes, ending in the named answer
  or exact missing input. Do not repeat a completed definition. Missing original
  craft build estimates wait for their specifications; do not invent finish dates.
- Implementation: name one runtime/content/build result and an estimate before
  editing. Split before 90 minutes if it cannot yield a reviewable capability;
  preserve the original parent result and cumulative clock across attempts.
- Qualification: use the existing full route and original duration. The first
  unexpected failure stops execution. One proposed correction needs causal proof;
  failed work plus one attempted repair requires cumulative priority review.
- Close with actual result, relevant evidence, remaining limits, merged/pushed
  source, required playable checkpoint, owned-process/scratch cleanup and deletion
  of contained task branches. Failed/unaccepted source is preserved, not merged
  merely to delete it.

A parent closes only when **all** its required named instances pass. Definition,
assertion count, validator files and number of commits are not gameplay progress.

## Accepted work — source limits retained

Recent completed cases include occupied-chair requester feedback (`bcd268c75`),
chair contention/transfer (`99c9fc1af`) and airborne late join/normal docking/crew
boarding (`437fe903d`). Their exact scopes and earlier failures are in
[delivery history](docs/history/ROADMAP_DELIVERIES.md). They do not close the full
multiplayer baseline or any original phase.

## Parked failures and dependent work

The inventory retains each failed route, original cap and specific reopening
condition. No unchanged retries, arbitrary longer caps, substituted short routes
or renamed copies. Observation/VIP, Sandbox, KIT-RELOAD, Hulk revisit, shared Rime,
browser timeout and registered capture blockers remain explicit dependencies.
An old failure does not become a new task merely because another definition ended.

## Validation and final release

Automated Godot uses Dummy audio and headless/private Xvfb with explicit x11.
Audible tests need explicit authorization. GitHub Actions stays disabled.
Native Windows execution and mandatory human review are already owner-excluded;
unperformed facts remain NOT_RUN. Applicable native GPU/device/audio and Linux
requirements remain. No simulated or headless pass supplies those measurements.

The final exit is one accepted candidate with zero P0/P1 defects, reviewed P2
outcomes, the required complete ordinary journeys and unfiltered local matrix,
matching installable artifacts, settled rights/signatures and verified downloaded
bytes. The [ten phase exit contracts](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding; none is silently reduced to this alpha.
