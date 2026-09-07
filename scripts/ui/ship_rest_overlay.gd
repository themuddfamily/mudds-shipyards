extends CanvasLayer

## Quiet, interruptible rest presentation. Input remains with PlayerController,
## including its normal pause action and the same E edge used to enter the bunk.
var _shade: ColorRect
var _caption: Label
var _elapsed := 0.0
var _craft_name := ""


func _ready() -> void:
	layer = 8
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.015, 0.025, 0.045, 0.0)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_color", Color(0.8, 0.86, 0.92))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(_caption)
	hide()
	set_process(false)


func begin_rest(craft_name: String, wake_input: String = "E") -> void:
	_elapsed = 0.0
	_craft_name = craft_name.to_upper()
	set_wake_input(wake_input)
	_shade.color.a = 0.0
	show()
	set_process(true)


func set_wake_input(wake_input: String) -> void:
	_caption.text = "RESTING ABOARD %s\n\n[ %s ]  WAKE UP" % [_craft_name, wake_input]


func end_rest() -> void:
	hide()
	set_process(false)


func _process(delta: float) -> void:
	_elapsed += delta
	_shade.color.a = minf(_elapsed / 0.6, 1.0) * 0.985
