# Completion scope working inventory

Checked against runtime source `392d98417` on 2026-10-09. This is the first itemized planning deliverable for [roadmap task 0](../ROADMAP.md#0-fix-the-release-scope-and-assign-the-completion-work--all-phases). It records implemented content and named remaining work; it does not approve a reduced release scope, close phase gates or set a finish date. The [34-task checklist](../ROADMAP.md#remaining-tasks-to-complete-the-project) remains authoritative.

“Implemented / acceptance open” means a production definition, scene or runtime owner exists. The final candidate still needs ordinary-controls, package, recovery and applicable human/hardware acceptance. A file or catalog entry alone never proves an end-to-end route. Owners and delivery estimates remain unassigned until the completion plan supplies them.

## Fleet — Phases 4–6

GameFlow's production flyable roster names nine craft. Definitions are under `assets/ships/`; historical wording remains bounded by each definition's evidence status.

| Craft | Definition | Status and exact remaining action |
| :--- | :--- | :--- |
| Torrent | [torrent_provisional.tres](../assets/ships/torrent_provisional.tres) | Implemented / acceptance open. Complete guided first sortie, combat, docking, recovery and handling review; resolve applicable B5 provenance dependencies. |
| Arrow | [arrow_provisional.tres](../assets/ships/arrow_provisional.tres) | Implemented / acceptance open. Complete reconnaissance-role, flight/combat/landing/recovery and silhouette review; name-to-model evidence remains bounded. |
| Jovian | [jovian_provisional.tres](../assets/ships/jovian_provisional.tres) | Implemented / acceptance open. Accept physical hold/cabin, conserved cargo transfer, ordinary engineer repair and return/recovery in solo and supported crew sessions. Resolve historical identity dependencies. |
| Zenith | [zenith_b7_observed.tres](../assets/ships/zenith_b7_observed.tres) | Implemented / acceptance open. Accept interceptor trade-offs and full craft loop; resolve naming and tied B7 recording/build continuity. |
| Halyard | [halyard_new_design.tres](../assets/ships/halyard_new_design.tres) | Implemented / acceptance open. Accept moving cabin, passenger sit/stand, bunk, pilot handback and recovery. Complete reachable network passenger integration; a solo chair is not evidence of network support. |
| Bulwark | [bulwark_new_design.tres](../assets/ships/bulwark_new_design.tres) | Implemented / acceptance open. Accept physical gunner route, real target damage, stand/reseat, network migration/disconnect and recovery on final package and native hardware. |
| Cinder Light Interceptor | [cinder_light_interceptor_new_design.tres](../assets/ships/cinder_light_interceptor_new_design.tres) | Implemented / acceptance open. Accept specialist handling, weapon, damage/repair, docking and reuse. |
| Cinder Cargo Hauler | [cinder_cargo_hauler_new_design.tres](../assets/ships/cinder_cargo_hauler_new_design.tres) | Implemented / acceptance open. Accept loadmaster/cargo interactions, actual travelling projectiles and current/late-peer presentation, flight and recovery. |
| Cinder Long-Range Bomber | [cinder_long_range_bomber_new_design.tres](../assets/ships/cinder_long_range_bomber_new_design.tres) | Implemented / acceptance open. Accept finite payload, target damage, navigation/crew interactions, landing and recovery. |
| Titan, Vortex, Paradox, Katana, Predator, Dynamic, Utopia, Salyut | No corresponding ship definitions in the current roster | Missing implementation plus historical evidence dependencies. Deliver each agreed interpretation's definition, hull/cabin, berth, boarding, handling, role/weapon, audio and recovery through the existing fleet pipeline. Complete each full craft loop; the five modern craft do not replace these commitments. |

Shared fleet acceptance: ordinary boarding → flight → supported role/combat → landing → disembarkation → reuse; destruction and save/crash recovery preserve usable controls and valid owners. Review hull/cabin animation, collision, camera clearance, reduced-motion/flash presentation and minimum/target GPU budgets. Original recognition feedback and legally available reconstruction sources remain separate dependencies.

## Station routes — Phases 1, 3 and 10.3

The [production world scene](../scenes/world/shipyard_world.tscn) instantiates these modules; [ShipyardWorld](../scripts/world/shipyard_world.gd) adds geometry, activities, route registration and signage. The non-metric [route registry](../scripts/world/station_route_registry.gd) does not establish physical walkability.

| Required route/content group | Production location | Remaining acceptance or delivery |
| :--- | :--- | :--- |
| Central berth, Arrow berth and launch/return apron | `shipyard_world.tscn`, `shipyard_world.gd` | Walk spawn → board → return → exit without rescue; verify approach cues, camera/collision clearance and readable normal/minimum graphics. |
| Aft junction and habitat spine | `scenes/world/modules/aft_junction_stack.tscn`, `habitat_spine.tscn` | Walk every agreed branch, doors and station-life interaction; review continuity, signage and final dressing. |
| Jovian freight berth and cargo terminals | `jovian_freight_berth.tscn`, `cargo_source_terminal.tscn`, `cargo_destination_terminal.tscn` | Reach terminals through the physical route; transfer actual inventory, preserve receipts across failure/reload and return to the craft. |
| Fleet dock comb and fleet berths | `fleet_dock_comb.tscn`, world berth instances | Walk to every shipped craft and return; accept berth/hull scale, docking support, discovery and finished fleet presentation. |
| Fabrication annex | `fabrication_annex.tscn` | Accept the physical connector, service interactions, readable route and final art. |
| Observation/logistics spur | `observation_logistics_spur.tscn` | Accept connector and viewing/logistics routes, navigation cues, support and camera clearance. |
| Salvage terrace | `salvage_terrace.tscn` | Accept terrace/connector and authored salvage interactions with recovery and final presentation. |
| VIP reception suite | `vip_reception_suite.tscn` | Accept physical access and required reception content; retain interpretation/evidence boundaries. |

Before assigning new rooms, reconcile the original Phase 3 topology promises against these routes and the [research topology](research/STATION_TOPOLOGY.md). Name any missing agreed room/connection individually. Do not infer historical adjacency from the modern operational graph or mark station expansion complete from module counts.

## Activities and destinations — Phases 6, 8 and 10.4

| Required player loop | Current owner/content seam | Remaining action |
| :--- | :--- | :--- |
| Checkpoint race and asteroid threading | `scripts/activities/cinder_timed_race_session.gd`, `timed_checkpoint_race.gd`; two `assets/activities/*route/threading*.tres` resources | Accept station departure, real checkpoint travel, timeout/abort/retry, progress/payment save failure and repeat return through normal controls. |
| Platform patrol | `scripts/activities/patrol_activity.gd`; `cinder_reach_platform_patrol_route.tres` | Retain delivered paid-reset branch replay and rejected-write transaction; accept both routes, combat/progress, fresh-load, payment once and ten same-world repeats. |
| Jovian cargo | GameFlow cargo owner; freight terminals | Accept conserved source/recipient quantities and transfer receipts, wrong craft/cargo refusal, reset/switch/reload and genuine later reward. |
| Mining/extraction | `scripts/world/cinder_mining_platform_activity.gd` | Accept saved extraction capacity/progress, unpaid completion/retry and usable interruption recovery; no inferred ore grant. |
| Scan/discovery | `scripts/world/cinder_abandoned_structure_scan_activity.gd` | Accept travel, earned report, refused discovery save/retry and fresh-load/interruption; no repeat payment. |
| Beacon traversal | `scripts/world/cinder_beacon_traversal_activity.gd` | Accept actual route, terminal save/payment retry, reset/reload and a second genuine run; preserve unpaid debt. |
| Convoy escort | `scripts/activities/cinder_convoy_escort_host.gd`, `convoy_escort_activity.gd`; Emberline route | Accept physical escort, threat/loss/abort, saved-craft resume, owed reward/reset and native peer actor lifecycle. |
| Station defence and heavy breach | `station_defense_activity.gd`, encounter host, production defence/heavy-breach boards | Accept ordinary Boot/board deployment, combat success/failure, pending reward, interruption/retry and repeat deployment. |
| Hulk salvage and belt interior | Sector sites in `planetary_destination_catalog.gd`; `derelict_power_restoration_activity.gd` | Earned-unpaid one-shot restoration recovery is integrated in `1ed2b964b`, with focused acceptance passing. Matching Windows/Linux `709de858a` hulk checkpoints pass focused package/startup checks. Linux also passes actual exported-executable kill/restart and usable recovery; Linux execution of the Windows embedded PCK passes interruption, and the matching unsigned installer now passes native default11/hulk pilot16 with actual owned Windows kill/restart and one Boot payment. The staged on-foot route, real breaker and safe-home recovery preserve terminal/settings/cargo; other interruption contexts remain open. Complete ordinary physical approach, landing/entry, salvage/power interaction, safe exit and return acceptance; sector sites do not count as planets. |
| Ember Moon | `scenes/world/planets/ember_moon.tscn`, caldera expedition owner | Accept physical outbound/landing/survey/reboard/takeoff/home loop, abandonment, interrupted visits and repeated returns on packaged minimum/target hardware. |
| Aurora | `scenes/world/planets/aurora_temperate_world.tscn`, coastal survey owner | Accept physical cruise/arrival, shore route/survey/reward, interrupted visits, return and repeat use; review atmosphere, terrain, water and audio. |
| Rime | `scenes/world/planets/rime_glacial_world.tscn`, ice-core survey owner | Accept physical travel/surface/return, spent-heat recovery, survey/reward and repeated visits; review terrain, weather/atmosphere and audio. |

All shipped activity loops need wrong-craft refusal where applicable, supported failure/abort/reset, accepted start followed by rejected later writes, fresh-load and OS interruption, and ten repeats without resource growth or stranded objectives. For deliberately one-shot hulk restoration, repeat visits must retain the restored bus and single claimed cell; they must never produce another completion reward. Persistence must not recreate combat actors, infer legacy reward entitlement or duplicate payment.

Combat additionally needs ordinary controls for the catalog's courier intercept, paired-wing break, perimeter hold and Torpedo Run, alongside craft-specific weapons/payloads. The [scenario catalog](../scripts/combat/combat_scenario_catalog.gd) and [weapon resolver](../scripts/combat/weapon_definition_resolver_profile.gd) supply contracts; live owners, real damage and native peer presentation must be accepted separately. Reconcile hauler projectile travel and heavy-picket posture against current runtime before assigning a duplicate implementation.

## Multiplayer and platform limits — Phases 7 and 9

- Implemented network crew routes include Jovian engineer and Bulwark gunner. Halyard passenger integration is the next bounded delivery. Remaining shipped roles need their own reachable hatch/chair route, authority and input restoration; injected assignments do not qualify them.
- `NetworkEnetSessionAdapter.DEFAULT_MAX_CLIENTS` is 8. This is a configured default, **not** an accepted release player count; handshake/interest/parser caps differ and do not prove capacity. The required native server/two-client review and 30-minute soak remain open. Agree the supported player/crew count and then prove tick, bandwidth, snapshot and resource limits at that count.
- Planetary travel and network sessions currently refuse incompatible overlap through GameFlow. Shared planetary multiplayer remains an explicit full-scope decision/dependency; it requires coordinated origin/rebase, streaming, craft/crew/projectile and activity/save authority if included. The current restriction is not completion of that ambition.
- [Export presets](../export_presets.cfg) exist for Windows Desktop and Linux x86_64. The latest Windows/Linux hulk checkpoints (`709de858a`) have bounded package/startup and scoped interruption acceptance; earlier patrol acceptance remains specific to `ed359040c`. Clean native graphical Linux play, final-candidate Windows installation/update/rollback/recovery, physical input/audio, trusted signing and final distribution remain open. Other promised desktop targets require an explicit implementation or owner-approved deferral.

## Dependencies before a credible delivery date

1. Reconcile each original phase commitment against this inventory and add individually named missing content; retain all unapproved original promises.
2. Agree shared planetary multiplayer, supported player/crew limits and desktop targets. Assign an accountable owner and separate implementation/acceptance estimates to every remaining deliverable.
3. Book native GPUs, physical controllers, audible review and first-time players; preserve all unperformed gates as `NOT_RUN`.
4. Finish runtime/content delivery, then freeze one candidate for complete regression, normal-controls journeys, thirteen required graphical reviews, performance/accessibility/audio, installation/recovery, licensing/signing and matching distribution.

External research, legal clearance and signing credentials remain dependencies. No owner decisions, review results or dates are inferred by this inventory.
