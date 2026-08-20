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
## Progress reported here is real. [method set_stage] is driven by the startup
## loader from the resource loader's own percentage and from the count of
## construction stages that have actually finished, so the bar never jumps from
## nothing to done, and it never advances while nothing is happening.
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
var _stage_label: Label
var _detail_label: Label
var _caret: Label
var _bar_track: ColorRect
var _bar_fill: ColorRect
var _rule: ColorRect

var _palette: Dictionary = PaletteType.get_palette(PaletteType.MODE_NONE)
var _ui_scale := 1.0
var _reduced_motion := false
var _progress := 0.0
var _stage_text := ""
var _detail_text := ""
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
func set_stage(stage_text: String, progress: float, detail_text: String = "") -> void:
	if not _can_mutate_live_presentation():
		return
	_stage_text = stage_text
	_detail_text = detail_text
	# Startup only ever moves forward. Clamping here means a caller that reports
	# a phase boundary slightly out of order cannot make the bar walk backwards.
	_progress = clampf(maxf(progress, _progress), 0.0, 1.0)
	if _stage_label == null:
		return
	_stage_label.text = _stage_text.to_upper()
	_detail_label.text = _detail_text
	_detail_label.visible = not _detail_text.is_empty()
	_layout_bar()


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

	var stage_row := HBoxContainer.new()
	stage_row.name = "StageRow"
	stage_row.add_theme_constant_override("separation", 6)
	stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(stage_row)

	_stage_label = _make_label("", 17)
	stage_row.add_child(_stage_label)

	_caret = _make_label("_", 17)
	stage_row.add_child(_caret)

	_detail_label = _make_label("", 13)
	_detail_label.visible = false
	stack.add_child(_detail_label)

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
	_stage_label.add_theme_color_override("font_color", nominal)
	_caret.add_theme_color_override("font_color", nominal)
	_detail_label.add_theme_color_override("font_color", muted)
	_rule.color = _role(PaletteType.ROLE_CAUTION)
	_bar_fill.color = nominal
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
	for label: Node in [_title, _stage_label, _caret, _detail_label]:
		var typed := label as Label
		if typed == null:
			continue
		var base := int(typed.get_meta(&"base_font_size", 16))
		typed.add_theme_font_size_override("font_size", maxi(8, roundi(base * _ui_scale)))
	_rule.custom_minimum_size = Vector2(310.0 * _ui_scale, 3.0)
	_bar_track.custom_minimum_size = Vector2(420.0 * _ui_scale, 8.0)
	var viewport_size := _viewport_size()
	var margin := 72.0 * _ui_scale
	stack.position = Vector2(margin, viewport_size.y - 300.0 * _ui_scale)
	stack.size = Vector2(maxf(420.0 * _ui_scale, viewport_size.x * 0.5), 240.0 * _ui_scale)
	_layout_bar()


func _layout_bar() -> void:
	if _bar_track == null or _bar_fill == null:
		return
	var track_width := maxf(_bar_track.size.x, _bar_track.custom_minimum_size.x)
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
