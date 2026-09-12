extends Node3D
## Original procedural open-wheel bodywork, separate steering and axle-roll pivots.

var _paint: StandardMaterial3D
var _carbon: ShaderMaterial
var _accent: StandardMaterial3D
var _metal: StandardMaterial3D
var _tuning: CarTuning
var _wheels: Array[Dictionary]
var _flap: Node3D
var _steering_wheel: Node3D
var _rain_light: MeshInstance3D
var _material_cache: Dictionary = {}
var _view_occluders: Array = []
var _mirrors: Array[SubViewport] = []
var _wheel_viewport: SubViewport
var _leds: Array[MeshInstance3D] = []
var _driver_arms: Array[Node3D] = []
var _sponsor_id := 1
var _personal_sponsor := 8
var ghost_mode := false

func configure(color: Color, tuning: CarTuning, wheels: Array[Dictionary], identity := 0) -> void:
	_tuning = tuning
	_sponsor_id = 1 + posmod(identity, 7)
	_personal_sponsor = [8,10,11][identity % 3]
	_wheels = wheels
	_paint = _material(color, 0.30, 0.20)
	_carbon = ShaderMaterial.new()
	_carbon.shader = preload("res://materials/carbon_weave.gdshader")
	_paint.clearcoat_enabled = true
	_paint.clearcoat = 0.85
	_paint.clearcoat_roughness = 0.16
	_accent = _material(Color("f3f0df"), 0.25, 0.25)
	_metal = _material(Color("89949b"), 0.25, 0.80)

func _ready() -> void:
	_bodywork()
	_cockpit()
	_wheel_detail()
	_aero()
	for wheel in _wheels:
		_build_wheel(wheel)
	_decals()
	_build_mirrors()
	if get_parent() is RaycastFormulaCar and get_parent().player_controlled:
		_set_render_layer(self, 2)
	if "--inspect-unbatched" not in OS.get_cmdline_user_args():
		preload("res://scripts/mesh_batcher.gd").merge_children(self, [_rain_light] + _view_occluders)
	for geometry in find_children("*", "GeometryInstance3D", true, false):
		# Moving cars receive GI without leaving a stationary SDFGI silhouette.
		geometry.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC

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
		_rod(Vector3(side * 0.27, 0.77, -0.65), Vector3(side * 0.65, 0.80, -0.91), 0.018, _carbon)
		var mirror := _sphere("Mirror", Vector3(0.14, 0.058, 0.07), Vector3(side * 0.68, 0.80, -0.91), _paint)
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
	_steering_wheel = Node3D.new()
	_steering_wheel.name = "SteeringWheel"
	_steering_wheel.position = Vector3(0.0, 0.82, -0.65)
	add_child(_steering_wheel)
	_box("WheelCenter", Vector3(0.25, 0.13, 0.055), Vector3.ZERO, _carbon, _steering_wheel)
	for side in [-1.0, 1.0]:
		_box("WheelGrip", Vector3(0.045, 0.19, 0.065), Vector3(side * 0.16, 0.0, 0.0), _carbon, _steering_wheel)
		for index in range(3):
			_sphere("WheelButton", Vector3(0.014, 0.014, 0.008), Vector3(side * 0.094, float(index - 1) * 0.036, 0.035), _paint, _steering_wheel)
	_box("ScreenBezel", Vector3(0.174, 0.095, 0.011), Vector3(0.0, 0.012, 0.032), _metal, _steering_wheel)

func _aero() -> void:
	for index in range(5):
		_wing("FrontAerofoil", 1.95 - index * 0.045, 0.19, Vector3(0.0, 0.18 + index * 0.040, -2.40 + index * 0.115), _carbon, self, -8.0 - index * 7.0)
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
	SponsorIdentity.panel(_flap, _sponsor_id, Vector2(1.22,0.25), Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0,0.018,0)))
	for side in [-1.0,1.0]:
		for vane in 4:
			_box("FrontCascade", Vector3(0.21,0.014,0.22),Vector3(side * (0.66 + vane * 0.04),0.29 + vane * 0.036,-2.02),_carbon).rotation_degrees.z = side * 10
		for slot in 5:
			_box("RearEndplateLouvre",Vector3(0.044,0.017,0.34),Vector3(side * 0.78,0.99 - slot * 0.048,1.97),_carbon)
		_box("Bargeboard",Vector3(0.023,0.25,0.55),Vector3(side * 0.71,0.32,-0.8),_paint).rotation_degrees.y = side * 12
		for fin in 3:
			_box("FloorTurningVane",Vector3(0.018,0.15,0.3),Vector3(side * (0.64 + fin * 0.08),0.25,-0.64),_carbon)
	_box("RearCrashStructure",Vector3(0.18,0.16,0.40),Vector3(0,0.34,1.94),_carbon)
	_box("RainLightHousing",Vector3(0.15,0.12,0.065),Vector3(0,0.37,2.074),_carbon)
	for side in [-1.0,1.0]:
		_rod(Vector3(side * 0.10,0.60,1.64),Vector3(side * 0.10,0.61,1.95),0.022,_metal)

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
	var dust := preload("res://cars/tyre_effects.gd").new()
	dust.name = "TyrePlume"
	dust.position = Vector3(0, -0.29, 0.06)
	if not ghost_mode:
		pivot.add_child(dust)
		wheel.dust = dust
	else:
		dust.free()
	# Steering upright, brake caliper, tie rod and realistic wishbone junctions.
	_box("BrakeCaliper",Vector3(0.065,0.15,0.11),Vector3(side * 0.80,0.37,z + 0.12),_metal)
	_rod(Vector3(side * 0.82,0.25,z),Vector3(side * 0.82,0.46,z),0.032,_metal)
	if wheel.front:
		_rod(Vector3(side * 0.22,0.39,z + 0.16),Vector3(side * 0.82,0.36,z + 0.1),0.014,_carbon)

func _decals() -> void:
	for side in [-1.0,1.0]:
		SponsorIdentity.panel(self, _sponsor_id, Vector2(0.78,0.23), Transform3D(Basis(Vector3.UP,side * PI/2), Vector3(side * 0.762,0.48,0.1)))
		SponsorIdentity.panel(self, _personal_sponsor, Vector2(0.30,0.30), Transform3D(Basis(Vector3.UP,side * PI/2), Vector3(side * 0.799,0.84,1.95)))
	SponsorIdentity.panel(self, 0, Vector2(0.18,0.09), Transform3D(Basis(Vector3.RIGHT,-PI/2),Vector3(0,0.68,-1.27)))

func update_controls(steer: float, drs: bool, brake: float, time: float) -> void:
	if _flap != null:
		_flap.rotation.x = lerpf(_flap.rotation.x, deg_to_rad(1.0 if drs else -24.0), 0.20)
	if _steering_wheel != null:
		_steering_wheel.rotation.z = -steer * 1.15
	if _rain_light != null:
		var lit := brake > 0.1 or fmod(time, 0.5) < 0.16
		(_rain_light.material_override as StandardMaterial3D).emission_energy_multiplier = 3.0 if lit else 0.12
	if get_parent() is RaycastFormulaCar:
		var car := get_parent() as RaycastFormulaCar
		for viewport in _mirrors:
			var camera := viewport.get_camera_3d()
			camera.global_transform = car.global_transform * camera.get_meta("mount_pose")
		var fraction := clampf((car.rpm - car.tuning.idle_rpm) / (car.tuning.rev_limit_rpm - car.tuning.idle_rpm),0,1)
		for i in _leds.size():
			var mat := _leds[i].material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.0 if fraction > float(i) / 15.0 else 0.0
		for side_index in _driver_arms.size():
			var side := -1.0 if side_index == 0 else 1.0
			var hand := _steering_wheel.transform * Vector3(side * 0.16,0,0)
			var elbow := Vector3(side * 0.23,0.72,-0.26)
			var arm := _driver_arms[side_index]
			arm.position = (hand + elbow) * 0.5
			arm.scale.y = hand.distance_to(elbow)
			arm.quaternion = Quaternion(Vector3.UP,(hand - elbow).normalized())

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
	for node: Node3D in _view_occluders:
		# Only the driver's head is hidden at the eye point; wheel, arms and halo remain.
		node.visible = mode != 2 if node.name in ["Helmet", "HelmetVisor"] else true
	for viewport in _mirrors:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if mode in [1,2] else SubViewport.UPDATE_DISABLED

func _set_render_layer(node: Node, value: int) -> void:
	if node is GeometryInstance3D:
		node.layers = value
	for child in node.get_children():
		_set_render_layer(child, value)

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

func _wheel_detail() -> void:
	var car := get_parent() as RaycastFormulaCar
	if car == null or ghost_mode:
		return
	var rubber := _material(Color("121519"),0.88,0.0)
	var suit := _material(Color("dae2e7"),0.92,0.0)
	for side in [-1.0,1.0]:
		_sphere("SculptedGrip",Vector3(0.037,0.096,0.045),Vector3(side * 0.16,0,0),rubber,_steering_wheel)
		_box("ShiftPaddle",Vector3(0.065,0.13,0.012),Vector3(side * 0.114,-0.003,-0.044),_carbon,_steering_wheel)
		_box("ClutchPaddle",Vector3(0.085,0.036,0.012),Vector3(side * 0.09,-0.085,-0.034),_carbon,_steering_wheel)
		var glove := _sphere("GlovedPalm",Vector3(0.042,0.065,0.032),Vector3(side * 0.167,0.003,0.024),suit,_steering_wheel)
		for finger in 4:
			_sphere("GloveFinger",Vector3(0.032,0.011,0.024),Vector3(side * 0.159,0.033 - finger * 0.019,0.043),suit,_steering_wheel)
			_box("FingerSeam",Vector3(0.022,0.002,0.003),Vector3(side * 0.163,0.033 - finger * 0.019,0.067),_carbon,_steering_wheel)
		_sphere("Thumb",Vector3(0.027,0.018,0.025),Vector3(side * 0.13,0.049,0.039),suit,_steering_wheel)
		glove.rotation.z = side * 0.13
		var arm := _cylinder(0.048,1.0,suit)
		arm.name = "ArticulatedSleeve"
		_driver_arms.append(arm)
		_view_occluders.append(arm)
		_sphere("Shoulder",Vector3(0.11,0.09,0.13),Vector3(side * 0.14,0.75,-0.15),suit)
		for i in 3:
			var dial := _cylinder(0.013,0.012,_material([Color("da3c46"),Color("448cd5"),Color("e9cc5c")][i],0.35,0.3),_steering_wheel)
			dial.position = Vector3(side * (0.09 - i * 0.03),-0.054,0.041)
			dial.rotation.x = PI / 2
			_box("DialIndex",Vector3(0.002,0.009,0.003),dial.position + Vector3(0,0.004,0.008),_accent,_steering_wheel)
	for i in 15:
		var color := Color("63ed88") if i < 7 else (Color("f2d64e") if i < 11 else Color("778aff"))
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color * 0.3
		mat.emission_enabled = true
		mat.emission = color
		var led := _box("ShiftLED",Vector3(0.008,0.008,0.005),Vector3(-0.084 + i * 0.012,0.074,0.034),mat,_steering_wheel)
		_leds.append(led)
		_view_occluders.append(led)
	if not car.player_controlled or DisplayServer.get_name() == "headless":
		return
	_wheel_viewport = SubViewport.new()
	_wheel_viewport.name = "SharedWheelDisplay"
	_wheel_viewport.size = Vector2i(512,256)
	_wheel_viewport.disable_3d = true
	_wheel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_wheel_viewport)
	var display := preload("res://ui/wheel_screen.gd").new()
	display.car = car
	display.size = Vector2(512,256)
	_wheel_viewport.add_child(display)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _wheel_viewport.get_texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var screen := QuadMesh.new()
	screen.size = Vector2(0.162,0.081)
	_instance("LiveOLED",screen,mat,_steering_wheel).position = Vector3(0,0.013,0.039)

func _build_mirrors() -> void:
	var car := get_parent() as RaycastFormulaCar
	if car == null or not car.player_controlled or ghost_mode or DisplayServer.get_name() == "headless":
		return
	for side in [-1.0,1.0]:
		var viewport := SubViewport.new()
		viewport.name = "RearMirrorLeft" if side < 0 else "RearMirrorRight"
		viewport.size = Vector2i(384,192)
		viewport.world_3d = get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		add_child(viewport)
		_mirrors.append(viewport)
		var camera := Camera3D.new()
		camera.fov = 60
		camera.near = 0.1
		camera.far = 700
		camera.cull_mask = 1 # Exclude the player's own car and mirror surfaces.
		viewport.add_child(camera)
		camera.position = Vector3(side * 0.72,0.86,-0.80)
		camera.basis = Basis.looking_at(Vector3(side * 0.15,-0.035,1).normalized())
		camera.set_meta("mount_pose", camera.transform)
		camera.current = true
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = viewport.get_texture()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.uv1_scale.x = -1
		mat.uv1_offset.x = 1
		var surface := QuadMesh.new()
		surface.size = Vector2(0.244,0.088)
		var mirror := _instance("RearViewGlass",surface,mat)
		mirror.position = Vector3(side * 0.68,0.802,-0.834)
		mirror.rotation.y = side * 0.10
