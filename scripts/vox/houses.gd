class_name VoxHouses
extends RefCounted
## Little diorama models of the six homes you can buy, shown on Ms. Deed's desk.

const S := 0.03


static func build(tier: int) -> ArrayMesh:
	var v := Vox.new(S)
	v.box(-22, -2, -18, 22, 0, 18, Color("#5aa83a"), 0.08)           # grass plinth
	v.box(-22, -4, -18, 22, -2, 18, Color("#6a4a2a"), 0.06)
	match clampi(tier, 0, 5):
		0:
			_box_home(v)
		1:
			_shack(v)
		2:
			_cottage(v)
		3:
			_house(v)
		4:
			_manor(v)
		5:
			_castle(v)
	return v.build(Vector3(0, 0, 0))


## Gable roof along the x axis: rises from y0 over the z range [z0, z1).
static func _roof(v: Vox, x0: int, x1: int, z0: int, z1: int, y0: int, col: Color, overhang := 1) -> void:
	var half := (z1 - z0) / 2
	for i in range(half + 1):
		v.box(x0 - overhang, y0 + i, z0 - overhang + i, x1 + overhang, y0 + i + 1, z0 + i + 1, col.darkened(0.04 * i) if i % 2 else col, 0.06)
		v.box(x0 - overhang, y0 + i, z1 + overhang - i - 1, x1 + overhang, y0 + i + 1, z1 + overhang - i, col.darkened(0.04 * i) if i % 2 else col, 0.06)
	v.box(x0 - overhang, y0 + half, z0 + half - 1, x1 + overhang, y0 + half + 1, z0 + half + 1, col.lightened(0.1), 0.05)


static func _door(v: Vox, x: int, z: int, w := 4, h := 8) -> void:
	v.box(x, 0, z, x + w, h, z + 1, Color("#4e3220"), 0.05)
	v.box(x + w - 1, 3, z + 1, x + w, 4, z + 2, Color("#e6b840"), 0.0)


static func _window(v: Vox, x: int, y: int, z: int, face_z := true) -> void:
	if face_z:
		v.box(x, y, z, x + 4, y + 4, z + 1, Color("#ffe29a", 0.25), 0.0)
		v.box(x - 1, y - 1, z, x + 5, y, z + 1, Color("#4e3220"), 0.03)
		v.box(x + 1, y + 1, z + 1, x + 3, y + 3, z + 2, Color("#ffe29a", 0.25), 0.0)


static func _box_home(v: Vox) -> void:
	v.box(-8, 0, -6, 8, 10, 6, Color("#b08a52"), 0.07)
	v.remove_box(-6, 8, -4, 6, 10, 4)
	v.box(-8, 10, -6, -4, 11, -2, Color("#b08a52"), 0.06)
	v.box(-5, 0, 6, 5, 6, 7, Color("#8a6a3a"), 0.05)            # entrance flap
	v.box(-4, 0, 7, 4, 1, 12, Color("#c42234"), 0.07)           # scrap of carpet
	v.box(-4, 4, 6, 4, 5, 7, Color("#e8d8a8"), 0.03)
	v.box(10, 0, -4, 11, 8, -3, Color("#7a5a3a"), 0.05)          # sign post
	v.box(8, 8, -4, 14, 12, -3, Color("#efe6cc"), 0.03)


static func _shack(v: Vox) -> void:
	v.planks(-9, 0, -7, 9, 9, 7, Color("#9a6a3c"), true, 2, 8)
	_roof(v, -9, 9, -7, 7, 9, Color("#6a4222"), 2)
	_door(v, -2, 7)
	_window(v, 4, 4, 7)
	v.box(5, 14, -3, 7, 20, -1, Color("#7a7a86"), 0.06)         # crooked chimney
	v.box(6, 20, -2, 8, 22, 0, Color("#7a7a86"), 0.06)
	v.box(-16, 0, 2, -12, 5, 6, Color("#8a5c36"), 0.06)         # barrel


static func _cottage(v: Vox) -> void:
	v.cobble(-11, 0, -8, 11, 4, 8, Color("#9a9aa6"), 3)
	v.planks(-11, 4, -8, 11, 11, 8, Color("#d8c89a"), true, 3, 9)
	_roof(v, -11, 11, -8, 8, 11, Color("#c8a040"), 2)
	_door(v, -2, 8)
	_window(v, -9, 5, 8)
	_window(v, 5, 5, 8)
	v.box(6, 12, -4, 9, 24, -1, Color("#8a8a96"), 0.06)         # chimney with smoke
	v.box(6, 24, -4, 9, 25, -1, Color("#5a5a66"), 0.04)
	v.ellipsoid(7.5, 29.0, -2.5, 3.0, 2.0, 3.0, Color("#e8e8f0", 0.7), 0.05)
	for fx in range(-10, 10, 3):
		var fc := Color("#d83a4a") if fx % 6 == 0 else Color("#f4d040")
		v.box(fx, 2, 9, fx + 2, 5, 10, fc, 0.1)


static func _house(v: Vox) -> void:
	v.cobble(-12, 0, -9, 12, 5, 9, Color("#a0a0aa"), 3)
	v.planks(-12, 5, -9, 12, 20, 9, Color("#e0d0b0"), true, 3, 10)
	v.box(-12, 12, -9, 12, 13, 9, Color("#8a5a30"), 0.05)        # floor beam
	_roof(v, -12, 12, -9, 9, 20, Color("#b04030"), 2)
	_door(v, -2, 9, 5, 9)
	for wx in [-9, 5]:
		_window(v, wx, 6, 9)
		_window(v, wx, 15, 9)
	v.box(8, 22, -4, 11, 34, -1, Color("#8a8a96"), 0.06)
	v.box(-16, 0, -2, -13, 10, 2, Color("#3a8a3a"), 0.1)         # tree
	v.ellipsoid(-14.5, 14.0, 0.0, 5.0, 5.0, 5.0, Color("#4aa83a"), 0.1)


static func _manor(v: Vox) -> void:
	v.cobble(-18, 0, -9, 18, 6, 9, Color("#b0a8a0"), 3)
	v.planks(-18, 6, -9, 18, 22, 9, Color("#e8dcc0"), true, 3, 11)
	_roof(v, -6, 6, -9, 9, 22, Color("#4a5a8a"), 2)
	_roof(v, -18, -8, -8, 8, 22, Color("#4a5a8a"), 2)
	_roof(v, 8, 18, -8, 8, 22, Color("#4a5a8a"), 2)
	for cx in [-6, -3, 0, 3, 5]:
		v.box(cx, 0, 9, cx + 1, 20, 10, Color("#f0ece0"), 0.04)    # columns
	v.box(-6, 20, 9, 6, 22, 10, Color("#f0ece0"), 0.04)
	_door(v, -2, 10, 5, 9)
	for wx in [-16, -12, 8, 12]:
		_window(v, wx, 8, 9)
		_window(v, wx, 16, 9)
	v.box(-1, 28, -1, 4, 40, 4, Color("#e8dcc0"), 0.05)           # little tower
	v.box(-2, 40, -2, 5, 41, 5, Color("#4a5a8a"), 0.05)
	v.box(0, 41, 0, 3, 46, 3, Color("#4a5a8a"), 0.06)
	v.box(1, 46, 1, 2, 54, 2, Color("#e6b840"), 0.0)


static func _castle(v: Vox) -> void:
	var st := Color("#a8a8b6")
	v.cobble(-16, 0, -12, 16, 18, 12, st, 3)
	for x in range(-16, 16, 4):
		v.box(x, 18, -12, x + 2, 21, -10, st.darkened(0.05), 0.05)
		v.box(x, 18, 10, x + 2, 21, 12, st.darkened(0.05), 0.05)
	for tx in [-18, 14]:
		for tz in [-14, 10]:
			v.cobble(tx, 0, tz, tx + 5, 32, tz + 5, st.lightened(0.04), 3)
			for ax in range(tx - 1, tx + 6, 2):
				v.box(ax, 32, tz - 1, ax + 1, 34, tz, st, 0.04)
				v.box(ax, 32, tz + 5, ax + 1, 34, tz + 6, st, 0.04)
			v.box(tx + 1, 32, tz + 1, tx + 4, 40, tz + 4, Color("#9a3a3a"), 0.06)
			v.box(tx + 2, 40, tz + 2, tx + 3, 48, tz + 3, Color("#d8d8e8"), 0.04)
			v.box(tx + 3, 46, tz + 2, tx + 7, 49, tz + 3, Color("#e6b840"), 0.05)   # pennant
	v.box(-4, 0, 12, 4, 12, 13, Color("#4e3220"), 0.05)           # gate
	v.box(-4, 12, 12, 4, 14, 13, Color("#2a2a32"), 0.05)
	v.box(-2, 5, 13, 2, 6, 14, Color("#e6b840"), 0.0)
	v.box(-4, 18, -4, 4, 38, 4, st.lightened(0.05), 0.05)         # keep
	v.box(-5, 38, -5, 5, 40, 5, Color("#9a3a3a"), 0.05)
	v.box(-3, 40, -3, 3, 46, 3, Color("#9a3a3a"), 0.06)
	v.box(-1, 46, -1, 1, 56, 1, Color("#e6b840"), 0.0)
	for wx in [-2, 1]:
		v.box(wx, 26, 4, wx + 1, 31, 5, Color("#ffe29a", 0.25), 0.0)
