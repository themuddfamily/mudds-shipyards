extends SceneTree

## Direct presentation-only check for the Central/Torrent berth route polish.
## The existing authored GuidanceCyan batch gains contrast; no geometry,
## authority, berth, boarding, route, or lifecycle ownership moves here.

const PRESENTATION_SCENE := preload(
	"res://scenes/world/presentation/central_berth_hero_presentation.tscn"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var presentation := PRESENTATION_SCENE.instantiate() as CentralBerthHeroPresentation
	_check(presentation != null, "central berth presentation instantiates")
	if presentation == null:
		_finish()
		return
	root.add_child(presentation)
	await process_frame

	var audit := presentation.get_asset_audit_report()
	_check(
		bool(audit.get("valid", false)),
		"route polish preserves the authored presentation contract: %s" % [audit.get("errors", [])]
	)
	_check(
		int(audit.get("runtime_mesh_count", 0)) == 8
		and int(audit.get("runtime_surface_count", 0)) == 8
		and int(audit.get("forbidden_authority_node_count", -1)) == 0
		and bool(audit.get("presentation_only", false))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("walking_surface_authority", true)),
		"existing eight-batch shell remains authority-free and unchanged"
	)

	var guidance := presentation.get_runtime_material(&"GuidanceCyan")
	_check(
		guidance != null
		and guidance.albedo_color.is_equal_approx(CentralBerthHeroPresentation.GUIDANCE_ALBEDO)
		and guidance.emission_enabled
		and guidance.emission.is_equal_approx(CentralBerthHeroPresentation.GUIDANCE_EMISSION)
		and is_equal_approx(
			guidance.emission_energy_multiplier,
			CentralBerthHeroPresentation.GUIDANCE_EMISSION_ENERGY
		),
		"authored route strips use the brighter high-separation cyan treatment"
	)

	var service_root := presentation.get_semantic_root(&"service_channels")
	var guidance_batches: Array[MeshInstance3D] = []
	if service_root != null:
		for candidate in service_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if StringName(mesh_instance.get_meta("central_berth_material_role", &"")) == &"GuidanceCyan":
				guidance_batches.append(mesh_instance)
	_check(
		guidance_batches.size() == 1
		and guidance_batches[0].material_override == guidance
		and guidance_batches[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"one existing service-channel batch carries the route treatment without extra geometry"
	)

	presentation.queue_free()
	await process_frame
	_finish()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		_failures.append(label)
		push_error("FAIL: " + label)


func _finish() -> void:
	if _failures.is_empty():
		print("Central berth route readability test passed")
		quit(0)
	else:
		push_error("Central berth route readability test failed: %s" % _failures)
		quit(1)
