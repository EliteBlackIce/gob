class_name IslandArt
extends RefCounted
## Builds the painted look of the island: terrain, sea, sky, and foliage scatter.


static func _smoothf(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Returns {"heights": PackedFloat32Array, "nx": int, "nz": int}
static func build_terrain(isl: Node3D) -> Dictionary:
	var HX: float = isl.HX
	var HZ: float = isl.HZ
	var STEP: float = isl.STEP
	var nx := int(2.0 * HX / STEP)
	var nz := int(2.0 * HZ / STEP)
	var W := nx + 1
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var heights := PackedFloat32Array()
	verts.resize(W * (nz + 1))
	cols.resize(verts.size())
	norms.resize(verts.size())
	heights.resize(verts.size())
	for j in nz + 1:
		for i in W:
			var x := -HX + i * STEP
			var z := -HZ + j * STEP
			var h: float = isl.height_at(x, z)
			heights[j * W + i] = h
			verts[j * W + i] = Vector3(x, h, z)
	var sun_dir := Vector3(0.45, 0.75, 0.5).normalized()
	for j in nz + 1:
		for i in W:
			var idx := j * W + i
			var h := heights[idx]
			var hl := heights[j * W + maxi(i - 1, 0)]
			var hr := heights[j * W + mini(i + 1, nx)]
			var hu := heights[maxi(j - 1, 0) * W + i]
			var hd := heights[mini(j + 1, nz) * W + i]
			var n := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			norms[idx] = n
			var slope := Vector2(hr - hl, hd - hu).length() / (2.0 * STEP)
			var conc := (hl + hr + hu + hd) * 0.25 - h
			var x := verts[idx].x
			var z := verts[idx].z
			var n1: float = isl.noise.get_noise_2d(x * 5.0, z * 5.0) * 0.5 + 0.5
			var n2: float = isl.noise.get_noise_2d(x * 1.3 + 40.0, z * 1.3) * 0.5 + 0.5
			var onpath := 1.0 - _smoothf(2.2, 6.0, isl._dist_to_route(x, z))
			var c: Color
			if h < -0.05:
				# underwater: sand fading to deeper blue-green with depth
				c = Color("#d4c58c").lerp(Color("#5f9aa0"), clampf(-h / 2.8, 0.0, 1.0))
			elif h < 0.4:
				c = Color("#bfa670").lerp(Color("#e6d09a"), _smoothf(-0.05, 0.4, h))
			elif h < 1.2:
				c = Color("#e6d09a").lerp(Color("#d8c07e"), n1)
				c = c.lerp(Color("#5aa23a"), _smoothf(0.8, 1.35, h) * (0.55 + 0.4 * n2))
			else:
				var lush := Color("#2e8a2b").lerp(Color("#79c241"), n1 * 0.7 + n2 * 0.3)
				var sunlit := clampf(n.dot(sun_dir), 0.0, 1.0)
				c = lush.lerp(Color("#a8d048"), sunlit * 0.35)
				c = c.lerp(Color("#1f6a26"), clampf(conc * 0.5, 0.0, 0.5))
				c = c.lerp(Color("#bda074"), onpath * 0.88)
			var rocky := _smoothf(0.95, 1.5, slope) + _smoothf(11.0, 15.0, h) * 0.35
			if rocky > 0.01 and h > 0.9:
				var band := 0.5 + 0.5 * sin(h * 2.6 + n1 * 3.0)
				var rock := Color("#7d7a72").lerp(Color("#b4ae9c"), band * 0.8 + n1 * 0.2)
				if n.y > 0.55:
					rock = rock.lerp(Color("#5f8a3a"), 0.35)
				c = c.lerp(rock, clampf(rocky * 1.2, 0.0, 1.0))
			var ao := 1.0 - clampf(conc * 0.22, 0.0, 0.3) + clampf(-conc * 0.06, 0.0, 0.08)
			cols[idx] = Color(c.r * ao, c.g * ao, c.b * ao, 1.0).srgb_to_linear()
	var indices := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * W + i
			var b := a + 1
			var c2 := a + W
			var d := c2 + 1
			indices.append_array([a, b, c2, b, d, c2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Paint.get_mat("ground", Color.WHITE, {"variation": 0.0, "wrap": 0.35, "shade_fill": 0.3, "flat_amount": 0.0, "rim": 0.0})
	isl.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	isl.add_child(body)
	return {"heights": heights, "nx": nx, "nz": nz}


static func build_water(isl: Node3D, tdata: Dictionary) -> void:
	var W: int = tdata["nx"] + 1
	var H: int = tdata["nz"] + 1
	var img := Image.create(W, H, false, Image.FORMAT_RH)
	var hs: PackedFloat32Array = tdata["heights"]
	for j in H:
		for i in W:
			img.set_pixel(i, j, Color(hs[j * W + i], 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 1800)
	pm.subdivide_width = 160
	pm.subdivide_depth = 160
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("height_tex", tex)
	sm.set_shader_parameter("tex_origin", Vector2(-isl.HX, -isl.HZ))
	sm.set_shader_parameter("tex_size", Vector2(2.0 * isl.HX, 2.0 * isl.HZ))
	var sd := -Basis.from_euler(Atmos.SUN_DIR_DEG * PI / 180.0).z
	sm.set_shader_parameter("sun_dir", -sd)
	mi.material_override = sm
	mi.position = Vector3(0, -0.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	isl.add_child(mi)


static func build_clouds(isl: Node3D) -> void:
	var cr := RandomNumberGenerator.new()
	cr.seed = 99
	var mat := Paint.get_mat("cloth", Color("#fdfdff"), {"albedo_b": Color("#cfdcf0"), "variation": 0.5, "emission_strength": 0.25, "wrap": 0.8, "shade_fill": 0.5, "sss": 0.0, "rim": 0.2, "roughness": 1.0})
	for i in 26:
		var ang := cr.randf() * TAU
		var dist := cr.randf_range(130.0, 560.0)
		var c := Node3D.new()
		c.position = Vector3(cos(ang) * dist, cr.randf_range(95.0, 160.0), sin(ang) * dist)
		isl.add_child(c)
		var parts := []
		for k in cr.randi_range(5, 9):
			var rad := cr.randf_range(9.0, 22.0)
			var m := MeshKit.blob(func(u: Vector3) -> Vector3:
				var p := u * rad
				p.y *= 0.55
				if p.y < 0.0:
					p.y *= 0.35
				return p, func(u: Vector3, p: Vector3) -> Color:
				var s := clampf(0.78 + u.y * 0.25, 0.0, 1.0)
				return Color(s, s, minf(s * 1.04, 1.0), 1.0), 8, 12)
			parts.append([m, Transform3D(Basis.IDENTITY, Vector3(cr.randf_range(-24, 24), cr.randf_range(-3, 6), cr.randf_range(-12, 12)))])
		var mi := MeshInstance3D.new()
		mi.mesh = MeshKit.combine(parts)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(mi)


static func _multimesh(isl: Node3D, mesh: Mesh, xforms: Array, mat: Material = null, shadows := true) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if mat != null:
		mmi.material_override = mat
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	isl.add_child(mmi)


## Scatters jungle: palms, glossy leaf plants, red plants, ferns, grass, bushes, boulders.
## Returns candidate crow perch positions (palm tops near the route).
static func scatter(isl: Node3D) -> Array[Vector3]:
	var rng: RandomNumberGenerator = isl._rng
	var HX: float = isl.HX
	var HZ: float = isl.HZ
	var forest := FastNoiseLite.new()
	forest.seed = 5
	forest.frequency = 0.03
	var palm_x: Array = [[], [], [], []]
	var bigleaf: Array = [[], [], []]
	var redp: Array = [[], []]
	var ferns: Array = [[], []]
	var grass: Array = [[], [], []]
	var bushes: Array = [[], []]
	var rocks: Array = [[], [], [], []]
	var homes: Array[Vector3] = []
	var tavern := Vector2(isl.TAVERN_POS.x, isl.TAVERN_POS.y - 6)

	var tries := 3200
	for i in tries:
		var x := rng.randf_range(-HX + 4, HX - 4)
		var z := rng.randf_range(-HZ + 4, HZ - 4)
		var h: float = isl.height_at(x, z)
		if h < 0.85 or h > 8.5:
			continue
		var p2 := Vector2(x, z)
		if p2.distance_to(tavern) < 15.0 or p2.distance_to(isl.HUT_POS) < 7.5 or p2.distance_to(isl.LIGHT_POS) < 9.0:
			continue
		var dr: float = isl._dist_to_route(x, z)
		var dens := forest.get_noise_2d(x, z) * 0.5 + 0.5
		var pos := Vector3(x, h - 0.05, z)
		var yaw := rng.randf() * TAU
		var r := rng.randf()
		if r < 0.1 * (0.4 + dens) and dr > 4.8 and h > 1.1:
			var v := rng.randi() % 4
			var sc := rng.randf_range(0.85, 1.3)
			palm_x[v].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos))
			if homes.size() < 14 and dr < 24.0 and dr > 6.0:
				homes.append(pos + Vector3(0, 5.6 * sc, 0))
		elif r < 0.26 and dr > 4.6:
			var sc2 := rng.randf_range(0.8, 1.5)
			bigleaf[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc2), pos))
		elif r < 0.32 and dr > 4.6:
			redp[rng.randi() % 2].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.3)), pos))
		elif r < 0.45 and dr > 3.6:
			ferns[rng.randi() % 2].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), pos))
		elif r < 0.52 and dr > 3.5:
			bushes[rng.randi() % 2].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), pos))
		elif r < 0.6 and dr > 5.5:
			var sc3 := rng.randf_range(0.5, 1.7)
			var b := Basis.from_euler(Vector3(rng.randf_range(-0.2, 0.2), yaw, rng.randf_range(-0.2, 0.2))).scaled(Vector3(sc3, sc3 * rng.randf_range(0.8, 1.2), sc3))
			rocks[rng.randi() % 4].append(Transform3D(b, pos + Vector3(0, -0.05, 0)))
		else:
			grass[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), pos))
	# dense meadow grass everywhere green (not on the path)
	for i in 3600:
		var x := rng.randf_range(-HX + 3, HX - 3)
		var z := rng.randf_range(-HZ + 3, HZ - 3)
		var h: float = isl.height_at(x, z)
		if h > 1.15 and h < 7.5 and isl._dist_to_route(x, z) > 2.0:
			grass[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.6)), Vector3(x, h - 0.03, z)))
	# big mossy sea-stacks along the gorge walls and coast
	for k in 22:
		var side := -1.0 if k % 2 == 0 else 1.0
		var zz := rng.randf_range(4.0, 36.0) if k < 14 else rng.randf_range(-80.0, 70.0)
		var xx: float = isl.GORGE_X + side * rng.randf_range(9.5, 15.0) if k < 14 else rng.randf_range(-58.0, 58.0)
		var hh: float = isl.height_at(xx, zz)
		if hh < 0.6 or isl._dist_to_route(xx, zz) < 6.5:
			continue
		var sc4 := rng.randf_range(2.2, 5.0)
		var b := Basis.from_euler(Vector3(0.0, rng.randf() * TAU, 0.0)).scaled(Vector3(sc4, sc4 * rng.randf_range(0.9, 1.7), sc4))
		rocks[3].append(Transform3D(b, Vector3(xx, hh - sc4 * 0.45, zz)))

	for v in 4:
		_multimesh(isl, Props.palm(v), palm_x[v])
	for v in 3:
		_multimesh(isl, Props.big_leaf_plant(v), bigleaf[v])
		_multimesh(isl, Props.grass(v), grass[v], null, false)
	for v in 2:
		_multimesh(isl, Props.red_plant(v), redp[v])
		_multimesh(isl, Props.fern(v), ferns[v], null, false)
		_multimesh(isl, Props.bush(v), bushes[v])
	for v in 4:
		_multimesh(isl, MeshKit.rock(1.0, 11 + v * 5, 0.75 + 0.1 * v), rocks[v], Props.rock_mat())
	return homes


# ---------------------------------------------------------------- buildings

static func _solid(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0) -> void:
	var sb := Style.solid_box(parent, size, pos)
	sb.rotation.y = rot_y


static func _plant(parent: Node, mesh: Mesh, pos: Vector3, yaw := 0.0, scl := 1.0) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation.y = yaw
	mi.scale = Vector3.ONE * scl
	parent.add_child(mi)


static func _ground_y(isl: Node3D, x: float, z: float) -> float:
	return isl.height_at(x, z)


## The Goblin Delivery Co. tavern, seen from outside (reference: sail-canvas wooden inn). Front faces -Z.
static func build_tavern(isl: Node3D) -> void:
	var gp: Vector2 = isl.TAVERN_POS
	var g := Vector3(gp.x, 2.0, gp.y)
	var root := Node3D.new()
	root.position = g
	isl.add_child(root)
	var wall_col := Color("#8d7b66")
	var S := Structures
	# stone footing
	S._mi(root, MeshKit.rbox(Vector3(12.8, 0.7, 8.8), 0.1, 0.2), Paint.stone(Color("#7a7468")), Vector3(0, 0.35, 0))
	# main hall walls
	var wm := S.wood_white()
	S._mi(root, S.plank_wall(12.0, 4.0, wall_col, 11), wm, Vector3(0, 0.6, -4.0))
	S._mi(root, S.plank_wall(12.0, 4.0, wall_col, 12), wm, Vector3(0, 0.6, 4.0), Vector3(0, 180, 0))
	S._mi(root, S.plank_wall(8.0, 4.0, wall_col, 13), wm, Vector3(-6.0, 0.6, 0), Vector3(0, 90, 0))
	S._mi(root, S.plank_wall(8.0, 4.0, wall_col, 14), wm, Vector3(6.0, 0.6, 0), Vector3(0, -90, 0))
	for cx in [-6.0, 6.0]:
		for cz in [-4.0, 4.0]:
			S._mi(root, MeshKit.rbox(Vector3(0.34, 4.5, 0.34), 0.06), Paint.wood(S.WOOD_BROWN), Vector3(cx, 2.85, cz))
	S._mi(root, MeshKit.rbox(Vector3(12.6, 0.3, 0.4), 0.06), Paint.wood(S.WOOD_BROWN), Vector3(0, 4.7, -4.0))
	S._mi(root, MeshKit.rbox(Vector3(12.6, 0.3, 0.4), 0.06), Paint.wood(S.WOOD_BROWN), Vector3(0, 4.7, 4.0))
	# upper floor (set back, against the rock)
	S._mi(root, S.plank_wall(8.4, 2.8, wall_col.darkened(0.06), 21), wm, Vector3(0, 4.7, -2.2))
	S._mi(root, S.plank_wall(8.4, 2.8, wall_col.darkened(0.06), 22), wm, Vector3(0, 4.7, 2.6), Vector3(0, 180, 0))
	S._mi(root, S.plank_wall(4.8, 2.8, wall_col.darkened(0.1), 23), wm, Vector3(-4.2, 4.7, 0.2), Vector3(0, 90, 0))
	S._mi(root, S.plank_wall(4.8, 2.8, wall_col.darkened(0.1), 24), wm, Vector3(4.2, 4.7, 0.2), Vector3(0, -90, 0))
	# roof: two shingled slopes, ridge, gable-ends
	var roof_col := Color("#6a5846")
	var slope := S.shingle_slope(13.6, 5.7, roof_col, 31, 0.3)
	var rm := wm.duplicate() as ShaderMaterial
	rm.set_shader_parameter("grain", 0.3)
	S._mi(root, slope, rm, Vector3(0, 7.3, -4.9), Vector3(-30, 0, 0))
	S._mi(root, S.shingle_slope(13.6, 5.7, roof_col, 32, 0.3), rm, Vector3(0, 7.3, 4.9), Vector3(-30, 180, 0))
	S._mi(root, MeshKit.rbox(Vector3(13.8, 0.2, 0.55), 0.06), Paint.wood(S.WOOD_DARK), Vector3(0, 10.15, 0.0))
	# porch (boardwalk) + steps + posts + shed roof
	S._mi(root, S.boardwalk(12.4, 3.2, 3), wm, Vector3(0, 0.7, -5.7))
	for i in 3:
		S._mi(root, MeshKit.rbox(Vector3(3.2, 0.2, 0.5), 0.05), Paint.stone(Color("#8a8478")), Vector3(0, 0.55 - i * 0.2, -7.6 - i * 0.5))
	for px in [-5.8, -2.6, 2.6, 5.8]:
		S._mi(root, MeshKit.rbox(Vector3(0.24, 3.3, 0.24), 0.05), Paint.wood(S.WOOD_BROWN), Vector3(px, 2.4, -7.15))
	S._mi(root, MeshKit.rbox(Vector3(12.4, 0.26, 0.3), 0.05), Paint.wood(S.WOOD_BROWN), Vector3(0, 4.0, -7.15))
	S._mi(root, S.shingle_slope(13.2, 3.5, roof_col.lightened(0.05), 33, 0.45), rm, Vector3(0, 4.1, -7.45), Vector3(-14, 0, 0))
	var rail_l := S.railing(4.4)
	rail_l.position = Vector3(-4.0, 0.7, -7.15)
	root.add_child(rail_l)
	var rail_r := S.railing(4.4)
	rail_r.position = Vector3(4.0, 0.7, -7.15)
	root.add_child(rail_r)
	# door, windows, sign
	var door := S.door_double()
	door.position = Vector3(0, 0.7, -4.08)
	root.add_child(door)
	for wx in [-4.0, 4.0]:
		var wn := S.window(1.2, 1.3)
		wn.position = Vector3(wx, 2.0, -4.08)
		root.add_child(wn)
		var lt := FlickerLight.new()
		lt.light_color = Color("#ffb04a")
		lt.light_energy = 1.0
		lt.omni_range = 9.0
		lt.position = Vector3(wx, 2.6, -5.6)
		root.add_child(lt)
	for wx in [-2.6, 2.6]:
		var wn2 := S.window(1.0, 1.1)
		wn2.position = Vector3(wx, 5.4, -4.5)
		root.add_child(wn2)
	var sgn := S.sign_board("GOBLIN DELIVERY CO.", 3.2, 0.85)
	sgn.position = Vector3(0, 4.45, -4.45)
	root.add_child(sgn)
	# torches + lanterns + banners
	for tx in [-1.7, 1.7]:
		var t := S.torch(true)
		t.position = Vector3(tx, 1.6, -4.12)
		root.add_child(t)
		var bn := S.banner(0.85, 2.0, Color("#8a2a3a"))
		bn.position = Vector3(tx * 1.9, 3.7, -4.18)
		root.add_child(bn)
	for lx in [-4.8, 4.8]:
		var ln := S.lantern(true)
		ln.position = Vector3(lx, 3.0, -7.15)
		root.add_child(ln)
	# canvas sail awning on a wooden frame (left), like the reference
	var sl := S.sail(5.2, 3.6, Color("#eadfc2"), 0.35)
	sl.position = Vector3(-8.2, 4.6, -3.6)
	sl.rotation_degrees = Vector3(18, 78, -10)
	root.add_child(sl)
	S._mi(root, MeshKit.tube([Vector3(-7.4, 0.6, -7.2), Vector3(-7.6, 3.2, -6.5), Vector3(-8.2, 6.4, -5.8)], PackedFloat32Array([0.14, 0.12, 0.1]), 6), Paint.wood(S.WOOD_DARK))
	S._mi(root, MeshKit.tube([Vector3(-7.4, 0.6, -0.8), Vector3(-7.7, 3.0, -1.4), Vector3(-8.2, 6.0, -2.4)], PackedFloat32Array([0.14, 0.12, 0.1]), 6), Paint.wood(S.WOOD_DARK))
	root.add_child(S.rope_between(Vector3(-8.2, 6.4, -5.8), Vector3(-6.2, 4.8, -4.4), 0.2))
	# a second, smaller sail on the right
	var sl2 := S.sail(3.4, 2.6, Color("#e2d3b0"), 0.25)
	sl2.position = Vector3(7.6, 5.8, -3.2)
	sl2.rotation_degrees = Vector3(-14, -76, 8)
	root.add_child(sl2)
	# chimney on the right, smoking
	var ch := S.chimney(3.0)
	ch.position = Vector3(3.6, 7.1, 1.4)
	root.add_child(ch)
	var smoke := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	sm.radial_segments = 8
	sm.rings = 4
	smoke.mesh = sm
	smoke.material_override = Paint.get_mat("cloth", Color("#cfcfd6"), {"emission_strength": 0.3, "wrap": 0.8})
	smoke.amount = 14
	smoke.lifetime = 5.0
	smoke.direction = Vector3(0.2, 1.0, 0.0)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.25, 0.1, 0.0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.0))
	smoke.scale_amount_curve = curve
	smoke.position = Vector3(3.6, 10.3, 1.4)
	root.add_child(smoke)
	# clutter: barrels, crates, rope, sacks
	var b1 := S.barrel(Color("#8a5a30"))
	b1.position = Vector3(-5.2, 0.7, -6.1)
	root.add_child(b1)
	var b2 := S.barrel(Color("#7a4e2a"))
	b2.position = Vector3(-4.5, 0.7, -5.6)
	b2.rotation_degrees.y = 40
	root.add_child(b2)
	var b3 := S.barrel(Color("#9a6a3a"))
	b3.position = Vector3(5.1, 0.7, -6.0)
	b3.rotation_degrees.y = 15
	root.add_child(b3)
	var c1 := S.crate(Vector3(0.9, 0.8, 0.9), 4)
	c1.position = Vector3(4.2, 0.7, -5.5)
	c1.rotation_degrees.y = 12
	root.add_child(c1)
	var c2 := S.crate(Vector3(0.7, 0.6, 0.7), 5)
	c2.position = Vector3(4.35, 1.5, -5.45)
	c2.rotation_degrees.y = -20
	root.add_child(c2)
	# greenery hugging the building (like the reference's big glossy leaves + red plants)
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	for i in 16:
		var px := rng.randf_range(-8.5, 8.5)
		var pz := rng.randf_range(-10.2, -8.0) if rng.randf() < 0.7 else rng.randf_range(-5.0, 5.5)
		if absf(px) < 2.6 and pz < -8.0:
			continue
		var wx: float = g.x + px
		var wz: float = g.z + pz
		var wy: float = isl.height_at(wx, wz) - g.y
		_plant(root, Props.big_leaf_plant(rng.randi() % 3), Vector3(px, wy - 0.02, pz), rng.randf() * TAU, rng.randf_range(0.9, 1.5))
	for i in 7:
		var px2: float = [-7.5, -3.4, 3.4, 7.2, 8.8, -9.0, 6.4][i]
		_plant(root, Props.red_plant(i % 2), Vector3(px2, 0.55, -8.8 if i < 4 else -4.0 + i), rng.randf() * TAU, rng.randf_range(0.9, 1.4))
	for i in 5:
		_plant(root, Props.fern(i % 2), Vector3(-5.5 + i * 2.8, 0.8, -9.4), rng.randf() * TAU, 1.0)
	# ferns & grass tufts growing on the roof
	for i in 7:
		var rx := rng.randf_range(-6.0, 6.0)
		var rz := rng.randf_range(-4.2, -0.6)
		_plant(root, Props.fern(i % 2), Vector3(rx, 7.4 + (rz + 4.9) * 0.55, rz), rng.randf() * TAU, 0.9)
	# vines hanging down the right wall
	for i in 5:
		var vx := 6.15
		var vz := -3.2 + i * 1.6
		var pts: Array = []
		var radii := PackedFloat32Array()
		for k in 8:
			pts.append(Vector3(vx + sin(k * 0.8 + i) * 0.08, 4.6 - k * 0.6, vz + cos(k + i) * 0.05))
			radii.append(0.025 * (1.0 - float(k) / 9.0))
		var vm := MeshInstance3D.new()
		vm.mesh = MeshKit.tube(pts, radii, 5)
		vm.material_override = Paint.get_mat("leaf", Color("#2f6a2a"), {"roughness": 0.8})
		root.add_child(vm)
	# warm glow at the door
	var dl := FlickerLight.new()
	dl.light_color = Color("#ffa040")
	dl.light_energy = 1.4
	dl.omni_range = 12.0
	dl.position = Vector3(0, 2.4, -6.2)
	root.add_child(dl)
	# collision: building body + porch + ramp
	_solid(root, Vector3(12.6, 8.0, 8.6), Vector3(0, 4.0, 0))
	_solid(root, Vector3(12.4, 0.7, 3.2), Vector3(0, 0.35, -5.7))
	var ramp := Style.solid_box(root, Vector3(3.2, 0.3, 1.9), Vector3(0, 0.2, -7.9))
	ramp.rotation_degrees.x = 20
	# the way back in
	Interactable.make(isl, Vector3(g.x, g.y + 1.2, g.z - 6.4), "Go back inside (abandon delivery)", Callable(isl, "_abandon"), 3.6)
	# cliff backdrop behind the inn
	for k in 3:
		var rm2 := MeshInstance3D.new()
		rm2.mesh = MeshKit.rock(1.0, 51 + k * 7, 1.1)
		rm2.material_override = Props.rock_mat()
		rm2.position = Vector3(g.x - 8.0 + k * 8.5, g.y + 1.0, g.z + 9.5 + k)
		rm2.scale = Vector3(7.5, 8.5, 6.0)
		rm2.rotation.y = k * 1.3
		isl.add_child(rm2)


static func _keeper(isl: Node3D, key: String, tunic: Color, skin: Color, hat: bool, hat_col: Color, node: Node3D, pos: Vector3, yaw_deg: float) -> void:
	var keeper := GoblinModel.build(tunic, skin, hat, hat_col)
	keeper.position = pos
	keeper.rotation_degrees.y = yaw_deg
	node.add_child(keeper)
	isl._keepers[key] = keeper


static func build_hut(isl: Node3D) -> void:
	var hp: Vector2 = isl.HUT_POS
	var g := Vector3(hp.x, isl.height_at(hp.x, hp.y), hp.y)
	var h := Node3D.new()
	h.position = g
	h.rotation_degrees.y = 25
	isl.add_child(h)
	var S := Structures
	var wm := S.wood_white()
	var col := Color("#a08868")
	S._mi(h, MeshKit.rbox(Vector3(5.4, 0.5, 4.4), 0.08, 0.2), Paint.stone(Color("#7a7468")), Vector3(0, 0.2, 0))
	S._mi(h, S.plank_wall(5.0, 2.8, col, 61), wm, Vector3(0, 0.4, 2.0))
	S._mi(h, S.plank_wall(5.0, 2.8, col, 62), wm, Vector3(0, 0.4, -2.0), Vector3(0, 180, 0))
	S._mi(h, S.plank_wall(4.0, 2.8, col, 63), wm, Vector3(-2.5, 0.4, 0), Vector3(0, 90, 0))
	S._mi(h, S.plank_wall(4.0, 2.8, col, 64), wm, Vector3(2.5, 0.4, 0), Vector3(0, -90, 0))
	for cx in [-2.5, 2.5]:
		for cz in [-2.0, 2.0]:
			S._mi(h, MeshKit.rbox(Vector3(0.22, 3.0, 0.22), 0.05), Paint.wood(S.WOOD_BROWN), Vector3(cx, 1.9, cz))
	var roof := Color("#8a4a36")
	var rm := wm.duplicate() as ShaderMaterial
	rm.set_shader_parameter("grain", 0.25)
	S._mi(h, S.shingle_slope(5.8, 3.0, roof, 65, 0.25), rm, Vector3(0, 3.2, 2.35), Vector3(-34, 180, 0))
	S._mi(h, S.shingle_slope(5.8, 3.0, roof, 66, 0.25), rm, Vector3(0, 3.2, -2.35), Vector3(-34, 0, 0))
	S._mi(h, MeshKit.rbox(Vector3(5.9, 0.16, 0.4), 0.05), Paint.wood(S.WOOD_DARK), Vector3(0, 4.85, 0))
	S._mi(h, S.gable_wall(4.2, 1.5, col, 67), wm, Vector3(-2.55, 3.4, 0), Vector3(0, 90, 0))
	S._mi(h, S.gable_wall(4.2, 1.5, col, 68), wm, Vector3(2.55, 3.4, 0), Vector3(0, -90, 0))
	var door := S.door_double(1.0, 2.2)
	door.position = Vector3(0, 0.4, 2.06)
	door.rotation_degrees.y = 180
	h.add_child(door)
	var wn := S.window(0.9, 0.9)
	wn.position = Vector3(1.7, 1.4, 2.06)
	wn.rotation_degrees.y = 180
	h.add_child(wn)
	var ch := S.chimney(2.0)
	ch.position = Vector3(-1.6, 3.5, -0.8)
	h.add_child(ch)
	var ln := S.lantern(true)
	ln.position = Vector3(-1.3, 2.7, 2.5)
	h.add_child(ln)
	var br := S.barrel(Color("#8a5a30"))
	br.position = Vector3(2.0, 0.5, 2.9)
	h.add_child(br)
	var cr := S.crate(Vector3(0.7, 0.6, 0.7), 8)
	cr.position = Vector3(-2.0, 0.5, 2.8)
	h.add_child(cr)
	# mailbox (the delivery target)
	var mb := S.mailbox()
	mb.position = Vector3(3.0, 0.0, 3.4)
	h.add_child(mb)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 6:
		_plant(h, Props.big_leaf_plant(i % 3), Vector3(rng.randf_range(-3.5, 3.5), 0.0, rng.randf_range(2.8, 4.2)), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	_plant(h, Props.red_plant(0), Vector3(-3.0, 0.0, 3.5), 0.4, 1.0)
	_solid(h, Vector3(5.0, 5.0, 4.0), Vector3(0, 2.5, 0))
	var mbi := Interactable.make(isl, g + Vector3(0, 1.0, 0) + (h.basis * Vector3(3.0, 0, 3.4)), "Deliver the parcel", Callable(isl, "_try_deliver"), 3.4)
	mbi.enabled = isl.job["dest"] == "marl"
	_keeper(isl, "marl", Color("#a05a2a"), Color("#8a9a3a"), false, Color.WHITE, h, Vector3(-0.2, 0.2, 3.5), 160.0)
	var gl := FlickerLight.new()
	gl.light_color = Color("#ffa848")
	gl.light_energy = 1.1
	gl.omni_range = 8.0
	gl.position = Vector3(0, 2.4, 3.2)
	h.add_child(gl)


static func build_lighthouse(isl: Node3D) -> void:
	var lp: Vector2 = isl.LIGHT_POS
	var g := Vector3(lp.x, isl.height_at(lp.x, lp.y), lp.y)
	var l := Node3D.new()
	l.position = g
	isl.add_child(l)
	var S := Structures
	# stone tower with painted bands baked into vertex colour
	var rows := 14
	var prof := PackedVector2Array()
	var cols := PackedColorArray()
	for i in rows + 1:
		var t := float(i) / rows
		prof.append(Vector2(lerpf(2.5, 1.6, t) + 0.08 * sin(t * 40.0), t * 12.0))
		var band := (int(t * 5.0) % 2 == 0)
		var c := Color("#f1ead8") if band else Color("#c4392c")
		var ao := lerpf(0.7, 1.0, smoothstep(0.0, 0.25, t))
		cols.append(Color(c.r * ao, c.g * ao, c.b * ao, 1.0 - (0.35 if i % 2 == 0 else 0.0)))
	S._mi(l, MeshKit.lathe(prof, 24, cols, "lhtower"), Paint.stone(Color.WHITE, {"flat_amount": 0.0, "variation": 0.35, "wear": 0.6, "wear_color": Color("#d8d0bc"), "noise_scale": 3.0}), Vector3.ZERO)
	# gallery + railing + lamp room + roof
	S._mi(l, MeshKit.lathe(PackedVector2Array([Vector2(1.6, 12.0), Vector2(2.2, 12.1), Vector2(2.2, 12.4), Vector2(1.5, 12.4)]), 24, PackedColorArray(), "lhgal"), Paint.stone(Color("#3a3f4a")))
	for k in 16:
		var a := TAU * float(k) / 16.0
		S._mi(l, MeshKit.rbox(Vector3(0.06, 0.8, 0.06), 0.015), Paint.metal(Color("#2e2c34")), Vector3(cos(a) * 2.1, 12.8, sin(a) * 2.1))
	S._mi(l, MeshKit.torus_ring(2.1, 0.04), Paint.metal(Color("#2e2c34")), Vector3(0, 13.2, 0), Vector3(90, 0, 0))
	S._mi(l, MeshKit.lathe(PackedVector2Array([Vector2(1.05, 12.4), Vector2(1.1, 13.9), Vector2(0.0, 13.9)]), 16, PackedColorArray(), "lhlamp"), Paint.get_mat("glass", Color("#fff3b0"), {"emission_strength": 1.6, "emission_color": Color("#ffe9a0"), "variation": 0.0}))
	S._mi(l, MeshKit.lathe(PackedVector2Array([Vector2(1.5, 13.9), Vector2(1.3, 14.2), Vector2(0.5, 14.9), Vector2(0.0, 15.3)]), 16, PackedColorArray(), "lhroof"), Paint.painted(Color("#c4392c")))
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe9a0")
	lamp.light_energy = 2.2
	lamp.omni_range = 26.0
	lamp.position = Vector3(0, 13.2, 0)
	l.add_child(lamp)
	var dr := S.door_double(1.1, 2.1)
	dr.position = Vector3(0, 0.0, 2.45)
	dr.rotation_degrees.y = 180
	l.add_child(dr)
	for k in 3:
		S._mi(l, MeshKit.rbox(Vector3(0.5, 0.7, 0.06), 0.02), Paint.get_mat("glass", Color("#ffd27a"), {"emission_strength": 0.9, "emission_color": Color("#ffb347"), "variation": 0.0}), Vector3(sin(k * 2.1 + 0.3) * 2.1, 4.0 + k * 2.6, cos(k * 2.1 + 0.3) * 2.1), Vector3(0, rad_to_deg(k * 2.1 + 0.3), 0))
	# keeper's lean-to + mailbox
	var mb := S.mailbox()
	mb.position = Vector3(3.6, 0.0, 3.0)
	l.add_child(mb)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 7:
		var a2 := rng.randf() * TAU
		var rr := rng.randf_range(3.5, 6.5)
		_plant(l, Props.big_leaf_plant(i % 3), Vector3(cos(a2) * rr, 0.0, sin(a2) * rr), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	var bar := S.barrel(Color("#8a5a30"))
	bar.position = Vector3(-3.2, 0.5, 2.6)
	l.add_child(bar)
	_solid(l, Vector3(4.6, 12.0, 4.6), Vector3(0, 6.0, 0))
	var mbi := Interactable.make(isl, g + Vector3(3.6, 1.0, 3.0), "Deliver the parcel", Callable(isl, "_try_deliver"), 3.4)
	mbi.enabled = isl.job["dest"] == "light"
	_keeper(isl, "light", Color("#2a6a7a"), Color("#7a9a3a"), true, Color("#1a4a5a"), l, Vector3(1.8, 0.0, 3.5), 190.0)


static func build_pickup(pos: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.position = pos
	var b := Structures.barrel(Color("#8a5a30"))
	b.scale = Vector3(0.7, 0.7, 0.7)
	crate.add_child(b)
	for k in 4:
		var bt := MeshInstance3D.new()
		bt.mesh = MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.06, 0.12), Vector2(0.025, 0.2), Vector2(0.022, 0.3), Vector2(0.0, 0.3)]), 8, PackedColorArray(), "bot")
		bt.material_override = Paint.get_mat("glass", Color("#4cc27a"), {"emission_strength": 0.5, "emission_color": Color("#7fe0a0")})
		bt.position = Vector3(-0.15 + k * 0.1, 0.7, (k % 2) * 0.08 - 0.04)
		bt.rotation_degrees = Vector3(0, 0, (k - 1.5) * 9)
		crate.add_child(bt)
	Style.light(crate, Color("#9dffc0"), 0.5, 4.0, Vector3(0, 1.0, 0))
	return crate
