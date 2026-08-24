extends SceneTree

const Berths := preload("res://scripts/world/fleet_expansion_berths.gd")
const StationSurfaceKit := preload("res://scripts/world/station_surface_kit.gd")

const MARKERS := [
	[
		^"dock_04_cargo/ServicePresentation/CargoCraneHoist",
		Color("56d8de"),
	],
	[
		^"dock_05_bomber/ServicePresentation/OrdnanceMarkerPort",
		Color("ff8b42"),
	],
	[
		^"dock_06_interceptor/ServicePresentation/LaunchRailBatch",
		Color("61e4ee"),
	],
]

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var berths := Berths.new()
	root.add_child(berths)
	await process_frame

	var exact_material_family := true
	var marker_materials: Array[StandardMaterial3D] = []
	for spec in MARKERS:
		var renderer := berths.get_node_or_null(spec[0] as NodePath) as GeometryInstance3D
		var material := renderer.material_override as StandardMaterial3D \
			if renderer != null else null
		marker_materials.append(material)
		exact_material_family = exact_material_family \
			and _is_mapped_metal_trim(material) \
			and material.emission_enabled \
			and material.emission.is_equal_approx(spec[1] as Color) \
			and is_equal_approx(material.emission_energy_multiplier, 2.0)
	_check(
		exact_material_family,
		"cargo, bomber, and interceptor marker hardware retains its role colour while using the station metric metal-trim family"
	)

	var audit := berths.get_audit_report()
	_check(
		bool(audit.get("valid", false)) \
		and int(audit.get("static_bodies", -1)) == 6 \
		and int(audit.get("collision_shapes", -1)) == 6 \
		and int(audit.get("renderer_nodes", -1)) == 26 \
		and int(audit.get("guide_lights", -1)) == 5 \
		and int(audit.get("descendants", -1)) == 61,
		"material binding preserves FleetExpansionBerths layout, collision, renderer, light, and attachment-owner rosters"
	)

	var cargo_material := marker_materials[0]
	var normal_texture := cargo_material.normal_texture
	cargo_material.normal_texture = null
	var drift := berths.get_service_presentation_audit()
	_check(
		not bool(drift.get("valid", true)) \
		and (drift.get("errors", PackedStringArray()) as PackedStringArray).has(
			"service marker station material drift: dock_04_cargo"
		),
		"the production audit fails red if marker hardware falls back to a scalar material"
	)
	cargo_material.normal_texture = normal_texture
	_check(
		bool(berths.get_audit_report().get("valid", false)),
		"restoring the registered marker map returns the live production component green"
	)

	berths.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS fleet_expansion_marker_material_family_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _is_mapped_metal_trim(material: StandardMaterial3D) -> bool:
	return material != null \
		and material.albedo_texture != null \
		and material.albedo_texture.resource_path == StationSurfaceKit.PANEL_ALBEDO_PATH \
		and material.normal_enabled \
		and material.normal_texture != null \
		and material.normal_texture.resource_path == StationSurfaceKit.PANEL_NORMAL_PATH \
		and material.roughness_texture != null \
		and material.roughness_texture.resource_path == StationSurfaceKit.PANEL_ROUGHNESS_PATH \
		and material.roughness_texture_channel == BaseMaterial3D.TEXTURE_CHANNEL_RED \
		and material.uv1_triplanar and material.uv1_world_triplanar \
		and material.uv1_scale.is_equal_approx(Vector3.ONE * 0.30) \
		and material.clearcoat_enabled \
		and is_equal_approx(material.clearcoat, StationSurfaceKit.TRIM_CLEARCOAT) \
		and is_equal_approx(
			material.clearcoat_roughness, StationSurfaceKit.TRIM_CLEARCOAT_ROUGHNESS
		)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
