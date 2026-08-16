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

## Production composition

`GameFlow` now composes one process-lifetime policy with the same retained
`UserDataStore`, `RuntimeSettings`, and `RuntimeSettingsStoreAdapter` used by
production settings persistence. The adapter performs its one startup load;
GameFlow then restores the policy and publishes `STARTING` before the first
settings application reaches InputMap, Player, the five ships, world quality,
window/audio state, or HUD. Startup generations advance from the durable record.
Lifecycle commit IDs are deterministic successors of the shared store
generation (`safe-start-begin-NNNNNNNNNN`, `safe-start-stable-NNNNNNNNNN`, and
`safe-start-clean-NNNNNNNNNN`) and remain bounded by the store generation limit.

GameFlow accumulates exactly 5.0 seconds of positive, finite `_physics_process`
delta before asking the policy to mark `STABLE`. Zero delta, idle frames, wall
clock, and time spent detached do not contribute. A whole-Main detach/re-entry,
or a reconstructed GameFlow adopting the retained process composition, keeps
the same policy/startup identity and cannot increment the failure count or
reload the store. A failed stable publication remains conservatively
`STARTING`; it is reported but not retried every physics frame.

There is intentionally no clean-shutdown hook in `_exit_tree()`, `free()`, or
the loader. Application-owned orderly shutdown must explicitly call
`GameFlow.mark_orderly_shutdown()`. This prevents ordinary Main streaming from
being misclassified as a successful process exit.

When the threshold recommendation is present, GameFlow validates its exact
schema, ID, target, two-key patch, and preservation roster. It stages only
`graphics_profile = low` and `window_mode = windowed`, then saves the complete
merged settings section through `RuntimeSettingsStoreAdapter`. Every control,
binding, camera, audio, and accessibility value plus every unrelated store
namespace is preserved. Failure rolls the staged live recommendation back, so
the merge is atomic from the settings consumer's perspective. Corrupt/newer
settings, malformed/newer recovery records, and backup-recovery authority are
never overwritten or implicitly repaired.

`get_safe_start_recovery_report()` exposes deep-detached lifecycle statuses,
identity scalars, the policy snapshot, physics progress, and authority flags; it
does not expose the live policy/store/settings/filesystem objects.

Focused verification:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/safe_start_recovery_policy_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/safe_start_production_recovery_test.gd
```
