class_name Style
extends RefCounted
## Small helpers shared by gameplay scripts. All art lives in scripts/vox.


static func mat(color: Color, emit := 0.0) -> ShaderMaterial:
	return VMat.solid(0.25, 4.0, {"tint": color, "emission_strength": emit})


static func solid_box(parent: Node, size: Vector3, pos := Vector3.ZERO) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = size
	cs.shape = shp
	sb.add_child(cs)
	sb.position = pos
	if parent != null:
		parent.add_child(sb)
	return sb


static func label3d(parent: Node, text: String, pos: Vector3, size := 0.02, color := Color("#f3e3b5"), rot := Vector3.ZERO, billboard := false) -> Label3D:
	var l := Label3D.new()
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.text = text
	l.font = PixelFont.get_font()
	l.font_size = 32
	l.pixel_size = size
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color("#2a1a0d")
	l.position = pos
	l.rotation_degrees = rot
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if parent != null:
		parent.add_child(l)
	return l


static func light(parent: Node, color: Color, energy: float, rng: float, pos: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	if parent != null:
		parent.add_child(l)
	return l


## One-shot chunky cube burst (feathers, sparks, splashes, confetti).
static func burst(tree_parent: Node, pos: Vector3, color: Color, amount := 14, speed := 5.0, size := 0.12, life := 0.8) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	p.material_override = m
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	tree_parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)


static func smooth(a: float, b: float, x: float) -> float:
	var t: float = clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
