# Common-world origin rebase owner

Production `Main` owns one lifetime-stable `CommonWorldOriginRebaseOwner`. On a
GameFlow physics tick, the existing single ship-or-player position read is first
encoded by `EmberMoonStreamingProductionBinding`. At the inclusive 10,000 m
threshold the owner synchronously validates the exact actor/frame/absolute
coordinate, captures the live spatial roster, requests the exact frame rebase,
translates every direct Main `Node3D` plus every nested `top_level` `Node3D`,
verifies authoritative roots by their exact global delta and ordinary descendants
by unchanged local transforms, commits the
request, and reconciles the Ember binding to the target generation. GameFlow
then gives Cinder and activity consumers the adjusted detached sample without a
second actor read.

There is no await or deferred boundary inside the transaction. Invalid, stale,
queued, detached, or mismatched identities fail before mutation. Translation or
commit failure restores every translated root and cancels the matching pending
request. Rollback also restores every captured descendant local transform, so
derived SpringArm/camera responses cannot leak from a rejected transaction. The
committed signal fires only after state is final and rejects
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

The owner controls only coordinate-frame rebase request/commit and common-world
translation. It has no activity, combat, gameplay, landing, ship-flight, reward,
save, network, or streaming load/unload/generation authority. The same owner,
bootstrap, binding, frame, and counters survive whole-Main detach/re-entry.

The remaining player-facing gap is travel and landing orchestration: no
production travel session selects Ember, transitions orbit/atmosphere/descent,
or grants a landing. This owner only makes the existing absolute Ember streaming
composition spatially reachable without losing local precision.
