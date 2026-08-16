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
