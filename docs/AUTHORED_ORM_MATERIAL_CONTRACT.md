# Authored/baked/ORM material contract

`tools/materials/orm_material_validator.py` defines the metadata seam for the
remaining station material work. Each material records its source mesh, visual
role, and the intended provenance of albedo, normal, roughness, metallic, and
packed ORM maps. Packed ORM uses the fixed convention **R = occlusion, G =
roughness, B = metallic**.

The checked-in contract is deliberately `metadata_only`. It documents where a
human artist's source mesh and bake output will attach; it does not create
textures, measure normal quality, establish texel density, or claim that a
procedural/derived map is authored, baked, or scanned. The validator rejects a
future `authored`, `baked`, or `scanned` status until that evidence is supplied.

When the artist pass begins, add a contract JSON beside its source manifest and
change map rows to point at real outputs. Keep the source mesh and bake recipe
versioned, preserve the channel mapping, and add a focused review record for
lighting and material readability. This contract alone does not close the
roadmap's human-art or visual-review gates.

Validate with:

```sh
python3 -m unittest tools.materials.test_orm_material_validator
python3 tools/materials/orm_material_validator.py path/to/contract.json
```
