class_name Dungeon
extends Node3D
## One playable dungeon floor: generates a random layout, builds it, fills every room by role
## (waves, bosses, chests, shrines, campfires, merchants, traps, the customer), and runs the run
## (XP, loot, minimap, doors, results). Floors chain: after delivering you can take the stairs
## deeper for harder floors and better loot, or portal home.

signal finished(result: Dictionary)

const TRAP_DMG := 22.0


class RoomRT extends RefCounted:
	var d: DungeonGen.DRoom
	var kind := ""
	var state := "idle"           # idle -> active -> cleared
	var mobs: Array = []
	var wave := 0
	var waves := 1
	var budget := 5
	var gates: Array = []
	var seen := false
	var markers: Array = []
	var ambush := false
	var stock: Array = []
	var used := false
	var wave_t := 0.0

	func adopt(m: Mob) -> void:
		mobs.append(m)

	func on_mob_hit(_m: Mob) -> void:
		pass

	func world_center() -> Vector3:
		var c := d.center()
		return Vector3(c.x + 0.5, 0.0, c.y + 0.5)


var ui: UI
var job: Dictionary = {}
var player: Player
var g: DungeonGen
var theme := "crypt"
var tier := 1
var floor_no := 1
var mods: Array = []
var seed_value := 0

var rooms: Array[RoomRT] = []
var level_root: Node3D
var content: Node3D
var boss: Boss = null
var parcel_delivered := false
var boss_dead := false
var kills := 0
var loot_found: Array = []
var xp_gained := 0
var copper_start := 0
var elapsed := 0.0
var parcel_title := ""
var customer_name := ""

var _lights: Array = []
var _rng := RandomNumberGenerator.new()
var _map_img: Image
var _map_tex: ImageTexture
var _map_dirty := false
var _reveal_t := 0.0
var _slow_t := 0.0
var _light_t := 0.0
var _hazard_t := 0.0
var _room_t := 0.0
var _traps: Array = []
var _ended := false
var _cur_room: RoomRT = null
var _dark := false
var _luck := 0.0
var _gold_mult := 1.0
var _xp_mult := 1.0
var _chest_mult := 1.0
var _barrel_mult := 1.0
var _elite_bonus := 0.0
var _ghosts := false
var _portals: Array = []
var _portals_for_exit: Array = []
var _motes: Array = []
var _noise_t := 10.0
var _blackout_t := 0.0


func _ready() -> void:
	theme = str(job.get("theme", "crypt"))
	tier = int(job.get("tier", 1))
	mods = job.get("mods", []).duplicate()
	seed_value = int(job.get("seed", randi()))
	customer_name = str(job.get("customer", "A Customer"))
	parcel_title = str(job.get("title", "A Parcel"))
	copper_start = Game.copper
	for m in mods:
		var md: Dictionary = Game.MODIFIERS[m]
		_luck += float(md.get("luck", 0.0))
		_gold_mult *= float(md.get("gold", 1.0))
		_xp_mult *= float(md.get("xp", 1.0))
		_chest_mult *= float(md.get("chests", 1.0))
		_barrel_mult *= float(md.get("barrels", 1.0))
		_elite_bonus += float(md.get("elite", 0.0))
		if md.get("dark", false):
			_dark = true
		if md.get("ghosts", false):
			_ghosts = true
	_luck += float(Game.mandate.get("luck", 0.0))
	Atmos.dungeon(self, theme, _dark)
	player = Player.new()
	player.ui = ui
	add_child(player)
	player.setup_for_run("dungeon")
	player.motes.emitting = false
	_motes = Atmos.dungeon_motes(player.cam, theme)
	player.died.connect(_on_player_died)
	player.killed_mob.connect(func(_m): pass)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffe0b0")
	lamp.light_energy = 0.55 if not _dark else 1.1
	lamp.omni_range = 6.5
	lamp.position = Vector3(0, 1.7, 0)
	player.add_child(lamp)
	Game.run_loot.clear()
	for sc in Game.scrap:
		sc["run"] = false
	var amb := DungeonAmbience.new()
	amb.player = player
	amb.ui = ui
	amb.dungeon = self
	add_child(amb)
	_load_floor()
	ui.configure_hud("dungeon")
	ui.hud_player = player
	ui.combat.dungeon = self
	ui.show_hud(true)
	ui.capture_wanted = true
	Sfx.ambience(false)
	Sfx.set_track("dungeon")
	Sfx.music_volume(-15.0)
	_announce_intro()


func _announce_intro() -> void:
	var th: Dictionary = Game.THEMES[theme]
	var sub := "Tier %d   -   Floor %d" % [tier, floor_no]
	if mods.size() > 0:
		var names: Array[String] = []
		for m in mods:
			names.append(Game.MODIFIERS[m]["name"])
		sub += "   -   " + ", ".join(names)
	ui.announce(str(th["name"]).to_upper(), sub, (th["color"] as Color).lightened(0.3), 2.8)
	if floor_no == 1 and job.has("customer"):
		ui.combat.objective = "Deliver %s to %s" % [parcel_title, customer_name]
	ui.hint("d_move", "Dungeons are random every time. Find the BOSS room, beat it, and deliver the parcel to the customer behind it.", 9.0)
	ui.hint("d_attack", "LEFT CLICK swings your weapon. Hold RIGHT CLICK to block (tap it just before a hit to PARRY). SHIFT rolls through danger.", 11.0)
	ui.hint("d_map", "The minimap in the corner fills in as you explore. Doors lock while a room's monsters are alive.", 9.0)


# ---------------------------------------------------------------- floor generation

func _load_floor() -> void:
	for n in [level_root, content]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	rooms.clear()
	_traps.clear()
	_lights.clear()
	_portals.clear()
	boss = null
	boss_dead = false
	_cur_room = null
	_rng.seed = seed_value
	var deeper := floor_no > 1
	g = DungeonGen.generate(seed_value, theme, tier, {"no_customer": deeper})
	level_root = Node3D.new()
	level_root.name = "Level"
	add_child(level_root)
	var info := DungeonBuilder.build(level_root, g)
	_lights = info["lights"]
	if _dark:
		for l in _lights:
			(l["light"] as Light3D).light_energy *= 0.3
	content = Node3D.new()
	content.name = "Content"
	add_child(content)
	for dr in g.rooms:
		var r := RoomRT.new()
		r.d = dr
		r.kind = dr.kind
		rooms.append(r)
	for r in rooms:
		_make_gates(r)
		_populate(r)
	_spawn_roamers()
	_place_mines()
	_init_map()
	var start := rooms[g.start_id]
	player.global_position = start.world_center() + Vector3(0, 0.3, 0)
	player.velocity = Vector3.ZERO
	var first_door: Dictionary = start.d.doors[0] if start.d.doors.size() > 0 else {"dir": Vector2i(0, -1)}
	var dv: Vector2i = first_door["dir"]
	player.yaw = atan2(-float(dv.x), -float(dv.y))
	player.pitch = 0.0
	_reveal_around(start.world_center(), 12.0)
	_cur_room = start
	start.seen = true
	_map_flush()


# ---------------------------------------------------------------- populating rooms

func _roamer_rooms() -> Array:
	var pool: Array = []
	for r in rooms:
		if r.kind in ["start", "boss", "customer", "stairs"]:
			continue
		pool.append(r)
	return pool


## Lethal-Company-style weirdos that ignore the wave system: ceiling socks, a sack thief, lawn gnomes.
func _spawn_roamers() -> void:
	var pool := _roamer_rooms()
	if pool.is_empty():
		return
	var socks := 1 + _rng.randi_range(0, 2) + (1 if tier >= 3 else 0)
	for i in socks:
		var r: RoomRT = pool[_rng.randi() % pool.size()]
		_spawn_roamer("sock", _tile_pos(_random_tile(r, 1, 0.0)) + Vector3(0, float(MobDB.KINDS["sock"]["hover"]), 0))
	if _rng.randf() < 0.65:
		var r2: RoomRT = pool[_rng.randi() % pool.size()]
		_spawn_roamer("thief", _tile_pos(_random_tile(r2, 1, 0.0)))
	var gnomes := 0
	if tier <= 1:
		gnomes = 1 if _rng.randf() < 0.3 else 0
	else:
		gnomes = 1 + (1 if tier >= 3 and _rng.randf() < 0.5 else 0)
	for i in gnomes:
		var r3: RoomRT = pool[_rng.randi() % pool.size()]
		_spawn_roamer("gnome", _tile_pos(_random_tile(r3, 1, 0.0)))


func _spawn_roamer(kind_id: String, pos: Vector3) -> Mob:
	var m := Mob.make(kind_id, theme, tier, mods, false)
	content.add_child(m)
	m.global_position = pos + Vector3(0, 0.05, 0)
	m.rotation.y = _rng.randf() * TAU
	m.died.connect(_on_mob_died)
	return m


func _place_mines() -> void:
	var pool := _roamer_rooms()
	if pool.is_empty():
		return
	var n := (1 if tier <= 1 else 2) + _rng.randi_range(0, 2)
	for r in rooms:
		if r.kind == "trap":
			n += 2
	var dmg := 55.0 * (1.0 + 0.15 * float(tier - 1))
	for i in n:
		var r: RoomRT = pool[_rng.randi() % pool.size()]
		Landmine.place(content, _tile_pos(_random_tile(r, 1, 2.0)) + Vector3(_rng.randf() - 0.5, 0.0, _rng.randf() - 0.5) * 0.6, dmg, ui)

func _tile_pos(t: Vector2i) -> Vector3:
	return Vector3(t.x + 0.5, 0.0, t.y + 0.5)


func _random_tile(r: RoomRT, margin := 1, avoid_center := 0.0) -> Vector2i:
	var keys: Array = r.d.tiles.keys()
	for tries in 40:
		var t: Vector2i = keys[_rng.randi_range(0, keys.size() - 1)]
		if g.tile(t.x, t.y) != DungeonGen.T_FLOOR:
			continue
		var ok := true
		for dd in range(-margin, margin + 1):
			if not g.is_floor(t.x + dd, t.y) or not g.is_floor(t.x, t.y + dd):
				ok = false
				break
		if not ok:
			continue
		if avoid_center > 0.0 and Vector2(t).distance_to(Vector2(r.d.center())) < avoid_center:
			continue
		var near_door := false
		for door in r.d.doors:
			if Vector2(t).distance_to(Vector2(door["tile"])) < 3.5:
				near_door = true
		if near_door:
			continue
		return t
	return r.d.center()


func _populate(r: RoomRT) -> void:
	match r.kind:
		"start":
			_pop_start(r)
		"combat":
			_pop_combat(r)
		"treasure":
			_pop_treasure(r)
		"shrine":
			_pop_shrine(r)
		"rest":
			_pop_rest(r)
		"merchant":
			_pop_merchant(r)
		"trap":
			_pop_trap(r)
		"boss":
			_pop_boss(r)
		"customer":
			_pop_customer(r)
		"stairs":
			_pop_stairs(r)
	_scatter_scrap(r)


func _scatter_scrap(r: RoomRT) -> void:
	var n := 0
	match r.kind:
		"treasure":
			n = 2 + (1 if _rng.randf() < 0.4 else 0)
		"combat":
			n = 1 if _rng.randf() < 0.6 else 0
		"shrine", "rest", "trap", "merchant":
			n = 1 if _rng.randf() < 0.5 else 0
	for i in n:
		var t := _random_tile(r, 1, 2.0)
		var sid := Scrap.random_id(_rng)
		Scrap.place(content, _tile_pos(t), sid, Scrap.roll_value(sid, tier, _rng), ui)


func _gate_kind(r: RoomRT) -> bool:
	return r.kind in ["combat", "boss"] or r.ambush


func _make_gates(r: RoomRT) -> void:
	if r.kind not in ["combat", "boss", "treasure"]:
		return
	for door in r.d.doors:
		var t: Vector2i = door["tile"]
		var dir: Vector2i = door["dir"]
		var gate := StaticBody3D.new()
		gate.collision_layer = 1
		content.add_child(gate)
		var horizontal := dir.y != 0     # corridor runs along z: gate spans x
		gate.position = Vector3(t.x + 0.5, 0.0, t.y + 0.5)
		gate.rotation.y = 0.0 if horizontal else PI * 0.5
		var mi := MeshInstance3D.new()
		mi.mesh = DProps.gate(theme)
		mi.material_override = VMat.solid(0.25, 4.0)
		gate.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.2, 5.5, 0.5)
		cs.shape = bs
		cs.position = Vector3(0, 2.75, 0)
		gate.add_child(cs)
		cs.disabled = true
		gate.position.y = 6.0
		gate.visible = false
		r.gates.append(gate)


func _set_gates(r: RoomRT, closed: bool) -> void:
	for gate in r.gates:
		var gnode := gate as StaticBody3D
		var cs := gnode.get_child(1) as CollisionShape3D
		if closed:
			gnode.visible = true
			cs.set_deferred("disabled", false)
			var tw := gnode.create_tween()
			tw.tween_property(gnode, "position:y", 0.0, 0.35).set_ease(Tween.EASE_IN)
			tw.tween_callback(func(): Sfx.play("door", -2.0))
		else:
			cs.set_deferred("disabled", true)
			var tw2 := gnode.create_tween()
			tw2.tween_property(gnode, "position:y", 6.0, 0.7)
			tw2.tween_callback(func(): gnode.visible = false)


func _breakables(r: RoomRT, n: int) -> void:
	for i in n:
		var t := _random_tile(r, 1, 3.0)
		var roll: float = _rng.randf()
		var k := "barrel"
		if roll > 0.9 or (_barrel_mult > 1.0 and roll > 0.7):
			k = "keg"
		elif roll > 0.62:
			k = "pot"
		elif roll > 0.4:
			k = "crate"
		var b := Breakable.make(content, k, _tile_pos(t) + Vector3(_rng.randf() - 0.5, 0, _rng.randf() - 0.5) * 0.6, i)
		b.on_break = Callable(self, "_on_break")


func _on_break(b: Breakable) -> void:
	var pos := b.global_position + Vector3(0, 0.4, 0)
	var roll := randf()
	if roll < 0.5:
		_drop_copper(pos, 1 + randi() % 2)
	elif roll < 0.58:
		LootDrop.spawn(content, pos, "orb")
	elif roll < 0.65:
		LootDrop.spawn(content, pos, "bottle", null, 1)
	elif roll < 0.675:
		_drop_item(pos, "", 0.0)
	elif roll < 0.73:
		var sid := Scrap.random_id(_rng)
		Scrap.place(content, Vector3(pos.x, 0.0, pos.z), sid, Scrap.roll_value(sid, tier, _rng), ui)


func _pop_start(r: RoomRT) -> void:
	_breakables(r, 2)
	var c := r.world_center()
	var portal := _make_portal(c + Vector3(0, 0, -4.0), Color("#7ac8ff"), "Leave the dungeon  (abandon this contract)", Callable(self, "_confirm_abandon"))
	r.markers.append({"pos": Vector2(c.x, c.z - 4.0), "col": Color("#7ac8ff")})
	portal.rotation.y = 0.0


func _pop_combat(r: RoomRT) -> void:
	r.budget = 3 + r.d.area() / 55 + tier / 2 + _rng.randi_range(0, 2)
	r.waves = 1 + (1 if (tier >= 3 or r.d.area() > 240) else 0) + (1 if _rng.randf() < 0.25 else 0)
	_breakables(r, 3 + r.d.area() / 50)
	if theme == "furnace" and _rng.randf() < 0.5:
		r.markers.append({"pos": Vector2(r.world_center().x, r.world_center().z), "col": Color("#ff7a30")})


func _pop_treasure(r: RoomRT) -> void:
	var c := r.world_center()
	var weights: Array[float] = [60.0, 28.0 + tier * 2.0, 8.0 + tier * 2.0]
	var roll: float = _rng.randf() * (weights[0] + weights[1] + weights[2])
	var ct := 0
	if roll > weights[0]:
		ct = 1 if roll < weights[0] + weights[1] else 2
	var mimic := _rng.randf() < 0.18
	r.ambush = not mimic and _rng.randf() < 0.3
	var chest := _make_chest(c, ct, mimic, r)
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#ffd24a")})
	_breakables(r, 4)
	if _chest_mult > 1.2 and _rng.randf() < 0.7:
		var t := _random_tile(r, 1, 3.0)
		_make_chest(_tile_pos(t), 0, false, r)


func _make_chest(pos: Vector3, tier_c: int, mimic: bool, r: RoomRT) -> Node3D:
	var chest := Node3D.new()
	Scanner.mark(chest, "Chest", Color("#ffd24a"))
	chest.position = pos
	chest.rotation.y = float(_rng.randi_range(0, 3)) * PI * 0.5
	content.add_child(chest)
	var parts := DProps.chest(tier_c)
	var body := MeshInstance3D.new()
	body.mesh = parts["body"]
	body.material_override = VMat.solid(0.05, 4.0)
	chest.add_child(body)
	var lid := Node3D.new()
	lid.position = Vector3(0, 0.4, -0.25)         # hinge: back edge, top of the body
	chest.add_child(lid)
	var lmi := MeshInstance3D.new()
	lmi.mesh = parts["lid"]
	lmi.material_override = VMat.solid(0.05, 4.0)
	lid.add_child(lmi)
	var col := Style.solid_box(chest, Vector3(0.8, 0.45, 0.55), Vector3(0, 0.22, 0))
	col.collision_layer = 1
	if tier_c >= 1:
		var l := OmniLight3D.new()
		l.light_color = Color("#ffe27a") if tier_c == 2 else Color("#cfe0ff")
		l.light_energy = 0.7
		l.omni_range = 4.0
		l.position = Vector3(0, 0.9, 0)
		chest.add_child(l)
	var prompt := "Open the chest" + (" (gold!)" if tier_c == 2 else (" (silver)" if tier_c == 1 else ""))
	var it := Interactable.make(chest, Vector3(0, 0.5, 0), prompt, Callable(), 2.4)
	var cb := func(_by: Node):
		if not it.enabled:
			return
		it.enabled = false
		Sfx.play("chest")
		if mimic:
			_mimic_reveal(chest, r)
			return
		var tw := lid.create_tween()
		tw.tween_property(lid, "rotation:x", -1.9, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Style.burst(content, chest.global_position + Vector3(0, 0.6, 0), Color("#ffe27a"), 14, 5.0, 0.1, 0.8)
		_chest_loot(chest.global_position + Vector3(0, 0.6, 0), tier_c)
		if r.ambush and r.state == "idle":
			ui.toast("It's an AMBUSH!", Color("#ff9a7a"))
			_activate(r)
	it.callback = cb
	return chest


func _chest_loot(pos: Vector3, tier_c: int) -> void:
	var n := 1 + tier_c + (1 if _rng.randf() < 0.3 else 0) + (1 if Game.has_skill("jackpot") else 0)
	for i in n:
		_drop_item(pos, "", 0.25 * tier_c + 0.15)
	_drop_copper(pos, 3 + tier_c * 3)
	if randf() < 0.5:
		LootDrop.spawn(content, pos, "orb")


func _mimic_reveal(chest: Node3D, r: RoomRT) -> void:
	var pos := chest.global_position
	chest.queue_free()
	ui.announce("IT'S A MIMIC!", "Of course it was.", Color("#ff9a7a"), 1.5)
	Game.moment("OPENED A MIMIC")
	var m := _spawn_mob(r, "mimic", pos, false, true)
	if m != null:
		m.awake = true
		m.wake()
		m.take_damage(0.0, Vector3.ZERO, {"knock": 0.0})


func _pop_shrine(r: RoomRT) -> void:
	var c := r.world_center()
	var col := Color("#c880ff")
	var mi := MeshInstance3D.new()
	mi.mesh = DProps.altar(col)
	mi.material_override = VMat.solid(0.05, 4.0)
	mi.position = c
	content.add_child(mi)
	Scanner.mark(mi, "Shrine", col)
	var l := FlickerLight.new()
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = 9.0
	l.position = c + Vector3(0, 1.6, 0)
	content.add_child(l)
	_lights.append({"light": l, "room": r.d.id, "pos": l.position})
	Style.solid_box(content, Vector3(1.3, 1.0, 1.3), c + Vector3(0, 0.5, 0)).collision_layer = 1
	var it := Interactable.make(content, c + Vector3(0, 1.0, 0), "Pray at the shrine", Callable(), 3.2)
	it.callback = func(_by: Node): _use_shrine(r, it)
	r.markers.append({"pos": Vector2(c.x, c.z), "col": col})
	_breakables(r, 3)


func _use_shrine(r: RoomRT, it: Interactable) -> void:
	if r.used:
		return
	var pool := [
		{"name": "Rage", "desc": "+25% damage this run.", "buff": {"dmg_pct": 25.0}},
		{"name": "Iron Skin", "desc": "+14 armor this run.", "buff": {"armor": 14.0}},
		{"name": "Fleet Foot", "desc": "+18% move speed this run.", "buff": {"move": 18.0}},
		{"name": "Eagle Eye", "desc": "+14% crit chance, +30% crit damage.", "buff": {"crit": 14.0, "crit_dmg": 30.0}},
		{"name": "Vampirism", "desc": "+6% lifesteal. Ew.", "buff": {"lifesteal": 6.0}},
		{"name": "Fortitude", "desc": "+25% max HP (and heals).", "buff": {"hp_pct": 25.0}},
		{"name": "Greed", "desc": "+50% copper from drops.", "buff": {"gold_pct": 50.0}},
		{"name": "Glass Cannon", "desc": "+50% damage but -30% max HP. YOLO.", "buff": {"dmg_pct": 50.0, "hp_pct": -30.0}},
		{"name": "Regeneration", "desc": "+2 HP per second this run.", "buff": {"regen": 2.0}},
		{"name": "Bomb Bag", "desc": "+5 bottles and +50% throwable damage.", "buff": {"throw_dmg": 50.0}, "bottles": 5},
	]
	pool.shuffle()
	var opts := pool.slice(0, 3)
	Sfx.play("shrine")
	Menus.show_choice(ui, "A SHRINE OF QUESTIONABLE GODS", "Pick one blessing. It lasts until you leave the dungeon.", opts, func(o: Dictionary):
		r.used = true
		it.enabled = false
		for k in o["buff"]:
			player.buffs[k] = float(player.buffs.get(k, 0.0)) + float(o["buff"][k])
		player.bottles += int(o.get("bottles", 0))
		player.refresh_stats()
		if o["name"] == "Fortitude":
			player.heal(player.max_hp * 0.3)
		Fx.ring(content, player.global_position, 4.0, Color("#c880ff"), 0.6)
		ui.toast("Blessed: %s" % o["name"], Color("#d8a8ff"))
		Sfx.play("loot_rare"))


func _pop_rest(r: RoomRT) -> void:
	var c := r.world_center()
	var mi := MeshInstance3D.new()
	mi.mesh = DProps.campfire(true)
	mi.material_override = VMat.solid(0.05, 4.0)
	mi.position = c
	content.add_child(mi)
	Scanner.mark(mi, "Campfire", Color("#ff9a3a"))
	var l := FlickerLight.new()
	l.light_color = Color("#ff9a3a")
	l.light_energy = 2.0
	l.omni_range = 11.0
	l.position = c + Vector3(0, 1.4, 0)
	content.add_child(l)
	_lights.append({"light": l, "room": r.d.id, "pos": l.position})
	Style.solid_box(content, Vector3(1.0, 0.6, 1.0), c + Vector3(0, 0.3, 0)).collision_layer = 1
	var it := Interactable.make(content, c + Vector3(0, 1.0, 0), "Rest by the fire (heal + grog)", Callable(), 3.0)
	it.callback = func(_by: Node):
		if r.used:
			ui.toast("The fire is down to embers. One rest per campfire.", Color("#ffd89a"))
			return
		r.used = true
		it.enabled = false
		player.heal(player.max_hp)
		player.hp = player.max_hp
		var cap := int(player.stats["grog"]) + 2
		if Game.grog_stock < cap:
			Game.grog_stock += 1
		Sfx.play("potion")
		ui.toast("Rested. HP full. (+1 grog)", Color("#9dffa0"))
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#ff9a3a")})
	_breakables(r, 2)


func _pop_merchant(r: RoomRT) -> void:
	var c := r.world_center()
	var mi := MeshInstance3D.new()
	mi.mesh = DProps.cart()
	mi.material_override = VMat.solid(0.05, 4.0)
	mi.position = c + Vector3(0, 0, -1.0)
	content.add_child(mi)
	Scanner.mark(mi, "Merchant", Color("#9fe6b0"))
	Style.solid_box(content, Vector3(1.8, 1.2, 1.0), c + Vector3(0, 0.6, -1.0)).collision_layer = 1
	var npc := Npc.make(content, "skeleton", theme, "Grib the Peddler", 1.0, true)
	npc.position = c + Vector3(0, 0, 1.0)
	var l := OmniLight3D.new()
	l.light_color = Color("#ffd8a0")
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.position = c + Vector3(0, 2.8, 0)
	content.add_child(l)
	_lights.append({"light": l, "room": r.d.id, "pos": l.position})
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_value + r.d.id
	for i in 3:
		r.stock.append(ItemDB.roll(ItemDB.ilvl_for(tier, floor_no, Game.level), rr, ["weapon", "", ""][i], -1, 20.0 + _luck))
	var it := Interactable.make(content, c + Vector3(0, 1.0, 1.0), "Trade with Grib", Callable(), 3.4)
	it.callback = func(_by: Node): _merchant_menu(r)
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#7aff9a")})
	_breakables(r, 2)


func _merchant_menu(r: RoomRT) -> void:
	var entries: Array = []
	entries.append({"label": "Grog flask  -  35 copper", "desc": "Grib: \"Heals. Probably.\"", "enabled": Game.copper >= 35 and Game.grog_stock < int(player.stats["grog"]) + 2,
		"cb": func():
			Game.copper -= 35
			Game.grog_stock += 1
			Sfx.play("coin")
			_merchant_menu(r)})
	entries.append({"label": "3 throwing bottles  -  25 copper", "desc": "Glass, but make it weaponised.", "enabled": Game.copper >= 25,
		"cb": func():
			Game.copper -= 25
			player.bottles += 3
			Sfx.play("coin")
			_merchant_menu(r)})
	for it in r.stock:
		var item: Dictionary = it
		var price := int(round(float(item["value"]) * 2.2))
		entries.append({"label": "%s  -  %d copper" % [ItemDB.title(item), price],
			"desc": "%s %s  -  %s" % [ItemDB.rarity_name(int(item["rarity"])), ItemDB.SLOT_NAMES[item["slot"]], ", ".join(ItemDB.describe(item).slice(0, 3))],
			"enabled": Game.copper >= price and Game.inventory.size() < Game.INV_CAP,
			"cb": func():
				Game.copper -= price
				Game.inventory.append(item)
				r.stock.erase(item)
				Sfx.play("coin")
				_merchant_menu(r)})
	ui.show_menu("GRIB THE PEDDLER", "You have %d copper." % Game.copper, entries, "Leave")


func _pop_trap(r: RoomRT) -> void:
	var c := r.world_center()
	var n := 6 + r.d.area() / 40
	for i in n:
		var t := _random_tile(r, 1, 2.5)
		var pos := _tile_pos(t)
		var plate := MeshInstance3D.new()
		plate.mesh = DProps.plate()
		plate.material_override = VMat.solid(0.05, 4.0)
		plate.position = pos + Vector3(0, 0.02, 0)
		content.add_child(plate)
		var spikes := MeshInstance3D.new()
		spikes.mesh = DProps.spikes()
		spikes.material_override = VMat.solid(0.05, 4.0)
		spikes.position = pos + Vector3(0, -0.6, 0)
		content.add_child(spikes)
		_traps.append({"pos": pos, "spikes": spikes, "plate": plate, "t": _rng.randf() * 3.0, "period": 3.0, "hit": false, "room": r.d.id})
	# the loot at the end of the gauntlet
	var far := _random_tile(r, 1, 0.0)
	_make_chest(_tile_pos(far), 1 if tier < 3 else 2, false, r)
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#ff6a4a")})
	_breakables(r, 3)


func _pop_boss(r: RoomRT) -> void:
	var th: Dictionary = Game.THEMES[theme]
	var bid: String = th["boss"]
	if floor_no > 1:
		var ids := ["auditor", "mimic_king", "landlord", "dragon"]
		bid = ids[(seed_value + floor_no) % ids.size()]
	boss = Boss.make_boss(bid, theme, tier, mods)
	boss.room = r
	boss.spawn_cb = Callable(self, "_boss_spawn")
	content.add_child(boss)
	boss.global_position = r.world_center() + Vector3(0, 0.1, 0)
	Scanner.mark(boss, "BOSS", Color("#ff5a4a"))
	boss.died.connect(_on_boss_died)
	boss.phase_changed.connect(func(_b, p): ui.announce("%s IS ENRAGED" % boss.boss_name.to_upper(), "Phase %d" % p, Color("#ff5a3a"), 1.8))
	boss.pacified.connect(func(_b): _on_dragon_pacified())
	r.markers.append({"pos": Vector2(r.world_center().x, r.world_center().z), "col": Color("#ff3a3a")})
	_breakables(r, 4)


func _boss_spawn(kind_id: String, pos: Vector3) -> Mob:
	var r := rooms[g.boss_id]
	return _spawn_mob(r, kind_id, pos, false, true)


func _pop_customer(r: RoomRT) -> void:
	var c := r.world_center()
	var kinds := {"crypt": "skeleton", "sewer": "rat", "caves": "mushroom", "furnace": "imp", "ice": "intern"}
	var kind: String = kinds.get(theme, "skeleton")
	var npc := Npc.make(content, kind, theme, customer_name, 1.4 if kind == "rat" else 1.1)
	npc.position = c + Vector3(0, 0, -1.5)
	Scanner.mark(npc, "%s (customer)" % customer_name, Color("#4ae0ff"))
	var l := OmniLight3D.new()
	l.light_color = Color("#ffe0a0")
	l.light_energy = 1.8
	l.omni_range = 11.0
	l.position = c + Vector3(0, 3.0, 0)
	content.add_child(l)
	_lights.append({"light": l, "room": r.d.id, "pos": l.position})
	var mi := MeshInstance3D.new()
	mi.mesh = VoxProps.rug(14, 10, Color("#9a2a3a"), Color("#e6b840"))
	mi.material_override = VMat.solid(0.1, 4.0)
	mi.position = c + Vector3(-0.7, 0.01, -0.5)
	content.add_child(mi)
	var it := Interactable.make(content, c + Vector3(0, 1.0, -0.5), "Deliver %s to %s" % [parcel_title, customer_name], Callable(), 3.4)
	it.callback = func(_by: Node):
		if parcel_delivered:
			return
		if not boss_dead:
			ui.toast("%s: \"The boss is still out there. I'm not accepting parcels from someone who skipped it.\"" % customer_name, Color("#ffd89a"))
			return
		_deliver(1.0)
		it.enabled = false
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#4ae0ff")})
	_breakables(r, 3)


func _pop_stairs(r: RoomRT) -> void:
	var c := r.world_center()
	r.markers.append({"pos": Vector2(c.x, c.z), "col": Color("#4ae0ff")})
	_breakables(r, 3)
	var l := OmniLight3D.new()
	l.light_color = Color("#a0d8ff")
	l.light_energy = 1.4
	l.omni_range = 10.0
	l.position = c + Vector3(0, 3.0, 0)
	content.add_child(l)
	_lights.append({"light": l, "room": r.d.id, "pos": l.position})
	# stairs/portals appear after the boss is beaten (see _on_boss_died)


func _make_portal(pos: Vector3, color: Color, prompt: String, cb: Callable) -> Node3D:
	var node := Node3D.new()
	node.position = pos
	content.add_child(node)
	Scanner.mark(node, prompt.split("  (")[0], color)
	var mi := MeshInstance3D.new()
	mi.mesh = DProps.portal(color)
	mi.material_override = VMat.solid(0.1, 4.0)
	node.add_child(mi)
	var l := FlickerLight.new()
	l.light_color = color
	l.light_energy = 1.8
	l.omni_range = 8.0
	l.position = Vector3(0, 1.4, 0.4)
	node.add_child(l)
	Interactable.make(node, Vector3(0, 1.0, 0.6), prompt, cb, 3.2)
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 0.07)
	p.mesh = bm
	p.material_override = Fx._unshaded(color, 1.0, 3.0)
	p.amount = 24
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(1.0, 0.1, 0.1)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3.ZERO
	p.position = Vector3(0, 0.2, 0.3)
	node.add_child(p)
	_portals.append(node)
	return node


# ---------------------------------------------------------------- run loop

func _process(delta: float) -> void:
	if _ended:
		return
	elapsed += delta
	_room_t -= delta
	_reveal_t -= delta
	_light_t -= delta
	_hazard_t -= delta
	if _room_t <= 0.0:
		_room_t = 0.1
		_track_room()
	if _reveal_t <= 0.0:
		_reveal_t = 0.25
		_reveal_around(player.global_position, 9.0)
		_map_flush()
	if _blackout_t > 0.0:
		_blackout_t -= delta
		if _blackout_t <= 0.0:
			_light_t = 0.0
	if _light_t <= 0.0:
		_light_t = 0.35
		var pp := player.global_position
		for l in _lights:
			var node := l["light"] as Light3D
			if node != null and is_instance_valid(node):
				node.visible = _blackout_t <= 0.0 and pp.distance_to(l["pos"]) < 34.0
	if _hazard_t <= 0.0:
		_hazard_t = 0.3
		_hazards()
	_noise_t -= delta
	if _noise_t <= 0.0:
		_noise_t = _rng.randf_range(7.0, 14.0)
		_noisy_sack()
	_update_traps(delta)
	for r in rooms:
		if r.state == "active":
			_wave_logic(r, delta)
	if boss != null and is_instance_valid(boss):
		ui.combat.boss = boss
		ui.combat.boss_name = boss.boss_name
		ui.combat.boss_title = boss.boss_title


## Every light on the floor goes dark for a while (spooky events).
func blackout(secs: float) -> void:
	_blackout_t = maxf(_blackout_t, secs)
	for l in _lights:
		var node := l["light"] as Light3D
		if node != null and is_instance_valid(node):
			node.visible = false


## Noisy scrap (dolls, horns, clocks...) goes off in your sack and wakes things up nearby.
func _noisy_sack() -> void:
	var noisy: Array = []
	for sc in Game.scrap:
		if Scrap.DB.get(str(sc["id"]), {}).get("noisy", false):
			noisy.append(sc)
	if noisy.is_empty() or player.dead:
		return
	var sc: Dictionary = noisy[_rng.randi() % noisy.size()]
	var d: Dictionary = Scrap.DB[str(sc["id"])]
	Sfx.play(str(d["snd"]), 2.0, 0.9)
	FloatText.spawn(content, player.global_position + Vector3(0, 2.2, 0), "*%s goes off in your sack*" % str(d["name"]).to_lower(), Color("#ffe27a"), 0.8)
	for n in get_tree().get_nodes_in_group("mob"):
		var m := n as Mob
		if m != null and not m.dead and not m.awake and m.room == null and m.global_position.distance_to(player.global_position) < 26.0:
			m.wake()


func _track_room() -> void:
	var pt := Vector2i(int(floor(player.global_position.x)), int(floor(player.global_position.z)))
	var dr := g.room_at(pt.x, pt.y)
	if dr == null:
		return
	var r := rooms[dr.id]
	if r != _cur_room:
		_cur_room = r
		if not r.seen:
			r.seen = true
			_on_first_visit(r)
	if r.state == "idle" and (r.kind in ["combat", "boss"]) and not (r.kind == "boss" and boss_dead):
		var deep := true
		for door in r.d.doors:
			if Vector2(pt).distance_to(Vector2(door["tile"])) < 3.5:
				deep = false
		if deep:
			_activate(r)


func _on_first_visit(r: RoomRT) -> void:
	match r.kind:
		"treasure":
			ui.toast("A treasure room! (Careful: not every chest is honest.)", Color("#ffe27a"))
		"shrine":
			ui.toast("A shrine hums quietly.", Color("#d8a8ff"))
		"rest":
			ui.toast("A campfire. Blessed, blessed warmth.", Color("#ffb070"))
		"merchant":
			ui.toast("A peddler! He has... goods.", Color("#9dffa0"))
		"trap":
			ui.toast("The floor looks suspiciously plate-shaped. Watch your step!", Color("#ff9a7a"))
		"boss":
			ui.hint("d_boss", "The boss! Learn its red floor warnings, roll through the attacks, and hit it when it's tired.", 8.0)
		"customer":
			ui.toast("%s is waiting." % customer_name, Color("#9fe6ff"))
	ui.hint("d_loot", "Loot glows with rarity: white, green, blue, purple, ORANGE. Walk over it to pick it up. Tab opens your pack.", 9.0)


func _activate(r: RoomRT) -> void:
	if r.state != "idle":
		return
	r.state = "active"
	_set_gates(r, true)
	r.wave = 0
	if r.kind == "boss":
		ui.announce(boss.boss_name.to_upper(), boss.boss_title, Color("#ff7a5a"), 2.4)
		ui.combat.boss = boss
		ui.combat.boss_name = boss.boss_name
		ui.combat.boss_title = boss.boss_title
		boss.wake()
		Sfx.set_track("boss")
		r.mobs = [boss]
		r.wave = 1
		r.waves = 1
		Sfx.play("boss", 2.0)
		return
	if r.ambush:
		r.budget = 4 + tier
	_next_wave(r)


func _next_wave(r: RoomRT) -> void:
	r.wave += 1
	var count := int(round(float(r.budget) / float(r.waves))) + (1 if r.wave > 1 else 0)
	var elite_chance := 0.05 + 0.02 * tier + _elite_bonus
	var placed := 0
	while placed < count:
		var kind := MobDB.pick_kind(theme, tier, _rng)
		var pack := int(MobDB.KINDS[kind]["pack"])
		var elite: bool = _rng.randf() < elite_chance and placed > 0 and pack <= 1
		for i in pack:
			var t := _random_tile(r, 1, 0.0)
			var tries := 0
			while Vector2(_tile_pos(t).x, _tile_pos(t).z).distance_to(Vector2(player.global_position.x, player.global_position.z)) < 5.0 and tries < 12:
				t = _random_tile(r, 1, 0.0)
				tries += 1
			_spawn_mob(r, kind, _tile_pos(t), elite and i == 0)
			placed += 1
	if _ghosts and r.wave == 1:
		for i in 2:
			var t2 := _random_tile(r, 1, 0.0)
			_spawn_mob(r, "ghost", _tile_pos(t2) + Vector3(0, 0.5, 0), false)
	if r.waves > 1:
		ui.toast("Wave %d / %d" % [r.wave, r.waves], Color("#ff9a7a"))
	Sfx.play("spore", -4.0, 0.6)


func _spawn_mob(r: RoomRT, kind_id: String, pos: Vector3, elite: bool, instant := false) -> Mob:
	var m := Mob.make(kind_id, theme, tier, mods, elite)
	m.room = r
	content.add_child(m)
	m.global_position = pos + Vector3(0, 0.05, 0)
	m.died.connect(_on_mob_died)
	r.mobs.append(m)
	if instant:
		m.awake = true
		return m
	Fx.ring(content, pos, 1.8, Color("#c8a0ff") if not elite else Color("#ffd24a"), 0.7)
	Style.burst(content, pos + Vector3(0, 0.4, 0), Color("#c8a0ff"), 8, 3.0, 0.08, 0.7)
	if m.model != null:
		var tgt := m.model.scale
		m.model.scale = tgt * Vector3(1, 0.05, 1)
		var tw := m.create_tween()
		tw.tween_property(m.model, "scale", tgt, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	m.wake_in = 0.8
	return m


func _wave_logic(r: RoomRT, delta: float) -> void:
	r.mobs = r.mobs.filter(func(m): return is_instance_valid(m) and not (m as Mob).dead)
	if not r.mobs.is_empty():
		return
	if r.kind == "boss":
		return
	if r.wave < r.waves:
		r.wave_t += delta
		if r.wave_t > 1.2:
			r.wave_t = 0.0
			_next_wave(r)
		return
	_clear_room(r)


func _clear_room(r: RoomRT) -> void:
	r.state = "cleared"
	_set_gates(r, false)
	if r.kind == "combat" or r.ambush:
		ui.announce("ROOM CLEARED", "", Color("#9dffa0"), 1.2)
		var c := r.world_center()
		if randf() < 0.4:
			LootDrop.spawn(content, c, "orb")
		_drop_copper(c, 3 + tier)
		if randf() < 0.18 + _chest_mult * 0.04:
			_make_chest(c + Vector3(0, 0, 0), 0 if randf() < 0.75 else 1, false, r)
			ui.toast("A chest rose from the rubble.", Color("#ffe27a"))


# ---------------------------------------------------------------- drops, xp

func _on_mob_died(mob: Mob, info: Dictionary) -> void:
	if mob.is_boss:
		return
	kills += 1
	Game.kills += 1
	player.kills += 1
	if mob.suicide:
		return
	var gain := int(round(float(mob.xp_value) * _xp_mult))
	var ups := Game.add_xp(gain)
	xp_gained += gain
	FloatText.spawn(content, mob.global_position + Vector3(0, 1.2, 0), "+%d xp" % gain, Color("#7ed957"), 0.7)
	if ups > 0:
		_level_up()
	var pos := mob.global_position + Vector3(0, 0.5, 0)
	var gold_mult := _gold_mult * (1.0 + float(player.stats["gold_pct"]) / 100.0) * (1.5 if Stats.has_unique(player.stats, "gold_aura") else 1.0)
	var coins := int(round((2.0 + 1.5 * tier + float(mob.xp_value) * 0.3) * gold_mult * (3.0 if mob.elite else 1.0)))
	_drop_copper(pos, coins, true)
	var luck := float(player.stats["luck"]) + _luck
	var chance := 0.07 + (0.0 if not mob.elite else 1.0)
	if mob.kind == "mimic":
		chance = 1.0
	if randf() < chance:
		_drop_item(pos, "", 0.4 if mob.elite else 0.0, mob.kind == "mimic")
		if mob.kind == "mimic":
			_drop_item(pos, "", 0.5, true)
	var hp_frac := player.hp / player.max_hp
	if randf() < 0.1 + (0.12 if hp_frac < 0.5 else 0.0):
		LootDrop.spawn(content, pos, "orb")
	if randf() < 0.07:
		LootDrop.spawn(content, pos, "bottle", null, 1)
	if randf() < 0.03:
		LootDrop.spawn(content, pos, "grog")


func _level_up() -> void:
	player.refresh_stats()
	player.heal(player.max_hp * 0.5)
	Sfx.play("levelup")
	ui.announce("LEVEL %d" % Game.level, "+1 skill point  -  visit the cellar!", Color("#ffe97a"), 1.6)
	Fx.ring(content, player.global_position, 5.0, Color("#ffe97a"), 0.7)


func _drop_copper(pos: Vector3, total: int, split := false) -> void:
	var pieces := clampi(total / 3, 1, 5) if split else clampi(total / 2, 1, 8)
	var each := maxi(total / pieces, 1)
	for i in pieces:
		LootDrop.spawn(content, pos, "copper", null, each)


func _drop_item(pos: Vector3, slot: String, boost: float, rare_floor := false) -> void:
	var luck := float(player.stats["luck"]) + _luck
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	var ilvl := ItemDB.ilvl_for(tier, floor_no, Game.level)
	var rarity := ItemDB.roll_rarity(rr, luck, boost)
	if rare_floor:
		rarity = maxi(rarity, 2)
	var it := ItemDB.roll(ilvl, rr, slot, rarity, luck)
	var d := LootDrop.spawn(content, pos, "item", it)
	d.ui = ui
	loot_found.append(it)
	if rarity >= 4:
		ui.announce("LEGENDARY!", ItemDB.title(it), ItemDB.rarity_color(4), 2.0)
		Sfx.play("loot_epic")
	elif rarity == 3:
		Sfx.play("loot_rare", -2.0)


# ---------------------------------------------------------------- bosses, delivery, finishing

func _on_boss_died(mob: Mob, info: Dictionary) -> void:
	boss_dead = true
	Sfx.set_track("dungeon")
	var r := rooms[g.boss_id]
	r.state = "cleared"
	_set_gates(r, false)
	ui.combat.boss = null
	var peaceful: bool = info.get("source", "") == "pacified"
	var gain := int(round(float(mob.xp_value) * _xp_mult))
	var ups := Game.add_xp(gain)
	xp_gained += gain
	kills += 1
	Game.kills += 1
	if ups > 0:
		_level_up()
	var bid: String = boss.boss_id
	if not Game.trophies.has(bid):
		Game.trophies.append(bid)
	ui.announce("%s DEFEATED" % boss.boss_name.to_upper() if not peaceful else "PEACE IN OUR TIME", "Loot incoming!" if not peaceful else "The dragon is thrilled.", Color("#ffe97a"), 2.6)
	Game.moment("DEFEATED %s" % boss.boss_name.to_upper() if not peaceful else "PACIFIED A DRAGON WITH A PARCEL")
	ui.slowmo(0.3, 1.4)
	var pos := mob.global_position + Vector3(0, 0.6, 0)
	_drop_item(pos, "", 0.9, true)
	_drop_item(pos, "", 0.6, true)
	_drop_item(pos, "", 1.2, true)
	_drop_copper(pos, int((60 + 40 * tier) * _gold_mult), true)
	for i in 3:
		LootDrop.spawn(content, pos, "orb")
	_make_chest(pos + Vector3(2.5, 0, 0), 2, false, r)
	ui.combat.objective = "Deliver %s to %s" % [parcel_title, customer_name] if floor_no == 1 and not parcel_delivered else "Find the way down (or portal home)"
	if floor_no > 1:
		_spawn_exit_portals()
	if peaceful and floor_no == 1:
		_deliver(1.35)


func _on_dragon_pacified() -> void:
	ui.toast("The dragon sniffs the parcel. It IS his. He is crying.", Color("#ffd89a"))


func _deliver(bonus_mult: float) -> void:
	if parcel_delivered:
		return
	parcel_delivered = true
	var cond := player.parcel_cond
	var fast := elapsed < 480.0
	var base := float(job.get("pay", 200))
	var pay := int(round(base * (0.4 + 0.6 * cond / 100.0) * bonus_mult * (1.2 if fast else 1.0)))
	Game.copper += pay
	player.copper_run += pay
	Game.deliveries += 1
	Game.add_xp(60.0 + 40.0 * tier)
	xp_gained += int(60 + 40 * tier)
	Sfx.play("deliver")
	var quips := ["\"Finally. I've been waiting since the Third Age.\"", "\"Is it supposed to be ticking? ...Never mind. Thanks!\"", "\"You're the first goblin who didn't scream at me. 5 stars.\"", "\"Tip is included in the price. That's a joke. There's no tip.\""]
	ui.toast("%s: %s" % [customer_name, quips[randi() % quips.size()]], Color("#9fe6ff"))
	ui.announce("DELIVERED!", "+%d copper   (parcel %d%%%s)" % [pay, int(cond), ", speedy bonus" if fast else ""], Color("#9dffa0"), 2.4)
	if cond >= 99.0:
		Game.moment("PERFECT DELIVERY (IN A DUNGEON)")
	# progression
	var new_tier := false
	if tier >= Game.max_tier:
		Game.max_tier = tier + 1
		new_tier = true
	Game.best_floor = maxi(Game.best_floor, floor_no)
	if new_tier:
		for t in Game.THEME_ORDER:
			if int(Game.THEMES[t]["tier"]) == Game.max_tier:
				ui.toast("NEW REGION UNLOCKED: %s!" % Game.THEMES[t]["name"], Color("#ffe97a"))
	Game.save_game()
	ui.combat.objective = "Take the portal home, or the stairs deeper"
	_spawn_exit_portals()


func _spawn_exit_portals() -> void:
	if not _portals_for_exit.is_empty():
		return
	var r: RoomRT = rooms[g.customer_id] if g.customer_id >= 0 and rooms.size() > g.customer_id else rooms[g.boss_id]
	var c := r.world_center()
	var p1 := _make_portal(c + Vector3(-3.0, 0, 3.5), Color("#7ac8ff"), "Portal home  (keep all your loot)", Callable(self, "_go_home"))
	var p2 := _make_portal(c + Vector3(3.0, 0, 3.5), Color("#ff9a4a"), "Take the stairs DOWN  (floor %d: harder, better loot)" % (floor_no + 1), Callable(self, "_descend"))
	_portals_for_exit = [p1, p2]
	r.markers.append({"pos": Vector2(c.x - 3, c.z + 3.5), "col": Color("#7ac8ff")})
	r.markers.append({"pos": Vector2(c.x + 3, c.z + 3.5), "col": Color("#ff9a4a")})


func _go_home(_by: Node) -> void:
	if _ended:
		return
	_finish("delivered" if parcel_delivered else "left", "BACK HOME", _summary_lines())


func _confirm_abandon(_by: Node) -> void:
	ui.show_menu("LEAVE THE DUNGEON?", "You keep everything you found, but the contract fails (no pay).",
		[{"label": "Yes, leave", "desc": "Cowardice has its advantages.", "cb": func():
			ui.close_modal()
			_finish("abandoned", "CLOCKED OUT", "You crept back out of the dungeon.\n" + _summary_lines())}],
		"Stay and fight")


func _descend(_by: Node) -> void:
	if _ended:
		return
	floor_no += 1
	tier += 1
	Game.best_floor = maxi(Game.best_floor, floor_no)
	var themes: Array = []
	for t in Game.THEME_ORDER:
		if Game.theme_unlocked(t):
			themes.append(t)
	theme = themes[randi() % themes.size()]
	seed_value = randi()
	job["deeper"] = true
	await ui.fade_to(1.0, 0.4)
	_portals_for_exit = []
	# new floor: re-environment
	for c in get_children():
		if c is WorldEnvironment:
			c.queue_free()
	Atmos.dungeon(self, theme, _dark)
	for mo in _motes:
		if is_instance_valid(mo):
			mo.queue_free()
	_motes = Atmos.dungeon_motes(player.cam, theme)
	_load_floor()
	await ui.fade_to(0.0, 0.5)
	_announce_intro()
	ui.combat.objective = "Find the boss. Then the stairs."


func _summary_lines() -> String:
	var parts: Array[String] = []
	parts.append("Kills: %d    XP: +%d    Floor reached: %d" % [kills, xp_gained, floor_no])
	parts.append("Copper: %+d    Items found: %d" % [Game.copper - copper_start, loot_found.size()])
	if Game.level > 1:
		parts.append("You are level %d." % Game.level)
	return "\n".join(parts)


func _on_player_died(cause: String) -> void:
	if _ended:
		return
	var dname: String = Game.goblin_name
	Game.moment("%s %s" % [dname.to_upper(), cause.to_upper()])
	ui.slowmo(0.3, 1.8)
	var lost: Array = []
	for uid in Game.run_loot:
		for it in Game.inventory:
			if it["uid"] == uid:
				lost.append(it)
	Game.record_death(cause)
	await get_tree().create_timer(3.4, true, false, true).timeout
	if _ended:
		return
	var lines := "%s %s.\nFuneral deducted: %d copper.\n%s" % [dname, cause, Game.funeral_cost(), _summary_lines()]
	if not lost.is_empty():
		lines += "\nThe dungeon kept %d item%s you found this run." % [lost.size(), "s" if lost.size() > 1 else ""]
	_finish("died", "%s IS DEAD" % dname.to_upper(), lines)


func _finish(outcome: String, title: String, lines: String) -> void:
	if _ended:
		return
	_ended = true
	Engine.time_scale = 1.0
	if outcome != "died":
		Game.run_loot.clear()
		for sc in Game.scrap:
			sc["run"] = false
	var quotes: Array = Game.ROAST_DEATH if outcome == "died" else Game.ROAST_OK
	var kept: Array = []
	if outcome != "died":
		kept = loot_found.duplicate()
	var result := {
		"outcome": outcome, "title": title, "lines": lines,
		"moments": Game.clips.duplicate(), "loot": kept,
		"quote": "Grubnik: \"%s\"" % quotes[randi() % quotes.size()],
		"floor": floor_no, "kills": kills, "xp": xp_gained, "delivered": parcel_delivered,
	}
	await ui.fade_to(1.0, 0.5)
	finished.emit(result)


# ---------------------------------------------------------------- hazards & traps

func _hazards() -> void:
	if player.dead:
		return
	var pt := Vector2i(int(floor(player.global_position.x)), int(floor(player.global_position.z)))
	var kind := g.tile(pt.x, pt.y)
	if player.global_position.y > 0.8:
		return
	if kind == DungeonGen.T_LAVA:
		player.take_hit(Vector3.UP, 5.0, 10.0 + 3.0 * tier, "tried to swim in lava")
		player.add_status("burn", 2.5, 6.0)
	elif kind == DungeonGen.T_POISON:
		player.add_status("poison", 3.0, 3.0 + tier)
		player.add_status("slow", 1.0, 0.0)


func _update_traps(delta: float) -> void:
	if _traps.is_empty():
		return
	var pp := player.global_position
	for tr in _traps:
		tr["t"] += delta
		var ph: float = fmod(tr["t"], tr["period"])
		var pos: Vector3 = tr["pos"]
		if pp.distance_to(pos) > 30.0:
			continue
		var spikes := tr["spikes"] as MeshInstance3D
		var plate := tr["plate"] as MeshInstance3D
		if ph < 1.9:
			spikes.position.y = pos.y - 0.6
			plate.material_override = VMat.solid(0.05, 4.0)
			tr["hit"] = false
		elif ph < 2.5:
			spikes.position.y = pos.y - 0.45 + (0.05 if int(ph * 20.0) % 2 == 0 else 0.0)        # shaking warning
			plate.material_override = VMat.solid(0.05, 4.0, {"tint": Color(1.8, 0.5, 0.4)})
		else:
			spikes.position.y = pos.y
			if not tr["hit"] and Vector2(pp.x - pos.x, pp.z - pos.z).length() < 0.95 and pp.y < 0.9:
				tr["hit"] = true
				player.take_hit(Vector3.UP, 3.0, TRAP_DMG + 3.0 * tier, "found the spikes the hard way")
				Sfx.play("hit")


# ---------------------------------------------------------------- minimap

func _init_map() -> void:
	_map_img = Image.create(g.width, g.height, false, Image.FORMAT_RGBA8)
	_map_img.fill(Color(0, 0, 0, 0))
	_map_tex = ImageTexture.create_from_image(_map_img)


func _reveal_around(pos: Vector3, radius: float) -> void:
	var cx := int(pos.x)
	var cz := int(pos.z)
	var ri := int(ceil(radius))
	var th_col: Color = Game.THEMES[theme]["color"]
	var floor_col := Color(0.62, 0.58, 0.52, 0.95).lerp(th_col, 0.15)
	for y in range(cz - ri, cz + ri + 1):
		for x in range(cx - ri, cx + ri + 1):
			if x < 1 or y < 1 or x >= g.width - 1 or y >= g.height - 1:
				continue
			if (Vector2(x, y) - Vector2(pos.x, pos.z)).length() > radius:
				continue
			var tk := g.tile(x, y)
			if tk == DungeonGen.T_VOID:
				continue
			var c := floor_col
			if tk == DungeonGen.T_LAVA:
				c = Color("#ff6a20")
			elif tk == DungeonGen.T_POISON:
				c = Color("#7ae04a")
			if _map_img.get_pixel(x, y).a < 0.9 or _map_img.get_pixel(x, y) != c:
				_map_img.set_pixel(x, y, c)
				_map_dirty = true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if g.tile(nx, ny) == DungeonGen.T_VOID and _map_img.get_pixel(nx, ny).a < 0.5:
					_map_img.set_pixel(nx, ny, Color(0.16, 0.12, 0.1, 0.95))
					_map_dirty = true


func _map_flush() -> void:
	if _map_dirty:
		_map_tex.update(_map_img)
		_map_dirty = false


func minimap_texture() -> Texture2D:
	return _map_tex


func player_tile() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z)


func minimap_markers() -> Array:
	var out: Array = []
	for r in rooms:
		if not r.seen:
			continue
		for m in r.markers:
			if r.used and (r.kind == "shrine" or r.kind == "rest"):
				continue
			out.append({"pos": m["pos"], "col": m["col"]})
	return out
