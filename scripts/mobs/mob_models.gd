class_name MobModels
extends RefCounted
## Voxel bodies and procedural animation for every mob archetype. Each model is a small
## Node3D rig ("rig" meta: name -> joint). Animate with MobModels.animate().

const S := 0.05
const BONE := Color("#dcd6c0")
const DARK := Color("#1e1a22")

static var _cache := {}


static func _mi(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO, alpha := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation_degrees = rot
	m.set_meta("alpha", alpha)
	parent.add_child(m)
	return m


static func _joint(parent: Node3D, rig: Dictionary, name: String, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = name
	j.position = pos
	parent.add_child(j)
	rig[name] = j
	return j


static func rig_of(root: Node3D) -> Dictionary:
	return root.get_meta("rig") as Dictionary


static func _col(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


static func build(kind: String, theme: String) -> Node3D:
	var pal: Dictionary = MobDB.PALETTES.get(theme, MobDB.PALETTES["crypt"])
	var key := kind + "|" + theme
	if not _cache.has(key):
		_cache[key] = _make_parts(kind, pal)
	var parts: Dictionary = _cache[key]
	var root := Node3D.new()
	root.name = "MobModel"
	var rig := {}
	var mtype: String = str(MobDB.KINDS[kind]["model"])
	root.set_meta("mtype", mtype)
	root.set_meta("kind", kind)
	match mtype:
		"humanoid":
			var hips := _joint(root, rig, "Hips", Vector3(0, 12 * S, 0))
			var spine := _joint(hips, rig, "Spine", Vector3.ZERO)
			_mi(spine, parts["torso"], Vector3.ZERO)
			var head := _joint(spine, rig, "Head", Vector3(0, 12 * S, 0))
			_mi(head, parts["head"])
			for side in [1.0, -1.0]:
				var tag := "L" if side > 0 else "R"
				var arm := _joint(spine, rig, "Arm" + tag, Vector3(side * parts["shoulder"] * S, 11 * S, 0))
				_mi(arm, parts["arm"])
				var leg := _joint(hips, rig, "Leg" + tag, Vector3(side * 2.2 * S, 0, 0))
				_mi(leg, parts["leg"])
			if parts.has("weapon"):
				var hand := _joint(rig["ArmR"], rig, "HandR", Vector3(0, -11 * S, 1 * S))
				_mi(hand, parts["weapon"], Vector3.ZERO, Vector3(-90, 0, 0))
			if parts.has("weapon_l"):
				var handl := _joint(rig["ArmL"], rig, "HandL", Vector3(0, -11 * S, 1 * S))
				_mi(handl, parts["weapon_l"], Vector3.ZERO, Vector3(-90, 0, 0))
			if parts.has("back"):
				_mi(spine, parts["back"], Vector3(0, 6 * S, -3 * S))
			if parts.has("wing"):
				for side in [1.0, -1.0]:
					var w := _joint(spine, rig, "Wing" + ("L" if side > 0 else "R"), Vector3(side * 2 * S, 9 * S, -3 * S))
					_mi(w, parts["wing"] if side > 0 else parts["wingR"])
		"quad":
			var body := _joint(root, rig, "Body", Vector3(0, parts["leg_h"] * S, 0))
			_mi(body, parts["body"])
			var head2 := _joint(body, rig, "Head", Vector3(0, parts["head_y"] * S, parts["head_z"] * S))
			_mi(head2, parts["head"])
			var tail := _joint(body, rig, "Tail", Vector3(0, parts["tail_y"] * S, -parts["body_len"] * S * 0.5))
			_mi(tail, parts["tail"])
			for lg in [["FL", 1.0, 1.0], ["FR", -1.0, 1.0], ["BL", 1.0, -1.0], ["BR", -1.0, -1.0]]:
				var l := _joint(body, rig, "Leg" + lg[0], Vector3(lg[1] * parts["leg_x"] * S, 0, lg[2] * parts["leg_z"] * S))
				_mi(l, parts["leg"])
		"blob":
			var b := _joint(root, rig, "Body", Vector3.ZERO)
			_mi(b, parts["body"], Vector3.ZERO, Vector3.ZERO, false)
			var core := _joint(b, rig, "Core", Vector3(0, 6 * S, 0))
			_mi(core, parts["core"])
		"bat":
			var bd := _joint(root, rig, "Body", Vector3(0, 0, 0))
			_mi(bd, parts["body"])
			for side in [1.0, -1.0]:
				var w2 := _joint(bd, rig, "Wing" + ("L" if side > 0 else "R"), Vector3(side * 2 * S, 1 * S, 0))
				_mi(w2, parts["wing"] if side > 0 else parts["wingR"])
		"mushroom":
			var st := _joint(root, rig, "Body", Vector3(0, 2 * S, 0))
			_mi(st, parts["stalk"])
			var cap := _joint(st, rig, "Cap", Vector3(0, 8 * S, 0))
			_mi(cap, parts["cap"])
			for side in [1.0, -1.0]:
				var f := _joint(st, rig, "Foot" + ("L" if side > 0 else "R"), Vector3(side * 2 * S, -2 * S, 0))
				_mi(f, parts["foot"])
		"keg":
			var kb := _joint(root, rig, "Body", Vector3(0, 5 * S, 0))
			_mi(kb, parts["body"])
			var fuse := _joint(kb, rig, "Fuse", Vector3(0, 12 * S, 0))
			_mi(fuse, parts["fuse"])
			for side in [1.0, -1.0]:
				var tag2 := "L" if side > 0 else "R"
				var kl := _joint(kb, rig, "Leg" + tag2, Vector3(side * 2.5 * S, -1 * S, 0))
				_mi(kl, parts["leg"])
				var ka := _joint(kb, rig, "Arm" + tag2, Vector3(side * 5.5 * S, 8 * S, 0))
				_mi(ka, parts["arm"])
		"chest":
			var cb := _joint(root, rig, "Body", Vector3(0, 3 * S, 0))
			_mi(cb, parts["body"])
			var lid := _joint(cb, rig, "Lid", Vector3(0, 7 * S, -4 * S))
			_mi(lid, parts["lid"])
			for lg2 in [[1.0, 1.0], [-1.0, 1.0], [1.0, -1.0], [-1.0, -1.0]]:
				var cl := _joint(cb, rig, "Leg%d%d" % [lg2[0], lg2[1]], Vector3(lg2[0] * 4 * S, -1 * S, lg2[1] * 2.5 * S))
				_mi(cl, parts["leg"])
	root.set_meta("rig", rig)
	return root


static func is_ghostly(kind: String) -> bool:
	return kind == "ghost"


# ============================================================== parts

static func _make_parts(kind: String, pal: Dictionary) -> Dictionary:
	var main: Color = pal["main"]
	var acc: Color = pal["accent"]
	var glow: Color = pal["glow"]
	var d := {}
	match kind:
		"skeleton", "archer":
			var bone := main.lerp(BONE, 0.55).darkened(0.16)
			d = _skeleton(bone, acc, glow, kind == "archer")
		"intern":
			d = _intern(main, acc)
		"imp":
			d = _imp(main, acc, glow)
		"golem":
			d = _golem(main, acc, glow)
		"ghost":
			d = _ghost(main, glow)
		"rat":
			d = _rat(main, acc)
		"hound":
			d = _hound(main, acc, glow)
		"slime", "slime_small":
			d = _slime(main, glow)
		"bat":
			d = _bat(main, acc, glow)
		"mushroom":
			d = _mushroom(main, acc, glow)
		"bomber":
			d = _keg(main, acc, glow)
		"mimic":
			d = _mimic(acc)
	return d


static func _b(v: Vox, ox := 0.0, oy := 0.0, oz := 0.0) -> ArrayMesh:
	return v.build(Vector3(ox, oy, oz))


static func _skeleton(bone: Color, acc: Color, glow: Color, archer: bool) -> Dictionary:
	var h := Vox.new(S)
	h.box(0, 0, 0, 8, 8, 8, bone, 0.06)
	h.box(1, 5, 7, 3, 7, 8, DARK, 0.0)                      # eye sockets
	h.box(5, 5, 7, 7, 7, 8, DARK, 0.0)
	h.box(1, 5, 7, 2, 6, 8, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	h.box(5, 5, 7, 6, 6, 8, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	h.box(3, 3, 7, 5, 4, 8, DARK, 0.0)                      # nose
	h.box(1, 0, 7, 7, 2, 8, DARK, 0.0)                      # teeth gap
	for x in range(1, 7, 2):
		h.box(x, 0, 7, x + 1, 2, 8, bone.lightened(0.1), 0.02)
	h.box(0, 6, 0, 8, 8, 1, bone.darkened(0.12), 0.04)
	if archer:
		h.box(-1, 7, -1, 9, 9, 9, acc, 0.06)                # hood
		h.box(0, 5, -1, 8, 7, 0, acc.darkened(0.2), 0.04)
	var t := Vox.new(S)
	t.box(3, 0, 1, 5, 12, 3, bone, 0.05)                    # spine
	for y in range(3, 12, 2):
		t.box(0, y, 0, 8, y + 1, 4, bone.darkened(0.04), 0.05)
		t.box(3, y, 3, 5, y + 1, 4, bone, 0.04)
	t.box(1, 0, 0, 7, 3, 4, bone.darkened(0.1), 0.05)       # pelvis
	t.box(2, 9, 4, 6, 12, 5, acc, 0.05)                     # clerk shirt front
	t.box(3, 5, 4, 5, 10, 5, Color("#b03a3a"), 0.04)        # tie
	var arm := Vox.new(S)
	arm.box(0, -11, 0, 2, 0, 2, bone, 0.05)
	arm.box(-1, -13, -1, 3, -11, 3, bone.lightened(0.05), 0.04)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 2, 11, 2, bone, 0.05)
	leg.box(-1, -1, -1, 3, 1, 4, bone.darkened(0.1), 0.04)
	var parts := {
		"head": _b(h, 4, 0, 4), "torso": _b(t, 4, 0, 2), "arm": _b(arm, 1, 0, 1), "leg": _b(leg, 1, 11, 1), "shoulder": 5.0,
	}
	if archer:
		var bow := Vox.new(S)
		for y in range(0, 22):
			var bend := int(round(sin(float(y) / 21.0 * PI) * 5.0))
			bow.box(bend, y, 0, bend + 1, y + 1, 1, Color("#7a4a28"), 0.05)
		bow.box(0, 0, 0, 1, 22, 1, Color("#e8e0c8"), 0.0)
		parts["weapon_l"] = _b(bow, 0, 11, 0)
		var q := Vox.new(S)
		q.box(0, 0, 0, 4, 10, 3, Color("#6a4a2a"), 0.06)
		for x in range(0, 4, 2):
			q.box(x, 10, 1, x + 1, 13, 2, Color("#e8e0c8"), 0.0)
		parts["back"] = _b(q, 2, 0, 1)
	else:
		var sw := Vox.new(S)
		sw.box(0, 0, 0, 2, 4, 2, Color("#5a3a1e"), 0.05)
		sw.box(-2, 4, 0, 4, 5, 2, Color("#8a7a5a"), 0.04)
		sw.box(0, 5, 0, 2, 20, 1, Color("#a8a49a"), 0.07)
		sw.box(0, 5, 0, 1, 20, 1, Color("#80786a"), 0.05)
		parts["weapon"] = _b(sw, 1, 0, 1)
	return parts


static func _intern(main: Color, acc: Color) -> Dictionary:
	var skin := main.lerp(Color("#8aa070"), 0.5)
	var shirt := Color("#e8e4d8")
	var h := Vox.new(S)
	h.box(0, 0, 0, 9, 8, 8, skin, 0.07)
	h.box(0, 7, 0, 9, 9, 8, Color("#4a3a2a"), 0.08)             # messy hair
	h.box(1, 5, 8, 4, 7, 9, Color("#f0f0e0"), 0.02)             # eyes
	h.box(5, 5, 8, 8, 7, 9, Color("#f0f0e0"), 0.02)
	h.box(2, 5, 8, 3, 6, 9, DARK, 0.0)
	h.box(6, 5, 8, 7, 6, 9, DARK, 0.0)
	h.box(1, 4, 8, 4, 5, 9, Color("#7a5a8a"), 0.04)             # eye bags
	h.box(5, 4, 8, 8, 5, 9, Color("#7a5a8a"), 0.04)
	h.box(2, 1, 8, 7, 3, 9, Color("#4a0c14"), 0.0)              # moaning mouth
	h.box(3, 2, 8, 6, 3, 9, Color("#c04050"), 0.0)
	var t := Vox.new(S)
	t.box(0, 0, 0, 10, 12, 5, shirt, 0.05)
	t.box(0, 0, 0, 10, 2, 5, Color("#3a3a46"), 0.04)            # belt/trousers top
	t.box(4, 1, 5, 6, 11, 6, acc, 0.04)                         # tie
	t.box(4, 10, 5, 6, 12, 6, acc.darkened(0.2), 0.0)
	t.box(1, 6, 5, 4, 9, 6, Color("#f4e050"), 0.02)             # ID badge
	t.box(6, 4, 5, 9, 6, 6, Color("#4a8a4a"), 0.05)             # coffee stain
	var arm := Vox.new(S)
	arm.box(0, -12, 0, 3, 0, 3, shirt, 0.05)
	arm.box(0, -14, 0, 3, -11, 3, skin, 0.06)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 3, 12, 3, Color("#3a3a46"), 0.06)
	leg.box(-1, -1, -1, 4, 2, 5, Color("#2a1a12"), 0.05)
	var papers := Vox.new(S)
	papers.box(0, 0, 0, 8, 6, 6, Color("#efe6cc"), 0.03)
	papers.box(0, 2, 0, 8, 3, 6, Color("#cfc6a8"), 0.03)
	papers.box(2, 6, 1, 4, 8, 3, Color("#f08a4a"), 0.0)
	return {"head": _b(h, 4.5, 0, 4), "torso": _b(t, 5, 0, 2.5), "arm": _b(arm, 1.5, 0, 1.5), "leg": _b(leg, 1.5, 12, 1.5),
		"shoulder": 6.5, "weapon": _b(papers, 4, 0, 3)}


static func _imp(main: Color, acc: Color, glow: Color) -> Dictionary:
	var skin := main.lerp(Color("#d83a2a"), 0.5)
	var h := Vox.new(S)
	h.box(0, 0, 0, 8, 7, 7, skin, 0.06)
	h.box(1, 4, 7, 3, 6, 8, Color("#fff0a0"), 0.0)
	h.box(5, 4, 7, 7, 6, 8, Color("#fff0a0"), 0.0)
	h.box(2, 4, 7, 3, 5, 8, DARK, 0.0)
	h.box(5, 4, 7, 6, 5, 8, DARK, 0.0)
	h.box(1, 1, 7, 7, 2, 8, DARK, 0.0)
	h.box(2, 1, 7, 3, 2, 8, Color("#f4ecd0"), 0.0)
	h.box(5, 1, 7, 6, 2, 8, Color("#f4ecd0"), 0.0)
	for hx in [0, 6]:                                              # horns
		h.box(hx, 7, 1, hx + 2, 10, 3, Color("#2a2020"), 0.04)
		h.box(hx + (-1 if hx == 0 else 1), 9, 1, hx + (0 if hx == 0 else 2), 12, 3, Color("#2a2020"), 0.04)
	var t := Vox.new(S)
	t.box(0, 0, 0, 8, 10, 4, skin, 0.06)
	t.box(2, 0, 4, 6, 6, 5, skin.lightened(0.15), 0.05)
	t.box(0, -4, 1, 1, 0, 2, skin.darkened(0.1), 0.0)            # tail
	var arm := Vox.new(S)
	arm.box(0, -9, 0, 2, 0, 2, skin, 0.06)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 2, 8, 2, skin.darkened(0.1), 0.06)
	leg.box(-1, -1, -1, 3, 1, 3, Color("#2a2020"), 0.04)
	var wing := Vox.new(S)
	for i in 10:
		wing.box(i, -i / 3, 0, i + 1, 8 - i / 2, 1, Color("#7a1a1a") if i % 3 else Color("#2a2020"), 0.05)
	wing.box(0, 0, 0, 10, 1, 1, Color("#2a2020"), 0.04)
	var wingr := Vox.new(S)
	for k in wing.cells:
		wingr.cells[Vector3i(-1 - k.x, k.y, k.z)] = wing.cells[k]
	var fork := Vox.new(S)
	fork.box(0, 0, 0, 1, 18, 1, Color("#3a3a46"), 0.03)
	fork.box(-2, 17, 0, 3, 18, 1, Color("#3a3a46"), 0.03)
	for fx in [-2, 0, 2]:
		fork.box(fx, 18, 0, fx + 1, 22, 1, Color("#ff9a3a", 0.5), 0.0)
	return {"head": _b(h, 4, 0, 3.5), "torso": _b(t, 4, 0, 2), "arm": _b(arm, 1, 0, 1), "leg": _b(leg, 1, 8, 1), "shoulder": 5.0,
		"wing": _b(wing, 0, 0, 0), "wingR": _b(wingr, 0, 0, 0), "weapon": _b(fork, 0.5, 0, 0.5)}


static func _golem(main: Color, acc: Color, glow: Color) -> Dictionary:
	var stone := main.lerp(Color("#8a8a92"), 0.6)
	var h := Vox.new(S)
	h.cobble(0, 0, 0, 7, 6, 7, stone, 2)
	h.box(1, 3, 6, 3, 4, 7, Color(glow.r, glow.g, glow.b, 0.3), 0.0)
	h.box(4, 3, 6, 6, 4, 7, Color(glow.r, glow.g, glow.b, 0.3), 0.0)
	var t := Vox.new(S)
	t.cobble(0, 0, 0, 14, 13, 8, stone, 3)
	t.box(5, 4, 8, 9, 8, 9, Color(glow.r, glow.g, glow.b, 0.25), 0.0)    # core
	t.box(0, 10, 0, 3, 14, 8, stone.darkened(0.12), 0.05)
	t.box(11, 10, 0, 14, 14, 8, stone.darkened(0.12), 0.05)
	t.box(1, 9, 1, 3, 11, 3, Color("#5a8a3a"), 0.08)             # moss
	var arm := Vox.new(S)
	arm.cobble(0, -14, 0, 5, 0, 5, stone, 3)
	arm.box(-1, -17, -1, 6, -13, 6, stone.darkened(0.1), 0.05)
	var leg := Vox.new(S)
	leg.cobble(0, 0, 0, 5, 9, 5, stone.darkened(0.1), 3)
	leg.box(-1, -1, -1, 6, 1, 7, stone.darkened(0.2), 0.05)
	return {"head": _b(h, 3.5, 0, 3.5), "torso": _b(t, 7, 0, 4), "arm": _b(arm, 2.5, 0, 2.5), "leg": _b(leg, 2.5, 9, 2.5), "shoulder": 9.0}


static func _ghost(main: Color, glow: Color) -> Dictionary:
	var sheet := Color("#e8f0f0")
	sheet.a = 1.0
	var h := Vox.new(S)
	h.box(0, 0, 0, 8, 8, 8, sheet, 0.04)
	h.box(1, 4, 7, 3, 6, 8, DARK, 0.0)
	h.box(5, 4, 7, 7, 6, 8, DARK, 0.0)
	h.box(3, 1, 7, 5, 3, 8, DARK, 0.0)
	h.box(0, 8, 1, 8, 9, 7, sheet.darkened(0.06), 0.04)
	var t := Vox.new(S)
	for y in 14:
		var r := 3.2 + float(y) * 0.28
		var ragged := y < 3 and (y + int(r)) % 2 == 0
		t.cyl_y(0.0, 0.0, y, y + 1, r - (1.0 if ragged else 0.0), r - (1.0 if ragged else 0.0), sheet.darkened(0.04 * (14 - y) / 14.0), 0.03)
	var arm := Vox.new(S)
	arm.box(0, -8, 0, 2, 0, 2, sheet, 0.03)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 1, 1, 1, sheet, 0.0)
	return {"head": _b(h, 4, 0, 4), "torso": _b(t, 0, -4, 0), "arm": _b(arm, 1, 0, 1), "leg": _b(leg, 0, 0, 0), "shoulder": 5.0}


static func _rat(main: Color, acc: Color) -> Dictionary:
	var fur := Color("#6a5a4e").lerp(main, 0.2)
	var body := Vox.new(S)
	body.box(0, 0, 0, 6, 5, 10, fur, 0.07)
	body.box(1, 5, 1, 5, 6, 8, fur.darkened(0.08), 0.06)
	var head := Vox.new(S)
	head.box(0, 0, 0, 5, 5, 4, fur.lightened(0.05), 0.06)
	head.box(1, 0, 4, 4, 3, 7, fur.lightened(0.1), 0.06)
	head.box(2, 2, 7, 3, 3, 8, Color("#e8a0a0"), 0.0)             # nose
	head.box(0, 4, 3, 1, 5, 4, Color("#e8a0a0"), 0.0)
	head.box(0, 5, 1, 1, 7, 3, fur, 0.05)                         # ears
	head.box(4, 5, 1, 5, 7, 3, fur, 0.05)
	head.box(0, 3, 3, 1, 4, 4, Color("#ff3a3a", 0.4), 0.0)        # red eyes
	head.box(4, 3, 3, 5, 4, 4, Color("#ff3a3a", 0.4), 0.0)
	head.box(1, 0, 6, 2, 1, 7, Color("#f4ecd0"), 0.0)             # teeth + stolen envelope
	head.box(2, -1, 5, 5, 1, 6, Color("#efe6cc"), 0.0)
	var tail := Vox.new(S)
	tail.box(0, 0, 0, 1, 1, 8, Color("#e8a0a0"), 0.04)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 1, 3, 2, fur.darkened(0.12), 0.05)
	return {"body": _b(body, 3, 0, 5), "head": _b(head, 2.5, 0, 2), "tail": _b(tail, 0.5, 0, 0), "leg": _b(leg, 0.5, 3, 1),
		"leg_h": 3, "head_y": 1.0, "head_z": 5.0, "tail_y": 2.0, "body_len": 10.0, "leg_x": 2.2, "leg_z": 3.0}


static func _hound(main: Color, acc: Color, glow: Color) -> Dictionary:
	var fur := main.darkened(0.15).lerp(Color("#5a3a2a"), 0.5)
	var body := Vox.new(S)
	body.box(0, 0, 0, 9, 8, 15, fur, 0.07)
	body.box(0, 7, 0, 9, 9, 15, fur.darkened(0.15), 0.07)
	body.box(2, 8, 2, 7, 11, 12, fur.darkened(0.25), 0.07)         # mane / spikes
	for z in range(3, 12, 3):
		body.box(3, 11, z, 6, 13, z + 1, Color(glow.r, glow.g, glow.b, 0.45), 0.0)
	var head := Vox.new(S)
	head.box(0, 0, 0, 8, 8, 6, fur, 0.06)
	head.box(1, 0, 6, 7, 4, 11, fur.lightened(0.06), 0.06)
	head.box(1, 0, 10, 7, 1, 11, DARK, 0.0)
	for tx in [1, 6]:
		head.box(tx, -1, 9, tx + 1, 1, 10, Color("#f4ecd0"), 0.0)
	head.box(0, 5, 5, 2, 6, 6, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	head.box(6, 5, 5, 8, 6, 6, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	head.box(0, 8, 1, 2, 11, 3, fur.darkened(0.2), 0.05)
	head.box(6, 8, 1, 8, 11, 3, fur.darkened(0.2), 0.05)
	head.box(2, 0, 3, 6, 1, 5, Color("#b03a3a"), 0.0)             # collar tag
	var tail := Vox.new(S)
	tail.box(0, 0, 0, 2, 2, 8, fur.darkened(0.1), 0.05)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 3, 7, 3, fur.darkened(0.1), 0.06)
	leg.box(0, -1, -1, 3, 1, 4, DARK, 0.04)
	return {"body": _b(body, 4.5, 0, 7.5), "head": _b(head, 4, 4, 0), "tail": _b(tail, 1, 0, 0), "leg": _b(leg, 1.5, 7, 1.5),
		"leg_h": 7, "head_y": 4.0, "head_z": 6.5, "tail_y": 6.0, "body_len": 15.0, "leg_x": 3.0, "leg_z": 5.0}


static func _slime(main: Color, glow: Color) -> Dictionary:
	var c := main.lerp(Color("#58c05a"), 0.35)
	var body := Vox.new(S)
	body.box(0, 0, 0, 14, 11, 14, c, 0.05)
	for corner in [[0, 0], [13, 0], [0, 13], [13, 13]]:
		body.remove_box(corner[0], 0, corner[1], corner[0] + 1, 11, corner[1] + 1)
		body.remove_box(corner[0], 10, corner[1], corner[0] + 1, 11, corner[1] + 1)
	body.remove_box(0, 10, 0, 14, 11, 1)
	body.remove_box(0, 10, 13, 14, 11, 14)
	body.box(2, 8, 2, 12, 11, 12, c.lightened(0.12), 0.05)
	body.box(0, 0, 0, 14, 1, 14, c.darkened(0.12), 0.04)
	# eyes
	body.box(3, 5, 14, 5, 8, 15, Color("#f4f0d8"), 0.0)
	body.box(9, 5, 14, 11, 8, 15, Color("#f4f0d8"), 0.0)
	body.box(4, 6, 14, 5, 7, 15, DARK, 0.0)
	body.box(10, 6, 14, 11, 7, 15, DARK, 0.0)
	body.box(5, 3, 14, 9, 4, 15, DARK, 0.0)
	var core := Vox.new(S)
	core.box(0, 0, 0, 5, 5, 3, Color(glow.r, glow.g, glow.b, 0.4), 0.0)       # floating junk in the goo
	core.box(1, 1, 0, 4, 2, 3, Color("#efe6cc"), 0.0)
	return {"body": _b(body, 7, 0, 7), "core": _b(core, 2.5, 0, 1.5)}


static func _bat(main: Color, acc: Color, glow: Color) -> Dictionary:
	var fur := Color("#3a3446").lerp(main, 0.2)
	var body := Vox.new(S)
	body.box(0, 0, 0, 5, 5, 6, fur, 0.07)
	body.box(0, 4, 0, 1, 7, 2, fur, 0.04)
	body.box(4, 4, 0, 5, 7, 2, fur, 0.04)
	body.box(1, 2, 6, 2, 3, 7, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	body.box(3, 2, 6, 4, 3, 7, Color(glow.r, glow.g, glow.b, 0.35), 0.0)
	body.box(1, 0, 6, 2, 1, 7, Color("#f4ecd0"), 0.0)
	body.box(3, 0, 6, 4, 1, 7, Color("#f4ecd0"), 0.0)
	var wing := Vox.new(S)
	for i in 11:
		var h := 6 - int(i * 0.35)
		var col := fur if i % 3 == 0 else fur.darkened(0.25)
		wing.box(i, -h / 2, 0, i + 1, h - h / 2, 1, col, 0.06)
	wing.box(0, 0, 0, 11, 1, 1, fur.lightened(0.1), 0.04)
	var wingr := Vox.new(S)
	for k in wing.cells:
		wingr.cells[Vector3i(-1 - k.x, k.y, k.z)] = wing.cells[k]
	return {"body": _b(body, 2.5, 2.5, 3), "wing": _b(wing, 0, 0, 0.5), "wingR": _b(wingr, 0, 0, 0.5)}


static func _mushroom(main: Color, acc: Color, glow: Color) -> Dictionary:
	var cap_c := main.lerp(Color("#b04aa0"), 0.35)
	var stalk := Vox.new(S)
	stalk.box(0, 0, 0, 7, 9, 7, Color("#ecdcc0"), 0.06)
	stalk.box(1, 5, 7, 3, 7, 8, DARK, 0.0)
	stalk.box(4, 5, 7, 6, 7, 8, DARK, 0.0)
	stalk.box(2, 2, 7, 5, 3, 8, Color("#8a3a4a"), 0.0)
	stalk.box(0, 0, 0, 7, 1, 7, Color("#c8b898"), 0.04)
	var cap := Vox.new(S)
	cap.ellipsoid(8.0, 1.0, 8.0, 9.0, 5.0, 9.0, cap_c, 0.06)
	cap.remove_box(-3, -6, -3, 20, 0, 20)
	for sp in [Vector3i(4, 4, 8), Vector3i(11, 4, 5), Vector3i(8, 5, 12), Vector3i(12, 3, 10), Vector3i(5, 3, 4)]:
		cap.box(sp.x, sp.y, sp.z, sp.x + 2, sp.y + 1, sp.z + 2, Color(glow.r, glow.g, glow.b, 0.4), 0.0)
	var foot := Vox.new(S)
	foot.box(0, 0, 0, 2, 2, 3, Color("#ecdcc0"), 0.05)
	return {"stalk": _b(stalk, 3.5, 0, 3.5), "cap": _b(cap, 8, 0, 8), "foot": _b(foot, 1, 0, 1.5)}


static func _keg(main: Color, acc: Color, glow: Color) -> Dictionary:
	var wood := Color("#8a5a2e")
	var body := Vox.new(S)
	body.cyl_y(0.0, 0.0, 0, 12, 5.0, 5.0, wood, 0.07)
	for by in [1, 5, 10]:
		body.cyl_y(0.0, 0.0, by, by + 1, 5.4, 5.4, Color("#5a5a66"), 0.04)
	body.box(-3, 6, 4, -1, 8, 5, Color("#f4f0d8"), 0.0)           # eyes
	body.box(1, 6, 4, 3, 8, 5, Color("#f4f0d8"), 0.0)
	body.box(-2, 6, 5, -1, 7, 6, DARK, 0.0)
	body.box(2, 6, 5, 3, 7, 6, DARK, 0.0)
	body.box(-3, 3, 5, 3, 4, 6, DARK, 0.0)                         # grin
	body.box(-3, 4, 5, -2, 5, 6, DARK, 0.0)
	body.box(2, 4, 5, 3, 5, 6, DARK, 0.0)
	body.box(-4, 8, 4, 4, 9, 5, Color("#c0302a"), 0.0)             # "BOOM" sticker
	var fuse := Vox.new(S)
	fuse.box(0, 0, 0, 1, 4, 1, Color("#e8dcb0"), 0.03)
	fuse.box(0, 4, 0, 1, 5, 1, Color(1.0, 0.7, 0.2, 0.2), 0.0)
	fuse.box(-1, 5, -1, 2, 7, 2, Color(1.0, 0.85, 0.3, 0.1), 0.0)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 2, 4, 2, main.darkened(0.2), 0.06)
	leg.box(-1, -1, -1, 3, 1, 4, DARK, 0.03)
	var arm := Vox.new(S)
	arm.box(0, -6, 0, 2, 0, 2, main.lerp(Color("#74b83c"), 0.6), 0.06)
	return {"body": _b(body, 0, 0, 0), "fuse": _b(fuse, 0.5, 0, 0.5), "leg": _b(leg, 1, 4, 1), "arm": _b(arm, 1, 0, 1)}


static func _mimic(acc: Color) -> Dictionary:
	var wood := Color("#8a5a2e")
	var body := Vox.new(S)
	body.box(0, 0, 0, 14, 7, 10, wood, 0.07)
	body.planks(0, 0, 0, 14, 7, 1, wood, true, 2, 7)
	body.box(0, 0, 0, 14, 1, 10, wood.darkened(0.35), 0.04)
	for bx in [2, 11]:
		body.box(bx, 0, -1, bx + 1, 7, 11, Color("#5a5a66"), 0.04)
	body.box(1, 6, 1, 13, 7, 9, Color("#d03a4a"), 0.05)             # red gullet
	for tx in range(1, 13, 2):                                       # lower teeth
		body.box(tx, 7, 9, tx + 1, 9, 10, Color("#f4ecd0"), 0.0)
		body.box(tx, 7, 0, tx + 1, 9, 1, Color("#f4ecd0"), 0.0)
	body.box(4, 6, 2, 10, 8, 6, Color("#e04a68"), 0.04)             # tongue
	var lid := Vox.new(S)
	lid.box(0, 0, 0, 14, 4, 10, wood.lightened(0.05), 0.07)
	lid.box(1, 4, 1, 13, 6, 9, wood.lightened(0.1), 0.07)
	for bx in [2, 11]:
		lid.box(bx, 0, -1, bx + 1, 6, 11, Color("#5a5a66"), 0.04)
	lid.box(6, 0, 10, 8, 3, 11, GOLD_LOCK, 0.0)
	for tx in range(1, 13, 2):
		lid.box(tx, -2, 9, tx + 1, 0, 10, Color("#f4ecd0"), 0.0)
		lid.box(tx, -2, 0, tx + 1, 0, 1, Color("#f4ecd0"), 0.0)
	lid.box(2, 2, 10, 4, 4, 11, Color("#ffe84a", 0.4), 0.0)         # eyes
	lid.box(10, 2, 10, 12, 4, 11, Color("#ffe84a", 0.4), 0.0)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 3, 5, 3, Color("#5a3a1e"), 0.06)
	leg.box(-1, -1, -1, 4, 1, 4, Color("#3a2a18"), 0.04)
	return {"body": _b(body, 7, 0, 5), "lid": _b(lid, 7, 0, 0), "leg": _b(leg, 1.5, 5, 1.5)}


const GOLD_LOCK := Color("#e6b840")


# ============================================================== animation

## pose: idle / walk / windup / strike / recover / stun / dead.  k: progress inside that pose (0..1).
static func animate(root: Node3D, t: float, speed01: float, pose: String, k: float) -> void:
	var rig := rig_of(root)
	var mtype: String = root.get_meta("mtype")
	var kind: String = root.get_meta("kind")
	var ph := t * (9.0 if kind != "intern" and kind != "golem" else 5.5)
	var sw := sin(ph) * speed01
	match mtype:
		"humanoid":
			_anim_humanoid(rig, kind, t, sw, speed01, pose, k)
		"quad":
			_anim_quad(rig, kind, t, sw, speed01, pose, k)
		"blob":
			_anim_blob(rig, t, speed01, pose, k)
		"bat":
			_anim_bat(rig, t, pose, k)
		"mushroom":
			_anim_mushroom(rig, t, speed01, pose, k)
		"keg":
			_anim_keg(rig, t, sw, speed01, pose, k)
		"chest":
			_anim_chest(rig, t, speed01, pose, k)


static func _anim_humanoid(rig: Dictionary, kind: String, t: float, sw: float, sp: float, pose: String, k: float) -> void:
	var hips: Node3D = rig["Hips"]
	var spine: Node3D = rig["Spine"]
	var head: Node3D = rig["Head"]
	var al: Node3D = rig["ArmL"]
	var ar: Node3D = rig["ArmR"]
	var ll: Node3D = rig["LegL"]
	var lr: Node3D = rig["LegR"]
	var float_kind := kind == "ghost" or kind == "imp"
	var hunch := 0.25 if kind == "intern" else 0.0
	hips.position.y = (12 if kind != "ghost" else 6) * S + (absf(sin(t * 9.0)) * 0.03 * sp if not float_kind else sin(t * 2.5) * 0.08)
	spine.rotation = Vector3(hunch + 0.1 * sp, -sw * 0.15, 0.0)
	head.rotation = Vector3(-hunch * 0.5, sin(t * 0.9) * 0.2 * (1.0 - sp), 0.0)
	ll.rotation.x = sw * 0.9
	lr.rotation.x = -sw * 0.9
	if kind == "ghost":
		ll.rotation.x = 0.0
		lr.rotation.x = 0.0
	al.rotation = Vector3(-sw * 0.7, 0.0, 0.08)
	ar.rotation = Vector3(sw * 0.7, 0.0, -0.08)
	if kind == "intern":
		al.rotation = Vector3(-1.3, 0.0, 0.25)         # zombie reach
		ar.rotation = Vector3(-1.3, 0.0, -0.25)
	if kind == "archer":
		al.rotation = Vector3(-1.45, 0.0, 0.0)         # bow arm out
		ar.rotation = Vector3(-0.9 + sw * 0.2, 0.0, 0.0)
	match pose:
		"windup":
			var e := Style.smooth(0.0, 1.0, k)
			spine.rotation.x = -0.3 * e + hunch
			ar.rotation = Vector3(lerpf(0.0, -2.7, e), 0.0, -0.2)
			if kind == "archer":
				al.rotation = Vector3(-1.5, 0.0, 0.0)
				ar.rotation = Vector3(-1.5, 0.0, 0.0)
				ar.position.z = -0.1 * e
			if kind == "intern" or kind == "golem":
				al.rotation = Vector3(lerpf(-1.0, -2.7, e), 0.0, 0.2)
				ar.rotation = Vector3(lerpf(-1.0, -2.7, e), 0.0, -0.2)
		"strike":
			var f := 1.0 - k
			spine.rotation.x = 0.5 * f + hunch
			ar.rotation = Vector3(lerpf(-0.2, -2.7, k), 0.0, -0.1)
			if kind == "intern" or kind == "golem":
				al.rotation = Vector3(lerpf(-0.2, -2.7, k), 0.0, 0.2)
				ar.rotation = Vector3(lerpf(-0.2, -2.7, k), 0.0, -0.2)
		"recover":
			spine.rotation.x = hunch + 0.12
		"stun":
			head.rotation.z = sin(t * 18.0) * 0.18
			al.rotation = Vector3(0.4, 0.0, 0.5)
			ar.rotation = Vector3(0.4, 0.0, -0.5)
		"dead":
			pass
	if rig.has("WingL"):
		var fl := sin(t * 14.0) * 0.6
		(rig["WingL"] as Node3D).rotation = Vector3(0, 0.5 + fl, 0)
		(rig["WingR"] as Node3D).rotation = Vector3(0, -0.5 - fl, 0)


static func _anim_quad(rig: Dictionary, kind: String, t: float, sw: float, sp: float, pose: String, k: float) -> void:
	var body: Node3D = rig["Body"]
	var head: Node3D = rig["Head"]
	var tail: Node3D = rig["Tail"]
	var base_y := 3.0 * S if kind == "rat" else 7.0 * S
	body.position.y = base_y + absf(sin(t * 11.0)) * 0.05 * sp
	body.rotation.x = 0.0
	tail.rotation = Vector3(0.3, sin(t * 6.0) * 0.5, 0.0)
	head.rotation = Vector3(sin(t * 2.0) * 0.05, 0.0, 0.0)
	(rig["LegFL"] as Node3D).rotation.x = sw * 0.9
	(rig["LegBR"] as Node3D).rotation.x = sw * 0.9
	(rig["LegFR"] as Node3D).rotation.x = -sw * 0.9
	(rig["LegBL"] as Node3D).rotation.x = -sw * 0.9
	match pose:
		"windup":
			var e := Style.smooth(0.0, 1.0, k)
			body.rotation.x = -0.35 * e
			body.position.z = -0.12 * e
			head.rotation.x = 0.4 * e
		"strike":
			body.rotation.x = 0.3 * (1.0 - k)
			body.position.z = 0.0
			head.rotation.x = -0.5 * (1.0 - k)
			for n in ["LegFL", "LegFR"]:
				(rig[n] as Node3D).rotation.x = -0.9
			for n2 in ["LegBL", "LegBR"]:
				(rig[n2] as Node3D).rotation.x = 0.9
		"stun":
			head.rotation.z = sin(t * 18.0) * 0.2


static func _anim_blob(rig: Dictionary, t: float, sp: float, pose: String, k: float) -> void:
	var b: Node3D = rig["Body"]
	var idle := 1.0 + sin(t * 3.0) * 0.04
	b.scale = Vector3(1.0 / sqrt(idle), idle, 1.0 / sqrt(idle))
	(rig["Core"] as Node3D).rotation.y = t * 1.5
	match pose:
		"windup":                                          # crouch before a hop
			var e := Style.smooth(0.0, 1.0, k)
			b.scale = Vector3(1.0 + 0.25 * e, 1.0 - 0.35 * e, 1.0 + 0.25 * e)
		"strike":                                          # stretch in the air
			b.scale = Vector3(0.85, 1.25, 0.85)
		"recover":
			var e2 := 1.0 - k
			b.scale = Vector3(1.0 + 0.3 * e2, 1.0 - 0.3 * e2, 1.0 + 0.3 * e2)


static func _anim_bat(rig: Dictionary, t: float, pose: String, k: float) -> void:
	var fl := sin(t * 22.0) * 0.9
	(rig["WingL"] as Node3D).rotation = Vector3(0, 0, 0.2 + fl)
	(rig["WingR"] as Node3D).rotation = Vector3(0, 0, -0.2 - fl)
	var b: Node3D = rig["Body"]
	b.rotation.x = 0.0
	match pose:
		"windup":
			b.rotation.x = -0.6 * k
		"strike":
			b.rotation.x = 0.8


static func _anim_mushroom(rig: Dictionary, t: float, sp: float, pose: String, k: float) -> void:
	var st: Node3D = rig["Body"]
	var cap: Node3D = rig["Cap"]
	st.position.y = 2 * S + absf(sin(t * 6.0)) * 0.04 * sp
	cap.rotation = Vector3(sin(t * 2.0) * 0.04, 0.0, sin(t * 1.7) * 0.04)
	cap.scale = Vector3.ONE
	(rig["FootL"] as Node3D).rotation.x = sin(t * 6.0) * 0.6 * sp
	(rig["FootR"] as Node3D).rotation.x = -sin(t * 6.0) * 0.6 * sp
	match pose:
		"windup":
			var e := Style.smooth(0.0, 1.0, k)
			cap.scale = Vector3(1.0 + 0.2 * e, 1.0 - 0.25 * e, 1.0 + 0.2 * e)
			cap.rotation.x = -0.2 * e
		"strike":
			cap.scale = Vector3(0.9, 1.2, 0.9)


static func _anim_keg(rig: Dictionary, t: float, sw: float, sp: float, pose: String, k: float) -> void:
	var b: Node3D = rig["Body"]
	b.position.y = 5 * S + absf(sin(t * 12.0)) * 0.05 * sp
	b.rotation.z = sin(t * 12.0) * 0.08 * sp
	(rig["LegL"] as Node3D).rotation.x = sw
	(rig["LegR"] as Node3D).rotation.x = -sw
	(rig["ArmL"] as Node3D).rotation = Vector3(-sw * 0.5, 0, 0.5)
	(rig["ArmR"] as Node3D).rotation = Vector3(sw * 0.5, 0, -0.5)
	var f: Node3D = rig["Fuse"]
	f.scale = Vector3.ONE * (1.0 + sin(t * 30.0) * 0.1)
	if pose == "windup":                                      # fuse lit: shake and swell
		var s := 1.0 + 0.25 * k
		b.scale = Vector3(s, s, s)
		b.rotation.z = sin(t * 50.0) * 0.1 * k
		(rig["ArmL"] as Node3D).rotation = Vector3(-2.8, 0, 0.3)
		(rig["ArmR"] as Node3D).rotation = Vector3(-2.8, 0, -0.3)
	else:
		b.scale = Vector3.ONE


static func _anim_chest(rig: Dictionary, t: float, sp: float, pose: String, k: float) -> void:
	var b: Node3D = rig["Body"]
	var lid: Node3D = rig["Lid"]
	b.position.y = 3 * S + absf(sin(t * 10.0)) * 0.12 * sp
	var open := 0.35 + sin(t * 8.0) * 0.1 * sp
	match pose:
		"windup":
			open = lerpf(0.35, 1.1, k)
		"strike":
			open = lerpf(1.1, 0.0, minf(k * 2.5, 1.0))
			b.position.z = 0.15 * (1.0 - k)
		"idle":
			open = 0.0
	lid.rotation.x = -open
	var i := 0
	for n in ["Leg11", "Leg-11", "Leg1-1", "Leg-1-1"]:
		var lgn: Node3D = rig.get(n)
		if lgn != null:
			lgn.rotation.x = sin(t * 12.0 + i * PI) * 0.7 * sp
		i += 1
