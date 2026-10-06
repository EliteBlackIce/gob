class_name Crow
extends Enemy
## Perched thief. Swoops, steals the parcel, flies to its nest and eats it
## while you sprint after it. Bottles and boots bring it down.

enum S { PERCH, SWOOP, FLEE, EAT, STUNNED, LEAVE }

var state := S.PERCH
var home := Vector3.ZERO
var nest := Vector3.ZERO
var parcel: Parcel = null

var _t := 0.0
var _wings: Array[Node3D] = []
var _cooldown := 0.0
var _peck_cd := 0.0
var _caw_t := 0.0
var _leave_t := 0.0
var _body: Node3D


func _ready() -> void:
	super._ready()
	_body = Node3D.new()
	add_child(_body)
	var black := Color("#1d1b26")
	Style.sphere(_body, 0.26, black, Vector3.ZERO, Vector3(1.0, 0.85, 1.6), 7)
	Style.sphere(_body, 0.17, black, Vector3(0, 0.12, 0.34), Vector3.ONE, 7)
	Style.cone(_body, 0.06, 0.24, Color("#f0a030"), Vector3(0, 0.1, 0.55), Vector3(90, 0, 0), 5)
	Style.sphere(_body, 0.045, Color.WHITE, Vector3(0.1, 0.18, 0.43), Vector3.ONE, 5)
	Style.sphere(_body, 0.045, Color.WHITE, Vector3(-0.1, 0.18, 0.43), Vector3.ONE, 5)
	Style.sphere(_body, 0.02, Color.BLACK, Vector3(0.11, 0.18, 0.47), Vector3.ONE, 4)
	Style.sphere(_body, 0.02, Color.BLACK, Vector3(-0.11, 0.18, 0.47), Vector3.ONE, 4)
	Style.box(_body, Vector3(0.18, 0.04, 0.4), Color("#2c2a3a"), Vector3(0, 0, -0.5), Vector3(-10, 0, 0))
	for s in [-1, 1]:
		var w := Node3D.new()
		w.position = Vector3(s * 0.2, 0.08, 0)
		_body.add_child(w)
		Style.box(w, Vector3(0.7, 0.04, 0.34), Color("#262433"), Vector3(s * 0.35, 0, 0))
		_wings.append(w)
	position = home
	rotation.y = randf() * TAU


func hear(pos: Vector3, radius: float) -> void:
	if state != S.PERCH or player == null or player.dead:
		return
	if global_position.distance_to(pos) < radius and player.carried != null:
		state = S.SWOOP
		Sfx.play("caw", -4.0)


func stun(t: float) -> void:
	if state == S.STUNNED or state == S.LEAVE and parcel == null:
		return
	_drop_parcel()
	state = S.STUNNED
	stun_t = t
	Sfx.play("caw", -2.0, 0.7)
	Style.burst(get_parent(), global_position, Color("#2c2a3a"), 8, 4.0, 0.1, 0.8)


func hit(_dir: Vector3, _force: float) -> void:
	if state == S.PERCH or global_position.y - ground(global_position) < 3.6:
		_drop_parcel()
		Sfx.play("caw", 0.0, 0.6)
		Style.burst(get_parent(), global_position, Color("#2c2a3a"), 16, 6.0, 0.12, 1.0)
		queue_free()


func _drop_parcel() -> void:
	if parcel != null and is_instance_valid(parcel) and parcel.state == "stolen":
		var gp := global_position
		gp.y = ground(gp)
		parcel.make_loose(gp)
		if ui != null:
			ui.toast("The crow dropped it! Grab it!", Color("#9dffa0"))
	parcel = null


func _physics_process(delta: float) -> void:
	_t += delta
	_peck_cd = maxf(0.0, _peck_cd - delta)
	_cooldown = maxf(0.0, _cooldown - delta)
	var flap := 0.15 if state == S.PERCH or state == S.EAT or state == S.STUNNED else 1.0
	for i in _wings.size():
		var s := -1.0 if i == 0 else 1.0
		_wings[i].rotation.z = s * sin(_t * 26.0 * flap) * 0.7 * flap + s * (0.5 if flap < 0.5 else 0.0)
	if parcel != null and is_instance_valid(parcel) and parcel.state == "stolen":
		parcel.global_position = global_position + Vector3(0, -0.3, 0) + global_basis.z * 0.5
	if player == null:
		return
	match state:
		S.PERCH:
			global_position = home + Vector3(0, sin(_t * 2.0) * 0.02, 0)
			var d := global_position.distance_to(player.global_position)
			if not player.dead and ((player.carried != null and d < 17.0) or d < 8.0):
				state = S.SWOOP
				Sfx.play("caw", -3.0)
		S.SWOOP:
			_swoop(delta)
		S.FLEE:
			var goal := nest + Vector3(0, 0.6, 0)
			var flat := Vector2(goal.x - global_position.x, goal.z - global_position.z)
			var tgt := goal if flat.length() < 6.0 else Vector3(goal.x, maxf(goal.y, ground(global_position) + 5.0), goal.z)
			_fly_to(tgt, 8.8, delta)
			if global_position.distance_to(goal) < 1.2:
				state = S.EAT
				_caw_t = 1.0
				if ui != null:
					ui.toast("It's EATING your parcel!", Color("#ff9d8a"))
		S.EAT:
			_caw_t -= delta
			if _caw_t <= 0.0:
				_caw_t = 1.6
				Sfx.play("caw", -8.0, 0.9)
			if parcel != null and is_instance_valid(parcel):
				parcel.damage(4.0 * delta, "eaten by a crow")
			else:
				state = S.LEAVE
		S.STUNNED:
			var gy := ground(global_position) + 0.3
			global_position.y = move_toward(global_position.y, gy, 14.0 * delta)
			rotation.z = lerp_angle(rotation.z, PI * 0.5, delta * 8.0)
			stun_t -= delta
			if stun_t <= 0.0:
				rotation.z = 0.0
				state = S.LEAVE
				_leave_t = 0.0
		S.LEAVE:
			_leave_t += delta
			var away := (global_position - player.global_position)
			away.y = 0.0
			var tgt := global_position + away.normalized() * 20.0 + Vector3(0, 10, 0)
			_fly_to(tgt, 9.0, delta)
			if _cooldown <= 0.0 and parcel == null and _leave_t > 2.5 and player.carried != null \
					and global_position.distance_to(player.global_position) < 24.0 and not player.dead:
				state = S.SWOOP
			if _leave_t > 9.0:
				queue_free()


func _fly_to(target: Vector3, speed: float, delta: float) -> void:
	var d := target - global_position
	if d.length() > 0.05:
		global_position += d.normalized() * minf(speed * delta, d.length())
	face(d, delta, 8.0)


func _swoop(delta: float) -> void:
	if player.dead:
		state = S.LEAVE
		return
	var tgt := player.global_position + Vector3(0, 1.0, 0)
	_fly_to(tgt, 9.6, delta)
	if global_position.distance_to(tgt) > 1.3:
		return
	var carrying := player.carried != null and player.carried.state == "carried"
	if carrying:
		if Game.has_skill("pocket") and not player.pocket_used:
			player.pocket_used = true
			ui.toast("SECRET POCKET! The crow is offended.", Color("#9dffa0"))
			Sfx.play("pop")
			state = S.LEAVE
			_leave_t = 0.0
			_cooldown = 6.0
			return
		parcel = player.carried
		player.carried = null
		parcel.state = "stolen"
		parcel.held()
		parcel.get_parent().remove_child(parcel)
		get_parent().add_child(parcel)
		parcel.scale = Vector3.ONE * 0.7
		Sfx.play("caw", 2.0)
		ui.toast("A CROW STOLE YOUR PARCEL!", Color("#ff9d8a"))
		Game.moment("CROW STOLE THE PARCEL")
		player.shake = 0.3
		state = S.FLEE
	elif _peck_cd <= 0.0:
		_peck_cd = 1.8
		var dir := (player.global_position - global_position)
		dir.y = 0.0
		player.take_hit(dir, 6.5, 1, "was pecked to death by a crow with a grudge")
		state = S.LEAVE
		_leave_t = 0.0
		_cooldown = 1.5
