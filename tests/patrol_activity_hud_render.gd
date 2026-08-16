extends SceneTree

## One normal-resolution Forward+ review frame for the patrol travel/dwell copy
## inside the production objective card. This is not a matrix test.

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const OUTPUT_PATH := "/tmp/patrol-activity-hud-forward-plus.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "PatrolActivityHudReview"
	viewport.size = Vector2i(1600, 900)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("07111d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport.add_child(background)
	var hud := HUD_SCENE.instantiate() as GameHUD
	viewport.add_child(hud)
	await process_frame
	hud.set_reduced_motion(true)
	hud.call("_begin")
	await process_frame
	hud.set_mode("piloting")
	hud.set_objective(
		"Free flight — explore, fight, or return to a compatible registered berth",
		"SANDBOX SORTIE"
	)
	hud.set_target_count(0, 3)
	hud.set_activity_objective(ROUTE.display_name, {
		"activity_id": ROUTE.activity_id,
		"activity_kind": &"patrol",
		"state": PatrolActivity.State.ACTIVE,
		"state_id": &"active",
		"phase_id": &"dwell",
		"generation": 1,
		"session_generation": 1,
		"activity_generation": 1,
		"next_checkpoint_index": 2,
		"checkpoint_count": ROUTE.get_checkpoint_count(),
		"completed_checkpoint_count": 2,
		"dwell_elapsed_seconds": 0.8,
		"dwell_remaining_seconds": 1.2,
		"current_time_seconds": 18.4,
		"last_duration_seconds": -1.0,
		"failure_reason": &"",
		"terminal_reason": &"",
	})
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("PATROL_ACTIVITY_HUD_RENDER_FAILED: empty image")
		quit(1)
		return
	if image.save_png(OUTPUT_PATH) != OK:
		push_error("PATROL_ACTIVITY_HUD_RENDER_FAILED: could not save frame")
		quit(1)
		return
	var objective_panel := hud.get("_objective_panel") as Control
	var objective := hud.get("_objective_label") as Label
	var activity := hud.get("_activity_objective_label") as Label
	var targets := hud.get("_target_label") as Label
	var panel_rect := objective_panel.get_global_rect()
	var activity_rect := activity.get_global_rect()
	var target_rect := targets.get_global_rect()
	if (
		activity_rect.intersects(objective.get_global_rect())
		or activity_rect.intersects(target_rect)
		or not panel_rect.encloses(activity_rect)
		or not panel_rect.encloses(target_rect)
	):
		push_error("PATROL_ACTIVITY_HUD_RENDER_FAILED: activity card overlap")
		quit(1)
		return
	print(
		"PATROL_ACTIVITY_HUD_RECTS panel=", panel_rect,
		" objective=", objective.get_global_rect(),
		" activity=", activity_rect,
		" targets=", target_rect
	)
	print(
		"PATROL_ACTIVITY_HUD_RENDER_OK renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" path=", OUTPUT_PATH
	)
	quit(0)
