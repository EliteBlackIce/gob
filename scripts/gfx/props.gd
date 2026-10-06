class_name Props
extends RefCounted
## Reusable assets. Foliage first; structures and furniture live further down.

static var _pc := {}


static func leaf_mat(extra := {}) -> ShaderMaterial:
	var e := {"wind": 0.05}
	e.merge(extra, true)
	return Paint.leaf(Color.WHITE, e)


static func bark_mat() -> ShaderMaterial:
	return Paint.get_mat("wood", Color.WHITE, {"grain": 0.55, "variation": 0.5, "stroke_axis": Vector3(0, 1, 0), "stroke_stretch": 6.0, "wear": 0.0, "roughness": 0.9, "specular": 0.05, "wind": 0.03})


## Palm tree: curved ringed trunk + crown of arching fronds + coconuts. Two surfaces.
static func palm(variant: int) -> ArrayMesh:
	var key := "palm%d" % variant
	if _pc.has(key):
		return _pc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + variant * 17
	var H := rng.randf_range(4.8, 6.4)
	var lean := rng.randf_range(0.5, 1.5) * (1.0 if variant % 2 == 0 else -1.0)
	var pts: Array = []
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	var n := 16
	for i in n:
		var t := float(i) / (n - 1)
		pts.append(Vector3(lean * t * t * 0.9, t * H, sin(t * PI * 1.2) * 0.22))
		var ring := 1.0 + 0.1 * sin(t * H * 13.0)
		radii.append(lerpf(0.26, 0.11, t) * ring * (1.0 + 0.5 * pow(1.0 - t, 6.0)))
		var band := 0.82 + 0.18 * sin(t * H * 13.0 + 1.0)
		var c := Color("#6e5236").lerp(Color("#a68660"), t * 0.8)
		cols.append(Color(c.r * band, c.g * band, c.b * band, 1.0 - 0.0))
	pts.append(pts[n - 1] + Vector3(0.0, 0.12, 0.0))
	radii.append(0.0)
	cols.append(cols[n - 1])
	var trunk := MeshKit.tube(pts, radii, 9, cols)
	var top: Vector3 = pts[n - 1] + Vector3(0, 0.05, 0)
	var parts := []
	var fr := MeshKit.frond(rng.randf_range(2.6, 3.2), 15, 1.0, 0.16, 0.9)
	for k in 11:
		var yaw := TAU * float(k) / 11.0 + rng.randf_range(-0.2, 0.2)
		var tilt := rng.randf_range(-0.35, 0.35) if k % 2 == 0 else rng.randf_range(0.1, 0.55)
		var sc := rng.randf_range(0.85, 1.15)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3(0, 0, 1), tilt)
		parts.append([fr, Transform3D(b.scaled(Vector3.ONE * sc), top)])
	for k in 4:
		var yaw2 := TAU * float(k) / 4.0 + 0.4
		var b2 := Basis(Vector3.UP, yaw2) * Basis(Vector3(0, 0, 1), rng.randf_range(1.05, 1.3))
		parts.append([MeshKit.frond(1.8, 11, 0.7, 0.12, 0.4), Transform3D(b2, top)])
	var fronds := MeshKit.combine(parts)
	var coco_parts := [[trunk, Transform3D.IDENTITY]]
	for k in 4:
		var a := TAU * float(k) / 4.0 + variant
		var cm := MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.11, func(u: Vector3, p: Vector3) -> Color: return Color("#4a6a2a").lerp(Color("#6a4a2a"), clampf(-u.y * 0.7 + 0.3, 0.0, 1.0)), 7, 9)
		coco_parts.append([cm, Transform3D(Basis.IDENTITY, top + Vector3(cos(a) * 0.17, -0.12, sin(a) * 0.17))])
	var trunk_all := MeshKit.combine(coco_parts)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk_all.surface_get_arrays(0))
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fronds.surface_get_arrays(0))
	out.surface_set_material(0, bark_mat())
	out.surface_set_material(1, leaf_mat({"wind": 0.045}))
	_pc[key] = out
	return out


static func big_leaf_plant(variant: int) -> ArrayMesh:
	var m := MeshKit.leaf_plant(6 + variant % 3, 0.9 + 0.15 * (variant % 3), 40 + variant, Color("#237a2a"), Color("#5fb53a"))
	return _with_mat(m, leaf_mat({"wind": 0.06}), "bigleaf%d" % variant)


static func red_plant(variant: int) -> ArrayMesh:
	var m := MeshKit.red_plant(0.9 + 0.2 * (variant % 2), 70 + variant)
	return _with_mat(m, leaf_mat({"wind": 0.05, "sss_color": Color("#ff7a3a"), "sss": 0.7}), "red%d" % variant)


static func fern(variant: int) -> ArrayMesh:
	var key := "fern%d" % variant
	if _pc.has(key):
		return _pc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 200 + variant
	var parts := []
	var fr := MeshKit.frond(1.0, 13, 0.42, 0.07, 0.35)
	for k in 8:
		var b := Basis(Vector3.UP, TAU * float(k) / 8.0 + rng.randf_range(-0.2, 0.2)) * Basis(Vector3(0, 0, 1), rng.randf_range(0.2, 0.8))
		parts.append([fr, Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), Vector3.ZERO)])
	return _with_mat(MeshKit.combine(parts), leaf_mat({"wind": 0.07}), key)


static func grass(variant: int) -> ArrayMesh:
	var key := "grass%d" % variant
	if _pc.has(key):
		return _pc[key]
	var parts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 300 + variant
	for k in 3:
		var t := MeshKit.grass_tuft(8, 0.5 + 0.2 * rng.randf(), 300 + variant * 3 + k)
		parts.append([t, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.18, 0.18), 0, rng.randf_range(-0.18, 0.18)))])
	return _with_mat(MeshKit.combine(parts), leaf_mat({"wind": 0.3, "shade_fill": 0.35}), key)


static func bush(variant: int) -> ArrayMesh:
	var key := "bush%d" % variant
	if _pc.has(key):
		return _pc[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 400 + variant
	var parts := []
	for k in 5:
		var r := rng.randf_range(0.45, 0.8)
		var m := MeshKit.blob(func(u: Vector3) -> Vector3:
			var d := 1.0 + 0.18 * sin(u.x * 5.0 + u.y * 3.0) * sin(u.z * 4.0)
			return u * r * d * Vector3(1.0, 0.75, 1.0), func(u: Vector3, p: Vector3) -> Color:
			return Color("#1f5a22").lerp(Color("#6fb83a"), clampf(u.y * 0.5 + 0.5, 0.0, 1.0)) * Color(1, 1, 1, 1), 9, 12)
		parts.append([m, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-0.5, 0.5), r * 0.55, rng.randf_range(-0.5, 0.5)))])
	return _with_mat(MeshKit.combine(parts), leaf_mat({"wind": 0.025}), key)


static func _with_mat(m: ArrayMesh, mat: Material, key: String) -> ArrayMesh:
	if _pc.has(key):
		return _pc[key]
	m.surface_set_material(0, mat)
	_pc[key] = m
	return m


static func rock_mat() -> ShaderMaterial:
	return Paint.get_mat("stone", Color.WHITE, {"variation": 0.35, "noise_scale": 1.6, "flat_amount": 0.45, "wear": 0.0})
