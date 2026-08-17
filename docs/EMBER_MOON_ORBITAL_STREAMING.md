# Ember Moon orbital placement and streaming foundation

`NearbySectorOrbitalRegistry` and `EmberMoonStreamingBootstrap` form one
explicit-update foundation for Ember Moon. Production `Main` now instances the
bootstrap and a narrow caller-physics adapter, described in
`EMBER_MOON_PRODUCTION_STREAMING_BINDING.md`. They do not alter
`ShipyardWorld`, Cinder Reach, `SpaceBackdrop`, a ship, a player, or a
`PlanetaryTravelSession`.

## Absolute datum

The immutable registry is schema 1, registry
`nearby_sector_orbital_registry`, frame `nearby_sector_orbital`, with exactly
1,000,000 metres per integer cell. `shipyard_station_datum` is cell `(0,0,0)`
with zero offset. `ember_body_center` is cell `(0,0,-8)` with zero offset:
exactly `(0,0,-8000000)` metres from the station datum.

The -Z direction follows the station's existing outbound-facing convention.
The round 8,000 km distance is an original modern game-scale placement, not a
recovered fact. The station entry is a coordinate reference only; it does not
claim ownership of the live station. No Cinder or decorative backdrop identity,
transform, scale, or lifecycle is reused.

Coordinates use the strict `PlanetaryCoordinateFrame` record:
`{schema_version, frame_id, cell_x, cell_y, cell_z, offset_meters}`. Cells are
safe integers and offsets use the canonical half-open interval
`[-500000, 500000)` on every axis. Registry reads and reports are detached.

## Composition and lifecycle

The bootstrap begins at the station-relative Ember body centre and owns exactly
one child `WorldStreamingCoordinator`. The coordinator registers
`assets/world/locations/ember_moon.tres` and binds the existing authored
`scenes/world/planets/ember_moon.tscn`. The registered navigation anchor is the
body-local `(0,130000,0)` point; the scene origin is body centre. A loaded root
therefore remains a locally identity `WorldLocation_EmberMoon` child beneath
the coordinator.

The coordinate frame freezes the 120,000 m radius, +Y surface reference,
-Z north hint, 10,000 m origin-shift threshold, registry frame/cell size, and
station datum as initial streaming origin. It begins at generation 1.

There is no engine process callback. A caller explicitly supplies a canonical
absolute focus and exact current coordinate generation. Radial body-centre
distance uses these inclusive rules:

- unloaded at more than 250,000 m;
- load at or below 250,000 m;
- retain through exactly 300,000 m;
- unload above 300,000 m.

The scene cannot load while its decoded body centre is more than 300,000 m from
streaming zero. Thus proximity alone cannot instantiate the 120 km body at its
initial 8,000 km local position: the caller must rebase first. A resident or
pending load is retired when either its focus or body centre leaves the bounded
envelope. Coordinator generations remain independent: first load is 1, unload
is 2, and reload is 3.

## Caller-owned rebase and observations

The bootstrap exposes the exact configured coordinate-frame object because a
`PlanetaryTravelSession` requires frame instance identity. The caller owns the
entire rebase transaction:

1. request a rebase from the current frame generation;
2. apply the frozen `world_translation_delta` to the common world root,
   including the bootstrap;
3. commit the exact request and source generation, reversing the translation if
   commit fails;
4. resume updates with the target generation.

The bootstrap never requests, commits, or applies this translation. Streaming
updates and observations reject a pending rebase, stale generation, or root
whose identity basis/position no longer matches the frame.

`create_travel_observation()` requires a finite bounded speed, exact current
coordinate generation, exact live coordinator generation, and a current loaded
scene. It returns detached canonical orbital, world-streaming, body-local,
radial, altitude, speed, world/body/location identity, and both generation
fields. A caller may pass the orbital coordinate, speed, and coordinate-frame
generation to `PlanetaryTravelSession`; this component never retains or mutates
that session. The additional location generation lets the caller reject an
observation from a retired scene even though TravelSession itself does not yet
consume streaming generations.

## Evidence and authority

Both components are `NEW` / `modern_interpretation`. The registry owns only an
immutable datum. The bootstrap truthfully owns frame configuration, absolute
focus evaluation, Ember registration, load/unload requests, and observation
encoding. The coordinator owns the instantiated root lifecycle.

Automatic processing, rebase decision/application, ship or player movement,
GameFlow, travel-session mutation, landing approval, world/terrain/collision
generation, save, network, SpaceBackdrop, and Cinder streaming authority are
all exactly false.

Production insertion is limited to one lifetime-stable bootstrap and one
caller-physics observation binding. Applying an origin rebase remains deferred
until one host can atomically translate the station, Cinder, ships, player,
effects, and Ember roots; the production binding exposes only a detached preview
and fails closed at generation 1. Also deferred are motion and travel handoff,
GameFlow transitions, TravelSession streaming-generation binding, landing
authority, spherical gravity, global terrain/LOD/collision, actor spawning,
persistence/networking, and production performance/render validation.

Focused verification covers exact cells and detachment, canonical rejection,
the required initial rebase, both inclusive distance boundaries, coordinator
generations 1/2/3, stale asynchronous completion, signal reentry, exact-current
detached observations, root drift, evidence, and authority.
