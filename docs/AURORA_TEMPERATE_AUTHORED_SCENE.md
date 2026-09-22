# Aurora temperate authored scene

This NEW standalone witness gives Aurora one body-centred ocean sphere, one
bounded +Y landing patch, and one caller-driven spherical terrain clipmap. The
clipmap consumes Aurora's real terrain profile and commits five 65 × 65 radial
rings: 21,125 vertices, 40,096 visible triangles and one 32,768-triangle
relief-matched collision shape reaching 1.5 km. One shared vertex-colour
material separates shore,
lowland, highland, rock and snow. The complete 600 m approach box sits inside a
750 m flat envelope, and the authored landing-floor disc occupies a deliberate
94 m visual opening rather than fighting the generated surface. The atmosphere
composition remains the sole `WorldEnvironment` owner; this scene does not
configure it automatically.

The *scene* still owns no streaming, player, camera, gameplay, landing
decision, origin shifting, save, network, navigation, or production binding.
Terrain rebuilds remain explicit caller operations and collision ends at the
terrain profile's 1.5 km physical boundary. What has changed since this
paragraph was first written is that something else now owns those things for
it: `scripts/game/aurora_expedition.gd` stands this scene up as a real visit.
The section below records that route and, just as importantly, what about it is
still not Ember-grade.

## The production visit

Aurora is a second visitable world. A player gets there like this: take a small
or medium craft's pilot seat at Mudds, open `Esc` -> Destination Board, and
press **Aurora Temperate World**. The board row is registered from Aurora's own
`PlanetaryWorldDefinition` and now reads its distance from
`NearbySectorOrbitalRegistry`'s `aurora_body_center` datum -- 12,000 km on
station-relative +X, deliberately a different axis from Ember's 8,000 km on
-Z -- rather than from a literal nothing could keep honest.

What arrives is not a reskin of Ember. Ember is airless: its streaming
bootstrap composes an airless sun rig and scales the station Environment's
ambient down into vacuum. Aurora hands the viewport its own
`PlanetaryAtmosphereComposition` instead, so the existing atmosphere, sky,
cloud and sun adapters run together and the pilot lands into fog, an
atmospheric horizon and a cloud deck. Under the craft is Aurora's own bounded
terrain generator, and around the pad is a coast: an amber gravel trail with
posts, a signed lookout deck with rails and two instrument scopes, a ring of
standing stones, coast-facing tree clusters, shore rocks and a live waterline.

The loop is: land on the authored pad through a real `ShipBerth` lease and
`HeroShip.request_berth_landing()`; leave the seat with a real `interact`;
walk the authored patch on real collision; walk back to the craft's
`ShipBoardingArea` and re-board with a real `interact`; and choose the board's
return action to fly home and dock at the pilot's own registered berth.
Departing frees the visited world, restores the station's presentation and
leaves no Aurora nodes under `Main`. Abandoning mid-visit returns a
controllable explorer to the yard with their craft docked at home and no held
reservation. `tests/aurora_visit_loop_test.gd` drives all of that through a
real composed `Main`.

### Surviving a re-entry

A visit that is running when `Main` leaves the tree used to end silently: the
pilot woke up back at Mudds with no record they had ever gone.
`AuroraExpeditionPersistenceBinding` now commits a small detached record --
the visit phase, the craft named by its registered home berth, and whether the
pilot was out of the seat -- into the same `UserDataStore` the game already
ships with. The next `Main` loads it at the end of `start_shift()`, stands the
world back up through the *same* `_compose_surface()` a fresh arrival uses,
gives the craft a real lease and a real assisted landing on the pad, and
recovers the pilot on foot beside its ramp. The receipt is retired only once
that resume is accepted, so an interrupted resume leaves the trip retryable
rather than losing it. A pilot who had already asked to go home is deliberately
not brought back.

### What is still Ember's and not yet Aurora's

Ember reaches its moon through `PlanetaryJourneyCoordinator`,
`PlanetaryCruiseProductionBinding`, `EmberMoonStreamingProductionBinding` and
`CommonWorldOriginRebaseOwner`: a real cruise out, a streamed generation that
loads as the craft closes, an authored approach corridor flown under the
final-approach controller, and committed common-world origin rebases on the way
down. Aurora does none of that. Its outbound leg is an explicit 1.2 s jump, the
world is instantiated directly rather than loaded through
`WorldStreamingCoordinator`, and no origin rebase happens because nothing moves
far enough from the streaming origin to need one.

Closing that gap is not a matter of pointing Aurora at the existing owners.
`CommonWorldOriginRebaseOwner` and `PlanetaryCruiseProductionBinding` each bind
exactly one bootstrap/binding pair at `_ready` and are statically typed to
Ember's classes, and the origin owner translates *every* live root -- the
station included -- so a second streamed body needs that ownership widened
before it can stream at all. `PlanetaryStreamingBootstrap` (extracted from
`EmberMoonStreamingBootstrap`) is the first step of that work and is in place;
the owner widening is not.

## Detached surface-route and landmark audit

The existing landing declaration supplies exactly one `NEW` / modern,
non-traversable `aurora_pad_to_staging` polyline: the authored `aurora_pad`
at `(0, 0, 0)`, then `aurora_egress` at `(18, 0, 0)`, then `aurora_staging` at
`(42, 0, 0)`, all in region-local metres. The scene audit resolves those points
from the landing resource and requires the three existing marker nodes to match.
It publishes this only as detached content data; `traversable` and
`route_authority` are explicitly false.

This is neither a navigation graph nor a clearance/traversal claim. The bounded
96 m patch remains the sole authored centre support, surrounded by generated
relief collision outside its 48 m half-width. No Player, NavigationRegion,
landing decision, streaming, production binding, Main/GameFlow ownership, or
origin/rebase application is introduced.

## Standalone renderer witness

`tests/capture_aurora_temperate_visuals.gd` is an evidence-only native
Forward+ witness for this standalone scene. It instantiates Aurora alone,
configures its already-authored atmosphere composition with one fixed
body-local observation, and adds one temporary evidence camera at the authored
ApproachEntry looking at the authored pad. It captures the exact same pose in
HIGH and LOW renderer profiles; the LOW frame is a profile-difference witness,
not a quality ranking.

The harness rejects headless, Mobile, Compatibility, and non-X11 execution and
publishes no fallback artifacts. A successful native run publishes only its two
frames, capture log, source digest, and immutable evidence manifest in a
versioned directory under `artifacts/aurora_temperate_visuals/captures/`; the
root `evidence_manifest.json` is an atomic pointer to one complete version.
No prior complete capture is deleted before that pointer switches. The manifest
is explicitly `NEW`,
`modern_interpretation`, `source_bounded=false`, `confidence=none`, and
`production_witness=false`.

The native witness is deliberately separate from headless focused tests. Run it
only when a native capture has been explicitly authorized:

```sh
godot --path . --display-driver x11 --rendering-driver vulkan \
  --audio-driver Dummy --script tests/capture_aurora_temperate_visuals.gd
```

Those artifacts prove only that this standalone authored scene configured and
rendered its fixed observation—including the committed terrain—under the named
native renderer. They do not prove Main/GameFlow integration, streaming,
visitability, Player or production-camera ownership, movement, landing
eligibility, collision beyond the current 1.5 km profile boundary, runtime
focus updates, weather/time progression, audio, save/networking, performance, visual fidelity,
or production visual quality.

## How Aurora is reached

Aurora used to be reached by an explicit 1.2 s jump that instantiated this scene
locally under `Main`. It is now streamed and visited through the same production
planetary subsystem Ember uses.

`AuroraTemperateStreamingBootstrap` is a second `PlanetaryStreamingBootstrap`
standing in `Main` beside Ember's. It registers
`assets/world/locations/aurora_temperate.tres` against the body-centre datum
`NearbySectorOrbitalRegistry` already declares 12,000 km on station-relative +X,
and it drives this scene's own `PlanetaryAtmosphereComposition` where Ember's
bootstrap drives its airless sun rig - configuring it against the live
generation and feeding it one body-local observation per accepted focus.
`AuroraTemperateStreamingProductionBinding` is its caller-physics adapter and is
thirty lines: everything it does is shared.

A visit is admitted by `PlanetaryJourneyCoordinator.admit_aurora_visit()`, which
points the one `PlanetaryCruiseProductionBinding` at Aurora's bootstrap and makes
sure the one `CommonWorldOriginRebaseOwner` holds Aurora's pair. Each physics
tick the coordinator's Aurora lane runs the same order Ember's does: Aurora's own
streaming observation from GameFlow's single actor read, then the caller-owned
origin transaction, then the cruise. Aurora sits 12,000 km out and the
origin-shift threshold is 10 km, so the world is not reachable at all without
committed common-world rebases; the visit counts them. Once Aurora is resident
the visit leases its exploration berth on *this* scene's own `LandingRegion`,
stands an `AuroraVisitApproachSource`, engages the cruise and arms the authored
corridor from `aurora_foundation_landing.tres`. The touchdown is a real
`ShipBerth` lease and a real `HeroShip.request_berth_landing()`, and the
return now uses physical departure and shared cruise before ordinary home
landing. Explicit surface rescue retains its restoration path; cancellation
leaves the craft at its current physical pose.

### Physical travel and remaining recovery placements

A new visit requires a physically departed craft. The pilot climbs clear of the
yard and faces Aurora before requesting cruise; existing active-flight-objective
restrictions remain in force. Cruise retains the same seated craft across origin
shifts. Once Aurora streams in, its approach source authenticates each committed
frame change before the next movement tick. The controller flies into the authored
corridor and hands off to the berth's physical landing assistance. Landing gets a
fixed deadline based on the accepted travel distance, retaining independent
obstruction, clearance and lease checks.

Fresh outbound travel makes no orbital-standoff, corridor-entry or berth-staging
placement. Cancelling outbound releases its own cruise and landing ownership at
the current pose without overwriting recovery or a replacement craft's lifecycle.
Manual input retains priority; the requested visit can resume when input ends.
Interrupted-visit restoration and explicit rescue still use placements. RETURN
retains the occupied surface lease until real takeoff, queues cruise while the
pilot climbs clear, and carries the same craft through origin shifts. Its
authenticated home-shell receipt hands control to ordinary manual flight and
registered-berth landing; reaching that shell does not claim docking.

The isolated production and visit-loop suites pass 69 and 50 assertions on
`727f2588e`: physical approach and docking, pilot continuity, cabin sleep/wake,
walking, reboarding, save restoration, repeat departure and cancellation. Their
bounded fixture places the craft 70 km away before requesting outbound travel.
The optional `--aurora-full-flight` mode uses held-input departure, climb and
orientation from the yard without subsequent actor placement; its full 12,000 km
run on `727f2588e` failed before landing: the craft flew over 12,000 km with
continuous actor movement and 1,200 origin shifts, but final approach retired
after descent and exhausted 600 re-engagement attempts. The last refusal was
`alignment_below_threshold`. The first retirement was subsequently reproduced:
a low-descent rebase introduced 8.8 mm of floating-point disagreement between
the cached landing root and its live parent/local composition. The fix preserves
that composition order through rebases without widening tolerances. The same
reproduction now lands (14 assertions); the existing handoff regression passes
27 assertions, including rejection of genuine local movement and reparenting.
This is not a full-flight pass. The test ends the automatically selected Cinder activity through the
public session-fenced failure API, so it does not establish a complete fresh-save
objective playthrough. Logs: `aurora-production-isolated.log`,
`aurora-visit-loop-isolated.log` and `aurora-full-flight-frozen.log` under
`/root/.cache/mudds-shipyards/`.

The combined candidate `bc38358ef` includes this fix and physical return.
Separate return checks pass real departure/unload (20 assertions), near-home
flight/docking/walking (10, Torrent), Halyard local landing/walking (5), and
existing Aurora suites (68 and 49). These separate fixtures do not establish a
full same-craft round trip. That explicit Halyard acceptance is pending; the
latest published checkpoint remains `080f6ae`.
