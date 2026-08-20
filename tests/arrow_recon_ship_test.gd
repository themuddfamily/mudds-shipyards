extends SceneTree

const ARROW_SCENE := preload("res://scenes/ships/arrow_recon_ship.tscn")
const TORRENT_SCENE := preload("res://scenes/ships/torrent_interceptor.tscn")
const SHIP_LAYER := PhysicsLayers.SHIP

var _failures: Array[String] = []
var _test_root: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_root = Node3D.new()
	_test_root.name = "ArrowReconShipTestRoot"
	root.add_child(_test_root)
	var arrow := ARROW_SCENE.instantiate() as ArrowReconShip
	_check(arrow != null, "Arrow scene instantiates as ArrowReconShip")
	if arrow == null:
		_finish()
		return
	_test_root.add_child(arrow)
	await process_frame
	await physics_frame
	await physics_frame

	_test_definition_and_evidence(arrow)
	_test_distinct_presentation(arrow)
	await _test_entry_heat_attachment(arrow)
	_test_visual_performance_batch(arrow)
	_test_boarding_step_mesh_sharing(arrow)
	_test_escape_pods_and_sensors(arrow)
	_test_collision_boarding_and_cameras(arrow)
	await _test_engine_weapon_and_lifecycle(arrow)
	await _test_cleanup(arrow)
	_finish()


func _test_boarding_step_mesh_sharing(arrow: ArrowReconShip) -> void:
	var steps: Array[MeshInstance3D] = []
	for child in arrow.get_arrow_visual_root().get_children():
		var step := child as MeshInstance3D
		if step != null and step.position.y >= -0.13 and step.position.y <= 0.45 \
			and step.position.x <= -1.64 and step.position.x >= -2.30 \
			and is_equal_approx(step.position.z, 0.05):
			steps.append(step)
	var meshes: Dictionary = {}
	for step in steps:
		if step.mesh != null:
			meshes[step.mesh.get_instance_id()] = true
	_check(
		steps.size() == ArrowReconShip.BOARDING_STEP_VISIBLE_COPIES
		and meshes.size() == 1
		and steps[0].mesh is ArrayMesh
		and (steps[0].mesh as ArrayMesh).surface_get_material(0) != null
		and steps[0].mesh == steps[2].mesh,
		"three named visual-only boarding steps share one exact inherited rounded ArrayMesh while retaining all copies"
	)
	var retained := steps[0].mesh
	steps[2].mesh = (retained as ArrayMesh).duplicate() as ArrayMesh
	var split: Dictionary = {}
	for step in steps:
		split[step.mesh.get_instance_id()] = true
	_check(split.size() == 2, "RED: a private boarding-step mesh breaks the exact 3 -> 1 sharing contract")
	steps[2].mesh = retained
	meshes.clear()
	for step in steps:
		meshes[step.mesh.get_instance_id()] = true
	_check(meshes.size() == 1, "restoring the boarding-step mesh returns its sharing contract green")


func _test_definition_and_evidence(arrow: ArrowReconShip) -> void:
	var definition := arrow.get_ship_definition()
	_check(definition != null and definition.is_definition_valid(), "Arrow owns a valid ShipDefinition resource")
	if definition == null:
		return
	_check(definition.get_ship_id() == &"arrow_provisional", "definition exposes a stable Arrow candidate ID")
	_check(definition.get_display_name() == "Arrow-class Recon Ship candidate", "definition labels the craft as a candidate")
	_check(definition.get_role() == "Reconnaissance ship", "creator-supported reconnaissance role is preserved")
	_check(definition.get_evidence_status_id() == &"provisional", "definition explicitly rejects authenticated status")
	_check(not definition.is_authenticated() and definition.is_historical_claim(), "Arrow is a sourced but unauthenticated historical claim")
	_check(definition.evidence_references.size() >= 3, "definition cites creator roster, research register, and label footage")
	_check("two escape pods" in definition.evidence_notes, "definition records the supported pod-count fact")
	_check("silhouette" in definition.evidence_notes and "provisional" in definition.evidence_notes, "definition limits all shape claims")
	_check(definition.audio_profile_id == &"efficient_twin_recon", "definition exposes a distinct future audio profile")
	_check(definition.compatibility_tags.has("recon") and definition.compatibility_tags.has("small_craft"), "definition declares recon berth compatibility")

	var definition_audit := definition.get_audit_report()
	_check(bool(definition_audit.valid), "definition audit validates")
	_check(str(definition_audit.evidence_status) == "provisional", "definition audit preserves provisional status")
	var evidence := arrow.get_arrow_evidence_report()
	_check(str(evidence.evidence_scope) == "name_role_pod_count_only", "craft audit narrowly scopes supported evidence")
	_check(not bool(evidence.authenticated_geometry), "craft audit denies authenticated geometry")
	_check((evidence.creator_supported as PackedStringArray).size() == 3, "craft audit lists exactly the three supported fact categories")
	_check((evidence.modern_provisional as PackedStringArray).size() >= 5, "craft audit inventories provisional design categories")
	var audit := arrow.get_arrow_audit_report()
	_check(bool(audit.valid) and (audit.errors as PackedStringArray).is_empty(), "fully constructed Arrow passes its public audit")
	_check(int(audit.escape_pod_count) == 2 and int(audit.engine_count) == 2, "audit exposes two pods and twin engines")
	_check(str(audit.weapon_class) == "light_recon_pulse", "audit labels the deliberately lighter weapon class")
	_check(bool(arrow.get_meta("arrow_recon_candidate", false)), "root metadata identifies an Arrow candidate")
	_check(not bool(arrow.get_meta("authenticated_historical_silhouette", true)), "root metadata cannot imply historical silhouette authentication")


func _test_distinct_presentation(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	_check(visual != null and visual.name == "ArrowReconVisual", "variant replaces the Torrent exterior with a dedicated visual root")
	_check(arrow.get_node_or_null("TorrentVisual") == null, "no inherited Torrent visual hierarchy remains")
	_check(str(visual.get_meta("geometry_status", "")) == "provisional", "visual hierarchy carries provisional geometry metadata")
	_check(not bool(visual.get_meta("authenticated_historical_silhouette", true)), "visual hierarchy denies an authenticated silhouette")
	_check(visual.get_node_or_null("ReconFuselage") is MeshInstance3D, "slender recon fuselage is a real procedural mesh")
	_check(visual.get_node_or_null("PortSensorWing") is MeshInstance3D, "port sensor wing is a smooth authored planform mesh")
	_check(visual.get_node_or_null("StarboardSensorWing") is MeshInstance3D, "starboard sensor wing is a smooth authored planform mesh")
	_check(visual.get_node_or_null("DorsalSurveySpine") is MeshInstance3D, "dorsal survey spine is a curved loft")


func _test_entry_heat_attachment(arrow: ArrowReconShip) -> void:
	var visual := arrow.get_arrow_visual_root()
	var target := arrow.get_entry_heat_target()
	_check(
		target != null
		and target.name == "PlanetaryEntryHeatTarget"
		and target.get_parent() == visual
		and not target.top_level,
		"Arrow exposes exactly one typed entry-heat target as a direct non-top-level child of its final visual root"
	)
	_check(
		target != null
		and target.position == Vector3(0.0, 1.4, -0.15)
		and target.rotation == Vector3.ZERO
		and target.scale == Vector3(1.45, 1.4, 1.08),
		"Arrow entry-heat target freezes the exact authored ship-local fit"
	)
	var attachment := arrow.get_arrow_audit_report().entry_heat_attachment as Dictionary
	_check(
		bool(attachment.valid)
		and (attachment.authored_local_bounds as AABB).is_equal_approx(AABB(
			Vector3(-5.8, -1.4, -7.71), Vector3(11.6, 5.6, 15.12)
		))
		and (attachment.expanded_local_bounds as AABB).is_equal_approx(AABB(
			Vector3(-6.1625, -1.75, -7.98), Vector3(12.325, 6.3, 15.66)
		)),
		"attachment audit freezes the authored and 0.25m-standoff Arrow-local bounds"
	)
	_check(
		int(attachment.target_subtree_nodes) == 3
		and int(attachment.renderer_nodes) == 1
		and int(attachment.surface_count) == 1
		and int(attachment.geometry_submissions) == 1
		and int(attachment.visible_geometry_copies) == 1
		and int(attachment.unique_mesh_resource_allocations) == 1
		and int(attachment.exclusive_material_allocations) == 1
		and not bool(attachment.presentation_configured)
		and float(attachment.intensity_baseline) == 0.0
		and float(attachment.live_intensity) == 0.0,
		"attachment contributes exactly one three-node target subtree, renderer, surface/submission, visible copy, mesh allocation, and exclusive material"
	)
	var presentation := target.get_presentation() if target != null else null
	var state := presentation.get_state_snapshot() if presentation != null else {}
	var material := target.get_material() if target != null else null
	_check(
		presentation != null
		and not bool(state.get("configured", true))
		and int(state.get("generation", -1)) == 0
		and int(state.get("revision", -1)) == 0
		and not bool(state.get("has_presented_observation", true))
		and material != null
		and material.resource_local_to_scene
		and float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0,
		"host attachment is passive and starts at the exact zero baseline without configuring or sampling"
	)
	_check(
		target != null
		and target.is_contract_valid()
		and target.find_children("*", "CollisionObject3D", true, false).is_empty()
		and not target.is_processing()
		and not target.is_physics_processing(),
		"entry-heat attachment owns no collision or automatic process authority"
	)

	var second := ARROW_SCENE.instantiate() as ArrowReconShip
	_check(second != null, "a second Arrow instantiates for resource-ownership evidence")
	if second != null:
		second.position = Vector3(100.0, 0.0, 0.0)
		_test_root.add_child(second)
		await process_frame
		await physics_frame
		var second_target := second.get_entry_heat_target()
		var second_material := (
			second_target.get_material() if second_target != null else null
		)
		var first_overlay := target.get_overlay() if target != null else null
		var second_overlay := (
			second_target.get_overlay() if second_target != null else null
		)
		_check(
			second_target != null
			and second_target != target
			and first_overlay != null
			and second_overlay != null
			and first_overlay.mesh == second_overlay.mesh
			and material != null
			and second_material != null
			and material != second_material
			and material.shader == second_material.shader
			and float(second_material.get_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER
			)) == 0.0,
			"two Arrows share the immutable target mesh/shader but own distinct exact-zero live materials"
		)
		_check(
			_count_named(visual, "PlanetaryEntryHeatTarget") == 1
			and _count_named(
				second.get_arrow_visual_root(), "PlanetaryEntryHeatTarget"
			) == 1,
			"each live Arrow owns exactly one entry-heat target generation"
		)
		second.queue_free()
		await process_frame

	(attachment.authored_transform as Dictionary)["position"] = Vector3(INF, INF, INF)
	(attachment.target_contract as Dictionary)["valid"] = false
	_check(
		bool(arrow.get_arrow_audit_report().entry_heat_attachment.valid)
		and arrow.get_arrow_audit_report().entry_heat_attachment.authored_transform.position \
			== Vector3(0.0, 1.4, -0.15),
		"caller mutation cannot alter detached entry-heat attachment evidence"
	)
	if target != null:
		var authored_position := target.position
		target.position += Vector3(0.1, 0.0, 0.0)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"authored transform drift"
			),
			"structured-red: entry-heat attachment transform drift fails Arrow audit"
		)
		target.position = authored_position
		target.top_level = true
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"top-level transform authority"
			),
			"structured-red: top-level target drift fails Arrow audit"
		)
		target.top_level = false
		target.position = authored_position
		target.rotation = Vector3.ZERO
		target.scale = Vector3(1.45, 1.4, 1.08)
		if material != null:
			material.set_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER, 0.25
			)
			_check(
				not bool(arrow.get_arrow_audit_report().valid)
				and _report_has_error(
					arrow.get_arrow_audit_report(),
					"target contract is invalid"
				),
				"structured-red: unconfigured nonzero intensity fails Arrow target audit"
			)
			material.set_shader_parameter(
				PlanetaryEntryHeatTarget.OWNED_PARAMETER, 0.0
			)
		var duplicate := preload(
			"res://scenes/effects/planetary_entry_heat_target.tscn"
		).instantiate() as PlanetaryEntryHeatTarget
		visual.add_child(duplicate)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_audit_report(),
				"instance roster drift"
			),
			"structured-red: a duplicate entry-heat target fails the one-instance host roster"
		)
		visual.remove_child(duplicate)
		duplicate.free()
	_check(
		bool(arrow.get_arrow_audit_report().valid),
		"Arrow audit returns green after every entry-heat host mutation is restored"
	)
	var configured := presentation.configure(
		PlanetaryAtmosphereProfile.new(), material
	)
	_check(
		bool(configured.get("accepted", false))
		and bool(arrow.get_arrow_audit_report().valid),
		"a legitimate external adapter configuration keeps the immutable Arrow host audit green"
	)
	var presented := presentation.present_observation(
		14000.0, 250.0, presentation.get_generation()
	)
	_check(
		bool(presented.get("accepted", false))
		and is_equal_approx(float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)), 0.25)
		and bool(arrow.get_arrow_audit_report().valid),
		"bounded externally driven live intensity remains valid without giving Arrow sampling authority"
	)
	var reset := presentation.reset_for_reuse(presentation.get_generation())
	_check(
		bool(reset.get("accepted", false))
		and float(material.get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0
		and bool(arrow.get_arrow_audit_report().valid),
		"explicit adapter reset restores zero while the unchanged Arrow host remains valid"
	)
	var loft := (visual.get_node("ReconFuselage") as MeshInstance3D).mesh
	_check(loft is ArrayMesh and (loft as ArrayMesh).get_faces().size() > 700, "recon fuselage has a dense smooth loft rather than a box primitive")

	var arrow_weapon_cooldown := arrow.weapon_cooldown
	var torrent := TORRENT_SCENE.instantiate() as HeroShip
	_test_root.add_child(torrent)
	await process_frame
	var arrow_collision := arrow.get_node("ArrowHullCollision") as CollisionShape3D
	var torrent_collision := torrent.get_node("HullCollision") as CollisionShape3D
	var arrow_box := arrow_collision.shape as BoxShape3D
	var torrent_box := torrent_collision.shape as BoxShape3D
	_check(arrow_box.size.z > torrent_box.size.z * 1.35, "Arrow collision envelope is substantially longer than Torrent")
	_check(arrow_box.size.x < torrent_box.size.x * 0.7, "Arrow core is substantially narrower than Torrent")
	_check(arrow.maximum_speed > torrent.maximum_speed, "Arrow has a faster recon top-speed profile")
	_check(arrow.thrust_acceleration < torrent.thrust_acceleration, "Arrow trades launch acceleration for efficient speed")
	_check(arrow.yaw_speed_degrees < torrent.yaw_speed_degrees, "long recon craft turns differently from the interceptor")
	_check(arrow.roll_speed_degrees > torrent.roll_speed_degrees, "Arrow has a distinct higher roll response")
	_check(arrow.maximum_hull < torrent.maximum_hull, "Arrow is lighter and more fragile than the interceptor")
	_check(arrow_weapon_cooldown > torrent.weapon_cooldown, "Arrow's light pulse weapons fire more slowly than Torrent cannons")
	torrent.queue_free()
	await process_frame


func _test_escape_pods_and_sensors(arrow: ArrowReconShip) -> void:
	_check(arrow.get_escape_pod_count() == 2, "Arrow visibly exposes exactly two escape pods")
	var pods := arrow.get_escape_pods()
	_check(pods.size() == 2 and pods[0] != pods[1], "escape pods are distinct scene-tree modules")
	var port := arrow.get_escape_pod(&"port")
	var starboard := arrow.get_escape_pod(&"starboard")
	_check(port != null and starboard != null, "both port and starboard pods resolve by stable side ID")
	_check(arrow.get_escape_pod(&"missing") == null, "unknown pod side has no fallback")
	if port != null and starboard != null:
		_check(port.position.x < -1.0 and starboard.position.x > 1.0, "pods are visibly separated on opposite fuselage sides")
		_check(port.position.distance_to(starboard.position) > 3.0, "pod pressure shells are not a duplicated central decoration")
		for pod in [port, starboard]:
			_check(bool(pod.get_meta("escape_pod", false)), "%s is semantically tagged as escape pod" % pod.name)
			_check(str(pod.get_meta("geometry_status", "")) == "provisional", "%s exposes provisional geometry status" % pod.name)
			_check(bool(pod.get_meta("separable_visual_module", false)), "%s is a visibly separable module" % pod.name)
			_check(not bool(pod.get_meta("release_mechanism_implemented", true)), "%s does not falsely claim a working release system" % pod.name)
			_check(pod.get_node_or_null("PodPressureShell") is MeshInstance3D, "%s owns a smooth pressure shell" % pod.name)
			_check(pod.get_node_or_null("PodSeparationCollar") is MeshInstance3D, "%s has a legible separation collar" % pod.name)

	var mast := arrow.get_sensor_mast()
	_check(mast != null and mast.name == "SensorSweep", "Arrow exposes its rotating sensor sweep")
	_check(mast != null and mast.get_parent().name == "ReconSensorMast", "sensor sweep sits on a dedicated dorsal mast")
	var receiver_report := arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary
	_check(
		bool(receiver_report.valid) and int(receiver_report.geometry_nodes) == 2
			and int(receiver_report.primitive_mesh_allocations) == 1,
		"mirrored sensor receivers retain one exact shared SphereMesh"
	)
	if mast != null:
		var receiver := mast.get_node_or_null("ArrayReceiver") as MeshInstance3D
		if receiver != null:
			var shared_mesh := receiver.mesh
			receiver.mesh = shared_mesh.duplicate() as SphereMesh
			_check(
				not bool((arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary).valid),
				"structured-red: one private receiver mesh fails the sharing audit"
			)
			receiver.mesh = shared_mesh
			_check(
				bool((arrow.get_arrow_visual_performance_report().array_receiver_mesh_sharing as Dictionary).valid),
				"restoring the shared receiver mesh clears the allocation audit"
			)
	_check(arrow.get_arrow_visual_root().get_node_or_null("VentralSensorGimbal") is MeshInstance3D, "recon craft has a ventral optical/spectral gimbal")
	_check(
		arrow.get_arrow_visual_root().get_node_or_null("PortLateralArray") != null
		and arrow.get_arrow_visual_root().get_node_or_null("StarboardLateralArray") != null,
		"recon craft exposes paired lateral sensor arrays"
	)


func _test_visual_performance_batch(arrow: ArrowReconShip) -> void:
	var report := arrow.get_arrow_visual_performance_report()
	if not bool(report.valid):
		print("ARROW_VISUAL_CENSUS_ERRORS: ", report.errors)
	var local_evidence_format := (
		"ARROW_WING_ROOT_RIB_BATCH: nodes %d->%d submissions %d->%d "
		+ "primitive_mesh_allocations %d->%d visible_copies %d->%d"
	)
	print(local_evidence_format % [
			int(report.wing_root_rib_batch.legacy.geometry_nodes),
			int(report.wing_root_rib_batch.geometry_nodes),
			int(report.wing_root_rib_batch.legacy.geometry_submissions),
			int(report.wing_root_rib_batch.geometry_submissions),
			int(report.wing_root_rib_batch.legacy.primitive_mesh_allocations),
		int(report.wing_root_rib_batch.primitive_mesh_allocations),
		int(report.wing_root_rib_batch.legacy.visible_geometry_copies),
		int(report.wing_root_rib_batch.visible_geometry_copies),
	])
	var joint_evidence_format := (
		"ARROW_LATERAL_ARRAY_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(joint_evidence_format % [
		int(report.lateral_array_curve_joint_sharing.legacy.geometry_nodes),
		int(report.lateral_array_curve_joint_sharing.geometry_nodes),
		int(report.lateral_array_curve_joint_sharing.legacy.geometry_submissions),
		int(report.lateral_array_curve_joint_sharing.geometry_submissions),
		int(report.lateral_array_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.lateral_array_curve_joint_sharing.primitive_mesh_allocations),
		int(report.lateral_array_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.lateral_array_curve_joint_sharing.visible_geometry_copies),
	])
	var leading_edge_evidence_format := (
		"ARROW_SENSOR_LEADING_EDGE_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(leading_edge_evidence_format % [
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.geometry_nodes),
		int(report.sensor_leading_edge_curve_joint_sharing.geometry_nodes),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.geometry_submissions),
		int(report.sensor_leading_edge_curve_joint_sharing.geometry_submissions),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations),
		int(report.sensor_leading_edge_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.sensor_leading_edge_curve_joint_sharing.visible_geometry_copies),
	])
	var dorsal_conduit_evidence_format := (
		"ARROW_DORSAL_DATA_CONDUIT_CURVE_JOINT_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(dorsal_conduit_evidence_format % [
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.geometry_nodes),
		int(report.dorsal_data_conduit_curve_joint_sharing.geometry_nodes),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.geometry_submissions),
		int(report.dorsal_data_conduit_curve_joint_sharing.geometry_submissions),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.primitive_mesh_allocations),
		int(report.dorsal_data_conduit_curve_joint_sharing.primitive_mesh_allocations),
		int(report.dorsal_data_conduit_curve_joint_sharing.legacy.visible_geometry_copies),
		int(report.dorsal_data_conduit_curve_joint_sharing.visible_geometry_copies),
	])
	var panel_band_evidence_format := (
		"ARROW_FUSELAGE_PANEL_BAND_MESH_SHARING: nodes %d->%d "
		+ "submissions %d->%d primitive_mesh_allocations %d->%d "
		+ "visible_copies %d->%d"
	)
	print(panel_band_evidence_format % [
		int(report.fuselage_panel_band_mesh_sharing.legacy.geometry_nodes),
		int(report.fuselage_panel_band_mesh_sharing.geometry_nodes),
		int(report.fuselage_panel_band_mesh_sharing.legacy.geometry_submissions),
		int(report.fuselage_panel_band_mesh_sharing.geometry_submissions),
		int(report.fuselage_panel_band_mesh_sharing.legacy.primitive_mesh_allocations),
		int(report.fuselage_panel_band_mesh_sharing.primitive_mesh_allocations),
		int(report.fuselage_panel_band_mesh_sharing.legacy.visible_geometry_copies),
		int(report.fuselage_panel_band_mesh_sharing.visible_geometry_copies),
	])
	var whole_evidence_format := (
		"ARROW_VISUAL_CENSUS: nodes %d->%d submissions %d->%d "
		+ "unique_mesh_allocations %d->%d visible_copies %d->%d"
	)
	print(whole_evidence_format % [
			int(report.legacy.nodes), int(report.current.nodes),
			int(report.legacy.geometry_submissions),
			int(report.current.geometry_submissions),
			int(report.legacy.unique_mesh_resource_allocations),
			int(report.current.unique_mesh_resource_allocations),
			int(report.legacy.visible_geometry_copies),
			int(report.current.visible_geometry_copies),
	])
	_check(
		bool(report.valid)
		and report.current == report.expected
		and report.current == {
			"nodes": 179,
			"mesh_instance_nodes": 158,
			"multi_mesh_instance_nodes": 1,
			"geometry_submissions": 159,
			"visible_geometry_copies": 160,
			"unique_mesh_resource_allocations": 123,
			"auto_fallback_names": 23,
		},
		"whole Arrow visual freezes the exact Stage-2 179-node, 159-submission, 123-mesh census with all 160 copies"
	)
	_check(
		report.phase9_before_entry_heat == {
			"nodes": 176,
			"mesh_instance_nodes": 157,
			"multi_mesh_instance_nodes": 1,
			"geometry_submissions": 158,
			"visible_geometry_copies": 159,
			"unique_mesh_resource_allocations": 122,
			"auto_fallback_names": 23,
		}
		and report.entry_heat_target_delta == {
			"target_subtree_nodes": 3,
			"renderer_nodes": 1,
			"surface_count": 1,
			"geometry_submissions": 1,
			"visible_geometry_copies": 1,
			"unique_mesh_resource_allocations": 1,
			"exclusive_material_allocations": 1,
		}
		and report.reductions == {
			"nodes": -2,
			"geometry_submissions": 0,
			"unique_mesh_resource_allocations": 19,
			"auto_fallback_names": 1,
			"visible_geometry_copies": -1,
		}
		and report.phase9_reductions_before_entry_heat == {
			"nodes": 1,
			"geometry_submissions": 1,
			"unique_mesh_resource_allocations": 20,
			"auto_fallback_names": 1,
			"visible_geometry_copies": 0,
		},
		"Stage-2 evidence isolates the exact entry-heat delta from the frozen Phase-9 optimized visual"
	)
	_check(
		report.wing_root_rib_batch.legacy == {
			"geometry_nodes": 2,
			"geometry_submissions": 2,
			"visible_geometry_copies": 2,
			"primitive_mesh_allocations": 2,
			"multimesh_allocations": 0,
		}
		and int(report.wing_root_rib_batch.geometry_nodes) == 1
		and int(report.wing_root_rib_batch.geometry_submissions) == 1
		and int(report.wing_root_rib_batch.visible_geometry_copies) == 2
		and int(report.wing_root_rib_batch.primitive_mesh_allocations) == 1
		and int(report.wing_root_rib_batch.multimesh_allocations) == 1,
		"local rib family records exact 2->1 node/submission/primitive allocation with its two visible copies unchanged"
	)
	_check(
		report.lateral_array_curve_joint_sharing.legacy == {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		}
		and int(report.lateral_array_curve_joint_sharing.geometry_nodes) == 6
		and int(report.lateral_array_curve_joint_sharing.geometry_submissions) == 6
		and int(report.lateral_array_curve_joint_sharing.visible_geometry_copies) == 6
		and int(report.lateral_array_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.lateral_array_curve_joint_sharing.resource_allocation_reduction) == 5
		and report.lateral_array_curve_joint_sharing.node_paths == PackedStringArray([
			"PortLateralArray/CurveJoint",
			"PortLateralArray/@MeshInstance3D@15",
			"PortLateralArray/@MeshInstance3D@16",
			"StarboardLateralArray/CurveJoint",
			"StarboardLateralArray/@MeshInstance3D@17",
			"StarboardLateralArray/@MeshInstance3D@18",
		]),
		"six unchanged lateral-array nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of six"
	)
	_check(
		report.sensor_leading_edge_curve_joint_sharing.legacy == {
			"geometry_nodes": 6,
			"geometry_submissions": 6,
			"visible_geometry_copies": 6,
			"primitive_mesh_allocations": 6,
		}
		and int(report.sensor_leading_edge_curve_joint_sharing.geometry_nodes) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.geometry_submissions) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.visible_geometry_copies) == 6
		and int(report.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.sensor_leading_edge_curve_joint_sharing.resource_allocation_reduction) == 5
		and report.sensor_leading_edge_curve_joint_sharing.node_paths == PackedStringArray([
			"SensorLeadingEdge/CurveJoint",
			"SensorLeadingEdge/@MeshInstance3D@2",
			"SensorLeadingEdge/@MeshInstance3D@3",
			"@Node3D@4/CurveJoint",
			"@Node3D@4/@MeshInstance3D@5",
			"@Node3D@4/@MeshInstance3D@6",
		]),
		"six unchanged sensor-leading-edge nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of six"
	)
	_check(
		report.dorsal_data_conduit_curve_joint_sharing.legacy == {
			"geometry_nodes": 3,
			"geometry_submissions": 3,
			"visible_geometry_copies": 3,
			"primitive_mesh_allocations": 3,
		}
		and int(report.dorsal_data_conduit_curve_joint_sharing.geometry_nodes) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.geometry_submissions) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.visible_geometry_copies) == 3
		and int(report.dorsal_data_conduit_curve_joint_sharing.primitive_mesh_allocations) == 1
		and int(report.dorsal_data_conduit_curve_joint_sharing.resource_allocation_reduction) == 2
		and report.dorsal_data_conduit_curve_joint_sharing.node_paths == PackedStringArray([
			"DorsalDataConduit/CurveJoint",
			"DorsalDataConduit/@MeshInstance3D@8",
			"DorsalDataConduit/@MeshInstance3D@9",
		]),
		"three named dorsal-conduit nodes/submissions/copies and exact paths now retain one immutable SphereMesh instead of three"
	)
	_check(
		report.fuselage_panel_band_mesh_sharing.legacy == {
			"geometry_nodes": 5,
			"geometry_submissions": 5,
			"visible_geometry_copies": 5,
			"primitive_mesh_allocations": 5,
		}
		and int(report.fuselage_panel_band_mesh_sharing.geometry_nodes) == 5
		and int(report.fuselage_panel_band_mesh_sharing.geometry_submissions) == 5
		and int(report.fuselage_panel_band_mesh_sharing.visible_geometry_copies) == 5
		and int(report.fuselage_panel_band_mesh_sharing.primitive_mesh_allocations) == 1
		and int(report.fuselage_panel_band_mesh_sharing.resource_allocation_reduction) == 4
		and not bool(report.fuselage_panel_band_mesh_sharing.normalised_by_torus_budget)
		and report.fuselage_panel_band_mesh_sharing.authored_tessellation == Vector2i(64, 18)
		and report.fuselage_panel_band_mesh_sharing.current_tessellation == Vector2i(64, 18)
		and (report.fuselage_panel_band_mesh_sharing.node_paths as PackedStringArray).size() == 5
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[0]) == "FuselagePanelBand"
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[1]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[2]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[3]).begins_with("@MeshInstance3D@")
		and str(report.fuselage_panel_band_mesh_sharing.node_paths[4]).begins_with("@MeshInstance3D@"),
		"five ordinary named panel-band nodes/submissions/copies retain one exact authored TorusMesh instead of five"
	)
	var visual := arrow.get_arrow_visual_root()
	var batch := visual.get_node_or_null("WingRootRibBatch") as MultiMeshInstance3D
	_check(
		batch != null and batch.multimesh != null
		and batch.multimesh.instance_count == 2
		and batch.multimesh.visible_instance_count == 2
		and batch.get_child_count() == 0
		and batch.get_script() == null
		and bool(batch.get_meta("visual_detail_only", false))
		and (batch.get_meta("authored_instance_transforms", []) as Array).size() == 2
		and batch.get_groups().is_empty()
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty()
		and visual.get_node_or_null("WingRootRib") == null,
		"the rib batch owns only visual-detail audit metadata and no script, group, child, or collision authority"
	)
	_check(
		visual.get_node_or_null("FuselagePanelBand") is MeshInstance3D,
		"the torus-smoothness evidence node remains independently addressable"
	)

	# Detached report and structured-red mutations cover the whole census,
	# authored transform buffer, visible roster, and shared primitive allocation.
	(report.current as Dictionary)["nodes"] = -1
	(report.wing_root_rib_batch as Dictionary)["geometry_nodes"] = -1
	(report.lateral_array_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.sensor_leading_edge_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.dorsal_data_conduit_curve_joint_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.fuselage_panel_band_mesh_sharing as Dictionary)["primitive_mesh_allocations"] = -1
	(report.entry_heat_target as Dictionary)["target_subtree_nodes"] = -1
	var detached_dorsal_transforms := (
		report.dorsal_data_conduit_curve_joint_sharing.authored_transforms as Array
	)
	detached_dorsal_transforms[0] = Transform3D.IDENTITY
	var detached_panel_transforms := (
		report.fuselage_panel_band_mesh_sharing.authored_transforms as Array
	)
	detached_panel_transforms[0] = Transform3D.IDENTITY
	_check(
		int(arrow.get_arrow_visual_performance_report().current.nodes) == 179
		and int(
			arrow.get_arrow_visual_performance_report()
				.lateral_array_curve_joint_sharing.primitive_mesh_allocations
		) == 1
		and int(
			arrow.get_arrow_visual_performance_report()
				.entry_heat_target.target_subtree_nodes
		) == 3,
		"caller mutation cannot alter the detached visual or entry-heat performance evidence"
	)
	_check(
		int(
			arrow.get_arrow_visual_performance_report()
				.sensor_leading_edge_curve_joint_sharing.primitive_mesh_allocations
		) == 1,
		"caller mutation cannot alter detached sensor-leading-edge allocation evidence"
	)
	var fresh_dorsal_report := (
		arrow.get_arrow_visual_performance_report()
			.dorsal_data_conduit_curve_joint_sharing as Dictionary
	)
	_check(
		int(fresh_dorsal_report.primitive_mesh_allocations) == 1
		and not ((fresh_dorsal_report.authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"caller mutation cannot alter detached dorsal-conduit allocation or transform evidence"
	)
	var fresh_panel_report := (
		arrow.get_arrow_visual_performance_report()
			.fuselage_panel_band_mesh_sharing as Dictionary
	)
	_check(
		int(fresh_panel_report.primitive_mesh_allocations) == 1
		and not ((fresh_panel_report.authored_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"caller mutation cannot alter detached panel-band allocation or transform evidence"
	)
	var torus_budget_report := TorusGeometryBudget.normalise_tree(arrow)
	var budgeted_panel_report := (
		arrow.get_arrow_visual_performance_report()
			.fuselage_panel_band_mesh_sharing as Dictionary
	)
	_check(
		bool(budgeted_panel_report.valid)
		and bool(budgeted_panel_report.normalised_by_torus_budget)
		and budgeted_panel_report.authored_tessellation == Vector2i(64, 18)
		and budgeted_panel_report.current_tessellation == Vector2i(41, 12)
		and int(torus_budget_report.tori) == 14,
		"production torus budget retains the exact 64x18 authored recipe and yields the shared panel band's live 41x12 recipe"
	)
	var injected := Node3D.new()
	injected.name = "ForbiddenVisualAllocation"
	visual.add_child(injected)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"whole visual census drift: nodes"
		),
		"structured-red: an unbudgeted visual node fails the whole Arrow census"
	)
	visual.remove_child(injected)
	injected.free()
	if batch != null and batch.multimesh != null:
		var authored_transforms := (
			batch.get_meta("authored_instance_transforms", []) as Array
		).duplicate()
		var corrupted_transforms := authored_transforms.duplicate()
		var authored_transform := corrupted_transforms[0] as Transform3D
		corrupted_transforms[0] = Transform3D(
			authored_transform.basis,
			authored_transform.origin + Vector3(0.1, 0, 0)
		)
		batch.set_meta("authored_instance_transforms", corrupted_transforms)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib authored transform metadata drift"
			),
			"structured-red: an authored rib transform mutation fails presentation audit"
		)
		batch.set_meta("authored_instance_transforms", authored_transforms)
		var authored_bounds := batch.multimesh.custom_aabb
		batch.multimesh.custom_aabb = authored_bounds.grow(0.1)
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib culling bounds drift"
			),
			"structured-red: a rib batch culling-bounds mutation fails presentation audit"
		)
		batch.multimesh.custom_aabb = authored_bounds
		batch.multimesh.visible_instance_count = 1
		_check(
			not bool(arrow.get_arrow_audit_report().valid)
			and _report_has_error(
				arrow.get_arrow_visual_performance_report(),
				"wing-root rib visible-copy roster drift"
			),
			"structured-red: hiding one batched rib fails the visible-copy roster"
		)
		batch.multimesh.visible_instance_count = 2
		var box := batch.multimesh.mesh as BoxMesh
		if box != null:
			var authored_size := box.size
			box.size.x += 0.1
			_check(
				not bool(arrow.get_arrow_audit_report().valid)
				and _report_has_error(
					arrow.get_arrow_visual_performance_report(),
					"wing-root rib primitive allocation drift"
				),
				"structured-red: shared rib primitive mutation fails presentation audit"
			)
			box.size = authored_size
	var lateral_report := (
		arrow.get_arrow_visual_performance_report()
			.lateral_array_curve_joint_sharing as Dictionary
	)
	var joint_paths := lateral_report.node_paths as PackedStringArray
	var first_joint := visual.get_node(NodePath(joint_paths[0])) as MeshInstance3D
	var last_joint := visual.get_node(NodePath(joint_paths[-1])) as MeshInstance3D
	var shared_joint_mesh := first_joint.mesh as SphereMesh
	last_joint.mesh = shared_joint_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private lateral-array joint mesh fails shared-allocation identity"
	)
	last_joint.mesh = shared_joint_mesh
	var authored_radius := shared_joint_mesh.radius
	shared_joint_mesh.radius += 0.01
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint primitive recipe drift"
		),
		"structured-red: shared lateral-array sphere recipe mutation fails presentation audit"
	)
	shared_joint_mesh.radius = authored_radius
	var authored_material := shared_joint_mesh.material
	shared_joint_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint material identity drift"
		),
		"structured-red: lateral-array material mutation fails presentation audit"
	)
	shared_joint_mesh.material = authored_material
	last_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"lateral-array CurveJoint render-state drift"
		),
		"structured-red: lateral-array shadow mutation fails presentation audit"
	)
	last_joint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var leading_edge_report := (
		arrow.get_arrow_visual_performance_report()
			.sensor_leading_edge_curve_joint_sharing as Dictionary
	)
	var leading_edge_paths := leading_edge_report.node_paths as PackedStringArray
	var first_leading_edge_joint := (
		visual.get_node(NodePath(leading_edge_paths[0])) as MeshInstance3D
	)
	var last_leading_edge_joint := (
		visual.get_node(NodePath(leading_edge_paths[-1])) as MeshInstance3D
	)
	var shared_leading_edge_mesh := first_leading_edge_joint.mesh as SphereMesh
	last_leading_edge_joint.mesh = shared_leading_edge_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private sensor-leading-edge joint mesh fails shared-allocation identity"
	)
	last_leading_edge_joint.mesh = shared_leading_edge_mesh
	var authored_leading_edge_rings := shared_leading_edge_mesh.rings
	shared_leading_edge_mesh.rings -= 1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint primitive recipe drift"
		),
		"structured-red: shared sensor-leading-edge sphere recipe mutation fails presentation audit"
	)
	shared_leading_edge_mesh.rings = authored_leading_edge_rings
	var authored_leading_edge_material := shared_leading_edge_mesh.material
	shared_leading_edge_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint material identity drift"
		),
		"structured-red: sensor-leading-edge material mutation fails presentation audit"
	)
	shared_leading_edge_mesh.material = authored_leading_edge_material
	last_leading_edge_joint.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint render-state drift"
		),
		"structured-red: sensor-leading-edge renderer-layer mutation fails presentation audit"
	)
	last_leading_edge_joint.layers = 1
	last_leading_edge_joint.set_meta("forbidden_semantic_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"sensor-leading-edge CurveJoint gained semantic authority"
		),
		"structured-red: sensor-leading-edge semantic metadata fails the zero-authority audit"
	)
	last_leading_edge_joint.remove_meta("forbidden_semantic_authority")
	var dorsal_conduit_report := (
		arrow.get_arrow_visual_performance_report()
			.dorsal_data_conduit_curve_joint_sharing as Dictionary
	)
	var dorsal_joint_paths := dorsal_conduit_report.node_paths as PackedStringArray
	var first_dorsal_joint := (
		visual.get_node(NodePath(dorsal_joint_paths[0])) as MeshInstance3D
	)
	var last_dorsal_joint := (
		visual.get_node(NodePath(dorsal_joint_paths[-1])) as MeshInstance3D
	)
	var shared_dorsal_mesh := first_dorsal_joint.mesh as SphereMesh
	last_dorsal_joint.mesh = shared_dorsal_mesh.duplicate() as SphereMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint shared-mesh identity drift"
		),
		"structured-red: one private dorsal-conduit joint mesh fails shared-allocation identity"
	)
	last_dorsal_joint.mesh = shared_dorsal_mesh
	var authored_dorsal_radial_segments := shared_dorsal_mesh.radial_segments
	shared_dorsal_mesh.radial_segments -= 1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint primitive recipe drift"
		),
		"structured-red: shared dorsal-conduit sphere recipe mutation fails presentation audit"
	)
	shared_dorsal_mesh.radial_segments = authored_dorsal_radial_segments
	var authored_dorsal_material := shared_dorsal_mesh.material
	shared_dorsal_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint material identity drift"
		),
		"structured-red: dorsal-conduit sensor-material mutation fails presentation audit"
	)
	shared_dorsal_mesh.material = authored_dorsal_material
	last_dorsal_joint.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint render-state drift"
		),
		"structured-red: dorsal-conduit renderer-layer mutation fails presentation audit"
	)
	last_dorsal_joint.layers = 1
	last_dorsal_joint.set_meta("forbidden_lifecycle_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"dorsal-data-conduit CurveJoint gained semantic authority"
		),
		"structured-red: dorsal-conduit lifecycle metadata fails the zero-authority audit"
	)
	last_dorsal_joint.remove_meta("forbidden_lifecycle_authority")
	var panel_band_paths := (
		budgeted_panel_report.node_paths as PackedStringArray
	)
	var first_panel_band := (
		visual.get_node(NodePath(panel_band_paths[0])) as MeshInstance3D
	)
	var last_panel_band := (
		visual.get_node(NodePath(panel_band_paths[-1])) as MeshInstance3D
	)
	var shared_panel_band_mesh := first_panel_band.mesh as TorusMesh
	last_panel_band.mesh = shared_panel_band_mesh.duplicate() as TorusMesh
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band shared-mesh identity drift"
		),
		"structured-red: one private panel-band mesh fails shared-allocation identity"
	)
	last_panel_band.mesh = shared_panel_band_mesh
	var budgeted_ring_segments := shared_panel_band_mesh.ring_segments
	shared_panel_band_mesh.ring_segments -= 1
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band primitive recipe drift"
		),
		"structured-red: shared panel-band live recipe mutation fails presentation audit"
	)
	shared_panel_band_mesh.ring_segments = budgeted_ring_segments
	var authored_panel_tessellation: Vector2i = shared_panel_band_mesh.get_meta(
		TorusGeometryBudget.AUTHORED_META
	)
	shared_panel_band_mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META,
		Vector2i(authored_panel_tessellation.x - 1, authored_panel_tessellation.y)
	)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band authored budget metadata drift"
		),
		"structured-red: panel-band authored-budget metadata mutation fails its 64x18 provenance gate"
	)
	shared_panel_band_mesh.set_meta(
		TorusGeometryBudget.AUTHORED_META, authored_panel_tessellation
	)
	var authored_panel_material := shared_panel_band_mesh.material
	shared_panel_band_mesh.material = null
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band material identity drift"
		),
		"structured-red: panel-band titanium-material mutation fails presentation audit"
	)
	shared_panel_band_mesh.material = authored_panel_material
	last_panel_band.layers = 2
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band render-state drift"
		),
		"structured-red: panel-band renderer-layer mutation fails presentation audit"
	)
	last_panel_band.layers = 1
	last_panel_band.set_meta("forbidden_semantic_authority", true)
	_check(
		not bool(arrow.get_arrow_audit_report().valid)
		and _report_has_error(
			arrow.get_arrow_visual_performance_report(),
			"fuselage panel-band gained semantic authority"
		),
		"structured-red: panel-band metadata fails the zero-authority audit"
	)
	last_panel_band.remove_meta("forbidden_semantic_authority")
	_check(
		bool(arrow.get_arrow_audit_report().valid),
		"whole/local Arrow visual audits return green after every mutation is restored"
	)


func _test_collision_boarding_and_cameras(arrow: ArrowReconShip) -> void:
	_check(arrow.collision_layer == SHIP_LAYER, "Arrow uses canonical Ship physics layer")
	_check(arrow.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Arrow collides with world, players, and ships")
	var collisions: Array[Node] = []
	for child in arrow.get_children():
		if child is CollisionShape3D:
			collisions.append(child)
	_check(collisions.size() == 2, "Arrow has exactly two named direct hull collision shapes")
	_check(arrow.get_node_or_null("ArrowHullCollision") is CollisionShape3D, "slender fuselage has a named collision shape")
	_check(arrow.get_node_or_null("ArrowWingCollision") is CollisionShape3D, "sensor-wing planform has a named collision shape")

	var boarding_area := arrow.get_node_or_null("ShipBoardingArea") as ShipBoardingArea
	_check(boarding_area != null and boarding_area.get_ship() == arrow, "physical boarding area resolves the Arrow owner generically")
	_check(boarding_area != null and boarding_area.is_available(), "parked Arrow begins physically boardable")
	_check("ARROW RECON SHIP" in boarding_area.get_prompt(), "boarding prompt names the recon craft")
	_check(arrow.get_boarding_position().distance_to(boarding_area.global_position - Vector3.UP * 0.5) < 0.1, "boarding marker and interaction area align")
	var entry := arrow.get_boarding_entry_transform()
	var seat := arrow.get_pilot_seat_anchor()
	_check(entry.origin.is_finite() and seat != null and seat.global_position.is_finite(), "inherited physical entry and seat remain valid")
	_check(entry.origin.distance_to(seat.global_position) < 3.0, "boarding entry remains a short physical transition to the seat")
	_check(arrow.get_exit_transform().origin.distance_to(arrow.global_position) > 5.8, "exit marker clears the full sensor-wing collision")

	var chase := arrow.get_camera()
	_check(chase != null and chase.name == "ShipCamera", "Arrow inherits a physical chase camera")
	arrow.set_piloted(true)
	_check(chase.current, "piloting activates Arrow chase view")
	arrow.set_cockpit_view(true)
	var cockpit_camera := arrow.get_camera()
	_check(cockpit_camera != null and cockpit_camera.name == "CockpitCamera" and cockpit_camera.current, "Arrow switches to inherited physical cockpit camera")
	_check(cockpit_camera.get_parent().name == "CockpitInterior", "cockpit camera remains inside the modelled cabin")
	arrow.set_cockpit_view(false)
	arrow.set_piloted(false)

	var canopy := arrow.get_arrow_visual_root().get_node_or_null("CanopyHinge") as Node3D
	_check(canopy != null, "functional inherited canopy pivot remains intact")
	var port_hinge_mount := arrow.get_arrow_visual_root().get_node_or_null("PortCanopyHingeMount") as MeshInstance3D
	var starboard_hinge_mount := arrow.get_arrow_visual_root().get_node_or_null("StarboardCanopyHingeMount") as MeshInstance3D
	_check(
		port_hinge_mount != null and starboard_hinge_mount != null
		and port_hinge_mount.position.x < 0.0 and starboard_hinge_mount.position.x > 0.0,
		"Arrow preserves both explicitly named canopy hinge mounts"
	)
	_check(
		canopy.get_node_or_null("PortCanopyTopRail") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyTopRail") is MeshInstance3D
		and canopy.get_node_or_null("PortCanopyNoseFrame") is MeshInstance3D
		and canopy.get_node_or_null("StarboardCanopyNoseFrame") is MeshInstance3D,
		"Arrow preserves and restyles both named canopy sides"
	)
	arrow.set_canopy_open(true, 0.0)
	await process_frame
	_check(arrow.is_canopy_open() and canopy.rotation.x > 0.8, "Arrow canopy opens through the common physical lifecycle")
	arrow.set_canopy_open(false, 0.0)
	await process_frame
	_check(not arrow.is_canopy_open() and absf(canopy.rotation.x) < 0.01, "Arrow canopy reseals without rebuilding its pivot")


func _test_engine_weapon_and_lifecycle(arrow: ArrowReconShip) -> void:
	var rib_batch := arrow.get_arrow_visual_root().get_node_or_null(
		"WingRootRibBatch"
	) as MultiMeshInstance3D
	var rib_batch_identity := rib_batch.get_instance_id() if rib_batch != null else 0
	var entry_target := arrow.get_entry_heat_target()
	var entry_overlay := entry_target.get_overlay() if entry_target != null else null
	var entry_material := entry_target.get_material() if entry_target != null else null
	var entry_mesh := entry_overlay.mesh if entry_overlay != null else null
	var entry_shader := entry_material.shader if entry_material != null else null
	var entry_target_identity := (
		entry_target.get_instance_id() if entry_target != null else 0
	)
	_test_root.remove_child(arrow)
	await process_frame
	_check(
		arrow.get_entry_heat_target() == entry_target
		and entry_target != null
		and entry_target.get_parent() == arrow.get_arrow_visual_root()
		and entry_target.get_material() == entry_material,
		"whole-Arrow detach retains the same passive target, visual-root parent, and exclusive material"
	)
	_test_root.add_child(arrow)
	await process_frame
	await physics_frame
	_check(
		arrow.get_entry_heat_target() == entry_target
		and entry_target != null
		and entry_target.get_instance_id() == entry_target_identity
		and bool(arrow.get_arrow_audit_report().valid),
		"whole-Arrow re-entry restores no target and preserves the sole attachment identity"
	)
	var fired_events: Array[Dictionary] = []
	arrow.projectile_fired.connect(func(origin: Vector3, direction: Vector3) -> void:
		fired_events.append({"origin": origin, "direction": direction})
	)
	arrow.engine_start_time = 0.03
	arrow.weapon_cooldown = 0.05
	arrow.set_piloted(true)
	arrow.request_engine_start()
	for index in 8:
		await physics_frame
	var telemetry := arrow.get_telemetry()
	_check(str(telemetry.engine_state) == "ONLINE", "Arrow completes the inherited engine-start lifecycle")
	_check(str(telemetry.ship_id) == "arrow_provisional" and str(telemetry.role) == "Reconnaissance ship", "telemetry carries Arrow identity and role")
	var plumes: Array[MeshInstance3D] = []
	var port_plume := arrow.get_arrow_visual_root().get_node_or_null("PortEnginePlume") as MeshInstance3D
	var starboard_plume := arrow.get_arrow_visual_root().get_node_or_null("StarboardEnginePlume") as MeshInstance3D
	if port_plume != null:
		plumes.append(port_plume)
	if starboard_plume != null:
		plumes.append(starboard_plume)
	_check(plumes.size() == 2, "Arrow has exactly two efficient engine plumes")
	_check(
		plumes.size() == 2
		and (plumes[0] as MeshInstance3D).visible
		and (plumes[1] as MeshInstance3D).visible,
		"both twin-engine plumes activate online"
	)

	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired_events.size() == 1, "Arrow emits one light pulse from real flight input")
	if not fired_events.is_empty():
		var first_origin: Vector3 = fired_events[0].origin
		_check(first_origin.distance_to(arrow.to_global(Vector3(-1.05, 0.72, -5.7))) < 0.1, "first pulse originates from repositioned port muzzle")
		_check((fired_events[0].direction as Vector3).dot(-arrow.global_basis.z) > 0.9, "light pulse fires along the visible nose axis")
	for index in 5:
		await physics_frame
	Input.action_press("fire")
	await physics_frame
	Input.action_release("fire")
	_check(fired_events.size() == 2, "second pulse alternates after cooldown")
	if fired_events.size() >= 2:
		var second_origin: Vector3 = fired_events[1].origin
		_check(second_origin.distance_to(arrow.to_global(Vector3(1.05, 0.72, -5.7))) < 0.1, "second pulse originates from repositioned starboard muzzle")

	arrow.set_piloted(false)
	arrow.request_engine_stop()
	arrow.apply_damage(arrow.maximum_hull + 1.0, arrow.global_position, Vector3.UP)
	for index in 15:
		await physics_frame
	_check(arrow.is_destroyed(), "Arrow participates in inherited damage/destruction lifecycle")
	_check(arrow.collision_layer == 0 and arrow.collision_mask == 0, "destroyed Arrow disables physical collision")
	_check(
		entry_target != null
		and arrow.get_entry_heat_target() == entry_target
		and not arrow.get_arrow_visual_root().visible,
		"destroyed-hull hiding applies to the attached target through the stable visual root"
	)
	var reset_transform := Transform3D(Basis(Vector3.UP, deg_to_rad(24.0)), Vector3(12, 3, -18))
	arrow.reset_for_reuse(reset_transform)
	await physics_frame
	await physics_frame
	_check(not arrow.is_destroyed() and arrow.is_boardable(), "Arrow resets as the same reusable physical ship")
	_check(arrow.global_transform.origin.is_equal_approx(reset_transform.origin), "Arrow reuse restores the requested berth position")
	_check(arrow.collision_layer == SHIP_LAYER and arrow.collision_mask == PhysicsLayers.SHIP_BODY_MASK, "Arrow reuse restores canonical collision")
	_check(arrow.get_arrow_visual_root().visible, "Arrow variant visual is restored after reuse")
	_check(arrow.get_escape_pod_count() == 2, "both visible escape pods survive the reuse lifecycle")
	_check(
		rib_batch_identity != 0
		and arrow.get_arrow_visual_root().get_node_or_null("WingRootRibBatch") == rib_batch
		and rib_batch.get_instance_id() == rib_batch_identity,
		"damage/reset lifecycle preserves the same rib batch and never duplicates it"
	)
	_check(
		entry_target_identity != 0
		and arrow.get_entry_heat_target() == entry_target
		and entry_target.get_instance_id() == entry_target_identity
		and entry_target.get_overlay().mesh == entry_mesh
		and entry_target.get_material() == entry_material
		and entry_target.get_material().shader == entry_shader
		and float(entry_target.get_material().get_shader_parameter(
			PlanetaryEntryHeatTarget.OWNED_PARAMETER
		)) == 0.0
		and _count_named(
			arrow.get_arrow_visual_root(), "PlanetaryEntryHeatTarget"
		) == 1,
		"damage/reset preserves one exact target, shared resources, exclusive material, and zero baseline"
	)


func _test_cleanup(arrow: ArrowReconShip) -> void:
	var arrow_reference: WeakRef = weakref(arrow)
	var entry_target_reference: WeakRef = weakref(arrow.get_entry_heat_target())
	var pod_reference: WeakRef = weakref(arrow.get_escape_pod(&"port"))
	var boarding_reference: WeakRef = weakref(arrow.get_node_or_null("ShipBoardingArea"))
	arrow.queue_free()
	arrow = null
	await process_frame
	await physics_frame
	await process_frame
	_check(arrow_reference.get_ref() == null, "Arrow root cleans up without retention")
	_check(entry_target_reference.get_ref() == null, "entry-heat target cleans up with the Arrow visual root")
	_check(pod_reference.get_ref() == null, "escape pod hierarchy cleans up with Arrow")
	_check(boarding_reference.get_ref() == null, "boarding component cleans up with Arrow")
	_test_root.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _count_named(search_root: Node, node_name: String) -> int:
	var count := 1 if search_root.name == node_name else 0
	for child in search_root.get_children():
		count += _count_named(child, node_name)
	return count


func _report_has_error(report: Dictionary, fragment: String) -> bool:
	for error in report.get("errors", PackedStringArray()):
		if fragment in str(error):
			return true
	return false


func _collect_meshes_named(search_root: Node, node_name: String, output: Array[MeshInstance3D]) -> void:
	if search_root is MeshInstance3D and search_root.name == node_name:
		output.append(search_root as MeshInstance3D)
	for child in search_root.get_children():
		_collect_meshes_named(child, node_name, output)


func _finish() -> void:
	Input.action_release("fire")
	if _failures.is_empty():
		print("ARROW_RECON_SHIP_TEST_OK")
		quit(0)
	else:
		print("ARROW_RECON_SHIP_TEST_FAILED: ", ", ".join(_failures))
		quit(1)
