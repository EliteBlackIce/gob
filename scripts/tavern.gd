class_name Tavern
extends Node3D
## Home base: tavern, post office, and the only place Grubnik will find you.

signal start_run

var ui: UI
var player: Player
var _fire_light: OmniLight3D
var _flames: Array[Node3D] = []
var _t := 0.0
var _shame_labels: Label3D
var _mk_main: Node3D
var _mk_cellar: Node3D
var _intro_hint := false


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_bar()
	_build_fireplace()
	_build_board_and_boss()
	_build_decor()
	_spawn_player()
	_mk_main = _make_marker(Color("#ffd24a"))
	_mk_cellar = _make_marker(Color("#7fd8ff"))
	ui.configure_hud(false)
	ui.hud_player = player
	ui.show_hud(true)
	ui.capture_wanted = false
	Sfx.music_volume(-12.0)


func _build_environment() -> void:
	Atmos.interior(self)


func _fit(root: Node, node: Node3D, pos: Vector3, rot_y := 0.0) -> Node3D:
	node.position = pos
	node.rotation_degrees.y = rot_y
	root.add_child(node)
	return node


func _build_room() -> void:
	var S := Structures
	S.allow_moss = false
	var wm := S.wood_white()
	var beam := Paint.wood(Color("#5a3e26"), {"grain": 0.8, "wear": 0.5})
	# floor: worn boards + collider
	S._mi(self, S.boardwalk(22.0, 16.0, 8, Color("#9a7448")), wm, Vector3(0, 0.0, 0))
	Style.solid_box(self, Vector3(22, 0.6, 16), Vector3(0, -0.3, 0))
	# walls: grey-brown clapboard over a dark wainscot, with collision
	var wall_col := Color("#a08a6c")
	S._mi(self, S.plank_wall(22.0, 6.5, wall_col, 41), wm, Vector3(0, 0, -7.96), Vector3(0, 180, 0))
	S._mi(self, S.plank_wall(22.0, 6.5, wall_col, 42), wm, Vector3(0, 0, 7.96))
	S._mi(self, S.plank_wall(16.0, 6.5, wall_col, 43), wm, Vector3(-10.96, 0, 0), Vector3(0, -90, 0))
	S._mi(self, S.plank_wall(16.0, 6.5, wall_col, 44), wm, Vector3(10.96, 0, 0), Vector3(0, 90, 0))
	S._mi(self, S.plank_wall(22.0, 1.3, Color("#7a5c40"), 45, 0.2, 0.07), wm, Vector3(0, 0, -7.9), Vector3(0, 180, 0))
	S._mi(self, S.plank_wall(22.0, 1.3, Color("#7a5c40"), 46, 0.2, 0.07), wm, Vector3(0, 0, 7.9))
	S._mi(self, S.plank_wall(16.0, 1.3, Color("#7a5c40"), 47, 0.2, 0.07), wm, Vector3(-10.9, 0, 0), Vector3(0, -90, 0))
	S._mi(self, S.plank_wall(16.0, 1.3, Color("#7a5c40"), 48, 0.2, 0.07), wm, Vector3(10.9, 0, 0), Vector3(0, 90, 0))
	for wz in [-7.85, 7.85]:
		S._mi(self, MeshKit.rbox(Vector3(21.8, 0.12, 0.12), 0.03), beam, Vector3(0, 1.32, wz))
	for wx in [-10.85, 10.85]:
		S._mi(self, MeshKit.rbox(Vector3(0.12, 0.12, 15.8), 0.03), beam, Vector3(wx, 1.32, 0))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, -8.3))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, 8.3))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(-11.3, 3.5, 0))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(11.3, 3.5, 0))
	# timber frame: posts, tie beams, rafters, corner braces
	for i in 7:
		var px := -9.0 + i * 3.0
		S._mi(self, MeshKit.rbox(Vector3(0.36, 6.5, 0.4), 0.07), beam, Vector3(px, 3.25, -7.78))
		S._mi(self, MeshKit.rbox(Vector3(0.36, 6.5, 0.4), 0.07), beam, Vector3(px, 3.25, 7.78))
		S._mi(self, MeshKit.rbox(Vector3(0.45, 0.5, 15.6), 0.08), beam, Vector3(px, 6.1, 0))
		for bz in [-7.5, 7.5]:
			S._mi(self, MeshKit.rbox(Vector3(0.16, 1.5, 0.16), 0.03), beam, Vector3(px + 0.5, 5.3, bz * 0.99), Vector3(0, 0, 45))
	for i in 5:
		var pz := -6.0 + i * 3.0
		S._mi(self, MeshKit.rbox(Vector3(0.4, 6.5, 0.36), 0.07), beam, Vector3(-10.78, 3.25, pz))
		S._mi(self, MeshKit.rbox(Vector3(0.4, 6.5, 0.36), 0.07), beam, Vector3(10.78, 3.25, pz))
	S._mi(self, MeshKit.rbox(Vector3(21.6, 0.5, 0.5), 0.08), beam, Vector3(0, 6.1, 0))
	# ceiling boards + canvas sails sagging between the beams
	S._mi(self, S.boardwalk(22.0, 16.0, 9, Color("#7a6040")), wm, Vector3(0, 6.55, 0), Vector3(180, 0, 0))
	var sl1 := S.sail(7.0, 5.0, Color("#e4d8bc"), 0.5)
	sl1.position = Vector3(-4.0, 5.85, 3.0)
	sl1.rotation_degrees = Vector3(90, 0, 4)
	add_child(sl1)
	var sl2 := S.sail(6.0, 4.4, Color("#8a2a3a"), 0.45)
	sl2.position = Vector3(5.0, 5.8, -3.0)
	sl2.rotation_degrees = Vector3(90, 0, -6)
	add_child(sl2)
	# camera-only blockers, inset from the walls/ceiling (layer 16)
	for cb in [[Vector3(22, 8, 0.4), Vector3(0, 3, -7.5)], [Vector3(22, 8, 0.4), Vector3(0, 3, 7.5)],
			[Vector3(0.4, 8, 16), Vector3(-10.5, 3, 0)], [Vector3(0.4, 8, 16), Vector3(10.5, 3, 0)],
			[Vector3(22, 0.4, 16), Vector3(0, 6.1, 0)]]:
		var blk := Style.solid_box(self, cb[0], cb[1])
		blk.collision_layer = 16
		blk.collision_mask = 0
	# the front door (exit)
	var door := S.door_double(2.2, 3.3)
	_fit(self, door, Vector3(0, 0.0, 7.82))
	Style.label3d(self, "OUT (to certain peril)", Vector3(0, 4.15, 7.7), 0.009, Color("#f3d98a"), Vector3(0, 180, 0))
	for tx in [-2.2, 2.2]:
		var t := S.torch(true)
		_fit(self, t, Vector3(tx, 1.7, 7.7))
	Style.light(self, Color("#9ab8ff"), 0.8, 7.0, Vector3(0, 2.5, 6.0))
	Interactable.make(self, Vector3(0, 1.0, 6.9), "Head out to work", Callable(self, "_exit_door"), 3.0)
	# windows with moonlight, shutters and warm glow from outside
	for wx in [-7.0, 7.0]:
		var wn := S.window(1.5, 1.7, false)
		_fit(self, wn, Vector3(wx, 1.9, 7.85))
		wn.get_child(0).material_override = Paint.get_mat("glass", Color("#6a88d8"), {"emission_strength": 1.0, "emission_color": Color("#7a98ff"), "variation": 0.0, "albedo_b": Color("#9ab4ff")})
		Style.light(self, Color("#8aa8ff"), 0.8, 8.0, Vector3(wx, 3.0, 6.0))
	# corner clutter: barrels, crates, sacks, rope
	var clutter := [[Vector3(9.5, 0, 6.6), 0], [Vector3(10.1, 0, 5.5), 1], [Vector3(-9.6, 0, 6.8), 0], [Vector3(-8.6, 0, 7.0), 1], [Vector3(9.5, 0, -6.6), 0]]
	for cl in clutter:
		var b := S.barrel(Color("#8a5a30") if cl[1] == 0 else Color("#7a4e2a"))
		_fit(self, b, cl[0], cl[1] * 40.0)
		Style.solid_box(self, Vector3(1.0, 1.0, 1.0), cl[0] + Vector3(0, 0.5, 0))
	_fit(self, S.crate(Vector3(0.9, 0.8, 0.9), 3), Vector3(-9.8, 0, 5.6), 20.0)
	_fit(self, S.crate(Vector3(0.7, 0.6, 0.7), 4), Vector3(-9.6, 0.8, 5.7), -15.0)
	_fit(self, S.sack(Color("#a89468"), 1), Vector3(-8.8, 0, 5.9))
	_fit(self, S.sack(Color("#9a8458"), 2), Vector3(-9.3, 0, 6.5), 70.0)


func _build_bar() -> void:
	var S := Structures
	var wm := S.wood_white()
	var cx := -5.6
	# counter: planked front, thick polished top, brass foot rail
	S._mi(self, S.plank_wall(10.0, 1.2, Color("#8a6038"), 51, 0.22, 0.09), wm, Vector3(cx, 0.0, -3.2), Vector3(0, 180, 0))
	S._mi(self, MeshKit.rbox(Vector3(10.4, 0.14, 1.9), 0.05, 0.0, 2, Color("#9a6a3a")), Paint.get_mat("wood", Color.WHITE, {"grain": 0.7, "roughness": 0.5, "specular": 0.45, "wear": 0.3}), Vector3(cx, 1.27, -4.0))
	S._mi(self, MeshKit.rbox(Vector3(10.2, 1.2, 1.5), 0.05, 0.3, 2, Color("#6a4a2e")), wm, Vector3(cx, 0.6, -4.0))
	S._mi(self, MeshKit.tube([Vector3(-9.8, 0.22, -3.1), Vector3(-5.6, 0.22, -3.1), Vector3(-1.4, 0.22, -3.1)], PackedFloat32Array([0.04, 0.04, 0.04]), 8), Paint.metal(Color("#d0b060"), {"wear": 0.3}))
	Style.solid_box(self, Vector3(10.4, 1.3, 1.9), Vector3(cx, 0.65, -4.0))
	# barrels along the back wall + a keg rack
	for i in 6:
		var b := S.barrel(Color("#8a5a30").lerp(Color("#6a4527"), (i % 3) * 0.3))
		_fit(self, b, Vector3(-9.6 + i * 1.7, 0.0, -7.2), i * 25.0)
	for i in 4:
		var b2 := S.barrel(Color("#7a4e2a"))
		b2.scale = Vector3(0.85, 0.85, 0.85)
		_fit(self, b2, Vector3(-8.8 + i * 1.7, 1.0, -7.3))
	# shelves with bottles and mugs
	for row in 2:
		for i in 4:
			var sh := S.shelf(1.9, 0.32)
			_fit(self, sh, Vector3(-9.0 + i * 2.2, 2.5 + row * 0.85, -7.65))
			for k in 4:
				if (i + k + row) % 5 == 0:
					continue
				var bc: Color = [Color("#3e9c5a"), Color("#c0504a"), Color("#d8a04a"), Color("#4a78c8")][(i + k + row) % 4]
				var bt := S.bottle(bc)
				_fit(self, bt, Vector3(-9.6 + i * 2.2 + k * 0.4, 2.53 + row * 0.85, -7.62), randf_range(-20, 20))
			var mg := S.mug()
			_fit(self, mg, Vector3(-8.1 + i * 2.2, 2.53 + row * 0.85, -7.62))
	var sgn := S.sign_board("THE SOGGY STAMP", 3.4, 0.9)
	_fit(self, sgn, Vector3(cx, 4.9, -7.7), 180.0)
	# the keep: a goblin barkeep on a crate, plus things on the counter
	var bt := GoblinModel.build(Color("#8a3a30"), Color("#738a38"), false)
	bt.position = Vector3(cx, 0.45, -5.6)
	add_child(bt)
	Style.box(self, Vector3(1.2, 0.45, 1.0), Color("#6a4527"), Vector3(cx, 0.22, -5.6))
	_fit(self, S.mug(), Vector3(-2.4, 1.34, -3.8), 30.0)
	_fit(self, S.mug(false), Vector3(-7.6, 1.34, -4.0), -50.0)
	_fit(self, S.candle(true, 0.14), Vector3(-2.0, 1.34, -4.4))
	_fit(self, S.candle(true, 0.1), Vector3(-9.0, 1.34, -4.2))
	for lx in [-8.2, -3.0]:
		var ln := S.lantern(true)
		ln.position = Vector3(lx, 4.2, -4.0)
		add_child(ln)
		S._mi(self, MeshKit.tube([Vector3(lx, 6.1, -4.0), Vector3(lx, 5.1, -4.0), Vector3(lx, 4.65, -4.0)], PackedFloat32Array([0.012, 0.012, 0.012]), 4), Paint.metal(Color("#2e2c34")))
	Interactable.make(self, Vector3(-5.0, 1.0, -2.6), "Chat with Brin the barkeep", Callable(self, "_bar_menu"), 3.4)


func _build_fireplace() -> void:
	var S := Structures
	var fz := -2.0
	# stone chimney breast rising to the ceiling
	S._mi(self, S.stone_wall(5.6, 6.5, 71, 0.5), Paint.get_mat("stone", Color.WHITE, {"flat_amount": 0.15, "variation": 0.3, "roughness": 0.95}), Vector3(10.0, 0.0, fz), Vector3(0, 90, 0))
	S._mi(self, MeshKit.rbox(Vector3(1.2, 6.5, 5.6), 0.1, 0.2), Paint.stone(Color("#7a7670")), Vector3(10.4, 3.25, fz))
	Style.solid_box(self, Vector3(1.6, 6.5, 5.8), Vector3(10.2, 3.25, fz))
	# firebox: dark recess, lintel, mantel
	S._mi(self, MeshKit.rbox(Vector3(0.3, 2.0, 2.8), 0.04), Paint.get_mat("plain", Color("#16100d"), {"roughness": 1.0, "specular": 0.0, "rim": 0.0}), Vector3(9.55, 1.1, fz))
	for sz in [-1.55, 1.55]:
		S._mi(self, MeshKit.rbox(Vector3(0.5, 2.3, 0.4), 0.06, 0.1, 2, Color("#8a8680")), Paint.stone(Color.WHITE, {"flat_amount": 0.1}), Vector3(9.5, 1.15, fz + sz))
	S._mi(self, MeshKit.rbox(Vector3(0.7, 0.4, 3.9), 0.06, 0.1, 2, Color("#9a948c")), Paint.stone(Color.WHITE, {"flat_amount": 0.1}), Vector3(9.5, 2.45, fz))
	S._mi(self, MeshKit.rbox(Vector3(0.9, 0.16, 4.4), 0.04, 0.0, 2, Color("#5a3a22")), Paint.wood(Color("#5a3a22"), {"grain": 0.9}), Vector3(9.4, 2.8, fz))
	S._mi(self, MeshKit.rbox(Vector3(1.0, 0.16, 3.6), 0.04, 0.1, 2, Color("#8a847c")), Paint.stone(Color.WHITE), Vector3(9.4, 0.08, fz))
	# logs, embers and a lively fire
	var logs := S.log_pile(5)
	logs.position = Vector3(9.35, 0.1, fz)
	logs.rotation_degrees.y = 90
	add_child(logs)
	var flame_root := Node3D.new()
	flame_root.position = Vector3(9.35, 0.35, fz)
	add_child(flame_root)
	for k in 6:
		var fc: Color = [Color("#ff4a12"), Color("#ff7a1a"), Color("#ffa628"), Color("#ff7a1a"), Color("#ff4a12"), Color("#ffd04a")][k]
		var kk := k
		var fm := MeshKit.blob(func(u: Vector3) -> Vector3:
			var p := u * Vector3(0.2, 0.55, 0.2)
			if u.y > 0.0:
				p.x *= 1.0 - u.y * 0.9
				p.z *= 1.0 - u.y * 0.9
				p.x += u.y * u.y * 0.08 * sin(kk * 2.0)
			p.y += 0.5
			return p, func(u: Vector3, p: Vector3) -> Color: return fc.lerp(Color("#fff0a0"), clampf(0.5 - u.y * 0.5, 0.0, 0.7)), 8, 10)
		var fl := MeshInstance3D.new()
		fl.mesh = fm
		fl.material_override = Paint.glow(Color.WHITE, 2.8)
		fl.position = Vector3(0.0, 0.0, (k - 2.5) * 0.3)
		fl.scale = Vector3(1.0, 0.7 + (3 - absi(k - 2)) * 0.18, 1.0)
		flame_root.add_child(fl)
	for k in 8:
		var em := MeshInstance3D.new()
		em.mesh = MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.09, 0.05, 0.09))
		em.material_override = Paint.glow(Color("#ff5a1a"), 2.2)
		em.position = Vector3(9.4 + randf_range(-0.2, 0.2), 0.14, fz + (k - 3.5) * 0.22)
		add_child(em)
	var fire := FlickerLight.new()
	fire.light_color = Color("#ff8a3a")
	fire.light_energy = 3.4
	fire.omni_range = 14.0
	fire.position = Vector3(8.6, 1.2, fz)
	fire.shadow_enabled = true
	fire.flame = flame_root
	add_child(fire)
	_fire_light = fire
	var warm := OmniLight3D.new()
	warm.light_color = Color("#ffb060")
	warm.light_energy = 1.1
	warm.omni_range = 7.0
	warm.position = Vector3(8.8, 2.8, fz)
	add_child(warm)
	var sp := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	sp.mesh = bm
	sp.material_override = Paint.glow(Color("#ffcf7a"), 3.0)
	sp.amount = 22
	sp.lifetime = 1.8
	sp.direction = Vector3(-0.1, 1.0, 0)
	sp.spread = 28.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.8
	sp.gravity = Vector3(0, 0.3, 0)
	sp.position = Vector3(9.35, 1.0, fz)
	add_child(sp)
	# on the mantel: candles, mugs, a ship's wheel above
	_fit(self, S.candle(true, 0.16), Vector3(9.4, 2.88, fz - 1.5))
	_fit(self, S.candle(true, 0.1), Vector3(9.4, 2.88, fz + 1.4))
	_fit(self, S.mug(false), Vector3(9.4, 2.88, fz + 0.3), 70.0)
	var wheel := Node3D.new()
	wheel.position = Vector3(10.35, 4.7, fz)
	wheel.rotation_degrees = Vector3(0, 90, 0)
	add_child(wheel)
	var wmat := Paint.wood(Color("#7a5232"), {"grain": 0.8})
	S._mi(wheel, MeshKit.torus_ring(0.78, 0.07), wmat, Vector3.ZERO)
	S._mi(wheel, MeshKit.torus_ring(0.12, 0.09), wmat, Vector3.ZERO)
	for k in 8:
		S._mi(wheel, MeshKit.rbox(Vector3(0.07, 1.9, 0.07), 0.02), wmat, Vector3.ZERO, Vector3(0, 0, k * 22.5))
		S._mi(wheel, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.05), Vector2(0.035, 0.2), Vector2(0.0, 0.22)]), 8, PackedColorArray(), "wheelknob"), wmat, Vector3(cos(deg_to_rad(k * 45.0)) * 0.9, sin(deg_to_rad(k * 45.0)) * 0.9, 0.0), Vector3(0, 0, k * 45.0 - 90.0))
	_fit(self, S.banner(0.9, 2.2, Color("#8a2a3a")), Vector3(10.85, 4.6, fz - 2.6), 90.0)
	_fit(self, S.banner(0.9, 2.2, Color("#8a2a3a")), Vector3(10.85, 4.6, fz + 2.6), 90.0)


func _build_board_and_boss() -> void:
	var S := Structures
	var wm := S.wood_white()
	# job board (left wall): framed cork-ish planks covered in notes
	S._mi(self, MeshKit.rbox(Vector3(0.22, 3.4, 4.4), 0.06, 0.1, 2, Color("#5a3e26")), wm, Vector3(-10.8, 2.7, -1.0))
	S._mi(self, S.plank_wall(4.0, 3.0, Color("#9a7a52"), 81, 0.25, 0.05), wm, Vector3(-10.62, 1.2, -1.0), Vector3(0, -90, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var paper := Paint.get_mat("cloth", Color("#efe2bf"), {"roughness": 0.9, "wrap": 0.5, "sss": 0.15, "variation": 0.3})
	for k in 14:
		var py := 1.6 + (k % 4) * 0.68 + rng.randf_range(-0.1, 0.1)
		var pz := -2.7 + (k / 4) * 0.95 + rng.randf_range(-0.15, 0.15)
		var pw := rng.randf_range(0.45, 0.7)
		var ph := rng.randf_range(0.5, 0.85)
		S._mi(self, MeshKit.rbox(Vector3(0.015, ph, pw), 0.004, 0.0, 1, Color(0.9 + rng.randf() * 0.1, 0.85 + rng.randf() * 0.1, 0.7 + rng.randf() * 0.1)), paper, Vector3(-10.58, py, pz), Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-4, 4)))
		S._mi(self, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.02), Paint.glow(Color("#c0302a"), 0.2), Vector3(-10.56, py + ph * 0.42, pz))
	Style.label3d(self, "WANTED: Goblins. Any.", Vector3(-10.54, 3.2, -1.7), 0.0035, Color("#3a2410"), Vector3(0, 90, 0))
	Style.label3d(self, "JOBS", Vector3(-10.5, 4.75, -1.0), 0.016, Color("#f3d98a"), Vector3(0, 90, 0))
	Interactable.make(self, Vector3(-9.2, 1.0, -1.0), "Browse the job board", Callable(self, "_job_board"), 3.2)

	# Grubnik's door (back wall): heavy, iron-bound, gold emblem, mail slot
	var bd := S.door_double(2.4, 3.8)
	_fit(self, bd, Vector3(4.6, 0.0, -7.82), 180.0)
	S._mi(self, MeshKit.rbox(Vector3(1.0, 0.3, 0.05), 0.01), Paint.metal(Color("#e0b84a"), {"emission_strength": 0.1}), Vector3(4.6, 3.35, -7.7))
	Style.label3d(self, "GRUBNIK", Vector3(4.6, 3.35, -7.62), 0.006, Color("#2a1a0d"))
	Style.label3d(self, "DO NOT KNOCK. DO NOT WAIT.\nDO NOT EXIST.", Vector3(4.6, 4.3, -7.7), 0.0055, Color("#f3d98a"))
	S._mi(self, MeshKit.rbox(Vector3(0.9, 0.12, 0.08), 0.02), Paint.metal(Color("#2a2a30")), Vector3(4.6, 1.2, -7.72))
	for tx in [2.2, 7.0]:
		_fit(self, S.torch(true), Vector3(tx, 1.7, -7.7), 180.0)
		_fit(self, S.banner(0.9, 2.4, Color("#8a2a3a")), Vector3(tx + (-0.9 if tx < 4 else 0.9), 4.8, -7.78), 180.0)
	Interactable.make(self, Vector3(4.6, 1.0, -6.4), "Check the mail slot (Grubnik's letter)", Callable(self, "_boss_letter"), 3.2)

	# wall of shame (left wall, front half): stone slab, nails, candles
	S._mi(self, S.stone_wall(5.2, 3.4, 91, 0.2), Paint.get_mat("stone", Color("#5a5560"), {"flat_amount": 0.1, "variation": 0.3}), Vector3(-10.7, 1.0, 4.6), Vector3(0, -90, 0))
	Style.label3d(self, "WALL OF SHAME", Vector3(-10.45, 4.75, 4.6), 0.011, Color("#d8a0a0"), Vector3(0, 90, 0))
	_shame_labels = Style.label3d(self, "", Vector3(-10.45, 2.9, 4.6), 0.0055, Color("#e8d8d8"), Vector3(0, 90, 0))
	_shame_labels.line_spacing = 6
	_refresh_shame()
	for cz in [3.0, 6.2]:
		_fit(self, S.candle(true, 0.12), Vector3(-10.4, 0.0, cz))
	Interactable.make(self, Vector3(-9.4, 1.0, 4.6), "Pay respects", Callable(self, "_respects"), 3.2)

	# cellar hatch: planked trapdoor with an iron ring
	S._mi(self, S.boardwalk(2.0, 2.0, 12, Color("#4a3624")), wm, Vector3(-5.0, 0.03, 3.2), Vector3(0, 90, 0))
	for hz in [-1.0, 1.0]:
		S._mi(self, MeshKit.rbox(Vector3(2.2, 0.06, 0.12), 0.02), Paint.metal(Color("#2e2c34")), Vector3(-5.0, 0.06, 3.2 + hz * 0.95))
		S._mi(self, MeshKit.rbox(Vector3(0.12, 0.06, 2.1), 0.02), Paint.metal(Color("#2e2c34")), Vector3(-5.0 + hz * 0.95, 0.06, 3.2))
	S._mi(self, MeshKit.torus_ring(0.14, 0.02), Paint.metal(Color("#8a8a92")), Vector3(-5.0, 0.12, 3.2), Vector3(90, 0, 0))
	Style.label3d(self, "CELLAR (training)", Vector3(-5.0, 1.2, 3.2), 0.006, Color("#f3d98a"), Vector3.ZERO, true)
	Interactable.make(self, Vector3(-5.0, 0.6, 3.2), "Climb into the cellar (skills)", Callable(self, "_cellar"), 2.8)


func _build_decor() -> void:
	var S := Structures
	for fl in [Vector3(-5, 4.6, 2.0), Vector3(2, 4.8, 1.0), Vector3(6, 4.6, 5.0), Vector3(-2, 4.6, -4.5), Vector3(7, 4.4, -3.5)]:
		var wl := OmniLight3D.new()
		wl.light_color = Color("#ffc888")
		wl.light_energy = 1.1
		wl.omni_range = 11.0
		wl.position = fl
		add_child(wl)
	# rugs: a big patterned one in the middle, a runner by the door
	_fit(self, S.rug(9.0, 6.0, Color("#a8322f"), Color("#d8a64a")), Vector3(2.0, 0.0, 1.0))
	_fit(self, S.rug(2.4, 3.2, Color("#3a4a8a"), Color("#d8a64a")), Vector3(-2.2, 0.025, 5.4))
	# tables with stools, mugs and candles
	var tabs := [[Vector3(3.0, 0, 2.0), 20.0], [Vector3(7.0, 0, 4.5), -10.0], [Vector3(2.0, 0, -3.0), 5.0]]
	for i in tabs.size():
		var tp: Vector3 = tabs[i][0]
		var ty: float = tabs[i][1]
		var tb := S.table(1.7, 0.95, 0.9, i + 1)
		_fit(self, tb, tp, ty)
		Style.solid_box(self, Vector3(1.8, 1.0, 1.1), tp + Vector3(0, 0.5, 0))
		var cand := S.candle(true, 0.12)
		cand.position = Vector3(0.1, 0.9, 0.0)
		tb.add_child(cand)
		var mg := S.mug()
		mg.position = Vector3(-0.5, 0.9, 0.2)
		mg.rotation_degrees.y = 40
		tb.add_child(mg)
		var mg2 := S.mug(false)
		mg2.position = Vector3(0.55, 0.9, -0.2)
		tb.add_child(mg2)
		for sx in [-1.0, 1.0]:
			var st := S.stool(0.5)
			st.position = Vector3(sx * 1.2, 0.0, 0.0)
			st.rotation_degrees.y = sx * 20.0
			tb.add_child(st)
	# parcel pile ("dead letters") and pigeonholes
	var ppos := [Vector3(7.5, 0.0, 1.2), Vector3(8.3, 0.0, 1.9), Vector3(7.7, 0.8, 1.5), Vector3(6.9, 0.0, 2.1)]
	for i in ppos.size():
		_fit(self, S.crate(Vector3(0.8, 0.7, 0.7) * (1.0 - i * 0.05), 20 + i), ppos[i], i * 31.0)
	Style.solid_box(self, Vector3(2.4, 1.6, 2.0), Vector3(7.7, 0.8, 1.6))
	Style.label3d(self, "DEAD LETTERS", Vector3(7.7, 2.2, 1.5), 0.008, Color("#c0a070"), Vector3.ZERO, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	S._mi(self, MeshKit.rbox(Vector3(4.2, 2.6, 0.3), 0.05, 0.1), Paint.wood(Color("#4a3220"), {"grain": 0.9}), Vector3(6.5, 2.5, 7.7))
	for r in 3:
		for c in 6:
			S._mi(self, MeshKit.rbox(Vector3(0.58, 0.6, 0.12), 0.015), Paint.get_mat("plain", Color("#1a120c"), {"roughness": 1.0}), Vector3(4.9 + c * 0.64, 1.7 + r * 0.75, 7.58))
			if rng.randf() < 0.55:
				S._mi(self, MeshKit.rbox(Vector3(0.36, 0.22, 0.04), 0.008, 0.0, 1, Color(0.92, 0.88, 0.74)), Paint.get_mat("cloth", Color.WHITE, {"roughness": 0.9}), Vector3(4.9 + c * 0.64, 1.62 + r * 0.75, 7.5), Vector3(0, 0, rng.randf_range(-12, 12)))
	# hanging lanterns on chains
	for lp in [Vector3(-2, 4.6, 0), Vector3(5, 4.6, -4), Vector3(-8, 4.6, 4)]:
		var ln := S.lantern(true)
		ln.position = lp
		add_child(ln)
		S._mi(self, MeshKit.tube([Vector3(lp.x, 6.1, lp.z), Vector3(lp.x, 5.3, lp.z), Vector3(lp.x, lp.y + 0.46, lp.z)], PackedFloat32Array([0.012, 0.012, 0.012]), 4), Paint.metal(Color("#2e2c34")))
	# hanging drying herbs / rope net for atmosphere
	for i in 6:
		var hx := -10.0 + i * 0.5
		S._mi(self, MeshKit.tube([Vector3(hx, 6.1, -7.4), Vector3(hx, 5.7, -7.4), Vector3(hx + 0.05, 5.3, -7.38)], PackedFloat32Array([0.01, 0.015, 0.05]), 5, PackedColorArray([Color("#6a5a38"), Color("#5a7a3a"), Color("#6a8a3a")])), Paint.get_mat("leaf", Color.WHITE))
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 3
	for i in 5:
		add_child(S.rope_between(Vector3(-10.9, 5.6 - i * 0.04, -5.0 + i * 2.2), Vector3(-6.0, 5.9, -5.0 + i * 2.2), 0.4, 0.016))


func _spawn_player() -> void:
	player = Player.new()
	player.ui = ui
	player.cam_dist = 5.6
	player.pitch = -0.38
	player.position = Vector3(1.0, 0.2, 3.0)
	add_child(player)
	player.arm.margin = 0.3
	player.arm.collision_mask = 1 | 16
	player.setup_for_run(false)
	player.model.rotation.y = PI
	player.yaw = 0.0


func _make_marker(color: Color) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Style.cyl(n, 0.0, 0.16, 0.34, color, Vector3.ZERO, Vector3(180, 0, 0), 4, 0.35)
	Style.light(n, color, 0.5, 3.5, Vector3(0, -0.5, 0))
	return n


## Gold arrow = your next objective; blue arrow = you have skill points to spend.
func _update_guide() -> void:
	var has_job := not Game.current_job.is_empty()
	var target := Vector3(0, 4.5, 7.2) if has_job else Vector3(-9.4, 4.4, -1.0)
	_mk_main.position = target + Vector3(0, sin(_t * 3.0) * 0.2, 0)
	_mk_main.rotation.y = _t * 1.5
	_mk_main.visible = not ui.modal_open
	_mk_cellar.visible = Game.skill_points > 0 and not ui.modal_open
	_mk_cellar.position = Vector3(-5.0, 2.0 + sin(_t * 3.0 + 1.0) * 0.2, 3.2)
	_mk_cellar.rotation.y = -_t * 1.5
	if ui.modal_open:
		return
	if not _intro_hint and _t > 1.0:
		_intro_hint = true
		ui.hint("t_board", "Step 1: walk to the JOB BOARD on the left wall (follow the gold arrow) and press E to pick a parcel.", 8.0)
	if has_job:
		ui.hint("t_door", "Parcel taken! Now head out the FRONT DOOR (the gold arrow) to start the delivery.", 8.0)
	if Game.skill_points > 0 and Game.deliveries + Game.deaths >= 1:
		ui.hint("t_cellar", "You have a skill point! Climb down the CELLAR hatch (blue arrow) to learn a new trick.", 8.0)


func _process(delta: float) -> void:
	_t += delta
	_update_guide()
	pass


# ---------- interactions ----------

func _refresh_shame() -> void:
	var lines: Array[String] = []
	for s in Game.shame.slice(0, 7):
		var d: Dictionary = s
		lines.append("RIP %s (day %d)\n   %s" % [d["name"], d["day"], str(d["cause"]).substr(0, 44)])
	_shame_labels.text = "\n".join(lines) if lines.size() > 0 else "(empty. for now.)"


func _respects(_by: Node) -> void:
	var lines := ["F.", "He was a good goblin. He was also late.", "You pour out a little grog. Brin charges you for it.", "Somewhere, a crow is wearing his hat."]
	ui.toast(lines[randi() % lines.size()], Color("#f3d0d0"))


func _exit_door(_by: Node) -> void:
	if Game.current_job.is_empty():
		ui.toast("Pick a parcel at the job board first!", Color("#ffd89a"))
		Sfx.play("error")
		return
	Sfx.play("click")
	start_run.emit()


func _job_board(_by: Node) -> void:
	var entries: Array = []
	for j in Game.today_jobs:
		var job: Dictionary = j
		var mark := "  (SELECTED)" if Game.current_job.get("id", "") == job["id"] and Game.current_job.get("dest", "") == job["dest"] else ""
		entries.append({
			"label": "%s  ->  %s%s" % [job["title"], job["dest_name"], mark],
			"desc": "%s   Pay: %d copper   Time: %d:%02d" % [job["note"], job["pay"], int(job["time"]) / 60, int(job["time"]) % 60],
			"cb": func():
				Game.current_job = job
				ui.close_modal()
				ui.toast("Taken: %s. Head for the door." % job["title"], Color("#9dffa0"))
				Sfx.play("coin"),
		})
	ui.show_menu("JOB BOARD", "Day %d.  Grubnik: \"%s\"" % [Game.day, Game.mandate["text"]], entries, "Leave them (cowardly)")


func _boss_letter(_by: Node) -> void:
	var text: String = Game.LETTERS[(Game.day * 3 + Game.deaths) % Game.LETTERS.size()]
	text += "\n\nToday's policy: " + str(Game.mandate["text"])
	ui.show_letter("A NOTE FROM GRUBNIK", text)


func _cellar(_by: Node) -> void:
	ui.show_skills()


func _bar_menu(_by: Node) -> void:
	var can_grog: bool = Game.copper >= 25 and Game.perk_hp < 2
	var can_crate: bool = Game.copper >= 20 and Game.perk_bottles < 6
	var entries: Array = [
		{"label": "Goblin Grog  -  25 copper", "desc": "+1 max HP on your next run (stacks to +2). Tastes like regret and fire.", "enabled": can_grog,
			"cb": func():
				Game.copper -= 25
				Game.perk_hp += 1
				Sfx.play("coin")
				ui.close_modal()
				ui.toast("Liquid courage acquired. (+1 HP next run)", Color("#ffd89a"))},
		{"label": "Crate of Bottles  -  20 copper", "desc": "+3 throwing bottles next run. Brin won't judge.", "enabled": can_crate,
			"cb": func():
				Game.copper -= 20
				Game.perk_bottles += 3
				Sfx.play("coin")
				ui.close_modal()
				ui.toast("Bottles loaded. (+3 next run)", Color("#9fe6b0"))},
	]
	var quip := "Brin: \"Coin first. Questions never.\""
	if Game.deaths > 3:
		quip = "Brin: \"You again? I just wiped the stain.\""
	ui.show_menu("THE SOGGY STAMP", quip, entries, "Never mind")
