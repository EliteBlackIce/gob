class_name Bottle
extends RigidBody3D
## Chucked glassware. Pops on contact, stuns anything spooky nearby.

var heavy := false
var damage := 30.0
var _life := 2.6
var _done := false


static func throw(parent: Node, from: Vector3, vel: Vector3, is_heavy: bool) -> Bottle:
	var b := Bottle.new()
	b.heavy = is_heavy
	parent.add_child(b)
	b.global_position = from
	b.linear_velocity = vel
	b.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	return b


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 3
	mass = 0.4
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.12
	cs.shape = s
	add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = VoxProps.bottle(Color("#3e9c5a"))
	mi.material_override = VMat.solid(0.03, 4.0)
	mi.position = Vector3(0, -0.1, 0)
	add_child(mi)
	body_entered.connect(func(_b): _pop())
	Sfx.play("whoosh", -6.0, 1.4)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_pop()
		return
	for e in get_tree().get_nodes_in_group("enemy"):
		if (e as Node3D).global_position.distance_to(global_position) < 1.5:
			_pop()
			return
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob != null and not mob.dead and mob.global_position.distance_to(global_position + Vector3(0, -0.5, 0)) < 0.9 + mob.body_r:
			_pop()
			return


func _pop() -> void:
	if _done:
		return
	_done = true
	Sfx.play("pop", 0.0, 0.8)
	var radius := 4.4 if heavy else 3.2
	var stun_t := 4.0 if heavy else 2.6
	Style.burst(get_tree().current_scene, global_position, Color("#7fe0a0"), 12, 6.0, 0.1, 0.6)
	for e in get_tree().get_nodes_in_group("enemy"):
		if (e as Node3D).global_position.distance_to(global_position) < radius:
			e.stun(stun_t)
	Fx.ring(get_tree().current_scene, global_position - Vector3(0, 0.2, 0), radius, Color("#7fe0a0"), 0.35)
	for m in get_tree().get_nodes_in_group("mob"):
		var mob := m as Mob
		if mob != null and not mob.dead and mob.global_position.distance_to(global_position) < radius + mob.body_r:
			var dir := (mob.global_position - global_position)
			dir.y = 0.0
			var info := {"knock": 5.0, "stun": stun_t * 0.5, "source": "bottle"}
			if Game.has_skill("pyro"):
				info["burn"] = damage * 0.3
			mob.take_damage(damage, dir.normalized(), info)
	queue_free()
