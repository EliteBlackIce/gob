class_name DungeonBuilder
extends RefCounted
## Turns a DungeonGen layout into blocky Minecraft-Dungeons-style geometry: stone-brick walls,
## flagstone floors, ceilings, torches, banners and per-theme decor. Meshes are chunked 16x16
## tiles; collision is merged into a handful of boxes.

const VXS := 0.5              # voxel edge (m); one tile = 2x2 voxels
const WALL_H := 11            # voxels (5.5 m)
const CH := 16                # chunk size in tiles

const THEME_COLORS := {
	"crypt": {"wall": Color("#767c8a"), "floor": Color("#686c78"), "accent": Color("#8a5aa0"), "fog": Color("#120e1a"), "ambient": Color("#5c5a80"),
		"torch": Color("#ffb060"), "glow": Color("#8affb0"), "sky": Color("#08060e")},
	"sewer": {"wall": Color("#5a7a66"), "floor": Color("#4a6256"), "accent": Color("#a0902e"), "fog": Color("#0a1610"), "ambient": Color("#6a8a78"),
		"torch": Color("#ffe9a0"), "glow": Color("#c8ff6a"), "sky": Color("#050a07")},
	"caves": {"wall": Color("#5e4c6a"), "floor": Color("#4a3e54"), "accent": Color("#c070ff"), "fog": Color("#100818"), "ambient": Color("#6a4a90"),
		"torch": Color("#d090ff"), "glow": Color("#d28aff"), "sky": Color("#07040c")},
	"furnace": {"wall": Color("#6a423a"), "floor": Color("#5a3e38"), "accent": Color("#ff7a30"), "fog": Color("#1c0a05"), "ambient": Color("#b0603c"),
		"torch": Color("#ff7a30"), "glow": Color("#ffb040"), "sky": Color("#0c0402")},
	"ice": {"wall": Color("#7aa4c4"), "floor": Color("#9cc4dc"), "accent": Color("#d8f4ff"), "fog": Color("#0a1826"), "ambient": Color("#6aa0cc"),
		"torch": Color("#a0e0ff"), "glow": Color("#c8f4ff"), "sky": Color("#040a12")},
}


static func theme_colors(theme: String) -> Dictionary:
	return THEME_COLORS.get(theme, THEME_COLORS["crypt"])


static func _h(x: int, y: int, z: int) -> float:
	return Vox.hash3(x, y, z)


static func _shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)


# ---------------------------------------------------------------- voxel colouring

static func _floor_color(theme: String, vx: int, vz: int, base: Color, kind: int) -> Color:
	if kind == DungeonGen.T_LAVA:
		var f := 0.8 + _h(vx, 3, vz) * 0.5
		return Color(1.0 * f, 0.38 * f, 0.08 * f, 0.25)
	if kind == DungeonGen.T_POISON:
		var f2 := 0.8 + _h(vx, 3, vz) * 0.4
		return Color(0.42 * f2, 0.85 * f2, 0.22 * f2, 0.4)
	var row := vz / 3
	var off := (row % 2) * 2
	var sx := (vx + off) / 3
	var f3 := 0.95 + 0.1 * _h(sx, 1, row)
	if (vx + off) % 3 == 0 or vz % 3 == 0:
		f3 *= 0.9
	var r := _h(vx, 5, vz)
	if r < 0.006:
		f3 *= 0.8
	var c := _shade(base, f3)
	if theme == "ice" and r > 0.985:
		c.a = 0.55
		c = c.lightened(0.3)
	if theme == "caves" and r > 0.992:
		c = Color(0.82, 0.5, 1.0, 0.4)
	return c


static func _wall_color(theme: String, vx: int, vy: int, vz: int, base: Color, acc: Color) -> Color:
	var bx := (vx + (vy & 1)) / 2
	var bz := (vz + (vy & 1)) / 2
	var f := 0.94 + 0.12 * _h(bx, vy, bz)
	if (vx + vz + (vy & 1)) % 2 == 0:
		f *= 0.97
	if vy <= 1:
		f *= 0.86                                   # darker base course
	if vy >= WALL_H - 2:
		f *= 0.86
	var c := _shade(base, f)
	if vy == WALL_H - 2 or vy == 2:
		c = _shade(acc.lerp(base, 0.75), f * 0.95)  # trim bands
	var r := _h(vx, vy + 17, vz)
	match theme:
		"crypt":
			if r > 0.997:
				c = _shade(Color("#c8c4d0"), 0.9)    # stray bone-white brick
			if vy < 4 and _h(vx / 2, 9, vz / 2) > 0.8 and r > 0.4:
				c = _shade(Color("#4e6a3a"), f)      # moss
		"sewer":
			if vy < 5 and _h(vx / 2, 9, vz / 2) > 0.45 and r > 0.3:
				c = _shade(Color("#5a8a3a"), f)
			if vy > 8 and r > 0.8:
				c = _shade(Color("#3a5a40"), f)
		"caves":
			if r > 0.997:
				c = Color(0.82, 0.5, 1.0, 0.35)      # glowing ore
		"furnace":
			if r > 0.99:
				c = Color(1.0, 0.45, 0.1, 0.3)       # glowing cracks
		"ice":
			if r > 0.995:
				c = Color(0.85, 0.97, 1.0, 0.5)
	return c


static func _ceil_color(theme: String, vx: int, vz: int, base: Color) -> Color:
	var f := 0.6 + 0.06 * _h(vx / 2, 77, vz / 2)
	if vx % 8 == 0 or vz % 8 == 0:
		f *= 0.7                                    # beams
	return _shade(base, f)


# ---------------------------------------------------------------- main build

static func build(level: Node3D, g: DungeonGen) -> Dictionary:
	var theme := g.theme
	var pal := theme_colors(theme)
	var wall_c: Color = pal["wall"]
	var floor_c: Color = pal["floor"]
	var acc_c: Color = pal["accent"]
	var chunks := {}
	var shell := {}
	var floors: Array[Vector2i] = []
	# classify
	for y in range(1, g.height - 1):
		for x in range(1, g.width - 1):
			if g.is_floor(x, y):
				floors.append(Vector2i(x, y))
	for f in floors:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(f.x + dx, f.y + dy)
				if not g.is_floor(n.x, n.y) and not shell.has(n):
					shell[n] = true

	for f in floors:
		var ch := _chunk(chunks, f)
		var kind := g.tile(f.x, f.y)
		for lx in 2:
			for lz in 2:
				var vx := f.x * 2 + lx
				var vz := f.y * 2 + lz
				var key := Vector3i(vx, -1, vz)
				ch.cells[key] = _floor_color(theme, vx, vz, floor_c, kind)
				ch.skip[key] = 1 << 3
				var ck := Vector3i(vx, WALL_H, vz)
				var cc := _ceil_color(theme, vx, vz, wall_c)
				if theme == "caves" and _h(vx, 91, vz) > 0.8:
					ch.cells[Vector3i(vx, WALL_H - 1, vz)] = cc
					ch.skip[Vector3i(vx, WALL_H - 1, vz)] = 1 << 2
				ch.cells[ck] = cc
				ch.skip[ck] = 1 << 2
	for s in shell:
		var sp: Vector2i = s
		var ch2 := _chunk(chunks, sp)
		for lx in 2:
			for lz in 2:
				var vx := sp.x * 2 + lx
				var vz := sp.y * 2 + lz
				var mask := (1 << 2) | (1 << 3)
				# face indices: 0 +X, 1 -X, 4 +Z, 5 -Z
				if lx == 1 and _solid_void(g, shell, sp + Vector2i(1, 0)):
					mask |= 1 << 0
				if lx == 0 and _solid_void(g, shell, sp + Vector2i(-1, 0)):
					mask |= 1 << 1
				if lz == 1 and _solid_void(g, shell, sp + Vector2i(0, 1)):
					mask |= 1 << 4
				if lz == 0 and _solid_void(g, shell, sp + Vector2i(0, -1)):
					mask |= 1 << 5
				for vy in range(-1, WALL_H):
					var key2 := Vector3i(vx, vy, vz)
					ch2.cells[key2] = _wall_color(theme, vx, vy, vz, wall_c, acc_c)
					ch2.skip[key2] = mask
				var ck2 := Vector3i(vx, WALL_H, vz)
				ch2.cells[ck2] = _ceil_color(theme, vx, vz, wall_c)
				ch2.skip[ck2] = mask | (1 << 2)
	var mat := VMat.solid(VXS, 1.0)
	var meshes: Array[MeshInstance3D] = []
	for k in chunks:
		var ck3: Vector2i = k
		var vox: Vox = chunks[k]
		var org := Vector3(ck3.x * CH * 2, 0, ck3.y * CH * 2)
		var mi := MeshInstance3D.new()
		mi.mesh = vox.build(org)
		mi.material_override = mat
		mi.position = Vector3(ck3.x * CH, 0, ck3.y * CH)
		level.add_child(mi)
		meshes.append(mi)
	_collision(level, g, shell)
	var out := {"meshes": meshes, "shell": shell, "lights": [], "wall_spots": {}}
	_decor(level, g, shell, out)
	return out


static func _solid_void(g: DungeonGen, shell: Dictionary, t: Vector2i) -> bool:
	return not g.is_floor(t.x, t.y) and not shell.has(t)


static func _chunk(chunks: Dictionary, t: Vector2i) -> Vox:
	var key := Vector2i(t.x / CH, t.y / CH)
	if not chunks.has(key):
		chunks[key] = Vox.new(VXS)
	return chunks[key]


static func _collision(level: Node3D, g: DungeonGen, shell: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = "LevelCollision"
	body.collision_layer = 1
	level.add_child(body)
	var fl := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(g.width, 1.0, g.height)
	fl.shape = fs
	fl.position = Vector3(g.width * 0.5, -0.5, g.height * 0.5)
	body.add_child(fl)
	var ce := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(g.width, 1.0, g.height)
	ce.shape = cs
	ce.position = Vector3(g.width * 0.5, WALL_H * VXS + 0.5, g.height * 0.5)
	body.add_child(ce)
	# walls: merge runs of shell tiles along x on each row
	for y in range(0, g.height):
		var x := 0
		while x < g.width:
			if shell.has(Vector2i(x, y)):
				var x0 := x
				while x < g.width and shell.has(Vector2i(x, y)):
					x += 1
				var w := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(x - x0, WALL_H * VXS + 1.0, 1.0)
				w.shape = bs
				w.position = Vector3(x0 + (x - x0) * 0.5, (WALL_H * VXS) * 0.5, y + 0.5)
				body.add_child(w)
			else:
				x += 1


# ---------------------------------------------------------------- decor + lights

static func _torch_spots(g: DungeonGen, tiles: Array, rng: RandomNumberGenerator, count: int, spacing: float, exclude: Array) -> Array:
	var cands: Array = []
	for t in tiles:
		var tt: Vector2i = t
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = tt + d
			if not g.is_floor(n.x, n.y):
				cands.append([tt, d])
	for i in range(cands.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = cands[i]
		cands[i] = cands[j]
		cands[j] = tmp
	var out: Array = []
	for c in cands:
		if out.size() >= count:
			break
		var tt2: Vector2i = c[0]
		var ok := true
		for o in out:
			if (Vector2(tt2) - Vector2(o[0])).length() < spacing:
				ok = false
				break
		for ex in exclude:
			if (Vector2(tt2) - Vector2(ex)).length() < 3.5:
				ok = false
				break
		if ok:
			out.append(c)
	return out


static func _decor(level: Node3D, g: DungeonGen, shell: Dictionary, out: Dictionary) -> void:
	var theme := g.theme
	var pal := theme_colors(theme)
	var rng := RandomNumberGenerator.new()
	rng.seed = g.seed_value ^ 0x5eed
	var torch_col: Color = pal["torch"]
	var lights: Array = out["lights"]
	var deco := Node3D.new()
	deco.name = "Decor"
	level.add_child(deco)
	var torch_mesh := VoxProps.torch(true)
	var torch_mat := VMat.solid(0.04, 4.0)
	var banner_cols := {"crypt": Color("#5a2a7a"), "sewer": Color("#7a7a2a"), "caves": Color("#7a2aa0"), "furnace": Color("#b02a1a"), "ice": Color("#2a5aa0")}
	for r in g.rooms:
		var door_tiles: Array = []
		for d in r.doors:
			door_tiles.append(d["tile"])
		var tiles: Array = r.tiles.keys()
		var ntorch := clampi(r.area() / 55, 2, 6)
		var spots := _torch_spots(g, tiles, rng, ntorch, 6.0, door_tiles)
		for sp in spots:
			var t: Vector2i = sp[0]
			var d: Vector2i = sp[1]
			var wall_pos := Vector3(t.x + 0.5 + d.x * 0.44, 1.7, t.y + 0.5 + d.y * 0.44)
			var mi := MeshInstance3D.new()
			mi.mesh = torch_mesh
			mi.material_override = torch_mat
			mi.position = wall_pos
			deco.add_child(mi)
			var l := FlickerLight.new()
			l.light_color = torch_col
			l.light_energy = 2.4
			l.omni_range = 13.0
			l.position = Vector3(t.x + 0.5 - d.x * 0.3, 2.9, t.y + 0.5 - d.y * 0.3)
			l.shadow_enabled = false
			deco.add_child(l)
			lights.append({"light": l, "room": r.id, "pos": l.position})
			if rng.randf() < 0.6 and theme != "sewer" and theme != "caves":
				var bn := MeshInstance3D.new()
				bn.mesh = VoxProps.banner(banner_cols[theme])
				bn.material_override = VMat.solid(0.05, 4.0)
				var fdir := Vector2(-d.x, -d.y)
				var sidestep := Vector2(-fdir.y, fdir.x) * 2.2
				var bt := Vector2(t.x + 0.5, t.y + 0.5) + sidestep
				if g.is_floor(int(bt.x), int(bt.y)):
					bn.position = Vector3(bt.x + d.x * 0.45, 3.9, bt.y + d.y * 0.45)
					bn.rotation.y = atan2(fdir.x, fdir.y)
					deco.add_child(bn)
		# scattered floor decor
		_scatter(deco, g, r, rng, theme, pal, lights, level)
	# corridor torches
	var ctiles: Array = g.corridor_tiles.keys()
	var cspots := _torch_spots(g, ctiles, rng, maxi(ctiles.size() / 12, 4), 8.0, [])
	for sp2 in cspots:
		var t2: Vector2i = sp2[0]
		var d2: Vector2i = sp2[1]
		var mi2 := MeshInstance3D.new()
		mi2.mesh = torch_mesh
		mi2.material_override = torch_mat
		mi2.position = Vector3(t2.x + 0.5 + d2.x * 0.44, 1.7, t2.y + 0.5 + d2.y * 0.44)
		deco.add_child(mi2)
		var l2 := FlickerLight.new()
		l2.light_color = torch_col
		l2.light_energy = 1.8
		l2.omni_range = 11.0
		l2.position = Vector3(t2.x + 0.5 - d2.x * 0.3, 2.9, t2.y + 0.5 - d2.y * 0.3)
		deco.add_child(l2)
		lights.append({"light": l2, "room": -1, "pos": l2.position})


static func _place(deco: Node3D, mesh: Mesh, vox: float, pos: Vector3, yaw := 0.0, ppv := 4.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = VMat.solid(vox, ppv)
	mi.position = pos
	mi.rotation.y = yaw
	deco.add_child(mi)
	return mi


static func _scatter(deco: Node3D, g: DungeonGen, r: DungeonGen.DRoom, rng: RandomNumberGenerator, theme: String, pal: Dictionary, lights: Array, level: Node3D) -> void:
	var tiles: Array = r.tiles.keys()
	var c := r.center()

	var rnd_tile := func(margin: int) -> Variant:
		for tries in 24:
			var t: Vector2i = tiles[rng.randi_range(0, tiles.size() - 1)]
			if Vector2(t).distance_to(Vector2(c)) < 3.5:
				continue
			var ok := true
			for dd in range(-margin, margin + 1):
				if not g.is_floor(t.x + dd, t.y) or not g.is_floor(t.x, t.y + dd):
					ok = false
					break
			if ok and g.tile(t.x, t.y) == DungeonGen.T_FLOOR:
				return t
		return null

	# pillars
	if r.shape == "pillars":
		var pm := DProps.pillar(theme)
		for p in r.pillars:
			if Vector2(p).distance_to(Vector2(c)) < 2.5:
				continue
			_place(deco, pm, 0.25, Vector3(p.x + 0.5, 0, p.y + 0.5), 0.0, 4.0)
			var sb := Style.solid_box(level, Vector3(1.0, 6.0, 1.0), Vector3(p.x + 0.5, 3.0, p.y + 0.5))
			sb.collision_layer = 1
	var n_small := clampi(r.area() / 40, 2, 7)
	match theme:
		"crypt":
			for i in n_small:
				var t: Variant = rnd_tile.call(1)
				if t == null:
					continue
				var v: Vector2i = t
				_place(deco, DProps.bones(i), 0.05, Vector3(v.x + rng.randf(), 0, v.y + rng.randf()), rng.randf() * TAU)
			if rng.randf() < 0.7 and r.kind in ["combat", "treasure"]:
				var tc: Variant = rnd_tile.call(2)
				if tc != null:
					var vc: Vector2i = tc
					_place(deco, DProps.coffin(), 0.05, Vector3(vc.x + 0.5, 0, vc.y + 0.5), float(rng.randi_range(0, 3)) * PI * 0.5)
					Style.solid_box(level, Vector3(0.9, 0.9, 1.9), Vector3(vc.x + 0.5, 0.45, vc.y + 0.5)).collision_layer = 1
		"sewer":
			for i in n_small:
				var t2: Variant = rnd_tile.call(1)
				if t2 == null:
					continue
				var v2: Vector2i = t2
				_place(deco, DProps.bones(i + 3), 0.05, Vector3(v2.x + rng.randf(), 0, v2.y + rng.randf()), rng.randf() * TAU)
				if rng.randf() < 0.5:
					_place(deco, DProps.shrooms(Color("#9aff6a"), i), 0.05, Vector3(v2.x + 0.5, 0, v2.y + 0.5), 0.0)
		"caves":
			for i in n_small + 2:
				var t3: Variant = rnd_tile.call(1)
				if t3 == null:
					continue
				var v3: Vector2i = t3
				var col: Color = pal["accent"]
				_place(deco, DProps.shrooms(col, i % 4), 0.05, Vector3(v3.x + 0.5, 0, v3.y + 0.5), rng.randf() * TAU)
				if i % 3 == 0:
					var l := OmniLight3D.new()
					l.light_color = col
					l.light_energy = 0.6
					l.omni_range = 4.5
					l.position = Vector3(v3.x + 0.5, 0.8, v3.y + 0.5)
					deco.add_child(l)
					lights.append({"light": l, "room": r.id, "pos": l.position})
			for i in 5:
				var t4: Variant = rnd_tile.call(0)
				if t4 != null:
					var v4: Vector2i = t4
					_place(deco, DProps.stalactite(Color("#6a5878"), i), 0.1, Vector3(v4.x + 0.5, WALL_H * VXS, v4.y + 0.5))
		"furnace":
			for i in n_small:
				var t5: Variant = rnd_tile.call(1)
				if t5 == null:
					continue
				var v5: Vector2i = t5
				if i % 3 == 0:
					_place(deco, DProps.brazier(true), 0.05, Vector3(v5.x + 0.5, 0, v5.y + 0.5))
					var bl := FlickerLight.new()
					bl.light_color = Color("#ff8a30")
					bl.light_energy = 1.6
					bl.omni_range = 9.0
					bl.position = Vector3(v5.x + 0.5, 1.6, v5.y + 0.5)
					deco.add_child(bl)
					lights.append({"light": bl, "room": r.id, "pos": bl.position})
					Style.solid_box(level, Vector3(0.6, 1.0, 0.6), Vector3(v5.x + 0.5, 0.5, v5.y + 0.5)).collision_layer = 1
				else:
					_place(deco, DProps.stalagmite(Color("#3c2a28"), i), 0.1, Vector3(v5.x + 0.5, 0, v5.y + 0.5))
		"ice":
			for i in n_small:
				var t6: Variant = rnd_tile.call(1)
				if t6 == null:
					continue
				var v6: Vector2i = t6
				_place(deco, DProps.crystals(Color("#9ae0ff"), i % 4), 0.05, Vector3(v6.x + 0.5, 0, v6.y + 0.5), rng.randf() * TAU)
				if i % 3 == 0:
					var il := OmniLight3D.new()
					il.light_color = Color("#9ae0ff")
					il.light_energy = 0.6
					il.omni_range = 4.5
					il.position = Vector3(v6.x + 0.5, 0.9, v6.y + 0.5)
					deco.add_child(il)
					lights.append({"light": il, "room": r.id, "pos": il.position})
			for i in 4:
				var t7: Variant = rnd_tile.call(0)
				if t7 != null:
					var v7: Vector2i = t7
					_place(deco, DProps.stalactite(Color("#a8d8f0"), i), 0.1, Vector3(v7.x + 0.5, WALL_H * VXS, v7.y + 0.5))
	# hanging chains everywhere
	for i in 2:
		var tch: Variant = rnd_tile.call(0)
		if tch != null:
			var vch: Vector2i = tch
			var len_v := rng.randi_range(8, 20)
			_place(deco, DProps.chain(len_v), 0.05, Vector3(vch.x + 0.5, WALL_H * VXS, vch.y + 0.5))
