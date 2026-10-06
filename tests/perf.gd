extends SceneTree
func _init() -> void:
	var t0 := Time.get_ticks_msec()
	VoxTerrain.ensure()
	print("height table ms: ", Time.get_ticks_msec() - t0)
	t0 = Time.get_ticks_msec()
	var n := 0
	for cz in 12:
		for cx in 9:
			var m := VoxTerrain.build_chunk(cx, cz)
			n += m.get_surface_count()
			if cz == 3 and cx == 4:
				print("one chunk ms so far: ", Time.get_ticks_msec() - t0)
	print("all chunks ms: ", Time.get_ticks_msec() - t0, " surfaces ", n)
	quit()
