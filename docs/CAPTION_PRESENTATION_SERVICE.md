# Caption presentation service foundation

`CaptionPresentationEvent` and `CaptionPresentationService` provide a typed,
presentation-only seam for future captions and subtitles. This foundation is
not wired into HUD, GameFlow or an audio director. It grants no gameplay,
activity, reward, ship, berth, save or network authority and does not select,
play or synchronize audio.

## Input and limits

Callers construct a typed event with a stable lowercase ID, one of the four
categories (`dialogue`, `radio`, `system`, `ambient`), speaker, text, physics
duration and integer priority. The service validates again and copies scalar
fields on enqueue.

| Field or store | Exact limit |
| --- | ---: |
| Stable ID | 1–64 characters; lowercase ASCII, digits, `_`, `-`, `.`, `:` |
| Speaker | 1–64 characters, nonblank, no NUL |
| Text | 1–512 characters, nonblank, no NUL |
| Caller physics duration | 0.1–30.0 seconds, finite |
| Priority | 0–100 inclusive |
| Active plus pending captions | 8 |
| Accepted-ID replay ledger | 1,024 per reset generation |

The replay ledger never evicts an accepted ID. Once its exact bound is reached,
new unique events reject with `dedupe_ledger_full`; replay protection is never
silently weakened. An explicit `reset()` opens a new generation and clears the
ledger.

## Queue and timing policy

The active caption is non-preemptive. Pending captions sort by priority
descending, then accepted sequence ascending (FIFO for equal priority). When
all eight storage slots are occupied, a newcomer is accepted only if it has
strictly higher priority than the lowest pending priority. It replaces the
newest item at that lowest priority; the active item is never an overflow
victim. The replaced ID remains in the replay ledger.

`advance_physics(delta)` is the only clock. Negative or non-finite delta
rejects; exactly zero is a successful freeze that changes neither state nor
revision. Positive caller physics time consumes the active duration, promotes
the already-sorted pending queue, and can expire multiple captions in one call.
Unused delta is not banked after the queue becomes idle. Tests freeze identical
expiration outcomes at 30, 60 and 120 Hz.

## Presentation and lifecycle boundary

`captions_enabled=false` hides the consumer-facing caption but does not pause
its caller-physics lifetime, preventing stale replay when captions are enabled
again. `reduced_flash=true` publishes `steady_no_flash`; otherwise the service
publishes `consumer_standard`. These are presentation instructions, not an
animation implementation.

State and presentation snapshots contain only deeply detached scalar data.
They can be retained across a consumer detach, inspected or mutated without
changing the service. Reset clears active, pending and replay content while
preserving the two accessibility flags.

Every successful state mutation commits the complete state and increments its
revision before emitting `state_committed`. All mutation entry points reject
with `reentrant_call` during that signal. Rejections, zero delta and unchanged
flags emit nothing. The deterministic audit repeats the exact limits, policies,
sorted accepted IDs, detached state and explicit authority denials.

Run the focused contract only:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/caption_presentation_service_test.gd
```
