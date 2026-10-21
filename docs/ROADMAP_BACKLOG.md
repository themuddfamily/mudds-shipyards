# Roadmap backlog and original requirement crosswalk

Start with the 36 original parent outcomes below, then follow the named child
inventory and its family acceptance contracts. The original promises and all ten
phase gates remain binding in the [preserved scope](history/ROADMAP_SCOPE_20261017.md).
The [working roadmap](../ROADMAP.md#execution-now) selects executable work;
[delivery history](history/ROADMAP_DELIVERIES.md) records accepted and failed attempts.
This backlog preserves remaining scope, not a ready queue or remaining-job count.

| Find | Existing section |
| --- | --- |
| Original promises and their named children | [36-parent crosswalk](#coverage-of-the-original-remaining-outcomes) |
| Original acceptance gates | [Ten phase gates](#original-phase-gates-and-completion) |
| Named outcomes and dependencies | [Concrete child inventory](#concrete-child-outcomes) |
| Unresolved multiplicities and estimates | [Unknown scope and counting](#unknown-scope-and-counting) |
| Acceptance contracts and retained failure boundaries | [Family contracts](#family-contracts) |
| Source-specific historical context | [Retained context](#retained-source-specific-context) |

Read rows by the result they describe; these distinctions do not change existing
row statuses or acceptance:

- **Capability:** a concrete runtime, player-content or executable build/release
  change. Select it only after identifying its production gap, exact owners,
  bounded implementation and focused acceptance.
- **Qualification:** proof of an existing capability or complete journey on a
  specified source/package. Preserve its full original route and limits; an
  unqualified final candidate does not imply missing implementation.
- **Definition or dependency:** a finite unresolved contract/list, owner decision
  or external input. Its completion identifies actual uncovered capabilities or
  an exact blocker; it delivers no gameplay by itself.

No row automatically schedules a successor. A new defect ends the selected
attempt; any further work needs its own bounded selection and retained failure
budget. Parked work requires its recorded reopening condition.

## Owner decisions accepted2026-10-21

Freight transfer remains automatic on landing; physical terminals expose the
existing cargo job/manifests/receipt. Hauler shares existing Jovian stock with
conserved custody, without creating more cargo. Every fresh current authenticated
navigator rejection gets requester feedback, including unavailable consumers;
stale/replayed/foreign responses remain silent. Beacon outbound maximum is60s
using the existing unpaused monotonic clock and unchanged route/start/stop criteria.
Bomber ammunition refills when the pilot retakes the seat. These resolve the
historical unanswered choices below; implementation and qualification remain
separate. FREIGHT-TERMINAL-INTERFACE is completed on509703300/checkpoint5097033,
integrated/pushed with owned scratch cleaned. HAULER-CARGO-MANIFEST also DONE
on6bcbea302/checkpoint6bcbea3; full ordinary delivery/cold inventory remain open.
Navigator requester rejection feedback is DONEc2c72a223/checkpointc2c72a2.
Select one next bounded card; other roster/capacity/role decisions are unchanged.

## Coverage of the original remaining outcomes

These are **36 parent outcomes**, not 36 executable jobs. They remain open until all applicable named instances and original acceptance conditions hold. This crosswalk is the guard against losing scope during the rewrite; it is not an extra evidence system. Original wording and all ten phase specifications remain in the preserved reference.

Each final cell below names one unfinished child, what proves it, and its current
prerequisite. It is a next-step map, not permission to run that child or a
replacement for the full child inventory. Definition completes a contract;
qualification proves an existing capability. Neither implies new gameplay.
Parents 3/27 share the same 21 world cells; parents 6/35 share MATRIX-FINAL;
parents 11/21 share damage ownership. Do not count these twice.


| Parent | Original parent outcome | Active task families | Next bounded result, proof and remaining dependency |
| --- | --- | --- | --- |
| 1 | Finish final integrated-source and packaged physical abandonment acceptance | WORLD-ABANDON, WORLD-SOLO, PACKAGE-WIN, PACKAGE-LINUX | **Qualification — EMBER-PACKAGE-ABANDON.** GATED on a supported packaged OS-input route; old external driver UNSUPPORTED. Prove physical outbound/abandon/reboard/ascent/home docking and usable walking. Source abandonment stays accepted; real-file/reuse and other world cases remain. |
| 2 | Complete matching installed interruption/recovery on the accepted integrated build | RECOVERY-CONTRACT, RECOVERY-KILL, INSTALL-LINUX, FINAL-RECONCILE | **Qualification — CREW-RECOVERY-INSTALLED.** GATED on final installed candidate and one supported craft/seat/cut. Prove committed context → owned kill/reap → distinct restart → awake supported home cabin, usable controls and conserved activity/reward. Other installed contexts and reconciliation remain. |
| 3 | Complete canonical-distance outbound and return with ordinary remote crews for Ember, Aurora and Rime, including activities/rewards/save, late join, disconnect, pilot loss, cancellation, interruptions and repeat visits | WORLD-SHARED (each world/case), NET-CREW, RECOVERY-KILL | **Qualification — SHARED-EMBER-BASELINE.** GATED on ordinary independent crew/profile and exact canonical command. Prove outbound, physical survey, reward/save and home return. All 21 shared cells remain; Aurora originals WAITING, Rime arrival PARKED. Shared with 27, not another set. |
| 4 | Record the final shipped roster and supported limits | SCOPE-DECISION, NET-CAPACITY, ORIGINAL-SPEC | **Dependency — SCOPE-LIMIT.** WAITING on the already-asked owner choice. Finish records supported remote-guest count and playing-host participation. SCOPE-DESKTOP and BOMBER-ROLE-DECISION remain separate; SCOPE-ROSTER definition is DONE. |
| 5 | Assign owners, dependencies and estimates to the remaining deliverables | PLAN-ASSIGN and the per-session task card | **Definition — PLAN-NEXT / PLAN-ASSIGN.** Freeze one existing child: result, files/owner, accepted dependencies, exact proof, implementation/check estimate and first-failure stop. Finish is one executable assignment. Ownership/estimates for remaining deliverables stay open; no gameplay or release-date claim. |
| 6 | Qualify and package current source | BASE-DIAG/FIX, MATRIX, PACKAGE-WIN/LINUX | **Qualification — MATRIX-FINAL.** GATED on required repairs/integration and frozen candidate. Pass existing unfiltered local `--mode all` at original caps, without exclusions. PACKAGE-FINAL and reconciliation remain separate; latest accepted checkpoint `51257b3` is development scope. |
| 7 | Complete the normal-controls core playthrough and fix observed blockers | GUIDED, SANDBOX, SETTINGS-INPUT/RUN, LIFECYCLE, STATION-ROUTE, CRAFT-ACCEPT | **Qualification — GUIDED-FINAL.** GATED on final package. Prove original ordinary training/combat/home/neutral-shutdown/physical-exit route 3/3. Checkpoint `3d92b91` keeps its accepted3/3; new923d7b3 is not final-Guided-qualified; Sandbox PARKED, Settings WAITING, remaining station/craft/lifecycle journeys open. |
| 8 | Complete control and tutorial tuning | CONTROL-FIX, INPUT-DEVICE, INPUT-REMAP | **Qualification — INPUT-CONTROLLER.** WAITING on physical device, isolated session and frozen complete ordinary route. Prove actual-device menus and gameplay; synthetic input cannot supply this result. INPUT-KBM, Settings originals, remapping/context and tutorial cases remain. |
| 9 | Finish station layout and final presentation | HIST-CLAIM, STATION-MODULE/ROUTE/ART/LIFE | **Parked view — STATION-FINDINGS[Habitat common entry].** Source8a6339b91 full-Main player-height readback times out180.842s before any PNG; no visual finding or no-finding. Concrete supported capture-boundary change required before new selection. Accepted Habitat/service runtime scopes stand; remaining station routes/art and STATION-RELATIONS remain. |
| 10 | Finish fleet art, character animation and role acceptance | CRAFT-ART, CRAFT-ROLE, CRAFT-ACCEPT | **Dependency — BOMBER-ROLE-DECISION.** WAITING on exact additional role/count, action and physical access. Finish is the contract needed to split a justified capability; invent no role. Fleet art/animation/full craft journeys and eight SPEC→BUILD-SPLIT→CRAFT-ACCEPT chains remain. |
| 11 | Complete the combat-and-recovery slice across supported craft | COMBAT-SLICE, CRAFT-ACCEPT, NET-DAMAGE | **Definition — BOMBER-REARM-POLICY.** Owner chose refill when pilot retakes seat2026-10-21. Finish supplies entitlement before correction/qualification. HALYARD-GUNNER-DAMAGE one actual52damage/local lifecycle DONEc28f7ffa3; weapon/damage definitions are DONE; encounters, craft/recovery and shared damage remain. Courier first clear/home DONE4196ad0; other Courier outcomes and full ordinary Perimeter remain OPEN; both runtime integrations are shipped. |
| 12 | Complete the whole-game art-direction pass | ART-FINDING, STATION-ART, CRAFT-ART, CAPTURE | **Definition — ART-FINDINGS[one view].** Name an actual UI/animation/effect/lighting/terrain/weather defect, current view, intended before→after, runtime owner and protected route before repair. Other station/fleet art, accessibility and required capture sets remain. |
| 13 | Close the complete nearby-activity roster | ACT-HUD/WRITE/PLAY/REPEAT, TRAVEL-LIMIT, HULK | **PLAY-BEACON full journey DONE —bc48b2a/112.031s; PLAY-CINDER-SUPPLY DONE —9ed9a07; saved unpaid Start retry DONE —7ecdfec.** Complete original ordinary journey216.291s:13 station+6out+6reverse+5 reboard goals, transfer1/one actual-file credit/duplicate refusal, exact protected data including raceg1 through strict home dock, OFFLINE exit/supported1.234m walk and normal UI OS0. Merged/pushed; owned scratch removed. Four separate cargo lifecycle failures, repeats/restock/Hauler policy, full Defense and remaining activities stay open; no parent closure. |
| 14 | Qualify each implemented world's full physical round trip | WORLD-SOLO/ABANDON/SAVE/EDGE | **Definition — WORLD-SAVE-DEFINE[one world/boundary].** Specify initial state, survey/reward/reboard disk cut, once-only durable result and usable resume/safe recovery, with existing route/command prerequisite. SOLO returns, abandonment, other save cuts and EDGE cases remain. |
| 15 | Resolve remaining planetary content and presentation gaps | WORLD-CONTENT, ART-FINDING | **Definition — ART-FINDINGS[one planetary view].** Finish with an actual observed presentation defect, affected route and comparable before/after acceptance. CONTENT-EMBER/AURORA/RIME found no missing implementation; do not redo them. Original journeys, qualitative presentation and hardware gates remain. |
| 16 | Close remaining fleet/crew replication gaps | NET-CREW, NET-CAPACITY | **Qualification preparation — ROLE-JOVIAN-ENGINEER.** GATED on supported candidate/ordinary route. Freeze independent authenticated walk/sit/use/stand/exit and applicable ownership/disconnect recovery. Other seven role routes, NET-SEATS-FINAL, capacity and Bomber interpretation remain. |
| 17 | Complete remote engine and landing/dock presentation | NET-POSE, NET-BUDGET | **Definition — NET-POSE-DEFINE[one uncovered view].** Name one still-unqualified craft/operation/view, current/late-peer expectation, production consumer and existing test seam. Delivered operation HUD/throttle fixes are excluded from new work. Broader ordinary motion/landing views remain; NET-FULL-SNAPSHOT aggregate envelope checks are accepted on330a39ce3, with final-candidate/native/endurance qualification separate. |
| 18 | Complete supported remote helm actions and their real local-input prerequisite | NET-HELM, INPUT-DEVICE | **Recorded yaw+handback DONE007024839.** Full ordinary boarding/departure/both-yaw/normal helm release/current PASSENGER HUD/real backward walk passes136.675s with retired source/owner0gen+1, retained co-pilot, actual3OS exits0 and no diagnostics. Fresh paired0070248 checkpoint. Reverse/pitch/roll turn-release scopes remain accepted; other action-specific handback, boost/hover and physical-device prerequisites remain open. |
| 19 | Qualify honest remote-command recovery after host simulation stalls | NET-STALL | **Current source qualification DONE — NET-STALL on3d6b1b513.** Full independent suite passes both original600-step stalls/2s fresh actions, ownership/landing/reuse/cleanup,160 terminal host assertions and actual client/wrapper exit0; zero diagnostics. No unchanged rerun. Exact final-package/native/endurance and distinct ordinary-control gates remain; this does not accept a full matrix. |
| 20 | Complete remote landing, post-dock disembarkation and craft reuse | NET-LAND-DIAG, NET-DOCK | **Jovian pilot/co-pilot ordinary reuse DONEbc7f9f9c4.** Full boarding/flight/home landing, passenger exit/reboard, pilot exit/groundwalk/reclaim and repeat departure/braked stop pass with both actual clients. Reboard Interact repair49bc7b736 and paired49bc7b7 checkpoint remain current. Other supported craft/role instances, distinct second landing and full parent remain open. |
| 21 | Qualify fleet hull/component damage, repair, destruction and regeneration presentation across supported craft and roles | NET-DAMAGE | **Qualification preparation — NET-DAMAGE[one craft/role].** Freeze supported ordinary scenario, candidate and expected peer damage/repair/destruction/regeneration and usable recovery. DAMAGE-DEFINE plus identified component row/power repairs are DONE. Other supported scenarios and missing-original prerequisites remain; share parent 11 ownership. |
| 22 | Qualify the implemented convoy actor lifecycle in native gameplay | NET-ACTOR[Convoy] | **Definition — CONVOY-ACTOR-DEFINE[one lifecycle case].** Compare native gameplay coverage with authority tests; name participants/action and observable tender retirement/restoration, with ordinary Convoy prerequisite. Finish is one bounded executable case. Other live/dead/reset/late/disconnect cases remain; no parked save probe reopened. |
| 23 | Qualify Torpedo Run authority and solo recovery | NET-ACTOR[Torpedo Run] | **Gated qualification — TORPEDO-PEER-FLIGHT.** Requires actual Torpedo baseline/participant route and matching package. Prove current/late adoption of real airborne seeker without launch replay, then terminal retirement without duplicate damage/resurrection. COMBAT-TORPEDO and other nine authority/recovery cases remain. |
| 24 | Finish remaining travelling-weapon and moving-crew integration | NET-ACTOR[Picket/Emberline], NET-CREW, WORLD-SHARED | **Definition — PICKET-ACTOR-DEFINE[one lifecycle case].** Name supported moving-crew participants, existing actor/test owner and one observable live/dead/reset/late/disconnect finish. EMBERLINE-ACTOR-DEFINE/failed baseline and existing ROLE-/SHARED- cells remain; create no duplicate crew assignment. |
| 25 | Qualify the production server-browser and connection flow | NET-BROWSER | **Parked qualification — BROWSER-UNREACHABLE.** Accepted matching RPC-cache templates missing after stopped Windows compilation; no retry selected. Eventual proof is honest non-admission/no-answer feedback and usable retry/menu recovery at frozen limits. Other six ordinary browser cases and broader connection gates remain. |
| 26 | Pass multiplayer and endurance acceptance | NET-ENDURANCE, NET-CAPACITY, NET-BUDGET | **Qualification — remaining original server cases.** BOARD4bc0e3b38, full original MOVING-CABIN2e117e64f and real AUTHORITY-STOP082da79c9 accepted on current Linux source. The latter preserves full moving prefix then proves actual host disconnect, old-binding retirement and usable solo controls. Original client-pilot disconnect with surviving server/passenger is also accepted21817ab4b after the full moving prefix. Full SERVER-BASELINE, original30-minute/adverse-network endurance, chosen capacity and final/native qualification remain open; select its next complete named case separately. |
| 27 | Resolve planetary travel during multiplayer explicitly | WORLD-SHARED (each world/case) | **Dependency — SHARED-AURORA-BASELINE.** Recover original `47ffce740` runner/arguments, source/build/profile, participant state and raw orchestrator/peer receipts. Finish is that exact handoff; separately select reproduction. All 21 shared cells remain, including parked Rime arrival; same outcomes as 3. |
| 28 | Benchmark and optimize on representative native hardware | PERF-MACHINE/ROUTE/RUN/FIX | **Definition — PERF-ROUTES-DEFINE.** Define any required representative workloads beyond the seven delivered selectors, including how whole orbit-to-surface repetition maps to existing world endurance. Additional craft/world/cycle choices are unspecified; repeating cabin/surface paths and combat reuse already exist. Actual minimum/target hardware, measurement cells, original-length native runs and demonstrated hotspot fixes remain. |
| 29 | Complete real-device controls and accessibility review | INPUT-DEVICE/REMAP, ACCESS-VIEW/COMFORT | **Overflow capability DONE — ACCESS-TITLE on checkpoint19e7990.** Multiplayer is now inside the1024x768 title viewport; actual same-view comparison and eight-viewport retained-control/focus regression pass. ACCESS-TITLE-FOCUS is DONE checkpoint923d7b3: measured focus/press correction,32 paint pairs, same-view and paired package checks pass. Other view/remap/comfort/state/device gates remain. |
| 30 | Finish authored audio and the real-device mix pass | AUDIO-CONTENT/MIX | **Navigator requester feedback DONEc2c72a223.** Full actual peer proof and checkpoint preserve accepted/clear. Remaining AUDIO-MIX cases require their named routes/devices/backend and explicit audible authorization; actual listening stays NOT_RUN. |
| 31 | Finish production crash and save recovery | RECOVERY-CONTRACT/FIX/KILL, ACT-WRITE, WORLD-SAVE | **Definition — WORLD-SAVE-DEFINE[one remaining boundary].** Ember first-relay safe-yard cut DONE on exact packaged923d7b326 with caller6112944d0: actual kill/reap-9, distinct Resume0, exact passive progress, fresh boarding/original completion and one durable reward, zero diagnostics. Original failures retained; no tolerance/cap increase. Other world/context boundaries, installed cuts and migration/corrupt/unsupported cases remain open. Canonical outbound NOT_RUN, standing-pose restore NOT_SUPPORTED; no whole-parent closure. |
| 32 | Qualify installation, updates and supported desktop platforms | PACKAGE-WIN/LINUX, INSTALL-WIN/LINUX, LINUX-BUNDLE/DESKTOP | **Qualification — LINUX-LAUNCH-DESKTOP.** WAITING on clean isolated graphical session and frozen installed candidate/ordinary route. Prove actual installed desktop entry launches/completes it; headless startup is insufficient. Direct-ELF, final packages/NSIS, six Linux transactions and extra-target definition remain; native Windows exclusions stand. |
| 33 | Complete all required graphical capture gates | CAPTURE (each required registry ID) | **Qualification — caption-presenter-forward-render.** GATED on frozen candidate/original runnable harness. Produce its one declared PNG, verify source/output identity and inspect at original resolution; stop at set/result. Full 13-set/143-PNG registry stays binding; caption-production/station-operations keep parked reopening conditions. |
| 34 | Complete release licensing, trusted signing and distribution | RIGHTS, SIGN, DISTRIBUTE | **Dependency — RIGHTS[project release terms].** Record owner-chosen release-terms text and explicit distribution disposition; engine notices do not settle this family. Other asset/media rights, external trusted signing credentials and accepted-candidate/authorized-destination distribution remain separate. |
| 35 | Run final release acceptance on the exact distributed candidate | MATRIX, FINAL-RECONCILE, DISTRIBUTE | **Qualification — MATRIX-FINAL.** After required repairs/integration, freeze candidate and pass existing unfiltered local `--mode all`, original caps/no exclusions. Failure stops for separate named repair. Same matrix as 6; FINAL-RECONCILE and actual distributed/downloaded byte identity remain distinct; owner exclusions preserved. |
| 36 | Resolve historical reconstruction dependencies and deliver the remaining researched fleet | HIST-CLAIM, ORIGINAL-SPEC/BUILD, CRAFT-ART/ACCEPT, STATION-MODULE | **Dependency — SPEC-TITAN.** Modern proposal exists; explicit interpretation decision or tied model evidence is still required. Finish is bounded accepted specification with supported facts/unknowns. Build split/implementation/full craft acceptance, other seven absent craft, four identity claims and STATION-RELATIONS remain. |


## Original phase gates and completion

<a id="phase-1--research"></a>

[Phase 1 research](../docs/history/ROADMAP_SCOPE_20261017.md#phase-1--research), [Phase 2 vertical slice](../docs/history/ROADMAP_SCOPE_20261017.md#phase-2--vertical-slice), [Phase 3 station](../docs/history/ROADMAP_SCOPE_20261017.md#phase-3--shipyard-expansion-bounded-operational-lattice-slice-settled-full-phase-incomplete), [Phase 4 original fleet](../docs/history/ROADMAP_SCOPE_20261017.md#phase-4--original-fleet), [Phase 5 expanded fleet](../docs/history/ROADMAP_SCOPE_20261017.md#phase-5--expanded-fleet), [Phase 6 combat](../docs/history/ROADMAP_SCOPE_20261017.md#phase-6--expanded-combat-and-damage), [Phase 7 multiplayer](../docs/history/ROADMAP_SCOPE_20261017.md#phase-7--multiplayer), [Phase 8 nearby world/activities](../docs/history/ROADMAP_SCOPE_20261017.md#phase-8--nearby-world-and-activities), [Phase 9 release](../docs/history/ROADMAP_SCOPE_20261017.md#phase-9--release-polish), and [Phase 10 final quality/planets](../docs/history/ROADMAP_SCOPE_20261017.md#phase-10--final-quality-push-and-visitable-planets) retain their specifications and exit gates.

Project completion requires each original promise to be delivered and accepted, or explicitly deferred by the owner beside that promise; all required final-candidate gates must hold and distributed artifacts must match the tested bytes. No parent is closed by this reorganization. Report progress as named playable/runtime/release outcomes, completed task instances and actual blockers. Do not report a percentage from task rows, test totals, schema versions or commits.

## Concrete child outcomes

Reconciled on 2026-10-18 after the owner requested smaller, provable goals.
**One row is one named outcome.** [Family contracts](#family-contracts) define the proof;
ROADMAP.md schedules a small executable queue with owners, actions and budgets;
the retained postdock cards split the exit/reuse family into five ordered outcomes.
These rows replace the earlier grouped “per craft/role/world” inventory.
A family row such as CRAFT-ACCEPT is a completion container, not an executable
assignment. Its next bounded action must be selected in the working roadmap;
never interpret all remaining clauses in a row as one session's task. An existing
source handoff is reused until a relevant source change invalidates it. Planning,
implementation and qualification are reported separately; adding smaller rows
alone does not deliver any of their runtime outcomes.
They are a scope inventory, not an implementation estimate or a project percentage.

**States:** UNSCHEDULED = named scenario, not yet assigned/frozen; DEFINE =
finite list or contract still needed; GATED = named prerequisite; WAITING =
external resource; PARKED = earlier failure/reopen condition still applies;
DONE = only the cited source/scenario is accepted. Readiness is assigned in the
working queue; inventory references point there. A check already accepted does not become missing implementation
because the final candidate is not selected. No unchanged rerun is scheduled here.

One named qualification may have a long existing route; keep its original
limits. An implementation expected to exceed 90 minutes must be split into
named capabilities before starting. A new defect ends the current card and
amends this inventory; it does not silently add steps to it.

### Baseline, scope and planning children

Finish means the named existing route passes on its frozen candidate, or the named definition ends with a finite answer/missing input. Guided, Sandbox and Settings retain their original [baseline contracts](#baseline-and-ordinary-controls).

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| SCOPE-ROSTER | Reconcile original twelve plus modern five craft, stations, opponents/weapons, activities, worlds, roles and targets | 4 | DONE as [finite named roster](COMPLETION_SCOPE.md#finite-release-roster--scope-roster): original12+modern5/eventual17, current9/missing8; other named inventories and unresolved boundaries preserved. No gameplay/qualification completion implied |
| SCOPE-LIMIT | Release guest count and playing-host decision | 4,26 | WAITING; already-asked owner decision |
| SCOPE-DESKTOP | Required desktop target list | 4,32 | WAITING final owner list: Windows Desktop/Linux x86_64 presets exist; Phase9 conditionally requires other non-Windows targets without naming one. Source investigation DONE; no third-target promise or deferral inferred |
| PLAN-NEXT | Assign the next bounded queue | 5 | Parent-to-child breakdown DONE 2026-10-20: all 36 original crosswalk rows now name an unfinished child, decisive proof and current dependency; original parent wording, child inventory, ten gates and parked budgets retained. Completed definitions/fixes are not reassigned; shared world/matrix/damage outcomes are not duplicated. The [working queue](../ROADMAP.md#next-three-production-deliveries) now prepares the Freight interface, Hauler manifest and navigator refusal cards with player result, ownership boundary, completion check, estimate limits and owner choices now resolved2026-10-21. All three cards are now completed with integrated playable checkpoints5097033/6bcbea3/c2c72a2; Beacon/Bomber approved qualification remains queued. No helm successor is scheduled. Each execution still requires its exact frozen task card; no whole-project estimate or gameplay completion implied |
| GUIDED-FINAL | Final-package Guided ordinary-input sortie, original 3/3 | 7 | GATED on final package; checkpoint3d92b91 ordinary3/3 DONE, earlier f676c50 retained. Do not repeat current accepted package unchanged or transfer it to a different final candidate |
| SANDBOX-RECOVERY | Original all-nine/54-waypoint recovery walk and reuse | 7 | PARKED; supported changed input/runtime cause required |
| SETTINGS-INPUT | Recover original runner, profile and logs | 7,8,29 | WAITING; original artifacts, no substitute Gate C |
| SETTINGS-RETURN | Original Settings/re-entry route, including gamepad return | 7,8,29 | GATED; SETTINGS-INPUT and supported correction |
| LIFE-VISIBLE | Four-cycle source phantom-geometry qualification | 7 | DONE; d7be01487, staged/headless source scope |
| LIFE-REUSE | Twelve-cycle source all-nine reuse qualification | 7 | DONE; d7be01487, staged/headless source scope |
| LIFE-PACKAGE-DEFINE | Name uncovered packaged ordinary-play lifecycle cases | 7 | DONE as the [finite packaged lifecycle boundary](#packaged-ordinary-lifecycle--life-package-define) below; definition only, source passes retained, no package route executed or successor selected |
| CONTROL-FINDINGS | List observed unresolved control/help defects | 8 | DONE as bounded source review: advertised Right Stick LOOK has no Player/Tow consumer; GAMEPAD-LOOK packaged99e79c3 separately. Existing mixed prompts/distance help/sprint fixes retained; physical-device acceptance remains open. |
| GAMEPAD-LOOK | Continuous right-stick local camera look | 8,29 | DONE in99e79c3: Player/tractor real camera, authored delta rate/deadzone/clamps/inversion and handoff clearing; full focused checks/paired checkpoint pass. Physical controller/full ordinary route remains open. |
| UI-BOARD-FOCUS | Keyboard Activity Board transition retains valid visible focus without engine signal-disconnection errors | 8,13,29 | PARKED/OPEN; diagnostic source preserved under `archive/withheld/ui-board-focus-20261018`, working branch deleted. key-only4.673s and changed tooltip4.954s components both NOT_REPRODUCED. Second establishes one visible embedded popup with matching root recipients and successful teardown. Original popup identity/connection-removal event unknown; no production cause/fix. Two-attempt cumulative9.627s, original investigation budget retained. Actual full-Main Beacon-home candidatea612ea686 recurs at37.713s/frame1233; page transitions but same two diagnostics, still no popup/removal identity. Actual-Main diagnostic now proves native/canvas coordinate mismatch: embedded-popup get_screen_transform omits rootstretch. Corrected reporting admits actual visible TooltipPanel/both native rootbindings/retainedExitfocus, then ordinary HUDclose exits0 with no original errors on unchanged runtime. Original pair NOT_REPRODUCED; no runtimefix/completion accepted. Source archived under archive/diagnostics/tooltip-hover-admission-20261020, scratch cleaned. Linux-release synchronous ActivityBoard capture b1b659d6e later passes shared BeaconEntry prefix44.456s: eight snapshots/two transitions,55hiddenPopupMenus/no visiblepopup, only unchanged SceneTree focusbinding. Original Home caller/extraobserverpayload absent; no error-emitting lifecycle captured. Actual popup/connection-removal identity in failing original journey remains missing; no further UI repair/retry selected. Exact full Home caller/observer replay5f2cafb94 now also has no original errors: eight transition snapshots,55 hidden PopupMenus/only SceneTree focus binding; UI cause remains unproved. Full route fails original300s deadline at independently identified controller mouse-quantization stall; Home alignment repair now passes the complete112.031s route on bc48b2a with all original guards, but establishes no UI cause. Diagnostic-only source bundled, owned scratch and duplicate ELF cleaned. |

### Station, fleet and combat children

Walking proof: complete the named ordinary walk/Interact route without rescue and preserve clearance. Service-motion proof: readable/safe implemented rail during walking/boarding. Craft acceptance: walk/board/launch, applicable role/weapon, damage/recovery, strict landing/exit/reuse and cross-craft/Main re-entry. Eventual fleet is **17**, of which nine are implemented and eight originals lack definitions. No “finish craft” implementation assignment is authorized by an acceptance row.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| WALK-CENTRAL | Central launch/return | 7,9 | UNSCHEDULED; exact production-roster route |
| WALK-AFT | Aft stairs/door/board | 7,9 | UNSCHEDULED; exact production-roster route |
| WALK-HABITAT | Ordinary hub→Habitat rest/wake/common room→hub plus usable restart controls | 7,9 | DONE in recorded ordinary scope; LOOP archive3707bc9 and RESTART archive29abe94. Final dressing/native/final-source gates remain separate; parked Sandbox unchanged |
| WALK-HABITAT-LOOP | Fresh normal Start Shift, hub→door→bunk sleep/wake→common room→same hub | 7,9 | DONE packaged3707bc9: actual archive ELF OS-XTest full route54.259s/163.231m, exact reservation/wake/commons/support/hub return, same Player. No scenario placement; hardware/final-source scope stays separate |
| WALK-HABITAT-RESTART | Normal quit while resting, distinct process with same data, fresh awake supported controls | 7,9 | DONE packaged29abe94: two normal UI exits/exit0, same actual data/distinct PID, fresh supported look/walk/tractor interaction68.756s under singleCAP300. No station pose or OS-kill claim; exact continuation below |
| HABITAT-BUNK-REST | Six production Habitat bunks offer actual local SLEEP/WAKE with supported return and lifecycle cleanup | 7,9 | DONE; packaged221f523. Six StationSeat-based bunks, focused134/full spine/Habitat/ship sleep checks and paired startup pass; no saved station pose or ship/recovery/network authority expansion |
| WALK-FREIGHT | Full Freight terminal/door/room/conserved-transfer/receipt-reload/same-ship return | 7,9 | Interface delivered509703300/checkpoint5097033; full ordinary route remains GATED on its frozen route and existing cold KIT-RELOAD failure. Automatic workflow approved2026-10-21. Existing Jovian automatic cargo delivery remains accepted in its own scope; KIT-RELOAD remains PARKED. [Concrete ordered handoff](#freight-terminals--physical-interface-and-existing-transfer-owner); no route selected |
| FREIGHT-TERMINAL-INTERFACE | Ordinary Freight terminal interaction bound to actual conserved cargo owners | 7,9,13 | DONE on509703300/checkpoint5097033: both actual-Main raw-E fittings, initial/saved/depleted/current-owner/re-entry/refusal checks and existing conserved/once-only cargo suite PASS; paired checkpoint/startups PASS. Existing6-kit source/berth capacity64/two-kit entitlement retained; full ordinary walk and cold KIT-RELOAD remain separate |
| WALK-FLEET | Fleet Dock access and all-shipped berth reuse, shared with CRAFT-ACCEPT | 7,9 | DEFINE runnable boundary; three assigned comb berths are Zenith/Halyard/Bulwark, but original all-shipped reach/reuse covers nine current craft through existing CRAFT-ACCEPT journeys. No threshold-only completion or duplicate Sandbox route; [scope and seam](#fleet-access-and-reuse--shared-acceptance-boundary) |
| WALK-ANNEX | Fresh normal hub→Annex console→hub with one actual restock | 7,9 | DONE source9af57671d;81.387s, same supported Player, kits5→6/one Annex update/Aft unchanged, disclosed pre-walk craft/repair fixtures; no whole-station closure |
| WALK-OBSERVATION | Observation supported return | 7,9 | OPEN/unqualified. Privatebae551d58 full route PASS54 goals/345.753m/60-frame view/home/normal Exit0/clean logs, but active-tooltip repair INCONCLUSIVE: original visible TooltipPanel not exercised. Later actual-Main baseline did not produce it. Candidate remains unmerged; all five unique commits/seven files preserved by verified bundle/patch/source archive and pushed archive/withheld/exit-tooltip-order-20261020; local/remote/tracking working refs deleted. Missing actual hover owner/pointer/window/foreground state and original visible tooltip/root bindings before a separately selected repair. Full integrated route acceptance retained. [Accounting](history/ROADMAP_DELIVERIES.md#tooltip-candidate-accounted-and-archived--unqualified--2026-10-20) |
| WALK-SALVAGE | Salvage three-component manifest | 7,9 | DONE in recorded current Linux-source ordinary scope: ACCESS9749f742c, INSPECT5189436f1, REVISITf7abac379. Actual hub approach/three grades/real-file publication/distinct-process restore/physical repeats/full retained-hub return accepted; original limits retained. Existing staged/memory-store checks remain separate; production Boot/OS-XTest/native/final-package gates remain. [Complete scope](history/ROADMAP_DELIVERIES.md#existing-salvage-durable-physical-revisit-qualified--2026-10-20) |
| WALK-SALVAGE-ACCESS | Hub→three inspection positions→hub by same supported Player | 7,9 | DONE9749f742c: all29outbound/29reverse goals and retained hub spawn;64assertions/103.697s/exit0, clean logs and unchanged inspection state. Two added existing-floor waypoints clear Annex roof columns; every original destination/.20arrival/240loops/4settle/300s retained. Source merged/pushed, owned scratch cleaned; prior121.841868s failures preserved. Source qualification via InputEvent/held actions, not OS-XTest/nativeGPU or publication/revisit. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-access-round-trip-qualified--2026-10-20) |
| WALK-SALVAGE-INSPECT | Ordinary three components and manifest publication after actual approach | 7,9 | DONE5189436f1: full normal hub approach, all3 actual inspections/authored grades and manifest via ordinary controls, independent real-file primary loads/exact slot/unrelated-data conservation, repeat console adds no transaction, all29reverse goals/retained spawn.92assertions/103.609s/OS0/cleanlogs; original .20/240loops/4settle/300s retained. Reviewed/merged/pushed, owned scratch cleaned. Source qualification only; fresh-process REVISITf7abac379 accepted separately. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-inspection-and-publication-qualified--2026-10-20) |
| WALK-SALVAGE-REVISIT | Durable fresh-process physical revisit without duplicate transaction | 7,9 | DONEf7abac379: exact accepted writer real XDG profile in distinct Godot process; primary3IDs/manifest read before Main; fresh normal Main restores them, normal recovery exit directly confirmed, ordinary walk back to retained hub then all29out/4physical repeats/29reverse/spawn. Every repeat preserves actualprimary payload/generation/grades; finalslot conserved.94assertions/107.025s/OS0/cleanlogs/.20/240loops/4settle/300s unchanged. First36.348s failure retained; one source-supported caller correction, no profile/recovery bypass. Reviewed/merged/pushed, owned scratch cleaned. Source qualification, broader Boot/native/final gates separate. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-durable-physical-revisit-qualified--2026-10-20) |
| WALK-VIP | VIP reception | 7,9 | PARKED; failed route plus repair, see working-roadmap failure summary |
| LIFE-TOW | Central tow during nearby walking/boarding | 9 | DONE in packaged9162fac/caller11c2332 ordinary scope:43.086m supported walking/five goals, actual Torrent boarding and90seatedframes; same service/seven movers advance clock/poses,745 consecutive samples, zero diagnostics. Rendered readability/native hardware/whole-station remain separate |
| LIFE-GANTRY | Freight gantry during nearby walking/boarding | 9 | DONE packaged2df8c31 ordinary scope:127.445m/13 settled goals,12.509m local walk/max10.297m from gantry, actual Jovian boarding/90seatedframes; same two movers clock/poses, home berth/OFFLINE/parked,1,668 consecutive samples/no diagnostics. Seat is distant; rendered/full-station/final remain separate |
| LIFE-ARM | Aft service arm during nearby walking/boarding | 9 | DONE packagedf2bf35a:15 settled goals/108.091m,18.303m local walk/max11.711m arm distance, actual Zenith boarding/90seated;1642 consecutive samples/three actual movers/current home/OFFLINE/parked. One actual controller step proof replaces unsupported blanket-speed assumption without changing ordinary bound/physics. [Original failures and accepted full result](history/ROADMAP_DELIVERIES.md#aft-service-arm--actor-proven-ordinary-route-accepted) retained; rendered/hardware/full station separate |
| LIFE-PATROL | Habitat patrol during nearby walking/boarding | 9 | DONE packaged ea8fe43:22 settled goals/171.602m,17.302m local/max9.944m origin distance, actual same-door candidate/E/OPEN-clear/return and distinct Torrent E→BOARDING/90seated. Same two actual drone roots/seed/defaults/home/OFFLINE/parked,2428 consecutive samples; all77Python/package/startups/audit/ONEroute PASS first attempt. [Frozen contract/full result](history/ROADMAP_DELIVERIES.md#habitat-patrol--ordinary-door-walking-and-torrent-boarding-accepted). Rendered/hardware/full station separate |
| STATION-RELATIONS | Name unresolved historical adjacency/elevation/ladder relationships | 9,36 | DEFINE; tied source anchors or precise missing evidence |
| STATION-CENTRAL-VIEW | One current source-tied Central operational-view defect | 9,12 | GATED; usable existing view/reproduction, capture stall parked |
| STATION-FINDINGS | Finite remaining presentation/living-station findings | 9,12 | Nine-branch/four-LIFE review roster defined below; source review found no supported new service/wayfinding gap. Habitat common-entry source8a6339b91 full-Main capture PARKED after180.842s/no PNG; no visual review/repair/acceptance. Other actual presentation findings remain OPEN; no automatic retry or replacement isolated-module proof. |
| BOMBER-ROLES-DEFINE | Bomber promised crew/navigation versus actual supported roles | 4,10,16 | DONE; pilot/payload implemented, additional crew/Nav semantics missing |
| BOMBER-ROLE-DECISION | Choose additional Bomber role/count, action and physical access | 4,10,16 | WAITING; precise interpretation needed, no approved scope reduction |
| CRAFT-GAPS-TORRENT | Torrent remaining authored components/roles | 10,11 | Definition DONE: no concrete required missing implementation found in bounded owners; craft acceptance OPEN, supported finding needed for implementation |
| CRAFT-GAPS-ARROW | Arrow remaining authored components/roles | 10,11 | Definition DONE: finite authored capability map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role found in bounded owners. Full craft/art/combat acceptance OPEN; exact product finding needed for repair. |
| CRAFT-GAPS-JOVIAN | Jovian remaining authored components/roles | 10,11 | Definition DONE: finite authored capability map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role found in bounded owners. Full craft/art/combat acceptance OPEN; exact product finding needed for repair. |
| CRAFT-GAPS-ZENITH | Zenith remaining authored components/roles | 10,11 | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. |
| CRAFT-GAPS-HALYARD | Halyard remaining authored components/roles | 10,11 | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. |
| CRAFT-GAPS-BULWARK | Bulwark remaining authored components/roles | 10,11 | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. |
| CRAFT-GAPS-CINDER-LIGHT | Cinder Light Interceptor remaining authored components/roles | 10,11 | Definition DONE: finite authored pilot/weapon/component map in COMPLETION_SCOPE.md; no concrete new required runtime/physical-role gap found. Full craft/art/combat/ordinary package acceptance OPEN. |
| CRAFT-GAPS-CINDER-HAULER | Cinder Cargo Hauler remaining authored components/roles | 10,11 | Definition DONE: finite hull/cabin/roles/travelling-weapon map plus explicit Hauler cargo-contract gap; forwarding bridge does not accept Hauler delivery. Full craft/art/combat/crew/cargo play OPEN. |
| CRAFT-GAPS-CINDER-BOMBER | Cinder Long-Range Bomber remaining authored components/roles | 10,11 | Definition DONE: pilot/payload/component map; additional crew/navigation decision and exact spent-payload policy now permits refill when pilot retakes seat; additional role remains unresolved. Full craft/art/combat/crew/recovery OPEN. |
| HAULER-CARGO-DEFINE | Name Hauler-specific conserved cargo play | 10,13 | Bounded contract/ordered production boundaries below; existing item/destination/phases retained. Owner chose shared existing Jovian/Hauler stock2026-10-21; physical access delivereda43ae4b, cargo delivery remains unaccepted. |
| BOMBER-REARM-POLICY | Define permitted spent-payload replenishment boundary | 10,11,31 | DECIDED2026-10-21: refill4 whenever pilot retakes seat. Existing detach/newsession source path is consistent by inspection; actual ordinary reboard qualification remains required. No explicit-service-only change. |
| WEAPONS-DEFINE | Actual craft/role to weapon acceptance roster | 11 | Definition DONE on a0d446645; current binding map in WEAPON_DEFINITION_CONTRACT.md, finite distinctions below. No missing runtime weapon type inferred; eight originals UNKNOWN/Bomber role decision retained |
| DAMAGE-DEFINE | Uncovered craft/role component-damage/recovery cells | 11,21 | Definition DONE on82a7564cb; COMPONENT_DAMAGE_MODEL_CONTRACT.md maps five IDs/all nine craft, real role exceptions, repair/reset owners and concrete remote row gap; no gameplay pass |
| ART-FINDINGS | Finite actual UI/animation/effect/lighting/terrain/weather defects | 12,15 | DEFINE; named before/after view and affected route |
| CRAFT-ACCEPT-TORRENT | Torrent full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-ARROW | Arrow full solo craft loop | 7,10,11 | Ordinary return/reuse DONEed1167b; named pilot precision-hit plus preserved two-flight home/OFFLINE exits/clear/reboard/UIquit DONE51257b3, actual archive120.991s. [Accepted scope](history/ROADMAP_DELIVERIES.md#arrow-precision-hit-and-return--shipped-on-51257b3). Broader combat/damage/recovery/crosscraft/Main/art/device/final acceptance remains GATED; no Sandbox/Defense closure |
| CRAFT-ACCEPT-JOVIAN | Jovian full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-ZENITH | Zenith full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-HALYARD | Halyard full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-BULWARK | Bulwark full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-CINDER-LIGHT | Cinder Light Interceptor full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-CINDER-HAULER | Cinder Cargo Hauler full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-CINDER-BOMBER | Cinder Long-Range Bomber full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| SPEC-TITAN | Titan evidence-bounded identity/capability specification | 10,36 | Modern proposal DONE in [Titan design](design/TITAN_IMPLEMENTATION_PROPOSAL.md); WAITING owner interpretation decision or tied model evidence. No implementation authorized or historical gate closed |
| BUILD-SPLIT-TITAN | Titan named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-TITAN, split before any implementation |
| CRAFT-ACCEPT-TITAN | Titan full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-VORTEX | Vortex evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-VORTEX | Vortex named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-VORTEX, split before any implementation |
| CRAFT-ACCEPT-VORTEX | Vortex full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-PARADOX | Paradox evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-PARADOX | Paradox named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-PARADOX, split before any implementation |
| CRAFT-ACCEPT-PARADOX | Paradox full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-KATANA | Katana evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-KATANA | Katana named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-KATANA, split before any implementation |
| CRAFT-ACCEPT-KATANA | Katana full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-PREDATOR | Predator evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-PREDATOR | Predator named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-PREDATOR, split before any implementation |
| CRAFT-ACCEPT-PREDATOR | Predator full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-DYNAMIC | Dynamic evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-DYNAMIC | Dynamic named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-DYNAMIC, split before any implementation |
| CRAFT-ACCEPT-DYNAMIC | Dynamic full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-UTOPIA | Utopia evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-UTOPIA | Utopia named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-UTOPIA, split before any implementation |
| CRAFT-ACCEPT-UTOPIA | Utopia full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| SPEC-SALYUT | Salyut evidence-bounded identity/capability specification | 10,36 | WAITING; evidence or explicit interpretation decision |
| BUILD-SPLIT-SALYUT | Salyut named hull/handling/access/role/recovery build cards | 10,36 | GATED; SPEC-SALYUT, split before any implementation |
| CRAFT-ACCEPT-SALYUT | Salyut full craft loop | 7,10,11,36 | GATED; its specified production capabilities delivered |
| COMBAT-INTERCEPTOR | Initial interceptor pressure encounter | 11 | DONE in checkpoint3d92b91 Guided starter-Torrent scope: same original3/3 ordinary route proves actual player fire/defender destruction, physical home landing/shutdown/exit and usable controls. [One shared proof, no duplicate delivery](history/ROADMAP_DELIVERIES.md#guided-checkpoint3d92b91--original-ordinary-route-accepted3of3). Other craft/encounter/damage/recovery requirements remain in their named owners |
| COMBAT-COURIER | Courier Intercept | 11 | COURIER-CLEAR first full original journey DONE4196ad0: ordinary route55.973s under300, initial defender alive through actual Courier kill/CLEARED before1400m, then defender defeat and strict home dock/OFFLINE/physical exit. Runtime damage-admission431aae retained; ordinary nonlethal preparation/readiness changes no combat rules. Paired checkpoint/strict startups/1525-entry audit/review GO; merged/pushed/owned cleanup done. [Separate bounded outcomes](#courier-intercept--bounded-outcomes) retain escape/two withdrawals/recovery/repeats/native requirements OPEN; full parent not closed |
| COMBAT-WING | Paired Wing Break | 11 | FAILED/open ordinary two actual player-weapon kills plus complete home/OFFLINE physical exit/UIquit. Latest9a68aa01f trial102.037s:8shots,0Wingdamagehits/kills, both opponents38health; prerequisite Heavy/Torpedo home journeys pass. Unique diagnostic source archived under pushed tag `archive/diagnostics/wing-ordinary-route-20261020`; branch/worktree removed, observer/selector/driver excluded from main. Independently accepted board-landing withdrawal fix shipped9e9d1be; it does not complete Wing combat. [Closeout](history/ROADMAP_DELIVERIES.md#wing-branch-accounted-landing-fix-shipped--2026-10-20) |
| COMBAT-WING-ADMISSION | Existing Wing becomes a genuine third solo board contract | 11 | DONE checkpointf671da9: on-foot arm/cancel, physical departure/registered source gate, real suppression/flank pair, solo/network refusal, both-destroyed objective with healthy-retirement abort, correct HUD/audio/no-credit lifecycle. Actual Main28/director151/board59/HUD8/audio11 checks, paired exports/startups/audit PASS. Component simulated clear disclosed; no full ordinary kills/home. [Result](history/ROADMAP_DELIVERIES.md#paired-wing-board-admission--shipped-on-f671da9) |
| COMBAT-PERIMETER | Perimeter Hold | 11 | PERIMETER-LIVE runtime/admission DONE fdae1cb: physical fourth-board contract, protected core/three live attackers,90s/>35%, HUD and lifecycle. Actual-Main admission, retained Breach recovery, staged objective and paired packages PASS; branch merged/deleted. Full ordinary weapon/home, failure/recovery, repeats/network/native remain OPEN. [Delivery](history/ROADMAP_DELIVERIES.md#perimeter-live-branch-finished--2026-10-20) |
| COMBAT-BREACH | Heavy Breach | 11 | Same ordinary sortie as PLAY-BREACH below; one successful route may satisfy both parents, without counting two deliveries. Additional supported damage/recovery/craft cases remain explicit; BREACH-INTERRUPTION earned-debt case DONE c78e0ac |
| COMBAT-TORPEDO | Torpedo Run evade/intercept/destroy/fail/abort | 11,23 | PLAY-TORPEDO supplies the first actual boat-clear/home sortie. Freeze evade/intercept, failure, abort and solo restoration separately afterward; one happy-path clear cannot close all cases or TORPEDO authority/restoration |

### Courier Intercept — bounded outcomes

Parent11 retains the whole encounter; these cards prevent one failed clear from
turning into an unbounded repair/qualification chain. Normal first entry already
exists: fresh Guided Torrent → actual four range kills → keep initial defender
alive → automatic courier dispatch after4.5 physics seconds. The initial defender
must remain alive until the selected courier outcome; killing it changes phase
and withdraws the scenario. All ordinary routes retain actual default controls,
same actors, live weapons and the original home landing/shutdown/physical exit.

| Card | One result and its decisive proof | Current boundary |
| --- | --- | --- |
| COURIER-CLEAR | Player destroys the actual runner before1400m; retained positive accepted/resolved source-ship/target/generation/sequence kill receipt plus director CLEARED, then clear defender and complete home. | DONE4196ad0. Complete original packaged journey55.973s/original300: same Player/ship/default sampler/tuning; defender alive17 through first dispatch and Courier CLEARED; actual source289859963540→target292779199297/gen1/seq15 lethal10/hull0 at0.817s/0.582% escape; then defender defeated/genuine return/strict occupied home contract+lease/OFFLINE/physical E exit, hull89/error0.17. Two feedback-bound nonlethal85→51→17 health/input records precede dispatch, with actual weapon-ready gating; no gameplay/AI/damage/timing changes. Initial41.436s overheat-related guard failure and all earlier failures retained. Source/checkpoint/113driver tests/three strict startups/1525payload audit/independent review/owned cleanup complete. No normal UI quit/gameOS0/separate supported walk/reload/repeat/native credit. [Delivery](history/ROADMAP_DELIVERIES.md#courier--full-first-intercept-and-home-journey-accepted--2026-10-21) |
| COURIER-ESCAPE | Actual live runner reaches original boundary with positive hull; director ESCAPED stands down all dispatched actors, then player clears defender and completes home. | UNSCHEDULED. The failed clear observed escape but did not complete this distinct home/stand-down contract; no acceptance transferred. |
| COURIER-WITHDRAW-PHASE | With courier actually running, destroy initial defender through real fire; normal RETURN_TO_YARD causes WITHDRAWN and stops courier/escort fire, then complete home. | UNSCHEDULED. Earlier Guided3/3 killed defender before courier dispatch, so it does not prove this live-withdrawal case. |
| COURIER-WITHDRAW-DISTANCE | Remain beyond the scenario's own700m origin radius for7 physics seconds while authorized; WITHDRAWN stands down courier/escort, then clear defender and complete home. | UNSCHEDULED. Observation must expose the actual director origin/grace without changing authority; escape,150s expiry and phase withdrawal cannot substitute. |
| COURIER-RECOVERY | One specifically named interruption/cold continuation preserves the intended safe context without stale courier/escort authority or duplicate outcome. | DEFINE before selection: name interruption boundary and existing save/recovery expectation; retain broader recovery ownership. No invented active-encounter resume guarantee. |

Only a separately selected card becomes executable: freeze clean source/package,
exact owners/commands, one ordinary CAP300/outer330 attempt and first-failure
stop. Preserve4.5s dispatch,82% distress,2.4s escort,1400m escape,700m/7s
disengagement and150s backstop. No direct damage, actor placement, shortened
limits or schema/validator family. The existing driver/observer/privacy tests
are the implementation seam; add the smallest behavior-specific checks.
Estimate one driver/observer route at30–60min implementation/review plus10–20min
checks/package/cleanup; split before90min. These are planning estimates, not
permission to restart a failed card's clock. First successful packaged clear
still leaves other craft, encounter, damage, recovery and parent 11 gates open.

### Freight terminals — physical interface and existing transfer owner

**Interface completed2026-10-21 on509703300; playable checkpoint5097033.**
The existing DispatchScreen and ManifestKiosk now own inventory-free
FreightJobTerminal interaction adapters. Ordinary E selects the existing job and
shows actual manifests/latest saved receipt, retaining automatic landing transfer.
Full default cargo suite176 assertions, terminal68, authority94 and startup privacy
checks PASS; strict three package startups and actual paired payload/archive audit
PASS. Actual Player input is exercised from staged endpoint positions in initial
and saved Main; this does not close full WALK-FREIGHT or distinct-process cold
KIT-RELOAD. Source/result review GO. [Delivery/failed attempts/limits](history/ROADMAP_DELIVERIES.md#freight-physical-terminal-interface-completed--2026-10-21).

The source definition below records the **pre-implementation** state.

Source definition2026-10-20 on801b38e7a, one medium bounded source mapper plus
root contract review; no edits to production, engines, tests or ordinary run.
This corrects the roster's former implication that physical Freight terminals
were implemented. The berth and existing automatic delivery are retained.

Actual production boundaries:
- JovianFreightBerth owns approach/apron/boarding/cargo-transfer/service-threshold/
  service-room/cargo-rack route markers and the ordinary ServiceAccess StationDoor.
  DispatchScreens and ManifestKiosk are StaticBody/Mesh fixtures without prompt or
  interact methods; they are not cargo adapters.
- scenes/world/modules/cargo_source_terminal.tscn has no production instantiation.
  cargo_destination_terminal.tscn is instantiated by nearby_sector_cluster.gd
  at the Cinder platform, not in the Freight station branch.
- GameFlow _initialize_cargo_delivery_composition binds the actual Jovian ship
  and Freight berth directly to CargoTransferAuthority. Existing job uses
  fabrication_kits, source capacity/initial6 and destination capacity64, transfers
  exactly2 on successful return landing through _complete_cargo_delivery_on_return.
  Existing accepted KIT-BOARD/DEPART/DELIVER are not missing production work.
- CargoTransferTerminal.bind_authority currently requires handle entity_id equal
  terminal_id and manifest_id equal its configured manifest. A physical adapter
  must resolve that actual ownership seam; do not alias an independent terminal
  as the ship, register a second stocked manifest, or mint extra cargo.
- Normal Player E candidate discovery/dispatch exists. Neither Activity Board
  navigation nor a new transfer/reward authority is required merely to expose a
  physical endpoint, but the chosen workflow must use the existing cargo owner.

One design question was presented with a concrete recommended workflow: physical
terminals select the existing job/show actual manifests and saved receipt, keeping
its automatic landing transfer; alternative is manual transfer after docking.
Owner chose the automatic-landing-transfer workflow2026-10-21. Retain conserved quantities, once-only durable
settlement and same-ship return. An inspect-only panel without the genuine transfer
journey cannot close WALK-FREIGHT. This decision concerns Freight/Jovian; it does
not implement Hauler stock custody; owner separately chose shared stock2026-10-21.

Ordered deliverables, not executable cards or fixed completion estimates:

| Deliverable | Production result and proof | Dependency / stop |
| --- | --- | --- |
| FREIGHT-TERMINAL-INTERFACE | Exact source/destination placement on existing Freight fittings; real prompt/ordinary E; current owner/manifest identity and honest enabled/refused feedback. Existing terminal/authority tests plus one actual Main interaction regression protect identity, range, re-entry and stock conservation. Meaningful accepted runtime checkpoint required. | DONE509703300/checkpoint5097033 with staged actual-Main raw input and initial/saved owner checks. Geometry/clearance and real inventory retained; full walk/cold reload remain separate. |
| Existing KIT-DELIVER plus physical terminal continuation | Actual ordinary walk to each endpoint, board the same Jovian, depart/complete the chosen legitimate transfer path; exactly6→4/0→2, one committed receipt/reward and usable home/physical exit. Inspect terminal receipt from actual owner/store, not a seeded complete flag. | Interface first; retain earlier accepted automatic owner unless workflow explicitly changes it. Freeze full same-candidate command/limits before execution; staged checks cannot replace it. |
| Existing KIT-RELOAD | Distinct process reads actual committed receipt/manifests without duplicate transfer/reward, and usable controls/terminal/ship remain. | Original30s/first-normal-frame timeout stays PARKED; reuse its named child and causal reopening condition. Do not create a parallel Freight reload with a larger cap. |
| WALK-FREIGHT full branch | Same supported Player hub→approach/apron→each terminal→ServiceAccess door/room/racks→same hub/ship; conserve cargo and verify the committed receipt including required cold reload. No rescue/teleports/shortened routes. | All above plus exact branch driver/observer handoff. Sandbox waypoint geometry is a route reference, not permission to rerun parked all-craft Sandbox. Shared Tooltip exit failures retain their own reopening conditions; no adjacent probe selected. |

The source finding is a missing production interface, not a successful walk,
new runtime defect reproduction, checkpoint or parent completion. Implementation
estimate remains unfrozen until terminal action/ownership is settled; split
before90min. Once chosen, prioritize the physical interface/runtime checkpoint
before adding ordinary-route telemetry. No new validator/evidence family.

### Remaining unmerged work

The [earlier 20-branch inventory](history/ROADMAP_DELIVERIES.md#remaining-branch-status-after-duplicate-closeouts--2026-10-20)
distinguishes three withheld gameplay fixes from 17 automation/diagnostic-only
candidates at that point and records each acceptance blocker. The older Breach probe and Jovian
syntax branch have verified exact-source successors and archived original histories;
their branches are removed. The retained Breach successor is now merged on c78e0ac
after full earned-debt interruption acceptance, leaving 19 remote candidates
(three gameplay fixes/16 automation at that point). Halyard BOARD is now
accepted and its branch removed too, leaving 18 non-main candidates (three gameplay
fixes/15 automation at that point). The superseded original Jovian exit caller
is now archived under a pushed tag and removed, leaving 17 non-main remote
candidates (three gameplay fixes/14 automation). Full Jovian exit remains OPEN.
Fifteen already-integrated local branches and their clean worktrees are also
removed. The five local-only exceptions are now accounted for and removed too:
cargo capture and durable supervision are integrated; original native/Sandbox
route tooling is superseded and archived. The failed settle-facing guard remains
withheld, with exact history under an archive tag; full Sandbox/recovery/reuse
remains FAILED/open. No local-only branch exception remains.
No new gameplay or release qualification follows from deleting those duplicate refs.

### Perimeter Hold — missing production integration

Definition DONE: the detached catalog had no production caller. Its90s/>35%
protect-asset objective differs from the director's two-guard `station_defense`
and the separate34s/1–2–1 Station Defense activity. Existing Breach marker has no
health; its two scatter craft and guided RangeOpponent do not implement the
catalog's three distinct actors.

**PERIMETER-LIVE runtime/admission is DONE on fdae1cb.** Existing candidate aa88b5a73
was integrated after main's shipped Wing, so Hold is fourth rather than third.
Actual-Main board/seat/thrust departure, dedicated health asset/three distinct
resolver actors, catalog 90s/>35% boundaries, HUD and synchronous cleanup pass.
Heavy/Torpedo alone retain credit/debt; saved offers 0–2 and new 3 are supported.
The shipped automatic-landing withdrawal guard is preserved.

All original Breach test bytes/assertions remain; the Hold admission case moved
intact into the existing Hold test's opt-in mode. Both keep 90s caps; original
Breach 48 assertions complete in 76.650s, Hold 19 pass. Default staged Hold 52 and the
existing director 153/asset 12/board 69/HUD 11/Wing 40 checks pass. Matching clean
Windows/Linux exports, three strict menu startups and actual package audit pass.
This is staged objective/lifecycle plus physical admission, not ordinary weapon
combat or a complete 90s home/reuse sortie. Ordinary weapons/home, recovery,
repeats, network and native/human requirements remain OPEN. Candidate merged and
pushed; branch deleted and owned scratch cleaned after preservation. Prior
363.897s/three failures remain recorded; new stages 378.870s, cumulative 742.767s.
[Original failures](history/ROADMAP_DELIVERIES.md#perimeter-hold-live-integration--implemented-but-parked)
and [accepted closeout](history/ROADMAP_DELIVERIES.md#perimeter-live-branch-finished--2026-10-20).

**Fleet handoff:** a SPEC closes with supported identity/capability facts,
explicit unknowns and any required owner interpretation. BUILD-SPLIT replaces
that craft’s placeholder with named production capabilities: each needs files/owner,
dependencies, player-visible result, focused proof, implementation/check estimates
and checkpoint requirement. Only a capability whose own prerequisites hold becomes
READY. Do not assign “build the complete ship,” assume a fixed task count per craft,
or estimate a whole build before this split. Titan’s existing decision remains
WAITING; the full CRAFT-ACCEPT journey is preserved after capability delivery.

### Ordinary Habitat journey — finite acceptance contract

Definition on32d773487 after packaged221f523 station-bunk delivery. LOOP is now
accepted on archive 3707bc9:54.259s/163.231m through ordinary OS input, no
scenario placement. RESTART is accepted on archive29abe94:68.756s, same profile,
distinct processes, real UI quits and fresh supported tractor interaction.
WALK-HABITAT closes these two normal outcomes on their recorded sources. Final packaged dressing/native/device requirements keep their own gates.
No additional runtime gap was established by this source map.

**WALK-HABITAT-LOOP** starts in fresh production Main and uses normal Start Shift,
movement/look and Interact. No teleport, direct transform/velocity assignment,
forced sleep/door/control flags, per-waypoint relocation or rescue is permitted.
Turn through actual input; observe current target discovery rather than invoking
the interaction coordinator directly. Keep one live Player throughout.

| Leg | Authored target / required observation |
| --- | --- |
| Hub start | PlayerSpawn≈(-8.5,0.18,11), normal camera/controls and supported walking; retain this actual starting region as the return target. |
| Starboard approach | Reuse the obstacle-aware circulation witnesses (6,13.5)→(34.8,13.5)→(34.8,15.5)→(43,15.5)→(46,15.5), expressed as world X/Z. Totes occupy z15.05–15.85 and cabinets x36.8; a direct z15.5 line is not presumed clear. The fresh hub connection still needs actual live proof. |
| Pressure doorway | Initially closed HabitatSpine/MainAccess≈(49.72,0,15.5); actual proximity/facing candidate, separate Interact press/release, door opens and the same Player crosses its physical threshold. |
| Bunk | BunkAlcove01/StationBunkInteraction; actual wake point Habitat-local(-2,0.04,5.1)≈world(54.1,0.04,17.5). Reach by walking, face/discover it, Interact sleeps with its exact reservation; released/repressed Interact wakes, clears reservation and restores supported locomotion. No borrowed ship/crew/hatch claim. |
| Common room | Return to central circulation then cross RouteCommonEntry≈(67.65,0.15,15.5), with x≈67.8 an existing threshold witness. Require actual observation-common occupancy and physical support. |
| Hub return | Reverse the physical corridor/doorway and obstacle-aware starboard route to the original hub region, retaining normal camera, walking and interaction. No rescue/snap or substituted staged return. |

These are source-authored witnesses, not a newly accepted unobstructed polyline.
Use existing Player/StationDoor/StationBunk/GameFlow input and reservation owners.
The Habitat origin is(49,0,15.5), yaw+π/2; its floor0 meets the station floor−0.02
within the existing seam contract. Runtime collisions and supported movement
must be observed, rather than inferred from these coordinates.

Freeze one source/package and existing driver invocation before executing;
use one300s whole-loop cap, stop on complete route or first failure. Extend the
existing ordinary-input driver/observer only as required for this full loop,
without replaying the unrelated parked all-craft Sandbox route. Complete-loop
acceptance uses the existing external OS-input path on owned isolated Xvfb with
explicit x11 and Dummy, independent abort, input/cursor release and process
cleanup. Headless fixtures can support focused regressions; they do not replace
this ordinary-input journey. Rendering/device feel retain separate gates.
A failure retains the whole frozen route; diagnose/repair only its concrete
production owner and never narrow the accepted journey to a staged subcase.

**WALK-HABITAT-RESTART** is a separate normal-restart outcome. Freeze normal UI
quit while occupying that real station bunk after ordinary admission. Confirm
accepted durable context and orderly session/safe-start closure, reap the game,
then launch a distinct process with the same private real-file profile and normal
Begin Shift. Require a fresh awake/unseated, collision-supported Player, no old
bunk reservation/sleep/crew/ship claim, and ordinary look, walking displacement
and interaction at the supported safe station start. Use one300s cap for the
whole quit/restart operation; no new timeout following a failed attempt.

Current `_capture_solo_safe_recovery_context` admits saved rest only for ShipBunk.
StationBunk sleep attempts `{mode:unavailable}` publication; accepted commit
makes it durable, while refused writes retain the previous preference/retry.
Cold normal start therefore promises supported awake station controls, not the
old Habitat pose, bunk lease or sleep. This definition adds no station save mode.
Normal restart does not close OS-kill/interruption promises: those stay in the
existing RECOVERY-KILL family. A rejected publication or unavailable startup is
a real failed boundary, not permission to fabricate a saved record or claim.

Existing [Habitat integration](../tests/habitat_integration_test.gd) starts its
traversal at(43,0.18,15.5), returns only to x47.8 and separately stages the bunk
wake point. Its accepted134/203 rest/full results retain that exact scope.
[Native sortie driver](../tools/release/run_native_sortie.py) and
[read-only observer](../scripts/diagnostics/native_sortie_observer.gd) supply the
existing obstacle-aware circulation/door input seams; the guarded habitat-loop
selector is delivered in3707bc9; habitat-restart is delivered in29abe94.
The latter requires both normal UI exits, actual clean markers, independent
actual-file preservation and cold supported look/walk/tractor admission/exit.
Preserve all54-waypoint Sandbox requirements and its original failed300s record.
[GameFlow](../scripts/game/game_flow.gd) `start_shift`,
`_refresh_interaction_targets`, `_on_interact_requested`,
`_capture_solo_safe_recovery_context` and orderly shutdown own the real behavior.
The parked full resume suite remains parked. Runtime changes, if actually
required, need focused regressions and a fresh checkpoint; qualification alone
does not require an identical rebuild or close native/human/full-parent gates.

### Component consequences and acceptance boundary

DAMAGE-DEFINE source inventory on `82a7564cb` is consolidated in
[the existing damage contract](COMPONENT_DAMAGE_MODEL_CONTRACT.md#actual-consequences-and-remaining-qualification).
Finite uncovered work is shared by parents11/21:

| Outcome | Exact scope / status |
| --- | --- |
| NET-COMPONENT-ROW | DONE39a2ad709, packaged. Actual retained row now uses accepted host facts with source/role/lifecycle fences; local HUD29/30, pose216 and Main ENet382 pass. Original compile failure and one annotation repair retained; full parent OPEN. |
| NET-COMPONENT-POWERS | DONE packaged330a39c: actual host per-craft trio reaches retained observer HUD; legacy/order/local/terminal lifecycle preserved. Existing codec bounded-full fallback fixes the observed12408-byte delta without changing ceiling/values/schema. Pose302/MainENet382/Halyard70/localHUD104/codec/paired package gates PASS; [both failures, repairs and full result](history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted). Broader parents remain OPEN. |
| Existing full-craft/role recovery acceptance | Preserve existing CRAFT-ACCEPT and NET-DAMAGE scenarios; nine-craft parity is not every role/contact route. No new Cartesian matrix. |
| Missing-original components/roles | UNKNOWN for the eight missing originals; original specification prerequisites remain. |

### Weapon binding and acceptance boundary

WEAPONS-DEFINE source inventory on `a0d446645` (2026-10-18) resolves the actual
nine-craft roster. The primary [binding map](WEAPON_DEFINITION_CONTRACT.md#current-registration-map)
is maintained in the existing weapon contract. Eleven actual craft/role bindings
include both Halyard roles sharing one weapon and Bulwark's distinct gunner.
Policy-only crew entries are not weapons; eight missing originals remain UNKNOWN,
and Bomber's additional crew/navigation interpretation is still WAITING.

The finite distinctions below are qualification selectors, not ten new missing
implementations or ten copies of every encounter. Existing focused passes retain
their recorded scopes; none was rerun by this definition.

| Case | Binding-specific finish | Existing owner/check anchor |
| --- | --- | --- |
| WEAPON-TORRENT | Guided range profile in the two named phases versus authored combat profile; actual registered damage | GameFlow profile selection; weapon_definition_migration_test.gd |
| WEAPON-ARROW | DONE named pilot-hit qualification checkpoint51257b3: one native timed F press, fresh source1102/precision-emitter/sequence0/receipt1, actual DRONE-01 health100→76/24damage, attitude restoration10.626s within25s and full two-flight return/reuse/UIquit120.991s withinCAP300. Broader common combat/craft gates remain open; two earlier failures/cumulative558.746s retained. | [Accepted route and exact reopening fact](history/ROADMAP_DELIVERIES.md#arrow-precision-hit-and-return--shipped-on-51257b3); existing observer/driver/tests and unchanged Arrow/HeroShip/GameFlow combat chain |
| WEAPON-JOVIAN | Actual pilot heavy-cannon selection/damage through the common chain | Jovian resource, HeroShip, GameFlow; migration/common combat checks |
| WEAPON-ZENITH | Actual pilot repeater selection/damage through the common chain | Zenith resource, HeroShip, GameFlow; migration/common combat checks |
| WEAPON-HALYARD | Both pilot and admitted gunner use the same lance/heat/cooldown; real damage beyond a request receipt | Halyard crew consumer and HeroShip; existing gunner gameplay test stops at emitted request; attempted actual-hit extension is parked at ordinary seat admission |
| WEAPON-BULWARK-PILOT | Actual pilot sustained-pulse binding through the common chain | Bulwark pulse resource, HeroShip, GameFlow |
| WEAPON-BULWARK-GUNNER | Charged limited-ammo hitscan, component gates/revalidation and accepted-submission debit | Bulwark crew consumer; bulwark_crew_gunner_gameplay_test.gd; not Picket opponent travel |
| WEAPON-CINDER-LIGHT | Runtime repeater definition and inherited live heat/cadence | cinder_light_interceptor_combat_production_test.gd |
| WEAPON-CINDER-CARGO | Inherited heat plus actual moving bolt and terminal damage; no instantaneous replacement | cinder_cargo_mass_driver_bolt_test.gd, MassDriverBoltPool and GameFlow |
| WEAPON-CINDER-BOMBER | Fire edge/pulse suppression, four-round cooldown/wing refusal, real terminal or harmless expiry and generation cleanup | cinder_bomber_payload_integration_test.gd, payload authority/projectile/adapter |

**Common original Phase 6 acceptance remains shared:** command/source ownership,
profile/cadence/lifecycle validation, first obstruction and registered endpoint,
distinct miss/world/non-damageable outcomes, friendly/self refusal, once-only damage/score, reverse
receipt arrival, saturation/recycle/abort, lethal/nonlethal presentation/audio
chronology, detach/re-entry/reset/regeneration, applicable native legibility/mix
and restored packaged loop. Reuse existing resolver/authority/pool checks before
adding coverage. The six original COMBAT encounters remain separate outcomes;
this map does not generate a craft×encounter matrix or qualify full fleet combat.

No new runtime weapon was shown absent by the inspected roster. Resource-only
beam support is not a delivered beam, nor proof that one was promised. Generic
converter ammunition refusal does not erase existing Bomber/Bulwark ammunition.
HALYARD-GUNNER-DAMAGE is DONE on c28f7ffa3. The unchanged original route passes
49 assertions52.341s on its declared input-only display: exact gunner admission,
remapped FIRE, one actual52damage commit through GameFlow/live authority/resolver/
production adapter, then stand/walk/helm return/reseat/replacement cleanup.
Passive capture explains the earlier null candidate: headless mouse mode stayed
visible, facing never changed, and the chair remained behind the player despite
actual overlap. PrivateXvfb/explicitx11/Dummy/dummy renderer permits capture and
chair aim becomes1.0; no gameplay repair or closer-walk variant was needed.
Original exterior/registered-target fixtures remain disclosed. This is source
qualification, not OS-XTest/network/native-GPU or whole combat acceptance.
Original two failed routes103.872s and new headless failure51.925s are retained;
selected new stages120.306s include compile and successful52.341s, not new feature
counts. Caller-only source merged/pushed; current3767687 runtime unchanged, no
identical export. Owned scratch cleaned; original failed archive retained.
[Exact scope and cleanup](history/ROADMAP_DELIVERIES.md#existing-halyard-gunner-damage-qualified-on-its-declared-input-display--2026-10-20).

### Activities and solo-world children

First-play proof: ordinary outbound/start/activity, once-only durable reward and home return at canonical distances. The accepted one-shot HULK route is not reassigned as missing gameplay. Repeat/write/save scenarios are instantiated only after their finite uncovered lists are known.

Select one milestone from the [first-play handoff](#activity-first-play--bounded-handoffs),
not an entire row as an implementation assignment. Milestones can be accepted
individually, as KIT-BOARD/DEPART/DELIVER already demonstrate; PLAY-* closes only
when the complete same-candidate ordinary journey is proven. A staged integration
test is an owner/regression anchor, not a runnable ordinary route.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| PLAY-RACE | Checkpoint Race first full ordinary play | 13 | UNSCHEDULED; ordinary board/depart/approach → production countdown and ordered race checkpoints → one durable generation reward → actual home dock/usable exit. Driver selection/adaptation required; retained Race timeout is not authorized for retry |
| PLAY-THREADING | Asteroid/debris Threading first full ordinary play | 13 | Driver definition DONE; execution GATED on unresolved UI-BOARD-FOCUS at shared Activity Board transition. Full30m entry→five physical gates→durable reward→landing-unlocked actual home/usable exit remains unproven. No renamed retry or synthetic checkpoints; [readiness/owners/full contract](#threading-complete-first-play--driver-readiness) |
| PLAY-PATROL | Platform Patrol first full ordinary play | 13 | UNSCHEDULED; name relay_sweep or platform_sweep → approach/start → five authored checkpoints with2s physical station-keeping each → branch reward/home dock/exit. Freeze one branch first; other branch remains uncovered and retained Patrol failure stays parked |
| PLAY-JOVIAN-KIT | Jovian kit delivery first full ordinary play | 13 | Ordinary board/depart/deliver DONE through28a5e354e;79.213s strict home return, two kits/single reward/usable exit. Distinct-process reload remains unqualified after strict30s timeout; no whole-parent closure |
| KIT-BOARD | Ordinary offline cargo selection and Jovian pilot boarding | 7,13 | DONE source62bc7c823;66.158s, real menus/walk/local pilot/occupied berth, cargoIDLE0/source6/destination0 manifests; no departure |
| KIT-DEPART | Real departure automatically starts cargo, then ordinary brake | 13 | DONE sourceb91019562;70.350s, real5m/lease release/ACTIVEg1/brake≤.5m/s1s/original180s |
| KIT-DELIVER | Strict home landing transfers2 kits/pays once; usable exterior exit | 13 | DONE28a5e354e;79.213s actual dock/lease, COMPLETEDg1 kits4/2, one transfer/reward, automatic OFFLINE/authored exit/supported walk≥.5m |
| KIT-RELOAD | Distinct process reloads actual completed store without duplication | 13,31 | PARKED/open; originalstrict30s includespreload. Mainready/restoreaccepted27.762s/pausedfalse; firstordinaryphysics/process pair incomplete beforedeadline, full60tick continuation unqualified. Bounded sourceaudit2026-10-20 finds standardSceneTree waits/no callerpause error/no concrete currentstartuprepair. Trace lacksafterphysics/beforeprocess boundary, so exactfirst-framecost unlocalized. No corrupt/duplicatecargo observed; no rerun/probe/longercap/preloadclockmove selected. Source archive/withheld/jovian-reload-boundary-20261018 retained. |
| PLAY-CINDER-SUPPLY | Cinder platform supply first full ordinary play | 13 | DONE9ed9a0709, packaged checkpoint9ed9a07. Complete ordinary native-input journey216.291s under original300s/activity120s: all13+6+6+5 and home walking goals, actual terminal transfer1/source2→1/destination0→1, exactly one saved credit, duplicate refusal, exact protected pretransfer/paid/repeat/home files incl raceg1, physical reboard/home dock/OFFLINE/authored exit/supported1.234m walk/normal UI OS0. Independent full-scope review GO, three strict startups and1525-entry Windows/Linux payload audit PASS. Earlier failures retained; real boarding old-package RED/source26-check GREEN identifies missing remote-sortie continuation. Merged/pushed, no new branch/worktree; own scratch removed. Separate four cargo lifecycle failures, repeat/restock/Hauler policy and native hardware/human gates remain open |
| PLAY-MINING | Mining/extraction first full ordinary play | 13 | FAILED/PARKED candidate20bd1ab: single archive route53.444s reaches real Cinder approach then strict-stops on Activity Board focus-disconnection errors, before mining/return. Source unmerged under `archive/withheld/mining-first-play-20261018`, working branch deleted/checkpoint withheld; UI-BOARD-FOCUS causal repair required before reopening; original CAP300 unchanged |
| PLAY-SCAN | Structure Scan first full ordinary play | 13 | UNSCHEDULED; ordinary approach within24m → actual4s physics scan → one discovery/payment entitlement → home dock/usable exit. Existing full Scan failure stays PARKED; no unchanged retry selected |
| PLAY-BEACON | Beacon Traversal first full ordinary play | 13 | DONE bc48b2a: complete original ordinary journey112.031s within300s. Four physical beacons/one durable reward/60 stable ticks, actual safe RangeHeader crossing at hull100, four range targets/interceptor defeated, strict occupied home dock/OFFLINE/one native L and E/same-Player supported0.969m walk. Original Home caller restored with fine mouse correction at demonstrated quantization stall; all original guards retained. Independent review, paired checkpoint/three strict startups/1525-entry audit PASS; merged/pushed/owned cleanup done. Earlier settlement e06550e retained; archived37.713s UI failure and307.042s stalled route retained. UI cause remains unresolved; no normal-UI-quit/cold-restart/repeat/native/human acceptance. [Full result](history/ROADMAP_DELIVERIES.md#beacon--complete-original-home-journey-accepted--2026-10-21) |
| PLAY-CONVOY | Convoy Escort first full ordinary play | 13 | UNSCHEDULED; departed piloted craft enters4m rendezvous → escort actual retained-Main tender through route/threats to safe arrival → payment/home dock/exit. Preserve90s timeout and42m/3s separation rules; parked Convoy failures are not reopened |
| PLAY-DEFENSE | Station Defense first full ordinary play | 13 | OPEN. Runtime autonomous-flight escape defect fixed/shipped3767687: five focused suites, three strict packaged startups, actual payload audit and independent scoped review PASS. Full ordinary caller0b11486e0 remains withheld: boarding/departure/one actual kill, aborted near34s; no payment/home/reset/nextDeploy/UIexit. First kill about30s leaves less than remaining10.5s authored delays; a feasible ordinary combat plan is required before full rerun. Clock-start owner choice is pending; current board-start34s remains until answered. Original four kills/once payment/home/Reset/nextDeploy/UIexit and34s/CAP300/outer360 retained. Prior failed source/results preserved; owned scratch cleaned. [Runtime fix and limits](history/ROADMAP_DELIVERIES.md#defense-autonomous-flight-boundary-fixed-and-checkpointed--2026-10-20) |
| DEFENSE-PHYSICAL-INTERACTION | Physical board E Deploy/status/reward-retry/terminal Reset | 13 | DONE checkpointa59127c: actual Main15/full placement62, paired exports/three strict startups/actual PCK audit PASS. Existing owners, debt/refusal/separatepress/range/facing/armed gates and whole34s preserved. Original test parse16.381s + one explicit-int correction retained, cumulative334.765s. Staged pose/terminal/refusal fixtures disclosed; full ordinary combat/home separate. [Result](history/ROADMAP_DELIVERIES.md#station-defense-physical-interaction--shipped-on-a59127c) |
| PLAY-BREACH | Heavy Breach first full ordinary play | 13 | UNSCHEDULED; on-foot arm posted Heavy → board/depart combat-capable craft → destroy charged picket while protecting objective → one payment → home/dock/on-foot next posting. Existing staged production route is not actual combat; earned-debt interruption case DONE c78e0ac |
| PLAY-TORPEDO | Torpedo Run first full ordinary play | 13 | UNSCHEDULED; reach Torpedo posting through normal board rotation → arm/board/depart → evade/intercept live seekers and destroy actual boat → distinct payment → home/dock/on-foot next posting. No direct scenario selection or skipped Heavy prerequisite |
| HUD-RACE | Race durable reset/select/start/fresh-Main UI | 13 | Source review already found no concrete discrepancy; no edits/runs or ordinary acceptance. Do not repeat unchanged source triage; full qualification remains unscheduled |
| HUD-PATROL | Patrol durable reset/select/start/fresh-Main UI | 13 | Source review already found no concrete discrepancy; no edits/runs or ordinary acceptance. Do not repeat unchanged source triage; full qualification remains unscheduled |
| HUD-CARGO | Cargo durable reset/select/start/fresh-Main UI | 13 | Supply-status child DONE0c2dc2e: depleted hold reports insufficient kits after reset/reselection; cargo127/nearby HUD13 and paired checkpoint pass. Broader durable UI/restart remains open; KIT-RELOAD stays parked |
| HUD-CONVOY | Convoy durable reset/select/start/fresh-Main UI | 13 | Restored-objective discrepancy DONE on checkpoint3d92b91: cold/wrong-craft saved escort shows paused guidance, accepted craft rebind restores live progress; existing retained-feedback20 assertions pass. Wider durable reset/select/start/full ordinary Convoy scope remains open; parked save suite not reopened |
| ACT-WRITES-DEFINE | Uncovered activity/write-boundary cells | 13,31 | DONE definition only; finite durable owner/boundary map below, with terminal-only owners distinguished; exact-package/real-file/ordinary recovery acceptance remains open |
| BOOT-BREACH-OWNERS | Physical Heavy Breach board has exact production owners before gameplay | 9,11,13 | DONE packagede3d1ada; two exact old owner failures, final full startup/48-check production route and strict paired checkpoint pass; earned-debt interruption transaction DONE c78e0ac |
| BREACH-INTERRUPTION | Exported Heavy Breach real-file earned debt/kill/recovery/paid replay | 13,31,32 | DONE c78e0ac: source and exact archived Linux executable each complete genuine earned unpaid terminal, actual owned kill/reap, distinct normal Resume/real pilot/production exit/physical payment, exact same-document atomic receipt+ack and third cold paid replay. Privacy/compile/paired exports/strict startups/audit PASS; branch merged/deleted. All original 249.405s failures retained; ordinary combat/active-combat restore/native scope separate. [Delivery](history/ROADMAP_DELIVERIES.md#breach-interruption-branch-finished--2026-10-20) |
| ACT-REPEAT-DEFINE | Exact applicable ten-run activity scenarios | 13 | DONE definition: all twelve activities classified below; two cargo routes retain explicit stock-policy gates, Heavy/Torpedo preserve alternating physical board. Measurement/deadline freeze and first-play gates remain; no execution accepted |
| REPEAT-RACE | Ten same-world Checkpoint Race completions through actual ordered checkpoints, payment and accepted reset; next run starts usable | 13 | GATED on PLAY-RACE and a frozen resource-baseline/deadline contract; existing source passes retained |
| REPEAT-BEACON | Ten same-world traversals of all four authored beacons in order, accepted payment/reset and usable next run | 13 | GATED on PLAY-BEACON and frozen resource-baseline/deadline contract; no synthetic beacon submission as ordinary-route proof |
| REPEAT-SCAN | Ten same-world scans from actual approach, full four-second physics scan, existing payment/discovery/reset and usable next run | 13 | GATED on PLAY-SCAN and frozen resource-baseline/deadline contract; existing full Scan failure remains PARKED, no retry selected |
| REPEAT-THREADING | Ten five-gate Asteroid Threading completions with accepted payment/reset | 13 | GATED on PLAY-THREADING and measurement/deadline freeze; source reset/save coverage retained |
| REPEAT-PATROL | Ten ordered station-keeping patrol completions on the frozen authored branch, then usable next start | 13 | GATED on PLAY-PATROL and measurement/deadline freeze; record relay/platform branch explicitly; one branch does not qualify the other |
| REPEAT-JOVIAN-KIT | Ten real two-kit delivery/paid reset cycles without invented stock | 13 | GATED on legitimate stock replenishment/cycling policy and measurement/deadline freeze; initial6 kits only fund3 deliveries, KIT-RELOAD stays PARKED |
| REPEAT-CINDER-SUPPLY | Ten real one-crate platform delivery/paid reset cycles without invented stock | 13 | GATED on PLAY-CINDER-SUPPLY, stock/capacity policy and measurement/deadline freeze; initial source2/destination capacity8; Hauler stock choice remains unresolved |
| REPEAT-MINING | Ten real six-second extractions, each acknowledged once and reset durably | 13 | GATED on PLAY-MINING and measurement/deadline freeze; capacity receipt is not ore/currency inventory |
| REPEAT-CONVOY | Ten real safe-arrival escorts with once-only payment and production reset | 13 | GATED on PLAY-CONVOY and measurement/deadline freeze; retained-host/actor lifecycle and original failures remain |
| REPEAT-DEFENSE | Ten fresh physical-board deployments, full three-wave clears, payment and reset | 13 | GATED on PLAY-DEFENSE and measurement/deadline freeze; wave recovery is not another fresh completion |
| REPEAT-BREACH | Ten cleared Heavy Breach postings through ordinary board rotation | 13 | GATED on PLAY-BREACH and measurement/deadline freeze; alternate Torpedo postings cannot be skipped; BREACH-INTERRUPTION earned-debt case DONE c78e0ac |
| REPEAT-TORPEDO | Ten cleared Torpedo postings through ordinary board rotation | 13 | GATED on PLAY-TORPEDO and measurement/deadline freeze; ten mixed sorties do not satisfy ten of either scenario |
| TRAVEL-LIMIT | Numeric ordinary nearby-travel envelope | 13 | DECIDED2026-10-21: Beacon outbound maximum60s unpaused monotonic elapsed, existing exact start/stop/route unchanged. Timing implementation/qualification pending; return and other routes remain open. |
| HULK-REVISIT | Home-return/reload/revisit retains restored bus and single claimed cell | 13 | PARKED/open; original300s unchanged, failed source archive/withheld/hulk-revisit-departure-20261017. Bounded raw/source audit2026-10-20 confirms458consecutive revisit samples/47.393m ordinary supported movement, samePlayer, authored5.8walk/9.2sprint; no interior stall established. Global deadline expires midroute beforefreshbreaker. No relevant changedproductionseam/supportable correction found; missing per-stage monotonicwalltimestamps tolocalize cost. No rerun/probe/capchange selected. |
| EMBER-SOURCE-ABANDON | Integrated physical Ember abandonment/home return | 1,14 | DONE; e85157b4d, MemoryFilesystem, original exact31 |
| EMBER-OBSERVER | Native package observer production capability | 1 | DONE; 4270d71 source capability and startup-qualified checkpoint |
| EMBER-NATIVE-SMOKE | Native observer normal-window-close smoke | 1 | PARKED; failed fixture/repair and priority review retained |
| EMBER-PACKAGE-ABANDON | Packaged ordinary physical abandonment/home return | 1,14 | GATED; supported OS-input route, old external-driver path UNSUPPORTED |
| WORLD-ABANDON-DEFINE | Applicable Aurora/Rime abandonment and Ember reuse/durability cases | 1,14 | DEFINE; explicit physical/durable outcomes, source pass retained |
| WORLD-SAVE-DEFINE | Uncovered world survey/reward/reboard/visit disk boundaries | 14,31 | Ember first-relay safe-yard contract defined and exact-package cut accepted below; other Ember/Aurora/Rime boundaries remain DEFINE, no whole-family closure. |
| WORLD-SAVE-EMBER-FIRST-RELAY | Cold safe-yard recovery retains first-relay progress and later pays the original survey once | 14,31 | DONE on exact archive923d7b326/caller6112944d0: saved unpaid relay, real SIGKILL/reap-9, distinct Boot Resume0, exact runtime boundary, safe yard/fresh boarding/attachment1→2/original completion and once-only receipt0→1, zero diagnostics. Correctly staged external metadata; no gameplay/predicate change/tolerance. Original300s/game/660s outer and317.447268s failed costs retained; new wall interval308.992s. [Accepted result](history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-recovery--exact-package-accepted--2026-10-20). Canonical outbound/normal controls/native GPU NOT_RUN, standing-pose restore NOT_SUPPORTED; current/final-package and broader world gates remain open. |
| WORLD-EDGE-DEFINE | Applicable solo cancellation/refusal/failure/repeat cases | 14 | DEFINE; exact original cases and route limits |
| SOLO-EMBER | Ember canonical physical survey round trip | 14 | GATED; freeze uncovered candidate/scenario, prior source passes retained |
| CONTENT-EMBER | Ember finite remaining authored content/presentation findings | 15 | Definition DONE on 7c0bc2967: no missing implementation identified in the inspected authored-content scope; see boundary below. Full ordinary/repeat/shared/hardware qualification remains open |
| SOLO-AURORA | Aurora canonical physical survey round trip | 14 | GATED; freeze uncovered candidate/scenario, prior source passes retained |
| CONTENT-AURORA | Aurora finite remaining authored content/presentation findings | 15 | Definition DONE on 9d2d467e0: no missing implementation identified within inspected authored-content scope; see boundary below. Qualitative adequacy and existing journey/visual/hardware acceptance unproven |
| SOLO-RIME | Rime canonical physical survey round trip | 14 | GATED; freeze uncovered candidate/scenario, prior source passes retained |
| CONTENT-RIME | Rime finite remaining authored content/presentation findings | 15 | Definition DONE on 30968aeda: no missing implementation identified within inspected authored-content scope; see boundary below. Existing ordinary/shared/visual/hardware acceptance remains open |

### Ember authored-content boundary

CONTENT-EMBER source comparison, 2026-10-18, on `7c0bc2967`: **no missing
implementation identified within the inspected Phase 10.4 authored-content
promise**. This closes the definition only, not parent 15 or the whole-world loop.
No engine, capture, native smoke or journey test was run.

| Original criterion | Production owner inspected |
| --- | --- |
| Recognisable orbital silhouette | `ember_moon.tscn` body and `ember_moon_authored_scene.gd::_configure_orbital_landing_datum_cue`; streaming bootstrap loads the actual authored scene. Visual judgement remains unqualified. |
| Substantial landing region | `ember_caldera_landing_region.tres`; authored scene supplies the 96×96 m supported landing area and surrounding terrain/collision. |
| Multiple navigable landmarks | Authored scene contains rack/relay/gantry/bunker and dynamically composes lava tube, survey mast and wrecked lander. |
| Surface routes | Authored scene supplies pad-to-staging and chevron routes to the three additional landmarks. |
| Activities/rewards via existing authorities | Relay survey plus `ember_caldera_expedition_activity.gd` errands; `ember_planetary_surface_production_binding.gd` binds ActivityDirector, planetary reward adapters and ordinary trailhead interaction. GameFlow installs the intent sink; surface-loop binding forwards real position/reward progress. |
| Recoverable failures | Errand abandonment leaves visit/craft/return intact; `planetary_journey_coordinator.gd` owns whole-journey abandonment/home return. |
| Reason to return | Distinct relay, lava-tube and wreck objectives/rewards offer different or unfinished work. No requirement for endlessly renewing payment was found. |
| Bounded authored content | Actual caldera, routes and local surveys are bounded authored content; returning to Mudds remains separate. No procedural expansion or station replacement is required. |

Paths above resolve under `scenes/world/planets/`, `assets/world/planets/`,
`scripts/world/`, `scripts/activities/` and `scripts/game/`. The older
`ember_moon_content.tres` is a bounded data-only manifest; its omissions do not
prove that the runtime-composed landmarks or errands are absent.
`tests/ember_moon_authored_scene_test.gd` and
`tests/ember_landing_region_test.gd` contain focused coverage for geometry,
continuously supported routes, actual trailhead interaction, both errand rewards,
paid re-entry and abandonment. Their source was inspected; no result is renewed.

Current-source ordinary full journey, repeated/interrupted visits, complete
remote-crew journey, native performance and silhouette/landmark readability
remain unqualified in their existing SOLO/WORLD/SHARED/PERF/ART outcomes.
The parked Ember native-close smoke is untouched. No new content task or
qualification chain follows automatically from this definition.

### Aurora authored-content boundary

CONTENT-AURORA source comparison, 2026-10-18, on `9d2d467e0`: **no missing
implementation identified within the inspected Phase 10.4 authored-content
promise**. This closes the finite definition only. No engine, capture, arrival
probe or journey test ran; no previous test result is renewed.

| Original criterion | Production owner inspected |
| --- | --- |
| Recognisable orbital silhouette | `shipyard_world.gd` assigns Aurora's material/shader to destination-tagged `CelestialGreenBody`; `aurora_orbital_silhouette.gdshader` supplies ocean/land/cloud/atmosphere presentation. Streamed scene has its own `BodyVisual`. Visual adequacy through approach remains unproven. |
| Substantial landing region | `aurora_temperate_world.tscn` supplies the landing floor/pad and 96×96 m collision patch. `aurora_temperate_authored_scene.gd` configures five terrain rings with flat authored surroundings and 1.5 km collision coverage. The original promise supplies no numerical adequacy threshold; source presence is not approval of scale. |
| Multiple navigable landmarks | Scene `_build_exploration_landmarks()` composes signed lookout, entrance/steps, instruments, standing stones, groves and shore rocks. Actual lookout/stones anchors feed survey gameplay. |
| Surface routes | Same builder supplies marked amber gravel segments from pad/staging to lookout and a standing-stone branch, with posts/sign and appropriate deck/step/rail/stone collision. |
| Activities/rewards via existing authorities | `aurora_coastal_survey.gd` binds scene anchors and two ActivityDirector checkpoints, consumes real actor positions and commits through NearbyActivityRewardAdapter and existing GameFlow reward authority/store. Receipt is once-only. |
| Recoverable failures | Survey abandonment/restart, interrupted progress and refused-reward retry are implemented. Shared `planetary_surface_visit_expedition.gd` owns restoration/cancellation/rescue, with reboarding independent of survey completion. |
| Reason to return | Unfinished/interrupted survey and unpaid completion support continuation; destination readmission/free coast exploration remain. Paid completion deliberately disables further reward interactions. No renewable payment loop was explicitly promised; none is added or silently assumed. Qualitative sufficiency is not proved by this source comparison. |
| Bounded authored content | Fixed coast landmarks/routes, two observations and one data receipt preserve existing reward/station authority. Wider terrain/water do not imply extra authored gameplay regions. |

Names above resolve under `scripts/world/`, `scripts/rendering/`,
`scripts/activities/`, `scripts/game/` and `scenes/world/planets/`. Main composes
Aurora's streaming pair; `aurora_expedition.gd` supplies its profile to the shared
visit owner, whose streamed-surface composition attaches the survey and berth.
The detached pad→egress→staging metadata snapshot is not a complete inventory of
the runtime coastal walk. Its omission of lookout/stones is not absent gameplay.

Existing authored-scene, visit-loop and space-backdrop tests were inspected only.
Ordinary/shared full journeys, package failed-save recovery, repeated/interrupted
visits, visual recognisability/adequacy and applicable native hardware acceptance
remain in their existing outcomes. No new mandatory human gate or owner approval
is introduced. The original Aurora arrival bundle remains WAITING; its parked
failure and limits are unchanged. The authored-scene document now explicitly marks
its early jump-only account as superseded by physical travel.

### Rime authored-content boundary

CONTENT-RIME source comparison, 2026-10-18, on `30968aeda`: **no missing
implementation identified within the inspected Phase 10.4 authored-content
promise**. This closes the finite definition only. No engine, capture, landing
probe or test rerun occurred; no previous result is renewed.

| Original criterion | Production owner inspected |
| --- | --- |
| Recognisable orbital silhouette | `shipyard_world.gd` assigns Rime's material to destination-tagged `CelestialGreyBody`; `rime_orbital_silhouette.gdshader` supplies ice bands/fractures/caps/cloud streaks/limb. Streamed scene has `BodyVisual`. Actual recognisability remains unqualified. |
| Substantial landing region | `rime_icefall_landing.tres` supplies small/medium craft pad, corridor and five egress/surface anchors. Scene has a shelf visual and 96×96 m central collision patch; authored runtime builds surrounding relief collision with 750 m flattened surroundings. Source presence does not decide qualitative adequacy. |
| Multiple navigable landmarks | `rime_glacial_authored_scene.gd` builds survey beacon/sign, drill/core crate/heated hut, seracs/viewpoint and pressure-ridge gauge, with authored collision where appropriate. |
| Surface routes | Same owner builds the 2.4 m orange survey route through those landmarks and a cyan return path. GlacierExploration is under the real LandingRegion Node3D, so placements follow region rebases. |
| Activities/rewards via existing authority | `rime_expedition.gd` binds `rime_ice_core_survey.gd` to the shared visit. Actual scene anchors supply two ActivityDirector checkpoints; beacon/drill/gauge interactions use existing reward adapter and GameFlow reward authority/UserDataStore. Payment is once-only. |
| Recoverable failures | Survey heater drains outside craft/hut warmth; cold failure and beacon restart preserve player/craft/lease/return. Completed readings survive rejected reward-save retry; existing persistence captures/restores interrupted survey/visit state. |
| Reason to return | Failed/unfinished survey, unique discovery and unpaid retry provide continuation across visits. Paid discovery suppresses further reward runs; no renewable reward loop is required or invented. Post-completion return incentives remain qualitative, not an absent capability proved here. |
| Bounded authored content | One shelf with fixed landmarks/trails, deterministic scatter, pad/route clearance and existing node/light/triangle budgets. No station-service replacement or new settlement economy is implied. |

Names resolve under `scripts/world/`, `scripts/rendering/`, `scripts/game/`,
`scripts/activities/`, `assets/world/planets/` and `scenes/world/planets/`.
Main composes Rime's streaming pair; its bootstrap preloads the actual scene,
GameFlow registers the destination, and its expedition profile attaches the survey
through the shared visit owner. The static scene and detached content metadata
are incomplete inventories of runtime-built content. Metadata disclaiming route
or traversal authority does not mean physical walking is absent.

Existing authored-scene test source covers composition, landmarks/routes, terrain
support, warmth, placement and budgets; it does not establish a full journey or
reward lifecycle. Ordinary/shared journeys, repeated/interrupted visits, fresh
reward-save recovery, readability, weather/terrain presentation and applicable
native hardware acceptance remain in their existing outcomes. No new mandatory
human gate is introduced. Parked Rime arrival/landing/pad-control failures and
original limits remain unchanged. The world document now separates its initial
test inventory from current source-specific results in backlog/history.

### Multiplayer children

Role proof: ordinary walk/sit/use/stand/exit with authenticated peers, supported moving-cabin ownership/disconnect recovery. Browser proof: valid admission or honest refusal plus usable menus. Shared-world proof: the [planetary family contract](#activities-and-planetary-journeys), including original physical, reward/save and usable-return criteria. **21 shared-world rows serve both parents 3 and 27; they are not two queues.** Physical-device qualification remains separate.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| NET-JOVIAN-BOARD | Ordinary two-client physical boarding and confirmed seats/HUD | 16,26 | DONE; fff5f7221, host plus two clients |
| NET-JOVIAN-DEPART | Ordinary shared 5m departure and zero-speed braking | 16,26 | DONE; 96c96312f, broader return/endurance not established |
| HELM-EDGE-REPRO | Actual immediate landing followed by neutral physics reproduces missing remote edge | 18 | DONE; a3955ee90 expected-only failure, original fixture compile repair retained |
| HELM-EDGE-REPAIR | Preserve admitted immediate command exactly once across consumers | 18 | DONE; 2c73494a4, consumer40/ship_command79, component-staged scope |
| NET-JOVIAN-RETURN | Original shared physical home docking and both clients consumed arrival | 16,20,26 | DONE;4c9c764e9 original route138.915s, failed331 arrival attempt retained |
| NET-JOVIAN-ARRIVAL-CALLER | Confirm arrival using client-received ownership record | 16,20,26 | DONE;4c9c764e9, original pilot/ship/ownership generations, all peers exit0 |
| ROLE-JOVIAN-ENGINEER | Jovian engineer ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-HALYARD-PASSENGER | Halyard passenger ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-HALYARD-ENGINEER | Halyard engineer ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-HALYARD-GUNNER | Halyard gunner ordinary moving-crew lifecycle | 16,24 | Local source route and one actual52damage DONEc28f7ffa3; independent authenticated remote-role lifecycle remains GATED on supported candidate/ordinary route. Original fixtures and broader networking/native limits retained. |
| ROLE-HALYARD-LOADMASTER | Halyard loadmaster ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-BULWARK-GUNNER | Bulwark gunner ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-CINDER-LOADMASTER | Cinder loadmaster ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| ROLE-CINDER-NAVIGATOR | Cinder navigator ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
| NET-SEATS-FINAL | Final-candidate promotion/seat ledger/berth handback/stale refusal | 16 | GATED; selected candidate, no rebuild of delivered authority |
| NET-POSE-DEFINE | Uncovered supported craft/engine/motion/landing-view cells | 17 | Bounded Jovian source comparison DONE: concrete physical throttle instrument consumer gap; broader cells remain unqualified |
| NET-OPERATION-HUD | Gameplay HUD engine/throttle follows eligible accepted host operation facts; local pilot prediction/raw authority retained | 17 | DONEda1ae60; exact old3 failures, pose175/real-peer354, paired exports/three strict startups/actual1515-entry audit. No simulation/wire changes; parent 17 OPEN |
| NET-HULL-HUD | Gameplay HUD bar/frame projects existing authoritative hull/maximum/status; raw simulation telemetry remains local | 21 | DONE7be348d62; exact old2 HUD failures, fixed pose140/real-peer272, paired exports/three strict startups/actual1515-entry audit. Raw simulation authority preserved; parent21 OPEN |
| NET-HULL-INSTRUMENTS | Physical remote hull gauge reflects existing authoritative health; damage/destruction/new-life/solo-clear | 21 | DONE24430b7c1; old2 failures reproduced, pose121/real-peer250 and fresh paired24430b7 with3strict startups/actual1515-entry audit. Parent21 OPEN, no wire change |
| NET-THROTTLE-INSTRUMENTS | Current/late physical cockpit gauge reflects signed authoritative throttle, neutral shutdown and solo restore | 17 | DONE8f17b0241; old4 failures reproduced, pose91/real-peer203 pass; fresh paired8f17b02 with3strict startups/actual1515-entry audit. Broader parent17 remains OPEN |
| HELM-ACTIONS-DEFINE | Finite sampled-local-input to remote-helm action roster | 18 | DONE; seven held fields/two ordered edges, source definition only |
| CABIN-PASSENGER-ROLE | Confirmed standing cabin passenger HUD follows current claim and craft after normal helm release | 18,20 | DONE007024839 within the same yaw/handback integration/checkpoint: focusedHUD36 plus full136.675s ordinary three-peer route PASS, correct PASSENGER/craft, current support/ownership/source/co-pilot and backward walking. Pure presentation, no authority grant. Original branch and superseded caller refs deleted; archives/cleanup complete. Same delivery as HELM-YAW, not separately counted. |
| HELM-THROTTLE-REVERSE | Sampled reverse thrust and neutral release | 18 | OPEN; reverse flight/release child DONE52b228c86, unchanged ordinary route138.086s, host1.448m/888ms and both actual replicas pass; same source/lease/host effect required. Recorded yaw/shared handback accepted007024839; reverse-specific handback and physical input qualification remain open |
| HELM-YAW | Both sampled yaw directions, neutral release and handback without stale ownership | 18 | DONE for recorded source route007024839, merged2f75e834b: full136.675s ordinary boarding/departure/both-yaw/normal Interact/owner0gen+1/current PASSENGER HUD/supported backward walk, retired source/capture and retained co-pilot; all3 actual OS exits0, no diagnostics. All original.6m local/host and8/15/300/360s gates retained; chair-clearance caller additionally proves.6m backward after clearance. Paired checkpoint0070248; both related branches/owned scratch closed. OS/device/native/endurance/full parent remain open. [Acceptance](history/ROADMAP_DELIVERIES.md#passenger-hud-and-yaw-handback-accepted-both-branches-closed--2026-10-20) |
| HELM-PITCH | Both sampled pitch directions and neutral release | 18 | OPEN; turn/release child DONEf9682a38c: three-process original boarding/departure/brake plus both synthetic Godot pitch actions→production sampler→host +4.8°/−4.2° within567/364ms, fresh neutral≤1s, drift0°, both actual replicas≤2° and three exits0/zero diagnostics. [Source result](history/ROADMAP_DELIVERIES.md#sampled-remote-pitch--turn-and-release-accepted). Recorded yaw/shared handback accepted007024839; pitch-specific handback remains open; OS/device/native/endurance/full parent not accepted  Changed shared-caller regression73f4a4f67 PASS131.398s with original pitch gates. |
| HELM-ROLL-RATE | Both sampled roll-rate directions and neutral release | 18 | OPEN; turn/release child DONE73f4a4f67: original three-process boarding/departure/brake, both synthetic actions→production sampler→host−5.867°/+5.867° in535/546ms, fresh neutral≤1s/measured roll drift0° and both replicas≤2°. No active barrel roll or host/pilot barrel request; all3 exits0/zero diagnostics. [Source result](history/ROADMAP_DELIVERIES.md#sampled-continuous-roll-rate--turn-and-release-accepted). Recorded yaw/shared handback accepted007024839; roll-specific handback remains open; no OS/device/native/endurance/full-parent acceptance |
| HELM-BOOST | Sampled boost effect on authoritative flight and release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| HELM-HOVER | Sampled hover correction on authoritative craft and release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| NET-STALL | Original 600-step host simulation stall and honest command recovery | 19 | DONE on3d6b1b513 current-source isolated Linux full original suite:160 terminal host assertions, both600-step stalls/original2s action checks, actual client/wrapper exit0 and zero diagnostics. [Result](history/ROADMAP_DELIVERIES.md#original-host-stall-route--current-source-accepted). No unchanged repeat; final-package/native/endurance and distinct ordinary moving-Halyard/other-action handback gates remain |
| NET-SECOND-LAND | Historical intermittent second-landing boundary | 20 | GATED; establish distinctness from current return failure before any probe |
| NET-DOCK-DEFINE | Supported craft dock/exit/reboard/redeparture acceptance cases | 20 | DONE definition only; next five Jovian instances below, all other craft/roles remain unscheduled |
| NET-JOVIAN-PASSENGER-EXIT | Original passenger reaches supported ground while pilot retains helm | 16,20,26 | DONE on861c4d39b, merged2352d18c3: original full138.470s journey PASS clean, all seven physical route poses, same-player supported ground walk, legitimate passenger claim/body retirement, retained pilot and actual3peer exits0. Paired checkpoint861c4d3; exact-tip local/remote/tracking branch deletion and owned cleanup complete. Broader postdock reuse remains separate. [Acceptance](history/ROADMAP_DELIVERIES.md#physical-jovian-passenger-exit-accepted-and-branch-closed--2026-10-20) |
| NET-JOVIAN-DOCKED-PILOT-HOLD | A still-owned remote pilot retains the committed authoritative dock pose/velocity | 16,20,26 | DONE within accepted passenger-exit chain861c4d39b, merged2352d18c3. Pose322 regression PASS; final original138.470s three-peer journey retains exact committed home/pilot/source through supported passenger exit and actual3OS exits0, no diagnostics. Paired checkpoint861c4d3; branch/owned cleanup complete. Same integration and build as EXIT, not a separately counted delivery. |
| NET-JOVIAN-PASSENGER-REBOARD | Original passenger reclaims original co-pilot chair | 16,20,26 | DONE scoped ordinary three-peer Linux journey49bc7b736. Full original departure/home landing/physical exit/groundwalk/reboard/fresh chair PASS149.242s; both clients consume exact chair, original pilot and strict home lease retained;3actualOS0/clean logs. Actual unconsumed pre-bind hatch ID identified; producer retires old edges while preserving fresh/retry behavior. Source98/body42 PASS; fresh paired checkpoint/strict menus/package audit and independent review GO; owned scratch removed. Full parent/baseline/endurance/native gates remain open. [Delivery](history/ROADMAP_DELIVERIES.md#jovian-passenger-reboard--accepted--2026-10-20). |
| NET-JOVIAN-PILOT-EXIT | Original pilot releases helm and walks onto supported berth ground | 16,20,26 | DONE scoped ordinary three-peer Linux journey63186dc80. Complete accepted passenger prefix, original pilot authored exit and1.255m supported walk; exact old authority/source/queue/seat/body/publication retired, both clients consume release, passenger chair and strict occupied home lease retained. PASS153.310s/3actualOS0/cleanlogs. Initial impossible pose-header check corrected with fresh same-hull retirement-boundary comparison; original failure retained. Runtime unchanged49bc7b7; owned scratch removed, main sole branch. [Delivery](history/ROADMAP_DELIVERIES.md#jovian-original-pilot-exit--accepted--2026-10-20). |
| NET-JOVIAN-PILOT-RECLAIM | Original pilot returns to same hull and acquires current helm authority | 16,20,26 | DONE07ec703c7; full physical reuse and actual retired-stream refusal |
| NET-JOVIAN-REDEPART | Same crew/hull departs at least5m and brakes after physical reuse | 16,20,26 | DONEbc7f9f9c4; full ordinary pilot/co-pilot reuse journey, actual berth release and stopped peer convergence |
| CONVOY-ACTOR-DEFINE | Uncovered Convoy tender live/dead/reset/late/disconnect cases | 22 | DEFINE; actual native-gameplay coverage versus authority tests |
| TORPEDO-AUTH-DEFINE | Actual projectile authority, retained solo restoration and pilot/target loss | 23 | DONE definition only; ten finite qualification cases below, no new missing production consumer or runtime defect established. Ordinary/independent packaged routes remain OPEN |
| PICKET-ACTOR-DEFINE | Uncovered Picket travelling actor/late/dead/reset/disconnect cases | 24 | DEFINE; actual moving-crew integration |
| EMBERLINE-ACTOR-DEFINE | Uncovered Emberline flight/hit/miss/expiry/late/dead/reset/disconnect cases | 24 | DEFINE; retained failed baseline not erased by isolated pass |
| NET-BROWSER-PAUSE | Paused LAN Refresh and host answering | 25 | DONE packaged042c701e2; real automatic paused loopback27/default GameFlow7 pass; full ordinary menu/endurance gates separate |
| BROWSER-JOIN | Discover/refresh/select/join ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-STALE | Stale session ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-FULL | Full session ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-UNREACHABLE | Unreachable endpoint ordinary browser route | 25 | OPEN; non-admission routee944f52 PARKED at timeout diagnostic; no-answer case remains unrun; source preserved under `archive/withheld/browser-release-cache-20261020`, working refs deleted; requirement OPEN |
| BROWSER-CONTROLLER | Controller menu navigation ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-DISCONNECT | Disconnect/retry ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-CANCEL | Cancel/reuse ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| SERVER-BASELINE-DEFINE | Residual authoritative-server/two-client gameplay command and cases | 26 | Definition DONE; Halyard BOARD accepted4bc0e3b38, full original MOVING-CABIN accepted2e117e64f. AUTHORITY-STOP accepted082da79c9 with real host shutdown/client recovery after full moving prefix; complete server baseline remains open. |
| HALYARD-APPROACH | Freeze ordinary spawn-to-airstair input waypoint route | 16,26 | DONE definition; native aft/fleet chain and authored final extension, no collision qualification |
| HALYARD-BOARD | Non-playing Main authority and two original ordinary occupants | 16,26 | DONE 4bc0e3b38: complete original menus/spawn/walk/actual pilot+crew_port_00 boarding and host/client consumed identities, ownership/body/frame/seat/claim generations, controls/HUD; all three actual OS exits0/terminal handshake pass in 130.472s. Same suite300/outer360/8s transition. Branch merged/pushed/deleted; earlier 271.737s failures retained. No runtime change/new identical checkpoint. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-ordinary-boarding-branch-finished--2026-10-20) |
| HALYARD-MOVING-CABIN | Actual departure with passenger supported walk/chair cycle | 16,24,26 | DONE current-source2e117e64f: same ordinary-board actors, actual pilot departure5.175m, host-confirmed passenger walk>.6m/local1.181m, stand/sit/stand/reseat during actual hull motion, current body/frame/role/ownership and both consumed presentations; claims1→3→5. Full141.298s/270checks/one marker/three actual OS0/zero diagnostics; original caps unchanged. First141.234s caller failure retained, observer engine consumer corrected once. [Accepted full case](history/ROADMAP_DELIVERIES.md#halyard-ordinary-moving-cabin--accepted--2026-10-20); authority-stop accepted separately082da79c9, endurance/package/native/full baseline remain open. |
| HALYARD-AUTHORITY-STOP | Real server stop restores both remaining occupants to solo play | 16,26 | DONE082da79c9: full original BOARD/MOVING prefix, same non-playing host stops once with original occupants aboard, both actual server_disconnected/session_stopped events, old grant/body/prediction/seat/helm retirement; solo pilot throttle, same supported passenger walk0.616m and both real pause/Resume. Full142.082s/307checks/one marker/three actual OS0/zero diagnostics; original caps unchanged. Two compile-only fixes retained, independent GO, owned scratch removed. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-real-authority-stop--accepted--2026-10-20). Current Linux source only; full baseline/endurance/native/reconnect/migration remain open. |
| SERVER-BASELINE | Dedicated-server/two-client ordinary flight/recovery acceptance | 26 | PARTIAL: original pilot-disconnect case DONE21817ab4b after full ordinary BOARD+7MOVING stages; actual host and adapter disconnect once, departed pilot authority retired, surviving passenger body/frame/claim preserved then ordinary stand/reseat claim5→7, departed samePlayer solo throttle+pause/Resume.145.446s/threeactualOS0/cleanlogs; reviewed/merged/pushed/ownedcleanup complete. Earlier BOARD/MOVING/AUTHORITY-STOP retain their accepted scopes. Original seat races/transfers, sleep, late join, impaired/stalled networking, other boarding/landing disconnect cuts, reconnect/destruction/Main re-entry and supported-platform/full-baseline gates remain; no unchanged rerun scheduled. [Accepted case/command](history/ROADMAP_DELIVERIES.md#server-baseline--ordinary-client-pilot-disconnect-accepted--2026-10-21) |
| NET-FULL-SNAPSHOT | All-nine forced-full publication and byte budget | 17,26 | DONE on accepted330a39ce3 in existing Main/ENet suite: actual complete nine-craft full/live4656/4656 bytes, exact decode and fragment acceptance under unchanged12000. [Retained result](history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted). Ordinary/native/endurance/final-candidate gates remain open |
| NET-PROFILES-DEFINE | Original latency/loss/jitter/reorder/stall profile roster | 26 | DONE definition only; MOVING_INTERIOR_LATENCY finite contract names five stream profiles, narrow three-process command injection and two physical host-stall actions; impaired independent session/endurance remain open |
| NET-ENDURANCE-DEFINE | Executable original 30-minute independent two-client moving-interior route | 26 | DEFINE; original duration/latency, no short substitute |
| NET-ENDURANCE | Original 30-minute moving-interior session | 26 | GATED; stable baseline and exact original command |
| SHARED-EMBER-BASELINE | Ember shared canonical outbound/physical survey/reward/save/home return | 3,27 | GATED; ordinary crew/profile and exact canonical command |
| SHARED-EMBER-LATE-JOIN | Ember shared late join | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-EMBER-RECONNECT | Ember shared disconnect/reconnect | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-EMBER-PILOT-LOSS | Ember shared pilot loss | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-EMBER-CANCEL | Ember shared cancellation | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-EMBER-INTERRUPT | Ember shared actual OS interruption | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-EMBER-REVISIT | Ember shared repeat visit | 3,27 | GATED; EMBER genuine baseline and exact original case command |
| SHARED-AURORA-BASELINE | Aurora shared canonical outbound/physical survey/reward/save/home return | 3,27 | WAITING; original 47ffce740 bundle |
| SHARED-AURORA-LATE-JOIN | Aurora shared late join | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-AURORA-RECONNECT | Aurora shared disconnect/reconnect | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-AURORA-PILOT-LOSS | Aurora shared pilot loss | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-AURORA-CANCEL | Aurora shared cancellation | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-AURORA-INTERRUPT | Aurora shared actual OS interruption | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-AURORA-REVISIT | Aurora shared repeat visit | 3,27 | GATED; AURORA genuine baseline and exact original case command |
| SHARED-RIME-BASELINE | Rime shared canonical outbound/physical survey/reward/save/home return | 3,27 | PARKED/open. Original58.083simulation-seconds/120s wall failure retained. Full restored two-crew cost captured9a073c98 stillFAIL1624.422s at peer host.landed gate.105 usable sampled script frames, noEND/ACCUMULATED; Halyard/native attribution unresolved and controllerleg=-1 unavailable. No supported repair/retry or cap change. Source bundled, both owners terminal/19 identities absent/64 scratch entries archived verified removed. Original120s/2400s and full scope preserved. |
| SHARED-RIME-LATE-JOIN | Rime shared late join | 3,27 | GATED; RIME genuine baseline and exact original case command |
| SHARED-RIME-RECONNECT | Rime shared disconnect/reconnect | 3,27 | GATED; RIME genuine baseline and exact original case command |
| SHARED-RIME-PILOT-LOSS | Rime shared pilot loss | 3,27 | GATED; RIME genuine baseline and exact original case command |
| SHARED-RIME-CANCEL | Rime shared cancellation | 3,27 | GATED; RIME genuine baseline and exact original case command |
| SHARED-RIME-INTERRUPT | Rime shared actual OS interruption | 3,27 | GATED; RIME genuine baseline and exact original case command |
| SHARED-RIME-REVISIT | Rime shared repeat visit | 3,27 | GATED; RIME genuine baseline and exact original case command |

### Torpedo authority and restoration — finite remaining cases

TORPEDO-AUTH-DEFINE is a source definition onaa1a88bef, one bounded high-effort
reader plus root verification; no engine, gameplay implementation or fresh pass.
Existing ownership is delivered: LiveCombatAuthority and SeekerTorpedoProjectile
own resolver flights/terminal damage; TorpedoBoatOpponent.set_network_presentation_only
suspends AI/collision/registration/launch and permanently retires old solo seekers.
GameFlow's join/session owners and EncounterScenarioDirector suspend/resume the
retained boat/target/hull/charge/generation/timer. GameFlow publishes actual seeker
pools to NetworkRemoteProjectileReplicator's current/late/terminal presentation.
Generic GameFlow remote-helm cleanup retires old ownership; director termination
observes target craft lifetime/destruction and authorized phase. Pilot-seat loss
alone is not defined as craft destruction or a new abort policy.

Existing game_flow_torpedo_boat_authority_test uses real Main/boat/pool but API
calls and synthetic current/late consumers. It covers join suspension, denied
launch, frozen timer/distance, retained restoration/fresh solo fire, live-host
adoption, refused/manual/directory join and Main reentry. network_remote_projectile_test
uses same-process loopback ENet/fake pools; seeker and boat tests cover their actual
owners. [Recorded earlier lifecycle scope](MOVING_INTERIOR_LATENCY.md) remains
accepted. These anchors do not establish independent ordinary Torpedo gameplay.

Each row below is one **unselected qualification**, not a missing implementation.
All are GATED on an actual Torpedo baseline/appropriate named participant route,
matching package and a frozen original command/deadline. COMBAT-TORPEDO remains
the ordinary combat/reward/home-return owner; do not duplicate it here.

| Child / parent23 | One observable finish | Additional prerequisite / stopping boundary |
| --- | --- | --- |
| TORPEDO-PEER-FLIGHT | Independent packaged host/current/late processes observe one actual host seeker, current-pose adoption of an already-airborne flight without launch replay, and actual terminal retirement without duplicate damage/resurrection | Freeze one launch-to-terminal scenario and actual participating craft; synthetic packets alone do not close it. Stop after that flight/terminal lifecycle. |
| TORPEDO-JOIN-FAIL | An actually pending transport join fails; retained solo boat state resumes, old seekers remain retired, fresh solo flight works | Pending join must be observed; immediate invalid-port/API refusal is insufficient. Stop after one failed join/recovery. |
| TORPEDO-JOIN-CANCEL | Ordinary browser cancel during pending join restores the same retained solo encounter and usable fresh fire | Actual browser route; no admitted session/disconnect substitution. Stop after one cancel/recovery. |
| TORPEDO-DISCONNECT | Ordinary Disconnect from admitted client state restores retained solo state and fresh launch authority, without resurrecting old flights | Actual admitted peer/session; no direct shutdown-only claim. Stop after one disconnect/recovery. |
| TORPEDO-SERVER-LOSS | Real authority process loss restores usable retained solo encounter and retires old network/solo-flight effects | Actual independent authority termination with owned abort/reap path. Stop after one loss/recovery; no migration/endurance claim. |
| TORPEDO-MAIN-REENTRY | Actual whole-Main exit/reentry preserves supported retained encounter restoration and fresh-flight authority, with old flights retired | Freeze exact lifecycle action/expected owners; existing API reentry proof retained. Stop after one reentry/recovery. |
| TORPEDO-PILOT-LOSS | Actual remote helm retirement during live Torpedo play preserves correct surviving-craft/target ownership and usable supported recovery | Name physical pilot/craft/seat route; no invented pilot-loss-always-aborts rule. Stop after one pilot-loss recovery. |
| TORPEDO-TARGET-DESTROY | Actual target-craft destruction aborts/withdraws the Torpedo composition and stands down boat/seekers once, without reward | Actual target identity/destruction, no generic unrelated director substitute. Stop after one terminal cleanup. |
| TORPEDO-TARGET-REMOVE | Actual target lifetime removal retires the encounter/boat/seekers once, with no stale-target or duplicate terminal effects | Separate from hull destruction; exact production lifetime owner. Stop after one removal cleanup. |
| TORPEDO-PHASE-EXIT | Leaving the authorized flight phase withdraws the Torpedo composition and its flights without reward/duplicate terminal effects | Name actual production phase transition; no direct arbitrary state assignment as ordinary-route proof. Stop after one withdrawal. |

A selected card must freeze exact files, ordinary/setup disclosures, participants,
retained-state/receipt criteria and measured route budget before engines. Source
review found no required runtime change to estimate; estimate each selected
qualification/any demonstrated repair from its actual route. Do not chain all ten
cases into one assignment. Any failure stops its selected case before separately
reviewing repair/priority. No dependency on parked Heavy Breach debt interruption,
no unchanged parked retry, and no new validator/schema/persistence entitlement.
Parent23 and full independent/native combat/recovery acceptance remain OPEN.

### Hardware, accessibility and audio children

Native performance proof retains ≥60s/3,600-frame warmup and ≥600s/18,000-frame measurement, 1080p High p95≤16.7ms/p99≤33.3ms/no post-warm frame>100ms/working set≤4GiB and original GPU/VRAM/streaming budgets. Each missing benchmark route, measured hotspot, remap case, readability cell, cue and mix scenario becomes a named child only when the corresponding finite list is resolved. Software/VM/Dummy tests do not qualify actual hardware or audible mix.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| PERF-MINIMUM | Bind actual minimum-spec machine/profile | 28 | WAITING; representative isolated hardware |
| PERF-TARGET | Bind actual target-spec machine/profile | 28 | WAITING; representative isolated hardware |
| PERF-ROUTES-DEFINE | Required representative workloads beyond the seven existing selectors, with whole-expedition repetition mapped to world endurance | 28 | DEFINE; additional craft/world/cycle roster unspecified; existing repeat paths retained |
| PERF-CELLS-DEFINE | Applicable machine/route measurements | 28 | GATED; required routes and actual two machine profiles |
| INPUT-KBM | Physical keyboard/mouse ordinary full route | 8,18,29 | WAITING; actual device/isolated session, exact required route |
| INPUT-CONTROLLER | Physical controller ordinary full route | 8,18,29 | WAITING; actual device/isolated session, exact required route |
| MIXED-CONTROL-PROMPTS | Grouped help retains mixed button/stick labels independent of action order | 8,29 | DONEb86264f; actual MOVE/default shorthand, glyph40/camera27/help20 and paired checkpoint; no physical device/whole apply-flight claim |
| CAMERA-DISTANCE-PROMPTS | Piloting help exposes both live remapped distance directions | 8,29 | DONE7718a5a; HUD keyboard/controller labels/reset, focused27/help20 and paired checkpoint. No whole apply/restart/device claim |
| REMAP-DEFINE | Uncovered binding/apply/restart/conflict/recovery cases | 8,29 | Definition DONE onc1fc23871; existing persistence contract names finite outcomes and concrete missing on-foot sprint toggle; hardware/Settings prerequisites preserved |
| ONFOOT-SPRINT-TOGGLE | Advertised shared sprint option works while walking | 8,29 | DONEbd4e15d0f, packaged. Saved/live/reset/HOLD, actual Player physics sprint speed and control/tree/remote fences pass; existing settings checks retained. Broader remapping/device gates OPEN |
| TRACTOR-LOOK-INVERSION | Existing on-foot inversion also controls tractor mouse/right-stick pitch, from saved startup and live edits | 8,29 | DONE checkpoint34d4b9e: full tractor162, actual Main settings11 and existing runtime settings156 checks PASS; paired exports/three strict startups/package audit PASS. Original headless mouse failure31.933s retained; one isolated X11/dummy-display correction passes all assertions. Physical devices/full ordinary routes/final candidate OPEN. [Result](history/ROADMAP_DELIVERIES.md#tractor-look-inversion--shipped-on-34d4b9e) |
| ACCESS-PAUSE-DEFINE | Pause/options readability views and required scale/aspect cells | 12,29 | DONE; five named aspect groups/three authored scales, actual view states below |
| ACCESS-PAUSE-4X3 | Pause/options at 1024x768, requested scales0.75/1.0/1.6 | 12,29 | DONE sourceece9a0253:96 actual Main observations/all32 states at each scale, bounds/font/focus/scroll pass33.402s; headless geometry only, no rendered/device/persistence qualification |
| ACCESS-PAUSE-16X9 | Pause/options at 1920x1080, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.405s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| ACCESS-PAUSE-16X10 | Pause/options at 1920x1200, requested scales0.75/1.0/1.6 | 12,29 | DONE source1cf102298:96 Main observations/all32 states at requested.75/1/1.6; conflict and repair-focus corrections accepted |
| ACCESS-PAUSE-21X9 | Pause/options at 3440x1440, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.533s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| ACCESS-PAUSE-32X9 | Pause/options at 5120x1440, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.412s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| SETTINGS-SCALED-FOCUS-SCROLL | Fully reveal current Settings focus under scaled pause layouts; ignore stale/duplicate requests | 12,29 | DONE; paired4d7ac43. Focus59 and complete16:9/21:9/32:9 checks pass. Original21:9 failure33.080s and pre-run review correction retained in history |
| ACCESS-VIEWS-DEFINE | Remaining required HUD/menu/help/role readability views/cells | 12,29 | DONE as source definition in the finite view roster below; owners/states/coverage and one-cell selection named. No new layout/device qualification. |
| ACCESS-FEEDBACK-STATUS | Settings save/recovery and nearby/activity-selection feedback follows current palette role once | 12,29 | DONE checkpoint2ed93ca: four families/14 callers use unchanged role helper. Existing caller suites11/35/26/113 and HUD layout552, paired exports/strict startups/PCK audit PASS first attempt; no generic matrix rerun. Copy/visibility/actions/focus/authority retained; headless caller/theme scope, full journeys/rendered/device/human/native/final remain open. [Result](history/ROADMAP_DELIVERIES.md#settings-and-activity-feedback-palettes--shipped-on-2ed93ca) |
| ACCESS-GAMEPLAY-STATUS | Mode/engine/throttle/hull/component/target-lock labels use current palette role once | 12,29 | DONE checkpoint941ef73: existing-entry role update/white modulation/steady telemetry guard,256 cases/768 actual paints across32 states/4palettes/2contrast. Full accessibility1979/target-lock6/sensor-reticle90/HUD-layout552 and paired exports/strict startups/PCK audit PASS first attempt. Copy/visibility/thresholds/geometry/authority retained; headless theme scope, rendered/device/human/full journeys/native/final open. [Result](history/ROADMAP_DELIVERIES.md#gameplay-status-palettes--shipped-on-941ef73) |
| ACCESS-DESTINATIONS-STATUS | Retained Destination Board status colour follows current state/palette/high contrast without multiplication | 12,29 | DONE checkpointc47ca33: existing registration role updated once/neutral modulation;32 live Control palette/contrast pairs, full HUD layout552/accessibility443/Main console16 and paired exports/strict startups/PCK audit PASS first attempt. Label identity/text/action/focus and journey authority retained. Headless theme scope; rendered/device/human/full journeys/final remain open. [Result](history/ROADMAP_DELIVERIES.md#destination-board-status-palette--shipped-on-c47ca33) |
| ACCESS-HELP[on_foot,1920×1200,0.75] | All four ordinary on-foot context pages fit and retain usable navigation at minimum scale | 12,29 | DONE source5ac9d3ef0:124 assertions/30.860s, actual Main, requested/effective0.75, twenty rows/four pages, geometry/font/wrapping/focus/Close pass. Headless source scope only; rendered/human/device/other cells/final candidate remain open. [Scope](history/ROADMAP_DELIVERIES.md#on-foot-help--one-minimum-scale-1610-cell-accepted) |
| ACCESS-HELP[aboard,1920×1200,0.75] | All four ordinary aboard context pages fit and retain usable navigation at minimum scale | 12,29 | DONE sourcee5dfe1117:124 assertions/31.076s, actual Main/HUD, requested/effective0.75, twenty rows/four pages, geometry/font/wrapping/focus/Close pass. Headless source scope only; rendered/human/device/crew gameplay/other cells/final candidate remain open. [Scope](history/ROADMAP_DELIVERIES.md#aboard-help--one-minimum-scale-1610-cell-accepted) |
| ACCESS-TITLE-FOCUS | Focused Begin Shift text on cyan uses the intended readable paint | 12,29 | DONE checkpoint923d7b3: actual baseline focus1.335/pressed1.713 contrast corrected with local INK overrides; all32 actual-HUD palette/contrast/state pairs clear4.5/7, focus/outline/navigation/layout retained, same-view reviewed and paired package checks pass. [Actual result/limits](history/ROADMAP_DELIVERIES.md#begin-shift-focus-contrast--shipped-on-923d7b3). Other views/states/native/final gates remain open. |
| ACCESS-MENU-CONTRAST | Shared menu hover/pressed text remains readable across role palettes | 12,29 | DONE checkpointd00ae72: shared darker fills/palette-aware text;160 real production menu paints minimum8.359:1, accessibility443/Help20/controller navigation and paired exports/three strict startups/PCK audit PASS first attempt. Normal/focus/layout/actions and local Help CLOSE retained. Headless theme scope; rendered/device/human/broad UI/final gates open. [Result](history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72) |
| ACCESS-HELP-CLOSE-CONTRAST | Help CLOSE text remains readable while hovered/pressed | 12,29 | DONE checkpoint820cc38: local darker fills/palette-aware text;32 actual paint pairs minimum7.767:1 plus existing accessibility252/Help20, paired exports/three strict startups/PCK audit PASS first attempt. Other menu defaults and Help focus/paging/close retained. Headless paint scope; rendered/human/device/broad UI/final gates open. [Result](history/ROADMAP_DELIVERIES.md#help-close-contrast--shipped-on-820cc38) |
| COMFORT-MOTION | Reduced motion route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-FLASH | Reduced flash route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-COLOUR | Colour-safe cues route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-CAPTIONS | Captions route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| AUDIO-CONTENT-DEFINE | Finite actually missing cues and broken transitions | 30 | Definition DONE on8a6e7dfe6; existing COMPLETION_SCOPE audio map separates real playback, two transition outcomes and dormant Ember feed definition; no missing new theme inferred |
| AUDIO-ACTIVITY-LIFECYCLE | Current activity music survives normal updates and same-run completion | 30 | DONEf1f35d137, packaged. Same-run completion/base updates, terminal fences, combat/landing resume, reset/context/lifecycle/PCM/clock scopes pass; five focused suites, paired exports/three strict startups. Audible mix OPEN |
| AUDIO-SURFACE-MUSIC | Aurora/Rime surface visit selects existing surface bed | 30 | DONE packaged4ff7a08; actual visit-state projection, controlled phase150/activity26/retained bed checks and strict paired checkpoint pass; ordinary journeys/listening remain open |
| AUDIO-EMBER-FEED-DEFINE | Actual intended Ember environment and observation owner | 30 | Definition DONE on17f92907c: [airless contract/production owners/exact missing intent](COMPLETION_SCOPE.md#ember-environment-feed--source-definition). Active audio forbids atmospheric wind; dormant generic path uses Aurora assets/no ordinary callers. Additional world-specific sound/listener intent is unspecified; no integration selected or new playback qualified. |
| AUDIO-MIX-DEFINE | Finite real-output scenario/device mix list | 30 | Definition DONE on9ef81a348: [finite mix roster](COMPLETION_SCOPE.md#real-output-mix-roster--audio-mix-define), nine current craft/eight normalized activity kinds and named shared episodes. All listening NOT_RUN; actual device/backend/configuration and explicit audible authorization missing. Source review identifies repair cue playback gap; no audio acceptance claimed. |
| AUDIO-MIX | Actual output levels/cues/transitions in named scenario | 30 | WAITING on selected roster case, exact package/ordinary route, actual device/backend/configuration and explicit audible authorization. Finite roster defined; all actual listening remains NOT_RUN. |
| AUDIO-CREW-REPAIR-PLAYBACK | Actual accepted Halyard repair edges reach normalized presentation and resident playback | 30 | DONE packaged9b7b46a. Raw-state normalization, independent elapsed repair observation, missing router labels and resident dispatch repaired. Seven focused/paired package gates PASS; real source/kit/role, once captions, historical-terminal/source reset proved under Dummy. [Full result/first failure](history/ROADMAP_DELIVERIES.md#audio-crew-repair-playback--actual-accepted-repair-edges-delivered). Actual listening/physical crew/native qualification remains separate. |
| AUDIO-NAVIGATOR-PLAYBACK | Actual navigator result/recipient cue playback boundary | 30 | Accepted/clear DONE packaged4bbb341 across standalone/host-local/bridge/client; actual client stand/reseat/revocation/replay/migration/disconnect and shared crew epoch correction pass original route. Requester rejection DONEc2c72a223/checkpointc2c72a2: all fresh authenticated current refusals including missing consumer; two actual peers/four real rejected presses, replay/foreign silence and full original accepted-clear/migration/disconnect pass252 checks. [New result](history/ROADMAP_DELIVERIES.md#navigator-requester-rejection-feedback-completed--2026-10-21). All real listening/native/full travel gates stay open. [Result](history/ROADMAP_DELIVERIES.md#audio-navigator-client-feedback-and-crew-epoch--delivered). |

### Recovery and release children

Recovery proof uses an owned actual OS SIGKILL, distinct restart, protected real files, once-only rewards and ordinary usable recovery. One selected cut is one task, not arbitrary power-loss coverage. Package/capture/install proof follows the unchanged [release family contracts](#recovery-packages-captures-and-release). **13 capture sets / 143 PNGs** are individually named; native Windows execution/human-review owner exclusions remain factual NOT_RUN, and applicable other release gates remain open.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| RECOVERY-ONFOOT-DEFINE | On-foot durable-boundary/resume-or-safe-home contract | 2,31 | DONE; four-field home preference; selected f90547c archive cut now accepted |
| RECOVERY-ONFOOT-PROBE | Exported release driver admits and observes genuine on-foot save/resume context | 2,31,32 | DONE source scope f90547c37: real-file source kill/restart, supported walk+Interact, receipts1→2; package child accepted |
| CHECKPOINT-ONFOOT-PROBE | Paired checkpoint ships accepted on-foot release-driver support | 6,32 | DONE f90547c: paired exports, strict startups and exact package audits |
| RECOVERY-ONFOOT-CUT | Real-file on-foot commit, owned SIGKILL and distinct-process usable home recovery | 2,31 | DONE f90547c direct and actual archive-extracted ELF cuts; supported walk/Interact, receipts1→2 once |
| RECOVERY-PILOT-DEFINE | Pilot durable-boundary/resume-or-safe-home contract | 2,31 | DONE definition only; four-field safe-home pilot preference, fresh claims, preserved activity/debt; ca0 archive pilot/Convoy pass retained; final candidate and ordinary-controls qualification remain |
| RECOVERY-CABIN-DEFINE | Cabin/rest durable-boundary/resume-or-safe-home contract | 2,31 | DONE definition only; four-field craft/home preference, fresh supported awake cabin/hatch, no saved flight/sleep pose. Earlier package passes retained; finite remaining cases below |
| RECOVERY-CREW-DEFINE | Seated crew durable-boundary/resume-or-safe-home contract | 2,31 | DONE definition only; settled solo crew saves four-field home-cabin preference; Resume wakes unseated with fresh cabin/hatch, no prior role or seat claim. Earlier ca0 crew pass retained; finite cases below |
| CREW-RECOVERY-INSTALLED | One installed crew interruption returns awake to the supported home cabin with activity/reward integrity | 2,31 | GATED final installed candidate plus one frozen supported craft/seat/cut; use existing crew selector, original caps and owned kill/reap/distinct restart |
| CREW-RECOVERY-ORDINARY | One ordinary crew admission→recovery→walk/helm-or-exit journey | 2,31 | UNSCHEDULED; freeze one supported craft/physical role and complete ordinary setup/continuation. Scripted ca0 package setup/escort is not this acceptance |
| RECOVERY-DOCK-DEFINE | Docking durable-boundary/resume-or-safe-home contract | 2,31 | DONE definition only; active solo assist retains home pilot preference; busy boarding/exit attempts unavailable. Fresh ownership replaces leases/pose; finite cases below |
| DOCK-RECOVERY-PROBE | Existing release driver can interrupt one actual accepted landing assist and check fresh safe-home recovery | 2,31,32 | DONE packaged311df73; existing loader/probe/runner docking+Convoy selector, full source and archive ELF kill/restart pass at original caps with fresh home-pilot control and exact terminal/reward boundary |
| DOCK-RECOVERY-CUT | One exact installed candidate survives interruption during actual assist with conserved activity/reward and usable safe-home recovery | 2,31 | GATED exact installed/final candidate. Source and archive-extracted 311df73 Bulwark/home/Convoy cut pass; no old lease/assist/seat identity restored. Ordinary/full installed acceptance remains distinct |
| DOCK-EXIT-RECOVERY-CUT | One interrupted exterior handoff recovers safely after accepted unavailable publication | 2,31 | GATED frozen actual busy-exit cut and executable driver; rejected publication retains prior durable preference. Completed grounded exit follows existing on-foot contract |
| RECOVERY-ACTIVITY-DEFINE | Active activity durable-boundary/resume-or-safe-home contract | 2,31 | DONE source map only on470aa24c4; progress/embodiment contract and two actual runtime gaps below. Four terminal-only active-resume policies remain explicitly unresolved; no original promise waived |
| ASTEROID-START-FRESH | Start Fresh durably abandons the interrupted active Asteroid Threading run | 13,31 | DONE packaged59c55cb: full production179/253.847s under original300; public title/live Start Fresh, refusal/retry, samegen IDLE/laterstream/cold Main and retained-owner/reward protections. Ordinary OS-input/interruption/final candidate remain separate |
| CINDER-SUPPLY-DEBT | Earned Cinder platform supply completion survives refused payment and cold restart | 13,31 | DONE packagedf8b5f86: genuine earned proof before payment; three actual-file child processes prove refused debt, one cold payment, paid replay fence and next generation. Active manifest reconstruction and Hauler stock policy remain separate |
| RECOVERY-PLANET-DEFINE | Planetary durable-boundary/resume-or-safe-home contract | 2,31 | DONE source map; Aurora/Rime visit restoration differs from Ember passive survey continuity. WORLD-SAVE per-world boundary and installed RECOVERY-KILL remain open; no broader location promise waived |
| RECOVERY-CUTS-DEFINE | Uncovered installed context/activity/OS-interruption cases | 2,31 | GATED; explicit state contracts and exact installed Linux package |
| SAVE-MIGRATION | Real-file valid migration with distinct-process reload | 31,32 | GATED; exact current format/fixture and uncovered case |
| SAVE-CORRUPT | Corrupt-data fallback and usable recovery | 31,32 | GATED; specified fallback, protected data retained |
| SAVE-UNSUPPORTED | Unsupported data refuses destructive overwrite | 31,32 | Future outer-envelope primary/tmp/bak source/Linux real-file case DONE4b66b3548: retained loaded authority and2fresh processes preserve names/bytes/modes. Other formats/native/installed scope remains GATED; no broad closure |
| CHECKPOINT-HELM-EDGE | Fresh paired playable command-delivery checkpoint | 6,32 | DONE; 2c73494, both exports/three startups/exact payload and archive checks |
| PACKAGE-FINAL | Exact final Windows/Linux package qualification | 6,32 | GATED; frozen final candidate, existing exports/inventory/startups |
| INSTALL-WIN-FINAL | Matching NSIS installer artifact/extraction identity | 32 | GATED; final package, native execution remains excluded |
| INSTALL-LINUX-CLEAN | Clean install on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| INSTALL-LINUX-UPGRADE | Upgrade on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| INSTALL-LINUX-ROLLBACK | Rollback on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| INSTALL-LINUX-RETAINED | Retained-data handling on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| INSTALL-LINUX-CORRUPT | Corrupt-data handling on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| INSTALL-LINUX-UNINSTALL | Uninstall on final Linux package | 32 | GATED; final package, accepted named earlier interruption cuts retained |
| LINUX-LAUNCH-DESKTOP | Installed desktop entry ordinary graphical play | 32 | WAITING; clean isolated graphical Linux session |
| LINUX-LAUNCH-DIRECT | Direct installed ELF ordinary graphical play | 32 | WAITING; clean isolated graphical Linux session |
| caption-presenter-forward-render | Registered capture set, 1 PNG | 12,33 | GATED; frozen candidate and original runnable harness |
| caption-production-forward-render | Registered capture set, 1 PNG | 12,33 | PARKED; supported changed environment/mitigation required |
| cinder-streaming-transition-render | Registered capture set, 24 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-berth-feedback | Registered capture set, 18 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-combat-visuals | Registered capture set, 7 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-hero-cell | Registered capture set, 18 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-jovian-freight-berth | Registered capture set, 2 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-jovian-freighter | Registered capture set, 4 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-player-motion | Registered capture set, 9 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-scenes | Registered capture set, 27 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-station-operations | Registered capture set, 7 PNGs | 12,33 | PARKED; supported changed environment/mitigation required |
| capture-varied-encounters | Registered capture set, 18 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| capture-zenith-visuals | Registered capture set, 7 PNGs | 12,33 | GATED; frozen candidate and original runnable harness |
| RIGHTS-DEFINE | Finite project/asset/source licensing families and missing documents | 34 | DONE as the [source-backed rights-family map](#rights-families-and-missing-documents--rights-define); definition only, no blanket rights clearance. Creator-permission account retained; project release terms and historical media redistribution documents remain distinct gaps |
| SIGN-FINAL | Trusted game/installer/uninstaller signatures and expected publisher | 34 | WAITING; trusted external certificate/credentials, exact artifacts |
| MATRIX-FINAL | Existing unfiltered local --mode all on one frozen candidate | 6,35 | GATED; targeted repairs/integration, original caps and no exclusions |
| FINAL-RECONCILE | All original promises and applicable final-candidate results | 2,35 | GATED; existing candidate record/SHA256SUMS, zero P0/P1 and reviewed P2 |
| DISTRIBUTE | Authorized publication and downloaded-byte identity | 34,35 | GATED; actual final acceptance and authorized destination |
| IDENTITY-TORRENT | Torrent B5 provenance/continuity tied-source claim | 36 | WAITING; registered evidence or exact external dependency |
| IDENTITY-ZENITH | Zenith B7 provenance/naming tied-source claim | 36 | WAITING; registered evidence or exact external dependency |
| IDENTITY-ARROW | Arrow identity tied-source claim | 36 | WAITING; registered evidence or exact external dependency |
| IDENTITY-JOVIAN | Jovian identity tied-source claim | 36 | WAITING; registered evidence or exact external dependency |

### Unknown scope and counting

The inventory contains accepted outcomes, broad families, dependencies and
qualifications. **It is not a remaining-job count.** In particular, “one craft,”
“one role” and “one recovery context” are selectors to resolve, not executable
assignments. Completing a definition does not deliver the gameplay it describes.

The [working roadmap](../ROADMAP.md#execution-now) selects the next exact
outcome and keeps failed/gated work separate. Remote operation/hull HUD plus physical hull/throttle
instrument repairs ship in pairedda1ae60; their broader parents remain open.
HELM-REVERSE-FLIGHT is source-qualified on52b228c86;
its source-only definition is DONE. CRAFT-GAPS-TORRENT definition found no concrete
required missing implementation in the inspected owners; Arrow/Jovian now also
have finite authored maps in COMPLETION_SCOPE.md. Their full craft/art/combat
acceptance and stronger historical identity claims remain open. No automatic
successor or qualification chain is scheduled. Cargo
boarding/departure/delivery and yaw turns retain their accepted source scopes.
Halyard BOARD is accepted on 4bc0e3b38 for its original source boarding card.
Cargo reload retains its recorded failure and reopen condition. Recorded yaw/
handback and standing PASSENGER HUD are accepted on007024839; other action-specific
handback/native/device/endurance cases remain open and are not automatic next work. All36 original parents and ten phase
gates remain open. Local scheduling is not a whole-project estimate.

A DEFINE row must end in a finite list/contract or an exact missing fact, with
no engine run unless separately scheduled. Expand its existing parent here only
with actual uncovered outcomes. In particular, the eight BUILD-SPLIT rows are
placeholders for future capability cards, not eight complete ship builds.
Weapon/damage cells, historical relationships, presentation defects, repeated
activity/write/save cases, adverse network profiles, performance measurements,
readability cells, audio scenarios, installed interruption cuts and family-specific rights/document
dispositions still have unresolved multiplicities. **A defensible whole-project
remaining-job count and completion date are therefore not yet available.**
No new validator, tracker or evidence chain belongs to this decomposition.

## Family contracts

These existing contracts retain their original acceptance and stop boundaries.
Select a named child in ROADMAP.md before executing a family instance.

## Baseline and ordinary controls

<a id="remaining-tasks-to-complete-the-project"></a>
<a id="0-fix-the-release-scope-and-assign-the-completion-work--all-phases"></a>

Scope: original §0–1 and retained milestones; Phases 2, 9 and 10.1. These are separate tasks, not a requirement to finish the whole baseline before delivering one repair.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| SCOPE-DECISION[one unresolved roster/limit] | DEFINE; production roster | Resolve one finite omission or propose one explicit scope decision with affected original promises. Stop at recorded decision or named owner input; no silent deferral. |
| PLAN-ASSIGN[one selected child] | ELIGIBLE; selected task | Fill the task card, owner, dependency, actual check and estimate. Stop when that child is executable; do not manufacture a release date from task counts. |
| BASE-DIAG[one failing suite] | ELIGIBLE; failure table below | One hypothesis/probe identifies the first failing boundary and production owner, or a specific blocker. Stop before unrelated diagnostics. |
| BASE-FIX[one reproduced defect] | GATED on diagnosis | Change the runtime/content owner and pass the affected original check without relaxing limits. Stop after relevant integration and required checkpoint; full matrix is MATRIX. |
| GUIDED[chosen combined package] | Current checkpoint3d92b91 PASS3/3; a changed exact candidate needs its own selection | Pass original Guided ordinary-input route 3/3 in fresh processes/profiles, unchanged shutdown timing. Stop at those three runs; old e085 passes remain source-specific. |
| SANDBOX[recovery-walk/reuse boundary] | GATED on supported input-pacing/runtime fix; ca0 retained log shows only0.20s of responsive recovery turning before deadline, no geometry-block proof | Complete the original all-nine-craft/station/combat/crash/recall/reuse route at its original 300s cap, without rescue. Preserve all 54 waypoints, eight initial excursions and occupied-berth criteria; stop on complete route or first concrete failure. |
| SETTINGS-INPUT[original artifacts] | WAITING on runner/profile/logs | Recover exact originals and identify their provenance; otherwise leave acceptance blocked with a precise handoff. No substitute promotion. |
| SETTINGS-RUN[original route] | GATED on recovered inputs and any focused fix | Complete original Settings/re-entry route, including gamepad return and intended mouse observation. Writer-only success is insufficient. Stop at original route result. |
| LIFECYCLE[chosen candidate] | ELIGIBLE; implementation already delivered | Run existing four-cycle `lifecycle_phantom_geometry_test.gd` and twelve-cycle `long_session_soak_test.gd` unchanged on selected source/package. Stop at those checks; fix a demonstrated defect separately. |
| CONTROL-FIX[one observed input/help defect] | GATED on reproduction | Correct one camera, steering, braking, hover, landing, prompt or tutorial problem. Demonstrate the same ordinary-input action before/after; stop after focused route and checkpoint. |

The last full matrix's eleven failed suites are below. `BASE-DIAG` selects **one** row, never all rows in one assignment. Later checks are historical scoped facts, not final baseline acceptance.

| Suite / exact existing filename under `tests/` | Last known boundary / next justified action |
| --- | --- |
| `bulwark_game_flow_registration_test.gd` | Historical Forward+/llvmpipe300s timeout remains. E3 unchanged current default passes20 headlessly on2983a2be7; no default registration defect reproduced. Capture and graphics cause remain open; retain catalog graphics classification and cover original suite in a future combined matrix. No unchanged isolated retry. |
| `cargo_delivery_production_integration_test.gd` | Full matrix timed out; later 418 source/package completes 124 assertions. Include in next combined matrix; do not rerun unchanged isolated merely because the older matrix failed. |
| `cinder_convoy_session_save_restore_test.gd` | Original300s single print-only probe on c2ad94184 passes70 checks;17th Main returns298.534s before first `missed_abort` check. Synchronous Main add_child192.606s across17 lifetimes; no game assertion error. Qualification remains FAIL. No Convoy-specific culprit/different avoidable startup change identified; parked, no unchanged retry/profile. Raw: `/srv/mudds-work/convoy-position-probe-results-20261017/`. |
| `cinder_patrol_session_save_restore_test.gd` | Q4 original300s probe on `e8f24ff00` completes18/30 Main lifetimes, stops after19th synchronous startup before fresh-IDLE assertion69. Historical17th retirement/save passes; repeated station/fleet readiness dominates. Q4-FIX targets runtime startup; full suite remains FAIL. |
| `cinder_race_session_save_restore_test.gd` | Print-only source dd38c163f original300s diagnostic completes81 assertions,19 Main lifetimes; synchronous attach totals212.821s. Deadline expires during19th retirement begun299.268s, before fresh cold-IDLE verification. No game assertion failed before cap; no specific avoidable production hotpath identified. Diagnosis complete; full suite FAIL. No unchanged retry or cap/assertion reduction; a measured production startup change is needed before further qualification. [Actual result](history/ROADMAP_DELIVERIES.md#branch-accountability-and-race-timeout-diagnosis--2026-10-20). |
| `game_flow_ember_surface_presentation_integration_test.gd` | Original full300s print-only diagnostic24647a179 on current6acc baseline times out:90 checks pass/no assertion failure; retired completes221.732s, local_loss268.846s; session host-session begins299.975s at cap. Later newer/replacement scenarios unentered. Full suite remains FAIL; no runtime defect/fix proven. Diagnostic source bundled, owned scratch removed; no unchanged retry or cap/assertion reduction selected. |
| `game_flow_scan_durable_recovery_test.gd` | Half-second retry fixed; later full suite still times out after 96 printed passes. Diagnose remaining boundary. |
| `session_recovery_resume_offer_test.gd` | Q5 original300s probe on `df66dcded` completes Main16 real-file recovery, then expires at Main17 next passenger interaction (fixture line631) after151 passes. Main18/19 unentered; inner await unresolved. No recovery defect/fix proven; do not repeat unchanged. |
| `game_flow_rime_client_pad_controls_test.gd` | On3e39ed8da corrected headless run first scenario completes, return17.099s; second held-edge starts264.733s and still progresses at291.862s before original 300s timeout. Diagnosis above; preserve180 edge waits/1,440-tick exposure and100 jump waits. Next: reduce a measured production hotpath, then affected original checks; no unchanged rerun or timing relaxation. |
| `network_emberline_bolt_test.gd` | Retained failure waits on later dead-peer baseline before reset; pending-generation errors follow. Q1 isolated `e026cf620` instrumented probe passes 154 under original limits, so no repair/root cause is proven. Retain old matrix FAIL; cover next combined matrix without another unchanged isolated run. |
| `station_light_overlap_census_test.gd` | Historical expected rows/environment unresolved; mismatch repeats on its own freeze. Recover measurement basis before changing expectations; never replace hashes just to pass. |

### Packaged ordinary lifecycle — LIFE-PACKAGE-DEFINE

Definition DONE by source/contract review, 2026-10-20; no engine, test or package
run. LIFE-VISIBLE and LIFE-REUSE remain accepted on d7be01487 in their recorded
source scopes. The existing four-cycle phantom audit and twelve-cycle soak are
not ordinary packaged journeys: both inject MemoryFilesystem and instantiate
Main directly; the soak shortens boarding motions, forces completed-guide state,
stages the home approach, injects damage and detaches/re-adds the same Main for
save/re-entry. The phantom audit also stages cabin/bunk traverses. Its visible
renderer census is a scene-tree contract, not a rendered-image review.

Only these remaining lifecycle outcomes are identified; reuse existing children
rather than create another fleet/cycle matrix or automatically schedule runs:

| Existing outcome | Uncovered packaged ordinary completion | Dependency / exact runnable boundary |
| --- | --- | --- |
| GUIDED-FINAL | Original Guided sortie, landing, neutral shutdown and physical exit, 3/3 fresh processes/profiles on the chosen final package | Final package GATED. Existing `tools/release/run_native_sortie.py BINARY --output DIR --route guided` supplies OS input/default samplers; retain original shutdown timing and earlier package-specific passes. No missing driver inferred. |
| SANDBOX-RECOVERY | Full original nine-craft/54-waypoint route, eight initial excursions, actual crash, same-player recall, occupied-berth regeneration, supported recovery walk and craft reuse, 1/1 within original300s | PARKED; `--route sandbox` exists, but retained run expires before reuse. A supported changed input/runtime cause is required before selection; a shortened reuse-only continuation cannot accept the failed full route. |
| CRAFT-ACCEPT-* / CRAFT-ROLE / RECOVERY-CABIN-DEFINE / CREW-RECOVERY-ORDINARY | Applicable ordinary hatch/chair/bunk walk, sit/action/sleep/wake/stand, helm-or-exit, landing/reuse and cross-craft continuation without staged aisles, damage or return poses | Freeze one supported craft/physical role and its complete journey; existing focused/staged checks do not provide a full package OS-input command. The native sortie selector has no fleet cabin/bunk/crew acceptance route. Preserve accepted Habitat loop/restart and all recorded crew scopes; Bomber role interpretation and parked Halyard boundaries remain dependencies. |
| SETTINGS-RETURN / existing RECOVERY-KILL and installed recovery children | Ordinary save/quit or owned interruption, distinct-process continuation with usable controls and conserved activity/reward/data, according to each settled context | SETTINGS-INPUT originals remain WAITING; installed cuts require their exact candidate/context/driver. Same-Main memory-store detach/re-add is not disk restart. Habitat restart and named accepted recovery cuts remain DONE; this definition neither duplicates nor reopens them. |
| LIFECYCLE[chosen candidate] | Packaged repeated sortie/activity/cabin/recovery/Main transitions retain clean quiescent presentation and bounded resources, with usable controls between transitions | Source four/twelve-cycle checks remain unchanged anchors. No existing native-sortie selector combines ordinary repeated cycles, cabin/bunk, Main re-entry and the lifecycle resource/renderer observations. Missing seam: one declared package ordinary-input route and its observation/rest-state sampling boundary, with original repetition/resource limits retained. No command or ordinary-pass claim is invented here. |

The original normal-controls contract remains Guided3/3, Sandbox1/1 and
Settings/re-entry1/1, plus all applicable craft/station/crew/combat/recovery
requirements; this definition closes none of them. Repeated activity rewards,
network endurance, capture sets and native GPU/device/audio/human reviews retain
their own existing owners and gates. No new runtime defect or implementation is
established, no source pass is rerun, and no automatic successor queue follows.

## Station, craft, combat and presentation

Scope: original §2 and §7; Phases 1, 3–6 and 10.3. A component pass does not close a whole craft or station.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| HIST-CLAIM[one identity/topology claim] | WAITING where source evidence is missing; otherwise DEFINE | Resolve one Torrent B5/Zenith B7 provenance or continuity claim, Zenith naming, Arrow/Jovian identity, or station adjacency/scale/version/ladder relationship. Record supported facts, source views and unknowns. Stop at a bounded specification or exact external evidence request. |
| STATION-MODULE[one supported module/interaction] | GATED on evidence/specification | Build one justified room/connection, or climb interaction only if required by resolved ladder scope. Ordinary walk/Interact reaches it; visible structure and collision agree; preserve berth/hull clearance. Stop after that module and checkpoint. |
| STATION-ROUTE[one named branch] | ELIGIBLE for implemented branch | Walk Central, Aft, Habitat, Freight, Fleet Dock, Annex, Observation, Salvage or evidence-permitted VIP as one instance. Use existing station playability/interaction routes. Stop at complete branch or first reproducible blockage; do not add unsupported topology. |
| STATION-ART[one actual finding] | GATED on identified view/defect | Replace one placeholder or correct one room/furniture/material/signage defect. Compare fixed player-height views and affected walk/collision/berth budgets after streaming/rebase. Stop at that finding. |
| STATION-LIFE[one behavior] | ELIGIBLE for authored tow/gantry/service-arm/patrol routes | Qualify one Central tow, Freight gantry, Aft service arm or Habitat patrol behavior in ordinary play with `station_operations_activity_test.gd` as applicable. Repair only a demonstrated issue; do not replace delivered rails. |
| CRAFT-ART[one craft/component] | GATED on design/evidence and one named finding | Finish one hull, cabin/access, character animation, material or LOD component. Check authored role readability, boarding/clearance and affected gameplay-distance views/budgets. Stop at the component and checkpoint. |
| CRAFT-ROLE[one craft/role] | ELIGIBLE for implemented role | Complete ordinary walk/Interact/sit/action/stand/exit and appropriate moving-craft recovery. Reuse existing role tests; do not reimplement delivered roles. Stop at the named route. |
| COMBAT-SLICE[one craft/weapon/encounter] | GATED on named supported scenario | Exercise its applicable hit/miss/occlusion, refusal/ammo, damage/repair, destruction/regeneration and return to use through existing owners. One weapon/encounter per assignment; stop after its original scenario and checkpoint. |
| ART-FINDING[one view/effect/transition] | GATED on concrete finding | Fix one whole-game art-direction defect in UI, effects, lighting, animation or transition. Preserve gameplay readability and budgets; compare the same before/after view and affected route. Stop at that finding, not an unbounded art pass. |
| ORIGINAL-SPEC[one missing craft] | WAITING on evidence or explicit interpretation decision | Produce one bounded craft specification using supported facts and honest unknowns; record external dependency if insufficient. Stop before invented historical claims or unapproved interpretation. |
| ORIGINAL-BUILD[one specified craft capability] | GATED on ORIGINAL-SPEC | Deliver one named capability through existing source-art/definition/berth/boarding/flight/weapon/role/damage/recovery owners, with focused scenario and checkpoint. Instantiate remaining capabilities separately; full craft acceptance still required. |
| CRAFT-ACCEPT[one completed craft] | GATED on all promised capabilities | Run that craft's full fleet scenario: access/roles/flight/combat/damage/recovery/reuse and art/limits. Stop at named craft result, not the entire fleet. |

Original fleet remains Torrent, Arrow, Jovian, Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia, Salyut and Zenith. Missing definitions: **Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia and Salyut**. Instantiate ORIGINAL-SPEC/BUILD/ACCEPT per craft. Four original-inspired candidates plus five modern designs do not finish the twelve-original commitment. Modern interpretations require explicit scope decisions and honest labels.

### Fleet access and reuse — shared acceptance boundary

WALK-FLEET source handoff on995fb9621 resolves the roster, not acceptance.
`FleetDockComb` has three assigned docks with world-owned Zenith, Halyard and
Bulwark berths. Its Dock03 historical landmark key is not a deferred berth.
The original “Fleet comb and all shipped craft berths” requirement also demands
physical reach and reuse of every shipped craft, separated voids/neighbour
clearance, fleet overview and player-height review. Current shipped roster:
Torrent, Arrow, Jovian, Zenith, Halyard, Bulwark, Cinder Light Interceptor,
Cinder Cargo Hauler and Cinder Long-Range Bomber.

Use the existing nine `CRAFT-ACCEPT-*` journeys for reuse; do not create another
fleet matrix. LIFE-ARM's Zenith approach and `SandboxPilot.begin_craft()` supply
route references, not full all-shipped acceptance. Missing runnable boundary:
a supported ordinary-package reach/reuse command mapped to those existing
journeys and their required interactions. Threshold walking alone cannot close
this requirement. Preserve the original parked Sandbox all-nine/54-waypoint,
crash and reuse route unchanged; a renamed shorter selector cannot replace it.
The earlier two-client HALYARD-BOARD failures established no solo Fleet walking
blocker; accepted boarding does not qualify all-fleet walking, and this source review found no separate solo access defect.

If a concrete full route is selected later, extend only the existing startup
selector guard, read-only native-sortie observer, OS-input driver and focused
Python checks. No new route, engine run, gameplay repair or checkpoint was
selected by this handoff; overview/native/player-height review remains open.

### Station presentation — finite review boundaries

STATION-FINDINGS source slice2026-10-18 on df3e71d4e: root inspected the living
service owners; one medium read-only mapper inspected wayfinding and branch
interaction bindings. **No supported new implementation gap was established in
those seams.** This defines where to inspect next; it does not accept the visual
quality of any branch or complete parent9/12. No engine, capture or walking route
was run. Existing passes and parked failures retain their original sources.

Select **one existing branch and one view/state** below per review. A review
ends with either a reproducible named defect or an explicit no-finding result
limited to that view. A defect card must state before→after, exact runtime owner,
protected route, focused check and fixed comparison view. Do not assign “finish
station art”, generate arbitrary new dressing, or treat source counts as visual
acceptance. Minimum graphics, ultrawide and reduced-motion/flash views remain
part of original parent acceptance; schedule each actual uncovered cell explicitly.

| Existing branch | Bounded player-facing view / state to inspect | Runtime owner / protected outcome |
| --- | --- | --- |
| Central | Standing spawn directory and adjacent tow/cargo presentation while approaching the berth | `shipyard_world.gd`, `station_wayfinding_signage.gd`; readable destination and berth access; existing CENTRAL-VIEW capture stall stays parked |
| Aft | Lower operations-room console line from its actual doorway; separate upper stair/workpost view remains uncovered | `aft_junction_stack.gd`, world Aft activities; consoles are downstairs, not visible through the upper floor. Isolated console image attempt PARKED120s/no image; preserve stair/door clearance and distinct Activity/Destination controls |
| Habitat | Bunk/common-room arrival and garden/observation doorway | `habitat_spine.gd`, world patrol/skywatch; preserve accepted ordinary loop, usable bunks and wake controls |
| Freight | Service-room entrance and gantry beside the actual boarding approach | `jovian_freight_berth.gd`, world Freight activities; readable service/boarding destinations and operable unlocked door |
| Fleet Dock | One named berth threshold from its actual approach | `fleet_dock_comb.gd`, `fleet_expansion_berths.gd`; correct craft destination and boarding/landing clearance; choose berth before reviewing |
| Annex | Restock console from the supported central aisle | `fabrication_annex.gd` geometry and `shipyard_world.gd` console owner; existing service text/control and clear aisle; unfinished south gate is not a promised destination |
| Observation | Cross-landing view toward one named Observation/Logistics pad | `observation_logistics_spur.gd`; correct pad destination and supported return |
| Salvage | One inspection-pad view after supported arrival | `salvage_terrace.gd`, `salvage_inspection_station.gd`; three-component contract retained; physical access/revisit remains parked/gated |
| VIP | Reception arrival view after supported access | `vip_reception_suite.gd`; existing route/evidence boundary retained; parked VIP walk is not reopened by this list |

**Habitat common-entry view: PARKED, not reviewed.** Source8a6339b91 fresh
import20.652s passes; one full-Main Forward+ software readback times out180.842s
before PNG or measured-eye metadata. Renderer startup is logged, but the exact
blocking lifecycle/draw boundary is unobserved. No geometry, lighting or camera
runtime defect is established. Existing integrated capture y2.55 exceeds the
standing body height and cannot replace the selected measured-eye view; isolated
chair renders do not establish full-Main lighting/arrival. No retry, cap increase,
other-room replacement or no-finding claim. A supported capture-boundary change
must precede a separately frozen attempt; same full-Main path under another room
name does not reset this failure. [Actual result/cleanup](history/ROADMAP_DELIVERIES.md#habitat-arrival-view--readback-timed-out-before-image).

All file basenames above resolve under `scripts/world/`. This roster reuses the
nine existing WALK branches; it adds no station rooms, historical claims or
unbounded art multiplicities. The full remaining-job count is still unknown
until actual findings and original scope dependencies are resolved.

The four existing LIFE cards have concrete owners in
`ShipyardWorld.STATION_ACTIVITY_SPECS`: LIFE-TOW→CentralTowServiceActivity,
LIFE-GANTRY→FreightApproachGantry, LIFE-ARM→AftOperationsActivity and
LIFE-PATROL→HabitatServicePatrol. Their `StationOperationsActivity` owner already
advances deterministic presentation clocks, supports enable/pause and publishes
world-owned solid lifecycle changes. `StationServiceAgent` already resolves
courier routes from the station graph; no general autonomous logistics promise
is inferred. Existing component/navigation checks protect these contracts;
they do not replace the ordinary nearby walking/boarding acceptance of each LIFE
card. No new animation or authority layer is justified by this source slice.

Wayfinding already substitutes the actual Aft Activity/Destination console
positions, attaches real expansion berths and refreshes deferred placement.
`tests/station_wayfinding_test.gd` already covers facing, collision/door clearance,
marker/berth changes and rebases. Fabrication's empty landmark list deliberately
excludes an unfinished endpoint. A repair now requires an observed wrong/missing
sign, inaccessible signed destination, failed interaction or other concrete
view defect with exact location/state. Do not add a parallel signage validator
or rerun blocked rendered captures without their concrete reopening condition.

## Activities and planetary journeys

<a id="phase-8--nearby-world-and-activities"></a>
<a id="4-visitable-planets-with-complete-atmosphere-to-surface-loops"></a>

Scope: original §3, retained abandonment milestone and Phase 8/10.4 specifications. Shared journeys use WORLD-SHARED below, not a duplicate queue.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| ACT-HUD[Race, Patrol, Cargo or Convoy] | ELIGIBLE; one family selected | Verify reset/select/start and fresh-Main presentation against durable state; fix one actual discrepancy. Stop after that family's route, not all four. |
| ACT-WRITE[one activity/boundary] | GATED on uncovered failure boundary | Exercise one real write failure at ACTIVE, earned-unpaid, paid/reset or refused/reset; fresh process observes once-only durable rewards and usable recovery. Reuse existing lifecycle tests; stop at named boundary. |
| ACT-PLAY[one nearby activity] | ELIGIBLE for implemented content | Ordinary outbound travel, actual activity, reward and home return work at canonical distances. Stop after first full play or first reproduced defect; repetition/endurance is ACT-REPEAT. |
| ACT-REPEAT[one activity] | GATED on ACT-PLAY | Complete its existing repeated-use/endurance scenario with once-only rewards and clean actors/state. Stop at that scenario's original duration, not a new arbitrary loop target. |
| TRAVEL-LIMIT[one nearby route] | Beacon outbound60s agreed2026-10-21; execution selected | Preserve existing clock/start/stop/route below; implement observations and qualify actual elapsed time without changing whole-sortie cap. Other routes retain scope. |
| HULK[physical salvage/power/revisit] | Arrival, breaker and home ordinary-input qualification DONE; revisit/disk gates open | Existing interior83 scoped checks retain their limits. Full ordinary Guided/HULK/breaker/reverse walk/reboard/home route driver7e251f8af/gameef67f3e95 passes 191.886s at original300s cap, actual unload and once-only receipt retained; checkpointef67f3e Linux is exact tested binary. Windows payload startup/privacy passes separately; strict payload parity fails65 generated scenes. REVISIT-CONTRACT DONE; REVISIT-INPUT candidate5010ef932 FAILED optional-lift driver condition; REVISIT-DEPARTURE candidate2298e4889 FAILED original300s deadline during new interior walk after actual reload/dock/exit; no fresh breaker event. Candidate withheld; REVISIT-CHECKPOINT GATED; independent Ember ABANDON source qualification subsequently DONE; no HULK repair selected in ROADMAP.md; no unchanged interior rerun or full-parent closure. |
| WORLD-CONTENT[one world/gap] | DEFINE if missing content not named | For Ember, Aurora or Rime, name one finite missing environmental/content behavior from the original specification and roster. Implement that behavior in a separate bounded child with ordinary surface interaction and checkpoint. Stop at specification or named behavior, not a new planet catalogue. |
| WORLD-SOLO[one world] | ELIGIBLE for implemented world; existing physical route | Complete canonical outbound, atmospheric descent, physical landing/exit/activity/reboard, ascent and home dock through ordinary controls. Preserve original route/physics limits; staged arrival is not acceptance. Stop at one world's full route or first defect. |
| WORLD-ABANDON[one world] | GATED on WORLD-SOLO route | Qualify delivered abandonment/home-return fixes in full integrated-source and packaged journey, including physical walking/docking/reuse. Ember integrated-source ABANDON DONE on e85157b4d: exact31, exit0, physical outbound/abandon/reboard/ascent/home occupied dock/walking, MemoryFilesystem, original7200s cap. Packaged journey/reuse/disk gates remain open; earlier ec457/6e1 scoped passes are not this full parent gate. Stop at named scenario; no unchanged source rerun. |
| WORLD-SAVE[one world/boundary] | GATED on named expected resume/safe-recovery contract | Save/reload or real interruption retains visit/survey/reward/reboard state once and returns to usable play. Stop at one boundary. Rime df862 staged/in-process 78-pass restoration is delivered; it does not qualify canonical journeys. |
| WORLD-EDGE[one world/case] | GATED on baseline route and scenario definition | One solo cancellation, refusal, failure, repeat visit or interruption case preserves physics, rewards and return to use. Stop at one case; shared late join/disconnect belongs to WORLD-SHARED. |

Route anchors include `tests/ember_transit_movement_soak.gd`, `tests/aurora_physical_return_soak.gd --aurora-full-roundtrip`, `tests/ember_abandon_return_manual_override_test.gd` and the existing Rime landing/survey routes. Resolve the exact existing command in the task card before running; never substitute a staged route for a canonical one.

### Beacon outbound travel envelope — approved60second maximum

TRAVEL-LIMIT[Beacon outbound] / parent13, source-only definition on2026-10-20.
**Owner-approved2026-10-21:60.0s maximum unpaused monotonic elapsed time.**
The choice is settled; its actual ordinary-flight timing remains to be qualified. Original
Phase8 requires a maximum station travel-time envelope, and the retained parent
requires an agreed normal-flight maximum. This proposal supplies one bounded
instance; it neither closes that family nor removes return/other-route promises.

| Contract field | Proposed single-leg criterion |
| --- | --- |
| Start | First ordinary engine-start/launch input after the same pilot is seated in the default Torrent at its occupied home berth. Include engine startup and physical departure; do not start only after a distant departed receipt. |
| Stop | First live, unpaused, same-craft physical approach within the production first-Beacon32m radius at speed≤0.45m/s, with valid pilot controls. The retained driver approaches more tightly,≤12m; that driver detail is not a new production activity-start requirement. |
| Clock | Unpaused monotonic elapsed seconds. Subtract only explicitly recorded paused intervals. Engine loading before Start, station walking/boarding and activity UI/objective time after Stop are outside this leg. In-leg CPU/GPU stalls still count; simulation ticks are reported separately and cannot substitute for elapsed-time proof. |
| Route / controls | Actual fresh occupied Torrent home berth → live transformed first Beacon; default authored tuning/input sampler, normal thrust/steering/brake, no boost, teleport, recovery, debug navigation or staged movement. Reject a failed/destroyed/recovered run rather than restart its clock. |
| Scope | One outbound leg only. Ordinary Beacon traversal/payment/home and every other required activity/return limit remain open in their existing children. No new engine attempt, parked UI route, environment qualification or300s whole-sortie cap change is selected. |
| Next after decision | Freeze exact package/ordinary driver, add start/stop/pause monotonic observations to the existing route if missing, and select its timing proof with original safety caps. No new validator, alternate route or accepted full PLAY-BEACON claim. |

**Execution selected2026-10-21:** existing `run_native_sortie.py` gains optional
`--qualify-beacon-outbound`, valid only with `--route beacon-home`. Fixed60.0s;
start immediately before the first engine-demand launch output (including mouse,
steering or brake when production would start the engine), while OFFLINE/seated
at the original occupied home berth. Observe every raw sample on one Python
monotonic clock at receipt: this is a conservative upper bound including IPC and
stalls. Reject every in-leg pause rather than estimate subtraction. Bind actual
process/actors and unchanged default controls/tuning; reject lifecycle failure,
recovery and issued boost inputs. Existing observer does not expose boost state;
qualification relies on this isolated driver's sole issued input and reports that
scope. Stop on the first live32m/0.45m/s qualified sample while leaving existing
12m approach steering unchanged. Keep original full beacon-home acceptance and
300s cap (independent330s supervisor). Reuse accepted c2c72a2 ELF; no game edit or
duplicate checkpoint export. One bounded implementer owns driver/tests, one
independent reviewer, root owns integration and the silent isolated actual run.
Stop at first reproduced failure; no route/cap/tuning relaxation or parked retry.

**Source and retained-record basis, not a new flight:**

- `scripts/world/cinder_beacon_traversal_activity.gd` authors the four Beacon
  centres(16,-9,-240),(32,-26,-372),(46,-44,-498),(30,-46,-600), each radius32m.
  First Beacon is230.779m from the accepted Torrent parked position
  (0,1.15,-10); the four-centre path including that first leg is596.141m.
  These are Euclidean distances, not measured flown paths. GameFlow's
  `_cinder_authored_frame_to_world` resolves the live/bootstrap/rebased frame;
  do not use raw authored positions after a common-origin shift.
- Default Torrent in `scripts/ships/hero_ship.gd`: speed cap82m/s,
  thrust34m/s², brake48m/s², passive drag2.8m/s². The Beacon driver uses ordinary
  thrust/brake without boost. A speed cap is not guaranteed cruise or a timing
  proof. Its approach brakes at v²/(2×brake)+0.18v+10m;
  forward thrust requires aim alignment>0.72.
- Accepted checkpointe06550e record
  `/srv/mudds-work/beacon-settlement-20261019/results/ordinary-settlement/result.json`
  retains launch stage frame776, departed924, stopped approach1353. Authored
  physics60Hz implies577/60=9.6167 simulation seconds from launch-stage record
  to approach,429/60=7.1500 from departed receipt. Launch-stage is not a retained
  monotonic timestamp of the first launch input; neither interval proves the
  proposed wall clock. Actual approach distance10.535m is inside both radii.
- The complete driver63.879s includes startup, walking, boarding, paused UI,
  traversal/payment and observation. It is not this leg's travel duration.
  The30s proposal is an engineering pacing target informed by short distance and
  that single simulation-time observation, not measured wall/native/human proof.
  Native hardware, manual usability and original full journey gates remain open.

No runtime edit, engine, package or temporary file was needed for this proposal.

### Activity first play — bounded handoffs

Reworked on2026-10-19 from sourceeaa8954cc. This is the requested planning
breakdown, not newly accepted gameplay. The twelve PLAY-* rows above describe
specific complete journeys; the next assignment selects one useful checkpoint
inside a journey. Completed KIT milestones and all existing failures stay intact.

| Checkpoint to select | Player-visible result / completion check | Ownership and stop |
| --- | --- | --- |
| Ordinary launch and activity admission | From actual menu/on-foot boarding and berth departure, reach the named physical start and activate the correct authored activity through supported controls. Record craft, route/branch, generation, objective and actual start position. No activity completion is claimed | Root owns route selection/integration; one implementer owns only the selected existing route driver. Stop at the first valid activity start or first discrepancy. No teleport, direct board signal or synthetic checkpoint may substitute for ordinary entry |
| Actual activity and settlement | Continue the accepted entry through that row's physical gates, dwell, transfer, escort or combat; observe the real terminal state and exactly one corresponding durable reward/capacity receipt. Preserve unrelated store data and existing timers | Existing GameFlow/binding/activity/board and GameFlowRewardAuthority remain production owners. Assign only an observed runtime defect to its actual owner; stop at settlement or first failure. A mocked kill, fast-forward or injected terminal state is not acceptance |
| Home and usable continuation | Continue the earned run to the real home berth, successful dock/lease, supported exterior exit and usable movement or on-foot board. Final PLAY acceptance must retain the complete ordinary route on one candidate | Extend the same route's return/cleanup only. Being within140m of home is insufficient. Stop at usable home continuation; real-file cold restart and ten-run endurance remain separately named work |

These are handoff boundaries, not three automatically created jobs per activity.
If a complete existing route already proves multiple checkpoints, retain that
proof without rerunning or splitting it into artificial deliveries. A source
change affecting an earlier checkpoint requires relevant regression coverage;
separate old-source partial passes do not establish a final integrated journey.

**Driver readiness is a real prerequisite.** The inspected Race, Threading,
Patrol, Cinder Supply, Scan and Beacon tests provide staged integration/owner
checks, not demonstrated complete ordinary commands. Existing
`tests/nearby_sector_flight_review.gd` stages boarding and finishes near home;
`tools/release/run_native_sortie.py` now provides `--route beacon-entry` and
`--route beacon-settlement`; packaged e06550e accepts ordinary entry, all four
physical beacons and durable payment. Home return remains unproven, so neither
driver yet proves a complete PLAY-* journey. Reuse the ordinary
boarding/departure/home pattern in
`tests/cargo_delivery_production_integration_test.gd --ordinary-jovian-kit-deliver`
where appropriate; its kit delivery does not prove Cinder supply. A new ordinary
route selector is executable release capability, not a new evidence validator.

| Journey / existing production and regression seam | Constraint to freeze for its next checkpoint |
| --- | --- |
| Race / GameFlow, NearbySectorActivityBinding, `assets/activities/cinder_reach_checkpoint_route.tres`; `tests/cinder_activity_integration_test.gd` | Actual five-checkpoint route. Main countdown2s, standalone binding countdown3s, both timeout120s; do not transfer fixture timing to the production owner |
| Threading / NearbySectorActivityBinding, GameFlow asteroid session, `assets/activities/cinder_asteroid_field_threading_run.tres`; `tests/cinder_asteroid_field_test.gd` | Five physical gates,30m entry; retained source persistence/reset checks do not establish ordinary flight |
| Patrol / GameFlow, PatrolActivity, `assets/activities/cinder_reach_platform_patrol_route.tres`; `tests/patrol_production_integration_test.gd` | Choose relay or platform branch before work. Existing full-suite construction failure remains parked; another branch name does not reset its budget |
| Cinder supply / NearbySectorActivityBinding, CargoTransferAuthority, CargoDeliveryActivity; `tests/cinder_cargo_activity_bridge_test.gd`, `tests/cinder_cargo_reward_handoff_test.gd` | Ordinary Jovian arrival/occupied Cinder berth establishes initial two-crate source; start, depart capture volume, redock and transfer one. Actual consumer accepts Jovian only; no Hauler access workaround |
| Mining / GameFlow, CinderMiningPlatformActivity, CinderMiningCapacityPersistence; `tests/cinder_mining_durable_recovery_test.gd` |30m approach and6s extraction, capacity receipt rather than invented ore/currency. PLAY-MINING remains parked at board-focus failure before extraction |
| Scan / GameFlow, CinderAbandonedStructureScanActivity, discovery persistence; `tests/game_flow_scan_durable_recovery_test.gd` |24m approach and4s physical scan. Retained full Scan timeout is not reopened by this breakdown |
| Beacon / GameFlow, CinderBeaconTraversalActivity; `tests/game_flow_beacon_durable_recovery_test.gd` |32m first-beacon start and four physical beacons in order. Existing durable recovery fixture is an owner anchor, not ordinary traversal |
| Jovian kits / GameFlow, CargoDeliveryActivity, JovianCargoSessionPersistence; `tests/cargo_delivery_production_integration_test.gd` | KIT-BOARD/DEPART/DELIVER already accepted; do not reschedule them. KIT-RELOAD remains parked under its original30s cap |
| Convoy / GameFlow, CinderConvoyEscortHost; `tests/cinder_convoy_production_integration_test.gd` | Use retained Main host and real tender/threats, not a standalone streamed fixture. Preserve existing Convoy failure/reopening conditions |
| Defense / StationDefenseActivityBoard, authored perimeter scenario; `tests/station_defense_production_placement_test.gd` | Physical deployment and real three-wave combat. Do not conflate this activity with unresolved COMBAT-PERIMETER catalog/launch mapping |
| Breach / HeavyBreachActivityBoard, EncounterScenarioDirector; `tests/heavy_breach_game_flow_production_route_test.gd` | Existing production owner/admission fix is accepted. Actual combat/return is still uncovered; staged kills do not fill it. BREACH-INTERRUPTION earned-debt case DONE c78e0ac |
| Torpedo / same board/director, TorpedoBoatOpponent; same production route fixture | Reach posted Torpedo through ordinary alternating sorties; no direct director selection. A successful clear/home does not prove fail/abort/authority/restoration |

**Estimate and stop rule:** allow15–25min source mapping to freeze one actual
driver seam/command and prerequisite; then separately estimate the bounded driver
or observed production repair, normally30–60min implementation and10–20min focused
checks. Split before90min. These are planning allowances, not measured full-route
durations or permission to raise any existing cap. Freeze the actual command,
candidate, unchanged deadline and expected checkpoint before its first engine
run. A meaningful accepted runtime checkpoint additionally needs the normal
paired builds/startup/package checks (allow10–15min); driver-only work gets the
applicable release-driver check and does not imply a new gameplay build.
First failure ends that attempt. Retain the original route and cumulative
failure history before selecting any causal repair. All twelve journeys, repeat
contracts, write/recovery cases and parent13's travel envelope remain binding.

### Threading complete first play — driver readiness

**Definition DONE; execution GATED on UI-BOARD-FOCUS.** Read-only readiness
mapping onf02ec981f found no independently executable ordinary Threading driver.
No source/runtime/test edits, engine, package or route attempt performed. This is
not Threading gameplay completion. The full ordinary journey remains the target;
do not turn an entry-only or near-home observation into PLAY-THREADING acceptance.

The existing NativeSortie Pilot provides real Begin Shift, walk>8m, candidate E
boarding, same Player/Torrent, default sampler and real berth departure. The
accepted Beacon entry/settlement pilot supplies ordinary pause→ActivityBoardButton
Return→Nearby/SELECT/START and authored mouse/thrust/brake controls. That same
ActivityBoardButton boundary is retained as failed on Beacon-homea612ea686 and
Mining; a new Threading selector would not repair it. No new Popup identity,
connection-removal event or production cause is established. Original CAP300,
UI3s acknowledgements and cumulative component9.627s/Mining/Beacon histories
remain; no renamed retry, cap reset or imported home-branch qualification.

Conditional implementation ownership when actually ready: one driver implementer
owns existing tools/release/run_native_sortie.py and test_native_sortie.py;
root integrates pure scripts/diagnostics/native_sortie_observer.gd, existing
startup_loader observer admission and tests/startup_cli_privacy_test.gd. Add one
explicit full-route selector, read-only paused observations and confined actual
store capture, not a new validator/schema/version family. There is no current
Threading command or success marker. No implementation/engine is selected now.

Full acceptance to retain:
- Ordinary menu/walk/board/depart/start through supported controls, within30m
  of the actual first gate; no direct board signal or activity-start mutation.
- Physically cross all five authored gates in order, preserving real asteroid
  contact-before-progress failure. Observe transformed gates via
  _cinder_authored_frame_to_world and actual craft via _cinder_authored_frame_position;
  the .tres coordinates are not automatically current common-world coordinates.
- Observe actual activity cinder_asteroid_field_threading_run generation,
  cursor increments, terminal state and exactly one durable
  return_asteroid_survey_to_shipyard receipt, with unrelated store data preserved.
- Fresh Torrent remains in Guided TARGET_PRACTICE; completing Threading does not
  unlock landing. A full driver must complete actual range targets/interceptor
  through supported weapons into RETURN_TO_YARD, preserving the paid Threading
  terminal, before real L capture/strict exact occupied home dock/lease/token.
- Neutral automatic ENGINE_OFFLINE, actual E exterior exit, supported same-Player
  movement>=.5m and60 stable ticks. Ordinary Jovian kit delivery demonstrates
  these acceptance principles, not Torrent/Threading home qualification. The
  unmerged Beacon-home code does not supply accepted home behavior.

The exact engine revision's [Popup parent teardown](https://github.com/godotengine/godot/blob/a13da4feb/scene/gui/popup.cpp#L63)
unconditionally disconnects the matching parent focus/tree signals. This is a
source call-site match, not the missing original popup/removal identity or a
causal reopening fact. Root rechecked retained original diagnostics: only root
Window identity/empty callable, still no popup identity. No fresh UI probe/fix
is selected on this source fact.

Next independent candidate: source-map the still-open ordinary browser
unreachable-host timeout/retry path, now that its focused production deadline is
packaged1c679a4. Keep its full actual Main/UI/retry acceptance separate from the
already-passing adapter test and from this blocked Activity Board family.

### Activity repetition — first bounded definition slice

Source431f24b59, definition only; no gameplay defect or implementation assignment.
The existing ten-same-world-run requirement is retained in
[completion scope](COMPLETION_SCOPE.md).
REPEAT-RACE, REPEAT-BEACON and REPEAT-SCAN each require its named canonical
PLAY-* journey first. Qualify one activity at a time; ten runs do not waive
ordinary outbound/home acceptance or become ten unrelated test/evidence commits.

| Child | Production owner / finite route | Acceptance to freeze before selection |
| --- | --- | --- |
| REPEAT-RACE | GameFlow production race composition, NearbySectorActivityBinding.start_race/reset_race and CinderTimedRaceSession; actual ActivityDirector checkpoints, TimedCheckpointRace timing | Same live world across ten legitimate start/checkpoints/finish/payment/reset cycles; exact generation/receipt identity, no duplicate reward, no stranded objective; ordinary inputs and actual route. Preserve production Main2s countdown/120s timeout. Standalone binding3s timing is component coverage, not ordinary repeat acceptance. |
| REPEAT-BEACON | NearbySectorActivityBinding.start_beacon_traversal/submit_beacon_traversal/reset_beacon_traversal and CinderBeaconTraversalActivity | Each run starts within authored32m first-beacon radius and reaches all four beacons in order through locomotion; existing payment/reset/generation rules hold for ten runs. |
| REPEAT-SCAN | NearbySectorActivityBinding scan start/reward/reset and CinderAbandonedStructureScanActivity | Each run starts within authored24m approach radius, completes4s actual physics scan, and retains existing discovery/payment/reset rules for ten runs. Repeated discovery is not a new entitlement. |

All three retain original no-resource-growth/no-stranded-objective acceptance.
The selected card must name the concrete runtime resource measurement/baseline,
route command, unchanged existing deadlines and exact candidate before running;
these definitions do not invent tolerances or infer a passing resource metric.
Reward authority remains GameFlowRewardAuthority; restarting/replaying completion
must not duplicate its activity/generation receipt. Real-file refused-write,
fresh-process and OS-interruption promises remain ACT-WRITE/recovery work.

Estimate:20–30min to freeze one card after its PLAY-* prerequisite has passed;
no production implementation is currently justified by this source review.
Execution estimate remains unresolved until the accepted first-play route gives
measured activity/reset durations; budget ten such cycles plus travel/closure,
without extending original deadlines. Stop on ten accepted runs or the first
defect; retain any failure before separately selecting a repair. Scan's previous
full-suite failure stays parked with its existing budget/reopen condition.
The remaining nine source classifications are now defined below; their gameplay
and resource acceptance remain unperformed.

### Activity repetition — remaining nine definitions

Source4d14158de plus existing source-qualified Cinder debt checkpointf8b5f86;
read-only source inspection on2026-10-18. This completes ACT-REPEAT-DEFINE as a
finite definition, not ten-run acceptance or an implementation assignment.
Every applicable activity retains the original **ten same-world runs, no resource
growth, no stranded objectives** promise. Keep one retained world and production
owners; clearing history, rebuilding Main, synthetic checkpoint/kill submission,
restocking fixtures or direct scenario changes cannot stand in for ordinary play.
Existing tests named here are coverage anchors only; none ran for this definition.

| Child / source owner | Finite ordinary repeat route | Specific gate / pass condition |
| --- | --- | --- |
| REPEAT-THREADING / [binding](../scripts/world/nearby_sector_activity_binding.gd), [five-gate route](../assets/activities/cinder_asteroid_field_threading_run.tres), GameFlow._reset_cinder_asteroid_session | Approach first gate within30m, start, physically cross all five gates in order, settle actual generation reward, accepted persisted reset; repeat ten times and prove next start usable | PLAY-THREADING first; pending reward blocks replacement. cinder_asteroid_field_test.gd source save/reset coverage is not ten ordinary flights |
| REPEAT-PATROL / [PatrolActivity](../scripts/activities/patrol_activity.gd), GameFlow._new_cinder_patrol_activity/reset_active_activity | Freeze relay_sweep or platform_sweep; traverse that branch's five authored checkpoints in order, hold each for2s through real physics, receive its branch-specific reward, accepted persisted reset; ten completions and usable next start | PLAY-PATROL first. Record branch and route; mixing branches cannot prove ten of the named branch. Other branch coverage remains explicit under PLAY-PATROL; existing Patrol failure/reopen conditions unchanged |
| REPEAT-JOVIAN-KIT / [GameFlow cargo composition](../scripts/game/game_flow.gd), [CargoDeliveryActivity](../scripts/cargo/cargo_delivery_activity.gd) | Actual Jovian departure→strict home landing/transfer2 fabrication kits→one payment→accepted reset, ten cycles under existing180s per-delivery deadline | KIT board/depart/deliver passes retained, KIT-RELOAD stays parked. Source starts6/capacity6, destination capacity64: only3 funded deliveries without replenishment. Required missing contract is a legitimate same-world refill/cargo-cycle source; reset alone does not replenish. Ten-run acceptance remains GATED, not waived or replaced by three successes/seven refusals |
| REPEAT-CINDER-SUPPLY / [binding cargo ownership](../scripts/world/nearby_sector_activity_binding.gd), [terminal debt owner](../scripts/persistence/cinder_cargo_delivery_persistence.gd) | Actual load_crate→clear_gate→dock_platform, authorized physical terminal transfer1 crate, durable once-only payment, accepted reset; ten cycles under existing120s deadline | PLAY-CINDER-SUPPLY first. Initial source2/capacity8 and destination capacity8 fund only2 transfers per retained source; rebinding may reseed a source but is not an approved infinite-stock contract and does not empty destination. Name legitimate replenishment plus destination turnover before execution. Preserve approved shared Jovian/Hauler stock policy; do not infer Hauler delivery from access or Jovian baseline |
| REPEAT-MINING / [mining activity](../scripts/world/cinder_mining_platform_activity.gd), binding persistence/reset | Approach within30m, hold actual6s extraction at authored anchor, request and persist capacity receipt once, accepted durable reset, then repeat ten times/next start | PLAY-MINING first. Leaving radius interrupts progress; pending capacity save blocks reset/start. No ore/currency grant is invented. cinder_mining_durable_recovery_test.gd protects durable boundaries but does not prove ordinary repetition |
| REPEAT-CONVOY / [production host](../scripts/activities/cinder_convoy_escort_host.gd), GameFlow._start_cinder_convoy/reset_active_activity | Healthy piloted departed craft enters actual4m rendezvous sphere, escorts real tender through complete authored route/threats to safe arrival, settles debt, accepted production persisted reset; ten successes/next start | PLAY-CONVOY first. Use retained GameFlow host, not streamed binding's standalone fixture. Preserve90s timeout,42m escort proximity/3s separation and authored movement. Tender/threat reuse and terminal cleanup count toward resource acceptance; retained Convoy failures are not authorized retries |
| REPEAT-DEFENSE / [physical board](../scripts/activities/station_defense_activity_board.gd), [scenario](../assets/activities/shipyard_perimeter_defense.tres) | On-foot board Deploy→ordinary boarding/departure/combat→all three authored waves clear→one payment→home/dock/on-foot board Reset; ten fresh completed deployments and usable next Deploy | PLAY-DEFENSE first. Current fixed hostile counts1/2/1, delays0/2.5/8s, timeout34s; retain original semantics. Failed-wave recovery is continuation, not a counted fresh success. Pending payment must settle; protect/reset the actual objective and reuse bounded host roster |
| REPEAT-BREACH / [physical alternating board](../scripts/activities/heavy_breach_activity_board.gd), [scenario director](../scripts/combat/encounter_scenario_director.gd) | On-foot arm posted Heavy, board/depart a real combat-capable ship, destroy actual charged picket while protecting objective, clear/pay, ordinary return/dock/on-foot rearm; count ten Heavy clears | PLAY-BREACH first. Conclusion rotates posting to Torpedo; no normal post-clear Reset required. Pending debt blocks arm. Respect normal craft service/ammunition constraints; unresolved Bomber rearm is not bypassed. Existing BREACH-INTERRUPTION earned-debt case DONE c78e0ac |
| REPEAT-TORPEDO / same physical board/director, [boat](../scripts/ships/torpedo_boat_opponent.gd) | At posted Torpedo arm/board/depart, evade/intercept live seekers, destroy actual boat for clear and distinct Torpedo payment, ordinary home/board rearm; ten Torpedo clears | PLAY-TORPEDO first. Conclusion rotates to Heavy; no direct selection to skip alternating posting. Existing two-seeker pool and abandonment/stand-down remain bounded; heavy_breach_game_flow_production_route_test.gd staged kills are not ordinary combat repetition |

Heavy/Torpedo share travel/board ownership but retain **two separate ten-clear
counts**. Starting at fresh Heavy, twenty successful alternating sorties yield
ten Heavy and ten Torpedo; ten mixed sorties yield only five each. Failed or
withdrawn launched sorties also rotate but do not count as successful runs.
Cancelling an armed/unlaunched offer does not rotate. An execution card may
collect both counts on one ordinary alternating route; it cannot count the same
clear as both rewards or use reset/direct director calls to skip required play.

Before selecting any execution, freeze candidate, actual command, ordinary
first-play prerequisite, same-phase resource baseline/measurement and unchanged
existing route deadlines. Measure retained actors/registrations, transient
projectile/effect pools, observers and objectives after equivalent terminal/reset
phases; specify legitimate changing generation/receipt/inventory accounting.
Do not infer a numeric leak tolerance or passing metric from source structure.
The exact measurement contract remains a pre-execution gate, as for the first
three definitions. Resource measurements must demonstrate the original promise.

Per activity, budget20–30min to freeze its execution card after first-play/policy
gates. Execution estimate is ten measured complete cycles plus travel/cleanup;
Heavy/Torpedo require the actual alternating route above. No invented whole-task
runtime or raised per-run deadline substitutes for measured first-play duration.
Stop at the first defect or ten accepted cycles; any implementation exceeding90min
must split before starting. Refused-write/fresh-process/OS-interruption and final
candidate requirements remain separate original promises, not waived by repetition.

### Activity write-boundary roster — ACT-WRITES-DEFINE

Source inspection on3e87af961, definition only. Each qualification card chooses
one activity and one actual write boundary; the four boundary labels are not a
blanket48-test cross product. No new runtime defect was established. Existing
checks below are coverage anchors, not newly executed passes or a final-source
qualification. The generic NearbySectorActivitySessionAdapter/Binding capture
helper is caller-injected; it does not automatically resume every production
activity or replace the actual owners below.

| Activity / production owner | Durable state and existing acceptance anchors | Applicable remaining qualification |
| --- | --- | --- |
| Checkpoint Race / GameFlow + CinderRaceSessionPersistence | `cinder_timed_race_session`; `cinder_race_session_save_restore_test.gd` covers active/progress outage, earned payment retry and refused unpaid reset | Final candidate/required distinct-process case; retained full-suite timeout is not permission for an unchanged retry |
| Platform Patrol / GameFlow + CinderPatrolSessionPersistence | `cinder_patrol_session`; `cinder_patrol_session_save_restore_test.gd` covers unpaid restart, terminal refusal, write recovery/reset retention | Same exact-source distinction; parked Patrol failure remains |
| Jovian kit delivery / GameFlow + JovianCargoSessionPersistence | `jovian_cargo_session`; `cargo_delivery_production_integration_test.gd` covers inventory/receipt, interrupted payment and missed start/save/reset | Ordinary KIT-RELOAD remains parked at its unchanged30s cap |
| Cinder platform supply / NearbySectorActivityBinding + CinderCargoDeliveryPersistence | `cinder_cargo_delivery` strict v2 earned terminal proof before payment, atomic paid acknowledgement; legacy v1 presentation-only. Existing roundtrip extended on7ecdfec (external launcher2461d5eee): ordinary Start retries saved debt with pending/paid UI; source27 and exact Windows embedded package27 plus three actual-file child processes pass, one credit and conserved transfer/foreign data | CINDER-SUPPLY-DEBT DONE in its selected refusal/cold-payment/no-replay scope. Active manifest resume, ordinary/installed/final/OS-interruption acceptance remain separate; no Jovian behavior inferred |
| Mining/extraction / GameFlow + CinderMiningCapacityPersistence | `cinder_mining_capacity`; `cinder_mining_durable_recovery_test.gd` covers real-file active/unpaid/paid capacity, reset/write refusal and published-sync case | Required final/installed/ordinary cases; capacity is the durable outcome, not an invented ore or credit grant |
| Structure Scan / GameFlow + scan activity/discovery persistence | `cinder_structure_scan_session` + `cinder_scan_discovery`; `game_flow_scan_durable_recovery_test.gd` covers real-file debt/payment/discovery retry, paid reset and progress/terminal saving | Retained full Scan failure stays parked; no automatic probe/retry |
| Beacon Traversal / GameFlow + beacon activity | `cinder_beacon_session`; `game_flow_beacon_durable_recovery_test.gd` covers real-file active/unpaid/paid recovery, refused resets, owner fence, published payment and write outage | Required ordinary/installed/final-candidate interruption remains distinct from covered source cases |
| Asteroid Threading / GameFlow + NearbySectorActivitySessionAdapter's strict asteroid record | `cinder_asteroid_session`; `cinder_asteroid_field_test.gd` covers actual Main active/debt/payment/reset, backup/newer refusal, callback fence and paid floor | Actual OS-interruption/distinct-process and complete ordinary-play cases remain separate |
| Convoy / GameFlow + CinderConvoySessionPersistence | `cinder_convoy_session`, arrival summary separately `cinder_convoy_safe_arrival`; `cinder_convoy_session_save_restore_test.gd` already includes unpaid/reset/write outage | Preserve ca0 pilot/Convoy package result and parked full-suite failure; no unchanged retry |
| Station Defense / physical StationDefenseActivityBoard | `station_defense_session` stores earned terminal/debt. `station_defense_production_placement_test.gd` covers real-file refusal, recreated Main and once-only acknowledgement | Active actors/damage/leases are explicitly excluded from this owner. Final/installed/ordinary terminal cases remain separate |
| Heavy Breach / physical HeavyBreachActivityBoard | `heavy_breach_session`, reward `shipyard_heavy_breach`; `heavy_breach_activity_board_production_test.gd` and `heavy_breach_game_flow_production_route_test.gd` cover earned/refused payment, recreated board/Main and paid acknowledgement with MemoryFilesystem | Actual-file distinct-process earned debt→one payment and paid restart; no active encounter reconstruction in this owner |
| Torpedo Run / same physical board, distinct scenario/reward | Same session owner, reward `shipyard_torpedo_run`; production route test earns the actual rotated Torpedo terminal and retries its debt with MemoryFilesystem | Separate Torpedo actual-file fresh-process debt/receipt/paid restart; shared code is not scenario acceptance |

All test filenames above are under `tests/`. GameFlow._commit_game_flow_activity_reward
delegates to GameFlowRewardAuthority.commit: genuine earned state must precede
payment, and authority owns activity/generation/receipt identity. A refused reset
must retain durable debt and live state; an accepted paid reset must not create a
second reward or erase unrelated payload. Published-but-refused filesystem sync
has existing owner-specific reconciliation; do not invent another shared layer.

"Terminal-only" describes existing behavior, not an owner-approved scope cut.
It does not waive broader original crash/re-entry promises. Any requirement for
an active resume beyond these actual owners remains an uncovered capability to
specify explicitly; tests expecting discarded active state cannot close that
broader requirement. Full ordinary travel/reward/home/re-entry remains ACT-PLAY,
with ACT-REPEAT separate. HULK revisit remains parked; its one-shot power receipt
and planetary survey/world persistence retain their own owners/contracts.

Executable release seam: the existing startup loader, in_world_interruption_probe
and run_package_probes support convoy/beacon/mining/stationdefense/scan/hulk/ember,
but no Heavy Breach or Torpedo selector. A bounded release-driver extension can
therefore deliver actual-file OS-interruption qualification for one missing
terminal owner without changing gameplay or introducing another validator. Select
one scenario explicitly before implementation; retain startup admission/privacy,
real owned kill/reap, distinct restart, exact document and once-only receipt checks.
No engine or package checks were run for this definition; all original failures,
external decisions and final gates retain status.

BREACH-INTERRUPTION earned-debt release capability is DONE on c78e0ac.
Original e9/3c admission failures, c159's late-metadata failure and853's JSON
comparison failure remain recorded at 249.405s. Source and raw tutorial seen sets establish the original concrete
cause: physical debt retry pays and arms Torpedo; its next tutorial save replaces
latest shared-store metadata before the old probe reads it. The existing board
signal now captures the actual primary JSON/commit before that tutorial; both
runtime and package consumer require the exact ledger and paid terminal in that
same document. Godot source proves JSON FLOAT versus live INT dictionary
equality was invalid in853; only the expected ledger is canonicalized through
the existing JSON helper, preserving every field/value and all eight checks.
Failure diagnostics now name predicates/types without printing foreign payload.
Later no-op interaction, foreign settings/cargo, normal Resume/
real pilot/exit and third distinct cold paid replay remain unchanged.

Both full source and archive-extracted executable transactions pass, with
child300s/transaction1000s unchanged. New stages 352.043s, cumulative 601.447s;
paired clean packages/three strict startups/actual audit pass. Existing branch
merged/pushed/deleted and owned scratch cleaned after preservation. This closes
only earned terminal debt recovery. Initial board/flight/target damage are staged
fixtures; ordinary combat, Torpedo recovery, active encounter/timer/pose restore,
network/native/human and final-release scope remain separate/open.
[Original failed reopening](history/ROADMAP_DELIVERIES.md#breach-interruption-after-fixed-startup--failed-and-parked)
and [accepted closeout](history/ROADMAP_DELIVERIES.md#breach-interruption-branch-finished--2026-10-20).

## Multiplayer

<a id="phase-7--multiplayer"></a>

Scope: all twelve original §4 outcomes and retained ordinary-remote-crew milestone. Select one craft, role, channel or matrix cell; aggregate session and snapshot checks remain separate.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| NET-CAPACITY[one supported session profile] | GATED on SCOPE-LIMIT decision | Verify explicit player count, per-craft occupancy/roles and connection profile. Eight configured clients is not accepted eight-player support. Stop at one profile. |
| NET-CREW[one craft/role] | ELIGIBLE for implemented route | Independent authenticated ordinary crew walks, sits, performs role, stands/exits and survives applicable ownership/host/disconnect recovery. Use existing Jovian engineer, Halyard engineer/passenger or Bulwark gunner route tests. Stop at named role. |
| NET-POSE[one craft/operation] | ELIGIBLE; existing remote/craft-pose tests | Current and late peer see correct engine, station-frame pose and landing/dock presentation during one named operation. Use `network_remote_craft_pose_test.gd` / `network_craft_pose_station_frame_test.gd`; stop at operation. |
| NET-HELM[one supported action] | ELIGIBLE; `network_remote_pilot_helm_test.gd` | Real sampled local input reaches supported remote helm action and handback without stale ownership. Stop at original action/recovery scenario; synthetic command-only checks cannot close input prerequisite. |
| NET-STALL[existing host-stall route] | Current-source DONE3d6b1b513; final-package/native scope separate | Full original route passed both600-step stalls/original2s actions,160 terminal host assertions, actual peer/wrapper exits0 and no diagnostics. No unchanged repeat, clock/deadline relaxation or transfer to other ordinary/native/endurance gates. |
| NET-LAND-DIAG[intermittent second landing] | DEFINE; original failure retained | One probe identifies the first failed boundary in second landing/reuse. Stop with owner/fix or blocker; no speculative clock rewrite. |
| NET-DOCK[one craft] | GATED on relevant fix if needed | Remote landing/dock, ordinary disembarkation, reboard and repeat departure succeed. Stop at one craft's existing route. |
| NET-DAMAGE[one craft/role scenario] | ELIGIBLE; existing damage/respawn integration tests | Peer presents hull/component damage, repair, destruction and regeneration coherently, then returns to usable role/craft. Stop at one scenario; preserve authority and ownership. |
| NET-ACTOR[one channel/lifecycle] | ELIGIBLE for implemented channel | Convoy, Torpedo Run, Picket or Emberline instance covers its named travelling actor/projectile live/dead/reset, late join, disconnect or solo-restoration boundary. Use existing authority/Emberline tests. Stop at one lifecycle case, then schedule uncovered cases separately. |
| NET-BROWSER[one ordinary menu flow] | ELIGIBLE; discovery/binding tests | Discover/refresh/select/join/disconnect/retry from normal menus. Separate stale, full, unreachable, cancel and controller cases into individual instances; stop at selected flow. |
| NET-BUDGET[all-nine forced-full snapshot] | Aggregate contract DONE on330a39ce3; new-candidate/native/ordinary scope separate | Existing `network_craft_pose_station_frame_test.gd::_assert_snapshot_envelope` uses actual Main nine-craft publication, forces full encoding and measures live delta; both fragment and decode to the exact complete snapshot within12000 bytes (fragment payload900, maximum16). Retained full suite PASS382 in172.837s; all-nine full/live4656/4656. No CPU/throughput threshold is specified. Do not rerun or add a budget-only selector merely to duplicate this accepted result; ordinary multiplayer and final/native/endurance gates remain open. |
| NET-ENDURANCE[one supported profile] | DEFINE exact independent-process command, then GATED on stable baseline | Run original 30-minute two-client moving-interior session with declared latency/profile and no ownership/state leaks. `network_moving_interior_latency_test.gd` is an anchor, not an invented substitute command. Stop after original duration and clean closure. |
| WORLD-SHARED[one world/case] | GATED on supported crew/profile and baseline dependencies | Ordinary independent remote crew completes the selected canonical case, including actual outbound/return, activity/reward/save and appropriate usable recovery. Preserve focused 300s/canonical 900s and physical landing 120s where specified. Stop at one matrix cell. |

WORLD-SHARED instances: **Ember, Aurora, Rime**, each with **baseline full outbound/return, late join, disconnect/reconnect, pilot loss, cancellation, real interruption, repeat visit**. Each cell is a separate task and must name participants, initial state, ordinary-input route and durable reward/return criteria before execution. The baseline includes activity and save behavior; failure cases do not inherit a staged baseline. Use existing `tests/network/halyard_network_shared_planetary_cruise_test.gd` and applicable world/landing tests. Missing exact case coverage becomes a bounded DEFINE child, not a claim that the anchor already covers it.

### LAN discovery while paused — NET-BROWSER-PAUSE

**DONE packaged042c701e2, parent25.** Discovery alone processes during gameplay
pause. Automatic real-loopback paused responder/browser, correct host row/current
capacity/endpoint, frozen gameplay heartbeat, stopped-host refresh, cancellation
and socket/state cleanup pass27 assertions; existing default GameFlow browser
integration passes7. Old unchanged production reproduces the exact paused
completion failure first. Both exports/three strict silent startups/actual package
parity pass. [Original contract and actual results](history/ROADMAP_DELIVERIES.md#paused-lan-discovery--delivered).
Full ordinary independent Main/browser/admission/reconnect/capacity/endurance,
native Windows/GPU/device/audio/human and final gates remain OPEN/NOT_RUN.
No repeated accepted check or parked live-menu retry is selected by this delivery.

### Unreachable or non-admitting host — BROWSER-JOIN-DEADLINE

**Focused runtime delivery DONE on1c679a4e2**, merged/pushed and paired-checkpoint
packaged. The authored5000ms monotonic deadline now spans connection/admission,
continues during pause, closes the pending native peer with readable timeout,
and permits retry. Cancellation/replacement and valid admission retire the clock.
Five focused suites pass196 assertions; both exports, three strict menu startups
and actual1521-entry package parity pass. One initial test syntax failure and its
sole repair remain in the cumulative result; no further failure occurred.
[Original frozen contract and actual results](history/ROADMAP_DELIVERIES.md#client-join-admission-deadline--delivered).
Full independent ordinary Main/menu unreachable-host UI/retry, capacity/endurance
and native/human/final gates remain OPEN/NOT_RUN. This closes one runtime defect
under parent25, not the complete browser requirement.

### Browser inline session recovery — BROWSER-INLINE-RECOVERY

**DONE in focused runtime scope on20e90c9**, merged/pushed and packaged. Browser
progress/timeout feedback and current fenced Retry now work before Begin Shift;
Cancel/Disconnect priority and newer validation messages are preserved. Five
focused suites182 assertions, paired exports/three strict startup checks and
1521-entry package parity pass. Original regression, source-review finding and
Cancel-priority failure/corrective decisions are retained in the
[full frozen contract/results](history/ROADMAP_DELIVERIES.md#browser-inline-session-recovery--delivered).
Owned scratch cleaned; raw results retained. Full ordinary OS-input/browser
journey, rendered readability and parent25 remain OPEN/NOT_RUN.

### Browser ordinary timeout and retry — bounded delivery cards

**PARKED/unaccepted** candidatee944f52a8 on pushed branch
`feat/browser-ordinary-driver-20261020`; unmerged/withheld.89 Python tests,
privacy,35 join assertions, paired exports/three strict startups and1521-entry
parity pass, but ONE ordinary route fails40.554s at actual timeout:
NetworkSession tree_exited disconnect/empty callable diagnostic, cause unknown.
Fixture cleanup separately rejects its command. Full Retry/admission/Disconnect/
fresh Cancel/Resume/normal quit NOT_RUN. Both driver and ordinary delivery remain
unaccepted; no successful-prefix substitution. Original name-collision failure,
sole corrective exception and full frozen acceptance/caps remain in the
[retained contract/results](history/ROADMAP_DELIVERIES.md#browser-ordinary-timeout-and-retry--failed-and-parked).
Cumulative12 stages235.879s/2fails; all67 observed process identities absent.
Eight unique builds retained privately; owned scratch cleaned; no public build.
No further repair/exception/probe/retry/cap change selected. Next action is bounded
read-only disconnection-owner mapping before any concrete production correction.
Original no-answer/unreachable case and all broad/native/human/final gates stay open.

### Timeout RPC-cache ownership — NET-TIMEOUT-TEARDOWN-OWNER

**One source observation complete: NOT_REPRODUCED.** Clean20cab9bba import19.711s
and single combined caller11.514s pass measurement guards. Default/custom APIs
both track the actual `SceneCacheInterface::_remove_node_cache` callback bound
to the adapter ID and cleanly remove it at automatic timeout5004/5002ms. Same
adapter remains parented. No ownership-dependent difference observed; no app
ownership change or release cause/fix supported. Full-game graph, separate-process
and release-template context remain untested by this component caller.
[Exact observations, original source map and frozen contract](history/ROADMAP_DELIVERIES.md#timeout-rpc-cache-ownership--source-observation-not-reproduced).
Two owners terminal/all6 observed identities absent; owned scratch cleaned and raw
results retained. Investigation cumulative14 stages267.105s retains two original
failures. No second probe/repair/cap increase/full-route retry selected. The subsequent release capture is complete below; it identifies the retained native
callback without establishing the internal mismatch or repair. Do not repeat unchanged
default/custom source comparison. Original browser candidate stays parked;
all broad/native/human/final gates and accepted checkpoint20e90c9 unchanged.

### Release timeout callback capture — bounded definition and selection

**Parent25; frozen2026-10-20 before implementation/engines.** Independent high
contract review recommends one passive release capture because the sole source
observation identifies a native SceneCacheInterface callback but cleans it under
both API ownership modes. This new actual parity fact addresses the missing
callback identity in the original release failure. It authorizes no ownership
workaround, ordinary acceptance retry, source-probe repeat or runtime fix.
Investigation cumulative14 stages267.104796959s/two original failed stages remains
binding; original12-stage235.879s browser chain stays parked/unaccepted.

Use a clean derivative of EXACTe944f52a835789971a58e0e4d1dd50c4ac664b34.
One medium implementer owns ONLY `scripts/diagnostics/native_sortie_observer.gd`,
inside `_browser_observation`'s existing valid-adapter branch: append actual API
identity/root and serialized tree_exited connection validity, object ID/class,
method, primitive bound arguments, unbound count and flags (about20–30 lines).
Keep Callable/Object references local to the sample. Represent nonprimitive
arguments by safe type/identity metadata without invoking custom _to_string.
No connections, disconnections, callback invocation, retained references,
transport polling, expiry/authority writes, changed cadence or general framework.
Root owns guards/packages/integration; one independent high reviewer before engines.
No recursive agents. Driver SHA256 remains
`2d7d4da626d018ddc4bc68e74bac67c8ad6632bf6f703d00089b16d6982d1015`;
fixture/test/GameFlow/adapter/startup/privacy sources stay byte-identical to e944.

Focused/package stages: fresh guarded import180s, existing startup privacy60s,
existing safe clean Linux export180s, actual package startup120s requiring exit0
and exactly one STARTUP_MENU_READY_OK, embedded observer/source-pin/package
inventory check90s. No Windows/public checkpoint is justified by diagnostic-only
code; any working runtime fix later requires the normal paired checkpoints.
No hosted CI, native desktop/audio or --script override on the exported game.

Then ONE original private Xvfb/XTest separate-process route command structure from
`browser-ordinary-driver-20261020/results/repair-1/results/ordinary/authorization.json`,
replacing only owned paths and the new diagnostic binary filename. Same300s
whole-process cap,3s UI/fixture acknowledgements,10s display/15s window limits,
explicit x11/Dummy, rendering flags, normal OS-typed endpoint and original steps.
Driver/fixture remain unchanged, including the known fixture command rejection.
The original full timeout→Retry/admission→Disconnect→freshCancel→Resume/walk/
normalquit criteria cannot be replaced by a passing prefix or evidence artifact.

Harvest RAW game.log, not only the pilot's last state (diagnostics reject its
current chunk). Desired original failure is the exact nonexistent-disconnect
NetworkSession tree_exited/empty-callable error referencing the actual adapter ID,
with real connected/nonadmitted hello and5000–7000ms paused automatic timeout.
Require same Main/player/adapter/API identities and complete connection snapshots
before and after cleanup. Capture the actual owner/binding/removal outcome; do
not assume a particular callback or retained list. Missing bracketing data is
INCONCLUSIVE/STOP, not permission for another capture. The exact already-known
fixture cleanup rejection is retained separately. Every other new/different
failure, timeout, guard issue or missing required data STOP; no repair, substitute
route, extra observation or cap increase. Zero target errors is NOT_REPRODUCED
and ends this assignment; any later unchanged-driver failure remains recorded.

The underlying route must retain its actual nonzero/success:false result when
original errors occur. A complete diagnostic harvest is not runtime acceptance,
a fixed bug, a playable delivery or a project percentage. Preserve logs/source/
process identities and unique diagnostic package, then clean only owned scratch.
Estimate15–25min implementation/review,5–10min build/capture/cleanup; split before
45min. Pass ends this acquisition; next runtime choice needs actual captured cause.
All original browser, native/human/final parent gates remain OPEN/NOT_RUN.

**Result2026-10-20: CAPTURED_KNOWN_FAILURE, acquisition only.** Candidate
783c8c87206a52928641dd887f9a34e02caaf246 adds only25 observer lines and is
pushed/unmerged/withheld. All five readiness/package stages pass; one actual
release route exits1/success:false at the exact original diagnostic. Raw brackets
show the same valid SceneCacheInterface callback bound to the actual adapter ID,
flags4/unbound0, still present after5006ms timeout. Release method metadata is
empty, unlike the source observation; exact internal mismatch/repair remains
unproved. Same Main/player/adapter/API/root and paused phase/position/clock.
Separate fixture rejection unchanged. [Full result, hashes, limits and cleanup](history/ROADMAP_DELIVERIES.md#release-timeout-callback-capture--known-failure-captured).
Six owners finished/33 observed identities absent; five unique private Linux
artifacts retained and owned checkout/helpers/profiles cleaned from active paths.
Six stages131.191s; cumulative20 stages398.296s preserves original failures and
this actual failed route. No retry/repair/cap increase or second capture selected.
Correction definition is complete in the following section; the first build-recipe
implementation is selected, while actual templates and full-route acceptance remain gated. Diagnostic acquisition is not a production fix or ordinary acceptance.

### Release RPC-cache correction — implementation cards

**Definition complete2026-10-20; first implementation selected before edits.**
Parents25/32. Pinned engine source is
`a13da4feb8d8aefc283c3763d33a2f170a18d541`, the existing builder's exact revision.
The captured retained callback establishes a production teardown gap; it does not
identify the differing native identity bytes or prove a compiler/ABI fault.

**Correction to the earlier source lead:** adding `.bind(E.key)` is not a repair.
[Signal connect/disconnect](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/object/object.cpp#L1556)
use the [base comparator through bind wrappers](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/variant/callable_bind.cpp#L85).
[Release method metadata](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/object/callable_mp.h#L53)
is intentionally empty without DEBUG_ENABLED. Neither fact proves the failure.

Independent high source/lifecycle review GO supports this **unproved candidate**:
in `modules/multiplayer/scene_cache_interface.h`, add a Callable member to
NodeCache; in `_track`, construct/store the bound removal callback once and
connect that value one-shot; in `clear`, disconnect that exact stored value.
[Callable copies retain custom identity](https://github.com/godotengine/godot/blob/a13da4feb8d8aefc283c3763d33a2f170a18d541/core/variant/callable.cpp#L265),
so lookup reuses the same pointer/hash rather than reconstructing it. Native data
holds a raw owner pointer/ObjectID, with scalar bound node ID, adding no ownership
cycle. One-shot emission holds Callable copies while removing the connection
before invocation; NodeCache removal can release its copy safely. Repeated
clear/retrack remains supported. Do not change general Callable equality, skip a
disconnect via is_connected, suppress diagnostics, fake tree exit or change app
ownership. Effectiveness remains gated on actual patched release validation.

**RPC-CACHE-BUILD-RECIPE — selected executable build capability.** One medium
implementer owns ONLY `tools/release/build_godot_reflection_fix.py`, its existing
`test_build_godot_reflection_fix.py`, and new
`tools/release/patches/godot-4.7.1-rpc-cache-teardown.patch`. Root owns docs,
integration/checks; one independent high reviewer. No recursive agents.

Extend the existing builder, not a parallel copy. Add explicit mutually exclusive
`--rpc-cache-teardown` mode, `--platform linuxbsd|windows`, and an absolute owned
`--cache-root` for this mode. Preserve all legacy defaults/paths/tests. RPC mode
must apply ONLY the two-file callback patch (explicit header include if needed),
never reflection/mesh/probe patches. Pin official source archive, SCons wheel,
patch and exact before/after target bytes. Use template_release x86_64 and private
platform-specific logs/results, build names and staged template filenames.
Windows output is inspected as PE and never executed on Linux; Linux version
probes, when later run, must be headless/Dummy. Preserve inherited HOME, isolated
XDG, bounded jobs/timeouts and existing abort/reap behavior. No installed engine,
stock templates or export-preset mutation; no silent renderer/feature removal.
Windows dependencies must be explicit, not bypassed by ad hoc disable flags.

Acceptance in this card is the existing build-tool suite extended for real
new behavior: side-effect-free two-platform plans, conflicting-mode rejection,
exact patch/source rejection, unrelated-mode isolation, correct target staging,
stale template refusal and no Windows execution. Command:
`python3 -B -m unittest discover -s tools/release -p test_build_godot_reflection_fix.py`,
cap60s, no compiler/downloader/Godot. Actual compile and runtime effectiveness
remain NOT_RUN. Source-file downloads for reviewed patch preparation are allowed
only into owned scratch; no source archive/tool installation or engine build.
Estimate45–60min implementation/review plus focused checks; split before90min.
Unexpected check failure STOP for this card; no automatic repair/retry expansion.
Commit/push the capability, retain exact patch/source facts and clean owned scratch.
No playable checkpoint is implied by an uncompiled build recipe.

**RPC-CACHE-BUILD-RECIPE result: DONE onf45c9094f8a3b0724abc3896d97b265b81ee8030.**
Only the three owned files changed, with explicit callable header and stored-value
connection/disconnection in the patch. Independent high actual-source/build-tool
review and root review GO; all24 tests pass once,0.514s guarded stage under60s cap.
Source/index/cache/engine guards intact; one owner finished/two observed child
identities and owner absent. Feature branch pushed, source fast-forward integrated.
Only results remain in owned scratch, including the two official source files and
reviewed after-images. Actual source archive preparation, dependency installation,
compilation and runtime effectiveness NOT_RUN. Default installed engines/templates
and presets not changed. [Exact hashes, usage and limits](history/ROADMAP_DELIVERIES.md#rpc-cache-release-template-recipe--implemented).
Freeze commit→cleanup290.078s/4.8min versus45–60min implementation/review estimate;
excludes initial definition/final publication. No new playable checkpoint.
Next single action: dependency provisioning and exact build-command freeze for
matching templates, with original full-route/fixture gates preserved.

**RPC-CACHE-TEMPLATES — dependent actual build.** Recipe accepted; GATED on
SCons and required native/cross build dependencies. Current environment has
Python3.13.5/GCC14.2/ar/patch/pkg-config,12 CPUs and~13GiB available RAM, but no
SCons, clang++ or MinGW on PATH, and no prior builder cache. Debian's cached
package index offers POSIX MinGW14.2; no installation performed. Existing builder
pins SCons4.10.1. Extend/provision within a separate frozen card; matching
Windows/Linux release templates must share source+patch and preserve needed
renderer/accessibility features. Existing official
[Linux requirements](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_linuxbsd.html)
and [Windows cross compilation](https://docs.godotengine.org/en/4.7/engine_details/development/compiling/compiling_for_windows.html#cross-compiling-for-windows-from-other-operating-systems)
name dependencies. Use max2 jobs/no LTO for the initial bounded candidate, explicit
per-platform cap no greater than the existing3600s recipe ceiling, and independent
abort/reap guards. Freeze actual commands/output paths/dependencies before build;
stop on first unexpected failure. This definition does not execute/provision it.

**RPC-CACHE-TEMPLATE-PREP — selected2026-10-20 before install/prepare.**
This provisions the preceding build dependency; no compile/game run is selected.
Root owns execution under `/srv/mudds-work/rpc-cache-templates-20261020/`; one
medium read-only dependency mapper confirmed the pinned source defaults. No
recursive agents. Existing source/patch/recipe pins remain unchanged.

Run `apt-get install -y --no-install-recommends g++-mingw-w64-x86-64-posix libwayland-bin`
with noninteractive frontend, cap600s. Cached package simulation must show no
upgrades/removals; record installed package versions and compiler POSIX thread
model. No apt upgrade/update, driver replacement, system SCons or unrelated dev
library installation. Existing native GCC/ar/patch/pkg-config are present.

From an exact clean recipe worktree, run the existing builder `--prepare
--rpc-cache-teardown --target template_release --platform PLATFORM --cache-root
/srv/mudds-work/rpc-cache-templates-20261020/cache --jobs 2 --timeout 1800` once
per linuxbsd/windows, each outer cap300s. This pins/downloads/extracts the existing
official source archive and SCons4.10.1 wheel into separate owned platform caches,
then installs that wheel only in their private venvs. No source patch or compile.

SDK preparation uses only the pinned source's installers from each source root:
Linux `misc/scripts/install_accesskit.py`; Windows that script plus
`install_angle.py`, `install_winrt.py`, `install_d3d12_sdk_windows.py`. Each600s,
one invocation only; private XDG/TMPDIR, inherited HOME and LOCALAPPDATA unset so
outputs stay in source `bin/build_deps`. Preserve source hashes, raw outputs and
owned process identities. Exact dependency versions from source: AccessKit0.21.2,
ANGLEchromium/7219, WinRT72, Mesa25.3.1-3, Agility1.618.5, PIX1.0.240308001.
PIX remains default-disabled; no renderer/accessibility disabling flag. Read the
actual extracted scripts before execution to verify destinations/defaults.
[Windows default detection](https://raw.githubusercontent.com/godotengine/godot/a13da4feb8d8aefc283c3763d33a2f170a18d541/platform/windows/detect.py),
[Linux default detection](https://raw.githubusercontent.com/godotengine/godot/a13da4feb8d8aefc283c3763d33a2f170a18d541/platform/linuxbsd/detect.py).

Acceptance: exact source/wheel/SDK inputs prepared, default features still
available and owned actors gone, or precise first failure. Any unexpected failure
STOP; no automatic repair/retry/source URL change or cap increase. No package or
runtime acceptance follows. Estimate15–30min prep/inspection; retain reusable
source/toolchain inputs instead of deleting required build artifacts. Commit/push
result before selecting actual compile commands; preserve original browser gates.

**Preparation result2026-10-20: PREPARED.** Eight stages174.054s; eight owners
finished/all65 observed owner+child identities absent. Eight new Debian packages,
zero upgrades/removals; POSIX GCC14.2 cross compiler and Wayland scanner1.23.1.
Both exact source archives/private SCons4.10.1 venvs and pinned SDK scripts prepared
successfully. Required1837 SDK consumer files hashed; source/installed engine and
stock-template guards intact. Freeze→prepared409.761s/6.8min versus15–30min prep
estimate. No compile/native run. Inputs retained for this next actual build.
Optional default-disabled PIX lacks MinGW import conversion because gendef is
absent; this does not remove an enabled default feature.

**RPC-CACHE-TEMPLATES — selected actual compile, frozen before execution.**
Recipe worktree remains clean `70af2484c` under the same owned root. Root owns
both processes and shared stop handling; dependency mapper completed independent
source review. Launch independent linuxbsd/windows commands concurrently, each:
`python3 -B tools/release/build_godot_reflection_fix.py --build
--rpc-cache-teardown --target template_release --platform PLATFORM --cache-root
/srv/mudds-work/rpc-cache-templates-20261020/cache --jobs 2 --timeout 3600`.
Existing isolated supervisor whole-command cap3900s per platform permits bounded
source/pip/postbuild checks around the3600s compile cap. Max four compiler jobs
total/no LTO; no feature-disable options. Linux version probe stays headless/Dummy;
Windows PE is never executed. Retain exact PID/start identities, raw logs and
source/helper/installed-engine/template/SDK-input guards. Stop/cancel the other
build on the first unexpected failure; no retry/flag substitution/cap increase.

Acceptance: both native patches exactly applied, source recipe guards pass,
actual Linux ELF and Windows PE built/staged with hashes, no missing-SDK or
feature-disable warnings. This establishes compiled templates, not native GPU,
Windows execution or gameplay correctness. Assemble a fresh owned
`templates/4.7.1.stable/` set from the actual built files. Preserve Agility handoff:
Windows SCsub emits `bin/D3D12Core.dll` and `bin/d3d12SDKLayers.dll`; copy their
identical bytes beside the private Windows template as `D3D12Core.x86_64.dll`
and `d3d12SDKLayers.x86_64.dll`, matching the existing exporter's lookup. Validate
against the actual SDK source files/PE architecture; ANGLE/AccessKit link statically.
No preset/runtime-driver change. Current Vulkan Auto export does not select those
DLLs, but the complete private template set must retain them for D3D12 consumers.
A missing sidecar is not a blanket startup failure: the engine can fall back to
OS D3D12. Do not misreport a renderer failure from packaging inventory alone.

Estimate25–60min parallel compile plus5–10min collection/review, stop before90min.
One collection pass (cap180s) checks artifacts, SDK/stock pins and cleanup. Retain
unique templates/reusable inputs; remove only completed temporary worktree/helpers/
profiles after source/result publication. No game import/export/probe/browser
retry or public checkpoint in this task. Original browser398.296s investigation
budget and all unperformed acceptance remain unchanged.

Separate source-only fixture readiness review establishes a protocol defect:
Godot JSON numbers parse as doubles, but e944 fixture requires `sequence is int`.
Driver emits JSON numbers. The exact historical command file was deleted, so its
particular offending bytes are unproved. A bounded fix must normalize finite,
nonnegative integral safe-range numbers, preserve exact successor/private-directory/environment/mode/PID
contracts and prove real Godot parsing. No fixture edit/run is selected here.

Linux compile result2026-10-20: existing linuxbsd_build owner finished exit0,
guarded stagePASS2934.911273s/48.9min with no diagnostics. Built and private-staged
release template94,303,272 bytes, SHA256
4fe7e2cfc8092ebfd8339b7ca9d227b6ed5dba177f86b9c7e57913cfe89e5607.
Silent headless/Dummy version probe returned
4.7.1.stable.mudds_rpc_cache_teardown_linuxbsd.a13da4feb.
All8,651 observed owner/child identities are absent. Windows compile remains live
under its unchanged2jobs/3600s cap; no collection, game export or runtime route
has run. Keep this partial result separate from matching-pair acceptance.

Windows result: STOP at original3600s compiler timeout, stage exit1 after
3611.846848s/60.2min, no compiler diagnostics and no accepted PE. This is an
incomplete build, not a verified source/patch defect. Both owners terminal;
all14,427 observed owner/child identities absent, no live process cwd under the
owned template root. Collection, paired game exports and runtime route NOT_RUN.
No automatic retry/cap increase. A separate bounded priority review may assess
retained incremental objects against the original cumulative90min stop; it does
not select execution or reset the failed attempt/budget.

After source push and clean/ignored-file checks, duplicate template and dependent
acceptance worktrees were removed. Unique helpers were copied/hash-verified into
their results folders; profile logs and original freezes retained. Template root
now has only cache/ and results/: exact Linux template preserved/hash-verified,
pinned SDK/source/object cache retained, incomplete Windows objects kept separate.
Dependent acceptance root now has only results/; source candidatee5b9dd25f stays
pushed/unmerged, reviewed drafts preserved, no engines/tests/exports attempted.
The bounded HUD-RACE source check found no concrete discrepancy; no edits/tests
or acceptance claim followed. Other original scope and external gates stay open.

**BROWSER-FIXTURE-JSON — DONE2026-10-20; source fixture accepted.**
Parent25's executable release-test handoff prerequisite; Linux/Windows compiler
jobs remain separate and keep their existing caps. Use a clean derivative of
783c8c87206a52928641dd887f9a34e02caaf246 in
`/srv/mudds-work/browser-fixture-json-20261020/worktree`. One medium implementer
owns ONLY `tests/network/network_session_join_failure_test.gd`; root owns private
caller/guards/integration, one independent high reviewer. No recursive agents.

Normalize the fixture sequence only after checking an actual int/float value,
finite/nonnegative/integral and <=9007199254740991 (exact JSON integer range).
Never coerce strings/bools/null/fractional/nonfinite/out-of-range values. Preserve
existing dictionary/mode validation, private env/directory/headless/Dummy/port
preconditions, exact sequence+1 successor check, PID/port acknowledgements,
raw/admitting/stop behavior and independent300s fixture cap. No new nonce protocol,
driver edit, game logic, observer or networking authority change. Driver stays
SHA2562d7d4da626d018ddc4bc68e74bac67c8ad6632bf6f703d00089b16d6982d1015.
Add real JSON-number decoding and rejected-type/boundary cases to the same normal
GDScript suite; preserve its existing35 assertions/real join cases.

Proof once after review from clean candidate: guarded fresh headless/Dummy import
cap180s; existing `res://tests/network/network_session_join_failure_test.gd`
cap60s requiring exit0/one NETWORK_SESSION_JOIN_FAILURE_TEST_OK, including new
codec checks; one private Python caller cap30s imports the unchanged driver's
BrowserFixture and starts the actual source-engine fixture. Exact driver engine
arguments remain `--headless --audio-driver Dummy --path WORKTREE --script
res://tests/network/network_session_join_failure_test.gd -- --native-browser-fixture
--fixture-dir=OWNED_DIR --fixture-port=OWNED_LOOPBACK_PORT`. Require real raw
sequence0→admitting1→raw2→stop3, each original3s acknowledgement bound, distinct
actual fixture PID/port matching every state, normal stop exit0/one
NATIVE_BROWSER_FIXTURE_STOPPED_OK, no diagnostics and all owned actors absent.
Retain actual command/state JSON and raw logs this time. Caller-only handoff does
not qualify the full packaged browser route or native callback repair.

Use resolved stock source engine SHA32f8d7596c4b41185512b1c49d69f2da3be018fd784a53e349fa92a98a97bcde,
private XDG/TMPDIR with inherited HOME, frozen source/index/cache/engine/PID guards.
Fresh import alone may create cache. No unchanged Python89-suite rerun, full
browser retry, export, template replacement or public checkpoint in this card.
Estimate15–30min implementation/review plus2–5min checks/cleanup; split before45min.
Any unexpected failure STOP; no automatic repair/retry/cap increase. Commit/push
source, retain outcome and clean owned scratch. Candidate begins unmerged; merge
only after the whole stated fixture contract passes. Original route failure and
20-stage398.296s history remain binding; source historical input still unproved.

Result: candidate7b8cc74797818004cd37ea7952b8c922bfd21338 passed independent
whole-file/caller review, fresh import24.947s, existing suite24.664s/62 assertions
(original35 plus27 codec assertions), and actual driver handoff2.043s. Each stage
exited0 without diagnostics; suite/caller markers exactly once. Actual fixture
PID1608723/port37730 acknowledged raw0→admitting1→raw2→stop3, normal exit0 and
one NATIVE_BROWSER_FIXTURE_STOPPED_OK, within unchanged3s acknowledgement limits.
Three stages51.654s; all ten observed owner/child identities absent. Only the exact
tested fixture file is integrated into main, including its opt-in external mode;
other diagnostic/driver/observer branch changes remain unmerged/withheld.
Raw commands/state, logs, frozen helpers and guards are retained under
`/srv/mudds-work/browser-fixture-json-20261020/results/`. No client admission,
packaged full route, native repair or new gameplay checkpoint is established.
Original20-stage398.296s history and external/human gates remain unchanged.
Integrated/pushed4879b3afd; owned worktree/cache removed after identity checks,
frozen helpers copied/hash-verified and raw profile logs retained. Only results/
remains; freeze→cleanup10.6min against15–30min plus2–5min estimate.

Source preparation only (2026-10-20): clean derivativee5b9dd25f82c9a34bf3982ea1a57f82a87b2a4be
ofcf348472b, originally pushed on `fix/net-timeout-release-accept-20261020`.
Source now preserved under `archive/withheld/net-timeout-release-accept-20261020`;
working refs deleted, original acceptance remains OPEN and source unmerged.
Root copied exactly the originale944 observer, startup loader, privacy test,
Python driver and driver test; all five blobs verified. Accepted fixture blob
4c4b52d5cd35333a10117907b3e859ddb4f87e61 remains unchanged. No783 passive-capture
lines, other source edits, engine/tests/export/runtime or main merge. Independent
source comparison found no adapter/GameFlow/HUD incompatibility. Source preparation
freeze/result retained in `/srv/mudds-work/net-timeout-release-accept-20261020/results/`;
worktree subsequently removed after the stopped template attempt; source and
reviewed helpers retained for any later separately selected check. This preparation does not
close the route. Independent production alternative remains navigator refusal
feedback, now owner-approved for every fresh authenticated current rejection2026-10-21; implementation remains queued.

**NET-TIMEOUT-RELEASE-ACCEPT — dependent runtime acceptance.** GATED on those
matching templates. BROWSER-FIXTURE-JSON now supplies the separately accepted
fixture command handoff; native runtime effectiveness is still unverified. Existing safe export
uses a private versioned template directory, Linux template SHA pin and empty
preset overrides. GODOT_BIN alone does not select the packaged runtime. Windows
must consume the matching patched PE, not the stock template; package audits must
compare against the actual built templates. Keep strict source/package identity,
paired clean exports, actual Linux binary/archive and Windows-payload silent
startup exit0/one menu-ready marker. Native Windows remains NOT_RUN under its hold.
Freeze that candidate/check selection before execution. Preserve original whole
browser timeout→Retry/admission→Disconnect→fresh Cancel→Resume/walk/quit acceptance,
300s cap and all existing UI/fixture limits. No passing prefix or diagnostic
acquisition closes it. Only a working accepted runtime correction earns the next
normal paired playable checkpoint. Original20-stage398.296s investigation history
and all broad/native/human/final gates remain binding/open.

### Supported remote helm action roster

HELM-ACTIONS-DEFINE is DONE as a source definition, not new gameplay or current
source qualification. Production owners: `scripts/control/local_ship_input_source.gd`,
`transformed_ship_command_mapper.gd`, GameFlow's capture/forwarding path and
`network_remote_pilot_command_source.gd`. Defaults below are from `project.godot`;
remaps may replace them. Test references are coverage anchors unless a recorded
accepted source/result is explicitly stated. No tests ran for this definition.

| Action / default binding | Command field | Wire / actual host consumer | Proof and remaining boundary |
| --- | --- | --- | --- |
| Forward W / reverse S; controller axis1 | throttle | move_axis[1] → decoded throttle → HeroShip flight thrust | Forward accepted96c96312f; reverse flight/release accepted52b228c86, actual host motion and both replicas. Reverse-specific handback remains open; recorded yaw/shared handback accepted007024839. |
| Left A / right D; controller axis0 | yaw | move_axis[0] → yaw → host attitude | Turn/release DONE624d2a6; changed-caller regressionf9682a38c retains actual host/replica/neutral gates. Recorded full yaw/handback DONE007024839; physical-device qualification remains open. |
| Up/Down arrows; controller axis3 | pitch | look_pitch → pitch → host attitude | Turn/release sourcequalification DONEf9682a38c using synthetic InputEventAction→production sampler, actual host and both replicas. This does not qualify physical bindings/devices; HELM-PITCH-specific handback remains open; recorded yaw/shared handback accepted007024839. |
| Roll left Q / right R; controller axis2 | roll | look_yaw → roll rate → host attitude | Turn/release sourcequalification DONE73f4a4f67 using synthetic Godot actions through actual sampler/host/both replicas; actual up measured around retained nose. No active barrel roll/request; this is separate from G. Physical bindings/devices and roll-specific handback remain open; recorded yaw/shared handback accepted007024839. |
| Boost Shift; controller button7 | boost | run → boost → host acceleration/speed envelope | Provider mapping anchors in ship_command_test/local_ship_transformed_input_test; actual sampled host effect/release remains HELM-BOOST. |
| Brake PageUp / right mouse; controller axis4 | brake | crouch → brake → host deceleration | Ordinary two-client source96c96312f already proves sampled throttle/brake/neutral0m/s stop; no duplicate brake task. |
| Hover H; controller button0 | hover | jump → hover → host vertical/upright correction | Command boolean anchor in ship_command_test; sampled host correction/release remains HELM-HOVER. |
| Barrel roll G; controller button1 | barrel_roll edge | roll_request_id → interaction_request_id → host pending roll edge | network_remote_pilot_helm_test contains sampled key/first-packet/dedup/rebind cases; this is a static anchor, not a new current-source run. Preserve existing source-specific proof. |
| Landing L; controller button13 | landing edge | landing_request_id → board_request/pilot_landing_serial → host take_landing_request/network landing | Immediate compatibility/FIFO preservation accepted on2c73494 (consumer40/ship79); actual one-pulse331a9628b reaches accepted request and strict physical host dock, but full client arrival fails. No duplicate input investigation. |

Yaw/throttle share unit-disc normalization; pitch/roll clamp independently. Held
commands send at the existing four-tick cadence and neutralize after the host's
30-tick hold window. Edge serials deduplicate with pending booleans; do not infer
one host action per serial increment when multiple presses precede host sampling.

Interact handback uses the separate boarding/seat-swap/disembarkation route
(parent20), not movement helm encoding. Captured mouse-look deltas and local
camera controls are not encoded by this builder; its look_yaw carries roll rate,
not mouse yaw. Fire uses separate craft/role weapon authority owners. Retired
engine start/stop mapper values are false; no additional encoded action is invented.
Synthetic key events, logical Input actions, provider injection and staged
InputEventAction/FIFO cases are distinct proof scopes. None establishes actual
keyboard/controller hardware acceptance. Existing dock/reuse and INPUT-DEVICE
rows retain those requirements; no native/human gate is closed here.

### Supported post-dock exit and reuse cases

NET-DOCK-DEFINE is DONE as a source definition only; parent20 and full multiplayer
qualification remain open. Accepted4c9c764e9 ordinary Jovian return took138.915s
and proves strict physical home docking plus both clients consuming retained
arrival, with original pilot/source/ownership and seated generations. It proves
no post-dock stand, exterior exit or reuse. Keep failed331a9628b client-arrival
history and NET-SECOND-LAND's distinctness gate; neither is a new docking task.

The finite pilot candidates are Torrent, Arrow, Jovian, Zenith, Halyard, Bulwark,
Cinder Light Interceptor, Cinder Cargo Hauler and Cinder Long-Range Bomber. For
each, the acceptance instance is one ordinary occupied-home-dock → pilot exit to
supported station ground → walk clear → reboard the same hull/helm → one physical
repeat departure and neutral stop. Only Jovian has the accepted two-client
ordinary return prerequisite above. Other candidates need their exact supported
ordinary remote route/candidate frozen before execution; the nine-craft snapshot
roster alone does not establish that support. No Cartesian craft/role matrix is
created, and no new physical role is inferred for the small craft or bomber.

The retained physical crew cases below each mean: after that craft's supported
home docking, stand/release the named chair, walk through its actual hatch to
supported station ground, reboard and reclaim that same chair, then remain
supported/secured through the existing pilot's one repeat departure. Each is a
separate instance, gated on its own ordinary docking/role prerequisites; existing
staged exterior approaches and API actors are coverage anchors, not full-route
acceptance. Pilot release/reclaim is its separate instance above.

| Craft / physical role instance | Existing source seam / support boundary |
| --- | --- |
| Jovian passenger at `co_pilot_station` | `jovian_network_two_client_return_test.gd` → flight → boarding → `halyard_network_passenger_route_test.gd`; accepted original two-client arrival is the immediate prerequisite. |
| Jovian engineer at `passenger_port_01` | `jovian_network_engineer_route_test.gd`; role-specific standing/reseat is an anchor, ordinary home docking/exit/reuse remains unqualified. |
| Halyard passenger; engineer; gunner; loadmaster (four instances) | `halyard_network_passenger_route_test.gd`, `halyard_network_engineer_route_test.gd`; authored passenger/loadmaster station, `crew_port_01` engineer and `co_pilot_station` gunner contracts. Loadmaster is a physical passenger assignment with its own action; layout-only navigator/sensor/co-pilot labels add no supported role. |
| Bulwark gunner at `gunner_station` | `bulwark_network_gunner_route_test.gd`; supported authored pilot-to-gunner cabin corridor has focused capsule/skin coverage; ordinary full moving-cabin/dock-exit/reuse and a physical engineer instance remain unaccepted. Unanchored engineer policy is not a chair. |
| Cinder Cargo Hauler loadmaster; navigator (two instances) | `halyard_network_passenger_route_test.gd --cinder-loadmaster` / `--cinder-navigator`; `cinder_loadmaster_station` / `cinder_navigator_station` are physical passenger assignments. Navigation ping API actors do not establish physical navigator route acceptance. No extension to other Cinder hulls is implied. |

**Original passenger-exit selection — now DONE; full Jovian reuse accepted below.** The visible
result is that the original second client can leave the co-pilot chair after
home arrival, walk out onto the freight-berth deck and continue walking, while
the original first client retains the helm. Reboarding that passenger, pilot
exit/reclaim, and repeat departure are ordered successors, not extra next-task
requirements. The engineer and other craft instances remain unscheduled.

- **Caller/ownership:** extend existing
  `tests/network/jovian_network_two_client_return_test.gd` with a select-only
  `--postdock-passenger-exit` continuation after `_client_return` / host arrival confirmation and before the
  inherited retained-seat handshake. Update only the selected case's final
  retention expectation; `_local_flight_current` / `_host_flight_identity_current`
  require seating and cannot remain the guard for a legitimately standing/exited
  passenger. Reuse boarding `_press`, `_look`, `_walk_to` and inherited process
  coordination; retain default accepted return behavior. No new harness/validator.
- **Production repair owners, only if first failure identifies one:**
  `scripts/game/game_flow.gd` physical-crew stand/boarding presentation,
  `_request_network_client_boarding`, `_network_boarding_departure_status` and
  `_release_network_client_boarding_presentation`;
  `scripts/network/network_boarding_authority.gd`,
  `network_ship_ownership_authority.gd`, `network_remote_body_simulation.gd`;
  `scripts/ships/crew_seat_role_authority.gd`, `jovian_light_freighter.gd` authored
  stand/hatch/exit route; `scripts/interaction/ship_boarding_area.gd` reservations
  and `scripts/world/ship_berth.gd` physical lease. Freeze the actual failing
  owner before editing; do not rewrite all owners or networking speculatively.
- **Actions/evidence:** original non-playing Main host plus original two Main
  clients; client_b uses sampled Interact, ordinary look/walk and hatch Interact
  through authored exit to ground, then walks clear. No teleport, direct claim,
  body registration, forced landing flag or private transition call is an action.
  Read both client presentation and host body/ledgers: exact passenger chair
  released before exterior boarding occupancy/reservation release; actual
  supported/control-enabled unseated Player and measurable ground locomotion;
  no stale chair/berth claim or cabin containment after exit. Retain original
  authenticated peer/avatar and local Player identity; record body entity and
  ship/frame/seat/ownership generations and claim sequences at each boundary.
  Lifecycle retirement/rebinding must follow the production owner, with no old
  generation resurrected; do not require a departed body's cabin binding to stay
  current. The uninvolved pilot keeps exact source/stream/delivery epoch,
  ownership and pilot seat claim. Home berth remains physically occupied by the
  same hull with valid token/lease and committed landed entity generation.
- **Bounds/stop:** preserve existing300s total,300s peer deadline,15s/walk
  waypoint, existing8s role/boarding transitions,120s physical return and5s
  arrival convergence; no deadline increase to fit the continuation. Retain
  independent abort, first-failure snapshot, input/cursor cleanup and actual
  host/client/client_b OS exit0 receipts before success. Run only the selected
  continuation after implementation using `godot --headless --audio-driver Dummy
  --path . --script res://tests/network/jovian_network_two_client_return_test.gd
  -- --postdock-passenger-exit` (select-only candidate8054a2cc4, unreviewed and engines NOT_RUN), headless
  coordinator/private Xvfb peers and explicit `--display-driver x11`. First
  failure stops with exact boundary/owner; source comparison ran no engine.
  Native Windows/GPU/device/human gates remain NOT_RUN. Definition adds no
  gameplay feature, checkpoint requirement or project percentage progress.

### Retained Jovian exit/reuse cards — parked, outside the active queue

The original exit caller and its one repair failed parsing; those two attempts
ran no gameplay. Candidates8054a2cc4/e147b6d49 and raw failures remain retained.
Later selected2aed310cd passes syntax but fails its one full postdock route;
its single0d225bee8 corrective attempt reaches standing but fails cabin walking;
[actual result](history/ROADMAP_DELIVERIES.md#jovian-passenger-exit--syntax-passes-postdock-route-stops) below supersedes gameplay-NOT_RUN for that candidate only. These five
ordered cards preserve their acceptance/dependencies; none is currently selected.
Numeric predecessor references here mean this parked five-card Jovian sequence,
not the executable queue.
Full syntax correction/review and the one later runtime corrective attempt have
run. Cumulative priority review now parks the chain; no further repair/retry is selected.

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
- **Execution/result:** independent review of8054a2cc4 found no lifecycle/default
  blocker; clean import PASS. Compile FAILED at line321: single-line lambda
  predicates continued across physical lines without explicit continuation.
  No selected gameplay route started. Source/cache guards held, supervisors ended,
  raw is retained in `/srv/mudds-work/jovian-passenger-exit-20261018/results/`.
- **Bounded repair result:** NET-JOVIAN-EXIT-CALLER-PARSE FAILED at clean
  e147b6d49. Three explicit continuations fixed the original line321 boundary,
  but the single allowed compile retry finds another parse error at line406.
  No route, peer, passenger exit or production runtime was exercised. Both
  failed commits/raw are retained; no test acceptance was relaxed.
- **Original priority review (before2026-10-20 selection):** about45 min implementation/review/setup plus bounded
  correction/check time; one task failure plus one attempted repair is used.
  The unresolved outcome is ordinary postdock exit, not an established game
  defect. Competing READY WALK-ANNEX has a frozen route and separate caller;
  root selected it. No further Jovian diagnosis/correction/compile/route is
  selected. A future explicitly bounded caller syntax review/correction must
  precede any requalification; original300/360/15/8/120/5 limits remain.
- **Close/retention:** preserve refs8054a2cc4/e147b6d49 and both raw failures,
  commit/push, remove owned clean checkout/private profiles/helpers after process
  closure. This failed caller is not merged and needs no checkpoint. Original
  return remains accepted only at its earlier source scope. Reboard/reclaim/
  redepart and native/device/world/endurance gates stay open.

- **Later selected syntax review / runtime stop2026-10-20:** source2aed310cd
  reapplies the retained continuation to current6c584673a and fixes all five
  multiline predicate sites without changing operands/default behavior/limits.
  Independent high review GO. Import20.625s/check-only16.528s PASS. One original
  three-peer route FAIL129.786s after actual strict home return/convergence.
  First host get_path diagnostic: inherited boarding-test _node_identity583,
  called _postdock_receipt608 for off-tree command source. Later pilot-retention
  and passenger-standing assertions fail; no exterior exit or ground walk.
  Current cumulative166.940s; prior two parse failures retained, not reset.
  Candidate pushed/unmerged/withheld; no runtime repair, new checkpoint or retry.
  All22 observed process identities absent;76 profile entries archived/verified,
  owned worktree/cache/profiles/helpers removed at5.36min within45min card.
  [Full result/remaining boundary](history/ROADMAP_DELIVERIES.md#jovian-passenger-exit--syntax-passes-postdock-route-stops).
  That receipt fault is addressed by the later candidate below; its failed full
  route still prevents acceptance. Preserve
  original300s suite/360s outer/300peer/15walk/8transition/120return/5convergence.

- **One measured drift/receipt correction2026-10-20 — WITHHELD:** raw data
  identifies initial pilot failure as hull0.494335→0.500294m from exact host dock,
  current ownership/source5/5 and neutral controls. Pose reconciliation applies
  flight deadband after authoritative landed+docked. Passenger snapshot was
  rising0.05/0.45s after shared pilot abort, not a proven separate stand defect.
  Source0d225bee8 adds current dock hold in existing pose stream and regression
  coverage, plus source instance identity without an invalid get_path receipt.
  Independent high review GO; import20.674s/full pose42.374s322/check-only16.487s
  PASS. One original3peer route FAIL145.995s: actual stand/host confirmation pass,
  pilot captured exactly at host dock/source5/5, but host15s cabin-walk predicate
  fails. Supported/control-enabled same passenger at(-52.6118,2.11189,64.56992),
  target(-52.22,2.41,65.82); no hatch exit/ground walk. No locomotion cause proved.
  Remaining get_path diagnostics occur in inherited first-failure producer-state
  capture, not corrected postdock receipt. Corrected225.530s+prior166.940s gives
  current chain392.470s; original parser failures retained separately. Failed
  runtime plus one corrective attempt now PARKED by cumulative priority review;
  no second repair, retry, cap/tolerance increase or renamed adjacent probe.
  Candidate pushed/unmerged; exports/checkpoints NOT_RUN, latest public923d7b3.
  All25 new process identities absent;85 profile entries archived/verified,
  owned scratch removed at17.09min within original05:35→06:20/45min budget.
  [Actual source/result](history/ROADMAP_DELIVERIES.md#docked-pilot-hold--focused-pass-full-exit-stops-at-cabin-walk).

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

**Accepted49bc7b736:** complete original journey PASS149.242s;3466 checks,
zero failures, one marker and three actual OS0/clean logs. Same passenger walks
1.236m outside, clears9m lockout, returns through supported apron/hatch and gets
a new body/claim3/currentgen1/stream2. Host and passenger first stand with empty
chair assignment, then ordinary walk/look/Interact takes the original co-pilot
chair and both clients consume its exact current relationship. Original pilot,
source/ownership and strict occupied home lease remain retained.

Actual diagnostic run shows old hatch ID3 accepted but not consumed before body
retirement at ID2; neutral rebound opening retransmits3. Accepted producer binds
a baseline and retires those pre-bind edges without resetting lifetime highwater
or losing fresh/retry actions. Source98 and real-body42 checks pass; fresh paired
checkpoint49bc7b7, strict menu/package checks and independent review GO.
Prior680.117s qualification and381.549s failed consumed-floor repair remain
preserved WITHHELD. Failed server-floor patch and diagnostic tracing are absent
from accepted source. Owned profiles verified/removed; no new branch/worktree.
Native Windows/GPU/devices/human/full baseline/endurance/parent gates remain open.
[Acceptance and retained failures](history/ROADMAP_DELIVERIES.md#jovian-passenger-reboard--accepted--2026-10-20).

### NET-JOVIAN-PILOT-EXIT — release helm and reach ground

**DONE63186dc80, parents16/20/26.** Full accepted passenger-reboard journey first;
original pilot then uses ordinary landed Interact, traverses the complete authored
hatch/airstair route with the same Player, reaches supported berth ground and
walks1.254681m through normal movement. No fabricated intermediate cabin body;
production's landed pilot exit is a direct physical disembark. Passenger stays
in its exact original co-pilot chair; reclaim/redeparture remain separate.

Host old source freed, pilot command queue reset, ownership0/gen2, exact pilot
seat/role/body/publication/relationship retired. Both clients consume released
ownership and a fresh same-hull pose after the actual host retirement boundary.
Client helm remains quiet during supported ground input; hull displacement and
speed stay0, strict occupied home lease and landed generation1 remain valid.
Full route153.310s/4338checks/3actualOS0/clean logs; independent GO. Original
300s/outer360s/waypoint15s/transition8s/landing120s/convergence5s/exit10s retained.

Initial153.970s failure was an unsupported new caller expectation: a coasting
pose attribution never becomes0. Actual ownership and controls already retired.
Only that observation changed; original failed source/raw preserved. Runtime,
assets and tools match49bc7b736; no identical rebuild. Owned scratch archived,
348 entries verified/removed;30 observed identities absent; integrated/pushed
main remains sole branch. [Proof and limits](history/ROADMAP_DELIVERIES.md#jovian-original-pilot-exit--accepted--2026-10-20).
Full parent/baseline/endurance/native/hardware/human/final gates remain open.

### NET-JOVIAN-PILOT-RECLAIM — reacquire the same helm

**DONE07ec703c7, parents16/20/26.** Full accepted passenger-reboard and original
pilot-exit/groundwalk journey first. Same original pilot clears the real7m hatch
lockout via supported apron corridor, returns through the authored hatch, consumes
its newly admitted cabin body, walks to cockpit and uses normal Interact to take
the pilot seat. Same peer/avatar/Player; no fabricated authority or forced seat.

Host current pilot claim5/ownershipgen3, fresh source and actual higher wire1
agree with owner accepted swap/local seat/producer stream+delivery10 and fresh
same-hull pose. Passenger client consumes the exact actual SEATED pilot relation
and keeps its original co-pilot claim3/current body. One explicitly reconstructed
old-stream0 probe receives a real stale_stream refusal; new pilot authority
survives. Strict occupied home lease/landedgen1 and stationary hull persist.
Full route165.990s/6571checks/3actualOS0/clean logs; independent GO.

Initial169.246s failure retains source/raw: owner's old walking relation is an
expected cache because seat-anchor publications exclude their owner. Correction
moves that exact remote consumer check to passenger only; owner's actual accepted
swap/seat/source/epoch/fresh-pose checks remain. Original300s/outer360s and15/8/
120/5/10s limits unchanged. Five stage intervals total369.397s including failures.
Owned scratch archived/409 entries verified/removed;32 observed identities absent.
Integrated/pushed main remains sole branch. Runtime/assets/tools unchanged from
49bc7b736; no identical rebuild. Latest playable49bc7b7 remains current.
[Proof and limits](history/ROADMAP_DELIVERIES.md#jovian-original-pilot-helm-reclaim--accepted--2026-10-20).
Repeat departure is now accepted below; full baseline/endurance and parent/hardware/human gates remain open.

### NET-JOVIAN-REDEPART — depart once after actual reuse

**DONEbc7f9f9c4, parents16/20/26.** Same original pilot and co-pilot complete
the entire ordinary boarding/flight/home docking, passenger physical exit/reboard,
pilot physical exit/groundwalk/reclaim and actual old-stream-refusal journey.
Only then ordinary pilot thrust travels5.208m along the new departure nose and
releases the physical occupied berth, old lease/token, reservation and bookkeeping.
Current landing state becomes flying/gen2; ship/seat/framegen1 and ownershipgen3
remain separate and current. Ordinary brake holds host speed0 for1019ms at the
stop receipt,11.655m from departure start.

Both actual clients consume post-stop pose6939>host stop6936 within5s, with
pilot/passenger hull errors0.493233m/0m<=original0.5m and seat-anchor errors0.
Reclaimed pilot claim5/new source/local producer10/newwire1 and original co-pilot
claim3/body/frame survive inherited retained/leaving handshake; old source is gone.
No staging, direct authority mutation, second landing or additional craft.
Full route PASS168.850s/6987checks/zero failures, three actual OS0/clean logs;
independent final GO. Original full300/outer360, forward10/brake10/convergence5/
barrier8/exit10 and complete prefix caps unchanged.

Pre-launch review corrected client strict-stop timing: keep moving invariants
while waiting for its own strict stopped-pose consumer, then set the final flag.
Both source versions compiled; one full run only. No runtime/assets/tools changes
from49bc7b736, so latest playable49bc7b7 remains current without identical rebuild.
All3 owners terminal/18 observed identities absent;226 archived entries verified
before exact owned scratch removal. Integrated/pushed main sole branch.
[Proof and limits](history/ROADMAP_DELIVERIES.md#jovian-departure-after-physical-crew-reuse--accepted--2026-10-20).
This closes the named Jovian pilot/co-pilot ordinary reuse instance. Other
supported craft/roles, distinct second landing, full baseline/endurance and parent/
native/hardware/human/final qualification remain open; no adjacent case selected.

## Performance, controls, accessibility and audio

Scope: original §5, Phases 9 and 10.2–10.3. Software rendering, VM and remote-display behavior do not qualify native target GPU performance.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| PERF-MACHINE[one minimum/target profile] | WAITING on representative hardware if unavailable | Bind declared CPU/GPU/RAM/display/driver profile to an actual isolated test machine. Stop at available machine identity or exact missing resource; never infer native performance from llvmpipe. |
| PERF-ROUTE[one missing benchmark route] | GATED on PERF-ROUTES-DEFINE naming a concrete uncovered workload | Implement the selected actor/action/measurement through the existing runner, with its focused selection check. Seven selectors already exist; see coverage below. Cabin/surface repetition and combat reuse are implemented. Do not infer another missing route from those family labels. Preserve default combined scope and original measurement floors; stop at the selected executable route, not a new benchmark system. |
| PERF-RUN[one machine/scenario] | GATED on machine and executable route | Original warmup at least 3,600 frames/60s; measurement at least 18,000 frames/600s. At 1080p High, p95 ≤16.7ms, p99 ≤33.3ms, no post-warm frame >100ms, peak working set ≤4GiB, plus required actual GPU/VRAM and streaming/transient budgets. Stop at that measured scenario; retain failure. |
| PERF-FIX[one measured hotspot] | GATED on demonstrated production cost | Fix the identified runtime/rendering owner; repeat the affected measurement and behavior check. Stop at measured effect and checkpoint; no census-only progress. |
| INPUT-DEVICE[one device/route] | WAITING on physical device if absent | Ordinary full selected route with actual keyboard/mouse or controller, including lifecycle/planetary control as applicable. Existing physical-sortie, lifecycle and controller-only expedition tests guide scenario. Stop at selected route; synthetic events cannot qualify physical hardware. |
| INPUT-REMAP[one setting/binding] | ELIGIBLE for automated persistence; physical confirmation separately | Remap/apply/restart retains binding and usable menus/gameplay, with conflicts/recovery as specified. Reuse runtime remapping/presenter/contract tests. Stop at one case. |
| FIRE-RESTART | DONE3a45c4d79 in original Linux-source real-file/distinct-process composition | Visible Fire row captures rawF13; actualApplySave/defaultfile; distinctsame-filereader row/InputMap/production LocalShipInputSource agrees onpress/release/formerF+leftmouseoff, gamepadbindings/unrelatedsentinel retained. Writer17checks/31.188s andreader19checks/31.012s, bothOS0/cleanlogs/original300s. Enginebuffer flushedbeforeobservation; originalkeys/predicates/flags/defaultsuite unchanged. Reviewed/merged/pushed/ownedscratchcleaned; previousfailures+source retained. Physicaldevice/fullSettings/native/final qualification separate. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-fire-restart--full-raw-dispatch-and-separate-process-contract-qualified--2026-10-20) |
| ACCESS-VIEW[one view/scale/aspect] | ELIGIBLE for isolated capture; relevant hardware separately | Verify readability/focus/clipping for named view at minimum/default/maximum scale and one of 4:3, 16:9, 16:10, 21:9, 32:9. Instantiate each required cell separately, using existing runtime accessibility tests. Stop at one view/cell or fixed finding. |
| ACCESS-COMFORT[one route/option] | ELIGIBLE; existing runtime options | Verify one reduced-motion, flash, color-safe or caption behavior in actual route and after restart as required. Stop at named option/scenario and any focused correction. |
| AUDIO-CONTENT[one cue/transition gap] | GATED on identified missing behavior | Author/fix one production ambience/music/effect transition and run existing music state/activity/orbit/surface integration checks with Dummy audio. Delivered Aurora coast is not a new gap. Stop at cue/transition and checkpoint. |
| AUDIO-MIX[one real-output scenario] | WAITING on explicit audible-test authorization and output device | Check actual mix/levels/transitions for selected scenario, fix concrete issue and repeat it. Stop at scenario result; automated Dummy output does not qualify real audio. Owner-excluded human review does not become a mandatory approval gate. |

### Benchmark workload definition — retained coverage and missing decision

PERF-ROUTES-DEFINE remains **DEFINE**, not a missing implementation roster.
Source review of `tools/performance/benchmark_runner.gd` establishes these seven
selectors; it is not a new benchmark run or native performance qualification.

| Existing selector | Implemented workload |
| --- | --- |
| `station_embodied_route` | Station player walk; part of the default pair. |
| `nearby_sector_ship_flight_route` | Torrent flight along the streamed Cinder approach lane; part of the default pair. |
| `halyard_cabin_walk_route` | Stationary Halyard aisle, repeated out-and-back. |
| `torrent_range_combat_reuse_route` | Torrent fire, authoritative DRONE-01 destruction, reset and reuse. |
| `ember_surface_walk_route` | Repeated authored Ember surface trail. |
| `aurora_surface_walk_route` | Repeated authored Aurora coastal trail. |
| `rime_surface_walk_route` | Repeated authored Rime icefall survey/return trail; delivered on a8f563e39. |

Retained deliveries: Halyard D5, Torrent combat E1, Ember E2, Aurora
c47b5cd55 and Rime a8f563e39. Rime's recorded check sampled521.227m across13
ordered points/one loop, with source33/default152/Ember24/Aurora27 assertions
and paired development checkpoint a8f563e. These are historical results, not
new execution or full-expedition acceptance.

The five select-only routes do not expand `DEFAULT_SCENARIO_ORDER`. Surface
selectors stage production actors; they do not perform admitted Host expeditions,
outbound travel, landing or return. Aurora's benchmark supplies its binding
cadence explicitly without inventing an admitted visit.

**Uncovered workload:** whole orbit-to-surface expedition repetition from the
original Phase10.4 long-session requirement. The retained contract does not name
its representative benchmark craft, world or cycle. Define those and map the
measurement to the existing world-endurance outcome before selecting a route;
do not duplicate that journey as a second completion requirement. Additional
fleet/cabin/combat representatives also need an explicit workload justification,
not a selector per craft or another copy of an existing walker. No new selector,
profiling run or retry of parked Q4 startup work is selected here. Minimum/target
hardware and all PERF-RUN timing, frame-count and memory/GPU budgets remain open.

### Dormant opponent presentation — bounded cost decision

**Decision DONE onf350e0a3d: rejected as next performance priority.** The single
frozen six-actor function microbenchmark measured89.824us combined, below the
preselected100us threshold. Import/probe both pass, state remains quiescent,
no runtime edits or performance fix selected. This is not native FPS/GPU/full Main
qualification or a delivered optimization. [Exact fixture/result/limits](history/ROADMAP_DELIVERIES.md#dormant-opponent-presentation--cost-decision).
Only `/srv/mudds-work/dormant-opponent-cost-20261020/results/` remains after owned
cleanup; original probe, raw three-batch timings and private logs preserved.
This is parent28; parent35 in the initial frozen heading was a metadata error,
not a change to the measured contract or a final-regression claim.

### Aft console arrival — one component presentation review

**FAILED/PARKED on81b9ee3ba**, with pre-render cache authorization33ccc26fb.
Clean import19.596s passes; isolated Xvfb/Forward+/llvmpipe capture times out
120.485s/exit124 after camera setup, before PNG save; marker0, no image or
visual finding. No runtime defect or root cause is established. Source/cache
unchanged; all owned processes absent, scratch cleaned, raw/helper/profile data
retained in `/srv/mudds-work/aft-console-view-20261020/results/`.
[Original contract/results](history/ROADMAP_DELIVERIES.md#aft-console-arrival--component-review-failed).
No repair, increased cap, alternative renderer/view or retry selected. Actual
Aft visual acceptance and the separate upper-workpost view remain OPEN.

### Remaining UI view roster — ACCESS-VIEWS-DEFINE

DONE as a source definition, not layout or device qualification. Owners below
are the actual production surfaces in `scripts/ui/hud.gd` unless named otherwise.
Use the five aspect groups and three authored scales in the pause/options roster
below. Select one row's named state and one aspect/scale cell per bounded task;
do not start a whole-UI Cartesian run. Preserve existing accepted cells and
original wider acceptance promises. Source/test anchors are coverage maps, not
new test results. No engine, capture or physical input was used for this definition.

| Child family / visible states | Actual owner | Existing coverage / what a new cell must establish |
| --- | --- | --- |
| ACCESS-TITLE: ordinary startup menu and return from browser/credits | GameHUD intro layer / `show_intro`, `_focus_intro_start_button` | `startup_loading_screen_test.gd` proves menu readiness; `controller_pause_navigation_prompt_test.gd` covers browser return and `credits_page_test.gd` covers credits return. A selected cell checks title text, Begin Shift/browser/credits buttons and retained enabled focus. Unresolved recovery choices use ACCESS-RECOVERY below.  Overflow fix DONE checkpoint19e7990: actual default1024x768 before/after component capture plus eight-viewport title/control regression; focus/credits remain. ACCESS-TITLE-FOCUS light-on-cyan finding is separate; no full-Main, other state/scale/device acceptance. |
| ACCESS-GAMEPLAY: approach, boarding confirmation, first-sortie tutorial, activity briefing/objective, weapon readiness, component damage, fleet registry | GameHUD interaction/tutorial/objective/weapon/component/registry panels; boarding confirmation adapter | `ultrawide_layout_test.gd` names these states and checks production Controls. Retain actual simultaneous telemetry/minimap/help/toast/interaction/status composition; one selected state/cell must preserve readable labels and nonoverlap rather than fabricate every possible card combination. |
| ACCESS-HELP: on_foot, aboard, driving, piloting; each reachable help page, plus published copilot/loadmaster context rows | `_help_rows_for_mode`, `_help_rows_with_role_context`, `_refresh_help_page`; five rows per page | `help_overlay_accessibility_test.gd` checks paging and enabled boundary focus; `runtime_input_glyph_hud_integration_test.gd` checks device text. A cell checks all pages of one named mode/context, labels and Previous/Next/Close focus. Aircraft-specific text uses the existing selected craft; new control semantics are not implied. GAMEPAD-LOOK repairs the found camera-input gap in checkpoint99e79c3. |
| ACCESS-ACTIVITY: selection page, current selection/status/reward summary, return from nearby page | ActivitySelectionPage / `open_activity_board`, `_show_activity_selection_page` | Existing ultrawide `activity_board` calls `open_activity_board`: this is the selection page. It does not cover NearbyActivityPage. Check visible rows/footer and return focus in one cell; preserve authored selection behavior. |
| ACCESS-NEARBY: activity list, current progress, rejected start guidance, terminal delivered/lost feedback | NearbyActivityPage / `show_nearby_activity_page`, `set_nearby_activity_snapshot` | `nearby_activity_hud_integration_test.gd` covers real HUD entry, ten production rows and cargo pickup/transit/delivery/terminal feedback. Check list top/middle/bottom, enabled actions and Back focus in a selected cell. Other activities use their published current presenter rows, not invented activity variants. |
| ACCESS-DESTINATIONS: destination list, selected destination detail/status, enabled travel and Back | PlanetaryDestinationPage / `open_planetary_destination_board`, `_restore_planetary_destination_focus` | `planetary_destination_console_production_test.gd` covers the actual console route; catalog/content-contract tests describe authored rows. A cell checks retained destination rows, scroll/detail/footer and disabled versus enabled action focus; presentation does not establish planetary travel acceptance. |
| ACCESS-BROWSER: refreshing, available/full rows, all-full, empty, unavailable/retry; manual controls and connection cancel/disconnect | ServerBrowserPage / `_show_server_browser_page`; server_browser_presenter | `server_browser_hud_integration_test.gd`, `server_browser_focus_navigation_test.gd`, `server_browser_manual_controls_hud_integration_test.gd` cover status/focus behavior. Select one state/cell; verify headers, filters/sort, scroll rows, guidance and enabled footer actions. Connection-state wording follows the current network presenter; this is not network qualification. |
| ACCESS-CREDITS: intro entry and pause entry; attribution list and engine notices; return to opener | CreditsPage / `_show_credits_page`, `close_credits_page` | `credits_page_test.gd` covers entry provenance, scroll focus and content. A cell checks top/bottom/notice text and keyboard/controller focus return. No new attribution or license scope is created. |
| ACCESS-CAPTIONS: current caption, transcript collapsed/expanded, transcript paging | caption_presentation_service, caption_presenter; GameHUD semantic transcript controls | `caption_presenter_layout_test.gd`, `caption_accessibility_contract_test.gd`, `caption_production_integration_test.gd` and ultrawide captions state supply existing anchors. Check readable caption/history controls and supported surrounding cards. Preserve the existing ToastPanel/expanded transcript non-simultaneous exemption. Dummy checks cannot qualify audible output. |
| ACCESS-ROLE-STATUS: copilot navigation support, loadmaster telemetry, bomber readiness, boarding/recovery cue | GameHUD runtime status composition; copilot/loadmaster presenters, cinder_loadmaster_hud_binding, boarding adapter | Existing copilot/loadmaster/bomber/boarding/audio-recovery HUD tests cover their own published payloads. Select one card/cell and its actual priority/retirement composition; check text, actions and caption reservation. Do not force mutually exclusive foreground cards to coexist or infer role authority from the HUD. |
| ACCESS-RECOVERY: title recovery notice/choices/support feedback, safe-start recommendation/result | GameHUD recovery prompt layer; safe_start_recovery_presenter | `session_recovery_hud_test.gd`, `game_flow_session_recovery_hud_integration_test.gd`, `game_flow_safe_start_recovery_hud_integration_test.gd` cover their named routes. Check one visible notice/result and enabled action focus without initiating destructive recovery as a layout shortcut. This does not accept parked interruption routes. |
| ACCESS-REST: entering/resting/leaving visible overlay and wake affordance | `scripts/ui/ship_rest_overlay.gd` | Existing ultrawide `ship_rest_overlay` state constructs the actual overlay. A cell checks its authored presentation and wake text with current motion setting; rest gameplay and physical controls remain separate acceptance. |

A selected cell must name its source pin, state, requested/effective scale and
resolution before running. Use the existing relevant test and actual Control
geometry first; add only a focused missing regression for a concrete layout fix.
For rendered inspection use an isolated display with explicit x11 and Dummy audio.
Check viewport/safe-area containment, readable untruncated essential text,
authored scrolling access and enabled focus/return. Preserve existing clipping,
background and mutually exclusive-card exemptions; do not weaken them to pass.
The existing ultrawide suite's five resolutions omit16:10, and its four authored
presets do not sample minimum0.75 scale. The separately accepted16:10 pause
case stays accepted in its scope; it does not accept every row above. Human
readability/device/native GPU judgments stay unperformed until actually tested.
Stop after the selected cell or its concrete discrepancy; a runtime repair needs
its own bounded files/checks/checkpoint card. No serial validator or new tracker.

### Pause/options view and cell roster

ACCESS-PAUSE-DEFINE is DONE as a static definition. Actual owners are
`GameHUD._build_pause/_build_settings_page/layout_for_viewport` in
`scripts/ui/hud.gd`, RuntimeSettings (MIN_UI_SCALE0.75, DEFAULT1.0, MAX1.6),
and the existing display/rebind/repair presenters. Each observation must record
requested and effective pause scale: the authored fit ceiling may reduce it.
No capture, test or real-device review ran for this definition. Later qualification
results are recorded in the child inventory.

| Surface / required visible state | Production node or owner | Existing coverage anchor / remaining distinction |
| --- | --- | --- |
| Pause main, resume/settings/back focus | PauseMainPage / _show_pause_main | ultrawide_layout_test pause_menu; controller_pause_navigation_prompt_test; runtime visible Control geometry, not human review |
| Normal options, both columns, top/middle/bottom scroll and Save/Reset/Back | SettingsPage/SettingsScroll | FLIGHT+CAMERA, bindings, DISPLAY, MULTIPLAYER, AUDIO MIX, ACCESSIBILITY and status/footer must be reachable; settings_menu baseline alone does not inspect offscreen rows |
| Binding capture/conflict/reset row | _build_input_bindings / runtime rebind presenter | runtime_input_rebind_hud_integration_test; preserve focus and scrolling after a row changes |
| Unsaved reset confirmation and cancel/confirm return | _settings_reset_confirmation | _request_settings_reset/_confirm_settings_reset; must not strand focus when retired |
| Pending display Keep/Revert/countdown/result | DisplaySettingsConfirmation | display_settings_hud_integration_test; temporary resolution confirmation is a distinct visible state |
| Settings repair notice, failure and confirm surface | SettingsRepairNotice | runtime_settings_repair_hud_test/integration; presentation cannot invent persistence authority |

Five named aspect groups:4:3 at1024x768,16:9 at1920x1080,16:10 at1920x1200,
21:9-class at3440x1440 and32:9 at5120x1440. Each checks the three authored scales
0.75/1.0/1.6 for this finite pause/options surface set. These are the explicitly
promised scale/aspect axes, not combinations of every setting/device/world.
The remaining production surfaces are defined below; no whole-UI acceptance is inferred.

Existing `ultrawide_layout_test.gd` resizes production Main/Window and already
contains pause_menu/settings_menu at4:3,16:9,21:9,32:9 with authored/reduced-motion/
large-text/high-contrast presets. It lacks16:10 and the minimum-scale Main preset.
`hud_ultrawide_safe_area_test.gd` covers16:10 and all three scales for gameplay
HUD in a SubViewport, not the missing pause/settings Main state. The detached
runtime_accessibility_presentation test covers policies/status/prompt fitting,
not these Controls. settings_focus_navigation checks focused right-column entries
and re-entry; it does not establish every scale/aspect or rendered readability.

The retained ACCESS-PAUSE-16X10 qualification contract uses the existing Main layout
fixture, one named viewport and its pause/options states, retaining actual window,
safe bounds, font-floor/focus/scroll criteria and original300s cap. Extend that
fixture only for uncovered cases; no duplicate harness/validator. At the first
actual defect, stop and name a separate UI repair. Existing native/device and
visual-capture requirements remain unperformed; static anchors are not passes.

## Recovery, packages, captures and release

Scope: original §6 and retained installed-interruption milestone. Final-candidate qualification is scheduled once dependencies are met, not attached to every child.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| RECOVERY-CONTRACT[one context] | DEFINE if resume/safe-recovery outcome ambiguous | Name expected durable boundary, supported player/craft/berth/seat state and route back to normal play. Distinguish promised pose resume from safe-home recovery. Stop at executable contract, not expanded restoration promises. |
| RECOVERY-FIX[one reproduced failure] | GATED on contract/reproduction | Correct existing save/runtime owner; preserve valid/unsupported data, secret-free diagnostics, ownership and once-only rewards. Use real file/fresh process. Stop at affected check and required checkpoint; ACT-WRITE covers activity boundaries without duplicate assignment. |
| RECOVERY-KILL[one activity/context/package] | GATED on contract and exact Linux install/archive | Own the process, interrupt using actual OS SIGKILL, restart a distinct process and check durable boundary, usable recovery, rewards and actor closure. Select pilot, cabin, rest, crew, docking, activity or planet context individually. ca0 Convoy four-context passes remain source-specific; no airborne-pose claim. Stop at one context. |
| PACKAGE-WIN[one clean checkpoint] | ELIGIBLE after meaningful integrated change | Existing safe clean export: focused checks, exact EXE/ZIP/notes identity, embedded PCK/PE metadata and silent isolated Windows-payload startup through supported Linux-engine workflow. Require exit 0 and `STARTUP_MENU_READY_OK`; fixed quit frames are insufficient. Stop at exact package checks. Native Windows execution remains excluded/held. |
| PACKAGE-LINUX[matching checkpoint] | GATED on selected clean source | Export matching ELF/archive; existing inventory checks, exact member bytes/modes, direct and archive-extracted strict startup. Stop at exact artifact checks. |
| INSTALL-WIN[one candidate] | GATED on packages | Build matching installer with existing NSIS tooling and inspect exact extraction/build identity and applicable non-execution checks. Native installation/execution is excluded; do not bypass antivirus. Stop at artifact checks, with unperformed runtime factual NOT_RUN. |
| LINUX-BUNDLE[managed installer] | DONE on `653c1459d`; actual six-member package verified | Ship the delivered manager in the archive, preserving explicitly supported old/new bundle contracts. Stop at archive install/update/uninstall, exact binary and protected-data checks using existing tests. |
| INSTALL-LINUX[one transaction] | ELIGIBLE for managed per-user install | One clean install, old-to-new upgrade, rollback, retained/corrupt data handling or uninstall transaction preserves saves/unrelated files and exact owned artifacts. Installer12 tests and actual shipped-manager36 checks pass onb41c3cc, including named first-install/update SIGKILL publication cuts and fresh retries. Current LINUX-UNINSTALL-CUT reproduces the shipped a8 missing-menu refusal after an actual post-desktop-unlink SIGKILL; source repair505d41968 is accepted with all14/no-skip installer tests; checkpoint505d419 ships the fixed manager and passes the actual named SIGKILL/retry/repeat with protected bytes/modes intact. Select uncovered/new-candidate transactions, not redundant reimplementation. This named uninstall cut is accepted; other cuts/power loss remain open. |
| LINUX-DESKTOP[one entry/ordinary route] | WAITING on clean isolated graphical Linux session if unavailable | Launch actual installed desktop entry or direct ELF and complete ordinary route; test each separately. Inert GIO argv probe and headless startup are insufficient. Stop at entry+route result; no implied native GPU/input/audio qualification. |
| CAPTURE[one required registry ID] | GATED on frozen candidate and runnable environment | Run unchanged registered harness with isolated X11/Dummy, verify declared source and exact images, inspect original-resolution output and fix actual finding separately. Stop at one set. Human stages are excluded; hardware gates separate. See blocked sets below. |
| RIGHTS[one asset/source family] | GATED on available provenance/rights information | Record licensing/redistribution disposition for the named family. Preserve owner's settled creator-permission account without claiming a written grant or asking again. Stop at clearance or exact missing external document. |
| SIGN[one exact artifact family] | WAITING on trusted certificate/credentials outside repository | Use existing `sign_windows_artifacts.sh` workflow to sign/verify game, installer and uninstaller, expected publisher and exact distributed bytes. Development signing cannot qualify. Stop at trusted signatures; native Windows execution is not required. |
| MATRIX[one frozen integrated candidate] | GATED on targeted repairs/integration | Clean import and existing unfiltered `--mode all` matrix at original suite/long caps, no exclusions, including isolated graphics. Stop at complete result; failures become named child fixes. Do not rerun whole matrix for every small change. |
| FINAL-RECONCILE[one candidate] | GATED on required content, matrix and applicable platform/device/performance/audio/endurance/install/capture/signing results | Reconcile all original promises and exact candidate results with existing `release_candidate.py`, candidate record and `SHA256SUMS`. Zero open P0/P1, explicit reviewed P2/residual-risk dispositions including RENDER-001 where applicable. Changed source invalidates affected qualification; owner exclusions stay excluded. Stop at actual complete or named unmet gates, never a new evidence layer. |
| DISTRIBUTE[accepted candidate] | GATED on FINAL-RECONCILE and authorized destination/publication | Publish exact qualified artifacts/checksums and concise player-facing notes using existing release flow. Stop after byte identity and download checks. No Downloads copy or public publication implied by local checkpoints. |

### Rights families and missing documents — RIGHTS-DEFINE

Definition DONE on2026-10-20 from the current asset register, credits catalog,
README and actual checkpoint3d92b91 inventories. This finite routing map does not
certify every asset's rights, select a project licence, or close parent34. A
RIGHTS assignment selects one actual family/document gap; no per-file validator
or new provenance chain is needed.

| Current family | Existing source / player-facing notice | Remaining artifact or boundary |
| --- | --- | --- |
| Project code, gameplay definitions and standalone installer | README records project-original work and no project LICENSE; repository history identifies source. | Project release-terms text is absent. Engine MIT text does not select a licence for this project's own code. Record the owner's chosen terms before claiming this family cleared; no licence is inferred here. |
| Authored geometry, vector/procedural graphics and Blender sources | ASSETS.md and CreditsCatalog attribute project-original models, markings, materials and generators. Actual package includes the registered project-original Zenith blend. | Retain registered authorship and exact distributed inputs. Offline tool credits describe creation tools; they do not supply the missing project release terms. New external source material requires its own recorded disposition. |
| Procedurally synthesized sound and music | ASSETS.md, generator sources/manifests and in-game credits. Planetary air/cabin/water attribution now included on3d92b91; its three WAV and generator hashes match the existing manifest. | Authorship/attribution is recorded in the named scope. This does not establish listening, historical authenticity or all audio/runtime acceptance; project release terms remain separate. |
| Generated raster artwork and registered derivatives | ASSETS.md records image-generation source, dates/prompts/metadata and derived-map recipes; credits preserve that authorship. | Preserve the actual registered source/derivative relationship and chosen project distribution terms. Do not promote generated concepts into historical evidence or infer a blanket grant for unrelated imagery. |
| Godot engine, bundled components and default font | CreditsCatalog obtains Engine.get_license_text/get_copyright_info/get_license_info from the running binary; existing credits test checks the page and expanded notices. No additional project font is registered. | Keep those notices reachable on the final exact package. Existing source/package checks support their recorded candidate only; signatures, native execution and final release qualification retain separate gates. |
| Historical research media and original-game claims | Source ledger and ASSETS.md distinguish referenced B7 video/frame material from project-original runtime assets; original Roblox assets/scripts are not represented as bundled work. | Owner's creator-permission question remains settled as recorded in README; no repeated permission question or written grant is invented. Redistribution rights for the referenced B7 media itself are not recorded: keep that media unbundled unless its own disposition changes. Historical identity/evidence gates stay open. |

The [Godot licensing guide](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)
describes the existing engine-notice approach; project terms remain separate.

The creation tools named in CreditsCatalog (Blender, image generation, Python /
numpy / scipy) are not an extra shipped-runtime licence family merely because
they produced an asset. Actual checkpoint inventories exclude tools/ and tests/;
registered authored source and metadata still belong to their families above.
The existing credits UI already carries Godot notices, so no duplicate external
notice-packaging project is scheduled. Trusted signing and distribution remain
SIGN-FINAL/DISTRIBUTE, not substitutes for resolving these document gaps.

### Activity recovery — progress, player state and uncovered capabilities

RECOVERY-ACTIVITY-DEFINE is DONE as a source map on470aa24c4, not runtime or
final-source acceptance. Reuse the [twelve activity/write owners](#activity-write-boundary-roster--act-writes-define)
and their existing tests; do not create a second activity roster or a48-case
cross product. Original [active-activity recovery acceptance](history/ROADMAP_SCOPE_20261017.md)
still requires an explicit expected resume/safe-recovery state, durable progress,
usable controls and no duplicated reward or stranded craft/seat. Current behavior
alone does not settle an unresolved promise.

**Player continuation is independent of activity data.** GameFlow's
`_handle_hud_session_recovery_choice(normal_start)` acknowledges the current
fenced receipt and schedules existing solo recovery; normal `start_shift` also
chooses Resume if its notice remains open. `_apply_solo_safe_recovery` reacquires
the saved craft at its home berth: on-foot support, fresh pilot boarding, or awake
unseated cabin/rest/crew, according to the existing four-field preference. No
activity owner may invent a saved player pose, airborne ship position, former
seat/lease/crew authority or networking session. Aurora/Rime visits retain their
separate restoration owners. Unavailable contexts use normal supported station
start. Physical look/walk/interaction after recovery remains necessary; loading
JSON or acknowledging a crash notice alone does not prove it.

**Progress continuation uses the last accepted activity checkpoint.** Race,
Patrol, Jovian cargo and Convoy restore through their typed GameFlow persistence
owners. Convoy retains escort identity/progress/threat state but requires a fresh
current runtime rebind. Scan, Beacon, Mining and Asteroid Threading restore through
the actual streamed activity owner; their presence in the saved document does not
imply a loaded world or automatic location restoration. Mining retains extraction
capacity, not an invented credit/ore reward. Respect each owner's trust/validation,
generation, checkpoint interval, refused-write retry and payment fence. Reuse
`ACT-WRITE` for a selected uncovered write boundary and `RECOVERY-KILL` for an
exact installed/ordinary interruption; retain existing source/package passes and
parked failures instead of rerunning them under a new name.

Four owners cannot currently reconstruct an active cold run:

| Actual owner | What a cold load provides | Unfinished capability/policy |
| --- | --- | --- |
| [Cinder supply persistence](../scripts/persistence/cinder_cargo_delivery_persistence.gd) / [reward handoff](../scripts/cargo/cinder_cargo_reward_handoff.gd) | Strict v2 terminal transfer proof checkpoints before payment; atomic paid acknowledgement and cold current-owner settlement. Legacy v1 generation0 remains presentation-only; no manifests/handles restored. | **CINDER-SUPPLY-DEBT DONE** onf8b5f86: actual-file earned/refused→cold one-payment→paid no-replay, next generation, immutable proof and unrelated payload retained. Active manifest/inventory/deadline restoration separately needs an explicit resume-or-safe-home policy; Hauler stock choices remain untouched. |
| [StationDefenseActivityBoard](../scripts/activities/station_defense_activity_board.gd) | Durable terminal generation/history and genuine unpaid debt; fresh IDLE encounter, no saved enemies/health/leases. | Active wave/health continuation policy unresolved; terminal debt/reset/atomic paid acknowledgement already have owners, so do not invent a replacement. |
| [HeavyBreachActivityBoard](../scripts/activities/heavy_breach_activity_board.gd), Heavy Breach | Scenario/generation floor and earned unpaid/paid completion, no active combat/timer/actors. | Active encounter recovery policy unresolved. Earned terminal-debt real-file interruption is DONE c78e0ac; original 249.405s failures retained. Active encounter restoration remains unresolved. |
| Same board, Torpedo Run scenario | Separate reward/scenario terminal debt. Retained network suspension preserves live timer/distance; it is not a cold-process codec. | Cold active-run policy and distinct Torpedo terminal qualification remain open. Do not widen the retained-network promise into arbitrary disk pose restoration or count Breach as Torpedo acceptance. |

**Start Fresh must abandon active progress without discarding earnings.** The
existing `_decline_interrupted_planetary_visits` transaction retires Scan/Beacon/
Mining progress even before their world streams; `_start_fresh_after_interrupted_session`
synchronizes their live owners and resets the selected Race/Patrol/Jovian cargo/
Convoy through existing persistence. Completed debt/paid history stays authoritative;
refused publication must preserve the old save/live state and keep the choice
available. Unsupported/corrupt records are protected, never silently erased.

Two bounded runtime gaps were established by this map. ASTEROID-START-FRESH is
now delivered on59c55cb (full production179/253.847s, paired checkpoint);
CINDER-SUPPLY-DEBT is delivered onf8b5f86 (three-process roundtrip71.163s, reward62, paired checkpoint). The original acceptance contracts follow:

1. **ASTEROID-START-FRESH:** independent `cinder_asteroid_session` is absent from
   both the durable decline transaction and streamed live reset loop, while
   `_ensure_cinder_asteroid_session` reloads it on a later current binding.
   Extend those existing owners, using the strict asteroid codec and existing
   reset/publication rules. Finish: active real-file run→ordinary Start Fresh at
   title with the world absent→later stream/cold load has no old active run;
   also synchronize a present live owner. Prove failed publication retains save,
   live progress and choice, and unpaid/paid completions/unrelated payload survive.
   Estimate45–60min implementation plus focused checks/checkpoint; split before90.
   This capability is DONE on59c55cb in its recorded source scope; no OS-kill
   probe or parked recovery-suite replay was used.
2. **CINDER-SUPPLY-DEBT:** persist a genuine earned completion before reward
   callback; allow its current legitimate owner to settle exactly one payment
   after cold load, atomically acknowledging paid state through existing authority.
   Finish: actual-file earned/refused payment→cold reload→one payment→paid cold
   reload with no replay; preserve quantities, unrelated payload and reset refusal.
   The debt must prove the genuine completed transfer identity/item/quantity/
   generation; a summary or minted entitlement cannot substitute. The existing
   authority needs Cinder-specific debt validation/atomic acknowledgement; those
   checks are now implemented and accepted onf8b5f86. Existing reward62 and
   roundtrip17 pass; retained actual files prove unpaidgen2→paidgen3→unchanged
   paidgen3 and exactly one receipt. Current-owner callback acceptance, no inventory
   retry edits, next actual generation and refusal/provenance guards are covered.
   Active manifest reconstruction and Hauler stock policy remain separate.

Production seams: [GameFlow](../scripts/game/game_flow.gd) functions named above,
`_initialize_cinder_*_session_persistence`, `_ensure_cinder_{scan,beacon,asteroid}_session`,
`_reset_cinder_asteroid_session`; [streamed activity binding](../scripts/world/nearby_sector_activity_binding.gd)
`configure_cinder_mining_capacity_persistence`, scan/beacon/asteroid capture/restore;
[existing reward authority](../scripts/game/game_flow_reward_authority.gd).
No code/tests/engines/packages changed or ran for this definition. Four active
terminal-owner policies, installed/final candidate and ordinary-controls recovery
remain open. Native/device/human gates and all 36 parents/ten phase gates remain open.

### Settled exterior on-foot recovery contract

RECOVERY-ONFOOT-DEFINE is DONE. GameFlow _capture_solo_safe_recovery_context and
_persist_solo_safe_recovery_context persist exactly a four-field `solo_safe_recovery` home
preference: location=mudds_home_berth, mode=on_foot, craft_id, berth_id. Successful
expected-generation UserDataStore commit establishes authority; refused writes
retain the last preference and retry. Backup-derived authority is not overwritten.
No player coordinates, velocity, seat identity or flight pose are persisted here.

Eligible capture is settled exterior APPROACH_SHIP/COMPLETE with floor support,
no transition, live network session, planetary blocker, seat/sleep/piloting claim.
Jumps retain the last supported preference. Resume or Begin Shift accepting the
Resume offer resolves fresh registered craft/home berth and supported authored
exit, starts the fresh player awake/unseated/controls enabled, acquires no pilot/
crew/hatch claim and does not switch active_ship to the preferred craft. Unsupported
context falls back to ordinary shipyard start. PlayerController.settle_exit_onto_support
can return the original exit on unsuitable support, so acceptance must actually
check floor support and walking rather than infer it from a helper call.

The on-foot leg of session_recovery_resume_offer_test's cold solo recovery case
uses a fake filesystem/fresh Main and does not walk. Its real-file case covers
cabin/rest. safe_start_production_recovery_test and CrashRecoveryCoordinator
cover boot-marker/settings ordering, not on-foot pose/usable walking. Existing
startup_loader.in_world_probe_request, in_world_interruption_probe and
run_package_probes.sh originally admitted pilot/cabin/rest/crew/engineer; on_foot was unsupported at definition.

Delivered production capability is RECOVERY-ONFOOT-PROBE at f90547c37: extends the existing exported
release-driver path to a genuine settled on-foot commit/resume case, preserving
private headless/Dummy admission and existing contexts. The paired checkpoint and actual direct/archive-extracted ELF cut now pass.
RECOVERY-ONFOOT-CUT proves actual real-file commit for a named
nondefault craft, owned SIGKILL/reap and distinct same-profile Resume/Begin Shift,
supported outside-home recovery with no seat/hatch claim, ordinary walking then
real Interact boarding, and conserved existing activity/debt/reward boundary.
No arbitrary power-loss, other context, airborne-pose or native-device claim.

### Settled pilot recovery contract

RECOVERY-PILOT-DEFINE is DONE as a source definition on51cc486e6. It adds no
runtime feature or new qualification. GameFlow owns capture, disclosure, Resume/
Begin Shift and fresh boarding; UserDataStore owns atomic generation-checked
publication; activity owners retain progress/debt/payment authority.

- `_capture_solo_safe_recovery_context` requires settled actual pilot ownership
  on a registered, boardable, nondestroyed craft and actual Player pilot anchor,
  outside transition/network/planetary ownership. The durable preference has
  exactly `{location:mudds_home_berth, mode:pilot, craft_id, berth_id}`; it contains
  no transform, velocity, object identity or old seat/reservation token.
- `_persist_solo_safe_recovery_context` publishes only after accepted store
  commit; refused writes retain previous authority and bounded retry. Backup
  documents are not silently overwritten. Cold startup validates the four-field
  contract against fresh registered craft and its exact occupied/reserved home
  berth and available boarding area (`_solo_safe_recovery_craft`).
- The existing recovery notice explicitly says home-berth boarding, previous
  flight position not restored and saved activity progress kept. Stale Resume
  fences cannot board. Accepted Resume defers until Begin Shift; the normal
  Begin Shift choice can acknowledge the same notice. `_apply_solo_safe_recovery`
  settles at the authored supported exit then calls `_board_ship`, acquiring
  fresh real seat/hatch owners while preserving recovered activity.
- Unsupported/unknown/unavailable craft or conflicting network/planetary state
  cannot consume this pilot preference into a seat claim. Normal station start
  and independent activity/debt remain. Planetary restoration has its own owner.
  Retained Main reentry preserves live identities and is a different case from
  cold-process recovery. Airborne pose restoration is outside this contract.

Authoritative code: `scripts/game/game_flow.gd` functions above plus
`start_shift`, and `scripts/persistence/user_data_store.gd` commit.
Existing `tests/session_recovery_resume_offer_test.gd` pilot cases cover active
Convoy cold recovery, refused-write retry, stale/accepted Resume, deferred Begin
Shift, retained Main identity, terminal unpaid debt and unavailable-context
fallback. These are anchors, not a new suite PASS: its retained original300s
failure at Main17 after151 passes remains parked; Main18/19 were not entered.

The [ca0 archive check](LINUX_BUILD.md#earlier-local-checkpoint-ca0afc449--2026-10-17)
records an owned Bulwark pilot/active Convoy SIGKILL and distinct restart in57.291s:
exact durable boundary, receipts1→2 once and one crash event. Preserve this
accepted source/package case. Setup/boarding is scripted and completion uses
an escort-motion fixture, so it does not establish an ordinary-input journey.
The existing `scripts/diagnostics/in_world_interruption_probe.gd` and
`tools/release/run_package_probes.sh` already implement kill/reap, unchanged
killed document, distinct restart and terminal `IN_WORLD_RECOVERY_OK` checks.
For a separately selected Linux ELF qualification, existing selectors are
`PACKAGE_PATH=<absolute-qualified-ELF> PACKAGE_PROBE_RECOVERY_CONTEXT=pilot
PACKAGE_PROBE_AUDIO_DRIVER=Dummy tools/release/run_package_probes.sh
--in-world-interruption --native-export --activity=convoy`, with a private profile
and original stage caps. This definition runs no probe. The driver also has
beacon/mining/scan/hulk/stationdefense/ember pilot selectors; their mere presence
is not acceptance, and no new all-activity recovery implementation is inferred.

Finite remaining work: qualify this contract on the eventual exact installed/
archive Linux candidate; separately select a concrete full normal-controls
recovery route if required; resolve docking/planetary and other activity cases
under their existing definitions. Native execution/device/audio and owner-excluded
human gates retain factual status. No30–60min missing production capability was
established here; do not create one just to obtain another task.

### Settled cabin and ship-bunk recovery contract

RECOVERY-CABIN-DEFINE is DONE as a source definition on3598e1788; no engine,
new runtime feature, save format or fresh qualification. This covers **ship**
cabin/rest. Station Habitat rest is delivered separately in checkpoint221f523; a ShipBunk
fixture cannot accept that station interaction.

- GameFlow._capture_solo_safe_recovery_context accepts grounded, awake, unseated
  cabin walking only with actual registered frame occupancy, local bounds,
  boardable live craft and matching in-flight containment/owner when applicable.
  Sleeping capture requires the exact reserved ShipBunk/seat anchor and live
  craft from that bunk, rather than Main's possibly different active_ship.
  No transition/network/planetary owner may conflict. Jumps retain the prior
  settled preference; unsupported handoffs persist unavailable rather than a
  stale seat claim. Crew mode has its separate settled contract below.
- UserDataStore atomically commits exactly `{location:mudds_home_berth,
  mode:cabin|rest, craft_id, berth_id}` with expected generation. Refused writes
  retain last committed preference/retry; backup authority is not overwritten.
  This record contains no coordinates/velocity, moving frame identity, berth or
  bunk lease, sleep state or seat claim. Activity/reward/debt owners stay separate.
- Resume/Begin Shift uses fresh registered craft/home berth with actual occupant
  and reservation owner, available hatch, supported authored frame/stand bounds
  and real hull-floor ray. _apply_solo_safe_recovery reserves a fresh hatch,
  places the fresh awake/unseated Player at safe_stand_transform and binds actual
  containment. Failed registration rolls back pose/claim. Success sets cabin mode,
  controls enabled and the preferred active craft; it does not restore sleep,
  old pilot/crew seats or airborne pose. Unsupported context falls back to ordinary
  safe start; planetary restoration retains its independent owner.

Owners: scripts/game/game_flow.gd `_solo_safe_recovery_craft`,
`_solo_safe_recovery_cabin`, `_capture_solo_safe_recovery_context`,
`_persist_solo_safe_recovery_context`, `_apply_solo_safe_recovery` and Resume/
start_shift; scripts/persistence/user_data_store.gd generation-checked publication.
The existing UI explicitly discloses awake on-foot home-cabin return.

Existing tests/session_recovery_resume_offer_test.gd covers staged cold cabin/
rest, owner refusals and actual-file landed Halyard bunk identity/fresh-Main
restoration. Full original suite's retained Main17/300s failure stays PARKED;
source anchors do not become new passes here. Earlier ca0 archive owned
SIGKILL/restart cases pass cabin64.794s/rest65.343s with awake supported Halyard
recovery, receipts1→2 and one crash event, on their recorded package only.
See [Linux recovery scope/selectors](LINUX_BUILD.md#exported-game-interruption-check).

| Remaining named case /parents2,31 | Finite finish | Prerequisite / stopping point |
| --- | --- | --- |
| CABIN-RECOVERY-INSTALLED | Exact installed candidate, real frame-owned cabin commit, owned kill/reap, distinct Resume/Begin Shift yields awake supported cabin and usable ordinary walking/helm or exit without duplicated activity/reward | GATED final installed candidate and one frozen craft/route/cut at original caps. Earlier ca0 remains accepted; stop after this one context. |
| REST-RECOVERY-INSTALLED | Exact reserved ship bunk commits its own craft, owned kill/reap, distinct restart wakes onto fresh supported home cabin with no old bunk/seat claim and usable controls | GATED exact installed candidate/one frozen actual bunk and existing rest selector; stop after one context. No physical rest-pose resume entitlement inferred. |

The existing exported interruption driver already supports cabin/rest; no new
probe family is required. Separately freeze ordinary setup/continuation to close
any broader journey promise. Unavailable-frame/refused-write source coverage is
retained; only a concrete uncovered boundary justifies a new repair or case.
Native/device/full release gates stay open; this definition runs no probe and
selects no automatic successor.

### Settled seated-crew recovery contract

RECOVERY-CREW-DEFINE is DONE as a source definition on the Habitat-integrated
source (main1bdd0f717). No new feature, engine run or package qualification.

A settled supported solo crew seat saves a **home-cabin preference**. Explicit
Resume/Begin Shift returns the player awake and unseated inside that craft at its
home berth, with fresh cabin/hatch ownership and enabled controls. Saved activity
progress stays with its independent owner. Previous crew role, seat, lease,
flight pose and authority are not restored; the existing recovery offer says so.

- Capture uses the actual `_solo_crew_ship`, even when `active_ship` differs.
  `_solo_crew_claim_is_current` requires the live registered craft/chair, matching
  role contract, attached authority, exact peer/avatar/seat generation and seated
  frame occupant. Transition, network and planetary conflicts prevent capture;
  unsupported handoffs publish unavailable.
- Durable fields are exactly `{location:mudds_home_berth, mode:crew, craft_id,
  berth_id}`. Existing UserDataStore generation-checked publication protects
  backup authority and retains the last commit/retries refused writes.
- Fresh resolution supports Halyard, Bulwark, Jovian and Cinder Hauler. It requires
  registered boardable craft at its matching occupied/reserved home berth,
  available hatch, authored frame/bounds and real walkable hull-floor support.
  Apply reserves a fresh hatch and registers cabin containment; failed binding
  rolls back pose/ownership. Success enables cabin walking without crew/pilot
  claims. Unsupported recovery retains the ordinary safe-start fallback.

Source owners: [GameFlow](../scripts/game/game_flow.gd)
`_solo_crew_claim_is_current`, `_capture_solo_safe_recovery_context`,
`_persist_solo_safe_recovery_context`, `_solo_safe_recovery_craft`,
`_solo_safe_recovery_cabin`, `_apply_solo_safe_recovery` and recovery description;
[UserDataStore](../scripts/persistence/user_data_store.gd) `commit`.

Existing [resume fixture](../tests/session_recovery_resume_offer_test.gd) contains
real Halyard admission, stale/conflicting claims, network exclusion, real-file
crew capture, cold Resume and walking/helm/exit checks. These are coverage
anchors, not a new pass: its full suite remains FAILED/PARKED at Main17/300s
after151 passes, before the later crew recovery subsection completes.
The accepted [ca0 archive crew cut](LINUX_BUILD.md#earlier-local-checkpoint-ca0afc449--2026-10-17)
uses source `ca0afc449efc547de0d6049ac94ea2c876d14e2d`:64.872s, actual Halyard
passenger, owned SIGKILL−9, distinct restart0, same activity boundary,
receipts1→2 once/crash1, awake supported unseated cabin and clean markers.
Its scripted setup/escort continuation remains disclosed.

The two named remaining rows above separate final installed bytes from an
ordinary player journey. Freeze one craft/seat/cut before either execution;
other supported role/craft instances remain unscheduled selectors within the
original scope. Existing `PACKAGE_PROBE_RECOVERY_CONTEXT=crew` already serves the
installed cut: no new probe family or validator is required. No runtime defect
or missing owner decision was established. All original recovery promises,
parked failures and native/device/human/final-release gates remain open.
No automatic qualification or repair successor is selected.

### Settled docking recovery contract

RECOVERY-DOCK-DEFINE is DONE as a source definition on86d0e4593. No engine
execution, new gameplay defect or new docking acceptance is claimed.

| Actual boundary | Existing durable behavior |
| --- | --- |
| Accepted request/active landing assist, solo seated pilot | Landing sets `_landing_request_active`, not `_transition_busy`; actual pilot ownership remains eligible for the four-field home preference. |
| Physical landing completed, pilot still seated | Exact live lease becomes occupancy before completion; GameFlow accepts matching completion, secures occupancy/network handoff and enters SHUT_DOWN. Recovery preference remains pilot. |
| Unfinished boarding/exterior exit | `_transition_busy` triggers attempted `{mode:unavailable}` publication. Only an accepted store commit makes this durable; refused writes retain the prior preference/retry. |
| Completed supported exterior exit | Transition clears, controls return and capture follows actual grounded on-foot or registered cabin ownership. A jump retains the last settled preference. |

The settled record remains exactly `{location:mudds_home_berth, mode, craft_id,
berth_id}`; berth_id is the craft's **home**, not its selected landing target.
There is no serialized docking pose, approach phase or physical berth lease.
Network/planetary conflicts and unsupported ownership also attempt unavailable.
Expected-generation publication protects existing backup authority.

Explicit Resume stages recovery; Begin Shift resolves fresh registered boardable
craft, matching occupied/reserved home berth and available hatch. Pilot recovery
uses the authored supported exit and ordinary boarding for new seat/hatch owners;
invalid context falls back to ordinary safe station start. Activity/debt/reward
owners remain independent. Cabin support/rollback retains its existing contract.

Owners: [GameFlow](../scripts/game/game_flow.gd) `_try_request_landing`,
`_on_landing_completed`, `_disembark_ship_to_exterior`,
`_capture_solo_safe_recovery_context`, `_persist_solo_safe_recovery_context`,
`_solo_safe_recovery_craft`, `_apply_solo_safe_recovery`;
[HeroShip](../scripts/ships/hero_ship.gd) landing completion;
[UserDataStore](../scripts/persistence/user_data_store.gd) `commit`.
Existing [landing clearance](../tests/landing_clearance_test.gd) covers live
lease/occupancy ordering and invalidation; it is not cross-process recovery.
The [resume fixture](../tests/session_recovery_resume_offer_test.gd) contains
refused publication, fresh home ownership and fallback checks; its full
Main17/300s/151-pass failure remains PARKED. ca0 pilot/cabin/rest/crew archive
passes retain their exact sources and do not become docking acceptance.

The three named docking rows separate delivered executable driver support from
installed active-assist and busy-exit cuts. Existing startup loader,
[interruption probe](../scripts/diagnostics/in_world_interruption_probe.gd) and
[package runner](../tools/release/run_package_probes.sh) admit pilot/cabin/rest/
crew/engineer/on_foot, plus docking+Convoy in packaged311df73. The one actual assist cut is delivered;
busy-exit remains unsupported. Extend the existing path only for a separately
frozen cut; no new validator family. Ordinary-input setup/continuation
needs its own frozen complete journey and is not established by scripted setup.
Original docking/recovery promises and native/device/human gates remain open.

### Planetary recovery boundaries

RECOVERY-PLANET-DEFINE is DONE as a source map on86d0e4593. No engine run or
new world acceptance. The worlds do not share one recovery behavior.

**Aurora/Rime:** [PlanetarySurfaceVisitExpedition](../scripts/game/planetary_surface_visit_expedition.gd)
captures eligible active visits, excluding outbound/corridor/retiring/return;
restoring has its own re-exit preservation. Existing
[visit persistence](../scripts/persistence/planetary_surface_visit_persistence_binding.gd)
commits `{schema_version,payload_kind,slot_id,visit,receipt_sha256}` with expected
store generation. Visit fields are `visit_state,craft_home_berth_id,on_foot,survey`;
survey holds its schema/activity/state/generation/checkpoint/failure fields,
with Rime heat additionally retained. Rewards have their separate authority.
Shared capture additionally requires current server/journey/world/lease ownership.

Begin Shift/Resume reacquires the registered same craft by home berth, streaming
and a fresh landing/surface lease, then places the player awake/on foot beside
the ramp with controls. Saved pose, velocity, seats, lease and actor/network
grants are not reinstated. The exact receipt retires after admission, before
streaming completion; graceful quit during restoring recaptures it. Start Fresh
moves a valid receipt to the passive declined slot transactionally, without
location admission; earned debt survives later genuine arrival. Refused writes
retain the prior decision/data.

**Ember:** [survey persistence](../scripts/persistence/ember_relay_survey_persistence_binding.gd)
and [return adapter](../scripts/world/planetary_return_persistence_adapter.gd)
preserve detached coordinate-frame/route identity and optional original survey
progress. GameFlow passively adopts/reexpresses this during a fresh physical
surface admission. It does **not** implement cold planetary-location restoration.
The existing Ember package selector explicitly uses cold yard recovery, new real
boarding and disclosed orbital/corridor placements before original survey resume:
`canonical_outbound=NOT_RUN`, `standing_pose_restore=NOT_SUPPORTED`.
Historical acceptance retains that scope; it is not an owner-approved waiver of
broader original world-save/location requirements.

Existing Aurora/Rime visit-loop and quit-during-resume fixtures cover source
restoration and transaction boundaries; Ember active-journey fixtures cover its
passive application/retirement fences. These are coverage anchors, not new passes.
The [df86280 Rime checkpoint](LINUX_BUILD.md#earlier-gameplay-checkpoint-df86280b5--2026-10-17)
records78 staged/in-process real-ENet assertions/147.288s on exact source
`df86280b5b3985770be527af71c6c247f311aae7`, not canonical travel or OS interruption.

Reuse existing finite families rather than add a duplicate planetary queue:

| Existing family instance | Remaining bounded finish |
| --- | --- |
| WORLD-SAVE[Ember first relay/cold process] | Contract explicitly defined below as existing safe-yard/passive progress. Qualify one exact package/real-file kill/restart and once-only continuation; broader cold-location requirements, if separately promised, remain distinct. No extra owner approval gate is inferred. |
| WORLD-SAVE[Aurora or Rime/one disk boundary] | Freeze one eligible phase/craft/progress/payment boundary; real-file fresh-process recovery/reboard and once-only reward. |
| RECOVERY-KILL[planet/one installed package] | Own actual kill/reap and distinct restart for the frozen contract; use existing driver where supported or select one concrete missing executable capability. |

Quit/return/repeat remain WORLD-EDGE, canonical journeys WORLD-SOLO and shared
interruptions the existing SHARED-* rows. Aurora missing-original waits and Rime
parked arrival remain unchanged. All original promises/phase gates stay open;
no surface-location waiver, automatic probe or parked-route retry is selected.

### Ember first-relay cold recovery — bounded contract

WORLD-SAVE-EMBER-FIRST-RELAY / parents14,31, defined on2026-10-20.
The original recovery requirement says to name the expected **resume or safe-
recovery** state. For this specific cut, use the existing probe's safe-yard
contract. No instruction was found requiring an additional owner decision;
that would be an inferred approval gate. The retained whole-Main surface
remove/re-add promise uses the same actors/session, not a distinct cold process.
This definition does not waive any separately required cold surface case.

| Boundary | Required result |
| --- | --- |
| Initial state | The existing Ember selector's registered craft has genuinely landed at its caldera lease; same awake supported on-foot Player reaches first relay. Route next_checkpoint_index1/next_objective ember_return_beacon/incomplete, positive original activity generation, zero ember_beacon_data receipts. Preserve disclosed orbital_anchor_hold/initial_corridor_entry placements. |
| Durable cut | Successful save_interrupted_ember_journey publishes ember_relay_survey_active_journey in ember_relay_survey_completion, with detached frame/route and no movement/reward replay. Own the actual live OS process, SIGKILL/reap it; the committed document bytes remain exact. |
| Cold recovery | A distinct Boot process with the same private real files accepts the current Resume fence, returns on foot/control-enabled in the ordinary yard, leaves the exact Ember checkpoint passive and pays nothing. Old flight/standing pose, lease/seat and transient grant identities are not restored. |
| Continuation | Real fresh home boarding preserves the passive receipt. The existing disclosed flight setup then admits the original route/generation; actual final objective retires its receipt and pays one reward. Repeated reward retry/save cannot pay again; unrelated durable data is preserved. |
| Proof / scope | Reuse run_package_probes.sh --in-world-interruption --native-export --activity=ember with pilot context on one exact Linux archive ELF. This is the existing staged planetary interruption scenario, not ordinary menu/canonical flight, native GPU/input/audio or installed/final release acceptance. canonical_outbound=NOT_RUN and standing_pose_restore=NOT_SUPPORTED remain mandatory disclosures. |

Production owners are GameFlow.save_interrupted_ember_journey,
EmberRelaySurveyPersistenceBinding, UserDataStore and the later physical admission
through PlanetaryJourneyCoordinator; cold start restores Aurora/Rime visits only.
Existing in_world_interruption_probe.gd:2402 onward encodes this exact cut;
ember_active_journey_checkpoint_resume_test.gd supplies its focused MemoryFilesystem
progress/payment anchor, not real-file cold proof. Existing accepted sources keep
their recorded scopes; no runtime repair is inferred from naming this contract.

**Accepted exact-package cut — 2026-10-20:** after independently verifying the
original archive/ELF/external export-result.json, root stages the metadata beside
the resolved extracted executable. Integrated caller6112944d0 launches only after
root preparation PASS. Compiled source923d7b326, same byte-identical Ember probe logic.
Full original staged/headless/Dummy contract PASS: arm1941025 killed/reaped-9,
distinct Boot resume1941296 exits0, exact runtime boundary retained, cold safe
yard/fresh boarding, attachment generation1→2, original route completes, one
real ember_beacon_data receipt0→1; repeated reward retries/save remain once-only.
Paid document equals independently read exit document; unrelated settings/tutorial
data and clean crash/safe-start markers verified. No engine/script diagnostics;
source/cache manifests unchanged. Independent result review GO.
Original300s per process/660s outer caps unchanged. Command-record→terminal-status
wall interval308.992s (file timestamps, not a separately instrumented monotonic
timer), additive to retained failed317.447268s; approximately626.440s combined.
Owned staging/private tmp removed at17:42:43,7.72min into15min selection; five
observed identities absent. New raw records only under existing
`/srv/mudds-work/ember-first-relay-20261020/results/package-handoff/`.
No branch/worktree/new export/checkpoint. Canonical outbound/normal controls/native
GPU NOT_RUN, standing-pose restore NOT_SUPPORTED. This is the named old-package
safe-recovery cut, not current/final-source, ordinary/canonical/installed or full
world acceptance. Original failed attempts below remain failures.
[Delivery](history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-recovery--exact-package-accepted--2026-10-20).

**Original exact-package attempt — FAIL/STOPPED (retained):** driver28f7c2a27 used actual
archive-extracted Linux source923d7b326 (game/driver code unchanged between those
commits), native-export/headless/Dummy,300s each process/660s outer/20min whole.
Existing default selector chooses Bulwark; genuine first relay is unpaid and
supported on foot. Owned arm1713707 is reaped-9, distinct resume1713976 exits0;
zero engine diagnostics. Runtime cold yard/controls/new boarding/original route
adoption/payment and late paid-terminal checks pass. Parent comparison fails:
orbital_coordinate.offset_meters[0] and surface_tangent_meters[0] change
180.34764099121094→180.34764099121097, each one binary64 ULP2.842e-14m. No other
compared Ember-boundary field differs. Do not infer corruption or call the whole
cut accepted; original exact criterion was not changed. Overall312.812s, no retry,
repair/cap increase or new build. All9 observed processes absent, five package
inputs hash-verified and owned scratch removed9.50min within20min. Exact package,
source/cache identities stable. [Raw scope/result](history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-cut--runtime-completes-parent-comparison-fails).
**Contract review and caller correction:** the arm's emitted runtime boundary
already has180.34764099121097, exactly equal to the recovered runtime boundary;
only the first raw wire text has180.34764099121094. UserDataStore's documented
JSON-number semantics and the probe's runtime/document binding explain the
parse/re-encode boundary. The release caller now compares both emitted runtime
boundaries exactly, still parsing the recovered document and preserving all
independent-file, kill/byte, route/generation and reward guards. Retained-data
replay accepts the actual exact pair and rejects74 independently changed scalar
values (each float by one ULP); bash syntax passes, independent review GO.
No tolerance or datastore behavior change. Original312.812s FAIL remains;
corrected full package run was NOT_RUN at that selection. Review/correction fit
the original20min boundary, but another312s run does not fit before06:25UTC. A new explicitly
frozen attempt must retain cumulative costs and original route/caps, rather than
silently extend/reset the old budget. No automatic successor selected.
[Correction scope](history/ROADMAP_DELIVERIES.md#ember-coordinate-contract--package-caller-corrected).

**Earlier corrective selection — FAIL/PARKED (retained):** clean drivercc2b44ffd, same archive,
06:22–06:37UTC/15min. Preparation mistakenly expected export metadata inside
the archive, asserted, and the unconditional next shell command launched the
checker anyway. Preflight exits1/4.636s on missing adjacent export-result.json;
no game process starts, zero diagnostics. Corrected full cut NOT_RUN. No repair
or retry. Independent cumulative review parks chain; measured attempts317.447s
including original312.812s. All6 observed identities absent/owner terminal,
four actual inputs hash-verified; archived/verified unique profile/helpers,
removed owned scratch at1.77min. Original and corrective budgets retained.
[Corrective closure](history/ROADMAP_DELIVERIES.md#ember-corrective-package-attempt--preparation-failure).

### Hauler supply integration boundaries

Source530ccda6b: one high-effort manifest/persistence reader plus root physical
mapping. No engine/test ran. Preserve existing `cinder_platform_supply_run`,
`cinder_supply_crates`, one-crate transfer, load_crate/clear_gate/dock_platform,
120s caller time and destination station_cargo_destination_terminal/manifest
(capacity8). Jovian entity/manifest IDs and existing two-crate/capacity8 contract
stay unchanged. CargoTransferAuthority alone owns quantities/atomic receipts.

| Ordered child | Production boundary and proof | State / stopping condition |
| --- | --- | --- |
| HAULER-SUPPLY-ACCESS | Actual Hauler reservation/contact/landing/disembarked current pilot walks supported to existing terminal; preserve exact lease/actor/attachment and old Jovian route | DONE; paired checkpointa43ae4b. Full access76/berth83/switching35 checks and three strict startups pass. Actual collider contact root4.25; Hauler-only leased staging above deck. No inventory/reward grant. Initial placement staged; full Main journey remains open. |
| HAULER-CARGO-STOCK | Conserved shared existing Jovian/Hauler two-crate mission stock | DONE6bcbea302/checkpoint6bcbea3: same authority manifest seeded once, shared by exact Jovian/Hauler custody without duplicated/recreated stock or custody receipts. Session-local; full ordinary delivery/cold inventory remain open. |
| HAULER-CARGO-MANIFEST | Admit actual Hauler with distinct exact source handle/manifest and conserved chosen stock; source replacement keeps a monotonic activity generation and existing reward/transfer replay fences | DONE6bcbea302/checkpoint6bcbea3. Atomic same-manifest authority reassignment; exact Jovian→Hauler→Jovian identities, two transfers/rewards and exhausted reacquisitions; active/unpaid owner protected. Authority101/binding72/access77/bridge8/reward13/debt27 checks and paired exports/strict startup/audit PASS. [Actual scope and failures](history/ROADMAP_DELIVERIES.md#hauler-shared-cinder-cargo-custody-completed--2026-10-21). |
| HAULER-CARGO-DELIVERY | Current pilot loads through real terminal, physically departs/clears gate, lands/exits/walks back and commits exactly one source→destination transfer/reward; repeat preserves quantities/receipts | Access/manifest DONE; full ordinary delivery remains OPEN/unselected. Use actual ship/actor/lease/terminal generations and shared custody; preserve old Jovian route. Define exact unchanged route/caps before running. Bridge/role proposals are not delivery proof. |

Pre-implementation source definition on668b5b6dc (superseded by completed
6bcbea302 custody above): the smallest manifest seam was
NearbySectorActivityBinding source admission and conserved stock custody.
CargoDeliveryActivity.adopt_terminal_generation_floor and the binding's
_apply_cargo_generation_floor already exist; prove their integration rather than
adding a duplicate API. Estimate after the stock decision:60–90min for manifest
implementation/focused checks, plus checkpoint export/startup; split before90min
if the chosen custody requires a separate independently useful capability. Keep
CargoManifest/transfer authority/reward handoff/persistence formats unchanged
unless a concrete consumer requires a change. Terminal-summary-only Cinder cargo
persistence description above is historical: current strict v2 earned debt and
cold payment are delivered by CINDER-SUPPLY-DEBT onf8b5f86. That acceptance does
not reconstruct active inventory/manifests or settle stock custody.
Existing tests are anchors, not new passes:
access suite declares1200s; authority/contract/handoff/summary/bridge suites retain
their original default300s. No schema/validator growth or unchanged parked retry.
Full ordinary packaged outbound/home, craft/art/crew/recovery gates remain open.

### Bomber crew/navigation interpretation

BOMBER-ROLES-DEFINE is DONE as a static comparison. The Bomber definition and
scripts/ships/cinder_long_range_bomber.gd implement one physical pilot, Dock05
access, pilot-fired finite travelling payloads, and shared landing/reuse owners.
GameFlow fires as player_pilot. Injected test identifiers bomber_gunner/new_gunner
are API actors, not authored chairs or registered crew gameplay. No MovingInteriorFrame,
walkable in-flight cabin, extra crew role/seat or Bomber navigator is registered;
HeroShip reports no_walkable_cabin. Cargo Hauler navigator dispatch and the physical
role allowlist do not cover Bomber. Existing tests are implementation/coverage
anchors, not newly executed whole-craft acceptance.

COMPLETION_SCOPE retains additional Bomber crew/navigation open, but Phase5's
conditional crew instruction gives no Bomber role count, concrete navigator action
or physical access layout. BOMBER-ROLE-DECISION therefore needs those exact choices
before a production station is assigned; no pilot-only scope reduction or invented
role is approved. Once defined, one station's physical enter/action/stand/reseat
and authority integration is a bounded production child with a fresh checkpoint.
Spent-payload recovery remains separate. CRAFT-GAPS-CINDER-BOMBER now maps the
actual source path: GameFlow `_disembark_ship_to_exterior` clears/detaches the
session, and next `_ensure_bomber_payload_session` starts a newer generation;
BomberPayloadAuthority `_start_generation` restores four rounds. This source
inference is not an executed ordinary reboard result or a defect finding.
Owner resolved BOMBER-REARM-POLICY2026-10-21: refill when the pilot retakes
the seat. Preserve that entitlement in correction/qualification; do not introduce
an explicit-service-only rule. Existing explicit fresh-generation unit behavior remains
accepted; it does not settle ordinary player entitlement.

CAPTURE instances (13 required sets, **143 PNGs** total):

| Registry ID | Expected images |
| --- | ---: |
| `caption-presenter-forward-render` | 1 |
| `caption-production-forward-render` | 1 |
| `cinder-streaming-transition-render` | 24 |
| `capture-berth-feedback` | 18 |
| `capture-combat-visuals` | 7 |
| `capture-hero-cell` | 18 |
| `capture-jovian-freight-berth` | 2 |
| `capture-jovian-freighter` | 4 |
| `capture-player-motion` | 9 |
| `capture-scenes` | 27 |
| `capture-station-operations` | 7 |
| `capture-varied-encounters` | 18 |
| `capture-zenith-visuals` | 7 |

Registry/commands: [graphical harness inventory](../docs/GRAPHICAL_HARNESS_INVENTORY.md) and `tools/release/graphical_harness_registry.json`. Earlier 3/13 source/image declarations are source-specific, not a current-candidate pass. **Caption production and station operations are blocked on this software-Vulkan environment:** original-cap cold compilation stalls in Godot's built-in Forward+ clustered COLOR_PASS ubershader. Bounded native stack/SPIR-V diagnosis is complete; material owner remains unknown. No custom-shader rewrite, quality/deadline reduction, unchanged cold rerun or registry promotion is justified. A concrete changed environment or supported mitigation is needed before another probe. Preserve RENDER-001 and original failures.

## Retained source-specific context

The following earlier source results and priority decisions are retained for
provenance and failure boundaries. Chronological next-action statements here
are historical; only ROADMAP.md selects current work.

These are unscheduled parent requirements, named child outcomes and task-family contracts.
The [concrete breakdown](#concrete-child-outcomes) names selectable outcomes and explicit unknowns.
They preserve scope; they are not an executable queue or a remaining-job count.
Select a named instance in the [working roadmap](../ROADMAP.md) before starting.
Pilot and passenger craft-label repairs are delivered in checkpoint b6196a1.
The original ordinary two-client boarding qualification is DONE on fff5f7221:
127.937s, both normal approaches and actual seats, current identities/authority/
consumed HUD, final host confirmation and all three actual peer exits0. It adds
only the accepted caller/harness; playable checkpoint b6196a1 contains its exact
game runtime. Earlier boarding and initial export failures remain retained in
history. Ordinary shared departure/braking is now DONE on96c96312f after its one
caller-field correction:132.562s, host5.004m departure/berth release/zero-speed
stop, both clients retained and converged, all actual exits0. Game runtime is
unchanged from checkpointb6196a1; this is source-route qualification. Immediate-command reproduction/repair and checkpoint2c73494 are now DONE: the
old runtime fails only the new edge-delivery assertion; repaired source passes
consumer40/ship_command79, and both packages pass strict startup/artifact checks.
The original shared return is now accepted on4c9c764e9 after one bounded caller
ownership-reader correction:138.915s, strict actual dock/lease/commit, both clients
consume original pilot/ownership and matching landed arrival, all three peers exit0.
The failed331a9628b arrival check and earlier failed attempts remain retained.
GameFlow's synthetic action seam samples/drains landing before physics, while
remote forwarding only reads the physics snapshot. Source mapping is intact;
the prior run did not capture pulse-time command publication. Require focused
old-runtime reproduction, accepted fix/checkpoint, then one unchanged return
qualification. Earlier failed task/repair remain cumulative; no extra probe.
Ordinary retained-seat home return is accepted in that source scope. Dedicated
server, disembark/reuse, canonical worlds and endurance remain unqualified. Broader
flight/endurance remain unqualified. Both lifecycle qualifications retain
their accepted source scopes.
These are not project-wide remaining counts; no phase completion is implied.
The original specifications remain binding in
[the preserved scope](history/ROADMAP_SCOPE_20261017.md).

Status key: ELIGIBLE = potentially selectable template, not scheduled work; DEFINE = missing contract;
GATED = named prerequisite; WAITING = external input; IN PROGRESS = assigned;
DONE = accepted on its recorded source/scenario. A template must be instantiated in ROADMAP.md with exact owner, scenario, source,
acceptance, budget and next action before it can be marked READY. Parent/template
counts do not answer how many executable jobs remain.

**Parked repair — Q4-FIX / PERF-FIX[station startup construction].** The measured
guard-order candidate was withheld because whole startup did not improve. No
supported replacement is identified; do not spend this batch repeating its
profile. Reopen only with a concrete different avoidable-construction change in
`shipyard_world.gd::_run_build_stages` or its measured constructor. Acceptance
remains comparable whole-startup improvement, preserved geometry/material/
collision/interaction/startup behavior, fresh clean Windows checkpoint and one
unchanged original 300 s full Patrol result, retaining all 30 Main lifetimes. Local
query-count reduction or equivalent snapshots alone are insufficient.

### External dependencies outside the ready queue

| Task | Waiting for | Completion of this dependency |
| --- | --- | --- |
| SCOPE-LIMIT[final release target] | Owner choice; question already asked | Explicit remote-guest count and playing-host participation recorded. Default settings/physical seats do not establish accepted support. |
| SETTINGS-INPUT[original artifacts] | Exact original runner/profile/logs | Originals identified and recovered, or precise missing-artifact handoff. A substitute cannot inherit Gate C. |
| WORLD-SHARED[Aurora original arrival reproduction] | Original `47ffce740` run bundle | Exact runner/arguments, source/build/profile/participant initial state and raw orchestrator/peer stage receipts. Historical receipt `71ef2ee4929822e8182cbf66bdbeeb14d9238d2b` records45 checks/five failures under120s landing; narrative alone cannot reconstruct invocation. |

The original server/two-client baseline remains authorized independently of the
final capacity choice. D3/D4 deliver its menu-admission slice; they do not qualify
its full gameplay/flight/endurance requirements. Remaining family tables preserve
unscheduled scope. The previous batch closed with Ember ABANDON source DONE,
HULK revisit FAILED and its checkpoint GATED. RIME-BENCH-ROUTE and its development checkpoint are DONE on a8f563e39: one
new executable source benchmark capability and paired builds, no native
performance or new gameplay claim. ROADMAP-SLICE defined four Rime independent-two-client baseline children.
Arrival candidate6f29e4f15 failed parsing; its one-line repair68cc7d989 passes
parsing and reaches Rime approach (970 rebases, zero staging), then fails the
original120s physical landing gate. Both remain withheld, owned checkout removed,
raw/source retained under `archive/withheld/rime-crew-arrival-typing-20261018`;
working refs deleted. Survey/home/package children remain unqualified
and parked with that parent. Recorded priority review selected the independent
Linux uninstall-interruption/retry/ship batch, now DONE on505d419. The next
working queue delivered BROWSER-CANCEL and paired checkpointa39e93a, closed
RACE-PAGE-RESET static diagnosis without a repair. FIRE-RESTART and its one
viewport fixture repair both fail before capture; candidates withheld, raw and
source retained under `archive/withheld/fire-restart-viewport-20261018`,
working refs deleted and clean checkout removed. Required priority review selected
PLAN-VISIBLE-DELIVERIES, now DONE: browser per-session generation handling and
defense briefing corrections are DONE on9be5c833a, with paired checkpoint9be5c83.
Native packaged Ember driver preflight FAILED at disabled `--path` overrides.
Static consumer definition is DONE: disabled overrides also discard external
script, so removing --path is not a repair. Native Ember observer source capability ships in4270d71 with privacy232/runtime20
and strict package startup/artifact passes. Its normal-window-close smoke FAILED
and further native-window work is parked after the recorded priority review.
Next selected independent work is ordinary VIP-route definition/walking. The
original9be5c83 unchanged-driver journey is UNSUPPORTED and remains unperformed;
a subsequent full OS-input route needs its own explicit card. Source proof is not transferred
to packages automatically.
A third station implementation has no evidenced finding and remains DEFINE/
GATED; no speculative fix is scheduled. FIRE-RESTART above is now accepted on3a45c4d79 after actual engine-buffer dispatch; broad Settings/device gates remain and no additional probe is selected. See
ROADMAP.md for exact contracts. No further Rime
probe, repair or unchanged run is selected.
One failed task plus its attempted repair requires a recorded priority review
before further repair; a new task name does not reset that boundary.

## Working constraints

Follow [AGENTS.md](../AGENTS.md). Every automated Godot invocation uses `--audio-driver Dummy`; use headless or isolated displays, explicit `--display-driver x11` under Xvfb and an independent abort/cleanup path. Do not use the owner's desktop or audible output without explicit authorization. Keep scratch, helpers and worktrees under `/srv/mudds-work/`; remove completed temporary worktrees after verifying integration and preserve unique uncommitted work/raw failures. Never enable/dispatch hosted CI. Do not use native Windows/Wine under the execution hold. Checkpoint artifacts belong in repository `builds/`, not Downloads.


### Explicit incremental Windows finish selection — original failure retained

2026-10-20, same RPC-CACHE-TEMPLATES outcome. Independent priority review found
2,105 nonempty cached objects and valid SCons signatures after the cold compile
timeout, immutable source/patch/wheel and idempotent builder reuse. One separately
frozen finish may reuse that completed work: exact original Windows command/pin70af,
jobs2/flags/cache unchanged, only `--timeout 480`; guarded command540s/owner600s.
Dependent collection60s/owner120s. Launch must leave130s reserved beyond finish
owner before absolute1792462171 /02:09:31UTC /04:09:31Paris, original70af+90min.
No later freeze resets that deadline. Guard retains STOP and requires exact prior
STOP SHA plus named finish/collection authorization/deadline; original3600s failure
is not removed or promoted. No further repair/retry/cap increase after this one
incremental selection. Root restored only clean70af worktree/helpers for this
bounded attempt; cache remains unchanged. No game export/runtime route selected.
Exact frozen commands/hashes: template results/incremental-frozen.json.


Incremental result: STOP at the selected480s compiler limit; stage exit1 after
492.110911s, no diagnostics, unfinished Variant compilation and no accepted PE.
No further retry/collection/export/runtime route. Original failed3600s attempt
and this single finish are both retained; no source/compiler defect established.
All15,090 observed identities across three owners/children absent; no live cwd
under owned template root. Re-removed clean70af duplicate worktree and disposable
helpers/profiles after copying/hash-checking only changed helper files into
results/incremental-helpers (unchanged files reference prior archived originals).
Cache and raw results retained. Closure5187.663s/86.5min from original70af freeze,
before its5400s deadline. Candidatee5b9dd25f and package drafts remain pushed/
archived, unmerged/unqualified; no acceptance requirement narrowed or closed.
Further Windows compilation is parked; no third attempt selected. Next selection
must review an independent eligible runtime outcome rather than extend this card.


### Selected SAVE-UNSUPPORTED real-file case

2026-10-20: exact future outer-envelope primary/tmp/bak fixture and limits are
frozen in ROADMAP.md#selected-independent-save-protection-check. Existing canonical
future-envelope tests use FakeFilesystem; real crash-point history cases run in
one process. This selection verifies actual disk refusal across two fresh engine
processes without duplicating existing validators. Only the existing crash-point
test file is implementation-owned; no production behavior gap is asserted in
advance. HUD-PATROL source review found no discrepancy and made no edits/runs.
Broad SAVE-UNSUPPORTED stays open outside this exact named source/filesystem case.

SAVE-UNSUPPORTED initialbcc699839 check: guarded import20.822787s PASS; suite
2.544507s FAIL in the child ownership caller before fresh save operations,
ERROR/ECHILD from is_process_running(invoker), child2 not launched. Eight observed
identities absent; raw failure preserved. Pinned engine source845–878 and881+
uses waitpid for liveness and popen/pclose for captured synchronous execution.
Independent review GO for exactly two invalid query removals/accurate identity
wording; one60s rerun selected on unchanged accepted import cache, not a save
implementation repair. No data assertions/caps/diagnostic handling weakened;
original failure and total task budget retained. No further automatic repair.

SAVE-UNSUPPORTED accepted source/Linux case4b66b354883eedac9b309177dbae143b2dd39c0e:
corrected suitePASS3.506682s/118 parent assertions,23 per actual fresh child;
PID1639834 invokes1639855/1639878. All15 observed owner/descendant identities
absent. Actual retained loaded commits, fresh load/read-only/commit/recover/
restore/discard refusals leave three future canonical fixtures and unrelated
sentinels unchanged, including file/directory modes. No diagnostics or synthetic
private marker leak in corrected run. Original import20.822787s PASS and failed
caller2.544507s retained; cumulative26.873975s, no failure/budget reset. Integrate
only exact tested file, no production save edits/checkpoint. Other unsupported
formats/package/native/recovery gates open; all36parents/10phase gates still open.

Integrated/pushed e67e06bfb; owned worktree/cache removed after source/PID checks.
Only save-unsupported-files-20261020/results/ remains, with hash-verified helpers
and profiles.tar.gz retaining85 files/3 symlinks with original bytes/modes/targets.
Freeze→cleanup12.9min including failed caller and one correction; budget retained.


### Docked-pilot closeout — later doorway boundary, still withheld

Separately selected 15:35–16:20UTC/45min on 2026-10-20 after raw/source review
identified the original cabin-stand-to-hatch diagonal crossing the solid pilot
chair. Existing branch bf7fb636e merges current main and adds one ordinary
ship-local clearance point `(-1.10, 0.52, -6.70)`; production dock hold and focused
regression remain unchanged from 0d225bee8. No state/collision staging or criteria
change. All original route points, host15s, walk15s, suite300s/outer360s remain.

Import20.710s, pose42.684s/322 and compile16.752s PASS. Full original three-peer
route FAIL147.311s: return/stand/cabin stand/new detour/original route[0] pass;
route[1] fails before route[2]/hatch Interact/exterior release/ground walk.
Host supported standing body at ship-local(-1.282619,0.481719,-8.546745), current
intent and exact dock remain. Caller walks route[0..2] before hatch Interact;
canopy/hinge/blocker/contacted-collider state is absent, so actual doorway
causation remains unproved. No retry, second repair or adjacent probe selected.

New227.457s plus prior392.470s gives619.927s current stages; original parser
failures remain separate. Candidate pushed/unmerged/withheld. Exports/startups/
audit NOT_RUN; public c78e0ac unchanged. Independent failure review STOP.
All25 observed identities absent;188 profile entries archived/verified, owned
worktree/profile/helpers removed6.01min within45min. Raw and helper sources:
`/srv/mudds-work/docked-pilot-closeout-20261020/results/`.
Full exit/reuse and all original parent gates remain open.


### Physical Jovian passenger exit — focused path passes, ordinary interaction unresolved

Selected15:47–16:32UTC/45min on2026-10-20, existing docked-pilot branch only.
Source found two separate mismatches: caller walks post-confirmation exterior
animation points before E; confirmed nonpilot production presentation teleports
to generic yard spawn. Jovian has no independent ShipCabinHatch toggle. Generic
cabin Interact outside2.2m pilot-swap radius requests passenger DISEMBARK.

Candidate de57a6e15 adds a confirmed landed/offline Jovian physical exit selected
from accepted host operation facts, using an explicit supported live ON_FOOT
transition. It retains the other pilot's state/camera/authority and skips pilot
cargo/tutorial effects; existing pilot/Halyard paths retain their behavior.
Caller walks to supported inboard(-1.75,.52,-6.30), then ordinary Interact; the
exit observer requires the aft chair clearance plus all six original exterior
poses, motion, and every original ground/retirement/current-pilot/actual-exit
condition. No fake seat, test body placement or weakened endpoint.

Two separately retained compiler failures preceded runtime:87b313468 importPASS
then GameFlow type inference FAIL38.440s total;1502fb9c8 importPASS/observer compile
FAIL37.184s total. Exact corrections only declare Transform3D/bool/current:bool;
all operands, original caps and original15:47 window remain. Their roots contain
only preserved results; six observed identities absent and39 profile entries
verified for each. No journey or export ran in those failures.

Final attempt import20.677s/compile16.943s/pose42.615s322/focused exit31.779s11 PASS.
Original full journey FAIL143.680s after real return/stand/supported inboard walk
and host confirmation:8s ordinary boarding/no-competing-station predicate fails
before E. Requests1/confirmations1 still name initial boarding; passenger berth
claim remains. No actual boarding/station candidate path, range or area gate was
recorded, so cause is unproved. New production departure was not exercised by
this journey; focused Player pass is not full exit acceptance.

Latest255.694s+prior695.551s=951.245s current stages; original8054/e147 parser
failures stay separate. No further fix/retry selected. All28 observed identities
absent,211 profile entries archived/verified; owned scratch removed19.06min
inside original45min. Exports/startups/audit NOT_RUN; c78e0ac unchanged. Candidate
pushed/unmerged/withheld; all exit/reuse and original parent gates remain open.
Raw: `/srv/mudds-work/jovian-passenger-physical-exit-caller-20261020/results/`;
earlier compiler roots `jovian-passenger-physical-exit-20261020/results/` and
`jovian-passenger-physical-exit-typed-20261020/results/` under `/srv/mudds-work/`.


### Jovian exit interaction conflict — original diagnostic closed

Existing branch tip2055f1f52 adds only receipt observations. The original full
journey still fails before E: boarding candidate is the correct available Jovian,
within6.639m/7m reach, with this player's reservation; competing engineer chair
passenger_port_01 is selected at1.800m and facing dot0.348. Availability/range
are not the failing conjunct. Runtime exit/claim retirement/ground walk remain
unaccepted. Import20.669s/compile16.986s pass; full142.894s fails. Combined current
stages1131.794s, original parser failures separate. No unchanged retry/export.
Next bounded repair must resolve ordinary exit aim competing with peripheral
engineer-seat discovery without removing deliberate engineer interaction or
weakening the original full journey. Same branch; no new task branch.
