# Session diagnostic record foundation

`SessionDiagnosticRecord` is a bounded, privacy-safe observation service for
session and crash evidence. Callers pass a typed `SessionDiagnosticEvent` with a
fixed event/severity enum, session identity, physics tick, physics-session
elapsed seconds, and at most 12 input fields. Only the fixed typed
boolean/numeric vocabulary below can be retained.

The service retains the newest 64 events. It removes recognized secret fields
and records only their count; it rejects arbitrary field names, every string
value, path/message/user-text fields, nested values, nonfinite numbers, and
values outside the documented bounds. Snapshots are deeply detached,
JSON-safe, and emitted with a fixed key order plus sorted primitive field keys.
No wall clock is sampled.

The retained field vocabulary is exact: counts/error/device/peer codes are
bounded integers; damage ratio, physics duration/delta, and speed are bounded
floats; `recovered` is boolean. Damage ratio is `0..1`, frame delta is at most
60 seconds, duration uses the 30-day session ceiling, counts top out at one
million, peer count at 4,096, and speed at 1,000,000 m/s.

Persistence is opt-in. Construct the recorder with an already-loaded
`UserDataStore`, then call `persist()` with a caller-owned stable commit token.
The recorder merges only `session_diagnostics` into the current payload so
settings and save namespaces remain caller-owned. `restore_from_store()` is
allowed only while detached and never restores an observer attachment.

The focused proof is:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/session_diagnostic_record_test.gd
```

## Deliberate limitations

- This is not wired to `Main`, crash recovery, OS exception handling, a log
  uploader, UI, settings, save games, networking, or release packaging.
- It records only the fixed enum/primitive vocabulary. It cannot preserve stack
  traces, filenames, free-form errors, usernames, or player-authored text.
- Secret detection is field-name based. Unknown fields fail closed, but numeric
  values cannot be classified by meaning; callers must not encode secrets into
  allowed numeric fields.
- The 30-day elapsed-session ceiling and 64-event ring are foundation bounds,
  not evidence for long-session production tuning.
- `UserDataStore` provides recoverable atomic replacement within Godot's
  GDScript filesystem limits; this layer adds no fsync, encryption, or OS crash
  handler.
