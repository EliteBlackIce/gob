class_name VMat
extends RefCounted
## Voxel material factory. All models share the two voxel shaders.

static var _sh_opaque: Shader
static var _sh_alpha: Shader
static var _cache := {}


static func opaque_shader() -> Shader:
	if _sh_opaque == null:
		_sh_opaque = load("res://shaders/voxel.gdshader")
	return _sh_opaque


static func alpha_shader() -> Shader:
	if _sh_alpha == null:
		_sh_alpha = load("res://shaders/voxel_alpha.gdshader")
	return _sh_alpha


## Cached opaque material for models with the given voxel size.
static func solid(vox := 0.04, ppv := 4.0, extra := {}) -> ShaderMaterial:
	var key := "s|%s|%s|%s" % [vox, ppv, str(extra)]
	if _cache.has(key):
		return _cache[key]
	var m := make_solid(vox, ppv, extra)
	_cache[key] = m
	return m


## Un-cached (animated per instance, e.g. hit flash or heat glow).
static func make_solid(vox := 0.04, ppv := 4.0, extra := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = opaque_shader()
	m.set_shader_parameter("vox", vox)
	m.set_shader_parameter("ppv", ppv)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	return m


static func glass(vox := 0.04, alpha := 0.7, extra := {}) -> ShaderMaterial:
	var key := "g|%s|%s|%s" % [vox, alpha, str(extra)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = alpha_shader()
	m.set_shader_parameter("vox", vox)
	m.set_shader_parameter("alpha", alpha)
	for k in extra:
		m.set_shader_parameter(k, extra[k])
	_cache[key] = m
	return m
