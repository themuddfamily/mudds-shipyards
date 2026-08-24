extends SceneTree

const PresenterType := preload("res://scripts/ui/semantic_audio_cue_presenter.gd")
const HudType := preload("res://scripts/ui/hud.gd")

var _assertions := 0
var _failures: PackedStringArray = []


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var presenter := PresenterType.new()
	var position := Vector3(4.0, 2.0, -8.0)
	var accepted := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(bool(accepted.get("accepted", false)), "registered cue is accepted")
	_check(accepted.get("caption") == "Heavy hull impact", "cue maps to concise caption")
	_check(accepted.get("severity_marker") == "!", "severity has a non-colour shape marker")
	_check(accepted.get("world_position") == position, "world position is preserved for caller layout")
	var duplicate := presenter.present_cue(&"hull_impact_heavy", &"defender", 0.9, position)
	_check(duplicate.get("reason") == &"duplicate_cue", "identical cue is deduplicated")
	var weapon_caption_contracts := {
		&"siege_lance_fire_heavy": ["Siege lance discharge", &"high"],
		&"siege_lance_impact_heavy": ["Siege lance impact", &"high"],
		&"tail_turret_fire_broad": ["Tail turret fires", &"medium"],
		&"tail_turret_impact_broad": ["Tail turret impact", &"medium"],
		&"repeater_fire_light": ["Repeater burst", &"low"],
		&"repeater_impact_light": ["Repeater impact", &"low"],
	}
	var weapon_index := 0
	for cue_id: StringName in weapon_caption_contracts:
		var contract := weapon_caption_contracts[cue_id] as Array
		var source_id := StringName("hostile_source_%d" % weapon_index)
		var direction := "rear-left" if weapon_index % 2 == 0 else "forward-right"
		var weapon_caption := presenter.present_cue(
			cue_id,
			source_id,
			0.7 if contract[1] != &"high" else 0.9,
			position + Vector3(float(weapon_index), 0.0, 0.0),
			{"direction": direction, "distance_m": 80.0 + weapon_index, "tick": weapon_index + 1}
		)
		_check(
			bool(weapon_caption.accepted)
			and weapon_caption.caption == contract[0]
			and weapon_caption.severity == contract[1]
			and weapon_caption.source == source_id
			and weapon_caption.direction == direction
			and weapon_caption.distance_band == &"mid",
			"%s maps to its concise caption with source, direction, and distance context" % cue_id
		)
		weapon_index += 1
	_check(
		presenter.get_transcript(20).size() <= SemanticAudioCuePresenter.MAX_TRANSCRIPT_ENTRIES,
		"derived weapon cues retain the existing bounded caption transcript"
	)
	var generic_fallback := presenter.present_cue(
		&"hull_impact_medium", &"generic_combat", 0.6, position + Vector3.UP
	)
	_check(
		bool(generic_fallback.accepted) and generic_fallback.caption == "Hull impact detected",
		"generic combat caption mappings remain available beside weapon-specific cues"
	)
	var engineer_repair_captions := {
		&"crew_engineer_repair_started": "Engineer repair started",
		&"crew_engineer_repair_progress": "Engineer repair progressing",
		&"crew_engineer_repair_interrupted": "Engineer repair interrupted",
		&"crew_engineer_repair_completed": "Engineer repair complete",
	}
	for cue_id: StringName in engineer_repair_captions:
		var repair_caption := presenter.present_cue(
			cue_id, &"Jovian engineer", 0.65, position,
			{"transition_id": String(cue_id)}
		)
		_check(
			bool(repair_caption.get("accepted", false))
				and repair_caption.get("caption", "") == engineer_repair_captions[cue_id],
			"%s has a truthful semantic repair caption" % cue_id
		)
	for cue_id in [
		&"station_defense_wave_started", &"station_defense_asset_danger", &"station_defense_asset_critical",
		&"station_defense_completed", &"station_defense_aborted", &"cargo_transfer_pickup_accepted",
		&"cargo_transfer_destination_delivered", &"cargo_transfer_rejected", &"cargo_transfer_activity_completed",
		&"cargo_transfer_aborted", &"planetary_orbit_approach", &"planetary_atmospheric_entry",
		&"planetary_landed", &"planetary_takeoff", &"planetary_ascent", &"planetary_orbit_return",
		&"planetary_returned_to_station"
	]:
		_check(cue_id in presenter.get_registered_cue_ids(), "%s is registered for captions" % cue_id)
	var metadata_cue := presenter.present_cue(
		&"cargo_transfer_rejected", &"cargo", 0.8, position,
		{"direction": "from port", "priority": 83}
	)
	_check(metadata_cue.get("direction") == "from port", "caller direction metadata is preserved")
	_check(metadata_cue.get("priority") == 83, "caller priority metadata is preserved")
	var no_metadata := presenter.present_cue(&"planetary_takeoff", &"flight", 0.5, position)
	_check(not no_metadata.has("direction") and not no_metadata.has("priority"), "unsupplied metadata stays absent")
	_check(
		presenter.get_transcript(20).size() == SemanticAudioCuePresenter.MAX_TRANSCRIPT_ENTRIES,
		"mixed generic and weapon captions still enforce the exact eight-entry transcript cap"
	)
	var hud := HudType.new()
	var requests: Array[Dictionary] = []
	hud.set_captions_enabled(true)
	hud.set_reduced_flash(true)
	hud.bind_caption_event_submitter(Callable(self, "_capture_request").bind(requests))
	_check(
		hud.present_semantic_audio_cue(
			&"siege_lance_fire_heavy", &"picket", 0.9, position,
			{"direction": "from port", "priority": 88}
		),
		"reduced-flash mode retains the siege-lance caption and caller metadata"
	)
	_check(str(requests[0].get("text", "")).ends_with("// from port"), "direction is readable in caption text")
	_check(str(requests[0].get("speaker", "")) == "picket", "source identity is readable as the caption speaker")
	_check(int(requests[0].get("priority", 0)) == 88, "caller priority controls caption priority")
	hud.set_captions_enabled(false)
	_check(
		not hud.present_semantic_audio_cue(
			&"repeater_fire_light", &"skirmisher", 0.5, position
		)
		and requests.size() == 1,
		"caption preference still gates derived weapon cues before queue submission"
	)
	hud.free()
	var unknown := presenter.present_cue(&"untrusted_cue", &"defender", 1.0, position)
	_check(unknown.get("reason") == &"unregistered_cue", "unregistered cue is rejected")
	if _failures.is_empty():
		print("SEMANTIC_AUDIO_CUE_PRESENTER_TEST_OK (%d assertions)" % _assertions)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append("FAIL: " + message)


func _capture_request(request: Dictionary, requests: Array[Dictionary]) -> bool:
	requests.append(request.duplicate(true))
	return true
