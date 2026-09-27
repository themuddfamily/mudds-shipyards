extends SceneTree

## Phase 10 §2 dormant-opponent residency. A production opponent that opts into
## `release_visuals_while_dormant` keeps its visual root out of the scene tree
## while stood down and gets the same root back on activation. Its body,
## colliders, muzzles, collision layers and health contract are unchanged, and a
## fixture that does not opt in keeps its visual root attached exactly as before.

const RANGE_SCENE := preload("res://scenes/ships/range_opponent.tscn")
const SKIRMISHER_SCENE := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const STATION_DEFENSE_SCENE_PATH := "res://scenes/activities/station_defense_encounter.tscn"
const SHIP_LAYER := PhysicsLayers.SHIP
const TARGET_LAYER := PhysicsLayers.TARGET
const MAIN_OPTED_IN := [
	&"RangeOpponent", &"StandoffPicket", &"WingSkirmisherLead",
	&"WingSkirmisherWing", &"CourierRunner", &"TorpedoBoat",
]
const ROSTER_OPTED_IN := [
	&"PerimeterRaiderAlpha", &"PerimeterRaiderBeta",
	&"PerimeterRaiderGamma", &"PerimeterHeavyPicket",
]

var _assertions := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_fixture_default_keeps_presentation()
	await _test_release_activation_and_stand_down()
	await _test_destruction_holds_presentation_until_effects_end()
	await _test_reentry_and_free_while_released()
	await _test_resolver_backed_derivative()
	_test_production_scenes_opt_in()
	if _failures.is_empty():
		print("DORMANT_OPPONENT_PRESENTATION_RESIDENCY_TEST_OK: %d checks" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_fixture_default_keeps_presentation() -> void:
	var opponent := RANGE_SCENE.instantiate() as RangeOpponent
	root.add_child(opponent)
	await process_frame
	await process_frame
	_check(not opponent.release_visuals_while_dormant, "fixtures default to a resident presentation")
	_check(
		opponent.get_node_or_null(^"RangeInterceptorVisual") != null
			and opponent.is_presentation_resident()
			and opponent.get_presentation_root() == opponent.get_node(^"RangeInterceptorVisual"),
		"a dormant fixture keeps its visual root attached"
	)
	opponent.free()


func _test_release_activation_and_stand_down() -> void:
	var reference := RANGE_SCENE.instantiate() as RangeOpponent
	root.add_child(reference)
	var opponent := RANGE_SCENE.instantiate() as RangeOpponent
	opponent.release_visuals_while_dormant = true
	root.add_child(opponent)
	await process_frame
	await process_frame
	var visual := opponent.get_presentation_root()
	var reference_index := reference.get_node(^"RangeInterceptorVisual").get_index()
	_check(
		visual != null
			and visual.name == &"RangeInterceptorVisual"
			and not visual.is_inside_tree()
			and visual.get_parent() == null
			and opponent.get_node_or_null(^"RangeInterceptorVisual") == null
			and not opponent.is_presentation_resident(),
		"a dormant opted-in opponent holds its visual root out of the tree"
	)
	_check(
		_direct_collision_count(opponent) == _direct_collision_count(reference)
			and _direct_collision_count(opponent) > 0
			and opponent.get_node_or_null(^"PortMuzzle") is Marker3D
			and opponent.get_node_or_null(^"StarboardMuzzle") is Marker3D
			and opponent.collision_layer == 0
			and opponent.collision_mask == 0
			and not opponent.visible
			and not opponent.is_active(),
		"release keeps every collider and muzzle and the dormant collision contract"
	)
	_check(
		opponent.get_weapon_telegraph_mesh_allocation_audit().get("errors", ["missing"]).is_empty(),
		"presentation audits still read the released visual root"
	)
	var released_nodes := opponent.find_children("*", "MeshInstance3D", true, false).size()
	var reference_nodes := reference.find_children("*", "MeshInstance3D", true, false).size()
	_check(released_nodes < reference_nodes, "released renderers leave the resident tree")

	var spawn := Transform3D(Basis(Vector3.UP, 0.4), Vector3(6.0, 3.0, -12.0))
	var activation := opponent.activate_with_result(spawn)
	_check(
		bool(activation.get("accepted", false))
			and opponent.is_active()
			and opponent.visible
			and opponent.get_presentation_root() == visual
			and visual.get_parent() == opponent
			and visual.is_inside_tree()
			and visual.visible
			and visual.get_index() == reference_index
			and opponent.is_presentation_resident(),
		"activation reattaches the same visual root at its authored child index"
	)
	_check(
		opponent.collision_layer == SHIP_LAYER | TARGET_LAYER
			and opponent.global_position.is_equal_approx(spawn.origin)
			and is_equal_approx(opponent.get_health(), opponent.get_maximum_health())
			and opponent.find_children("*", "MeshInstance3D", true, false).size() == reference_nodes,
		"activation restores the full presentation with unchanged authority"
	)
	await process_frame
	_check(opponent.is_presentation_resident(), "an active opponent is never released")

	opponent.deactivate()
	_check(opponent.is_presentation_resident(), "release waits for the deferred pass")
	await process_frame
	_check(
		not opponent.is_presentation_resident()
			and opponent.get_presentation_root() == visual
			and not visual.is_inside_tree(),
		"stand-down releases the same visual root again"
	)

	opponent.release_visuals_while_dormant = false
	_check(
		opponent.is_presentation_resident()
			and opponent.get_node_or_null(^"RangeInterceptorVisual") == visual,
		"clearing the flag restores the presentation while dormant"
	)
	reference.free()
	opponent.free()


func _test_destruction_holds_presentation_until_effects_end() -> void:
	var opponent := RANGE_SCENE.instantiate() as RangeOpponent
	opponent.release_visuals_while_dormant = true
	root.add_child(opponent)
	await process_frame
	await process_frame
	opponent.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.0, -10.0)))
	var visual := opponent.get_presentation_root()
	opponent.apply_damage(opponent.get_maximum_health() * 2.0, opponent.global_position)
	await process_frame
	await process_frame
	_check(
		not opponent.is_active() and visual.get_parent() == opponent,
		"a destroyed craft keeps its presentation attached while destruction effects run"
	)
	opponent.deactivate()
	await process_frame
	_check(
		not opponent.is_presentation_resident() and opponent.get_presentation_root() == visual,
		"clearing the destruction effects lets the dormant craft release"
	)
	var reactivated := opponent.activate_with_result(Transform3D.IDENTITY)
	_check(
		bool(reactivated.get("accepted", false))
			and visual.get_parent() == opponent
			and visual.visible
			and is_equal_approx(opponent.get_health(), opponent.get_maximum_health()),
		"a destroyed and released craft reactivates with its full presentation"
	)
	opponent.free()


func _test_reentry_and_free_while_released() -> void:
	var opponent := RANGE_SCENE.instantiate() as RangeOpponent
	opponent.release_visuals_while_dormant = true
	root.add_child(opponent)
	await process_frame
	await process_frame
	var visual := opponent.get_presentation_root()
	root.remove_child(opponent)
	root.add_child(opponent)
	await process_frame
	_check(
		not opponent.is_presentation_resident()
			and opponent.get_presentation_root() == visual
			and visual.get_parent() == null,
		"tree re-entry leaves a released presentation released"
	)
	var activation := opponent.activate_with_result(Transform3D.IDENTITY)
	_check(
		bool(activation.get("accepted", false)) and visual.get_parent() == opponent,
		"a re-entered opponent reattaches its presentation on activation"
	)
	opponent.deactivate()
	await process_frame
	var released := opponent.get_presentation_root()
	var released_id := released.get_instance_id() if released != null else 0
	opponent.free()
	_check(
		released_id != 0 and not is_instance_id_valid(released_id),
		"freeing a dormant opponent frees its released presentation"
	)


func _test_resolver_backed_derivative() -> void:
	var skirmisher := SKIRMISHER_SCENE.instantiate() as FlankingSkirmisherOpponent
	skirmisher.release_visuals_while_dormant = true
	root.add_child(skirmisher)
	await process_frame
	await process_frame
	var visual := skirmisher.get_presentation_root()
	_check(
		visual != null
			and visual.name == &"WingSkirmisherVisual"
			and visual.get_parent() == null
			and skirmisher.get_node_or_null(^"WingSkirmisherVisual") == null,
		"a resolver-backed derivative releases its own visual root"
	)
	skirmisher.activate(Transform3D(Basis.IDENTITY, Vector3(4.0, 2.0, -8.0)))
	_check(
		skirmisher.is_active()
			and skirmisher.get_node_or_null(^"WingSkirmisherVisual") == visual
			and visual.get_node_or_null(^"RoleLamp") != null,
		"derivative activation restores its visual root with its fittings"
	)
	skirmisher.deactivate()
	await process_frame
	_check(not skirmisher.is_presentation_resident(), "derivative stand-down releases again")
	skirmisher.free()


func _test_production_scenes_opt_in() -> void:
	var main_flags := _instance_flags(MAIN_SCENE_PATH)
	for node_name: StringName in MAIN_OPTED_IN:
		_check(bool(main_flags.get(node_name, false)), "main.tscn opts %s in" % node_name)
	var roster_flags := _instance_flags(STATION_DEFENSE_SCENE_PATH)
	for node_name: StringName in ROSTER_OPTED_IN:
		_check(bool(roster_flags.get(node_name, false)), "station defence roster opts %s in" % node_name)


func _instance_flags(path: String) -> Dictionary:
	var flags := {}
	var scene := load(path) as PackedScene
	if scene == null:
		return flags
	var state := scene.get_state()
	for node_index in state.get_node_count():
		for property_index in state.get_node_property_count(node_index):
			if state.get_node_property_name(node_index, property_index) == &"release_visuals_while_dormant":
				flags[state.get_node_name(node_index)] = bool(
					state.get_node_property_value(node_index, property_index)
				)
	return flags


func _direct_collision_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is CollisionShape3D:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
