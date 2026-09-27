class_name CreditsScrollArea
extends ScrollContainer

## A focusable scroll region for the CREDITS page's long, non-interactive text.
##
## Labels cannot take focus, so a stock ScrollContainer can only be scrolled by
## the mouse. While this area has focus, Up/Down (keyboard arrows, D-pad, left
## stick through the default `ui_up`/`ui_down` actions) and Page Up/Down scroll
## it, and the right stick scrolls it continuously. At either end the press is
## left unhandled so ordinary focus navigation moves on to the page's buttons.

const LINE_STEP := 64.0
const STICK_SPEED := 1400.0
const STICK_DEADZONE := 0.25


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	follow_focus = true
	set_process(false)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_FOCUS_ENTER:
			set_process(true)
			queue_redraw()
		NOTIFICATION_FOCUS_EXIT, NOTIFICATION_EXIT_TREE:
			set_process(false)
			queue_redraw()


func _draw() -> void:
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"font_focus_color", &"Button"), false, 2.0)


func max_scroll() -> int:
	var bar := get_v_scroll_bar()
	if bar == null:
		return 0
	return maxi(0, int(bar.max_value - bar.page))


## Scrolls by `pixels`; returns true when the offset actually moved.
func scroll_by(pixels: float) -> bool:
	var before := scroll_vertical
	scroll_vertical = clampi(before + roundi(pixels), 0, max_scroll())
	return scroll_vertical != before


func _gui_input(event: InputEvent) -> void:
	var step := 0.0
	if event.is_action_pressed(&"ui_down", true):
		step = LINE_STEP
	elif event.is_action_pressed(&"ui_up", true):
		step = -LINE_STEP
	elif event.is_action_pressed(&"ui_page_down", true):
		step = size.y * 0.9
	elif event.is_action_pressed(&"ui_page_up", true):
		step = -size.y * 0.9
	if step == 0.0:
		return
	# Consume the press only when it scrolled, so the ends hand focus onwards.
	if scroll_by(step):
		accept_event()


func _process(delta: float) -> void:
	if not has_focus():
		set_process(false)
		return
	var axis := 0.0
	for device: int in Input.get_connected_joypads():
		var value := Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		if absf(value) > absf(axis):
			axis = value
	if absf(axis) < STICK_DEADZONE:
		return
	scroll_by(axis * STICK_SPEED * delta)
