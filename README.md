# Mudds Shipyards

**Mudds Shipyards** is a native Godot 4 remake prototype inspired by ZolarKeth's 2009 Roblox game **Keth Shipyards**. The current project supports a bounded guided Torrent sortie and an early repeatable four-craft sandbox: cross the station on foot, physically enter one of exactly four prototype flyables—the partial, source-aligned B5-linked Torrent reconstruction v1, provisional Arrow candidate, provisional Jovian candidate, or bounded partial `Zenith-class Interceptor — B7-observed reconstruction`—sit at its controls, start, launch, fight, return through a strict lease-bound landing contract to a compatible physical berth, shut down, physically disembark, and choose another craft without reloading the world. Destroying the guided defender authorizes the return but does not complete the guide; completion occurs only after the same Torrent is securely docked, powered off, and the generation-guarded exit finishes. An Arrow-, Jovian-, or Zenith-first free sortie deliberately preserves the still-pending Torrent guide and its range contacts. Deliberate high-speed crashes invoke same-world pilot recovery and regenerate the lost craft at its berth. Those working beats are an early Phase 2/Phase 3/Phase 4 foundation; they do not make the complete shipyard, researched original fleet, authenticity work, multiplayer, multi-crew play, or release polish complete.

Repository: <https://github.com/themuddfamily/mudds-shipyards>

This repository contains an original, research-led fan prototype. It does not use Roblox, Roblox Studio, Electron, Three.js, or a browser runtime.

This is an unofficial fan project. It is not affiliated with, sponsored by, or
endorsed by ZolarKeth, Roblox Corporation, or the original experience's
rightsholders. No public-release or commercial-use permission from those parties
is recorded here, and this repository currently has no project `LICENSE` file;
the permission and legal-review gate described below remains open.

## Current prototype slice

- Third-person on-foot movement from an exposed junction facing a short stair and the flyable craft. The dock-lattice blockout uses separated collidable nodes, narrow orthogonal arms, large real voids, an open flight arm and signal gantry, and compact modern registry/operations pods.
- The live backdrop moves toward the broad composition shown collectively by the cited sources: near-black space, one deterministic 2,600-instance star shell, and four large green, tan/cream, grey, and orange presentation-only bodies beyond the launch range. Sources support dark, star-dense space and conspicuously large simple colour bodies, not the exact body/star count, placement, radii, materials, or density; those remain audited modern choices. The project-original nebula remains only as a faint live-sky cover and full-strength title treatment.
- A single explicitly modern registry terminal presents the creator-proven `SAY SHIP NAME` convention and ten documented names beside a physical active-berth indicator; it is not claimed as recovered original machinery.
- A source-bounded Aft Junction Stack adds a second physical level, a real climbable stair, an enterable windowed operations room with four chairs and three console bays, a cyan-operated door, and a locked/deferred red VIP landmark. Its exact plan, dimensions, furniture, mechanics, and adjacency are explicitly modern interpretation.
- A source-bounded Fleet Dock Comb extends that upper circulation through one narrow visible connector into a long starboard trunk, three short teeth and three broad physically separated slabs with real space between them. B2 supports the repeated comb/trunk/slab rhythm, not this exact count, placement, dimensions, ramp or styling. Dock 01 records a modern external Zenith assignment aligned to a world-owned berth; Docks 02/03 remain deliberately empty and deferred. The module's markers add no `ShipBerth`, lease, regeneration, interaction, audio or gameplay authority, while the world owns the exact four production landing contracts.
- An integrated Habitat Spine branches from the starboard lattice through a real operated door into a player-clear corridor, six bunk alcoves, an eight-chair observation/common room, windows, consoles, service detail, and a sealed deferred branch. Later secondary material motivates the habitat/bunk/chair motifs, but its exact build provenance is unverified; the module's name, placement, dimensions, room functions, layout, furniture, connector, and mechanics are a fixed-era-inspired modern interpretation rather than recovered geometry.
- Exactly four physically parked and flyable craft occupy independently reserved berths. B5, footage uploaded in June 2011, provides a high-confidence, frame-resolved Torrent name-to-model link; its recording date and live build revision are unverified. The linked model's detailed reconstruction remains partial and continuity with the 2009 form is unproved. The bounded reconstruction v1 replaces the former wide/low arrowhead with a compact faceted nose, raised central spine and blocky aft body, four stepped side-plane tiers, dominant paired upright rails, an explicitly inferred crossbar preserving the U-like rear read, a visible red seat, and a restrained amber forward panel whose historical function is unknown. Arrow and Jovian remain isolated provisional variants: Arrow preserves only the creator-supported name, reconnaissance role, and two-escape-pod count, while Jovian preserves only the creator-supported name and light-freighter role. Their current name-to-model mappings and all unsupported geometry and systems remain modern design.
- B7 securely links the runtime Zenith Interceptor label to a pale, very wide delta/arrow craft through the registered `f373–f467` approach, boarding and flight chain; `f468+` is excluded. The accepted partial implementation preserves that source-recognition macroform in a removable `SourceCore` while its cockpit/access, engines, weapons, landing gear, materials, handling and Fleet Dock berth remain modern. B7 was uploaded on 2012-03-18, but that does not establish its recording date, game build or model date. A5/B7 say **Interceptor**, A9 says **Fighter**, and the dated conflict remains unresolved. Passing asset, collision, lifecycle and capture checks does not authenticate the ship.
- An integrated port freight branch connects the station lattice to the Jovian's separate berth, loading apron, and service room. Its deployed ramp, cargo bay, passenger cabin, and cockpit form one attached collision-backed ship-local hierarchy rather than a detached interior or separate teleported level. Automated locomotion walks the production player from the ramp through the cargo bay into the passenger cabin; cockpit boarding is separately exercised through the exterior pilot hatch, so a continuous ramp-to-cockpit walk remains unproven.
- A reusable `MovingInteriorFrame` carries registered occupants through ship translation and rotation, aligns floor classification, exposes ship-local gravity, and applies exit velocity once. The production `PlayerController` consumes that gravity and resolves movement in the deck-tangent plane. This is a tested local-authority foundation for moving interiors with one player avatar, not implemented multiplayer or multi-crew gameplay.
- The Torrent's source-directed macroform uses a modern ergonomic normalization of about `L 8.4 m × W 7.2 m × H 4.54 m`; those metres are not recovered source dimensions. Its two observed aft housings use a nominal `0.80 m` diameter and `3.35 m` fore-aft length, but their historical function is unknown. Recessed engine internals, exhaust, opening pressure canopy, controls, weapons, tricycle visual gear, docking receiver, RCS and service detail remain separated or explicitly tagged modern interpretations. Compact hull/side-plane collision envelopes and the gameplay damage anchors were updated for the new form while preserving boarding, camera, flight, landing, damage and reuse contracts.
- Explicit engine startup/shutdown and keyboard, mouse, and partial gamepad arcade flight using a mixture of version-informed bindings and new prototype controls. Each piloted craft samples one validated `ShipCommand` snapshot per physics tick from a swappable command source; the production `LocalShipInputSource` drives the same flight/fire path that a later replay or network source could use. This is an authority seam, not multiplayer or implemented network play. Mouse motion maps directly to yaw/pitch attitude, `A`/`D` provide keyboard yaw, the arrow keys provide pitch, and `Q`/`R` provide roll without taking `E` away from interaction. Coalesced mouse motion is bounded per physics tick but retained as a backlog until consumed, rather than losing excess input at a clamp; simultaneous mouse yaw/pitch is composed as one local rotation vector so proportional diagonal sweeps do not acquire a polling-rate-dependent roll artifact. Ownership, parked/startup, camera and reset boundaries clear stale motion. Equivalent 30/60/120 Hz input trials—including a saturated diagonal sweep—are covered by deterministic regressions. A common SDL-style gamepad layout supplies separate throttle/yaw and pitch/roll sticks, triggers and flight buttons with a shared `0.18` deadzone, although engine start/stop and landing still require the keyboard. A brief `W` tap cannot falsely undock a parked craft; sustained `W` departs along the visible nose; real external collision motion and impulses remain preserved and clear the landed state rather than being suppressed.
- The fixed centre reticle continues to show the physical nose and weapon axis, while a separate hollow cyan flight-path cue projects actual world velocity through the active chase or cockpit camera. Slip moves that cue away from the reticle, off-screen travel clamps it to a safe ellipse, and rearward travel receives a distinct reverse state. The cue hides when travel is too slow, the craft is landed or destroyed, or the player is not piloting, and every control in the gameplay HUD remains pointer-transparent.
- `V` switches between a physical cockpit-eye view and a swept-sphere SpringArm chase view; the chase sweep collides with the world and other physical ships while excluding its own craft, and the mouse wheel adjusts distance. The chase boom now follows attitude with a bounded response and capped angular lag while the camera's optical axis stays exactly nose-aligned; view and authority boundaries snap away latent lag. Handling still needs a player-led packaged-build tuning pass. Engine start/stop, landing, and interaction remain explicit `GameFlow` events. Ship-local thrust presentation now follows the same sampled `ShipCommand` boost value and the resulting actual throttle instead of reading the local input action separately.
- An exterior target range followed by a live AI range-defence interceptor that manoeuvres, telegraphs and fires signal-driven hitscan weapons, damages the player's hull, and drives directional HUD feedback. Player and opponent shots traverse one live `CombatResolver` through registered stable source identities, authority-owned factions and weapon profiles, monotonic sequence checks, source collision exclusion, world occlusion, and typed damageable proxies. One global `PulseWeaponPresentation` renders accepted resolved shots through a fixed preallocated six-slot, oldest-visual-recycle pool with three modern emissive styles and no collision, damage, audio, or firing authority. The resolver's local sequence history survives whole-tree detach/re-entry, so a captured request cannot apply damage again; this is local replay hardening, not a networked combat implementation.
- Staged damage on both combatants. The opposing craft has impact sparks, persistent critical smoke, a destruction burst, and temporary physical debris. The hero craft now has world-space impacts, damaged-stage sparks, critical smoke and engine stutter, reduced engine output and speed under severe damage, plus a reusable destruction-presentation component.
- Schema-v2 physical berth leases and landing acceptance: a compatible berth grants an opaque requester/ship-bound token, the assist snapshots its exact berth identity, parent, transform, volume, and complete root-collision envelope, and completion converts that same reservation to occupancy only after a strict dock fit. Moved/reparented berths, lost leases, obstruction, timeout, destruction, or reuse reset abort safely and release the pending lease. A guided Torrent victory only opens the return leg; the guide remains incomplete through landing and shutdown and commits once, after the physical disembark signal and generation-guarded transition restore on-foot authority.
- Exactly four presentation-only `ShipBerthFeedback` components—one direct child of each production berth—translate the authoritative lease states into modern deck cues: cyan `BERTH OPEN`, amber moving `APPROACH VECTOR`, and green `BERTH SECURED`. They add no collision, physics queries, lights, audio, particles, timers, navigation, docking authority, or historical claim. Their layout, labels, colours, motion, materials, dimensions, and placement are unauthenticated modern interpretation.
- Landing, docking latches, safe shutdown, same-world disembarking, deliberate collision damage, crash recall, and reusable craft regeneration keep the loop available after a guided sortie instead of ending at a terminal completion screen. Whole-`Main` detach/re-entry preserves gameplay state and node identities, rebuilds released procedural audio resources without replaying startup, reconnects live combat sources once, clears transient pulse effects, and retains resolver replay rejection. Process-owned regeneration deadlines never mutate a detached tree; after re-entry, an occupied home berth schedules a bounded retry and the same craft instance returns only after acquiring its physical occupied lease.
- Each of the four production flyables owns one finite-range positional 3D `ShipAudioRig`, selecting one of three definition-bound profiles: Torrent and Zenith `standard_fighter`, Arrow `efficient_twin_recon`, and Jovian `heavy_quad_freighter`. Each rig procedurally synthesizes its continuous engine/operational layers. Physical combat events now use seven checked-in project-original 48 kHz PCM cues through one fixed ten-voice `CombatAudioPresentation`: safed triggers click without advancing authority, accepted player/defender shots sound once at the request origin, pulse impacts begin only at their delayed endpoint, and ship explosions remain at the destruction position. Independent fire, impact, explosion, and dry-fire pools prevent one event family from stealing another. The sounds are original fixed-seed offline synthesis, not recovered Keth audio; automated format, routing, authority, position, overlap, and lifecycle checks do **not** prove real-hardware audibility or final mix quality.
- A narrower, human-proportioned realistic-stylised pilot/technician with articulated procedural limbs, a compact helmet and visor, differentiated woven/flexible/hard materials, harness, segmented service hoses, couplings, fasteners, armour, life-support pack, gloves, and grounded boots in place of the original block avatar. One coherent rig covers standing, boarding, seated, disembark, and recovery states.
- A bounded central-berth hero cell with an original Blender-authored presentation shell: 111 editable deck, fascia, primary/secondary structure, and service-channel components batch to eight UV0-mapped runtime meshes (11,508 triangles). The established Godot walking floor, berth and collision-only launch transition remain authoritative beneath it; three retracted non-colliding clamps, stowed power/data/fuel utilities, trenches, drains, neutral work lights, a control pedestal, and a local reflection probe preserve the safe walk-up, boarding, landing and launch contract. Its layout and hardware are modern provisional design.
- The Torrent cockpit now has a compact translucent trapezoid forward panel, a tapered anti-glare instrument hood and side-console treatment, restrained in-world speed/throttle/engine/path readouts, and a low-energy practical light. Its deterministic quality contract samples the centre and four near-centre rays through a `10 m` sight corridor spanning approximately `±6°` yaw and `±5°` pitch, checks the nose-aligned pilot camera and near plane, and keeps the additions labelled as modern presentation rather than recovered historical controls.
- A bounded Phase 3 operational-lattice pass places exactly four fixed-rail, role-specific, non-colliding activity components in the live station: `Full` at Central (`CentralTowServiceActivity`), `Gantry` at Freight (`FreightApproachGantry`, corrected to freight-module-local `z = 0.9`), `Service Arm` at Aft (`AftOperationsActivity`), and `Drone Patrol` at Habitat (`HabitatServicePatrol`). Fixed transforms and seeds, finite render/service envelopes, deterministic seek and 30/60/120 Hz motion, reversible pause/disable/re-entry lifecycles, and detached fail-red audits keep the presentation bounded. These visual rails add no collision, navigation graph, docking authority, or autonomous-logistics gameplay; the two patrol drones are presentation, not autonomous agents.
- Exactly four finite-range positional 3D procedural machinery beds occupy the operational lattice: `central-berth-utilities` (`26 m` maximum / `4 m` reference distance), `aft-operations-service-wall` (`24 m` / `3.5 m`), `habitat-environmental-main` (`22 m` / `3 m`), and `freight-control-machinery` (`28 m` / `4 m`). Each synthesizes deterministic loop, servo, and latch waveforms on the Ambience bus with a two-voice ceiling; the Aft, Habitat, and Freight station doors trigger the servo/latch hooks. This project-original sound design is tagged `modern_interpretation`, not recovered historical ambience or audio.
- Exactly four collision-free outer-face structural dressings—`CentralBerthOuterFascia`, `AftOperationsOuterFascia`, `HabitatOuterServiceDressing`, and `FreightRackServiceDressing`—stay outside their attachment surfaces, do not widen walkable decks or fill station voids, and expose deterministic per-instance counts of 16 / 33 / 41 visible primitives at Low / Medium / High. Quality changes reveal prebuilt static detail without rebuilding geometry. The dressings and their placement are `modern_interpretation`, and their audited budgets are not a measured representative-Windows performance result.
- The four station modules—Aft Junction Stack, Habitat Spine, Fleet Dock Comb, and Jovian Freight Berth—now publish one shared `StationModuleContract` surface: stable module ID, connection anchor, route-marker registry, local footprint, evidence metadata, semantic component roster, collision/authority/performance reports, a reversible enable/disable lifecycle, and a validation API. `ShipyardWorld` owns a `StationRouteRegistry` that assembles them into one station graph and rejects duplicate module IDs, missing evidence, non-finite transforms, overlapping authority IDs, dangling connections, two modules claiming the same slot, and slots claimed by more than two endpoints. Adjacency is **declared and non-metric**: each module tags exactly one route marker—its outward `approach` face—with the connection slot it names, and the world publishes the matching hub endpoint pointing at the real lattice geometry the player crosses (`AftModuleConnector`, `StarboardBerthNode`, `FleetDockCombConnectorDeck`, and `RegistryPodDeck`). The live station reports four modules, four hub endpoints, four edges, and zero dangling or overclaimed slots across all 29 route markers; internal waypoints, room anchors, the deferred VIP landmark, the sealed habitat branch, and the three dock thresholds are deliberately excluded from the graph. The registry is a deep-copied report for tests and UI only—it assigns no gameplay authority and does not by itself prove a walkable route, which remains the job of the surface-playability and per-module integration suites.
- Modern HUD, configurable pause menu, tiered Forward+ desktop lighting/effects, procedural soundscape, and native Windows x86-64 desktop export configuration.

The current procedural station, player, and spacecraft geometry is **authored prototype work, not the target production quality**. The presentation target is a realistic-looking, polished stylised high-end PC treatment—not literal photorealism—while retaining Keth's broad clean silhouettes, readable colour, and playful spatial identity. The Torrent reconstruction v1 puts a low-section faceted, longitudinally dominant macroform ahead of its mechanical detail: compact pointed nose, stepped planes, raised spine, blunt aft box, subordinate round housings and the dominant U-like aft rail silhouette. Recessed engine internals, gear and docking hardware, service panels/vents, canopy seals/latches, restraints, instruments and controls remain modern detail rather than recovered construction. Arrow and Jovian remain visually distinct procedural craft, while the central berth adds a coherent first environmental hero-cell treatment. Zenith adds a project-original Blender-authored partial reconstruction whose removable source core preserves the B7-observed wide pale delta/arrow read; its modern systems remain separately tagged. Its close/far presentation contains 47,274 / 5,412 triangles in 22 runtime meshes and surfaces, while 24 mixed runtime shapes independently own collision. The live sky now reads as near-black dense stars with large simple colour bodies; the project-original nebula is only a faint cover rather than the dominant composition. The cockpit's anti-glare surfaces, restrained instruments, practical light and measured sight corridor improve material and pilot-eye readability without making its procedural shell photoreal or historically authenticated. This source-directed revision has not yet received final human visual sign-off, and substantial enemy-craft, freighter-interior, station-wide and final authored ship modelling work remains.

Torrent, Arrow, Jovian, and Zenith hulls use project-original mapped materials; the authored central berth and Zenith presentation bind registered material sets through UV0. Mipmaps and material-specific metalness/roughness response remain enabled. These maps are interim procedural aids—not measured scans, recovered textures, definitive high/low-poly bakes, hand-authored final maps, or complete ORM/metalness sets. Aft Junction and Habitat shells currently reuse the Arrow albedo without the new derivative maps. The cockpit anti-glare albedo is a separate project-original image created with OpenAI's built-in image generation tool; it is modern material work, not a surviving or reconstructed Keth asset. Asset provenance and exact generation prompts are recorded in `ASSETS.md`.

Forward+ visual profiles provide explicit performance tiers rather than implying that every machine can afford the high-end effects. `High` enables SSAO, SSIL, TAA, AgX tone mapping, glow, and subtle volumetric fog; `Medium` retains a reduced effects set, while `Low` prioritizes broad compatibility and frame rate. The High profile is the visual target, but its performance budget has not yet been established on representative Windows hardware.

The station revision is **source-informed, not a recovered floor plan or authenticated reconstruction**. Its dimensions, individual arm/node geometry, operations pod and berth adjacency, terminal and indicator, Habitat placement, freight branch, materials, signage, operational roles and rails, structural dressing, machinery placement, animation, and soundscape remain modern or inferred. The operational-lattice audit records `modern_interpretation` and explicitly rejects authenticated original geometry, placement, layout, and audio. The Aft Junction's red VIP access and Habitat's side branch are deliberately locked/deferred landmarks; unsupported interiors have not been invented. The Torrent class name/role is creator-supported, and B5 provides a high-confidence name-to-model link, but B5's June 2011 upload date does not establish its recording date or live build revision. Reconstruction v1 now follows the observed broad macroform and colour cues, but reconstruction detail remains partial, the metre envelope is a modern normalization, and continuity with the 2009 model is unproved. Embodied central boarding and the red seat are directly supported; the amber panel's function and the circular housings' function remain unknown. Access mechanics, canopy, controls, cameras, propulsion internals, weapons, landing gear, materials, handling and berth are modern design. B7 supplies a separately versioned high-confidence Zenith name-to-model lock and bounded broad macroform, not exact geometry, dimensions, systems or handling; the upload date does not establish recording/build date, and the A5/B7 Interceptor versus A9 Fighter conflict remains explicit. Its current access, cockpit, systems, materials, balance and Fleet Dock placement are modern. Arrow's name/role/two-pod count and Jovian's name/light-freighter role are supported, but their current name-to-model mappings and silhouettes remain unauthenticated and isolated from Torrent- and Zenith-specific evidence claims. See [RESEARCH.md](RESEARCH.md), the machine-readable [source ledger](docs/research/source_ledger.json), [station topology](docs/research/STATION_TOPOLOGY.md), and [ship evidence matrix](docs/research/ship_evidence_matrix.json) for the research boundary; see the [B5-observed Torrent specification](docs/TORRENT_2011_RECONSTRUCTION_SPEC.md) and [B7-observed Zenith specification](docs/ZENITH_B7_RECONSTRUCTION_SPEC.md) for the bounded art targets, and [ASSETS.md](ASSETS.md) for project-asset provenance.

## Run locally

Install [Godot 4.7.1](https://godotengine.org/download/archive/4.7.1-stable/) and open `project.godot`. On a fresh checkout, let the editor import the PNG assets before running the game:

```bash
godot --editor --path .
```

The project starts at 1280×720 and scales its 1600×900 UI viewport to the window. Press `E` on the title screen to begin. Press `Esc`, then choose **Settings**, to adjust and persist runtime preferences.

## Runtime settings

The pause settings panel exposes separate ship and on-foot mouse sensitivity and invert-Y options, shared camera FOV, Master/Ambience/Engines/Weapons/UI volumes, Low/Medium/High graphics profiles, and Windowed/Borderless/Fullscreen display modes. Changes preview immediately; **Save settings** stores validated values through Godot's `ConfigFile` API at `user://settings.cfg`, while **Restore defaults** reapplies and saves the authored defaults.

Modern and Classic control descriptors are also shown. They document the current modern layout and the surviving `Y`/`X`/`H`/`F`/`G`-style legacy actions; Classic is currently a descriptor, not a complete alternate `InputMap` or a claim that one historical build's controls have been reconstructed exactly.

## Controls

On foot:

| Input | Action |
|---|---|
| `W A S D` | Move |
| Mouse | Look |
| `Shift` | Sprint |
| `Space` | Jump |
| `E` | Interact / board / operate station doors |

In any current prototype craft:

| Input | Action |
|---|---|
| `Y` | Start engines (creator-listed across documented builds) |
| `X` | Stop engines (fixed-era meaning; some original-era listings used `X` for land) |
| `W / S` | Throttle |
| Mouse | Yaw / pitch attitude |
| `A / D` | Yaw left / right |
| `Up / Down` | Pitch up / down |
| `Q / R` | Roll left / right |
| `V` | Toggle chase / cockpit view |
| Mouse wheel | Adjust chase-camera distance |
| `Shift` | Boost |
| `Ctrl` or right mouse | Brake |
| `H` | Hover (creator-listed in later original-era builds) |
| `F` or left mouse | Fire (`F` is creator-listed; mouse fire is new) |
| `G` | Barrel roll (fixed-era binding) |
| `L` | Landing assist (modern prototype binding) |
| `E` | Exit while safely landed with engines offline |
| `Esc` | Pause; open **Settings** from the pause panel |
| `F1` | Toggle controls |

Common SDL-style gamepad while piloting (current partial support, `0.18` stick/trigger deadzone):

| Input | Action |
|---|---|
| Left stick vertical / horizontal | Throttle / yaw |
| Right stick vertical / horizontal | Pitch / roll |
| Left trigger / right trigger | Brake / fire |
| Left-stick press (`L3`) | Boost |
| `A` / `B` | Hover / barrel roll |
| `X` / `Y` | Interact / toggle chase-cockpit camera |
| Start | Pause |

Gamepad engine start/stop, landing assist, chase-distance adjustment, and the controls overlay are not yet bound, so the current build is not controller-only.

The historical bindings changed between builds. Movement handling, mouse flight, boost, brake, landing assist, weapon/damage values, and AI behaviour are current remake design rather than recovered simulation parameters.

## Validation and export

```bash
# For non-audio runs (including matrix runs), add --audio-driver Dummy to keep tests silent.
# Example:
# godot --headless --audio-driver Dummy --path . --script res://tests/smoke_test.gd

# Import and parse every project resource.
godot --headless --editor --path . --quit

# Run the project smoke tests.
godot --headless --audio-driver Dummy --path . --script res://tests/smoke_test.gd

# Check that steering remains upright and momentum follows the visible nose.
godot --headless --path . --script res://tests/flight_input_test.gd

# Audit explicit keyboard/gamepad mappings, deadzones, and conserved mouse-motion sampling.
godot --headless --path . --script res://tests/control_mapping_test.gd

# Validate active-camera velocity projection and the separate HUD flight-path cue.
godot --headless --path . --script res://tests/flight_path_cue_test.gd

# Exercise the combined input, chase-camera, cockpit-sight, telemetry, and cue closure contract.
godot --headless --path . --script res://tests/flight_quality_closure_test.gd

# Exercise the opposing interceptor's reusable combat lifecycle.
godot --headless --path . --script res://tests/combat_test.gd

# Check persisted settings defaults, validation, round trips, and safe application.
godot --headless --path . --script res://tests/runtime_settings_test.gd

# Validate the fixed global procedural audio bank, routing, and detach/re-entry lifecycle.
godot --headless --path . --script res://tests/audio_director_test.gd

# Check Forward+ quality profiles and renderer-safe fallbacks.
godot --headless --path . --script res://tests/forward_visual_test.gd

# Audit the deterministic source-bounded star shell and four presentation-only colour bodies.
godot --headless --path . --script res://tests/space_backdrop_test.gd

# Validate the typed source ledger, station topology, ship gates, rights boundary, and B5 chronology.
godot --headless --path . --script res://tests/research_evidence_test.gd

# Audit registered hull/deck PBR maps and deterministic derivative generation.
godot --headless --path . --script res://tests/fleet_pbr_test.gd
godot --headless --path . --script res://tests/material_map_generation_test.gd
godot --headless --path . --script res://tests/station_triplanar_material_test.gd

# Check the hero craft's impact, staged damage, degradation, destruction, and cleanup contract.
godot --headless --path . --script res://tests/hero_damage_visual_test.gd

# Validate the fixed, presentation-only travelling-pulse pool and its re-entrant callbacks.
godot --headless --path . --script res://tests/pulse_weapon_presentation_test.gd

# Exercise the production three-profile/four-flyable ship-audio and one-pool quality integration.
godot --headless --path . --script res://tests/ship_audio_rig_test.gd
godot --headless --path . --script res://tests/hero_quality_integration_test.gd

# Audit the original authored combat WAV bank and exact authority-to-positional-cue routing.
godot --headless --path . --script res://tests/combat_audio_asset_test.gd
godot --headless --path . --script res://tests/combat_audio_integration_test.gd

# Audit the B5-linked Torrent reconstruction boundary, detailed construction, and realistic-stylised pilot rig.
godot --headless --path . --script res://tests/torrent_2011_reconstruction_test.gd
godot --headless --path . --script res://tests/torrent_hero_art_test.gd
godot --headless --path . --script res://tests/pilot_visual_test.gd

# Check pause-settings widgets, signal wiring, snapshots, and accessibility labels.
godot --headless --path . --script res://tests/settings_ui_test.gd

# Prove repeatable physical fleet selection, berth use, crash recovery, and regeneration.
godot --headless --path . --script res://tests/sandbox_loop_test.gd

# Exercise the integrated two-level station route, stairs, door, and operations room.
godot --headless --path . --script res://tests/station_expansion_test.gd

# Audit central-berth construction, evidence boundaries, PBR scope, and safe routes.
godot --headless --path . --script res://tests/central_berth_authored_asset_test.gd
godot --headless --path . --script res://tests/central_berth_hero_test.gd

# Validate immutable authority-aware ship input snapshots and local input production.
godot --headless --path . --script res://tests/ship_command_test.gd

# Validate generic, source-registered authoritative hitscan and damage resolution.
godot --headless --path . --script res://tests/combat_resolver_test.gd

# Prove that both production fire paths use the shared live resolver and lifecycle proxies.
godot --headless --path . --script res://tests/live_combat_integration_test.gd

# Validate reusable ship definitions, oriented physical berths, and reservation leases.
godot --headless --path . --script res://tests/ship_definition_berth_test.gd

# Validate schema-v2 full-hull dock acceptance, exact lease authority, obstruction, and abort cleanup.
godot --headless --path . --script res://tests/landing_clearance_test.gd

# Validate one modern three-state visual feedback component per production berth.
godot --headless --path . --script res://tests/ship_berth_feedback_test.gd
godot --headless --path . --script res://tests/ship_berth_feedback_world_test.gd

# Validate canonical collision layers and dedicated physical boarding areas.
godot --headless --path . --script res://tests/collision_matrix_test.gd
godot --headless --path . --script res://tests/ship_boarding_area_test.gd

# Validate door state/collision plus the reusable Aft Junction module in isolation.
godot --headless --path . --script res://tests/station_door_test.gd
godot --headless --path . --script res://tests/aft_junction_stack_test.gd

# Audit the B2-bounded comb module and its collision-backed production-world connection.
godot --headless --path . --script res://tests/fleet_dock_comb_test.gd
godot --headless --path . --script res://tests/fleet_dock_comb_integration_test.gd

# Exercise real player focus, use, and traversal across station interactables.
godot --headless --path . --script res://tests/station_interaction_flow_test.gd

# Verify collision-backed walkable station surfaces and the reachable route roster.
godot --headless --path . --script res://tests/station_surface_playability_test.gd

# Validate the Habitat module and its real shared-world connector/traversal.
godot --headless --path . --script res://tests/habitat_spine_test.gd
godot --headless --path . --script res://tests/habitat_integration_test.gd

# Audit deterministic, non-colliding Full/Gantry/Service Arm/Drone Patrol activity profiles.
godot --headless --path . --script res://tests/station_operations_activity_test.gd

# Audit finite-range positional procedural machinery loops and servo/latch cues.
godot --headless --path . --script res://tests/station_machinery_ambience_test.gd

# Audit collision-free outer-face dressing and its fixed Low/Medium/High counts.
godot --headless --path . --script res://tests/station_structural_service_dressing_test.gd

# Exercise the exact four-by-four-by-four operational lattice in the live station.
godot --headless --path . --script res://tests/station_operational_lattice_test.gd

# Validate the distinct provisional Arrow and its Arrow-first sandbox/guided-state boundary.
godot --headless --path . --script res://tests/arrow_recon_ship_test.gd
godot --headless --path . --script res://tests/arrow_sandbox_integration_test.gd

# Exercise adversarial fleet berth, damage, recovery, and mission-lifecycle edges.
godot --headless --path . --script res://tests/fleet_lifecycle_safety_test.gd

# Prove destruction-safe boarding/disembarking transitions and later craft reuse.
godot --headless --path . --script res://tests/fleet_transition_destruction_test.gd

# Exercise whole-Main detach/re-entry, resolver replay history, audio rebuilds, and live-source reconnection.
godot --headless --path . --script res://tests/main_reentry_quality_test.gd

# Exercise regeneration deadlines across whole-tree re-entry and terminal mid-landing reuse resets.
godot --headless --path . --script res://tests/regeneration_reentry_safety_test.gd

# Validate reusable moving-interior frame motion, authority gates, gravity, and exit velocity.
godot --headless --path . --script res://tests/moving_interior_frame_test.gd

# Validate the provisional Jovian's evidence boundary, geometry, connected interior, and lifecycle.
godot --headless --path . --script res://tests/jovian_light_freighter_test.gd

# Validate the port freight module, world transform, and physical freighter fit.
godot --headless --path . --script res://tests/jovian_freight_berth_test.gd
godot --headless --path . --script res://tests/jovian_freight_berth_transform_test.gd
godot --headless --path . --script res://tests/jovian_freighter_berth_fit_test.gd

# Exercise the real four-craft production registry and Jovian-first sandbox path.
godot --headless --path . --script res://tests/jovian_sandbox_integration_test.gd

# Exercise the accelerated integrated mission path and its key interactions.
godot --headless --path . --script res://tests/vertical_slice_test.gd

# Prove that guided Torrent completion requires victory, strict docking, shutdown, and physical disembarkation.
godot --headless --path . --script res://tests/torrent_sortie_completion_test.gd

# Validate forgiving, collision-safe boarding discovery and deterministic seat selection.
godot --headless --path . --script res://tests/boarding_accessibility_test.gd

# Exercise resolver replay hardening and production command-consumer delivery across re-entry.
godot --headless --path . --script res://tests/combat_reentry_replay_test.gd
godot --headless --path . --script res://tests/command_consumer_delivery_test.gd

# Exercise controller-driven physical sortie acquisition and lifecycle behaviour.
godot --headless --path . --script res://tests/controller_physical_sortie_test.gd
godot --headless --path . --script res://tests/controller_sortie_lifecycle_test.gd

# Validate broad landing-assist acquisition while preserving exact final docking authority.
godot --headless --path . --script res://tests/landing_assist_accessibility_test.gd

# Audit the authored pilot/Torrent assets, runtime identity, and collision-to-art alignment.
godot --headless --path . --script res://tests/pilot_blender_asset_test.gd
godot --headless --path . --script res://tests/pilot_reentry_identity_test.gd
godot --headless --path . --script res://tests/torrent_authored_asset_test.gd
godot --headless --path . --script res://tests/torrent_blender_hero_asset_test.gd
godot --headless --path . --script res://tests/torrent_collision_art_alignment_test.gd

# Audit the bounded B7-observed Zenith runtime, authored asset, and full Fleet Dock lifecycle.
godot --headless --path . --script res://tests/zenith_interceptor_test.gd
godot --headless --path . --script res://tests/zenith_authored_asset_test.gd
godot --headless --path . --script res://tests/zenith_fleet_dock_integration_test.gd

# Render and validate 27 distinct evidence frames (requires a graphical display).
xvfb-run -a godot --path . --script res://tests/capture_scenes.gd

# Render 12 HUD-free 2560x1440 hero-cell frames (requires a graphical display).
xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440 --rendering-method forward_plus --script res://tests/capture_hero_cell.gd

# Render seven HUD-free 2560x1440 operational-lattice/backdrop frames (requires a graphical display).
xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440 --rendering-method forward_plus --script res://tests/capture_station_operations.gd

# Render twelve HUD-free 2560x1440 lease-state views across all four berths (requires a graphical display).
xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440 --rendering-method forward_plus --script res://tests/capture_berth_feedback.gd

# Render seven bounded Zenith views (requires a graphical display and final human art review).
xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440 --rendering-method forward_plus --script res://tests/capture_zenith_visuals.gd

# Export a Windows x86-64 build after installing official export templates.
godot --headless --path . --export-release "Windows Desktop" builds/windows/MuddsShipyards.exe
```

`flight_input_test.gd`, `control_mapping_test.gd`, `flight_path_cue_test.gd`, and `flight_quality_closure_test.gd` are deterministic handling and presentation regressions, not a claim that the controls are fully tuned. The requested human feel pass remains open. The command list above enumerates the 77 `tests/*_test.gd` headless suites in the current source tree. The recorded definitive v0.12 Godot 4.7.1 matrix predates the added station-surface and station-triplanar suites: it recorded an editor/import exit of `0` in 2,844 ms and exactly 75 of 75 suite exits of `0`, with 6,969 anchored `PASS:` assertions and exactly one terminal sentinel per suite (73 `OK`, two `PASS`). Its logs contained zero timeout, failure, error, fatal, RID, ObjectDB, resource, or orphan diagnostics; the only warnings were 76 generic root-startup warnings. The 452-file runnable-source scope remained byte-identical before and after at ordered-manifest SHA-256 `2115dddd6c11fa751c804b1e3140e0b2cf1b476b478675fe17ed2f7383e68792`. The exact results table, sentinel validation, and ordered process-hash aggregate have SHA-256 values `521d9bfd278ddec4ba0623f070b08487d962e7748d9eeafce09134f9125fe349`, `c243dfea866cb07a01343ad0300db10f9a72a12948b5a7c9a1d6e76c45ac1e05`, and `f0338503e70ca534a666b04c2ee41e4cb22d180f45fa7818ce110a6cbd493b10`. The now-superseded post-ledger/Fleet-Dock-Comb 72-suite, 6,673-assertion matrix remains historical, as do the earlier 69-, 54-, 44-, and 40-suite checkpoints; none supersedes the v0.12 result. Three shutdown-only Dummy-audio resource diagnostics found across preliminary historical passes were traced to test teardown racing an active WAV; the affected harnesses now explicitly release the presentation bank across a mixer boundary, and the definitive matrices plus repeated verbose focused runs were clean.

The following rendered evidence is a now-superseded v0.10 checkpoint, not validation of the current v0.12 target source or any v0.12 build. Under Godot 4.7.1 on the Linux llvmpipe X11 validation host, all four v0.10 graphical harnesses exited `0` with their exact success sentinels. That set contained 54 frames: 27 main gameplay states at 1280×720, plus 12 HUD/CanvasLayer-free Torrent hero-cell views, six operational-lattice views, and nine berth-feedback views at 2560×1440 Forward+. All 54 declared PNGs were present with the correct type and dimensions and had 54 unique full-file SHA-256 hashes. The closest pair in each harness passed its own near-duplicate thresholds: main mean difference `0.02177` / changed fraction `0.081`, hero `0.05385` / `0.242`, station `0.05045` / `0.300`, and berth `0.00085` / `0.0039`. Original-resolution human inspection of flight, dogfight, touchdown, disembark, Central approach/occupied, and Jovian approach/occupied found no blank, corrupt, or clipped blocker; the landing text was legible and occupied mint cues visibly differed. The Jovian cue was subtler and partly obscured by the large freighter but remained visible and nonblocking.

For that historical v0.10 pass, the critical 255-file capture scope (`project.godot`, `export_presets.cfg`, `default_bus_layout.tres`, `scripts/`, `scenes/`, `tests/`, `assets/`, and `tools/`) remained byte-identical before and after at SHA-256 `7b00e37f8af4c857665bf12f840717cd0d8ebe1a4d56b3e5932085901839e11d`. Logs contained zero `ERROR`, `SCRIPT ERROR`, or `FATAL` diagnostics, harness-failure lines, or failed sentinels. Each process emitted only the generic root startup warning and the known seven retained Texture RID shutdown warning after its success sentinel. The runners deliberately stage positions, lease transitions, or camera compositions and perform automated visual checks; this historical evidence and the representative screenshot review do not prove v0.12 behaviour, an uninterrupted human playthrough, final human art sign-off, native-GPU or native-Windows behaviour, representative performance, audibility, or historical authenticity. Broader human visual review remains open.

The final Zenith-specific X11 Forward+ capture passed all seven declared 2560×1440 frames with source bytes frozen and distinct semantic images, and original-resolution review found no blocker. Its evidence-manifest, 286-file source-aggregate, and raw-log SHA-256 values are respectively `6e6d66b3d6a7a1254da6da8ce1259b5c593f7820312c74ed199c4712a529c89a`, `68d23207b9841463c61273b8c3de610a25519e82dc56f46eeddfb7befdef77c4`, and `6da081c58304bb152d7553669395fd481fd64862276a944fd17be6cedd117704`. The log's only post-sentinel diagnostic was the known seven-Texture-RID capture warning. These seven staged views and their bounded visual review validate source-current presentation integration, not historical fidelity or authentication, complete-project craftsmanship sign-off, native-Windows behaviour, representative performance, or an uninterrupted player-controlled sortie.

During that v0.10 capture pass, Godot 4.7.1 on the Linux llvmpipe validation host reported seven retained Texture
RIDs at process shutdown after the central berth's `ReflectionProbe3D` renders.
Earlier isolation reduced this to one reflection-atlas colour buffer and its six
views; repeated probe cycles did not increase the count. The warning occurs only
after each successful capture sentinel. Treat it as a renderer teardown
limitation, not proof of a growing gameplay leak; native-GPU validation is still
required.

Windows builds are written to `builds/windows/` and are excluded from version control. The now-superseded v0.11 Windows x86-64 export after the Phase-1 ledger/B5 chronology/Fleet-Dock-Comb checkpoint completed with exit code `0`. `builds/windows/MuddsShipyards.exe` was 152,061,840 bytes, was modified `2026-08-14 03:19:42.759480226 +0100`, and had SHA-256 `bf2db8ab56d42ac7063fe7cbc894c0f623f3ddfa96f54cc4d5c7105ad9822d98`. It was a PE32+ Windows GUI x86-64 executable, stripped to an external PDB, with 12 sections, file/product version `0.11.0.0`, and product name `Mudds Shipyards`. Its zero-offset/zero-size PE Security Directory recorded no embedded Authenticode certificate; external catalog signing was not assessed. An isolated Linux headless Dummy-audio run of the embedded main pack completed 300 frames and exited `0`, with no diagnostics after the engine banner. This is historical packaged-startup evidence predating Zenith, not evidence for v0.12.

The source-current v0.12 Windows x86-64 artifact at `builds/windows/MuddsShipyards.exe` is 153,657,032 bytes, was modified `2026-08-14 07:42:29.806068718 +0100`, and has SHA-256 `014b6e443822cf263d8811af946bda43f29bf10f8986b0dabb6a6d804282b669`. It is a 12-section PE32+ x86-64 Windows GUI executable with product name `Mudds Shipyards`, file description `Modern standalone Keth Shipyards fan remake prototype`, and file/product version `0.12.0.0`. Its zero-offset/zero-size Security Directory records no embedded Authenticode certificate; signing remains pending. The executable embeds a 44,428,988-byte format-4 Godot 4.7.1 PCK at offset 109,228,032 with flags `2`, and has no external PCK. Isolated candidate and promoted-artifact Linux headless Dummy-audio smokes each completed 300 frames in about 3.72 seconds with exit `0` and clean diagnostics. This proves bounded package structure and Linux startup only, not native-Windows behaviour, representative performance, audibility, permission, or uninterrupted human play.

For historical context only, the now-superseded v0.10 Windows x86-64 export completed with exit code `0`. `builds/windows/KethShipyardsReforged.exe` was 137,356,496 bytes, was modified `2026-08-13 08:25:39.484373665 +0100`, and had SHA-256 `fe41f1b52e43c6e11b3fd3782088a66efb851b6e70ca0ea49a99f8c5126d6147`. It was a PE32+ AMD64 Windows GUI executable with 12 sections, `0.10.0.0` file/product versions, product name `Keth Shipyards: Reforged`, and file description `Early standalone Keth Shipyards fan prototype`. Its zero-offset/zero-size PE Security Directory recorded no embedded Authenticode certificate; external catalog signing was not assessed.

That historical v0.10 executable's embedded Godot 4.7.1 format-4 PCK contained exactly 161 unique entries; its sorted-entry manifest had SHA-256 `765f5d31b73e45e119d45fc62e67dc71684b1931758b6fbeaa1ec753bec4091a`. Relative to v0.9, the exact 12 additions were the compiled-script/remap pairs and compiled-scene/remap entries for `ShipAudioRig`, `PulseWeaponPresentation`, and `ShipBerthFeedback`. All three scripts and all three scenes loaded from the mounted pack. The pack contained zero `tests/`, `artifacts/`, or `tools/` paths and zero raw `.gd`, `.tscn`, or `.tres` files. An isolated Linux Godot 4.7.1 headless Dummy-audio main-pack smoke ran 300 frames in 3.258 seconds and exited `0`, with zero error, warning, leak, or orphan markers. The 133-file release scope remained byte-identical before and after at SHA-256 `1db8afc2e44d809c5df2802885e292e9181d3df96e598e7f63bc2c8f12166b87`. This is historical package/Linux-startup evidence only—not evidence for v0.12, native-Windows behaviour, representative hardware performance, audible output, embedded/external signing beyond the stated checks, or an uninterrupted human playthrough.

An uninterrupted native-Windows run and no-shortcut human playtest remain pending for the v0.12 artifact, as do representative native-Windows performance, audibility, signing, and release-permission work. Focused tests use deterministic fixtures, while the vertical, Jovian, Zenith, operational-lattice, berth-feedback, and capture integrations deliberately accelerate, reposition, seek, drive lease state, or directly stage some states. They verify bounded behaviour and integration, not the feel or reliability of an uninterrupted player-driven mission.

## Project status

This is an **early Phase 2 prototype with a settled, bounded Phase 3 operational-lattice slice and bounded Phase 4 foundations**. It is not yet the Phase 2 authenticity, quality, or acceptance target and is not the complete station, original fleet, combat game, multiplayer game, or multi-crew game. The exposed lattice, Aft Junction, Habitat, port freight branch, fixed-rail activity, positional machinery beds, outer-face dressings, lease-state berth feedback, procedural ship profiles, and pulse-weapon presentation are evidence-bounded modern interpretations rather than source-traceable recovered features; C1's exact build provenance remains unverified, and no historical layout, docking display, weapon effect, audio, or Zenith berth placement is claimed. The operational drones do not implement a navigation graph or autonomous logistics. The B5-linked Torrent and B7-observed Zenith identities are locked at high confidence within their respective versioned source chains, and both bounded partial reconstructions are implemented, but their exact recording/build provenance, detailed reconstruction and continuity with 2009 remain unresolved; Zenith also retains the A5/B7 Interceptor versus A9 Fighter conflict. Arrow and Jovian still lack model locks. Exactly four prototype craft—two bounded partial reconstructions and two provisional modern candidates—do not constitute recreation of the original fleet, and none is authenticated. The live `ShipCommand`, shared `CombatResolver`, strict berth-lease contract, and `MovingInteriorFrame`/tangent-gravity paths are reusable local-authority foundations rather than multiplayer or networking. The single range-defence encounter and damage presentations remain an initial combat implementation rather than a complete component-damage, repair, shield, weapon-variety, or respawn system. Immediate priorities include a no-shortcut native-Windows human playtest, native-Windows performance and audibility checks, signing and release permission, completing the Torrent and Zenith evidence/reconstruction gaps, extending authored geometry and final PBR work beyond the bounded station cells, and continuing the complete station/fleet work. Phase 3 remains incomplete, and Phases 3–9 still require the full shipyard, researched original and expanded fleets, broader combat, multiplayer/multi-crew support, nearby activities, and extensive accessibility, performance, animation, authored audio, UI, networking, and release polish.

Keth Shipyards and its original designs belong to their respective creator/rightsholders. Before any public release or commercial use, obtain written permission and complete a separate name, asset, and design-rights review. All code and newly produced assets in this prototype are original project work unless noted otherwise.
