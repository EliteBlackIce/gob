class_name Camcorder
extends CanvasLayer
## Full-screen "found footage" filter plus a blinking REC tag. Sits under the UI layer.

var _rect: ColorRect
var _mat: ShaderMaterial
var _tag: Label
var _clock := 0.0


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/camcorder.gdshader")
	_rect.material = _mat
	add_child(_rect)
	_tag = Label.new()
	_tag.add_theme_font_override("font", PixelFont.get_font())
	_tag.add_theme_font_size_override("font_size", 16)
	_tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_tag.add_theme_constant_override("shadow_offset_x", 2)
	_tag.add_theme_constant_override("shadow_offset_y", 2)
	_tag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tag.offset_right = -22
	_tag.offset_bottom = -14
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)


func _process(delta: float) -> void:
	var on: bool = bool(Game.settings["camcorder"])
	_rect.visible = on
	_tag.visible = on
	if not on:
		return
	_clock += delta
	_mat.set_shader_parameter("time_s", fmod(_clock, 50.0))
	var secs := int(Time.get_ticks_msec() / 1000)
	var dot := "o" if int(_clock * 1.6) % 2 == 0 else " "
	_tag.text = "%s REC\nDAY %d  %02d:%02d:%02d" % [dot, Game.day, secs / 3600, (secs / 60) % 60, secs % 60]
	_tag.add_theme_color_override("font_color", Color("#ff5050") if dot == "o" else Color("#e8e8e8"))
