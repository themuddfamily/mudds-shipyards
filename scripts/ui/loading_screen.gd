class_name LoadingScreen
extends CanvasLayer

## The first thing the packaged build puts on screen.
##
## This layer is built entirely from code, out of primitives that need no
## imported resource, so it can be constructed and painted before any of the
## expensive startup work begins. The nebula backdrop the title screen also uses
## is a 2 MB import, so it is attached separately by [method attach_backdrop]
## once the text has already reached the screen: the player never waits on it.
##
## Progress reported here is real. [method set_stage] is driven by completed
## startup phase boundaries and by the count of construction stages that have
## actually finished. While the scene resource is loading on its worker the bar
## holds at the phase boundary and the caret continues pulsing; it advances only
## when that resource or a named construction stage really completes.
##
## The accessibility presets are honoured, not bypassed. The stored preferences
## are read through `RuntimeSettings` before gameplay exists, so the colourblind
## palette tints the progress fill and the stage text, `ui_scale` sizes the
## type, and `reduced_motion` removes the fade and the pulsing caret.

const PaletteType := preload("res://scripts/ui/hud_palette.gd")

const BACKDROP_PATH := "res://assets/keth-nebula.png"
const INK := Color("020711")
const PANEL := Color("0c1724")
const DISMISS_FADE_SECONDS := 0.35
const BACKDROP_FADE_SECONDS := 0.45
const CARET_PERIOD_SECONDS := 1.1

var _root: Control
var _backdrop_slot: Control
var _title: Label
var _destination_label: Label
var _phase_label: Label
var _stage_label: Label
var _detail_label: Label
var _caret: Label
var _progress_label: Label
var _bar_track: ColorRect
var _bar_fill: ColorRect
var _phase_track: HBoxContainer
var _rule: ColorRect

var _palette: Dictionary = PaletteType.get_palette(PaletteType.MODE_NONE)
var _ui_scale := 1.0
var _reduced_motion := false
var _progress := 0.0
var _stage_text := ""
var _detail_text := ""
var _destination_text := ""
var _phase_text := ""
var _phase_index := 0
var _phase_count := 0
var _elapsed := 0.0
var _dismissed := false
var _backdrop: TextureRect
var _backdrop_fade_remaining := 0.0
var _dismiss_fade_remaining := 0.0
var _has_entered_live_tree := false


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_has_entered_live_tree = true
	_build()
	_repaint()
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_layout):
		viewport.size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	# This instance may be retained and attached again. Do not let the last
	# destination remain painted during the gap before its new caller publishes
	# current state; detached public calls are deliberately rejected below.
	_reset_status_state()


## Applies the stored accessibility preferences. Accepts the same descriptor
## `RuntimeSettings.get_accessibility_descriptor()` hands the HUD, so the
## loading screen and the HUD can never disagree about what the player chose.
func configure(descriptor: Dictionary) -> void:
	# Startup construction configures this screen before it enters the tree, but
	# once it has been live its presentation state belongs only to its current
	# attachment generation. A stale detached continuation must not alter what a
	# later re-entry presents.
	if is_queued_for_deletion() or (_has_entered_live_tree and not is_inside_tree()):
		return
	if descriptor.has("colorblind_palette_id"):
		_palette = PaletteType.get_palette(
			StringName(str(descriptor["colorblind_palette_id"]))
		)
	if descriptor.has("ui_scale"):
		_ui_scale = clampf(float(descriptor["ui_scale"]), 0.75, 1.6)
	if descriptor.has("reduced_motion"):
		_reduced_motion = bool(descriptor["reduced_motion"])
	if _root != null:
		_repaint()
		_layout()


## Names the stage now running and how far startup has actually got, 0..1.
## A caller that owns a real multi-phase transition may also publish its steady
## destination and 1-based phase position. They are presentation descriptors:
## this screen never advances either one on its own.
func set_stage(
	stage_text: String,
	progress: float,
	detail_text: String = "",
	destination_text: String = "",
	phase_text: String = "",
	phase_index: int = 0,
	phase_count: int = 0
) -> void:
	if not _can_mutate_live_presentation():
		return
	# Zero is the caller's unambiguous beginning-of-load state. It also prevents
	# a retained screen from lending any previous state to a new transition.
	if progress <= 0.0:
		_reset_status_state()
	_stage_text = stage_text
	_detail_text = detail_text
	_destination_text = (
		destination_text.strip_edges()
		if not destination_text.strip_edges().is_empty()
		else _destination_for(stage_text, detail_text, _destination_text)
	)
	_set_phase_state(phase_text, phase_index, phase_count)
	# Startup only ever moves forward. Clamping here means a caller that reports
	# a phase boundary slightly out of order cannot make the bar walk backwards.
	_progress = clampf(maxf(progress, _progress), 0.0, 1.0)
	if _stage_label == null:
		return
	_destination_label.text = "DESTINATION  /  %s" % _destination_text
	_phase_label.text = _formatted_phase_text()
	_phase_label.visible = _phase_count > 0
	_stage_label.text = _stage_text.to_upper()
	_detail_label.text = _detail_text
	# Keep this row reserved even when a phase has no detail. Changing a child
	# stage must not make the global progress track jump vertically.
	_detail_label.visible = true
	_progress_label.text = "%d%%" % roundi(_progress * 100.0)
	_layout_bar()
	_sync_phase_track()


## Loads and fades in the shared title backdrop. Called after the first frames
## have been presented, so its import cost is never part of time-to-first-frame.
func attach_backdrop() -> void:
	if not _can_mutate_live_presentation():
		return
	if _backdrop_slot == null or _backdrop_slot.get_child_count() > 0:
		return
	var texture := load(BACKDROP_PATH) as Texture2D
	if texture == null:
		return
	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.modulate = Color("879eae")
	_backdrop_slot.add_child(backdrop)
	if _reduced_motion:
		return
	backdrop.modulate.a = 0.0
	_backdrop = backdrop
	_backdrop_fade_remaining = BACKDROP_FADE_SECONDS


## Retires the screen. Under reduced motion it disappears at once; otherwise it
## cross-fades so the handover to the title screen is not a hard cut.
##
## The fades here are stepped in [method _process] rather than tweened. A `Tween`
## whose final callback frees the node that owns it leaves its tweeners behind as
## unreachable `RefCounted` instances, which the engine reports as leaks at exit;
## a counter costs less and cannot outlive the node it animates.
func dismiss() -> void:
	if not _can_mutate_live_presentation():
		return
	if _dismissed:
		return
	_dismissed = true
	if _reduced_motion or _root == null:
		queue_free()
		return
	_dismiss_fade_remaining = DISMISS_FADE_SECONDS


func is_dismissed() -> bool:
	return _dismissed


func get_progress() -> float:
	return _progress


func get_stage_text() -> String:
	return _stage_text


func _can_mutate_live_presentation() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


## Everything the screen is currently showing, for tests and for the startup
## report the loader prints.
func get_report() -> Dictionary:
	return {
		"progress": _progress,
		"stage": _stage_text,
		"detail": _detail_text,
		"destination": _destination_text,
		"phase": _phase_text,
		"phase_index": _phase_index,
		"phase_count": _phase_count,
		"reduced_motion": _reduced_motion,
		"ui_scale": _ui_scale,
		"dismissed": _dismissed,
		"backdrop_attached": _backdrop_slot != null and _backdrop_slot.get_child_count() > 0,
	}


func _process(delta: float) -> void:
	_advance_backdrop_fade(delta)
	if _advance_dismiss_fade(delta):
		return
	if _caret == null:
		return
	if _reduced_motion:
		_caret.modulate.a = 1.0
		return
	_elapsed += delta
	# A soft two-state caret, not a spinner that implies progress of its own.
	_caret.modulate.a = 0.35 + 0.65 * (0.5 + 0.5 * sin(TAU * _elapsed / CARET_PERIOD_SECONDS))


func _advance_backdrop_fade(delta: float) -> void:
	if _backdrop_fade_remaining <= 0.0 or not is_instance_valid(_backdrop):
		return
	_backdrop_fade_remaining = maxf(_backdrop_fade_remaining - delta, 0.0)
	_backdrop.modulate.a = 1.0 - _backdrop_fade_remaining / BACKDROP_FADE_SECONDS


## Returns true once the screen has started retiring, so nothing else animates.
func _advance_dismiss_fade(delta: float) -> bool:
	if not _dismissed:
		return false
	if _root == null:
		return true
	_dismiss_fade_remaining = maxf(_dismiss_fade_remaining - delta, 0.0)
	_root.modulate.a = _dismiss_fade_remaining / DISMISS_FADE_SECONDS
	if _dismiss_fade_remaining <= 0.0:
		queue_free()
	return true


func _build() -> void:
	_root = Control.new()
	_root.name = "LoadingRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var ink := ColorRect.new()
	ink.name = "Ink"
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ink.color = INK
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(ink)

	_backdrop_slot = Control.new()
	_backdrop_slot.name = "BackdropSlot"
	_backdrop_slot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_backdrop_slot)

	var shade := ColorRect.new()
	shade.name = "Shade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color("020711c4")
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 10)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(stack)

	_title = _make_label("MUDDS SHIPYARDS", 46)
	stack.add_child(_title)

	_rule = ColorRect.new()
	_rule.name = "Rule"
	_rule.custom_minimum_size = Vector2(310.0, 3.0)
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_rule)

	_destination_label = _make_label("", 13)
	_destination_label.name = "Destination"
	stack.add_child(_destination_label)

	_phase_label = _make_label("", 12)
	_phase_label.name = "Phase"
	_phase_label.visible = false
	stack.add_child(_phase_label)

	var stage_row := HBoxContainer.new()
	stage_row.name = "StageRow"
	stage_row.add_theme_constant_override("separation", 6)
	stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(stage_row)

	_stage_label = _make_label("", 17)
	_stage_label.name = "Status"
	_stage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_label.clip_text = true
	_stage_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stage_row.add_child(_stage_label)

	_caret = _make_label("_", 17)
	stage_row.add_child(_caret)

	_progress_label = _make_label("", 17)
	_progress_label.name = "Progress"
	_progress_label.custom_minimum_size.x = 62.0
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_row.add_child(_progress_label)

	_detail_label = _make_label("", 13)
	_detail_label.name = "Detail"
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.max_lines_visible = 2
	_detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail_label.custom_minimum_size.y = 36.0
	stack.add_child(_detail_label)

	_phase_track = HBoxContainer.new()
	_phase_track.name = "PhaseTrack"
	_phase_track.add_theme_constant_override("separation", 6)
	_phase_track.custom_minimum_size.y = 3.0
	_phase_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_phase_track)

	_bar_track = ColorRect.new()
	_bar_track.name = "BarTrack"
	_bar_track.color = PANEL
	_bar_track.custom_minimum_size = Vector2(420.0, 8.0)
	_bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_bar_track)

	_bar_fill = ColorRect.new()
	_bar_fill.name = "BarFill"
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_track.add_child(_bar_fill)

	var footer := _make_label("STANDALONE FAN PROTOTYPE", 11)
	footer.name = "Footer"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	footer.position = Vector2(-570.0, -42.0)
	footer.size = Vector2(530.0, 20.0)
	_root.add_child(footer)


func _make_label(text: String, base_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta(&"base_font_size", base_size)
	label.add_theme_font_size_override("font_size", base_size)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", INK)
	return label


func _repaint() -> void:
	var primary := _role(PaletteType.ROLE_PRIMARY)
	var nominal := _role(PaletteType.ROLE_NOMINAL)
	var muted := _role(PaletteType.ROLE_MUTED)
	_title.add_theme_color_override("font_color", primary)
	_destination_label.add_theme_color_override("font_color", _role(PaletteType.ROLE_CAUTION))
	_phase_label.add_theme_color_override("font_color", _role(PaletteType.ROLE_MUTED))
	_stage_label.add_theme_color_override("font_color", nominal)
	_caret.add_theme_color_override("font_color", nominal)
	_progress_label.add_theme_color_override("font_color", nominal)
	_detail_label.add_theme_color_override("font_color", muted)
	_rule.color = _role(PaletteType.ROLE_CAUTION)
	_bar_fill.color = nominal
	_repaint_phase_track()
	var footer := _root.get_node_or_null(^"Footer") as Label
	if footer != null:
		footer.add_theme_color_override("font_color", muted)


func _role(role: StringName) -> Color:
	return _palette.get(role, _palette[PaletteType.ROLE_PRIMARY]) as Color


func _layout() -> void:
	if _root == null:
		return
	var stack := _root.get_node_or_null(^"Stack") as VBoxContainer
	if stack == null:
		return
	for label: Node in [_title, _destination_label, _phase_label, _stage_label, _caret, _progress_label, _detail_label]:
		var typed := label as Label
		if typed == null:
			continue
		var base := int(typed.get_meta(&"base_font_size", 16))
		typed.add_theme_font_size_override("font_size", maxi(8, roundi(base * _ui_scale)))
	var viewport_size := _viewport_size()
	var margin := minf(72.0 * _ui_scale, viewport_size.x * 0.1)
	var available_width := maxf(1.0, viewport_size.x - margin * 2.0)
	var readable_width := clampf(
		viewport_size.x * 0.5,
		minf(420.0 * _ui_scale, available_width),
		minf(760.0 * _ui_scale, available_width)
	)
	_rule.custom_minimum_size = Vector2(minf(310.0 * _ui_scale, readable_width), 3.0)
	_bar_track.custom_minimum_size = Vector2(readable_width, 8.0)
	_phase_track.custom_minimum_size = Vector2(readable_width, 3.0)
	_progress_label.custom_minimum_size.x = 62.0 * _ui_scale
	var stack_height := minf(260.0 * _ui_scale, viewport_size.y - margin * 2.0)
	stack.position = Vector2(margin, maxf(margin, viewport_size.y - stack_height - margin))
	stack.size = Vector2(readable_width, stack_height)
	_layout_bar()


func _layout_bar() -> void:
	if _bar_track == null or _bar_fill == null:
		return
	# The track minimum is the exact readable width selected by `_layout`. Using
	# an old container size here can briefly overflow when UI scale decreases.
	var track_width := _bar_track.custom_minimum_size.x
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(track_width * _progress, _bar_track.custom_minimum_size.y)


func _viewport_size() -> Vector2:
	var viewport := get_viewport()
	if viewport != null:
		var rect := viewport.get_visible_rect().size
		if rect.x > 1.0 and rect.y > 1.0:
			return rect
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	)


func _destination_for(stage_text: String, detail_text: String, current: String) -> String:
	var stage := stage_text.to_lower()
	if stage.contains("ember"):
		return "EMBER MOON"
	if stage.contains("cinder"):
		return "CINDER REACH"
	if (
		stage.contains("mudds")
		or stage.contains("shipyard")
		or (" " + stage + " ").contains(" station ")
		or stage == "starting up"
	):
		return "MUDDS SHIPYARDS"
	# A staged child name is supporting detail, not a destination override. Only
	# consult it when the caller's status did not already name the transition.
	# This keeps "Building the shipyard / Preparing Ember..." truthfully at
	# Mudds while still supporting neutral statuses with an explicit destination.
	var detail := detail_text.to_lower()
	if detail.contains("ember"):
		return "EMBER MOON"
	if detail.contains("cinder"):
		return "CINDER REACH"
	if (
		detail.contains("mudds")
		or detail.contains("shipyard")
		or (" " + detail + " ").contains(" station ")
	):
		return "MUDDS SHIPYARDS"
	if not current.is_empty():
		return current
	return "DESTINATION PENDING"


func _set_phase_state(phase_text: String, phase_index: int, phase_count: int) -> void:
	var cleaned_phase := phase_text.strip_edges()
	if cleaned_phase.is_empty() or phase_count <= 0 or phase_index <= 0 or phase_index > phase_count:
		_phase_text = ""
		_phase_index = 0
		_phase_count = 0
		return
	_phase_text = cleaned_phase
	_phase_index = phase_index
	_phase_count = mini(phase_count, 8)
	_phase_index = mini(_phase_index, _phase_count)


func _formatted_phase_text() -> String:
	if _phase_count <= 0:
		return ""
	return "PHASE %d OF %d  /  %s" % [_phase_index, _phase_count, _phase_text.to_upper()]


func _rebuild_phase_track() -> void:
	if _phase_track == null:
		return
	for child in _phase_track.get_children():
		_phase_track.remove_child(child)
		child.queue_free()
	_phase_track.visible = _phase_count > 0
	for segment_index in _phase_count:
		var segment := ColorRect.new()
		segment.name = "Phase%02d" % (segment_index + 1)
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.custom_minimum_size.y = 3.0
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segment.set_meta(&"phase_number", segment_index + 1)
		_phase_track.add_child(segment)
	_repaint_phase_track()


func _sync_phase_track() -> void:
	if _phase_track == null:
		return
	_phase_track.visible = _phase_count > 0
	# Threaded resource progress may publish every frame. Preserve the same
	# segment nodes while only their phase state changes; the loading UI should
	# not allocate and retire Controls throughout the very path it is smoothing.
	if _phase_track.get_child_count() != _phase_count:
		_rebuild_phase_track()
		return
	_repaint_phase_track()


func _repaint_phase_track() -> void:
	if _phase_track == null:
		return
	for child in _phase_track.get_children():
		var segment := child as ColorRect
		if segment == null:
			continue
		var phase_number := int(segment.get_meta(&"phase_number", 0))
		var color := _role(PaletteType.ROLE_MUTED)
		if phase_number < _phase_index:
			color = _role(PaletteType.ROLE_NOMINAL)
			color.a = 0.7
		elif phase_number == _phase_index:
			color = _role(PaletteType.ROLE_CAUTION)
		else:
			color.a = 0.3
		segment.color = color


func _reset_status_state() -> void:
	_progress = 0.0
	_stage_text = ""
	_detail_text = ""
	_destination_text = ""
	_phase_text = ""
	_phase_index = 0
	_phase_count = 0
	if _destination_label != null:
		_destination_label.text = ""
	if _stage_label != null:
		_stage_label.text = ""
	if _detail_label != null:
		_detail_label.text = ""
		_detail_label.visible = true
	if _phase_label != null:
		_phase_label.text = ""
		_phase_label.visible = false
	_sync_phase_track()
	if _progress_label != null:
		_progress_label.text = ""
	if _bar_fill != null:
		_bar_fill.size.x = 0.0
