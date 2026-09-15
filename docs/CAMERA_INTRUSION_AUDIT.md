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
2.9 M near-plane point tests, 13.1 s. Lanes are `berth_rest`, `assist_descent`,
`launch_climb`, `outbound_route` and `inbound_route`, each sampled across the
three zoom stops, seven reachable boom offsets (rotation lag and velocity bank)
and the hull attitudes the berth's own `assist_maximum_tilt_degrees` permits.
The simulated spring-arm sweep agrees with the live rig to 0.000 m at every
berth.

## Findings

48 grouped findings. No `camera_sphere_in_world_collision` and no
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

### Deferred — station geometry, not ours to move

Every one of these is a visible renderer with **no collision at all**, which is
why the chase arm cannot retract for it. Naming the owner, worst depth, and the
lanes where a craft reaches it:

| Node | Depth | Lanes | Owner |
| --- | --- | --- | --- |
| `FleetExpansionBerths/dock_06_interceptor/ServicePresentation/LaunchFramePort` | 0.737 m | assist, launch | `scripts/world/fleet_expansion_berths.gd` |
| `FleetExpansionBerths/dock_04_cargo/ServicePresentation/CargoContainerBatch` | 0.615 m | assist, launch | `scripts/world/fleet_expansion_berths.gd` |
| `FleetExpansionBerths/dock_06_interceptor/ServicePresentation/LaunchRailBatch` | 0.435 m | assist, launch | `scripts/world/fleet_expansion_berths.gd` |
| `FleetExpansionBerths/dock_06_interceptor/ServicePresentation/LaunchFrameHeader` | 0.344 m | assist, launch | `scripts/world/fleet_expansion_berths.gd` |
| `FleetDockComb/GeneratedComb/SurfaceDetail/DockArmService/ServiceMastBatch` | 0.161 m | assist, launch | `scripts/world/fleet_dock_comb.gd` |
| `FleetDockComb/GeneratedComb/SurfaceDetail/DockArmService/DockServiceBrackets` | 0.158 m | assist, launch | `scripts/world/fleet_dock_comb.gd` |
| `ExposedDockLattice/@MeshInstance3D@752` | 0.115 m | assist, launch | `scripts/world/shipyard_world.gd` |
| `OpenLaunchSpine/SignalGantry` | 0.019 m | outbound | `scripts/world/shipyard_world.gd` |

The general fix is station-side: either give the intruded dressing collision so
the existing sweep retracts for it, or clear the published assist lane of it.

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
ten findings at their recorded hull poses through each craft's own production
camera and renders a three-frame sweep: centred boom, the audit's boom offset,
and one frame of hull yaw so the moving clip plane makes the intrusion legible.
Rendered under Xvfb on D3D12 (RTX 5070 Ti) to
`/root/.cache/mudds-shipyards/camera-audit-root/`. The reproduced camera lands
within 0.00–0.45 m of the audited position on all ten, and the Jovian fix is
captured as a frozen before/after pair at the two candidate roofs.
