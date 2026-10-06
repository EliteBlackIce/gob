class_name VoxProps
extends RefCounted
## Voxel prop library: foliage, rocks, furniture, parcels, small items. Every builder returns
## an ArrayMesh (cached) and documents the voxel size to use with VMat.solid().

static var _c := {}

const LEAF_A := Color("#2f8a2a")
const LEAF_B := Color("#58b83a")
const LEAF_C := Color("#7cd048")
const BARK := Color("#8a6a44")
const WOOD_BROWN := Color("#8a5c36")
const WOOD_DARK := Color("#4e3220")
const IRON := Color("#4a4a56")
const GOLD := Color("#e6b840")
const PAPER := Color("#efe6cc")


static func _cached(key: String, fn: Callable) -> ArrayMesh:
	if _c.has(key):
		return _c[key]
	var m: ArrayMesh = fn.call()
	_c[key] = m
	return m


static func mesh_instance(m: Mesh, vox: float, ppv := 4.0, extra := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = VMat.solid(vox, ppv, extra)
	return mi


# ------------------------------------------------------------------ foliage (voxel 0.25)

const PALM_V := 0.25


static func palm(variant: int) -> ArrayMesh:
	return _cached("palm%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant * 13
		var v := Vox.new(PALM_V)
		var H := 16 + (variant % 3) * 3
		var lean := rng.randf_range(0.6, 1.6) * (1.0 if variant % 2 == 0 else -1.0)
		var top := Vector3i(0, 0, 0)
		for y in H:
			var off := int(round(lean * pow(float(y) / H, 2.0) * 3.0))
			var ring := Color(BARK.r, BARK.g, BARK.b).darkened(0.18 if y % 3 == 0 else 0.0)
			var w := 2 if y < H * 0.8 else 1
			v.box(off, y, 0, off + w, y + 1, w, ring, 0.07)
			top = Vector3i(off, y + 1, 0)
		var fr := rng.randi_range(7, 9)
		for k in fr:
			var ang := TAU * float(k) / fr + rng.randf_range(-0.15, 0.15)
			var dx := cos(ang)
			var dz := sin(ang)
			var L := rng.randi_range(8, 11)
			for step in range(0, L + 1):
				var arch := roundi(sin(float(step) / L * PI * 0.8) * 2.4 - float(step) * 0.35)
				var px := top.x + roundi(dx * step)
				var pz := top.z + roundi(dz * step)
				var py := top.y + arch
				var shade := LEAF_A.lerp(LEAF_C, float(step) / L)
				v.set_v(px, py, pz, shade, 0.08)
				if step >= 2 and step <= L - 2:
					var qx := px + roundi(-dz)
					var qz := pz + roundi(dx)
					v.set_v(qx, py - 1 if step > L / 2 else py, qz, shade.darkened(0.08), 0.08)
					v.set_v(px - roundi(-dz), py - 1 if step > L / 2 else py, pz - roundi(dx), shade.darkened(0.08), 0.08)
				if step >= 4 and step <= L - 3:
					v.set_v(px + roundi(-dz * 2), py - 1, pz + roundi(dx * 2), shade.darkened(0.15), 0.08)
					v.set_v(px - roundi(-dz * 2), py - 1, pz - roundi(dx * 2), shade.darkened(0.15), 0.08)
		for k in 3:
			v.set_v(top.x + (k % 2), top.y - 1 - (k / 2), (k + 1) % 2, Color("#5a3a1e"), 0.1)
		return v.build(Vector3(0.5, 0, 0.5)))


static func bush(variant: int) -> ArrayMesh:
	return _cached("bush%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 400 + variant
		var v := Vox.new(0.2)
		var r := 3.5 + (variant % 3)
		v.ellipsoid(0.0, r * 0.7, 0.0, r, r * 0.75, r, LEAF_B, 0.12)
		for k in v.cells.keys():
			var c: Color = v.cells[k]
			var up := clampf(float(k.y) / (r * 1.4), 0.0, 1.0)
			v.cells[k] = Color(lerpf(LEAF_A.r, LEAF_C.r, up) * (c.r / LEAF_B.r), lerpf(LEAF_A.g, LEAF_C.g, up) * (c.g / LEAF_B.g), lerpf(LEAF_A.b, LEAF_C.b, up) * (c.b / LEAF_B.b), 1.0)
		for k in v.cells.keys():
			if Vox.hash3(k.x, k.y, k.z) < 0.1 and k.y > 1:
				v.cells.erase(k)
		for f in 5:
			var ang := rng.randf() * TAU
			var fc: Color = [Color("#e8402a"), Color("#f4c030"), Color("#f0f0e8"), Color("#e060a0")][f % 4]
			var x := roundi(cos(ang) * (r - 0.5))
			var z := roundi(sin(ang) * (r - 0.5))
			for y in range(int(r * 1.6), -1, -1):
				if v.has_v(x, y, z):
					v.set_v(x, y + 1, z, fc, 0.05)
					break
		return v.build(Vector3(0.5, 0, 0.5)))


static func grass(variant: int) -> ArrayMesh:
	return _cached("grass%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + variant
		var v := Vox.new(0.12)
		for b in 7:
			var x := rng.randi_range(-2, 2)
			var z := rng.randi_range(-2, 2)
			var h := rng.randi_range(2, 5)
			var lean := rng.randi_range(-1, 1)
			for y in h:
				var t := float(y) / h
				var c := Color("#2f7a26").lerp(Color("#6cc03c"), t)
				v.set_v(x + (lean if y > h / 2 else 0), y, z, c, 0.08)
		return v.build(Vector3(0.5, 0, 0.5)))


static func bigleaf(variant: int) -> ArrayMesh:
	return _cached("bigleaf%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 40 + variant
		var v := Vox.new(0.2)
		var n := 6 + variant % 3
		for k in n:
			var ang := TAU * float(k) / n + rng.randf_range(-0.2, 0.2)
			var dx := cos(ang)
			var dz := sin(ang)
			var L := rng.randi_range(6, 9)
			for step in range(1, L + 1):
				var py := roundi(sin(float(step) / L * PI * 0.85) * 2.8) + 1
				var w := 1 if step < 3 or step > L - 2 else 2
				for sdw in range(-w, w + 1):
					var px := roundi(dx * step - dz * sdw * 0.8)
					var pz := roundi(dz * step + dx * sdw * 0.8)
					var c := Color("#1f6a26").lerp(Color("#4aa83a"), float(step) / L)
					if sdw == 0:
						c = c.lightened(0.12)
					v.set_v(px, py - (1 if absi(sdw) == 2 else 0), pz, c, 0.07)
		return v.build(Vector3(0.5, 0, 0.5)))


static func redplant(variant: int) -> ArrayMesh:
	return _cached("red%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 70 + variant
		var v := Vox.new(0.18)
		for k in 7:
			var ang := TAU * float(k) / 7.0 + rng.randf_range(-0.2, 0.2)
			var dx := cos(ang)
			var dz := sin(ang)
			var L := rng.randi_range(5, 8)
			for step in range(1, L + 1):
				var py := roundi(sin(float(step) / L * PI * 0.7) * 3.5) + 1
				var c := Color("#9a1a26").lerp(Color("#ff7a30"), float(step) / L)
				v.set_v(roundi(dx * step), py, roundi(dz * step), c, 0.07)
				if step > 1 and step < L:
					v.set_v(roundi(dx * step - dz * 0.7), py, roundi(dz * step + dx * 0.7), c.darkened(0.1), 0.07)
		return v.build(Vector3(0.5, 0, 0.5)))


static func flower(variant: int) -> ArrayMesh:
	return _cached("flower%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(0.1)
		var col: Color = [Color("#e8402a"), Color("#f4c030"), Color("#f0f0e8"), Color("#e060a0"), Color("#5a8aff")][variant % 5]
		for y in 5:
			v.set_v(0, y, 0, Color("#3a8a2a"), 0.05)
		v.set_v(0, 5, 0, Color("#f4c030"), 0.0)
		for d in [Vector3i(1, 5, 0), Vector3i(-1, 5, 0), Vector3i(0, 5, 1), Vector3i(0, 5, -1)]:
			v.set_v(d.x, d.y, d.z, col, 0.05)
		return v.build(Vector3(0.5, 0, 0.5)))


static func rock(variant: int, mossy := true) -> ArrayMesh:
	return _cached("rock%d%s" % [variant, mossy], func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + variant * 7
		var v := Vox.new(0.25)
		var base := Color("#8a8a86")
		var n := 3
		for k in n:
			var r := rng.randf_range(2.2, 4.5) * (1.0 if k == 0 else 0.7)
			v.ellipsoid(rng.randf_range(-3, 3), r * 0.55, rng.randf_range(-3, 3), r, r * 0.7, r * rng.randf_range(0.8, 1.2), base.lerp(Color("#a8a8a0"), rng.randf()), 0.1)
		if mossy:
			for k in v.cells.keys():
				if not v.cells.has(k + Vector3i(0, 1, 0)):
					if Vox.hash3(k.x, k.y, k.z) < 0.75:
						v.cells[k] = Color("#5f9a3c").lerp(Color("#7cc048"), Vox.hash3(k.z, k.x, 3))
		return v.build(Vector3(0, 0, 0)))


## Tall sea-stack / cliff boulder, voxel 0.5.
static func stack(variant: int) -> ArrayMesh:
	return _cached("stack%d" % variant, func() -> ArrayMesh:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1300 + variant * 11
		var v := Vox.new(0.5)
		var h := rng.randi_range(8, 15)
		var r := rng.randf_range(3.0, 4.5)
		for y in h:
			var rr := r * (1.0 - float(y) / h * 0.45) + rng.randf_range(-0.4, 0.4)
			var band := 0.5 + 0.5 * sin(y * 1.1)
			var c := Color("#7a7a76").lerp(Color("#9c9c94"), band)
			v.cyl_y(0.0, 0.0, y, y + 1, rr, rr * rng.randf_range(0.85, 1.15), c, 0.09)
		for k in v.cells.keys():
			if not v.cells.has(k + Vector3i(0, 1, 0)) and Vox.hash3(k.x, k.y, k.z) < 0.8:
				v.cells[k] = Color("#58a838").lerp(Color("#7cc048"), Vox.hash3(k.z, 5, k.x))
		return v.build(Vector3(0, 0, 0)))


# ------------------------------------------------------------------ small props

static func barrel() -> ArrayMesh:
	return _cached("barrel", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		for y in 18:
			var t := float(y) / 17.0
			var r := 7.0 + 2.2 * sin(t * PI)
			var base := WOOD_BROWN.lerp(Color("#a0703c"), 0.5 * sin(t * 9.0) * 0.5 + 0.25)
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, base, 0.08)
			if y in [2, 7, 11, 15]:
				v.cyl_y(0.0, 0.0, y, y + 1, r + 0.4, r + 0.4, IRON, 0.05)
		v.cyl_y(0.0, 0.0, 17, 18, 6.0, 6.0, WOOD_BROWN.lightened(0.15), 0.08)
		return v.build(Vector3(0.5, 0, 0.5)))


static func crate(tint := Color("#9a6a3c")) -> ArrayMesh:
	return _cached("crate%s" % tint.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.planks(0, 0, 0, 14, 14, 14, tint, true, 2, 9)
		var frame := tint.darkened(0.3)
		for x in [0, 13]:
			for z in [0, 13]:
				v.box(x, 0, z, x + 1, 14, z + 1, frame, 0.04)
		for y in [0, 13]:
			v.box(0, y, 0, 14, y + 1, 1, frame, 0.04)
			v.box(0, y, 13, 14, y + 1, 14, frame, 0.04)
			v.box(0, y, 0, 1, y + 1, 14, frame, 0.04)
			v.box(13, y, 0, 14, y + 1, 14, frame, 0.04)
		for i in 12:
			v.set_v(1 + i, 1 + i, 0, frame, 0.04)
			v.set_v(12 - i, 1 + i, 0, frame, 0.04)
		return v.build(Vector3(7, 0, 7)))


static func torch(lit := true) -> ArrayMesh:
	return _cached("torch%s" % lit, func() -> ArrayMesh:
		var v := Vox.new(0.04)
		v.box(0, 0, 0, 2, 16, 2, WOOD_BROWN, 0.07)
		v.box(-1, 5, -1, 3, 7, 3, IRON, 0.03)
		v.box(-1, 16, -1, 3, 19, 3, Color("#3a2a1c"), 0.06)
		if lit:
			v.box(0, 19, 0, 2, 22, 2, Color("#ffb030", 0.2), 0.0)
			v.box(0, 22, 0, 2, 24, 2, Color("#ffe07a", 0.1), 0.0)
			v.set_v(-1, 20, 0, Color("#ff8a20", 0.3))
			v.set_v(2, 20, 1, Color("#ff8a20", 0.3))
		return v.build(Vector3(1, 0, 1)))


static func lantern(lit := true) -> ArrayMesh:
	return _cached("lantern%s" % lit, func() -> ArrayMesh:
		var v := Vox.new(0.04)
		v.box(0, 0, 0, 8, 1, 8, IRON, 0.03)
		v.box(1, 1, 1, 7, 9, 7, Color("#ffcf70", 0.18 if lit else 1.0), 0.0)
		for x in [0, 7]:
			for z in [0, 7]:
				v.box(x, 1, z, x + 1, 9, z + 1, IRON, 0.03)
		v.box(0, 9, 0, 8, 10, 8, IRON, 0.03)
		v.box(2, 10, 2, 6, 11, 6, IRON, 0.03)
		v.box(3, 11, 3, 5, 12, 5, IRON, 0.03)
		v.box(3, 12, 3, 5, 14, 5, IRON, 0.03)
		return v.build(Vector3(4, 0, 4)))


static func mailbox() -> ArrayMesh:
	return _cached("mailbox", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.box(0, 0, 0, 2, 22, 2, WOOD_BROWN, 0.07)
		v.box(-4, 22, -3, 6, 30, 5, Color("#c0392b"), 0.05)
		v.box(-3, 30, -2, 5, 31, 4, Color("#d84a3a"), 0.05)
		v.box(-4, 22, 5, 6, 30, 6, Color("#6a1a14"), 0.0)            # open mouth
		v.box(6, 24, 0, 7, 34, 1, GOLD, 0.03)                        # flag
		v.box(6, 32, 0, 11, 34, 1, GOLD, 0.03)
		v.box(-2, 26, 4, 3, 27, 6, PAPER, 0.02)                      # letter in the slot
		return v.build(Vector3(1, 0, 1)))


static func bottle(c := Color("#3e9c5a")) -> ArrayMesh:
	return _cached("bottle%s" % c.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.03)
		v.box(0, 0, 0, 4, 8, 4, Color(c.r, c.g, c.b, 0.82), 0.05)
		v.box(1, 8, 1, 3, 13, 3, Color(c.r, c.g, c.b, 0.82), 0.05)
		v.box(1, 13, 1, 3, 14, 3, Color("#8a5a2a"), 0.05)
		v.box(0, 2, 0, 4, 5, 1, PAPER, 0.03)
		return v.build(Vector3(2, 0, 2)))


static func mug(foam := true) -> ArrayMesh:
	return _cached("mug%s" % foam, func() -> ArrayMesh:
		var v := Vox.new(0.03)
		v.box(0, 0, 0, 5, 6, 5, Color("#7a4a28"), 0.07)
		v.box(5, 1, 2, 7, 5, 3, Color("#7a4a28"), 0.07)
		v.box(1, 6, 1, 4, 7, 4, Color("#e8c060") if not foam else Color("#f8f4e4"), 0.05)
		v.box(0, 1, 0, 5, 2, 5, IRON, 0.03)
		v.box(0, 4, 0, 5, 5, 5, IRON, 0.03)
		return v.build(Vector3(2.5, 0, 2.5)))


static func candle(h := 6) -> ArrayMesh:
	return _cached("candle%d" % h, func() -> ArrayMesh:
		var v := Vox.new(0.03)
		v.box(-2, 0, -2, 3, 1, 3, GOLD.darkened(0.2), 0.03)
		v.box(0, 1, 0, 2, h, 2, Color("#f1e8cc"), 0.03)
		v.box(0, h, 0, 1, h + 1, 1, Color("#ffe07a", 0.1), 0.0)
		v.box(0, h + 1, 0, 1, h + 2, 1, Color("#ffb030", 0.2), 0.0)
		return v.build(Vector3(0.5, 0, 0.5)))


static func table() -> ArrayMesh:
	return _cached("table", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.planks(0, 16, 0, 34, 18, 20, Color("#9a6a3c"), true, 2, 17)
		v.box(2, 14, 3, 32, 16, 5, WOOD_DARK, 0.05)
		v.box(2, 14, 15, 32, 16, 17, WOOD_DARK, 0.05)
		for x in [1, 31]:
			for z in [1, 16]:
				v.box(x, 0, z, x + 3, 16, z + 3, WOOD_BROWN.darkened(0.15), 0.07)
		return v.build(Vector3(17, 0, 10)))


static func stool() -> ArrayMesh:
	return _cached("stool", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.cyl_y(0.0, 0.0, 8, 10, 5.0, 5.0, Color("#a47440"), 0.07)
		for a in [Vector2(-3, -3), Vector2(3, -3), Vector2(-3, 3), Vector2(3, 3)]:
			v.box(int(a.x) - 1, 0, int(a.y) - 1, int(a.x) + 1, 8, int(a.y) + 1, WOOD_BROWN.darkened(0.2), 0.07)
		return v.build(Vector3(0.5, 0, 0.5)))


static func sack(c := Color("#b8a070")) -> ArrayMesh:
	return _cached("sack%s" % c.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.ellipsoid(0.0, 6.0, 0.0, 6.0, 6.5, 5.0, c, 0.09)
		v.ellipsoid(0.0, 12.0, 0.0, 3.0, 3.0, 3.0, c.darkened(0.08), 0.09)
		v.box(-3, 10, -3, 3, 11, 3, Color("#6a5638"), 0.04)
		return v.build(Vector3(0.5, 0, 0.5)))


static func banner(color := Color("#9a2a3a")) -> ArrayMesh:
	return _cached("banner%s" % color.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.box(-2, 42, -1, 20, 44, 1, WOOD_DARK, 0.05)
		for y in range(0, 42):
			for x in range(0, 18):
				var edge := x < 2 or x > 15 or y < 2
				var c := GOLD if edge else color.lerp(color.darkened(0.3), float(41 - y) / 60.0)
				if y < 5 and x % 4 < 2 and not edge:
					continue                                           # ragged hem
				v.set_v(x, y, 0, c, 0.05)
		# gold laurel-ish emblem
		v.box(6, 20, 0, 12, 22, 1, GOLD, 0.03)
		v.box(6, 14, 0, 12, 16, 1, GOLD, 0.03)
		v.box(5, 16, 0, 7, 20, 1, GOLD, 0.03)
		v.box(11, 16, 0, 13, 20, 1, GOLD, 0.03)
		v.box(8, 17, 0, 10, 19, 1, GOLD.lightened(0.2), 0.03)
		return v.build(Vector3(9, 42, 0)))


## Flat patterned rug, voxel 0.1, lying on the floor.
static func rug(w: int, d: int, main: Color, trim: Color) -> ArrayMesh:
	return _cached("rug%d_%d_%s" % [w, d, main.to_html()], func() -> ArrayMesh:
		var v := Vox.new(0.1)
		for x in w:
			for z in d:
				var e := mini(mini(x, w - 1 - x), mini(z, d - 1 - z))
				var c := main
				if e < 2:
					c = trim
				elif e < 4:
					c = main.darkened(0.3)
				elif e < 5:
					c = trim.darkened(0.2)
				else:
					var du := absi((x % 8) - 4)
					var dv := absi((z % 8) - 4)
					if du + dv < 3:
						c = main.lightened(0.12)
					elif du + dv < 4:
						c = trim.darkened(0.25)
				v.set_v(x, 0, z, c, 0.04)
		return v.build(Vector3(w / 2.0, 0, d / 2.0)))


# ------------------------------------------------------------------ parcels (voxel 0.04)

const PV := 0.04


static func parcel_cheese() -> ArrayMesh:
	return _cached("p_cheese", func() -> ArrayMesh:
		var v := Vox.new(PV)
		v.cyl_y(0.0, 0.0, 0, 8, 8.0, 8.0, Color("#f0c040"), 0.07)
		v.cyl_y(0.0, 0.0, 0, 1, 8.0, 8.0, Color("#d09a28"), 0.05)
		for k in v.cells.keys():
			if Vox.hash3(k.x, k.y, k.z) < 0.06 and k.y < 7 and k.y > 0:
				v.cells[k] = Color("#c8901c")
		for hole in [Vector3i(-3, 8, -2), Vector3i(2, 8, -4), Vector3i(3, 8, 2), Vector3i(-4, 8, 3)]:
			v.set_v(hole.x, hole.y - 1, hole.z, Color("#a8741a"), 0.0)
		# screaming face on the front (+z)
		for ex in [-4, 1]:
			v.box(ex, 4, 6, ex + 3, 7, 9, Color("#f8f4e4"), 0.0)
			v.box(ex + 1, 5, 8, ex + 2, 6, 9, Color("#201010"), 0.0)
		v.box(-3, 1, 7, 3, 4, 9, Color("#5a0a10"), 0.0)
		v.box(-1, 1, 8, 1, 2, 9, Color("#e0404a"), 0.0)
		return v.build(Vector3(0.5, 0, 0.5)))


static func parcel_potato() -> ArrayMesh:
	return _cached("p_potato", func() -> ArrayMesh:
		var v := Vox.new(PV)
		v.ellipsoid(0.0, 6.0, 0.0, 8.0, 6.5, 7.0, Color("#c4602c"), 0.1)
		for k in v.cells.keys():
			var h := Vox.hash3(k.x, k.y, k.z)
			if h < 0.1:
				v.cells[k] = Color("#8a3a1a")
			elif h > 0.93:
				v.cells[k] = Color("#e08a44")
		for e in [Vector3i(-3, 9, 5), Vector3i(4, 6, 5), Vector3i(0, 11, -3), Vector3i(-5, 5, -3)]:
			v.set_v(e.x, e.y, e.z, Color("#3a1408"), 0.0)
		# glowing cracks (emission mask)
		for k in v.cells.keys():
			if Vox.hash3(k.z, k.x, k.y) < 0.05:
				var c: Color = v.cells[k]
				v.cells[k] = Color(1.0, 0.45, 0.1, 0.35)
		return v.build(Vector3(0.5, 0, 0.5)))


static func parcel_wiggly() -> ArrayMesh:
	return _cached("p_wiggly", func() -> ArrayMesh:
		var v := Vox.new(PV)
		v.planks(-6, 2, -5, 6, 12, 5, Color("#7a4fb0"), true, 2, 8)
		for x in [-6, 5]:
			for z in [-5, 4]:
				v.box(x, 2, z, x + 1, 12, z + 1, Color("#563886"), 0.04)
		for sx in [-3, 2]:
			v.box(sx, 2, -5, sx + 1, 12, 5, GOLD, 0.04)               # gold straps
		for ex in [-5, 1]:
			v.box(ex, 6, 5, ex + 4, 10, 6, Color("#f8f4e4"), 0.0)
			v.box(ex + 1, 7, 5, ex + 3, 9, 6, Color("#201010"), 0.0)
		v.box(-3, 3, 5, 3, 4, 6, Color("#201010"), 0.0)
		for lx in [-4, 2]:
			v.box(lx, 0, -1, lx + 2, 2, 2, Color("#3a2a1a"), 0.04)    # little legs
		return v.build(Vector3(0, 0, 0)))


static func parcel_vase() -> ArrayMesh:
	return _cached("p_vase", func() -> ArrayMesh:
		var v := Vox.new(PV)
		var prof := [4.0, 5.5, 7.0, 7.5, 7.5, 7.0, 6.0, 5.0, 4.0, 3.0, 2.5, 2.5, 3.0, 4.0, 5.0, 5.0]
		for y in prof.size():
			var c := Color("#e4dccb")
			if y in [3, 4, 5, 9, 14]:
				c = Color("#3a6ab8")
			if y == 15:
				c = GOLD
			v.cyl_y(0.0, 0.0, y, y + 1, prof[y], prof[y], c, 0.04)
		for y in [9, 10, 11, 12, 13]:
			v.set_v(-5 - (13 - y if y > 11 else 0), y, 0, GOLD, 0.03)
			v.set_v(4 + (13 - y if y > 11 else 0), y, 0, GOLD, 0.03)
		v.set_v(-6, 13, 0, GOLD)
		v.set_v(5, 13, 0, GOLD)
		return v.build(Vector3(0.5, 0, 0.5)))


static func parcel_anvil() -> ArrayMesh:
	return _cached("p_anvil", func() -> ArrayMesh:
		var v := Vox.new(PV)
		var steel := Color("#5a5e6c")
		v.box(-6, 0, -3, 6, 3, 4, steel.darkened(0.15), 0.06)
		v.box(-3, 3, -2, 3, 8, 3, steel, 0.06)
		v.box(-7, 8, -3, 7, 12, 4, steel.lightened(0.1), 0.06)
		for i in 6:
			v.box(7 + i, 9 + i / 3, -2 + i / 3, 8 + i, 12 - i / 2, 3 - i / 3, steel.lightened(0.05), 0.06)
		v.box(-6, 12, -2, 6, 13, 3, Color("#9aa0b0"), 0.04)
		return v.build(Vector3(0.5, 0, 0.5)))
