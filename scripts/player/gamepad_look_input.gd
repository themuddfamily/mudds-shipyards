extends RefCounted

## Held standard right-stick intent for one local camera owner. Events, rather
## than global axis polling, make a handoff discard the previous owner's hold.
const ANGULAR_SPEED := 2.5
const DEADZONE := 0.2

var _axes := Vector2.ZERO
var _device := -1
var _application_focused := true
var _viewport: Viewport


func attach(viewport: Viewport) -> void:
	clear()
	_viewport = viewport
	_application_focused = DisplayServer.get_name() == "headless" \
		or Window.get_focused_window() != null
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)
	if not _viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		_viewport.gui_focus_changed.connect(_on_gui_focus_changed)


func detach() -> void:
	clear()
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if is_instance_valid(_viewport) \
			and _viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		_viewport.gui_focus_changed.disconnect(_on_gui_focus_changed)
	_viewport = null


func clear() -> void:
	_axes = Vector2.ZERO
	_device = -1


func handle_notification(what: int) -> void:
	if what == Node.NOTIFICATION_PAUSED or what == Node.NOTIFICATION_UNPAUSED:
		clear()
	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
		_application_focused = false
		clear()
	elif what == MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == MainLoop.NOTIFICATION_APPLICATION_RESUMED:
		_application_focused = true
		clear()


func observe(event: InputEvent, owner_active: bool) -> void:
	if not _can_look(owner_active):
		clear()
		return
	if event is not InputEventJoypadMotion:
		return
	var motion := event as InputEventJoypadMotion
	if motion.axis != JOY_AXIS_RIGHT_X and motion.axis != JOY_AXIS_RIGHT_Y:
		return
	if not is_finite(motion.axis_value):
		clear()
		return
	if motion.device != _device:
		clear()
		_device = motion.device
	if motion.axis == JOY_AXIS_RIGHT_X:
		_axes.x = clampf(motion.axis_value, -1.0, 1.0)
	else:
		_axes.y = clampf(motion.axis_value, -1.0, 1.0)


func angular_step(delta: float, owner_active: bool) -> Vector2:
	if not _can_look(owner_active):
		clear()
		return Vector2.ZERO
	if not is_finite(delta) or delta <= 0.0:
		return Vector2.ZERO
	var magnitude := _axes.length()
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	# Radial response preserves direction and caps diagonals at the authored
	# angular speed; the remaining travel starts continuously at the deadzone.
	var strength := (minf(magnitude, 1.0) - DEADZONE) / (1.0 - DEADZONE)
	return _axes / magnitude * strength * ANGULAR_SPEED * delta


func _can_look(owner_active: bool) -> bool:
	if not owner_active or not _application_focused or not is_instance_valid(_viewport):
		return false
	var focused := _viewport.gui_get_focus_owner()
	return focused == null or focused.is_in_group(&"gameplay_input_passthrough")


func _on_gui_focus_changed(focused: Control) -> void:
	if focused != null and not focused.is_in_group(&"gameplay_input_passthrough"):
		clear()


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if not connected and device == _device:
		clear()
