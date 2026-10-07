class_name Scrap
extends Node3D
## Lethal-Company-style loot: goofy junk lying around the dungeon. Grab it with E, haul it home
## (it slows you down), then sell it at Grubnik's quota desk. Die with it and it is gone.

const MAX_CARRY := 6

const DB := {
	"duck": {"name": "Rubber Duck", "lo": 18, "hi": 40, "snd": "squeak"},
	"whoopee": {"name": "Whoopee Cushion", "lo": 10, "hi": 26, "snd": "pfft"},
	"kazoo": {"name": "Brass Kazoo", "lo": 22, "hi": 48, "snd": "kazoo"},
	"gong": {"name": "Tiny Gong", "lo": 40, "hi": 80, "snd": "gong", "heavy": true},
	"eyeball": {"name": "Googly Eyeball", "lo": 30, "hi": 60, "snd": "squeak"},
	"teapot": {"name": "Cursed Teapot", "lo": 45, "hi": 92, "snd": "gong", "fragile": true},
	"cheese": {"name": "Cheese Wheel", "lo": 14, "hi": 34, "snd": "squish"},
	"horn": {"name": "Clown Horn", "lo": 20, "hi": 46, "snd": "honk", "noisy": true},
	"jar": {"name": "Jar of Mystery", "lo": 35, "hi": 78, "snd": "squish", "fragile": true},
	"crown": {"name": "Tiny Crown", "lo": 70, "hi": 130, "snd": "coin"},
	"brush": {"name": "Golden Toilet Brush", "lo": 90, "hi": 160, "snd": "coin"},
	"mug": {"name": "Skull Mug", "lo": 25, "hi": 56, "snd": "bone"},
	"spork": {"name": "Haunted Spork", "lo": 28, "hi": 62, "snd": "giggle"},
	"fish": {"name": "Fish on a Stick", "lo": 16, "hi": 36, "snd": "squish"},
	"anvil": {"name": "Tiny Anvil", "lo": 60, "hi": 110, "snd": "thud", "heavy": true},
	"doll": {"name": "Haunted Doll", "lo": 50, "hi": 100, "snd": "giggle", "noisy": true},
	"bobble": {"name": "Grubnik Bobblehead", "lo": 30, "hi": 70, "snd": "blip"},
	"bphone": {"name": "Banana Phone", "lo": 25, "hi": 55, "snd": "beep", "noisy": true},
	"lamp": {"name": "Glowshroom Lamp", "lo": 35, "hi": 75, "snd": "spore"},
	"plunger": {"name": "Golden Plunger", "lo": 80, "hi": 150, "snd": "coin"},
	"mirror": {"name": "Cursed Mirror", "lo": 70, "hi": 140, "snd": "squeak", "fragile": true},
	"trumpet": {"name": "Toy Trumpet", "lo": 20, "hi": 44, "snd": "kazoo", "noisy": true},
	"egg": {"name": "Enormous Egg", "lo": 55, "hi": 95, "snd": "squish", "heavy": true, "fragile": true},
	"vase": {"name": "Fancy Vase", "lo": 60, "hi": 120, "snd": "bell", "fragile": true},
	"clock": {"name": "Cuckoo Clock", "lo": 45, "hi": 85, "snd": "bell", "noisy": true},
	"boot": {"name": "Single Boot", "lo": 6, "hi": 16, "snd": "thud"},
}

## Short tags shown on pickups and the scan ping.
static func traits_text(scrap_id: String) -> String:
	var d: Dictionary = DB[scrap_id]
	var t: Array[String] = []
	if d.get("heavy", false):
		t.append("heavy")
	if d.get("fragile", false):
		t.append("fragile")
	if d.get("noisy", false):
		t.append("noisy")
	return "" if t.is_empty() else "  [" + ", ".join(t) + "]"

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
	var glint := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.05, 0.05)
	glint.mesh = bm
	glint.material_override = Fx._unshaded(Color("#fff6c0"), 0.9, 3.0)
	glint.position = Vector3(0.18, 0.75, 0)
	glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glint)
	_it = Interactable.make(self, Vector3(0, 0.4, 0), "Grab the %s  (~%d copper)%s" % [DB[id]["name"], value, traits_text(id)], Callable(self, "_grab"), 2.0)
	Scanner.mark(self, "%s  %dc%s" % [DB[id]["name"], value, traits_text(id)], Color("#ffe27a"))


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
		"fish":
			v.box(-1, 0, -1, 1, 10, 1, Color("#8a5a2e"))
			v.ellipsoid(0, 13, 0, 1.6, 4.0, 2.6, Color("#7aa0c8"))
			v.box(-1, 17, -2, 1, 19, 2, Color("#5a80a8"))
			v.box(-2, 13, 2, -1, 14, 3, Color("#101010"), 0.0)
			v.box(1, 13, 2, 2, 14, 3, Color("#101010"), 0.0)
		"anvil":
			v.box(-3, 0, -2, 3, 2, 2, Color("#3a3a42"))
			v.box(-2, 2, -1, 2, 5, 1, Color("#4a4a52"))
			v.box(-6, 5, -2, 5, 8, 2, Color("#5a5a64"))
			v.box(5, 6, -1, 8, 8, 1, Color("#5a5a64"))
		"doll":
			v.box(-2, 0, -2, 2, 6, 2, Color("#e070a0"))
			v.box(-3, 0, -3, 3, 2, 3, Color("#c85088"))
			v.box(-2, 6, -2, 2, 10, 2, Color("#f4e0c8"))
			v.box(-3, 9, -3, 3, 11, 3, Color("#f0d040"))
			v.box(-1, 8, 2, 0, 9, 3, Color("#101010"), 0.0)
			v.box(1, 8, 2, 2, 9, 3, Color("#ff2a2a", 0.3), 0.0)
			v.box(-3, 4, -1, -2, 7, 1, Color("#f4e0c8"))
			v.box(2, 4, -1, 3, 7, 1, Color("#f4e0c8"))
		"bobble":
			v.box(-2, 0, -2, 2, 2, 2, Color("#3a3a46"))
			v.box(-1, 2, -1, 1, 6, 1, Color("#e6b840"))
			v.ellipsoid(0, 9, 0, 4.0, 3.6, 3.6, Color("#8ab04a"))
			v.box(-3, 10, 3, -1, 11, 4, Color("#101010"), 0.0)
			v.box(1, 10, 3, 3, 11, 4, Color("#101010"), 0.0)
			v.box(-2, 7, 3, 2, 8, 4, Color("#5a1a1a"), 0.0)
			v.box(-5, 12, -1, 5, 13, 1, Color("#2a2a2a"))
		"bphone":
			for i in 10:
				var yy := int(round(sin(i * 0.33) * 3.0))
				v.box(i - 5, yy, -1, i - 4, yy + 3, 2, Color("#f2d84a"))
			v.box(-6, 0, -1, -5, 2, 2, Color("#5a3a1e"))
			v.box(-1, 3, -2, 1, 6, -1, Color("#2a2a2a"))
		"lamp":
			v.box(-1, 0, -1, 1, 7, 1, Color("#e8dcc0"))
			v.box(-3, 0, -3, 3, 1, 3, Color("#8a6a4a"))
			v.ellipsoid(0, 9, 0, 4.5, 2.5, 4.5, Color(0.55, 0.9, 1.0, 0.35))
			v.remove_box(-5, 5, -5, 6, 8, 6)
		"plunger":
			v.box(-1, 0, -1, 1, 13, 1, Color("#f0c030"))
			v.ellipsoid(0, 14, 0, 3.5, 2.0, 3.5, Color("#ffd848"))
			v.remove_box(-4, 15, -4, 5, 18, 5)
		"mirror":
			v.box(-4, 0, -1, 4, 12, 1, Color("#8a5a8a"))
			v.box(-3, 1, 0, 3, 11, 2, Color("#c8e8ff"))
			v.box(-1, 5, 1, 1, 7, 2, Color("#ff3a3a", 0.3), 0.0)
			v.box(-1, -3, -1, 1, 0, 1, Color("#6a3a6a"))
		"trumpet":
			v.box(-6, 2, -1, 4, 4, 1, Color("#e84a4a"))
			for i in 4:
				v.box(4 + i, 2 - i / 2, -1 - i / 2, 5 + i, 4 + i / 2, 1 + i / 2, Color("#f0c030"))
			v.box(-2, 4, -1, 0, 6, 1, Color("#3a8ad0"))
		"egg":
			v.ellipsoid(0, 7, 0, 5.0, 7.0, 5.0, Color("#f4eedc"))
			v.box(-2, 9, 4, 0, 11, 5, Color("#b8d870"))
			v.box(2, 5, 4, 4, 7, 5, Color("#b8d870"))
			v.box(-4, 3, 3, -2, 5, 4, Color("#b8d870"))
		"vase":
			v.cyl_y(0, 0, 0, 2, 3.0, 3.0, Color("#3a5ad0"))
			v.cyl_y(0, 0, 2, 9, 4.5, 4.5, Color("#f2f2ff"))
			v.cyl_y(0, 0, 4, 6, 4.8, 4.8, Color("#3a5ad0"))
			v.cyl_y(0, 0, 9, 13, 2.2, 2.2, Color("#f2f2ff"))
			v.cyl_y(0, 0, 13, 14, 3.0, 3.0, Color("#3a5ad0"))
		"clock":
			v.box(-4, 0, -2, 4, 9, 2, Color("#6a4a2e"))
			v.box(-5, 9, -2, 5, 11, 2, Color("#4a2e1a"))
			v.box(-1, 11, -2, 1, 13, 2, Color("#4a2e1a"))
			v.box(-2, 3, 2, 2, 7, 3, Color("#f0ead8"))
			v.box(0, 5, 3, 1, 7, 4, Color("#101010"), 0.0)
			v.box(-1, 7, 2, 1, 9, 4, Color("#f0c030"))
			v.box(-1, -4, 0, 0, 0, 1, Color("#d8a830"))
		"boot":
			v.box(-2, 0, -2, 2, 9, 2, Color("#5a3a22"))
			v.box(-2, 0, 2, 2, 3, 6, Color("#5a3a22"))
			v.box(-2, 0, -2, 2, 1, 6, Color("#2a1a12"))
			v.box(-1, 3, 5, 1, 4, 6, Color("#e8e0d0"))
		_:
			v.box(-3, 0, -3, 3, 6, 3, Color("#aaaaaa"))
	return v
