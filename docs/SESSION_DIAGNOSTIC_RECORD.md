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

## Production ownership and acceptance

`GameFlow._initialize_session_diagnostics()` composes the record, existing
`CrashRecoveryCoordinator`, `SessionDiagnosticLifecycleBridge` and
`SessionDiagnosticFileSink("user://diagnostics")`. Main restores the stored ring,
starts the diagnostic session and observes runtime modes and clean shutdown.
The recorder itself owns neither a clock nor filesystem access.

After an unfinished prior session, the coordinator captures one recovery snapshot
and one `CRASH_DETECTED` event. If file publication fails, Main's physics consumer
retries the existing cached publication at one-second intervals while the bridge
is STARTING or STABLE. Its countdown is independent of ordinary ring persistence:
a successful store save cannot postpone the crash-log retry. Success or clean
shutdown stops retries; there is no independent timer surviving Main teardown.
The same snapshot is retried rather than recaptured.

The existing Main integration check refuses only crash-log stage writes while
ordinary store saves succeed. It observes initial refusal, half-second boundaries,
repeated failure, eventual publication of the exact captured wire snapshot, one
crash event, and no retries after success or clean shutdown. The record/lifecycle/
file-sink checks cover bounded typed fields, redaction, detached snapshots,
foreign-payload preservation and staged publication. These are source checks with
injected filesystem failures. They do not establish real OS-crash recovery.

```sh
bash tools/run_affected_suites.sh --godot /path/to/godot --audio-driver Dummy \
  --jobs 2 --timeout 300 --import-gate never --results-dir /private/results \
  main_session_diagnostics_integration_test session_diagnostic_record_test \
  session_diagnostic_lifecycle_bridge_test session_diagnostic_file_sink_test
```

Import the clean source headlessly with Dummy audio before using `--import-gate
never`. PASS requires all four existing suite markers exactly once, exit zero
and no unexpected diagnostics; retain the suite logs and source identity.

The sink publishes `crash-log.json` under the diagnostics directory, with one
previous generation and staged replacement. Each log holds at most four
snapshots/256 KiB. Support exports contain validated current/previous snapshots,
not arbitrary engine logs, and retain at most three bundles/256 KiB per bundle.
Malformed-data quarantine and directory durability remain bounded by the existing
sink implementation; no native directory-fsync guarantee is made.

The optional `SessionDiagnosticProductionBinding`, network diagnostics adapter
and lifecycle four-transition threshold API are component seams; Main's direct
composition does not imply those APIs have production callers.

## Deliberate limitations

- There is no OS exception handler or log uploader. Validated diagnostic JSON
  does not prove privacy of raw engine logs or quarantined bytes.
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
