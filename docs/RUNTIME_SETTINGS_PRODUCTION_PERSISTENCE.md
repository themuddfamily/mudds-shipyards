# Runtime settings production persistence

`GameFlow` is the production composition root for one `RuntimeSettings`, one
`UserDataStore`, one `RuntimeSettingsStoreAdapter`, and one
`SafeStartRecoveryPolicy` identity during the OS process. Whole-Main
detach/re-entry and a loader-driven Main reconstruction both adopt those exact
RefCounted objects. Re-entry/reconstruction reapplies already validated settings
but does not load again or begin a second startup. Injected test authorities
remain Main-local and never populate this production process state.

Camera preferences have their own contract:
`docs/ULTRAWIDE_FIELD_OF_VIEW_POLICY.md` documents `camera_fov`'s meaning on
displays wider than 21:9 and the `limit_ultrawide_fov` opt-out that governs it.

HUD presentation preferences likewise: `docs/ACCESSIBILITY_PRESETS.md`
documents `high_contrast_hud` and `reticle_style`. They moved the typed
`RuntimeSettings` payload to schema 11. A schema-10 section (the schema that
introduced `limit_ultrawide_fov`) still loads and is upgraded in memory with
`high_contrast_hud = false` and `reticle_style = "standard"`; a schema-10
section that already carries either key is `value_fields_invalid`; an unknown
`reticle_style` in a current section is `invalid_reticle_style`; and a
schema-12+ section is still `newer_schema`, so the adapter preserves its bytes
exactly rather than treating them as replaceable corruption. `reticle_style`
is stored as its stable plain-string ID in both the ConfigFile and the typed
payload, never as a menu index.

## Startup order

The atomic adapter loads exactly once, then GameFlow restores the safe-start
record and publishes `STARTING`, all before the first
`_apply_all_runtime_settings()`. A validated settings section, including the
complete `InputBindingProfile`, is therefore installed before InputMap and the
Player, registered fleet, tow tractor, audio buses, window, world-quality owner, and
HUD consume the snapshot.

For a genuinely empty authority without legacy data, normal Main first persists
authored default settings; recovery/tutorial owners commit afterward. An invalid
or unsupported settings section leaves defaults live. A corrupt primary with a valid backup is
different: the adapter applies that backup's validated settings and complete input
profile read-only. Normal Main creates a `.recovery` copy of the damaged primary;
the primary and backup stay byte-identical. Settings Save refuses with
`store_recovery_required` and visible UNSAVED feedback until the separate explicit
repair action is confirmed. Durable safe-start startup/close writes also refuse;
that refusal is not a successful clean-shutdown publication. Ordinary Begin Shift,
supported walking and Settings Back/Resume remain usable.

Generation-zero legacy import remains limited to a genuinely empty authority;
it does not bypass corruption protection. Supported typed migrations above remain
in force. Main startup does not silently repair, promote or delete the backup.
The two-normal-process source case is [qualified here](history/ROADMAP_DELIVERIES.md#corrupt-backup-read-only-fallback-accepted-20261025);
explicit repair, other corruption arrangements and installed/native-device checks
remain separate.

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
godot --headless --audio-driver Dummy --editor --path . --quit
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

## Remaining remapping outcomes

REMAP-DEFINE source inventory on `c1fc23871` (2026-10-18), parents8/29.
This is a finite source definition, not renewed runtime or device acceptance.
The current authored profile has23 non-ui actions and22 visible remapping rows;
`capture_screenshot` is hidden/protected. Engine ui navigation is excluded by
InputRebindService's project-action filter, not removed by profile application.

The shared `sprint_boost` row is labelled “Sprint / boost” and exposes HOLD/
TOGGLE without a ship-only restriction. HUD commits that option into the same
profile that GameFlow applies to all registered fleet sources. At inventory,
ship boost used transformed held state, but Player._sample_sprint_held() read
Input directly and physics used that raw state for sprint speed, ignoring the
advertised on-foot toggle choice. This concrete consumer repair is
accepted in checkpointbd4e15d. Preserve remote _remote_run authority and
control-disable/scene lifecycle fences; no replacement settings store is needed.

| Remaining outcome | Existing scope and boundary |
| --- | --- |
| Distinct-process remap/options restoration with usable menu/gameplay | game_flow_runtime_input_rebind_persistence_test covers HUD remap/conflict and recreated settings/HUD using an in-memory store; input_binding_persistence_test covers explicit InputMap apply/reentry. These are not OS-process restart proof. |
| Ordinary conflict/reset/return usability | Existing HUD integration covers capture, stale/cancel/reset, reserved screenshot and last controller-Pause guard, including GUI routing. Actual device/focus full route remains open. |
| Packaged/user-file failure/recovery journey | Adapter and production checks cover atomic failed writes, corrupt/newer preservation and fallback/live retention. No additional missing persistence implementation identified; selected physical/durable journey acceptance remains open. |
| Hardware/controller-only completion | Synthetic controller sortie/expedition scopes do not prove actual hardware or every required action. Retain original hardware/focus/full-route gates. |

Other on-foot movement and tow-tractor curve/toggle meanings require an explicit
context contract: InputMap already supplies their bindings/deadzones, while the
ship transform supplies curve/toggle execution. This inventory does not assume
new behavior for every action/context pair. Keep SETTINGS-INPUT's original
runner/profile/log dependency WAITING and the failed Settings-return route parked;
none of these finite definitions replaces or reopens it.

## Local walking sprint application

Checkpoint `bd4e15d` wires the shared sprint profile into PlayerController's
existing local sampler through one InputActionTransform. GameFlow preflights
`can_apply_sprint_input_profile()` alongside fleet consumers before InputMap or
bank mutation and calls `apply_sprint_input_profile()` after synchronous commits.
Detached settings-only GameFlows with no Player still apply InputMap; fleet
source counts retain their existing meaning. No second settings store exists.

Equal live sprint bindings/options retain the latch; changed options/bindings
replace it. Control disable, boarding/disembark/recovery, remote handoff and
actual tree exit clear local sprint intent. Local enable/reentry primes physical
held state so a held key is not a new toggle press. While remote drive is enabled,
only accepted remote run drives sprint and priming never reads host Input.

The existing sprint reentry test preserves its ship assertions and covers the
retained Player, staged supported physics speed across release/second press,
live/default/HOLD/reset and lifecycle/remote boundaries. Existing rebind integration,
rebind persistence and production settings suites pass on this checkpoint.
These synthetic/in-memory/manual-physics checks do not close the distinct-process,
ordinary Settings-route or physical-device/full-controller gates above.

### Sprint option across distinct OS processes — source qualification7570edf7c

The missing option-to-runtime endpoint in the table above is now qualified for
Sprint/boost HOLD/TOGGLE. This is separate frombd4e15d's accepted in-memory/manual
physics coverage, which is retained unchanged. The opt-in modes in the existing
runtime_settings_production_persistence_test.gd are --sprint-restart-writer,
--sprint-restart-reader and --sprint-reset-reader, all with the same explicit
--sprint-restart-private-root and actual private XDG profile, headless/Dummy.

Normal Begin/visible hold-mode selection/Apply + Save writes TOGGLE. A distinct
normal Main loads it before first apply, then raw S/Shift through naturally
scheduled Player physics reaches9.2, retains9.2 for three completed ticks after
Shift release, and returns5.8 on the second press. Neutral stops0. Visible Reset
Defaults follows its existing clean-reset path (confirmation only if opened),
then Save and normal Exit. A third cold process loads HOLD; held Shift reaches
9.2 and release with S still held returns5.8. No provider, actor pose/velocity,
manual physics or direct sprint sampler is used. Each endpoint has the frozen
30-actual-physics-step limit and existing<.01 speed tolerance, support/control/
on-foot/unpaused checks and≤5m bound; observed maxima are2.973m/2.513m.

All authored bindings/controller mappings and unrelated settings remain exact;
only the selected hold_mode differs. Each real HUD Exit is independently verified
OS0 with both durable clean markers, unique PID/start/reap and same actual file/
directory identity. Existing default/HUD and complete Interact worker cases pass.
This accepts that one synthetic-raw cold-process option case, not physical devices,
ship boost, ordinary Settings return, original GateC or the full remap family.
[Source, raw results and cleanup](history/ROADMAP_DELIVERIES.md#sprint-toggle-cold-process-qualified-20261025).
