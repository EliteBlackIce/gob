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


func _part(size: Vector3, local: Vector3, mass: float, is_sphere := false) -> RigidBody3D:
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
	else:
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


## Borrow a mesh node out of a fresh goblin model and re-parent it onto a rigid body.
func _steal(src: Node3D, path: String, to: Node3D, offset: Vector3) -> void:
	var n := src.get_node_or_null(path) as Node3D
	if n == null:
		return
	var gt := n.global_transform
	var copy := n.duplicate() as Node3D
	to.add_child(copy)
	copy.global_transform = Transform3D(gt.basis, gt.origin + offset)


func _build(impulse: Vector3, tunic: Color) -> void:
	# one pristine goblin supplies every body part; each is re-parented onto a limb
	var donor := GoblinModel.build(tunic)
	add_child(donor)
	donor.position = Vector3.ZERO
	donor.force_update_transform()
	torso = _part(Vector3(0.38, 0.55, 0.26), Vector3(0, 0.95, 0), 1.4)
	var head := _part(Vector3(0.2, 0, 0), Vector3(0, 1.4, 0.03), 0.7, true)
	_pin(torso, head, Vector3(0, 1.2, 0.0))
	var rig := GoblinModel.rig_of(donor)
	# torso carries chest, belt, satchel; head carries head + ears + cap
	for nm in ["Spine", "Satchel"]:
		var j := rig[nm] as Node3D
		j.reparent(torso, true)
	(rig["Head"] as Node3D).reparent(head, true)
	var limbs := [["ThighL", Vector3(0.095, 0.7, 0)], ["ThighR", Vector3(-0.095, 0.7, 0)], ["UpperArmL", Vector3(0.24, 1.22, 0)], ["UpperArmR", Vector3(-0.24, 1.22, 0)]]
	for l in limbs:
		var jn := rig[l[0]] as Node3D
		var is_leg: bool = str(l[0]).begins_with("Thigh")
		var rb := _part(Vector3(0.14, 0.62, 0.16) if is_leg else Vector3(0.1, 0.52, 0.12), (l[1] as Vector3) + Vector3(0, -0.28 if is_leg else -0.22, 0), 0.4)
		_pin(torso, rb, l[1])
		jn.reparent(rb, true)
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
