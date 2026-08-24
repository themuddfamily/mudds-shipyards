extends SceneTree

const PracticalScript := preload("res://scripts/world/planetary_settlement_practical_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var practical := PracticalScript.new()
	root.add_child(practical)
	await process_frame
	var configured := practical.configure(&"ember_habitat_spine")
	var applied := practical.apply_solar_phase({"state": &"night", "sun_elevation_sine": -1.0, "sequence": 1})
	var first_snapshot := practical.get_snapshot()
	var repeated := practical.apply_solar_phase({"state": &"night", "sun_elevation_sine": -1.0, "sequence": 2})
	var repeated_snapshot := practical.get_snapshot()
	var detached := practical.detach()
	var reentered := practical.reenter()
	var snapshot := practical.get_snapshot()
	var authored_light := practical.get_node_or_null("OwnedSettlementPractical") as OmniLight3D
	if not configured.accepted or not applied.accepted or not repeated.accepted or not detached.accepted \
			or not reentered.accepted or not snapshot.visible or not is_equal_approx(snapshot.energy, 1.1) \
			or authored_light == null or authored_light.light_color != Color(1.0, 0.75, 0.55, 1.0) \
			or snapshot.authority.gameplay \
			or first_snapshot.light_property_submission_count != 3 \
			or repeated_snapshot.light_property_submission_count != first_snapshot.light_property_submission_count \
			or repeated_snapshot.last_solar.sequence != 2 \
			or snapshot.light_property_submission_count != first_snapshot.light_property_submission_count + 2:
		push_error("settlement practical presentation lifecycle failed: first=%s repeated=%s final=%s" % [first_snapshot, repeated_snapshot, snapshot])
		quit(1)
		return
	print("PLANETARY_SETTLEMENT_PRACTICAL_PRESENTATION_TEST_OK: repeated target 3 -> 0 light property submissions; bounded lifecycle restored")
	quit(0)
