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


func _ready() -> void:
	Atmos.interior(self)
	_build_room()
	_build_bar()
	_build_fireplace()
	_build_board_and_boss()
	_build_decor()
	_spawn_player()
	_mk_main = _make_marker(Color("#ffd24a"))
	_mk_cellar = _make_marker(Color("#7fd8ff"))
	Atmos.motes(player.cam, Color("#ffd48a"), 60, Vector3(9, 3, 9), 0.05)
	ui.configure_hud(false)
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
	for cl in [[Vector3(9.5, 0.9, 6.6), 0], [Vector3(10.1, 0.9, 5.5), 1], [Vector3(-9.6, 0.9, 6.8), 0], [Vector3(-8.6, 0.9, 7.0), 1], [Vector3(9.5, 0.9, -6.6), 0]]:
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
		ui.hint("t_board", "Step 1: walk to the JOB BOARD on the left wall (follow the gold arrow) and press E to pick a parcel.", 8.0)
	if has_job:
		ui.hint("t_door", "Parcel taken! Now head out the FRONT DOOR (the gold arrow) to start the delivery.", 8.0)
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
	player.setup_for_run(false)
	player.yaw = 0.0
	player.pitch = -0.05


func _process(delta: float) -> void:
	_t += delta
	_update_guide()


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
