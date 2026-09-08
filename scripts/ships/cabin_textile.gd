class_name CabinTextile
extends RefCounted

## Registered scanned twill maps, reused by every cabin finish. Local-metre
## triplanar projection survives merged furniture and UV-less legacy cushions;
## it follows the ship rather than swimming through the fabric in world space.
const COLOR := preload("res://assets/materials/cabin-textile/Fabric069_1K-PNG_Color.png")
const NORMAL := preload("res://assets/materials/cabin-textile/Fabric069_1K-PNG_NormalGL.png")
const ROUGHNESS := preload("res://assets/materials/cabin-textile/Fabric069_1K-PNG_Roughness.png")

static func apply(material: StandardMaterial3D, tile_metres := 0.42) -> void:
	# Remove the source denim's mean blue dye in the material multiplier, leaving
	# its photographed yarn variations intact and retaining each ship's palette.
	if not material.has_meta(&"cabin_textile_dye"):
		material.set_meta(&"cabin_textile_dye", material.albedo_color)
	var dye: Color = material.get_meta(&"cabin_textile_dye")
	var linear_dye := dye.srgb_to_linear()
	# Means were measured after decoding the source sRGB pixels to linear light.
	material.albedo_color = Color(linear_dye.r / 0.05806121,
		linear_dye.g / 0.09657842, linear_dye.b / 0.24557468, dye.a).linear_to_srgb()
	material.albedo_texture = COLOR
	material.metallic = 0.0
	material.metallic_specular = 0.18
	material.roughness = 1.0
	material.roughness_texture = ROUGHNESS
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = NORMAL
	material.normal_scale = 0.8
	material.uv1_triplanar = true
	material.uv1_world_triplanar = false
	material.uv1_triplanar_sharpness = 8.0
	material.uv1_scale = Vector3.ONE / tile_metres
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.clearcoat_enabled = false
	material.rim_enabled = true
	material.rim = 0.12
	material.rim_tint = 0.65
