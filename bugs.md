# Review candidates

Previously identified candidates were reproduced and addressed in the current branch:

- `scripts/combat/live_combat_authority.gd`: receipt allocation now uses a monotonic
  64-bit session allocator for deferred presentations, with explicit fail-closed
  saturation behavior.
- `scripts/audio/station_machinery_ambience.gd` and
  `scripts/audio/combat_audio_presentation.gd`: playback acceptance now includes an
  explicit backend-aware seam and atomic detach-on-rejection behavior.
- `scripts/game/game_flow.gd`, `scripts/effects/hero_damage_presentation.gd`,
  and `scripts/world/shipyard_world.gd`: whole-Main teardown now clears owner-side
  deferred presentation queues to prevent stale replay after re-entry.

## Open candidates — 2026-08-16 human playtest intake — **ALL FOUR CLOSED**

Reporter: project owner (`loginpeople123@gmail.com`), 2026-08-16, verbatim, four
reports across two messages:

1. *"The Arrow-class recon ship candidate — I LOVE this but the walkway to enter
   isn't wide enough to get around to the side — you can get in this one by
   jumping over the rails but can you expand the walkway a bit?"*
2. *"The Torrent-class interceptor — the runway here is PERFECT but it's slightly
   overlapping the walkway mentioned above and it causes a slight texture glitch
   — is it possible to fix this? Not a major issue."*
3. *"The Zenith ship looks good but there's a strange floating block + there's an
   invisible barrier around it that you can sort of climb on."*
4. *"The Arrow-class recon ship candidate — you only seem to be able to enter it
   when you are standing inside of the engine on the walkway."* — refined by the
   reporter to *"I mean the option to enter never appears when you're standing to
   the side of the ship"*.

Configuration for every measurement below: Linux (WSL2 6.18.33.2), Godot
4.7.1.stable.official.a13da4feb, `--headless` with `--audio-driver Dummy` for
physics and geometry probes, `xvfb-run -a -s "-screen 0 1920x1080x24" ...
--display-driver x11 --rendering-driver vulkan` for frames. Failure frequency
10/10 deterministic for every item.

---

### PORT-DECK-001 — the Arrow's berth deck is smaller than the craft parked on it, and its rails fence the only approach

- Status: `CLOSED` (fixed 2026-08-16). Severity **P1** — an unintended jump to
  reach a craft.
- Two independent defects at one site, both measured:
  - **Structure.** `PortBerthNode` was `Vector3(12.0, 1.2, 17.0)`, spanning
    `x = -49.000 … -37.000`. `ArrowHullCollision` is 12.2 m long, spanning
    `x = -49.450 … -37.250`, so the nose projected **0.450 m** and the tail
    **0.250 m** past the deck, with **2 of 4** footprint corners over open space.
    The four berth cue strips at `x = -50.100` and `-35.900` lay **entirely off**
    the deck they mark, nearest edge 0.940 m clear of any structure.
  - **Reachability.** `BranchRail` ran `x = -42.5 … -11.5` at both `z = 12.0` and
    `z = 19.0` — five metres past the 7 m branch arm it guards and straight across
    the berth node — at `y = 1.06 … 1.24`. The parked Arrow's sensor wing
    (`x = -44.200 … -39.300`, `y = 1.790 … 2.270`) blocks a standing capsule at the
    only gap in that rail, and its hull (`z = 13.950 … 17.050`) blocks the
    corridor's middle. The 7 m approach corridor was therefore sealed on both
    sides and the walkway beside the craft could only be entered over a rail —
    exactly the reported jump.
- Fix (`scripts/world/shipyard_world.gd`):
  - `PortBerthNode` `12.0 → 16.8` m about the unchanged centre `x = -43.0`, so the
    deck spans `x = -51.400 … -34.600`. The craft now has 1.950 m of apron at the
    nose and 2.650 m at the tail and a player can walk a full circuit around it.
    The cue strips land 1.300 m inside each edge, so `pad ⊃ cue ⊃ parked craft`
    holds for the first time — **no cue constant was re-authored** and the
    berth-feedback contract did not move.
  - `BranchRail` / `BranchRailPost` now span only their own arm (port
    `-34.6 … -12.5`, starboard `12.5 … 37.0`), five posts per rail as before.
  - Both branch arms butt their berth node instead of overlapping it by 0.5 m,
    which also removed 3.5 m² per side of exactly-coplanar deck.
  - `RegistryPodDeck` / `RegistryPodThreshold` deliberately **do not** widen; see
    `docs/design/ARROW_BERTH_CUE_DECK_DECISION.md` for the measurement that
    answered that question (widening them puts the pod deck under the freight
    connection lattice and creates three new coplanar decks on a walked route).
- Regressions (`tests/station_traversal_defect_witness_test.gd`):
  `_test_arrow_berth_can_be_walked_around` (one standable cell on each face of the
  craft must be in the no-jump flood from the production spawn),
  `_test_arrow_berth_rails_no_longer_fence_the_walkway` (production controller,
  bounded, no jump, from the branch-arm handoff to both flanks: measured
  `z = 15.5 → 8.129` and `15.5 → 22.871`, 7.37 m each, never leaving the deck),
  `_test_parked_craft_are_fully_supported_by_their_berth_decks` (all four
  footprint corners of all four craft: `unsupported_corners=0` for each).

---

### PORT-BOARDING-001 — the Arrow's boarding volume is centred underneath its own wing

- Status: `CLOSED` (fixed 2026-08-16). Severity **P1** — interaction cannot be
  acquired from its intended approach.
- The fleet-wide boarding volume is one 4.5 m `SphereShape3D` on the craft's own
  boarding marker. The Arrow's marker is at ship-local `(-2.45, -0.02, 0.15)`,
  which in world terms is `(-42.85, 1.13, 17.95)` — **inside its own
  `ArrowWingCollision` footprint**. No standing capsule can occupy the centre of
  that sphere, so the prompt only appeared where the sphere happened to poke out
  past the wing.
- Measured on the live berth deck, 0.5 m grid, production `PlayerController`
  teleported to each standable cell and `GameFlow._refresh_interaction_targets()`
  called: of the cells a capsule can stand on, the **entire starboard flank from
  `z = 7.0` to `z = 10.5` offered no prompt**, and the nearest cells that did
  offer one on the natural approach were `x = -36.5 … -36.0, z = 15.5 … 17.0` —
  inside the port `EfficientEngineHousing` (`x = -39.500 … -36.400`,
  `y = 1.510 … 2.670`), which has no collision. That is the reported "only when
  you are standing inside of the engine".
- Fix (`scripts/ships/arrow_recon_ship.gd`, `_add_flank_approach_range`): the
  inherited sphere is left **exactly** as published — it is a fleet-wide contract
  and `tests/boarding_accessibility_test.gd` pins its 4.5 m radius on all four
  craft — and a second, craft-shaped `ArrowApproachRange` box is added beside it,
  centred on the hull with half extents `6.9 × 1.4 × 7.6` m. With the production
  player's own 2.35 m interaction sphere that reaches 9.25 / 9.95 m, covering
  every standable metre of the 16.8 × 17.0 m berth deck (half extents 8.4 / 8.5)
  on both flanks and around nose and tail. It stops 2.55 m short of a point 7.0 m
  off the boarding marker along the lateral axis, so the bare-sphere 7.0 m
  fallback boundary `boarding_accessibility_test` pins is still exercised, not
  widened; that suite is unchanged and green.
- Regression (`tests/station_traversal_defect_witness_test.gd`
  `_test_boarding_prompt_is_offered_all_round_each_craft`): a ring of 3 / 5 / 7 m
  at 16 bearings around every parked craft, filtered to standable points, each
  driven through GameFlow's own `_refresh_interaction_targets()` seam. **Arrow:
  19 of 19 standable ring points prompt** (43 of 105 sampled points were silent
  before this pass).
- **Recorded, not fixed — the other three craft.** Measured by the same ring:
  `TorrentInterceptor` 15 of 27, `ZenithInterceptor` 6 of 13,
  `JovianLightFreighter` 0 standable points at these radii (it is 18.9 × 27.4 m,
  so the ring falls inside its own hull and ramp). The Torrent's and Zenith's
  silent points are all in the starboard/aft quadrants, away from their port-side
  boarding markers, and that one-sidedness is **deliberate**:
  `boarding_accessibility_test._test_torrent_opposite_side_rejection` asserts in
  as many words that the Torrent "cannot be boarded through the hull from its
  wrong/opposite side". Their coverage is printed by the regression on every run
  but only the Arrow is asserted all-round, because only the Arrow has a marker
  a player cannot reach. If the owner wants a walk-all-round rule for the fleet,
  that is a design decision about the Torrent's published contract, not a bug fix.

---

### RUNWAY-SEAM-001 — the authored Torrent runway and the walkway share a volume

- Status: `CLOSED` (fixed 2026-08-16). Severity **P2** (reporter: "Not a major
  issue").
- The authored central-berth shell — what the reporter calls the runway — renders
  its deck panels between `y = -0.005` and `y = 0.095` and recesses its service
  channels down to `y = -0.110`, over `x = -12.750 … 12.750` by
  `z = -27.750 … 7.750`. Three generic lattice decks had their top face on the
  `y = -0.020` plane *inside* that band and inside that footprint:
  - `CentralJunction` (`z = 5.0 … 23.0`) — 25.0 × 2.55 m of overlap, and the
    walkway the player walks in on from spawn;
  - `JunctionLink` (`x = -6.5 … 6.5`, `z = -3.0 … 6.0`) — 13.0 × 9.0 m, wholly
    enclosed by the shell;
  - `HeroBerthNode`, whose render slab was already hidden for this exact reason.
  Where the shell's channels are recessed the grey deck stood **0.090 m proud of
  the channel floor** and read through it. That is the "slight texture glitch".
- Fix (`scripts/world/shipyard_world.gd`), geometric only — **no depth-write, no
  render priority and no material value was touched**:
  - `CentralJunction` now starts at the shell's own edge, `z = 7.75`
    (`AUTHORED_CENTRAL_BERTH_EDGE_Z`), instead of running 2.75 m underneath it.
  - `JunctionLink` keeps its collision and its render slab is hidden with the same
    `hidden_by_authored_central_berth` marker the hero berth node already carried.
  - `HeroBerthNode` takes over the floor the walkway gave up
    (`z = -25.0 … 7.75`), same `y = -0.020` top plane, so the physical surface a
    player stands on is unchanged.
- Regression (`tests/station_surface_playability_test.gd`
  `_test_lattice_decks_do_not_share_the_authored_runway_volume`): re-measures the
  shell's own surface band from the live import (asserted at exactly
  `-0.110 … 0.095`) and requires that nothing else the station draws has a surface
  inside it where their footprints overlap. `RUNWAY_SHELL_VOLUME_INTRUDERS` was
  three decks; it is now `[]`.

---

### ZENITH-SITE-001 — floating geometry, and standable collision with nothing drawn

- Status: `CLOSED for what was measurable` (fixed 2026-08-16). Severity **P2**
  for the floating half, **P1** for the invisible-barrier half.
- Both halves were swept for structurally rather than fixed by eye, per the
  intake's own instruction.
- **Invisible barrier.** A 0.25 m grid sweep of the whole reachable station,
  raying down on the World layer and asking the renderer whether anything is drawn
  at each standable surface, found exactly **two** colliders a player can stand on
  with nothing rendered there, both at the central berth and both from a generic
  collision box outliving the authored shell that replaced its render slab:
  - `ExposedDockLattice/HeroBerthNode` was 27.0 m wide under a 25.5 m shell,
    leaving a **0.75 × 32.75 m invisible ledge down each flank** (591 probe hits).
  - `OpenLaunchSpine/CentralBerthLaunchTransitionCollision` reached `z = -28.000`
    with a top plane 0.095 m proud of the launch arm while the shell it belongs to
    stops at `z = -27.750`: a **25.5 × 0.25 m invisible lip** across the runway
    (16 probe hits).
  Fixed by narrowing `HeroBerthNode` to the shell's own 25.5 m, starting the
  transition block at `z = -27.75`, and extending `LaunchArmDeck` 0.25 m aft so
  its rendered edge meets the shell. The sweep now reports **31222 standable
  probes, 31222 drawn, 0 orphans**. No station collider around the Zenith itself
  was ever in that set; the Zenith's own hull collision was also measured
  triangle-by-triangle against its drawn hull and is the **tightest in the fleet**
  (27 of 1403 sampled columns stand more than 0.10 m above the drawn surface,
  against the Torrent's 823 of 951 — and the Torrent's boxes are a published,
  audited contract in `tests/torrent_collision_art_alignment_test.gd`).
- **Floating geometry.** An isolated-island sweep (every drawn mesh with no other
  drawn mesh within 0.06 m in any direction) found, at the Fleet Dock comb the
  Zenith is docked to: both 47 m `TrunkChord` under-deck beams hanging **0.090 m**
  below the deck they are bolted to — the port one intersecting nothing at all in
  the module — and the three `RungUnderChord` beams hanging 0.040 m. The same
  sweep found all eight `JovianFreightBerth` cargo crates hovering, 0.045–0.055 m
  above the rack shelf for the lower four and 0.040–0.070 m above their own lower
  crate for the upper four. All thirteen now bear on the surface below them with a
  0.010–0.060 m seat; only `y` coordinates moved.
- Regression (`tests/station_presentation_defect_witness_test.gd`
  `_test_structural_pieces_rest_on_drawn_geometry`): the existing `_drop_below`
  helper cannot answer this class, because it rays against World *collision* and
  every piece here hangs off structure that has none, so in open space the ray
  falls forever. The new check measures against **drawn geometry** instead.
  Plus `_test_no_station_collision_without_visible_geometry` above, which is the
  permanent guard for the invisible-barrier half and is the exact inverse of the
  visible-surface-needs-collision check that already existed.
- **Recorded, not fixed — the berth cue plates.** The one piece of geometry beside
  the Zenith that still hangs in the air is its own berth cue: the four
  `ZenithFleetDockBerth/BerthFeedback/FeedbackVisual` boundary strips plus
  `GlyphSecuredBar`, `LeaseStatePlate` and the two status plates all have their
  underside at `y = 4.380` over a dock slab whose top is `y = 4.200` and whose
  inset is `y = 4.240` — a **0.180 m hover**, touching nothing. Measured across
  the fleet the hover is 0.235 m at the central berth, 0.210 m at the Jovian and
  0.380 m at the Arrow; the difference at the Zenith is that the other three
  berths have a raised ring at roughly cue height for the cue to read against and
  the Zenith has none, so there the plates read as loose blocks. The cause is
  `ShipBerthFeedback.RENDER_MIN_Y = 0.14` plus the per-berth `local_transform` in
  `SHIP_BERTH_FEEDBACK_SPECS`, a frozen cross-berth contract duplicated in
  `tests/ship_berth_feedback_world_test.gd` and framed by
  `tests/capture_berth_feedback.gd`. This pass deliberately did not move it: the
  task scope protects berth transforms and the capture harness was out of bounds
  for edits. **Recommended next pass:** seat all four berth cues on the deck they
  mark, re-freezing `local_transform` per berth in the open.

---

## Open candidates — 2026-08-15 human playtest intake

Reporter: project owner (`loginpeople123@gmail.com`), 2026-08-15, verbatim report:
*"there's so many places that are difficult to get to, random objects floating in
the air and it ruins the experience."*

Configuration for every reproduction below: Linux (WSL2 6.18.33.2), Godot
4.7.1.stable.official.a13da4feb, `--headless` for physics probes and
`xvfb-run -a -s "-screen 0 2560x1440x24" ... --rendering-driver vulkan` for frames,
audio driver `Dummy`, clean user-data state, source at commit `ef5450c`.
Failure frequency: 10/10 deterministic for every item unless stated.

Witness for the confirmed traversal items (MAP-001…MAP-003), now **GREEN** and
collected by `run_test_matrix.sh`:
[`tests/station_traversal_defect_witness_test.gd`](tests/station_traversal_defect_witness_test.gd)
(sentinel `STATION_TRAVERSAL_DEFECT_WITNESS_TEST_OK`).

Witness for the presentation items (MAP-004…MAP-006), now **GREEN** and collected
by `run_test_matrix.sh`:
[`tests/station_presentation_defect_witness_test.gd`](tests/station_presentation_defect_witness_test.gd)
(sentinel `STATION_PRESENTATION_DEFECT_WITNESS_TEST_OK`). Its three assertions
were moved there verbatim when MAP-001…MAP-003 were fixed, so a P2 presentation
defect did not hold the P1 traversal gate red; it was renamed into the glob when
they were closed. One roster in it was widened — six mirrored legends to eleven —
and that is recorded in the suite header.

### Measurement that underpins the traversal items

`MEASURED_NO_JUMP_STEP_HEIGHT` was **`0.14`** at intake — the production
`PlayerController` (`CharacterBody3D`, plain `move_and_slide()`, no step-up
assist) mounted a 0.14 m lip with continuous `move_forward` and failed at 0.15 m,
walking or sprinting. Any authored lip of 0.15 m or more was therefore a wall,
not a step.

It is now **`0.30`**. `PlayerController` gained a bounded step-up assist
(`STEP_UP_MAX_HEIGHT`), chosen from the rig and the architecture rather than
rounded to taste: it equals this station's own authored stair riser
(`AftJunctionStack` raises 4.2 m over 14 risers = 0.300 m), it is 58% of the
avatar's measured 0.516 m knee-joint height on a 1.945 m standing suit, and it
is inside the 0.38 m capsule radius so the body is only ever placed where the
capsule could have rolled unaided. It is deliberately **below** the station's
0.40 m raised-pod slab, so a room a whole slab above its approach still has to
author a real threshold instead of relying on the assist. Bounds and mutations
are frozen by [`tests/player_step_up_assist_test.gd`](tests/player_step_up_assist_test.gd).

### MAP-001 — Aft stair base is fenced off; the whole aft-upper half of the station is unreachable

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: `scripts/world/aft_junction_stack.gd`. Two rail runs were closing the only
  gate onto the stair-base landing and they overlapped by 0.33 m, so no capsule
  column was ever open. `ApproachPortRail` now stops at the landing's southern
  edge (`_stair_base_landing_south_edge()`) instead of running 1.8 m past it — it
  guards the stretch of connection-deck edge that actually overhangs a drop and
  nothing more. The eastern stair rail line, which stood *on* the landing rather
  than over a drop, now starts where the ramp has climbed clear of the landing
  (`_stair_rail_start_progress()`); the outboard western line still runs full
  length. The landing's own newly-exposed south and west edges gained
  `StairBaseSouthRail` / `StairBaseWestRail`, because opening the gate made a
  previously unreachable 4.4 × 3.5 m landing walkable with two unguarded edges.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_aft_stair_base_is_not_fenced_off` — the recorded four-position
  reproduction, unchanged. From world `(0.0, 0.18, 50.5)` facing `-X` the
  production capsule now reaches `x = -6.290` on the landing (previously
  `-2.900`) and is stopped by the new west guard rail rather than falling. The
  same suite's required-route-surface flood covers the whole blast radius.
- Residual, recorded not fixed: from `z = 51.5` and north the westward walk is
  still stopped at `x ≈ -3.92` by the side of the ramp itself, which is 0.33 m
  proud of the landing there — just above the 0.30 m step limit. That is the
  side of a staircase, not a route; the player walks in at `z ≤ 51` and turns
  north. The route works but it is not equally open along the whole frontage.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (roadmap: "cannot reach a required route
  without an unintended jump"; the playable-prototype gate names the Aft upper
  level and Fleet Dock as required no-cheat destinations).
- Authority: `scripts/world/aft_junction_stack.gd:494`
  `_add_rail(lower, Vector3(-3.35, 0, 0.25), Vector3(-3.35, 0, 3.3), "ApproachPortRail")`,
  plus the two `Circulation` stair rails at the ramp foot.
- Node paths: `ShipyardWorld/AftJunctionStack/Structure/LowerOpenDeck/ApproachPortRail`
  (world x = -3.35, z = 48.25 … 51.30, collision on) and
  `ShipyardWorld/AftJunctionStack/Structure/Circulation/@StaticBody3D@81`/`@96`
  (world x ≈ -3.75 … -4.25, z ≈ 51.0 … 52.5).
- Steps: begin shift; walk to the Aft connection deck; stand at world
  `(0.0, 0.18, 50.5)`, `(0.0, 0.18, 51.5)`, `(0.0, 0.18, 52.0)` or
  `(0.0, 0.18, 52.6)` facing `-X`; hold `move_forward` for 200 physics frames.
- Expected: reach the stair base landing (x ≤ -4.6) and climb
  `Structure/Circulation/ContinuousStairRamp`.
- Actual: stops at x = -2.900 / -3.566 / -3.606 / -3.919 respectively, stuck for
  153-165 of 200 frames. The rail plus the stair-rail pair seal every column
  between the connection deck and the ramp foot.
- Blast radius (all unreachable on foot as a consequence):
  `AftJunctionStack/Structure/Circulation/ContinuousStairRamp`,
  `AftJunctionStack/Structure/UpperOpenDeck/UpperFloor` (top y = 4.20),
  `ExposedDockLattice/FleetDockCombConnector/FleetDockCombConnectorDeck`
  (centre `(6.0, 3.88, 68.3)`), and every `FleetDockComb/GeneratedComb/WalkableSurfaces/*`
  (`Trunk`, `Rung01/02`, `DockSlab01/02`, `Rung03Vertical`, `DockSlab03Upper`).
  The ramp itself is fine: from `(-5.0, 0.18, 50.0)` facing `+Z` the production
  capsule climbs to `(-5.0, 4.200, 67.53)` unaided.

### MAP-002 — 0.40 m riser seals the operations pod, the fleet registry pod, and the entire freight branch

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: `scripts/world/shipyard_world.gd`. Both pods keep their authored
  placement — `docs/research/STATION_TOPOLOGY.md` pins `OperationsPodFloor
  (43, 0.18, 27)` and `RegistryPodDeck (-43, 0.18, 27)` as frozen evidence, so
  moving the decks would have been documentation drift, and lowering them would
  have left every mullion, window, back wall, terminal and sign 0.40 m in the
  air, which is the same defect family the reporter complained about. Instead a
  new `_approach_threshold()` helper builds one rendered, colliding threshold
  apron across each pod's full 12 m frontage: `OperationsPodThreshold` and
  `RegistryPodThreshold`, rising from the lattice deck top (`y = -0.02`) at
  `z = 21.85` to the pod deck top (`y = 0.38`) at `z = 23.05` — a 1.20 m run for
  a 0.40 m rise, 18.4°, well inside `floor_max_angle`. The freight branch needed
  no separate work: its connection lattice is flush with the registry pod deck,
  so it opened as soon as the pod did.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_pod_decks_can_be_walked_into` — the recorded reproduction, run through
  the production controller. Standing on the lattice deck and holding
  `move_forward` for 200 frames now ends at `(43.0, 0.381, 25.87)` inside the
  operations pod, `(-46.5, 0.381, 30.17)` on the registry pod deck, and
  `(-47.0, 0.380, 30.17)` out along the freight connection lattice. No jump.
- Note on the recorded coordinates: the registry approach at `(-43.0, ·, 21.0)`
  stands **inside the parked `ArrowReconShip`'s hull**, so a capsule placed there
  starts overlapping a ship rather than on the deck. The regression uses
  `(-46.5, ·, 21.0)` on the same 12 m frontage; the lip crossed is identical.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (unreachable required route; the fleet
  registry terminal interaction cannot be acquired from its intended approach).
- Authority: `scripts/world/shipyard_world.gd:2786` `OperationsPodFloor`,
  `scripts/world/shipyard_world.gd:2811` `RegistryPodDeck`, and the
  `JovianFreightBerth` connection lattice, all authored with deck top y = 0.38
  against a lattice deck top of y = -0.02 → a 0.400 m vertical lip at z = 23.0.
- Node paths / coordinates: `ShipyardWorld/UpperOperations/OperationsPodFloor`
  `(43.0, 0.18, 27.0)`; `ShipyardWorld/ModernFleetRegistry/RegistryPodDeck`
  `(-43.0, 0.18, 27.0)`; `ShipyardWorld/JovianFreightBerth/ConnectionLattice/ConnectionHandoffDeck`
  `(-49.5, 0.08, 25.6)`.
- Steps: begin shift; stand at `(43.0, 0.18, 21.0)` (or `(-43.0, 0.18, 21.0)`, or
  `(-47.0, 0.18, 21.0)`) facing `+Z`; hold `move_forward` for 200 frames.
- Expected: step up into the glass-fronted pod / onto the freight handoff deck.
- Actual: stops dead at z = 22.620 with y unchanged at -0.020, stuck 178/200
  frames. The pods have open glazed frontages and a diegetic terminal, so they
  read unmistakably as rooms the player is meant to enter.
- Blast radius: every `JovianFreightBerth` surface is unreachable —
  `ConnectionDeckA/B/C`, `ConnectionHandoffDeck`, `ApronDeck01-04`,
  `CargoRackShelf`, `ServiceRoomShelf`, `FreightControlRoom/RoomFloor`.
  The seam itself is solid structure (no void): the void probe at x = -47.5
  returns zero empty samples, so this is purely the lip.

### MAP-003 — Two of the four flyable craft cannot be boarded on foot

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P1**.
- Fix: none of its own. It was a pure consequence of MAP-001 and MAP-002 and
  closed with them.
- Regression: `tests/station_traversal_defect_witness_test.gd`
  `_test_every_flyable_ship_is_boardable_on_foot` — `STRANDED_SHIPS: []`. Every
  one of the four production `get_boarding_position()` points now has a
  capsule-clear walkable node reachable from `%PlayerSpawn` without a jump.
- Re-measured reachability on the same sweep: **91,901 of 106,969** capsule-clear
  walkable graph nodes are reachable from spawn with no jump, against the
  intake baseline of 53,073 of 106,903 — 49.6% → 85.9%. The node total rose by
  66 because the fix added walkable threshold aprons. The 15,068 nodes still
  unreached are dominated by surfaces with no intended route: `OperationsPodRoof`
  and `RegistryPodRoof` (1,617 each), `FreightControlRoom/RoomRoof` (1,000), the
  habitat and Aft operations ceilings, `FreightGantryCrane/GantryHeader`,
  cargo-unit tops, rail tops and the registry terminal top. Ship interiors and
  the exterior target range have not been swept.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P1** (roadmap: "All four ships can be
  approached from collision-clear routes, boarded through the production
  reservation path"). Consequence of MAP-001 and MAP-002, tracked separately
  because it is what the player actually loses.
- `JovianLightFreighter` boarding position `(-49.60, 1.11, 65.45)` — on the
  freight loading apron, gated by MAP-002.
- `ZenithInterceptor` boarding position `(14.35, 4.73, 53.85)` — on
  `FleetDockComb/GeneratedComb/WalkableSurfaces/DockSlab01`, gated by MAP-001.
- Reachability sweep: 53,073 of 106,903 capsule-clear walkable graph nodes are
  reachable from `%PlayerSpawn` `(-8.5, 0.18, 11.0)` with no jump — just under
  half the authored walkable area of the station.

### MAP-004 — Pod facade and registry terminal legends are mirrored to the approaching player

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P2**.
- Fix: `scripts/world/shipyard_world.gd`, `scripts/world/aft_junction_stack.gd`,
  `scripts/world/habitat_spine.gd`. Each affected legend is yawed
  `Vector3(0, 180, 0)` so its readable `+Z` face points at the deck it is
  approached from. `TextMesh` extrudes symmetrically about local `z = 0`, so the
  yaw does not move the sign's depth footprint at all — verified in the live
  world, where the four terminal legends still occupy `z = 23.558 … 23.574`
  against a `RegistryScreen` front face at `z = 23.590`, i.e. they stand
  0.016-0.028 m proud of the panel and the readable glyph face now points away
  from it. **The rotation alone was checked against burial before it was
  trusted, not assumed.**
- Scope widened, deliberately and recorded: the intake listed six legends. A
  sweep of all 20 live `TextMesh` nodes in `Main` found **five more** with the
  identical cause — `Vector3.ZERO` on the approach-side face of a backing plate.
  All five were rendered and read backwards before the change:
  `ExposedDockLattice/Sign_MUDDS__--__REGENERATION_DECK` and
  `.../Sign_CENTRAL_JUNCTION__--__FLEET_DOCKS` (both on `JunctionSignFace`
  `z = 21.95`, the station's most prominent navigation board, mirrored to
  everyone walking aft through the portal);
  `AftJunctionStack/Structure/VIPLandmark/Sign_VIP_ACCESS__--__DEFERRED`
  (in front of the facade panels at `z = 20.12 …`); and
  `HabitatSpine/Structure/PlayerClearConnector/Sign_HABITAT_SPINE____FIXED-ERA-INSPIRED`
  (in front of `EntryFacadeRight` at `z = 0.48 …`); and
  `AftJunctionStack/Structure/OpenStructureDetails/Sign_AFT_JUNCTION__--__MODERN_INTERPRETATION`,
  which `bugs.md` had misfiled under "floor decals". Both modules already had a
  correctly yawed sibling (`AFT OPERATIONS`, `OBSERVATION COMMON`), so this was
  an authoring slip, not a convention.
- Secondary defect found only because the fix made the text readable:
  `RegistryScreen` was 1.35 m tall (`y = 1.195 … 2.545`) while the legend block
  runs `y = 1.134 … 2.254`, so the bottom line `UTOPIA  ARROW` fell 0.061 m off
  the lit panel onto the navy terminal body — black on near-black. The panel is
  now 1.50 m tall (`y = 1.08 … 2.58`). Legend positions are unchanged, so every
  coordinate recorded below still holds.
- Second defect on the VIP legend, found only by photographing it rather than
  trusting the rotation: `Sign_VIP_ACCESS__--__DEFERRED` stood at z = 67.96 while
  `AftJunctionStack/VIPAccess/FrameVisuals/Header` occupies z = 67.72 … 68.44 at
  exactly that height, so the sign was **buried inside its own door frame and
  rendered to nobody from either side**. Five camera positions from 1.06 m to
  6.0 m photographed blank frame header. It is now at z = 67.64, 0.08 m proud of
  the frame's front face. An un-mirrored sign hidden in its own panel is not
  fixed; this is why every legend in this pass was rendered and read, not just
  asserted.
- Regression: `tests/station_presentation_defect_witness_test.gd`
  `_test_approach_facing_signs`, roster widened from six to eleven. The original
  six entries are byte-identical; nothing was loosened.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P2** (roadmap: "isolated visual mismatch").
  Argued escalation: the roadmap's P1 clause "systematically reverses or destroys
  scene readability" plausibly applies, because six adjacent legends including the
  only diegetic regeneration interface are all reversed. Left at P2 pending review
  because it neither blocks nor misdirects the core loop.
- `TextMesh` renders its readable face toward local `+Z`; these six are authored
  with `Vector3.ZERO` rotation at the `-Z` face of their structure, so the reader
  standing on the lattice deck sees mirror writing.
- Node paths: `ShipyardWorld/UpperOperations/Sign_DOCK_OPERATIONS` `(43.0, 5.15, 22.68)`;
  `ShipyardWorld/ModernFleetRegistry/Sign_FLEET_REGISTRY__--__MODERN_INTERFACE`
  `(-43.0, 5.05, 22.82)`; `.../Sign_SAY_SHIP_NAME` `(-43.0, 2.17, 23.57)`;
  `.../Sign_TORRENT__JOVIAN__TITAN__VORTEX` `(-43.0, 1.70, 23.56)`;
  `.../Sign_KATANA__PARADOX__PREDATOR__DYNAMIC` `(-43.0, 1.43, 23.56)`;
  `.../Sign_UTOPIA__ARROW` `(-43.0, 1.18, 23.56)`.
  The last four sit 0.05 m in front of `RegistryScreen`, whose own panel faces the
  deck — the text faces into its own screen.
- Evidence frames: `b2_registry_sign.png`, `b2_pod_riser_outside.png`,
  `b2_freight_branch_gap.png` (scratchpad, not committed).

### MAP-005 — Eight safety beacons hover 0.19 m above the roofs they stand on

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P2**.
- Fix: `scripts/world/station_operations_activity.gd`. `_get_beacon_positions()`
  placed every beacon's origin at local `y = 0.27` while the `Base` pedestal is
  0.18 m tall and centred on that origin, so the pedestal's underside sat 0.18 m
  above the component's own mounting plane. It now uses
  `BEACON_SEAT_HEIGHT = 0.09`, half the pedestal height, which puts the underside
  on the plane every `FootPad` in the same component already rests on.
- Scope widened: the intake found eight because it only probed two activities.
  **All sixteen** beacons in the live roster were hovering — 0.19 m on
  `AftOperationsActivity`, `HabitatServicePatrol` and `FreightApproachGantry`,
  and 0.21 m on `CentralTowServiceActivity`. All sixteen now measure a 0.010 m
  residual except the Central berth's four at 0.030 m; that residual is the
  activity's mount transform sitting above the deck below it and is shared by
  every foot pad in the component, not a per-beacon defect. Recorded, not
  silently absorbed — see "found, not fixed" below.
- Second defect in the same assembly: on the `drone_patrol` profile the
  `AnchorFoot` was a plinth at local `y = -0.22`, whose top (`-0.16`) sat 0.07 m
  *below* the pedestal underside (`-0.09`). The pedestal was therefore hovering
  over its own anchor as well as over the roof. `AnchorFoot` is now a 0.06 m
  bolt-down flange sharing the pedestal's underside plane.
- Regression: `tests/station_presentation_defect_witness_test.gd`
  `_test_seated_decorations_rest_on_their_surface`, unchanged roster and
  unchanged 0.03 m tolerance.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P2** ("isolated visual mismatch"); it does not
  imply a route, so it does not escalate.
- Node paths: `ShipyardWorld/OperationalLattice/Activities/AftOperationsActivity/PresentationRoot/SafetyBeacon01-04/Base`
  (around `(3.9 … 7.7, 5.26, 60.0 … 62.5)`, resting surface
  `AftJunctionStack/Structure/OperationsRoom/OperationsCeiling` at y = 4.98) and
  `.../HabitatServicePatrol/PresentationRoot/SafetyBeacon01-04/Base`
  (around `(55.9 … 62.4, 5.15, 11.4 … 19.6)`, resting surface
  `HabitatSpine/Structure/PressurizedHabitatCorridor/HabitatCeiling`).
- Measured drop from the base underside to the surface below: 0.190 m for all eight.

### MAP-006 — Orphan freight dock guide lens hangs in open space

- Status: `CLOSED` (fixed 2026-08-15). Severity was **P2**.
- Fix: `scripts/world/jovian_freight_berth.gd`. The centreline guide-light run was
  authored at berth-local `z = [10, 18, 26, 34, 42, 49]`, but the apron's outbound
  leaf `ApronDeck04` ends at local `z = 47.85`, so the last entry alone was off
  the deck. It is now `47.0` — still the outermost cue on the outbound edge, now
  0.85 m inboard of the lip it sits on. World centre moves `(-53.0, 0.63, 77.8)`
  → `(-53.0, 0.63, 75.8)` and the drop `2.040 m` → `0.130 m`, matching all
  seventeen sibling lenses. The eighteenth `DockGuideLight` moves with it; nothing
  else in the roster changes.
- Regression: `tests/station_presentation_defect_witness_test.gd`
  `_test_orphan_dock_guide_lens`, unchanged 0.35 m threshold.
- Original record follows.
- Status at intake: `REPRODUCED`. Severity: **P2** ("isolated visual mismatch").
- Node path: `ShipyardWorld/JovianFreightBerth/FreightPresentation/DockGuideLens18`,
  centre `(-53.0, 0.63, 77.8)`.
- `LoadingApron/ApronDeck04` ends at z = 76.65, so the lens sits 1.15 m beyond the
  apron edge with a 2.04 m drop to `LoadingApron/ApronCrossChord6` below. Every
  other dock guide lens rests on the apron.

### Unconfirmed observations — all four adjudicated 2026-08-15

**1. Gantry overhead rail floats above its own columns — CONFIRMED, FIXED.**
`MaintenanceGantry/OverheadRail` started at y = 5.610 while
`MaintenanceGantry/Column` stopped at y = 5.530. The gap is real and it is not
bridged by anything: `BridgeBeam` (y = 5.490 … 5.810) ties the two rails to each
other at x = 0, but the columns stand at x = ±4.3, so the entire rail-plus-beam
assembly hung as one rigid unit 0.08 m clear of all four columns with no
connecting member anywhere. Identical on `FreightApproachGantry` (rail 5.990,
column top 5.910). Fixed in `scripts/world/station_operations_activity.gd` by
lengthening `Column` 5.42 → 5.50 m (centre 2.82 → 2.86), so the column top now
measures exactly the rail underside: 5.610 / 5.990. Rail height, `GANTRY_TRAVEL`,
`GANTRY_ELEVATION` and the component footprint are untouched. Visibility was the
open question and it is answered: at 5.5 m over a walkable deck the joint is in
frame from the Central berth approach, and a 0.08 m gap in a 0.42 m-wide column
head reads as a break, not as clearance.

**2. Floor decals rendered mirrored — DISMISSED as stated; one different defect
found underneath it.** Not mirrored. All eleven floor-facing legends in the live
world (`Sign_ACTIVE`, `Sign_ARROW_RECON…`, `FreightSign2 "BERTH F-01"`,
`FreightSign4`, the four `LeaseStateLabel`s, `AssignedDockLabel01`,
`DeferredDockLabel02/03`) have an orthonormalized basis **determinant of exactly
+1.000** with `basis.z = (0, 1, 0)`, i.e. the readable face points at the sky and
the glyphs are not reflected. What the overview frames actually showed is a 180°
*rotation*: these decals carry `rotation_degrees (-90, 0, 0)`, so their reading
"up" is world -Z, which is upright for a viewer travelling -Z and upside-down for
one travelling +Z. That is inherent to floor text, which can only be upright for
one of two travel directions. Verified in frame: "BERTH F-01" photographs
upside-down from the station-side approach — rotated, with unreflected letter
forms. Residual, recorded not fixed because the intended reading direction is a
design choice nobody has made: `BERTH F-01` and `KEEP TRANSFER LANE CLEAR` are
upright for someone walking *back* toward the station, while the freight apron's
primary travel is outbound.
**However**, the third item in the same bullet, "AFT JUNCTION // MODERN
INTERPRETATION", is **not a floor decal at all** — it is a vertical `TextMesh`
plaque at `(0, 1.23, 57.82)` on `AftJunctionStack/Structure/OpenStructureDetails`,
and it really was mirrored, for the ordinary MAP-004 reason. Rendered from the
aft connection deck at `(0, 2.4, 52)` it read backwards. Fixed with the rest of
the MAP-004 family and added to the witness roster.

**3. Arrow berth cue strips overhang the structure they mark — CONFIRMED and
visible, deliberately NOT fixed.** All four `Boundary_*` corners return no
downward hit within 400 m, and a deck grid sampled at 1 m over
`x = -52 … -34`, `z = 9 … 22` shows why: the port node deck spans roughly
`x = -49.5 … -36.5` at the cue's `z` extremes, while the cue rectangle's corners
sit at `x = ±7.02` and `z = ±4.977` from `(-43, 15.5)`, i.e. at `x = -50.02` and
`x = -35.98`. Both ends are past the deck edge. This is *not* the same as the
three sibling berths, whose strips hover a benign 0.19-0.36 m over their pads;
here they hang over the void, and frame `13_arrow_berth_cue` shows the outboard
strips glowing in open space beyond the deck outline.
Not fixed here because every available fix leaves this pass's remit: the
rectangle's size comes from `cue_half_width = 6.3` / `cue_half_length = 7.2` in
`SHIP_BERTH_SPECS`, which `get_ship_berth_feedback_audit_report()` verifies as a
**module contract** (`feedback_cue_half_width_drift_*`), and the cue honestly
advertises the Arrow's `landing_half_extents (8.0, 4.5, 9.0)` envelope — shrinking
it would make the cue lie about where the ship lands. The other repair, widening
the port node deck, is **walkable geometry**, explicitly out of scope for a
presentation pass. Owner needed for one of: enlarge the port node deck to cover
the envelope it advertises, or shrink the Arrow's berth envelope and cue together
and re-freeze the contract.

**4. `Sign_ACTIVE_BERTH__--__CENTRE_SPINE` is a floating sign — CONFIRMED, FIXED,
and it was mirrored as well.** Its intended mount was not "unclear": the legend
belongs to the berth indicator assembly directly beside it
(`BerthIndicatorBase` `(-38.5, 0.75, 27.6)`, `BerthIndicatorRing` y = 1.52,
`BerthIndicatorNeedle` `(-38.5, 2.55, 27.6)` spanning y = 1.50 … 3.60,
z = 27.52 … 27.68). At z = 26.90 it stood 0.62 m clear of the needle's -Z face —
exactly the 0.62 m the sweep measured — and, authored with `Vector3.ZERO`, it
also faced +Z, away from the deck. It is now a blade sign on the mast head at
z = 27.50, 0.018 m proud of the needle, yawed to the reader. Rendered and
confirmed: the legend reads forwards and the mast is visibly behind it.

### Explicit false positives — swept and dismissed

Downward-support sweeping every one of the 2,794 live `MeshInstance3D` nodes in
`Main` produced these unsupported-but-intentional groups, deliberately **not**
raised: `SpaceBackdrop/Celestial*` bodies and `ParallaxStars`;
`ExteriorTargetRange` drones, `BeaconMast`, `RangeTruss` and its range sign;
`OpenLaunchSpine` guide lenses and `SignalMast` (markers deliberately suspended in
the launch corridor void); `OperationalLattice/StructuralDressing/*` keel chords
and fascia (exterior dressing hanging outside the deck edge by design);
`AnimatedServiceDrone*` (authored hovering); ceiling cove rails, overhead beams,
docked/parked craft, and the freight crane; `BerthFeedback/FeedbackVisual`
boundary strips that hover 0.22-0.37 m over their pads (projected landing cue).
Closed `StationDoor` portals were excluded from every reachability query so a door
that simply needs an interact press is never miscounted as a blocked route; only
the two `deferred_access` landmark doors stay solid.

## SANDBOX-001 — re-board suppression bypassed by a physics-tick interact — **FIXED**

Configuration: Linux (WSL2 6.18.33.2), Godot 4.7.1.stable.official.a13da4feb,
`--headless`, audio driver `Dummy`, 32 cores, source at `f88419e`.

### Reproduced before it was touched

The recorded diagnosis was verified against the code and then reproduced twice,
independently of the existing witness, before any production edit:

1. **Through the real input path.** A scratch script boarded the Arrow by pressing
   the real `interact` action (`PlayerController._physics_process` →
   `interact_requested`), flew a sortie, landed, shut down, left the seat through
   the piloted interact edge, and then mashed `interact` on every physics tick.
   With idle frames starved to 10 Hz while physics kept 60 Hz — what a loaded
   machine does — the first post-exit press re-boarded the craft:
   `phase` COMPLETE → BOARDING, `_transition_busy` true, on the same idle frame
   (`idle=32`) as the exit, with `boarding_candidate` still naming the Arrow and
   `_reboard_blocked_ship` already set to it.
2. **At the handler.** Calling `_on_interact_requested()` in the window shows the
   same transition with the cached pair intact.

**The diagnosis held exactly**, with two additions worth recording.

- The window is *frame-phase dependent*, not merely narrow. When idle frames run
  freely — which is what `--headless` does by default, at 2-3 idle frames per
  physics tick — the idle refresh lands first and the window never opens on that
  run. That is why the defect only ever surfaced on a busy box, and it is why the
  witness now starves idle frames explicitly instead of relying on ambient load:
  its red assertion was itself timing-dependent, and passed on unfixed code on a
  quiet machine.
- The stale pair is not only the ship. `station_interaction_candidate` is cached
  by the same idle pass and consulted *first* by `_on_interact_requested()`, so the
  same window could actuate a station control the pilot was standing next to before
  the sortie, from wherever they exited.

### Root cause and the seam chosen

`_reboard_blocked_ship` was correct and was set in time. The defect was that the
consumer read a snapshot: `boarding_candidate` / `_near_ship` /
`station_interaction_candidate` are written only by `_update_on_foot_flow()` from
`_process()`, which is skipped for the whole sortie, while `interact_requested` is
emitted from `PlayerController._physics_process()` and Godot runs every physics
iteration of a frame ahead of that frame's idle pass.

The fix is `GameFlow._refresh_interaction_targets()`, called both from the idle
on-foot update and from `_on_interact_requested()` immediately before it acts.
This was preferred over adding a `candidate == _reboard_blocked_ship` rejection to
`_board_ship()`, which was the originally suggested repair, for three reasons: it
keeps the suppression rule in one place (`_find_boarding_candidate()`) instead of
duplicating the predicate at a second site; it fixes the station-door half of the
same window, which a boarding-only check does not; and it does not change the
contract of `_board_ship()`, which thirteen call sites across six suites use as a
scripted boarding entry point.

**Why this closes the window rather than narrowing it.** After the fix there is no
cached value between the state change and the decision. `_on_interact_requested()`
already returns early while `_transition_busy`, and `_try_exit_ship()` clears that
flag only at the very end of a synchronous tail that has already assigned
`_reboard_blocked_ship`. So at every instant the handler is permitted to act, the
suppression state is final, and the candidate it acts on is computed from the live
scene in the same call. No arrival order of physics and idle can produce a decision
from stale data, because there is no longer a stale copy to read — for the
suppression, the boarding-area reservation, and the station facing test alike.

### Evidence

`tests/sandbox_stale_reboard_defect_witness_test.gd` (sentinel
`SANDBOX_STALE_REBOARD_DEFECT_WITNESS_TEST_OK`), renamed into the gate glob, 19
assertions. Red 3/3 on the unfixed production file with the fix reverted — both
defect assertions — and green 3/3 immediately after restoring it.

Under genuine parallel load (background headless Godot runs, `/proc/loadavg`
1-minute figure sampled at each run start):

| Suite | Runs | Pass | Load range |
|---|---|---|---|
| `sandbox_stale_reboard_defect_witness_test` | 12 | 12 | 13.5 – 36.7 |
| `sandbox_loop_test` | 12 | 12 | 12.4 – 40.7 |

The second set of six of each ran entirely above 23, peaking at 40.7.

### The one witness assertion that was wrong

The red assertion's first conjunct was `game.get_active_ship() != arrow`. It is
unsatisfiable and never discriminated the defect: `active_ship` is a persistent
"selected craft" pointer, assigned in exactly two places (`_ready()` seeds it with
the guided Torrent before any boarding; `_board_ship()` re-points it), and nothing
clears it on disembark — `_try_exit_ship()` reads it at its tail to populate
`_reboard_blocked_ship`. It still names the Arrow after a clean exit with no
re-board, which was checked directly on the unfixed code. It is replaced by the
observables that do discriminate a re-board — `phase`, `_transition_busy`,
`_piloting`, `player.is_seated()`, `arrow.is_piloted()` — which is strictly
stronger than the original pair. Both this and the added real-input leg are
recorded in the suite header rather than made quietly.

### Same class elsewhere — surveyed, reported, not fixed

Every signal reachable from a `_physics_process()` was traced to its production
handlers and the handlers' decision state to its writers.

- **`GameFlow._on_opponent_projectile_fired`** (emitter `range_opponent.gd:405`,
  physics) reads **no** coordinator gate at all — not `phase`, not `_piloting`,
  not `_transition_busy` — and submits damage against `active_ship`
  unconditionally; `opponent.is_active()` is consulted afterwards, and only for the
  HUD flash. It is the one fail-open handler in the set, and it fails open by
  having no guard rather than by holding a stale one. Not fixed: it is combat
  authority behaviour, outside this change.
- **`GameFlow._on_target_destroyed`** reads idle-written `phase`; a drop is
  permanent, because `authorize_target_destruction` is one-shot and GameFlow never
  re-reads the world's destroyed count. Fails closed. Reachability is low: the
  emission is synchronous inside `_on_projectile_fired`'s own stack and shares its
  phase snapshot.
- **`GameFlow._on_opponent_destroyed`** reads idle-written `phase` and would drop
  the guided victory with no polling fallback. Currently unreachable:
  `_begin_interceptor_engagement()` sets `phase` synchronously before
  `opponent.activate()`.
- **`GameFlow._on_projectile_fired`** and **`_on_landing_completed`** read
  idle-written `phase` / `_sortie_departed_berth`; both fail closed, and the
  landing path already has an idle polling fallback in `_update_pilot_flow()` that
  re-invokes the handler under the same strict gate.
- Cleared: `boarding_completed` / `disembarking_completed` / `canopy_motion_finished`
  are `call_deferred` and additionally generation-guarded; `_on_ship_destroyed`,
  `_on_landing_aborted`, `_on_engine_state_changed` and
  `_on_authoritative_shot_submitted` have no idle-only writer in their gates;
  `ShipBoardingArea.is_available_for()` re-derives on every call, which is why the
  refresh above is race-free; `MovingInteriorFrame` is physics-only.

## SANDBOX-002 — combat authority seam: both open items resolved as unreachable

The two combat handlers left open by the SANDBOX-001 survey were reproduced
against the running production scene rather than argued from the source. Neither
is reachable in a wrong state. No production behaviour was changed; the coupling
that makes them safe is now asserted by
`tests/combat_encounter_authority_gate_test.gd`, and the reasoning is recorded at
both handlers in `scripts/game/game_flow.gd`.

### `_on_opponent_projectile_fired` — fail-open, but the emitter is the gate

The handler really does read no coordinator state, exactly as reported. It is
sound because `RangeOpponent._fire_at_target()` refuses unless `_active` is true,
and `_active` is owned end to end by the encounter lifecycle:

- `opponent.activate()` is reached from exactly one call site,
  `_begin_interceptor_engagement()` (`game_flow.gd:1295`), four lines after it
  sets `Phase.INTERCEPTOR_ENGAGEMENT`;
- `Phase.INTERCEPTOR_ENGAGEMENT` has exactly two exits. Every other
  `phase = Phase.…` assignment is guarded against reaching it: `_board_ship()`
  needs `not _piloting` and `phase in [APPROACH_SHIP, COMPLETE]`,
  `_try_exit_ship()` excludes the engagement outright, `_on_landing_completed()`
  needs `RETURN_TO_YARD`/`FREE_FLIGHT`, and `Phase.FAILED` is never assigned;
- both exits clear `_active` **synchronously, inside the same call that ends the
  phase**: `_destroy_interceptor()` sets `_active = false` before it emits
  `destroyed`, and `_recover_from_destroyed_ship()` calls `opponent.deactivate()`
  before it touches anything else. `HeroShip.destroyed` is emitted inside
  `apply_damage()`, so the pilot-loss exit runs re-entrantly inside the very
  handler under suspicion — there is no idle turn in which a stale latch lives.

Observed directly, with the defender's own physics driving the telegraph/fire
cycle: killing the pilot leaves `is_active() == false` and `phase` at
`APPROACH_SHIP` on return from `apply_damage()`, and killing the defender leaves
`is_active() == false` already at the `destroyed` signal. Neither exit produced a
further emission over 320 physics frames while the test held a perfect firing
solution in front of the craft. Adding a `phase` gate here would be strictly
*weaker* than the latch it duplicates: `phase` is idle-written and this handler
runs in the physics pass, which is precisely the SANDBOX-001 hazard.

Whole-`Main` detach was checked separately. While detached, no physics runs, so
nothing is emitted. On re-entry `_restore_runtime_bindings_after_reentry()` is
`call_deferred`, so a physics pass can precede it; a shot in that window finds no
live registration and is rejected `unregistered_source` by the resolver. That is
fail-closed — one lost shot, no damage.

### `_on_target_destroyed` — the permanent drop is real, and unreachable

The mechanism reproduces on demand: forcing `Phase.INTERCEPTOR_ENGAGEMENT` with a
live drone and firing destroys it, `world.authorize_target_destruction()` commits
and emits, and `destroyed_targets` stays put forever — the one-shot latch is
spent. It never happens in production because the phases the gate rejects are
exactly the phases in which no live drone can be damaged:

- outside the guided weapon window `_on_projectile_fired()` safes the shot;
- a non-Torrent craft is refused with `guided_range_reserved`;
- the two live-fire phases the gate *does* reject, `INTERCEPTOR_ENGAGEMENT` and
  `RETURN_TO_YARD`, are gated behind `destroyed_targets >= total_targets` at both
  entries (`_update_pilot_flow()`'s launch branch and `_on_target_destroyed()`
  itself), and `destroyed_targets` only advances by accepting one authorization
  per drone, clamped by `mini()`. Reaching them with a drone still standing would
  require the drop that reaching them is supposed to enable;
- both defenders are dormant until then, so neither can spend a drone's
  authorization by stray fire. `total_targets` is `world.get_target_count()`
  sampled after the world's own `_ready()`, and the drone roster never grows.

So the honest verdict is: reachable only if someone widens the guided weapon
window, or adds a third producer of drone damage. That is what the new test
watches, and both mutations were verified red.

### Reconfirmed, unchanged

`_on_opponent_destroyed` fails closed and its gate can never reject — `_active`
implies `Phase.INTERCEPTOR_ENGAGEMENT`, which the new test pins by asserting the
guided victory still lands. `_on_projectile_fired` and `_on_landing_completed`
fail closed as described. The previously cleared handlers were re-read and remain
clear.

### Found, not fixed (owned elsewhere)

`StandoffPicketOpponent` is a second live combat source that resolves its lance
directly on the shared resolver and is never seen by GameFlow's handlers. Its
withdrawal is keyed to the defender's `is_active()` and is evaluated in its own
`_physics_process`, so a charge committed on the frame the defender dies can
still land one lance during `RETURN_TO_YARD`. The craft's own comments say the
escort is deliberately not stranded by a phase change, so this is reported rather
than changed; it lives in `scripts/ships/`, which a sibling owns.

## RENDER-001 — Seven `Texture` RIDs leak at `RenderingDevice::finalize()` on every rendered run — **ACCEPTED_RISK**

- Status: `ACCEPTED_RISK`. Severity: **P3**. Disposition: **accepted, engine-side, no code
  change** — see "Rationale for accepting" below.
- Reporter: package-build agent, 2026-08-15, from the native-Windows execution recorded in
  [`docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md`](docs/PACKAGE_BUILD_RECORD_20260815_EF5450C.md).
  Investigated and adjudicated 2026-08-15; recorded here 2026-08-16.
- Owner: **none required on this side.** Owned upstream (godotengine/godot). The one
  follow-up that would belong to a person here is filing an upstream issue naming
  `ReflectionProbe`, which the investigation notes was not located and is optional.
- Affected loop beat: **none.** It occurs only during process teardown, after every beat
  (begin shift, walk, board, start, launch, fly, fire, return, land, shut down, disembark)
  has already completed. No player-observable behaviour is involved at any beat.
- First affected source: unknown — the warning predates the records that name it, and both
  earlier ROADMAP mentions misattributed it (see below), so no first-bad commit was
  bisected. Last confirmed affected source: `e57d207` (this worktree's `main`), reproduced
  today. The package-build observation was on `ef5450c`.
- Affected artifact hashes: Windows GUI EXE `gateE-20260815-ef5450c`, SHA-256
  `2325f175e336c70bda247ccba3d4617867fad19c962772d09928e7f9fb929583`, 153,713,144 bytes,
  PE version `0.12.0.0`, embedded PCK sorted-path manifest SHA-256
  `dc0800edfdf7a553d98e8b398d493461ef7e9eaa7dd1f309debb9466fde34684`.
- Nearest owning source in this repo (**not** the defect):
  `scripts/world/shipyard_world.gd` (SHA-256
  `76b58bde7e53ff670b7ffdb5883fa808be344524e2253ee069cb7c720d6b3821`),
  `_build_central_reflection_probe()` at `:2638`, called from `:2356` via `_ready()`.
  It builds `CentralBerthReflectionProbe`, `update_mode = UPDATE_ONCE`, the only
  `ReflectionProbe` in the project.

### Environment — two documented configurations, identical result

| | Configuration A (native Windows) | Configuration B (this box) |
| --- | --- | --- |
| OS | Windows 11 `10.0.26200.9168` | WSL2 Linux `6.18.33.2-microsoft-standard-WSL2` |
| CPU | Intel Core i9-14900 (32 threads) | same host, 32 threads |
| RAM | 94 GiB usable, 24 GiB swap | 94 GiB usable |
| GPU / driver | NVIDIA GeForce RTX 5070 Ti, Vulkan 1.4.341 | no `/dev/dri`; lavapipe `llvmpipe (LLVM 20.1.2, 256 bits)`, Vulkan 1.4.318 |
| Renderer profile | Forward+ | Forward+ **and** Forward Mobile, both tested |
| Display driver | as recorded: `--headless --quit-after 300` (see note) | `x11` under `xvfb-run` |
| Audio | `Dummy` | `Dummy` |
| Input | none (headless) | none (headless / scripted) |
| Resolution | default | 1280×720, 1920×1080 and 2560×1440 all tested |
| User data | clean | clean |
| Godot | 4.7.1.stable.official.a13da4feb | 4.7.1.stable.official.a13da4feb |

The count is **7 on both**, which is itself load-bearing evidence: it is neither an
llvmpipe artifact nor GPU-specific.

**Note on configuration A, unresolved:** the recorded native-Windows invocation passes
`--headless`, yet its banner reads `Vulkan 1.4.341 - Forward+ - Using Device #0: NVIDIA -
NVIDIA GeForce RTX 5070 Ti` and it leaks 7. On Linux, `--headless` creates no rendering
device and leaks 0, which is the whole reason the matrix cannot see this. Whether the
exported Windows template treats the flag differently, or the flag was ineffective in that
interop invocation, was **not** determined. It does not affect the verdict — configuration
B reproduces the leak with an unambiguously real rendering device — but it should not be
read as "`--headless` opens a rendering device", because that is not established.

### Steps

1. Ensure `.godot/` exists: `godot --headless --path . --editor --quit`.
2. Run the shipped main scene with a real rendering device and no harness:
   `xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --display-driver x11
   --rendering-driver vulkan --audio-driver Dummy --quit-after 300`.
3. Read the last two lines of stderr.
4. Repeat with `--quit-after 900`, and with `--rendering-method mobile`.

### Expected / actual

- **Expected:** the process exits `0` with no `Leaked` diagnostic. The playable-prototype
  gate in [`ROADMAP.md`](ROADMAP.md) names "resource-leak" diagnostics explicitly.
- **Actual:** exit `0`, and always:

  ```
  WARNING: 7 RIDs of type "Texture" were leaked.
     at: finalize (servers/rendering/rendering_device.cpp:8900)
  ```

### Failure frequency

Deterministic — but stated precisely rather than as a "10/10", because no single scenario
was run ten times. **Every** rendered run in the investigation's tables and every rendered
run performed for this record produced exactly 7, and no rendered run has ever produced a
different non-zero count: 7 at 20, 300 and 900 frames; 7 on Forward+ and on Forward
Mobile; 7 on llvmpipe and on the RTX 5070 Ti; 7 with one `ReflectionProbe` and 7 with
four; 7 from four different capture harnesses that load `ShipyardWorld`. Runs that never
render `ShipyardWorld`, and every `--headless` Linux run, produce 0. It was observed again
unprompted in today's `tests/capture_hero_cell.gd` verification runs for CAPTURE-001 below
— an independent sighting on `e57d207`.

### Root cause — engine-side, proven by an empty-project reproduction

Full investigation, including the bisection table and the ruled-out candidates:
[`docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md`](docs/TEXTURE_RID_LEAK_INVESTIGATION_20260815.md)
(SHA-256 `d130a8229157344a6ff1604fd887763b98cb8a1b1e69a40d82530464c94fc344`).

A ~70-line project containing only a `Camera3D`, a `MeshInstance3D` and **one stock
`ReflectionProbe`** leaks all seven. Three facts settle the attribution:

1. **No project content is involved.** `WorldEnvironment`, `BG_SKY`,
   `ProceduralSkyMaterial`, glow, and a shadow-casting `DirectionalLight3D` were each
   tested individually in that empty project and leak **0**. Adding the probe alone takes
   it to 7.
2. **The count does not scale with probe count.** One probe and four probes both leak
   exactly 7, so this is a single shared reflection atlas allocated on first use, not a
   per-probe resource. That also explains the stable "7" across unrelated scenes,
   harnesses, GPUs and drivers.
3. **Freeing the probe does not clear it.** Removing and `free()`-ing the probe ten frames
   before shutdown and rendering ten more frames still leaks 7. There is therefore no
   teardown any game code could add.

`Node.print_orphan_nodes()` printed nothing in every run — no `Node`s leak. The repo has
no `static var`s, no runtime `ImageTexture`/`NoiseTexture2D`/`GradientTexture`
construction in `scripts/`, no `SubViewport`/`ViewportTexture` outside `tests/`, and one
read-only `RenderingServer` call
(`scripts/rendering/visual_quality_controller.gd:119`). The one `const Texture2D`
cache — `scripts/effects/pulse_weapon_presentation.gd:39` — was suspected and cleared
twice independently.

Upstream references for the same class (RD-level RIDs surviving
`RenderingDevice::finalize()` in trivial projects): godotengine/godot
[#89182](https://github.com/godotengine/godot/issues/89182),
[#73577](https://github.com/godotengine/godot/issues/73577). No upstream issue naming
`ReflectionProbe` specifically was located.

### Rationale for accepting

- It is **bounded and fixed**: seven RIDs, once, at `finalize()`, immediately before the
  process exits and the OS reclaims everything. It does not grow with frame count, does
  not grow with probe count, and cannot reach a long-running session because it happens
  only during teardown.
- **No application-side repair exists.** Fact 3 above rules out teardown ordering. The
  only remaining levers are deleting `CentralBerthReflectionProbe` — a real visual
  regression to the central berth's hero lighting, traded for suppressing a cosmetic
  engine message — or suppressing the warning. Both are papering over.
- Two earlier characterisations were **wrong in their reasoning** and are corrected here:
  `ROADMAP.md` called it "the known seven-Texture-RID **llvmpipe** shutdown warning" and
  "the known seven-Texture-RID **capture** warning". It occurs identically on an RTX
  5070 Ti under a real NVIDIA driver, and it occurs in the shipped game running its own
  main scene with no harness. The severity call was right; the attribution was not, which
  is exactly why it kept resurfacing as an unowned finding.

### Known limits of this record

- The seven RD textures were **not individually named.** Godot 4.7.1 stable reports only a
  count; per-RID tracking is `RID_HANDLE_ALLOC_TRACKING_DEBUG`, a debug-build feature not
  compiled into the stable binary used here. "A shared reflection atlas" is inferred from
  the count's invariance to probe count, not read out of the engine.
- The **"0 after removing the probe" figure was measured only under lavapipe**, not
  re-measured natively on the RTX 5070 Ti. The unmodified count (7) does match the Windows
  record exactly.
- This collides with the literal wording of the playable-prototype gate ("no ...
  resource-leak ... diagnostics"). That gate wording needs an explicit carve-out for this
  shutdown warning, or every future rendered candidate run will re-open the same
  adjudication. Recorded, not silently absorbed.

### Linked reproducer / regression

**None, deliberately.** The bisection probe (`tests/zz_leak_probe.gd`) and the empty
comparison project were not committed: `tests/` is matrix-scanned and a permanent
regression asserting "the engine still leaks 7" would fail the moment upstream fixes it,
which is the wrong direction for a gate. The reproduction is the four numbered steps
above plus the empty-project recipe at the end of the investigation document. The headless
matrix structurally cannot see this — `--headless` creates no rendering device — which is
why `tools/release/run_test_matrix.sh` stays clean and is not a regression on it.

## CAPTURE-001 — `tests/capture_hero_cell.gd` cannot pass on unmodified `main` in this environment — **REPRODUCED**

- Status: `REPRODUCED`, **adjudicated 2026-08-16**. The record no longer holds an
  unadjudicated hypothesis: the decisive experiment it named was run, the hypothesis was
  upheld in substance and wrong about which emitter, and that **gate-design defect is now
  fixed** in the harness with no threshold moved. Two causes remain, one of them newly
  identified. See "Adjudication" below. Severity: **P2**. Disposition: **still open, still
  needs an owner** — both remaining repairs either change what an acceptance harness asserts
  or need a second rasteriser to adjudicate, and neither is a housekeeping call.
- Reporter: housekeeping agent, 2026-08-16. Independently reproduced here from a clean
  checkout before recording; a sibling agent had reported it first (stash-and-rerun on
  unmodified `main`) and this record does **not** rest on that report. Adjudicated the same
  day on `fcfa58e` by the capture-harness agent, from five completed rendered runs (A–D and
  a confirming F; one run aborted on X-display contention with a sibling worktree and is not
  counted).
- Owner: **needed.** Whoever calibrated `SHIP_LUMINANCE_P5_MINIMUM`,
  `GRAPHITE_BACKGROUND_MINIMUM_DELTA` and `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION`,
  or the current owner of the hero-cell evidence path.
- Affected loop beat: **none in the shipped game.** This is developer tooling. It does not
  gate the matrix — `capture_hero_cell.gd` is not a `tests/*_test.gd` file, so
  `tools/release/run_test_matrix.sh` never runs it — and no player-facing behaviour is
  implicated. It is recorded because a harness that cannot pass on unmodified `main` is a
  trap: the next person to run it reads a red as their own regression.
- First affected source: unknown — no bisection was run, and the harness is only invoked
  by hand. Last confirmed affected source: `e57d207`, today, working tree clean apart from
  the two unrelated test-wait conversions in this same commit (neither is on the
  hero-cell path). Harness SHA-256
  `e6fd564acaa9651b58d96df2f45f9394e810eac535b6e615d897db7726636d34`.
- Affected artifact hashes: **none produced.** See "The harness publishes nothing on
  failure" below — that is part of the defect's cost.

### Environment

Single configuration; the second configuration this record would need to be a
`NOT_REPRODUCED`-grade adjudication is precisely the real-GPU box it was calibrated on,
which is not available here.

| | |
| --- | --- |
| OS | WSL2 Linux `6.18.33.2-microsoft-standard-WSL2` on Windows 11 |
| CPU | Intel Core i9-14900, 32 threads |
| RAM | 94 GiB usable |
| GPU / driver | **no `/dev/dri`** — Vulkan resolves to lavapipe, `llvmpipe (LLVM 20.1.2, 256 bits)`, Vulkan 1.4.318 |
| Renderer profile | `forward_plus` (as the documented invocation requires) |
| Display driver | `x11` under `xvfb-run -a -s "-screen 0 2560x1440x24"` |
| Audio | `Dummy` |
| Input | none — the harness scripts every state |
| Resolution | 2560×1440 (`--resolution 2560x1440`, `CAPTURE_RESOLUTION`) |
| User data | clean |
| Godot | 4.7.1.stable.official.a13da4feb |

### Steps

1. `godot --headless --path . --editor --quit` (a fresh worktree has no `.godot/`).
2. Run the invocation documented at `README.md:352`, with `--audio-driver Dummy` added so
   it is headless-safe:
   `xvfb-run -a -s '-screen 0 2560x1440x24' godot --path . --resolution 2560x1440
   --rendering-method forward_plus --audio-driver Dummy --script res://tests/capture_hero_cell.gd`
3. Read `$?` and the `HERO_CELL_FAIL` lines.

### Expected / actual

- **Expected:** `HERO_CELL_CAPTURE_OK: 18 HUD-off source-frozen Forward+ frames at
  2560x1440`, exit `0`, and 18 published PNGs plus both manifests in `artifacts/hero_cell/`.
- **Actual:** `HERO_CELL_CAPTURE_FAILED`, exit `1`, nothing published.

### Failure frequency — 3/3 here, 4/4 including the sibling's run

Every gated metric, across the three runs performed for this record:

| Metric | Gate | Run 1 | Run 2 | Run 3 | Sibling |
| --- | --- | --- | --- | --- | --- |
| `ship_luminance_p5` | `> 0.04` | n/c | 0.0440 ✅ | 0.0445 ✅ | **0.0339** ❌ |
| `ship_luminance_p95` | `< 0.95` | n/c | 0.7546 ✅ | 0.7546 ✅ | — |
| `graphite_background_delta` | `>= 0.08` | **0.0781** ❌ | **0.0781** ❌ | **0.0766** ❌ | **0.0620** ❌ |
| ship-mask clipped luminance | `< 0.005` | n/c | 0.0026 ✅ | 0.0029 ✅ | — |
| cockpit OFFLINE/ONLINE exterior | `<= 0.005` | n/c | 0.0044 ✅ | 0.0045 ✅ | — |
| cockpit ONLINE/CRITICAL exterior | `<= 0.005` | **0.4148** ❌ | **0.0511** ❌ | **0.3808** ❌ | **0.1485** ❌ |

`n/c` = not captured. Run 1's stdout was truncated before the per-metric `PASS` lines were
read; its two failing values are recovered from the aggregate `HERO_CELL_CAPTURE_FAILED`
line, which enumerates every failure, so run 1 is known to have failed on exactly those
two and no others. Runs 2 and 3 were captured in full. The sibling column is that agent's
reported figures, retained for comparison but not relied on.

Exit `1` in 3/3. Every other assertion in the suite passes, including the complete
recursive source-freeze roster (471-file class, byte-identical before and after the
capture) and all 18 frame captures.

### These are two different problems, not one

> Retained as recorded on `e57d207`. **Superseded by "Adjudication" below**, which measured
> all four metrics again after the station lighting scheme landed and found three
> independent causes, not two. The split below was right about the *shape* of the
> ONLINE/CRITICAL failure and wrong about the emitter behind it.

The "thresholds were calibrated on real GPU hardware and this box is llvmpipe" reading
covers **one** of the two failures and not the other. Both halves are recorded because
recalibrating the numbers would close only the first and leave the harness red.

1. **`graphite_background_delta` — consistent with a calibration mismatch.** Stable across
   runs (0.0766–0.0781, a 1.9% spread) and only ~4% short of the `0.08` gate. This is the
   shape of a threshold that was set with real headroom on a different rasteriser and has
   none here. `ship_luminance_p5` belongs to the same family: it sits *on* its gate
   (0.0440/0.0445 against `> 0.04`, ~10% headroom) and the sibling's 0.0339 shows it
   flipping. Recalibration is a plausible repair for both — but only an owner can decide
   whether to widen the gate or accept that these two are unmeasurable without a GPU.
2. **cockpit ONLINE/CRITICAL exterior — *not* a calibration mismatch.** It ranges
   **0.0511 → 0.4148 across three runs of identical input**, i.e. 10× to 83× over a gate
   of `0.005`, with an 8× run-to-run spread. No single threshold value fits that. Its
   sibling comparison, cockpit OFFLINE/ONLINE, uses the **same gate and the same code path**
   and passes stably at 0.0044/0.0044/0.0045. So the gate itself is satisfiable here; the
   ONLINE→CRITICAL pair specifically is not.

**Leading hypothesis for (2), stated as a hypothesis and not adjudicated:** the CRITICAL
frame is produced by `_torrent.apply_damage(_torrent.maximum_hull * 0.76)`
(`tests/capture_hero_cell.gd:588`), which drives the live production damage presentation.
If that presentation puts anything stochastic outside the hull — sparks, smoke, a particle
system — those pixels are exterior/world pixels by the mask's own definition, they change
between the two frames by design, and their count varies per run. The harness's own
recorded limitation says the raw all-pixels-outside metric is deliberately *not* gated
"because live warning/practical lights intentionally change opaque cockpit surfaces", and
carves the gate down to triangle-unoccluded exterior/world pixels; the same reasoning may
simply not have been extended to damage VFX, which are outside the hull rather than on it.
That would make this a **gate-design defect rather than an environment defect**, and it
would fail on real hardware too. Confirming or refuting it needs one run with the damage
presentation suppressed, which was not performed here.

### Adjudication — 2026-08-16, on `fcfa58e`

The decisive experiment was run. Everything above was measured on `e57d207`, which predates
the station lighting scheme (`1ff7df2`, merged `6cca05d`), so all four metrics were
re-measured first. **The lighting pass moved three of them, one of them by 40×**, which by
itself retires the "these numbers just need widening" reading: the graphite figure the
record calls "stable and ~4% short" is no longer 0.0766–0.0781 on `main`.

Re-measurement on `fcfa58e`, same box, same documented invocation:

Run A is unmodified `main` from a pristine copy (harness SHA-256 identical to the one this
record was filed against). Runs B–D carry the instrumentation and then the repair.

| Metric | Gate | on `e57d207` | run A (unmodified) | run B | run D (repaired) |
| --- | --- | --- | --- | --- | --- |
| `ship_luminance_p5` | `> 0.04` | 0.0440–0.0445 | **0.0829** ✅ | 0.0830 ✅ | 0.0830 ✅ |
| `ship_luminance_p95` | `< 0.95` | 0.7546 | 0.7593 ✅ | 0.7593 ✅ | 0.7593 ✅ |
| `graphite_background_delta` | `>= 0.08` | 0.0766–0.0781 ❌ | **0.0019** ❌ | **0.0006** ❌ | **0.0019** ❌ |
| ship-mask clipped luminance | `< 0.005` | 0.0026–0.0029 | 0.0011 ✅ | 0.0011 ✅ | 0.0011 ✅ |
| cockpit OFFLINE/ONLINE exterior | `<= 0.005` | 0.0044–0.0045 ✅ | **0.0074** ❌ | 0.0050 ✅ | **0.0074** ❌ |
| cockpit ONLINE/CRITICAL exterior | `<= 0.005` | 0.0511–0.4148 ❌ | **0.4534** ❌ | **0.2748** ❌ | **0.0052** ❌ |

`ship_luminance_p5` is no longer marginal: the lighting pass roughly doubled it and it now
clears its gate by 2×. That half of finding (1) is closed by the lighting pass, not by any
harness change.

Note what the last two rows do after the repair. ONLINE/CRITICAL drops from 0.4534 to
0.0052 and becomes **indistinguishable from its stable sibling** — the outlier that no
threshold could fit is gone, and what is left on both rows is one shared, different problem
described under "The remaining two failures".

**Verdict on the ONLINE/CRITICAL hypothesis: upheld in substance, wrong in its named
emitter.** The cause is the live production damage presentation, and it is a gate-design
defect that fails on real hardware too — but it is not the stochastic particles. Three
readbacks of the same frozen scene, with each candidate quiesced in turn, separate them:

| Readback of the identical frozen CRITICAL scene | exterior changed fraction |
| --- | --- |
| fully live production damage presentation | 0.2748 |
| `DamageSparks`/`EngineFailureSparks`/`EngineSmoke` hidden, damage lights still live | **0.3127** |
| every transient damage emitter quiesced (particles **and** the two damage lights) | **0.0051** |

Hiding the stochastic particles did not reduce the metric at all — it read *higher* than the
live frame, because the lights kept moving between readbacks. Quiescing the lights collapsed
it to the renderer's own noise floor. The emitters are
`HeroDamagePresentation.DamageWarningLight` and `EngineFailureLight`
(`scripts/effects/hero_damage_presentation.gd:419`), whose energies are
`(1.4 + pulse) * urgency` with `pulse = sin(elapsed * 13)`, and
`2.8 * clampf(0.48 + 0.28 * sin(elapsed * 29) + 0.18 * sin(elapsed * 61), 0.12, 0.88)`.
Both are pure functions of accumulated presentation time, so the energy at readback is
whatever phase the frame timing happens to land on — a 3.4× swing on the warning light
alone. That is exactly the shape of the 0.0511 → 0.4534 spread across runs of identical
input, and it reproduces on any GPU: the sinusoids do not care about the rasteriser.

The particles are real and do reach exterior pixels — `local_coords = false`, `spread`
165°/48°, `randomness` 0.58–0.72, and they are `CPUParticles3D`, which
`_cockpit_occluder_mesh_records()` cannot classify because it only collects
`MeshInstance3D` — but their contribution is inside the noise of the light pulse.

**Fixed, in the harness, without moving a threshold.** The exterior comparison exists to
prove the fixed camera, the craft pose and the frozen world are identical between the two
frames, so that the physical-display ROI change is attributable to the readout. Pulsing
damage illumination is neither the world nor the pose, so the gated comparison now uses the
deterministic half of the critical state: after the fully live
`18_cockpit_critical_fixed.png` is staged, the transient damage emitters are made invisible,
the fixed-camera contract is re-validated, and one extra unpublished frame is read back for
the control (`_capture_cockpit_critical_exterior_control`). This is the same carve-out the
harness already documents for the raw outside-ROI metric — "live warning/practical lights
intentionally change opaque cockpit surfaces" — carried the rest of the way, because those
lights do not stop at the cockpit surfaces. `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION`
is **unchanged at 0.005**, the published critical frame is **unchanged and fully live**, and
the live exterior number is still measured and recorded as
`cockpit_online_critical_live_damage_exterior_world_non_gated` so nothing is hidden.

Measured on the repaired harness, three runs: live 0.4705 / 0.2765 / 0.4312 (recorded,
non-gated), transient emitters quiesced **0.0026 / 0.0052 / 0.0053** against the same
unchanged 0.005 gate — the live figure still swings by 1.7×, the gated one no longer moves
in the third decimal. That separation is the whole result. The
metric that ranged over an 8× spread across runs of identical input now lands inside the
renderer's own noise band, alongside the sibling comparison that was always stable. Run D
still trips the gate at 0.0052 — but for the reason the sibling trips it at 0.0074, not for
the reason this comparison used to.

### The remaining two failures, and why neither was "fixed" here

**(1) `graphite_background_delta` was not recalibrated, deliberately.** The gate is
`abs(graphite_median - background_median) >= 0.08`, where `background` is every mask sample
that did *not* hit the ship — i.e. whatever the station happens to put behind it. On
`fcfa58e` those two medians are `graphite 0.153652` and `background 0.153013`: the backdrop
has drifted onto the same luminance as the material, and the delta is 0.0006. Nothing about
the graphite material changed; the station lighting scheme did. The same run measures
`ivory_luminance_median 0.575780` against that graphite, so the ship's own material
separation is 0.42 and in excellent health — the material contrast this gate is presumably
meant to protect is not in trouble at all.

So the gate fails the "is it measuring the right thing" test: it benchmarks a ship material
against an uncontrolled backdrop, which makes it a property of the scenery, not of the
craft. Widening it to 0.0006 — or to anything — would be recalibrating to match a broken
measurement, which is worse than leaving it red. The repair is to give it a controlled
reference (the ivory/graphite separation is the obvious candidate, and is robust), but that
changes what the harness asserts and is an owner call.

**(2) The cockpit exterior gate has no headroom over this box's renderer noise floor.** This
now covers *both* exterior rows. The repaired harness measures the floor every run and
prints it: two readbacks of a single **unchanged** ONLINE state — zero scene difference,
zero state change — compared through the same exterior mask.

| Run | settle frames | measured noise floor | OFFLINE/ONLINE, same run | ONLINE/CRITICAL quiesced, same run |
| --- | --- | --- | --- | --- |
| B | 8 | 0.0044 | 0.0050 | 0.0051 (diagnostic) |
| C | 48 | 0.0124 | 0.0115 | 0.0026 |
| D | 8 | 0.0120 | 0.0074 | 0.0052 |
| F | 8 | 0.0121 | 0.0072 | 0.0053 |

The floor is **0.0044–0.0124 against a gate of 0.005**, and every gated exterior figure now
sits inside that band. Runs D and F are the same shipped harness and reproduce each other to
three decimals on every one of these figures, so what is left is stable and measurable — it
is simply larger than the gate. That settles what these comparisons are measuring on this box:
**renderer noise, and nothing else.** TAA is enabled on the capture viewport
(`_configure_native_capture` sets `root.use_taa = true`) and never stops jittering, so a
deliberately frozen scene is simply not reproducible below the gate here.

Settling longer was tried as a candidate repair and bought nothing — 8 frames gave 0.0044
and 0.0120 on two runs, 48 frames gave 0.0124 on one, so the floor is unstable run to run
and independent of the settle length, while 48 frames cost roughly three times the harness
runtime. `COCKPIT_DIFFERENTIAL_SETTLE_FRAMES` therefore stays at the original 8, with the
measurement recorded in the constant's comment so the next person does not repeat the
experiment. The floor is recorded, never gated: the harness does not get to pass by
declaring its own noise acceptable.

This one **is** genuinely environment-shaped — a real GPU with a stable TAA history would
plausibly sit far below 0.005 — but it cannot be adjudicated from one rasteriser, and the
gate value was not touched.

### Two things found on the way that are not this defect

- **`apply_damage` normalises an infinite vector on its own default path.**
  `_torrent.apply_damage(amount)` with no hit position leaves `world_hit_position` at
  `Vector3.INF`, and `scripts/ships/hero_ship.gd:1263` then evaluates
  `(world_hit_position - global_position).normalized()`, which prints
  `WARNING: Vector3 cannot be normalized, the elements must be finite`. The result is
  discarded — `present_impact` is correctly skipped because `is_finite()` is false — so this
  is cosmetic, but it fires on every damage call that omits a position. Not repaired here:
  `scripts/ships/` is outside this worktree's scope.
- **The stale transaction directory is still not cleaned on the failure path**, exactly as
  the section below records. Unchanged.

### The harness publishes nothing on failure

The capture is transactional. All 18 PNGs are written to
`artifacts/hero_cell/.capture_transaction/` and promoted only after every check passes, so
a failing run leaves `artifacts/hero_cell/` containing **no published frames, no
`source_manifest.sha256` and no `evidence_manifest.json`** — just a stale
`.capture_transaction/` directory with 18 orphaned files. Verified directly after all
three runs. Two consequences worth recording:

- There is no `log/image path + hash` evidence to cite for this record, which is why the
  metric table above is the durable anchor. (`artifacts/` is gitignored in any case; the
  package build record uses the same hashes-as-anchor convention.)
- Anyone re-running the harness inherits the previous run's stale transaction directory.
  Nothing observed it being cleaned up on the failure path.

**Partly addressed, 2026-08-16.** The first consequence was the more expensive one — the
numbers this record exists to preserve were reachable only by scraping assertion text — so
the harness now prints every measurement it took, on both paths, as `HERO_CELL_METRICS:`
lines carrying the full JSON of `ship_mask_lighting` and of every pair comparison including
the non-gated ones (`_print_measured_metrics`, called unconditionally from `_finish`). The
stale-transaction consequence is **unchanged**: nothing cleans `.capture_transaction/` on
the failure path.

### Linked reproducer / regression

The reproducer is the three numbered steps above. **No regression was added**, deliberately:
a `tests/*_test.gd` asserting that the hero-cell harness currently fails would land inside
the matrix glob and turn a tooling defect into a gate, and it would go red the moment the
harness is repaired. The correct regression is the harness itself, once an owner has
decided what it should assert on a GPU-less box. That reasoning is unchanged by the
adjudication: the ONLINE/CRITICAL repair is a change to `tests/capture_hero_cell.gd` and its
regression is the harness's own `HERO_CELL_PASS` line, which the matrix structurally cannot
run and should not be made to.

### What would close this record

1. `graphite_background_delta` given a controlled reference instead of the station backdrop,
   or retired. Owner decision — it changes what the harness asserts.
2. `COCKPIT_MAXIMUM_OUTSIDE_ROI_CHANGED_FRACTION` adjudicated against a real GPU, where the
   printed noise floor can be compared with this box's 0.0044–0.0124. If the floor there is
   an order of magnitude below the gate, the gate is right and this box is simply not a
   valid platform for it — which is a documentation change, not a threshold change.

The ONLINE/CRITICAL **gate-design** defect is closed and needs nothing further; what remains
on that row is item 2 above, shared with its sibling. The harness still exits `1` on this
box, on `graphite_background_delta` and on both exterior comparisons.
