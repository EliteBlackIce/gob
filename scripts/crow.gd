class_name Crow
extends Enemy

func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	parent.add_child(m)
	return m

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
var _tell_t := 0.0
var _tell: Label3D


func _ready() -> void:
	super._ready()
	_body = Node3D.new()
	_body.scale = Vector3.ONE * 1.5
	add_child(_body)
	var m_feather := Paint.get_mat("plain", Color("#23212e"), {"albedo_b": Color("#3a3858"), "variation": 0.5, "noise_scale": 5.0, "roughness": 0.35, "specular": 0.7, "rim": 0.9, "rim_color": Color("#8a8ad8"), "wrap": 0.4, "shade_fill": 0.4})
	var m_beak := Paint.get_mat("plain", Color("#f0a838"), {"roughness": 0.4, "specular": 0.5, "rim": 0.3})
	var m_eye := Paint.get_mat("plain", Color("#fff0a8"), {"roughness": 0.2, "specular": 0.8, "emission_strength": 0.3})
	var m_dark := Paint.get_mat("plain", Color("#0e0a10"), {"roughness": 0.1, "specular": 1.0})
	var bm := MeshKit.blob(func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.2, u.y * 0.19, u.z * 0.34)
		if u.z > 0.0:
			p.y += 0.04 * u.z
		else:
			p.x *= 1.0 + 0.2 * u.z
			p.y *= 1.0 + 0.2 * u.z
		return p, func(u: Vector3, p: Vector3) -> Color:
		return Color("#2a2838").lerp(Color("#4a4868"), clampf(u.y * 0.6 + 0.2, 0.0, 1.0)) * Color(1, 1, 1, 1), 12, 16)
	_mi(_body, bm, m_feather)
	_mi(_body, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.14, 0.14, 0.15), func(u: Vector3, p: Vector3) -> Color: return Color("#2e2c40")), m_feather, Vector3(0, 0.15, 0.3))
	# beak: upper + lower mandible
	_mi(_body, MeshKit.tube([Vector3(0, 0.0, 0), Vector3(0, -0.005, 0.08), Vector3(0, -0.03, 0.17)], PackedFloat32Array([0.05, 0.036, 0.0]), 8), m_beak, Vector3(0, 0.14, 0.4))
	_mi(_body, MeshKit.tube([Vector3(0, 0.0, 0), Vector3(0, -0.008, 0.06), Vector3(0, -0.02, 0.12)], PackedFloat32Array([0.03, 0.022, 0.0]), 6), m_beak, Vector3(0, 0.1, 0.4))
	for sd in [-1.0, 1.0]:
		_mi(_body, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.036), m_eye, Vector3(sd * 0.085, 0.2, 0.39))
		_mi(_body, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.02), m_dark, Vector3(sd * 0.092, 0.2, 0.418))
	# tail fan
	for k in 5:
		var ang := (k - 2) * 12.0
		_mi(_body, MeshKit.tube([Vector3(0, 0, 0), Vector3(0, 0.0, -0.18), Vector3(0, -0.02, -0.34)], PackedFloat32Array([0.04, 0.045, 0.0]), 6, PackedColorArray([Color("#2a2838"), Color("#34324a"), Color("#46446a")])), m_feather, Vector3(0, 0.0, -0.28), Vector3(-6, ang, 0))
	# feet tucked under the belly
	for sd in [-1.0, 1.0]:
		_mi(_body, MeshKit.tube([Vector3(0, 0, 0), Vector3(0, -0.1, 0.01), Vector3(0.0, -0.14, 0.05)], PackedFloat32Array([0.014, 0.012, 0.01]), 5), m_beak, Vector3(sd * 0.07, -0.14, 0.04))
	# wings: layered primary feathers, hinged at the shoulder
	for sd in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sd * 0.17, 0.06, 0.06)
		_body.add_child(w)
		for fi in 8:
			var t := float(fi) / 7.0
			var ln := lerpf(0.5, 0.95, t)
			var fc := Color("#26243a").lerp(Color("#4a4a78"), t)
			var fm := MeshKit.blob(func(u: Vector3) -> Vector3: return Vector3((u.x * 0.5 + 0.5) * ln, u.y * 0.012, u.z * 0.075 * (1.0 - 0.45 * (u.x * 0.5 + 0.5))), func(u: Vector3, p: Vector3) -> Color: return fc, 5, 8)
			_mi(w, fm, m_feather, Vector3(0.0, 0.0, 0.14 - t * 0.28), Vector3(0, -sd * (8 + t * 22), sd * (4 - t * 4)), Vector3(sd, 1, 1))
		_mi(w, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.32, 0.03, 0.2), func(u: Vector3, p: Vector3) -> Color: return Color("#2a2838")), m_feather, Vector3(sd * 0.2, 0.01, 0.0))
		_wings.append(w)
	position = home
	rotation.y = randf() * TAU


func _begin_swoop() -> void:
	if state == S.SWOOP:
		return
	state = S.SWOOP
	_tell_t = 0.55
	if _tell == null:
		_tell = Style.label3d(self, "!", Vector3(0, 0.9, 0), 0.03, Color("#ff5a4a"))
	_tell.visible = true
	Sfx.play("caw", -3.0)


func hear(pos: Vector3, radius: float) -> void:
	if state != S.PERCH or player == null or player.dead:
		return
	if global_position.distance_to(pos) < radius and player.carried != null:
		_begin_swoop()
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
		_wings[i].rotation.z = s * sin(_t * 26.0 * flap) * 0.7 * flap + s * (0.14 if flap < 0.5 else 0.0)
	if parcel != null and is_instance_valid(parcel) and parcel.state == "stolen":
		parcel.global_position = global_position + Vector3(0, -0.3, 0) + global_basis.z * 0.5
	if player == null:
		return
	match state:
		S.PERCH:
			global_position = home + Vector3(0, sin(_t * 2.0) * 0.02, 0)
			var d := global_position.distance_to(player.global_position)
			if not player.dead and ((player.carried != null and d < 17.0) or d < 8.0):
				_begin_swoop()
		S.SWOOP:
			_swoop(delta)
		S.FLEE:
			var goal := nest + Vector3(0, 0.6, 0)
			var flat := Vector2(goal.x - global_position.x, goal.z - global_position.z)
			var tgt := goal if flat.length() < 6.0 else Vector3(goal.x, maxf(goal.y, ground(global_position) + 5.0), goal.z)
			_fly_to(tgt, 6.6, delta)
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
				parcel.damage(3.0 * delta, "eaten by a crow")
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
				_begin_swoop()
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
	if _tell_t > 0.0:
		_tell_t -= delta
		face(player.global_position - global_position, delta, 12.0)
		if _tell_t <= 0.0 and _tell != null:
			_tell.visible = false
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
