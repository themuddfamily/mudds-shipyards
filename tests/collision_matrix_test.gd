extends SceneTree

const Layers = preload("res://scripts/core/physics_layers.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_project_layer_mapping()
	_test_unique_layer_bits()
	_test_actor_collision_matrix()
	_test_interaction_contract()
	_test_weapon_query_contract()
	_test_mask_composition()
	_finish()


func _test_project_layer_mapping() -> void:
	var expected := [
		[Layers.WORLD_INDEX, Layers.WORLD, "World"],
		[Layers.PLAYER_INDEX, Layers.PLAYER, "Player"],
		[Layers.SHIP_INDEX, Layers.SHIP, "Ship"],
		[Layers.INTERACTABLE_INDEX, Layers.INTERACTABLE, "Interactable"],
		[Layers.PROJECTILE_INDEX, Layers.PROJECTILE, "Projectile"],
		[Layers.TARGET_INDEX, Layers.TARGET, "Target"],
	]
	for entry: Array in expected:
		var layer_index := int(entry[0])
		var layer_bit := int(entry[1])
		var expected_name := str(entry[2])
		var setting_path := "layer_names/3d_physics/layer_%d" % layer_index
		_check(
			str(ProjectSettings.get_setting(setting_path, "")) == expected_name,
			"layer %d remains named %s in project.godot" % [layer_index, expected_name]
		)
		_check(
			layer_bit == 1 << (layer_index - 1),
			"%s constant uses the project layer-%d bit" % [expected_name, layer_index]
		)


func _test_unique_layer_bits() -> void:
	var named_layers: Array[int] = [
		Layers.WORLD,
		Layers.PLAYER,
		Layers.SHIP,
		Layers.INTERACTABLE,
		Layers.PROJECTILE,
		Layers.TARGET,
	]
	var combined := 0
	for layer_bit in named_layers:
		_check(
			layer_bit > 0 and (layer_bit & (layer_bit - 1)) == 0,
			"every named layer is exactly one bit"
		)
		_check(
			(combined & layer_bit) == 0,
			"named layer bits never overlap"
		)
		combined |= layer_bit
	_check(
		combined == Layers.ALL_NAMED_LAYERS,
		"ALL_NAMED_LAYERS is the exact union of the six project layers"
	)


func _test_actor_collision_matrix() -> void:
	_check(
		Layers.WORLD_BODY_LAYER == Layers.WORLD and Layers.WORLD_BODY_MASK == Layers.NONE,
		"static world geometry occupies only World and does not monitor actors"
	)
	_check(
		Layers.PLAYER_BODY_LAYER == Layers.PLAYER,
		"player bodies occupy the Player layer"
	)
	_check(
		Layers.SHIP_BODY_LAYER == Layers.SHIP,
		"all player and AI ship bodies share the Ship layer"
	)
	_check(
		(Layers.PLAYER_BODY_MASK & Layers.WORLD) != 0
		and (Layers.SHIP_BODY_MASK & Layers.WORLD) != 0,
		"players and ships both collide with station geometry"
	)
	_check(
		(Layers.PLAYER_BODY_MASK & Layers.SHIP) != 0
		and (Layers.SHIP_BODY_MASK & Layers.PLAYER) != 0,
		"player-ship collision intent is reciprocal"
	)
	_check(
		(Layers.SHIP_BODY_MASK & Layers.SHIP) != 0,
		"ship bodies collide with other player or AI ships"
	)
	_check(
		(Layers.PLAYER_BODY_MASK & Layers.PLAYER) != 0,
		"multiple physical player bodies collide with one another"
	)
	_check(
		Layers.PLAYER_BODY_MASK == Layers.SOLID_BODY_MASK
		and Layers.SHIP_BODY_MASK == Layers.SOLID_BODY_MASK,
		"solid actor masks use one symmetric composition"
	)


func _test_interaction_contract() -> void:
	_check(
		Layers.INTERACTABLE_AREA_LAYER == Layers.INTERACTABLE
		and Layers.INTERACTABLE_AREA_MASK == Layers.NONE,
		"interactable areas advertise themselves without monitoring physics bodies"
	)
	_check(
		Layers.INTERACTION_QUERY_MASK == Layers.INTERACTABLE,
		"interaction sensing sees exactly the Interactable layer"
	)
	_check(
		(Layers.INTERACTION_QUERY_MASK & Layers.SHIP) == 0
		and (Layers.INTERACTION_QUERY_MASK & Layers.WORLD) == 0,
		"interaction queries cannot mistake solid ships or station geometry for prompts"
	)
	_check(
		(Layers.SHIP_BODY_LAYER & Layers.INTERACTABLE) == 0,
		"ships expose interaction through a dedicated child area, not their body bit"
	)


func _test_weapon_query_contract() -> void:
	_check(
		Layers.DAMAGEABLE_LAYERS == Layers.PLAYER | Layers.SHIP | Layers.TARGET,
		"damageable queries cover players, physical ships, and Target hurtboxes"
	)
	_check(
		Layers.HITSCAN_QUERY_MASK == Layers.WORLD | Layers.DAMAGEABLE_LAYERS,
		"hitscan resolves world occlusion plus every supported damageable"
	)
	for required_layer: int in [Layers.WORLD, Layers.PLAYER, Layers.SHIP, Layers.TARGET]:
		_check(
			(Layers.HITSCAN_QUERY_MASK & required_layer) != 0,
			"hitscan includes required layer bit %d" % required_layer
		)
	_check(
		(Layers.HITSCAN_QUERY_MASK & Layers.INTERACTABLE) == 0
		and (Layers.HITSCAN_QUERY_MASK & Layers.PROJECTILE) == 0,
		"hitscan ignores prompt areas and other projectiles"
	)
	_check(
		Layers.PROJECTILE_BODY_LAYER == Layers.PROJECTILE
		and Layers.PROJECTILE_BODY_MASK == Layers.HITSCAN_QUERY_MASK,
		"physical projectiles use the same hit/occlusion contract as hitscan"
	)


func _test_mask_composition() -> void:
	_check(
		Layers.SOLID_ACTOR_LAYERS == Layers.PLAYER | Layers.SHIP,
		"SOLID_ACTOR_LAYERS composes player and ship bodies"
	)
	_check(
		Layers.SOLID_BODY_MASK == Layers.WORLD | Layers.SOLID_ACTOR_LAYERS,
		"SOLID_BODY_MASK composes world plus all solid actors"
	)
	_check(
		Layers.QUERY_ONLY_LAYERS == Layers.INTERACTABLE | Layers.TARGET,
		"query-only composition contains interaction and hurtbox layers"
	)
	_check(
		Layers.CAMERA_OBSTRUCTION_QUERY_MASK == Layers.WORLD | Layers.SHIP,
		"camera obstruction ignores triggers and sees world/ships"
	)
	_check(
		Layers.AI_AVOIDANCE_QUERY_MASK == Layers.WORLD | Layers.SHIP,
		"AI avoidance sees geometry and other ships"
	)
	var masks: Array[int] = [
		Layers.WORLD_BODY_MASK,
		Layers.PLAYER_BODY_MASK,
		Layers.SHIP_BODY_MASK,
		Layers.INTERACTABLE_AREA_MASK,
		Layers.DAMAGEABLE_TARGET_AREA_MASK,
		Layers.PROJECTILE_BODY_MASK,
		Layers.INTERACTION_QUERY_MASK,
		Layers.HITSCAN_QUERY_MASK,
		Layers.CAMERA_OBSTRUCTION_QUERY_MASK,
		Layers.AI_AVOIDANCE_QUERY_MASK,
	]
	for mask in masks:
		_check(
			(mask & Layers.ALL_NAMED_LAYERS) == mask,
			"every contract mask uses only named project layers"
		)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("COLLISION_MATRIX_TEST_OK")
		quit(0)
	else:
		print("COLLISION_MATRIX_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
