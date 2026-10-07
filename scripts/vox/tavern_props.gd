class_name VoxTavern
extends RefCounted
## Extra set dressing for the tavern: food, hanging meat, weapon racks, books, a post-office
## sorting table, a cat, a cage with a former employee... All cached voxel meshes at 0.05 m.

const V := 0.05
const WOOD := Color("#8a5c36")
const WOOD_D := Color("#4e3220")
const IRON := Color("#4a4a56")
const GOLD := Color("#e6b840")
const PAPER := Color("#efe6cc")

static var _c := {}


static func _mk(key: String, fn: Callable) -> ArrayMesh:
	if not _c.has(key):
		_c[key] = fn.call()
	return _c[key]


static func ham() -> ArrayMesh:
	return _mk("ham", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(0, 0, 0, 1, 8, 1, Color("#c8b890"), 0.02)                       # string
		v.ellipsoid(0.5, -4.0, 0.5, 4.0, 5.0, 3.5, Color("#c0645a"), 0.04)
		v.ellipsoid(0.5, -2.0, 0.5, 3.0, 2.5, 3.0, Color("#e8a090"), 0.04)
		v.box(-1, -10, -1, 2, -8, 2, Color("#efe6cc"), 0.02)                  # bone end
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func sausages() -> ArrayMesh:
	return _mk("sausages", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-8, 0, 0, 9, 1, 1, Color("#c8b890"), 0.02)                      # rope
		for i in 5:
			v.box(-7 + i * 3, -6, 0, -5 + i * 3, 0, 2, Color("#a0402e") if i % 2 else Color("#b8503a"), 0.04)
			v.box(-7 + i * 3, -7, 0, -5 + i * 3, -6, 2, Color("#7a2a20"), 0.03)
		return v.build_coarse(Vector3(0, 0, 0.5)))


static func herbs() -> ArrayMesh:
	return _mk("herbs", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(0, 0, 0, 1, 4, 1, Color("#c8b890"), 0.02)
		for i in 3:
			v.box(-2 + i * 2, -9, -1, i * 2, -3, 2, Color("#4a8a3a").lerp(Color("#8aa83a"), i * 0.3), 0.06)
		v.box(-3, -4, -1, 4, -3, 2, Color("#6a4a2a"), 0.03)
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func chandelier() -> ArrayMesh:
	return _mk("chandelier", func() -> ArrayMesh:
		var v := Vox.new(V)
		for k in 16:
			var a := TAU * k / 16.0
			v.box(roundi(cos(a) * 18.0), 0, roundi(sin(a) * 18.0), roundi(cos(a) * 18.0) + 2, 2, roundi(sin(a) * 18.0) + 2, IRON, 0.03)
		v.box(-18, 0, -1, 19, 2, 1, IRON, 0.03)
		v.box(-1, 0, -18, 1, 2, 19, IRON, 0.03)
		v.box(-2, 2, -2, 2, 7, 2, IRON.lightened(0.05), 0.03)                  # hub
		for k in 8:
			var a2 := TAU * k / 8.0
			var cx := roundi(cos(a2) * 18.0)
			var cz := roundi(sin(a2) * 18.0)
			v.box(cx, 2, cz, cx + 2, 6, cz + 2, PAPER, 0.02)                   # candle
			v.box(cx, 6, cz, cx + 2, 8, cz + 2, Color("#ffd060", 0.15), 0.0)   # flame
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func weapon_rack() -> ArrayMesh:
	return _mk("rack", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(0, 0, 0, 2, 26, 3, WOOD_D, 0.04)
		v.box(30, 0, 0, 32, 26, 3, WOOD_D, 0.04)
		v.box(0, 4, 0, 32, 6, 3, WOOD, 0.04)
		v.box(0, 18, 0, 32, 20, 3, WOOD, 0.04)
		var cols := [Color("#b8b4aa"), Color("#a8b0c0"), Color("#8a7a5a")]
		for i in 4:
			var x := 4 + i * 6
			v.box(x, 6, 1, x + 2, 32, 2, cols[i % 3], 0.03)                    # blades
			v.box(x - 1, 14, 1, x + 3, 16, 2, GOLD if i % 2 else IRON, 0.03)
			v.box(x, 6, 1, x + 2, 12, 2, Color("#5a3a1e"), 0.03)
		return v.build_coarse(Vector3(16, 0, 1.5)))


static func armor_stand() -> ArrayMesh:
	return _mk("armor", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-1, 0, -1, 1, 18, 1, WOOD_D, 0.04)
		v.box(-6, 0, -6, 6, 2, 6, WOOD_D, 0.04)
		v.box(-6, 18, -3, 6, 34, 3, Color("#9aa0ac"), 0.04)                    # breastplate
		v.box(-8, 30, -3, -6, 34, 3, Color("#8a909c"), 0.04)                   # pauldrons
		v.box(6, 30, -3, 8, 34, 3, Color("#8a909c"), 0.04)
		v.box(-5, 20, 3, 5, 22, 4, Color("#e6b840"), 0.02)                     # belt trim
		v.box(-4, 34, -4, 4, 42, 4, Color("#9aa0ac"), 0.04)                    # helmet
		v.box(-3, 36, 4, 3, 38, 5, DARK_SLIT, 0.0)
		v.box(-1, 42, -4, 1, 48, 4, Color("#c0302a"), 0.03)                    # plume
		v.box(-6, 8, -3, 6, 18, 3, Color("#8a909c"), 0.04)                     # tasset skirt
		return v.build_coarse(Vector3(0, 0, 0)))


const DARK_SLIT := Color("#14121c")


static func shield(col: Color) -> ArrayMesh:
	return _mk("shield" + col.to_html(), func() -> ArrayMesh:
		var v := Vox.new(V)
		for y in 18:
			var w: int = 8 - maxi(0, y - 11)
			v.box(-w, y, 0, w, y + 1, 2, col, 0.03)
		v.box(-1, 2, 2, 1, 16, 3, GOLD, 0.02)
		v.box(-7, 8, 2, 7, 10, 3, GOLD, 0.02)
		v.box(-2, 7, 3, 2, 11, 4, Color("#e8e0d0"), 0.02)
		return v.build_coarse(Vector3(0, 0, 0)))


static func swords() -> ArrayMesh:
	return _mk("swords", func() -> ArrayMesh:
		var v := Vox.new(V)
		for side in [-1, 1]:
			for i in 28:
				var x := int((i - 14) * side * 0.8)
				v.box(x, i, 0, x + 2, i + 1, 1, Color("#b8b4aa") if i > 6 else Color("#5a3a1e"), 0.03)
			v.box(-3 * side, 6, 0, -3 * side + 2, 8, 1, GOLD, 0.02)
		return v.build_coarse(Vector3(0, 0, 0)))


static func poster(variant: int) -> ArrayMesh:
	return _mk("poster%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(V)
		var paper: Color = [Color("#e8dcb8"), Color("#e0d0a0"), Color("#d8c8a0")][variant % 3]
		v.box(0, 0, 0, 10, 14, 1, paper, 0.03)
		v.box(0, 0, 0, 10, 1, 1, paper.darkened(0.12), 0.02)
		v.box(1, 11, 1, 9, 13, 2, Color("#c0302a"), 0.0)                       # WANTED banner
		match variant % 3:
			0:
				v.box(3, 4, 1, 7, 9, 2, Color("#8aa860"), 0.03)                # goblin face
				v.box(3, 7, 2, 4, 8, 3, DARK_SLIT, 0.0)
				v.box(6, 7, 2, 7, 8, 3, DARK_SLIT, 0.0)
			1:
				v.box(3, 4, 1, 7, 9, 2, Color("#d8d4c0"), 0.03)                # skull
				v.box(3, 6, 2, 5, 8, 3, DARK_SLIT, 0.0)
				v.box(6, 6, 2, 7, 8, 3, DARK_SLIT, 0.0)
			_:
				v.box(2, 3, 1, 8, 9, 2, Color("#b8a070"), 0.03)                # parcel
				v.box(4, 3, 2, 6, 9, 3, Color("#c0302a"), 0.0)
		v.box(4, 1, 1, 7, 2, 2, Color("#6a5a3a"), 0.0)                         # reward line
		v.box(0, 13, 1, 1, 14, 2, IRON, 0.0)
		v.box(9, 13, 1, 10, 14, 2, IRON, 0.0)
		return v.build_coarse(Vector3(5, 0, 0)))


static func island_map() -> ArrayMesh:
	return _mk("map", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-1, -1, 0, 31, 23, 1, WOOD_D, 0.04)                              # frame
		v.box(0, 0, 1, 30, 22, 2, Color("#d8c898"), 0.03)                      # parchment
		v.box(2, 2, 2, 28, 20, 3, Color("#5a88c0"), 0.03)                      # sea
		for x in range(6, 25):
			for y in range(5, 18):
				var d := Vector2((x - 15) / 9.0, (y - 11) / 6.5).length()
				if d < 0.9 + Vox.hash3(x, y, 5) * 0.15:
					v.set_v(x, y, 3, Color("#6aa83a") if d < 0.7 else Color("#d8c878"), 0.05)
		for pt in [Vector2i(10, 8), Vector2i(20, 13)]:
			v.box(pt.x, pt.y, 4, pt.x + 2, pt.y + 2, 5, Color("#c0302a"), 0.0)  # X marks the spot
		v.box(3, 17, 3, 6, 18, 4, Color("#2a2a32"), 0.0)                       # compass rose
		v.box(4, 16, 3, 5, 19, 4, Color("#2a2a32"), 0.0)
		return v.build_coarse(Vector3(15, 0, 0)))


static func bookshelf() -> ArrayMesh:
	return _mk("books", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.planks(0, 0, 0, 44, 52, 3, WOOD_D, true, 2, 12)
		v.box(0, 0, 0, 2, 52, 10, WOOD, 0.04)
		v.box(42, 0, 0, 44, 52, 10, WOOD, 0.04)
		v.box(0, 50, 0, 44, 52, 10, WOOD, 0.04)
		var cols := [Color("#8a2a2a"), Color("#2a5a8a"), Color("#3a7a3a"), Color("#8a6a2a"), Color("#5a2a7a"), Color("#aa8a5a")]
		for r in 4:
			var y := 2 + r * 12
			v.box(0, y, 0, 44, y + 1, 10, WOOD, 0.04)
			var x := 3
			var i := r * 7
			while x < 39:
				var w := 2 + int(Vox.hash3(i, r, 3) * 3)
				var h := 7 + int(Vox.hash3(i, r, 4) * 3)
				v.box(x, y + 1, 1, x + w, y + 1 + h, 9, cols[(i + r) % cols.size()], 0.05)
				v.box(x, y + 1 + h - 3, 9, x + w, y + h - 1, 10, GOLD if i % 3 == 0 else PAPER, 0.02)
				x += w
				i += 1
				if Vox.hash3(i, r, 8) < 0.12:
					x += 3
		return v.build_coarse(Vector3(22, 0, 0)))


static func sorting_table() -> ArrayMesh:
	return _mk("sorting", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.planks(-18, 17, -9, 18, 20, 9, Color("#8a5c36"), true, 2, 12)         # top
		v.box(-18, 15, -9, 18, 17, 9, WOOD_D, 0.04)
		for sx in [-17, 15]:
			for sz in [-8, 6]:
				v.box(sx, 0, sz, sx + 3, 15, sz + 3, WOOD_D, 0.04)
		v.box(-17, 5, -8, 17, 7, -6, WOOD_D, 0.04)                             # stretcher
		# pigeonholes on the back edge
		v.box(-18, 20, -9, 18, 22, -7, WOOD_D, 0.04)
		for i in 6:
			v.box(-16 + i * 6, 22, -9, -12 + i * 6, 28, -7, Color("#2a1a10"), 0.0)
			v.box(-15 + i * 6, 22, -8, -13 + i * 6, 27, -7, PAPER, 0.03)
		# letters, ink pad, stamp, scales
		v.box(-12, 20, 0, -4, 21, 6, PAPER, 0.03)
		v.box(-11, 21, 1, -5, 22, 5, PAPER.darkened(0.08), 0.03)
		v.box(-12, 20, 2, -4, 21, 3, Color("#c0302a"), 0.0)
		v.box(2, 20, 2, 8, 22, 7, Color("#2a2a4a"), 0.03)                      # ink pad
		v.box(4, 22, 3, 6, 28, 5, Color("#7a4a28"), 0.04)                      # stamp
		v.box(3, 28, 2, 7, 30, 6, Color("#b02a30"), 0.03)
		v.box(11, 20, -2, 17, 21, 4, IRON, 0.03)                               # brass scale
		v.box(13, 21, 0, 15, 27, 2, GOLD, 0.02)
		v.box(10, 27, -1, 18, 28, 3, GOLD, 0.02)
		v.box(9, 24, 0, 11, 27, 2, GOLD, 0.02)
		v.box(17, 24, 0, 19, 27, 2, GOLD, 0.02)
		return v.build_coarse(Vector3(0, 0, 0)))


static func bell() -> ArrayMesh:
	return _mk("bell", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-5, 0, -5, 5, 1, 5, GOLD.darkened(0.2), 0.03)
		for y in 6:
			var r := 4.5 - float(y) * 0.5
			v.cyl_y(0.0, 0.0, 1 + y, 2 + y, r, r, GOLD.lightened(0.05 * y), 0.03)
		v.box(-1, 7, -1, 1, 9, 1, GOLD.darkened(0.1), 0.03)
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func hay() -> ArrayMesh:
	return _mk("hay", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(0, 0, 0, 20, 12, 12, Color("#d8b858"), 0.07)
		for x in range(0, 20, 2):
			v.box(x, 0, 0, x + 1, 12, 12, Color("#c0a040"), 0.05)
		v.box(5, 0, 0, 6, 12, 12, Color("#8a6a3a"), 0.03)                      # binding twine
		v.box(14, 0, 0, 15, 12, 12, Color("#8a6a3a"), 0.03)
		v.box(6, 12, 3, 8, 15, 4, Color("#d8b858"), 0.07)                      # stray straw
		return v.build_coarse(Vector3(10, 0, 6)))


static func firewood() -> ArrayMesh:
	return _mk("wood", func() -> ArrayMesh:
		var v := Vox.new(V)
		for row in 4:
			for i in 7 - row:
				var x := row * 2 + i * 4
				for z in 12:
					for dy in 3:
						v.set_v(x + (dy % 2), row * 3 + dy, z, Color("#7a4a28").lerp(Color("#9a6a38"), Vox.hash3(i, row, 1)), 0.05)
				v.box(x, row * 3, 11, x + 3, row * 3 + 3, 12, Color("#e0c898"), 0.02)   # cut ends
		return v.build_coarse(Vector3(14, 0, 6)))


static func cauldron() -> ArrayMesh:
	return _mk("cauldron", func() -> ArrayMesh:
		var v := Vox.new(V)
		for y in 12:
			var r := 4.0 + 3.6 * sin(float(y) / 11.0 * PI * 0.8 + 0.3)
			v.cyl_y(0.0, 0.0, y + 3, y + 4, r, r, Color("#2a2a32").lightened(0.05 * (y % 3)), 0.03)
		v.cyl_y(0.0, 0.0, 14, 15, 6.5, 6.5, Color("#5ad84a", 0.4), 0.05)       # bubbling green brew
		v.box(-4, 0, -4, -2, 3, -2, IRON, 0.03)
		v.box(2, 0, 2, 4, 3, 4, IRON, 0.03)
		v.box(-4, 0, 2, -2, 3, 4, IRON, 0.03)
		v.box(2, 0, -4, 4, 3, -2, IRON, 0.03)
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func rocking_chair() -> ArrayMesh:
	return _mk("rocker", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(0, 7, 0, 12, 9, 12, Color("#7a4a28"), 0.04)                      # seat
		v.box(0, 9, 0, 12, 24, 2, Color("#7a4a28"), 0.04)                      # back
		v.box(1, 12, 0, 11, 14, 1, Color("#a03a3a"), 0.03)                     # cushion stripe
		v.box(0, 9, 0, 2, 15, 12, WOOD_D, 0.03)                                # arms
		v.box(10, 9, 0, 12, 15, 12, WOOD_D, 0.03)
		for sx in [0, 10]:
			for y in range(0, 4):
				v.box(sx, y + (2 if y in [0, 3] else 0) * 0, -2 + y, sx + 2, y + 1, 14 - y, WOOD_D, 0.03)   # rockers
		return v.build_coarse(Vector3(6, 0, 6)))


static func cat(fur: Color) -> Dictionary:
	return _mk_dict("cat" + fur.to_html(), func() -> Dictionary:
		var body := Vox.new(V)
		body.box(0, 0, 0, 6, 5, 12, fur, 0.04)
		body.box(1, 0, 0, 5, 1, 12, fur.lightened(0.25), 0.03)
		body.box(0, 3, 2, 6, 5, 5, fur.darkened(0.15), 0.03)                   # stripes
		body.box(0, 3, 7, 6, 5, 10, fur.darkened(0.15), 0.03)
		var head := Vox.new(V)
		head.box(0, 0, 0, 6, 5, 5, fur, 0.04)
		head.box(0, 5, 0, 2, 7, 2, fur, 0.03)                                  # ears
		head.box(4, 5, 0, 6, 7, 2, fur, 0.03)
		head.box(1, 2, 5, 2, 3, 6, Color("#7aff7a", 0.4), 0.0)                 # green eyes
		head.box(4, 2, 5, 5, 3, 6, Color("#7aff7a", 0.4), 0.0)
		head.box(2, 1, 5, 4, 2, 6, Color("#e8a0a8"), 0.0)
		var tail := Vox.new(V)
		tail.box(0, 0, 0, 2, 2, 9, fur.darkened(0.08), 0.03)
		tail.box(0, 0, 7, 2, 2, 9, fur.darkened(0.3), 0.03)
		return {"body": body.build_coarse(Vector3(3, 0, 6)), "head": head.build_coarse(Vector3(3, 0, 0)), "tail": tail.build_coarse(Vector3(1, 0, 0))})


static func _mk_dict(key: String, fn: Callable) -> Dictionary:
	if not _c.has(key):
		_c[key] = fn.call()
	return _c[key]


static func pigeon() -> Dictionary:
	return _mk_dict("pigeon", func() -> Dictionary:
		var body := Vox.new(V)
		body.box(0, 0, 0, 7, 6, 11, Color("#8a8a9a"), 0.04)
		body.box(0, 3, 0, 7, 6, 4, Color("#6a6a7a"), 0.04)
		body.box(1, 5, 7, 6, 7, 10, Color("#6a9a8a"), 0.04)                    # iridescent neck
		body.box(1, 0, -3, 6, 2, 0, Color("#5a5a6a"), 0.03)                    # tail
		var head := Vox.new(V)
		head.box(0, 0, 0, 5, 5, 5, Color("#8a8a9a"), 0.04)
		head.box(2, 1, 5, 3, 3, 8, Color("#e8a030"), 0.0)                      # beak
		head.box(0, 3, 3, 1, 4, 4, Color("#ff7a3a", 0.35), 0.0)                # orange eyes
		head.box(4, 3, 3, 5, 4, 4, Color("#ff7a3a", 0.35), 0.0)
		return {"body": body.build_coarse(Vector3(3.5, 0, 5)), "head": head.build_coarse(Vector3(2.5, 0, 0))})


static func coat_rack() -> ArrayMesh:
	return _mk("coatrack", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-1, 0, -1, 1, 38, 1, WOOD_D, 0.04)
		v.box(-6, 0, -6, 6, 2, 6, WOOD_D, 0.04)
		for k in 4:
			var a := TAU * k / 4.0 + 0.4
			v.box(roundi(cos(a) * 4), 34, roundi(sin(a) * 4), roundi(cos(a) * 4) + 2, 36, roundi(sin(a) * 4) + 2, WOOD, 0.03)
		v.box(-6, 14, -3, -3, 33, 3, Color("#3a4a8a"), 0.05)                   # a tiny goblin coat
		v.box(-7, 26, -3, -6, 33, 3, Color("#3a4a8a").darkened(0.1), 0.05)
		v.box(3, 30, -2, 8, 36, 2, Color("#2f3f8f"), 0.05)                     # postal cap
		v.box(3, 34, -2, 8, 35, 2, Color("#1e2a60"), 0.04)
		return v.build_coarse(Vector3(0, 0, 0)))


static func cage() -> ArrayMesh:
	return _mk("cage", func() -> ArrayMesh:
		var v := Vox.new(V)
		for k in 8:
			var a := TAU * k / 8.0
			var x := roundi(cos(a) * 8.0)
			var z := roundi(sin(a) * 8.0)
			v.box(x, 0, z, x + 1, 26, z + 1, IRON, 0.03)
		for y in [0, 12, 25]:
			v.cyl_y(0.5, 0.5, y, y + 1, 8.5, 8.5, IRON, 0.03)
			if y == 12 or y == 25:
				v.remove_box(-7, y, -7, 8, y + 1, 8)
		v.box(-1, 26, -1, 2, 32, 2, IRON, 0.03)
		# the previous employee
		var bone := Color("#d8d2bc")
		v.box(-2, 0, -2, 3, 1, 3, Color("#6a4a2a"), 0.04)                      # a tiny stool
		v.box(-3, 8, -2, 3, 14, 2, bone, 0.03)
		v.box(-2, 14, -2, 3, 19, 3, bone, 0.03)                                # skull
		v.box(-1, 16, 3, 0, 17, 4, DARK_SLIT, 0.0)
		v.box(1, 16, 3, 2, 17, 4, DARK_SLIT, 0.0)
		v.box(-3, 1, 3, -1, 8, 5, bone, 0.03)
		v.box(1, 1, 3, 3, 8, 5, bone, 0.03)
		v.box(-3, 18, 3, 3, 20, 4, Color("#2f3f8f"), 0.03)                     # tiny postal cap
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func plant(variant: int) -> ArrayMesh:
	return _mk("plant%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(V)
		for y in 8:
			var r := 4.0 - float(y) * 0.12
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, Color("#b86a3c") if y % 4 else Color("#8a4a28"), 0.04)
		v.cyl_y(0.0, 0.0, 8, 9, 4.2, 4.2, Color("#3a2a1a"), 0.03)
		for i in 6:
			var a := TAU * i / 6.0
			var x := roundi(cos(a) * 3.0)
			var z := roundi(sin(a) * 3.0)
			var h := 8 + (i * 3 + variant * 2) % 6
			v.box(x, 9, z, x + 1, 9 + h, z + 1, Color("#3a8a3a"), 0.05)
			v.box(x - 1, 9 + h - 3, z - 1, x + 2, 9 + h, z + 2, Color("#5ab83a"), 0.06)
			if variant % 2 == 1 and i % 2 == 0:
				v.box(x, 9 + h, z, x + 1, 11 + h, z + 1, Color("#e84a6a"), 0.04)    # flowers
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func plate(kind: int) -> ArrayMesh:
	return _mk("plate%d" % kind, func() -> ArrayMesh:
		var v := Vox.new(V)
		v.cyl_y(0.0, 0.0, 0, 1, 4.0, 4.0, Color("#e8e4d8"), 0.02)
		match kind % 3:
			0:                                                                   # bread loaf
				v.box(-3, 1, -2, 3, 4, 2, Color("#c8883a"), 0.05)
				v.box(-2, 4, -1, 2, 5, 1, Color("#d89848"), 0.05)
			1:                                                                   # cheese wedge
				v.box(-3, 1, -2, 3, 4, 2, Color("#f0c840"), 0.04)
				v.box(-1, 2, 2, 0, 3, 3, Color("#c8a020"), 0.0)
				v.box(1, 3, -2, 2, 4, -1, Color("#c8a020"), 0.0)
			_:                                                                   # drumstick
				v.box(-3, 1, -1, 1, 4, 2, Color("#b8683a"), 0.05)
				v.box(1, 2, 0, 5, 3, 1, Color("#efe6cc"), 0.02)
		return v.build_coarse(Vector3(0.5, 0, 0.5)))


static func lute() -> ArrayMesh:
	return _mk("lute", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.ellipsoid(0.0, 6.0, 0.0, 6.0, 7.0, 3.0, Color("#b06a30"), 0.04)
		v.cyl_y(0.0, 0.0, 6, 7, 2.0, 2.0, DARK_SLIT, 0.0)
		v.box(-1, 12, -1, 1, 34, 1, Color("#5a3a1e"), 0.03)                    # neck
		v.box(-2, 33, -1, 2, 38, 1, Color("#5a3a1e"), 0.03)
		for sx in [-1, 0]:
			v.box(sx, 3, 3, sx + 1, 34, 4, Color("#e8e0c8"), 0.0)
		return v.build_coarse(Vector3(0, 0, 0)))


static func bear_rug() -> ArrayMesh:
	return _mk("bear", func() -> ArrayMesh:
		var v := Vox.new(V * 2.0)
		var fur := Color("#6a4a30")
		v.box(-6, 0, -9, 7, 1, 8, fur, 0.05)                                    # body
		v.box(-9, 0, -6, -6, 1, 4, fur, 0.05)                                   # front paws
		v.box(7, 0, -6, 10, 1, 4, fur, 0.05)
		v.box(-8, 0, 5, -5, 1, 11, fur, 0.05)                                   # back paws
		v.box(6, 0, 5, 9, 1, 11, fur, 0.05)
		v.box(-3, 0, -13, 4, 2, -9, fur.lightened(0.05), 0.04)                  # head
		v.box(-1, 0, -16, 2, 1, -13, fur.darkened(0.1), 0.04)                   # snout
		v.box(0, 1, -16, 1, 2, -15, DARK_SLIT, 0.0)
		v.box(-3, 1, -12, -2, 2, -11, DARK_SLIT, 0.0)
		v.box(3, 1, -12, 4, 2, -11, DARK_SLIT, 0.0)
		v.box(-4, 0, -13, -2, 3, -12, fur, 0.04)                                # ears
		v.box(3, 0, -13, 5, 3, -12, fur, 0.04)
		v.box(-4, 1, -4, 5, 2, 4, fur.darkened(0.08), 0.05)                     # shaggy middle
		return v.build(Vector3(0, 0, 0)))


static func welcome_mat() -> ArrayMesh:
	return _mk("mat", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-14, 0, -8, 14, 1, 8, Color("#8a6a3a"), 0.05)
		v.box(-13, 1, -7, 13, 2, 7, Color("#a88848"), 0.05)
		v.box(-11, 2, -2, -8, 3, 2, Color("#3a2a1a"), 0.0)                      # "WELCOME" scribble, in blocks
		v.box(-6, 2, -2, -3, 3, 2, Color("#3a2a1a"), 0.0)
		v.box(-1, 2, -2, 2, 3, 2, Color("#3a2a1a"), 0.0)
		v.box(4, 2, -2, 7, 3, 2, Color("#3a2a1a"), 0.0)
		v.box(9, 2, -2, 12, 3, 2, Color("#3a2a1a"), 0.0)
		v.box(-12, 2, 4, 12, 3, 5, Color("#c0302a"), 0.0)                       # crossed out
		return v.build_coarse(Vector3(0, 0, 0)))


static func case_stand() -> ArrayMesh:
	return _mk("case", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-34, 0, -9, 34, 12, 9, Color("#5a3a22"), 0.04)                    # cabinet base
		v.box(-34, 12, -9, 34, 14, 9, Color("#7a5232"), 0.04)
		for sx in [-34, 32]:
			v.box(sx, 14, -9, sx + 2, 40, 9, Color("#5a3a22"), 0.04)
		v.box(-34, 38, -9, 34, 41, 9, Color("#5a3a22"), 0.04)
		for gx in range(-32, 33, 8):
			v.box(gx, 14, -9, gx + 1, 38, -8, Color("#6a4a2a"), 0.03)           # glass-frame bars (the glass is imaginary)
		v.box(-32, 26, -9, 32, 27, -8, Color("#6a4a2a"), 0.03)
		v.box(-32, 14, -2, 32, 38, -1, Color("#3a2a1a"), 0.03)                   # velvet back
		for p in [-24, -8, 8, 24]:
			v.box(p - 4, 14, -6, p + 4, 18, 6, Color("#8a1a2a"), 0.03)            # velvet pedestals
			v.box(p - 4, 18, -6, p + 4, 19, 6, GOLD, 0.02)
		return v.build_coarse(Vector3(0, 0, 0)))


static func chalkboard() -> ArrayMesh:
	return _mk("chalk", func() -> ArrayMesh:
		var v := Vox.new(V)
		v.box(-1, 0, 0, 25, 17, 2, WOOD_D, 0.04)
		v.box(1, 2, 2, 23, 15, 3, Color("#2a3a34"), 0.03)
		v.box(3, 12, 3, 14, 13, 4, Color("#e8e4d8"), 0.0)                        # chalk scribbles
		for r in 3:
			v.box(3, 9 - r * 3, 3, 10 + (r * 5) % 9, 10 - r * 3, 4, Color("#e8e4d8"), 0.0)
			v.box(17, 9 - r * 3, 3, 20, 10 - r * 3, 4, Color("#f0c840"), 0.0)
		v.box(3, 2, 3, 6, 3, 4, Color("#e8e4d8"), 0.0)
		return v.build_coarse(Vector3(12, 0, 0)))


static func gold_pile() -> ArrayMesh:
	return _mk("goldpile", func() -> ArrayMesh:
		var v := Vox.new(V)
		for i in 40:
			var x := int((Vox.hash3(i, 1, 1) - 0.5) * 12.0)
			var z := int((Vox.hash3(i, 2, 2) - 0.5) * 10.0)
			var h := maxi(1, 4 - int((absf(x) + absf(z)) * 0.3))
			for y in h:
				v.box(x, y, z, x + 2, y + 1, z + 2, GOLD.lightened(0.1 * Vox.hash3(x, y, z)), 0.05)
		return v.build_coarse(Vector3(0, 0, 0)))


static func tankard_set() -> ArrayMesh:
	return _mk("tankards", func() -> ArrayMesh:
		var v := Vox.new(V)
		for k in 3:
			var x := k * 7
			v.box(x, 0, 0, x + 5, 7, 5, Color("#9a9aa6"), 0.03)
			v.box(x + 1, 6, 1, x + 4, 7, 4, Color("#f4f0e0"), 0.02)             # foam
			v.box(x + 5, 2, 1, x + 7, 5, 3, Color("#8a8a96"), 0.03)             # handle
		return v.build_coarse(Vector3(10, 0, 2)))
