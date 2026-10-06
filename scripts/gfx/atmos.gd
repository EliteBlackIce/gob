class_name Atmos
extends RefCounted
## Lighting / sky / post-processing presets so every scene shares one mood.

const SUN_DIR_DEG := Vector3(-34.0, 42.0, 0.0)


static func day(parent: Node) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("#2a74d6")
	psm.sky_horizon_color = Color("#c4def0")
	psm.sky_curve = 0.16
	psm.ground_horizon_color = Color("#c4def0")
	psm.ground_bottom_color = Color("#2a6a8a")
	psm.ground_curve = 0.1
	psm.sun_angle_max = 24.0
	psm.sun_curve = 0.12
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9ab8de")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color("#bcd8ee")
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.2
	env.fog_sun_scatter = 0.25
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffe6bc")
	sun.light_energy = 0.92
	sun.rotation_degrees = SUN_DIR_DEG
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.light_angular_distance = 0.5
	parent.add_child(sun)
	return {"env": env, "sun": sun}


static func interior(parent: Node) -> Dictionary:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0e0a12")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a86b8")
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("#7a9ae8")
	moon.light_energy = 0.4
	moon.rotation_degrees = Vector3(-50, 160, 0)
	parent.add_child(moon)
	return {"env": env, "moon": moon}
