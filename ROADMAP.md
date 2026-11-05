# Development roadmap

**Playable alpha; the full game is unfinished.** Nine of the promised 17 craft
exist. The eight missing craft now have owner-approved modern design baselines;
implementation and full qualification remain outstanding. All 36 original parent outcomes and ten phase exit gates remain open.
There is no evidence-backed completion percentage or finish date.

**A roadmap heading is not a work assignment.** Select only a bounded child
with a filled [task card](#task-card-required-before-starting). Its result must
be observable, its pass condition fixed before work starts, and its dependencies
actually satisfied. Missing details mean blocked work, not permission to explore
indefinitely. A completed specification does not count as a completed feature.

Latest playable checkpoint: **e388031** — [Windows ZIP](builds/windows/MuddsShipyards-e388031-checkpoint.zip)
([notes](builds/windows/MuddsShipyards-e388031-notes.txt)) and
[Linux archive](builds/linux/MuddsShipyards-e388031-linux-x86_64.tar.gz).
This adds ordinary packaged UI qualification of the existing station Reduced Flash
policy; it adds no craft or new graphics policy. The previous Jovian exterior LOD
checkpoint remains included. Native Windows/GPU, rendered visibility and full
COMFORT-FLASH qualification remain open.
Earlier accepted changes, including Hauler/Bomber distant exteriors, remain
included in their recorded scopes.

## Current work and next selection

### Titan construction — standalone children1 and2 DONE

**Hull/pilot foundation834cc50a3**, pushed via dded94bda: original editable
12×18×5m hull, exact approved definition/pilot/eye, convex shell/engine collision,
clear cabin volume and inherited spool/thrust/braking/neutral shutdown. Focused
suite40checks PASS; all committed hashes match guarded inputs. Source and two
inspected software-rendered views retained in the verified standalone task archive.

**Physical access3b9f5617c**, pushed via4621bf485: real folding stern ramp,
vertically sliding hatch with roof slot, matching moving collision, continuous
floor and existing cabin frame. Actual Player walks apron→helm→apron after
neutral shutdown; all224 inbound and222 outbound frames supported and capsule
clear, endpoints within5cm. Actual unsupported exterior-access opening and
open/moving-access departure refuse. Focused suite63checks/30.109s, OS0,
sentinel1/diagnostics0/source-and-cache-stable; independent review GO. Closed/open
renders inspected on isolated llvmpipe/X11/Dummy (OS0, one environment V-Sync
warning). Complete raw/source/captures preserved in verified
`/srv/mudds-work/titan-access-20261105/records.tar.gz`; owned branch/worktree and
scratch removed. Original22:22:07→23:22:07UTC all-in budget retained and met.

These are standalone children of the [approved Titan proposal](docs/design/TITAN_IMPLEMENTATION_PROPOSAL.md).
**9/17 remains unchanged.** Main boarding, reachable berth, production pilot exit,
passengers/cargo/weapon/lifecycle and full craft qualification remain OPEN. Next:
child4 reachable own berth, then child5 minimum live Main composition ahead of
passenger/cargo work. That first playable milestone requires a fresh paired
Windows/Linux checkpoint; native Windows/GPU/human gates remain NOT_RUN.

### Hauler ordinary mass-driver hit, miss and home — PARKED, unaccepted

Final retained source **8c56e9d15**. No source from this attempt is merged and
no checkpoint is published. Actual native **c94f4867f** passes ordinary approach,
boarding, neutral90, departure/clearance and a genuine travelling hit: source1109,
correct weapon/sequence/current target, positive-age advancing flight,26damage
and100→74health. The run then stops after80.504s in `miss_aim`: the caller
asserts terminal+42ticks before waiting. Diagnostics0; every input/process cleaned.
The final Python-only wait-gate fix passes317 tests but has no native run.
Distinct lifetime miss, reverse route, strict home, physical exit, normal Quit
and final nine-predicate package audit remain **NOT_RUN**. Full craft and the
ordinary member remain OPEN. Seven source suites, paired exports/three strict
startups pass on c94; those do not close the missing full journey.

Original20:40:26UTC start and22:10:26UTC all-in deadline retained; one substantive
correction used, with routine observer/float/caller repairs recorded separately.
No time reset, smaller endpoint or automatic successor. Unique source, all raw
runs and exact false-miss/fixed-hit Linux packages are preserved in the verified
`/srv/mudds-work/hauler-weapon-20261105/records.tar.gz` with closeout metadata.
The frozen contract below is retained for audit, not an active assignment.
Next construction selection is Titan proposal child1 (standalone authored hull,
definition and pilot fixture), with a new concrete card required before starting.

**CRAFT-ACCEPT-CINDER-HAULER / travelling pilot weapon member**, reusing the
[existing firing-role map](docs/WEAPON_DEFINITION_CONTRACT.md) and accepted
Hauler admission/home99f2717ee. Deliver its missing executable ordinary caller
and terminal observation, not cargo replay or full craft/eleven-binding closure.

- **Candidate/start:** clean e67299a53; fresh normal Boot/private empty profile,
  ordinary E/18 `CinderHaulerSupplyPilot.INITIAL_GOALS`/actual Dock04 boarding
  and90 neutral ticks. No activity arm/load, state/pose/health write or injected
  shot/packet. Ordinary default pilot input only; no parked route retry.
- **Owners/files:** one high-effort implementer owns existing
  `tools/release/run_native_sortie.py`, `tools/release/test_native_sortie.py`,
  `scripts/diagnostics/native_sortie_observer.gd`,
  `scripts/game/startup_loader.gd`, `tests/startup_cli_privacy_test.gd`.
  Root owns card/commands/package/integration/cleanup; one independent high
  reviewer checks terminal attribution, actual input and complete outcomes.
  No gameplay tuning change or missing-original/crew/remote scope.
- **Literal source-owned route binding:** from actual departed Dock04 use its
  accepted live capture→capture+world-UP60m clearance, then station-local
  (0,120,-200)→(0,30,-75), reaching each at≤2m/≤.5m/s. Query actual complete
  current hull/geometry before each leg; fail a blocker, never teleport or
  substitute another goal. Station coordinates follow the live World transform.
  Brake at the firing point; aim from actual muzzle to the current supported
  moving target, using real mouse and measured motion/lead. Missile-style
  camera or actor pose writes are prohibited. Return through (0,120,-200),
  the same live clearance point and original capture/home path.
- **Hit/miss binding:** actual `ExteriorTargetRange/TargetDrone01`, `DRONE-01`,
  base(-13,7,-95), real moving collider radius2.35m, starts100 health. Exactly
  one accepted real FIRE flight must travel then commit26 once (100→74).
  After normal cooldown, ordinary input aims the same muzzle station-UP;
  passively query its actual .45m-radius/180m swept corridor excluding own hull.
  Exactly one second FIRE flight must genuinely miss/expire after the authored
 1.2s/180m, with health74 unchanged. No fabricated target/empty-space receipt.
  Weapon stage45s from settled firing arrival through both terminals; total
  original CAP300/independent360 remains from process launch, never reset.
- **Source facts:** registered source1109/current Hauler, weapon
  cinder_cargo_mass_driver,180m/26/.70s,150m/s/1.2s/.45m; actual3-slot pool.
  Preserve inherited heat/component/ONLINE/cadence gates. Do not use
  get_last_player_shot_result's launch dictionary as a terminal proof. Passive
  pool bolt_launched/resolved/abandoned callbacks and real authoritative
  terminal ShotRequest/adapter hit context must correlate exact flight/source/
  weapon/sequence; slot identity alone does not establish source attribution.
- **Literal executable command:** `python3 -B tools/release/run_native_sortie.py
  ABS_LINUX_ELF --output /srv/mudds-work/hauler-weapon-20261105/ordinary
  --route hauler-weapon`. Add exactly this opt-in selector under existing
  x11/Dummy/private-input admission; preserve all old selectors/order/defaults.
  Existing native private Xvfb/dummy renderer/abort/input release/reaping stays.
  Normal output result must contain success=true and NATIVE_HAULER_WEAPON_OK
  only after every stage/normal OS0. No rendered/GPU/device/human qualification.
- **Complete checks:** existing full Python native suite; seven full headless
  matrix scopes: startup_cli_privacy_test, cinder_cargo_mass_driver_bolt_test,
  cinder_cargo_hauler_test, weapon_definition_test, live_combat_integration_test,
  combat_resolver_test, main_reentry_quality_test. Pinned Godot4.7.1, Dummy,
  jobs1/timeout300, first import always then never, original marker once,
  raw diagnostics0/OS0/stable source+imports. Compile actual observer via
  startup/privacy preload, without calling instance-only methods on its class.
  Clean paired exports/three strict --startup-check probes/full inventory+
  all nine existing package audit predicates remain required before publication.
- **Proof/close:** one exact immutable source/package, actual PID/input/actor/
  muzzle/target/flight/authority/impact/terminal/home/support/stock/reward/claim
  operand records and normal durable clean close. Root retains verified records
  and unique source; merge/push accepted work, seven repository checkpoint files
  with actual scope notes; exact owned worktree/ref/process/scratch cleanup.
  No validators/schema versions/new evidence family, Downloads or hosted CI.
- **Budget/stop:** readiness costs retained from20:40:26UTC2026-11-05;
 90min all-in estimate/absolute22:10:26UTC deadline. Freeze **three corrections
  total** for this cross-component input/flight/terminal capability, each only
  after concrete cause plus cumulative-cost GO. First unexpected failure stops
  dependent work; final failed correction/deadline parks complete delivery.
  Original input/home sublimits remain:15s/walk goal,12s boarding,15s home
  alignment,120s landing,10s exit,90 neutral OFFLINE observations. No cost or
  correction reset, smaller endpoint or automatic successor. Prior parked
  station/Cinder attempts retain their distinct costs and owner gates.

| Frozen case | Actual action | Expected endpoint | Result |
| --- | --- | --- | --- |
| Physical admission/departure | Normal Boot/E/supported18-goal walk/actual E boarding/neutral90/W departure/live clearance and fixed firing route | Same production Dock04 Hauler/Player/source/default controls, ONLINE/home lease released, healthy hull and unchanged cargo/reward/other claims; real full-hull route queries pass | NOT_RUN |
| Genuine travelling hit | Native FIRE once at actual DRONE-01 with real muzzle/motion aim | One correlated current source1109/weapon/sequence/flight; launch health100, positive-age displaced flight observation before actual terminal; supported adapter commits26 once, health74, no duplicate damage | NOT_RUN |
| Genuine miss/retirement | Wait normal .70s gate; physically aim/query station-UP corridor, native FIRE once | Distinct flight, real positive-age travel then lifetime miss; health74 stable, pool/authority active counts0, no abandonment/resurrection/duplicate, authored weapon/heat behavior retained | NOT_RUN |
| Complete home and delivery | Fixed reverse route, original captured L/strict lease,90 neutral OFFLINE, physical E exit/apron walk/normal UI Quit | Exact occupied dock_04_cargo/root error≤.05m/speed≤.05m/s, supported same Player walk≥1m to accepted apron(8.8,4.18,90); actual OS0/both clean markers/diagnostics0; all source/native/package gates pass, pushed source/checkpoint and owned cleanup complete | NOT_RUN |

Hauler correction1/3 authorized21:57UTC: actual travelling impact reached the
moving target, but the authoritative re-query ended at a rounded surface point
roughly1µm outside its collider and returned a miss. Repair only the runtime
terminal-segment handoff in `travelling_bolt_projectile.gd`, extend the existing
oblique target regression in `cinder_cargo_mass_driver_bolt_test.gd`, and retain
the original range/occlusion/source/faction/once-only damage rules. Observer and
Python timing/representation repairs retain real airborne proof and exact26
once-only damage. The original22:10:26UTC all-in deadline is unchanged; failed
native records remain retained. Full hit/miss/home delivery remains unaccepted; the actual hit later passed but the caller stopped before miss/home.

### Station Reduced Flash ordinary package/UI episode — integrated

Source **e3880319c**, pushed in main **a7538b24e**. Actual packaged ordinary
Boot/E, supported spawn, settings OFF→ON→OFF→ON, unchanged actor/resource
identities and gameplay authority, exact presentation caps, explicit Save and
independent durable settings, normal Exit and both clean markers pass in71.645s;
zero diagnostics and all synthetic inputs/processes cleaned up. Six focused
Godot suites pass on unchanged Godot sources;310 Python checks pass. The store
negative-fixture suite deliberately produces four expected warnings; ordinary
package/startup checks produce none. Paired exports, three strict startup probes
and all nine package audit predicates pass. EXE/ZIP/notes and paired Linux
checkpoint are in builds/. This is property/UI qualification, not pixel,
native Windows/GPU or full COMFORT-FLASH acceptance.

Original start20:17:08UTC and21:32:08UTC all-in deadline retained. Runtime,
package audit, integration and push finished before the deadline; archive and
branch housekeeping overran it. Do not count this as an on-budget completed
sprint or reset its cost. Earlier failures remain in the preserved task archive
and [initial failure record](docs/history/ROADMAP_DELIVERIES.md#station-flash-startup-test-compile-stop-20261105).
No more station scope is opened by this result.

### Cinder remote pilot exterior-body handoff — PARKED, unaccepted

The selected ROLE-CINDER-LOADMASTER pilot-body member stopped on its final
allowed correction. Candidates7a356bd18→a98e3b7ac→677c5c4f2→ae24ec526 remain
unmerged. **No gameplay from this attempt is accepted; no checkpoint exported.**

Final actual client/host ENet run exits1 after16 passing assertions: cabin-body
promotion retirement, trusted fresh generation2 handoff, actual host pilot-anchor
birth, early cargo-authorization refusal, real seat-exit completion, restored
collision and on-floor state. Its next required check fails: the actual support
is Hauler `CinderCargoVisual/BoardingRampSupport`, while the frozen assertion
requires support beneath current Cinder access. Actual body position:
(35.21464,-66.98969,-700). This is a measured support-owner mismatch, not proof
of missing floor, a complete physical handoff or an accepted alternative.

Walking/client binding, post-exit cargo eligibility, stale/foreign input,
ordinary A reboard and all four retirement cuts remain **NOT_RUN**. Initial
7a356's complete remote-body suite passes190 assertions/245.002s with stable
source/import guards and zero diagnostics; it does not qualify the corrected
final candidate. Remaining source suites and every package gate are NOT_RUN.

Three corrections are spent: preserve the existing same-A pilot return (review
found an unconditional boarding refusal), repair two multiline fixture lambda
predicates, then explicitly type three WeakRef declarations under warnings as
errors. No failed predicate, original case, threshold or deadline was waived.
The fixed90-minute budget starts19:27:45UTC and ends20:57:45UTC2026-11-05;
actual failure occurs before the deadline. Closure cost and verified retained
source/results are in the [delivery record](docs/history/ROADMAP_DELIVERIES.md#cinder-pilot-exterior-support-owner-stop-20261105).

**Reopening requires explicit user reprioritization**, retaining all prior cost
and exhausted allowance, plus a bounded reconciliation of the actual supported
Hauler-ramp exit with the original live-exit/Cinder support contract. Establish
whether an actual further supported step is required; do not simply loosen the
support-owner assertion. All original walking, eligibility, replay, pilot return,
retirement, regression and checkpoint cases remain required. No retry or next
implementation is selected by this closure. Parked B passenger work is separate.

### Next delivery chain: remote Cinder pilot and terminal

These are separate members of the existing
[ROLE-CINDER-LOADMASTER contract](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback),
not new roadmap IDs. Execute in order only after the recorded selection gates
are satisfied. The first member is now PARKED above; the other members remain
GATED. No readiness resurvey or automatic retry is selected.

| Goal | Player-visible result | Fixed proof endpoint | Dependency / selection state |
| --- | --- | --- | --- |
| Host-authoritative pilot exit and walking body | Remote A leaves the Hauler pilot seat at the occupied Cinder berth and walks the same exterior actor on client and host | Host creates exactly one production body at its actual pilot anchor; real seat-exit completes onto support; authenticated input moves that same body≥1m; client/publication generations agree; host Player/camera stays unchanged. Foreign, duplicate and retired-generation input cannot move/recreate it; lease/source loss and disconnect retire it. Stock/payment unchanged. | Existing live Cinder berth/source/attachment and authenticated pilot grant. PARKED/unaccepted at the support-owner predicate above; six-case contract below remains binding. Parked B passenger exit/readmission is not a prerequisite or a retry authorization. |
| Remote terminal interaction and one conserved transfer | A uses normal terminal E after its physical exit and delivers one existing crate | Real host body passes live exit≤2.5m eligibility; current terminal action reaches existing cargo owner; source/hold2→1, destination0→1, exactly one completion/reward. Duplicate/stale/foreign attempts change neither stock nor payment. Existing120s activity limit retained. | GATED on accepted pilot body handoff and the existing load/clear-gate/dock phases. Readiness alone is not cargo authority. |
| Complete Loadmaster moving-crew journey | A pilots while B uses Loadmaster, then both complete the specified home/rejoin/handback route with the conserved delivery | Every original moving/chair/action/home/owner-loss/standing-rejoin/physical-exit/reuse case passes, all three processes exit0, no diagnostics, within original900s internal/960s outer bounds | GATED on both capabilities above, accepted standing readmission, guest ramp/exit and the missing ordinary caller. Two prerequisite attempts remain PARKED; their explicit reopening conditions still apply. |

The first delivery has this finite case membership. This is the acceptance
contract, **not a claim of execution or a completed start card**:

| Case | Setup/action | Expected observation |
| --- | --- | --- |
| 1. Actual pilot exit | Actual Main, authenticated ENet A, exact current Hauler pilot grant and occupied attached Cinder berth; request ordinary confirmed departure | Exactly one host production Player starts at the actual host pilot anchor and follows existing seat-exit motion; collision restored and floor support established at the live exit. No fixture spawn at the exit or actor teleport. |
| 2. Walk and publication | After physical completion, send fresh authenticated walking input | Same body moves≥1m under host simulation; publication advances with matching client/body generation. Host local Player/camera and stock/payment snapshots remain unchanged. |
| 3. Physical eligibility | Try existing cargo actor authorization before and after completion | No authorization before completion; actual completed body qualifies only under the existing live source/lease/attachment and≤2.5m exit rule. This does not perform or prove a transfer. |
| 4. Rejected ownership/replay and preserved pilot return | Submit foreign-peer input, duplicate departure and old body-generation/stream input; then same A walks to the actual supported boarding hatch and requests normal pilot BOARD | No second body, unauthorized movement, authorization, debit or reward. Replacement generation is authority-issued and retires the old input stream. Legitimate same-A/same-craft reboard obtains one current pilot grant and usable helm; old exterior body/publication/client prediction retire once before the ordinary boarding presentation. |
| 5. Retirement | Separately disconnect A, invalidate the berth lease and remove the current source/attachment | Each cut retires its body, movement authority and publication once; later packets cannot resurrect or authorize it. |
| 6. Integration and delivery | Run complete existing Halyard remote-pilot/body regressions and the new Cinder cases, then clean-commit checkpoint export and isolated startup | Original regression cases pass; each required command exits0 with its exact success marker and zero diagnostics. Package startup exits0 with exactly one STARTUP_MENU_READY_OK. Accepted source is merged/pushed; build notes state the scoped result; owned cleanup completes. |

Implementation owners are GameFlow, NetworkRemoteBodySimulation and the ENet
adapter, with the existing remote-pilot test extended. Freeze exact paths,
commands, per-case limits, remaining correction allowance and absolute≤90-minute
all-in deadline on the selected card **before code**. If that cannot fit, stop
selection and split the production capability; do not quietly omit a case.
No full-role, cargo, native-hardware or general exterior-networking completion
is implied by the pilot-body member.

### Closed work and retained exceptions

| Result | Status / retained boundary | Proof |
| --- | --- | --- |
| Checkpoint duplicate cleanup | 298 verified duplicates removed /50.2GB reclaimed; five permission mismatches retained and three Linux candidates NOT_RUN at cutoff. Remaining cleanup PARKED. | [Accounting, archive and restore checks](docs/history/ROADMAP_DELIVERIES.md#checkpoint-duplicate-cleanup-cutoff-20261105) |
| Jovian distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#jovian-whole-lod-delivered-20261105) |
| Hauler distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#hauler-whole-lod-delivered-20261105) |
| Bomber distant exterior | Scoped runtime/image/package PASS; complete craft and native qualification OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#bomber-whole-lod-delivered-20261105) |
| Shared retained-Main all-nine | Source identity/claim/home/repair scope PASS; ordinary journey/restart/networking OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#main-nine-component-claims-home-qualified-20261105) |
| Bulwark editable source | Scoped handoff/reproduction PASS; gameplay/art/LOD OPEN | [Delivery](docs/history/ROADMAP_DELIVERIES.md#bulwark-editable-source-handoff-accepted-20261105) |
| Player-motion retained images | Nine image hashes match; source/run/inspection binding missing. GATED; no unchanged search or recapture selected. | [Exact missing artifacts and search boundary](docs/history/ROADMAP_DELIVERIES.md#player-motion-retained-binding-stop-20261105) |

These are selection constraints, **not a list of tasks running in parallel**:

| Existing goal/member | Current result or blocker | Condition before further work |
| --- | --- | --- |
| [Cinder Light role-choice card](docs/history/ROADMAP_DELIVERIES.md#cinder-light-choice-card-fit-stop-20261105) | PARKED: added line needs73px inside63px body in all six existing fit cases | Explicit reprioritization and bounded text packing that preserves exact trade-off/full instructions/facts/state,normal fonts and original case/tolerance limits;retain cost/exhausted allowance |
| [Bulwark whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#bulwark-lod-cockpit-clearance-stop-20261105) | PARKED: required capture fails two unchanged cockpit-clearance assertions despite source and dimension passes | Log exact failed operands, reconcile original clearance contract, explicitly reprioritize with prior cost/exhausted allowance; no subset acceptance |
| [Halyard whole-craft LOD runtime](docs/history/ROADMAP_DELIVERIES.md#halyard-lod-capture-viewport-stop-20261105) | PARKED: source passes,but captured strip/panel dimensions crop the staged review layout | Explicitly reprioritize exact harness viewport/content scaling;unchanged image/geometry/camera/package gates and prior cost remain |
| [Rime solo access/outbound caller](docs/history/ROADMAP_DELIVERIES.md#rime-solo-outbound-alignment-stop-20261105) | PARKED: consumed look continues after alignment stage changes; four-tick tolerance fails | Measured input cause/correction and explicit reprioritization; no tuning or tolerance change inferred |
| [Cinder remote terminal handoff](docs/ROADMAP_BACKLOG.md#cinder-remote-crew-moving-handback) | Pilot-body attempt is PARKED at the measured support-owner mismatch; terminal transfer remains GATED | Explicit reprioritization plus exact support-contract reconciliation is required before retry; all six cases and prior cost remain; parked B egress remains separate |
| [Eight missing craft baselines](docs/ROADMAP_BACKLOG.md#owner-design-baselines-20261105) | Owner ADOPTED all eight prepared modern designs2026-11-05;9/17craft still implemented | Select dependency-ready build capabilities; no repeat design approval or false construction credit |
| [Halyard fresh-Main re-entry](docs/history/ROADMAP_DELIVERIES.md#halyard-fresh-main-offtree-stop-20261105) | PARKED: off-tree cabin-transform errors during actual HUD Restart Shift; no complete re-entry pass | Focused repair/retry request unanswered; original12:47:51UTC deadline expired. Requires explicit reprioritization, retaining cost and exhausted allowance |
| [Jovian first kit-delivery caller](docs/history/ROADMAP_DELIVERIES.md#jovian-native-caller-pause-epoch-stop-20261105) | PARKED: observer motion epoch jumps across Resume before walking; no movement defect established | Concrete pause/freshness correction and explicit reprioritization; original limits/cost remain |
| [Guided flight-observation caller](docs/history/ROADMAP_DELIVERIES.md#guided-flight-observation-stimulus-stop-20261105) | PARKED: requested120px input observed as about150px; exact cause unmeasured | Demonstrated input-unit cause and explicit reprioritization; no renamed retry |
| [Cinder Light whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#cinder-light-whole-lod-render-stop-20261105) | PARKED: capture timed out without an image; declared internal watchdog missing | Retry request unanswered and11:12:11UTC deadline expired; explicit reprioritization required |
| [Arrow whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#arrow-whole-lod-typed-membership-stop-20261105) | PARKED: typed mesh-array membership fails on Node3D | Type-safe correction and explicit reprioritization retaining exhausted allowance |
| [Zenith whole-craft LOD](docs/history/ROADMAP_DELIVERIES.md#zenith-modern-lod-census-stop-20261105) | PARKED: ArrayMesh-only method called on BoxMesh | Concrete mesh-type correction and explicit reprioritization retaining exhausted allowance |
| [Cinder retained-cabin readmission](docs/history/ROADMAP_DELIVERIES.md#cinder-standing-readmission-initial-chair-stop-20261105) | PARKED: initial Navigator chair Interact fails before rejoin | Diagnose that rejection, preserve landing guard, explicitly reprioritize |
| [Cinder guest egress](docs/history/ROADMAP_DELIVERIES.md#cinder-guest-egress-home-gate-stop-20261105) | PARKED: host home-ramp eligibility fails before guest launch | Satisfy the recorded causal reopening and cumulative-cost conditions |
| [Landed-crew browser entry](docs/history/ROADMAP_DELIVERIES.md#landed-crew-admission-ui-entry-stop-20261105) | PARKED: failed before admission; no joining feature accepted | Satisfy its recorded reopening conditions; no subset pass |

Every parked source/result remains recoverable from its linked delivery record.
Owned branches/worktrees/scratch for the closed attempts are cleaned up. Their
complete routes, failures, original budgets and correction limits stay binding;
a new label or automatic continuation cannot reset them.

Previously accepted [Rime arrival guidance](docs/history/ROADMAP_DELIVERIES.md#rime-arrival-guidance-delivered-20261105),
[retired-world residency](docs/history/ROADMAP_DELIVERIES.md#retired-world-residency-delivered-20261105)
and [Ember passive progress](docs/history/ROADMAP_DELIVERIES.md#ember-passive-progress-delivered-20261105)
remain closed in their recorded scopes. Aurora/Rime settled resume retirement,
Ember Save Progress, Arrow guidance and exported dedicated startup also retain
their accepted scopes. Halyard physical egress and Ember outbound remain parked
at their previously recorded station-spawn and planetary-gravity caller failures.
Do not reselect accepted components or use them to pass an unperformed full journey.

## Read this as a delivery plan

The [canonical backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the original requirements and their detailed acceptance contracts.
Its 337 records include containers, definitions and decisions; **337 is not the
number of coding tasks left**. The [36 original outcomes and ten phase gates](docs/ROADMAP_BACKLOG.md#coverage-of-the-original-remaining-outcomes)
remain open. Accepted and failed attempts belong in the
[delivery history](docs/history/ROADMAP_DELIVERIES.md), not in the next-work queue.

Use these three levels:

| Level | What it means | When it closes |
| --- | --- | --- |
| Product outcome | A complete craft, activity, world journey or release requirement | Every named child and its complete integration gate passes |
| Delivery goal | One independently usable game behavior or executable build capability | The fixed player/build action passes, accepted code is merged/pushed, required checkpoint is available and owned cleanup is complete |
| Qualification goal | One named journey, package, hardware or device check | Its original complete cases pass on the declared candidate and environment |

A source map, specification, test fixture or passing component check does not
close a delivery goal for a behavior it has not demonstrated. A completed child
does not close its parent. An unavailable owner decision or device is a named
blocked dependency, not an indefinite coding assignment.

<a id="current-planning-goal-finish-the-executable-breakdown"></a>

## One goal, one result, one stopping point

The existing [337-record backlog](docs/ROADMAP_BACKLOG.md#concrete-child-outcomes)
retains the requirements and their acceptance contracts. The backlog inventory
and goal classification are closed; do not repeat them. Missing acceptance
fields and owner inputs remain blocked as recorded in their contracts. The
records include completed work, broad containers, implementation, qualification
and owner decisions. They are not 337 unfinished coding tasks. The eight delivery groups below organize that scope;
none is an executable assignment.

Select a bounded child or an explicitly named member of its existing contract.
Give independently deliverable behaviors separate cards. Keep the complete
ordinary journey as a required integration goal; smaller checks never replace
it. No implementation may start from “finish the ship”, “improve multiplayer”
or another broad heading.

## How we will work from this roadmap

### Task card required before starting

Keep the selected card in [Current work](#current-work-and-next-selection),
using the existing goal ID and contract. Fill every field before editing code:

```text
Goal / contract: existing ID and exact member; link to its acceptance contract
Result: one observable player behavior or executable build/release result
Candidate / start: source or package, initial state, location and participants
Owner / files: implementer and exact files; reviewer when needed
Dependencies: prerequisite IDs and accepted results; missing input + owner
Cases: complete finite list, with ordered ordinary actions or literal commands
Expected: observable endpoint/value for EACH case, including preserved behavior
Proof: output location, environment and which scope it can establish
Budget: all-in estimate, absolute start/deadline, original test limits
Stop: correction allowance, independent abort, first-failure endpoint
Close: actual versus expected, status, elapsed cost, merge/push/build/cleanup
```

**A link alone does not fill a field.** Resolve the linked contract to its actual
cases and expected observations on the card. Reuse its values and limits; do not
invent numerical thresholds. A case should read “given this state, perform these
actions, observe this result”. Words such as “polished”, “robust”, “usable” or
“all applicable” need the literal observation that makes them pass or fail.

Use this small table for the cases, then fill the last column at closure:

| Case | Initial state and action | Expected result | Actual result and proof |
| --- | --- | --- | --- |
| Each named case | Exact setup and steps/command | Observable endpoint/value and preserved state | NOT_RUN until performed; then measured result and artifact |

### Missing information has an endpoint

| Situation | Required next action | When that action ends |
| --- | --- | --- |
| Contract field missing | Codex supplies that exact field in its existing contract, using a 15–30 minute bounded definition pass | Finite answer recorded, or exact absent value/artifact, completed search boundary and owner recorded; no rolling research |
| Product choice or external resource missing | State the exact question/artifact and its owner using the [existing input contracts](docs/ROADMAP_BACKLOG.md#blocking-decisions-and-resources) | Answer/resource recorded; no inferred approval and no blocked implementation |
| Runtime or ordinary caller missing, but behavior defined | Select its bounded implementation with a fixed check | Implemented result passes that check, or failure is parked; a caller/component check alone cannot qualify the ordinary journey |
| Prerequisite unfinished | Name its existing ID and required result | Dependency actually passes before dependent work launches |
| Earlier attempt parked | Retain its failure, source, cumulative cost and causal reopening condition | Reopen only under that condition; exhausted allowance/deadline also requires later explicit user reprioritization |

An undefined goal is **BLOCKED definition**; an unavailable choice/resource is
**BLOCKED input**; an unfinished prerequisite is **GATED**. OPEN and UNSCHEDULED
never mean READY. No missing field authorizes an open-ended assignment.

### Fixed budget and failure boundary

Estimate implementation, checks, required checkpoint, integration and cleanup
**together**, at no more than 90 minutes per implementation assignment. Split
larger production capabilities before starting. Full journeys and soaks retain
their original durations; do not shorten them to fit an implementation card.
Default correction allowance is one; freeze it and the absolute deadline first.

Stop dependent checks at the first unexpected failure and retain its actual
operands/output. Every correction needs a demonstrated cause and cumulative-cost
decision. **Routine compiler errors and incorrect test assertions are normal
implementation repairs inside the unchanged absolute time budget. They do not
require owner permission or consume the substantive-behavior correction limit.**
They still require a clean candidate and rerunning the complete affected gates;
no check, threshold or endpoint may be dropped to obtain a pass.

Frozen correction allowances apply to substantive production/behavior repairs.
Their exhaustion, an unresolved product requirement or the hard deadline parks
the task. New names, branches or smaller subsets never reset cumulative cost or
extend a deadline. Expired or substantively blocked parked attempts retain their
recorded reopening conditions and explicit priority decisions. This is not a
blanket retry of old work. No dependent check starts before its prerequisites
pass; unrelated defects return to their existing owner. Ask the user for real
product/scope/resource decisions, not approval to repair a mistake in a test.

### What counts as finished

A goal is PASS only when **every frozen case passes in the declared scope**,
accepted changes are merged and pushed, any required playable checkpoint is in
`builds/windows/`, and owned branches/worktrees/processes/scratch are cleaned.
Preserve unique rejected source and results before deleting their task refs.
Report retained exceptions. An unfinished task closes as FAIL, BLOCKED or PARKED
with the exact next input/reopening condition; do not quietly move to another
branch. No automatic successor is scheduled by closing a card.

Source tests establish their source scope; staged setup does not establish
ordinary access, and Linux/software rendering does not establish native Windows
or target-GPU performance. Required physical-device and human checks stay open
until performed, subject to the recorded owner exclusions. A completed definition
or child never closes an unperformed gameplay journey or its parent container.

Progress reports use **goal → player/build result → status → proof → blocker →
elapsed cost → next action**. Definitions, validators, test counts and commits
are not a project percentage. Do not invent a finish date from the row count.

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

[Final defect reconciliation](docs/ROADMAP_BACKLOG.md#final-candidate-defect-inventory)
now specifies the existing ledger/result inputs, candidate build-note inventory
and exact blocking verdict. Actual candidate review and implementation/qualification
remain open; zero known bugs alone cannot pass unfinished release journeys.

[Torrent remaining damage](docs/ROADMAP_BACKLOG.md#torrent-remaining-contact-repair-contract)
now fixes hit budgets and actual component consumers. It also identifies the
missing legitimate return path after wing/engine failure: the defender phase
blocks landing, so those cases cannot yet be selected for execution.

Existing [docking recovery](docs/ROADMAP_BACKLOG.md#installed-recovery-exact-cuts),
[Halyard engineer](docs/ROADMAP_BACKLOG.md#halyard-engineer-moving-return),
[Zenith contact/repair](docs/ROADMAP_BACKLOG.md#zenith-remaining-contact-repair-contract)
and [caption episode](docs/ROADMAP_BACKLOG.md#caption-ordinary-episode-contract)
contracts already define their acceptance fields. Their remaining work is the
named implementation and qualification, with parked prerequisites preserved;
do not restart those definition surveys from stale status wording.

[Packaged Ember abandonment](docs/ROADMAP_BACKLOG.md#ember-packaged-physical-abandon-contract)
now names the real pause-menu action, incomplete checkpoint/data checks and
physical home/reuse endpoint. Its normal Save integration and complete input
caller remain missing; the parked outbound gate remains a prerequisite.

[Exported dedicated authority](docs/ROADMAP_BACKLOG.md#packaged-dedicated-authority-contract)
now has a concrete Boot/CLI, listening, orderly one-session exit and packaged
two-client acceptance contract. The accepted source harness remains narrower;
normal Boot launch and optional orderly session exit are delivered on24ed6bc86;
packaged gameplay participation and full qualification remain open.

## Selecting work after the breakdown

Select one ready delivery or qualification goal from an existing row; fill its
card before editing or running checks. A broad craft/activity/world container is never one assignment. Follow
literal prerequisite IDs; independent ready capabilities may run in parallel
with disjoint ownership. A parked task needs its recorded causal reopening
condition and cumulative-cost decision before selection; exhausted limits also
require the explicit user reprioritization described above.

Close each assignment before moving on: actual result and proof, merge/push
accepted changes, required playable checkpoint, and owned branch/worktree/process
cleanup. Preserve unique rejected source without merging it. Report retained
exceptions explicitly. A new failure belongs to its existing goal; it does not
automatically enlarge the current task.

## Validation and final release

Automated Godot always uses Dummy audio, headless or private Xvfb with explicit
x11. Audible output requires authorization. GitHub Actions remains disabled.
Native Windows execution and mandatory human review remain owner-excluded;
unperformed facts stay NOT_RUN. Applicable Linux/native GPU/device/audio gates
remain; simulated checks cannot supply physical measurements.

The final exit is one accepted candidate with zeroP0/P1, explicitP2 dispositions,
required complete ordinary journeys and unfiltered local matrix, matching
installable artifacts, settled rights/signatures and authorized downloaded-byte
identity. All [ten phase exits](docs/ROADMAP_BACKLOG.md#original-phase-gates-and-completion)
remain binding. Missing design decisions or hardware access stay named blockers;
they do not become indefinite implementation tasks.
