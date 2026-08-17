# Ember Moon production streaming binding

`Main` owns exactly one `EmberMoonStreamingBootstrap` and one
`EmberMoonStreamingProductionBinding`. `GameFlow` performs the existing single
ship-or-player position read in `_physics_process()` and passes that detached
sample to both Cinder and Ember. The Ember binding has no `_process()` or
`_physics_process()` cadence of its own.

The binding freezes the bootstrap identity and its exact
`PlanetaryCoordinateFrame` identity during one deferred activation. Every
accepted caller sample is converted from the
current world-streaming `Vector3` to the canonical absolute
`nearby_sector_orbital` coordinate before the existing Ember bootstrap evaluates
its 250 km / 300 km streaming contract. Invalid, unavailable, stale-generation,
pending-rebase, or detached calls fail without guessing actor position or
retiring a streamed generation.

## Origin-rebase boundary

Production `Main` owns one `CommonWorldOriginRebaseOwner` that consumes this
binding's read-only preview. The binding still does not call `request_rebase()`,
move a node, or call `commit_rebase()`. It publishes the exact absolute
coordinate, source generation, threshold result, and translation. After the
owner commits that exact transaction, the binding accepts one exact generation
handoff and proves the adjusted local sample encodes the same absolute point.

This boundary remains fail-closed: arbitrary frame identity/generation changes,
pending requests, or mismatched owner receipts are rejected. A valid owner
transaction moves the complete live spatial roster, advances the frame exactly
once, and lets the bootstrap evaluate the retained absolute focus in the new
local frame.

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
claim. Remaining production work is player-facing travel and landing
orchestration; coordinate rebasing itself grants neither.
