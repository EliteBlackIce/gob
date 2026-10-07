class_name FloatText
extends Label3D
## Damage numbers: billboard pixel text that pops, drifts up and fades.

static func spawn(parent: Node, pos: Vector3, text: String, color: Color, size := 1.0, secs := 0.8, rise := 1.1) -> void:
	var l := FloatText.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.0075 * size
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.06, 0.03, 0.03)
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.shaded = false
	l.render_priority = 5
	l.outline_render_priority = 4
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector3.ONE * (1.25 if size > 1.1 else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y + rise, secs).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(l.queue_free)
