extends SceneTree

## Focused regression for the bounded, caller-triggered hot-debris aftermath.

const HeroDamagePresentationType := preload(
	"res://scripts/effects/hero_damage_presentation.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node3D.new()
	root.add_child(host)
	var presentation := HeroDamagePresentationType.new() as HeroDamagePresentation
	presentation.destruction_debris_count = 4
	presentation.destruction_effect_lifetime = 2.0
	host.add_child(presentation)
	presentation.present_destruction(Vector3(6.0, 0.0, -3.0))

	var aftermath := presentation.get_destruction_effect_root()
	var first_debris := aftermath.get_node_or_null("HeroHullDebris00") as RigidBody3D
	var hull := first_debris.get_node_or_null("HullFragment") as MeshInstance3D if first_debris != null else null
	var afterglow := first_debris.get_node_or_null("FractureAfterglow") as MeshInstance3D if first_debris != null else null
	_check(
		aftermath != null
		and first_debris != null
		and hull != null
		and afterglow != null
		and afterglow.mesh is BoxMesh
		and afterglow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"resolved destruction adds one bounded molten fracture face per debris piece"
	)

	presentation.call("_update_destruction_effects", 0.8)
	_check(
		afterglow != null
		and afterglow.transparency > 0.0
		and afterglow.transparency < 1.0
		and afterglow.scale.x < 1.0
		and is_equal_approx(hull.transparency, 0.0),
		"fracture glow visibly cools before intact debris begins its final fade"
	)

	presentation.call("_update_destruction_effects", 0.7)
	_check(
		hull != null and hull.transparency > 0.0 and hull.transparency < 1.0,
		"spent hull fragments fade during the bounded final aftermath window"
	)
	presentation.call("_update_destruction_effects", 0.6)
	_check(
		presentation.get_destruction_effect_root() == null
		and presentation.get_live_world_effect_count() == 0
		and aftermath.get_parent() == null,
		"aftermath expiry synchronously detaches every fragment and afterglow"
	)

	presentation.reset_for_reuse(1.0, HeroDamagePresentation.STATE_ACTIVE)
	presentation.present_destruction(Vector3.ZERO)
	var detached_aftermath := presentation.get_destruction_effect_root()
	host.remove_child(presentation)
	_check(
		presentation.get_live_world_effect_count() == 0 and detached_aftermath != null,
		"owner detach immediately drops all hot-debris aftermath tracking"
	)
	host.add_child(presentation)
	await process_frame
	_check(
		presentation.get_destruction_effect_root() == null
		and (not is_instance_valid(detached_aftermath) or not detached_aftermath.is_inside_tree()),
		"queued teardown cannot strand or resurrect hot debris across re-entry"
	)

	presentation.queue_free()
	host.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HERO_DESTRUCTION_AFTERMATH_VISUAL_TEST_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
