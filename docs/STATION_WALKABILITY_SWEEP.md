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

After the fixes below: **37 findings** — 0 / 37 / 0 / 0. Both `gap` findings are
closed and every fixed `walk_through` family is gone.

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

- **Aft Junction Stack — six upper transfer gate ribs (2.35 m) have no
  collision.** Confirmed real: the module declares
  `collision_solution: deck_supported_visual_ribs_outside_lane`, but the sweep
  measured that the upper deck is walkable *at* the rib rows and not only
  between them, so a player off the centre lane walks through a gate post. The
  collision change itself is small and passes the Aft suite, but it exposes a
  layout problem it cannot fix: measured live at y = 4.2, the deck north of the
  gate is two aisles of about 1.0 m and 1.1 m either side of
  `OperationalLattice/Activities/AftCrewWorkPost`, and the production traversal
  witness's Cinder tour crosses the rib row three times because those ribs were
  porous. The complete remedy is to make the ribs solid *and* move the crew work
  post so the gate's 3.66 m lane continues north — Aft layout work owned by
  another agent this session. Measurements for that work: free capsule-centre
  spans at y = 4.2 are `z 62.0–63.5: [-6.5..-3.7] [-2.7..-0.2]`,
  `z 64.0–66.0: [-8.5..-5.8] [-3.9..-0.2]`, opening out at `z ≥ 66.5`.
- **Parked craft undersides (12 findings):** Jovian landing bogie strut, damper,
  foot batch and lower engine collars; Arrow engine collar and refractory
  nozzles. `scripts/ships/*`, owned elsewhere this pass.

## Rendered triage evidence

`/root/.cache/mudds-shipyards/walkability-root/` — Xvfb, `--display-driver x11`,
gl_compatibility, 1280x720, production lighting and quality untouched:
`observation-logistics-pad-masts.png`, `observation-pad-cross-landing-mast.png`,
`vip-reception-armchairs.png`, `observation-landing-viewer.png`,
`registry-freight-deck-seam.png`, `aft-upper-transfer-gate.png`.
