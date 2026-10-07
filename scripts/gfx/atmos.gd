class_name Atmos
extends RefCounted
## Lighting, sky, fog, post-processing and the floating light motes.
##
## "Ray-traced" look: Godot has no hardware ray tracing, so on the Forward+ renderer we switch
## on its closest equivalents - SDFGI (real-time bounced light), SSAO + SSIL, volumetric fog
## (sun shafts). On the Compatibility renderer those properties are ignored and the baked
## per-block ambient occlusion, hard sun shadows, bloom and fog carry the look instead.

const SUN_DIR_DEG := Vector3(-42.0, 36.0, 0.0)


static func _is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


static func _gi(env: Environment, strong := true) -> void:
	if not _is_forward_plus():
		return
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssil_enabled = true
	env.ssil_intensity = 0.9
	env.sdfgi_enabled = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.4
	env.sdfgi_use_occlusion = true
	env.sdfgi_read_sky_light = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_energy = 1.1 if strong else 0.8


static func day(parent: Node) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("#3d84ea")
	psm.sky_horizon_color = Color("#b4d8ff")
	psm.sky_curve = 0.2
	psm.ground_horizon_color = Color("#b4d8ff")
	psm.ground_bottom_color = Color("#3a78b0")
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8aa6e0")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color("#bcdcff")
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.25
	env.fog_sun_scatter = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.18
	env.adjustment_contrast = 1.08
	_gi(env)
	env.volumetric_fog_enabled = _is_forward_plus()
	env.volumetric_fog_density = 0.0045
	env.volumetric_fog_albedo = Color("#fff4dc")
	env.volumetric_fog_emission = Color("#000000")
	env.volumetric_fog_anisotropy = 0.7
	env.volumetric_fog_length = 140.0
	env.volumetric_fog_gi_inject = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0cc")
	sun.light_energy = 1.2
	sun.rotation_degrees = SUN_DIR_DEG
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 110.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 2.5
	parent.add_child(sun)
	# a big square sun, MC style
	var disc := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(70, 70)
	disc.mesh = qm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color("#fff3b8")
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.disable_fog = true
	sm.no_depth_test = true
	sm.render_priority = -10
	disc.material_override = sm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = sun.basis.z * 650.0
	parent.add_child(disc)
	return {"env": env, "sun": sun}


static func interior(parent: Node) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0c0914")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#7a74b8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.1
	_gi(env, false)
	env.sdfgi_enabled = false      # the room is fully enclosed; SSAO/SSIL are enough
	env.volumetric_fog_enabled = _is_forward_plus()
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color("#ffd8a0")
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 40.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#8aa6ff")
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-50, 160, 0)
	moon.shadow_enabled = false
	parent.add_child(moon)
	return {"env": env, "moon": moon}


## Dungeon interior: dark, torch-lit, themed fog and ambient colour. dark_mode = "Power Outage".
static func dungeon(parent: Node, theme: String, dark_mode := false) -> Dictionary:
	var pal := DungeonBuilder.theme_colors(theme)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = pal["sky"]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (pal["ambient"] as Color)
	env.ambient_light_energy = 0.3 if dark_mode else 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 1.1
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = pal["fog"]
	env.fog_density = 0.028 if not dark_mode else 0.05
	env.fog_sky_affect = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.22
	env.adjustment_contrast = 1.1
	_gi(env, false)
	env.sdfgi_enabled = false
	if _is_forward_plus():
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.015
		env.volumetric_fog_albedo = (pal["torch"] as Color).lerp(Color.WHITE, 0.5)
		env.volumetric_fog_anisotropy = 0.5
		env.volumetric_fog_length = 30.0
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	return {"env": env}


## Drifting, twinkling light motes that follow the camera ("little light particles in the sky").
static func motes(cam: Node3D, color := Color("#fff2b0"), count := 90, extents := Vector3(16, 7, 16), size := 0.07) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size, size, size)
	p.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 3.0
	m.disable_fog = true
	p.material_override = m
	p.amount = count
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, 0.04, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.2, 1.0))
	curve.add_point(Vector2(0.55, 0.5))
	curve.add_point(Vector2(0.8, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(p)
	return p
