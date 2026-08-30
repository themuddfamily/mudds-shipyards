# Ember surface loop host

`EmberSurfaceLoopHost` is a standalone, opt-in composition of the existing
Ember Moon contracts and real production actors. It is `NEW` / modern
interpretation work and makes no historical-behaviour claim.

The caller first performs the existing Ember body-centre rebase and streaming
load, then a second explicit common-origin transaction that places the live
landing tangent patch at local origin (coordinate-frame generation three in the
focused fixture). In shared-root coverage, both commits run through the real
`EmberMoonStreamingProductionBinding` preview and
`CommonWorldOriginRebaseOwner.consume_rebase_preview()` transaction, including
its quiescence, rollback and PhysicsServer synchronization contract. The
bootstrap and its loaded root participate; the standalone fixture instantiates
the berth overlay and actors immediately afterward in the resulting frame.
Unre-based CharacterBody contact at 120 km is not claimed. It then supplies one
exact loaded location generation, the production
`EmberMoonStreamingBootstrap`, an `EmberSurfaceBerth`, one real Arrow recon ship,
and the real `PlayerController`.

`bind_dependencies()` freezes one explicit composition root. Omitting the final
argument retains the standalone topology: the host itself is the root and all
four dependencies are its direct children. A later production composition may
supply `Main` instead; in that topology the host, bootstrap, berth, Arrow,
Player, one `EmberMoonStreamingProductionBinding`, and one
`CommonWorldOriginRebaseOwner` must all be exact siblings under that same root.
The host freezes the root, owner and binding instance IDs and proves that both
components bind its exact bootstrap and coordinate frame. It checks the sibling
topology for the full attachment and never reparents any dependency.

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

`bind_dependencies()` only freezes the existing seated
`ShipBoardingArea` reservation and original ship command source; it neither
installs its command source nor accepts reservation-cleanup ownership. `start()`
first measures the complete typed approach envelope, then preflights the exact
live Player token, piloted/seated state, and original command source. Only after
the landing report and TravelSession start are accepted does it attach one
generation-fenced, value-only gravity source to the ship, install the bounded
command source, and accept cleanup responsibility for that already-held
reservation. A rejected start therefore cannot steal or reacquire GameFlow's
command/reservation state and remains retryable. After an accepted start, the
host writes no actor transform, velocity, parent, collision state, or
physics-processing state. The focused receipt fixture applies only its explicit
caller-owned common-world translation before asking the host to validate the
committed result.

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
frame, and caller-supplied reference magnitude. Every Host tick samples the
exact ship position and queues one bounded world-space vector for the next
`HeroShip` tick. HeroShip consumes that vector once inside ordinary flight,
remains the sole velocity/`move_and_slide()` owner, and uses its radial up for
hover braking and alignment. A lifecycle branch that cannot consume the sample
discards it that ship tick, so landing, shutdown or disembark cannot leave a
latent force. During the bounded planar surface walk, the embodied Player's
separate tangent-Y projection updates public `gravity_multiplier`; Player's
existing `_physics_process()` remains its only movement/collision integrator.

## Generation and failure boundary

The host freezes and checks all of these identities on every caller tick:

- host generation and attachment generation;
- the bootstrap and coordinate-frame instances and frame generation;
- for shared-root composition, the exact live origin-owner and Ember-binding
  siblings plus their bootstrap/frame identities;
- current bootstrap loaded-root instance ID;
- exact coordinator/location generation and loaded-root metadata;
- exact shared composition-root instance and direct-child topology;
- Ember world/body/region/terrain IDs;
- Arrow definition and instance ID, Player instance ID, berth and boarding-area
  instances.

Queued deletion, unloaded/replaced roots, N→N+2 generation replay, an
unadopted coordinate rebase, composition-root/topology drift, ship destruction,
landing abort, obstruction/support mismatch, or any detached dependency fails
the TravelSession. Synchronous destruction during a
berth or ship signal is retained by a first-wins pending-terminal guard and is
committed before the outer host mutation can return success. Explicit detach
disconnects callbacks, restores the prior command/control/gravity bindings,
releases only host-owned leases, detaches the TravelSession, and advances the
host attachment generation so old tokens cannot resume it. Releasing an active
landing lease uses the existing HeroShip next-physics `reservation_lost` abort;
no private landing method is called.

While the loop is active, the ship's exact command source is also a frozen
dependency. A foreign public `set_command_source()` replacement terminalizes
the host on the next caller tick. Cleanup neutralizes and retires only the
host-owned producer, releases only the host-owned Player/berth tokens, restores
the other actor bindings it owns, and deliberately leaves the foreign source
installed and attached. It never overwrites a later command owner with the
captured pre-loop source.

During an active shared-root loop, a caller may pass the exact detached receipt
from an already committed `CommonWorldOriginRebaseOwner` transaction to
`adopt_committed_origin_rebase()`. Adoption is caller-driven and accepts only
the frozen live sibling owner's current `last_receipt`, with exact transaction,
bootstrap, production-binding and coordinate-frame identity, and only for an
exact current N→N+1 frame commit with no pending rebase. It reconstructs the
complete sorted Node3D root roster and covered-instance roster from the frozen
composition root, matches every path/mode/instance ID, preserves the exact
bootstrap/location/loaded-scene identities and landing tangent relations (with
only a 1 cm allowance for float rounding between a direct root and streamed
child after the same large translation), and re-encodes the current ship or
Player position to prove the receipt's absolute orbital observation is
unchanged. A valid receipt updates only the host's
coordinate-frame-generation fence and detached audit evidence. The host never
requests, applies, commits, cancels, or defers an origin transaction; standalone
self-root composition deliberately rejects this production-oriented adoption
seam because it cannot prove the external common-world roster.

Failure or detach during public boarding/disembark is atomic: the host first
commits its terminal state, disconnects callbacks and releases exact leases,
then calls the existing public `force_recovery_to_on_foot()` cancellation seam.
When the live loaded surface is still current, recovery uses the Arrow's exit
only after a ray proves that transform is supported by the exact current
`WalkablePatch`; canopy, camera, piloted state, control, command source and
Player gravity are restored coherently, while the ship's pending gravity
sample is retired. If the surface itself is already
unloading, the transition is still cancelled at the Player's current transform
but locomotion remains disabled for a later world-owner recovery decision.

## Authority and remaining production work

The host owns the caller-clocked session composition, bounded command
transport, gravity sampling/value submission, Player multiplier composition,
and berth/boarding orchestration. It
does not own HeroShip or Player physics, InputMap, static collision, terrain,
origin shifting, streaming cadence, Main, GameFlow, activity, rewards, combat,
HUD, audio, save, or networking.

The entry envelope is validation, not staging authority. Production still has
to bring the live Arrow physically into that volume with a separate movement
owner, keep the Player publicly seated/piloting with the exact boarding
reservation, and call `start()` with current generations. The host neither
teleports nor brakes a rejected candidate into compliance.

`probe_approach_ready()` exposes that same frozen envelope as a read-only,
caller-tokened preflight while the bound Host remains `IDLE`. It returns a
deep-detached accepted/rejected measurement plus point-in-time Host snapshot and
audit. A successful probe is not a start capability: it does not retain entry
evidence, install the Host command source, take Player reservation-cleanup
ownership, reserve or occupy the berth, or write an actor transform, velocity,
parent, or physics state. Its only use is an honest future GameFlow readiness
observation after a separate owner has physically flown the real Arrow into the
already-authored corridor. It neither makes Ember reachable nor chooses a
manual-approach, landing, surface, or production handoff policy.

After `COMPLETED`, `return_runtime_ownership()` provides one atomic handback for
a later production GameFlow owner. It preflights the exact host command source,
ship-gravity binding, seated Player token, actor/control/camera/gravity state,
empty berth lease, and attached TravelSession; releases the ship-gravity
binding, restores the original ship command source, detaches the session and
bounded producer, retires the host attachment generation, and leaves the exact
Player reservation continuously held. Its returned dictionary is a
deep-detached identity/serial receipt, not a capability. If a preflight or
session detach is rejected, command/reservation ownership remains unchanged.
The host stays single-use. Ordinary failure/detach continues to restore bindings
and release only cleanup ownership that an accepted start actually transferred.

Production now has a `CommonWorldOriginRebaseOwner` that can translate station,
Cinder, Ember, actors, effects and streaming roots atomically. This standalone
host does not own or invoke it: production still needs explicit
GameFlow/activity selection that enters the loop only after the existing owner
has committed the surface-local frame, forwards later committed receipts, and
accepts the completion handback. Until then, this remains a standalone proof
entered only after caller-owned rebase/load. It grants no reward and does not
save progress.

Focused gate (after editor import):

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/hero_ship_planetary_surface_gravity_test.gd
godot --headless --audio-driver Dummy --path . \
  --script res://tests/ember_surface_loop_host_test.gd
```
