# Completion scope and production roster

This is the working roster for [roadmap task 0](../ROADMAP.md#0-fix-the-release-scope-and-assign-the-completion-work--all-phases), reconciled against the current runtime on 2026-10-17. It retains the original promises and remaining work; it does not reduce scope, set a date or close phase gates.

The latest local Windows and Linux checkpoints share clean source `3e0ee11c8b14612fd29a109d485d25d4d3cf8de5` ([Windows notes](../builds/windows/MuddsShipyards-3e0ee11-notes.txt), [Linux notes](../builds/linux/MuddsShipyards-3e0ee11-linux-notes.txt)). Station dressing reference scans retain fresh per-instance getters and dynamic hooks while reusing script declarations only within the scan. Twelve alternating actual-Main scans preserve all 2,811 protected node identities and reduce median scan CPU 289.603→215.213ms (25.69%); this does not establish overall startup or native-hardware performance. Five source suites pass, including station surfaces and the unchanged service route; the matrix records 176 passing assertions plus 52 reported by the dressing fixture's existing named-count sentinel. Actual Windows-payload checks pass 231 assertions, three strict startups pass, and all 1,515 Windows/Linux payload entries agree. Fresh EXE/ZIP/ELF/archive are local under `builds/`. The full matrix on this source is NOT_RUN; current-source full regression and normal-controls acceptance remain open.

The earlier `e87c326a4` Linux ELF with external caller `79eb3c6ea`, SHA-256 `a63a3dd9c35d91f9985e5cf4d3b731c081a1a2ecd13e9178fc66e2532f61c991`, demonstrates all 54 original station waypoints in order, all eight required craft cycles before crashing, an actual terminal Light impact at 119.899m/s, same-player production recall and exact occupied-berth regeneration. All 5,537 raw observations retain the same player/all nine craft identities/default samplers/authored tuning. **Full Sandbox remains FAILED / NOT_COMPLETED:** the original 300s deadline expires during the physical return walk before reuse (306.175s including cleanup), zero diagnostics and independent input/process cleanup. The caller clears the previously observed geometry contacts and avoids redundant stops/backtracking; game physics/tuning/timings and waypoint radii remain. Eighteen focused caller tests and bounded independent reviews pass. Raw runs/callers remain in `artifacts/checkpoint-e87c326/`. Same-package Guided 3/3 in 51.406/50.927/51.932s retains its exact earlier caller `e6a10f98519a25fa6aad11ea2faf6eb8525176f1e5347498539928a7c15d5a62`; it does not qualify the newer source. Full Gate C, Settings/re-entry, current-source full regression and all ten phase gates remain open. Native Windows/GPU/controller/audible/human acceptance remains NOT_RUN, and hosted CI remains disabled. Earlier `c26e2c13c` and `e159ac3c5` outcomes retain their named sources and views.

The repaired native Linux ordinary-input sortie driver completes three
consecutive fresh-process/profile sorties on the same exact `e159ac3c5` ELF in
49.322/50.975/49.311s. Every run includes four practice targets, interceptor
combat, strict home-berth landing, 91 neutral authored-60Hz shutdown frames
(1.516667 physics seconds) and same-player physical exit, with zero diagnostics
through shutdown and complete input/process cleanup. The driver fixes an
observed braking deadlock and rejects previously ignored engine diagnostics;
game physics, default sampling, authored tuning, route and 300s cap remain.
This meets the Guided 3/3 subcriterion on that named package. Full Gate C remains
open for Sandbox and Settings/re-entry; all-nine-craft and final combined-source
acceptance remain required. These isolated-Xvfb/dummy-renderer OS-input runs do
not establish native GPU/device or graphical acceptance. Those three passes qualify that earlier package only. Raw runs are `artifacts/native-sortie-diagnostics/`
and `artifacts/guided-e159ac3/`.

Complete Settings acceptance remains open. The original writer passes. The latest source restart completes keyboard-and-mouse flight and gamepad outbound/control probes before the unchanged 300-second cap during gamepad return; the earlier d750 Windows payload also times out. Both failures remain retained. The original runner, saved profile and raw logs referenced in the bug ledger are absent from this workspace and its available cache/storage locations as of 2026-10-17; their described results cannot be replayed here until recovered. The pending correction to mouse-input observation remains unverified. A substitute scenario must not inherit the original Gate C acceptance.

The latest complete unfiltered regression is the frozen `7f9627e5ce4a551e20a9528415521bfb9eb3ab28` result: **FAIL, 1,032 PASS / 13 FAIL across 1,045 suites**, with 41,810 recorded passing assertions. Run `20261017T031340Z-7f9627e` completed with original deadlines, unchanged source/cache and verified result log hashes; eight timeouts and five other failed suites remain retained. Later focused fixes and checks retain their named sources in [ROADMAP](../ROADMAP.md); no green full combined-source matrix is claimed. The earlier frozen `636814418` result remains FAIL (1,027 PASS / 18 FAIL). The latest original full Rime controls run, `083b0ebae`, passes the first scenario and its formerly failing return leg, then times out at the unchanged 300-second cap during the second scenario. Subsequent component savings do not establish complete Rime acceptance. Earlier `70a3c1bdc` (1,038/1,045) and interrupted `064f573b2` matrices remain historical. Complete ordinary-controls, graphical and applicable hardware qualification remain open; earlier source/package checks cannot qualify newer source.

One isolated original cargo delivery integration run on production source `135b4fa6a`, with temporary read-only timing markers, passes all 120 assertions under the unchanged 300-second cap. Its final fresh Main returns at engine wall time 251.384s; all 14 repeated disk-Main calls spend 154.480s attaching/starting and 32.641s in the original frame waits. The earlier full-matrix timeout does not reproduce in this isolated run. This does not establish its cause, qualify a newer source or replace complete regression; the instrumentation is restored and no runtime behavior or deadline was changed.

GitHub CI stays disabled. Native Windows execution remains held after the Avast alert; the owner excluded mandatory native Windows validation and human playtesting/review. Historical NOT_RUN records remain factual.

Earlier `951efea7` coastal/defence and `61749efc` engineer results retain their source-specific scope in the [roadmap history](../ROADMAP.md). Integration is delivered; those earlier checks do not qualify the complete current ordinary remote-crew journey matrix. The retained `47ff` canonical Aurora arrival failure remains an investigation target until current-source evidence establishes otherwise. Fleet definitions and original-content gaps below remain unchanged.


Status vocabulary used in every table:

- **Implemented / awaiting acceptance (I):** production content or an owner exists; normal-controls, final-candidate package, recovery and relevant human/hardware acceptance remain required.
- **Missing implementation (M):** the named content or required integration is absent. A detached catalog or test fixture does not deliver it.
- **External dependency (E):** source material, physical review equipment/players or release credentials are needed. This does not erase implementation work.

There are no newly approved deferrals in this inventory. Nine flyable definitions, test totals and checkpoint counts are not project completion percentages. Native GPU, physical-device, audible and human gates remain `NOT_RUN` until performed for their actual candidate.

## Station routes and historical topology

The [production scene](../scenes/world/shipyard_world.tscn), [world owner](../scripts/world/shipyard_world.gd) and [route registry](../scripts/world/station_route_registry.gd) establish the implementation seams. Registry adjacency is non-metric and does not prove walking. Module paths below are relative to `scenes/world/modules/`.

| Requirement | Original phase | Production path or gap | Status | Next action and acceptance scenario |
| --- | --- | --- | --- | --- |
| Central berth, Arrow berth, launch gate and return apron | 2, 3, 10.3 | `shipyard_world.tscn`, `shipyard_world.gd` | I | On the final package walk from spawn, board, launch under the marked gate, return by ordinary assist, dock and exit; review collision, camera and readable minimum graphics. |
| Aft junction, two elevations and operations room | 3, 10.3 | `aft_junction_stack.tscn` | I | Walk the stairs, operate the door and board console, then return without jumping or rescue; verify signage and no fleet landing-envelope overlap. |
| Habitat connector, bunks and common room | 3, 10.3 | `habitat_spine.tscn` | I | Walk both directions, use rest and wake, visit the common room and recover after restart with usable controls; review the final packaged dressing. |
| Freight berth and source/destination terminals | 3, 8 | `jovian_freight_berth.tscn`, `cargo_source_terminal.tscn`, `cargo_destination_terminal.tscn` | I | Walk to each terminal, transfer real conserved cargo, reload the committed receipt and return to the same ship; rejected writes must not duplicate inventory. |
| Fleet comb and all shipped craft berths | 3–5, 10.3 | `fleet_dock_comb.tscn`, world-owned berth instances | I | Physically reach and reuse every shipped craft, retain separated voids and neighbour clearance, then review fleet overview and player-height routes. Dock 03's deferred marker is not a delivered berth. |
| Fabrication Annex repair-kit service | 3, 8 | `fabrication_annex.tscn` | I | Walk up and Interact to restock within the cap; repeat with unavailable/departed ownership and review normal/minimum readability. |
| Observation/logistics spur | 3, 10.3 | `observation_logistics_spur.tscn` | I | Traverse its connector and viewing route, return supported, and inspect camera/head clearance and guidance. |
| Salvage Terrace inspection manifest | 3, 8 | `salvage_terrace.tscn` | I | Inspect all three components through ordinary controls, reload the 3/3 manifest and revisit; no inventory/currency grant is implied. |
| VIP reception access and content | 3, 10.3 | `vip_reception_suite.tscn` | I | Walk to the suite and exercise reception interactions; review its complete route and identify any remaining locked landmark separately. |
| Remaining habitat, VIP, platform, ladder, regeneration, dock-arm and room relationships; broader exposed spine | 1, 3, 10.3 | [topology](research/STATION_TOPOLOGY.md); no authenticated complete historical floor plan | E + M | Resolve one relationship from registered source anchors before changing an original-labelled connection; implement a reversible module and prove continuous walking. Modern modules do not authenticate historical adjacency. |
| Station life beyond fixed service rails | 3, 10.3 | `scripts/world/station_operations_activity.gd`, world-owned service assemblies; no general autonomous logistics graph promised by these rails | I; broader content open | Review central tow, freight gantry, Aft service arm and Habitat patrol during walking/boarding; finish required living-station content through bounded reusable owners, without turning presentation into berth authority. |

## Fleet: original twelve and modern additions

The original Phase 4 promise is **Torrent, Arrow, Jovian, Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia, Salyut and Zenith**. Only four have definitions. Five modern additions bring the current production roster to nine, not twelve recreated originals. [GameFlow](../scripts/game/game_flow.gd) and `assets/ships/` supply the runtime roster; [ship evidence](research/ship_evidence_matrix.json) keeps dated identity claims separate from playable content.

Every craft acceptance includes ordinary walk-up → board → launch → role/weapon → damage/repair or destruction/recovery → strict supported landing → exit → reuse, plus cross-craft switching and Main re-entry. Hull, cabin, collision, camera/muzzle clearance, audio and lateral handling require review on the final package.

| Craft | Original phase | Definition under `assets/ships/` or gap | Status | Concrete next action / acceptance scenario |
| --- | --- | --- | --- | --- |
| Torrent | 2, 4, 6 | `torrent_provisional.tres` | I + E | Complete guided first sortie/combat/return and finish source-bounded reconstruction; resolve B5 recording/build and 2009 continuity before stronger historical wording. |
| Arrow | 4, 6 | `arrow_provisional.tres` | I + E | Accept reconnaissance handling, two-pod presentation and full craft loop; obtain tied name/model views before replacing provisional identity. |
| Jovian | 4, 6–8 | `jovian_provisional.tres` | I + E | Accept physical cabin/hold, conserved freight transfer and engineer repair in solo/crew play; obtain tied name/model views for stronger reconstruction claims. |
| Zenith | 4, 6 | `zenith_b7_observed.tres` | I + E | Accept interceptor trade-offs and full loop; keep B7 source-core review within registered frames and resolve provenance for stronger claims. |
| Titan | 4 | No definition | M + E | Establish Titan's evidence boundary, then deliver its own hull/interior, definition, berth, handling and role through the fleet pipeline; accept the full craft loop. |
| Vortex | 4 | No definition | M + E | Establish Vortex's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Paradox | 4 | No definition | M + E | Establish Paradox's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Katana | 4 | No definition | M + E | Establish Katana's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Predator | 4 | No definition | M + E | Establish Predator's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Dynamic | 4 | No definition | M + E | Establish Dynamic's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Utopia | 4 | No definition | M + E | Establish Utopia's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Salyut | 4 | No definition | M + E | Establish Salyut's evidence boundary and deliver its own complete craft/berth; accept full loop and distinct handling. |
| Halyard crew transport | 5–7 | `halyard_new_design.tres` | I | Accept passenger, gunner, engineer and loadmaster routes with moving-cabin sit/stand/reseat, real role effects and migration/disconnect recovery. |
| Bulwark heavy gunship | 5–7 | `bulwark_new_design.tres` | I | Walk to gunner, aim/fire at a real damageable target, stand/reseat and recover after ownership transfer/destruction. |
| Cinder Light Interceptor | 5, 6 | `cinder_light_interceptor_new_design.tres` | I | Accept specialist handling, repeater/cooldown, component damage/repair and return/reuse. |
| Cinder Cargo Hauler | 5–8 | `cinder_cargo_hauler_new_design.tres` | I | Accept physical ramp, Loadmaster readiness, Navigator route hints, cargo and weapon play; readiness receipts must not grant cargo or reward authority. |
| Cinder Long-Range Bomber | 5, 6 | `cinder_long_range_bomber_new_design.tres` | I | Accept finite payload, travel-time hit/miss, crew/navigation, landing and recovery without restoring spent payload incorrectly. |

**None of the eight missing original craft definitions is delivered.** The modern craft are additional scope. Legally available higher-resolution source material remains a Phase 1 dependency; this document does not reopen the creator/rightsholder question settled by the owner in Phase 1.

## Combat opponents, weapons and damage

Opponent paths are under `scripts/ships/` with matching `scenes/ships/` scenes. The [scenario catalog](../scripts/combat/combat_scenario_catalog.gd) is detached; [encounter director](../scripts/combat/encounter_scenario_director.gd), [station defence host](../scripts/activities/station_defense_encounter_host.gd) and live actors own production effects.

| Requirement | Original phase | Runtime/content seam | Status | Next action and acceptance scenario |
| --- | --- | --- | --- | --- |
| Pressing interceptor and escaping courier | 2, 6 | `range_opponent.gd`, `courier_runner_opponent.gd` | I | Play the initial encounter and Courier Intercept; observe pressure/escape, real damage, success/failure, withdrawal and short safe recovery. |
| Standoff picket and flanking skirmisher | 6 | `standoff_picket_opponent.gd`, `flanking_skirmisher_opponent.gd`; `assets/weapons/picket_siege_lance.tres`, `skirmisher_flank_scatter.tres` | I | Play Paired Wing Break, Perimeter Hold and Heavy Breach; prove distinct standoff/flank posture, occlusion, scatter and player-readable counters. |
| Torpedo boat and interceptable seeker | 6 | `torpedo_boat_opponent.gd`, `scripts/combat/seeker_torpedo_projectile.gd` | I | Play Torpedo Run using evasive pitch/boost and shoot-down, then destroy the boat; accept failure/abort and late-peer projectile presentation. |
| Fleet pulse profiles and role weapons | 2, 5, 6 | `assets/weapons/*_combat_pulse.tres`, `hero_ship.gd`, Halyard/Bulwark role owners | I | Fire each actual craft/role at supported targets with friendly/self/occluded refusal; verify heat/cadence, real damage and accessible presentation. |
| Cinder repeater, travelling mass-driver and finite bomber payload | 5, 6 | Cinder ship owners; `scripts/combat/mass_driver_bolt_pool.gd`, `bomber_payload_authority.gd`, `bomber_payload_projectile.gd` | I | Accept travel-time hit/miss, origin shifts, depletion and stale-owner cleanup. Do not assign duplicate projectile work merely because the detached resolver refuses ammunition. |
| Consistent component damage, repair, destruction and respawn | 6, 10.1, 10.3 | `scripts/combat/component_damage_model.gd`, `ship_component_damage.gd`, `repair_authority.gd`, live damage adapters | I | Damage hero/enemy components, observe engine consequences, repair, destroy and regenerate; accept receipt ordering, pooled saturation and re-entry without duplicate score or lingering effects. |

## Nearby activities and three visitable worlds

These are Phase 8's concentrated authored cluster plus Phase 10.4's three atmosphere-to-surface worlds. [Destination catalog](../scripts/world/planetary_destination_catalog.gd) sector sites and presentation-only coloured bodies do not count as additional planets. GameFlow and the streaming coordinator own discovery/admission/return; the Activity Board must work with normal controls while unloaded as well as loaded.

| Requirement | Original phase | Runtime/content location | Status | Next action and acceptance scenario |
| --- | --- | --- | --- | --- |
| Checkpoint race | 8 | `scripts/activities/cinder_timed_race_session.gd`, `timed_checkpoint_race.gd` | I | Depart station, load Cinder, start, fly real checkpoints, finish or timeout/abort, retry rejected reward writes and return with one durable receipt. |
| Asteroid/debris threading | 8 | `assets/activities/` threading route, timed-race owner | I | Fly ordered spheres without shortcut progress; reload active/earned-unpaid state and repeat through ordinary controls without duplicate payment. |
| Platform patrol | 8 | `scripts/activities/patrol_activity.gd`, `assets/activities/cinder_reach_platform_patrol_route.tres` | I | Complete each posted route and combat/dwell, fail/reset, reload and replay after paid reset with one payment per earned generation. |
| Jovian kit delivery and Cinder platform supply | 8 | GameFlow cargo owner, `scripts/cargo/`, `scripts/world/cinder_cargo_access.gd` | I | Use exact Jovian/manifest, physically depart, dock, walk to terminal, transfer conserved stock and return; reject wrong craft, backup-derived entitlement and repeated receipts. |
| Mining/extraction | 8 | `scripts/world/cinder_mining_platform_activity.gd` | I | Hold the real ship in the extraction envelope, leave/retry, persist capacity progress and test refused writes; no ore grant is inferred. |
| Abandoned-structure material scan | 8 | `scripts/world/cinder_abandoned_structure_scan_activity.gd` | I | Hold at marker, leave/pause, complete report, retry failed discovery save and fresh-load without repeating payment. |
| Navigation beacon traversal | 8 | `scripts/world/cinder_beacon_traversal_activity.gd` | I | Fly beacons in order, fail/reset/retry, preserve unpaid debt across reload and complete a second legitimate run. |
| Convoy escort | 8 | `scripts/activities/cinder_convoy_escort_host.gd`, `convoy_escort_activity.gd` | I | Reach rendezvous, escort real tender against threats, accept separation/loss/abort, recover a saved craft and pay owed reward once. |
| Station defence, Heavy Breach and Torpedo Run | 6, 8 | `scripts/activities/station_defense_activity.gd`, encounter host/director and deck boards | I | Walk to the physical board, deploy and fight, fail/abort/reset, reload earned-unpaid state and redeploy; remote UI must not bypass deck proximity. |
| Hulk salvage/power restoration and belt interior | 8 | Catalog sector sites, `scripts/activities/derelict_power_restoration_activity.gd` | I | Approach/land/enter, use the real breaker, exit and return; repeat visits preserve restored bus/single claimed cell without a second reward. |
| Ember Moon caldera/relay survey | 8, 10.4 | `scenes/world/planets/ember_moon.tscn`, `scripts/activities/ember_caldera_expedition_activity.gd`, `scripts/world/ember_surface_relay_survey_activity.gd` | I | Accepted preparation runtime is integrated into main. Fly uninterrupted outbound, land, walk and complete real survey, save reward, reboard, ascend and dock home. Repeat abandonment/re-entry and shared remote-crew return separately. |
| Aurora coastal survey | 10.4 | `scenes/world/planets/aurora_temperate_world.tscn`, `scripts/activities/aurora_coastal_survey.gd` | I | Fly, land, walk actual shore landmarks, retry final-landmark reward save, reboard and physically return; accept repeated/interrupted visits, water/atmosphere and minimum hardware. |
| Rime ice-core survey | 10.4 | `scenes/world/planets/rime_glacial_world.tscn`, `scripts/activities/rime_ice_core_survey.gd` | I | Fly/land/walk, manage heat, distinguish warming from exhausted-survey restart, save/retry earned reward and return; accept repetition and weather/terrain presentation. |

For repeatable activities, accept ten same-world runs without resource growth or stranded objectives; for the one-shot hulk, accept repeated visits without a second reward. Test accepted starts followed by rejected writes, fresh process load and OS interruption. None of this permits persistence to recreate combat actors or infer legacy reward entitlement.

## Roles, supported session limits and desktop targets

| Requirement | Original phase | Runtime/content location | Status | Next action and acceptance scenario |
| --- | --- | --- | --- | --- |
| Immediately usable solo fighter pilot | 2, 5, 7 | `hero_ship.gd`, `scripts/game/game_flow.gd`, boarding/command components | I | First-time player boards and completes sortie/return with remapped keyboard/mouse and controller; recover safely after destruction/restart. |
| Pilot, passenger and moving-cabin occupancy | 7 | `scripts/network/network_enet_session_adapter.gd`, seat/relationship authority, Halyard/Jovian/Cinder owners | I | Real server and two clients walk, claim distinct seats, fly, stand/reseat, late join and disconnect; reject duplicate/stale/malicious claims and retain supported controls. |
| Jovian/Halyard engineer | 7 | `scripts/network/network_jovian_engineer_binding.gd`, ship repair owners and GameFlow | I | The physical Halyard engineer chair and finite shared repair route are integrated into main. Preserve the earlier `61749efc` package/migration/disconnect checks in their original scope, then accept ordinary native crew use, stand/reseat, migration and disconnect on the final package without helm authority or duplicated repair. |
| Bulwark/Halyard gunner | 7 | `scripts/network/network_bulwark_gunner_binding.gd`, `network_halyard_passenger_binding.gd`, ship owners | I | Sit/aim/fire at a real target in a moving craft, stand/reseat and survive pilot disconnect with valid weapon and input ownership. |
| Halyard Loadmaster and Cinder Loadmaster/Navigator | 5, 7 | Halyard/Cinder ship owners; `scripts/network/network_cinder_loadmaster_manifest_bridge.gd`, `network_cinder_navigator_ping_bridge.gd` | I | Walk to stations, use readiness/route hints, stand/reseat and reconnect; hints/readiness confer no cargo, reward or helm authority. |
| Shared planetary multiplayer | 7, 10.4 | `scripts/network/network_planetary_journey_bridge.gd`, GameFlow and planetary surface/return bindings | I / complete journey acceptance open | Accepted shared return, survey ownership/help, interrupted-visit restoration and fresh crew boarding are integrated into main. Finish the genuine canonical outbound/landing/survey/durable reward/reboard/physical home-return route with real remote crews and late observer, including rebase, cancellation, reconnect and interruptions. Investigate the retained original 120-second shared-arrival landing failure without relaxing it; staged surface checks and solo returns do not qualify the full journey. |
| Release player/crew capacity | 7, 9 | ENet `DEFAULT_MAX_CLIENTS = 8`; handshake/migration caps 64, interest cap 128 | E decision + I configuration | Name the supported release session and per-craft occupancy limits, then prove native server/two-client review and 30-minute latency/loss/soak at that count with tick/bandwidth/resource budgets. Eight configured clients is not an accepted eight-player release. |
| Windows Desktop | 9 | `export_presets.cfg`, `tools/release/` Windows export/NSIS/startup/interruption commands | I + E | Qualify one integrated candidate's EXE/ZIP/installer, clean install/upgrade/rollback/uninstall and all required recovery contexts; complete native gameplay/GPU/controller/audio review and trusted signing. |
| Linux x86_64 | 9 | `export_presets.cfg`, `tools/release/` archive/desktop helper workflow | I + E | Qualify matching final archive and private install/reinstall/uninstall with preserved userdata, native graphical solo/crew play and actual interruption/recovery; complete hardware/input/audio review. |
| Other desktop targets | 9 | No additional export preset in inspected source; original wording does not name a specific third target | M if required; E scope decision | Record the actual required desktop target list against Phase 9. Implement and accept any additional required target or record an explicit owner-approved decision beside the promise; no macOS delivery or deferral is invented here. |

## Phase-wide acceptance still required

The roster tables name content; the following shared commitments still apply to every required item. Detailed remaining tasks and historical results stay in [ROADMAP](../ROADMAP.md#remaining-tasks-to-complete-the-project).

| Original commitment | Phase | Current seam / status | Concrete next action and acceptance scenario |
| --- | --- | --- | --- |
| Evidence-bounded original names, models and station claims | 1, 3, 4 | `docs/research/source_ledger.json`, ship matrix/topology; I + E | Reproduce each claimed identity/relationship from registered anchors; resolve unknowns before stronger wording and preserve dated variants. |
| Packaged vertical slice and whole-game stabilization | 2, 10.1 | Production Main, GameFlow, existing canonical journeys and local regression; I / acceptance open | The intended runtime is integrated. Freeze the final source, run its complete local regression and ordinary board/fly/fight/dock/exit/recovery journeys; fix failures rather than relabel older runs. |
| Measured performance and finite streaming/transient budgets | 9, 10.2 | Graphics/quality settings, streaming and pooled effect owners; I + E | Measure minimum/target native Windows CPU/GPU/frame-time/memory/network budgets during station/combat/surface/repeat play; software or VM checks do not qualify native GPU performance. |
| Complete visual art direction and gameplay-distance reviews | 3–6, 10.3 | Station/fleet/world/UI presentation; I + E | Review all required routes and thirteen roadmap graphical scenarios, including minimum graphics, ultrawide and reduced flash/motion; fix seams, scale, cues and transitions with before/after views. |
| Audio, remapping, accessibility, tutorials and session discovery | 9, 10.3 | Production audio/input/settings/UI owners; I + E | Finish outstanding music/mix/browser/settings behavior and prove every required action via controller/remapping, captions/colour-safe cues and comfort settings; perform audible and first-time-player reviews. |
| Final candidate installation, data recovery and distribution | 9 | Release tooling/presets and atomic persistence; I + E | Accept final integrated packages, migration/corrupt-data fallback and all required installed recovery contexts, inspect licences, sign with real credentials and publish matching immutable artifacts/checksums with no open P0/P1. |

The immediate gameplay acceptance gap is the **complete physical survey round trip with remote crews** on the integrated runtime. Inspect and fix observed runtime failures while retaining ordinary controls, actual reward/save/reboarding/home-return behavior and the original acceptance limits. Integration is complete; it must not be assigned again as missing work. In parallel, each of the eight absent originals remains a content task constrained by its evidence boundary. Owners, implementation estimates and review availability still need assignment under task 0 before a credible finish date.
