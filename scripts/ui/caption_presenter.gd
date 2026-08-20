class_name CaptionPresenter
extends Control

## Reusable, snapshot-only visual presenter for CaptionPresentationService.
##
## This component never holds the service or a caption event object. Its only
## state input is the detached Dictionary returned by
## CaptionPresentationService.get_presentation_snapshot().

const COMPONENT_ID: StringName = &"caption-visual-presenter"
const SERVICE_ID: StringName = &"caption-presentation-service"
const SNAPSHOT_SCHEMA_VERSION := 1
const MIN_UI_SCALE := 0.75
const MAX_UI_SCALE := 1.6
const BASE_MIN_PANEL_WIDTH := 560.0
const BASE_MAX_PANEL_WIDTH := 960.0
const BASE_MIN_PANEL_HEIGHT := 104.0
const BASE_SAFE_MARGIN_X := 32.0
const BASE_SAFE_MARGIN_TOP := 24.0
const BASE_SAFE_MARGIN_BOTTOM := 42.0
const BASE_MARGIN_X := 28
const BASE_MARGIN_Y := 20
const BASE_STACK_SEPARATION := 8
const BASE_CATEGORY_FONT_SIZE := 15
const BASE_SPEAKER_FONT_SIZE := 18
const BASE_TEXT_FONT_SIZE := 22
const PANEL_BACKGROUND := Color("07101ef2")
const PANEL_BORDER := Color("bceef5")
const CATEGORY_INK := Color("9aedf4")
const SPEAKER_INK := Color("ffffff")
const TEXT_INK := Color("f3f9fd")

@onready var _panel: PanelContainer = %PanelShell
@onready var _margin: MarginContainer = %PanelMargin
@onready var _stack: VBoxContainer = %CaptionStack
@onready var _category_label: Label = %CategoryLabel
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _divider: HSeparator = %Divider
@onready var _text_label: RichTextLabel = %TextLabel

var _ui_scale := 1.0
var _applied_snapshot: Dictionary = {}
var _layout_token := 0
var _layout_viewport_size := Vector2.ZERO
## Optional physical-pixel exclusion supplied by a host HUD. A negative value
## retains the reusable component's scaled bottom safe margin.
var _host_bottom_safe_margin := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enforce_input_transparency()
	# Speaker text is bounded to 64 characters by the service, but that can still
	# exceed a narrow composed-HUD centre band. Preserve the full semantic text
	# property while keeping its visible header inside the panel.
	_speaker_label.clip_text = true
	_speaker_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	visible = false
	if not resized.is_connected(_queue_layout):
		resized.connect(_queue_layout)
	_apply_scale_theme()
	_queue_layout()


func _enter_tree() -> void:
	# Deferred layout work dropped during a detached turn must not mutate the
	# retained Control hierarchy off-tree. Re-entry schedules one current pass.
	_queue_layout()


## Applies only the service's detached presentation snapshot schema. Malformed
## or hand-authored lookalikes reject without changing the last committed view.
func apply_presentation_snapshot(snapshot: Dictionary) -> bool:
	if not _can_mutate_live_presentation():
		return false
	if not _is_valid_presentation_snapshot(snapshot):
		return false
	var was_visible := visible
	var previous_category := _category_label.text
	var previous_speaker := _speaker_label.text
	var previous_text := _text_label.text
	_applied_snapshot = snapshot.duplicate(true)
	var should_show := bool(_applied_snapshot.visible) and bool(_applied_snapshot.captions_enabled)
	if not should_show:
		_category_label.text = ""
		_speaker_label.text = ""
		_text_label.text = ""
		visible = false
		if was_visible or not previous_text.is_empty():
			_queue_layout()
		return true
	var caption := _applied_snapshot.caption as Dictionary
	_category_label.text = "[ %s ]" % str(caption.category_id).to_upper()
	_speaker_label.text = str(caption.speaker)
	_text_label.text = str(caption.text)
	modulate = Color.WHITE
	self_modulate = Color.WHITE
	visible = true
	if (
		not was_visible
		or previous_category != _category_label.text
		or previous_speaker != _speaker_label.text
		or previous_text != _text_label.text
	):
		_queue_layout()
	return true


func set_ui_scale(value: float) -> bool:
	if not _can_configure_layout():
		return false
	if not is_finite(value) or value < MIN_UI_SCALE or value > MAX_UI_SCALE:
		return false
	if is_equal_approx(_ui_scale, value):
		return true
	_ui_scale = value
	_apply_scale_theme()
	_queue_layout()
	return true


func get_ui_scale() -> float:
	return _ui_scale


## Lets a composed HUD reserve its own bottom interaction/telemetry band while
## retaining this component's width, wrapping and top/side safe-area rules.
## The value is expressed in final viewport pixels because the host may apply a
## different layout ceiling from the requested accessibility scale.
func set_host_bottom_safe_margin(value: float) -> bool:
	if not _can_configure_layout():
		return false
	if not is_finite(value) or value < 0.0:
		return false
	if is_equal_approx(_host_bottom_safe_margin, value):
		return true
	_host_bottom_safe_margin = value
	_queue_layout()
	return true


func clear_host_bottom_safe_margin() -> void:
	if not _can_configure_layout():
		return
	if _host_bottom_safe_margin < 0.0:
		return
	_host_bottom_safe_margin = -1.0
	_queue_layout()


## Deeply detached copy suitable for a consumer that detaches and later wants to
## compare revisions. Mutation never reaches the labels or retained input.
func get_applied_snapshot() -> Dictionary:
	return _applied_snapshot.duplicate(true)


func get_layout_contract() -> Dictionary:
	return {
		"minimum_ui_scale": MIN_UI_SCALE,
		"maximum_ui_scale": MAX_UI_SCALE,
		"base_minimum_panel_width": BASE_MIN_PANEL_WIDTH,
		"base_maximum_panel_width": BASE_MAX_PANEL_WIDTH,
		"base_minimum_panel_height": BASE_MIN_PANEL_HEIGHT,
		"base_safe_margin_x": BASE_SAFE_MARGIN_X,
		"base_safe_margin_top": BASE_SAFE_MARGIN_TOP,
		"base_safe_margin_bottom": BASE_SAFE_MARGIN_BOTTOM,
		"host_bottom_safe_margin_unit": &"physical_viewport_pixels",
		"maximum_panel_height_policy": &"viewport_minus_scaled_safe_top_and_bottom",
		"maximum_text_characters": CaptionPresentationEvent.MAX_TEXT_LENGTH,
	}.duplicate(true)


## Detached accessibility contract consumed by settings/review tooling.  The
## presenter remains presentation-only: this describes what the current scene
## guarantees, but does not enable captions, mutate settings, or infer audio
## state.  Keeping this beside the visual contract prevents a caller from
## treating a colour or flash treatment as the accessibility feature itself.
func get_accessibility_contract() -> Dictionary:
	return {
		"captions_are_textual": true,
		"category_is_textual": true,
		"speaker_is_textual": true,
		"body_contrast_ratio_minimum": 7.0,
		"speaker_contrast_ratio_minimum": 7.0,
		"category_contrast_ratio_minimum": 7.0,
		"border_contrast_ratio_minimum": 7.0,
		"reduced_flash_policy": &"steady_no_flash",
		"standard_transition_policy": &"consumer_standard",
		"animation_player_count": 0,
		"owned_tween_count": 0,
		"input_transparent": true,
		"captions_enabled_authority": &"caller_accessibility_settings",
		"audio_authority": false,
		"gameplay_authority": false,
	}.duplicate(true)


func get_layout_report() -> Dictionary:
	var viewport_size := _resolved_viewport_size()
	var safe_rect := _safe_rect(viewport_size)
	var panel_rect := _panel.get_global_rect() if _panel != null else Rect2()
	var text_content_height := float(_text_label.get_content_height()) if _text_label != null else 0.0
	var text_rect := _text_label.get_global_rect() if _text_label != null else Rect2()
	var input_transparent := mouse_filter == Control.MOUSE_FILTER_IGNORE
	for candidate in find_children("*", "Control", true, false):
		input_transparent = input_transparent and (candidate as Control).mouse_filter == Control.MOUSE_FILTER_IGNORE
	return {
		"component_id": COMPONENT_ID,
		"viewport_size": viewport_size,
		"viewport_origin": global_position,
		"ui_scale": _ui_scale,
		"safe_rect": safe_rect,
		"panel_rect": panel_rect,
		"panel_minimum_width": BASE_MIN_PANEL_WIDTH * _ui_scale,
		"panel_maximum_width": BASE_MAX_PANEL_WIDTH * _ui_scale,
		"panel_minimum_height": BASE_MIN_PANEL_HEIGHT * _ui_scale,
		"panel_maximum_height": _maximum_panel_height(viewport_size),
		"effective_safe_margin_bottom": _safe_margin_bottom(),
		"category_rect": _category_label.get_global_rect() if _category_label != null else Rect2(),
		"speaker_rect": _speaker_label.get_global_rect() if _speaker_label != null else Rect2(),
		"text_rect": text_rect,
		"text_content_height": text_content_height,
		"text_line_count": _text_label.get_line_count() if _text_label != null else 0,
		"text_clipped": text_content_height > text_rect.size.y + 1.0,
		"input_transparent": input_transparent,
		"visible": visible,
		"reduced_flash": bool(_applied_snapshot.get("reduced_flash", false)),
		"transition_policy": StringName(_applied_snapshot.get("transition_policy", &"")),
		"animation_player_count": find_children("*", "AnimationPlayer", true, false).size(),
		# The component has no tween owner. A composed HUD may have unrelated toast
		# or damage tweens, which must not be misreported as caption animation.
		"owned_tween_count": 0,
		"tween_count": 0,
		"rendered_category": _category_label.text if _category_label != null else "",
		"rendered_speaker": _speaker_label.text if _speaker_label != null else "",
		"rendered_text": _text_label.text if _text_label != null else "",
	}.duplicate(true)


func audit() -> Dictionary:
	var errors := PackedStringArray()
	if _panel == null or _margin == null or _stack == null:
		errors.append("caption panel hierarchy is incomplete")
	if _category_label == null or _speaker_label == null or _text_label == null:
		errors.append("caption typography hierarchy is incomplete")
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:
		errors.append("presenter root can intercept input")
	for candidate in find_children("*", "Control", true, false):
		if (candidate as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			errors.append("presenter child can intercept input: %s" % str(candidate.get_path()))
	if not is_finite(_ui_scale) or _ui_scale < MIN_UI_SCALE or _ui_scale > MAX_UI_SCALE:
		errors.append("UI scale left its frozen supported range")
	return {
		"component_id": COMPONENT_ID,
		"valid": errors.is_empty(),
		"errors": errors,
		"layout_contract": get_layout_contract(),
		"layout": get_layout_report(),
		"snapshot_input": &"caption_presentation_service_presentation_dictionary_only",
		"snapshot_storage": &"deep_detached_copy",
		"safe_area_anchoring": true,
		"wraps_text": true,
		"category_label_is_textual": true,
		"reduced_flash_policy": &"steady_no_animation",
		"presentation_only": true,
		"audio_authority": false,
		"gameplay_authority": false,
		"activity_authority": false,
		"reward_authority": false,
		"ship_authority": false,
		"berth_authority": false,
		"save_authority": false,
		"network_authority": false,
	}.duplicate(true)


func _is_valid_presentation_snapshot(snapshot: Dictionary) -> bool:
	if (
		typeof(snapshot.get("schema_version")) != TYPE_INT
		or int(snapshot.get("schema_version", -1)) != SNAPSHOT_SCHEMA_VERSION
		or typeof(snapshot.get("service_id")) != TYPE_STRING_NAME
		or StringName(snapshot.get("service_id", &"")) != SERVICE_ID
		or typeof(snapshot.get("generation")) != TYPE_INT
		or int(snapshot.get("generation", -1)) < 0
		or typeof(snapshot.get("revision")) != TYPE_INT
		or int(snapshot.get("revision", -1)) < 0
		or typeof(snapshot.get("visible")) != TYPE_BOOL
		or typeof(snapshot.get("captions_enabled")) != TYPE_BOOL
		or typeof(snapshot.get("reduced_flash")) != TYPE_BOOL
		or typeof(snapshot.get("transition_policy")) != TYPE_STRING_NAME
		or not snapshot.get("caption") is Dictionary
	):
		return false
	var reduced_flash := bool(snapshot.reduced_flash)
	var expected_policy: StringName = &"steady_no_flash" if reduced_flash else &"consumer_standard"
	if StringName(snapshot.get("transition_policy", &"")) != expected_policy:
		return false
	var shown := bool(snapshot.visible)
	if shown != (bool(snapshot.captions_enabled) and not (snapshot.caption as Dictionary).is_empty()):
		return false
	if not shown:
		return (snapshot.caption as Dictionary).is_empty()
	var caption := snapshot.caption as Dictionary
	if (
		typeof(caption.get("stable_id")) != TYPE_STRING_NAME
		or typeof(caption.get("category")) != TYPE_INT
		or typeof(caption.get("category_id")) != TYPE_STRING_NAME
		or typeof(caption.get("speaker")) != TYPE_STRING
		or typeof(caption.get("text")) != TYPE_STRING
		or typeof(caption.get("duration_physics_seconds")) != TYPE_FLOAT
		or typeof(caption.get("remaining_physics_seconds")) != TYPE_FLOAT
		or typeof(caption.get("priority")) != TYPE_INT
		or typeof(caption.get("sequence")) != TYPE_INT
		or int(caption.get("sequence", 0)) <= 0
	):
		return false
	var event := CaptionPresentationEvent.new(
		StringName(caption.get("stable_id", &"")),
		int(caption.get("category", -1)) as CaptionPresentationEvent.Category,
		str(caption.get("speaker", "")),
		str(caption.get("text", "")),
		float(caption.get("duration_physics_seconds", -1.0)),
		int(caption.get("priority", -1))
	)
	if not event.is_valid() or StringName(caption.get("category_id", &"")) != event.get_category_id():
		return false
	var remaining := float(caption.get("remaining_physics_seconds", -1.0))
	return (
		is_finite(remaining)
		and remaining > 0.0
		and remaining <= event.duration_physics_seconds
	)


func _can_mutate_live_presentation() -> bool:
	return is_inside_tree() and not is_queued_for_deletion()


func _can_configure_layout() -> bool:
	return not is_queued_for_deletion() and (not is_node_ready() or is_inside_tree())


func _apply_scale_theme() -> void:
	if _margin == null:
		return
	_margin.add_theme_constant_override("margin_left", roundi(BASE_MARGIN_X * _ui_scale))
	_margin.add_theme_constant_override("margin_right", roundi(BASE_MARGIN_X * _ui_scale))
	_margin.add_theme_constant_override("margin_top", roundi(BASE_MARGIN_Y * _ui_scale))
	_margin.add_theme_constant_override("margin_bottom", roundi(BASE_MARGIN_Y * _ui_scale))
	_stack.add_theme_constant_override("separation", roundi(BASE_STACK_SEPARATION * _ui_scale))
	_category_label.add_theme_font_size_override("font_size", roundi(BASE_CATEGORY_FONT_SIZE * _ui_scale))
	_speaker_label.add_theme_font_size_override("font_size", roundi(BASE_SPEAKER_FONT_SIZE * _ui_scale))
	_text_label.add_theme_font_size_override("normal_font_size", roundi(BASE_TEXT_FONT_SIZE * _ui_scale))
	_category_label.add_theme_constant_override("outline_size", maxi(2, roundi(3.0 * _ui_scale)))
	_speaker_label.add_theme_constant_override("outline_size", maxi(2, roundi(3.0 * _ui_scale)))
	_text_label.add_theme_constant_override("outline_size", maxi(2, roundi(3.0 * _ui_scale)))


func _queue_layout() -> void:
	if _panel == null:
		return
	_layout_token += 1
	var token := _layout_token
	call_deferred("_layout_pass_one", token)


func _layout_pass_one(token: int) -> void:
	if is_queued_for_deletion() or not is_inside_tree() or token != _layout_token or _panel == null:
		return
	_layout_viewport_size = _resolved_viewport_size()
	var safe_margin_x := BASE_SAFE_MARGIN_X * _ui_scale
	var available_width := maxf(1.0, _layout_viewport_size.x - safe_margin_x * 2.0)
	var panel_width := minf(BASE_MAX_PANEL_WIDTH * _ui_scale, available_width)
	panel_width = maxf(minf(BASE_MIN_PANEL_WIDTH * _ui_scale, available_width), panel_width)
	var bottom_margin := _safe_margin_bottom()
	var maximum_height := _maximum_panel_height(_layout_viewport_size)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_left = -panel_width * 0.5
	_panel.offset_right = panel_width * 0.5
	_panel.offset_bottom = -bottom_margin
	_panel.offset_top = -bottom_margin - maximum_height
	_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	call_deferred("_layout_pass_two", token)


func _layout_pass_two(token: int) -> void:
	if is_queued_for_deletion() or not is_inside_tree() or token != _layout_token or _panel == null:
		return
	var header_height := maxf(
		_category_label.get_combined_minimum_size().y,
		_speaker_label.get_combined_minimum_size().y
	)
	var divider_height := maxf(_divider.get_combined_minimum_size().y, 1.0)
	var content_height := maxf(float(_text_label.get_content_height()), float(roundi(BASE_TEXT_FONT_SIZE * _ui_scale)))
	var vertical_margins := float(roundi(BASE_MARGIN_Y * _ui_scale) * 2)
	var separations := float(roundi(BASE_STACK_SEPARATION * _ui_scale) * 2)
	var desired_height := vertical_margins + separations + header_height + divider_height + content_height
	var maximum_height := _maximum_panel_height(_layout_viewport_size)
	var panel_height := clampf(desired_height, BASE_MIN_PANEL_HEIGHT * _ui_scale, maximum_height)
	var bottom_margin := _safe_margin_bottom()
	_panel.offset_top = -bottom_margin - panel_height
	_panel.offset_bottom = -bottom_margin


func _resolved_viewport_size() -> Vector2:
	if size.x > 0.0 and size.y > 0.0:
		return size
	var viewport := get_viewport()
	return Vector2(viewport.size) if viewport != null else Vector2.ZERO


func _safe_rect(viewport_size: Vector2) -> Rect2:
	var left := BASE_SAFE_MARGIN_X * _ui_scale
	var top := BASE_SAFE_MARGIN_TOP * _ui_scale
	var right := viewport_size.x - left
	var bottom := viewport_size.y - _safe_margin_bottom()
	return Rect2(
		global_position + Vector2(left, top),
		Vector2(maxf(0.0, right - left), maxf(0.0, bottom - top))
	)


func _maximum_panel_height(viewport_size: Vector2) -> float:
	return maxf(
		BASE_MIN_PANEL_HEIGHT * _ui_scale,
		viewport_size.y - BASE_SAFE_MARGIN_TOP * _ui_scale - _safe_margin_bottom()
	)


func _safe_margin_bottom() -> float:
	return (
		_host_bottom_safe_margin
		if _host_bottom_safe_margin >= 0.0
		else BASE_SAFE_MARGIN_BOTTOM * _ui_scale
	)


func _enforce_input_transparency() -> void:
	for candidate in find_children("*", "Control", true, false):
		(candidate as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
