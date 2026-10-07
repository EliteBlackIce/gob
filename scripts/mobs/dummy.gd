class_name Dummy
extends Mob
## The training dummy by the tavern door. Takes it all and keeps a DPS meter.

var _label: Label3D
var _hits: Array = []        # [time, amount]
var _wobble := 0.0
var _vis: Node3D


func _init() -> void:
	kind = "dummy"
	theme = "crypt"
	is_boss = false
	d = {"atk": "none", "ai": "none", "hp": 999999.0, "dmg": 0.0, "speed": 0.0, "range": 0.0, "h": 1.9, "r": 0.5, "xp": 0, "cd": 1.0, "windup": 0.5, "name": "Training Dummy"}
	hp = 1.0e9
	max_hp = 1.0e9
	body_h = 1.9
	body_r = 0.5
	awake = true
	title = "Training Dummy"


func _ready() -> void:
	add_to_group("mob")
	collision_layer = 16
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 1.9
	cs.shape = cap
	cs.position = Vector3(0, 0.95, 0)
	add_child(cs)
	_vis = Node3D.new()
	add_child(_vis)
	var v := Vox.new(0.05)
	v.box(-1, 0, -1, 2, 30, 2, Color("#6a4222"), 0.06)                 # post
	v.box(-9, 20, -1, 10, 23, 2, Color("#7a5232"), 0.06)                # arms
	v.box(-5, 8, -4, 6, 22, 5, Color("#d8b870"), 0.1)                   # straw body
	for i in 6:
		v.box(-5, 9 + i * 2, -4, 6, 10 + i * 2, 5, Color("#8a6a3a"), 0.04)
	v.ellipsoid(0.5, 29.0, 0.5, 5.0, 5.0, 5.0, Color("#c8a860"), 0.1)   # sack head
	v.box(-2, 29, 4, 0, 31, 5, Color("#2a1a10"), 0.0)
	v.box(2, 29, 4, 4, 31, 5, Color("#2a1a10"), 0.0)
	v.box(-2, 26, 4, 4, 27, 5, Color("#2a1a10"), 0.0)
	v.box(-7, 20, -2, -5, 24, 2, Color("#c0302a"), 0.0)                 # red target on the chest
	v.box(-9, 4, -6, 10, 6, 7, Color("#5a3a1e"), 0.06)                  # base
	var mi := MeshInstance3D.new()
	mi.mesh = v.build(Vector3(0.5, 0, 0.5))
	var m := VMat.make_solid(0.05, 4.0)
	mi.material_override = m
	_mats = [m]
	_vis.add_child(mi)
	_label = Style.label3d(self, "Training Dummy\nswing at me", Vector3(0, 2.6, 0), 0.007, Color("#ffe9a0"), Vector3.ZERO, true)
	_label.no_depth_test = true


func _physics_process(delta: float) -> void:
	_anim_t += delta
	_flash = maxf(0.0, _flash - delta * 6.0)
	_wobble = maxf(0.0, _wobble - delta * 3.0)
	_vis.rotation.z = sin(_anim_t * 18.0) * 0.12 * _wobble
	_vis.rotation.x = sin(_anim_t * 15.0 + 1.0) * 0.1 * _wobble
	for m in _mats:
		m.set_shader_parameter("flash", _flash * 0.8)
	var now := Time.get_ticks_msec() / 1000.0
	while not _hits.is_empty() and now - float(_hits[0][0]) > 5.0:
		_hits.pop_front()
	if not _hits.is_empty():
		var total := 0.0
		for h in _hits:
			total += float(h[1])
		var span := maxf(now - float(_hits[0][0]), 1.0)
		_label.text = "Training Dummy\n%.0f DPS (5s)" % (total / minf(span, 5.0))
	else:
		_label.text = "Training Dummy\nswing at me"


func take_damage(amount: float, dir: Vector3, info := {}) -> float:
	_flash = 1.0
	_wobble = 1.0
	var crit: bool = info.get("crit", false)
	FloatText.spawn(get_parent(), global_position + Vector3(0, 2.3, 0), ("%d!" % int(round(amount))) if crit else str(int(round(amount))), Color("#ffd23a") if crit else Color("#fff4e0"), 1.5 if crit else 1.0)
	Sfx.play("crit" if crit else "thud", -4.0, randf_range(0.9, 1.2))
	Fx.hit(get_parent(), global_position + Vector3(0, 1.2, 0), Color("#d8b870"), crit)
	_hits.append([Time.get_ticks_msec() / 1000.0, amount])
	return amount


func stun(_t: float) -> void:
	pass
