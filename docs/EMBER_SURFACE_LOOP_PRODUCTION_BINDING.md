# Ember Surface Loop Production Binding Foundation

Status: `NEW`, modern interpretation, standalone and not instanced by `Main`.

`EmberSurfaceLoopProductionBinding` is the caller/physics scheduling seam for an
already composed and bound `EmberSurfaceLoopHost`. It deliberately does not
make the Ember surface loop production-reachable yet. A later Main/GameFlow
owner still has to compose the Host, surface berth and this binding, retire
cruise, choose the authoritative ship/on-foot focus, and pass the one shared
production observation.

## Two-phase contract

The future caller runs at physics priority `-100`. Arrow and the standing Player
run at priority `0`; the seated or moving-frame Player may run at priority `1`.
This binding is fixed at priority `2`.

At the early boundary, `prepare_early_tick` accepts exactly one non-wrapping
monotonic serial, a finite caller physics delta in `[0, 0.25]` seconds, the final
adjusted four-field actor sample, the exact result returned by the live
`CommonWorldOriginRebaseOwner`, and current coordinate-frame and streamed
location generations. It never samples an actor or streaming service. A
`rebase_committed` result is accepted only when its receipt equals the live
owner's current `last_receipt`; the binding synchronously calls the Host's
validated adoption seam before any priority-0 actor can move. A
`no_rebase_required` result must freeze the same sample and already-adopted Host
frame generation.

Only a detached envelope crosses to the priority-2 callback. The envelope
freezes `Engine.get_physics_frames()` and can be consumed only in that exact
physics frame; an idle-time or previous-frame envelope fails closed before it
can be accounted as a Host advance. After that exact-frame and monotonic serial
fence, one late-consume record is committed and every remaining late branch uses
that one record. An idle Host is started but not advanced in the same callback.
Consequently, the HeroShip has already sampled its prior command in caller
serial `S`; a command installed at late `S` is visible no earlier than Hero tick
`S+1`. Later envelopes advance the Host once after real actor physics. Completion
calls the Host's atomic runtime-ownership return once, stores its detached
receipt, and exposes it once to the future caller through
`take_completion_handback`. The relay validates the exact 17-field Host receipt,
including Host/actor IDs, retired/current attachment generations, retained
Player reservation, restored command source, detached values and
`host_attached=false`, before publishing it.

The future caller can pair one pending early envelope with one typed monotonic
intent through `queue_disembark_intent`, `queue_reboard_intent`, or
`queue_takeoff_intent`; their phases are fixed respectively at `LANDED`,
`ON_FOOT`, and `REBOARDED`. Queueing itself rejects a frame that no longer
matches the prepared envelope. The priority-2 callback rechecks the exact Host generation,
attachment, phase, caller serial and physics frame, then invokes the matching
public Host request once before that envelope's advance. Replays, skips and
out-of-order intent phases are state preserving.

The lifecycle is `IDLE -> START_PENDING -> RUNNING -> HANDOFF_PENDING`, with
`FAILED` as fail-closed terminal state. There is one pending envelope. Replays,
skips, overflow, stale frame/location/Host identities, replacements and queued
or detached dependencies are rejected. Detaching the binding discards an
unconsumed envelope so whole-tree re-entry cannot replay an old early sample.

## Authority boundary

The binding owns only the monotonic caller fence, detached pending evidence,
priority-2 Host lifecycle forwarding, immediate invocation of the Host's
committed-origin adoption validator, and detached completion handback relay.

It has no actor or streaming resampling; origin request, apply or commit;
movement, velocity, teleport or reparenting; command-source mutation outside the
Host; berth, seat or boarding-reservation mutation outside the Host; landing,
collision, gravity or session policy; input, cruise, activity, combat, reward,
save, UI, network or world-generation authority. `EmberSurfaceLoopHost` remains
the bounded lifecycle/command composer, existing actor classes remain the only
physical movers, and `CommonWorldOriginRebaseOwner` remains the only origin
transaction authority.

No destination choice, return-to-station route, production GameFlow handoff, or
surface visitability claim is made by this standalone foundation.
