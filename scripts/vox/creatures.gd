class_name VoxCreatures
extends RefCounted
## Voxel meshes for the enemies. Each returns a Dictionary of named ArrayMeshes.

static var _c := {}


static func crow() -> Dictionary:
	if _c.has("crow"):
		return _c["crow"]
	var navy := Color("#26253a")
	var sheen := Color("#3c3c60")
	var v := Vox.new(0.06)
	v.ellipsoid(0.0, 3.0, 0.0, 3.2, 2.8, 5.0, navy, 0.07)
	v.ellipsoid(0.0, 2.0, 0.5, 2.4, 1.5, 3.4, Color("#34324a"), 0.07)
	v.ellipsoid(0.0, 5.0, 4.2, 2.3, 2.3, 2.3, navy, 0.07)                # head
	v.box(-1, 4, 6, 1, 5, 9, Color("#f2a838"), 0.03)                    # beak
	v.box(-1, 3, 6, 1, 4, 8, Color("#d98a20"), 0.03)
	v.box(-2, 6, 5, -1, 7, 6, Color("#fff3b0"), 0.0)                    # eyes
	v.box(1, 6, 5, 2, 7, 6, Color("#fff3b0"), 0.0)
	v.box(-2, 6, 6, -1, 7, 7, Color("#0e0a10"), 0.0)
	v.box(1, 6, 6, 2, 7, 7, Color("#0e0a10"), 0.0)
	for k in 3:
		v.box(-2 + k * 2, 2, -9 - (0 if k == 1 else -1), -1 + k * 2, 3, -5, sheen if k == 1 else navy, 0.06)   # tail fan
	v.box(-2, 0, 0, -1, 1, 1, Color("#d98a20"), 0.03)                   # tucked feet
	v.box(1, 0, 0, 2, 1, 1, Color("#d98a20"), 0.03)
	var wl := Vox.new(0.06)
	for f in 9:
		var ln := 5 + f
		var c := navy.lerp(sheen, float(f) / 8.0)
		wl.box(0, 0, -2 + f, ln, 1, -1 + f, c, 0.06)
	wl.box(0, 0, -3, 6, 1, 0, navy, 0.05)
	var wr := Vox.new(0.06)
	for k in wl.cells:
		wr.cells[Vector3i(-1 - k.x, k.y, k.z)] = wl.cells[k]
	var d := {
		"body": v.build(Vector3(0.5, 0, 0.5)),
		"wingL": wl.build(Vector3(0, 0, 3)),
		"wingR": wr.build(Vector3(0, 0, 3)),
	}
	_c["crow"] = d
	return d


## The Inspector Slime: a Minecraft-slime-style translucent cube around a darker core with a face.
static func slime() -> Dictionary:
	if _c.has("slime"):
		return _c["slime"]
	var shell := Vox.new(0.06)
	shell.box(0, 0, 0, 16, 14, 16, Color("#58d078"), 0.06)
	shell.remove_box(1, 1, 1, 15, 13, 15)
	var core := Vox.new(0.06)
	core.box(0, 0, 0, 8, 7, 8, Color("#2e9a4e"), 0.07)
	core.box(1, 7, 1, 7, 8, 7, Color("#38aa58"), 0.05)
	for ex in [1, 5]:
		core.box(ex, 3, 8, ex + 2, 6, 9, Color("#10180e"), 0.0)       # eyes
		core.box(ex, 5, 8, ex + 1, 6, 9, Color("#e8ffe8"), 0.0)       # glint
	core.box(2, 1, 8, 6, 2, 9, Color("#0c140a"), 0.0)                 # flat unimpressed mouth
	core.box(1, 6, 8, 3, 7, 9, Color("#1d5a2a"), 0.0)                 # stern brow
	core.box(5, 6, 8, 7, 7, 9, Color("#1d5a2a"), 0.0)
	var ring := Vox.new(0.05)                                         # monocle
	for x in 5:
		for y in 5:
			var e := (x == 0 or x == 4 or y == 0 or y == 4) and not ((x == 0 or x == 4) and (y == 0 or y == 4))
			if e:
				ring.set_v(x, y, 0, Color("#e6b840"), 0.03)
	var board := Vox.new(0.05)
	board.box(0, 0, 0, 9, 12, 1, Color("#8a5c36"), 0.07)
	board.box(1, 1, 1, 8, 10, 2, Color("#efe6cc"), 0.03)
	board.box(3, 10, 1, 6, 12, 2, Color("#e6b840"), 0.03)
	for ln in 4:
		board.box(2, 3 + ln * 2, 2, 7, 4 + ln * 2, 3, Color("#4a3a2a"), 0.0)
	board.box(5, 1, 2, 7, 3, 3, Color("#d83a2a", 0.4), 0.0)
	var d := {
		"shell": shell.build(Vector3(8, 0, 8)),
		"core": core.build(Vector3(4, 0, 4)),
		"ring": ring.build(Vector3(2.5, 2.5, 0)),
		"board": board.build(Vector3(4.5, 6, 0.5)),
	}
	_c["slime"] = d
	return d


static func ogre() -> Dictionary:
	if _c.has("ogre"):
		return _c["ogre"]
	var skin := Color("#6a9448")
	var vest := Color("#7a3f2a")
	var V := 0.07
	var t := Vox.new(V)
	t.box(0, 0, 0, 22, 18, 12, skin, 0.06)
	t.ellipsoid(11.0, 6.0, 8.0, 10.0, 7.0, 5.0, skin.lightened(0.04), 0.06)     # belly
	t.box(0, 0, 0, 7, 18, 12, vest, 0.07)
	t.box(15, 0, 0, 22, 18, 12, vest, 0.07)
	t.box(0, 12, 0, 22, 18, 3, vest, 0.07)
	t.box(10, 0, 11, 12, 18, 12, Color("#2a1a10"), 0.0)                         # shirt seam
	for by in [4, 8, 12]:
		t.box(10, by, 12, 12, by + 1, 13, Color("#e6b840"), 0.02)               # buttons
	t.box(2, 14, 11, 8, 17, 13, Color("#e8d8a0"), 0.02)                         # name badge
	t.box(3, 15, 12, 7, 16, 13, Color("#4a3a2a"), 0.0)
	var h := Vox.new(V)
	h.box(0, 0, 0, 14, 12, 12, skin, 0.06)
	h.box(1, 8, 11, 13, 10, 12, skin.darkened(0.2), 0.04)                       # heavy brow
	for ex in [2, 9]:
		h.box(ex, 5, 11, ex + 3, 8, 12, Color("#fff3b0"), 0.02)
		h.box(ex + 1, 6, 11, ex + 2, 7, 12, Color("#14100c"), 0.0)
	h.box(5, 3, 11, 9, 6, 13, skin.lerp(Color("#d88a50"), 0.4), 0.05)           # big nose
	h.box(3, 0, 10, 11, 3, 12, Color("#2a100c"), 0.0)                           # underbite mouth
	for tx in [3, 10]:
		h.box(tx, 0, 11, tx + 1, 4, 12, Color("#f4efd8"), 0.02)                 # tusks
	h.box(-2, 4, 5, 0, 8, 8, skin.lerp(Color("#d88a50"), 0.2), 0.05)            # ears
	h.box(14, 4, 5, 16, 8, 8, skin.lerp(Color("#d88a50"), 0.2), 0.05)
	h.box(1, 12, 1, 13, 14, 11, Color("#2d3a82"), 0.05)                         # little clerk's cap
	h.box(2, 14, 2, 12, 15, 10, Color("#3a4a9a"), 0.05)
	var a := Vox.new(V)
	a.box(0, -16, 0, 6, 0, 6, skin, 0.06)
	a.box(0, -5, 0, 6, 0, 6, vest.darkened(0.1), 0.06)
	a.box(-1, -18, -1, 7, -14, 7, skin.lightened(0.05), 0.06)                   # fist
	var d := {
		"torso": t.build(Vector3(11, 0, 6)),
		"head": h.build(Vector3(7, 0, 6)),
		"arm": a.build(Vector3(3, 0, 3)),
	}
	_c["ogre"] = d
	return d
