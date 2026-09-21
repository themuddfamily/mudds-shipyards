# Common-world origin rebase owner

Production `Main` owns one lifetime-stable `CommonWorldOriginRebaseOwner`. On a
GameFlow physics tick, the existing single ship-or-player position read is first
encoded by `EmberMoonStreamingProductionBinding`. At the inclusive 10,000 m
threshold the owner synchronously validates the exact actor/frame/absolute
coordinate, captures the live spatial roster, requests the exact frame rebase,
translates every direct Main `Node3D` plus every nested `top_level` `Node3D`,
verifies authoritative roots by their exact global delta and ordinary descendants
by unchanged local transforms, then mirrors every exact covered live
`CollisionObject3D` global transform into `PhysicsServer3D`. Physics bodies use
`body_set_state(BODY_STATE_TRANSFORM)` and areas use `area_set_transform`; the
owner exposes the frame commit only after that roster is synchronized. It then
commits the request and reconciles the Ember binding to the target generation. GameFlow
then gives Cinder and activity consumers the adjusted detached sample without a
second actor read.

There is no await or deferred boundary inside the transaction. Invalid, stale,
queued, detached, or mismatched identities fail before mutation. Translation or
commit failure restores every translated root and cancels the matching pending
request. Rollback also restores every captured descendant local transform, so
derived SpringArm/camera responses cannot leak from a rejected transaction. The
same rollback synchronously restores the covered body and area server transforms;
if that restoration cannot be proven, the owner returns the distinct fail-closed
`collision_transform_rollback_desynchronized` result rather than claiming an
atomic rollback. The committed signal fires only after state is final and rejects
synchronous re-entry.

Normal descendants inherit their direct root shift. Nested `top_level` nodes are
shifted separately. Active pulse slots and queued damage-presentation receipts
block rebasing because they retain extra absolute coordinates that node
translation alone cannot rewrite honestly. Loaded Cinder/Ember roots are
non-top-level coordinator descendants and move with their bootstrap without a
streaming-generation change.

One narrow 0.10 m local response allowance applies only to `Camera3D` and
`SpringArm3D` nodes beneath `Player/CameraRig`: those engine-derived nodes
immediately resolve against newly shifted collision during the synchronous
transform notification (measured response 0.0312 m). Direct/top-level roots and
every physical, collision, authored-content, and streamed descendant retain
exact transforms; large-coordinate float quantisation is avoided by verifying
ordinary descendants in their unchanged local frame.

The owner controls only coordinate-frame rebase request/commit, common-world
translation, and the matching transform synchronization for the exact covered
collision roster. It owns no collision query, shape construction, collision or
landing decision, velocity integration, or second physics simulation. It has no
activity, combat, gameplay, landing, ship-flight, reward, save, network, or
streaming load/unload/generation authority. The same owner, bootstrap, binding,
frame, and counters survive whole-Main detach/re-entry.

The remaining player-facing gap is travel and landing orchestration: no
production travel session selects Ember, transitions orbit/atmosphere/descent,
or grants a landing. This owner only makes the existing absolute Ember streaming
composition spatially reachable without losing local precision.

## Serving more than one world

The owner is world-plural. It binds every `PlanetaryStreamingProductionBinding`
composed beside it, pairs each with the bootstrap that binding resolved and with
that bootstrap's own `PlanetaryCoordinateFrame`, and routes each transaction to
the world its preview names. `bind_world()`, `unbind_world()` and
`rebind_composed_worlds()` are the seams for a world that composes or retires;
all three are fenced and refuse while a transaction is in flight. An unnamed or
unbound world is refused as `unbound_rebase_world` rather than served by the
wrong frame.

The common world is shared, so one committed translation moves every bound
world's local space at once. A transaction therefore opens a pending rebase on
*every* bound frame for the same focus - either all are pending or none is - and
the requesting world commits first, while the whole transaction is still
reversible and a refused commit still cancels every pending request and restores
every root, derived local transform and PhysicsServer transform. The remaining
frames commit after it; a refusal there is an invariant breach reported
fail-closed as `common_world_frame_commit_desynchronized`, exactly as a refused
binding acceptance already is. A world left at its old generation would have had
its bootstrap root translated out from under it and would have refused every
later focus update, which is precisely what an Ember expedition would have done
to Aurora the moment a second world was composed.

Node translation is announced before any adapter is asked to accept, because a
streamed world root re-expresses away the float rounding the translation just
introduced and the accepting adapter audits that exact alignment. Each streamed
root is told the generation *its own* frame reached, which is not the requesting
world's. Worlds that did not ask are then reconciled through
`accept_common_world_translation()`, which advances their bound generation and
re-derives their retained local position from their unchanged absolute
coordinate. It cannot request, commit or re-evaluate streaming.

The root rule no longer names a class. A node is a common-world root unless it
declares `is_common_world_translation_root()` returning `false`; that is the
capability `EmberSurfaceLoopHost` declares, because it is a logic node pinned to
Main's own origin and is the reference identity a surface visit measures
against. `EmberSurfaceLoopHost` mirrors the same rule when it rebuilds the
roster a receipt froze.

The receipt names the world it acted for and carries the per-world generation
roster, and every consumer checks it: a Host refuses a receipt for another body,
and the surface-loop binding refuses an origin result for another body.
