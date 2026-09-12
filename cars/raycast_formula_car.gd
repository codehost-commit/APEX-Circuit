class_name RaycastFormulaCar
extends RigidBody3D
## Four independently raycast wheels, suspension forces, slip-based tyres and RWD powertrain.

@export var tuning: CarTuning = preload("res://physics/default_car_tuning.tres")
@export var player_controlled := false
@export var driver_name := "Driver"
@export var livery_color := Color("#e83945")
@export var art_root: Node3D
@export var wheel_visual_paths: Array[NodePath] = []

var throttle_input := 0.0
var brake_input := 0.0
var steering_input := 0.0
var steering_angle := 0.0
var gear := 1
var rpm := 3500.0
var speed_mps := 0.0
var longitudinal_g := 0.0
var lateral_g := 0.0
var tyre_smoke_strength := 0.0
var damage := 0.0
var drs_open := false
var drs_available := false
var current_surface := "asphalt"
var track: Node
var race_enabled := false
var ai_command := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drs": false}
var race_progress := 0.0
var lap := 0
var completed_lap_time := 0.0
var penalty_seconds := 0.0
var finished := false

var _wheels: Array[Dictionary] = []
var _shift_cut := 0.0
var _last_shift_up := false
var _last_shift_down := false
var _previous_velocity := Vector3.ZERO
var _chase_arm: SpringArm3D
var _chase_camera: Camera3D
var _cockpit_camera: Camera3D
var _cockpit_active := false
var _generated_visual: Node3D

func _ready() -> void:
	mass = tuning.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = tuning.center_of_mass
	linear_damp = 0.0
	angular_damp = 0.0
	contact_monitor = true
	max_contacts_reported = 8
	_add_body_collision()
	_create_wheels()
	_create_placeholder_visual_if_needed()
	_create_cameras()
	body_entered.connect(_on_body_entered)

func _add_body_collision() -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.45, 0.36, 3.7)
	collider.shape = shape
	collider.position = Vector3(0.0, 0.43, 0.02)
	add_child(collider)

func _create_wheels() -> void:
	var front_z := -tuning.wheelbase * 0.5
	var rear_z := tuning.wheelbase * 0.5
	var layouts := [
		{"name": "FL", "position": Vector3(-tuning.front_track * 0.5, 0.48, front_z), "front": true},
		{"name": "FR", "position": Vector3(tuning.front_track * 0.5, 0.48, front_z), "front": true},
		{"name": "RL", "position": Vector3(-tuning.rear_track * 0.5, 0.48, rear_z), "front": false},
		{"name": "RR", "position": Vector3(tuning.rear_track * 0.5, 0.48, rear_z), "front": false}
	]
	for layout in layouts:
		var ray := RayCast3D.new()
		ray.name = "%s_Ray" % layout.name
		ray.position = layout.position
		ray.target_position = Vector3(0.0, -(tuning.suspension_rest_length + tuning.wheel_radius + 0.18), 0.0)
		ray.enabled = true
		ray.exclude_parent = true
		ray.collision_mask = 1
		add_child(ray)
		_wheels.append({
			"name": layout.name, "local_position": layout.position, "front": layout.front,
			"ray": ray, "omega": 0.0, "compression": 0.0, "previous_compression": 0.0,
			"normal_force": 0.0, "surface": "asphalt", "visual": null
		})

func _create_placeholder_visual_if_needed() -> void:
	if art_root != null:
		return
	_generated_visual = Node3D.new()
	_generated_visual.name = "GeneratedFormulaPlaceholder"
	add_child(_generated_visual)
	_add_box("Monocoque", Vector3(0.82, 0.42, 2.35), Vector3(0.0, 0.53, 0.12), livery_color)
	_add_box("Nose", Vector3(0.38, 0.22, 1.55), Vector3(0.0, 0.40, -1.75), livery_color.lightened(0.08))
	_add_box("FrontWing", Vector3(1.82, 0.09, 0.34), Vector3(0.0, 0.25, -2.42), Color("#1a1e28"))
	_add_box("RearWing", Vector3(1.34, 0.46, 0.10), Vector3(0.0, 0.98, 1.63), Color("#161a22"))
	_add_box("Halo", Vector3(0.48, 0.30, 0.56), Vector3(0.0, 0.99, -0.14), Color("#141821"))
	for wheel in _wheels:
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "%s_PlaceholderWheel" % wheel.name
		var tyre := CylinderMesh.new()
		tyre.top_radius = tuning.wheel_radius
		tyre.bottom_radius = tuning.wheel_radius
		tyre.height = 0.25
		tyre.radial_segments = 20
		mesh_node.mesh = tyre
		mesh_node.position = wheel.local_position - Vector3(0.0, tuning.suspension_rest_length * 0.30, 0.0)
		mesh_node.rotation.z = PI * 0.5
		mesh_node.material_override = _material(Color("#101216"), 0.78, 0.08)
		_generated_visual.add_child(mesh_node)
		wheel.visual = mesh_node

func _add_box(label: String, size: Vector3, position_value: Vector3, color: Color) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = position_value
	mesh_node.material_override = _material(color, 0.32, 0.42)
	_generated_visual.add_child(mesh_node)

func _material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _create_cameras() -> void:
	_chase_arm = SpringArm3D.new()
	_chase_arm.name = "ChaseSpringArm"
	_chase_arm.position = Vector3(0.0, 1.45, 0.85)
	_chase_arm.rotation_degrees.x = -9.0
	_chase_arm.spring_length = 6.8
	_chase_arm.collision_mask = 1
	add_child(_chase_arm)
	_chase_camera = Camera3D.new()
	_chase_camera.name = "ChaseCamera"
	_chase_camera.position = Vector3(0.0, 0.0, 6.8)
	_chase_camera.fov = 69.0
	_chase_arm.add_child(_chase_camera)
	_cockpit_camera = Camera3D.new()
	_cockpit_camera.name = "CockpitCamera"
	_cockpit_camera.position = Vector3(0.0, 1.04, -0.40)
	_cockpit_camera.fov = 76.0
	add_child(_cockpit_camera)
	_set_camera_state(false)

func _physics_process(delta: float) -> void:
	if player_controlled and Input.is_action_just_pressed("camera_toggle"):
		_set_camera_state(not _cockpit_active)
	if player_controlled:
		_update_player_inputs(delta)
	else:
		_update_ai_inputs(delta)
	_update_camera(delta)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if not race_enabled:
		return
	var delta := state.step
	_shift_cut = maxf(0.0, _shift_cut - delta)
	var world_velocity := state.linear_velocity
	speed_mps = world_velocity.length()
	var total_downforce := 0.5 * tuning.air_density * tuning.lift_cl_area * speed_mps * speed_mps
	if drs_open:
		total_downforce *= tuning.front_aero_balance + (1.0 - tuning.front_aero_balance) * tuning.drs_rear_downforce_multiplier
	apply_central_force(Vector3.DOWN * total_downforce)
	if speed_mps > 0.1:
		var drag_multiplier := tuning.drs_drag_multiplier if drs_open else 1.0
		var drag := 0.5 * tuning.air_density * tuning.drag_cd_area * speed_mps * speed_mps * drag_multiplier
		apply_central_force(-world_velocity.normalized() * drag)
	var axle_compression := {"front": 0.0, "rear": 0.0}
	for wheel in _wheels:
		_update_wheel(wheel, state, delta, total_downforce, axle_compression)
	_apply_anti_roll(axle_compression)
	_update_powertrain(delta)
	longitudinal_g = (world_velocity - _previous_velocity).dot(-global_transform.basis.z) / maxf(delta * RaceConfig.gravity, 0.001)
	lateral_g = (world_velocity - _previous_velocity).dot(global_transform.basis.x) / maxf(delta * RaceConfig.gravity, 0.001)
	_previous_velocity = world_velocity
	tyre_smoke_strength = move_toward(tyre_smoke_strength, 0.0, delta * 2.5)

func _update_wheel(wheel: Dictionary, state: PhysicsDirectBodyState3D, delta: float, total_downforce: float, axle_compression: Dictionary) -> void:
	var ray: RayCast3D = wheel.ray
	ray.force_raycast_update()
	if not ray.is_colliding():
		wheel.normal_force = 0.0
		return
	var contact := ray.get_collision_point()
	var normal := ray.get_collision_normal().normalized()
	var hit_distance := ray.global_position.distance_to(contact) - tuning.wheel_radius
	var compression := clampf(tuning.suspension_rest_length - hit_distance, 0.0, tuning.suspension_rest_length)
	var compression_velocity := (compression - float(wheel.previous_compression)) / maxf(delta, 0.001)
	var damping := tuning.damper_bump if compression_velocity > 0.0 else tuning.damper_rebound
	var suspension_force := maxf(0.0, tuning.spring_rate * compression + damping * compression_velocity)
	wheel.previous_compression = compression
	wheel.compression = compression
	var relative_contact := contact - global_position
	apply_force(normal * suspension_force, relative_contact)
	var axle := "front" if wheel.front else "rear"
	axle_compression[axle] += compression * (-1.0 if float(wheel.local_position.x) < 0.0 else 1.0)
	var contact_velocity := state.linear_velocity + state.angular_velocity.cross(relative_contact)
	var steer := steering_angle if wheel.front else 0.0
	var wheel_forward := (-global_transform.basis.z).rotated(global_transform.basis.y, steer).normalized()
	var wheel_right := global_transform.basis.y.cross(wheel_forward).normalized()
	var forward_speed := contact_velocity.dot(wheel_forward)
	var lateral_speed := contact_velocity.dot(wheel_right)
	var surface := _surface_for_point(contact)
	wheel.surface = surface.name
	current_surface = surface.name
	var static_load := tuning.mass_kg * RaceConfig.gravity * 0.25
	var aero_load := total_downforce * (tuning.front_aero_balance if wheel.front else 1.0 - tuning.front_aero_balance) * 0.5
	var normal_force := maxf(0.0, suspension_force + aero_load)
	wheel.normal_force = normal_force
	var load_factor := pow(maxf(normal_force / maxf(static_load, 1.0), 0.12), tuning.load_sensitivity - 1.0)
	var grip_limit: float = tuning.tyre_mu * float(surface.grip) * normal_force * load_factor
	var slip_ratio := (float(wheel.omega) * tuning.wheel_radius - forward_speed) / maxf(absf(forward_speed), 4.0)
	var slip_angle := atan2(lateral_speed, maxf(absf(forward_speed), 3.0))
	var long_demand: float = _tyre_response(slip_ratio, tuning.longitudinal_peak_slip) * grip_limit
	var lat_demand: float = -_tyre_response(slip_angle, tuning.lateral_peak_angle) * grip_limit
	var brake_torque := brake_input * tuning.max_brake_torque * (tuning.brake_front_bias if wheel.front else 1.0 - tuning.brake_front_bias)
	if tuning.abs_enabled and absf(slip_ratio) > tuning.longitudinal_peak_slip:
		brake_torque *= 0.58
	var drive_torque := _drive_torque_for(wheel)
	var tyre_torque: float = -long_demand * tuning.wheel_radius
	var brake_direction := signf(float(wheel.omega)) if absf(float(wheel.omega)) > 0.1 else signf(forward_speed)
	wheel.omega += (drive_torque - brake_torque * brake_direction + tyre_torque) / tuning.wheel_inertia * delta
	var combined := Vector2(long_demand, lat_demand)
	if combined.length() > grip_limit:
		combined = combined.normalized() * grip_limit
	apply_force(wheel_forward * combined.x + wheel_right * combined.y, relative_contact)
	if absf(slip_ratio) > tuning.longitudinal_peak_slip * 1.4 or absf(slip_angle) > tuning.lateral_peak_angle * 1.55:
		tyre_smoke_strength = maxf(tyre_smoke_strength, clampf(absf(slip_ratio) + absf(slip_angle), 0.0, 1.0))
	_update_wheel_visual(wheel, compression, delta)

func _surface_for_point(point: Vector3) -> Dictionary:
	if track != null and track.has_method("get_surface_at"):
		return track.get_surface_at(point)
	return {"name": "asphalt", "grip": 1.0, "drag": 1.0, "legal": true}

func _tyre_response(slip: float, peak: float) -> float:
	var normalized := absf(slip) / maxf(peak, 0.001)
	var force := normalized if normalized <= 1.0 else maxf(0.48, 1.0 - (normalized - 1.0) * tuning.post_peak_falloff)
	return signf(slip) * force

func _apply_anti_roll(compression: Dictionary) -> void:
	var front_force := float(compression.front) * tuning.anti_roll_stiffness
	var rear_force := float(compression.rear) * tuning.anti_roll_stiffness
	apply_force(Vector3.UP * front_force, Vector3(0.0, 0.0, -tuning.wheelbase * 0.5))
	apply_force(Vector3.UP * rear_force, Vector3(0.0, 0.0, tuning.wheelbase * 0.5))

func _update_powertrain(delta: float) -> void:
	var driven_omega := 0.0
	for wheel in _wheels:
		if not wheel.front:
			driven_omega += absf(float(wheel.omega)) * 0.5
	var ratio := tuning.gear_ratios[gear - 1] * tuning.final_drive
	rpm = maxf(tuning.idle_rpm, driven_omega * ratio * 60.0 / TAU)
	if tuning.auto_shift and _shift_cut <= 0.0:
		if rpm > tuning.upshift_rpm and gear < tuning.gear_ratios.size():
			_shift(1)
		elif rpm < tuning.idle_rpm * 1.35 and gear > 1:
			_shift(-1)
	if rpm > tuning.rev_limit_rpm:
		rpm = tuning.rev_limit_rpm

func _drive_torque_for(wheel: Dictionary) -> float:
	if wheel.front or _shift_cut > 0.0:
		return 0.0
	var ratio := tuning.gear_ratios[gear - 1] * tuning.final_drive
	var torque := throttle_input * tuning.torque_at_rpm(rpm) * ratio * 0.5
	if tuning.traction_control and tyre_smoke_strength > 0.45:
		torque *= 0.58
	return torque

func _shift(direction: int) -> void:
	gear = clampi(gear + direction, 1, tuning.gear_ratios.size())
	_shift_cut = tuning.shift_duration

func _update_player_inputs(delta: float) -> void:
	var steer_target := Input.get_axis("steer_left", "steer_right")
	var throttle_target := Input.get_action_strength("throttle")
	var brake_target := Input.get_action_strength("brake")
	steering_input = move_toward(steering_input, steer_target, (tuning.steering_input_rise if absf(steer_target) > absf(steering_input) else tuning.steering_input_fall) * delta)
	throttle_input = move_toward(throttle_input, throttle_target, 4.5 * delta)
	brake_input = move_toward(brake_input, brake_target, 6.5 * delta)
	drs_open = Input.is_action_pressed("drs") and drs_available and race_enabled
	var shift_up := Input.is_action_pressed("shift_up")
	var shift_down := Input.is_action_pressed("shift_down")
	if shift_up and not _last_shift_up and _shift_cut <= 0.0:
		_shift(1)
	if shift_down and not _last_shift_down and _shift_cut <= 0.0:
		_shift(-1)
	_last_shift_up = shift_up
	_last_shift_down = shift_down
	_update_steering(delta)

func _update_ai_inputs(delta: float) -> void:
	steering_input = move_toward(steering_input, float(ai_command.steer), tuning.steering_input_rise * delta)
	throttle_input = move_toward(throttle_input, float(ai_command.throttle), 5.0 * delta)
	brake_input = move_toward(brake_input, float(ai_command.brake), 7.0 * delta)
	drs_open = bool(ai_command.drs) and drs_available and race_enabled
	_update_steering(delta)

func _update_steering(delta: float) -> void:
	var speed_factor := clampf(speed_mps / 88.0, 0.0, 1.0)
	var max_steer := lerpf(tuning.max_steer_low_speed, tuning.max_steer_high_speed, speed_factor)
	steering_angle = move_toward(steering_angle, steering_input * max_steer, tuning.steering_response * delta)

func _update_wheel_visual(wheel: Dictionary, compression: float, delta: float) -> void:
	var visual: Node3D = wheel.visual
	if visual == null:
		return
	visual.position.y = float(wheel.local_position.y) - compression
	visual.rotate_object_local(Vector3.RIGHT, float(wheel.omega) * delta)

func _update_camera(delta: float) -> void:
	if not player_controlled:
		return
	_chase_camera.fov = lerpf(_chase_camera.fov, 68.0 + clampf(speed_mps * 0.23, 0.0, 12.0), delta * 3.0)
	var shake := clampf((absf(lateral_g) + speed_mps / 45.0) * 0.012, 0.0, 0.06)
	_chase_camera.position.x = sin(Time.get_ticks_msec() * 0.022) * shake
	_cockpit_camera.rotation.z = lerpf(_cockpit_camera.rotation.z, -steering_input * 0.03, delta * 8.0)

func _set_camera_state(cockpit: bool) -> void:
	_cockpit_active = cockpit
	if _chase_camera != null:
		_chase_camera.current = player_controlled and not cockpit
	if _cockpit_camera != null:
		_cockpit_camera.current = player_controlled and cockpit

func is_cockpit_camera() -> bool:
	return _cockpit_active

func all_wheels_legal() -> bool:
	if track == null:
		return true
	for wheel in _wheels:
		var ray: RayCast3D = wheel.ray
		if not track.is_legal(ray.global_position):
			return false
	return true

func reset_to_pose(pose: Transform3D) -> void:
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	gear = 1
	rpm = tuning.idle_rpm
	damage = 0.0
	finished = false

func _on_body_entered(body: Node) -> void:
	if race_enabled and body is RaycastFormulaCar:
		var closing := maxf(0.0, (linear_velocity - body.linear_velocity).length())
		if closing > 5.0:
			damage = clampf(damage + closing * 0.003, 0.0, 1.0)
			EventBus.incident.emit(self, body, clampf(closing / 26.0, 0.0, 1.0), "contact")
