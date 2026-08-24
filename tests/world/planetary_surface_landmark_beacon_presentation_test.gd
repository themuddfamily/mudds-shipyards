extends SceneTree

const BeaconScript := preload("res://scripts/world/planetary_surface_landmark_beacon_presentation.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var beacon := BeaconScript.new()
	var peer_beacon := BeaconScript.new()
	root.add_child(beacon)
	root.add_child(peer_beacon)
	await process_frame
	var initial_snapshot := beacon.get_snapshot()
	var configured := beacon.configure(&"ember_settlement_gate", Vector3(70.0, 120000.0, -10.0))
	var peer_configured := peer_beacon.configure(&"ember_relay_ridge", Vector3(-24.0, 120040.0, 31.0))
	var applied := beacon.apply_presentation_recipe({"sun_elevation_sine": -1.0}, {"cloud_opacity_unitless": 0.2})
	var peer_applied := peer_beacon.apply_presentation_recipe({"sun_elevation_sine": 0.4}, {"cloud_opacity_unitless": 0.0})
	var low := beacon.apply_graphics_profile(&"low")
	var detached := beacon.detach()
	var reentered := beacon.reenter()
	var snapshot := beacon.get_snapshot()
	var peer_snapshot := peer_beacon.get_snapshot()
	var mesh := beacon.get_node("OwnedLandmarkBeacon") as MeshInstance3D
	var peer_mesh := peer_beacon.get_node("OwnedLandmarkBeacon") as MeshInstance3D
	var sphere := mesh.mesh as SphereMesh if mesh != null else null
	var material := mesh.material_override as StandardMaterial3D if mesh != null else null
	var peer_material := peer_mesh.material_override as StandardMaterial3D if peer_mesh != null else null
	if not configured.accepted or not peer_configured.accepted \
			or not applied.accepted or not peer_applied.accepted or not low.accepted \
			or not detached.accepted or not reentered.accepted \
			or initial_snapshot.visible \
			or snapshot.landmark_id != &"ember_settlement_gate" \
			or snapshot.anchor_body_local_m != Vector3(70.0, 120000.0, -10.0) \
			or peer_snapshot.anchor_body_local_m != Vector3(-24.0, 120040.0, 31.0) \
			or not snapshot.visible or not peer_snapshot.visible \
			or not is_equal_approx(snapshot.recipe.intensity_unitless, 0.45) \
			or not is_equal_approx(peer_snapshot.recipe.intensity_unitless, 0.35) \
			or snapshot.authority != {"navigation": false, "activity": false, "movement": false, "clock": false} \
			or mesh == null or peer_mesh == null or sphere == null \
			or mesh.mesh != peer_mesh.mesh \
			or not is_equal_approx(sphere.radius, 0.8) or not is_equal_approx(sphere.height, 1.6) \
			or material == null or peer_material == null or material == peer_material \
			or material.emission != Color(0.15, 0.45, 1.0, 1.0) \
			or peer_material.emission != Color(0.15, 0.45, 1.0, 1.0) \
			or not is_equal_approx(material.emission_energy_multiplier, 0.45) \
			or not is_equal_approx(peer_material.emission_energy_multiplier, 0.35):
		push_error("landmark beacon presentation lifecycle failed")
		quit(1)
		return
	print("PLANETARY_SURFACE_LANDMARK_BEACON_PRESENTATION_TEST_OK: hidden initial frame, shared geometry, isolated recipes, bounded lifecycle")
	quit(0)
