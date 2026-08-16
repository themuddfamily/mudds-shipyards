# Transformed ShipCommand mapper

`TransformedShipCommandMapper` is the production-neutral bridge from one
accepted, detached `InputActionTransformSampler` frame into the existing
`ShipCommand` transport. The caller supplies the exact bank generation plus
command sequence, timestamp, and stream identity; the mapper owns none of them.

## Exact ship-facing roster

The mapper requires these 18 actions in the complete sampler frame:

- signed axes: `move_back`/`move_forward` → throttle,
  `move_left`/`move_right` → yaw, `pitch_down`/`pitch_up` → pitch, and
  `roll_left`/`roll_right` → roll;
- logical held intent: `sprint_boost`, `brake`, `hover`, and `fire`;
- physical just-pressed intent: `barrel_roll`, `landing_assist`, `interact`, and
  `toggle_ship_camera_view`;
- signed one-step camera distance: `camera_distance_in` and
  `camera_distance_out`.

The complete runtime profile may also contain non-ship actions such as `jump`,
`pause`, `toggle_controls_overlay`, and `toggle_first_person`. Their transformed
snapshots are validated with the rest of the frame but do not enter
`ShipCommand`.

Axes use logical `value` and held commands use logical `pressed`, so the existing
transform remains the sole owner of their deadzone, curve, hold, and toggle
semantics. One-shot commands use `physical_just_pressed`: choosing toggle for an
edge action cannot silently make it fire on only every other physical press.
Opposing axes subtract and clamp to the signed unit range. Opposing
camera-distance edges cancel in the same frame.

## Validation and failure behavior

`map_frame()` accepts only the sampler's exact accepted-frame shape: `sampled`
status, exact generation, finite non-negative physics delta, canonical unique
sorted action order, matching action dictionary, and strict transformed action
snapshots. It verifies primitive types, options, bounds, transformed scalar,
physical/logical state relationships, and the complete required flight roster.

Every rejection returns a fresh, valid neutral `ShipCommand`. The frame is never
retained or mutated. Caller metadata must already be non-negative integers in
the transport's lossless JSON range; it is rejected rather than clamped.

## Authority boundary and production integration

The mapper never calls `Input` or `InputMap`, owns no process callback or physics
clock, does not select devices, and owns no command sequence, queue, delivery,
`GameFlow`, or ship. It always emits `engine_start = false` and
`engine_stop = false`: accepted movement, hover, fire, landing, and other intent
continue to drive the existing automatic-propulsion semantics.

Mouse-look motion remains neutral inside this mapper because the logical sampler
frame contains no motion-event stream. `LocalShipInputSource` now composes it
with the existing motion and camera-distance backlogs and publishes through the
authority-aware command source. See `docs/LOCAL_SHIP_TRANSFORMED_INPUT.md`.
The mapper remains stateless and does not itself prevent frame reuse;
single-consumption belongs to that source composition.

Focused verification:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/transformed_ship_command_mapper_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ship_command_test.gd
```
