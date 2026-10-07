class_name Fx
extends RefCounted
## Combat visuals: telegraphs, rings, sparks, debris. All primitive meshes so nothing is imported.

static var _mats := {}


static func _unshaded(color: Color, alpha := 1.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), alpha, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m


## A red warning disc on the floor that fills in, then calls cb(). Returns the node.
static func telegraph_circle(parent: Node, pos: Vector3, radius: float, secs: float, cb: Callable, color := Color("#ff3a2a")) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.06, 0)
	var base := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	cm.radial_segments = 24
	cm.rings = 1
	base.mesh = cm
	base.material_override = _unshaded(color, 0.22)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(base)
	var fill := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = radius
	fm.bottom_radius = radius
	fm.height = 0.03
	fm.radial_segments = 24
	fm.rings = 1
	fill.mesh = fm
	fill.material_override = _unshaded(color, 0.5)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, secs)
	tw.tween_callback(func():
		if cb.is_valid():
			cb.call()
		root.queue_free())
	return root


## A rectangular strike zone (cleave, charge lane, breath line) starting at `from`, facing dir.
static func telegraph_line(parent: Node, from: Vector3, dir: Vector3, length: float, width: float, secs: float, cb: Callable, color := Color("#ff3a2a")) -> Node3D:
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = from + Vector3(0, 0.06, 0)
	root.rotation.y = atan2(dir.x, dir.z)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.02, length)
	base.mesh = bm
	base.position = Vector3(0, 0, length * 0.5)
	base.material_override = _unshaded(color, 0.22)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(base)
	var fill := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(width, 0.03, length)
	fill.mesh = fm
	fill.material_override = _unshaded(color, 0.5)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fill.position = Vector3(0, 0, 0)
	fill.scale = Vector3(1, 1, 0.02)
	root.add_child(fill)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(fill, "scale:z", 1.0, secs)
	tw.tween_property(fill, "position:z", length * 0.5, secs)
	tw.chain().tween_callback(func():
		if cb.is_valid():
			cb.call()
		root.queue_free())
	return root


## Expanding ring (shockwaves, slams, shrines).
static func ring(parent: Node, pos: Vector3, radius: float, color: Color, secs := 0.45, height := 0.25) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.82
	tm.outer_radius = 1.0
	tm.rings = 20
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = _unshaded(color, 0.9, 2.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + Vector3(0, height, 0)
	mi.scale = Vector3(0.2, 0.3, 0.2)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.5, radius), secs).set_ease(Tween.EASE_OUT)
	var mat := mi.material_override as StandardMaterial3D
	var m2 := mat.duplicate() as StandardMaterial3D
	mi.material_override = m2
	tw.tween_property(m2, "albedo_color:a", 0.0, secs)
	tw.chain().tween_callback(mi.queue_free)


## Quick chunky hit sparks in the damage colour.
static func hit(parent: Node, pos: Vector3, color: Color, big := false) -> void:
	Style.burst(parent, pos, color, 12 if big else 7, 6.5 if big else 4.5, 0.11 if big else 0.08, 0.45)
	Style.burst(parent, pos, Color("#fff4c8"), 4, 3.0, 0.06, 0.25)


## Debris cubes that fall and fade (mob death).
static func debris(parent: Node, pos: Vector3, colors: Array, amount := 14, scale := 1.0) -> void:
	for i in amount:
		var c: Color = colors[i % colors.size()]
		var ch := Chunk.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.09, 0.2) * scale
		bm.size = Vector3(s, s, s)
		ch.mesh = bm
		ch.material_override = VMat.solid(0.25, 4.0, {"tint": c})
		ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(ch)
		ch.global_position = pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.6), randf_range(-0.3, 0.3)) * scale
		ch.vel = Vector3(randf_range(-1, 1), randf_range(0.6, 1.8), randf_range(-1, 1)) * (3.0 * scale)
		ch.floor_y = pos.y - 0.2


class Chunk extends MeshInstance3D:
	var vel := Vector3.ZERO
	var floor_y := 0.0
	var life := 1.6

	func _process(delta: float) -> void:
		life -= delta
		if life <= 0.0:
			queue_free()
			return
		if life < 0.4:
			scale = Vector3.ONE * (life / 0.4)
		if vel != Vector3.ZERO:
			vel.y -= 14.0 * delta
			global_position += vel * delta
			rotation += Vector3(vel.z, vel.x, vel.y) * delta * 2.0
			if global_position.y < floor_y:
				global_position.y = floor_y
				vel = Vector3.ZERO


## A crescent swoosh for melee swings. kind: slash (flat sweep), overhead / slam (vertical arc), stab (streak).
static func slash(parent: Node, origin: Vector3, fwd: Vector3, radius: float, arc_deg: float, kind: String, color: Color, mirror := false) -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var right := fwd.cross(Vector3.UP).normalized()
	var segs := 14
	var r0 := radius * 0.5
	var half := deg_to_rad(arc_deg) * 0.5
	for i in segs + 1:
		var t := float(i) / segs
		var a := lerpf(-half, half, t) * (-1.0 if mirror else 1.0)
		var fade := sin(t * PI)
		var dir_o: Vector3
		var dir_i: Vector3
		var lift := Vector3.ZERO
		match kind:
			"overhead", "slam":
				# vertical arc: from above-forward sweeping down to the floor in front
				var el := lerpf(deg_to_rad(80.0), deg_to_rad(-15.0), t)
				dir_o = (fwd * cos(el) + Vector3.UP * sin(el)).normalized()
				dir_i = dir_o
				lift = Vector3(0, 0.3, 0)
			"stab":
				dir_o = fwd
				dir_i = fwd
			_:
				dir_o = (fwd * cos(a) + right * sin(a)).normalized()
				dir_i = dir_o
		var p_out: Vector3
		var p_in: Vector3
		if kind == "stab":
			p_out = origin + fwd * lerpf(0.4, radius, t) + Vector3(0, 0.0, 0) + right * 0.04
			p_in = origin + fwd * lerpf(0.4, radius, t) - right * 0.04
		else:
			p_out = origin + dir_o * radius + lift
			p_in = origin + dir_i * r0 + lift
			if kind == "slash":
				p_out.y += sin(t * PI) * 0.15
		verts.append(p_in)
		verts.append(p_out)
		cols.append(Color(color.r, color.g, color.b, 0.0))
		cols.append(Color(color.r, color.g, color.b, 0.75 * fade))
		if i < segs:
			var b := i * 2
			idx.append_array([b, b + 1, b + 3, b, b + 3, b + 2])
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.4, 1.4, 1.4, 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(mi.queue_free)
