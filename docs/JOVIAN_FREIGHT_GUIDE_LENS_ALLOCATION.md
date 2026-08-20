# Jovian freight guide-lens allocation

`JovianFreightBerth` retains all eighteen named `DockGuideLens` renderer nodes,
their eighteen individual material identities, eighteen guide lights, and
eighteen housing nodes. They now share one immutable one-surface `SphereMesh`
with the exact 0.13 m radius, 0.26 m height, 12 radial segments, and six rings.
This changes component-local mesh identities from 18 to 1 (-17); it does not
batch geometry or share materials, remove nodes, change lights/collision/routes,
or claim draw-call, frame-time, GPU, or VRAM improvement.

`get_guide_lens_visual_allocation_audit()` verifies the exact renderer,
material-colour, housing/light, and no-authority rosters. The focused
`jovian_freight_berth_batch_test.gd` proves the green audit, a deliberately
escaped lens mesh red, and repair. Whole-scene census effects are measured in a
separate batch rather than inferred here.
