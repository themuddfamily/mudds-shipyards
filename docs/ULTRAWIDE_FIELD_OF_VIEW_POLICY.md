# Ultrawide field-of-view policy

`ROADMAP.md` Phase 9 asks for production-grade settings coverage including
ultrawide testing, and Phase 10 §3 asks for a review of the complete game at
21:9 and 32:9. This is the camera half of that: what the authored `camera_fov`
setting means on a display wider than 21:9, and the player setting that governs
it.

## The problem

Every camera the `camera_fov` setting drives is a `Camera3D` on
`Camera3D.KEEP_HEIGHT`:

| Rig | Node | Owner |
| --- | --- | --- |
| chase | `HeroShip/.../ShipCamera` | `scripts/ships/hero_ship.gd` |
| cockpit | `HeroShip/.../CockpitCamera` | `scripts/ships/hero_ship.gd` |
| on foot | `Player/.../PlayerCamera` | `scripts/player/player_controller.gd` |

`KEEP_HEIGHT` means the authored angle is the *vertical* one and the horizontal
angle widens with the display. That was invisible while the project pinned
`display/window/stretch/aspect` to `keep`, because every panel was pillarboxed
back to 16:9. Since `45561f79b` (`StartupLoader.stretch_aspect_for_display`)
real displays expand to the window aspect, so the widening reaches the player:

| Display | Aspect | Horizontal FOV at the authored 72° |
| --- | --- | --- |
| 1024 × 768 | 1.333 | 88.18° |
| 1920 × 1080 | 1.778 | 104.50° |
| 3440 × 1440 | 2.389 | 120.10° |
| 5120 × 1440 | 3.556 | **137.68°** |

137.68° is past the point where the near plane's own widened corners start
intersecting geometry the 16:9 corners clear.
`tools/camera_intrusion_audit.gd` measured six grouped near-plane intrusions
that exist only in its 32:9 band (see [Evidence](#evidence)).

## The policy

Hor+ up to 21:9, then a soft cap. Implemented once, in
`scripts/settings/ultrawide_fov_policy.gd`:

* **at or below the 21:9 reference aspect** (`REFERENCE_ASPECT`, 3440 / 1440 =
  2.3889) the authored vertical angle is used **exactly**. The function returns
  the authored value by an early return rather than through the trigonometry, so
  16:9 and 21:9 are bit-identical to the behaviour before this policy existed;
* **above it** the vertical angle is reduced just enough that the horizontal
  angle stays on the ceiling that *same authored angle* reaches at 21:9:

  ```
  effective_vertical = 2 · atan( tan(authored_vertical / 2) · 2.3889 / aspect )
  ```

At the shipping 72° default the ceiling is **120.10°** — "the 120° ceiling". A
5120 × 1440 panel therefore runs 52.04° vertical instead of 72°, and covers
120.10° horizontal instead of 137.68°.

### Why the ceiling scales with the authored angle

A flat 120° ceiling would resolve every slider position between 55° and 110° to
the same 51.93° vertical angle on a 32:9 panel, silently turning the shipping
"Camera field of view" slider into a no-op for exactly the players this policy
is for. Tying the ceiling to the authored angle keeps the slider meaningful:
110° authored still reads 87.63° vertical at 32:9 against 72°'s 52.04°.

### The 21:9 boundary

The cap engages strictly above 2.3889, so a 3440 × 1440 panel keeps 72.00° and
120.10° unchanged. An aspect a hair wider than 21:9 drops to 71.9°-ish — a
sub-perceptual step that exists because 21:9 is defined as the last unclamped
display rather than as a point on the curve.

## The setting

`limit_ultrawide_fov`, **default ON**, opt-out.

* `RuntimeSettings.limit_ultrawide_fov` (`scripts/settings/runtime_settings.gd`),
  persisted in the `[camera]` section beside `fov`, and in the typed user-data
  payload at `USER_DATA_PAYLOAD_SCHEMA_VERSION` 10. A schema-9 or older payload
  migrates the missing key to the default, so an existing player's file loads
  with the cap on and nothing else changed.
* Settings page: "Limit ultrawide field of view", in the **FLIGHT + CAMERA**
  group directly under "Camera field of view", with the same help line and the
  same live value-reflecting tooltip the other described toggles carry
  (`_refresh_accessibility_tooltips`).
* `GameFlow.RUNTIME_SETTING_KEYS` carries the key, and
  `GameFlow._on_runtime_setting_changed` re-derives the FOV for `camera_fov` and
  `limit_ultrawide_fov` through the same branch — the authored angle and the
  opt-out are two halves of one resolved value.

With the cap off, `UltrawideFovPolicy.effective_vertical_fov` is the identity
function and the rigs behave exactly as they did before the policy existed.

## The seam

`HeroShip.set_camera_fov(field_of_view, limit_ultrawide := true)` and
`PlayerController.set_camera_fov(field_of_view, limit_ultrawide := true)` take
the **authored** angle, retain it, and resolve the live `Camera3D.fov` through
the policy. `get_authored_camera_fov()` returns what the player chose;
`get_camera_fov()` returns what the rig is running.

Both rigs also connect to their viewport's `size_changed` and re-derive there,
because a player dragging a window onto an ultrawide panel or switching to a
32:9 fullscreen mode never reopens the settings menu. A rig whose FOV has never
been assigned keeps its authored scene value, so a resize cannot flatten the
cockpit rig's wider authored angle before the settings owner has spoken.

The tow tractor's third-person rig (`scripts/vehicles/tow_tractor.gd`) is still
on the uncapped single-argument seam and is the one remaining follow-up.

## Evidence

### The FOV table

`tests/ultrawide_layout_test.gd` boots production `Main`, resizes the real
window to each supported display twice — cap on and cap off — reads `fov` back
off the live `Camera3D`s and prints `ULTRAWIDE_CAMERA_FOV`. Nothing re-pushes a
FOV between resolutions; the resize itself re-derives it.

| Display | Aspect | Cap on: vert / horiz | Cap off: vert / horiz |
| --- | --- | --- | --- |
| 1024 × 768 | 1.333 | 72.00° / 88.18° | 72.00° / 88.18° |
| 1920 × 1080 | 1.778 | 72.00° / 104.50° | 72.00° / 104.50° |
| 2560 × 1440 | 1.778 | 72.00° / 104.50° | 72.00° / 104.50° |
| 3440 × 1440 | 2.389 | 72.00° / 120.10° | 72.00° / 120.10° |
| 5120 × 1440 | 3.556 | **52.04° / 120.10°** | 72.00° / 137.68° |

The 16:9 and 21:9 rows are asserted with `==`, not `is_equal_approx`.
`tests/flight_input_test.gd` pins the same table on a live Torrent outside
`Main`, and `tests/first_person_view_test.gd` pins it on the on-foot rig.

### Camera intrusion audit

`tools/camera_intrusion_audit.gd` reads the live chase FOV at boot and probes
the near plane in a 16:9 band and a 32:9 band. Run at a 5120 × 1440 content
scale, with the toggle as the only difference:

| Run | Live chase FOV | Grouped findings | 32:9-only findings |
| --- | --- | --- | --- |
| cap **off** | 72.00° | 30 | **6** |
| cap **on** | 52.04° | 23 | **0** |

The six that disappear are all `near_plane_in_world_mesh` on the chase rig along
`outbound_route`, against the exterior target range's `TargetDrone01`:
`DressingRenderBatch01` for the Torrent, Bulwark, Cinder bomber, Cinder
interceptor and Cinder hauler, and `ApproachFrame/ApproachFrameSouthWest` for
the Bulwark. Every finding that exists at 16:9 is untouched — the difference is
exactly the aspect-only set. (Grouped totals vary by ±1 between audit runs
because the range drones patrol; the target set does not.)

### Rendered captures

5120 × 1440 under Xvfb through the production boot path (window 5120 × 1440,
viewport 3200 × 900, aspect 3.556), cap on and cap off, in
`/root/.cache/mudds-shipyards/fov-root/`:

| File | Shows |
| --- | --- |
| `chase_5120x1440_cap-off.png` | 72° / 137.68°: the launch deck collapses to a narrow wedge in the centre and the flanks smear into extreme perspective distortion |
| `chase_5120x1440_cap-on.png` | 52.04° / 120.10°: the same framing at a readable scale, craft and gantry legible |
| `cockpit_5120x1440_cap-off.png` | canopy arch flattened, deck and signal gantry pushed to a distant strip |
| `cockpit_5120x1440_cap-on.png` | canopy arch and instrument hood at true cockpit scale with the gantry readable |
