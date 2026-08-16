# ExteriorTargetRange core retained-resource trim

`ShipyardWorld` builds four independently moving and independently destructible
range targets. Each target retains a named childless
`TargetDroneNN/DroneVisual/Core` sphere. Before this change the four cores used
the same geometry and existing shared `orange_glow` material, but each retained
a private `SphereMesh`.

The first safe visual-only opportunity is therefore to share only that mesh.
The targets cannot be combined into a `MultiMesh`: their `StaticBody3D` parents
move on separate phases, carry separate target/collision/damage identity, and
leave play independently. This change does not remove, rename, reparent, or
batch any core.

| ExteriorTargetRange core measure | before | after | delta |
| --- | ---: | ---: | ---: |
| core nodes / visible copies | 4 | 4 | 0 |
| structural mesh-surface submissions | 4 | 4 | 0 |
| core mesh resource identities | 4 | 1 | -3 |
| referenced material identities | 1 | 1 | 0 |
| retained mesh + material identities | 5 | 2 | -3 |

Each copy retains its exact zero local transform, unit scale, visibility, layer,
shadow mode, `orange_glow` material, and one surface. The shared `SphereMesh`
keeps the former `1.4` radius, `2.8` height, 24 radial segments, and 12 rings.

`get_exterior_target_core_allocation_audit()` freezes those component-local
facts. It rejects recipe, resource-identity, transform, material, submission,
child, metadata, processing, script, collision, navigation, light, audio, or
camera drift beneath the core nodes. Its dictionaries and arrays are deeply
detached. The focused outbound-range regression mutates the shared recipe,
substitutes an exact-looking private mesh, injects authority, restores each
case, and detaches/re-enters the same range while preserving core and target
collider identities.

## Authority boundary and verification

The core nodes own no target registration, collision, combat, damage, movement,
lifecycle, launch clearance, range cue, or evidence state. Those contracts stay
on the existing target/world systems and their existing semantic paths.
`outbound_route_clearance_test.gd` freezes the range positions, physical gate,
clear lane, cue geometry, target count, allocation, and detach/re-entry path.
`live_combat_integration_test.gd` continues to exercise real target adaptation,
hits, lethal damage, mission counting, presentation, and cleanup.

No Forward+ comparison is needed for this resource-identity-only slice: mesh
recipe, material, visible copies, transforms, and submissions are exact
equalities. Shared Godot resources remain mutable; the audit detects mutation
but does not make the resource intrinsically immutable.

This is not evidence for batching, driver draw calls, frame time, GPU time,
VRAM, whole-scene budgets, representative hardware, or pixel improvement. It
changes no target, collision, combat, damage, movement, launch-clearance, cue,
evidence, or lifecycle authority. Target lamps/rings/arms, burst fragments, and
all other ExteriorTargetRange allocations remain outside this bounded slice.
