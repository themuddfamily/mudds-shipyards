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
	_test_visual_performance_batch(arrow)
	_test_escape_pods_and_sensors(arrow)
	_test_collision_boarding_and_cameras(arrow)
	await _test_engine_weapon_and_lifecycle(arrow)
	await _test_cleanup(arrow)
	_finish()


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
			"nodes": 176,
			"mesh_instance_nodes": 157,
			"multi_mesh_instance_nodes": 1,
			"geometry_submissions": 158,
			"visible_geometry_copies": 159,
			"unique_mesh_resource_allocations": 141,
			"auto_fallback_names": 23,
		},
		"whole Arrow visual freezes the exact 177->176 node, 159->158 submission, 142->141 unique-mesh allocation census while retaining all 159 copies"
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
	_check(
		int(arrow.get_arrow_visual_performance_report().current.nodes) == 176,
		"caller mutation cannot alter the detached visual performance evidence"
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
	await physics_frame
	_check(arrow.is_destroyed(), "Arrow participates in inherited damage/destruction lifecycle")
	_check(arrow.collision_layer == 0 and arrow.collision_mask == 0, "destroyed Arrow disables physical collision")
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


func _test_cleanup(arrow: ArrowReconShip) -> void:
	var arrow_reference: WeakRef = weakref(arrow)
	var pod_reference: WeakRef = weakref(arrow.get_escape_pod(&"port"))
	var boarding_reference: WeakRef = weakref(arrow.get_node_or_null("ShipBoardingArea"))
	arrow.queue_free()
	arrow = null
	await process_frame
	await physics_frame
	await process_frame
	_check(arrow_reference.get_ref() == null, "Arrow root cleans up without retention")
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
