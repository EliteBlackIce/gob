class_name BossModels
extends RefCounted
## Boss bodies. The Auditor, Mimic King and Landlord reuse the mob rigs (scaled up) plus
## accessories; the Overdue Dragon has its own rig.

const S := 0.1
const SCALE := {"auditor": 2.0, "mimic_king": 3.0, "landlord": 2.4}

static var _cache := {}


static func build(boss_id: String, theme: String) -> Node3D:
	match boss_id:
		"auditor":
			var m := MobModels.build("skeleton", "crypt")
			_accessorize_auditor(m)
			m.scale = Vector3.ONE * SCALE[boss_id]
			return m
		"mimic_king":
			var m2 := MobModels.build("mimic", "sewer")
			_accessorize_king(m2)
			m2.scale = Vector3.ONE * SCALE[boss_id]
			return m2
		"landlord":
			var m3 := MobModels.build("intern", theme)
			_accessorize_landlord(m3)
			m3.scale = Vector3.ONE * SCALE[boss_id]
			return m3
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


static func _accessorize_auditor(m: Node3D) -> void:
	var rig := MobModels.rig_of(m)
	# top hat
	var hat := Vox.new(MobModels.S)
	hat.box(-1, 0, -1, 9, 1, 9, Color("#1a1a22"), 0.04)
	hat.box(1, 1, 1, 7, 9, 7, Color("#1a1a22"), 0.04)
	hat.box(1, 1, 1, 7, 3, 7, Color("#5a2a7a"), 0.04)
	hat.box(3, 2, 7, 5, 4, 8, Color("#e6b840"), 0.0)
	_mi(rig["Head"], hat.build(Vector3(4, 0, 4)), Vector3(0, 8 * MobModels.S, 0))
	# giant ledger in the left hand
	var book := Vox.new(MobModels.S)
	book.box(0, 0, 0, 12, 16, 3, Color("#5a1a1a"), 0.05)
	book.box(1, 1, 3, 11, 15, 4, Color("#efe6cc"), 0.03)
	for y in range(3, 14, 2):
		book.box(2, y, 3, 10, y + 1, 4, Color("#6a6a74"), 0.0)
	book.box(5, 14, 4, 7, 15, 5, Color("#c0302a"), 0.0)
	var hand: Node3D = rig["HandL"] if rig.has("HandL") else rig["ArmL"]
	_mi(hand, book.build(Vector3(6, 0, 1)), Vector3(0, -2 * MobModels.S, 2 * MobModels.S), Vector3(-90, 0, 0))
	# glowing quill instead of a sword
	if rig.has("HandR"):
		var hr: Node3D = rig["HandR"]
		for c in hr.get_children():
			c.queue_free()
		var quill := Vox.new(MobModels.S)
		quill.box(0, 0, 0, 1, 24, 1, Color("#f0ece0"), 0.03)
		quill.box(-1, 8, 0, 0, 22, 1, Color("#dcd6c0"), 0.04)
		quill.box(1, 8, 0, 2, 22, 1, Color("#dcd6c0"), 0.04)
		quill.box(0, 24, 0, 1, 26, 1, Color(0.7, 0.4, 1.0, 0.3), 0.0)
		_mi(hr, quill.build(Vector3(0.5, 0, 0.5)), Vector3.ZERO, Vector3(-90, 0, 0))


static func _accessorize_king(m: Node3D) -> void:
	var rig := MobModels.rig_of(m)
	var crown := Vox.new(MobModels.S)
	crown.box(0, 0, 0, 10, 2, 8, Color("#e6b840"), 0.04)
	for x in [0, 3, 6, 9]:
		crown.box(x, 2, 0, x + 1, 5, 1, Color("#e6b840"), 0.04)
		crown.box(x, 2, 7, x + 1, 5, 8, Color("#e6b840"), 0.04)
	crown.box(4, 2, 0, 6, 4, 1, Color("#d83a4a", 0.5), 0.0)
	_mi(rig["Lid"], crown.build(Vector3(5, 0, 4)), Vector3(0, 6 * MobModels.S, 5 * MobModels.S))
	# pile of loot spilling out
	var loot := Vox.new(MobModels.S)
	for i in 14:
		loot.box(i % 7, 0, i / 7, i % 7 + 1, 1 + (i % 3), i / 7 + 1, Color("#ffd24a", 0.7) if i % 2 == 0 else Color("#e6b840"), 0.05)
	_mi(rig["Body"], loot.build(Vector3(3, 0, 1)), Vector3(0, 6 * MobModels.S, 3 * MobModels.S))


static func _accessorize_landlord(m: Node3D) -> void:
	var rig := MobModels.rig_of(m)
	var robe := Vox.new(MobModels.S)
	robe.box(0, 0, 0, 12, 14, 7, Color("#6a2a3a"), 0.06)
	robe.box(5, 0, 7, 7, 14, 8, Color("#4a1a28"), 0.04)
	robe.box(0, 12, 0, 12, 14, 7, Color("#8a3a4a"), 0.06)
	_mi(rig["Spine"], robe.build(Vector3(6, 0, 3.5)), Vector3(0, 0, 0))
	# key ring on the belt
	var keys := Vox.new(MobModels.S)
	keys.cyl_y(0.0, 0.0, 0, 1, 3.0, 3.0, Color("#e6b840"), 0.03)
	keys.remove_box(-1, 0, -1, 1, 1, 1)
	for i in 5:
		keys.box(i - 3, -4, 0, i - 2, 0, 1, Color("#c8a030"), 0.05)
	_mi(rig["Hips"], keys.build(Vector3(0, 0, 0)), Vector3(4 * MobModels.S, 3 * MobModels.S, 3 * MobModels.S), Vector3(0, 0, 0))
	# paper hat that reads RENT
	var hat := Vox.new(MobModels.S)
	hat.box(0, 0, 0, 10, 2, 9, Color("#efe6cc"), 0.03)
	hat.box(1, 2, 1, 9, 7, 8, Color("#efe6cc"), 0.03)
	hat.box(3, 3, 8, 7, 6, 9, Color("#c0302a"), 0.0)
	_mi(rig["Head"], hat.build(Vector3(5, 0, 4.5)), Vector3(0, 8 * MobModels.S, 0))
	# big sack of rent money
	if rig.has("HandR"):
		var hr: Node3D = rig["HandR"]
		for c in hr.get_children():
			c.queue_free()
		var sack := Vox.new(MobModels.S)
		sack.ellipsoid(0.0, 5.0, 0.0, 5.0, 5.0, 4.0, Color("#b89c64"), 0.07)
		sack.box(-1, 9, -1, 2, 11, 1, Color("#8a6a38"), 0.04)
		sack.box(-2, 4, 4, 2, 7, 5, Color("#2a7a3a"), 0.0)
		_mi(hr, sack.build(Vector3(0, 0, 0)), Vector3.ZERO, Vector3(-90, 0, 0))


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
	var red := Color("#b82a1e")
	var dark := Color("#6a1812")
	var belly := Color("#e8b860")
	var d := {}
	var body := Vox.new(S)
	body.ellipsoid(0.0, 6.0, 0.0, 8.0, 7.0, 13.0, red, 0.06)
	body.ellipsoid(0.0, 3.0, 1.0, 6.0, 4.0, 11.0, belly, 0.05)
	for z in range(-10, 10, 3):
		body.box(-1, 12, z, 1, 15, z + 1, dark, 0.04)               # back spikes
		body.box(0, 15, z, 1, 16, z + 1, Color("#e8d8a0"), 0.0)
	d["body"] = body.build(Vector3(0, 6, 0))
	var neck := Vox.new(S)
	neck.ellipsoid(0.0, 0.0, 0.0, 4.2, 4.5, 6.0, red, 0.06)
	neck.box(-1, 4, -5, 1, 7, 5, dark, 0.04)
	d["neck"] = neck.build(Vector3(0, 0, 0))
	var head := Vox.new(S)
	head.box(-4, -2, -2, 4, 5, 6, red, 0.06)
	head.box(-3, -2, 6, 3, 2, 12, red.lightened(0.04), 0.06)           # snout
	head.box(-1, 2, 11, 0, 3, 12, dark, 0.0)                           # nostrils
	head.box(1, 2, 11, 2, 3, 12, dark, 0.0)
	for sx in [-5, 4]:
		head.box(sx, 2, 1, sx + 1, 4, 3, Color("#fff0a0", 0.2), 0.0)    # glowing eyes
	for hx in [-4, 3]:
		head.box(hx, 5, -2, hx + 2, 11, 0, Color("#e8d8a0"), 0.04)      # horns
		head.box(hx - (1 if hx < 0 else -1), 9, -3, hx + 1, 14, -1, Color("#c8b880"), 0.04)
	for tx in range(-3, 3, 2):
		head.box(tx, -3, 7, tx + 1, -1, 8, Color("#f4ecd0"), 0.0)       # upper fangs
	d["head"] = head.build(Vector3(0, 0, 0))
	var jaw := Vox.new(S)
	jaw.box(-3, -3, 0, 3, -1, 10, red.darkened(0.12), 0.05)
	jaw.box(-2, -1, 1, 2, 0, 9, Color("#c0304a"), 0.0)
	for tx2 in range(-2, 3, 2):
		jaw.box(tx2, -1, 8, tx2 + 1, 1, 9, Color("#f4ecd0"), 0.0)
	d["jaw"] = jaw.build(Vector3(0, 0, 0))
	for i in [1, 2, 3]:
		var t := Vox.new(S)
		var r := 5.0 - float(i) * 1.2
		t.ellipsoid(0.0, 0.0, -4.0, r, r * 0.9, 6.0, red.darkened(0.04 * i), 0.06)
		if i == 3:
			t.box(-1, -1, -11, 1, 1, -9, Color("#e8d8a0"), 0.0)
			t.box(-3, -1, -10, 3, 1, -8, Color("#c8b880"), 0.0)
			t.box(0, 1, -12, 1, 4, -8, Color("#e8d8a0"), 0.0)
		d["tail%d" % i] = t.build(Vector3(0, 0, 0))
	var w := Vox.new(S)
	for i in 26:
		var h := 18 - int(i * 0.5)
		var col := Color("#8a1a14") if i % 5 else dark
		w.box(i, -h / 2, 0, i + 1, h - h / 2, 1, col, 0.06)
	for fx in [6, 12, 18, 24]:
		w.box(fx, -9, 0, fx + 1, 9, 1, dark, 0.04)
	w.box(0, 0, -1, 26, 2, 2, red, 0.05)
	d["wing"] = w.build(Vector3(0, 0, 0))
	var wr := Vox.new(S)
	for k in w.cells:
		wr.cells[Vector3i(-1 - k.x, k.y, k.z)] = w.cells[k]
	d["wingR"] = wr.build(Vector3(0, 0, 0))
	var leg := Vox.new(S)
	leg.box(-2, -8, -2, 3, 0, 3, red.darkened(0.08), 0.06)
	leg.box(-3, -10, -2, 4, -8, 5, dark, 0.05)
	for cx in range(-2, 4, 2):
		leg.box(cx, -10, 5, cx + 1, -8, 7, Color("#e8d8a0"), 0.0)
	d["leg"] = leg.build(Vector3(0, 0, 0))
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
