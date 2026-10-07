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


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.scale = scl
	parent.add_child(m)
	return m


func _ready() -> void:
	var d := VoxCreatures.ogre()
	var mat := VMat.solid(0.07, 4.0)
	var torso := Node3D.new()
	torso.position = Vector3(0, 0.0, -1.6)
	add_child(torso)
	_mi(torso, d["torso"], mat, Vector3(0, 0.55, 0))
	_mi(torso, d["head"], mat, Vector3(0, 1.85, 0.1))
	for sd in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sd * 0.95, 1.7, 0.1)
		torso.add_child(piv)
		_mi(piv, d["arm"], mat)
		if sd > 0:
			arm_r = piv
	Style.label3d(self, "WINDOW 3\nPlease take a number.\nYou are number 4,892.", Vector3(0, 4.3, -1.0), 0.011, Color("#f3e3b5"), Vector3.ZERO, true)
	var vp := VoxProps
	# toll barrier arm: striped boom on two posts with warning lamps
	gate = Node3D.new()
	gate.position = Vector3(-4.6, 1.0, 0.8)
	add_child(gate)
	var boom := Vox.new(0.1)
	for x in 92:
		boom.box(x, 0, 0, x + 1, 2, 2, Color("#f4f0e4") if (x / 7) % 2 == 0 else Color("#c93a3a"), 0.05)
	_mi(gate, boom.build(Vector3.ZERO), VMat.solid(0.1, 4.0), Vector3(0, -0.1, 0))
	for px in [-4.6, 4.6]:
		var post := Vox.new(0.1)
		post.box(0, 0, 0, 4, 18, 4, vp.WOOD_BROWN, 0.07)
		post.box(0, 18, 0, 4, 20, 4, Color("#ff3a2a", 0.15), 0.0)
		_mi(self, post.build(Vector3(2, 0, 2)), VMat.solid(0.1, 4.0), Vector3(px, 0.0, 0.8))
	# service counter with a brass bell and ledger
	var counter := Vox.new(0.1)
	counter.planks(0, 0, 0, 34, 10, 10, Color("#8a5c36"), true, 2, 12)
	counter.box(-1, 10, -1, 35, 11, 11, Color("#a8743c"), 0.05)
	counter.box(24, 11, 3, 28, 13, 7, Color("#e6b840"), 0.04)
	counter.box(25, 13, 4, 27, 14, 6, Color("#e6b840"), 0.04)
	counter.box(4, 11, 2, 12, 12, 8, Color("#8a2a2a"), 0.04)
	counter.box(5, 12, 3, 11, 13, 7, Color("#efe6cc"), 0.03)
	_mi(self, counter.build(Vector3(17, 0, 5)), VMat.solid(0.1, 4.0), Vector3(0, 0, -0.6))
	var banner := vp.banner(Color("#2d3a82"))
	_mi(self, banner, VMat.solid(0.05, 4.0), Vector3(-2.2, 1.2, -1.3))
	blockade = Style.solid_box(self, Vector3(10.0, 3.0, 0.7), Vector3(0, 1.5, 0.8))
	var counter_col := Style.solid_box(self, Vector3(3.4, 2.0, 1.2), Vector3(0, 1.0, -0.6))
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
	player.take_hit(dir, 24.0, 220 if lethal else 45, "was returned to sender by Customer Service")
