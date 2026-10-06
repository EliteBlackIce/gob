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
	var S := Structures
	var skin := Color("#7f9a58")
	var m_skin := Paint.skin(Color.WHITE, {"sss": 0.25, "albedo_b": Color("#a09a48")})
	var m_cloth := Paint.cloth(Color.WHITE)
	var m_dark := Paint.get_mat("plain", Color("#1a100a"), {"roughness": 0.9})
	var m_tusk := Paint.get_mat("plain", Color("#efe4bc"), {"roughness": 0.4, "specular": 0.4})
	var torso := Node3D.new()
	torso.position = Vector3(0, 0, -1.6)
	add_child(torso)
	# belly and chest: one big sculpt, with a clerk's waistcoat painted into the vertex colours
	var body := MeshKit.blob(func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 1.15, u.y * 1.05, u.z * 0.8)
		if u.y > 0.3:
			p.x *= 1.0 + 0.25 * (u.y - 0.3)
		p.z += 0.15 * (1.0 - u.y) * u.z
		return p, func(u: Vector3, p: Vector3) -> Color:
		var vest := Color("#7a3f2a")
		var c := skin
		if u.z > 0.0 and u.y < 0.55 and absf(u.x) < 0.85:
			c = vest.lerp(skin, smoothstep(0.7, 0.9, absf(u.x)))
			if absf(u.x) < 0.07:
				c = Color("#2a1a10")
		var ao := lerpf(0.65, 1.0, smoothstep(-1.0, 0.1, u.y))
		return Color(c.r * ao, c.g * ao, c.b * ao, 1.0), 20, 28)
	_mi(torso, body, m_skin, Vector3(0, 1.35, 0.0))
	# arms
	var arm_pivots := []
	for sd in [-1.0, 1.0]:
		var piv := Node3D.new()
		piv.position = Vector3(sd * 1.15, 2.1, 0.0)
		torso.add_child(piv)
		_mi(piv, MeshKit.tube([Vector3(0, 0.1, 0), Vector3(sd * 0.1, -0.5, 0.1), Vector3(sd * 0.05, -1.1, 0.25)], PackedFloat32Array([0.34, 0.3, 0.24]), 10, PackedColorArray([skin, skin.darkened(0.05), skin.darkened(0.1)])), m_skin)
		_mi(piv, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.3, 0.26, 0.28), func(u: Vector3, p: Vector3) -> Color: return skin.lerp(Color("#b08a48"), 0.2)), m_skin, Vector3(sd * 0.05, -1.25, 0.28))
		_mi(piv, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.4, 0.3, 0.4), func(u: Vector3, p: Vector3) -> Color: return Color("#6a4a2a")), m_cloth, Vector3(0.0, 0.05, 0.0))
		if sd > 0:
			arm_r = piv
		arm_pivots.append(piv)
	# head: heavy brow, underbite, tusks, big nose, little cap
	var head := Node3D.new()
	head.position = Vector3(0, 2.75, 0.18)
	torso.add_child(head)
	_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3:
		var p := Vector3(u.x * 0.52, u.y * 0.5, u.z * 0.5)
		if u.y < -0.1 and u.z > 0.1:
			p.z += 0.12 * (-u.y) * u.z
		if u.z > 0.4 and u.y > 0.05 and u.y < 0.45:
			p.z += 0.08
		return p, func(u: Vector3, p: Vector3) -> Color:
		var c := skin.lerp(Color("#a09a48"), clampf(u.y * 0.3, 0.0, 0.3))
		if u.z > 0.6 and u.y < -0.3 and u.y > -0.5 and absf(u.x) < 0.6:
			c = Color("#2a100c")
		return Color(c.r, c.g, c.b, 1.0), 16, 22), m_skin)
	_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.14, 0.17, 0.2), func(u: Vector3, p: Vector3) -> Color: return skin.lerp(Color("#d88a50"), clampf(-u.y * 0.5 + 0.3, 0.0, 1.0))), m_skin, Vector3(0, -0.03, 0.52), Vector3(10, 0, 0))
	for sd in [-1.0, 1.0]:
		_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.085), Paint.get_mat("plain", Color("#fff3b0"), {"roughness": 0.2, "specular": 0.7}), Vector3(sd * 0.2, 0.1, 0.44))
		_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3: return u * Vector3(0.04, 0.05, 0.03)), m_dark, Vector3(sd * 0.2, 0.09, 0.51))
		_mi(head, MeshKit.rbox(Vector3(0.3, 0.07, 0.1), 0.025), Paint.get_mat("plain", Color("#4a5a30")), Vector3(sd * 0.2, 0.22, 0.46), Vector3(0, 0, sd * -18))
		_mi(head, MeshKit.tube([Vector3(0, 0, 0), Vector3(0, 0.12, 0.04), Vector3(0, 0.26, 0.0)], PackedFloat32Array([0.05, 0.04, 0.0]), 6, PackedColorArray([Color("#f4efd8"), Color("#efe4bc"), Color("#e6dab0")])), m_tusk, Vector3(sd * 0.17, -0.28, 0.5), Vector3(-10, 0, sd * -8))
		_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3:
			var t: float = u.x * sd * 0.5 + 0.5
			var p: Vector3 = Vector3(u.x * 0.1 + sd * 0.4, u.y * 0.26 * sin(PI * t) + 0.02, u.z * 0.04)
			return p, func(u: Vector3, p: Vector3) -> Color: return skin.lerp(Color("#d88a50"), 0.4), 6, 10), m_skin, Vector3(sd * 0.28, 0.12, -0.05), Vector3(0, 0, sd * 18))
	# a tiny clerk's cap and a name badge
	_mi(head, MeshKit.blob(func(u: Vector3) -> Vector3: return Vector3(u.x * 0.36, maxf(u.y, -0.05) * 0.18, u.z * 0.3)), Paint.cloth(Color("#2d3a82")), Vector3(0.0, 0.52, 0.02), Vector3(-6, 0, 4))
	_mi(torso, MeshKit.rbox(Vector3(0.5, 0.2, 0.04), 0.012), Paint.get_mat("plain", Color("#e8d8a0")), Vector3(-0.5, 1.9, 0.78), Vector3(-10, 0, 4))
	Style.label3d(torso, "SERVICE", Vector3(-0.5, 1.9, 0.805), 0.0045, Color("#2a1a0d"), Vector3(-10, 0, 4))
	Style.label3d(self, "WINDOW 3\nPlease take a number.\nYou are number 4,892.", Vector3(0, 4.7, -1.0), 0.011, Color("#f3e3b5"), Vector3.ZERO, true)

	# toll barrier arm: striped boom on two posts with warning lamps
	gate = Node3D.new()
	gate.position = Vector3(-4.6, 1.0, 0.8)
	add_child(gate)
	var boom := MeshKit.rbox(Vector3(9.2, 0.22, 0.22), 0.05, 0.1)
	_mi(gate, boom, Paint.painted(Color("#f4f0e4")), Vector3(4.6, 0, 0))
	for i in 6:
		_mi(gate, MeshKit.rbox(Vector3(0.7, 0.24, 0.24), 0.05, 0.1), Paint.painted(Color("#c93a3a")), Vector3(0.35 + i * 1.5, 0, 0))
	var wm := S.wood_white()
	for px in [-4.6, 4.6]:
		_mi(self, MeshKit.rbox(Vector3(0.4, 1.8, 0.4), 0.07), wm, Vector3(px, 0.9, 0.8))
		_mi(self, MeshKit.blob(func(u: Vector3) -> Vector3: return u * 0.14), Paint.glow(Color("#ff3a2a"), 1.8), Vector3(px, 1.95, 0.8))
	# service counter with a brass bell, ledger, and a stamp
	_mi(self, MeshKit.rbox(Vector3(3.4, 1.0, 1.0), 0.06, 0.2), wm, Vector3(0, 0.5, -0.6))
	_mi(self, MeshKit.rbox(Vector3(3.7, 0.12, 1.3), 0.04), Paint.wood(Color("#9a6a3a"), {"grain": 0.7, "roughness": 0.5, "specular": 0.4}), Vector3(0, 1.06, -0.6))
	_mi(self, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.18, 0.0), Vector2(0.2, 0.03), Vector2(0.14, 0.12), Vector2(0.05, 0.2), Vector2(0.0, 0.22)]), 14, PackedColorArray(), "ogrebell"), Paint.metal(Color("#e0b84a"), {"roughness": 0.25, "wear": 0.2}), Vector3(1.0, 1.12, -0.5))
	_mi(self, MeshKit.rbox(Vector3(0.7, 0.07, 0.5), 0.015), Paint.get_mat("cloth", Color("#8a2a2a")), Vector3(-0.8, 1.15, -0.55), Vector3(0, 12, 0))
	_mi(self, MeshKit.rbox(Vector3(0.6, 0.04, 0.42), 0.01), Paint.get_mat("cloth", Color("#f1e6c8")), Vector3(-0.8, 1.2, -0.55), Vector3(0, 12, 0))
	_mi(self, MeshKit.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.06, 0.1), Vector2(0.03, 0.14), Vector2(0.03, 0.2), Vector2(0.0, 0.22)]), 10, PackedColorArray(), "ogrestamp"), Paint.wood(Color("#5a3a22")), Vector3(-0.3, 1.12, -0.3))
	var banner := S.banner(0.9, 2.0, Color("#2d3a82"))
	banner.position = Vector3(-2.2, 3.2, -1.2)
	add_child(banner)
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
	player.take_hit(dir, 24.0, 3 if lethal else 2, "was returned to sender by Customer Service")
