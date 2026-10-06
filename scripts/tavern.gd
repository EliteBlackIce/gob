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
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0e0a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6d5f88")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.12
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#7a9ae0")
	moon.light_energy = 0.5
	moon.rotation_degrees = Vector3(-50, 160, 0)
	add_child(moon)


func _build_room() -> void:
	var wood := Color("#5e3f25")
	var wall := Color("#4a3320")
	var beam := Color("#35220f")
	for i in 11:
		Style.box(self, Vector3(2.0, 0.2, 16.0), wood if i % 2 == 0 else wood.darkened(0.12), Vector3(-10.0 + i * 2.0, -0.1, 0))
	Style.solid_box(self, Vector3(22, 0.6, 16), Vector3(0, -0.3, 0))
	# walls with beams
	Style.box(self, Vector3(22, 6.5, 0.4), wall, Vector3(0, 3.25, -8.2))
	Style.box(self, Vector3(22, 6.5, 0.4), wall, Vector3(0, 3.25, 8.2))
	Style.box(self, Vector3(0.4, 6.5, 16), wall, Vector3(-11.2, 3.25, 0))
	Style.box(self, Vector3(0.4, 6.5, 16), wall, Vector3(11.2, 3.25, 0))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, -8.3))
	Style.solid_box(self, Vector3(22, 7, 0.6), Vector3(0, 3.5, 8.3))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(-11.3, 3.5, 0))
	Style.solid_box(self, Vector3(0.6, 7, 16), Vector3(11.3, 3.5, 0))
	Style.box(self, Vector3(22, 0.4, 16), beam, Vector3(0, 6.6, 0))
	for i in 7:
		Style.box(self, Vector3(0.45, 6.5, 0.5), beam, Vector3(-9.0 + i * 3.0, 3.25, -7.9))
		Style.box(self, Vector3(0.45, 6.5, 0.5), beam, Vector3(-9.0 + i * 3.0, 3.25, 7.9))
		Style.box(self, Vector3(0.5, 0.5, 15.6), beam, Vector3(-9.0 + i * 3.0, 6.2, 0))
	for i in 5:
		Style.box(self, Vector3(0.5, 6.5, 0.5), beam, Vector3(-10.9, 3.25, -6.0 + i * 3.0))
		Style.box(self, Vector3(0.5, 6.5, 0.5), beam, Vector3(10.9, 3.25, -6.0 + i * 3.0))
	# exit door (front wall)
	Style.box(self, Vector3(2.6, 3.6, 0.3), beam, Vector3(0, 1.8, 7.9))
	Style.box(self, Vector3(2.2, 3.3, 0.16), Color("#7a5232"), Vector3(0, 1.65, 7.7))
	Style.box(self, Vector3(0.14, 0.5, 0.14), Color("#e0b84a"), Vector3(0.7, 1.6, 7.55), Vector3.ZERO, 0.3)
	Style.label3d(self, "OUT (to certain peril)", Vector3(0, 3.9, 7.7), 0.012, Color("#f3d98a"), Vector3(0, 180, 0))
	Style.light(self, Color("#9ab8ff"), 0.9, 7.0, Vector3(0, 2.5, 6.0))
	Interactable.make(self, Vector3(0, 1.0, 6.9), "Head out to work", Callable(self, "_exit_door"), 3.0)
	# windows with moonlight
	for wx in [-7.0, 7.0]:
		Style.box(self, Vector3(1.8, 1.8, 0.2), Color("#2a3a6a"), Vector3(wx, 3.2, 7.95), Vector3.ZERO, 0.8)
		Style.box(self, Vector3(1.95, 0.12, 0.3), beam, Vector3(wx, 3.2, 7.85))
		Style.box(self, Vector3(0.12, 1.95, 0.3), beam, Vector3(wx, 3.2, 7.85))
		Style.light(self, Color("#8aa8ff"), 0.7, 8.0, Vector3(wx, 3.0, 6.0))


func _build_bar() -> void:
	var wood := Color("#7a5430")
	var rope := Color("#c8b48a")
	for i in 6:
		var bx := -9.0 + i * 1.6
		Style.cyl(self, 0.62, 0.62, 1.1, Color("#8a5a30"), Vector3(bx, 0.55, -4.0), Vector3.ZERO, 9)
		Style.torus(self, 0.03, 0.6, Color("#3a2a1a"), Vector3(bx, 0.3, -4.0))
		Style.torus(self, 0.03, 0.6, Color("#3a2a1a"), Vector3(bx, 0.85, -4.0))
	Style.box(self, Vector3(10.0, 0.18, 1.5), wood, Vector3(-5.6, 1.15, -4.0))
	Style.box(self, Vector3(10.0, 0.06, 0.1), rope, Vector3(-5.6, 0.7, -3.3))
	Style.solid_box(self, Vector3(10.0, 1.3, 1.5), Vector3(-5.6, 0.65, -4.0))
	for i in 5:
		Style.cyl(self, 0.55, 0.55, 1.0, Color("#6a4527"), Vector3(-9.2 + i * 1.7, 0.5, -7.2), Vector3.ZERO, 9)
		Style.cyl(self, 0.5, 0.5, 0.9, Color("#6a4527"), Vector3(-9.2 + i * 1.7, 1.5, -7.2), Vector3.ZERO, 9)
	for i in 4:
		Style.box(self, Vector3(1.8, 0.1, 0.5), wood.darkened(0.2), Vector3(-9.0 + i * 2.2, 3.0, -7.7))
		for k in 3:
			Style.cyl(self, 0.07, 0.07, 0.4, [Color("#3e9c5a"), Color("#c0504a"), Color("#d8a04a")][k], Vector3(-9.5 + i * 2.2 + k * 0.4, 3.25, -7.7), Vector3.ZERO, 6, 0.12)
	Style.label3d(self, "THE SOGGY STAMP", Vector3(-5.6, 4.6, -7.9), 0.014, Color("#f3d98a"))
	var bt := GoblinModel.build(Color("#8a3a30"), Color("#7aa83a"), false)
	bt.position = Vector3(-5.6, 0, -5.6)
	add_child(bt)
	Style.light(self, Color("#ffb347"), 1.4, 7.5, Vector3(-5.6, 3.2, -4.5))
	Style.cyl(self, 0.08, 0.1, 0.25, Color("#f4efd8"), Vector3(-2.0, 1.34, -3.8), Vector3.ZERO, 6)
	Style.sphere(self, 0.07, Color("#ffd27a"), Vector3(-2.0, 1.52, -3.8), Vector3.ONE, 5, 1.6)
	Style.light(self, Color("#ffcf7a"), 0.8, 4.0, Vector3(-2.0, 1.8, -3.8))
	Interactable.make(self, Vector3(-5.0, 1.0, -2.6), "Chat with Brin the barkeep", Callable(self, "_bar_menu"), 3.4)


func _build_fireplace() -> void:
	var stone := Color("#6a6a74")
	Style.box(self, Vector3(1.4, 4.4, 5.0), stone, Vector3(10.4, 2.2, -2.0))
	Style.box(self, Vector3(1.0, 2.0, 2.6), Color("#14100e"), Vector3(9.95, 1.2, -2.0))
	Style.box(self, Vector3(1.8, 0.35, 5.4), stone.lightened(0.1), Vector3(10.1, 4.5, -2.0))
	Style.box(self, Vector3(1.4, 0.3, 3.4), stone.lightened(0.1), Vector3(10.2, 0.15, -2.0))
	var wheel := Node3D.new()
	wheel.position = Vector3(10.15, 5.5, -2.0)
	wheel.rotation_degrees = Vector3(0, 90, 0)
	add_child(wheel)
	Style.torus(wheel, 0.1, 0.75, Color("#7a5232"))
	for k in 8:
		Style.box(wheel, Vector3(0.08, 1.7, 0.1), Color("#7a5232"), Vector3.ZERO, Vector3(0, 0, k * 22.5))
	for k in 3:
		var f := Style.cone(self, 0.3 - k * 0.05, 1.0 - k * 0.15, [Color("#ff8a2a"), Color("#ffb347"), Color("#fff0a0")][k], Vector3(9.9, 0.7 + k * 0.1, -2.0 + (k - 1) * 0.45), Vector3.ZERO, 5)
		(f.material_override as ShaderMaterial).set_shader_parameter("emission_strength", 1.6)
		_flames.append(f)
	for k in 4:
		Style.cyl(self, 0.12, 0.12, 1.6, Color("#4a2f1a"), Vector3(10.0, 0.25, -2.6 + k * 0.4), Vector3(0, 0, 90), 6)
	_fire_light = Style.light(self, Color("#ff8a3a"), 3.6, 13.0, Vector3(8.6, 1.2, -2.0))
	_fire_light.shadow_enabled = true
	Style.light(self, Color("#ffb060"), 1.2, 7.0, Vector3(8.8, 2.8, -2.0))
	# sparks
	var sp := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	sp.mesh = bm
	sp.material_override = Style.mat(Color("#ffcf7a"), 0.0, 2.0)
	sp.amount = 18
	sp.lifetime = 1.6
	sp.direction = Vector3.UP
	sp.spread = 30.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.8
	sp.gravity = Vector3(0, 0.3, 0)
	sp.position = Vector3(9.9, 1.4, -2.0)
	add_child(sp)


func _build_board_and_boss() -> void:
	# job board (left wall)
	Style.box(self, Vector3(0.3, 3.4, 4.2), Color("#6a4527"), Vector3(-10.85, 2.6, -1.0))
	Style.box(self, Vector3(0.1, 3.0, 3.8), Color("#8a6a45"), Vector3(-10.65, 2.6, -1.0))
	for k in 6:
		Style.box(self, Vector3(0.06, 0.8, 0.6), Color("#f1e6c8").darkened(randf() * 0.12), Vector3(-10.55, 2.0 + (k % 3) * 0.9, -2.2 + (k / 3) * 2.0), Vector3(randf_range(-8, 8), 0, randf_range(-8, 8)))
	Style.label3d(self, "JOBS", Vector3(-10.5, 4.7, -1.0), 0.03, Color("#f3d98a"), Vector3(0, 90, 0))
	Interactable.make(self, Vector3(-9.2, 1.0, -1.0), "Browse the job board", Callable(self, "_job_board"), 3.2)

	# boss door (back wall)
	Style.box(self, Vector3(2.8, 4.0, 0.3), Color("#35220f"), Vector3(4.6, 2.0, -7.9))
	Style.box(self, Vector3(2.4, 3.7, 0.2), Color("#4a3a52"), Vector3(4.6, 1.85, -7.75))
	Style.box(self, Vector3(1.4, 0.4, 0.08), Color("#e0b84a"), Vector3(4.6, 2.6, -7.62), Vector3.ZERO, 0.2)
	Style.label3d(self, "GRUBNIK", Vector3(4.6, 2.6, -7.55), 0.007, Color("#2a1a0d"))
	Style.label3d(self, "DO NOT KNOCK. DO NOT WAIT.\nDO NOT EXIST.", Vector3(4.6, 3.3, -7.58), 0.006, Color("#f3d98a"))
	Style.box(self, Vector3(0.9, 0.12, 0.1), Color("#1a1a1a"), Vector3(4.6, 1.2, -7.6))
	Interactable.make(self, Vector3(4.6, 1.0, -6.4), "Check the mail slot (Grubnik's letter)", Callable(self, "_boss_letter"), 3.2)

	# wall of shame (left wall, front half)
	Style.box(self, Vector3(0.2, 3.4, 5.2), Color("#2a2030"), Vector3(-10.9, 2.7, 4.6))
	Style.label3d(self, "WALL OF SHAME", Vector3(-10.7, 4.8, 4.6), 0.02, Color("#d8a0a0"), Vector3(0, 90, 0))
	_shame_labels = Style.label3d(self, "", Vector3(-10.7, 2.9, 4.6), 0.0055, Color("#e8d8d8"), Vector3(0, 90, 0))
	_shame_labels.line_spacing = 6
	_refresh_shame()
	Interactable.make(self, Vector3(-9.4, 1.0, 4.6), "Pay respects", Callable(self, "_respects"), 3.2)

	# cellar hatch
	Style.box(self, Vector3(2.0, 0.12, 2.0), Color("#35220f"), Vector3(-5.0, 0.05, 3.2))
	for k in 4:
		Style.box(self, Vector3(1.8, 0.1, 0.35), Color("#4a3320"), Vector3(-5.0, 0.12, 2.6 + k * 0.4))
	Style.torus(self, 0.03, 0.18, Color("#8a8a92"), Vector3(-5.0, 0.2, 3.2), Vector3(90, 0, 0))
	Style.label3d(self, "CELLAR (training)", Vector3(-5.0, 1.3, 3.2), 0.01, Color("#f3d98a"))
	Interactable.make(self, Vector3(-5.0, 0.6, 3.2), "Climb into the cellar (skills)", Callable(self, "_cellar"), 2.8)


func _build_decor() -> void:
	# tables with candles
	for tp in [Vector3(3.0, 0, 2.0), Vector3(7.0, 0, 4.5), Vector3(2.0, 0, -3.0)]:
		Style.cyl(self, 0.9, 0.9, 0.12, Color("#7a5430"), tp + Vector3(0, 0.95, 0), Vector3.ZERO, 8)
		Style.cyl(self, 0.12, 0.2, 0.95, Color("#4a3320"), tp + Vector3(0, 0.47, 0), Vector3.ZERO, 6)
		Style.cyl(self, 0.06, 0.07, 0.2, Color("#f4efd8"), tp + Vector3(0.2, 1.1, 0.1), Vector3.ZERO, 6)
		Style.sphere(self, 0.05, Color("#ffd27a"), tp + Vector3(0.2, 1.25, 0.1), Vector3.ONE, 5, 1.8)
		Style.light(self, Color("#ffcf7a"), 0.7, 4.5, tp + Vector3(0.2, 1.6, 0.1))
		Style.solid_box(self, Vector3(1.6, 1.0, 1.6), tp + Vector3(0, 0.5, 0))
		for s in [-1, 1]:
			Style.box(self, Vector3(0.9, 0.12, 0.35), Color("#6a4527"), tp + Vector3(s * 1.3, 0.5, 0))
	# parcel pile (mail sorting)
	for pk in [Vector3(7.5, 0.3, 1.2), Vector3(8.2, 0.3, 1.9), Vector3(7.7, 0.85, 1.5), Vector3(6.9, 0.25, 2.1)]:
		Style.box(self, Vector3(0.8, 0.6, 0.7), Color("#a07a48").lightened(randf() * 0.2), pk, Vector3(0, randf_range(-30, 30), 0))
	Style.solid_box(self, Vector3(2.4, 1.6, 2.0), Vector3(7.7, 0.8, 1.6))
	Style.label3d(self, "DEAD LETTERS", Vector3(7.7, 2.2, 1.5), 0.008, Color("#c0a070"))
	# pigeonholes
	Style.box(self, Vector3(4.0, 2.4, 0.3), Color("#5a3a20"), Vector3(6.5, 2.4, 7.8))
	for r in 3:
		for c in 6:
			Style.box(self, Vector3(0.55, 0.55, 0.12), Color("#2a1a0d"), Vector3(5.0 + c * 0.6, 1.6 + r * 0.7, 7.6))
			if (r * 6 + c) % 3 == 0:
				Style.box(self, Vector3(0.3, 0.2, 0.05), Color("#f1e6c8"), Vector3(5.0 + c * 0.6, 1.6 + r * 0.7, 7.52))
	# hanging lanterns
	for lp in [Vector3(-2, 5.2, 0), Vector3(5, 5.2, -4), Vector3(-8, 5.2, 4)]:
		Style.cyl(self, 0.02, 0.02, 1.4, Color("#2a1a0d"), lp + Vector3(0, 0.7, 0), Vector3.ZERO, 4)
		Style.box(self, Vector3(0.4, 0.5, 0.4), Color("#ffcf6a"), lp, Vector3.ZERO, 1.4)
		Style.light(self, Color("#ffb347"), 1.1, 7.0, lp + Vector3(0, -0.3, 0))
	# the mighty ship's wheel hanging from the ceiling
	var w := Node3D.new()
	w.position = Vector3(-2.0, 5.6, -6.6)
	add_child(w)
	Style.torus(w, 0.08, 0.6, Color("#7a5232"), Vector3.ZERO, Vector3(90, 0, 0))


func _spawn_player() -> void:
	player = Player.new()
	player.ui = ui
	player.cam_dist = 4.6
	player.pitch = -0.2
	player.position = Vector3(1.0, 0.2, 3.0)
	add_child(player)
	player.setup_for_run(false)
	player.model.rotation.y = PI
	player.yaw = 0.0


func _make_marker(color: Color) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	Style.cyl(n, 0.0, 0.2, 0.42, color, Vector3.ZERO, Vector3(180, 0, 0), 4, 0.7)
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
	if _fire_light != null:
		_fire_light.light_energy = 3.0 + sin(_t * 13.0) * 0.4 + sin(_t * 7.3) * 0.3
	for i in _flames.size():
		_flames[i].scale = Vector3(1.0, 1.0 + sin(_t * 11.0 + i * 2.0) * 0.18, 1.0)


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
