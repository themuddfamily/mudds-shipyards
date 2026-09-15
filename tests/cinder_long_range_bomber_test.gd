extends SceneTree

const Bomber := preload("res://scripts/ships/cinder_long_range_bomber.gd")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	var bomber := Bomber.new()
	root.add_child(bomber)
	await process_frame
	_test_recessed_exhaust(bomber)
	_test_fitted_canopy(bomber)
	_test_formed_cockpit_walls(bomber)
	_test_service_cassettes(bomber)
	_test_forward_pressure_body(bomber)
	var audit := bomber.get_audit_report()
	var definition := bomber.get_ship_definition()
	_check(bool(audit.get("valid", false)), "the bomber builds a valid collision and payload contract")
	_check(
		definition != null
		and definition.is_definition_valid()
		and definition.get_ship_id() == &"cinder_long_range_bomber"
		and is_equal_approx(bomber.maximum_speed, definition.maximum_speed)
		and is_equal_approx(bomber.engine_start_time, definition.engine_start_time)
		and is_equal_approx(bomber.maximum_hull, definition.maximum_hull),
		"the live bomber consumes its authored 72 m/s, 3.6 s startup, and 240-hull profile"
	)
	_check(audit.get("evidence_status", &"") == &"NEW" and not bool(audit.get("historically_supported", true)), "the bomber makes no historical claim")
	_check(bomber.get_cockpit_seat_anchor() != null and bomber.get_boarding_marker() != null, "the bomber exposes physical cockpit and boarding anchors")
	_check(bomber.get_payload_hardpoints().size() == 4, "the bomber exposes four caller-owned payload hardpoints")
	_check(bool(bomber is HeroShip) and bool(audit.get("flight_authority", false)) and not bool(audit.get("combat_authority", true)) and not bool(audit.get("ordnance_authority", true)), "HeroShip owns flight while the component adds no duplicate combat or ordnance authority")
	var visual := bomber.get_variant_visual_root()
	var hull := visual.get_node_or_null(^"LongRangeHull") as MeshInstance3D
	var fairing := visual.get_node_or_null(^"CockpitSupportFairing") as MeshInstance3D
	var cockpit_floor := visual.get_node_or_null(^"CockpitInterior/CockpitFloor") as MeshInstance3D
	var fairing_mesh := fairing.mesh as ArrayMesh if fairing != null else null
	var hull_mesh := hull.mesh as ArrayMesh if hull != null else null
	var cockpit_floor_mesh := cockpit_floor.mesh if cockpit_floor != null else null
	_check(
		fairing != null
		and fairing_mesh != null
		and fairing.position.is_equal_approx(CinderLongRangeBomber.COCKPIT_SUPPORT_FAIRING_POSITION)
		and fairing_mesh.get_aabb().size.is_equal_approx(Vector3(3.9, 1.416, 6.8)),
		"the bomber builds the exact closed cockpit support fairing"
	)
	var hull_top := hull.position.y + hull_mesh.get_aabb().size.y * 0.5 \
			if hull != null and hull_mesh != null else INF
	var fairing_bottom := fairing.position.y + fairing_mesh.get_aabb().position.y \
			if fairing != null and fairing_mesh != null else INF
	var fairing_top := fairing.position.y + fairing_mesh.get_aabb().end.y \
			if fairing != null and fairing_mesh != null else -INF
	var cockpit_floor_bottom := cockpit_floor.position.y + cockpit_floor.get_aabb().position.y \
			if cockpit_floor != null and cockpit_floor_mesh != null else -INF
	var hull_overlap := hull_top - fairing_bottom
	var cockpit_overlap := fairing_top - cockpit_floor_bottom
	_check(
		hull_overlap > 0.02
		and absf(cockpit_overlap - 0.02) <= 0.0001,
		"the continuous shoulder enters the hull and seats 20 mm into the cockpit floor (%.4f m / %.4f m)" % [
			hull_overlap, cockpit_overlap
		]
	)
	_check(
		fairing != null
		and hull != null
		and fairing_mesh != null
		and fairing.visible
		and fairing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and fairing.material_override == hull.material_override
		and not fairing_mesh.resource_local_to_scene
		and fairing.get_child_count() == 0
		and fairing.get_script() == null
		and fairing.find_children("*", "CollisionShape3D", true, false).is_empty(),
		"the fairing is one shared hull-material renderer with no collision or gameplay authority"
	)
	var sensor_audit := bomber.get_sensor_resource_sharing_audit()
	_check(
		bool(sensor_audit.get("valid", false))
		and bool(sensor_audit.get("chase_retains_sensor", false))
		and bool(sensor_audit.get("cockpit_omits_sensor", false)),
		"the fairing leaves the exterior sensor and cockpit/chase layer split unchanged"
	)
	await _test_shared_damage_presentation(bomber)
	bomber.queue_free()
	await process_frame
	if _failures.is_empty():
		print("PASS cinder_long_range_bomber_test (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _test_recessed_exhaust(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var port := visual.get_node("PortGuideVanes") as MultiMeshInstance3D
	var starboard := visual.get_node("StarboardGuideVanes") as MultiMeshInstance3D
	var hub := visual.get_node("PortThrustPlug") as MeshInstance3D
	var lip := visual.get_node("PortNozzleLip") as MeshInstance3D
	var annulus := visual.get_node("PortCombustorAnnulus") as MeshInstance3D
	var bell := visual.get_node("PortExhaustBell") as MeshInstance3D
	var opposite_bell := visual.get_node("StarboardExhaustBell") as MeshInstance3D
	_check(port.multimesh.mesh is ArrayMesh and port.multimesh.instance_count == 12
		and port.multimesh.mesh == starboard.multimesh.mesh and bell.mesh == opposite_bell.mesh,
		"formed bells and twelve curved stator vanes retain immutable mesh sharing across paired engines")
	var vane_bounds := port.transform * port.multimesh.mesh.get_aabb()
	var hub_bounds := hub.transform * hub.mesh.get_aabb()
	_check(vane_bounds.end.z < lip.position.z and hub_bounds.end.z < lip.position.z
		and vane_bounds.size.z > port.scale.z * 0.2,
		"thick stator airfoils and the turned hub remain recessed inside the open bell")
	_check(not (annulus.material_override as StandardMaterial3D).emission_enabled
		and not (hub.material_override as StandardMaterial3D).emission_enabled
		and port.get_script() == null and hub.get_script() == null,
		"unpowered machinery has a passive metallic finish and adds no engine-state controller")


func _test_service_cassettes(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	for tag in ["ThermalService", "RamScoop/Scoop"]:
		var port := visual.get_node("Port" + tag + "Frame") as MeshInstance3D
		var starboard := visual.get_node("Starboard" + tag + "Frame") as MeshInstance3D
		var vanes := visual.get_node("Port" + tag + "Vanes") as MeshInstance3D
		var opposite_vanes := visual.get_node("Starboard" + tag + "Vanes") as MeshInstance3D
		var backing := visual.get_node("Port" + tag + "Recess") as MeshInstance3D
		_check(port.mesh is ArrayMesh and vanes.mesh is ArrayMesh
			and port.mesh == starboard.mesh and vanes.mesh == opposite_vanes.mesh
			and backing.mesh == (visual.get_node("Starboard" + tag + "Recess") as MeshInstance3D).mesh,
			"paired %s cassettes share their three immutable renderer stocks" % tag)
		_check(vanes.mesh.get_faces().size() == 960 and port.mesh.get_faces().size() > 36
			and port.material_override != null and vanes.material_override != null
			and port.get_script() == null and port.get_child_count() == 0,
			"%s has five closed curved vanes and a continuous frame without gameplay nodes" % tag)
		var foot := visual.global_transform.affine_inverse() * port.global_transform * port.mesh.get_aabb()
		_check(foot.position.y < 1.18 and foot.end.y > 1.18
			and foot.position.z > -2.8 and foot.end.z < 3.8,
			"%s frame foot seats into the shoulder crown clear of nose optics and payload lanes" % tag)
	_check(visual.find_children("*Louver*", "MeshInstance3D", true, false).is_empty()
		and visual.find_children("*ThermalServiceRim*", "MeshInstance3D", true, false).is_empty(),
		"service grilles replace the former stacked bars and separate rails")


func _test_forward_pressure_body(craft: HeroShip) -> void:
	var visual: Node3D = craft.call("get_variant_visual_root")
	var hull := visual.get_node("LongRangeHull") as MeshInstance3D
	var cowl := visual.get_node("SensorProtectiveCowl") as MeshInstance3D
	var optics := visual.get_node("LongRangeSensor") as MeshInstance3D
	var hull_faces := hull.mesh.get_faces()
	# The four existing saddle feet must enter the pressure skin, with their
	# tops exposed. A bounding box alone cannot detect the old floating nose.
	for side in [-1.0, 1.0]:
		for local_z in [-0.46, 0.75]:
			var at := cowl.position + Vector3(side * 0.82, -0.10, local_z)
			var skin_y := _pressure_skin_height(hull_faces, at.x, at.z)
			_check(skin_y > at.y - 0.065 and skin_y < at.y + 0.065,
				"forward pressure skin seats the targeting saddle foot at %s (skin %.4f)" % [at, skin_y])
	var lenses_clear := true
	for vertex in optics.mesh.get_faces():
		var point: Vector3 = optics.transform * vertex
		lenses_clear = lenses_clear and point.y > _pressure_skin_height(hull_faces, point.x, point.z) + 0.015
	_check(lenses_clear, "both recessed targeting lenses remain fully above the formed nose skin")
	_check(hull.mesh.get_aabb().size.is_equal_approx(Vector3(5.6, 2.65, 15.5))
		and hull.mesh.get_surface_count() == 1
		and hull.transform.is_equal_approx(Transform3D.IDENTITY),
		"the formed bow retains the original primary hull envelope and single renderer surface")

	var shoulder_drop := _pressure_skin_height(hull_faces, 0.0, -1.0) - _pressure_skin_height(hull_faces, 1.8, -1.0)
	_check(shoulder_drop > 0.12 and shoulder_drop < 0.3,
		"the primary shoulder curves below its central equipment landing rather than retaining a slab crown")
	var terminal_seal_small := true
	var terminal_vertices := 0
	for point in hull_faces:
		if is_equal_approx(point.z, -7.75):
			terminal_vertices += 1
			terminal_seal_small = terminal_seal_small and absf(point.x) < 0.02 and absf(point.y) < 0.025
	_check(terminal_vertices > 0 and terminal_seal_small and hull_faces.size() / 3 <= 2200,
		"the rounded bow closes with a small terminal seal within the 2200-triangle primary skin budget")
	var mirrored_faces := hull_faces.duplicate()
	for index in mirrored_faces.size():
		mirrored_faces[index].y = -mirrored_faces[index].y
	for side in ["Port", "Starboard"]:
		var shoulder := visual.get_node(side + "PressureShoulder") as MeshInstance3D
		var cap_embedded := true
		var cap_vertices := 0
		for local in shoulder.mesh.get_faces():
			if is_equal_approx(local.z, -6.4):
				cap_vertices += 1
				var point: Vector3 = shoulder.transform * local
				cap_embedded = cap_embedded and point.y < _pressure_skin_height(hull_faces, point.x, point.z) - 0.01 \
					and point.y > -_pressure_skin_height(mirrored_faces, point.x, point.z) + 0.01
		_check(cap_vertices > 0 and cap_embedded, "%s nacelle nose cap enters the rolled main skin without a detached tooth" % side)
	var arrays := hull.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var frames_valid := normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4
	for index in vertices.size():
		var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
		frames_valid = frames_valid and normals[index].is_finite() and normals[index].length_squared() > 0.99 \
			and uvs[index].is_finite() and tangent.is_finite() and tangent.length_squared() > 0.99 \
			and absf(tangent.dot(normals[index])) < 0.01
	_check(frames_valid, "formed bow and shoulders retain complete UVs and finite orthogonal normal/tangent frames")


func _pressure_skin_height(faces: PackedVector3Array, x: float, z: float) -> float:
	var highest := -INF
	var above := Vector3(x, 3.0, z)
	var below := Vector3(x, -3.0, z)
	for index in range(0, faces.size(), 3):
		var hit = Geometry3D.segment_intersects_triangle(above, below, faces[index], faces[index + 1], faces[index + 2])
		if hit != null:
			highest = maxf(highest, hit.y)
	return highest


func _test_fitted_canopy(craft: HeroShip) -> void:
	var hinge := craft.get_variant_visual_root().get_node("CanopyHinge") as Node3D
	var glass := hinge.get_node("CanopyGlass") as MeshInstance3D
	var vertices: PackedVector3Array = glass.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var upper_only := true
	for index in range(0, vertices.size(), 3):
		var normal := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index]).normalized()
		upper_only = upper_only and normal.y > -0.95
	var pillar := hinge.get_node("PortCanopyNoseFrame") as MeshInstance3D
	var broad_pillar := true
	var sampled := false
	for vertex: Vector3 in pillar.mesh.get_faces():
		var point := hinge.position + pillar.transform * vertex
		if point.y > 2.90 and point.y < 3.45:
			sampled = true
			broad_pillar = broad_pillar and absf(point.x) > 1.025
	_check(upper_only and sampled and broad_pillar and bool(glass.get_meta("upper_pressure_enclosure", false)),
		"the fitted windscreen keeps pillars outside the forward instrument view and has no glass floor")
	var attached_keepers := true
	for side in ["Port", "Starboard"]:
		var keeper := hinge.get_node(side + "CanopyLatchHook") as MeshInstance3D
		var bounds := keeper.transform * keeper.mesh.get_aabb()
		attached_keepers = attached_keepers and bounds.end.y > 0.10 and bounds.position.y <= -0.119 and bounds.size.x > 0.30
	_check(attached_keepers, "both moving latch keepers reach from the lower lid rails to the retained striker contacts")
	var glass_stock := glass.mesh
	craft.set_canopy_open(true, 0.0)
	_check(hinge.rotation.x > 1.0 and glass.mesh == glass_stock and glass.is_visible_in_tree(),
		"the common functional hinge opens the complete fitted upper lid")
	craft.set_canopy_open(false, 0.0)


func _test_formed_cockpit_walls(craft: HeroShip) -> void:
	var visual := craft.get_variant_visual_root()
	var cockpit := visual.get_node("CockpitInterior")
	var fairing := visual.get_node("CockpitSupportFairing") as MeshInstance3D
	var names := ["PortSidewall", "StarboardSidewall", "ForwardPressureWall", "RearPressureWall"]
	var contact_points := [Vector3(-1.68, 0, -0.555), Vector3(1.68, 0, -0.555), Vector3(0, 0, -2.45), Vector3(0, 0, 1.32)]
	var triangles := 0
	for index in names.size():
		var wall := cockpit.get_node(names[index]) as MeshInstance3D
		_check(wall.mesh is ArrayMesh and wall.mesh.get_surface_count() == 1 and wall.mesh.surface_get_material(0) == null,
			"formed cockpit armor keeps one surface per existing owner and no material in shared geometry")
		_check(wall.material_override == fairing.material_override and wall.get_child_count() == 0,
			"formed cockpit armor uses the owning craft finish with no additional scene or collision nodes")
		var faces := wall.mesh.get_faces()
		triangles += faces.size() / 3
		var levels: Dictionary = {}
		var contact := Vector3.INF
		for vertex in faces:
			var at := wall.transform * vertex
			levels[snappedf(at.y, 0.001)] = true
			if absf(at.x - contact_points[index].x) < 0.001 and absf(at.z - contact_points[index].z) < 0.001:
				if at.y < contact.y: contact = at
		_check(levels.size() >= 9, "armor has a substantial rolled profile below the retained seal land")
		var height := -INF
		var skin_faces := fairing.mesh.get_faces()
		for triangle in range(0, skin_faces.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(Vector3(contact.x, 8, contact.z), Vector3.DOWN,
				fairing.transform * skin_faces[triangle], fairing.transform * skin_faces[triangle + 1], fairing.transform * skin_faces[triangle + 2])
			if hit != null: height = maxf(height, hit.y)
		_check(is_finite(height) and height - contact.y > 0.025 and height - contact.y < 0.045,
			"the emitted armor toe seats inside actual fairing triangles, including the widest cheek and fore/aft center")
	_check(triangles <= 600, "four formed wall owners stay within 600 triangles and four submissions")


## Phase 6 fleet damage/repair/recovery coverage for the shared presentation.
##
## This craft is composed from script by its production binding rather than
## instanced from a `scenes/ships/*.tscn`, so it used to raise none of the shared
## channels a player sees on every authored craft. It now attaches the same
## `scenes/effects/hero_damage_presentation.tscn`, and this drives the whole
## lifecycle through it: staged hull sparks, engine smoke and engine-failure
## sparks on this hull's own anchors, the damage and engine-failure practicals,
## the localized rig the shared `component_damage_*` seam routes, the degraded
## engine exhaust grade, the reduced-flash impact clamp, a destruction burst
## detached out of the craft, and a regeneration that clears every one of them.
func _test_shared_damage_presentation(craft: CinderLongRangeBomber) -> void:
	var presentation := craft.get_damage_presentation()
	_check(
		presentation != null,
		"the bomber carries the fleet's shared damage presentation"
	)
	if presentation == null:
		return
	var sparks := presentation.get_node_or_null(^"DamageSparks") as CPUParticles3D
	var engine_sparks := presentation.get_node_or_null(^"EngineFailureSparks") as CPUParticles3D
	var smoke := presentation.get_node_or_null(^"EngineSmoke") as CPUParticles3D
	var warning := presentation.get_node_or_null(^"DamageWarningLight") as OmniLight3D
	var engine_light := presentation.get_node_or_null(^"EngineFailureLight") as OmniLight3D
	_check(
		presentation.get_script() == load("res://scripts/effects/hero_damage_presentation.gd")
		and presentation.spark_anchor.is_equal_approx(CinderLongRangeBomber.DAMAGE_SPARK_ANCHOR)
		and presentation.smoke_anchor.is_equal_approx(CinderLongRangeBomber.DAMAGE_SMOKE_ANCHOR)
		and presentation.warning_anchor.is_equal_approx(CinderLongRangeBomber.DAMAGE_WARNING_ANCHOR)
		and presentation.destruction_debris_count == CinderLongRangeBomber.DAMAGE_DEBRIS_COUNT
		and sparks != null and engine_sparks != null and smoke != null
		and warning != null and engine_light != null
		and sparks.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_SPARK_ANCHOR)
		and smoke.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_SMOKE_ANCHOR)
		and engine_sparks.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_SMOKE_ANCHOR)
		and warning.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_WARNING_ANCHOR)
		and engine_light.position.is_equal_approx(CinderLongRangeBomber.DAMAGE_SMOKE_ANCHOR),
		"the shared rig anchors its spark, smoke, warning and engine channels on this hull's own geometry"
	)
	_check(
		not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and not warning.shadow_enabled and not engine_light.shadow_enabled
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_status() == &"healthy",
		"an undamaged craft draws none of those channels and casts no extra shadow"
	)

	craft.set_physics_process(false)
	craft.set("_landed", false)
	craft.set("_engine_state", HeroShip.ENGINE_ONLINE)
	craft.call("_sync_damage_presentation")

	# Damaged: hull sparks and the amber damage practical, plus one world impact.
	craft.apply_damage(
		craft.maximum_hull * 0.45,
		craft.to_global(CinderLongRangeBomber.DAMAGE_SPARK_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"damaged"
		and sparks.emitting and sparks.visible
		and presentation.is_alarm_active()
		and warning.light_energy > 0.0
		and presentation.get_live_world_effect_count() == 1
		and not smoke.emitting,
		"damage raises the hull sparks and the damage warning light with one impact burst"
	)

	# Critical: engine smoke, engine-failure sparks and the cyan failure practical.
	craft.apply_damage(
		craft.maximum_hull * 0.35,
		craft.to_global(CinderLongRangeBomber.DAMAGE_SMOKE_ANCHOR),
		Vector3.UP
	)
	await process_frame
	await process_frame
	_check(
		presentation.get_status() == &"critical"
		and smoke.emitting and smoke.visible
		and engine_sparks.emitting and engine_sparks.visible
		and presentation.is_engine_failure_active()
		and engine_light.light_energy > 0.0
		and presentation.get_engine_power_multiplier() < 1.0,
		"critical damage raises engine smoke, engine-failure sparks and the degraded engine cue"
	)

	# The already-authoritative component roster drives the localized rig and the
	# static exhaust grade; neither is decided here.
	var model := craft.get_component_damage()
	var engine_anchor := _component_local_position(
		craft, ShipComponentDamage.COMPONENT_ENGINE_BAY
	)
	var guard := 0
	while model.get_component_state(ShipComponentDamage.COMPONENT_ENGINE_BAY) \
			< ShipComponentDamage.ComponentState.FAILED and guard < 4:
		model.record_damage(craft.maximum_hull * 2.0, engine_anchor)
		guard += 1
	craft.call("_sync_component_damage", 0.01)
	craft.call("_sync_engine_visuals_immediately")
	await process_frame
	var rig := presentation.get_node_or_null(
		"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
	) as Node3D
	var exhaust := craft.get_engine_exhaust_damage_presentation_profile()
	var visible_plumes := 0
	for plume_value in craft.get("_engine_glows") as Array:
		if is_instance_valid(plume_value) and (plume_value as MeshInstance3D).visible:
			visible_plumes += 1
	_check(
		rig != null
		and rig.position.is_equal_approx(engine_anchor)
		and presentation.get_failed_component_effect_ids().has(
			ShipComponentDamage.COMPONENT_ENGINE_BAY
		)
		and exhaust.get("stage") == &"failed"
		and visible_plumes == 0
		and not bool(exhaust.get("flashing", true))
		and not bool(exhaust.get("gameplay_authority", true)),
		"a failed engine bay shows the shared localized rig and puts out this craft's real plumes"
	)

	# Reduced flash: whatever intensity the caller resolved, the impact practical
	# is clamped to 1.6x peak and from there only decays, and the core only ever
	# expands and fades inside its authored band. There is no pulse in it.
	var world_effects_before: Dictionary = {}
	for existing in root.get_children():
		world_effects_before[existing.get_instance_id()] = true
	presentation.present_impact(craft.global_position, Vector3.UP, 4.0)
	var impact := _impact_effect_added_since(world_effects_before)
	var impact_flash := impact.get_node_or_null(^"ImpactFlash") as MeshInstance3D \
		if impact != null else null
	var impact_light := impact.get_node_or_null(^"ImpactLight") as OmniLight3D \
		if impact != null else null
	var peak_energy := impact_light.light_energy if impact_light != null else -1.0
	var previous_energy := peak_energy
	var previous_transparency := impact_flash.transparency if impact_flash != null else 0.0
	var decays_without_pulsing := impact_light != null and impact_flash != null
	for _flash_step in 8:
		await process_frame
		if not is_instance_valid(impact_light) or not is_instance_valid(impact_flash):
			break
		if impact_light.light_energy > previous_energy + 0.0001 \
				or impact_flash.transparency < previous_transparency - 0.0001 \
				or impact_flash.scale.x > HeroDamagePresentation.IMPACT_FLASH_MAXIMUM_SCALE * 1.22 + 0.0001 \
				or impact_light.omni_range > HeroDamagePresentation.IMPACT_LIGHT_MAXIMUM_RANGE + 0.0001:
			decays_without_pulsing = false
		previous_energy = impact_light.light_energy
		previous_transparency = impact_flash.transparency
	_check(
		impact_flash != null and impact_light != null
		and is_equal_approx(peak_energy, 5.2 * 1.6)
		and decays_without_pulsing
		and previous_energy < peak_energy
		and not impact_light.shadow_enabled
		and impact_flash.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"the shared impact practical stays inside the reduced-flash clamp and only decays at any intensity"
	)

	# Destruction: the burst and its debris detach out of the craft so a hidden or
	# recycled hull cannot drag them along.
	craft.apply_damage(craft.maximum_hull * 2.0, craft.global_position, Vector3.UP)
	await process_frame
	await process_frame
	var destruction := presentation.get_destruction_effect_root()
	var debris := 0
	if destruction != null:
		for child in destruction.get_children():
			if str(child.name).begins_with("HeroHullDebris"):
				debris += 1
	_check(
		craft.is_destroyed()
		and destruction != null
		and not craft.is_ancestor_of(destruction)
		and debris == CinderLongRangeBomber.DAMAGE_DEBRIS_COUNT
		and presentation.get_status() == &"destroyed",
		"destruction detaches the shared burst out of the craft with its full debris count"
	)

	# Regeneration: the berth's reuse path clears every channel it raised.
	var reset := craft.reset_for_reuse(craft.global_transform)
	await process_frame
	await process_frame
	_check(
		bool(reset.get("accepted", false))
		and presentation.get_status() == &"healthy"
		and not sparks.emitting and not smoke.emitting and not engine_sparks.emitting
		and is_zero_approx(warning.light_energy)
		and is_zero_approx(engine_light.light_energy)
		and presentation.get_destruction_effect_root() == null
		and presentation.get_live_world_effect_count() == 0
		and presentation.get_active_component_effect_count() == 0
		and presentation.get_node_or_null(
			"ComponentDamage_%s" % String(ShipComponentDamage.COMPONENT_ENGINE_BAY)
		) == null,
		"regeneration clears every damage, component, and destruction channel it raised"
	)


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


## The shared presentation detaches its impacts into the scene-tree root by
## design, and a colliding sibling there is renamed by the engine, so the burst
## one call raised is found as the root child that was not there before it.
func _impact_effect_added_since(before: Dictionary) -> Node3D:
	for candidate in root.get_children():
		if before.has(candidate.get_instance_id()):
			continue
		if candidate is Node3D and candidate.get_node_or_null(^"ImpactLight") != null:
			return candidate as Node3D
	return null
