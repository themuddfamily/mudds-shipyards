# Station defense activity foundation

`StationDefenseContract` and `StationDefenseActivity` provide a data-only Phase
8 objective authority for defending station assets across finite hostile waves.
They are not wired into the production game.

The contract snapshots:

- 1–16 waves, each with a stable ID, `ORDERED` or `SIMULTANEOUS` mode, a
  caller-physics delay, and 1–64 hostile `{ hostile_id, generation }` handles;
- up to 256 unique hostiles across the contract;
- 1–64 protected `{ asset_id, generation }` handles; and
- a finite positive overall timeout of at most 24 hours.

The activity exposes `start`, `advance`, `hostile_destroyed`,
`protected_asset_damaged`, `protected_asset_destroyed`, `fail`, `abort`,
`reset`, `detach`, and `reattach`. Every mutator requires the current activity
generation. Damage observations also require a unique generation-bearing event
handle, with a 1,024-entry bounded ledger; one slot is reserved so damage-event
noise cannot hide the first protected-asset destruction.

Only `advance(delta, generation)` changes wave-delay or timeout clocks. Process
and render frames do nothing. Ordered waves accept exactly the next hostile;
simultaneous waves accept any remaining hostile in the current wave. Completion
commits and signals once after every exact hostile handle is accepted. Protected
asset destruction fails the activity; damage observations alone do not.

`get_snapshot()` is deeply detached and HUD-ready, including state, wave mode
and countdown, active hostile handles, remaining counts, timeout, protected
asset evidence, and failure reason. Lifecycle signals receive separate detached
copies and reject synchronous mutator reentry. `audit()` publishes deterministic
limits, invariants, and exact authority exclusions.

Focused proof:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/station_defense_activity_test.gd
```

## Deliberate limitations

- Callers must source truthful destruction/damage observations and stable
  generations. This foundation does not authenticate them against combat or
  damage authorities.
- It owns no combat resolution, spawning, damage application, rewards, ships,
  berths, station/world geometry, HUD, `GameFlow`, `Main`, save, or network
  authority.
- It creates no enemies, protected objects, scenes, routes, cues, audio,
  failure recovery, or production station-defense activity.
- The timeout is one overall activity deadline; there are no per-hostile
  deadlines, scores, repair rules, partial asset-health model, or persistence.
- Source tests are not packaged route, balance, multiplayer, performance,
  presentation, or human-play evidence.
