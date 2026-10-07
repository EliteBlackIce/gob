class_name LootDrop
extends Node3D
## Anything on the floor you can grab: gear (with a rarity beam), copper, health orbs, bottles, grog.

var kind := "item"             # item | copper | orb | bottle | grog
var item: Dictionary = {}
var amount := 1
var floor_y := 0.0
var player: Player
var ui: UI

var _vel := Vector3.ZERO
var _t := 0.0
var _landed := false
var _body: Node3D
var _label: Label3D
var _full_warned := false
var _grab_delay := 0.5
var _magnet := false


static func spawn(parent: Node, pos: Vector3, kind_id: String, payload: Variant = null, amt := 1, floor_height := 0.0) -> LootDrop:
	var d := LootDrop.new()
	d.kind = kind_id
	d.amount = amt
	if kind_id == "item":
		d.item = payload
	d.floor_y = floor_height
	parent.add_child(d)
	d.global_position = pos
	var a := randf() * TAU
	d._vel = Vector3(cos(a) * randf_range(1.0, 3.2), randf_range(4.0, 6.5), sin(a) * randf_range(1.0, 3.2))
	return d


func _ready() -> void:
	add_to_group("loot")
	_body = Node3D.new()
	add_child(_body)
	var mi := MeshInstance3D.new()
	_body.add_child(mi)
	match kind:
		"item":
			var v := ItemModels.vox_for(item)
			mi.mesh = v.build_coarse(_center(v))
			mi.material_override = VMat.solid(ItemModels.S, 4.0)
			var sc := 1.15 if item["slot"] == "weapon" else 1.5
			mi.scale = Vector3.ONE * sc
			mi.position = Vector3(0, 0.55, 0)
			if item["slot"] == "weapon":
				mi.rotation_degrees.z = 35.0
			_add_beam(int(item["rarity"]))
			_label = Style.label3d(self, ItemDB.title(item), Vector3(0, 1.6, 0), 0.0065, ItemDB.rarity_color(int(item["rarity"])), Vector3.ZERO, true)
			_label.no_depth_test = true
			_label.visible = false
		"copper":
			mi.mesh = DProps.coin()
			mi.material_override = VMat.solid(0.03, 4.0)
			mi.scale = Vector3.ONE * (1.0 + minf(float(amount) / 60.0, 1.0))
			mi.position = Vector3(0, 0.25, 0)
			mi.rotation_degrees.x = 90.0
		"orb":
			mi.mesh = DProps.orb(Color("#ff4a5a"))
			mi.material_override = VMat.solid(0.035, 4.0)
			mi.position = Vector3(0, 0.45, 0)
			var l := OmniLight3D.new()
			l.light_color = Color("#ff5a6a")
			l.light_energy = 0.8
			l.omni_range = 3.5
			l.position = Vector3(0, 0.5, 0)
			add_child(l)
		"bottle":
			mi.mesh = VoxProps.bottle(Color("#3e9c5a"))
			mi.material_override = VMat.solid(0.03, 4.0)
			mi.position = Vector3(0, 0.45, 0)
			mi.scale = Vector3.ONE * 1.6
		"grog":
			mi.mesh = DProps.flask()
			mi.material_override = VMat.solid(0.035, 4.0)
			mi.position = Vector3(0, 0.45, 0)
			mi.scale = Vector3.ONE * 1.4
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _center(v: Vox) -> Vector3:
	var lo := Vector3(1e9, 1e9, 1e9)
	var hi := Vector3(-1e9, -1e9, -1e9)
	for k: Vector3i in v.cells:
		lo = lo.min(Vector3(k))
		hi = hi.max(Vector3(k) + Vector3.ONE)
	return Vector3((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5, (lo.z + hi.z) * 0.5)


func _add_beam(rarity: int) -> void:
	var rc := ItemDB.rarity_color(rarity)
	if rarity >= 1:
		var heights := [0.0, 2.2, 4.5, 7.5, 13.0]
		var hgt: float = heights[rarity]
		var beam := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07 + 0.03 * rarity
		cm.bottom_radius = 0.16 + 0.05 * rarity
		cm.height = hgt
		cm.radial_segments = 8
		cm.rings = 1
		beam.mesh = cm
		beam.material_override = Fx._unshaded(rc, 0.28 + 0.06 * rarity, 2.0)
		beam.position = Vector3(0, hgt * 0.5, 0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
	if rarity >= 2:
		var l := OmniLight3D.new()
		l.light_color = rc
		l.light_energy = 0.9 + 0.4 * (rarity - 2)
		l.omni_range = 4.0 + rarity
		l.position = Vector3(0, 0.8, 0)
		add_child(l)
	if rarity >= 3:
		var p := CPUParticles3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.06, 0.06, 0.06)
		p.mesh = bm
		p.material_override = Fx._unshaded(rc, 1.0, 3.0)
		p.amount = 10 + 6 * rarity
		p.lifetime = 1.6
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.5
		p.direction = Vector3.UP
		p.spread = 20.0
		p.initial_velocity_min = 0.6
		p.initial_velocity_max = 1.6
		p.gravity = Vector3(0, 0.2, 0)
		p.position = Vector3(0, 0.3, 0)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)


func _physics_process(delta: float) -> void:
	_t += delta
	_grab_delay = maxf(0.0, _grab_delay - delta)
	if not _landed:
		_vel.y -= 16.0 * delta
		global_position += _vel * delta
		if global_position.y <= floor_y and _vel.y < 0.0:
			global_position.y = floor_y
			if absf(_vel.y) > 3.0:
				_vel = Vector3(_vel.x * 0.4, -_vel.y * 0.35, _vel.z * 0.4)
			else:
				_landed = true
				_vel = Vector3.ZERO
	if _body != null:
		_body.rotation.y += delta * (2.2 if kind != "copper" else 4.0)
		_body.position.y = (sin(_t * 3.0) * 0.08 + 0.1) if _landed else 0.0
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Player
		return
	if player.dead:
		return
	var dv := player.global_position - global_position
	var dist := Vector2(dv.x, dv.z).length()
	if _label != null:
		_label.visible = dist < 7.0 and absf(dv.y) < 3.0
	if kind in ["copper", "orb"] and _landed and dist < 4.2 and _grab_delay <= 0.0:
		_magnet = true
	if _magnet:
		global_position = global_position.move_toward(player.global_position + Vector3(0, 0.6, 0), (9.0 + 12.0 / maxf(dist, 0.5)) * delta)
		dist = (player.global_position + Vector3(0, 0.6, 0) - global_position).length()
	if _grab_delay <= 0.0 and dist < 1.5 and absf(dv.y) < 2.2:
		_collect()


func _collect() -> void:
	match kind:
		"item":
			if not Game.add_item(item):
				if not _full_warned:
					_full_warned = true
					if ui != null:
						ui.toast("Pack full! Sell or drop something (Tab).", Color("#ff9a7a"))
					Sfx.play("error", -6.0)
				return
			var r := int(item["rarity"])
			Sfx.play("loot_epic" if r >= 3 else ("loot_rare" if r == 2 else "loot"), -2.0)
			if ui != null:
				ui.toast("%s  %s" % [ItemDB.rarity_name(r), ItemDB.title(item)], ItemDB.rarity_color(r))
				if r >= 4:
					Game.moment("LEGENDARY: %s!" % ItemDB.title(item))
		"copper":
			var gain := amount
			Game.copper += gain
			player.copper_run += gain
			Sfx.play("coin", -10.0, randf_range(0.9, 1.3))
		"orb":
			player.heal(player.max_hp * 0.2)
			Sfx.play("potion", -6.0, 1.4)
		"bottle":
			player.bottles += amount
			Sfx.play("loot", -4.0)
			if ui != null:
				ui.toast("+%d throwing bottle%s" % [amount, "s" if amount > 1 else ""], Color("#9fe6b0"))
		"grog":
			var cap := int(player.stats["grog"]) + 2
			if Game.grog_stock < cap:
				Game.grog_stock += amount
				Sfx.play("loot", -4.0)
				if ui != null:
					ui.toast("+1 grog flask", Color("#ffd89a"))
			else:
				return
	Style.burst(get_parent(), global_position + Vector3(0, 0.4, 0), ItemDB.rarity_color(int(item.get("rarity", 0))) if kind == "item" else Color("#ffe27a"), 6, 3.0, 0.07, 0.4)
	queue_free()
