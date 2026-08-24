extends SceneTree

const OwnerScript := preload(
	"res://scripts/world/ember_surface_loop_production_binding.gd"
)
const HostScript := preload("res://scripts/world/ember_surface_loop_host.gd")
const EmberScene := preload("res://scenes/world/planets/ember_moon.tscn")
const PlayerScene := preload("res://scenes/player/player.tscn")
const PhysicsLayersScript := preload("res://scripts/core/physics_layers.gd")

const RELAY_PATH := ^"LandingRegion/SurfaceLandmarks/StagingRelay"
const ACCESS_PATH := \
	^"LandingRegion/SurfaceLandmarks/RouteMarkers/StagingRelayAccess"

class FakeSurfaceComposition:
	extends Node
	var detach_calls := 0
	var reenter_calls := 0
	var reject_reenter := false
	func detach() -> Dictionary:
		detach_calls += 1
		return {"accepted": true, "reason": &"composition_detached"}
	func reenter() -> Dictionary:
		reenter_calls += 1
		if reject_reenter:
			return {"accepted": false, "reason": &"composition_reentry_rejected"}
		return {"accepted": true, "reason": &"composition_reentered"}
	func get_snapshot() -> Dictionary:
		return {"state": &"bound", "authority": {"reward": false}}
	func get_session_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"surface": {"state": &"ready"},
			"authority": {"save": false, "reward": false},
		}.duplicate(true)

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var runtime_parent := Node3D.new()
	runtime_parent.name = "LoadedEmberRuntime"
	# Production rebases the 120 km body-local landing datum near local origin.
	runtime_parent.position = Vector3(0.0, -120000.0, 0.0)
	root.add_child(runtime_parent)
	var authored := EmberScene.instantiate() as Node3D
	runtime_parent.add_child(authored)
	var actor := PlayerScene.instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	var host := HostScript.new()
	root.add_child(host)
	host.set("_generation", 54)
	host.set("_attachment_generation", 1)
	host.set("_attached", true)
	host.set("_phase", HostScript.Phase.ON_FOOT)
	host.set("_player_instance_id", actor.get_instance_id())
	host.set("_loaded_scene_instance_id", authored.get_instance_id())
	await process_frame

	var relay_before := _relay_snapshot(authored)
	var overlay_root := Node3D.new()
	overlay_root.name = "EmberProductionOverlay"
	root.add_child(overlay_root)
	var owner := OwnerScript.new()
	root.add_child(owner)
	owner.set("_configured", true)
	owner.set("_generation", 9)
	owner.set("_state", OwnerScript.State.RUNNING)
	owner.set("_host", host)
	owner.set("_player", actor)
	owner.set("_player_instance_id", actor.get_instance_id())
	owner.set("_loaded_scene_instance_id", authored.get_instance_id())
	owner.set("_composition_root", overlay_root)
	var attached := owner.call(
		&"_attach_staging_relay_proximity", authored
	) as Dictionary
	var access := authored.get_node(ACCESS_PATH) as Marker3D
	var diagnostic := overlay_root.get_node(
		"OwnedStagingRelayProximityDiagnostic"
	) as Area3D
	var ready := diagnostic.call(&"get_snapshot") as Dictionary
	_check(
		bool(attached.accepted) and diagnostic.get_parent() == overlay_root
			and diagnostic.global_transform == access.global_transform
			and bool(ready.active) and not bool(ready.completed)
			and int(ready.physical.area_collision_layer) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and int(ready.physical.area_collision_mask) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and not diagnostic.has_meta("station_interactable")
			and bool((authored.audit() as Dictionary).valid),
		"production attaches a non-solid Player-only diagnostic beside the authored scene"
	)

	actor.global_position = diagnostic.global_position
	diagnostic.body_entered.emit(actor)
	await physics_frame
	await physics_frame
	var completed := diagnostic.call(&"get_snapshot") as Dictionary
	var relay_after := _relay_snapshot(authored)
	_check(
		bool(completed.completed)
			and completed.physical.marker_text \
				== "STAGING RELAY\nCHECK RECORDED"
			and int(completed.physical.area_collision_mask) \
				== PhysicsLayersScript.PLAYER_BODY_LAYER
			and relay_after == relay_before
			and bool((authored.audit() as Dictionary).valid)
			and not bool(completed.authority.hud)
			and not bool(completed.authority.game_flow)
			and not bool(completed.authority.activity)
			and not bool(completed.authority.route)
			and not bool(completed.authority.reward),
		"the production Player proximity signal changes only Label3D and runtime receipt"
	)

	var surface := FakeSurfaceComposition.new()
	owner.add_child(surface)
	owner.set("_planetary_composition", surface)
	var session_before := owner.get_planetary_surface_session_snapshot()
	var detached: Dictionary = owner.detach_planetary_surface()
	var detached_snapshot := diagnostic.call(&"get_snapshot") as Dictionary
	host.set("_attachment_generation", 2)
	surface.reject_reenter = true
	var rejected_reentry: Dictionary = owner.reenter_planetary_surface()
	var rejected_snapshot := diagnostic.call(&"get_snapshot") as Dictionary
	surface.reject_reenter = false
	var reentered: Dictionary = owner.reenter_planetary_surface()
	var retained := diagnostic.call(&"get_snapshot") as Dictionary
	var session_after := owner.get_planetary_surface_session_snapshot()
	_check(
		bool(detached.accepted) and not bool(detached_snapshot.active)
			and not bool(detached_snapshot.physical.marker_visible)
			and not bool(rejected_reentry.accepted)
			and rejected_reentry.reason == &"composition_reentry_rejected"
			and not bool(rejected_snapshot.attached)
			and not bool(rejected_snapshot.physical.marker_visible)
			and bool(reentered.accepted) and bool(retained.active)
			and bool(retained.completed)
			and int(retained.attachment_generation) == 2
			and surface.detach_calls == 1 and surface.reenter_calls == 2
			and session_after == session_before
			and not session_after.has("staging_relay_proximity")
			and not diagnostic.has_method(&"get_persistence_snapshot")
			and relay_after == _relay_snapshot(authored),
		"failed re-entry rolls back both layers before one fenced retry retains completion"
	)

	owner.call(&"_retire_staging_relay_proximity")
	await process_frame
	var fresh_owner := OwnerScript.new()
	root.add_child(fresh_owner)
	fresh_owner.set("_configured", true)
	fresh_owner.set("_generation", 10)
	fresh_owner.set("_state", OwnerScript.State.RUNNING)
	fresh_owner.set("_host", host)
	fresh_owner.set("_player", actor)
	fresh_owner.set("_player_instance_id", actor.get_instance_id())
	fresh_owner.set("_loaded_scene_instance_id", authored.get_instance_id())
	fresh_owner.set("_composition_root", overlay_root)
	var fresh_attached := fresh_owner.call(
		&"_attach_staging_relay_proximity", authored
	) as Dictionary
	var fresh_diagnostic := overlay_root.get_node(
		"OwnedStagingRelayProximityDiagnostic"
	) as Area3D
	var fresh := fresh_diagnostic.call(&"get_snapshot") as Dictionary
	_check(
		bool(fresh_attached.accepted) and bool(fresh.active)
			and not bool(fresh.completed)
			and int(fresh.production_generation) == 10
			and fresh.physical.marker_text \
				== "STAGING RELAY\nLOCAL DIAGNOSTIC"
			and relay_before == _relay_snapshot(authored)
			and bool((authored.audit() as Dictionary).valid),
		"a fresh production generation resets while authored relay geometry stays exact"
	)

	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_STAGING_RELAY_PROXIMITY_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _relay_snapshot(scene: Node3D) -> Dictionary:
	var relay := scene.get_node(RELAY_PATH) as StaticBody3D
	var children := {}
	for node_name in [
		"BaseVisual", "BaseCollision", "MastVisual", "MastCollision",
		"HeadVisual", "HeadCollision",
	]:
		var child := relay.get_node(NodePath(node_name)) as Node3D
		children[node_name] = {
			"transform": child.transform,
			"resource": child.mesh if child is MeshInstance3D \
				else (child as CollisionShape3D).shape,
			"disabled": (child as CollisionShape3D).disabled \
				if child is CollisionShape3D else false,
		}
	return {
		"transform": relay.transform,
		"collision_layer": relay.collision_layer,
		"collision_mask": relay.collision_mask,
		"children": children,
	}.duplicate(true)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
