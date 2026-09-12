extends Node3D
## Reproducible real physics tests: acceleration, signs, braking, grip, RPM/DRS/reset.

class SurfaceFixture:
	extends Node
	var surface := "asphalt"
	func get_surface_at(_point: Vector3) -> Dictionary:
		return {"name": surface, "grip": 0.58 if surface == "kerb" else 1.0}
	func is_legal(_point: Vector3) -> bool:
		return true

var car: RaycastFormulaCar
var fixture: SurfaceFixture
var elapsed := 0.0
var stage := -1
var failures: Array[String] = []
var results: Dictionary = {}
var zero_to_hundred := 0.0
var max_rpm := 0.0
var left_x := 0.0

func _ready() -> void:
	var ground := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20000.0, 0.5, 20000.0)
	collider.shape = shape
	collider.position.y = -0.25
	ground.add_child(collider)
	add_child(ground)
	fixture = SurfaceFixture.new()
	add_child(fixture)
	car = RaycastFormulaCar.new()
	car.track = fixture
	car.automated_input = true
	car.race_enabled = true
	add_child(car)
	_next_stage()

func _next_stage() -> void:
	stage += 1
	elapsed = 0.0
	fixture.surface = "asphalt"
	car.reset_to_pose(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)), true)
	car.ai_command = {"throttle": 0.0, "brake": 0.0, "steer": 0.0, "drs": false}
	car.race_enabled = true
	match stage:
		0:
			car.ai_command.throttle = 1.0
		1, 2:
			car.set_flying_speed(20.0)
			car.ai_command.throttle = 0.22
			car.ai_command.steer = -0.55 if stage == 1 else 0.55
		3:
			car.set_flying_speed(55.56)
			car.ai_command.brake = 1.0
		4, 5:
			car.set_flying_speed(70.0)
			car.ai_command.throttle = 0.25
			car.ai_command.steer = 0.95
			fixture.surface = "kerb" if stage == 5 else "asphalt"
		6, 7:
			car.set_flying_speed(80.0)
			car.ai_command.throttle = 1.0
			car.drs_available = true
			car.ai_command.drs = stage == 7
		8:
			_finish()

func _physics_process(delta: float) -> void:
	if stage >= 8:
		return
	elapsed += delta
	max_rpm = maxf(max_rpm, car.rpm)
	if not car.global_position.is_finite() or not car.linear_velocity.is_finite():
		failures.append("Non-finite vehicle state")
		_finish()
		return
	match stage:
		0:
			if zero_to_hundred == 0.0 and car.speed_mps * 3.6 >= 100.0:
				zero_to_hundred = elapsed
			if elapsed >= 8.0:
				results.acceleration = {"zero_to_100_s": zero_to_hundred, "speed_at_8_s_kmh": car.speed_mps * 3.6, "gear": car.gear, "rpm": car.rpm, "y": car.position.y}
				_check(zero_to_hundred > 1.0 and zero_to_hundred < 4.5, "0-100 must take 1.0-4.5 seconds")
				_check(car.speed_mps * 3.6 > 220.0, "8-second acceleration must exceed 220 km/h")
				_check(absf(car.position.x) < 3.0, "Straight acceleration must remain straight")
				_check(car.grounded_wheels == 4, "All four wheels must remain on flat ground")
				_next_stage()
		1, 2:
			if elapsed >= 2.0:
				results["left" if stage == 1 else "right"] = {"x": car.position.x, "z": car.position.z, "yaw": car.rotation.y, "speed": car.speed_mps}
				_check(car.position.x < -3.0 if stage == 1 else car.position.x > 3.0, "A/D steering world direction")
				if stage == 1:
					left_x = car.position.x
				else:
					_check(absf(absf(left_x) - car.position.x) < 2.0, "Left/right handling symmetry")
				_next_stage()
		3:
			if car.speed_mps < 1.0 and elapsed > 0.15:
				results.braking = {"from_200_kmh_s": elapsed, "distance_m": absf(car.position.z)}
				_check(elapsed < 4.0, "200km/h brake stop under4s")
				_next_stage()
			elif elapsed > 4.0:
				_check(false, "200 km/h brake stop failed")
				_next_stage()
		4, 5:
			if elapsed >= 2.0:
				results["kerb" if stage == 5 else "asphalt"] = {"slip": car.front_slip + car.rear_slip, "speed": car.speed_mps, "yaw": car.rotation.y, "x": car.position.x, "grip": car.surface_grips.FL}
				if stage == 5:
					_check(float(results.kerb.slip) > float(results.asphalt.slip) * 1.10, "Kerbs must cause meaningfully higher slip than asphalt")
				_next_stage()
		6, 7:
			if elapsed >= 4.0:
				results["drs_open" if stage == 7 else "drs_closed"] = car.speed_mps * 3.6
				results["drs_open_state" if stage == 7 else "drs_closed_state"] = {"rpm": car.rpm, "gear": car.gear, "throttle": car.throttle_input, "grounded": car.grounded_wheels, "y": car.position.y, "rotation": str(car.rotation), "g": car.longitudinal_g}
				if stage == 7:
					_check(float(results.drs_open) > float(results.drs_closed) + 2.0, "DRS drag reduction must increase speed")
					_check(car.drs_open, "DRS opens only when requested and eligible")
					car.ai_command.throttle = 0.0
					car.ai_command.brake = 1.0
					car._update_inputs(0.1, 0.0, 1.0, 0.0, true, false)
					_check(not car.drs_open, "Braking closes DRS")
					car.damage = 0.42
					car.reset_to_pose(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.04, 0.0)))
					_check(is_equal_approx(car.damage, 0.42), "Recovery must retain damage")
					for wheel in car._wheels:
						_check(float(wheel.omega) == 0.0, "Reset zeros wheel velocity")
				_next_stage()

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)

func _finish() -> void:
	print("VEHICLE_VALIDATION ", JSON.stringify({"results": results, "max_rpm": max_rpm, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)
