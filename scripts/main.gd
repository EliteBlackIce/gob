extends Node
## Scene flow: title -> tavern -> island -> results -> tavern.

var ui: UI
var current: Node = null
var _busy := false


func _ready() -> void:
	randomize()
	ui = UI.new()
	add_child(ui)
	_load_tavern(true)
	ui.show_title(_on_start, _on_reset)
	await ui.fade_to(0.0, 1.0)


func _free_current() -> void:
	if current != null and is_instance_valid(current):
		current.queue_free()
	current = null
	ui.hud_player = null
	Engine.time_scale = 1.0


func _load_tavern(first_load := false) -> void:
	_free_current()
	Sfx.ambience(false)
	var t := Tavern.new()
	t.ui = ui
	t.start_run.connect(_on_start_run)
	add_child(t)
	current = t
	if first_load:
		Sfx.music_volume(-12.0)


func _on_start() -> void:
	ui.capture_wanted = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not Game.seen_intro:
		Game.seen_intro = true
		Game.save_game()
		ui.show_letter("WELCOME, NEW GOBLIN", "Congratulations on your employment.\n\nThe tavern is the post office. The post office is the dungeon entrance. The job board has parcels, and the parcels have customers, and the customers live in places full of things that bite.\n\nPick a contract, walk out the front door, kill whatever's in the way, loot the corpses and deliver the goods. Better gear, bigger bosses. Save up enough copper and we will let you buy a house. (We will not.)\n\nIf you die, the funeral is billed to your account and the dungeon keeps what you found. Swing the dummy by the door first. It has feelings. They are hurt.\n\n- Grubnik (management)", "Oh no")


func _on_reset() -> void:
	Game.reset_save()
	Game.new_day(false)
	Game.current_job = {}
	ui.close_modal(false)
	_load_tavern()
	ui.show_title(_on_start, _on_reset)


func _on_start_run() -> void:
	if _busy:
		return
	_busy = true
	await ui.fade_to(1.0, 0.45)
	_free_current()
	var job: Dictionary = Game.current_job.duplicate()
	if job.get("kind", "route") == "dungeon":
		var dg := Dungeon.new()
		dg.ui = ui
		dg.job = job
		dg.finished.connect(_on_run_finished)
		add_child(dg)
		current = dg
	else:
		var isl := Island.new()
		isl.ui = ui
		isl.job = job
		isl.finished.connect(_on_run_finished)
		add_child(isl)
		current = isl
	ui.capture_wanted = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sfx.music_volume(-20.0)
	await ui.fade_to(0.0, 0.6)
	_busy = false


func _on_run_finished(result: Dictionary) -> void:
	Game.current_job = {}
	Game.new_day()
	Game.save_game()
	_load_tavern()
	Sfx.music_volume(-12.0)
	await ui.fade_to(0.0, 0.6)
	ui.show_result(result, func():
		ui.toast("Day %d.  Grubnik: \"%s\"" % [Game.day, Game.mandate["text"]], Color("#ffd89a"))
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_busy = false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ui.modal_open:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE \
			and ui.capture_wanted and not ui.modal_open:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("clip"):
		var dir := ProjectSettings.globalize_path("user://clips")
		DirAccess.make_dir_recursive_absolute(dir)
		OS.shell_open(dir)
		ui.toast("Opened your clips folder.", Color("#f3e3b5"))
