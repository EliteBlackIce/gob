class_name ItemModels
extends RefCounted
## Voxel models for every item base: weapons are held in the first-person viewmodel, and every item
## (weapon or armour) is flattened into a little pixel icon for the inventory.
## Weapon convention: handle at y=0, blade/head towards +Y, centred on x=z=0, faces +Z.

const S := 0.034

const WOOD := Color("#8a5a2e")
const WOOD_D := Color("#5e3c1c")
const STEEL := Color("#c4c8d0")
const STEEL_D := Color("#8a8e9a")
const GOLD := Color("#e6b840")
const RED := Color("#c42234")

static var _mesh_cache := {}
static var _icon_cache := {}


static func _glow(c: Color, rarity: int, amt: float) -> Color:
	# rarity >= 2 weapons get a glowing edge in the rarity colour
	if rarity < 2:
		return c
	var rc := ItemDB.rarity_color(rarity)
	var out := c.lerp(rc, amt)
	out.a = 0.55 if rarity >= 3 else 0.8
	return out


static func weapon(base: String, rarity := 0) -> Vox:
	var v := Vox.new(S)
	match base:
		"opener":
			v.box(-1, 0, -1, 1, 8, 1, WOOD_D, 0.06)                     # handle
			v.box(-3, 8, -1, 3, 9, 1, GOLD, 0.04)                       # guard
			for y in range(9, 30):
				var w := 2 if y < 24 else (1 if y < 29 else 0)
				if w > 0:
					v.box(-w, y, 0, w, y + 1, 1, STEEL, 0.04)
			v.box(0, 9, 0, 1, 28, 1, _glow(STEEL.lightened(0.15), rarity, 0.8), 0.0)
			v.box(-1, 29, 0, 0, 31, 1, STEEL, 0.03)
		"club":
			for y in 28:
				var r := 1.2 + 2.6 * smoothstep(4.0, 24.0, float(y))
				v.cyl_y(0.0, 0.0, y, y + 1, r, r, WOOD if y > 3 else WOOD_D, 0.07)
			for p in [Vector3i(3, 20, 0), Vector3i(-4, 22, 0), Vector3i(0, 24, 3), Vector3i(0, 18, -4), Vector3i(3, 25, -2)]:
				v.set_v(p.x, p.y, p.z, _glow(STEEL, rarity, 0.8), 0.0)
			v.box(-2, 0, -2, 2, 1, 2, WOOD_D, 0.04)
		"cleaver":
			v.box(-1, 0, -1, 1, 9, 1, WOOD_D, 0.06)
			v.box(-5, 9, -1, 5, 10, 1, GOLD, 0.04)
			v.box(-4, 10, 0, 5, 26, 1, STEEL, 0.04)
			v.box(-4, 10, 0, -2, 26, 1, STEEL_D, 0.04)                  # spine
			v.box(4, 10, 0, 5, 26, 1, _glow(STEEL.lightened(0.2), rarity, 0.9), 0.0)  # edge
			v.remove_box(-1, 20, 0, 1, 23, 1)                            # hang hole
		"pencil":
			v.box(-1, 0, -1, 2, 2, 2, Color("#e87a8a"), 0.04)           # eraser
			v.box(-1, 2, -1, 2, 3, 2, STEEL_D, 0.03)                     # ferrule
			v.box(-1, 3, -1, 2, 30, 2, Color("#f2c230"), 0.05)
			v.box(0, 3, -1, 1, 30, 0, Color("#d9a21c"), 0.04)
			for y in range(30, 36):
				var w := 1 if y < 34 else 0
				v.box(-w, y, -w, 1 + w, y + 1, 1 + w, Color("#e8c88a"), 0.04)
			v.box(0, 36, 0, 1, 38, 1, _glow(Color("#2a2a30"), rarity, 0.9), 0.0)
		"pan":
			v.box(-1, 0, -1, 1, 12, 1, Color("#3a3a42"), 0.05)
			v.cyl_y(0.0, 0.0, 12, 13, 2.0, 1.0, Color("#3a3a42"), 0.03)
			# disc facing +z: build in the XY plane
			for x in range(-8, 9):
				for y in range(13, 30):
					var dx := float(x) / 8.0
					var dy := (float(y) - 21.0) / 8.0
					var d := dx * dx + dy * dy
					if d <= 1.0:
						var rim := d > 0.7
						var c := Color("#4a4a54") if rim else Color("#2c2c34")
						if rim:
							c = _glow(c.lightened(0.25), rarity, 0.8)
						v.box(x, y, -1 if rim else 0, x + 1, y + 1, 1, c, 0.05)
		"stamp":
			v.box(-1, 0, -1, 1, 22, 1, WOOD, 0.06)
			v.box(-1, 0, -1, 1, 3, 1, WOOD_D, 0.05)
			v.box(-7, 22, -4, 7, 24, 4, WOOD_D, 0.05)                    # head plate
			v.box(-6, 24, -3, 6, 30, 3, Color("#b02a30"), 0.05)          # rubber block
			v.box(-5, 30, -3, 5, 31, 3, _glow(Color("#e8e0c8"), rarity, 0.6), 0.03)
			v.box(-4, 26, 3, -2, 29, 4, Color("#f0e8d0"), 0.02)          # "OK"
			v.box(1, 26, 3, 4, 27, 4, Color("#f0e8d0"), 0.02)
		"stapler":
			v.box(-2, 0, -3, 2, 6, 3, Color("#2e3a58"), 0.05)             # grip
			v.box(-3, 6, -4, 3, 20, 4, Color("#3a4a78"), 0.05)            # body
			v.box(-3, 6, -4, 3, 8, 4, Color("#22304e"), 0.04)
			v.box(-2, 20, -2, 2, 24, 2, STEEL, 0.04)                      # staple mouth
			v.box(-1, 24, -1, 1, 26, 1, _glow(STEEL.lightened(0.2), rarity, 0.9), 0.0)
			v.box(-2, 12, 4, 2, 15, 5, RED, 0.04)                         # red stripe
		_:
			v.box(-1, 0, -1, 1, 20, 1, WOOD, 0.05)
	return v


static func weapon_mesh(base: String, rarity := 0) -> ArrayMesh:
	var key := "%s|%d" % [base, clampi(rarity, 0, 4)]
	if not _mesh_cache.has(key):
		_mesh_cache[key] = weapon(base, rarity).build(Vector3(0.5, 0, 0.5))
	return _mesh_cache[key]


# ---------------------------------------------------------------- armour (icons)

static func armor(slot: String, base: String) -> Vox:
	var v := Vox.new(S)
	match slot + ":" + base:
		"hat:cap":
			v.box(-7, 0, -6, 7, 4, 6, Color("#2f3f8f"), 0.05)
			v.box(-5, 4, -5, 5, 6, 5, Color("#3a4ca0"), 0.05)
			v.box(-6, 0, 6, 6, 1, 11, Color("#1e2a60"), 0.04)
			v.box(-2, 1, 6, 2, 4, 7, Color("#efe6cc"), 0.02)
		"hat:bag":
			v.box(-6, 0, -5, 6, 12, 5, Color("#b8925a"), 0.07)
			v.box(-3, 2, 5, -1, 4, 6, Color("#2a1a10"), 0.0)
			v.box(1, 2, 5, 3, 4, 6, Color("#2a1a10"), 0.0)
			v.box(-2, 12, -2, 2, 14, 2, Color("#a07c48"), 0.06)
		"hat:bucket":
			for y in 12:
				var r := 6.0 - float(y) * 0.12
				v.cyl_y(0.0, 0.0, y, y + 1, r, r, Color("#a0a4ae") if y % 4 else Color("#80848e"), 0.05)
			v.remove_box(-4, 11, -4, 4, 12, 4)
		"hat:cone":
			for y in 14:
				var r := 6.0 - float(y) * 0.4
				v.cyl_y(0.0, 0.0, y, y + 1, r, r, Color("#f2701a") if (y / 3) % 2 == 0 else Color("#f4f4f0"), 0.04)
		"hat:crown":
			v.box(-6, 0, -6, 6, 5, 6, GOLD, 0.05)
			for p in [Vector2i(-6, -6), Vector2i(-6, 4), Vector2i(4, -6), Vector2i(4, 4), Vector2i(-1, -1)]:
				v.box(p.x, 5, p.y, p.x + 2, 9, p.y + 2, GOLD.lightened(0.1), 0.04)
			v.box(-1, 2, 6, 1, 4, 7, RED, 0.0)
		"vest:leather", "vest:chain":
			var col := Color("#6a4326") if base == "leather" else Color("#9aa0ac")
			v.box(-8, 0, -4, 8, 14, 4, col, 0.07)
			v.remove_box(-3, 10, -4, 3, 14, 4)
			v.box(-1, 0, 4, 1, 14, 5, col.darkened(0.25), 0.04)
		"vest:sack":
			v.box(-8, 0, -4, 8, 14, 4, Color("#b89c64"), 0.08)
			v.remove_box(-3, 10, -4, 3, 14, 4)
			v.box(-4, 3, 4, 4, 9, 5, Color("#efe6cc"), 0.02)
			v.box(-2, 5, 5, 2, 7, 6, RED, 0.0)
		"vest:cardboard":
			v.box(-8, 0, -4, 8, 14, 4, Color("#b08a52"), 0.07)
			v.remove_box(-3, 10, -4, 3, 14, 4)
			v.box(-8, 6, 4, 8, 8, 5, Color("#d8c8a0"), 0.03)
		"vest:bubble":
			v.box(-8, 0, -4, 8, 14, 4, Color("#cfe8f4"), 0.04)
			for x in range(-7, 8, 3):
				for y in range(1, 13, 3):
					v.box(x, y, 4, x + 2, y + 2, 5, Color("#ecf8ff"), 0.02)
			v.remove_box(-3, 10, -4, 3, 14, 4)
		"boots:boots", "boots:waders":
			var bc := Color("#7e4e28") if base == "boots" else Color("#3a6a3a")
			for sx in [-6, 1]:
				v.box(sx, 0, -3, sx + 5, 10 if base == "waders" else 7, 3, bc, 0.06)
				v.box(sx, 0, 3, sx + 5, 4, 8, bc.darkened(0.1), 0.06)
		"boots:skates":
			for sx in [-6, 1]:
				v.box(sx, 3, -3, sx + 5, 9, 3, Color("#d8a0c8"), 0.05)
				v.box(sx, 3, 3, sx + 5, 6, 8, Color("#d8a0c8"), 0.05)
				v.box(sx, 0, -3, sx + 5, 1, 8, STEEL, 0.02)
				v.box(sx, 1, -3, sx + 1, 3, -2, STEEL_D, 0.0)
		"boots:slippers":
			for sx in [-6, 1]:
				v.box(sx, 0, -2, sx + 5, 5, 6, Color("#f08ab0"), 0.12)
				v.box(sx, 5, -2, sx + 5, 7, 2, Color("#f8b0c8"), 0.12)
		"trinket:stamp":
			v.box(-4, 0, -4, 4, 3, 4, Color("#b02a30"), 0.05)
			v.box(-2, 3, -2, 2, 9, 2, WOOD, 0.05)
			v.box(-3, 9, -3, 3, 11, 3, WOOD, 0.05)
		"trinket:mailbox":
			v.box(-5, 0, -3, 5, 8, 5, Color("#3a5ac0"), 0.05)
			v.box(-5, 8, -2, 5, 9, 4, Color("#3a5ac0"), 0.05)
			v.box(5, 4, -1, 6, 11, 1, RED, 0.0)
			v.box(-3, 2, 5, 3, 5, 6, Color("#1a2a60"), 0.0)
		"trinket:duck":
			v.ellipsoid(0, 3, 0, 5.0, 3.5, 4.0, Color("#f4d230"), 0.05)
			v.ellipsoid(2, 8, 0, 3.0, 3.0, 3.0, Color("#f4d230"), 0.05)
			v.box(4, 7, -1, 8, 9, 1, Color("#f08a20"), 0.03)
			v.box(2, 9, 2, 3, 10, 3, Color("#2a1a10"), 0.0)
		"trinket:envelope":
			v.box(-7, 0, -1, 7, 9, 1, GOLD, 0.05)
			for i in 6:
				v.box(-6 + i, 9 - i - 1, 1, 7 - i, 9 - i, 2, GOLD.darkened(0.2), 0.03)
			v.box(-1, 3, 1, 1, 5, 2, RED, 0.0)
		"trinket:pigeon":
			v.ellipsoid(0, 4, 0, 6.0, 4.0, 4.0, Color("#8a8a9a"), 0.07)
			v.ellipsoid(5, 8, 0, 3.0, 3.0, 3.0, Color("#7a7a8a"), 0.07)
			v.box(8, 8, -1, 10, 9, 1, Color("#e8a030"), 0.0)
			v.box(6, 9, 1, 7, 10, 2, Color("#e8f040", 0.4), 0.0)      # glowing eye
			v.box(-9, 4, -1, -5, 6, 1, Color("#6a6a7a"), 0.05)
		_:
			v.box(-4, 0, -4, 4, 8, 4, Color("#a0a0a0"), 0.06)
	return v


static func vox_for(item: Dictionary) -> Vox:
	if item["slot"] == "weapon":
		return weapon(item["base"], int(item["rarity"]))
	return armor(item["slot"], item["base"])


## 2D pixel icon: weapons are shown diagonally (like Minecraft tools), armour front-on.
static func icon(item: Dictionary) -> ImageTexture:
	var key := "%s|%s|%d" % [item["slot"], item["base"], int(item["rarity"])]
	if _icon_cache.has(key):
		return _icon_cache[key]
	var v := vox_for(item)
	var weapon_like: bool = item["slot"] == "weapon"
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for k: Vector3i in v.cells:
		lo = lo.min(Vector3(k))
		hi = hi.max(Vector3(k) + Vector3.ONE)
	var ext := hi - lo
	var ang := deg_to_rad(-42.0) if weapon_like else 0.0
	var ca := cos(ang)
	var sa := sin(ang)
	# project every voxel to icon space, drawing farther voxels first
	var order: Array = v.cells.keys()
	order.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return a.z < b.z)
	var maxdim := maxf(ext.x, ext.y)
	if weapon_like:
		maxdim = Vector2(ext.x, ext.y).length()
	var sc := float(n - 4) / maxf(maxdim, 1.0)
	var cx := (lo.x + hi.x) * 0.5
	var cy := (lo.y + hi.y) * 0.5
	for k: Vector3i in order:
		var c: Color = v.cells[k]
		var px := float(k.x) + 0.5 - cx
		var py := float(k.y) + 0.5 - cy
		var rx := px * ca - py * sa
		var ry := px * sa + py * ca
		var bs := maxi(1, int(ceil(sc)) + (1 if weapon_like and sc > 0.9 else 0))
		var ix := int(round(n * 0.5 + rx * sc - bs * 0.5))
		var iy := int(round(n * 0.5 - ry * sc - bs * 0.5))
		var shade := 1.0 - 0.05 * float(hi.z - k.z) / maxf(ext.z, 1.0)
		var pc := Color(c.r * shade, c.g * shade, c.b * shade, 1.0)
		for ox in bs:
			for oy in bs:
				var qx := ix + ox
				var qy := iy + oy
				if qx >= 0 and qy >= 0 and qx < n and qy < n:
					img.set_pixel(qx, qy, pc)
	# dark outline
	var out := img.duplicate() as Image
	for y in n:
		for x in n:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var xx: int = x + d.x
				var yy: int = y + d.y
				if xx >= 0 and yy >= 0 and xx < n and yy < n and img.get_pixel(xx, yy).a > 0.0:
					out.set_pixel(x, y, Color(0.07, 0.05, 0.04, 1.0))
					break
	var tex := ImageTexture.create_from_image(out)
	_icon_cache[key] = tex
	return tex
