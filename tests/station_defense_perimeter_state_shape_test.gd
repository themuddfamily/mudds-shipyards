extends SceneTree

## Production-state guard for the perimeter asset. Intact, under-attack, and
## physically failed forms remain legible without colour, while renewal uses
## the real Damageable lifecycle and returns exactly to intact.

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
	var presentation := asset.get_node(^"Presentation") as Node3D
	var ring_id := ring.get_instance_id()
	var core_id := core.get_instance_id()
	var ring_mesh_id := ring.mesh.get_instance_id()
	var core_mesh_id := core.mesh.get_instance_id()
	var child_count := presentation.get_child_count()
	var handle := asset.get_asset_handle()
	var damageable := asset.get_damageable_component()

	var intact := asset.get_protected_asset_presentation_snapshot()
	_check(
		intact.effective_state_id == &"idle"
			and intact.silhouette_id == &"full_ring_intact"
			and intact.ring_visible and intact.core_visible
			and (intact.ring_scale_vector as Vector3).is_equal_approx(Vector3.ONE)
			and (intact.core_scale_vector as Vector3).is_equal_approx(Vector3.ONE),
		"intact perimeter retains its full ring and core silhouette"
	)

	_apply_activity_state(asset, &"active", 1, 3, true, 0.0)
	var under_attack := asset.get_protected_asset_presentation_snapshot()
	_check(
		under_attack.effective_state_id == &"active"
			and under_attack.silhouette_id == &"broad_shield_attack"
			and (under_attack.ring_scale_vector as Vector3).x > 1.3
			and (under_attack.ring_scale_vector as Vector3).y < 0.8
			and (under_attack.core_scale_vector as Vector3).y > 1.3,
		"under attack broadens the retained shield and raises a tall core without colour"
	)

	var destruction := damageable.apply_damage(
		damageable.get_maximum_health(), asset.global_position, Vector3.UP,
		{"source": &"state_shape_test"}
	)
	var failed_authority := asset.get_snapshot()
	var failed_sync := asset.apply_authority_presentation_snapshot(failed_authority)
	var failed := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(destruction.get("accepted", false))
			and bool(destruction.get("destroyed", false))
			and bool(failed_sync.get("accepted", false))
			and bool(failed_authority.destroyed)
			and is_zero_approx(float(failed_authority.health))
			and int(failed_authority.asset_handle.generation) == int(handle.generation)
			and failed.effective_state_id == &"destroyed"
			and failed.silhouette_id == &"mast_only_failed"
			and not failed.ring_visible and not failed.core_visible and not failed.light_visible,
		"real Damageable destruction reduces the current generation to the mast-only silhouette"
	)

	var before_impossible := failed.duplicate(true)
	var impossible := asset.apply_activity_presentation_snapshot({
		"state_id": &"active",
		"current_wave_index": 1,
		"wave_count": 3,
		"wave_active": false,
		"wave_delay_remaining_seconds": 0.0,
	})
	_check(
		not bool(impossible.get("accepted", true))
			and impossible.get("reason", &"") == &"invalid_activity_presentation_snapshot"
			and asset.get_protected_asset_presentation_snapshot() == before_impossible,
		"active/wave-inactive/delay-zero detached state is impossible and leaves presentation exact"
	)

	var renewed := asset.renew(int(handle.get("generation", -1)))
	var renewed_handle := asset.get_asset_handle()
	var renewed_presentation := asset.get_protected_asset_presentation_snapshot()
	_check(
		bool(renewed.get("accepted", false))
			and int(renewed_handle.generation) == int(handle.generation) + 1
			and is_equal_approx(damageable.get_health(), damageable.get_maximum_health())
			and not damageable.is_destroyed()
			and renewed_presentation == intact,
		"renewing the physically failed asset increments generation and restores presentation exactly to intact"
	)
	_check(
		intact.silhouette_id != under_attack.silhouette_id
			and under_attack.silhouette_id != failed.silhouette_id
			and renewed_presentation.silhouette_id == intact.silhouette_id
			and ring.get_instance_id() == ring_id and core.get_instance_id() == core_id
			and ring.mesh.get_instance_id() == ring_mesh_id and core.mesh.get_instance_id() == core_mesh_id
			and presentation.get_child_count() == child_count,
		"intact, attack, and failed are distinct; renewal reuses intact fixed identities"
	)
	asset.queue_free()
	await process_frame
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("STATION_DEFENSE_PERIMETER_STATE_SHAPE_TEST_OK: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _apply_activity_state(
	asset: StationDefensePerimeterAsset, state_id: StringName, wave_index: int, wave_count: int,
	wave_active: bool, delay: float
) -> void:
	var result := asset.apply_activity_presentation_snapshot({
		"state_id": state_id,
		"current_wave_index": wave_index,
		"wave_count": wave_count,
		"wave_active": wave_active,
		"wave_delay_remaining_seconds": delay,
	})
	_check(bool(result.get("accepted", false)), "activity presentation snapshot applies")


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
