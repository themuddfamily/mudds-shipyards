# Input action transform

`InputActionTransform` is the production-neutral execution boundary for one
action's normalized `InputBindingProfile` options. It turns the profile's
stored deadzone, response curve, and hold mode into a deterministic sampled
result. It does not read or mutate `InputMap`, poll devices, dispatch an action,
or own Player, ship, HUD, `GameFlow`, or other gameplay authority.

## Construction and lifecycle

Construct from a profile action so missing options fail closed:

```gdscript
var transform := InputActionTransform.from_profile(profile, &"fire")
var generation := transform.get_generation()
transform.attach(generation)
var result := transform.process_sample(raw_strength, raw_pressed, physics_delta, generation)
```

The action ID must be non-empty and the options must pass
`InputBindingProfile.normalize_action_options()`. No local aliases or fallback
settings are accepted. Consequently the only executable option IDs are the
profile's `linear`/`squared` curves and `hold`/`toggle` modes, and its inclusive
deadzone bound remains exactly `0.0 .. 1.0`.

Instances begin detached. `attach()`, `detach()`, `reset()`, and
`process_sample()` require the exact current generation. Detach preserves the
persistent identity and sampled state while rejecting new samples; it clears
one-sample edge flags so a later owner cannot replay a press/release. Reattaching
at the same generation resumes the persistent state without hidden elapsed
time. Reset is allowed attached or detached, advances generation, clears all
sampled state, and preserves the lifecycle state. This lets a later owner
survive a tree/Main detach while stale callbacks fail closed.

## Scalar transform

Finite raw strength is clamped to `[-1, 1]`, retaining sign. Magnitudes at or
below the stored deadzone become zero. Magnitudes above it are linearly remapped
from `(deadzone, 1]` to `(0, 1]`; the `squared` curve then squares that remapped
magnitude before restoring sign. A deadzone of `1.0` therefore closes the full
normalized range without division by zero. This is an executable input rule,
not a new persisted setting.

A physical press requires both `raw_pressed` and a non-zero post-deadzone
scalar. That prevents button/axis noise inside the configured deadzone from
creating edges. Returning inside the deadzone produces one physical release,
even if a caller's raw pressed flag remains true.

## Hold, toggle, and time

`hold` output follows post-deadzone physical state and exposes the signed
transformed scalar as `value`. `toggle` changes its boolean latch only on a
rearmed physical rising edge; holding, repeated samples, and key echo cannot
retrigger it. Toggle output uses `1.0` while latched and `0.0` otherwise, while
`transformed_scalar` still exposes the signed response-curve result.

Snapshots distinguish physical `physical_*` fields from logical
`pressed`/`just_*` output. Thus a toggle's physical release rearms the input but
does not report a logical release; the next rising edge that turns the latch off
does. `physical_hold_seconds`, logical `hold_seconds`, and `elapsed_seconds`
advance only from accepted, caller-supplied physics delta. Process/render frames
and detach time do nothing. Zero delta is valid. Negative/nonfinite delta,
nonfinite raw strength, and finite additions that would overflow reject before
state mutation.

Echo samples are accepted as `echo_ignored`: they clear one-sample edge flags
but do not change raw/physical/logical state, increment the sample count, toggle
a latch, or advance time. Ordinary release is sampled with `raw_pressed=false`;
repeated release creates no additional edge.

## Snapshot and audit

`get_snapshot()` returns a deeply detached action/options, generation,
lifecycle, raw/transformed, physical/logical edge, latch, value, hold-time, and
sample-count tree. `audit()` adds configuration errors, the exact supported
profile vocabulary and bounds, an embedded detached snapshot, caller-physics
timing ownership, and explicit zero adjacent-authority flags.

## Deliberate limits

This foundation does not choose which bindings feed an action, combine multiple
devices, poll `Input`, mutate `InputMap`, persist settings, dispatch commands,
implement per-axis hysteresis, or wire any production consumer. It also does
not invent cubic curves, per-direction curves, alternate deadzones, or extra
hold modes. Mapping real sampled actions into Player/ship behavior remains a
later explicit integration step.
