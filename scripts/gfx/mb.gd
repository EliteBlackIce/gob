class_name MB
extends RefCounted
## Tiny mesh builder around SurfaceTool. Winding is not critical: the painted
## shader is double-sided and flips normals for back faces.

var st := SurfaceTool.new()
var _count := 0


func _init() -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)


func vert(p: Vector3, c := Color.WHITE, uv := Vector2.ZERO) -> void:
	st.set_color(c)
	st.set_uv(uv)
	st.add_vertex(p)
	_count += 1


func tri(a: Vector3, b: Vector3, c: Vector3, ca := Color.WHITE, cb := Color.WHITE, cc := Color.WHITE) -> void:
	vert(a, ca)
	vert(b, cb)
	vert(c, cc)


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col := Color.WHITE) -> void:
	tri(a, b, c, col, col, col)
	tri(a, c, d, col, col, col)


## Grid of vertices rows x cols (points/colors flat arrays) -> triangles.
func grid(points: PackedVector3Array, colors: PackedColorArray, rows: int, cols: int, uv_scale := Vector2.ZERO) -> void:
	for r in rows - 1:
		for c in cols - 1:
			var i0 := r * cols + c
			var i1 := i0 + 1
			var i2 := i0 + cols
			var i3 := i2 + 1
			var u0 := Vector2(float(c) / (cols - 1), float(r) / (rows - 1)) * uv_scale
			var u1 := Vector2(float(c + 1) / (cols - 1), float(r) / (rows - 1)) * uv_scale
			var u2 := Vector2(float(c) / (cols - 1), float(r + 1) / (rows - 1)) * uv_scale
			var u3 := Vector2(float(c + 1) / (cols - 1), float(r + 1) / (rows - 1)) * uv_scale
			st.set_color(colors[i0]); st.set_uv(u0); st.add_vertex(points[i0])
			st.set_color(colors[i2]); st.set_uv(u2); st.add_vertex(points[i2])
			st.set_color(colors[i1]); st.set_uv(u1); st.add_vertex(points[i1])
			st.set_color(colors[i1]); st.set_uv(u1); st.add_vertex(points[i1])
			st.set_color(colors[i2]); st.set_uv(u2); st.add_vertex(points[i2])
			st.set_color(colors[i3]); st.set_uv(u3); st.add_vertex(points[i3])
			_count += 6


func commit(smooth := true) -> ArrayMesh:
	if smooth:
		st.index()
	st.generate_normals()
	return st.commit()


func is_empty() -> bool:
	return _count == 0
