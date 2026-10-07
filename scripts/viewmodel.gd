class_name Viewmodel
extends Node3D
## First-person hands. Child of the camera. Two voxel goblin arms driven by hand targets (a tiny
## IK: the arm always stretches from its shoulder to the hand), so weapon swings, blocks, bottle
## throws, kicks and grog-chugging are all just keyframed hand positions.

const S := GoblinModel.S
const ARM_LEN := 0.46

# keyframes: [t, hand position (camera space), weapon euler degrees, ease(0 smooth, 1 in, 2 out)]
const REST_POS := Vector3(0.33, -0.36, -0.52)
const REST_ROT := Vector3(-32.0, 10.0, 0.0)

const SWINGS := {
	"overhead": [
		[0.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
		[0.30, Vector3(0.28, -0.02, -0.36), Vector3(55, 6, 6), 0],
		[0.50, Vector3(0.12, -0.36, -0.86), Vector3(-102, 0, 0), 1],
		[0.64, Vector3(0.12, -0.44, -0.82), Vector3(-114, 0, 0), 2],
		[1.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
	],
	"slash": [
		[0.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
		[0.28, Vector3(0.60, -0.16, -0.40), Vector3(-18, 28, -58), 0],
		[0.50, Vector3(-0.36, -0.30, -0.80), Vector3(-62, -42, 52), 1],
		[0.64, Vector3(-0.44, -0.34, -0.74), Vector3(-70, -52, 60), 2],
		[1.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
	],
	"stab": [
		[0.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
		[0.30, Vector3(0.34, -0.30, -0.26), Vector3(-82, 4, 0), 0],
		[0.48, Vector3(0.20, -0.22, -1.02), Vector3(-90, 0, 0), 1],
		[0.62, Vector3(0.20, -0.24, -0.96), Vector3(-90, 0, 0), 2],
		[1.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
	],
	"slam": [
		[0.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
		[0.40, Vector3(0.20, 0.14, -0.24), Vector3(64, 0, 0), 0],
		[0.56, Vector3(0.06, -0.52, -0.92), Vector3(-108, 0, 0), 1],
		[0.78, Vector3(0.06, -0.55, -0.90), Vector3(-112, 0, 0), 2],
		[1.0, Vector3(0.33, -0.36, -0.52), Vector3(-32, 10, 0), 0],
	],
	"shoot": [
		[0.0, Vector3(0.28, -0.28, -0.56), Vector3(-80, 0, 0), 0],
		[0.14, Vector3(0.28, -0.22, -0.44), Vector3(-66, 0, 0), 2],
		[1.0, Vector3(0.28, -0.28, -0.56), Vector3(-80, 0, 0), 0],
	],
}
const TWO_HANDED := ["club", "stamp", "pencil", "cleaver"]

var hold: Node3D                 # the carried parcel is parented here
var arm_l: Node3D
var arm_r: Node3D
var hand_r: Node3D
var hand_l: Node3D
var weapon_node: MeshInstance3D
var boot: Node3D
var bottle: Node3D
var flask: Node3D
var base := ""
var _t := 0.0
var _carry := 0.0
var _block := 0.0
var _roll := 0.0
var _throw := 0.0
var _kick := 0.0
var _slap := 0.0
var _drink := 0.0
var _cast := 0.0
var _bob := 0.0
var _bob_amt := 0.0
var _swing_t := -1.0
var _swing_dur := 0.5
var _swing_type := "overhead"
var _swing_alt := false
var _recoil := 0.0
var _equipped_base := ""
var _equipped_rar := -1
var _glow: OmniLight3D


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
			arm_r = a            # +x = screen right: the weapon arm
		else:
			arm_l = a
	hand_r = Node3D.new()
	add_child(hand_r)
	hand_l = Node3D.new()
	add_child(hand_l)
	weapon_node = MeshInstance3D.new()
	weapon_node.material_override = VMat.solid(ItemModels.S, 4.0)
	weapon_node.scale = Vector3.ONE * 0.8
	hand_r.add_child(weapon_node)
	_glow = OmniLight3D.new()
	_glow.omni_range = 2.6
	_glow.light_energy = 0.0
	_glow.position = Vector3(0, 0.5, 0)
	hand_r.add_child(_glow)
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
	hand_l.add_child(bottle)
	bottle.visible = false
	bottle.position = Vector3(0, 0.0, 0)
	flask = Node3D.new()
	var fm := MeshInstance3D.new()
	var fv := Vox.new(0.03)
	fv.box(-3, 0, -2, 3, 8, 2, Color("#7a4a28"), 0.06)
	fv.box(-1, 8, -1, 1, 11, 1, Color("#7a4a28"), 0.05)
	fv.box(-2, 11, -2, 2, 13, 2, Color("#b8925a"), 0.04)
	fv.box(-3, 2, 2, 3, 5, 3, Color("#e8d8a8"), 0.03)
	fm.mesh = fv.build_coarse(Vector3(0, 0, 0))
	fm.material_override = VMat.solid(0.03, 4.0)
	flask.add_child(fm)
	hand_l.add_child(flask)
	flask.visible = false
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_weapon(item: Variant) -> void:
	if item == null:
		base = ""
		weapon_node.mesh = null
		_equipped_base = ""
		_equipped_rar = -1
		_glow.light_energy = 0.0
		return
	var it: Dictionary = item
	if it["base"] == _equipped_base and it["rarity"] == _equipped_rar:
		return
	_equipped_base = it["base"]
	_equipped_rar = it["rarity"]
	base = it["base"]
	weapon_node.mesh = ItemModels.weapon_mesh(base, int(it["rarity"]))
	var rc := ItemDB.rarity_color(int(it["rarity"]))
	_glow.light_color = rc
	_glow.light_energy = 0.0 if int(it["rarity"]) < 3 else 0.6 + 0.3 * (int(it["rarity"]) - 3)


func swing_type_for(w: String) -> String:
	return ItemDB.WEAPONS[w]["swing"] if ItemDB.WEAPONS.has(w) else "overhead"


## dur seconds for the whole swing; combo alternates the slash direction.
func play_attack(type: String, dur: float, alt := false) -> void:
	_swing_type = type
	_swing_dur = dur
	_swing_t = 0.0
	_swing_alt = alt


func swing_progress() -> float:
	return _swing_t / _swing_dur if _swing_t >= 0.0 else -1.0


func set_state(speed01: float, carrying: bool, has_bottle: bool, delta: float, blocking := false, rolling := 0.0) -> void:
	_t += delta
	_carry = lerpf(_carry, 1.0 if carrying else 0.0, 1.0 - exp(-10.0 * delta))
	_block = lerpf(_block, 1.0 if blocking else 0.0, 1.0 - exp(-16.0 * delta))
	_roll = rolling
	_bob += delta * (6.0 + 8.0 * speed01)
	_bob_amt = lerpf(_bob_amt, speed01, 1.0 - exp(-8.0 * delta))
	_throw = maxf(0.0, _throw - delta * 2.8)
	_kick = maxf(0.0, _kick - delta * 4.0)
	_slap = maxf(0.0, _slap - delta * 5.0)
	_drink = maxf(0.0, _drink - delta * 1.3)
	_cast = maxf(0.0, _cast - delta * 2.0)
	_recoil = maxf(0.0, _recoil - delta * 6.0)
	if _swing_t >= 0.0:
		_swing_t += delta
		if _swing_t >= _swing_dur:
			_swing_t = -1.0
	var bobx := sin(_bob) * 0.012 * _bob_amt
	var boby := absf(cos(_bob)) * 0.018 * _bob_amt
	var idle := sin(_t * 1.6) * 0.004
	hold.position = Vector3(bobx, -0.36 + boby * 0.6 + idle, -0.62)
	# ---- right hand / weapon
	var armed := base != "" and _carry < 0.5
	weapon_node.visible = armed
	var rest_pos := REST_POS
	var rest_rot := REST_ROT
	if base == "stapler":
		rest_pos = Vector3(0.28, -0.28, -0.56)
		rest_rot = Vector3(-80, 0, 0)
	var hpos := rest_pos + Vector3(bobx, boby * 0.8 + idle, 0)
	var hrot := rest_rot + Vector3(sin(_bob * 1.0) * 2.0 * _bob_amt, 0, sin(_bob * 0.5) * 3.0 * _bob_amt)
	if _swing_t >= 0.0 and armed:
		var sample := _sample(_swing_type, _swing_t / _swing_dur)
		hpos = sample[0]
		hrot = sample[1]
		if _swing_alt and _swing_type == "slash":
			hpos.x = -hpos.x + 0.0
			hrot.y = -hrot.y
			hrot.z = -hrot.z
	if _block > 0.01 and armed:
		var bpos := Vector3(0.02, -0.2, -0.56)
		var brot := Vector3(-8, 0, 78)
		hpos = hpos.lerp(bpos, _block)
		hrot = hrot.lerp(brot, _block)
	if _cast > 0.0:
		var c := sin((1.0 - _cast) * PI)
		hpos = hpos.lerp(Vector3(0.2, 0.18, -0.4), c)
		hrot = hrot.lerp(Vector3(10, 0, 0), c)
	if _roll > 0.0:
		var r := sin(_roll * PI)
		hpos += Vector3(-0.05, -0.12, 0.05) * r
		hrot += Vector3(-30, 0, 0) * r
	if _carry > 0.01:
		var hug := Vector3(0.27, -0.32, -0.58)
		hpos = hpos.lerp(hug, _carry)
	hand_r.position = hpos
	hand_r.rotation_degrees = hrot
	_aim_arm(arm_r, Vector3(0.34, -0.17, -0.12), hpos if armed or _carry > 0.5 else Vector3(0.34 + bobx, -0.40 + boby, -0.55))
	# ---- left hand
	var lh := Vector3(-0.34, -0.40 + boby * 0.6, -0.55)
	if base in TWO_HANDED and armed:
		lh = hpos + Vector3(-0.07, -0.09, 0.02).rotated(Vector3.RIGHT, deg_to_rad(hrot.x + 32.0) * 0.4)
		lh.x = lerpf(-0.34, lh.x, 0.75 + 0.25 * (1.0 - _block))
	if _block > 0.01:
		lh = lh.lerp(Vector3(-0.12, -0.22, -0.55), _block)
	if _carry > 0.01:
		lh = lh.lerp(Vector3(-0.27, -0.32, -0.58), _carry)
	var show_bottle := false
	var show_flask := false
	if _throw > 0.0:
		var k := 1.0 - _throw                       # 0 -> 1
		var wind := Style.smooth(0.0, 0.35, k)
		var rel := Style.smooth(0.35, 0.6, k)
		var back := Vector3(-0.34, 0.05, -0.18)
		var fwd := Vector3(-0.18, 0.04, -0.95)
		lh = lh.lerp(back, wind)
		lh = lh.lerp(fwd, rel)
		lh = lh.lerp(Vector3(-0.34, -0.4, -0.55), Style.smooth(0.7, 1.0, k))
		show_bottle = k < 0.55
		hand_l.rotation_degrees = Vector3(-90, 0, 0)
	elif _drink > 0.0:
		var kd := 1.0 - _drink
		var up := sin(clampf(kd * 1.25, 0.0, 1.0) * PI)
		lh = lh.lerp(Vector3(-0.08, -0.02, -0.34), up)
		show_flask = true
		hand_l.rotation_degrees = Vector3(-40.0 - 70.0 * up, 0, 20)
	else:
		hand_l.rotation_degrees = Vector3.ZERO
	if _slap > 0.0:
		lh.y += sin(_slap * PI * 3.0) * _slap * 0.1
	hand_l.position = lh
	bottle.visible = show_bottle
	flask.visible = show_flask
	_aim_arm(arm_l, Vector3(-0.34, -0.17, -0.12), lh)
	if _kick > 0.0:
		var k2 := _kick
		var f := sin((1.0 - k2) * PI)
		boot.visible = true
		boot.position = Vector3(0.12, -0.75 + 0.5 * f, -0.2 - 0.55 * f)
		boot.rotation_degrees = Vector3(30.0 + 70.0 * f, 0.0, 0.0)
	else:
		boot.visible = false


func _sample(type: String, t: float) -> Array:
	var keys: Array = SWINGS.get(type, SWINGS["overhead"])
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if t <= float(b[0]) or i == keys.size() - 1:
			var u := clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001), 0.0, 1.0)
			match int(b[3]):
				1:
					u = u * u * u
				2:
					u = 1.0 - (1.0 - u) * (1.0 - u)
				_:
					u = u * u * (3.0 - 2.0 * u)
			return [(a[1] as Vector3).lerp(b[1], u), (a[2] as Vector3).lerp(b[2], u)]
	return [REST_POS, REST_ROT]


## Point an arm (mesh hangs along -Y from its origin) from its shoulder at a hand position.
func _aim_arm(arm: Node3D, shoulder: Vector3, hand: Vector3) -> void:
	var to := hand - shoulder
	var l := to.length()
	if l < 0.01:
		return
	arm.position = shoulder
	var q := Quaternion(Vector3(0, -1, 0), to / l)
	arm.basis = Basis(q) * Basis.from_scale(Vector3(1.0, clampf(l / ARM_LEN, 0.7, 1.7), 1.0))


func play_throw() -> void:
	_throw = 1.0


func play_kick() -> void:
	_kick = 1.0


func play_slap() -> void:
	_slap = 1.0


func play_drink() -> void:
	_drink = 1.0


func play_cast() -> void:
	_cast = 1.0


func recoil() -> void:
	_recoil = 1.0
