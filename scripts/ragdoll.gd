class_name Ragdoll
extends Node3D
## Pin-jointed voxel goblin corpse. Built from a fresh goblin model whose body parts are
## re-parented onto rigid bodies. The single most clippable object in the game.

var torso: RigidBody3D
var parts: Array[RigidBody3D] = []


static func spawn(parent: Node, pos: Vector3, impulse: Vector3, vest := GoblinModel.LEATHER) -> Ragdoll:
	var r := Ragdoll.new()
	parent.add_child(r)
	r.global_position = pos
	r._build(impulse, vest)
	return r


func _part(size: Vector3, local: Vector3, mass: float) -> RigidBody3D:
	var rb := RigidBody3D.new()
	rb.mass = mass
	rb.collision_layer = 4
	rb.collision_mask = 1
	rb.linear_damp = 0.15
	rb.angular_damp = 0.8
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
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


func _build(impulse: Vector3, vest: Color) -> void:
	var S := GoblinModel.S
	var donor := GoblinModel.build(vest)
	add_child(donor)
	donor.position = Vector3.ZERO
	donor.force_update_transform()
	var rig := GoblinModel.rig_of(donor)
	torso = _part(Vector3(10 * S, 12 * S, 6 * S), Vector3(0, 20 * S, 0), 1.4)
	var head := _part(Vector3(14 * S, 12 * S, 12 * S), Vector3(0, 32 * S + 6 * S, 0), 0.7)
	_pin(torso, head, Vector3(0, 26 * S, 0))
	(rig["Spine"] as Node3D).reparent(torso, true)
	(rig["Head"] as Node3D).reparent(head, true)
	for sd in [1.0, -1.0]:
		var tag := "L" if sd > 0 else "R"
		var arm := _part(Vector3(3 * S, 12 * S, 3 * S), Vector3(sd * 6.5 * S, 20 * S, 0), 0.3)
		_pin(torso, arm, Vector3(sd * 6.5 * S, 25.5 * S, 0))
		(rig["Arm" + tag] as Node3D).reparent(arm, true)
		var leg := _part(Vector3(5 * S, 14 * S, 6 * S), Vector3(sd * 2.5 * S, 7 * S, 0), 0.4)
		_pin(torso, leg, Vector3(sd * 2.5 * S, 14 * S, 0))
		(rig["Leg" + tag] as Node3D).reparent(leg, true)
	donor.queue_free()
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
