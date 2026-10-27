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
| Unresolved multiplicities and estimates | [Unknown scope and counting](#scope-counts-and-scheduling) |
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

Each final cell below names the complete required outcomes and their proof, not
an arbitrary next test. The child inventory carries each instance/dependency and
Done means. Definitions settle inputs; they do not deliver gameplay.
Parents 3/27 share the same 21 world cells; parents 6/35 share MATRIX-FINAL;
parents 11/21 share damage ownership. Do not count these twice.


| Parent | Original parent outcome | Active task families | Required completion and shared proof |
| --- | --- | --- | --- |
| 1 | Finish final integrated-source and packaged physical abandonment acceptance | WORLD-ABANDON, WORLD-SOLO, PACKAGE-WIN, PACKAGE-LINUX | EMBER-PACKAGE-ABANDON plus applicable WORLD-ABANDON/SAVE/EDGE outcomes: complete physical outward/abandon/reboard/ascent/home/exit/reuse with real-file integrity; [world proof](#proof-world). Source-only abandonment is retained, not packaged acceptance. |
| 2 | Complete matching installed interruption/recovery on the accepted integrated build | RECOVERY-CONTRACT, RECOVERY-KILL, INSTALL-LINUX, FINAL-RECONCILE | Named installed on-foot/pilot/cabin/rest/crew/docking/activity/world interruption cuts: actual kill/reap/distinct restart, settled supported recovery and preserved once-only progress/debt; [recovery proof](#proof-recovery). |
| 3 | Complete canonical-distance outbound and return with ordinary remote crews for Ember, Aurora and Rime, including activities/rewards/save, late join, disconnect, pilot loss, cancellation, interruptions and repeat visits | WORLD-SHARED (each world/case), NET-CREW, RECOVERY-KILL | All21 existing SHARED-EMBER/AURORA/RIME × BASELINE/LATE-JOIN/RECONNECT/PILOT-LOSS/CANCEL/INTERRUPT/REVISIT goals; [exact case outcomes](#proof-world). SAME work as27, no duplicated jobs. |
| 4 | Record the final shipped roster and supported limits | SCOPE-DECISION, NET-CAPACITY, ORIGINAL-SPEC | SCOPE-ROSTER accepted; SCOPE-LIMIT and SCOPE-DESKTOP recorded with concrete guest/host/craft-role and platform values; eight SPEC and Bomber role decisions remain explicit. [Decision register](#blocking-decisions-and-resources). |
| 5 | Assign owners, dependencies and estimates to the remaining deliverables | PLAN-ASSIGN and the per-session task card | Every named goal has observable Done means/dependency/owner class; each selected assignment fixes files/action/proof/estimate/cap/stop/cleanup before execution. No unestimated family assignment; [execution contract](#acceptance-contracts-for-every-named-goal). |
| 6 | Qualify and package current source | BASE-DIAG/FIX, MATRIX, PACKAGE-WIN/LINUX | PACKAGE-FINAL and the SAME MATRIX-FINAL/FINAL-RECONCILE as35 on one frozen candidate, unfiltered local checks/original limits and exact installable bytes; [release proof](#proof-release). |
| 7 | Complete the normal-controls core playthrough and fix observed blockers | GUIDED, SANDBOX, SETTINGS-INPUT/RUN, LIFECYCLE, STATION-ROUTE, CRAFT-ACCEPT | GUIDED-FINAL3/3; original SANDBOX-RECOVERY all-nine/54-waypoint1/1; SETTINGS-RETURN original1/1; named station/craft/lifecycle journeys with actual ordinary controls and usable return; [core proof](#proof-core). |
| 8 | Complete control and tutorial tuning | CONTROL-FIX, INPUT-DEVICE, INPUT-REMAP | Existing control/tutorial defects resolved, actual KBM/controller routes and specified remap/apply/reset/conflict/restart/context-return behaviors; [quality proof](#proof-quality). Completed options not implemented again. |
| 9 | Finish station layout and final presentation | HIST-CLAIM, STATION-MODULE/ROUTE/ART/LIFE | Exactly nine station branches physically connected/usable, four delivered service behaviors retained, actual named visual/topology findings resolved with collision/berth/flight agreement; [station proof](#proof-core). |
| 10 | Finish fleet art, character animation and role acceptance | CRAFT-ART, CRAFT-ROLE, CRAFT-ACCEPT | All17 CRAFT-ACCEPT journeys, actual supported role actions and required source-art/animation/material/clearance; eight absent craft must pass SPEC→build capabilities→complete journey. [Craft proof](#proof-craft). |
| 11 | Complete the combat-and-recovery slice across supported craft | COMBAT-SLICE, CRAFT-ACCEPT, NET-DAMAGE | Six actual encounter owners, eleven current firing-role bindings and five component IDs: real effects/repair/destruction/recovery/usable home; share damage owner with21 and Breach/Torpedo PLAY journeys. [Combat proof](#proof-combat). |
| 12 | Complete the whole-game art-direction pass | ART-FINDING, STATION-ART, CRAFT-ART, CAPTURE | Finite required station/fleet/world/character/effect/UI views reviewed, named findings repaired/no-finding closed, original13sets/143PNGs complete with preserved routes/budgets; [quality proof](#proof-quality). |
| 13 | Close the complete nearby-activity roster | ACT-HUD/WRITE/PLAY/REPEAT, TRAVEL-LIMIT, HULK | All12 named PLAY outcomes, applicable saved HUD/write boundaries, all12 ten-run REPEAT outcomes, agreed travel-leg limits and Hulk revisit; actual objectives/rewards/home/usable next start. [Activity proof](#proof-activity). |
| 14 | Qualify each implemented world's full physical round trip | WORLD-SOLO/ABANDON/SAVE/EDGE | SOLO-EMBER/AURORA/RIME complete canonical physical round trips and actual activity/save/reward/reboard/ascent/home; applicable abandonment/save/edge goals preserve usable continuation. [World proof](#proof-world). |
| 15 | Resolve remaining planetary content and presentation gaps | WORLD-CONTENT, ART-FINDING | Use delivered CONTENT-EMBER/AURORA/RIME maps; implement only actual uncovered authored behavior. Required world views/transition/weather findings resolved without inventing atmospheric wind on Ember; [world](#proof-world)/[quality](#proof-quality). |
| 16 | Close remaining fleet/crew replication gaps | NET-CREW, NET-CAPACITY | Existing physical ROLE-* roster ordinary claim/action/stand/exit/movement/loss/recovery, NET-SEATS-FINAL and chosen occupancy/capacity; no invented role matrix or Bomber scope reduction. [Network proof](#proof-network). |
| 17 | Complete remote engine and landing/dock presentation | NET-POSE, NET-BUDGET | Existing supported craft engine/throttle/hull/motion/landing consumers correct for current and late peers; preserve delivered330a39ce3 full-snapshot/power fixes; remaining explicit views/budgets/final-candidate proof only. [Network proof](#proof-network). |
| 18 | Complete supported remote helm actions and their real local-input prerequisite | NET-HELM, INPUT-DEVICE | Each supported sampled HELM action has actual host effect, neutral release and required ordinary handback/usable controls; physical INPUT-KBM/CONTROLLER separate. Retain accepted reverse/pitch/roll/yaw/boost/hover and ordinary handbacks; physical-device/endurance/final-candidate scope remains open. |
| 19 | Qualify honest remote-command recovery after host simulation stalls | NET-STALL | Retain accepted NET-STALL3d6b1b513 original600-step stalls/2s fresh actions/ownership/landing/reuse/cleanup. Relevant final-candidate/endurance profile verifies it through existing tests; no unchanged standalone rerun. |
| 20 | Complete remote landing, post-dock disembarkation and craft reuse | NET-LAND-DIAG, NET-DOCK | Named supported craft/role actual strict landing, coherent dock, physical passenger/pilot exit/reboard/reclaim and renewed departure; distinct second landing only once demonstrated distinct. Retain accepted Jovian reuse; [network proof](#proof-network). |
| 21 | Qualify fleet hull/component damage, repair, destruction and regeneration presentation across supported craft and roles | NET-DAMAGE | All applicable actual hull/five-component damage/repair/destruction/regeneration and supported peer-role recovery; same owner as11, delivered Halyard/component/power cases retained. [Combat](#proof-combat)/[network](#proof-network). |
| 22 | Qualify the implemented convoy actor lifecycle in native gameplay | NET-ACTOR[Convoy] | Existing Convoy tender/threat current/late/live/dead/reset/disconnect/solo-restoration cases use actual production actors, clean retirement and usable ordinary continuation; finite applicability first, [network proof](#proof-network). |
| 23 | Qualify Torpedo Run authority and solo recovery | NET-ACTOR[Torpedo Run] | Existing ten Torpedo authority/restoration cases, actual current/late airborne seeker adoption without launch replay, terminal retirement/no duplicate damage and usable solo recovery; PLAY-TORPEDO supplies ordinary clear/home once. |
| 24 | Finish remaining travelling-weapon and moving-crew integration | NET-ACTOR[Picket/Emberline], NET-CREW, WORLD-SHARED | Existing Picket/Emberline actual flight/hit/miss/expiry/live/dead/reset/late/loss cases integrate with named moving crew; no orphan/resurrection/double damage. Reuse ROLE/SHARED work, not another crew catalogue. |
| 25 | Qualify the production server-browser and connection flow | NET-BROWSER | All seven existing BROWSER goals: real discovery/join/stale/full/unreachable/controller/disconnect/cancel routes as applicable, accurate admission/refusal and usable retry/back; delivered UI fixes retained. [Network proof](#proof-network). |
| 26 | Pass multiplayer and endurance acceptance | NET-ENDURANCE, NET-CAPACITY, NET-BUDGET | Complete SERVER-BASELINE original server/two-client cases, original30-minute100msRTT/2%loss endurance with frozen jitter/reorder/budgets, chosen release capacity. Retain accepted Halyard contention/latejoin/destruction/loss/sleep scopes; [network proof](#proof-network). |
| 27 | Resolve planetary travel during multiplayer explicitly | WORLD-SHARED (each world/case) | The SAME21 shared-world goals as3. Exact Aurora47ffce740 handoff and Rime causal reopening dependencies remain; each full ordinary result/recovery/home outcome must pass. [World proof](#proof-world). |
| 28 | Benchmark and optimize on representative native hardware | PERF-MACHINE/ROUTE/RUN/FIX | Actual minimum/target machines and finite workload cells meet declared warmup/measurement/1080p p95/p99/stall/memory plus original GPU/VRAM/network/streaming budgets; fix measured hotspots. [Quality proof](#proof-quality). |
| 29 | Complete real-device controls and accessibility review | INPUT-DEVICE/REMAP, ACCESS-VIEW/COMFORT | Actual physical KBM/controller, specified remap/restart and finite UI aspect/scale/view states plus motion/flash/colour/captions pass. Delivered focus/overflow/control fixes retained; [quality proof](#proof-quality). |
| 30 | Finish authored audio and the real-device mix pass | AUDIO-CONTENT/MIX | Existing authored cues/music/voice/context cleanup plus actual authorized device/backend mix episodes and frozen output criteria; no redoing delivered repair/navigator/activity/surface playback. [Quality proof](#proof-quality). |
| 31 | Finish production crash and save recovery | RECOVERY-CONTRACT/FIX/KILL, ACT-WRITE, WORLD-SAVE | Existing real-file migration/corrupt/unsupported/refused-write/StartFresh and settled context recovery; four missing ACTIVE policies resolved then implemented where needed; actual kill/distinct restart/usable continuation/pay once. [Recovery proof](#proof-recovery). |
| 32 | Qualify installation, updates and supported desktop platforms | PACKAGE-WIN/LINUX, INSTALL-WIN/LINUX, LINUX-BUNDLE/DESKTOP | Exact chosen desktop packages/NSIS plus Linux clean/upgrade/rollback/retained/corrupt/uninstall and installed direct/desktop ordinary routes. Windows native execution exclusion retained; [release proof](#proof-release). |
| 33 | Complete all required graphical capture gates | CAPTURE (each required registry ID) | Each existing registered capture goal produces exactly its declared PNGs/source/sizes, inspected originals and resolved/dispositioned findings:13sets/143images, original quality/caps. [Quality proof](#proof-quality). |
| 34 | Complete release licensing, trusted signing and distribution | RIGHTS, SIGN, DISTRIBUTE | Concrete project terms and bundled-family permissions/attribution, actual trusted game/installer/uninstaller signatures/expected publisher, authorized destination and downloaded-byte identity. [Release proof](#proof-release). |
| 35 | Run final release acceptance on the exact distributed candidate | MATRIX, FINAL-RECONCILE, DISTRIBUTE | The SAME unfiltered MATRIX-FINAL as6, plus all36 promises/ten exits reconciled, zeroP0/P1/reviewedP2 and exact signed distributed/downloaded bytes; [release proof](#proof-release). |
| 36 | Resolve historical reconstruction dependencies and deliver the remaining researched fleet | HIST-CLAIM, ORIGINAL-SPEC/BUILD, CRAFT-ART/ACCEPT, STATION-MODULE | Eight named missing originals specified, actually built and accepted; four identity/provenance claims and station relationships tied to reproducible sources or explicit labelled interpretation decisions. [Craft](#proof-craft)/[decision](#blocking-decisions-and-resources) proof. |



## Original phase gates and completion

All ten gates remain open. The [preserved original specifications](history/ROADMAP_SCOPE_20261017.md)
remain authoritative; these observable exits summarize them without reducing scope.
Existing legacy phase anchors below are retained for links.

| Phase | Observable exit; every required child must pass |
| --- | --- |
| 1 Research | Original-labelled identity/topology claims have reproducible registered anchors/confidence; unknowns and any explicit approved interpretation are recorded honestly |
| 2 Vertical slice | Final-package Guided3/3, original all-nine Sandbox/recovery1/1 and original Settings/re-entry1/1; actual ordinary controls/combat/home/exit/usable continuation |
| 3 Station | Nine named connected physical branches and required interactions/revisit complete; four accepted service motions retained; actual topology/art/collision/berth findings resolved |
| 4 Original fleet | All twelve original craft, including eight absent today, implemented and accepted through their full specified physical/function/damage/recovery/reuse lifecycle |
| 5 Expanded fleet | Five modern additions accepted through their actual distinct functions/tradeoffs/roles and full lifecycle; they do not replace the eight absent originals |
| 6 Combat/damage | Six encounter owners, applicable eleven current firing bindings/five component consequences and missing-original specifications operate through real combat/repair/destruction/recovery/home, without double effects/rewards |
| 7 Multiplayer | Complete original server/two-client baseline, named roles/helm/actors/browser/lifecycle cases, original30-minute adverse-network endurance and chosen supported capacity |
| 8 Nearby activities | All twelve actual activity journeys and required ten-run repeats/durable outcomes, agreed travel legs and Hulk physical revisit/usable return |
| 9 Release | Required device/accessibility/audio/native performance, final package/install/recovery, rights/trusted signing and exact authorized distribution accepted on one integrated candidate |
| 10 Final quality/worlds | Required presentation/performance/stabilization and all three canonical solo world journeys plus21 shared cases complete; final candidate zeroP0/P1 and explicitP2 dispositions |

Native Windows execution/mandatory human review stay owner-excluded; factual
NOT_RUN is retained. Applicable Linux/native GPU/device/audio requirements remain.
No child assertion count or definition closes a phase.

<a id="phase-1--research"></a>

## Acceptance contracts for every named goal

The **Done means** column below is normative for every existing goal. A family is
a completion container, not an assignment; its explicitly named instances must
all finish. The original State/dependency cell and detailed retained contracts
continue to constrain the result. A blocked input is a goal with a finite answer,
not permission to keep researching or to invent a specification.

**Ownership and estimates.** Codex owns implementation, local checks, integration
and cleanup. The user owns the explicitly listed design/release decisions and
external access/credentials; device work requires actual access and audio output
requires authorization. A selected implementation names exact file ownership.
Allow 15–30 minutes for one decision-ready specification/handoff; implementation
is estimated from that accepted contract and split before 90 minutes. Existing
journey/soak durations remain unchanged. No honest estimate for an unbuilt craft
is available before its specification: this is a named blocked estimate, not an
open-ended build assignment. Planning completion is not gameplay completion.

Every executable handoff records: candidate/package, normal initial state,
participants/device/profile, action/command, all required endpoints, expected
state/reward/data, original deadlines, independent abort, and cleanup. Once that
handoff exists, execute or implement its named result; do not create another
handoff/evidence version. Stop at the first unexpected failure and record which
predicate failed. A supported correction preserves the whole result; after one
attempted repair, review cumulative cost before any further attempt.
That review records total elapsed cost and chooses park/switch or one bounded
continuation supported by new causal evidence and an explicit next stop. Renamed
or split cards retain cumulative cost; review is not automatic permission to retry.

### Ready means every acceptance input is fixed

This applies to **every** named row below. Words such as “specified”, “required”,
“applicable”, “usable” or “bounded” are references to an existing literal contract,
not pass conditions by themselves. Before selection, resolve each to the actual
listed action/state, expected value, original limit and proof location. An absent
value is recorded as an exact dependency and the task stays GATED or WAITING;
never choose the value after seeing a result. Preserve established tolerances.

Select one capability with one observable result. If its implementation estimate
exceeds90 minutes, split the actual production work into separately reviewable
capabilities before editing. Keep its original full-journey acceptance as a
separate required gate: a smaller implementation/check does not replace it.
Families and final matrices remain completion containers with their original
membership, not giant coding tasks. A named long-duration qualification is
executable once its complete cases and acceptance inputs are bound; keep its
original duration. It is not an implementation assignment.

A bounded assignment ends in exactly one of: **PASS** with the frozen result and
proof; **FAIL** with the first unmet predicate; **GATED/WAITING** with the named
missing input; or **PARKED** with retained source/results and a causal reopening
condition. No partial pass, new validator or additional research closes a product
goal. Record cumulative elapsed cost at failure or hard stop; close or park it
before selecting another assignment. Do not create a successor merely to continue
an expired budget. Reuse existing definitions and accepted results.

This bounded readiness pass preserves all337 canonical IDs and accepted records.
It does **not** make all337 executable. A source-map DONE remains a definition;
full craft, lifecycle, view and capacity rows remain completion containers.
Where the existing contract does not fix a field, its own row now names that
field and Codex or the product/resource owner. A row cannot pass by substituting
“all applicable”, “specified” or “usable” for those missing inputs. In particular,
shared-world case IDs are finite while their exact participant/phase/caller/cut
bindings can still be blocked. No new matrix, count or threshold is implied.

### Blocking decisions and resources

These are the only kinds of owner/external input that may block the listed work.
Already-settled choices below must not be asked again. Each row finishes with the
specified answer recorded beside the existing owner contract; implementation is
separate and must not be marked done by the decision.

| Existing or explicit goal | Exact answer/artifact required | Owner; completion proof |
| --- | --- | --- |
| SCOPE-LIMIT | Remote guests excluding host; whether host also plays; required physical per-craft occupancy/roles; chosen larger-crowd profile and applicable budgets | User decision recorded with concrete numbers/roles. Default8 and settings range1–32 are not accepted support |
| BROWSER-STALE | Monotonic expiry after the last valid LAN reply, continuing in paused menus; existing abstract30ticks has no duration/cadence | Codex selects explicit30seconds as an engineering default within authorized roadmap work; no user approval claimed. Earlier unanswered preference question remains optional, not an authorization gate. Deliveredca149d6: monotonic expiry/preflight/endpoint invalidation and original ordinary expired-row/Retry/freshadmission proof pass in recorded scope; no ticks→seconds mapping. Future user duration preference can amend the default |
| NET-ENDURANCE-DEFINE | Adopt or replace the literal proposed lab profile, directional loss/jitter/reorder/stalls, aggregate/forced-critical bandwidth, tick-drift/drain and equivalent-phase resource limits | User accepts or amends the exact rows of the [proposed table](MOVING_INTERIOR_LATENCY.md#endurance-execution-handoff--proposed-limits-2026-10-25): directional loss/jitter/reorder/stalls, bandwidth, tick drift/drain and resource ceilings. Original30min/100msRTT/2%loss/two-clients remain fixed. Completion is the recorded table with each proposed value accepted or replaced, not a general “looks good” with unresolved rows. Codex owns isolated-link implementation, ordinary1800s driver and measurement commands. Proposed values remain unapproved; no existing command or passing endurance result. |
| SCOPE-DESKTOP | Exact supported target list and explicit disposition of conditional extra desktop targets | User records required platforms; existing Windows Desktop/Linux x86_64 presets do not answer unspecified targets |
| SPEC-TITAN/VORTEX/PARADOX/KATANA/PREDATOR/DYNAMIC/UTOPIA/SALYUT | For EACH named craft: evidence reconstruction or labelled modern interpretation; intended use/weakness; hull/scale/access/berth/collision; handling; physical seats/roles/actions; weapons/navigation/cargo or explicit absence; damage/repair/recovery/save/reuse | Codex prepares decision-ready specifications from registered sources; user settles interpretation/design choices. All fields fixed, source confidence honest; prepared [Titan](design/TITAN_IMPLEMENTATION_PROPOSAL.md), [Vortex](design/VORTEX_IMPLEMENTATION_PROPOSAL.md), [Paradox](design/PARADOX_IMPLEMENTATION_PROPOSAL.md), [Katana](design/KATANA_IMPLEMENTATION_PROPOSAL.md), [Predator](design/PREDATOR_IMPLEMENTATION_PROPOSAL.md), [Dynamic](design/DYNAMIC_IMPLEMENTATION_PROPOSAL.md), [Utopia](design/UTOPIA_IMPLEMENTATION_PROPOSAL.md) and [Salyut](design/SALYUT_IMPLEMENTATION_PROPOSAL.md) proposals are not approval |
| BOMBER-ROLE-DECISION | Additional role count, each actual action and physical access/seat arrangement | User records exact additional roles; existing pilot-only runtime does not waive the original crew/navigation promise |
| RECOVERY-POLICY-CINDER-SUPPLY | Active manifest/inventory/deadline: resume listed fields OR named safe recovery; retained progress/debt; actors/claims retired; reset/refused-write behavior and ordinary continuation | User settles policy; Codex records a runnable accepted/refused-save and cold-restart contract |
| RECOVERY-POLICY-DEFENSE | Same fields for active wave/health/objective/timer | Same finite policy artifact; terminal-only saves are not scope approval |
| RECOVERY-POLICY-BREACH | Same fields for active encounter/objective/timer | Same finite policy artifact |
| RECOVERY-POLICY-TORPEDO | Same fields for active boat/seeker encounter/objective/timer | Same finite policy artifact |
| CARGO-REPLENISH-JOVIAN | Legitimate same-world source/refill trigger, conserved source/destination counts, capacity/refusal, and a normal ten-delivery route | User settles product policy; Codex implements/proves it. Existing six kits fund only three two-kit deliveries |
| CARGO-REPLENISH-CINDER | Legitimate shared-stock refill AND destination turnover; source/sink/trigger/conservation/capacity; normal ten-transfer route | Same. Existing two crates/destination capacity8 cannot prove ten; rebinding/reset cannot mint stock |
| PERF-MINIMUM / PERF-TARGET / PERF-ROUTES-DEFINE | Actual machine/OS/GPU/driver/resolution/quality and representative workloads; bind existing GPU/VRAM/network/streaming budgets where required but not numeric | User supplies access/target choice; Codex records exact machines, commands and ceilings before measurement. Reuse seven delivered selectors and world endurance; no new benchmark framework |
| ACCESS-CAPTIONS[overflow policy] | Select current-caption pagination, scrolling or wider/recomposed HUD when valid text exceeds the fixed safe area; settle timing/input/full-text/reservation behavior before implementation | User chooses presentation policy. Actual1280×720/request1.6 case measures650px intrinsic vs411.130435px safe; originalfonts/fulltext/width/reservation cannot all fit simultaneously. [Source and exact failed measurement](CAPTION_VISUAL_PRESENTER.md#open-maximum-payload-overflow-policy). No silent shrinking/truncation/transcript substitution; no runtime fix yet |
| INPUT-KBM / INPUT-CONTROLLER / AUDIO-MIX | Actual device/backend/session and frozen complete route; audio needs explicit audible authorization and chosen listening episodes/measurement ceilings | Resource/authorization recorded; synthetic input/Dummy remain insufficient for physical/output acceptance |
| RIGHTS-PROJECT-TERMS | Chosen project release license/terms and distribution disposition | User's explicit terms recorded; engine notices do not choose them |
| RIGHTS-BUNDLED-ASSETS / RIGHTS-HISTORICAL-MEDIA | Each actually bundled source/asset/media family has permission/license, attribution and redistribution disposition | User supplies missing permissions; Codex prepares final notices. Research-only media stays unbundled unless separately cleared |
| SIGN-FINAL / DISTRIBUTE | Trusted certificate/credentials and expected publisher; exact authorized destination | User supplies these; actual signatures/downloaded-byte proof closes the runtime release goals |

**Already settled:** automatic freight transfer; physical terminals show existing
jobs/manifests/receipts; conserved shared Jovian/Hauler stock; feedback for every
fresh authenticated navigator rejection; Beacon outbound≤60s; Bomber refill when
pilot retakes the seat; Defense Deploy arms the sortie. These remain closed
choices. Native Windows execution and mandatory human review are already
owner-excluded; unperformed facts remain NOT_RUN, without inventing new mandatory
gates. Applicable native GPU/device/audio/Linux requirements remain.

<a id="proof-core"></a>
### Core and station proof

- GUIDED-FINAL: exact final package, normal menus/controls, starter combat,
  strict home landing, neutral automatic shutdown, physical exit and usable
  walking, **3/3** complete runs; original route/caps remain.
- SANDBOX-RECOVERY: original **1/1 all-nine/54-waypoint** route, eight excursions,
  actual crash, same-Player recall, occupied-berth regeneration, recovery walk
  and reuse within its original300s. No shorter route replaces it.
- SETTINGS: original **1/1** apply/return/re-entry including gamepad-return route;
  actual saved bindings/options survive, gameplay control works and menu focus
  returns. Missing original runner/profile/logs is a finite recovery artifact.
- Station instances are exactly Central, Aft, Habitat, Freight, Fleet, Annex,
  Observation, Salvage and evidence-permitted VIP. Use the same supported Player,
  real doors/consoles/stairs/boarding and physical return; no test placement or
  rescue. Central includes launch/home/exit; Aft both elevations; Freight conserved
  transfer+cold receipt+same ship; Fleet every shipped craft's existing craft
  journey; Observation the actual viewing connector; VIP permitted reception and
  locked boundaries. Habitat rest/restart, Annex restock and Salvage durable
  revisit already have accepted scopes; do not implement them again.
- Existing tow, gantry, arm and patrol rails retain accepted walking/boarding
  results. Final review checks visible/collision agreement and flight clearance;
  it does not invent autonomous logistics or a ladder system from unknown imagery.

<a id="proof-craft"></a>
### Craft specification, build and complete journey proof

Original twelve: Torrent, Arrow, Jovian, Titan, Vortex, Paradox, Katana, Predator,
Dynamic, Utopia, Salyut, Zenith. Five additions: Halyard, Bulwark, Cinder Light,
Cinder Hauler, Cinder Bomber. All **17** remain promised; nine exist, eight do not.

Each SPEC ends with the fixed fields in the decision register. BUILD-SPLIT ends
with named production capabilities for that specification: authored source/hull/
collision/berth/access; handling/camera/clearance; physical role/cargo/navigation
functions; specified weapons or explicit unarmed design; damage/repair/recovery/
save/reuse. Each capability has owner/files, visible result, focused proof and an
estimate; the craft journey below is the integrated finish. These are actual
capabilities, not new validation frameworks or empty “build ship” assignments.

For EACH CRAFT-ACCEPT instance: ordinary walk/board/launch; exercise its actual
specified functions against real production targets/consumers; applicable damage,
repair or destruction/regeneration; strict home landing; neutral automatic
shutdown; physical exit and supported walk; fresh reboard/reuse; cross-craft switch
and whole-Main re-entry without stale claims/effects. Preserve editable source
art, hull/collision agreement, neighbour/camera/muzzle/berth clearance, audio and
stated handling tradeoffs. Exact source/package and final-candidate limits apply.

| Existing craft | Required distinctive action, in addition to the complete journey |
| --- | --- |
| Torrent | Starter combat and actual weapon damage; honest B5 evidence wording |
| Arrow | Precision hit/reconnaissance handling; preserve accepted two-flight/hit routes; visual sensor/pods are not invented gameplay |
| Jovian | Physical cabin/hold, conserved delivery and actual engineer repair |
| Zenith | Interceptor handling/weapon/access/reuse; honest registered B7 wording |
| Halyard | Passenger/gunner/engineer/Loadmaster physical walk/sit/action/stand/reseat; moving carry, actual damage/repair/readiness effects |
| Bulwark | Physical gunner aim/fire damages a real target; release/reseat/recovery |
| Cinder Light | Specialist handling/repeater/cooldown and component consequences |
| Cinder Hauler | Operable ramp, conserved cargo transfer, travelling mass driver, physical Loadmaster/Navigator actions; hints grant no helm/reward authority |
| Cinder Bomber | Four-round travelling payload hit/miss/depletion, qualified refill-on-pilot-retake and honest HUD; extra crew follows its explicit decision |

Missing craft retain known broad roles: Titan Medium Transport, Vortex Troop
Transport, Paradox Cruiser, Katana Fighter, Predator Detention Ship, Dynamic
Gunship, Utopia Dropship and Salyut Transport. Detailed unknowns remain blocked on
SPEC; no invented history or silent omission.

#### Torrent: finite acceptance coverage and missing ordinary route

CRAFT-ACCEPT-TORRENT, bounded source binding2026-10-25: the solo role is pilot;
this does not require a new engineer seat or any missing-craft specification.
The required sequence and existing supporting contracts are:

| Required result | Existing source contract and limit | What remains unproven |
| --- | --- | --- |
| Normal start, supported walk, board, launch, actual target damage, strict home landing, shutdown and physical exit | [Native Guided driver](../tools/release/run_native_sortie.py), existing `--route guided`, whole-process CAP300s; retained Guided acceptance stays in its recorded scope. | Current/final candidate qualification; Guided alone does not cover the subsequent damage/reuse/switch cases. |
| Fresh same-Torrent return/reuse | DONE5d2c58dba, `--route torrent-return-reuse`: actual package85.267s/OS0, two strict returns/90neutral-OFFLINE ticks each, fresh native boarding/second departure/fresh lease/physical exits/supported walking/normal UI exit. [Exact acceptance](history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025). | Remaining damage/repair/loss, cross-craft and Main scope is not closed; no unchanged replay selected. |
| Real incoming core impairment, airborne persistence and passive home repair | DONEa1de3363f, `--route torrent-damaged-return`: actual defender11damage, hull100→89/core.56/targeting.62;617uninterrupted airborne observations without repair;43strict passive commits restore core1, all five nominal/modifiers1/zero effects; hull89 retained through ordinary two-home continuation/UI OS0 in88.168s. [Acceptance](history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025). | One observed core impairment/repair case; broader component stages/destruction/cross-craft/Main/final gates remain open. No per-craft Cartesian matrix is introduced. |
| Correct pilot weapon in Guided range versus ordinary combat | [Weapon binding](WEAPON_DEFINITION_CONTRACT.md#current-registration-map): source1101; Guided LAUNCH/TARGET_PRACTICE uses360m/50damage, authored combat uses360m/34damage/.22s cooldown. [Migration check](../tests/weapon_definition_migration_test.gd) covers the binding. | Ordinary input must produce real registered target damage with the selected profile; loading a resource or emitting a fire request is insufficient. |
| Five component consequences and landed repair | [Component contract](COMPONENT_DAMAGE_MODEL_CONTRACT.md#actual-consequences-and-remaining-qualification): forward hull presentation; weaker wing controls fire; core controls targeting; engine controls mobility. Integrity≤.62 gives.62 and≤.24 gives zero for the corresponding operational channel. Torrent uses passive landed repair. [Model check](../tests/ship_component_damage_test.gd) and [fleet parity](../tests/hero_component_recovery_parity_test.gd) stage damage directly. | Bind ordinary damage encounters/contact, measured consequences and actual landed repair to the route; staged ledger mutation does not prove these actions. No engineer interaction may substitute. |
| Destruction, supported recall, regeneration and fresh Torrent boarding/use | [Torrent sortie check](../tests/torrent_sortie_completion_test.gd) covers return-loss retry, landing abort, exit-destruction fencing, once-only completion and free-sortie refusal; its regeneration wait is5.4 nominal simulated seconds, implemented as `ceil(5.4×physics_ticks_per_second)+30` frames. It directly boards and applies damage. | Ordinary full route remains PARKED/not accepted after three trials. Corrected resolver accounting observed eight genuine hits/100 total loss, required2101 final1-point hit, production recall and real pending deadline. Third stops71.859s at first post-recall `grounded=false` despite supported CentralJunction/control/capsule/camera restoration. Source places spawn before collision grounding; settling, regeneration/new generation, reboard/retry/home/UI NOT_RUN. No fourth trial; original clock/CAP300 retained. [Exact stop](history/ROADMAP_DELIVERIES.md#torrent-loss-recovery-third-attempt-stop-20261025). |
| Cross-craft switch and whole-Main re-entry without old claims, effects or source authority | Physical Torrent→Arrow→Torrent handoff/reclaim DONEdriveraf38de143/package6fe51dca4,131.708s: supported walking, both native seat/exit consumers, retired neutral producers and fresh Torrent stream with normal UI OS0. [Exact acceptance](history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025). The existing [combat lifecycle check](../tests/combat_destruction_recovery_lifecycle_test.gd) separately covers staged Main detach/re-entry; its destroyed pilot source is Arrow1102, not Torrent. | Shared retained Main resource/combat source binding DONE79dc473a5 via unchanged main_reentry_quality_test.gd: three cycles/source1101/hull/replay/queues/audio/nodes. [Accepted scope](history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025). Explicit component-ledger/generation and seat/berth claims are outside that test; preserve their existing named contracts. No ordinary-input/process-restart/packaged/Main-all-craft claim or unchanged replay. |

The existing [component integration check](../tests/ship_component_damage_integration_test.gd)
already fixes useful acceptance observations: impaired engine/fire/targeting
power.62; impaired fire cooldown equals nominal/.62; no airborne component repair
over90 physics frames (tolerance.0001); passive landed repair returns integrity1,
fire power1 and zero rigs in fewer than180 physics frames. These are staged
source checks, not new ordinary-route passes. The [Arrow switching fixture](../tests/arrow_sandbox_integration_test.gd)
already covers Arrow→Torrent admission with preserved guide progress, but stages
the walking position. The [Main re-entry check](../tests/main_reentry_quality_test.gd)
covers three direct detach/re-entry cycles with retained state and a restored
thirteen-source roster including Torrent1101. Reuse those focused contracts;
do not invent a normal process restart requirement for same-subtree re-entry.

**Definition result and subsequent delivery:** the bounded source pass identified
missing Codex-owned ordinary driver work, not an owner design choice or runtime
repair. The new `torrent-return-reuse` selector now supplies the return/reuse part
and is accepted in the exact package/input scope above. The new
`torrent-damaged-return` selector also accepts one real core impairment and
passive-repair case with ordinary continuation. The new `torrent-arrow-handoff`
selector also accepts physical Arrow ownership/exit and Torrent reclaim/exit
through actual native consumers. Remaining literal fields cover applicable
damage/destruction/recovery beyond the observed core case and the complete
full-craft route's fixed limits/command. The existing shared retained Main
resource/combat source case is now qualified on79dc473a5. It asserts Torrent
hull/source/replay/node/queue/audio behavior, not component-ledger/generation or
explicit seat/berth state; keep those claims within their existing contracts. Existing Guided/Sandbox/reuse300s caps stay unchanged;
none establishes a new aggregate deadline for the unfinished full-craft route.
Do not repeat this inventory or relabel staged source checks as ordinary play.

<a id="zenith-finite-acceptance-binding"></a>
#### Zenith: finite acceptance binding

CRAFT-ACCEPT-ZENITH is one existing completion goal, not a new set of child IDs.
Original source binding2026-10-26 on`1c3ecae05d3c71cf0ac4bc0a70e775c44c9d0b33`;
updated to retain the accepted Game`4bf5e889`/Driver`4870595fa`
[pilot/hit/home/reuse qualification](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026).
This reconciliation renews no test, capture or qualification result.
Reuse the existing [CRAFT-GAPS-ZENITH capability definition](COMPLETION_SCOPE.md#zenith-authored-capability-map--craft-gaps-zenith); this is its acceptance binding, not a new capability map.
This source-only binding changes no gameplay acceptance. Its original members
are the [complete craft journey](#proof-craft); the current roster remains twelve
originals plus five additions, with eight original craft still unspecified.

**Fixed production identity and supported functions.** The actual
[scene](../scenes/ships/zenith_interceptor.tscn),
[Zenith script](../scripts/ships/zenith_interceptor.gd) and
[definition](../assets/ships/zenith_b7_observed.tres) own
`zenith_b7_observed`, home `zenith_fleet_dock_berth`, `PILOT_CAPACITY=1`.
Only physical canopy access, pilot flight/cameras/weapon and shared
repair/recovery are required here; no cabin, passenger, gunner, engineer or
navigation function is inferred. Authored modern design is cruise94m/s,
boost126m/s, thrust42, brake54, hull68, engine start1.35s and landing maximum18m/s.
These are current resource values to preserve, not a newly invented performance
threshold or historical claim. Resolve boarding/seat/exit/muzzles/home from the
current craft and berth markers; fixed world coordinates from a staged test must
not replace those live transforms.

| Original member / literal action and observable finish | Production owner and retained proof, used once | Exact executable boundary still missing |
| --- | --- | --- |
| **Access and pilot admission.** Normal Begin Shift, supported walk along the existing Aft/stairs/Fleet bridge/Zenith approach; ordinary Interact boards this Zenith through its canopy. Same Player is seated as its sole pilot; original home remains occupied, exact craft/berth identities and OFFLINE state retained. | Existing `run_native_sortie.py --route life-arm` / `LifeTowPilot.ARM_GOALS`:15 ordered walking goals, actual Zenith boarding and90 seated observations. Reuse accepted LIFE-ARM `f2bf35a` once, in its recorded packaged scope. The retained archive run is52.811670s; original helper limits remain CAP300/outer360,15s per walking goal and12s boarding; it is a service-coexistence/admission route, not a flight or whole-craft pass. | DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: same Player walks15 authored goals and physically boards the sole pilot seat. Reuse the [accepted journey](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); no unchanged prefix replay or new admission definition. The separately parked WALK-AFT furniture/Board route remains outside this proof. |
| **Pilot handling and views.** From the admitted seat, real forward thrust wakes the engine, physically releases the occupied home berth and reaches FREE_FLIGHT. Exercise authored steering/roll, brake, hover, boost and cockpit/chase change, then regain controlled return flight; same pilot/current local command source and resource tuning remain. | HeroShip/Zenith and `zenith_b7_observed.tres`; production actions `move_forward`, `move_back`, `roll_left/right`, `brake`, `hover`, `sprint_boost`, `toggle_ship_camera_view` and ordinary mouse look. `zenith_interceptor_test.gd` / `fleet_role_differentiation_test.gd` anchor trade-offs and camera/seat contracts. `zenith_fleet_dock_integration_test.gd::_test_physical_sortie` observes actual short departure but stages access and return. | DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: native/consumed boost94.20213m/s, measured roll30.79999°, braking, hover and both camera transitions, with retained release tails and unchanged tuning. Reuse the [accepted route and limits](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); no missing pilot-handling selector or unchanged replay is selected. |
| **Actual weapon consumer.** Current pilot fires the registered repeater at one named real hostile/eligible production target within its authored range; retain an accepted/resolved source1104/weapon/sequence/target receipt and an actual28-point health loss, preserving original cadence and target authority. | [Weapon contract](WEAPON_DEFINITION_CONTRACT.md#current-registration-map), `zenith_combat_pulse.tres`: `zenith_interceptor_repeater`, hitscan420m/28damage/.24s. HeroShip→GameFlow→LiveCombatAuthority/resolver owns the hit. Migration/common combat checks establish binding. The staged fleet test shortens cooldown to.02 and deliberately misses every range target; it is **not** the required hit. | DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: actual native Fire resolves source1104/zenith_interceptor_repeater/sequence0 against DRONE-01, health100→72 retained after release, with420m/28damage/.24s unchanged. Reuse the [accepted hit](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); no missing ordinary-hit command or unchanged replay is selected. |
| **Applicable nonfatal component consequences.** Actual incoming resolved contact reaches Zenith's existing `forward_hull`, `port_wing`, `starboard_wing`, `core_systems` and `engine_bay` ledger; observe the authored impaired/failed consequences without treating a presentation effect as damage authority. Forward hull retains integrity/attribution/local damage cue; weaker wing governs fire; core governs targeting/convergence; engine governs thrust/steering/acceleration/speed/brake. | [Shared damage contract](COMPONENT_DAMAGE_MODEL_CONTRACT.md#actual-consequences-and-remaining-qualification), HeroShip.apply_damage / ShipComponentDamage / sole ComponentDamageModel. Inclusive integrity≤.62 gives impaired multiplier.62; ≤.24 gives failed multiplier0 for the operational channels. `zenith_interceptor_damage_feedback_test.gd` directly applies one controlled starboard-wing hit and observes its steady cue; shared parity checks are staged anchors only. | Shared attribution prerequisite DONEb4ff8c0: [actual repair/proof](history/ROADMAP_DELIVERIES.md#forward-hull-projectile-attribution-accepted-20261026),17realforwardhits across9craft onlyforward/oncehull, Zenith local cue,8focusedchecks, pairedexports/3strictstartups/exact1529payload pass. Baseline1 remains FAILED; corrected6a1f3f542 baseline isolates9wrongcore receipts. This staged prerequisite does not close the ordinary component member. Single core/repair caller5171119 PARKED after one pre-observation kernel-confirmed SIGSEGV; no gameplay acceptance, startup-cause review required before reopening. Legal activation SOURCE-DEFINED3ba8f2aa4 through physical Heavy Breach arm/Zenith departure/current WingSkirmisherLead2103; [exact source contract and missing execution fields](#zenith-heavy-breach-incoming-route--source-definition). Codex still owns ordered ordinary contact geometry/controls, nonfatal total budget, named impaired/failed component/consumer observations and original deadlines. No ordinary execution or five-component acceptance. Reuse activation and component maps; no repeated survey. No component×craft matrix or synthetic ledger write is authorized by this definition. |
| **Passive repair and restored function.** Physically return the damaged, intact Zenith to its actual berth; landed/not-destroyed/not-landing repair commits restore affected component integrity and the corresponding pilot functions. The hull retains its actual damage unless an existing owner explicitly repairs it; no engineer seat is invented. | HeroShip `_sync_component_damage` calls `tick_repair(delta, landed and not destroyed and not landing)`; ShipComponentDamage owns rate.62/s and the same ledger. Current damage contract distinguishes passive repair from engineer/terminal authority. Existing Zenith reset-for-reuse presentation checks are not passive-repair proof. | Single attempted core/repair caller5171119 is PARKED before any contact/repair observation (startup SIGSEGV); do not schedule an unchanged rerun. Existing source legal return is bound: an accepted normal L from live home capture starts landing, revokes Heavy fire authorization and withdraws/stands down the encounter. [Source definition](#zenith-heavy-breach-incoming-route--source-definition). Codex still binds the actual preceding contacts/nonfatal budget, ordinary return controls/accepted landing receipt, passive start/finish and corresponding restored-fire/targeting/engine consumer checks/deadlines. No measured ordinary repair cap or run is accepted. |
| **Loss, recall and berth regeneration.** Actual ordinary combat/contact destroys this piloted hull; old pilot/boarding/berth/combat effects retire, same Player is recalled to supported station play. After the existing2000ms minimum readiness delay and successful reset preflight plus lease reservation, the same registered Zenith is usable at its own home with a fresh life; physically board and operate it again. | GameFlow `_on_ship_destroyed`, `_recover_from_destroyed_ship`, `_replenish_destroyed_ship`, `_attempt_pending_regeneration`; HeroShip preflight/commit reset and source-life owners. The2000ms value is a readiness delay, **not** a guaranteed upper bound on reservation/reset completion. Existing shared recovery/lifecycle checks retain their staged scopes. | Codex: named actual fatal actor/contact and location, ordinary deliberate-loss input, pre/post life/claim/lease receipts, supported recall→Zenith walk/reboard path and per-boundary/whole-member deadline are unbound. No Zenith-specific ordinary loss selector exists. Do not replay the parked Torrent loss attempt or Sandbox all-craft crash route under this goal. |
| **Strict home, neutral OFFLINE and physical exit.** Fly this Zenith back without transform/velocity staging, use ordinary Landing Assist, accept the live berth's strict landing contract and exact dock transform/occupied lease; keep controls neutral for the authored1.5s automatic engine-idle shutdown. Only then ordinary Interact exits via its live ExitPoint; same unseated, controlled Player makes a supported walk clear of the wing. | Scene home and docking receiver; world berth/landing/lease owners plus HeroShip. The fleet integration test stages a moving pitched return, then verifies strict contract/lease/OFFLINE and physical exit; accelerated canopy/boarding/disembark times and staged return prevent ordinary-route acceptance. `EXPECTED_ANCHORS` defines the local authored markers, not a substitute path. | DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: both flights reach actual strict home/exact transform/occupied lease,90neutral physics ticks and authored1.5s automatic OFFLINE, physical Interact exit and supported wing-clear walk beyond7m. Reuse the [accepted route and its original limits](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); these route fields are no longer missing. This does not qualify damaged return or other unproved members. |
| **Fresh reboard and reuse.** After that supported exit/walk, approach the same live boarding marker and acquire a fresh pilot/command stream; physically depart again, release its home lease, then repeat strict home/OFFLINE/exit and usable walking. | Existing Player/boarding-area reservation/GameFlow switch and HeroShip source lifecycle. LIFE-ARM covers first admission only; `zenith_fleet_dock_integration_test.gd` does not prove this second ordinary flight. Existing `SandboxPilot.begin_craft()` is a route reference, not a new accepted shortcut. | DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: physical second boarding, cleared command0 before fresh consumed stream9, source5→retired7→ready9, second departure and strict home/OFFLINE/exit. Reuse the [accepted journey](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); no missing reuse selector or unchanged replay is selected. Parked all-nine/54-waypoint Sandbox remains unchanged. |
| **Cross-craft handback: Zenith→Torrent→same Zenith.** Exit the safely docked Zenith; physically walk to and board the existing Torrent, perform its supported pilot departure/home/OFFLINE/exit, then return by supported walking and reclaim the original Zenith. Only the currently occupied craft owns pilot/input; both home leases and source identities remain correct. | Fixed partner is the implemented starter Torrent, already present beside Zenith in the staged Main integration fixture; no missing craft/role decision is needed. Reuse the earlier accepted Torrent pilot/home contracts only for their stated scope; they do not establish travel between these berths. Production boarding/switch owners and source1104 distinguish the Zenith handback. | DONE Game`499e681`/Driver`8ba86d98e`: complete exported ordinary route162.917s, all42walkinggoals/280.899735m, mandatoryactualGuided4drones+defender/strictTorrenthome/90neutralOFFLINE/physicalexit and sameZenith90freshneutral reclaim onstream9>retired7>first5; laterstream10followsreceipt. All3131walking samples grounded/supported/current/max3D.167595<original.211667; actualnativeE/lifecycleconsumers, onePID normalHUDOS0, bothrealcleanmarkers/diag0/allownedcleanup. Four priorfailures remainfailed; safe cargo detour preserves everyoldgoal/cap and exact499gamebytes. [Accepted proof and limits](history/ROADMAP_DELIVERIES.md#zenith-torrent-handback-accepted-20261026). No unchanged replay selected; damage/repair/loss/art/network/external/fullcraft remainopen. |
| **Whole-Main lifecycle and normal termination.** At a declared settled point, exercise the existing same-subtree Main detach/re-entry contract: retain the same world, Player, Zenith, berth, authored-art registry and source1104 while retiring stale transient claims/effects and restoring usable controls. Separately, end the selected ordinary Zenith journey through normal HUD Exit and actual OS exit0. | `zenith_fleet_dock_integration_test.gd` removes/re-adds the same Main and checks exact retained instance/resource/registry/source identities. Reuse that staged lifecycle anchor in its scope; it is not a distinct-process restart. Existing native normal-exit machinery serves the separate ordinary termination predicate. | DONE settled retained-Main on`a70f9397a`: existing staged post-exit fixture passes57 assertions/OS0/one marker in45.495s, including re-resolved identities, model/healthy ledger, exact dock/lease/OFFLINE, restored full combat roster/source1104, empty settled claims/effects and actual grounded3.226154m move-left. [Proof](history/ROADMAP_DELIVERIES.md#zenith-settled-main-reentry-qualified-20261026). This proves absence of stale resurrection at this settled boundary, not populated in-flight claim/effect retirement; no whole-craft or ordinary-flight acceptance is inferred. Normal termination is separately DONE in accepted Game`4bf5e889`/Driver`4870595fa` scope: actual focused HUD Exit/OS0, both real durable clean states and zero detected diagnostics in133.691s. Reuse the [accepted termination](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026); it does not close retained-Main. Do not invent a user-facing reload action or require an OS restart to preserve instance IDs. |
| **Editable asset, hull/collision and clearance.** Preserve `art_source/zenith/zenith_authored_v1.blend`, its generator/imported GLB/manifest and B7-limited label; review actual close/cockpit/chase/far/berth and moving access views. Runtime24 mixed collision shapes must agree with the visible hull; canopy/seat eye, two muzzles, wing/comb/neighbour/deck and landing clearance remain usable through the physical route. Audio perspective follows cockpit/chase without stale ownership. | Zenith `EXPECTED_BOUNDS`, `COLLISION_SPECS`, `EXPECTED_ANCHORS`, runtime-authored presentation; `zenith_authored_asset_test.gd`, ship/fleet collision tests, navigation-light/plume/orientation/critical-wing tests and `audio/zenith_perspective_audio_scene_adapter_test.gd`. Reuse these as source/staged anchors. `capture-zenith-visuals` retains its seven-frame historical finding and seven-Texture-RID warning; IDENTITY-ZENITH retains the registered B7 scope and separate stronger-claim evidence dependency. | Codex: exact current package/source/capture cameras and original declared image inventory, player-height/flight clearance poses along this route, actual visual findings/dispositions and ordinary route limits remain unbound. Existing asset bounds/triangles are authored contracts, not new clearance tolerances. Native GPU/output and other unperformed external gates remain NOT_RUN; no new historical claim or unchanged parked recapture. |

**Execution-definition stop.** The original bounded source survey is complete.
Game`4bf5e889`/Driver`4870595fa` now supplies the accepted ordinary
pilot/hit/two-home/reuse/normal-exit command and its frozen inputs/limits in the
[retained journey](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026).
Do not select another survey, missing-selector implementation or unchanged replay
for those accepted predicates. The original four failed trials remain FAILED;
their source/raw and cumulative cost are retained with the accepted result.

There is still no ordinary combined full-craft command covering the unproved
component consequences/repair and loss/regeneration. Full Torrent handback is
accepted separately above. The unproved members retain the exact Codex-owned route/input/endpoint/deadline gaps above;
no original numeric whole-craft cap is supplied by the accepted subset.
Retained-Main remains a separately bound same-subtree check, and art/device/final
gates remain OPEN. Only a separately selected uncovered member with its route,
unchanged limits and concrete consumer can execute. Retained LIFE-ARM/staged
proof and WALK-AFT/Sandbox/Torrent-loss failures keep their recorded scopes and
reopening conditions. This reconciliation schedules no engine run, repair or
checkpoint and does not mark full Zenith acceptance DONE.

**Retained component-route source facts — no repeated survey.** The actual hostile
is RangeOpponent/source2101, `defence_pulse_cannon`,11damage/420m resolver range.
GameFlow `_begin_interceptor_engagement` activates only for starter Torrent;
boarding retargets an already-live opponent to the new active ship. These facts
do not establish that a legal Zenith attack/ordinary route exists. The accepted
Guided handback kills that defender and cannot supply the incoming hit unchanged.
Zenith hull68 becomes57 after one11hit; same-region integrity becomes6/17 and
operational channels impair to.62. A second same-region hit leaves hull46 and
fails that component. Forward hull has attribution/local presentation only.
Passive repair uses the same ledger at.62/s only while landed/intact/not-landing;
hull damage is retained. Current projectile routing is accepted above. Missing
ordinary activation/input/contact-order/return/restored-consumer/deadline bindings
remain Codex work in the two existing member cells; staged90/180-frame fixtures
are not newly invented ordinary deadlines. Reuse this source map.

### Zenith Heavy Breach incoming route — source definition

Bounded source-only pass2026-10-26, source3ba8f2aa4, start13:11:52UTC,
15minute allocation. Independent source review GO. No engine, trial, runtime
change, gameplay acceptance or new actor policy. The five-component/impaired/
failed and passive repair members remain open; this stops at their exact caller
contract gap and must not become another activation survey.

| Existing action/boundary | Literal production contract |
| --- | --- |
| Physical arm | Fresh profile's first Heavy Breach posting; normal on-foot E within2.8m, current board generation, no conflicting running activity or station-defense arm. GameFlow's existing physical board interaction arms the sortie. |
| Zenith launch | Physically board the registered Zenith/source1104 and apply normal forward thrust; require piloted active craft, departed own berth, FREE_FLIGHT and current combat registration. `_try_launch_armed_heavy_breach` passes actual active Zenith to `launch_armed_sortie`/`begin_heavy_breach`. |
| Actual hostile | Director `_launch_heavy_breach` activates Picket against the protected objective and the first configured skirmisher, WingSkirmisherLead/source2103, directly against Zenith. Screen spawn is92m toward objective,54m lateral,16m up relative to this craft; no staging/API activation is needed. |
| Real fire | `skirmisher_flank_scatter`:180m resolver range,14trigger damage split into three14/3 pellets,5°fan. Tactical engagement120m, telegraph0.28s, effective cooldown0.4s (telegraph additional). Current director roster/running Heavy, live Zenith/objective/picket, FREE_FLIGHT/not-landing, no wing disengagement and assigned wing role are required at dispatch. Anchor can fire; flanker additionally requires exposure≤−0.15; unassigned cannot. Aim dot≥0.9; charging retains aim≥0.84. |
| Legal withdrawal | Normal L must be accepted inside the actual compatible home capture with lease/reservation and `request_berth_landing`. A keypress alone is insufficient. `is_landing_active()` immediately makes director phase authorization false; its next outcome evaluation selects WITHDRAWN, sets CONCLUDED before stand-down, deactivates participants, clears roster and dismisses wing. |
| Home repair and end | Retain actual strict own-home occupied lease, same-ledger passive landed/intact/not-landing repair0.62/s without hull healing, restored affected consumers,90neutral physics observations/authored1.5s automatic OFFLINE, physical exit/supported walk and normal HUD Quit/actual OS0. These are required endpoints, not a new accepted journey. |
| Existing encounter bounds |150s encounter expiry; optional disengagement is beyond700m from origin AND every live participant for7s. Neither bound is a new incoming-contact deadline or whole-Zenith journey cap. |

**Conditional math, not contact acceptance.** For68hull Zenith, n pellets on one
component leave integrity`1−14n/51`: one0.72549 nominal, two0.45098 impaired,
three0.17647 failed. One complete trigger costs at most14hull (68→54) only if
no other hostile contact occurs. Pellet count, affected region and additional
Picket/scatter damage are not guaranteed. Do not turn that conditional value
into a promised ordinary health floor or choose a component after seeing a run.

**Concrete caller attempted and PARKED.** Source5171119 implemented the reviewed
72° live-capture pose, exact two-pellet core stage, emitted734/1000m consumer
comparison, combined all-source reserve,24-frame accepted landing and real
same-ledger repair/exit contract. It passed the frozen preflight, then its only
ordinary attempt crashed before the first observer state; no gameplay predicate
was reached. [Actual failure and reopening condition](history/ROADMAP_DELIVERIES.md#zenith-core-repair-startup-failure-parked-20261026).
The unaccepted observer/Boot/caller is archived, not merged. Current main retains
only the separately tested premature-exit reporting fixd0cbd2016. No second trial
or contact retuning; startup cause remains NOT_ESTABLISHED. One approved startup-
only debugger capture reproduced exact5171119 ELF/SIGSEGV at the same0x2e57c13,
but relevant frames remain unsymbolized. The missing artifact is an actionable
symbolized engine/script callsite, owned by Codex; this attempt stops without
another launch, symbol download or rebuild. All five components,
both stages, passive repair and full Zenith remain open. The following missing-
field record describes the earlier source pass and does not schedule a repeated
activation survey. **Original stop — BLOCKED definition, Codex.** Missing: ordinary pose/input/contact
order targeting the required component/stage; total nonfatal hull budget;
component→actual operational consumer before/after repair; controlled return
and accepted landing observation; per-leg and whole-route command/limits.
No existing Zenith incoming/repair driver provides those values. The existing
HeavyBreachPilot and observer own Arrow/source1102/picket kill/payment; the
Torrent damaged-return recorder requires source2101/defender/INTERCEPTOR phase.
Neither can be renamed to prove Zenith/source2103. Reusable seams are the real
board walking/arm prefix, LIFE-ARM physical Zenith admission, Zenith's accepted
home/exit controls and same-ledger damage/repair signal snapshots. A future
implementation would own the existing native runner/test, observer, Boot selector
and CLI privacy test, with no replacement damage authority or actor policy.

The starter-defender alternative is rejected for this route: normal landing
admits RETURN_TO_YARD or FREE_FLIGHT, not INTERCEPTOR_ENGAGEMENT. Retargeting on
boarding alone supplies no return/exit contract. Source identities and shared
component model remain mapped above. Reopening this definition requires the
missing literal contact/consumer/control contract, not another source map,
unchanged trial or additional planning ID. One observed component/repair case
would still not close all five components or both stages of full Zenith acceptance.

<a id="bulwark-finite-acceptance-binding"></a>
#### Bulwark: finite acceptance binding

CRAFT-ACCEPT-BULWARK retains its original [complete craft journey](#proof-craft).
This source-only binding2026-10-26 on`2b34ef71a` reuses the existing
[CRAFT-GAPS-BULWARK definition](COMPLETION_SCOPE.md#bulwark-authored-capability-map--craft-gaps-bulwark);
it is not another capability map or a gameplay pass. Original twelve plus five
additions remain **17**; no original journey member or parked result is removed.

**Identity and physical authority.** The production
[script](../scripts/ships/bulwark_heavy_gunship.gd),
[scene](../scenes/ships/bulwark_heavy_gunship.tscn) and
[resource](../assets/ships/bulwark_new_design.tres) own
`bulwark_heavy_gunship`, source1107 and home`bulwark_fleet_dock_berth`/Dock03.
Authored values are98m/s cruise,120m/s boost,22 thrust acceleration,30 brake,
300 hull,2.75s engine start and13m/s landing maximum. These preserve current
handling tradeoffs; they are not a new route deadline. Exactly two physical
anchors exist: pilot`pilot_station` and gunner`gunner_station`. Policy
`engineer_slot`/`passenger_slot` and four network walking berths add no chairs;
the manually claimed engineer fixture does not create a physical role obligation.
Bulwark is project-original modern content, with no historical identity decision.

For each missing field below, **Codex** owns the executable route/input/candidate
binding and bounded proof selection. No external owner decision blocks those
fields. Actual applicable native GPU and physical audio/input checks remain external
gates. Native Windows execution and mandatory human review remain owner-excluded;
unperformed facts stay NOT_RUN. Source/Linux/Xvfb and the staged network result
cannot establish physical output or device measurements.

| Original member / literal physical action and authoritative finish | Production owner and retained proof, reused only in its scope | Exact remaining executable fields and owner |
| --- | --- | --- |
| **Walk, canopy admission and launch.** Begin Shift; walk the station/Aft/Fleet bridge and raised Dock03 approach to this live boarding marker. Ordinary Interact boards the same Player into the physical pilot anchor; forward thrust wakes the engine, releases this occupied home lease and reaches FREE_FLIGHT. | Bulwark/ShipBoardingArea/Player/GameFlow; world-owned Dock03 and HeroShip. `bulwark_production_integration_test.gd` verifies identity, berth bounds/lease and supported exit but teleports the player/ship and uses zero-duration transitions. `SandboxPilot.begin_craft()` has Bulwark walking goals`[52,4.2,68.3]→[50.2,6.6,59.2]→[49,6.6,59.2]`; these are a route reference within the parked all-nine selector, not accepted admission. | Codex: bind live markers to an ordered supported Begin Shift→Dock03 path, actual canopy/boarding inputs and unshortened transitions, fresh pilot/source identity and lease-release receipts, departure endpoint and per-walk/boarding/startup/departure deadlines on one named source/package. No unchanged Sandbox replay is selected. |
| **Heavy pilot handling, cameras and actual pulse hit.** In controlled flight exercise thrust/steering/roll, brake, hover, boost and cockpit/chase; aim/fire the pilot cannon at a named real eligible target. Observe accepted/resolved source1107/`bulwark_sustained_pulse_cannon`/sequence/target and actual50-point health loss within360m at the authored.30s cadence. | HeroShip, Bulwark resource, `bulwark_combat_pulse.tres`, GameFlow `_get_player_weapon_profiles` and LiveCombatAuthority/resolver. GameFlow registers both pilot pulse and crew lance for the same source1107; attaching gunner authority must not erase the pilot profile. Existing ship/fleet differentiation and weapon migration checks are source/staged anchors. | Codex: outbound/turn/brake/hover/boost/return poses, exact native actions and neutral intervals, real target identity/starting health/aim geometry, one fresh press/release and hit/replay observation boundaries; bind original per-action/flight limits and candidate. No direct damage, moved target or cooldown override supplies the ordinary hit. |
| **Pilot→supported moving cabin→physical gunner.** Release controls until actual engine OFFLINE; while unlanded, ordinary exit invokes `_leave_seat_into_cabin`, disembarks relative to the live frame, sets piloted=false and registers the same controlled standing Player. Walk the supported local aisle`(-.62,1.33,.40)→(-.62,1.33,1.80)→(1.25,1.33,1.80)→(1.25,1.33,.65)` and Interact at the actual gunner approach/anchor. Retain frame registration, containment, floor support and exclusive gunner seat generation through movement. | GameFlow `_try_exit_ship`/`_leave_seat_into_cabin`, MovingInteriorFrame, ShipCrewSeat and Bulwark cabin/role contract; `bulwark_heavy_gunship_test.gd::_test_walkable_cabin_contract` casts a full standing capsule through those local legs and checks floor/skin support. Local points must be transformed through the current hull. The existing crew gameplay test also flies/brakes/idles the actual hull, then uses ordinary aft/right/forward walking and gunner Interact after teleporting only the initial exterior admission. Leaving the pilot seat retires active flight activity; it does not preserve a solo helm or create autonomous piloting. | Codex: exact ordinary OFFLINE stand input/start-stop, safe live drift/carry segment and observation duration, physical aisle input/reach/seat-admission path and per-leg/claim deadlines; bind body/frame/seat/command receipts and selected candidate. OFFLINE standing alone does not satisfy the gunner ONLINE discharge gate. Bind the real seated weapon-demand wake below for solo fire; bind concurrent pilot ownership separately for powered moving-crew flight. |
| **Charged gunner damage, depletion and release/reseat/reclaim.** From a current physical gunner claim, select/aim at a real eligible target; ordinary Fire first requests weapon power and must reach ONLINE without acquiring helm/releasing the dock latch, then holds through.45s base charge; dispatch accepted hitscan`picket_siege_lance` within560m for22 actual damage, with4.8s base cooldown. A fresh actor starts with2 rounds, cap8; accepted resolver submission debits one even on a miss. Release input/claim, stand at the live gunner exit, walk/reseat and verify current generation; stand again and physically return to the pilot anchor before reclaiming helm. | Bulwark `_crew_lance_definition`, `_consume_gunner_fire_intent`, charge revalidation, GameFlow `_submit_solo_gunner_fire` and HeroShip `request_solo_crew_weapon_power` precede LiveCombatAuthority. The latter validates the seated actor/claim/frame, records only power it woke and calls `_wake_engine_for_automatic_demand(false)`; the discharge consumer still requires ONLINE. Role release stops only its owned power without a pilot. Existing crew gameplay test holds actual Fire against DRONE-03 with no pilot shots/helm after staged initial admission; this source anchor is not the missing final-package full journey. The crew definition deliberately clears Picket travel fields and registers hitscan; no travelling bolt/reload is inferred. **Reuse f676c5016 once:**120 checks,133.997s, host+one-client; remote and moving-host hits each100→78, stand/reseat, stale-RPC/generation cancellation and pilot-disconnect cleanup. Retained report`/srv/mudds-work/bulwark-gunner-candidate-results-20261017/report.txt`; hatch/target/lease changes were staged. | Codex: exact solo target identity/selection/aim and ordinary raw hold/release sequence, witnessed OFFLINE→ONLINE weapon-demand ownership/no-helm/no-latch-release, ammo-before/after/cooldown/charge receipts, stand→approach→reseat→pilot-return walking/interaction sequence, source/claim retirement observations and each deadline. Bind retained network proof to its original candidate/caps without replay; two clients, actual host termination, hull loss, endurance and full ordinary admission remain outside it. No extra physical engineer/passenger route. |
| **Concurrent moving gunner and ownership-loss handback.** With one host and one client, one actual actor pilots while the other physically walks/sits/aims/fires from the moving Bulwark gunner; stand/reseat and release the current generation, then exercise the declared pilot-disconnect/ownership-transfer and supported handback endpoint without stale fire/helm. | NetworkBulwarkGunnerBinding, production crew/remote-pilot/cabin owners. Reuse the same f676c5016 result cited above once across these overlapping predicates: its moving-host gunner, pilot disconnect, stale-RPC and generation cleanup are recorded; staged hatch/targets/lease changes remain. Actual host termination and hull destruction were not proved. This supported two-player arrangement needs no new release-capacity decision. | Codex: bind exact host/client and pilot/gunner assignments, both ordinary station→craft admission paths, powered moving segment/target/carry receipts, literal disconnect/owner-loss cut, supported surviving-body return/reseat/exit endpoint, unchanged original driver/caps and candidate. Actual host-termination/hull-loss/endurance qualification remains under its existing named network/recovery goals; this binding creates no per-craft host-loss matrix and claims no reset-hull substitute. |
| **Nonfatal five-component consequences.** Real incoming resolved contacts attribute damage to`forward_hull`, `port_wing`, `starboard_wing`, `core_systems`, `engine_bay`; retain hull loss and the sole component generation/sequence/integrity. At integrity≤.62 impaired channels are.62;≤.24 failed channels are0. Forward hull owns integrity/attribution/local cue; weaker wing governs fire; core governs targeting distance/convergence; engine governs thrust/steering/acceleration/speed/brake. Bulwark gunner charge/cooldown divide by live fire multiplier; failed fire blocks discharge. | HeroShip.apply_damage, ShipComponentDamage/ComponentDamageModel and actual pilot/gunner consumers; [shared consequences](COMPONENT_DAMAGE_MODEL_CONTRACT.md#actual-consequences-and-remaining-qualification). `bulwark_component_damage_silhouette_test.gd` and crew gameplay checks retain controlled attribution/channel/cue scope; starboard scorch/failed vane is presentation, not another damage ledger. | Codex: named hostile/contact source and weapon, ordered real contact geometry and nonfatal hull budget for the five listed components, exact pre/post ledger and affected pilot/gunner observations, ordinary maneuver/fire inputs and per-contact/observation deadlines. No component×craft matrix, synthetic ledger write or direct-hit staging substitutes for the ordinary member. |
| **Passive repair and restored pilot/gunner function.** Fly the damaged intact craft to its own berth; while landed/not destroyed/not landing, passive component repair restores affected integrity and associated fire/targeting/engine channels. Verify a fresh physical pilot/gunner use after repair; hull damage remains unless an existing hull-repair owner actually changes it. | HeroShip `_sync_component_damage`→ShipComponentDamage.tick_repair at authored.62/s over the same ledger. Bulwark's optional six-kit engineer consumer is berth-gated but its policy identity is unanchored; do not require a fictional repair chair to complete passive repair. Existing shared component/crew fixtures remain staged anchors. | Codex: bind the preceding real contact receipts, ordinary home/neutral route, repair eligibility start/finish and expected original ledger/channel values, post-repair pilot/gunner interaction/fire evidence and measured completion deadlines. No new hull refill or engineer-role design decision is needed. |
| **Fatal loss, supported recall, regeneration and fresh use.** Actual incoming combat/contact destroys this piloted hull; old pilot/crew/boarding/combat and berth claims retire. Same Player returns to supported station control. After the existing2000ms minimum readiness delay plus successful reset preflight/reservation, a fresh Bulwark life occupies its own home; physically walk/board and operate it again with no old charge/ammo/claim authority. | GameFlow destruction/recovery/pending-regeneration owners, HeroShip reset preflight/commit and Bulwark destruction/reuse clearing. `bulwark_heavy_gunship_test.gd::_test_base_lifecycle` directly resets transforms twice; it is not ordinary destruction/recall proof. The2000ms delay is not an upper completion guarantee. | Codex: actual fatal actor/weapon/contact location and deliberate-loss inputs, old/new life/source/seat/lease receipts, supported recall→Dock03 path, fresh boarding/operation endpoint and fatal/recall/readiness/reboard deadlines. Retained f676c5016 does not prove hull destruction; no parked Torrent/Sandbox loss retry is transferred here. |
| **Strict home, neutral OFFLINE, physical exit and supported walking.** Fly back through the live Dock03 landing contract using ordinary Landing Assist; satisfy strict bounds/speed/orientation and settle at its exact dock transform with occupied current lease. Neutral controls allow authored1.5s automatic shutdown to OFFLINE; only then Interact exits via the live exterior marker, and the same unseated controlled Player walks clear on actual raised-deck support. | HeroShip landing/shutdown, GameFlow berth occupancy/exterior disembark and world Dock03. Production integration checks collision envelope/raised deck/ramp gap and physical exit support after staged transforms/zero-duration boarding. Source test tolerances are not a new ordinary flight/exit limit. | Codex: actual flight entry/capture/approach and raw assist/neutral/exit inputs, exact home/lease/OFFLINE observation interval, exit→deck-clear walking goals/support receipts, per-approach/shutdown/exit/walk caps and candidate binding. No transform/velocity staging or borrowed Guided300s cap. |
| **Fresh same-Bulwark reboard/reuse.** From supported exterior walking, return to its live boarding marker, acquire a fresh pilot stream, depart/release home, then repeat strict home/OFFLINE/exterior exit and controlled supported walking. | Player/ShipBoardingArea/GameFlow switching and HeroShip/Bulwark reuse/source lifecycles. Main ship's direct reset transactions establish reset behavior, not this second physical sortie; parked Sandbox all-nine/54-waypoint history remains unchanged. | Codex: exact clear-deck→reapproach walking inputs/reach, fresh pilot generation/neutral-stream receipts, second-flight turnaround/home endpoints and per-leg/whole-member caps on the selected package. No unchanged all-fleet replay. |
| **Cross-craft handback: Bulwark→Torrent→same Bulwark.** Exit safely at Dock03, walk to the existing starter Torrent, board/operate/depart/home/OFFLINE/exit it, then walk back and reclaim this original Bulwark. Only occupied craft/current source owns controls; both home leases and retired gunner claims remain correct. | Production walking/boarding/switch/lease owners; Bulwark1107 and Torrent1101. Torrent's accepted pilot/home contracts remain reusable only for their recorded scope; accepted Torrent→Arrow→Torrent is a different pair and supplies no Dock03 travel proof. | Codex: outward/reverse live-marker route and native input, exact Torrent accepted-proof/candidate binding, handoff/retired source+gunner-claim receipts, final Bulwark physical reclaim endpoint and per-walk/flight/handback deadlines. Fixed implemented Torrent partner needs no external craft choice. |
| **Whole-Main re-entry and normal termination.** At a named settled context detach/re-enter the existing Main subtree, retain world/Player/Bulwark/home/source1107 and authored resources, retire transient pilot/gunner charge/claim/effect authority, then restore controlled physical use. Separately finish the ordinary journey through normal HUD Exit with actual OS exit0. | GameFlow `_exit_tree`/re-entry attachment, Bulwark teardown/reuse and shared Main lifecycle owners. `bulwark_crew_gunner_gameplay_test.gd` already removes/re-adds the same Main, retains Player/role authority, checks the ledger empty and occupant tag gone, then physically reseats and verifies owned weapon-power wake. Reuse this source/staged anchor rather than invent a missing Main check. Its initial admission is staged; source content alone is not a newly executed pass. A new OS process cannot retain instance IDs. | Codex: bind that existing same-subtree check to the selected candidate and retained proof, identify the exact remaining world/home/source/charge/effect observations outside its current assertions and preserve its original member deadline. Bind ordinary HUD input/start-stop/exit cap separately. No invented user-facing reload action or OS-restart identity promise. |
| **Editable source art, hull/collision/clearance and audio.** Preserve the authored armor/shoulders/twin housings/dorsal bastions/canopy/cockpit/gunner furniture and editable production generators. Review close/cockpit/chase/far/home and moving aisle/seat views; visible hull agrees with actual collision, with pilot eye/camera, both weapon origins, Dock03 comb/neighbour/ramp/deck/canopy and cabin standing capsule clearance. Audio follows pilot/cabin/gunner perspective and releases old owners. | Bulwark runtime `_build_bulwark_variant`/fitout/collision/marker/cabin builders, scene/resource, shared ShipFitoutBatch and audio bindings. Ship/production/silhouette/mesh-sharing/gunner-feedback and `audio/bulwark_cinder_perspective_audio_test.gd` are source/staged anchors. Existing `capture_bulwark_camera_views.gd` and historical Forward+/llvmpipe300s registration timeout remain recorded; later default headless20-check pass does not close graphics/capture. | Codex: bind the existing editable GDScript generators/scene/resource to the required source-art handoff and reproducible build/import deliverable; an external Blender source is not present under current`art_source/`, so no existing `.blend` acceptance is claimed; current package/source and declared capture-camera inventory, player/flight/aisle clearance poses, actual visual findings/dispositions and original capture/route limits. Applicable native GPU/output remains NOT_RUN; native Windows/mandatory-human owner exclusions remain. No unchanged parked capture or new historical claim. |

**Executable boundary.** The bounded owners above expose no combined ordinary
Bulwark pilot→gunner hit→repair/loss→home/reuse→Torrent handback command with a
bound raw-input sequence and original numeric whole-journey cap. Existing
`SandboxPilot.begin_craft()` supplies a Bulwark access reference; its parked
all-nine route is not that missing command. The solo seated weapon-demand seam
is explicit; OFFLINE cabin admission is not itself live-fire proof, and a second actor is not required merely to wake weapon
power. The separate concurrent moving-crew journey retains its host+one-client
ordinary-admission/ownership-loss boundaries. Codex must select one uncovered
member, bind its concrete inputs/consumer/start-stop/original limits and reuse
retained proof once. This definition selects no engine run, gameplay repair,
new evidence family or checkpoint and does not invent an aggregate deadline.
All ordinary journey, art, role-network and final external gates retain their
original scope; nothing here marks Bulwark gameplay DONE.

<a id="proof-combat"></a>
### Combat, weapons and damage proof

Six encounter owners: initial interceptor, Courier, Paired Wing, Perimeter,
Heavy Breach and Torpedo. Real player weapons must achieve the named result,
settle its reward once, then complete physical home/shutdown/exit/usable return.
Wing means **both actual opponents destroyed**; Perimeter means the real core
survives **90s with >35%**; Breach/Torpedo reuse their PLAY sorties below.
Courier preserves separately accepted clear/escape/phase-and-distance withdrawals;
remaining escorted/recovery/repeat instances stay explicit.

The existing weapon contract names **eleven firing-role bindings across nine
craft**, not every invented role/craft combination. For each required uncovered
binding, prove supported-target hit/miss, self/friendly/occluded refusals,
cadence/heat/ammo, actual travelling impact where authored and stale-owner cleanup.
Use the five actual component IDs and consequences: forward hull integrity,
port/starboard weaker-wing fire limits, core targeting/convergence and engine
movement/braking; authorized repair/destruction/regeneration returns usable craft,
without duplicate damage, effects or score. Missing-original weapons/components
are specified first. Delivered HUD power/remote component fixes stay delivered.

<a id="proof-activity"></a>
### Twelve activity, durability and repeat proofs

Common PLAY finish: normal controls from ordinary start through real departure,
actual objective, genuine terminal result, exactly one durable payment/capacity
outcome, physical home dock, neutral OFFLINE exit and usable supported walking.
No injected checkpoint/kill/reward or arrival-near-home substitutes. Original
activity timers and complete-route caps apply.

| Goal | Objective that must actually happen |
| --- | --- |
| PLAY-RACE | Production countdown, five ordered physical checkpoints, existing120s timer |
| PLAY-THREADING | Start≤30m, five real gates in order; collision-before-progress failure remains |
| PLAY-PATROL | Both named relay_sweep/platform_sweep branches: five checkpoints,2s hold each, correct branch payment |
| PLAY-JOVIAN-KIT | Real departure and strict landing transfer exactly two kits/pay once; accepted first journey retained, cold KIT-RELOAD separate |
| PLAY-CINDER-SUPPLY | Actual load/clear gate/platform terminal transfer one conserved crate, one credit, duplicate refusal; accepted Jovian journey retained; Hauler delivery separate |
| PLAY-MINING | Approach≤30m and six actual extraction seconds; capacity receipt, not invented ore/currency |
| PLAY-SCAN | Approach≤24m, four real scan seconds, discovery/payment once |
| PLAY-BEACON | Four beacons in order/payment once; accepted complete journey retained |
| PLAY-CONVOY | Actual4m rendezvous, retained Main tender/threats and safe arrival;90s,42m proximity/3s separation rules retained |
| PLAY-DEFENSE | Physical Deploy/launch, waves1–2–1 all destroyed within existing34s activity semantics, payment/home/Reset and usable next Deploy |
| PLAY-BREACH | Arm posted Heavy on foot, real charged picket/protected objective/clear/payment and normal next posting |
| PLAY-TORPEDO | Reach posted Torpedo through ordinary rotation, evade/intercept real seekers, destroy actual boat/pay/home; no direct scenario selection |

Each REPEAT instance means **ten legitimate same-world completions** with their real
payment or capacity acknowledgement/reset and usable next start; equivalent-phase actors/registrations,
projectile/effect pools, observers/objectives do not grow. Distinguish legitimate
receipt/generation progress; do not invent a leak tolerance. Heavy and Torpedo
need ten clears EACH through the actual four-posting rotation: Heavy→Torpedo→
Paired Wing→Perimeter. Twenty Heavy/Torpedo successes serve those two goals, not
ten mixed successes; intervening postings must conclude ordinarily, without
skipping/direct selection or counting them as Heavy/Torpedo clears. Cargo requires the two explicit replenishment/
turnover decisions; reset/rebinding cannot create supplies.

HUD-Race/Patrol/Cargo/Convoy compare actual reset→selection→start→fresh-Main saved
state and actions. Reuse delivered UI fixes. Real-file write/rejected-write/reset/
reward checks use the existing twelve-owner ACT-WRITES roster; freeze only actual
uncovered boundaries, not a fabricated twelve×four test grid. Rejected reset/Start Fresh publications preserve the old durable/live state.
Progress/terminal write failures retain each named owner’s retry/debt/payment
contract; cold continuation cannot duplicate the actual payment or capacity result.

TRAVEL-LIMIT ends in a finite leg list: craft, outbound/return, exact clock/start/
stop/pause handling, agreed maximum and existing cap. Beacon outbound is already
≤60s with observed10.510574s; do not reask or infer maxima for other legs. Hulk
revisit means actual cold restore→physical bus/cell revisit→usable home return,
no second cell/payment; keep its original failed300s boundary and reopening cause.

<a id="proof-world"></a>
### Three solo worlds and exactly21 shared-world proofs

Each SOLO instance is canonical outbound→atmospheric entry where applicable→physical descent/landing/
exit→actual authored activity/save/reward→physical reboard/takeoff/ascent→strict
yard dock/exit/usable walking. Ember includes caldera relay/ember_beacon_data,
lava-tube and wreck errands; Aurora lookout/standing-stones observations; Rime
beacon/drill/gauge/ice-core plus actual cold failure/restart behavior. Content
source maps are DONE; do not call them missing planetary implementation.

Each world retains named abandonment/reboarding, save/reward/reboard/visit cuts,
cancellation/refusal/failure/repeat outcomes. A DEFINE artifact lists actual
owner/boundary/expected resume or safe recovery, exact participant/control route,
protected progress/debt and original deadline; it ends there, without engine runs
or additional evidence versions. Accepted Ember safe-yard/passive-survey recovery
is not an arbitrary surface-pose restoration waiver; Aurora/Rime have their own
surface restoration owners.

The existing SHARED rows enumerate Ember/Aurora/Rime × seven cases, **21 total**:

| Case, instantiated once per world | DONE requires, in addition to the actual world baseline |
| --- | --- |
| BASELINE | Independent ordinary crew canonical outward/surface survey/durable result/save and complete usable home return |
| LATE-JOIN | Fixed join cut; new peer receives current world/craft/crew/progress, obtains legitimate usable participation and completes required result/return |
| RECONNECT | Fixed transport-loss cut; old authority retires, usable recovery and fresh admission/crew work, reward stays once-only, return usable |
| PILOT-LOSS | Fixed pilot/phase; actual successor or settled safe-return result, no stale helm or stranded remaining crew |
| CANCEL | Fixed phase/caller; physical recover/reboard/return, actors/objectives retire, earned debt retained and next visit works |
| INTERRUPT | Actual committed boundary, owned OS kill/reap, distinct normal restart, specified supported recovery and once-only continuation |
| REVISIT | Complete first return, legitimate same-world readmission, repeated physical landing/walk/reboard/home with durable progress and bounded lifecycle |

No generic “multiplayer travel supported” pass closes these. Recover the exact
Aurora47ffce740 runner/arguments/candidate/profile/participants/raw records before
reproduction. Shared Rime keeps its actual landed-boundary failure and causal
reopening condition. No staged arrival, renamed selector or longer cap substitutes.

<a id="proof-network"></a>
### Multiplayer proof

- SERVER-BASELINE: production authority/two independent clients complete ordinary
  admission, walking, pilot/passenger roles, flight, strict dock, physical exit/
  reuse and usable continuation. All original named contention/transfer/latejoin/
  loss/reconnect/destruction/re-entry/adverse/invalid-command instances have exact
  outcomes. Retain accepted Halyard cases and complete promised Jovian coverage.
- ROLE instances: physical walk/claim/actual role action/release/usable continuation;
  applicable movement/disconnect/migration/recovery. Only implemented authored
  roles in the existing roster; no invented all-craft×all-role matrix.
- HELM: actual sampled named action reaches the host, has its authored effect,
  then ordinary release retires the old source correctly. Preserve accepted
  throttle/pitch/roll/yaw/boost/hover and ordinary-handback scopes; physical-device,
  endurance and final-candidate qualification remain separate.
- Landing/reuse: strict actual berth and coherent current landed presentation,
  physical passenger/pilot exit/reboard/reclaim and renewed real departure.
- Actor/damage: existing Convoy/Torpedo/Picket/Emberline live/dead/reset/late/loss
  cases use real production actors/projectiles; no launch replay, double damage,
  resurrection, orphaned actor or stolen crew authority.
- Browser: actual menu discovery/refresh/select/manual join/cancel/disconnect/
  retry, accurate stale/full/empty/unreachable feedback, no false admission and
  usable return. Physical controller route requires an actual device.
- NET-ENDURANCE: original **30 minutes**, independent two-client moving session,
  original **100ms RTT/2% loss** plus explicitly frozen jitter/reorder/stall profile;
  zero authority/seat/entity divergence, bounded queues/bandwidth and leak-free
  equivalent-phase resources. DEFINE must specify exact command/participants,
  impairment values and numerical ceilings before running. No short replacement.
  Release capacity is the user-selected guest/playing-host profile, not default8.

A new defect must map to one of these promised outcomes. No new network validator
or extra Halyard edge case is created merely because its harness already works.

<a id="proof-recovery"></a>
### Durable recovery proof

For named on-foot/pilot/cabin/bunk-rest/seated-crew/docking/planet/activity cuts:
accepted real-file state→owned actual SIGKILL/reap→distinct normal restart with
same data→settled supported state→ordinary look/walk/interaction and helm-or-exit
continuation. Claims/leases/network identities are fresh, not serialized authority.
Preserve accepted progress, inventory and unpaid debt; payment occurs once;
refused reset/Start Fresh publication retains the prior file/live state and
recovery choice. Failed progress/terminal writes follow their named owner’s
retry/debt/payment contract; gameplay progress is not universally rolled back.
Accepted Start Fresh durably retires active progress without deleting legitimate earnings.

Use each already-settled embodiment/world contract, not arbitrary airborne/sleep/
seat pose restoration. The four active-run decisions above are still missing;
terminal-only persistence does not waive them. Installed cuts use the exact final
installed Linux candidate. Valid migration reloads, corruption uses its specified
fallback, unsupported format never destructively overwrites protected files.

<a id="proof-quality"></a>
### Presentation, input, audio and performance proof

Review the finite existing station/fleet/world/character/effect/UI views, identify
actual named defects and desired visible results, then fix each with same-view
before/after and preserved gameplay/clearance. A properly inspected no-finding
view is a closed review; do not keep rediscovering it. All **13 registered capture
sets/143 PNGs** require exact declared inventory/source/size, original-resolution
inspection and resolved/dispositioned findings. Existing Forward+ environment
failures require a supported causal change, not lower quality or larger caps.

Physical KBM/controller complete menus and actual gameplay with all required
actions; remap/apply/conflict/reset/restart and context return behave as specified.
UI essential text/focus/scroll/safe areas work in the existing finite views/cells:
pause/options has five aspect groups and three authored scales. Reduced motion,
flash, colour cues and captions survive required transitions and restart. Do not
multiply every setting×device×world without an original requirement.

Audio uses the existing authored nine-craft/eight-normalized-activity/shared-episode
roster. Cue/music/priority/context transitions and voice cleanup work; actual
output balance/clipping/latency/repetition need named devices/backend and audible
authorization. Dummy dispatch does not prove listening.

On actual minimum/target hardware: ≥60s/**3,600** warm-up frames and ≥600s/**18,000**
measured frames, **1080p High p95≤16.7ms/p99≤33.3ms**, no post-warm frame>100ms,
working set≤4GiB, plus original GPU/VRAM/network/streaming budgets. Bind missing
budgets/workloads before measurement; preserve the delivered selectors and actual
whole-world repeat workloads. Fix measured hotspots, not speculative optimizations.

#### Reduced motion — finite production consumers

COMFORT-MOTION's bounded source-definition pass on e76fdbc80 identifies the
following eight remaining behavior-changing families. Damage and toast retain
their accepted receipts; they are not reopened. These are existing behaviors,
not eight new features or an invented craft×device matrix. No runtime defect or
new test result was established by this read-only pass.

| Existing consumer / trigger | Literal OFF → ON endpoint | Existing focused suite (`tests/…_test.gd`) |
| --- | --- | --- |
| GameFlow chase settings; retained ship and deferred fleet admission | Captured authored `maximum_chase_camera_rotation_lag_degrees` →0; OFF restores that captured value. No flight-command change. | `accessibility_reentry_integration`, `game_flow_fleet_expansion_registration` |
| ShipRestOverlay; actual rest entry and live accessibility refresh | New shade0→0.985 over0.6s → immediate0.985/no processing. ON also settles current rest; OFF does not replay its fade. Wake/claim behavior retained. | `ship_sleep_gameplay` |
| GameHUD Begin Shift | New intro fade0.45s → zero-duration tween leg; same hide-intro/show-HUD/start callback. Existing tween keeps its creation-time mode. | `first_person_view`, `controller_physical_sortie` |
| LoadingScreen; StartupLoader reads stored settings before attachment | Backdrop0.45s/dismiss0.35s/caret alpha0.35–1 over1.1s → immediate backdrop/immediate queued dismissal/steady caret1. No live Settings caller exists during loading. | `startup_loading_screen`, `loading_screen_transition` |
| NetworkMovingInteriorPresenter; live settings and presenter creation | Sample accepted anchor plus bounded elapsed clock → sample accepted anchor only, from next render. OFF restores existing clock sampling; local authority unchanged. | `network_moving_interior_presentation` |
| PlanetaryAtmosphereFlightEffects; ordinary advance reads HUD settings | Gust/buffet amplitude multiplier1→0.35 at next sample; steady wind retained. This affects existing bounded lateral drift; preserve its eligibility/reset/control invariants. | `planetary_wind_drift` covers drift, but has no explicit reduced-motion comparison |
| Arrow/fleet atmospheric entry exterior observations | Scale `1 + intensity × delta`, delta0.20→0.06 (maximum1.20→1.06); next accepted observation updates current/new effect. Generation/detach/airless hiding unchanged. | `arrow_entry_presentation_production_caller`, `hero_fleet_atmospheric_entry_envelope_production` |
| Arrow/fleet airless landing wash observations | Dust scale delta0.60→0.22 (maximum1.60→1.22); thruster delta0.45→0.15 (maximum1.45→1.15), with unchanged clearance/descent load; next observation updates current/new effect. | `arrow_entry_presentation_production_caller`, `hero_fleet_airless_landing_wash_production` |

The focused suites identify existing component coverage, not a new ordinary
package acceptance claim. A separately selected headless check uses
`tools/release/run_test_matrix.sh --godot /tmp/mudds-tools/godot-4.7.1/godot`
with `--audio-driver Dummy --mode headless --jobs 1 --scope tests/NAME_test.gd`
and its original300s cap; acceptance remains exit0, one terminal sentinel and zero
diagnostics. Input-only suites retain their isolated-display requirements.
No suite or renderer was run by this definition.

Settings ownership/default OFF/persistence/Reset reuse existing accepted proof;
cold ON selects the ON endpoints and authored Reset selects OFF. Static minimap,
trail, approach/Ember status, Bomber, camera-summary and caption metadata do not
create additional motion-animation episodes. An inaccessible live intro/loading
toggle is not a demonstrated repair requirement.

**Terminal definition result: BLOCKED ordinary-route binding—Codex.** The source
roster and existing behavior are now fixed; do not survey them again. For each
still-unproved original-required route, selection must name its existing normal
action/caller, exact candidate/profile, expected endpoint from this table and
original deadline, or record that exact unavailable caller. In particular, the
wind suite's absent comparison is a coverage gap, not proof of broken runtime
behavior or authorization for a test-only implementation task. Rendered and
physical-device acceptance remain open. No automatic successor or retry is selected.

<a id="ship-rig-caption-membership"></a>

#### Ship rig caption membership — source definition closed

On af97e5f82, [ShipAudioRig](../scripts/audio/ship_audio_rig.gd) has **21 possible
semantic IDs**, with the finite membership below. Nineteen have definitions in
[the canonical presenter](../scripts/ui/semantic_audio_cue_presenter.gd). This is
source coverage, not 19 ordinary-play/runtime qualification passes.

| Producer operation | Exact semantic membership | Caption definition |
| --- | --- | --- |
| Audio recovery / engine state | ship_audio_recovery_ready; engine_started; engine_stopped | Present |
| Engine damage bands | engine_degraded; engine_critical; engine_recovered | Delivered46bae53; actual composed cue path retained in its recorded scope |
| Thrust / boost | thrust_load_engaged; thrust_load_released; boost_engaged; boost_released | Present |
| Damage alarm | engine_damage_alarm; engine_damage_alarm_cleared | Present; retained alongside the three new engine captions |
| Component impact / fallback | engine_component_impact; port_weapon_component_impact; starboard_weapon_component_impact; sensor_component_impact; hull_impact_medium | Present |
| Destruction / landing | ship_destroyed; ship_landing_contact | Present |
| Caller-owned velocity/load API | engine_load_high; engine_load_normal | Absent; no production caller demonstrated for set_engine_velocity |

The bounded scripts/scenes search finds `set_engine_velocity` only at its rig
definition. Existing ship_audio_velocity_test and ship_audio_semantic_cue_test
invoke it directly; tests are not evidence of a live consumer. Do not add two
otherwise dormant captions or invent a velocity binding merely to fill this map.
The eight resident CUE_IDS/profile synthesis names use cue_requested, not the
semantic_engine_cue_emitted stream, and add no hidden semantic membership here.
Emission owners are the existing rig recovery/state/degradation/load/thrust/boost/
alarm methods, component mapping and impact/destruction/landing helpers.

This producer's source-membership definition is closed. Reopen it for an actual
changed producer/caller or demonstrated missing caption; do not repeat the same
survey. Other audio producers, ordinary transition/restart/Reset, rendered/device
and full COMFORT-CAPTIONS acceptance retain their existing open scope. No runtime
change, engine run, new validator, build or extra release gate is introduced.

<a id="proof-release"></a>
### Exact final release proof

One clean frozen integrated candidate passes required full ordinary routes and
the existing **unfiltered local --mode all** at original caps/no exclusions.
Use the preserved [severity and defect-disposition rules](history/ROADMAP_SCOPE_20261017.md#priority-order).
Bind the existing defect inventory to the candidate: every open finding has its
ID, severity, affected predicate and owner; P0/P1 count must be zero. Each P2 has
a recorded disposition, rationale and responsible owner; an ACCEPTED_RISK label
without those fields fails. Codex owns linking the inventory and existing policy;
only a genuinely unresolved release-risk choice needs a user decision. Match
Windows EXE/archive/NSIS game/installer/uninstaller and Linux ELF/archive/installer
bytes to that candidate; menu startup requires exit0+STARTUP_MENU_READY_OK.
Linux clean install/upgrade/rollback/retained/corrupt/uninstall transactions and
installed direct/desktop-entry ordinary play preserve the required data/files.
Settle project terms, bundled assets/attribution and final notices; research-only
historical media remains unbundled without clearance. Trusted real signatures
identify the expected publisher. Authorized publication/download matches exact
accepted bytes and checksums. Native Windows execution/mandatory human-review
exclusions stay excluded; unperformed facts remain NOT_RUN. Actual applicable
Linux/native GPU/device/audio gates remain. GitHub Actions stays disabled.

### MATRIX-FINAL — literal command and terminal result

This is the existing full source regression gate, not a packaged playthrough.
Before execution Codex records the clean candidate commit, absolute checkout,
Godot executable/hash/version, fresh private HOME/XDG paths and fresh absolute
log/status/results paths in its one selected card. `PROFILE_HOME`,
`PROFILE_CONFIG`, `PROFILE_DATA` and `PROFILE_CACHE` below are those recorded
private profile directories; PATH supplies the recorded toolchain. Final source identity is a
release dependency; it is not permission to defer defining this command.
Run from that checkout with an environment that does not inherit any
`TEST_MATRIX_*` overrides. `GODOT_BIN` below is the recorded engine path;
`RESULTS`, `LOG` and `STATUS` are the recorded fresh absolute output paths.

```bash
env -i PATH="$PATH" HOME="$PROFILE_HOME" XDG_CONFIG_HOME="$PROFILE_CONFIG" \
  XDG_DATA_HOME="$PROFILE_DATA" XDG_CACHE_HOME="$PROFILE_CACHE" LANG=C.UTF-8 \
  python3 tools/release/suite_process.py --timeout 21600 --detach \
  --log "$LOG" --status "$STATUS" -- \
  env -u WAYLAND_DISPLAY -u WAYLAND_SOCKET xvfb-run -a \
  tools/release/run_test_matrix.sh --godot "$GODOT_BIN" \
  --audio-driver Dummy --display-driver x11 --mode all \
  --timeout 300 --results-dir "$RESULTS"
```

Use the existing README supervisor cancellation procedure with PID/start-tick
identity and pidfd; never kill unrelated processes. The21600s outer limit is the
existing detached-matrix limit, not a replacement per-suite deadline. Each suite
keeps max(300s, its declared `test-matrix-timeout-seconds`); lanes/cleanup remain
owned by the existing runner. No `--scope`, filter, shard, accepted-risk option,
cache-drift allowance or manifest-scope override is permitted.

Pass requires actual supervisor `FINISHED`/exit0 after cleanup and the generated
`run-manifest.txt`: `overall_status=PASS`, `failed_suite_count=0`,
`execution_mode=all`, `mode_excluded_suite_count=0`,
`total_suites=discovered_suite_count`, `source_manifest_match=true`,
`godot_cache_stable=true`, `accepted_risk_count=0`. Every discovered suite has one
PASS row/exit0/required sentinel and zero diagnostics in `results-canonical.tsv`;
raw logs and the manifest's source/result hashes are retained. A launcher-ready
status, partial roster or source-only result never closes packaged/player/device
acceptance. The first failed predicate is the terminal result; any further run
requires the same cumulative-cost and demonstrated-cause review as other goals.

## Concrete child outcomes

Reconciled on 2026-10-24: every named record carries a **Done means** column;
all original IDs and accepted scopes are retained. This is a scope crosswalk,
not a claim that every row has an executable acceptance contract. Rows explicitly
marked BLOCKED definition still need their missing finite cases, routes or values
bound before they can be selected.
**Every row has an explicit Kind.** Capability = one production behavior;
Qualification = one named acceptance route or measurement; Definition = a finite
specification; Decision = recorded product choice; Resource = actual missing
artifact/access; Container = a group whose members must finish. A container is
never assigned as an implementation. Kind describes the result, not readiness;
the State/dependency and literal Done means still control selection.
 [Family contracts](#family-contracts) define the proof;
ROADMAP.md selects one implementation with exact owners, actions and budgets;
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

### Finite execution and blocking inputs

Inventory review2026-10-27: all337 canonical rows read once. Existing accepted
scopes remain closed. Residual ambiguities in HUD-CARGO/CONVOY, all three SOLO
worlds, EMBER-PACKAGE-ABANDON, BROWSER-CONTROLLER, installed crew/dock recovery,
Windows package identity, rights and the final matrix are now stated in their
existing rows as literal proof or exact missing fields with an owner. This is
a contract-disposition pass, not a claim that all337 records are executable:
PLAN-NEXT remains open until its source-resolvable definitions are actually fixed.
A blocker inventory is complete planning disposition only; it is not an executable
breakdown. An external dependency can remain blocked only with the exact missing
answer/artifact and its named owner. A Codex-owned missing route, command, fixture,
endpoint or member list must be supplied, or tied to a specific unavailable source
artifact with its completed search boundary; merely assigning it to Codex does
not satisfy PLAN-NEXT. No further inventory survey is selected; the next
definition resolves one named missing field rather than discovering another list.

The 337 IDs below are the canonical inventory. Their order, the 36 parents and
ten phase exits are preserved. A row is executable only when its existing Done
means and linked contract identify the complete finite scenario membership,
observable endpoint and pass/fail criterion. The selected card binds the exact
source/package, existing route/command, participants, original deadline and
cleanup. Missing contract values mean **BLOCKED definition**; unavailable owner
choices or resources mean **BLOCKED input**. UNSCHEDULED, OPEN or an older
ELIGIBLE family label never overrides these blocks. PARKED additionally requires
its recorded causal reopening condition. None of these labels authorizes a run.

Codex owns recovering existing commands, enumerating uncovered original-required
cases and implementing/testing a selected capability. The user owns explicit
scope/design/pacing choices, credentials, actual external hardware/access and
audible authorization. A definition assignment ends after one pass with either
the finite answer or the exact missing field and responsible owner recorded in
that same row. An unresolved field is a terminal blocked result for that
assignment; it is not permission to keep researching, add rows or run probes.
Do not choose arbitrary numerical thresholds to make an unknown contract runnable.

**Definition finish versus product finish.** A BLOCKED-definition row permits one
bounded attempt to supply exactly its missing fields; it does not permit the
blocked gameplay run. Write the answer in the same row/linked contract. A completed
source map is reused, not surveyed again. If fields cannot be recovered in the
15–30 minute definition allocation, record the exact absent artifact/value,
where the bounded search ended and its owner, then stop. The bounded definition attempt ends
with that explicit blocker; the definition remains BLOCKED until its required
fields are supplied. The product outcome remains open. Reopening
requires the missing information or a demonstrated source change. No automatic
successor, new numbering, extra validator or fresh budget is created.

Membership is closed by the existing named rows/linked rosters. A container
closes when those members pass, and is never an implementation assignment.
Previously accepted evidence may satisfy another literal predicate when its
source/scenario matches; record that reuse instead of rerunning it. A newly found
failure ends the selected card and stays attached to its existing outcome.
Additional work needs an uncovered original promise and a concrete production
result; definitions, smaller cards and tests are not new gameplay deliverables.

### Remaining contract gaps — PLAN-NEXT

This is the finite disposition of the **31 existing containers**, not another
work queue. Each row below names exactly what must be resolved in its existing
contract before it can be assigned. Codex owns these bindings unless an explicit
owner input is listed. Completing this list's definition work delivers no game
feature. Do not reopen completed surveys or create successor planning IDs.

| Existing container IDs | Fixed boundary; exact remaining definition/input |
| --- | --- |
| WALK-FLEET | Exactly the nine existing craft's access/home-exit/reuse members under CRAFT-ACCEPT below. Bind each live berth/approach/clearance route and existing driver; reuse the craft receipt rather than add a Fleet loop. |
| STATION-FINDINGS | Central, Aft, Habitat, Freight, Fleet, Annex, Observation, Salvage, VIP; tow, gantry, arm and patrol service views. Codex maps each to its existing capture or names the missing subject/state/camera/render/text/access/clearance fields. A reviewed view closes that view; retained parked captures require their recorded reopening cause. |
| ART-FINDINGS | Existing13 capture sets/143 images plus original fleet/world/character/effect/UI obligations. Codex maps each original obligation to a named existing image/view or exact missing view specification; reference STATION-FINDINGS once. No new obligation inferred from an empty area. |
| CRAFT-ACCEPT-TORRENT, CRAFT-ACCEPT-ARROW, CRAFT-ACCEPT-JOVIAN, CRAFT-ACCEPT-ZENITH, CRAFT-ACCEPT-HALYARD, CRAFT-ACCEPT-BULWARK, CRAFT-ACCEPT-CINDER-LIGHT, CRAFT-ACCEPT-CINDER-HAULER, CRAFT-ACCEPT-CINDER-BOMBER | Eleven acceptance boundaries listed below; each craft's existing distinctive functions remain in its row. Codex binds the unproved member's actual caller/input/contact/route/endpoints/limits and reuses accepted members. Missing ordinary driver code is implementation, not an external-access blocker. Bomber's additional crew alone depends on BOMBER-ROLE-DECISION. |
| CRAFT-ACCEPT-TITAN, CRAFT-ACCEPT-VORTEX, CRAFT-ACCEPT-PARADOX, CRAFT-ACCEPT-KATANA, CRAFT-ACCEPT-PREDATOR, CRAFT-ACCEPT-DYNAMIC, CRAFT-ACCEPT-UTOPIA, CRAFT-ACCEPT-SALYUT | User accepts/amends each existing SPEC proposal; Codex then adopts its existing BUILD-SPLIT cards and binds the same eleven integrated acceptance boundaries. Do not survey or write the prepared proposals again. |
| COMBAT-COURIER | Retain accepted clear/escape/withdrawal. Codex names the still-required escorted/recovery/repeat outcomes from original scope and their exact actor/terminal/home endpoints; unresolved membership keeps this container blocked. |
| COMBAT-PERIMETER | Ordinary90s core survival with >35% remaining and no-credit result/home is fixed. Codex names the original failure/recovery cases and their exact trigger/result/continuation before either is assigned. |
| COMBAT-TORPEDO | PLAY-TORPEDO owns actual clear/home once. Codex binds the original evade/intercept/fail/abort/solo-restoration cases to their actor/contact/terminal/retirement endpoints; parked clear work keeps its causal reopening gate. |
| NET-SEATS-FINAL | Existing promotion, seat-ledger, berth handback, contention and stale/duplicate/foreign-refusal cases. Codex names the literal existing goal/role/participant/caller receipts and candidate for each; no new role matrix. |
| SERVER-BASELINE | Original server/two-independent-client ordinary flight/dock/exit/reuse and lifecycle/adverse cases. Codex names exact reused SERVER-BASELINE child receipts and remaining route/cut/endpoints; short accepted slices cannot close the original complete journey. |
| COMFORT-MOTION | Reuse accepted toast/damage episodes and the [eight fixed remaining source consumers/OFF–ON endpoints](#reduced-motion--finite-production-consumers). Codex binds only still-unproved ordinary callers/candidate/profile/deadline and retained transition/cold/Reset endpoints. Source roster discovery is closed; missing intended behavior must be an explicit choice, not another survey. |
| COMFORT-FLASH | Existing17-family membership/policy is fixed; shared native save/three-process/Reset is accepted. Codex binds only each remaining normal trigger/caller/ordinary route and its existing effect endpoints; no new producer survey. |
| COMFORT-COLOUR | Existing enum0–3, literal HUD labels, health percentage/status, minimap glyphs/labels and caption severity markers are fixed. Codex names exact remaining ordinary/cold/Reset/rendered/device cases and routes. Device access remains separate from missing caller implementation. |
| COMFORT-CAPTIONS | Existing accepted Loadmaster/approach/engine/Ember and fixed ship-rig membership remain closed. Codex lists remaining original-required ordinary episode IDs/callers/text/severity/expiry/retirement/cold/Reset cases. User owns only the already-recorded maximum-payload overflow policy and actual audible/device access where required. |
| PACKAGE-FINAL | Codex names the existing Windows/Linux package/startup/payload/ordinary-route goal IDs and literal counts on one frozen candidate. Keep six INSTALL-LINUX transactions separately owned; final SHA binding waits for actual exported bytes, not for writing the transaction definition. |
| FINAL-RECONCILE | Existing36 parents/ten phase exits, shared outcomes counted once. Codex maps each to its complete existing members and accepted source/candidate scopes; every still-open child stays named. ZeroP0/P1, explicitP2 dispositions, final checksums, rights/signing and authorized publication remain actual release gates. |

**The eleven craft boundaries**, retained from the existing complete craft
contract, are: (1) physical access/pilot admission; (2) pilot handling/cameras;
(3) the craft's named actual functions/weapon consumers and physical roles;
(4) nonfatal component consequences; (5) repair/restored functions;
(6) loss/recall/regeneration; (7) strict home/OFFLINE/physical exit;
(8) fresh same-craft reuse; (9) cross-craft handback; (10) retained-Main lifecycle
and normal termination; (11) editable asset/hull-collision/access/camera/muzzle/
neighbour clearance and authored presentation. These are member boundaries,
not eleven new tasks per craft or an invented craft×case matrix. A legitimately
absent role/weapon must be explicit in the craft specification. For every
unproved boundary Codex records the actual missing route/trigger/endpoint/limit;
accepted members retain their own source limits. Zenith and Bulwark already
have detailed bindings; reuse them rather than start another mapping pass.

Other finite memberships stay in their existing rows:21 shared-world cases,
12 ten-run activity repeats, six Linux installation transactions and seven
existing performance selectors. Their missing fields are, respectively:
participant/role/phase/cut/durable endpoint/ordinary caller; same-world reset/
rotation/cargo source/sink/equivalent-phase counters; exact fixture/protected
files/modes/installed-usability command; and representative whole-world
workload/machine/command/metric ceilings. Codex owns source/caller/fixture work;
the decision register owns the exact unresolved cargo, active-recovery,
capacity, hardware and metric-policy inputs. Neither unavailable source artifacts
nor unapproved values authorize substitute runs. These missing bindings keep
PLAN-NEXT open; the container inventory above is now explicit.

### Varied encounter complete image set — frozen 2026-10-27

Selected goal: **capture-varied-encounters**; source-specific visual qualification
only. No gameplay/art implementation or parked capture retry is selected.

**Terminal result: PARKED before engine launch.** External wrapper supplied
`--log`/`--status` without required `--detach`; supervisor parser exits2, before
Godot. Wrapper then reads missing engine.log and raises FileNotFoundError instead
of publishing its result. No import/capture/display/images. Independent review
confirms exact cause; first-failure stop applies, no correction/retry selected.
Reopening requires a recorded cumulative-priority decision and wrapper source GO;
retain original02:40→03:40UTC budget and all preparation/closure cost.

**One continuation approved before correction,02:50UTC.** Independent high-risk
review chooses the exact wrapper fix over switching: parser cause demonstrated,
zero prior engine invocations,9.862minutes already spent and about49minutes
remaining. Remove unsupported --log/--status, use existing synchronous supervisor
mode and redirect stdout/stderr directly to engine.log; no early detached-ready
status can count as completion. Review corrected source before invoking it.
Permit one90s import then one unchanged300s capture, preserving03:00 import
readiness/03:05 launch/03:40 hard stop and all18 frames/quality/inspection.
Next unexpected failure is terminal PARK, with no further correction or run.
The failed original wrapper/archive remains unchanged. This explicit decision
supersedes only the previous no-continuation selection, not its failure or cost.

**Continuation terminal result: PARKED at original capture timeout.** Synchronous
wrapper accepted; one import passes22.168921s, no diagnostics/source change.
One full original-quality capture returns124 in302.300156s including teardown,
zero18required images/zeroDONE, no engine warnings/errors, unchanged frozen
source/imported resources. Live watcher305.041674s/no early diagnostic abort;
outer330s allowance not exhausted. Log only identifies engine/Forward+/llvmpipe
startup; precise cause remains unknown. All six process identities absent;
owned checkout/profiles/scratch removed,312record files verified archived.
Cleanup18.422497minutes cumulative on original02:40→03:40 clock, plus closure.
No further correction or run selected. Original preparation failure/archive
remains unchanged. Human/native-GPU/final-candidate gates and actual visual
inspection remain unperformed; no new playable build for this failed capture.
[Raw preservation and cleanup](history/ROADMAP_DELIVERIES.md#varied-encounter-preparation-refused-before-engine-20261027).

- Result: all18 authored encounter frames exist and have an original-resolution
  agent inspection. Seven played frames retain HUD/contact/objective information;
  eleven controlled plates expose opponent silhouettes, role lamps, armed/safed
  muzzle, the three-ray scatter fan, and courier/skirmisher damage stages.
- Start: clean commit containing this card, detached owned checkout at
  `/srv/mudds-work/varied-encounters-20261027/worktree`; separate fresh import and
  capture HOME/XDG profiles under that root. Source, registry and complete imported
  resources are frozen before capture. Main and historical image sets are protected.
- Files: no runtime/harness changes. Only this existing row/contract, ROADMAP.md,
  delivery history and this goal's existing registry entry may record the result.
  Accepted images go to `artifacts/varied-encounters-<source>/`; failed output stays
  in the owned external archive. No new validator or evidence family.
- Engine: existing guarded4.7.1 editor at
  `/srv/mudds-work/toolchains/godot-4.7.1-reflection-atlas-7b46e60/godot`,
  SHA256 `7b46e60fa1d4ddc979d35698a96d6cb16f79d03019ee5c84aaf24c98434c5f7d`.
  Private authenticated Xvfb1600x900/x11/Dummy, Forward+/Vulkan/llvmpipe using
  `/usr/share/vulkan/icd.d/lvp_icd.json`. This is a declared software-renderer
  deviation from the inventory's prepared DZN environment, with original authored
  quality unchanged; no native GPU/performance/physical-device qualification.
- Actions: one silent headless/Dummy editor import (90s preparation cap),
  then exactly one full capture using the existing command in
  [the inventory](GRAPHICAL_HARNESS_INVENTORY.md).
  Invoke `tests/capture_varied_encounters.gd` with `--resolution 1600x900`,
  `--display-driver x11 --audio-driver Dummy --rendering-method forward_plus
  --rendering-driver vulkan`, external `MUDDS_CAPTURE_OUTPUT_DIR`, cleared
  Wayland/parse/staging/wayfinding flags. Engine cap300s; independent process-tree
  supervisor330s; no user desktop or synthetic OS inputs. Supervisor kills/reaps
  owned descendants independently of any game menu.
- Exact images: `play_01_live_contact.png`, `play_02_courier_scenario_opens.png`,
  `play_03_chasing_the_runner.png`, `play_04_runner_outcome.png`,
  `play_05_wing_inbound.png`, `play_06_turning_into_the_flanker.png`,
  `play_07_objective_outcome.png`, `plate_01_opponent_roster.png`,
  `plate_02_anchor_and_flanker_lamps.png`, `plate_03_roles_traded.png`,
  `plate_04_armed_versus_safed.png`, `plate_04b_scatter_fan.png`,
  `plate_05_courier_calm.png`, `plate_06_courier_distress.png`,
  `plate_07_courier_critical.png`, `plate_08_courier_destroyed.png`,
  `plate_09_skirmisher_critical.png`, `plate_10_skirmisher_destroyed.png`.
- PASS: actual exit0; exactly one `CAPTURE_VARIED_ENCOUNTERS_DONE` and no FAILED
  marker/errors/warnings; exact18 nonempty PNGs, each1600x900; unchanged frozen
  tracked inputs/registry/imported resources; all owned processes reaped.
  Inspect every original: essential HUD text is legible and within the frame;
  named contact/objective is visible; plate subjects are in frame, silhouette/role/
  armed-state differences can be distinguished; scatter plate shows separated
  rays; successive damage stages show their named change. Each actual defect
  leaves this visual qualification open with its image/predicate; no speculative
  runtime repair. Do not promote human-review status or final-candidate scope.
- Dependencies: existing authored18-frame harness/registry and retained guarded
  editor; no missing design decision. Historical17 frames are not reused as18.
- Stop: selection/preparation charged from02:40UTC2026-10-27; estimate45minutes
  including inspection/closure, hard03:40UTC, reserve final15minutes for closure.
  Import readiness by03:00, capture launch by03:05. First unexpected failure ends
  the task: no correction/retry, quality reduction or larger cap. No prior attempt
  of this current18-frame qualification is claimed or erased; historical17 remain.
- Closure: one terminal result with first unmet predicate, commit/push, preserve
  raw source/logs/images and remove owned checkout/process/profile/scratch. No
  duplicate playable checkpoint for capture-only work. Broader release gates stay open.

### Baseline, scope and planning children

Finish means the named existing route passes on its frozen candidate, or the named definition ends with a finite answer/missing input. Guided, Sandbox and Settings retain their original [baseline contracts](#baseline-and-ordinary-controls).

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| SCOPE-ROSTER | Reconcile original twelve plus modern five craft, stations, opponents/weapons, activities, worlds, roles and targets | 4 | Definition | DONE as [finite named roster](COMPLETION_SCOPE.md#finite-release-roster--scope-roster): original12+modern5/eventual17, current9/missing8; other named inventories and unresolved boundaries preserved. No gameplay/qualification completion implied | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SCOPE-LIMIT | Release guest count and playing-host decision | 4,26 | Decision | WAITING; already-asked owner decision | User records guest count excluding host, playing-host yes/no, supported craft/role occupancy, chosen capacity profile and its numeric capacity budgets or the exact accepted NET-ENDURANCE-DEFINE budget table. Omitted budgets keep this decision incomplete; Codex owns implementation and actual measurement, which this decision does not prove. |
| RECOVERY-POLICY-CINDER-SUPPLY | Set active supply manifest/inventory/deadline restart outcome | 2,13,31 | Decision | WAITING; exact decision artifact in decision register; terminal-only current saves are not scope approval | Recorded [active-recovery policy](#blocking-decisions-and-resources): exact restored vs safe state, protected fields/debt, retired actors/claims, reset/refused-write and ordinary continuation. This row closes on the recorded owner decision only; runtime implementation and actual restart acceptance remain required under the existing activity-write/recovery goals. |
| RECOVERY-POLICY-DEFENSE | Set active wave/health/objective restart outcome | 2,13,31 | Decision | WAITING; exact decision artifact in decision register | Recorded [active-recovery policy](#blocking-decisions-and-resources): exact restored vs safe state, protected fields/debt, retired actors/claims, reset/refused-write and ordinary continuation. This row closes on the recorded owner decision only; runtime implementation and actual restart acceptance remain required under the existing activity-write/recovery goals. |
| RECOVERY-POLICY-BREACH | Set active Heavy encounter/objective restart outcome | 2,11,13,31 | Decision | WAITING; exact decision artifact in decision register | Recorded [active-recovery policy](#blocking-decisions-and-resources): exact restored vs safe state, protected fields/debt, retired actors/claims, reset/refused-write and ordinary continuation. This row closes on the recorded owner decision only; runtime implementation and actual restart acceptance remain required under the existing activity-write/recovery goals. |
| RECOVERY-POLICY-TORPEDO | Set active Torpedo encounter/objective restart outcome | 2,11,13,31 | Decision | WAITING; exact decision artifact in decision register | Recorded [active-recovery policy](#blocking-decisions-and-resources): exact restored vs safe state, protected fields/debt, retired actors/claims, reset/refused-write and ordinary continuation. This row closes on the recorded owner decision only; runtime implementation and actual restart acceptance remain required under the existing activity-write/recovery goals. |
| CARGO-REPLENISH-JOVIAN | Legitimate conserved stock source for ten delivery cycles | 13 | Decision | WAITING product policy; six initial kits fund only three deliveries; reset is not a source | User-approved [cargo cycle policy](#blocking-decisions-and-resources) records legitimate source/sink/trigger, conservation, capacity/refusal and normal repeat route. Implement the accepted policy under PLAY-JOVIAN-KIT; ten real conserved cycles belong to REPEAT-JOVIAN-KIT, counted once. Policy approval alone delivers no transfers. |
| CARGO-REPLENISH-CINDER | Legitimate shared-stock refill and destination turnover for ten cycles | 13 | Decision | WAITING product policy; no rebinding/reset to mint crates or free destination capacity | User-approved [cargo cycle policy](#blocking-decisions-and-resources) records legitimate source/sink/trigger, conservation, capacity/refusal and normal repeat route. Implement the accepted policy under PLAY-CINDER-SUPPLY; ten real conserved cycles belong to REPEAT-CINDER-SUPPLY, counted once. Policy approval alone delivers no transfers. |
| RIGHTS-PROJECT-TERMS | Record project release terms and distribution disposition | 34 | Decision | WAITING owner-chosen terms; engine notices do not choose the project license | User records exact project release terms/license and allowed distribution; final package notices reflect that answer. |
| RIGHTS-BUNDLED-ASSETS | Clear actual bundled asset/source families and final attribution | 34 | Resource | BLOCKED definition — Codex: reconcile the frozen package inventory against the six existing RIGHTS-DEFINE families; name each genuinely missing permission/attribution document and its holder, or record none. Project terms depend on RIGHTS-PROJECT-TERMS; historical media depends on RIGHTS-HISTORICAL-MEDIA. Settled creator permission is not a missing grant. | For each of the six [existing rights families](#rights-families-and-missing-documents--rights-define), record included/excluded, exact packaged paths and the existing authorship/license/attribution location. Every included external family needs its actual redistribution permission; missing documents have a named holder. Final Credits/notices match the frozen inventory. Do not invent an unspecified permission wait or repeat the completed source-family survey. |
| RIGHTS-HISTORICAL-MEDIA | Record each historical-media redistribution disposition | 34,36 | Resource | WAITING where rights absent; research-only media stays unbundled unless explicitly cleared | Every historical-media family explicitly cleared for bundling or excluded; research-only permission is not inferred redistribution. |
| NET-CAPACITY-FINAL | Qualify the chosen remote-guest/playing-host profile | 4,26 | Qualification | WAITING input (user): SCOPE-LIMIT guest count excluding host, playing-host choice, supported craft-role occupancy and capacity budgets. Then BLOCKED definition (Codex): literal reused SERVER-BASELINE/NET-ENDURANCE membership required for that chosen profile, unchanged durations/limits and concurrent participants; select seat/contention/join/reconnect/bunk cases only where the original capacity contract requires them. Default8/settings1–32 are not accepted support. | After SCOPE-LIMIT fixes guest count, host participation, craft/role occupancy and budgets, Codex names the exact reused SERVER-BASELINE and NET-ENDURANCE journeys required at that capacity. GATED until this finite list and original durations/limits are explicit; every listed journey must pass with the chosen participants concurrently present to close capacity. No default-setting capacity claim. |
| SCOPE-DESKTOP | Required desktop target list | 4,32 | Decision | WAITING final owner list: Windows Desktop/Linux x86_64 presets exist; Phase9 conditionally requires other non-Windows targets without naming one. Source investigation DONE; no third-target promise or deferral inferred | Recorded exact supported desktop list and explicit conditional-target disposition; user decision. |
| PLAN-NEXT | Finish the finite executable breakdown | 5 | Definition | Scope crosswalk DONE2026-10-24; executable breakdown INCOMPLETE. [Remaining31-container contracts and other finite binding gaps](#remaining-contract-gaps--plan-next) are enumerated once; this list is the definition boundary, not a new discovery queue. Original36 promises/ten exits and all327 prior goal IDs preserved; ten blocking decision/resource outcomes named. Remaining full-craft, shared-world, comfort, installed-recovery, installation and performance contracts retain exact BLOCKED definition fields in their existing rows. Codex owns filling source-resolvable fields; owner decisions stay with their named owner. Accepted freight/Hauler/navigator deliveries remain closed. | Definition accepted only when all337 existing records have a Kind and literal prerequisite IDs (or none); every source-resolvable action/endpoint/limit/proof and Container membership is fixed in its existing contract. An unavailable external answer/artifact may remain dependency-blocked only with its exact field, named owner and required answer/artifact; an unavailable historical execution artifact also retains its completed search boundary. A Codex-owned field without its answer or that specific artifact dependency keeps PLAN-NEXT OPEN. Each selected implementation must fit the existing90-minute closure limit and have its own observable result; complete journeys retain their original limits. No dangling “applicable”, “usable” or “specified” reference supplies a value. Acceptance proves the breakdown only, not product completion. Writing a blocker ends only that bounded attempt; it does not resolve a source-resolvable definition. |
| GUIDED-FINAL | Final-package Guided ordinary-input sortie, original 3/3 | 7 | Qualification | GATED on final package; checkpoint3d92b91 ordinary3/3 DONE, earlier f676c50 retained. Do not repeat current accepted package unchanged or transfer it to a different final candidate | [Core](#proof-core): on the selected final package run `tools/release/run_native_sortie.py BINARY --output DIR --route guided` three times, each with a fresh process/profile and distinct output directory. Each full ordinary starter-combat → strict home landing → neutral automatic shutdown → physical exit → supported walking → normal HUD Exit must finish with actual OS0 within original CAP300s. Require 3/3; stop at the first failure. Preserve original shutdown timing and durable clean-close requirements. Earlier checkpoint passes remain accepted only on their recorded candidates. |
| SANDBOX-RECOVERY | Original all-nine/54-waypoint recovery walk and reuse | 7 | Qualification | PARKED; supported changed input/runtime cause required | [Core](#proof-core): original all-nine/54-waypoint/eight-excursion crash/recall/regeneration/reuse route1/1 under300s. |
| SETTINGS-INPUT | Recover original runner, profile and logs | 7,8,29 | Resource | BLOCKED input: bounded source recovery COMPLETE; the four original execution artifacts listed in Done means remain unavailable. Exact writer/reader identities and search boundary are retained in the [bounded recovery](#original-settings-artifacts--bounded-recovery). No new source survey, replacement Gate C or run is selected. Reopening requires a missing artifact or concrete new location. Codex owns artifact recovery; the present holder/location of the four original artifacts is unknown, not assumed to be the user. | Supply the four missing original artifacts: final writer/restart orchestration with launch/status receipts; original isolated durable profile; final source gamepad-return timeout log; later packaged gamepad-flight timeout log. Match the recovered source/package identities and original300s in the [bounded recovery](#original-settings-artifacts--bounded-recovery). Source recovery is complete. Reopen only for one of these artifacts or a concrete new location; a repeated search or replacement route cannot close this goal. |
| SETTINGS-RETURN | Original Settings/re-entry route, including gamepad return | 7,8,29 | Qualification | GATED; SETTINGS-INPUT and supported correction | [Core](#proof-core): original apply/return/re-entry1/1 including actual gamepad-return and persisted controls. |
| LIFE-VISIBLE | Four-cycle source phantom-geometry qualification | 7 | Qualification | DONE; d7be01487, staged/headless source scope | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| LIFE-REUSE | Twelve-cycle source all-nine reuse qualification | 7 | Qualification | DONE; d7be01487, staged/headless source scope | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| LIFE-PACKAGE-DEFINE | Name uncovered packaged ordinary-play lifecycle cases | 7 | Definition | DONE source definition only; [finite packaged lifecycle boundary](#packaged-ordinary-lifecycle--life-package-define). Existing named journeys own their package acceptance; no additional all-game loop is selected. Any uncovered original repeated-transition predicate remains BLOCKED definition until its literal route/count/rest-state/resource endpoints are fixed. The accepted4-cycle/12-cycle staged checks do not set packaged values. | DONE for the [packaged lifecycle source map](#packaged-ordinary-lifecycle--life-package-define). Reuse GUIDED-FINAL, SANDBOX-RECOVERY, named CRAFT-ACCEPT/role, SETTINGS-RETURN and installed-recovery children for their lifecycle predicates. Only an identified original repeated-transition requirement not covered by those children can justify additional work; first bind its literal route, count, rest state and resource endpoints. This row neither runs another all-game loop nor reopens its completed source survey. |
| CONTROL-FINDINGS | List observed unresolved control/help defects | 8 | Definition | DONE as bounded source review: advertised Right Stick LOOK has no Player/Tow consumer; GAMEPAD-LOOK packaged99e79c3 separately. Existing mixed prompts/distance help/sprint fixes retained; physical-device acceptance remains open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| GAMEPAD-LOOK | Continuous right-stick local camera look | 8,29 | Capability | DONE in99e79c3: Player/tractor real camera, authored delta rate/deadzone/clamps/inversion and handoff clearing; full focused checks/paired checkpoint pass. Physical controller/full ordinary route remains open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| UI-BOARD-FOCUS | Keyboard Activity Board transition retains valid visible focus without engine signal-disconnection errors | 8,13,29 | Capability | PARKED/OPEN; diagnostic source preserved under `archive/withheld/ui-board-focus-20261018`, working branch deleted. key-only4.673s and changed tooltip4.954s components both NOT_REPRODUCED. Second establishes one visible embedded popup with matching root recipients and successful teardown. Original popup identity/connection-removal event unknown; no production cause/fix. Two-attempt cumulative9.627s, original investigation budget retained. Actual full-Main Beacon-home candidatea612ea686 recurs at37.713s/frame1233; page transitions but same two diagnostics, still no popup/removal identity. Actual-Main diagnostic now proves native/canvas coordinate mismatch: embedded-popup get_screen_transform omits rootstretch. Corrected reporting admits actual visible TooltipPanel/both native rootbindings/retainedExitfocus, then ordinary HUDclose exits0 with no original errors on unchanged runtime. Original pair NOT_REPRODUCED; no runtimefix/completion accepted. Source archived under archive/diagnostics/tooltip-hover-admission-20261020, scratch cleaned. Linux-release synchronous ActivityBoard capture b1b659d6e later passes shared BeaconEntry prefix44.456s: eight snapshots/two transitions,55hiddenPopupMenus/no visiblepopup, only unchanged SceneTree focusbinding. Original Home caller/extraobserverpayload absent; no error-emitting lifecycle captured. Actual popup/connection-removal identity in failing original journey remains missing; no further UI repair/retry selected. Exact full Home caller/observer replay5f2cafb94 now also has no original errors: eight transition snapshots,55 hidden PopupMenus/only SceneTree focus binding; UI cause remains unproved. Full route fails original300s deadline at independently identified controller mouse-quantization stall; Home alignment repair now passes the complete112.031s route on bc48b2a with all original guards, but establishes no UI cause. Diagnostic-only source bundled, owned scratch and duplicate ELF cleaned. Recovery caller26257272f now observes the same two signal-disconnection messages during second-process shutdown after genuine repair/cold retained walk, not a demonstrated Activity Board transition cause. Popup/removal identity remains unobserved; [exact new boundary](history/ROADMAP_DELIVERIES.md#corrupt-repair-caller-accepted-shutdown-gate-open-20261026). No UI runtime fix/probe selected. Pinned source pass identifies matching Popup ancestor cleanup; empty native callable formatting does not prove dead target. Concrete Popup instance/path and connection-removal order remain BLOCKED runtime facts—Codex; [source boundary](history/ROADMAP_DELIVERIES.md#popup-parent-connection-source-boundary-20261026). No patch/probe/replay selected and no repeat source survey needed. Full Convoy84222cbea now emits the same two root-Window messages after normal Quit request, with paid escort/strict home/exit/walk reached. Concrete Popup/cause remains unknown, not established as the Activity Board producer; [actual shutdown result](history/ROADMAP_DELIVERIES.md#convoy-full-route-shutdown-parked-20261026). | Original ordinary Activity Board transition leaves enabled visible focus and zero signal-disconnection diagnostics; reproduce exact popup/connection owner before repair. |

### Station, fleet and combat children

Walking proof: complete the named ordinary walk/Interact route without rescue and preserve clearance. Service-motion proof: readable/safe implemented rail during walking/boarding. Craft acceptance: walk/board/launch, applicable role/weapon, damage/recovery, strict landing/exit/reuse and cross-craft/Main re-entry. Eventual fleet is **17**, of which nine are implemented and eight originals lack definitions. No “finish craft” implementation assignment is authorized by an acceptance row.

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| WALK-CENTRAL | Central launch/return | 7,9 | Qualification | DONE by reuse of accepted packaged7997b2b37: same Player supported walk/actual Torrent boarding/Guided launch-marker crossing/native home assist/exact Central dock/current lease/90neutral OFFLINE ticks/physical exit/supported0.969437m return/normal UI OS0. Whole retained Race journey276.690s under original300, no diagnostics; no new engine run. Recorded Linux/Xvfb OS-input scope only; station art/other branches/device/native/final remain separate. [Coverage and exact records](history/ROADMAP_DELIVERIES.md#central-station-accepted-proof-reused-20261025). | [Station](#proof-core): same Player walk/board/marked launch/home assist/strict dock/OFFLINE exit/return. |
| WALK-AFT | Aft stairs/door/board | 7,9 | Qualification | PARKED / NOT_ACCEPTED; original27fbcc1 furniture failure retained. Source-bounded continuation5c7cfee/06ce015 exercised all eleven lower walking goals and actual Board open/UI close, but trials39.469s/39.135s stopped at resume receipt checks. Real frozen Player epoch1395 is newer than last unpaused observed1394; next resumed epoch is fresh1413. No engine diagnostics; all input/helper/game/Xvfb cleanup flags pass. Candidate stays unmerged in verified archive/source bundle; main restored and task branch removed. Reopen only with actual paused completed-motion owner via `_life_completed_motion()`, independent source GO/cumulative review; no freshness relaxation/unchanged retry. Original60min:50.915min through cleanup plus final-push cost in closeout; full300/360/15s journey unchanged. [Cause, source and cleanup](history/ROADMAP_DELIVERIES.md#aft-furniture-route-resume-receipt-parked-20261025) | [Station](#proof-core): normal Begin Shift/same supported Player → actual OperationsEntrance E/open → Bay02 Activity Board open/close → physical stairs/upper floor → original parked/OFFLINE Zenith boarding → physical exit/canonical wing-clear return → reverse stairs/hub → normal UI quit/OS0. No jump, teleport, rescue or console proxy; CAP300/outer360 and original per-leg bounds. |
| WALK-HABITAT | Ordinary hub→Habitat rest/wake/common room→hub plus usable restart controls | 7,9 | Qualification | DONE in recorded ordinary scope; LOOP archive3707bc9 and RESTART archive29abe94. Final dressing/native/final-source gates remain separate; parked Sandbox unchanged | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-HABITAT-LOOP | Fresh normal Start Shift, hub→door→bunk sleep/wake→common room→same hub | 7,9 | Qualification | DONE packaged3707bc9: actual archive ELF OS-XTest full route54.259s/163.231m, exact reservation/wake/commons/support/hub return, same Player. No scenario placement; hardware/final-source scope stays separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-HABITAT-RESTART | Normal quit while resting, distinct process with same data, fresh awake supported controls | 7,9 | Qualification | DONE packaged29abe94: two normal UI exits/exit0, same actual data/distinct PID, fresh supported look/walk/tractor interaction68.756s under singleCAP300. No station pose or OS-kill claim; exact continuation below | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HABITAT-BUNK-REST | Six production Habitat bunks offer actual local SLEEP/WAKE with supported return and lifecycle cleanup | 7,9 | Capability | DONE; packaged221f523. Six StationSeat-based bunks, focused134/full spine/Habitat/ship sleep checks and paired startup pass; no saved station pose or ship/recovery/network authority expansion | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-FREIGHT | Full Freight terminal/door/room/conserved-transfer/receipt-reload/same-ship return | 7,9 | Qualification | Interface delivered509703300/checkpoint5097033; full ordinary route remains GATED on its frozen route and existing cold KIT-RELOAD failure. Automatic workflow approved2026-10-21. Existing Jovian automatic cargo delivery remains accepted in its own scope; KIT-RELOAD remains PARKED. [Concrete ordered handoff](#freight-terminals--physical-interface-and-existing-transfer-owner); no route selected | [Station](#proof-core): complete terminal/door/room/delivery, cold committed receipt and same-ship supported return; KIT-RELOAD prerequisite. |
| FREIGHT-TERMINAL-INTERFACE | Ordinary Freight terminal interaction bound to actual conserved cargo owners | 7,9,13 | Capability | DONE on509703300/checkpoint5097033: both actual-Main raw-E fittings, initial/saved/depleted/current-owner/re-entry/refusal checks and existing conserved/once-only cargo suite PASS; paired checkpoint/startups PASS. Existing6-kit source/berth capacity64/two-kit entitlement retained; full ordinary walk and cold KIT-RELOAD remain separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-FLEET | Fleet Dock access and all-shipped berth reuse, shared with CRAFT-ACCEPT | 7,9 | Container | BLOCKED definition (Codex): ordered physical access/exit/reuse paths and existing driver for Torrent, Arrow, Jovian, Zenith, Halyard, Bulwark, Cinder Light, Cinder Hauler and Cinder Bomber; exact comb/neighbour clearance poses and final package. Reuse accepted craft journeys once; no new roster or matrix. | The nine current craft pass approach/current seat/home exit/fresh use through their [existing craft journeys](#fleet-access-and-reuse--shared-acceptance-boundary); exact missing route/clearance/candidate fields are in State. |
| WALK-ANNEX | Fresh normal hub→Annex console→hub with one actual restock | 7,9 | Qualification | DONE source9af57671d;81.387s, same supported Player, kits5→6/one Annex update/Aft unchanged, disclosed pre-walk craft/repair fixtures; no whole-station closure | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-OBSERVATION | Observation supported return | 7,9 | Qualification | OPEN/unqualified. Privatebae551d58 full route PASS54 goals/345.753m/60-frame view/home/normal Exit0/clean logs, but active-tooltip repair INCONCLUSIVE: original visible TooltipPanel not exercised. Later actual-Main baseline did not produce it. Candidate remains unmerged; all five unique commits/seven files preserved by verified bundle/patch/source archive and pushed archive/withheld/exit-tooltip-order-20261020; local/remote/tracking working refs deleted. Missing actual hover owner/pointer/window/foreground state and original visible tooltip/root bindings before a separately selected repair. Full integrated route acceptance retained. [Accounting](history/ROADMAP_DELIVERIES.md#tooltip-candidate-accounted-and-archived--unqualified--2026-10-20) | Integrated-source normal hub/Annex/Observation physical viewing route and supported hub return/normal exit; withheld private pass is not integration. |
| WALK-SALVAGE | Salvage three-component manifest | 7,9 | Qualification | DONE in recorded current Linux-source ordinary scope: ACCESS9749f742c, INSPECT5189436f1, REVISITf7abac379. Actual hub approach/three grades/real-file publication/distinct-process restore/physical repeats/full retained-hub return accepted; original limits retained. Existing staged/memory-store checks remain separate; production Boot/OS-XTest/native/final-package gates remain. [Complete scope](history/ROADMAP_DELIVERIES.md#existing-salvage-durable-physical-revisit-qualified--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-SALVAGE-ACCESS | Hub→three inspection positions→hub by same supported Player | 7,9 | Qualification | DONE9749f742c: all29outbound/29reverse goals and retained hub spawn;64assertions/103.697s/exit0, clean logs and unchanged inspection state. Two added existing-floor waypoints clear Annex roof columns; every original destination/.20arrival/240loops/4settle/300s retained. Source merged/pushed, owned scratch cleaned; prior121.841868s failures preserved. Source qualification via InputEvent/held actions, not OS-XTest/nativeGPU or publication/revisit. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-access-round-trip-qualified--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-SALVAGE-INSPECT | Ordinary three components and manifest publication after actual approach | 7,9 | Qualification | DONE5189436f1: full normal hub approach, all3 actual inspections/authored grades and manifest via ordinary controls, independent real-file primary loads/exact slot/unrelated-data conservation, repeat console adds no transaction, all29reverse goals/retained spawn.92assertions/103.609s/OS0/cleanlogs; original .20/240loops/4settle/300s retained. Reviewed/merged/pushed, owned scratch cleaned. Source qualification only; fresh-process REVISITf7abac379 accepted separately. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-inspection-and-publication-qualified--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-SALVAGE-REVISIT | Durable fresh-process physical revisit without duplicate transaction | 7,9 | Qualification | DONEf7abac379: exact accepted writer real XDG profile in distinct Godot process; primary3IDs/manifest read before Main; fresh normal Main restores them, normal recovery exit directly confirmed, ordinary walk back to retained hub then all29out/4physical repeats/29reverse/spawn. Every repeat preserves actualprimary payload/generation/grades; finalslot conserved.94assertions/107.025s/OS0/cleanlogs/.20/240loops/4settle/300s unchanged. First36.348s failure retained; one source-supported caller correction, no profile/recovery bypass. Reviewed/merged/pushed, owned scratch cleaned. Source qualification, broader Boot/native/final gates separate. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-salvage-durable-physical-revisit-qualified--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WALK-VIP | VIP reception | 7,9 | Qualification | PARKED; BLOCKED definition (Codex): recover the retained failed reception caller/source/result, exact first failed predicate and causal reopening condition; bind normal hub → actual reception interaction → same supported hub return/normal UI exit, existing route/caps, current candidate and locked boundaries. Any missing historical permission needs its actual source owner identified; no new access entitlement or unchanged rerun. | The retained complete physical reception route passes its original interaction, floor/support/motion, locked-boundary and normal-exit predicates within its original limits. Before selection Codex records the exact archived command/route/result and reopening cause here; an absent artifact/value keeps this row PARKED/BLOCKED. “Evidence-permitted” alone is not an acceptance predicate. |
| LIFE-TOW | Central tow during nearby walking/boarding | 9 | Qualification | DONE in packaged9162fac/caller11c2332 ordinary scope:43.086m supported walking/five goals, actual Torrent boarding and90seatedframes; same service/seven movers advance clock/poses,745 consecutive samples, zero diagnostics. Rendered readability/native hardware/whole-station remain separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| LIFE-GANTRY | Freight gantry during nearby walking/boarding | 9 | Qualification | DONE packaged2df8c31 ordinary scope:127.445m/13 settled goals,12.509m local walk/max10.297m from gantry, actual Jovian boarding/90seatedframes; same two movers clock/poses, home berth/OFFLINE/parked,1,668 consecutive samples/no diagnostics. Seat is distant; rendered/full-station/final remain separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| LIFE-ARM | Aft service arm during nearby walking/boarding | 9 | Qualification | DONE packagedf2bf35a:15 settled goals/108.091m,18.303m local walk/max11.711m arm distance, actual Zenith boarding/90seated;1642 consecutive samples/three actual movers/current home/OFFLINE/parked. One actual controller step proof replaces unsupported blanket-speed assumption without changing ordinary bound/physics. [Original failures and accepted full result](history/ROADMAP_DELIVERIES.md#aft-service-arm--actor-proven-ordinary-route-accepted) retained; rendered/hardware/full station separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| LIFE-PATROL | Habitat patrol during nearby walking/boarding | 9 | Qualification | DONE packaged ea8fe43:22 settled goals/171.602m,17.302m local/max9.944m origin distance, actual same-door candidate/E/OPEN-clear/return and distinct Torrent E→BOARDING/90seated. Same two actual drone roots/seed/defaults/home/OFFLINE/parked,2428 consecutive samples; all77Python/package/startups/audit/ONEroute PASS first attempt. [Frozen contract/full result](history/ROADMAP_DELIVERIES.md#habitat-patrol--ordinary-door-walking-and-torrent-boarding-accepted). Rendered/hardware/full station separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| STATION-RELATIONS | Name unresolved historical adjacency/elevation/ladder relationships | 9,36 | Definition | BLOCKED input — Codex records source anchors for only the existing adjacency/elevation/scale/version/ladder claims; the user supplies missing evidence/access or approves explicit interpretation. No new topology claim is implied. | One finite record of unresolved adjacency/elevation/scale/version/ladder claims, each with source anchors or exact missing evidence/interpretation decision. |
| STATION-CENTRAL-VIEW | One fixed current Central operational-view review and any resulting repair | 9,12 | Qualification | PARKED capture prerequisite remains. Before selection Codex binds one player-height view/source and its visibility/clearance criteria from the existing station roster. No assumed defect or unchanged capture retry. | Inspect that one frozen view: close as explicit inspected no-finding, or name and repair its actual defect with same-view before/after and unchanged walk/flight/collision clearance. Either result closes this view only; no capture-timeout exemption or new sweep. |
| STATION-FINDINGS | Finite remaining presentation/living-station findings | 9,12 | Container | BLOCKED definition (Codex). One selected existing branch/view per 15–30 minute definition: fix the exact Fleet berth or Observation pad where relevant, supported camera pose/height, renderer/quality/resolution/scale, image size and literal text/access/clearance predicates. Reuse accepted views; Habitat and other parked captures require their existing causal reopening conditions. The [2026-10-26 capture binding pass](#station-presentation--finite-review-boundaries) maps all13 subjects and records exact absent fields; reuse it, with no automatic successor survey or capture. | Definition finished: closed required-view list for Central/Aft/Habitat/Freight/Fleet/Annex/Observation/Salvage/VIP and tow/gantry/arm/patrol, referencing existing capture inventory once; each view has the listed literal pose/render/text/access/clearance fields. Outcome accepted: every listed view is inspected with no finding or its named defect is repaired/dispositioned with same-view proof. A missing-input record leaves definition and outcome BLOCKED; it ends only the current bounded attempt. One reviewed view cannot close the container. |
| BOMBER-ROLES-DEFINE | Bomber promised crew/navigation versus actual supported roles | 4,10,16 | Definition | DONE; pilot/payload implemented, additional crew/Nav semantics missing | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| BOMBER-ROLE-DECISION | Choose additional Bomber role/count, action and physical access | 4,10,16 | Decision | WAITING; precise interpretation needed, no approved scope reduction | Recorded exact additional role/count/action/physical-access contract; pilot-only runtime is not scope reduction. |
| CRAFT-GAPS-TORRENT | Torrent remaining authored components/roles | 10,11 | Definition | Definition DONE: no concrete required missing implementation found in bounded owners; craft acceptance OPEN, supported finding needed for implementation | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-ARROW | Arrow remaining authored components/roles | 10,11 | Definition | Definition DONE: finite authored capability map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role found in bounded owners. Full craft/art/combat acceptance OPEN; exact product finding needed for repair. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-JOVIAN | Jovian remaining authored components/roles | 10,11 | Definition | Definition DONE: finite authored capability map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role found in bounded owners. Full craft/art/combat acceptance OPEN; exact product finding needed for repair. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-ZENITH | Zenith remaining authored components/roles | 10,11 | Definition | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-HALYARD | Halyard remaining authored components/roles | 10,11 | Definition | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-BULWARK | Bulwark remaining authored components/roles | 10,11 | Definition | Definition DONE: finite capability/physical-role map in COMPLETION_SCOPE.md; no concrete new required missing runtime component/role established. Full craft/art/combat/crew qualification and recorded parked gates remain OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-CINDER-LIGHT | Cinder Light Interceptor remaining authored components/roles | 10,11 | Definition | Definition DONE: finite authored pilot/weapon/component map in COMPLETION_SCOPE.md; no concrete new required runtime/physical-role gap found. Full craft/art/combat/ordinary package acceptance OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-CINDER-HAULER | Cinder Cargo Hauler remaining authored components/roles | 10,11 | Definition | Definition DONE: finite hull/cabin/roles/travelling-weapon map with conserved Hauler cargo delivery now qualified99f2717ee through the complete ordinary package journey. Full craft/art/combat/crew/cold/repeat acceptance remains OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CRAFT-GAPS-CINDER-BOMBER | Cinder Long-Range Bomber remaining authored components/roles | 10,11 | Definition | Definition DONE: pilot/payload/component map; additional crew/navigation decision and exact spent-payload policy now permits refill when pilot retakes seat; additional role remains unresolved. Full craft/art/combat/crew/recovery OPEN. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HAULER-CARGO-DEFINE | Name Hauler-specific conserved cargo play | 10,13 | Definition | Definition DONE; owner chose conserved shared Jovian/Hauler stock2026-10-21. Access/manifest retained and full ordinary HAULER-CARGO-DELIVERY now DONE99f2717ee in packaged Linux/Xvfb OS-input scope. Cold inventory/repeats/full craft remain separate. [Complete journey](history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-accepted-20261025). | Record the Hauler ordinary conserved shared-stock transfer/receipt/cold-reload journey and its existing owners; shared-custody policy is already settled. |
| BOMBER-REARM-POLICY | Permitted spent-payload replenishment boundary | 10,11,31 | Decision | DONE in the recorded decision/ordinary-entitlement scope; settled2026-10-21: refill4 whenever pilot retakes seat. Entitlement DONE4a0d82bff actual ordinary depletion/refusal/physical reboard newer generation4/fresh projectile3. Observed post-retake presentation refusal repaired255f8df2b/checkpoint255f8df below; no explicit-service-only change. | Already decided/proved: physical pilot retake refills4 after depletion/refusal, fresh release3; preserve4a0d82bff/255f8df scope, no redefinition. |
| WEAPONS-DEFINE | Actual craft/role to weapon acceptance roster | 11 | Definition | Definition DONE on a0d446645; current binding map in WEAPON_DEFINITION_CONTRACT.md, finite distinctions below. No missing runtime weapon type inferred; eight originals UNKNOWN/Bomber role decision retained | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| DAMAGE-DEFINE | Uncovered craft/role component-damage/recovery cells | 11,21 | Definition | Definition DONE on82a7564cb; COMPONENT_DAMAGE_MODEL_CONTRACT.md maps five IDs/all nine craft, real role exceptions, repair/reset owners and concrete remote row gap; no gameplay pass | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ART-FINDINGS | Finite actual UI/animation/effect/lighting/terrain/weather defects | 12,15 | Container | BLOCKED definition (Codex): reconcile the existing 13 capture sets/143 images and original fleet/world/character/effect/UI obligations against accepted coverage. Name each uncovered original clause and subject/state; bind source, camera, renderer/quality/resolution/scale and same-view comparison criteria. The station roster is only a referenced subset, not the contract for non-station art. Stop after this finite coverage answer or a field-level missing-input record; no capture or runtime change is selected. | Definition finished: one closed coverage list of the existing13 capture sets/143 images and original fleet/world/character/effect/UI views, each mapped to accepted proof or literal missing subject/state/pose/render/inspection fields. Outcome accepted: every listed view has inspection and disposition, with each real defect repaired under the stated same-view and gameplay/clearance conditions. A missing field keeps the definition BLOCKED; recording it ends only that attempt. One review closes one view; one repair closes one defect. Empty areas or unavailable pictures do not authorize new art requirements. |
| CRAFT-ACCEPT-TORRENT | Torrent full solo craft loop | 7,10,11 | Container | Return/reuse capability DONE5d2c58dba: packaged ordinary Guided plus fresh same-Torrent boarding/departure/two strict homes/90neutral-OFFLINE ticks each/physical exits/supported walks/normal UI OS0,85.267s under300s. [Accepted scope](history/ROADMAP_DELIVERIES.md#torrent-return-reuse-capability-accepted-20261025). Incoming core-damage/passive repair also DONEa1de3363f: real source2101 hit/hull89/core.56/targeting.62,617airborne observations,43strict passive commits/all nominal/hull89 retained and full two-home continuation88.168s/OS0. [Exact scope](history/ROADMAP_DELIVERIES.md#torrent-core-damage-passive-repair-accepted-20261025). Physical Torrent→Arrow→Torrent handoff/reclaim also DONEdriveraf38de143/package6fe51dca4: actual current-source E consumers,90neutral-OFFLINE ticks per seat,supported walks,fresh Torrent stream/normal UI OS0 in131.708s. [Scope](history/ROADMAP_DELIVERIES.md#torrent-arrow-physical-handoff-accepted-20261025). Shared retained Main source resource/combat lifecycle also DONE79dc473a5: unchanged existing three-cycle72-assertion check passes70.113s/OS0/zero diagnostics, including Torrent1101/hull/replay/queues/node/resource identity. [Exact staged scope](history/ROADMAP_DELIVERIES.md#shared-main-source-lifecycle-accepted-20261025). Full craft OPEN: [remaining fields](#torrent-finite-acceptance-coverage-and-missing-ordinary-route) for applicable damage/destruction/recovery and full-route/final-candidate command/limits; Arrow flight/weapons and explicit component/seat contracts are not supplied by these scoped checks. No new matrix or unchanged replay selected. Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Retain the exact accepted return/reuse, core.56→1 passive repair, physical Torrent→Arrow→Torrent and shared retained-Main cases in [Torrent’s finite binding](#torrent-finite-acceptance-coverage-and-missing-ordinary-route). Remaining original-required component stages/loss and final candidate cases need the exact actor/trigger/expected consequence/ordinary route/source/cap stated above; one repair case does not prove every component or fatal recovery. |
| CRAFT-ACCEPT-ARROW | Arrow full solo craft loop | 7,10,11 | Container | Ordinary return/reuse DONEed1167b; named pilot precision-hit plus preserved two-flight home/OFFLINE exits/clear/reboard/UIquit DONE51257b3, actual archive120.991s. [Accepted scope](history/ROADMAP_DELIVERIES.md#arrow-precision-hit-and-return--shipped-on-51257b3). Broader combat/damage/recovery/crosscraft/Main/art/device/final acceptance remains GATED; no Sandbox/Defense closure. Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Qualification container: pilot precision/recon handling and the existing single24damage hit; preserve the accepted two-flight returns. |
| CRAFT-ACCEPT-JOVIAN | Jovian full solo craft loop | 7,10,11 | Container | WEAPON-JOVIAN PARKED after one authorized caller correction:13Gantrygoals/90seat and first actual8.22285m/free-lease departure pass; frame2210 moves1.753796m above original1.603333m bound. No clearance waypoint/shot/home/reuse/UIOS0. Driverc148/game7af source pins differ; failed source stays unmerged. Motion owner/cause unknown; no next correction or retry selected. Original23:40→01:10UTC/90min cumulative clock retained. [Frozen contract and both attempts](history/ROADMAP_DELIVERIES.md#jovian-cannon-departure-parked-and-linux-archive-modes-fixed-20261027). Separate engineer journey remains parked. Ordinary solo spawn→engineer repair→hub attempt PARKED/NOT_ACCEPTED2026-10-25 after2actual trials. Corrected1530b4fc8 reaches17outbound physical goals/chair, acceptedportrepair/integrityimprovement/6→5/437ms/HUD5, then fails stand-retirement aggregate. Candidate incorrectly requires empty released authority still attached; production detaches it. Actual post-stand members unlogged. Fullreverse/hub/normalUI0NOT_RUN; no third under this card. Both sources/raw/STOP archived, candidate excluded from main/branch removed. Future selection needs predicate bound to existing detach contract+preassertmember receipts, independent source/cumulative review, originalfullroute/limits retained. Full craft remains a qualification container; other ordered role/function/damage/recovery/switch/Main route bindings still required. [Exact stops](history/ROADMAP_DELIVERIES.md#jovian-ordinary-engineer-two-stops-20261025). | Jovian completion container for the listed physical steps plus the complete craft contract. The next definition ends with proof/route/limit for every step or the exact missing artifact/decision and owner. A future bounded implementation changes one demonstrated missing behavior; this row closes only when the whole required journey is accepted. |
| CRAFT-ACCEPT-ZENITH | Zenith full solo craft loop | 7,10,11 | Container | OPEN container; [finite11member binding](#zenith-finite-acceptance-binding). Retain DONE ordinary pilot/real28hit/two strict homes/fresh reuse/normalOS0 Game4bf5e889/Driver4870595fa in the [accepted scope](history/ROADMAP_DELIVERIES.md#zenith-pilot-hit-home-reuse-accepted-20261026). Settled retained-Main DONEa70f9397a in its [staged scope](history/ROADMAP_DELIVERIES.md#zenith-settled-main-reentry-qualified-20261026). Full physical cross-craft handback DONE Game499e681/Driver8ba86d98e:162.917s/42walkinggoals/mandatoryactualGuided/strictTorrenthome/OFFLINE/exit/sameZenithfresh90neutral/normalHUDOS0/bothrealcleanmarkers/diag0. Stream5→retired7→reclaim9; later10afterreceipt. [Exact proof/fourfailedtrials/limits](history/ROADMAP_DELIVERIES.md#zenith-torrent-handback-accepted-20261026). Focused physical stair repair1f7dccb remains accepted in its [recorded scope](history/ROADMAP_DELIVERIES.md#aft-stair-base-supported-contact-accepted-20261026). Remaining original component consequences/passive repair, loss/regeneration and current art/device/final bindings stay OPEN/BLOCKED definition as listed above; no missing handback or Main selector and no unchanged replay. Full craft is not DONE. | All members of the [finite binding](#zenith-finite-acceptance-binding) satisfy the [complete craft journey](#proof-craft) on the bound candidate, with original limits and retained failures. No extra crew, invented historical handling, craft×case matrix or unchanged parked replay. |
| CRAFT-ACCEPT-HALYARD | Halyard full solo craft loop | 7,10,11 | Container | Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Qualification container: pilot plus physical passenger/gunner/engineer/Loadmaster claim/action/stand/reseat; retain the accepted52damage gunner case. |
| CRAFT-ACCEPT-BULWARK | Bulwark full solo craft loop | 7,10,11 | Container | Source acceptance binding recorded below; full journey BLOCKED definition (Codex) on the listed exact inputs/routes/candidate/limits: ordinary Dock03 access/pilot flight, OFFLINE cabin stand→seated weapon-power wake→gunner hit/release/reseat→pilot reclaim, concurrent moving-crew ownership handback, five-component consequences/passive repair, loss/regeneration, strict home/exit/reuse, Torrent handback and retained Main. Exact missing native inputs/routes/candidate/receipts/deadlines are assigned per member; f676c5016 reused only for its recorded host+one-client/staged scope. No new run, whole-loop pass or extra physical role. Selected member: [ordinary solo gunner journey](../ROADMAP.md#execution-now) — physical Dock03 admission/actual outward drift/carried aisle/real22-hit/fresh gunner reseat/pilot reclaim/strict home/normalOS0 and real clean files. PARKED after six failed ordinary trials; latest96197bf failed the outward15s bound after101.287s, and its final wrapper source guard also failed after a concurrent documentation edit. No accepted gunner journey or new checkpoint. Reopening requires the demonstrated outward-failure cause, bounded correction, independent cumulative-priority decision and clean frozen source; see the selected card for cumulative cost and retained source/raw. Separately, the reproduced carried-floor runtime repair is accepted in checkpoint30534f5: [actual captured regression and package proof](history/ROADMAP_DELIVERIES.md#carried-cabin-floor-contact-accepted-20261026); this does not close the parked journey. All remaining full-craft bindings stay open. | [Bulwark finite acceptance binding](#bulwark-finite-acceptance-binding) preserves every [complete craft journey](#proof-craft) member and the physical gunner real-damage/release/reseat requirement. |
| CRAFT-ACCEPT-CINDER-LIGHT | Cinder Light Interceptor full solo craft loop | 7,10,11 | Container | WEAPON-CINDER-LIGHT member PARKED: first full run canonical-race comparison fails after15walk/90seat/12mlift; one exact-codec correction then fails its component float-pair assertion before export/second native. No firing/home/reuse/UIOS0. [Both stops/full retained contract](#cinder-light-two-pulse-weapon-and-returnreuse--frozen2026-10-27). Six candidate files remain unmerged/verified archived; owned branch/worktree/process/scratch cleaned. No third attempt or further correction selected; exact fixture values/representation proof remains missing. Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Qualification container: pilot specialist handling, actual repeater cadence/cooldown and component consequences. |
| CRAFT-ACCEPT-CINDER-HAULER | Cinder Cargo Hauler full solo craft loop | 7,10,11 | Container | Conserved cargo delivery DONE99f2717ee; full craft remains GATED on remaining actual weapon/role/damage/recovery/reuse/cross-craft/Main/art and final-source acceptance. One delivery does not close this journey. Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Qualification container: pilot/ramp, conserved shared-stock delivery, travelling mass-driver impact and physical Loadmaster/Navigator actions. |
| CRAFT-ACCEPT-CINDER-BOMBER | Cinder Long-Range Bomber full solo craft loop | 7,10,11 | Container | Qualification container; BLOCKED definition (Codex): exact ordered role/function, nonfatal/failed-component/repair, fatal-recovery, switch partner/handback and retained-Main members; ordinary driver/route/start-stop/original limits and accepted proof reused per member. No craft×case matrix. | [Complete craft journey](#proof-craft), plus this craft-specific result: Qualification container: pilot four-round payload hit/miss/depletion, refusal while empty and refill4 on physical pilot retake; extra crew waits on BOMBER-ROLE-DECISION. |
| SPEC-TITAN | Titan evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern pilot/two-passenger/four-inert-parcel utility transport proposal](design/TITAN_IMPLEMENTATION_PROPOSAL.md); numeric geometry/16fields/functions/custody-recovery fixed, owner interpretation/design choice pending. No runtime or craft delivered. | Titan: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-TITAN | Titan named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-TITAN; 13 bounded [draft production/package cards](design/TITAN_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed. Adopt against actual owner choice; do not repeat definition. | Titan: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-TITAN | Titan full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-TITAN](design/TITAN_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-TITAN → implemented BUILD-SPLIT-TITAN capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-VORTEX | Vortex evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. WAITING owner interpretation/design choice. [Decision-ready modern proposal](design/VORTEX_IMPLEMENTATION_PROPOSAL.md) prepared2026-10-25: pilot+4physicalpassengers/10×20×5m originalhull/continuoussternaccess/exacttrialtuning/reusedpilotcannon/no cargo-specialists/safeonfootrestart/14boundedcards. Rootsource/seam/contractreviewdone, no runtime/engine/build; A3name-role only/B4label-only/modelUNKNOWN. Proposal preparation is not SPEC completion or approval.  Proposed drag revised1.8→1.85 to meet14 differing source axes versus Bomber; still unapproved and not a runtime pass. | Vortex: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-VORTEX | Vortex named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED SPEC-VORTEX owner approval;14draft runtime/package cards already in [proposal](design/VORTEX_IMPLEMENTATION_PROPOSAL.md). Adopt/amend against accepted SPEC before implementation; do not repeat definition or call draft cards accepted construction. | Vortex: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-VORTEX | Vortex full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-VORTEX](design/VORTEX_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-VORTEX → implemented BUILD-SPLIT-VORTEX capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-PARADOX | Paradox evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern pilot/gunner/passenger cruiser proposal](design/PARADOX_IMPLEMENTATION_PROPOSAL.md); owner interpretation/design choice pending; no runtime implementation | Paradox: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-PARADOX | Paradox named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-PARADOX; 16 bounded [candidate cards](design/PARADOX_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed | Paradox: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-PARADOX | Paradox full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-PARADOX](design/PARADOX_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-PARADOX → implemented BUILD-SPLIT-PARADOX capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-KATANA | Katana evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern single-pilot braking fighter proposal](design/KATANA_IMPLEMENTATION_PROPOSAL.md); owner interpretation/design choice pending; no runtime implementation | Katana: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-KATANA | Katana named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-KATANA; 13 bounded [candidate cards](design/KATANA_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed | Katana: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-KATANA | Katana full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-KATANA](design/KATANA_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-KATANA → implemented BUILD-SPLIT-KATANA capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-PREDATOR | Predator evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern unarmed pilot/guard/voluntary-detainee cell transport proposal](design/PREDATOR_IMPLEMENTATION_PROPOSAL.md); owner interpretation/design choice pending; no runtime implementation | Predator: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-PREDATOR | Predator named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-PREDATOR; 15 bounded [candidate cards](design/PREDATOR_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed | Predator: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-PREDATOR | Predator full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-PREDATOR](design/PREDATOR_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-PREDATOR → implemented BUILD-SPLIT-PREDATOR capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-DYNAMIC | Dynamic evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern single-pilot short-range gunship proposal](design/DYNAMIC_IMPLEMENTATION_PROPOSAL.md); numeric geometry/16fields/functions/custody-recovery fixed, owner interpretation/design choice pending. No runtime or craft delivered. | Dynamic: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-DYNAMIC | Dynamic named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-DYNAMIC; 13 bounded [draft production/package cards](design/DYNAMIC_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed. Adopt against actual owner choice; do not repeat definition. | Dynamic: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-DYNAMIC | Dynamic full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-DYNAMIC](design/DYNAMIC_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-DYNAMIC → implemented BUILD-SPLIT-DYNAMIC capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-UTOPIA | Utopia evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern conserved supply dropship with finite hostile approach proposal](design/UTOPIA_IMPLEMENTATION_PROPOSAL.md); numeric geometry/16fields/functions/custody-recovery fixed, owner interpretation/design choice pending. No runtime or craft delivered. | Utopia: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-UTOPIA | Utopia named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-UTOPIA; 18 bounded [draft production/package cards](design/UTOPIA_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed. Adopt against actual owner choice; do not repeat definition. | Utopia: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-UTOPIA | Utopia full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-UTOPIA](design/UTOPIA_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-UTOPIA → implemented BUILD-SPLIT-UTOPIA capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| SPEC-SALYUT | Salyut evidence-bounded identity/capability specification | 10,36 | Definition | BLOCKED input — user accepts/amends the linked explicit interpretation/design proposal and its fixed specification fields; no research or runtime execution pending that answer. PREPARED/unapproved [modern unarmed pilot/two-passenger transport proposal](design/SALYUT_IMPLEMENTATION_PROPOSAL.md); numeric geometry/16fields/functions/custody-recovery fixed, owner interpretation/design choice pending. No runtime or craft delivered. | Salyut: all fixed [specification fields](#proof-craft), honest evidence label and explicit interpretation/design decision; no ship-completion claim. |
| BUILD-SPLIT-SALYUT | Salyut named hull/handling/access/role/recovery build cards | 10,36 | Definition | BLOCKED input — user approval of the named SPEC; then Codex adopts/amends its already finite linked capability cards against that answer. This row ends at that finite plan; it is not executable ship construction. GATED on accepted SPEC-SALYUT; 15 bounded [draft production/package cards](design/SALYUT_IMPLEMENTATION_PROPOSAL.md) prepared, not approved or executed. Adopt against actual owner choice; do not repeat definition. | Salyut: accepted SPEC expanded into named hull/access, handling, actual functions/weapons, damage/recovery/save/reuse capabilities with files/owner/visible result/proof/estimates; construction still required. |
| CRAFT-ACCEPT-SALYUT | Salyut full craft loop | 7,10,11,36 | Container | WAITING input (user): accept/amend [SPEC-SALYUT](design/SALYUT_IMPLEMENTATION_PROPOSAL.md), including roles/actions, functions/armed-or-unarmed, geometry/access/berth and handling. Codex then binds the actual build and ordered journey/cases/limits; prepared cards are not implementation. | Accepted SPEC-SALYUT → implemented BUILD-SPLIT-SALYUT capabilities → [complete physical craft journey](#proof-craft). Missing product values remain with the user; concrete route/case/driver binding remains with Codex. |
| COMBAT-INTERCEPTOR | Initial interceptor pressure encounter | 11 | Qualification | DONE in checkpoint3d92b91 Guided starter-Torrent scope: same original3/3 ordinary route proves actual player fire/defender destruction, physical home landing/shutdown/exit and usable controls. [One shared proof, no duplicate delivery](history/ROADMAP_DELIVERIES.md#guided-checkpoint3d92b91--original-ordinary-route-accepted3of3). Other craft/encounter/damage/recovery requirements remain in their named owners | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| COMBAT-COURIER | Courier Intercept | 11 | Container | NON-EXECUTABLE container — accepted clear/escape/withdrawals retained. Remaining escorted/recovery/repeat membership is BLOCKED definition: Codex must enumerate only the uncovered original cases with trigger/result/route/cap; a generic remaining-case label cannot schedule play. COURIER-WITHDRAW-DISTANCE first full ordinary journey DONE719fe364a; see bounded outcomes. COURIER-ESCAPE also DONE393733212: full103.179s/actualfirstunhurt1400m escape/all-actorstanddown/realdefenderkill/strict home, defaults/caps retained; see bounded outcomes. COURIER-CLEAR first full original journey DONE4196ad0: ordinary route55.973s under300, initial defender alive through actual Courier kill/CLEARED before1400m, then defender defeat and strict home dock/OFFLINE/physical exit. Runtime damage-admission431aae retained; ordinary nonlethal preparation/readiness changes no combat rules. Paired checkpoint/strict startups/1525-entry audit/review GO; merged/pushed/owned cleanup done. [Separate bounded outcomes](#courier-intercept--bounded-outcomes) retain escorted instances/recovery/repeats/native requirements OPEN; clear, escape and first unhurt phase/distance withdrawals keep their recorded scopes, full parent not closed | [Combat](#proof-combat): retain clear/escape/withdrawal passes; finish only named remaining escorted/recovery/repeat outcomes, real terminal result and usable home. |
| COMBAT-WING | Paired Wing Break | 11 | Qualification | FAILED/open ordinary two actual player-weapon kills plus complete home/OFFLINE physical exit/UIquit. Latest9a68aa01f trial102.037s:8shots,0Wingdamagehits/kills, both opponents38health; prerequisite Heavy/Torpedo home journeys pass. Unique diagnostic source archived under pushed tag `archive/diagnostics/wing-ordinary-route-20261020`; branch/worktree removed, observer/selector/driver excluded from main. Independently accepted board-landing withdrawal fix shipped9e9d1be; it does not complete Wing combat. [Closeout](history/ROADMAP_DELIVERIES.md#wing-branch-accounted-landing-fix-shipped--2026-10-20) | Two real live Wing opponents destroyed by ordinary player weapons, then strict home/OFFLINE physical exit/normal UI completion; admission alone insufficient. |
| COMBAT-WING-ADMISSION | Existing Wing becomes a genuine third solo board contract | 11 | Capability | DONE checkpointf671da9: on-foot arm/cancel, physical departure/registered source gate, real suppression/flank pair, solo/network refusal, both-destroyed objective with healthy-retirement abort, correct HUD/audio/no-credit lifecycle. Actual Main28/director151/board59/HUD8/audio11 checks, paired exports/startups/audit PASS. Component simulated clear disclosed; no full ordinary kills/home. [Result](history/ROADMAP_DELIVERIES.md#paired-wing-board-admission--shipped-on-f671da9) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| COMBAT-PERIMETER | Perimeter Hold | 11 | Container | NON-EXECUTABLE container — ordinary90s/>35% survival/home is one finite case; additional failure/recovery membership is BLOCKED definition until Codex records exact original trigger and supported terminal result. Existing delivered runtime/admission stays accepted. Ordinary-driver attempt PARKED317c3b44f: first Heavy withdrawal/home and actual saved Torpedo posting pass; fresh-selection E correction reaches second Arrow/Torpedo, then sole L fails to start landing. Nonqualifying diagnostic successfully traces both landing inputs; prior failure NOT_REPRODUCED, product cause unproven. No third qualifying trial selected; both failures/source/data retained, CAP300/original clock unchanged. [Exact stop](history/ROADMAP_DELIVERIES.md#perimeter-ordinary-route-input-stop-20261025). PERIMETER-LIVE runtime/admission DONE fdae1cb: physical fourth-board contract, protected core/three live attackers,90s/>35%, HUD and lifecycle. Actual-Main admission, retained Breach recovery, staged objective and paired packages PASS; branch merged/deleted. Full ordinary weapon/home, failure/recovery, repeats/network/native remain OPEN. [Delivery](history/ROADMAP_DELIVERIES.md#perimeter-live-branch-finished--2026-10-20) | Real protected core survives90s with >35% through ordinary live combat, its no-credit terminal result/home/usable continuation; named failure/recovery also resolved. |
| COMBAT-BREACH | Heavy Breach | 11 | Qualification | First full ordinary charged-picket kill/payment/home sortie DONEfb396ab13, exactly the PLAY-BREACH proof below, counted once. Remaining craft journeys belong to the 17 CRAFT-ACCEPT rows; replicated hull/component outcomes belong to NET-DAMAGE; active Breach restart policy belongs to RECOVERY-POLICY-BREACH and its implementation to the Breach owner in the [existing activity-write roster](#activity-write-boundary-roster--act-writes-define). These do not create additional unnamed COMBAT-BREACH cases. BREACH-INTERRUPTION earned-debt case DONEc78e0ac. No full combat-parent closure. | Same actual full sortie as PLAY-BREACH; one proof serves both parents, no duplicate job. |
| COMBAT-TORPEDO | Torpedo Run evade/intercept/destroy/fail/abort | 11,23 | Container | NON-EXECUTABLE container — PLAY-TORPEDO owns clear/home once; remaining evade/intercept/fail/abort/solo-restoration cases require Codex to bind the existing ten-case TORPEDO-AUTH contract to exact ordinary routes, triggers and results. Missing routes/values are BLOCKED definition; no implicit successor attempt. | Actual evade/intercept/boat destruction plus each named fail/abort/restoration outcome; PLAY-TORPEDO supplies its clear/home proof once. |

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
| COURIER-ESCAPE | Actual live runner reaches original boundary with positive hull; director ESCAPED stands down all dispatched actors, then player clears defender and completes home. | DONE393733212: complete packaged103.179s/original300/330, actual85→51→17 preparation (one authenticated harmless-miss retry), firstgen1/unhurt78 courier at1,400.066m/ESCAPED, every actually dispatched actor inactive/unauthorized/no furtherfire through home. Fixed ordinary waitflight max358.837m from actualorigin; physical saved-attack return<=1m/speed.05444 precedes real lethal17 and originalstrict home/lease/OFFLINE/Eexit/error.17/hull59. Actual source/defaults preserved; all game logs clean/owned cleanup complete. Final134 Python/observer/privacy/package/startup/payload audit/review pass; four commits merged/pushed. Initial unconfirmed preparation shot, later disabled-weapon timeout, exact component diagnostic and arrival test failure retained. Full escort/repeat/withdraw/recovery/native/parent gates remain. [Acceptance](history/ROADMAP_DELIVERIES.md#courier-escape--accepted-ordinary-flight-and-home--2026-10-24). |
| COURIER-WITHDRAW-PHASE | With courier actually running, destroy initial defender through real fire; normal RETURN_TO_YARD causes WITHDRAWN and stops courier/escort fire, then complete home. | DONEccfaa63b8 for first unhurt courier instance: full56.522s/original300/330; observedlivegen1 courier1595, actual authoritative player request12 lethal17 at1597 while runnerstillrunning/pending/unhurt78 and phaseRETURN, then WITHDRAWN1598. All actually dispatched1actor inactive/unauthorized/pending0/no furtherfire for865frames through strict occupiedhome/OFFLINE/DISEMBARKING/physicalCOMPLETE/error.17/hull89; max actual-origin radius63.412 rulesout distance. Frozen game081/driverccfaa pair verified; final141 Python and package/startup/payload/review pass. Initial omitted-disembark caller failure retained, two commits merged/pushed and owned cleanup complete. Distance withdrawal is qualified in its own card; escorted instances/recovery/repeats/native/fullparent remain open. [Acceptance](history/ROADMAP_DELIVERIES.md#courier-phase-withdrawal--accepted-live-dispatch-and-home--2026-10-24). |
| COURIER-WITHDRAW-DISTANCE | Remain more than700m from the actual scenario origin and every active roster craft for7 physics seconds while authorized; WITHDRAWN stands down courier/escort, then clear defender and complete home. | DONE719fe364a: first packaged attempt 92.585s/original300/330. Actual origin AND every active craft >700m for 420 consecutive pending physics samples; actual terminal grace7.016667s, WITHDRAWN while authorized with original defender17 and unhurt Courier78/progress59.83%. All actually dispatched actors inactive/unauthorized/pending0/no further fire through 60-frame hold, physical attack return, fresh authoritative defender kill and strict home/OFFLINE/DISEMBARKING/physical COMPLETE/error0.17. Final144 tests, observer/privacy, clean private package/startup/payload audit and independent review PASS; source merged/pushed, owned cleanup complete. Escorted instances/recovery/repeats/native/fullparent remain open. [Acceptance](history/ROADMAP_DELIVERIES.md#courier-distance-withdrawal--accepted-ordinary-flight-and-home--2026-10-24). |
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

Current verified HTTPS heads on2026-10-25 contain **only main** at1c06e5d05;
local branches also contain only main. The earlier20/19/18/17 branch counts below
in [delivery history](history/ROADMAP_DELIVERIES.md#remaining-branch-status-after-duplicate-closeouts--2026-10-20)
are historical checkpoints, not current unfinished working branches. Unique
withheld diagnostic/gameplay attempts retain their documented archives/tags and
reopening conditions; removing a branch did not accept a failed candidate.
Pre-existing detached worktree/archive registrations remain protected until
ownership and unique changes are accounted for; none is silently pruned. Current
work creates no branch/worktree. This correction supplies no gameplay qualification.

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
| WEAPON-JOVIAN | PARKED/NOT_ACCEPTED: corrected caller achieves actual first departure, then frame2210 fails unchanged per-tick motion1.753796m>1.603333m. No clearance waypoint/Fire/target damage/two-home/reuse/UIOS0 proof; no retry selected. | Runtime1103/650m70/.62s and original full route/caps retained. Motion owner/cause remains unrecorded; reopening requires demonstrated causal correction and independent cumulative-priority review, not the already-completed W-departure repair. [Both attempts and original contract](history/ROADMAP_DELIVERIES.md#jovian-cannon-departure-parked-and-linux-archive-modes-fixed-20261027). |
| WEAPON-ZENITH | Actual pilot repeater selection/damage through the common chain | Zenith resource, HeroShip, GameFlow; migration/common combat checks |
| WEAPON-HALYARD | Both pilot and admitted gunner use the same lance/heat/cooldown; real damage beyond a request receipt | Halyard crew consumer and HeroShip; existing gunner gameplay test stops at emitted request; attempted actual-hit extension is parked at ordinary seat admission |
| WEAPON-BULWARK-PILOT | Actual pilot sustained-pulse binding through the common chain | Bulwark pulse resource, HeroShip, GameFlow |
| WEAPON-BULWARK-GUNNER | Charged limited-ammo hitscan, component gates/revalidation and accepted-submission debit | Bulwark crew consumer; bulwark_crew_gunner_gameplay_test.gd; not Picket opponent travel |
| WEAPON-CINDER-LIGHT | PARKED/NOT_ACCEPTED: first full run reaches15walk/boarding/90seat/12mlift then canonical-save/raw-ack mismatch; one approved correction stops in exact-float component regression before any export or second native. No shot/home/reuse/UIOS0 proof. | [Full original contract and both stops](#cinder-light-two-pulse-weapon-and-returnreuse--frozen2026-10-27). Six unmerged source files verified archived; owned branch/worktree/process/scratch cleaned. Missing proof is actual component float values/which combined comparison fails. No further correction/test/replay selected; all cumulative cost retained. |
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

### Cinder Light two-pulse weapon and return/reuse — frozen2026-10-27

**Current status: correction preparation PARKED; no second native attempt.**
One independently authorized exact-codec correction639 passes314Python/import/
privacy, then its new Godot exact-float combined assertion fails (actual fixture
values unlogged). Canonical acknowledgement/raw-preservation/wrong-field checks
pass, but exact pair reproduction stays unproved. No production defect inferred.
[Both stops, original clock and verified cleanup](history/ROADMAP_DELIVERIES.md#cinder-codec-continuation-parked-at-component-regression-20261027).
All six candidate files remain unmerged/archived; owned branch/worktree/process/
scratch cleaned. No further correction/test/export/native is selected under the
closed continuation. The authorization and first full route below remain history.

**Explicit causal reopening2026-10-27 02:19UTC, before restoration/correction.**
Independent high review authorizes one production-canonical acknowledgement
observation/comparison correction and one second full native attempt. This
supersedes the previous PARK/one-attempt restriction only for this cause; all
previous failure/raw/source and43.01minutes stay charged to01:33:55UTC. Original
90minute hard03:03:55 remains; correction readiness02:30/native launch02:35.
No epsilon, Python approximation or field omission: raw acknowledgement remains
unchanged and the observer separately publishes the exact production JSON
round-trip. Actual persisted state must equal that full canonical acknowledgement
with the same writer/receipt/identity guards. Existing tests prove the actual
float pair, raw immutability and wrong-field refusal; changed observer gets fresh
compile/private export/strict startup. No other behavior, route, two18hits, both
flights/home/reuse/UIOS0, namespaces or original300/360/15/25/landing limits change.
One medium implementer owns the restored five files plus existing
cinder_timed_race_session_test.gd; root owns integration/checks/build/cleanup, one
high independent reviewer source/results. No third attempt; next unexpected
failure/missed cutoff/insufficient closure time PARKS. Original record below stays
historical and is not erased.

**PARKED/NOT_ACCEPTED after the one full attempt.** All15 walk goals, actual
boarding/90 seated frames and powered12m lift pass. First A arrival/Fire/home/reuse/
UIOS0 do not. First failure is caller equality between canonical saved elapsed
0.0166666666666667 and raw live acknowledgement0.016666666666666666, despite
accepted production writer. No engine/cannon/save-write defect established.
[Exact raw/source boundary, preserved source and cleanup](history/ROADMAP_DELIVERIES.md#cinder-light-weapon-route-parked-at-canonical-race-comparison-20261027).
No retry selected; full contract below is retained as frozen history, not an
active run authorization. Reopening needs exact production-codec comparison
without epsilon/mutation and independent cumulative-priority review.

**Existing selector WEAPON-CINDER-LIGHT, one member of CRAFT-ACCEPT-CINDER-LIGHT.**
This new ordinary qualification has no earlier selected/parked instance in the
focused record. It does not replace the full eleven-boundary craft journey,
component damage/repair/destruction, cross-craft, art or final-source/device gates.
Original task clock starts2026-10-27 01:33:55UTC, including the completed source
binding; total90minutes/hard03:03:55UTC. Readiness must finish before02:10UTC and
the one full native attempt must launch before02:15UTC. A missed cutoff or first
unexpected failure stops/PARKS; no automatic correction, retry or fresh clock.

**Result/owner/start.** Codex delivers one executable ordinary OS-input caller in
the existing release runner and qualifies the two actual pilot hits plus full
two-flight usable return. One high implementer owns only run_native_sortie.py,
test_native_sortie.py, native_sortie_observer.gd, startup_loader.gd and
startup_cli_privacy_test.gd; root owns this card, exact candidate/build/process
management/integration/cleanup. One independent high reviewer checks source/raw.
Base59b66e32f; clean implementation commit and exact package/hash bind before any
engine. Fresh private profile/default settings, normal Boot title/Begin Shift,
Main/World/Player; no saved cargo/activity/reward fixture, injected poses or states.

**Actual actors/defaults.** `World` below means the live `GameFlow.world`
node, actually `Main/ShipyardWorld`, not an invented sibling. Read its nested
`FleetExpansionProductionBinding/cinder_light_interceptor`, canonical
`cinder_light_interceptor`, home `dock_06_interceptor`. Source-derived nominal
parked root[64,5.26,85.3]/yaw+90°; capture[94,13.26,85.3]; live boarding/exit
[64,4.18,88.15]. Assert actual markers/transform/current berth, never assign them.
Actual source1108/repeater `cinder_light_repeater`:320m/18damage/.28s cooldown,
24m origin tolerance; initial LeftMuzzle[-2.82,.42,-3.42], then RightMuzzle
[2.82,.42,-3.42]. Target is actual moving
`World/ExteriorTargetRange/TargetDrone01`/DRONE-01 with registered adapter, initial
100HP/base[-13,7,-95]. Default hull110, maximum speed102/boost120, thrust32,
brake40, drag3, throttle response9, startup1.8s, yaw85/roll120, flight assist6.4,
mouse turn22°, landing maximum speed18. No damage/tuning/physics/time changes.

**Finite ordinary route.** Normal supported Player walk through these existing
LIFE-ARM/Fleet points, in order (y values remain authored deck elevations):
[0,0,15.5], [0,0,39], [0,0,46.3], [0,0,51], [-5.7,0,51], [-5.7,4.2,61.2],
[-3.5,4.2,61.5], [-3.5,4.2,64.2], [-3.5,4.2,68.3], [6,4.2,68.3],
[13,4.2,68.3], [22,4.2,68.3], [56,4.2,68.3], [56,4.2,live_boarding.z],
then live boarding. Ordinary E/current reservation/pilot admission,90 seated
neutral frames at the exact occupied OFFLINE berth. Do not reuse Zenith identity.

For EACH flight, ordinary W must first exercise actual Dock06 departure lift:
observe `_departure_lift_active`, its live origin/up/height12, actual positive
consumed thrust/ONLINE/free lease/non-landed motion; wait for lift inactive AND
actual rise>=11.99m (Hero's source completion tolerance.01). An inactive blocked
lift below that height fails. Only then steer through the finite route below.
These transit points are new engineering selections, not previously proven safe.
Default handling, collision and clearance must actually pass on the one attempt.

| Ordered flight point | World position / required operation |
| --- | --- |
| A: lifted forward departure | dock*(0,12,-20), nominal[44,17.26,85.3] |
| B: raised departure lane | [44,50,85.3] |
| C: raised range lane | [22,50,-24.7] |
| D: weapon lane | [22,25.28,-24.7]; brake to<=.35m/s. Flight1 performs exactly two shots; flight2 never fires |
| Return C, then B | Same fixed raised points, in that order; both arrivals required |
| E: raised capture approach | [94,50,85.3] |
| H: live home capture | live capture, nominal[94,13.26,85.3]; brake, then exactly one ordinary L |

Waypoint arrival/braking uses the existing Arrow/Zenith navigation predicate and
original tolerances; each new navigation stage has a frozen15s executor bound.
Original walking15s/goal, boarding12s, exterior exit10s, weapon total25s, native
CAP300/outer360 stay binding. Landing uses its actual captured Hero timeout
(min24s, source-derived travel allowance), unchanged4s stall and strict end
.16m/.5m/s/1.5° then exact berth transform/current occupied lease. No assist retry.
Automatic OFFLINE with>=90 neutral physics ticks, ordinary E/exterior exit,
supported walk to live boarding+[-8,0,0], actual>7m/reboard-block clear. Reapproach
live marker and ordinary E/new pilot stream,90 seated neutral ticks, second full
flight/home/OFFLINE/exit/clear walk. Require first<retired<second stream, current
Main/World/Player/capsule/shape/craft/berth/camera/target/adapter throughout.
Finish ordinary pause/Tab/Return on actual HUD Exit, actual OS0 and independent
final primary-file crash-clean/safe-start clean_shutdown/current session_ended.

**Two-pulse weapon proof.** Aim through actual camera1000m convergence and
next-muzzle320m first-contact queries, both DRONE-01/current registered target.
Require correct alternating actual marker/origin, fresh native F press AND its
consumed current-source command, actual requests0 then1/source1108/weapon/profile/
receipt/adapter context, exact health100→82→64 and exactly two18damage commits.
Each separate F pulse uses existing minimum6physics ticks, then observed native
release AND consumed command fire=false; second press waits for actual ready and
>=17physics ticks after first. No held-fire burst/early-shot probe/third Fire.
Positive actual heat/cooldown after each shot; ordinary neutral recovery follows
Hero timer=max(0,timer-delta), heat decreases at.50/s; each intact shot adds.28
heat and sets.28s timer. No overheat/1s lock is expected. Observe final ready,
restore controlled attitude within the same25s weapon window. Preserve target64
and zero further requests through both homes/flight2; no destruction/score/reward.

**Literal data contract.** Actual independent primary captures: baseline, each
completed home and orderly close; bind real profile/store/file identity and
monotonic document/commit generations, not a fictional fixed interleaving.
Allowed payload siblings are ONLY baseline runtime_settings plus
solo_safe_recovery, crash_recovery, safe_start_recovery, session_diagnostics,
cinder_timed_race_session and tutorial_prompts_seen. Require each actual live
writer/payload/receipt. Fresh race starts idle0/no saved race/tutorial; first
departure starts1, first home fails1, physical reboard resets terminal1→idle2,
second departure starts3, second home fails3. Home reason returned_to_shipyard;
if genuine timeout already occurred at elapsed>=120, preserve that same state `failed`/failure_reason `timeout`
terminal without a new generation. No new120s per-flight limit is introduced.
Tutorial schema1 adds only cinder_reach_checkpoint_route once. No checkpoint/lap/
best/penalty/reward; no cargo selection/transfer/inventory change or other namespace.
Initial default Torrent exterior preference is allowed until actual Cinder Light
boarding. Settled Cinder pilot/home exterior contexts must use
{location:mudds_home_berth, mode:pilot/on_foot, craft_id:cinder_light_interceptor,
berth_id:dock_06_interceptor}; unavailable is permitted only during actual transition.
Other settings/bindings/preferences/progress/debt stay baseline-identical.

**Proof/build/closure.** One full existing Python native-runner suite, source
import/compile, startup CLI privacy and existing Cinder combat source check; all
actual Godot calls use pinned4.7.1/Dummy and fresh private profiles. Observer only
reads detached current values/receipts; paused states reuse completed gameplay
and refresh UI, with no paused physics queries. No action-provider or gameplay
mutation. One clean private Linux export embeds the opt-in observer; require
actual archive `--startup-check` exit0/exactly one STARTUP_MENU_READY_OK and zero
unexpected diagnostics, then
`python3 -B tools/release/run_native_sortie.py EXACT_BINARY --output FRESH_DIR --route cinder-light-return-reuse`
with existing independent360s supervisor and actual source/profile/cache/process
guards. No normal gameplay/graphics change is intended, so no identical public
Windows rebuild is claimed; a demonstrated runtime repair would need its own
supported continuation and fresh paired playable checkpoint before acceptance.
Source/raw review GO precedes accepted integration/push; full craft and native
GPU/device/human/final-candidate gates stay open/NOT_RUN. At closure preserve
unique unaccepted source before exact owned branch/worktree/process/scratch cleanup.

### Activities and solo-world children

First-play proof: ordinary outbound/start/activity, once-only durable reward and home return at canonical distances. The accepted one-shot HULK route is not reassigned as missing gameplay. Repeat/write/save scenarios are instantiated only after their finite uncovered lists are known.

Select one milestone from the [first-play handoff](#activity-first-play--bounded-handoffs),
not an entire row as an implementation assignment. Milestones can be accepted
individually, as KIT-BOARD/DEPART/DELIVER already demonstrate; PLAY-* closes only
when the complete same-candidate ordinary journey is proven. A staged integration
test is an owner/regression anchor, not a runnable ordinary route.

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| PLAY-RACE | Checkpoint Race first full ordinary play | 13 | Qualification | DONE in packaged7997b2b37 Linux/Xvfb OS-input scope: full normal menu/Guided/physical exit/reboard clearance/same-Torrent countdown/five real32m gates16.116667s/once-only durable payment/strict home dock/90neutral OFFLINE ticks/physical exit/supported.969m walk/normal UI OS0 in276.690s under original300. Exact two approach-driven tutorial additions and all other protected save data verified through five real-file captures/orderly close. Source/raw GO; earlier failures retained and source integrated. Repeat/recovery/device/native/final gates remain separate. [Result](history/ROADMAP_DELIVERIES.md#race-first-play-accepted-20261025). | [Complete ordinary activity journey](#proof-activity): five ordered physical checkpoints/countdown within120s; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-THREADING | Asteroid/debris Threading first full ordinary play | 13 | Qualification | Driver definition DONE; execution GATED on unresolved UI-BOARD-FOCUS at shared Activity Board transition. Full30m entry→five physical gates→durable reward→landing-unlocked actual home/usable exit remains unproven. No renamed retry or synthetic checkpoints; [readiness/owners/full contract](#threading-complete-first-play--driver-readiness) | [Complete ordinary activity journey](#proof-activity): ≤30m start/five real gates/collision-before-progress behavior; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-PATROL | Platform Patrol first full ordinary play | 13 | Qualification | RELAY_SWEEP first ordinary packaged branch DONEc3d369e0f: actual UI selection/genuine Guided/reboard/safe header departure, five ordered120-continuous-tick holds, exact relay payment, strict home/90neutral OFFLINE/physical exit/supported.969m walk/normalUIOS0 in227.070s under original300; five real-file captures and independent source/raw GO. First outbound-header timeout retained on same90minclock; caller-only safe-lane correction, runtime unchanged. PLATFORM_SWEEP PARKED: unaccepted ff3fbab08 completed five holds/payment/home/walk but original300s expired at quit_wait; normal UI OS0 and orderly-close file are missing. Source/raw archived; no retry or cap change selected. Reopen only with source/raw-supported cause and bounded correction preserving the full journey and cumulative clock. [Failed trial](history/ROADMAP_DELIVERIES.md#patrol-platform-first-play-parked-20261025). Full PLAY-PATROL stays OPEN. Repeat/cold/parked30Main suite/UI-BOARD-FOCUS/native/final gates unchanged. [Result](history/ROADMAP_DELIVERIES.md#patrol-relay-first-play-accepted-20261025). | [Complete ordinary activity journey](#proof-activity): relay_sweep AND platform_sweep five checkpoints/2s holds/branch payment; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-JOVIAN-KIT | Jovian kit delivery first full ordinary play | 13 | Qualification | Ordinary board/depart/deliver DONE through28a5e354e;79.213s strict home return, two kits/single reward/usable exit. Distinct-process reload remains unqualified after strict30s timeout; no whole-parent closure | [Complete ordinary activity journey](#proof-activity): real departure/strict landing/transfer2 kits/pay once; cold KIT-RELOAD remains; real durable result and strict home/OFFLINE physical exit/usable walking. |
| KIT-BOARD | Ordinary offline cargo selection and Jovian pilot boarding | 7,13 | Qualification | DONE source62bc7c823;66.158s, real menus/walk/local pilot/occupied berth, cargoIDLE0/source6/destination0 manifests; no departure | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| KIT-DEPART | Real departure automatically starts cargo, then ordinary brake | 13 | Qualification | DONE sourceb91019562;70.350s, real5m/lease release/ACTIVEg1/brake≤.5m/s1s/original180s | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| KIT-DELIVER | Strict home landing transfers2 kits/pays once; usable exterior exit | 13 | Qualification | DONE28a5e354e;79.213s actual dock/lease, COMPLETEDg1 kits4/2, one transfer/reward, automatic OFFLINE/authored exit/supported walk≥.5m | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| KIT-RELOAD | Distinct process reloads actual completed store without duplication | 13,31 | Qualification | PARKED/open; originalstrict30s includespreload. Mainready/restoreaccepted27.762s/pausedfalse; firstordinaryphysics/process pair incomplete beforedeadline, full60tick continuation unqualified. Bounded sourceaudit2026-10-20 finds standardSceneTree waits/no callerpause error/no concrete currentstartuprepair. Trace lacksafterphysics/beforeprocess boundary, so exactfirst-framecost unlocalized. No corrupt/duplicatecargo observed; no rerun/probe/longercap/preloadclockmove selected. Source archive/withheld/jovian-reload-boundary-20261018 retained. | Distinct normal process loads actual completed kit-delivery file, preserves transfer/payment/unrelated data exactly and usable continuation under original30s including preload. |
| PLAY-CINDER-SUPPLY | Cinder platform supply first full ordinary play | 13 | Qualification | DONE9ed9a0709, packaged checkpoint9ed9a07. Complete ordinary native-input journey216.291s under original300s/activity120s: all13+6+6+5 and home walking goals, actual terminal transfer1/source2→1/destination0→1, exactly one saved credit, duplicate refusal, exact protected pretransfer/paid/repeat/home files incl raceg1, physical reboard/home dock/OFFLINE/authored exit/supported1.234m walk/normal UI OS0. Independent full-scope review GO, three strict startups and1525-entry Windows/Linux payload audit PASS. Earlier failures retained; real boarding old-package RED/source26-check GREEN identifies missing remote-sortie continuation. Merged/pushed, no new branch/worktree; own scratch removed. Separate four cargo lifecycle failures, repeat/restock/cold inventory and native hardware/human gates remain open; Hauler ordinary delivery separately DONE99f2717ee | [Complete ordinary activity journey](#proof-activity): actual crate/gate/platform transfer1/one durable credit/duplicate refusal; preserve shared stock; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-MINING | Mining/extraction first full ordinary play | 13 | Qualification | FAILED/PARKED candidate20bd1ab: single archive route53.444s reaches real Cinder approach then strict-stops on Activity Board focus-disconnection errors, before mining/return. Source unmerged under `archive/withheld/mining-first-play-20261018`, working branch deleted/checkpoint withheld; UI-BOARD-FOCUS causal repair required before reopening; original CAP300 unchanged | [Complete ordinary activity journey](#proof-activity): ≤30m approach/six physics extraction seconds/durable capacity receipt; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-SCAN | Structure Scan first full ordinary play | 13 | Qualification | UNSCHEDULED; ordinary approach within24m → actual4s physics scan → one discovery/payment entitlement → home dock/usable exit. Existing full Scan failure stays PARKED; no unchanged retry selected | [Complete ordinary activity journey](#proof-activity): ≤24m approach/four physics scan seconds/discovery/payment once; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-BEACON | Beacon Traversal first full ordinary play | 13 | Qualification | DONE bc48b2a: complete original ordinary journey112.031s within300s. Four physical beacons/one durable reward/60 stable ticks, actual safe RangeHeader crossing at hull100, four range targets/interceptor defeated, strict occupied home dock/OFFLINE/one native L and E/same-Player supported0.969m walk. Original Home caller restored with fine mouse correction at demonstrated quantization stall; all original guards retained. Independent review, paired checkpoint/three strict startups/1525-entry audit PASS; merged/pushed/owned cleanup done. Earlier settlement e06550e retained; archived37.713s UI failure and307.042s stalled route retained. UI cause remains unresolved; no normal-UI-quit/cold-restart/repeat/native/human acceptance. [Full result](history/ROADMAP_DELIVERIES.md#beacon--complete-original-home-journey-accepted--2026-10-21) | [Complete ordinary activity journey](#proof-activity): four physical beacons in order/payment once; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-CONVOY | Convoy Escort first full ordinary play | 13 | Qualification | PARKED/NOT_ACCEPTED after ONE full resumed candidate84222cbea. Genuine Guided, same-Torrent4m rendezvous, exact34+1 native raider hits, all four tender legs/safely_arrived7.15s, credit1, strict home/90neutral OFFLINE frames/physical exit/0.969m walk proven. Normal Quit requested, but two root-Window focus_entered/tree_exited disconnect errors stop zero-diagnostic acceptance; OS0/both final clean markers not independently captured. Native302.438s includes cleanup, recorded failure RuntimeError not proven CAP300 timeout. No retry/suppression/source-only acceptance; five-file code/private package archived unmerged. [Full raw result and scope](history/ROADMAP_DELIVERIES.md#convoy-full-route-shutdown-parked-20261026). Prior19.068441min plus all resumed time from22:07:45 retained against75min total; reviewed HARD23:03:40.893533; archive cumulative51.964455min. Reopen only actual connection-owner/removal-order cause + supported correction + independent cumulative-priority review preserving original full route/CAP300/outer360/OS0/clean states; matching older strings is not common-cause proof. Older two preengine stops and17Main save-suite remain parked. | [Complete ordinary activity journey](#proof-activity): actual4m rendezvous/retained Main tender safe arrival;90s/42m/3s separation; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-DEFENSE | Station Defense first full ordinary play | 13 | Qualification | OPEN. Deploy-arm/actual-launch start9af48515a delivered. Latest consumed-fire candidate787daded0 NOT_ACCEPTED: one full ordinary trial104.968s, genuine Alpha/Beta kills at20.150s/28.0167s, original activity timed_out34.0167s with2/4 remaining; zero payment, no home/Reset/UIquit. Fresh input consumption worked; no engine defect established. Focused checks/private package passed, but cannot close activity. Original failures retained, unique five-file qualification source archived/unmerged, accepted main restored and owned cleanup complete. No retry selected: reopen only for source/raw-supported cause and one bounded correction preserving full original journey/34s/CAP300/outer360. [Exact closeout](history/ROADMAP_DELIVERIES.md#defense-consumed-fire-qualification--not-accepted--2026-10-24). | [Complete ordinary activity journey](#proof-activity): physical Deploy/real waves1–2–1/actual four kills/payment/home/Reset/usable next Deploy;34s activity semantics; real durable result and strict home/OFFLINE physical exit/usable walking. |
| DEFENSE-PHYSICAL-INTERACTION | Physical board E Deploy/status/reward-retry/terminal Reset | 13 | Capability | DONE checkpointa59127c: actual Main15/full placement62, paired exports/three strict startups/actual PCK audit PASS. Existing owners, debt/refusal/separatepress/range/facing/armed gates and whole34s preserved. Original test parse16.381s + one explicit-int correction retained, cumulative334.765s. Staged pose/terminal/refusal fixtures disclosed; full ordinary combat/home separate. [Result](history/ROADMAP_DELIVERIES.md#station-defense-physical-interaction--shipped-on-a59127c) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| PLAY-BREACH | Heavy Breach first full ordinary play | 13 | Qualification | DONE scoped first full ordinary journey fb396ab13/checkpointfb396ab. Actual physical Heavy arm/Arrow takeoff/observed lance charge/player hits24+22 kill46-health Picket/CLEARED at3.05s, exactly one generation1 actual-file Heavy credit retained through orderly close, strict home/OFFLINE physical exit/physical usable Torpedo posting/normal UI actualOS0; full90.112s under150/300/360 and clean logs. Real late-authority damage adapter attached idempotently; staged live-ray/Picket/encounter/Heavy checks, fresh paired exports/3menus/1527-entry audit and independent source/raw review pass. Both earlier failures/caller-angle correction preserved, same cumulative clock; merged/pushed/owned cleanup/records consolidated, no taskbranch/worktree. Isolated Linux/default-input/Dummy scope; repeats/other lifecycle/craft/native/device/full parents remain open. [Delivery](history/ROADMAP_DELIVERIES.md#picket-damage-admission-and-full-heavy-breach--accepted--2026-10-25). | [Complete ordinary activity journey](#proof-activity): on-foot posted Heavy/real picket/protected objective/payment/home/normal next posting; real durable result and strict home/OFFLINE physical exit/usable walking. |
| PLAY-TORPEDO | Torpedo Run first full ordinary play | 13 | Qualification | PARKED/NOT_ACCEPTED latest continuation: source review BLOCK at67.453min cumulative; unread queued neutral samples after OS release can erase later actual consumption. No tests/engine/export/whole trial. Candidate and original patch verified in case-records.tar.gz/closeout.json outside repo; main restored, owned helpers consolidated. Reopen only with accounting that survives queued release ambiguity, source GO and cumulative review; full journey/limits unchanged. [Review stop](history/ROADMAP_DELIVERIES.md#torpedo-control-continuation-stopped-at-source-review-20261025). PARKED after3fullordinaryFAILs, latestd8eece4/game2de. First121.849s run proves real evasion/interceptions/boat24damage but stops pooled-flight receipt bookkeeping; supported correction retry104.452s stopssecondboarding. Source/raw-proved sampledreadiness continuation133.075s reboards correctly (soleE4604/BOARDING4607), provespitchboostevasion/distinctseeker14kill, then3boatshotsmiss and2incomingseekers destroyArrow; boat70/70/noTorppayment/home/posting/UI0. FirstHeavyprefix/receipt remains actual. Both caller fixes/fixturefailure and all3runs retained on sameoriginalclock; no source merged merely for cleanup. Unique source/bundles/results archived, ownedprocess/profile/packagecleanup complete/mainrestored. Reopen only demonstrated source/raw-supported gameplay/control correction preserving full150each/shared300/outer360 goal; no unchanged retries/newqualifierlayers/point-aim-timer guesses. Publicfb396ab unchanged. [Closeout](history/ROADMAP_DELIVERIES.md#torpedo-second-boarding-readiness--whole-journey-not-accepted--2026-10-25). | [Complete ordinary activity journey](#proof-activity): ordinary posting rotation/real evade/interception/boat destruction/distinct payment/home; real durable result and strict home/OFFLINE physical exit/usable walking. |
| HUD-RACE | Race durable reset/select/start/fresh-Main UI | 13 | Qualification | Source review already found no concrete discrepancy; no edits/runs or ordinary acceptance. Do not repeat unchanged source triage; full qualification remains unscheduled. BLOCKED definition — Codex binds the literal saved activity/debt fields, expected enabled actions after each reset/select/start/fresh-Main step, existing command and original limits. No implementation is selected without a demonstrated runtime defect. | Race: actual reset→selection→start→distinct fresh Main shows authoritative saved state and correct enabled actions; protect real data/debt and retain accepted repairs. |
| HUD-PATROL | Patrol durable reset/select/start/fresh-Main UI | 13 | Qualification | Source review already found no concrete discrepancy; no edits/runs or ordinary acceptance. Do not repeat unchanged source triage; full qualification remains unscheduled. BLOCKED definition — Codex binds the literal saved activity/debt fields, expected enabled actions after each reset/select/start/fresh-Main step, existing command and original limits. No implementation is selected without a demonstrated runtime defect. | Patrol: actual reset→selection→start→distinct fresh Main shows authoritative saved state and correct enabled actions; protect real data/debt and retain accepted repairs. |
| HUD-CARGO | Cargo durable reset/select/start/fresh-Main UI | 13 | Capability | Supply-status child DONE0c2dc2e: depleted hold reports insufficient kits after reset/reselection; cargo127/nearby HUD13 and paired checkpoint pass. Broader durable UI/restart remains open; KIT-RELOAD stays parked. Remaining ordinary UI qualification is BLOCKED definition — Codex: record the exact saved activity/generation/progress/debt fields, expected displayed state and enabled actions after reset, selection, start and distinct fresh-Main reload; bind the existing fixture/command, protected payload and original limits. Reuse accepted runtime repairs and completed source maps; no repeated survey or implementation without a reproduced discrepancy. | Cargo: actual reset→selection→start→distinct fresh Main shows authoritative saved state and correct enabled actions; protect real data/debt and retain accepted repairs. |
| HUD-CONVOY | Convoy durable reset/select/start/fresh-Main UI | 13 | Capability | Restored-objective discrepancy DONE on checkpoint3d92b91: cold/wrong-craft saved escort shows paused guidance, accepted craft rebind restores live progress; existing retained-feedback20 assertions pass. Bounded source check2026-10-26 found no new runtime gap: existing production integration664–762 and save/restore566–598 already exercise committed reset, HUD family switching, start and fresh-Main authority. Reuse completed470aa24c4/4fc5ef9f3 source maps; do not repeat this survey. Wider combined ordinary HUD/full Convoy qualification remains open; parked save suite not reopened. Remaining ordinary UI qualification is BLOCKED definition — Codex: record the exact saved activity/generation/progress/debt fields, expected displayed state and enabled actions after reset, selection, start and distinct fresh-Main reload; bind the existing fixture/command, protected payload and original limits. Reuse accepted runtime repairs and completed source maps; no repeated survey or implementation without a reproduced discrepancy. | Convoy: actual reset→selection→start→distinct fresh Main shows authoritative saved state and correct enabled actions; protect real data/debt and retain accepted repairs. |
| ACT-WRITES-DEFINE | Uncovered activity/write-boundary cells | 13,31 | Definition | DONE definition only; finite durable owner/boundary map below, with terminal-only owners distinguished; exact-package/real-file/ordinary recovery acceptance remains open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| BOOT-BREACH-OWNERS | Physical Heavy Breach board has exact production owners before gameplay | 9,11,13 | Capability | DONE packagede3d1ada; two exact old owner failures, final full startup/48-check production route and strict paired checkpoint pass; earned-debt interruption transaction DONE c78e0ac | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| BREACH-INTERRUPTION | Exported Heavy Breach real-file earned debt/kill/recovery/paid replay | 13,31,32 | Qualification | DONE c78e0ac: source and exact archived Linux executable each complete genuine earned unpaid terminal, actual owned kill/reap, distinct normal Resume/real pilot/production exit/physical payment, exact same-document atomic receipt+ack and third cold paid replay. Privacy/compile/paired exports/strict startups/audit PASS; branch merged/deleted. All original 249.405s failures retained; ordinary combat/active-combat restore/native scope separate. [Delivery](history/ROADMAP_DELIVERIES.md#breach-interruption-branch-finished--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACT-REPEAT-DEFINE | Exact applicable ten-run activity scenarios | 13 | Definition | DONE definition: all twelve activities classified below; two cargo routes retain explicit stock-policy gates, Heavy/Torpedo preserve alternating physical board. Measurement/deadline freeze and first-play gates remain; no execution accepted | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| REPEAT-RACE | Ten same-world Checkpoint Race completions through actual ordered checkpoints, payment and accepted reset; next run starts usable | 13 | Qualification | PARKED after two full attempts; [literal retained contract](#race-repetition--selected-ordinary-input-capability). First735.603s attempt has3completehome/census cycles and4payments; fourthhome hits original300s. Python-only gantry-lane correction source49cba86e3 then firstcycle times out312.126s before inner/outerlane/home/census; payment1 only. Fullten-cycle result FAILEDtwice; idle20/nextstart/UIclose NOT_RUN. Candidate/exports unaccepted, verified archived before owned branch/scratch cleanup. First-play7997b2b37 remains accepted. Reopen only demonstrated corrected first-lane failure cause and independent cumulative-priority review under retained original clock/caps; no renamed/unchanged retry. [Full stop](history/ROADMAP_DELIVERIES.md#race-repetition-two-attempt-stop-20261025). | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Production countdown and five ordered physical checkpoints within the existing120s timer. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-BEACON | Ten same-world traversals of all four authored beacons in order, accepted payment/reset and usable next run | 13 | Qualification | PARKED/NOT_DELIVERED after two full attempts. First425.713s native: one paid full home/census, then leg2 original300s cap/cursor3. Cause-supported external Resume mouse-pending correction0029b8daf passes253 tests; unchanged da6d539 game reused. Corrected335.727s native/336.134s wrapper: two paid complete homes/two matching censuses, then original12s reboard-clear walk entering leg3. Later cause NOT_ESTABLISHED; no third trial/investigation/repair/cap increase. [Frozen contract](#beacon-repetition--selected-ordinary-input-capability), [failure/archive/cleanup](history/ROADMAP_DELIVERIES.md#beacon-repetition-two-attempt-stop-20261026). Reopen only demonstrated later-walk cause plus independent cumulative-priority review; original14:58:50UTC/90min cost retained. Source/private exports verified archived before exact branch/worktree deletion; candidate remains unmerged. | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. All four authored beacons traversed physically in order; retain the settled outbound≤60s limit. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-SCAN | Ten same-world scans from actual approach, full four-second physics scan, existing payment/discovery/reset and usable next run | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-SCAN and frozen resource-baseline/deadline contract; existing full Scan failure remains PARKED, no retry selected | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual approach≤24m followed by four real scan seconds. Each run preserves the existing discovery/payment authority, accepted reset and usable next start; entitled receipts settle once, with no duplicate discovery reward. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-THREADING | Ten five-gate Asteroid Threading completions with accepted payment/reset | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-THREADING and measurement/deadline freeze; source reset/save coverage retained | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual start≤30m and five physical gates in order, preserving collision-before-progress behavior. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-PATROL | Ten ordered station-keeping patrol completions on the frozen authored branch, then usable next start | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: complete PLAY-PATROL (relay DONEc3d369e0f; platform still open) and measurement/deadline freeze; record relay/platform branch explicitly; one branch does not qualify the other. Branch membership is BLOCKED definition (Codex): bind the original repeat requirement to relay_sweep/platform_sweep. If the original specification does not settle one versus both, record that exact product choice for the user before execution; do not choose from run results or invent another repeat requirement. | [Activity repeat](#proof-activity): ten legitimate completions in one retained world for each branch required by the recorded membership. Five ordered checkpoints with2s continuous holds; freeze whether relay_sweep, platform_sweep or both are required before execution. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-JOVIAN-KIT | Ten real two-kit delivery/paid reset cycles without invented stock | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: legitimate stock replenishment/cycling policy and measurement/deadline freeze; initial6 kits only fund3 deliveries, KIT-RELOAD stays PARKED | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual departure, strict landing and transfer of exactly two kits per delivery; require the recorded CARGO-REPLENISH-JOVIAN policy and conserved source/destination counts. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-CINDER-SUPPLY | Ten real one-crate platform delivery/paid reset cycles without invented stock | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-CINDER-SUPPLY, stock/capacity policy and measurement/deadline freeze; initial source2/destination capacity8; approved shared Jovian/Hauler custody is retained; legitimate replenishment/destination turnover remains unresolved | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual platform terminal transfer of exactly one conserved crate per delivery; require CARGO-REPLENISH-CINDER refill/turnover policy, source/destination counts and duplicate refusal. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-MINING | Ten real six-second extractions, each acknowledged once and reset durably | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-MINING and measurement/deadline freeze; capacity receipt is not ore/currency inventory | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual approach≤30m and six real extraction seconds per completion; require the existing once-only capacity acknowledgement rather than invented ore/currency. Each completion has exactly one capacity acknowledgement, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-CONVOY | Ten real safe-arrival escorts with once-only payment and production reset | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-CONVOY and measurement/deadline freeze; retained-host/actor lifecycle and original failures remain | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual4m rendezvous and retained-Main tender safe arrival; preserve90s timeout,42m proximity and3s separation rules. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-DEFENSE | Ten fresh physical-board deployments, full three-wave clears, payment and reset | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-DEFENSE and measurement/deadline freeze; wave recovery is not another fresh completion | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Fresh physical Deploy/launch and all four enemies in waves1–2–1 destroyed under existing34s activity semantics; accepted Reset must permit the next Deploy. Each completion has exactly one durable payment, accepted reset and usable next start. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. |
| REPEAT-BREACH | Ten cleared Heavy Breach postings through ordinary board rotation | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-BREACH and measurement/deadline freeze; alternate Torpedo postings cannot be skipped; BREACH-INTERRUPTION earned-debt case DONE c78e0ac | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual charged picket/protected-objective clear from the posted Heavy encounter; reach each next Heavy through ordinary Heavy→Torpedo→Paired Wing→Perimeter board rotation. Each completion has exactly one durable payment, ordinary home/dock/on-foot rearm and a usable next posting through the required rotation; no normal post-clear Reset is required. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. Intervening postings must conclude ordinarily; count ten clears of this named encounter, not ten mixed successes. |
| REPEAT-TORPEDO | Ten cleared Torpedo postings through ordinary board rotation | 13 | Qualification | BLOCKED definition — Codex must freeze the existing ten-same-world-success route, unchanged per-run deadlines, finite equivalent-phase resource counters/baselines and legitimate receipt/generation growth. Pass requires zero growth in those retained resource counts after equivalent cleanup phases; Codex binds the counters and baseline, without inventing a leak allowance or asking the user for one. Estimate total execution from ten measured complete cycles plus travel/cleanup; no new whole-route deadline. Only this activity’s named PLAY, cargo-policy or rotation prerequisites apply. Prerequisites/retained scope: PLAY-TORPEDO and measurement/deadline freeze; ten mixed sorties do not satisfy ten of either scenario | [Activity repeat](#proof-activity): ten legitimate completions in one retained world. Actual seeker evasion/interception and boat destruction from the posted Torpedo encounter; reach each next Torpedo through ordinary Heavy→Torpedo→Paired Wing→Perimeter board rotation. Each completion has exactly one durable payment, ordinary home/dock/on-foot rearm and a usable next posting through the required rotation; no normal post-clear Reset is required. Compare the frozen equivalent-phase actor/registration/pool/observer/objective counters with their baseline: no growth; retain legitimate receipt/generation increments separately. Freeze the exact route, counters and original limits before running; absent bindings remain BLOCKED definition. Intervening postings must conclude ordinarily; count ten clears of this named encounter, not ten mixed successes. |
| TRAVEL-LIMIT | Numeric ordinary nearby-travel envelope | 13 | Decision | DECIDED2026-10-21: Beacon outbound maximum60s unpaused monotonic elapsed, existing exact start/stop/route unchanged. DONE252ed6bfc: measured10.510574s within60s during full original111.908s beacon-home journey using checkpointc2c72a2. Return and other routes remain open. | This decision closes on the recorded original-required craft/leg list, each exact start/stop/pause/clock and owner-approved maximum. Remaining leg membership is BLOCKED definition—Codex; unresolved maxima are BLOCKED input—user. Additional legs require an identified uncovered original requirement. Actual leg measurements remain qualification under the corresponding existing PLAY/REPEAT goals, not completion of this decision. Beacon≤60s/10.510574s remains accepted. |
| HULK-REVISIT | Home-return/reload/revisit retains restored bus and single claimed cell | 13 | Qualification | PARKED/open; original300s unchanged, failed source archive/withheld/hulk-revisit-departure-20261017. Bounded raw/source audit2026-10-20 confirms458consecutive revisit samples/47.393m ordinary supported movement, samePlayer, authored5.8walk/9.2sprint; no interior stall established. Global deadline expires midroute beforefreshbreaker. No relevant changedproductionseam/supportable correction found; missing per-stage monotonicwalltimestamps tolocalize cost. No rerun/probe/capchange selected. | Cold reload→physical bus/cell revisit→usable home; restored bus/single claimed cell persist, no duplicate reward; original300s and causal reopen condition. |
| EMBER-SOURCE-ABANDON | Integrated physical Ember abandonment/home return | 1,14 | Qualification | DONE; e85157b4d, MemoryFilesystem, original exact31 | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| EMBER-OBSERVER | Native package observer production capability | 1 | Capability | DONE; 4270d71 source capability and startup-qualified checkpoint | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| EMBER-NATIVE-SMOKE | Native observer normal-window-close smoke | 1 | Qualification | PARKED; failed fixture/repair and priority review retained | Original frozen observer/window-close route exits normally with exact fixture/cleanup and zero diagnostics; failed fixture not retried unchanged. |
| EMBER-PACKAGE-ABANDON | Packaged ordinary physical abandonment/home return | 1,14 | Qualification | GATED; supported OS-input route, old external-driver path UNSUPPORTED. BLOCKED definition — Codex: bind supported packaged OS-input caller/command, craft/profile, exact physical abandonment trigger, protected survey/progress/debt fields and complete reboard/ascent/strict-home/exit/reuse endpoints with original limits. The unsupported old external-driver path supplies no command. Reuse pending-abandon cold-restart/ordinary-Quit component proofs only in their recorded scope; record an unavailable caller/artifact before selection. | [World](#proof-world): supported packaged OS-input outbound/physical abandonment/reboard/ascent/home dock/exit/reuse; source/memory-store pass insufficient. |
| WORLD-ABANDON-DEFINE | Applicable Aurora/Rime abandonment and Ember reuse/durability cases | 1,14 | Definition | Finite source cases bound in the [abandonment and next-visit contract](#world-abandonment-and-next-visit-binding). Aurora/Rime survey abort, airborne approach abort, ordinary surface return and lifecycle rescue are distinct; tree-detach interruption is separate. Full physical Ember return/home/exit/reuse and remaining disk-restart boundaries remain unqualified; accepted component and pending-abandon cuts are listed below. Execution GATED on the named ordinary/package callers and exact original route/kill/restart limits; Codex owns these missing executable bindings. Earned-but-unpaid end-visit loss is reproduced and fixed in checkpointf51e02a: [real-file/fresh-Main and once-only retry proof](history/ROADMAP_DELIVERIES.md#surface-survey-unpaid-retirement-accepted-20261026); ordinary physical return/distinct OS restart/full-world qualification remain open. One source pass complete; no unchanged survey or new matrix.  Ember explicit-abandon saved-checkpoint component is accepted in34f60da, with controlled-Host/MemoryFilesystem and staged return proof; remaining disk boundaries and full ordinary journeys remain open.  Exact pending-abandon exported real-file kill/cold-restart cut accepted on Gameb30a9ea93/Driver7337dc543 ([proof](history/ROADMAP_DELIVERIES.md#ember-pending-abandon-native-cold-restart-accepted-20261026)); full physical return/debt and other quit/detach cases remain open.  Ordinary application-Quit capture accepted on8e74c40 ([proof](history/ROADMAP_DELIVERIES.md#ember-ordinary-quit-checkpoint-capture-accepted-20261026)): actual Main/production collector saves current incomplete on-foot route/pose once; exported final real file has fresh index0 and passive original index1. Arbitrary Main removal/streaming and untested phases remain open. | Finite list of applicable Aurora/Rime abandonment and uncovered Ember reuse/durable cuts, each phase/caller/reboard-or-safe-return/debt/next-visit endpoint fixed. |
| WORLD-SAVE-DEFINE | Uncovered world survey/reward/reboard/visit disk boundaries | 14,31 | Definition | BLOCKED definition (Codex): list only uncovered Ember/Aurora/Rime disk boundaries with exact phase/craft, committed survey/earned-unpaid/payment fields, accepted/refused-write or owned kill cut, distinct-process command, supported reboard/home endpoint and original limits. [Planetary contracts](#planetary-recovery-boundaries) govern the result; accepted WORLD-SAVE-EMBER-FIRST-RELAY923d7b326/6112944d0 is reused, not reopened.  Exact pending-abandon exported real-file kill/cold-restart cut accepted on Gameb30a9ea93/Driver7337dc543 ([proof](history/ROADMAP_DELIVERIES.md#ember-pending-abandon-native-cold-restart-accepted-20261026)); full physical return/debt and other quit/detach cases remain open.  Ordinary application-Quit capture accepted on8e74c40 ([proof](history/ROADMAP_DELIVERIES.md#ember-ordinary-quit-checkpoint-capture-accepted-20261026)): actual Main/production collector saves current incomplete on-foot route/pose once; exported final real file has fresh index0 and passive original index1. Arbitrary Main removal/streaming and untested phases remain open. | List actual uncovered per-world survey/earned-unpaid/paid/reboard/visit disk boundaries; expected recovery/protected state/real-file action fixed, no blanket grid. |
| WORLD-SAVE-EMBER-FIRST-RELAY | Cold safe-yard recovery retains first-relay progress and later pays the original survey once | 14,31 | Qualification | DONE on exact archive923d7b326/caller6112944d0: saved unpaid relay, real SIGKILL/reap-9, distinct Boot Resume0, exact runtime boundary, safe yard/fresh boarding/attachment1→2/original completion and once-only receipt0→1, zero diagnostics. Correctly staged external metadata; no gameplay/predicate change/tolerance. Original300s/game/660s outer and317.447268s failed costs retained; new wall interval308.992s. [Accepted result](history/ROADMAP_DELIVERIES.md#ember-first-relay-cold-recovery--exact-package-accepted--2026-10-20). Canonical outbound/normal controls/native GPU NOT_RUN, standing-pose restore NOT_SUPPORTED; current/final-package and broader world gates remain open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| WORLD-EDGE-DEFINE | Applicable solo cancellation/refusal/failure/repeat cases | 14 | Definition | BLOCKED definition — Codex must bind original solo cancellation/refusal/failure/revisit cuts to world, caller, phase and expected actor/lease/reward/usable-return state; missing product outcome goes to the user. This is a finite list decision, not gameplay acceptance. | List original solo cancellation/refusal/failure/repeat cuts per world, with specific caller/phase, usable return and reward/actor/lease cleanup. |
| SOLO-EMBER | Ember canonical physical survey round trip | 14 | Qualification | GATED; freeze uncovered candidate/scenario, prior source passes retained. BLOCKED definition — Codex: bind this world's existing canonical-distance route to actual craft, ordinary control sequence/command and original segment/whole-route limits. For each objective in Done means, name its literal completion/progress/reward/save fields, physical landing/reboard/ascent/home endpoints and normal-exit proof. Reuse accepted source cases only within their recorded scope; no substitute short journey. | [Canonical physical round trip](#proof-world), Ember: caldera relay/ember_beacon_data plus lava-tube/wreck errands; actual save/reward/reboard/ascent/strict yard dock/exit/usable walk. |
| CONTENT-EMBER | Ember finite remaining authored content/presentation findings | 15 | Definition | Definition DONE on 7c0bc2967: no missing implementation identified in the inspected authored-content scope; see boundary below. Full ordinary/repeat/shared/hardware qualification remains open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SOLO-AURORA | Aurora canonical physical survey round trip | 14 | Qualification | GATED; freeze uncovered candidate/scenario, prior source passes retained. BLOCKED definition — Codex: bind this world's existing canonical-distance route to actual craft, ordinary control sequence/command and original segment/whole-route limits. For each objective in Done means, name its literal completion/progress/reward/save fields, physical landing/reboard/ascent/home endpoints and normal-exit proof. Reuse accepted source cases only within their recorded scope; no substitute short journey. | [Canonical physical round trip](#proof-world), Aurora: actual lookout/standing-stones observations and durable reward; actual save/reward/reboard/ascent/strict yard dock/exit/usable walk. |
| CONTENT-AURORA | Aurora finite remaining authored content/presentation findings | 15 | Definition | Definition DONE on 9d2d467e0: no missing implementation identified within inspected authored-content scope; see boundary below. Qualitative adequacy and existing journey/visual/hardware acceptance unproven | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SOLO-RIME | Rime canonical physical survey round trip | 14 | Qualification | GATED; freeze uncovered candidate/scenario, prior source passes retained. BLOCKED definition — Codex: bind this world's existing canonical-distance route to actual craft, ordinary control sequence/command and original segment/whole-route limits. For each objective in Done means, name its literal completion/progress/reward/save fields, physical landing/reboard/ascent/home endpoints and normal-exit proof. Reuse accepted source cases only within their recorded scope; no substitute short journey. Also bind the existing cold-failure/restart trigger and supported recovery. | [Canonical physical round trip](#proof-world), Rime: beacon/drill/gauge/ice-core and actual cold failure/restart; actual save/reward/reboard/ascent/strict yard dock/exit/usable walk. |
| CONTENT-RIME | Rime finite remaining authored content/presentation findings | 15 | Definition | Definition DONE on 30968aeda: no missing implementation identified within inspected authored-content scope; see boundary below. Existing ordinary/shared/visual/hardware acceptance remains open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |

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

For the three qualitative criteria above (orbital recognisability, landing-region
adequacy and reason to return), use the existing required world/capture views.
Before selecting a review, fix the observable criterion and expected visible
result from the original contract. If it supplies no such criterion, record the
exact missing interpretation decision for the owner and keep that criterion
GATED; repeated source comparisons cannot close it. A source inventory is not
visual acceptance. Do not invent new content, renewable rewards or a mandatory
human-review gate to settle the wording.

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

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| NET-JOVIAN-BOARD | Ordinary two-client physical boarding and confirmed seats/HUD | 16,26 | Qualification | DONE; fff5f7221, host plus two clients | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-DEPART | Ordinary shared 5m departure and zero-speed braking | 16,26 | Qualification | DONE; 96c96312f, broader return/endurance not established | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HELM-EDGE-REPRO | Actual immediate landing followed by neutral physics reproduces missing remote edge | 18 | Qualification | DONE; a3955ee90 expected-only failure, original fixture compile repair retained | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HELM-EDGE-REPAIR | Preserve admitted immediate command exactly once across consumers | 18 | Capability | DONE; 2c73494a4, consumer40/ship_command79, component-staged scope | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-RETURN | Original shared physical home docking and both clients consumed arrival | 16,20,26 | Qualification | DONE;4c9c764e9 original route138.915s, failed331 arrival attempt retained | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-ARRIVAL-CALLER | Confirm arrival using client-received ownership record | 16,20,26 | Qualification | DONE;4c9c764e9, original pilot/ship/ownership generations, all peers exit0 | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ROLE-JOVIAN-ENGINEER | Jovian engineer ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual selected component repair with conserved kit and observed elapsed progress, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-HALYARD-PASSENGER | Halyard passenger ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): physical passenger sit/stand and supported moving-cabin carry, without helm authority, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-HALYARD-ENGINEER | Halyard engineer ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual component repair/readiness with conserved kit and interrupted repair cleanup, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-HALYARD-GUNNER | Halyard gunner ordinary moving-crew lifecycle | 16,24 | Qualification | Local source route and one actual52damage DONEc28f7ffa3; independent authenticated remote-role lifecycle remains GATED on supported candidate/ordinary route. Original fixtures and broader networking/native limits retained. BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual gunner target damage, release and physical reseat; retain local52damage proof, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-HALYARD-LOADMASTER | Halyard loadmaster ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual cargo/manifest action and truthful conserved load/readiness, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-BULWARK-GUNNER | Bulwark gunner ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): physical gunner aim/fire causing registered target damage and release/reseat, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-CINDER-LOADMASTER | Cinder loadmaster ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual conserved cargo action through the current Loadmaster owner, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| ROLE-CINDER-NAVIGATOR | Cinder navigator ordinary moving-crew lifecycle | 16,24 | Qualification | BLOCKED definition (Codex): exact host/client identities and physical admission route, moving segment, owner-loss/disconnect cut, supported handback endpoint and existing driver/caps for this role. No additional role/craft combination. | [Physical role contract](#proof-network): actual admitted navigation action/handback and current requester refusal feedback, then current claim release, physical stand/exit/reseat and the explicitly bound moving/loss/handback cases. |
| NET-SEATS-FINAL | Final-candidate promotion/seat ledger/berth handback/stale refusal | 16 | Container | BLOCKED definition — Codex must bind the existing promotion/berth/handback/contention and stale/duplicate/foreign-refusal cases to exact craft/roles/commands and original limits on one final candidate; no additional seat permutations. | Final candidate actual promotion/berth/handback/contention and stale/duplicate/foreign refusals preserve one occupant and supported controls; reuse delivered authority. |
| NET-POSE-DEFINE | Uncovered supported craft/engine/motion/landing-view cells | 17 | Definition | BLOCKED definition for remaining coverage — Codex must freeze only uncovered craft/engine/throttle/motion/landing view IDs, current/late recipient and expected consumer values; delivered Jovian instruments/projection retained. No all-craft matrix is inferred. Bounded Jovian source comparison DONE: concrete physical throttle instrument consumer gap; broader cells remain unqualified | Finite uncovered actual craft/engine/throttle/motion/landing view list with current/late-recipient expectation and production consumer; exclude delivered projection. |
| NET-OPERATION-HUD | Gameplay HUD engine/throttle follows eligible accepted host operation facts; local pilot prediction/raw authority retained | 17 | Capability | DONEda1ae60; exact old3 failures, pose175/real-peer354, paired exports/three strict startups/actual1515-entry audit. No simulation/wire changes; parent 17 OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-HULL-HUD | Gameplay HUD bar/frame projects existing authoritative hull/maximum/status; raw simulation telemetry remains local | 21 | Capability | DONE7be348d62; exact old2 HUD failures, fixed pose140/real-peer272, paired exports/three strict startups/actual1515-entry audit. Raw simulation authority preserved; parent21 OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-HULL-INSTRUMENTS | Physical remote hull gauge reflects existing authoritative health; damage/destruction/new-life/solo-clear | 21 | Capability | DONE24430b7c1; old2 failures reproduced, pose121/real-peer250 and fresh paired24430b7 with3strict startups/actual1515-entry audit. Parent21 OPEN, no wire change | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-THROTTLE-INSTRUMENTS | Current/late physical cockpit gauge reflects signed authoritative throttle, neutral shutdown and solo restore | 17 | Capability | DONE8f17b0241; old4 failures reproduced, pose91/real-peer203 pass; fresh paired8f17b02 with3strict startups/actual1515-entry audit. Broader parent17 remains OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HELM-ACTIONS-DEFINE | Finite sampled-local-input to remote-helm action roster | 18 | Definition | DONE; seven held fields/two ordered edges, source definition only | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CABIN-PASSENGER-ROLE | Confirmed standing cabin passenger HUD follows current claim and craft after normal helm release | 18,20 | Qualification | DONE007024839 within the same yaw/handback integration/checkpoint: focusedHUD36 plus full136.675s ordinary three-peer route PASS, correct PASSENGER/craft, current support/ownership/source/co-pilot and backward walking. Pure presentation, no authority grant. Original branch and superseded caller refs deleted; archives/cleanup complete. Same delivery as HELM-YAW, not separately counted. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HELM-THROTTLE-REVERSE | Sampled reverse thrust and neutral release | 18 | Qualification | DONE isolated corrected source102704512: full ordinary3process route142.607s, actual1.342m reverse/755ms, fresh neutral434ms, both actual replicas≤0.5m, ordinary Interact handback/owner0gen+1/current PASSENGER HUD/retired source-capture/supported walk. All3newOSexits0/no diagnostics. First154.514s failure retained: local safety cutoff stopped strafe before host cleared chair; one caller strength.35→.25 correction preserves every endpoint/deadline/collision. Prior52b228c86 flight scope retained; physical devices/native/endurance/final-parent gates open. [Acceptance](history/ROADMAP_DELIVERIES.md#reverse-thrust--full-ordinary-handback-accepted-after-caller-correction--2026-10-25) | Sampled reverse thrust actually moves host, neutral release/ordinary handback retires source and leaves supported controls; retain accepted reverse-flight scope. |
| HELM-YAW | Both sampled yaw directions, neutral release and handback without stale ownership | 18 | Qualification | DONE for recorded source route007024839, merged2f75e834b: full136.675s ordinary boarding/departure/both-yaw/normal Interact/owner0gen+1/current PASSENGER HUD/supported backward walk, retired source/capture and retained co-pilot; all3 actual OS exits0, no diagnostics. All original.6m local/host and8/15/300/360s gates retained; chair-clearance caller additionally proves.6m backward after clearance. Paired checkpoint0070248; both related branches/owned scratch closed. OS/device/native/endurance/full parent remain open. [Acceptance](history/ROADMAP_DELIVERIES.md#passenger-hud-and-yaw-handback-accepted-both-branches-closed--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HELM-PITCH | Both sampled pitch directions and neutral release | 18 | Qualification | DONE isolated source d8c160f12: complete ordinary3process route138.248s, actual +4.800/−4.200deg in703/359ms, fresh neutral/zero drift, both actual replicas, full Interact handback/owner0gen+1/PASSENGER HUD/supported walk/retired source-capture. All3actual exits0/no diagnostics. Prior turn/release f9682a38c retained; physical devices/native/endurance/final-parent scope stays open. [Acceptance](history/ROADMAP_DELIVERIES.md#pitch-and-roll-rate--full-ordinary-handback-accepted--2026-10-25) | Both sampled pitch directions have actual host effect, neutral release and uncovered ordinary handback/recovery; retain accepted turn/release. |
| HELM-ROLL-RATE | Both sampled roll-rate directions and neutral release | 18 | Qualification | DONE isolated source d8c160f12: complete ordinary3process route137.012s, actual up-about-nose −5.867/+5.133deg in580/367ms, fresh neutral/zero drift, both real replicas, full Interact handback/owner0gen+1/PASSENGER HUD/supported walk/retired source-capture. Barrel/fire/landing fences intact; all3actual exits0/no diagnostics. Prior73f4a4f67 turn result retained; physical devices/native/endurance/final-parent scope open. [Acceptance](history/ROADMAP_DELIVERIES.md#pitch-and-roll-rate--full-ordinary-handback-accepted--2026-10-25) | Both sampled roll-rate directions affect host; neutral release and uncovered handback/recovery; retain accepted turn/release. |
| HELM-BOOST | Sampled boost effect on authoritative flight and release | 18 | Qualification | DONE in isolated source70c8a65e5 scope: full ordinary three-process route147.183s including baseline/boost actual host14.65/19.45m/s² across equal30ticks, fresh release<0.36s, both actual replicas≤0.5m and full Interact handback/supported walk/owner0gen+1/source-capture retirement; all3OSexits0/zero runtime diagnostics. Synthetic sampled actions/loopback only; physical devices/native/endurance/final scope remains open. [Result](history/ROADMAP_DELIVERIES.md#sampled-remote-boost--full-handback-accepted--2026-10-25) | Sampled boost gives authored host flight effect; ordinary release/handback retires same confirmed source without stale demand. |
| HELM-HOVER | Sampled hover correction on authoritative craft and release | 18 | Qualification | DONE isolated source524606903 scope: full ordinary three-process route157.438s, sampled pitch/forward creates tilt/climb; actual30tick hover tilt16.7403→6.1584deg/vertical13.5390→1.0482m/s matches authored damping/uprighting, fresh release313ms, both actual replicas≤0.5m and full Interact handback/supported walk/owner0gen+1/source-capture retirement; all3OSexits0/zero runtime diagnostics. Physical devices/native/planetary/endurance/final parent scope remains open. [Result](history/ROADMAP_DELIVERIES.md#sampled-remote-hover--full-handback-accepted--2026-10-25) | Sampled hover gives authored host correction; release/handback preserves honest controls and retires old demand. |
| NET-STALL | Original 600-step host simulation stall and honest command recovery | 19 | Qualification | DONE on3d6b1b513 current-source isolated Linux full original suite:160 terminal host assertions, both600-step stalls/original2s action checks, actual client/wrapper exit0 and zero diagnostics. [Result](history/ROADMAP_DELIVERIES.md#original-host-stall-route--current-source-accepted). No unchanged repeat; final-package/native/endurance and distinct ordinary moving-Halyard/other-action handback gates remain | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-SECOND-LAND | Historical intermittent second-landing boundary | 20 | Qualification | BLOCKED definition — Codex: identify the retained failed source/command, literal second-landing predicate and original route/cap; the old label “current return failure” is insufficient. Compare with failed331a9628b client-arrival and accepted4c9c764e9 strict Jovian return in [existing post-dock history](#supported-post-dock-exit-and-reuse-cases). No probe until distinctness is resolved. | One finite disposition: if the literal predicate is identical to an accepted case, cite that exact proof and close this duplicate within its scope; if distinct and original-required, record its exact source/command/second physical landing/lease/reuse endpoints and original cap before qualification. Missing retained artifact stays BLOCKED with its location/search boundary recorded. Post-dock stand/exit/reuse are not proved by4c9c764e9. |
| NET-DOCK-DEFINE | Supported craft dock/exit/reboard/redeparture acceptance cases | 20 | Definition | DONE definition only; next five Jovian instances below, all other craft/roles remain unscheduled | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-PASSENGER-EXIT | Original passenger reaches supported ground while pilot retains helm | 16,20,26 | Qualification | DONE on861c4d39b, merged2352d18c3: original full138.470s journey PASS clean, all seven physical route poses, same-player supported ground walk, legitimate passenger claim/body retirement, retained pilot and actual3peer exits0. Paired checkpoint861c4d3; exact-tip local/remote/tracking branch deletion and owned cleanup complete. Broader postdock reuse remains separate. [Acceptance](history/ROADMAP_DELIVERIES.md#physical-jovian-passenger-exit-accepted-and-branch-closed--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-DOCKED-PILOT-HOLD | A still-owned remote pilot retains the committed authoritative dock pose/velocity | 16,20,26 | Qualification | DONE within accepted passenger-exit chain861c4d39b, merged2352d18c3. Pose322 regression PASS; final original138.470s three-peer journey retains exact committed home/pilot/source through supported passenger exit and actual3OS exits0, no diagnostics. Paired checkpoint861c4d3; branch/owned cleanup complete. Same integration and build as EXIT, not a separately counted delivery. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-PASSENGER-REBOARD | Original passenger reclaims original co-pilot chair | 16,20,26 | Qualification | DONE scoped ordinary three-peer Linux journey49bc7b736. Full original departure/home landing/physical exit/groundwalk/reboard/fresh chair PASS149.242s; both clients consume exact chair, original pilot and strict home lease retained;3actualOS0/clean logs. Actual unconsumed pre-bind hatch ID identified; producer retires old edges while preserving fresh/retry behavior. Source98/body42 PASS; fresh paired checkpoint/strict menus/package audit and independent review GO; owned scratch removed. Full parent/baseline/endurance/native gates remain open. [Delivery](history/ROADMAP_DELIVERIES.md#jovian-passenger-reboard--accepted--2026-10-20). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-PILOT-EXIT | Original pilot releases helm and walks onto supported berth ground | 16,20,26 | Qualification | DONE scoped ordinary three-peer Linux journey63186dc80. Complete accepted passenger prefix, original pilot authored exit and1.255m supported walk; exact old authority/source/queue/seat/body/publication retired, both clients consume release, passenger chair and strict occupied home lease retained. PASS153.310s/3actualOS0/cleanlogs. Initial impossible pose-header check corrected with fresh same-hull retirement-boundary comparison; original failure retained. Runtime unchanged49bc7b7; owned scratch removed, main sole branch. [Delivery](history/ROADMAP_DELIVERIES.md#jovian-original-pilot-exit--accepted--2026-10-20). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-PILOT-RECLAIM | Original pilot returns to same hull and acquires current helm authority | 16,20,26 | Qualification | DONE07ec703c7; full physical reuse and actual retired-stream refusal | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-JOVIAN-REDEPART | Same crew/hull departs at least5m and brakes after physical reuse | 16,20,26 | Qualification | DONEbc7f9f9c4; full ordinary pilot/co-pilot reuse journey, actual berth release and stopped peer convergence | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CONVOY-ACTOR-DEFINE | Uncovered Convoy tender live/dead/reset/late/disconnect cases | 22 | Definition | BLOCKED definition — Codex must map existing Convoy live/dead/reset/late/disconnect cases to actual tender/threat owners, participant actions, retirement and usable solo-restoration endpoints; no additional actor catalogue. | Finite uncovered Convoy live/dead/reset/late/disconnect cases with actual tender/threat owner, participants/action/retirement/solo-restoration; no new actor catalogue. |
| TORPEDO-AUTH-DEFINE | Actual projectile authority, retained solo restoration and pilot/target loss | 23 | Definition | DONE definition only; ten finite qualification cases below, no new missing production consumer or runtime defect established. Ordinary/independent packaged routes remain OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| PICKET-ACTOR-DEFINE | Uncovered Picket travelling actor/late/dead/reset/disconnect cases | 24 | Definition | BLOCKED definition — Codex must bind existing Picket live/dead/reset/late/disconnect cases to actual travelling actor/moving crew, exact command/cut and no-replay/no-double-hit/usable-restoration endpoint. | Finite uncovered Picket live/dead/reset/late/disconnect cases using actual travelling actor and moving-crew owner; named participants/result. |
| EMBERLINE-ACTOR-DEFINE | Uncovered Emberline flight/hit/miss/expiry/late/dead/reset/disconnect cases | 24 | Definition | BLOCKED definition — Codex must bind existing flight/hit/miss/expiry/late/dead/reset/disconnect cases to actual actors/participants, exact command and retirement/usable-continuation endpoint; original failed baseline remains PARKED. | Finite uncovered flight/hit/miss/expiry/late/dead/reset/disconnect cases in actual Emberline; failed original baseline retained. |
| NET-BROWSER-PAUSE | Paused LAN Refresh and host answering | 25 | Capability | DONE packaged042c701e2; real automatic paused loopback27/default GameFlow7 pass; full ordinary menu/endurance gates separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| BROWSER-JOIN | Discover/refresh/select/join ordinary browser route | 25 | Qualification | Source ordinary-route qualification DONE80abab3b1: real LAN/authenticated join, both same-Player connected and solo walks after normal Disconnect/Refresh/Back/Resume,294 assertions/86.310s, actual OS0/no diagnostics. Package/device/native/endurance/final-candidate scope remains GATED; [exact result](history/ROADMAP_DELIVERIES.md#browser-join-supported-walking-20261025). | [Ordinary browser](#proof-network): Discover/refresh/select a live joinable session → actual admission and usable gameplay → disconnect → usable browser/menu. A refusal fails this goal. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-STALE | Stale session ordinary browser route | 25 | Capability | DONEca149d6 scoped source InputEvent/LAN production behavior. Explicit30s engineering default from last valid reply, paused monotonic expiry, exact LAN row/endpoint retirement and stalejoinpreflight beforeintent/rolechanges. Natural actualexpiry30.003631s; zero staleintents/admissions; honestexpiredUI/Retryfocus, actualRetryrediscoverssamehost, originalPlayerfreshjoin and4supportedwalks/normalDisconnect+soloreturn. Whole314checks/116.907s, twoactualOS0/zero diagnostics; focusedLAN42/expiry8/default7/presenter83/HUD40 pass. FreshcleanWindowsEXE/ZIP/notes, strictpayloadmenu startup0/sentinel1/zero diagnostics,1527-entry inventory/stockPEtext/exactZIP, independentruntime+packageGO andownedcleanup. Existing abstract30ticks hasno seconds mapping; optionaldurationpreference isnotapproval. Originalcaps/90mininclprior10 preserved; no failures/retries. MatchingLinuxca149d6 is now separately startup-qualified with exact Windows payload parity; no packagedordinary/native/device/capacity/endurance/finalqualification claim. [Delivery](history/ROADMAP_DELIVERIES.md#lan-browser-expiry-accepted--2026-10-25). Separately parked unreachable route is not replayed. | [Ordinary browser](#proof-network): Select a frozen expired session row → no admission → terminal stale/unavailable feedback → usable refresh/retry/back. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-FULL | Full session ordinary browser route | 25 | Qualification | DONE e39653cf in source InputEvent/LAN UI-refusal scope. Real one-slot host+authenticated occupant; third Main sees actual1/1 FULL row, ordinary pointer press/release reaches disabled UI and creates zero activation/join/admission. Real Refresh advances directory1→2; Back/Begin Shift retains same supported Player for1.002774m walk/12neutral ticks. Original occupant stable; host counts0→1→0, all3 actual OS exits0, coordinator209 checks/125.781s/zero diagnostics. First121.373s coordinate failure retained; one caller-only final-transform correction, no runtime/cap change. Independent source/raw GO, pushed main/local task branch+owned scratch cleaned. No transport-refusal or release-capacity claim; package/device/native/endurance/final gates remain separate. [Exact scope](history/ROADMAP_DELIVERIES.md#browser-full-ui-refusal-accepted-20261025) | [Ordinary browser](#proof-network): Select a genuinely full session → refused admission with accurate full feedback → usable alternative/retry/back. Admission fails this goal. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-UNREACHABLE | Unreachable endpoint ordinary browser route | 25 | Qualification | OPEN as a whole. Separate silent/no-answer source case DONE bd61da07: real bound non-answering UDP endpoint, paused native CONNECTING attempt naturally times out at 5,005 ms; visible timeout/current fenced Retry, complete retirement; actual Retry creates fresh native attempt, prompt Cancel closes it, same guest Main/Player then joins independently matched live Main host as 1079334082/gen1. Four supported 1.002774 m connected/solo walks, 12 neutral ticks/zero drift, 522 passive samples, host counts 0→1→0 and both actual OS exits 0. Whole source/InputEvent/Xvfb/Dummy route 335 checks/92.784 s/zero diagnostics; initial 1.280 s parse failure preserved, one reviewed explicit-bool correction; source/cache/pin guards and cleanup pass. No runtime change or identical export. SEPARATE reachable-ENet/non-admission packaged route e944f52 remains PARKED at timeout native-cache diagnostic, source under archive/withheld/browser-release-cache-20261020; no causal runtime fix or replay. Package/device/native/controller/capacity/endurance/final gates open. [Source-case result](history/ROADMAP_DELIVERIES.md#browser-no-answer-source-accepted-20261025). | [Ordinary browser](#proof-network): Attempt the frozen unavailable endpoint → existing bounded terminal failure/no admission → no surviving session owners → usable retry/back. Preserve parked failure and original deadlines. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-CONTROLLER | Controller menu navigation ordinary browser route | 25 | Qualification | GATED; chosen candidate/scenario, delivered UI fixes retained. BLOCKED definition — Codex: bind existing controller buttons and expected focus/action for discovery, selection, admission, gameplay, Disconnect and browser return; name participants, endpoint, route/command, count, original deadlines and terminal exits. BLOCKED input — user only if unavailable: actual supported controller/backend and isolated-session access. Synthetic events do not satisfy the physical-device result. | [Ordinary browser](#proof-network): Actual physical controller discovers/selects a live session, joins usable gameplay, disconnects and returns to enabled browser/menu focus; freeze existing required buttons before execution. Synthetic input does not qualify. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-DISCONNECT | Disconnect/retry ordinary browser route | 25 | Qualification | DONE035fa2f scoped Linux-source InputEvent/LAN ordinary route: complete normal first join/walking/Disconnect/old transport+authority retirement/solo/fresh Refresh+authenticated rejoin/second connected walking/second retirement/final solo+hoststop. Both original Players retained; matched tuple659889361/1→514425711/2; hostcounts0→1→0→1→0, seven supported walks1.002774m with12neutral ticks each. Whole510checks/88.888s, actual2OS exits0/zero diagnostics. Both earlier caller failures retained; normalized identity fields and actual pre-assert observation, no runtime/cap change. Independent source/raw GO; integrated/pushed and owned cleanup. Original75min08:15:10Z clock includes intervening package task. Package/device/endurance/capacity/final gates remain open. [Accepted result](history/ROADMAP_DELIVERIES.md#browser-disconnect-rejoin-accepted--2026-10-25) | [Ordinary browser](#proof-network): Join an actual live session → ordinary Disconnect → old transport/authority retired → usable browser → fresh successful admission and usable gameplay. No stale session reuse. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| BROWSER-CANCEL | Cancel/reuse ordinary browser route | 25 | Qualification | DONE ed29733 in Linux-source InputEvent/Xvfb/Dummy scope. Two actual native CONNECTING attempts to the settled owned UDP non-answering endpoint are cancelled through ordinary UI; both peers closed, pending identities/deadlines and authority cleared. Same guest Main/Player then discovers and joins actual live Main host as matched 848552394/gen1 using a fresh native peer. Passive guard passes 270 samples; four supported 1.002774 m connected/solo walks, 12 neutral ticks and zero drift; host counts 0→1→0, both actual OS exits 0. Complete route 351 checks/86.223 s/zero diagnostics. First 82.671 s failure retained: obsolete disabled/Back assertion conflicts with current enabled Retry Connection contract; one reviewed caller-only correction passes original limits. Independent raw/source review GO, owned processes/scratch cleaned. Game code unchanged; no identical checkpoint export. Package/device/native/capacity/endurance/final gates remain open. [Delivery](history/ROADMAP_DELIVERIES.md#browser-cancel-reuse-accepted-20261025). | [Ordinary browser](#proof-network): Begin an actual pending connection → ordinary Cancel before admission → transport/owners retired → usable browser → fresh successful join. No later callback admits the cancelled request. Freeze exact candidate, endpoint/participants, existing command and original limits; no unchanged parked rerun. |
| SERVER-BASELINE-DEFINE | Residual authoritative-server/two-client gameplay command and cases | 26 | Definition | Definition DONE; Halyard BOARD accepted4bc0e3b38, full original MOVING-CABIN accepted2e117e64f. AUTHORITY-STOP accepted082da79c9 with real host shutdown/client recovery after full moving prefix; complete server baseline remains open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-APPROACH | Freeze ordinary spawn-to-airstair input waypoint route | 16,26 | Definition | DONE definition; native aft/fleet chain and authored final extension, no collision qualification | Accepted source waypoint/input route only; retain its existing source binding. Physical collision, boarding and moving-cabin acceptance remain with HALYARD-BOARD and HALYARD-MOVING-CABIN. No repeated definition pass or route promotion. |
| HALYARD-BOARD | Non-playing Main authority and two original ordinary occupants | 16,26 | Qualification | DONE 4bc0e3b38: complete original menus/spawn/walk/actual pilot+crew_port_00 boarding and host/client consumed identities, ownership/body/frame/seat/claim generations, controls/HUD; all three actual OS exits0/terminal handshake pass in 130.472s. Same suite300/outer360/8s transition. Branch merged/pushed/deleted; earlier 271.737s failures retained. No runtime change/new identical checkpoint. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-ordinary-boarding-branch-finished--2026-10-20) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-MOVING-CABIN | Actual departure with passenger supported walk/chair cycle | 16,24,26 | Qualification | DONE current-source2e117e64f: same ordinary-board actors, actual pilot departure5.175m, host-confirmed passenger walk>.6m/local1.181m, stand/sit/stand/reseat during actual hull motion, current body/frame/role/ownership and both consumed presentations; claims1→3→5. Full141.298s/270checks/one marker/three actual OS0/zero diagnostics; original caps unchanged. First141.234s caller failure retained, observer engine consumer corrected once. [Accepted full case](history/ROADMAP_DELIVERIES.md#halyard-ordinary-moving-cabin--accepted--2026-10-20); authority-stop accepted separately082da79c9, endurance/package/native/full baseline remain open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-AUTHORITY-STOP | Real server stop restores both remaining occupants to solo play | 16,26 | Qualification | DONE082da79c9: full original BOARD/MOVING prefix, same non-playing host stops once with original occupants aboard, both actual server_disconnected/session_stopped events, old grant/body/prediction/seat/helm retirement; solo pilot throttle, same supported passenger walk0.616m and both real pause/Resume. Full142.082s/307checks/one marker/three actual OS0/zero diagnostics; original caps unchanged. Two compile-only fixes retained, independent GO, owned scratch removed. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-real-authority-stop--accepted--2026-10-20). Current Linux source only; full baseline/endurance/native/reconnect/migration remain open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-PASSENGER-DESTRUCTION-RECOVERY | Current host hull loss, supported same-Player recovery and ordinary regenerated-ship reuse | 21,26 | Qualification | DONEf5b71e06e/checkpointf5b71e0: complete original BOARD+seven MOVING stages, actual host destruction/old body+claims retirement, both usable recoveries/pause/Resume, normal host regeneration, full station return/hatch entry, fresh body streams/role/ownership and renewed flight. 382 checks/197.131s/all3actualOS0; focused69, crew bridge19 and eleven existing regressions pass. Clean paired exports/strict startup/package audit pass; ten commits integrated/pushed and owned scratch removed. Full component repair/NET-DAMAGE, wider craft/role/baseline/endurance/native gates remain open. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-passenger-destruction-recovery-and-reuse--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-NETWORK-REPAIR-PANEL | Physical cabin repair readout follows current host facts for seated/walking clients | 21 | Qualification | DONEce2329a82/checkpointce2329a: focused28 and original real ENet engineer79 checks pass, actual host repair/one kit spend, panel progress/completion/5 remaining kits, standing refresh and raw client authority isolation. Missing current view waits honestly; leave/stop restores local. Actual ENet is PASS_WITH_ENVIRONMENT_WARNING (one Xvfb/llvmpipe V-Sync capability warning; strict logs NOT_CLEAN), zero game errors/allpeerOS0. Existing regressions and full destruction/reuse382 pass; clean paired exports/strict startup verified; merged/pushed/ownedcleanup complete. Full roster/NET-DAMAGE/native/baseline/endurance remain open. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-network-cabin-repair-readout--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-NETWORK-ROSTER-PANEL | Physical cabin roster/readiness/routing/handoff follows current host facts for seated/walking clients | 16,21,26 | Qualification | DONEa0764f281/checkpointa0764f2. Compact actual host display facts use existing engineer publication/current admission fences; seated/walking panel, ordinary engineer release, local-refresh persistence and retirement restore correct current/local state without client gameplay authority. Focused40 after two expected RED failures; original real ENet engineer82 checks/101.641s/all peerOS0, existing companions PASS. Real route PASS_WITH_ENVIRONMENT_WARNING (one Xvfb/llvmpipe V-Sync warning; strict NOT_CLEAN), zero game errors. Fresh paired exports/three strict startups/1527-entry payload and package audit/review pass; merged/pushed/owned cleanup complete. Real pilot open; positive readiness focused/staged; active emergency handoff/full NET-CREW/NET-DAMAGE/baseline/native remain open. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-network-cabin-roster--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| HALYARD-NETWORK-SEAT-REJECTION | Current remote occupied-chair refusal shows one accurate request-bound toast and permits fresh retry | 16,26 | Qualification | DONEbcd268c75/checkpointbcd268c. Actual host delegated seat_occupied verdict retains body/stream/request/seat/epoch and original binding lifetime; current requester-only passenger snapshot yields one accurate toast, supported controls, fresh refusal and release/retry. Full original host/client route107 checks/107.305s/bothactualOS0/cleanlogs, focused101/36/66/6/40/privacy PASS; expected RED/nullnumeric strictfailure/parser failure retained, exact source reuse verified. Fresh paired exports/three strict startups/1527-entry package audit/review pass; four commits merged/pushed, owned scratch/results cleanup complete. Full two-client moving seat race/transfer, other reasons/roles, native/fullbaseline remain open. [Delivery](history/ROADMAP_DELIVERIES.md#halyard-occupied-chair-feedback--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |


| SERVER-BASELINE | Dedicated-server/two-client ordinary flight/recovery acceptance | 26 | Container | NON-EXECUTABLE container — only the original authority/two-client ordinary journey and named lifecycle/adverse cases in SERVER-BASELINE-DEFINE; accepted children retained. Codex must record any still-unbound original case command/trigger/result/cap before selection; missing values are BLOCKED definition. PARTIAL: original pilot-disconnect case DONE21817ab4b after full ordinary BOARD+7MOVING stages; actual host and adapter disconnect once, departed pilot authority retired, surviving passenger body/frame/claim preserved then ordinary stand/reseat claim5→7, departed samePlayer solo throttle+pause/Resume.145.446s/threeactualOS0/cleanlogs; reviewed/merged/pushed/ownedcleanup complete. Earlier BOARD/MOVING/AUTHORITY-STOP retain their accepted scopes. Halyard ordinary chair contention/transfer is DONE99c9fc1af (separate child below). Halyard airborne late join/docking pickup is DONE437fe903d (separate child below). Other craft/role seat races/transfers, other late-join contexts, impaired/stalled networking, other boarding/landing disconnect cuts, reconnect, other destruction contexts, Main re-entry and supported-platform/full-baseline gates remain; no unchanged rerun scheduled. Ordinary moving passenger-disconnect case DONE503350e32: full BOARD+seven MOVING, real passenger shutdown and once-only removal, retained pilot grants/fresh authority throttle, same-Player supported solo walk/pause/Resume, all3actualOS0 and clean logs142.626s. Source-only/private-Xvfb scope, runtime unchanged; original failures and causal caller corrections retained. [Accepted case](history/ROADMAP_DELIVERIES.md#server-baseline-passenger-disconnect--accepted--2026-10-24). Moving sleep/wake DONE8b0845486: full BOARD+seven MOVING, physically reached Port bunk, host/local reservation/posture agreement and consumed sleeping/walking, visible wake controls, supported1.212m walk, physical return and fresh same-chair claim7/gen1;159.806s/428checks/all3actualOS0. Runtime unchanged and source/private-Xvfb scope only. [Sleep result/limits](history/ROADMAP_DELIVERIES.md#server-baseline-moving-sleepwake--accepted--2026-10-24). [Accepted case/command](history/ROADMAP_DELIVERIES.md#server-baseline--ordinary-client-pilot-disconnect-accepted--2026-10-21) | [Network](#proof-network): full original authority/two-client ordinary flight/dock/exit/reuse and each named lifecycle/adverse case terminal; accepted narrow cases do not close parent. |
| SERVER-BASELINE-SEAT-RACE | Original two moving occupants contend for one chair, transfer it, restore roles and fly again | 16,26 | Qualification | DONE99c9fc1af. Full original BOARD+seven MOVING; ordinary brake/accepted OFFLINE/helm release, supported contenders, same ready/go real Interact, one claimed winner/one seat_occupied loser and exact once-only toast. Ordinary winner stand/clear, original loser same-chair claim7→10/gen1, original pilot ownership1→3/claim2→5 and passengerclaim12, fresh consumed roles/renewed host>5m flight, complete handshake/all3actualOS0. Full451checks/170.190s/cleanlogs; independent source/raw review GO. Three caller failures retained; readiness/path/JSON corrections preserve all caps/goals/predicates. Four commits merged/pushed,66processidentities absent/811scratch entries verifiedremoved/resultsconsolidated; no taskbranch/worktree. Runtime unchanged/checkpointbcd268c retained; sourceLinux/privateXvfb only. Fullbaseline/endurance/exported/native/device/human and broader parents remain open. [Delivery](history/ROADMAP_DELIVERIES.md#server-baseline-seat-race--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SERVER-BASELINE-LATE-JOIN | Join after real departure, consume airborne state, board after actual docking and fly as crew | 26 | Qualification | DONE437fe903d. A ordinary authored pilotboarding/5.019m actualdeparture before Bprocess starts(+.158s); B HUDjoin/freshairborne craft/owner/pilotbody while unclaimed stationPlayer. Sole sampledlanding/strict actualhomeberth+lease+committeddock consumed byboth; originalpilotclaim2/gen1/bodyframe1/ownership1 preserved. B full17-waypoint authored walk/hatch/chair, fulltwo-seatBOARD+sevenMOVING/completehandshake/3actualOS0.303checks/225.667s/cleanlogs; independent source/rawGO. Two earlier callerfailures retained: soleowner noecho publication assumption and absentlandingtarget_id. Existingsolepilothelper beforeB/strictbroadcast after, realcanonicalentity/gen/landed/revision/tick/globalposition plusauthoredberth replace impossiblewirefield; no runtime/endpoint/capchange. Three commits merged/pushed;47ownedprocessidentitiesabsent/380scratch entriesverifiedremoved/resultsconsolidated; no taskbranch/worktree. SourceLinux/privateXvfb only, unchangedcheckpointbcd268c. Fullbaseline/endurance/othercontexts/exported/native/device/human remainopen. [Delivery](history/ROADMAP_DELIVERIES.md#server-baseline-late-join--accepted--2026-10-24). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SERVER-BASELINE-PASSENGER-RECONNECT | Rejoined Halyard passenger physically obtains a fresh cabin berth/chair and flies again | 16,26 | Qualification | DONE109aca01f, Linux-source ordinary-input scope. Full original BOARD+7MOVING/actual native B loss/retirement/solo walk/same Player+adapter normal browser Manual Join/pilot actual return+strict original home dock/physical fresh berth+walk+separate chair/renewed real flight/3OS0 passes397 checks in171.746850s, zero diagnostics. Return7.29249s/dock6.23802s within original20/24; all original global/local caps unchanged. First171.149352s functional397 run rejected for3crew-role send errors; native-recipient guards repair exact engineer/gunner/passenger send paths,39real-ENet regression/fresh Windows checkpoint109aca0/strict startup1527inventory/review GO. Earlier compile failures and d2 unaccepted source remain archived; no clock reset. Package/native-device/endurance/capacity/final scope separate, no whole-parent closure. [Full result](history/ROADMAP_DELIVERIES.md#ordinary-passenger-reconnect-accepted-20261025). | Original BOARD+7MOVING→actual B transport loss/retirement/usable solo→same Player/adapter normal Manual Join→A actual input return/strict dock→physical standing-berth request/later chair→renewed flight/three OS0. No automatic old grant restore. |

| SERVER-BUNK-AUTHORITY | Client rest follows the host-selected ship bunk and refusal outcome | 26 | Qualification | DONEf6803cf26/checkpointf6803cf: real host/client contested Port→Starboard selection, both-busy refusal/feedback, freed retry/wake, sleeping-client shutdown/current-exit recovery and subsequent solo sleep/wake pass116 checks. Full original three-Main moving sleep journey428 checks and existing rest/lifecycle/content/privacy pass. Scoped GameFlow consumer; existing host policy/protocol retained. Fresh paired packages/strict startup verified; native/full baseline/endurance gates remain open. [Result and retained limits](../ROADMAP.md#execution-now). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-FULL-SNAPSHOT | All-nine forced-full publication and byte budget | 17,26 | Capability | DONE on accepted330a39ce3 in existing Main/ENet suite: actual complete nine-craft full/live4656/4656 bytes, exact decode and fragment acceptance under unchanged12000. [Retained result](history/ROADMAP_DELIVERIES.md#net-component-powers--host-output-and-bounded-live-updates-accepted). Ordinary/native/endurance/final-candidate gates remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-PROFILES-DEFINE | Original latency/loss/jitter/reorder/stall profile roster | 26 | Definition | DONE definition only; MOVING_INTERIOR_LATENCY finite contract names five stream profiles, narrow three-process command injection and two physical host-stall actions; impaired independent session/endurance remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| NET-ENDURANCE-DEFINE | Executable original 30-minute independent two-client moving-interior route | 26 | Definition | BLOCKED input/implementation — bounded recovery confirms no existing complete command; original30min/server+two independentclients/100ms RTT/2%loss remain fixed. Exact unprovided profile/tolerances/stall schedule/forced-critical aggregate traffic/mapped tick drift/backlog drain/resource ceilings now have one [literal proposed contract](MOVING_INTERIOR_LATENCY.md#endurance-execution-handoff--proposed-limits-2026-10-25), awaiting adoption or replacements; no defaults represented as original values. Private user+network namespace and netem availability probe exits0, no game/traffic. Existing normal8/24,000-byte window is a coalescing threshold with counted critical bypass, not a hard aggregate ceiling. Existing ordinaryHalyard and process seams identified; actual shaping/1800s driver/continuous measurements still need implementation after values fixed. No engine/profile/fullrun or threshold relaxation. | Exact independent-process30-minute route/profile: original100msRTT/2%loss, explicit jitter/reorder/stall, queue/tick/bandwidth ceilings, equivalent-phase leak measurement and cleanup. |
| NET-ENDURANCE | Original 30-minute moving-interior session | 26 | Qualification | GATED on SERVER-BASELINE and NET-ENDURANCE-DEFINE: adoption/replacement of the existing proposed impairment/metric table, then Codex delivery of the isolated-link independent-process1800s driver. The proposal remains unapproved; no executable endurance command currently exists. | On the bound candidate, one authority and two independent clients complete1800s ordinary moving-interior play at original100msRTT/2%loss and the adopted jitter/reorder/stall schedule. Every adopted bandwidth/tick-drift/backlog-drain/equivalent-phase resource ceiling and terminal ownership/cleanup predicate passes; retain all three actual process exits. Missing adopted value, driver, workload or metric binding keeps qualification GATED; short synthetic tests cannot close it. |
| SHARED-EMBER-BASELINE | Ember shared canonical outbound/physical survey/reward/save/home return | 3,27 | Qualification | BLOCKED definition (Codex), one Ember baseline only: record craft, independent participants and physical roles, ordinary outward/relay-survey/reboard/home route, exact authored result/save/payment endpoints, existing caller/command and original limits. Reuse the existing seven-case world contract. Stop with that executable baseline or the exact unavailable caller/artifact/input and owner; no engine run or follow-on case is selected. | Actual ordinary crew outward flight, physical Ember survey and authored durable result/save, reboard and full strict home/OFFLINE/physical exit on the fixed participants/candidate. Record once-only payment/progress and supported continuation. Parents3/27 share this single baseline; defining the route does not qualify it. |
| SHARED-EMBER-LATE-JOIN | Ember shared late join | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/LATE-JOIN still needs joining peer/role and exact live transit or surface join phase; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/LATE-JOIN: current actors/progress consumed without launch or reward replay. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-EMBER-RECONNECT | Ember shared disconnect/reconnect | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/RECONNECT still needs peer/role, actual transport-loss cut and rejoin phase/claim handback; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/RECONNECT: drop/rejoin restores the supported role or its settled handback without duplicate claims. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-EMBER-PILOT-LOSS | Ember shared pilot loss | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/PILOT-LOSS still needs pilot/committed phase and named successor or safe-recovery owner/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/PILOT-LOSS: pilot loss transfers or safely retires authority and completes the bound return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-EMBER-CANCEL | Ember shared cancellation | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/CANCEL still needs actual cancellation caller, phase and protected progress/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/CANCEL: real cancellation retires visit/actors/claims and preserves protected progress on return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-EMBER-INTERRUPT | Ember shared actual OS interruption | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/INTERRUPT still needs committed durable kill cut, exact protected progress/payment and distinct-process recovery endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/INTERRUPT: owned kill/reap and distinct normal restart preserve the fixed durable state once. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-EMBER-REVISIT | Ember shared repeat visit | 3,27 | Qualification | GATED; EMBER genuine baseline and exact original case command. BLOCKED definition (Codex): EMBER/REVISIT still needs legitimate normal readmission trigger and first/second-visit endpoints/progress; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | EMBER/REVISIT: physical second admission preserves once-only progress/reward and full home return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-BASELINE | Aurora shared canonical outbound/physical survey/reward/save/home return | 3,27 | Qualification | WAITING; original 47ffce740 bundle. BLOCKED definition (Codex): AURORA/BASELINE still needs ordinary craft/peer-role roster, full outward/surface result/save and home endpoints; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/BASELINE: ordinary outward/surface activity/durable result/save and full physical home/exit. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-LATE-JOIN | Aurora shared late join | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/LATE-JOIN still needs joining peer/role and exact live transit or surface join phase; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/LATE-JOIN: current actors/progress consumed without launch or reward replay. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-RECONNECT | Aurora shared disconnect/reconnect | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/RECONNECT still needs peer/role, actual transport-loss cut and rejoin phase/claim handback; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/RECONNECT: drop/rejoin restores the supported role or its settled handback without duplicate claims. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-PILOT-LOSS | Aurora shared pilot loss | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/PILOT-LOSS still needs pilot/committed phase and named successor or safe-recovery owner/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/PILOT-LOSS: pilot loss transfers or safely retires authority and completes the bound return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-CANCEL | Aurora shared cancellation | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/CANCEL still needs actual cancellation caller, phase and protected progress/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/CANCEL: real cancellation retires visit/actors/claims and preserves protected progress on return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-INTERRUPT | Aurora shared actual OS interruption | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/INTERRUPT still needs committed durable kill cut, exact protected progress/payment and distinct-process recovery endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/INTERRUPT: owned kill/reap and distinct normal restart preserve the fixed durable state once. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-AURORA-REVISIT | Aurora shared repeat visit | 3,27 | Qualification | GATED; AURORA genuine baseline and exact original case command. BLOCKED definition (Codex): AURORA/REVISIT still needs legitimate normal readmission trigger and first/second-visit endpoints/progress; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | AURORA/REVISIT: physical second admission preserves once-only progress/reward and full home return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-BASELINE | Rime shared canonical outbound/physical survey/reward/save/home return | 3,27 | Qualification | PARKED/open. Original58.083simulation-seconds/120s wall failure retained. Full restored two-crew cost captured9a073c98 stillFAIL1624.422s at peer host.landed gate.105 usable sampled script frames, noEND/ACCUMULATED; Halyard/native attribution unresolved and controllerleg=-1 unavailable. No supported repair/retry or cap change. Source bundled, both owners terminal/19 identities absent/64 scratch entries archived verified removed. Original120s/2400s and full scope preserved. BLOCKED definition (Codex): RIME/BASELINE still needs ordinary craft/peer-role roster, full outward/surface result/save and home endpoints; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/BASELINE: ordinary outward/surface activity/durable result/save and full physical home/exit. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-LATE-JOIN | Rime shared late join | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/LATE-JOIN still needs joining peer/role and exact live transit or surface join phase; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/LATE-JOIN: current actors/progress consumed without launch or reward replay. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-RECONNECT | Rime shared disconnect/reconnect | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/RECONNECT still needs peer/role, actual transport-loss cut and rejoin phase/claim handback; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/RECONNECT: drop/rejoin restores the supported role or its settled handback without duplicate claims. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-PILOT-LOSS | Rime shared pilot loss | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/PILOT-LOSS still needs pilot/committed phase and named successor or safe-recovery owner/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/PILOT-LOSS: pilot loss transfers or safely retires authority and completes the bound return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-CANCEL | Rime shared cancellation | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/CANCEL still needs actual cancellation caller, phase and protected progress/return endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/CANCEL: real cancellation retires visit/actors/claims and preserves protected progress on return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-INTERRUPT | Rime shared actual OS interruption | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/INTERRUPT still needs committed durable kill cut, exact protected progress/payment and distinct-process recovery endpoint; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/INTERRUPT: owned kill/reap and distinct normal restart preserve the fixed durable state once. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |
| SHARED-RIME-REVISIT | Rime shared repeat visit | 3,27 | Qualification | GATED; RIME genuine baseline and exact original case command. BLOCKED definition (Codex): RIME/REVISIT still needs legitimate normal readmission trigger and first/second-visit endpoints/progress; bind its existing caller/route/limits in [the seven-case world contract](#proof-world). | RIME/REVISIT: physical second admission preserves once-only progress/reward and full home return. Preserve this row’s recorded artifacts and world prerequisites; parents3/27 share this one result. |

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

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| PERF-MINIMUM | Bind actual minimum-spec machine/profile | 28 | Resource | WAITING; representative isolated hardware | Record actual minimum machine/OS/CPU/RAM/GPU/driver/resolution/quality, isolated access and intended workloads; this resource/profile goal does not claim a measurement pass. |
| PERF-TARGET | Bind actual target-spec machine/profile | 28 | Resource | WAITING; representative isolated hardware | Record actual target machine/OS/CPU/RAM/GPU/driver/resolution/quality, isolated access and intended workloads; this resource/profile goal does not claim a measurement pass. |
| PERF-ROUTES-DEFINE | Required representative workloads beyond the seven existing selectors, with whole-expedition repetition mapped to world endurance | 28 | Definition | BLOCKED definition — Codex must bind the seven existing selectors and existing world-endurance journeys to original requirements, recording any uncovered original workload once; no optional craft/cabin/world axes. Missing original workload intent is user input. | One closed workload list binds all seven existing selectors and existing world-endurance journeys to original performance requirements. It fixes the uncovered Phase10.4 whole-expedition craft/world/cycle or records the precise owner choice still required. Machine identities are exclusively PERF-CELLS-DEFINE dependencies; unavailable hardware does not block naming workloads. Additional craft/cabin/combat workload requires an identified uncovered original requirement. Every original workload is covered or dependency-blocked; then PERF-CELLS-DEFINE binds commands/numeric budgets. Do not reopen the roster without a demonstrated gap. |
| PERF-CELLS-DEFINE | Applicable machine/route measurements | 28 | Definition | BLOCKED definition/input. Codex binds the finite PERF-ROUTES list to PERF-MINIMUM/TARGET identities and exact commands. Preserve the original warmup/measurement/frame/memory budgets; enumerate each missing GPU/VRAM/network/streaming ceiling by name. User supplies actual unavailable machines/access and genuinely unspecified ceilings. Stop at the finite list or those exact blockers; no performance run, optional axes or inferred threshold. | One literal machine/workload/command/metric/ceiling/abort list. Each required field has a source-backed value or an explicitly named unavailable input and owner. A blocked answer ends this definition attempt and cannot mark PERF measurement accepted. Existing floors remain ≥60s/3600 warmup frames, ≥600s/18000 measured frames, 1080p High p95≤16.7ms/p99≤33.3ms, no post-warm frame>100ms, working set≤4GiB. |
| INPUT-KBM | Physical keyboard/mouse ordinary full route | 8,18,29 | Qualification | BLOCKED definition—Codex: finite action→effect roster, ordinary route, run count, original caps and termination/proof; BLOCKED input—user: actual physical device/backend and isolated-session access. Supplying hardware does not complete the route definition; synthetic coverage does not satisfy physical acceptance | Actual physical keyboard/mouse: bind the existing production InputMap/help actions for menus, walking, boarding, piloting and supported role interaction to one named ordinary route/device/backend. Record each action→expected effect; actual remap/apply/conflict/reset and distinct-restart persistence, enabled menu focus and usable gameplay return must pass. Existing sampled HELM proof is retained; synthetic input is insufficient. |
| INPUT-CONTROLLER | Physical controller ordinary full route | 8,18,29 | Qualification | BLOCKED definition—Codex: finite action→effect roster, ordinary route, run count, original caps and termination/proof; BLOCKED input—user: actual physical device/backend and isolated-session access. Supplying hardware does not complete the route definition; synthetic coverage does not satisfy physical acceptance | Actual physical supported controller: bind the existing production InputMap/help actions for menus, walking, boarding, piloting and supported role interaction to one named ordinary route/device/backend. Record each action→expected effect; actual remap/apply/conflict/reset and distinct-restart persistence, enabled menu focus and usable gameplay return must pass. Existing sampled HELM proof is retained; synthetic input is insufficient. |
| MIXED-CONTROL-PROMPTS | Grouped help retains mixed button/stick labels independent of action order | 8,29 | Capability | DONEb86264f; actual MOVE/default shorthand, glyph40/camera27/help20 and paired checkpoint; no physical device/whole apply-flight claim | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CAMERA-DISTANCE-PROMPTS | Piloting help exposes both live remapped distance directions | 8,29 | Capability | DONE7718a5a; HUD keyboard/controller labels/reset, focused27/help20 and paired checkpoint. No whole apply/restart/device claim | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| REMAP-DEFINE | Uncovered binding/apply/restart/conflict/recovery cases | 8,29 | Definition | Definition DONE onc1fc23871; original missing on-foot sprint consumer deliveredbd4e15d; its distinct-process option→natural Player endpoint now qualified7570edf7c ([scope](history/ROADMAP_DELIVERIES.md#sprint-toggle-cold-process-qualified-20261025)). Other exact remap/physical/Settings requirements remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ONFOOT-SPRINT-TOGGLE | Advertised shared sprint option works while walking | 8,29 | Capability | DONEbd4e15d0f, packaged. Saved/live/reset/HOLD, actual Player physics sprint speed and control/tree/remote fences pass; existing settings checks retained. Broader remapping/device gates OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| TRACTOR-LOOK-INVERSION | Existing on-foot inversion also controls tractor mouse/right-stick pitch, from saved startup and live edits | 8,29 | Capability | DONE checkpoint34d4b9e: full tractor162, actual Main settings11 and existing runtime settings156 checks PASS; paired exports/three strict startups/package audit PASS. Original headless mouse failure31.933s retained; one isolated X11/dummy-display correction passes all assertions. Physical devices/full ordinary routes/final candidate OPEN. [Result](history/ROADMAP_DELIVERIES.md#tractor-look-inversion--shipped-on-34d4b9e) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-DEFINE | Pause/options readability views and required scale/aspect cells | 12,29 | Definition | DONE; five named aspect groups/three authored scales, actual view states below | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-4X3 | Pause/options at 1024x768, requested scales0.75/1.0/1.6 | 12,29 | Qualification | DONE sourceece9a0253:96actualMainobservations/all32states at3scales bounds/font/focus/scroll geometry only. Existing rendered top1.0/1.4 on59117 accepted in its scope. Additional SIX actual1024x768 normalSettings top/middle/bottom images at literalrequested0.75/1.6 oncac78d22 now inspected, no visible finding; actualeffective0.75/1.010526, scroll0/1234/2469, fixedheading/footer and essentialvisiblelabels fit/readable. Capture8.860s/OS0/marker1/zero diagnostics, privateForward+/llvmpipe/x11/Dummy; rootoriginal-resolutioninspection. Opt-in sameharness capability accepted, runtimeUIcodeunchanged. This is componentrendering only: authoredsnapshotcontrolvalues, no ordinaryslider/valuesync/transaction/focus/Main/device/native/final acceptance; unseenintermediatecontents/otherpopupstates remain unreviewed. Ownedbranch/process/scratch cleanup complete. [Six-view proof](history/ROADMAP_DELIVERIES.md#settings-4x3-extreme-views-inspected-20261025); [earlier top view](history/ROADMAP_DELIVERIES.md#settings-4x3-top-render-inspected-20261025). | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-16X9 | Pause/options at 1920x1080, requested scales0.75/1.0/1.6 | 12,29 | Qualification | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.405s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-16X10 | Pause/options at 1920x1200, requested scales0.75/1.0/1.6 | 12,29 | Qualification | DONE source1cf102298:96 Main observations/all32 states at requested.75/1/1.6; conflict and repair-focus corrections accepted | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-21X9 | Pause/options at 3440x1440, requested scales0.75/1.0/1.6 | 12,29 | Qualification | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.533s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-PAUSE-32X9 | Pause/options at 5120x1440, requested scales0.75/1.0/1.6 | 12,29 | Qualification | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.412s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SETTINGS-SCALED-FOCUS-SCROLL | Fully reveal current Settings focus under scaled pause layouts; ignore stale/duplicate requests | 12,29 | Capability | DONE; paired4d7ac43. Focus59 and complete16:9/21:9/32:9 checks pass. Original21:9 failure33.080s and pre-run review correction retained in history | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-VIEWS-DEFINE | Remaining required HUD/menu/help/role readability views/cells | 12,29 | Definition | DONE as source definition in the finite view roster below; owners/states/coverage and one-cell selection named. No new layout/device qualification. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-FEEDBACK-STATUS | Settings save/recovery and nearby/activity-selection feedback follows current palette role once | 12,29 | Capability | DONE checkpoint2ed93ca: four families/14 callers use unchanged role helper. Existing caller suites11/35/26/113 and HUD layout552, paired exports/strict startups/PCK audit PASS first attempt; no generic matrix rerun. Copy/visibility/actions/focus/authority retained; headless caller/theme scope, full journeys/rendered/device/human/native/final remain open. [Result](history/ROADMAP_DELIVERIES.md#settings-and-activity-feedback-palettes--shipped-on-2ed93ca) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-GAMEPLAY-STATUS | Mode/engine/throttle/hull/component/target-lock labels use current palette role once | 12,29 | Capability | DONE checkpoint941ef73: existing-entry role update/white modulation/steady telemetry guard,256 cases/768 actual paints across32 states/4palettes/2contrast. Full accessibility1979/target-lock6/sensor-reticle90/HUD-layout552 and paired exports/strict startups/PCK audit PASS first attempt. Copy/visibility/thresholds/geometry/authority retained; headless theme scope, rendered/device/human/full journeys/native/final open. [Result](history/ROADMAP_DELIVERIES.md#gameplay-status-palettes--shipped-on-941ef73) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-DESTINATIONS-STATUS | Retained Destination Board status colour follows current state/palette/high contrast without multiplication | 12,29 | Capability | DONE checkpointc47ca33: existing registration role updated once/neutral modulation;32 live Control palette/contrast pairs, full HUD layout552/accessibility443/Main console16 and paired exports/strict startups/PCK audit PASS first attempt. Label identity/text/action/focus and journey authority retained. Headless theme scope; rendered/device/human/full journeys/final remain open. [Result](history/ROADMAP_DELIVERIES.md#destination-board-status-palette--shipped-on-c47ca33) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-HELP[on_foot,1920×1200,0.75] | All four ordinary on-foot context pages fit and retain usable navigation at minimum scale | 12,29 | Qualification | DONE source5ac9d3ef0:124 assertions/30.860s, actual Main, requested/effective0.75, twenty rows/four pages, geometry/font/wrapping/focus/Close pass. Headless source scope only; rendered/human/device/other cells/final candidate remain open. [Scope](history/ROADMAP_DELIVERIES.md#on-foot-help--one-minimum-scale-1610-cell-accepted) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-HELP[aboard,1920×1200,0.75] | All four ordinary aboard context pages fit and retain usable navigation at minimum scale | 12,29 | Qualification | DONE sourcee5dfe1117:124 assertions/31.076s, actual Main/HUD, requested/effective0.75, twenty rows/four pages, geometry/font/wrapping/focus/Close pass. Headless source scope only; rendered/human/device/crew gameplay/other cells/final candidate remain open. [Scope](history/ROADMAP_DELIVERIES.md#aboard-help--one-minimum-scale-1610-cell-accepted) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-TITLE-FOCUS | Focused Begin Shift text on cyan uses the intended readable paint | 12,29 | Capability | DONE checkpoint923d7b3: actual baseline focus1.335/pressed1.713 contrast corrected with local INK overrides; all32 actual-HUD palette/contrast/state pairs clear4.5/7, focus/outline/navigation/layout retained, same-view reviewed and paired package checks pass. [Actual result/limits](history/ROADMAP_DELIVERIES.md#begin-shift-focus-contrast--shipped-on-923d7b3). Other views/states/native/final gates remain open. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-MENU-CONTRAST | Shared menu hover/pressed text remains readable across role palettes | 12,29 | Capability | DONE checkpointd00ae72: shared darker fills/palette-aware text;160 real production menu paints minimum8.359:1, accessibility443/Help20/controller navigation and paired exports/three strict startups/PCK audit PASS first attempt. Normal/focus/layout/actions and local Help CLOSE retained. Headless theme scope; rendered/device/human/broad UI/final gates open. [Result](history/ROADMAP_DELIVERIES.md#shared-menu-contrast--shipped-on-d00ae72) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ACCESS-HELP-CLOSE-CONTRAST | Help CLOSE text remains readable while hovered/pressed | 12,29 | Capability | DONE checkpoint820cc38: local darker fills/palette-aware text;32 actual paint pairs minimum7.767:1 plus existing accessibility252/Help20, paired exports/three strict startups/PCK audit PASS first attempt. Other menu defaults and Help focus/paging/close retained. Headless paint scope; rendered/human/device/broad UI/final gates open. [Result](history/ROADMAP_DELIVERIES.md#help-close-contrast--shipped-on-820cc38) | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| COMFORT-MOTION | Reduced motion route and retained setting | 29 | Container | OPEN — accepted HUD episodes: [active damage cue, checkpoint b5fa554](history/ROADMAP_DELIVERIES.md#active-damage-reduced-motion-accepted-20261025), with exact alpha/hold/original-lifetime limits retained; [current toast, checkpoint 4ca2d16](history/ROADMAP_DELIVERIES.md#current-toast-reduced-motion-accepted-20261025), fully opaque/steady on ON with unchanged content/serial/priority/queue and original normal expiry. Repeated toggles cannot extend/replay either cue; new cues follow the selected mode. Existing 2005-assertion suite, actual readback and paired checkpoints pass. The [eight remaining behavior-changing source families](#reduced-motion--finite-production-consumers) and literal OFF/ON endpoints are now bound on e76fdbc80. Wider goal remains BLOCKED ordinary-route binding—Codex: name each still-unproved normal caller/candidate/profile/deadline; rendered/device acceptance stays open. Do not repeat the consumer survey. Reuse accepted scopes; no unchanged rerun. | Container closes only when every member of its recorded finite episode list passes its literal current/new behavior, ordinary transition, saved setting after distinct restart, authored Reset and preserved objective/control predicates. Existing damage/toast proof is reused. Reuse the linked finite consumer contract and accepted settings proof; remaining normal commands/routes, candidate/profile and original limits must be frozen before selection. Missing ordinary callers remain BLOCKED definition. A genuinely unspecified product behavior is an exact user-owned decision. Selecting one episode cannot close the container. |
| COMFORT-FLASH | Reduced flash route and retained setting | 29 | Container | OPEN — current damage flash episode DONE 1a948d9ac: ON caps effective active alpha≤.07 without brightening dim cues; same Tween/elapsed/running-paused state, .42 flash/.62 arrow fade and expiry. OFF/repeated toggles cannot relight or extend; new hits, pre-ready setters and existing motion hold retained. Existing accessibility suite, actual three-frame readback and paired packages/strict startups/audit pass. [Exact scope](history/ROADMAP_DELIVERIES.md#current-damage-reduced-flash-accepted-20261025). Producer/policy definition DONE2026-10-26: [finite17-family contract](#reduced-flash-producer-and-episode-contract) fixes authored OFF/ON/current/new behavior and common ordinary save/cold/Reset endpoints. Cargo terminal production forwarding is DONE d4e2213 ([proof](history/ROADMAP_DELIVERIES.md#cargo-terminal-reduced-flash-production-binding-accepted-20261026)), with exact retained-record visual refresh and unchanged cargo authority. The shared ordinary cold/reset caller is DONE3649b4b and reused across all17 families. Codex still owns remaining normal effect trigger/observer/candidate/original-limit bindings; only those unbound qualifications remain BLOCKED definition. Do not schedule another storage/restart caller. No new visual-policy owner decision is required by this source roster. Accepted episode stays closed, no unchanged rerun.  Live torpedo terminal-burst capability DONE9105da8 ([proof](history/ROADMAP_DELIVERIES.md#live-torpedo-burst-reduced-flash-accepted-20261026)): active hit/intercept/fizzle meshes immediately adopt existing emission4.0/1.2 and current-age scale4.2/2.6 policy, preserving0.55s lifetime, position, flights/damage/collision; repeated toggles and expired effects protected. Actual material/mesh component proof; ordinary per-family effect-trigger qualification/full-family/native GPU/human gates remain open. Shared preference persistence is reused below.  Shared native Boot/raw-key Save→cold ON→Reset→third cold OFF/defaults DONE3649b4b; live HUD forwarding and production HUD dirty-state result binding repaired. [Accepted scope](history/ROADMAP_DELIVERIES.md#shared-reduced-flash-native-restart-accepted-20261026); physical/rendered/native Windows/GPU/human and ordinary family episodes stay open. | Select one of the finite17 producer families and its literal policy/accepted scope in the linked contract. Bind exact normal trigger/caller/candidate/limits before execution; prove actual current/new effect behavior, reuse the shared ordinary save/three-process/Reset result, and retain applicable original external gates. Source-defined values or one component pass cannot close the full container. |
| COMFORT-COLOUR | Colour-safe cues route and retained setting | 29 | Container | Finite source contract bound2026-10-25: enum0:none/default/Reset,1:deuteranopia,2:protanopia,3:tritanopia. Existing six core label families/32states×4palettes×2contrast and minimap single-hue shape scopes retained. No missing runtime consumer demonstrated. Tritanopia distinct-process endpoint DONE1f2260f69: actual visible choice/Save→cold realHUD/minimap→normalResetSave→thirdcoldnone, supported raw walking/text/shape, fullotherbindings/options/sentinel and3actualHUDExitOS0/bothclean states. All5checks firstpass, no runtimechange/export; checkpoint39157e8 unchanged. Full rendered/device/other required ordinary episode coverage remains open. [Exact qualification](history/ROADMAP_DELIVERIES.md#colour-preset-cold-process-qualified-20261025). | Existing mode/engine/throttle/hull/component-recovery/target-lock labels retain literal text; enemy health retains percentage/status; minimap retains hostile diamond, friendly ring/cross and objective glyph/label; captions retain text/severity markers. Palette selection changes actual registered HUD/minimap colours without removing those discriminators. Default/Reset is none, not an invented ON/OFF option. One cold-process case requires exact saved enum/control/HUD/minimap→Reset→cold default with protected settings/data and usable controls; it closes only that selected source endpoint. Full parent acceptance retains original actual-device/rendered/transition requirements. |
| COMFORT-CAPTIONS | Captions route and retained setting | 29 | Container | OPEN — live Loadmaster caption capability DONE19336f3a8 ([delivery](history/ROADMAP_DELIVERIES.md#loadmaster-live-captions-delivered-20261025)); live planetary final-approach captions DONE4aa8b64ec ([delivery](history/ROADMAP_DELIVERIES.md#final-approach-live-captions-delivered-20261025)). Existing five Loadmaster/four approach IDs have actual visible-HUD/shared-service component proof; Loadmaster rejection is not qualified as live requester feedback ([source finding](history/ROADMAP_DELIVERIES.md#loadmaster-refusal-readiness-not-selected-20261025)); queue/expiry/duplicate/stale/detach/OFF and companion checks pass, paired checkpoints/strict startups/PCK audits pass. This is component capability delivery; ordinary crew/network/world play and per-episode transition/restart/Reset remain open. Wider goal remains BLOCKED definition — Codex records finite remaining original-required consumers and literal ON/OFF/Reset/restart outcomes; genuinely unspecified product behavior stays with the user. Engine-transition capability DONE46bae53c8/checkpoint46bae53: existing engine_degraded/engine_critical/engine_recovered have exact captions/defaultmedium/high/low; realHeroledger→automaticrigbinding→router/Director/GameFlow→visibleHUD/oneservice proof, five new/retainedalarm FIFO/expiry/OFF/noreplay/unbound checks pass. Oldregistry exactly3fails; allfixed/pairedexports/3strictstartups/actualPCKaudit pass. No emission/mix/gameplay/severity change; componentfixture/manualcaptionclock only, ordinaryflight/listening/rendered/native/fullfamily acceptance remain open. [Exact result](history/ROADMAP_DELIVERIES.md#engine-transition-live-captions-delivered-20261025). Ship-rig source membership now fixed:21possible IDs,19mapped,2unmapped velocity/load IDs with no demonstrated production caller. [Finite producer boundary](#ship-rig-caption-membership) is DONE definition only; no additional live gap or new implementation selected.  Ember surface-loop capability DONEb81082277:18 canonical interior/exterior phase/reward captions, literal unit assertions and actual composition/Director/GameFlow/visibleHUD/oneservice display/expiry pass; oldregistry exactly18 planned fails;13 fixed stages/paired exports/3strict startups/1527-entry payload audit firstpass. Existing owner/controlled receipt fixture and manualclock only; no physical journey/real durable reward/listening/rendered/native/fullCOMFORT acceptance. [Exact delivery](history/ROADMAP_DELIVERIES.md#ember-surface-live-captions-delivered-20261026). | Accepted five Loadmaster/four approach/three engine-transition/eighteen Ember component results remain closed. Codex records in this existing row the finite remaining original-required ordinary episode IDs, each actual caller/action, literal caption/severity, once-only display/expiry/retirement, saved choice after distinct restart and authored Reset endpoint. Reuse the fixed [ship-rig membership](#ship-rig-caption-membership); callerless velocity/load IDs create no live work. The container closes only after those named episodes and the existing device/rendered/transition requirements pass. Missing episode membership or route/value is BLOCKED definition; overflow remains the separate recorded owner-policy dependency. |
| AUDIO-CONTENT-DEFINE | Finite actually missing cues and broken transitions | 30 | Definition | Definition DONE on8a6e7dfe6; existing COMPLETION_SCOPE audio map separates real playback, two transition outcomes and dormant Ember feed definition; no missing new theme inferred | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-ACTIVITY-LIFECYCLE | Current activity music survives normal updates and same-run completion | 30 | Capability | DONEf1f35d137, packaged. Same-run completion/base updates, terminal fences, combat/landing resume, reset/context/lifecycle/PCM/clock scopes pass; five focused suites, paired exports/three strict startups. Audible mix OPEN | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-SURFACE-MUSIC | Aurora/Rime surface visit selects existing surface bed | 30 | Capability | DONE packaged4ff7a08; actual visit-state projection, controlled phase150/activity26/retained bed checks and strict paired checkpoint pass; ordinary journeys/listening remain open | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-EMBER-FEED-DEFINE | Actual intended Ember environment and observation owner | 30 | Definition | Definition DONE on17f92907c: [airless contract/production owners/exact missing intent](COMPLETION_SCOPE.md#ember-environment-feed--source-definition). Active audio forbids atmospheric wind; dormant generic path uses Aurora assets/no ordinary callers. Additional world-specific sound/listener intent is unspecified; no integration selected or new playback qualified. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-MIX-DEFINE | Finite real-output scenario/device mix list | 30 | Definition | Definition DONE on9ef81a348: [finite mix roster](COMPLETION_SCOPE.md#real-output-mix-roster--audio-mix-define), nine current craft/eight normalized activity kinds and named shared episodes. All listening NOT_RUN; actual device/backend/configuration and explicit audible authorization missing. The identified repair cue playback gap is now DONE9b7b46a; no listening acceptance is claimed. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-MIX | Actual output levels/cues/transitions in named scenario | 30 | Qualification | BLOCKED definition/input — Codex binds the existing AUDIO-MIX-DEFINE roster to exact package/routes and balance/clipping/latency/repetition/cue/cleanup limits; user supplies actual device/backend/access, genuinely unspecified listening targets and audible authorization. WAITING on selected roster case, exact package/ordinary route, actual device/backend/configuration and explicit audible authorization. Finite roster defined; all actual listening remains NOT_RUN. | [Quality](#proof-quality): selected existing craft/activity/shared episodes on actual authorized device/backend meet frozen balance/clipping/latency/repetition/cue/cleanup criteria; no Dummy listening claim. A selected case closes only its assignment; AUDIO-MIX closes after every required case in the existing AUDIO-MIX-DEFINE roster passes. |
| AUDIO-CREW-REPAIR-PLAYBACK | Actual accepted Halyard repair edges reach normalized presentation and resident playback | 30 | Capability | DONE packaged9b7b46a. Raw-state normalization, independent elapsed repair observation, missing router labels and resident dispatch repaired. Seven focused/paired package gates PASS; real source/kit/role, once captions, historical-terminal/source reset proved under Dummy. [Full result/first failure](history/ROADMAP_DELIVERIES.md#audio-crew-repair-playback--actual-accepted-repair-edges-delivered). Actual listening/physical crew/native qualification remains separate. | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| AUDIO-NAVIGATOR-PLAYBACK | Actual navigator result/recipient cue playback boundary | 30 | Capability | Accepted/clear DONE packaged4bbb341 across standalone/host-local/bridge/client; actual client stand/reseat/revocation/replay/migration/disconnect and shared crew epoch correction pass original route. Requester rejection DONEc2c72a223/checkpointc2c72a2: all fresh authenticated current refusals including missing consumer; two actual peers/four real rejected presses, replay/foreign silence and full original accepted-clear/migration/disconnect pass252 checks. [New result](history/ROADMAP_DELIVERIES.md#navigator-requester-rejection-feedback-completed--2026-10-21). All real listening/native/full travel gates stay open. [Result](history/ROADMAP_DELIVERIES.md#audio-navigator-client-feedback-and-crew-epoch--delivered). | Retain delivered accepted/clear/current-requester rejection playback and silent stale/foreign/replay scopes; remaining real listening only through AUDIO-MIX. |

### Recovery and release children

Recovery proof uses an owned actual OS SIGKILL, distinct restart, protected real files, once-only rewards and ordinary usable recovery. One selected cut is one task, not arbitrary power-loss coverage. Package/capture/install proof follows the unchanged [release family contracts](#recovery-packages-captures-and-release). **13 capture sets / 143 PNGs** are individually named; native Windows execution/human-review owner exclusions remain factual NOT_RUN, and applicable other release gates remain open.

| ID | Named outcome | Parents | Kind | State / dependency | Done means |
| --- | --- | --- | --- | --- | --- |
| RECOVERY-ONFOOT-DEFINE | On-foot durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE; four-field home preference; selected f90547c archive cut now accepted | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-ONFOOT-PROBE | Exported release driver admits and observes genuine on-foot save/resume context | 2,31,32 | Qualification | DONE source scope f90547c37: real-file source kill/restart, supported walk+Interact, receipts1→2; package child accepted | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CHECKPOINT-ONFOOT-PROBE | Paired checkpoint ships accepted on-foot release-driver support | 6,32 | Qualification | DONE f90547c: paired exports, strict startups and exact package audits | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-ONFOOT-CUT | Real-file on-foot commit, owned SIGKILL and distinct-process usable home recovery | 2,31 | Qualification | DONE f90547c direct and actual archive-extracted ELF cuts; supported walk/Interact, receipts1→2 once | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-PILOT-DEFINE | Pilot durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE definition only; four-field safe-home pilot preference, fresh claims, preserved activity/debt; ca0 archive pilot/Convoy pass retained; final candidate and ordinary-controls qualification remain | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-CABIN-DEFINE | Cabin/rest durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE definition only; four-field craft/home preference, fresh supported awake cabin/hatch, no saved flight/sleep pose. Earlier package passes retained; finite remaining cases below | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-CREW-DEFINE | Seated crew durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE definition only; settled solo crew saves four-field home-cabin preference; Resume wakes unseated with fresh cabin/hatch, no prior role or seat claim. Earlier ca0 crew pass retained; finite cases below | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CREW-RECOVERY-INSTALLED | One installed crew interruption returns awake to the supported home cabin with activity/reward integrity | 2,31 | Qualification | GATED final installed candidate plus one frozen supported craft/seat/cut; use existing crew selector, original caps and owned kill/reap/distinct restart. BLOCKED definition — Codex: name supported craft/physical seat and existing installed selector/command; bind actual committed crew-save boundary, protected document fields/activity/debt/payment, owned kill/reap, distinct restart and ordinary awake-unseated home-cabin continuation endpoint under original limits. Exact installed candidate bytes are a separate gate. Reuse settled crew policy; settings-only crew acceptance does not prove earned-debt retention. | [Recovery](#proof-recovery): exact installed candidate actual crew commit/OS kill/distinct restart→awake supported home cabin→ordinary controls/continuation, conserved debt/payment once. |
| CREW-RECOVERY-ORDINARY | One ordinary crew admission→recovery→walk/helm-or-exit journey | 2,31 | Qualification | DONE one Jovian engineer checkpoint case378d99caf: ordinary hub/ramp/chair→actual4fieldcommit→owned kill/reap−9→distinct normalResume/awake supported cabin→2physicalgoals/realhelm/ONLINEcommand1→normalUIOS0/finalclean,79.277s under original300s. Protectedpayload exact across7actualdocuments; settingsonly/earnedactivity-rewardsabsent, no earned-debt qualification. Existing guardedJovian cockpit-priority repair, RED/GREEN7/Python260/pairedexports/three strictstartups/actual1529PCKaudit/rawreview pass. [Proof and retained failures](history/ROADMAP_DELIVERIES.md#ordinary-jovian-engineer-recovery-accepted-20261026). No unchanged rerun. Retained Heavy follow-on f5e6cacee PARKED: full actual route84.357s reaches normalOS0 but final protectednamespace check fails on unobserved new default race/tutorial; original settings/credit1/paidterminal exact. [Failure/reopening](history/ROADMAP_DELIVERIES.md#retained-heavy-crew-recovery-parked-20261026). Source/raw/private exports archived unmerged, no second run selected. Othercrew/installed/final/hardware stay open. | One actual ordinary crew admission/commit/kill/restart/continuation on the frozen craft/role/candidate. Pass requires awake unseated supported home cabin, fresh claims, usable controls, exact protected durable delta and once-only progress/payment. A definition or staged crew placement cannot close this ordinary journey. |
| RECOVERY-DOCK-DEFINE | Docking durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE definition only; active solo assist retains home pilot preference; busy boarding/exit attempts unavailable. Fresh ownership replaces leases/pose; finite cases below | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| DOCK-RECOVERY-PROBE | Existing release driver can interrupt one actual accepted landing assist and check fresh safe-home recovery | 2,31,32 | Qualification | DONE packaged311df73; existing loader/probe/runner docking+Convoy selector, full source and archive ELF kill/restart pass at original caps with fresh home-pilot control and exact terminal/reward boundary | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| DOCK-RECOVERY-CUT | One exact installed candidate survives interruption during actual assist with conserved activity/reward and usable safe-home recovery | 2,31 | Qualification | GATED exact installed/final candidate. Source and archive-extracted 311df73 Bulwark/home/Convoy cut pass; no old lease/assist/seat identity restored. Ordinary/full installed acceptance remains distinct. BLOCKED definition — Codex: bind retained Bulwark/home/Convoy assist cut and existing installed command to exact committed preference/activity/debt fields, kill trigger, distinct restart, fresh safe-home pilot ownership and ordinary continuation receipts at original limits. Reuse311df73 source/archive proof within its scope; final installed bytes remain a separate gate. No old lease/assist/seat identity is restored. | Exact installed candidate interrupted during actual assist restarts at settled safe-home pilot context; no old lease/pose, actual activity/debt/reward conserved and usable controls. |
| DOCK-EXIT-RECOVERY-CUT | One interrupted exterior handoff recovers safely after accepted unavailable publication | 2,31 | Qualification | Executable release support DONE24774c04: accepted/refused busy-exit cut, independent real-file preimage/CAS/backup/refusal, actual-9/reap/distinct Boot, station walk or fresh pilot/throttle, exact protected payload/paid1 and both clean markers. Source and embedded private-Linux pairs pass; [finite contract/result](#busy-exterior-exit-interruption--frozen-2026-10-27). No unchanged repeat of these accepted pairs. Full installed/ordinary qualification stays GATED on exact installed candidate; BLOCKED definition — Codex: bind installed prefix/ELF/hash and complete ordinary preparation route/caller to this same busy-exit cut with original limits. Existing `PACKAGE_PROBE_RECOVERY_CONTEXT=exit`/`exit_refused`, `PACKAGE_PATH` and `run_package_probes.sh --in-world-interruption --native-export` supply scripted executable commands; they do not supply a complete ordinary approach journey. Do not substitute on-foot/crew/airborne cuts. | Busy exterior exit: accepted unavailable publication changes the durable record to the contracted unavailable state; refused publication preserves the prior durable home preference. At the bound cut, actual kill/distinct restart selects the [settled supported recovery](#settled-docking-recovery-contract) and ordinary continuation without stale seat/transition claims. |
| RECOVERY-ACTIVITY-DEFINE | Active activity durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE source map only on470aa24c4; progress/embodiment contract and two actual runtime gaps below. Four terminal-only active-resume policies remain explicitly unresolved; no original promise waived | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| ASTEROID-START-FRESH | Start Fresh durably abandons the interrupted active Asteroid Threading run | 13,31 | Capability | DONE packaged59c55cb: full production179/253.847s under original300; public title/live Start Fresh, refusal/retry, samegen IDLE/laterstream/cold Main and retained-owner/reward protections. Ordinary OS-input/interruption/final candidate remain separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| CINDER-SUPPLY-DEBT | Earned Cinder platform supply completion survives refused payment and cold restart | 13,31 | Capability | DONE packagedf8b5f86: genuine earned proof before payment; three actual-file child processes prove refused debt, one cold payment, paid replay fence and next generation. Active manifest reconstruction and Hauler stock policy remain separate | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-PLANET-DEFINE | Planetary durable-boundary/resume-or-safe-home contract | 2,31 | Definition | DONE source map; Aurora/Rime visit restoration differs from Ember passive survey continuity. WORLD-SAVE per-world boundary and installed RECOVERY-KILL remain open; no broader location promise waived | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| RECOVERY-CUTS-DEFINE | Uncovered installed context/activity/OS-interruption cases | 2,31 | Definition | BLOCKED definition (Codex): enumerate only uncovered installed on-foot/pilot/cabin/bunk/crew/docking/activity/planet cuts against their settled contracts. Each member needs its exact committed durable boundary, expected data/debt/payment delta, owned kill/restart command, supported endpoint and original cap. Reuse accepted cuts; four active-run product policies remain with the user. | Finite uncovered installed contexts/activity/OS cuts tied to existing settled contracts and exact Linux candidate; explicit initial state/cut/restart/data/control proof. |
| SAVE-MIGRATION | Real-file valid migration with distinct-process reload | 31,32 | Capability | DONE supported runtime_settings10→11 source case on 4d1ba694/run pin2e8ef5149. Normal production writer loads10 once before first apply, preserves all prior values/profile and paid Race/reward, keeps stored10 through STABLE; explicit visible Save writes exact11 with only high_contrast_hud=false/reticle_style=standard added. Entire payload differs only in that section; generation6→7, exact parent and .bak bytes/mode0600. Distinct normal reader consumes exact writer generation10 SHA, restores complete InputMap/profile/Race/reward1, completes Begin Shift within475ms/UI5s, same-Player supported≥1m walk/settle/12 neutral ticks and clean close togen19 with valid predecessor. Final writer37.189s/91 and reader38.544s/153, actualOS0/markers1/no diagnostics; independent source/raw review GO. Earlier17.044/31.629/37.541 failures and one intermediate writer pass retained on original90min11:15:39Z clock; causal corrections wait actual Main readiness/normal intro completion without changing criteria or caps. Owned cleanup complete; game code unchanged/no identical export. Final installed/native/device/other-format migration gates remain open. [Accepted result](history/ROADMAP_DELIVERIES.md#settings-schema10-migration-accepted-20261025); [earlier park](history/ROADMAP_DELIVERIES.md#settings-schema10-migration-parked-20261025). | Freeze one actual supported older file/version and expected current document/unchanged protected fields. Production migration writes the expected current state; a distinct normal process reloads it and permits ordinary continuation without duplicate rewards. Missing fixture, expected values or original command keeps this GATED; do not invent a migration promise. |
| SAVE-CORRUPT | Corrupt-data fallback and usable recovery | 31,32 | Capability | DONE for the frozen primary/valid-backup read-only source case on3380961fb: two distinct normal Main processes restore backup schema11/FOV96/full profile and paid ledger1, preserve primary/bak/recovery bytes/names/modes0600, refuse unconfirmed Save with UNSAVED feedback, complete normal Begin Shift/supported walking/12 neutral ticks and exit0. Main alone creates recovery; Race restore and durable startup/close writes intentionally refuse. First pair passes33.085s/114 and33.151s/108 with marker1/no diagnostics, unchanged source/cache/editor/template guards and independent review GO. No repair confirmation or paid Race actor restoration claim. Owned processes/scratch cleaned; [exact result](history/ROADMAP_DELIVERIES.md#corrupt-backup-read-only-fallback-accepted-20261025). Backup-repair guidance child DONE2456552bd/checkpoint2456552: after authentic rejected startup and explicit confirmation, actual Settings gives quit/reopen instruction; generic no-owner success remains unchanged. Old copy exactlyoneRED, fixedHUD16/total80source/WindowsPCK16 assertions and actual1024×768/requested1.6 fit, pairedexports/3strictstartups/1529PCKaudit pass. [Exact scope](history/ROADMAP_DELIVERIES.md#backup-repair-reopen-guidance-accepted-20261026). Other corruption arrangements/ordinary explicit repair/distinct-restart/installed/native scope remain unqualified. | Freeze one actual corrupt primary/tmp/bak arrangement and exact production fallback/expected protected file bytes and fields. Distinct normal restart selects that fallback, preserves valid recovery copies and permits ordinary continuation without duplicate rewards. Missing corruption case or expected fallback keeps this GATED. |
| SAVE-UNSUPPORTED | Unsupported data refuses destructive overwrite | 31,32 | Capability | Outer-envelope source case4b66b3548 and installed schema2 primary/tmp/bak cases remain accepted on package755ad605a/driver0d06648d; [primary](history/ROADMAP_DELIVERIES.md#installed-future-primary-refusal-accepted-20261026), [temporary/backup](history/ROADMAP_DELIVERIES.md#installed-future-remaining-placements-accepted-20261026). Legacy mixed CFG8/CFG7 destructive recovery and read-only fallback repaired7876ebc8d/checkpoint7876ebc: all three future placements × mutable load/read-only load/direct legacy save refuse ERR_INVALID_DATA; files/Unix modes/live values/signals remain exact. Same frozen test goes27 RED predicates→291-assertion GREEN; actual Windows PCK291 plus paired startup/payload audit pass. [Repair and exact scope](history/ROADMAP_DELIVERIES.md#legacy-future-cfg-preservation-accepted-20261026). Nested typed payload12 primary-only supported-outer1 case DONE on exact7876ebc Linux package/driverddfa82789: ordinary Save/confirmed Reset refuse, four fixture subtrees preserved through15 disk milestones, only actual session1/2 crash/diagnostic additions, distinct cold three-point51.335m walk and two normal OS0 exits; four declared warnings/zero unexpected diagnostics. Existing runner extended without gameplay/observer changes; [exact acceptance and limits](history/ROADMAP_DELIVERIES.md#installed-nested-settings-refusal-accepted-20261026). No other nested format/placement or final-candidate inheritance. Ordinary lone-CFG8/atomic-JSON coexistence DONE on exact7876ebc Linux package/driver2fe5d91d7: all2874 observations retain the future CFG guards, Save/clean direct Reset succeed with exact current defaults, cold JSON loads without migration/warnings, three walking points53.465m/two normal OS0 exits and both actual5physics-second stable/clean lifecycles pass. Fourteen disk milestones/five declared JSON namespaces; first2/cold0 warnings/zero unexpected diagnostics. [Exact case and first unit-fixture failure](history/ROADMAP_DELIVERIES.md#installed-legacy-cfg-coexistence-accepted-20261026). No gameplay/policy change; other placements/native/final-candidate scopes remain separate. The named legacy-UI definition is closed; reuse the accepted source/API/outer/nested/legacy cases, with no automatic successor survey or unsupported-format matrix. Do not repeat closed source surveys/API cases; no new runtime gap inferred there. Final-candidate/device/native-GPU/native-Windows scope remains separate; owner exclusions unchanged. | Named unsupported envelope/format refuses destructive overwrite; primary/tmp/bak names/bytes/modes and loaded authority preserved across fresh processes; accepted outer-envelope scope retained. |
| CHECKPOINT-HELM-EDGE | Fresh paired playable command-delivery checkpoint | 6,32 | Qualification | DONE; 2c73494, both exports/three startups/exact payload and archive checks | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| PACKAGE-FINAL | Exact final Windows/Linux package qualification | 6,32 | Container | Export prerequisite FIXED6b667235b: real private077 exports now package ELF0755, matching existing contract;23 exporter checks and corrected actual tar/strict startup pass. [Exact repair and scope](history/ROADMAP_DELIVERIES.md#jovian-cannon-departure-parked-and-linux-archive-modes-fixed-20261027). Final qualification remains GATED; BLOCKED definition (Codex): name the complete existing package qualification member IDs/commands and exact ordinary-route counts to apply to one frozen Windows/Linux candidate. Reuse accepted scopes where source/scenario matches; owner-excluded native Windows/human facts remain NOT_RUN. | The frozen source commit and actual Windows/Linux exports agree with the production payload manifests and SHA256SUMS; each declared package startup exits0 with STARTUP_MENU_READY_OK; every member of the recorded package/ordinary-route list passes its original counts/caps. Missing member/command/count prevents container closure. Installer transactions, signing and distribution retain their own named goals. |
| INSTALL-WIN-FINAL | Matching NSIS installer artifact/extraction identity | 32 | Qualification | Source-version prerequisite770f5b522 remains accepted. Standalone artifact prerequisite DONE17a11183a: compiler exports complete finalized uninstaller after optional signing, records actual path/bytes/SHA in existing schema1; staged exclusive publication/collision/copy-failure/mock-sign-order tests pass. Both existing suites34tests33PASS/1PowerShellskip; actual7876 setup81.969s under600/log0, standalone117593bytes/actualPEversion/hash and unchanged six prior files/extracted game verified independently. [Literal final handoff](WINDOWS_INSTALLER.md#final-installer-identity--install-win-final). GATED on PACKAGE-FINAL actual candidate and SIGN-FINAL trusted artifact checks. Earlier setups without sidecars retain their extraction limit. Native Windows execution remains owner-excluded/NOT_RUN; no missing standalone-export implementation remains. | On the frozen final Windows candidate execute linked NSIS build/extraction/identity commands: exact source/version, setup/result/checksum, extracted staged game and exported standalone uninstaller bytes/size/hash/actual PE version match. Optional signing precedes uninstaller capture; actual trust and signed-byte proof belong to SIGN-FINAL. Close only on that final candidate, not a checkpoint subset. Native Windows execution remains owner-excluded. |
| INSTALL-LINUX-CLEAN | Clean install on final Linux package | 32 | Qualification | Execution GATED on frozen final Linux package identity/export; the [accepted b4ff8c0 installed checkpoint recipe](history/ROADMAP_DELIVERIES.md#linux-installed-checkpoint-guided-qualification-accepted-20261026) supplies concrete owned paths, byte/mode/launcher checks and full Guided direct-executable command, without graphical desktop or final-candidate acceptance; final package acceptance remains PACKAGE-FINAL. Transaction definition (Codex) binds the final package to an empty isolated prefix, exact expected files/modes/version and installed launch/ordinary-usability command at original limits; no old package required; Definition finishes with fixture/prefix/XDG paths, commands, exact owned/protected files and expected modes/data/usability endpoint; it does not require a final SHA. Before execution, bind the chosen package SHA256 and resolve expected package-file bytes from its actual manifest. Missing fixture/command/endpoint fields remain BLOCKED definition. | [Final Linux installation](#proof-release): clean isolated installation with expected files/modes/version and usable installed launch; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| INSTALL-LINUX-UPGRADE | Upgrade on final Linux package | 32 | Qualification | Execution GATED on frozen final Linux package identity/export; the [accepted499e681→b4ff8c0 checkpoint transaction](history/ROADMAP_DELIVERIES.md#linux-checkpoint-upgrade-499e681-to-b4ff8c0-accepted-20261026) supplies actual prior/candidate paths, saved-progress/settings fixture, expected payload/modes/launcher checks and installed full Guided command; final-package/rendered-desktop/retained-save gameplay reload are not accepted; final package acceptance remains PACKAGE-FINAL. Transaction definition (Codex) binds exact supported old→final packages, existing progress/settings/unowned-file fixtures, expected updated bytes/modes and usable installed launch at original limits; Definition finishes with fixture/prefix/XDG paths, commands, exact owned/protected files and expected modes/data/usability endpoint; it does not require a final SHA. Before execution, bind the chosen package SHA256 and resolve expected package-file bytes from its actual manifest. Missing fixture/command/endpoint fields remain BLOCKED definition. | [Final Linux installation](#proof-release): old→new installation updates intended bytes while preserving specified user progress/settings; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| INSTALL-LINUX-ROLLBACK | Rollback on final Linux package | 32 | Qualification | Final execution GATED on final package identity/export. Checkpoint selected rollback499→b4→499 ACCEPTED on driver503dbf6f6: exact prior bytes/modes/launcher, actual b4-produced save loaded by499 in healthy session3, credit1/settings preserved, three supported walking goals/normal HUD Quit/OS0; six protected files unchanged after uninstall. [Actual proof and limits](history/ROADMAP_DELIVERIES.md#selected-checkpoint-rollback-accepted-20261026). No failed-update/power-loss/rendered/final acceptance or unchanged checkpoint rerun. | [Final Linux installation](#proof-release): failed/selected rollback restores specified prior installed bytes and protected data, then usable launch; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| INSTALL-LINUX-RETAINED | Retained-data handling on final Linux package | 32 | Qualification | Final execution GATED on final Linux package identity/export; checkpoint [retained Heavy load](#installed-retained-heavy-load--selected-checkpoint-contract) ACCEPTED a716c4d8e: source251 Python checks/one actual installed b4 load33.683s, live ledger1/paid terminal/stored settings/healthy session2, 51.262m supported walk/next Torpedo posting unarmed/normal UI OS0/final clean no regrant. [Exact raw proof and retained failures](history/ROADMAP_DELIVERIES.md#installed-retained-heavy-load-accepted-20261026). Existing recipe supplies real fixture/protected fields/private profile/command; final package, full runtime-settings/rendered desktop/native-hardware facts remain open. Original16:11/90min clock includes checks/closure; archive27.680min. | [Final Linux installation](#proof-release): install/update with existing valid user data preserves required progress/settings and loads correctly; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| INSTALL-LINUX-CORRUPT | Corrupt-data handling on final Linux package | 32 | Qualification | Final execution GATED on frozen final package/export. Executable checkpoint recovery caller source accepted26257272f: actual keyboard confirmation commits27→28/full payload and valid backup preserved/normal first OS0; cold session3/credit1/settings/live paid Torpedo acknowledgement and all3ordinary walking goals52.593m demonstrated. FULL QUALIFICATION FAIL/PARK: second shutdown emits rootWindow focus_entered/tree_exited disconnect errors; final OS0/clean file not independently captured. [Accepted implementation and remaining gate](history/ROADMAP_DELIVERIES.md#corrupt-repair-caller-accepted-shutdown-gate-open-20261026). No diagnostic suppression, new gameplay checkpoint or additional trial selected. Original two caller stops and source archive remain historical; original19:31:09/90min clock and300/330/360caps retained. Reopening needs production popup/connection-removal ownership and independent cumulative-priority decision, not another caller or policy survey. | [Final Linux installation](#proof-release): install/update with named corrupt data selects specified safe fallback while protecting valid recovery copies; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| INSTALL-LINUX-UNINSTALL | Uninstall on final Linux package | 32 | Qualification | Execution GATED on frozen final Linux package identity/export; final package acceptance remains PACKAGE-FINAL. Transaction definition (Codex) binds the installed final package ownership manifest, protected saves/unowned-file fixtures and exact post-uninstall/reinstall results at original limits. Accepted named interruption cuts remain retained; Definition finishes with fixture/prefix/XDG paths, commands, exact owned/protected files and expected modes/data/usability endpoint; it does not require a final SHA. Before execution, bind the chosen package SHA256 and resolve expected package-file bytes from its actual manifest. Missing fixture/command/endpoint fields remain BLOCKED definition. | [Final Linux installation](#proof-release): uninstall removes only managed package/entry files, preserves saves/unowned files and permits correct reinstall; exact candidate bytes and ordinary usability, no headless-desktop substitution. |
| LINUX-LAUNCH-DESKTOP | Installed desktop entry ordinary graphical play | 32 | Qualification | WAITING; clean isolated graphical Linux session  BLOCKED definition — Codex: bind the exact existing ordinary graphical route/command, required run count, original cap and terminal gameplay/normal-exit state. GATED on PACKAGE-FINAL exact installed bytes; user supplies access to a clean isolated graphical Linux session if unavailable. No active-desktop authorization implied. | On PACKAGE-FINAL, launch the installed desktop entry in the named isolated graphical session and complete every bound ordinary route/run with its original cap and normal UI exit/OS0. Codex must record the actual route/command/count/endpoints here or in one exact linked contract before selection. Headless or disabled-render-loop checkpoint results cannot close this rendered final case; direct ELF uses no path/pack/script override. |
| LINUX-LAUNCH-DIRECT | Direct installed ELF ordinary graphical play | 32 | Qualification | Normal-exit executable prerequisite DONE39157e8ca: actual shipped-manager clean private install; one complete ordinary Guided flight/home/OFFLINE/physical exit then focused OS-key HUD Exit/actual OS0 in55.826s underCAP300. Installed/archive bytes unchanged; both actual durable clean states verified. Private Xvfb/x11/Dummy/dummy renderer/disabled render loop only. Full rendered graphical Linux/final-candidate route remains WAITING; no 3/3 or desktop-entry claim. [Exact result](history/ROADMAP_DELIVERIES.md#guided-installed-normal-exit-accepted-20261025).  BLOCKED definition — Codex: bind the exact existing ordinary graphical route/command, required run count, original cap and terminal gameplay/normal-exit state. GATED on PACKAGE-FINAL exact installed bytes; user supplies access to a clean isolated graphical Linux session if unavailable. No active-desktop authorization implied. | On PACKAGE-FINAL, launch the installed ELF directly in the named isolated graphical session and complete every bound ordinary route/run with its original cap and normal UI exit/OS0. Codex must record the actual route/command/count/endpoints here or in one exact linked contract before selection. Headless or disabled-render-loop checkpoint results cannot close this rendered final case; direct ELF uses no path/pack/script override. |
| caption-presenter-forward-render | Registered capture set, 1 PNG | 12,33 | Qualification | Source capture and original-resolution agent inspection accepted on06d22013a: exact1 PNG1600x900, exit0/one marker/zero diagnostics, source/import/registry unchanged; caption/speaker/category readable with margins. Human NOT_RUN remains excluded, current/final-candidate qualification separate. Retain artifacts/caption-presenter-06d22013a; do not repeat this unchanged accepted view. | [Registered capture](#proof-quality): exact 1 PNG for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| caption-production-forward-render | Registered capture set, 1 PNG | 12,33 | Qualification | PARKED environment failure on06d22013a: original300s timeout/exit124,0of1 PNG/no marker. Later diagnostic reaches pre-draw but no post-draw; software-driver pipeline cause/material owner unresolved. No image or smaller-presenter substitution, no unchanged retry; human/current/final gates unperformed. | [Registered capture](#proof-quality): exact 1 PNG for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| cinder-streaming-transition-render | Registered capture set, 24 PNGs | 12,33 | Qualification | GATED current source/image binding: historical24-frame production capture and root inspection recorded, one-frame pop repaired and HIGH temporal-settling residual retained. Exact current source/24-image declarations remain pending; recover/bind retained frames before choosing a new capture. No historical/human/current-candidate transfer. | [Registered capture](#proof-quality): exact 24 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-berth-feedback | Registered capture set, 18 PNGs | 12,33 | Qualification | GATED full current18-frame2560x1440 set/source. Historical v0.10 nine-frame capture/representative inspection is not this expanded18 contract. Occupied-cue finding/disposition retained; no repeated inspection promoted to current/full acceptance. | [Registered capture](#proof-quality): exact 18 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-combat-visuals | Registered capture set, 7 PNGs | 12,33 | Qualification | PARKED clean-capture qualification: seven exact2560x1440 source-frozen published frames exist under artifacts/combat_visuals, manifest aggregate4f9a6a38670e6b8ffc8b313caebe36b6972cbdebdff3f8b3af56c17b6b0c81e4. Green sentinel is followed by WARNING7TextureRIDs leaked (capture log1483), with earlier superuser warning; not zero-diagnostic PASS. Original inspection unresolved, current harness differs. Required diagnostic resolution/new frozen capture remains open. On 2026-10-25 rebuilt pinned guarded editor successfully, but ONE original 300 s capture times out (exit 124/300.847 s) before images (0/7); last checkpoint Main instantiation, startup/render delay cause unresolved. No pixel inspection or clean-shutdown/RID-fix inference; reopen only after causal correction/review, no unchanged rerun, longer cap or sentinel-only promotion. | [Registered capture](#proof-quality): exact 7 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-hero-cell | Registered capture set, 18 PNGs | 12,33 | Qualification | PARKED/NOT_DELIVERED on2f333b0e4: ONE unchanged full18-frame2560×1440 Forward+ capture, guardededitor7b46e60/pinnedllvmpipe/privateXvfb/x11/Dummy, original300s timeoutexit124/guard302.135270s,0PNG/0marker. Lastcheckpointpilotinstantiation; laterintervalunlocalized, no art/shader/ROI cause or clean-shutdown/reflectionfix established. Source/index/tree/cache/pins unchanged,9ownedidentitiesabsent; registry stages pendingunchanged. [Exact failure and archive](history/ROADMAP_DELIVERIES.md#torrent-hero-cell-original-cap-timeout-20261026). Reopen onlysupportedcausalcorrection/environmentchange+independentcumulativepriority preserving original18frames/2560/quality/300s; no unchanged retry/qualitydrop/newbudget.  Later conditional warm-cache preparation import exit0/20.944s and verified102files/5400444bytes, but missed reviewed18:30launchcutoff before rendererPopen; NOsecondcapture/cacheeffecttest. [Preparation cutoff](history/ROADMAP_DELIVERIES.md#hero-warm-cache-preparation-cutoff-20261026); finaltimingreviewupheldPARK, sixprepidentitiesabsent. Sameoriginalclock/cost; nofurtherwindow/retry. | [Registered capture](#proof-quality): exact 18 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-jovian-freight-berth | Registered capture set, 2 PNGs | 12,33 | Qualification | Source capture and recorded inspection of both originals accepted on689e2ed0e: exact2 PNG1400x900/exit0/one marker/zero diagnostics, source/import/registry unchanged. Supplemental sign pair establishes repaired legend; it is not a replacement canonical frame. Human/native/current/final-source qualification remains separate; current runtime/material dependencies differ. Retain artifacts/jovian-freight-berth-689e2ed0e; no unchanged recapture/reinspection. | [Registered capture](#proof-quality): exact 2 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-jovian-freighter | Registered capture set, 4 PNGs | 12,33 | Qualification | Source capture and original-resolution agent inspection accepted on e159ac3c5: exact4 PNG1280x720/exit0/one marker/zero diagnostics; readable cabin, coherent cargo lids/cooling, scoped JOVIAN-ROOF-001 resolved. Earlier obstructed5c76d images remain unaccepted. Human/native/temporal/current/final-source gates remain separate; retain artifacts/jovian-freighter-e159ac3c5, no unchanged recapture. | [Registered capture](#proof-quality): exact 4 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-player-motion | Registered capture set, 9 PNGs | 12,33 | Qualification | GATED retained-source binding/current qualification. Historicaled359040c has recorded nine2560x1440 frames, stable source/imports and original-resolution agent no-finding inspection. Existing artifacts/player_motion nine-image manifest is not yet proven to be that source/run; first recover binding and full diagnostic disposition. Human/current/final gates remain unperformed; no automatic unchanged recapture. | [Registered capture](#proof-quality): exact 9 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-scenes | Registered capture set, 27 PNGs | 12,33 | Qualification | GATED current27-frame2560x1440 set/source. Historical v0.10 complete27-frame set was1280x720 and does not satisfy current declared resolution; historical representative inspection cannot close the current set. | [Registered capture](#proof-quality): exact 27 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-station-operations | Registered capture set, 7 PNGs | 12,33 | Qualification | PARKED environment failure: exact6cf94bd39 roster attempt and later418f3fe16 diagnostics time out at original300s/exit124,0of7 PNG. Built-in Forward+ color-pass ubershader compilation identified, material owner/supported mitigation unresolved. No image/current inspection or unchanged retry; require demonstrated causal environment/source change. | [Registered capture](#proof-quality): exact 7 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-varied-encounters | Registered capture set, 18 PNGs | 12,33 | Qualification | PARKED on8c99f6c54: first supervisor option failure occurred before engine; one independently approved synchronous-wrapper correction/import22.169s then ONE original300s full capture exits124/302.300s incl teardown,0/18images/0DONE/no diagnostics. Source/imports unchanged, six owned process identities absent, owned checkout/scratch cleaned and records archived. Log shows only engine/Vulkan startup; precise cause unknown. [Both stops/cleanup](#varied-encounter-complete-image-set--frozen-2026-10-27). No further correction/run selected; original02:40→03:40 clock and18.422minutes through cleanup plus final closure retained. Current18-frame1600x900 set/source remains incomplete. Existing artifacts/varied_encounter_visuals has17 exact-size PNGs and lacks plate_04b_scatter_fan.png; no verified current source or bounded documented original inspection. Seventeen historical frames cannot close18; no count-only or historical promotion. | [Registered capture](#proof-quality): exact 18 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| capture-zenith-visuals | Registered capture set, 7 PNGs | 12,33 | Qualification | GATED clean/current-source qualification. Historical seven-frame production and original-resolution no-blocker review recorded at frozen286-file aggregate68d23207b9841463c61273b8c3de610a25519e82dc56f46eeddfb7befdef77c4, but post-sentinel seven-Texture-RID warning remains. Published frames are not zero-diagnostic acceptance; current registry/source/human/final stages remain pending. | [Registered capture](#proof-quality): exact 7 PNGs for THIS existing set/source/declared sizes; inspect originals and resolve/disposition actual findings; no substitutions. |
| RIGHTS-DEFINE | Finite project/asset/source licensing families and missing documents | 34 | Definition | DONE as the [source-backed rights-family map](#rights-families-and-missing-documents--rights-define); definition only, no blanket rights clearance. Creator-permission account retained; project release terms and historical media redistribution documents remain distinct gaps | Accepted only for the exact source/scenario cited in State. Preserve its result and limitations; no automatic rerun. Final integrated qualification belongs to MATRIX-FINAL/FINAL-RECONCILE. |
| SIGN-FINAL | Trusted game/installer/uninstaller signatures and expected publisher | 34 | Qualification | BLOCKED definition—Codex: finite game/installer/uninstaller artifact paths and hashes, supported verification command, actual trust-store context and literal success/failure checks. BLOCKED input—user: trusted certificate identity/fingerprint, expected publisher and credential access. No private credentials belong in the proof. | On the frozen candidate, sign every listed game/installer/uninstaller member; verify every resulting signature in the declared trust context, with the recorded command returning success and matching the exact expected publisher and certificate fingerprint. Record signed-byte hashes for DISTRIBUTE. Unsigned members, identity mismatch, untrusted/invalid signatures or missing verification block closure. Signing tools reporting success alone are insufficient. |
| MATRIX-FINAL | Existing unfiltered local --mode all on one frozen candidate | 6,35 | Qualification | GATED on frozen final source and recorded Godot binary identity; Codex owns those bindings and the [literal matrix handoff](#matrix-final--literal-command-and-terminal-result). Do not run as part of roadmap editing. Shared native-runner premature-exit repair DONEd0cbd2016 remains accepted; it is not a final matrix. | Execute the linked unfiltered command once from the clean candidate. Require supervisor FINISHED/exit0, matrix overall_status=PASS, failed_suite_count=0, execution_mode=all, no scope/filter/shard/exclusions/risk allowance, complete discovered roster, unchanged source/cache and all owned processes reaped. Preserve run-manifest.txt, results-canonical.tsv and raw logs; no test-count growth substitutes for this result. Original suite deadlines remain unchanged. |
| FINAL-RECONCILE | All original promises and applicable final-candidate results | 2,35 | Container | GATED on the existing36-parent/ten-exit crosswalk, exact candidate results and SHA256SUMS. BLOCKED definition (Codex) wherever complete child membership or candidate binding is absent; signing and authorized downloaded-byte identity retain their own SIGN-FINAL/DISTRIBUTE owners. | For each of the existing36 parent promises and ten phase exits, record its complete existing child IDs and exact accepted candidate/source scopes, or the specific still-open child/input. Close only when no required pre-publication member is OPEN/BLOCKED/PARKED, required exact-candidate results are accepted, P0/P1 count is0 under the [preserved severity rules](history/ROADMAP_SCOPE_20261017.md#priority-order), every P2 has its defect ID, explicit disposition, rationale and responsible owner, and final artifact checksums agree. Codex must bind the candidate defect inventory before this gate is executable; a genuinely unsettled release-risk decision remains user-owned input. Missing membership/value keeps reconciliation BLOCKED definition (Codex); a crosswalk or accepted subset cannot close it. DISTRIBUTE follows accepted pre-publication gates; its downloaded-byte proof is not a circular prerequisite for authorizing publication. |
| DISTRIBUTE | Authorized publication and downloaded-byte identity | 34,35 | Qualification | GATED; actual final acceptance and authorized destination | Explicitly authorized destination serves downloaded bytes exactly matching accepted signed candidate/checksums; no publication before approval. |
| IDENTITY-TORRENT | Torrent B5 provenance/continuity tied-source claim | 36 | Definition | WAITING; registered evidence or exact external dependency | Record the literal shipped statement about B5 provenance and continuity of the shipped Torrent identification, its registered supporting source anchors/confidence and the specific unsupported proposition. Close with supporting evidence or explicit user approval of the labelled interpretation used in shipped presentation. If evidence is unavailable, record the exact missing source/view/access and stop. Preserve accepted honest wording; a generic request for more evidence or another unchanged survey cannot close this goal. |
| IDENTITY-ZENITH | Zenith B7 provenance/naming tied-source claim | 36 | Definition | WAITING; registered evidence or exact external dependency | Record the literal shipped statement about B7 provenance and the shipped Zenith naming claim, its registered supporting source anchors/confidence and the specific unsupported proposition. Close with supporting evidence or explicit user approval of the labelled interpretation used in shipped presentation. If evidence is unavailable, record the exact missing source/view/access and stop. Preserve accepted honest wording; a generic request for more evidence or another unchanged survey cannot close this goal. |
| IDENTITY-ARROW | Arrow identity tied-source claim | 36 | Definition | WAITING; registered evidence or exact external dependency | Record the literal shipped statement about identity of the shipped Arrow, its registered supporting source anchors/confidence and the specific unsupported proposition. Close with supporting evidence or explicit user approval of the labelled interpretation used in shipped presentation. If evidence is unavailable, record the exact missing source/view/access and stop. Preserve accepted honest wording; a generic request for more evidence or another unchanged survey cannot close this goal. |
| IDENTITY-JOVIAN | Jovian identity tied-source claim | 36 | Definition | WAITING; registered evidence or exact external dependency | Record the literal shipped statement about identity of the shipped Jovian, its registered supporting source anchors/confidence and the specific unsupported proposition. Close with supporting evidence or explicit user approval of the labelled interpretation used in shipped presentation. If evidence is unavailable, record the exact missing source/view/access and stop. Preserve accepted honest wording; a generic request for more evidence or another unchanged survey cannot close this goal. |


### Scope, counts and scheduling

All327 pre-rewrite goal IDs and all36 parent promises are retained. Ten actual
previously unnamed decision/resource outcomes are now explicit rows; no gameplay
promise was added. Records include completed scopes, containers, definitions,
blocked decisions and executable outcomes: they are not337 unfinished jobs or a
percentage. Each record has a Done means condition; no generic family is runnable.

The eight missing craft still need specifications before honest implementation
estimates. Four active-recovery policies, two cargo-cycle policies, release scope,
physical resources and rights/signing inputs are explicit above. Their absence is
a specific blocker, not permission for indefinite research. Once settled, update
that same row and implement its named capabilities; do not create serial maps.

Use one active implementation, with exact owner/files/action/estimate/cap/stop.
Prioritize complete playable outcomes and missing production over convenient
qualification harnesses. Preserve accepted scopes; final integrated acceptance
runs through the single release gates. Do not count definitions, commits, tests,
validator versions or rows as gameplay progress or invent a completion date.

## Family contracts

These existing contracts retain their original acceptance and stop boundaries.
Every bracketed family row below is a **non-executable template**, even where a
historical Status says ELIGIBLE. Only its existing canonical child can be selected
in ROADMAP.md after the finite-execution rule above is satisfied. A template does
not authorize repeated discovery, a new child ID or a new scenario axis. If it has
no bound child/finite roster or numerical criterion, it is BLOCKED definition
owned by Codex, with unspecified design/limit choices owned by the user.

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

### Original Settings artifacts — bounded recovery

SETTINGS-INPUT, one read-only pass2026-10-25: **source identity recovered; original
execution artifacts still WAITING**. This does not close SETTINGS-RETURN or
qualify a replacement route. No tests, Godot, exports or probes were run.

| Recovered original | Exact identity / retained limit |
| --- | --- |
| Writer | `tests/accessibility_reentry_integration_test.gd --settings-process-write` at9a89b3763ce4b4c760c547e59296bc086a856fe3 |
| Distinct restart reader | `tests/controller_physical_sortie_test.gd --settings-reentry-input-route`, optional `--sortie-diagnostics`, same source. Reader introduced byeadc1503414425665f63669f684bbbd99ee238f5 |
| Original pairing | Writer must exit0; distinct restart shares SAME isolated `XDG_DATA_HOME` and existing `user://mudds_user_data.json`; private rendered display/Dummy audio and unchanged outer300s. Source synthetic events do not establish physical hardware |
| Final failure summary | Tracked ROADMAP at064f573b2f83b517a722a7d7fd856573535e2885 records successful writer, source KBM sortie/gamepad outbound probes then gamepad-return cap; earlier Windows payload separately reaches gamepad flight before same cap. This summary is not the missing raw log |
| Earlier Windows package | d750f76d92036d37b98712b83891c4cff1ac3b2a; SHA256e32506fbbc61fac4a87f633438f8831557b7530406d58c918fe50f76246b18b7,1513entries, historical notes available in064f573b2. Older notes record an earlier KBM-return failure; do not confuse that earlier run with the later summary |

Still missing: actual FINAL writer/restart orchestration command and launch/status
receipts, isolated durable profile, final source gamepad-return timeout log and
later packaged gamepad-flight timeout log. The historical artifact neighborhood
`/root/.cache/mudds-shipyards/roadmap-validation/aurora-client-hud-retirement/stable-custom-full/`
is absent. Documented old member
`settings-reentry-reader-walk-trace/settings-reentry-input-route.log`, SHA256
`6416d846eb0591cba88e0ccac4a546d5e47765341ee9e2fa89539e1e03ae2389`,
belongs to an EARLIER Begin failure, not the final300s timeout.

Search covered relevant Git history/source, repository artifacts and the existing
`/srv/mudds-work` relocation/archive/closeout indexes and retained inventories.
No matching relocation was found within that bounded scope; this is not an
all-filesystem absence claim. Do not repeat this same search without new artifacts
or a concrete location. Original execution-data recovery is the remaining external
dependency, not permission to fabricate a profile/command or rerun a substitute.
Seven original-source/notes/identity files byte-match the retained archive:
`/srv/mudds-work/settings-original-artifacts-20261025/records.tar.gz`,40382bytes,
SHA256`d284da31b1ed3f370045012ac1a5cb26e02a7a2603eaab5c1d4b5cb6f3378cc3`.
Only archive and closeout remain; no branch/worktree/process/build was created.

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
| CRAFT-ACCEPT-* / CRAFT-ROLE / RECOVERY-CABIN-DEFINE | Remaining ordinary hatch/chair/bunk walk, sit/action/sleep/wake/stand, landing/reuse and cross-craft continuation without staged aisles, damage or return poses | Freeze one uncovered supported craft/physical role and its complete journey. Existing `tools/release/run_native_sortie.py BINARY --output DIR --route crew-recovery` accepts the Jovian engineer admission/commit/kill/restart/walk/helm/normal-Quit case on378d99caf; CREW-RECOVERY-ORDINARY is DONE within that scope, not missing preparation. Reuse that route and receipt; it does not prove other roles, earned activity/reward retention, installed recovery or the complete fleet/cabin/bunk journeys. Name the exact remaining route/trigger/endpoint before selection. Preserve accepted Habitat loop/restart; Bomber role interpretation and parked Halyard boundaries remain dependencies. |
| SETTINGS-RETURN / existing RECOVERY-KILL and installed recovery children | Ordinary save/quit or owned interruption, distinct-process continuation with usable controls and conserved activity/reward/data, according to each settled context | SETTINGS-INPUT originals remain WAITING; installed cuts require their exact candidate/context/driver. Same-Main memory-store detach/re-add is not disk restart. Habitat restart and named accepted recovery cuts remain DONE; this definition neither duplicates nor reopens them. |
| Original repeated-transition requirement, only if uncovered by the children above | Identify the original promise and the exact transitions not already qualified by those children; preserve clean quiescent presentation, bounded resources and usable controls | NON-EXECUTABLE coverage gap, not an additional all-game assignment. Codex must first cite that original requirement and bind its route/count/rest-state/resource endpoints. Source four/twelve-cycle anchors cannot supply ordinary package acceptance. Reuse covered journeys; do not invent a combined fleet/cabin/recovery matrix from this label. |

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

**Capture binding pass, 2026-10-26, source0383848bf: BLOCKED definition — Codex.**
The existing13 subjects below are now mapped once to declared harness frames;
this is neither a visual review nor a new capture requirement. Reuse this map
instead of repeating the source survey. Registry:
`tools/release/graphical_harness_registry.json` (existing13 sets/143 PNGs).
`tools/validate_visual_capture_set.py` checks a supplied manifest's integrity;
it is not the registry and cannot establish readability or physical access.

In the table, **Scenes** means `tests/capture_scenes.gd` / `capture-scenes`;
**Operations** means `tests/capture_station_operations.gd` /
`capture-station-operations`; **Freight** means
`tests/capture_jovian_freight_berth.gd` / `capture-jovian-freight-berth`.
Names are declared frames, not evidence that an image exists or passed review.

| Existing subject | Declared frame binding | Exact remaining binding / retained boundary |
| --- | --- | --- |
| Central | Operations `02_central_berth_operations.png`; Scenes `station.png` | Supported standing-spawn-directory pose/eye height, literal destination text and berth-access comparison. Elevated station overview is not this view; CENTRAL-VIEW stays parked. |
| Aft | Operations `03_aft_operations_route.png`; Scenes `aft_junction.png`, `operations_room.png` | Lower-console doorway pose and literal Activity/Destination text/door clearance; separate upper stair/workpost view. The120s/no-image console attempt stays parked. |
| Habitat | Operations `04_habitat_service_access.png`; Scenes `habitat_exterior.png`, `habitat_common_room.png` | Measured-eye common-entry image/metadata and exact bunk/wake/doorway comparisons. Existing local camera y2.55 does not qualify standing arrival;180.842s/no-image attempt stays parked. |
| Freight | Operations `05_jovian_freight_operations.png`; Scenes `freight_dock_approach.png`; Freight `freight_berth_overview.png`, `freight_control_room.png` | Bind integrated service entrance/boarding approach, literal service/boarding text and unlocked-door/clearance comparisons. Accepted689e2ed0e standalone pair remains accepted only in its custom capture environment. |
| Fleet | Scenes `fleet_overview.png` is overview context only | Name one actual berth/craft threshold and supported approach pose, literal destination and boarding/landing clearance predicates. Overview does not bind this member. |
| Annex | No explicit frame in the required13 sets | Restock console from supported central aisle: image binding, pose/eye height/FOV, literal service text, interaction and aisle-clearance comparison. Unfinished south gate remains excluded. |
| Observation | No explicit frame in the required13 sets | Name one actual Observation/Logistics pad, cross-landing pose, image binding, literal destination and supported return comparison. |
| Salvage | No explicit frame in the required13 sets | Supported-arrival inspection-pad image/pose, literal three-component presentation and access comparison. Parked/gated physical access/revisit remains parked/gated. |
| VIP | No explicit frame in the required13 sets | Supported reception-arrival image/pose, literal evidence-permitted text and access comparison. Parked VIP walk remains parked. |
| Tow | Operations `02_central_berth_operations.png` | `CentralTowServiceActivity`: ordinary nearby walking/boarding view, exact presentation phase, text if present and service/route clearance comparison. Paused tableau is not ordinary acceptance. |
| Gantry | Operations `05_jovian_freight_operations.png`; Scenes `freight_dock_approach.png` | `FreightApproachGantry`: ordinary nearby walking/boarding view and exact operating phase/clearance comparison. Operations includes the real gantry envelope but does not prove that route. |
| Arm | Operations `03_aft_operations_route.png` | `AftOperationsActivity`: dedicated service-arm phase/player pose and ordinary nearby walking/clearance comparison. Existing Aft failure boundary remains. |
| Patrol | Operations `04_habitat_service_access.png` | `HabitatServicePatrol`: patrol phase/player-eye pose and ordinary access/clearance comparison. Existing Habitat failure boundary remains. |

**Known comparison settings, not player-pose proof.** Operations uses full Main,
Forward+, High (`apply_visual_quality(2)`),2560×1440,TAA/MSAA2X and content-scale
size zero. `_frame_points` dynamically fits a camera around semantic anchors;
`_prepare_deterministic_activity` pauses activities; `_seek_activity_tableau`
sets their clocks to base time plus activity index×1.37.
Central/Aft/Habitat/Freight base times are7.25/10/12.75/15.5s, respectively.
These are reproducible source recipes, not recorded standing-eye measurements.
Scenes also declares2560×1440/TAA/MSAA2X; its room cameras are module-local
Aft(5.6,2.35,10.15)→(5.6,1.35,15.4),FOV60 and
Habitat(0,2.55,18.8)→(0,1.75,27.2),FOV56. Both scripts stage capture state.
Freight declares1400×900 with its own lights/environment; its interior camera
is(17.8,1.9,31.8)→(20,1.55,28.8),FOV70 after the real service door opens.

At this pass the two accepted Freight PNGs exist under
`artifacts/jovian-freight-berth-689e2ed0e/captures/`. The default Scenes
`gameplay_evidence_manifest.json`, `gameplay_source_manifest.sha256` and
`station.png`, and Operations `02_central_berth_operations.png`, are absent at
their declared local paths. This bounded check makes no archive-wide absence
claim. Scenes/Operations registry source and image stages remain pending;
`reviewed_current` alone is not accepted proof. Optional Operations
`08_wayfinding_pylon_player_eye.png` is outside required143 and cannot replace
the parked Central view.

Codex owns the missing view bindings above: supported player pose/eye height,
exact state and readable strings, source-bound renderer/quality/scale/image
conditions, and literal access/clearance endpoints. Existing settings can be
reused where valid; do not infer measured clearance or readable text from source
anchors. The definition and product container remain BLOCKED until these fields
are supplied. This pass ends here; no automatic successor survey or capture.
Parked views require their recorded causal reopening evidence first. Review of
required minimum/ultrawide/comfort cells retains the original scope and cannot
be replaced by these overview mappings.

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
| TRAVEL-LIMIT[one nearby route] | Beacon outbound60s DONE252ed6bfc/10.510574s | Existing exact clock/start/stop/route qualified with full111.908s beacon-home at original300s cap; checkpointc2c72a2 reused. Other routes retain scope. |
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
The choice and actual timing are settled: DONE252ed6bfc/10.510574s below; do not schedule the outbound measurement again. Original
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

**Completed2026-10-21 —252ed6bfc:** outbound conservative monotonic upper bound
10.510573555s≤60.0s, first demandframe788/sequence314 to qualifyingframe1396/
sequence922 at19.082720m and0.051334m/s. Zero pauses/subtractions; all609 raw leg
samples retain actors/default controls. Original full beacon-home111.908s PASS,
four physical Beacons, one durable reward, Guided combat, strict home dock,
OFFLINE exit and supported0.96943m walk; cap300s unchanged. Corrected118 driver
tests and independent source/result review pass. No game change; accepted
c2c72a2 ELF reused, no duplicate checkpoint. Private Linux Xvfb/x11/Dummy/dummy
renderer only; boost check covers this sole driver's issued keys. Native GPU,
Windows/human, cold restart/endurance and return/other numeric limits remain
open. [Delivery record](history/ROADMAP_DELIVERIES.md#beacon-outbound-60-second-qualification--completed2026-10-21).

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
| Cinder supply / NearbySectorActivityBinding, CargoTransferAuthority, CargoDeliveryActivity; `tests/cinder_cargo_activity_bridge_test.gd`, `tests/cinder_cargo_reward_handoff_test.gd` | Accepted ordinary Jovian supply journey9ed9a0709 and shared Jovian/Hauler conserved custody6bcbea302 are retained. Actual Hauler delivery/cold inventory and ten-cycle replenishment/destination-turnover remain separate; no missing Hauler stock choice is inferred. |
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

### Race repetition — selected ordinary-input capability

REPEAT-RACE, selected2026-10-25, now **PARKED after two failed full attempts**.
The accepted first-play7997b2b37 satisfies its prerequisite. The unaccepted
candidate implements an opt-in `race-repeat` mode in the existing
native-sortie driver/read-only observer, not another validator or evidence format.
One original world/Main/Player/Torrent is retained; one genuine Guided prelude is
followed by **ten** normal timed-race sorties. Every sortie preserves the actual
2s countdown, five physical ordered gates,120s race limit/zero penalties, exact
once-only durable reward, strict occupied home landing, original≥90 neutral
OFFLINE ticks, physical exit and supported walking. Normal reboarding invokes the
existing persisted terminal reset; run generations are1,3,…19 with reward counts
1,…10. Tenth reboarding proves durable idle generation20, unchanged ledger10 and
occupied OFFLINE dock with a usable next start, without an eleventh departure or
payment. End through normal UI quit/actual OS0 and exact orderly-close files.
No transform, checkpoint, kill, payment, reset or gameplay-timing injection.

Compare equivalent eligible completed homes after the existing shutdown/exit and
supported-on-foot checks. The full original walk still must finish before the
cycle is accepted; census collection does not replace its displacement/duration.
Baseline is first completed race home; cycles2–10 must show zero positive
growth in the Main subtree node census by built-in class and script path, flyable
ship group count, GameFlow `ships` count, combat target `_registrations_by_instance`
and resolver `_source_registry` sizes, ActivityDirector `_definitions`/`_activities`
sizes and active objective IDs. Main/world/Player and registered fleet identities
stay fixed; streamed residency state must match at comparison. Node census covers
retained actor/checkpoint/objective/observer/projectile/effect descendants. Record
a census once per eligible completed cycle, without creating Nodes or calling
registry-pruning getters. Legitimate durable receipt/generation/history advances
are excluded from resource counts, not accepted as duplicate awards. Any uncovered
resource owner or unmatched state blocks the claim rather than gaining a tolerance.

Existing single-sortie CAP300 and all its sublimits remain unchanged. Each repeat
cycle retains300s, including initial Guided/startup in the first cycle. The new
repeat driver has an independent aggregate abort at3000s (ten existing caps), not
an increased deadline for old `race-home`. There was no original whole-repeat
clock. Root's task clock is12:29Z→13:59Z/90min, including selection/implementation,
checks/export/run/integration/cleanup; do not restart it. Estimates45min code,
15min checks/export,20min route and10min closure. Stop on first unexpected failure;
no automatic repair/retry. Exact clean source/package/command binds before launch.

One high implementer owns `run_native_sortie.py`, its existing Python tests and
`native_sortie_observer.gd`; root owns exact startup mode/privacy admission,
docs/process/package/integration; an independent high reviewer checks source/raw
results. Tests do not replace the ten real cycles. No gameplay change is assumed;
no identical Windows checkpoint is needed for private diagnostic-mode work alone.
Actual installed/native-device/GPU/audio/endurance/final-candidate gates remain.

**Stop, not delivery:** first whole attempt735.602507876s fails the fourth home
CAP300 after three complete cycles and four payments. Recorded hull pose/source
geometry reproduces gantry portpost/header margin contacts; a reviewed Python-only
correction inserts published approach-lane40/170 staging before every old waypoint.
On a fresh profile, the corrected whole attempt fails312.126038933s at first home
CAP300, with one payment and neither lane receipt. Ten-cycle acceptance failed
twice; final idle20/next-start/normal UI close remain NOT_RUN. Three original
censuses are exactly equal (10007nodes/9fleet/13combat registrations+sources/
1observer/0projectileflights), but cannot replace ten successes. Guards and native
input/process cleanup pass; no engine diagnostics. Keep both separate attempts,
1047.728546809s failed-route cost and the original wall clock. Candidate49cba86e3
is archived/unmerged; its source prechecks are not runtime delivery. The later
first-lane failure's actual control/slide-collider cause is unresolved. No further
investigation, correction or replay is selected. [Exact records/cleanup](history/ROADMAP_DELIVERIES.md#race-repetition-two-attempt-stop-20261025).

### Beacon repetition — selected ordinary-input capability

**PARKED after two full attempts2026-10-26; NOT_DELIVERED.** Candidate
source0029b8daf/game da6d539 remains unmerged. First425.713s native attempt:
one paid full home/census, then leg2 original300s cap at Beacon cursor3. Source
review plus frozen-heading/neutral-demand evidence supports one external-driver
Resume mouse-pending correction;253 failfast Python checks pass. The unchanged
game package was reused. Corrected335.727s native/336.134s wrapper attempt:
two paid homes and matching resource censuses, then original12s ordinary
reboard-clear walk entering leg3. Later cause NOT_ESTABLISHED. No third attempt,
source exploration, repair, cap increase or renamed retry is selected.
[Full records and exact ownership cleanup](history/ROADMAP_DELIVERIES.md#beacon-repetition-two-attempt-stop-20261026).
All source/private exports/raw results are verified archived before exact owned
branch/worktree deletion; no public checkpoint. All12 supervisors/57 observed
identities absent. Original14:58:50UTC/90min clock includes both attempts;
archive closure57.711min, final push in closeout.json. The earlier byte-audit
failure/correction is retained:66 scene differences are only typed node IDs,
all other decoded bytes equal/id_paths empty; two intended scripts differ.
The finite definition below stays fixed. Reopening requires demonstrated cause
for the later physical clear-walk boundary and independent cumulative-priority
review with the same original route/support/>7m/12s and full ten-run acceptance.

REPEAT-BEACON selected2026-10-26, source5549036f8. PLAY-BEACON is accepted;
this assignment implements the missing ordinary ten-run release caller and then
qualifies it, not a new validator. Root/Codex owns integration and closure; one
implementation agent owns `tools/release/run_native_sortie.py`, its existing test,
`scripts/diagnostics/native_sortie_observer.gd` and
`scripts/game/startup_loader.gd` plus the existing admission/privacy test if needed.
No production gameplay/tuning/content owner changes are selected.

One original Main/world/Player/Torrent and fleet stay alive. Cycle1 preserves the
accepted full Beacon-home journey including actual Guided combat. After its
strict home/OFFLINE/exit/walk, use ordinary Activity Board
`ConvoyEscortActivityButton` to select `convoy_escort`, visible
`SELECTED // EMBERLINE CONVOY ESCORT`, idle/gen0/unlocked. Capture the first census
after that selection and completed-home settling. Its departure does not
start an unrelated race. Throughout subsequent travel require idle Convoy,
no tender encounter/payment and actual authored distance>4m from its rendezvous
(84,-48,-724). This selects an existing supported activity; it does not start
or qualify Convoy and never changes its rendezvous or actor policy.

Cycles2–10 use ordinary wing-clear/reboard, original outbound and physical
Beacon1 approach≤32m. While paused, normal Nearby Beacon RESET of the restored
paid generationN must persist RESETN/cursor0/reward flag false/ledgerN before
START increments to N+1. START and all four ordered physical contacts use real
input/production owners; no synthetic submission. Successful generations are
1…10. Exactly ten `debris_route_navigation_data` receipts, one per generation,
are durable; protected unrelated data stay unchanged except explicitly named
ordinary tutorial/selection/safe-home fields. Later home journeys use legitimate
FREE_FLIGHT, not replayed Guided targets; preserve every original home waypoint,
strict dock/lease/parked state, automatic OFFLINE, physical exit and supported
walk. Reuse the accepted route rather than shorten it.

Home is outside the live Cinder binding range, so do not claim Start/Reset is
enabled there. After tenth complete home, one **unpaid readiness sortie** reboards
and reaches Beacon1≤32m through the original outbound controls. While paused:
normal RESET paid10→durable RESET10; actual START→durable ACTIVE11/cursor0;
normal RESET then its existing CONFIRM RESET→durable RESET11/cursor0. Ledger
remains exactly10 throughout; no eleventh traversal/payment is counted. Resume
and retain full original strict home/OFFLINE/exit/walk and normal HUD Quit/OS0.
Paused physics must prevent an injected/accidental first-beacon submission.

Compare equivalent completed homes after the existing supported walk/settling:
Main subtree node counts by built-in class/script path; fixed registered fleet
identities/flyable group/GameFlow ships; combat target registrations and resolver
source registry; ActivityDirector definitions/activities and active objective IDs;
projectile slots/active flights and direct presentation-consumer array lengths.
Baseline is first completed home after Convoy selection. Cycles2–10 and final
readiness home require zero positive growth and matching streamed residency;
Main/world/Player/fleet identities stay fixed. Node counts include retained
checkpoint/objective/observer/projectile/effect descendants. Read raw ownership
fields without pruning getters or scene mutation. Receipt/session/history
advances are legitimate data, not resource counters; do not exempt unnamed
retained resources or invent leak tolerances. Missing/unmatched comparison state
blocks the claim instead of weakening it.

Retain original300s for each complete cycle/readiness leg and monotonic outbound
≤60s from first actual engine demand; reject pauses in that timed leg. Derived
aggregate abort3300s = eleven unchanged300s caps; no old single-sortie cap grows.
One original conservative14:58:50UTC/90minute clock includes readiness, code,
focused checks/import/privacy, clean exports/strict startup, full route, review,
merge/push and owned branch/worktree/process/scratch cleanup; hard stop16:28:50.
No automatic retry. Source/results of a failure remain attached to this same
outcome and clock. Fresh accepted playable artifacts stay in builds/windows and
builds/linux, and an opt-in diagnostic/release result must not be described as a
new player mechanic or native-device/final-project qualification.

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
| REPEAT-BREACH / [physical alternating board](../scripts/activities/heavy_breach_activity_board.gd), [scenario director](../scripts/combat/encounter_scenario_director.gd) | On-foot arm posted Heavy, board/depart a real combat-capable ship, destroy actual charged picket while protecting objective, clear/pay, ordinary return/dock/on-foot rearm; count ten Heavy clears | PLAY-BREACH first. Conclusion rotates posting to Torpedo; full board cycle also includes Paired Wing/Perimeter before Heavy returns; no normal post-clear Reset required. Pending debt blocks arm. Respect normal craft service/ammunition constraints; qualified refill-on-pilot-retake is preserved; do not mint ammunition by fixtures. Existing BREACH-INTERRUPTION earned-debt case DONE c78e0ac |
| REPEAT-TORPEDO / same physical board/director, [boat](../scripts/ships/torpedo_boat_opponent.gd) | At posted Torpedo arm/board/depart, evade/intercept live seekers, destroy actual boat for clear and distinct Torpedo payment, ordinary home/board rearm; ten Torpedo clears | PLAY-TORPEDO first. Conclusion rotates to Paired Wing, then Perimeter, then Heavy; no direct selection to skip the actual four-posting cycle. Existing two-seeker pool and abandonment/stand-down remain bounded; heavy_breach_game_flow_production_route_test.gd staged kills are not ordinary combat repetition |

Heavy/Torpedo share travel/board ownership but retain **two separate ten-clear
counts**. Starting at fresh Heavy, obtain ten Heavy clears and ten Torpedo clears through
the ordinary Heavy → Torpedo → Paired Wing → Perimeter rotation. Twenty counted
Heavy/Torpedo successes require all intervening postings to conclude ordinarily;
twenty total sorties do not prove both counts. Failed or
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

Shared combat-board posting durability is accepted on 4968cf1a1: authentic
failed Heavy and withdrawn Wing conclusions survive actual-file distinct-process
loads, including the existing paid Torpedo completion/ledger. Pending posting-save
refusal/retry fences launches and preserves paid/unpaid fields in the focused
transaction fixtures. This is posting-only acceptance; ordinary Hold and wider
active/installed/final recovery remain open. Hold grants no credit in its existing
catalog; its terminal/home proof must not invent a payment.
[Exact scope and checks](history/ROADMAP_DELIVERIES.md#combat-terminal-posting-persistence-accepted-20261025).

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

WORLD-SHARED instances: **Ember, Aurora, Rime**, each with **baseline full outbound/return, late join, disconnect/reconnect, pilot loss, cancellation, real interruption, repeat visit**. Each cell is a separate task and must name participants, initial state, ordinary-input route and durable reward/return criteria before execution. The baseline includes activity and save behavior; failure cases do not inherit a staged baseline. Use existing `tests/network/halyard_network_shared_planetary_cruise_test.gd` and applicable world/landing tests. Missing exact case coverage blocks the corresponding existing SHARED row until Codex records its finite case contract; it does not authorize a new child or claim that the anchor already covers it.

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

The separately unrun silent/no-answer fault is now qualified on bd61da07 in
Linux-source/InputEvent scope: actual paused timeout at 5,005 ms, cleanup,
Retry/Cancel and fresh live-host reuse pass. This does not reopen or accept the
parked connected/raw-host package route above, or close the broader parent.
[Exact source-case proof](history/ROADMAP_DELIVERIES.md#browser-no-answer-source-accepted-20261025).

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

**Reopening review2026-10-21: dependency unchanged.** Current official stock
Linux template SHA2562cb27aee3f7fdf763d0ae16972f6975606959a071f4cd33f6ef1429eb8385049
and Windows76269a403bb832599edeee4432a5b7a7e88c018eb5c9c798dfd8289359b0ec07
are the stock pair, not matching RPC-cache teardown builds. Only the patched
Linux template completed; no accepted patched Windows PE after the retained
3600s cold/480s incremental attempts. Archive tags resolve diagnostic783c8c87206a
and prepared acceptancee5b9dd25f82c. No new dependency, build, engine or unchanged
browser retry is selected. Original full timeout/retry/disconnect/cancel/walk/quit
contract and existing build budgets remain intact.

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
| Forward W / reverse S; controller axis1 | throttle | move_axis[1] → decoded throttle → HeroShip flight thrust | Forward accepted96c96312f. Reverse full ordinary handback DONE isolated source102704512: actual1.342m/755ms, fresh neutral434ms, both replicas, supported walk/source-capture retirement after one causal caller correction. Prior52b228c86 flight result retained; physical bindings/devices/final gates stay separate. |
| Left A / right D; controller axis0 | yaw | move_axis[0] → yaw → host attitude | Turn/release DONE624d2a6; changed-caller regressionf9682a38c retains actual host/replica/neutral gates. Recorded full yaw/handback DONE007024839; physical-device qualification remains open. |
| Up/Down arrows; controller axis3 | pitch | look_pitch → pitch → host attitude | Full pitch turn/release/ordinary handback DONE isolated source d8c160f12: actual +4.800/−4.200deg, fresh neutral, real replicas, supported walk/source retirement. Earlier f9682a38c turn-only scope retained. Synthetic sampled actions; physical bindings/devices and final scope stay separate. |
| Roll left Q / right R; controller axis2 | roll | look_yaw → roll rate → host attitude | Full roll-rate turn/release/ordinary handback DONE isolated source d8c160f12: actual up-about-nose −5.867/+5.133deg, fresh neutral, replicas, supported walk/source retirement; no G barrel/fire/landing edges. Earlier73f4a4f67 turn-only scope retained. Physical bindings/devices/final scope stay separate. |
| Boost Shift; controller button7 | boost | run → boost → host acceleration/speed envelope | HELM-BOOST isolated source70c8a65e5: full ordinary route plus sampled actions→actual host14.65/19.45m/s², fresh release, both replicas and complete handback/source retirement PASS. No physical Shift/button7 or hardware qualification. |
| Brake PageUp / right mouse; controller axis4 | brake | crouch → brake → host deceleration | Ordinary two-client source96c96312f already proves sampled throttle/brake/neutral0m/s stop; no duplicate brake task. |
| Hover H; controller button0 | hover | jump → hover → host vertical/upright correction | HELM-HOVER isolated source524606903: real sampled pitch/climb→authored host vertical/upright correction, fresh release, both replicas and full handback/source retirement PASS. Normal yard only; physical H/button0, planetary and hardware acceptance stay separate. |
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
| INPUT-REMAP[one setting/binding] | GATED until one existing binding case has a frozen contract; physical confirmation separately | Name the action, old/new raw input, preserved controller bindings, conflicting action and chosen conflict response, exact Apply/Save and Reset values, distinct-process restart checks and actual gameplay consumer. Bind source/profile/command, limits and clean exits before running. Reuse existing remapping/persistence tests. Interact source case DONEcfa6199fb: [complete remap/conflict/three-process Reset qualification](history/ROADMAP_DELIVERIES.md#interact-remap-restart-qualified-20261025); earlier fixture stops remain recorded. Sprint TOGGLE/Reset/HOLD cold option→natural Player source case DONE7570edf7c ([scope](history/ROADMAP_DELIVERIES.md#sprint-toggle-cold-process-qualified-20261025)); full authored bindings/options retained. Fire remains accepted below. Stop at the selected case; neither closes the original Settings return route or physical-device acceptance. |
| FIRE-RESTART | DONE3a45c4d79 in original Linux-source real-file/distinct-process composition | Visible Fire row captures rawF13; actualApplySave/defaultfile; distinctsame-filereader row/InputMap/production LocalShipInputSource agrees onpress/release/formerF+leftmouseoff, gamepadbindings/unrelatedsentinel retained. Writer17checks/31.188s andreader19checks/31.012s, bothOS0/cleanlogs/original300s. Enginebuffer flushedbeforeobservation; originalkeys/predicates/flags/defaultsuite unchanged. Reviewed/merged/pushed/ownedscratchcleaned; previousfailures+source retained. Physicaldevice/fullSettings/native/final qualification separate. [Acceptance](history/ROADMAP_DELIVERIES.md#existing-fire-restart--full-raw-dispatch-and-separate-process-contract-qualified--2026-10-20) |
| ACCESS-VIEW[one view/scale/aspect] | GATED on one named required view and literal inspection criteria; relevant hardware separately | Bind existing view/route, source, pixel dimensions, requested/effective scale, renderer and visible text/focus/clipping criteria before capture. Select one required cell from existing minimum/default/maximum and aspect coverage; preserve accepted cells. Use existing accessibility tests. Stop at that view/cell's pass or first finding; no blanket readiness or full-view-family closure. |
| ACCESS-COMFORT[one route/option] | BLOCKED definition (Codex) for remaining episodes; canonical COMFORT-MOTION/FLASH/COLOUR/CAPTIONS rows govern | In the existing option's row, name the remaining original-required consumer/episode and literal ON/OFF, Reset and distinct-restart outcomes, route/command and limits. Previously accepted damage/toast episodes stay closed. Missing intended behavior is a named user decision; an existing option alone does not make a scenario ready. Stop at the frozen episode's pass or first failure; a correction requires the retained causal/budget review.  Reduced flash uses the fixed17-family contract below; its producer/policy definition stays closed and only the named production/trigger/caller/ordinary-proof gates remain. |
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

### Reduced flash producer and episode contract

**Finite source definition DONE on67a026991,2026-10-26; qualification OPEN.**
This binds existing COMFORT-FLASH/parent29 to17 families below. Shared code is
listed once; forwarders are not extra effects and this is not a craft×world×peer
matrix. These are existing authored behaviors, not new flash-safety limits.
The test references are reusable coverage anchors, not claims that this source
pass ran those tests or qualified every ordinary route. Existing HUD-current-cue
1a948d9ac and seeker-terminal9105da8 results remain accepted in their exact scope.

[RuntimeSettings](../scripts/settings/runtime_settings.gd) owns the boolean,
authored default/reset OFF (`DEFAULT_REDUCED_FLASH`,124/849). It is persisted as
`payload.runtime_settings.values.reduced_flash` in the existing
`user://mudds_user_data.json` store through
[RuntimeSettingsStoreAdapter](../scripts/settings/runtime_settings_store_adapter.gd).
[GameFlow](../scripts/game/game_flow.gd) owns actual application to the consumers.
No alternative preference, schema or validator is required.

| Existing producer family / owner | Authored OFF → ON result; current and new effects | Production binding and retained coverage anchor |
| --- | --- | --- |
| HUD damage — [hud.gd](../scripts/ui/hud.gd),149/3838/3854 | New-hit alpha0.24→0.07. ON caps the current effective alpha at min(current,0.07); OFF cannot brighten/restart that already-active cue. New hits use the selected policy. Reduced motion independently also caps this cue. | Canonical live Reduced flash event→current HUD setter DONE3649b4b; cold/snapshot bindings remain GameFlow→HUD. Native raw-key UI/current/new cue and save/cold/Reset pass in the shared proof below. Existing `accessibility_presets_test.gd` and `reduced_flash_settings_ui_test.gd`; accepted current-cue episode stays closed. |
| Pulse muzzle/impact — [pulse_weapon_presentation.gd](../scripts/effects/pulse_weapon_presentation.gd),418/1051/1161 | Dynamic lights visible→hidden/energy0. OFF muzzle `(0.55+1.85*muzzle_ratio)*style_light`, impact `(1-phase)*2.7*style_light`; pulse/flare/sparks remain. Current slots repaint synchronously; new slots use retained flag. | GameFlow25831. Existing `reduced_flash_combat_effects_test.gd`, `pulse_weapon_presentation_test.gd`. |
| Hull damage, including copied rig — [hero_damage_presentation.gd](../scripts/effects/hero_damage_presentation.gd),75/200/893/1474 | Impact `5.2*min(intensity,1.6)`→cap1.8; destruction13→3; warning oscillation→steady0.5; engine visual stutter→0.48; component flicker→0.5 times impaired/failed peaks2.4/4.6. Flight power unchanged. Existing cues update next presentation step; new cues use retained flag. | GameFlow25831→damage setter and `HeroShip.set_network_damage_reduced_flash`2808. Existing `reduced_flash_combat_effects_test.gd`, `hero_damage_severity_visual_test.gd`, `network_craft_pose_station_frame_test.gd`. |
| Engine glow/copied STARTING — [hero_ship.gd](../scripts/ships/hero_ship.gd),5644/2981 | Local starting glow `0.25+0.15*sin(elapsed*18)`→steady0.25; failing-engine glow uses damage rig mean0.48. Copied STARTING uses latest received sample→first retained STARTING sample, rebased on engine/component grade change. Local next presentation step; copied reassertion synchronous; new starting episode captures current baseline. | Fleet/copy forwarders above. Existing `reduced_flash_combat_effects_test.gd`, `network_craft_pose_station_frame_test.gd`. |
| Bomber payload — [bomber_payload_presentation.gd](../scripts/effects/bomber_payload_presentation.gd),88/528/562 | OFF low/medium/high trail length0.42/0.72/1, persistence1.25/4/8s. ON length min(profile,0.3), lateral0.72, transparency0.38, persistence≤0.7s; terminal steady ring scale1.35/transparency0.58, flare hidden. OFF restores authored profile-dependent ring/flare. Current flight/terminal slots repaint synchronously; new slots retain profile/flag. | GameFlow25855→bomber423→profile setter. Existing `bomber_payload_presentation_test.gd`, `game_flow_bomber_payload_settings_test.gd`. |
| Travelling bolts — [travelling_bolt_projectile.gd](../scripts/combat/travelling_bolt_projectile.gd),44/240/650 | Trail9→3.6m; core emission5.6→1.6; trail2.6→0.9; transparency0.34→0.66; dynamic light hidden. Current slots repaint synchronously; new/late pools inherit flag. | GameFlow25871/15572; picket pool1460. Existing `cinder_cargo_mass_driver_bolt_test.gd`, `standoff_picket_opponent_test.gd`, `cinder_convoy_production_integration_test.gd`. |
| Seeker flight/terminal — [seeker_torpedo_projectile.gd](../scripts/combat/seeker_torpedo_projectile.gd),78/298/766 | Trail7→3m; seeker emission5→1.5; trail2.2→0.8; light hidden. Burst4→1.2, peak scale4.2→2.6, same0.55s. Current flights/surviving bursts repaint synchronously at current age; new effects inherit flag. | GameFlow25877→boat316; lazy pool453. Existing `seeker_torpedo_projectile_test.gd`; accepted live-terminal9105da8 remains closed. |
| Opponent vent/destruction — [range_opponent.gd](../scripts/ships/range_opponent.gd),296/2225 | Vent peak5.4→1.9 with steady fade in either mode; destruction peak10→3 with existing decay. Vent synchronous, existing destruction next process step; new effects inherit flag. | GameFlow25871→opponents/reinforcements. Existing `range_opponent_weapon_heat_test.gd`, `reduced_flash_combat_effects_test.gd`. |
| Torpedo lock/charge — [torpedo_boat_opponent.gd](../scripts/ships/torpedo_boat_opponent.gd),80/316/425 | Lock emission4.8→1.6; brackets remain discrete/steady. ON inherited charge lenses use steady progress-based swelling and warning-light energy0; OFF uses inherited shimmer/light behavior. Lock material synchronous; charge next presentation step; new cues retain flag. | GameFlow25877→boat setter. Existing `torpedo_boat_opponent_test.gd`. |
| Replicated projectiles — [network_remote_projectile_replicator.gd](../scripts/network/network_remote_projectile_replicator.gd),361/543/599 | Emission multiplier1→0.35: body5→1.75 except torpedo1.2→0.42; trail2.2→0.77; burst4→1.4. Torpedo trail7→3m, raider/lance9→3.6m, slug remains5m; burst peak3.6→2.2 with same0.45s. Current flight/burst repaints synchronously without restoring flight visibility or resetting age; new records retain flag. | GameFlow13147/25883. Existing `network_remote_projectile_test.gd`, `network_emberline_bolt_test.gd`. |
| Copied actor materials — [network_emberline_actor_presenter.gd](../scripts/network/network_emberline_actor_presenter.gd),141/161 and [network_picket_actor_presenter.gd](../scripts/network/network_picket_actor_presenter.gd),165 | Captured authored `row.energy`→min(row.energy,1.0); health shading separate. Existing private materials repaint synchronously; new actor records use retained flag. | GameFlow12965/12997/25885. Existing `network_emberline_bolt_test.gd`, `cinder_convoy_production_integration_test.gd`. |
| Station solar/environment — [station_solar_readability_presentation.gd](../scripts/world/station_solar_readability_presentation.gd),14/193 | Captured-baseline-bounded OFF→tighter ON caps specified below, with no authored animated flash suppression. Current environment synchronous; rebuilt presentation uses retained setting. | GameFlow25849→world5858/5892/6411. Existing `station_solar_readability_presentation_test.gd`. |
| Cinder lane/gate markers — [cinder_asteroid_field.gd](../scripts/world/cinder_asteroid_field.gd),179/513 | Lane/gate emission3.2/3.0→1.5/1.5; static in both modes. Existing materials repaint synchronously; new field/streamed generation receives retained setting. | World5871→cluster4182/2839; streaming binding458. Existing `cinder_sector_art_pass_test.gd`. |
| Entry HUD/cockpit — [atmospheric_entry_guidance_presenter.gd](../scripts/ui/atmospheric_entry_guidance_presenter.gd),159 and [arrow_entry_cockpit_readout_presentation.gd](../scripts/effects/arrow_entry_cockpit_readout_presentation.gd),204 | `! ENTRY LOAD RISING !`→`[ STEADY ENTRY LOAD RISING ]`; `!! ENTRY LOAD CRITICAL !!`→`[ STEADY ENTRY LOAD CRITICAL ]`; cockpit critical/high-sink color ff796f→f4c879. Text/symbols retained; renderers are already nonflashing. Current/new accepted observations read selected flag. | HUD accessibility→Arrow binding137–175→HUD5248/cockpit. Existing `arrow_entry_presentation_production_caller_test.gd`, `atmospheric_entry_guidance_presenter_test.gd`. |
| Entry exterior — [arrow_entry_exterior_envelope_presentation.gd](../scripts/effects/arrow_entry_exterior_envelope_presentation.gd),14/260 | Intensity-scaled opacity cap0.78→0.42, emission2.2→0.95; recovery ring opacity0.78→0.42/emission1.8→0.95. Motion policy separate. Current/new effects change on next accepted observation. | Arrow observation binding; fleet atmospheric binding171; Ember loop2462–2502. Existing `arrow_entry_presentation_production_caller_test.gd`, `hero_fleet_atmospheric_entry_envelope_production_test.gd`. |
| Airless wash — [arrow_landing_dust_wash_presentation.gd](../scripts/effects/arrow_landing_dust_wash_presentation.gd),13/245 | Dust opacity cap0.72→0.324, multiplied by actual clearance/descent load. Thruster opacity=dust×0.82: cap0.5904→0.26568. Motion geometry separate. Current/new wash changes on next accepted observation. | Arrow binding137 or fleet wash binding100; same production observation loop. Existing `arrow_entry_presentation_production_caller_test.gd`, `hero_fleet_airless_landing_wash_production_test.gd`. |
| Cargo terminal supported cap — [cargo_transfer_terminal.gd](../scripts/cargo/cargo_transfer_terminal.gd),395/440 | OFF unavailable0.18, ready1.15, carrying2.2, terminal3, committed2.7, rejected3.2, reset0.25; ON caps each at1.15. Steady in both modes. Current detached record repaints synchronously without changing text/state/authority; new/reentered generations inherit the retained flag and original ordinary rebind semantics. | Production forwarding DONE d4e2213: cluster setter/readiness→binding retained preference→normal publisher and exact cached visual replay. Existing `cinder_cargo_transfer_presentation_state_test.gd` proves all high/low states and invariants; real Main `reduced_flash_combat_effects_test.gd` proves actual setting chain at unavailable0.18 plus live/new-generation inheritance. Direct-injection readability tests remain only their original component scope. [Accepted scope](history/ROADMAP_DELIVERIES.md#cargo-terminal-reduced-flash-production-binding-accepted-20261026); ordinary UI/cold/full comfort remain open. |

Station caps OFF→ON, each respecting captured baseline: exposure1.08→0.94,
glow intensity0.34→0.18, strength1.05→0.72, bloom0.006→0.002, threshold
floor1.45→1.65, HDR scale2→1.35, luminance3→2.4, fog sun scatter0.04→0.015,
volumetric anisotropy0.35→0.2, glow-level caps[0,.7,.5,.18,0,0,0]→
[0,.38,.22,.06,0,0,0]. ON sun halo=min(captured baseline,0.08); OFF restores
captured halo. A cap is not a request to brighten an already dim baseline.

**Excluded from additional visual obligations:** caption renderer/preview remain
steady with no owned Tween/AnimationPlayer. GameFlow25801 currently forwards
Reduced motion to a service parameter named reduced_flash; this mislabels service
transition metadata but has no current rendered flash difference. No visual
repair is selected for that metadata. Detached RuntimeAccessibilityPresentation,
visual/audio/caption accessibility contracts and CameraComfortSettingsBinding
have no production callers in scripts; they are not extra live effects. Cargo
route/threshold geometry, interceptor beacon, engineer work light, berth
practical, habitat/aft lights and Ember status/survey/return markers are declared
steady safe nonconsumers: metadata alone creates no new ON/OFF policy.

**Shared preference proof — DONE3649b4b in native Linux synthetic-keyboard scope.**
[Actual result](history/ROADMAP_DELIVERIES.md#shared-reduced-flash-native-restart-accepted-20261026) uses normal Boot/Main and
real controls across three distinct reaped processes. Staged actual HUD cue
properties are component proof; physical input, rendered visibility, ordinary
producer journeys and native Windows/GPU/human gates remain open. One settings
transaction/restart proof is shared across these families; do not duplicate it
as17 storage tests. Per-family effect construction/forwarding still needs its
own actual observation. Freeze one candidate/private profile and keep Reduced
motion OFF and payload intensity at authored default2/high to isolate Reduced
flash, unless the original selected episode explicitly fixes another profile.
Supported profile values above do not create another profile×family matrix.

1. In normal gameplay, press Escape, SETTINGS (`SettingsOpenButton`), then
   ACCESSIBILITY→Reduce screen flashes (`ReducedFlashControl`). The real toggle
   emits setting_change_requested; checkbox, RuntimeSettings boolean and the
   selected family's actual presentation must agree with its table row. Use an
   already-running cue and a new cue where the row distinguishes them.
   A timed current cue must be visible with positive remaining lifetime; an
   expired cue cannot substitute for a live-transition check.
2. Pause is real SceneTree pause (`hud.gd`2829). A current transient may be
   inspected while paused; toggling must not mint a new event, replay an expired
   one, extend a timer or change gameplay authority. Follow each row's stated
   synchronous/next-presentation/next-observation update timing; do not invent a
   universal immediate callback for observation-driven effects.
3. Toggle OFF→ON→OFF→ON through the visible control. For HUD's current damage
   cue retain its accepted no-relight exception; other rows retain their own
   authored live behavior. Compare actual nodes/materials/text, not only a
   settings snapshot or a profile that reports intended constants.
4. Press APPLY + SAVE (`SettingsSaveButton`); require actual successful save
   feedback, cleared dirty state and disk boolean true in
   payload.runtime_settings.values.reduced_flash. Use the ordinary production
   store, not seeded settings or a substitute config-file path. Record its real
   primary/backup bytes and permitted production commit changes.
5. Exit through the normal HUD owner; require actual process exit0 and real
   orderly markers. Reap it. Launch a distinct process with the same private
   files. The cold checkbox, runtime value and a genuinely new selected effect
   must agree with ON. Retained-Main remove/re-add alone cannot prove this step.
6. Press RESET DEFAULTS (`SettingsResetButton`), confirming
   `ConfirmSettingsResetButton` if the dirty-settings prompt is shown. This is a
   whole-settings reset, not a Reduced-flash-only reset. Require actual successful
   reset feedback, boolean false, table OFF behavior for applicable current/new
   effects and persisted false. Normal exit/reap then a third process must show
   authored OFF/default behavior. Keep unrelated gameplay data protected within
   the selected frozen case; do not confuse legitimate shutdown markers with
   preference corruption.
7. Existing persistence/refusal/dirty-state ownership is reused. A refused save
   cannot be reported as saved or erase the previous durable choice; a live
   preview may remain dirty. General refusal coverage is shared, not a new
   failure-grid per effect. No engine duration is changed: preserve existing
   suite and original ordinary-route limits when binding the actual command.

Actual owners/anchors: HUD7992/8041/3113 controls and confirmation;
GameFlow7284/26313/26328 save/reset handlers; RuntimeSettings598/721/849 and
RuntimeSettingsStoreAdapter default store/slot. Existing
`settings_reset_confirmation_ui_test.gd`, `settings_persistence_feedback_ui_test.gd`
and `runtime_settings_production_persistence_test.gd` protect their named pieces.
The last file retains its Fire/Interact/Sprint/Colour modes. The Reduced flash
sequence is now executed by embedded `runtime_settings_restart_probe.gd` through
actual Boot, using `run_package_probes.sh --settings-restart --native-export`.
Source `3649b4bbb34742a4fd9d076576c6665fc4355a5f`, real three-process result and raw files are in the linked
acceptance. Production persistence47 also protects refused-save HUD dirty state
and successful retry clearing; these are injected-source checks, not physical input.
Do not rerun the unchanged caller definition or duplicate this store proof per family.

**Cargo runtime capability DONE d4e2213:** real setting forwarding and current
  material refresh pass the focused high-state and real-Main setting-chain checks
  ([proof](history/ROADMAP_DELIVERIES.md#cargo-terminal-reduced-flash-production-binding-accepted-20261026)). Text/state and transfer/
  inventory/reward/interaction authority stay unchanged. This closes the named
  production gap; the shared native preference sequence is accepted in3649b4b
  below. Earlier direct-injection effects do not become ordinary cargo proof.

**Literal remaining work and owners, not an automatic queue:**

- **Shared executable preference proof DONE3649b4b:** real embedded native Linux
  writer/reader/reset-reader, raw keyboard GUI events, actual Save/Reset/normal
  Quit, exact primary/backups and preserved unrelated namespace pass. Reuse
  [this result](history/ROADMAP_DELIVERIES.md#shared-reduced-flash-native-restart-accepted-20261026); do not schedule the
  missing-caller task again. Physical input/rendered and external hardware gates
  remain open; an identified consumer/source change can require affected rechecking.
- **Codex episode qualification:** for each not-yet-qualified table family,
  bind one original normal effect trigger and its existing observer/caller.
  Shared local pulse/hull/combat cues reuse the original Guided combat route;
  bomber payload, Cinder bolts/markers/terminal, Torpedo Run, replicated peers and
  planetary entry/wash use their existing named cargo/combat/network/world routes.
  Where that route/participant is still gated, retain that exact dependency and
  name the missing trigger/observer in the selected card; never substitute a
  synthetic snapshot as an ordinary journey or rerun a parked route unchanged.
  This roster fixes producer/observable membership; ordinary trigger/caller
  bindings are still required before those qualification assignments are ready.
- **Native hardware/device and human visibility gates:** NOT_RUN or existing
  owner exclusion until actually performed. Property checks/source maps cannot
  close them. No new device/platform promise is inferred by this definition.

A family result closes only its named runtime/episode scope. The full
COMFORT-FLASH container closes after all required shared preference, listed
producer episodes and applicable original external gates have actual proof.
No implementation, engine, capture, package or new test was run for this source
definition. No new goal IDs, validator family or gameplay requirement is added.
This definition stays closed unless a named producer or caller changes; amend
that affected row instead of repeating an unchanged whole-family source survey.

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
| ACCESS-TITLE: ordinary startup menu and return from browser/credits | GameHUD intro layer / `show_intro`, `_focus_intro_start_button` | `startup_loading_screen_test.gd` proves menu readiness; `controller_pause_navigation_prompt_test.gd` covers browser return and `credits_page_test.gd` covers credits return. A selected cell checks title text, Begin Shift/browser/credits buttons and retained enabled focus. Unresolved recovery choices use ACCESS-RECOVERY below.  Overflow fix DONE checkpoint19e7990: actual default1024x768 before/after component capture plus eight-viewport title/control regression; focus/credits remain. ACCESS-TITLE-FOCUS is DONE checkpoint923d7b3 within its recorded palette/state scope; do not reopen the old light-on-cyan finding. No full-Main, other state/scale/device acceptance. |
| ACCESS-GAMEPLAY: approach, boarding confirmation, first-sortie tutorial, activity briefing/objective, weapon readiness, component damage, fleet registry | GameHUD interaction/tutorial/objective/weapon/component/registry panels; boarding confirmation adapter | `ultrawide_layout_test.gd` names these states and checks production Controls. Retain actual simultaneous telemetry/minimap/help/toast/interaction/status composition; one selected state/cell must preserve readable labels and nonoverlap rather than fabricate every possible card combination. |
| ACCESS-HELP: on_foot, aboard, driving, piloting; each reachable help page, plus published copilot/loadmaster context rows | `_help_rows_for_mode`, `_help_rows_with_role_context`, `_refresh_help_page`; five rows per page | `help_overlay_accessibility_test.gd` checks paging and enabled boundary focus; `runtime_input_glyph_hud_integration_test.gd` checks device text. A cell checks all pages of one named mode/context, labels and Previous/Next/Close focus. Aircraft-specific text uses the existing selected craft; new control semantics are not implied. GAMEPAD-LOOK repairs the found camera-input gap in checkpoint99e79c3. |
| ACCESS-ACTIVITY: selection page, current selection/status/reward summary, return from nearby page | ActivitySelectionPage / `open_activity_board`, `_show_activity_selection_page` | Existing ultrawide `activity_board` calls `open_activity_board`: this is the selection page. It does not cover NearbyActivityPage. Check visible rows/footer and return focus in one cell; preserve authored selection behavior. |
| ACCESS-NEARBY: activity list, current progress, rejected start guidance, terminal delivered/lost feedback | NearbyActivityPage / `show_nearby_activity_page`, `set_nearby_activity_snapshot` | `nearby_activity_hud_integration_test.gd` covers real HUD entry, ten production rows and cargo pickup/transit/delivery/terminal feedback. DONE selected0d77125/checkpoint0d77125: bounded ten-row scroll region, fixed feedback/SaveLoadBack, whole focused row after retained priority/progress updates and no stale Back focus; actual accepted defense arm receipt says ARMED/board-and-depart. HUD124/Main16 and inspected two actual component views pass. Main active-reset uses disclosed existing owner fixture, not ordinary launch. Other cells/full activities/native/device and parked UI-BOARD-FOCUS remain open; [result](history/ROADMAP_DELIVERIES.md#nearby-activities-bounded-list-and-armed-feedback--shipped-on-0d77125--2026-10-25). |
| ACCESS-DESTINATIONS: destination list, selected destination detail/status, enabled travel and Back | PlanetaryDestinationPage / `open_planetary_destination_board`, `_restore_planetary_destination_focus` | `planetary_destination_console_production_test.gd` covers the actual console route; catalog/content-contract tests describe authored rows. DONE scoped9477a89/checkpoint9477a89: actual five-card board now has bounded vertical scrolling with fixed heading/Back;1024x768/requested1.6 actual-Main91 assertions, enabled final-site focus/no dispatch and inspected Forward+ component top/bottom pass. Existing layout552/accessibility1979 retained by exact production source. Other cells/ordinary travel/device/native/full parent remain open; [accepted result](history/ROADMAP_DELIVERIES.md#destination-board-bounded-cards-and-focus--shipped-on-9477a89--2026-10-25). |
| ACCESS-BROWSER: refreshing, available/full rows, all-full, empty, unavailable/retry; manual controls and connection cancel/disconnect | ServerBrowserPage / `_show_server_browser_page`; server_browser_presenter | `server_browser_hud_integration_test.gd`, `server_browser_focus_navigation_test.gd`, `server_browser_manual_controls_hud_integration_test.gd` cover status/focus behavior. Select one state/cell; verify headers, filters/sort, scroll rows, guidance and enabled footer actions. Connection-state wording follows the current network presenter; this is not network qualification. |
| ACCESS-CREDITS: intro entry and pause entry; attribution list and engine notices; return to opener | CreditsPage / `_show_credits_page`, `close_credits_page` | `credits_page_test.gd` covers entry provenance, scroll focus and content. A cell checks top/bottom/notice text and keyboard/controller focus return. No new attribution or license scope is created. |
| ACCESS-CAPTIONS: current caption, transcript collapsed/expanded, transcript paging | caption_presentation_service, caption_presenter; GameHUD semantic transcript controls | `caption_presenter_layout_test.gd`, `caption_accessibility_contract_test.gd`, `caption_production_integration_test.gd` and ultrawide captions state supply existing anchors. Check readable caption/history controls and supported surrounding cards. Preserve the existing ToastPanel/expanded transcript non-simultaneous exemption. Dummy checks cannot qualify audible output.  Actual1280×720/request1.6 max64-source/512-body check fails safe containment (650px intrinsic/411.130px safe), with stable original fonts and convergence. Owner overflow-policy choice pending; no synthetic500-band substitution or runtime repair. [Measured boundary](CAPTION_VISUAL_PRESENTER.md#open-maximum-payload-overflow-policy). |
| ACCESS-ROLE-STATUS: copilot navigation support, loadmaster telemetry, bomber readiness, boarding/recovery cue | GameHUD runtime status composition; copilot/loadmaster presenters, cinder_loadmaster_hud_binding, boarding adapter | Existing copilot/loadmaster/bomber/boarding/audio-recovery HUD tests cover their own published payloads. Select one card/cell and its actual priority/retirement composition; check text, actions and caption reservation. Do not force mutually exclusive foreground cards to coexist or infer role authority from the HUD. |
| ACCESS-RECOVERY: title recovery notice/choices/support feedback, safe-start recommendation/result | GameHUD recovery prompt layer; safe_start_recovery_presenter | `session_recovery_hud_test.gd`, `game_flow_session_recovery_hud_integration_test.gd`, `game_flow_safe_start_recovery_hud_integration_test.gd` cover their named routes. Check one visible notice/result and enabled action focus without initiating destructive recovery as a layout shortcut. This does not accept parked interruption routes. |
| ACCESS-REST: entering/resting/leaving visible overlay and wake affordance | `scripts/ui/ship_rest_overlay.gd` | Existing ultrawide `ship_rest_overlay` state constructs the actual overlay. A cell checks its authored presentation and wake text with current motion setting; rest gameplay and physical controls remain separate acceptance. |

Before further cell selection, Codex records the exact original-required
state/aspect/scale membership for each existing family here, distinguishing
accepted, unrun and dependency-blocked cells. If the original contract does not
establish membership, record that exact unresolved coverage input and keep the
family GATED; do not infer extra combinations. A family closes only when all its
fixed required cells pass. This source roster alone does not settle membership.

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
| PACKAGE-LINUX[matching checkpoint] | DONE for currentca149d6 delivery: exactclean LinuxELF/archive/notes, actualdirect21.988s/archive22.459s startup eachOS0/sentinel1/zero diagnostics; all1527 actual entries match acceptedWindowsca; exactsix-member archive bytes/modes/metadata, independent review andownedcleanup. Same LAN-checkpoint90min clock/prior10 charged; no reset. Earlier8c delivery retained. Finalcandidate/ordinary/install/native gates remain GATED; no newruntimechange or broader qualification. [Current matching delivery](history/ROADMAP_DELIVERIES.md#linux-lan-expiry-checkpoint-accepted--2026-10-25) | Export matching ELF/archive; existing inventory checks, exact member bytes/modes, direct and archive-extracted strict startup. Stop at exact artifact checks. |
| INSTALL-WIN[one candidate] | GATED on packages | Build matching installer with existing NSIS tooling and inspect exact extraction/build identity and applicable non-execution checks. Native installation/execution is excluded; do not bypass antivirus. Stop at artifact checks, with unperformed runtime factual NOT_RUN. |
| LINUX-BUNDLE[managed installer] | DONE on `653c1459d`; actual six-member package verified | Ship the delivered manager in the archive, preserving explicitly supported old/new bundle contracts. Stop at archive install/update/uninstall, exact binary and protected-data checks using existing tests. |
| INSTALL-LINUX[one transaction] | ELIGIBLE for managed per-user install | One clean install, old-to-new upgrade, rollback, retained/corrupt data handling or uninstall transaction preserves saves/unrelated files and exact owned artifacts. Installer12 tests and actual shipped-manager36 checks pass onb41c3cc, including named first-install/update SIGKILL publication cuts and fresh retries. Current LINUX-UNINSTALL-CUT reproduces the shipped a8 missing-menu refusal after an actual post-desktop-unlink SIGKILL; source repair505d41968 is accepted with all14/no-skip installer tests; checkpoint505d419 ships the fixed manager and passes the actual named SIGKILL/retry/repeat with protected bytes/modes intact. Select uncovered/new-candidate transactions, not redundant reimplementation. This named uninstall cut is accepted; other cuts/power loss remain open. Clean b4ff8c0 checkpoint transaction and installed full Guided route accepted2026-10-26: exact shipped-manager/archive payload/modes/launcher, strict startup0/one marker, Guided55.720s/ordinary HUD OS0/zero diagnostics, uninstall only owned files/five protected fixtures unchanged/all16 observed identities absent. [Frozen recipe, retained wrapper failures and cleanup](history/ROADMAP_DELIVERIES.md#linux-installed-checkpoint-guided-qualification-accepted-20261026). Final INSTALL-LINUX-CLEAN and graphical desktop launch remain open; reuse this recipe rather than reimplement the installer. Checkpoint499e681→b4ff8c0 upgrade also accepted2026-10-26: fresh owned generation/exact payload/modes/launcher, old owned files removed, strict startup0/one marker, installed fullGuided55.707s/normalHUDOS0/zero diagnostics, shipped uninstall/five protected fixtures unchanged/all15 observed identities absent. [Upgrade recipe/raw proof](history/ROADMAP_DELIVERIES.md#linux-checkpoint-upgrade-499e681-to-b4ff8c0-accepted-20261026); protected actual earned-credit save is not gameplay-reload acceptance. Final INSTALL-LINUX-UPGRADE remains gated. |
| LINUX-DESKTOP[one entry/ordinary route] | WAITING on clean isolated graphical Linux session if unavailable | Launch actual installed desktop entry or direct ELF and complete ordinary route; test each separately. Inert GIO argv probe and headless startup are insufficient. Stop at entry+route result; no implied native GPU/input/audio qualification. |
| CAPTURE[one required registry ID] | GATED on frozen candidate and runnable environment | Run unchanged registered harness with isolated X11/Dummy, verify declared source and exact images, inspect original-resolution output and fix actual finding separately. Stop at one set. Human stages are excluded; hardware gates separate. See blocked sets below. |
| RIGHTS[one asset/source family] | GATED on available provenance/rights information | Record licensing/redistribution disposition for the named family. Preserve owner's settled creator-permission account without claiming a written grant or asking again. Stop at clearance or exact missing external document. |
| SIGN[one exact artifact family] | WAITING on trusted certificate/credentials outside repository | Use existing `sign_windows_artifacts.sh` workflow to sign/verify game, installer and uninstaller, expected publisher and exact distributed bytes. Development signing cannot qualify. Stop at trusted signatures; native Windows execution is not required. |
| MATRIX[one frozen integrated candidate] | GATED on targeted repairs/integration | Clean import and existing unfiltered `--mode all` matrix at original suite/long caps, no exclusions, including isolated graphics. Stop at complete result; failures become named child fixes. Do not rerun whole matrix for every small change. |
| FINAL-RECONCILE[one candidate] | GATED on required content, matrix and applicable platform/device/performance/audio/endurance/install/capture/signing results | Reconcile all original promises and exact candidate results with existing `release_candidate.py`, candidate record and `SHA256SUMS`. Zero open P0/P1, explicit reviewed P2/residual-risk dispositions including RENDER-001 where applicable. Changed source invalidates affected qualification; owner exclusions stay excluded. Stop at actual complete or named unmet gates, never a new evidence layer. |
| DISTRIBUTE[accepted candidate] | GATED on FINAL-RECONCILE and authorized destination/publication | Publish exact qualified artifacts/checksums and concise player-facing notes using existing release flow. Stop after byte identity and download checks. No Downloads copy or public publication implied by local checkpoints. |

### Installed retained Heavy load — selected checkpoint contract

**Checkpoint retained-load case ACCEPTED a716c4d8e, 2026-10-26.** One actual
b4 native load33.683s after499→b4 installed upgrade: real primary generation19→23
at title→24 at next posting→27 orderly close, healthy session/startup2, exact
live credit1/paid terminal/settings, three supported waypoints51.262m/actual
unarmed Torpedo candidate and normal UI OS0/no regrant.251 Python checks pass
after one producer-fixture field correction; original failed suite remains.
One private wrapper umask/missing-cleanup-variable setup failure occurred before
any game; corrected installer-only022/manifest-derived cleanup preserves strict
modes and all records. [Full acceptance and source/archive closure](history/ROADMAP_DELIVERIES.md#installed-retained-heavy-load-accepted-20261026).
Python driver/tests alone changed; unchanged b4 observer/package reused. Full
runtime settings/rendered desktop/native hardware/final-package gates stay open.
The finite contract below is retained; no unchanged rerun or new source survey.

Existing INSTALL-LINUX-RETAINED, checkpoint case selected2026-10-26/source103ca4593.
Prior499e681→b4ff8c0 transaction proves bytes/modes only. This assignment adds the
missing ordinary production-load release caller, not another save validator.
Own only `tools/release/run_native_sortie.py` and its existing Python test. Reuse
existing b4 exported `heavy-breach` observer; no game/GDScript/export change.

Input is actual `ordinary-sortie/orderly-close.json` from accepted
`/srv/mudds-work/heavy-picket-damage-admission-20261025/results/case-records.tar.gz`:
8655bytes/SHA25625f9ccfe03b22018eae2cffcb52841ed5fbcff3f4a51a6c020e6c7495701aa73,
generation19, clean crash/session1/startup1/unclean0 and clean safe-start1/failures0.
It contains exactly one non-replayable generation1 Heavy credit, acknowledged
terminal generation floor1/offered index1, schema11 settings, on-foot Arrow home
preference and seen tutorial `shipyard_heavy_breach`. This is a declared valid
fixture; do not synthesize its entitlement or mutate live authority state.

Use the existing shipped manager to install499 and upgrade the same owned prefix
to b4, preserving that fixture and unowned files/bytes/modes; resolve installed
ELF from manifest and compare fixed archive/export bytes/modes/launcher. The
new opt-in route `retained-heavy --retained-data FILE` seeds only
`PROFILE/data/godot/app_userdata/Mudds Shipyards/mudds_user_data.json` inside the
existing new TemporaryDirectory, before launching. Reject this input flag on
all other routes. Keep private XDG ownership, bounded input/abort/process cleanup
and300s single-route cap; do not accept an arbitrary reusable user profile.

At normal menu_ready, independently read actual primary save at the observer's
owned profile path: require source primary, generation advancement and healthy
session/startup2/no unclean start or recovery recommendation. The live decoded
reward authority must equal fixture ledger1; stored runtime settings and paid
Heavy terminal stay exact. Settings equality is actual primary data preservation;
only existing mouse/walk/default-control observables establish applied tuning,
not a full comfort/settings runtime qualification. The cold director is deliberately IDLE/active generation0,
while the board restores `torpedo_run`, highest paid generation1, pending0,
unarmed. Do not misuse the combat-era require_paid generation equality.

Press ordinary E on BEGIN SHIFT, enter APPROACH_SHIP at authored spawn; clean
quit retains safe home preference, not former actor position. With current stable
actors/awake supported controls, follow existing Heavy outbound waypoints
(-8.5,.18,6)→(8,.18,6)→(8,.18,-24), using existing bounded walking/steering and
completed-motion/support predicates. Require the actual board candidate/available
TORPEDO RUN prompt; do not arm, shoot, start an activity or award again. Pause and
use observed Escape/Tab/Return controls on EXIT TO DESKTOP; require actual OS0,
released inputs and all helper/game/Xvfb reaped. Independent final primary capture
must contain both clean markers and unchanged ledger, terminal, settings and
other protected siblings. Permit only the existing named ordinary session/safety
updates; no unlisted progress loss or additional receipt is allowed.

Conservative original16:11:00UTC/90min includes readiness/code/existing
focused suite/review, one actual installed continuation, checks, integration/push
and branch/worktree/process/scratch cleanup; hard17:41:00. Stop first unexpected
failure and retain source/result; no automatic correction/retry. No duplicate
export is needed for Python-only driver work. This can close only this checkpoint
retained-load case; final INSTALL-LINUX-RETAINED, rendered desktop/device/native
hardware and other recovery/active-run cases retain their original gates.

### Selected checkpoint rollback — retained-save contract

**Checkpoint case ACCEPTED** on driver503dbf6f6; sole native load34.017s,
transaction76.699s, strict startup exit0/one readiness marker. Exact older payload
and newer-save session2→3 continuation pass; all six protected files survive
uninstall, all18 owned process identities are absent. [Actual result and archive](history/ROADMAP_DELIVERIES.md#selected-checkpoint-rollback-accepted-20261026).
The frozen pre-execution contract below is retained; it does not select a rerun.
Final-package and other explicitly excluded cases remain open.

Existing INSTALL-LINUX-ROLLBACK, one selected checkpoint transaction, source
f2a4c568d/2026-10-26. Original finite requirement permits a failed-update or
selected-rollback trigger; this case chooses the latter, not an injected failure.
Use shipped manager `install --archive FILE --install-dir PREFIX --applications-dir APPS`
for499→b4→499 in one owned prefix. Pin499 archive
994457c9a15fe3b0b9b4d72bccf8df427f17adba540cc8fb6289acae612bf8ea,
b4 archive6c93c752a631aacee8e698d8fa2ffb3cd3cbd4418526ba555df6607ea7f5b375;
shipped manager f0bc2779bd918513f276e9527f5e956e7e75ccd376e192130d036e542a25f467.
Installer children use explicit022 umask; private profiles retain0700 isolation.

Each publication creates a fresh generation: verify exact archive ELF/icon bytes,
755/644 modes, owner manifest/launcher0644 and literal Exec/Path/Icon. Selected
rollback must restore original499 ELF SHA
8802ba25e2dadf56665f39697d48ddb19b340f6cab70f4a7bec42e41c52ff678,
remove the b4 generation's managed files and preserve every named unowned note,
actual saved-data bytes/mode and unrelated launcher. Restored directory UUID need
not equal the initial499 UUID; restored payload bytes must. Shipped uninstall
must remove final managed payload/manifest/entry/journals only.

Use actual b4-produced `transaction-corrected/retained-load/orderly-close.json`
from `/srv/mudds-work/retained-heavy-20261026/records.tar.gz`:9296bytes/SHA256
`af2fada0a687b3a2dad6ee5c4550d4e6cd92120f2df94f6681f053e5b23ed409`,
generation27, clean session/startup2, no failures, ledger Heavy credit1/paid floor1,
Torpedo offered, exact schema11 settings. Preserve it in owned private XDG during
all installs; pass those exact post-rollback bytes to the existing isolated
`retained-heavy --retained-data FILE` on the restored installed499 executable.
Original8655byte fixture remains accepted; admit only these two declared inputs,
without new format/schema/validator families. Validate healthy session/startup
advance relative to the pinned input(2→3 here; original1→2 unchanged), matching
new session-start diagnostic, primary source/generation advance, unchanged earned
ledger/paid terminal/settings/other protected siblings, and final clean markers.

Reuse the existing three supported Heavy walk points and actual unarmed Torpedo
candidate/availability/prompt, then normal observed UI Quit/actual OS0. No arming,
weapon action, grant, actor/store mutation or clock override. Keep original300s
native/independent330s, authenticated private Xvfb/x11/Dummy/dummy renderer.
Old/new observer/startup/game-flow/persistence PCK entries are byte-identical;
mechanical inspection finds only damage adapter changed across the1529 entries.
That supports this exact saved-state continuation; it is no general future-schema
rollback promise. No new export or redundant source parser/graphics matrix.

Own only existing native-sortie Python driver/test for the declared fixture and
baseline-relative session check. One bounded implementer/independent reviewer;
root owns transaction/one actual prior-version load and integration/cleanup.
Conservative16:42:43UTC/45min includes readiness/code/checks/run/archive/push;
hard17:27:43. Stop first unexpected failure and retain it before any causal review;
no automatic correction/retry or renamed budget. Exact final-package,
failed-update interruption, power-loss, rendered desktop and hardware facts
remain in their existing open gates.

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

### Ordinary Jovian engineer recovery — selected contract

**One checkpoint case ACCEPTED378d99caf,2026-10-26.** Sole corrected full route
passes79.277s: actual engineer commit10/parent9, -9/reaped first process,
distinct normal recovery/session2/awake supported cabin, two real walk goals,
actual helm/ONLINE command1/native thrust and normal UI0/finalclean. Seven actual
documents retain every protected sibling; fresh settings-only profile has no
earned activity/reward to qualify. The runtime repair includes Jovian in existing
guarded cockpit aim priority; explicit co-pilot/engineer choices remain. Captured
RED/GREEN7, Python260, paired exports/three strict startups/1529-entry audit and
independent source/raw review pass. [Actual proof and archives](history/ROADMAP_DELIVERIES.md#ordinary-jovian-engineer-recovery-accepted-20261026).
Original17:01:14UTC/90min includes prior30.639min/PARK/parse failure, reviewed
reopening, readiness correction, actual trial and closure. No cap/reset/route
change. Historical selection/PARK/reopening contracts below are retained as
history; none schedules another run. Installed/final/earned-debt/othercrew/native
requirements remain in their original gates.

**Explicit reopening2026-10-26 after reviewed typed-fixture prerequisite.**
Typed fixture SHA256 e09f8cd097b0346c31a173b9b6e6e76681921b2b6b1e17aa66324bbc79f66ac6
changes only camera:Camera3D, berth:ShipBerth, origin:Vector3, facing:Vector3.
All captured geometry/seven assertion groups remain. Independent priority review
selects this same outcome with prior30.639minutes retained, original17:01:14UTC/
90min/hard18:31:14 unchanged. Permit one silent isolated import and one old-RED
with exactly the intended cockpit-selection mismatch and all other guards/negative
chair choices passing; then the previously bounded runtime/driver repair, GREEN,
Python/source review/paired exports/strict startups/audit and ONE full native retry.
Any unexpected failure parks again; no further fixture patch/retry cycle. Existing
seven-file ownership and full original route/data/300s/330s remain binding.
The original stopped result and archive below remain retained unchanged.

**PARKED after the correction's first preflight failure.** The intended old-RED
regression did not execute: GDScript could not infer camera/berth/origin/facing
at fixture lines672/677/679/680; exit1/16.617s. Production GameFlow and driver
remain unchanged on d192f1e38; only the new test selector is uncommitted and
preserved. Independent review upheld the literal next-unexpected-failure stop.
No four-type edit, old-RED rerun, GREEN, runtime repair, export or native retry
occurred. The following selected/correction contracts are historical, not active
authorization. [Actual records and source archive](history/ROADMAP_DELIVERIES.md#ordinary-jovian-crew-recovery-parked-20261026).
Reopening requires reviewed typed fixture source plus explicit independent
cumulative-priority selection for this same outcome; preserve all previous cost,
actual route/data/endpoints and original300s/330s. No renamed successor or
fresh budget. The underlying Jovian cockpit-priority defect remains open.

**First trial stopped; one causal correction selected, same clock.** Candidate
d192f1e38 passed258 Python/privacy3311/import, paired exports, three strict
startups and1529-entry audit. Native157.728s completes actual engineer commit,
owned kill-9 and distinct normal recovery/cabin walk, then E takes co-pilot
passenger instead of helm. Root aborts/reaps rather than waits the remaining cap;
inputs/all child cleanup pass, diagnostics0. Actual coldPID2230282 frames613/614
have top-level Jovian boarding candidate true and co-pilot station candidate;
no boarding discovery/reach defect is established. Existing solo cockpit aim
precedence excludes Jovian while the station chair wins Interact.
Independent causal/cumulative review permits ONE correction: include Jovian in
that existing guarded precedence; add actual-candidate/no-station pre-E and
immediate wrong-crew-claim driver assertions. Extend ownership only to existing
`scripts/game/game_flow.gd` and `tests/jovian_solo_engineer_route_test.gd`.
Before the sole retry, a focused captured-geometry regression must distinguish
old co-pilot selection from corrected cockpit selection, with real chair aim
still selecting its chair. No reach/discovery/path/threshold/time/policy change.
The first failure/source/bundle/export bytes remain retained. Any further
unexpected check or full-route failure parks this attempt under the same original
17:01:14UTC/90min/hard18:31:14; no automatic third trial or fresh clock.

Existing CREW-RECOVERY-ORDINARY, selected2026-10-26 on maina1bc1d3de.
This delivers the missing executable ordinary-input release capability, not a new
recovery policy or validator. One bounded implementation owns only existing
`tools/release/run_native_sortie.py`, `tools/release/test_native_sortie.py`,
`scripts/diagnostics/native_sortie_observer.gd`, `scripts/game/startup_loader.gd`
and `tests/startup_cli_privacy_test.gd`. The observer stays read-only. Root owns
plan/history, private exports/actual validation and integration/cleanup; one
independent reviewer checks lifecycle/data/route constraints.

**Result and steps.** Add existing-driver route `crew-recovery` for exactly
Jovian `jovian_provisional`, engineer `passenger_port_01`, home
`jovian_freight_berth`. Normal Boot/Begin Shift starts at the authored hub. Use
LifeTowPilot.GANTRY_GOALS through freight_return, then world x=-42 aligned to
the actual cargo-access marker z; walk to the actual access/deck markers (ship
local(-10.05,-1.08,3.2) and(-5.05,.64,3.2)), across the physical cargo aisle via
local(0,.60,3.2), then(0,.60,-5.25) and engineer entry(-1.35,.60,-5.25).
No pilot-board shortcut or teleport. Face the actual engineer anchor and press/
release OS E; require completed actual seating/current role/authority/occupant,
controls and transition settled. Independently read actual primary and predecessor
around seating; require committed crew preference exactly:
`{location:mudds_home_berth, mode:crew, craft_id:jovian_provisional, berth_id:jovian_freight_berth}`.
Protected activity/reward/settings/other siblings remain exact; session diagnostics
are accounted for separately. The existing context commit changes no entitlement.

Release synthetic inputs, SIGKILL that exact owned Popen and reap actual-9 within
existing15s; preserve committed bytes through the interruption. Launch the same
embedded ELF/args/private profile in a distinct process. Normal observed OS menu
input selects Resume and Begin Shift, never an emitted signal or production-method
call. Require session/startup1→2, unclean_start_count1 and exactly one actual
crash_detected event, and the supported awake/unseated
home cabin in phase IN_FLIGHT_CABIN/actual HUD mode aboard (GameFlow requests
cabin; GameHUD resolves it to MODE_ABOARD), registered floor/frame/hatch
and fresh ownership; no old engineer, seat, pilot or transient authority restored.
The saved preference remains mode crew until a later ordinary context commit.
Walk to local(0,.60,-5.25), then
(0,.60,-6.70), face helm and press/release OS E; require actual pilot anchor/
authority, actual current local input command throttle>0, flight demand and engine
ONLINE in the same current craft. A key tap or intended throttle alone cannot pass.
Finish normal HUD Quit/actual OS0, final
crash clean/safe-start clean_shutdown, released inputs and all children reaped.

**Proof and limits.** Execute one exact clean-commit embedded Linux export with
`python3 tools/release/run_native_sortie.py GAME.x86_64 --route crew-recovery --output NEW_DIRECTORY`.
Whole-operation original300s/independent330s spans both games, kill/reap/restart;
it does not reset. Expected exits are first-9 and second normal UI0, with zero
engine/script diagnostics in both legs. Reuse existing ordinary walking .30m
arrival/braking and supported completed-motion rules; final engineer/helm walking
anchors retain the existing .12m/four-settled-frame criterion. Interaction still
requires the real production reach/claim, not only proximity. Authored input/timing/physics/
collision/motion durations remain unchanged. Private authenticated Xvfb with
explicit x11/Dummy/dummy renderer only; no active desktop/native GPU/audio claim.
Focused existing Python and loader/privacy checks protect selectors, input edges,
real-file preservation and actual kill/distinct restart. Paired clean exports,
strict exit0/one-readiness-marker startup and actual payload comparison precede
the sole complete native attempt. No staged Convoy, scene placement, time override,
new policy, injected entitlement or production-action call supplies acceptance.
Preserving zero/absent progress proves no mutation; it does not prove earned-debt
recovery. Installed/final packages and other crew instances remain open.

**Stop and closure.** Conservative original17:01:14UTC/90min includes the one
source binding pass, implementation/checks/exports/run/review/archive/integration/
push and branch/worktree/process/scratch cleanup; hard18:31:14. First unexpected
failure stops and retains raw state/source before any causal/cumulative-priority
review. No automatic retry, successor definition or clock reset. Integrate only
accepted source; preserve any unaccepted unique source in a verified archive
before exact owned cleanup. Publish a checkpoint only if its working capability
passes; no unaccepted observer candidate enters main for branch housekeeping.

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

### Busy exterior exit interruption — frozen 2026-10-27

Selected DOCK-EXIT-RECOVERY-CUT member: executable release-driver support for
accepted and refused busy-exit publication. This does not close installed/final
or complete ordinary journey acceptance. Production recovery policy is settled;
no game authority or save schema change is selected.

- Start: clean source after this card; owned branch/worktree under
  `/srv/mudds-work/busy-exit-recovery-20261027/`; fresh independent private
  HOME/XDG profiles per outcome; pinned standard4.7.1 engine
  `/tmp/mudds-tools/godot-4.7.1/godot`. Headless/Dummy only.
- Ownership: implementation only `scripts/game/startup_loader.gd`,
  `scripts/diagnostics/in_world_interruption_probe.gd`,
  `tools/release/run_package_probes.sh`, `tests/startup_cli_privacy_test.gd`.
  Root owns this card, ROADMAP.md, delivery history and integration/cleanup.
- Result: existing runner accepts `PACKAGE_PROBE_RECOVERY_CONTEXT=exit` and
  `exit_refused` only with existing Convoy interruption/headless/Dummy safety.
  Existing `docking` and ordinary startup remain unchanged.
- Setup: reuse disclosed existing escort/approach fixture: actual Bulwark pilot,
  first real Convoy payment1, second Convoy failed by real home landing; exact
  occupied home/OFFLINE/pilot preference before exit. No injected recovery record.
- Cut: invoke existing `_try_exit_ship`; synchronously observe actual busy
  DISEMBARKING before its canopy await completes, then pause. Accepted store
  changes only `solo_safe_recovery` to exactly `{mode:unavailable}` with one
  generation advance, prior primary becomes backup. Refused sibling first creates
  an owned empty actual `.tmp` directory; real commit refuses, exact primary/backup
  bytes/generation/pilot preference remain, retry is scheduled. Remove the owned
  blocker while paused before READY; no subsequent orderly save before kill.
- Protect: exact pre-exit Convoy terminal record, reward ledger/credit1, debt,
  settings and all unrelated payload fields remain unchanged at publication and
  cold continuation. Runtime session diagnostics/crash markers use only their
  existing lifecycle deltas; enumerate those in runner rather than exempt data.
- Restart: runner reads real disk independently, kills/reaps its actual ready game
  as-9, preserves paused file bytes, starts distinct normal Boot. Accepted case
  Resume/Begin Shift yields supported controllable station fallback, no old seat/
  hatch/transition; ordinary held forward24physics ticks moves>0.1m on real floor.
  Refused case restores a fresh Bulwark home pilot/seat/hatch, accepts ordinary
  forward throttle>0/ONLINE after two physics frames. Preserve paid1/failed second
  run throughout; no new reward needed to prove preservation. Close both existing
  clean markers and actual OS0 through existing release-driver shutdown path.
- Proof: existing privacy suite admits only safe selectors and rejects conflicting
  modes; smallest existing runner checks plus source accepted/refused cut pairs.
  From clean candidate, one private Linux export; strict actual archive startup
  exit0/exactone STARTUP_MENU_READY_OK, then both pairs using embedded executable
  (`run_package_probes.sh --in-world-interruption --native-export`, activity Convoy,
  exact PACKAGE_PATH and new context). No external-script override establishes
  package support. Each pair uses fresh result/profile paths and actual-byte hashes.
- Limits: existing300s independently for arm and restart; original landing/walk/
  boarding frame limits retained, no rendered automation. Independent supervisor
  kills/reaps owned children; release any held input on all terminal paths.
- Budget: selection charged03:00UTC2026-10-27, estimate75minutes including checks,
  export/review/integration/cleanup, hard04:30UTC; reserve final15minutes closure.
  Source ready03:40/export launch by04:00. First unexpected failure ends the task;
  no automatic correction/retry or cap increase. Any proposed continuation needs
  demonstrated cause and independent cumulative-priority review on this same clock.
- Closure: integrate/push only accepted capability; archive unique rejected source,
  raw results and remove owned branch/worktree/process/scratch. No duplicate public
  gameplay checkpoint for diagnostic-only release support; actual private export
  proves executable support. Native/device/human/ordinary/installed/final gates open.

**First source stop, before busy exit.** Candidateb9d103645 import22.164s/privacy
2.671s pass; one accepted-source attempt stops66.108s after real pilot/payment1/
thrust/home landing, before PREPARED/cut. Runner kills/reaps arm; source/cache
unchanged. Combined pre-cut assertion contains two source-proven false checks:
fresh ARM compares actual threat record with cold-only empty restored cache;
completed landing has overwritten reason to returned_to_shipyard, so expecting
landing_requested is impossible. Other conjunct values were not recorded.

**One causal continuation approved before correction,03:15UTC.** Independent
high-risk review confirms both causes and chooses this bounded correction over
switching at15minutes cumulative/75remaining on original03:00→04:30 clock. Only
busy-exit ARM uses canonical live-threat comparison; RESUME retains cold cache;
completed-home expects returned_to_shipyard. No runtime policy change, predicate
relaxation, new instrumentation layer or fresh budget. Corrected source requires
review, then one accepted-source rerun; if it passes continue first refused/source
and private export/package pairs. Next unexpected failure is terminal PARK/no
second correction. Preserve first source failure/clean-source pin/raw results.

**Accepted release capability —24774c04.** Existing privacy/import pass; accepted
and refused source pairs99.442s/101.923s and actual embedded Linux pairs76.991s/
78.713s pass at original300s limits per process. Actual archive startup exit0,
exactone STARTUP_MENU_READY_OK/no diagnostics; all four raw results independently
reviewed. Full-payload/file/generation/backup/kill/restart/control/clean checks
pass. Integration57c9b3eb0 is pushed; owned task branch/worktree/process/profile/
scratch cleanup complete27.803minutes from original03:00UTC, plus notes/push.
Initial66.108s failed candidate and single approved correction retained, no
budget reset. Reuse these exact source/package results; whole installed/full
ordinary/native/final scope remains open in the existing row.
[Package identities, archive and actual validation](history/ROADMAP_DELIVERIES.md#busy-exterior-exit-release-interruption-support-accepted-20261027).

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

<a id="world-abandonment-and-next-visit-binding"></a>
### World abandonment and next-visit binding

WORLD-ABANDON-DEFINE / original parents1,14. One bounded source-definition
pass on integrated sourceef95885a8; no engine, probe, capture or qualification ran.
This supplies finite existing behaviors, not new child IDs or gameplay passes.
All337 canonical identities and the original world/recovery promises remain.

**Aurora and Rime each have these four distinct existing boundaries.** Both use
[PlanetarySurfaceVisitExpedition](../scripts/game/planetary_surface_visit_expedition.gd)
through their existing Aurora/Rime wrappers. An internal cancellation API is not
proof of an ordinary surface-abandon control.

| Boundary and actual caller | Observable endpoint fixed by the existing owner | Retained source/test anchor and exact remaining proof |
| --- | --- | --- |
| ACTIVE optional survey; ordinary Interact at the Aurora trail sign or Rime orange beacon | Survey becomes FAILED with player_abandoned; same player/craft/surface lease and movement remain usable, no reward for the aborted survey; restart at that marker or reboard/return remains available. Rime heater resets to full. | Survey interact/abandon owners; existing aurora_visit_loop_test and rime_visit_loop_test component cases. Their staged scope is retained; bind ordinary candidate/input/route before qualification. |
| Outbound/corridor; enabled Destination Board ABANDON APPROACH | request→cancel releases autopilot at the same live seated pilot/craft pose and velocity; direct flight control remains, lane/visit retire and later admission remains possible; no survey entitlement is created. | Expedition board_action_text/request/cancel and aurora_expedition_production_test outbound case. Do not replace it with surface rescue or auto re-engagement. Remaining command/profile/original phase limits must be fixed before execution. |
| Landed/surface; reboard, then enabled RETURN TO MUDDS | Ordinary request enters _begin_return; pilot seat is required, followed by manual takeoff/clearance, home approach, real registered-berth docking and physical exit. No rescue placement supplies this physical return. Fresh arrival resets ACTIVE/FAILED survey; same-Main COMPLETED-unpaid remains retryable and paid rewards stay once-only. | _begin_return/_arrive_home and each survey _clear_previous_visit_run; bind to the existing WORLD-SOLO canonical journey. Missing ordinary/package route stays GATED, not a newly shortened abandon check. |
| Surface/disembarking/boarding lifecycle cancel() | Existing rescue clears transition/seat/reservations/surface lease, returns controllable unseated explorer and live craft to Mudds, then streamer wind-down/home touchdown/lane idle permits readmission. | Direct cancel component cases in both visit-loop tests; this is an internal lifecycle case, not an exposed ordinary surface-abandon interaction. Tree detach saves then cancel(true), preserving interrupted restoration, and belongs to WORLD-SAVE rather than abandonment. |

Shared anchors: expedition board text/request at159/225, _begin_return1046,
_arrive_home1063, _retire_saved_visit1110, cancel1126 and _advance_retiring1215
on this source; tests aurora_expedition_production_test outbound and direct
surface cancellation, aurora_visit_loop_test and rime_visit_loop_test. These
are source locations, not new passing executions. Existing activity-content and
once-only reward contracts remain authoritative.

**Unpaid end-visit debt: runtime repair accepted, broader qualification open.**
The original source pass identified the exact cut: genuine COMPLETED survey,
refused reward write but successful visit save, accepted/refused end-visit
retirement, then fresh store/Main and next surface retry. Sourcefc2b33f reproduces
exactly eight loss failures across Aurora/Rime; there is no separate pending
survey entitlement in the paid-receipt reward store. The saved active visit was
the only durable unpaid completion when no passive archive existed.
Checkpointf51e02a repairs only _retire_saved_visit: validate primary authority,
observed generation/receipt and paid state, then move unpaid completion to the
existing passive declined owner with one atomic commit. Refusal/conflict/invalid
paid state preserves records; incomplete/paid normal retirement and universal
resume retirement are unchanged. The existing real-file lifecycle fixture now
proves both worlds' passive debt at Mudds, disclosed staged current arrival and
legitimate final-anchor payment once; the original quit/resume suite also passes.
[Actual proof and limits](history/ROADMAP_DELIVERIES.md#surface-survey-unpaid-retirement-accepted-20261026).
This is fresh Main/store in one OS process with disclosed observation/arrival
staging, not ordinary outbound/return or independent OS kill/restart proof.
Those original command/profile/cut/limits remain Codex-owned execution gaps;
no new policy approval or completed-world claim is inferred. Ember cases below
are not covered by this Aurora/Rime repair.

**Ember: reuse and durable retirement after the retained source ABANDON.**

**Pending-abandon real-file OS cut accepted:** Gameb30a9ea93/Driver7337dc543
ships the existing arm/resume workflow's `ember-abandon` selector. Actual exported
ELF195.384s: first relay save→public pending abandon→independent backup/primary
proof→planned owned SIGKILL/reap-9→distinct Boot safe yard/new boarding/fresh
survey0, zero payment and exact passive/foreign data. [Actual proof](history/ROADMAP_DELIVERIES.md#ember-pending-abandon-native-cold-restart-accepted-20261026).
This closes that exact pending-return interruption, with disclosed initial flight
placement; it does not close the physical home/exit/reuse or completed-debt cuts
below. Ordinary application-Quit capture is now accepted on8e74c40:
[actual production Quit and exported real-file proof](history/ROADMAP_DELIVERIES.md#ember-ordinary-quit-checkpoint-capture-accepted-20261026).
A fresh on-foot visit writes its exact index0 checkpoint before teardown; the old
index1 remains passive. Arbitrary Main removal/streaming, other untested phases
and completed-debt OS restart remain open.


**Runtime component accepted in checkpoint34f60da:** explicit solo abandonment
now declines the exact observed saved checkpoint atomically after read-only
owner/cancellation preflight. Incomplete progress cannot reappear through fresh
admission; same-instance approach cleanup retires the staged composition.
Completed debt, failed writes and rejected owners retain their contracts.
[Actual source/fixture/manual-return/package proof](history/ROADMAP_DELIVERIES.md#ember-explicit-abandon-checkpoint-accepted-20261026).
This is MemoryFilesystem/controlled Host plus disclosed staged-return integration,
not the full physical home/exit/reuse or real-file OS-restart cases below. Their
original scope and missing execution bindings remain open.

GameFlow.abandon_ember_surface_journey forwards to PlanetaryJourneyCoordinator;
EmberSurfaceLoopHost.abandon waits while on foot/landed, lifting the survey gate
so the same player can physically reboard. Its own takeoff must submit
surface-clear before one commit releases leases and returns pilot command.
Coordinator completion cancels active survey work and arms the existing Mudds
return. Aborted work earns no survey reward. Preserve sourcee85157b4d's exact31
physical return proof once; it uses MemoryFilesystem, fixture admission/timing
shortcuts and original7200s source cap, not ordinary packaged durability/reuse.

| Uncovered original boundary | Literal endpoint and stop boundary |
| --- | --- |
| Same-Main next visit after physical abandon/home/exit | Same retained host/player/craft can accept a new expedition after the first one's real surface-clear, home dock and supported exit. New visit/session/command generations replace retired ones; no old lease, abandoned route or reward is replayed. Host _rebuild_for_next_visit and existing ember_surface_loop_host_test air/surface cases plus ember_loop_soak_evidence are source/staged anchors. The soak uses MemoryFilesystem and disclosed orbital/corridor placement; it is not ordinary package proof. Missing supported OS-input second-visit command and its original complete-route limits remain GATED; do not replay accepted source ABANDON unchanged. |
| Saved active checkpoint→abandon→home/exit→cold next visit | Record a genuine successful save_interrupted_ember_journey document, abandon the incomplete survey through the physical pending/reboard/surface-clear return, then restart using the same actual files and admit a fresh visit. Prove retired/abandoned progress cannot re-open work or earn a reward, while unrelated data and separately earned unpaid debt remain protected and eventual valid payment stays once-only. Read actual records through the existing persistence owners; in-memory host reset is insufficient. Supported ordinary/package input and exact real-file cut/restart route/limits are still missing, assigned to Codex. Do not substitute the separately accepted first-relay safe-yard recovery cut, which has no intervening abandonment. |

Ember anchors: GameFlow begin/save/abandon seams, coordinator
abandon_ember_surface_journey/_complete_ember_surface_abandon, host
_abandon_commit_ready/_commit_abandon/_rebuild_for_next_visit,
EmberSurfaceLoopProductionBinding abort_planetary_relay_survey and
abandon_planetary_surface, and the existing Ember persistence tests.
No phase/craft/device cross product or numeric deadline is invented here.
Stop this definition pass here. A next assignment must choose one literal
uncovered executable boundary above and fix its missing command/fixture/limits;
no repeat source inventory is selected. WORLD-ABANDON, WORLD-SOLO, WORLD-SAVE and
EMBER-PACKAGE-ABANDON remain open in their original complete scopes.

### Ordinary packaged Ember outbound driver — frozen 2026-10-27

Selected SOLO-EMBER member: implement the missing ordinary packaged outbound
input command, not another content survey. Full SOLO still requires relay,
lava-tube/wreck errands, durable reward, reboard/ascent/home/exit/reuse; none is
waived or closed by this capability. Existing source outbound/manual/cancel/
re-entry checks retain their own scope and are not rerun unchanged.

- Result: existing `run_native_sortie.py BINARY --output NEW_DIR --route
  ember-outbound` drives one normal Arrow departure and actual Ember destination
  admission, canonical physical outward flight, caldera landing and surface exit,
  then normal HUD Quit/OS0. No direct GameFlow calls or pose/lease/progress injection.
- Start: clean candidate in owned worktree under
  `/srv/mudds-work/ember-outbound-20261027/`, fresh private HOME/XDG profile;
  standard pinned4.7.1 engine/template, actual embedded Linux export. Existing
  owned Xvfb/x11/Dummy/dummy-renderer native input workflow; no user desktop/audio.
- Ownership: `tools/release/run_native_sortie.py`, existing
  `tools/release/test_native_sortie.py`,
  `scripts/diagnostics/native_sortie_observer.gd`,
  `scripts/game/startup_loader.gd`, `tests/startup_cli_privacy_test.gd` only.
  Root owns roadmap/history/integration/build/cleanup. No default runtime policy,
  graphics quality, authored handling/speed/physics or historical claim change.
- Actions: normal Begin Shift; on-foot Activity Board selects idle Convoy before
  departure, avoiding a live default race; supported Arrow access/boarding uses
  the accepted Arrow ordinary path, current reservation-backed pilot and original
  walk/board/lift limits. Neutral seated admission and actual W thrust clear home.
  Pause→DESTINATION BOARD→actual `PlanetaryDestinationAction_ember_moon` by native
  click; consume the production briefing if shown, close pause, follow production
  cruise/approach controls and actual caldera landing/exit. Use real controls only.
- Frozen geometry: craft `arrow_provisional`; canonical station datum(0,0,0),
  Ember body(0,0,-8000000)m, body-local orbital navigation(0,130000,0)m,
  airless radius120000m; actual region `ember_caldera`, authored `caldera_pad`.
  Existing registered stream/frame/generation and berth owners resolve live poses;
  no staged orbital/corridor placement or mutable substitute sampler.
- PASS: same current Arrow/Player/seat source through flight; default production
  sampler,60Hz/time_scale1/authored rates, >7800000m physical transit and >700
  committed origin shifts, continuity reconciled only with actual rebase receipts.
  Real actual matching caldera berth occupied by that Arrow, strict landing
  completes, automatic OFFLINE, then the production coordinator's automatic
  disembark request executes the actual host/Player transition. Driver stays
  neutral and sends no competing E after landing. Same awake unseated
  control-enabled Player on genuine surface support, no
  boarding/cabin/crew claim. Observe actual main/host/loaded world identities.
  No survey/errand reward or checkpoint completion is manufactured; this endpoint
  precedes the survey. Normal pause HUD Quit yields actual OS0 and existing clean
  markers. Ordinary quit may save only its actual production checkpoint through
  the existing owner; no save schema or additional namespace entitlement is added.
- Observer: extend existing read-only mode/fields only as needed for real visible
  button geometry, cruise/landing/current actors/origin receipts. Preserve old
  `ember` and all existing modes; no observer-driven input, setters, leases,
  transforms, pause changes, saves/rewards or physics queries while paused.
- Proof: focused existing Python driver tests include new control/identity/
  rebase/route-deadline failure cases; existing startup privacy safely gates actual
  x11/Dummy/private-input selectors. Fresh import; clean private Linux export,
  strict actual archive startup exit0/exactone STARTUP_MENU_READY_OK, then ONE
  ordinary native outbound command with full raw controls/observations and
  independent source review/raw review. Old Arrow/other route caps stay300s.
- Limits: inherit existing1800s outbound cap only for ember-outbound, independent
  outer1860s abort/owned process reap; unchanged per-action and original landing
  limits. No global CAP increase, fixed-fps/time-scale/speed change, shortened
  distance, extra placement, bypassed collision/support, direct activity calls
  or accepted source-journey substitution. This is not the unsupported old
  external-script9be5c83 attempt or a renamed parked native smoke.
- Dependencies: existing Arrow admission and authored canonical physical Ember
  runtime are accepted in their cited scopes; new ordinary input driver is the
  missing implementation. No new product/design owner choice is required.
- Budget: charged from03:30UTC2026-10-27, estimate80minutes including focused
  checks/export/one flight/integration/cleanup, hard05:00UTC. Source ready04:05,
  native launch by04:15, reserve final15minutes for closure; original1800s journey
  allowance is retained. First unexpected failure stops; no automatic retry or
  correction. Any continuation requires demonstrated cause and independent
  cumulative-priority decision on this same clock, never a fresh task budget.
- Closure: integrate/push only accepted executable capability, archive rejected
  unique source if any, remove owned branch/worktree/process/profile/scratch.
  No duplicate public gameplay build for read-only diagnostic/input-driver work;
  actual private export proves support. Full ordinary SOLO/return/save/repeat/
  installed/native GPU/physical-device/final gates remain open.

**First verification stop and one approved continuation,03:52UTC.** First Python
run on857e20e91 stops16.008s: one of309 tests fails because the new selector was
prepended to the CLI choices, violating the existing literal Zenith-first prefix.
The next dispatch tuple already matches; no second failure is inferred. No Godot,
export or flight ran. Independent cumulative-priority GO before correction permits
one additive ordering repair: append the new selector/help entry, preserve every
existing prefix/default/cap/dispatch behavior and keep tests unchanged. About22min
is already charged on original03:30→05:00 clock; source04:05/nativebefore04:14
cutoffs remain. Review corrected source, then one Python rerun; only if PASS run
first remaining focused/export/startup/native stages. Next unexpected failure
is terminal PARK/no second correction or fresh budget. Original raw failure stays.

**Definition corrected before any execution,03:41UTC.** Source/independent review
establishes that coordinator LANDED+OFFLINE queues disembark automatically; host
requires exact occupied landing/seated/hatch state then runs actual Player exit.
The earlier one-E clause was a planning error, not an original gameplay promise.
Accepted source waits for this automatic SURFACE_OUTBOUND transition. Only that
clause is corrected; all other endpoints/controls/continuity/caps remain. No
runtime policy change, extra input or failed-test acceptance relaxation.

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
| HAULER-CARGO-DELIVERY | Current pilot loads through real terminal, physically departs/clears gate, lands/exits/walks back and commits exactly one source→destination transfer/reward; repeat preserves quantities/receipts | DONE scoped99f2717ee: full normal-menu/18 supported station goals/actual Hauler boarding/departure/strict Cinder contact/normal Select+Start/load/gate/redock/10-point terminal walk/one conserved crate+payment/real duplicate refusal/reverse walk/reboard/strict home/OFFLINE physical exit/1.797m supported settled apron walk/normal UI actualOS0 in193.312s under original300/360/cargo120. Five actual-file captures protect all pretransfer siblings and exact paid terminal/ledger through home; independent source/raw GO, diagnostics0. Earlier failures/fixture correction/cumulative budget retained; source integrated/pushed and owned cleanup complete. Cold inventory/repeats/native/full craft/final stay open. [Full proof and cleanup](history/ROADMAP_DELIVERIES.md#hauler-supply-first-play-accepted-20261025). |

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

### Bomber seat-retake refill — selected2026-10-21

BOMBER-REARM-POLICY / parents10,11,31. Approved refill4 whenever the pilot
retakes the seat; this does not resolve additional crew roles or destruction/
recovery entitlements. No source defect established from the existing clear/
detach/new-generation path.

Frozen ordinary-input route: normal Begin Shift, existing Central/Aft stair
walking prefix and six-point port Bomber boarding path, actual E boarding;
initial active generation ammo4. Four distinct OS mouse FIRE press/release edges,
waiting production cooldown0 and actual accepted record after each; ammo3/2/1/0
in the same generation. After cooldown, fifth edge must produce actual
ammunition_exhausted, still0/four records. Neutral input until actual OFFLINE at
same exact occupied parked berth, actual E/canopy exit and supported on-foot
control. Require inactive authority/loop, zero ammunition and cleared projectile/
request state. Physically walk outward until real reboard suppression clears,
return to live hatch candidate and E reboard. Before any FIRE, same hull/player/
Main/berth/component identities, strictly newer generation, exactly4 rounds,
zero cooldown and no inherited records; fresh first release leaves3. Finish
neutral OFFLINE and actual supported exterior exit. Parked FIRE is ordinary
supported control; this is seat-policy acceptance, not flight/combat acceptance.

Existing Python driver gains bomber-rearm route mapped to existing sandbox game
selector. Only driver, existing Python tests and passive observer are assigned;
no gameplay owner edit. Observer adds a fresh narrow bomber snapshot outside
inactive-fleet detail cache: actual identities/authority/loop/controls/support/
reboard suppression reads only. Validate all raw samples, detached receipts;
no input provider, fixture, teleport, state reset, recovery or authority calls.
Existing routes and global300s cap unchanged; outer330s abort/release/reap.
One implementer, one independent reviewer; root owns clean-source local checks,
fresh private Linux qualification export, strict menu startup exit0/exact marker,
and one silent owned-Xvfb actual route. First failure stops; no retries or weakened
route/caps. No public duplicate checkpoint absent gameplay/graphics change.
Native hardware/Windows/human/full craft/roles/recovery gates remain open.

**Entitlement completed4a0d82bff:** original ordinary route66.232s PASS; four
records4→0, postcooldown exhausted refusal, supported exit/inactive empty loop,
24.67m outward suppression-clear walk, same physical seat generation2 exactly4,
fresh accepted release/projectile leaves3 and final supported OFFLINE exit.
Six FIRE and five E presses/releases,122 focused tests, observer parse/privacy,
private export/strict startup and independent855-raw-sample review pass. All
six owners terminal,19 sampled identities absent;70 scratch entries verified
archived/removed. Private package archived outside builds, loose ELF removed.
**Concrete limitation:** fresh generation2 release presentation returns
invalid_release_record despite successful authority/projectile. Do not call
presentation/fullcraft complete; next precise repair below. Publicc2c72a2 unchanged.

### Bomber reboard payload presentation — completed2026-10-21

**DONE255f8df2b/checkpoint255f8df:** successful new generation resets/reactivates
presentation; refused/stale starts preserve live effects/counters. Existing
integration25 and driver122 pass. Same ordinary route66.146s passes all original
refill assertions plus accepted release_presented on all five releases, including
after physical retake; independent854-sample review GO. Paired packages/three
strict startups/actual1527-entry payload and exact archive checks pass. EXE/ZIP/
notes in builds/windows. All nine owners terminal,28 sampled identities absent;
120 scratch entries verified archived/removed. Native/rendered/human/fullcraft
limits retained. Prior defect and selection below are historical, now resolved.

BOMBER-REBOARD-PRESENTATION, parents10/11. Actual qualified refill run4a0d82bff
retains accepted gen2 payload release/projectile but nested presentation refusal
invalid_release_record; all gen1 release presentations accepted. Production
`detach_payload_authority` detaches pooled presentation; successful
`begin_payload_generation` syncs audio without reactivating presentation, whereas
explicit reuse resets it. Repair only successful new-generation presentation
reactivation; stale/refused begin must preserve active visuals/records. Keep
finite ammo/generation/cooldown/admission and owner seat entitlement unchanged.

One implementer owns Bomber runtime, smallest existing integration regression,
and native driver/tests adding nested accepted-presentation release checks.
Independent reviewer; root owns clean candidate checks, fresh Windows/Linux
checkpoint exports with strict menu startups, same full ordinary bomber-rearm
route at original300/330s caps, integration and cleanup. No injected gameplay
fixtures in actual acceptance, no render/native/human/fullcraft claim; first
failure stops for causal review. No new validator family or broad effects audit.

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

### Torrent hero cell — full18 capture contract

**Later conditional warm-cache preparation: no second rendering invocation.**
The owned cold-run Mesa cache exists as102files/5400444bytes. Independent review
allowed a byte-exact copy of only that complete subtree into fresh private user
cache, exact same2f333b0e4/engine/ICD/library/art/quality/300s/18frames, with a
reviewed18:30UTC launch cutoff to reserve inspection/closure under original
18:46:07hardstop. Fresh import passes20.944s; prep completes too late, so the
wrapper cutoff asserts BEFORE rendererPopen. `game_reaped=false` means no game
was created, not a surviving process. No cache-effect result or causal shader
claim. Final priority review upholdsPARK/no new window; all six prep identities
absent. [Cache metadata, exact status and archive](history/ROADMAP_DELIVERIES.md#hero-warm-cache-preparation-cutoff-20261026).
The following original capture failure remains the only actual rendered attempt.

**PARKED at the original cap,2026-10-26.** The sole unchanged capture exits124
at300s (wrapper301.322925s/guard302.135270s),0/18PNG,0successmarkers and no
published manifests. Last checkpoint is pilot instantiation after world/central
berth/Torrent; subsequent transform/attachment/lifecycle/frame+physics/control/
source-component preparation is unlocalized. No later visual gate or inspection
completed. Source/index/tree/cache and dependency pins remain unchanged, nine
owned process identities are absent. [Actual records/cleanup](history/ROADMAP_DELIVERIES.md#torrent-hero-cell-original-cap-timeout-20261026).
Registry source/image/human fields stay pending unchanged. The selected contract
below is historical, not authorization to retry. Reopen only a supported causal
correction/environment change with independent cumulative-priority review of this
same retained outcome/cost, original18frames/2560×1440/Forward+quality/300s.
No new engine build, probe, patch, larger cap, lower quality, shader-cause
assertion, reflection-cleanup qualification or substitute capture is selected.

Existing capture-hero-cell, selected2026-10-26 on mainaecb384f2. This is ONE
source/rendered-output qualification, not a new art obligation, validator or
runtime implementation. Declare current source/art stable for this capture; all
captured source, authored art and imported cache must be frozen before/after.
No source change is authorized by a speculative finding. Root owns execution,
output/image inspection, existing registry/docs handoff and owned cleanup; one
recipe mapper and one independent reviewer. Original ID/parents/count remain.

**Result and exact membership.** The unchanged `tests/capture_hero_cell.gd`
CAPTURE_FILES is the complete ordered18PNG roster, all2560×1440, with its existing
source/evidence manifests and every numeric/semantic gate unchanged. This covers
Torrent/world/pilot berth, hull/profile/dorsal/clamps/access/canopy/seat, near/far
LOD, fixed aft OFFLINE/ONLINE, powered chase25m/50m, neutral UV/material crop and
fixed cockpit OFFLINE/ONLINE/critical. Historical12frames do not substitute.
Use the original [complete filename/command contract](GRAPHICAL_HARNESS_INVENTORY.md#current-required-capture-commands).

**Start/environment.** One clean imported isolated checkout at its exact plan
commit; same tracked source/art/registry and complete cache before/after. Pinned
retained editor `/srv/mudds-work/toolchains/godot-4.7.1-reflection-atlas-7b46e60/godot`,
SHA2567b46e60fa1d4ddc979d35698a96d6cb16f79d03019ee5c84aaf24c98434c5f7d,
177083960bytes/version4.7.1.stable.mudds_reflection_atlas_a2917e5_guarded.a13da4feb.
Its build is accepted; its intended reflection cleanup is NOT yet qualified.
No new engine build/patch/global install/template change. Pin Vulkan ICD
`/usr/share/vulkan/icd.d/lvp_icd.json`,SHA256
9a6a0d616f3f2efc2d227f89653047e5330ff634b0519ffbf1b2c60dc1c0e0e7,
and library `/lib/x86_64-linux-gnu/libvulkan_lvp.so` (resolved
`/usr/lib/x86_64-linux-gnu/libvulkan_lvp.so`),SHA256
0004262f4dc95585492d55925face67a79a7c869ad8760b42ae01bd0bdb807a2.
Record actual OS/kernel/CPU/memory, log-reported adapter/version and invocation.
Explicit llvmpipe replaces the docs' prepared DZN context, not Forward+ quality;
only that recorded environment is qualified. Native GPU/performance stays NOT_RUN.

**Steps/proof.** One silent headless/Dummy import into owned cache/profile, then
one authenticated private Xvfb2560×1440 session, private user data, explicitx11,
Dummy, Forward+/Vulkan, TAA/2×MSAA/fulloriginal camera/waits. Clear inherited
parse-only/staging-only/wayfinding capture flags. Fresh canonical output is
`/srv/mudds-work/hero-cell-capture-20261026/images`, outside checkout/old outputs.
Exact invocation: `timeout 300s GODOT --path CHECKOUT --display-driver x11 --audio-driver Dummy --rendering-method forward_plus --rendering-driver vulkan --resolution 2560x1440 --script res://tests/capture_hero_cell.gd`,
with `MUDDS_CAPTURE_OUTPUT_DIR` bound to that fresh absolute output. Independent
supervision owns abort/reap and display/profile cleanup; no active desktop,
synthetic global focus or audible output. Require actual exit0/full
HERO_CELL_CAPTURE_OK18marker, no unexpected diagnostics through shutdown, complete
18image sizes/SHA/manifests and source/cache/registry identity. A sentinel alone,
parse/staging check or historical inspection is insufficient.

Inspect ALL18 originals. In particular08helmet/≥60%crimson-seat silhouette;
07continuous canopy/glass/frame/hinge without clipping;11/12four nested engine
layers per side;15UV/material continuity and correct concave/convex relief;
02/04/06/08/15motif handedness;16–18continuous20×12degree exterior corridor.
Record inspected no-finding or an actual named defect; do not invent art changes.
Only accepted output may be copied to a unique repo artifacts directory and
advance existing registry source/image fields; human review remains NOT_RUN.
No schema/validator version, automatic recapture or duplicate playable build.

**Stop/closure.** Original18:01:07UTC/45min/hard18:46:07 includes recipe/import/
ONE300s capture/inspection/metadata/archive/push/process/worktree/scratch cleanup.
First unexpected failure stops and retains source/raw/output before any causal
priority review. No cap/wait/quality reduction or unchanged retry. Missing shader/
hardware support is an exact environment blocker, not visual acceptance. Accepted
source-specific capture does not close final/common-candidate, whole-art/whole-
fleet, native hardware or human gates. Preserve prior capture failures for other
sets and do not run them under this selection.

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
frozen in the retained [SAVE-UNSUPPORTED real-file selection](#selected-save-unsupported-real-file-case). Existing canonical
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

### Defense launch arm — delivered2026-10-24

**Delivered9af48515a/checkpoint9af4851 — runtime rule only.** Eight accepted
production/test files match tested candidate bytes. Actual1,028 prelaunch samples
retain same arm/idle0/inactive enemies; occupied→free berth release2069 consumes
once and starts34s. Seven runtime suites/public CLI privacy, fresh paired exports,
three strict startups, actual1527-entry parity/archive audit pass. Public payload
matches1,525 candidate entries; only withheld observer/selector differ. Full route
stillFAIL100.537s/2kills/34.0167stimeout/zero reward; remaining journey not reached.
Driver147 regressions do not establish full combat. Five qualification files and
all four candidate commits preserved under archive/withheld/defense-launch-route-20261024;
not merged. New31 stages/830.339s retain6 failures;108 identities absent/454 scratch
entries archived and removed. Nine original outcomes remain unqualified.

Next independent boundary: prove an ordinary clear-fire/aim plan from actual
blocked-shot/targeting geometry before selecting another full Defense run.
Current57 shots have23 misses/13 friendly blocks/12 world blocks; the exact
blocking collider paths/shot origins were not captured. Camera/muzzle defect is
not demonstrated: production already converges muzzles onto camera-ray contacts.
No timer, damage, world collision bypass or unsupported unchanged retry. Earlier
selection below is historical; owner arming rule delivered, full PLAY-DEFENSE open.

DEFENSE-LAUNCH-ARM / PLAY-DEFENSE / parent13. User chose Deploy arms it in reply
to the explicit arm-at-Deploy/start-enemies-and34s-on-launch choice. Board holds
a runtime-only current-generation/content/weak-actor arm; host/activity remain
idle/no enemies or elapsed time while walking/boarding/engine waking. Physical
armed E cancels, Reset/board/Main retirement clear arm, coldload is unarmed with
no save schema change. Pending completion payment protects admission unchanged.
Actual live current seated pilot + not-landed craft + exact occupied berth before
release and actual authoritative lease retirement after release consume once;
failed/stale/foreign/replaced actor/content and historical departure cannot start.
Board/nearby activity presentation says ARMED and directs boarding/departure.

Host/content.start preserves original34s, waves1/2/1 and delays0/2.5/8, all four
real player kills and once-only durable reward. Restore archived0b11486e0 full
ordinary route into current driver/observer without replacing accepted routes.
Add arm/prelaunch inactive observations and exact launch start; keep authored
walk/Arrow boarding/departure, four kills/payment, strict home/dock/OFFLINE/
supported physical exit, physical Reset/next Deploy and normal UI OS exit0.
Original global300s/outer360s and all input/identity/physics gates remain.

Runtime implementer owns board/GameFlow/narrow nearby presenter/existing tests;
separate release implementer owns existing native driver/tests/passive observer/
startup selector/privacy test. Independent high lifecycle reviewer. Root owns
local checks/frozen source/cache/process supervision, fresh paired clean-source
Windows/Linux exports and strict startups (exit0/exactly one menu-ready marker),
original full route, checkpoint notes/ZIP, commit/push and owned cleanup. First
unexpected failure stops for bounded causal review; no automatic cap/route/
criteria relaxation. No new validator family, CI dispatch, active-desktop/audio
or native Windows/GPU/human/full-release qualification implied.

### Defense clear fire — selected2026-10-24

DEFENSE-CLEAR-FIRE / PLAY-DEFENSE / parent13. Original failed full journey remains
open. Source advisory PLAYER_SHIP_ORIGIN_ENVELOPE spans worldx70..110/y4..16/
z-100..-60; one candidate[80,10,-90] is inside that audited volume, not assumed
safe. Retain original16m port departure then fixed ordinary dogleg via[-71,10,-90].
Conservative rotation-invariant sphere must enclose every enabled current Arrow
root collision shape/local transform/scale plus margin; unsupported input rejects.
Initial/end overlap and both entire segments must clear exact ship collision_mask,
excluding only own hull. Recheck current segment before command; contact/stale
geometry ends attempt. No alternate route search, staged movement or boost.

Read-only observer mirrors HeroShip camera-center reticle query and actual next
muzzle convergence, production masks/exclusions/inside flags, resolves first-hit
Damageable to exact current chosen hostile/handle/source, reports actual ready
cooldown/heat/recovery. OS fire only when both first hits match and weapon ready;
retain real shot origin/direction/impact/collider identity. Resolver receipts
alone establish damage/kills; queries do not. Restore only the five withheld
release/observer/startup/privacy files fromb03a88b9c, preserving accepted routes.
No runtime actor/physics/health/weapons/content/timer changes.

One full same original journey: on-foot Deploy/Arrow board/depart, all four actual
kills/three waves, once-only real-file reward, strict home/dock/OFFLINE physical
exit, physical Reset/next Deploy availability and normal UI exit0. Original34s/
300s/360s and geometry/identity/default controls preserved.14 ideal hits at24damage,
11within-wave intervals*.38≈4.18s and10.5s lulls; estimated12–14s ordinary staging
leaves≈5–7s for target turns/delay. This supports one conditional trial only.
One high implementer owns existing driver/tests/passive observer/selector/privacy;
independent high review; root owns frozen checks, clean private Linux export,
strict startup, actual full attempt and integration/cleanup. First unexpected
failure stops, full scope remains required; no cap/criteria weakening. No hosted
CI/audio/desktop/nativeGPU/human claim. No duplicate public gameplay checkpoint
for excluded qualification-only edits; retain latest9af4851 until actual delivery.
