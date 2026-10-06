class_name Slime
extends Enemy
## Postal Inspector Slime. Wants to see your stamp. If your timing is bad it
## confiscates the parcel and balances it on its head like a trophy.

enum S { IDLE, CHASE, INSPECT, HAPPY, FLEE, STUNNED }

var state := S.IDLE
var home := Vector3.ZERO
var parcel: Parcel = null

var _t := 0.0
var _body: Node3D
var _ignore := 0.0
var _flee_goal := Vector3.ZERO
var _happy_t := 0.0
var _phase := 0.0


func _ready() -> void:
	super._ready()
	_body = Node3D.new()
	add_child(_body)
	var green := Color("#58c96a")
	Style.sphere(_body, 0.62, green, Vector3(0, 0.5, 0), Vector3(1.0, 0.85, 1.0), 10, 0.18)
	Style.sphere(_body, 0.16, Color.WHITE, Vector3(-0.22, 0.68, 0.5), Vector3.ONE, 7)
	Style.sphere(_body, 0.16, Color.WHITE, Vector3(0.22, 0.68, 0.5), Vector3.ONE, 7)
	Style.sphere(_body, 0.07, Color.BLACK, Vector3(-0.22, 0.68, 0.64), Vector3.ONE, 5)
	Style.sphere(_body, 0.07, Color.BLACK, Vector3(0.22, 0.68, 0.64), Vector3.ONE, 5)
	Style.torus(_body, 0.015, 0.2, Color("#e0b84a"), Vector3(0.22, 0.68, 0.62), Vector3(0, 0, 0), 0.2)
	Style.box(_body, Vector3(0.3, 0.05, 0.05), Color("#1d5a2a"), Vector3(0, 0.38, 0.6))
	Style.box(_body, Vector3(0.34, 0.42, 0.06), Color("#8a6a3a"), Vector3(0.6, 0.45, 0.25), Vector3(0, -40, 10))
	Style.box(_body, Vector3(0.28, 0.34, 0.07), Color("#f1e6c8"), Vector3(0.61, 0.46, 0.26), Vector3(0, -40, 10))
	Style.label3d(_body, "INSPECTOR", Vector3(0, 1.45, 0), 0.012, Color("#c8ffd0"))
	position = home


func hear(_pos: Vector3, _radius: float) -> void:
	pass


func stun(t: float) -> void:
	_spit()
	state = S.STUNNED
	stun_t = t
	Sfx.play("squelch", -2.0, 1.3)
	Style.burst(get_parent(), global_position + Vector3.UP * 0.5, Color("#58c96a"), 10, 5.0, 0.12, 0.7)


func hit(dir: Vector3, force: float) -> void:
	global_position += dir * 1.6 * force
	stun(1.6 * force)


func _spit() -> void:
	if parcel != null and is_instance_valid(parcel) and parcel.state == "absorbed":
		var gp := global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 1.4
		gp.y = ground(gp)
		parcel.make_loose(gp)
		if ui != null:
			ui.toast("*BLORP* The slime spat it out!", Color("#9dffa0"))
	parcel = null
	_ignore = 12.0


func _physics_process(delta: float) -> void:
	_t += delta
	_ignore = maxf(0.0, _ignore - delta)
	if player == null:
		return
	var dist := global_position.distance_to(player.global_position)
	var moving := false
	var hop_dir := Vector3.ZERO
	var speed := 0.0
	match state:
		S.IDLE:
			if _ignore <= 0.0 and not player.dead and player.carried != null and player.carried.state == "carried" and dist < 20.0:
				state = S.CHASE
				ui.toast("Papers, please!", Color("#c8ffd0"))
				Sfx.play("squelch", -4.0)
		S.CHASE:
			if player.dead or player.carried == null or player.carried.state != "carried":
				state = S.IDLE
			else:
				moving = true
				hop_dir = player.global_position - global_position
				speed = 4.7
				if dist < 2.1:
					_begin_inspection()
		S.INSPECT:
			face(player.global_position - global_position, delta)
		S.HAPPY:
			_happy_t -= delta
			_body.position.y = absf(sin(_t * 12.0)) * 0.4
			if _happy_t <= 0.0:
				state = S.IDLE
				_ignore = 30.0
		S.FLEE:
			moving = true
			hop_dir = _flee_goal - global_position
			speed = 4.4
			if parcel != null and is_instance_valid(parcel):
				parcel.damage(5.0 * delta, "dissolved by an Inspector Slime")
			else:
				state = S.IDLE
				_ignore = 20.0
			if hop_dir.length() < 2.0:
				_flee_goal = home + Vector3(randf_range(-14, 14), 0, randf_range(-14, 14))
		S.STUNNED:
			stun_t -= delta
			_body.scale = Vector3(1.2, 0.6, 1.2)
			if stun_t <= 0.0:
				_body.scale = Vector3.ONE
				state = S.IDLE
	if moving:
		hop_dir.y = 0.0
		var hop := absf(sin(_t * 6.0))
		global_position += hop_dir.normalized() * speed * delta * (0.2 + hop * 1.2)
		_body.position.y = hop * 0.55
		_body.scale = Vector3(1.0 + (1.0 - hop) * 0.18, 1.0 - (1.0 - hop) * 0.2, 1.0 + (1.0 - hop) * 0.18)
		face(hop_dir, delta, 8.0)
	elif state == S.IDLE:
		_body.scale = Vector3(1.0, 1.0 + sin(_t * 2.5) * 0.05, 1.0)
		_body.position.y = 0.0
	var gy := ground(global_position)
	global_position.y = gy
	if parcel != null and is_instance_valid(parcel) and parcel.state == "absorbed":
		parcel.global_position = global_position + Vector3(0, 1.3 + _body.position.y, 0)


func _begin_inspection() -> void:
	if Game.has_skill("forged") and not player.forged_used:
		player.forged_used = true
		ui.toast("FORGED PAPERS! The slime is satisfied.", Color("#9dffa0"))
		Sfx.play("stamp")
		state = S.HAPPY
		_happy_t = 1.5
		return
	state = S.INSPECT
	player.frozen = true
	player.velocity = Vector3.ZERO
	ui.qte(Callable(self, "_inspection_done"))


func _inspection_done(success: bool) -> void:
	player.frozen = false
	if not is_inside_tree() or player.dead:
		return
	if success:
		Sfx.play("stamp")
		ui.toast("APPROVED!", Color("#9dffa0"))
		state = S.HAPPY
		_happy_t = 1.6
		return
	Sfx.play("error")
	if player.carried != null and player.carried.state == "carried":
		parcel = player.carried
		player.carried = null
		parcel.state = "absorbed"
		parcel.held()
		parcel.get_parent().remove_child(parcel)
		get_parent().add_child(parcel)
		parcel.scale = Vector3.ONE * 0.8
		ui.toast("REJECTED! CONFISCATED!", Color("#ff9d8a"))
		Game.moment("SLIME CONFISCATED THE PARCEL")
		var away := (global_position - player.global_position)
		away.y = 0.0
		_flee_goal = global_position + away.normalized() * 24.0
		state = S.FLEE
	else:
		state = S.IDLE
		_ignore = 10.0
