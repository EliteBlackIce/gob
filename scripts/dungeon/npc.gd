class_name Npc
extends Node3D
## A friendly (or at least non-hostile) voxel person: the customer, the merchant, and so on.

var model: Node3D
var label: Label3D
var _t := randf() * 10.0
var _kind := ""
var _goblin := false
var _player: Node3D = null


static func make(parent: Node, kind: String, theme: String, display_name: String, scale_f := 1.0, goblin := false) -> Npc:
	var n := Npc.new()
	n._kind = kind
	n._goblin = goblin
	parent.add_child(n)
	if goblin:
		n.model = GoblinModel.build(Color("#3a6a8a"), Color("#8ac040"), true, Color("#8a2a2a"), true)
	else:
		n.model = MobModels.build(kind, theme)
		for mi in n.model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = VMat.solid(MobModels.S, 4.0)
	n.model.scale = Vector3.ONE * scale_f
	n.add_child(n.model)
	n.label = Style.label3d(n, display_name, Vector3(0, 2.4 * scale_f, 0), 0.008, Color("#ffe9a0"), Vector3.ZERO, true)
	n.label.no_depth_test = true
	return n


func _process(delta: float) -> void:
	_t += delta
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player != null:
		var d := _player.global_position - global_position
		d.y = 0.0
		if d.length() < 12.0 and d.length() > 0.1:
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-4.0 * delta))
	if _goblin:
		GoblinModel.animate(model, 0.0, _t)
	else:
		MobModels.animate(model, _t, 0.0, "idle", 0.0)
