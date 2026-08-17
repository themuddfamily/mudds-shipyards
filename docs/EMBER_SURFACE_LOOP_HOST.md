# Ember surface loop host

`EmberSurfaceLoopHost` is a standalone, opt-in composition of the existing
Ember Moon contracts and real production actors. It is `NEW` / modern
interpretation work and makes no historical-behaviour claim.

The caller first performs the existing Ember body-centre rebase and streaming
load, then a second explicit common-origin transaction that places the live
landing tangent patch at local origin (coordinate-frame generation three in the
focused fixture). The bootstrap and its loaded root participate in that
transaction; the standalone fixture instantiates the berth overlay and actors
immediately afterward in the resulting frame. Unre-based CharacterBody contact
at 120 km is not claimed. It then supplies one exact loaded location generation,
the production `EmberMoonStreamingBootstrap`, an `EmberSurfaceBerth`, one real Arrow recon
ship, and the real `PlayerController`.

`bind_dependencies()` freezes one explicit composition root. Omitting the final
argument retains the standalone topology: the host itself is the root and all
four dependencies are its direct children. A later production composition may
supply `Main` instead; in that topology the host, bootstrap, berth, Arrow, and
Player must all be exact direct children of that same root. The host records the
root instance and checks that sibling topology for the full attachment. It
never reparents any of them.

The fixture may place the actors once inside the authored corridor and establish
the Player's public seated state. Start no longer depends on a synthetic exact
point, identity basis, or effectively-zero velocity. Instead the typed immutable
`ApproachEntryEnvelope` freezes `caldera_approach`, its target pad, the Arrow's
full collision bounds, and the current composition-root/loaded-root/frame/location
identities. It accepts a measured root position within `(42, 25, 75)` metres of
the corridor's declared `(0, 60, 300)` transform, at no more than `12 m/s` and
`12 degrees` from its oriented basis. Every transformed hull corner must also
remain inside the full authored `(45, 60, 300)` corridor with `0.05 m` margin.
These are a bounded subset and proof of the existing corridor, not new geometry.
The evaluator only reads the public ship transform and velocity.

The exact seated `ShipBoardingArea` reservation is transferred to the host at
successful bind, so every terminal path has one explicit cleanup owner.
After `start()`, neither the host nor its focused test writes an actor transform,
velocity, parent, collision state, or physics-processing state.

## Physical sequence

The host has no `_process()` or `_physics_process()`. Its caller invokes
`advance_physics()` once after each real actor physics tick with the same finite
delta (maximum 0.25 seconds).

1. After the measured entry proof succeeds, the bounded
   `EmberSurfaceLoopCommandSource` supplies forward production flight from the
   landing definition's corridor entry volume to the
   internal `(0, 60, 30)` assist handoff. The latter lies inside the same
   declared corridor and is not new world geometry.
2. `EmberSurfaceBerth` derives the exact pad half-extents `(14, 9, 16)`,
   compatible ship tags, and broad corridor half-extents `(45, 60, 300)` from
   `ember_caldera_landing_region.tres`. It adds no renderer or collision. A real
   lease and `HeroShip.request_berth_landing()` drive the staged approach. The
   TravelSession landing fact is submitted only after public landed telemetry,
   strict full-hull acceptance, exact occupancy/token identity, and physical
   support are current together.
3. After automatic engine shutdown, the existing `ShipBoardingArea` reservation
   and `PlayerController.begin_disembark()` produce the on-foot body. The caller
   supplies normal public Input actions; the host only observes continuous
   support and ordered pad-egress `(18, 0, 0)` then staging `(42, 0, 0)` anchors.
   Both anchors and every intermediate support sample are evaluated in the
   gravity policy's frozen tangent basis relative to the live authored
   `LandingRegion`; a world-X/Z shortcut is not used. Each caller tick requires
   `PlayerController.is_on_floor()` plus a downward physics query whose exact
   collider is the current loaded root's `WalkablePatch`.
4. Returning through the egress and the real nearby boarding area permits an
   exact Player reservation and `begin_boarding()`. A competing reservation is
   state-preserving and cannot be stolen.
5. The same bounded command source pitches and accelerates the real Arrow away
   from the occupied pad. Only the first public `landed: true -> false`
   transition releases the exact berth lease. The existing TravelSession then
   observes 15 m surface clearance, 20 km orbital return, and completion.

The gravity policy is configured from the exact world, terrain, coordinate
frame, and caller-supplied reference magnitude. During the bounded planar
surface walk, its tangent-Y projection updates Player's public
`gravity_multiplier`; Player's existing `_physics_process()` remains the only
movement/collision integrator. This is intentionally a bounded tangent-patch
composition, not global spherical locomotion.

## Generation and failure boundary

The host freezes and checks all of these identities on every caller tick:

- host generation and attachment generation;
- the bootstrap and coordinate-frame instances and frame generation;
- current bootstrap loaded-root instance ID;
- exact coordinator/location generation and loaded-root metadata;
- exact shared composition-root instance and direct-child topology;
- Ember world/body/region/terrain IDs;
- Arrow definition and instance ID, Player instance ID, berth and boarding-area
  instances.

Queued deletion, unloaded/replaced roots, N→N+2 generation replay, coordinate
rebase, composition-root/topology drift, ship destruction, landing abort,
obstruction/support mismatch, or any
detached dependency fails the TravelSession. Synchronous destruction during a
berth or ship signal is retained by a first-wins pending-terminal guard and is
committed before the outer host mutation can return success. Explicit detach
disconnects callbacks, restores the prior command/control/gravity bindings,
releases only host-owned leases, detaches the TravelSession, and advances the
host attachment generation so old tokens cannot resume it. Releasing an active
landing lease uses the existing HeroShip next-physics `reservation_lost` abort;
no private landing method is called.

Failure or detach during public boarding/disembark is atomic: the host first
commits its terminal state, disconnects callbacks and releases exact leases,
then calls the existing public `force_recovery_to_on_foot()` cancellation seam.
When the live loaded surface is still current, recovery uses the Arrow's exit
only after a ray proves that transform is supported by the exact current
`WalkablePatch`; canopy, camera, piloted state, control, command source and
gravity bindings are restored coherently. If the surface itself is already
unloading, the transition is still cancelled at the Player's current transform
but locomotion remains disabled for a later world-owner recovery decision.

## Authority and remaining production work

The host owns the caller-clocked session composition, bounded command
transport, gravity-multiplier composition, and berth/boarding orchestration. It
does not own HeroShip or Player physics, InputMap, static collision, terrain,
origin shifting, streaming cadence, Main, GameFlow, activity, rewards, combat,
HUD, audio, save, or networking.

The entry envelope is validation, not staging authority. Production still has
to bring the live Arrow physically into that volume with a separate movement
owner, keep the Player publicly seated/piloting with the exact boarding
reservation, and call `start()` with current generations. The host neither
teleports nor brakes a rejected candidate into compliance.

Production now has a `CommonWorldOriginRebaseOwner` that can translate station,
Cinder, Ember, actors, effects and streaming roots atomically. This standalone
host does not own or invoke it: production still needs explicit
GameFlow/activity selection that enters the loop only after the existing owner
has committed the surface-local frame and that forwards later generation
changes fail-closed. Until then, this remains a standalone proof entered only
after caller-owned rebase/load. It grants no reward and does not save progress.

Focused gate (after editor import):

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_surface_loop_host_test.gd
```
