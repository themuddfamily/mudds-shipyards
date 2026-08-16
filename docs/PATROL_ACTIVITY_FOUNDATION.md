# Patrol activity foundation

`PatrolActivity` is a production-neutral `RefCounted` authority that composes an
already registered checkpoint route. The first fixture deliberately reuses
`cinder_reach_checkpoint_route.tres`: its five navigation beacons form an honest
outbound inspection sweep, and reuse prevents a second copy of those world
coordinates or checkpoint radii.

The shared definition remains the checkpoint-volume contract. Entering its next
volume opens a configured continuous dwell; only finite caller-supplied physics
delta accumulates, and leaving that same volume resets partial dwell. Once dwell
finishes, `ActivityDirector` commits the ordered checkpoint, keeping abort/fail
available throughout the dwell instead of completing the underlying route
early. Detached snapshots expose patrol and director generations, travel/dwell
phase, ordered progress, dwell remaining, current/last duration, occupancy, and
terminal reason for a future HUD.

The authority supports attach/detach re-entry, start, position submission,
physics advance, abort, fail, reset, and close. Every mutation requires the
current patrol generation and rejects signal-subscriber re-entry. A mapped
checkpoint mismatch fails closed instead of publishing divergent progress.

This foundation owns no world nodes, rewards, gameplay lifecycle, HUD,
`GameFlow`, ship, combat, berth, persistence, or networking behavior. It is one
finite outbound sweep, not a repeating/branching patrol, and it cannot run at
the same time as the timed race on the same director because both intentionally
share one Cinder route activity ID. Production route selection, continuous
position sampling, presentation, recovery policy, and rewards remain future
integration work.
