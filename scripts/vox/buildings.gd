class_name VoxBuildings
extends RefCounted
## Voxel buildings. Voxel size is 0.25 m unless noted. Fronts face -Z.

const V := 0.25
const WALL := Color("#a8926c")
const WALL_DARK := Color("#6e5238")
const BEAM := Color("#5a3e26")
const ROOF := Color("#6a4a3e")
const STONE := Color("#8a8a86")
const DOOR := Color("#4a3a86")
const IRON := Color("#3c3c48")
const GOLD := Color("#e6b840")

static var _c := {}


static func _roof_color(x: int, row: int, seed_v: int) -> Color:
	var h := Vox.hash3(x / 2, row, seed_v)
	var c := ROOF.lerp(Color("#8a6048"), h * 0.7)
	if (row % 2) == 1:
		c = c.darkened(0.1)
	if Vox.hash3(x, row, seed_v + 5) < 0.12:
		c = c.lerp(Color("#5f9a3c"), 0.65)                                   # moss
	return c


static func _door(v: Vox, x0: int, y0: int, z: int, w: int, h: int, facing := -1) -> void:
	# a plank double door recessed into the wall at z (voxel plane), facing -z by default
	v.planks(x0, y0, z, x0 + w, y0 + h, z + 1, DOOR, false, 1, 99)
	v.box(x0 + w / 2, y0, z, x0 + w / 2 + 1, y0 + h, z + 1, DOOR.darkened(0.45), 0.0)
	for sy in [y0 + 3, y0 + h - 4]:
		v.box(x0, sy, z + (0 if facing > 0 else -1), x0 + w, sy + 1, z + (1 if facing > 0 else 0), IRON, 0.03)
	var ring_z := z - 1 if facing < 0 else z + 1
	v.box(x0 + w / 2 - 2, y0 + h / 2 - 1, ring_z, x0 + w / 2 + 2, y0 + h / 2 + 1, ring_z + 1, GOLD, 0.03)
	# frame
	v.box(x0 - 1, y0, z - 1, x0, y0 + h + 1, z + 1, BEAM, 0.05)
	v.box(x0 + w, y0, z - 1, x0 + w + 1, y0 + h + 1, z + 1, BEAM, 0.05)
	v.box(x0 - 1, y0 + h, z - 1, x0 + w + 1, y0 + h + 1, z + 1, BEAM, 0.05)


static func _window(v: Vox, x0: int, y0: int, z: int, w: int, h: int, glow := true, facing := -1) -> void:
	v.remove_box(x0, y0, z, x0 + w, y0 + h, z + 1)
	var glass := Color("#ffc860", 0.3) if glow else Color("#6a88d8", 0.5)
	v.box(x0, y0, z, x0 + w, y0 + h, z + 1, glass, 0.0)
	v.box(x0 + w / 2, y0, z, x0 + w / 2 + 1, y0 + h, z + 1, BEAM, 0.04)
	v.box(x0, y0 + h / 2, z, x0 + w, y0 + h / 2 + 1, z + 1, BEAM, 0.04)
	var zf := z - 1 if facing < 0 else z + 1
	v.box(x0 - 1, y0 - 1, zf, x0 + w + 1, y0, zf + 1, BEAM, 0.05)         # sill
	v.box(x0 - 1, y0 + h, zf, x0 + w + 1, y0 + h + 1, zf + 1, BEAM, 0.05)
	v.box(x0 - 1, y0, zf, x0, y0 + h, zf + 1, BEAM, 0.05)
	v.box(x0 + w, y0, zf, x0 + w + 1, y0 + h, zf + 1, BEAM, 0.05)
	for sx in [x0 - 3, x0 + w + 1]:                                          # shutters
		v.box(sx, y0, zf, sx + 2, y0 + h, zf + 1, Color("#8a2a2a"), 0.07)


# ------------------------------------------------------------------ tavern exterior

## 52 x 36 footprint (13 x 9 m). Origin: centre of the footprint on the ground.
static func tavern_exterior() -> ArrayMesh:
	if _c.has("tavern_ext"):
		return _c["tavern_ext"]
	var v := Vox.new(V)
	# stone foundation
	v.cobble(-1, 0, -1, 53, 3, 37, STONE, 3)
	# lower walls
	v.planks(1, 3, 1, 51, 19, 2, WALL, true, 2, 12)         # back (+z side is the rear? front is -z)
	v.planks(1, 3, 35, 51, 19, 36, WALL, true, 2, 12)
	v.planks(1, 3, 2, 2, 19, 35, WALL, false, 2, 12)
	v.planks(50, 3, 2, 51, 19, 35, WALL, false, 2, 12)
	# front wall is z=1; rear z=35.  (front faces -z)
	for cx in [0, 50]:
		for cz in [0, 35]:
			v.box(cx, 3, cz, cx + 2, 21, cz + 2, BEAM, 0.06)
	v.box(0, 18, 0, 52, 20, 2, BEAM, 0.06)
	v.box(0, 18, 34, 52, 20, 36, BEAM, 0.06)
	# upper floor, set back
	v.planks(9, 20, 9, 43, 30, 10, WALL.darkened(0.05), true, 2, 12)
	v.planks(9, 20, 29, 43, 30, 30, WALL.darkened(0.05), true, 2, 12)
	v.planks(9, 20, 10, 10, 30, 29, WALL.darkened(0.08), false, 2, 12)
	v.planks(42, 20, 10, 43, 30, 29, WALL.darkened(0.08), false, 2, 12)
	for cx in [8, 42]:
		for cz in [8, 29]:
			v.box(cx, 20, cz, cx + 2, 31, cz + 2, BEAM, 0.06)
	# big gable roof, ridge along x
	for z in range(-4, 41):
		var d := mini(z + 4, 40 - z)
		var yr := 20 + int(d * 0.85)
		for x in range(-2, 54):
			var c := _roof_color(x, z, 3)
			v.set_v(x, yr, z, c, 0.06)
			v.set_v(x, yr - 1, z, c.darkened(0.15), 0.06)
	for x in range(-2, 54):
		v.set_v(x, 20 + int(22 * 0.85) + 1, 18, Color("#4a3228"), 0.05)
		v.set_v(x, 20 + int(22 * 0.85) + 1, 17, Color("#4a3228"), 0.05)
	# gable ends
	for z in range(0, 36):
		var d2 := mini(z + 1, 36 - z)
		var top := 20 + int(d2 * 0.85) - 2
		for y in range(19, top):
			v.set_v(0, y, z, WALL.darkened(0.1), 0.07)
			v.set_v(51, y, z, WALL.darkened(0.1), 0.07)
	# porch: deck, posts, railing, shed roof, steps
	v.planks(2, 3, -14, 50, 4, 1, Color("#8a7458"), false, 2, 10)
	for px in [4, 18, 34, 48]:
		v.box(px, 4, -14, px + 2, 19, -12, BEAM, 0.06)
	v.box(3, 18, -14, 51, 20, -12, BEAM, 0.06)
	for z in range(-14, 1):
		for x in range(1, 53):
			var yy := 20 - int((0 - z) * 0.35)
			v.set_v(x, yy, z, _roof_color(x, z, 9), 0.06)
			v.set_v(x, yy - 1, z, _roof_color(x, z, 9).darkened(0.15), 0.06)
	for span in [[4, 19], [34, 49]]:
		for rx in range(span[0], span[1]):
			if rx % 3 == 0:
				v.box(rx, 4, -13, rx + 1, 8, -12, BEAM.lightened(0.05), 0.05)
			v.box(rx, 8, -13, rx + 1, 9, -12, BEAM.lightened(0.05), 0.05)
	for i in 3:
		v.cobble(20, 3 - 1 - i + 1, -15 - i * 2, 32, 3 - i + 1, -13 - i * 2, STONE.lightened(0.05), 2)
	# door + windows + sign
	v.remove_box(22, 4, 0, 30, 17, 2)
	_door(v, 22, 4, 1, 8, 13, -1)
	for wx in [8, 40]:
		_window(v, wx, 8, 1, 5, 6, true, -1)
	for wx2 in [14, 33]:
		_window(v, wx2, 22, 9, 5, 5, true, -1)
	v.planks(18, 18, -1, 34, 22, 0, Color("#7a5a3a"), true, 2, 99)
	v.box(17, 22, -1, 35, 23, 0, BEAM, 0.04)
	v.box(17, 17, -1, 35, 18, 0, BEAM, 0.04)
	# chimney (stone), right rear
	v.cobble(38, 20, 22, 44, 50, 28, Color("#8a7a6e"), 3)
	v.box(37, 50, 21, 45, 52, 29, STONE.darkened(0.1), 0.05)
	v.box(39, 51, 23, 43, 52, 27, Color("#1a1210"), 0.0)
	# wall torches' sconces + hanging lantern brackets
	for tx in [20, 32]:
		v.box(tx, 11, -1, tx + 1, 12, 0, IRON, 0.03)
	_c["tavern_ext"] = v.build(Vector3(26, 0, 18))
	return _c["tavern_ext"]


## Canvas sail on poles, like the reference inn. Voxel 0.25.
static func sail() -> ArrayMesh:
	if _c.has("sail"):
		return _c["sail"]
	var v := Vox.new(V)
	var cloth := Color("#eee4c8")
	for y in range(0, 15):
		for x in range(0, 24):
			var bulge := int(sin(float(x) / 23.0 * PI) * 3.0)
			var tilt := int(y * 0.35)
			var c := cloth.lerp(Color("#cdbf9a"), float(14 - y) / 28.0 + (0.2 if (x % 6 == 0) else 0.0))
			if x == 0 or x == 23 or y == 0 or y == 14:
				c = c.darkened(0.2)
			v.set_v(x, y + 3, bulge + tilt, c, 0.05)
	v.box(-1, 0, 0, 1, 20, 2, BEAM, 0.06)
	v.box(23, 0, 0, 25, 20, 2, BEAM, 0.06)
	v.box(-1, 18, 0, 25, 20, 2, BEAM, 0.05)
	_c["sail"] = v.build(Vector3(12, 0, 0))
	return _c["sail"]


# ------------------------------------------------------------------ hut

static func hut() -> ArrayMesh:
	if _c.has("hut"):
		return _c["hut"]
	var v := Vox.new(V)
	v.cobble(-1, 0, -1, 21, 2, 17, STONE, 3)
	v.planks(1, 2, 1, 19, 13, 2, WALL, true, 2, 10)
	v.planks(1, 2, 14, 19, 13, 15, WALL, true, 2, 10)
	v.planks(1, 2, 2, 2, 13, 14, WALL, false, 2, 10)
	v.planks(18, 2, 2, 19, 13, 14, WALL, false, 2, 10)
	for cx in [0, 18]:
		for cz in [0, 14]:
			v.box(cx, 2, cz, cx + 2, 14, cz + 2, BEAM, 0.06)
	for z in range(-2, 18):
		var d := mini(z + 2, 17 - z)
		var yr := 13 + int(d * 0.85)
		for x in range(-2, 22):
			var c := _roof_color(x, z, 11)
			v.set_v(x, yr, z, c, 0.06)
			v.set_v(x, yr - 1, z, c.darkened(0.15), 0.06)
	for z in range(1, 15):
		var d2 := mini(z, 15 - z)
		var top := 13 + int(d2 * 0.85) - 1
		for y in range(13, top):
			v.set_v(1, y, z, WALL.darkened(0.1), 0.07)
			v.set_v(18, y, z, WALL.darkened(0.1), 0.07)
	v.remove_box(8, 3, 0, 12, 10, 2)
	_door(v, 8, 3, 1, 4, 7, -1)
	_window(v, 14, 5, 1, 3, 4, true, -1)
	v.cobble(2, 13, 10, 6, 28, 14, Color("#8a7a6e"), 3)
	v.box(1, 28, 9, 7, 29, 15, STONE.darkened(0.1), 0.05)
	_c["hut"] = v.build(Vector3(10, 0, 8))
	return _c["hut"]


# ------------------------------------------------------------------ lighthouse (voxel 0.5)

static func lighthouse() -> ArrayMesh:
	if _c.has("lighthouse"):
		return _c["lighthouse"]
	var v := Vox.new(0.5)
	var H := 24
	for y in H:
		var r := 5.2 - float(y) / H * 1.9
		var band := (y / 4) % 2 == 0
		var c := Color("#f1ead8") if band else Color("#c4392c")
		v.cyl_y(0.0, 0.0, y, y + 1, r, r, c, 0.05)
		v.cyl_y(0.0, 0.0, y, y + 1, r - 1.0, r - 1.0, c.darkened(0.3), 0.0)
	v.cyl_y(0.0, 0.0, 0, 3, 6.2, 6.2, Color("#8a8a86"), 0.07)
	v.cyl_y(0.0, 0.0, H, H + 1, 6.4, 6.4, Color("#3a3f4a"), 0.04)              # gallery floor
	for k in 16:
		var a := TAU * k / 16.0
		v.box(roundi(cos(a) * 6.0), H + 1, roundi(sin(a) * 6.0), roundi(cos(a) * 6.0) + 1, H + 3, roundi(sin(a) * 6.0) + 1, Color("#2e2c34"), 0.03)
	v.cyl_y(0.0, 0.0, H + 1, H + 5, 3.2, 3.2, Color("#ffe48a", 0.12), 0.0)       # lamp
	v.cyl_y(0.0, 0.0, H + 5, H + 6, 4.2, 4.2, Color("#c4392c"), 0.05)
	for k in 4:
		v.cyl_y(0.0, 0.0, H + 6 + k, H + 7 + k, 3.8 - k, 3.8 - k, Color("#c4392c"), 0.05)
	v.box(-1, 3, -6, 1, 8, -4, Color("#4a3a86"), 0.04)                          # door (front -z)
	for wy in [11, 16, 20]:
		v.box(-1, wy, -4, 1, wy + 2, -3, Color("#ffc860", 0.3), 0.0)
	_c["lighthouse"] = v.build(Vector3(0.5, 0, 0.5))
	return _c["lighthouse"]


# ------------------------------------------------------------------ tavern interior (voxel 0.25)

## The whole room shell: floor, walls, ceiling, beams, windows, fireplace mass, bar, job board,
## wall of shame, pigeonholes, cellar hatch. x -44..44, z -32..32, y 0..26. Front (door) is +z.
static func tavern_room() -> ArrayMesh:
	if _c.has("room"):
		return _c["room"]
	var v := Vox.new(V)
	var tan := Color("#b09870")
	# floor
	v.planks(-44, -1, -32, 44, 0, 32, Color("#a07a4c"), false, 1, 14)
	# walls (inner faces only matter)
	v.planks(-45, 0, -33, 45, 26, -32, tan, true, 2, 14)             # back
	v.planks(-45, 0, 32, 45, 26, 33, tan, true, 2, 14)               # front
	v.planks(-45, 0, -32, -44, 26, 32, tan, false, 2, 14)            # left
	v.planks(44, 0, -32, 45, 26, 32, tan, false, 2, 14)              # right
	# wainscot band
	v.planks(-44, 0, -32, 44, 5, -31, Color("#7a5a3c"), true, 1, 10)
	v.planks(-44, 0, 31, 44, 5, 32, Color("#7a5a3c"), true, 1, 10)
	v.planks(-44, 0, -31, -43, 5, 31, Color("#7a5a3c"), false, 1, 10)
	v.planks(43, 0, -31, 44, 5, 31, Color("#7a5a3c"), false, 1, 10)
	# ceiling + beams
	v.planks(-44, 26, -32, 44, 27, 32, Color("#8a6a48"), true, 2, 16)
	for px in range(-36, 40, 12):
		v.box(px, 0, -32, px + 2, 26, -30, BEAM, 0.06)
		v.box(px, 0, 30, px + 2, 26, 32, BEAM, 0.06)
		v.box(px, 23, -32, px + 2, 26, 32, BEAM, 0.06)               # tie beams across
	for pz in range(-24, 28, 12):
		v.box(-44, 0, pz, -42, 26, pz + 2, BEAM, 0.06)
		v.box(42, 0, pz, 44, 26, pz + 2, BEAM, 0.06)
		v.box(-44, 23, pz, 44, 25, pz + 2, BEAM, 0.06)
	v.box(-44, 24, -1, 44, 26, 1, BEAM.darkened(0.1), 0.05)            # ridge beam
	for px in range(-36, 40, 12):
		for sgn in [-1, 1]:
			for k in 5:
				v.set_v(px, 22 - k, -30 + k if sgn < 0 else 30 - k, BEAM, 0.05)   # braces
	# doors (front = +z door, back = boss door): painted in place, frames proud of the wall
	_door(v, -5, 0, 32, 10, 14, -1)
	_door(v, 14, 0, -33, 10, 16, 1)
	v.box(18, 17, -33, 20, 19, -31, GOLD, 0.03)                     # boss emblem above the door
	v.box(17, 18, -33, 21, 19, -31, GOLD, 0.03)
	# windows on the front wall (moonlight)
	for wx in [-30, 24]:
		v.remove_box(wx, 6, 32, wx + 8, 16, 33)
		v.box(wx, 6, 32, wx + 8, 16, 33, Color("#7a98ff", 0.45), 0.0)
		v.box(wx + 3, 6, 32, wx + 5, 16, 33, BEAM, 0.04)
		v.box(wx, 10, 32, wx + 8, 12, 33, BEAM, 0.04)
		v.box(wx - 1, 5, 31, wx + 9, 6, 33, BEAM, 0.04)
		v.box(wx - 1, 16, 31, wx + 9, 17, 33, BEAM, 0.04)
	# fireplace mass (right wall) with firebox opening facing -x
	v.cobble(34, 0, -22, 44, 12, 6, Color("#8c8a86"), 3)
	v.cobble(38, 12, -22, 44, 27, 6, Color("#8c8a86"), 3)
	v.remove_box(34, 0, -14, 41, 10, -2)
	v.box(41, 0, -14, 44, 10, -2, Color("#181210"), 0.02)             # soot back wall
	v.box(34, 10, -16, 41, 11, 0, Color("#7a7670"), 0.05)             # lintel
	v.box(32, 11, -18, 41, 13, 2, Color("#5a3a22"), 0.06)             # mantel shelf
	v.box(34, 0, -14, 38, 1, -2, Color("#7a7670"), 0.05)              # hearth slab
	# bar counter + top
	v.planks(-40, 0, -22, 0, 5, -14, Color("#8a6038"), true, 2, 12)
	v.box(-41, 5, -23, 1, 6, -13, Color("#a8743c"), 0.05)
	v.box(-40, 1, -14, 0, 2, -13, Color("#d0b060"), 0.04)             # brass foot rail
	# job board (left wall)
	v.planks(-44, 5, -14, -42, 19, 6, Color("#7a5a3a"), false, 1, 12)
	v.planks(-43, 6, -12, -42, 18, 4, Color("#a88a5c"), false, 1, 12)
	for k in 14:
		var nx := -11 + (k % 5) * 3 + int(Vox.hash3(k, 1, 1) * 2)
		var ny := 7 + (k / 5) * 3 + int(Vox.hash3(k, 2, 2) * 2)
		v.box(-42, ny, nx, -41, ny + 2, nx + 2, Color("#efe2bf"), 0.04)
		v.set_v(-41, ny + 1, nx, Color("#c0302a"), 0.0)
	# wall of shame slab (left wall, front half)
	v.cobble(-44, 4, 8, -42, 19, 28, Color("#5e5a68"), 3)
	# pigeonholes (front wall, right)
	v.planks(17, 5, 30, 35, 17, 32, Color("#5a3e26"), true, 2, 12)
	for r in 3:
		for c in 5:
			v.box(18 + c * 3, 6 + r * 4, 30, 20 + c * 3, 9 + r * 4, 32, Color("#1a120c"), 0.0)
			if Vox.hash3(c, r, 9) < 0.6:
				v.box(18 + c * 3, 6 + r * 4, 31, 20 + c * 3, 7 + r * 4, 32, Color("#efe2bf"), 0.03)
	# cellar hatch in the floor (dark planks, iron straps, ring)
	v.planks(-24, -1, 8, -16, 0, 16, Color("#4a3624"), false, 1, 8)
	v.box(-24, 0, 8, -16, 1, 9, IRON, 0.03)
	v.box(-24, 0, 15, -16, 1, 16, IRON, 0.03)
	v.box(-24, 0, 8, -23, 1, 16, IRON, 0.03)
	v.box(-17, 0, 8, -16, 1, 16, IRON, 0.03)
	v.box(-21, 0, 11, -19, 1, 13, Color("#8a8a92"), 0.03)
	# hanging sails across the ceiling
	for sail in [[-36, 8, 4, 28, Color("#e8dcc0")], [8, -22, 36, -4, Color("#9a2a3a")]]:
		for x in range(sail[0], sail[0] + 28):
			for z in range(sail[1], sail[1] + 20):
				var sag := int(sin(float(x - sail[0]) / 27.0 * PI) * sin(float(z - sail[1]) / 19.0 * PI) * 3.0)
				var c: Color = sail[4]
				v.set_v(x, 23 - sag, z, c.darkened(0.12 if (x + z) % 7 == 0 else 0.0), 0.05)
	_c["room"] = v.build(Vector3.ZERO)
	return _c["room"]


static func fire_mesh() -> ArrayMesh:
	if _c.has("fire"):
		return _c["fire"]
	var v := Vox.new(0.1)
	for log_y in 2:
		v.box(0, log_y * 3, 0, 16, log_y * 3 + 3, 3, Color("#5a3a22"), 0.06)
		v.box(0, log_y * 3, 6, 16, log_y * 3 + 3, 9, Color("#4a2e1a"), 0.06)
		v.box(0, log_y * 3, 12, 16, log_y * 3 + 3, 15, Color("#5a3a22"), 0.06)
	for x in range(1, 15):
		for z in range(1, 14):
			var h := int((sin(x * 0.9) * 0.5 + 0.5) * (sin(z * 1.1) * 0.5 + 0.5) * 12.0) + 2
			var edge := minf(minf(x, 15 - x), minf(z, 14 - z)) / 6.0
			h = int(h * clampf(edge + 0.35, 0.0, 1.0))
			for y in range(6, 6 + h):
				var t := float(y - 6) / maxf(h, 1)
				var c := Color("#ff4a12").lerp(Color("#ff9a22"), t * 1.2).lerp(Color("#ffe07a"), clampf(t - 0.5, 0.0, 1.0) * 1.4)
				v.set_v(x, y, z, Color(c.r, c.g, c.b, 0.1), 0.0)
	_c["fire"] = v.build(Vector3(8, 0, 7))
	return _c["fire"]
