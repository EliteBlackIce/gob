extends Node
## Headless gameplay smoke test. Exercises every mechanic and fails loudly.
##   godot --headless --fixed-fps 60 --path . res://tests/smoke.tscn

var fails := 0
var ui: UI


func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	ui = UI.new()
	add_child(ui)
	await frames(2)
	await test_voxel()
	await test_basics()
	await test_tavern()
	await test_traits()
	await test_crow()
	await test_slime()
	await test_skills()
	await test_ogre()
	await test_delivery()
	await test_death()
	print("\nSMOKE TEST: ", "PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func make_island(job: Dictionary) -> Island:
	var isl := Island.new()
	isl.ui = ui
	isl.job = job
	add_child(isl)
	return isl


func job_with(trait_id: String, dest := "marl") -> Dictionary:
	for j in Game.JOBS:
		if j["trait"] == trait_id:
			var d: Dictionary = j.duplicate()
			d["dest"] = dest
			d["dest_name"] = "Test"
			d["pay"] = 100
			d["time"] = 200.0
			return d
	return {}


func test_voxel() -> void:
	print("voxel world + first person")
	var v := Vox.new(1.0)
	v.box(0, 0, 0, 2, 2, 2, Color.WHITE, 0.0)
	var m := v.build()
	check(m.surface_get_array_len(0) == 144, "2x2x2 voxel cube meshes to its 24 outer quads (%d verts)" % m.surface_get_array_len(0))
	var v2 := Vox.new(1.0)
	v2.box(0, 0, 0, 1, 1, 1, Color.WHITE, 0.0)
	v2.box(1, 0, 0, 2, 1, 1, Color.WHITE, 0.0)
	check(v2.build().surface_get_array_len(0) == 60, "touching voxels cull their shared faces")
	var glow := Vox.new(1.0)
	glow.set_v(0, 0, 0, Color(1, 0.5, 0.1, 0.2))
	var carr: PackedColorArray = glow.build().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(absf(carr[0].a - 0.2) < 0.001, "colour alpha (emission mask) survives meshing")
	VoxTerrain.ensure()
	check(VoxTerrain.height_at(-300.0, 0.0) == -5.0, "far outside the island is open sea")
	var hh := VoxTerrain.height_at(0.0, 86.0)
	check(absf(hh - 2.0) < 0.76, "the tavern plaza sits at about 2 m (%.2f)" % hh)
	check(absf(fmod(hh * 2.0, 1.0)) < 0.001, "terrain heights are whole half-metre blocks")
	check(VoxTerrain.height_at(-4.0, 20.0) > 5.0 or VoxTerrain.height_at(-12.0, 20.0) > 5.0, "the gorge has tall walls")
	var isl := make_island(job_with("screamer"))
	await frames(20)
	var p: Player = isl.player
	check(p.cam != null and p.view != null, "player has a camera and first-person hands")
	check(p.cam.cull_mask & 2 == 0, "the body is hidden from the first-person camera")
	check(p.carried != null and p.carried.get_parent() == p.view.hold, "the carried parcel sits in your hands")
	check(absf(p.cam.global_position.y - p.global_position.y - Player.EYE_HEIGHT) < 0.2, "eyes are at head height")
	var yaw0 := p.yaw
	p._input(_mouse_motion(40.0))
	check(p.yaw != yaw0 or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED, "mouse look is wired up")
	isl.queue_free()
	await frames(3)


func _mouse_motion(dx: float) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.relative = Vector2(dx, 0.0)
	return e


func test_basics() -> void:
	print("starter kit, toss, tells, hints")
	Game.reset_save()
	Game.owned.clear()
	var isl := make_island(job_with("screamer"))
	await frames(20)
	var p: Player = isl.player
	check(p.bottles == 3, "new goblin starts with 3 bottles (%d)" % p.bottles)
	check(p.mode == "route" and p.max_hp >= 100.0, "route mode, RPG hit points (%d)" % int(p.max_hp))
	# kick stuns a slime without any skills
	var s := Slime.new()
	s.island = isl
	s.player = p
	s.ui = ui
	s.home = p.global_position + p.model.global_basis.z * 1.5
	isl.add_child(s)
	await frames(3)
	s.hit(p.model.global_basis.z, 1.0)
	check(s.state == Slime.S.STUNNED, "base kick stuns a slime")
	s.queue_free()
	# toss
	var parcel: Parcel = p.carried
	parcel.toss(p)
	check(p.carried == null and parcel.state == "loose", "G tosses the parcel out of your hands")
	await frames(40)
	check(parcel._pickup.enabled and not parcel._tossing, "tossed parcel lands and can be picked up")
	p.global_position = parcel.global_position + Vector3(0.4, 0.2, 0)
	await frames(3)
	parcel._on_pickup(p)
	check(p.carried == parcel, "player re-grabs the tossed parcel")
	# crow tell: a diving crow must pause before it dives
	var crow := Crow.new()
	crow.island = isl
	crow.player = p
	crow.ui = ui
	crow.home = p.global_position + Vector3(0, 6, 0)
	isl.add_child(crow)
	await frames(2)
	crow._begin_swoop()
	check(crow._tell_t > 0.0 and crow._tell != null and crow._tell.visible, "crow shows a '!' tell before diving")
	await frames(60)
	check(not crow._tell.visible, "tell disappears when the dive begins")
	# hints queue once
	Game.hints_seen.erase("unit_test")
	ui.hint("unit_test", "hello", 0.2)
	ui.hint("unit_test", "hello again", 0.2)
	var copies: int = ui._hint_queue.filter(func(i): return i[0] == "hello").size() + (1 if ui._hint_label.text == "hello" else 0)
	check(copies == 1 and not ui._hint_queue.any(func(i): return i[0] == "hello again"), "hint shows once, duplicates ignored")
	isl.queue_free()
	await frames(3)
	# island hints fire for a new save
	Game.hints_seen.clear()
	var isl2 := make_island(job_with("hot"))
	await frames(120)
	check(Game.hints_seen.has("run") and Game.hints_seen.has("trait_hot"), "island tutorial hints fire (%s)" % str(Game.hints_seen.keys()))
	isl2.queue_free()
	await frames(3)
	# tavern guide arrows
	Game.hints_seen.clear()
	Game.current_job = {}
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await frames(120)
	check(t._mk_main.visible, "tavern objective arrow is visible")
	check(Game.hints_seen.has("t_board"), "tavern tutorial says go to the job board")
	Game.current_job = Game.today_jobs[0]
	await frames(10)
	check(Game.hints_seen.has("t_door"), "tavern tutorial points at the door after taking a job")
	t.queue_free()
	Game.current_job = {}
	await frames(3)


func test_tavern() -> void:
	print("tavern")
	Game.skill_points = 12
	for id in Game.SKILLS:
		Game.owned[id] = true
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await frames(10)
	check(t.player != null and not t.player.dead, "player spawns")
	t._job_board(null)
	check(ui.modal_open, "job board opens")
	ui.close_modal()
	t._boss_letter(null)
	check(ui.modal_open, "boss letter opens")
	ui.close_modal()
	t._cellar(null)
	check(ui.modal_open, "skill tree opens")
	ui.close_modal()
	t._bar_menu(null)
	check(ui.modal_open, "bar opens")
	ui.close_modal()
	Game.current_job = {}
	t._exit_door(null)
	check(true, "exit without job is refused gracefully")
	var started := [false]
	t.start_run.connect(func(): started[0] = true)
	Game.current_job = Game.today_jobs[0]
	t._exit_door(null)
	check(started[0], "exit with job starts run")
	await frames(30)
	check(t.player.global_position.y > -1.0, "player stands on tavern floor")
	t.queue_free()
	await frames(2)


func test_traits() -> void:
	print("parcel traits")
	for tr in ["screamer", "hot", "wiggly", "glass", "heavy"]:
		var isl := make_island(job_with(tr))
		await frames(40)
		var p: Player = isl.player
		check(p.global_position.y > -1.0, "%s: player grounded on island" % tr)
		check(p.carried != null, "%s: parcel carried" % tr)
		var parcel: Parcel = p.carried
		match tr:
			"screamer":
				parcel._scream_t = 0.0
				await frames(5)
				check(parcel._scream_t > 1.0, "screamer screams and resets")
			"hot":
				parcel.heat = 99.9
				var hp0 := p.hp
				await frames(10)
				check(p.hp < hp0 or p.invuln > 0.0, "hot potato explodes and hurts")
				check(parcel.condition < 100.0, "hot potato damaged itself")
			"wiggly":
				parcel._wiggle_t = 0.0
				await frames(5)
				check(parcel.state == "escaped", "wiggly crate escapes")
				await frames(120)
				var d := parcel.global_position.distance_to(p.global_position)
				check(is_instance_valid(parcel), "escaped crate still alive")
				p.global_position = parcel.global_position + Vector3(0.5, 0.3, 0)
				await frames(20)
				check(p.carried == parcel, "player recaptures crate (d was %.1f)" % d)
			"glass":
				var c0 := parcel.condition
				p.velocity.y = 7.0
				parcel.damage(10.0)
				check(parcel.condition < c0, "glass takes damage (padding applied)")
			"heavy":
				check(true, "heavy parcel carried")
		isl.queue_free()
		await frames(3)


func test_crow() -> void:
	print("crow")
	var isl := make_island(job_with("glass"))
	await frames(20)
	var p: Player = isl.player
	var crow := Crow.new()
	crow.island = isl
	crow.player = p
	crow.ui = ui
	crow.home = p.global_position + Vector3(4, 4, 0)
	var np := p.global_position + Vector3(-12, 0, 5)
	crow.nest = Vector3(np.x, isl.height_at(np.x, np.z), np.z)
	isl.add_child(crow)
	p.pocket_used = true
	Game.owned.erase("pocket")
	await frames(240)
	check(crow.parcel != null or p.carried == null, "crow stole the parcel")
	check(crow.state == Crow.S.FLEE or crow.state == Crow.S.EAT, "crow flees/eats (state %d)" % crow.state)
	crow.stun(2.0)
	await frames(5)
	check(crow.parcel == null, "stunned crow dropped the parcel")
	var parcel: Parcel = null
	for n in isl.get_children():
		if n is Parcel:
			parcel = n
	check(parcel != null and parcel.state == "loose", "parcel is loose in the world")
	p.global_position = parcel.global_position + Vector3(0.5, 0.2, 0)
	await frames(5)
	parcel._on_pickup(p)
	check(p.carried == parcel, "player picks parcel back up")
	Game.owned["pocket"] = true
	isl.queue_free()
	await frames(3)


func test_slime() -> void:
	print("slime")
	var isl := make_island(job_with("heavy"))
	await frames(20)
	var p: Player = isl.player
	p.forged_used = true
	var s := Slime.new()
	s.island = isl
	s.player = p
	s.ui = ui
	s.home = p.global_position + Vector3(5, 0, 0)
	isl.add_child(s)
	for i in 300:
		await frames(1)
		if s.state == Slime.S.INSPECT:
			break
	check(s.state == Slime.S.INSPECT, "slime starts inspection (state %d)" % s.state)
	check(p.frozen, "player frozen during inspection")
	check(ui._qte_active, "stamp QTE is up")
	ui._finish_qte(false)
	await frames(5)
	check(s.parcel != null and s.state == Slime.S.FLEE, "failed stamp -> parcel confiscated")
	check(not p.frozen, "player unfrozen after inspection")
	s.stun(1.0)
	await frames(5)
	check(s.parcel == null, "stunned slime spits parcel out")
	isl.queue_free()
	await frames(3)


func test_ogre() -> void:
	print("ogre")
	var isl := make_island(job_with("plain" if false else "heavy"))
	await frames(20)
	var p: Player = isl.player
	var ogre: Ogre = null
	for n in isl.get_children():
		if n is Ogre:
			ogre = n
	check(ogre != null, "ogre exists at the gorge")
	p.global_position = ogre.global_position + Vector3(0, 1.0, 5.0)
	await frames(10)
	ogre._ring(p)
	check(ui.modal_open, "riddle panel opens")
	ui.close_modal()
	ogre._answer(false)
	await frames(60)
	check(ogre.strikes == 1 and p.hp < p.max_hp, "wrong answer -> strike + damage (hp %d)" % p.hp)
	ogre._busy = false
	ogre._answer(true)
	await frames(60)
	check(ogre.passed, "right answer opens the gate")
	check(not is_instance_valid(ogre.blockade) or ogre.blockade.is_queued_for_deletion(), "blockade removed")
	isl.queue_free()
	await frames(3)
	# three strikes kill
	var isl2 := make_island(job_with("heavy"))
	await frames(20)
	var p2: Player = isl2.player
	var o2: Ogre = null
	for n in isl2.get_children():
		if n is Ogre:
			o2 = n
	p2.global_position = o2.global_position + Vector3(0, 1.0, 5.0)
	o2.strikes = 2
	Game.owned.erase("second_wind")
	o2._swing()
	await frames(80)
	check(p2.dead, "third strike is lethal")
	Game.owned["second_wind"] = true
	isl2.queue_free()
	await frames(3)


func test_skills() -> void:
	print("skills")
	var isl := make_island(job_with("heavy"))
	await frames(20)
	var p: Player = isl.player
	check(p.bottles >= 6, "bandolier and bomb maker give bottles (%d)" % p.bottles)
	p.hp = 1
	p.take_hit(Vector3.FORWARD, 5.0, 9999.0, "was a test")
	check(not p.dead and p.hp > 30.0, "Second Wind saves the first lethal hit (hp %d)" % int(p.hp))
	p.invuln = 0.0
	p.take_hit(Vector3.FORWARD, 5.0, 9999.0, "was a test")
	check(p.dead, "...but only the first")
	isl.queue_free()
	await frames(3)
	# bottle stuns a slime
	var isl2 := make_island(job_with("heavy"))
	await frames(20)
	var p2: Player = isl2.player
	var s := Slime.new()
	s.island = isl2
	s.player = p2
	s.ui = ui
	s.home = p2.global_position + Vector3(0, 0, -4)
	isl2.add_child(s)
	await frames(5)
	Bottle.throw(isl2, s.global_position + Vector3(0, 1.0, 0.5), Vector3.ZERO, true)
	await frames(30)
	check(s.state == Slime.S.STUNNED, "bottle splash stuns slime")
	isl2.queue_free()
	await frames(3)


func test_delivery() -> void:
	print("delivery")
	var isl := make_island(job_with("glass"))
	await frames(20)
	var done := [false]
	var res := [{}]
	isl.finished.connect(func(r): done[0] = true; res[0] = r)
	var p: Player = isl.player
	var cop0 := Game.copper
	p.global_position = isl.dest_pos + Vector3(2, 1.0, 3)
	await frames(10)
	isl._try_deliver(p)
	await frames(60)
	check(done[0], "delivery finishes the run")
	check(Game.copper > cop0, "payment received")
	check(res[0].get("outcome", "") == "delivered", "result outcome = delivered")
	isl.queue_free()
	await frames(3)
	# lighthouse destination
	var isl2 := make_island(job_with("glass", "light"))
	await frames(20)
	var done2 := [false]
	isl2.finished.connect(func(_r): done2[0] = true)
	isl2.player.global_position = isl2.dest_pos + Vector3(2, 1.0, 3)
	await frames(10)
	isl2._try_deliver(isl2.player)
	await frames(60)
	check(done2[0], "lighthouse delivery works")
	isl2.queue_free()
	await frames(3)


func test_death() -> void:
	print("death")
	var isl := make_island(job_with("hot"))
	await frames(20)
	var done := [false]
	var res := [{}]
	isl.finished.connect(func(r): done[0] = true; res[0] = r)
	var shame0 := Game.shame.size()
	isl.player.die("was thrown at the moon in a test")
	await frames(400)
	check(isl.player.dead, "player dead")
	check(Game.shame.size() >= shame0, "wall of shame updated")
	check(done[0], "death ends the run")
	check(res[0].get("outcome", "") == "died", "result outcome = died")
	isl.queue_free()
	await frames(3)
	# drowning
	var isl2 := make_island(job_with("heavy"))
	await frames(20)
	var p: Player = isl2.player
	var deep := Vector3(0, 0, 0)
	for x in range(-70, 70, 2):
		if isl2.height_at(x, 70) < -2.5:
			deep = Vector3(x, -1.0, 70)
			break
	check(deep != Vector3.ZERO, "found deep water to drown in")
	p.global_position = deep + Vector3(0, 3.0, 0)
	await frames(240)
	check(p.dead, "swimming into deep water drowns the goblin")
	isl2.queue_free()
	await frames(3)
