extends Node
## Look-dev: a lineup of materials/shapes under sun, for tuning the painted shader.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/look.tscn -- out.png [night]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/look.png"
	var night := args.size() > 1 and args[1] == "night"
	var mode: String = args[1] if args.size() > 1 else "lineup"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#9fd0ee") if not night else Color("#0e0a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9fb4d8") if not night else Color("#6a6aa0")
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = false
	env.glow_intensity = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe9c4")
	sun.light_energy = 0.8
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	ground.mesh = pm
	ground.material_override = Paint.get_mat("ground", Color("#4a8a30"))
	add_child(ground)

	if mode == "goblin":
		await goblin_shots(out)
		return
	var x := -5.0
	# rounded wood crate
	_mesh(MeshKit.rbox(Vector3(1.0, 0.8, 1.0), 0.07), Paint.wood(Color("#8a5c36")), Vector3(x, 0.4, 0)); x += 1.6
	# painted plank
	_mesh(MeshKit.rbox(Vector3(1.2, 0.5, 0.35), 0.05), Paint.painted(Color("#3b6aa8")), Vector3(x, 0.25, 0)); x += 1.6
	# rock
	_mesh(MeshKit.rock(0.7, 3), Paint.stone(Color.WHITE), Vector3(x, 0.3, 0)); x += 1.6
	# barrel (lathe)
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.34, 0.0), Vector2(0.42, 0.25), Vector2(0.46, 0.5), Vector2(0.42, 0.75), Vector2(0.34, 1.0), Vector2(0.0, 1.0)])
	_mesh(MeshKit.lathe(prof, 18), Paint.wood(Color("#8a5a30"), {"stroke_axis": Vector3(0, 1, 0)}), Vector3(x, 0, 0)); x += 1.4
	# skin sphere
	_mesh(MeshKit.blob(func(u): return u * 0.45), Paint.skin(Color("#6f9a2f")), Vector3(x, 0.5, 0)); x += 1.2
	# metal
	_mesh(MeshKit.rbox(Vector3(0.7, 0.25, 0.5), 0.05), Paint.metal(Color("#5b6070")), Vector3(x, 0.15, 0)); x += 1.2
	# frond + broad leaf
	var fm := MeshInstance3D.new()
	fm.mesh = MeshKit.frond()
	fm.material_override = Paint.leaf(Color.WHITE)
	fm.position = Vector3(x, 0.8, 0)
	add_child(fm)
	x += 3.0
	var bl := MeshInstance3D.new()
	bl.mesh = MeshKit.broad_leaf()
	bl.material_override = Paint.leaf(Color.WHITE)
	bl.position = Vector3(x, 0.4, 0)
	add_child(bl)

	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	cam.position = Vector3(0.0, 2.6, 8.0)
	cam.look_at(Vector3(0.5, 0.5, 0), Vector3.UP)
	cam.current = true
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()


func _mesh(m: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func goblin_shots(out: String) -> void:
	var g := GoblinModel.build()
	add_child(g)
	g.rotation_degrees.y = 25
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.current = true
	var shots := [
		["body", Vector3(1.4, 1.1, 3.4), Vector3(0, 0.78, 0), 0.0, 0.0],
		["head", Vector3(0.7, 1.45, 1.35), Vector3(0, 1.35, 0), 0.0, 0.0],
		["back", Vector3(-1.2, 1.2, -3.2), Vector3(0, 0.8, 0), 0.0, 0.0],
		["run", Vector3(2.8, 1.0, 2.6), Vector3(0, 0.75, 0), 1.0, 0.4],
	]
	for sh in shots:
		cam.position = sh[1]
		cam.look_at(sh[2], Vector3.UP)
		GoblinModel.animate(g, float(sh[3]), float(sh[4]) + 0.3)
		for i in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.replace(".png", "_%s.png" % sh[0]))
		print("saved ", sh[0])
	get_tree().quit()
