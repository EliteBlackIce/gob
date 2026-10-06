class_name Parcel
extends Node3D
## A parcel with a personality. Each trait is a different way to ruin your day.

signal destroyed(reason: String)

var job: Dictionary = {}
var trait_id := "plain"
var title := "Parcel"
var condition := 100.0
var heat := 0.0
var state := "carried"   # carried | loose | stolen | absorbed | escaped
var player: Player
var island: Node
var ui: UI

var _scream_t := 4.0
var _wiggle_t := 9.0
var _warn := false
var _mouth: MeshInstance3D
var _glow: ShaderMaterial
var _steam: CPUParticles3D
var _legs: Array[MeshInstance3D] = []
var _pickup: Interactable
var _vel := Vector3.ZERO
var _hop_t := 0.0
var _t := 0.0
var _dead := false
var _grab_cd := 0.0


static func create(j: Dictionary) -> Parcel:
	var p := Parcel.new()
	p.job = j
	p.trait_id = j["trait"]
	p.title = j["title"]
	p._build()
	return p


func _build() -> void:
	match trait_id:
		"screamer":
			Style.cyl(self, 0.3, 0.3, 0.3, Color("#f2c64a"), Vector3(0, 0.15, 0), Vector3.ZERO, 12)
			Style.cyl(self, 0.31, 0.31, 0.03, Color("#d9a22c"), Vector3(0, 0.3, 0), Vector3.ZERO, 12)
			for hp in [Vector3(0.12, 0.3, 0.1), Vector3(-0.14, 0.3, -0.08), Vector3(0.0, 0.3, -0.18)]:
				Style.sphere(self, 0.05, Color("#c28a1e"), hp, Vector3(1, 0.3, 1), 5)
			Style.sphere(self, 0.07, Color.WHITE, Vector3(-0.1, 0.22, 0.28), Vector3.ONE, 6)
			Style.sphere(self, 0.07, Color.WHITE, Vector3(0.1, 0.22, 0.28), Vector3.ONE, 6)
			Style.sphere(self, 0.03, Color.BLACK, Vector3(-0.1, 0.22, 0.34), Vector3.ONE, 5)
			Style.sphere(self, 0.03, Color.BLACK, Vector3(0.1, 0.22, 0.34), Vector3.ONE, 5)
			_mouth = Style.box(self, Vector3(0.18, 0.04, 0.04), Color("#3a1208"), Vector3(0, 0.1, 0.3))
		"hot":
			_glow = Style.make_mat(Color("#b8431f"), 0.6, 0.1)
			var m := SphereMesh.new()
			m.radius = 0.26
			m.height = 0.46
			m.radial_segments = 8
			m.rings = 4
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = _glow
			mi.position = Vector3(0, 0.22, 0)
			mi.scale = Vector3(1.1, 1, 0.95)
			add_child(mi)
			Style.sphere(self, 0.04, Color("#7a2a12"), Vector3(0.12, 0.35, 0.15), Vector3.ONE, 4)
			_steam = CPUParticles3D.new()
			var sm := BoxMesh.new()
			sm.size = Vector3(0.1, 0.1, 0.1)
			_steam.mesh = sm
			_steam.material_override = Style.mat(Color("#ffe6c0"), 0.0, 0.4)
			_steam.amount = 12
			_steam.lifetime = 1.0
			_steam.direction = Vector3.UP
			_steam.spread = 25.0
			_steam.initial_velocity_min = 0.8
			_steam.initial_velocity_max = 1.6
			_steam.gravity = Vector3(0, 0.6, 0)
			_steam.position = Vector3(0, 0.5, 0)
			_steam.emitting = false
			add_child(_steam)
		"wiggly":
			Style.box(self, Vector3(0.5, 0.4, 0.4), Color("#7a4fb0"), Vector3(0, 0.25, 0))
			Style.box(self, Vector3(0.54, 0.06, 0.44), Color("#5b3a8a"), Vector3(0, 0.46, 0))
			Style.box(self, Vector3(0.1, 0.42, 0.42), Color("#d8b873"), Vector3(0, 0.25, 0))
			Style.sphere(self, 0.07, Color.WHITE, Vector3(-0.13, 0.32, 0.21), Vector3.ONE, 6)
			Style.sphere(self, 0.07, Color.WHITE, Vector3(0.13, 0.32, 0.21), Vector3.ONE, 6)
			Style.sphere(self, 0.03, Color.BLACK, Vector3(-0.13, 0.32, 0.27), Vector3.ONE, 5)
			Style.sphere(self, 0.03, Color.BLACK, Vector3(0.13, 0.32, 0.27), Vector3.ONE, 5)
			for s in [-1, 1]:
				_legs.append(Style.box(self, Vector3(0.08, 0.2, 0.08), Color("#3a2a1a"), Vector3(s * 0.15, 0.04, 0)))
		"glass":
			Style.sphere(self, 0.24, Color("#8fd0e8"), Vector3(0, 0.26, 0), Vector3(1, 1.1, 1), 9, 0.15)
			Style.cyl(self, 0.09, 0.13, 0.22, Color("#8fd0e8"), Vector3(0, 0.56, 0), Vector3.ZERO, 8, 0.15)
			Style.torus(self, 0.02, 0.1, Color("#e8c858"), Vector3(0, 0.67, 0), Vector3.ZERO, 0.2)
			Style.box(self, Vector3(0.04, 0.2, 0.02), Color("#e8c858"), Vector3(0.24, 0.3, 0), Vector3(0, 0, 8))
		"heavy":
			Style.box(self, Vector3(0.5, 0.12, 0.3), Color("#4a4e5a"), Vector3(0, 0.06, 0))
			Style.box(self, Vector3(0.28, 0.2, 0.22), Color("#5b6070"), Vector3(0, 0.22, 0))
			Style.box(self, Vector3(0.6, 0.14, 0.28), Color("#6c7284"), Vector3(0, 0.39, 0))
			Style.cone(self, 0.14, 0.3, Color("#6c7284"), Vector3(0.44, 0.39, 0), Vector3(0, 0, -90), 5)
		_:
			Style.box(self, Vector3(0.5, 0.4, 0.4), Color("#a07a48"), Vector3(0, 0.2, 0))


func _process(delta: float) -> void:
	_t += delta
	match state:
		"carried":
			_tick_carried(delta)
		"escaped":
			_tick_escaped(delta)
		"loose":
			position.y = _ground() + 0.02 if island != null and get_parent() == island else position.y
	if _mouth != null:
		_mouth.scale.y = lerpf(_mouth.scale.y, 1.0, delta * 6.0)
		_mouth.scale.x = lerpf(_mouth.scale.x, 1.0, delta * 6.0)
	if _glow != null:
		_glow.set_shader_parameter("emission_strength", 0.1 + heat / 100.0 * 1.4)
		var hot_col := Color("#b8431f").lerp(Color("#ffb347"), heat / 100.0)
		_glow.set_shader_parameter("albedo", hot_col)
	if _steam != null:
		_steam.emitting = heat > 55.0 and state != "loose"


func _ground() -> float:
	return island.height_at(global_position.x, global_position.z) if island != null else global_position.y


func _tick_carried(delta: float) -> void:
	if player == null or player.dead:
		return
	rotation.z = sin(_t * 9.0) * 0.1 * player.speed01
	rotation.x = sin(_t * 7.0) * 0.05 * player.speed01
	match trait_id:
		"screamer":
			_scream_t -= delta
			if _scream_t <= 0.0:
				_scream()
				_scream_t = randf_range(3.5, 6.0)
		"hot":
			var rate := 7.0 * (0.5 if player.in_water else 1.0)
			if player.in_water:
				heat = maxf(0.0, heat - 32.0 * delta)
			else:
				heat = minf(100.0, heat + rate * delta)
			if heat >= 100.0:
				_explode()
		"wiggly":
			_wiggle_t -= delta
			if _wiggle_t < 1.4 and not _warn:
				_warn = true
				ui.toast("The crate is wiggling...", Color("#d9b8ff"))
				Sfx.play("squelch", -6.0, 1.6)
			if _warn:
				position.x = sin(_t * 40.0) * 0.03
			if _wiggle_t <= 0.0:
				_escape()


func _scream() -> void:
	Sfx.play("scream")
	if _mouth != null:
		_mouth.scale = Vector3(1.0, 5.0, 1.0)
	if ui != null:
		ui.toast("AAAAAAAAAAAH!", Color("#ffe27a"))
	if player != null:
		player.shake = maxf(player.shake, 0.12)
	get_tree().call_group("enemy", "hear", global_position, 32.0)


func _explode() -> void:
	heat = 0.0
	Sfx.play("boom")
	Style.burst(get_tree().current_scene, global_position + Vector3.UP * 0.6, Color("#ff9a2e"), 26, 9.0, 0.2, 1.0)
	damage(35.0, "the potato went off")
	Game.moment("THE POTATO WENT OFF")
	if player != null:
		player.shake = 0.5
		player.take_hit(Vector3.UP + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)), 9.0, 1, "was cooked by a Hot Potato (Literal)")


func _escape() -> void:
	if player == null or island == null:
		return
	_warn = false
	_wiggle_t = randf_range(9.0, 14.0)
	state = "escaped"
	_grab_cd = 1.2
	var gpos := global_position
	get_parent().remove_child(self)
	island.add_child(self)
	global_position = gpos
	rotation = Vector3.ZERO
	player.carried = null
	_vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 5.0
	_vel.y = 5.0
	Sfx.play("pop")
	ui.toast("IT ESCAPED! Chase it!", Color("#d9b8ff"))
	Game.moment("THE CRATE RAN AWAY")


func _tick_escaped(delta: float) -> void:
	_grab_cd = maxf(0.0, _grab_cd - delta)
	for i in _legs.size():
		_legs[i].rotation.x = sin(_t * 25.0 + i * PI) * 0.8
	var g := _ground()
	_vel.y -= 18.0 * delta
	global_position += _vel * delta
	if global_position.y <= g:
		global_position.y = g
		_hop_t -= delta
		if _hop_t <= 0.0:
			_hop_t = randf_range(0.3, 0.6)
			var away := Vector3.ZERO
			if player != null:
				away = (global_position - player.global_position)
				away.y = 0.0
			away = away.normalized() + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))
			if island.height_at(global_position.x + away.x * 2.0, global_position.z + away.z * 2.0) < 0.2:
				away = -away
			_vel = away.normalized() * 5.2
			_vel.y = 6.0
		else:
			_vel.x = 0.0
			_vel.z = 0.0
	rotation.y += delta * 6.0
	damage(2.0 * delta, "chewed through the wall of a crate")
	if player != null and not player.dead and player.carried == null and not player.frozen and _grab_cd <= 0.0:
		if global_position.distance_to(player.global_position) < 1.5:
			player.grab(self)
			ui.toast("CAUGHT IT!", Color("#9dffa0"))
			Sfx.play("coin")


func damage(amount: float, reason := "damaged") -> void:
	if _dead:
		return
	if Game.has_skill("padding"):
		amount *= 0.65
	condition = maxf(0.0, condition - amount)
	if condition <= 0.0:
		_dead = true
		destroyed.emit(reason)


## Pack Rat's Q: calm every kind of parcel in the way it deserves.
func slap() -> void:
	Sfx.play("thud", -2.0, 1.6)
	match trait_id:
		"screamer":
			_scream_t = 12.0
			ui.toast("*shh* ...it's quiet.", Color("#ffe27a"))
		"hot":
			heat = 35.0
			ui.toast("Cooled it. Mostly.", Color("#ffb347"))
		"wiggly":
			_wiggle_t = 14.0
			_warn = false
			ui.toast("It's sulking. Good.", Color("#d9b8ff"))
		_:
			ui.toast("*pat pat* Good parcel.", Color("#f3e3b5"))


func status_text() -> String:
	match trait_id:
		"hot":
			return "HEAT %d%%" % int(heat)
		"screamer":
			return "SCREAMING"
		"wiggly":
			return "WIGGLY" if state != "escaped" else "LOOSE!"
		"glass":
			return "FRAGILE"
		"heavy":
			return "HEAVY"
	return ""


## Drops the parcel in the world where anybody (you, a crow) can pick it up.
func make_loose(world_pos: Vector3) -> void:
	state = "loose"
	if get_parent() != null:
		get_parent().remove_child(self)
	island.add_child(self)
	global_position = world_pos
	rotation = Vector3.ZERO
	scale = Vector3.ONE
	if _pickup == null:
		_pickup = Interactable.make(self, Vector3(0, 0.3, 0), "Pick up %s" % title, _on_pickup, 2.4)
	_pickup.enabled = true


func _on_pickup(by: Node) -> void:
	var p := by as Player
	if p != null and p.carried == null:
		p.grab(self)
		Sfx.play("pop")


func held() -> void:
	if _pickup != null:
		_pickup.enabled = false
