# RangeOpponent component-damage adapter

`RangeOpponentComponentDamageAdapter` is the first production consumer of the
standalone `ComponentDamageModel`. It replaces `RangeOpponent`'s former `_health`
scalar with one private `hull` component; it is not an observer or mirror.

The captured hull stages reproduce the current opponent outcomes exactly:

| Stage | Inclusive health ratio | Disabled | Performance multiplier |
| --- | ---: | --- | ---: |
| `nominal` | `1.0` | false | `1.0` |
| `damaged` | `0.67` | false | `1.0` |
| `critical` | `0.34` | false | `1.0` |
| `destroyed` | `0.0` | true | `0.0` |

Only the terminal stage has a data consequence. Damaged and critical hull do
not reduce movement, tactics, firing cadence, or collision authority. Existing
presentation remains on `RangeOpponent`: sparks start at `0.67`, smoke at
`0.34`, and critical engine output keeps its existing oscillating visual
formula and port-side factor. Model stage signals are deliberately not wired to
those effects because authoritative health is immediate while pulse impact,
smoke, explosion, and audio may be deferred to a presentation receipt.

The adapter allocates its own monotonically increasing damage sequence inside
each model generation. This sequence is never a combat-source sequence or a
presentation receipt. `activate_with_result()` is the explicit reset seam; a
successful activation advances one generation and resets only that private
sequence. Ordinary deactivation and whole-owner detach/re-entry do not reset
the model. They retain health and generation while existing owner code clears
transient presentation and combat registration state.

Every accepted `activate_with_result()` commits the matching presentation
recovery in the same lifecycle call. The base defender, siege picket, courier,
and wing skirmisher immediately restore nominal component stages, engine plume
scale/visibility and engine lights; clear persistent hull/weapon sparks, engine
smoke and sensor damage light; and retire impact, destruction, and debris nodes.
The detached activation result includes the same
`range_opponent_component_recovery` report available from
`get_component_recovery_report()`, so a lifecycle owner can verify the reset
without gaining presentation or damage authority.

Deferred damage records capture the model generation, its private operation
sequence/revision, and the physical opponent's activation generation alongside
the external presentation receipt. Commit removes and rejects a record when
any fence is stale or its receipt sequence does not match its storage key. The
session-monotonic combat receipt remains externally owned; these local fences
only prevent a delayed prior-life callback or corrupted queued record from
spawning smoke, sparks, or destruction effects after reuse.

`maximum_health` is captured once after scene properties are authored. A later
property drift rejects damage and `activate_with_result()` returns
`maximum_health_drift` before reset, collision, visibility, or spawn state can
partially change. `activate()` returns the same detached result, and each current
opponent subclass stops its registration and tactical activation work when that
result rejects. Existing valid callers may ignore the result. The lifecycle
damage proxy reads the model-backed maximum rather than the mutable authored
property, so rejected drift cannot split resolver reporting from hull state.

As an explicitly tested migration hardening, non-finite damage and finite damage
below the current health value's representable precision are atomic no-effect
rejections. The old direct method could emit presentation and a health signal
without a representable health change, and could treat positive infinity as
lethal; the shared model rejects both. The live resolver already rejected
non-finite damage before reaching `RangeOpponent`.

Collision, active state, source registration/retirement, resolver acceptance,
mission/activity observation, health/destruction signals, deferred receipt
storage, world-space VFX, debris, and audio remain with their existing owners.
The adapter exposes detached state evidence only and does not add repair,
shields, per-part failure, handling penalties, score, save, or network policy.
