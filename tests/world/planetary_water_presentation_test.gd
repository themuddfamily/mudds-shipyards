extends SceneTree

const PresentationScript := preload("res://scripts/world/planetary_water_presentation.gd")
const ContractScript := preload("res://scripts/world/planetary_water_surface_material_contract.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var presentation := PresentationScript.new()
	root.add_child(presentation)
	await process_frame
	var configured := presentation.configure(ContractScript.new())
	var applied := presentation.apply_presentation_recipe(
		{"sun_energy_unitless": 0.2},
		{"sky_exposure_unitless": 0.4, "wind_velocity_mps": Vector3(900.0, 0.0, 0.0)}
	)
	var snapshot := presentation.get_snapshot()
	if not configured.accepted or not applied.accepted or snapshot.material_instance_id == 0 \
			or snapshot.recipe.water_color.a != 1.0 or snapshot.authority.physics:
		push_error("water presentation target failed")
		quit(1)
		return
	print("PLANETARY_WATER_PRESENTATION_TEST_OK: exclusive bounded live target")
	quit(0)
