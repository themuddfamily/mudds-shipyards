# Streamed ship-berth overlay

`StreamedShipBerthOverlay` is a standalone, read-oriented registry for
`ShipBerth` nodes owned by a `WorldStreamingCoordinator`. It gives a later
`ShipyardWorld` integration one atomic streamed roster and one deliberately
named live-node resolver without changing the coordinator, the resident berth
registry, or any physical berth.

This foundation is not production-wired. Its only production dependency is the
existing coordinator and berth contracts; a later owner must configure it
before the first streaming request and explicitly merge its read view.

## Configuration and complete-root registration

`configure(coordinator, resident_berth_ids)` succeeds once, while the supplied
coordinator is live and quiescent. The sorted resident ID roster is used only to
reject global identifier collisions. An empty roster is explicit and valid.
Configuration connects to the coordinator's committed `location_loaded` and
`location_unloaded` observations.

One load observation preflights the complete recursive `ShipBerth` roster below
that exact root before writing any index. The root must be live, inside the
tree, not queued for deletion, currently owned by the configured coordinator,
and carry exact `world_location_id` and `world_location_generation` metadata.
Each berth must be live, unqueued, inside that root, pass
`get_validation_errors()`, and expose a stable unique ID. Resident collisions,
active streamed collisions, duplicate IDs or instance IDs, invalid siblings,
and bounded-capacity failures reject the whole batch and emit no registration
signal.

A committed primitive berth row contains exactly the location ID, coordinator
load generation, root instance ID, berth ID, berth instance ID,
`ShipBerth.SCHEMA_VERSION`, and sorted compatibility tags. Reservation and
occupancy are intentionally absent because those are mutable lease state, not
stream provenance.

## Generations, retirement, and tree lifetime

Load and retirement generations are distinct. A loaded roster at generation
`N` can retire only from the coordinator's exact committed unload generation
`N + 1`, with the original root instance ID. Retirement removes the whole
location roster and both live indices before one detached batch signal, then
keeps bounded location and berth tombstones. A later reload must use a newer
coordinator generation and new root/berth instances. Replays, delayed unloads,
active replacement attempts, and provenance collisions are rejected without
changing state.

The coordinator remains lifecycle authority. Whole-coordinator/Main detach and
re-entry preserve the same loaded root and overlay record: identity remains
current, while live resolution is unavailable outside the tree. Independent
root removal, replacement, or queued deletion is reconciled by the coordinator,
which emits the sole retirement observation. The overlay does not infer unload
from raw tree signals and therefore cannot double-retire a location.

`resolve_berth_node(location_id, load_generation, root_instance_id, berth_id,
berth_instance_id)` is the only API that returns a live capability. A consumer
must echo the full primitive provenance returned by `lookup_record()`, so a
stale consumer cannot acquire a replacement node that reused the same stable
berth ID after reload. Resolution fails closed for mismatched expected identity,
an expired, outside-tree, queued, reparented,
metadata-drifted, or instance-mismatched root/berth. Every dictionary, array,
signal payload, snapshot, lookup record, merged read, and audit is deeply
detached and contains primitives only.

## Frozen bounds and authority boundary

The schema freezes these limits:

- 128 configured resident berth IDs;
- 64 active streamed berths across 32 active locations;
- 16 berths in one streamed location;
- 128 tracked berth IDs and 64 tracked location IDs including tombstones;
- positive exact integer identities/generations through
  `9,007,199,254,740,991`, with a load generation reserving its immediate
  retirement successor.

Stable IDs are 1–64 lowercase ASCII letters, digits, and single underscores,
without a leading/trailing underscore or repeated underscores. Mutation and
signal dispatch are guarded: callbacks observe committed post-state, may read
detached snapshots, and cannot register, retire, or reconfigure synchronously.

The audit publishes the project's exact common 12-key all-false authority
roster: renderer, gameplay, streaming, save, network, physics, world generation,
terrain generation, collision generation, origin shift, weather clock, and
audio. Its adjacent roster also denies scene-tree mutation, berth lease,
reservation, occupancy, ship-token, landing, ship-movement, cargo, route,
reward, and UI authority. In particular, this overlay never loads or unloads a
location, reparents/frees a node, reserves/occupies/releases a berth, moves a
ship, decides landing, transfers cargo, grants rewards, or persists state.

## Focused evidence

`tests/streamed_ship_berth_overlay_test.gd` uses the real
`WorldStreamingCoordinator` and packed `ShipBerth` fixtures. It covers atomic
invalid and duplicate rosters, resident/global collisions, exact Cinder-style
provenance and sorted tags, merged reads, detached payloads, callback re-entry,
whole-coordinator detach/re-entry, exact `N + 1` unload, generation-3 reload,
delayed generation-2 rejection, independent removal, queued berth/root
fail-closed behavior, one batch tombstone, deterministic chronology, and the
complete authority and bounded-schema reports.
