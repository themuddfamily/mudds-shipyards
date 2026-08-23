extends SceneTree

const PracticalScript := preload("res://scripts/world/planetary_settlement_practical_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var practical := PracticalScript.new()
	root.add_child(practical)
	await process_frame
	var configured := practical.configure(&"ember_habitat_spine")
	var applied := practical.apply_solar_phase({"state": &"night", "sun_elevation_sine": -1.0})
	var detached := practical.detach()
	var reentered := practical.reenter()
	var snapshot := practical.get_snapshot()
	if not configured.accepted or not applied.accepted or not detached.accepted \
			or not reentered.accepted or not snapshot.visible or snapshot.energy > 1.1001 \
			or snapshot.authority.gameplay:
		push_error("settlement practical presentation lifecycle failed")
		quit(1)
		return
	print("PLANETARY_SETTLEMENT_PRACTICAL_PRESENTATION_TEST_OK: bounded night practical lifecycle")
	quit(0)
