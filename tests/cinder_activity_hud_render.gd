extends SceneTree

## One-frame human-review tool for the compact activity objective inside the
## production HUD scene. This is intentionally not a matrix test.
##
## Usage:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . \
##     --display-driver x11 --rendering-driver vulkan \
##     --script res://tests/cinder_activity_hud_render.gd

const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ROUTE := preload("res://assets/activities/cinder_reach_checkpoint_route.tres")
const OUTPUT_PATH := "/tmp/cinder-activity-hud-forward-plus.png"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var viewport := SubViewport.new()
	viewport.name = "CinderActivityHudReview"
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
		"state": CheckpointRouteActivity.State.ACTIVE,
		"generation": 1,
		"next_checkpoint_index": 0,
		"checkpoint_count": ROUTE.get_checkpoint_count(),
		"failure_reason": &"",
	})
	for _frame in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("CINDER_ACTIVITY_HUD_RENDER_FAILED: empty image")
		quit(1)
		return
	if image.save_png(OUTPUT_PATH) != OK:
		push_error("CINDER_ACTIVITY_HUD_RENDER_FAILED: could not save frame")
		quit(1)
		return
	var objective_panel := hud.get("_objective_panel") as Control
	var objective := hud.get("_objective_label") as Label
	var activity := hud.get("_activity_objective_label") as Label
	var targets := hud.get("_target_label") as Label
	print(
		"CINDER_ACTIVITY_HUD_RECTS panel=", objective_panel.get_global_rect(),
		" objective=", objective.get_global_rect(),
		" activity=", activity.get_global_rect(),
		" targets=", targets.get_global_rect()
	)
	print(
		"CINDER_ACTIVITY_HUD_RENDER_OK renderer=", RenderingServer.get_current_rendering_method(),
		" adapter=", RenderingServer.get_video_adapter_name(),
		" size=", image.get_size(),
		" path=", OUTPUT_PATH
	)
	quit(0)
