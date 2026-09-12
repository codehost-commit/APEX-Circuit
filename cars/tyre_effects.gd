extends GPUParticles3D
## World-space plumes inherit wheel velocity. Dust varies by surface and age.
var plume_material: ShaderMaterial
var process: ParticleProcessMaterial
var _surface := ""

func _ready() -> void:
	emitting = false
	amount = 110
	lifetime = 2.6
	local_coords = false
	visibility_aabb = AABB(Vector3(-45,-8,-45),Vector3(90,25,90))
	process = ParticleProcessMaterial.new()
	process.direction = Vector3(0, 0.25, 1)
	process.spread = 32
	process.gravity = Vector3(0.4, 0.75, 0.1)
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 2.8
	process.scale_min = 0.20
	process.scale_max = 0.60
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 1.4
	process.turbulence_noise_scale = 2.0
	process.turbulence_influence_min = 0.08
	process.turbulence_influence_max = 0.35
	process.damping_min = 0.8
	process.damping_max = 2.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,0.12,0.45,1])
	ramp.colors = PackedColorArray([Color(0.65,0.7,0.6,0),Color(1,1,1,0.7),Color(0.7,0.8,0.75,0.3),Color(1,1,1,0)])
	var gradient := GradientTexture1D.new()
	gradient.gradient = ramp
	process.color_ramp = gradient
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0,0.22))
	scale_curve.add_point(Vector2(0.5,0.65))
	scale_curve.add_point(Vector2(1,1))
	var curve := CurveTexture.new()
	curve.curve = scale_curve
	process.scale_curve = curve
	process_material = process
	plume_material = ShaderMaterial.new()
	plume_material.shader = preload("res://materials/tyre_plume.gdshader")
	var noise := FastNoiseLite.new()
	noise.frequency = 0.045
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	plume_material.set_shader_parameter("noise_map", texture)
	var quad := QuadMesh.new()
	quad.size = Vector2(4,4)
	quad.material = plume_material
	draw_pass_1 = quad

func update_plume(grounded: bool, speed: float, surface: String, risk: float, velocity: Vector3) -> void:
	var dirt := surface in ["sand", "gravel", "grass"]
	var active := grounded and speed > 5.0 and (dirt or risk > 1.02)
	if emitting != active:
		emitting = active
	if not active:
		return
	amount_ratio = clampf(speed / 70.0 if dirt else (risk - 0.9) * 0.65, 0.08, 1.0)
	process.direction = (velocity * 0.14 + Vector3(0,1.0,0)).normalized()
	process.initial_velocity_min = speed * 0.08
	process.initial_velocity_max = maxf(2, speed * 0.22)
	if _surface != surface:
		_surface = surface
		plume_material.set_shader_parameter("tint", Color(0.39,0.34,0.19,0.60) if surface == "grass" else (Color(0.65,0.54,0.38,0.75) if dirt else Color(0.82,0.86,0.90,0.55)))
		process.gravity = Vector3(0.65,0.16 if dirt else 0.95,0.3)
