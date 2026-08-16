# Atomic user-data store foundation

`scripts/persistence/user_data_store.gd` is the Phase 9 persistence boundary for
user data. The store itself remains independent of `RuntimeSettings`,
`GameFlow`, HUD, save slots, networking, cloud sync, and migration policy.
`scripts/settings/runtime_settings_store_adapter.gd` now composes this boundary
for settings without adding settings knowledge to the store.

The compact JSON envelope is schema version 1 and has exactly four fields:
`schema_version`, positive `generation`, `commit`, and `payload`. Commit metadata
has exactly `id`, `parent_generation`, `parent_id`, and the SHA-256 of canonical
payload JSON. Callers supply the stable commit ID; timestamps are excluded so
equivalent input is deterministic. Payload dictionaries may define application
keys, but values are restricted to JSON primitives, arrays, and dictionaries
with nonempty string keys.

Loads select the validated primary first and then the validated `.bak` sibling.
A `.tmp` sibling is never load authority. Missing primary and backup produces an
empty generation-zero store; existing but invalid documents produce a closed
failure without changing the last loaded snapshot. Unsupported newer schemas,
unknown envelope/commit fields, malformed types, non-finite numbers, hash
mismatches, invalid UTF-8, corrupt/truncated JSON, and exceeded limits are not
partially interpreted.

If the primary, backup, or temporary artifact declares a newer schema, the
entire operation refuses and preserves every byte; an older build never falls
back past or deletes possible newer data. When only the primary is corrupt and
the backup validates, load exposes that backup as a detached recovery snapshot.
A later generation-checked `commit()` is the explicit repair action: it replaces
the corrupt primary while retaining the verified backup.

Commits require the exact loaded generation and a new printable-ASCII commit ID.
The store canonicalizes and validates a detached payload, writes a same-directory
`.tmp`, calls `FileAccess.flush()`, reads and validates it, rotates the validated
primary to the retained `.bak`, and renames the verified temporary file into the
primary path. Failed publication restores the backup when possible. Load never
overwrites an invalid primary; only an explicit generation-checked commit after
a valid backup load performs that repair.
Ordinary failed commits best-effort remove their staged `.tmp` and report the
rollback outcome. A stale `.tmp` left by process interruption is ignored by
load and removed before the next commit, but is never promoted on its own.

Bounds are intentionally conservative: 1 MiB encoded document, depth 12, 4,096
total payload entries/keys, 256 UTF-8 bytes per key, 16 KiB per string, printable
commit IDs up to 128 bytes, generations through 2,147,483,647, and integers in
the interoperable JSON range ±(2^53−1).

Godot's JSON parser exposes JSON numbers as floating-point variants. Envelope
generations are therefore accepted only when finite and mathematically integral,
then normalized to integers by the API. Payload numbers retain JSON number
semantics; a later typed settings/save adapter is responsible for reconstructing
domain integers after its own validation.

Crash-consistency limit: Godot 4.7 exposes `FileAccess.flush()` to GDScript but
not a file `fsync`/`FlushFileBuffers` or parent-directory sync primitive. The
same-directory rename and retained validated backup make interrupted operations
recoverable through the next load, but this layer cannot promise persistence
through every kernel/filesystem/power-loss ordering. It also does not provide
cross-process locking, encryption, authentication, compression, migrations, or
multi-file transactions.

## Runtime settings adapter

`RuntimeSettingsStoreAdapter` owns one `runtime_settings` key inside the shared
store payload and preserves all unrelated keys on save. Its section has an
independent schema version and contains every validated runtime preference plus
the complete `InputBindingProfile`. `RuntimeSettings.to_user_data_payload()`
converts all `StringName` keys/values to JSON strings;
`apply_user_data_payload()` strictly reconstructs JSON-normalized integral
binding fields before validating the whole profile against the captured project
defaults. A malformed, sparse, out-of-range, conflicting, unknown-field, or
newer section leaves the live resource untouched. Load and save remain
side-effect free: audio, display, and `InputMap` application are still explicit
runtime operations.

Call `load()` to select and validate current atomic authority. A supported
`user://settings.cfg` is imported only when the store reports an authoritative
empty generation zero with both primary and backup missing. Migration first
loads into a detached `RuntimeSettings`, then commits
`runtime-settings-legacy-v1`; live state changes only after that commit succeeds.
The source ConfigFile is retained. A valid nonempty store without a settings
key, corrupt atomic data, or a newer atomic/settings/input-profile schema never
falls back to legacy data and is not overwritten.

Call `save(commit_id)` with a new printable stable commit ID. It reloads exact
authority, validates any existing settings section, replaces only that payload
key, and delegates publication/rollback to `UserDataStore`. The returned status
includes the adapter `reason`, `store_reason`, generation, and detached complete
`store_status`; failed commits do not roll back or otherwise alter the live
settings being saved, and the store preserves its preceding authority. Ordinary
save also refuses a backup-recovery load (`store_recovery_required`) so replacing
a corrupt primary remains a separate explicit repair decision.

This foundation is not invoked by `GameFlow` or HUD yet. It does not delete the
legacy ConfigFile after migration, automatically invent commit IDs, repair
corrupt authority, resolve cross-process writers, or apply process-global
settings side effects.
