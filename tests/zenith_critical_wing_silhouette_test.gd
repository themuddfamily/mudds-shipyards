extends SceneTree

## Focused proof that the existing starboard-wing ledger gains a non-colour
## failed-state silhouette only. The retained cue remains presentation-only.

const ZENITH_SCENE := preload("res://scenes/ships/zenith_interceptor.tscn")
const ComponentDamage := preload("res://scripts/combat/ship_component_damage.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _initialize() -> void:
	var craft := ZENITH_SCENE.instantiate() as ZenithInterceptor
	root.add_child(craft)
	await process_frame
	await physics_frame

	var cue := craft.get_zenith_visual_root().get_node(^"StarboardWingDamageCue") as Node3D
	var spar := cue.get_node(^"ExposedWingSpar") as MeshInstance3D
	var nominal_transform := spar.transform
	var model := craft.get_component_damage()
	var hit := _component_local_position(craft, ComponentDamage.COMPONENT_STARBOARD_WING)
	model.record_damage(craft.maximum_hull * 2.0, hit)
	await process_frame
	var failed := craft.get_starboard_wing_damage_cue_snapshot()
	_check(
		model.get_component_state(ComponentDamage.COMPONENT_STARBOARD_WING) \
			== ComponentDamage.ComponentState.FAILED
			and bool(failed.get("visible", false))
			and failed.get("silhouette_pose", &"") == &"failed_canted"
			and spar.rotation_degrees.is_equal_approx(
				ZenithInterceptor.DAMAGE_SPAR_FAILED_ROTATION_DEGREES
			)
			and spar.scale.is_equal_approx(ZenithInterceptor.DAMAGE_SPAR_FAILED_SCALE)
			and not spar.transform.is_equal_approx(nominal_transform),
		"the existing failed wing state exposes a fixed canted, taller spar silhouette without relying on colour"
	)
	_check(
		cue.process_mode == Node.PROCESS_MODE_DISABLED
			and cue.get_child_count() == 2
			and cue.find_children("*", "Light3D", true, false).is_empty()
			and cue.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"the failed pose reuses the retained presentation cue without lights, collision, timing, or new renderers"
	)

	var repair_delta := 2.0 / maxf(model.repair_rate_per_second, 0.001)
	model.tick_component_repair(ComponentDamage.COMPONENT_STARBOARD_WING, repair_delta, true)
	await process_frame
	var repaired := craft.get_starboard_wing_damage_cue_snapshot()
	_check(
		model.get_component_state(ComponentDamage.COMPONENT_STARBOARD_WING) \
			== ComponentDamage.ComponentState.NOMINAL
			and not bool(repaired.get("visible", true))
			and repaired.get("silhouette_pose", &"") == &"nominal_upright"
			and spar.transform.is_equal_approx(nominal_transform),
		"authorized repair restores the exact nominal spar pose before hiding the retained cue"
	)

	craft.queue_free()
	await process_frame
	_finish()


func _component_local_position(craft: HeroShip, component_id: StringName) -> Vector3:
	for component_variant in craft.get_component_damage_report().get("components", []) as Array:
		var component := component_variant as Dictionary
		if StringName(component.get("id", &"")) == component_id:
			return component.get("local_position", Vector3.INF) as Vector3
	return Vector3.INF


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ZENITH_CRITICAL_WING_SILHOUETTE_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	print("ZENITH_CRITICAL_WING_SILHOUETTE_TEST_FAILED: %s" % "; ".join(_failures))
	quit(1)
