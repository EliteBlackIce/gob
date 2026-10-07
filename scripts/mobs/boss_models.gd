class_name BossModels
extends RefCounted
## Boss bodies. The Auditor, Mimic King and Landlord reuse the mob rigs (scaled up) plus
## accessories; the Overdue Dragon has its own rig.

const S := 0.13
const SCALE := {"auditor": 2.1, "mimic_king": 3.2, "landlord": 1.9}

static var _cache := {}


static func build(boss_id: String, theme: String) -> Node3D:
	var m: Node3D
	match boss_id:
		"auditor", "landlord", "mimic_king":
			m = MobModels.build(boss_id, theme)
			m.scale = Vector3.ONE * SCALE[boss_id]
			return m
		"dragon":
			return _dragon()
	return MobModels.build("skeleton", theme)


static func _mi(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation_degrees = rot
	parent.add_child(m)
	return m


# ---------------------------------------------------------------- dragon

static func _dragon() -> Node3D:
	if not _cache.has("dragon"):
		_cache["dragon"] = _dragon_parts()
	var p: Dictionary = _cache["dragon"]
	var root := Node3D.new()
	root.name = "Dragon"
	var rig := {}
	root.set_meta("mtype", "dragon")
	root.set_meta("kind", "dragon")
	var body := MobModels._joint(root, rig, "Body", Vector3(0, 8 * S, 0))
	_mi(body, p["body"])
	var neck := MobModels._joint(body, rig, "Neck", Vector3(0, 6 * S, 11 * S))
	_mi(neck, p["neck"])
	var head := MobModels._joint(neck, rig, "Head", Vector3(0, 7 * S, 4 * S))
	_mi(head, p["head"])
	var jaw := MobModels._joint(head, rig, "Jaw", Vector3(0, -1 * S, 2 * S))
	_mi(jaw, p["jaw"])
	var t1 := MobModels._joint(body, rig, "Tail1", Vector3(0, 3 * S, -12 * S))
	_mi(t1, p["tail1"])
	var t2 := MobModels._joint(t1, rig, "Tail2", Vector3(0, 0, -9 * S))
	_mi(t2, p["tail2"])
	var t3 := MobModels._joint(t2, rig, "Tail3", Vector3(0, 0, -8 * S))
	_mi(t3, p["tail3"])
	for side in [1.0, -1.0]:
		var tag := "L" if side > 0 else "R"
		var w := MobModels._joint(body, rig, "Wing" + tag, Vector3(side * 6 * S, 7 * S, 3 * S))
		_mi(w, p["wing"] if side > 0 else p["wingR"])
		for fz in [1.0, -1.0]:
			var leg := MobModels._joint(body, rig, "Leg%s%s" % ["F" if fz > 0 else "B", tag], Vector3(side * 6 * S, -2 * S, fz * 8 * S))
			_mi(leg, p["leg"])
	root.set_meta("rig", rig)
	return root


static func _dragon_parts() -> Dictionary:
	var red := Color("#9a2420")
	var dark := Color("#5a1614")
	var belly := Color("#e0b46c")
	var bone := Color("#ece0b8")
	var membrane := Color("#c8472a")
	var d := {}
	var body := Vox.new(S)
	body.box(-7, 2, -12, 7, 10, 12, red, 0.03)
	body.box(-6, 10, -10, 6, 12, 10, red.darkened(0.08), 0.03)               # humped back
	body.box(-6, 0, -11, 6, 3, 11, belly, 0.02)                               # cream belly
	for z in range(-10, 11, 3):
		body.box(-6, 1, z, 6, 2, z + 1, belly.darkened(0.16), 0.02)           # belly plates
		body.box(-8, 4, z, -7, 9, z + 2, dark, 0.03)                          # side scales
		body.box(7, 4, z, 8, 9, z + 2, dark, 0.03)
		body.box(-1, 12, z, 1, 14, z + 1, bone, 0.02)                         # back spikes
		body.box(0, 14, z, 1, 16 if z % 2 == 0 else 15, z + 1, bone.lightened(0.05), 0.02)
	body.box(-7, 8, 8, 7, 11, 12, dark.lightened(0.05), 0.03)                 # shoulder plates
	d["body"] = body.build_shaded(Vector3(0, 6, 0))
	var neck := Vox.new(S)
	neck.box(-4, -4, -6, 4, 5, 6, red, 0.03)
	neck.box(-3, -4, -6, 3, -2, 6, belly, 0.02)                               # throat
	for z in range(-5, 6, 3):
		neck.box(-1, 5, z, 1, 7, z + 1, bone, 0.02)
	d["neck"] = neck.build_shaded(Vector3(0, 0, 0))
	var head := Vox.new(S)
	head.box(-5, -3, -3, 5, 5, 6, red, 0.03)
	head.box(-4, -3, 6, 4, 2, 14, red.lightened(0.04), 0.03)                  # long snout
	head.box(-4, 2, 6, 4, 3, 14, red.darkened(0.1), 0.03)
	head.box(-5, 5, 1, 5, 6, 6, dark, 0.03)                                    # brow ridge
	head.box(-2, 1, 14, -1, 2, 15, MobModels.DARK, 0.0)                                  # nostrils
	head.box(1, 1, 14, 2, 2, 15, MobModels.DARK, 0.0)
	for sx in [-6, 5]:
		head.box(sx, 1, 1, sx + 1, 4, 4, Color("#fff0a0", 0.2), 0.0)           # glowing eyes
		head.box(sx, -1, -1, sx + 2, 1, 2, dark, 0.03)                         # cheek spikes
	for hx in [-4, 3]:
		head.box(hx, 5, -3, hx + 2, 9, -1, bone, 0.02)                         # swept-back horns
		head.box(hx + (-1 if hx < 0 else 1), 8, -5, hx + (1 if hx < 0 else 3), 11, -3, bone.lightened(0.05), 0.02)
		head.box(hx + (-2 if hx < 0 else 2), 10, -7, hx + (0 if hx < 0 else 4), 13, -5, bone.lightened(0.1), 0.02)
	for tx in range(-3, 4, 2):
		head.box(tx, -4, 8, tx + 1, -2, 9, Color("#f4ecd0"), 0.0)             # upper fangs
	d["head"] = head.build_shaded(Vector3(0, 0, 0))
	var jaw := Vox.new(S)
	jaw.box(-4, -3, 0, 4, -1, 13, red.darkened(0.15), 0.03)
	jaw.box(-3, -1, 1, 3, 0, 12, Color("#c0304a"), 0.0)
	jaw.box(-1, -1, 4, 1, 0, 10, Color("#e0506a"), 0.0)                       # tongue
	for tx2 in range(-3, 4, 2):
		jaw.box(tx2, -1, 11, tx2 + 1, 1, 12, Color("#f4ecd0"), 0.0)
	d["jaw"] = jaw.build_shaded(Vector3(0, 0, 0))
	for i in [1, 2, 3]:
		var t := Vox.new(S)
		var r: int = 6 - i
		t.box(-r, -r + 1, -9, r, r, 0, red.darkened(0.04 * i), 0.03)
		t.box(-r + 1, -r, -9, r - 1, -r + 1, 0, belly.darkened(0.1 * i), 0.02)
		for z in range(-8, 0, 3):
			t.box(0, r, z, 1, r + 2, z + 1, bone, 0.02)
		if i == 3:
			t.box(-1, -1, -13, 1, 1, -9, red.darkened(0.12), 0.03)
			t.box(-4, -1, -14, 4, 1, -11, dark, 0.03)                          # spade tail tip
			t.box(0, 1, -14, 1, 5, -11, bone, 0.02)
		d["tail%d" % i] = t.build_shaded(Vector3(0, 0, 0))
	var w := Vox.new(S)
	w.box(0, -1, -1, 26, 2, 2, bone.darkened(0.15), 0.02)                      # leading arm bone
	w.box(24, -1, -1, 27, 3, 2, bone, 0.02)
	for fx in [6, 12, 18, 24]:
		var reach: int = 14 - fx / 3
		w.box(fx, -reach, 0, fx + 1, 0, 1, bone.darkened(0.2), 0.02)           # finger bones
		for xx in range(fx - 5 if fx > 6 else 0, fx):
			var hh: int = int(float(reach) * float(xx - (fx - 6)) / 6.0) if fx > 6 else reach
			w.box(xx, -clampi(hh, 1, reach), 0, xx + 1, 0, 1, membrane if (xx + fx) % 7 else membrane.darkened(0.15), 0.04)
	w.box(0, -6, 0, 6, 0, 1, membrane, 0.04)
	d["wing"] = w.build_shaded(Vector3(0, 0, 0))
	var wr := Vox.new(S)
	for k in w.cells:
		wr.cells[Vector3i(-1 - k.x, k.y, k.z)] = w.cells[k]
	d["wingR"] = wr.build_shaded(Vector3(0, 0, 0))
	var leg := Vox.new(S)
	leg.box(-3, -8, -3, 4, 0, 4, red.darkened(0.08), 0.03)
	leg.box(-4, -4, -4, 5, -2, 5, dark, 0.03)                                  # knee plate
	leg.box(-4, -11, -3, 5, -8, 7, dark.lightened(0.05), 0.03)                 # foot
	for cx in range(-3, 5, 3):
		leg.box(cx, -11, 7, cx + 2, -9, 10, bone, 0.02)                        # claws
	d["leg"] = leg.build_shaded(Vector3(0, 0, 0))
	return d


static func animate_dragon(root: Node3D, t: float, pose: String, k: float, moving: float) -> void:
	var rig := MobModels.rig_of(root)
	var body: Node3D = rig["Body"]
	body.position.y = 8 * S + sin(t * 1.8) * 0.05 + absf(sin(t * 5.0)) * 0.05 * moving
	var neck: Node3D = rig["Neck"]
	var head: Node3D = rig["Head"]
	var jaw: Node3D = rig["Jaw"]
	neck.rotation = Vector3(-0.35 + sin(t * 1.3) * 0.05, sin(t * 0.7) * 0.12, 0)
	head.rotation = Vector3(0.35, 0, 0)
	jaw.rotation = Vector3(0.12 + sin(t * 2.0) * 0.04, 0, 0)
	var flap := sin(t * 1.5) * 0.12
	(rig["WingL"] as Node3D).rotation = Vector3(0.0, 0.0, 0.5 + flap)
	(rig["WingR"] as Node3D).rotation = Vector3(0.0, 0.0, -0.5 - flap)
	(rig["Tail1"] as Node3D).rotation = Vector3(0.1, sin(t * 1.4) * 0.3, 0)
	(rig["Tail2"] as Node3D).rotation = Vector3(0.0, sin(t * 1.4 - 0.7) * 0.4, 0)
	(rig["Tail3"] as Node3D).rotation = Vector3(0.0, sin(t * 1.4 - 1.4) * 0.5, 0)
	var sw := sin(t * 6.0) * moving
	(rig["LegFL"] as Node3D).rotation.x = sw * 0.6
	(rig["LegBR"] as Node3D).rotation.x = sw * 0.6
	(rig["LegFR"] as Node3D).rotation.x = -sw * 0.6
	(rig["LegBL"] as Node3D).rotation.x = -sw * 0.6
	match pose:
		"breath":
			neck.rotation = Vector3(-0.8 * k, 0, 0)
			head.rotation = Vector3(0.1, 0, 0)
			jaw.rotation = Vector3(0.9 * k, 0, 0)
			body.rotation.x = -0.12 * k
		"slam":
			body.rotation.x = 0.2 * (1.0 - k) - 0.15 * k
			(rig["WingL"] as Node3D).rotation = Vector3(0.0, 0.0, 1.2 * k)
			(rig["WingR"] as Node3D).rotation = Vector3(0.0, 0.0, -1.2 * k)
		"swipe":
			body.rotation.y = sin(k * PI) * 0.6
			(rig["Tail1"] as Node3D).rotation.y = -sin(k * PI) * 1.2
		"gust":
			(rig["WingL"] as Node3D).rotation = Vector3(0.0, 0.0, 0.2 + sin(t * 18.0) * 0.5)
			(rig["WingR"] as Node3D).rotation = Vector3(0.0, 0.0, -0.2 - sin(t * 18.0) * 0.5)
			body.rotation.x = -0.18
		"roar":
			neck.rotation = Vector3(-0.7, 0, 0)
			jaw.rotation = Vector3(0.8, 0, 0)
		"stun":
			neck.rotation = Vector3(0.4, sin(t * 14.0) * 0.2, 0)
		_:
			body.rotation = Vector3.ZERO
