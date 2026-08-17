# Ember Moon production streaming binding

`Main` owns exactly one `EmberMoonStreamingBootstrap` and one
`EmberMoonStreamingProductionBinding`. `GameFlow` performs the existing single
ship-or-player position read in `_physics_process()` and passes that detached
sample to both Cinder and Ember. The Ember binding has no `_process()` or
`_physics_process()` cadence of its own.

The binding freezes the bootstrap identity, its exact
`PlanetaryCoordinateFrame` identity, and coordinate-frame generation 1 during
one deferred activation. Every accepted caller sample is converted from the
current world-streaming `Vector3` to the canonical absolute
`nearby_sector_orbital` coordinate before the existing Ember bootstrap evaluates
its 250 km / 300 km streaming contract. Invalid, unavailable, stale-generation,
pending-rebase, or detached calls fail without guessing actor position or
retiring a streamed generation.

## Origin-rebase boundary

Production does not yet have one owner that can atomically translate the
station, Cinder, ships, player, effects, and Ember roots. The binding therefore
does not call `request_rebase()`, move a node, or call `commit_rebase()`. Its
`preview_origin_rebase()` method is read-only. For the most recent accepted
actor observation it publishes the exact absolute coordinate, source generation,
inclusive 10,000 m threshold result, and proposed translation delta that a later
common-world origin owner would need to use.

This boundary is deliberately fail-closed. At the initial station-relative
origin, an actor can be encoded at any valid local position, but approaching
Ember's absolute body centre cannot load the moon: the bootstrap returns
`rebase_required_before_load`, the coordinate frame remains generation 1, and
the Ember coordinator remains unloaded. The binding will reject any externally
changed frame identity, generation, or pending rebase rather than silently
adopting it.

## Lifecycle and authority

A whole-`Main` detach pauses GameFlow physics. The same binding, bootstrap,
coordinate frame, private coordinator, generation, counters, and last detached
observation remain alive. Re-entry reuses them; it does not reconfigure,
re-activate, or replay a sample.

The bootstrap retains its existing narrow registration and load/unload request
authority. The production binding owns only caller-physics orchestration,
absolute-coordinate conversion, and the detached rebase preview. It owns no
activity, cargo, Cinder, combat, gameplay, landing, movement, origin-rebase,
reward, ship, save, network, or streaming-generation authority. It never starts
travel, awards progress, moves an actor, or changes Cinder state.

This composition is `NEW` / `modern_interpretation`; it makes no recovered-source
claim. Remaining production work is the common-world origin transaction and its
translation-safe coexistence contract. Only after that exists can production
rebase near Ember and exercise the already-tested standalone load/unload journey.
