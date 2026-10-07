extends Node
## Visual checks for the RPG overhaul.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/dshot.tscn -- out scenario [arg]
## Scenarios: mobs, bosses, combat, items, ui

var out := "/tmp/dshot"
var ui: UI


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "/tmp/dshot"
	var scenario: String = args[1] if args.size() > 1 else "mobs"
	var extra: String = args[2] if args.size() > 2 else ""
	ui = UI.new()
	add_child(ui)
	ui._fade.color.a = 0.0
	await _frames(3)
	match scenario:
		"mobs":
			await mobs(extra if extra != "" else "crypt")
		"bosses":
			await bosses()
		"combat":
			await combat(extra if extra != "" else "crypt")
		"items":
			await items()
		"ui":
			await ui_shots()
		"tavern":
			await tavern_shots()
		"menus":
			await menu_shots()
		"friend":
			await friend_shots()
		"roamers":
			await roamer_shots()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, name])
	print("saved ", name)


func _stage(theme: String) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	Atmos.dungeon(root, theme)
	var v := Vox.new(0.5)
	for x in range(-30, 30):
		for z in range(-30, 10):
			v.cells[Vector3i(x, -1, z)] = Color("#5a5864") * (0.9 + Vox.hash3(x, 1, z) * 0.2)
	var fl := MeshInstance3D.new()
	fl.mesh = v.build(Vector3.ZERO)
	fl.material_override = VMat.solid(0.5, 8.0)
	root.add_child(fl)
	var l := OmniLight3D.new()
	l.light_energy = 3.0
	l.omni_range = 40.0
	l.position = Vector3(0, 8, -3)
	root.add_child(l)
	return root


func mobs(theme: String) -> void:
	var root := _stage(theme)
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	var kinds := MobDB.KINDS.keys()
	var groups := 3
	var per := int(ceil(float(kinds.size()) / groups))
	for gi in groups:
		var models: Array = []
		for i in per:
			var idx := gi * per + i
			if idx >= kinds.size():
				break
			var kind: String = kinds[idx]
			var m := MobModels.build(kind, theme)
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = VMat.solid(MobModels.S, 4.0) if kind != "ghost" else VMat.glass(MobModels.S, 0.55)
			m.position = Vector3((i - (per - 1) * 0.5) * 1.55, 0, -3.0)
			root.add_child(m)
			models.append(m)
		cam.position = Vector3(0, 1.5, 0.6)
		cam.look_at(Vector3(0, 0.85, -3.0), Vector3.UP)
		for t in 12:
			for m in models:
				MobModels.animate(m, t * 0.1, 0.0, "idle", 0.0)
			await get_tree().process_frame
		await _snap("g%d_idle" % gi)
		for m in models:
			MobModels.animate(m, 1.0, 0.0, "windup", 1.0)
		await _snap("g%d_windup" % gi)
		for m in models:
			m.queue_free()
		await _frames(2)


func bosses() -> void:
	var ids := Boss.BOSSES.keys()
	for bid in ids:
		var theme: String = Boss.BOSSES[bid]["theme"]
		var root := _stage(theme)
		var cam := Camera3D.new()
		cam.fov = 60.0
		root.add_child(cam)
		cam.current = true
		var m := BossModels.build(bid, theme)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = VMat.solid(BossModels.S if bid == "dragon" else MobModels.S, 4.0)
		root.add_child(m)
		m.position = Vector3(0, 0, -4)
		cam.position = Vector3(5.5, 3.2, 4.0)
		cam.look_at(Vector3(0, 1.8, -4.0), Vector3.UP)
		for t in 10:
			if bid == "dragon":
				BossModels.animate_dragon(m, t * 0.1, "idle", 0.0, 0.0)
			else:
				MobModels.animate(m, t * 0.1, 0.0, "idle", 0.0)
			await get_tree().process_frame
		await _snap("boss_" + bid)
		root.queue_free()
		await _frames(2)


func items() -> void:
	# a grid of weapons at each rarity, in the first-person viewmodel style
	var root := _stage("crypt")
	var cam := Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	cam.current = true
	var bases := ItemDB.WEAPONS.keys()
	for r in 5:
		for i in bases.size():
			var mi := MeshInstance3D.new()
			mi.mesh = ItemModels.weapon_mesh(bases[i], r)
			mi.material_override = VMat.solid(ItemModels.S, 8.0)
			mi.position = Vector3(-3.6 + i * 1.2, 0.4, -r * 1.5)
			mi.rotation_degrees = Vector3(0, 25, 35)
			root.add_child(mi)
	cam.position = Vector3(0, 4.5, 4.5)
	cam.look_at(Vector3(0, 0.5, -3.0), Vector3.UP)
	await _snap("weapons")


func combat(theme: String) -> void:
	Game.reset_save()
	Game.max_tier = 5
	var big := ItemDB.roll(8, _rng(3), "weapon", 3)
	big["base"] = "cleaver"
	Game.inventory.append(big)
	Game.equip(big)
	var d := Dungeon.new()
	d.ui = ui
	d.job = {"kind": "dungeon", "id": "cheese", "title": "Screaming Cheese", "theme": theme, "tier": 2, "mods": [], "pay": 300, "customer": "Skeleton Dave", "seed": 4242, "trait": "screamer", "note": ""}
	add_child(d)
	await _frames(6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _snap("start")
	# a combat room
	var room: Dungeon.RoomRT = null
	for r in d.rooms:
		if r.kind == "combat":
			room = r
			break
	var p := d.player
	p.invuln = 9999.0
	p.global_position = room.world_center() + Vector3(0, 0.2, 5.0)
	p.yaw = 0.0
	await _frames(70)
	await _snap("wave")
	# shove a few mobs right in front of the player and swing
	for m in room.mobs:
		if is_instance_valid(m) and not (m as Mob).dead:
			(m as Mob).global_position = p.global_position + Vector3(randf_range(-1.2, 1.2), 0.1, -2.2 - randf() * 2.0)
	await _frames(6)
	p.combo = 0
	p._try_attack()
	for i in 14:
		await get_tree().process_frame
	p.invuln = 9999.0
	await _snap("swing_a")
	for i in 8:
		await get_tree().process_frame
	await _snap("swing_b")
	await _frames(40)
	p._atk_t = -1.0
	p._atk_cd = 0.0
	p._try_attack()
	for i in 12:
		await get_tree().process_frame
	await _snap("swing_c")
	# block
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("block")
	await _frames(14)
	await _snap("block")
	Input.action_release("block")
	# kill everything, show loot
	for m in room.mobs.duplicate():
		if is_instance_valid(m):
			(m as Mob).take_damage(99999.0, Vector3.FORWARD, {"crit": true})
	await _frames(8)
	await _snap("kills")
	for i in 3:
		d._drop_item(p.global_position + Vector3(0, 0.5, -3 + i * 0.5), "", 1.5, true)
	d._drop_item(p.global_position + Vector3(2, 0.5, -3), "", 3.0, true)
	await _frames(40)
	await _snap("loot")
	# boss room
	var br: Dungeon.RoomRT = d.rooms[d.g.boss_id]
	p.global_position = br.world_center() + Vector3(0, 0.2, 7.5)
	p.yaw = PI
	await _frames(90)
	await _snap("boss")


func ui_shots() -> void:
	Game.reset_save()
	Game.level = 7
	Game.xp = 120
	Game.copper = 1520
	var rng := _rng(7)
	for i in 14:
		Game.add_item(ItemDB.roll(7, rng), false)
	var leg := ItemDB.roll(9, rng, "weapon", 4)
	Game.add_item(leg, false)
	Game.equip(leg)
	for slot in ["hat", "vest", "boots", "trinket"]:
		var it := ItemDB.roll(7, rng, slot, 3)
		Game.add_item(it, false)
		Game.equip(it)
	var p := Player.new()
	p.ui = ui
	add_child(p)
	p.setup_for_run("dungeon")
	ui.hud_player = p
	ui.configure_hud("dungeon")
	ui.show_hud(true)
	ui.combat.player = p
	await _frames(5)
	p.hp = 70.0
	await _snap("hud")
	Menus._sel_uid = leg["uid"]
	Menus._sel_where = "pack"
	Menus.show_inventory(ui, "pack")
	await _snap("inventory")
	Menus.show_inventory(ui, "smith")
	await _snap("smith")
	Menus.show_shop(ui)
	await _snap("shop")
	Game.new_day()
	Menus.show_contracts(ui, func(_j): pass)
	await _snap("contracts")
	Menus.show_realtor(ui)
	await _snap("realtor")
	ui.show_skills()
	await _snap("skills")
	ui.show_title(func(): pass, func(): pass)
	await _snap("title")


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func tavern_shots() -> void:
	Game.reset_save()
	Game.trophies = ["auditor", "dragon"]
	Game.house_tier = 2
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await _frames(10)
	var p := t.player
	var views := [
		["door", Vector3(0.0, 0.1, 2.5), 180.0],
		["wide", Vector3(0.0, 0.1, 6.0), 0.0],
		["west", Vector3(4.0, 0.1, 1.0), 90.0],
		["fire", Vector3(2.5, 0.1, -3.5), -90.0],
		["south", Vector3(0.0, 0.1, -1.5), 180.0],
		["north", Vector3(-1.0, 0.1, 3.0), 0.0],
		["smith", Vector3(5.5, 0.1, 4.0), 90.0 - 0.0],
		["dummy", Vector3(3.0, 0.1, 3.0), -60.0],
		["realtor", Vector3(-3.5, 0.1, 1.0), 90.0],
		["trophies", Vector3(-4.0, 0.1, 3.5), 180.0],
		["stash", Vector3(4.5, 0.1, 0.5), -90.0],
		["bar", Vector3(1.0, 0.1, 1.0), 20.0],
	]
	for v in views:
		p.global_position = v[1]
		p.yaw = deg_to_rad(float(v[2]))
		p.pitch = -0.05
		await _frames(8)
		await _snap("tav_" + str(v[0]))


func menu_shots() -> void:
	Game.reset_save()
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await _frames(10)
	t.player.yaw = 0.9
	ui.show_title(func(): pass, func(): pass)
	await _snap("title")
	ui.show_options(func(): pass)
	await _snap("options")
	ui.close_modal(false)
	ui.show_hud(true)
	ui.capture_wanted = true
	ui.show_pause(func(): pass, func(): pass)
	await _snap("pause")
	ui.close_modal(false)
	ui.show_letter("WELCOME, NEW GOBLIN", "Congratulations on your employment.\n\nThe tavern is the post office. Pick a contract, walk out the front door, kill whatever's in the way.", "Oh no")
	await _snap("letter")


func friend_shots() -> void:
	Game.reset_save()
	Game.scrap = [{"id": "duck", "value": 31, "run": false}, {"id": "gong", "value": 66, "run": false}]
	var root := _stage("crypt")
	var cam := Camera3D.new()
	cam.fov = 55.0
	root.add_child(cam)
	cam.current = true
	var ids := Scrap.DB.keys()
	var rng := RandomNumberGenerator.new()
	for i in ids.size():
		var sc := Scrap.place(root, Vector3((i - (ids.size() - 1) * 0.5) * 0.8, 0, -3.0), ids[i], Scrap.roll_value(ids[i], 2, rng), ui)
		sc.name = "S%d" % i
	cam.position = Vector3(0, 1.5, 1.2)
	cam.look_at(Vector3(0, 0.3, -3.0), Vector3.UP)
	await _frames(6)
	await _snap("scrap")
	var p := Player.new()
	p.ui = ui
	root.add_child(p)
	p.setup_for_run("dungeon")
	p.global_position = Vector3(0, 0.1, 2.0)
	p.yaw = 0.0
	ui.hud_player = p
	ui.configure_hud("dungeon")
	ui.show_hud(true)
	await _frames(4)
	p.hp = p.max_hp
	p.dead = false
	p.cam.make_current()
	await _frames(2)
	Scanner.ping(p)
	await _frames(10)
	await _snap("scan")
	root.queue_free()
	await _frames(2)
	var cc := Camcorder.new()
	add_child(cc)
	var t := Tavern.new()
	t.ui = ui
	add_child(t)
	await _frames(10)
	t.player.view.visible = false
	t.player.global_position = Vector3(-3.6, 0.1, 3.4)
	t.player.yaw = deg_to_rad(180.0)
	t.player.pitch = -0.05
	await _frames(6)
	await _snap("desk_cam")
	cc.queue_free()
	await _frames(3)
	await _snap("desk")
	t._quota_desk()
	await _snap("desk_menu")


func roamer_shots() -> void:
	Game.reset_save()
	var root := _stage("crypt")
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	var models: Array = []
	var x := -2.4
	for k in ["gnome", "thief", "sock"]:
		var m := MobModels.build(k, "crypt")
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = VMat.solid(MobModels.S, 4.0)
		m.position = Vector3(x, 1.6 if k == "sock" else 0.0, -3.0)
		root.add_child(m)
		models.append(m)
		x += 2.4
	var mine := Landmine.place(root, Vector3(1.2, 0, -1.6), 50.0, ui)
	var ids := ["fish", "anvil", "doll", "bobble", "bphone", "lamp", "plunger", "mirror", "trumpet", "egg", "vase", "clock", "boot"]
	var rng := RandomNumberGenerator.new()
	for i in ids.size():
		Scrap.place(root, Vector3((i - 6) * 0.75, 0, -6.0), ids[i], Scrap.roll_value(ids[i], 1, rng), ui)
	cam.position = Vector3(0, 1.4, 1.6)
	cam.look_at(Vector3(0, 0.7, -3.5), Vector3.UP)
	for t in 10:
		for m in models:
			MobModels.animate(m, t * 0.1, 0.0, "idle", 0.0)
		await get_tree().process_frame
	await _snap("lineup")
	ui.show_hud(true)
	ui.set_sock(true)
	await _snap("sock_face")
	ui.set_sock(false)
	# dance emote, third person
	var p := Player.new()
	p.ui = ui
	root.add_child(p)
	p.setup_for_run("dungeon")
	p.global_position = Vector3(0, 0.1, 0)
	p.hp = p.max_hp
	await _frames(4)
	for k in 3:
		p._start_emote()
		p._emote_kind = k
		for i in 20:
			await get_tree().process_frame
		await _snap("dance_%d" % k)
		p._end_emote()
		p._emote_cd = 0.0
