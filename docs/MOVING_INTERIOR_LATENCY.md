# Moving-interior stability under latency

Phase 7 gate: measure what the moving-interior relationship stream does to a
walking crew member when the transport is slow, jittery, re-ordered, lossy or
stalled, before player counts are broadened.

The regression is `tests/network_moving_interior_latency_test.gd`. It runs
`res://scenes/main.tscn` on the server side — so the moving frame is the
production `HalyardCrewTransport` with its own `MovingInteriorFrame` and
published `INTERIOR_BOUNDS`, and the server's own player is the production
`PlayerController` — and connects one server plus two clients over real
loopback ENet, each on its own `SceneMultiplayer` branch. Seat claims,
transfers, occupancy, publication, budget framing, the per-recipient ordering
buffer, the relationship stream and the replica are all production scripts.

The suite is named `network_*` on purpose. `tools/release/run_test_matrix.sh`
marks a suite as a network suite when its path is `tests/network/*` or
`tests/network_*`, and only marked suites take the per-run flock lane; this one
opens real ENet sockets, so it has to take that lane. (The existing
`tests/network/moving_interior_latency_test.gd` is a different, data-only
regression over `NetworkMovingInteriorLatencyValidator` and is unchanged.)

## The transport shim

There was no send/receive seam on the relationship stream, so one was added:
`NetworkEnetSessionAdapter.set_moving_interior_transport_hook()`. In production
the hook is unset and every relationship packet goes straight to the authority
RPC, costing one `Callable.is_null()` per published packet. When a harness
installs it, the hook receives `(peer_id, wire)` for relationship snapshots and
for their release tombstones only, and hands each survivor back through
`deliver_moving_interior_wire_packet()`, which calls the same authority RPC.
The hook can only decide *when*, or *whether*, a packet the server already
published reaches a peer. It is not an authority seam: it cannot create, edit or
accept a relationship, and no other stream is routed through it. The shim itself
lives in the test and runs on a simulated 60 Hz clock, so the profiles do not
depend on how fast the host machine is.

## What the sweep drives

One continuous 570-tick leg. The Halyard flies a real arc — it translates and
yaws every tick, so a frame-local pose that never changes still traces a curve
through the world:

* client A claims the Halyard pilot seat, tied to one moving-interior frame
  generation;
* client B walks the cabin aisle at an ordinary 2.7 m/s, one 60 Hz step per
  published tick, while the pilot flies the turning leg;
* client B walks six metres of aisle to the production `ShipBunk`, sleeps in
  flight, and wakes;
* the pilot seat is transferred A → B and back, mid-leg;
* client B drops mid-leg and reconnects;
* the whole Main subtree is detached and re-entered on the server;
* client A finally disconnects while still holding its seat.

## Profiles and measurements

`max_presentation_lag` is how far the pose a client is drawing trails the live
authoritative pose — the visible cost of latency. `max_reconstruction` is the
error against the authoritative pose *for the tick that sample carries*.
`max_extrapolation` is how far the replica sampler runs ahead of its newest
accepted sample.

| profile | one-way | jitter | loss | stall | delivered / published | re-ordered arrivals | max presentation lag | max reconstruction | max extrapolation | max step | teleports |
|---|---|---|---|---|---|---|---|---|---|---|---|
| clean | 0 ms | – | – | – | 240 / 240 | 0 | 0.000 m | 0.000 m | 0.000 m | 0.045 m | 0 |
| lan | 80 ms | ±20 ms | – | – | 720 / 720 | 294 | 0.270 m | 0.000 m | 0.270 m | 0.315 m | 0 |
| regional | 200 ms | ±60 ms | – | – | 360 / 360 | 245 | 0.720 m | 0.000 m | 0.675 m | 0.090 m | 0 |
| intercontinental | 350 ms | ±120 ms | 2 % | – | 316 / 361 | 235 | 1.771 m | 0.000 m | 0.675 m | 1.620 m | 0 |
| stall | 80 ms | ±20 ms | – | 1.5 s | 240 / 600 | 100 | 2.851 m | 0.000 m | 0.675 m | 1.366 m | 0 |

Documented bounds, all asserted per profile:

* **Reconstruction is exact.** The wire carries the pose in the cabin's own
  coordinates, so transport disorder costs lag, never distortion. Measured
  0.000 m on every profile against a 0.0005 m tolerance.
* **Extrapolation stops at the documented horizon.** The production replica is
  built as `MovingInteriorReplica.new(AUTHORITY_PEER_ID, 2, 0.0, 0.25, 8.0)`,
  and its timeline is real seconds (see *The replica timeline is seconds*
  below), so the horizon is 0.25 s of the published linear velocity:
  0.25 × 2.7 m/s = 0.675 m. Every profile whose lag exceeds a quarter of a
  second hits exactly that ceiling and none exceeds it; `lan`, at 80 ms, never
  owes the whole horizon and stops at the 0.270 m it actually does owe.
* **Teleport tolerance.** 8 m of frame-local displacement between accepted
  samples. The worst observed step was 1.62 m, at 350 ms with loss; the replica
  classified zero samples as teleports across the whole sweep.
* **Containment.** Every presented and every sampled pose, on both clients, was
  inside `INTERIOR_BOUNDS`, above the cabin floor plane, and inside the live
  frame volume via the frame's own `contains_world_position()`.
* **Ordering.** Neither client's migration generation nor its per-recipient
  ordering cursor ever regressed. 874 arrivals were re-ordered by the shim
  across the sweep; the per-recipient buffer repaired them, and the ones that
  arrived after their successor had already been released were rejected and
  counted as stale.
* **Freeze and resume.** The 1.5 s stall froze the stream (the relationship
  stream's `gap_hold`) and then resumed at the live server tick, with both
  occupants still tracked on both clients and no jump beyond tolerance.
* **The server's own player is unaffected** across the whole-Main re-entry, and
  the remote seat claim survives it.

## Defects found and fixed

**1. A delivery gap wider than the ordering window killed the stream for good.**
`NetworkSnapshotJitterBuffer` rejects a packet whose `server_tick` is more than
`MAX_TICK_GAP` (8) beyond the last released tick. It never advances past that,
so once a gap exceeded the window every later packet was rejected too. Reachable
without any packet loss at all: the per-recipient budget coalesces at 8
snapshots per 10-tick window, so a busy cabin already produces >8-tick holes in
one entity's tick sequence. Symptom: the other crew member in the Halyard cabin
freezes in place permanently after a stall, a lossy patch, or a busy moment, and
never recovers for the rest of the session. Fixed in
`consume_moving_interior_snapshot()`: a `snapshot_gap_too_large` rejection is
treated as a stream discontinuity and re-baselines that recipient's cursor onto
the first packet after the gap, counting it in `stall_rebaselines`. The
relationship stream then performs its documented freeze-then-resume on its own
tick gap. Witness: without the fix, `stall: the relationship stream freezes
across the stall`, `stall: client 0 still tracks both cabin occupants after the
stall` and `stall: the stream resumes at the live server tick once delivery
returns` all fail.

**2. A disconnected crewmate stayed on screen as a phantom.** The server simply
stopped publishing a dropped peer's relationships, and silence is not a release,
so every remaining client kept the last pose it had received. Symptom: a crew
member who drops mid-leg is drawn as a motionless body standing in the moving
cabin, on every other client, for the rest of the session. Fixed in
`_on_peer_disconnected()`: the entity ids released from `_seat_moving_relationships`
and from `NetworkMovingInteriorAuthority.release_peer()` are collected and an
explicit release is broadcast to the remaining admitted peers, which also clears
their per-recipient entity and pending bookkeeping. Witness: `the remaining
client stops drawing the crew member who left the cabin` and `the other client
stops drawing the pilot who disconnected`.

**3. A reconnecting client re-used its pre-disconnect replica state.**
`shutdown()` called `_reset_moving_interior_jitter()` with the *current*
migration generation, and the deep reset inside it only runs when the generation
strictly increases — so a teardown cleared nothing. The per-entity tick cursors
and the last received poses survived into the next session. Symptom: on
reconnect the cabin's other occupants are shown exactly where they stood when
the link dropped, and any entity whose server tick restarts lower is rejected as
stale for the rest of the session. Fixed by adding `clear_entities()` to
`NetworkMovingInteriorRelationshipStream` and `NetworkMovingInteriorReplica` —
which drop every tracked entity while *keeping* the migration cursor, because a
reconnect to the same host resumes on the same generation — and calling it from
`shutdown()`. Witness: `a torn-down client keeps no pre-disconnect pose to show
on reconnect`.

**4. The replica's sample history nested without bound.**
`NetworkMovingInteriorReplica.accept_snapshot()` stored `record["previous"] =
current.duplicate(true)`, embedding the whole previous record — including *its*
previous — inside the next one. Every accepted packet added a nesting level, so
each arriving relationship cost a deeper recursive copy than the last until
Godot's duplicate-recursion limit was hit. The unfixed sweep emits 1001
`Max recursion reached` errors in 570 ticks. Symptom: a long leg in a moving
cabin makes remote crew updates progressively more expensive, then hitch, then
stop. Fixed by carrying forward only the two fields the interpolator reads.
Witness: `client N keeps one predecessor per replica sample, not a chain of
them`.

## The replica timeline is seconds

`NetworkMovingInteriorReplica` interpolates on a **real-seconds** axis, and now
says so. A relationship on the wire carries a `server_tick`, not a timestamp, so
the conversion happens exactly once, at the single seam that records an arrival:
`NetworkEnetSessionAdapter._present_moving_interior_relationship()` calls
`moving_interior_tick_to_seconds()` (60 Hz,
`MOVING_INTERIOR_SERVER_TICK_RATE_HZ`). Nothing inside the replica knows about
ticks any more, and every `now_seconds` a caller hands to
`sample_moving_interior_replica()` or `apply_moving_interior_replica()` is on
that same axis — which is what lets the presenter below sample it from a render
clock.

Before the conversion the replica was fed raw tick numbers while its constants
were named seconds, so `_max_extrapolation_seconds = 0.25` clamped to a quarter
of a *tick* and then multiplied it by a velocity in metres per *second*. That
was self-consistent only because every reader used the same wrong unit. The
physical horizon is unchanged — 0.25 s × 2.7 m/s = **0.675 m**, the same ceiling
the table above measures — but it is now the horizon the constant claims, and
the `lan` profile's measured extrapolation dropped from a clamped 0.675 m to the
0.270 m its 80 ms of lag actually justifies.

## What a client draws

`NetworkMovingInteriorPresenter` is the production consumer. On a non-authority
peer it runs every rendered frame: it polls one int
(`get_moving_interior_presentation_entity_count()`), samples each tracked
relationship at its own render time, and lets
`NetworkMovingInteriorReplicaBinding` compose that frame-local pose with the
live `MovingInteriorFrame` transform onto one remote avatar node. The avatar is
the production pilot visual — the same imported Blender suit the local player
wears, falling back to the same generated recovery suit `PlayerController` falls
back to. A crew member walking the aisle of a Halyard in flight is therefore
drawn moving *with* the cabin, inside the cabin, on every other client.

Its render clock is the wall-clock seam: it anchors on the newest server tick
the adapter has released, converts that once through
`moving_interior_tick_to_seconds()`, and adds the real time elapsed since. That
sum is the sample time, so a pose advances smoothly between two arrivals instead
of stepping from packet to packet. The anchor is re-taken whenever the newest
tick *changes* rather than only when it advances, because a reconnect to the
same host resumes on the same migration generation with a server tick that may
restart lower; an anchor that only moved forward would sit permanently ahead of
every arrival and pin the replica at its horizon for the rest of the session.

GameFlow owns only the two things the presenter cannot know: which live node
each published `parent_frame_id` refers to (`frame_<ship_id>` → that craft, the
same node its own `MovingInteriorFrame` treats as the moving frame), and which
entity is this peer's own body, which is simulated locally and must never be
drawn twice. It attaches the presenter when a client session starts, restates
the frames after a whole-Main re-entry, and detaches it when the session stops.

Lifecycle, all asserted in `tests/network_moving_interior_presentation_test.gd`:
a release tombstone, a peer disconnect, a migration, a session stop and a
whole-Main re-entry each remove the avatar in the same frame and leave no orphan
node behind. Steady state costs nothing: with the tracked set unchanged the
presenter runs no reconcile, spawns no node and rebinds nothing — the suite
compares the audit counters across a 30-round steady leg.

**Accessibility.** The presenter reads `RuntimeSettings.reduced_motion` the way
the other presenters do and never owns it. With reduced motion on it samples at
the newest accepted arrival instead of running its render clock past it, so a
remote body follows the poses the server actually sent — a little behind —
rather than speculating forward and then correcting. The suite asserts both
halves: with the setting on the drawn pose is always an accepted pose, and with
it off the same leg at the same latency genuinely does run ahead.

**One change was needed outside the presenter.**
`NetworkMovingInteriorReplicaBinding` refused a `PhysicsBody3D` as the *frame*,
and every craft with a walkable moving interior is a `CharacterBody3D` — so it
refused every frame production actually has. The avatar is still refused,
because it is written to every frame; the frame is only ever read, and reading a
body's transform takes nothing away from the solver. The adapter also gained
`retire_moving_interior_occupancy()`: `publish_moving_interior_release()` tells
the other clients to stop drawing a crew member, but nothing retired the
authority's own occupancy record, so a released entity id stayed claimed and
could never be re-registered under a fresh generation.

## What remains before broadening player counts

* **The walking pose is still published by the suites, not by GameFlow.**
  `_publish_network_moving_interior_state()` publishes the seated pilot at the
  cabin origin; it does not yet publish a walking cabin occupant's live
  frame-local pose each tick. The presenter draws whatever the server publishes,
  and both suites drive the real walk through the production stream, but
  authority-side publication of an on-foot cabin occupant is the next step.
* **Per-recipient budget headroom.** The sweep deliberately advances a whole
  budget window per round so its own traffic is never coalesced. With more
  occupants the 8-snapshots/10-tick ceiling is the next thing to characterise —
  defect 1 shows coalescing is a real source of tick holes, not a theoretical
  one.
* **Two clients only.** This gate establishes the relationship stream's
  behaviour for one pilot and one walker. Interest management and the resync
  baseline under many occupants are untested at latency.
* **Loss is injected above ENet.** The relationship RPC is reliable, so the 2 %
  profile models loss on a path where retransmission does not save the packet.
  It is a stand-in for the gap sources that *are* reachable in production
  (coalescing, stalls), not a claim about ENet's own delivery.
* Native-hardware and human-review gates remain `NOT_RUN`.
