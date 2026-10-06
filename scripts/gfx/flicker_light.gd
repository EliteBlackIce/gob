class_name FlickerLight
extends OmniLight3D
## Candle / torch / fire light that wobbles. Also drives an optional flame node.

var base_energy := 1.0
var flame: Node3D = null
var _t := 0.0
var _ph := randf() * 10.0


func _ready() -> void:
	base_energy = light_energy


func _process(delta: float) -> void:
	_t += delta
	var f := 1.0 + sin((_t + _ph) * 13.0) * 0.08 + sin((_t + _ph) * 7.3) * 0.07 + sin((_t + _ph) * 23.0) * 0.04
	light_energy = base_energy * f
	if flame != null:
		flame.scale = Vector3(1.0 + sin(_t * 17.0 + _ph) * 0.08, 1.0 + sin(_t * 11.0 + _ph) * 0.14, 1.0 + cos(_t * 15.0 + _ph) * 0.08)
