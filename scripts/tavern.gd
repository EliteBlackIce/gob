class_name Tavern
extends Node3D
## Home base: tavern, post office, and the only place Grubnik will find you. A blocky inn lit by
## fire and lanterns, with a bar, job board, boss door, wall of shame and a cellar hatch.

signal start_run

var ui: UI
var player: Player
var _fire_light: FlickerLight
var _t := 0.0
var _shame_labels: Label3D
var _mk_main: Node3D
var _mk_cellar: Node3D
var _intro_hint := false
var _quota_board: Label3D
var _board_t := 0.0


func _ready() -> void:
	Atmos.interior(self)
	_build_room()
	_build_bar()
	_build_fireplace()
	_build_board_and_boss()
	_build_decor()
	_build_services()
	_build_trophies()
	_build_extras()
	_build_quota_desk()
	_spawn_player()
	_mk_main = _make_marker(Color("#ffd24a"))
	_mk_cellar = _make_marker(Color("#7fd8ff"))
	Atmos.motes(player.cam, Color("#ffd48a"), 60, Vector3(9, 3, 9), 0.05)
	ui.configure_hud("hub")
	ui.hud_player = player
	ui.show_hud(true)
	ui.capture_wanted = false
	Sfx.music_volume(-12.0)


func _mesh(mesh: Mesh, vox: float, pos: Vector3, yaw_deg := 0.0, extra := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VMat.solid(vox, 4.0, extra)
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	add_child(mi)
	return mi


func _light(pos: Vector3, color := Color("#ffb04a"), energy := 1.0, rng := 8.0, shadow := false) -> FlickerLight:
	var l := FlickerLight.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	l.shadow_enabled = shadow
	add_child(l)
	return l


func _build_room() -> void:
	_mesh(VoxBuildings.tavern_room(), 0.25, Vector3.ZERO)
	Style.solid_box(self, Vector3(22, 0.6, 16), Vector3(0, -0.3, 0))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, -8.3))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, 8.3))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(-11.3, 3.5, 0))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(11.3, 3.5, 0))
	Style.label3d(self, "OUT (to certain peril)", Vector3(0, 4.15, 7.7), 0.009, Color("#f3d98a"), Vector3(0, 180, 0))
	for tx in [-2.2, 2.2]:
		_mesh(VoxProps.torch(true), 0.04, Vector3(tx, 1.7, 7.72), 180.0)
		_light(Vector3(tx, 2.8, 7.0), Color("#ff9a3a"), 0.9, 6.0)
	_light(Vector3(0, 2.5, 6.0), Color("#9ab8ff"), 0.7, 7.0)
	Interactable.make(self, Vector3(0, 1.0, 6.9), "Head out to work", Callable(self, "_exit_door"), 3.0)
	for wx in [-7.0, 7.0]:
		_light(Vector3(wx, 3.0, 6.0), Color("#8aa8ff"), 0.9, 9.0)
	# corner clutter
	for cl in [[Vector3(-9.6, 0.9, 6.8), 0], [Vector3(-8.6, 0.9, 7.0), 1], [Vector3(9.5, 0.9, -6.6), 0]]:
		_mesh(VoxProps.barrel(), 0.05, cl[0] + Vector3(0, -0.9, 0), cl[1] * 40.0)
		Style.solid_box(self, Vector3(1.0, 1.0, 1.0), cl[0] + Vector3(0, -0.4, 0))
	_mesh(VoxProps.crate(), 0.05, Vector3(-9.8, 0.0, 5.6), 20.0)
	_mesh(VoxProps.crate(Color("#8a5a30")), 0.05, Vector3(-9.6, 0.7, 5.7), -15.0)
	_mesh(VoxProps.sack(), 0.05, Vector3(-8.8, 0.0, 5.9))
	_mesh(VoxProps.sack(Color("#a89060")), 0.05, Vector3(-9.3, 0.0, 6.5), 70.0)


func _build_bar() -> void:
	var cx := -5.6
	Style.solid_box(self, Vector3(10.4, 1.3, 1.9), Vector3(cx, 0.65, -4.0))
	for i in 6:
		_mesh(VoxProps.barrel(), 0.05, Vector3(-9.6 + i * 1.7, 0.0, -7.2), i * 25.0)
	for i in 4:
		var b2 := _mesh(VoxProps.barrel(), 0.05, Vector3(-8.8 + i * 1.7, 0.9, -7.3))
		b2.scale = Vector3(0.85, 0.85, 0.85)
	for row in 2:
		for i in 4:
			var sh := Vox.new(0.05)
			sh.box(0, 0, 0, 38, 2, 7, Color("#6a4a30"), 0.07)
			var smi := VoxProps.mesh_instance(sh.build(Vector3(19, 0, 3.5)), 0.05)
			smi.position = Vector3(-9.0 + i * 2.2, 2.5 + row * 0.85, -7.65)
			add_child(smi)
			for k in 4:
				if (i + k + row) % 5 == 0:
					continue
				var bc: Color = [Color("#3e9c5a"), Color("#c0504a"), Color("#d8a04a"), Color("#4a78c8")][(i + k + row) % 4]
				_mesh(VoxProps.bottle(bc), 0.03, Vector3(-9.6 + i * 2.2 + k * 0.4, 2.55 + row * 0.85, -7.62), randf_range(-20, 20))
			_mesh(VoxProps.mug(), 0.03, Vector3(-8.1 + i * 2.2, 2.55 + row * 0.85, -7.62))
	var sgn := Vox.new(0.05)
	sgn.planks(0, 0, 0, 70, 16, 3, Color("#7a5a3a"), true, 2, 20)
	sgn.box(-1, -1, 0, 71, 0, 3, Color("#4e3220"), 0.05)
	sgn.box(-1, 16, 0, 71, 17, 3, Color("#4e3220"), 0.05)
	_mesh(sgn.build(Vector3(35, 8, 0)), 0.05, Vector3(cx, 4.7, -7.75))
	Style.label3d(self, "THE SOGGY STAMP", Vector3(cx, 4.7, -7.55), 0.011, Color("#f6e3a0"))
	# the keep, on a crate behind the bar
	var bt := GoblinModel.build(Color("#8a3a30"), Color("#74b83c"), false, GoblinModel.CAP, false)
	bt.position = Vector3(cx, 0.45, -5.9)
	add_child(bt)
	_mesh(VoxProps.crate(Color("#6a4527")), 0.05, Vector3(cx, 0.0, -5.9))
	_mesh(VoxProps.mug(), 0.03, Vector3(-2.4, 1.5, -3.8), 30.0)
	_mesh(VoxProps.mug(false), 0.03, Vector3(-7.6, 1.5, -4.0), -50.0)
	_mesh(VoxProps.candle(6), 0.03, Vector3(-2.0, 1.5, -4.4), 0.0)
	_mesh(VoxProps.candle(4), 0.03, Vector3(-9.0, 1.5, -4.2), 0.0)
	for lx in [-8.2, -3.0]:
		_mesh(VoxProps.lantern(true), 0.04, Vector3(lx, 4.1, -4.0))
		var chain := Vox.new(0.04)
		chain.box(0, 0, 0, 1, 34, 1, Color("#3a3a46"), 0.04)
		_mesh(chain.build(Vector3(0.5, 0, 0.5)), 0.04, Vector3(lx, 4.7, -4.0))
		_light(Vector3(lx, 4.2, -4.0), Color("#ffb04a"), 1.2, 8.0)
	_light(Vector3(-5.6, 2.4, -5.0), Color("#ffb04a"), 1.2, 7.0)
	Interactable.make(self, Vector3(-5.0, 1.0, -2.6), "Chat with Brin the barkeep", Callable(self, "_bar_menu"), 3.4)


func _build_fireplace() -> void:
	Style.solid_box(self, Vector3(2.6, 6.5, 7.0), Vector3(10.0, 3.25, -4.0))
	var fire := _mesh(VoxBuildings.fire_mesh(), 0.1, Vector3(9.35, 0.12, -2.0), 90.0, {"emission_strength": 2.6})
	var fl := _light(Vector3(8.4, 1.3, -2.0), Color("#ff8a3a"), 3.6, 14.0, true)
	fl.flame = fire
	_fire_light = fl
	_light(Vector3(8.8, 2.8, -2.0), Color("#ffb060"), 1.1, 7.0)
	var sp := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	sp.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("#ffcf7a")
	sm.emission_enabled = true
	sm.emission = Color("#ffcf7a")
	sm.emission_energy_multiplier = 3.0
	sp.material_override = sm
	sp.amount = 22
	sp.lifetime = 1.8
	sp.direction = Vector3(-0.1, 1.0, 0)
	sp.spread = 28.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.8
	sp.gravity = Vector3(0, 0.3, 0)
	sp.position = Vector3(9.4, 1.4, -2.0)
	add_child(sp)
	_mesh(VoxProps.candle(8), 0.03, Vector3(8.7, 2.85, -3.4))
	_mesh(VoxProps.candle(5), 0.03, Vector3(8.7, 2.85, -0.6))
	_mesh(VoxProps.mug(false), 0.03, Vector3(8.7, 2.85, -2.0), 70.0)
	var wheel := Vox.new(0.05)
	for k in 8:
		var a := TAU * k / 8.0
		wheel.line(Vector3i(0, 0, 0), Vector3i(roundi(cos(a) * 16), roundi(sin(a) * 16), 0), Color("#7a5232"), 0.06)
		wheel.box(roundi(cos(a) * 17), roundi(sin(a) * 17), -1, roundi(cos(a) * 17) + 2, roundi(sin(a) * 17) + 2, 2, Color("#6a4222"), 0.05)
	for k in 48:
		var a2 := TAU * k / 48.0
		wheel.box(roundi(cos(a2) * 15), roundi(sin(a2) * 15), 0, roundi(cos(a2) * 15) + 2, roundi(sin(a2) * 15) + 2, 1, Color("#8a6038"), 0.06)
	wheel.box(-2, -2, -1, 3, 3, 2, Color("#e6b840"), 0.04)
	_mesh(wheel.build(Vector3(0.5, 0.5, 0)), 0.05, Vector3(8.25, 4.7, -2.0), 90.0)


func _build_board_and_boss() -> void:
	Style.label3d(self, "WANTED: Goblins. Any.", Vector3(-10.4, 3.4, -2.2), 0.0035, Color("#3a2410"), Vector3(0, 90, 0))
	Style.label3d(self, "JOBS", Vector3(-10.4, 4.85, -1.0), 0.016, Color("#f3d98a"), Vector3(0, 90, 0))
	Interactable.make(self, Vector3(-9.2, 1.0, -1.0), "Browse the job board", Callable(self, "_job_board"), 3.2)

	Style.label3d(self, "GRUBNIK", Vector3(4.75, 3.35, -7.7), 0.006, Color("#2a1a0d"))
	Style.label3d(self, "DO NOT KNOCK. DO NOT WAIT.\nDO NOT EXIST.", Vector3(4.75, 4.1, -7.7), 0.0055, Color("#f3d98a"))
	for tx in [2.1, 7.4]:
		_mesh(VoxProps.torch(true), 0.04, Vector3(tx, 1.7, -7.72), 0.0)
		_light(Vector3(tx, 2.8, -7.0), Color("#ff9a3a"), 0.9, 6.0)
		_mesh(VoxProps.banner(Color("#9a2a3a")), 0.05, Vector3(tx + (-0.95 if tx < 4 else 0.95), 5.3, -7.76), 0.0)
	Interactable.make(self, Vector3(4.75, 1.0, -6.4), "Check the mail slot (Grubnik's letter)", Callable(self, "_boss_letter"), 3.2)

	Style.label3d(self, "WALL OF SHAME", Vector3(-10.4, 4.9, 4.6), 0.011, Color("#d8a0a0"), Vector3(0, 90, 0))
	_shame_labels = Style.label3d(self, "", Vector3(-10.4, 3.0, 4.6), 0.0055, Color("#e8d8d8"), Vector3(0, 90, 0))
	_shame_labels.line_spacing = 6
	_refresh_shame()
	for cz in [3.0, 6.2]:
		_mesh(VoxProps.candle(5), 0.03, Vector3(-10.2, 0.0, cz))
		_light(Vector3(-10.0, 0.6, cz), Color("#ffb04a"), 0.5, 3.5)
	Interactable.make(self, Vector3(-9.4, 1.0, 4.6), "Pay respects", Callable(self, "_respects"), 3.2)

	Style.label3d(self, "CELLAR (training)", Vector3(-5.0, 1.2, 3.2), 0.006, Color("#f3d98a"), Vector3.ZERO, true)
	Interactable.make(self, Vector3(-5.0, 0.6, 3.2), "Climb into the cellar (skills)", Callable(self, "_cellar"), 2.8)


func _make_marker(color: Color) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var v := Vox.new(0.06)
	for y in 6:
		var w := 6 - y
		v.box(-w, y, -w, w + 1, y + 1, w + 1, Color(color.r, color.g, color.b, 0.15), 0.0)
	var mi := VoxProps.mesh_instance(v.build(Vector3(0.5, 0, 0.5)), 0.06, 2.0, {"emission_strength": 1.3})
	mi.position = Vector3(0, -0.1, 0)
	n.add_child(mi)
	_light_attach(n, color)
	return n


func _light_attach(n: Node3D, color: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 0.5
	l.omni_range = 3.5
	l.position = Vector3(0, -0.4, 0)
	n.add_child(l)


## Gold arrow = your next objective; blue arrow = you have skill points to spend.
func _update_guide() -> void:
	var has_job := not Game.current_job.is_empty()
	var target := Vector3(0, 4.7, 7.2) if has_job else Vector3(-9.4, 4.6, -1.0)
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
		ui.hint("t_board", "Step 1: walk to the JOB BOARD on the left wall (follow the gold arrow) and press E to pick a contract. Dungeons are random every time!", 9.0)
	if has_job:
		ui.hint("t_door", "Contract taken! Swing the training dummy first if you like (left click), then head out the FRONT DOOR (gold arrow).", 8.0)
	if Game.deliveries + Game.deaths >= 1:
		ui.hint("t_services", "Between runs: GRUK (east corner) buys, sells and enhances gear. Your STASH is by the fire. MS. DEED sells houses (the ending!). TAB opens your backpack anywhere.", 11.0)
	if Game.skill_points > 0 and Game.deliveries + Game.deaths >= 1:
		ui.hint("t_cellar", "You have a skill point! Climb down the CELLAR hatch (blue arrow) to learn a new trick.", 8.0)


func _build_decor() -> void:
	var rug := VoxProps.rug(90, 60, Color("#a8322f"), Color("#d8a64a"))
	_mesh(rug, 0.1, Vector3(2.0, 0.02, 1.0))
	_mesh(VoxProps.rug(24, 32, Color("#3a4a8a"), Color("#d8a64a")), 0.1, Vector3(-2.2, 0.03, 5.4))
	var tabs := [[Vector3(3.0, 0, 2.0), 20.0], [Vector3(7.0, 0, 4.5), -10.0], [Vector3(2.0, 0, -3.0), 5.0]]
	for i in tabs.size():
		var tp: Vector3 = tabs[i][0]
		var ty: float = tabs[i][1]
		var tb := _mesh(VoxProps.table(), 0.05, tp, ty)
		Style.solid_box(self, Vector3(1.8, 1.0, 1.1), tp + Vector3(0, 0.5, 0))
		var cand := VoxProps.mesh_instance(VoxProps.candle(6), 0.03)
		cand.position = Vector3(0.1, 0.9, 0.0)
		tb.add_child(cand)
		var mg := VoxProps.mesh_instance(VoxProps.mug(), 0.03)
		mg.position = Vector3(-0.5, 0.9, 0.2)
		mg.rotation_degrees.y = 40
		tb.add_child(mg)
		var mg2 := VoxProps.mesh_instance(VoxProps.mug(false), 0.03)
		mg2.position = Vector3(0.55, 0.9, -0.2)
		tb.add_child(mg2)
		for sx in [-1.0, 1.0]:
			var st := VoxProps.mesh_instance(VoxProps.stool(), 0.05)
			st.position = Vector3(sx * 1.2, 0.0, 0.0)
			tb.add_child(st)
		_light(tp + Vector3(0.1, 1.5, 0.1), Color("#ffc070"), 0.8, 4.5)
	# the "dead letters" parcel pile by the fire
	var ppos := [Vector3(7.5, 0.0, 1.2), Vector3(8.3, 0.0, 1.9), Vector3(7.7, 0.72, 1.5), Vector3(6.9, 0.0, 2.1)]
	for i in ppos.size():
		_mesh(VoxProps.crate([Color("#9a6a3c"), Color("#8a5a30"), Color("#a87a48"), Color("#7a5230")][i]), 0.05, ppos[i], i * 31.0)
	Style.solid_box(self, Vector3(2.4, 1.6, 2.0), Vector3(7.7, 0.8, 1.6))
	Style.label3d(self, "DEAD LETTERS", Vector3(7.7, 2.2, 1.5), 0.008, Color("#c0a070"), Vector3.ZERO, true)
	for fl in [Vector3(-5, 4.6, 2.0), Vector3(2, 4.8, 1.0), Vector3(6, 4.6, 5.0), Vector3(-2, 4.6, -4.5), Vector3(7, 4.4, -3.5)]:
		var wl := OmniLight3D.new()
		wl.light_color = Color("#ffc888")
		wl.light_energy = 0.9
		wl.omni_range = 11.0
		wl.position = fl
		add_child(wl)
	for lp in [Vector3(-2, 4.5, 0), Vector3(5, 4.5, -4), Vector3(-8, 4.5, 4)]:
		_mesh(VoxProps.lantern(true), 0.04, lp)
		var chain2 := Vox.new(0.04)
		chain2.box(0, 0, 0, 1, 40, 1, Color("#3a3a46"), 0.04)
		_mesh(chain2.build(Vector3(0.5, 0, 0.5)), 0.04, lp + Vector3(0, 0.5, 0))
		_light(lp + Vector3(0, -0.2, 0), Color("#ffb04a"), 1.0, 8.0)


func _spawn_player() -> void:
	player = Player.new()
	player.ui = ui
	player.position = Vector3(1.0, 0.2, 3.0)
	add_child(player)
	player.setup_for_run("hub")
	player.yaw = 0.0
	player.pitch = -0.05


func _process(delta: float) -> void:
	_t += delta
	_board_t -= delta
	if _board_t <= 0.0:
		_board_t = 0.6
		_refresh_board()
	_update_guide()
	_animate_critters()


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
	Menus.show_contracts(ui, func(job: Dictionary):
		Game.current_job = job
		var msg := "Taken: %s. Head for the door." % job["title"]
		if job["kind"] == "dungeon":
			msg = "Contract: %s (tier %d). Head for the door!" % [Game.THEMES[job["theme"]]["name"], job["tier"]]
		ui.toast(msg, Color("#9dffa0")))


func _boss_letter(_by: Node) -> void:
	var text: String = Game.LETTERS[(Game.day * 3 + Game.deaths) % Game.LETTERS.size()]
	text += "\n\nToday's policy: " + str(Game.mandate["text"])
	ui.show_letter("A NOTE FROM GRUBNIK", text)


func _cellar(_by: Node) -> void:
	ui.show_skills()


func _bar_menu(_by: Node) -> void:
	var cap := int(Stats.compute()["grog"]) + 2
	var can_grog: bool = Game.copper >= 30 and Game.grog_stock < cap
	var sat_cost := 60 * (Game.perk_bottles + 1)
	var entries: Array = [
		{"label": "Goblin Grog  -  30 copper", "desc": "Heals 40%% of your HP when drunk (R). You carry %d / %d flasks. Tastes like regret and fire." % [Game.grog_stock, cap], "enabled": can_grog,
			"cb": func():
				Game.copper -= 30
				Game.grog_stock += 1
				Sfx.play("coin")
				_bar_menu(null)},
		{"label": "Bigger Bottle Satchel  -  %d copper" % sat_cost, "desc": "+1 starting throwing bottle in every dungeon, forever. (Now +%d.)" % Game.perk_bottles, "enabled": Game.copper >= sat_cost and Game.perk_bottles < 6,
			"cb": func():
				Game.copper -= sat_cost
				Game.perk_bottles += 1
				Sfx.play("coin")
				_bar_menu(null)},
	]
	var quip := "Brin: \"Coin first. Questions never.\""
	if Game.deaths > 3:
		quip = "Brin: \"You again? I just wiped the stain.\""
	ui.show_menu("THE SOGGY STAMP", quip + "      (%d copper)" % Game.copper, entries, "Never mind")


# ---------------------------------------------------------------- new services: smith, stash, realtor, dummy

func _build_services() -> void:
	# --- Gruk's anvil (east wall, south of the fireplace)
	var anvil := Vox.new(0.05)
	anvil.box(-5, 0, -4, 5, 6, 4, Color("#4a4a56"), 0.05)
	anvil.box(-8, 6, -5, 8, 9, 5, Color("#6a6a78"), 0.05)
	anvil.box(8, 7, -2, 13, 9, 2, Color("#6a6a78"), 0.05)
	anvil.box(-8, 9, -5, 8, 10, 5, Color("#8a8a98"), 0.04)
	_mesh(anvil.build(Vector3(0, 0, 0)), 0.05, Vector3(8.8, 0.0, 5.0), 90.0)
	Style.solid_box(self, Vector3(1.0, 1.0, 1.2), Vector3(8.8, 0.5, 5.0))
	var forge := Vox.new(0.05)
	forge.cobble(-8, 0, -6, 8, 12, 6, Color("#6a6a74"), 3)
	forge.box(-5, 8, 5, 5, 11, 6, Color("#ff7a20", 0.25), 0.1)
	forge.box(-4, 3, 5, 4, 6, 6, Color("#ffb030", 0.2), 0.1)
	_mesh(forge.build(Vector3(0, 0, 0)), 0.05, Vector3(10.4, 0.0, 6.3), 90.0)
	Style.solid_box(self, Vector3(1.0, 1.2, 1.6), Vector3(10.6, 0.6, 6.3))
	_light(Vector3(9.9, 1.4, 6.0), Color("#ff8a3a"), 2.2, 7.0)
	var gruk := GoblinModel.build(Color("#4a4a56"), Color("#6aa030"), false, GoblinModel.CAP, false)
	gruk.position = Vector3(9.5, 0.0, 4.2)
	gruk.rotation.y = -PI * 0.6
	gruk.scale = Vector3.ONE * 1.15
	add_child(gruk)
	Style.label3d(self, "GRUK'S ANVIL", Vector3(10.9, 3.0, 5.5), 0.009, Color("#f6e3a0"), Vector3(0, -90, 0))
	Style.label3d(self, "buy / sell / enhance", Vector3(10.9, 2.55, 5.5), 0.005, Color("#c0a070"), Vector3(0, -90, 0))
	Interactable.make(self, Vector3(9.2, 1.0, 4.6), "Talk to Gruk the Blacksmith", Callable(self, "_smith_menu"), 3.2)

	# --- the stash chest by the fire
	var chest_parts := DProps.chest(1)
	var cb := MeshInstance3D.new()
	cb.mesh = chest_parts["body"]
	cb.material_override = VMat.solid(0.05, 4.0)
	cb.position = Vector3(7.7, 0.0, -0.4)
	cb.rotation.y = PI * 0.5
	add_child(cb)
	var cl := MeshInstance3D.new()
	cl.mesh = chest_parts["lid"]
	cl.material_override = VMat.solid(0.05, 4.0)
	cl.position = Vector3(7.7 - 0.0, 0.4, -0.4)
	cl.rotation.y = PI * 0.5
	cl.position += Vector3(0.25, 0, 0)
	add_child(cl)
	Style.solid_box(self, Vector3(0.6, 0.5, 0.9), Vector3(7.7, 0.25, -0.4))
	Style.label3d(self, "YOUR STASH", Vector3(7.7, 1.3, -0.4), 0.006, Color("#cfe0ff"), Vector3.ZERO, true)
	Interactable.make(self, Vector3(7.5, 0.8, -0.4), "Open your stash", Callable(self, "_stash"), 2.8)

	# --- Ms. Deed, realtor
	var desk := _mesh(VoxProps.table(), 0.05, Vector3(-6.6, 0, 1.0), 90.0)
	Style.solid_box(self, Vector3(1.1, 1.0, 1.8), Vector3(-6.6, 0.5, 1.0))
	var deed := GoblinModel.build(Color("#7a3a8a"), Color("#a0c040"), true, Color("#6a2a7a"), false)
	deed.position = Vector3(-7.9, 0.0, 1.0)
	deed.rotation.y = PI * 0.5
	add_child(deed)
	_house_model = MeshInstance3D.new()
	_house_model.material_override = VMat.solid(VoxHouses.S, 4.0)
	_house_model.position = Vector3(-6.6, 0.92, 1.0)
	_house_model.rotation.y = PI * 0.5
	add_child(_house_model)
	_refresh_house()
	_light(Vector3(-6.2, 2.4, 1.0), Color("#ffe0a0"), 1.3, 6.0)
	Style.label3d(self, "MS. DEED  -  GOBLIN REALTY", Vector3(-9.6, 3.2, 1.0), 0.0065, Color("#f3d98a"), Vector3(0, 90, 0))
	Interactable.make(self, Vector3(-6.6, 1.0, 1.0), "Talk to Ms. Deed (buy a house!)", Callable(self, "_realtor"), 3.0)

	# --- the training dummy, by the door
	var dummy := Dummy.new()
	dummy.position = Vector3(5.2, 0.05, 5.6)
	add_child(dummy)


var _house_model: MeshInstance3D
var _cat: Dictionary = {}
var _pigeon: Dictionary = {}
var _bell_n := 0


func _refresh_house() -> void:
	if _house_model != null:
		_house_model.mesh = VoxHouses.build(Game.house_tier)
		var sc: Array = [0.75, 0.75, 0.7, 0.62, 0.5, 0.42]
		_house_model.scale = Vector3.ONE * float(sc[clampi(Game.house_tier, 0, 5)])


func _build_trophies() -> void:
	# a glass display case by the fire: one velvet pedestal per boss
	var cx := 4.9
	var cz := -1.0
	_mesh(VoxTavern.case_stand(), 0.05, Vector3(cx, 0, cz), 0.0)
	Style.solid_box(self, Vector3(3.5, 2.1, 1.0), Vector3(cx, 1.05, cz))
	Style.label3d(self, "TROPHY CASE", Vector3(cx, 2.35, cz), 0.007, Color("#f3d98a"), Vector3.ZERO, true)
	var order := ["auditor", "mimic_king", "landlord", "dragon"]
	var names := {"auditor": "The Auditor", "mimic_king": "Mimic King", "landlord": "The Landlord", "dragon": "Overdue Dragon"}
	var pedx := [-1.2, -0.4, 0.4, 1.2]
	for i in order.size():
		var id: String = order[i]
		var got := Game.trophies.has(id)
		var v := Vox.new(0.05)
		match id:
			"auditor":
				v.box(0, 0, 0, 8, 8, 8, Color("#d8d2bc"), 0.04)
				v.box(1, 5, 7, 3, 7, 8, Color("#1a1a22"), 0.0)
				v.box(5, 5, 7, 7, 7, 8, Color("#1a1a22"), 0.0)
				v.box(-1, 8, -1, 9, 9, 9, Color("#1a1a22"), 0.0)
				v.box(1, 9, 1, 7, 15, 7, Color("#1a1a22"), 0.0)
			"mimic_king":
				v.box(0, 0, 0, 12, 4, 8, Color("#e6b840"), 0.04)
				for ccx in [0, 3, 6, 9, 11]:
					v.box(ccx, 4, 0, ccx + 1, 8, 1, Color("#e6b840"), 0.04)
					v.box(ccx, 4, 7, ccx + 1, 8, 8, Color("#e6b840"), 0.04)
				v.box(5, 1, 7, 7, 3, 8, Color("#d83a4a", 0.5), 0.0)
			"landlord":
				v.cyl_y(0.0, 0.0, 0, 1, 4.0, 4.0, Color("#e6b840"), 0.03)
				v.remove_box(-2, 0, -2, 2, 1, 2)
				for k in 4:
					v.box(-5 + k * 3, -6, 0, -4 + k * 3, 0, 1, Color("#c8a030"), 0.05)
					v.box(-6 + k * 3, -8, 0, -3 + k * 3, -6, 1, Color("#c8a030"), 0.05)
				v.box(-6, 1, -1, 6, 3, 1, Color("#c8a030"), 0.03)
			"dragon":
				for y in 14:
					var w := maxi(5 - y / 3, 1)
					v.box(-w, y, -w, w, y + 1, w, Color("#e8d8a0").darkened(0.02 * y), 0.04)
		var pos := Vector3(cx + float(pedx[i]), 1.0 if id != "landlord" else 1.35, cz)
		var mi := _mesh(v.build_coarse(Vector3(4, 0, 4)), 0.05, pos, 0.0)
		mi.visible = got
		Style.label3d(self, names[id] if got else "???", Vector3(cx + float(pedx[i]), 0.55, cz - 0.52), 0.0042, Color("#f3d98a") if got else Color("#7a6a5a"), Vector3.ZERO)


func _smith_menu(_by: Node) -> void:
	ui.show_menu("GRUK THE BLACKSMITH", "Gruk: \"Anvil's hot. Wallet's not. Fix that.\"      %d copper" % Game.copper, [
		{"label": "Browse wares", "desc": "A fresh selection every day.", "cb": func(): Menus.show_shop(ui)},
		{"label": "Sell or enhance gear", "desc": "Enhance up to +5 (stats x1.08 each). Selling gives half value.", "cb": func(): Menus.show_inventory(ui, "smith")},
	], "Leave")


func _stash(_by: Node) -> void:
	Menus.show_inventory(ui, "stash")


func _realtor(_by: Node) -> void:
	Menus.show_realtor(ui, func(): _refresh_house())


# ---------------------------------------------------------------- a lived-in room

func _prop(mesh: Mesh, pos: Vector3, yaw := 0.0, scl := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VMat.solid(0.05, 4.0)
	mi.position = pos
	mi.rotation_degrees.y = yaw
	mi.scale = Vector3.ONE * scl
	add_child(mi)
	return mi


func _build_quota_desk() -> void:
	var v := Vox.new(0.05)
	var wood := Color("#6a4a2e")
	var dark := Color("#3e2a1a")
	var brass := Color("#d8a830")
	v.planks(0, 0, 0, 40, 16, 14, wood)
	v.box(-1, 16, -1, 41, 18, 15, dark)
	v.box(3, 18, 3, 13, 19, 11, Color("#e8dcb8"))
	v.box(4, 19, 4, 12, 20, 5, Color("#222222"))
	v.box(26, 18, 4, 36, 22, 10, dark)
	v.box(29, 22, 6, 33, 26, 8, brass)
	for i in 9:
		var h := 1 + i
		v.box(33 + i, 24 - h, 7 - h, 34 + i, 24 + h, 7 + h, brass if i % 3 != 2 else Color("#a07818"), 0.04)
	v.remove_box(37, 20, 4, 42, 30, 11)
	v.box(0, 16, 0, 2, 22, 2, Color("#c03030"))
	v.box(15, 18, 5, 21, 21, 9, Color("#8a5a2a"))
	v.box(16, 21, 6, 20, 22, 8, Color("#c8a040"))
	var mi := _mesh(v.build(Vector3(20, 0, 7)), 0.05, Vector3(-3.6, 0, 5.9), 180.0)
	mi.name = "QuotaDesk"
	Style.solid_box(self, Vector3(2.1, 0.9, 0.8), Vector3(-3.6, 0.45, 5.9))
	_light(Vector3(-3.6, 2.6, 5.6), Color("#ffd890"), 1.2, 5.0)
	_quota_board = Style.label3d(self, "", Vector3(-3.6, 2.5, 7.55), 0.008, Color("#ffe9a0"), Vector3(0, 180, 0))
	Style.label3d(self, "GRUBNIK'S QUOTA DESK", Vector3(-3.6, 3.05, 7.55), 0.007, Color("#f3d98a"), Vector3(0, 180, 0))
	Interactable.make(self, Vector3(-3.6, 1.0, 5.1), "Grubnik's quota desk (sell scrap / pay up)", Callable(self, "_quota_desk"), 3.0)
	_refresh_board()


func _refresh_board() -> void:
	if _quota_board == null:
		return
	var days := Game.quota_days_left()
	_quota_board.text = "QUOTA #%d\n%d / %d copper\n%d day%s left" % [Game.quota["n"], Game.quota["paid"], Game.quota["target"], days, "" if days == 1 else "s"]
	_quota_board.modulate = Color("#ff7a6a") if (days <= 1 and int(Game.quota["paid"]) < int(Game.quota["target"])) else Color("#ffe9a0")


func _quota_desk(_by: Node = null) -> void:
	ui.hint("quota", "QUOTA: Grubnik wants a set amount of copper every few days. Sell scrap from dungeons here (it counts 20% extra) or pay in copper. Meet it for a bonus and a rare gear drop; miss it and he 'adjusts' your wages.", 10.0)
	var paid := int(Game.quota["paid"])
	var target := int(Game.quota["target"])
	var days := Game.quota_days_left()
	var sub := "Quota #%d: %d / %d copper paid.   Due in %d day%s.\nSack: %d item%s worth about %d copper (%d toward quota)." % [
		Game.quota["n"], paid, target, days, "" if days == 1 else "s",
		Game.scrap.size(), "" if Game.scrap.size() == 1 else "s", Game.scrap_total(), int(round(Game.scrap_total() * Game.SCRAP_BONUS))]
	if paid >= target:
		sub += "\nQuota met! Wait for the deadline to collect your bonus, or keep overpaying (half of any extra comes back)."
	var entries: Array = []
	entries.append({"label": "Sell the whole sack  (+%d)" % int(round(Game.scrap_total() * Game.SCRAP_BONUS)), "desc": "Scrap counts 20% extra toward the quota.", "enabled": not Game.scrap.is_empty(), "cb": func():
		var worth := Game.sell_scrap()
		Sfx.play("coin")
		ui.toast("Sold scrap: +%d toward quota." % worth, Color("#ffe27a"))
		_refresh_board()
		_quota_desk()})
	for amt in [25, 100]:
		var a: int = amt
		entries.append({"label": "Pay %d copper" % a, "desc": "", "enabled": Game.copper >= a, "cb": func():
			Game.pay_quota(a)
			Sfx.play("coin")
			_refresh_board()
			_quota_desk()})
	entries.append({"label": "Pay everything you've got  (%d)" % Game.copper, "desc": "", "enabled": Game.copper > 0, "cb": func():
		Game.pay_quota(Game.copper)
		Sfx.play("coin")
		_refresh_board()
		_quota_desk()})
	ui.show_menu("GRUBNIK'S QUOTA DESK", sub, entries, "Leave")


func _build_extras() -> void:
	# --- hanging from the beams: hams, sausages, herbs, a chandelier and a caged ex-employee
	for hp in [Vector3(-2.75, 5.45, 1.4), Vector3(-2.75, 5.35, 2.7), Vector3(-2.75, 5.5, -0.8), Vector3(-5.75, 5.4, 4.5)]:
		_prop(VoxTavern.ham(), hp, randf() * 360.0)
	for sp in [Vector3(3.25, 5.6, 4.0), Vector3(3.25, 5.6, -2.2), Vector3(-8.75, 5.6, 2.0)]:
		_prop(VoxTavern.sausages(), sp, 90.0)
	for hb in [Vector3(-8.7, 5.55, -1.0), Vector3(-8.7, 5.55, 4.0), Vector3(-5.8, 5.55, -0.5), Vector3(0.25, 5.55, -3.0)]:
		_prop(VoxTavern.herbs(), hb, randf() * 360.0)
	_prop(DProps.chain(26), Vector3(0.25, 5.85, 1.0))
	_prop(VoxTavern.chandelier(), Vector3(0.25, 4.5, 1.0), 0.0)
	_light(Vector3(0.25, 4.3, 1.0), Color("#ffc878"), 1.3, 9.0)
	_prop(DProps.chain(22), Vector3(3.25, 5.8, 0.6))
	_prop(VoxTavern.cage(), Vector3(3.25, 3.5, 0.6), 0.0)
	Style.label3d(self, "Previous Employee", Vector3(3.25, 5.0, 0.6), 0.0045, Color("#d8c8a0"), Vector3.ZERO, true)

	# --- south wall: weapon rack, armour, shield, posters, coat rack, welcome mat
	_prop(VoxTavern.weapon_rack(), Vector3(-6.5, 0, 7.8), 180.0)
	Style.solid_box(self, Vector3(1.6, 1.5, 0.4), Vector3(-6.5, 0.75, 7.7))
	_prop(VoxTavern.armor_stand(), Vector3(-4.4, 0, 7.4), 180.0)
	Style.solid_box(self, Vector3(0.7, 2.0, 0.6), Vector3(-4.4, 1.0, 7.4))
	_prop(VoxTavern.shield(Color("#2a4a8a")), Vector3(-9.0, 2.6, 7.95), 180.0)
	_prop(VoxTavern.shield(Color("#8a2a2a")), Vector3(-9.0, 1.6, 7.95), 180.0, 0.8)
	for pi in 3:
		_prop(VoxTavern.poster(pi), Vector3(-2.9 + pi * 0.7, 2.6 - (pi % 2) * 0.15, 7.96), 180.0)
	_prop(VoxTavern.coat_rack(), Vector3(2.9, 0, 7.4))
	_prop(VoxTavern.welcome_mat(), Vector3(0, 0.03, 6.2))
	_prop(VoxTavern.plant(1), Vector3(3.8, 0, 7.3))
	_prop(VoxTavern.plant(0), Vector3(-1.9, 0, 7.4))
	_prop(VoxTavern.island_map(), Vector3(2.2, 2.7, 7.95), 180.0)
	Style.label3d(self, "THE ISLAND (X = where the parcels went)", Vector3(2.2, 2.35, 7.9), 0.0035, Color("#3a2410"), Vector3(0, 180, 0))
	_prop(VoxTavern.lute(), Vector3(-10.9, 2.7, -6.9), 90.0)
	_prop(VoxTavern.poster(1), Vector3(-10.93, 2.2, -6.0), 90.0)

	# --- north wall: bookshelf, chalkboard, plants
	_prop(VoxTavern.bookshelf(), Vector3(2.0, 0, -7.85))
	Style.solid_box(self, Vector3(2.2, 2.6, 0.5), Vector3(2.0, 1.3, -7.7))
	_prop(VoxTavern.plant(0), Vector3(0.7, 0, -7.3))
	var ch := _prop(VoxTavern.chalkboard(), Vector3(0.95, 0, -2.5), 0.0)
	ch.position.y = 0.0
	Style.label3d(self, "TODAY:\nGROG  (always)\nGROG  (large)\nSOUP  (no)", Vector3(0.95, 0.85, -2.43), 0.0042, Color("#f0ecd8"), Vector3.ZERO)

	# --- the bar: tankards, a pile of other people's copper
	_prop(VoxTavern.tankard_set(), Vector3(-7.7, 1.52, -4.2), 10.0)
	_prop(VoxTavern.tankard_set(), Vector3(-3.6, 1.52, -3.8), -25.0)
	_prop(VoxTavern.gold_pile(), Vector3(-1.2, 1.52, -4.1))
	_prop(VoxTavern.plate(1), Vector3(-5.2, 1.52, -3.7))
	_prop(VoxTavern.plate(2), Vector3(-9.2, 1.52, -3.9), 40.0)

	# --- sorting table (the post office part of the post office)
	_prop(VoxTavern.sorting_table(), Vector3(-3.2, 0, -1.2), 0.0)
	Style.solid_box(self, Vector3(1.8, 1.0, 0.9), Vector3(-3.2, 0.5, -1.2))
	var bell := _prop(VoxTavern.bell(), Vector3(-2.7, 1.0, -1.0))
	Style.label3d(self, "SORTING DESK", Vector3(-3.2, 2.15, -1.2), 0.0055, Color("#f3d98a"), Vector3.ZERO, true)
	var bi := Interactable.make(self, Vector3(-2.7, 1.2, -1.0), "Ring the service bell", Callable(), 2.6)
	bi.callback = func(_by: Node):
		_bell_n += 1
		Sfx.play("bell")
		var lines := ["Brin: \"WHAT.\"", "Brin: \"Ring that again and I charge you.\"", "Brin: \"I am RIGHT HERE.\"", "Brin: \"...fine. Take a stamp.\"", "A crow somewhere gets very excited."]
		ui.toast(lines[(_bell_n - 1) % lines.size()], Color("#ffe9a0"))
		Style.burst(self, bell.global_position + Vector3(0, 0.5, 0), Color("#ffe27a"), 6, 2.0, 0.06, 0.5)

	# --- the fire corner: bear rug, rocking chair, cat, cauldron, firewood, hay
	_prop(VoxTavern.bear_rug(), Vector3(6.6, 0.03, -3.6), 90.0)
	_prop(VoxTavern.rocking_chair(), Vector3(7.5, 0, -2.7), 90.0)
	Style.solid_box(self, Vector3(0.6, 0.9, 0.6), Vector3(7.5, 0.45, -2.7))
	_prop(VoxTavern.cauldron(), Vector3(9.55, 0.1, -3.2))
	_prop(VoxTavern.firewood(), Vector3(9.9, 0, -7.0), 90.0)
	_prop(VoxTavern.hay(), Vector3(7.5, 0, -7.2), 8.0)
	Style.solid_box(self, Vector3(1.0, 0.6, 0.6), Vector3(7.5, 0.3, -7.2))
	_prop(VoxTavern.plant(1), Vector3(10.2, 0, -0.2))
	_cat = _make_cat(Vector3(6.2, 0.05, -4.4), 35.0)

	# --- food on the tables, more candles, a pigeon who pays no rent
	var tspots := [Vector3(3.0, 0.9, 2.0), Vector3(7.0, 0.9, 4.5), Vector3(2.0, 0.9, -3.0)]
	for i in tspots.size():
		_prop(VoxTavern.plate(i), tspots[i] + Vector3(0.4, 0, 0.3), 20.0 * i)
		_prop(VoxTavern.plate(i + 1), tspots[i] + Vector3(-0.2, 0, -0.35), -30.0)
		_prop(VoxTavern.tankard_set(), tspots[i] + Vector3(-0.9, 0, 0.1), 80.0 * i, ).scale = Vector3.ONE * 0.7
	_pigeon = _make_pigeon(Vector3(-10.55, 4.78, -0.6))
	Style.label3d(self, "Gerald", Vector3(-10.4, 5.35, -0.6), 0.0045, Color("#d8d8e8"), Vector3(0, 90, 0))


func _make_cat(pos: Vector3, yaw: float) -> Dictionary:
	var parts := VoxTavern.cat(Color("#d88a3a"))
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	var mat := VMat.solid(0.05, 4.0)
	var body := MeshInstance3D.new()
	body.mesh = parts["body"]
	body.material_override = mat
	root.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = parts["head"]
	head.material_override = mat
	head.position = Vector3(0, 0.05, 0.35)
	root.add_child(head)
	var tail := MeshInstance3D.new()
	tail.mesh = parts["tail"]
	tail.material_override = mat
	tail.position = Vector3(0.0, 0.1, -0.3)
	tail.rotation_degrees.y = 180.0
	root.add_child(tail)
	return {"root": root, "tail": tail, "head": head}


func _make_pigeon(pos: Vector3) -> Dictionary:
	var parts := VoxTavern.pigeon()
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = 90.0
	add_child(root)
	var mat := VMat.solid(0.05, 4.0)
	var body := MeshInstance3D.new()
	body.mesh = parts["body"]
	body.material_override = mat
	root.add_child(body)
	var head := MeshInstance3D.new()
	head.mesh = parts["head"]
	head.material_override = mat
	head.position = Vector3(0, 0.25, 0.3)
	root.add_child(head)
	return {"root": root, "head": head}


func _animate_critters() -> void:
	if not _cat.is_empty():
		(_cat["tail"] as Node3D).rotation_degrees.y = 180.0 + sin(_t * 1.6) * 28.0
		(_cat["head"] as Node3D).position.y = 0.05 + sin(_t * 1.1) * 0.012           # slow purr-breathing
	if not _pigeon.is_empty():
		var h := _pigeon["head"] as Node3D
		h.position.z = 0.3 + (0.06 if int(_t * 2.2) % 3 == 0 else 0.0)
		h.rotation_degrees.y = sin(_t * 0.7) * 25.0
