extends Node
## Look-dev: renders a small lineup under the day lighting.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/look.tscn -- out.png [mode]
## Modes: lineup (default), goblin


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/look.png"
	var mode: String = args[1] if args.size() > 1 else "lineup"
	Atmos.day(self)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.current = true
	var ground := MeshInstance3D.new()
	var v := Vox.new(0.25)
	for x in range(-24, 24):
		for z in range(-24, 24):
			v.set_v(x, -1, z, Color("#5aa83a"), 0.07)
	ground.mesh = v.build()
	ground.material_override = VMat.solid(0.25, 4.0)
	add_child(ground)
	if mode == "goblin":
		await goblin_shots(out, cam)
		return
	if mode == "terrain":
		var t0 := Time.get_ticks_msec()
		VoxTerrain.ensure()
		print("height table ms: ", Time.get_ticks_msec() - t0)
		t0 = Time.get_ticks_msec()
		var holder := Node3D.new()
		add_child(holder)
		VoxTerrain.build_into(holder)
		print("meshing ms: ", Time.get_ticks_msec() - t0, " chunks ", holder.get_child_count())
		cam.position = Vector3(30, 22, 80)
		cam.look_at(Vector3(-4, 1, 30), Vector3.UP)
		cam.far = 600.0
		await _snap(out)
		cam.position = Vector3(-4, 4, 46)
		cam.look_at(Vector3(-4, 3, 10), Vector3.UP)
		await _snap(out.replace(".png", "_gorge.png"))
		get_tree().quit()
		return
	var vb := Vox.new(0.1)
	vb.box(0, 0, 0, 6, 6, 6, Color("#8a5a30"), 0.08)
	vb.ellipsoid(10, 3, 3, 3, 3, 3, Color("#d86a2a"), 0.08)
	vb.box(14, 0, 0, 18, 10, 4, Color("#3a8a3a"), 0.08)
	vb.box(18, 4, 0, 20, 6, 4, Color("#ffcf6a", 0.2), 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = vb.build(Vector3(10, 0, 3))
	mi.material_override = VMat.solid(0.1, 4.0)
	add_child(mi)
	cam.position = Vector3(1.2, 1.3, 2.8)
	cam.look_at(Vector3(0.1, 0.4, 0.0), Vector3.UP)
	await _snap(out)
	get_tree().quit()


func goblin_shots(out: String, cam: Camera3D) -> void:
	var g := GoblinModel.build()
	add_child(g)
	g.rotation_degrees.y = 25
	var shots := [
		["body", Vector3(1.6, 1.1, 3.2), Vector3(0, 0.85, 0), 0.0, 0.0],
		["head", Vector3(0.9, 1.45, 1.5), Vector3(0, 1.38, 0), 0.0, 0.0],
		["back", Vector3(-1.5, 1.2, -3.0), Vector3(0, 0.85, 0), 0.0, 0.0],
		["run", Vector3(3.0, 1.0, 2.6), Vector3(0, 0.8, 0), 1.0, 0.4],
	]
	for sh in shots:
		cam.position = sh[1]
		cam.look_at(sh[2], Vector3.UP)
		GoblinModel.animate(g, float(sh[3]), float(sh[4]) + 0.3)
		await _snap(out.replace(".png", "_%s.png" % sh[0]))
	get_tree().quit()


func _snap(out: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
