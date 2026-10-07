class_name GoblinModel
extends RefCounted
## The mascot, built out of voxels like the reference: a big square head with huge googly eyes,
## a wide open grin with fangs and a lolling tongue, stepped pointy ears, a leather vest, belt
## with a metal buckle, grey trousers and chunky boots. He wears a little postal cap and a
## backpack with a bedroll and a letter poking out.
## Rig (all Node3D): Hips > Spine > Head > (Jaw, EarL, EarR, Cap); Spine > ArmL, ArmR, Back;
## Hips > LegL, LegR. Faces +Z, feet on y=0, about 1.65 m tall with the cap.

const S := 0.04   # metres per voxel

const SKIN := Color("#74b83c")
const LEATHER := Color("#6a4326")
const PANTS := Color("#54545e")
const BOOT := Color("#7e4e28")
const EYE := Color("#f4e8c4")
const PUPIL := Color("#2a1818")
const MOUTH := Color("#4a0c14")
const TEETH := Color("#f2ecd4")
const TONGUE := Color("#d93a48")
const METAL := Color("#b9bbc0")
const CAP := Color("#2f3f8f")
const PAPER := Color("#efe6cc")

static var _cache := {}


static func _skin_dark(c: Color) -> Color:
	return c.darkened(0.12)


# ------------------------------------------------------------------ voxel parts

static func _head_vox(skin: Color) -> Vox:
	var v := Vox.new(S)
	v.box(0, 0, 0, 14, 12, 12, skin, 0.06)
	# subtle shading: darker jaw line and cheeks
	for x in 14:
		for z in 12:
			v.set_v(x, 0, z, _skin_dark(skin), 0.05)
	# brow ridge
	v.box(1, 10, 11, 13, 11, 12, _skin_dark(skin), 0.05)
	# big googly eyes, proud of the face
	for ex in [1, 9]:
		v.box(ex, 5, 11, ex + 4, 10, 13, EYE, 0.02)
		v.box(ex, 5, 11, ex + 1, 6, 12, EYE.darkened(0.12), 0.0)
	v.box(3, 7, 12, 5, 9, 13, PUPIL, 0.0)       # left eye, pupil toward the centre / up
	v.box(9, 7, 12, 11, 9, 13, PUPIL, 0.0)
	# little nose
	v.box(6, 4, 12, 8, 6, 13, _skin_dark(skin).darkened(0.05), 0.04)
	# open mouth: carve, paint the cavity, add fangs
	v.remove_box(3, 0, 10, 11, 4, 12)
	v.box(3, 0, 9, 11, 4, 10, MOUTH, 0.05)
	v.box(3, 0, 9, 4, 4, 12, MOUTH.darkened(0.2), 0.0)
	v.box(10, 0, 9, 11, 4, 12, MOUTH.darkened(0.2), 0.0)
	for tx in [3, 4, 9, 10]:
		v.box(tx, 2, 10, tx + 1, 4, 11, TEETH, 0.02)
	v.box(6, 0, 10, 8, 1, 11, TEETH, 0.02)
	return v


static func _tongue_vox() -> Vox:
	var v := Vox.new(S)
	v.box(0, 0, 0, 3, 5, 2, TONGUE, 0.06)
	v.box(1, 0, 0, 2, 4, 2, TONGUE.lightened(0.12), 0.03)
	return v


static func _ear_vox(skin: Color, side: int) -> Vox:
	var v := Vox.new(S)
	for x in 10:
		var yc := 3 + int(x * 0.5)
		var half := maxi(1, 3 - x / 3)
		for y in range(yc - half, yc + half + 1):
			for z in 2:
				var c := skin
				if z == 1 and x > 1:
					c = skin.lerp(Color("#d8e070"), 0.35)       # lighter inner ear
				if y == yc + half and x > 1:
					c = _skin_dark(skin)
				var xx: int = x if side > 0 else -1 - x
				v.set_v(xx, y, z - (x / 4), c, 0.05)
	return v


static func _cap_vox(c: Color) -> Vox:
	var v := Vox.new(S)
	v.box(-1, 0, -1, 15, 2, 13, c.darkened(0.12), 0.05)       # band
	v.box(0, 2, 0, 14, 4, 12, c, 0.05)                         # crown
	v.box(1, 4, 1, 13, 5, 11, c.lightened(0.06), 0.05)
	v.box(6, 5, 5, 8, 6, 7, c.darkened(0.3), 0.0)              # button
	v.box(1, 0, 13, 13, 1, 17, c.darkened(0.3), 0.05)          # visor
	v.box(5, 1, 13, 9, 4, 14, PAPER, 0.02)                     # envelope badge
	v.box(5, 3, 13, 9, 4, 14, PAPER.darkened(0.12), 0.0)
	v.box(6, 2, 13, 8, 3, 14, Color("#c0302a", 0.55), 0.0)    # red seal (glows a hair)
	return v


static func _torso_vox(skin: Color, vest: Color) -> Vox:
	var v := Vox.new(S)
	v.box(0, 0, 0, 10, 12, 6, skin, 0.06)
	# leather vest: side panels, back, shoulder straps
	v.box(0, 0, 0, 3, 12, 6, vest, 0.07)
	v.box(7, 0, 0, 10, 12, 6, vest, 0.07)
	v.box(0, 0, 0, 10, 12, 1, vest.darkened(0.08), 0.07)
	v.box(3, 9, 0, 4, 12, 6, vest, 0.06)
	v.box(6, 9, 0, 7, 12, 6, vest, 0.06)
	v.box(2, 2, 5, 3, 12, 6, vest.darkened(0.2), 0.04)        # vest edge trim
	v.box(7, 2, 5, 8, 12, 6, vest.darkened(0.2), 0.04)
	# belt, buckle, pouches
	v.box(0, 0, 0, 10, 2, 6, Color("#4e301a"), 0.06)
	v.box(4, 0, 6, 6, 2, 7, METAL, 0.04)
	v.set_v(4, 1, 6, METAL.darkened(0.3))
	v.box(1, 0, 6, 3, 3, 8, Color("#9a7840"), 0.06)
	v.box(7, 0, 6, 9, 3, 8, Color("#9a7840"), 0.06)
	return v


static func _arm_vox(skin: Color, vest: Color) -> Vox:
	var v := Vox.new(S)
	v.box(0, -12, 0, 3, 0, 3, skin, 0.06)
	v.box(0, -4, 0, 3, 0, 3, vest, 0.07)
	v.box(0, -12, 0, 3, -10, 3, skin.lightened(0.05), 0.05)
	return v


static func _leg_vox(pants: Color, boot: Color, side: int) -> Vox:
	var v := Vox.new(S)
	# built for the left leg (+x outward); the right leg is the mirror image
	v.box(0, 6, 0, 4, 14, 4, pants, 0.07)
	v.box(0, 6, 0, 4, 8, 4, pants.darkened(0.15), 0.05)
	v.box(0, 0, -1, 5, 6, 6, boot, 0.07)                        # chunky boot, toe forward
	v.box(0, 5, -1, 5, 6, 5, boot.lightened(0.18), 0.05)        # folded cuff
	v.box(0, 0, -1, 5, 1, 6, boot.darkened(0.35), 0.04)         # sole
	if side < 0:
		var m := Vox.new(S)
		for k in v.cells:
			m.cells[Vector3i(3 - k.x, k.y, k.z)] = v.cells[k]
		return m
	return v


## The backpack from the reference: brown body, lighter flap, gold buckle, red bedroll, letter.
static func _pack_vox() -> Vox:
	var v := Vox.new(S)
	var brown := Color("#7a4a28")
	v.box(1, 0, 0, 11, 11, 7, brown, 0.09)
	v.box(0, 1, 1, 12, 7, 6, brown.darkened(0.08), 0.09)          # side pouches
	v.box(1, 8, 0, 11, 11, 7, brown.lightened(0.12), 0.07)        # flap
	v.box(1, 8, 6, 11, 9, 7, brown.darkened(0.3), 0.05)           # flap edge stitching
	v.box(5, 4, 7, 8, 9, 8, Color("#e0b040"), 0.04)               # gold buckle
	v.box(6, 5, 7, 7, 8, 8, Color("#8a5a18"), 0.0)
	# red bedroll on top (cylinder along X)
	for x in range(-1, 13):
		for y in range(11, 16):
			for z in range(0, 7):
				var dy := (y + 0.5 - 13.5) / 2.5
				var dz := (z + 0.5 - 3.5) / 3.5
				if dy * dy + dz * dz <= 1.0:
					var end := x <= 0 or x >= 11
					v.set_v(x, y, z, Color("#a01828") if end else Color("#c42234"), 0.07)
	v.box(2, 11, 0, 3, 16, 7, Color("#5a3a1e"), 0.04)             # straps
	v.box(9, 11, 0, 10, 16, 7, Color("#5a3a1e"), 0.04)
	# letter poking out of the top
	v.box(4, 15, 2, 9, 19, 3, PAPER, 0.02)
	v.box(4, 15, 2, 9, 16, 3, PAPER.darkened(0.1), 0.0)
	v.box(6, 17, 3, 8, 18, 4, Color("#c0302a"), 0.0)
	# trailing red strap down the side
	v.box(11, 3, 2, 12, 11, 4, Color("#b82030"), 0.06)
	v.box(11, 0, 2, 12, 4, 4, Color("#b82030").darkened(0.15), 0.06)
	return v


# ------------------------------------------------------------------ assembly

static func _parts(skin: Color, vest: Color, hat_color: Color) -> Dictionary:
	var key := "%s|%s|%s" % [skin.to_html(), vest.to_html(), hat_color.to_html()]
	if _cache.has(key):
		return _cache[key]
	var d := {
		"head": _head_vox(skin).build_shaded(Vector3(7, 0, 6)),
		"tongue": _tongue_vox().build_shaded(Vector3(1.5, 5, 1)),
		"earL": _ear_vox(skin, 1).build_shaded(Vector3(0, 3, 0.5)),
		"earR": _ear_vox(skin, -1).build_shaded(Vector3(0, 3, 0.5)),
		"cap": _cap_vox(hat_color).build_shaded(Vector3(7, 0, 6)),
		"torso": _torso_vox(skin, vest).build_shaded(Vector3(5, 0, 3)),
		"armL": _arm_vox(skin, vest).build_shaded(Vector3(1.5, 0, 1.5)),
		"legL": _leg_vox(PANTS, BOOT, 1).build_shaded(Vector3(2, 14, 2)),
		"legR": _leg_vox(PANTS, BOOT, -1).build_shaded(Vector3(2, 14, 2)),
		"pack": _pack_vox().build_shaded(Vector3(6, 0, 7)),
	}
	_cache[key] = d
	return d


static func _mi(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = VMat.solid(S, 4.0)
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	parent.add_child(m)
	return m


static func _joint(parent: Node3D, name: String, pos: Vector3, rig: Dictionary) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	parent.add_child(j)
	rig[name] = j
	return j


## tunic = vest colour. with_hat adds the postal cap; carry_pack adds the backpack.
static func build(vest := LEATHER, skin := SKIN, with_hat := true, hat_color := CAP, carry_pack := true) -> Node3D:
	var p := _parts(skin, vest, hat_color)
	var root := Node3D.new()
	root.name = "GoblinModel"
	var rig := {}
	var hips := _joint(root, "Hips", Vector3(0, 14 * S, 0), rig)
	var spine := _joint(hips, "Spine", Vector3.ZERO, rig)
	_mi(spine, p["torso"])
	var head := _joint(spine, "Head", Vector3(0, 12 * S, 0), rig)
	_mi(head, p["head"])
	var jaw := _joint(head, "Jaw", Vector3(-0.5 * S, 4 * S, 5 * S), rig)
	_mi(jaw, p["tongue"])
	_mi(_joint(head, "EarL", Vector3(7 * S, 0, 0), rig), p["earL"])
	_mi(_joint(head, "EarR", Vector3(-7 * S, 0, 0), rig), p["earR"])
	var cap := _joint(head, "Cap", Vector3.ZERO, rig)
	if with_hat:
		_mi(cap, p["cap"], Vector3(0, 12 * S, 0))
	for side in [1.0, -1.0]:
		var tag := "L" if side > 0 else "R"
		var arm := _joint(spine, "Arm" + tag, Vector3(side * 6.5 * S, 11 * S, 0), rig)
		_mi(arm, p["armL"])
		var leg := _joint(hips, "Leg" + tag, Vector3(side * 2.5 * S, 0, 0), rig)
		_mi(leg, p["legL"] if side > 0 else p["legR"])
	var back := _joint(spine, "Back", Vector3(0, 1 * S, -3 * S), rig)
	if carry_pack:
		_mi(back, p["pack"])
	rig["Pack"] = back
	root.set_meta("rig", rig)
	animate(root, 0.0, 0.0)
	return root


static func rig_of(model: Node3D) -> Dictionary:
	return model.get_meta("rig") as Dictionary


static func back_mount(model: Node3D) -> Node3D:
	return rig_of(model)["Back"] as Node3D


# ------------------------------------------------------------------ animation

## speed01: 0 idle .. 1 full run. t: seconds. Chunky, snappy, Minecraft-ish limb swings.
static func animate(model: Node3D, speed01: float, t: float, carrying := false) -> void:
	var rig := rig_of(model)
	var a := speed01
	var idle := 1.0 - a
	var ph := t * 10.0
	var sw := sin(ph)
	var br := sin(t * 2.2)
	var hips: Node3D = rig["Hips"]
	hips.position.y = 14 * S + absf(sin(ph)) * 0.035 * a + br * 0.004
	var spine: Node3D = rig["Spine"]
	spine.rotation = Vector3(0.06 + 0.16 * a + (0.12 if carrying else 0.0), -sw * 0.12 * a, sw * 0.04 * a)
	spine.scale = Vector3(1.0, 1.0 + br * 0.01, 1.0)
	var head: Node3D = rig["Head"]
	head.rotation = Vector3(-0.06 - 0.1 * a, sin(t * 0.8) * 0.28 * idle + sw * 0.06 * a, sin(t * 1.3) * 0.05 * idle)
	var jaw: Node3D = rig["Jaw"]
	jaw.rotation = Vector3(0.1 + sin(t * 7.0) * 0.12 + sw * 0.15 * a, 0.0, sin(t * 5.0) * 0.12)
	var ear_l: Node3D = rig["EarL"]
	var ear_r: Node3D = rig["EarR"]
	var flap := sin(ph * 2.0 + 0.6) * 0.3 * a + sin(t * 1.7) * 0.05
	var twitch := maxf(0.0, sin(t * 0.9)) * maxf(0.0, sin(t * 7.0)) * 0.3
	ear_l.rotation = Vector3(0, 0, 0.12 + flap + twitch)
	ear_r.rotation = Vector3(0, 0, -0.12 - flap)
	(rig["Cap"] as Node3D).rotation = Vector3(sin(ph * 2.0 - 0.9) * 0.05 * a, 0.0, sin(ph - 0.4) * 0.04 * a)
	var legl: Node3D = rig["LegL"]
	var legr: Node3D = rig["LegR"]
	legl.rotation.x = sw * 0.95 * a
	legr.rotation.x = -sw * 0.95 * a
	var arml: Node3D = rig["ArmL"]
	var armr: Node3D = rig["ArmR"]
	arml.rotation = Vector3(-sw * 0.8 * a - 0.04, 0.0, 0.1 + 0.03 * br * idle + 0.05 * a)
	armr.rotation = Vector3(sw * 0.8 * a - 0.04, 0.0, -0.1 - 0.03 * br * idle - 0.05 * a)
	(rig["Back"] as Node3D).rotation = Vector3(sin(ph * 2.0 - 1.0) * 0.06 * a, 0.0, sin(ph - 0.8) * 0.05 * a)


static func pose_kick(model: Node3D, k: float) -> void:
	var rig := rig_of(model)
	(rig["LegR"] as Node3D).rotation.x = -1.55 * k
	(rig["LegL"] as Node3D).rotation.x = 0.2 * k
	(rig["Spine"] as Node3D).rotation.x -= 0.22 * k


static func pose_wave(model: Node3D, t: float) -> void:
	var rig := rig_of(model)
	(rig["ArmR"] as Node3D).rotation = Vector3(0.0, 0.0, -2.55 + sin(t * 9.0) * 0.35)


## Weapon swing for the third-person body (only its shadow is seen in first person).
static func pose_swing(model: Node3D, k: float) -> void:
	var rig := rig_of(model)
	var wind := Style.smooth(0.0, 0.35, k)
	var strike := Style.smooth(0.35, 0.55, k)
	var back := Style.smooth(0.7, 1.0, k)
	var ang := lerpf(-0.2, -2.7, wind)
	ang = lerpf(ang, -0.5, strike)
	ang = lerpf(ang, -0.2, back)
	(rig["ArmR"] as Node3D).rotation = Vector3(ang, 0.0, -0.15)
	(rig["Spine"] as Node3D).rotation.x += 0.25 * strike * (1.0 - back)
