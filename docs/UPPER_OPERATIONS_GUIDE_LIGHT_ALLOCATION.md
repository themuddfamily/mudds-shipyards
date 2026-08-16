# UpperOperations guide-light retained-resource trim

`ShipyardWorld._add_guide_light()` builds 51 presentation-only guide pairs,
including the one observation-post practical under `UpperOperations`. Every lens
was already an identical childless `MeshInstance3D` with a 0.16 m `SphereMesh`;
its material was one of four identical emissive recipes. The old helper retained
a new mesh and material for every call.

The bounded change shares one sphere resource and one material per color recipe.
It does not batch nodes or remove lights.

| renderer-independent measure | before | after | delta |
| --- | ---: | ---: | ---: |
| retained guide mesh/material identities | 102 | 5 | -97 |
| guide scope nodes (51 lenses + 51 lights) | 102 | 102 | 0 |
| structural mesh-surface submissions | 51 | 51 | 0 |

The submission number is one surface on each live lens `MeshInstance3D`; it is
not a measured driver draw-call count. No frame-time, GPU-time, draw-call, VRAM,
or whole-scene budget improvement is claimed.

The focused audit freezes all 51 light paths, local positions, colors, authored
energy/range, shadow flags, pulse phases, and pulse bases under fingerprint
`d91c20a3aa38001b9a9171b56bec150059465ed703c95b1fd8a88dd3304ee20e`.
Explicit node names remain exact; Godot's process-local `@Class@instance`
fallback names are represented as deterministic same-class sibling ordinals,
matching the station light census policy. Unrelated modules can therefore add
nodes without falsifying an otherwise unchanged guide-light baseline.
It also freezes the sphere tessellation and four material recipes. The
UpperOperations pair remains at `(-12.75, 4.45, 2.4)`, cyan, energy `1.2`, range
`5.5`, shadowless and non-pulsing. Collision, routes, evidence, semantics,
authority, node hierarchy and lifecycle are unchanged.

## Verification and limits

Run the focused suite with:

```sh
godot --headless --audio-driver Dummy --path . \
  --script res://tests/upper_operations_allocation_test.gd
```

The suite checks exact counts/deltas, detached audit data, mesh/material and
private-copy mutations, an injected authority-shaped child, and whole-world
detach/re-entry identity. Shared resources are mutable Godot resources rather
than engine-frozen objects; unintended mutation is detected by the audit but is
not prevented at assignment time.

No Forward+ comparison was run. Resource identity is the only render-side
change: mesh dimensions/tessellation, material parameters, every transform, and
every visible node/submission are exact equalities, so this candidate cannot
change pixels without first failing the focused recipe or behavior contract.
Other station spheres/materials, light count, submissions, node count and native
performance remain untouched and unmeasured.
