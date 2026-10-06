class_name IslandArt
extends RefCounted
## Builds the voxel look of the island: sea, clouds, foliage scatter, buildings, pickups.


static func _mi(parent: Node, mesh: Mesh, vox: float, pos := Vector3.ZERO, rot_y := 0.0, extra := {}, ppv := 4.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VMat.solid(vox, ppv, extra)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


static func _multimesh(parent: Node3D, mesh: Mesh, xforms: Array, vox: float, extra := {}, shadows := true) -> void:
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
	mmi.material_override = VMat.solid(vox, 4.0, extra)
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


static func build_water(parent: Node3D) -> void:
	var tex := ImageTexture.create_from_image(VoxTerrain.height_image())
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 1800)
	pm.subdivide_width = 2
	pm.subdivide_depth = 2
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("height_tex", tex)
	sm.set_shader_parameter("tex_origin", Vector2(-VoxTerrain.HX, -VoxTerrain.HZ))
	sm.set_shader_parameter("tex_size", Vector2(2.0 * VoxTerrain.HX, 2.0 * VoxTerrain.HZ))
	mi.material_override = sm
	mi.position = Vector3(0, -0.12, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func build_clouds(parent: Node3D) -> void:
	var cr := RandomNumberGenerator.new()
	cr.seed = 99
	var mat := VMat.solid(3.0, 2.0, {"tex": 0.03, "emission_strength": 1.1})
	for i in 24:
		var v := Vox.new(3.0)
		var w := cr.randi_range(4, 9)
		var d := cr.randi_range(3, 5)
		for x in w:
			for z in d:
				var h := 1 + (1 if (x > 1 and x < w - 2 and cr.randf() < 0.35) else 0)
				for y in h:
					v.set_v(x, y, z, Color(1.0, 1.0, 1.0, 0.55 if y == 0 else 0.4), 0.02)
		var mi := MeshInstance3D.new()
		mi.mesh = v.build(Vector3(w / 2.0, 0, d / 2.0))
		mi.material_override = mat
		var ang := cr.randf() * TAU
		var dist := cr.randf_range(220.0, 620.0)
		mi.position = Vector3(cos(ang) * dist, cr.randf_range(90.0, 150.0), sin(ang) * dist)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)


## Scatter jungle. Returns candidate crow perch positions (palm tops near the route).
static func scatter(parent: Node3D) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7714
	var forest := FastNoiseLite.new()
	forest.seed = 5
	forest.frequency = 0.03
	var palms: Array = [[], [], [], []]
	var bushes: Array = [[], [], []]
	var grass: Array = [[], [], []]
	var bigleaf: Array = [[], [], []]
	var red: Array = [[], []]
	var flowers: Array = [[], [], [], [], []]
	var rocks: Array = [[], [], [], []]
	var stacks: Array = [[], [], []]
	var homes: Array[Vector3] = []
	var tavern := Vector2(VoxTerrain_TAVERN.x, VoxTerrain_TAVERN.y - 6)
	for i in 4200:
		var x := rng.randf_range(-VoxTerrain.HX + 4, VoxTerrain.HX - 4)
		var z := rng.randf_range(-VoxTerrain.HZ + 4, VoxTerrain.HZ - 4)
		var h := VoxTerrain.height_at(x, z)
		if h < 0.9 or h > 9.0:
			continue
		var p2 := Vector2(x, z)
		if p2.distance_to(tavern) < 17.0 or p2.distance_to(VoxTerrain.HUT_POS) < 8.0 or p2.distance_to(VoxTerrain.LIGHT_POS) < 9.0:
			continue
		var dr := VoxTerrain.dist_to_route(x, z)
		var dens := forest.get_noise_2d(x, z) * 0.5 + 0.5
		var snap := Vector3(floor(x / 0.5) * 0.5 + 0.25, h, floor(z / 0.5) * 0.5 + 0.25)
		var yaw := float(rng.randi() % 4) * PI * 0.5
		var r := rng.randf()
		var xf := Transform3D(Basis(Vector3.UP, yaw), snap)
		if r < 0.1 * (0.4 + dens) and dr > 5.0 and h > 1.1:
			var v := rng.randi() % 4
			palms[v].append(xf)
			if homes.size() < 14 and dr < 24.0 and dr > 6.0:
				homes.append(snap + Vector3(0, 5.8, 0))
		elif r < 0.22 and dr > 4.5:
			bigleaf[rng.randi() % 3].append(xf)
		elif r < 0.27 and dr > 4.5:
			red[rng.randi() % 2].append(xf)
		elif r < 0.37 and dr > 4.0:
			bushes[rng.randi() % 3].append(xf)
		elif r < 0.42 and dr > 5.5:
			rocks[rng.randi() % 4].append(xf)
		elif r < 0.52 and dr > 3.0:
			flowers[rng.randi() % 5].append(xf)
		else:
			grass[rng.randi() % 3].append(xf)
	for i in 5200:
		var x2 := rng.randf_range(-VoxTerrain.HX + 3, VoxTerrain.HX - 3)
		var z2 := rng.randf_range(-VoxTerrain.HZ + 3, VoxTerrain.HZ - 3)
		var h2 := VoxTerrain.height_at(x2, z2)
		if h2 > 0.95 and h2 < 7.5 and VoxTerrain.dist_to_route(x2, z2) > 2.2:
			grass[rng.randi() % 3].append(Transform3D(Basis(Vector3.UP, float(rng.randi() % 4) * PI * 0.5), Vector3(floor(x2 / 0.5) * 0.5 + 0.25, h2, floor(z2 / 0.5) * 0.5 + 0.25)))
	var stack_pos: Array[Vector3] = []
	for k in 26:
		var side := -1.0 if k % 2 == 0 else 1.0
		var zz := rng.randf_range(4.0, 36.0) if k < 16 else rng.randf_range(-80.0, 70.0)
		var xx: float = VoxTerrain.GORGE_X + side * rng.randf_range(10.0, 16.0) if k < 16 else rng.randf_range(-56.0, 56.0)
		var hh := VoxTerrain.height_at(xx, zz)
		if hh < 0.6 or VoxTerrain.dist_to_route(xx, zz) < 7.0:
			continue
		stacks[k % 3].append(Transform3D(Basis(Vector3.UP, float(rng.randi() % 4) * PI * 0.5), Vector3(floor(xx / 0.5) * 0.5, hh - 0.5, floor(zz / 0.5) * 0.5)))
		stack_pos.append(Vector3(xx, hh, zz))
	for v in 4:
		_multimesh(parent, VoxProps.palm(v), palms[v], VoxProps.PALM_V, {"wind": 0.05})
		_multimesh(parent, VoxProps.rock(v), rocks[v], 0.25)
	for v in 3:
		_multimesh(parent, VoxProps.bush(v), bushes[v], 0.2, {"wind": 0.02})
		_multimesh(parent, VoxProps.grass(v), grass[v], 0.12, {"wind": 0.06}, false)
		_multimesh(parent, VoxProps.bigleaf(v), bigleaf[v], 0.2, {"wind": 0.03})
		_multimesh(parent, VoxProps.stack(v), stacks[v], 0.5)
	for v in 2:
		_multimesh(parent, VoxProps.redplant(v), red[v], 0.18, {"wind": 0.03})
	for v in 5:
		_multimesh(parent, VoxProps.flower(v), flowers[v], 0.1, {}, false)
	for sp in stack_pos:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 1.7
		sh.height = 6.0
		cs.shape = sh
		body.add_child(cs)
		body.position = sp + Vector3(0, 2.5, 0)
		parent.add_child(body)
	return homes


const VoxTerrain_TAVERN := Vector2(0, 86)


static func _light(parent: Node3D, pos: Vector3, color := Color("#ffb04a"), energy := 1.0, rng := 8.0, shadow := false) -> FlickerLight:
	var l := FlickerLight.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.shadow_enabled = shadow
	parent.add_child(l)
	return l


static func _solid(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := Style.solid_box(parent, size, pos)
	sb.rotation.y = rot_y
	return sb


static func _prop(parent: Node3D, mesh: Mesh, vox: float, pos: Vector3, yaw_deg := 0.0, extra := {}) -> MeshInstance3D:
	var mi := _mi(parent, mesh, vox, pos, deg_to_rad(yaw_deg), extra)
	return mi


## The Goblin Delivery Co. inn, seen from outside. Front faces -Z (toward the player's start).
static func build_tavern(isl: Node3D) -> void:
	var g := Vector3(VoxTerrain_TAVERN.x, VoxTerrain.height_at(0, 86), VoxTerrain_TAVERN.y)
	var root := Node3D.new()
	root.position = g
	isl.add_child(root)
	_mi(root, VoxBuildings.tavern_exterior(), 0.25, Vector3.ZERO)
	# sails + poles on the left like the reference inn
	_prop(root, VoxBuildings.sail(), 0.25, Vector3(-8.2, 0.0, -2.4), 78.0)
	_prop(root, VoxBuildings.sail(), 0.25, Vector3(8.0, 2.5, -1.5), -78.0)
	# sign text
	var sgn := Style.label3d(root, "GOBLIN DELIVERY CO.", Vector3(0, 5.0, -4.75), 0.012, Color("#f6e3a0"), Vector3(0, 180, 0))
	sgn.outline_size = 14
	# torches by the door + lanterns on the porch
	for tx in [-2.2, 2.2]:
		_prop(root, VoxProps.torch(true), 0.04, Vector3(tx, 1.9, -4.3))
		_light(root, Vector3(tx, 2.9, -4.8), Color("#ff9a3a"), 1.1, 7.0)
	for lx in [-4.8, 4.8]:
		_prop(root, VoxProps.lantern(true), 0.04, Vector3(lx, 3.2, -7.4))
		_light(root, Vector3(lx, 3.5, -7.4), Color("#ffc060"), 0.9, 7.5)
	for wx in [-4.0, 4.0]:
		_light(root, Vector3(wx, 2.6, -5.8), Color("#ffb04a"), 1.0, 9.0)
	_light(root, Vector3(0, 2.4, -6.4), Color("#ffa040"), 1.5, 12.0)
	for bx in [-3.8, 3.8]:
		_prop(root, VoxProps.banner(Color("#9a2a3a")), 0.05, Vector3(bx, 3.9, -4.4), 180.0)
	# barrels / crates / sacks
	_prop(root, VoxProps.barrel(), 0.05, Vector3(-5.2, 0.9, -6.1), 20.0)
	_prop(root, VoxProps.barrel(), 0.05, Vector3(-4.5, 0.9, -5.5), 80.0)
	_prop(root, VoxProps.barrel(), 0.05, Vector3(5.1, 0.9, -6.0), 45.0)
	_prop(root, VoxProps.crate(), 0.05, Vector3(4.3, 0.9, -5.4), 12.0)
	_prop(root, VoxProps.crate(Color("#8a5a30")), 0.05, Vector3(4.4, 1.6, -5.4), -18.0)
	_prop(root, VoxProps.sack(), 0.05, Vector3(-3.4, 0.9, -6.4), 0.0)
	# smoking chimney
	var smoke := CPUParticles3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.7, 0.7, 0.7)
	smoke.mesh = sm
	smoke.material_override = VMat.solid(0.35, 2.0, {"emission_strength": 0.9, "tex": 0.02})
	smoke.amount = 14
	smoke.lifetime = 5.0
	smoke.direction = Vector3(0.2, 1.0, 0.0)
	smoke.spread = 8.0
	smoke.initial_velocity_min = 0.9
	smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0.3, 0.1, 0.0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.0))
	smoke.scale_amount_curve = curve
	smoke.position = Vector3(4.5, 13.2, 1.2)
	root.add_child(smoke)
	# vegetation hugging the walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 321
	for i in 16:
		var px := rng.randf_range(-9.0, 9.0)
		var pz := rng.randf_range(-11.0, -8.5)
		if absf(px) < 2.8:
			continue
		var wy := VoxTerrain.height_at(g.x + px, g.z + pz) - g.y
		_prop(root, VoxProps.bigleaf(i % 3), 0.2, Vector3(px, wy, pz), rng.randi() % 4 * 90.0, {"wind": 0.03})
	for i in 6:
		var wy2 := VoxTerrain.height_at(g.x - 9.5 + i * 3.8, g.z - 9.4) - g.y
		_prop(root, VoxProps.redplant(i % 2), 0.18, Vector3(-9.5 + i * 3.8, wy2, -9.4), rng.randi() % 4 * 90.0, {"wind": 0.03})
	# collision: building body, porch slab, front ramp
	_solid(root, Vector3(12.8, 8.0, 8.8), Vector3(0, 4.0, 0.0))
	_solid(root, Vector3(12.4, 0.8, 3.6), Vector3(0, 0.4, -6.0))
	var ramp := Style.solid_box(root, Vector3(3.4, 0.3, 2.2), Vector3(0, 0.2, -8.3))
	ramp.rotation_degrees.x = 18
	# the way back in
	Interactable.make(isl, Vector3(g.x, g.y + 1.2, g.z - 6.6), "Go back inside (abandon delivery)", Callable(isl, "_abandon"), 3.6)


static func _keeper(isl: Node3D, key: String, vest: Color, skin: Color, hat: bool, hat_col: Color, node: Node3D, pos: Vector3, yaw_deg: float) -> void:
	var keeper := GoblinModel.build(vest, skin, hat, hat_col, false)
	keeper.position = pos
	keeper.rotation_degrees.y = yaw_deg
	node.add_child(keeper)
	isl._keepers[key] = keeper


static func build_hut(isl: Node3D) -> void:
	var hp := VoxTerrain.HUT_POS
	var g := Vector3(hp.x, VoxTerrain.height_at(hp.x, hp.y), hp.y)
	var h := Node3D.new()
	h.position = g
	h.rotation_degrees.y = 25
	isl.add_child(h)
	_mi(h, VoxBuildings.hut(), 0.25, Vector3.ZERO)
	_solid(h, Vector3(5.0, 4.0, 4.0), Vector3(0, 2.0, 0))
	_prop(h, VoxProps.mailbox(), 0.05, Vector3(3.0, 0.0, -3.2))
	_prop(h, VoxProps.barrel(), 0.05, Vector3(2.2, 0.0, -2.9))
	_prop(h, VoxProps.crate(), 0.05, Vector3(-2.2, 0.0, -2.8), 15.0)
	_prop(h, VoxProps.lantern(true), 0.04, Vector3(-1.3, 2.4, -2.3))
	_light(h, Vector3(-1.3, 2.7, -2.6), Color("#ffb04a"), 1.2, 8.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 6:
		var px := rng.randf_range(-3.5, 3.5)
		var pz := rng.randf_range(-4.4, -3.0)
		_prop(h, VoxProps.bigleaf(i % 3), 0.2, Vector3(px, 0.0, pz), rng.randi() % 4 * 90.0, {"wind": 0.03})
	var mbi := Interactable.make(isl, g + Vector3(0, 1.0, 0) + (h.basis * Vector3(3.0, 0, -3.2)), "Deliver the parcel", Callable(isl, "_try_deliver"), 3.4)
	mbi.enabled = isl.job["dest"] == "marl"
	_keeper(isl, "marl", Color("#a05a2a"), Color("#8ac84a"), false, Color.WHITE, h, Vector3(-0.2, 0.0, -3.5), 20.0)


static func build_lighthouse(isl: Node3D) -> void:
	var lp := VoxTerrain.LIGHT_POS
	var g := Vector3(lp.x, VoxTerrain.height_at(lp.x, lp.y), lp.y)
	var l := Node3D.new()
	l.position = g
	isl.add_child(l)
	_mi(l, VoxBuildings.lighthouse(), 0.5, Vector3.ZERO)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe9a0")
	lamp.light_energy = 2.4
	lamp.omni_range = 28.0
	lamp.position = Vector3(0, 14.0, 0)
	l.add_child(lamp)
	_solid(l, Vector3(5.0, 12.0, 5.0), Vector3(0, 6.0, 0))
	_prop(l, VoxProps.mailbox(), 0.05, Vector3(3.6, 0.0, -3.0))
	_prop(l, VoxProps.barrel(), 0.05, Vector3(-3.2, 0.0, -2.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for i in 7:
		var a2 := rng.randf() * TAU
		var rr := rng.randf_range(4.0, 7.0)
		_prop(l, VoxProps.bigleaf(i % 3), 0.2, Vector3(cos(a2) * rr, 0.0, sin(a2) * rr), rng.randi() % 4 * 90.0, {"wind": 0.03})
	var mbi := Interactable.make(isl, g + Vector3(3.6, 1.0, -3.0), "Deliver the parcel", Callable(isl, "_try_deliver"), 3.4)
	mbi.enabled = isl.job["dest"] == "light"
	_keeper(isl, "light", Color("#2a6a7a"), Color("#7ab04a"), true, Color("#1a4a5a"), l, Vector3(1.8, 0.0, -3.6), 15.0)


static func build_pickup(pos: Vector3) -> Node3D:
	var crate := Node3D.new()
	crate.position = pos
	_prop(crate, VoxProps.barrel(), 0.05, Vector3(0, 0, 0))
	for k in 4:
		var bt := _prop(crate, VoxProps.bottle(Color("#4cc27a")), 0.03, Vector3(-0.15 + k * 0.1, 0.9, (k % 2) * 0.08 - 0.04), k * 40.0)
		bt.rotation_degrees.z = (k - 1.5) * 8
	var gl := OmniLight3D.new()
	gl.light_color = Color("#9dffc0")
	gl.light_energy = 0.6
	gl.omni_range = 4.0
	gl.position = Vector3(0, 1.2, 0)
	crate.add_child(gl)
	return crate
