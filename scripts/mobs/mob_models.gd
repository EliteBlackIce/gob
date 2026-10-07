class_name MobModels
extends RefCounted
## Voxel bodies and procedural animation for every mob archetype. Each model is a small
## Node3D rig ("rig" meta: name -> joint). Animate with MobModels.animate().

const S := 0.05
const BONE := Color("#dcd6c0")
const DARK := Color("#1e1a22")

const BOSS_TYPES := {"auditor": "humanoid", "landlord": "humanoid", "mimic_king": "chest"}

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
	var mtype: String = str(MobDB.KINDS[kind]["model"]) if MobDB.KINDS.has(kind) else str(BOSS_TYPES.get(kind, "humanoid"))
	root.set_meta("mtype", mtype)
	root.set_meta("kind", kind)
	match mtype:
		"humanoid":
			var hips := _joint(root, rig, "Hips", Vector3(0, 13 * S, 0))
			var spine := _joint(hips, rig, "Spine", Vector3.ZERO)
			_mi(spine, parts["torso"], Vector3.ZERO)
			var head := _joint(spine, rig, "Head", Vector3(0, 12 * S, 0))
			_mi(head, parts["head"])
			for side in [1.0, -1.0]:
				var tag := "L" if side > 0 else "R"
				var arm := _joint(spine, rig, "Arm" + tag, Vector3(side * parts["shoulder"] * S, 11 * S, 0))
				_mi(arm, parts["arm"])
				var leg := _joint(hips, rig, "Leg" + tag, Vector3(side * float(parts.get("leg_x", 2.8)) * S, 0, 0))
				_mi(leg, parts["leg"])
			if parts.has("weapon"):
				var hand := _joint(rig["ArmR"], rig, "HandR", Vector3(0, -11 * S, 1.5 * S))
				_mi(hand, parts["weapon"], Vector3.ZERO, Vector3(-90, 0, 0))
			if parts.has("weapon_l"):
				var handl := _joint(rig["ArmL"], rig, "HandL", Vector3(0, -11 * S, 1.5 * S))
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
		"mimic_king":
			d = _mimic(acc, true)
		"auditor":
			d = _auditor()
		"landlord":
			d = _landlord()
	return d


static func _b(v: Vox, ox := 0.0, oy := 0.0, oz := 0.0) -> ArrayMesh:
	return v.build_shaded(Vector3(ox, oy, oz))


# Humanoid proportions (voxels): legs 13, torso 12 (10 wide, 5 deep), head 10^3, arms 12 long.
# Models face +Z. Every part is built around its joint: see build().

static func _skull(bone: Color, glow: Color) -> Vox:
	var h := Vox.new(S)
	h.box(0, 0, 0, 10, 10, 10, bone, 0.04)
	h.box(1, 10, 1, 9, 11, 9, bone.lightened(0.06), 0.03)                    # domed crown
	h.box(0, 6, 10, 10, 7, 11, bone.darkened(0.1), 0.03)                     # heavy brow
	h.box(0, 3, 10, 1, 5, 11, bone.lightened(0.05), 0.03)                    # cheekbones stick out
	h.box(9, 3, 10, 10, 5, 11, bone.lightened(0.05), 0.03)
	for ex in [2, 6]:
		h.remove_box(ex, 4, 8, ex + 2, 6, 10)                                # deep eye sockets
		h.box(ex, 4, 8, ex + 2, 6, 9, DARK, 0.0)
		h.box(ex, 4, 8, ex + 1, 5, 9, Color(glow.r, glow.g, glow.b, 0.3), 0.0) # glowing pupil
	h.remove_box(4, 2, 9, 6, 4, 10)
	h.box(4, 2, 9, 6, 4, 10, DARK, 0.0)                                      # nose hole
	h.box(1, 0, 9, 9, 2, 10, DARK, 0.0)                                      # mouth gap
	for tx in range(1, 9, 2):
		h.box(tx, 0, 9, tx + 1, 2, 10, bone.lightened(0.12), 0.02)           # teeth
	h.box(7, 8, 10, 8, 10, 11, DARK, 0.0)                                    # crack
	h.box(8, 9, 10, 9, 10, 11, DARK, 0.0)
	h.box(0, 0, 0, 10, 1, 10, bone.darkened(0.15), 0.03)
	return h


static func _skel_torso(bone: Color, acc: Color) -> Vox:
	var t := Vox.new(S)
	t.box(4, 0, 0, 6, 12, 2, bone, 0.03)                                     # spine
	for y in [3, 5, 7, 9]:
		t.box(0, y, 1, 10, y + 1, 5, bone, 0.03)                             # ribs
		t.remove_box(2, y, 1, 8, y + 1, 3)
		t.box(0, y, 1, 1, y + 1, 5, bone.darkened(0.08), 0.03)
	t.box(4, 2, 4, 6, 10, 5, bone.lightened(0.08), 0.03)                     # sternum
	t.box(1, 0, 0, 9, 3, 5, bone.darkened(0.1), 0.03)                        # pelvis
	t.box(0, 10, 0, 10, 12, 5, bone.darkened(0.05), 0.03)                    # shoulder girdle
	t.box(1, 10, 5, 9, 12, 6, acc, 0.03)                                     # clerk collar
	t.box(4, 4, 5, 6, 11, 6, Color("#b03030"), 0.02)                         # tie
	t.box(4, 3, 5, 6, 4, 6, Color("#8a2020"), 0.02)
	t.box(7, 7, 5, 9, 9, 6, Color("#f0e8d0"), 0.02)                          # name tag
	return t


static func _skel_arm(bone: Color) -> Vox:
	var a := Vox.new(S)
	a.box(0, -12, 0, 2, 0, 2, bone, 0.03)
	a.box(-1, -3, -1, 3, 0, 3, bone.darkened(0.08), 0.03)                    # shoulder knob
	a.box(-1, -8, -1, 3, -6, 3, bone.lightened(0.05), 0.03)                  # elbow knob
	a.box(-1, -13, -1, 3, -11, 3, bone.lightened(0.08), 0.03)                # hand
	return a


static func _skel_leg(bone: Color) -> Vox:
	var l := Vox.new(S)
	l.box(0, 3, 0, 2, 13, 2, bone, 0.03)
	l.box(-1, 7, -1, 3, 9, 3, bone.lightened(0.05), 0.03)                    # knee knob
	l.box(-1, 0, -1, 3, 3, 5, bone.darkened(0.08), 0.03)                     # foot
	l.box(-1, 0, 4, 3, 1, 5, bone.darkened(0.2), 0.02)
	return l


static func _skeleton(bone: Color, acc: Color, glow: Color, archer: bool) -> Dictionary:
	var h := _skull(bone, glow)
	if archer:
		h.box(-1, 5, -1, 11, 11, 11, acc, 0.03)                              # hood
		h.box(0, 11, 1, 10, 12, 9, acc.lightened(0.05), 0.03)
		h.box(-1, 5, -1, 1, 9, 11, acc.darkened(0.1), 0.03)
		h.box(9, 5, -1, 11, 9, 11, acc.darkened(0.1), 0.03)
		h.remove_box(1, 5, 8, 9, 10, 11)                                     # open face
		h.box(1, 0, 8, 9, 5, 10, bone, 0.03)
		h.box(2, 5, 8, 4, 7, 10, DARK, 0.0)
		h.box(6, 5, 8, 8, 7, 10, DARK, 0.0)
		h.box(2, 5, 8, 3, 6, 9, Color(glow.r, glow.g, glow.b, 0.3), 0.0)
		h.box(6, 5, 8, 7, 6, 9, Color(glow.r, glow.g, glow.b, 0.3), 0.0)
	var parts := {"head": _b(h, 5, 0, 5), "torso": _b(_skel_torso(bone, acc), 5, 0, 2.5), "arm": _b(_skel_arm(bone), 1, 0, 1),
		"leg": _b(_skel_leg(bone), 1, 13, 1), "shoulder": 6.6}
	if archer:
		var bow := Vox.new(S)
		for y in range(0, 26):
			var bend := int(round(sin(float(y) / 25.0 * PI) * 6.0))
			bow.box(bend, y, 0, bend + 2, y + 1, 2, Color("#7a4a28"), 0.04)
		bow.box(0, 0, 0, 1, 26, 1, Color("#e8e0c8"), 0.0)
		bow.box(-1, 11, -1, 3, 15, 3, Color("#4e3220"), 0.03)                # grip
		parts["weapon_l"] = _b(bow, 0, 13, 0)
		var q := Vox.new(S)
		q.box(0, 0, 0, 5, 12, 4, Color("#6a4a2a"), 0.04)
		q.box(0, 11, 0, 5, 12, 4, Color("#4e3220"), 0.03)
		for x in range(0, 5, 2):
			q.box(x, 12, 1, x + 1, 16, 2, Color("#e8e0c8"), 0.0)             # arrow shafts
			q.box(x, 16, 1, x + 1, 17, 2, Color("#c0c4cc"), 0.0)
		parts["back"] = _b(q, 2.5, 0, 2)
	else:
		var sw := Vox.new(S)
		sw.box(0, 0, 0, 2, 5, 2, Color("#5a3a1e"), 0.03)                     # grip
		sw.box(-3, 5, -1, 5, 7, 3, Color("#8a7a5a"), 0.03)                   # guard
		sw.box(0, 7, 0, 3, 26, 1, Color("#b8b4aa"), 0.03)                    # blade
		sw.box(0, 7, 0, 1, 26, 1, Color("#8a8478"), 0.03)
		sw.box(1, 26, 0, 2, 28, 1, Color("#b8b4aa"), 0.03)
		sw.box(0, 12, 0, 1, 14, 1, Color("#7a4a28"), 0.03)                   # rust
		sw.box(2, 18, 0, 3, 21, 1, Color("#7a4a28"), 0.03)
		parts["weapon"] = _b(sw, 1, 0, 0.5)
	return parts


static func _intern(main: Color, acc: Color) -> Dictionary:
	var skin := main.lerp(Color("#8aa070"), 0.55)
	var shirt := Color("#e6e2d6")
	var h := Vox.new(S)
	h.box(0, 0, 0, 10, 10, 10, skin, 0.04)
	h.box(0, 9, 0, 10, 11, 10, Color("#4a3426"), 0.04)                        # messy hair
	h.box(0, 8, 8, 10, 10, 11, Color("#4a3426"), 0.04)                        # fringe
	h.box(1, 10, 2, 4, 12, 7, Color("#4a3426"), 0.04)                         # tuft
	h.box(7, 10, 3, 9, 13, 6, Color("#4a3426"), 0.04)
	h.box(4, 4, 10, 6, 7, 11, skin.darkened(0.08), 0.03)                      # big nose
	for ex in [1, 6]:
		h.remove_box(ex, 5, 9, ex + 3, 7, 10)
		h.box(ex, 5, 9, ex + 3, 7, 10, Color("#efeee0"), 0.02)                # eyes sunk in
		h.box(ex + 1, 5, 9, ex + 2, 7, 10, DARK, 0.0)
		h.box(ex, 4, 9, ex + 3, 5, 10, Color("#7a5a8a"), 0.02)                # eye bags
	h.remove_box(2, 1, 9, 8, 3, 10)
	h.box(2, 1, 9, 8, 3, 10, Color("#4a0c14"), 0.0)                           # moaning mouth
	h.box(3, 1, 9, 5, 2, 10, Color("#c04050"), 0.0)
	h.box(3, 2, 9, 4, 3, 10, Color("#f0ecd0"), 0.0)
	h.box(6, 2, 9, 7, 3, 10, Color("#f0ecd0"), 0.0)
	h.box(-1, 3, 3, 0, 6, 7, skin, 0.03)                                      # ears
	h.box(10, 3, 3, 11, 6, 7, skin, 0.03)
	var t := Vox.new(S)
	t.box(0, 0, 0, 10, 12, 5, shirt, 0.03)
	t.box(0, 0, 0, 10, 3, 5, Color("#3a3a46"), 0.03)                          # trousers top / belt
	t.box(4, 1, 5, 6, 2, 6, Color("#e6b840"), 0.02)                           # buckle
	t.box(4, 3, 5, 6, 11, 6, acc, 0.03)                                       # tie
	t.box(3, 10, 5, 7, 12, 6, acc.darkened(0.2), 0.03)
	t.box(0, 10, 5, 4, 12, 6, shirt.darkened(0.08), 0.03)                     # collar
	t.box(6, 10, 5, 10, 12, 6, shirt.darkened(0.08), 0.03)
	t.box(1, 5, 5, 4, 8, 6, Color("#f4e050"), 0.02)                           # lanyard badge
	t.box(6, 3, 5, 9, 5, 6, Color("#6a4a2a"), 0.04)                           # coffee stain
	t.box(0, 3, 0, 1, 8, 5, shirt.darkened(0.1), 0.03)                        # torn side
	var arm := Vox.new(S)
	arm.box(0, -6, 0, 3, 0, 3, shirt, 0.03)                                   # sleeve
	arm.box(0, -12, 0, 3, -6, 3, skin, 0.04)                                  # bare forearm
	arm.box(-1, -13, -1, 4, -10, 4, skin.lightened(0.05), 0.03)               # fist
	arm.box(0, -7, 0, 3, -6, 3, shirt.darkened(0.15), 0.03)                   # ragged cuff
	var leg := Vox.new(S)
	leg.box(0, 3, 0, 3, 13, 3, Color("#3a3a4a"), 0.03)
	leg.box(0, 8, 0, 3, 9, 3, Color("#2e2e3a"), 0.03)
	leg.box(-1, 0, -1, 4, 3, 6, Color("#2a1a12"), 0.03)                       # shoes
	leg.box(-1, 0, 5, 4, 1, 6, Color("#1a100a"), 0.02)
	var cup := Vox.new(S)
	cup.box(0, 0, 0, 4, 5, 4, Color("#f0ecd8"), 0.02)                         # coffee cup
	cup.box(1, 5, 1, 3, 6, 3, Color("#5a3a1e"), 0.02)
	cup.box(4, 1, 1, 5, 4, 3, Color("#f0ecd8"), 0.02)
	cup.box(-1, 5, -1, 5, 6, 0, Color("#d8d4c0"), 0.02)
	return {"head": _b(h, 5, 0, 5), "torso": _b(t, 5, 0, 2.5), "arm": _b(arm, 1.5, 0, 1.5), "leg": _b(leg, 1.5, 13, 1.5),
		"shoulder": 6.8, "weapon": _b(cup, 2, 0, 2)}


static func _imp(main: Color, acc: Color, glow: Color) -> Dictionary:
	var skin := main.lerp(Color("#d83a2a"), 0.55)
	var dk := skin.darkened(0.2)
	var h := Vox.new(S)
	h.box(0, 0, 0, 10, 9, 9, skin, 0.04)
	h.box(0, 0, 0, 10, 2, 9, dk, 0.03)                                         # chin shadow
	h.box(3, 3, 9, 7, 5, 11, skin.lightened(0.05), 0.03)                       # snout
	h.box(4, 3, 11, 6, 4, 12, DARK, 0.0)
	for ex in [1, 6]:
		h.box(ex, 5, 9, ex + 3, 8, 10, Color("#fff0a0"), 0.0)
		h.box(ex + 1, 5, 9, ex + 2, 8, 10, DARK, 0.0)                          # slit pupil
	h.box(1, 8, 9, 9, 9, 10, dk, 0.03)                                         # angry brow
	h.box(1, 1, 9, 9, 2, 10, DARK, 0.0)
	for tx in [2, 3, 6, 7]:
		h.box(tx, 1, 9, tx + 1, 3, 10, Color("#f4ecd0"), 0.0)                  # fangs
	for hx in [0, 7]:                                                          # horns
		h.box(hx, 9, 1, hx + 3, 12, 4, Color("#2a2020"), 0.03)
		h.box(hx + (-1 if hx == 0 else 1), 11, 1, hx + (1 if hx == 0 else 4), 15, 4, Color("#2a2020"), 0.03)
		h.box(hx + (-2 if hx == 0 else 2), 14, 1, hx + (0 if hx == 0 else 5), 17, 3, Color("#4a3a38"), 0.03)
	h.box(-3, 4, 3, 0, 7, 6, skin, 0.03)                                       # pointy ears
	h.box(10, 4, 3, 13, 7, 6, skin, 0.03)
	h.box(-4, 6, 4, -3, 8, 5, skin, 0.03)
	h.box(13, 6, 4, 14, 8, 5, skin, 0.03)
	var t := Vox.new(S)
	t.box(0, 0, 0, 10, 12, 5, skin, 0.04)
	t.box(2, 0, 5, 8, 8, 6, skin.lightened(0.18), 0.03)                        # pale belly
	t.box(0, 0, 0, 10, 2, 5, Color("#3a2a2a"), 0.03)                           # tiny loincloth belt
	t.box(4, 0, 5, 6, 2, 6, Color("#e6b840"), 0.02)
	t.box(0, 10, 0, 10, 12, 5, dk, 0.03)
	t.box(4, -5, 1, 6, 0, 3, skin, 0.03)                                       # tail
	t.box(4, -8, 1, 6, -5, 3, dk, 0.03)
	t.box(3, -11, 1, 7, -8, 3, Color("#2a2020"), 0.03)                         # spade tip
	var arm := Vox.new(S)
	arm.box(0, -12, 0, 2, 0, 2, skin, 0.04)
	arm.box(-1, -3, -1, 3, 0, 3, dk, 0.03)
	arm.box(-1, -13, -1, 3, -10, 3, skin.lightened(0.05), 0.03)
	for cx in [-1, 1]:
		arm.box(cx + 1, -15, 0, cx + 2, -13, 1, Color("#2a2020"), 0.0)         # claws
	var leg := Vox.new(S)
	leg.box(0, 5, 0, 2, 13, 2, dk, 0.04)
	leg.box(-1, 2, 0, 3, 5, 3, skin, 0.04)
	leg.box(-1, 0, -1, 3, 2, 5, Color("#2a2020"), 0.03)
	var wing := Vox.new(S)
	for i in 14:
		var hgt := 12 - int(i * 0.6)
		wing.box(i, -hgt / 3, 0, i + 1, hgt - hgt / 3, 1, Color("#8a1a1a") if i % 4 else Color("#2a2020"), 0.04)
	wing.box(0, 0, 0, 14, 2, 1, Color("#2a2020"), 0.03)
	wing.box(0, 0, 0, 2, 7, 1, Color("#2a2020"), 0.03)
	var wingr := Vox.new(S)
	for k in wing.cells:
		wingr.cells[Vector3i(-1 - k.x, k.y, k.z)] = wing.cells[k]
	var fork := Vox.new(S)
	fork.box(0, 0, 0, 2, 26, 2, Color("#3a3a46"), 0.03)
	fork.box(-4, 24, 0, 6, 26, 2, Color("#3a3a46"), 0.03)
	for fx in [-4, 0, 4]:
		fork.box(fx, 26, 0, fx + 2, 31, 2, Color("#ff9a3a", 0.5), 0.0)
	return {"head": _b(h, 5, 0, 4.5), "torso": _b(t, 5, 0, 2.5), "arm": _b(arm, 1, 0, 1), "leg": _b(leg, 1, 13, 1), "shoulder": 6.6,
		"wing": _b(wing, 0, 0, 0), "wingR": _b(wingr, 0, 0, 0), "weapon": _b(fork, 1, 0, 1)}


static func _golem(main: Color, acc: Color, glow: Color) -> Dictionary:
	var stone := main.lerp(Color("#8a8a92"), 0.6)
	var core := Color(glow.r, glow.g, glow.b, 0.25)
	var h := Vox.new(S)
	h.cobble(0, 0, 0, 10, 9, 10, stone, 3)
	h.box(0, 6, 10, 10, 7, 11, stone.darkened(0.12), 0.03)                     # brow
	for ex in [2, 6]:
		h.remove_box(ex, 4, 9, ex + 2, 6, 10)
		h.box(ex, 4, 9, ex + 2, 6, 10, core, 0.0)
	h.box(4, 1, 9, 6, 3, 10, DARK, 0.0)
	h.box(0, 9, 3, 10, 10, 8, Color("#4a8a3a"), 0.05)                          # moss crown
	var t := Vox.new(S)
	t.cobble(0, 0, 0, 16, 14, 9, stone, 3)
	t.box(0, 11, 0, 16, 14, 9, stone.lightened(0.05), 0.03)
	t.box(6, 3, 9, 10, 9, 10, core, 0.0)                                       # glowing core
	t.box(7, 9, 9, 9, 11, 10, core, 0.0)
	t.box(5, 2, 9, 11, 3, 10, stone.darkened(0.2), 0.03)
	t.box(5, 9, 9, 6, 10, 10, stone.darkened(0.2), 0.03)
	t.box(10, 9, 9, 11, 10, 10, stone.darkened(0.2), 0.03)
	t.box(1, 10, 1, 4, 12, 4, Color("#4a8a3a"), 0.05)                          # moss
	t.box(11, 12, 5, 14, 14, 8, Color("#4a8a3a"), 0.05)
	t.box(3, 0, 9, 4, 6, 10, stone.darkened(0.25), 0.03)                       # cracks
	t.box(12, 2, 9, 13, 8, 10, stone.darkened(0.25), 0.03)
	var arm := Vox.new(S)
	arm.cobble(0, -14, 0, 6, 0, 6, stone, 3)
	arm.box(-1, -4, -1, 7, 0, 7, stone.lightened(0.06), 0.03)                  # shoulder boulder
	arm.cobble(-1, -19, -1, 7, -13, 7, stone.darkened(0.08), 3)                # fist
	arm.box(2, -8, 6, 4, -4, 7, core, 0.0)
	var leg := Vox.new(S)
	leg.cobble(0, 3, 0, 6, 13, 6, stone.darkened(0.06), 3)
	leg.cobble(-1, 0, -1, 7, 3, 8, stone.darkened(0.2), 3)
	return {"head": _b(h, 5, 0, 5), "torso": _b(t, 8, 0, 4.5), "arm": _b(arm, 3, 0, 3), "leg": _b(leg, 3, 13, 3), "shoulder": 10.5, "leg_x": 4.6}


static func _ghost(main: Color, glow: Color) -> Dictionary:
	var sheet := Color("#e8f0f4")
	var h := Vox.new(S)
	h.box(0, 0, 0, 10, 10, 10, sheet, 0.03)
	h.box(1, 10, 1, 9, 11, 9, sheet.darkened(0.04), 0.03)                      # hood top
	h.box(-1, 2, 1, 0, 9, 9, sheet.darkened(0.08), 0.03)                       # hood sides
	h.box(10, 2, 1, 11, 9, 9, sheet.darkened(0.08), 0.03)
	for ex in [2, 6]:
		h.remove_box(ex, 4, 9, ex + 2, 7, 10)
		h.box(ex, 4, 8, ex + 2, 7, 9, DARK, 0.0)
		h.box(ex, 5, 8, ex + 1, 6, 9, Color(glow.r, glow.g, glow.b, 0.2), 0.0)
	h.remove_box(4, 1, 9, 6, 3, 10)
	h.box(4, 1, 8, 6, 3, 9, DARK, 0.0)                                         # "oooh"
	var t := Vox.new(S)
	for y in 18:
		var r := 4.2 + float(y) * 0.22
		var ragged := y < 3 and ((y * 5 + int(r * 3.0)) % 3 == 0)
		var rr := r - (1.2 if ragged else 0.0)
		t.cyl_y(0.0, 0.0, y, y + 1, rr, rr * 0.9, sheet.darkened(0.04 * float(18 - y) / 18.0), 0.03)
	t.box(-3, 8, 4, 3, 11, 5, Color("#f4f0d8"), 0.02)                          # HELLO MY NAME IS
	t.box(-3, 10, 4, 3, 11, 5, Color("#c0302a"), 0.0)
	t.box(-2, 8, 5, 2, 9, 6, DARK, 0.0)
	var arm := Vox.new(S)
	arm.box(0, -9, 0, 3, 0, 3, sheet, 0.03)
	arm.box(-1, -11, -1, 4, -8, 4, sheet.darkened(0.06), 0.03)
	var leg := Vox.new(S)
	leg.box(0, 0, 0, 1, 1, 1, sheet, 0.0)
	return {"head": _b(h, 5, 0, 5), "torso": _b(t, 0, 6, 0), "arm": _b(arm, 1.5, 0, 1.5), "leg": _b(leg, 0, 0, 0), "shoulder": 6.5}


static func _auditor() -> Dictionary:
	var bone := Color("#c8c2b0")
	var coat := Color("#1e1c28")
	var h := _skull(bone, Color("#c070ff"))
	h.box(5, 3, 10, 9, 4, 11, GOLD_LOCK, 0.02)                                 # monocle ring
	h.box(5, 6, 10, 9, 7, 11, GOLD_LOCK, 0.02)
	h.box(5, 4, 10, 6, 6, 11, GOLD_LOCK, 0.02)
	h.box(8, 4, 10, 9, 6, 11, GOLD_LOCK, 0.02)
	h.box(8, 0, 10, 9, 3, 11, GOLD_LOCK, 0.0)                                  # monocle chain
	h.box(-2, 10, -2, 12, 11, 12, Color("#14121c"), 0.03)                      # top hat brim
	h.box(1, 11, 1, 9, 22, 9, Color("#14121c"), 0.03)
	h.box(1, 12, 1, 9, 15, 9, Color("#6a2a9a"), 0.03)                          # purple band
	h.box(3, 12, 9, 7, 15, 10, GOLD_LOCK, 0.02)                                # gold buckle
	h.box(4, 13, 9, 6, 14, 10, Color("#14121c"), 0.0)
	var t := Vox.new(S)
	t.box(0, 0, 0, 12, 12, 6, coat, 0.03)
	t.box(4, 0, 6, 8, 11, 7, Color("#ece8dc"), 0.02)                           # shirt front
	t.box(1, 3, 6, 4, 12, 7, coat.lightened(0.1), 0.03)                        # lapels
	t.box(8, 3, 6, 11, 12, 7, coat.lightened(0.1), 0.03)
	t.box(5, 10, 7, 7, 11, 8, Color("#b02a2a"), 0.02)                          # bow tie
	t.box(4, 10, 7, 5, 12, 8, Color("#b02a2a"), 0.02)
	t.box(7, 10, 7, 8, 12, 8, Color("#b02a2a"), 0.02)
	for by in [2, 5, 8]:
		t.box(5, by, 7, 7, by + 1, 8, GOLD_LOCK, 0.0)                           # buttons
	t.box(3, 5, 7, 6, 6, 8, GOLD_LOCK, 0.0)                                    # pocket-watch chain
	t.box(2, 3, 7, 4, 5, 8, GOLD_LOCK, 0.0)
	t.box(-1, 10, -1, 13, 12, 7, coat.lightened(0.05), 0.03)                   # padded shoulders
	t.box(1, -10, -1, 11, 0, 2, coat, 0.03)                                    # long tails
	t.box(2, -11, -1, 5, -10, 2, coat.lightened(0.08), 0.03)
	t.box(7, -11, -1, 10, -10, 2, coat.lightened(0.08), 0.03)
	var arm := Vox.new(S)
	arm.box(0, -9, 0, 3, 0, 3, coat, 0.03)
	arm.box(-1, -10, -1, 4, -9, 4, Color("#ece8dc"), 0.02)                      # white cuff
	arm.box(0, -13, 0, 2, -10, 2, bone, 0.03)
	arm.box(-1, -15, -1, 3, -13, 3, bone.lightened(0.06), 0.03)
	for fx in range(-1, 3):
		arm.box(fx, -18, -1, fx + 1, -15, 0, bone, 0.02)                        # long bony fingers
		arm.box(fx, -18, 2, fx + 1, -15, 3, bone, 0.02)
	var leg := Vox.new(S)
	leg.box(0, 4, 0, 3, 13, 3, Color("#2a2836"), 0.03)
	leg.box(0, 0, 0, 3, 4, 3, Color("#d8d4c4"), 0.02)                           # spats
	leg.box(-1, 0, -1, 4, 2, 6, Color("#14121c"), 0.02)
	var book := Vox.new(S)
	book.box(0, 0, 0, 14, 18, 4, Color("#5a1a1a"), 0.03)
	book.box(1, 1, 4, 13, 17, 5, Color("#efe6cc"), 0.02)
	for y in range(3, 16, 2):
		book.box(2, y, 5, 12, y + 1, 6, Color("#6a6a74"), 0.0)
	book.box(0, 0, 4, 2, 2, 5, GOLD_LOCK, 0.0)
	book.box(12, 16, 4, 14, 18, 5, GOLD_LOCK, 0.0)
	book.box(6, 17, 5, 8, 20, 6, Color("#c0302a"), 0.0)
	book.box(4, 8, 6, 10, 10, 7, Color(0.75, 0.45, 1.0, 0.3), 0.0)             # glowing "TOTAL: DOOM"
	var quill := Vox.new(S)
	quill.box(0, 0, 0, 1, 34, 1, Color("#f0ece0"), 0.02)
	quill.box(-1, 8, 0, 0, 30, 1, Color("#dcd6c0"), 0.02)
	quill.box(1, 8, 0, 2, 30, 1, Color("#dcd6c0"), 0.02)
	quill.box(0, 34, 0, 1, 37, 1, Color(0.75, 0.45, 1.0, 0.3), 0.0)
	return {"head": _b(h, 5, 0, 5), "torso": _b(t, 6, 0, 3), "arm": _b(arm, 1.5, 0, 1.5), "leg": _b(leg, 1.5, 13, 1.5), "shoulder": 7.4,
		"leg_x": 3.0, "weapon": _b(quill, 0.5, 0, 0.5), "weapon_l": _b(book, 7, 0, 2)}


static func _landlord() -> Dictionary:
	var skin := Color("#8aa860")
	var robe := Color("#7a2a3a")
	var trim := GOLD_LOCK
	var h := Vox.new(S)
	h.box(0, 0, 0, 12, 10, 11, skin, 0.04)
	h.box(-1, 0, 1, 0, 5, 9, skin.darkened(0.05), 0.03)                        # jowls
	h.box(12, 0, 1, 13, 5, 9, skin.darkened(0.05), 0.03)
	h.box(0, 8, 9, 12, 10, 12, skin.darkened(0.12), 0.03)                      # heavy brow
	for ex in [2, 7]:
		h.remove_box(ex, 5, 10, ex + 3, 7, 11)
		h.box(ex, 5, 10, ex + 3, 7, 11, Color("#f0ecd8"), 0.0)                 # beady eyes
		h.box(ex + 1, 5, 10, ex + 2, 7, 11, DARK, 0.0)
	h.box(4, 3, 11, 8, 7, 13, skin.darkened(0.08), 0.03)                       # big nose
	h.box(2, 2, 11, 10, 4, 12, Color("#3a2a1a"), 0.03)                         # walrus moustache
	h.box(1, 1, 11, 2, 3, 12, Color("#3a2a1a"), 0.03)
	h.box(10, 1, 11, 11, 3, 12, Color("#3a2a1a"), 0.03)
	h.box(8, 1, 11, 9, 2, 15, Color("#6a4a2a"), 0.03)                          # cigar
	h.box(8, 1, 15, 9, 2, 16, Color(1.0, 0.5, 0.15, 0.2), 0.0)
	h.box(-2, 3, 3, 0, 6, 8, skin, 0.03)                                       # ears
	h.box(12, 3, 3, 14, 6, 8, skin, 0.03)
	h.box(0, 10, 0, 12, 12, 11, Color("#efe6cc"), 0.02)                        # paper hat
	h.box(2, 12, 2, 10, 17, 9, Color("#efe6cc"), 0.02)
	h.box(3, 13, 9, 9, 16, 10, Color("#c0302a"), 0.0)                          # RENT stamp
	var t := Vox.new(S)
	t.box(0, 0, 0, 18, 14, 10, robe, 0.03)
	t.box(2, 0, 10, 16, 7, 12, robe.lightened(0.08), 0.03)                      # big belly bulge
	t.remove_box(6, 6, 10, 12, 14, 11)
	t.box(6, 4, 9, 12, 14, 10, skin.lightened(0.1), 0.03)                       # open robe: belly + chest
	for hx in [7, 9, 11]:
		t.box(hx, 8, 10, hx + 1, 10, 11, Color("#3a2a1a"), 0.0)                 # chest hair
	t.box(0, 12, 0, 18, 14, 10, robe.lightened(0.05), 0.03)
	t.box(5, 6, 10, 6, 14, 11, trim, 0.02)                                      # gold trim
	t.box(12, 6, 10, 13, 14, 11, trim, 0.02)
	t.box(1, 6, 10, 17, 7, 12, Color("#c8b890"), 0.03)                          # rope belt
	t.box(8, 5, 11, 10, 7, 13, trim, 0.02)
	t.box(-1, -7, -1, 19, 0, 11, robe.darkened(0.08), 0.03)                     # robe skirt
	t.box(-1, -7, -1, 19, -6, 11, trim, 0.02)
	var arm := Vox.new(S)
	arm.box(0, -8, 0, 5, 0, 5, robe, 0.03)
	arm.box(-1, -9, -1, 6, -8, 6, trim, 0.02)
	arm.box(0, -13, 0, 5, -9, 5, skin, 0.04)
	arm.box(-1, -16, -1, 6, -12, 6, skin.lightened(0.04), 0.03)
	for fx in [0, 2, 4]:
		arm.box(fx, -18, 0, fx + 1, -16, 1, skin, 0.02)
	var leg := Vox.new(S)
	leg.box(0, 3, 0, 5, 13, 5, skin.darkened(0.1), 0.04)
	leg.box(-1, 0, -1, 6, 3, 7, Color("#e8a0c0"), 0.04)                         # fluffy slippers
	leg.box(0, 3, 6, 5, 4, 7, Color("#f4c8d8"), 0.03)
	var keys := Vox.new(S)
	keys.cyl_y(0.0, 0.0, 0, 1, 4.0, 4.0, GOLD_LOCK, 0.02)
	keys.remove_box(-2, 0, -2, 2, 1, 2)
	for k in 6:
		keys.box(-5 + k * 2, -8, 0, -4 + k * 2, 0, 1, Color("#c8a030"), 0.03)
		keys.box(-6 + k * 2, -10, 0, -3 + k * 2, -8, 1, Color("#c8a030"), 0.03)
	var sack := Vox.new(S)
	sack.ellipsoid(0.0, 6.0, 0.0, 6.5, 6.0, 5.0, Color("#b89c64"), 0.04)
	sack.box(-2, 11, -2, 3, 14, 2, Color("#8a6a38"), 0.03)
	sack.box(-3, 4, 4, 3, 8, 6, Color("#2a7a3a"), 0.0)                          # big green $
	sack.box(-1, 3, 4, 1, 9, 6, Color("#2a7a3a"), 0.0)
	return {"head": _b(h, 6, 0, 5.5), "torso": _b(t, 9, 0, 5), "arm": _b(arm, 2.5, 0, 2.5), "leg": _b(leg, 2.5, 13, 2.5), "shoulder": 11.3,
		"leg_x": 4.4, "weapon": _b(sack, 0, 0, 0), "weapon_l": _b(keys, 0, 0, 0)}


static func _rat(main: Color, acc: Color) -> Dictionary:
	var fur := Color("#7a6a5c").lerp(main, 0.15)
	var belly := fur.lightened(0.22)
	var body := Vox.new(S)
	body.box(0, 0, 0, 7, 6, 12, fur, 0.04)
	body.box(1, 6, 1, 6, 7, 10, fur.darkened(0.06), 0.04)                      # arched back
	body.box(1, 0, 1, 6, 1, 11, belly, 0.03)                                    # pale belly
	body.box(2, 7, 3, 5, 8, 8, fur.darkened(0.12), 0.04)                        # spine ridge
	body.box(0, 3, 1, 1, 5, 5, fur.darkened(0.1), 0.04)                         # scruffy patches
	body.box(6, 2, 5, 7, 5, 10, fur.darkened(0.1), 0.04)
	var head := Vox.new(S)
	head.box(0, 0, 0, 6, 6, 6, fur.lightened(0.04), 0.03)
	head.box(1, 0, 6, 5, 4, 10, fur.lightened(0.08), 0.03)                      # snout
	head.box(2, 1, 10, 4, 3, 11, Color("#e8a0a8"), 0.02)                        # nose
	head.box(2, 0, 9, 3, 1, 10, Color("#f4ecd0"), 0.0)                          # buck teeth
	head.box(3, 0, 9, 4, 1, 10, Color("#f4ecd0"), 0.0)
	for ex in [0, 5]:
		head.box(ex, 3, 5, ex + 1, 5, 7, Color("#ff3a3a", 0.35), 0.0)           # glowing eyes
		head.box(ex - 1, 6, 1, ex + 2, 9, 4, fur, 0.03)                         # round ears
		head.box(ex, 6, 3, ex + 1, 8, 4, Color("#e8a0a8"), 0.02)                # pink inner ear
	for wy in [2, 3]:
		head.box(-3, wy, 7, 0, wy + 1, 8, Color("#e8e0d0"), 0.0)                # whiskers
		head.box(6, wy, 7, 9, wy + 1, 8, Color("#e8e0d0"), 0.0)
	head.box(1, 0, 5, 5, 1, 6, Color("#efe6cc"), 0.02)                          # stolen envelope
	head.box(2, -1, 6, 4, 0, 7, Color("#c0302a"), 0.0)
	var tail := Vox.new(S)
	for i in 10:
		tail.box(0, 0, -i, 2 if i < 5 else 1, 1, -i + 1, Color("#e8a0a8").darkened(0.04 * (i % 2)), 0.03)
	var leg := Vox.new(S)
	leg.box(0, 1, 0, 2, 4, 2, fur.darkened(0.12), 0.04)
	leg.box(-1, 0, -1, 3, 1, 3, Color("#e8a0a8"), 0.03)                         # pink paws
	return {"body": _b(body, 3.5, 0, 6), "head": _b(head, 3, 0, 2), "tail": _b(tail, 0.5, 0, 0), "leg": _b(leg, 1, 4, 1),
		"leg_h": 4, "head_y": 1.0, "head_z": 6.0, "tail_y": 2.5, "body_len": 12.0, "leg_x": 2.4, "leg_z": 4.0}


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
	var shell := c.lightened(0.12)
	var body := Vox.new(S)
	body.box(0, 0, 0, 14, 12, 14, shell, 0.03)
	for corner in [[0, 0], [13, 0], [0, 13], [13, 13]]:
		body.remove_box(corner[0], 0, corner[1], corner[0] + 1, 12, corner[1] + 1)
	body.box(0, 0, 0, 14, 2, 14, c.darkened(0.1), 0.03)                       # gooey base
	body.box(-1, 0, 3, 0, 2, 11, c.darkened(0.1), 0.03)                       # drips
	body.box(14, 0, 4, 15, 2, 10, c.darkened(0.1), 0.03)
	body.box(3, 12, 3, 11, 13, 11, shell, 0.03)                               # top bump
	body.box(4, 13, 4, 8, 14, 7, c.lightened(0.3), 0.02)                      # glossy highlight
	body.remove_box(2, 3, 11, 12, 10, 14)                                      # window to the nucleus
	var core := c.darkened(0.28)
	body.box(2, 3, 8, 12, 10, 11, core, 0.03)                                  # dark core, recessed
	body.box(3, 6, 11, 6, 9, 12, Color("#f4f0d8"), 0.0)                        # eyes on the core
	body.box(8, 6, 11, 11, 9, 12, Color("#f4f0d8"), 0.0)
	body.box(4, 6, 11, 5, 8, 12, DARK, 0.0)
	body.box(9, 6, 11, 10, 8, 12, DARK, 0.0)
	body.box(5, 4, 11, 9, 5, 12, DARK, 0.0)                                    # mouth
	body.box(4, 5, 11, 5, 6, 12, DARK, 0.0)
	body.box(9, 5, 11, 10, 6, 12, DARK, 0.0)
	var junk := Vox.new(S)
	junk.box(0, 0, 0, 5, 5, 3, Color(glow.r, glow.g, glow.b, 0.4), 0.0)
	junk.box(1, 1, 0, 4, 2, 3, Color("#efe6cc"), 0.0)
	return {"body": _b(body, 7, 0, 7), "core": _b(junk, 2.5, 0, 1.5)}


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


static func _mimic(acc: Color, king := false) -> Dictionary:
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
	if king:
		body.box(1, 7, -2, 13, 20, 0, Color("#a01a2a"), 0.03)                      # royal cape
		body.box(1, 7, -3, 13, 9, -2, Color("#f4f0e8"), 0.03)                      # ermine collar
		for sx in range(2, 12, 3):
			body.box(sx, 7, -3, sx + 1, 8, -2, DARK, 0.0)                          # ermine spots
		body.box(0, 0, 9, 14, 1, 10, GOLD_LOCK, 0.03)                              # gold trim
		for gx in [1, 6, 11]:
			body.box(gx, 3, 10, gx + 2, 5, 11, [Color("#d83a4a"), Color("#4ad0ff"), Color("#6aff7a")][gx % 3], 0.0)   # jewels
		lid.box(0, 5, 3, 14, 7, 7, GOLD_LOCK, 0.03)                                # crown band
		for cx in [0, 3, 6, 9, 12]:
			lid.box(cx, 7, 3, cx + 2, 10, 7, GOLD_LOCK, 0.03)
		lid.box(6, 8, 6, 8, 10, 7, Color("#d83a4a", 0.4), 0.0)
		lid.box(2, 2, 10, 4, 4, 11, Color("#d83a4a", 0.4), 0.0)                    # angrier red eyes
		lid.box(10, 2, 10, 12, 4, 11, Color("#d83a4a", 0.4), 0.0)
		for tx in range(2, 12, 2):
			body.box(tx, 7, 8, tx + 1, 11, 9, Color("#f4ecd0"), 0.0)               # taller teeth
	return {"body": _b(body, 7, 0, 5), "lid": _b(lid, 7, 0, 0), "leg": _b(leg, 1.5, 5, 1.5)}


const GOLD_LOCK := Color("#e6b840")


# ============================================================== animation

## pose: idle / walk / windup / strike / recover / stun / dead.  k: progress inside that pose (0..1).
static func animate(root: Node3D, t: float, speed01: float, pose: String, k: float) -> void:
	var rig := rig_of(root)
	var mtype: String = root.get_meta("mtype")
	var kind: String = root.get_meta("kind")
	var ph := t * (9.0 if kind not in ["intern", "golem", "landlord"] else 5.5)
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
	hips.position.y = (13 if kind != "ghost" else 7) * S + (absf(sin(t * 9.0)) * 0.03 * sp if not float_kind else sin(t * 2.5) * 0.08)
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
