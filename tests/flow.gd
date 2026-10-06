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
	# second run: straight delivery
	Game.current_job = Game.today_jobs[1]
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
	print("\nFLOW TEST: ", "PASS" if fails == 0 else "%d FAILURES" % fails)
	Game.reset_save()
	get_tree().quit(1 if fails > 0 else 0)
