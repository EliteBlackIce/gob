class_name Enemy
extends Node3D
## Shared plumbing for things that want your parcel. They walk the heightfield
## directly instead of using physics, which keeps dozens of them cheap.

var island: Node
var player: Player
var ui: UI
var stun_t := 0.0


func _ready() -> void:
	add_to_group("enemy")


func ground(p: Vector3) -> float:
	return float(island.height_at(p.x, p.z))


func face(dir: Vector3, delta: float, rate := 10.0) -> void:
	if Vector2(dir.x, dir.z).length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-rate * delta))


func hear(_pos: Vector3, _radius: float) -> void:
	pass


func hit(_dir: Vector3, _force: float) -> void:
	pass


func stun(_t: float) -> void:
	pass
