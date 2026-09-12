class_name RaycastFormulaCar
extends RigidBody3D
## Four-ray suspension with the prototype's combined-slip bicycle tyre model.
## +X right, -Z forward. Positive input turns RIGHT (negative Godot yaw).

const FormulaVisual = preload("res://cars/formula_visual.gd")
const EngineSound = preload("res://cars/formula_engine_audio.gd")
const GRAVITY := 9.81
@export var tuning: CarTuning = preload("res://physics/default_car_tuning.tres")
@export var player_controlled := false
@export var driver_name := "Driver"
@export var livery_color := Color("#f32b4f")
@export var art_root: Node3D
@export var visual_scene: PackedScene
@export var wheel_visual_paths: Array[NodePath] = []

var automated_input := false
var throttle_input := 0.0
var brake_input := 0.0
var handbrake_input := 0.0
var steering_input := 0.0
var steering_angle := 0.0
var gear := 1
var rpm := 5000.0
var speed_mps := 0.0
var forward_speed := 0.0
var longitudinal_g := 0.0
var lateral_g := 0.0
var tyre_smoke_strength := 0.0
var wheelspin := 0.0
var brake_lock := 0.0
var front_slip := 0.0
var rear_slip := 0.0
var slip_angle := 0.0
var spin_amount := 0.0
var launch_efficiency := 1.0
var damage := 0.0
var reverse_engaged := false
var drs_open := false
var drs_available := false
var current_surface := "asphalt"
var track: Node
var race_enabled := false
var ai_command := {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drs": false, "handbrake": false}
var race_progress := 0.0
var lap := 0
var completed_lap_time := 0.0
var penalty_seconds := 0.0
var finished := false
var surface_names: Dictionary = {}
var surface_grips: Dictionary = {}
var tire_loads: Dictionary = {}
var tire_risk: Dictionary = {}
var grounded_wheels := 0

var _wheels: Array[Dictionary] = []
var _shift_cut := 0.0
var _shift_cooldown := 0.0
var _reverse_hold := 0.0
var _physics_time := 0.0
var _camera_mode := 0
var _camera_initialized := false
var _chase_camera: Camera3D
var _chase_arm: SpringArm3D
var _t_camera: Camera3D
var _cockpit_camera: Camera3D
var _generated_visual: Node3D
var _audio: Node
var _pending_pose := false
var _reset_transform := Transform3D.IDENTITY
var _reset_velocity := Vector3.ZERO
var _contact_cooldown := 0.0
var _previous_velocity := Vector3.ZERO
var _acceleration_initialized := false
var _load_transfer_g := 0.0
var _mouse_active := true
var _look_target := Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not player_controlled:
		return
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.2):
		_mouse_active = false
		_look_target = Vector2.ZERO
	elif event is InputEventKey:
		_mouse_active = true
	elif event is InputEventMouseMotion and event.relative.length_squared() > 0.01:
		_mouse_active = true
		if _camera_mode == 2 and not GameState.paused and GameState.mode != GameState.Mode.MENU:
			var bounds := get_viewport().get_visible_rect().size
			_look_target = (event.position / bounds * 2.0 - Vector2.ONE).clamp(Vector2(-1,-1),Vector2.ONE)


func _ready() -> void:
	tuning = tuning.duplicate()
	mass = tuning.mass_kg
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = tuning.center_of_mass
	inertia = Vector3(830.0, tuning.yaw_inertia, 340.0)
	linear_damp = 0.0
	angular_damp = 0.0
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	can_sleep = false
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 8
	var contact_material := PhysicsMaterial.new()
	contact_material.friction = 0.22
	contact_material.bounce = 0.08
	physics_material_override = contact_material
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.80, 0.40, 4.45)
	collider.shape = shape
	collider.position = Vector3(0.0, 0.35, 0.0)
	add_child(collider)
	_create_wheels()
	if visual_scene != null and art_root == null:
		art_root = visual_scene.instantiate() as Node3D
		add_child(art_root)
	if art_root == null:
		_generated_visual = FormulaVisual.new()
		_generated_visual.name = "FormulaBody"
		_generated_visual.configure(livery_color, tuning, _wheels)
		add_child(_generated_visual)
	else:
		_bind_imported_wheels()
	_create_cameras()
	_audio = EngineSound.new()
	_audio.car = self
	add_child(_audio)
	body_entered.connect(_on_body_entered)

func _bind_imported_wheels() -> void:
	# The art wrapper uses +X right, -Z forward, metres, and centred wheel nodes.
	for index in _wheels.size():
		var wheel := _wheels[index]
		var path := wheel_visual_paths[index] if index < wheel_visual_paths.size() else NodePath("Wheels/" + String(wheel.name))
		var imported := art_root.get_node_or_null(path) as Node3D
		if imported == null:
			push_warning("Car art is missing wheel pivot: " + String(path))
			continue
		var pivot := Node3D.new()
		pivot.name = String(wheel.name) + "_SteerPivot"
		pivot.position = Vector3(wheel.local_position.x, 0.34, wheel.local_position.z)
		add_child(pivot)
		var axle := Node3D.new()
		axle.name = "AxleRoll"
		pivot.add_child(axle)
		imported.reparent(axle, true)
		wheel.visual = pivot
		wheel.roll_node = axle

func _create_wheels() -> void:
	var rear_z := tuning.wheelbase - tuning.cg_to_front
	for layout in [["FL", Vector3(-0.95, 0.59, -tuning.cg_to_front), true],
		["FR", Vector3(0.95, 0.59, -tuning.cg_to_front), true],
		["RL", Vector3(-0.95, 0.59, rear_z), false], ["RR", Vector3(0.95, 0.59, rear_z), false]]:
		var ray := RayCast3D.new()
		ray.name = "%s_Contact" % layout[0]
		ray.position = layout[1]
		ray.target_position = Vector3.DOWN * (tuning.suspension_rest_length + tuning.wheel_radius + 0.13)
		ray.collision_mask = 1
		ray.exclude_parent = true
		ray.enabled = true
		add_child(ray)
		_wheels.append({"name": layout[0], "local_position": layout[1], "front": layout[2],
			"ray": ray, "omega": 0.0, "roll": 0.0, "compression": 0.0, "normal_force": 0.0,
			"surface": "asphalt", "grip": 1.0, "rolling": 0.014, "contact": Vector3.ZERO,
			"grounded": false, "slip_ratio": 0.0, "slip_angle": 0.0, "risk": 0.0,
			"visual": null, "roll_node": null, "dust": null})

func _physics_process(delta: float) -> void:
	_physics_time += delta
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	if player_controlled and Input.is_action_just_pressed("camera_toggle"):
		_set_camera_mode((_camera_mode + 1) % 3)
	if player_controlled and not automated_input:
		_update_inputs(delta, Input.get_action_strength("throttle"), Input.get_action_strength("brake"),
			Input.get_axis("steer_left", "steer_right"), Input.is_action_pressed("drs"),
			Input.is_action_pressed("handbrake") if InputMap.has_action("handbrake") else false)
		if Input.is_action_just_pressed("shift_up"):
			_shift(1)
		if Input.is_action_just_pressed("shift_down"):
			_shift(-1)
	else:
		_update_inputs(delta, float(ai_command.get("throttle", 0.0)), float(ai_command.get("brake", 0.0)),
			float(ai_command.get("steer", 0.0)), bool(ai_command.get("drs", false)), bool(ai_command.get("handbrake", false)))
	_update_wheel_visuals(delta)

func _process(delta: float) -> void:
	_update_camera(delta)

func _update_inputs(delta: float, throttle: float, brake: float, steer: float, drs: bool, handbrake: bool) -> void:
	steer = clampf(steer, -1.0, 1.0)
	var rate := tuning.steering_input_fall if absf(steer) < 0.01 else tuning.steering_input_rise
	steering_input = move_toward(steering_input, steer, rate * delta)
	throttle_input = move_toward(throttle_input, clampf(throttle, 0.0, 1.0) if brake < 0.05 else 0.0, 11.0 * delta)
	brake_input = move_toward(brake_input, clampf(brake, 0.0, 1.0), 12.0 * delta)
	handbrake_input = move_toward(handbrake_input, 1.0 if handbrake else 0.0, 14.0 * delta)
	steering_angle = move_toward(steering_angle, steering_input * get_max_steering_angle(speed_mps) * (1.0 - handbrake_input * 0.36), tuning.steering_response * delta)
	var was_open := drs_open
	drs_open = drs and drs_available and race_enabled and brake_input < 0.02 and handbrake_input < 0.02 and not reverse_engaged
	if drs_open != was_open:
		EventBus.drs_changed.emit(self, drs_open)
	if throttle > 0.02 or brake < 0.1:
		_reverse_hold = 0.0
		reverse_engaged = false
	elif speed_mps < 0.65 and not (GameState.mode == GameState.Mode.RACE and GameState.start_state != GameState.StartState.GREEN):
		_reverse_hold += delta
		if _reverse_hold > 0.6:
			reverse_engaged = true

func get_max_steering_angle(speed: float) -> float:
	if speed < 3.0:
		return tuning.max_steer_low_speed
	var front_grip := (float(surface_grips.get("FL", 1.0)) + float(surface_grips.get("FR", 1.0))) * 0.5
	var aero_load := 0.5 * tuning.air_density * tuning.lift_cl_area * speed * speed
	var available := tuning.tyre_mu * front_grip * GRAVITY * (1.0 + aero_load / (mass * GRAVITY))
	var target := minf(tuning.steering_target_accel, available * 0.91)
	return clampf(atan(tuning.wheelbase * target / maxf(speed * speed, 1.0)), tuning.max_steer_high_speed, tuning.max_steer_low_speed)

func max_steer_for_speed(speed: float) -> float:
	return get_max_steering_angle(speed)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_pose:
		state.transform = _reset_transform
		state.linear_velocity = _reset_velocity
		state.angular_velocity = Vector3.ZERO
		_pending_pose = false
	var delta := state.step
	var body_basis := state.transform.basis.orthonormalized()
	var forward := -body_basis.z
	var right := body_basis.x
	var up := body_basis.y
	var velocity := state.linear_velocity
	speed_mps = Vector2(velocity.x, velocity.z).length()
	forward_speed = velocity.dot(forward)
	if _acceleration_initialized:
		var acceleration := (velocity - _previous_velocity) / maxf(delta, 0.0001)
		var blend := 1.0 - exp(-18.0 * delta)
		longitudinal_g = lerpf(longitudinal_g, acceleration.dot(forward) / GRAVITY, blend)
		lateral_g = lerpf(lateral_g, acceleration.dot(right) / GRAVITY, blend)
	_previous_velocity = velocity
	_acceleration_initialized = true
	var lateral_speed := velocity.dot(right)
	var yaw_rate := -state.angular_velocity.dot(up)
	_shift_cut = maxf(0.0, _shift_cut - delta)
	_shift_cooldown = maxf(0.0, _shift_cooldown - delta)
	var aero := 0.5 * tuning.air_density * tuning.lift_cl_area * speed_mps * speed_mps
	var front_aero := aero * tuning.front_aero_balance
	var rear_aero := aero * (1.0 - tuning.front_aero_balance) * (tuning.drs_rear_downforce_multiplier if drs_open else 1.0)
	# Aero is applied ONCE; tyre loads distribute this same load.
	state.apply_central_force(-up * (front_aero + rear_aero))
	_sample_suspension(state)
	_update_powertrain(delta)
	if grounded_wheels == 0:
		return
	var front_distance := tuning.cg_to_front
	var rear_distance := tuning.wheelbase - front_distance
	var static_front := mass * GRAVITY * rear_distance / tuning.wheelbase
	var static_rear := mass * GRAVITY - static_front
	var transfer := mass * _load_transfer_g * GRAVITY * tuning.center_of_mass.y / tuning.wheelbase
	var front_load := maxf(800.0, static_front + front_aero - transfer)
	var rear_load := maxf(800.0, static_rear + rear_aero + transfer)
	var front_grip := (float(surface_grips.get("FL", 1.0)) + float(surface_grips.get("FR", 1.0))) * 0.5
	var rear_grip := (float(surface_grips.get("RL", 1.0)) + float(surface_grips.get("RR", 1.0))) * 0.5
	var damage_grip := maxf(0.48, 1.0 - damage * 0.38)
	var front_limit := tuning.tyre_mu * front_grip * front_load * damage_grip * _axle_contact_fraction(true)
	var rear_limit := tuning.tyre_mu * rear_grip * rear_load * damage_grip * (1.0 - handbrake_input * 0.58) * _axle_contact_fraction(false)
	var velocity_floor := maxf(2.0, absf(forward_speed))
	var motion_sign := -1.0 if forward_speed < -0.1 else 1.0
	var front_alpha := atan2(lateral_speed + yaw_rate * front_distance, velocity_floor) - steering_angle * motion_sign
	var rear_alpha := atan2(lateral_speed - yaw_rate * rear_distance, velocity_floor)
	var low_speed := clampf(absf(forward_speed) / 4.0, 0.0, 1.0)
	var front_lateral := -tuning.front_cornering_stiffness * pow(front_load / static_front, tuning.load_sensitivity) * front_alpha * low_speed
	var rear_lateral := -tuning.rear_cornering_stiffness * pow(rear_load / static_rear, tuning.load_sensitivity) * rear_alpha * low_speed
	var ratio := tuning.gear_ratios[maxi(gear - 1, 0)] * tuning.final_drive
	var geared_force := tuning.torque_at_rpm(rpm) * ratio * 0.97 / tuning.wheel_radius
	var engine_force := minf(tuning.max_drive_force, minf(geared_force, tuning.peak_power_watts / maxf(7.0, absf(forward_speed))))
	engine_force *= launch_efficiency * maxf(0.30, 1.0 - damage * 0.58)
	if _shift_cut > 0.0 or rpm >= tuning.rev_limit_rpm - 20.0 or speed_mps > tuning.max_speed_mps:
		engine_force = 0.0
	var drive_input := brake_input if reverse_engaged else throttle_input
	var drive_force := engine_force * drive_input * (-0.55 if reverse_engaged else 1.0)
	if not race_enabled or (reverse_engaged and forward_speed < -tuning.reverse_speed_mps):
		drive_force = 0.0
	if tuning.traction_control:
		drive_force = clampf(drive_force, -rear_limit * 0.82, rear_limit * 0.82)
	var braking := brake_input if not reverse_engaged and race_enabled else 0.0
	if not race_enabled:
		braking = 1.0
	var brake_force := tuning.max_brake_force * braking
	if tuning.abs_enabled:
		brake_force = minf(brake_force, (front_limit + rear_limit) * 0.92)
	brake_force = minf(brake_force, absf(forward_speed) * mass / maxf(delta, 0.001))
	var front_longitudinal := -motion_sign * brake_force * tuning.brake_front_bias
	var rear_longitudinal := drive_force - motion_sign * brake_force * (1.0 - tuning.brake_front_bias)
	rear_longitudinal -= motion_sign * minf(tuning.handbrake_force * handbrake_input, absf(forward_speed) * mass / maxf(delta, 0.001))
	var front_force := _combined_force(front_longitudinal, front_lateral, front_limit)
	var rear_force := _combined_force(rear_longitudinal, rear_lateral, rear_limit)
	var rolling := 0.0
	for wheel in _wheels:
		rolling += float(wheel.rolling) * 0.25
	var rolling_force := -tanh(forward_speed / 1.5) * rolling * mass * GRAVITY
	var drag := 0.5 * tuning.air_density * tuning.drag_cd_area * speed_mps * speed_mps
	drag *= (tuning.drs_drag_multiplier if drs_open else 1.0) * (1.0 + damage * 0.42)
	var longitudinal_force := front_force.x + rear_force.x + rolling_force
	if speed_mps > 0.05:
		longitudinal_force -= motion_sign * drag
	var lateral_force := front_force.y + rear_force.y
	var left_grip := (float(surface_grips.get("FL", 1.0)) + float(surface_grips.get("RL", 1.0))) * 0.5
	var right_grip := (float(surface_grips.get("FR", 1.0)) + float(surface_grips.get("RR", 1.0))) * 0.5
	var split_grip := right_grip - left_grip
	lateral_force += split_grip * mass * GRAVITY * 0.16
	var yaw_moment := front_distance * front_force.y - rear_distance * rear_force.y
	yaw_moment += split_grip * (absf(longitudinal_force) * tuning.front_track * 0.34 + absf(lateral_force) * tuning.wheelbase * 0.08)
	yaw_moment -= yaw_rate * (270.0 + speed_mps * 8.0)
	state.apply_central_force(forward * longitudinal_force + right * lateral_force)
	state.apply_torque(-up * yaw_moment)
	var roll_pitch_velocity := state.angular_velocity - up * state.angular_velocity.dot(up)
	state.apply_torque(-roll_pitch_velocity * 1000.0)
	if speed_mps < 1.0 and absf(drive_force) < 1.0:
		var damping := maxf(0.0, 1.0 - delta * 7.0)
		state.linear_velocity.x *= damping
		state.linear_velocity.z *= damping
		state.angular_velocity.y *= damping
	_load_transfer_g = lerpf(_load_transfer_g, longitudinal_force / (mass * GRAVITY), 1.0 - exp(-10.0 * delta))
	slip_angle = atan2(lateral_speed, maxf(1.5, absf(forward_speed)))
	front_slip = clampf(absf(front_alpha) / 0.20, 0.0, 1.6)
	rear_slip = clampf(absf(rear_alpha) / 0.22, 0.0, 1.6)
	wheelspin = clampf((absf(rear_longitudinal) / maxf(1.0, rear_limit) - 0.72) / 0.72, 0.0, 1.4)
	brake_lock = clampf((brake_force / maxf(1.0, front_limit + rear_limit) - 0.60) / 0.65, 0.0, 1.0)
	spin_amount = clampf(maxf(0.0, absf(slip_angle) - 0.16) / 0.62 * 0.62 + maxf(0.0, absf(yaw_rate) - 0.85) / 2.2 * 0.55 + maxf(0.0, rear_slip - front_slip * 0.72 - 0.28) * 0.42, 0.0, 1.0)
	tyre_smoke_strength = maxf(maxf(front_slip, rear_slip) * 0.65, maxf(wheelspin, brake_lock)) if speed_mps > 5.0 else 0.0
	_update_wheel_telemetry(state, delta, front_load, rear_load, front_alpha, rear_alpha, front_longitudinal, rear_longitudinal, front_lateral, rear_lateral, front_limit, rear_limit)
	launch_efficiency = move_toward(launch_efficiency, 1.0, delta * 0.095)

static func _combined_force(longitudinal: float, lateral: float, limit: float) -> Vector2:
	var demand := Vector2(longitudinal, lateral)
	var magnitude := demand.length()
	if magnitude < 0.00001 or limit < 1.0:
		return Vector2.ZERO
	var ratio := magnitude / limit
	return demand * tanh(ratio) / ratio

func _sample_suspension(state: PhysicsDirectBodyState3D) -> void:
	grounded_wheels = 0
	var counts: Dictionary = {}
	var up := state.transform.basis.y.normalized()
	for wheel in _wheels:
		var ray: RayCast3D = wheel.ray
		ray.force_raycast_update()
		wheel.grounded = ray.is_colliding()
		if not wheel.grounded:
			wheel.compression = 0.0
			wheel.normal_force = 0.0
			surface_grips[wheel.name] = 0.0
			continue
		grounded_wheels += 1
		var contact := ray.get_collision_point()
		var normal := ray.get_collision_normal().normalized()
		wheel.contact = contact
		var spring_length := ray.global_position.distance_to(contact) - tuning.wheel_radius
		var compression := clampf(tuning.suspension_rest_length - spring_length, -0.08, tuning.suspension_rest_length)
		var contact_offset := contact - state.transform.origin
		var contact_velocity := state.linear_velocity + state.angular_velocity.cross(contact_offset - state.center_of_mass)
		var vertical_speed := contact_velocity.dot(normal)
		var damping := tuning.damper_bump if vertical_speed < 0.0 else tuning.damper_rebound
		var suspension_force := clampf(tuning.spring_rate * maxf(compression, 0.0) - damping * vertical_speed, 0.0, 38000.0)
		wheel.compression = compression
		wheel.normal_force = suspension_force
		state.apply_force(normal * suspension_force, contact_offset)
		var surface := _surface_for_point(contact)
		var surface_name := String(surface.get("name", "asphalt"))
		wheel.surface = surface_name
		var phase := float(_wheels.find(wheel)) * 1.7 + 0.4
		var amplitude := 0.003 if surface_name == "asphalt" else (0.018 if surface_name == "kerb" else 0.045)
		var spatial := sin(contact.x * 0.031 + contact.z * 0.017 + phase) * 0.62 + sin(contact.x * 0.009 - contact.z * 0.043 + phase * 1.7) * 0.38
		wheel.grip = float(surface.get("grip", 1.0)) * (1.0 + spatial * amplitude)
		var resistance := 0.014
		if surface_name == "kerb":
			resistance = 0.024
		elif surface_name == "grass":
			resistance = 0.11
		elif surface_name == "sand" or surface_name == "gravel":
			resistance = 0.22
		wheel.rolling = float(surface.get("rolling_resistance", resistance))
		surface_names[wheel.name] = surface_name
		surface_grips[wheel.name] = wheel.grip
		counts[surface_name] = int(counts.get(surface_name, 0)) + 1
	var highest := 0
	var old_surface := current_surface
	for surface_name in counts:
		if int(counts[surface_name]) > highest:
			highest = int(counts[surface_name])
			current_surface = surface_name
	if current_surface != old_surface:
		EventBus.surface_changed.emit(self, current_surface)
	for first in [0, 2]:
		var left: Dictionary = _wheels[first]
		var right: Dictionary = _wheels[first + 1]
		if left.grounded and right.grounded:
			var anti_roll := (float(left.compression) - float(right.compression)) * tuning.anti_roll_stiffness
			state.apply_force(up * anti_roll, state.transform.basis * Vector3(left.local_position))
			state.apply_force(-up * anti_roll, state.transform.basis * Vector3(right.local_position))

func _axle_contact_fraction(front: bool) -> float:
	var contacts := 0
	for wheel in _wheels:
		if bool(wheel.front) == front and wheel.grounded:
			contacts += 1
	return contacts * 0.5

func _update_wheel_telemetry(state: PhysicsDirectBodyState3D, delta: float, front_load: float, rear_load: float, front_alpha: float, rear_alpha: float, front_long: float, rear_long: float, front_lat: float, rear_lat: float, front_limit: float, rear_limit: float) -> void:
	var lateral_transfer := mass * lateral_g * GRAVITY * tuning.center_of_mass.y / tuning.front_track
	var total_load := maxf(front_load + rear_load, 1.0)
	for wheel in _wheels:
		var is_front: bool = wheel.front
		var axle_load := front_load if is_front else rear_load
		var transfer := lateral_transfer * axle_load / total_load
		var wheel_load := maxf(0.0, axle_load * 0.5 + transfer * (0.5 if float(wheel.local_position.x) < 0.0 else -0.5))
		tire_loads[wheel.name] = wheel_load / total_load
		var alpha := front_alpha if is_front else rear_alpha
		var demand := Vector2(front_long, front_lat).length() / maxf(1.0, front_limit) if is_front else Vector2(rear_long, rear_lat).length() / maxf(1.0, rear_limit)
		var surface_penalty := clampf((1.0 - float(wheel.grip)) / 0.65, 0.0, 1.0)
		wheel.risk = clampf(demand * 0.43 + absf(alpha) * 1.5 + surface_penalty * 0.48 + (wheelspin * 0.30 if not is_front else 0.0) + brake_lock * 0.20, 0.0, 1.25)
		tire_risk[wheel.name] = wheel.risk
		var direction := -state.transform.basis.z.rotated(state.transform.basis.y, -steering_angle if is_front else 0.0)
		var offset := state.transform.basis * Vector3(wheel.local_position) - state.center_of_mass
		var wheel_speed := (state.linear_velocity + state.angular_velocity.cross(offset)).dot(direction)
		var slip := wheelspin * 0.27 * throttle_input if not is_front else 0.0
		slip -= brake_lock * 0.7 * brake_input
		if handbrake_input > 0.02 and not is_front:
			slip = lerpf(slip, -1.0, handbrake_input)
		wheel.slip_ratio = slip
		wheel.slip_angle = alpha
		# Implicit rolling constraint removes stiff explicit tyre-torque oscillation.
		var target_omega := wheel_speed * (1.0 + slip) / tuning.wheel_radius
		wheel.omega = lerpf(float(wheel.omega), target_omega, 1.0 - exp(-30.0 * delta))

func _update_powertrain(delta: float) -> void:
	var driven_omega := 0.0
	for wheel in _wheels:
		if not wheel.front:
			driven_omega += absf(float(wheel.omega)) * 0.5
	var ratio := tuning.gear_ratios[gear - 1] * tuning.final_drive
	var coupled_rpm := driven_omega * ratio * 60.0 / TAU
	var launch_rpm := lerpf(tuning.idle_rpm, 9700.0, throttle_input) if speed_mps < 8.0 else tuning.idle_rpm
	if reverse_engaged:
		launch_rpm = tuning.idle_rpm + absf(forward_speed) / tuning.reverse_speed_mps * 9000.0
	var target := clampf(maxf(launch_rpm, coupled_rpm), tuning.idle_rpm, tuning.rev_limit_rpm)
	rpm = lerpf(rpm, target, 1.0 - exp(-30.0 * delta))
	if (tuning.auto_shift or automated_input or not player_controlled) and _shift_cooldown <= 0.0 and not reverse_engaged:
		if coupled_rpm >= tuning.upshift_rpm and gear < tuning.gear_ratios.size():
			_shift(1)
		elif gear > 1:
			var lower_rpm := driven_omega * tuning.gear_ratios[gear - 2] * tuning.final_drive * 60.0 / TAU
			if lower_rpm < tuning.upshift_rpm * 0.77:
				_shift(-1)

func _shift(direction: int) -> void:
	if _shift_cut > 0.0 or reverse_engaged:
		return
	var target := clampi(gear + direction, 1, tuning.gear_ratios.size())
	if target == gear:
		return
	var wheel_rpm := absf(forward_speed) / tuning.wheel_radius * tuning.gear_ratios[target - 1] * tuning.final_drive * 60.0 / TAU
	if direction < 0 and wheel_rpm > tuning.rev_limit_rpm:
		return
	gear = target
	_shift_cut = tuning.shift_duration
	_shift_cooldown = 0.18

func _surface_for_point(point: Vector3) -> Dictionary:
	if track != null and track.has_method("get_surface_at"):
		return track.get_surface_at(point)
	return {"name": "asphalt", "grip": 1.0, "drag": 1.0, "legal": true}

func _update_wheel_visuals(delta: float) -> void:
	for wheel in _wheels:
		var visual: Node3D = wheel.visual
		if visual == null:
			continue
		visual.position.y = float(wheel.local_position.y) - tuning.suspension_rest_length + float(wheel.compression)
		visual.rotation.y = -steering_angle if wheel.front else 0.0
		wheel.roll = fposmod(float(wheel.roll) - float(wheel.omega) * delta, TAU)
		var roll_node: Node3D = wheel.roll_node
		if roll_node != null:
			roll_node.rotation.x = float(wheel.roll)
		var dust: CPUParticles3D = wheel.dust
		if dust != null:
			dust.emitting = wheel.grounded and speed_mps > 8.0 and (String(wheel.surface) in ["sand", "gravel", "grass"] or float(wheel.risk) > 1.05)
			dust.color = Color(0.69, 0.56, 0.37, 0.28) if String(wheel.surface) != "asphalt" else Color(0.80, 0.83, 0.86, 0.17)
	if _generated_visual != null:
		_generated_visual.update_controls(steering_input, drs_open, brake_input, _physics_time)
	elif art_root != null and art_root.has_method("update_controls"):
		art_root.update_controls(steering_input, drs_open, brake_input, _physics_time)

func _create_cameras() -> void:
	_t_camera = Camera3D.new()
	_t_camera.name = "TCamera"
	_t_camera.position = Vector3(0.0, 1.46, 0.19)
	_t_camera.rotation_degrees.x = -7.0
	_t_camera.fov = 74.0
	_t_camera.near = 0.05
	_t_camera.far = 10000.0
	add_child(_t_camera)
	_cockpit_camera = Camera3D.new()
	_cockpit_camera.name = "CockpitCamera"
	_cockpit_camera.position = Vector3(0.0, 1.02, -0.25)
	_cockpit_camera.rotation_degrees.x = -1.5
	_cockpit_camera.fov = 78.0
	_cockpit_camera.near = 0.035
	_cockpit_camera.far = 10000.0
	add_child(_cockpit_camera)
	_chase_camera = Camera3D.new()
	_chase_camera.name = "ChaseCamera"
	_chase_camera.fov = 66.0
	_chase_camera.near = 0.12
	_chase_camera.far = 10000.0
	_chase_arm = SpringArm3D.new()
	_chase_arm.name = "CollisionSafeChaseArm"
	_chase_arm.top_level = true
	_chase_arm.spring_length = 6.8
	_chase_arm.margin = 0.18
	_chase_arm.collision_mask = 1
	var camera_sweep := SphereShape3D.new()
	camera_sweep.radius = 0.18
	_chase_arm.shape = camera_sweep
	add_child(_chase_arm)
	_chase_arm.add_excluded_object(get_rid())
	_chase_arm.add_child(_chase_camera)
	_set_camera_mode(0)

func _set_camera_mode(mode: int) -> void:
	_camera_mode = mode
	if _generated_visual != null and player_controlled:
		_generated_visual.set_camera_view(mode)
	elif art_root != null and player_controlled and art_root.has_method("set_camera_view"):
		art_root.set_camera_view(mode)
	if _chase_camera == null:
		return
	_chase_camera.current = player_controlled and mode == 0
	_t_camera.current = player_controlled and mode == 1
	_cockpit_camera.current = player_controlled and mode == 2
	_camera_initialized = false

func set_camera_mode(mode: int) -> void:
	_set_camera_mode(clampi(mode, 0, 2))

func _update_camera(delta: float) -> void:
	if not player_controlled or _chase_camera == null:
		return
	var look := _look_target if _mouse_active and GameState.mouse_look and _camera_mode == 2 else Vector2.ZERO
	_cockpit_camera.rotation.y = lerp_angle(_cockpit_camera.rotation.y, -look.x * 0.85, 1.0 - exp(-8.0 * delta))
	_cockpit_camera.rotation.x = lerp_angle(_cockpit_camera.rotation.x, deg_to_rad(-1.5) - look.y * 0.38, 1.0 - exp(-8.0 * delta))
	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var anchor := global_position + Vector3.UP * 1.05
	var look_direction := (forward + global_basis.x * steering_input * 0.08 - Vector3.UP * 0.235).normalized()
	var camera_basis := Basis.looking_at(look_direction)
	if not _camera_initialized:
		_chase_arm.global_position = anchor
		_chase_arm.global_basis = camera_basis
		_camera_initialized = true
	else:
		_chase_arm.global_position = _chase_arm.global_position.lerp(anchor, 1.0 - exp(-18.0 * delta))
		_chase_arm.global_basis = _chase_arm.global_basis.slerp(camera_basis, 1.0 - exp(-9.0 * delta))
	_chase_camera.rotation.x = 0.08
	_chase_camera.fov = lerpf(_chase_camera.fov, 66.0 + clampf(speed_mps / 105.0, 0.0, 1.0) * 7.0, 1.0 - exp(-3.0 * delta))
	_t_camera.position.y = 1.46 + sin(_physics_time * 78.0) * minf(0.003, speed_mps * 0.000035)

func is_cockpit_camera() -> bool:
	return _camera_mode == 2

func get_camera_name() -> String:
	return ["CHASE", "T-CAM", "COCKPIT"][_camera_mode]

func activate_chase_camera() -> void:
	_set_camera_mode(0)

func all_wheels_legal() -> bool:
	if track == null:
		return true
	for wheel in _wheels:
		var ray: RayCast3D = wheel.ray
		if not track.is_legal(ray.global_position):
			return false
	return true

func all_wheels_off_track() -> bool:
	if track == null:
		return false
	for wheel in _wheels:
		var ray: RayCast3D = wheel.ray
		if track.is_legal(ray.global_position):
			return false
	return true

func reset_to_pose(pose: Transform3D, repair_damage: bool = false) -> void:
	_acceleration_initialized = false
	_load_transfer_g = 0.0
	ai_command = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drs": false}
	_reset_transform = pose
	_reset_velocity = Vector3.ZERO
	_pending_pose = true
	global_transform = pose
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	throttle_input = 0.0
	brake_input = 0.0
	handbrake_input = 0.0
	steering_input = 0.0
	steering_angle = 0.0
	gear = 1
	rpm = tuning.idle_rpm
	speed_mps = 0.0
	forward_speed = 0.0
	longitudinal_g = 0.0
	lateral_g = 0.0
	wheelspin = 0.0
	brake_lock = 0.0
	front_slip = 0.0
	rear_slip = 0.0
	slip_angle = 0.0
	spin_amount = 0.0
	_reverse_hold = 0.0
	reverse_engaged = false
	drs_open = false
	drs_available = false
	_shift_cut = 0.0
	_shift_cooldown = 0.0
	_camera_initialized = false
	for wheel in _wheels:
		wheel.omega = 0.0
		wheel.roll = 0.0
		wheel.compression = 0.0
		wheel.slip_ratio = 0.0
		wheel.slip_angle = 0.0
		wheel.normal_force = 0.0
		wheel.grounded = false
		if wheel.dust != null:
			wheel.dust.emitting = false
	if repair_damage:
		damage = 0.0
	finished = false

func set_flying_speed(speed: float) -> void:
	var velocity := -global_transform.basis.z * speed
	_acceleration_initialized = false
	linear_velocity = velocity
	_reset_velocity = velocity
	speed_mps = absf(speed)
	forward_speed = speed
	for wheel in _wheels:
		wheel.omega = speed / tuning.wheel_radius
	gear = 1
	while gear < tuning.gear_ratios.size() and absf(speed) / tuning.wheel_radius * tuning.gear_ratios[gear - 1] * tuning.final_drive * 60.0 / TAU > tuning.upshift_rpm:
		gear += 1
	rpm = clampf(absf(speed) / tuning.wheel_radius * tuning.gear_ratios[gear - 1] * tuning.final_drive * 60.0 / TAU, tuning.idle_rpm, tuning.rev_limit_rpm)

func get_telemetry() -> Dictionary:
	var wheels: Array[Dictionary] = []
	for wheel in _wheels:
		wheels.append({"name": wheel.name, "surface": wheel.surface, "grip": wheel.grip,
			"normal_force": wheel.normal_force, "load": tire_loads.get(wheel.name, 0.25),
			"slip_ratio": wheel.slip_ratio, "slip_angle": wheel.slip_angle, "risk": wheel.risk,
			"omega": wheel.omega, "grounded": wheel.grounded})
	return {"rpm": rpm, "gear": -1 if reverse_engaged else gear, "speed_mps": speed_mps,
		"throttle": throttle_input, "brake": brake_input, "steer": steering_input,
		"drs_open": drs_open, "drs_available": drs_available, "wheelspin": wheelspin,
		"brake_lock": brake_lock, "front_slip": front_slip, "rear_slip": rear_slip,
		"slip_angle": slip_angle, "spin_amount": spin_amount, "surface": current_surface,
		"longitudinal_g": longitudinal_g, "lateral_g": lateral_g, "wheels": wheels}

func _on_body_entered(body: Node) -> void:
	if not race_enabled or _contact_cooldown > 0.0:
		return
	var closing := 0.0
	if body is RaycastFormulaCar:
		closing = (linear_velocity - body.linear_velocity).length()
	elif body is StaticBody3D and body.has_meta("barrier"):
		closing = linear_velocity.length() * 0.45
	if closing > 4.0:
		damage = clampf(damage + closing * 0.007, 0.0, 1.0)
		_contact_cooldown = 0.35
		EventBus.incident.emit(self, body, clampf(closing / 26.0, 0.0, 1.0), "contact")
