extends SceneTree

const BOOTSTRAP_SCENE := preload(
	"res://scenes/world/components/ember_moon_streaming_bootstrap.tscn"
)
const EXPECTED_ASSERTIONS := 10

var _assertions := 0
var _failures := PackedStringArray()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var bootstrap := BOOTSTRAP_SCENE.instantiate() as EmberMoonStreamingBootstrap
	root.add_child(bootstrap)
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
