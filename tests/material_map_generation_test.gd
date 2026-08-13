extends SceneTree

const LEGACY_SETS := ["torrent-hull", "arrow-hull", "jovian-hull", "shipyard-deck"]

const TORRENT_HERO_SOURCES := {
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

const TORRENT_HERO_RUNTIME := {
	"albedo": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-albedo-runtime-v2.png",
		"sha256": "17ccc04b8e641b4890cbacb7842b2fb24e2bbbbd00a7628fc5d9fa86c1b74b12",
	},
	"normal": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-normal-runtime-v2.png",
		"sha256": "c86817d88739b85835efd8626a2ce2c540620fa8a0af985e4bc5384d1599e357",
	},
	"roughness": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-roughness-runtime-v2.png",
		"sha256": "57255d680fc060dd74a040f3bea27d55e9e93dba35f42985ada956f92bacfa42",
	},
	"orm": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-orm-runtime-v2.png",
		"sha256": "8f754d93a36b12eb6a031c8c9675da6e54591844c5582fee1063d6d3b523b2cd",
	},
	"emissive": {
		"path": "res://assets/models/torrent/textures/torrent-hero-trim-emissive-runtime-v2.png",
		"sha256": "398be72d094af6a429d9f06ec7eeeb855850b9873648d2d2f70e6b85e47cbd69",
	},
	"flat_study": {
		"path": "res://assets/models/torrent/textures/torrent-hero-flat-albedo-study-runtime-v2.png",
		"sha256": "f2305695d1b6f924da73be35b4d3a9aec3e5702fb36b4346a920ae29f60fae6e",
	},
}

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

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_legacy_material_sets()
	_test_legacy_derivatives_were_not_overwritten()
	_test_torrent_hero_source_contracts()
	_test_torrent_hero_runtime_maps()
	_finish()


func _test_legacy_material_sets() -> void:
	for stem: String in LEGACY_SETS:
		var albedo := _load_image("res://assets/materials/%s-albedo-v1.png" % stem)
		var normal := _load_image("res://assets/materials/%s-normal-v1.png" % stem)
		var roughness := _load_image("res://assets/materials/%s-roughness-v1.png" % stem)
		_check(albedo != null, "%s base-colour master exists" % stem)
		_check(normal != null, "%s registered normal derivative exists" % stem)
		_check(roughness != null, "%s registered roughness derivative exists" % stem)
		if albedo == null or normal == null or roughness == null:
			continue
		_check(normal.get_size() == albedo.get_size(), "%s normal preserves exact source dimensions" % stem)
		_check(roughness.get_size() == albedo.get_size(), "%s roughness preserves exact source dimensions" % stem)
		_check(_edges_are_visually_tileable(albedo), "%s legacy tile edges remain within local pixel-continuity tolerance" % stem)
		_check(_import_contains("res://assets/materials/%s-albedo-v1.png" % stem, "mipmaps/generate=true"), "%s base-colour import generates mipmaps for oblique 3D use" % stem)
		var normal_path := "res://assets/materials/%s-normal-v1.png" % stem
		var importer_inverts_y := _import_contains(normal_path, "process/normal_map_invert_y=true")
		_check(importer_inverts_y, "%s normal import converts its encoded image-row Y to Godot tangent-space Y" % stem)
		_check(_normal_is_plausible(normal), "%s normal derivative contains tangent-space relief" % stem)
		_check(
			_normal_import_matches_height_gradient(albedo, normal, importer_inverts_y),
			"%s effective imported normal follows the registered Godot height-gradient direction" % stem
		)
		_check(_roughness_is_plausible(roughness), "%s roughness remains in the restrained physical range" % stem)


func _test_legacy_derivatives_were_not_overwritten() -> void:
	for path: String in LEGACY_DERIVATIVE_HASHES:
		_check(
			_sha256(path) == str(LEGACY_DERIVATIVE_HASHES[path]),
			"v1 legacy derivative remains byte-identical after v2 hero generation: %s" % path
		)


func _test_torrent_hero_source_contracts() -> void:
	for source_key: String in TORRENT_HERO_SOURCES:
		var spec: Dictionary = TORRENT_HERO_SOURCES[source_key]
		var path := str(spec.path)
		var image := _load_image(path)
		_check(image != null, "%s imagegen source exists" % source_key)
		_check(image != null and image.get_size() == spec.size, "%s imagegen source remains exactly 1254 square" % source_key)
		_check(_sha256(path) == str(spec.sha256), "%s imagegen source remains byte-identical" % source_key)

	_check(
		str(TORRENT_HERO_SOURCES.trim.seam_classification) == "intentional_uv_trim_atlas_not_tileable",
		"trim source is classified as an intentional non-tileable UV atlas"
	)
	_check(
		str(TORRENT_HERO_SOURCES.flat_study.seam_classification) == "material_study_seams_unverified",
		"flat edit remains an unverified material study rather than a seamless claim"
	)


func _test_torrent_hero_runtime_maps() -> void:
	var images := {}
	for map_key: String in TORRENT_HERO_RUNTIME:
		var spec: Dictionary = TORRENT_HERO_RUNTIME[map_key]
		var path := str(spec.path)
		var image := _load_image(path)
		images[map_key] = image
		_check(image != null, "%s Torrent hero runtime image exists" % map_key)
		_check(image != null and image.get_size() == Vector2i(1024, 1024), "%s Torrent hero runtime image is exactly 1024 square" % map_key)
		_check(_sha256(path) == str(spec.sha256), "%s Torrent hero runtime image has the deterministic registered hash" % map_key)
		_check(_import_contains(path, "mipmaps/generate=true"), "%s Torrent hero runtime import generates mipmaps" % map_key)

	var albedo := images.get("albedo") as Image
	var normal := images.get("normal") as Image
	var roughness := images.get("roughness") as Image
	var orm := images.get("orm") as Image
	var emissive := images.get("emissive") as Image
	var flat_study := images.get("flat_study") as Image
	if albedo == null or normal == null or roughness == null or orm == null or emissive == null or flat_study == null:
		return

	_check(normal.get_size() == albedo.get_size(), "trim normal is pixel-registered to the runtime atlas")
	_check(roughness.get_size() == albedo.get_size(), "trim roughness is pixel-registered to the runtime atlas")
	_check(orm.get_size() == albedo.get_size(), "trim ORM is pixel-registered to the runtime atlas")
	_check(emissive.get_size() == albedo.get_size(), "trim emissive mask is pixel-registered to the runtime atlas")
	var trim_normal_path := str(TORRENT_HERO_RUNTIME.normal.path)
	var trim_importer_inverts_y := _import_contains(trim_normal_path, "process/normal_map_invert_y=true")
	_check(_import_contains(trim_normal_path, "compress/normal_map=1"), "trim normal uses Godot's normal-map import mode")
	_check(trim_importer_inverts_y, "trim normal import converts its encoded image-row Y to Godot tangent-space Y")
	_check(_normal_is_plausible(normal), "trim normal contains restrained tangent-space image-derived relief")
	_check(
		_normal_import_matches_height_gradient(albedo, normal, trim_importer_inverts_y),
		"trim effective imported normal follows the registered Godot height-gradient direction"
	)
	_check(_roughness_is_plausible(roughness), "trim roughness remains a restrained registered proxy")
	_check(_orm_is_registered(orm, roughness), "trim ORM keeps neutral AO in R, registered roughness in G, and non-metal in B")
	_check(_emissive_is_sparse_cyan(emissive), "trim emissive is an opt-in sparse cyan-accent mask without red livery")
	_check(
		str(TORRENT_HERO_RUNTIME.flat_study.path) != str(TORRENT_HERO_RUNTIME.albedo.path),
		"flat material-study runtime copy remains distinct from the selected trim atlas"
	)


func _load_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	return image if image != null and not image.is_empty() else null


func _sha256(path: String) -> String:
	return FileAccess.get_sha256(ProjectSettings.globalize_path(path))


func _import_contains(texture_path: String, token: String) -> bool:
	var file := FileAccess.open(ProjectSettings.globalize_path(texture_path + ".import"), FileAccess.READ)
	return file != null and token in file.get_as_text()


func _edges_are_visually_tileable(image: Image) -> bool:
	var left_right_error := 0.0
	var top_bottom_error := 0.0
	for y in image.get_height():
		left_right_error += _rgb_distance(image.get_pixel(0, y), image.get_pixel(image.get_width() - 1, y))
	for x in image.get_width():
		top_bottom_error += _rgb_distance(image.get_pixel(x, 0), image.get_pixel(x, image.get_height() - 1))
	left_right_error /= image.get_height() * 3.0
	top_bottom_error /= image.get_width() * 3.0

	var adjacent_x_error := 0.0
	var adjacent_y_error := 0.0
	var adjacent_x_samples := 0
	var adjacent_y_samples := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width() - 1, 8):
			adjacent_x_error += _rgb_distance(image.get_pixel(x, y), image.get_pixel(x + 1, y))
			adjacent_x_samples += 1
	for y in range(0, image.get_height() - 1, 8):
		for x in range(0, image.get_width(), 8):
			adjacent_y_error += _rgb_distance(image.get_pixel(x, y), image.get_pixel(x, y + 1))
			adjacent_y_samples += 1
	adjacent_x_error /= maxi(adjacent_x_samples, 1) * 3.0
	adjacent_y_error /= maxi(adjacent_y_samples, 1) * 3.0

	return (
		left_right_error <= adjacent_x_error * 1.25 + 0.003
		and top_bottom_error <= adjacent_y_error * 1.25 + 0.003
	)


func _rgb_distance(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


func _normal_is_plausible(image: Image) -> bool:
	var minimum_blue := 1.0
	var maximum_variation := 0.0
	for y in range(0, image.get_height(), 31):
		for x in range(0, image.get_width(), 31):
			var pixel := image.get_pixel(x, y)
			minimum_blue = minf(minimum_blue, pixel.b)
			maximum_variation = maxf(maximum_variation, absf(pixel.r - 0.5) + absf(pixel.g - 0.5))
	return minimum_blue > 0.72 and maximum_variation > 0.002


func _normal_import_matches_height_gradient(
	albedo: Image,
	normal: Image,
	importer_inverts_y: bool
) -> bool:
	# Image rows increase downward, while Godot's tangent-space normal convention
	# expects the corresponding Y component to increase upward. These derivative
	# PNGs intentionally retain their registered historical bytes, so their import
	# sidecars perform the required green-channel conversion.
	var x_stats := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	var y_stats := PackedFloat64Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for y in range(1, albedo.get_height() - 1, 17):
		for x in range(1, albedo.get_width() - 1, 17):
			var left := albedo.get_pixel(x - 1, y).get_luminance()
			var right := albedo.get_pixel(x + 1, y).get_luminance()
			var up := albedo.get_pixel(x, y - 1).get_luminance()
			var down := albedo.get_pixel(x, y + 1).get_luminance()
			var encoded := normal.get_pixel(x, y)
			var actual_x := encoded.r * 2.0 - 1.0
			var actual_y := encoded.g * 2.0 - 1.0
			if importer_inverts_y:
				actual_y = -actual_y
			_accumulate_correlation(x_stats, -(right - left), actual_x)
			_accumulate_correlation(y_stats, down - up, actual_y)
	return _correlation(x_stats) > 0.97 and _correlation(y_stats) > 0.97


func _accumulate_correlation(stats: PackedFloat64Array, expected: float, actual: float) -> void:
	stats[0] += 1.0
	stats[1] += expected
	stats[2] += actual
	stats[3] += expected * expected
	stats[4] += actual * actual
	stats[5] += expected * actual


func _correlation(stats: PackedFloat64Array) -> float:
	var count := stats[0]
	var covariance := count * stats[5] - stats[1] * stats[2]
	var expected_variance := count * stats[3] - stats[1] * stats[1]
	var actual_variance := count * stats[4] - stats[2] * stats[2]
	var denominator := sqrt(maxf(expected_variance * actual_variance, 0.0))
	return covariance / denominator if denominator > 0.0000001 else 0.0


func _roughness_is_plausible(image: Image) -> bool:
	var minimum := 1.0
	var maximum := 0.0
	var channel_error := 0.0
	for y in range(0, image.get_height(), 31):
		for x in range(0, image.get_width(), 31):
			var pixel := image.get_pixel(x, y)
			minimum = minf(minimum, pixel.r)
			maximum = maxf(maximum, pixel.r)
			channel_error = maxf(channel_error, absf(pixel.r - pixel.g) + absf(pixel.r - pixel.b))
	return minimum >= 0.27 and maximum <= 0.9 and maximum - minimum > 0.005 and channel_error < 0.01


func _orm_is_registered(orm: Image, roughness: Image) -> bool:
	var maximum_channel_error := 0.0
	for y in range(0, orm.get_height(), 13):
		for x in range(0, orm.get_width(), 13):
			var packed := orm.get_pixel(x, y)
			var registered_roughness := roughness.get_pixel(x, y).r
			maximum_channel_error = maxf(
				maximum_channel_error,
				absf(1.0 - packed.r) + absf(registered_roughness - packed.g) + absf(packed.b)
			)
	return maximum_channel_error < 0.004


func _emissive_is_sparse_cyan(image: Image) -> bool:
	var lit_samples := 0
	var sampled_pixels := 0
	var maximum_green := 0.0
	var maximum_blue := 0.0
	var red_dominant := false
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel := image.get_pixel(x, y)
			sampled_pixels += 1
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.01:
				lit_samples += 1
				maximum_green = maxf(maximum_green, pixel.g)
				maximum_blue = maxf(maximum_blue, pixel.b)
				red_dominant = red_dominant or pixel.r > pixel.g or pixel.r > pixel.b
	var coverage := float(lit_samples) / maxf(float(sampled_pixels), 1.0)
	return coverage > 0.0005 and coverage < 0.01 and maximum_green > 0.6 and maximum_blue > 0.8 and not red_dominant


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("MATERIAL_MAP_GENERATION_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("MATERIAL_MAP_GENERATION_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
