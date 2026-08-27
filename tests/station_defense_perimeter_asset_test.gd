extends SceneTree

const ASSET_SCENE := preload("res://scenes/activities/station_defense_perimeter_asset.tscn")

var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var asset := ASSET_SCENE.instantiate() as StationDefensePerimeterAsset
	root.add_child(asset)
	await process_frame

	var ring := asset.get_node(^"Presentation/SignalRing") as MeshInstance3D
	var core := asset.get_node(^"Presentation/Core") as MeshInstance3D
	var collision := asset.get_node(^"CollisionShape3D") as CollisionShape3D
	var ring_id := ring.get_instance_id()
	var ring_mesh_id := ring.mesh.get_instance_id()
	var collision_id := collision.get_instance_id()
	var collision_shape_id := collision.shape.get_instance_id()
	var initial_child_count := asset.get_node(^"Presentation").get_child_count()
	var initial_collision_layer := asset.collision_layer
	var initial_collision_mask := asset.collision_mask
	var handle := asset.get_asset_handle()
	var pristine_presentation := asset.get_protected_asset_presentation_snapshot()
	var starboard_snapshot := {
		"asset_handle": handle,
		"activity_generation": int(handle.generation),
		"active": true,
		"bearing_world": Vector3.RIGHT,
	}
	var toward_starboard := asset.apply_hostile_bearing_presentation_snapshot(starboard_snapshot)
	var starboard := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(toward_starboard.accepted)
		and bool(starboard.hostile_bearing_active)
		and is_equal_approx(float(starboard.ring_yaw), PI * 0.5)
		and ring.basis.y.normalized().is_equal_approx(Vector3.RIGHT)
		and (starboard.core_position as Vector3).is_equal_approx(Vector3(0.85, 2.65, 0.0)),
		"the existing vertical shield ring and core steadily face the supplied hostile approach"
	)

	var renewal_signal_handle: Dictionary = {}
	var renewal_signal_presentation: Dictionary = {}
	asset.asset_renewed.connect(func(renewed_handle: Dictionary) -> void:
		renewal_signal_handle.assign(renewed_handle)
		renewal_signal_presentation.assign(asset.get_protected_asset_presentation_snapshot())
	)
	var damageable := asset.get_damageable_component()
	var destruction := damageable.apply_damage(
		damageable.get_maximum_health(), asset.global_position, Vector3.UP,
		{"source": &"asset_test"}
	)
	var destroyed_snapshot := asset.get_snapshot()
	var destroyed_presentation_result := asset.apply_authority_presentation_snapshot(
		destroyed_snapshot
	)
	var destroyed_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(destruction.get("accepted", false))
		and bool(destruction.get("destroyed", false))
		and bool(destroyed_snapshot.destroyed)
		and is_zero_approx(float(destroyed_snapshot.health))
		and int(destroyed_snapshot.asset_handle.generation) == 1
		and bool(destroyed_presentation_result.get("accepted", false))
		and destroyed_presentation.effective_state_id == &"destroyed"
		and destroyed_presentation.silhouette_id == &"mast_only_failed"
		and asset.collision_layer == PhysicsLayers.NONE,
		"production Damageable destruction commits the current generation's failed form"
	)
	var renewed := asset.renew(int(handle.generation))
	_check(
		bool(renewed.accepted)
		and int(renewal_signal_handle.generation) == 2
		and int(asset.get_asset_handle().generation) == int(handle.generation) + 1
		and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
		and not damageable.is_destroyed()
		and asset.collision_layer == initial_collision_layer
		and renewal_signal_presentation == pristine_presentation,
		"renewal observers see generation two only after real failure resets exactly to intact"
	)

	var before_stale_renewed := asset.get_protected_asset_presentation_snapshot()
	_check(
		asset.apply_hostile_bearing_presentation_snapshot(starboard_snapshot).reason \
			== &"stale_hostile_bearing_snapshot"
		and asset.get_protected_asset_presentation_snapshot() == before_stale_renewed,
		"the prior generation cannot restore its shield face after renewal"
	)

	var generation_two_handle := asset.get_asset_handle()
	var port_snapshot := {
		"asset_handle": generation_two_handle,
		"activity_generation": int(generation_two_handle.generation),
		"active": true,
		"bearing_world": Vector3.LEFT,
	}
	var toward_port := asset.apply_hostile_bearing_presentation_snapshot(port_snapshot)
	var port := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(toward_port.accepted)
		and is_equal_approx(float(port.ring_yaw), -PI * 0.5)
		and (port.core_position as Vector3).is_equal_approx(Vector3(-0.85, 2.65, 0.0)),
		"the renewed generation can intentionally select its own approach face"
	)

	var restored := asset.restore_pristine_generation(3)
	var restored_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(restored.accepted)
		and int(asset.get_asset_handle().generation) == 3
		and _is_neutral_bearing(restored_presentation),
		"pristine generation restore also clears the prior generation bearing synchronously"
	)

	var before_stale_restored := asset.get_protected_asset_presentation_snapshot()
	_check(
		asset.apply_hostile_bearing_presentation_snapshot(port_snapshot).reason \
			== &"stale_hostile_bearing_snapshot"
		and asset.get_protected_asset_presentation_snapshot() == before_stale_restored,
		"the pre-restore generation cannot redirect the restored protected asset"
	)

	root.remove_child(asset)
	_check(
		ring.get_instance_id() == ring_id
		and ring.mesh.get_instance_id() == ring_mesh_id
		and collision.get_instance_id() == collision_id
		and collision.shape.get_instance_id() == collision_shape_id
		and _is_neutral_bearing(asset.get_protected_asset_presentation_snapshot()),
		"detaching preserves fixed presentation identities and the intentional neutral state"
	)
	root.add_child(asset)
	await process_frame
	var restored_handle := asset.get_asset_handle()
	var after_readd := asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": restored_handle,
		"activity_generation": int(restored_handle.generation),
		"active": true,
		"bearing_world": Vector3.FORWARD,
	})
	var readded_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(after_readd.accepted)
		and ring.get_instance_id() == ring_id
		and ring.mesh.get_instance_id() == ring_mesh_id
		and collision.get_instance_id() == collision_id
		and collision.shape.get_instance_id() == collision_shape_id
		and is_equal_approx(absf(float(readded_presentation.ring_yaw)), PI)
		and (readded_presentation.core_position as Vector3).is_equal_approx(
			Vector3(0.0, 2.65, -0.85)
		),
		"re-added geometry keeps identity and accepts only an intentional current-generation bearing"
	)
	asset.apply_hostile_bearing_presentation_snapshot({
		"asset_handle": restored_handle,
		"activity_generation": int(restored_handle.generation),
		"active": false,
		"bearing_world": Vector3.ZERO,
	})
	var neutral := asset.get_protected_asset_presentation_snapshot()
	_check(
		_is_neutral_bearing(neutral, 3),
		"clearing the current bearing returns the protected-asset beacon to neutral"
	)

	var budget := neutral.budget as Dictionary
	_check(
		ring.get_instance_id() == ring_id
		and ring.mesh.get_instance_id() == ring_mesh_id
		and collision.get_instance_id() == collision_id
		and collision.shape.get_instance_id() == collision_shape_id
		and asset.get_node(^"Presentation").get_child_count() == initial_child_count
		and asset.collision_layer == initial_collision_layer
		and asset.collision_mask == initial_collision_mask
		and int(budget.presentation_nodes) == 4
		and int(budget.mesh_instances) == 2
		and int(budget.lights) == 1
		and int(budget.process_callbacks) == 0
		and not bool(budget.runtime_node_allocation)
		and not bool(budget.runtime_resource_allocation),
		"the approach face reuses fixed presentation geometry without touching collision or authority"
	)

	asset.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("STATION_DEFENSE_PERIMETER_ASSET_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _is_neutral_bearing(presentation: Dictionary, expected_source_generation := -1) -> bool:
	var source := presentation.hostile_bearing_source as Dictionary
	var source_is_current := (
		expected_source_generation >= 0
		and int(source.get("activity_generation", -1)) == expected_source_generation
		and source.get("asset_handle") is Dictionary
		and int((source.asset_handle as Dictionary).get("generation", -1)) \
			== expected_source_generation
		and not bool(source.get("active", true))
	)
	return (
		not bool(presentation.hostile_bearing_active)
		and (presentation.hostile_bearing_local as Vector3).is_zero_approx()
		and (source.is_empty() or source_is_current)
		and (presentation.core_position as Vector3).is_equal_approx(Vector3(0.0, 2.65, 0.0))
		and is_zero_approx(float(presentation.ring_yaw))
	)
