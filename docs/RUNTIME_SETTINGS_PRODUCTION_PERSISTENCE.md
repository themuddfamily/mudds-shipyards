# Runtime settings production persistence

`GameFlow` is the production composition root for one `RuntimeSettings`, one
`UserDataStore`, one `RuntimeSettingsStoreAdapter`, and one
`SafeStartRecoveryPolicy` identity during the OS process. Whole-Main
detach/re-entry and a loader-driven Main reconstruction both adopt those exact
RefCounted objects. Re-entry/reconstruction reapplies already validated settings
but does not load again or begin a second startup. Injected test authorities
remain Main-local and never populate this production process state.

## Startup order

The atomic adapter loads exactly once, then GameFlow restores the safe-start
record and publishes `STARTING`, all before the first
`_apply_all_runtime_settings()`. A validated settings section, including the
complete `InputBindingProfile`, is therefore installed before InputMap and the
Player, five ships, tow tractor, audio buses, window, world-quality owner, and
HUD consume the snapshot.

An empty settings authority leaves authored defaults live; safe-start then owns
the store's first generation for its startup marker. Corrupt, unsupported/newer,
recovery-only, or failed settings loads still leave defaults live. Corrupt or
newer settings also block the lifecycle write so those bytes remain exact;
backup recovery may be inspected but cannot be advanced. The adapter's existing
generation-zero legacy import remains the only migration policy; GameFlow adds
no repair or delete behavior.

At the recovery threshold, an exact validated two-key recommendation may merge
`graphics_profile = low` and `window_mode = windowed` through the same adapter
before first apply. All other settings and namespaces are preserved. Unlike an
accepted user edit, this startup recommendation is staged as one atomic merge:
a failed save rolls its live values back to the pre-merge snapshot.

## Transactions

Each accepted HUD setting change that actually changes the validated snapshot
is saved immediately. Reset Defaults applies one batched live reset and saves it
once. The retained explicit Save action also creates one transaction. Unknown
keys and unchanged values are not state transactions and do not write.

Settings commit IDs use `runtime-settings-NNNNNNNNNN`; safe-start uses distinct
`safe-start-{begin,stable,clean}-NNNNNNNNNN` IDs. Both derive deterministic
successors from bounded store generations. The settings counter is deterministic,
bounded by `UserDataStore.MAX_GENERATION`, seeded from the loaded generation and
recognized prior settings commit ID. A failed attempt consumes no durable ID,
so its deterministic next ID is reused on retry; committed IDs remain monotonic
across process restarts even when the recovery namespace commits in between. No
wall clock enters persistence.

The adapter reloads current store authority before every save and replaces only
the `runtime_settings` payload key. Diagnostic, save-slot, and future unrelated
namespaces are retained exactly. Settings signals apply live side effects only;
they never invoke persistence. A synchronous signal callback that attempts a
nested settings/save transaction is rejected before touching the adapter.

A failed save does not roll back the user's accepted in-memory change. The
prior canonical bytes remain intact, `unsaved_changes` becomes true, and the HUD
reports the failure. A later successful transaction publishes the full current
snapshot and clears that flag.

## Status boundary

`get_runtime_settings_persistence_report()` returns deep-detached load/save
statuses, identity scalars, transaction counts, monotonic commit state, and the
startup-order witness. It exposes no live store, adapter, filesystem, or settings
object. `configure_runtime_settings_persistence()` is a pre-start dependency
injection seam used by focused tests; it permanently closes when settings
construction begins.

`get_safe_start_recovery_report()` independently exposes detached recovery
identity/status, the five-second physics-window progress, and explicit authority
flags. `mark_orderly_shutdown()` is the only clean-shutdown seam. Detach, free,
and re-entry never call it or infer process exit.

## Deliberate limits

- No automatic repair, deletion, or downgrade of corrupt/newer authority.
- No OS-crash or process-exit save hook.
- No automatic clean-shutdown inference from scene-tree detach/free.
- No automatic per-frame retry after a failed STABLE publication.
- No rollback of accepted live settings after a failed save.
- No multi-process writer coordination beyond `UserDataStore`'s existing
  generation and authority checks.
- No new gameplay, audio, reward, activity, ship, berth, save-game, or network
  authority.

## Focused verification

```sh
godot --headless --editor --path . --quit
godot --headless --audio-driver Dummy --path . \
  --script res://tests/runtime_settings_store_adapter_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/runtime_settings_production_persistence_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/safe_start_production_recovery_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/runtime_settings_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/accessibility_reentry_integration_test.gd
```

The production suite injects an in-memory filesystem/store before Main enters
the tree. It covers validated startup, complete binding application, change,
no-op, reset, explicit save, failed save, signal re-entry, unrelated namespace
preservation, detached status, corrupt/newer/failed/empty loads, and whole-Main
detach/re-entry without accessing the real production user-data path.
