extends SceneTree

## Range opponents aim at the player's strikable hull, never at the off-hull
## boarding sphere.
##
## Every production hero ship carries `ShipBoardingArea/BoardingRange`, an
## interaction-layer sphere that sits metres beside the hull and precedes the
## hull shapes in tree order. A first-shape aim point picked that sphere, so a
## resolver-backed opponent's authoritative hitscan was fired at empty space
## beside a narrow craft. This suite targets the production Arrow and Zenith
## hulls, proves the aim point is a hitscan-strikable hull shape, and fires the
## opponent's real hitscan from all round the craft through the live authority.

const SkirmisherScene := preload("res://scenes/ships/flanking_skirmisher_opponent.tscn")
const Layers := preload("res://scripts/core/physics_layers.gd")
const SHIP_SCENES := [
	"res://scenes/ships/arrow_recon_ship.tscn",
	"res://scenes/ships/zenith_interceptor.tscn",
]
const FIRING_RANGE := 45.0
const BEARINGS := 12

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for scene_path: String in SHIP_SCENES:
		await _test_ship(scene_path)
	_finish()


func _test_ship(scene_path: String) -> void:
	var host := Node3D.new()
	host.name = "HullAimHost"
	root.add_child(host)
	var authority := LiveCombatAuthority.new()
	authority.name = "CombatAuthority"
	host.add_child(authority)
	var ship := (load(scene_path) as PackedScene).instantiate() as Node3D
	host.add_child(ship)
	ship.global_position = Vector3.ZERO
	var opponent := SkirmisherScene.instantiate() as ResolverBackedOpponent
	host.add_child(opponent)
	await process_frame
	await physics_frame
	await physics_frame
	var label := scene_path.get_file()

	opponent.activate(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, -FIRING_RANGE)))
	opponent.set_target(ship)
	# The anchor role keeps the skirmisher's own firing arc open on every bearing.
	opponent.call(&"_assign_wing_role_internal", WingCoordinator.ROLE_ANCHOR)
	var aim_shape := opponent.get(&"_target_aim_shape") as CollisionShape3D
	var aim_owner := aim_shape.get_parent() as CollisionObject3D if aim_shape != null else null
	_check(
		aim_owner != null
			and (aim_owner.collision_layer & Layers.HITSCAN_QUERY_MASK) != 0
			and not ship.get_node(^"ShipBoardingArea").is_ancestor_of(aim_shape),
		"%s: the opponent aims at a strikable hull shape, not the boarding sphere (aimed at %s)"
			% [label, ship.get_path_to(aim_shape) if aim_shape != null else "<none>"]
	)
	_check(
		opponent.is_combat_source_registered(),
		"%s: the opponent registers with the live combat authority" % label
	)

	var struck := 0
	for index in BEARINGS:
		var angle := TAU * float(index) / float(BEARINGS)
		var position := Vector3(sin(angle), 0.0, -cos(angle)) * FIRING_RANGE
		opponent.global_transform = Transform3D(
			Basis.looking_at((ship.global_position - position).normalized(), Vector3.UP),
			position
		)
		await physics_frame
		await physics_frame
		opponent.call(&"_fire_at_target", opponent.call(&"_get_target_aim_position"))
		var result := opponent.get(&"_last_shot_result") as Dictionary
		if _strikes_ship(result, ship):
			struck += 1
	_check(
		struck == BEARINGS,
		"%s: an aimed hitscan strikes the hull from every bearing (%d/%d)" % [label, struck, BEARINGS]
	)
	host.queue_free()
	await process_frame
	await process_frame


## The skirmisher fires a small fan: the shot lands if any pellet strikes the
## craft's own collision tree.
func _strikes_ship(result: Dictionary, ship: Node3D) -> bool:
	var pellets: Array = result.get("pellets", [result])
	for pellet: Dictionary in pellets:
		var collider := pellet.get("collider") as Node
		if bool(pellet.get("hit", false)) and collider != null \
				and (collider == ship or ship.is_ancestor_of(collider)):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: ", description)
	else:
		_failures.append(description)
		push_error("FAIL: " + description)


func _finish() -> void:
	if _failures.is_empty():
		print("RANGE_OPPONENT_HULL_AIM_TEST_OK: %d assertions" % _assertions)
		quit(0)
	else:
		print("RANGE_OPPONENT_HULL_AIM_TEST_FAILED: ", "; ".join(_failures))
		quit(1)
