## test-matrix-network: required
extends "res://tests/game_flow_ember_surface_presentation_integration_test.gd"
## Separate Rime boundary controls contract; reuses the actual two-Main fixture.
## Staged arrival is not canonical travel, shared ice-core survey or return.
func _run() -> void:
	RenderingServer.set_render_loop_enabled(false)
	for scenario in ["rime_session", "rime_scene"]:
		await _test_client_survey_retirement(scenario, &"rime_glacial_world")
		if _hud_setup_failed:
			break
	if _failures.is_empty():
		print("GAME_FLOW_RIME_CLIENT_PAD_CONTROLS_TEST_OK (%d assertions)" % _assertions)
		quit(0)
	else:
		_finish()
