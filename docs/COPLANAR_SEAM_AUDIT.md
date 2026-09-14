# Coplanar seam / z-fighting audit

Phase 10 §1 and §3 ask for visible seams, z-fighting and flashing materials to be
removed. A fight is a relationship between two *different* renderers, so no
per-module test could see one. `tools/coplanar_seam_audit.gd` is the probe that
can.

```
godot --headless --audio-driver Dummy --path . --script tools/coplanar_seam_audit.gd
```

It boots `scenes/main.tscn` the way `tests/geometry_census_scenario_test.gd`
does, walks every visible opaque `MeshInstance3D` and `MultiMeshInstance3D` copy
(decoding `MultiMesh.buffer` or `authored_instance_transforms`, because the
headless server answers identity for `get_instance_transform()`), reduces each
mesh to vertex-connected planar faces, and reports pairs of faces from different
renderers that are parallel within 0.5°, offset by at most 3 mm, and overlapping
by at least 0.01 m² of real polygon area. It exits 0, prints a per-module
summary, and writes everything to `user://coplanar_seam_audit.json`. About 20 s
on the resident station.

Findings are grouped into **families** (one authored mistake in a batch builder
otherwise appears once per copy) and scored `overlap_area / distance²`, where the
distance is to the nearest authored `walkable_surface` — so triage starts with
what a player actually sees.

## What the probe refuses to call a defect

Four coincidences are legitimate and are excluded rather than reported, each
because it cannot flicker:

| class | rule |
| --- | --- |
| back-to-back | the two faces point into each other — two solids in contact. Backface culling removes one before the depth test. |
| interior | one face lies inside the other renderer's own volume, and only when that renderer is box-like enough for its AABB to be a truthful volume (a merged room batch's AABB is the room, and would bury every real defect in it). |
| occluded | both faces are themselves already in back-to-back contact across the whole overlap: two props standing on one deck, each pressed flat against it. |
| declared | `coplanar_by_design` metadata on either renderer (or an ancestor) **and** the same material on both faces. Honoured only where the material really is identical. |

`SHADOWS_ONLY` proxies (the `StaticShadowBatch` envelopes) never reach the colour
pass and are skipped entirely. Reported normals are facing directions: Godot
winds front faces clockwise, so the geometric normal is negated on the way out.

## Where the scene stands after this pass

1,411 pairs reported / 419 families, against 1,350 back-to-back, 330 buried and
28 declared exclusions, over 5,874 renderer placements and 162,073 planar faces.
The first run, before the fixes below, reported 1,527 pairs / 435 families.

| module | pairs | overlap m² | | module | pairs | overlap m² |
| --- | ---: | ---: | --- | --- | ---: | ---: |
| HabitatSpine | 301 | 45.06 | | TorrentInterceptor | 19 | 5.19 |
| AftJunctionStack | 248 | 47.70 | | LandingPad | 14 | 2.23 |
| HalyardCrewTransport | 184 | 15.82 | | ExteriorTargetRange | 14 | 0.48 |
| JovianLightFreighter | 183 | 35.04 | | ObservationLogisticsSpur | 13 | 0.28 |
| JovianFreightBerth | 125 | 59.17 | | FleetDockComb | 12 | 12.30 |
| FleetExpansionProductionBinding | 78 | 35.04 | | ModernFleetRegistry | 11 | 0.63 |
| IndustrialInfrastructure | 72 | 4.93 | | BulwarkHeavyGunship | 10 | 1.98 |
| ExposedDockLattice | 47 | 49.29 | | OperationalLattice | 7 | 0.37 |
| VipReceptionSuite | 29 | 2.05 | | FabricationAnnex | 4 | 0.12 |
| ArrowReconShip | 28 | 1.92 | | SalvageTerrace | 2 | 0.04 |

The five modules owned by this pass went from 509 pairs / 97.06 m² of fighting
overlap to 349 pairs / 47.56 m², and their worst family score dropped from 0.165
to 0.0038.

## Rendered confirmation

Silent isolated Xvfb / x11 / D3D12 GL-compatibility captures at 1280×720, camera
aimed at each seam's **overlap centre** (not the faces' own centres — a 90 m²
deck's centre can be metres from the 0.4 m patch it shares). Each site is
rendered twice with the camera moved 2 cm sideways: z-fighting changes *which*
surface wins, parallax only moves edges. `flip%` is the share of the seam crop
whose winning surface changed.

Captures: `/root/.cache/mudds-shipyards/seam-audit-root/{before,after}/`.

| site | before flip% | after flip% | verdict |
| --- | ---: | ---: | --- |
| salvage lower pad × support cap | 0.98 | 0.00 | fixed |
| salvage top pad × support cap | 3.41 | 0.00 | fixed |
| annex entry sign × jamb | 0.01 | 0.00 | fixed |
| annex gantry cap × column | 1.49 | 1.50 | not a fight — the flip is distant machinery past a foreground column, identical before and after; the seam itself is gone from the audit |
| bunk mouth head × jamb | 14.12 | 0.00 | fixed — the worst confirmed defect found |
| VIP clerestory sill × port wall | 0.95 | 0.34 | fixed on both shared planes; residue is neighbouring glazing detail |
| VIP threshold floor × wall | 0.01 | 0.01 | seam gone from the audit; never resolved as a visible flip at this range |
| VIP front plate × front wall | 0.00 | 0.00 | seam gone from the audit; faces the approach side, not framed |
| spur case × pallet | 0.00 | 0.00 | seam gone from the audit; 20 mm band too small to flip a pixel |
| comb dock slab × Halyard gear foot | 0.00 | 0.00 | deferred, see below |

The bunk mouth head is the one that shows what this class looks like:
`before/05_habitat_mouth_head_a.png` is banded with horizontal stripes of
alternating `shell_light` and `shell_mid` across the alcove surround, and
`after/05_habitat_mouth_head_a.png` is a clean surface. The salvage top pad
(`02_salvage_top_pad_a.png`) shows the column cap as a dark rippled square in the
middle of a walked deck, and nothing at all afterwards.

## Fixed

All eight are transforms. No new material, light or geometry; the geometry census
is identical before and after.

| seam | module | change |
| --- | --- | --- |
| terrace column caps on the lower salvage pad (×4) and top inspection pad (×2) | `salvage_terrace.gd` | `_support_center` places every column from the deck it carries, seating its cap on that deck's underside |
| entry sign plate on the portal jamb | `fabrication_annex.gd` | plate stands `COPLANAR_STANDOFF` (5 mm) proud, as a mounted plate would |
| fabricator gantry end caps on the column faces (×8) | `fabrication_annex.gd` | columns stand 5 mm further apart, burying each beam cap |
| bunk mouth head lapping both jambs (×12 families) | `habitat_spine.gd` | head carries a 5 mm `BUNK_MOUTH_HEAD_STANDOFF` reveal on the lane side |
| clerestory sill set into the port wall (two shared planes) | `vip_reception_suite.gd` | sill moves 5 mm proud in x and 5 mm down, into a shadow reveal |
| threshold floor edge on the threshold wall faces (×2) | `vip_reception_suite.gd` | threshold walls stand 5 mm further out — the walls move, not the walkable plate |
| front floor plate edge on the front wall faces | `vip_reception_suite.gd` | both front walls move 5 mm forward together, so the facade stays one plane |
| lower cargo case sunk 20 mm into its pallet (×3 stacks) | `observation_logistics_spur.gd` | case seats on the pallet's top face |

Each touched suite gained a focused assertion on the new standoff.

## Declared

`VipReceptionSuite`'s `Reception` and `Threshold` shells are built as
overlapping boxes so corners are solid rather than mitred, which laps each wall's
outer face over its neighbour's on one plane. Both sides are the one `pearl`
finish at the one orientation, so whichever box wins a pixel it shades
identically. Both nodes now carry `coplanar_by_design` =
`SHELL_LAP_DECLARATION`; 28 pairs are excluded on that basis, and only because
the audit independently confirms the material is the same.

## Deferred

Owned by this pass, left as-is:

- `habitat_spine.gd` — `ObservationCommon/DeferredFacadeHeader` laps the facade
  behind it (3.68 m² at 22 m) and the corridor/common front panels meet on one
  plane (0.45 m² ×2). Both are same-finish laps; they want the same
  `coplanar_by_design` treatment as the VIP shell rather than a standoff.
- `habitat_spine.gd` — `SideBranchGarden` link floor and garden floor share the
  underside plane at y = −0.5 (0.83 m², 25 m, both faces looking down).
- `habitat_spine.gd` — the bunk mouth head's residual end-cap lap with its jamb,
  0.083 m² (was 0.832 m²).
- `fabrication_annex.gd` — roof column bases and the hazard curb share the deck
  plane (0.093 m² ×2).
- `salvage_terrace.gd` — the inspection ramp's lip and the top inspection pad
  share a walkable handoff plane (0.039 m² ×2). This is a ramp meeting a deck and
  wants a handoff declaration, not a step.

Not owned by this pass — these belong to the named files and should be picked up
by whoever owns them:

| seam | owner |
| --- | --- |
| Zenith `PortWingOuterSkin` × `PortBlendedDeltaWing` (0.27 m² at 0.7 m — the highest-scoring finding in the whole scene) | `scripts/ships/zenith_interceptor.gd` |
| Bulwark cockpit floor × both side consoles (0.50 m² at 1.9 m, ×2) | `scripts/ships/bulwark_heavy_gunship.gd` |
| bomber and cargo berth legs × boarding legs (3.20 m², ×4 each) | `scripts/world/fleet_expansion_berths.gd` |
| dock lattice connector deck × cargo container batch (30.76 m²) | `scripts/world/shipyard_world.gd`, `scripts/world/ship_berth.gd` |
| Cinder cargo pod × loadmaster cabin end wall (7.51 m²) | `scripts/ships/cinder_cargo_hauler.gd` |
| dock slab / slab inset × Halyard landing gear feet | `scripts/world/fleet_dock_comb.gd`, `scripts/ships/halyard_crew_transport.gd` |
| AftJunctionStack (248 pairs, 47.70 m²) and JovianFreightBerth (125 pairs, 59.17 m²) | `scripts/world/aft_junction_stack.gd`, `scripts/world/jovian_freight_berth.gd` |

## Known unrelated failure

`tests/geometry_census_scenario_test.gd` fails on the current baseline with a
triangle-only drift (resident 1,951,735 vs the frozen 1,951,853; loaded 2,085,869
vs 2,085,987). It reproduces on an unmodified `scripts/world/` tree, and the
per-bucket census is byte-identical before and after this pass, so it is not
caused by these fixes and has not been refrozen here.
