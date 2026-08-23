extends SceneTree

## Regression for the VIP reception suite: the interpretation interior behind the
## Aft Junction's red landmark.
##
## Two things are being guarded, and the second matters more than the first.
##
## 1. The room is physically sound. Every mesh in it shares volume with another
##    drawn mesh, so nothing hovers; every collider has drawn geometry at exactly
##    its size, so nothing solid-looking is empty and nothing walkable is
##    invisible; the sunken well can be entered and left inside the production
##    capsule's no-jump step; and none of it penetrates the neighbouring module.
##
## 2. The room stays labelled. It is invented — element `new`, status
##    `modern_interpretation`, source confidence `none` — and the assertions below
##    fail if it ever starts publishing registered anchors, claims to reproduce an
##    observed interior, joins the station adjacency graph as a fifth module, or
##    drops the plinth legend that tells a player standing in it that no source
##    describes it.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WORLD_LAYER := PhysicsLayers.WORLD

## Tolerance for the "shares volume with drawn geometry" sweep. 2 mm: the two
## signs sit 0.5 mm proud of the panel they are lettered onto so their glyphs are
## in front of it rather than coplanar with it, and everything else in the module
## laps its support outright.
const SEATED_TOLERANCE := 0.002

## The production controller's no-jump step, as measured by
## `station_traversal_defect_witness_test.gd`. The well's risers must clear it.
const NO_JUMP_STEP_LIMIT := 0.32

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	root.add_child(game)
	await process_frame
	await physics_frame
	game.start_shift()
	for _settle in 6:
		await physics_frame

	var world := game.get_node_or_null(^"ShipyardWorld") as ShipyardWorld
	_check(world != null, "production world is live")
	if world == null:
		_finish()
		return
	var suite := world.get_node_or_null(^"VipReceptionSuite") as VipReceptionSuite
	_check(suite != null, "the VIP reception suite is instantiated in the production world")
	if suite == null:
		game.queue_free()
		await process_frame
		_finish()
		return

	_test_contract(suite)
	_test_banquette_joint_batch(suite)
	_test_roof_cassette_batch(suite)
	_test_evidence_label(suite)
	_test_is_not_a_fifth_station_module(world, suite)
	_test_nothing_floats(world, suite)
	_test_colliders_have_drawn_geometry(suite)
	_test_well_is_enterable_without_a_jump(suite)
	_test_does_not_penetrate_the_aft_module(world, suite)
	_test_relocated_entrance_uses_the_extended_upper_deck(world, suite)
	await _test_landmark_opens_onto_the_room(world, suite)
	await _test_lifecycle(suite)

	game.queue_free()
	await process_frame
	_finish()


func _test_contract(suite: VipReceptionSuite) -> void:
	var audit := suite.get_audit_report()
	for error in (audit.errors as PackedStringArray):
		print("VIP_SUITE_VALIDATION: ", error)
	_check(bool(audit.valid), "the suite validates clean")
	_check(int(audit.seat_count) == VipReceptionSuite.SEAT_COUNT, "the seating roster is complete")
	_check(int(audit.glazing_pane_count) >= VipReceptionSuite.GLAZING_PANE_COUNT, "the glazing roster is complete")
	_check(
		int(audit.practical_light_count) == VipReceptionSuite.PRACTICAL_LIGHT_COUNT,
		"the exact eighteen-practical suite roster lights the interior rather than relying on emission alone"
	)
	var lighting := suite.get_node_or_null(^"Structure/Lighting") as Node3D
	var sill_cove := suite.get_node_or_null(
		^"Structure/Lighting/OutboardSillCove"
	) as MeshInstance3D
	var sill_port := suite.get_node_or_null(
		^"Structure/Lighting/OutboardSillSpill01"
	) as OmniLight3D
	var sill_center := suite.get_node_or_null(
		^"Structure/Lighting/OutboardSillSpill02"
	) as OmniLight3D
	var sill_starboard := suite.get_node_or_null(
		^"Structure/Lighting/OutboardSillSpill03"
	) as OmniLight3D
	var exact_sill_paths := PackedStringArray()
	if lighting != null:
		for candidate in lighting.find_children("OutboardSillSpill*", "OmniLight3D", false, false):
			exact_sill_paths.append(str(candidate.name))
		exact_sill_paths.sort()
	_check(
		exact_sill_paths == PackedStringArray([
			"OutboardSillSpill01", "OutboardSillSpill03",
		])
		and sill_port != null
		and sill_center == null
		and sill_starboard != null
		and sill_port.position.is_equal_approx(Vector3(-5.2, 0.85, 13.7))
		and sill_starboard.position.is_equal_approx(Vector3(2.6, 0.85, 13.7))
		and is_equal_approx(sill_port.omni_range, 4.4)
		and is_equal_approx(sill_starboard.omni_range, 4.4)
		and is_equal_approx(sill_port.light_energy, 0.36)
		and is_equal_approx(sill_starboard.light_energy, 0.36)
		and sill_port.light_color.is_equal_approx(Color("ffe6c4"))
		and sill_starboard.light_color.is_equal_approx(Color("ffe6c4"))
		and is_equal_approx(sill_port.omni_attenuation, 2.1)
		and is_equal_approx(sill_starboard.omni_attenuation, 2.1)
		and sill_port.distance_fade_enabled
		and sill_starboard.distance_fade_enabled
		and is_equal_approx(sill_port.distance_fade_begin, 60.0)
		and is_equal_approx(sill_starboard.distance_fade_begin, 60.0)
		and is_equal_approx(sill_port.distance_fade_length, 25.0)
		and is_equal_approx(sill_starboard.distance_fade_length, 25.0)
		and sill_port.is_visible_in_tree()
		and sill_starboard.is_visible_in_tree()
		and not sill_port.shadow_enabled
		and not sill_starboard.shadow_enabled,
		"the outboard sill retains only its exact enabled shadowless side pair"
	)
	_check(
		sill_cove != null
		and sill_cove.mesh != null
		and sill_cove.mesh.get_aabb().size.is_equal_approx(Vector3(11.4, 0.06, 0.1))
		and sill_cove.position.is_equal_approx(Vector3(-1.3, 0.62, 13.86))
		and sill_cove.material_override is StandardMaterial3D
		and (sill_cove.material_override as StandardMaterial3D).emission_enabled,
		"the continuous 11.4 m emissive sill fixture remains geometrically and materially intact"
	)

	var clearance := suite.get_clearance_profile()
	_check(float(clearance.threshold_clear_width) >= 4.0, "the threshold is generously player-clear")
	_check(float(clearance.reception_head_clearance) > float(clearance.threshold_head_clearance), "the room opens up above the threshold it is entered from")
	_check(float(clearance.lantern_head_clearance) > float(clearance.reception_head_clearance), "the lantern lifts the ceiling again over the seating")

	_check(suite.get_room_ids().size() == 2, "the suite publishes exactly its threshold and its reception room")
	for room_id in suite.get_room_ids():
		var volume := suite.get_room_volume(room_id)
		_check(not volume.is_empty(), "room %s publishes an occupancy volume" % room_id)
		_check(str(volume.get("evidence_status", "")) == "modern_interpretation", "room %s carries the module's evidence status" % room_id)
		_check(suite.contains_room(room_id, suite.to_global(volume.local_center as Vector3)), "room %s contains its own centre" % room_id)
	_check(suite.get_room_volume(&"vip-observation-deck").is_empty(), "an unknown room has no invented fallback volume")

	var roster := suite.get_support_roster()
	_check(roster.size() >= 8, "the cantilever publishes its load path member by member")
	var every_member_named := true
	for entry in roster:
		if str(entry.get("carries", "")) == "unknown" or str(entry.get("laps", "")) == "unknown":
			every_member_named = false
	_check(every_member_named, "every published support member names what it carries and what it laps")


func _test_banquette_joint_batch(suite: VipReceptionSuite) -> void:
	var fitout := suite.get_node_or_null(^"Structure/Fitout") as Node3D
	var batch := suite.get_node_or_null(
		^"Structure/Fitout/BanquetteSegmentJoints"
	) as MultiMeshInstance3D
	_check(fitout != null and batch != null and batch.multimesh != null, "banquette joints resolve as one Fitout-level MultiMesh batch")
	if fitout == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var expected: Array[Transform3D] = []
	var seats_intact := true
	for segment_index in 7:
		var segment := fitout.get_node_or_null(
			NodePath("Banquette%02d" % (segment_index + 1))
		) as Node3D
		if segment == null:
			seats_intact = false
			continue
		seats_intact = seats_intact \
			and bool(segment.get_meta("station_seat", false)) \
			and segment.get_node_or_null(^"Base") is StaticBody3D \
			and segment.find_children("SegmentJoint", "MeshInstance3D", true, false).is_empty()
		for side in [-1.0, 1.0]:
			expected.append(
				segment.transform * Transform3D(
					Basis.IDENTITY,
					Vector3(float(side) * 0.52, -0.16, -0.02)
				)
			)
	_check(seats_intact, "all seven semantic/collision-backed banquette roots survive without duplicate joint nodes")
	_check(
		multi.instance_count == 14
		and multi.visible_instance_count == -1
		and authored.size() == 14
		and expected.size() == 14,
		"one batch retains all fourteen visible joint copies"
	)
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = authored_exact and (authored[index] as Transform3D).is_equal_approx(expected[index])
	_check(authored_exact, "authored batch roster preserves every old joint transform and ordering")
	if not RenderingServer.get_video_adapter_name().is_empty():
		var renderer_exact := multi.instance_count == expected.size()
		for index in expected.size():
			renderer_exact = renderer_exact and multi.get_instance_transform(index).is_equal_approx(expected[index])
		_check(renderer_exact, "Forward+ renderer transforms preserve every old joint transform and ordering")

	var first_base := fitout.get_node_or_null(^"Banquette01/Base/Mesh") as MeshInstance3D
	_check(
		multi.mesh.get_aabb().size.is_equal_approx(Vector3(0.05, 0.4, 0.76))
		and multi.mesh.get_surface_count() == 1
		and first_base != null
		and batch.material_override == first_base.material_override,
		"batch preserves the rounded-box extent, one surface, and lacquer material identity"
	)
	_check(
		batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"batch preserves parent-space transforms, shadow casting, and render layer"
	)

	var render := suite.get_render_batch_contract()
	_check(
		int(render.baseline_descendant_nodes) == 468
		and int(render.descendant_nodes) == 464
		and int(render.baseline_mesh_instances) == 264
		and int(render.mesh_instances) == 259
		and int(render.baseline_multimesh_batches) == 1
		and int(render.multimesh_batches) == 2,
		"the sill-light slice freezes descendants 468 -> 464, MeshInstances 264 -> 259, and batches 1 -> 2"
	)
	_check(
		int(render.baseline_drawn_copies) == 278
		and int(render.drawn_copies) == 278
		and int(render.baseline_geometry_submissions) == 265
		and int(render.geometry_submissions) == 261
		and int(render.banquette_joint_copies) == 14,
		"drawn copies remain 278 while the new family lowers submissions 265 -> 261"
	)
	_check(
		int(render.banquette_renderer_buffer_floats) == 168
		and bool(render.banquette_renderer_buffer_matches_authored)
		and bool(render.banquette_bounds_match_authored)
		and bool(render.exact_counts),
		"the existing banquette buffer remains 168 exact floats with its authored aggregate AABB"
	)

	var detached := render.authored_joint_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((suite.get_render_batch_contract().authored_joint_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"render contract returns a detached authored-transform roster"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	var mutation_errors := suite.get_validation_errors()
	_check(
		mutation_errors.has("VIP banquette-joint renderer buffer drifted from its authored roster"),
		"mutating one live renderer transform is rejected by the module audit"
	)
	multi.buffer = original_buffer
	_check(suite.get_validation_errors().is_empty(), "restoring the exact buffer restores a clean module audit")


func _test_roof_cassette_batch(suite: VipReceptionSuite) -> void:
	var exterior := suite.get_node_or_null(^"Structure/ExteriorShell") as Node3D
	var batch := suite.get_node_or_null(
		^"Structure/ExteriorShell/RoofCassettes"
	) as MultiMeshInstance3D
	_check(
		exterior != null and batch != null and batch.multimesh != null,
		"five exterior roof cassettes resolve as one ExteriorShell-level MultiMesh batch"
	)
	if exterior == null or batch == null or batch.multimesh == null:
		return
	var multi := batch.multimesh
	var authored := batch.get_meta("authored_instance_transforms", []) as Array
	var expected: Array[Transform3D] = []
	for cassette_index in VipReceptionSuite.ROOF_CASSETTE_COPY_COUNT:
		expected.append(
			Transform3D(
				Basis.IDENTITY,
				Vector3(-1.3, 5.46, 4.0 + float(cassette_index) * 2.2)
			)
		)
	_check(
		exterior.find_children("RoofCassette*", "MeshInstance3D", true, false).is_empty()
		and multi.instance_count == 5
		and multi.visible_instance_count == -1
		and authored.size() == 5,
		"the batch retains five visible copies without duplicate ordinary roof-cassette nodes"
	)
	var authored_exact := authored.size() == expected.size()
	for index in mini(authored.size(), expected.size()):
		authored_exact = (
			authored_exact
			and (authored[index] as Transform3D).is_equal_approx(expected[index])
		)
	_check(authored_exact, "the roof batch preserves all five old transforms in stable order")
	if not RenderingServer.get_video_adapter_name().is_empty():
		var renderer_exact := multi.instance_count == expected.size()
		for index in expected.size():
			renderer_exact = (
				renderer_exact
				and multi.get_instance_transform(index).is_equal_approx(expected[index])
			)
		_check(renderer_exact, "Forward+ receives the exact five authored roof transforms")

	var comparison := exterior.get_node_or_null(^"PortShellRib01") as MeshInstance3D
	_check(
		multi.mesh != null
		and multi.mesh.get_aabb().size.is_equal_approx(Vector3(11.6, 0.12, 1.7))
		and multi.mesh.get_surface_count() == 1
		and comparison != null
		and batch.material_override == comparison.material_override
		and batch.transform.is_equal_approx(Transform3D.IDENTITY)
		and batch.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and batch.layers == 1,
		"the roof batch preserves exact mesh extent, pearl material, parent space, shadows and render layer"
	)

	var semantic_paths := [
		^"Structure/Reception/WellPan",
		^"Structure/Fitout/Banquette01",
		^"Structure/Fitout/Banquette07",
		^"Structure/Fitout/Armchair01",
		^"Structure/Fitout/Armchair04",
		^"Structure/Fitout/ServeryStool01",
		^"Structure/Fitout/ServeryStool03",
		^"Structure/Fitout/ServeryBody",
		^"Structure/Fitout/HostDesk",
		^"Structure/Fitout/OutboardWindowBench",
		^"Structure/Fitout/LightColumnPort",
		^"Structure/Fitout/LightColumnStarboard",
	]
	var semantics_intact := true
	for path: NodePath in semantic_paths:
		semantics_intact = semantics_intact and suite.get_node_or_null(path) != null
	_check(
		semantics_intact,
		"WellPan and every named furniture family remain at their established semantic paths"
	)

	var render := suite.get_render_batch_contract()
	_check(
		int(render.roof_cassette_baseline_mesh_instances) == 5
		and int(render.roof_cassette_mesh_instances) == 0
		and int(render.roof_cassette_baseline_multimesh_resources) == 0
		and int(render.roof_cassette_multimesh_resources) == 1
		and int(render.roof_cassette_baseline_mesh_resources) == 1
		and int(render.roof_cassette_mesh_resources) == 1
		and int(render.roof_cassette_material_resources) == 1
		and int(render.roof_cassette_baseline_submissions) == 5
		and int(render.roof_cassette_submissions) == 1,
		"family-local resources freeze at one mesh/one material while nodes 5 -> 1 and submissions 5 -> 1"
	)
	_check(
		int(render.roof_cassette_copies) == 5
		and int(render.roof_cassette_renderer_buffer_floats) == 60
		and int(render.renderer_buffer_floats) == 228
		and bool(render.roof_cassette_renderer_buffer_matches_authored)
		and bool(render.roof_cassette_bounds_match_authored)
		and bool(render.renderer_buffer_matches_authored)
		and bool(render.bounds_match_authored),
		"the five copies add an exact 60-float buffer and authored aggregate culling AABB"
	)

	var detached := render.authored_roof_cassette_transforms as Array
	detached[0] = Transform3D.IDENTITY
	_check(
		not ((suite.get_render_batch_contract().authored_roof_cassette_transforms as Array)[0] as Transform3D).is_equal_approx(
			Transform3D.IDENTITY
		),
		"the roof transform roster is detached from retained renderer authority"
	)
	var original_buffer := multi.buffer.duplicate()
	var mutated_buffer := original_buffer.duplicate()
	mutated_buffer[3] += 0.25
	multi.buffer = mutated_buffer
	_check(
		suite.get_validation_errors().has(
			"VIP roof-cassette renderer buffer drifted from its authored roster"
		),
		"mutating one live roof transform turns the exact component audit red"
	)
	multi.buffer = original_buffer
	_check(suite.get_validation_errors().is_empty(), "restoring the roof buffer restores a clean module audit")


func _test_evidence_label(suite: VipReceptionSuite) -> void:
	var evidence := suite.get_evidence_metadata()
	_check(str(evidence.evidence_status) == "modern_interpretation", "the interior publishes modern_interpretation")
	_check(str(evidence.interpretation_label) == "new", "the interior publishes the topology document's `new` element label")
	_check(str(evidence.source_confidence) == "none", "source confidence is none, not low: no anchor describes any VIP interior")
	_check(not bool(evidence.source_bounded), "the interior does not claim to be source-bounded")
	_check(not bool(evidence.authenticated_original_geometry), "the interior claims no authenticated original geometry")
	_check(not bool(evidence.reproduces_observed_interior), "the interior claims to reproduce nothing")
	_check(
		(evidence.registered_evidence_anchors as PackedStringArray).is_empty(),
		"the interior cites no registered anchor, because there is none to cite"
	)
	_check(
		(evidence.unjoined_source_fragments as PackedStringArray).size() >= 2,
		"the two unjoined VIP fragments are recorded as context rather than as references"
	)
	_check(
		(evidence.modern_interpretations as PackedStringArray).size() >= 4
			and "the existence of any VIP interior behind the landmark" in Array(evidence.modern_interpretations),
		"the existence of the room is itself listed as the first modern interpretation"
	)
	var note := str(evidence.content_note)
	_check("No source describes the inside of any VIP room" in note, "the content note states the boundary in plain words")

	# The legend a player actually reads, at the threshold, before the view.
	var plinth_legend := suite.find_child("Sign_MODERN_INTERPRETATION", true, false) as MeshInstance3D
	var plinth_reason := suite.find_child("Sign_NO_SOURCE_DESCRIBES_THIS_ROOM", true, false) as MeshInstance3D
	_check(plinth_legend != null and plinth_reason != null, "the threshold plinth carries the interpretation legend in the room itself")


func _test_is_not_a_fifth_station_module(world: ShipyardWorld, suite: VipReceptionSuite) -> void:
	_check(not suite.is_in_group("station_modules"), "the interpretation interior is not registered as a station module")
	_check(suite.is_in_group("station_interpretation_interiors"), "the interior is discoverable as what it is")
	var report := world.get_station_route_registry_report()
	var modules := report.get("modules", {}) as Dictionary
	_check(not modules.has(VipReceptionSuite.MODULE_ID), "the suite is absent from the station module roster")
	var adjacency := report.get("adjacency", {}) as Dictionary
	var suite_has_edge := false
	for raw_edge in adjacency.get("edges", []) as Array:
		var edge := raw_edge as Dictionary
		for endpoint in edge.get("endpoints", PackedStringArray()) as PackedStringArray:
			if String(endpoint).begins_with("%s:" % VipReceptionSuite.MODULE_ID):
				suite_has_edge = true
	_check(not suite_has_edge, "the suite adds no station adjacency edge")
	var route_ids := PackedStringArray()
	if suite.has_method("get_route_ids"):
		route_ids = PackedStringArray(suite.call("get_route_ids"))
	_check(route_ids.is_empty(), "the suite declares no route markers and therefore no connection slot")


## MAP-005 and the 2026-08-16 "strange floating block" report, applied to every
## piece of this module rather than to a hand-written roster of it. Measured
## against drawn geometry, not against collision: half of the load path is
## non-collidable structure hanging under an open deck, and a ray in open space
## simply falls forever.
func _test_nothing_floats(world: ShipyardWorld, suite: VipReceptionSuite) -> void:
	var own: Array[Dictionary] = []
	for candidate in suite.find_children("*", "MeshInstance3D", true, false):
		var instance := candidate as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree():
			continue
		own.append({"node": instance, "box": (instance.global_transform * instance.mesh.get_aabb()).abs()})
	_check(own.size() > 200, "the sweep sees the whole built module")

	# The pieces that lap the Aft Junction — the collar, the keels and the back
	# stays — are seated on *its* geometry, so the neighbour is part of the sweep.
	var neighbour: Array[AABB] = []
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	if aft != null:
		for candidate in aft.find_children("*", "MeshInstance3D", true, false):
			var instance := candidate as MeshInstance3D
			if instance.mesh == null or not instance.is_visible_in_tree():
				continue
			neighbour.append((instance.global_transform * instance.mesh.get_aabb()).abs())
	_check(not neighbour.is_empty(), "the neighbouring module's geometry is available to the sweep")

	var floating := PackedStringArray()
	for entry in own:
		var instance := entry["node"] as MeshInstance3D
		var box := (entry["box"] as AABB).grow(SEATED_TOLERANCE)
		var seated := false
		for other in own:
			var other_node := other["node"] as MeshInstance3D
			if other_node == instance or instance.is_ancestor_of(other_node) or other_node.is_ancestor_of(instance):
				continue
			if box.intersects(other["box"] as AABB):
				seated = true
				break
		if not seated:
			for neighbour_box in neighbour:
				if box.intersects(neighbour_box):
					seated = true
					break
		if not seated:
			floating.append("%s at %s" % [instance.name, str(box.get_center())])
	print("VIP_SUITE_FLOATING: ", floating)
	_check(floating.is_empty(), "nothing in the VIP suite hangs in space (%d floating)" % floating.size())


func _test_colliders_have_drawn_geometry(suite: VipReceptionSuite) -> void:
	var contract := suite.get_collision_contract()
	_check(bool(contract.all_layers_match_lifecycle), "every body carries the world layer")
	_check(bool(contract.all_masks_zero), "static station structure queries nothing")
	_check(bool(contract.all_shapes_present_and_enabled), "every body has an enabled shape")

	var orphans := PackedStringArray()
	var mismatched := PackedStringArray()
	for candidate in suite.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var mesh_instance := body.get_node_or_null(^"Mesh") as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			orphans.append(str(body.name))
			continue
		var shape := body.get_node_or_null(^"Collision") as CollisionShape3D
		if shape == null or shape.shape == null:
			orphans.append(str(body.name))
			continue
		var drawn: Vector3 = mesh_instance.mesh.get_aabb().size
		var solid := Vector3.ZERO
		if shape.shape is BoxShape3D:
			solid = (shape.shape as BoxShape3D).size
		elif shape.shape is CylinderShape3D:
			var cylinder := shape.shape as CylinderShape3D
			solid = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)
		if not drawn.is_equal_approx(solid):
			mismatched.append("%s drawn=%s solid=%s" % [body.name, str(drawn), str(solid)])
	print("VIP_SUITE_ORPHAN_COLLIDERS: ", orphans)
	print("VIP_SUITE_SIZE_DRIFT: ", mismatched)
	_check(orphans.is_empty(), "every collider in the suite has drawn geometry at it")
	_check(mismatched.is_empty(), "every collider is exactly the size of the thing a player sees")


func _test_well_is_enterable_without_a_jump(suite: VipReceptionSuite) -> void:
	var clearance := suite.get_clearance_profile()
	_check(float(clearance.well_step_rise) <= NO_JUMP_STEP_LIMIT, "each well riser is inside the production no-jump step")
	_check(
		is_equal_approx(float(clearance.well_drop), float(clearance.well_step_rise) * 2.0),
		"the two published risers account for the whole published drop"
	)
	var tread := suite.find_child("WellStepEntry", true, false) as StaticBody3D
	var pan := suite.find_child("WellPan", true, false) as StaticBody3D
	_check(tread != null and pan != null, "the well has a physical entry step and a physical floor")
	if tread == null or pan == null:
		return
	var tread_top := tread.position.y + ((tread.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D).size.y * 0.5
	var pan_top := pan.position.y + ((pan.get_node(^"Collision") as CollisionShape3D).shape as BoxShape3D).size.y * 0.5
	_check(absf(tread_top - pan_top) <= NO_JUMP_STEP_LIMIT, "the step-to-well-floor riser is walkable")
	_check(absf(VipReceptionSuite.FLOOR_ELEVATION - tread_top) <= NO_JUMP_STEP_LIMIT, "the floor-to-step riser is walkable")


func _test_does_not_penetrate_the_aft_module(world: ShipyardWorld, suite: VipReceptionSuite) -> void:
	var aft := world.get_node_or_null(^"AftJunctionStack") as AftJunctionStack
	if aft == null:
		return
	var offenders := PackedStringArray()
	for candidate in suite.find_children("*", "StaticBody3D", true, false):
		var body := candidate as StaticBody3D
		var body_box := _body_world_box(body)
		if not body_box.has_volume():
			continue
		for neighbour_candidate in aft.find_children("*", "StaticBody3D", true, false):
			var neighbour_body := neighbour_candidate as StaticBody3D
			var neighbour_box := _body_world_box(neighbour_body)
			if not neighbour_box.has_volume():
				continue
			if body_box.grow(-0.02).intersects(neighbour_box.grow(-0.02)):
				offenders.append("%s <-> AftJunctionStack/%s" % [body.name, neighbour_body.name])
	print("VIP_SUITE_NEIGHBOUR_PENETRATION: ", offenders)
	_check(offenders.is_empty(), "the suite's solid shell does not penetrate the module it hangs off")


## The reception is deliberately set back from the upper deck to restore the
## route around the landmark. The widened public deck must meet the relocated
## threshold directly: a narrow add-on here reads as furniture, not circulation.
func _test_relocated_entrance_uses_the_extended_upper_deck(world: ShipyardWorld, suite: VipReceptionSuite) -> void:
	var upper_floor := world.get_node_or_null(
		^"AftJunctionStack/Structure/UpperOpenDeck/UpperFloor"
	) as StaticBody3D
	var threshold_floor := suite.get_node_or_null(^"Structure/Threshold/ThresholdFloor") as StaticBody3D
	_check(
		upper_floor != null and threshold_floor != null,
		"the set-back VIP entrance retains its widened deck and threshold floors"
	)
	if upper_floor == null or threshold_floor == null:
		return
	var deck_bounds := _body_world_box(upper_floor)
	var threshold_bounds := _body_world_box(threshold_floor)
	_check(
		is_equal_approx(deck_bounds.end.z, threshold_bounds.position.z),
		"the widened upper deck reaches the relocated reception threshold without a gap"
	)
	_check(
		is_equal_approx(deck_bounds.end.y, threshold_bounds.end.y),
		"the widened deck preserves its walkable elevation into VIP reception"
	)


func _test_landmark_opens_onto_the_room(world: ShipyardWorld, suite: VipReceptionSuite) -> void:
	var door := world.get_node_or_null(^"AftJunctionStack/VIPAccess") as StationDoor
	_check(door != null, "the red landmark door is live")
	if door == null:
		return
	_check(not door.locked and not door.deferred_access, "the landmark is openable")
	_check(door.is_portal_blocked(), "the landmark is physically closed until someone opens it")
	_check(door.interact(suite), "the landmark accepts a real interaction")
	var opened := false
	for _frame in 90:
		await physics_frame
		if door.is_open() and not door.is_portal_blocked():
			opened = true
			break
	_check(opened, "the landmark clears its portal inside its panel-travel budget")

	var space := suite.get_world_3d().direct_space_state
	var threshold := suite.to_global(Vector3(0.0, 1.2, 1.5))
	var deck := suite.to_global(Vector3(0.0, 1.2, -2.4))
	var through := space.intersect_ray(PhysicsRayQueryParameters3D.create(deck, threshold, WORLD_LAYER))
	_check(through.is_empty(), "an open landmark leaves a genuinely clear physical route into the threshold")
	var under := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(threshold, threshold - Vector3.UP * 3.0, WORLD_LAYER)
	)
	_check(not under.is_empty(), "there is collision-backed floor immediately inside the doorway")
	var reception_floor := suite.to_global(Vector3(-1.3, 1.2, 4.6))
	var reception_under := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(reception_floor, reception_floor - Vector3.UP * 3.0, WORLD_LAYER)
	)
	_check(not reception_under.is_empty(), "the reception floor is collision-backed where a player first stands in it")


func _test_lifecycle(suite: VipReceptionSuite) -> void:
	suite.set_module_enabled(false)
	var disabled := suite.get_lifecycle_contract()
	_check(bool(disabled.visible_matches_enabled) and bool(disabled.collision_matches_enabled), "disabling clears visibility and collision together")
	suite.set_module_enabled(true)
	var enabled := suite.get_lifecycle_contract()
	_check(bool(enabled.reversible), "the lifecycle is reversible")
	_check(bool(enabled.visible_matches_enabled) and bool(enabled.collision_matches_enabled), "re-enabling restores the room exactly")
	_check(suite.is_module_enabled(), "the flag and the node state agree")

	var parent := suite.get_parent()
	var detached_before := _lifecycle_snapshot(suite)
	parent.remove_child(suite)
	suite.set_module_enabled(false)
	_check(
		not suite.is_inside_tree()
			and _lifecycle_snapshot(suite) == detached_before,
		"detached direct VIP lifecycle mutation preserves visible and collision state atomically"
	)
	parent.add_child(suite)
	await process_frame
	suite.set_module_enabled(false)
	var live_disabled := suite.get_lifecycle_contract()
	suite.set_module_enabled(true)
	_check(
		suite.is_inside_tree()
			and bool(live_disabled.visible_matches_enabled)
			and bool(live_disabled.collision_matches_enabled)
			and _lifecycle_snapshot(suite) == detached_before,
		"readded VIP suite accepts fresh live disable and restore without rebuilding"
	)

	var queued_before := _lifecycle_snapshot(suite)
	suite.queue_free()
	suite.set_module_enabled(false)
	_check(
		suite.is_inside_tree()
			and suite.is_queued_for_deletion()
			and _lifecycle_snapshot(suite) == queued_before,
		"queued direct VIP lifecycle mutation preserves visible and collision state atomically"
	)


func _lifecycle_snapshot(suite: VipReceptionSuite) -> Dictionary:
	var body_layers: Array[Dictionary] = []
	for raw_body in suite.find_children("*", "StaticBody3D", true, false):
		var body := raw_body as StaticBody3D
		body_layers.append({
			"path": suite.get_path_to(body),
			"collision_layer": body.collision_layer,
			"collision_mask": body.collision_mask,
			"visible": body.visible,
		})
	return {
		"enabled": suite.is_module_enabled(),
		"visible": suite.visible,
		"lifecycle": suite.get_lifecycle_contract(),
		"body_layers": body_layers,
	}.duplicate(true)


func _body_world_box(body: StaticBody3D) -> AABB:
	var box := AABB()
	var first := true
	for candidate in body.find_children("*", "CollisionShape3D", true, false):
		var shape := candidate as CollisionShape3D
		if shape.shape == null:
			continue
		var size: Vector3 = shape.shape.get_debug_mesh().get_aabb().size
		var piece := AABB(shape.global_position - size * 0.5, size)
		if first:
			box = piece
			first = false
		else:
			box = box.merge(piece)
	return box


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)
		print("FAIL: ", message)


func _finish() -> void:
	print("VIP_RECEPTION_SUITE_TEST_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("VIP_RECEPTION_SUITE_TEST_OK")
		quit(0)
	else:
		print("VIP_RECEPTION_SUITE_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
