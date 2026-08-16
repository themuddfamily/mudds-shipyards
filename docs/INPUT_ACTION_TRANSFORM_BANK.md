# Input action transform bank

`InputActionTransformBank` is the production-neutral profile-wide owner for the
per-action `InputActionTransform` foundation. It validates and detaches one
complete `InputBindingProfile`, freezes its exact action roster, and constructs
one transform for every action in stable lexical order. The bank coordinates
profile and owner lifecycle; all deadzone, curve, hold, toggle, echo, release,
noise, and numeric processing remains in the reused child transform.

## Complete profile contract

Construction accepts only a profile that survives a full
`InputBindingProfile.from_dictionary(profile.to_dictionary())` validation. Its
binding and action-option keys must be the same non-empty set. The sorted set
becomes the bank's immutable action roster.

`replace_profile()` accepts changed bindings and normalized options only when
the complete candidate contains that exact roster. Missing and injected actions
are reported separately and reject before any child changes. Malformed,
option-only, empty, and null profiles also fail closed. Accepted profile data is
canonicalized in sorted order and detached from subsequent caller mutation.

This roster check is intentionally local. The bank does not compare against or
read the project `InputMap`; a future owner must supply the already validated
runtime profile whose roster it intends to execute.

## Sampling API

```gdscript
var bank := InputActionTransformBank.new(profile)
var generation := bank.get_generation()
bank.attach(generation)

var fire := bank.process_action_sample(
    &"fire", raw_strength, raw_pressed, physics_delta, generation, is_echo
)
```

`process_action_sample()` accepts one explicit action and caller-owned physics
sample. It rejects invalid bank configuration, stale bank generation, an action
outside the frozen roster, and sampling while detached. Accepted results carry
the bank generation, action ID, and a deeply detached child snapshot. Each
child's value, time, edge, and sample count are independent: sampling one action
cannot advance a sibling.

`get_action_snapshot(action, generation)` provides exact-generation inspection
while attached or detached. `get_snapshot()` provides the whole canonical
profile plus every action snapshot inserted in `action_order`; it exposes no
child object reference. The `generation` inside a nested child snapshot is an
implementation audit of that rebuilt transform. Callers use only the bank's
top-level generation for freshness.

The bank does not define a frame-wide sample. A later production owner must
explicitly sample each action it needs once per intended physics step. This
avoids inventing device aggregation or timing policy inside the settings layer.

## Atomic replacement and reset

Profile replacement and whole-profile `reset()` validate, canonicalize, build,
and—when needed—attach an entire candidate child set before committing it. On
success the bank generation advances once. On rejection the profile,
generation, lifecycle, values, elapsed time, edges, and toggles are unchanged.
Fresh children mean no held state, one-sample edge, elapsed time, or toggle can
cross reset or replacement; callbacks carrying the prior bank generation fail.

Reset preserves the currently accepted profile and attached/detached lifecycle;
it resets transform state, not settings to project defaults. Default-profile
selection remains the settings owner's responsibility.

## Detach and re-entry

`detach()` preflights every owned child, then invokes the existing transform's
detach contract in sorted order. Persistent state—pressed output, value, time,
and a toggle latch—belongs to the same bank generation and is retained. Every
one-sample press/release edge is cleared, so reattaching the same generation
cannot replay input. Detached sampling is rejected and process/render frames do
nothing. A reset while detached retires retained state without implicitly
reattaching the new generation.

Retaining a toggle across detach is continuity, not cross-profile leakage. A
toggle is guaranteed not to survive reset or profile replacement.

## Audit and authority boundary

`audit()` returns detached sorted child audits, the embedded whole-bank
snapshot, exact-roster and atomicity declarations, and explicit boundaries:

- caller-supplied physics delta only;
- no `InputMap` polling or mutation;
- no device inference or device-family combination;
- no Player, ship, HUD, `GameFlow`, command, persistence, or gameplay authority.

## Remaining production seam

One explicit integration seam remains: a production input owner must create and
replace the bank from `RuntimeSettings`' validated profile, feed each required
action's raw scalar/pressed/echo sample with physics delta, and consume the
returned transformed values/edges when building existing gameplay commands.
Until that owner is deliberately wired and tested, persisted curve/hold choices
remain executable foundations rather than production flight behavior.
