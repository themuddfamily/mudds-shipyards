extends SceneTree

const CLUSTER_SCENE := preload("res://scenes/world/components/nearby_sector_cluster.tscn")
const LOCATION_ID: StringName = &"cinder_reach"
const GENERATION := 7
const TICK := 1.0 / 60.0
const EXPECTED_AUTHORED_RENDERER_COUNT := 218
const EXPECTED_BOUND_RENDERER_COUNT := 222
const EXPECTED_INTEGRATED_BATCH_FINGERPRINT := (
	"ExtractionPlatform/CinderReachPlatform/ExtractionArmPort/ArmCollar"
	+ "|cinder-extraction-arm-collars|3|-1;"
	+ "ExtractionPlatform/CinderReachPlatform/ExtractionArmStarboard/ArmCollar"
	+ "|cinder-extraction-arm-collars|3|-1;"
	+ "ExtractionPlatform/CinderReachPlatform/StreamingApertureLensBatch"
	+ "|cinder-streaming-aperture-lenses|8|-1;"
	+ "ExtractionPlatform/CinderReachPlatform/StreamingScorchedBayBatch"
	+ "|cinder-streaming-scorched-bays|4|4;"
	+ "StreamingBeaconMastBatch|cinder-streaming-beacon-masts|4|4;"
	+ "StreamingBeaconTrimRingBatch|cinder-streaming-beacon-trim-rings|4|4"
)
const EXPECTED_ARM_COLLAR_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(0.0, -6.0, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, -17.0, 0.0)),
	Transform3D(Basis.IDENTITY, Vector3(0.0, -28.0, 0.0)),
]
const EXPECTED_SCORCHED_BAY_TRANSFORMS: Array[Transform3D] = [
	Transform3D(Basis.IDENTITY, Vector3(-4.62, 0.0, -18.0)),
	Transform3D(Basis.IDENTITY, Vector3(4.62, 0.0, -18.0)),
	Transform3D(Basis.IDENTITY, Vector3(-4.62, 0.0, 6.0)),
	Transform3D(Basis.IDENTITY, Vector3(4.62, 0.0, 6.0)),
]

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	await _test_standalone_is_authored_and_inert()
	await _test_bind_currentness()
	await _test_streamed_fade_lifecycle_and_baselines()
	await _test_invalid_stale_and_detached_reports()
	_finish()


func _test_standalone_is_authored_and_inert() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(cluster)
	await process_frame
	var snapshot := cluster.get_streaming_transition_snapshot()
	_check(
		not bool(snapshot.get("bound", true))
		and snapshot.get("phase") == &"standalone"
		and is_equal_approx(float(snapshot.get("opacity", -1.0)), 1.0)
		and cluster.visible,
		"direct component fixtures retain the fully authored presentation"
	)
	var rejected := cluster.advance_streaming_transition(TICK, 499.9, GENERATION)
	_check(
		not bool(rejected.get("accepted", true))
		and rejected.get("reason") == &"not_streamed"
		and cluster.visible,
		"a standalone cluster cannot be armed by advancement"
	)
	var authored_renderer := cluster.get_node(
		^"ExtractionPlatform/CinderReachPlatform/CoreDrum/Mesh"
	) as GeometryInstance3D
	var authored_light := cluster.find_children("*", "Light3D", true, false)[0] as Light3D
	authored_renderer.transparency = 0.25
	authored_renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	authored_light.light_energy = 3.25
	cluster.set_meta(&"world_location_id", LOCATION_ID)
	cluster.set_meta(&"world_location_generation", GENERATION)
	var component := CinderStreamingTransitionPresentation.new()
	var bound := component.bind_streamed_content(cluster, GENERATION)
	component.advance_physics(0.25, 499.9, GENERATION)
	_check(
		bool(bound.get("accepted", false))
		and is_equal_approx(authored_renderer.transparency, 0.625)
		and authored_renderer.cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		and is_equal_approx(authored_light.light_energy, 1.625),
		"partial opacity composes with nonzero authored transparency and light energy"
	)
	component.advance_physics(0.25, 499.9, GENERATION)
	_check(
		is_equal_approx(authored_renderer.transparency, 0.25)
		and authored_renderer.cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
		and is_equal_approx(authored_light.light_energy, 3.25),
		"opacity one restores exact authored transparency, shadow, and energy baselines"
	)
	cluster.queue_free()
	await process_frame


func _test_bind_currentness() -> void:
	var detached := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	detached.set_meta(&"world_location_id", LOCATION_ID)
	detached.set_meta(&"world_location_generation", GENERATION)
	var detached_component := CinderStreamingTransitionPresentation.new()
	var detached_component_before := detached_component.get_snapshot()
	var detached_root_before := _presentation_state(detached)
	var detached_result := detached_component.bind_streamed_content(detached, GENERATION)
	_check(
		not bool(detached_result.get("accepted", true))
		and detached_result.get("reason") == &"content_root_detached"
		and detached_component.get_snapshot() == detached_component_before
		and _presentation_state(detached) == detached_root_before,
		"detached bind rejects before component ownership or renderer presentation mutation"
	)
	detached.queue_free()

	var queued := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(queued)
	await process_frame
	queued.set_meta(&"world_location_id", LOCATION_ID)
	queued.set_meta(&"world_location_generation", GENERATION)
	var queued_component := CinderStreamingTransitionPresentation.new()
	var queued_component_before := queued_component.get_snapshot()
	var queued_root_before := _presentation_state(queued)
	queued.queue_free()
	var queued_result := queued_component.bind_streamed_content(queued, GENERATION)
	_check(
		queued.is_inside_tree()
		and queued.is_queued_for_deletion()
		and not bool(queued_result.get("accepted", true))
		and queued_result.get("reason") == &"content_root_detached"
		and queued_component.get_snapshot() == queued_component_before
		and _presentation_state(queued) == queued_root_before,
		"queued bind rejects before component ownership or renderer presentation mutation"
	)
	await process_frame

	var live := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	root.add_child(live)
	await process_frame
	live.set_meta(&"world_location_id", LOCATION_ID)
	live.set_meta(&"world_location_generation", GENERATION)
	var live_component := CinderStreamingTransitionPresentation.new()
	var live_result := live_component.bind_streamed_content(live, GENERATION)
	_check(
		bool(live_result.get("accepted", false))
		and live_result.get("reason") == &"bound_hidden"
		and bool(live_component.get_snapshot().get("bound", false))
		and not live.visible,
		"a fresh live root still binds into the hidden fade-in presentation state"
	)
	live.queue_free()
	await process_frame


func _test_streamed_fade_lifecycle_and_baselines() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	cluster.set_meta(&"world_location_id", LOCATION_ID)
	cluster.set_meta(&"world_location_generation", GENERATION)
	root.add_child(cluster)
	await process_frame
	var hidden := cluster.get_streaming_transition_snapshot()
	var renderers := cluster.find_children("*", "GeometryInstance3D", true, false)
	var lights := cluster.find_children("*", "Light3D", true, false)
	var collisions := cluster.find_children("*", "CollisionShape3D", true, false)
	var resource_ids := _visual_resource_ids(renderers)
	var collision_contract := _collision_contract(collisions)
	_check(
		bool(hidden.get("bound", false))
		and int(hidden.get("generation", -1)) == GENERATION
		and hidden.get("phase") == &"fading_in"
		and is_zero_approx(float(hidden.get("opacity", -1.0)))
		and not cluster.visible
		and int(hidden.get("authored_renderer_count", -1)) \
			== EXPECTED_AUTHORED_RENDERER_COUNT
		and int(hidden.get("renderer_count", -1)) \
			== EXPECTED_BOUND_RENDERER_COUNT
		and renderers.size() == EXPECTED_BOUND_RENDERER_COUNT
		and lights.size() == 27,
		"a streamed generation commits fully hidden before its first draw"
	)
	_check(
		_integrated_batch_roster_contract(cluster, hidden),
		"the bound renderer roster has the exact extraction-collar, aperture-lens, scorched-bay, beacon-mast, and beacon-trim batch fingerprint"
	)
	_check(
		_aperture_lens_batch_contract(cluster),
		"eight semantic aperture lenses retain exact transforms and renderer settings behind one bounded MultiMesh"
	)
	_check(
		_scorched_bay_batch_contract(cluster),
		"four immutable scorched-bay surfaces retain exact transforms and renderer settings behind one bounded MultiMesh submission"
	)
	var peer := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	peer.set_meta(&"world_location_id", LOCATION_ID)
	peer.set_meta(&"world_location_generation", GENERATION + 1)
	root.add_child(peer)
	await process_frame
	var batch := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/StreamingScorchedBayBatch"
	) as MultiMeshInstance3D
	var peer_batch := peer.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/StreamingScorchedBayBatch"
	) as MultiMeshInstance3D
	_check(
		_scorched_bay_batch_contract(peer)
		and batch != null and peer_batch != null
		and batch.material_override != null
		and peer_batch.material_override != null
		and batch.material_override != peer_batch.material_override,
		"concurrent streamed generations retain isolated scorched-bay materials"
	)
	peer.queue_free()
	await process_frame
	_check(
		_beacon_trim_ring_batch_contract(cluster),
		"four static beacon trim rings retain exact transforms and renderer settings behind one bounded MultiMesh"
	)
	_check(
		_beacon_mast_batch_contract(cluster),
		"four static beacon masts retain exact transforms and renderer settings behind one bounded MultiMesh submission"
	)
	_check(
		_all_renderer_transparency(renderers, 1.0)
		and _all_lights_zero(lights)
		and _collision_contract(collisions) == collision_contract,
		"opacity zero changes presentation only and leaves collision untouched"
	)

	for _tick_index in 15:
		cluster.advance_streaming_transition(TICK, 499.9, GENERATION)
	var halfway := cluster.get_streaming_transition_snapshot()
	_check(
		is_equal_approx(float(halfway.get("opacity", -1.0)), 0.5)
		and halfway.get("phase") == &"fading_in"
		and cluster.visible,
		"fifteen 60 Hz caller ticks produce the deterministic half-opacity sample"
	)
	for _tick_index in 15:
		cluster.advance_streaming_transition(TICK, 500.0, GENERATION)
	var authored := cluster.get_streaming_transition_snapshot()
	_check(
		is_equal_approx(float(authored.get("opacity", -1.0)), 1.0)
		and authored.get("phase") == &"authored"
		and cluster.visible
		and _visual_resource_ids(renderers) == resource_ids
		and _collision_contract(collisions) == collision_contract,
		"thirty 60 Hz caller ticks restore authored presentation without resource or collision churn"
	)
	_check(
		bool(cluster.get_streaming_transition_audit().get("valid", false)),
		"the exact authored renderer, shadow, light, and visibility baselines audit green"
	)
	var debris := cluster.get_node_or_null(^"DebrisField/DebrisChips") \
		as MultiMeshInstance3D
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.LOW)
	var low_hidden := debris != null and not debris.visible
	cluster.set_detail_quality(NearbySectorCluster.DetailQuality.HIGH)
	_check(
		low_hidden and debris != null and debris.visible
		and is_equal_approx(float(
			cluster.get_streaming_transition_snapshot().get("opacity", -1.0)
		), 1.0),
		"LOW and HIGH authored child visibility remains independent of transition opacity"
	)

	var at_boundary := cluster.advance_streaming_transition(0.25, 650.0, GENERATION)
	_check(
		is_equal_approx(float(at_boundary.get("opacity", -1.0)), 1.0)
		and at_boundary.get("phase") == &"authored"
		and not bool(at_boundary.get("retire_ready", true)),
		"the presentation remains fully authored through the exact 650 metre boundary"
	)
	var fading_out := cluster.advance_streaming_transition(0.25, 650.1, GENERATION)
	_check(
		is_equal_approx(float(fading_out.get("opacity", -1.0)), 0.5)
		and fading_out.get("phase") == &"fading_out"
		and not bool(fading_out.get("retire_ready", true)),
		"the first outside phase fades without granting streaming authority"
	)
	var fading_out_opacity := float(fading_out.get("opacity", -1.0))
	root.remove_child(cluster)
	await process_frame
	var detached_before := cluster.get_streaming_transition_snapshot()
	var detached_advance := cluster.advance_streaming_transition(
		0.25, 650.1, GENERATION
	)
	var detached_after := cluster.get_streaming_transition_snapshot()
	root.add_child(cluster)
	await process_frame
	var fading_out_reentry := cluster.get_streaming_transition_snapshot()
	_check(
		not bool(detached_advance.get("accepted", true))
		and detached_advance.get("reason") == &"content_root_detached"
		and detached_after == detached_before
		and fading_out_reentry.get("phase") == &"fading_out"
		and is_equal_approx(
			float(fading_out_reentry.get("opacity", -2.0)), fading_out_opacity
		)
		and int(fading_out_reentry.get("generation", -1)) == GENERATION,
		"detached fade calls reject and re-entry retains phase, opacity, and generation"
	)
	var reversed := cluster.advance_streaming_transition(0.25, 650.0, GENERATION)
	_check(
		is_equal_approx(float(reversed.get("opacity", -1.0)), 0.75)
		and reversed.get("phase") == &"fading_in",
		"returning inside the boundary reverses continuously without unload thrash"
	)
	cluster.advance_streaming_transition(0.5, 650.0, GENERATION)
	var complete_fade := cluster.advance_streaming_transition(0.5, 650.1, GENERATION)
	_check(
		complete_fade.get("phase") == &"fade_out_complete"
		and is_zero_approx(float(complete_fade.get("opacity", -1.0)))
		and not bool(complete_fade.get("retire_ready", true))
		and not cluster.visible,
		"fade-out reaches exact hidden state while the generation remains owned"
	)
	root.remove_child(cluster)
	await process_frame
	root.add_child(cluster)
	await process_frame
	var hidden_reentry := cluster.get_streaming_transition_snapshot()
	_check(
		hidden_reentry.get("phase") == &"fade_out_complete"
		and is_zero_approx(float(hidden_reentry.get("opacity", -1.0)))
		and int(hidden_reentry.get("generation", -1)) == GENERATION
		and not cluster.visible,
		"detach and re-entry at fade-out completion retain hidden ownership"
	)
	var retire := cluster.advance_streaming_transition(TICK, 650.1, GENERATION)
	_check(
		bool(retire.get("retire_ready", false))
		and is_zero_approx(float(retire.get("opacity", -1.0))),
		"only a subsequent still-outside caller tick authorizes retirement"
	)

	cluster.queue_free()
	await process_frame


func _test_invalid_stale_and_detached_reports() -> void:
	var cluster := CLUSTER_SCENE.instantiate() as NearbySectorCluster
	cluster.set_meta(&"world_location_id", LOCATION_ID)
	cluster.set_meta(&"world_location_generation", GENERATION)
	root.add_child(cluster)
	await process_frame
	var before := cluster.get_streaming_transition_snapshot()
	var rejected := [
		cluster.advance_streaming_transition(NAN, 499.9, GENERATION),
		cluster.advance_streaming_transition(TICK, INF, GENERATION),
		cluster.advance_streaming_transition(TICK, 499.9, GENERATION + 1),
	]
	var after := cluster.get_streaming_transition_snapshot()
	_check(
		not bool((rejected[0] as Dictionary).get("accepted", true))
		and (rejected[0] as Dictionary).get("reason") == &"invalid_delta"
		and (rejected[1] as Dictionary).get("reason") == &"invalid_distance"
		and (rejected[2] as Dictionary).get("reason") == &"stale_generation"
		and int(after.get("advance_count", -1)) == int(before.get("advance_count", -2))
		and is_equal_approx(float(after.get("opacity", -1.0)), float(before.get("opacity", -2.0))),
		"invalid and stale calls reject atomically without presentation drift"
	)
	var mutable_snapshot := cluster.get_streaming_transition_snapshot()
	mutable_snapshot["opacity"] = 0.83
	var mutable_audit := cluster.get_streaming_transition_audit()
	mutable_audit["errors"] = PackedStringArray(["forged"])
	mutable_audit["snapshot"] = {}
	var authority_component := CinderStreamingTransitionPresentation.new()
	var authority := cluster.get_streaming_transition_audit()
	_check(
		is_zero_approx(float(cluster.get_streaming_transition_snapshot().get("opacity", -1.0)))
		and (cluster.get_streaming_transition_audit().get("errors", PackedStringArray()) as PackedStringArray).is_empty()
		and not authority_component.has_method(&"_process")
		and not authority_component.has_method(&"_physics_process")
		and not bool(authority.get("automatic_processing", true))
		and not bool(authority.get("streaming_authority", true))
		and not bool(authority.get("gameplay_authority", true)),
		"snapshot and audit are detached and the component owns no private physics loop"
	)

	# The hard retention cap makes a teleport hidden in one tick, but still
	# requires a later outside confirmation before generic policy retirement.
	var teleported := cluster.advance_streaming_transition(TICK, 725.0, GENERATION)
	var confirmed := cluster.advance_streaming_transition(0.0, 725.0, GENERATION)
	_check(
		is_zero_approx(float(teleported.get("opacity", -1.0)))
		and not bool(teleported.get("retire_ready", true))
		and bool(confirmed.get("retire_ready", false)),
		"teleport retention is capped at 725 metres and one confirmation tick"
	)
	cluster.queue_free()
	await process_frame


func _visual_resource_ids(renderers: Array[Node]) -> PackedInt64Array:
	var ids := PackedInt64Array()
	for node in renderers:
		var renderer := node as GeometryInstance3D
		if renderer is MeshInstance3D:
			var mesh := (renderer as MeshInstance3D).mesh
			ids.append(mesh.get_instance_id() if mesh != null else 0)
		elif renderer is MultiMeshInstance3D:
			var multimesh := (renderer as MultiMeshInstance3D).multimesh
			ids.append(multimesh.get_instance_id() if multimesh != null else 0)
		else:
			ids.append(0)
	return ids


func _integrated_batch_roster_contract(
	cluster: NearbySectorCluster, snapshot: Dictionary
	) -> bool:
	if snapshot.get("integrated_batch_fingerprint", "") \
			!= EXPECTED_INTEGRATED_BATCH_FINGERPRINT:
		return false
	var paths: Array[NodePath] = [
		^"ExtractionPlatform/CinderReachPlatform/ExtractionArmPort/ArmCollar",
		^"ExtractionPlatform/CinderReachPlatform/ExtractionArmStarboard/ArmCollar",
		^"ExtractionPlatform/CinderReachPlatform/StreamingApertureLensBatch",
		^"ExtractionPlatform/CinderReachPlatform/StreamingScorchedBayBatch",
		^"StreamingBeaconMastBatch",
		^"StreamingBeaconTrimRingBatch",
	]
	var rows := PackedStringArray()
	var integrated_family_count := 0
	for candidate in cluster.find_children("*", "MultiMeshInstance3D", true, false):
		var family := StringName(candidate.get_meta(&"visual_batch_family_id", &""))
		if family in [
			&"cinder-extraction-arm-collars",
			&"cinder-streaming-aperture-lenses",
			&"cinder-streaming-scorched-bays",
			&"cinder-streaming-beacon-masts",
			&"cinder-streaming-beacon-trim-rings",
		]:
			integrated_family_count += 1
	for index in paths.size():
		var batch := cluster.get_node_or_null(paths[index]) as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			return false
		rows.append("%s|%s|%d|%d" % [
			str(paths[index]),
			str(batch.get_meta(&"visual_batch_family_id", &"")),
			batch.multimesh.instance_count,
			batch.multimesh.visible_instance_count,
		])
		if index < 2:
			var transforms := batch.get_meta(
				&"authored_instance_transforms", []
			) as Array
			if transforms != EXPECTED_ARM_COLLAR_TRANSFORMS \
					or not bool(batch.get_meta(&"visual_detail_only", false)) \
					or not batch.find_children(
						"*", "CollisionObject3D", true, false
					).is_empty() \
					or not batch.find_children(
						"*", "CollisionShape3D", true, false
					).is_empty():
				return false
	return integrated_family_count == 6 \
		and ";".join(rows) == EXPECTED_INTEGRATED_BATCH_FINGERPRINT


func _aperture_lens_batch_contract(cluster: NearbySectorCluster) -> bool:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var batch := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/StreamingApertureLensBatch"
	) as MultiMeshInstance3D
	if platform == null or batch == null or batch.multimesh == null:
		return false
	var multi := batch.multimesh
	var transforms := batch.get_meta(
		&"authored_instance_transforms", []
	) as Array
	var source_paths := batch.get_meta(&"semantic_source_paths", []) as Array
	if multi.instance_count != 8 \
		or multi.transform_format != MultiMesh.TRANSFORM_3D \
		or multi.custom_aabb.size.length_squared() <= 0.0 \
		or transforms.size() != 8 \
		or source_paths.size() != 8 \
		or batch.get_meta(&"visual_batch_family_id", &"") \
			!= &"cinder-streaming-aperture-lenses":
		return false
	var exemplar: MeshInstance3D
	var platform_inverse := platform.global_transform.affine_inverse()
	for index in source_paths.size():
		var source := cluster.get_node_or_null(source_paths[index]) as MeshInstance3D
		if source == null or source.visible or source.mesh == null \
			or not (transforms[index] as Transform3D).is_equal_approx(
				platform_inverse * source.global_transform
			):
			return false
		if exemplar == null:
			exemplar = source
	if exemplar == null:
		return false
	return multi.mesh == exemplar.mesh \
		and batch.material_override == exemplar.material_override \
		and batch.material_overlay == exemplar.material_overlay \
		and batch.cast_shadow == exemplar.cast_shadow \
		and batch.layers == exemplar.layers \
		and batch.visibility_range_begin == exemplar.visibility_range_begin \
		and batch.visibility_range_end == exemplar.visibility_range_end \
		and batch.visibility_range_begin_margin == exemplar.visibility_range_begin_margin \
		and batch.visibility_range_end_margin == exemplar.visibility_range_end_margin \
		and batch.visibility_range_fade_mode == exemplar.visibility_range_fade_mode \
		and batch.extra_cull_margin == exemplar.extra_cull_margin \
		and batch.ignore_occlusion_culling == exemplar.ignore_occlusion_culling \
		and batch.gi_mode == exemplar.gi_mode \
		and batch.lod_bias == exemplar.lod_bias


func _scorched_bay_batch_contract(cluster: NearbySectorCluster) -> bool:
	var platform := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform"
	) as Node3D
	var batch := cluster.get_node_or_null(
		^"ExtractionPlatform/CinderReachPlatform/StreamingScorchedBayBatch"
	) as MultiMeshInstance3D
	if platform == null or batch == null or batch.multimesh == null:
		return false
	var multi := batch.multimesh
	var transforms := batch.get_meta(
		&"authored_instance_transforms", []
	) as Array
	var source_paths := batch.get_meta(&"semantic_source_paths", []) as Array
	if multi.instance_count != 4 \
			or multi.visible_instance_count != 4 \
			or multi.transform_format != MultiMesh.TRANSFORM_3D \
			or multi.custom_aabb.size.length_squared() <= 0.0 \
			or transforms != EXPECTED_SCORCHED_BAY_TRANSFORMS \
			or source_paths.size() != 4 \
			or batch.get_meta(&"visual_batch_family_id", &"") \
				!= &"cinder-streaming-scorched-bays":
		return false
	var sources: Array[MeshInstance3D] = []
	for index in source_paths.size():
		var source := cluster.get_node_or_null(
			source_paths[index]
		) as MeshInstance3D
		if source == null or source.visible or source.mesh == null \
				or not source.get_children().is_empty() \
				or not source.transform.is_equal_approx(transforms[index]):
			return false
		sources.append(source)
	var exemplar := sources[0]
	return multi.mesh == exemplar.mesh \
		and batch.material_override == exemplar.material_override \
		and batch.material_overlay == exemplar.material_overlay \
		and batch.cast_shadow == exemplar.cast_shadow \
		and batch.layers == exemplar.layers \
		and batch.visibility_range_begin == exemplar.visibility_range_begin \
		and batch.visibility_range_end == exemplar.visibility_range_end \
		and batch.visibility_range_begin_margin == exemplar.visibility_range_begin_margin \
		and batch.visibility_range_end_margin == exemplar.visibility_range_end_margin \
		and batch.visibility_range_fade_mode == exemplar.visibility_range_fade_mode \
		and batch.extra_cull_margin == exemplar.extra_cull_margin \
		and batch.ignore_occlusion_culling == exemplar.ignore_occlusion_culling \
		and batch.gi_mode == exemplar.gi_mode \
		and batch.lod_bias == exemplar.lod_bias \
		and batch.find_children("*", "CollisionObject3D", true, false).is_empty() \
		and batch.find_children("*", "CollisionShape3D", true, false).is_empty()


func _beacon_trim_ring_batch_contract(cluster: NearbySectorCluster) -> bool:
	var batch := cluster.get_node_or_null(
		^"StreamingBeaconTrimRingBatch"
	) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return false
	var multi := batch.multimesh
	var transforms := batch.get_meta(
		&"authored_instance_transforms", []
	) as Array
	var source_paths := batch.get_meta(&"semantic_source_paths", []) as Array
	if multi.instance_count != 4 \
		or multi.visible_instance_count != 4 \
		or multi.transform_format != MultiMesh.TRANSFORM_3D \
		or multi.custom_aabb.size.length_squared() <= 0.0 \
		or transforms.size() != 4 \
		or source_paths.size() != 4 \
		or batch.get_meta(&"visual_batch_family_id", &"") \
			!= &"cinder-streaming-beacon-trim-rings":
		return false
	var exemplar: MeshInstance3D
	var root_inverse := cluster.global_transform.affine_inverse()
	for index in source_paths.size():
		var source := cluster.get_node_or_null(source_paths[index]) as MeshInstance3D
		if source == null or source.visible or source.mesh == null \
			or not (transforms[index] as Transform3D).is_equal_approx(
				root_inverse * source.global_transform
			):
			return false
		if exemplar == null:
			exemplar = source
	if exemplar == null:
		return false
	return multi.mesh == exemplar.mesh \
		and batch.material_override == exemplar.material_override \
		and batch.material_overlay == exemplar.material_overlay \
		and batch.cast_shadow == exemplar.cast_shadow \
		and batch.layers == exemplar.layers \
		and batch.visibility_range_begin == exemplar.visibility_range_begin \
		and batch.visibility_range_end == exemplar.visibility_range_end \
		and batch.visibility_range_begin_margin == exemplar.visibility_range_begin_margin \
		and batch.visibility_range_end_margin == exemplar.visibility_range_end_margin \
		and batch.visibility_range_fade_mode == exemplar.visibility_range_fade_mode \
		and batch.extra_cull_margin == exemplar.extra_cull_margin \
		and batch.ignore_occlusion_culling == exemplar.ignore_occlusion_culling \
		and batch.gi_mode == exemplar.gi_mode \
		and batch.lod_bias == exemplar.lod_bias


func _beacon_mast_batch_contract(cluster: NearbySectorCluster) -> bool:
	var batch := cluster.get_node_or_null(
		^"StreamingBeaconMastBatch"
	) as MultiMeshInstance3D
	if batch == null or batch.multimesh == null:
		return false
	var multi := batch.multimesh
	var transforms := batch.get_meta(
		&"authored_instance_transforms", []
	) as Array
	var source_paths := batch.get_meta(&"semantic_source_paths", []) as Array
	if multi.instance_count != 4 \
		or multi.visible_instance_count != 4 \
		or multi.transform_format != MultiMesh.TRANSFORM_3D \
		or multi.custom_aabb.size.length_squared() <= 0.0 \
		or transforms.size() != 4 \
		or source_paths.size() != 4 \
		or batch.get_meta(&"visual_batch_family_id", &"") \
			!= &"cinder-streaming-beacon-masts":
		return false
	var exemplar: MeshInstance3D
	var root_inverse := cluster.global_transform.affine_inverse()
	for index in source_paths.size():
		var source := cluster.get_node_or_null(source_paths[index]) as MeshInstance3D
		if source == null or source.visible or source.mesh == null \
			or not source.get_children().is_empty() \
			or not (transforms[index] as Transform3D).is_equal_approx(
				root_inverse * source.global_transform
			):
			return false
		if exemplar == null:
			exemplar = source
	if exemplar == null:
		return false
	return multi.mesh == exemplar.mesh \
		and batch.material_override == exemplar.material_override \
		and batch.material_overlay == exemplar.material_overlay \
		and batch.cast_shadow == exemplar.cast_shadow \
		and batch.layers == exemplar.layers \
		and batch.visibility_range_begin == exemplar.visibility_range_begin \
		and batch.visibility_range_end == exemplar.visibility_range_end \
		and batch.visibility_range_begin_margin == exemplar.visibility_range_begin_margin \
		and batch.visibility_range_end_margin == exemplar.visibility_range_end_margin \
		and batch.visibility_range_fade_mode == exemplar.visibility_range_fade_mode \
		and batch.extra_cull_margin == exemplar.extra_cull_margin \
		and batch.ignore_occlusion_culling == exemplar.ignore_occlusion_culling \
		and batch.gi_mode == exemplar.gi_mode \
		and batch.lod_bias == exemplar.lod_bias


func _presentation_state(cluster: NearbySectorCluster) -> Dictionary:
	var renderers := cluster.find_children("*", "GeometryInstance3D", true, false)
	var lights := cluster.find_children("*", "Light3D", true, false)
	var transparencies := PackedFloat32Array()
	var shadows := PackedInt32Array()
	var energies := PackedFloat32Array()
	for renderer_node in renderers:
		var renderer := renderer_node as GeometryInstance3D
		transparencies.append(renderer.transparency)
		shadows.append(renderer.cast_shadow)
	for light_node in lights:
		energies.append((light_node as Light3D).light_energy)
	return {
		"visible": cluster.visible,
		"transparencies": transparencies,
		"shadows": shadows,
		"energies": energies,
	}.duplicate(true)


func _collision_contract(collisions: Array[Node]) -> Array[String]:
	var rows: Array[String] = []
	for node in collisions:
		var shape := node as CollisionShape3D
		var body := shape.get_parent() as CollisionObject3D
		rows.append("%s|%d|%d|%s" % [
			str(cluster_path(shape)),
			body.collision_layer if body != null else -1,
			body.collision_mask if body != null else -1,
			str(shape.disabled),
		])
	return rows


func cluster_path(node: Node) -> NodePath:
	return node.get_path()


func _all_renderer_transparency(renderers: Array[Node], expected: float) -> bool:
	for node in renderers:
		if not is_equal_approx((node as GeometryInstance3D).transparency, expected):
			return false
	return true


func _all_lights_zero(lights: Array[Node]) -> bool:
	for node in lights:
		if not is_zero_approx((node as Light3D).light_energy):
			return false
	return true


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	print("CINDER_STREAMING_TRANSITION_PRESENTATION_ASSERTIONS: ", _assertions)
	if _failures.is_empty():
		print("CINDER_STREAMING_TRANSITION_PRESENTATION_TEST_OK")
		quit(0)
	else:
		print("CINDER_STREAMING_TRANSITION_PRESENTATION_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
