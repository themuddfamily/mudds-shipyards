# Safe-start recovery policy foundation

`SafeStartRecoveryPolicy` is a caller-driven persistence boundary for detecting
consecutive startups that never reached a known-stable physics state. It stores
one strict schema-versioned record in the `safe_start_recovery` namespace of an
already-loaded `UserDataStore`. It has no clock, process callback, operating
system crash detection, settings authority, GameFlow integration, or HUD
integration.

## Caller sequence

1. Load `UserDataStore`, then call `restore()` with its exact generation.
2. Allocate a positive, monotonically increasing startup generation and call
   `mark_startup_begin()` with exact record/store generations and a deterministic
   commit ID.
3. After a caller-selected physics-stability window, call
   `mark_stable_after_physics_window()`. This is the only transition that resets
   accumulated failures.
4. During orderly teardown, call `mark_clean_shutdown()`. This closes an active
   startup marker so it is not counted as unfinished on the next startup.

The first startup begins with zero failures. Beginning a new startup over a
persisted `starting` marker increments the count exactly once. The count
saturates at 8. At 3 consecutive unfinished startups, the policy publishes a
safe-settings recommendation. Duplicate lifecycle calls are idempotent, while
stale startup, record, and store generations are rejected.

## Recommendation contract

The recommendation is detached data, not an applied setting. Its patch contains
only `graphics_profile = low` and `window_mode = windowed`, targets the current
RuntimeSettings payload schema, and explicitly requires all unlisted controls,
bindings, camera, audio, and accessibility values to remain unchanged. A future
consumer must validate the existing RuntimeSettings namespace and merge these
two keys; this policy never applies or persists the patch itself.

Malformed, unsupported, or newer safe-start records are rejected without being
overwritten. A recovered backup may be inspected, but mutation is refused until
the caller explicitly repairs/reloads primary store authority. Every commit
preserves unrelated namespaces and uses `UserDataStore` generation checks and
atomic commit behavior. Signals are emitted only after state is committed, and
all public lifecycle operations reject signal-driven reentry.

## Later production wiring seam

A future startup composition owner should load the store, restore this policy,
allocate deterministic startup/commit identities, and call `mark_startup_begin`
before normal startup proceeds. That owner chooses the physics-stability window,
calls the stable transition after it, and records orderly shutdown. If a
recommendation exists, the same owner may present or explicitly validate and
merge it through the RuntimeSettings persistence adapter. No hidden processing
or lifecycle inference belongs in this policy.

Focused verification:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/safe_start_recovery_policy_test.gd
```
