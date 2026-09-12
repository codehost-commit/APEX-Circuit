extends Node3D
## Original procedural open-wheel bodywork, separate steering and axle-roll pivots.

var _paint: StandardMaterial3D
var _carbon: StandardMaterial3D
var _accent: StandardMaterial3D
var _metal: StandardMaterial3D
var _tuning: CarTuning
var _wheels: Array[Dictionary]
var _flap: Node3D
var _steering_wheel: Node3D
var _rain_light: MeshInstance3D
var _material_cache: Dictionary = {}
var _view_occluders: Array = []

func configure(color: Color, tuning: CarTuning, wheels: Array[Dictionary]) -> void:
	_tuning = tuning
	_wheels = wheels
	_paint = _material(color, 0.25, 0.54)
	_carbon = _material(Color("171b20"), 0.46, 0.22)
	_accent = _material(Color("f3f0df"), 0.25, 0.25)
	_metal = _material(Color("89949b"), 0.25, 0.80)

func _ready() -> void:
	_bodywork()
	_cockpit()
	_aero()
	for wheel in _wheels:
		_build_wheel(wheel)
	_decals()
	if "--inspect-unbatched" not in OS.get_cmdline_user_args():
		preload("res://scripts/mesh_batcher.gd").merge_children(self, [_rain_light] + _view_occluders)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var key := Vector4(color.r, color.g, color.b, roughness + metallic * 10.0)
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	_material_cache[key] = material
	return material

func _bodywork() -> void:
	# Elliptical cross sections create a tapered nose, shoulders, and coke-bottle tail.
	_loft("Monocoque", [Vector4(-2.34, 0.34, 0.09, 0.06), Vector4(-1.87, 0.41, 0.17, 0.10),
		Vector4(-1.26, 0.49, 0.24, 0.19), Vector4(-0.80, 0.54, 0.36, 0.24),
		Vector4(0.04, 0.50, 0.43, 0.25), Vector4(0.82, 0.49, 0.38, 0.25),
		Vector4(1.65, 0.40, 0.21, 0.14), Vector4(2.08, 0.30, 0.11, 0.08)], _paint)
	_loft("NoseHighlight", [Vector4(-2.30, 0.385, 0.035, 0.011), Vector4(-1.85, 0.497, 0.065, 0.012),
		Vector4(-1.26, 0.677, 0.083, 0.01), Vector4(-0.86, 0.772, 0.07, 0.009)], _accent)
	_box("CarbonFloor", Vector3(1.72, 0.055, 2.83), Vector3(0.0, 0.17, 0.36), _carbon)
	for side in [-1.0, 1.0]:
		var pod := _loft("Sidepod", [Vector4(-0.60, 0.40, 0.16, 0.11), Vector4(-0.32, 0.49, 0.26, 0.20),
			Vector4(0.30, 0.45, 0.27, 0.21), Vector4(0.81, 0.36, 0.22, 0.14),
			Vector4(1.42, 0.27, 0.11, 0.075)], _paint)
		pod.position.x = side * 0.48
		var intake := _box("RadiatorInlet", Vector3(0.33, 0.13, 0.035), Vector3(side * 0.50, 0.53, -0.43), _carbon)
		intake.rotation_degrees.z = side * 10.0
		_box("PodAccent", Vector3(0.055, 0.03, 1.05), Vector3(side * 0.705, 0.44, 0.29), _accent)
		_box("FloorEdge", Vector3(0.026, 0.065, 2.13), Vector3(side * 0.86, 0.19, 0.32), _carbon)
		for index in range(4):
			var louvre := _box("CoolingLouvre", Vector3(0.24, 0.018, 0.035), Vector3(side * 0.48, 0.67 - index * 0.028, 0.22 + index * 0.15), _carbon)
			louvre.rotation_degrees.x = -12.0
		_rod(Vector3(side * 0.27, 0.77, -0.65), Vector3(side * 0.65, 0.80, -0.69), 0.018, _carbon)
		var mirror := _sphere("Mirror", Vector3(0.14, 0.058, 0.07), Vector3(side * 0.68, 0.80, -0.69), _paint)
		mirror.rotation_degrees.y = side * 16.0
	_loft("EngineCover", [Vector4(0.05, 0.91, 0.19, 0.33), Vector4(0.36, 0.91, 0.20, 0.34),
		Vector4(0.94, 0.64, 0.20, 0.20), Vector4(1.65, 0.41, 0.10, 0.10)], _paint)
	_sphere("AirboxInlet", Vector3(0.115, 0.090, 0.02), Vector3(0.0, 1.10, 0.022), _carbon)
	_box("CameraMount", Vector3(0.065, 0.15, 0.055), Vector3(0.0, 1.30, 0.24), _carbon)
	_box("TVCamera", Vector3(0.35, 0.064, 0.082), Vector3(0.0, 1.38, 0.24), _accent)
	_box("Diffuser", Vector3(1.48, 0.065, 0.47), Vector3(0.0, 0.24, 1.73), _carbon).rotation_degrees.x = 13.0
	for side in [-0.61, -0.30, 0.0, 0.30, 0.61]:
		_box("DiffuserStrake", Vector3(0.021, 0.17, 0.48), Vector3(side, 0.20, 1.78), _carbon)
	_rod(Vector3(0.0, 0.58, 1.28), Vector3(0.0, 0.61, 2.0), 0.065, _metal)
	var light_material := _material(Color("ff233f"), 0.35, 0.0)
	light_material.emission_enabled = true
	light_material.emission = Color("ff1d3e")
	light_material.emission_energy_multiplier = 2.0
	_rain_light = _box("RainLight", Vector3(0.12, 0.095, 0.025), Vector3(0.0, 0.37, 2.09), light_material)

func _cockpit() -> void:
	_sphere("CockpitOpening", Vector3(0.33, 0.11, 0.46), Vector3(0.0, 0.735, -0.24), _carbon)
	_sphere("DriverSuit", Vector3(0.235, 0.13, 0.24), Vector3(0.0, 0.76, -0.11), _paint)
	var helmet_material := _material(Color("eef25d"), 0.24, 0.25)
	_sphere("Helmet", Vector3(0.175, 0.205, 0.20), Vector3(0.0, 0.96, -0.16), helmet_material)
	_sphere("HelmetVisor", Vector3(0.165, 0.057, 0.045), Vector3(0.0, 0.99, -0.335), _material(Color("143344"), 0.12, 0.78))
	var halo_points: Array[Vector3] = []
	for index in range(13):
		var angle := PI * float(index) / 12.0
		halo_points.append(Vector3(cos(angle) * 0.40, 1.02 + sin(angle) * 0.08, -0.04 - sin(angle) * 0.73))
	for index in range(halo_points.size() - 1):
		_view_occluders.append(_rod(halo_points[index], halo_points[index + 1], 0.027, _carbon))
	_view_occluders.append(_rod(Vector3(0.0, 0.73, -0.80), Vector3(0.0, 1.10, -0.77), 0.023, _carbon))
	for side in [-1.0, 1.0]:
		_view_occluders.append(_rod(Vector3(side * 0.40, 1.02, -0.04), Vector3(side * 0.32, 0.78, 0.13), 0.03, _carbon))
		_view_occluders.append(_rod(Vector3(side * 0.15, 0.82, -0.26), Vector3(side * 0.18, 0.84, -0.62), 0.049, _paint))
		_sphere("Glove", Vector3(0.056, 0.055, 0.065), Vector3(side * 0.175, 0.84, -0.65), _accent)
	_steering_wheel = Node3D.new()
	_steering_wheel.name = "SteeringWheel"
	_steering_wheel.position = Vector3(0.0, 0.82, -0.65)
	add_child(_steering_wheel)
	_view_occluders.append(_steering_wheel)
	_box("WheelCenter", Vector3(0.25, 0.13, 0.055), Vector3.ZERO, _carbon, _steering_wheel)
	for side in [-1.0, 1.0]:
		_box("WheelGrip", Vector3(0.045, 0.19, 0.065), Vector3(side * 0.16, 0.0, 0.0), _carbon, _steering_wheel)
		for index in range(3):
			_sphere("WheelButton", Vector3(0.014, 0.014, 0.008), Vector3(side * 0.094, float(index - 1) * 0.036, 0.035), _paint, _steering_wheel)
	_box("WheelScreen", Vector3(0.09, 0.048, 0.007), Vector3(0.0, 0.016, 0.032), _material(Color("7bddd3"), 0.18, 0.12), _steering_wheel)

func _aero() -> void:
	for index in range(3):
		_wing("FrontAerofoil", 1.95 - index * 0.065, 0.21, Vector3(0.0, 0.20 + index * 0.055, -2.31 + index * 0.16), _carbon, self, -8.0 - index * 7.0)
	for side in [-1.0, 1.0]:
		_box("FrontEndplate", Vector3(0.042, 0.18, 0.73), Vector3(side * 0.97, 0.28, -2.18), _paint)
		_rod(Vector3(side * 0.13, 0.36, -1.97), Vector3(side * 0.13, 0.21, -2.25), 0.023, _carbon)
		_box("RearEndplate", Vector3(0.035, 0.44, 0.61), Vector3(side * 0.78, 0.90, 1.95), _paint)
		_rod(Vector3(side * 0.18, 0.40, 1.66), Vector3(side * 0.18, 0.90, 1.99), 0.025, _carbon)
	_wing("RearMainplane", 1.53, 0.28, Vector3(0.0, 0.81, 1.84), _carbon, self, -12.0)
	_flap = Node3D.new()
	_flap.name = "DRSFlapPivot"
	_flap.position = Vector3(0.0, 1.025, 2.02)
	add_child(_flap)
	_wing("ActiveDRSFlap", 1.50, 0.30, Vector3.ZERO, _accent, _flap, 0.0)
	_flap.rotation_degrees.x = -24.0
	_label("APEX", Vector3(0.0, 1.069, 2.04), 28, 0.0055, Color("192129"), Vector3(-90.0, 0.0, 0.0))

func _build_wheel(wheel: Dictionary) -> void:
	var pivot := Node3D.new()
	pivot.name = "%s_SteerPivot" % wheel.name
	pivot.position = Vector3(wheel.local_position)
	pivot.position.y = 0.34
	add_child(pivot)
	wheel.visual = pivot
	var roll_node := Node3D.new()
	roll_node.name = "AxleRoll"
	pivot.add_child(roll_node)
	wheel.roll_node = roll_node
	var width := 0.32 if wheel.front else 0.40
	var rubber := _material(Color("15171a"), 0.83, 0.02)
	var tyre := _lathe_tyre(width, _tuning.wheel_radius)
	_instance("SlickTyre", tyre, rubber, roll_node)
	var side := -1.0 if float(wheel.local_position.x) < 0.0 else 1.0
	for face in [-1.0, 1.0]:
		var hub := _cylinder(0.225, 0.025, _carbon, roll_node)
		hub.position.x = face * width * 0.495
		hub.rotation.z = PI * 0.5
		var brake := _cylinder(0.175, 0.029, _metal, roll_node)
		brake.position.x = face * width * 0.46
		brake.rotation.z = PI * 0.5
		for spoke_index in range(8):
			var angle := TAU * float(spoke_index) / 8.0
			var spoke := _box("RimSpoke", Vector3(0.036, 0.21, 0.022), Vector3(face * width * 0.535, cos(angle) * 0.105, sin(angle) * 0.105), _metal, roll_node)
			spoke.rotation.x = angle
		var ring := TorusMesh.new()
		ring.inner_radius = 0.263
		ring.outer_radius = 0.272
		ring.rings = 32
		ring.ring_segments = 6
		var stripe := _instance("TyreCompoundRing", ring, _material(Color("f2dc47"), 0.75, 0.0), roll_node)
		stripe.position.x = face * width * 0.505
		stripe.rotation.z = PI * 0.5
		var nut := _cylinder(0.053, 0.041, _material(Color("e13e41") if side < 0.0 else Color("447be0"), 0.24, 0.8), roll_node)
		nut.position.x = face * width * 0.57
		nut.rotation.z = PI * 0.5
	var z := float(wheel.local_position.z)
	for height in [0.30, 0.50]:
		_rod(Vector3(side * 0.25, height, z - 0.35), Vector3(side * 0.83, 0.34, z), 0.017, _carbon)
		_rod(Vector3(side * 0.25, height, z + 0.35), Vector3(side * 0.83, 0.34, z), 0.017, _carbon)
	_rod(Vector3(side * 0.20, 0.65, z + 0.13), Vector3(side * 0.83, 0.30, z), 0.013, _metal)
	if not wheel.front:
		_rod(Vector3(side * 0.16, 0.34, z), Vector3(side * 0.82, 0.34, z), 0.025, _metal)
		var dust := CPUParticles3D.new()
		dust.name = "TyreDust"
		dust.position = Vector3(0.0, -0.21, 0.09)
		dust.emitting = false
		dust.amount = 20
		dust.lifetime = 0.65
		dust.local_coords = false
		dust.direction = Vector3(0.0, 0.3, 1.0)
		dust.spread = 24.0
		dust.initial_velocity_min = 1.2
		dust.initial_velocity_max = 3.0
		dust.gravity = Vector3(0.0, 0.3, 0.0)
		dust.scale_amount_min = 0.12
		dust.scale_amount_max = 0.35
		var particle_mesh := QuadMesh.new()
		particle_mesh.size = Vector2.ONE
		var particle_material := _material(Color.WHITE, 1.0, 0.0)
		particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particle_material.vertex_color_use_as_albedo = true
		particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		particle_material.no_depth_test = false
		particle_mesh.material = particle_material
		dust.mesh = particle_mesh
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 1.0, 1.0, 0.25))
		ramp.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
		dust.color_ramp = ramp
		pivot.add_child(dust)
		wheel.dust = dust

func _decals() -> void:
	_label("07", Vector3(0.0, 0.63, -1.39), 44, 0.0040, Color.WHITE, Vector3(-76.0, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		_label("CIRCUIT", Vector3(side * 0.747, 0.48, 0.11), 26, 0.0060, Color.WHITE, Vector3(0.0, side * 90.0, 0.0))

func update_controls(steer: float, drs: bool, brake: float, time: float) -> void:
	if _flap != null:
		_flap.rotation.x = lerpf(_flap.rotation.x, deg_to_rad(1.0 if drs else -24.0), 0.20)
	if _steering_wheel != null:
		_steering_wheel.rotation.z = -steer * 1.15
	if _rain_light != null:
		_rain_light.visible = brake > 0.1 or fmod(time, 0.5) < 0.16

func _box(label: String, size: Vector3, position_value: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := _instance(label, mesh, material, parent)
	node.position = position_value
	return node

func _sphere(label: String, scale_value: Vector3, position_value: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	var node := _instance(label, mesh, material, parent)
	node.position = position_value
	node.scale = scale_value
	return node

func _cylinder(radius: float, height: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	return _instance("MachinedHub", mesh, material, parent)

func _rod(from: Vector3, to: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var node := _cylinder(radius, from.distance_to(to), material)
	node.position = (from + to) * 0.5
	var direction := (to - from).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length_squared() > 0.00001:
		node.quaternion = Quaternion(axis.normalized(), acos(clampf(Vector3.UP.dot(direction), -1.0, 1.0)))
	return node

func _instance(label: String, mesh: Mesh, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = material
	(parent if parent != null else self).add_child(node)
	if label in ["Helmet", "HelmetVisor", "Glove", "DriverSuit"]:
		_view_occluders.append(node)
	return node

func set_camera_view(mode: int) -> void:
	# Driver-eye cutaway: hide the head/arms and decorative wheel so the one
	# functional wheel display stays readable. Exterior cameras retain all art.
	for node: Node3D in _view_occluders:
		node.visible = mode != 2

func _loft(label: String, sections: Array, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 16
	for index in range(sections.size() - 1):
		for segment in range(SEGMENTS):
			var vertices: Array[Vector3] = []
			for corner in [[index, segment], [index + 1, segment], [index + 1, segment + 1], [index, segment + 1]]:
				var section: Vector4 = sections[corner[0]]
				var angle := TAU * float(corner[1]) / SEGMENTS
				vertices.append(Vector3(cos(angle) * section.z, section.y + sin(angle) * section.w, section.x))
			for vertex in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(vertices[vertex])
	for end in [0, sections.size() - 1]:
		var section: Vector4 = sections[end]
		for segment in range(SEGMENTS):
			var angle := TAU * float(segment) / SEGMENTS
			var next_angle := TAU * float(segment + 1) / SEGMENTS
			var a := Vector3(cos(angle) * section.z, section.y + sin(angle) * section.w, section.x)
			var b := Vector3(cos(next_angle) * section.z, section.y + sin(next_angle) * section.w, section.x)
			surface.add_vertex(Vector3(0.0, section.y, section.x))
			surface.add_vertex(b if end == 0 else a)
			surface.add_vertex(a if end == 0 else b)
	surface.generate_normals()
	var shell_material := material.duplicate() as StandardMaterial3D
	shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _instance(label, surface.commit(), shell_material)

func _wing(label: String, width: float, depth: float, position_value: Vector3, material: Material, parent: Node3D, angle: float) -> void:
	var node := _box(label, Vector3(width, 0.025, depth), position_value, material, parent)
	node.rotation_degrees.x = angle

func _lathe_tyre(width: float, radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(-width * 0.5, radius * 0.64), Vector2(-width * 0.52, radius * 0.91),
		Vector2(-width * 0.40, radius), Vector2(width * 0.40, radius), Vector2(width * 0.52, radius * 0.91), Vector2(width * 0.5, radius * 0.64)]
	for index in range(profile.size() - 1):
		for segment in range(32):
			var vertices: Array[Vector3] = []
			for corner in [[index, segment], [index + 1, segment], [index + 1, segment + 1], [index, segment + 1]]:
				var point: Vector2 = profile[corner[0]]
				var angle := TAU * float(corner[1]) / 32.0
				vertices.append(Vector3(point.x, cos(angle) * point.y, sin(angle) * point.y))
			for vertex in [0, 1, 2, 0, 2, 3]:
				surface.add_vertex(vertices[vertex])
	surface.generate_normals()
	return surface.commit()

func _label(value: String, position_value: Vector3, font_size: int, pixel_size: float, color: Color, rotation_value: Vector3) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = pixel_size
	label.modulate = color
	label.outline_size = 0
	label.position = position_value
	label.rotation_degrees = rotation_value
	add_child(label)
