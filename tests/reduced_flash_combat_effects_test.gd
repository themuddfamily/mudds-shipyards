extends SceneTree

## Reduced flash reaching the combat effects every craft shares, through real
## `res://scenes/main.tscn`: the player's pulse muzzle flash and impact flare,
## and a fleet hull's damage presentation (impact light, alarm, failing-engine
## light and the destruction flash). Each is checked on an effect created before
## the live toggle, one created after it, and again after a whole-Main re-entry.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")

## Oscillation amplitude above which a light is treated as flashing.
const STEADY_TOLERANCE := 0.01
## Every authored opponent in Main; each shares RangeOpponent's destruction flash.
const OPPONENT_PATHS: Array[NodePath] = [
	^"RangeOpponent", ^"StandoffPicket", ^"WingSkirmisherLead",
	^"WingSkirmisherWing", ^"CourierRunner", ^"TorpedoBoat",
]

var _failures: Array[String] = []
var _assertions := 0


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, _maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		return {"error": OK, "bytes": (files[path] as PackedByteArray).duplicate()}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		files[to_path] = files[from_path]
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate() as GameFlow
	_check(game != null, "production Main instantiates")
	if game == null:
		_finish()
		return
	game.configure_runtime_settings_persistence(
		Store.new("memory://reduced-flash-combat.json", MemoryFilesystem.new()),
		"memory://reduced-flash-combat-legacy.cfg"
	)
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame

	var settings := game.get_runtime_settings()
	var pulse := game.pulse_presentation
	var fleet: Array[HeroShip] = game.get_flyable_ships()
	_check(settings != null and is_instance_valid(pulse) and fleet.size() >= 2,
		"Main exposes RuntimeSettings, the pulse presentation and the fleet")
	if settings == null or not is_instance_valid(pulse) or fleet.size() < 2:
		await _clean_up(game)
		_finish()
		return
	settings.config_path = "user://reduced_flash_combat_%d.cfg" % Time.get_ticks_usec()
	settings.reset_to_defaults()
	await process_frame
	var damage := fleet[0].get_damage_presentation()
	# A hull that drives HeroShip's own exhaust lights (variant craft own theirs).
	var glow_ship: HeroShip = null
	for candidate in fleet:
		if not (candidate.get("_engine_lights") as Array).is_empty() \
				and candidate.get_damage_presentation() != null and candidate != fleet[1]:
			glow_ship = candidate
			break
	_check(glow_ship != null, "a fleet hull drives HeroShip's shared exhaust lights")
	var terminal_damage := fleet[1].get_damage_presentation()
	_check(damage != null and terminal_damage != null, "fleet hulls carry the damage presentation")
	if damage == null or terminal_damage == null:
		await _clean_up(game)
		_finish()
		return

	# Baseline with reduced flash off: the practical lights do fire.
	pulse.set_auto_advance_enabled(false)
	pulse.clear_effects()
	_check(_present_hit(game, fleet[0]), "a pulse shot is accepted with reduced flash off")
	_check(_muzzle_light_energy(pulse) > 0.5,
		"baseline: the muzzle flash lights the scene with reduced flash off")
	var impact_before := _present_impact(damage)
	_check(impact_before != null and impact_before.light_energy > 5.0,
		"baseline: a hull hit throws a bright practical light")
	_check(_light_swing(damage, "EngineFailureLight") > 0.5,
		"baseline: a failing engine light stutters with reduced flash off")
	_check(_engine_glow_swing(glow_ship) > 0.5,
		"baseline: a failing engine's exhaust light stutters with reduced flash off")
	_check(_spool_glow_swing(glow_ship) > 0.5,
		"baseline: the spool-up exhaust light pulses with reduced flash off")
	var courier := game.get_node_or_null(^"CourierRunner") as RangeOpponent
	var early_flash := _spawn_opponent_flash(courier)
	_check(early_flash != null and early_flash.light_energy >= 9.0,
		"baseline: an opponent destruction flash peaks at full strength")
	var thrust_before := _thrust_swing(glow_ship)

	# Live toggle through the production settings authority.
	settings.reduced_flash = true
	_check(_muzzle_light_energy(pulse) <= 0.0,
		"a muzzle flash already on screen drops its dynamic light when reduced flash turns on")
	pulse.advance_simulation(0.3)
	_check(_impact_light_energy(pulse) <= 0.0,
		"the impact flare of a shot fired before the toggle stays unlit")
	damage._update_transient_effects(0.0)
	_check(is_instance_valid(impact_before) and impact_before.light_energy <= 2.0,
		"a hull-hit light spawned before the toggle is capped")
	courier._process(0.01)
	_check(is_instance_valid(early_flash) and early_flash.light_energy <= 3.0,
		"an opponent destruction flash spawned before the toggle is capped")
	_check(is_equal_approx(_thrust_swing(glow_ship), thrust_before) and thrust_before > 0.1,
		"reduced flash leaves the failing engine's thrust multiplier untouched")
	await _check_reduced(game, fleet[0], glow_ship, pulse, damage, "after the live toggle")

	# Whole-Main detach and re-entry keeps the accepted setting.
	var parent := game.get_parent()
	parent.remove_child(game)
	await process_frame
	parent.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	_check(settings.reduced_flash, "reduced flash survives a whole-Main re-entry")
	pulse.set_auto_advance_enabled(false)
	await _check_reduced(game, fleet[0], glow_ship, pulse, damage, "after whole-Main re-entry")

	# The terminal destruction flash is capped too.
	terminal_damage.present_destruction(Vector3.ZERO)
	var flash := terminal_damage.get("_destruction_flash") as OmniLight3D
	terminal_damage._update_destruction_effects(0.0)
	_check(is_instance_valid(flash) and flash.light_energy <= 4.0,
		"the destruction flash is capped under reduced flash")

	# Turning it back off restores the authored punch.
	settings.reduced_flash = false
	pulse.clear_effects()
	_check(_present_hit(game, fleet[0]), "a pulse shot is accepted after reduced flash turns off")
	_check(_muzzle_light_energy(pulse) > 0.5, "reduced flash off restores the muzzle light")
	_check(_light_swing(damage, "EngineFailureLight") > 0.5,
		"reduced flash off restores the authored engine stutter")
	_check(_engine_glow_swing(glow_ship) > 0.5,
		"reduced flash off restores the failing engine's exhaust stutter")
	pulse.set_auto_advance_enabled(true)
	await _clean_up(game)
	_finish()


func _check_reduced(
		game: GameFlow,
		shooter: HeroShip,
		glow_ship: HeroShip,
		pulse: PulseWeaponPresentation,
		damage: HeroDamagePresentation,
		context: String
	) -> void:
	pulse.clear_effects()
	_check(_present_hit(game, shooter), "a pulse shot is accepted " + context)
	_check(_muzzle_light_energy(pulse) <= 0.0, "a new muzzle flash is unlit " + context)
	pulse.advance_simulation(0.3)
	_check(_impact_light_energy(pulse) <= 0.0, "a new impact flare is unlit " + context)
	pulse.clear_effects()
	var impact := _present_impact(damage)
	_check(impact != null and impact.light_energy <= 2.0, "a new hull-hit light is capped " + context)
	_check(_light_swing(damage, "EngineFailureLight") <= STEADY_TOLERANCE,
		"the failing-engine light holds steady " + context)
	_check(_light_swing(damage, "DamageWarningLight") <= STEADY_TOLERANCE,
		"the damage alarm light holds steady " + context)
	_check(_max_light(damage, "DamageWarningLight") > 0.0,
		"the damage alarm is still lit, only steady, " + context)
	_check(_engine_glow_swing(glow_ship) <= STEADY_TOLERANCE,
		"a failing engine's exhaust light holds steady " + context)
	_check(_spool_glow_swing(glow_ship) <= STEADY_TOLERANCE,
		"the spool-up exhaust light holds steady " + context)
	for path in OPPONENT_PATHS:
		var opponent := game.get_node_or_null(path) as RangeOpponent
		_check(opponent != null and bool(
			opponent.get_weapon_heat_presentation_state().get("reduced_flash", false)
		), "%s receives reduced flash %s" % [path, context])
		var picket := opponent as StandoffPicketOpponent
		if picket != null:
			_check(bool((picket.get_lance_bolt_snapshot().get("presentation", {}) as Dictionary).get("reduced_flash", false)),
				"the picket's lance bolts receive reduced flash " + context)
	var flash := _spawn_opponent_flash(game.get_node_or_null(^"WingSkirmisherLead") as RangeOpponent)
	_check(flash != null and flash.light_energy <= 3.0,
		"a new opponent destruction flash is capped " + context)
	# Leave the hull healthy for the next leg.
	damage.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	await process_frame


## Spawns only the detached destruction art; health and combat are untouched.
func _spawn_opponent_flash(opponent: RangeOpponent) -> OmniLight3D:
	if opponent == null:
		return null
	opponent._spawn_destruction_burst(Vector3.ZERO, opponent.global_transform)
	return opponent.get("_destruction_light") as OmniLight3D


## Peak-to-peak engine-light energy of a critically damaged, online hull.
func _engine_glow_swing(ship: HeroShip) -> float:
	var damage := ship.get_damage_presentation()
	damage.update_state(0.05, HeroDamagePresentation.STATE_ACTIVE)
	ship.set("_engine_state", HeroShip.ENGINE_ONLINE)
	ship.set("_throttle", 1.0)
	var energies: Array[float] = []
	for step in 50:
		damage.set("_elapsed", float(step) * 0.01)
		damage._update_local_cues()
		ship._sync_engine_visuals_immediately()
		energies.append((ship.get("_engine_lights") as Array)[0].light_energy)
	_restore_engine(ship)
	return energies.max() - energies.min()


## Peak-to-peak engine-light energy while the engine spools up.
func _spool_glow_swing(ship: HeroShip) -> float:
	ship.get_damage_presentation().update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	ship.set("_engine_state", HeroShip.ENGINE_STARTING)
	var energies: Array[float] = []
	for step in 50:
		ship.set("_elapsed", float(step) * 0.01)
		ship._update_presentation(0.0, ShipCommand.new())
		energies.append((ship.get("_engine_lights") as Array)[0].light_energy)
	_restore_engine(ship)
	return energies.max() - energies.min()


## Peak-to-peak thrust multiplier a failing engine hands the flight integrator.
func _thrust_swing(ship: HeroShip) -> float:
	var damage := ship.get_damage_presentation()
	damage.update_state(0.05, HeroDamagePresentation.STATE_ACTIVE)
	var values: Array[float] = []
	for step in 50:
		damage.set("_elapsed", float(step) * 0.01)
		damage._update_local_cues()
		values.append(damage.get_engine_power_multiplier())
	damage.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	return values.max() - values.min()


func _restore_engine(ship: HeroShip) -> void:
	ship.get_damage_presentation().update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	ship.set("_engine_state", HeroShip.ENGINE_OFFLINE)
	ship.set("_throttle", 0.0)
	ship._sync_engine_visuals_immediately()


func _present_hit(game: GameFlow, shooter: HeroShip) -> bool:
	var origin := shooter.global_position + Vector3(0.0, 2.0, 0.0)
	return game._present_pulse_shot(origin, origin + Vector3(0.0, 0.0, -30.0), &"cyan", null, true)


func _muzzle_light_energy(pulse: PulseWeaponPresentation) -> float:
	var best := 0.0
	for light in _slot_lights(pulse, "MuzzleLight"):
		if light.visible:
			best = maxf(best, light.light_energy)
	return best


func _impact_light_energy(pulse: PulseWeaponPresentation) -> float:
	var best := 0.0
	for light in _slot_lights(pulse, "ImpactLight"):
		if light.visible:
			best = maxf(best, light.light_energy)
	return best


func _slot_lights(pulse: PulseWeaponPresentation, light_name: String) -> Array[OmniLight3D]:
	var lights: Array[OmniLight3D] = []
	for slot in pulse.get_node(^"PoolRoot").get_children():
		var light := slot.get_node_or_null(light_name) as OmniLight3D
		if light != null:
			lights.append(light)
	return lights


func _present_impact(damage: HeroDamagePresentation) -> OmniLight3D:
	var effects: Array = damage.get("_transient_effects")
	var before := effects.size()
	damage.update_state(1.0, HeroDamagePresentation.STATE_ACTIVE)
	damage.present_impact(damage.global_position, Vector3.UP, 1.6)
	effects = damage.get("_transient_effects")
	if effects.size() <= before:
		return null
	return (effects.back() as Dictionary).get("light") as OmniLight3D


## Peak-to-peak energy of a hull light over half a second of critical damage.
func _light_swing(damage: HeroDamagePresentation, light_name: String) -> float:
	var light := damage.get_node_or_null(light_name) as OmniLight3D
	if light == null:
		return -1.0
	var energies := _sample_critical(damage, light)
	return energies.max() - energies.min()


func _max_light(damage: HeroDamagePresentation, light_name: String) -> float:
	var light := damage.get_node_or_null(light_name) as OmniLight3D
	return _sample_critical(damage, light).max() if light != null else -1.0


func _sample_critical(damage: HeroDamagePresentation, light: OmniLight3D) -> Array[float]:
	damage.update_state(0.05, HeroDamagePresentation.STATE_ACTIVE)
	var energies: Array[float] = []
	for step in 50:
		damage.set("_elapsed", float(step) * 0.01)
		damage._update_local_cues()
		energies.append(light.light_energy)
	return energies


func _clean_up(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	await process_frame


func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)


func _finish() -> void:
	if _failures.is_empty():
		print("REDUCED_FLASH_COMBAT_EFFECTS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error("FAIL: " + failure)
	print("REDUCED_FLASH_COMBAT_EFFECTS_TEST_FAILED (%d/%d)" % [_failures.size(), _assertions])
	quit(1)
