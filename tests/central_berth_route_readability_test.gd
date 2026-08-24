extends SceneTree

## Direct presentation-only check for the Central/Torrent berth route polish.
## The authored GuidanceCyan route gains a static threshold handoff from the
## regeneration deck; authority, collision, berth and lifecycle stay elsewhere.

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
		and int(audit.get("total_render_mesh_count", 0)) == 9
		and int(audit.get("total_render_surface_count", 0)) == 9
		and int(audit.get("forbidden_authority_node_count", -1)) == 0
		and bool(audit.get("presentation_only", false))
		and not bool(audit.get("collision_authority", true))
		and not bool(audit.get("walking_surface_authority", true)),
		"authored eight-batch shell stays unchanged beside one bounded route draw"
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
			if StringName(mesh_instance.get_meta("central_berth_material_role", &"")) == &"GuidanceCyan" \
					and not mesh_instance.has_meta(&"central_berth_route_handoff"):
				guidance_batches.append(mesh_instance)
	_check(
		guidance_batches.size() == 1
		and guidance_batches[0].material_override == guidance
		and guidance_batches[0].cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"one existing service-channel batch carries the route treatment without extra geometry"
	)

	var handoff := service_root.get_node_or_null(^"RegenerationDeckHandoff") as MeshInstance3D \
		if service_root != null else null
	_check(
		handoff != null
		and handoff.mesh != null
		and handoff.mesh.resource_name == String(CentralBerthHeroPresentation.ROUTE_HANDOFF_FAMILY_ID)
		and handoff.mesh.get_surface_count() == 1
		and handoff.mesh.get_aabb().is_equal_approx(CentralBerthHeroPresentation.ROUTE_HANDOFF_BOUNDS)
		and handoff.material_override == guidance
		and handoff.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and int(audit.get("route_handoff_member_count", 0)) == 8
		and int(audit.get("route_handoff_triangle_count", 0)) == 864,
		"one static batched pair of deck-seated handoff blades frames the real berth route; bounds=%s triangles=%d" % [
			handoff.mesh.get_aabb() if handoff != null and handoff.mesh != null else AABB(),
			presentation._mesh_triangle_count(handoff.mesh) if handoff != null and handoff.mesh != null else -1,
		]
	)
	_check(
		float(audit.get("route_handoff_inner_clearance_m", 0.0)) >= 6.75
		and is_equal_approx(
			(audit.get("route_handoff_bounds", AABB()) as AABB).position.y,
			CentralBerthHeroPresentation.EXPECTED_MAXIMUM.y,
		)
		and not handoff.has_method("_process")
		and not handoff.has_method("_physics_process")
		and handoff.find_children("*", "CollisionShape3D", true, false).is_empty()
		and handoff.find_children("*", "Light3D", true, false).is_empty(),
		"handoff is physically seated, non-coplanar, outside craft clearance, and non-authoritative"
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
		push_error("Central berth route readability test failed: %s" % [_failures])
		quit(1)
