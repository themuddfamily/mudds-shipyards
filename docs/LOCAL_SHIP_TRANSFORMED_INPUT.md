# Local ship transformed input integration

`LocalShipInputSource` now composes the validated `InputActionTransformBank`,
`InputActionTransformSampler`, and `TransformedShipCommandMapper` behind its
existing authority-aware `ShipCommandSource` transport. It remains the owner of
command sequence, timestamp, stream epoch, lifecycle FIFO, mouse-motion backlog,
and mouse-wheel camera-distance backlog.

## Default compatibility profile

At construction the source obtains the complete process-stable authored project
binding roster from `RuntimeSettings` (which owns that snapshot across whole-Main
re-entry). Its retained default profile keeps those exact 22 action binding lists
and installs `deadzone = 0`, `curve = linear`, and
`hold_mode = hold` for each action. This is deliberate compatibility, not a
second calibration claim: the source samples already-resolved logical
`Input.get_action_strength()` values, and the identity transform preserves the
old raw LocalShipInputSource response instead of applying the authored InputMap
deadzone twice.

Production `GameFlow` now replaces that construction profile with the exact
validated `RuntimeSettings` profile for all five retained local sources. Since
InputMap already owns physical binding/deadzone resolution, the production
provider lifts its resolved strength into the transform's deadzone domain; the
bank can retain the exact deadzone and apply curve/hold semantics while the
default linear response remains unchanged.

Injected providers keep the same two-method contract. Legacy test/replay
providers that supply non-zero flight-axis strength without independently
reporting that axis pressed are normalized as pressed for the eight axis actions.
For non-axis actions, a pressed-only legacy button sample is normalized to the
same scalar-one/pressed pair that production `Input` exposes. The adapter still
invokes each underlying provider method exactly once per action. Default and
injected sampling both pass through the complete bank/sampler/mapper path.
Injected providers are raw by default. An adapter that already models InputMap
resolution declares `INPUT_PROVIDER_INPUT_MAP_RESOLVED`, preventing the same
logical magnitude from being attenuated twice.

## Explicit configuration API

The source exposes detached state and generation-safe mutation:

- `get_input_binding_profile()` / `get_authored_input_binding_profile()`;
- `get_input_profile_generation()` and `get_input_transform_snapshot()`;
- `replace_input_binding_profile(profile, generation)` plus the current-generation
  convenience `configure_input_binding_profile(profile)`;
- `validate_input_binding_profile(profile, generation)` for side-effect-free
  multi-source transaction preflight;
- `reset_input_binding_profile(generation)` and
  `reset_input_binding_profile_to_authored()`;
- `reset_input_transform_state(generation)`;
- exact-generation `detach_input_transform()` / `attach_input_transform()`;
- `set_input_transform_physics_delta()` for deterministic callers.

A RuntimeSettings owner can pass its detached validated profile directly. The
bank requires the exact initial 22-action roster and replaces every transform
atomically, so stored deadzone, linear/squared curve, and hold/toggle options
become executable. A successful profile/reset/lifecycle change starts a new
command epoch and clears pending delivery; stale or invalid input changes
nothing. The API remains usable without `GameFlow`; production `GameFlow` is its
canonical RuntimeSettings composition owner.

At startup and live replacement, `GameFlow` preflights the candidate and current
generation against every ship-retained local source before applying InputMap or
committing a bank. The synchronous, signal-free commit advances each changed
bank once. Exact matches are not replaced, so whole-Main re-entry reclaims the
process-global InputMap without adding a profile generation or resetting toggle
state beyond the source's existing detach/entry lifecycle fences.

## Command and failure behavior

Every active command sample reads the whole profile through the sampler, validates
the detached frame in the mapper, then lets the existing source base install its
real sequence/timestamp/stream metadata. Axes use transformed logical values;
boost/brake/hover/fire use logical held state; barrel-roll, landing, interaction,
camera-toggle, and camera-distance use physical rising edges. Toggle therefore
remains meaningful for held commands without dropping every other one-shot.

Mouse motion and wheel steps are consumed only after the transformed frame and
mapped command validate. Malformed, nonfinite, stale, or detached samples return
a neutral command without partially advancing transform state or discarding the
motion backlog. Explicit test/replay edges still enter the same command snapshot.
`engine_start` and `engine_stop` are always false; movement, fire, hover, landing,
and other accepted demand continue to drive HeroShip's automatic propulsion.

The source owns no RuntimeSettings mutation, profile persistence, GameFlow, HUD,
HeroShip, AI, or device-selection policy. `GameFlow` owns selecting and passing
the active RuntimeSettings profile; the source owns only exact-generation
validation, transform state, and command delivery.

Focused verification:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/local_ship_transformed_input_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ship_command_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/control_mapping_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/runtime_settings_production_persistence_test.gd
```
