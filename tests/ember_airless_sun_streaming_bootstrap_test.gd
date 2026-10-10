extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const EXPECTED_ASSERTIONS := 22

var _assertions := 0
var _failures := PackedStringArray()


class LightSubclassProbe extends DirectionalLight3D:
	func _init() -> void:
		pass


	func _enter_tree() -> void:
		pass


class PrebuiltLightBranchProbe extends Node3D:
	var bootstrap: EmberMoonStreamingBootstrap
	var enter_counts := Vector2i(-1, -1)


	func _enter_tree() -> void:
		enter_counts = Vector2i(int(bootstrap.call(&"_descendant_directional_light_count")),
			bootstrap.find_children("*", "DirectionalLight3D", true, false).size())


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	var seeded_light := DirectionalLight3D.new()
	bootstrap.add_child(seeded_light)
	root.add_child(bootstrap)
	_check(_light_count(bootstrap) == 1
		and (bootstrap.audit().errors as PackedStringArray).has("unloaded Ember retains a directional light"),
		"pre-existing native lights retain the unloaded-light refusal")
	bootstrap.remove_child(seeded_light)
	seeded_light.free()
	await process_frame
	var frame := bootstrap.get_coordinate_frame_for_session()
	_check(
		frame != null and bootstrap.get_airless_sun_rig() == null
			and bootstrap.find_children("*", "DirectionalLight3D", true, false).is_empty(),
		"unloaded Ember owns no live directional light",
	)

	var rebase := frame.request_rebase(bootstrap.position, 1)
	bootstrap.position += rebase.request.world_translation_delta
	var committed := frame.commit_rebase(int(rebase.request.request_id), 1)
	_check(
		rebase.accepted and committed.accepted and frame.get_generation() == 2,
		"caller-owned rebase establishes the live Ember frame without sun authority",
	)

	var north := _absolute(frame, Vector3.UP * bootstrap.BODY_RADIUS_METERS, 2)
	var load := bootstrap.update_absolute_focus(north, 2)
	await process_frame
	await process_frame
	var loaded := bootstrap.get_loaded_instance()
	var day_rig := bootstrap.get_airless_sun_rig() as EmberAirlessSunBinding
	var day_light := day_rig.get_directional_light() if day_rig != null else null
	_check(
		load.accepted and load.action == &"load" and loaded != null
			and day_rig != null and day_rig.get_parent() == loaded.get_parent(),
		"completed streamed generation composes the authored rig beside its Ember root",
	)
	_check(
		bootstrap.find_children("*", "DirectionalLight3D", true, false).size() == 1
			and day_light != null and day_light.visible
			and day_light.light_energy == EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY,
		"north-pole destination presents one visible authored daylight owner",
	)
	var first_rig_id := day_rig.get_instance_id()
	await _check_light_membership(bootstrap)

	var south := _absolute(frame, Vector3.DOWN * bootstrap.BODY_RADIUS_METERS, 2)
	var night := bootstrap.update_absolute_focus(south, 2)
	_check(
		night.accepted and night.reason == &"within_unload_hysteresis"
			and bootstrap.get_airless_sun_rig() == day_rig
			and day_light.light_energy == 0.0,
		"live south-pole destination drives the bounded airless night result",
	)

	root.remove_child(bootstrap)
	await process_frame
	root.add_child(bootstrap)
	await process_frame
	var reentered := bootstrap.update_absolute_focus(north, 2)
	_check(
		reentered.accepted and bootstrap.get_airless_sun_rig() == day_rig
			and day_light.light_energy == EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY
			and int(bootstrap.get_snapshot().airless_sun.attach_count) == 1,
		"whole-bootstrap detach and re-entry retains one generation and reapplies daylight",
	)

	var far := _absolute(frame, Vector3.UP * 300_001.0, 2)
	var unload := bootstrap.update_absolute_focus(far, 2)
	_check(
		unload.accepted and unload.action == &"unload"
			and bootstrap.get_loaded_instance() == null
			and bootstrap.get_airless_sun_rig() == null,
		"generation retirement synchronously detaches the matching sun rig",
	)
	_check(
		bootstrap.find_children("*", "DirectionalLight3D", true, false).is_empty()
			and int(bootstrap.get_snapshot().airless_sun.detach_count) == 1,
		"unloaded Ember again owns no directional light",
	)
	await process_frame

	var reload := bootstrap.update_absolute_focus(north, 2)
	await process_frame
	await process_frame
	var replacement_rig := bootstrap.get_airless_sun_rig() as EmberAirlessSunBinding
	var replacement_light := (
		replacement_rig.get_directional_light() if replacement_rig != null else null
	)
	_check(
		reload.accepted and reload.location_generation == 3
			and replacement_rig != null
			and replacement_rig.get_instance_id() != first_rig_id
			and replacement_light != null and replacement_light.visible
			and replacement_light.light_energy \
			== EmberAirlessSunBinding.AUTHORED_BASELINE_ENERGY,
		"reload generation three receives a fresh current daylight binding",
	)
	var snapshot := bootstrap.get_snapshot()
	var binding_capabilities := replacement_rig.get_snapshot().capabilities as Dictionary
	_check(
		bootstrap.audit().valid and replacement_rig.audit().valid
			and int(snapshot.airless_sun.attach_count) == 2
			and int(snapshot.airless_sun.detach_count) == 1
			and bool(binding_capabilities.production_caller_wired)
			and not bool(binding_capabilities.clock_or_ephemeris)
			and not bool(binding_capabilities.coordinate_conversion)
			and not bootstrap.is_processing() and not bootstrap.is_physics_processing(),
		"production composition audits green without clock, ephemeris, origin, or movement cadence",
	)

	bootstrap.queue_free()
	await process_frame
	_finish()


func _check_light_membership(bootstrap: EmberMoonStreamingBootstrap) -> void:
	var nested := Node3D.new()
	bootstrap.get_loaded_instance().get_parent().add_child(nested)
	var outside := Node3D.new()
	root.add_child(outside)
	var internal_branch := Node3D.new()
	internal_branch.add_child(DirectionalLight3D.new(), false, Node.INTERNAL_MODE_BACK)
	nested.add_child(internal_branch, false, Node.INTERNAL_MODE_BACK)
	_check(_light_count(bootstrap) == 2
		and bootstrap.find_children("*", "DirectionalLight3D", true, false).size() == 2
		and not bootstrap.audit().valid,
		"internal descendants at every level retain the original duplicate-light census")
	internal_branch.free()
	var native_light := DirectionalLight3D.new()
	nested.add_child(native_light)
	_check(_light_count(bootstrap) == 2 and not bootstrap.audit().valid,
		"arbitrary native descendant lights immediately retain the duplicate-light refusal")
	var removal_observations: Array[Vector2i] = []
	var observe_removal := func(node: Node) -> void:
		if node == native_light:
			removal_observations.append(Vector2i(_light_count(bootstrap),
				bootstrap.find_children("*", "DirectionalLight3D", true, false).size()))
	node_removed.connect(observe_removal)
	nested.remove_child(native_light)
	node_removed.disconnect(observe_removal)
	_check(removal_observations.size() == 1
		and removal_observations[0].x == removal_observations[0].y
		and _light_count(bootstrap) == 1 and bootstrap.audit().valid,
		"native removal matches the recursive census during notification and after unlink: "
		+ str(removal_observations))
	var prebuilt_branch := PrebuiltLightBranchProbe.new()
	prebuilt_branch.bootstrap = bootstrap
	prebuilt_branch.add_child(DirectionalLight3D.new())
	nested.add_child(prebuilt_branch)
	_check(prebuilt_branch.enter_counts.x == prebuilt_branch.enter_counts.y
		and prebuilt_branch.enter_counts.y == 2,
		"prebuilt subtree entry preserves the census before descendant enter notifications: "
		+ str(prebuilt_branch.enter_counts))
	prebuilt_branch.free()
	var subclass_light := LightSubclassProbe.new()
	nested.add_child(subclass_light)
	_check(_light_count(bootstrap) == 2 and not bootstrap.audit().valid,
		"the fresh census counts light subclasses with overridden lifecycle callbacks")
	subclass_light.reparent(outside)
	var outside_valid: bool = _light_count(bootstrap) == 1 and bootstrap.audit().valid
	subclass_light.reparent(nested)
	_check(outside_valid and _light_count(bootstrap) == 2 and not bootstrap.audit().valid,
		"same-object light reparenting immediately observes both current descendant scopes")
	subclass_light.queue_free()
	_check(_light_count(bootstrap) == 2 and not bootstrap.audit().valid,
		"queued duplicate lights remain in the census until actual removal")
	await process_frame
	_check(_light_count(bootstrap) == 1 and bootstrap.audit().valid,
		"freed duplicate lights leave the live census without retaining ownership")
	nested.add_child(native_light)
	root.remove_child(bootstrap)
	_check(_light_count(bootstrap) == 2
		and bootstrap.find_children("*", "DirectionalLight3D", true, false).size() == 2,
		"whole-bootstrap detach preserves the original current descendant scope")
	var detached_light := DirectionalLight3D.new()
	nested.add_child(detached_light)
	var detached_count := _light_count(bootstrap)
	detached_light.free()
	root.add_child(bootstrap)
	_check(detached_count == 3 and _light_count(bootstrap) == 2 and not bootstrap.audit().valid,
		"detached native additions and re-entry preserve current light scope")
	native_light.free()
	_check(_light_count(bootstrap) == 1 and bootstrap.audit().valid,
		"re-entered native light removal restores the original valid sun composition")
	nested.free()
	outside.free()


func _light_count(bootstrap: EmberMoonStreamingBootstrap) -> int:
	return int(bootstrap.call(&"_descendant_directional_light_count"))


func _absolute(
		frame: PlanetaryCoordinateFrame,
		body_local: Vector3,
		generation: int,
	) -> Dictionary:
	var encoded := frame.encode_body_local_position(body_local, generation)
	return (encoded.coordinate as Dictionary).orbital_coordinate as Dictionary


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error("FAIL: %s" % message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PASS: Ember streamed airless sun production (%d assertions)" % _assertions)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: %s" % failure)
		quit(1)
