# Explicit world-streaming distance policy

`WorldStreamingDistancePolicy` is the automatic decision layer above
`WorldStreamingCoordinator`; it is not a second scene or generation authority.
The policy registers a frozen navigation anchor with two radii, reads the
coordinator's public loaded/loading IDs, and calls its public load/unload
requests. `WorldLocationDefinition.scene_origin_position` is intentionally not
part of distance evaluation; it controls coordinator placement only.

## Contract

- `load_radius` is inclusive. An unloaded location is eligible at or inside it.
- `unload_radius` is exclusive and must be larger. A loaded or loading location
  is eligible for unload only after moving outside it.
- The band between those values retains current coordinator state, preventing a
  position fluctuating near one threshold from loading and unloading every tick.
- Each update sorts all eligible transitions by ascending distance, then stable
  location ID, and attempts at most the configured request budget. Rejected
  attempts consume budget because they are still coordinator calls.
- Request outcomes and aggregate counters commit before `transition_attempted`
  is emitted. While an update is active, signal observers may inspect detached
  snapshots but registration, unregistration, budget/tracking mutation, and
  nested updates reject or no-op; observer callbacks cannot perturb the
  in-progress candidate set.
- The policy never processes itself. `update_position()` is an explicit sample
  and update; `physics_tick(delta)` uses a previously supplied sample and only
  advances time from the caller's finite, non-negative delta; `update_now()` is
  an explicit update without time advancement.
- Physics time accumulation is preflighted before any update state changes. A
  finite delta that would overflow accumulated time is rejected as
  `time_overflow`, leaving the prior snapshot intact.
- `clear_tracked_position()` makes subsequent updates no-ops. It does not unload
  locations or cancel in-flight loads, so a temporarily missing pilot/camera/
  navigation source cannot empty the world.
- Coordinator outcomes, including generation and failure reason, are recorded
  verbatim. The next update re-reads actual coordinator state; it never assumes
  that an accepted async request is already loaded.
- Whole-policy or whole-coordinator detach/re-entry retains registration and
  coordinator state. No `_ready()` or engine-process callback replays requests.

This layer owns no objectives, rewards, ships, berths, saves, networking,
`GameFlow`, `Main`, or `ShipyardWorld` integration. A future integration owner
must choose the tracked world position, physics update point, definitions,
scenes, thresholds, and platform budgets.
