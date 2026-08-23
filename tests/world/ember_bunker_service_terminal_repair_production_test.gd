extends SceneTree

const BindingScript := preload(
	"res://scripts/world/ember_planetary_surface_production_binding.gd"
)
const DirectorScript := preload("res://scripts/activities/activity_director.gd")
const RELAY_ANCHOR := Vector3(180.0, 120009.0, -44.0)
const RETURN_ANCHOR := Vector3(540.0, 120030.0, -210.0)

class FakeHost:
	var generation := 55
	var attachment_generation := 1
	var player_instance_id := 0
	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop", "attached": true,
			"phase_id": &"on_foot",
			"identities": {
				"world_id": &"ember_moon",
				"player_instance_id": player_instance_id,
			},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _reward_calls := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate() as GameFlow if packed != null else null
	_check(game != null, "the real GameFlow scene instantiates")
	if game == null:
		_finish()
		return
	root.add_child(game)
	await process_frame
	await physics_frame
	var player := game.player as PlayerController
	var craft := game.active_ship as HeroShip
	game.process_mode = Node.PROCESS_MODE_DISABLED
	craft.set_physics_process(false)
	craft.set("_landed", true)
	craft.set("_landing_active", false)
	craft.set("_destroyed", false)
	game.set("_piloting", false)
	game.ships = [craft]

	var host := FakeHost.new()
	host.player_instance_id = player.get_instance_id()
	var director := DirectorScript.new()
	root.add_child(director)
	var binding := BindingScript.new() as Node
	root.add_child(binding)
	await process_frame
	var configured := binding.call(
		&"configure", host, director, Callable(self, "_reward_sink"), 55,
		Callable(game, "_commit_ember_service_terminal_repair")
	) as Dictionary
	var interaction := binding.get_node("OwnedSurveyBunkerInteraction")
	player.global_position = interaction.global_position
	craft.global_position = interaction.global_position + Vector3(25.0, 0.0, 0.0)
	var model := craft.get_component_damage()
	var damaged_component := _damage_one_component(craft)
	var integrity_before := model.get_component_integrity(damaged_component)
	_check(
		bool(configured.accepted) and not damaged_component.is_empty()
			and integrity_before < 1.0,
		"production GameFlow, bunker, player, and one damaged Hero component are live"
	)

	var started := binding.call(&"start_relay_survey") as Dictionary
	var survey_logged := interaction.call(
		&"submit_interaction", player, 55, 1
	) as Dictionary
	var unlocked := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(started.accepted) and bool(survey_logged.accepted)
			and bool(unlocked.relay_survey.optional_checkpoint.completed)
			and bool(unlocked.survey_interaction.service_terminal.available)
			and int(unlocked.survey_interaction.service_terminal.terminal_generation) == 1
			and unlocked.survey_interaction.prompt \
				== "[ E ]  SERVICE NEARBY LANDED CRAFT",
		"only the accepted current optional checkpoint unlocks the physical terminal"
	)

	craft.set("_landed", false)
	var airborne := bool(interaction.call(&"interact", player))
	var airborne_snapshot := interaction.call(&"get_snapshot") as Dictionary
	craft.set("_landed", true)
	craft.global_position = interaction.global_position + Vector3(49.0, 0.0, 0.0)
	var distant := bool(interaction.call(&"interact", player))
	var distant_snapshot := interaction.call(&"get_snapshot") as Dictionary
	_check(
		not airborne
			and airborne_snapshot.service_terminal.status == &"service_craft_not_landed"
			and not distant
			and distant_snapshot.service_terminal.status == &"service_target_out_of_range"
			and int(distant_snapshot.service_terminal.request_sequence) == 2
			and is_equal_approx(model.get_component_integrity(damaged_component), integrity_before),
		"airborne and out-of-range craft evidence cannot mutate the component"
	)

	craft.global_position = interaction.global_position + Vector3(25.0, 0.0, 0.0)
	var serviced := bool(interaction.call(&"interact", player))
	var integrity_after := model.get_component_integrity(damaged_component)
	var serviced_snapshot := interaction.call(&"get_snapshot") as Dictionary
	var service_receipt := serviced_snapshot.service_terminal.last_receipt as Dictionary
	_check(
		serviced and integrity_after > integrity_before
			and integrity_after <= integrity_before + 0.200001
			and bool(serviced_snapshot.service_terminal.consumed)
			and serviced_snapshot.service_terminal.status == &"repair_applied"
			and serviced_snapshot.service_terminal.status_text \
				== "COMPONENT SERVICE APPLIED"
			and serviced_snapshot.prompt \
				== "[ COMPLETE ]  CRAFT COMPONENT SERVICED"
			and service_receipt.component_id == damaged_component
			and service_receipt.authority_path == &"repair_authority_component_adapter"
			and int(service_receipt.request_sequence) == 3,
		"GameFlow selects one component and the retained authority applies one pulse"
	)
	var replay := interaction.call(
		&"submit_service_repair", player, 55, 1, 1
	) as Dictionary
	_check(
		not bool(replay.accepted)
			and replay.reason == &"service_terminal_already_consumed"
			and is_equal_approx(model.get_component_integrity(damaged_component), integrity_after),
		"the consumed terminal cannot replay its repair transaction"
	)

	var relay := binding.call(
		&"submit_relay_survey_position", RELAY_ANCHOR
	) as Dictionary
	var returned := binding.call(
		&"submit_relay_survey_position", RETURN_ANCHOR
	) as Dictionary
	var reward := binding.call(&"commit_relay_survey_reward") as Dictionary
	var completed_session := binding.call(&"get_session_snapshot") as Dictionary
	var detached := binding.call(&"detach") as Dictionary
	var hidden := binding.call(&"get_snapshot") as Dictionary
	host.attachment_generation = 2
	var reentered := binding.call(&"reenter") as Dictionary
	var session_restored := binding.call(
		&"restore_session_snapshot", completed_session
	) as Dictionary
	var retained := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(relay.accepted) and bool(returned.accepted) and bool(reward.accepted)
			and bool(detached.accepted) and hidden.survey_interaction.prompt.is_empty()
			and bool(reentered.accepted) and bool(session_restored.accepted)
			and bool(retained.survey_interaction.service_terminal.consumed)
			and retained.survey_interaction.prompt \
				== "[ COMPLETE ]  CRAFT COMPONENT SERVICED",
		"detach hides the terminal and same-generation re-entry retains consumption"
	)
	var next_run := binding.call(&"start_relay_survey") as Dictionary
	var reset := binding.call(&"get_snapshot") as Dictionary
	_check(
		bool(next_run.accepted)
			and int(reset.relay_survey.optional_checkpoint.current_activity_generation) == 2
			and not bool(reset.relay_survey.optional_checkpoint.completed)
			and int(reset.survey_interaction.service_terminal.terminal_generation) == -1
			and not bool(reset.survey_interaction.service_terminal.available)
			and _reward_calls == 1,
		"a newer activity generation clears the old service terminal without reward replay"
	)

	binding.queue_free()
	director.queue_free()
	game.queue_free()
	await process_frame
	_finish()


func _damage_one_component(craft: HeroShip) -> StringName:
	var model := craft.get_component_damage()
	var report := model.get_component_report()
	var components := report.get("components", []) as Array
	if components.is_empty():
		return &""
	var target := components[0] as Dictionary
	model.record_damage(
		craft.maximum_hull * 1.5,
		target.get("local_position", Vector3.ZERO) as Vector3
	)
	var selected := &""
	var integrity := 1.0
	for component_value in model.get_component_report().components as Array:
		var component := component_value as Dictionary
		if float(component.integrity) < integrity:
			selected = StringName(component.id)
			integrity = float(component.integrity)
	return selected


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	_reward_calls += 1
	return {"accepted": true, "reason": &"test_reward_committed"}


func _finish() -> void:
	for failure in _failures:
		push_error(failure)
	print(
		"EMBER_BUNKER_SERVICE_TERMINAL_REPAIR_PRODUCTION_TEST_OK: %d assertions"
		% _assertions
	)
	quit(0 if _failures.is_empty() else 1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
