class_name DungeonAmbience
extends Node
## Lethal-Company-style unease: lights die for a second, things move in the walls, and sometimes
## a tall shape stands at the edge of the torchlight. It vanishes the moment you look at it.

var player: Player
var ui: UI
var dungeon: Node
var _t := randf_range(22.0, 40.0)
var _watcher: Node3D = null
var _watch_look := 0.0
var _watch_life := 0.0
var _rng := RandomNumberGenerator.new()

const LINES := [
	"[something giggles inside the wall]", "[distant thump]", "[a door creaks somewhere]", "[wet footsteps, very slow]",
	"[a kazoo plays one note]", "[Grubnik clears his throat from the walls]", "[your parcel whispers: \"don't\"]",
	"[chains, then silence]", "[a goblin sobs, far away]", "[the floor breathes]",
]


func _ready() -> void:
	_rng.randomize()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.dead:
		return
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(28.0, 70.0)
		_fire()
	if _watcher != null:
		_update_watcher(delta)


const INTERCOM := [
	"ATTENTION EMPLOYEES: the dungeon is NOT a break room.",
	"Reminder: the quota is due in %d day%s. No pressure. (Pressure.)",
	"Whoever keeps feeding the mimics: stop.",
	"Fun fact: dying is still billed to your account.",
	"The lawn gnomes are not company property. Do not stop looking at them.",
	"Lost and found: one sock. Please do not look up.",
	"Scrap counts 20% extra at the desk. That's called GENEROSITY.",
	"If you hear a kazoo, no you didn't.",
	"Today's safety tip: landmines go off when you step OFF them. Plan accordingly.",
	"Someone left a Haunted Doll in the break room. It is now YOUR doll.",
	"Employee of the month is still vacant. Make me proud. Or don't. I'm busy.",
]


func _fire() -> void:
	var pick := _rng.randi() % 7
	match pick:
		5:
			_intercom()
			return
		6:
			if int(dungeon.get("tier")) >= 2:
				_lights_out()
			else:
				_intercom()
			return
		0:
			_flicker()
		1:
			_sound_line("thump", -2.0)
		2:
			_steps()
		3:
			_sound_line("giggle", -6.0)
		4:
			if _watcher == null and int(dungeon.get("tier")) >= 2:
				_spawn_watcher()
			else:
				_flicker()


func _intercom() -> void:
	var line: String = INTERCOM[_rng.randi() % INTERCOM.size()]
	if line.contains("%d"):
		var dl := Game.quota_days_left()
		line = line % [dl, "" if dl == 1 else "s"]
	Sfx.play("bell", -6.0, 1.3)
	if ui != null:
		ui.toast("GRUBNIK (intercom): \"%s\"" % line, Color("#ffd89a"))


func _lights_out() -> void:
	_caption("[the power goes out]")
	Sfx.play("thump", 0.0, 0.5)
	dungeon.call("blackout", 12.0)
	await get_tree().create_timer(12.0, false).timeout
	if is_instance_valid(player) and not player.dead:
		_caption("[the power flickers back on]")
		Sfx.play("blip", -4.0)


func _caption(text: String) -> void:
	if ui != null:
		ui.toast(text, Color("#9aa8a0"))


func _sound_line(snd: String, db: float) -> void:
	Sfx.play(snd, db)
	_caption(LINES[_rng.randi() % LINES.size()])
	player.shake = maxf(player.shake, 0.2)


func _steps() -> void:
	_caption("[footsteps behind you]")
	for i in 5:
		Sfx.play("step", -8.0 - i * 1.5, 0.8 + _rng.randf() * 0.2)
		await get_tree().create_timer(0.38, false).timeout
		if not is_instance_valid(player):
			return


func _flicker() -> void:
	_caption("[the lights flicker]")
	Sfx.play("thump", -6.0)
	dungeon.call("blackout", 0.7)


func _spawn_watcher() -> void:
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var side := Vector3(-fwd.z, 0, fwd.x)
	var pos := player.global_position + fwd * _rng.randf_range(9.0, 13.0) + side * _rng.randf_range(-3.0, 3.0)
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3(0, 1.4, 0), pos + Vector3(0, 1.4, 0))
	q.exclude = [player.get_rid()]
	if not space.intersect_ray(q).is_empty():
		_flicker()
		return
	var v := Vox.new(0.07)
	var dark := Color("#0c0b10")
	v.box(-3, 0, -2, 3, 22, 2, dark, 0.0)
	v.box(-8, 12, -1, -3, 14, 1, dark, 0.0)
	v.box(3, 12, -1, 8, 14, 1, dark, 0.0)
	v.box(-8, 2, -1, -6, 14, 1, dark, 0.0)
	v.box(6, 2, -1, 8, 14, 1, dark, 0.0)
	v.ellipsoid(0, 25, 0, 4.0, 4.5, 3.5, dark, 0.0)
	v.box(-3, 25, 3, -1, 27, 4, Color(1.0, 0.15, 0.1, 0.2), 0.0)
	v.box(1, 25, 3, 3, 27, 4, Color(1.0, 0.15, 0.1, 0.2), 0.0)
	_watcher = Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = v.build(Vector3(0, 0, 0))
	mi.material_override = VMat.solid(0.07, 4.0)
	_watcher.add_child(mi)
	dungeon.add_child(_watcher)
	_watcher.global_position = Vector3(pos.x, 0.0, pos.z)
	_watch_look = 0.0
	_watch_life = 14.0
	Sfx.play("boss", -14.0, 0.5)
	_caption("[something is standing there]")


func _update_watcher(delta: float) -> void:
	_watch_life -= delta
	var to := _watcher.global_position - player.global_position
	to.y = 0.0
	_watcher.rotation.y = atan2(-to.x, -to.z) + PI
	var fwd := Vector3(-sin(player.yaw), 0, -cos(player.yaw))
	var looking := fwd.dot(to.normalized()) > 0.8
	if looking:
		_watch_look += delta
	if (looking and _watch_look > 0.9) or to.length() < 4.0 or _watch_life <= 0.0:
		if looking and _watch_look > 0.9 and ui != null:
			ui.flash_damage(0.18)
			Sfx.play("thump", -2.0, 0.6)
			player.shake = maxf(player.shake, 0.5)
		_watcher.queue_free()
		_watcher = null
