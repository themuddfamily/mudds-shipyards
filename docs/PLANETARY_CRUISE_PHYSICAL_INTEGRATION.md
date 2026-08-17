# Planetary cruise physical integration

Status: standalone production-compatible foundation. It is not wired to Main,
GameFlow, HUD, or InputMap and does not make Ember reachable by itself.

## Ownership

`PlanetaryCruisePhysicalController` is caller-driven. It binds one live
`HeroShip` lifecycle generation and one positive coordinate-frame generation,
requests a physical clearance proof from that ship, evaluates
`PlanetaryCruisePolicy`, and submits one detached envelope. It has no process or
physics callback and never writes a transform or velocity, reparents a node,
teleports, or invokes `move_and_slide()`.

`HeroShip` remains the only velocity and `CharacterBody3D.move_and_slide()`
owner. Its existing physics callback consumes at most one fresh envelope before
ordinary flight. A cruise tick and a standard-flight tick are mutually
exclusive. The physical basis is preserved while cruise is active; cruise does
not rotate the craft. Manual propulsion, steering, hover, brake, landing, fire,
or barrel-roll command intent retires cruise before ordinary flight consumes
that same immutable `ShipCommand`. Camera-only input does not interrupt or wake
cruise.

## Physical proof

The proof uses every enabled, non-null direct `CollisionShape3D` child owned by
the real `HeroShip` body. For each shape it freezes the current global transform
(therefore the current orientation), uses the normalized ship-to-destination
direction, the complete requested sweep distance, the ship collision mask,
physics bodies only, zero query margin, and excludes only the ship body RID.
An initial `intersect_shape` closes the overlap boundary; `cast_motion` supplies
the collision-free prefix; a final intersection closes the exact sweep endpoint.
The proof is accepted only when every enabled root shape was queried. It records
the exact coordinate-frame generation and cannot be reused by another ship or
attachment lifecycle.

Each successful query mints a monotonically increasing, one-use HeroShip proof
sequence and caches a detached copy inside that ship. A newer query invalidates
the prior capability and any not-yet-consumed envelope minted from it, including
when the newer request is malformed. Submission
must echo the exact ship/controller/lifecycle/frame identity, direction, hull
roster and transforms, collision mask, physical speed/alignment sample, swept
distance, clearance, and flags. HeroShip consumes the cached capability only
after a valid submission. Asserted `full_hull` or `obstacle` booleans without the
matching ship-minted proof are rejected.

The standalone controller requests `min(destination distance, 750,000 m)` as
its exact physical corridor. This conservative horizon exceeds the pure
policy's 731,666.67 m zero-speed engagement requirement. If current-speed
braking needs more clearance, the policy rejects participation rather than
inventing a longer proof. Destination distance remains a separate caller
observation and must be at least the proved corridor.

The controller performs no independent ray or obstacle inference. The pure
policy still owns no collision query. A later production caller must supply the
current post-origin-rebase frame generation; changing frames requires a fresh
binding and proof.

## Envelope and cadence

Envelope schema version 1 freezes ship instance and attachment generation,
controller instance and generation, monotonically increasing sequence,
coordinate/proof generation and proof sequence, normalized direction, the exact
policy observation, policy speed and
acceleration hints, braking hint, policy reason, and the full-hull/obstacle
result. `HeroShip` validates the exact schema before queueing it. Queueing does
not change velocity or position.

HeroShip independently re-evaluates `PlanetaryCruisePolicy` over the submitted
observation and requires every desired-state, 20,000 m/s speed, +500 m/s²
acceleration, zero hold, or -750 m/s² brake-to-target field to match the policy
result exactly. The observation's physical fields must match the one-use proof.
This closes forged 100,000 m/s or 10,000 m/s² envelopes without transferring
movement authority to the controller. Legitimate overspeed is a participating
`braking_to_speed` mode that approaches 20,000 m/s at 750 m/s²; it is distinct
from disengagement braking to zero.

Participation requires one new proof-bearing envelope before every HeroShip
physics tick. A missing/stale/duplicate/malformed envelope, controller loss, or
coordinate-generation rollback cannot continue cruise. An active ship begins a
HeroShip-owned 750 m/s² brake when fresh cadence is lost. Explicit disengagement
uses the same bounded brake. Braking clamps at zero and never reverses velocity.
Any physical slide collision retires cruise in the same HeroShip tick.

The cruise target remains the pure policy's 20,000 m/s, with 500 m/s² bounded
acceleration and 750 m/s² braking. Those values only become velocity changes
inside HeroShip. This foundation does not establish that a production route is
clear; each live tick must prove it.

## Lifecycle

The HeroShip attachment generation advances and all pending/active state is
retired on pilot authority changes, landing start/completion/abort, destruction,
explicit reuse reset, manual flight takeover, controller loss, ship tree detach,
collision, and completed braking. Whole-tree detach therefore freezes physics
but deliberately requires a new controller binding and fresh proof after
re-entry. Old envelopes remain rejected by their captured generation.

## Authority boundary

The controller's common authority roster is exactly false for renderer,
gameplay, streaming, save, network, physics, world generation, terrain
generation, collision generation, origin shift, weather clock, and audio. It
does own bounded policy evaluation, requests to HeroShip's collision-proof API,
and intent submission. It owns no input sampling, movement, velocity write,
landing or combat decision.

HeroShip already owns physical flight, collision response, damage, and automatic
engine behavior. This slice extends that existing authority rather than creating
a second mover. There is no activity, reward, cargo, landing, streaming, save,
network, or UI integration here.

## Remaining production work

A later Main/GameFlow owner must decide when the player requests cruise, provide
the post-rebase destination and exact coordinate-frame generation, supply the
existing combat/landing/pilot gates, call the controller once per physics tick,
and present state. It must not add another actor sample or movement path.
