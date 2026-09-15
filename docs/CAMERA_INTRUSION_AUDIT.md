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

Verification for this pass: the camera audit and `tools/station_walkability_sweep.gd`
before and after, every berth's published lane re-swept with its own craft's real
collision shapes plus each craft's parked pose, and the module suites,
`outbound_route_clearance_test`, `landing_clearance_test`,
`cinder_cargo_hauler_test`, `fleet_expansion_shipyard_integration_test`,
`station_traversal_defect_witness_test` and the walkable-area census.

## Ultrawide

`display/window/stretch/aspect` ships as `keep`, which pillarboxes a 32:9
display back to a 16:9 render, so 16:9 is the shipping case and the audit
reports 32:9 separately rather than acting on it. Under `KEEP_HEIGHT` the
authored 72° vertical FOV becomes 137.7° horizontal at 32:9, which widens the
near plane from ±0.194 m to ±0.388 m. That produces **6 additional findings**
that do not exist at 16:9, all shallow grazes on the range drones and one
approach frame. No FOV policy change is proposed here; this is recorded so that
any future move to `expand` is taken knowing it widens the near plane by 2×.

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
