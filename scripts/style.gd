class_name Style
extends RefCounted
## Procedural art helpers: everything in the game is built from primitives
## wearing the same painterly shader, so the whole world reads as one style.

static var _shader: Shader
static var _cache: Dictionary = {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/stylized.gdshader")
	return _shader


static func mat(color: Color, rim := 0.5, emit := 0.0, flat := true) -> ShaderMaterial:
	var key := "%s|%s|%s|%s" % [color.to_html(), rim, emit, flat]
	if _cache.has(key):
		return _cache[key]
	var m := make_mat(color, rim, emit, flat)
	_cache[key] = m
	return m


## Un-cached material, for things that animate (glowing parcels, lanterns).
static func make_mat(color: Color, rim := 0.5, emit := 0.0, flat := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("rim_amount", rim)
	m.set_shader_parameter("emission_strength", emit)
	m.set_shader_parameter("flat_shade", 1.0 if flat else 0.0)
	return m


static func _place(mi: MeshInstance3D, parent: Node, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	mi.position = pos
	mi.rotation_degrees = rot
	if parent != null:
		parent.add_child(mi)
	return mi


static func box(parent: Node, size: Vector3, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, 0.5, emit)
	return _place(mi, parent, pos, rot)


static func sphere(parent: Node, radius: float, color: Color, pos := Vector3.ZERO, scl := Vector3.ONE, segs := 8, emit := 0.0) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segs
	m.rings = maxi(segs / 2, 3)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, 0.5, emit)
	mi.scale = scl
	return _place(mi, parent, pos, Vector3.ZERO)


static func cyl(parent: Node, top_r: float, bot_r: float, h: float, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, segs := 7, emit := 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bot_r
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, 0.5, emit)
	return _place(mi, parent, pos, rot)


static func cone(parent: Node, r: float, h: float, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, segs := 6) -> MeshInstance3D:
	return cyl(parent, 0.0, r, h, color, pos, rot, segs)


static func torus(parent: Node, inner: float, outer: float, color: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, emit := 0.0) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 10
	m.ring_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, 0.4, emit)
	return _place(mi, parent, pos, rot)


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
	l.pixel_size = size
	l.modulate = color
	l.outline_size = 8
	l.outline_modulate = Color("#2a1a0d")
	l.position = pos
	l.rotation_degrees = rot
	l.shaded = false
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


## One-shot chunky particle burst (feathers, sparks, splashes, confetti).
static func burst(tree_parent: Node, pos: Vector3, color: Color, amount := 14, speed := 5.0, size := 0.12, life := 0.8) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	p.mesh = bm
	p.material_override = mat(color, 0.2, 0.3)
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
