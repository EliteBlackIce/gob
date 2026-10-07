class_name Boss
extends Mob
## The four dungeon bosses. Each fight is a loop of telegraphed attacks that get nastier below
## half health. Attacks are written as little coroutines: wind-up, warning on the floor, strike.

signal phase_changed(boss: Boss, phase: int)
signal pacified(boss: Boss)

const BOSSES := {
	"auditor": {"name": "The Auditor", "title": "Chief of Unpaid Overtime", "hp": 560.0, "dmg": 1.0, "speed": 3.0, "h": 3.6, "r": 0.9, "xp": 160, "theme": "crypt"},
	"mimic_king": {"name": "The Mimic King", "title": "Sovereign of Suspicious Chests", "hp": 760.0, "dmg": 1.05, "speed": 3.4, "h": 2.6, "r": 1.5, "xp": 220, "theme": "sewer"},
	"landlord": {"name": "The Landlord", "title": "Rent Is Due. Always.", "hp": 980.0, "dmg": 1.1, "speed": 3.0, "h": 4.4, "r": 1.2, "xp": 300, "theme": "caves"},
	"dragon": {"name": "The Overdue Dragon", "title": "Has Been Waiting Since Tuesday", "hp": 1300.0, "dmg": 1.2, "speed": 3.6, "h": 3.2, "r": 1.7, "xp": 420, "theme": "furnace"},
}

var boss_id := "auditor"
var boss_name := ""
var boss_title := ""
var phase := 1
var busy := false
var spawn_cb: Callable
var _pose := "idle"
var _pose_t0 := 0.0
var _pose_dur := 1.0
var _atk_cd := 2.0
var _move_mode := "chase"
var _dmg_mult := 1.0
var _stagger := 0.0
var _stagger_t := 0.0
var _intro := 0.0
var _last_atk := ""
var _can_pacify := false
var _pacify_node: Interactable = null
var _spawned: Array = []
var _time := 0.0


static func make_boss(id: String, theme_id: String, tier_n: int, mod_list: Array) -> Boss:
	var b := Boss.new()
	b.boss_id = id
	b.is_boss = true
	b.theme = theme_id
	b.tier = tier_n
	b.mods = mod_list
	var d: Dictionary = BOSSES[id]
	b.boss_name = d["name"]
	b.boss_title = d["title"]
	b.title = d["name"]
	var t := float(maxi(tier_n, 1) - 1)
	b.max_hp = float(d["hp"]) * (1.0 + 0.32 * t)
	for m in mod_list:
		b.max_hp *= float((Game.MODIFIERS.get(m, {}) as Dictionary).get("hp", 1.0))
	b.hp = b.max_hp
	b._dmg_mult = float(d["dmg"]) * (1.0 + 0.16 * t) * 22.0 / 22.0
	b.dmg = 20.0 * b._dmg_mult
	b.speed = float(d["speed"])
	b.body_h = float(d["h"])
	b.body_r = float(d["r"])
	b.xp_value = int(float(d["xp"]) * (1.0 + 0.2 * t))
	b.kb_resist = 0.92
	b.d = {"atk": "none", "hp": b.max_hp, "range": 3.0, "name": b.boss_name, "ai": "boss", "dmg": b.dmg, "cd": 2.0, "windup": 1.0, "speed": b.speed, "h": b.body_h, "r": b.body_r, "xp": b.xp_value}
	b.base_scale = 1.0
	return b


func _build_model() -> void:
	model = BossModels.build(boss_id, theme)
	add_child(model)
	_tint_model()


func model_vox() -> float:
	return BossModels.S if boss_id == "dragon" else MobModels.S


func _tint_model() -> void:
	_mats.clear()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := VMat.make_solid(model_vox() if boss_id == "dragon" else MobModels.S, 4.0, {"emission_strength": 2.0})
		(mi as MeshInstance3D).material_override = m
		_mats.append(m)


func _ready() -> void:
	super._ready()
	if _bar != null:
		_bar.visible = false


func wake() -> void:
	if awake or dead:
		return
	awake = true
	_intro = 2.0
	state = "chase"
	Sfx.play("boss", 3.0)
	if player != null:
		player.shake = 1.0


# ---------------------------------------------------------------- loop

func _think(delta: float) -> void:
	_time += delta
	_stagger_t = maxf(0.0, _stagger_t - delta)
	if _stagger_t <= 0.0:
		_stagger = 0.0
	if _intro > 0.0:
		_intro -= delta
		_pose = "roar"
		_move(Vector3.ZERO, 0.0, delta)
		_boss_anim("roar", 0.5)
		if _intro <= 0.0:
			_pose = "idle"
		return
	if hp < max_hp * 0.5 and phase == 1 and not busy:
		_enter_phase2()
		return
	var to := dir_to_player()
	var dist := dist_to_player()
	_atk_cd = maxf(0.0, _atk_cd - delta)
	if busy:
		match _move_mode:
			"none":
				_move(Vector3.ZERO, 0.0, delta)
				face(to, delta, 6.0)
			"chase":
				face(to, delta, 6.0)
				_move(to, speed * (1.3 if phase == 2 else 1.0), delta)
			"away":
				face(to, delta, 6.0)
				_move(-to, speed, delta)
			"lock":
				_move(Vector3.ZERO, 0.0, delta)
		var k := clampf((_time - _pose_t0) / maxf(_pose_dur, 0.01), 0.0, 1.0)
		_boss_anim(_pose, k)
		return
	face(to, delta, 6.0)
	var want := _preferred_range()
	if dist > want:
		_move(to, speed * (1.3 if phase == 2 else 1.0), delta)
	elif dist < want * 0.6:
		_move(-to, speed * 0.7, delta)
	else:
		_move(Vector3.ZERO, 0.0, delta)
	_boss_anim("idle", 0.0)
	if _atk_cd <= 0.0:
		_start_attack(dist)


func _preferred_range() -> float:
	match boss_id:
		"auditor":
			return 7.0
		"mimic_king":
			return 6.0
		"landlord":
			return 6.0
		"dragon":
			return 7.5
	return 5.0


func _set_pose(p: String, dur: float) -> void:
	_pose = p
	_pose_t0 = _time
	_pose_dur = dur


func _boss_anim(p: String, k: float) -> void:
	if model == null:
		return
	if boss_id == "dragon":
		BossModels.animate_dragon(model, _anim_t, p, k, clampf(_speed_now / maxf(speed, 0.1), 0.0, 1.0))
		return
	var mp := p
	if p == "roar":
		mp = "windup"
	elif p in ["slam", "breath", "swipe", "gust", "cast"]:
		mp = "windup" if k < 0.6 else "strike"
	if boss_id == "mimic_king" and p == "idle":
		mp = "walk"
	MobModels.animate(model, _anim_t, clampf(_speed_now / maxf(speed, 0.1), 0.0, 1.0), mp, k if mp in ["windup", "strike"] else 0.0)


var _pacified := false
var _gen := 0


func _wait(secs: float) -> bool:
	var g := _gen
	await get_tree().create_timer(secs).timeout
	return not dead and is_inside_tree() and not _pacified and g == _gen


func _start_attack(dist: float) -> void:
	busy = true
	if randf() < 0.45:
		var lines: Array = MobDB.BOSS_BARKS.get(boss_id, [])
		if not lines.is_empty():
			FloatText.spawn(get_parent(), global_position + Vector3(0, body_h + 1.2, 0), lines[randi() % lines.size()], Color("#ffd89a"), 1.0, 2.0, 0.6)
	var pick := _choose_attack(dist)
	_last_atk = pick
	call(pick)


func _choose_attack(dist: float) -> String:
	var options: Array = []
	match boss_id:
		"auditor":
			options = ["_a_slam", "_a_volley", "_a_summon", "_a_stamp"] if phase == 2 else ["_a_slam", "_a_volley", "_a_summon"]
			if phase == 2:
				options.append("_a_redink")
		"mimic_king":
			options = ["_k_leap", "_k_tongue", "_k_coins"]
			if phase == 2:
				options.append("_k_bites")
			options.append("_k_minis")
		"landlord":
			options = ["_l_pound", "_l_notices", "_l_charge", "_l_tenants"]
			if phase == 2:
				options.append("_l_keys")
		"dragon":
			options = ["_d_breath", "_d_swipe", "_d_barrage", "_d_gust"]
			if phase == 2:
				options.append("_d_lavarain")
	# avoid repeating the same move twice; close range favours melee moves
	options = options.filter(func(o): return o != _last_atk)
	if dist < 5.0:
		for melee in ["_a_slam", "_k_leap", "_l_pound", "_d_swipe"]:
			if options.has(melee):
				options.append(melee)
				options.append(melee)
	return options[randi() % options.size()]


func _end_attack(cooldown: float) -> void:
	busy = false
	_pose = "idle"
	_move_mode = "chase"
	_atk_cd = cooldown * (0.7 if phase == 2 else 1.0)


func _enter_phase2() -> void:
	phase = 2
	busy = true
	_move_mode = "lock"
	_set_pose("roar", 1.6)
	Sfx.play("boss", 3.0, 1.2)
	player.shake = 1.0
	phase_changed.emit(self, 2)
	Fx.ring(get_parent(), global_position, 9.0, Color("#ff5a3a"), 0.8)
	if boss_id == "dragon":
		_enable_pacify()
	await _wait(1.6)
	if dead:
		return
	_end_attack(1.0)


# ---------------------------------------------------------------- shared attack helpers

func _hurt(amount: float, dir: Vector3, force: float) -> void:
	if player == null or player.dead:
		return
	player.take_hit(dir, force, amount * _dmg_mult, boss_name)


func _circle(center: Vector3, radius: float, windup: float, amount: float, force := 8.0, color := Color("#ff3a2a")) -> void:
	Fx.telegraph_circle(self, Vector3(center.x, global_position.y, center.z), radius, windup, func():
		if dead:
			return
		Fx.ring(get_parent(), Vector3(center.x, global_position.y, center.z), radius, Color("#ffcf8a"), 0.35)
		Style.burst(get_parent(), center + Vector3(0, 0.3, 0), Color("#b8a888"), 12, 6.0, 0.14, 0.6)
		Sfx.play("thud", 0.0, 0.8)
		if player != null:
			player.shake = maxf(player.shake, 0.5)
			var dv := player.global_position - center
			dv.y = 0.0
			if dv.length() <= radius and player.global_position.y < global_position.y + 1.2:
				_hurt(amount, dv.normalized() if dv.length() > 0.1 else Vector3.FORWARD, force), color)


func _line(from: Vector3, dir: Vector3, length: float, width: float, windup: float, amount: float, force := 9.0) -> void:
	var d := Vector3(dir.x, 0, dir.z).normalized()
	Fx.telegraph_line(self, Vector3(from.x, global_position.y, from.z), d, length, width, windup, func():
		if dead:
			return
		Sfx.play("whoosh", 0.0, 0.7)
		if player != null:
			var rel := player.global_position - from
			rel.y = 0.0
			var along := rel.dot(d)
			var perp := absf(rel.dot(d.cross(Vector3.UP)))
			if along > 0.0 and along < length and perp < width * 0.5 + 0.3:
				_hurt(amount, d, force))


func _proj(from: Vector3, vel: Vector3, amount: float, color: Color, opts := {}) -> void:
	var o := {"radius": 0.3, "cause": boss_name, "life": 5.0}
	for k in opts:
		o[k] = opts[k]
	Projectile.fire(get_parent(), "mob", from, vel, amount * _dmg_mult, color, o)


func _fan(count: int, arc_deg: float, spd: float, amount: float, color: Color, opts := {}) -> void:
	var from := global_position + Vector3(0, body_h * 0.65, 0)
	var aim := (player.global_position + Vector3(0, 1.0, 0) - from)
	aim.y = 0.0
	aim = aim.normalized()
	for i in count:
		var a := deg_to_rad(arc_deg) * (float(i) / maxf(count - 1, 1) - 0.5)
		var v := aim.rotated(Vector3.UP, a) * spd
		_proj(from, v, amount, color, opts)


func _ring(count: int, spd: float, amount: float, color: Color, offset := 0.0, opts := {}) -> void:
	var from := global_position + Vector3(0, 1.0, 0)
	for i in count:
		var a := TAU * float(i) / count + offset
		_proj(from, Vector3(cos(a), 0, sin(a)) * spd, amount, color, opts)


func _summon(kind_id: String, n: int) -> void:
	_spawned = _spawned.filter(func(m): return is_instance_valid(m) and not (m as Mob).dead)
	for i in n:
		if _spawned.size() >= 6:
			return
		var a := randf() * TAU
		var p := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(3.5, 6.0)
		var m: Mob
		if spawn_cb.is_valid():
			m = spawn_cb.call(kind_id, p)
		else:
			m = Mob.make(kind_id, theme, tier, mods)
			get_parent().add_child(m)
			m.global_position = p
			m.wake()
		if m != null:
			_spawned.append(m)
			Fx.ring(get_parent(), p, 1.6, Color("#c8a0ff"), 0.5)
			Style.burst(get_parent(), p + Vector3(0, 0.5, 0), Color("#c8a0ff"), 10, 4.0, 0.1, 0.6)
	Sfx.play("spore", 0.0, 0.7)


# ---------------------------------------------------------------- THE AUDITOR

func _a_slam() -> void:
	_move_mode = "chase"
	if not await _wait(0.5):
		return
	_move_mode = "lock"
	var target := player.global_position
	_set_pose("slam", 1.0)
	_circle(target, 3.6 if phase == 1 else 4.2, 1.0, 34.0)
	if not await _wait(1.3):
		return
	_end_attack(1.6)


func _a_volley() -> void:
	_move_mode = "lock"
	_set_pose("cast", 0.9)
	if not await _wait(0.9):
		return
	_fan(7 if phase == 1 else 11, 70.0, 11.0, 15.0, Color("#b070ff"), {"radius": 0.25})
	Sfx.play("fire", -2.0, 1.4)
	if phase == 2:
		if not await _wait(0.5):
			return
		_fan(7, 90.0, 9.0, 15.0, Color("#ff5a7a"), {"radius": 0.25})
	if not await _wait(0.7):
		return
	_end_attack(1.5)


func _a_summon() -> void:
	_move_mode = "lock"
	_set_pose("cast", 1.0)
	if not await _wait(0.8):
		return
	_summon("skeleton", 3 if phase == 1 else 4)
	if not await _wait(0.8):
		return
	_end_attack(2.2)


func _a_stamp() -> void:
	# giant line slam: a stamp of doom
	_move_mode = "lock"
	var d := dir_to_player()
	_set_pose("slam", 1.1)
	_line(global_position, d, 16.0, 3.4, 1.1, 40.0)
	if not await _wait(1.5):
		return
	_end_attack(1.4)


func _a_redink() -> void:
	_move_mode = "chase"
	_set_pose("cast", 0.6)
	for i in 4:
		if not await _wait(0.55):
			return
		var p := player.global_position + player.velocity * 0.35
		_circle(p, 2.7, 0.9, 26.0, 6.0, Color("#c01a3a"))
		Sfx.play("squelch", -4.0, 1.3)
	if not await _wait(1.2):
		return
	_end_attack(1.4)


# ---------------------------------------------------------------- THE MIMIC KING

func _k_leap() -> void:
	_move_mode = "lock"
	_set_pose("windup", 0.8)
	if not await _wait(0.7):
		return
	var target := player.global_position
	var start := global_position
	_circle(target, 4.0 if phase == 1 else 4.6, 1.0, 36.0, 9.0)
	_set_pose("strike", 1.0)
	var tw := create_tween()
	var steps := 20
	for i in steps + 1:
		var k := float(i) / steps
		var pos := start.lerp(target, k)
		pos.y = start.y + sin(k * PI) * 4.0
		tw.tween_callback(func(): global_position = pos)
		tw.tween_interval(1.0 / steps)
	if not await _wait(1.15):
		return
	global_position.y = start.y
	velocity = Vector3.ZERO
	_end_attack(1.5)


func _k_tongue() -> void:
	_move_mode = "lock"
	var d := dir_to_player()
	_set_pose("windup", 1.0)
	_line(global_position, d, 14.0, 1.8, 1.0, 30.0)
	if phase == 2:
		_line(global_position, d.rotated(Vector3.UP, 0.5), 14.0, 1.6, 1.0, 26.0)
		_line(global_position, d.rotated(Vector3.UP, -0.5), 14.0, 1.6, 1.0, 26.0)
	if not await _wait(1.0):
		return
	_set_pose("strike", 0.4)
	# the tongue itself, for a moment
	var tongue := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.6, 0.4, 14.0)
	tongue.mesh = bm
	tongue.material_override = Fx._unshaded(Color("#e04a68"), 1.0, 1.0)
	get_parent().add_child(tongue)
	tongue.global_position = global_position + d * 7.0 + Vector3(0, 0.8, 0)
	tongue.rotation.y = atan2(d.x, d.z)
	get_tree().create_timer(0.3).timeout.connect(tongue.queue_free)
	if not await _wait(0.8):
		return
	_end_attack(1.7)


func _k_coins() -> void:
	_move_mode = "lock"
	_set_pose("windup", 0.7)
	if not await _wait(0.7):
		return
	_ring(14 if phase == 1 else 20, 7.5, 12.0, Color("#ffd24a"), 0.0, {"radius": 0.22})
	Sfx.play("coin", 0.0, 0.7)
	if not await _wait(0.6):
		return
	_fan(5, 40.0, 13.0, 14.0, Color("#ffd24a"), {"radius": 0.22})
	if not await _wait(0.9):
		return
	_end_attack(1.6)


func _k_bites() -> void:
	_move_mode = "chase"
	for i in 3:
		if not await _wait(0.5):
			return
		_set_pose("windup", 0.4)
		_move_mode = "lock"
		if not await _wait(0.4):
			return
		_set_pose("strike", 0.3)
		_circle(global_position + dir_to_player() * 3.0, 3.0, 0.3, 24.0, 7.0)
		_move_mode = "chase"
	if not await _wait(0.6):
		return
	_end_attack(1.8)


func _k_minis() -> void:
	_move_mode = "lock"
	_set_pose("windup", 1.0)
	if not await _wait(0.9):
		return
	_summon("mimic", 2)
	if not await _wait(0.8):
		return
	_end_attack(2.4)


# ---------------------------------------------------------------- THE LANDLORD

func _l_pound() -> void:
	_move_mode = "lock"
	_set_pose("slam", 1.0)
	_circle(global_position, 4.6, 1.0, 28.0, 9.0)
	if not await _wait(1.1):
		return
	# two shockwave rings that you have to jump
	for i in (2 if phase == 1 else 3):
		_wave(7.0 + 0.0 * i)
		if not await _wait(0.6):
			return
	if not await _wait(0.5):
		return
	_end_attack(1.5)


func _wave(max_r: float) -> void:
	var centre := global_position
	Fx.ring(get_parent(), centre, max_r, Color("#ffcf8a"), 0.9)
	var hit := false
	var tw := create_tween()
	var steps := 18
	for i in steps:
		var r := max_r * float(i + 1) / steps
		tw.tween_callback(func():
			if hit or dead or player == null:
				return
			var dv := player.global_position - centre
			var flat := Vector2(dv.x, dv.z).length()
			if absf(flat - r) < 0.9 and player.global_position.y < global_position.y + 0.6:
				hit = true
				_hurt(22.0, dv.normalized(), 7.0))
		tw.tween_interval(0.05)


func _l_notices() -> void:
	_move_mode = "lock"
	_set_pose("cast", 0.8)
	if not await _wait(0.8):
		return
	for i in 3:
		_fan(5, 60.0, 10.0, 13.0, Color("#f4ecd0"), {"homing": 1.2, "radius": 0.3, "life": 4.0})
		Sfx.play("whoosh", -2.0, 1.5)
		if not await _wait(0.5):
			return
	if not await _wait(0.5):
		return
	_end_attack(1.6)


func _l_charge() -> void:
	_move_mode = "lock"
	var d := dir_to_player()
	_set_pose("windup", 1.0)
	_line(global_position, d, 18.0, 3.0, 1.0, 36.0, 12.0)
	if not await _wait(1.0):
		return
	_set_pose("strike", 0.7)
	_move_mode = "lock"
	var t0 := Time.get_ticks_msec()
	var g0 := _gen
	while (Time.get_ticks_msec() - t0) < 700 and not dead and g0 == _gen:
		velocity.x = d.x * 24.0
		velocity.z = d.z * 24.0
		move_and_slide()
		if player != null and global_position.distance_to(player.global_position) < body_r + 1.0 and player.invuln <= 0.0:
			_hurt(36.0, d, 12.0)
		await get_tree().physics_frame
		if get_slide_collision_count() > 0 and (Time.get_ticks_msec() - t0) > 150:
			break
	velocity = Vector3.ZERO
	if dead or g0 != _gen:
		return
	player.shake = 0.8
	Sfx.play("thud", 3.0, 0.6)
	_set_pose("stun", 1.6)
	stun_t = 0.0
	_move_mode = "none"
	if not await _wait(1.6):
		return
	_end_attack(1.0)


func _l_tenants() -> void:
	_move_mode = "lock"
	_set_pose("cast", 1.0)
	if not await _wait(0.9):
		return
	_summon("mushroom" if theme == "caves" else "skeleton", 2)
	_summon("bat", 2)
	if not await _wait(0.7):
		return
	_end_attack(2.6)


func _l_keys() -> void:
	_move_mode = "lock"
	_set_pose("cast", 1.0)
	if not await _wait(0.8):
		return
	for i in 4:
		_ring(10, 8.0, 12.0, Color("#e6b840"), float(i) * 0.3, {"radius": 0.25})
		Sfx.play("coin", -2.0, 0.6)
		if not await _wait(0.45):
			return
	_end_attack(1.8)


# ---------------------------------------------------------------- THE OVERDUE DRAGON

func _d_breath() -> void:
	_move_mode = "lock"
	var d := dir_to_player()
	_set_pose("breath", 1.0)
	_line(global_position, d, 14.0, 4.2, 1.0, 20.0, 5.0)
	if not await _wait(1.0):
		return
	Sfx.play("fire", 2.0, 0.6)
	# sweeping fire: three bursts across the arc
	for i in 3:
		var ang := (-0.45 + 0.45 * i) * (1.0 if randf() < 0.5 else -1.0)
		var dd := d.rotated(Vector3.UP, ang)
		for k in 6:
			var pos := global_position + dd * (3.0 + k * 2.2)
			Style.burst(get_parent(), pos + Vector3(0, 0.5, 0), Color("#ff7a20"), 8, 3.0, 0.2, 0.7)
		_line_damage_instant(global_position, dd, 14.0, 3.6, 16.0)
		if not await _wait(0.35):
			return
	_fire_patch(player.global_position)
	if not await _wait(0.8):
		return
	_end_attack(1.6)


func _line_damage_instant(from: Vector3, d: Vector3, length: float, width: float, amount: float) -> void:
	if player == null:
		return
	var rel := player.global_position - from
	rel.y = 0.0
	var along := rel.dot(d)
	var perp := absf(rel.dot(d.cross(Vector3.UP)))
	if along > 0.0 and along < length and perp < width * 0.5:
		_hurt(amount, d, 3.0)
		player.add_status("burn", 3.0, 5.0)


func _fire_patch(pos: Vector3) -> void:
	var node := Node3D.new()
	get_parent().add_child(node)
	node.global_position = Vector3(pos.x, global_position.y, pos.z)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.2
	cm.height = 0.05
	disc.mesh = cm
	disc.material_override = Fx._unshaded(Color("#ff6a1a"), 0.65, 2.5)
	node.add_child(disc)
	var l := OmniLight3D.new()
	l.light_color = Color("#ff8a30")
	l.light_energy = 1.4
	l.omni_range = 6.0
	l.position = Vector3(0, 0.6, 0)
	node.add_child(l)
	var tw := node.create_tween()
	for i in 8:
		tw.tween_interval(0.5)
		tw.tween_callback(func():
			if player != null and not player.dead and Vector2(player.global_position.x - node.global_position.x, player.global_position.z - node.global_position.z).length() < 2.2:
				_hurt(9.0, Vector3.UP, 2.0)
				player.add_status("burn", 2.0, 4.0))
	tw.tween_property(disc, "scale", Vector3(0.1, 1, 0.1), 0.4)
	tw.tween_callback(node.queue_free)


func _d_swipe() -> void:
	_move_mode = "lock"
	_set_pose("swipe", 0.9)
	_circle(global_position, 6.0, 0.9, 30.0, 10.0)
	if not await _wait(1.2):
		return
	_end_attack(1.4)


func _d_barrage() -> void:
	_move_mode = "lock"
	_set_pose("breath", 0.8)
	if not await _wait(0.8):
		return
	for i in (4 if phase == 1 else 7):
		var tgt := player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
		var from := global_position + Vector3(0, 3.0, 0) + dir_to_player() * 2.0
		var dv := tgt - from
		var T := 1.0
		var g := 14.0
		var vel := Vector3(dv.x / T, (dv.y + 0.5 * g * T * T) / T, dv.z / T)
		Projectile.fire(get_parent(), "mob", from, vel, 22.0 * _dmg_mult, Color("#ff6a1a"), {"gravity": g, "aoe": 2.8, "status": "burn", "radius": 0.4, "life": 3.0, "cause": boss_name})
		Sfx.play("fire", -2.0)
		if not await _wait(0.45):
			return
	if not await _wait(0.6):
		return
	_end_attack(1.5)


func _d_gust() -> void:
	_move_mode = "lock"
	_set_pose("gust", 1.4)
	if not await _wait(0.5):
		return
	Sfx.play("whoosh", 2.0, 0.5)
	Fx.ring(get_parent(), global_position, 12.0, Color("#e8d8b8"), 0.9)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900 and not dead:
		if player != null and not player.dead:
			var away := player.global_position - global_position
			away.y = 0.0
			if away.length() < 13.0:
				player._kb = away.normalized() * 11.0
				player.add_status("slow", 1.5, 0.0)
		await get_tree().physics_frame
	if not await _wait(0.4):
		return
	_end_attack(1.2)


func _d_lavarain() -> void:
	_move_mode = "lock"
	_set_pose("roar", 1.0)
	if not await _wait(0.6):
		return
	for i in 7:
		var p := player.global_position + player.velocity * 0.4 + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
		_circle(p, 2.6, 1.0, 24.0, 7.0, Color("#ff6a1a"))
		if not await _wait(0.4):
			return
	if not await _wait(1.0):
		return
	_end_attack(1.8)


# ---------------------------------------------------------------- pacifying the dragon

func _enable_pacify() -> void:
	if _pacify_node != null:
		return
	_can_pacify = true
	_pacify_node = Interactable.make(get_parent(), global_position + Vector3(3.0, 1.0, 0), "Hand over the parcel (it's HIS, actually)", Callable(self, "_do_pacify"), 4.5)
	if player != null and player.ui != null:
		player.ui.toast("The dragon is glaring at your parcel... is it HIS?!", Color("#ffd89a"))


func _do_pacify(_by: Node) -> void:
	if _pacified or dead:
		return
	_pacified = true
	_gen += 1
	busy = true
	_move_mode = "none"
	if _pacify_node != null:
		_pacify_node.queue_free()
	_cancel_attack()
	_set_pose("roar", 2.0)
	Sfx.play("deliver")
	Game.moment("Delivered a parcel to a dragon MID-FIGHT")
	pacified.emit(self)
	hp = 1.0
	await get_tree().create_timer(1.8).timeout
	if not dead:
		_die({"source": "pacified"})


# ---------------------------------------------------------------- damage rules for bosses

func take_damage(amount: float, dir: Vector3, info := {}) -> float:
	if _pacified or dead:
		return 0.0
	if not awake:
		wake()
		return 0.0
	var dealt := super.take_damage(amount, dir, info)
	# stagger: burst damage briefly staggers the boss
	_stagger += amount
	_stagger_t = 4.0
	if _stagger >= max_hp * 0.14 and busy and not dead and _intro <= 0.0:
		_stagger = 0.0
		_cancel_attack_busy()
	if boss_id == "dragon" and phase == 1 and hp < max_hp * 0.7 and not _can_pacify:
		_enable_pacify()
	return dealt


func _cancel_attack_busy() -> void:
	_gen += 1
	stun_t = 1.4
	busy = false
	_move_mode = "chase"
	_atk_cd = 1.4
	_pose = "stun"
	if player != null and player.ui != null:
		player.ui.toast("STAGGERED!", Color("#ffe97a"))
	FloatText.spawn(get_parent(), global_position + Vector3(0, body_h + 0.8, 0), "STAGGERED!", Color("#ffe97a"), 1.4)


func stun(t: float) -> void:
	if dead:
		return
	if t >= 1.0:
		_cancel_attack_busy()


func _animate(pose_name: String, k: float, speed01_override := -1.0) -> void:
	if pose_name == "stun":
		_boss_anim("stun", 0.0)


func _death_anim() -> void:
	if model == null:
		queue_free()
		return
	for i in 5:
		Fx.debris(get_parent(), global_position + Vector3(randf_range(-1.5, 1.5), randf_range(0.5, body_h), randf_range(-1.5, 1.5)), _death_colors(), 10, 1.8)
	var tw := create_tween()
	tw.tween_property(model, "scale", model.scale * 1.08, 0.2)
	tw.tween_property(model, "rotation:z", 0.4, 0.6)
	tw.parallel().tween_property(model, "scale", model.scale * Vector3(1.0, 0.05, 1.0), 1.2).set_delay(0.3)
	tw.tween_callback(queue_free)
