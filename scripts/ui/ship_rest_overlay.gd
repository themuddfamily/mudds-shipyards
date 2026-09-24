extends CanvasLayer

const SafeArea := preload("res://scripts/ui/ultrawide_safe_area_contract.gd")
const BASE_FONT_SIZE := 26
const BASE_CAPTION_SIZE := Vector2(980.0, 180.0)
const SHADE_OPACITY := 0.985

## Quiet, interruptible rest presentation. Input remains with PlayerController,
## including its normal pause action and the same E edge used to enter the bunk.
var _shade: ColorRect
var _caption: Label
var _elapsed := 0.0
var _craft_name := ""
var _ui_scale := 1.0
var _reduced_motion := false


func _ready() -> void:
	layer = 8
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.015, 0.025, 0.045, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color", Color(0.8, 0.86, 0.92))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(_caption)
	get_viewport().size_changed.connect(_layout_caption)
	_layout_caption()
	hide()
	set_process(false)


func configure_accessibility(ui_scale: float, reduced_motion: bool) -> void:
	_ui_scale = clampf(ui_scale, SafeArea.MIN_UI_SCALE, SafeArea.MAX_UI_SCALE)
	_reduced_motion = reduced_motion
	if not is_node_ready():
		return
	_layout_caption()
	if visible and _reduced_motion:
		_shade.color.a = SHADE_OPACITY
		set_process(false)


func _layout_caption() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe: Rect2 = SafeArea.safe_rect(viewport_size, _ui_scale)
	var caption_size := Vector2(
		minf(BASE_CAPTION_SIZE.x * _ui_scale, safe.size.x),
		minf(BASE_CAPTION_SIZE.y * _ui_scale, safe.size.y)
	)
	_caption.position = safe.position + (safe.size - caption_size) * 0.5
	_caption.size = caption_size
	_caption.add_theme_font_size_override("font_size", roundi(BASE_FONT_SIZE * _ui_scale))


func begin_rest(craft_name: String, wake_input: String = "E") -> void:
	_elapsed = 0.0
	_craft_name = craft_name.to_upper()
	set_wake_input(wake_input)
	_shade.color.a = SHADE_OPACITY if _reduced_motion else 0.0
	show()
	set_process(not _reduced_motion)


func set_wake_input(wake_input: String) -> void:
	_caption.text = "RESTING ABOARD %s\n\n[ %s ]  WAKE UP" % [_craft_name, wake_input]


func end_rest() -> void:
	hide()
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_shade.color.a = minf(_elapsed / 0.6, 1.0) * SHADE_OPACITY
	if _elapsed >= 0.6:
		set_process(false)
