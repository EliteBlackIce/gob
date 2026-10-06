class_name Ogre
extends Node3D
## Customer Service Ogre. Guards the gorge toll gate. Answer his riddle or be
## returned to sender -- at high velocity, in front of your friends.

const RIDDLES := [
	{"q": "I have a stamp but I'm not a postman.\nI have a seal but I'm not an otter.\nWhat am I?", "a": ["An envelope", "A very confused crab", "Your boss"]},
	{"q": "What gets wetter the more it dries?", "a": ["A towel", "The sea", "Your receipt"]},
	{"q": "What has to be broken before you can use it?", "a": ["An egg", "A promise to Grubnik", "A toll gate"]},
	{"q": "I speak without a mouth and hear without ears.\nWhat am I?", "a": ["An echo", "A mailbox", "Your manager"]},
	{"q": "What has hands but cannot clap?", "a": ["A clock", "An ogre", "A skeleton"]},
	{"q": "The more of me there is,\nthe less you can see.", "a": ["Darkness", "Paperwork", "Mail"]},
	{"q": "What can you catch, but never throw?", "a": ["A cold", "A crow", "A parcel"]},
	{"q": "What goes up when the rain comes down?", "a": ["An umbrella", "The price of stamps", "A goblin"]},
]

var island: Node
var player: Player
var ui: UI
var blockade: StaticBody3D
var gate: Node3D
var arm_r: Node3D
var strikes := 0
var passed := false
var bell: Interactable

var _busy := false
var _t := 0.0
var _riddle: Dictionary = {}


func _ready() -> void:
	var skin := Color("#7d9a5a")
	var torso := Node3D.new()
	torso.position = Vector3(0, 0, -1.6)
	add_child(torso)
	Style.box(torso, Vector3(1.7, 1.5, 1.1), Color("#8a5a3a"), Vector3(0, 1.4, 0))
	Style.sphere(torso, 0.95, skin, Vector3(0, 1.2, 0.25), Vector3(1.0, 0.9, 0.8), 9)
	Style.sphere(torso, 0.55, skin, Vector3(0, 2.5, 0.1), Vector3(1.0, 0.95, 1.0), 9)
	Style.box(torso, Vector3(0.9, 0.12, 0.1), Color("#2b1a10"), Vector3(0, 2.35, 0.58))
	for s in [-1, 1]:
		Style.sphere(torso, 0.1, Color.WHITE, Vector3(s * 0.2, 2.62, 0.5), Vector3.ONE, 6)
		Style.sphere(torso, 0.05, Color.BLACK, Vector3(s * 0.2, 2.62, 0.58), Vector3.ONE, 5)
		Style.cone(torso, 0.1, 0.32, Color("#f4efd8"), Vector3(s * 0.28, 2.3, 0.55), Vector3(-20, 0, s * 12), 5)
		Style.cone(torso, 0.16, 0.4, skin.darkened(0.1), Vector3(s * 0.58, 2.6, 0), Vector3(0, 0, -s * 70), 4)
	Style.box(torso, Vector3(0.5, 0.2, 0.05), Color("#e8d8a0"), Vector3(0, 1.9, 0.6))
	Style.label3d(torso, "SERVICE", Vector3(0, 1.9, 0.64), 0.006, Color("#2a1a0d"))
	Style.cyl(torso, 0.55, 0.62, 0.22, Color("#2d3a82"), Vector3(0, 3.0, 0.05), Vector3.ZERO, 8)
	for s in [-1, 1]:
		var arm := Node3D.new()
		arm.position = Vector3(s * 1.05, 1.9, 0)
		torso.add_child(arm)
		Style.box(arm, Vector3(0.45, 1.3, 0.45), skin, Vector3(0, -0.6, 0.15))
		Style.sphere(arm, 0.3, skin, Vector3(0, -1.3, 0.15), Vector3.ONE, 6)
		if s == 1:
			arm_r = arm
	Style.label3d(self, "WINDOW 3\nPlease take a number.\nYou are number 4,892.", Vector3(0, 4.4, -1.0), 0.011, Color("#f3e3b5"))

	# toll barrier arm
	gate = Node3D.new()
	gate.position = Vector3(-4.6, 1.0, 0.8)
	add_child(gate)
	Style.box(gate, Vector3(9.2, 0.22, 0.22), Color("#c93a3a"), Vector3(4.6, 0, 0))
	for i in 6:
		Style.box(gate, Vector3(0.7, 0.24, 0.24), Color.WHITE, Vector3(0.7 + i * 1.5, 0, 0))
	Style.cyl(self, 0.3, 0.3, 1.6, Color("#6a4a2d"), Vector3(-4.6, 0.8, 0.8))
	Style.cyl(self, 0.3, 0.3, 1.6, Color("#6a4a2d"), Vector3(4.6, 0.8, 0.8))
	# counter + bell
	Style.box(self, Vector3(3.2, 1.0, 0.9), Color("#7a5430"), Vector3(0, 0.5, -0.6))
	Style.cyl(self, 0.13, 0.2, 0.2, Color("#e0b84a"), Vector3(1.0, 1.1, -0.5), Vector3.ZERO, 8, 0.2)
	blockade = Style.solid_box(self, Vector3(10.0, 3.0, 0.7), Vector3(0, 1.5, 0.8))
	var counter_col := Style.solid_box(self, Vector3(3.2, 2.0, 1.0), Vector3(0, 1.0, -0.6))
	counter_col.name = "CounterCol"
	bell = Interactable.make(self, Vector3(0, 1.0, 1.6), "Ring the bell for service", Callable(self, "_ring"), 3.2)


func _process(delta: float) -> void:
	_t += delta
	if arm_r != null and not _busy:
		arm_r.rotation.x = sin(_t * 1.5) * 0.05


func _ring(_by: Node) -> void:
	if _busy:
		return
	if passed:
		ui.toast("Window closed. Go through. Shoo.", Color("#f3e3b5"))
		return
	Sfx.play("bell")
	_busy = true
	_riddle = RIDDLES[randi() % RIDDLES.size()]
	var answers: Array = (_riddle["a"] as Array).duplicate()
	var correct: String = answers[0]
	answers.shuffle()
	if Game.has_skill("riddle"):
		var wrong: Array = answers.filter(func(a): return a != correct)
		answers.erase(wrong[0])
		ui.toast("Paperwork Sense: one answer crossed out.", Color("#9dffa0"))
	var heading := "The Ogre sighs. 'Rules are rules.'" if strikes == 0 else "'THAT IS NOT HOW FORM 27-B WORKS.'"
	ui.show_riddle(heading, str(_riddle["q"]), answers, func(idx: int): _answer(answers[idx] == correct))


func _answer(correct: bool) -> void:
	if correct:
		_let_pass()
	else:
		_swing()


func _let_pass() -> void:
	passed = true
	_busy = false
	Sfx.play("deliver")
	ui.toast("'Pleasure doing business.'", Color("#9dffa0"))
	var tw := create_tween()
	tw.tween_property(gate, "rotation:z", deg_to_rad(80.0), 0.9).set_trans(Tween.TRANS_BACK)
	if is_instance_valid(blockade):
		blockade.queue_free()
	bell.prompt = "Window closed"


func _swing() -> void:
	strikes += 1
	Sfx.play("roar", 2.0)
	ui.toast("'FORM 27-B VIOLATION!'", Color("#ff9d8a"))
	var tw := create_tween()
	tw.tween_property(arm_r, "rotation:x", -2.4, 0.25)
	tw.tween_callback(_strike)
	tw.tween_property(arm_r, "rotation:x", 0.0, 0.6)
	tw.tween_callback(func(): _busy = false)


func _strike() -> void:
	if player == null or player.dead:
		return
	var dir := Vector3(randf_range(-0.2, 0.2), 0, 1.0)
	Sfx.play("yeet", 2.0)
	var lethal := strikes >= 3
	Game.moment("RETURN TO SENDER" if not lethal else "SENT TO THE SHADOW REALM (FORM 27-B)")
	ui.slowmo(0.3, 1.4)
	player.take_hit(dir, 24.0, 3 if lethal else 2, "was returned to sender by Customer Service")
