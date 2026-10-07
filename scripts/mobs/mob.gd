class_name Mob
extends CharacterBody3D
## One monster. Data-driven from MobDB: walks, shoots, lobs, hops, dives, charges or explodes.
## Every attack is telegraphed (wind-up pose + red pulse) so fights are readable and dodgeable.

signal died(mob: Mob, info: Dictionary)
signal damaged(mob: Mob, amount: float)

const GRAVITY := 22.0

var kind := "skeleton"
var theme := "crypt"
var tier := 1
var d: Dictionary = {}
var hp := 30.0
var max_hp := 30.0
var dmg := 10.0
var speed := 3.0
var dead := false
var awake := false
var elite := false
var affix := ""
var affix_data: Dictionary = {}
var title := ""
var body_h := 1.6
var body_r := 0.45
var kb_resist := 0.0
var is_boss := false
var suicide := false
var room: RefCounted = null
var player: Player = null
var model: Node3D
var base_scale := 1.0
var hover := 0.0
var xp_value := 5
var state := "idle"
var state_t := 0.0
var stun_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var poison_t := 0.0
var poison_dps := 0.0
var slow_t := 0.0
var kb := Vector3.ZERO
var mods: Array = []

var _mats: Array[ShaderMaterial] = []
var _flash := 0.0
var _anim_t := randf() * 10.0
var _cd := 0.0
var _hop_t := 0.0
var _dash_dir := Vector3.ZERO
var _dash_hit := false
var _atk_dir := Vector3.ZERO
var _bar: Node3D
var _bar_fill: MeshInstance3D
var _bar_t := 0.0
var _dot_t := 0.0
var _speed_now := 0.0
var _air := false
var _tele: Node3D = null
var _sep_t := 0.0
var _push := Vector3.ZERO
var _uid_beep := 0.0
var _heal_t := 0.0
var wake_in := -1.0               # >0: wake up after this many seconds (spawn-in delay)


## Factory: builds, scales and places a mob. Call add_child on the result yourself or use spawn().
static func make(kind_id: String, theme_id: String, tier_n: int, mod_list: Array, elite_n := false, affix_id := "") -> Mob:
	var m := Mob.new()
	m.setup(kind_id, theme_id, tier_n, mod_list, elite_n, affix_id)
	return m


func setup(kind_id: String, theme_id: String, tier_n: int, mod_list: Array, elite_n := false, affix_id := "") -> void:
	kind = kind_id
	theme = theme_id
	tier = tier_n
	mods = mod_list
	d = MobDB.scaled(kind, tier, mods)
	hp = float(d["hp"])
	dmg = float(d["dmg"])
	speed = float(d["speed"])
	body_h = float(d["h"])
	body_r = float(d["r"])
	xp_value = int(d["xp"])
	hover = float(d.get("hover", 0.0))
	base_scale = float(d.get("scale", 1.0))
	title = str(d["name"])
	if elite_n:
		elite = true
		affix = affix_id
		if affix == "":
			var keys: Array = MobDB.ELITE_AFFIXES.keys()
			affix = keys[randi() % keys.size()]
		affix_data = MobDB.ELITE_AFFIXES[affix]
		hp *= 1.7 * float(affix_data.get("hp", 1.0))
		dmg *= 1.3 * float(affix_data.get("dmg", 1.0))
		speed *= float(affix_data.get("speed", 1.0))
		xp_value *= 3
		base_scale *= float(affix_data.get("scale", 1.0)) * 1.15
		title = "%s %s" % [affix_data["name"], title]
	max_hp = hp


func _ready() -> void:
	add_to_group("mob")
	collision_layer = 16
	collision_mask = 1 | 16
	floor_snap_length = 0.4
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_r * base_scale
	cap.height = maxf(body_h * base_scale, body_r * 2.2)
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)
	_build_model()
	player = get_tree().get_first_node_in_group("player") as Player
	_make_bar()
	_cd = randf_range(0.2, 1.0)
	if hover > 0.0:
		motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	if kind == "ghost":
		collision_mask = 0


func _build_model() -> void:
	model = MobModels.build(kind, theme)
	model.scale = Vector3.ONE * base_scale
	add_child(model)
	_tint_model()


func _tint_model() -> void:
	_mats.clear()
	var ghost := MobModels.is_ghostly(kind)
	var extra := {}
	if elite:
		extra["tint"] = Color(1.0, 1.0, 1.0).lerp(affix_data["color"], 0.28)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: ShaderMaterial
		if ghost:
			m = VMat.glass(MobModels.S, 0.55).duplicate()
		else:
			m = VMat.make_solid(model_vox(), 4.0, extra)
			if elite:
				m.set_shader_parameter("emission_strength", 2.2)
		(mi as MeshInstance3D).material_override = m
		_mats.append(m)


func model_vox() -> float:
	return MobModels.S


func _make_bar() -> void:
	_bar = Node3D.new()
	_bar.position = Vector3(0, (body_h * base_scale) + 0.45 + hover * 0.0, 0)
	add_child(_bar)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	bg.mesh = q
	bg.material_override = _bar_mat(Color(0.08, 0.04, 0.04))
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(1.0, 0.07)
	_bar_fill.mesh = q2
	var fc: Color = Color("#e0382c") if not elite else (affix_data["color"] as Color)
	_bar_fill.material_override = _bar_mat(fc)
	_bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar_fill.position.z = 0.002
	_bar.add_child(_bar_fill)
	if elite:
		var lab := Style.label3d(_bar, title, Vector3(0, 0.2, 0), 0.006, affix_data["color"], Vector3.ZERO, true)
		lab.no_depth_test = true
	_bar.visible = elite
	if is_boss:
		_bar.visible = false


func _bar_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.render_priority = 3
	return m


func wake() -> void:
	if awake or dead:
		return
	awake = true
	state = "chase"
	_cd = randf_range(0.3, 0.9)


func ground_y() -> float:
	return global_position.y


func dist_to_player() -> float:
	if player == null or not is_instance_valid(player):
		return 999.0
	var dv := player.global_position - global_position
	return Vector2(dv.x, dv.z).length()


func dir_to_player() -> Vector3:
	var dv := player.global_position - global_position
	dv.y = 0.0
	return dv.normalized() if dv.length() > 0.01 else Vector3.FORWARD


func face(dir: Vector3, delta: float, rate := 10.0) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


# ------------------------------------------------------------------ physics loop

func _physics_process(delta: float) -> void:
	if dead:
		return
	_anim_t += delta
	if wake_in > 0.0:
		wake_in -= delta
		if wake_in <= 0.0:
			wake()
	_flash = maxf(0.0, _flash - delta * 6.0)
	_bar_t = maxf(0.0, _bar_t - delta)
	if _bar != null and not elite and not is_boss:
		_bar.visible = _bar_t > 0.0
	_apply_flash()
	if player == null or not is_instance_valid(player) or player.dead:
		player = get_tree().get_first_node_in_group("player") as Player
		_idle_physics(delta)
		return
	_statuses(delta)
	if dead:
		return
	if not awake:
		if dist_to_player() < 14.0 and room == null:
			wake()
		_idle_physics(delta)
		_animate("idle", 0.0, 0.0)
		return
	state_t += delta
	_cd = maxf(0.0, _cd - delta)
	kb = kb.move_toward(Vector3.ZERO, 22.0 * delta)
	if stun_t > 0.0:
		stun_t -= delta
		_move(Vector3.ZERO, 0.0, delta)
		_animate("stun", 0.0, 0.0)
		return
	_think(delta)
	_separate(delta)


func _idle_physics(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if hover <= 0.0:
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = (_hover_target() - global_position.y) * 3.0
	move_and_slide()


func _hover_target() -> float:
	return hover + sin(_anim_t * 2.4) * 0.15


func _move(dir: Vector3, spd: float, delta: float, accel := 18.0) -> void:
	var s := spd * (0.5 if slow_t > 0.0 else 1.0)
	var want := dir * s + kb + _push
	velocity.x = move_toward(velocity.x, want.x, accel * delta * 2.0)
	velocity.z = move_toward(velocity.z, want.z, accel * delta * 2.0)
	if hover > 0.0:
		velocity.y = (_hover_target() - global_position.y) * 3.0
	else:
		velocity.y -= GRAVITY * delta
		if is_on_floor() and velocity.y < 0.0:
			velocity.y = -1.0
	_speed_now = Vector2(velocity.x, velocity.z).length()
	move_and_slide()


func _separate(delta: float) -> void:
	_sep_t -= delta
	if _sep_t > 0.0:
		return
	_sep_t = 0.12
	_push = Vector3.ZERO
	for o in get_tree().get_nodes_in_group("mob"):
		var m := o as Mob
		if m == null or m == self or m.dead:
			continue
		var dv := global_position - m.global_position
		dv.y = 0.0
		var l := dv.length()
		var need := (body_r * base_scale + m.body_r * m.base_scale) * 1.05
		if l < need and l > 0.001:
			_push += dv / l * (need - l) * 6.0


func _animate(pose: String, k: float, speed01_override := -1.0) -> void:
	if model == null:
		return
	var sp01 := clampf(_speed_now / maxf(speed, 0.1), 0.0, 1.0) if speed01_override < 0.0 else speed01_override
	MobModels.animate(model, _anim_t, sp01, pose, k)


func _apply_flash() -> void:
	var tint_red := 0.0
	if state == "windup" and not is_boss:
		tint_red = 0.5 + 0.5 * sin(state_t * 24.0)
	for m in _mats:
		m.set_shader_parameter("flash", _flash * 0.85)
		if kind != "ghost":
			var base: Color = Color(1, 1, 1).lerp(affix_data["color"], 0.28) if elite else Color.WHITE
			m.set_shader_parameter("tint", base.lerp(Color(1.9, 0.55, 0.45), tint_red * 0.8))
			if burn_t > 0.0:
				m.set_shader_parameter("tint", base.lerp(Color(1.8, 0.9, 0.4), 0.5))
			elif poison_t > 0.0:
				m.set_shader_parameter("tint", base.lerp(Color(0.6, 1.5, 0.6), 0.5))


func _statuses(delta: float) -> void:
	slow_t = maxf(0.0, slow_t - delta)
	_dot_t -= delta
	if burn_t > 0.0:
		burn_t -= delta
	if poison_t > 0.0:
		poison_t -= delta
	if _dot_t <= 0.0:
		_dot_t = 0.5
		if burn_t > 0.0:
			_dot(burn_dps * 0.5, Color("#ff9a3a"))
		if poison_t > 0.0:
			_dot(poison_dps * 0.5, Color("#7aff6a"))
	if affix == "vampiric" and awake:
		pass


func _dot(amount: float, color: Color) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	_bar_t = 3.0
	_update_bar()
	FloatText.spawn(get_parent(), global_position + Vector3(0, body_h * base_scale + 0.3, 0), str(int(round(amount))), color, 0.8)
	if hp <= 0.0:
		_die({"source": "dot"})


# ------------------------------------------------------------------ AI

func _think(delta: float) -> void:
	var dist := dist_to_player()
	var to := dir_to_player()
	var atk: String = str(d["atk"])
	var rng_attack: float = float(d["range"])
	match state:
		"chase", "idle":
			_chase(delta, dist, to, atk, rng_attack)
		"windup":
			_windup(delta, dist, to, atk)
		"strike":
			_strike(delta, dist, to, atk)
		"recover":
			_recover(delta, dist, to)
		"hop":
			_hop_air(delta, dist, to)


func _chase(delta: float, dist: float, to: Vector3, atk: String, rng_attack: float) -> void:
	var ai: String = str(d["ai"])
	var move_dir := Vector3.ZERO
	var spd := speed
	match ai:
		"walk", "charge":
			if ai == "charge":
				# circle at mid range, then charge
				if dist > 10.0:
					move_dir = to
				elif dist < 5.0:
					move_dir = -to * 0.6 + to.cross(Vector3.UP) * 0.8
				else:
					move_dir = to.cross(Vector3.UP) * (1.0 if int(_anim_t * 0.3) % 2 == 0 else -1.0)
					spd *= 0.7
			elif dist > rng_attack * 0.85:
				move_dir = to
			if ai == "walk" and atk == "explode":
				spd = speed
		"keep":
			var keep := float(d.get("keep", 7.0))
			if dist < keep - 1.0:
				move_dir = -to
				spd *= 0.8
			elif dist > rng_attack * 0.85:
				move_dir = to
			else:
				move_dir = to.cross(Vector3.UP) * (1.0 if int(_anim_t * 0.4) % 2 == 0 else -1.0) * 0.6
				spd *= 0.6
		"fly", "ghost":
			# loiter around the player then dive
			var orbit := to.cross(Vector3.UP) * (1.0 if int(_anim_t * 0.5 + float(get_instance_id() % 7)) % 2 == 0 else -1.0)
			move_dir = (to * 0.4 + orbit * 0.9).normalized() if dist < 7.0 else to
			if dist < 3.0:
				move_dir = -to * 0.5 + orbit
		"fly_keep":
			var keep2 := float(d.get("keep", 8.0))
			if dist < keep2 - 1.5:
				move_dir = -to
			elif dist > rng_attack * 0.8:
				move_dir = to
			else:
				move_dir = to.cross(Vector3.UP) * (1.0 if int(_anim_t * 0.35) % 2 == 0 else -1.0)
				spd *= 0.7
		"hop":
			_hop_wait(delta, dist, to)
			return
	face(to, delta)
	if ai == "ghost":
		# ghosts drift through everything; keep them off the floor collision
		pass
	_move(move_dir.normalized() if move_dir.length() > 0.01 else Vector3.ZERO, spd, delta)
	_animate("walk", 0.0)
	# start an attack?
	if _cd <= 0.0 and _can_attack(dist, atk, rng_attack):
		_begin_attack(to, atk)


func _can_attack(dist: float, atk: String, rng_attack: float) -> bool:
	match atk:
		"swing", "slam", "explode":
			return dist <= rng_attack
		"shoot", "lob":
			return dist <= rng_attack and dist >= float(d.get("keep", 5.0)) * 0.5
		"dash":
			return dist <= rng_attack and dist >= 3.5
		"dive":
			return dist <= 8.0 and dist >= 2.0
	return false


func _begin_attack(to: Vector3, atk: String) -> void:
	state = "windup"
	state_t = 0.0
	_atk_dir = to
	_dash_hit = false
	if atk == "slam":
		var rr := float(d.get("aoe", 3.0)) * base_scale
		var wt := float(d["windup"])
		_tele = Fx.telegraph_circle(self, global_position, rr, wt, Callable())
	elif atk == "dash":
		_tele = Fx.telegraph_line(self, global_position, to, 7.5, 1.4, float(d["windup"]), Callable())
	if atk == "explode":
		Sfx.play("beep", -6.0, 1.0)
	elif atk == "shoot" or atk == "lob":
		pass


func _windup(delta: float, dist: float, to: Vector3, atk: String) -> void:
	var wt := float(d["windup"])
	if atk == "explode":
		_move(to, speed * 0.6, delta)
		face(to, delta)
		_uid_beep -= delta
		if _uid_beep <= 0.0:
			_uid_beep = 0.18
			Sfx.play("beep", -8.0, 1.0 + state_t)
	elif atk == "dash" or atk == "slam":
		_move(Vector3.ZERO, 0.0, delta)
		if atk == "dash":
			_atk_dir = _atk_dir.lerp(to, delta * 3.0).normalized()
			face(_atk_dir, delta, 14.0)
	else:
		face(to, delta, 12.0)
		_move(Vector3.ZERO, 0.0, delta)
	_animate("windup", clampf(state_t / wt, 0.0, 1.0), 0.0)
	if state_t >= wt:
		state = "strike"
		state_t = 0.0
		_do_strike(to, atk)


func _do_strike(to: Vector3, atk: String) -> void:
	_atk_dir = to
	match atk:
		"swing":
			Sfx.play("swing", -8.0, 0.8)
			var in_range := dist_to_player() <= float(d["range"]) + 0.7 + body_r * base_scale
			if in_range and _in_front(to, 0.1):
				_hurt_player(dmg, to, 5.5)
		"slam":
			var rr := float(d.get("aoe", 3.0)) * base_scale
			Sfx.play("thud", 2.0)
			Fx.ring(get_parent(), global_position, rr, Color("#ffcf8a"))
			Style.burst(get_parent(), global_position + Vector3(0, 0.2, 0), Color("#b8a888"), 14, 6.0, 0.14, 0.7)
			player.shake = maxf(player.shake, 0.5)
			if dist_to_player() <= rr:
				_hurt_player(dmg, to, 8.0)
		"shoot":
			_fire_projectile(to)
		"lob":
			_lob_projectile()
		"dash":
			_dash_dir = to
			_dash_hit = false
			Sfx.play("whoosh", -3.0, 0.9)
		"dive":
			var tp := player.global_position + Vector3(0, 0.9, 0)
			_dash_dir = (tp - (global_position + Vector3(0, body_h * 0.5, 0))).normalized()
			_dash_hit = false
			Sfx.play("whoosh", -5.0, 1.4)
		"explode":
			_explode()


func _strike(delta: float, dist: float, to: Vector3, atk: String) -> void:
	var dur := 0.2
	match atk:
		"dash":
			dur = 0.55
			velocity.x = _dash_dir.x * 15.0
			velocity.z = _dash_dir.z * 15.0
			velocity.y = -1.0 if hover <= 0.0 else velocity.y
			move_and_slide()
			if not _dash_hit and dist_to_player() < body_r * base_scale + 0.9:
				_dash_hit = true
				_hurt_player(dmg, _dash_dir, 7.0)
			_animate("strike", clampf(state_t / dur, 0.0, 1.0), 1.0)
		"dive":
			dur = 0.55
			velocity = _dash_dir * 11.0
			move_and_slide()
			if not _dash_hit and dist_to_player() < 1.0 + body_r and absf(player.global_position.y + 0.9 - global_position.y) < 1.4:
				_dash_hit = true
				_hurt_player(dmg, _dash_dir, 4.5)
			_animate("strike", clampf(state_t / dur, 0.0, 1.0), 1.0)
		"swing":
			dur = 0.22
			_move(_atk_dir * 4.5, 4.5, delta)
			_animate("strike", clampf(state_t / dur, 0.0, 1.0))
		_:
			_move(Vector3.ZERO, 0.0, delta)
			_animate("strike", clampf(state_t / dur, 0.0, 1.0))
	if state_t >= dur and state == "strike":
		state = "recover"
		state_t = 0.0
		if atk != "explode":
			_cd = float(d["cd"]) * randf_range(0.85, 1.2)


func _recover(delta: float, dist: float, to: Vector3) -> void:
	var dur := 0.35
	if str(d["atk"]) == "dash":
		dur = 0.9              # vulnerable after a charge
	_move(Vector3.ZERO, 0.0, delta)
	_animate("recover", clampf(state_t / dur, 0.0, 1.0), 0.0)
	if state_t >= dur:
		state = "chase"
		state_t = 0.0


func _in_front(to: Vector3, min_dot: float) -> bool:
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	return fwd.dot(to) > min_dot


func _hurt_player(amount: float, dir: Vector3, force: float) -> void:
	var res := player.take_hit(dir, force, amount, title, self)
	if affix == "vampiric" and res == "hit":
		hp = minf(max_hp, hp + amount * 0.5)
		_update_bar()
	if affix == "burning" and res == "hit":
		player.add_status("burn", 3.0, 5.0)


func _fire_projectile(to: Vector3) -> void:
	var start := global_position + Vector3(0, body_h * base_scale * 0.7, 0) + to * 0.5
	var aim := (player.global_position + Vector3(0, 1.0, 0) - start).normalized()
	var ps := float(d.get("proj_speed", 14.0))
	var col := Color("#ffd24a")
	var opts := {"radius": 0.25, "cause": title}
	if kind == "imp":
		col = Color("#ff6a1a")
		opts["aoe"] = float(d.get("aoe", 0.0))
		opts["status"] = "burn"
		Sfx.play("fire", -4.0)
	else:
		col = (MobDB.PALETTES[theme]["glow"] as Color).lerp(Color.WHITE, 0.4)
		Sfx.play("arrow", -4.0)
	Projectile.fire(get_parent(), "mob", start, aim * ps, dmg, col, opts)


func _lob_projectile() -> void:
	var start := global_position + Vector3(0, body_h * base_scale * 1.1, 0)
	var target := player.global_position + Vector3(0, 0.3, 0)
	var dv := target - start
	var flat := Vector2(dv.x, dv.z)
	var ps := float(d.get("proj_speed", 11.0))
	var T := maxf(flat.length() / ps, 0.45)
	var g := 16.0
	var vel := Vector3(dv.x / T, (dv.y + 0.5 * g * T * T) / T, dv.z / T)
	var col: Color = MobDB.PALETTES[theme]["glow"]
	Sfx.play("spore", -3.0)
	Projectile.fire(get_parent(), "mob", start, vel, dmg, col, {"gravity": g, "aoe": 2.2, "status": "poison", "radius": 0.3, "life": 3.0, "cause": title})


func _explode() -> void:
	var rr := float(d.get("aoe", 3.4))
	Sfx.play("boom", 0.0, 1.1)
	Fx.ring(get_parent(), global_position, rr, Color("#ffb040"), 0.5)
	Style.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Color("#ff8a2a"), 22, 8.0, 0.16, 0.7)
	Style.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Color("#3a3028"), 14, 6.0, 0.2, 0.9)
	player.shake = maxf(player.shake, 0.7)
	if dist_to_player() <= rr:
		_hurt_player(dmg, (player.global_position - global_position).normalized(), 9.0)
	for o in get_tree().get_nodes_in_group("mob"):
		var m := o as Mob
		if m != null and m != self and not m.dead and m.global_position.distance_to(global_position) < rr:
			m.take_damage(dmg * 0.8, (m.global_position - global_position).normalized(), {"source": "explosion"})
	suicide = true
	_die({"source": "self"})


# ---- hopping slimes

func _hop_wait(delta: float, dist: float, to: Vector3) -> void:
	face(to, delta, 8.0)
	_move(Vector3.ZERO, 0.0, delta)
	_hop_t += delta
	var pre := 0.4
	_animate("windup" if _hop_t > _cd_hop() - pre else "idle", clampf((_hop_t - (_cd_hop() - pre)) / pre, 0.0, 1.0), 0.0)
	if _hop_t >= _cd_hop():
		_hop_t = 0.0
		state = "hop"
		state_t = 0.0
		_air = true
		_dash_hit = false
		var s := speed * 1.7
		velocity = Vector3(to.x * s, 7.2, to.z * s)
		Sfx.play("squish", -6.0, randf_range(0.8, 1.3))


func _cd_hop() -> float:
	return float(d["cd"]) * 1.5


func _hop_air(delta: float, dist: float, to: Vector3) -> void:
	velocity.y -= GRAVITY * delta
	move_and_slide()
	_animate("strike", 0.0, 1.0)
	if not _dash_hit and dist_to_player() < body_r * base_scale + 0.7 and absf(player.global_position.y - global_position.y) < 1.6:
		_dash_hit = true
		_hurt_player(dmg, to, 5.0)
	if is_on_floor() and state_t > 0.15:
		state = "chase"
		state_t = 0.0
		_hop_t = 0.0
		_air = false
		velocity = Vector3.ZERO
		Sfx.play("squish", -10.0, 0.7)
		Style.burst(get_parent(), global_position + Vector3(0, 0.1, 0), (MobDB.PALETTES[theme]["main"] as Color), 6, 3.0, 0.1, 0.4)


# ------------------------------------------------------------------ damage

func take_damage(amount: float, dir: Vector3, info := {}) -> float:
	if dead:
		return 0.0
	if not awake:
		wake()
		if room != null and room.has_method("on_mob_hit"):
			room.on_mob_hit(self)
	var dealt := minf(amount, hp)
	hp -= amount
	_flash = 1.0
	_bar_t = 3.5
	_update_bar()
	var crit: bool = info.get("crit", false)
	var pos := global_position + Vector3(0, body_h * base_scale + 0.35, 0)
	var col := Color("#fff4e0")
	var sz := 1.0
	if crit:
		col = Color("#ffd23a")
		sz = 1.5
	elif info.get("source", "") == "bottle":
		col = Color("#9fe6b0")
	FloatText.spawn(get_parent(), pos, ("%d!" % int(round(amount))) if crit else str(int(round(amount))), col, sz)
	var snd := "bone" if kind in ["skeleton", "archer"] else ("squish" if kind in ["slime", "slime_small"] else "hit")
	Sfx.play("crit" if crit else snd, -3.0, randf_range(0.9, 1.15))
	Fx.hit(get_parent(), global_position + Vector3(0, body_h * base_scale * 0.6, 0), MobDB.PALETTES[theme]["main"] if kind in ["skeleton", "slime", "slime_small"] else Color("#e04a3a"), crit)
	var force := float(info.get("knock", 3.0)) * (1.0 - kb_resist)
	if force > 0.0 and not is_boss:
		kb = Vector3(dir.x, 0, dir.z).normalized() * force * 1.6
	if info.get("stun", 0.0) > 0.0 and not is_boss:
		stun(float(info["stun"]))
	elif amount >= max_hp * 0.22 and not is_boss and not elite and state in ["windup"]:
		_cancel_attack()
		stun_t = 0.5
	if info.has("burn") and info["burn"] > 0.0:
		burn_t = 3.0
		burn_dps = maxf(burn_dps, float(info["burn"]))
	if info.has("poison") and info["poison"] > 0.0:
		poison_t = 4.0
		poison_dps = maxf(poison_dps, float(info["poison"]))
	damaged.emit(self, amount)
	if hp <= 0.0:
		_die(info)
	return dealt


func _cancel_attack() -> void:
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
	_tele = null
	state = "chase"
	state_t = 0.0


func stun(t: float) -> void:
	if dead:
		return
	if is_boss:
		t *= 0.25
	if t <= 0.05:
		return
	stun_t = maxf(stun_t, t)
	_cancel_attack()
	if not is_boss:
		Style.burst(get_parent(), global_position + Vector3(0, body_h * base_scale + 0.1, 0), Color("#ffe97a"), 5, 1.8, 0.08, 0.5)


## Legacy hook used by island enemies' bottle code.
func hit(dir: Vector3, force: float) -> void:
	take_damage(8.0 * force, dir, {"knock": 4.0 * force})


func _update_bar() -> void:
	if _bar_fill == null:
		return
	var f := clampf(hp / max_hp, 0.0, 1.0)
	_bar_fill.scale.x = maxf(f, 0.001)
	_bar_fill.position.x = -0.5 * (1.0 - f)


func _die(info: Dictionary) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	if _bar != null:
		_bar.visible = false
	var cols: Array = _death_colors()
	Fx.debris(get_parent(), global_position + Vector3(0, body_h * base_scale * 0.5, 0), cols, 16 + int(body_h * 6), maxf(base_scale, 0.7))
	Sfx.play("pop", -4.0, 0.6)
	if affix == "explosive":
		var rr := float(affix_data.get("death_boom", 3.4))
		Fx.ring(get_parent(), global_position, rr, Color("#ff8a2a"), 0.5)
		Sfx.play("boom", -2.0)
		if player != null and dist_to_player() < rr:
			player.take_hit(dir_to_player() * -1.0, 7.0, dmg * 0.8, "a volatile " + String(kind), self)
	if str(d.get("split", "")) != "" and not suicide:
		_split()
	died.emit(self, info)
	_death_anim()


func _death_colors() -> Array:
	var pal: Dictionary = MobDB.PALETTES[theme]
	match kind:
		"skeleton", "archer":
			return [Color("#dcd6c0"), Color("#b8b29a"), Color("#6a5a8a")]
		"slime", "slime_small":
			return [pal["main"], (pal["main"] as Color).lightened(0.2), pal["glow"]]
		"imp", "hound":
			return [Color("#a02a20"), Color("#2a2020"), pal["glow"]]
		"golem":
			return [Color("#8a8a92"), Color("#6a6a72"), pal["glow"]]
	return [pal["main"], (pal["main"] as Color).darkened(0.25), pal["accent"]]


func _split() -> void:
	var into := str(d["split"])
	for i in 2:
		var m := Mob.make(into, theme, tier, mods)
		m.room = room
		get_parent().add_child(m)
		var a := TAU * (float(i) / 2.0) + randf() * 0.6
		m.global_position = global_position + Vector3(cos(a), 0.3, sin(a)) * 0.6
		m.awake = true
		m.state = "chase"
		m.kb = Vector3(cos(a), 0, sin(a)) * 4.0
		if room != null and room.has_method("adopt"):
			room.adopt(m)


func _death_anim() -> void:
	if model == null:
		queue_free()
		return
	var tw := create_tween()
	tw.tween_property(model, "rotation:x", -1.4, 0.25)
	tw.parallel().tween_property(model, "scale", model.scale * Vector3(1.0, 0.2, 1.0), 0.35)
	tw.tween_callback(queue_free)
