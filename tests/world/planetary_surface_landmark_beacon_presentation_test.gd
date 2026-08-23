extends SceneTree

const BeaconScript := preload("res://scripts/world/planetary_surface_landmark_beacon_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var beacon := BeaconScript.new()
	root.add_child(beacon)
	await process_frame
	var configured := beacon.configure(&"ember_settlement_gate", Vector3(70.0, 120000.0, -10.0))
	var applied := beacon.apply_presentation_recipe({"sun_elevation_sine": -1.0}, {"cloud_opacity_unitless": 0.2})
	var low := beacon.apply_graphics_profile(&"low")
	var detached := beacon.detach()
	var reentered := beacon.reenter()
	var snapshot := beacon.get_snapshot()
	if not configured.accepted or not applied.accepted or not low.accepted \
			or not detached.accepted or not reentered.accepted \
			or snapshot.landmark_id != &"ember_settlement_gate" \
			or snapshot.anchor_body_local_m != Vector3(70.0, 120000.0, -10.0) \
			or not snapshot.visible or snapshot.authority.navigation:
		push_error("landmark beacon presentation lifecycle failed")
		quit(1)
		return
	print("PLANETARY_SURFACE_LANDMARK_BEACON_PRESENTATION_TEST_OK: bounded beacon lifecycle")
	quit(0)
