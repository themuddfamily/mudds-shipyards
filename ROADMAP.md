# Development roadmap

This is the working task list, restructured on 2026-10-17. The game is a playable development alpha; all ten phase exit gates remain open. This rewrite closes no production requirement.

The [preserved scope and history](docs/history/ROADMAP_SCOPE_20261017.md) contains the complete previous roadmap, including original Phase 1–10 specifications, numerical limits, routes and acceptance conditions. Those requirements remain binding. The [production roster](docs/COMPLETION_SCOPE.md) names current content and remaining gaps. Use this file to select a small task; use those references to check its full contract. Historical passes qualify only their recorded source and scenario.

Latest playable checkpoint: `df86280b5b3985770be527af71c6c247f311aae7`, with [Windows notes](builds/windows/MuddsShipyards-df86280-notes.txt) and [Linux notes](builds/linux/MuddsShipyards-df86280-linux-notes.txt). Its shared Rime recovery guidance fix and focused package checks pass. The full matrix on that source is **NOT_RUN**. The last unfiltered matrix, `f85957f`, failed 11 of 1,045 suites; later focused fixes do not rewrite that result.

Native Windows execution/validation and human playtesting/review are owner-excluded mandatory completion gates. Keep unperformed results **NOT_RUN**, without treating those exclusions as new blockers. The Windows antivirus execution hold remains in force. Applicable native GPU, physical-device, audible, Linux runtime, signing and other release requirements remain separate. GitHub Actions stays disabled under the owner's CI budget hold.

## How to finish one task

Every row below describes a task or a repeatable **single-instance task template**. A template is not an executable assignment until its craft, route, case, world or artifact is named. `WORLD-SOLO[Ember]` and `WORLD-SOLO[Rime]` are separate tasks. Never assign a whole cross-product as one job. The tables are a work breakdown, not a count of finished work or a release estimate.

Statuses:

- **READY:** a bounded implementation or check can begin using existing owners and tools.
- **DEFINE:** one missing scenario, numeric criterion or reproduction must be specified first. Stop with one concrete contract and next action, or one named blocker.
- **GATED:** a named preceding task must finish before this instance can pass.
- **WAITING:** a specific external artifact, machine, device, credential or owner decision is missing. State exactly what is needed; do independent ready work meanwhile.
- **DONE:** the named instance met its criterion on the recorded source/build. A historical template example does not finish every instance.

Use this durable task card at the top of each implementation session and update it before handoff or context rollover:

```text
Task ID and one named instance:
One player-visible result (or executable release capability):
Accountable owner; production files/component:
Dependencies and available inputs:
Acceptance: existing command/scenario, unchanged limits, expected result/artifact:
Source/build being checked:
Estimate: implementation/check time; external waiting time separately:
Stop when:
Latest actual result and remaining uncertainty:
Next single action:
```

The selected task must fit one focused delivery: normally one defect, one route, one craft component or one packaging capability. Split it again if it requires unrelated fixes or an open-ended audit. A diagnostic task gets **one stated hypothesis and one probe**; after the result, choose a concrete fix, a different justified hypothesis or a named blocker. Do not repeat an unchanged failed run. Preserve its raw failure, deadline and physical criteria.

Finish implementation with the affected existing focused check and integration check where needed. A meaningful gameplay/graphics checkpoint also needs a fresh clean-source Windows EXE, ZIP and notes under `builds/windows/`, following the safe export and silent isolated package workflow. Checkpoints do not require the entire final release matrix after every small fix. Aggregate qualification is explicitly scheduled below. Keep source/build identity in the result; do not inherit old passes.

Keep completed entries short: instance, outcome, source/build and check reference. Put detailed logs in existing artifacts/build notes and historical detail in Git; do not grow another checkpoint narrative inside this file. No new validator family, numbered evidence version, test-count target or evidence-only progress claim. No automatic scope deferrals.

## Current task and next queue

**Completed: PLAN — replace the sprawling roadmap with bounded tasks (2026-10-17).** Owner: primary agent. All 36 parent outcomes are mapped; the original requirements are preserved verbatim apart from relative-link rebasing; local link targets, incoming anchors and formatting checks pass. Independent review approves coverage and bounded acceptance. This documentation delivery changes no game behavior and needs no new build. **No implementation child is currently selected.** Next action: fill the LINUX-BUNDLE task card before implementation.

The following is a proposed execution order after PLAN, not permission to combine the rows into one job. Select and fill one task card at a time. Estimates below are planning ranges, not promises; reassess after the first probe.

| Order / instance | Status and dependency | Concrete result and stopping check | Initial effort |
| --- | --- | --- | --- |
| 1. LINUX-BUNDLE[managed installer] | READY; existing standalone manager is delivered | Include the managed installer in the Linux archive so installation needs no repository checkout. Extend `export_linux_candidate.sh` and existing export/installer tests; preserve support for existing five-member archives and allow only the explicitly named added member. Stop at successful archive install/update/uninstall, saved-data preservation and exact ELF identity checks. | 1–3 hours implementation and local checks; export time separate |
| 2. BASE-DIAG[Rime pad-controls second scenario] | READY; preserve original suite 300s and return-walk 18s limits | Identify the first incomplete production boundary in the second scenario using one bounded instrumented run of `tests/game_flow_rime_client_pad_controls_test.gd`. Stop with a concrete owner/fix task or a demonstrated external blocker, not another full audit. | One probe plus analysis, about 30–60 minutes |
| 3. SETTINGS-INPUT[original artifacts] | WAITING; original runner, saved profile and raw logs unavailable | Recover the exact originals from their custodian, or record the precise missing-artifact handoff. A substitute cannot close the original Gate C. Stop at recovered identity/paths or a named external dependency. | Bounded inventory already done; external wait unknown |
| 4. SCOPE-LIMIT[session capacity] | DEFINE; existing configured clients are not accepted player limits | Propose the supported player count and per-craft seat/role limits against existing runtime definitions and tests; list the exact decision required. Stop at a finite decision record and the acceptance instances it enables. No invented approval. | 30–60 minutes for proposal; decision wait separate |

## Baseline and ordinary controls

<a id="remaining-tasks-to-complete-the-project"></a>
<a id="0-fix-the-release-scope-and-assign-the-completion-work--all-phases"></a>

Scope: original §0–1 and retained milestones; Phases 2, 9 and 10.1. These are separate tasks, not a requirement to finish the whole baseline before delivering one repair.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| SCOPE-DECISION[one unresolved roster/limit] | DEFINE; production roster | Resolve one finite omission or propose one explicit scope decision with affected original promises. Stop at recorded decision or named owner input; no silent deferral. |
| PLAN-ASSIGN[one selected child] | READY; selected task | Fill the task card, owner, dependency, actual check and estimate. Stop when that child is executable; do not manufacture a release date from task counts. |
| BASE-DIAG[one failing suite] | READY; failure table below | One hypothesis/probe identifies the first failing boundary and production owner, or a specific blocker. Stop before unrelated diagnostics. |
| BASE-FIX[one reproduced defect] | GATED on diagnosis | Change the runtime/content owner and pass the affected original check without relaxing limits. Stop after relevant integration and required checkpoint; full matrix is MATRIX. |
| GUIDED[chosen combined package] | READY; exact package | Pass original Guided ordinary-input route 3/3 in fresh processes/profiles, unchanged shutdown timing. Stop at those three runs; old e085 passes remain source-specific. |
| SANDBOX[recovery-walk/reuse boundary] | GATED on one diagnosed fix | Complete the original all-nine-craft/station/combat/crash/recall/reuse route at its original 300s cap, without rescue. Preserve all 54 waypoints, eight initial excursions and occupied-berth criteria; stop on complete route or first concrete failure. |
| SETTINGS-INPUT[original artifacts] | WAITING on runner/profile/logs | Recover exact originals and identify their provenance; otherwise leave acceptance blocked with a precise handoff. No substitute promotion. |
| SETTINGS-RUN[original route] | GATED on recovered inputs and any focused fix | Complete original Settings/re-entry route, including gamepad return and intended mouse observation. Writer-only success is insufficient. Stop at original route result. |
| LIFECYCLE[chosen candidate] | READY; implementation already delivered | Run existing four-cycle `lifecycle_phantom_geometry_test.gd` and twelve-cycle `long_session_soak_test.gd` unchanged on selected source/package. Stop at those checks; fix a demonstrated defect separately. |
| CONTROL-FIX[one observed input/help defect] | GATED on reproduction | Correct one camera, steering, braking, hover, landing, prompt or tutorial problem. Demonstrate the same ordinary-input action before/after; stop after focused route and checkpoint. |

The last full matrix's eleven failed suites are below. `BASE-DIAG` selects **one** row, never all rows in one assignment. Later checks are historical scoped facts, not final baseline acceptance.

| Suite / exact existing filename under `tests/` | Last known boundary / next justified action |
| --- | --- |
| `bulwark_game_flow_registration_test.gd` | Original 300s timeout; isolate first incomplete registration boundary. |
| `cargo_delivery_production_integration_test.gd` | Full matrix timed out; later 418 source/package completes 124 assertions. Include in next combined matrix; do not rerun unchanged isolated merely because the older matrix failed. |
| `cinder_convoy_session_save_restore_test.gd` | Legacy Reset repaired; full suite still exceeds original 300s. Diagnose the next incomplete boundary. |
| `cinder_patrol_session_save_restore_test.gd` | Original 300s timeout; one-boundary diagnosis required. |
| `cinder_race_session_save_restore_test.gd` | Original 300s timeout; one-boundary diagnosis required. |
| `game_flow_ember_surface_presentation_integration_test.gd` | Original 300s timeout; separate setup from first incomplete integration boundary. |
| `game_flow_scan_durable_recovery_test.gd` | Half-second retry fixed; later full suite still times out after 96 printed passes. Diagnose remaining boundary. |
| `session_recovery_resume_offer_test.gd` | Original 300s timeout; one-boundary diagnosis required. |
| `game_flow_rime_client_pad_controls_test.gd` | Latest isolated first scenario completes, return 17.283s under 18s; second scenario exceeds suite 300s. Diagnose second scenario. |
| `network_emberline_bolt_test.gd` | Late-peer startup/retry failure at original 44/45s boundary. Identify startup/protocol boundary before a runtime fix. |
| `station_light_overlap_census_test.gd` | Historical expected rows/environment unresolved; mismatch repeats on its own freeze. Recover measurement basis before changing expectations; never replace hashes just to pass. |

## Station, craft, combat and presentation

Scope: original §2 and §7; Phases 1, 3–6 and 10.3. A component pass does not close a whole craft or station.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| HIST-CLAIM[one identity/topology claim] | WAITING where source evidence is missing; otherwise DEFINE | Resolve one Torrent B5/Zenith B7 provenance or continuity claim, Zenith naming, Arrow/Jovian identity, or station adjacency/scale/version/ladder relationship. Record supported facts, source views and unknowns. Stop at a bounded specification or exact external evidence request. |
| STATION-MODULE[one supported module/interaction] | GATED on evidence/specification | Build one justified room/connection, or climb interaction only if required by resolved ladder scope. Ordinary walk/Interact reaches it; visible structure and collision agree; preserve berth/hull clearance. Stop after that module and checkpoint. |
| STATION-ROUTE[one named branch] | READY for implemented branch | Walk Central, Aft, Habitat, Freight, Fleet Dock, Annex, Observation, Salvage or evidence-permitted VIP as one instance. Use existing station playability/interaction routes. Stop at complete branch or first reproducible blockage; do not add unsupported topology. |
| STATION-ART[one actual finding] | GATED on identified view/defect | Replace one placeholder or correct one room/furniture/material/signage defect. Compare fixed player-height views and affected walk/collision/berth budgets after streaming/rebase. Stop at that finding. |
| STATION-LIFE[one behavior] | READY for authored tow/gantry/service-arm/patrol routes | Qualify one Central tow, Freight gantry, Aft service arm or Habitat patrol behavior in ordinary play with `station_operations_activity_test.gd` as applicable. Repair only a demonstrated issue; do not replace delivered rails. |
| CRAFT-ART[one craft/component] | GATED on design/evidence and one named finding | Finish one hull, cabin/access, character animation, material or LOD component. Check authored role readability, boarding/clearance and affected gameplay-distance views/budgets. Stop at the component and checkpoint. |
| CRAFT-ROLE[one craft/role] | READY for implemented role | Complete ordinary walk/Interact/sit/action/stand/exit and appropriate moving-craft recovery. Reuse existing role tests; do not reimplement delivered roles. Stop at the named route. |
| COMBAT-SLICE[one craft/weapon/encounter] | GATED on named supported scenario | Exercise its applicable hit/miss/occlusion, refusal/ammo, damage/repair, destruction/regeneration and return to use through existing owners. One weapon/encounter per assignment; stop after its original scenario and checkpoint. |
| ART-FINDING[one view/effect/transition] | GATED on concrete finding | Fix one whole-game art-direction defect in UI, effects, lighting, animation or transition. Preserve gameplay readability and budgets; compare the same before/after view and affected route. Stop at that finding, not an unbounded art pass. |
| ORIGINAL-SPEC[one missing craft] | WAITING on evidence or explicit interpretation decision | Produce one bounded craft specification using supported facts and honest unknowns; record external dependency if insufficient. Stop before invented historical claims or unapproved interpretation. |
| ORIGINAL-BUILD[one specified craft capability] | GATED on ORIGINAL-SPEC | Deliver one named capability through existing source-art/definition/berth/boarding/flight/weapon/role/damage/recovery owners, with focused scenario and checkpoint. Instantiate remaining capabilities separately; full craft acceptance still required. |
| CRAFT-ACCEPT[one completed craft] | GATED on all promised capabilities | Run that craft's full fleet scenario: access/roles/flight/combat/damage/recovery/reuse and art/limits. Stop at named craft result, not the entire fleet. |

Original fleet remains Torrent, Arrow, Jovian, Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia, Salyut and Zenith. Missing definitions: **Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia and Salyut**. Instantiate ORIGINAL-SPEC/BUILD/ACCEPT per craft. Four original-inspired candidates plus five modern designs do not finish the twelve-original commitment. Modern interpretations require explicit scope decisions and honest labels.

## Activities and planetary journeys

<a id="phase-8--nearby-world-and-activities"></a>
<a id="4-visitable-planets-with-complete-atmosphere-to-surface-loops"></a>

Scope: original §3, retained abandonment milestone and Phase 8/10.4 specifications. Shared journeys use WORLD-SHARED below, not a duplicate queue.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| ACT-HUD[Race, Patrol, Cargo or Convoy] | READY; one family selected | Verify reset/select/start and fresh-Main presentation against durable state; fix one actual discrepancy. Stop after that family's route, not all four. |
| ACT-WRITE[one activity/boundary] | GATED on uncovered failure boundary | Exercise one real write failure at ACTIVE, earned-unpaid, paid/reset or refused/reset; fresh process observes once-only durable rewards and usable recovery. Reuse existing lifecycle tests; stop at named boundary. |
| ACT-PLAY[one nearby activity] | READY for implemented content | Ordinary outbound travel, actual activity, reward and home return work at canonical distances. Stop after first full play or first reproduced defect; repetition/endurance is ACT-REPEAT. |
| ACT-REPEAT[one activity] | GATED on ACT-PLAY | Complete its existing repeated-use/endurance scenario with once-only rewards and clean actors/state. Stop at that scenario's original duration, not a new arbitrary loop target. |
| TRAVEL-LIMIT[one nearby route] | DEFINE; release scope decision | Establish proposed numeric ordinary-travel envelope and route conditions from design/runtime facts; obtain required decision. Stop at finite criterion, not an invented “agreed maximum.” |
| HULK[physical salvage/power/revisit] | READY; existing `abandoned_hulk_loop_test.gd` | Complete physical salvage and power restoration, then revisit with once-only cell/reward behavior. Stop at existing full scenario; do not inflate reward counts. |
| WORLD-CONTENT[one world/gap] | DEFINE if missing content not named | For Ember, Aurora or Rime, name one finite missing environmental/content behavior from the original specification and roster. Implement that behavior in a separate bounded child with ordinary surface interaction and checkpoint. Stop at specification or named behavior, not a new planet catalogue. |
| WORLD-SOLO[one world] | READY for implemented world; existing physical route | Complete canonical outbound, atmospheric descent, physical landing/exit/activity/reboard, ascent and home dock through ordinary controls. Preserve original route/physics limits; staged arrival is not acceptance. Stop at one world's full route or first defect. |
| WORLD-ABANDON[one world] | GATED on WORLD-SOLO route | Qualify delivered abandonment/home-return fixes in full integrated-source and packaged journey, including physical walking/docking/reuse. Existing ec457/6e1 scoped passes are not this full gate. Stop at named scenario. |
| WORLD-SAVE[one world/boundary] | GATED on named expected resume/safe-recovery contract | Save/reload or real interruption retains visit/survey/reward/reboard state once and returns to usable play. Stop at one boundary. Rime df862 staged/in-process 78-pass restoration is delivered; it does not qualify canonical journeys. |
| WORLD-EDGE[one world/case] | GATED on baseline route and scenario definition | One solo cancellation, refusal, failure, repeat visit or interruption case preserves physics, rewards and return to use. Stop at one case; shared late join/disconnect belongs to WORLD-SHARED. |

Route anchors include `tests/ember_transit_movement_soak.gd`, `tests/aurora_physical_return_soak.gd --aurora-full-roundtrip`, `tests/ember_abandon_return_manual_override_test.gd` and the existing Rime landing/survey routes. Resolve the exact existing command in the task card before running; never substitute a staged route for a canonical one.

## Multiplayer

<a id="phase-7--multiplayer"></a>

Scope: all twelve original §4 outcomes and retained ordinary-remote-crew milestone. Select one craft, role, channel or matrix cell; aggregate session and snapshot checks remain separate.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| NET-CAPACITY[one supported session profile] | GATED on SCOPE-LIMIT decision | Verify explicit player count, per-craft occupancy/roles and connection profile. Eight configured clients is not accepted eight-player support. Stop at one profile. |
| NET-CREW[one craft/role] | READY for implemented route | Independent authenticated ordinary crew walks, sits, performs role, stands/exits and survives applicable ownership/host/disconnect recovery. Use existing Jovian engineer, Halyard engineer/passenger or Bulwark gunner route tests. Stop at named role. |
| NET-POSE[one craft/operation] | READY; existing remote/craft-pose tests | Current and late peer see correct engine, station-frame pose and landing/dock presentation during one named operation. Use `network_remote_craft_pose_test.gd` / `network_craft_pose_station_frame_test.gd`; stop at operation. |
| NET-HELM[one supported action] | READY; `network_remote_pilot_helm_test.gd` | Real sampled local input reaches supported remote helm action and handback without stale ownership. Stop at original action/recovery scenario; synthetic command-only checks cannot close input prerequisite. |
| NET-STALL[existing host-stall route] | READY; stable independent processes | Original 600-step stalls and original 2s action limits recover honestly without false completion. Stop at route result; no clock/deadline relaxation. |
| NET-LAND-DIAG[intermittent second landing] | DEFINE; original failure retained | One probe identifies the first failed boundary in second landing/reuse. Stop with owner/fix or blocker; no speculative clock rewrite. |
| NET-DOCK[one craft] | GATED on relevant fix if needed | Remote landing/dock, ordinary disembarkation, reboard and repeat departure succeed. Stop at one craft's existing route. |
| NET-DAMAGE[one craft/role scenario] | READY; existing damage/respawn integration tests | Peer presents hull/component damage, repair, destruction and regeneration coherently, then returns to usable role/craft. Stop at one scenario; preserve authority and ownership. |
| NET-ACTOR[one channel/lifecycle] | READY for implemented channel | Convoy, Torpedo Run, Picket or Emberline instance covers its named travelling actor/projectile live/dead/reset, late join, disconnect or solo-restoration boundary. Use existing authority/Emberline tests. Stop at one lifecycle case, then schedule uncovered cases separately. |
| NET-BROWSER[one ordinary menu flow] | READY; discovery/binding tests | Discover/refresh/select/join/disconnect/retry from normal menus. Separate stale, full, unreachable, cancel and controller cases into individual instances; stop at selected flow. |
| NET-BUDGET[all-nine forced-full snapshot] | READY; existing budget owner | Measure original full-snapshot publication/byte budgets across supported nine-craft load; movement-only bytes do not qualify. Stop at this aggregate budget result; do not repeat for every NET-POSE task. |
| NET-ENDURANCE[one supported profile] | DEFINE exact independent-process command, then GATED on stable baseline | Run original 30-minute two-client moving-interior session with declared latency/profile and no ownership/state leaks. `network_moving_interior_latency_test.gd` is an anchor, not an invented substitute command. Stop after original duration and clean closure. |
| WORLD-SHARED[one world/case] | GATED on supported crew/profile and baseline dependencies | Ordinary independent remote crew completes the selected canonical case, including actual outbound/return, activity/reward/save and appropriate usable recovery. Preserve focused 300s/canonical 900s and physical landing 120s where specified. Stop at one matrix cell. |

WORLD-SHARED instances: **Ember, Aurora, Rime**, each with **baseline full outbound/return, late join, disconnect/reconnect, pilot loss, cancellation, real interruption, repeat visit**. Each cell is a separate task and must name participants, initial state, ordinary-input route and durable reward/return criteria before execution. The baseline includes activity and save behavior; failure cases do not inherit a staged baseline. Use existing `tests/network/halyard_network_shared_planetary_cruise_test.gd` and applicable world/landing tests. Missing exact case coverage becomes a bounded DEFINE child, not a claim that the anchor already covers it.

## Performance, controls, accessibility and audio

Scope: original §5, Phases 9 and 10.2–10.3. Software rendering, VM and remote-display behavior do not qualify native target GPU performance.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| PERF-MACHINE[one minimum/target profile] | WAITING on representative hardware if unavailable | Bind declared CPU/GPU/RAM/display/driver profile to an actual isolated test machine. Stop at available machine identity or exact missing resource; never infer native performance from llvmpipe. |
| PERF-ROUTE[one missing benchmark route] | DEFINE; named required scenario | Specify and implement one missing fleet/cabin/combat/surface/repeat route through existing benchmark runner. It currently supports only `station_embodied_route` and `nearby_sector_ship_flight_route`, with launcher running both. Stop at executable route/selection and focused check, not a new benchmark system. |
| PERF-RUN[one machine/scenario] | GATED on machine and executable route | Original warmup at least 3,600 frames/60s; measurement at least 18,000 frames/600s. At 1080p High, p95 ≤16.7ms, p99 ≤33.3ms, no post-warm frame >100ms, peak working set ≤4GiB, plus required actual GPU/VRAM and streaming/transient budgets. Stop at that measured scenario; retain failure. |
| PERF-FIX[one measured hotspot] | GATED on demonstrated production cost | Fix the identified runtime/rendering owner; repeat the affected measurement and behavior check. Stop at measured effect and checkpoint; no census-only progress. |
| INPUT-DEVICE[one device/route] | WAITING on physical device if absent | Ordinary full selected route with actual keyboard/mouse or controller, including lifecycle/planetary control as applicable. Existing physical-sortie, lifecycle and controller-only expedition tests guide scenario. Stop at selected route; synthetic events cannot qualify physical hardware. |
| INPUT-REMAP[one setting/binding] | READY for automated persistence; physical confirmation separately | Remap/apply/restart retains binding and usable menus/gameplay, with conflicts/recovery as specified. Reuse runtime remapping/presenter/contract tests. Stop at one case. |
| ACCESS-VIEW[one view/scale/aspect] | READY for isolated capture; relevant hardware separately | Verify readability/focus/clipping for named view at minimum/default/maximum scale and one of 4:3, 16:9, 16:10, 21:9, 32:9. Instantiate each required cell separately, using existing runtime accessibility tests. Stop at one view/cell or fixed finding. |
| ACCESS-COMFORT[one route/option] | READY; existing runtime options | Verify one reduced-motion, flash, color-safe or caption behavior in actual route and after restart as required. Stop at named option/scenario and any focused correction. |
| AUDIO-CONTENT[one cue/transition gap] | GATED on identified missing behavior | Author/fix one production ambience/music/effect transition and run existing music state/activity/orbit/surface integration checks with Dummy audio. Delivered Aurora coast is not a new gap. Stop at cue/transition and checkpoint. |
| AUDIO-MIX[one real-output scenario] | WAITING on explicit audible-test authorization and output device | Check actual mix/levels/transitions for selected scenario, fix concrete issue and repeat it. Stop at scenario result; automated Dummy output does not qualify real audio. Owner-excluded human review does not become a mandatory approval gate. |

## Recovery, packages, captures and release

Scope: original §6 and retained installed-interruption milestone. Final-candidate qualification is scheduled once dependencies are met, not attached to every child.

| ID / one instance | Status / prerequisite | Result and acceptance; stop boundary |
| --- | --- | --- |
| RECOVERY-CONTRACT[one context] | DEFINE if resume/safe-recovery outcome ambiguous | Name expected durable boundary, supported player/craft/berth/seat state and route back to normal play. Distinguish promised pose resume from safe-home recovery. Stop at executable contract, not expanded restoration promises. |
| RECOVERY-FIX[one reproduced failure] | GATED on contract/reproduction | Correct existing save/runtime owner; preserve valid/unsupported data, secret-free diagnostics, ownership and once-only rewards. Use real file/fresh process. Stop at affected check and required checkpoint; ACT-WRITE covers activity boundaries without duplicate assignment. |
| RECOVERY-KILL[one activity/context/package] | GATED on contract and exact Linux install/archive | Own the process, interrupt using actual OS SIGKILL, restart a distinct process and check durable boundary, usable recovery, rewards and actor closure. Select pilot, cabin, rest, crew, docking, activity or planet context individually. ca0 Convoy four-context passes remain source-specific; no airborne-pose claim. Stop at one context. |
| PACKAGE-WIN[one clean checkpoint] | READY after meaningful integrated change | Existing safe clean export: focused checks, exact EXE/ZIP/notes identity, embedded PCK/PE metadata and silent isolated Windows-payload startup through supported Linux-engine workflow. Require exit 0 and `STARTUP_MENU_READY_OK`; fixed quit frames are insufficient. Stop at exact package checks. Native Windows execution remains excluded/held. |
| PACKAGE-LINUX[matching checkpoint] | GATED on selected clean source | Export matching ELF/archive; existing inventory checks, exact member bytes/modes, direct and archive-extracted strict startup. Stop at exact artifact checks. |
| INSTALL-WIN[one candidate] | GATED on packages | Build matching installer with existing NSIS tooling and inspect exact extraction/build identity and applicable non-execution checks. Native installation/execution is excluded; do not bypass antivirus. Stop at artifact checks, with unperformed runtime factual NOT_RUN. |
| LINUX-BUNDLE[managed installer] | READY; first next-queue task | Ship the delivered manager in the archive, preserving explicitly supported old/new bundle contracts. Stop at archive install/update/uninstall, exact binary and protected-data checks using existing tests. |
| INSTALL-LINUX[one transaction] | READY for managed per-user install | One clean install, old-to-new upgrade, rollback, retained/corrupt data handling or uninstall transaction preserves saves/unrelated files and exact owned artifacts. Existing seven manager tests and real archive checks already pass on their source. Select an uncovered/new-candidate transaction, not redundant reimplementation. Abrupt termination/power loss remains separately unqualified. |
| LINUX-DESKTOP[one entry/ordinary route] | WAITING on clean isolated graphical Linux session if unavailable | Launch actual installed desktop entry or direct ELF and complete ordinary route; test each separately. Inert GIO argv probe and headless startup are insufficient. Stop at entry+route result; no implied native GPU/input/audio qualification. |
| CAPTURE[one required registry ID] | GATED on frozen candidate and runnable environment | Run unchanged registered harness with isolated X11/Dummy, verify declared source and exact images, inspect original-resolution output and fix actual finding separately. Stop at one set. Human stages are excluded; hardware gates separate. See blocked sets below. |
| RIGHTS[one asset/source family] | GATED on available provenance/rights information | Record licensing/redistribution disposition for the named family. Preserve owner's settled creator-permission account without claiming a written grant or asking again. Stop at clearance or exact missing external document. |
| SIGN[one exact artifact family] | WAITING on trusted certificate/credentials outside repository | Use existing `sign_windows_artifacts.sh` workflow to sign/verify game, installer and uninstaller, expected publisher and exact distributed bytes. Development signing cannot qualify. Stop at trusted signatures; native Windows execution is not required. |
| MATRIX[one frozen integrated candidate] | GATED on targeted repairs/integration | Clean import and existing unfiltered `--mode all` matrix at original suite/long caps, no exclusions, including isolated graphics. Stop at complete result; failures become named child fixes. Do not rerun whole matrix for every small change. |
| FINAL-RECONCILE[one candidate] | GATED on required content, matrix and applicable platform/device/performance/audio/endurance/install/capture/signing results | Reconcile all original promises and exact candidate results with existing `release_candidate.py`, candidate record and `SHA256SUMS`. Zero open P0/P1, explicit reviewed P2/residual-risk dispositions including RENDER-001 where applicable. Changed source invalidates affected qualification; owner exclusions stay excluded. Stop at actual complete or named unmet gates, never a new evidence layer. |
| DISTRIBUTE[accepted candidate] | GATED on FINAL-RECONCILE and authorized destination/publication | Publish exact qualified artifacts/checksums and concise player-facing notes using existing release flow. Stop after byte identity and download checks. No Downloads copy or public publication implied by local checkpoints. |

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

Registry/commands: [graphical harness inventory](docs/GRAPHICAL_HARNESS_INVENTORY.md) and `tools/release/graphical_harness_registry.json`. Earlier 3/13 source/image declarations are source-specific, not a current-candidate pass. **Caption production and station operations are blocked on this software-Vulkan environment:** original-cap cold compilation stalls in Godot's built-in Forward+ clustered COLOR_PASS ubershader. Bounded native stack/SPIR-V diagnosis is complete; material owner remains unknown. No custom-shader rewrite, quality/deadline reduction, unchanged cold rerun or registry promotion is justified. A concrete changed environment or supported mitigation is needed before another probe. Preserve RENDER-001 and original failures.

## Coverage of the original remaining outcomes

These are **36 parent outcomes**, not 36 executable jobs. They remain open until all applicable named instances and original acceptance conditions hold. This crosswalk is the guard against losing scope during the rewrite; it is not an extra evidence system. Original wording and all ten phase specifications remain in the preserved reference.

| Original parent outcome | Active task families |
| --- | --- |
| Finish final integrated-source and packaged physical abandonment acceptance | WORLD-ABANDON, WORLD-SOLO, PACKAGE-WIN, PACKAGE-LINUX |
| Complete matching installed interruption/recovery on the accepted integrated build | RECOVERY-CONTRACT, RECOVERY-KILL, INSTALL-LINUX, FINAL-RECONCILE |
| Complete canonical-distance outbound and return with ordinary remote crews for Ember, Aurora and Rime, including activities/rewards/save, late join, disconnect, pilot loss, cancellation, interruptions and repeat visits | WORLD-SHARED (each world/case), NET-CREW, RECOVERY-KILL |
| Record the final shipped roster and supported limits | SCOPE-DECISION, NET-CAPACITY, ORIGINAL-SPEC |
| Assign owners, dependencies and estimates to the remaining deliverables | PLAN-ASSIGN and the per-session task card |
| Qualify and package current source | BASE-DIAG/FIX, MATRIX, PACKAGE-WIN/LINUX |
| Complete the normal-controls core playthrough and fix observed blockers | GUIDED, SANDBOX, SETTINGS-INPUT/RUN, LIFECYCLE, STATION-ROUTE, CRAFT-ACCEPT |
| Complete control and tutorial tuning | CONTROL-FIX, INPUT-DEVICE, INPUT-REMAP |
| Finish station layout and final presentation | HIST-CLAIM, STATION-MODULE/ROUTE/ART/LIFE |
| Finish fleet art, character animation and role acceptance | CRAFT-ART, CRAFT-ROLE, CRAFT-ACCEPT |
| Complete the combat-and-recovery slice across supported craft | COMBAT-SLICE, CRAFT-ACCEPT, NET-DAMAGE |
| Complete the whole-game art-direction pass | ART-FINDING, STATION-ART, CRAFT-ART, CAPTURE |
| Close the complete nearby-activity roster | ACT-HUD/WRITE/PLAY/REPEAT, TRAVEL-LIMIT, HULK |
| Qualify each implemented world's full physical round trip | WORLD-SOLO/ABANDON/SAVE/EDGE |
| Resolve remaining planetary content and presentation gaps | WORLD-CONTENT, ART-FINDING |
| Close remaining fleet/crew replication gaps | NET-CREW, NET-CAPACITY |
| Complete remote engine and landing/dock presentation | NET-POSE, NET-BUDGET |
| Complete supported remote helm actions and their real local-input prerequisite | NET-HELM, INPUT-DEVICE |
| Qualify honest remote-command recovery after host simulation stalls | NET-STALL |
| Complete remote landing, post-dock disembarkation and craft reuse | NET-LAND-DIAG, NET-DOCK |
| Qualify fleet hull/component damage, repair, destruction and regeneration presentation across supported craft and roles | NET-DAMAGE |
| Qualify the implemented convoy actor lifecycle in native gameplay | NET-ACTOR[Convoy] |
| Qualify Torpedo Run authority and solo recovery | NET-ACTOR[Torpedo Run] |
| Finish remaining travelling-weapon and moving-crew integration | NET-ACTOR[Picket/Emberline], NET-CREW, WORLD-SHARED |
| Qualify the production server-browser and connection flow | NET-BROWSER |
| Pass multiplayer and endurance acceptance | NET-ENDURANCE, NET-CAPACITY, NET-BUDGET |
| Resolve planetary travel during multiplayer explicitly | WORLD-SHARED (each world/case) |
| Benchmark and optimize on representative native hardware | PERF-MACHINE/ROUTE/RUN/FIX |
| Complete real-device controls and accessibility review | INPUT-DEVICE/REMAP, ACCESS-VIEW/COMFORT |
| Finish authored audio and the real-device mix pass | AUDIO-CONTENT/MIX |
| Finish production crash and save recovery | RECOVERY-CONTRACT/FIX/KILL, ACT-WRITE, WORLD-SAVE |
| Qualify installation, updates and supported desktop platforms | PACKAGE-WIN/LINUX, INSTALL-WIN/LINUX, LINUX-BUNDLE/DESKTOP |
| Complete all required graphical capture gates | CAPTURE (each required registry ID) |
| Complete release licensing, trusted signing and distribution | RIGHTS, SIGN, DISTRIBUTE |
| Run final release acceptance on the exact distributed candidate | MATRIX, FINAL-RECONCILE, DISTRIBUTE |
| Resolve historical reconstruction dependencies and deliver the remaining researched fleet | HIST-CLAIM, ORIGINAL-SPEC/BUILD, CRAFT-ART/ACCEPT, STATION-MODULE |

## Original phase gates and completion

<a id="phase-1--research"></a>

[Phase 1 research](docs/history/ROADMAP_SCOPE_20261017.md#phase-1--research), [Phase 2 vertical slice](docs/history/ROADMAP_SCOPE_20261017.md#phase-2--vertical-slice), [Phase 3 station](docs/history/ROADMAP_SCOPE_20261017.md#phase-3--shipyard-expansion-bounded-operational-lattice-slice-settled-full-phase-incomplete), [Phase 4 original fleet](docs/history/ROADMAP_SCOPE_20261017.md#phase-4--original-fleet), [Phase 5 expanded fleet](docs/history/ROADMAP_SCOPE_20261017.md#phase-5--expanded-fleet), [Phase 6 combat](docs/history/ROADMAP_SCOPE_20261017.md#phase-6--expanded-combat-and-damage), [Phase 7 multiplayer](docs/history/ROADMAP_SCOPE_20261017.md#phase-7--multiplayer), [Phase 8 nearby world/activities](docs/history/ROADMAP_SCOPE_20261017.md#phase-8--nearby-world-and-activities), [Phase 9 release](docs/history/ROADMAP_SCOPE_20261017.md#phase-9--release-polish), and [Phase 10 final quality/planets](docs/history/ROADMAP_SCOPE_20261017.md#phase-10--final-quality-push-and-visitable-planets) retain their specifications and exit gates.

Project completion requires each original promise to be delivered and accepted, or explicitly deferred by the owner beside that promise; all required final-candidate gates must hold and distributed artifacts must match the tested bytes. No parent is closed by this reorganization. Report progress as named playable/runtime/release outcomes, completed task instances and actual blockers. Do not report a percentage from task rows, test totals, schema versions or commits.

## Working constraints

Follow [AGENTS.md](AGENTS.md). Every automated Godot invocation uses `--audio-driver Dummy`; use headless or isolated displays, explicit `--display-driver x11` under Xvfb and an independent abort/cleanup path. Do not use the owner's desktop or audible output without explicit authorization. Keep scratch, helpers and worktrees under `/srv/mudds-work/`; remove completed temporary worktrees after verifying integration and preserve unique uncommitted work/raw failures. Never enable/dispatch hosted CI. Do not use native Windows/Wine under the execution hold. Checkpoint artifacts belong in repository `builds/`, not Downloads.
