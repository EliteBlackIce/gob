class_name Vox
extends RefCounted
## Sparse voxel model + mesher. Build a model out of boxes/ellipsoids/cylinders, then call
## build() to get one ArrayMesh with hidden faces culled and ambient occlusion baked into the
## vertex colours. Colour alpha is an emission mask (1 = none, <1 = glowing).

const FACES := [
	# normal, a, b  (a x b == normal)
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3i(0, 1, 0), Vector3i(1, 0, 0)],
]
const AO_CURVE := [0.52, 0.7, 0.85, 1.0]

var size := 0.04
var cells := {}
var skip := {}                   # Vector3i -> bitmask of face indices (FACES order) never drawn
static var _mesh_cache := {}


func _init(voxel_size := 0.04) -> void:
	size = voxel_size


static func hash3(x: int, y: int, z: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663) ^ (z * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func set_v(x: int, y: int, z: int, c: Color, jit := 0.0) -> void:
	if jit > 0.0:
		var f := 1.0 + (hash3(x, y, z) - 0.5) * 2.0 * jit
		c = Color(clampf(c.r * f, 0.0, 1.0), clampf(c.g * f, 0.0, 1.0), clampf(c.b * f, 0.0, 1.0), c.a)
	cells[Vector3i(x, y, z)] = c


func get_v(x: int, y: int, z: int) -> Variant:
	return cells.get(Vector3i(x, y, z))


func has_v(x: int, y: int, z: int) -> bool:
	return cells.has(Vector3i(x, y, z))


## Half-open box [x0,x1) x [y0,y1) x [z0,z1).
func box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, c: Color, jit := 0.05) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				set_v(x, y, z, c, jit)


func ellipsoid(cx: float, cy: float, cz: float, rx: float, ry: float, rz: float, c: Color, jit := 0.05) -> void:
	for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
		for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
			for z in range(int(floor(cz - rz)), int(ceil(cz + rz)) + 1):
				var dx := (x + 0.5 - cx) / rx
				var dy := (y + 0.5 - cy) / ry
				var dz := (z + 0.5 - cz) / rz
				if dx * dx + dy * dy + dz * dz <= 1.0:
					set_v(x, y, z, c, jit)


func cyl_y(cx: float, cz: float, y0: int, y1: int, rx: float, rz: float, c: Color, jit := 0.05) -> void:
	for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
		for z in range(int(floor(cz - rz)), int(ceil(cz + rz)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dz := (z + 0.5 - cz) / rz
			if dx * dx + dz * dz <= 1.0:
				for y in range(y0, y1):
					set_v(x, y, z, c, jit)


func remove_box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				cells.erase(Vector3i(x, y, z))


## Copy of everything with x -> (width-1-x) over the given x range (for symmetric models).
func mirror_x(center2: int) -> void:
	# center2 = 2 * mirror plane in voxel coordinates between cells; x' = center2 - 1 - x
	for k in cells.keys():
		var c: Color = cells[k]
		var nk := Vector3i(center2 - 1 - k.x, k.y, k.z)
		if not cells.has(nk):
			cells[nk] = c


func merge(other: Vox, off := Vector3i.ZERO) -> void:
	for k in other.cells:
		cells[k + off] = other.cells[k]


## Planked wood: rows alternate in shade, with staggered joints. horizontal = planks run along X.
func planks(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, base: Color, horizontal := true, row_h := 2, plank_len := 14) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				var along := x if horizontal else z
				var row := (y - y0) / row_h if horizontal else (y - y0) / row_h
				var rowf := 0.9 + hash3(row, 3, 7) * 0.2
				var jointpos := (along + row * 5) % plank_len
				var f := rowf
				if jointpos == 0:
					f *= 0.72
				elif (y - y0) % row_h == 0:
					f *= 0.88
				var c := Color(base.r * f, base.g * f, base.b * f, base.a)
				set_v(x, y, z, c, 0.05)


## Cobblestone / brick pattern with mortar lines.
func cobble(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, base: Color, block := 3) -> void:
	for x in range(x0, x1):
		for y in range(y0, y1):
			for z in range(z0, z1):
				var bx := (x + ((y / block) % 2) * (block / 2)) / block
				var bz := (z + ((y / block) % 2) * (block / 2)) / block
				var by := y / block
				var f := 0.82 + hash3(bx, by, bz) * 0.3
				var mortar := (y % block == 0) or ((x + ((y / block) % 2) * (block / 2)) % block == 0 and (z + ((y / block) % 2) * (block / 2)) % block == 0)
				if (y % block == 0):
					f *= 0.78
				var c := Color(base.r * f, base.g * f, base.b * f, base.a)
				set_v(x, y, z, c, 0.04)


func line(a: Vector3i, b: Vector3i, c: Color, jit := 0.04) -> void:
	var d := b - a
	var n := maxi(maxi(absi(d.x), absi(d.y)), absi(d.z))
	for i in n + 1:
		var t := float(i) / maxf(n, 1)
		set_v(a.x + roundi(d.x * t), a.y + roundi(d.y * t), a.z + roundi(d.z * t), c, jit)


func shell(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, c: Color, thick := 1, jit := 0.05) -> void:
	box(x0, y0, z0, x1, y1, z1, c, jit)
	remove_box(x0 + thick, y0 + thick, z0 + thick, x1 - thick, y1 - thick, z1 - thick)


func count() -> int:
	return cells.size()


func _occ(p: Vector3i) -> int:
	return 1 if cells.has(p) else 0


## Build the mesh. origin is the model pivot in voxel coordinates.
func build(origin := Vector3.ZERO, ao_on := true) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	for key: Vector3i in cells:
		var c: Color = cells[key]
		var sk: int = skip.get(key, 0)
		for fi in 6:
			var f: Array = FACES[fi]
			var n: Vector3i = f[0]
			if (sk >> fi) & 1 == 1 or cells.has(key + n):
				continue
			var a: Vector3i = f[1]
			var b: Vector3i = f[2]
			var plane := Vector3(key)
			if n.x + n.y + n.z > 0:
				plane += Vector3(n)
			var ao := [1.0, 1.0, 1.0, 1.0]
			if ao_on:
				var front := key + n
				for i in 2:
					for j in 2:
						var sa := a * (1 if i == 1 else -1)
						var sb := b * (1 if j == 1 else -1)
						var s1 := _occ(front + sa)
						var s2 := _occ(front + sb)
						var cr := _occ(front + sa + sb)
						var lvl := 0 if (s1 == 1 and s2 == 1) else 3 - (s1 + s2 + cr)
						ao[i * 2 + j] = AO_CURVE[lvl]
			var p00 := plane
			var p10 := plane + Vector3(a)
			var p11 := plane + Vector3(a) + Vector3(b)
			var p01 := plane + Vector3(b)
			var c00 := Color(c.r * ao[0], c.g * ao[0], c.b * ao[0], c.a)
			var c01 := Color(c.r * ao[1], c.g * ao[1], c.b * ao[1], c.a)
			var c10 := Color(c.r * ao[2], c.g * ao[2], c.b * ao[2], c.a)
			var c11 := Color(c.r * ao[3], c.g * ao[3], c.b * ao[3], c.a)
			var nf := Vector3(n)
			# clockwise (Godot front) = p00, p11, p10 / p00, p01, p11 ; flip the diagonal for smooth AO
			if ao[0] + ao[3] >= ao[1] + ao[2]:
				_tri(verts, norms, cols, p00, p11, p10, c00, c11, c10, nf, origin)
				_tri(verts, norms, cols, p00, p01, p11, c00, c01, c11, nf, origin)
			else:
				_tri(verts, norms, cols, p01, p10, p00, c01, c10, c00, nf, origin)
				_tri(verts, norms, cols, p01, p11, p10, c01, c11, c10, nf, origin)
	return _commit(verts, norms, cols)


func _tri(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3, origin: Vector3) -> void:
	verts.append((a - origin) * size)
	verts.append((b - origin) * size)
	verts.append((c - origin) * size)
	norms.append(n)
	norms.append(n)
	norms.append(n)
	cols.append(ca)
	cols.append(cb)
	cols.append(cc)


func _commit(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if verts.is_empty():
		return mesh
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## AABB of the model in metres relative to origin.
func extents(origin := Vector3.ZERO) -> AABB:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for k: Vector3i in cells:
		lo = lo.min(Vector3(k))
		hi = hi.max(Vector3(k) + Vector3.ONE)
	return AABB((lo - origin) * size, (hi - lo) * size)
