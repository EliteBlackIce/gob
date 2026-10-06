class_name GoblinModel
extends RefCounted
## The mascot: a lanky, grinning postal goblin, sculpted from procedural meshes and
## driven by a small jointed rig (hips, spine, neck/head, jaw, ears, arms with elbows,
## legs with knees, satchel). Facing +Z, feet on y=0, ~1.45 m with the cap.

const SKIN := Color("#738a38")
const SKIN_DARK := Color("#6a7a2c")
const TUNIC := Color("#2f3c86")
const LEATHER := Color("#6a4126")
const PAPER := Color("#ece0c0")


# ------------------------------------------------------------------ helpers

static func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	parent.add_child(m)
	return m


static func _joint(parent: Node3D, name: String, pos: Vector3, rig: Dictionary) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	parent.add_child(j)
	rig[name] = j
	return j


static func _interp(rows: Array, y: float, idx: int) -> float:
	# rows: [[y, a, b, ...], ...] ascending y
	if y <= rows[0][0]:
		return rows[0][idx]
	for i in rows.size() - 1:
		if y <= rows[i + 1][0]:
			var t: float = (y - rows[i][0]) / (rows[i + 1][0] - rows[i][0])
			return lerpf(rows[i][idx], rows[i + 1][idx], t)
	return rows[rows.size() - 1][idx]


## Elliptical loft through rows [y, rx, rz, zoff, Color]. Closed at both ends.
static func _loft(rows: Array, segs := 20) -> ArrayMesh:
	var n := rows.size()
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for r in n:
		var row: Array = rows[r]
		for c in segs + 1:
			var a := TAU * float(c) / segs
			pts.append(Vector3(cos(a) * row[1], row[0], sin(a) * row[2] + row[3]))
			var col: Color = row[4]
			cs.append(col)
	var mb := MB.new()
	mb.grid(pts, cs, n, segs + 1)
	return mb.commit(true)


static func _vc(c: Color, ao := 1.0, wear := 0.0) -> Color:
	return Color(c.r * ao, c.g * ao, c.b * ao, 1.0 - wear)


# ------------------------------------------------------------------ parts

## Skull: brow ridge, hollow cheeks, pointed chin, recessed grin. Local origin = head centre.
static func _head_mesh(skin: Color) -> ArrayMesh:
	var deform := func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.165, u.y * 0.19, u.z * 0.175)
		if u.y < 0.0:
			p.x *= 1.0 + 0.42 * u.y
			if u.z > 0.0:
				p.z += 0.045 * (-u.y) * u.z
			p.y -= 0.03 * (-u.y)
		# cheek hollows
		if absf(u.x) > 0.45 and u.y > -0.55 and u.y < 0.1 and u.z > 0.15:
			p.x *= 0.9
			p.z *= 0.96
		# heavy brow ridge
		if u.z > 0.35 and u.y > 0.12 and u.y < 0.5:
			var k := smoothstep(0.12, 0.3, u.y) * (1.0 - smoothstep(0.3, 0.5, u.y))
			p.z += 0.03 * k * u.z
		# flatter back of the skull
		if u.z < -0.2:
			p.z *= 0.92
		# eye sockets
		for s in [-1.0, 1.0]:
			var d := Vector2(u.x - s * 0.42, u.y - 0.2)
			if u.z > 0.5 and d.length() < 0.2:
				p.z -= 0.022 * (1.0 - d.length() / 0.2)
		# mouth: curved band recessed (smile: corners higher)
		var ym := -0.56 + 0.62 * u.x * u.x
		var dm := absf(u.y - ym)
		if u.z > 0.5 and absf(u.x) < 0.6 and dm < 0.075:
			p.z -= 0.036 * (1.0 - dm / 0.075) * (1.0 - smoothstep(0.4, 0.6, absf(u.x)))
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var c := skin
		# warmer, yellower on cheeks / forehead, darker in sockets and under the jaw
		c = c.lerp(Color("#a09a3c"), clampf(0.3 * (u.y + 0.2), 0.0, 0.3))
		c = c.lerp(Color("#c98a45"), clampf((absf(u.x) - 0.45) * 0.9 * (u.z + 0.4), 0.0, 0.3))
		var ym := -0.56 + 0.62 * u.x * u.x
		var dm := absf(u.y - ym)
		if u.z > 0.5 and absf(u.x) < 0.6 and dm < 0.05:
			c = Color("#3a1410")
		for s in [-1.0, 1.0]:
			var d := Vector2(u.x - s * 0.42, u.y - 0.2)
			if u.z > 0.4 and d.length() < 0.26:
				c = c.lerp(SKIN_DARK.darkened(0.2), 0.55 * (1.0 - d.length() / 0.26))
		var ao := 1.0 - clampf(-u.y - 0.4, 0.0, 0.6) * 0.5
		return _vc(c, ao)
	return MeshKit.blob(deform, colorf, 22, 30)


static func _ear_mesh(skin: Color) -> ArrayMesh:
	# grows along +X (outward); caller mirrors for the other side
	var L := 0.42
	var W := 0.15
	var deform := func(u: Vector3) -> Vector3:
		var t := (u.x + 1.0) * 0.5
		var s := W * sin(PI * pow(t, 0.62)) * (1.0 - 0.25 * t)
		var p := Vector3(t * L, u.y * s, u.z * 0.028 * (1.0 - 0.4 * t) * (0.3 + s / W))
		p.y += t * t * 0.1
		p.z -= t * 0.05
		# slight cup toward the face
		p.z += (u.y * u.y) * s * 0.18
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var t := (u.x + 1.0) * 0.5
		var inner := Color("#c9783a")
		var outer := skin.lerp(Color("#a09a3c"), 0.18)
		var c := outer.lerp(inner, clampf(0.35 + u.z * 0.9, 0.0, 1.0)).lerp(Color("#d99a50"), t * 0.35)
		var edge := 1.0 - absf(u.y)
		return _vc(c.lerp(skin.darkened(0.15), clampf(1.0 - edge * 3.0, 0.0, 0.5)), 1.0, 0.0)
	return MeshKit.blob(deform, colorf, 12, 18)


static func _nose_mesh(skin: Color) -> ArrayMesh:
	var deform := func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.046, u.y * 0.08, u.z * 0.078)
		# long bulbous nose that points down at the tip
		if u.y < 0.0:
			p.x *= 1.0 + 0.7 * (-u.y)
			p.z += 0.03 * (-u.y)
		p.z += 0.03 * (u.y + 1.0)
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var c := skin.lerp(Color("#d88a3f"), clampf(0.2 + (-u.y) * 0.8, 0.0, 0.85))
		return _vc(c, 1.0)
	return MeshKit.blob(deform, colorf, 12, 16)


static func _skirt(rx: float, rz: float, drop: float, tabs: int, col: Color, zoff := 0.0, bot := 1.25) -> ArrayMesh:
	var cols := tabs * 2 + 1
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for row in 2:
		for c in cols:
			var a := TAU * float(c) / (cols - 1)
			var k := 1.0 if row == 0 else bot
			var y := 0.0
			var cc := _vc(col, 1.0, 0.0)
			if row == 1:
				var long_tab := (c % 2 == 0)
				var h := sin(float(c) * 12.9898) * 0.5 + 0.5
				y = -drop * ((1.0 if long_tab else 0.5) + 0.25 * h) - 0.02
				cc = _vc(col, 0.7, 0.9)
			pts.append(Vector3(cos(a) * rx * k, y, sin(a) * rz * k + zoff))
			cs.append(cc if row == 1 else _vc(col, 0.95))
	var mb := MB.new()
	mb.grid(pts, cs, 2, cols)
	return mb.commit(true)


static func _cap_crown(c: Color) -> ArrayMesh:
	var deform := func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.225, u.y * 0.115, u.z * 0.235)
		if u.y < 0.0:
			p.y *= 0.2
		# crown sags a little to one side, bulges at the back
		p.y -= 0.018 * u.x
		if u.z < 0.0:
			p.z *= 1.06
		p.x += 0.012 * u.y
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var wr := 0.5 + 0.5 * sin(u.x * 9.0 + u.z * 7.0) * (1.0 - absf(u.y))
		var cc := c.lerp(c.lightened(0.18), clampf(u.y, 0.0, 1.0) * 0.6).lerp(c.darkened(0.2), wr * 0.25)
		return _vc(cc, 1.0 - clampf(-u.y, 0.0, 1.0) * 0.3)
	return MeshKit.blob(deform, colorf, 12, 22)


static func _visor(c: Color) -> ArrayMesh:
	var deform := func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.17, u.y * 0.012, u.z * 0.075)
		p.y -= (u.z * u.z) * 0.012 + u.x * u.x * 0.018
		p.z += 0.075
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		return _vc(c.lightened(0.18 if u.y < 0.0 else 0.0), 1.0, clampf(absf(u.x) * 0.5, 0.0, 0.4))
	return MeshKit.blob(deform, colorf, 8, 16)


static func _tube_part(pts: Array, radii: PackedFloat32Array, col: Color, ao_end := 1.0, sides := 10) -> ArrayMesh:
	var cols := PackedColorArray()
	for i in pts.size():
		var t := float(i) / maxi(pts.size() - 1, 1)
		cols.append(_vc(col, lerpf(1.0, ao_end, t)))
	return MeshKit.tube(pts, radii, sides, cols)


static func _boot(c: Color) -> ArrayMesh:
	var deform := func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.1, u.y * 0.078, u.z * 0.19)
		if u.y < 0.0:
			p.y *= 0.9
		# toe curls up a touch, heel is blocky
		if u.z > 0.3:
			p.y += 0.02 * (u.z - 0.3)
			p.x *= 1.0 - 0.25 * (u.z - 0.3)
		if u.z < -0.5:
			p.x *= 0.85
		p.z += 0.045
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var sole := smoothstep(-0.55, -0.85, u.y)
		var cc := c.lerp(Color("#24160d"), sole)
		return _vc(cc, 1.0 - sole * 0.2, clampf(0.6 - absf(u.y) * 1.0, 0.0, 0.5) * 0.7)
	return MeshKit.blob(deform, colorf, 10, 16)


static func _hand(skin: Color) -> Node3D:
	var h := Node3D.new()
	var mat := Paint.skin(Color.WHITE)
	var palm := MeshKit.blob(func(u): return Vector3(u.x * 0.03, u.y * 0.04, u.z * 0.02), func(u, p): return _vc(skin.lerp(Color("#b5a845"), 0.2), 1.0), 8, 10)
	_mi(h, palm, mat, Vector3(0, -0.035, 0))
	# three chunky fingers + thumb
	for i in 3:
		var x := -0.018 + i * 0.018
		var ln := 0.05 - absf(i - 1) * 0.006
		var pts := [Vector3(x, -0.06, 0.004), Vector3(x, -0.06 - ln * 0.55, 0.01), Vector3(x, -0.06 - ln, 0.026)]
		var f := MeshKit.tube(pts, PackedFloat32Array([0.0095, 0.0085, 0.0]), 6, PackedColorArray([_vc(skin, 1.0), _vc(skin, 0.95), _vc(skin.lerp(Color("#d88a3f"), 0.5), 0.9)]))
		_mi(h, f, mat)
	var th := MeshKit.tube([Vector3(0.028, -0.03, 0.0), Vector3(0.045, -0.055, 0.012), Vector3(0.048, -0.08, 0.028)], PackedFloat32Array([0.011, 0.0095, 0.0]), 6, PackedColorArray([_vc(skin, 1.0), _vc(skin, 0.95), _vc(skin.lerp(Color("#d88a3f"), 0.5), 0.9)]))
	_mi(h, th, mat)
	return h


# ------------------------------------------------------------------ build

static func build(tunic := TUNIC, skin := SKIN, with_hat := true, hat_color := Color("#2d3a82")) -> Node3D:
	var root := Node3D.new()
	root.name = "GoblinModel"
	var rig := {}
	var m_skin := Paint.skin(Color.WHITE)
	var m_cloth := Paint.cloth(Color.WHITE, {"stroke_stretch": 2.5})
	var m_leather := Paint.get_mat("wood", Color.WHITE, {"grain": 0.35, "variation": 0.4, "wear": 0.8, "roughness": 0.6, "specular": 0.25, "wear_color": Color("#a67c4e")})
	var bag_c := Color("#7a4d2a")
	var m_bag := Paint.get_mat("wood", bag_c, {"grain": 0.3, "variation": 0.4, "wear": 0.8, "roughness": 0.6, "specular": 0.25, "wear_color": Color("#a67c4e")})
	var m_metal := Paint.metal(Color("#cdbb78"))
	var m_teeth := Paint.get_mat("plain", Color("#e6d8a2"), {"roughness": 0.4, "specular": 0.4, "rim": 0.2})
	var m_dark := Paint.get_mat("plain", Color("#20120c"), {"roughness": 0.9, "specular": 0.05, "rim": 0.1})
	var m_hair := Paint.get_mat("cloth", Color("#2a1810"), {"roughness": 0.8, "specular": 0.3, "sss": 0.0})

	var hips := _joint(root, "Hips", Vector3(0, 0.76, 0), rig)
	var spine := _joint(hips, "Spine", Vector3(0, 0.02, 0), rig)
	var chest := _joint(spine, "Chest", Vector3(0, 0.2, 0), rig)
	var neck := _joint(chest, "Neck", Vector3(0, 0.2, 0.02), rig)
	var head := _joint(neck, "Head", Vector3(0, 0.12, 0.03), rig)
	var jaw := _joint(head, "Jaw", Vector3(0, -0.1, 0.06), rig)
	var ear_l := _joint(head, "EarL", Vector3(0.15, 0.05, -0.01), rig)
	var ear_r := _joint(head, "EarR", Vector3(-0.15, 0.05, -0.01), rig)
	var cap := _joint(head, "Cap", Vector3(0, 0.105, -0.012), rig)
	var back := _joint(chest, "Back", Vector3(0, 0.03, -0.14), rig)
	head.scale = Vector3.ONE * 1.12

	# ---- legs
	for side in [1.0, -1.0]:
		var tag := "L" if side > 0 else "R"
		var thigh := _joint(hips, "Thigh" + tag, Vector3(0.095 * side, -0.02, 0), rig)
		var shin := _joint(thigh, "Shin" + tag, Vector3(0, -0.33, 0), rig)
		var foot := _joint(shin, "Foot" + tag, Vector3(0, -0.33, 0), rig)
		var trous := Color("#5b4630")
		var th_m := _tube_part([Vector3(0, 0.0, 0), Vector3(0, -0.16, 0.01), Vector3(0, -0.33, 0)], PackedFloat32Array([0.082, 0.068, 0.054]), trous, 0.8, 10)
		_mi(thigh, th_m, m_cloth)
		var kn := MeshKit.blob(func(u): return u * Vector3(0.06, 0.048, 0.06), func(u, p): return _vc(trous.lightened(0.1), 0.9), 6, 8)
		_mi(thigh, kn, m_cloth, Vector3(0, -0.33, 0.01))
		var sh_m := _tube_part([Vector3(0, 0, 0.0), Vector3(0, -0.15, -0.012), Vector3(0, -0.29, -0.005)], PackedFloat32Array([0.052, 0.046, 0.058]), trous.darkened(0.1), 0.85, 10)
		_mi(shin, sh_m, m_cloth)
		# boot with folded cuff + laces strap
		var cuff := MeshKit.lathe(PackedVector2Array([Vector2(0.06, -0.19), Vector2(0.076, -0.195), Vector2(0.083, -0.245), Vector2(0.076, -0.3), Vector2(0.064, -0.305)]), 14, PackedColorArray([_vc(Color("#6e4a2a"), 0.8), _vc(Color("#7a5230"), 1.0), _vc(Color("#7a5230"), 1.0), _vc(Color("#7a5230"), 0.95), _vc(Color("#4a2e18"), 0.7)]))
		_mi(shin, cuff, m_leather, Vector3(0, 0.0, 0.0))
		_mi(foot, _boot(Color("#5a3a22")), m_leather, Vector3(0, -0.04, 0.0), Vector3(0, side * 4, 0))
		_mi(foot, MeshKit.rbox(Vector3(0.03, 0.05, 0.01), 0.005), m_metal, Vector3(0, 0.0, 0.07), Vector3(-30, 0, 0))

	# ---- torso (tunic), tattered hem, belt
	var tunic_rows: Array = [
		[-0.1, 0.125, 0.098, 0.0, _vc(tunic.darkened(0.25), 0.8)],
		[0.0, 0.135, 0.105, 0.0, _vc(tunic, 0.9)],
		[0.1, 0.15, 0.113, 0.005, _vc(tunic, 1.0)],
		[0.22, 0.176, 0.125, 0.01, _vc(tunic.lightened(0.05), 1.0)],
		[0.31, 0.19, 0.115, 0.0, _vc(tunic.lightened(0.08), 1.0)],
		[0.37, 0.13, 0.085, -0.005, _vc(tunic.darkened(0.1), 0.9)],
		[0.41, 0.06, 0.05, -0.008, _vc(tunic.darkened(0.2), 0.8)],
	]
	_mi(spine, _loft(tunic_rows, 22), m_cloth)
	_mi(spine, _skirt(0.137, 0.106, 0.2, 9, tunic.darkened(0.12)), m_cloth, Vector3(0, -0.07, 0))
	_mi(spine, _skirt(0.14, 0.11, 0.27, 6, tunic.darkened(0.25), -0.02, 1.18), m_cloth, Vector3(0, -0.06, -0.01))
	# neck
	_mi(chest, _tube_part([Vector3(0, 0.12, 0.0), Vector3(0, 0.22, 0.015), Vector3(0, 0.27, 0.04)], PackedFloat32Array([0.05, 0.036, 0.04]), skin.darkened(0.05), 1.0, 10), m_skin)
	# tunic collar
	var collar := MeshKit.lathe(PackedVector2Array([Vector2(0.085, 0.0), Vector2(0.092, 0.025), Vector2(0.075, 0.05)]), 14, PackedColorArray([_vc(tunic.darkened(0.2), 0.7), _vc(tunic, 1.0), _vc(tunic.lightened(0.1), 1.0)]))
	_mi(chest, collar, m_cloth, Vector3(0, 0.13, 0.0), Vector3(-12, 0, 0), Vector3(1.0, 1.0, 0.75))
	# belt + buckle
	var belt := MeshKit.lathe(PackedVector2Array([Vector2(0.137, -0.03), Vector2(0.148, -0.025), Vector2(0.148, 0.025), Vector2(0.137, 0.03)]), 22, PackedColorArray([_vc(Color("#3a2414"), 0.7), _vc(Color("#5a3a22"), 0.9), _vc(Color("#5a3a22"), 1.0), _vc(Color("#3a2414"), 0.8)]))
	_mi(spine, belt, m_leather, Vector3(0, 0.02, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.77))
	_mi(spine, MeshKit.rbox(Vector3(0.055, 0.05, 0.014), 0.008), m_metal, Vector3(0, 0.02, 0.118))
	_mi(spine, MeshKit.rbox(Vector3(0.028, 0.024, 0.016), 0.005), m_dark, Vector3(0, 0.02, 0.121))

	# strap across chest (follows the torso surface) and chest patch with envelope
	var sp := PackedVector3Array()
	var sc := PackedColorArray()
	var steps := 14
	var s0 := Vector2(0.115, 0.34)
	var s1 := Vector2(-0.12, -0.03)
	for i in steps + 1:
		var t := float(i) / steps
		var xy := s0.lerp(s1, t)
		var dirv := (s1 - s0).normalized()
		var perp := Vector2(-dirv.y, dirv.x)
		for k in 3:
			var o := (k - 1) * 0.026
			var q := xy + perp * o
			var rx := _interp(tunic_rows, q.y, 1)
			var rz := _interp(tunic_rows, q.y, 2)
			var zo := _interp(tunic_rows, q.y, 3)
			var ratio := clampf(q.x / rx, -0.97, 0.97)
			var z := rz * sqrt(1.0 - ratio * ratio) + zo + 0.012
			sp.append(Vector3(q.x, q.y, z))
			sc.append(_vc(Color("#6a4126"), 1.0 if k == 1 else 0.82, 0.0 if k == 1 else 0.6))
	var smb := MB.new()
	smb.grid(sp, sc, steps + 1, 3)
	_mi(spine, smb.commit(true), m_leather)
	# strap on the back
	_mi(spine, MeshKit.rbox(Vector3(0.05, 0.3, 0.012), 0.004), m_bag, Vector3(-0.02, 0.22, -0.12), Vector3(0, 0, -12))
	# shield-shaped chest patch with envelope emblem
	var patch := MeshKit.cloth(0.085, 0.1, 5, 6, func(u, v): return Vector3(0, -0.012 * pow(2.0 * v - 1.0, 2.0) if v > 0.5 else 0.0, 0.01 * (1.0 - pow(2.0 * u - 1.0, 2.0))), func(u, v): return _vc(Color("#232c6a"), 1.0, 0.5))
	_mi(chest, patch, m_cloth, Vector3(-0.05, 0.02, 0.118), Vector3(-8, 0, 0))
	_mi(chest, MeshKit.rbox(Vector3(0.048, 0.034, 0.006), 0.003), Paint.get_mat("plain", PAPER, {"roughness": 0.8, "specular": 0.1}), Vector3(-0.05, 0.03, 0.128), Vector3(-8, 0, 3))
	_mi(chest, MeshKit.rbox(Vector3(0.046, 0.003, 0.003), 0.001), m_dark, Vector3(-0.05, 0.038, 0.132), Vector3(-8, 0, -22))
	_mi(chest, MeshKit.rbox(Vector3(0.046, 0.003, 0.003), 0.001), m_dark, Vector3(-0.05, 0.038, 0.132), Vector3(-8, 0, 22))

	# ---- satchel on the right hip (swings)
	var sat := _joint(hips, "Satchel", Vector3(-0.185, 0.05, 0.0), rig)

	var bag := MeshKit.rbox(Vector3(0.1, 0.2, 0.25), 0.03, 0.2)
	_mi(sat, bag, m_bag, Vector3(0, -0.12, 0.0))
	_mi(sat, MeshKit.rbox(Vector3(0.105, 0.09, 0.26), 0.025, 0.1), Paint.get_mat("wood", bag_c.darkened(0.12), {"grain": 0.3, "wear": 0.8, "roughness": 0.6, "wear_color": Color("#a67c4e")}), Vector3(0.005, -0.04, 0.0), Vector3(0, 0, 4))
	_mi(sat, MeshKit.rbox(Vector3(0.02, 0.05, 0.05), 0.006), m_metal, Vector3(-0.058, -0.075, 0.0))
	var env_m := Paint.get_mat("plain", PAPER, {"roughness": 0.8, "specular": 0.05, "rim": 0.2})
	for i in 3:
		_mi(sat, MeshKit.rbox(Vector3(0.012, 0.13, 0.085), 0.004), env_m, Vector3(-0.012 + i * 0.012, 0.0, -0.045 + i * 0.045), Vector3(i * 10 - 10, 0, 6 - i * 8))
	_mi(sat, MeshKit.blob(func(u): return u * 0.014), Paint.glow(Color("#c0302a"), 0.15), Vector3(-0.02, 0.0, -0.002))
	_mi(sat, MeshKit.rbox(Vector3(0.03, 0.03, 0.006), 0.002), Paint.get_mat("plain", Color("#c0302a"), {"roughness": 0.4, "specular": 0.4}), Vector3(-0.058, -0.03, 0.115))

	# ---- head
	_mi(head, _head_mesh(skin), m_skin)
	_mi(head, _nose_mesh(skin), m_skin, Vector3(0, -0.003, 0.152), Vector3(14, 0, 0))
	# nostrils
	for s in [-1.0, 1.0]:
		_mi(head, MeshKit.blob(func(u): return u * Vector3(0.011, 0.007, 0.012)), m_dark, Vector3(0.022 * s, -0.068, 0.205))
	# eyes: ball, pupil, glint, heavy lids
	for s in [-1.0, 1.0]:
		var ec := Vector3(0.071 * s, 0.045, 0.135)
		_mi(head, MeshKit.blob(func(u): return u * 0.04), Paint.get_mat("plain", Color("#efe6b0"), {"roughness": 0.25, "specular": 0.6, "rim": 0.2, "variation": 0.1}), ec)
		_mi(head, MeshKit.blob(func(u): return u * Vector3(0.022, 0.026, 0.012)), Paint.get_mat("plain", Color("#2a1608"), {"roughness": 0.15, "specular": 0.9, "rim": 0.0}), ec + Vector3(0.004 * s, -0.004, 0.034))
		_mi(head, MeshKit.blob(func(u): return u * 0.0075), Paint.glow(Color.WHITE, 1.5), ec + Vector3(0.0, 0.006, 0.043))
		# upper lid (skin hemisphere shell, tilted for a sly grin)
		var lid := MeshKit.blob(func(u: Vector3) -> Vector3:
			var p: Vector3 = u * Vector3(0.046, 0.04, 0.045)
			if u.y < 0.0:
				p.y *= 0.25
			return p, func(u: Vector3, _p: Vector3) -> Color: return _vc(skin.darkened(0.08).lerp(Color("#b5a845"), 0.2), 1.0 - clampf(-u.y, 0.0, 1.0) * 0.3), 8, 12)
		_mi(head, lid, m_skin, ec + Vector3(0.0, 0.012, 0.0), Vector3(0, 0, -18 * s))
		# lower lid / eye bag
		_mi(head, MeshKit.blob(func(u): return u * Vector3(0.044, 0.022, 0.042), func(u, p): return _vc(skin.darkened(0.06), 1.0), 6, 10), m_skin, ec + Vector3(0.0, -0.028, 0.0), Vector3(0, 0, 10 * s))
		# bushy brow
		var brow := MeshKit.tube([Vector3(-0.045 * s, 0.0, 0.0), Vector3(0.0, 0.012, 0.004), Vector3(0.05 * s, 0.002, -0.004)], PackedFloat32Array([0.006, 0.014, 0.005]), 6, PackedColorArray([_vc(Color("#2a1810")), _vc(Color("#2a1810")), _vc(Color("#2a1810"))]))
		_mi(head, brow, m_hair, ec + Vector3(0.0, 0.058, 0.0), Vector3(0, 0, 12 * s))
	# teeth along the grin (a few crooked, two lower tusks)
	var teeth := [[-0.066, 0.1, 0.026, 8.0], [-0.04, 0.11, 0.034, -4.0], [-0.014, 0.117, 0.024, 3.0], [0.016, 0.116, 0.032, -6.0], [0.042, 0.108, 0.022, 7.0], [0.066, 0.098, 0.03, -3.0]]
	for t in teeth:
		var x: float = t[0]
		var ym := -0.56 + 0.62 * pow(x / 0.165, 2.0)
		_mi(head, MeshKit.rbox(Vector3(0.017, float(t[2]), 0.012), 0.004), m_teeth, Vector3(x, ym * 0.22 + 0.004, 0.145 + x * x * 0.12), Vector3(0, 0, float(t[3])))
	for s in [-1.0, 1.0]:
		_mi(head, MeshKit.rbox(Vector3(0.014, 0.034, 0.012), 0.004), m_teeth, Vector3(0.05 * s, -0.118, 0.148), Vector3(0, 0, -s * 8))
	# hair tufts + cap
	for hp in [[0.15, -0.0, -0.02, 30.0], [-0.15, 0.0, -0.02, -30.0], [0.0, 0.02, -0.16, 0.0]]:
		var tuft := MeshKit.tube([Vector3(0, 0, 0), Vector3(0.0, -0.03, 0.01), Vector3(0, -0.075, 0.0)], PackedFloat32Array([0.02, 0.016, 0.0]), 6, PackedColorArray([_vc(Color("#2a1810")), _vc(Color("#2a1810")), _vc(Color("#2a1810"))]))
		_mi(head, tuft, m_hair, Vector3(hp[0] * 0.8, hp[1] + 0.06, hp[2]), Vector3(0, 0, -hp[3] * 0.5))
	if with_hat:
		_mi(cap, _cap_crown(hat_color), m_cloth, Vector3(0, 0.03, -0.005), Vector3(-10, 0, 3))
		var band := MeshKit.lathe(PackedVector2Array([Vector2(0.222, -0.006), Vector2(0.232, 0.0), Vector2(0.232, 0.045), Vector2(0.222, 0.05)]), 22, PackedColorArray([_vc(hat_color.darkened(0.3), 0.7), _vc(hat_color.darkened(0.2), 0.9), _vc(hat_color.darkened(0.2), 1.0), _vc(hat_color.darkened(0.3), 0.9)]))
		_mi(cap, band, m_cloth, Vector3(0, 0.0, -0.005), Vector3(-6, 0, 3), Vector3(1.0, 1.0, 1.04))
		_mi(cap, _visor(hat_color.darkened(0.3)), Paint.get_mat("wood", hat_color.darkened(0.35), {"grain": 0.0, "roughness": 0.45, "specular": 0.4, "wear": 0.5, "wear_color": hat_color.lightened(0.2)}), Vector3(0, 0.022, 0.195), Vector3(14, 0, 0))
		_mi(cap, MeshKit.rbox(Vector3(0.075, 0.052, 0.008), 0.004), Paint.get_mat("plain", PAPER, {"roughness": 0.7, "specular": 0.1}), Vector3(0, 0.044, 0.226), Vector3(-6, 0, 0))
		_mi(cap, MeshKit.rbox(Vector3(0.068, 0.004, 0.004), 0.0015), m_dark, Vector3(0.0, 0.053, 0.2315), Vector3(-6, 0, -24))
		_mi(cap, MeshKit.rbox(Vector3(0.068, 0.004, 0.004), 0.0015), m_dark, Vector3(0.0, 0.053, 0.2315), Vector3(-6, 0, 24))
	# ears (mirrored)
	_mi(ear_l, _ear_mesh(skin), m_skin, Vector3.ZERO, Vector3(0, -40, 24))
	_mi(ear_r, _ear_mesh(skin), m_skin, Vector3.ZERO, Vector3(0, 220, 24), Vector3(1, 1, 1))

	# ---- arms: shoulder -> upper arm -> forearm -> hand
	for side in [1.0, -1.0]:
		var tag := "L" if side > 0 else "R"
		var sh := _joint(chest, "Shoulder" + tag, Vector3(0.165 * side, 0.17, -0.005), rig)
		var ua := _joint(sh, "UpperArm" + tag, Vector3.ZERO, rig)
		var fa := _joint(ua, "Forearm" + tag, Vector3(0, -0.25, 0), rig)
		var hd := _joint(fa, "Hand" + tag, Vector3(0, -0.24, 0), rig)
		_mi(sh, MeshKit.blob(func(u): return u * Vector3(0.05, 0.036, 0.05), func(u, p): return _vc(tunic.darkened(0.05), 1.0 - clampf(-u.y, 0.0, 1.0) * 0.2), 8, 12), m_cloth, Vector3(0.0, -0.005, 0.0))
		# sleeve (rolled to the elbow, ragged edge)
		var sl := MeshKit.lathe(PackedVector2Array([Vector2(0.052, 0.02), Vector2(0.058, -0.04), Vector2(0.056, -0.15), Vector2(0.062, -0.205), Vector2(0.054, -0.225)]), 12, PackedColorArray([_vc(tunic, 1.0), _vc(tunic, 0.95), _vc(tunic.darkened(0.1), 0.9), _vc(tunic.darkened(0.2), 0.8, 0.8), _vc(tunic.darkened(0.3), 0.7, 1.0)]))
		_mi(ua, sl, m_cloth, Vector3(0, 0.0, 0.0))
		_mi(ua, _tube_part([Vector3(0, -0.17, 0), Vector3(0, -0.22, 0.002), Vector3(0, -0.255, 0.005)], PackedFloat32Array([0.034, 0.03, 0.028]), skin, 1.0, 8), m_skin)
		_mi(fa, MeshKit.blob(func(u): return u * Vector3(0.03, 0.03, 0.03), func(u, p): return _vc(skin.lerp(Color("#b5a845"), 0.3), 1.0), 6, 8), m_skin, Vector3(0, 0.0, 0.0))
		_mi(fa, _tube_part([Vector3(0, 0, 0), Vector3(0, -0.12, 0.004), Vector3(0, -0.24, 0.0)], PackedFloat32Array([0.03, 0.025, 0.021]), skin, 1.0, 8), m_skin)
		var hnd := _hand(skin)
		hd.add_child(hnd)
		hnd.rotation_degrees = Vector3(0, 0, -side * 10)
		if side < 0:
			hnd.scale = Vector3(-1, 1, 1)

	root.set_meta("rig", rig)
	root.set_meta("rest_hips_y", 0.76)
	# neutral rest pose
	animate(root, 0.0, 0.0)
	return root


static func rig_of(model: Node3D) -> Dictionary:
	return model.get_meta("rig") as Dictionary


## Where a carried parcel sits.
static func back_mount(model: Node3D) -> Node3D:
	return rig_of(model)["Back"] as Node3D


# ------------------------------------------------------------------ animation

## Procedural walk / idle cycle with secondary motion. speed01: 0 idle .. 1 full run.
static func animate(model: Node3D, speed01: float, t: float, carrying := false) -> void:
	var rig := rig_of(model)
	var a := speed01
	var ph := t * 10.5
	var sw := sin(ph)
	var cw := cos(ph)
	var idle := 1.0 - a
	var breathe := sin(t * 2.3)
	var hips: Node3D = rig["Hips"]
	hips.position.y = 0.76 + absf(sw) * 0.045 * a - 0.014 * a + breathe * 0.004
	hips.rotation = Vector3(0.0, sw * 0.16 * a, sw * 0.055 * a)
	var spine: Node3D = rig["Spine"]
	var lean := 0.1 + 0.2 * a + (0.12 if carrying else 0.0)
	spine.rotation = Vector3(lean, -sw * 0.2 * a, -sw * 0.04 * a)
	var chest: Node3D = rig["Chest"]
	chest.rotation = Vector3(0.05 + breathe * 0.015, -sw * 0.08 * a, 0.0)
	chest.scale = Vector3.ONE * (1.0 + breathe * 0.012)
	var neck: Node3D = rig["Neck"]
	neck.rotation = Vector3(-0.1 - lean * 0.3, sw * 0.1 * a, 0.0)
	var head: Node3D = rig["Head"]
	head.rotation = Vector3(-0.12 - lean * 0.3 + sin(t * 1.1) * 0.03 * idle, -sw * 0.1 * a + sin(t * 0.7) * 0.18 * idle, sin(t * 1.3) * 0.06 * idle + sw * 0.03 * a)
	var cap: Node3D = rig["Cap"]
	cap.rotation = Vector3(sin(ph * 2.0 - 0.8) * 0.05 * a, 0.0, sin(ph - 0.5) * 0.04 * a)
	var jaw: Node3D = rig["Jaw"]
	jaw.rotation.x = 0.04 + (0.18 if a > 0.6 else 0.0) * absf(sin(ph * 0.5)) * 0.5 + 0.02 * sin(t * 2.3)
	# ears flop with the stride and twitch when idle
	var twitch := maxf(0.0, sin(t * 0.9)) * maxf(0.0, sin(t * 7.0)) * 0.2
	var ear_l: Node3D = rig["EarL"]
	var ear_r: Node3D = rig["EarR"]
	ear_l.rotation = Vector3(0.0, 0.0, 0.1 + sin(ph * 2.0 + 0.5) * 0.14 * a + sin(t * 1.7) * 0.03 + twitch)
	ear_r.rotation = Vector3(0.0, 0.0, -0.1 - sin(ph * 2.0 + 1.1) * 0.14 * a - sin(t * 1.9) * 0.03)
	# legs
	var sides := [["L", 0.0], ["R", PI]]
	for sd in sides:
		var p: float = ph + sd[1]
		var thigh: Node3D = rig["Thigh" + sd[0]]
		var shin: Node3D = rig["Shin" + sd[0]]
		var foot: Node3D = rig["Foot" + sd[0]]
		var sg := sin(p)
		thigh.rotation = Vector3(sg * 0.75 * a + 0.04, 0.0, 0.0)
		shin.rotation = Vector3((0.08 + 1.0 * clampf(cos(p), 0.0, 1.0)) * a, 0.0, 0.0)
		foot.rotation = Vector3(-(thigh.rotation.x * 0.4 + shin.rotation.x * 0.5) + 0.25 * clampf(-cos(p), 0.0, 1.0) * a, 0.0, 0.0)
	# arms swing opposite to the legs
	for sd in [["L", PI], ["R", 0.0]]:
		var p2: float = ph + sd[1]
		var ua: Node3D = rig["UpperArm" + sd[0]]
		var fa: Node3D = rig["Forearm" + sd[0]]
		var hd: Node3D = rig["Hand" + sd[0]]
		var side := 1.0 if sd[0] == "L" else -1.0
		ua.rotation = Vector3(sin(p2) * 0.6 * a - 0.05, 0.0, side * (0.12 + 0.05 * breathe * idle + 0.06 * a))
		fa.rotation = Vector3(-(0.28 + 0.65 * clampf(cos(p2), 0.0, 1.0) * a + 0.12 * a), 0.0, 0.0)
		hd.rotation = Vector3(0.1 + sin(p2 - 0.6) * 0.2 * a, 0.0, 0.0)
	# satchel swings behind the stride
	var sat: Node3D = rig["Satchel"]
	sat.rotation = Vector3(sin(ph - 0.9) * 0.22 * a, 0.0, sin(ph * 2.0 - 1.3) * 0.07 * a + 0.04)


## Kick pose overlay: k in 0..1 (call after animate).
static func pose_kick(model: Node3D, k: float) -> void:
	var rig := rig_of(model)
	(rig["ThighR"] as Node3D).rotation.x = -1.5 * k
	(rig["ShinR"] as Node3D).rotation.x = 0.2 * k
	(rig["Spine"] as Node3D).rotation.x -= 0.25 * k


## Friendly wave (keepers on the porch).
static func pose_wave(model: Node3D, t: float) -> void:
	var rig := rig_of(model)
	var ua: Node3D = rig["UpperArmR"]
	var fa: Node3D = rig["ForearmR"]
	ua.rotation = Vector3(0.0, 0.0, -2.5 + sin(t * 3.0) * 0.15)
	fa.rotation = Vector3(0.0, 0.0, -0.5 + sin(t * 9.0) * 0.45)
