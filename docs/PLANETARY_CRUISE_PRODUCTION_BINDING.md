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
`GameFlow.disengage_planetary_cruise(brake_to_stop)` remain the only production
request seams. The existing pause navigation has one controller-focusable
`EMBER CRUISE` toggle that emits a typed monotonic request serial; it adds no
`InputMap` action and reads no raw `Input`. `GameFlow` synchronously rechecks
the live report and gates before calling engage or `disengage(true)`, while
replayed or skipped serials cannot toggle twice. There is no automatic engage.
Engage requires the exact live, piloted active ship in departed free flight, no
landing request/assist, no live combat, no recovery, no running activity, and
no pending origin transaction.

The HUD receives presentation only. Its exact detached state vocabulary is
`READY — EMBER MOON`, `QUEUED`, `ACCELERATING`, `CRUISING`,
`BRAKING TO SPEED`, `BRAKING`, or `UNAVAILABLE — <bounded public gate>`.
Internal controller, proof, generation, and transaction reasons are not shown.
The fixed destination remains Ember's canonical navigation anchor; this slice
adds no destination selection, return target, surface transition, movement,
sampling, policy, or origin authority. Whole-`Main` re-entry retains the same
HUD and binding identities but never restores an engagement: a fresh player
request is required.

The binding owns exactly one stable `PlanetaryCruisePhysicalController` child.
The controller asks `HeroShip` for its current fixed-orientation, full-hull
750 km swept-clearance proof, evaluates the existing pure policy, and submits a
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
