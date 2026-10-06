class_name Viewmodel
extends Node3D
## First-person hands. Child of the camera. Two voxel goblin arms that cradle the carried
## parcel, swing with your steps, throw bottles, and a boot that flies in for the kick.

const S := GoblinModel.S

var hold: Node3D                 # the carried parcel is parented here
var arm_l: Node3D
var arm_r: Node3D
var boot: Node3D
var bottle: Node3D
var _t := 0.0
var _carry := 0.0                # 0 arms down .. 1 hugging the parcel
var _throw := 0.0
var _kick := 0.0
var _slap := 0.0
var _bob := 0.0
var _bob_amt := 0.0


func _ready() -> void:
	var skin := GoblinModel.SKIN
	var arm_mesh: ArrayMesh = GoblinModel._parts(skin, GoblinModel.LEATHER, GoblinModel.CAP)["armL"]
	var mat := VMat.solid(S, 4.0)
	hold = Node3D.new()
	hold.position = Vector3(0, -0.36, -0.72)
	add_child(hold)
	for sd in [-1.0, 1.0]:
		var a := Node3D.new()
		add_child(a)
		var mi := MeshInstance3D.new()
		mi.mesh = arm_mesh
		mi.material_override = mat
		mi.scale = Vector3.ONE * 0.95
		a.add_child(mi)
		if sd > 0:
			arm_l = a
		else:
			arm_r = a
	boot = Node3D.new()
	add_child(boot)
	var bmesh: ArrayMesh = GoblinModel._parts(skin, GoblinModel.LEATHER, GoblinModel.CAP)["legL"]
	var bi := MeshInstance3D.new()
	bi.mesh = bmesh
	bi.material_override = mat
	bi.scale = Vector3.ONE * 1.05
	boot.add_child(bi)
	boot.visible = false
	bottle = Node3D.new()
	var bm := MeshInstance3D.new()
	bm.mesh = VoxProps.bottle(Color("#3e9c5a"))
	bm.material_override = VMat.solid(0.03, 4.0)
	bm.scale = Vector3.ONE * 1.6
	bottle.add_child(bm)
	arm_r.add_child(bottle)
	bottle.position = Vector3(0, -0.62, 0.0)
	bottle.rotation_degrees = Vector3(90, 0, 0)
	# first-person parts are tiny: keep them from clipping into walls by drawing late
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_state(speed01: float, carrying: bool, has_bottle: bool, delta: float) -> void:
	_t += delta
	_carry = lerpf(_carry, 1.0 if carrying else 0.0, 1.0 - exp(-10.0 * delta))
	_bob += delta * (6.0 + 8.0 * speed01)
	_bob_amt = lerpf(_bob_amt, speed01, 1.0 - exp(-8.0 * delta))
	_throw = maxf(0.0, _throw - delta * 3.2)
	_kick = maxf(0.0, _kick - delta * 4.0)
	_slap = maxf(0.0, _slap - delta * 5.0)
	bottle.visible = has_bottle and _carry < 0.5
	var bobx := sin(_bob) * 0.012 * _bob_amt
	var boby := absf(cos(_bob)) * 0.018 * _bob_amt
	var idle := sin(_t * 1.6) * 0.004
	hold.position = Vector3(bobx, -0.36 + boby * 0.6 + idle, -0.62)
	# relaxed pose: arms hang at the sides, slightly forward
	var relaxed_l := Vector3(0.34, -0.17 + boby, -0.16)
	var relaxed_r := Vector3(-0.34, -0.17 + boby, -0.16)
	var hug_l := Vector3(0.27, -0.2, -0.08)
	var hug_r := Vector3(-0.27, -0.2, -0.08)
	arm_l.position = relaxed_l.lerp(hug_l, _carry) + Vector3(bobx, 0, 0)
	arm_r.position = relaxed_r.lerp(hug_r, _carry) + Vector3(bobx, 0, 0)
	var swing := sin(_bob) * 0.18 * _bob_amt
	var rl := Vector3(deg_to_rad(64.0) + swing, deg_to_rad(-6.0), deg_to_rad(-4.0))
	var rr := Vector3(deg_to_rad(64.0) - swing, deg_to_rad(6.0), deg_to_rad(4.0))
	var hl := Vector3(deg_to_rad(78.0), deg_to_rad(12.0), deg_to_rad(-4.0))
	var hr := Vector3(deg_to_rad(78.0), deg_to_rad(-12.0), deg_to_rad(4.0))
	arm_l.rotation = rl.lerp(hl, _carry)
	arm_r.rotation = rr.lerp(hr, _carry)
	if _throw > 0.0:
		var k := _throw
		var w := sin((1.0 - k) * PI)
		arm_r.rotation = arm_r.rotation.lerp(Vector3(deg_to_rad(170.0 - 120.0 * (1.0 - k)), 0.0, deg_to_rad(8.0)), clampf(w * 1.6, 0.0, 1.0))
		arm_r.position += Vector3(0.0, 0.1 * w, -0.1 * w)
	if _slap > 0.0:
		var sp := sin(_slap * PI * 3.0) * _slap
		arm_l.position.y += sp * 0.1
		arm_l.rotation.x += sp * 0.3
	if _kick > 0.0:
		var k2 := _kick
		var f := sin((1.0 - k2) * PI)
		boot.visible = true
		boot.position = Vector3(0.12, -0.75 + 0.5 * f, -0.2 - 0.55 * f)
		boot.rotation_degrees = Vector3(30.0 + 70.0 * f, 0.0, 0.0)
	else:
		boot.visible = false


func play_throw() -> void:
	_throw = 1.0


func play_kick() -> void:
	_kick = 1.0


func play_slap() -> void:
	_slap = 1.0
