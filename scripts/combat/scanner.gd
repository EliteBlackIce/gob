class_name Scanner
extends RefCounted
## V-key ping. Anything flagged with Scanner.mark() lights up through walls for a few seconds.

const RANGE := 42.0
const COOLDOWN := 2.5
static var _cd := 0.0


static func mark(node: Node, text: String, color: Color) -> void:
	node.add_to_group("scannable")
	node.set_meta("scan_text", text)
	node.set_meta("scan_color", color)


static func ping(player: Player) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _cd:
		return false
	_cd = now + COOLDOWN
	Sfx.play("scan")
	var parent := player.get_parent()
	Fx.ring(parent, player.global_position, 12.0, Color("#7affc8"), 0.7, 0.1)
	Fx.ring(parent, player.global_position, 22.0, Color("#7affc8"), 1.0, 0.1)
	var found := 0
	for n in player.get_tree().get_nodes_in_group("scannable"):
		var node := n as Node3D
		if node == null or not is_instance_valid(node) or not node.is_inside_tree():
			continue
		if node.global_position.distance_to(player.global_position) > RANGE:
			continue
		found += 1
		var old := node.get_node_or_null("ScanTag")
		if old != null:
			old.queue_free()
		var l := Style.label3d(node, str(node.get_meta("scan_text")), Vector3(0, 1.3, 0), 0.0085, node.get_meta("scan_color"), Vector3.ZERO, true)
		l.name = "ScanTag"
		l.no_depth_test = true
		l.render_priority = 5
		l.outline_size = 12
		var tw := l.create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(l, "modulate:a", 0.0, 0.8)
		tw.tween_callback(l.queue_free)
	if player.ui != null and found == 0:
		player.ui.toast("[scan: nothing nearby]", Color("#9aa8a0"))
	return true
