class_name Slime
extends Enemy

func _mi2(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	parent.add_child(m)
	return m

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
	var jelly := Paint.get_mat("glass", Color("#5ed07a"), {"albedo_b": Color("#9af0a0"), "variation": 0.5, "noise_scale": 2.0, "emission_strength": 0.28, "emission_color": Color("#7aff9a"), "roughness": 0.15, "specular": 0.9, "rim": 0.9, "rim_color": Color("#c8ffd0"), "sss": 0.8, "sss_color": Color("#a0ff80"), "wrap": 0.6})
	var gel := MeshKit.blob(func(u: Vector3) -> Vector3:
		var p := u * Vector3(0.62, 0.58, 0.62)
		if u.y < 0.0:
			p.y *= 0.55
			p.x *= 1.0 + 0.12 * -u.y
			p.z *= 1.0 + 0.12 * -u.y
		p.y += 0.5
		return p, func(u: Vector3, p: Vector3) -> Color:
		var c := Color("#3fae5a").lerp(Color("#8fe8a0"), clampf(u.y * 0.5 + 0.5, 0.0, 1.0))
		return Color(c.r, c.g, c.b, 1.0), 16, 22)
	_mi2(_body, gel, jelly)
	# suspended gunk bits + bubbles inside the jelly
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 7:
		var bub := MeshKit.blob(func(u: Vector3) -> Vector3: return u * rng.randf_range(0.03, 0.07))
		_mi2(_body, bub, Paint.get_mat("glass", Color("#d8ffd8"), {"emission_strength": 0.5, "emission_color": Color("#e8ffe8")}), Vector3(rng.randf_range(-0.3, 0.3), 0.35 + rng.randf_range(0.0, 0.5), rng.randf_range(-0.3, 0.3)))
	# big googly eyes + grumpy brows (it's a bureaucrat)
	var eye_w := Paint.get_mat("plain", Color("#fffbe8"), {"roughness": 0.15, "specular": 0.8, "rim": 0.2})
	var pupil := Paint.get_mat("plain", Color("#14100c"), {"roughness": 0.1, "specular": 1.0})
	for sd in [-1.0, 1.0]:
		_mi2(_body, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.15), eye_w, Vector3(sd * 0.22, 0.72, 0.5))
		_mi2(_body, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.07, 0.085, 0.05)), pupil, Vector3(sd * 0.22 - sd * 0.015, 0.7, 0.63))
		_mi2(_body, MeshKit.rbox(Vector3(0.22, 0.045, 0.05), 0.015), Paint.get_mat("plain", Color("#1d5a2a")), Vector3(sd * 0.22, 0.9, 0.52), Vector3(0, 0, sd * 16))
	# a flat, unimpressed mouth
	_mi2(_body, MeshKit.rbox(Vector3(0.3, 0.04, 0.05), 0.015), Paint.get_mat("plain", Color("#1d5a2a")), Vector3(0, 0.45, 0.6))
	# monocle with chain, clipboard with stamp
	var gold := Paint.metal(Color("#e0b84a"), {"emission_strength": 0.1})
	_mi2(_body, MeshKit.torus_ring(0.12, 0.016), gold, Vector3(0.22, 0.7, 0.62))
	_mi2(_body, MeshKit.tube([Vector3(0.34, 0.7, 0.6), Vector3(0.5, 0.5, 0.5), Vector3(0.6, 0.45, 0.3)], PackedFloat32Array([0.008, 0.008, 0.008]), 4), gold)
	var cb := Node3D.new()
	cb.position = Vector3(-0.6, 0.55, 0.3)
	cb.rotation_degrees = Vector3(0, 30, -8)
	_body.add_child(cb)
	_mi2(cb, MeshKit.rbox(Vector3(0.3, 0.4, 0.035), 0.01), Paint.wood(Color("#8a6038"), {"grain": 0.7}), Vector3.ZERO)
	_mi2(cb, MeshKit.rbox(Vector3(0.25, 0.32, 0.01), 0.004), Paint.get_mat("cloth", Color("#f1e6c8")), Vector3(0, -0.01, 0.022))
	_mi2(cb, MeshKit.rbox(Vector3(0.12, 0.04, 0.02), 0.006), gold, Vector3(0, 0.2, 0.02))
	for ln in 4:
		_mi2(cb, MeshKit.rbox(Vector3(0.18, 0.006, 0.004), 0.002), Paint.get_mat("plain", Color("#3a2a1a")), Vector3(0, 0.08 - ln * 0.06, 0.03))
	_mi2(cb, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.035), Paint.glow(Color("#e0302a"), 0.3), Vector3(0.05, -0.1, 0.03))
	Style.label3d(_body, "INSPECTOR", Vector3(0, 1.55, 0), 0.01, Color("#c8ffd0"), Vector3.ZERO, true)
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
