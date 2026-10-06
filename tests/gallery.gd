extends Node
## Dev tool: renders every procedural asset to its own PNG.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 720x540 res://tests/gallery.tscn -- <mode> <out_dir>
## Modes: studio (characters/parcels/props on a neutral stage), island, tavern, ui, audio

var out_dir := "/tmp/assets"
var ui: UI
var cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "studio"
	out_dir = args[1] if args.size() > 1 else out_dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	Game.hints_seen.clear()
	Game.current_job = {}
	Game.owned.clear()
	Game.shame.clear()
	match mode:
		"studio":
			await studio()
		"island":
			await island_shots()
		"tavern":
			await tavern_shots()
		"ui":
			await ui_shots()
		"audio":
			audio_dump()
	print("gallery done: ", mode)
	get_tree().quit()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func snap(name: String, settle := 3) -> void:
	await frames(settle)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("  ", name)


func node_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	var meshes: Array = n.find_children("*", "MeshInstance3D", true, false)
	if n is MeshInstance3D:
		meshes.append(n)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


func frame(n: Node, yaw_deg := 28.0, elev_deg := 14.0, pad := 1.0) -> void:
	var bb := node_aabb(n)
	var c := bb.get_center()
	var r := maxf(bb.size.length() * 0.5, 0.2)
	var dist := r / sin(deg_to_rad(cam.fov * 0.5)) * pad
	var y := deg_to_rad(yaw_deg)
	var e := deg_to_rad(elev_deg)
	cam.global_position = c + Vector3(sin(y) * cos(e), sin(e), cos(y) * cos(e)) * dist
	cam.look_at(c, Vector3.UP)


func frame_sphere(c: Vector3, r: float, yaw_deg: float, elev_deg: float) -> void:
	var dist := r / sin(deg_to_rad(cam.fov * 0.5))
	var y := deg_to_rad(yaw_deg)
	var e := deg_to_rad(elev_deg)
	cam.global_position = c + Vector3(sin(y) * cos(e), sin(e), cos(y) * cos(e)) * dist
	cam.look_at(c, Vector3.UP)


# ---------------------------------------------------------------- studio

func _vi(mesh: Mesh, vox: float, pos := Vector3.ZERO, rot_y := 0.0, extra := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VMat.solid(vox, 4.0, extra)
	mi.position = pos
	mi.rotation.y = deg_to_rad(rot_y)
	return mi


func _crow_node() -> Node3D:
	var d := VoxCreatures.crow()
	var root := Node3D.new()
	var body := _vi(d["body"], 0.06)
	body.scale = Vector3.ONE * 1.5
	root.add_child(body)
	for sd in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sd * 0.15, 0.18, 0.0) * 1.5
		w.scale = Vector3.ONE * 1.5
		w.rotation.z = -sd * 0.3
		root.add_child(w)
		w.add_child(_vi(d["wingL"] if sd > 0 else d["wingR"], 0.06))
	root.position.y = 0.5
	return root


func _slime_node() -> Node3D:
	var d := VoxCreatures.slime()
	var root := Node3D.new()
	var core := _vi(d["core"], 0.06, Vector3(0, 0.38, 0), 0.0, {"emission_strength": 0.5})
	root.add_child(core)
	root.add_child(_vi(d["ring"], 0.05, Vector3(0.12, 0.52, 0.52)))
	var shell := MeshInstance3D.new()
	shell.mesh = d["shell"]
	shell.material_override = VMat.glass(0.06, 0.5, {"emission_strength": 0.5})
	root.add_child(shell)
	var bd := _vi(d["board"], 0.05, Vector3(-0.58, 0.42, 0.2), 40.0)
	root.add_child(bd)
	return root


func _ogre_node() -> Node3D:
	var d := VoxCreatures.ogre()
	var root := Node3D.new()
	root.add_child(_vi(d["torso"], 0.07, Vector3(0, 0.55, 0)))
	root.add_child(_vi(d["head"], 0.07, Vector3(0, 1.85, 0.1)))
	for sd in [-1.0, 1.0]:
		root.add_child(_vi(d["arm"], 0.07, Vector3(sd * 0.95, 1.7, 0.1)))
	return root


func _parcel_node(job: Dictionary, heat := 0.0) -> Node3D:
	var p := Parcel.create(job)
	p.heat = heat
	return p


func studio() -> void:
	Atmos.day(self)
	cam = Camera3D.new()
	cam.fov = 36.0
	add_child(cam)
	cam.current = true
	var tile := Vox.new(0.25)
	for x in range(-20, 20):
		for z in range(-20, 20):
			tile.set_v(x, -1, z, Color("#7cc048") if (x + z) % 2 == 0 else Color("#6ab43c"), 0.05)
	var ground := _vi(tile.build(), 0.25)
	add_child(ground)
	var jobs := {}
	for j in Game.JOBS:
		jobs[j["trait"]] = j
	var items: Array = [
		["goblin_courier", func(): return GoblinModel.build(), 24.0, 8.0, 0.95],
		["goblin_back", func(): return GoblinModel.build(), 200.0, 8.0, 0.95],
		["goblin_running", func():
			var g := GoblinModel.build()
			GoblinModel.animate(g, 1.0, 0.45, false)
			return g, 38.0, 8.0, 0.95],
		["goblin_hut_keeper", func(): return GoblinModel.build(Color("#a05a2a"), Color("#8ac84a"), false, Color.WHITE, false), 24.0, 8.0, 0.95],
		["goblin_lighthouse_keeper", func(): return GoblinModel.build(Color("#2a6a7a"), Color("#7ab04a"), true, Color("#1a4a5a"), false), 24.0, 8.0, 0.95],
		["goblin_barkeep_brin", func(): return GoblinModel.build(Color("#8a3a30"), Color("#74b83c"), false, GoblinModel.CAP, false), 24.0, 8.0, 0.95],
		["crow", func(): return _crow_node(), 40.0, 18.0, 0.95],
		["inspector_slime", func(): return _slime_node(), 32.0, 12.0, 0.95],
		["customer_service_ogre", func(): return _ogre_node(), 20.0, 8.0, 0.95],
		["parcel_screaming_cheese", func(): return _parcel_node(jobs["screamer"]), 28.0, 14.0, 0.95],
		["parcel_hot_potato_cool", func(): return _parcel_node(jobs["hot"], 0.0), 28.0, 14.0, 0.95],
		["parcel_hot_potato_about_to_blow", func(): return _parcel_node(jobs["hot"], 90.0), 28.0, 14.0, 0.95],
		["parcel_wiggly_crate", func(): return _parcel_node(jobs["wiggly"]), 28.0, 14.0, 0.95],
		["parcel_grandmas_vase", func(): return _parcel_node(jobs["glass"]), 28.0, 14.0, 0.95],
		["parcel_ceremonial_anvil", func(): return _parcel_node(jobs["heavy"]), 28.0, 14.0, 0.95],
		["throwing_bottle", func(): return _vi(VoxProps.bottle(Color("#3e9c5a")), 0.03), 28.0, 14.0, 0.95],
		["palm_tree", func(): return _vi(VoxProps.palm(0), VoxProps.PALM_V), 30.0, 8.0, 0.9],
		["rock", func(): return _vi(VoxProps.rock(1), 0.25), 30.0, 14.0, 0.95],
		["sea_stack", func(): return _vi(VoxProps.stack(0), 0.5), 30.0, 10.0, 0.95],
		["bush", func(): return _vi(VoxProps.bush(0), 0.2), 30.0, 14.0, 0.95],
		["jungle_plants", func():
			var r := Node3D.new()
			r.add_child(_vi(VoxProps.bigleaf(0), 0.2, Vector3(-1.4, 0, 0)))
			r.add_child(_vi(VoxProps.redplant(0), 0.18, Vector3(0.0, 0, 0)))
			r.add_child(_vi(VoxProps.grass(0), 0.12, Vector3(1.2, 0, 0)))
			for k in 5:
				r.add_child(_vi(VoxProps.flower(k), 0.1, Vector3(1.8 + k * 0.25, 0, 0.5)))
			return r, 24.0, 20.0, 0.95],
		["barrel_crate_sack", func():
			var r2 := Node3D.new()
			r2.add_child(_vi(VoxProps.barrel(), 0.05, Vector3(-0.8, 0, 0)))
			r2.add_child(_vi(VoxProps.crate(), 0.05, Vector3(0.1, 0, 0), 20.0))
			r2.add_child(_vi(VoxProps.sack(), 0.05, Vector3(0.9, 0, 0)))
			return r2, 24.0, 14.0, 0.95],
		["torch_lantern_mailbox", func():
			var r3 := Node3D.new()
			r3.add_child(_vi(VoxProps.torch(true), 0.04, Vector3(-0.6, 0, 0), 0.0, {"emission_strength": 2.0}))
			r3.add_child(_vi(VoxProps.lantern(true), 0.04, Vector3(0.0, 0, 0), 0.0, {"emission_strength": 2.0}))
			r3.add_child(_vi(VoxProps.mailbox(), 0.05, Vector3(0.7, 0, 0)))
			return r3, 24.0, 14.0, 0.95],
		["table_stool_mug_candle", func():
			var r4 := Node3D.new()
			r4.add_child(_vi(VoxProps.table(), 0.05, Vector3(0, 0, 0)))
			r4.add_child(_vi(VoxProps.stool(), 0.05, Vector3(-1.2, 0, 0)))
			r4.add_child(_vi(VoxProps.mug(), 0.03, Vector3(-0.4, 0.9, 0.1)))
			r4.add_child(_vi(VoxProps.candle(6), 0.03, Vector3(0.3, 0.9, 0.0)))
			return r4, 24.0, 20.0, 0.95],
		["banner", func(): return _vi(VoxProps.banner(Color("#9a2a3a")), 0.05, Vector3(0, 2.1, 0)), 10.0, 0.0, 0.95],
	]
	for it in items:
		var n: Node3D = (it[1] as Callable).call()
		add_child(n)
		await frames(2)
		frame(n, float(it[2]), float(it[3]), float(it[4]))
		await snap(str(it[0]))
		n.queue_free()
		await frames(2)
	var rd := Ragdoll.spawn(self, Vector3(0, 1.6, 0), Vector3(2, 5, 3))
	await frames(6)
	var tp: Vector3 = rd.torso.global_position
	cam.global_position = tp + Vector3(2.0, 0.6, 2.8)
	cam.look_at(tp, Vector3.UP)
	await snap("goblin_ragdoll", 1)
	rd.queue_free()


# ---------------------------------------------------------------- island (in-world)

func island_shots() -> void:
	ui = UI.new()
	add_child(ui)
	ui.fade_to(0.0, 0.01)
	var isl := Island.new()
	isl.ui = ui
	isl.job = Game.today_jobs[0].duplicate()
	add_child(isl)
	await frames(5)
	ui.show_hud(false)
	isl.player.visible = false
	isl.player.global_position = Vector3(0, 3.0, 74.0)   # parked safely on the plaza
	isl.player.set_physics_process(false)
	isl.player.set_process(false)
	isl.set_process(false)                               # no timers / hints / deaths during the shoot
	cam = Camera3D.new()
	cam.fov = 60.0
	cam.far = 900.0
	isl.add_child(cam)
	cam.current = true
	var shots := [
		["island_overview", Vector3(70, 105, 128), Vector3(0, 0, -6)],
		["island_tavern_exterior", Vector3(-12, 8, 62), Vector3(0, 5, 86)],
		["island_ogre_toll_gate", Vector3(0, 4.5, 30), Vector3(-4, 2.5, 18)],
		["island_gorge", Vector3(-4, 6, 44), Vector3(-4, 3, 14)],
		["island_marls_hut", Vector3(-1, 5, -18), Vector3(-10, 2.5, -30)],
		["island_lighthouse", Vector3(2, 10, -58), Vector3(18, 8, -78)],
		["island_palm_beach", Vector3(-26, 4, 66), Vector3(-14, 3, 52)],
		["island_coast_view", Vector3(34, 9, -4), Vector3(0, 2, -20)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await snap(str(s[0]), 4)
	# perch post
	if isl._crow_homes.size() > 0:
		var h: Vector3 = isl._crow_homes[0]
		cam.global_position = h + Vector3(5, 1.5, 6)
		cam.look_at(h - Vector3(0, 1, 0), Vector3.UP)
		await snap("island_crow_perch", 4)


# ---------------------------------------------------------------- tavern (in-world)

func tavern_shots() -> void:
	ui = UI.new()
	add_child(ui)
	ui.fade_to(0.0, 0.01)
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await frames(5)
	ui.show_hud(false)
	t.player.visible = false
	t._mk_main.visible = false
	t._mk_cellar.visible = false
	cam = Camera3D.new()
	cam.fov = 70.0
	t.add_child(cam)
	cam.current = true
	var shots := [
		["tavern_wide_from_door", Vector3(0, 3.6, 7.2), Vector3(0, 1.8, -3)],
		["tavern_fireplace", Vector3(3.5, 2.3, 3.0), Vector3(10, 1.5, -2)],
		["tavern_bar", Vector3(-2, 2.6, 2.4), Vector3(-6, 1.6, -5)],
		["tavern_job_board", Vector3(-6.0, 2.6, 2.0), Vector3(-10.8, 2.6, -1.0)],
		["tavern_boss_door", Vector3(2.0, 2.4, -3.0), Vector3(4.6, 2.2, -7.8)],
		["tavern_wall_of_shame", Vector3(-6.0, 2.4, 6.0), Vector3(-10.8, 2.6, 4.6)],
		["tavern_cellar_hatch", Vector3(-3.0, 2.2, 5.5), Vector3(-5.0, 0.2, 3.2)],
		["tavern_dead_letters_and_pigeonholes", Vector3(5.0, 2.8, 4.5), Vector3(7.0, 1.4, 4.2)],
		["tavern_table_and_rug", Vector3(0.0, 3.2, 5.0), Vector3(3.0, 0.8, 2.0)],
		["tavern_exit_door", Vector3(0, 2.4, 2.4), Vector3(0, 2.2, 7.8)],
	]
	for s in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await snap(str(s[0]), 4)
	# objective arrows (normally floating over the next target)
	t._mk_main.visible = true
	t._mk_cellar.visible = true
	t._mk_main.position = Vector3(-9.4, 3.6, -1.0)
	t._mk_cellar.position = Vector3(-5.0, 2.0, 3.2)
	set_process(false)
	cam.global_position = Vector3(-4.0, 3.4, 4.8)
	cam.look_at(Vector3(-7.5, 2.6, 0.5), Vector3.UP)
	await snap("tavern_objective_arrows", 2)


# ---------------------------------------------------------------- ui

func ui_shots() -> void:
	ui = UI.new()
	add_child(ui)
	ui.fade_to(0.0, 0.01)
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await frames(5)
	t._mk_main.visible = false
	t._mk_cellar.visible = false
	Game.skill_points = 3
	Game.owned = {"quick_feet": true, "bandolier": true}
	ui.show_title(func(): pass, func(): pass)
	await snap("ui_title", 3)
	ui.close_modal(false)
	t._job_board(null)
	await snap("ui_job_board", 3)
	ui.close_modal(false)
	ui.show_skills()
	await snap("ui_skill_tree", 3)
	ui.close_modal(false)
	ui.show_riddle("The Ogre sighs. 'Rules are rules.'", "What gets wetter the more it dries?", ["A towel", "The sea", "Your receipt"], func(_i): pass)
	await snap("ui_ogre_riddle", 3)
	ui.close_modal(false)
	t._bar_menu(null)
	await snap("ui_bar_menu", 3)
	ui.close_modal(false)
	ui.show_letter("A NOTE FROM GRUBNIK", Game.LETTERS[1] + "\n\nToday's policy: " + str(Game.mandate["text"]))
	await snap("ui_boss_letter", 3)
	ui.close_modal(false)
	ui.show_result({"title": "DELIVERED!", "lines": "Delivered: Screaming Cheese\nCondition: 72%   (SPEEDY: +25%)\nPay: 54 copper    Skill points: +1", "moments": ["CROW STOLE THE PARCEL", "THE CRATE RAN AWAY"], "quote": "Grubnik: \"Adequate. Do not expect a thank-you.\""}, func(): pass)
	await snap("ui_result_delivered", 3)
	ui.close_modal(false)
	ui.show_result({"title": "SNIK IS DEAD", "lines": "Snik was returned to sender by Customer Service.\nParcel lost. Funeral deducted: 15 copper.", "moments": ["RETURN TO SENDER"], "quote": "Grubnik: \"Death is not an excuse. It's barely a delay.\""}, func(): pass)
	await snap("ui_result_dead", 3)
	ui.close_modal(false)
	# stamp QTE ring, frozen mid-shrink
	ui.show_hud(true)
	ui.qte(func(_ok): pass)
	ui._qte_active = false
	ui._qte_t = 0.8
	(ui._qte_ring as UI.QteRing).t = 0.8
	ui._qte_ring.queue_redraw()
	await snap("ui_stamp_qte", 2)
	ui._qte.visible = false
	ui.hint("g1", "CROWS steal parcels! Kick them (F) or throw a bottle (Left Click). In a pinch, toss the parcel out of reach with G.", 30.0)
	ui.toast("A CROW STOLE YOUR PARCEL!", Color("#ff9d8a"))
	ui.toast("+2 bottles", Color("#9fe6b0"))
	await snap("ui_hud_hint_toasts", 6)
	ui.flash_damage(0.4)
	await snap("ui_damage_flash", 1)
	Game.moment("CROW STOLE THE PARCEL")
	await snap("ui_viral_clip_banner", 5)


# ---------------------------------------------------------------- audio

func audio_dump() -> void:
	var out := {}
	for k in Sfx._bank.keys():
		out[k] = _peaks((Sfx._bank[k] as AudioStreamWAV).data, 320)
	out["music_shanty_loop"] = _peaks(Sfx._music_stream.data, 900)
	out["ocean_ambience_loop"] = _peaks((Sfx._amb.stream as AudioStreamWAV).data, 900)
	var f := FileAccess.open("%s/audio.json" % out_dir, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	print("  audio.json (%d sounds)" % out.size())


func _peaks(data: PackedByteArray, n: int) -> Array:
	var total := data.size() / 2
	var res := []
	for i in n:
		var a := int(float(i) / n * total)
		var b := maxi(a + 1, int(float(i + 1) / n * total))
		var mx := 0
		var mn := 0
		var step := maxi(1, (b - a) / 12)
		var j := a
		while j < b:
			var v := data.decode_s16(j * 2)
			mx = maxi(mx, v)
			mn = mini(mn, v)
			j += step
		res.append([mn / 32768.0, mx / 32768.0])
	return res
