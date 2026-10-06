class_name Interactable
extends Node3D
## Anything the goblin can poke with E. Lives in the "interactable" group.

var prompt := "Interact"
var radius := 2.2
var enabled := true
var callback: Callable


static func make(parent: Node, pos: Vector3, text: String, cb: Callable, r := 2.2) -> Interactable:
	var i := Interactable.new()
	i.prompt = text
	i.callback = cb
	i.radius = r
	i.position = pos
	parent.add_child(i)
	i.add_to_group("interactable")
	return i


func activate(player: Node) -> void:
	if enabled and callback.is_valid():
		callback.call(player)
