class_name Breakable
extends StaticBody3D
## Barrels, crates, pots and powder kegs. One hit and they explode into chunks (and loot).

var kind := "barrel"
var broken := false
var on_break: Callable


static func make(parent: Node, k: String, pos: Vector3, variant := 0) -> Breakable:
	var b := Breakable.new()
	b.kind = k
	parent.add_child(b)
	b.position = pos
	b.rotation.y = randf() * TAU
	b._build(variant)
	return b


func _build(variant: int) -> void:
	add_to_group("breakable")
	collision_layer = 1
	var mi := MeshInstance3D.new()
	var half := Vector3(0.38, 0.45, 0.38)
	match kind:
		"barrel":
			mi.mesh = VoxProps.barrel()
			mi.material_override = VMat.solid(0.05, 4.0)
			half = Vector3(0.42, 0.45, 0.42)
		"crate":
			mi.mesh = VoxProps.crate()
			mi.material_override = VMat.solid(0.05, 4.0)
			half = Vector3(0.35, 0.35, 0.35)
		"pot":
			mi.mesh = DProps.pot(variant)
			mi.material_override = VMat.solid(0.05, 4.0)
			half = Vector3(0.3, 0.3, 0.3)
		"keg":
			mi.mesh = DProps.keg()
			mi.material_override = VMat.solid(0.05, 4.0)
			half = Vector3(0.45, 0.5, 0.45)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = half * 2.0
	cs.shape = bs
	cs.position = Vector3(0, half.y, 0)
	add_child(cs)


func smash(dir := Vector3.ZERO) -> void:
	if broken:
		return
	broken = true
	remove_from_group("breakable")
	var cols: Array = [Color("#8a5c36"), Color("#6a4222")]
	if kind == "pot":
		cols = [Color("#b86a3c"), Color("#8a4a28")]
	elif kind == "keg":
		cols = [Color("#a02a24"), Color("#3a3a46")]
	Fx.debris(get_parent(), global_position + Vector3(0, 0.4, 0), cols, 12, 1.0)
	Sfx.play("bone" if kind == "pot" else "thud", -6.0, 1.2)
	if kind == "keg":
		_explode()
	if on_break.is_valid():
		on_break.call(self)
	queue_free()


func _explode() -> void:
	var rr := 3.6
	Sfx.play("boom", -1.0)
	Fx.ring(get_parent(), global_position, rr, Color("#ffb040"), 0.5)
	Style.burst(get_parent(), global_position + Vector3(0, 0.5, 0), Color("#ff8a2a"), 20, 8.0, 0.16, 0.7)
	var pl := get_tree().get_first_node_in_group("player") as Player
	var dmg := 28.0 + 4.0 * Game.level
	if pl != null and pl.global_position.distance_to(global_position) < rr:
		pl.take_hit((pl.global_position - global_position).normalized(), 9.0, dmg * 0.6, "a powder keg (it was labelled)")
		pl.shake = maxf(pl.shake, 0.7)
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob != null and not mob.dead and mob.global_position.distance_to(global_position) < rr + mob.body_r:
			mob.take_damage(dmg * 2.2, (mob.global_position - global_position).normalized(), {"knock": 8.0, "source": "explosion", "stun": 1.0})
	for b in get_tree().get_nodes_in_group("breakable"):
		var br := b as Breakable
		if br != null and br != self and not br.broken and br.global_position.distance_to(global_position) < rr:
			br.smash.call_deferred()
