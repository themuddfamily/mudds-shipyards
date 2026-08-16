# Input action transform sampler

`InputActionTransformSampler` is the production-neutral state-sampling seam for
`InputActionTransformBank`. A caller supplies one physics delta and the exact
current bank generation. The sampler reads a complete raw action frame, submits
it through the bank transaction, and returns the bank's detached transformed
frame. It does not decide when physics runs or consume the result.

## Provider contract

An injected provider is any valid `Object` with both methods:

```gdscript
func get_action_strength(action: StringName) -> float
func is_action_pressed(action: StringName) -> bool
```

Passing no provider uses Godot's production `Input` singleton through those same
methods. The sampler never queries `InputMap`, bindings, devices, device family,
event type, or platform metadata. It samples logical actions already resolved
by the provider.

For every eligible `sample_physics_frame()` call, the sampler walks the bank's
canonical sorted roster and calls each method exactly once per action, strength
then pressed. It collects the whole provider frame before invoking the bank.
Wrong types and nonfinite strength record the first deterministic failure, but
the sampler still completes one read of both methods for every roster member;
the entire collected frame is then discarded. This keeps test/replay provider
call cardinality stable without partially sampling transform state.

An invalid provider, a provider missing either method, or a provider that
becomes invalid while being called rejects as a provider failure. Missing-method
validation happens before either method is invoked. An engine-level script error
that aborts a provider call is outside this value-level adapter's recovery
boundary and must be fixed in that provider.

## Tick validation

The adapter validates in this order before provider access:

1. sampler/bank configuration;
2. exact bank generation;
3. attached bank lifecycle;
4. numeric, finite, non-negative caller physics delta;
5. valid provider and both required methods.

Thus detached, stale, malformed-delta, and nonfinite-delta calls perform zero
provider reads and cannot mutate the bank. After collection, the bank repeats
its generation/lifecycle validation, so a hostile or faulty provider that
changes the bank while being sampled cannot commit a now-stale frame.

This state provider has no echo method. Godot `Input` exposes current held
action state here rather than OS key-repeat events, so every collected action is
an ordinary physics sample. Event-level echo suppression remains available on
the lower-level single-action transform API for event adapters.

## Atomic complete bank frame

The sampler required one narrow extension to `InputActionTransformBank`:

```gdscript
bank.process_complete_frame(raw_samples, physics_delta, generation)
```

`raw_samples` must be a dictionary containing exactly every bank action once.
Every value must contain exactly a numeric `raw_scalar` and boolean
`raw_pressed`. Before invoking the first child, the bank verifies:

- exact roster with sorted missing/unknown reports;
- attached matching child lifecycle;
- every sample's shape and finite scalar;
- finite elapsed, physical-hold, and logical-hold accumulation for every child;
- available sample counters.

This preflight is necessary even though the sampler reads its provider first. A
bank may have prior explicit per-action history: without the transaction, an
early action could commit before a later action rejects accumulated-time
overflow. Children are private and signal-free, so after complete preflight the
stable-order commit has no remaining external failure seam.

## Transformed frame

Accepted and rejected calls return primitive/dictionary data with:

- `accepted`, `reason`, and bank `generation`;
- accepted `physics_delta`;
- canonical `action_count` and copied `action_order`;
- `actions`, inserted in that order and containing detached child snapshots.

Provider identity and objects are never returned. A rejection contains no
action snapshots, preventing a caller from treating a partial provider/bank
read as a frame. `failed_action`/`failed_method` or roster differences are added
when they are safe and relevant.

## Authority and remaining integration

The sampler owns no profile persistence, `InputMap` mutation, device inference,
Player, ship, HUD, `GameFlow`, command, or gameplay authority. It does not attach,
detach, reset, or replace the bank, and it has no `_process` or
`_physics_process` callback.

Startup/production wiring remains a separately owned step: that owner must hold
the validated profile/bank lifecycle, call this adapter once per intended
physics tick, and map the detached transformed frame into existing input/command
consumers. This file deliberately does not choose that owner or bypass its
authority.
