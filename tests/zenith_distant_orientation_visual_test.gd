extends SceneTree

## Focused component gate for the Zenith's presentation-only far engine read.
## It deliberately does not exercise collision, boarding, weapons, handling,
## berth fit or evidence status beyond proving their authored artifact is intact.

const PRESENTATION_SCENE := preload(
	"res://scenes/ships/presentation/zenith_authored_presentation.tscn"
)
const EngineExhaustPresentation := preload("res://scripts/ships/engine_exhaust_presentation.gd")
const EXPECTED_BOUNDS_MINIMUM := Vector3(-7.20, -1.05, -5.35)
const EXPECTED_BOUNDS_MAXIMUM := Vector3(7.20, 3.20, 5.30)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as ZenithAuthoredPresentation
	root.add_child(presentation)
	await process_frame

	var audit := presentation.get_asset_audit_report()
	_check(
		bool(audit.get("valid", false)),
		"production Zenith remains green after its distant engine-response polish"
	)

	var far_material: ShaderMaterial
	var close_material: ShaderMaterial
	var engine_palette := presentation.get_runtime_material(&"EngineEmission")
	var far_names := PackedStringArray()
	var far_nodes_valid := true
	var close_nodes_shared := true
	for plume in presentation.get_engine_plumes():
		if String(plume.name).begins_with("LOD1"):
			far_names.append(String(plume.name))
			var plume_material := plume.material_override as ShaderMaterial
			if far_material == null:
				far_material = plume_material
			far_nodes_valid = far_nodes_valid \
				and plume_material == far_material \
				and bool(plume.get_meta(&"distant_orientation_cue", false)) \
				and bool(plume.get_meta(&"presentation_only", false)) \
				and not bool(plume.get_meta(&"gameplay_authority", true)) \
				and plume.get_child_count() == 0 \
				and plume.get_script() == null \
				and plume.get_groups().is_empty()
		else:
			if close_material == null:
				close_material = plume.material_override as ShaderMaterial
			close_nodes_shared = close_nodes_shared \
				and plume.material_override == close_material
	far_names.sort()
	_check(
		far_names == PackedStringArray([
			"LOD1PortEnginePlume", "LOD1StarboardEnginePlume",
		])
		and far_material != null
		and close_material != null
		and far_material != close_material
		and far_nodes_valid
		and close_nodes_shared
		and far_material.shader == EngineExhaustPresentation.PLUME_SHADER
		and close_material.shader == EngineExhaustPresentation.PLUME_SHADER
		and far_material.get_shader_parameter(&"exhaust_color") == engine_palette.emission
		and close_material.get_shader_parameter(&"exhaust_color") == engine_palette.emission
		and is_equal_approx(float(far_material.get_shader_parameter(&"intensity")) / float(close_material.get_shader_parameter(&"intensity")), 4.8 / 3.1),
		"both LODs retain soft cyan exhaust, with stronger far intensity and no added authority"
	)

	presentation.update_lod_for_distance(80.0)
	_check(
		presentation.get_active_lod() == 1
		and int(audit.get("runtime_mesh_count", 0)) == 22
		and int(audit.get("runtime_surface_count", 0)) == 22
		and (audit.get("bounds_minimum", Vector3.INF) as Vector3).distance_to(
			EXPECTED_BOUNDS_MINIMUM
		) <= 0.002
		and (audit.get("bounds_maximum", Vector3.INF) as Vector3).distance_to(
			EXPECTED_BOUNDS_MAXIMUM
		) <= 0.002,
		"far handoff preserves the exact authored mesh roster and frozen visual envelope"
	)
	_check(
		bool(audit.get("raw_source_glb_hash_verified", false))
		and str(audit.get("evidence_scope", "")) == "B7_frames_373_467_only"
		and not bool(audit.get("historical_geometry_authenticated", true)),
		"polish leaves the pinned B7 artifact and its bounded evidence claim unchanged"
	)

	presentation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_DISTANT_ORIENTATION_VISUAL_TEST_OK assertions=%d" % _assertions)
		quit(0)
	else:
		print("ZENITH_DISTANT_ORIENTATION_VISUAL_TEST_FAILED failures=%d" % _failures.size())
		quit(1)
