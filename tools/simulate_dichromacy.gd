extends SceneTree

## Design-time review tool (not part of the test glob). Re-renders captured
## evidence frames through the Viénot 1999 dichromat simulation that lives in
## tests/fleet_colour_metrics.gd, so the frames can be judged by eye the way a
## dichromat would see them rather than only by a cleared threshold.

const ColourMetrics := preload("res://tests/fleet_colour_metrics.gd")

const SOURCE_DIR := "res://artifacts/berth_feedback"
const OUTPUT_DIR := "res://artifacts/berth_feedback/dichromacy"
const REVIEW_WIDTH := 1024


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var names := PackedStringArray()
	var directory := DirAccess.open(SOURCE_DIR)
	for file_name in directory.get_files():
		if file_name.ends_with(".png"):
			names.append(file_name)
	names.sort()
	for file_name in names:
		var image := Image.load_from_file("%s/%s" % [SOURCE_DIR, file_name])
		if image == null:
			continue
		var height := int(round(float(REVIEW_WIDTH) * float(image.get_height()) / float(image.get_width())))
		image.resize(REVIEW_WIDTH, height, Image.INTERPOLATE_LANCZOS)
		for mode: String in ColourMetrics.VISION_MODELS:
			if mode == "normal":
				image.save_png("%s/normal_%s" % [OUTPUT_DIR, file_name])
				continue
			var simulated := Image.create_empty(REVIEW_WIDTH, height, false, image.get_format())
			for y in height:
				for x in REVIEW_WIDTH:
					var source := image.get_pixel(x, y)
					var linear := ColourMetrics.simulate(
						Vector3(
							ColourMetrics.srgb_component_to_linear(source.r),
							ColourMetrics.srgb_component_to_linear(source.g),
							ColourMetrics.srgb_component_to_linear(source.b)
						),
						mode
					)
					simulated.set_pixel(
						x,
						y,
						Color(
							clampf(linear.x, 0.0, 1.0),
							clampf(linear.y, 0.0, 1.0),
							clampf(linear.z, 0.0, 1.0)
						).linear_to_srgb()
					)
			simulated.save_png("%s/%s_%s" % [OUTPUT_DIR, mode, file_name])
		print("SIMULATED: ", file_name)
	print("DICHROMACY_SIMULATION_OK")
	quit(0)
