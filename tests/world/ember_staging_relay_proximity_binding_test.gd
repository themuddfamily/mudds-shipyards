extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_staging_relay_proximity_binding.gd"
)
const PhysicsLayersScript := preload("res://scripts/core/physics_layers.gd")

class FakeHost:
	var generation := 41
	var attachment_generation := 3
	var attached := true
	var phase_id: StringName = &"on_foot"
	var player_instance_id := 0
	var loaded_scene_instance_id := 777
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_snapshot() -> Dictionary:
		return {
			"attached": attached,
			"phase_id": phase_id,
			"identities": {
				"player_instance_id": player_instance_id,
				"loaded_scene_instance_id": loaded_scene_instance_id,
			},
		}

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var actor := Node3D.new()
	root.add_child(actor)
	var foreign_actor := Node3D.new()
	root.add_child(foreign_actor)
	var host := FakeHost.new()
	host.player_instance_id = actor.get_instance_id()
	var binding := BindingScript.new() as Area3D
	root.add_child(binding)
	await process_frame
	var configured: Dictionary = binding.call(
		&"configure", host, actor, 41, 7, 777
	)
	var ready := binding.call(&"get_snapshot") as Dictionary
	var marker := binding.get_node(^"StagingRelayDiagnosticMarker") as Label3D
	_check(
		bool(configured.accepted) and bool(ready.active)
			and not bool(ready.completed)
			and int(ready.physical.area_collision_layer) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and int(ready.physical.area_collision_mask) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and bool(ready.physical.monitoring)
			and not bool(ready.physical.monitorable)
			and ready.physical.shape == &"sphere"
			and is_equal_approx(float(ready.physical.radius_m), 0.85)
			and ready.physical.center_local_m == Vector3(0.0, 0.9, 0.0)
			and not bool(ready.physical.solid_geometry_added)
			and ready.physical.marker_text \
				== "STAGING RELAY\nLOCAL DIAGNOSTIC"
			and marker.position == Vector3(0.0, 4.15, 0.0),
		"current on-foot generation exposes only the Player proximity diagnostic"
	)

	var stale: Dictionary = binding.call(
		&"submit_proximity", actor, 41, 2, 7
	)
	binding.body_entered.emit(foreign_actor)
	var after_foreign := binding.call(&"get_snapshot") as Dictionary
	binding.body_entered.emit(actor)
	await process_frame
	var completed := binding.call(&"get_snapshot") as Dictionary
	var duplicate: Dictionary = binding.call(
		&"submit_proximity", actor, 41, 3, 7
	)
	var receipt := completed.last_receipt as Dictionary
	_check(
		not bool(stale.accepted) and not bool(after_foreign.completed)
			and bool(completed.completed) and not bool(duplicate.accepted)
			and completed.physical.marker_text \
				== "STAGING RELAY\nCHECK RECORDED"
			and int(completed.physical.area_collision_mask) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and bool(completed.physical.monitoring)
			and receipt.interaction_id \
				== &"ember_staging_relay_local_diagnostic"
			and receipt.landmark_id == &"ember_staging_relay"
			and receipt.access_marker_id == &"ember_staging_relay_access"
			and int(receipt.host_generation) == 41
			and int(receipt.attachment_generation) == 3
			and int(receipt.production_generation) == 7
			and not bool(receipt.historical_claim)
			and not bool(receipt.activity_started)
			and not bool(receipt.route_advanced)
			and not bool(receipt.reward_granted),
		"only the exact player and three live generations record one local receipt"
	)

	host.phase_id = &"landed"
	binding.call(&"refresh_authoritative_state")
	var landed := binding.call(&"get_snapshot") as Dictionary
	host.phase_id = &"on_foot"
	var detached: Dictionary = binding.call(&"detach")
	var hidden := binding.call(&"get_snapshot") as Dictionary
	host.attachment_generation = 4
	var reentered: Dictionary = binding.call(&"reenter", 4)
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		not bool(landed.active) and not bool(landed.physical.marker_visible)
			and bool(detached.accepted) and not bool(hidden.active)
			and bool(reentered.accepted) and bool(retained.active)
			and bool(retained.completed)
			and bool(retained.physical.marker_visible)
			and not binding.has_method(&"get_persistence_snapshot")
			and not binding.has_method(&"restore_persistence_snapshot"),
		"phase and attachment fencing hide the marker while re-entry retains runtime state"
	)

	var fresh := BindingScript.new() as Area3D
	root.add_child(fresh)
	await process_frame
	var fresh_configured: Dictionary = fresh.call(
		&"configure", host, actor, 41, 8, 777
	)
	var fresh_snapshot := fresh.call(&"get_snapshot") as Dictionary
	_check(
		bool(fresh_configured.accepted) and bool(fresh_snapshot.active)
			and not bool(fresh_snapshot.completed)
			and int(fresh_snapshot.production_generation) == 8
			and fresh_snapshot.physical.marker_text \
				== "STAGING RELAY\nLOCAL DIAGNOSTIC"
			and not bool(fresh_snapshot.authority.hud)
			and not bool(fresh_snapshot.authority.game_flow)
			and not bool(fresh_snapshot.authority.activity)
			and not bool(fresh_snapshot.authority.route)
			and not bool(fresh_snapshot.authority.reward)
			and not bool(fresh_snapshot.authority.history)
			and not bool(fresh_snapshot.authority.save)
			and not bool(fresh_snapshot.authority.network)
			and not bool(fresh_snapshot.authority.movement)
			and not bool(fresh_snapshot.authority.solid_geometry),
		"a fresh production generation resets without acquiring adjacent authority"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_STAGING_RELAY_PROXIMITY_BINDING_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
