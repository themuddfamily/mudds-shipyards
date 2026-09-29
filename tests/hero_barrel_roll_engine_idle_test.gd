extends SceneTree

## A barrel roll is one key press, and the craft finishes it on its own.
##
## Reproduction: on real Main, a single barrel-roll tap on the Bulwark, cargo
## hauler, long-range bomber, Halyard or Jovian - whose roll takes 2.4 to 4.8 s
## at their authored roll rates - left the craft frozen part-way round, on its
## side or upside down, once the engine idled 1.5 s after the last input. The
## automatic idle counted the roll's own motion as "no demand" and stopped the
## integrator that was turning the craft.

const Cadence := preload("res://tests/fixed_physics_cadence.gd")
const SCENES: Array[String] = [
	"res://scenes/ships/bulwark_heavy_gunship.tscn",
	"res://scenes/ships/halyard_crew_transport.tscn",
	"res://scenes/ships/jovian_light_freighter.tscn",
]
const WAIT_TICKS := 480


class ScriptedSource:
	extends ShipCommandSource
	var controls: Dictionary = {}

	func _sample_controls() -> Dictionary:
		return controls.duplicate(true)


var _cadence := Cadence.new()
var _assertions := 0
var _failures: Array[String] = []


func _initialize() -> void:
	await process_frame
	_cadence.pin()
	for path in SCENES:
		await _roll(path)
	_cadence.restore()
	if _failures.is_empty():
		print("PASS hero_barrel_roll_engine_idle_test (%d assertions)" % _assertions)
		print("HERO_BARREL_ROLL_ENGINE_IDLE_OK")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL hero_barrel_roll_engine_idle_test (%d failures)" % _failures.size())
		quit(1)


func _roll(path: String) -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var ship := (load(path) as PackedScene).instantiate() as HeroShip
	stage.add_child(ship)
	ship.global_position = Vector3(0.0, 400.0, 0.0)
	var source := ScriptedSource.new()
	ship.add_child(source)
	ship.set_command_source(source)
	ship.set_piloted(true)
	var label := String(ship.get_ship_id())
	# A short burst of thrust wakes the engine and gets the craft moving.
	source.controls = {"throttle": 1.0}
	for i in 20:
		await physics_frame
	source.controls = {}
	for i in 10:
		await physics_frame
	var up_before := ship.global_basis.y.normalized()
	source.controls = {"barrel_roll": true}
	await physics_frame
	source.controls = {}
	_check(float(ship.get(&"_roll_animation")) > 0.0, "%s starts its barrel roll" % label)
	var finished_at := -1
	var engine_off_mid_roll := false
	for tick in WAIT_TICKS:
		await physics_frame
		var remaining := float(ship.get(&"_roll_animation"))
		if remaining > 0.0 and StringName(ship.get_telemetry().engine_state) != HeroShip.ENGINE_ONLINE:
			engine_off_mid_roll = true
		if remaining <= 0.0 and finished_at < 0:
			finished_at = tick
	var up_after := ship.global_basis.y.normalized()
	_check(not engine_off_mid_roll, "%s keeps its engine running until the roll completes" % label)
	_check(finished_at >= 0, "%s completes the whole barrel roll (%.2f rad left)" % [
		label, float(ship.get(&"_roll_animation"))
	])
	_check(up_after.dot(up_before) > 0.99, "%s comes out of the roll upright (up dot %.3f)" % [
		label, up_after.dot(up_before)
	])
	_check(
		StringName(ship.get_telemetry().engine_state) == HeroShip.ENGINE_OFFLINE,
		"%s still idles its engine once the roll is over" % label
	)
	print("ROLL %s finished_at=%d engine_off_mid_roll=%s up_dot=%.3f" % [
		label, finished_at, engine_off_mid_roll, up_after.dot(up_before)
	])
	ship.set_piloted(false)
	root.remove_child(stage)
	stage.free()
	for i in 2:
		await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
