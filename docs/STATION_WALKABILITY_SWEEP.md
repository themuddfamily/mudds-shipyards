# Station walkability sweep — Phase 10 §1

`tools/station_walkability_sweep.gd` boots `scenes/main.tscn`, reuses
`tools/station_walkable_area_census.gd`'s 82-surface walkable roster (the
baseline declarations plus every module that publishes `walkable_surface`
metadata), and sweeps the production player capsule (0.38 r / 1.94 h,
mask 7, `scenes/player/player.tscn`) on a 0.25 m grid at standing height over
every one of those decks, aprons, branch arms, ramps and interiors.

Run it with:

```
godot --headless --audio-driver Dummy --path . --script tools/station_walkability_sweep.gd
```

It exits 0, prints a per-module summary, and writes the full triage list to
`user://station_walkability_sweep.json`. It is a probe, not a gate.

## Defect classes

| class | meaning |
| --- | --- |
| `invisible_blocker` | collision stops the capsule with no visible geometry within 0.3 m |
| `walk_through` | a rendered piece ≥ 0.4 m tall stands on a walkable cell with no collider anywhere in its volume |
| `choke` | an authored lane pinched below 0.9 m of clear width between two blockers |
| `gap` | an authored walkable cell, or a 1–2 cell seam between two authored decks, with no floor within 0.3 m below |

Two headless details the probe has to handle, both recorded in its source: the
dummy rendering server answers identity for `MultiMesh.get_instance_transform()`
and an empty box for a batch's AABB, so batched dressing is located by decoding
`MultiMesh.buffer` (falling back to the modules' `authored_instance_transforms`
metadata); and a cell centre can land exactly on a deck's outer face, so a gap
must miss a 4 cm cross of floor rays, not one ray.

## Results

First sweep, 2026-09-14 at `4808160f`: **82 surfaces, 135,117 cells, 39,495
blocked, 46 findings** — 0 `invisible_blocker`, 44 `walk_through`, 0 `choke`,
2 `gap`.

Zero chokes is a measurement, not a silence: the probe measured 341 bounded
lanes and the narrowest clear width anywhere on the station is **0.98 m** on the
Aft operations floor, followed by 1.02 m in the Habitat corridor and 1.08 m on
Jovian apron deck 04. Zero invisible blockers is likewise a real result — every
collider the capsule met had geometry drawn at it.

After the fixes below: **19 findings** — 0 / 19 / 0 / 0. Both `gap` findings are
closed and every fixed `walk_through` family is gone. The Aft transfer-gate ribs
closed the station-module families (37 -> 31); the twelve parked-craft underside
findings closed next (31 -> 19), which took `jovian_freight_berth` to zero
findings and `shipyard_world` from 15 to 11. Blocked cells rose from 39,620 to
39,689 and then to 39,904; the parked craft added four bounded lanes
(341 -> 345) and none of them is narrow enough to report, so the narrowest lane
on the station is still the Aft operations floor's 0.980 m.

## Triage

### Fixed

1. **Observation Logistics Spur — six light masts had no collision.**
   2.8 m masts standing on the logistics pad and the pad cross landing that the
   player walked straight through. Every other piece of pad dressing here
   (pallets, cases, consoles, the bench) is a `StaticBody3D` with a `Marker3D`
   anchor for the shared render batch; the masts were the one family that got
   the anchor and no body. Added `LightMastCollision01..06` at the identical
   pose and 0.16 × 2.8 × 0.16 section. *Player effect:* the masts now stop you
   like the pallets beside them.
   `scripts/world/observation_logistics_spur.gd`, asserted in
   `tests/observation_logistics_spur_test.gd`.

2. **VIP Reception — four armchairs were solid only at the pedestal.**
   The 0.28 m bronze pedestal disc had collision; the 0.72 × 0.16 × 0.70 seat
   cushion and the 0.62 m back did not, so the capsule passed through every
   chair in the room at chest height and stopped at ankle height. Seat and back
   are bodies now. Sitting is unaffected — `PlayerController.begin_boarding()`
   disables the player's own collision and the seat's exit pose stands 1.05 m
   clear. *Player effect:* the reception reads as furnished rather than painted.
   `scripts/world/vip_reception_suite.gd`, asserted in
   `tests/vip_reception_suite_test.gd`.

3. **Upper Operations — the observation landing's fixed viewer had no
   collision.** A 1.05 m post and a head at chest height, standing between the
   `LandingObservationConsole` and the `LandingEquipmentLocker`, which are both
   solid. *Player effect:* you no longer walk through one instrument on a
   landing where the two either side of it stop you.
   `scripts/world/shipyard_world.gd`, asserted in
   `tests/station_surface_playability_test.gd`.

4. **Jovian freight berth — 0.30 m open slot in the registry handoff floor.**
   The only floor `gap` anywhere on the station. Connection leaf B stopped at
   x = -49.30 while the Modern Fleet Registry pod deck carried on from x = -49.0
   at the same y = 0.380 plane, leaving an open slot 0.30 m wide and 2.2 m long
   between two walkable decks on the registry-to-freight route. A 2026-08 pass
   had measured that slot and correctly concluded a player cannot fall through
   it (0.30 m against a 0.76 m capsule), which is why the +X approach rail
   starts north of it — that stays true and the rail is unchanged, but you could
   still see space through the floor. Leaf B now meets the shelf exactly as leaf
   A does. Both new contacts are edge seams with zero shared volume.
   *Player effect:* one continuous deck between the registry pod and the freight
   branch. `scripts/world/jovian_freight_berth.gd`, asserted in
   `tests/jovian_freight_berth_transform_test.gd`.

5. **Aft Junction Stack — six upper transfer gate ribs (2.35 m) had no
   collision.** The one deferred defect this sweep confirmed, and the one that
   needed layout work rather than a collision flag. The module declared
   `collision_solution: deck_supported_visual_ribs_outside_lane`, but the deck is
   walkable *at* the rib rows and not only between them, so a player off the
   centre lane walked through a 2.35 m gate post.

   Each drawn rib now carries a `TransferRibCollision01..06` body at its own pose
   and its own `0.24 x 2.35 x 0.52` section, so the collider can never be wider
   or narrower than what is drawn. That alone would have left the gate funnelling
   players into `OperationalLattice/Activities/AftCrewWorkPost`, which splits the
   deck north of the gate in two: the bench ends at x = -6.6 and the cable drum
   and supply crate start at x = -5.55, leaving a **1.050 m** west aisle between
   them and the open east lane past the crate. Measured live with the production
   capsule at the authored +/- 1.95 m rib spacing, the solid ribs squeezed the
   east-lane crossing to **1.151 m** between a rib and the supply crate. The rib
   pair therefore moved out to +/- 2.40 m about the deck's own x = -5.15
   centreline, which keeps them symmetric on the route stripe and over the
   `UpperFloorInset` they bear on, takes that crossing to **1.601 m**, and widens
   the gate's own clear lane from 3.66 m to **4.56 m**. Shoulder lanes outside
   the ribs are 2.36 m (west, to the deck rail) and 2.84 m (east, to the
   operations-room west wall); the first rib row measures 4.29 m because the
   stair-head muster locker's east bay shoulders into it. The declared
   `collision_solution` is now `solid_ribs_at_drawn_section_outside_lane` and the
   profile publishes the measured aisle widths.

   Nothing moved on the work post, which another module owns. What did move is
   the production traversal witness's Cinder tour: three of its legs crossed the
   deck laterally at world z = 63.0 — straight through the x = -3.2 rib column —
   and could only ever have done so while the ribs were porous. All three now use
   the same crossing a player would: the open north deck at z = 67.0, the east
   lane south through the gate, then west along z = 61.25, south of the rib rows
   and north of the south deck rails. No leg was shortened and no waypoint left
   the walkable deck. *Player effect:* the transfer gate is a gate — you walk
   through the 4.56 m lane it frames instead of through its posts, and both ways
   past the crew work post stay walkable.
   `scripts/world/aft_junction_stack.gd`, asserted in
   `tests/aft_junction_stack_test.gd` (`_test_production_upper_deck_aisles`
   re-measures every figure above on the live station with the production
   capsule) and re-walked in `tests/station_traversal_defect_witness_test.gd`.

6. **Parked craft undersides — twelve findings on the two berthed ships.**
   The deferred list below was emptied by giving each drawn piece a collider at
   its own drawn section on the ship's own root body, which is where both craft
   already keep every other hull, deck and sole shape. Nothing was remodelled;
   the only thing that changed is what you bump into.

   *Arrow, port berth deck (4 findings).* `ArrowHullCollision` stops at local
   z = 5.75 and the drawn tail runs to z = 6.93, so both ceramic engine collars
   and both refractory nozzle bells stood over the deck with no collider
   anywhere in their volume. Their lowest drawn point clears that deck by
   1.39 m against a 1.94 m production capsule, so a walker crossing behind the
   parked craft put their head and shoulders through an engine bell. Each piece
   now carries its own cylinder about the nacelle axis — the collar at its
   0.70 m outer radius over its 0.1477 m ring depth, the nozzle at its 0.57 m
   widest radius over its full 0.88 m bell — measured against the renderer it
   answers for in `tests/arrow_recon_ship_test.gd`. A box would have claimed
   0.29 m of empty air at each corner of a round collar. Root shapes 5 -> 9.
   The landing envelope grows aft only: z-max 5.75 -> 6.93, the drawn nozzle
   mouth exactly, with the sole plane (y = -1.17), the wing span (x = +/- 5.55)
   and the roof (y = 1.675) untouched. `ENGINE_DAMAGE_CUE_*` still slides the
   starboard collar's *renderer* outboard as a chase-view damage silhouette;
   that cue stays presentation-only, because a craft whose collision envelope
   moved when it took a hit would fly and land differently damaged.

   *Jovian, freight apron (8 findings).* Everything this craft parks *on*, plus
   everything aft of `AftHullCollision`, was presentation only: the two
   reachable landing bogie struts, their dampers, two of the four sole
   castings, and the two lower exhaust collars — 2.04 m engine bells whose
   lowest drawn point clears the apron by 1.38 m. Each leg shaft and damper now
   carries a cylinder at its own lathe radius (0.26 m over 1.5 m, 0.15 m over
   1.25 m) at the renderer's own cant; each sole carries the convex hull of its
   own formed mesh, because the casting tapers from a 1.65 x 2.2 m pad to a
   0.92 m shoe and a box would have stood 0.37 m proud of it at shin height;
   each collar carries a cylinder at its 1.02 m lip over its 0.42 m ring depth,
   solid because the builder's own recessed throat disc closes the bore.
   All four bogies and all four collars are built, not only the eight pieces the
   sweep could reach: the hardware is drawn identically on every corner and nacelle,
   and a craft solid on one leg and porous on its mirror is a worse answer than
   either. Every collider is derived from the live renderer it matches — the
   legs by their shared lathe mesh, the soles from the batch's own authored
   instance transforms and formed mesh, the collars from their named nodes — so
   restyling the gear cannot separate the drawn part from the solid one. Root
   shapes 47 -> 63. The soles stop on their own drawn underside at local
   y = -1.23, which is 0.02 m above the declared -1.25 landing contact plane, so
   the landing envelope's floor, width and roof are all unchanged and the
   berth's structural-penetration audit still sees the deployed cargo ramp and
   pilot stair as the only apron-bearing contacts; only z-max moves,
   12.25 -> 13.26, the drawn collar lip.

   One witness walk moved, for the same reason the Aft gate's Cinder tour did.
   `tests/station_traversal_defect_witness_test.gd`'s PORT-DECK-001 rail walk
   stood at x = -36.0, which is 7 cm *behind* the Arrow's drawn nozzle mouth at
   x = -36.07, and both its legs crossed the berth laterally straight under an
   engine bell — a crossing that could only ever have worked while those bells
   were porous. Measured live with the production capsule, the clear lateral
   lane behind the solid tail is **1.36 m** wide centred on x = -35.30, so the
   walk now stands there: still inside the removed rail's x = -42.5 … -11.5
   span, still crossing both old rail lines, and now finishing both legs with
   7.37 m of travel and zero stuck frames instead of 0.15 m. The Jovian's own
   published `flight_collision_bounds` aft face also moved, from z = 12.30 to
   z = 13.31, because it had been sized to `AftHullCollision` rather than to the
   craft — `parked_render_bounds` has always reached z = 14.45 — and it keeps
   the same 0.05 m margin over the real aft-most collider it always had.

   *Player effect:* you walk around a parked ship's engines and landing legs
   instead of through them, on both aprons. Nothing about how either craft
   flies, lands or is boarded changed: both ships' own suites,
   `station_surface_playability_test` (roster refrozen to 138 shapes),
   `outbound_route_clearance_test`,
   `hero_fleet_airless_landing_wash_production_test`,
   `jovian_sandbox_integration_test`, `arrow_sandbox_integration_test`,
   `controller_sortie_lifecycle_test`, `jovian_freighter_berth_fit_test`,
   `boarding_accessibility_test` and `fleet_role_differentiation_test` all pass
   unchanged. `scripts/ships/arrow_recon_ship.gd`,
   `scripts/ships/jovian_light_freighter.gd`, asserted in
   `tests/arrow_recon_ship_test.gd` and `tests/jovian_light_freighter_test.gd`
   (`_test_exterior_ground_support_collision` re-measures all sixteen pieces
   against their renderers).

### Accepted as intentional

- **Hero berth `LandingPad/StarboardUtilityBay` (6 pieces: three umbilical
  housings, the service cabinet, the control pedestal stem and head).**
  `LandingPad`'s entire dressing roster is contractually presentation-only and
  collision-free (`get_central_berth_audit_report()["presentation_collision_free"]`),
  because a tow tractor crosses the pad at 11.5 m/s and the Torrent's launch
  sweep stages hull shapes across it. The module already documents the sanctioned
  way to add solid ground-support equipment: build it in
  `_build_central_berth_service_line()`, a *sibling* of `LandingPad`, where every
  piece that reads as solid is collidable. Moving the utility bay there is the
  right fix and is a berth restructure, not a collision flag.
- **Aft Operations `VisualPressureEnvelope` side cladding.** Declared
  `visual_detail_only` with "the underlying roof remains the sole collider". The
  flagged panel is 0.12 m of cladding proud of the room's wall collider at the
  deck edge.
- **Habitat soft goods:** four `BunkAlcove*/BerthLife/CurtainLeadEdge` privacy
  curtains and `CrewBerthRoster/RosterHungCoverall`. Cloth; walking through a
  hung curtain is correct.
- **Habitat `GardenService/NutrientPanel`:** a 0.10 m flush wall panel.
- **Animated activity props:** the three cargo-line `AnimatedCargoSled`
  containers/ribs and `AftCrewWorkPost/AnimatedToolCarousel/CarouselTool3`. These
  slide along their lines every frame; a moving collider would shove or trap the
  player.

### Deferred

Nothing. The parked-craft undersides were the last deferred family and are fixed
above; the nineteen findings that remain are all accepted as intentional.

## Rendered triage evidence

`/root/.cache/mudds-shipyards/walkability-root/` — Xvfb, `--display-driver x11`,
gl_compatibility, 1280x720, production lighting and quality untouched:
`observation-logistics-pad-masts.png`, `observation-pad-cross-landing-mast.png`,
`vip-reception-armchairs.png`, `observation-landing-viewer.png`,
`registry-freight-deck-seam.png`, `aft-upper-transfer-gate.png`.

`/root/.cache/mudds-shipyards/craft-underside-root/` — same settings, for the
parked-craft undersides: `before/` and `after/` each hold
`arrow-port-engine-tail.png`, `arrow-starboard-refractory-nozzle.png`,
`jovian-port-landing-bogie.png`, `jovian-port-landing-sole.png` and
`jovian-lower-exhaust-collar.png`. Each pair is one apron walk. The probe casts
the production player's own capsule (0.38 r / 1.94 h, mask 7) along the
approach the sweep flagged, stands the player where that capsule actually
stops, and photographs it from a camera fixed for both frames; the "before"
frame is the same scene with exactly the sixteen Jovian and four Arrow
colliders this pass added switched off, which is the pre-fix collision state.
Nothing was remodelled, so the drawn geometry is identical in both frames and
only the walker moves. Measured travel along each approach, before -> after:
Arrow port engine tail 3.250 -> 2.062 m, Arrow starboard nozzle 3.250 ->
2.062 m, Jovian port landing bogie and sole 4.500 -> 2.219 m, Jovian lower
exhaust collar 4.344 -> 3.344 m. In both "before" Arrow frames and the
"before" Jovian collar frame the walker's helmet is plainly inside the engine
bell; in the "after" frames they stand outside it, and at the bogie the
walker's boots stop on the sole casting's own edge.

`/root/.cache/mudds-shipyards/aft-gate-root/` — same settings, for the Aft
transfer-gate fix: `before/gate-approach.png` and `after/gate-approach.png` from
the stair head, and `before/work-post-aisle.png` and `after/work-post-aisle.png`
looking south down the work-post aisle at the rib rows. Identical cameras on both
sides; the ribs are drawn exactly as before and stand further outboard, and the
1.05 m aisle between the bench and the cable drum is open in both.
