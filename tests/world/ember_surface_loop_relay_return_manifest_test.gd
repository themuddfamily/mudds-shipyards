extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const ManifestScript := preload("res://scripts/world/ember_relay_survey_return_manifest.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BindingScript.new()
	var manifest := ManifestScript.new()
	var not_ready := manifest.issue(
		{"state": &"active", "activity_generation": 17}, 4
	)
	var issued := manifest.issue(
		{"state": &"completed", "activity_generation": 17}, 4
	)
	var duplicate := manifest.issue(
		{"state": &"awaiting_reward", "activity_generation": 17}, 5
	)
	var next_generation := manifest.issue(
		{"state": &"completed", "activity_generation": 18}, 5
	)
	var payload: Dictionary = issued.get("manifest", {})
	var reset := manifest.reset()
	var snapshot := manifest.get_snapshot()
	var valid: bool = not not_ready.accepted and issued.accepted and not duplicate.accepted \
			and next_generation.accepted and reset.accepted \
			and payload.destination_id == &"mudds_shipyards" \
			and payload.activity_id == &"ember_beacon_survey" \
			and payload.objective_id == &"survey_beacon_network" \
			and payload.reward_id == &"ember_beacon_data" \
			and payload.return_incentive_id == &"return_beacon_data_to_shipyard" \
			and payload.recovery_id == &"return_to_landed_ship" \
			and payload.recovery_authority_id == &"planetary_landing_return_contract" \
			and payload.attachment_generation == 4 \
			and not payload.movement_authority \
			and not payload.berth_authority \
			and not payload.reward_authority \
			and snapshot.issued_generation == -1 \
			and binding.has_method(&"issue_planetary_relay_survey_return_manifest") \
			and binding.has_method(&"reset_planetary_relay_survey_return_manifest")
	if not valid:
		push_error("relay survey return manifest failed")
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_RELAY_RETURN_MANIFEST_TEST_OK: fenced caller-routed home intent")
	quit(0)
