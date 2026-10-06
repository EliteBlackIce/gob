class_name VoxTerrain
extends RefCounted
## The island as a field of half-metre blocks. A static height table (built once per process)
## answers every gameplay query; chunked meshes carry the visuals; a HeightMap shape carries
## the collision (steep faces become walls, one-block steps become gentle ramps).

const HX := 72.0
const HZ := 96.0
const CELL := 0.5
const STEP := 0.5
const NX := 288
const NZ := 384
const SEA_FLOOR := -2.5            # blocks below this are hidden by the sea and never meshed
const CHUNK := 32

const ROUTE: Array[Vector2] = [
	Vector2(0, 84), Vector2(0, 62), Vector2(-2, 42), Vector2(-4, 28), Vector2(-4, 6),
	Vector2(-12, -12), Vector2(-10, -30), Vector2(-2, -50), Vector2(10, -66), Vector2(16, -76),
]
const GORGE_X := -4.0
const HUT_POS := Vector2(-10, -30)
const LIGHT_POS := Vector2(18, -78)

static var _noise: FastNoiseLite
static var _heights: PackedFloat32Array
static var _types: PackedByteArray      # 0 grass 1 sand 2 stone 3 path 4 underwater sand
static var _ready := false
static var _chunk_cache := {}


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func dist_to_route(x: float, z: float) -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for i in ROUTE.size() - 1:
		var a := ROUTE[i]
		var b := ROUTE[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


static func _get_noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 21
		_noise.frequency = 0.02
		_noise.fractal_octaves = 3
	return _noise


static func raw_height(x: float, z: float) -> float:
	var n := _get_noise().get_noise_2d(x, z)
	var r := sqrt(pow(x / 62.0, 2.0) + pow(z / 88.0, 2.0))
	if r > 1.12:
		return -5.0
	var mask := 1.0 - _smooth(0.7, 1.03, r)
	var base := 2.6 + n * 6.5
	var h := lerpf(-5.0, base, mask)
	var f := 1.0 - _smooth(3.5, 12.0, dist_to_route(x, z))
	h = lerpf(h, 1.5 + n * 0.5, f * 0.92)
	var plaza := 1.0 - _smooth(14.0, 24.0, Vector2(x, z).distance_to(Vector2(0, 80)))
	h = lerpf(h, 2.0, plaza)
	for c in [HUT_POS, LIGHT_POS]:
		var fd := 1.0 - _smooth(7.0, 14.0, Vector2(x, z).distance_to(c))
		h = lerpf(h, 2.0, fd)
	var gz := _smooth(2.0, 9.0, z) * (1.0 - _smooth(30.0, 37.0, z))
	var wall := _smooth(4.6, 7.8, absf(x - GORGE_X)) * gz
	h += wall * (9.5 + n * 3.0)
	return h


## Build the quantised height table once (about 2-3 s). Safe to call repeatedly.
static func ensure() -> void:
	if _ready:
		return
	_heights = PackedFloat32Array()
	_heights.resize(NX * NZ)
	for j in NZ:
		var z := -HZ + (j + 0.5) * CELL
		for i in NX:
			var x := -HX + (i + 0.5) * CELL
			_heights[j * NX + i] = roundf(raw_height(x, z) / STEP) * STEP
	_classify()
	_ready = true


static func _classify() -> void:
	_types = PackedByteArray()
	_types.resize(NX * NZ)
	var nz := _get_noise()
	for j in NZ:
		for i in NX:
			var h := _heights[j * NX + i]
			if h < -0.05:
				_types[j * NX + i] = 4
				continue
			var x := -HX + (i + 0.5) * CELL
			var z := -HZ + (j + 0.5) * CELL
			var relief := 0.0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = clampi(i + d.x, 0, NX - 1)
				var nj: int = clampi(j + d.y, 0, NZ - 1)
				relief = maxf(relief, absf(_heights[nj * NX + ni] - h))
			var t := 0
			if h < 0.9:
				t = 1
			elif relief >= 1.5 or h > 9.5:
				t = 2
			else:
				var onpath := 1.0 - _smooth(2.2, 5.2, dist_to_route(x, z))
				t = 3 if (onpath > 0.5 + nz.get_noise_2d(x * 4.0, z * 4.0) * 0.25) else 0
			_types[j * NX + i] = t


## Quantised block-top height at a world position (O(1)).
static func height_at(x: float, z: float) -> float:
	ensure()
	var i := int(floor((x + HX) / CELL))
	var j := int(floor((z + HZ) / CELL))
	if i < 0 or j < 0 or i >= NX or j >= NZ:
		return -5.0
	return _heights[j * NX + i]


static func cell_h(i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= NX or j >= NZ:
		return -5.0
	return _heights[j * NX + i]


# ------------------------------------------------------------------ colours

static func _jit(c: Color, x: int, y: int, z: int, amt := 0.07) -> Color:
	var f := 1.0 + (Vox.hash3(x, y, z) - 0.5) * 2.0 * amt
	return Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), 1.0)


static func top_color(t: int, h: float, i: int, j: int) -> Color:
	var n := Vox.hash3(i, j, 3)
	match t:
		0:
			var g := Color("#58b038").lerp(Color("#7cd048"), n * 0.7 + 0.1 * sin(i * 0.13 + j * 0.11))
			return _jit(g, i, j, 1, 0.05)
		1:
			return _jit(Color("#e6d396").lerp(Color("#d8c27e"), n), i, j, 2, 0.04)
		2:
			var band := 0.5 + 0.5 * sin(h * 1.7)
			return _jit(Color("#8a8a86").lerp(Color("#a2a29a"), band * 0.6 + n * 0.4), i, j, 4, 0.06)
		3:
			return _jit(Color("#a88c62").lerp(Color("#b8a074"), n), i, j, 5, 0.06)
		_:
			return _jit(Color("#d4c58c").lerp(Color("#6aa8a8"), clampf(-h / 2.6, 0.0, 1.0)), i, j, 6, 0.04)


static func side_color(t: int, depth_layers: int, h: float, i: int, j: int, layer: int) -> Color:
	var n := Vox.hash3(i + layer * 7, layer, j)
	match t:
		0:
			if depth_layers == 0:
				return _jit(Color("#58a838"), i, layer, j, 0.06)      # grass fringe
			return _jit(Color("#8a5c36").lerp(Color("#6e4426"), clampf(depth_layers * 0.12, 0.0, 0.6)), i, layer, j, 0.08)
		1:
			return _jit(Color("#dccb8e").lerp(Color("#bda86a"), clampf(depth_layers * 0.1, 0.0, 0.6)), i, layer, j, 0.05)
		2:
			var band := 0.5 + 0.5 * sin((h - layer * STEP) * 3.0 + n)
			var c := Color("#7a7a76").lerp(Color("#9c9c94"), band)
			if depth_layers == 0 and n > 0.45:
				c = c.lerp(Color("#5f9a3c"), 0.65)                      # moss on the lip
			return _jit(c, i, layer, j, 0.07)
		3:
			if depth_layers == 0:
				return _jit(Color("#b09468"), i, layer, j, 0.06)
			return _jit(Color("#8a5c36"), i, layer, j, 0.08)
		_:
			return _jit(Color("#c8b87c").lerp(Color("#4f8f98"), clampf(depth_layers * 0.18, 0.0, 1.0)), i, layer, j, 0.05)


# ------------------------------------------------------------------ meshing

static func _ao_top(i: int, j: int, h: float, sx: int, sz: int) -> float:
	var a := 1 if cell_h(i + sx, j) > h + 0.01 else 0
	var b := 1 if cell_h(i, j + sz) > h + 0.01 else 0
	var c := 1 if cell_h(i + sx, j + sz) > h + 0.01 else 0
	var lvl := 0 if (a == 1 and b == 1) else 3 - (a + b + c)
	return Vox.AO_CURVE[lvl]


static func _quad(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, p00: Vector3, p10: Vector3, p11: Vector3, p01: Vector3, n: Vector3, c00: Color, c10: Color, c11: Color, c01: Color) -> void:
	# clockwise from outside: p00 p11 p10 / p00 p01 p11   (a = p10-p00 direction, b = p01-p00)
	if c00.r + c00.g + c00.b + c11.r + c11.g + c11.b >= c10.r + c10.g + c10.b + c01.r + c01.g + c01.b:
		verts.append(p00); verts.append(p11); verts.append(p10)
		cols.append(c00); cols.append(c11); cols.append(c10)
		verts.append(p00); verts.append(p01); verts.append(p11)
		cols.append(c00); cols.append(c01); cols.append(c11)
	else:
		verts.append(p01); verts.append(p10); verts.append(p00)
		cols.append(c01); cols.append(c10); cols.append(c00)
		verts.append(p01); verts.append(p11); verts.append(p10)
		cols.append(c01); cols.append(c11); cols.append(c10)
	for k in 6:
		norms.append(n)


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, 1.0)


static func build_chunk(cx: int, cz: int) -> ArrayMesh:
	ensure()
	var key := Vector2i(cx, cz)
	if _chunk_cache.has(key):
		return _chunk_cache[key]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var i0 := cx * CHUNK
	var j0 := cz * CHUNK
	for j in range(j0, mini(j0 + CHUNK, NZ)):
		for i in range(i0, mini(i0 + CHUNK, NX)):
			var h := _heights[j * NX + i]
			if h < SEA_FLOOR:
				continue
			var t := int(_types[j * NX + i])
			var x0 := -HX + i * CELL
			var z0 := -HZ + j * CELL
			var x1 := x0 + CELL
			var z1 := z0 + CELL
			# top face
			var tc := top_color(t, h, i, j)
			var a00 := _shade(tc, _ao_top(i, j, h, -1, -1))
			var a10 := _shade(tc, _ao_top(i, j, h, 1, -1))
			var a11 := _shade(tc, _ao_top(i, j, h, 1, 1))
			var a01 := _shade(tc, _ao_top(i, j, h, -1, 1))
			# a = +x, b = +z  =>  a x b = -y, so the top uses (a=z, b=x) ordering for +y outward
			_quad(verts, norms, cols, Vector3(x0, h, z0), Vector3(x0, h, z1), Vector3(x1, h, z1), Vector3(x1, h, z0), Vector3.UP, a00, a01, a11, a10)
			# sides toward lower neighbours, one quad per block layer
			for d in 4:
				var ni := i + (1 if d == 0 else (-1 if d == 1 else 0))
				var nj := j + (1 if d == 2 else (-1 if d == 3 else 0))
				var nh := cell_h(ni, nj)
				if nh >= h - 0.01:
					continue
				var low := maxf(nh, SEA_FLOOR)
				var layers := int(round((h - low) / STEP))
				for L in layers:
					var yt := h - L * STEP
					var yb := yt - STEP
					var sc := side_color(t, L, h, i, j, L)
					var shade_t := 0.9 - 0.04 * minf(L, 6)
					var shade_b := 0.86 - 0.04 * minf(L, 6)
					var ct := _shade(sc, shade_t)
					var cb := _shade(sc, shade_b)
					match d:
						0:   # +x face, a = +y, b = +z
							_quad(verts, norms, cols, Vector3(x1, yb, z0), Vector3(x1, yt, z0), Vector3(x1, yt, z1), Vector3(x1, yb, z1), Vector3.RIGHT, cb, ct, ct, cb)
						1:   # -x face, a = +z, b = +y
							_quad(verts, norms, cols, Vector3(x0, yb, z0), Vector3(x0, yb, z1), Vector3(x0, yt, z1), Vector3(x0, yt, z0), Vector3.LEFT, cb, cb, ct, ct)
						2:   # +z face, a = +x, b = +y
							_quad(verts, norms, cols, Vector3(x0, yb, z1), Vector3(x1, yb, z1), Vector3(x1, yt, z1), Vector3(x0, yt, z1), Vector3.BACK, cb, cb, ct, ct)
						3:   # -z face, a = +y, b = +x
							_quad(verts, norms, cols, Vector3(x0, yb, z0), Vector3(x0, yt, z0), Vector3(x1, yt, z0), Vector3(x1, yb, z0), Vector3.FORWARD, cb, ct, ct, cb)
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_COLOR] = cols
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_chunk_cache[key] = mesh
	return mesh


## Adds visual chunks + collision to parent. Returns the heights texture data for the sea shader.
static func build_into(parent: Node3D) -> void:
	ensure()
	var mat := VMat.solid(CELL, 8.0, {"tex": 0.07})
	for cz in int(ceil(float(NZ) / CHUNK)):
		for cx in int(ceil(float(NX) / CHUNK)):
			var m := build_chunk(cx, cz)
			if m.get_surface_count() == 0:
				continue
			var mi := MeshInstance3D.new()
			mi.mesh = m
			mi.material_override = mat
			parent.add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = NX
	hm.map_depth = NZ
	var data := PackedFloat32Array()
	data.resize(NX * NZ)
	for k in NX * NZ:
		data[k] = maxf(_heights[k], -3.0)
	hm.map_data = data
	cs.shape = hm
	cs.scale = Vector3(CELL, 1.0, CELL)
	body.add_child(cs)
	parent.add_child(body)


static func height_image() -> Image:
	ensure()
	var img := Image.create(NX, NZ, false, Image.FORMAT_RF)
	for j in NZ:
		for i in NX:
			img.set_pixel(i, j, Color(_heights[j * NX + i], 0, 0, 1))
	return img
