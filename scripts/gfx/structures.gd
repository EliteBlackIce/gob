class_name Structures
extends RefCounted
## Buildings and furniture assets, all procedural, all in the same painted style.
## Conventions: +Y up, the "front" of a building faces -Z, metres.

static var _sc := {}
static var allow_moss := true

const WOOD_GREY := Color("#8a7a64")
const WOOD_BROWN := Color("#7a5a3a")
const WOOD_DARK := Color("#4e3826")


static func _mi(parent: Node, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	if parent != null:
		parent.add_child(m)
	return m


static func wood_white(extra := {}) -> ShaderMaterial:
	var e := {"grain": 0.8, "stroke_axis": Vector3(1, 0, 0), "wear": 0.5, "wear_color": Color("#cdb48a")}
	e.merge(extra, true)
	return Paint.get_mat("wood", Color.WHITE, e)


static func _tint(base: Color, rng: RandomNumberGenerator, spread := 0.16) -> Color:
	var k := 1.0 + rng.randf_range(-spread, spread)
	var c := Color(base.r * k, base.g * k, base.b * k, 1.0)
	if allow_moss and rng.randf() < 0.08:
		c = c.lerp(Color("#4f7a3a"), 0.35)   # moss / algae stain
	return c


## Horizontal clapboard wall w x h in the XY plane (front faces -Z, centred on x, bottom at y=0).
static func plank_wall(w: float, h: float, base: Color, seed_v := 1, plank_h := 0.22, thick := 0.05) -> ArrayMesh:
	var key := "pwall|%s|%s|%s|%s|%s" % [w, h, base.to_html(), seed_v, plank_h]
	if _sc.has(key):
		return _sc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var rows := int(ceil(h / plank_h))
	for r in rows:
		var y := (r + 0.5) * plank_h
		var x := -w * 0.5
		while x < w * 0.5 - 0.01:
			var ln := minf(rng.randf_range(1.1, 3.2), w * 0.5 - x)
			if ln < 0.2:
				break
			var tint := _tint(base, rng)
			var pm := MeshKit.rbox(Vector3(ln - 0.025, plank_h * 0.96, thick), 0.012, 0.08, 1, tint)
			var tr := Transform3D(Basis(Vector3(0, 0, 1), rng.randf_range(-0.004, 0.004)), Vector3(x + ln * 0.5, y, rng.randf_range(-0.01, 0.012) + (r % 2) * 0.006))
			parts.append([pm, tr])
			x += ln
	var m := MeshKit.combine(parts)
	_sc[key] = m
	return m


## One shingled roof slope in its own frame: width w along X, slope length l along +Z (up-slope = +Y/+Z mix handled by caller).
static func shingle_slope(w: float, l: float, base: Color, seed_v := 1, moss := 0.2) -> ArrayMesh:
	var key := "shingle|%s|%s|%s|%s|%s" % [w, l, base.to_html(), seed_v, moss]
	if _sc.has(key):
		return _sc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var row_h := 0.28
	var rows := int(ceil(l / row_h))
	for r in rows:
		var z := (r + 0.5) * row_h
		var x := -w * 0.5
		while x < w * 0.5 - 0.01:
			var ln := minf(rng.randf_range(0.5, 1.5), w * 0.5 - x)
			if ln < 0.15:
				break
			var tint := _tint(base, rng, 0.2)
			if rng.randf() < moss:
				tint = tint.lerp(Color("#5a8a3a"), rng.randf_range(0.4, 0.8))
			var pm := MeshKit.rbox(Vector3(ln - 0.02, 0.035, row_h * 1.35), 0.012, 0.0, 1, tint)
			var tr := Transform3D(Basis(Vector3(1, 0, 0), deg_to_rad(5.0)), Vector3(x + ln * 0.5, 0.02 * (r % 2), z))
			parts.append([pm, tr])
			x += ln
	var m := MeshKit.combine(parts)
	_sc[key] = m
	return m


static func chimney(h := 2.4) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mat := Paint.get_mat("stone", Color.WHITE, {"flat_amount": 0.2, "variation": 0.4, "roughness": 0.95})
	var parts := []
	var y := 0.0
	var layer := 0
	while y < h:
		var bh := rng.randf_range(0.17, 0.24)
		var bx := -0.3
		while bx < 0.3 - 0.01:
			var bl := minf(rng.randf_range(0.22, 0.38), 0.3 - bx)
			var t := Color("#7d6e62").lerp(Color("#a8604a"), rng.randf() * 0.6).lerp(Color("#8a8a8a"), rng.randf() * 0.4)
			parts.append([MeshKit.rbox(Vector3(bl - 0.02, bh - 0.02, 0.62), 0.02, 0.1, 1, t), Transform3D(Basis.IDENTITY, Vector3(bx + bl * 0.5 + (layer % 2) * 0.05, y + bh * 0.5, 0))])
			bx += bl
		y += bh
		layer += 1
	_mi(n, MeshKit.combine(parts), mat)
	_mi(n, MeshKit.rbox(Vector3(0.78, 0.12, 0.78), 0.03, 0.1), Paint.stone(Color("#6a6a70")), Vector3(0, h + 0.06, 0))
	_mi(n, MeshKit.rbox(Vector3(0.5, 0.05, 0.5), 0.01, 0.0), Paint.get_mat("plain", Color("#1a1210")), Vector3(0, h + 0.13, 0))
	return n


static func barrel(tint := Color("#8a5a30")) -> Node3D:
	var n := Node3D.new()
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.3, 0.0), Vector2(0.34, 0.06), Vector2(0.42, 0.28), Vector2(0.45, 0.5), Vector2(0.42, 0.72), Vector2(0.34, 0.94), Vector2(0.3, 1.0), Vector2(0.28, 0.98), Vector2(0.0, 0.98)])
	var cols := PackedColorArray([Color(0.6, 0.6, 0.6), Color(0.65, 0.65, 0.65), Color(0.75, 0.75, 0.75), Color(0.9, 0.9, 0.9), Color.WHITE, Color(0.9, 0.9, 0.9), Color(0.8, 0.8, 0.8), Color(0.7, 0.7, 0.7), Color(0.5, 0.5, 0.5), Color(0.95, 0.95, 0.95)])
	var body := MeshKit.lathe(prof, 20, cols, "barrel")
	_mi(n, body, Paint.get_mat("wood", tint, {"grain": 1.0, "stroke_axis": Vector3(0, 1, 0), "stroke_stretch": 7.0, "grain_scale": 14.0, "wear": 0.5, "wear_color": tint.lightened(0.35)}))
	for hy in [0.12, 0.36, 0.64, 0.88]:
		var r := 0.3 + 0.15 * sin(PI * hy) ** 0.8 * 1.0
		var ring := MeshKit.lathe(PackedVector2Array([Vector2(r - 0.01, hy - 0.03), Vector2(r + 0.025, hy - 0.025), Vector2(r + 0.025, hy + 0.025), Vector2(r - 0.01, hy + 0.03)]), 20, PackedColorArray(), "hoop%s" % hy)
		_mi(n, ring, Paint.metal(Color("#4a4a52"), {"wear": 0.7}))
	return n


static func crate(size := Vector3(0.8, 0.7, 0.8), seed_v := 1, base := Color("#86644a")) -> Node3D:
	var n := Node3D.new()
	var mat := wood_white()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var bh := size.y / 4.0
	for side in 4:
		for r in 4:
			var tint := _tint(base, rng)
			var long_x := side % 2 == 0
			var sx := size.x if long_x else size.z
			var pm := MeshKit.rbox(Vector3(sx, bh * 0.94, 0.04), 0.01, 0.08, 1, tint)
			var ang := side * 90.0
			var dirv := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(ang))
			var off := dirv * (size.z * 0.5 if long_x else size.x * 0.5)
			parts.append([pm, Transform3D(Basis(Vector3.UP, deg_to_rad(ang)), off + Vector3(0, (r + 0.5) * bh, 0))])
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			parts.append([MeshKit.rbox(Vector3(0.06, size.y, 0.06), 0.012, 0.1, 1, base.darkened(0.25)), Transform3D(Basis.IDENTITY, Vector3(cx * (size.x * 0.5 - 0.02), size.y * 0.5, cz * (size.z * 0.5 - 0.02)))])
	parts.append([MeshKit.rbox(Vector3(size.x * 0.96, 0.04, size.z * 0.96), 0.01, 0.0, 1, base.darkened(0.1)), Transform3D(Basis.IDENTITY, Vector3(0, size.y - 0.02, 0))])
	_mi(n, MeshKit.combine(parts), mat)
	return n


static func torch(lit := true) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.5), Vector2(0.05, 0.62), Vector2(0.06, 0.72), Vector2(0.0, 0.72)]), 8, PackedColorArray(), "torchpole"), wood_white({"grain": 0.6}).duplicate())
	_mi(n, MeshKit.rbox(Vector3(0.14, 0.04, 0.14), 0.01), Paint.metal(Color("#3a3a42")), Vector3(0, 0.46, 0))
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.05, 0.62), Vector2(0.075, 0.66), Vector2(0.08, 0.74), Vector2(0.0, 0.76)]), 8, PackedColorArray(), "torchwrap"), Paint.get_mat("cloth", Color("#2a1c12")))
	if lit:
		var fl := Node3D.new()
		fl.position = Vector3(0, 0.76, 0)
		n.add_child(fl)
		var fm := MeshKit.blob(func(u: Vector3) -> Vector3:
			var p := u * Vector3(0.07, 0.17, 0.07)
			if u.y > 0.0:
				p.x *= 1.0 - u.y * 0.8
				p.z *= 1.0 - u.y * 0.8
			p.y += 0.12
			return p, func(u: Vector3, p: Vector3) -> Color:
			return Color("#ff7a1a").lerp(Color("#ffe27a"), clampf(1.0 - u.y * 0.5, 0.0, 1.0)) * Color(1, 1, 1, 1), 8, 10)
		_mi(fl, fm, Paint.glow(Color.WHITE, 2.4))
		var lt := FlickerLight.new()
		lt.light_color = Color("#ff9a3a")
		lt.light_energy = 1.1
		lt.omni_range = 6.5
		lt.position = Vector3(0, 0.9, 0)
		lt.flame = fl
		n.add_child(lt)
	return n


static func lantern(lit := true) -> Node3D:
	var n := Node3D.new()
	var metal := Paint.metal(Color("#2e2c34"), {"wear": 0.5})
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.1, 0.03), Vector2(0.08, 0.05), Vector2(0.0, 0.05)]), 10, PackedColorArray(), "lbase"), metal)
	for cx in [-1, 1]:
		for cz in [-1, 1]:
			_mi(n, MeshKit.rbox(Vector3(0.016, 0.26, 0.016), 0.004), metal, Vector3(cx * 0.075, 0.18, cz * 0.075))
	var gl := MeshKit.rbox(Vector3(0.15, 0.24, 0.15), 0.02, 0.0)
	_mi(n, gl, Paint.get_mat("glass", Color("#ffcf7a"), {"emission_strength": 1.6 if lit else 0.1, "emission_color": Color("#ffb347"), "variation": 0.0}), Vector3(0, 0.18, 0))
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.11, 0.3), Vector2(0.05, 0.36), Vector2(0.03, 0.4), Vector2(0.0, 0.41)]), 10, PackedColorArray(), "lcap"), metal)
	_mi(n, MeshKit.torus_ring(0.025, 0.007), metal, Vector3(0, 0.45, 0))
	if lit:
		var lt := FlickerLight.new()
		lt.light_color = Color("#ffb04a")
		lt.light_energy = 0.9
		lt.omni_range = 7.5
		lt.position = Vector3(0, 0.18, 0)
		n.add_child(lt)
	return n


## Hanging cloth banner with a gold laurel-ish emblem.
static func banner(w := 0.9, h := 2.2, color := Color("#8a2a3a"), emblem := true) -> Node3D:
	var n := Node3D.new()
	var cloth := MeshKit.cloth(w, h, 8, 14, func(u: float, v: float) -> Vector3:
		var fold := sin(u * PI * 3.0) * 0.035 * (0.3 + v)
		var swing := sin(v * 2.0) * 0.02
		var ragged := 0.0
		if v > 0.88:
			var k := int(u * 6.0)
			ragged = -((v - 0.88) * h) * (0.6 if k % 2 == 0 else 0.1) * 0.0
		return Vector3(0, ragged, fold + swing), func(u: float, v: float) -> Color:
		var c := color.lerp(color.darkened(0.35), v * 0.5)
		var edge := minf(u, 1.0 - u)
		if edge < 0.07:
			c = Color("#d8b048").lerp(c, edge / 0.07)
		return Color(c.r, c.g, c.b, 1.0 - clampf(v - 0.85, 0.0, 1.0) * 2.0))
	_mi(n, cloth, Paint.cloth(Color.WHITE, {"sss": 0.3, "wear": 0.0}), Vector3(0, -h * 0.5, 0))
	_mi(n, MeshKit.rbox(Vector3(w + 0.2, 0.06, 0.06), 0.015), wood_white({"grain": 0.5}), Vector3(0, 0.0, 0), Vector3.ZERO)
	if emblem:
		var gold := Paint.metal(Color("#e0b84a"), {"emission_strength": 0.15})
		_mi(n, MeshKit.torus_ring(w * 0.2, w * 0.035), gold, Vector3(0, -h * 0.4, 0.05), Vector3(90, 0, 0))
		_mi(n, MeshKit.rbox(Vector3(w * 0.22, w * 0.15, 0.03), 0.01), gold, Vector3(0, -h * 0.4, 0.06))
	return n


## Canvas sail: sagging cloth between four corners, stitched edge, grommets and rope.
static func sail(w := 3.0, h := 2.4, color := Color("#e8dcc0"), sag := 0.25) -> Node3D:
	var n := Node3D.new()
	var cloth := MeshKit.cloth(w, h, 12, 10, func(u: float, v: float) -> Vector3:
		var bulge := sin(u * PI) * sin(v * PI) * sag
		var wrinkle := sin(u * 18.0 + v * 6.0) * 0.012 * sin(v * PI)
		return Vector3(0, 0, bulge + wrinkle), func(u: float, v: float) -> Color:
		var c := color.lerp(Color("#bda884"), clampf(v * 0.5 + sin(u * 7.0) * 0.1, 0.0, 0.55))
		var edge := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
		if edge < 0.025:
			c = c.darkened(0.25)
		return Color(c.r, c.g, c.b, 1.0))
	_mi(n, cloth, Paint.cloth(Color.WHITE, {"sss": 0.45, "wrap": 0.7, "shade_fill": 0.4}))
	var rope := Paint.get_mat("cloth", Color("#b8a074"), {"roughness": 1.0})
	for c in [Vector3(-w * 0.5, h * 0.5, 0), Vector3(w * 0.5, h * 0.5, 0), Vector3(-w * 0.5, -h * 0.5, 0), Vector3(w * 0.5, -h * 0.5, 0)]:
		_mi(n, MeshKit.torus_ring(0.04, 0.012), Paint.metal(Color("#7a6a4a")), c)
	return n


static func door_double(w := 1.9, h := 2.9) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var panel := PackedColorArray()
	var parts := []
	var leaf_w := w * 0.5
	for side in [-1.0, 1.0]:
		var rows := 14
		for r in rows:
			var pm := MeshKit.rbox(Vector3(leaf_w - 0.03, h / rows * 0.97, 0.06), 0.01, 0.06, 1, _tint(Color("#6a4a7a") if false else Color("#5a4a78"), rng, 0.08))
			parts.append([pm, Transform3D(Basis.IDENTITY, Vector3(side * leaf_w * 0.5, (r + 0.5) * h / rows, 0))])
	_mi(n, MeshKit.combine(parts), wood_white({"grain": 0.5, "stroke_axis": Vector3(1, 0, 0)}))
	var iron := Paint.metal(Color("#3a3a46"), {"wear": 0.6})
	for side in [-1.0, 1.0]:
		for yy in [0.55, 1.45, 2.35]:
			_mi(n, MeshKit.rbox(Vector3(leaf_w * 0.92, 0.09, 0.025), 0.01), iron, Vector3(side * leaf_w * 0.5, yy, -0.04))
			for rv in 4:
				_mi(n, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.016), iron, Vector3(side * (leaf_w * 0.5 - leaf_w * 0.34 + rv * leaf_w * 0.22), yy, -0.056))
	var gold := Paint.metal(Color("#e0b84a"), {"emission_strength": 0.1})
	_mi(n, MeshKit.torus_ring(0.2, 0.03), gold, Vector3(0, h * 0.5, -0.05), Vector3(90, 0, 0))
	_mi(n, MeshKit.rbox(Vector3(0.14, 0.1, 0.03), 0.01), gold, Vector3(0, h * 0.5, -0.06))
	for side in [-1.0, 1.0]:
		_mi(n, MeshKit.torus_ring(0.06, 0.012), iron, Vector3(side * 0.12, h * 0.42, -0.06), Vector3(90, 0, 0))
	# timber frame + arch lintel
	var frame := wood_white({"grain": 0.9}).duplicate()
	_mi(n, MeshKit.rbox(Vector3(0.16, h + 0.2, 0.14), 0.03), Paint.wood(WOOD_BROWN), Vector3(-w * 0.5 - 0.08, h * 0.5 + 0.1, 0.0))
	_mi(n, MeshKit.rbox(Vector3(0.16, h + 0.2, 0.14), 0.03), Paint.wood(WOOD_BROWN), Vector3(w * 0.5 + 0.08, h * 0.5 + 0.1, 0.0))
	_mi(n, MeshKit.rbox(Vector3(w + 0.5, 0.18, 0.15), 0.04), Paint.wood(WOOD_BROWN), Vector3(0, h + 0.15, 0.0))
	return n


static func window(w := 1.0, h := 1.1, glow := true) -> Node3D:
	var n := Node3D.new()
	var glass := Paint.get_mat("glass", Color("#ffd27a"), {"emission_strength": 1.1 if glow else 0.15, "emission_color": Color("#ffb347"), "variation": 0.0, "albedo_b": Color("#ffe6a8")})
	_mi(n, MeshKit.rbox(Vector3(w, h, 0.05), 0.01, 0.0), glass, Vector3(0, h * 0.5, 0.0))
	var fr := Paint.wood(WOOD_DARK)
	for y in [0.0, h]:
		_mi(n, MeshKit.rbox(Vector3(w + 0.16, 0.08, 0.1), 0.02), fr, Vector3(0, y, -0.02))
	for x in [-w * 0.5, w * 0.5]:
		_mi(n, MeshKit.rbox(Vector3(0.08, h + 0.08, 0.1), 0.02), fr, Vector3(x, h * 0.5, -0.02))
	_mi(n, MeshKit.rbox(Vector3(0.05, h, 0.08), 0.01), fr, Vector3(0, h * 0.5, -0.03))
	_mi(n, MeshKit.rbox(Vector3(w, 0.05, 0.08), 0.01), fr, Vector3(0, h * 0.5, -0.03))
	# shutters
	for s in [-1.0, 1.0]:
		_mi(n, MeshKit.rbox(Vector3(w * 0.5, h * 0.98, 0.04), 0.01, 0.05, 1, Color("#7a5a3a")), wood_white({"grain": 0.9}), Vector3(s * (w * 0.5 + w * 0.3), h * 0.5, -0.1), Vector3(0, s * 55.0, 0))
	return n


static func sign_board(text: String, w := 2.6, h := 0.8) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.rbox(Vector3(w, h, 0.08), 0.03, 0.1), wood_white({"grain": 0.9}).duplicate(), Vector3.ZERO)
	_mi(n, MeshKit.rbox(Vector3(w + 0.1, 0.07, 0.1), 0.02), Paint.wood(WOOD_DARK), Vector3(0, h * 0.5, 0))
	_mi(n, MeshKit.rbox(Vector3(w + 0.1, 0.07, 0.1), 0.02), Paint.wood(WOOD_DARK), Vector3(0, -h * 0.5, 0))
	var l := Style.label3d(n, text, Vector3(0, 0.0, -0.05), 0.006 * (2.6 / w) * 1.3, Color("#f3d98a"), Vector3(0, 180, 0))
	l.outline_size = 14
	return n


static func rope_between(a: Vector3, b: Vector3, sag := 0.15, r := 0.018, color := Color("#b8a074")) -> MeshInstance3D:
	var pts: Array = []
	for i in 9:
		var t := float(i) / 8.0
		pts.append(a.lerp(b, t) + Vector3(0, -sin(t * PI) * sag, 0))
	var radii := PackedFloat32Array()
	for i in 9:
		radii.append(r)
	var m := MeshKit.tube(pts, radii, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = Paint.get_mat("cloth", color, {"roughness": 1.0, "variation": 0.4})
	return mi


static func railing(length := 4.0, h := 0.9) -> Node3D:
	var n := Node3D.new()
	var posts := int(length / 1.0) + 1
	var wm := Paint.wood(WOOD_BROWN)
	for i in posts:
		var x := -length * 0.5 + length * float(i) / (posts - 1)
		_mi(n, MeshKit.rbox(Vector3(0.1, h, 0.1), 0.02), wm, Vector3(x, h * 0.5, 0))
	_mi(n, MeshKit.rbox(Vector3(length, 0.07, 0.09), 0.02), wm, Vector3(0, h * 0.95, 0))
	_mi(n, MeshKit.rbox(Vector3(length, 0.05, 0.06), 0.015), wm, Vector3(0, h * 0.5, 0))
	return n


## Triangular gable wall (planks shrink toward the peak). Bottom at y=0, apex at y=h.
static func gable_wall(w: float, h: float, base: Color, seed_v := 3, plank_h := 0.22) -> ArrayMesh:
	var key := "gable|%s|%s|%s|%s" % [w, h, base.to_html(), seed_v]
	if _sc.has(key):
		return _sc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var rows := int(ceil(h / plank_h))
	for r in rows:
		var y := (r + 0.5) * plank_h
		var rw := w * (1.0 - (r + 1.0) * plank_h / h)
		if rw < 0.3:
			break
		parts.append([MeshKit.rbox(Vector3(rw, plank_h * 0.96, 0.05), 0.012, 0.08, 1, _tint(base, rng)), Transform3D(Basis.IDENTITY, Vector3(0, y, rng.randf_range(-0.008, 0.01)))])
	var m := MeshKit.combine(parts)
	_sc[key] = m
	return m


## Boardwalk: planks running along Z, gaps between, joists beneath. Top surface at y=0.
static func boardwalk(w: float, d: float, seed_v := 2, base := WOOD_GREY) -> ArrayMesh:
	var key := "bwalk|%s|%s|%s|%s" % [w, d, seed_v, base.to_html()]
	if _sc.has(key):
		return _sc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var n := int(w / 0.3)
	for i in n:
		var x := -w * 0.5 + (i + 0.5) * w / n
		var z0 := -d * 0.5
		while z0 < d * 0.5 - 0.05:
			var ln := minf(rng.randf_range(1.2, 2.8), d * 0.5 - z0)
			parts.append([MeshKit.rbox(Vector3(w / n - 0.025, 0.06, ln - 0.03), 0.014, 0.1, 1, _tint(base, rng, 0.2)), Transform3D(Basis(Vector3(1, 0, 0), rng.randf_range(-0.008, 0.008)), Vector3(x, -0.03 + rng.randf_range(-0.006, 0.006), z0 + ln * 0.5))])
			z0 += ln
	for j in 3:
		parts.append([MeshKit.rbox(Vector3(w, 0.12, 0.14), 0.02, 0.0, 1, Color("#5a4630")), Transform3D(Basis.IDENTITY, Vector3(0, -0.12, -d * 0.4 + j * d * 0.4))])
	var m := MeshKit.combine(parts)
	_sc[key] = m
	return m


static func mailbox() -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.rbox(Vector3(0.1, 1.2, 0.1), 0.02), Paint.wood(WOOD_BROWN), Vector3(0, 0.6, 0))
	var body := MeshKit.lathe(PackedVector2Array([Vector2(0.0, -0.3), Vector2(0.17, -0.3), Vector2(0.2, -0.22), Vector2(0.2, 0.0), Vector2(0.15, 0.12), Vector2(0.0, 0.16)]), 14, PackedColorArray(), "mbbody")
	_mi(n, body, Paint.painted(Color("#c0392b")), Vector3(0, 1.38, 0), Vector3(0, 0, 90), Vector3(1, 1, 1))
	_mi(n, MeshKit.rbox(Vector3(0.04, 0.3, 0.012), 0.004), Paint.painted(Color("#f0d060")), Vector3(0.24, 1.55, 0))
	_mi(n, MeshKit.rbox(Vector3(0.1, 0.07, 0.012), 0.004), Paint.painted(Color("#f0d060")), Vector3(0.28, 1.68, 0))
	_mi(n, MeshKit.rbox(Vector3(0.14, 0.02, 0.1), 0.004), Paint.get_mat("plain", Color("#ece0c0")), Vector3(-0.22, 1.5, 0.0), Vector3(0, 0, -8))
	return n


# ------------------------------------------------------------------ furniture & small props

static func table(w := 1.6, d := 0.9, h := 0.9, seed_v := 1) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var boards := 4
	for i in boards:
		var bw := d / boards
		parts.append([MeshKit.rbox(Vector3(w, 0.07, bw - 0.012), 0.015, 0.0, 1, _tint(Color("#8a6040"), rng, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0, h - 0.035, -d * 0.5 + (i + 0.5) * bw))])
	parts.append([MeshKit.rbox(Vector3(w * 0.9, 0.08, 0.07), 0.015, 0.0, 1, Color("#5a4028")), Transform3D(Basis.IDENTITY, Vector3(0, h - 0.11, -d * 0.3))])
	parts.append([MeshKit.rbox(Vector3(w * 0.9, 0.08, 0.07), 0.015, 0.0, 1, Color("#5a4028")), Transform3D(Basis.IDENTITY, Vector3(0, h - 0.11, d * 0.3))])
	_mi(n, MeshKit.combine(parts), wood_white({"grain": 0.9, "stroke_axis": Vector3(1, 0, 0)}))
	var leg := MeshKit.lathe(PackedVector2Array([Vector2(0.03, 0.0), Vector2(0.045, 0.05), Vector2(0.04, 0.3), Vector2(0.06, 0.42), Vector2(0.04, 0.55), Vector2(0.05, h - 0.1), Vector2(0.0, h - 0.1)]), 10, PackedColorArray(), "tleg")
	for lx in [-1, 1]:
		for lz in [-1, 1]:
			_mi(n, leg, Paint.wood(Color("#6a4a30")), Vector3(lx * (w * 0.5 - 0.1), 0.0, lz * (d * 0.5 - 0.1)))
	_mi(n, MeshKit.rbox(Vector3(w - 0.2, 0.05, 0.05), 0.01), Paint.wood(Color("#5a4028")), Vector3(0, 0.2, 0))
	return n


static func stool(h := 0.5) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, h), Vector2(0.2, h), Vector2(0.22, h - 0.02), Vector2(0.21, h - 0.07), Vector2(0.0, h - 0.07)]), 14, PackedColorArray(), "stoolseat"), wood_white({"grain": 0.9}))
	for k in 3:
		var a := TAU * k / 3.0
		_mi(n, MeshKit.rbox(Vector3(0.05, h - 0.05, 0.05), 0.012), Paint.wood(Color("#5a4028")), Vector3(cos(a) * 0.12, (h - 0.05) * 0.5, sin(a) * 0.12), Vector3(sin(a) * 9.0, 0, -cos(a) * 9.0))
	return n


static func mug(foam := true) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.02), Vector2(0.06, 0.12), Vector2(0.058, 0.13), Vector2(0.0, 0.13)]), 12, PackedColorArray(), "mug"), Paint.wood(Color("#6a4528"), {"grain": 0.6}))
	_mi(n, MeshKit.torus_ring(0.035, 0.008), Paint.metal(Color("#5a5a62")), Vector3(0.075, 0.07, 0), Vector3(0, 0, 0), Vector3(1.0, 1.2, 1.0))
	for hy in [0.025, 0.1]:
		_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.056, hy - 0.006), Vector2(0.062, hy - 0.005), Vector2(0.062, hy + 0.005), Vector2(0.056, hy + 0.006)]), 12, PackedColorArray(), "mughoop%s" % hy), Paint.metal(Color("#6a6a74")))
	if foam:
		_mi(n, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.056, 0.035, 0.056)), Paint.get_mat("cloth", Color("#f4efe0"), {"roughness": 0.8}), Vector3(0, 0.135, 0))
	return n


static func bottle(c := Color("#3e9c5a")) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.052, 0.03), Vector2(0.052, 0.17), Vector2(0.03, 0.22), Vector2(0.018, 0.27), Vector2(0.02, 0.31), Vector2(0.0, 0.31)]), 10, PackedColorArray(), "bottle"), Paint.get_mat("glass", c, {"emission_strength": 0.35, "emission_color": c.lightened(0.2), "variation": 0.0}))
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.015, 0.28), Vector2(0.024, 0.285), Vector2(0.024, 0.31), Vector2(0.015, 0.315)]), 8, PackedColorArray(), "cork"), Paint.wood(Color("#8a6a40")))
	return n


static func candle(lit := true, h := 0.12) -> Node3D:
	var n := Node3D.new()
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.026, h), Vector2(0.0, h)]), 10, PackedColorArray(), "candle%s" % h), Paint.get_mat("cloth", Color("#f1e8cc"), {"sss": 0.6, "roughness": 0.6}))
	_mi(n, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.065, 0.015), Vector2(0.04, 0.02), Vector2(0.0, 0.02)]), 10, PackedColorArray(), "candlebase"), Paint.metal(Color("#b8a060")))
	if lit:
		var fl := Node3D.new()
		fl.position = Vector3(0, h + 0.03, 0)
		n.add_child(fl)
		var fm := MeshKit.blob(func(u: Vector3) -> Vector3:
			var p := u * Vector3(0.016, 0.04, 0.016)
			if u.y > 0.0:
				p.x *= 1.0 - u.y * 0.85
				p.z *= 1.0 - u.y * 0.85
			p.y += 0.02
			return p, func(u: Vector3, p: Vector3) -> Color: return Color("#ffd27a").lerp(Color("#ff8a2a"), clampf(-u.y * 0.5 + 0.2, 0.0, 1.0)), 6, 8)
		_mi(fl, fm, Paint.glow(Color.WHITE, 3.0))
		var lt := FlickerLight.new()
		lt.light_color = Color("#ffb85a")
		lt.light_energy = 0.7
		lt.omni_range = 4.2
		lt.position = Vector3(0, h + 0.15, 0)
		lt.flame = fl
		n.add_child(lt)
	return n


static func sack(c := Color("#a89468"), seed_v := 1) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var m := MeshKit.blob(func(u: Vector3) -> Vector3:
		var p := u * Vector3(0.28, 0.34, 0.24)
		p.x *= 1.0 - 0.3 * clampf(u.y, 0.0, 1.0)
		p.z *= 1.0 - 0.3 * clampf(u.y, 0.0, 1.0)
		p += Vector3(sin(u.y * 6.0) * 0.015, 0.0, sin(u.x * 5.0 + u.z * 3.0) * 0.015)
		if p.y < -0.28:
			p.y = -0.28
		return p, func(u: Vector3, p: Vector3) -> Color: return Color(c.r, c.g, c.b, 1.0).darkened(clampf(-u.y * 0.25, 0.0, 0.3)), 10, 12)
	_mi(n, m, Paint.cloth(Color.WHITE, {"stroke_stretch": 1.5, "noise_scale": 5.0}), Vector3(0, 0.3, 0), Vector3(0, rng.randf() * 360.0, 0))
	_mi(n, MeshKit.torus_ring(0.07, 0.015), Paint.get_mat("cloth", Color("#6a5638")), Vector3(0, 0.6, 0), Vector3(90, 0, 0))
	return n


## Flat patterned rug in the XZ plane, centred on the origin (top at y~0.02).
static func rug(w := 6.0, d := 4.0, main := Color("#a8322f"), trim := Color("#d8a64a")) -> Node3D:
	var n := Node3D.new()
	var cloth := MeshKit.cloth(w, d, 30, 20, func(u: float, v: float) -> Vector3:
		return Vector3(0, 0, sin(u * 21.0 + v * 9.0) * 0.004), func(u: float, v: float) -> Color:
		var eu := minf(u, 1.0 - u) * w
		var ev := minf(v, 1.0 - v) * d
		var e := minf(eu, ev)
		var c := main
		if e < 0.09:
			c = trim
		elif e < 0.2:
			c = main.darkened(0.25)
		elif e < 0.27:
			c = trim.darkened(0.15)
		else:
			# diamond lattice
			var du := absf(fposmod(u * w * 1.4, 1.0) - 0.5)
			var dv := absf(fposmod(v * d * 1.4, 1.0) - 0.5)
			if du + dv < 0.2:
				c = main.lightened(0.08)
			elif du + dv < 0.27:
				c = trim.darkened(0.2)
		var wear := 0.94 + 0.06 * sin(u * 31.0) * sin(v * 23.0)
		return Color(c.r * wear, c.g * wear, c.b * wear, 1.0))
	var mi := _mi(n, cloth, Paint.cloth(Color.WHITE, {"sss": 0.1, "variation": 0.2}), Vector3(0, 0.03, 0), Vector3(-90, 0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n


## Rough-hewn stone block wall in the XY plane (front faces -Z), bottom at y=0.
static func stone_wall(w: float, h: float, seed_v := 1, depth := 0.35) -> ArrayMesh:
	var key := "swall|%s|%s|%s" % [w, h, seed_v]
	if _sc.has(key):
		return _sc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	var y := 0.0
	var layer := 0
	while y < h - 0.01:
		var bh := minf(rng.randf_range(0.26, 0.4), h - y)
		var x := -w * 0.5
		var off := -rng.randf_range(0.0, 0.3)
		x += off
		while x < w * 0.5 - 0.01:
			var bl := rng.randf_range(0.45, 0.85)
			var cx := clampf(x, -w * 0.5, w * 0.5)
			var ex := clampf(x + bl, -w * 0.5, w * 0.5)
			if ex - cx > 0.12:
				var t := Color("#8a8680").lerp(Color("#a89a88"), rng.randf()).lerp(Color("#6a6862"), rng.randf() * 0.4)
				var pm := MeshKit.rbox(Vector3(ex - cx - 0.03, bh - 0.03, depth), 0.04, 0.12, 2, t)
				parts.append([pm, Transform3D(Basis(Vector3(0, 0, 1), rng.randf_range(-0.01, 0.01)), Vector3((cx + ex) * 0.5, y + bh * 0.5, rng.randf_range(-0.02, 0.03)))])
			x += bl
		y += bh
		layer += 1
	var m := MeshKit.combine(parts)
	_sc[key] = m
	return m


static func shelf(w := 2.0, d := 0.3) -> Node3D:
	var n := Node3D.new()
	var wm := Paint.wood(Color("#6a4a30"), {"grain": 0.9})
	_mi(n, MeshKit.rbox(Vector3(w, 0.06, d), 0.015), wm)
	for sx in [-1.0, 1.0]:
		_mi(n, MeshKit.rbox(Vector3(0.06, 0.2, d * 0.9), 0.012), wm, Vector3(sx * (w * 0.5 - 0.15), -0.12, 0), Vector3.ZERO)
	return n


static func log_pile(count := 4) -> Node3D:
	var n := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in count:
		var r := rng.randf_range(0.07, 0.1)
		var lg := MeshKit.tube([Vector3(-0.5, 0, 0), Vector3(0, 0, 0.0), Vector3(0.5, 0, 0)], PackedFloat32Array([r, r * 1.05, r]), 8, PackedColorArray([Color("#4a3322"), Color("#6a4a30"), Color("#4a3322")]))
		_mi(n, lg, Paint.get_mat("wood", Color.WHITE, {"grain": 1.0, "stroke_axis": Vector3(1, 0, 0)}), Vector3(rng.randf_range(-0.05, 0.05), r + (i / 3) * 0.17, (i % 3) * 0.17 - 0.17), Vector3(0, rng.randf_range(-12, 12), rng.randf_range(-4, 4)))
	return n
