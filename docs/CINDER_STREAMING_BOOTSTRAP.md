# Cinder Reach streaming bootstrap

`CinderStreamingBootstrap` is an opt-in composition resource for the existing
Cinder Reach content. It binds `cinder_reach.tres` and
`nearby_sector_cluster.tscn` to one `WorldStreamingCoordinator` and one
`WorldStreamingDistancePolicy` without adding either to `Main` or
`ShipyardWorld`.

Its fixed navigation-distance contract is:

- Load at or inside 500 metres from the Cinder platform anchor.
- Unload only outside 650 metres, leaving a 150-metre hysteresis band.
- Place the cluster scene root at its explicit zero scene origin; its authored
  station-world children are not translated by the platform anchor again.
- Attempt at most one coordinator transition per explicit update.

The bootstrap has no `_process()` or `_physics_process()` loop. A future world
owner must call `update_position(position)`, or retain a finite sample with
`set_tracked_position(position)` and call `physics_tick(delta)`/`update_now()`.
Clearing tracking preserves existing loaded/loading state.

The checked PackedScene binding is the default deferred loader. Hosts may set an
explicit coordinator-compatible loader before the first request. Snapshots and
audits are detached dictionaries and expose no Node, Resource, Callable, or
collection mutation authority.

This component owns no gameplay, mission, activity, objective, reward, ship,
berth, save, network, or production-world integration authority.
