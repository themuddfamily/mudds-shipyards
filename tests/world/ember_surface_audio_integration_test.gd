extends SceneTree

const BindingScript := preload("res://scripts/world/ember_planetary_surface_production_binding.gd")
const DirectorScript := preload("res://scripts/activities/activity_director.gd")

class FakeHost:
	var generation := 4
	var attachment_generation := 1

	func get_generation() -> int: return generation
	func get_attachment_generation() -> int: return attachment_generation
	func get_phase() -> int: return 8
	func get_snapshot() -> Dictionary:
		return {
			"host_id": &"ember_surface_loop",
			"attached": true,
			"phase_id": &"on_foot",
			"identities": {"world_id": &"ember_moon", "player_instance_id": 101},
		}

var _assertions := 0
var _failures := PackedStringArray()
var _hazard_cues: Array[StringName] = []
var _hazard_intensities: Array[float] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := FakeHost.new()
	var director := DirectorScript.new()
	var binding := BindingScript.new()
	root.add_child(director)
	root.add_child(binding)
	await process_frame
	var configured := binding.configure(host, director, Callable(self, "_reward_sink"), 4)
	_check(bool(configured.accepted), "Ember composition configures with audio ownership")
	var playback := binding.get_node("OwnedPlanetarySurfaceAudioBinding")
	playback.semantic_surface_cue_emitted.connect(_on_surface_cue)
	_check(
		bool(binding.set_surface_audio_reduced_dynamic_range(true).accepted),
		"caller reduced-range policy reaches the retained surface playback binding"
	)
	var hazard_observation := {
		"actor_instance_id": 101,
		"delta_seconds": 1.0,
		"exposure_unitless": 1.0,
		"position_body_local_m": Vector3(92.0, 120001.0, -5.0),
		"surface_phase_id": &"on_foot",
	}.duplicate(true)
	var stale_warning := binding.submit_authored_hazard_observation(hazard_observation, 3, 1)
	var warning := binding.submit_authored_hazard_observation(hazard_observation, 4, 1)
	var repeated_warning := binding.submit_authored_hazard_observation(hazard_observation, 4, 1)
	var recovery_observation := hazard_observation.duplicate(true)
	recovery_observation.delta_seconds = 7.0
	var recovery := binding.submit_authored_hazard_observation(recovery_observation, 4, 1)
	var exit_observation := hazard_observation.duplicate(true)
	exit_observation.position_body_local_m = Vector3(112.0, 120001.0, -5.0)
	var clear := binding.submit_authored_hazard_observation(exit_observation, 4, 1)
	var repeated_clear := binding.submit_authored_hazard_observation(exit_observation, 4, 1)
	_check(
		not bool(stale_warning.accepted) and bool(warning.accepted) and bool(repeated_warning.accepted)
			and bool(recovery.accepted) and bool(clear.accepted) and bool(repeated_clear.accepted)
			and _hazard_cues == [
				&"surface_hazard_warning", &"surface_hazard_recovery_required",
				&"surface_hazard_clear",
			]
			and _hazard_intensities.size() == 3
			and _hazard_intensities[0] <= 0.75
			and _hazard_intensities[1] <= 0.75
			and _hazard_intensities[2] <= 0.75,
		"real Relay Arc warning, recovery, and safe-clear edges emit once in reduced range"
	)
	var solar := binding.submit_solar_observation(Vector3.UP, Vector3(0.0, 1.0, 0.0), 1.0)
	var weather := binding.submit_weather_exposure(
		&"caldera_thermal_vent", Vector3(58.0, 120000.0, -4.0),
		0.0, 1.0, 1.0, 0.25, 0.0
	)
	_check(bool(solar.accepted) and bool(weather.accepted), "retained solar/weather snapshots are accepted")
	var audio_snapshot: Dictionary = binding.get_snapshot().surface_audio
	_check(int(audio_snapshot.source_generation) > 0, "audio adapter consumes a fenced environment generation")
	_check(
		(audio_snapshot.binding as Dictionary).voices.size() == 2,
		"production composition retains the two-voice audio ceiling"
	)
	var cues_before_detach := _hazard_cues.size()
	_check(bool(binding.detach().accepted) and _hazard_cues.size() == cues_before_detach, "surface detach clears audio attachment without inventing a hazard-clear cue")
	host.attachment_generation = 2
	_check(bool(binding.reenter().accepted), "surface re-entry restores audio attachment")
	var reentered_warning := binding.submit_authored_hazard_observation(hazard_observation, 4, 2)
	var semantic_hazard := (binding.get_snapshot().surface_audio as Dictionary).binding.semantic_hazard as Dictionary
	_check(
		bool(reentered_warning.accepted)
			and bool((binding.get_snapshot().surface_audio as Dictionary).binding.attached)
			and _hazard_cues.size() == cues_before_detach + 1
			and _hazard_cues.back() == &"surface_hazard_warning",
		"new attachment admits one fresh warning after clearing the old dedupe fence"
	)
	_check(
		bool(semantic_hazard.reduced_dynamic_range)
			and int(semantic_hazard.last_source_generation) == 1
			and not bool(semantic_hazard.authority.hazard)
			and not bool(semantic_hazard.authority.damage)
			and not bool(semantic_hazard.authority.recovery),
		"detached audio state preserves reduced range and owns no hazard gameplay authority"
	)
	for failure in _failures:
		push_error(failure)
	print("ember_surface_audio_integration_test: %d assertions" % _assertions)
	quit(0 if _failures.is_empty() else 1)


func _reward_sink(_receipt: Dictionary) -> Dictionary:
	return {"accepted": true, "reason": &"test_reward"}


func _on_surface_cue(cue_id: StringName, intensity: float) -> void:
	if cue_id.begins_with("surface_hazard_"):
		_hazard_cues.append(cue_id)
		_hazard_intensities.append(intensity)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
