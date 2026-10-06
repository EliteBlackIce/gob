class_name Player
extends CharacterBody3D
## The goblin, in first person. Fast enough to flee, fragile enough to make it interesting.

signal died(cause: String)

const GRAVITY := 24.0
const MOUSE_SENS := 0.0028
const EYE_HEIGHT := 1.36

var island: Node = null           # set on the island: height queries, water, enemies
var ui: UI
var cam_dist := 0.0               # third-person distance (only used for the death cam / tests)
var hp := 3
var max_hp := 3
var frozen := false               # scripted freeze (inspections)
var dead := false
var carried: Parcel = null
var bottles := 0
var second_wind_used := false
var pocket_used := false
var forged_used := false
var in_water := false
var speed01 := 0.0
var shake := 0.0
var invuln := 0.0

var model: Node3D                 # full body: only its shadow is seen in first person
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
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _kick_cd := 0.0
var _throw_cd := 0.0
var _launch_t := 0.0
var _slap_hold := 0.0
var _drown_t := 0.0
var _prev_vy := 0.0
var _was_in_water := false
var _kick_anim := 0.0
var _step_t := 0.0
var _fov_kick := 0.0
var _bob_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
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


func setup_for_run(is_island: bool) -> void:
	max_hp = 3 + (Game.perk_hp if is_island else 0)
	hp = max_hp
	bottles = 0
	if is_island:
		bottles = 3 + Game.perk_bottles + (3 if Game.has_skill("bandolier") else 0) + (2 if Game.has_skill("heavy_bottles") else 0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _locked():
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.5, 1.5)


func _locked() -> bool:
	return frozen or dead or (ui != null and ui.modal_open)


func _forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _physics_process(delta: float) -> void:
	_update_camera(delta)
	if dead:
		return
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_kick_cd = maxf(0.0, _kick_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	_anim_t += delta
	var locked := _locked()

	var in2 := Vector2.ZERO
	if not locked:
		in2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(in2.x, 0, in2.y).rotated(Vector3.UP, yaw)

	var speed := 6.2
	if Game.has_skill("quick_feet"):
		speed *= 1.15
	speed *= float(Game.mandate["speed"]) if island != null else 1.0
	if carried != null and carried.trait_id == "heavy":
		speed *= 0.8
	if in_water:
		speed *= 0.65

	var vy := velocity.y
	if _launch_t > 0.0:
		_launch_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, 2.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 2.0 * delta)
	elif _dash_t > 0.0:
		_dash_t -= delta
		velocity.x = _dash_dir.x * 17.0
		velocity.z = _dash_dir.z * 17.0
	else:
		var accel := 60.0 if is_on_floor() else 22.0
		velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)

	if not locked and Input.is_action_just_pressed("dash") and Game.has_skill("dash") and not bool(Game.mandate["nodash"]) \
			and _dash_cd <= 0.0 and dir.length() > 0.1 and _launch_t <= 0.0:
		_dash_t = 0.2
		_dash_cd = 1.1
		_dash_dir = dir.normalized()
		_fov_kick = 14.0
		Sfx.play("whoosh", -4.0, 1.2)
		Style.burst(get_parent(), global_position + Vector3(0, 0.1, 0), Color("#e8d8a8"), 8, 3.0, 0.14, 0.5)
		if carried != null and carried.trait_id == "glass":
			carried.damage(6.0, "dashed to pieces")

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
	if island != null and global_position.y < -14.0:
		die("fell off the edge of the world")
	_footsteps(delta)

	var hspeed := Vector2(velocity.x, velocity.z).length()
	speed01 = clampf(hspeed / 6.5, 0.0, 1.0) if is_on_floor() else 0.4
	model.rotation.y = yaw + PI
	GoblinModel.animate(model, speed01, _anim_t, carried != null)
	if _kick_anim > 0.0:
		_kick_anim -= delta
		GoblinModel.pose_kick(model, clampf(_kick_anim / 0.25, 0.0, 1.0))
	view.set_state(speed01, carried != null, bottles > 0 and island != null, delta)

	if not locked:
		_actions(delta)
		_scan_interactables()
	else:
		interact_target = null


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
	if not is_on_floor() or hs < 2.0 or _launch_t > 0.0:
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


func _actions(delta: float) -> void:
	if Input.is_action_just_pressed("throw") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and island != null and bottles > 0 and _throw_cd <= 0.0:
		bottles -= 1
		_throw_cd = 0.45
		view.play_throw()
		var aim: Vector3 = -cam.global_basis.z
		var v := (aim + Vector3.UP * 0.18).normalized() * 17.0
		Bottle.throw(get_parent(), cam.global_position + aim * 0.5 + Vector3(0.1, -0.15, 0), v + velocity * 0.3, Game.has_skill("heavy_bottles"))

	if Input.is_action_just_pressed("kick") and _kick_cd <= 0.0:
		_kick_cd = 0.6
		_kick_anim = 0.25
		view.play_kick()
		Sfx.play("whoosh", -2.0, 1.6)
		var fwd: Vector3 = _forward()
		for e in get_tree().get_nodes_in_group("enemy"):
			var d := (e as Node3D).global_position - global_position
			var flat := Vector3(d.x, 0, d.z)
			if flat.length() < 2.8 and d.y < 3.0 and flat.normalized().dot(fwd) > 0.25:
				e.hit(fwd, 2.0 if Game.has_skill("power_boot") else 1.0)

	if Input.is_action_just_pressed("toss") and carried != null and island != null:
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


func _scan_interactables() -> void:
	var best: Interactable = null
	var best_d := 9999.0
	var eye := cam.global_position
	var look: Vector3 = -cam.global_basis.z
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


func take_hit(from_dir: Vector3, force: float, dmg: int, cause: String) -> void:
	if dead or invuln > 0.0:
		return
	hp -= dmg
	if hp <= 0:
		if Game.has_skill("second_wind") and not second_wind_used:
			second_wind_used = true
			hp = 1
			ui.toast("SECOND WIND! (barely)", Color("#9dffa0"))
		else:
			die(cause, from_dir.normalized() * force)
			return
	Sfx.play("hurt")
	shake = 0.4
	invuln = 1.0
	if ui != null:
		ui.flash_damage(0.45)
		ui.hitstop(0.07)
	launch(from_dir.normalized() * force + Vector3.UP * force * 0.5)
	if carried != null:
		carried.damage(18.0, "got in the way of a hit")


func launch(v: Vector3) -> void:
	velocity = v
	_launch_t = 0.6
	_dash_t = 0.0


func die(cause: String, impulse := Vector3.ZERO) -> void:
	if dead:
		return
	dead = true
	hp = 0
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
	rig.global_position = target
	shake = maxf(0.0, shake - delta * 1.4)
	var roll := sin(_bob_t * 0.5) * 0.012 * speed01
	rig.rotation = Vector3(pitch, yaw, roll)
	cam.h_offset = randf_range(-1, 1) * shake * 0.12
	cam.v_offset = randf_range(-1, 1) * shake * 0.12
	_fov_kick = lerpf(_fov_kick, 0.0, 1.0 - exp(-6.0 * delta))
	cam.fov = 80.0 + 6.0 * speed01 + _fov_kick
	arm.spring_length = lerpf(arm.spring_length, cam_dist, 1.0 - exp(-8.0 * delta))
