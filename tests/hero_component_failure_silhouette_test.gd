extends SceneTree

const ShipComponentDamageType := preload("res://scripts/combat/ship_component_damage.gd")

const CRAFT_COMPONENTS := {
	"TorrentInterceptor": ShipComponentDamageType.COMPONENT_FORWARD_HULL,
	"ArrowReconShip": ShipComponentDamageType.COMPONENT_PORT_WING,
	"JovianLightFreighter": ShipComponentDamageType.COMPONENT_STARBOARD_WING,
	"ZenithInterceptor": ShipComponentDamageType.COMPONENT_CORE_SYSTEMS,
	"HalyardCrewTransport": ShipComponentDamageType.COMPONENT_ENGINE_BAY,
}

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "production Main instantiates for localized component-failure silhouettes")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame

	var profile_signatures: Dictionary = {}
	for craft_name: String in CRAFT_COMPONENTS:
		var craft := game.get_node(craft_name) as HeroShip
		var component_id: StringName = CRAFT_COMPONENTS[craft_name]
		craft.set_physics_process(false)
		craft.set("_landed", false)
		var model := craft.get_component_damage()
		var local_position := _component_local_position(craft, component_id)
		var damage := model.record_damage(craft.maximum_hull * 2.0, local_position)
		craft.call("_sync_component_damage", 0.01)
		var presentation := craft.get_damage_presentation()
		var snapshot := presentation.get_component_failure_silhouette_snapshot(component_id)
		var shards := snapshot.get("shards", []) as Array
		var rig := presentation.get_node_or_null(
			"ComponentDamage_%s" % String(component_id)
		) as Node3D
		var mesh_ids: Dictionary = {}
		var triangle_count := 0
		var collision_descendants := 0
		for shard_record: Dictionary in shards:
			mesh_ids[int(shard_record.get("mesh_instance_id", 0))] = true
			var shard := rig.get_node_or_null(str(shard_record.get("name", ""))) as MeshInstance3D
			if shard != null and shard.mesh != null:
				triangle_count += shard.mesh.get_faces().size() / 3
		if rig != null:
			collision_descendants = rig.find_children(
				"*", "CollisionObject3D", true, false
			).size() + rig.find_children("*", "CollisionShape3D", true, false).size()
		_check(
			bool(damage.get("accepted", false))
			and model.get_component_state(component_id)
			== ShipComponentDamageType.ComponentState.FAILED
			and rig != null
			and rig.position.is_equal_approx(local_position)
			and int(snapshot.get("visible_shard_count", 0)) == 2,
			"%s shows two static fracture shards at its real %s anchor" % [
				craft_name, String(component_id)
			]
		)
		_check(
			shards.size() == 2
			and mesh_ids.size() == 1
			and triangle_count == 24
			and collision_descendants == 0
			and not bool(snapshot.get("authority", true)),
			"%s silhouette stays within two shared-mesh nodes, 24 triangles, and zero collision" % craft_name
		)
		profile_signatures[_profile_signature(shards)] = true

	_check(
		profile_signatures.size() == CRAFT_COMPONENTS.size(),
		"forward, port, starboard, core, and engine failures have five non-color geometry patterns"
	)
	var budget := (
		(game.get_node("TorrentInterceptor") as HeroShip)
		.get_damage_presentation()
		.get_component_failure_silhouette_budget()
	)
	_check(
		int(budget.get("nodes_per_failed_component", 0)) == 2
		and int(budget.get("mesh_resources_per_presentation", 0)) == 1
		and int(budget.get("triangles_per_failed_component", 0)) == 24
		and int(budget.get("maximum_silhouette_nodes", 0)) == 16
		and int(budget.get("maximum_silhouette_triangles", 0)) == 192
		and int(budget.get("collision_shapes", -1)) == 0
		and int(budget.get("physics_bodies", -1)) == 0
		and not bool(budget.get("gameplay_authority", true)),
		"the presentation publishes its strict eight-section worst-case resource budget"
	)

	var torrent := game.get_node("TorrentInterceptor") as HeroShip
	var torrent_presentation := torrent.get_damage_presentation()
	var torrent_component: StringName = CRAFT_COMPONENTS["TorrentInterceptor"]
	var before_reentry := torrent_presentation.get_component_failure_silhouette_snapshot(
		torrent_component
	)
	var before_shards := before_reentry.get("shards", []) as Array
	var before_node_ids: Array[int] = []
	var torrent_rig := torrent_presentation.get_node(
		"ComponentDamage_%s" % String(torrent_component)
	) as Node3D
	for shard_record: Dictionary in before_shards:
		before_node_ids.append(
			torrent_rig.get_node(str(shard_record.get("name", ""))).get_instance_id()
		)
	root.remove_child(game)
	await process_frame
	root.add_child(game)
	await process_frame
	var after_reentry := torrent_presentation.get_component_failure_silhouette_snapshot(
		torrent_component
	)
	var after_node_ids: Array[int] = []
	torrent_rig = torrent_presentation.get_node(
		"ComponentDamage_%s" % String(torrent_component)
	) as Node3D
	for shard_record: Dictionary in after_reentry.get("shards", []) as Array:
		after_node_ids.append(
			torrent_rig.get_node(str(shard_record.get("name", ""))).get_instance_id()
		)
	_check(
		before_node_ids == after_node_ids
		and int(after_reentry.get("visible_shard_count", 0)) == 2
		and torrent_rig.find_children("ComponentFailureShard*", "MeshInstance3D", true, false).size() == 2,
		"whole-Main detach/re-entry restores the same failed silhouette without duplication"
	)

	var repair := torrent.get_component_damage().tick_component_repair(
		torrent_component, 1.0, true
	)
	torrent.call("_sync_component_damage", 0.01)
	var repaired_snapshot := torrent_presentation.get_component_failure_silhouette_snapshot(
		torrent_component
	)
	_check(
		bool(repair.get("accepted", false))
		and torrent.get_component_damage().get_component_state(torrent_component)
		< ShipComponentDamageType.ComponentState.FAILED
		and int(repaired_snapshot.get("visible_shard_count", 0)) == 0,
		"authorized component repair clears the failed silhouette as soon as the section leaves FAILED"
	)

	for craft_name: String in CRAFT_COMPONENTS:
		var craft := game.get_node(craft_name) as HeroShip
		var reset := craft.reset_for_reuse(craft.global_transform)
		var presentation := craft.get_damage_presentation()
		_check(
			bool(reset.get("accepted", false))
			and presentation.get_active_component_effect_count() == 0
			and presentation.find_children(
				"ComponentFailureShard*", "MeshInstance3D", true, false
			).is_empty(),
			"%s respawn/reuse removes every retained failure shard" % craft_name
		)

	game.queue_free()
	await process_frame
	_finish()


func _component_local_position(ship: HeroShip, component_id: StringName) -> Vector3:
	for component in ship.get_component_damage_report().get("components", []) as Array:
		if StringName((component as Dictionary).get("id", &"")) == component_id:
			return (component as Dictionary).get("local_position", Vector3.ZERO) as Vector3
	return Vector3.ZERO


func _profile_signature(shards: Array) -> String:
	var parts: PackedStringArray = []
	for shard_record: Dictionary in shards:
		parts.append(str(shard_record.get("transform", Transform3D.IDENTITY)))
	return "|".join(parts)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("HERO_COMPONENT_FAILURE_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("HERO_COMPONENT_FAILURE_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
