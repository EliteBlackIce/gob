extends Node
## Dungeon look-dev: builds a generated dungeon and snaps a few views.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 res://tests/dlook.tscn -- out theme seed
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/dlook"
	var theme: String = args[1] if args.size() > 1 else "crypt"
	var seed_v := int(args[2]) if args.size() > 2 else 11
	Atmos.dungeon(self, theme)
	var g := DungeonGen.generate(seed_v, theme, 1)
	var t0 := Time.get_ticks_msec()
	var level := Node3D.new()
	add_child(level)
	var info := DungeonBuilder.build(level, g)
	print("build ms: ", Time.get_ticks_msec() - t0, " rooms ", g.rooms.size(), " meshes ", (info["meshes"] as Array).size())
	var cam := Camera3D.new()
	cam.fov = 80.0
	add_child(cam)
	cam.current = true
	var r: DungeonGen.DRoom = g.rooms[g.start_id]
	var c := r.center()
	var lamp := OmniLight3D.new()
	lamp.light_energy = 0.5
	lamp.omni_range = 7.0
	cam.add_child(lamp)
	cam.position = Vector3(c.x + 0.5, 1.5, c.y + 0.5)
	cam.rotation.y = 0.5
	await _snap(out + "_a.png")
	cam.rotation.y = 2.4
	await _snap(out + "_b.png")
	var br: DungeonGen.DRoom = g.rooms[g.boss_id]
	var bc := br.center()
	cam.position = Vector3(bc.x + 0.5, 1.5, bc.y + 0.5 + 5)
	cam.rotation = Vector3(-0.05, 0.0, 0)
	await _snap(out + "_c.png")
	# top-down overview
	cam.position = Vector3(g.width * 0.5, 120, g.height * 0.5)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	cam.far = 400
	# hide ceiling for overview by moving far plane? just snap
	await _snap(out + "_top.png")
	get_tree().quit()


func _snap(path: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
