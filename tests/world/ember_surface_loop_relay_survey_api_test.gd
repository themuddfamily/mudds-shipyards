extends SceneTree

const BindingScript := preload("res://scripts/world/ember_surface_loop_production_binding.gd")

func _init() -> void:
	var binding := BindingScript.new()
	var methods := [
		&"start_planetary_relay_survey",
		&"submit_planetary_relay_survey_position",
		&"submit_planetary_relay_survey_landmark",
		&"commit_planetary_relay_survey_reward",
	]
	for method in methods:
		if not binding.has_method(method):
			push_error("missing production relay survey method: %s" % method)
			quit(1)
			return
	print("EMBER_SURFACE_LOOP_RELAY_SURVEY_API_TEST_OK: host relay survey forwards exposed")
	quit(0)
