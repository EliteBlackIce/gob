class_name Scrap
extends Node3D
## Lethal-Company-style loot: goofy junk lying around the dungeon. Grab it with E, haul it home
## (it slows you down), then sell it at Grubnik's quota desk. Die with it and it is gone.

const MAX_CARRY := 6

const DB := {
	"duck": {"name": "Rubber Duck", "lo": 18, "hi": 40, "snd": "squeak"},
	"whoopee": {"name": "Whoopee Cushion", "lo": 10, "hi": 26, "snd": "pfft"},
	"kazoo": {"name": "Brass Kazoo", "lo": 22, "hi": 48, "snd": "kazoo"},
	"gong": {"name": "Tiny Gong", "lo": 40, "hi": 80, "snd": "gong"},
	"eyeball": {"name": "Googly Eyeball", "lo": 30, "hi": 60, "snd": "squeak"},
	"teapot": {"name": "Cursed Teapot", "lo": 45, "hi": 92, "snd": "gong"},
	"cheese": {"name": "Cheese Wheel", "lo": 14, "hi": 34, "snd": "squish"},
	"horn": {"name": "Clown Horn", "lo": 20, "hi": 46, "snd": "honk"},
	"jar": {"name": "Jar of Mystery", "lo": 35, "hi": 78, "snd": "squish"},
	"crown": {"name": "Tiny Crown", "lo": 70, "hi": 130, "snd": "coin"},
	"brush": {"name": "Golden Toilet Brush", "lo": 90, "hi": 160, "snd": "coin"},
	"mug": {"name": "Skull Mug", "lo": 25, "hi": 56, "snd": "bone"},
	"spork": {"name": "Haunted Spork", "lo": 28, "hi": 62, "snd": "giggle"},
}

var id := "duck"
var value := 20
var ui: UI
var _body: Node3D
var _t := randf() * 6.0
var _it: Interactable


static func roll_value(scrap_id: String, tier: int, rng: RandomNumberGenerator) -> int:
	var d: Dictionary = DB[scrap_id]
	return int(round(rng.randf_range(float(d["lo"]), float(d["hi"])) * (1.0 + 0.14 * float(tier - 1))))


static func random_id(rng: RandomNumberGenerator) -> String:
	var keys := DB.keys()
	return keys[rng.randi() % keys.size()]


static func place(parent: Node, pos: Vector3, scrap_id: String, val: int, ui_ref: UI) -> Scrap:
	var s := Scrap.new()
	s.id = scrap_id
	s.value = val
	s.ui = ui_ref
	parent.add_child(s)
	s.global_position = pos
	return s


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	var mi := MeshInstance3D.new()
	var v := model(id)
	mi.mesh = v.build(_center(v))
	mi.material_override = VMat.solid(0.04, 4.0)
	mi.scale = Vector3.ONE * 1.5
	mi.position = Vector3(0, 0.34, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	var gl := OmniLight3D.new()
	gl.light_color = Color("#ffe9a0")
	gl.light_energy = 0.35
	gl.omni_range = 2.2
	gl.position = Vector3(0, 0.5, 0)
	add_child(gl)
	_it = Interactable.make(self, Vector3(0, 0.4, 0), "Grab the %s  (~%d copper)" % [DB[id]["name"], value], Callable(self, "_grab"), 2.0)
	Scanner.mark(self, "%s  %dc" % [DB[id]["name"], value], Color("#ffe27a"))


func _center(v: Vox) -> Vector3:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for k: Vector3i in v.cells:
		lo = lo.min(Vector3(k))
		hi = hi.max(Vector3(k) + Vector3.ONE)
	return Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)


func _process(delta: float) -> void:
	_t += delta
	_body.position.y = 0.06 + sin(_t * 2.4) * 0.04
	_body.rotation.y += delta * 0.7


func _grab(_by: Node) -> void:
	if Game.scrap.size() >= MAX_CARRY:
		Sfx.play("error", -4.0)
		if ui != null:
			ui.toast("Your sack is full (%d)! Haul it home or dump something." % MAX_CARRY, Color("#ff9a7a"))
		return
	Game.scrap.append({"id": id, "value": value, "run": true})
	Game.touch_gear()
	Sfx.play(str(DB[id]["snd"]), 0.0, randf_range(0.9, 1.15))
	if ui != null:
		ui.toast("+ %s  (%dc)   sack %d/%d" % [DB[id]["name"], value, Game.scrap.size(), MAX_CARRY], Color("#ffe27a"))
		if Game.scrap.size() == 1:
			ui.hint("scrap", "SCRAP! Junk is worth copper. Sell it at Grubnik's QUOTA DESK in the tavern. A full sack slows you down, and dying means losing it. Press V to scan for more.", 9.0)
	Style.burst(get_parent(), global_position + Vector3(0, 0.4, 0), Color("#ffe27a"), 8, 3.0, 0.07, 0.4)
	queue_free()


# ---------------------------------------------------------------- models

static func model(scrap_id: String) -> Vox:
	var v := Vox.new(0.04)
	match scrap_id:
		"duck":
			var y := Color("#ffd23a")
			v.ellipsoid(0, 3, 0, 4.5, 3.2, 5.5, y)
			v.ellipsoid(0, 8, 3, 3.0, 3.0, 3.0, y)
			v.box(-1, 7, 6, 2, 8, 9, Color("#ff8a1a"))
			v.box(-2, 9, 4, -1, 10, 5, Color("#111111"))
			v.box(1, 9, 4, 2, 10, 5, Color("#111111"))
			v.box(-1, 3, -6, 1, 6, -4, y)
		"whoopee":
			v.ellipsoid(0, 1.5, 0, 6.5, 1.8, 5.0, Color("#e0507a"))
			v.ellipsoid(0, 2.4, 0, 5.2, 1.0, 4.0, Color("#f07a9a"))
			v.box(5, 1, -1, 8, 3, 1, Color("#c03a60"))
		"kazoo":
			v.box(-6, 1, -1, 6, 3, 1, Color("#d4a030"))
			v.box(-8, 0, -2, -5, 4, 2, Color("#b88820"))
			v.box(5, 3, -1, 7, 5, 1, Color("#a07818"))
			v.box(-1, 3, -1, 2, 4, 1, Color("#222222"))
		"gong":
			v.box(-5, 0, -1, -3, 11, 1, Color("#6a4a2a"))
			v.box(3, 0, -1, 5, 11, 1, Color("#6a4a2a"))
			v.box(-5, 10, -1, 5, 12, 1, Color("#6a4a2a"))
			v.cyl_y(0, 0, 3, 4, 3.5, 3.5, Color("#e0b030"))
			v.ellipsoid(0, 5, 0, 3.5, 3.5, 0.9, Color("#e8c040"))
			v.box(0, 2, -1, 1, 4, 0, Color("#fff0a0"))
		"eyeball":
			v.ellipsoid(0, 4, 0, 4.2, 4.2, 4.2, Color("#f4f4ee"))
			v.ellipsoid(0, 4, 3.0, 2.2, 2.2, 1.6, Color("#1a1a1a"), 0.0)
			v.box(-1, 5, 4, 0, 6, 5, Color("#ffffff"), 0.0)
			v.box(1, 1, 1, 2, 3, 3, Color("#d44a4a"))
		"teapot":
			v.ellipsoid(0, 4, 0, 5.5, 4.0, 5.5, Color("#6a4aa8"))
			v.box(-2, 7, -2, 2, 10, 2, Color("#4a2a88"))
			v.box(-1, 10, -1, 1, 11, 1, Color("#e0b030"))
			v.box(5, 3, -1, 9, 4, 1, Color("#6a4aa8"))
			v.box(7, 4, -1, 9, 7, 1, Color("#6a4aa8"))
			v.box(-9, 3, -1, -5, 7, 1, Color("#4a2a88"))
			v.box(-3, 5, 5, -1, 6, 6, Color("#ff3a3a"), 0.0)
			v.box(1, 5, 5, 3, 6, 6, Color("#ff3a3a"), 0.0)
		"cheese":
			v.cyl_y(0, 0, 0, 5, 5.5, 5.5, Color("#f2c84a"))
			v.cyl_y(0, 0, 5, 6, 4.5, 4.5, Color("#fadc70"))
			v.box(3, 1, 3, 5, 3, 5, Color("#c9962a"))
			v.box(-4, 2, 2, -2, 4, 4, Color("#c9962a"))
			v.box(-1, 4, -5, 1, 5, -4, Color("#c9962a"))
		"horn":
			v.ellipsoid(6, 3, 0, 3.0, 3.0, 3.0, Color("#ff3a3a"))
			v.cyl_y(0, 0, 0, 1, 0.01, 0.01, Color("#000000"))
			for i in 8:
				var r := 1.0 + float(i) * 0.5
				v.box(-6 + i, 3 - int(r * 0.5), -int(r), -5 + i, 3 + int(r * 0.5) + 1, int(r) + 1, Color("#ffd23a") if i % 2 == 0 else Color("#fff0b0"))
		"jar":
			v.box(-4, 0, -4, 4, 9, 4, Color("#9ad8d0"))
			v.box(-3, 1, -3, 3, 8, 3, Color("#6ae070"))
			v.box(-4, 9, -4, 4, 11, 4, Color("#8a5a2a"))
			v.ellipsoid(0, 5, 0, 2.2, 2.2, 2.2, Color("#d8ff8a"))
		"crown":
			v.box(-5, 0, -5, 5, 3, 5, Color("#f0c030"))
			v.remove_box(-4, 0, -4, 4, 4, 4)
			for p in [Vector2i(-5, -5), Vector2i(4, -5), Vector2i(-5, 4), Vector2i(4, 4), Vector2i(-1, -5), Vector2i(0, 4)]:
				v.box(p.x, 3, p.y, p.x + 1, 6, p.y + 1, Color("#f8d848"))
			v.box(-1, 3, -5, 1, 4, -4, Color("#e83a4a"))
		"brush":
			v.box(-1, 0, -1, 1, 14, 1, Color("#f2c030"))
			v.box(-3, 14, -3, 3, 20, 3, Color("#ffd848"))
			v.box(-2, 20, -2, 2, 22, 2, Color("#f8e890"))
			v.box(-3, 17, -3, 3, 18, -2, Color("#e8a020"))
		"mug":
			v.box(-4, 0, -4, 4, 8, 4, Color("#e8e4d4"))
			v.remove_box(-3, 5, -3, 3, 9, 3)
			v.box(-2, 6, 4, 0, 7, 5, Color("#222222"))
			v.box(1, 6, 4, 3, 7, 5, Color("#222222"))
			v.box(4, 2, -1, 7, 6, 1, Color("#e8e4d4"))
			v.box(-3, 5, -3, 3, 6, 3, Color("#6a3a1a"))
		"spork":
			v.box(-1, 0, -1, 1, 14, 1, Color("#c8ccd4"))
			v.box(-3, 14, -1, 3, 18, 1, Color("#dfe3ea"))
			v.box(-3, 18, -1, -2, 21, 1, Color("#dfe3ea"))
			v.box(0, 18, -1, 1, 21, 1, Color("#dfe3ea"))
			v.box(2, 18, -1, 3, 21, 1, Color("#dfe3ea"))
			v.box(-1, 9, 1, 0, 10, 2, Color("#6aff8a"), 0.0)
			v.box(1, 9, 1, 2, 10, 2, Color("#6aff8a"), 0.0)
		_:
			v.box(-3, 0, -3, 3, 6, 3, Color("#aaaaaa"))
	return v
