class_name DProps
extends RefCounted
## Voxel set dressing and interactables for dungeons. Every function returns a cached mesh.

const IRON := Color("#4a4a56")
const GOLD := Color("#e6b840")
const WOOD := Color("#8a5c36")
const WOOD_D := Color("#4e3220")

static var _c := {}


static func _cached(key: String, fn: Callable) -> Variant:
	if _c.has(key):
		return _c[key]
	var m: Variant = fn.call()
	_c[key] = m
	return m


# ---------------------------------------------------------------- chests

const CHEST_COLORS := [Color("#8a5c36"), Color("#a8b0c0"), Color("#e6b840")]


## {"body": mesh, "lid": mesh}. The lid pivots at its back-bottom edge (origin there).
static func chest(tier: int) -> Dictionary:
	return _cached("chest%d" % tier, func() -> Dictionary:
		var c: Color = CHEST_COLORS[clampi(tier, 0, 2)]
		var trim := Color("#3a3a46") if tier < 2 else Color("#a87a1a")
		var body := Vox.new(0.05)
		body.planks(0, 0, 0, 16, 8, 10, c, true, 2, 8)
		for bx in [1, 14]:
			body.box(bx, 0, -1, bx + 1, 8, 11, trim, 0.04)
		body.box(0, 0, 0, 16, 1, 10, c.darkened(0.3), 0.04)
		body.box(1, 7, 1, 15, 8, 9, Color("#2a1a10"), 0.03)             # dark inside
		var lid := Vox.new(0.05)
		lid.planks(0, 0, 0, 16, 4, 10, c.lightened(0.04), true, 2, 8)
		for y in range(4, 7):
			var inset := y - 3
			lid.planks(0, y, inset, 16, y + 1, 10 - inset, c.lightened(0.06), true, 2, 8)
		for bx in [1, 14]:
			lid.box(bx, 0, -1, bx + 1, 4, 11, trim, 0.04)
			lid.box(bx, 4, 0, bx + 1, 7, 10, trim, 0.04)
		lid.box(7, 0, 10, 9, 3, 11, GOLD, 0.03)                           # lock
		lid.box(7, 1, 11, 9, 2, 12, Color("#5a3a08"), 0.0)
		return {"body": body.build(Vector3(8, 0, 5)), "lid": lid.build(Vector3(8, 0, 0))})


static func pot(variant: int) -> ArrayMesh:
	return _cached("pot%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var base: Color = [Color("#b86a3c"), Color("#a05a38"), Color("#c87a48")][variant % 3]
		for y in 12:
			var t := float(y) / 11.0
			var r := 3.0 + 3.0 * sin(t * PI * 0.9 + 0.2)
			if y > 9:
				r = 3.4
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, base if y % 5 else base.darkened(0.2), 0.07)
		v.cyl_y(0.0, 0.0, 11, 12, 3.8, 3.8, base.lightened(0.1), 0.05)
		v.remove_box(-2, 11, -2, 2, 12, 2)
		return v.build(Vector3(0.5, 0, 0.5)))


static func keg() -> ArrayMesh:
	return _cached("keg", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		for y in 16:
			var t := float(y) / 15.0
			var r := 6.4 + 2.0 * sin(t * PI)
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, Color("#a02a24") if y % 6 != 0 else Color("#e8dcc0"), 0.07)
		for by in [2, 13]:
			v.cyl_y(0.0, 0.0, by, by + 1, 8.6, 8.6, IRON, 0.04)
		v.box(-2, 6, 7, 2, 10, 9, Color("#f4ecd0"), 0.02)                 # skull blaze
		v.box(-2, 6, 8, -1, 8, 9, Color("#1a1a20"), 0.0)
		v.box(1, 6, 8, 2, 8, 9, Color("#1a1a20"), 0.0)
		v.box(-1, 4, 8, 1, 6, 9, Color("#f4ecd0"), 0.0)
		v.box(0, 16, 0, 1, 20, 1, Color("#e8dcb0"), 0.03)                 # fuse
		v.box(0, 20, 0, 1, 21, 1, Color(1.0, 0.7, 0.2, 0.2), 0.0)
		return v.build(Vector3(0.5, 0, 0.5)))


static func barrel() -> ArrayMesh:
	return VoxProps.barrel()


static func crate() -> ArrayMesh:
	return VoxProps.crate()


# ---------------------------------------------------------------- decor

static func bones(variant: int) -> ArrayMesh:
	return _cached("bones%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var bone := Color("#dcd6c0")
		v.ellipsoid(2.0, 2.0, 2.0, 3.0, 2.0, 3.0, bone.darkened(0.1), 0.08)
		v.box(5, 0, 1, 12, 1, 2, bone, 0.04)
		v.box(6, 0, 4, 11, 1, 5, bone.darkened(0.1), 0.04)
		v.box(10, 0, 0, 12, 2, 3, bone, 0.04)
		v.box(0, 3, 1, 1, 4, 2, DARK_EYE, 0.0)
		v.box(3, 3, 1, 4, 4, 2, DARK_EYE, 0.0)
		if variant % 2 == 0:
			v.box(-4, 0, 6, 4, 1, 7, bone, 0.05)
			v.box(-2, 1, 6, 2, 2, 7, bone, 0.05)
		return v.build(Vector3(4, 0, 3)))


const DARK_EYE := Color("#1a1a20")


static func coffin() -> ArrayMesh:
	return _cached("coffin", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var wood := Color("#4e3a2a")
		v.planks(0, 0, 0, 14, 8, 34, wood, false, 2, 12)
		v.box(1, 8, 1, 13, 9, 33, wood.lightened(0.08), 0.05)
		v.box(5, 9, 6, 9, 10, 26, wood.lightened(0.12), 0.05)             # cross
		v.box(3, 9, 12, 11, 10, 14, wood.lightened(0.12), 0.05)
		for z in [2, 31]:
			v.box(0, 0, z, 14, 8, z + 1, IRON, 0.04)
		return v.build(Vector3(7, 0, 17)))


static func pillar(theme: String) -> ArrayMesh:
	return _cached("pillar" + theme, func() -> ArrayMesh:
		var v := Vox.new(0.25)
		var c := DungeonBuilder.theme_colors(theme)["wall"] as Color
		v.cobble(-2, 0, -2, 2, 24, 2, c.lightened(0.05), 2)
		v.box(-3, 0, -3, 3, 2, 3, c.darkened(0.1), 0.05)
		v.box(-3, 22, -3, 3, 24, 3, c.darkened(0.1), 0.05)
		return v.build(Vector3(0, 0, 0)))


static func brazier(lit := true) -> ArrayMesh:
	return _cached("brazier%s" % lit, func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.box(-1, 0, -1, 1, 10, 1, IRON, 0.04)
		v.box(-3, 0, -3, 3, 1, 3, IRON.darkened(0.2), 0.04)
		v.box(-4, 10, -4, 4, 12, 4, IRON, 0.04)
		v.box(-5, 12, -5, 5, 14, 5, IRON.lightened(0.05), 0.04)
		v.box(-4, 12, -4, 4, 13, 4, Color("#3a1a10"), 0.05)
		if lit:
			v.box(-3, 13, -3, 3, 16, 3, Color("#ff8a20", 0.25), 0.1)
			v.box(-2, 16, -2, 2, 19, 2, Color("#ffb030", 0.2), 0.1)
			v.box(-1, 19, -1, 1, 22, 1, Color("#ffe07a", 0.1), 0.0)
		return v.build(Vector3(0.5, 0, 0.5)))


static func shrooms(color: Color, variant: int) -> ArrayMesh:
	return _cached("shroom%s%d" % [color.to_html(), variant], func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var rng := RandomNumberGenerator.new()
		rng.seed = 100 + variant
		for i in 4:
			var x := rng.randi_range(-5, 5)
			var z := rng.randi_range(-5, 5)
			var h := rng.randi_range(3, 9)
			var r := rng.randf_range(1.8, 3.4)
			v.box(x, 0, z, x + 1, h, z + 1, Color("#e8dcc0"), 0.05)
			v.cyl_y(x + 0.5, z + 0.5, h, h + 2, r, r, Color(color.r, color.g, color.b, 0.45), 0.08)
			v.cyl_y(x + 0.5, z + 0.5, h + 2, h + 3, r * 0.6, r * 0.6, Color(color.r, color.g, color.b, 0.35), 0.06)
		return v.build(Vector3(0, 0, 0)))


static func crystals(color: Color, variant: int) -> ArrayMesh:
	return _cached("cryst%s%d" % [color.to_html(), variant], func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7 + variant
		for i in 5:
			var x := rng.randi_range(-5, 5)
			var z := rng.randi_range(-5, 5)
			var h := rng.randi_range(6, 18)
			for y in h:
				var w := 1 if y < h - 3 else 0
				v.box(x - w, y, z - w, x + 1 + w, y + 1, z + 1 + w, Color(color.r, color.g, color.b, 0.5 if y > 3 else 1.0).lightened(0.08 * float(y) / h), 0.06)
		return v.build(Vector3(0, 0, 0)))


static func stalagmite(color: Color, variant: int) -> ArrayMesh:
	return _cached("stal%s%d" % [color.to_html(), variant], func() -> ArrayMesh:
		var v := Vox.new(0.1)
		var h := 8 + (variant % 3) * 3
		for y in h:
			var r := 2.2 * (1.0 - float(y) / h) + 0.4
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, color.lightened(0.06 * float(y) / h), 0.08)
		return v.build(Vector3(0.5, 0, 0.5)))


static func stalactite(color: Color, variant: int) -> ArrayMesh:
	return _cached("stac%s%d" % [color.to_html(), variant], func() -> ArrayMesh:
		var v := Vox.new(0.1)
		var h := 6 + (variant % 3) * 3
		for y in h:
			var r := 2.2 * (float(y) / h) + 0.3
			v.cyl_y(0.0, 0.0, y, y + 1, r, r, color.darkened(0.05), 0.08)
		return v.build(Vector3(0.5, h, 0.5)))


static func chain(length_vox: int) -> ArrayMesh:
	return _cached("chain%d" % length_vox, func() -> ArrayMesh:
		var v := Vox.new(0.05)
		for y in length_vox:
			if y % 3 == 0:
				v.box(-1, y, 0, 1, y + 1, 1, IRON.lightened(0.1), 0.04)
			else:
				v.box(0, y, -1, 1, y + 1, 1, IRON, 0.04)
		return v.build(Vector3(0, length_vox, 0)))


static func altar(color: Color) -> ArrayMesh:
	return _cached("altar" + color.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var st := Color("#8a8a96")
		v.cobble(-7, 0, -7, 7, 3, 7, st.darkened(0.1), 3)
		v.cobble(-5, 3, -5, 5, 9, 5, st, 3)
		v.box(-6, 9, -6, 6, 11, 6, st.lightened(0.1), 0.05)
		v.box(-2, 11, -2, 2, 15, 2, Color(color.r, color.g, color.b, 0.3), 0.0)
		v.box(-1, 15, -1, 1, 17, 1, Color(color.r, color.g, color.b, 0.15), 0.0)
		for p in [Vector2i(-6, -6), Vector2i(5, -6), Vector2i(-6, 5), Vector2i(5, 5)]:
			v.box(p.x, 11, p.y, p.x + 1, 14, p.y + 1, st.darkened(0.1), 0.05)
			v.box(p.x, 14, p.y, p.x + 1, 15, p.y + 1, Color(color.r, color.g, color.b, 0.3), 0.0)
		return v.build(Vector3(0, 0, 0)))


static func campfire(lit := true) -> ArrayMesh:
	return _cached("campfire%s" % lit, func() -> ArrayMesh:
		var v := Vox.new(0.05)
		var rock := Color("#7a7a86")
		for i in 10:
			var a := TAU * float(i) / 10.0
			v.box(roundi(cos(a) * 7.0), 0, roundi(sin(a) * 7.0), roundi(cos(a) * 7.0) + 3, 3, roundi(sin(a) * 7.0) + 3, rock.darkened(0.1 * (i % 3)), 0.08)
		v.box(-6, 1, -1, 6, 3, 1, WOOD_D, 0.06)
		v.box(-1, 1, -6, 1, 3, 6, WOOD, 0.06)
		if lit:
			v.box(-3, 3, -3, 3, 6, 3, Color("#ff7a20", 0.25), 0.1)
			v.box(-2, 6, -2, 2, 10, 2, Color("#ffb030", 0.2), 0.1)
			v.box(-1, 10, -1, 1, 13, 1, Color("#ffe07a", 0.1), 0.0)
		return v.build(Vector3(0, 0, 0)))


static func cart() -> ArrayMesh:
	return _cached("cart", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.planks(-14, 5, -9, 14, 7, 9, WOOD, true, 2, 10)
		v.planks(-14, 7, -9, 14, 12, -8, WOOD_D, true, 2, 10)
		v.planks(-14, 7, 8, 14, 12, 9, WOOD_D, true, 2, 10)
		for sx in [-13, 12]:
			v.box(sx, 7, -9, sx + 1, 12, 9, WOOD_D, 0.05)
		for wz in [-11, 10]:
			for y in range(0, 9):
				for x in range(-3, 4):
					var d := Vector2(x, y - 4).length()
					if d <= 4.2 and d > 1.2:
						v.set_v(x, y, wz, WOOD_D.lightened(0.1), 0.05)
		# goods: potions + bags
		v.box(-10, 7, -6, -6, 11, -2, Color("#b8a070"), 0.06)
		v.box(-4, 7, 2, 0, 10, 6, Color("#9a3a8a", 0.45), 0.05)
		v.box(3, 7, -5, 6, 12, -2, Color("#3e9c5a", 0.45), 0.05)
		v.box(7, 7, 2, 11, 9, 7, Color("#d83a2a", 0.5), 0.05)
		# awning on poles
		for p in [Vector2i(-13, -9), Vector2i(12, -9), Vector2i(-13, 8), Vector2i(12, 8)]:
			v.box(p.x, 12, p.y, p.x + 1, 26, p.y + 1, WOOD_D, 0.05)
		for x in range(-15, 16):
			for z in range(-11, 11):
				v.set_v(x, 26 + (1 if abs(z) < 3 else 0), z, Color("#b02a3a") if (x / 3) % 2 == 0 else Color("#efe6cc"), 0.05)
		return v.build(Vector3(0, 0, 0)))


## Portcullis gate for a 3-wide corridor opening (voxel 0.25: 12 wide, 22 tall).
static func gate(theme: String) -> ArrayMesh:
	return _cached("gate" + theme, func() -> ArrayMesh:
		var v := Vox.new(0.25)
		var c: Color = DungeonBuilder.theme_colors(theme)["accent"]
		for x in range(0, 12):
			if x % 2 == 0:
				v.box(x, 0, 0, x + 1, 22, 1, IRON.lightened(0.05), 0.05)
				v.box(x, 0, 0, x + 1, 1, 1, Color("#8a8a96"), 0.03)
		for y in [3, 9, 15, 20]:
			v.box(0, y, 0, 12, y + 1, 1, IRON, 0.04)
		for x in range(0, 12, 4):
			v.box(x, 0, -1, x + 1, 22, 0, c, 0.05)
		return v.build(Vector3(6, 0, 0.5)))


static func portal(color: Color) -> ArrayMesh:
	return _cached("portal" + color.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.1)
		var st := Color("#6a6a78")
		for i in 40:
			var a := PI * float(i) / 39.0
			var x := roundi(cos(a) * 14.0)
			var y := roundi(sin(a) * 18.0)
			v.box(x - 1, y, -2, x + 2, y + 2, 3, st.darkened(0.05 * (i % 3)), 0.07)
		v.box(-16, 0, -2, -13, 2, 3, st, 0.05)
		v.box(13, 0, -2, 16, 2, 3, st, 0.05)
		for x in range(-12, 13):
			for y in range(0, 17):
				var e := (float(x) / 12.0) * (float(x) / 12.0) + (float(y) / 17.0) * (float(y) / 17.0)
				if e < 0.95:
					v.set_v(x, y, 0, Color(color.r, color.g, color.b, 0.3).lerp(Color(color.r, color.g, color.b, 0.15), e), 0.1)
		return v.build(Vector3(0, 0, 0)))


static func stairs(theme: String) -> ArrayMesh:
	return _cached("stairs" + theme, func() -> ArrayMesh:
		var v := Vox.new(0.1)
		var c: Color = DungeonBuilder.theme_colors(theme)["floor"]
		for i in 10:
			v.box(-12, -i - 1, i * 2 - 6, 12, -i, i * 2 - 4 + 2, c.darkened(0.06 * i), 0.07)
		v.box(-14, 0, -8, -12, 4, 16, c.lightened(0.05), 0.06)
		v.box(12, 0, -8, 14, 4, 16, c.lightened(0.05), 0.06)
		v.box(-12, -11, -6, 12, -10, 16, Color("#0a0810"), 0.0)
		return v.build(Vector3(0, 0, 0)))


static func spikes() -> ArrayMesh:
	return _cached("spikes", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		for x in range(-8, 8, 4):
			for z in range(-8, 8, 4):
				for y in 7:
					var w := 1 if y < 4 else 0
					v.box(x - w, y, z - w, x + 1 + w, y + 1, z + 1 + w, Color("#c8ccd4").darkened(0.12 * float(7 - y) / 7.0), 0.04)
		return v.build(Vector3(0, 0, 0)))


static func plate() -> ArrayMesh:
	return _cached("plate", func() -> ArrayMesh:
		var v := Vox.new(0.05)
		v.box(-9, 0, -9, 9, 1, 9, Color("#6a6a74"), 0.05)
		v.box(-8, 1, -8, 8, 2, 8, Color("#8a6a3a"), 0.06)
		v.box(-2, 2, -2, 2, 3, 2, Color("#c0302a"), 0.0)
		return v.build(Vector3(0, 0, 0)))


static func coin(variant := 0) -> ArrayMesh:
	return _cached("coin%d" % variant, func() -> ArrayMesh:
		var v := Vox.new(0.03)
		v.cyl_y(0.0, 0.0, 0, 2, 4.0, 4.0, Color("#e6b840"), 0.05)
		v.cyl_y(0.0, 0.0, 0, 1, 4.0, 4.0, Color("#b8861a"), 0.03)
		v.box(-1, 0, -1, 1, 2, 1, Color("#fff0a0", 0.6), 0.0)
		return v.build(Vector3(0.5, 1, 0.5)))


static func orb(color: Color) -> ArrayMesh:
	return _cached("orb" + color.to_html(), func() -> ArrayMesh:
		var v := Vox.new(0.035)
		v.ellipsoid(0.0, 0.0, 0.0, 4.0, 4.0, 4.0, Color(color.r, color.g, color.b, 0.35), 0.05)
		v.ellipsoid(0.0, 0.0, 0.0, 2.0, 2.0, 2.0, Color(color.r, color.g, color.b, 0.15).lightened(0.3), 0.0)
		return v.build(Vector3(0, 0, 0)))


static func flask() -> ArrayMesh:
	return _cached("flask", func() -> ArrayMesh:
		var v := Vox.new(0.035)
		v.box(-3, 0, -2, 3, 8, 2, Color("#7a4a28"), 0.06)
		v.box(-1, 8, -1, 1, 11, 1, Color("#7a4a28"), 0.05)
		v.box(-2, 11, -2, 2, 13, 2, Color("#b8925a"), 0.04)
		v.box(-3, 2, 2, 3, 5, 3, Color("#e8d8a8"), 0.03)
		return v.build(Vector3(0, 0, 0)))
