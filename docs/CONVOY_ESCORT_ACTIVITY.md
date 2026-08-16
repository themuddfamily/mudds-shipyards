# Convoy escort activity foundation

`ConvoyEscortActivity` is a production-neutral lifecycle authority for one
protected convoy run. It snapshots a valid checkpoint-route definition already
registered with `ActivityDirector`; those ordered checkpoint positions become
convoy legs, and the definition radius remains the leg-arrival radius.

Each start binds both a stable convoy ID and its caller-owned entity generation.
Every later sample must match the activity generation and that exact convoy
identity/generation. A caller submits finite convoy and escort positions plus an
`ACTIVE`, `DESTROYED`, or `LOST` entity status. Reaching the last ordered leg is
safe arrival only while the escort is inside the configured proximity radius.

Time is explicit:

- Samples never advance time.
- `advance_physics(delta, generation)` advances the overall timeout.
- While the last sample is outside escort proximity, the same caller delta also
  advances continuous separation time; a new in-range sample resets it.
- Separation failure wins deterministically if separation and timeout cross on
  the same tick.
- Tree frames, detach/re-entry, and wall time do nothing.

All lifecycle signals fire after state is committed and reject nested start,
sample, physics, abort, or reset mutations. `get_snapshot()`/`audit()` return
detached HUD-ready dictionaries containing identifiers, ordered-leg progress,
next position, proximity, remaining times, and terminal result.

This foundation does not move or spawn entities, apply combat/damage, grant
rewards, transfer cargo, choose ships/berths, drive `GameFlow` or HUD, persist
saves, replicate network state, or add geometry. No existing nearby-sector route
is claimed as a convoy route; production content and adapters remain future work.
