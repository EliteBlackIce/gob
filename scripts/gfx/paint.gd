class_name Paint
extends RefCounted
## Material library. Every kind is the same painted.gdshader with different knobs,
## so the whole game shares one coherent hand-painted look.

static var _shader: Shader
static var _cache := {}


static func shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/painted.gdshader")
	return _shader


static func _defaults(kind: String, c: Color) -> Dictionary:
	match kind:
		"wood":
			return {"albedo_b": c.darkened(0.28), "variation": 0.45, "grain": 0.9, "grain_scale": 8.0, "stroke_axis": Vector3(1, 0, 0),
				"stroke_stretch": 5.0, "noise_scale": 2.2, "wear": 0.75, "wear_color": c.lightened(0.38).lerp(Color("#d9b27a"), 0.4),
				"roughness": 0.88, "specular": 0.1, "rim": 0.25}
		"painted":
			return {"albedo_b": c.lightened(0.12), "variation": 0.35, "grain": 0.15, "grain_scale": 5.0, "stroke_axis": Vector3(1, 0, 0),
				"stroke_stretch": 3.0, "noise_scale": 2.0, "wear": 0.9, "wear_color": Color("#b89a6a"), "roughness": 0.75, "specular": 0.2, "rim": 0.3}
		"cloth":
			return {"albedo_b": c.darkened(0.2), "variation": 0.5, "noise_scale": 3.0, "stroke_stretch": 3.0, "stroke_axis": Vector3(0, 1, 0),
				"roughness": 1.0, "specular": 0.02, "wrap": 0.5, "sss": 0.25, "sss_color": c.lightened(0.3), "rim": 0.35}
		"stone":
			return {"albedo_b": c.lightened(0.18), "variation": 0.7, "noise_scale": 1.8, "wear": 0.4, "wear_color": c.lightened(0.3),
				"roughness": 0.95, "specular": 0.05, "rim": 0.2, "flat_amount": 0.35}
		"metal":
			return {"albedo_b": c.darkened(0.3), "variation": 0.35, "noise_scale": 5.0, "wear": 0.6, "wear_color": c.lightened(0.5),
				"metallic": 0.55, "roughness": 0.38, "specular": 0.8, "rim": 0.5}
		"skin":
			return {"albedo_b": c.lerp(Color("#d0a050"), 0.35), "variation": 0.45, "noise_scale": 3.5, "roughness": 0.55, "specular": 0.28,
				"wrap": 0.45, "sss": 0.22, "sss_color": Color("#ff9a4a"), "rim": 0.22, "shade_fill": 0.28}
		"leaf":
			return {"albedo_b": c.lightened(0.2), "variation": 0.45, "noise_scale": 3.0, "roughness": 0.55, "specular": 0.16, "wrap": 0.5,
				"sss": 0.3, "sss_color": Color("#9ad43a"), "rim": 0.12, "shade_fill": 0.3}
		"glow":
			return {"emission_strength": 2.0, "roughness": 0.4, "specular": 0.5, "rim": 0.0, "variation": 0.0}
		"glass":
			return {"emission_strength": 0.35, "roughness": 0.1, "specular": 1.0, "rim": 0.8, "variation": 0.2, "albedo_b": c.lightened(0.3)}
		"ground":
			return {"variation": 0.0, "noise_scale": 1.0, "roughness": 1.0, "specular": 0.0, "rim": 0.0, "wrap": 0.3}
	return {"albedo_b": c.lightened(0.12), "variation": 0.3, "roughness": 0.8, "specular": 0.15, "rim": 0.3, "noise_scale": 2.5}


## Cached material of a given kind. extra overrides any shader parameter.
static func get_mat(kind: String, color: Color, extra := {}) -> ShaderMaterial:
	var key := "%s|%s|%s" % [kind, color.to_html(), str(extra)]
	if _cache.has(key):
		return _cache[key]
	var m := make(kind, color, extra)
	_cache[key] = m
	return m


## Un-cached material (for things that animate their own parameters).
static func make(kind: String, color: Color, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader()
	m.set_shader_parameter("albedo", color)
	var p := _defaults(kind, color)
	for k in p:
		m.set_shader_parameter(k, p[k])
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


static func wood(c: Color, extra := {}) -> ShaderMaterial: return get_mat("wood", c, extra)
static func painted(c: Color, extra := {}) -> ShaderMaterial: return get_mat("painted", c, extra)
static func cloth(c: Color, extra := {}) -> ShaderMaterial: return get_mat("cloth", c, extra)
static func stone(c: Color, extra := {}) -> ShaderMaterial: return get_mat("stone", c, extra)
static func metal(c: Color, extra := {}) -> ShaderMaterial: return get_mat("metal", c, extra)
static func skin(c: Color, extra := {}) -> ShaderMaterial: return get_mat("skin", c, extra)
static func leaf(c: Color, extra := {}) -> ShaderMaterial: return get_mat("leaf", c, extra)
static func glow(c: Color, strength := 2.0, extra := {}) -> ShaderMaterial:
	var e := {"emission_strength": strength}
	e.merge(extra, true)
	return get_mat("glow", c, e)
static func glass(c: Color, extra := {}) -> ShaderMaterial: return get_mat("glass", c, extra)
static func plain(c: Color, extra := {}) -> ShaderMaterial: return get_mat("plain", c, extra)
