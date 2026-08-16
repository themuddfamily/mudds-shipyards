# Station walkable-area census

Run the production census with:

```sh
godot --headless --audio-driver Dummy --path . --script res://tools/station_walkable_area_census.gd
```

The `production_station_walkable_collision_v1` profile measures only enabled,
World-layer `BoxShape3D` top faces that are explicitly in the production roster
or publish the live metadata contract below. It measures the instantiated
`shipyard_world.tscn`, not authored dimensions copied into the tool. Each
surface is sampled at its centre and four inset points with downward physics
rays. A missing shape, duplicate identity/body, unsupported shape, wrong
collision policy, implausible normal, or absent live support invalidates the
report.

Horizontal usable area is the top-face area projected onto XZ. Coplanar level
surfaces are geometrically unioned by elevation, so intentional construction
laps at station handoffs cannot count one footprint twice. Sorted detail rows
retain both the raw per-surface projection and the deterministic incremental
union contribution. Inclined ramps are distinct planes: their horizontal
projection and true inclined surface area are reported separately.

Ships and ship interiors, vehicles, roofs/ceilings, decorative tops, void, and
`NearbySectorCluster` destination geometry are excluded because they are not
declared walkable station surfaces. Fixtures do not subtract from the usable
circulation envelope. Entry boxes whose projection is already owned by a floor
are not separately declared.

Later modules opt in by setting these metadata values on each authoritative
walkable `StaticBody3D`:

```gdscript
body.set_meta("walkable_surface", true)
body.set_meta("walkable_surface_id", &"stable-unique-id")
body.set_meta("walkable_surface_owner", &"stable_module_owner")
body.set_meta("walkable_surface_kind", &"level") # or &"ramp"
```

The aggregate JSON includes its schema/profile, Godot version, Git source SHA,
owner totals, support counts, and exact six-decimal area totals. At the current
production baseline it reports 54 surfaces, including three ramps:

- Raw declared horizontal projection: **7,103.199985 m²**
- Counted coplanar-unioned horizontal area: **6,849.844560 m²**
- Counted true surface area: **6,857.712521 m²**
- Ramp projection / true area: **68.480000 / 76.347961 m²**

For an expansion target of 18–22% measured by the same profile, the required
net addition is **1,232.972021–1,506.965803 m²**, producing a total of
**8,082.816581–8,356.810363 m²**. Compare the merged production run to this
frozen baseline; do not compare raw declarations, which include handoff laps.
