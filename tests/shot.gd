extends Node
## Dev tool: renders a scenario and saves a PNG.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/shot.tscn -- <scenario> <out.png>
## Scenarios: tavern, tavern_fire, island_start, island_gorge, island_hut, island_slime, island_crow

var _ui: UI


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "tavern"
	var out: String = args[1] if args.size() > 1 else "/tmp/shot.png"
	_ui = UI.new()
	add_child(_ui)
	_ui.fade_to(0.0, 0.01)
	var game := Game
	game.hints_seen.clear()
	game.current_job = {}
	if not scenario.begins_with("tavern"):
		game.current_job = game.today_jobs[0]
	var node: Node
	if scenario.begins_with("ui_"):
		var t := Tavern.new()
		t.ui = _ui
		add_child(t)
		await _frames(15)
		Game.skill_points = 3
		Game.owned = {"quick_feet": true, "bottle": true}
		match scenario:
			"ui_skills":
				_ui.show_skills()
			"ui_jobs":
				t._job_board(null)
			"ui_riddle":
				_ui.show_riddle("The Ogre sighs. 'Rules are rules.'", "What gets wetter the more it dries?", ["A towel", "The sea", "Your receipt"], func(_i): pass)
			"ui_result":
				_ui.show_result({"title": "DELIVERED!", "lines": "Delivered: Screaming Cheese\nCondition: 72%\nPay: 43 copper    Skill points: +1", "moments": ["CROW STOLE THE PARCEL", "THE CRATE RAN AWAY"], "quote": "Grubnik: \"Adequate. Do not expect a thank-you.\""}, func(): pass)
			"ui_title":
				_ui.show_title(func(): pass, func(): pass)
		await _frames(8)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out)
		print("saved ", out)
		get_tree().quit()
		return
	if scenario.begins_with("tavern"):
		var t := Tavern.new()
		t.ui = _ui
		add_child(t)
		node = t
		await _frames(30)
		if scenario == "tavern_fire":
			t.player.yaw = -1.2
			t.player.pitch = -0.1
		elif scenario == "tavern_board":
			t.player.position = Vector3(-6, 0.2, -0.5)
			t.player.yaw = 1.1
		else:
			t.player.yaw = 0.35
			t.player.position = Vector3(-3.0, 0.2, 3.0)
			await _frames(5)
	else:
		var j: Dictionary = game.today_jobs[0].duplicate()
		var isl := Island.new()
		isl.ui = _ui
		isl.job = j
		add_child(isl)
		node = isl
		await _frames(20)
		var p: Player = isl.player
		match scenario:
			"island_gorge":
				p.global_position = Vector3(-4, isl.height_at(-4, 28) + 0.5, 28)
				p.yaw = 0.0
				p.pitch = -0.2
			"island_hut":
				p.global_position = Vector3(-6, isl.height_at(-6, -22) + 0.5, -22)
				p.yaw = 0.3
				p.pitch = -0.2
			"island_slime":
				p.global_position = Vector3(-6, isl.height_at(-6, 56) + 0.5, 56)
				p.yaw = 0.0
			"island_start":
				p.yaw = 0.5
				p.pitch = -0.15
				p.cam_dist = 7.0
				p.arm.spring_length = 7.0
			"island_ogre":
				p.global_position = Vector3(-4, isl.height_at(-4, 24) + 0.5, 24)
				p.yaw = 0.0
				p.pitch = -0.12
				p.arm.spring_length = 4.5
			"island_slime2":
				p.global_position = Vector3(-6, isl.height_at(-6, 55) + 0.5, 55)
				p.yaw = 0.0
				p.pitch = -0.12
				p.arm.spring_length = 5.0
				p.carried.visible = true
			"island_ragdoll":
				p.die("was yeeted", Vector3(0, 6, 14))
				await _frames(5)
				var rimg := get_viewport().get_texture().get_image()
				rimg.save_png(out)
				print("saved ", out)
				get_tree().quit()
				return
			"island_wide":
				p.global_position = Vector3(10, isl.height_at(10, 40) + 0.5, 40)
				p.yaw = 0.6
				p.pitch = -0.1
				p.arm.spring_length = 12.0
				p.cam_dist = 12.0
		await _frames(30)
	await _frames(10)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_size())
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
