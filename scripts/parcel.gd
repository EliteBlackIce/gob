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
var _tossing := false


static func create(j: Dictionary) -> Parcel:
	var p := Parcel.new()
	p.job = j
	p.trait_id = j["trait"]
	p.title = j["title"]
	p._build()
	return p


func _build() -> void:
	var skin_mat := Paint.get_mat("plain", Color.WHITE, {"roughness": 0.5, "specular": 0.3, "rim": 0.3})
	match trait_id:
		"screamer":
			# a big wheel of cheese with holes, a rind, and a gaping, screaming face
			var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.27, 0.0), Vector2(0.31, 0.03), Vector2(0.325, 0.1), Vector2(0.31, 0.17), Vector2(0.27, 0.2), Vector2(0.0, 0.2)])
			var cols := PackedColorArray([Color("#e8b440"), Color("#d89a30"), Color("#e8a838"), Color("#f2c64a"), Color("#e8a838"), Color("#d89a30"), Color("#f6d462")])
			_vis(MeshKit.lathe(prof, 22, cols, "cheese"), skin_mat, Vector3(0, 0.0, 0))
			for h in [Vector3(0.1, 0.2, 0.1), Vector3(-0.14, 0.2, -0.08), Vector3(0.0, 0.2, -0.2), Vector3(0.18, 0.2, -0.12)]:
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.05, 0.025, 0.05), func(u: Vector3, p: Vector3) -> Color: return Color("#b07a1c")), skin_mat, h)
			for s2 in [-1.0, 1.0]:
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.07), Paint.get_mat("plain", Color("#fffbe8"), {"roughness": 0.2, "specular": 0.7}), Vector3(0.1 * s2, 0.2, 0.3))
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.033, 0.04, 0.02)), Paint.get_mat("plain", Color("#1a0e08"), {"roughness": 0.1, "specular": 0.9}), Vector3(0.1 * s2, 0.2, 0.36))
			_mouth = _vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.11, 0.045, 0.03), func(u: Vector3, p: Vector3) -> Color: return Color("#3a0e08").lerp(Color("#c0403a"), clampf(-u.y, 0.0, 1.0))), skin_mat, Vector3(0, 0.1, 0.32))
		"hot":
			_glow = Paint.make("plain", Color("#a83a1c"), {"roughness": 0.55, "specular": 0.25, "rim": 0.3, "emission_strength": 0.1, "variation": 0.4, "albedo_b": Color("#7a2a14")})
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			var nz := FastNoiseLite.new()
			nz.seed = 3
			nz.frequency = 1.6
			var pm := MeshKit.blob(func(u: Vector3) -> Vector3:
				var d := 1.0 + nz.get_noise_3dv(u * 1.4) * 0.28
				return u * Vector3(0.3, 0.23, 0.25) * d, func(u: Vector3, p: Vector3) -> Color:
				var c := Color("#c4602c").lerp(Color("#8a3a1a"), clampf(nz.get_noise_3dv(u * 3.0) * 0.5 + 0.5, 0.0, 1.0) * 0.6)
				return Color(c.r, c.g, c.b, 1.0), 14, 18)
			_vis(pm, _glow, Vector3(0, 0.23, 0))
			for k in 7:
				var a := rng.randf() * TAU
				var e := Vector3(cos(a) * 0.24, 0.23 + rng.randf_range(-0.05, 0.15), sin(a) * 0.2)
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.032, 0.02, 0.032), func(u: Vector3, p: Vector3) -> Color: return Color("#3a1408")), skin_mat, e)
			_steam = CPUParticles3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.07
			sm.height = 0.14
			sm.radial_segments = 6
			sm.rings = 3
			_steam.mesh = sm
			_steam.material_override = Paint.get_mat("cloth", Color("#f4ead8"), {"emission_strength": 0.5, "wrap": 0.9})
			_steam.amount = 14
			_steam.lifetime = 1.1
			_steam.direction = Vector3.UP
			_steam.spread = 25.0
			_steam.initial_velocity_min = 0.8
			_steam.initial_velocity_max = 1.6
			_steam.gravity = Vector3(0, 0.6, 0)
			_steam.position = Vector3(0, 0.5, 0)
			_steam.emitting = false
			add_child(_steam)
		"wiggly":
			var cr := Structures.crate(Vector3(0.52, 0.42, 0.42), 9, Color("#7a4fb0"))
			cr.position = Vector3(0, 0.0, 0)
			add_child(cr)
			# gold straps, big eyes, a lopsided grin, and wiggly legs
			for sx in [-0.14, 0.14]:
				_vis(MeshKit.rbox(Vector3(0.05, 0.44, 0.44), 0.01, 0.0), Paint.metal(Color("#d8b048")), Vector3(sx, 0.21, 0))
			for s2 in [-1.0, 1.0]:
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.065), Paint.get_mat("plain", Color("#fffbe8"), {"roughness": 0.2, "specular": 0.7}), Vector3(0.1 * s2, 0.27, 0.215))
				_vis(MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.03, 0.036, 0.02)), Paint.get_mat("plain", Color("#1a0e08"), {"roughness": 0.1, "specular": 0.9}), Vector3(0.1 * s2 + 0.01 * s2, 0.265, 0.268))
				var leg := _vis(MeshKit.tube([Vector3(0, 0, 0), Vector3(0.02 * s2, -0.08, 0.02), Vector3(0.03 * s2, -0.15, 0.06)], PackedFloat32Array([0.03, 0.026, 0.04]), 6, PackedColorArray([Color("#3a2a1a"), Color("#3a2a1a"), Color("#2a1a10")])), skin_mat, Vector3(0.14 * s2, 0.02, 0.0))
				_legs.append(leg)
			_vis(MeshKit.rbox(Vector3(0.2, 0.025, 0.02), 0.006), Paint.get_mat("plain", Color("#1a0e08")), Vector3(0.0, 0.14, 0.218), Vector3(0, 0, 6))
		"glass":
			# painted porcelain vase: bulb body, neck, flared lip, two handles, blue bands
			var prof2 := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.12, 0.0), Vector2(0.16, 0.04), Vector2(0.25, 0.16), Vector2(0.27, 0.28), Vector2(0.22, 0.4), Vector2(0.12, 0.5), Vector2(0.075, 0.58), Vector2(0.08, 0.68), Vector2(0.13, 0.74), Vector2(0.12, 0.76), Vector2(0.06, 0.74), Vector2(0.0, 0.7)])
			var cols2 := PackedColorArray()
			for i in prof2.size():
				var y := prof2[i].y
				var band := 0.5 + 0.5 * sin(y * 30.0)
				var c := Color("#f4f0e4").lerp(Color("#3a6ab8"), 0.0 if (int(y * 14.0) % 3 != 0) else 0.85)
				if i == 0 or i >= prof2.size() - 3:
					c = Color("#d8b048") if i >= prof2.size() - 3 else c
				cols2.append(Color(c.r, c.g, c.b, 1.0))
			_vis(MeshKit.lathe(prof2, 24, cols2, "vase"), Paint.get_mat("plain", Color.WHITE, {"roughness": 0.18, "specular": 0.9, "rim": 0.6, "variation": 0.0}), Vector3.ZERO)
			for s2 in [-1.0, 1.0]:
				_vis(MeshKit.tube([Vector3(0.075 * s2, 0.6, 0), Vector3(0.2 * s2, 0.66, 0), Vector3(0.22 * s2, 0.52, 0), Vector3(0.15 * s2, 0.46, 0)], PackedFloat32Array([0.022, 0.02, 0.02, 0.022]), 6, PackedColorArray([Color("#d8b048"), Color("#e8c458"), Color("#d8b048"), Color("#c09a38")])), Paint.metal(Color("#d8b048"), {"emission_strength": 0.05}))
		"heavy":
			var steel := Paint.metal(Color("#4a4e5a"), {"wear": 0.8, "wear_color": Color("#9aa0b0"), "roughness": 0.4})
			_vis(MeshKit.rbox(Vector3(0.5, 0.12, 0.32), 0.03, 0.2), steel, Vector3(0, 0.06, 0))
			_vis(MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.1, 0.1), Vector2(0.08, 0.18), Vector2(0.14, 0.24), Vector2(0.0, 0.24)]), 4, PackedColorArray(), "anvilwaist"), steel, Vector3(0, 0.12, 0), Vector3(0, 45, 0), Vector3(1.4, 1.0, 1.0))
			_vis(MeshKit.rbox(Vector3(0.64, 0.13, 0.3), 0.025, 0.1), steel, Vector3(0, 0.42, 0))
			_vis(MeshKit.tube([Vector3(0.28, 0.42, 0), Vector3(0.4, 0.42, 0), Vector3(0.54, 0.4, 0)], PackedFloat32Array([0.15, 0.1, 0.0]), 8, PackedColorArray([Color("#9aa0b0"), Color("#7a808e"), Color("#5a606e")])), steel)
			_vis(MeshKit.rbox(Vector3(0.1, 0.05, 0.1), 0.01), steel, Vector3(-0.24, 0.5, 0))
			_vis(MeshKit.rbox(Vector3(0.58, 0.02, 0.28), 0.006, 0.0), Paint.metal(Color("#8a90a0"), {"roughness": 0.25}), Vector3(-0.02, 0.495, 0))
		_:
			add_child(Structures.crate(Vector3(0.5, 0.4, 0.4), 2))


func _vis(mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	match state:
		"carried":
			_tick_carried(delta)
		"escaped":
			_tick_escaped(delta)
		"loose":
			if not _tossing and island != null and get_parent() == island:
				position.y = _ground() + 0.02
	if _mouth != null:
		_mouth.scale.y = lerpf(_mouth.scale.y, 1.0, delta * 6.0)
		_mouth.scale.x = lerpf(_mouth.scale.x, 1.0, delta * 6.0)
	if _glow != null:
		_glow.set_shader_parameter("emission_strength", 0.06 + heat / 100.0 * 0.9)
		_glow.set_shader_parameter("emission_color", Color("#ff5a14", clampf(heat / 60.0, 0.0, 1.0)))
		_glow.set_shader_parameter("albedo", Color("#a83a1c").lerp(Color("#ff7a2a"), heat / 100.0))
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


## G: lob the parcel a few metres. Dodges crows and slimes (they only want a
## *carried* parcel) -- but you have to go and pick it back up.
func toss(by: Player) -> void:
	if state != "carried" or island == null or _tossing:
		return
	var from := global_position
	var to: Vector3 = by.global_position + by.model.global_basis.z * 3.6
	to.y = float(island.height_at(to.x, to.z))
	if to.y < 0.0:
		ui.toast("Not into the sea!", Color("#9fe6ff"))
		return
	by.carried = null
	make_loose(from)
	_tossing = true
	_pickup.enabled = false
	Sfx.play("whoosh", -4.0, 1.3)
	var tw := create_tween()
	tw.tween_method(func(t: float): global_position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 1.8, 0.0, 1.0, 0.42)
	tw.tween_callback(func():
		_tossing = false
		_pickup.enabled = true
		Sfx.play("thud", -6.0, 1.2)
		if trait_id == "glass":
			damage(14.0, "tossed like a beanbag"))


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
