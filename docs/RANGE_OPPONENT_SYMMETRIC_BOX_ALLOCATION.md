# RangeOpponent symmetric-box retained-resource trim

The base `RangeOpponent` hull builds four exact port/starboard box families:
`ProngInset`, `SweptBrace`, `OuterVane`, and `VaneTip`. Before this change each
of the eight childless `MeshInstance3D` nodes retained a private `BoxMesh`, even
though the two members of every family had the same size and material recipe.
Only their node transforms differed.

No pre-existing script or test consumed these names or paths. The nodes carry no
children, metadata, scripts, processing, collision, target, projectile, damage,
movement, encounter, or lifecycle authority. The state-driven weapon telegraphs,
engine plumes/lights, muzzle markers, damage emitters, physical debris, and all
seven authoritative hull collision shapes remain outside this scope.

The bounded change shares one mesh inside each family. It does not use
`MultiMesh`, remove nodes, merge submissions, or change materials/transforms.

| RangeOpponent-local measure | before | after | delta |
| --- | ---: | ---: | ---: |
| paired hull-box nodes / visible copies | 8 | 8 | 0 |
| structural mesh-surface submissions | 8 | 8 | 0 |
| paired hull-box mesh identities | 8 | 4 | -4 |
| material identities referenced by the scope | 4 | 4 | 0 |
| mesh + material identities referenced by the scope | 12 | 8 | -4 |

`get_symmetric_hull_box_allocation_audit()` freezes all four recipes, both exact
transforms per family, material identity, visibility/layer/shadow defaults,
childlessness, and authority/lifecycle exclusions. The directly related combat
suite also mutates the shared `OuterVane` size, substitutes an exact-looking
private mesh, injects an `Area3D`, restores each mutation, and rechecks the audit
after whole-node detach/re-entry. The remainder of that suite continues through
activation, health/damage/death/reactivation, seven-collider identity, deferred
presentation ordering, bounded receipts, movement, targeting, weapon timings,
vertical projectiles, and cleanup.

## Verification and limits

Run the focused suite with:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/combat_test.gd
```

No Forward+ comparison is needed for this resource-identity-only slice: every
rendered primitive recipe, material, transform, copy, and structural submission
is an exact equality. Shared Godot resources remain mutable; the audit detects
unintended mutation but does not prevent assignment-time mutation.

This is not evidence for driver draw calls, frame time, GPU time, VRAM, a
whole-scene budget, or representative hardware performance. Derived opponent
hulls keep their existing builders and allocations. No encounter, combat,
damage, movement, projectile, target, collision, timing, semantic-path, or
lifecycle authority changed.
