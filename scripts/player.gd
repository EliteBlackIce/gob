class_name Player
extends CharacterBody3D
## The goblin, in first person: fast enough to flee, fragile enough to make it interesting.
## Modes: "hub" (tavern, safe), "route" (island parcel run, parcel in hands), "dungeon" (full combat).

signal died(cause: String)
signal killed_mob(mob: Mob)

const GRAVITY := 24.0
const MOUSE_SENS := 0.0028
const EYE_HEIGHT := 1.36
const ROLL_TIME := 0.42
const IFRAMES := 0.32

var island: Node = null           # set on the island route: height queries, water, enemies
var mode := "hub"
var ui: UI
var cam_dist := 0.0
var hp := 100.0
var max_hp := 100.0
var stats: Dictionary = {}
var frozen := false
var dead := false
var carried: Parcel = null
var bottles := 0
var second_wind_used := false
var pocket_used := false
var forged_used := false
var revive_used := false
var in_water := false
var speed01 := 0.0
var shake := 0.0
var invuln := 0.0
var blocking := false
var parcel_cond := 100.0          # dungeon parcel condition (%), drops when you take hits
var statuses := {}                # name -> {t, dps}
var combo := 0
var kills := 0
var xp_run := 0
var copper_run := 0
var dmg_dealt := 0.0
var dmg_taken := 0.0
var buffs := {}                   # shrine blessings: stat -> value

var model: Node3D
var rig: Node3D
var arm: SpringArm3D
var cam: Camera3D
var view: Viewmodel
var motes: CPUParticles3D
var cam_override: Node3D = null
var yaw := 0.0
var pitch := 0.0
var interact_target: Interactable = null

var _anim_t := 0.0
var _roll_t := -1.0
var _roll_cd := 0.0
var _roll_dir := Vector3.ZERO
var _kick_cd := 0.0
var _throw_cd := 0.0
var _grog_cd := 0.0
var _cast_cd := 0.0
var _atk_cd := 0.0
var _atk_t := -1.0
var _atk_dur := 0.5
var _atk_hit := false
var _atk_type := "overhead"
var _combo_t := 0.0
var _queued := false
var _launch_t := 0.0
var _slap_hold := 0.0
var _drown_t := 0.0
var _prev_vy := 0.0
var _was_in_water := false
var _kick_anim := 0.0
var _step_t := 0.0
var _fov_kick := 0.0
var _bob_t := 0.0
var _block_t := 0.0
var _heal_pool := 0.0
var _status_t := 0.0
var _gear_rev := -1
var _pigeon_t := 3.0
var _kb := Vector3.ZERO
var _hit_react := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 16
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(52.0)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.45
	cs.shape = cap
	cs.position = Vector3(0, 0.73, 0)
	add_child(cs)
	model = GoblinModel.build()
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = 2          # invisible to the first-person camera, still casts shadows
	rig = Node3D.new()
	rig.top_level = true
	add_child(rig)
	arm = SpringArm3D.new()
	arm.spring_length = 0.0
	arm.collision_mask = 1
	arm.margin = 0.2
	rig.add_child(arm)
	arm.add_excluded_object(get_rid())
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.05
	cam.far = 500.0
	cam.cull_mask = 0xFFFFF & ~2
	arm.add_child(cam)
	cam.current = true
	view = Viewmodel.new()
	cam.add_child(view)
	motes = Atmos.motes(cam)
	rig.global_position = global_position + Vector3(0, EYE_HEIGHT, 0)
	add_to_group("player")
	refresh_stats(true)


func refresh_stats(full_heal := false) -> void:
	var frac := hp / maxf(max_hp, 1.0)
	stats = Stats.compute()
	for k in buffs:
		stats[k] = float(stats.get(k, 0.0)) + float(buffs[k])
	stats["dmg"] = stats["w_dmg"] * (1.0 + stats["dmg_pct"] / 100.0)
	max_hp = float(stats["max_hp"])
	hp = max_hp if full_heal else clampf(frac * max_hp, 1.0, max_hp)
	_gear_rev = Game.gear_rev
	if view != null:
		view.set_weapon(Game.equipped.get("weapon"))


func setup_for_run(mode_name: Variant) -> void:
	# accepts the old bool too: true = island route, false = hub
	if typeof(mode_name) == TYPE_BOOL:
		mode_name = "route" if mode_name else "hub"
	mode = str(mode_name)
	buffs = {}
	refresh_stats(true)
	bottles = int(stats["bottles"]) if mode != "hub" else 0
	parcel_cond = 100.0
	statuses = {}
	second_wind_used = false
	revive_used = false
	pocket_used = false
	forged_used = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _locked():
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)


func _locked() -> bool:
	return frozen or dead or (ui != null and ui.modal_open)


func _forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func combat_enabled() -> bool:
	return mode == "dungeon" or mode == "hub"


func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if dead:
		return
	if _gear_rev != Game.gear_rev:
		refresh_stats()
	_roll_cd = maxf(0.0, _roll_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	_grog_cd = maxf(0.0, _grog_cd - delta)
	_cast_cd = maxf(0.0, _cast_cd - delta)
	_atk_cd = maxf(0.0, _atk_cd - delta)
	_combo_t = maxf(0.0, _combo_t - delta)
	_hit_react = maxf(0.0, _hit_react - delta * 4.0)
	invuln = maxf(0.0, invuln - delta)
	if _combo_t <= 0.0:
		combo = 0
	_anim_t += delta
	var locked := _locked()
	_tick_vitals(delta)

	var in2 := Vector2.ZERO
	if not locked:
		in2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(in2.x, 0, in2.y).rotated(Vector3.UP, yaw)

	var speed := 6.2 * float(stats["move_mult"])
	if mode == "route":
		speed *= float(Game.mandate["speed"])
	if carried != null and carried.trait_id == "heavy":
		speed *= 0.8
	if in_water:
		speed *= 0.65
	if blocking:
		speed *= 0.5
	if _atk_t >= 0.0:
		speed *= 0.72
	if statuses.has("slow"):
		speed *= 0.7

	var vy := velocity.y
	if _launch_t > 0.0:
		_launch_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
	elif _roll_t >= 0.0:
		_roll_t += delta
		var k := _roll_t / ROLL_TIME
		var sp := lerpf(14.5, 6.0, k * k)
		velocity.x = _roll_dir.x * sp
		velocity.z = _roll_dir.z * sp
		if _roll_t >= ROLL_TIME:
			_roll_t = -1.0
	else:
		var accel := 60.0 if is_on_floor() else 22.0
		velocity.x = move_toward(velocity.x, dir.x * speed + _kb.x, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed + _kb.z, accel * delta)
	_kb = _kb.move_toward(Vector3.ZERO, 30.0 * delta)

	if not locked and Input.is_action_just_pressed("dash") and _roll_cd <= 0.0 and _roll_t < 0.0 and _launch_t <= 0.0:
		_start_roll(dir)

	vy -= GRAVITY * delta
	if is_on_floor() and vy < 0.0:
		vy = -1.0
	if not locked and Input.is_action_just_pressed("jump") and is_on_floor() and _launch_t <= 0.0:
		vy = 7.0
		if carried != null and carried.trait_id == "glass":
			carried.damage(3.0, "jumped like a fool")
	velocity.y = vy

	_prev_vy = velocity.y
	move_and_slide()
	if is_on_floor() and _prev_vy < -10.0:
		_land(-_prev_vy)
	if is_on_floor() and _launch_t < 0.35:
		_launch_t = 0.0

	_water_check(delta)
	if mode == "route" and global_position.y < -14.0:
		die("fell off the edge of the world")
	if mode == "dungeon" and global_position.y < -8.0:
		die("fell out of the dungeon (it was a very small hole)")
	_footsteps(delta)

	var hspeed := Vector2(velocity.x, velocity.z).length()
	speed01 = clampf(hspeed / 6.5, 0.0, 1.0) if is_on_floor() else 0.4
	model.rotation.y = yaw + PI
	GoblinModel.animate(model, speed01, _anim_t, carried != null)
	if _kick_anim > 0.0:
		_kick_anim -= delta
		GoblinModel.pose_kick(model, clampf(_kick_anim / 0.25, 0.0, 1.0))
	if _atk_t >= 0.0:
		GoblinModel.pose_swing(model, clampf(_atk_t / _atk_dur, 0.0, 1.0))
	var roll_k := clampf(_roll_t / ROLL_TIME, 0.0, 1.0) if _roll_t >= 0.0 else 0.0
	view.set_state(speed01, carried != null, bottles > 0 and mode != "hub", delta, blocking, roll_k)

	if not locked:
		_actions(delta)
		_scan_interactables()
	else:
		blocking = false
		interact_target = null


func _tick_vitals(delta: float) -> void:
	if _heal_pool > 0.0:
		var h := minf(_heal_pool, max_hp * 0.4 * delta)
		_heal_pool -= h
		heal(h, false)
	if mode == "dungeon" and float(stats.get("regen", 0.0)) > 0.0:
		heal(float(stats["regen"]) * delta, false)
	_status_t -= delta
	for s in statuses.keys():
		statuses[s]["t"] -= delta
		if statuses[s]["t"] <= 0.0:
			statuses.erase(s)
	if _status_t <= 0.0:
		_status_t = 0.5
		for s2 in statuses.keys():
			var st: Dictionary = statuses[s2]
			if float(st["dps"]) > 0.0:
				_raw_damage(float(st["dps"]) * 0.5, str(s2))
	if _atk_t >= 0.0:
		_atk_t += delta
		if not _atk_hit and _atk_t >= _atk_dur * 0.42:
			_atk_hit = true
			_resolve_swing()
		if _atk_t >= _atk_dur:
			_atk_t = -1.0
			if _queued:
				_queued = false
				_try_attack()


func heal(amount: float, show := true) -> void:
	if dead or amount <= 0.0:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if show and hp - before >= 1.0 and ui != null:
		FloatText.spawn(get_parent(), global_position + Vector3(0, 2.0, 0), "+%d" % int(round(hp - before)), Color("#7aff7a"), 0.9)


func add_status(status_name: String, secs: float, dps: float) -> void:
	if mode == "hub" or dead:
		return
	if statuses.has(status_name):
		statuses[status_name]["t"] = maxf(statuses[status_name]["t"], secs)
		statuses[status_name]["dps"] = maxf(statuses[status_name]["dps"], dps)
	else:
		statuses[status_name] = {"t": secs, "dps": dps}


# ---------------------------------------------------------------- movement helpers

func _start_roll(dir: Vector3) -> void:
	var d := dir
	if d.length() < 0.1:
		d = _forward()
	_roll_dir = d.normalized()
	_roll_t = 0.0
	_roll_cd = 1.0 * float(stats["roll_cd_mult"]) + ROLL_TIME
	invuln = maxf(invuln, IFRAMES + (0.08 if Game.has_skill("roll_master") else 0.0))
	_fov_kick = 16.0
	blocking = false
	_atk_t = -1.0
	Sfx.play("roll", -2.0, 1.1)
	Style.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color("#e8d8a8"), 8, 3.0, 0.14, 0.5)
	if Stats.has_unique(stats, "roll_fast"):
		Style.burst(get_parent(), global_position + Vector3(0, 0.2, 0), Color("#ffd24a"), 16, 5.0, 0.1, 0.8)
	if carried != null and carried.trait_id == "glass":
		carried.damage(6.0, "rolled to pieces")


func is_rolling() -> bool:
	return _roll_t >= 0.0


func _water_check(delta: float) -> void:
	in_water = false
	if island == null:
		return
	var depth: float = -float(island.height_at(global_position.x, global_position.z))
	in_water = depth > 0.12 and global_position.y < 0.5
	if in_water and not _was_in_water:
		Sfx.play("splash", -6.0)
		Style.burst(get_parent(), global_position, Color("#bdf2ff"), 10, 4.0, 0.12, 0.6)
	_was_in_water = in_water
	if depth > 1.5:
		_drown_t += delta
		if _drown_t > 0.6 and _drown_t - delta <= 0.6:
			ui.toast("The sea is NOT a road!", Color("#9fe6ff"))
		if _drown_t > 1.5:
			die("swam into the sea like it owed them money")
	else:
		_drown_t = maxf(0.0, _drown_t - delta * 2.0)


func _footsteps(delta: float) -> void:
	var hs := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or hs < 2.0 or _launch_t > 0.0 or _roll_t >= 0.0:
		_step_t = 0.0
		return
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = 0.42 * 6.2 / maxf(hs, 3.0)
		Sfx.play("splash" if in_water else "step", -14.0 if in_water else -12.0, randf_range(0.85, 1.2))


func _land(impact: float) -> void:
	shake = maxf(shake, 0.2)
	Sfx.play("thud", -4.0)
	Style.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color("#e8d8a8"), 8, 2.5, 0.14, 0.5)
	if carried != null and carried.trait_id == "glass":
		carried.damage(impact * 1.1, "landed on its face")


# ---------------------------------------------------------------- actions

func _actions(delta: float) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var armed_ok := combat_enabled() and carried == null and captured
	var wants_block := armed_ok and Input.is_action_pressed("block") and _atk_t < 0.0 and _roll_t < 0.0
	if wants_block and not blocking:
		_block_t = 0.0
	blocking = wants_block
	if blocking:
		_block_t += delta
	if armed_ok and Input.is_action_just_pressed("attack"):
		if _atk_t >= 0.0:
			if _atk_t > _atk_dur * 0.55:
				_queued = true
		else:
			_try_attack()

	if captured:
		if Input.is_action_just_pressed("bottle") or Input.is_action_just_pressed("throw"):
			_throw_bottle()
		elif mode == "route" and Input.is_action_just_pressed("attack") and carried != null:
			_throw_bottle()
		if Input.is_action_just_pressed("kick") and _kick_cd <= 0.0 and _roll_t < 0.0:
			_do_kick()
		if Input.is_action_just_pressed("grog") and _grog_cd <= 0.0:
			_drink_grog()
		if Input.is_action_just_pressed("ability") and _cast_cd <= 0.0 and mode == "dungeon":
			_holler()

	if Input.is_action_just_pressed("toss") and carried != null and mode == "route":
		carried.toss(self)

	if Input.is_action_pressed("slap") and carried != null and Game.has_skill("slap"):
		_slap_hold += delta
		if _slap_hold >= 0.5:
			_slap_hold = -0.5
			view.play_slap()
			carried.slap()
	else:
		_slap_hold = 0.0

	if Input.is_action_just_pressed("interact") and interact_target != null:
		interact_target.activate(self)

	if Stats.has_unique(stats, "pigeon") and mode == "dungeon":
		_pigeon_t -= delta
		if _pigeon_t <= 0.0:
			_pigeon_t = 3.2
			_pigeon_strike()


func _try_attack() -> void:
	if _atk_cd > 0.0 or _atk_t >= 0.0 or blocking:
		return
	var rate := float(stats["atk_rate"])
	_atk_dur = clampf(1.0 / rate, 0.26, 1.3)
	_atk_cd = _atk_dur * 0.92
	_atk_t = 0.0
	_atk_hit = false
	_atk_type = str(stats["swing"])
	_queued = false
	combo = (combo + 1) if _combo_t > 0.0 else 1
	if combo > 3:
		combo = 1
	_combo_t = _atk_dur + 0.55
	view.play_attack(_atk_type, _atk_dur, combo % 2 == 0)
	Sfx.play("swing", -6.0, (1.25 - float(stats["speed"]) * 0.12) + (0.15 if combo == 3 else 0.0))


func _aim() -> Vector3:
	return -cam.global_basis.z


func _resolve_swing() -> void:
	var heavy := combo == 3
	var mult := 1.35 if heavy else 1.0
	if _atk_type == "shoot":
		_fire_staple(mult)
		return
	var fwd := _forward()
	var reach := float(stats["reach"]) + (0.35 if heavy else 0.0)
	var arc := float(stats["arc"]) * (1.15 if heavy else 1.0)
	var cos_half := cos(deg_to_rad(arc * 0.5))
	var origin := global_position
	var hits := 0
	var targets: Array = []
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob == null or mob.dead:
			continue
		var dv := mob.global_position - origin
		dv.y = 0.0
		var dist := dv.length()
		if dist > reach + mob.body_r * mob.base_scale:
			continue
		if dist > 0.45 and fwd.dot(dv / dist) < cos_half:
			continue
		var dy: float = mob.global_position.y + mob.body_h * 0.5 - (global_position.y + 0.9)
		if absf(dy) > 2.2 + mob.body_h * 0.5:
			continue
		targets.append(mob)
	for e in get_tree().get_nodes_in_group("enemy"):
		var dv2: Vector3 = (e as Node3D).global_position - origin
		dv2.y = 0.0
		if dv2.length() < reach + 0.5 and fwd.dot(dv2.normalized()) > cos_half:
			e.hit(fwd, 1.0 + (1.0 if heavy else 0.0))
			hits += 1
	for b in get_tree().get_nodes_in_group("breakable"):
		var dv3: Vector3 = (b as Node3D).global_position - origin
		dv3.y = 0.0
		if dv3.length() < reach + 0.5 and fwd.dot(dv3.normalized()) > cos_half - 0.2:
			b.smash(fwd)
			hits += 1
	for mob2 in targets:
		_hit_mob(mob2, mult, heavy)
		hits += 1
	var aoe := float(stats.get("aoe", 0.0))
	if aoe > 0.0:
		# stamp hammer: a ground slam that hits everything around the point of impact
		var centre := origin + fwd * (reach * 0.6)
		Fx.ring(get_parent(), centre, aoe, Color("#ffd24a"), 0.35)
		shake = maxf(shake, 0.25)
		for m2 in get_tree().get_nodes_in_group("mob"):
			var mm := m2 as Mob
			if mm != null and not mm.dead and not targets.has(mm) and mm.global_position.distance_to(centre) < aoe:
				_hit_mob(mm, mult * 0.6, false)
				hits += 1
	if Stats.has_unique(stats, "shockwave"):
		Fx.ring(get_parent(), origin + fwd * 1.6, 4.5, Color("#ffa42a"), 0.5)
		for m3 in get_tree().get_nodes_in_group("mob"):
			var m4 := m3 as Mob
			if m4 != null and not m4.dead and not targets.has(m4) and m4.global_position.distance_to(origin + fwd * 2.0) < 4.2:
				_hit_mob(m4, 0.55, false)
	if hits > 0:
		shake = maxf(shake, 0.18 if not heavy else 0.4)
		if ui != null:
			ui.hitstop(0.045 if not heavy else 0.08)
		view.recoil()
	elif heavy:
		shake = maxf(shake, 0.1)


func roll_damage(mult := 1.0) -> Dictionary:
	var base := float(stats["dmg"]) * mult * randf_range(0.92, 1.08)
	if Game.has_skill("berserker") and hp < max_hp * 0.4:
		base *= 1.3
	var crit := randf() * 100.0 < minf(float(stats["crit"]), 100.0)
	if crit:
		base *= float(stats["crit_dmg"]) / 100.0
	return {"amount": base, "crit": crit}


func _hit_mob(mob: Mob, mult: float, heavy: bool, source := "melee") -> void:
	var r := roll_damage(mult)
	var amount: float = r["amount"]
	var crit: bool = r["crit"]
	var dir := (mob.global_position - global_position)
	dir.y = 0.0
	dir = dir.normalized()
	var knock := float(stats["knock_base"]) * (1.0 + float(stats["knock"]) / 100.0) * (1.4 if heavy else 1.0)
	var info := {"crit": crit, "knock": knock, "source": source}
	if randf() * 100.0 < float(stats["burn"]):
		info["burn"] = amount * 0.35
	if randf() * 100.0 < float(stats["poison"]) or (crit and Stats.has_unique(stats, "poison_crit")):
		info["poison"] = amount * 0.3
	if randf() * 100.0 < float(stats["stun"]) or (crit and Stats.has_unique(stats, "stun_crit")):
		info["stun"] = 1.4
	if Stats.has_unique(stats, "execute") and mob.hp - amount < mob.max_hp * 0.2 and not mob.is_boss:
		amount = mob.hp + 1.0
	var dealt := mob.take_damage(amount, dir, info)
	dmg_dealt += dealt
	if float(stats["lifesteal"]) > 0.0 and mode == "dungeon":
		heal(dealt * float(stats["lifesteal"]) / 100.0)
	if Stats.has_unique(stats, "chain") and source == "melee":
		for o in get_tree().get_nodes_in_group("mob"):
			var om := o as Mob
			if om != null and om != mob and not om.dead and om.global_position.distance_to(mob.global_position) < 5.0:
				om.take_damage(amount * 0.6, (om.global_position - mob.global_position).normalized(), {"source": "chain", "knock": 1.0})
				Fx.hit(get_parent(), om.global_position + Vector3(0, 1.0, 0), Color("#8ad8ff"), false)
				break
	if mob.dead:
		kills += 1
		killed_mob.emit(mob)
		if Stats.has_unique(stats, "coin_kill"):
			var coins := int(2 + mob.xp_value)
			copper_run += coins
			Game.copper += coins
			Style.burst(get_parent(), mob.global_position + Vector3(0, 1.0, 0), Color("#ffd24a"), 10, 5.0, 0.1, 0.7)
			Sfx.play("coin", -8.0)
	if crit and ui != null:
		ui.hitstop(0.05)


func _fire_staple(mult: float) -> void:
	var r := roll_damage(mult)
	var aim := _aim()
	var from := cam.global_position + aim * 0.7 + cam.global_basis.x * 0.15 - cam.global_basis.y * 0.12
	var info := {"crit": r["crit"], "knock": 1.5, "source": "ranged"}
	if randf() * 100.0 < float(stats["burn"]):
		info["burn"] = r["amount"] * 0.35
	if randf() * 100.0 < float(stats["poison"]):
		info["poison"] = r["amount"] * 0.3
	Sfx.play("arrow", -5.0, 1.5)
	Projectile.fire(get_parent(), "player", from, aim * 34.0, r["amount"], Color("#d8dce8"),
		{"pierce": Stats.has_unique(stats, "pierce"), "radius": 0.12, "life": 1.0, "info": info})
	shake = maxf(shake, 0.05)
	view.recoil()


func _pigeon_strike() -> void:
	var best: Mob = null
	var bd := 9.0
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob == null or mob.dead or not mob.awake:
			continue
		var dd := mob.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			best = mob
	if best == null:
		return
	Fx.hit(get_parent(), best.global_position + Vector3(0, 1.2, 0), Color("#c8c8d8"), true)
	_hit_mob(best, 0.8, false, "pigeon")
	FloatText.spawn(get_parent(), best.global_position + Vector3(0, 2.4, 0), "COO!", Color("#d8d8e8"), 0.9)


func _throw_bottle() -> void:
	if bottles <= 0 or _throw_cd > 0.0 or mode == "hub":
		return
	bottles -= 1
	_throw_cd = 0.5
	view.play_throw()
	var aim := _aim()
	var v := (aim + Vector3.UP * 0.2).normalized() * 17.0
	var heavy := Game.has_skill("bomb_maker")
	var b := Bottle.throw(get_parent(), cam.global_position + aim * 0.5 + Vector3(-0.1, -0.15, 0), v + velocity * 0.3, heavy)
	b.damage = (22.0 + 4.0 * Game.level) * (1.0 + float(stats["throw_dmg"]) / 100.0)


func _do_kick() -> void:
	_kick_cd = 0.7
	_kick_anim = 0.25
	view.play_kick()
	Sfx.play("whoosh", -2.0, 1.6)
	var fwd: Vector3 = _forward()
	var boot := 2.0 if Game.has_skill("power_boot") else 1.0
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position - global_position
		var flat := Vector3(d.x, 0, d.z)
		if flat.length() < 2.8 and d.y < 3.0 and flat.normalized().dot(fwd) > 0.25:
			e.hit(fwd, boot)
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob == null or mob.dead:
			continue
		var dv := mob.global_position - global_position
		dv.y = 0.0
		if dv.length() < 2.4 + mob.body_r and dv.normalized().dot(fwd) > 0.2:
			mob.take_damage(float(stats["dmg"]) * 0.6 * boot, fwd, {"knock": 9.0 * boot, "stun": 0.9 * boot, "source": "kick"})
			if mob.is_boss and boot > 1.5:
				mob.stun(2.4)
			shake = maxf(shake, 0.2)
	for b in get_tree().get_nodes_in_group("breakable"):
		var d2: Vector3 = (b as Node3D).global_position - global_position
		d2.y = 0.0
		if d2.length() < 2.6 and d2.normalized().dot(fwd) > 0.2:
			b.smash(fwd)


func _drink_grog() -> void:
	if Game.grog_stock <= 0:
		if ui != null:
			ui.toast("Out of grog. The tavern has more (for a price).", Color("#ffd89a"))
		_grog_cd = 0.6
		return
	if hp >= max_hp - 1.0 and mode != "hub":
		return
	Game.grog_stock -= 1
	_grog_cd = 1.0
	view.play_drink()
	Sfx.play("potion", -2.0)
	var boost := 0.55 if Game.has_skill("grog_lover") else 0.4
	_heal_pool += max_hp * boost
	if ui != null:
		ui.toast("Glug glug. (+%d%% HP)" % int(boost * 100.0), Color("#9dffa0"))


func _holler() -> void:
	_cast_cd = 18.0 - (4.0 if Game.has_skill("roll_master") else 0.0)
	view.play_cast()
	Sfx.play("roar", -2.0, 1.4)
	Fx.ring(get_parent(), global_position, 6.0, Color("#ffe97a"), 0.5, 0.4)
	shake = maxf(shake, 0.5)
	FloatText.spawn(get_parent(), global_position + Vector3(0, 2.2, 0), "EXCUSE ME??", Color("#ffe97a"), 1.4)
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob != null and not mob.dead and mob.global_position.distance_to(global_position) < 6.5:
			var dir := (mob.global_position - global_position).normalized()
			mob.take_damage(float(stats["dmg"]) * 0.5, dir, {"knock": 9.0, "stun": 2.2, "source": "holler"})


func cooldowns() -> Dictionary:
	return {"roll": _roll_cd, "roll_max": maxf(1.0 * float(stats["roll_cd_mult"]) + ROLL_TIME, 0.1), "holler": _cast_cd, "holler_max": 18.0,
		"kick": _kick_cd, "grog": _grog_cd}


func _scan_interactables() -> void:
	var best: Interactable = null
	var best_d := 9999.0
	var eye := cam.global_position
	for n in get_tree().get_nodes_in_group("interactable"):
		var it := n as Interactable
		if it == null or not it.enabled or not it.is_inside_tree():
			continue
		var to := it.global_position - eye
		var d := to.length()
		if d < it.radius + 0.4 and d < best_d:
			best = it
			best_d = d
	interact_target = best


func grab(p: Parcel) -> void:
	if carried != null:
		return
	carried = p
	p.player = self
	p.island = island
	p.state = "carried"
	p.held()
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	view.hold.add_child(p)
	p.position = Vector3.ZERO
	p.rotation = Vector3.ZERO
	p.scale = Vector3.ONE * 0.5
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- taking damage

## Returns "hit", "blocked", "parried", "dodged" or "ignored".
func take_hit(from_dir: Vector3, force: float, dmg_amount: float, cause: String, src: Node = null) -> String:
	if dead or mode == "hub":
		return "ignored"
	if _roll_t >= 0.0 and invuln > 0.0:
		_dodge_feedback()
		return "dodged"
	if invuln > 0.0:
		return "ignored"
	var amount := float(dmg_amount)
	var dir := from_dir.normalized() if from_dir.length() > 0.01 else Vector3.BACK
	if blocking:
		var facing := _forward().dot(-dir) > -0.15
		if facing:
			if _block_t < 0.25:
				Sfx.play("parry", 0.0)
				Fx.hit(get_parent(), cam.global_position + _aim() * 1.2, Color("#9fe6ff"), true)
				FloatText.spawn(get_parent(), cam.global_position + _aim() * 1.5, "PARRY!", Color("#9fe6ff"), 1.4)
				if src is Mob:
					(src as Mob).stun(1.8)
					(src as Mob).take_damage(float(stats["dmg"]) * 0.8, -dir, {"knock": 6.0, "source": "parry"})
				invuln = 0.4
				shake = 0.3
				if ui != null:
					ui.hitstop(0.1)
				return "parried"
			var red := 0.8 if str(stats["weapon"]) == "pan" else 0.65
			amount *= (1.0 - red)
			Sfx.play("block", 0.0)
			Fx.hit(get_parent(), cam.global_position + _aim() * 1.2, Color("#d8dce8"), false)
			_kb = dir * force * 0.9
			shake = maxf(shake, 0.15)
	amount *= (1.0 - float(stats["armor_red"]))
	return _apply_hit(dir, force, amount, cause, src)


func _dodge_feedback() -> void:
	if Game.has_skill("perfect_dodge"):
		_roll_cd = 0.0
	if randf() < 0.3:
		FloatText.spawn(get_parent(), global_position + Vector3(0, 2.0, 0), "DODGE", Color("#9fe6ff"), 0.9)


func _apply_hit(dir: Vector3, force: float, amount: float, cause: String, src: Node) -> String:
	var shown := maxf(1.0, amount)
	hp -= shown
	dmg_taken += shown
	if mode == "dungeon":
		var pad := 0.65 if Game.has_skill("padding") else 1.0
		parcel_cond = maxf(0.0, parcel_cond - shown * 0.12 * pad)
	if carried != null:
		carried.damage(18.0, "got in the way of a hit")
	FloatText.spawn(get_parent(), global_position + Vector3(0, 1.9, 0), str(int(round(shown))), Color("#ff6a5a"), 1.1)
	if hp <= 0.0:
		if Game.has_skill("second_wind") and not second_wind_used:
			second_wind_used = true
			hp = max_hp * 0.4
			if ui != null:
				ui.toast("SECOND WIND! (barely)", Color("#9dffa0"))
		elif Stats.has_unique(stats, "revive") and not revive_used:
			revive_used = true
			hp = max_hp * 0.5
			if ui != null:
				ui.toast("The Duck of Second Chances says: QUACK. (revived)", Color("#ffe97a"))
			Fx.ring(get_parent(), global_position, 5.0, Color("#ffe97a"), 0.6)
		else:
			die(cause, dir * force)
			return "hit"
	Sfx.play("hurt")
	shake = maxf(shake, 0.4)
	invuln = 0.55 if mode == "dungeon" else 1.0
	_hit_react = 1.0
	if ui != null:
		ui.flash_damage(clampf(0.25 + shown / max_hp, 0.3, 0.7))
		ui.hitstop(0.06)
	if mode == "route":
		launch(dir * force + Vector3.UP * force * 0.5)
	else:
		_kb = dir * force * 1.1
		_atk_t = -1.0
		_queued = false
	var thorn := float(stats["thorns"])
	if src is Mob and thorn > 0.0:
		(src as Mob).take_damage(thorn, -dir, {"knock": 2.0, "source": "thorns"})
	return "hit"


func _raw_damage(amount: float, cause: String) -> void:
	if dead:
		return
	hp -= amount
	dmg_taken += amount
	FloatText.spawn(get_parent(), global_position + Vector3(0, 1.9, 0), str(int(round(amount))), Color("#ff9a3a") if cause == "burn" else Color("#7aff6a"), 0.8)
	if hp <= 0.0:
		die("was slowly %s" % ("roasted" if cause == "burn" else "poisoned"))


func launch(v: Vector3) -> void:
	velocity = v
	_launch_t = 0.6
	_roll_t = -1.0


func die(cause: String, impulse := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	model.visible = false
	view.visible = false
	motes.emitting = false
	if carried != null:
		carried.visible = false
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var rd := Ragdoll.spawn(get_parent(), global_position, impulse + Vector3.UP * 3.0)
	cam_override = rd.torso
	cam.cull_mask = 0xFFFFF
	arm.spring_length = 4.2
	Sfx.play("hurt", 2.0, 0.7)
	died.emit(cause)


func _update_camera(delta: float) -> void:
	if dead and cam_override != null and is_instance_valid(cam_override):
		var tp := cam_override.global_position + Vector3(0, 0.5, 0)
		rig.global_position = rig.global_position.lerp(tp, 1.0 - exp(-8.0 * delta))
		rig.rotation = Vector3(-0.45, yaw, 0.0)
		cam.fov = 70.0
		return
	var bob := 0.0
	if is_on_floor():
		_bob_t += delta * (7.0 + 6.0 * speed01)
		bob = sin(_bob_t) * 0.035 * speed01
	var target := global_position + Vector3(0, EYE_HEIGHT + bob, 0)
	if _roll_t >= 0.0:
		target.y -= 0.35 * sin(clampf(_roll_t / ROLL_TIME, 0.0, 1.0) * PI)
	rig.global_position = target
	shake = maxf(0.0, shake - delta * 1.4)
	var roll := sin(_bob_t * 0.5) * 0.012 * speed01
	var pitch_extra := 0.0
	if _roll_t >= 0.0:
		var rk := clampf(_roll_t / ROLL_TIME, 0.0, 1.0)
		pitch_extra = -sin(rk * PI) * 0.35
		roll += sin(rk * TAU) * 0.08
	if _atk_t >= 0.0:
		var ak := clampf(_atk_t / _atk_dur, 0.0, 1.0)
		pitch_extra += (sin(ak * PI) * 0.03) * (2.0 if combo == 3 else 1.0)
		roll += sin(ak * PI) * 0.025 * (1.0 if combo % 2 == 0 else -1.0)
	roll += _hit_react * sin(_anim_t * 40.0) * 0.03
	rig.rotation = Vector3(pitch + pitch_extra, yaw, roll)
	cam.h_offset = randf_range(-1, 1) * shake * 0.12
	cam.v_offset = randf_range(-1, 1) * shake * 0.12
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-6.0 * delta))
	cam.fov = 80.0 + 6.0 * speed01 + _fov_kick
	arm.spring_length = lerpf(arm.spring_length, cam_dist, 1.0 - exp(-8.0 * delta))
