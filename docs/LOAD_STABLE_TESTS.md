# Writing load-stable suites

This machine is shared. A suite runs with anything between one and two dozen
other jobs on the box, and three suites used to fail only in that condition -
`network_moving_interior_publication_test`,
`network_remote_body_simulation_test` and `lifecycle_phantom_geometry_test`.
None of them had found a production defect; all three had measured a different
window than the one they said they measured. This is how to not write the
fourth one.

## The mechanism

A test coroutine advances the simulation like this:

```gdscript
for _round in 120:
    await physics_frame
    await process_frame
```

On an idle machine that is 120 physics ticks, because one tick runs per
rendered frame. On a loaded machine the engine catches up: when a frame takes
longer than the physics tick, the next frame runs several steps to keep the
simulation on real time, up to `Engine.max_physics_steps_per_frame` (8 by
default). One awaited round is then *up to eight ticks*, and nothing in the
loop can tell.

Everything that follows from that is the same bug wearing different clothes:

* **A window that is longer than it says.** `lifecycle_phantom_geometry_test`
  sampled light energy once per awaited round for 120 rounds and divided the
  turning-point count by "two seconds". Under load the 120 rounds spanned four
  to five seconds, so the yard's authored 0.605 Hz ambient pulse
  (`sin(_elapsed * 3.8)` in `ShipyardWorld._animate_warning_lights`) was
  reported at 1.25-1.50 Hz and failed the reduced-flash contract, with nothing
  at all wrong in the scene.
* **A cadence measured against the wrong clock.** The host in
  `network_moving_interior_publication_test` re-states a secured occupant's
  pose every `MOVING_INTERIOR_SECURED_KEEPALIVE_TICKS` server ticks. ENet is
  polled once per rendered frame, so when the server runs eight ticks in one
  frame it emits eight ticks of snapshots against one client poll and the
  replica the suite samples is legitimately several ticks stale.
* **A per-round nudge that should be per tick.** The same suite flies the
  Halyard one step of a turning arc per driven round. Fewer, longer rounds
  means fewer steps of arc for the same walk, and "the body is carried by the
  cabin, not left behind in world space" measures the arc.
* **A server-side rule measured through a socket.** The same suite asked how
  far behind the host's live tick a client's copy of the seat pose was. Both
  peers are on loopback ENet in one process, and ENet throttles a peer's
  reliable send rate from its own round-trip measurements; under load those
  spike, the throttle closes, and the whole stream queues. One recorded run had
  the client twenty-two ticks behind the host for the entire window with the
  ordering buffer rejecting nothing - a measurement of the socket, not of the
  host's keep-alive cadence.
* **An instantaneous sample of a transient.** `CharacterBody3D.is_on_floor()`
  is a property of the last `move_and_slide()`. A body standing on a deck that
  is itself translating reports `false` for the odd tick while the capsule
  re-seats, and load decides which tick that is.

## Three patterns that work

1. **Sample where the ticks are.** Put per-tick work in `_physics_process` on a
   small driver node with a high `process_physics_priority`, and let the
   awaited loop only wait for the count to be reached. See
   `RestWindowSampler` in `tests/lifecycle_phantom_geometry_test.gd` and
   `TickDriver` in `tests/network_remote_body_simulation_test.gd`. This is the
   cheapest fix: it costs no wall-clock time, because the catch-up ticks were
   going to run anyway.
2. **Size every budget from what was measured, never from the loop counter.**
   `Engine.get_physics_frames()` is the authoritative tick count, the
   authority's own tick counter is the authoritative server tick, and
   `Engine.physics_ticks_per_second` converts either to seconds. A window is
   `ticks_sampled / physics_ticks_per_second`, not the constant the loop was
   written around.
3. **Pin the cadence when the point *is* the cadence.** When a suite is
   asserting something about sends, polls and ticks lining up - a keep-alive
   interval, an intent stream, an interpolation horizon - use
   `tests/fixed_physics_cadence.gd`: `_cadence.pin()` sets
   `Engine.max_physics_steps_per_frame = 1` so one awaited round is exactly one
   tick and one poll, and `_cadence.restore()` puts the engine back. The
   simulation then runs behind wall-clock under load instead of bunching, which
   is the right trade for a suite that counts ticks - the shared
   `_wait_until()` helpers spend a tick budget *and* a wall-clock budget before
   giving up, so a slower-than-real-time simulation cannot time them out. Pin
   the narrowest scope that needs it; a suite with a long drive between short
   measured windows should not pay for the pin during the drive.

Alongside those: **measure a rule where the rule is decided.** A cadence the
host keeps is a fact about the host. Measuring it as "how stale is the client's
copy" silently adds the transport, and the transport is load-dependent. Measure
it against something that travelled the same path - in the publication suite,
how far the seat's pose has fallen behind the freshest packet the client has
received from that same host - so a shared delay cancels out and only the thing
being asserted is left.

And: **wait on a predicate, not on a fixed sleep**, and make the
predicate the state you actually mean. "The body stopped" has to exclude "the
body froze because its intent stream stalled", or a delivery gap satisfies it.
Give the wait a generous bounded budget and report how much of the budget it
used, so the margin is visible in the passing log and not only in the failure.

## Two patterns that do not

1. **Widening the tolerance.** Raising a bound until the failure stops is how a
   suite ends up unable to see the defect it was written for. If a value moves
   under load, the window it was measured in moved - fix the window. The
   flash-rate contract stayed at the authored
   `AUTHORED_AMBIENT_FLASH_HZ + FLASH_RATE_RESOLUTION_HZ`; only the divisor was
   corrected.
2. **Making the flake someone else's problem.** Marking the suite graphical,
   dropping it from the matrix, skipping the assertion, adding a retry, or
   pinning the whole run to `--jobs 1` all remove the signal instead of the
   race. A suite that cannot survive a loaded machine cannot be trusted on a
   quiet one either; it was measuring the machine, not the game.

## Checklist for a new suite

* Does any assertion count awaited rounds as ticks or as seconds? Measure
  instead.
* Does any per-round side effect (moving a hull, streaming an intent, holding a
  pose) belong on the physics tick? Move it to a driver node.
* Does any assertion read a one-tick boolean (`is_on_floor()`, "is the tween
  finished", "has the packet arrived")? Make it a bounded predicate wait, and
  put the measured margin in the assertion text.
* Does the suite need send/poll/tick alignment? Pin with
  `tests/fixed_physics_cadence.gd` and restore.
* Before calling it done, run it at least eight times: three on a quiet machine
  and five against deliberate load (`tools/run_affected_suites.sh --jobs 6`
  over a batch of unrelated suites, in parallel with the run under test), and
  report the worst measured value in both conditions.
