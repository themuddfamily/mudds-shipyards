# Cinder streamed ship-berth production binding

`CinderStreamedShipBerthBinding` is the production composition seam between the
standalone `StreamedShipBerthOverlay`, Main's existing
`CinderStreamingBootstrap`, and the exact five resident `ShipyardWorld` berth
IDs. Main owns one fixed node immediately after the bootstrap and before the
existing deferred streaming driver.

The binding configures once while the coordinator is quiescent and before any
load request. It retains the same overlay, bootstrap, coordinator, world, and
binding identities across whole-Main detach/re-entry. Re-entry does not reconnect
signals, repeat configuration, or replay a load/retirement event.

## Current zero-berth Cinder behavior

This stage deliberately does not place `CinderCargoAccess`, a cargo destination
terminal, or any other `ShipBerth`. A real load of today's
`NearbySectorCluster` is therefore observed by the overlay as rejected
`no_ship_berths`, with zero active streamed records and no registration signal.
Its coordinator unload is observed as `unknown_location`, with no retirement
signal or fabricated tombstone. Reload repeats those typed observations at the
new exact coordinator generation and root instance. The detached merged view
remains the sorted five resident IDs throughout.

That result is fail-closed evidence, not a successful Cinder berth claim. A
later placement stage may cause the same unchanged overlay to commit a full
valid roster atomically.

## Public read boundary

`get_merged_berth_snapshot()` and `lookup_streamed_berth_record()` return deeply
detached primitive dictionaries. `resolve_streamed_berth_node()` is the sole
live capability seam and requires callers to echo location ID, load generation,
root instance ID, berth ID, and berth instance ID from a lookup record. A stale
generation cannot silently resolve a replacement node.

`ShipyardWorld.get_berth_ids()`, its five resident node/transform caches, landing
queries, feedback audit, and GameFlow landing/cargo behavior are unchanged.

## Authority boundary

The binding adds no process loop and never requests a load/unload, adds/removes
a node, registers a resident world berth, reserves/occupies/releases a lease,
moves a ship, accepts a landing, transfers cargo, grants a reward, presents UI,
or persists state. Its audit retains the exact common 12-key all-false authority
roster and explicitly denies scene-tree, berth lease, reservation, occupancy,
ship-token, landing, movement, streaming-decision, cargo, route, reward, and UI
authority.

Focused production evidence instantiates real Main with isolated settings
persistence, freezes resident-only startup, loads the real zero-berth Cinder
scene, checks whole-Main detach/re-entry identity, unloads/reloads at exact
coordinator generations, and proves no duplicate overlay signals or changes to
the resident registry.
