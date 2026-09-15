# Camera intrusion audit — ship perspective

Phase 10 §1 asks for world geometry to be audited "from the embodied player and
ship perspectives". The walking half is `tools/station_walkability_sweep.gd` and
`tools/coplanar_seam_audit.gd`. This is the flying half.

`tools/camera_intrusion_audit.gd` boots production `Main` and, for all nine
flyable craft, samples the real chase rig, the cockpit camera and the on-foot
camera at the cabin exit across every lane the station publishes. Run it with:

```
godot --headless --audio-driver Dummy --path . --script tools/camera_intrusion_audit.gd
```

It exits 0, prints a per-craft summary, and writes the grouped list to
`user://camera_intrusion_audit.json`.

## What it measures

| Class | Meaning |
| --- | --- |
| `camera_sphere_in_own_hull` | the `SpringArm3D` sweep sphere (`chase_camera_collision_radius`) overlaps the craft's own hull envelope, which the arm excludes by RID and so cannot retract for |
| `camera_sphere_in_world_collision` | the same sphere overlaps solid geometry on `CAMERA_OBSTRUCTION_QUERY_MASK` |
| `near_plane_in_world_mesh` | a near-plane corner is inside a visible opaque station renderer |
| `near_plane_in_own_hull_mesh` | a near-plane corner is inside a visible opaque renderer the craft itself draws |
| `spring_arm_collapse_at_rest` | the resolved rest arm is too short to read the craft |

Collision is not the authority for the near-plane classes: most station dressing
and most hull plating carry none, so the probe walks real triangles and runs a
three-ray parity test in each renderer's own space. Camera `cull_mask` is
honoured — the Zenith and Torrent hide their exterior canopy shells from the
cockpit rig, and those are not intrusions. A containment self-check probes 412
world renderers at their own bounding-box centres first (91.3 % contained), so
an empty result is a clean scene rather than a dead detector.

Coverage of the last run: 9 craft, 5,963 renderers, 154,497 chase samples,
2.9 M near-plane point tests, 11.3 s. Lanes are `berth_rest`, `assist_descent`,
`launch_climb`, `outbound_route` and `inbound_route`, each sampled across the
three zoom stops, seven reachable boom offsets (rotation lag and velocity bank)
and the hull attitudes the berth's own `assist_maximum_tilt_degrees` permits.
The simulated spring-arm sweep agrees with the live rig to 0.000 m at every
berth.

## Findings

29–30 grouped findings, down from 48 before the station-geometry pass below,
and across 8 targets instead of 16. The number varies by one group between runs
because the range drones patrol a closed-form orbit, so the shallow grazes on
them are sampled at slightly different positions; the *target* set does not
vary. No `camera_sphere_in_world_collision` and no
`spring_arm_collapse_at_rest` anywhere: the arm keeps its sweep sphere clear of
every solid body, and every craft resolves its full requested rest arm at its
berth (15.34–22.00 m against readability floors of 4.50–11.00 m). The cockpit rig and the cabin-exit rig are clean on all
nine craft.

### Fixed

**Jovian chase near plane inside its own `CargoRoofShell`** — `assist_descent`
and `launch_climb`, 0.107 m deep. `HeroShip`'s boundary mount was lifting the
camera to the top of `get_landing_collision_report().local_bounds`. That
envelope is a landing contract and is allowed to stop below the craft: measured
on the live fleet it stops 0.31 m under the Jovian's cargo roof and dorsal ribs,
0.94 m under the Bulwark's canopy nose frame, 1.84 m under the Arrow's cockpit,
and 1.99–2.59 m under the three Cinder canopies. Lifting to that roof parks the
near plane inside plating that is still drawn.

Fix: `HeroShip.get_chase_camera_self_hull_envelope()` merges the visible opaque
hull renderers into the envelope the correction lifts against, cached and
rebuilt whenever the live collision envelope changes. Transparent, additive and
shadow-only renderers stay out, so the Arrow's planetary-entry overlay and every
canopy glazing cannot raise the roof by metres the camera sees through. Torrent,
Zenith and Halyard measure a 0.000 m lift and are bit-identical to before.
Regression: `tests/flight_input_test.gd`
`_test_chase_camera_self_hull_envelope_covers_drawn_hull`.

Known gap: the envelope is measured with the canopy closed. An open canopy
frame swings above it, which only happens while parked with the camera 15 m
away.

### Accepted

**`camera_sphere_in_own_hull`, 6 groups, Jovian 0.621 m / Halyard 0.571 m.**
Reached only with the arm collapsed against a berth or the range gate. The
sweep sphere is an obstruction-query volume, not a render volume; with the near
plane held clear of the merged envelope above, a sphere overlap puts nothing on
screen. Lifting for the full radius would be a framing change, not a fix.

**Exterior range target drones, 5 groups, up to 0.793 m.** `TargetDrone01`,
`03` and `04` sit on the outbound route. They are `StaticBody3D` on layer 32
(`TARGET`) with mask 0 — deliberately non-solid gunnery targets that the *hull*
flies through as well, so the camera doing the same is consistent, not a defect.
If they are ever made solid, `PhysicsLayers.CAMERA_OBSTRUCTION_QUERY_MASK` has
to gain `TARGET` at the same time or the camera will pass through bodies the
craft cannot.

### Fixed — station geometry (Phase 10 §1 follow-up)

All eight of these were visible renderers with **no collision at all**, which is
why the chase arm could not retract for them: `SpringArm3D` resolves the boom
with a shape sweep on `PhysicsLayers.CAMERA_OBSTRUCTION_QUERY_MASK`, and a
renderer without a body is invisible to that sweep. They are gone from the audit
and the grouped total falls from 48 to 29.

Two of them were worse than a camera defect. Dock 06's `LaunchFramePort` and
`LaunchFrameHeader` stood *inside Dock 04's own published approach lane* — the
hauler's landing envelope crosses world x = 30 at y = 12.98…16.18 and the post
reached y = 14.20, so the craft flew through a drawn 10 m post on every
approach, and only the post's total absence of collision kept the landing assist
from stalling on it. Dock 04's three 7 m containers stood inside the
`VipReceptionSuite` reception and threshold, inside `AftJunctionStack`'s
operations room and upper deck, through the fleet-dock comb connector deck and
its rails, and on top of the comb's own trunk walking plate; two of the three
were entirely buried inside other modules' interiors.

| Node | Depth | Lanes | Disposition |
| --- | --- | --- | --- |
| `.../dock_06_interceptor/ServicePresentation/LaunchFramePort` | 0.737 m | assist, launch | moved to pad-local x = -11 (from -16) and thinned to 1.2 m through the approach axis, then given collision |
| `.../dock_04_cargo/ServicePresentation/CargoContainerBatch` | 0.615 m | assist, launch | row moved to the 4 m strip between the comb trunk's edge and Dock 04's landing clearance, resized 7 × 3.6 × 7 → 3 × 3.6 × 4 to fit it, broken around `CargoTrunkLeg`, then given collision |
| `.../dock_06_interceptor/ServicePresentation/LaunchRailBatch` | 0.435 m | assist, launch | moved to pad-local x = ±11 (from ±16) and shortened 38 m → 22 m so it stops 1.5 m short of Dock 02's walking slab, then given collision |
| `.../dock_06_interceptor/ServicePresentation/LaunchFrameHeader` | 0.344 m | assist, launch | shortened 33.5 m → 23.5 m to span the moved posts, thinned to 1.2 m, then given collision |
| `FleetDockComb/.../DockArmService/ServiceMastBatch` | 0.161 m | assist, launch | riser bracket and pod given collision; both recorded camera poses are inside the bracket's own section |
| `FleetDockComb/.../DockArmService/DockServiceBrackets` | 0.158 m | assist, launch | same body |
| `ExposedDockLattice/@MeshInstance3D@752` | 0.115 m | assist, launch | named `MastCap03` (three siblings all called `MastCap` were being auto-renamed) and given collision |
| `OpenLaunchSpine/SignalGantry` | 0.019 m | outbound | given collision; it was the only member of its gantry without it, both `SignalMast` posts carrying it have always been `StaticBody3D` |

Where the fix is "given collision", nothing moved and the collider is the drawn
box. Where it is "moved", collision alone was not available: the piece stood in
a lane or on a walking surface, so a body there would have traded a camera
defect for a landing or walkability defect.

Two collision decisions are deliberately partial, and the measurement is the
reason:

* **The comb's dock-service mast has no collider.** All three docked craft
  publish a landing volume that starts just above the deck plane and runs the
  full hull length — the Halyard's is 28.35 m and reaches module-local x = 29.5 —
  so a collider on the 4.2 m mast at x = 21.9 stands inside the parked Halyard's
  own envelope. Measured: a mast collider blocked the Zenith, Halyard and Bulwark
  published lanes *and* the Halyard's parked pose. The bracket and pod hang below
  the deck line (crown at elevation − 0.13 against craft envelope floors at
  elevation + 0.03 and higher), block nothing, and are where both recorded camera
  poses (elevation − 0.14 and elevation − 0.31) actually are.
* **Dock 06's launch frame is 1.2 m through the approach axis instead of 1.5 m.**
  The frame line sits in a 1.79 m gap between the parked Zenith's envelope
  (world x ≤ 29.21) and Dock 02's walking slab (world x ≥ 31.00). At the authored
  1.5 m section a now-solid post would have left 0.04 m to the Zenith; at 1.2 m it
  leaves 0.19 m and 0.40 m.

Dock 04's and Dock 06's silhouette-width floors moved with the geometry, from
33.0 m to 32.0 m and 23.0 m. A pad is 28.0 m wide, so a 33.0 m floor could only
ever be met by dressing hanging 2.5 m or more past the pad on each side; what
that overhang reached is the list above. Dock 05 is unchanged: none of its
dressing was found in anybody else's volume.

That pass closed with an open question — *a human should look at how the two
pads read now* — and the answer, taken from three fixed viewpoints per pad under
Xvfb, was that they did not read at all. See the art-direction pass below.

### 2026-09-15 — Phase 10 §3 art direction: the two pads get their identity back

The shrunk dressing was clearance-correct and unreadable. Rendered from a walker
on the comb at 1.6 m eye height, from the chase camera on the published approach
at 40 m, and from the station long view:

* **Dock 04 showed no freight at all from either flying viewpoint.** The three
  3 × 3.6 × 4 m containers sit on the only free strip the pad owns, and that
  strip is screened by the VIP reception suite and the Aft junction mass from
  everywhere except the walkway itself. What was left was a lone crane goalpost
  cantilevered over an empty gap, its hoist a 3 m stub ending 8.5 m above
  nothing.
* **Dock 06 showed two cyan sticks and a dark doorway.** The shortened rails had
  no ground plane, no pad and nothing at either end — in the station long view
  the port rail reads as a bar floating in vacuum, detached from the station —
  and the launch frame reads as a portal into another module rather than a gantry.

Both identities are rebuilt inside the same contracts, from the same box
primitive and the same four per-pad materials. No material, texture or light is
added; the module still publishes exactly five guide lights.

| Pad | What it now shows |
| --- | --- |
| Dock 04 | Seven containers instead of three: two three-high stacks on the starboard strip either side of `CargoTrunkLeg`, each face carrying a lit ID stripe, on lit yard kerbs; a freight transfer bed on the port strip (two beams, four roller stands) with the seventh container landed on it under the crane; the crane jib shortened to reach that load and the hoist grown into a real 6.5 m lifting line; a manifest board on its own pylon; and a lit chevron gate on a threshold beam at the approach mouth. |
| Dock 06 | A two-panel blast fence raked 16° back behind the frame line, on four buttress ribs; an umbilical tower and arm standing the port side up; a full-length port lane kerb and a short starboard one at the lane mouth, both with corner markers; 14 rail lamps down the two rails; a readiness board; a lit header band across the frame; and the same chevron gate at the lane mouth. |

The fence is deliberately **two panels with a 7 m gate**, not one 20 m wall: the
comb's 4.8 m `Trunk` walkway runs the whole length of Dock 06 at pad-local
x [−2.4, 2.4] with its deck plane at pad-local y = 0, and a solid fence there
would have closed the spine. Measured against the live world, the panels clear
that walkway by 1.1 m on each side and their lowest corner sits 59 mm above its
deck. The launch threshold beam is 20 m rather than 24 m for the same reason in
miniature: at 24 m its underside was coplanar with both rail undersides and the
seam audit picked up two new findings, which are gone at 20 m.

**The same measurement decides how far outboard Dock 06 may dress at all, and
the witness suite caught the first draft getting it wrong.** This pad's
footprint overlays the comb's dock slabs from pad-local x = +9 outward:
`DockSlab01` (x [9, 21], z [−33, −18]) and `DockSlab02` (x [9, 21], z [−15, −3])
are walking surfaces whose deck plane is pad-local y = 0, and `DockSlab03Upper`
(x [9, 21], z [0, 12]) sits 1.8 m above it. A first draft put the fence panels
out to x = ±10.5 and ran a full-length 0.9 m starboard kerb from z = −6 to +20,
which stood *on* `DockSlab01` and `DockSlab02`. Nothing in the three audits
moved — the sweep reported the same 19 findings and the same 345 lanes — but
`station_traversal_defect_witness_test`'s Halyard circuit walked into the kerb
at world (42.0, 4.2, 54.1) and stalled there for 523 frames, 16.6 m into a
31.2 m leg. The panels now stop at x = ±8.3 and the starboard kerb only runs
z [13, 20], forward of every slab; the same walk completes its full 31.15 m with
zero stuck frames. That witness suite is the check that catches this class, not
the sweep: a wall across a route the sweep does not measure is invisible to it.

Every structural piece carries the collider it visually implies, and **every
collider now stands inside its own 28 × 42 m pad with 0.10 m to spare** — the
first time that has been true of this module's dressing. Only the crane mast
still cantilevers past the pad edge, and it carries no collider, exactly as
before. The silhouette floors rise rather than fall: Dock 04 holds at 32.0 m
(reaching 32.65 m) and Dock 06 goes 23.0 → 27.5 m (reaching 27.80 m).

Census, all measured rather than asserted:

| | before | after |
| --- | --- | --- |
| service renderer nodes | 11 | 15 |
| service drawn copies | 14 | 85 |
| service mesh resources | 11 | 12 |
| whole-module renderer nodes | 24 | 28 |
| whole-module mesh resources | 24 | 25 |
| structural colliders | 8 | 36 |
| module descendants | 70 | 104 |
| guide lights | 5 | 5 |
| materials | 11 | 11 |

Four new `MultiMeshInstance3D` batches (an apron kit and a marking batch per
pad) draw all 71 added copies, and all four share one 1 × 1 × 1 `BoxMesh` scaled
per instance — so 71 new pieces cost 4 draw submissions and 1 mesh allocation.

The three audits, run before and after against the live production world:

| Audit | before | after |
| --- | --- | --- |
| `tools/camera_intrusion_audit.gd` | 30 findings | 30 findings, byte-identical per craft, **zero referencing this module** |
| `tools/station_walkability_sweep.gd` | 82 surfaces, 135,137 cells, 19 findings (19 walk-through, 0 invisible, 0 choke, 0 gap), 345 lanes | identical findings, lanes and per-module rows; blocked cells 39,904 → 39,939 as the new dressing is solid |
| `tools/coplanar_seam_audit.gd` | 1,334 findings | 1,334 findings, zero new and zero removed seam pairs, identical worst-20 |

Rendered before/after pairs from the three fixed viewpoints per pad are in
`/root/.cache/mudds-shipyards/pads-root/{before,after}/`, rendered under Xvfb on
D3D12 (RTX 5070 Ti) with the same pad-local camera spec on both sides.

**Honest residual:** Dock 04's container yard still cannot be seen from the
chase camera or the station long view. It is screened by the VIP reception suite
and the Aft junction stack, and the strip it stands on is the only free ground
the pad has. The freight identity that reads from those two viewpoints is the
port apron — crane, transfer bed, landed container, manifest board — plus the
chevron gate; the stacks read from the walkway, which is where a player actually
meets them. Dock 06's starboard kerb and rail are likewise partly screened by
Dock 02's walking slab from the approach, so its lane reads asymmetric from the
chase.

Verification for this pass: the camera audit and `tools/station_walkability_sweep.gd`
before and after, every berth's published lane re-swept with its own craft's real
collision shapes plus each craft's parked pose, and the module suites,
`outbound_route_clearance_test`, `landing_clearance_test`,
`cinder_cargo_hauler_test`, `fleet_expansion_shipyard_integration_test`,
`station_traversal_defect_witness_test` and the walkable-area census.

## Ultrawide

`display/window/stretch/aspect` shipped as `keep`, which pillarboxed a 32:9
display back to a 16:9 render, so 16:9 was the shipping case and the audit
reports 32:9 separately rather than acting on it. Under `KEEP_HEIGHT` the
authored 72° vertical FOV becomes 137.7° horizontal at 32:9, which widens the
near plane from ±0.194 m to ±0.388 m. That produces **6 additional findings**
that do not exist at 16:9, all shallow grazes on the range drones and one
approach frame.

Both halves of that paragraph have since been acted on. `45561f79b` moved real
displays to `expand`, so 32:9 is now a shipping render rather than a
hypothetical, and `docs/ULTRAWIDE_FIELD_OF_VIEW_POLICY.md` added the
`limit_ultrawide_fov` setting (default ON) that holds the horizontal angle at
the 21:9 ceiling above 21:9. Re-run at a 5120 × 1440 content scale with that cap
on, the live chase FOV reads 52.04° and all six 32:9-only findings are gone
(23 grouped findings against 30 with the cap off); every finding that exists at
16:9 is unchanged. The audit itself still invents no policy — it reads whatever
FOV the live rigs are running.

## Rendered confirmation

`.godot/camera_intrusion_capture.gd` (scratch, not shipped) re-stages the worst
findings at their recorded hull poses through each craft's own production camera
and renders a three-frame sweep: centred boom, the audit's boom offset, and one
frame of hull yaw so the moving clip plane makes the intrusion legible. Rendered
under Xvfb on D3D12 (RTX 5070 Ti).

The first pass covered the worst ten findings, in
`/root/.cache/mudds-shipyards/camera-audit-root/`. The reproduced camera lands
within 0.00–0.45 m of the audited position on all ten, and the Jovian fix is
captured as a frozen before/after pair at the two candidate roofs.

The station-geometry pass re-ran the two worst station findings as a true
before/after pair — the same spec, the same recorded poses, once with
`scripts/world/fleet_expansion_berths.gd` at 6fbc4c7 and once with the fix — into
`/root/.cache/mudds-shipyards/camera-lanes-root/{before,after}/`. Both craft
reproduce the audited camera to 0.01 m and 0.45 m on the boom-lag frame.

The verdict is not subtle, because a camera *inside* a closed box sees its
back-faces culled and renders the box as a flat unlit slab across the frame.
On the hauler's yaw-sweep frame the pre-fix render is a hard-edged dark plane
covering the entire left half of the screen — the inside of `LaunchFramePort`
— and the post-fix render of the same pose is clean starfield. Changed pixels
per frame pair, at a threshold of 12/255:

| Frame | Changed |
| --- | --- |
| `f02` hauler / `LaunchFramePort`, centred | 0.63 % |
| `f02` hauler / `LaunchFramePort`, boom lag | 0.93 % |
| `f02` hauler / `LaunchFramePort`, yaw sweep | **34.37 %** |
| `f05` Zenith / `CargoContainerBatch`, centred | 22.44 % |
| `f05` Zenith / `CargoContainerBatch`, boom lag | 10.44 % |
| `f05` Zenith / `CargoContainerBatch`, yaw sweep | 17.31 % |

### 2026-09-15 correction — the signal gantry stays open

Giving `OpenLaunchSpine/SignalGantry` its drawn 27 × 0.8 × 0.8 m collider put
a solid 11.8 m underside across the illuminated launch lane (guide lights at
2.7, 6.2 and 9.7 m). The guided first sortie (`tests/vertical_slice_test.gd`)
flies the Torrent at y = 9 and stopped dead at z = −63.4 against it, so a player
launching high in the lane could never cross the gate. The crossbeam is
navigation dressing over a flight lane, not a pressure frame: it is back to no
collision layer and no shape, its 0.019 m outbound-lane camera graze is
**accepted** alongside the range drones, and `launch_signal_gantry_curve_test`
now asserts that no world collider crosses the lane box at the gate.
