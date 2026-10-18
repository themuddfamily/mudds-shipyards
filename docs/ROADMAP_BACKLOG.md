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

## Coverage of the original remaining outcomes

These are **36 parent outcomes**, not 36 executable jobs. They remain open until all applicable named instances and original acceptance conditions hold. This crosswalk is the guard against losing scope during the rewrite; it is not an extra evidence system. Original wording and all ten phase specifications remain in the preserved reference.

| Parent | Original parent outcome | Active task families | Reconciliation / next named outcome |
| --- | --- | --- | --- |
| 1 | Finish final integrated-source and packaged physical abandonment acceptance | WORLD-ABANDON, WORLD-SOLO, PACKAGE-WIN, PACKAGE-LINUX | Source Ember abandonment DONE on e85157b4d; EMBER-PACKAGE-ABANDON and real-file/reuse cases remain gated. |
| 2 | Complete matching installed interruption/recovery on the accepted integrated build | RECOVERY-CONTRACT, RECOVERY-KILL, INSTALL-LINUX, FINAL-RECONCILE | RECOVERY-ONFOOT-DEFINE/PROBE/CUT DONE in the selected f90547c direct/archive scope. Pilot/cabin/crew/docking/planetary/activity source maps are defined below; explicit activity capability/policy gaps and remaining installed cuts stay open. |
| 3 | Complete canonical-distance outbound and return with ordinary remote crews for Ember, Aurora and Rime, including activities/rewards/save, late join, disconnect, pilot loss, cancellation, interruptions and repeat visits | WORLD-SHARED (each world/case), NET-CREW, RECOVERY-KILL | The 21 SHARED-* cells are named below; Aurora originals WAITING and Rime arrival PARKED. Same cells as27. |
| 4 | Record the final shipped roster and supported limits | SCOPE-DECISION, NET-CAPACITY, ORIGINAL-SPEC | SCOPE-ROSTER definition DONE; SCOPE-DESKTOP final target list and SCOPE-LIMIT WAITING; BOMBER-ROLES-DEFINE resolves one exact role promise. |
| 5 | Assign owners, dependencies and estimates to the remaining deliverables | PLAN-ASSIGN and the per-session task card | One prepared card selected in ROADMAP.md; later capability scopes/estimates still undefined. No release date. |
| 6 | Qualify and package current source | BASE-DIAG/FIX, MATRIX, PACKAGE-WIN/LINUX | Checkpoint2c73494 and HELM-EDGE-REPRO/REPAIR accepted; MATRIX-FINAL still gated. |
| 7 | Complete the normal-controls core playthrough and fix observed blockers | GUIDED, SANDBOX, SETTINGS-INPUT/RUN, LIFECYCLE, STATION-ROUTE, CRAFT-ACCEPT | LIFE-VISIBLE/REUSE source DONE; Guided earlier-package pass retained. Nine WALK-* and17 eventual CRAFT-ACCEPT-* outcomes named; Sandbox PARKED and Settings WAITING. |
| 8 | Complete control and tutorial tuning | CONTROL-FIX, INPUT-DEVICE, INPUT-REMAP | REMAP-DEFINE DONE; ONFOOT-SPRINT-TOGGLE packagedbd4e15d. CONTROL-FINDINGS definition DONE; GAMEPAD-LOOK packaged99e79c3 repairs its concrete camera gap. Remaining context definitions and INPUT-KBM/CONTROLLER real-device routes stay open. |
| 9 | Finish station layout and final presentation | HIST-CLAIM, STATION-MODULE/ROUTE/ART/LIFE | WALK-ANNEX source9af57671d DONE in its disclosed-fixture scope; other WALK-* and four station LIFE-* rows remain, VIP PARKED. STATION-RELATIONS/FINDINGS require bounded source-tied definitions. |
| 10 | Finish fleet art, character animation and role acceptance | CRAFT-ART, CRAFT-ROLE, CRAFT-ACCEPT | Nine current craft plus eight missing originals explicitly named. Each SPEC/BUILD-SPLIT/CRAFT-ACCEPT outcome remains distinct; component gaps DEFINE. |
| 11 | Complete the combat-and-recovery slice across supported craft | COMBAT-SLICE, CRAFT-ACCEPT, NET-DAMAGE | Six COMBAT-* encounters named. WEAPONS-DEFINE/DAMAGE-DEFINE resolve actual supported cells; no duplicated network-damage assignment. |
| 12 | Complete the whole-game art-direction pass | ART-FINDING, STATION-ART, CRAFT-ART, CAPTURE | ART-FINDINGS, ACCESS-* and13 named capture sets; each actual repair needs its own view/behavior proof. |
| 13 | Close the complete nearby-activity roster | ACT-HUD/WRITE/PLAY/REPEAT, TRAVEL-LIMIT, HULK | Twelve PLAY-* and four HUD-* rows named; ACT-WRITES-DEFINE maps actual durable owners below; REPEAT-DEFINE and TRAVEL-LIMIT remain. HULK revisit PARKED. |
| 14 | Qualify each implemented world's full physical round trip | WORLD-SOLO/ABANDON/SAVE/EDGE | Three SOLO-* returns named; Ember source abandonment DONE. WORLD-ABANDON/SAVE/EDGE-DEFINE resolve uncovered cases. |
| 15 | Resolve remaining planetary content and presentation gaps | WORLD-CONTENT, ART-FINDING | CONTENT-EMBER/AURORA/RIME definitions DONE in inspected authored-content scopes with no missing implementation identified. Presentation and original journey acceptance remain open; no assumed new planets/features. |
| 16 | Close remaining fleet/crew replication gaps | NET-CREW, NET-CAPACITY | Jovian boarding/departure DONE in recorded scopes. Eight named role routes, NET-SEATS-FINAL and bomber role contract remain separate. |
| 17 | Complete remote engine and landing/dock presentation | NET-POSE, NET-BUDGET | NET-POSE-DEFINE resolves craft/operation views; NET-FULL-SNAPSHOT is one aggregate original-budget check. |
| 18 | Complete supported remote helm actions and their real local-input prerequisite | NET-HELM, INPUT-DEVICE | HELM-EDGE-REPRO/REPAIR DONE on recorded source; HELM-ACTIONS-DEFINE now names six uncovered held-action cases; devices remain separate. Physical-device proof stays separate. |
| 19 | Qualify honest remote-command recovery after host simulation stalls | NET-STALL | NET-STALL retains original600-step/2s contract; no unchanged parked/stall expansion under current repair. |
| 20 | Complete remote landing, post-dock disembarkation and craft reuse | NET-LAND-DIAG, NET-DOCK | NET-JOVIAN-RETURN DONE; NET-SECOND-LAND must prove distinctness from recorded failures before diagnosis. Five bounded Jovian exit/reboard/pilot-exit/reclaim/redeparture cards now name reuse; other craft prerequisites remain. |
| 21 | Qualify fleet hull/component damage, repair, destruction and regeneration presentation across supported craft and roles | NET-DAMAGE | DAMAGE-DEFINE shares parent11 ownership and names uncovered real craft/role consequences and peer presentation. |
| 22 | Qualify the implemented convoy actor lifecycle in native gameplay | NET-ACTOR[Convoy] | CONVOY-ACTOR-DEFINE ends with actual uncovered native lifecycle cases, not another full Convoy save probe. |
| 23 | Qualify Torpedo Run authority and solo recovery | NET-ACTOR[Torpedo Run] | COMBAT-TORPEDO ordinary route and TORPEDO-AUTH-DEFINE authority/recovery cases remain distinct. |
| 24 | Finish remaining travelling-weapon and moving-crew integration | NET-ACTOR[Picket/Emberline], NET-CREW, WORLD-SHARED | PICKET-ACTOR-DEFINE/EMBERLINE-ACTOR-DEFINE plus existing ROLE-/SHARED-* cells; no duplicate moving-crew queue. |
| 25 | Qualify the production server-browser and connection flow | NET-BROWSER | Seven BROWSER-* menu outcomes named; delivered cancel/session-generation fixes retained on recorded sources. |
| 26 | Pass multiplayer and endurance acceptance | NET-ENDURANCE, NET-CAPACITY, NET-BUDGET | Boarding/departure subroutes DONE. Return is now DONE in its source scope; dedicated SERVER-BASELINE, profiles,30min endurance/full-snapshot/capacity remain open. |
| 27 | Resolve planetary travel during multiplayer explicitly | WORLD-SHARED (each world/case) | Same21 SHARED-* cells as3; no double count or staged-arrival substitute. |
| 28 | Benchmark and optimize on representative native hardware | PERF-MACHINE/ROUTE/RUN/FIX | PERF-MINIMUM/TARGET WAITING on actual hardware; PERF-ROUTES/CELLS-DEFINE precede original-length measurements. |
| 29 | Complete real-device controls and accessibility review | INPUT-DEVICE/REMAP, ACCESS-VIEW/COMFORT | Two device families/four COMFORT-* outcomes named. ACCESS-PAUSE-DEFINE and ACCESS-VIEWS-DEFINE DONE as finite rosters; actual remaining readability/remap cells and device qualification stay open. |
| 30 | Finish authored audio and the real-device mix pass | AUDIO-CONTENT/MIX | AUDIO-CONTENT-DEFINE DONE; activity lifecycle packagedf1f35d1 and surface music packaged4ff7a08; dormant Ember-feed definition remains. MIX-DEFINE/real AUDIO-MIX retain audible authorization/device gates. |
| 31 | Finish production crash and save recovery | RECOVERY-CONTRACT/FIX/KILL, ACT-WRITE, WORLD-SAVE | Seven recovery context definitions plus ACT-WRITES/WORLD-SAVE lists; SAVE-MIGRATION/CORRUPT/UNSUPPORTED named. Existing accepted cuts retained. |
| 32 | Qualify installation, updates and supported desktop platforms | PACKAGE-WIN/LINUX, INSTALL-WIN/LINUX, LINUX-BUNDLE/DESKTOP | Checkpoint packages retained; final package/NSIS, six final Linux transactions and two graphical launch paths named. Additional target scope DEFINE. |
| 33 | Complete all required graphical capture gates | CAPTURE (each required registry ID) | All13 registry IDs/143 PNGs named individually; caption-production and station-operations stalls PARKED. |
| 34 | Complete release licensing, trusted signing and distribution | RIGHTS, SIGN, DISTRIBUTE | RIGHTS-DEFINE finite family list; SIGN-FINAL WAITING on trusted credentials; DISTRIBUTE gated on acceptance/authorized destination. |
| 35 | Run final release acceptance on the exact distributed candidate | MATRIX, FINAL-RECONCILE, DISTRIBUTE | MATRIX-FINAL, FINAL-RECONCILE and DISTRIBUTE distinct. Current full matrix NOT_RUN; excluded native/human gates not silently reinstated. |
| 36 | Resolve historical reconstruction dependencies and deliver the remaining researched fleet | HIST-CLAIM, ORIGINAL-SPEC/BUILD, CRAFT-ART/ACCEPT, STATION-MODULE | Four IDENTITY-* claims, eight SPEC/BUILD-SPLIT/CRAFT-ACCEPT chains and STATION-RELATIONS; missing evidence stays external. |


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
| PLAN-NEXT | Assign the next bounded queue | 5 | DONE; this planning pass, no gameplay claim |
| GUIDED-FINAL | Final-package Guided ordinary-input sortie, original 3/3 | 7 | GATED; final package, earlier f676c50 acceptance retained |
| SANDBOX-RECOVERY | Original all-nine/54-waypoint recovery walk and reuse | 7 | PARKED; supported changed input/runtime cause required |
| SETTINGS-INPUT | Recover original runner, profile and logs | 7,8,29 | WAITING; original artifacts, no substitute Gate C |
| SETTINGS-RETURN | Original Settings/re-entry route, including gamepad return | 7,8,29 | GATED; SETTINGS-INPUT and supported correction |
| LIFE-VISIBLE | Four-cycle source phantom-geometry qualification | 7 | DONE; d7be01487, staged/headless source scope |
| LIFE-REUSE | Twelve-cycle source all-nine reuse qualification | 7 | DONE; d7be01487, staged/headless source scope |
| LIFE-PACKAGE-DEFINE | Name uncovered packaged ordinary-play lifecycle cases | 7 | DEFINE; preserve both source passes, no automatic rerun |
| CONTROL-FINDINGS | List observed unresolved control/help defects | 8 | DONE as bounded source review: advertised Right Stick LOOK has no Player/Tow consumer; GAMEPAD-LOOK packaged99e79c3 separately. Existing mixed prompts/distance help/sprint fixes retained; physical-device acceptance remains open. |
| GAMEPAD-LOOK | Continuous right-stick local camera look | 8,29 | DONE in99e79c3: Player/tractor real camera, authored delta rate/deadzone/clamps/inversion and handoff clearing; full focused checks/paired checkpoint pass. Physical controller/full ordinary route remains open. |
| UI-BOARD-FOCUS | Keyboard Activity Board transition retains valid visible focus without engine signal-disconnection errors | 8,13,29 | PARKED: key-only4.673s and changed tooltip4.954s components both NOT_REPRODUCED. Second establishes one visible embedded popup with matching root recipients and successful teardown. Original popup identity/connection-removal event unknown; no production cause/fix. Two-attempt cumulative9.627s, original investigation budget retained. No popup variant or mining retry without concrete reopening fact |

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
| WALK-FREIGHT | Freight terminals | 7,9 | UNSCHEDULED; exact production-roster route |
| WALK-FLEET | Fleet Dock berths | 7,9 | UNSCHEDULED; exact production-roster route |
| WALK-ANNEX | Fresh normal hub→Annex console→hub with one actual restock | 7,9 | DONE source9af57671d;81.387s, same supported Player, kits5→6/one Annex update/Aft unchanged, disclosed pre-walk craft/repair fixtures; no whole-station closure |
| WALK-OBSERVATION | Observation supported return | 7,9 | UNSCHEDULED; exact production-roster route |
| WALK-SALVAGE | Salvage three-component manifest | 7,9 | OPEN; definition DONE, ordered ACCESS/INSPECT/REVISIT children below; existing connector-staged memory-store scope retained |
| WALK-SALVAGE-ACCESS | Hub→three inspection positions→hub by same supported Player | 7,9 | FAILED/PARKED: original46c059cf1 61.019s plus one repair641bbdbb0 60.822s, both outbound20; unchanged fullroute/limits, no further diagnosis/fix/run selected |
| WALK-SALVAGE-INSPECT | Ordinary three components and manifest publication after actual approach | 7,9 | GATED on ACCESS; freeze exact continuation before execution |
| WALK-SALVAGE-REVISIT | Durable fresh-process physical revisit without duplicate transaction | 7,9 | GATED on INSPECT; freeze store/ordinary route before execution |
| WALK-VIP | VIP reception | 7,9 | PARKED; failed route plus repair, see working-roadmap failure summary |
| LIFE-TOW | Central tow during nearby walking/boarding | 9 | UNSCHEDULED; existing station operations owner |
| LIFE-GANTRY | Freight gantry during nearby walking/boarding | 9 | UNSCHEDULED; existing station operations owner |
| LIFE-ARM | Aft service arm during nearby walking/boarding | 9 | UNSCHEDULED; existing station operations owner |
| LIFE-PATROL | Habitat patrol during nearby walking/boarding | 9 | UNSCHEDULED; existing station operations owner |
| STATION-RELATIONS | Name unresolved historical adjacency/elevation/ladder relationships | 9,36 | DEFINE; tied source anchors or precise missing evidence |
| STATION-CENTRAL-VIEW | One current source-tied Central operational-view defect | 9,12 | GATED; usable existing view/reproduction, capture stall parked |
| STATION-FINDINGS | Finite remaining presentation/living-station findings | 9,12 | Review roster defined below for nine existing branches and four LIFE owners. Bounded service/wayfinding source review found no supported new implementation gap; actual current-view findings remain OPEN. No visual acceptance or automatic capture retry |
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
| CRAFT-GAPS-CINDER-BOMBER | Cinder Long-Range Bomber remaining authored components/roles | 10,11 | Definition DONE: pilot/payload/component map; additional crew/navigation decision and exact spent-payload rearm policy remain unresolved. Full craft/art/combat/crew/recovery OPEN. |
| HAULER-CARGO-DEFINE | Name Hauler-specific conserved cargo play | 10,13 | Bounded contract/ordered production boundaries below; existing item/destination/phases retained. One stock-policy question pending; physical access delivereda43ae4b, cargo delivery remains unaccepted. |
| BOMBER-REARM-POLICY | Define permitted spent-payload replenishment boundary | 10,11,31 | DEFINE; source disembark detaches and next session restores4. Specify seat re-entry versus actual rearm/recovery entitlement before repair/qualification; fresh-generation API tests do not settle that choice. |
| WEAPONS-DEFINE | Actual craft/role to weapon acceptance roster | 11 | Definition DONE on a0d446645; current binding map in WEAPON_DEFINITION_CONTRACT.md, finite distinctions below. No missing runtime weapon type inferred; eight originals UNKNOWN/Bomber role decision retained |
| DAMAGE-DEFINE | Uncovered craft/role component-damage/recovery cells | 11,21 | Definition DONE on82a7564cb; COMPONENT_DAMAGE_MODEL_CONTRACT.md maps five IDs/all nine craft, real role exceptions, repair/reset owners and concrete remote row gap; no gameplay pass |
| ART-FINDINGS | Finite actual UI/animation/effect/lighting/terrain/weather defects | 12,15 | DEFINE; named before/after view and affected route |
| CRAFT-ACCEPT-TORRENT | Torrent full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
| CRAFT-ACCEPT-ARROW | Arrow full solo craft loop | 7,10,11 | GATED; craft capabilities and exact full-route command |
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
| COMBAT-INTERCEPTOR | Initial interceptor pressure encounter | 11 | UNSCHEDULED; existing live encounter, actual damage and safe return |
| COMBAT-COURIER | Courier Intercept | 11 | UNSCHEDULED; existing live encounter, actual damage and safe return |
| COMBAT-WING | Paired Wing Break | 11 | UNSCHEDULED; existing live encounter, actual damage and safe return |
| COMBAT-PERIMETER | Perimeter Hold | 11 | UNSCHEDULED; existing live encounter, actual damage and safe return |
| COMBAT-BREACH | Heavy Breach | 11 | UNSCHEDULED; existing live encounter, actual damage and safe return |
| COMBAT-TORPEDO | Torpedo Run evade/intercept/destroy/fail/abort | 11,23 | UNSCHEDULED; existing live encounter, actual damage and safe return |

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
| NET-COMPONENT-POWERS | Definition unresolved: local engine/weapon/targeting HUD values include critical-hull stutter and Halyard routing. Integrity alone is insufficient; no wire/format change selected. |
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
| WEAPON-ARROW | Actual pilot precision-emitter selection/damage through the common chain | Arrow resource, HeroShip, GameFlow; migration/common combat checks |
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
HALYARD-GUNNER-DAMAGE is FAILED/PARKED after original 0b157138b (51.847s) plus
one caller repair 3a7c4b4bf (52.025s): both fail the original co-pilot seat admission,
supported Player/candidate null, before target fixture/new damage proof. The
fixed-world→craft-local aim caller change did not qualify the route; actual cause
and runtime weapon defect remain unestablished. Cumulative 103.872s review stops
further diagnosis/fix/rerun without concrete new fact/change; no third variant.
Both candidates withheld, no build; raw/source/actual attempt/selection preserved
in delivery history. Existing network Halyard failure budgets remain unchanged.

### Activities and solo-world children

First-play proof: ordinary outbound/start/activity, once-only durable reward and home return at canonical distances. The accepted one-shot HULK route is not reassigned as missing gameplay. Repeat/write/save scenarios are instantiated only after their finite uncovered lists are known.

| ID | Named outcome | Parents | State / dependency |
| --- | --- | --- | --- |
| PLAY-RACE | Checkpoint Race first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-THREADING | Asteroid/debris Threading first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-PATROL | Platform Patrol first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-JOVIAN-KIT | Jovian kit delivery first full ordinary play | 13 | Ordinary board/depart/deliver DONE through28a5e354e;79.213s strict home return, two kits/single reward/usable exit. Distinct-process reload remains unqualified after strict30s timeout; no whole-parent closure |
| KIT-BOARD | Ordinary offline cargo selection and Jovian pilot boarding | 7,13 | DONE source62bc7c823;66.158s, real menus/walk/local pilot/occupied berth, cargoIDLE0/source6/destination0 manifests; no departure |
| KIT-DEPART | Real departure automatically starts cargo, then ordinary brake | 13 | DONE sourceb91019562;70.350s, real5m/lease release/ACTIVEg1/brake≤.5m/s1s/original180s |
| KIT-DELIVER | Strict home landing transfers2 kits/pays once; usable exterior exit | 13 | DONE28a5e354e;79.213s actual dock/lease, COMPLETEDg1 kits4/2, one transfer/reward, automatic OFFLINE/authored exit/supported walk≥.5m |
| KIT-RELOAD | Distinct process reloads actual completed store without duplication | 13,31 | FAILED/PARKED;972efd906 strict30s timeout, f432bd630 diagnostic Main ready/restore accepted27.762s then first normal frame pair incomplete before30s. Full60-tick restart unqualified; raw/input retained, no further probe selected |
| PLAY-CINDER-SUPPLY | Cinder platform supply first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-MINING | Mining/extraction first full ordinary play | 13 | FAILED/PARKED candidate20bd1ab: single archive route53.444s reaches real Cinder approach then strict-stops on Activity Board focus-disconnection errors, before mining/return. Source unmerged/checkpoint withheld; UI-BOARD-FOCUS causal repair required before reopening; original CAP300 unchanged |
| PLAY-SCAN | Structure Scan first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-BEACON | Beacon Traversal first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-CONVOY | Convoy Escort first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-DEFENSE | Station Defense first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-BREACH | Heavy Breach first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| PLAY-TORPEDO | Torpedo Run first full ordinary play | 13 | UNSCHEDULED; canonical outbound/activity/reward/home return |
| HUD-RACE | Race durable reset/select/start/fresh-Main UI | 13 | UNSCHEDULED; correct existing owner only on actual discrepancy |
| HUD-PATROL | Patrol durable reset/select/start/fresh-Main UI | 13 | UNSCHEDULED; correct existing owner only on actual discrepancy |
| HUD-CARGO | Cargo durable reset/select/start/fresh-Main UI | 13 | Supply-status child DONE0c2dc2e: depleted hold reports insufficient kits after reset/reselection; cargo127/nearby HUD13 and paired checkpoint pass. Broader durable UI/restart remains open; KIT-RELOAD stays parked |
| HUD-CONVOY | Convoy durable reset/select/start/fresh-Main UI | 13 | UNSCHEDULED; correct existing owner only on actual discrepancy |
| ACT-WRITES-DEFINE | Uncovered activity/write-boundary cells | 13,31 | DONE definition only; finite durable owner/boundary map below, with terminal-only owners distinguished; exact-package/real-file/ordinary recovery acceptance remains open |
| BOOT-BREACH-OWNERS | Physical Heavy Breach board has exact production owners before gameplay | 9,11,13 | DONE packagede3d1ada; two exact old owner failures, final full startup/48-check production route and strict paired checkpoint pass; original interruption transaction remains parked |
| BREACH-INTERRUPTION | Exported Heavy Breach real-file earned debt/kill/recovery/paid replay | 13,31,32 | FAILED/PARKED: after originale9/repair3c board failures and accepted startupfixe3, unchanged-probe reopeningc159 fails69.957s at atomic-payment commit assertion; third cold replay NOT_RUN. Cumulative140.961s; unmerged/withheld, no further run/repair selected |
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
| REPEAT-BREACH | Ten cleared Heavy Breach postings through ordinary board rotation | 13 | GATED on PLAY-BREACH and measurement/deadline freeze; alternate Torpedo postings cannot be skipped; BREACH-INTERRUPTION remains PARKED |
| REPEAT-TORPEDO | Ten cleared Torpedo postings through ordinary board rotation | 13 | GATED on PLAY-TORPEDO and measurement/deadline freeze; ten mixed sorties do not satisfy ten of either scenario |
| TRAVEL-LIMIT | Numeric ordinary nearby-travel envelope | 13 | DEFINE; design/runtime basis and scope decision |
| HULK-REVISIT | Home-return/reload/revisit retains restored bus and single claimed cell | 13 | PARKED; failed route plus repair, original 300s |
| EMBER-SOURCE-ABANDON | Integrated physical Ember abandonment/home return | 1,14 | DONE; e85157b4d, MemoryFilesystem, original exact31 |
| EMBER-OBSERVER | Native package observer production capability | 1 | DONE; 4270d71 source capability and startup-qualified checkpoint |
| EMBER-NATIVE-SMOKE | Native observer normal-window-close smoke | 1 | PARKED; failed fixture/repair and priority review retained |
| EMBER-PACKAGE-ABANDON | Packaged ordinary physical abandonment/home return | 1,14 | GATED; supported OS-input route, old external-driver path UNSUPPORTED |
| WORLD-ABANDON-DEFINE | Applicable Aurora/Rime abandonment and Ember reuse/durability cases | 1,14 | DEFINE; explicit physical/durable outcomes, source pass retained |
| WORLD-SAVE-DEFINE | Uncovered world survey/reward/reboard/visit disk boundaries | 14,31 | DEFINE; contract per world, staged/MemoryFilesystem proof retained only as scoped |
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
| ROLE-HALYARD-GUNNER | Halyard gunner ordinary moving-crew lifecycle | 16,24 | GATED; exact supported craft/candidate, prior role-specific proofs retained |
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
| HELM-THROTTLE-REVERSE | Sampled reverse thrust and neutral release | 18 | OPEN; reverse flight/release child DONE52b228c86, unchanged ordinary route138.086s, host1.448m/888ms and both actual replicas pass; same source/lease/host effect required. Original handback requirement remains open; shared handback parked |
| HELM-YAW | Both sampled yaw directions, neutral release and handback without stale ownership | 18 | OPEN; turn/release child DONE624d2a6 after neutral-attitude fix, unchanged ordinary route139.519s and both client attitudes pass. Original failures retained; corrected38c079086 shows PASSENGER after real handback but fails156.016s at cabin walk15s. Handback parked after original plus one repair; candidate unmerged, full walk/handback remains required |
| HELM-PITCH | Both sampled pitch directions and neutral release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| HELM-ROLL-RATE | Both sampled roll-rate directions and neutral release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| HELM-BOOST | Sampled boost effect on authoritative flight and release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| HELM-HOVER | Sampled hover correction on authoritative craft and release | 18 | UNSCHEDULED; same confirmed source/lease, actual host effect, handback without stale ownership |
| NET-STALL | Original 600-step host simulation stall and honest command recovery | 19 | UNSCHEDULED; independent peers, original 2s action limits |
| NET-SECOND-LAND | Historical intermittent second-landing boundary | 20 | GATED; establish distinctness from current return failure before any probe |
| NET-DOCK-DEFINE | Supported craft dock/exit/reboard/redeparture acceptance cases | 20 | DONE definition only; next five Jovian instances below, all other craft/roles remain unscheduled |
| NET-JOVIAN-PASSENGER-EXIT | Original passenger reaches supported ground while pilot retains helm | 16,20,26 | FAILED compile8054a2cc4 and one syntax repair e147b6d49; parked after priority review, gameplay NOT_RUN |
| NET-JOVIAN-PASSENGER-REBOARD | Original passenger reclaims original co-pilot chair | 16,20,26 | GATED on passenger exit; retained parked card above |
| NET-JOVIAN-PILOT-EXIT | Original pilot releases helm and walks onto supported berth ground | 16,20,26 | GATED on passenger reboard; passenger stays seated |
| NET-JOVIAN-PILOT-RECLAIM | Original pilot returns to same hull and acquires current helm authority | 16,20,26 | GATED on pilot exit; old command generations stay retired |
| NET-JOVIAN-REDEPART | Same crew/hull departs at least5m and brakes after physical reuse | 16,20,26 | GATED on pilot reclaim; no second landing/endurance expansion |
| CONVOY-ACTOR-DEFINE | Uncovered Convoy tender live/dead/reset/late/disconnect cases | 22 | DEFINE; actual native-gameplay coverage versus authority tests |
| TORPEDO-AUTH-DEFINE | Actual projectile authority, retained solo restoration and pilot/target loss | 23 | DONE definition only; ten finite qualification cases below, no new missing production consumer or runtime defect established. Ordinary/independent packaged routes remain OPEN |
| PICKET-ACTOR-DEFINE | Uncovered Picket travelling actor/late/dead/reset/disconnect cases | 24 | DEFINE; actual moving-crew integration |
| EMBERLINE-ACTOR-DEFINE | Uncovered Emberline flight/hit/miss/expiry/late/dead/reset/disconnect cases | 24 | DEFINE; retained failed baseline not erased by isolated pass |
| BROWSER-JOIN | Discover/refresh/select/join ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-STALE | Stale session ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-FULL | Full session ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-UNREACHABLE | Unreachable endpoint ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-CONTROLLER | Controller menu navigation ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-DISCONNECT | Disconnect/retry ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| BROWSER-CANCEL | Cancel/reuse ordinary browser route | 25 | GATED; chosen candidate/scenario, delivered UI fixes retained |
| SERVER-BASELINE-DEFINE | Residual authoritative-server/two-client gameplay command and cases | 26 | DONE definition only; Halyard approach definition DONE, BOARD FAILED/PARKED, MOVING-CABIN/AUTHORITY-STOP GATED; no baseline completion |
| HALYARD-APPROACH | Freeze ordinary spawn-to-airstair input waypoint route | 16,26 | DONE definition; native aft/fleet chain and authored final extension, no collision qualification |
| HALYARD-BOARD | Non-playing Main authority and two original ordinary occupants | 16,26 | FAILED/PARKED; original route and one caller repair both fail consumed-state comparison; no further retry selected |
| HALYARD-MOVING-CABIN | Actual departure with passenger supported walk/chair cycle | 16,24,26 | GATED on HALYARD-BOARD; no staged flight envelope |
| HALYARD-AUTHORITY-STOP | Real server stop restores both remaining occupants to solo play | 16,26 | GATED on HALYARD-MOVING-CABIN; no SIGKILL/migration/reconnect claim |
| SERVER-BASELINE | Dedicated-server/two-client ordinary flight/recovery acceptance | 26 | GATED; exact baseline contract, boarding/departure passes do not close it |
| NET-FULL-SNAPSHOT | All-nine forced-full publication and byte budget | 17,26 | UNSCHEDULED; original aggregate budgets, movement-only bytes insufficient |
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
| SHARED-RIME-BASELINE | Rime shared canonical outbound/physical survey/reward/save/home return | 3,27 | PARKED; original arrival failure plus repair, 120s physical gate |
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
| PERF-ROUTES-DEFINE | Finite uncovered required fleet/cabin/combat/surface/repeat benchmark routes | 28 | DEFINE; seven delivered route selections retained |
| PERF-CELLS-DEFINE | Applicable machine/route measurements | 28 | GATED; required routes and actual two machine profiles |
| INPUT-KBM | Physical keyboard/mouse ordinary full route | 8,18,29 | WAITING; actual device/isolated session, exact required route |
| INPUT-CONTROLLER | Physical controller ordinary full route | 8,18,29 | WAITING; actual device/isolated session, exact required route |
| MIXED-CONTROL-PROMPTS | Grouped help retains mixed button/stick labels independent of action order | 8,29 | DONEb86264f; actual MOVE/default shorthand, glyph40/camera27/help20 and paired checkpoint; no physical device/whole apply-flight claim |
| CAMERA-DISTANCE-PROMPTS | Piloting help exposes both live remapped distance directions | 8,29 | DONE7718a5a; HUD keyboard/controller labels/reset, focused27/help20 and paired checkpoint. No whole apply/restart/device claim |
| REMAP-DEFINE | Uncovered binding/apply/restart/conflict/recovery cases | 8,29 | Definition DONE onc1fc23871; existing persistence contract names finite outcomes and concrete missing on-foot sprint toggle; hardware/Settings prerequisites preserved |
| ONFOOT-SPRINT-TOGGLE | Advertised shared sprint option works while walking | 8,29 | DONEbd4e15d0f, packaged. Saved/live/reset/HOLD, actual Player physics sprint speed and control/tree/remote fences pass; existing settings checks retained. Broader remapping/device gates OPEN |
| ACCESS-PAUSE-DEFINE | Pause/options readability views and required scale/aspect cells | 12,29 | DONE; five named aspect groups/three authored scales, actual view states below |
| ACCESS-PAUSE-4X3 | Pause/options at 1024x768, requested scales0.75/1.0/1.6 | 12,29 | DONE sourceece9a0253:96 actual Main observations/all32 states at each scale, bounds/font/focus/scroll pass33.402s; headless geometry only, no rendered/device/persistence qualification |
| ACCESS-PAUSE-16X9 | Pause/options at 1920x1080, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.405s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| ACCESS-PAUSE-16X10 | Pause/options at 1920x1200, requested scales0.75/1.0/1.6 | 12,29 | DONE source1cf102298:96 Main observations/all32 states at requested.75/1/1.6; conflict and repair-focus corrections accepted |
| ACCESS-PAUSE-21X9 | Pause/options at 3440x1440, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.533s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| ACCESS-PAUSE-32X9 | Pause/options at 5120x1440, requested scales0.75/1.0/1.6 | 12,29 | DONE source4d7ac43:96 actual Main observations/all32 states at each scale pass33.412s; original criteria/caps. Headless geometry only; rendered/device/transaction gates remain open |
| SETTINGS-SCALED-FOCUS-SCROLL | Fully reveal current Settings focus under scaled pause layouts; ignore stale/duplicate requests | 12,29 | DONE; paired4d7ac43. Focus59 and complete16:9/21:9/32:9 checks pass. Original21:9 failure33.080s and pre-run review correction retained in history |
| ACCESS-VIEWS-DEFINE | Remaining required HUD/menu/help/role readability views/cells | 12,29 | DONE as source definition in the finite view roster below; owners/states/coverage and one-cell selection named. No new layout/device qualification. |
| COMFORT-MOTION | Reduced motion route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-FLASH | Reduced flash route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-COLOUR | Colour-safe cues route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| COMFORT-CAPTIONS | Captions route and retained setting | 29 | GATED; exact affected existing route, no new option implementation assumed |
| AUDIO-CONTENT-DEFINE | Finite actually missing cues and broken transitions | 30 | Definition DONE on8a6e7dfe6; existing COMPLETION_SCOPE audio map separates real playback, two transition outcomes and dormant Ember feed definition; no missing new theme inferred |
| AUDIO-ACTIVITY-LIFECYCLE | Current activity music survives normal updates and same-run completion | 30 | DONEf1f35d137, packaged. Same-run completion/base updates, terminal fences, combat/landing resume, reset/context/lifecycle/PCM/clock scopes pass; five focused suites, paired exports/three strict startups. Audible mix OPEN |
| AUDIO-SURFACE-MUSIC | Aurora/Rime surface visit selects existing surface bed | 30 | DONE packaged4ff7a08; actual visit-state projection, controlled phase150/activity26/retained bed checks and strict paired checkpoint pass; ordinary journeys/listening remain open |
| AUDIO-EMBER-FEED-DEFINE | Actual intended Ember environment and observation owner | 30 | DEFINE; wrappers dormant, zero-delta helper alone is not a running-game delivery |
| AUDIO-MIX-DEFINE | Finite real-output scenario/device mix list | 30 | DEFINE; distinct from silent state/integration checks |
| AUDIO-MIX | Actual output levels/cues/transitions in named scenario | 30 | WAITING; finite scenarios, explicit audible authorization and device |

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
| SAVE-UNSUPPORTED | Unsupported data refuses destructive overwrite | 31,32 | GATED; exact fixture, secret-free diagnostics |
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
| RIGHTS-DEFINE | Finite project/asset/source licensing families and missing documents | 34 | DEFINE; preserve settled creator permission, no repeated question |
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
Cargo reload, Halyard boarding and handback retain their recorded failures and
reopen conditions; they are not READY work. All36 original parents and ten phase
gates remain open. Local scheduling is not a whole-project estimate.

A DEFINE row must end in a finite list/contract or an exact missing fact, with
no engine run unless separately scheduled. Expand its existing parent here only
with actual uncovered outcomes. In particular, the eight BUILD-SPLIT rows are
placeholders for future capability cards, not eight complete ship builds.
Weapon/damage cells, historical relationships, presentation defects, repeated
activity/write/save cases, adverse network profiles, performance measurements,
readability cells, audio scenarios, installed interruption cuts and licensing
families still have unresolved multiplicities. **A defensible whole-project
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
| GUIDED[chosen combined package] | ELIGIBLE; exact package | Pass original Guided ordinary-input route 3/3 in fresh processes/profiles, unchanged shutdown timing. Stop at those three runs; old e085 passes remain source-specific. |
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
| `cinder_race_session_save_restore_test.gd` | Original 300s timeout; one-boundary diagnosis required. |
| `game_flow_ember_surface_presentation_integration_test.gd` | Original 300s timeout; separate setup from first incomplete integration boundary. |
| `game_flow_scan_durable_recovery_test.gd` | Half-second retry fixed; later full suite still times out after 96 printed passes. Diagnose remaining boundary. |
| `session_recovery_resume_offer_test.gd` | Q5 original300s probe on `df66dcded` completes Main16 real-file recovery, then expires at Main17 next passenger interaction (fixture line631) after151 passes. Main18/19 unentered; inner await unresolved. No recovery defect/fix proven; do not repeat unchanged. |
| `game_flow_rime_client_pad_controls_test.gd` | On3e39ed8da corrected headless run first scenario completes, return17.099s; second held-edge starts264.733s and still progresses at291.862s before original 300s timeout. Diagnosis above; preserve180 edge waits/1,440-tick exposure and100 jump waits. Next: reduce a measured production hotpath, then affected original checks; no unchanged rerun or timing relaxation. |
| `network_emberline_bolt_test.gd` | Retained failure waits on later dead-peer baseline before reset; pending-generation errors follow. Q1 isolated `e026cf620` instrumented probe passes 154 under original limits, so no repair/root cause is proven. Retain old matrix FAIL; cover next combined matrix without another unchanged isolated run. |
| `station_light_overlap_census_test.gd` | Historical expected rows/environment unresolved; mismatch repeats on its own freeze. Recover measurement basis before changing expectations; never replace hashes just to pass. |

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
| Aft | Upper operations room consoles/workpost from the stair arrival | `aft_junction_stack.gd`, world Aft activities; distinguish Activity/Destination controls and preserve stair/door clearance |
| Habitat | Bunk/common-room arrival and garden/observation doorway | `habitat_spine.gd`, world patrol/skywatch; preserve accepted ordinary loop, usable bunks and wake controls |
| Freight | Service-room entrance and gantry beside the actual boarding approach | `jovian_freight_berth.gd`, world Freight activities; readable service/boarding destinations and operable unlocked door |
| Fleet Dock | One named berth threshold from its actual approach | `fleet_dock_comb.gd`, `fleet_expansion_berths.gd`; correct craft destination and boarding/landing clearance; choose berth before reviewing |
| Annex | Restock console from the supported central aisle | `fabrication_annex.gd` geometry and `shipyard_world.gd` console owner; existing service text/control and clear aisle; unfinished south gate is not a promised destination |
| Observation | Cross-landing view toward one named Observation/Logistics pad | `observation_logistics_spur.gd`; correct pad destination and supported return |
| Salvage | One inspection-pad view after supported arrival | `salvage_terrace.gd`, `salvage_inspection_station.gd`; three-component contract retained; physical access/revisit remains parked/gated |
| VIP | Reception arrival view after supported access | `vip_reception_suite.gd`; existing route/evidence boundary retained; parked VIP walk is not reopened by this list |

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
| TRAVEL-LIMIT[one nearby route] | DEFINE; release scope decision | Establish proposed numeric ordinary-travel envelope and route conditions from design/runtime facts; obtain required decision. Stop at finite criterion, not an invented “agreed maximum.” |
| HULK[physical salvage/power/revisit] | Arrival, breaker and home ordinary-input qualification DONE; revisit/disk gates open | Existing interior83 scoped checks retain their limits. Full ordinary Guided/HULK/breaker/reverse walk/reboard/home route driver7e251f8af/gameef67f3e95 passes191.886s at original300s cap, actual unload and once-only receipt retained; checkpointef67f3e Linux is exact tested binary. Windows payload startup/privacy passes separately; strict payload parity fails65 generated scenes. REVISIT-CONTRACT DONE; REVISIT-INPUT candidate5010ef932 FAILED optional-lift driver condition; REVISIT-DEPARTURE candidate2298e4889 FAILED original300s deadline during new interior walk after actual reload/dock/exit; no fresh breaker event. Candidate withheld; REVISIT-CHECKPOINT GATED; independent Ember ABANDON source qualification subsequently DONE; no HULK repair selected in ROADMAP.md; no unchanged interior rerun or full-parent closure. |
| WORLD-CONTENT[one world/gap] | DEFINE if missing content not named | For Ember, Aurora or Rime, name one finite missing environmental/content behavior from the original specification and roster. Implement that behavior in a separate bounded child with ordinary surface interaction and checkpoint. Stop at specification or named behavior, not a new planet catalogue. |
| WORLD-SOLO[one world] | ELIGIBLE for implemented world; existing physical route | Complete canonical outbound, atmospheric descent, physical landing/exit/activity/reboard, ascent and home dock through ordinary controls. Preserve original route/physics limits; staged arrival is not acceptance. Stop at one world's full route or first defect. |
| WORLD-ABANDON[one world] | GATED on WORLD-SOLO route | Qualify delivered abandonment/home-return fixes in full integrated-source and packaged journey, including physical walking/docking/reuse. Ember integrated-source ABANDON DONE on e85157b4d: exact31, exit0, physical outbound/abandon/reboard/ascent/home occupied dock/walking, MemoryFilesystem, original7200s cap. Packaged journey/reuse/disk gates remain open; earlier ec457/6e1 scoped passes are not this full parent gate. Stop at named scenario; no unchanged source rerun. |
| WORLD-SAVE[one world/boundary] | GATED on named expected resume/safe-recovery contract | Save/reload or real interruption retains visit/survey/reward/reboard state once and returns to usable play. Stop at one boundary. Rime df862 staged/in-process 78-pass restoration is delivered; it does not qualify canonical journeys. |
| WORLD-EDGE[one world/case] | GATED on baseline route and scenario definition | One solo cancellation, refusal, failure, repeat visit or interruption case preserves physics, rewards and return to use. Stop at one case; shared late join/disconnect belongs to WORLD-SHARED. |

Route anchors include `tests/ember_transit_movement_soak.gd`, `tests/aurora_physical_return_soak.gd --aurora-full-roundtrip`, `tests/ember_abandon_return_manual_override_test.gd` and the existing Rime landing/survey routes. Resolve the exact existing command in the task card before running; never substitute a staged route for a canonical one.

### Activity repetition — first bounded definition slice

Source431f24b59, definition only; no gameplay defect or implementation assignment.
The existing ten-same-world-run requirement is retained in
[completion scope](COMPLETION_SCOPE.md).
REPEAT-RACE, REPEAT-BEACON and REPEAT-SCAN each require its named canonical
PLAY-* journey first. Qualify one activity at a time; ten runs do not waive
ordinary outbound/home acceptance or become ten unrelated test/evidence commits.

| Child | Production owner / finite route | Acceptance to freeze before selection |
| --- | --- | --- |
| REPEAT-RACE | NearbySectorActivityBinding.start_race/reset_race and CinderTimedRaceSession; actual ActivityDirector checkpoints, TimedCheckpointRace timing | Same live world across ten legitimate start/checkpoints/finish/payment/reset cycles; exact generation/receipt identity, no duplicate reward, no stranded objective; ordinary inputs and actual route. Existing3s countdown/120s race timeout remain unchanged. |
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
| REPEAT-CINDER-SUPPLY / [binding cargo ownership](../scripts/world/nearby_sector_activity_binding.gd), [terminal debt owner](../scripts/persistence/cinder_cargo_delivery_persistence.gd) | Actual load_crate→clear_gate→dock_platform, authorized physical terminal transfer1 crate, durable once-only payment, accepted reset; ten cycles under existing120s deadline | PLAY-CINDER-SUPPLY first. Initial source2/capacity8 and destination capacity8 fund only2 transfers per retained source; rebinding may reseed a source but is not an approved infinite-stock contract and does not empty destination. Name legitimate replenishment plus destination turnover before execution. Preserve unanswered Hauler stock decision; do not infer Hauler delivery from access or Jovian baseline |
| REPEAT-MINING / [mining activity](../scripts/world/cinder_mining_platform_activity.gd), binding persistence/reset | Approach within30m, hold actual6s extraction at authored anchor, request and persist capacity receipt once, accepted durable reset, then repeat ten times/next start | PLAY-MINING first. Leaving radius interrupts progress; pending capacity save blocks reset/start. No ore/currency grant is invented. cinder_mining_durable_recovery_test.gd protects durable boundaries but does not prove ordinary repetition |
| REPEAT-CONVOY / [production host](../scripts/activities/cinder_convoy_escort_host.gd), GameFlow._start_cinder_convoy/reset_active_activity | Healthy piloted departed craft enters actual4m rendezvous sphere, escorts real tender through complete authored route/threats to safe arrival, settles debt, accepted production persisted reset; ten successes/next start | PLAY-CONVOY first. Use retained GameFlow host, not streamed binding's standalone fixture. Preserve90s timeout,42m escort proximity/3s separation and authored movement. Tender/threat reuse and terminal cleanup count toward resource acceptance; retained Convoy failures are not authorized retries |
| REPEAT-DEFENSE / [physical board](../scripts/activities/station_defense_activity_board.gd), [scenario](../assets/activities/shipyard_perimeter_defense.tres) | On-foot board Deploy→ordinary boarding/departure/combat→all three authored waves clear→one payment→home/dock/on-foot board Reset; ten fresh completed deployments and usable next Deploy | PLAY-DEFENSE first. Current fixed hostile counts1/2/1, delays0/2.5/8s, timeout34s; retain original semantics. Failed-wave recovery is continuation, not a counted fresh success. Pending payment must settle; protect/reset the actual objective and reuse bounded host roster |
| REPEAT-BREACH / [physical alternating board](../scripts/activities/heavy_breach_activity_board.gd), [scenario director](../scripts/combat/encounter_scenario_director.gd) | On-foot arm posted Heavy, board/depart a real combat-capable ship, destroy actual charged picket while protecting objective, clear/pay, ordinary return/dock/on-foot rearm; count ten Heavy clears | PLAY-BREACH first. Conclusion rotates posting to Torpedo; no normal post-clear Reset required. Pending debt blocks arm. Respect normal craft service/ammunition constraints; unresolved Bomber rearm is not bypassed. Existing BREACH-INTERRUPTION stays PARKED |
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
| Cinder platform supply / NearbySectorActivityBinding + CinderCargoDeliveryPersistence | `cinder_cargo_delivery` strict v2 earned terminal proof before payment, atomic paid acknowledgement; legacy v1 presentation-only. Existing roundtrip onf8b5f86 uses three actual-file child processes | CINDER-SUPPLY-DEBT DONE in its selected refusal/cold-payment/no-replay scope. Active manifest resume, ordinary/installed/final/OS-interruption acceptance remain separate; no Jovian behavior inferred |
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

BREACH-INTERRUPTION remains FAILED/PARKED. Its original e9 and one caller repair3c
failed board admission35.365/35.638s. Separate production fix BOOT-BREACH-OWNERS
e3d1ada resolved the actual missed startup binding and passed full startup plus
existing48-check route and paired checkpoint. Root then explicitly selected one
unchanged-probe reopening on that causal fixed baseline, preserving prior71.004s.
Candidatec159 reaches real earned debt/readiness kill/cold normal Resume/production
exit/physical board retry and matching paid receipt checks, but fails its atomic
payment commit assertion69.957s. Cause unproven; no IN_WORLD_RECOVERY_OK, third cold
paid replay or package transaction. Cumulative140.961s STOP/PARK; all failed refs/
raw results retained, no further diagnosis, repair, fourth automatic attempt or
renamed retry selected. These partial observations do not accept the unchanged
full real-file/pilot/board/payment/cold replay contract. [Reopening closure](history/ROADMAP_DELIVERIES.md#breach-interruption-after-fixed-startup--failed-and-parked).

## Multiplayer

<a id="phase-7--multiplayer"></a>

Scope: all twelve original §4 outcomes and retained ordinary-remote-crew milestone. Select one craft, role, channel or matrix cell; aggregate session and snapshot checks remain separate.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| NET-CAPACITY[one supported session profile] | GATED on SCOPE-LIMIT decision | Verify explicit player count, per-craft occupancy/roles and connection profile. Eight configured clients is not accepted eight-player support. Stop at one profile. |
| NET-CREW[one craft/role] | ELIGIBLE for implemented route | Independent authenticated ordinary crew walks, sits, performs role, stands/exits and survives applicable ownership/host/disconnect recovery. Use existing Jovian engineer, Halyard engineer/passenger or Bulwark gunner route tests. Stop at named role. |
| NET-POSE[one craft/operation] | ELIGIBLE; existing remote/craft-pose tests | Current and late peer see correct engine, station-frame pose and landing/dock presentation during one named operation. Use `network_remote_craft_pose_test.gd` / `network_craft_pose_station_frame_test.gd`; stop at operation. |
| NET-HELM[one supported action] | ELIGIBLE; `network_remote_pilot_helm_test.gd` | Real sampled local input reaches supported remote helm action and handback without stale ownership. Stop at original action/recovery scenario; synthetic command-only checks cannot close input prerequisite. |
| NET-STALL[existing host-stall route] | ELIGIBLE; stable independent processes | Original 600-step stalls and original 2s action limits recover honestly without false completion. Stop at route result; no clock/deadline relaxation. |
| NET-LAND-DIAG[intermittent second landing] | DEFINE; original failure retained | One probe identifies the first failed boundary in second landing/reuse. Stop with owner/fix or blocker; no speculative clock rewrite. |
| NET-DOCK[one craft] | GATED on relevant fix if needed | Remote landing/dock, ordinary disembarkation, reboard and repeat departure succeed. Stop at one craft's existing route. |
| NET-DAMAGE[one craft/role scenario] | ELIGIBLE; existing damage/respawn integration tests | Peer presents hull/component damage, repair, destruction and regeneration coherently, then returns to usable role/craft. Stop at one scenario; preserve authority and ownership. |
| NET-ACTOR[one channel/lifecycle] | ELIGIBLE for implemented channel | Convoy, Torpedo Run, Picket or Emberline instance covers its named travelling actor/projectile live/dead/reset, late join, disconnect or solo-restoration boundary. Use existing authority/Emberline tests. Stop at one lifecycle case, then schedule uncovered cases separately. |
| NET-BROWSER[one ordinary menu flow] | ELIGIBLE; discovery/binding tests | Discover/refresh/select/join/disconnect/retry from normal menus. Separate stale, full, unreachable, cancel and controller cases into individual instances; stop at selected flow. |
| NET-BUDGET[all-nine forced-full snapshot] | ELIGIBLE; existing budget owner | Measure original full-snapshot publication/byte budgets across supported nine-craft load; movement-only bytes do not qualify. Stop at this aggregate budget result; do not repeat for every NET-POSE task. |
| NET-ENDURANCE[one supported profile] | DEFINE exact independent-process command, then GATED on stable baseline | Run original 30-minute two-client moving-interior session with declared latency/profile and no ownership/state leaks. `network_moving_interior_latency_test.gd` is an anchor, not an invented substitute command. Stop after original duration and clean closure. |
| WORLD-SHARED[one world/case] | GATED on supported crew/profile and baseline dependencies | Ordinary independent remote crew completes the selected canonical case, including actual outbound/return, activity/reward/save and appropriate usable recovery. Preserve focused 300s/canonical 900s and physical landing 120s where specified. Stop at one matrix cell. |

WORLD-SHARED instances: **Ember, Aurora, Rime**, each with **baseline full outbound/return, late join, disconnect/reconnect, pilot loss, cancellation, real interruption, repeat visit**. Each cell is a separate task and must name participants, initial state, ordinary-input route and durable reward/return criteria before execution. The baseline includes activity and save behavior; failure cases do not inherit a staged baseline. Use existing `tests/network/halyard_network_shared_planetary_cruise_test.gd` and applicable world/landing tests. Missing exact case coverage becomes a bounded DEFINE child, not a claim that the anchor already covers it.

### Supported remote helm action roster

HELM-ACTIONS-DEFINE is DONE as a source definition, not new gameplay or current
source qualification. Production owners: `scripts/control/local_ship_input_source.gd`,
`transformed_ship_command_mapper.gd`, GameFlow's capture/forwarding path and
`network_remote_pilot_command_source.gd`. Defaults below are from `project.godot`;
remaps may replace them. Test references are coverage anchors unless a recorded
accepted source/result is explicitly stated. No tests ran for this definition.

| Action / default binding | Command field | Wire / actual host consumer | Proof and remaining boundary |
| --- | --- | --- | --- |
| Forward W / reverse S; controller axis1 | throttle | move_axis[1] → decoded throttle → HeroShip flight thrust | Forward accepted96c96312f; reverse flight/release accepted52b228c86, actual host motion and both replicas. Original handback remains open. |
| Left A / right D; controller axis0 | yaw | move_axis[0] → yaw → host attitude | Provider mapping/solo action anchors in ship_command_test and flight_input_test; both sampled remote directions/effect/release remain HELM-YAW. |
| Up/Down arrows; controller axis3 | pitch | look_pitch → pitch → host attitude | Provider mapping anchor in ship_command_test; both sampled remote directions/effect/release remain HELM-PITCH. |
| Roll left Q / right R; controller axis2 | roll | look_yaw → roll rate → host attitude | Provider mapping anchor; both sampled remote directions/effect/release remain HELM-ROLL-RATE, separate from barrel roll. |
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

**NEXT: Jovian passenger post-dock stand and exterior exit only.** The visible
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

The original exit caller and its one repair failed parsing; no gameplay route
ran. Candidates8054a2cc4/e147b6d49 and raw failures remain retained. These five
ordered cards preserve their acceptance/dependencies; none is currently selected.
Numeric predecessor references here mean this parked five-card Jovian sequence,
not the executable queue.
A new explicitly bounded syntax correction/review must precede any retry.

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
- **Priority review/next:** about45 min implementation/review/setup plus bounded
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

## Performance, controls, accessibility and audio

Scope: original §5, Phases 9 and 10.2–10.3. Software rendering, VM and remote-display behavior do not qualify native target GPU performance.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| PERF-MACHINE[one minimum/target profile] | WAITING on representative hardware if unavailable | Bind declared CPU/GPU/RAM/display/driver profile to an actual isolated test machine. Stop at available machine identity or exact missing resource; never infer native performance from llvmpipe. |
| PERF-ROUTE[one missing benchmark route] | DEFINE; named required scenario | Specify and implement one missing fleet/cabin/combat/surface/repeat route through existing benchmark runner. It supports default `station_embodied_route` plus `nearby_sector_ship_flight_route`, and select-only `halyard_cabin_walk_route` from D5 plus `torrent_range_combat_reuse_route` from E1 and `ember_surface_walk_route` from E2, plus delivered select-only `aurora_surface_walk_route` on c47b5cd55. Rime icefall survey/return route DONE on a8f563e39 (521.227m sampled,13ordered points/one sampled loop,source33/default152/Ember24/Aurora27); paired development checkpoint a8f563e DONE in ROADMAP.md, using the existing authored trails; other repeat instances stay open. Default combined acceptance retains its original narrow scope. Stop at executable route/selection and focused check, not a new benchmark system. |
| PERF-RUN[one machine/scenario] | GATED on machine and executable route | Original warmup at least 3,600 frames/60s; measurement at least 18,000 frames/600s. At 1080p High, p95 ≤16.7ms, p99 ≤33.3ms, no post-warm frame >100ms, peak working set ≤4GiB, plus required actual GPU/VRAM and streaming/transient budgets. Stop at that measured scenario; retain failure. |
| PERF-FIX[one measured hotspot] | GATED on demonstrated production cost | Fix the identified runtime/rendering owner; repeat the affected measurement and behavior check. Stop at measured effect and checkpoint; no census-only progress. |
| INPUT-DEVICE[one device/route] | WAITING on physical device if absent | Ordinary full selected route with actual keyboard/mouse or controller, including lifecycle/planetary control as applicable. Existing physical-sortie, lifecycle and controller-only expedition tests guide scenario. Stop at selected route; synthetic events cannot qualify physical hardware. |
| INPUT-REMAP[one setting/binding] | ELIGIBLE for automated persistence; physical confirmation separately | Remap/apply/restart retains binding and usable menus/gameplay, with conflicts/recovery as specified. Reuse runtime remapping/presenter/contract tests. Stop at one case. |
| ACCESS-VIEW[one view/scale/aspect] | ELIGIBLE for isolated capture; relevant hardware separately | Verify readability/focus/clipping for named view at minimum/default/maximum scale and one of 4:3, 16:9, 16:10, 21:9, 32:9. Instantiate each required cell separately, using existing runtime accessibility tests. Stop at one view/cell or fixed finding. |
| ACCESS-COMFORT[one route/option] | ELIGIBLE; existing runtime options | Verify one reduced-motion, flash, color-safe or caption behavior in actual route and after restart as required. Stop at named option/scenario and any focused correction. |
| AUDIO-CONTENT[one cue/transition gap] | GATED on identified missing behavior | Author/fix one production ambience/music/effect transition and run existing music state/activity/orbit/surface integration checks with Dummy audio. Delivered Aurora coast is not a new gap. Stop at cue/transition and checkpoint. |
| AUDIO-MIX[one real-output scenario] | WAITING on explicit audible-test authorization and output device | Check actual mix/levels/transitions for selected scenario, fix concrete issue and repeat it. Stop at scenario result; automated Dummy output does not qualify real audio. Owner-excluded human review does not become a mandatory approval gate. |

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
| ACCESS-TITLE: ordinary startup menu and return from browser/credits | GameHUD intro layer / `show_intro`, `_focus_intro_start_button` | `startup_loading_screen_test.gd` proves menu readiness; `controller_pause_navigation_prompt_test.gd` covers browser return and `credits_page_test.gd` covers credits return. A selected cell checks title text, Begin Shift/browser/credits buttons and retained enabled focus. Unresolved recovery choices use ACCESS-RECOVERY below. |
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
| [HeavyBreachActivityBoard](../scripts/activities/heavy_breach_activity_board.gd), Heavy Breach | Scenario/generation floor and earned unpaid/paid completion, no active combat/timer/actors. | Active encounter recovery policy unresolved. Original real-file interruption remains PARKED140.961s; this map does not reopen it. |
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
remain open. Native/device/human gates and all36 parents/ten phase gates remain open.

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
| WORLD-SAVE[Ember/location boundary] | Set the expected original resume/safe-recovery boundary explicitly; current later-survey continuity does not close surface-location restoration if required. Preserve that uncovered scope. |
| WORLD-SAVE[Aurora or Rime/one disk boundary] | Freeze one eligible phase/craft/progress/payment boundary; real-file fresh-process recovery/reboard and once-only reward. |
| RECOVERY-KILL[planet/one installed package] | Own actual kill/reap and distinct restart for the frozen contract; use existing driver where supported or select one concrete missing executable capability. |

Quit/return/repeat remain WORLD-EDGE, canonical journeys WORLD-SOLO and shared
interruptions the existing SHARED-* rows. Aurora missing-original waits and Rime
parked arrival remain unchanged. All original promises/phase gates stay open;
no surface-location waiver, automatic probe or parked-route retry is selected.

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
| HAULER-CARGO-STOCK | Decide shared existing two-crate mission stock, separate two-crate Hauler stock, or loading-terminal custody | WAITING on the one already-asked question; no elapsed-time answer/default authorization. This selects custody/initial entitlement, not a new approval requirement for independent access work. |
| HAULER-CARGO-MANIFEST | Admit actual Hauler with distinct exact source handle/manifest and conserved chosen stock; source replacement keeps a monotonic activity generation and existing reward/transfer replay fences | GATED on stock policy/access. Existing CargoDeliveryActivity starts generation0, producing contract_g1; simply recreating it after completion collides with the ledger. Nonactive source retirement/re-registration also reseeds stock. Prove Jovian→Hauler→Jovian ownership, stale-handle refusal, no stock recreation, exact destination conservation/one receipt per completion. Do not clear ledgers/fences. Freeze files and proof before implementation. |
| HAULER-CARGO-DELIVERY | Current pilot loads through real terminal, physically departs/clears gate, lands/exits/walks back and commits exactly one source→destination transfer/reward; repeat preserves quantities/receipts | GATED on access/manifest. Use actual ship/actor/lease/terminal generations and chosen custody; preserve old Jovian route. Define exact unchanged route/caps before running. Bridge/role proposals are not delivery proof. |

The smallest manifest seam is NearbySectorActivityBinding source admission and,
if required, a supported CargoDeliveryActivity generation continuation. Keep
CargoManifest/transfer authority/reward handoff/persistence formats unchanged
unless a concrete consumer requires a change. Terminal-summary-only Cinder cargo
persistence remains: cold restore exposes completion at generation0 without live
inventory/progress or replayable reward. Existing tests are anchors, not new passes:
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
BOMBER-REARM-POLICY must define which same-hull events may replenish spent
payload (seat re-entry, dock service or actual destruction/reuse) before assigning
a correction or proof. Existing explicit fresh-generation unit behavior remains
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
raw/remote source refs retained. Survey/home/package children remain unqualified
and parked with that parent. Recorded priority review selected the independent
Linux uninstall-interruption/retry/ship batch, now DONE on505d419. The next
working queue delivered BROWSER-CANCEL and paired checkpointa39e93a, closed
RACE-PAGE-RESET static diagnosis without a repair. FIRE-RESTART and its one
viewport fixture repair both fail before capture; candidates withheld, raw and
remote hold retained, clean checkout removed. Required priority review selected
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
GATED; no speculative fix is scheduled. No further Fire probe/repair is selected. See
ROADMAP.md for exact contracts. No further Rime
probe, repair or unchanged run is selected.
One failed task plus its attempted repair requires a recorded priority review
before further repair; a new task name does not reset that boundary.

## Working constraints

Follow [AGENTS.md](../AGENTS.md). Every automated Godot invocation uses `--audio-driver Dummy`; use headless or isolated displays, explicit `--display-driver x11` under Xvfb and an independent abort/cleanup path. Do not use the owner's desktop or audible output without explicit authorization. Keep scratch, helpers and worktrees under `/srv/mudds-work/`; remove completed temporary worktrees after verifying integration and preserve unique uncommitted work/raw failures. Never enable/dispatch hosted CI. Do not use native Windows/Wine under the execution hold. Checkpoint artifacts belong in repository `builds/`, not Downloads.
