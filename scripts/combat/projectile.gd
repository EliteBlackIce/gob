class_name Projectile
extends Node3D
## Bolts, arrows, fireballs, staples. Hand-stepped (no physics bodies): cheap and predictable.
## team "mob" hurts the player, team "player" hurts mobs.

var team := "mob"
var vel := Vector3.ZERO
var dmg := 10.0
var radius := 0.35
var life := 4.0
var pierce := false
var color := Color("#ff7a30")
var status := ""                # "burn", "poison", "stun" on hit
var aoe := 0.0                  # explode radius on impact
var gravity := 0.0
var homing := 0.0
var cause := "got shot"
var info := {}
var _hit := {}
var _light: OmniLight3D = null


static func fire(parent: Node, team_name: String, from: Vector3, velocity: Vector3, damage: float, col: Color, opts := {}) -> Projectile:
	var p := Projectile.new()
	p.team = team_name
	p.vel = velocity
	p.dmg = damage
	p.color = col
	for k in opts:
		p.set(k, opts[k])
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var len := 0.5 if vel.length() > 14.0 else 0.28
	bm.size = Vector3(0.14, 0.14, len)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 0.8
	_light.omni_range = 4.0
	add_child(_light)
	_face()


func _face() -> void:
	var n := vel.normalized()
	if vel.length() > 0.1 and absf(n.y) < 0.98:
		look_at(global_position + vel, Vector3.UP)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_end(false)
		return
	vel.y -= gravity * delta
	if homing > 0.0:
		var target: Node3D = null
		if team == "mob":
			target = get_tree().get_first_node_in_group("player") as Node3D
		if target != null:
			var want := (target.global_position + Vector3(0, 1.0, 0) - global_position).normalized() * vel.length()
			vel = vel.lerp(want, clampf(homing * delta, 0.0, 1.0))
	var step := vel * delta
	var from := global_position
	var to := from + step
	# walls
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	var r := space.intersect_ray(q)
	if not r.is_empty():
		global_position = r["position"]
		_end(true)
		return
	global_position = to
	_face()
	if team == "mob":
		var pl := get_tree().get_first_node_in_group("player") as Player
		if pl != null and not pl.dead:
			var c := pl.global_position + Vector3(0, 0.8, 0)
			if _seg_dist(from, to, c) < radius + 0.45:
				pl.take_hit(vel.normalized(), 5.0, dmg, cause)
				if status == "burn":
					pl.add_status("burn", 3.0, dmg * 0.15)
				elif status == "poison":
					pl.add_status("poison", 4.0, dmg * 0.12)
				_end(true)
	else:
		for m in get_tree().get_nodes_in_group("mob"):
			var mob := m as Mob
			if mob == null or mob.dead or _hit.has(mob):
				continue
			var c2 := mob.global_position + Vector3(0, mob.body_h * 0.5, 0)
			if _seg_dist(from, to, c2) < radius + mob.body_r:
				_hit[mob] = true
				var inf := info.duplicate()
				inf["source"] = "ranged"
				mob.take_damage(dmg, vel.normalized(), inf)
				if not pierce:
					_end(true)
					return


func _seg_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _end(impact: bool) -> void:
	if impact:
		Style.burst(get_parent(), global_position, color, 8, 4.0, 0.08, 0.35)
		if aoe > 0.0:
			Fx.ring(get_parent(), global_position - Vector3(0, 0.2, 0), aoe, color, 0.35)
			Sfx.play("pop", -3.0, 0.8)
			if team == "mob":
				var pl := get_tree().get_first_node_in_group("player") as Player
				if pl != null and pl.global_position.distance_to(global_position) < aoe:
					pl.take_hit((pl.global_position - global_position).normalized(), 6.0, dmg, cause)
			else:
				for m in get_tree().get_nodes_in_group("mob"):
					var mob := m as Mob
					if mob != null and not mob.dead and mob.global_position.distance_to(global_position) < aoe:
						mob.take_damage(dmg * 0.7, (mob.global_position - global_position).normalized(), {"source": "ranged"})
	queue_free()
