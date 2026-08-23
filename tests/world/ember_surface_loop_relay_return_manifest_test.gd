extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")
const ManifestScript := preload("res://scripts/world/ember_relay_survey_return_manifest.gd")
const TravelAdapterScript := preload("res://scripts/world/ember_relay_survey_return_travel_adapter.gd")
const TravelSessionScript := preload("res://scripts/world/planetary_travel_session.gd")
const ReturnContractScript := preload("res://scripts/world/planetary_landing_return_contract.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var binding := BindingScript.new()
	var manifest := ManifestScript.new()
	var travel := TravelAdapterScript.new()
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
	var wrong_manifest := issued.duplicate(true)
	(wrong_manifest.manifest as Dictionary).destination_id = &"wrong_destination"
	var wrong_destination := travel.consume(wrong_manifest, 101, 202, 4)
	var intent := travel.consume(issued, 101, 202, 4)
	var duplicate_intent := travel.consume(issued, 101, 202, 4)
	var detached := travel.detach()
	var reentered := travel.reenter(5)
	var retained_duplicate := travel.consume(issued, 101, 202, 5)
	var aborted := travel.abort()
	var travel_reset := travel.reset()
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
			and intent.accepted and not duplicate_intent.accepted \
			and not wrong_destination.accepted \
			and intent.intent.actor_instance_id == 101 \
			and intent.intent.craft_instance_id == 202 \
			and intent.intent.destination_id == &"mudds_shipyards" \
			and detached.accepted and reentered.accepted \
			and not retained_duplicate.accepted and aborted.accepted \
			and travel_reset.accepted \
			and binding.has_method(&"issue_planetary_relay_survey_return_manifest") \
			and binding.has_method(&"reset_planetary_relay_survey_return_manifest") \
			and binding.has_method(&"consume_planetary_relay_survey_return") \
			and binding.has_method(&"submit_planetary_return_reboard") \
			and binding.has_method(&"submit_planetary_return_takeoff") \
			and binding.has_method(&"submit_planetary_return_ascent") \
			and binding.has_method(&"submit_planetary_return_orbit") \
			and binding.has_method(&"prepare_planetary_return_approach") \
			and binding.has_method(&"admit_planetary_return_contract_approach") \
			and binding.has_method(&"confirm_planetary_return_arrival_ready") \
			and TravelSessionScript.new().has_method(&"admit_return_travel_intent") \
			and TravelSessionScript.new().has_method(&"submit_authorized_return_reboard") \
			and TravelSessionScript.new().has_method(&"submit_authorized_return_orbit") \
			and TravelSessionScript.new().has_method(&"prepare_return_approach") \
			and TravelSessionScript.new().has_method(&"admit_return_contract_approach") \
			and TravelSessionScript.new().has_method(&"confirm_return_arrival_ready") \
			and ReturnContractScript.new().has_method(&"confirm_orbit_arrival_ready")
	if not valid:
		push_error("relay survey return manifest failed")
		binding.free()
		manifest = null
		travel = null
		await process_frame
		quit(1)
		return
	print("EMBER_SURFACE_LOOP_RELAY_RETURN_MANIFEST_TEST_OK: fenced caller-routed home intent")
	binding.free()
	manifest = null
	travel = null
	await process_frame
	quit(0)
