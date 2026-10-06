class_name Island
extends Node3D
## One delivery run: a hand-shaped island, a gorge with a toll ogre, crows,
## inspector slimes, and a customer who has been waiting since lunch.

signal finished(result: Dictionary)

const HX := 72.0
const HZ := 96.0
const STEP := 1.5
const ROUTE: Array[Vector2] = [
	Vector2(0, 84), Vector2(0, 62), Vector2(-2, 42), Vector2(-4, 28), Vector2(-4, 6),
	Vector2(-12, -12), Vector2(-10, -30), Vector2(-2, -50), Vector2(10, -66), Vector2(16, -76),
]
const GORGE_X := -4.0
const OGRE_POS := Vector2(-4, 18)
const HUT_POS := Vector2(-10, -30)
const LIGHT_POS := Vector2(18, -78)
const TAVERN_POS := Vector2(0, 86)
const SPAWN := Vector2(0, 72)

var ui: UI
var job: Dictionary = {}
var player: Player
var parcel: Parcel
var noise := FastNoiseLite.new()
var time_left := 180.0
var dest_pos := Vector3.ZERO

var _ended := false
var _rng := RandomNumberGenerator.new()
var _pickups: Array[Node3D] = []
var _ogre: Ogre = null
var _hint_clock := 0.0
var _hint_started := false
var _hint_poll := 0.0

const TRAIT_HINTS := {
	"screamer": "SCREAMING CHEESE: it shrieks every few seconds and crows hear it. Hold Q (with Parcel Slap) shushes it - or just outrun the birds.",
	"hot": "HOT POTATO: it heats up the whole way. Wade into the shallow sea to cool it - or it explodes in your satchel!",
	"wiggly": "WIGGLY CRATE: it WILL escape. When it wiggles, get ready - chase it down and touch it to catch it.",
	"glass": "GRANDMA'S VASE: jumping, dashing and falling all crack it. Walk carefully!",
	"heavy": "CEREMONIAL ANVIL: heavy, so you're slower. Plan your route around the crows.",
}


func _ready() -> void:
	_rng.seed = 7714
	noise.seed = 21
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	time_left = float(job["time"])
	Structures.allow_moss = true
	Atmos.day(self)
	IslandArt.build_clouds(self)
	var tdata := IslandArt.build_terrain(self)
	IslandArt.build_water(self, tdata)
	_crow_homes = IslandArt.scatter(self)
	_fix_crow_homes()
	IslandArt.build_tavern(self)
	IslandArt.build_hut(self)
	IslandArt.build_lighthouse(self)
	_build_pickups()
	_spawn_player()
	_spawn_enemies()
	dest_pos = _dest_world()
	ui.configure_hud(true)
	ui.set_dest("%s" % job["dest_name"])
	ui.hud_player = player
	ui.show_hud(true)
	Sfx.ambience(true)
	ui.toast("Deliver: %s  ->  %s" % [job["title"], job["dest_name"]], Color("#f3e3b5"))
	Game.clips.clear()


# ---------- height field ----------

func _dist_to_route(x: float, z: float) -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for i in ROUTE.size() - 1:
		var a := ROUTE[i]
		var b := ROUTE[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func height_at(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var r := sqrt(pow(x / 62.0, 2.0) + pow(z / 88.0, 2.0))
	var mask := 1.0 - Style.smooth(0.7, 1.03, r)
	var base := 2.6 + n * 6.5
	var h := lerpf(-5.0, base, mask)
	var f := 1.0 - Style.smooth(3.5, 12.0, _dist_to_route(x, z))
	h = lerpf(h, 1.5 + n * 0.5, f * 0.92)
	var plaza := 1.0 - Style.smooth(14.0, 24.0, Vector2(x, z).distance_to(Vector2(0, 80)))
	h = lerpf(h, 2.0, plaza)
	for c in [HUT_POS, LIGHT_POS]:
		var fd := 1.0 - Style.smooth(7.0, 14.0, Vector2(x, z).distance_to(c))
		h = lerpf(h, 2.0, fd)
	var gz := Style.smooth(2.0, 9.0, z) * (1.0 - Style.smooth(30.0, 37.0, z))
	var wall := Style.smooth(4.6, 7.8, absf(x - GORGE_X)) * gz
	h += wall * (9.5 + n * 3.0)
	return h


var _crow_homes: Array[Vector3] = []


## Make sure there are four crow perches near the route; build posts where palms are missing.
func _fix_crow_homes() -> void:
	var homes: Array[Vector3] = []
	var wanted := [Vector2(2, 52), Vector2(-14, -2), Vector2(-6, -24), Vector2(8, -58)]
	for wv in wanted:
		var best := Vector3(wv.x, height_at(wv.x, wv.y) + 4.5, wv.y)
		var bd := 1e9
		for ch in _crow_homes:
			var d := Vector2(ch.x, ch.z).distance_to(wv)
			if d < bd and d < 14.0:
				bd = d
				best = ch
		if bd >= 1e8:
			var gx := best.x
			var gz := best.z
			var gh := height_at(gx, gz)
			_perch_post(Vector3(gx, gh, gz))
			best = Vector3(gx, gh + 4.2, gz)
		homes.append(best)
	_crow_homes = homes


func _perch_post(p: Vector3) -> void:
	Style.cyl(self, 0.18, 0.26, 4.4, Color("#7a5a38"), p + Vector3(0, 2.2, 0), Vector3(3, 0, -2), 6)
	Style.box(self, Vector3(1.5, 0.12, 0.2), Color("#6a4a2d"), p + Vector3(0, 4.0, 0), Vector3(0, 30, 0))


func _build_pickups() -> void:
	for pv in [Vector2(2, 56), Vector2(-3, 36), Vector2(-9, -4), Vector2(-6, -40), Vector2(6, -60)]:
		var crate := IslandArt.build_pickup(Vector3(pv.x, height_at(pv.x, pv.y), pv.y))
		add_child(crate)
		_pickups.append(crate)


func _dest_world() -> Vector3:
	var p: Vector2 = HUT_POS if job["dest"] == "marl" else LIGHT_POS
	return Vector3(p.x, height_at(p.x, p.y), p.y)


var _keepers: Dictionary = {}


func _spawn_player() -> void:
	player = Player.new()
	player.island = self
	player.ui = ui
	player.position = Vector3(SPAWN.x, height_at(SPAWN.x, SPAWN.y) + 0.4, SPAWN.y)
	add_child(player)
	player.setup_for_run(true)
	player.model.rotation.y = PI
	player.died.connect(_on_player_died)
	parcel = Parcel.create(job)
	parcel.ui = ui
	parcel.island = self
	add_child(parcel)
	parcel.destroyed.connect(_on_parcel_destroyed)
	player.grab(parcel)


func _spawn_enemies() -> void:
	for i in _crow_homes.size():
		var c := Crow.new()
		c.island = self
		c.player = player
		c.ui = ui
		c.home = _crow_homes[i]
		c.nest = _nest_for(c.home)
		add_child(c)
	for sp in [Vector2(-6, 50), Vector2(-9, -2), Vector2(0, -46), Vector2(12, -64)]:
		var s := Slime.new()
		s.island = self
		s.player = player
		s.ui = ui
		s.home = Vector3(sp.x, height_at(sp.x, sp.y), sp.y)
		add_child(s)
	var ogre := Ogre.new()
	_ogre = ogre
	ogre.island = self
	ogre.player = player
	ogre.ui = ui
	ogre.position = Vector3(OGRE_POS.x, height_at(OGRE_POS.x, OGRE_POS.y), OGRE_POS.y)
	add_child(ogre)


# ---------- run flow ----------

func _process(delta: float) -> void:
	if _ended or player == null:
		return
	time_left -= delta
	ui.set_timer(time_left)
	_update_hints(delta)
	if time_left < -45.0 and not player.dead:
		_end("failed", "TOO LATE", "The customer gave up and bought from a rival goblin.\nNo pay. No refunds. No hard feelings (many hard feelings).", 0, 0)
		return
	var d := dest_pos - player.global_position
	ui.compass_angle = atan2(d.x, -d.z) + player.yaw
	ui.set_dest("%s  -  %dm" % [job["dest_name"], int(Vector2(d.x, d.z).length())])
	for pk in _pickups.duplicate():
		if is_instance_valid(pk) and pk.global_position.distance_to(player.global_position) < 1.8:
			_pickups.erase(pk)
			pk.queue_free()
			player.bottles += 2
			ui.toast("+2 bottles", Color("#9fe6b0"))
			Sfx.play("pop")
	for k in _keepers:
		var kp: Node3D = _keepers[k]
		GoblinModel.pose_wave(kp, Time.get_ticks_msec() * 0.001)


## Crow nests sit a short flap away from the perch, off the main path, so a
## theft is a quick chase and not a cross-country run.
func _nest_for(home: Vector3) -> Vector3:
	for k in 8:
		var a := TAU * k / 8.0 + 0.4
		var p := Vector2(home.x, home.z) + Vector2(cos(a), sin(a)) * 17.0
		var h := height_at(p.x, p.y)
		if h > 1.3 and h < 6.0 and _dist_to_route(p.x, p.y) > 7.0:
			return Vector3(p.x, h, p.y)
	var q := Vector2(home.x + 15.0, home.z)
	return Vector3(q.x, maxf(height_at(q.x, q.y), 1.5), q.y)


func _update_hints(delta: float) -> void:
	_hint_clock += delta
	if not _hint_started and _hint_clock > 1.2 and not ui.modal_open:
		_hint_started = true
		ui.hint("run", "WASD to run, mouse to look, SPACE to jump.\nFollow the gold arrow to %s and press E at the mailbox!" % job["dest_name"], 8.0)
		ui.hint("trait_" + str(job["trait"]), str(TRAIT_HINTS.get(job["trait"], "")), 9.0)
	_hint_poll -= delta
	if _hint_poll > 0.0 or player == null or player.dead:
		return
	_hint_poll = 0.4
	var pp := player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position.distance_to(pp)
		if e is Crow and d < 26.0:
			ui.hint("crow", "CROWS steal parcels! Kick them (F) or throw a bottle (Left Click). In a pinch, toss the parcel out of reach with G.", 9.0)
		elif e is Slime and d < 20.0:
			ui.hint("slime", "INSPECTOR SLIME! When the gold ring shrinks onto the green zone, press E to stamp. Miss and he confiscates the parcel - bottle him to make him spit it out.", 10.0)
	if _ogre != null and is_instance_valid(_ogre) and not _ogre.passed and _ogre.global_position.distance_to(pp) < 20.0:
		ui.hint("ogre", "The OGRE wants a riddle answered. Walk up to the gate and press E at the bell. Wrong answers hurt. Three wrong answers are fatal.", 10.0)
	if player.in_water:
		ui.hint("sea", "Shallow water is fine (and cools hot parcels). Deep water drowns goblins.", 7.0)
	if pp.distance_to(dest_pos) < 16.0:
		ui.hint("deliver", "Press E at the red mailbox to deliver. Fast + undamaged = bonus pay and skill points!", 8.0)


func _try_deliver(_by: Node) -> void:
	if _ended or player == null:
		return
	# the Interactable that fired belongs to whichever destination is active
	if player.global_position.distance_to(dest_pos) > 12.0:
		ui.toast("Wrong address. Check the label.", Color("#ffd89a"))
		Sfx.play("error")
		return
	if player.carried == null:
		ui.toast("You have no parcel! Find it!", Color("#ff9d8a"))
		Sfx.play("error")
		return
	var cond := player.carried.condition
	var late := time_left <= 0.0
	var fast := time_left > float(job["time"]) * 0.5
	var pay := int(round(float(job["pay"]) * (cond / 100.0) * (0.5 if late else 1.0)))
	if fast and not late:
		pay += int(round(pay * 0.25))
	var pts := 1 + (1 if cond >= 90.0 else 0)
	Game.copper += pay
	Game.deliveries += 1
	Game.skill_points += pts
	Game.save_game()
	Sfx.play("deliver")
	if cond >= 99.0:
		Game.moment("PERFECT DELIVERY (GOBLIN SURVIVED)")
	var tag := "   (LATE: half pay)" if late else ("   (SPEEDY: +25%)" if fast else "")
	var lines := "Delivered: %s\nCondition: %d%%%s\nPay: %d copper    Skill points: +%d" % [job["title"], int(cond), tag, pay, pts]
	_end("delivered", "DELIVERED!", lines, pay, pts)


func _abandon(_by: Node) -> void:
	if _ended:
		return
	var fee := 10 if player.carried != null else 0
	Game.copper -= fee
	_end("abandoned", "CLOCKED OUT", "You crept back inside.\n%s" % ("Restocking fee: %d copper." % fee if fee > 0 else "No parcel, no fee."), -fee, 0)


func _on_parcel_destroyed(reason: String) -> void:
	if _ended:
		return
	Game.moment("PARCEL DESTROYED (%s)" % reason.to_upper())
	await get_tree().create_timer(1.6).timeout
	if _ended:
		return
	_end("failed", "PARCEL LOST", "%s didn't make it: %s.\nNo pay. The customer 'understands'. (They do not.)" % [job["title"], reason], 0, 0)


func _on_player_died(cause: String) -> void:
	if _ended:
		return
	var dname: String = Game.goblin_name
	var caption := "%s %s" % [dname.to_upper(), cause.to_upper()]
	Game.moment(caption)
	ui.slowmo(0.3, 1.8)
	Game.record_death(cause)
	await get_tree().create_timer(3.4, true, false, true).timeout
	if _ended:
		return
	var lines := "%s %s.\nParcel lost. Funeral deducted: %d copper." % [dname, cause, Game.funeral_cost()]
	_end("died", "%s IS DEAD" % dname.to_upper(), lines, 0, 0)


func _end(outcome: String, title: String, lines: String, _pay: int, _pts: int) -> void:
	if _ended:
		return
	_ended = true
	var quotes: Array = Game.ROAST_DEATH if outcome == "died" else Game.ROAST_OK
	var result := {
		"outcome": outcome, "title": title, "lines": lines,
		"moments": Game.clips.duplicate(),
		"quote": "Grubnik: \"%s\"" % quotes[randi() % quotes.size()],
	}
	Game.perk_hp = 0
	Game.perk_bottles = 0
	Engine.time_scale = 1.0
	await ui.fade_to(1.0, 0.5)
	finished.emit(result)
