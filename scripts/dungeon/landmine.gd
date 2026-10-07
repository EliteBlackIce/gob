class_name Landmine
extends Node3D
## Lethal Company rules: step on it and it clicks, step OFF it and it blows. Monsters set them off
## too, which is half the fun. Shows up on the scan ping.

var damage := 55.0
var ui: UI
var armed := false
var exploded := false
var _t := randf() * 2.0
var _led: MeshInstance3D
var _led_mat: StandardMaterial3D


static func place(parent: Node, pos: Vector3, dmg: float, ui_ref: UI) -> Landmine:
	var m := Landmine.new()
	m.damage = dmg
	m.ui = ui_ref
	parent.add_child(m)
	m.global_position = pos
	return m


func _ready() -> void:
	add_to_group("mine")
	var v := Vox.new(0.04)
	v.cyl_y(0, 0, 0, 2, 7.5, 7.5, Color("#3a3e36"), 0.03)
	v.cyl_y(0, 0, 2, 3, 5.5, 5.5, Color("#4e5446"), 0.03)
	v.cyl_y(0, 0, 3, 4, 2.5, 2.5, Color("#6a6e60"), 0.02)
	for a in 6:
		var ang := a * TAU / 6.0
		v.box(int(cos(ang) * 6.0), 1, int(sin(ang) * 6.0), int(cos(ang) * 6.0) + 1, 3, int(sin(ang) * 6.0) + 1, Color("#2a2c26"), 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = v.build(Vector3(0, 0, 0))
	mi.material_override = VMat.solid(0.04, 4.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_led = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.04, 0.06)
	_led.mesh = bm
	_led_mat = Fx._unshaded(Color("#ff2a1a"), 1.0, 4.0)
	_led.material_override = _led_mat
	_led.position = Vector3(0, 0.17, 0)
	add_child(_led)
	Scanner.mark(self, "Landmine", Color("#ff5a4a"))


func _physics_process(delta: float) -> void:
	if exploded:
		return
	_t += delta
	var rate := 7.0 if armed else 0.9
	_led.visible = fmod(_t * rate, 1.0) < (0.5 if armed else 0.15)
	var on := false
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead:
		var dv := p.global_position - global_position
		if Vector2(dv.x, dv.z).length() < 0.7 and absf(dv.y) < 1.2:
			on = true
	if not on:
		for n in get_tree().get_nodes_in_group("mob"):
			var m := n as Mob
			if m == null or m.dead or m.hover > 0.0 or m.is_boss:
				continue
			var dm := m.global_position - global_position
			if Vector2(dm.x, dm.z).length() < 0.6 and absf(dm.y) < 1.0:
				on = true
				break
	if on and not armed:
		armed = true
		Sfx.play("click", 4.0, 0.7)
		FloatText.spawn(get_parent(), global_position + Vector3(0, 0.8, 0), "*click*", Color("#ff8a7a"), 1.2)
		if ui != null:
			ui.hint("landmine", "*click*  You're standing on a LANDMINE. It goes off when you step OFF. Roll away fast, or lure a monster onto it first.", 8.0)
	elif not on and armed:
		_explode()


func _explode() -> void:
	exploded = true
	var parent := get_parent()
	var c := global_position
	Sfx.play("boom", 2.0)
	Fx.ring(parent, c, 4.5, Color("#ff9a3a"), 0.5)
	Fx.debris(parent, c + Vector3(0, 0.3, 0), [Color("#3a3e36"), Color("#ff8a2a"), Color("#ffd24a")], 20, 1.2)
	Style.burst(parent, c + Vector3(0, 0.5, 0), Color("#ffb04a"), 24, 8.0, 0.16, 0.6)
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and not p.dead:
		var dv := p.global_position - c
		var dist := dv.length()
		if dist < 4.5:
			var fall := clampf(1.0 - dist / 4.5, 0.25, 1.0)
			p.take_hit(dv.normalized() if dist > 0.05 else Vector3.BACK, 12.0, damage * fall, "stepped off a landmine", null)
		p.shake = maxf(p.shake, clampf(1.2 - dist * 0.08, 0.2, 1.0))
	for n in get_tree().get_nodes_in_group("mob"):
		var m := n as Mob
		if m != null and not m.dead and m.global_position.distance_to(c) < 4.5:
			m.take_damage(damage * 1.6, (m.global_position - c).normalized(), {"knock": 12.0, "source": "mine"})
	for b in get_tree().get_nodes_in_group("breakable"):
		if (b as Node3D).global_position.distance_to(c) < 3.0 and b.has_method("smash"):
			b.smash(((b as Node3D).global_position - c).normalized())
	for other in get_tree().get_nodes_in_group("mine"):
		if other != self and not (other as Landmine).exploded and (other as Node3D).global_position.distance_to(c) < 3.5:
			(other as Landmine).armed = true          # chain reaction on the next frame
	queue_free()
