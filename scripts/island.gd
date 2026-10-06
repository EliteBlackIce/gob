class_name Island
extends Node3D
## One delivery run: a hand-shaped island, a gorge with a toll ogre, crows,
## inspector slimes, and a customer who has been waiting since lunch.

signal finished(result: Dictionary)

const HX := 72.0
const HZ := 96.0
const STEP := 1.5
const ROUTE: Array[Vector2] = [
	Vector2(0, 84), Vector2(0, 62), Vector2(-2, 42), Vector2(-4, 28), Vector2(-4, 6),
	Vector2(-12, -12), Vector2(-10, -30), Vector2(-2, -50), Vector2(10, -66), Vector2(16, -76),
]
const GORGE_X := -4.0
const OGRE_POS := Vector2(-4, 18)
const HUT_POS := Vector2(-10, -30)
const LIGHT_POS := Vector2(18, -78)
const TAVERN_POS := Vector2(0, 86)
const SPAWN := Vector2(0, 72)

var ui: UI
var job: Dictionary = {}
var player: Player
var parcel: Parcel
var noise := FastNoiseLite.new()
var time_left := 180.0
var dest_pos := Vector3.ZERO

var _ended := false
var _rng := RandomNumberGenerator.new()
var _pickups: Array[Node3D] = []
var _ogre: Ogre = null
var _hint_clock := 0.0
var _hint_started := false
var _hint_poll := 0.0

const TRAIT_HINTS := {
	"screamer": "SCREAMING CHEESE: it shrieks every few seconds and crows hear it. Hold Q (with Parcel Slap) shushes it - or just outrun the birds.",
	"hot": "HOT POTATO: it heats up the whole way. Wade into the shallow sea to cool it - or it explodes in your satchel!",
	"wiggly": "WIGGLY CRATE: it WILL escape. When it wiggles, get ready - chase it down and touch it to catch it.",
	"glass": "GRANDMA'S VASE: jumping, dashing and falling all crack it. Walk carefully!",
	"heavy": "CEREMONIAL ANVIL: heavy, so you're slower. Plan your route around the crows.",
}


func _ready() -> void:
	_rng.seed = 7714
	noise.seed = 21
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	time_left = float(job["time"])
	_build_environment()
	_build_terrain()
	_build_water()
	_scatter_props()
	_build_tavern_exterior()
	_build_hut()
	_build_lighthouse()
	_build_pickups()
	_spawn_player()
	_spawn_enemies()
	dest_pos = _dest_world()
	ui.configure_hud(true)
	ui.set_dest("%s" % job["dest_name"])
	ui.hud_player = player
	ui.show_hud(true)
	Sfx.ambience(true)
	ui.toast("Deliver: %s  ->  %s" % [job["title"], job["dest_name"]], Color("#f3e3b5"))
	Game.clips.clear()


# ---------- height field ----------

func _dist_to_route(x: float, z: float) -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for i in ROUTE.size() - 1:
		var a := ROUTE[i]
		var b := ROUTE[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func height_at(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var r := sqrt(pow(x / 62.0, 2.0) + pow(z / 88.0, 2.0))
	var mask := 1.0 - Style.smooth(0.7, 1.03, r)
	var base := 2.6 + n * 6.5
	var h := lerpf(-5.0, base, mask)
	var f := 1.0 - Style.smooth(3.5, 12.0, _dist_to_route(x, z))
	h = lerpf(h, 1.5 + n * 0.5, f * 0.92)
	var plaza := 1.0 - Style.smooth(14.0, 24.0, Vector2(x, z).distance_to(Vector2(0, 80)))
	h = lerpf(h, 2.0, plaza)
	for c in [HUT_POS, LIGHT_POS]:
		var fd := 1.0 - Style.smooth(7.0, 14.0, Vector2(x, z).distance_to(c))
		h = lerpf(h, 2.0, fd)
	var gz := Style.smooth(2.0, 9.0, z) * (1.0 - Style.smooth(30.0, 37.0, z))
	var wall := Style.smooth(4.6, 7.8, absf(x - GORGE_X)) * gz
	h += wall * (9.5 + n * 3.0)
	return h


func _build_terrain() -> void:
	var nx := int(2.0 * HX / STEP)
	var nz := int(2.0 * HZ / STEP)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var norms := PackedVector3Array()
	var heights := PackedFloat32Array()
	verts.resize((nx + 1) * (nz + 1))
	cols.resize(verts.size())
	norms.resize(verts.size())
	heights.resize(verts.size())
	for j in nz + 1:
		for i in nx + 1:
			var x := -HX + i * STEP
			var z := -HZ + j * STEP
			var h := height_at(x, z)
			heights[j * (nx + 1) + i] = h
			verts[j * (nx + 1) + i] = Vector3(x, h, z)
			norms[j * (nx + 1) + i] = Vector3.UP
	for j in nz + 1:
		for i in nx + 1:
			var idx := j * (nx + 1) + i
			var h := heights[idx]
			var hx := heights[j * (nx + 1) + mini(i + 1, nx)] - heights[j * (nx + 1) + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, nz) * (nx + 1) + i] - heights[maxi(j - 1, 0) * (nx + 1) + i]
			var slope := Vector2(hx, hz).length() / (2.0 * STEP)
			var x := verts[idx].x
			var z := verts[idx].z
			var jit := noise.get_noise_2d(x * 6.0, z * 6.0) * 0.5 + 0.5
			var c: Color
			var onpath := 1.0 - Style.smooth(2.5, 6.5, _dist_to_route(x, z))
			if h < 0.35:
				c = Color("#b9a46a").lerp(Color("#d9c58a"), clampf(h + 1.0, 0.0, 1.0))
			elif h < 1.15:
				c = Color("#ecd999").lerp(Color("#d8c27e"), jit)
			else:
				c = Color("#3b9a2c").lerp(Color("#7ccb3c"), jit)
				c = c.lerp(Color("#c4ae86"), onpath * 0.8)
			if (slope > 1.0 and h > 1.0) or h > 10.0:
				c = Color("#c2b08a").lerp(Color("#9a8a68"), jit)
			cols[idx] = c.srgb_to_linear()
	var indices := PackedInt32Array()
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c2 := a + (nx + 1)
			var d := c2 + 1
			indices.append_array([a, b, c2, b, d, c2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var tm := Style.make_mat(Color.WHITE, 0.25, 0.0, true)
	tm.set_shader_parameter("jitter", 0.05)
	mi.material_override = tm
	add_child(mi)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 1800)
	pm.subdivide_width = 180
	pm.subdivide_depth = 180
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	sm.set_shader_parameter("island_radii", Vector2(62, 88))
	mi.material_override = sm
	mi.position = Vector3(0, -0.05, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_clouds() -> void:
	var cr := RandomNumberGenerator.new()
	cr.seed = 99
	for i in 22:
		var ang := cr.randf() * TAU
		var dist := cr.randf_range(120.0, 520.0)
		var c := Node3D.new()
		c.position = Vector3(cos(ang) * dist, cr.randf_range(95.0, 150.0), sin(ang) * dist)
		add_child(c)
		for k in cr.randi_range(4, 7):
			var rad := cr.randf_range(9.0, 20.0)
			var sp := Style.sphere(c, rad, Color("#fbfdff"), Vector3(cr.randf_range(-22, 22), cr.randf_range(-3, 5), cr.randf_range(-12, 12)), Vector3(1.0, 0.5, 0.8), 8, 0.55)
			sp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_environment() -> void:
	_build_clouds()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("#1766c9")
	psm.sky_horizon_color = Color("#8fcdf0")
	psm.ground_horizon_color = Color("#8fcdf0")
	psm.ground_bottom_color = Color("#3a6a8a")
	psm.sun_angle_max = 28.0
	psm.sky_curve = 0.25
	psm.sun_angle_max = 22.0
	psm.sun_curve = 0.12
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bcc8d6")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.04
	env.fog_enabled = true
	env.fog_light_color = Color("#a9d9ee")
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.15
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.28
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0cf")
	sun.light_energy = 2.1
	sun.rotation_degrees = Vector3(-58, 38, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


# ---------- props ----------

func _leaf_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 5
	var length := 2.6
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	for k in range(1, segs + 1):
		var t := float(k) / segs
		var w := sin(t * PI * 0.9 + 0.25) * 0.42
		var y := -0.55 * t * t + 0.35 * t
		var p := Vector3(t * length, y, 0)
		var l := p + Vector3(0, 0, w)
		var r := p + Vector3(0, 0, -w)
		var c0 := Color("#2f7a2a").lerp(Color("#79c53e"), float(k - 1) / segs).srgb_to_linear()
		var c1 := Color("#2f7a2a").lerp(Color("#79c53e"), t).srgb_to_linear()
		st.set_color(c0); st.add_vertex(prev_l)
		st.set_color(c0); st.add_vertex(prev_r)
		st.set_color(c1); st.add_vertex(l)
		st.set_color(c0); st.add_vertex(prev_r)
		st.set_color(c1); st.add_vertex(r)
		st.set_color(c1); st.add_vertex(l)
		prev_l = l
		prev_r = r
	return st.commit()


func _multimesh(mesh: Mesh, xforms: Array, mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


func _scatter_props() -> void:
	var leaf := _leaf_mesh()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.13
	trunk.bottom_radius = 0.27
	trunk.height = 5.0
	trunk.radial_segments = 6
	trunk.rings = 2
	var rock := SphereMesh.new()
	rock.radial_segments = 6
	rock.rings = 3
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.12
	tuft.height = 0.7
	tuft.radial_segments = 3
	tuft.rings = 1
	var bush := SphereMesh.new()
	bush.radial_segments = 7
	bush.rings = 4

	var trunks: Array = []
	var fronds: Array = []
	var frondsb: Array = []
	var rocks_a: Array = []
	var rocks_b: Array = []
	var tufts: Array = []
	var bushes: Array = []
	var reds: Array = []
	var crow_homes: Array[Vector3] = []

	for i in 900:
		var x := _rng.randf_range(-HX + 4, HX - 4)
		var z := _rng.randf_range(-HZ + 4, HZ - 4)
		var h := height_at(x, z)
		if h < 1.1 or h > 7.5:
			continue
		var dr := _dist_to_route(x, z)
		var p := Vector3(x, h, z)
		if Vector2(x, z).distance_to(Vector2(TAVERN_POS.x, TAVERN_POS.y - 6)) < 16.0:
			continue
		if Vector2(x, z).distance_to(HUT_POS) < 8.0 or Vector2(x, z).distance_to(LIGHT_POS) < 9.0:
			continue
		var kind := _rng.randf()
		if kind < 0.3 and dr > 4.5:
			var tilt := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.12, 0.12))
			var yaw := _rng.randf() * TAU
			var sc := _rng.randf_range(0.85, 1.35)
			var tb := Basis.from_euler(tilt) * Basis(Vector3.UP, yaw)
			trunks.append(Transform3D(tb.scaled(Vector3.ONE * sc), p + Vector3(0, 2.5 * sc, 0)))
			var top := p + (tb * Vector3(0, 5.0 * sc, 0))
			for k in 7:
				var a := TAU * k / 7.0 + _rng.randf() * 0.3
				var lb := Basis(Vector3.UP, a) * Basis.from_euler(Vector3(0, 0, _rng.randf_range(-0.15, 0.25)))
				var xf := Transform3D(lb.scaled(Vector3.ONE * sc * _rng.randf_range(0.9, 1.15)), top)
				if k % 2 == 0:
					fronds.append(xf)
				else:
					frondsb.append(xf)
			if crow_homes.size() < 12 and dr < 22.0 and dr > 6.0:
				crow_homes.append(top + Vector3(0, 0.3, 0))
		elif kind < 0.42 and dr > 5.0:
			var sc := _rng.randf_range(0.5, 2.2)
			var tb := Basis.from_euler(Vector3(0, _rng.randf() * TAU, 0)).scaled(Vector3(sc * _rng.randf_range(0.8, 1.4), sc * 0.75, sc * _rng.randf_range(0.8, 1.3)))
			var xf := Transform3D(tb, p + Vector3(0, sc * 0.3, 0))
			if _rng.randf() < 0.5:
				rocks_a.append(xf)
			else:
				rocks_b.append(xf)
		elif kind < 0.62 and dr > 3.0:
			var sc := _rng.randf_range(0.7, 1.6)
			bushes.append(Transform3D(Basis().scaled(Vector3(sc, sc * 0.7, sc)), p + Vector3(0, sc * 0.25, 0)))
		elif kind < 0.72 and dr > 3.0:
			for k in 5:
				var lb := Basis(Vector3.UP, TAU * k / 5.0 + _rng.randf()) * Basis.from_euler(Vector3(0, 0, _rng.randf_range(0.0, 0.5)))
				reds.append(Transform3D(lb.scaled(Vector3.ONE * _rng.randf_range(0.35, 0.55)), p + Vector3(0, 0.1, 0)))
		else:
			for k in 3:
				var off := Vector3(_rng.randf_range(-0.4, 0.4), 0, _rng.randf_range(-0.4, 0.4))
				var tb := Basis(Vector3.UP, _rng.randf() * TAU) * Basis.from_euler(Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
				tufts.append(Transform3D(tb, p + off + Vector3(0, 0.3, 0)))
	for k in 260:
		var x := _rng.randf_range(-HX + 4, HX - 4)
		var z := _rng.randf_range(-HZ + 4, HZ - 4)
		var h := height_at(x, z)
		if h > 1.1 and h < 5.0:
			var tb := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(1, _rng.randf_range(0.6, 1.4), 1))
			tufts.append(Transform3D(tb, Vector3(x, h + 0.3, z)))

	_multimesh(trunk, trunks, Style.mat(Color("#8a6a45"), 0.4))
	_multimesh(leaf, fronds, Style.mat(Color("#ffffff"), 0.45))
	_multimesh(leaf, frondsb, Style.mat(Color("#d8f0a8"), 0.45))
	_multimesh(leaf, reds, Style.mat(Color("#e0463a"), 0.5))
	rock.radius = 1.0
	rock.height = 2.0
	_multimesh(rock, rocks_a, Style.mat(Color("#b3a688"), 0.2))
	_multimesh(rock, rocks_b, Style.mat(Color("#948768"), 0.2))
	bush.radius = 1.0
	bush.height = 2.0
	_multimesh(bush, bushes, Style.mat(Color("#2f7f30"), 0.15))
	_multimesh(tuft, tufts, Style.mat(Color("#6fb544"), 0.2))

	# crow perches: prefer palm tops near the route, with fallbacks
	var homes: Array[Vector3] = []
	var wanted := [Vector2(2, 52), Vector2(-14, -2), Vector2(-6, -24), Vector2(8, -58)]
	for wv in wanted:
		var best: Vector3 = Vector3(wv.x, height_at(wv.x, wv.y) + 4.5, wv.y)
		var bd := 1e9
		for ch in crow_homes:
			var d := Vector2(ch.x, ch.z).distance_to(wv)
			if d < bd and d < 14.0:
				bd = d
				best = ch
		if bd >= 1e8:
			var gx := best.x
			var gz := best.z
			var gh := height_at(gx, gz)
			_perch_post(Vector3(gx, gh, gz))
			best = Vector3(gx, gh + 4.2, gz)
		homes.append(best)
	_crow_homes = homes


var _crow_homes: Array[Vector3] = []


func _perch_post(p: Vector3) -> void:
	Style.cyl(self, 0.18, 0.26, 4.4, Color("#7a5a38"), p + Vector3(0, 2.2, 0), Vector3(3, 0, -2), 6)
	Style.box(self, Vector3(1.5, 0.12, 0.2), Color("#6a4a2d"), p + Vector3(0, 4.0, 0), Vector3(0, 30, 0))


func _build_pickups() -> void:
	for pv in [Vector2(2, 56), Vector2(-3, 36), Vector2(-9, -4), Vector2(-6, -40), Vector2(6, -60)]:
		var g := Vector3(pv.x, height_at(pv.x, pv.y), pv.y)
		var crate := Node3D.new()
		crate.position = g
		add_child(crate)
		Style.cyl(crate, 0.35, 0.4, 0.7, Color("#8a5a30"), Vector3(0, 0.35, 0), Vector3.ZERO, 8)
		Style.torus(crate, 0.02, 0.38, Color("#4a3322"), Vector3(0, 0.3, 0), Vector3.ZERO)
		for k in 3:
			Style.cyl(crate, 0.05, 0.06, 0.35, Color("#4cc27a"), Vector3(-0.15 + k * 0.15, 0.85, 0), Vector3(0, 0, (k - 1) * 12), 6, 0.2)
		Style.light(crate, Color("#9dffc0"), 0.6, 4.0, Vector3(0, 1.0, 0))
		_pickups.append(crate)


func _build_tavern_exterior() -> void:
	var g := Vector3(TAVERN_POS.x, 2.0, TAVERN_POS.y)
	var t := Node3D.new()
	t.position = g
	add_child(t)
	var wood := Color("#6a4529")
	var dark := Color("#4a2f1a")
	Style.box(t, Vector3(13, 5, 9), wood, Vector3(0, 2.5, 0))
	for i in 7:
		Style.box(t, Vector3(0.25, 5.2, 0.25), dark, Vector3(-6 + i * 2.0, 2.6, -4.6))
	Style.box(t, Vector3(14, 0.4, 10), dark, Vector3(0, 5.1, 0))
	Style.box(t, Vector3(10, 3.5, 7), wood.lightened(0.05), Vector3(0, 7.0, 0.5))
	var roof := Style.cyl(t, 0.0, 1.0, 1.0, Color("#8a3a22"), Vector3(0, 9.6, 0.5), Vector3(0, 0, 90), 3)
	roof.scale = Vector3(2.4, 11.5, 8.0)
	roof.rotation_degrees = Vector3(0, 0, 90)
	Style.cyl(t, 0.12, 0.12, 8.0, dark, Vector3(-3.0, 11.5, 0.5), Vector3.ZERO, 6)
	var sail := Style.cyl(t, 1.0, 1.0, 0.1, Color("#efe6cf"), Vector3(-3.0, 11.0, 0.5), Vector3(90, 0, 0), 3)
	sail.scale = Vector3(2.3, 1.0, 2.7)
	var sail2 := Style.cyl(t, 1.0, 1.0, 0.1, Color("#e5d9bb"), Vector3(3.2, 10.3, 0.5), Vector3(90, 0, 0), 3)
	sail2.scale = Vector3(2.0, 1.0, 2.2)
	Style.cyl(t, 0.1, 0.1, 6.0, dark, Vector3(3.2, 10.5, 0.5), Vector3.ZERO, 6)
	Style.box(t, Vector3(2.0, 3.2, 0.3), dark, Vector3(0, 1.6, 4.55))
	Style.box(t, Vector3(1.7, 2.9, 0.12), Color("#7a5232"), Vector3(0, 1.5, 4.7))
	Style.box(t, Vector3(0.12, 0.5, 0.12), Color("#e0b84a"), Vector3(0.6, 1.5, 4.8), Vector3.ZERO, 0.3)
	for wx in [-4.2, 4.2]:
		Style.box(t, Vector3(1.4, 1.4, 0.2), Color("#ffcf6a"), Vector3(wx, 2.8, 4.55), Vector3.ZERO, 0.9)
		Style.box(t, Vector3(1.6, 0.15, 0.3), dark, Vector3(wx, 2.1, 4.6))
		Style.light(t, Color("#ffb347"), 1.4, 9.0, Vector3(wx, 2.8, 6.0))
	Style.box(t, Vector3(3.4, 0.9, 0.2), Color("#5a3a20"), Vector3(0, 4.3, 4.7))
	Style.label3d(t, "GOBLIN DELIVERY CO.", Vector3(0, 4.3, 4.85), 0.014, Color("#f3d98a"))
	Style.light(t, Color("#ffb347"), 1.6, 12.0, Vector3(0, 3.0, 6.5))
	Interactable.make(self, Vector3(g.x, g.y + 1.0, g.z + 6.0), "Go back inside (abandon delivery)", Callable(self, "_abandon"), 3.0)


func _dest_world() -> Vector3:
	var p: Vector2 = HUT_POS if job["dest"] == "marl" else LIGHT_POS
	return Vector3(p.x, height_at(p.x, p.y), p.y)


func _build_hut() -> void:
	var g := Vector3(HUT_POS.x, height_at(HUT_POS.x, HUT_POS.y), HUT_POS.y)
	var h := Node3D.new()
	h.position = g
	h.rotation_degrees.y = 25
	add_child(h)
	Style.box(h, Vector3(5, 3, 4), Color("#8a6a45"), Vector3(0, 1.5, 0))
	var roof := Style.cone(h, 3.8, 2.2, Color("#c0503a"), Vector3(0, 4.0, 0), Vector3(0, 45, 0), 4)
	roof.scale = Vector3(1.2, 1.0, 1.0)
	Style.box(h, Vector3(1.0, 2.0, 0.2), Color("#4a2f1a"), Vector3(0, 1.0, 2.05))
	Style.box(h, Vector3(0.9, 0.9, 0.2), Color("#ffcf6a"), Vector3(1.6, 1.8, 2.05), Vector3.ZERO, 0.8)
	Style.cyl(h, 0.45, 0.5, 0.8, Color("#6a7a8a"), Vector3(-1.9, 0.4, 2.8), Vector3.ZERO, 8)
	Style.light(h, Color("#ffb347"), 1.2, 7.0, Vector3(0, 2.5, 3.0))
	# mailbox
	var mb := Node3D.new()
	mb.position = Vector3(2.6, 0, 3.2)
	h.add_child(mb)
	Style.cyl(mb, 0.07, 0.09, 1.2, Color("#5a3a20"), Vector3(0, 0.6, 0), Vector3.ZERO, 5)
	Style.box(mb, Vector3(0.6, 0.4, 0.4), Color("#c0392b"), Vector3(0, 1.3, 0))
	Style.cyl(mb, 0.2, 0.2, 0.6, Color("#c0392b"), Vector3(0, 1.5, 0), Vector3(0, 0, 90), 8)
	var mbi := Interactable.make(self, g + Vector3(0, 1.0, 0) + (h.basis * Vector3(2.6, 0, 3.2)), "Deliver the parcel", Callable(self, "_try_deliver"), 3.2)
	mbi.enabled = job["dest"] == "marl"
	# keeper
	var keeper := GoblinModel.build(Color("#a05a2a"), Color("#9bbd55"), false)
	keeper.position = Vector3(-0.2, 0, 3.4)
	keeper.rotation_degrees.y = 160
	h.add_child(keeper)
	_keepers["marl"] = keeper


var _keepers: Dictionary = {}


func _build_lighthouse() -> void:
	var g := Vector3(LIGHT_POS.x, height_at(LIGHT_POS.x, LIGHT_POS.y), LIGHT_POS.y)
	var l := Node3D.new()
	l.position = g
	add_child(l)
	for i in 5:
		var col := Color("#f4efe0") if i % 2 == 0 else Color("#c0392b")
		Style.cyl(l, 2.0 - i * 0.18, 2.2 - i * 0.18, 2.4, col, Vector3(0, 1.2 + i * 2.4, 0), Vector3.ZERO, 9)
	Style.cyl(l, 2.1, 1.7, 0.4, Color("#3a3f4a"), Vector3(0, 12.2, 0), Vector3.ZERO, 9)
	Style.cyl(l, 1.0, 1.0, 1.6, Color("#fff3b0"), Vector3(0, 13.2, 0), Vector3.ZERO, 8, 1.2)
	Style.cone(l, 1.5, 1.2, Color("#c0392b"), Vector3(0, 14.6, 0), Vector3.ZERO, 8)
	Style.light(l, Color("#ffe9a0"), 2.5, 22.0, Vector3(0, 13.2, 0))
	Style.box(l, Vector3(1.0, 2.0, 0.2), Color("#4a2f1a"), Vector3(0, 1.0, 2.0))
	var mb := Node3D.new()
	mb.position = Vector3(3.2, 0, 2.8)
	l.add_child(mb)
	Style.cyl(mb, 0.07, 0.09, 1.2, Color("#5a3a20"), Vector3(0, 0.6, 0), Vector3.ZERO, 5)
	Style.box(mb, Vector3(0.6, 0.4, 0.4), Color("#c0392b"), Vector3(0, 1.3, 0))
	var mbi := Interactable.make(self, g + Vector3(3.2, 1.0, 2.8), "Deliver the parcel", Callable(self, "_try_deliver"), 3.2)
	mbi.enabled = job["dest"] == "light"
	var keeper := GoblinModel.build(Color("#2a6a7a"), Color("#7ab04a"), true, Color("#1a4a5a"))
	keeper.position = Vector3(1.8, 0, 3.4)
	keeper.rotation_degrees.y = 190
	l.add_child(keeper)
	_keepers["light"] = keeper


# ---------- actors ----------

func _spawn_player() -> void:
	player = Player.new()
	player.island = self
	player.ui = ui
	player.position = Vector3(SPAWN.x, height_at(SPAWN.x, SPAWN.y) + 0.4, SPAWN.y)
	add_child(player)
	player.setup_for_run(true)
	player.model.rotation.y = PI
	player.died.connect(_on_player_died)
	parcel = Parcel.create(job)
	parcel.ui = ui
	parcel.island = self
	add_child(parcel)
	parcel.destroyed.connect(_on_parcel_destroyed)
	player.grab(parcel)


func _spawn_enemies() -> void:
	for i in _crow_homes.size():
		var c := Crow.new()
		c.island = self
		c.player = player
		c.ui = ui
		c.home = _crow_homes[i]
		c.nest = _nest_for(c.home)
		add_child(c)
	for sp in [Vector2(-6, 50), Vector2(-9, -2), Vector2(0, -46), Vector2(12, -64)]:
		var s := Slime.new()
		s.island = self
		s.player = player
		s.ui = ui
		s.home = Vector3(sp.x, height_at(sp.x, sp.y), sp.y)
		add_child(s)
	var ogre := Ogre.new()
	_ogre = ogre
	ogre.island = self
	ogre.player = player
	ogre.ui = ui
	ogre.position = Vector3(OGRE_POS.x, height_at(OGRE_POS.x, OGRE_POS.y), OGRE_POS.y)
	add_child(ogre)


# ---------- run flow ----------

func _process(delta: float) -> void:
	if _ended or player == null:
		return
	time_left -= delta
	ui.set_timer(time_left)
	_update_hints(delta)
	if time_left < -45.0 and not player.dead:
		_end("failed", "TOO LATE", "The customer gave up and bought from a rival goblin.\nNo pay. No refunds. No hard feelings (many hard feelings).", 0, 0)
		return
	var d := dest_pos - player.global_position
	ui.compass_angle = atan2(d.x, -d.z) + player.yaw
	ui.set_dest("%s  -  %dm" % [job["dest_name"], int(Vector2(d.x, d.z).length())])
	for pk in _pickups.duplicate():
		if is_instance_valid(pk) and pk.global_position.distance_to(player.global_position) < 1.8:
			_pickups.erase(pk)
			pk.queue_free()
			player.bottles += 2
			ui.toast("+2 bottles", Color("#9fe6b0"))
			Sfx.play("pop")
	for k in _keepers:
		var kp: Node3D = _keepers[k]
		(kp.get_node("Body/ArmR") as Node3D).rotation.z = -2.6 + sin(Time.get_ticks_msec() * 0.01) * 0.4


## Crow nests sit a short flap away from the perch, off the main path, so a
## theft is a quick chase and not a cross-country run.
func _nest_for(home: Vector3) -> Vector3:
	for k in 8:
		var a := TAU * k / 8.0 + 0.4
		var p := Vector2(home.x, home.z) + Vector2(cos(a), sin(a)) * 17.0
		var h := height_at(p.x, p.y)
		if h > 1.3 and h < 6.0 and _dist_to_route(p.x, p.y) > 7.0:
			return Vector3(p.x, h, p.y)
	var q := Vector2(home.x + 15.0, home.z)
	return Vector3(q.x, maxf(height_at(q.x, q.y), 1.5), q.y)


func _update_hints(delta: float) -> void:
	_hint_clock += delta
	if not _hint_started and _hint_clock > 1.2 and not ui.modal_open:
		_hint_started = true
		ui.hint("run", "WASD to run, mouse to look, SPACE to jump.\nFollow the gold arrow to %s and press E at the mailbox!" % job["dest_name"], 8.0)
		ui.hint("trait_" + str(job["trait"]), str(TRAIT_HINTS.get(job["trait"], "")), 9.0)
	_hint_poll -= delta
	if _hint_poll > 0.0 or player == null or player.dead:
		return
	_hint_poll = 0.4
	var pp := player.global_position
	for e in get_tree().get_nodes_in_group("enemy"):
		var d := (e as Node3D).global_position.distance_to(pp)
		if e is Crow and d < 26.0:
			ui.hint("crow", "CROWS steal parcels! Kick them (F) or throw a bottle (Left Click). In a pinch, toss the parcel out of reach with G.", 9.0)
		elif e is Slime and d < 20.0:
			ui.hint("slime", "INSPECTOR SLIME! When the gold ring shrinks onto the green zone, press E to stamp. Miss and he confiscates the parcel - bottle him to make him spit it out.", 10.0)
	if _ogre != null and is_instance_valid(_ogre) and not _ogre.passed and _ogre.global_position.distance_to(pp) < 20.0:
		ui.hint("ogre", "The OGRE wants a riddle answered. Walk up to the gate and press E at the bell. Wrong answers hurt. Three wrong answers are fatal.", 10.0)
	if player.in_water:
		ui.hint("sea", "Shallow water is fine (and cools hot parcels). Deep water drowns goblins.", 7.0)
	if pp.distance_to(dest_pos) < 16.0:
		ui.hint("deliver", "Press E at the red mailbox to deliver. Fast + undamaged = bonus pay and skill points!", 8.0)


func _try_deliver(_by: Node) -> void:
	if _ended or player == null:
		return
	# the Interactable that fired belongs to whichever destination is active
	if player.global_position.distance_to(dest_pos) > 12.0:
		ui.toast("Wrong address. Check the label.", Color("#ffd89a"))
		Sfx.play("error")
		return
	if player.carried == null:
		ui.toast("You have no parcel! Find it!", Color("#ff9d8a"))
		Sfx.play("error")
		return
	var cond := player.carried.condition
	var late := time_left <= 0.0
	var fast := time_left > float(job["time"]) * 0.5
	var pay := int(round(float(job["pay"]) * (cond / 100.0) * (0.5 if late else 1.0)))
	if fast and not late:
		pay += int(round(pay * 0.25))
	var pts := 1 + (1 if cond >= 90.0 else 0)
	Game.copper += pay
	Game.deliveries += 1
	Game.skill_points += pts
	Game.save_game()
	Sfx.play("deliver")
	if cond >= 99.0:
		Game.moment("PERFECT DELIVERY (GOBLIN SURVIVED)")
	var tag := "   (LATE: half pay)" if late else ("   (SPEEDY: +25%)" if fast else "")
	var lines := "Delivered: %s\nCondition: %d%%%s\nPay: %d copper    Skill points: +%d" % [job["title"], int(cond), tag, pay, pts]
	_end("delivered", "DELIVERED!", lines, pay, pts)


func _abandon(_by: Node) -> void:
	if _ended:
		return
	var fee := 10 if player.carried != null else 0
	Game.copper -= fee
	_end("abandoned", "CLOCKED OUT", "You crept back inside.\n%s" % ("Restocking fee: %d copper." % fee if fee > 0 else "No parcel, no fee."), -fee, 0)


func _on_parcel_destroyed(reason: String) -> void:
	if _ended:
		return
	Game.moment("PARCEL DESTROYED (%s)" % reason.to_upper())
	await get_tree().create_timer(1.6).timeout
	if _ended:
		return
	_end("failed", "PARCEL LOST", "%s didn't make it: %s.\nNo pay. The customer 'understands'. (They do not.)" % [job["title"], reason], 0, 0)


func _on_player_died(cause: String) -> void:
	if _ended:
		return
	var dname: String = Game.goblin_name
	var caption := "%s %s" % [dname.to_upper(), cause.to_upper()]
	Game.moment(caption)
	ui.slowmo(0.3, 1.8)
	Game.record_death(cause)
	await get_tree().create_timer(3.4, true, false, true).timeout
	if _ended:
		return
	var lines := "%s %s.\nParcel lost. Funeral deducted: %d copper." % [dname, cause, Game.funeral_cost()]
	_end("died", "%s IS DEAD" % dname.to_upper(), lines, 0, 0)


func _end(outcome: String, title: String, lines: String, _pay: int, _pts: int) -> void:
	if _ended:
		return
	_ended = true
	var quotes: Array = Game.ROAST_DEATH if outcome == "died" else Game.ROAST_OK
	var result := {
		"outcome": outcome, "title": title, "lines": lines,
		"moments": Game.clips.duplicate(),
		"quote": "Grubnik: \"%s\"" % quotes[randi() % quotes.size()],
	}
	Game.perk_hp = 0
	Game.perk_bottles = 0
	Engine.time_scale = 1.0
	await ui.fade_to(1.0, 0.5)
	finished.emit(result)
