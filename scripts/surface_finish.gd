class_name SurfaceFinish
extends RefCounted
static var _concrete: StandardMaterial3D

static func concrete() -> StandardMaterial3D:
	if _concrete != null:
		return _concrete
	_concrete = StandardMaterial3D.new()
	_concrete.roughness = 0.96
	var noise := FastNoiseLite.new()
	noise.seed = 917
	noise.frequency = 0.22
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	var gradient := Gradient.new()
	gradient.set_color(0,Color("747873"))
	gradient.set_color(1,Color("c0c1b7"))
	texture.color_ramp = gradient
	_concrete.albedo_texture = texture
	var bump := NoiseTexture2D.new()
	bump.width = 256
	bump.height = 256
	bump.noise = noise
	bump.as_normal_map = true
	bump.bump_strength = 0.35
	_concrete.normal_enabled = true
	_concrete.normal_texture = bump
	_concrete.normal_scale = 0.20
	_concrete.uv1_triplanar = true
	_concrete.uv1_world_triplanar = true
	_concrete.uv1_scale = Vector3.ONE * 0.7
	return _concrete
