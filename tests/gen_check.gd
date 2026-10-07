extends SceneTree
func _init() -> void:
	var sigs := {}
	var bad := 0
	for s in 200:
		var g := DungeonGen.generate(s * 7919 + 3, ["crypt","sewer","caves","furnace","ice"][s % 5], 1 + s % 4)
		var reach := g.reachable_rooms()
		if reach != g.rooms.size():
			bad += 1
			print("seed ", s, " rooms ", g.rooms.size(), " reach ", reach)
		sigs[g.signature()] = true
		if s < 3:
			var kinds := {}
			for r in g.rooms:
				kinds[r.kind] = int(kinds.get(r.kind, 0)) + 1
			print(s, " rooms=", g.rooms.size(), " floor=", g.floor_count(), " kinds=", kinds)
	print("unique layouts: ", sigs.size(), " / 200  bad=", bad)
	quit()
