class_name MeshKit
extends RefCounted
## Procedural modelling toolkit. Every shape bakes ambient-occlusion tint into
## vertex colour rgb and an edge-wear mask into alpha (1 - wear) for painted.gdshader.

static var _cache := {}


# ------------------------------------------------------------------ rounded box

static func _axis_coords(h: float, r: float, b: int) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for i in b + 1:
		a.append(-h + r * float(i) / b)
	for i in b + 1:
		a.append(h - r + r * float(i) / b)
	return a


## Box with rounded (beveled) edges. r = bevel radius. Cached by arguments.
static func rbox(size: Vector3, r := 0.04, ao_bottom := 0.18, b := 3, tint := Color.WHITE) -> ArrayMesh:
	var rr := minf(r, minf(size.x, minf(size.y, size.z)) * 0.5 - 0.0005)
	rr = maxf(rr, 0.0005)
	var key := "rbox|%s|%s|%s|%s|%s" % [size, rr, ao_bottom, b, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var inner := h - Vector3(rr, rr, rr)
	var coords := [_axis_coords(h.x, rr, b), _axis_coords(h.y, rr, b), _axis_coords(h.z, rr, b)]
	var mb := MB.new()
	var faces := [[0, 1.0, 1, 2], [0, -1.0, 2, 1], [1, 1.0, 2, 0], [1, -1.0, 0, 2], [2, 1.0, 0, 1], [2, -1.0, 1, 0]]
	for f in faces:
		var na: int = f[0]
		var ns: float = f[1]
		var ua: int = f[2]
		var va: int = f[3]
		var cu: PackedFloat32Array = coords[ua]
		var cv: PackedFloat32Array = coords[va]
		var pts := PackedVector3Array()
		var cols := PackedColorArray()
		for iu in cu.size():
			for iv in cv.size():
				var p := Vector3.ZERO
				p[na] = ns * h[na]
				p[ua] = cu[iu]
				p[va] = cv[iv]
				var inn := Vector3(clampf(p.x, -inner.x, inner.x), clampf(p.y, -inner.y, inner.y), clampf(p.z, -inner.z, inner.z))
				var d := p - inn
				var nd := d.normalized() if d.length() > 0.00001 else Vector3.ZERO
				var pos := inn + nd * rr
				var nface := Vector3.ZERO
				nface[na] = ns
				var edge := 1.0 - clampf(nd.dot(nface), 0.0, 1.0)
				var wearm := clampf(edge / 0.29, 0.0, 1.0)
				var ao := lerpf(1.0 - ao_bottom, 1.0, smoothstep(-h.y, -h.y + maxf(size.y * 0.6, 0.001), pos.y))
				pts.append(pos)
				cols.append(Color(ao * tint.r, ao * tint.g, ao * tint.b, 1.0 - wearm))
		mb.grid(pts, cols, cu.size(), cv.size())
	var m := mb.commit(true)
	_cache[key] = m
	return m


# ------------------------------------------------------------------ lathe

## Surface of revolution. profile = (radius, y) points bottom -> top. colors per profile point.
static func lathe(profile: PackedVector2Array, segs := 16, colors := PackedColorArray(), cache_key := "") -> ArrayMesh:
	if cache_key != "" and _cache.has(cache_key):
		return _cache[cache_key]
	var rows := profile.size()
	var cols := segs + 1
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for r in rows:
		var col := colors[r] if r < colors.size() else Color.WHITE
		for c in cols:
			var a := TAU * float(c) / segs
			pts.append(Vector3(profile[r].x * cos(a), profile[r].y, profile[r].x * sin(a)))
			cs.append(col)
	var mb := MB.new()
	mb.grid(pts, cs, rows, cols)
	var m := mb.commit(true)
	if cache_key != "":
		_cache[cache_key] = m
	return m


# ------------------------------------------------------------------ tube

## Swept tube along points with per-point radius (use 0 at an end to close it).
static func tube(points: Array, radii: PackedFloat32Array, sides := 8, colors := PackedColorArray()) -> ArrayMesh:
	var n := points.size()
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	var prev_n := Vector3.ZERO
	for i in n:
		var p: Vector3 = points[i]
		var t: Vector3 = (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var nn: Vector3
		if i == 0:
			nn = t.cross(Vector3.UP)
			if nn.length() < 0.01:
				nn = t.cross(Vector3.RIGHT)
			nn = nn.normalized()
		else:
			nn = (prev_n - t * prev_n.dot(t)).normalized()
		prev_n = nn
		var bb := t.cross(nn)
		var col := colors[i] if i < colors.size() else Color.WHITE
		for j in sides + 1:
			var a := TAU * float(j) / sides
			pts.append(p + (nn * cos(a) + bb * sin(a)) * radii[i])
			cs.append(col)
	var mb := MB.new()
	mb.grid(pts, cs, n, sides + 1)
	return mb.commit(true)


# ------------------------------------------------------------------ sculpt blob

## Deformed UV-sphere. deform(unit: Vector3) -> Vector3 position; colorf(unit, pos) -> Color.
static func blob(deform: Callable, colorf := Callable(), rings := 16, segs := 22) -> ArrayMesh:
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for i in rings + 1:
		var th := PI * float(i) / rings
		for j in segs + 1:
			var ph := TAU * float(j) / segs
			var u := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var pos: Vector3 = deform.call(u)
			pts.append(pos)
			cs.append(colorf.call(u, pos) if colorf.is_valid() else Color.WHITE)
	var mb := MB.new()
	mb.grid(pts, cs, rings + 1, segs + 1)
	return mb.commit(true)


# ------------------------------------------------------------------ cloth

## Rectangular sheet w x h (centered), fold(u, v) -> Vector3 extra offset, colorf(u, v) -> Color.
static func cloth(w: float, h: float, nx: int, ny: int, fold: Callable, colorf := Callable()) -> ArrayMesh:
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for iy in ny + 1:
		for ix in nx + 1:
			var u := float(ix) / nx
			var v := float(iy) / ny
			var p := Vector3((u - 0.5) * w, (0.5 - v) * h, 0.0)
			if fold.is_valid():
				p += fold.call(u, v)
			pts.append(p)
			cs.append(colorf.call(u, v) if colorf.is_valid() else Color.WHITE)
	var mb := MB.new()
	mb.grid(pts, cs, ny + 1, nx + 1)
	return mb.commit(true)


# ------------------------------------------------------------------ foliage

## Palm frond: arched rachis with drooping, tapered leaflets. Grows along +X.
static func frond(length := 2.8, leaflets := 15, leaflet_len := 1.0, width := 0.15, droop := 0.9) -> ArrayMesh:
	var key := "frond|%s|%s|%s|%s|%s" % [length, leaflets, leaflet_len, width, droop]
	if _cache.has(key):
		return _cache[key]
	var mb := MB.new()
	var dark := Color("#174a1c")
	var mid := Color("#2f8426")
	var light := Color("#6fb832")
	var steps := 18
	var spine: Array[Vector3] = []
	for i in steps + 1:
		var t := float(i) / steps
		spine.append(Vector3(t * length, 0.55 * t * length * (1.0 - t * 0.8) - droop * t * t * 0.9 + 0.1, 0.0))
	# rachis (thin tube-like strip)
	for i in steps:
		var a: Vector3 = spine[i]
		var b: Vector3 = spine[i + 1]
		var ta := float(i) / steps
		var wa := 0.035 * (1.0 - ta * 0.8)
		var wb := 0.035 * (1.0 - float(i + 1) / steps * 0.8)
		var c0 := dark.lerp(mid, ta)
		var c1 := dark.lerp(mid, float(i + 1) / steps)
		mb.tri(a + Vector3(0, 0, wa), b + Vector3(0, 0, wb), a - Vector3(0, 0, wa), c0, c1, c0)
		mb.tri(b + Vector3(0, 0, wb), b - Vector3(0, 0, wb), a - Vector3(0, 0, wa), c1, c1, c0)
	for k in leaflets:
		var t := 0.07 + 0.9 * float(k) / (leaflets - 1)
		var idx := int(t * steps)
		var base: Vector3 = spine[idx].lerp(spine[mini(idx + 1, steps)], t * steps - idx)
		var tdir: Vector3 = (spine[mini(idx + 1, steps)] - spine[idx]).normalized()
		var ln := leaflet_len * sin(PI * (0.25 + 0.72 * t)) * (1.0 - 0.15 * t)
		for side in [-1.0, 1.0]:
			var out := Vector3(0, 0, side)
			var dirv: Vector3 = (out * 0.82 + tdir * 0.55 + Vector3(0, -0.5 - 0.5 * t, 0)).normalized()
			var p0 := base
			for sgm in [1, 2, 3]:
				var f := float(sgm) / 3.0
				var sag := -ln * 0.18 * f * f
				var pos: Vector3 = base + dirv * ln * f + Vector3(0, sag, 0)
				var wprev := width * (1.0 - float(sgm - 1) / 3.0) * (1.0 - 0.3 * t)
				var wcur := width * (1.0 - f) * (1.0 - 0.3 * t) * (0.8 if sgm < 3 else 0.0)
				var perp := tdir.cross(dirv).normalized() * 0.5
				var ca := dark.lerp(mid, 0.4 + 0.4 * (1.0 - f)) if sgm == 1 else mid.lerp(light, f * 0.8)
				var cb := mid.lerp(light, f)
				mb.tri(p0 + perp * wprev, p0 - perp * wprev, pos + perp * wcur, ca, ca, cb)
				mb.tri(p0 - perp * wprev, pos - perp * wcur, pos + perp * wcur, ca, cb, cb)
				p0 = pos
	var m := mb.commit(false)
	_cache[key] = m
	return m


## Big glossy tropical leaf (banana / monstera style) like the ones in the reference. Grows along +X.
static func broad_leaf(length := 1.5, width := 0.75, droop := 0.5, cup := 0.18, dark := Color("#123f18"), mid := Color("#237a2a"), light := Color("#5fb53a"), vein := Color("#9ad55a")) -> ArrayMesh:
	var key := "bleaf|%s|%s|%s|%s|%s|%s" % [length, width, droop, cup, mid.to_html(), light.to_html()]
	if _cache.has(key):
		return _cache[key]
	var nu := 8
	var nv := 10
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for iv in nv + 1:
		var v := float(iv) / nv
		var w := width * sin(PI * pow(v, 0.75)) * 0.5 + 0.001
		var cx := v * length * cos(droop * v * 0.8)
		var cy := length * 0.35 * v - droop * v * v * length * 0.9
		for iu in nu + 1:
			var u := float(iu) / nu * 2.0 - 1.0
			var z := u * w
			var y := cy + absf(u) * w * 0.34 - u * u * w * cup * 2.0
			pts.append(Vector3(cx, y, z))
			var shade := dark.lerp(mid, 0.35 + 0.65 * (1.0 - absf(u))).lerp(light, v * 0.55)
			if absf(u) < 0.07:
				shade = shade.lerp(vein, 0.7)
			cs.append(shade)
	var mb := MB.new()
	mb.grid(pts, cs, nv + 1, nu + 1)
	var m := mb.commit(true)
	_cache[key] = m
	return m


## Low-poly displaced boulder with strata bands and moss on top.
static func rock(radius := 1.0, seed_v := 1, squash := 0.75) -> ArrayMesh:
	var key := "rock|%s|%s|%s" % [radius, seed_v, squash]
	if _cache.has(key):
		return _cache[key]
	var nz := FastNoiseLite.new()
	nz.seed = seed_v
	nz.frequency = 1.3
	nz.fractal_octaves = 3
	var deform := func(u: Vector3) -> Vector3:
		var d := 1.0 + nz.get_noise_3dv(u * 1.7) * 0.42
		var p := u * radius * d
		p.y *= squash
		if p.y < -radius * 0.28:
			p.y = -radius * 0.28 + (p.y + radius * 0.28) * 0.15
		return p
	var colorf := func(u: Vector3, p: Vector3) -> Color:
		var band := 0.5 + 0.5 * sin(p.y * 7.0 / maxf(radius, 0.2) + nz.get_noise_3dv(u * 3.0) * 3.0)
		var c := Color("#7a766e").lerp(Color("#aaa595"), band)
		if u.y > 0.55:
			c = c.lerp(Color("#5f8a3a"), clampf((u.y - 0.55) * 2.0, 0.0, 0.7))
		var ao := lerpf(0.55, 1.0, smoothstep(-0.3 * radius, 0.4 * radius, p.y))
		return Color(c.r * ao, c.g * ao, c.b * ao, 1.0)
	var m := blob(deform, colorf, 12, 16)
	_cache[key] = m
	return m


## Merge several meshes (each with a Transform3D) into one surface list.
static func combine(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		st.append_from(p[0] as Mesh, 0, p[1] as Transform3D)
	return st.commit()


## Grass tuft: several curved, tapered blades. Root dark, tip bright.
static func grass_tuft(blades := 9, height := 0.55, seed_v := 1) -> ArrayMesh:
	var key := "grass|%s|%s|%s" % [blades, height, seed_v]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MB.new()
	for i in blades:
		var yaw := rng.randf() * TAU
		var lean := rng.randf_range(0.15, 0.75)
		var h := height * rng.randf_range(0.65, 1.2)
		var w := 0.035 * rng.randf_range(0.8, 1.3)
		var off := Vector3(rng.randf_range(-0.07, 0.07), 0.0, rng.randf_range(-0.07, 0.07))
		var dirv := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-dirv.z, 0.0, dirv.x)
		var prev_c := off
		var base_col := Color("#2c6b22").lerp(Color("#3f8a2c"), rng.randf())
		var tip_col := Color("#8fd04a").lerp(Color("#c8e060"), rng.randf() * 0.6)
		var segs := 3
		for sg in segs:
			var t0 := float(sg) / segs
			var t1 := float(sg + 1) / segs
			var p0 := off + dirv * (lean * h * t0 * t0) + Vector3(0, h * t0, 0)
			var p1 := off + dirv * (lean * h * t1 * t1) + Vector3(0, h * t1, 0)
			var w0 := w * (1.0 - t0)
			var w1 := w * (1.0 - t1)
			var c0 := base_col.lerp(tip_col, t0)
			var c1 := base_col.lerp(tip_col, t1)
			mb.tri(p0 + side * w0, p0 - side * w0, p1 + side * w1, c0, c0, c1)
			if sg < segs - 1:
				mb.tri(p0 - side * w0, p1 - side * w1, p1 + side * w1, c0, c1, c1)
	var m := mb.commit(false)
	_cache[key] = m
	return m


## Rosette of broad leaves (jungle floor plant, like the big glossy leaves in the reference).
static func leaf_plant(leaves := 6, scale := 1.0, seed_v := 1, mid := Color("#2f8c33"), light := Color("#7ccf45")) -> ArrayMesh:
	var key := "lplant|%s|%s|%s|%s" % [leaves, scale, seed_v, mid.to_html()]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	for i in leaves:
		var lf := broad_leaf(rng.randf_range(1.1, 1.7) * scale, rng.randf_range(0.55, 0.85) * scale, rng.randf_range(0.35, 0.8), 0.2, Color("#17501f"), mid, light)
		var t := Transform3D(Basis(Vector3.UP, TAU * float(i) / leaves + rng.randf_range(-0.3, 0.3)) * Basis(Vector3(0, 0, 1), rng.randf_range(0.05, 0.5)), Vector3(0, 0.02, 0))
		parts.append([lf, t])
	var m := combine(parts)
	_cache[key] = m
	return m


## Spiky red tropical plant (the red leaves in the reference shots).
static func red_plant(scale := 1.0, seed_v := 1) -> ArrayMesh:
	var key := "redplant|%s|%s" % [scale, seed_v]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var parts := []
	for i in 7:
		var lf := broad_leaf(rng.randf_range(0.9, 1.3) * scale, rng.randf_range(0.2, 0.32) * scale, rng.randf_range(0.3, 0.7), 0.12, Color("#6a1218"), Color("#d23a2a"), Color("#ff9a3a"), Color("#ffd070"))
		var t := Transform3D(Basis(Vector3.UP, TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)) * Basis(Vector3(0, 0, 1), rng.randf_range(0.35, 0.95)), Vector3(0, 0.02, 0))
		parts.append([lf, t])
	var m := combine(parts)
	_cache[key] = m
	return m


## Thin torus ring in the XY plane (axis +Z): major radius R, tube radius r.
static func torus_ring(R: float, r: float, segs := 18, sides := 6) -> ArrayMesh:
	var key := "torus|%s|%s|%s|%s" % [R, r, segs, sides]
	if _cache.has(key):
		return _cache[key]
	var pts := PackedVector3Array()
	var cs := PackedColorArray()
	for i in segs + 1:
		var a := TAU * float(i) / segs
		var c := Vector3(cos(a) * R, sin(a) * R, 0.0)
		var radial := Vector3(cos(a), sin(a), 0.0)
		for j in sides + 1:
			var b := TAU * float(j) / sides
			pts.append(c + radial * (cos(b) * r) + Vector3(0, 0, sin(b) * r))
			cs.append(Color.WHITE)
	var mb := MB.new()
	mb.grid(pts, cs, segs + 1, sides + 1)
	var m := mb.commit(true)
	_cache[key] = m
	return m
