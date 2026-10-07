extends Node
## Headless end-to-end flow: title -> tavern -> run -> death -> result -> tavern.
##   godot --headless --fixed-fps 60 --path . res://tests/flow.tscn

var fails := 0


func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	Game.reset_save()
	Game.new_day(false)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(90)
	check(main.current is Tavern, "main boots into the tavern")
	check(main.ui.modal_open, "title screen is showing")
	main.ui.close_modal(false)
	main._on_start()
	await frames(5)
	check(main.ui.modal_open, "intro letter shown to a new goblin")
	main.ui.close_modal()
	Game.current_job = Game.today_jobs[0]
	check(Game.current_job["kind"] == "route", "first board entry is the island route")
	main._on_start_run()
	await frames(200)
	check(main.current is Island, "run starts: island loaded")
	var isl: Island = main.current
	var day0 := Game.day
	isl.player.die("was flow-tested into the sea")
	await frames(500)
	check(main.current is Tavern, "death returns to the tavern")
	check(main.ui.modal_open, "result panel is showing")
	check(Game.day == day0 + 1, "a new day begins")
	main.ui.close_modal(false)
	main._busy = false
	# second run: straight delivery (pin a parcel that can't run off or explode, so it's deterministic)
	Game.current_job = Game.today_jobs[0].duplicate()
	Game.current_job["id"] = "anvil"
	Game.current_job["title"] = "Ceremonial Anvil"
	Game.current_job["trait"] = "heavy"
	main._on_start_run()
	await frames(200)
	isl = main.current
	check(isl is Island, "second run loads")
	var cop := Game.copper
	isl.player.global_position = isl.dest_pos + Vector3(2, 1, 3)
	await frames(10)
	isl._try_deliver(isl.player)
	await frames(200)
	check(main.current is Tavern and Game.copper > cop, "delivery pays and returns to tavern")
	# third run: a procedurally generated dungeon
	main.ui.close_modal(false)
	main._busy = false
	var dj: Dictionary = {}
	for j in Game.today_jobs:
		if j["kind"] == "dungeon":
			dj = j
			break
	Game.current_job = dj
	main._on_start_run()
	await frames(240)
	check(main.current is Dungeon, "dungeon contract loads a dungeon")
	var dg: Dungeon = main.current
	check(dg.rooms.size() >= 9 and dg.player.mode == "dungeon", "dungeon is built and the goblin is inside")
	# die in the dungeon and come back with a result screen
	dg.player.die("was flow-tested by a skeleton")
	await frames(600)
	check(main.current is Tavern and main.ui.modal_open, "dungeon death returns to the tavern with results")
	main.ui.close_modal(false)
	main._busy = false
	# fourth run: win the dungeon via the shortcut (boss + delivery) and bank the loot
	Game.current_job = dj
	main._on_start_run()
	await frames(240)
	dg = main.current
	check(dg is Dungeon, "second dungeon loads")
	dg.boss.take_damage(99999.0, Vector3.FORWARD, {})
	await frames(30)
	dg._deliver(1.0)
	var cop2 := Game.copper
	dg._go_home(null)
	await frames(300)
	check(main.current is Tavern and Game.deliveries >= 2, "delivering a dungeon contract returns home with pay")
	print("\nFLOW TEST: ", "PASS" if fails == 0 else "%d FAILURES" % fails)
	Game.reset_save()
	get_tree().quit(1 if fails > 0 else 0)
