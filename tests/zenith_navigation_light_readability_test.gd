extends SceneTree

const PRESENTATION_SCENE := preload(
	"res://scenes/ships/presentation/zenith_authored_presentation.tscn"
)

const NAVIGATION_LIGHT_PATHS := {
	&"PortNavRed": [
		^"ModernSystems/LOD0/ModernSystemsLOD0StaticBatch_PortNavRed",
		^"ModernSystems/LOD1/ModernSystemsLOD1StaticBatch_PortNavRed",
	],
	&"StarboardNavGreen": [
		^"ModernSystems/LOD0/ModernSystemsLOD0StaticBatch_StarboardNavGreen",
		^"ModernSystems/LOD1/ModernSystemsLOD1StaticBatch_StarboardNavGreen",
	],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as ZenithAuthoredPresentation
	root.add_child(presentation)
	await process_frame

	var asset_root := presentation.get_asset_root()
	for role: StringName in NAVIGATION_LIGHT_PATHS:
		var material := presentation.get_runtime_material(role)
		_check(
			material != null
			and material.emission_enabled
			and is_equal_approx(material.emission_energy_multiplier, 3.4)
			and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
			"%s stays a bright lighting-independent recognition cue" % role
		)
		for node_path: NodePath in NAVIGATION_LIGHT_PATHS[role]:
			var light_mesh := asset_root.get_node_or_null(node_path) as MeshInstance3D
			_check(
				light_mesh != null
				and light_mesh.material_override == material
				and light_mesh.get_meta("zenith_material_role", &"") == role
				and bool(light_mesh.get_meta("presentation_only", false))
				and not bool(light_mesh.get_meta("gameplay_authority", true)),
				"%s uses the same presentation-only cue in both whole-ship LODs" % role
			)

	var audit := presentation.get_asset_audit_report()
	_check(
		bool(audit.get("valid", false))
		and str(audit.get("evidence_scope", "")) == "B7_frames_373_467_only"
		and not bool(audit.get("gameplay_authority", true))
		and not bool(audit.get("collision_authority", true)),
		"readability polish preserves the bounded evidence and authority boundary"
	)

	presentation.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS zenith_navigation_light_readability_test")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
