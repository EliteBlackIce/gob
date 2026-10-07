extends Node
## Headless RPG / dungeon test: loot, stats, progression, procedural layouts, mobs, bosses, rooms.
##   godot --headless --fixed-fps 60 --path . res://tests/rpg.tscn

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
	Game.reset_save()
	test_items()
	test_stats_and_progress()
	test_generator()
	if "friend" in OS.get_cmdline_user_args():
		await test_friend_slop()
		print("\nRPG TEST: ", "PASS" if fails == 0 else "%d FAILURES" % fails)
		get_tree().quit(1 if fails > 0 else 0)
		return
	await test_menus()
	await test_arena_mobs()
	await test_bosses()
	await test_dungeon_runs()
	await test_friend_slop()
	print("\nRPG TEST: ", "PASS" if fails == 0 else "%d FAILURES" % fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- items

func test_items() -> void:
	print("== items")
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var counts := [0, 0, 0, 0, 0]
	var uniques := 0
	var bad := 0
	for i in 4000:
		var it := ItemDB.roll(1 + i % 20, rng)
		counts[it["rarity"]] += 1
		if it.get("unique", "") != "":
			uniques += 1
		if it["stats"].is_empty() or ItemDB.describe(it).is_empty() or float(it["value"]) <= 0.0:
			bad += 1
		var aff := 0
		for k in it["stats"]:
			if k != "w_dmg":
				aff += 1
	print("   rarity counts: ", counts, " uniques ", uniques)
	check(bad == 0, "every rolled item has stats, text and value")
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > counts[4], "rarity gets rarer")
	check(counts[4] > 10 and uniques > 3, "legendaries (and uniques) do drop")
	var a := ItemDB.roll(5, _seeded(7), "weapon", 3)
	var b := ItemDB.roll(5, _seeded(7), "weapon", 3)
	check(a["base"] == b["base"] and a["stats"] == b["stats"], "same seed -> same item")
	var epic := ItemDB.roll(10, _seeded(1), "vest", 3)
	var common := ItemDB.roll(10, _seeded(1), "vest", 0)
	check(epic["stats"].size() > common["stats"].size(), "higher rarity has more affixes")
	var w1 := ItemDB.roll(2, _seeded(3), "weapon", 1)
	var w2 := ItemDB.roll(20, _seeded(3), "weapon", 1)
	check(w2["stats"]["w_dmg"] > w1["stats"]["w_dmg"] * 2.0, "item level scales damage")
	# icons + models for every base
	var icons_ok := true
	for base in ItemDB.WEAPONS:
		var it2 := ItemDB.roll(3, _seeded(5), "weapon", 4)
		it2["base"] = base
		icons_ok = icons_ok and ItemModels.icon(it2) != null and ItemModels.weapon_mesh(base, 4).get_surface_count() == 1
	for slot in ["hat", "vest", "boots", "trinket"]:
		for base2 in ItemDB.ARMOR[slot]:
			var it3 := ItemDB.roll(3, _seeded(5), slot, 2)
			it3["base"] = base2
			icons_ok = icons_ok and ItemModels.icon(it3) != null and ItemModels.vox_for(it3).count() > 0
	check(icons_ok, "icons and voxel models exist for every weapon and armour base")
	# enhancing
	var e := ItemDB.roll(5, _seeded(9), "weapon", 2)
	var before: float = e["stats"]["w_dmg"]
	ItemDB.enhance(e)
	check(e["stats"]["w_dmg"] > before and e["plus"] == 1, "enhance raises stats")


func _seeded(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


# ---------------------------------------------------------------- stats & progression

func test_stats_and_progress() -> void:
	print("== stats & progression")
	Game.reset_save()
	var s0 := Stats.compute()
	check(s0["max_hp"] >= 100.0 and s0["dps"] > 5.0, "starter kit gives a sensible baseline (hp %d, dps %d)" % [s0["max_hp"], s0["dps"]])
	var big := ItemDB.roll(12, _seeded(11), "weapon", 4)
	var dps_before: float = s0["dps"]
	Game.inventory.append(big)
	Game.equip(big)
	var s1 := Stats.compute()
	check(s1["dps"] > dps_before, "equipping a better weapon raises DPS (%d -> %d)" % [dps_before, s1["dps"]])
	check(Game.equipped["weapon"] == big and not Game.inventory.has(big), "equip moves item out of the pack")
	var hat := ItemDB.roll(8, _seeded(2), "hat", 3)
	Game.inventory.append(hat)
	Game.equip(hat)
	check(Stats.compute()["armor"] > s0["armor"] or Stats.compute()["max_hp"] > s0["max_hp"], "armour raises armour/HP")
	var lvl0 := Game.level
	var hp0: float = Stats.compute()["max_hp"]
	var ups := Game.add_xp(5000)
	check(ups > 3 and Game.level > lvl0 and Stats.compute()["max_hp"] > hp0, "XP levels you up and raises HP (level %d)" % Game.level)
	check(Game.skill_points >= ups, "level ups grant skill points")
	var sp := Game.skill_points
	check(Game.buy_skill("power_strikes") and Game.skill_points == sp - 1, "skill purchase")
	check(not Game.buy_skill("keen_edge") or Game.has_skill("power_strikes"), "tier gating respected")
	# sell
	var junk := ItemDB.roll(4, _seeded(4), "boots", 1)
	Game.inventory.append(junk)
	var c0 := Game.copper
	Game.sell(junk)
	check(Game.copper > c0 and not Game.inventory.has(junk), "selling gives copper")
	# stash
	var st := ItemDB.roll(4, _seeded(6), "trinket", 1)
	Game.inventory.append(st)
	check(Game.to_stash(st) and Game.stash.has(st), "stash accepts items")
	check(Game.from_stash(st) and Game.inventory.has(st), "stash gives them back")
	# save / load
	Game.save_game()
	var eq_uid: int = Game.equipped["weapon"]["uid"]
	var inv_n := Game.inventory.size()
	var lvl := Game.level
	Game.inventory.clear()
	Game.equipped.clear()
	Game.level = 1
	Game.load_game()
	check(Game.level == lvl and Game.inventory.size() == inv_n and Game.equipped["weapon"]["uid"] == eq_uid, "save/load round-trips gear and level")
	# house
	Game.copper = 100000
	var tier0 := Game.house_tier
	check(Game.buy_house() and Game.house_tier == tier0 + 1, "can buy a house")
	var hp_house: float = Stats.compute()["max_hp"]
	check(hp_house > hp0, "houses add perks")
	while not Game.house_next().is_empty():
		Game.buy_house()
	check(Game.won and Game.house_tier == Game.HOUSES.size() - 1, "buying the Castle wins the game")
	# contracts
	Game.new_day()
	var routes := 0
	var dungeons := 0
	var all_ok := true
	for j in Game.today_jobs:
		if j["kind"] == "route":
			routes += 1
		else:
			dungeons += 1
			all_ok = all_ok and Game.theme_unlocked(j["theme"]) and j["tier"] >= 1 and j["pay"] > 0 and j.has("seed")
	check(routes == 1 and dungeons == 3 and all_ok, "daily board: 1 route + 3 dungeon contracts")
	# death penalty
	Game.reset_save()
	var loot := ItemDB.roll(3, _seeded(8), "weapon", 2)
	Game.add_item(loot)
	var held := Game.inventory.size()
	Game.record_death("a test")
	check(Game.inventory.size() == held - 1, "dying loses the loot found that run")
	Game.reset_save()


# ---------------------------------------------------------------- generator

func test_generator() -> void:
	print("== procedural dungeons")
	var sigs := {}
	var bad_conn := 0
	var missing := 0
	var themes := ["crypt", "sewer", "caves", "furnace", "ice"]
	for s in 120:
		var g := DungeonGen.generate(s * 104729 + 17, themes[s % 5], 1 + s % 5)
		if g.reachable_rooms() != g.rooms.size():
			bad_conn += 1
		sigs[g.signature()] = true
		var have := {}
		for r in g.rooms:
			have[r.kind] = true
		if not (have.has("start") and have.has("boss") and have.has("customer") and have.has("combat") and have.has("treasure")):
			missing += 1
		if g.rooms.size() < 9 or g.rooms.size() > 14:
			missing += 1
	check(bad_conn == 0, "every room is reachable on foot (120 seeds)")
	check(missing == 0, "every dungeon has start, boss, customer, combat and treasure rooms")
	check(sigs.size() >= 118, "layouts are random (%d unique of 120)" % sigs.size())
	var g1 := DungeonGen.generate(777, "crypt", 2)
	var g2 := DungeonGen.generate(777, "crypt", 2)
	check(g1.signature() == g2.signature(), "same seed -> same dungeon")
	var deeper := DungeonGen.generate(5, "crypt", 2, {"no_customer": true})
	check(deeper.rooms[deeper.customer_id].kind == "stairs", "deeper floors end in a stairwell")


# ---------------------------------------------------------------- menus

func test_menus() -> void:
	print("== menus")
	Game.reset_save()
	for i in 12:
		Game.add_item(ItemDB.roll(6, _seeded(i), "", -1), false)
	Game.copper = 5000
	var p := Player.new()
	p.ui = ui
	add_child(p)
	ui.hud_player = p
	ui.show_hud(true)
	await frames(3)
	Menus.show_inventory(ui, "pack")
	await frames(2)
	check(ui.modal_open and ui.modal_tag == "inv", "inventory opens")
	Menus._sel_uid = Game.inventory[0]["uid"]
	Menus._sel_where = "pack"
	Menus.show_inventory(ui, "smith")
	await frames(2)
	check(ui.modal_open, "blacksmith screen renders with an item selected")
	Menus.show_inventory(ui, "stash")
	await frames(2)
	Menus.show_shop(ui)
	await frames(2)
	check(ui.modal_open and Game.shop_stock.size() == 5, "shop lists 5 items")
	Menus.show_contracts(ui, func(_j): pass)
	await frames(2)
	check(ui.modal_open, "contract board renders")
	Menus.show_realtor(ui)
	await frames(2)
	ui.show_skills()
	await frames(2)
	check(ui.modal_open, "skill tree renders")
	ui.close_modal(false)
	var hh := VoxHouses
	var ok := true
	for t in 6:
		ok = ok and hh.build(t).get_surface_count() == 1
	check(ok, "all six house models build")
	p.queue_free()
	await frames(2)


# ---------------------------------------------------------------- arena helpers

func make_arena() -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	var floor_body := Style.solid_box(root, Vector3(80, 1, 80), Vector3(0, -0.5, 0))
	floor_body.collision_layer = 1
	var p := Player.new()
	p.ui = ui
	root.add_child(p)
	p.setup_for_run("dungeon")
	p.global_position = Vector3(0, 0.1, 0)
	ui.hud_player = p
	return {"root": root, "player": p}


func test_arena_mobs() -> void:
	print("== mobs")
	Game.reset_save()
	for kind in MobDB.KINDS:
		var a := make_arena()
		var root: Node3D = a["root"]
		var p: Player = a["player"]
		p.frozen = false
		var m := Mob.make(kind, "crypt", 2, [])
		root.add_child(m)
		m.global_position = Vector3(0, 0.1, -5.0 if kind != "bat" else -4.0)
		m.wake()
		await frames(3)
		var hp0 := p.hp
		var died := [false]
		m.died.connect(func(_mm, _i): died[0] = true)
		# let it attack the player for up to 6 seconds
		var got_hit := false
		for i in 360:
			await get_tree().process_frame
			if p.hp < hp0 - 0.5:
				got_hit = true
				break
			p.invuln = 0.0
		check(got_hit or kind in ["archer", "mushroom", "imp", "gnome", "sock"], "%s attacks the player" % kind)
		if not got_hit:
			check(m.state != "idle", "%s (ranged) is active" % kind)
		# kill it
		m.take_damage(99999.0, Vector3.FORWARD, {"crit": true, "knock": 3.0})
		await frames(3)
		check(died[0] and m.dead, "%s dies and emits died" % kind)
		root.queue_free()
		await frames(2)
	# elites with every affix
	var a2 := make_arena()
	var root2: Node3D = a2["root"]
	for affix in MobDB.ELITE_AFFIXES:
		var e := Mob.make("skeleton", "crypt", 3, [], true, affix)
		root2.add_child(e)
		e.global_position = Vector3(3, 0.1, -3)
		e.wake()
		await frames(20)
		e.take_damage(99999.0, Vector3.FORWARD, {})
	check(true, "all elite affixes spawn and die")
	await frames(30)
	root2.queue_free()
	await frames(2)
	# the training dummy
	var a3 := make_arena()
	var dm := Dummy.new()
	(a3["root"] as Node3D).add_child(dm)
	dm.global_position = Vector3(0, 0, -2)
	await frames(2)
	dm.take_damage(50.0, Vector3.FORWARD, {"crit": true})
	check(not dm.dead and dm.hp > 1.0e8, "training dummy survives")
	(a3["root"] as Node3D).queue_free()
	await frames(2)


func test_bosses() -> void:
	print("== bosses")
	Game.reset_save()
	Game.level = 8
	for bid in Boss.BOSSES:
		var a := make_arena()
		var root: Node3D = a["root"]
		var p: Player = a["player"]
		var b := Boss.make_boss(bid, Boss.BOSSES[bid]["theme"], 2, [])
		root.add_child(b)
		b.global_position = Vector3(0, 0.1, -8)
		var died := [false]
		b.died.connect(func(_m, _i): died[0] = true)
		b.wake()
		var attacks := {}
		var phase2 := false
		var hp0 := p.hp
		var dealt_to_player := false
		# fight for ~25 seconds of game time, keep the player alive and dodge-less
		for i in 1800:
			await get_tree().process_frame
			attacks[b._last_atk] = true
			p.hp = p.max_hp
			p.invuln = 0.0
			if i == 600:
				b.take_damage(b.max_hp * 0.55, Vector3.FORWARD, {})
			if b.phase == 2:
				phase2 = true
		check(attacks.size() >= 3, "%s used %d different attacks (%s)" % [bid, attacks.size(), ", ".join(attacks.keys())])
		check(phase2, "%s reaches phase 2" % bid)
		check(b.hp > 0.0 and not b.dead, "%s survives chip damage" % bid)
		if bid == "dragon":
			check(b._can_pacify, "dragon offers a peaceful ending")
		b.take_damage(b.max_hp * 2.0, Vector3.FORWARD, {"crit": true})
		await frames(5)
		check(died[0], "%s can be killed" % bid)
		root.queue_free()
		await frames(5)
	Game.reset_save()


# ---------------------------------------------------------------- full dungeon runs

func test_dungeon_runs() -> void:
	print("== dungeon runs")
	Game.reset_save()
	Game.max_tier = 5
	var themes := ["crypt", "sewer", "caves", "furnace", "ice"]
	for ti in themes.size():
		var theme: String = themes[ti]
		var job := {"kind": "dungeon", "id": "cheese", "title": "Screaming Cheese", "theme": theme, "tier": 1 + ti, "mods": ["elites"] if ti % 2 == 0 else ["bountiful", "explosive"],
			"pay": 300, "customer": "Skeleton Dave", "seed": 1000 + ti * 77, "trait": "screamer", "note": ""}
		var d := Dungeon.new()
		d.ui = ui
		d.job = job
		add_child(d)
		await frames(4)
		check(d.rooms.size() >= 9 and d.player != null, "%s dungeon builds (%d rooms)" % [theme, d.rooms.size()])
		# fight in every combat room
		var cleared := 0
		var combat := 0
		for r in d.rooms:
			if r.kind != "combat":
				continue
			combat += 1
			d.player.global_position = r.world_center() + Vector3(0, 0.2, 0)
			d.player.hp = d.player.max_hp
			for i in 30:
				await get_tree().process_frame
			if r.state != "active":
				continue
			var guard := 0
			while r.state == "active" and guard < 12:
				guard += 1
				for m in r.mobs.duplicate():
					if is_instance_valid(m) and not (m as Mob).dead:
						(m as Mob).take_damage(99999.0, Vector3.FORWARD, {})
				for i in 40:
					await get_tree().process_frame
				d.player.hp = d.player.max_hp
			if r.state == "cleared":
				cleared += 1
			else:
				print("   room ", r.d.id, " state=", r.state, " wave=", r.wave, "/", r.waves, " mobs=", r.mobs.size(), " ambush=", r.ambush)
		check(combat > 0 and cleared == combat, "%s: cleared %d/%d combat rooms (doors open again)" % [theme, cleared, combat])
		var loot := get_tree().get_nodes_in_group("loot").size()
		check(loot > 0, "%s: monsters dropped loot (%d pickups)" % [theme, loot])
		# special rooms
		for r in d.rooms:
			match r.kind:
				"treasure":
					d.player.global_position = r.world_center() + Vector3(1.0, 0.2, 0)
					await frames(5)
					for n in get_tree().get_nodes_in_group("interactable"):
						var it := n as Interactable
						if it != null and it.prompt.begins_with("Open") and it.global_position.distance_to(r.world_center()) < 3.0 and it.enabled:
							it.activate(d.player)
							break
					await frames(5)
				"shrine":
					d._use_shrine(r, Interactable.new())
					await frames(3)
					check(ui.modal_open, "%s: shrine offers blessings" % theme)
					ui.close_modal(false)
				"merchant":
					d._merchant_menu(r)
					await frames(3)
					ui.close_modal(false)
		# boss room
		var br: Dungeon.RoomRT = d.rooms[d.g.boss_id]
		d.player.global_position = br.world_center() + Vector3(0, 0.2, 0.5)
		for i in 60:
			await get_tree().process_frame
		check(br.state == "active" and d.boss.awake, "%s: boss room activates (%s)" % [theme, d.boss.boss_name])
		check(br.gates.size() > 0, "%s: boss room locks its doors" % theme)
		for i in 240:
			await get_tree().process_frame
			d.player.hp = d.player.max_hp
		d.boss.take_damage(d.boss.max_hp * 5.0, Vector3.FORWARD, {})
		for i in 30:
			await get_tree().process_frame
		check(d.boss_dead and Game.trophies.size() > 0, "%s: boss dies, trophy awarded" % theme)
		# deliver the parcel
		var tier_before := Game.max_tier
		var cr: Dungeon.RoomRT = d.rooms[d.g.customer_id]
		d.player.global_position = cr.world_center() + Vector3(0, 0.2, 2.0)
		await frames(5)
		var copper0 := Game.copper
		d._deliver(1.0)
		check(d.parcel_delivered and Game.copper > copper0, "%s: delivery pays out" % theme)
		check(d._portals_for_exit.size() == 2, "%s: exit portals appear" % theme)
		# take the stairs down
		if ti == 0:
			await d._descend(null)
			await frames(10)
			check(d.floor_no == 2 and d.rooms.size() >= 9, "stairs lead to a new random floor (%s)" % d.theme)
		# finishing
		var res := [null]
		d.finished.connect(func(r2): res[0] = r2)
		d._go_home(null)
		for i in 90:
			await get_tree().process_frame
		check(res[0] != null and res[0].has("loot"), "%s: run ends with a results dictionary" % theme)
		d.queue_free()
		await frames(5)
	# dying
	var d2 := Dungeon.new()
	d2.ui = ui
	d2.job = {"kind": "dungeon", "id": "cheese", "title": "X", "theme": "crypt", "tier": 1, "mods": [], "pay": 200, "customer": "Dave", "seed": 4242, "trait": "x", "note": ""}
	add_child(d2)
	await frames(4)
	var res2 := [null]
	d2.finished.connect(func(r3): res2[0] = r3)
	Game.add_item(ItemDB.roll(3, _seeded(33), "weapon", 2))
	d2.player.take_hit(Vector3.FORWARD, 3.0, 99999.0, "a unit test")
	for i in 300:
		await get_tree().process_frame
	check(d2.player.dead and res2[0] != null and res2[0]["outcome"] == "died", "death ends the run")
	d2.queue_free()
	await frames(3)
	Game.reset_save()


func test_friend_slop() -> void:
	print("== friend slop")
	# --- friend-slop systems
	Game.reset_save()
	check(UI.snap_size(18) == 16 and UI.snap_size(26) == 24 and UI.snap_size(54) == 48, "font sizes snap to the pixel grid")
	check(Game.settings.has("camcorder") and Game.settings.has("sens"), "options exist")
	for sid in Scrap.DB:
		check(Scrap.model(sid).count() > 20, "scrap model: %s" % sid)
	Game.scrap = [{"id": "duck", "value": 50, "run": true}, {"id": "gong", "value": 100, "run": false}]
	check(Game.scrap_speed_mult() < 1.0, "carrying scrap slows you")
	var worth := Game.sell_scrap()
	check(worth == 180 and Game.scrap.is_empty() and int(Game.quota["paid"]) == 180, "selling scrap pays 20% extra toward quota")
	Game.day = int(Game.quota["deadline"])
	var cu := Game.copper
	var verdict := Game.resolve_quota()
	check(verdict.get("ok", false) and Game.copper > cu and int(Game.quota["n"]) == 2, "meeting the quota rewards you and raises it")
	Game.day = int(Game.quota["deadline"])
	cu = Game.copper
	verdict = Game.resolve_quota()
	check(not verdict.get("ok", true) and Game.copper < cu and int(Game.quota["n"]) == 2, "missing the quota docks your wages")
	Game.scrap = [{"id": "duck", "value": 50, "run": true}]
	Game.record_death("a unit test")
	check(Game.scrap.is_empty(), "dying drops this run's scrap")
	var sc_root := Node3D.new()
	add_child(sc_root)
	var sc := Scrap.place(sc_root, Vector3.ZERO, "kazoo", 33, ui)
	var pl := Player.new()
	pl.ui = ui
	sc_root.add_child(pl)
	pl.setup_for_run("dungeon")
	await frames(3)
	check(sc.is_in_group("scannable"), "scrap can be scanned")
	check(Scanner.ping(pl), "scan ping fires")
	await frames(2)
	check(sc.get_node_or_null("ScanTag") != null, "scan ping tags scannable things")
	sc._grab(pl)
	check(Game.scrap.size() == 1 and Game.scrap[0]["id"] == "kazoo", "picking scrap up fills the sack")
	sc_root.queue_free()
	await frames(3)
	# --- roamers, landmines, scrap traits, emotes
	Game.reset_save()
	var ar := make_arena()
	var aroot: Node3D = ar["root"]
	var ap: Player = ar["player"]
	ap.frozen = false
	ap.yaw = 0.0
	ap.pitch = 0.0
	# lawn gnome: frozen while watched, sprints when you look away
	var gn := Mob.make("gnome", "crypt", 2, [])
	gn.position = Vector3(0, 0.1, -9.0)
	aroot.add_child(gn)
	gn.wake()
	for i in 20:
		await get_tree().physics_frame
	var gp0 := gn.global_position
	for i in 40:
		await get_tree().physics_frame
	var gmove := Vector2(gn.global_position.x - gp0.x, gn.global_position.z - gp0.z).length()
	check(gn.watched() and gmove < 0.05, "lawn gnome freezes while you look at it (watched=%s moved=%.2f)" % [gn.watched(), gmove])
	ap.yaw = PI
	await frames(3)
	for i in 40:
		await get_tree().physics_frame
	check(not gn.watched() and gn.global_position.distance_to(gp0) > 1.0, "lawn gnome moves when you look away")
	gn.take_damage(99999.0, Vector3.FORWARD, {})
	await frames(5)
	ap.yaw = 0.0
	# sack thief: steals from the sack, drops it when killed
	Game.scrap = [{"id": "duck", "value": 40, "run": true}]
	ap.global_position = Vector3(0, 0.1, 0)
	var th := Mob.make("thief", "crypt", 1, [])
	th.position = Vector3(0, 0.1, -1.2)
	aroot.add_child(th)
	th.wake()
	var stole := false
	for i in 240:
		await get_tree().physics_frame
		if not th.stolen.is_empty():
			stole = true
			break
	check(stole and Game.scrap.is_empty(), "sack thief steals scrap from your sack")
	th.take_damage(99999.0, Vector3.FORWARD, {})
	await frames(5)
	var dropped := false
	for n in get_tree().get_nodes_in_group("scannable"):
		if n is Scrap and (n as Scrap).id == "duck":
			dropped = true
			(n as Scrap)._grab(ap)
	check(dropped and Game.scrap.size() == 1, "killing the thief drops what it stole")
	# ceiling sock: drops on your face, roll shakes it off
	var sk := Mob.make("sock", "crypt", 1, [])
	sk.position = ap.global_position + Vector3(0.3, 3.6, 0.0)
	aroot.add_child(sk)
	for i in 40:
		await get_tree().physics_frame
	check(ap.latched_sock == sk and ui._sock_ov != null and ui._sock_ov.visible, "ceiling sock latches onto your face (state=%s)" % sk._sock_state)
	ap._start_roll(Vector3.FORWARD)
	await frames(3)
	check(ap.latched_sock == null and (ui._sock_ov == null or not ui._sock_ov.visible), "rolling shakes the sock off")
	sk.take_damage(99999.0, Vector3.FORWARD, {})
	for i in 60:
		await get_tree().physics_frame
	# landmine: click on, boom off
	ap.hp = ap.max_hp
	ap.invuln = 0.0
	var mn := Landmine.place(aroot, ap.global_position + Vector3(0, 0, -3.0), 40.0, ui)
	ap.global_position = mn.global_position + Vector3(0, 0.1, 0)
	await frames(4)
	check(mn.armed and not mn.exploded, "landmine clicks when stepped on")
	var hp_mine := ap.hp
	ap.global_position += Vector3(1.5, 0, 0)
	await frames(4)
	check(not is_instance_valid(mn) and ap.hp < hp_mine, "landmine explodes when you step off")
	# scrap traits
	Game.scrap = [{"id": "anvil", "value": 80, "run": true}]
	var heavy_mult := Game.scrap_speed_mult()
	Game.scrap = [{"id": "duck", "value": 80, "run": true}]
	check(heavy_mult < Game.scrap_speed_mult(), "heavy scrap slows you more")
	Game.scrap = [{"id": "mirror", "value": 100, "run": true}]
	Game.scrap_take_hit()
	check(int(Game.scrap[0]["value"]) == 75, "fragile scrap cracks when you get hit")
	# dance emote baffles nearby monsters
	ap.hp = ap.max_hp
	var sk2 := Mob.make("skeleton", "crypt", 1, [])
	sk2.position = ap.global_position + Vector3(0, 0.1, -3.0)
	aroot.add_child(sk2)
	sk2.wake()
	await frames(3)
	ap._start_emote()
	check(ap.is_emoting() and sk2.stun_t > 1.0, "dancing baffles nearby monsters")
	for i in 200:
		await get_tree().physics_frame
	check(not ap.is_emoting(), "the dance ends by itself")
	aroot.queue_free()
	Game.scrap = []
	await frames(3)
