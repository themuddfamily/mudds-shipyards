class_name ShipSurfaceDetail
extends RefCounted

## Shared surface treatment for the fleet's secondary structure.
##
## Every craft in the fleet renders as two visual populations. Hull lofts and
## authored hull shells are bound to a registered albedo/normal/roughness map
## family and read as manufactured plate. Secondary structure — engine
## housings, landing gear, collars, sensor masts, escape pods, cargo hardware,
## deck plate, thermal panels — was left on a flat scalar `albedo_color` with
## no maps at all and with every craft's structural roughness clustered inside
## a band roughly 0.1 wide, so those parts differed from one another in hue and
## in nothing else. Flat colour plus one shared specular response is what reads
## as an untextured primitive.
##
## `bind_structural_detail` closes that gap without inventing a second look. It
## binds the craft's own already-registered normal map — and, for machined
## metal, its roughness map — to a structural material through triplanar
## projection at a finer scale than that craft's hull uses, so the secondary
## structure gains surface relief and a varying specular response while staying
## inside its own registered material family.
##
## What it deliberately does not do:
##
## - It never binds an albedo texture. The scalar `albedo_color` is the value
##   `tests/fleet_role_differentiation_test.gd` measures for the frozen
##   CIEDE2000 body and accent floors, and it stays exactly as authored.
## - It authors no UVs and moves no vertex, so no silhouette changes and no
##   craft's evidence-bounded macroform is touched.
## - It leaves `uv1_triplanar` alone on hull materials, whose UV0 texture-
##   coordinate authority is declared in the Torrent and Zenith presentation
##   audits.
##
## Provenance: the bound maps are the project's existing procedurally generated
## material maps, reused here at a second projection scale. Nothing in this
## helper is authored, baked or scanned surface art.


## Lateral wall subdivision for every chamfered cylinder and frustum the fleet
## builds, replacing the `CylinderMesh.rings = 4` default that
## `StationSurfaceKit.CYLINDER_DEFAULT_RINGS` mirrors.
##
## Why zero is not a quality reduction. A capped cylinder's wall quad between two
## adjacent radial angles is *planar*: on a straight cylinder both of its side
## edges are vertical, and on a frustum both are generators that meet at the
## cone apex, so the apex and the two lower corners already define the plane the
## two upper corners lie in. Splitting that planar quad horizontally puts the new
## vertices exactly on the same plane, at exactly the linear parameter the
## interpolator would have produced anyway:
##
## - position — `_add_cylinder_band` places ring `k` at `lerp(bottom_y, top_y,
##   k/n)` with `_radius_at` linear in y, so every intermediate ring sits on the
##   generator line, not inside or outside it. No silhouette moves.
## - normal — the band normal is the perpendicular of the profile *tangent*, and
##   a wall's profile is one straight segment, so every sub-band is handed the
##   identical normal. There is no curvature along the wall for extra rings to
##   resolve.
## - UV — the axial coordinate is `(y + half_height) / height`, linear in y, so a
##   subdivided quad reproduces the same linear function it interpolates from.
##
## The extra rings therefore only ever mattered to something that samples per
## *vertex* rather than per pixel. Checked before taking this: every ship
## material is `SHADING_MODE_PER_PIXEL` (the one exception, the range opponent's
## smoke quad, is `UNSHADED` and is not a cylinder), the fleet binds no
## `ShaderMaterial` and no vertex-displacement or per-vertex-colour effect, and
## the structural relief above is world-triplanar, which Godot samples by world
## position and not by any interpolated vertex channel.
##
## Measured, not assumed, and the honest number is not zero. Over 42 fixed
## 2560x1440 views of the six craft — 154,828,800 pixels, clocks pinned at
## `--fixed-fps 60` with every craft's `process_mode` disabled before the first
## frame — dropping the four rings changes 3,049 px, 0.00197%. Read that in two
## halves:
##
## - Torrent, Arrow, Jovian and Zenith render bit-identically across two runs of
##   the *same* build, so their diff is all signal: 1,468 px of 77,414,400
##   (0.0019%). 1,316 of those differ by 1 or 2 of 255 — sub-quantisation
##   interpolation noise from the vertex positions being computed by a different
##   arithmetic path. 28 exceed 32 of 255, and every one of the 28 is an
##   *isolated single pixel*: connected-component analysis finds 28 clusters of
##   size 1, which is rasterizer edge tie-breaking, not a silhouette. A moved
##   silhouette would be a connected contour hundreds of pixels long.
## - The two range opponents carry a thin emissive telegraph sliver that this
##   machine's llvmpipe rasterizes non-deterministically: two runs of the same
##   build differ by 1,326 and 1,398 px there. Their 1,581 px across the change
##   is inside that floor and is not evidence of anything.
##
## No AABB moves — `tests/fleet_surface_detail_test.gd` checks that directly at
## every live radial-segment count, on straight stock and on tapers both ways —
## and no collision shape is involved: the ship builders construct their
## colliders from the same radius/height arguments and never read this mesh.
##
## What this reduction does *not* extend to, measured on the same 42 views so
## nobody re-chases it. The fleet's other density knobs sit on curved surfaces,
## where subdivision is the silhouette and taking it is a quality trade, not a
## free saving:
##
## - `_sphere` (Torrent/Jovian 24x12, Arrow 28x14) at 16x8 / 18x9 saves 33,552
##   fleet triangles and moves 343,685 px — 113x this change — with coherent
##   clusters up to 967 px on the Zenith's engine spheres. Rejected.
## - `_torus` (Torrent/Jovian 48x16, Arrow 64x18) at 32x10 / 40x12 saves 28,672
##   triangles and moves 141,462 px, 6,602 of them beyond 32 of 255, almost all
##   of it visible faceting on the Arrow's engine collars. Rejected.
##
## Both were rejected on the rendered evidence, not on principle: a cylinder
## wall is flat along its axis and a sphere is not, and that difference is the
## whole reason one reduction is free and the other is not.
const CYLINDER_WALL_RINGS := 0


## Binds a structural material to its craft's registered relief maps.
##
## `texture_scale` is a triplanar `uv1_scale`, so a larger number tiles the map
## more times per world metre and yields smaller features; every caller passes
## a value above its craft's hull scale so secondary structure reads at a
## machined-part frequency rather than at hull-plate frequency.
##
## Only the normal map is bound, never a roughness map. The registered
## roughness maps average roughly 0.44 and multiply the scalar, so a structural
## material carrying one renders at less than half its authored roughness and
## can never exceed about 0.6 however high the scalar goes. Leaving them off
## keeps `roughness` on these materials equal to the roughness the player
## actually sees, which is what makes the fleet-wide spread in
## `tests/fleet_surface_detail_test.gd` a meaningful measurement rather than a
## number that has to be mentally multiplied per craft.
##
## Returns `true` when the material was actually treated, so callers can audit
## the treatment rather than assume it.
static func bind_structural_detail(
		material: StandardMaterial3D,
		normal_map: Texture2D,
		texture_scale: float,
		normal_strength: float,
		triplanar_sharpness: float = 4.0
	) -> bool:
	if material == null or normal_map == null:
		return false
	material.normal_enabled = true
	material.normal_texture = normal_map
	material.normal_scale = normal_strength
	material.uv1_triplanar = true
	material.uv1_triplanar_sharpness = triplanar_sharpness
	material.uv1_scale = Vector3.ONE * texture_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return true


## True when a material carries the structural treatment above. Used by the
## focused regression so the treatment cannot silently fall off a craft.
static func has_structural_detail(material: StandardMaterial3D) -> bool:
	return (
		material != null
		and material.normal_enabled
		and material.normal_texture != null
		and material.uv1_triplanar
		and material.albedo_texture == null
		and material.roughness_texture == null
	)
