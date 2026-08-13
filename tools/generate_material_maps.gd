extends SceneTree

## Builds deterministic runtime-sized copies and registered image-derived maps
## for the modern Torrent hero trim atlas. The generated normal and roughness
## textures are restrained material aids inferred from visible colour/luminance;
## they are not geometry-derived or measured surface data.

const HERO_RUNTIME_SIZE := 1024

const HERO_SOURCE_CONTRACTS := {
	"trim": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-v1.png",
		"sha256": "21536687fe1b5b7ddba305f696d1e7a53f29bd14774db3ec1411af12b6622b76",
		"size": Vector2i(1254, 1254),
		"seam_classification": "intentional_uv_trim_atlas_not_tileable",
	},
	"flat_study": {
		"path": "res://assets/models/torrent/textures/torrent-hero-flat-albedo-study-v1.png",
		"sha256": "c480681c5c94ca7baa01668127f0084e61adbf86e8c3826dbe208b7f8c81f063",
		"size": Vector2i(1254, 1254),
		"seam_classification": "material_study_seams_unverified",
	},
}

const HERO_RUNTIME_PATHS := {
	"albedo": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png",
	"normal": "res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png",
	"roughness": "res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png",
	"orm": "res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png",
	"emissive": "res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png",
	"flat_study": "res://assets/models/torrent/textures/torrent-hero-flat-albedo-study-runtime-v2.png",
}

# The legacy v1 recipe remains available for a clean checkout where a derivative
# is absent. Existing legacy files are hash-validated and never overwritten.
const LEGACY_MATERIAL_SPECS := [
	{
		"source": "res://assets/materials/torrent-hull-albedo-v1.png",
		"normal": "res://assets/materials/torrent-hull-normal-v1.png",
		"roughness": "res://assets/materials/torrent-hull-roughness-v1.png",
		"normal_strength": 1.45,
		"roughness_base": 0.46,
	},
	{
		"source": "res://assets/materials/arrow-hull-albedo-v1.png",
		"normal": "res://assets/materials/arrow-hull-normal-v1.png",
		"roughness": "res://assets/materials/arrow-hull-roughness-v1.png",
		"normal_strength": 1.35,
		"roughness_base": 0.5,
	},
	{
		"source": "res://assets/materials/jovian-hull-albedo-v1.png",
		"normal": "res://assets/materials/jovian-hull-normal-v1.png",
		"roughness": "res://assets/materials/jovian-hull-roughness-v1.png",
		"normal_strength": 1.5,
		"roughness_base": 0.48,
	},
	{
		"source": "res://assets/materials/shipyard-deck-albedo-v1.png",
		"normal": "res://assets/materials/shipyard-deck-normal-v1.png",
		"roughness": "res://assets/materials/shipyard-deck-roughness-v1.png",
		"normal_strength": 1.65,
		"roughness_base": 0.58,
	},
]

const LEGACY_DERIVATIVE_HASHES := {
	"res://assets/materials/arrow-hull-normal-v1.png": "cae5b106246d7ab32f5b608c26df70e52548a1890c425fb51b5d692c43f1ec74",
	"res://assets/materials/arrow-hull-roughness-v1.png": "2391f4f3e5c9f2b2770d99a6aa6a093a4bef833e0b91a65410ae70426b2a5ae8",
	"res://assets/materials/jovian-hull-normal-v1.png": "f6fd6f501d5ced31cbb5a0e253e3c53e0ce4411206db677ce606eb4ffcb1a117",
	"res://assets/materials/jovian-hull-roughness-v1.png": "0c3623f918f0dcc0754cfdb16dbd529251eba68734bc4e0f60aa2fb2b9ba6918",
	"res://assets/materials/shipyard-deck-normal-v1.png": "49024f90ceb10c0cce703f64f6f8167c954fc7a440c4e8e003bf006dc0fd12de",
	"res://assets/materials/shipyard-deck-roughness-v1.png": "e9d256467f44f5e1d2925be69a81b3578602d3419af2d3d9458fed1d072dc720",
	"res://assets/materials/torrent-hull-normal-v1.png": "41158b76b1d0d17dd4fdc6881de3e7522ab2f74fad841fc6f541b01e56ecaa42",
	"res://assets/materials/torrent-hull-roughness-v1.png": "f630c58c11f1f8b1fa70617974f38da0e7cdcb97598400919510d6af6400e69c",
}


func _init() -> void:
	call_deferred("_generate_all")


func _generate_all() -> void:
	if not _validate_immutable_inputs():
		push_error("Torrent hero material inputs failed validation; no outputs were written")
		quit(1)
		return
	var legacy_regenerated := _restore_missing_legacy_derivatives()
	if legacy_regenerated < 0:
		push_error("Unable to restore one or more missing legacy v1 derivatives")
		quit(1)
		return

	var trim_source := _load_rgb_image(str(HERO_SOURCE_CONTRACTS.trim.path))
	var flat_source := _load_rgb_image(str(HERO_SOURCE_CONTRACTS.flat_study.path))
	if trim_source == null or flat_source == null:
		push_error("Unable to load validated Torrent hero material sources")
		quit(1)
		return

	var trim_runtime := _runtime_copy(trim_source)
	var flat_runtime := _runtime_copy(flat_source)
	var registered_maps := _derive_registered_maps(trim_runtime)
	var outputs := {
		str(HERO_RUNTIME_PATHS.albedo): trim_runtime,
		str(HERO_RUNTIME_PATHS.normal): registered_maps.normal,
		str(HERO_RUNTIME_PATHS.roughness): registered_maps.roughness,
		str(HERO_RUNTIME_PATHS.orm): registered_maps.orm,
		str(HERO_RUNTIME_PATHS.emissive): registered_maps.emissive,
		str(HERO_RUNTIME_PATHS.flat_study): flat_runtime,
	}

	for output_path: String in outputs:
		var image := outputs[output_path] as Image
		var save_error := image.save_png(ProjectSettings.globalize_path(output_path))
		if save_error != OK:
			push_error("Unable to save %s: %s" % [output_path, error_string(save_error)])
			quit(1)
			return
		print("GENERATED_TORRENT_HERO_MAP: %s" % output_path)

	print(
		"MATERIAL_MAP_GENERATION_OK: 6 Torrent hero runtime assets; "
		+ "%d legacy v1 derivatives preserved, %d regenerated from the v1 recipe"
		% [LEGACY_DERIVATIVE_HASHES.size() - legacy_regenerated, legacy_regenerated]
	)
	quit(0)


func _validate_immutable_inputs() -> bool:
	var valid := true
	for source_key: String in HERO_SOURCE_CONTRACTS:
		var source_spec: Dictionary = HERO_SOURCE_CONTRACTS[source_key]
		var source_path := str(source_spec.path)
		var global_path := ProjectSettings.globalize_path(source_path)
		var actual_hash := FileAccess.get_sha256(global_path)
		if actual_hash != str(source_spec.sha256):
			push_error(
				"Source hash mismatch for %s: expected %s, received %s"
				% [source_path, source_spec.sha256, actual_hash]
			)
			valid = false
			continue
		var image := Image.load_from_file(global_path)
		if image == null or image.is_empty() or image.get_size() != source_spec.size:
			push_error("Source dimension mismatch for %s" % source_path)
			valid = false

	for legacy_path: String in LEGACY_DERIVATIVE_HASHES:
		var global_path := ProjectSettings.globalize_path(legacy_path)
		if not FileAccess.file_exists(global_path):
			continue
		var actual_hash := FileAccess.get_sha256(global_path)
		var expected_hash := str(LEGACY_DERIVATIVE_HASHES[legacy_path])
		if actual_hash != expected_hash:
			push_error(
				"Legacy derivative changed before generation: %s (expected %s, received %s)"
				% [legacy_path, expected_hash, actual_hash]
			)
			valid = false
	return valid


func _restore_missing_legacy_derivatives() -> int:
	var regenerated := 0
	for spec: Dictionary in LEGACY_MATERIAL_SPECS:
		var normal_path := str(spec.normal)
		var roughness_path := str(spec.roughness)
		var normal_missing := not FileAccess.file_exists(ProjectSettings.globalize_path(normal_path))
		var roughness_missing := not FileAccess.file_exists(ProjectSettings.globalize_path(roughness_path))
		if not normal_missing and not roughness_missing:
			continue

		var maps := _derive_legacy_maps(spec)
		if maps.is_empty():
			return -1
		if normal_missing:
			var normal_error := (maps.normal as Image).save_png(ProjectSettings.globalize_path(normal_path))
			if normal_error != OK or FileAccess.get_sha256(ProjectSettings.globalize_path(normal_path)) != str(LEGACY_DERIVATIVE_HASHES[normal_path]):
				push_error("Unable to reproduce missing legacy normal: %s" % normal_path)
				return -1
			regenerated += 1
			print("REGENERATED_MISSING_LEGACY_MAP: %s" % normal_path)
		if roughness_missing:
			var roughness_error := (maps.roughness as Image).save_png(ProjectSettings.globalize_path(roughness_path))
			if roughness_error != OK or FileAccess.get_sha256(ProjectSettings.globalize_path(roughness_path)) != str(LEGACY_DERIVATIVE_HASHES[roughness_path]):
				push_error("Unable to reproduce missing legacy roughness: %s" % roughness_path)
				return -1
			regenerated += 1
			print("REGENERATED_MISSING_LEGACY_MAP: %s" % roughness_path)
	return regenerated


func _derive_legacy_maps(spec: Dictionary) -> Dictionary:
	var source := Image.load_from_file(ProjectSettings.globalize_path(str(spec.source)))
	if source == null or source.is_empty():
		push_error("Unable to load legacy material source: %s" % spec.source)
		return {}
	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height := source.get_height()
	if width < 4 or height < 4:
		push_error("Legacy material source is too small: %s" % spec.source)
		return {}

	var normal_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var roughness_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var normal_strength := float(spec.normal_strength)
	var roughness_base := float(spec.roughness_base)
	for y in height:
		var y_up := posmod(y - 1, height)
		var y_down := posmod(y + 1, height)
		for x in width:
			var x_left := posmod(x - 1, width)
			var x_right := posmod(x + 1, width)
			var center := source.get_pixel(x, y).get_luminance()
			var left := source.get_pixel(x_left, y).get_luminance()
			var right := source.get_pixel(x_right, y).get_luminance()
			var up := source.get_pixel(x, y_up).get_luminance()
			var down := source.get_pixel(x, y_down).get_luminance()
			var normal := Vector3(
				-(right - left) * normal_strength,
				-(down - up) * normal_strength,
				1.0
			).normalized()
			normal_image.set_pixel(
				x,
				y,
				Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5, 1.0)
			)
			var neighbour_average := (left + right + up + down) * 0.25
			var local_contrast := absf(center - neighbour_average)
			var roughness := clampf(
				roughness_base + local_contrast * 0.58 + (0.5 - center) * 0.08,
				0.28,
				0.88
			)
			roughness_image.set_pixel(x, y, Color(roughness, roughness, roughness, 1.0))
	return {"normal": normal_image, "roughness": roughness_image}


func _load_rgb_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGB8)
	return image


func _runtime_copy(source: Image) -> Image:
	var runtime := source.duplicate()
	runtime.resize(HERO_RUNTIME_SIZE, HERO_RUNTIME_SIZE, Image.INTERPOLATE_LANCZOS)
	runtime.convert(Image.FORMAT_RGB8)
	return runtime


func _derive_registered_maps(albedo: Image) -> Dictionary:
	var width := albedo.get_width()
	var height := albedo.get_height()
	var normal_image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var roughness_image := Image.create(width, height, false, Image.FORMAT_L8)
	var orm_image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var emissive_image := Image.create(width, height, false, Image.FORMAT_RGB8)

	for y in height:
		var y_up := maxi(y - 1, 0)
		var y_down := mini(y + 1, height - 1)
		for x in width:
			var x_left := maxi(x - 1, 0)
			var x_right := mini(x + 1, width - 1)
			var source_pixel := albedo.get_pixel(x, y)
			var center := source_pixel.get_luminance()
			var left := albedo.get_pixel(x_left, y).get_luminance()
			var right := albedo.get_pixel(x_right, y).get_luminance()
			var up := albedo.get_pixel(x, y_up).get_luminance()
			var down := albedo.get_pixel(x, y_down).get_luminance()

			# Clamp at atlas borders: this is intentional UV trim, not a repeating
			# tile, so opposite edges must never influence one another.
			var gradient_x := (right - left) * 1.25
			var gradient_y := (down - up) * 1.25
			var normal := Vector3(-gradient_x, -gradient_y, 1.0).normalized()
			normal_image.set_pixel(
				x,
				y,
				Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5)
			)

			var neighbour_average := (left + right + up + down) * 0.25
			var local_contrast := absf(center - neighbour_average)
			var cyan_mask := _cyan_accent_mask(source_pixel)
			# A restrained painted-surface proxy: local edge contrast increases
			# roughness slightly, while explicitly selected cyan light accents are
			# smoother. This does not claim measured material response.
			var roughness := clampf(
				0.56 + local_contrast * 0.55 + (0.5 - center) * 0.06 - cyan_mask * 0.18,
				0.30,
				0.78
			)
			roughness_image.set_pixel(x, y, Color(roughness, roughness, roughness))

			# Godot-style ORM packing: ambient occlusion remains neutral white in
			# R because it cannot be recovered honestly from this colour image; G
			# is the registered roughness proxy; B keeps coated surfaces non-metal.
			orm_image.set_pixel(x, y, Color(1.0, roughness, 0.0))
			emissive_image.set_pixel(
				x,
				y,
				Color(cyan_mask * 0.04, cyan_mask * 0.82, cyan_mask)
			)

	return {
		"normal": normal_image,
		"roughness": roughness_image,
		"orm": orm_image,
		"emissive": emissive_image,
	}


func _cyan_accent_mask(pixel: Color) -> float:
	var cyan_excess := minf(pixel.g, pixel.b) - pixel.r
	var chroma := maxf(pixel.r, maxf(pixel.g, pixel.b)) - minf(pixel.r, minf(pixel.g, pixel.b))
	var brightness := maxf(pixel.g, pixel.b)
	var balance := 1.0 - clampf(absf(pixel.g - pixel.b) / 0.34, 0.0, 1.0)
	return (
		smoothstep(0.07, 0.24, cyan_excess)
		* smoothstep(0.10, 0.34, chroma)
		* smoothstep(0.28, 0.72, brightness)
		* balance
	)
