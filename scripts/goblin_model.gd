class_name GoblinModel
extends RefCounted
## The mascot: a lanky green postal goblin with a satchel. Built from primitives.

const SKIN := Color("#8ab13f")
const SKIN_DARK := Color("#6f9230")
const TUNIC := Color("#3b4aa0")
const LEATHER := Color("#6a4a2d")
const BOOT := Color("#4a3322")
const PAPER := Color("#f1e6c8")


static func build(tunic := TUNIC, skin := SKIN, with_hat := true, hat_color := Color("#2d3a82")) -> Node3D:
	var root := Node3D.new()
	root.name = "GoblinModel"

	for s in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LegL" if s < 0 else "LegR"
		leg.position = Vector3(s * 0.15, 0.5, 0)
		root.add_child(leg)
		Style.box(leg, Vector3(0.17, 0.4, 0.19), Color("#6b5538"), Vector3(0, -0.2, 0))
		Style.box(leg, Vector3(0.23, 0.17, 0.36), BOOT, Vector3(0, -0.43, 0.06))
		Style.box(leg, Vector3(0.25, 0.1, 0.2), LEATHER, Vector3(0, -0.3, 0))

	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	Style.box(body, Vector3(0.5, 0.52, 0.32), tunic, Vector3(0, 0.78, 0))
	Style.box(body, Vector3(0.56, 0.16, 0.36), tunic.darkened(0.15), Vector3(0, 0.5, 0), Vector3(0, 0, 3))
	Style.box(body, Vector3(0.14, 0.62, 0.34), LEATHER, Vector3(-0.06, 0.78, 0), Vector3(0, 0, -28))
	Style.box(body, Vector3(0.54, 0.08, 0.35), LEATHER, Vector3(0, 0.56, 0))
	Style.box(body, Vector3(0.1, 0.09, 0.02), Color("#c9b469"), Vector3(0, 0.56, 0.18))
	Style.box(body, Vector3(0.14, 0.1, 0.02), PAPER, Vector3(0.12, 0.92, 0.17))

	var satchel := Node3D.new()
	satchel.name = "Satchel"
	satchel.position = Vector3(0.3, 0.55, 0.04)
	body.add_child(satchel)
	Style.box(satchel, Vector3(0.14, 0.3, 0.34), LEATHER)
	Style.box(satchel, Vector3(0.16, 0.06, 0.36), LEATHER.darkened(0.2), Vector3(0, 0.15, 0))
	Style.box(satchel, Vector3(0.05, 0.14, 0.2), PAPER, Vector3(0.03, 0.2, 0), Vector3(0, 0, -10))

	var back := Node3D.new()
	back.name = "Back"
	back.position = Vector3(0, 0.85, -0.3)
	body.add_child(back)

	for s in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "ArmL" if s < 0 else "ArmR"
		arm.position = Vector3(s * 0.34, 0.98, 0)
		body.add_child(arm)
		Style.box(arm, Vector3(0.13, 0.26, 0.15), tunic, Vector3(0, -0.12, 0))
		Style.box(arm, Vector3(0.11, 0.3, 0.12), skin, Vector3(0, -0.36, 0))
		Style.sphere(arm, 0.08, skin, Vector3(0, -0.54, 0), Vector3.ONE, 5)

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.28, 0.02)
	body.add_child(head)
	Style.sphere(head, 0.27, skin, Vector3.ZERO, Vector3(1.0, 0.92, 0.96), 9)
	Style.cone(head, 0.07, 0.2, skin_dark(skin), Vector3(0, -0.02, 0.28), Vector3(90, 0, 0), 5)
	for s in [-1, 1]:
		Style.cone(head, 0.13, 0.6, skin_dark(skin).lightened(0.1), Vector3(s * 0.4, 0.05, -0.04), Vector3(0, 0, -s * 78), 4)
		Style.sphere(head, 0.065, Color.WHITE, Vector3(s * 0.1, 0.07, 0.22), Vector3.ONE, 6)
		Style.sphere(head, 0.032, Color("#1a1208"), Vector3(s * 0.1, 0.07, 0.275), Vector3.ONE, 5)
		Style.box(head, Vector3(0.14, 0.03, 0.04), skin_dark(skin), Vector3(s * 0.1, 0.15, 0.23), Vector3(0, 0, s * -12))
	Style.box(head, Vector3(0.2, 0.035, 0.05), Color("#3b1c10"), Vector3(0, -0.12, 0.23))
	Style.box(head, Vector3(0.035, 0.05, 0.03), Color("#f4efd8"), Vector3(-0.05, -0.1, 0.255))
	Style.box(head, Vector3(0.035, 0.05, 0.03), Color("#f4efd8"), Vector3(0.06, -0.1, 0.255))
	if with_hat:
		Style.cyl(head, 0.26, 0.29, 0.14, hat_color, Vector3(0, 0.22, 0), Vector3.ZERO, 8)
		Style.cyl(head, 0.29, 0.29, 0.04, hat_color.darkened(0.2), Vector3(0, 0.28, 0), Vector3.ZERO, 8)
		Style.box(head, Vector3(0.3, 0.04, 0.16), hat_color.darkened(0.25), Vector3(0, 0.15, 0.3), Vector3(8, 0, 0))
		Style.box(head, Vector3(0.12, 0.08, 0.02), PAPER, Vector3(0, 0.23, 0.285))
	return root


static func skin_dark(skin: Color) -> Color:
	return skin.darkened(0.12)


## Cheap procedural walk / idle cycle. speed01: 0 idle .. 1 full run.
static func animate(model: Node3D, speed01: float, t: float, carrying := false) -> void:
	var swing := sin(t * 11.0) * 0.9 * speed01
	var legl: Node3D = model.get_node("LegL")
	var legr: Node3D = model.get_node("LegR")
	var body: Node3D = model.get_node("Body")
	var arml: Node3D = body.get_node("ArmL")
	var armr: Node3D = body.get_node("ArmR")
	var head: Node3D = body.get_node("Head")
	legl.rotation.x = swing
	legr.rotation.x = -swing
	arml.rotation.x = -swing * 0.9
	armr.rotation.x = swing * 0.9
	arml.rotation.z = 0.1 + sin(t * 1.7) * 0.03
	armr.rotation.z = -0.1 - sin(t * 1.7) * 0.03
	body.position.y = absf(sin(t * 11.0)) * 0.07 * speed01 + sin(t * 2.0) * 0.012
	body.rotation.x = 0.12 * speed01 + (0.1 if carrying else 0.0)
	head.rotation.z = sin(t * 11.0) * 0.07 * speed01 + sin(t * 1.3) * 0.03
	head.rotation.x = -body.rotation.x * 0.8
