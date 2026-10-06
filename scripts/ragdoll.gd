class_name Ragdoll
extends Node3D
## Pin-jointed goblin corpse. The single most clippable object in the game.

var torso: RigidBody3D
var parts: Array[RigidBody3D] = []


static func spawn(parent: Node, pos: Vector3, impulse: Vector3, tunic := GoblinModel.TUNIC) -> Ragdoll:
	var r := Ragdoll.new()
	parent.add_child(r)
	r.global_position = pos
	r._build(impulse, tunic)
	return r


func _part(size: Vector3, color: Color, local: Vector3, mass: float, is_sphere := false) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.collision_layer = 4
	rb.collision_mask = 1
	rb.linear_damp = 0.15
	rb.angular_damp = 0.8
	var cs := CollisionShape3D.new()
	if is_sphere:
		var s := SphereShape3D.new()
		s.radius = size.x
		cs.shape = s
		Style.sphere(rb, size.x, color, Vector3.ZERO, Vector3.ONE, 8)
	else:
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
		Style.box(rb, size, color)
	rb.add_child(cs)
	add_child(rb)
	rb.position = local
	parts.append(rb)
	return rb


func _pin(a: RigidBody3D, b: RigidBody3D, at: Vector3) -> void:
	var j := PinJoint3D.new()
	add_child(j)
	j.position = at
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)


func _build(impulse: Vector3, tunic: Color) -> void:
	torso = _part(Vector3(0.5, 0.55, 0.32), tunic, Vector3(0, 0.8, 0), 1.4)
	var head := _part(Vector3(0.27, 0, 0), GoblinModel.SKIN, Vector3(0, 1.3, 0), 0.7, true)
	_pin(torso, head, Vector3(0, 1.1, 0))
	Style.cone(head, 0.12, 0.5, GoblinModel.SKIN_DARK, Vector3(0.38, 0, 0), Vector3(0, 0, -78), 4)
	Style.cone(head, 0.12, 0.5, GoblinModel.SKIN_DARK, Vector3(-0.38, 0, 0), Vector3(0, 0, 78), 4)
	for s in [-1, 1]:
		var arm := _part(Vector3(0.12, 0.5, 0.13), GoblinModel.SKIN, Vector3(s * 0.38, 0.8, 0), 0.3)
		_pin(torso, arm, Vector3(s * 0.34, 1.02, 0))
		var leg := _part(Vector3(0.17, 0.5, 0.19), Color("#6b5538"), Vector3(s * 0.15, 0.27, 0), 0.4)
		_pin(torso, leg, Vector3(s * 0.15, 0.52, 0))
	for p in parts:
		p.apply_central_impulse(impulse * p.mass * 0.35)
		p.apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * p.mass * 1.4)
	get_tree().create_timer(6.0).timeout.connect(_fade)


func _fade() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.8)
	tw.tween_callback(queue_free)
