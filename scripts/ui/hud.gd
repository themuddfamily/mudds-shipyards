class_name GameHUD
extends CanvasLayer

const FlightPathCueType := preload("res://scripts/ui/flight_path_cue.gd")

signal start_requested
signal restart_requested
signal setting_change_requested(key: StringName, value: Variant)
signal settings_save_requested
signal settings_reset_requested

const INK := Color("07111d")
const PANEL := Color("101c2bd9")
const PANEL_SOLID := Color("0c1724")
const CYAN := Color("62e6ef")
const CYAN_SOFT := Color("a9f7f5")
const AMBER := Color("ffb85c")
const RED := Color("ff6b64")
const WHITE := Color("edfaff")
const MUTED := Color("87a8b5")

var _root: Control
var _intro: Control
var _hud: Control
var _pause: Control
var _pause_main_page: Control
var _settings_page: Control
var _settings_controls: Dictionary = {}
var _settings_value_labels: Dictionary = {}
var _settings_status_label: Label
var _updating_settings := false
var _objective_label: Label
var _objective_kicker: Label
var _interaction_panel: PanelContainer
var _interaction_label: Label
var _mode_label: Label
var _engine_label: Label
var _speed_label: Label
var _altitude_label: Label
var _throttle_label: Label
var _throttle_bar: ProgressBar
var _hull_bar: ProgressBar
var _damage_status_label: Label
var _telemetry_panel: PanelContainer
var _target_label: Label
var _enemy_panel: PanelContainer
var _enemy_name_label: Label
var _enemy_health_bar: ProgressBar
var _enemy_status_label: Label
var _damage_flash: ColorRect
var _damage_direction: Label
var _damage_tween: Tween
var _toast_panel: PanelContainer
var _toast_title: Label
var _toast_detail: Label
var _help_panel: PanelContainer
var _reticle: Control
var _flight_cue_layer: FlightPathCue
var _toast_serial := 0
var _toast_tween: Tween
var _started := false
var _active_ship_name := "TORRENT-CLASS INTERCEPTOR"
var _active_ship_role := "INTERCEPTOR"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_interface()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _started and (event.is_action_pressed("interact") or event.is_action_pressed("jump")):
		_begin()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and _started:
		if _pause.visible and _settings_page != null and _settings_page.visible:
			_show_pause_main()
		else:
			set_paused(not _pause.visible)
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1 and _started:
		_help_panel.visible = not _help_panel.visible


func show_intro() -> void:
	_started = false
	_intro.visible = true
	_hud.visible = false
	_pause.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_mode(mode: String) -> void:
	var piloting := mode.to_lower().contains("pilot")
	_mode_label.text = "PILOTING  //  %s" % _active_ship_name if piloting else "ON FOOT  //  REGENERATION DECK"
	_mode_label.modulate = AMBER if piloting else CYAN
	_telemetry_panel.visible = piloting
	_reticle.visible = piloting
	if _flight_cue_layer != null:
		_flight_cue_layer.set_piloting(piloting)
	if piloting:
		_set_help_text([
			["Y", "START ENGINES"], ["W / S", "FORWARD / REVERSE"],
			["MOUSE", "STEER"], ["UP / DOWN", "PITCH"], ["A / D", "YAW"],
			["Q / R", "ROLL"], ["F / LMB", "FIRE"],
			["SHIFT / CTRL/RMB", "BOOST / BRAKE"], ["V / WHEEL", "VIEW / DISTANCE"],
			["H / G", "HOVER / BARREL ROLL"], ["L", "LANDING ASSIST"],
			["X", "STOP ENGINES"], ["E", "EXIT: LANDED + OFFLINE"],
			["GAMEPAD", "STICKS FLY / TRIGGERS + FACE"]
		])
	else:
		_set_help_text([
			["W A S D", "MOVE"], ["MOUSE", "LOOK"], ["SHIFT", "SPRINT"],
			["SPACE", "JUMP"], ["E", "INTERACT / BOARD"], ["F1", "CONTROLS"]
		])


func set_ship_identity(display_name: String, role: String = "") -> void:
	_active_ship_name = display_name.strip_edges().to_upper()
	if _active_ship_name.is_empty():
		_active_ship_name = "SPACECRAFT"
	_active_ship_role = role.strip_edges().to_upper()
	if _mode_label != null and _telemetry_panel != null and _telemetry_panel.visible:
		_mode_label.text = "PILOTING  //  %s" % _active_ship_name
	else:
		_set_help_text([
			["W A S D", "MOVE"], ["MOUSE", "LOOK"], ["SHIFT", "SPRINT"],
			["SPACE", "JUMP"], ["E", "INTERACT / BOARD"], ["F1", "CONTROLS"]
		])


func set_objective(text: String, kicker: String = "CURRENT OBJECTIVE") -> void:
	_objective_kicker.text = kicker
	_objective_label.text = text


func set_interaction(text: String, is_visible: bool = true) -> void:
	_interaction_label.text = text
	_interaction_panel.visible = is_visible and not text.is_empty()


func update_ship_telemetry(data: Dictionary) -> void:
	var speed: float = float(data.get("speed", 0.0))
	var altitude: float = maxf(0.0, float(data.get("altitude", 0.0)))
	var throttle: float = clampf(float(data.get("throttle", 0.0)), -1.0, 1.0)
	var maximum_hull: float = maxf(0.001, float(data.get("maximum_hull", 100.0)))
	var hull: float = clampf(float(data.get("hull", maximum_hull)), 0.0, maximum_hull)
	var damage_status := str(data.get("damage_status", "healthy")).to_upper()
	var engine_power := clampf(float(data.get("engine_power", 1.0)), 0.0, 1.0)
	_speed_label.text = "%03d" % roundi(speed)
	_altitude_label.text = "%04d M" % roundi(altitude)
	_throttle_bar.value = absf(throttle) * 100.0
	_throttle_label.text = "THROTTLE  //  %s" % (
		"REVERSE" if throttle < -0.04 else ("FORWARD" if throttle > 0.04 else "NEUTRAL")
	)
	_throttle_label.modulate = AMBER if throttle < -0.04 else MUTED
	_hull_bar.value = clampf(hull / maximum_hull, 0.0, 1.0) * 100.0
	_damage_status_label.text = "HULL  //  %s    ENGINE OUTPUT  %03d%%" % [
		damage_status,
		roundi(engine_power * 100.0),
	]
	_damage_status_label.modulate = RED if damage_status == "CRITICAL" else (AMBER if damage_status == "DAMAGED" else MUTED)
	set_engine_state(str(data.get("engine_state", "OFFLINE")))
	if _flight_cue_layer != null:
		_flight_cue_layer.update_from_telemetry(data)


func get_flight_cue_report() -> Dictionary:
	if _flight_cue_layer == null:
		return {
			"schema_version": 1,
			"layer_visible": false,
			"marker_visible": false,
			"marker_position": Vector2.ZERO,
			"connector_visible": false,
			"clamped": false,
			"rearward": false,
			"alignment": 0.0,
			"camera_view": &"",
			"safe_center": Vector2.ZERO,
			"safe_radii": Vector2.ZERO,
			"safe_rect": Rect2(),
			"mouse_passthrough": true,
		}
	var report := _flight_cue_layer.get_audit_report()
	report["reticle_visible"] = _reticle != null and _reticle.visible
	return report


func set_engine_state(state: String) -> void:
	var normalized := state.to_upper()
	_engine_label.text = "ENGINE  //  " + normalized
	match normalized:
		"ONLINE": _engine_label.modulate = CYAN
		"STARTING": _engine_label.modulate = AMBER
		_: _engine_label.modulate = RED


func set_target_count(destroyed: int, total: int) -> void:
	_target_label.text = "RANGE TARGETS  %d / %d" % [destroyed, total]


func set_enemy_status(display_name: String, current: float, maximum: float, visible: bool = true) -> void:
	_enemy_panel.visible = visible
	if not visible:
		return
	_enemy_name_label.text = display_name.to_upper()
	var safe_maximum := maxf(maximum, 0.001)
	var ratio := clampf(current / safe_maximum, 0.0, 1.0)
	_enemy_health_bar.value = ratio * 100.0
	_enemy_status_label.text = "%03d%%  //  %s" % [
		roundi(ratio * 100.0),
		"BREAKING" if ratio <= 0.35 else "ENGAGED",
	]
	_enemy_health_bar.modulate = RED if ratio <= 0.35 else AMBER


func flash_damage(intensity: float = 1.0, direction: Vector2 = Vector2.ZERO) -> void:
	var strength := clampf(intensity, 0.2, 1.0)
	if is_instance_valid(_damage_tween):
		_damage_tween.kill()
	_damage_flash.color = Color(0.95, 0.08, 0.035, 0.24 * strength)
	_damage_flash.modulate = Color.WHITE
	var normalized_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.UP
	var viewport_size := get_viewport().get_visible_rect().size
	var indicator_center := viewport_size * 0.5 + normalized_direction * Vector2(
		viewport_size.x * 0.36,
		viewport_size.y * 0.28
	)
	# Keep the directional cue inside safe margins and below the centered enemy
	# status panel; the previous fixed 1600x900 coordinate overlapped combat UI
	# and drifted at other resolutions.
	indicator_center.x = clampf(indicator_center.x, 80.0, viewport_size.x - 80.0)
	indicator_center.y = clampf(indicator_center.y, 240.0, viewport_size.y - 100.0)
	_damage_direction.position = indicator_center - _damage_direction.pivot_offset
	_damage_direction.rotation = normalized_direction.angle() + PI * 0.5
	_damage_direction.modulate = Color(1.0, 1.0, 1.0, strength)
	_damage_direction.visible = true
	_damage_tween = create_tween()
	_damage_tween.set_parallel(true)
	_damage_tween.tween_property(_damage_flash, "modulate", Color.TRANSPARENT, 0.42)
	_damage_tween.tween_property(_damage_direction, "modulate", Color.TRANSPARENT, 0.62)
	_damage_tween.chain().tween_callback(func() -> void:
		_damage_direction.visible = false
		_damage_tween = null
	)


func toast(title: String, detail: String = "", duration: float = 3.2) -> void:
	if is_instance_valid(_toast_tween):
		_toast_tween.kill()
	_toast_serial += 1
	var serial := _toast_serial
	_toast_title.text = title.to_upper()
	_toast_detail.text = detail
	_toast_panel.modulate = Color.TRANSPARENT
	_toast_panel.visible = true
	_toast_tween = create_tween()
	_toast_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_toast_tween.tween_property(_toast_panel, "modulate", Color.WHITE, 0.18)
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_panel, "modulate", Color.TRANSPARENT, 0.35)
	_toast_tween.tween_callback(func() -> void:
		if serial == _toast_serial:
			_toast_panel.visible = false
			_toast_tween = null
	)


func set_paused(paused: bool) -> void:
	_pause.visible = paused
	if paused:
		_show_pause_main()
	get_tree().paused = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED
	if paused and _pause_main_page != null:
		var resume := _pause_main_page.find_child("ResumeButton", true, false) as Button
		if resume != null:
			resume.grab_focus()


## Populates every supplied preference without sending change requests back to
## the settings owner. Missing keys retain the values currently shown.
func set_settings_snapshot(snapshot: Dictionary) -> void:
	_updating_settings = true
	for raw_key: Variant in snapshot:
		var key := StringName(str(raw_key))
		if not _settings_controls.has(key):
			continue
		var control := _settings_controls[key] as Control
		var value: Variant = snapshot[raw_key]
		if control is Range:
			(control as Range).value = float(value)
			_update_setting_value_label(key, float(value))
		elif control is CheckButton:
			(control as CheckButton).button_pressed = bool(value)
		elif control is OptionButton:
			var option := control as OptionButton
			option.select(clampi(int(value), 0, option.item_count - 1))
	_updating_settings = false


func set_settings_status(text: String, success: bool = true) -> void:
	if _settings_status_label == null:
		return
	_settings_status_label.text = text
	_settings_status_label.modulate = CYAN_SOFT if success else RED
	_settings_status_label.visible = not text.is_empty()


func _begin() -> void:
	if _started:
		return
	_started = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_intro, "modulate", Color.TRANSPARENT, 0.45)
	tween.tween_callback(func() -> void:
		_intro.visible = false
		_hud.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		start_requested.emit()
	)


func _build_interface() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_intro()
	_build_hud()
	_build_pause()
	_set_mouse_passthrough(_hud)
	show_intro()


func _build_intro() -> void:
	_intro = Control.new()
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_intro)

	var backdrop := TextureRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = load("res://assets/keth-nebula.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color("879eae")
	_intro.add_child(backdrop)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("02071194")
	_intro.add_child(shade)

	var corner := MarginContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	corner.offset_left = 72.0
	corner.offset_right = 690.0
	corner.offset_top = -410.0
	corner.offset_bottom = -62.0
	_intro.add_child(corner)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	corner.add_child(stack)

	var eyebrow := _label("INSPIRED BY ZOLARKETH'S CLASSIC SANDBOX", 14, AMBER)
	eyebrow.add_theme_constant_override("outline_size", 5)
	eyebrow.add_theme_color_override("font_outline_color", INK)
	stack.add_child(eyebrow)

	var title := _label("MUDDS", 82, WHITE)
	title.add_theme_constant_override("outline_size", 12)
	title.add_theme_color_override("font_outline_color", INK)
	stack.add_child(title)

	var title_two := _label("SHIPYARDS", 54, CYAN)
	title_two.add_theme_constant_override("outline_size", 10)
	title_two.add_theme_color_override("font_outline_color", INK)
	stack.add_child(title_two)

	var subtitle := _label("MODERN FAN REMAKE  /  VERTICAL SLICE 02", 16, MUTED)
	stack.add_child(subtitle)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(310.0, 3.0)
	rule.color = AMBER
	stack.add_child(rule)

	var copy := _label("Walk the yard. Board the ship. Start the engines.\nThe launch deck is waiting.", 18, WHITE)
	copy.add_theme_constant_override("line_spacing", 6)
	stack.add_child(copy)

	var start := Button.new()
	start.text = "BEGIN SHIFT   [ E ]"
	start.custom_minimum_size = Vector2(280.0, 52.0)
	start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	start.add_theme_font_size_override("font_size", 16)
	start.add_theme_color_override("font_color", INK)
	start.add_theme_color_override("font_hover_color", INK)
	start.add_theme_stylebox_override("normal", _box(CYAN, 4, 0, Color.TRANSPARENT))
	start.add_theme_stylebox_override("hover", _box(CYAN_SOFT, 4, 0, Color.TRANSPARENT))
	start.add_theme_stylebox_override("pressed", _box(AMBER, 4, 0, Color.TRANSPARENT))
	start.pressed.connect(_begin)
	stack.add_child(start)

	var footer := _label("STANDALONE FAN PROTOTYPE  •  NO ROBLOX REQUIRED", 11, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position = Vector2(-570.0, -42.0)
	footer.size = Vector2(530.0, 20.0)
	_intro.add_child(footer)


func _build_hud() -> void:
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.visible = false
	_root.add_child(_hud)

	var brand := VBoxContainer.new()
	brand.position = Vector2(30.0, 26.0)
	brand.size = Vector2(460.0, 96.0)
	brand.add_theme_constant_override("separation", 2)
	_hud.add_child(brand)
	var brand_title := _label("MUDDS  /  SHIPYARDS", 20, WHITE)
	brand.add_child(brand_title)
	_mode_label = _label("ON FOOT  //  REGENERATION DECK", 12, CYAN)
	brand.add_child(_mode_label)
	var brand_rule := ColorRect.new()
	brand_rule.custom_minimum_size = Vector2(245.0, 2.0)
	brand_rule.color = CYAN
	brand.add_child(brand_rule)

	var objective := PanelContainer.new()
	objective.position = Vector2(30.0, 126.0)
	objective.size = Vector2(440.0, 112.0)
	objective.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud.add_child(objective)
	var objective_margin := _margin(18, 14, 18, 14)
	objective.add_child(objective_margin)
	var objective_stack := VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation", 6)
	objective_margin.add_child(objective_stack)
	_objective_kicker = _label("CURRENT OBJECTIVE", 11, AMBER)
	objective_stack.add_child(_objective_kicker)
	_objective_label = _label("Approach the Torrent-class interceptor", 17, WHITE)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_stack.add_child(_objective_label)
	_target_label = _label("RANGE TARGETS  0 / 3", 11, MUTED)
	objective_stack.add_child(_target_label)

	_help_panel = PanelContainer.new()
	_help_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_help_panel.offset_left = -300.0
	_help_panel.offset_right = -28.0
	_help_panel.offset_top = 28.0
	_help_panel.offset_bottom = 342.0
	_help_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud.add_child(_help_panel)
	_set_help_text([])

	_interaction_panel = PanelContainer.new()
	_interaction_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_interaction_panel.offset_left = -250.0
	_interaction_panel.offset_right = 250.0
	_interaction_panel.offset_top = -118.0
	_interaction_panel.offset_bottom = -54.0
	_interaction_panel.add_theme_stylebox_override("panel", _box(Color("101c2bf2"), 7, 1, CYAN))
	_hud.add_child(_interaction_panel)
	var interaction_margin := _margin(18, 12, 18, 12)
	_interaction_panel.add_child(interaction_margin)
	_interaction_label = _label("[ E ]  BOARD TORRENT", 15, WHITE)
	_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_margin.add_child(_interaction_label)
	_interaction_panel.visible = false

	_flight_cue_layer = FlightPathCueType.new() as FlightPathCue
	_flight_cue_layer.name = "FlightPathCue"
	_flight_cue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_flight_cue_layer)

	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.position = Vector2(-22.0, -22.0)
	_reticle.size = Vector2(44.0, 44.0)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_reticle)
	for rect_data: Array in [
		[Vector2(20, 0), Vector2(4, 12)], [Vector2(20, 32), Vector2(4, 12)],
		[Vector2(0, 20), Vector2(12, 4)], [Vector2(32, 20), Vector2(12, 4)]
	]:
		var mark := ColorRect.new()
		mark.position = rect_data[0]
		mark.size = rect_data[1]
		mark.color = CYAN
		_reticle.add_child(mark)
	_reticle.visible = false

	_build_telemetry()
	_build_enemy_status()
	_build_toast()
	_build_damage_flash()


func _build_telemetry() -> void:
	_telemetry_panel = PanelContainer.new()
	_telemetry_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_telemetry_panel.offset_left = -378.0
	_telemetry_panel.offset_right = -28.0
	_telemetry_panel.offset_top = -260.0
	_telemetry_panel.offset_bottom = -28.0
	_telemetry_panel.add_theme_stylebox_override("panel", _box(PANEL, 8, 1, Color("315367")))
	_hud.add_child(_telemetry_panel)
	var margin := _margin(18, 15, 18, 15)
	_telemetry_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	_engine_label = _label("ENGINE  //  OFFLINE", 12, RED)
	stack.add_child(_engine_label)
	var readouts := HBoxContainer.new()
	readouts.add_theme_constant_override("separation", 26)
	stack.add_child(readouts)
	var speed_stack := VBoxContainer.new()
	readouts.add_child(speed_stack)
	_speed_label = _label("000", 38, WHITE)
	speed_stack.add_child(_speed_label)
	speed_stack.add_child(_label("M / S", 10, MUTED))
	var alt_stack := VBoxContainer.new()
	readouts.add_child(alt_stack)
	_altitude_label = _label("0000 M", 27, CYAN_SOFT)
	alt_stack.add_child(_altitude_label)
	alt_stack.add_child(_label("ALTITUDE", 10, MUTED))
	_throttle_label = _label("THROTTLE  //  NEUTRAL", 9, MUTED)
	stack.add_child(_throttle_label)
	_throttle_bar = _bar(CYAN)
	stack.add_child(_throttle_bar)
	stack.add_child(_label("HULL INTEGRITY", 9, MUTED))
	_hull_bar = _bar(AMBER)
	_hull_bar.value = 100.0
	stack.add_child(_hull_bar)
	_damage_status_label = _label("HULL  //  HEALTHY    ENGINE OUTPUT  100%", 9, MUTED)
	stack.add_child(_damage_status_label)
	_telemetry_panel.visible = false


func _build_toast() -> void:
	_toast_panel = PanelContainer.new()
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_panel.offset_left = -265.0
	_toast_panel.offset_right = 265.0
	_toast_panel.offset_top = 32.0
	_toast_panel.offset_bottom = 112.0
	_toast_panel.add_theme_stylebox_override("panel", _box(PANEL_SOLID, 6, 1, AMBER))
	_hud.add_child(_toast_panel)
	var margin := _margin(18, 10, 18, 10)
	_toast_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	margin.add_child(stack)
	_toast_title = _label("SYSTEM ONLINE", 13, AMBER)
	_toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_toast_title)
	_toast_detail = _label("", 12, WHITE)
	_toast_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_toast_detail)
	_toast_panel.visible = false


func _build_enemy_status() -> void:
	_enemy_panel = PanelContainer.new()
	_enemy_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_enemy_panel.offset_left = -238.0
	_enemy_panel.offset_right = 238.0
	_enemy_panel.offset_top = 124.0
	_enemy_panel.offset_bottom = 192.0
	_enemy_panel.add_theme_stylebox_override("panel", _box(Color("180f16e8"), 7, 1, RED))
	_hud.add_child(_enemy_panel)
	var margin := _margin(16, 9, 16, 9)
	_enemy_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	var heading := HBoxContainer.new()
	stack.add_child(heading)
	_enemy_name_label = _label("RANGE DEFENCE INTERCEPTOR", 11, WHITE)
	_enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_enemy_name_label)
	_enemy_status_label = _label("100%  //  ENGAGED", 10, AMBER)
	heading.add_child(_enemy_status_label)
	_enemy_health_bar = _bar(AMBER)
	_enemy_health_bar.value = 100.0
	stack.add_child(_enemy_health_bar)
	_enemy_panel.visible = false


func _build_damage_flash() -> void:
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.95, 0.08, 0.035, 0.2)
	_damage_flash.modulate = Color.TRANSPARENT
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_damage_flash)
	_damage_direction = _label("▲", 30, RED)
	_damage_direction.size = Vector2(50.0, 50.0)
	_damage_direction.pivot_offset = Vector2(25.0, 25.0)
	_damage_direction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_direction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_damage_direction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_direction.visible = false
	_hud.add_child(_damage_direction)


func _build_pause() -> void:
	_pause = Control.new()
	_pause.name = "PauseOverlay"
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.visible = false
	_root.add_child(_pause)
	var dim := ColorRect.new()
	dim.name = "PauseDimmer"
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color("020711c7")
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause.add_child(dim)
	_build_pause_main_page()
	_build_settings_page()
	_show_pause_main()


func _build_pause_main_page() -> void:
	_pause_main_page = PanelContainer.new()
	_pause_main_page.name = "PauseMainPage"
	_pause_main_page.set_anchors_preset(Control.PRESET_CENTER)
	_pause_main_page.position = Vector2(-240.0, -204.0)
	_pause_main_page.size = Vector2(480.0, 408.0)
	_pause_main_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_main_page.add_theme_stylebox_override("panel", _box(PANEL_SOLID, 10, 1, CYAN))
	_pause.add_child(_pause_main_page)
	var margin := _margin(34, 28, 34, 28)
	_pause_main_page.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var paused_title := _label("SHIFT PAUSED", 30, WHITE)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(paused_title)
	var paused_subtitle := _label("Station systems remain on standby.", 13, MUTED)
	paused_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(paused_subtitle)
	var resume := _menu_button("RESUME", CYAN)
	resume.name = "ResumeButton"
	resume.pressed.connect(func() -> void: set_paused(false))
	stack.add_child(resume)
	var settings := _menu_button("SETTINGS", CYAN_SOFT)
	settings.name = "SettingsOpenButton"
	settings.pressed.connect(_show_settings_page)
	stack.add_child(settings)
	var restart := _menu_button("RESTART SHIFT", AMBER)
	restart.name = "RestartButton"
	restart.pressed.connect(func() -> void:
		set_paused(false)
		restart_requested.emit()
	)
	stack.add_child(restart)
	var exit := _menu_button("EXIT TO DESKTOP", RED)
	exit.name = "ExitButton"
	exit.pressed.connect(func() -> void: get_tree().quit())
	stack.add_child(exit)


func _build_settings_page() -> void:
	_settings_page = PanelContainer.new()
	_settings_page.name = "SettingsPage"
	_settings_page.set_anchors_preset(Control.PRESET_CENTER)
	_settings_page.position = Vector2(-430.0, -330.0)
	_settings_page.size = Vector2(860.0, 660.0)
	_settings_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_page.add_theme_stylebox_override("panel", _box(PANEL_SOLID, 10, 1, CYAN))
	_pause.add_child(_settings_page)

	var margin := _margin(30, 24, 30, 24)
	_settings_page.add_child(margin)
	var page_stack := VBoxContainer.new()
	page_stack.add_theme_constant_override("separation", 12)
	margin.add_child(page_stack)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 18)
	page_stack.add_child(heading)
	var heading_copy := VBoxContainer.new()
	heading_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_copy.add_theme_constant_override("separation", 2)
	heading.add_child(heading_copy)
	heading_copy.add_child(_label("SHIP SYSTEM SETTINGS", 25, WHITE))
	heading_copy.add_child(_label("Tune flight, camera, display and mix. Changes preview immediately.", 12, MUTED))
	var header_rule := ColorRect.new()
	header_rule.custom_minimum_size = Vector2(92.0, 3.0)
	header_rule.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_rule.color = AMBER
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(header_rule)

	var scroll := ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	page_stack.add_child(scroll)

	var columns := HBoxContainer.new()
	columns.custom_minimum_size.x = 780.0
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	scroll.add_child(columns)
	var left_column := VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 12)
	columns.add_child(left_column)
	var right_column := VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override("separation", 12)
	columns.add_child(right_column)

	var controls_group := _settings_group(left_column, "FLIGHT + CAMERA", "Input follows the direction you see.")
	_add_slider_setting(controls_group, &"ship_mouse_sensitivity", "Ship steering sensitivity", 0.0002, 0.02, 0.0001, 0.0022)
	_add_toggle_setting(controls_group, &"invert_ship_y", "Invert ship vertical look", false)
	_add_slider_setting(controls_group, &"on_foot_mouse_sensitivity", "On-foot look sensitivity", 0.0005, 0.02, 0.0001, 0.0025)
	_add_toggle_setting(controls_group, &"invert_on_foot_y", "Invert on-foot vertical look", false)
	_add_slider_setting(controls_group, &"camera_fov", "Camera field of view", 55.0, 110.0, 1.0, 72.0)
	_add_option_setting(controls_group, &"control_preset", "Control hints (labels only)", ["Modern", "Classic"], 0)

	var display_group := _settings_group(left_column, "DISPLAY", "Choose clarity or headroom.")
	_add_option_setting(display_group, &"graphics_profile", "Graphics quality", ["Low", "Medium", "High"], 2)
	_add_option_setting(display_group, &"window_mode", "Window mode", ["Windowed", "Borderless", "Fullscreen"], 0)

	var audio_group := _settings_group(right_column, "AUDIO MIX", "Independent linear volume controls.")
	_add_slider_setting(audio_group, &"master_volume", "Master", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"ambience_volume", "Shipyard ambience", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"engine_volume", "Engines", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"weapons_volume", "Weapons", 0.0, 1.0, 0.01, 1.0)
	_add_slider_setting(audio_group, &"ui_volume", "Interface", 0.0, 1.0, 0.01, 1.0)

	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _box(Color("122638"), 5, 1, Color("315367")))
	right_column.add_child(hint_panel)
	var hint_margin := _margin(14, 12, 14, 12)
	hint_panel.add_child(hint_margin)
	var hint := _label("TIP  //  Start with the cockpit camera and lower steering sensitivity if the nose feels too eager.", 11, CYAN_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(hint)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	page_stack.add_child(footer)
	var save := _menu_button("APPLY + SAVE", CYAN)
	save.name = "SettingsSaveButton"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(func() -> void: settings_save_requested.emit())
	footer.add_child(save)
	var reset := _menu_button("RESET DEFAULTS", AMBER)
	reset.name = "SettingsResetButton"
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset.pressed.connect(func() -> void: settings_reset_requested.emit())
	footer.add_child(reset)
	var back := _menu_button("BACK", MUTED)
	back.name = "SettingsBackButton"
	back.custom_minimum_size.x = 150.0
	back.pressed.connect(_show_pause_main)
	footer.add_child(back)
	_settings_status_label = _label("", 10, CYAN_SOFT)
	_settings_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_status_label.visible = false
	page_stack.add_child(_settings_status_label)


func _settings_group(parent: VBoxContainer, title: String, detail: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(Color("101f2e"), 6, 1, Color("27465b")))
	parent.add_child(panel)
	var margin := _margin(16, 13, 16, 14)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	margin.add_child(stack)
	stack.add_child(_label(title, 12, AMBER))
	stack.add_child(_label(detail, 10, MUTED))
	return stack


func _add_slider_setting(
	parent: VBoxContainer,
	key: StringName,
	title: String,
	minimum: float,
	maximum: float,
	step: float,
	initial: float
) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var copy := HBoxContainer.new()
	row.add_child(copy)
	var title_label := _label(title, 11, WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_child(title_label)
	var value_label := _label("", 10, CYAN_SOFT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size.x = 68.0
	copy.add_child(value_label)
	var slider := HSlider.new()
	slider.name = String(key).to_pascal_case() + "Control"
	slider.custom_minimum_size.y = 18.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	var slider_track := _box(Color("29475b"), 4, 0, Color.TRANSPARENT)
	slider_track.content_margin_top = 3.0
	slider_track.content_margin_bottom = 3.0
	var slider_fill := _box(CYAN.darkened(0.28), 4, 0, Color.TRANSPARENT)
	slider_fill.content_margin_top = 3.0
	slider_fill.content_margin_bottom = 3.0
	var slider_fill_highlight := _box(CYAN, 4, 0, Color.TRANSPARENT)
	slider_fill_highlight.content_margin_top = 3.0
	slider_fill_highlight.content_margin_bottom = 3.0
	slider.add_theme_stylebox_override("slider", slider_track)
	slider.add_theme_stylebox_override("grabber_area", slider_fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_highlight)
	slider.value_changed.connect(func(value: float) -> void: _on_setting_value_changed(key, value))
	row.add_child(slider)
	_settings_controls[key] = slider
	_settings_value_labels[key] = value_label
	_update_setting_value_label(key, initial)


func _add_toggle_setting(parent: VBoxContainer, key: StringName, title: String, initial: bool) -> void:
	var toggle := CheckButton.new()
	toggle.name = String(key).to_pascal_case() + "Control"
	toggle.text = title
	toggle.button_pressed = initial
	toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	toggle.add_theme_font_size_override("font_size", 11)
	toggle.add_theme_color_override("font_color", WHITE)
	toggle.add_theme_color_override("font_hover_color", CYAN_SOFT)
	toggle.toggled.connect(func(value: bool) -> void: _on_setting_value_changed(key, value))
	parent.add_child(toggle)
	_settings_controls[key] = toggle


func _add_option_setting(
	parent: VBoxContainer,
	key: StringName,
	title: String,
	options: Array,
	initial: int
) -> void:
	var row := VBoxContainer.new()
	row.name = String(key).to_pascal_case() + "Row"
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	row.add_child(_label(title, 11, WHITE))
	var selector := OptionButton.new()
	selector.name = String(key).to_pascal_case() + "Control"
	selector.custom_minimum_size.y = 38.0
	selector.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	selector.add_theme_font_size_override("font_size", 11)
	selector.add_theme_color_override("font_color", WHITE)
	selector.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	selector.add_theme_stylebox_override("hover", _box(Color("173044"), 4, 1, CYAN))
	for option: Variant in options:
		selector.add_item(str(option))
	selector.select(initial)
	selector.item_selected.connect(func(index: int) -> void: _on_setting_value_changed(key, index))
	row.add_child(selector)
	_settings_controls[key] = selector


func _on_setting_value_changed(key: StringName, value: Variant) -> void:
	if value is float:
		_update_setting_value_label(key, float(value))
	if not _updating_settings:
		setting_change_requested.emit(key, value)


func _update_setting_value_label(key: StringName, value: float) -> void:
	if not _settings_value_labels.has(key):
		return
	var value_label := _settings_value_labels[key] as Label
	match key:
		&"ship_mouse_sensitivity":
			value_label.text = "%d%%" % roundi(value / 0.0022 * 100.0)
		&"on_foot_mouse_sensitivity":
			value_label.text = "%d%%" % roundi(value / 0.0025 * 100.0)
		&"camera_fov":
			value_label.text = "%d°" % roundi(value)
		_:
			value_label.text = "%d%%" % roundi(value * 100.0)


func _show_settings_page() -> void:
	_pause_main_page.visible = false
	_settings_page.visible = true
	var first_control := _settings_controls.get(&"ship_mouse_sensitivity") as Control
	if first_control != null:
		first_control.grab_focus()


func _show_pause_main() -> void:
	if _pause_main_page == null or _settings_page == null:
		return
	_pause_main_page.visible = true
	_settings_page.visible = false


func _set_help_text(rows: Array) -> void:
	for child in _help_panel.get_children():
		child.queue_free()
	var margin := _margin(16, 14, 16, 14)
	_help_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	var heading := _label("CONTROLS  //  F1", 11, AMBER)
	stack.add_child(heading)
	for row: Array in rows:
		var line := HBoxContainer.new()
		var key := _label(str(row[0]), 11, CYAN_SOFT)
		key.custom_minimum_size.x = 92.0
		line.add_child(key)
		line.add_child(_label(str(row[1]), 10, MUTED))
		stack.add_child(line)
	_set_mouse_passthrough(_help_panel)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _box(color: Color, radius: int, border_width: int, border_color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.border_color = border_color
	return box


func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, 8.0)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("213444"), 3, 0, Color.TRANSPARENT))
	bar.add_theme_stylebox_override("fill", _box(fill_color, 3, 0, Color.TRANSPARENT))
	return bar


func _menu_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48.0
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_stylebox_override("normal", _box(Color("142536"), 4, 1, Color("315367")))
	button.add_theme_stylebox_override("hover", _box(color.darkened(0.55), 4, 1, color))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.35), 4, 1, color))
	return button


func _set_mouse_passthrough(control: Control) -> void:
	# Gameplay look/steer is handled through `_unhandled_input`; non-interactive
	# HUD controls must never consume motion or fire clicks before they reach it.
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			_set_mouse_passthrough(child as Control)
