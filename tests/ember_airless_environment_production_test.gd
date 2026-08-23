extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const Store := preload("res://scripts/persistence/user_data_store.gd")
const AirlessEnvironmentPresentation := preload(
	"res://scripts/world/ember_airless_environment_presentation.gd"
)
const STORE_PATH := "memory://ember-airless-environment-settings.json"
const EXPECTED_ASSERTIONS := 13

var _assertions := 0
var _failures := PackedStringArray()


class MemoryFilesystem extends UserDataFilesystem:
	var files: Dictionary = {}

	func file_exists(path: String) -> bool:
		return files.has(path)

	func directory_exists(_path: String) -> bool:
		return false

	func ensure_parent_directory(_path: String) -> Error:
		return OK

	func read_bytes(path: String, maximum_bytes: int) -> Dictionary:
		if not files.has(path):
			return {"error": ERR_FILE_NOT_FOUND, "bytes": PackedByteArray()}
		var bytes := (files[path] as PackedByteArray).duplicate()
		return {
			"error": OK if bytes.size() <= maximum_bytes else ERR_FILE_CORRUPT,
			"bytes": bytes,
		}

	func write_bytes_and_flush(path: String, bytes: PackedByteArray) -> Error:
		files[path] = bytes.duplicate()
		return OK

	func remove_path(path: String) -> Error:
		if not files.has(path):
			return ERR_FILE_NOT_FOUND
		files.erase(path)
		return OK

	func rename_path(from_path: String, to_path: String) -> Error:
		if not files.has(from_path):
			return ERR_FILE_NOT_FOUND
		if files.has(to_path):
			return ERR_ALREADY_EXISTS
		files[to_path] = (files[from_path] as PackedByteArray).duplicate()
		files.erase(from_path)
		return OK


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_continuous_curve_contract()
	var game := MAIN_SCENE.instantiate() as GameFlow
	var store := Store.new(STORE_PATH, MemoryFilesystem.new()) as UserDataStore
	_check(
		game != null and game.configure_runtime_settings_persistence(
			store, "memory://ember-airless-environment-legacy.cfg"
		),
		"production Main instantiates with isolated persistence",
	)
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	await process_frame
	game.set_physics_process(false)

	var bootstrap := game.get_node_or_null(
		^"EmberMoonStreamingBootstrap"
	) as EmberMoonStreamingBootstrap
	var binding := game.get_node_or_null(
		^"EmberMoonStreamingProductionBinding"
	) as EmberMoonStreamingProductionBinding
	var owner := game.get_node_or_null(
		^"CommonWorldOriginRebaseOwner"
	) as CommonWorldOriginRebaseOwner
	var player := game.get_node_or_null(^"Player") as PlayerController
	var world_environment := game.get_node_or_null(
		^"ShipyardWorld/ShipyardEnvironment"
	) as WorldEnvironment
	_check(
		bootstrap != null and binding != null and owner != null and player != null
		and world_environment != null and world_environment.environment != null
		and game.find_children("*", "WorldEnvironment", true, false).size() == 1,
		"production resolves one existing authored Environment and no duplicate",
	)
	if bootstrap == null or binding == null or owner == null or player == null \
			or world_environment == null or world_environment.environment == null:
		await _cleanup(game)
		_finish()
		return

	var environment := world_environment.environment
	var baseline := _owned_values(environment)
	var baseline_background_energy := environment.background_energy_multiplier
	var baseline_sky_id := environment.sky.get_instance_id()
	var baseline_sky_material_id := environment.sky.sky_material.get_instance_id()
	_check(
		not bool(bootstrap.get_snapshot().airless_environment.active)
		and _owned_values(environment) == baseline,
		"unloaded Ember leaves the authored environment at its exact baseline",
	)

	player.global_position = Vector3(0.0, 0.0, -7_880_000.0)
	var first_sample := _sample(player)
	var first_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, first_sample
	)
	var preview := binding.preview_origin_rebase(
		int(first_tick.get("coordinate_frame_generation", 0))
	)
	var first_rebase := owner.consume_rebase_preview(preview, first_sample)
	await _wait_for_environment_presentation(bootstrap)
	var terminator := bootstrap.get_snapshot().airless_environment as Dictionary
	var terminator_presentation := terminator.presentation as Dictionary
	_check(
		bool(first_rebase.get("accepted", false))
		and is_instance_valid(bootstrap.get_loaded_instance())
		and bool(terminator.active)
		and (terminator_presentation.last_result as Dictionary).visual_state \
			== &"airless_terminator"
		and (terminator_presentation.last_result as Dictionary).curve_input_source \
			== &"accepted_sun_horizon_clearance_degrees"
		and bool((terminator_presentation.last_result as Dictionary).continuous_curve)
		and is_equal_approx(
			environment.ambient_light_energy,
			float(baseline.ambient_light_energy) \
				* AirlessEnvironmentPresentation.TERMINATOR_AMBIENT_MULTIPLIER
		)
		and not environment.fog_enabled,
		"the real post-rebase horizon sample produces an airless terminator",
	)

	var day_position := bootstrap.global_position \
		+ Vector3.UP * EmberMoonStreamingBootstrap.BODY_RADIUS_METERS
	player.global_position = day_position
	var day_sample := _sample(player)
	var day_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, day_sample
	)
	var day := bootstrap.get_snapshot().airless_environment as Dictionary
	var day_presentation := day.presentation as Dictionary
	var day_energy := environment.ambient_light_energy
	_check(
		bool(day_tick.get("accepted", false))
		and (day_presentation.last_result as Dictionary).visual_state == &"surface_day"
		and day_energy > float(
			(terminator_presentation.current as Dictionary).ambient_light_energy
		)
		and is_equal_approx(
			float((day_presentation.current as Dictionary).ambient_light_energy),
			float(baseline.ambient_light_energy) \
				* AirlessEnvironmentPresentation.DAY_AMBIENT_MULTIPLIER
		)
		and bool(day_presentation.black_star_field_preserved)
		and int(day_presentation.node_budget) == 0
		and int(day_presentation.resource_budget) == 0,
		"surface daylight raises bounded relative fill without creating resources",
	)

	var day_preview := binding.preview_origin_rebase(2)
	var day_rebase := owner.consume_rebase_preview(day_preview, day_sample)
	var after_generation := bootstrap.get_snapshot().airless_environment as Dictionary
	_check(
		bool(day_rebase.get("accepted", false))
		and int(after_generation.attach_count) == 1
		and int((after_generation.presentation as Dictionary).coordinate_frame_generation) == 3
		and environment.ambient_light_energy == day_energy,
		"a later rebase advances the accepted frame without duplicate environment binding",
	)

	player.global_position = bootstrap.global_position \
		+ Vector3.DOWN * EmberMoonStreamingBootstrap.BODY_RADIUS_METERS
	var night_tick := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(player)
	)
	var night := bootstrap.get_snapshot().airless_environment as Dictionary
	var night_presentation := night.presentation as Dictionary
	_check(
		bool(night_tick.get("accepted", false))
		and (night_presentation.last_result as Dictionary).visual_state \
			== &"surface_night"
		and environment.ambient_light_energy \
			< float((terminator_presentation.current as Dictionary).ambient_light_energy)
		and environment.background_energy_multiplier == baseline_background_energy
		and environment.sky.get_instance_id() == baseline_sky_id
		and environment.sky.sky_material.get_instance_id() \
			== baseline_sky_material_id,
		"airless night darkens surfaces while preserving the exact star field",
	)

	var game_parent := game.get_parent()
	game_parent.remove_child(game)
	await process_frame
	_check(
		_owned_values(environment) == baseline
		and not bool(bootstrap.get_snapshot().airless_environment.active),
		"whole-Main detach restores the exact authored Environment baseline",
	)
	game_parent.add_child(game)
	await process_frame
	await process_frame
	player.global_position = bootstrap.global_position \
		+ Vector3.UP * EmberMoonStreamingBootstrap.BODY_RADIUS_METERS
	var reentered := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(player)
	)
	var reentry := bootstrap.get_snapshot().airless_environment as Dictionary
	_check(
		bool(reentered.get("accepted", false))
		and bool(reentry.active) and int(reentry.attach_count) == 2
		and int(reentry.detach_count) == 1
		and (reentry.presentation.last_result as Dictionary).visual_state \
			== &"surface_day"
		and game.find_children("*", "WorldEnvironment", true, false).size() == 1,
		"re-entry binds once to the same authored Environment without duplication",
	)

	player.global_position = bootstrap.global_position \
		+ Vector3.UP * (EmberMoonStreamingBootstrap.UNLOAD_RADIUS_METERS + 1.0)
	var unload := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(player)
	)
	_check(
		bool(unload.get("accepted", false))
		and bootstrap.get_loaded_instance() == null
		and not bool(bootstrap.get_snapshot().airless_environment.active)
		and _owned_values(environment) == baseline,
		"streamed unload synchronously restores the exact Environment baseline",
	)

	player.global_position = bootstrap.global_position \
		+ Vector3.UP * EmberMoonStreamingBootstrap.BODY_RADIUS_METERS
	var reload := binding.physics_tick_from_caller_sample(
		1.0 / 60.0, _sample(player)
	)
	await _wait_for_environment_presentation(bootstrap)
	var reloaded := bootstrap.get_snapshot().airless_environment as Dictionary
	_check(
		bool(reload.get("accepted", false))
		and bool(reloaded.active) and int(reloaded.attach_count) == 3
		and int(reloaded.detach_count) == 2
		and int((reloaded.presentation as Dictionary).location_generation) == 3
		and (reloaded.presentation.last_result as Dictionary).visual_state \
			== &"surface_day"
		and game.find_children("*", "WorldEnvironment", true, false).size() == 1,
		"streamed reload binds once for the fresh location generation",
	)

	await _cleanup(game)
	_finish()


func _sample(actor: Node3D) -> Dictionary:
	return {
		"available": true,
		"position": actor.global_position,
		"actor_kind": &"player",
		"actor_instance_id": actor.get_instance_id(),
	}


func _test_continuous_curve_contract() -> void:
	var night := AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(
		-AirlessEnvironmentPresentation.TRANSITION_HALF_WIDTH_DEGREES
	)
	var terminator := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(0.0)
	)
	var day := AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(
		AirlessEnvironmentPresentation.TRANSITION_HALF_WIDTH_DEGREES
	)
	_check(
		is_equal_approx(
			float(night.ambient),
			AirlessEnvironmentPresentation.NIGHT_AMBIENT_MULTIPLIER
		)
		and is_equal_approx(
			float(night.sky), AirlessEnvironmentPresentation.NIGHT_SKY_MULTIPLIER
		)
		and is_equal_approx(
			float(terminator.ambient),
			AirlessEnvironmentPresentation.TERMINATOR_AMBIENT_MULTIPLIER
		)
		and is_equal_approx(
			float(terminator.sky),
			AirlessEnvironmentPresentation.TERMINATOR_SKY_MULTIPLIER
		)
		and is_equal_approx(
			float(day.ambient),
			AirlessEnvironmentPresentation.DAY_AMBIENT_MULTIPLIER
		)
		and is_equal_approx(
			float(day.sky), AirlessEnvironmentPresentation.DAY_SKY_MULTIPLIER
		),
		"continuous curve retains the exact night, horizon, and day ceilings",
	)
	var monotonic := true
	var bounded_step := true
	var previous := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(-5.0)
	)
	for index in range(1, 81):
		var clearance := -5.0 + float(index) * 0.125
		var current := (
			AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(
				clearance
			)
		)
		var ambient_delta := float(current.ambient) - float(previous.ambient)
		var sky_delta := float(current.sky) - float(previous.sky)
		monotonic = monotonic and ambient_delta >= 0.0 and sky_delta >= 0.0
		bounded_step = bounded_step \
			and ambient_delta < 0.008 and sky_delta < 0.01
		previous = current
	var epsilon := 0.0001
	var left_horizon := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(-epsilon)
	)
	var right_horizon := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(epsilon)
	)
	var night_inside := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(
			-AirlessEnvironmentPresentation.TRANSITION_HALF_WIDTH_DEGREES + epsilon
		)
	)
	var day_inside := (
		AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(
			AirlessEnvironmentPresentation.TRANSITION_HALF_WIDTH_DEGREES - epsilon
		)
	)
	_check(
		monotonic and bounded_step
		and absf(float(night_inside.ambient) - float(night.ambient)) < epsilon
		and absf(float(night_inside.sky) - float(night.sky)) < epsilon
		and absf(float(left_horizon.ambient) - float(terminator.ambient)) < epsilon
		and absf(float(right_horizon.ambient) - float(terminator.ambient)) < epsilon
		and absf(float(left_horizon.sky) - float(terminator.sky)) < epsilon
		and absf(float(right_horizon.sky) - float(terminator.sky)) < epsilon
		and absf(float(day_inside.ambient) - float(day.ambient)) < epsilon
		and absf(float(day_inside.sky) - float(day.sky)) < epsilon
		and AirlessEnvironmentPresentation.continuous_multipliers_for_clearance(INF).is_empty(),
		"the accepted-clearance response is monotonic, continuous, bounded, and finite-only",
	)


func _wait_for_environment_presentation(
	bootstrap: EmberMoonStreamingBootstrap, maximum_frames := 180
	) -> void:
	for _frame in maximum_frames:
		var snapshot := bootstrap.get_snapshot()
		if is_instance_valid(bootstrap.get_loaded_instance()) \
				and bool((snapshot.airless_environment as Dictionary).active):
			return
		await process_frame


func _owned_values(environment: Environment) -> Dictionary:
	return {
		"ambient_light_energy": environment.ambient_light_energy,
		"ambient_light_sky_contribution": environment.ambient_light_sky_contribution,
		"fog_enabled": environment.fog_enabled,
	}.duplicate(true)


func _cleanup(game: GameFlow) -> void:
	if is_instance_valid(game):
		game.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("EMBER_AIRLESS_ENVIRONMENT_PRODUCTION_TEST_OK: 13 assertions")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
