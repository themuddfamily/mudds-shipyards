# Planetary cruise production binding

`PlanetaryCruiseProductionBinding` is the caller-driven production composition
between `GameFlow`, one `PlanetaryCruisePhysicalController`, and the active
`HeroShip`. It does not add a second movement, policy, collision-query, input,
streaming, or origin authority.

## Production order and destination

`Main` has physics priority `-100`, before every production `HeroShip`. Each
physics tick has one ordered observation path:

1. `GameFlow` captures its existing single ship-or-player actor sample.
2. `EmberMoonStreamingProductionBinding` converts that sample to the absolute
   orbital frame and updates streaming.
3. `CommonWorldOriginRebaseOwner` may commit one common-world translation. On
   success, its adjusted actor sample and target frame generation replace the
   pre-rebase values. Before exposing that commit, the origin owner forces the
   exact covered `CollisionObject3D` roster to its translated Node3D transforms
   in `PhysicsServer3D`; this prevents both false obstacles from pre-translation
   bodies and false clears from pre-translation blockers in same-tick proofs.
4. `PlanetaryCruiseProductionBinding` receives only that adjusted sample and
   exact current generation. At most one proof-bearing envelope is queued for
   the next `HeroShip` physics callback.
5. Cinder and the existing activity consumers continue to receive the same
   adjusted sample. `HeroShip` later consumes the envelope and remains the sole
   writer of velocity and sole caller of `move_and_slide()`.

The binding validates the checked-in Ember `WorldLocationDefinition` and
encodes its navigation anchor, body-local `(0, 130000, 0)`, once as the absolute
orbital coordinate `(cell 0,0,-8; offset 0,130000,0)`. Only that detached
absolute value is retained. Every caller tick decodes it again through the exact
current `PlanetaryCoordinateFrame`; no pre-rebase local destination survives a
frame change.

## API and lifecycle

`GameFlow.engage_planetary_cruise()` and
`GameFlow.disengage_planetary_cruise(brake_to_stop)` remain the detached request
seams for cruise itself. The player-facing destination seam is the pause
navigation's one controller-focusable `EMBER CRUISE` toggle, mirrored by the
Destination Board's `LAUNCH EXPEDITION` row for the same `ember_moon` route;
both emit the same typed monotonic request serial, add no `InputMap` action and
read no raw `Input`. `GameFlow` synchronously rechecks the live report and gates
before acting, while replayed or skipped serials cannot toggle twice. There is
no automatic engage. Admission requires the exact live, piloted active ship in
departed free flight, no landing request/assist, no live combat, no recovery, no
running activity, and no pending origin transaction.

A press on a ready row starts the complete retained expedition through
`GameFlow.begin_ember_surface_journey()` — the surface `Host`, the
`ActivityDirector`, the reward authority, the streaming binding and this cruise
binding, not a detached flight demo — and publishes the standing
`EMBER EXPEDITION` objective plus the first-time activity briefing card for
`ember_beacon_survey` on the same channel every other activity uses. A press
while an expedition is live abandons it through
`GameFlow.abandon_ember_surface_journey()`; the rule that seam implements is
documented on `PlanetaryJourneyCoordinator.abandon_ember_surface_journey()` and
in `EMBER_SURFACE_LOOP_HOST.md`. Refusals surface through the existing
`EMBER CRUISE UNAVAILABLE` toast and its bounded public gate vocabulary.

An abandoned expedition's way home is this binding's Mudds return approach, armed
directly rather than through the completed loop's station-return contract, which
an abandoned visit never earned. Its completion hands the last leg to the
ordinary registered-berth landing lifecycle with no physical-arrival receipt.

The HUD receives presentation only. Its exact detached state vocabulary is
`READY — EMBER MOON`, `QUEUED`, `ACCELERATING`, `CRUISING`,
`BRAKING TO SPEED`, `BRAKING`, or `UNAVAILABLE — <bounded public gate>`.
Internal controller, proof, generation, and transaction reasons are not shown.
The fixed destination remains Ember's canonical navigation anchor; this slice
adds no destination selection or origin authority. Whole-`Main` re-entry
retains the same HUD and binding identities and never restores an engagement
by itself; the retained coordinator re-requests a transit leg it still owns
(see "Transit ownership").

The binding owns exactly one stable `PlanetaryCruisePhysicalController` child.
The controller asks `HeroShip` for its current fixed-orientation, full-hull
1,250 km swept-clearance proof, evaluates the existing pure policy, and submits a
detached envelope. One monotonic GameFlow caller-tick serial prevents duplicate
or replayed cadence. Reaching the maximum safe integer retires the request and
never wraps or reuses `MAX`; binding generations reject engagement at `MAX-1`
so the final serial always remains available for an accepted request's atomic
retirement.

An exact frame `N -> N+1` change performs a no-brake controller disengage,
clears the old envelope, rebinds the same ship/controller at `N+1`, re-decodes
the absolute destination, and evaluates freshly in the same pre-Hero tick.
Stale or skipped generations fail closed. A rejected/cancelled rebase does not
change the frame and therefore does not trigger a rebind.

`HeroShip` can independently advance its attachment generation on unpilot,
landing, destruction, collision, reset, detach, manual command, or missing
cadence. `reconcile_retired_ship_binding()` proves the old attachment is no
longer current and clears only the controller-local record. It never retries a
ship mutation, moves the hull, or creates a replacement controller. A later
explicit request can bind the same controller identity freshly.

The production binding holds one mutation guard across every synchronous
controller bind, proof/evaluation submission, disengage, and reconciliation.
Callbacks from controller or HeroShip signals can inspect the already committed
state but receive `reentrant_call` from every mutation API. Retirement commits
only after the controller is proven detached or reconciled; a rejected release
leaves the prior binding identity/generation intact and returns structured red.
Freed, queued, or reparented controller identities are never dereferenced by
snapshot/audit paths.

Whole-`Main` detach retires any request and all pending envelopes. Re-entry
preserves the same binding/controller identities and creates no duplicate; a
new explicit engage is required.

## Transit ownership: flying the legs

The binding is also the production movement owner for the outbound Ember leg.
An engagement may carry one *transit leg* (`request_engage(..., transit_leg)`):
`ember_outbound`. A legacy engagement with no leg behaves exactly as before,
and the Mudds return approach still uses that legacy engagement. With a leg, every caller tick
hands the controller one detached *guidance* record alongside the destination:

- **Cruise mode** (far from the approach point): the existing long-leg policy,
  plus an attitude the hull should face (the heading). The policy's
  `attitude_authority` observation key turns a refused alignment into the
  `transit_aligning` state — participation held at the current speed while the
  controller slews the hull at `TRANSIT_ATTITUDE_TURN_RATE` and carries the
  velocity through the same rotation — so a craft launched off its berth turns
  onto the leg by itself instead of the pilot having to aim it.
- **Approach mode** (an approach point inside the activation distance, or an
  armed target the long leg can no longer engage): the same pure policy's
  short-leg profile, selected by a positive `approach_speed_limit` observation
  key. Speed follows `min(limit, sqrt(2·8,000·d))` toward the point, brakes to
  rest inside the 40 m terminal distance and then holds at zero speed so the
  attitude slew can finish; the existing entry/shell measurement then accepts
  the arrival exactly as before. Because `HeroShip` re-evaluates the policy on
  every envelope, both modes are pure functions of the observation.
- **Attitude**: the controller submits one `submit_planetary_cruise_attitude()`
  command per envelope; `HeroShip` applies the bounded slew in its own physics
  tick and discards it with the envelope. Any manual flight command still
  retires the cruise, which is how the pilot takes the craft back.

One transit tuning set lives in `PlanetaryCruisePolicy`
(`ember_eight_megameter_transit_v2`): 90 km/s cruise, 10 km/s² acceleration
and braking, 0.5 s brake response, 25 km fixed margin, a 1,250 km clearance
horizon in the controller. An 8,000 km leg is ~98 s of simulated flight; the
minimum engage distance (braking envelope plus acceleration distance) is
880 km, inside the swept horizon. `GameFlow` derives the Mudds return corridor
length and brake shell (25–70 km) from the same constants.

**Rebases.** A committed common-world rebase is a coordinate change, not a
disengage. `PlanetaryJourneyCoordinator` announces each commit to the binding
(`accept_committed_origin_rebase(receipt)`), which re-expresses its frozen
transforms — the armed target through the controller's
`translate_approach_target()`, the return home target, the landing-root drift
snapshot — and the next caller tick carries the attachment into
generation N+1 through `controller.rebind_coordinate_frame()` /
`HeroShip.retarget_planetary_cruise_coordinate_frame()`: same attachment, same
velocity, same participation, fresh proof in the new frame. An 8,000 km leg
crosses its ~750–800 ten-kilometre rebases without ever losing the cruise. A
frame that moves under an armed target *without* that announcement still
fails closed (`final_approach_rebase_aborted`). An attached, idle
`EmberSurfaceLoopHost` adopts the same commits so its frame fence stays
current while the craft flies the last ~200 km to the armed approach.

**Outbound route.** `begin_ember_surface_journey()` engages `ember_outbound`.
The long leg cruises at the anchor; its brake-shell decision is the planned
standoff stop 70 km short of the navigation anchor, flown attached
(`transit_standoff_braking_submitted`) rather than released. Ember has streamed
in by then, the Host binds, the pending expedition forwards and arms the
final approach; the approach profile then flies the ~80 km into the authored
corridor entry, the existing arrival measurement completes it and the surface
Host takes over. Whenever the cruise is released while the expedition is
still wanted — a manual command, an obstacle, a whole-`Main` re-entry — the
coordinator asks for the leg again on the next clean tick
(`_resume_ember_outbound_transit()`); a pilot holding the controls keeps
them and releasing them resumes the leg. A whole-`Main` re-entry mid-leg is
the safe abort: the pending expedition is cancelled with the rest of the
retained state, nothing re-engages by itself, and the pilot has the craft under
manual control where they are until they open a fresh expedition.

**Return leg.** Not flown yet. The return approach is armed exactly as before
(a legacy engagement with the brake-complete shell, now derived from the
transit tuning), so a craft cruising home under manual alignment still gets the
existing shell completion and yard handoff; a climb-out out of the caldera and
yard legs into the registered berth were prototyped and removed unproven
(`EMBER_LOOP_SOAK.md`, "Remaining gaps"). `GameFlow.get_planetary_transit_progress()`
exposes the outbound leg's mode, distance to the current point and speed for
presentation.

## Authority boundary

The binding's exact common authority roster is false for renderer, gameplay,
streaming, save, network, physics, world generation, terrain generation,
collision generation, origin shift, weather clock, and audio. It owns only the
explicit request lifecycle, absolute-destination decoding, controller binding,
and once-per-caller-tick delivery cadence. Combat, landing, piloting, activity,
ship destruction, frame generation, streaming generations, and movement remain
observed external authorities.

The focused production tests freeze singular composition, ordering, canonical
destination identity, one-sample/one-envelope delivery, next-Hero-tick physical
consumption, an exact frame rebind with no stale-broadphase false obstacle, a
second rebase with a translated blocker that cannot become a stale false clear,
combat/lifecycle/replacement failure, stale-controller reconciliation, detached
reports, and whole-Main re-entry. Player-activation evidence additionally drives
the existing pause/controller focus route, the typed request serial, all exact
HUD states and bounded gate copy, braking disengage, layout endpoints, and
re-entry without ghost engagement.
