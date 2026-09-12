class_name CarTuning
extends Resource
## All handling values for the custom raycast formula car.

@export_category("Mass and geometry")
@export var mass_kg := 795.0
@export var center_of_mass := Vector3(0.0, 0.24, 0.05)
@export var wheelbase := 3.35
@export var front_track := 1.62
@export var rear_track := 1.58
@export var wheel_radius := 0.33
@export var suspension_rest_length := 0.22

@export_category("Suspension")
@export var spring_rate := 122000.0
@export var damper_bump := 9200.0
@export var damper_rebound := 11800.0
@export var anti_roll_stiffness := 18500.0

@export_category("Tyres")
@export var tyre_mu := 1.62
@export_range(0.65, 1.0, 0.01) var load_sensitivity := 0.86
@export var longitudinal_peak_slip := 0.115
@export var lateral_peak_angle := 0.125
@export var post_peak_falloff := 0.22
@export var wheel_inertia := 1.15
@export var rolling_resistance := 0.014
@export var offroad_drag_force := 980.0

@export_category("Powertrain")
@export var idle_rpm := 3500.0
@export var rev_limit_rpm := 15000.0
@export var upshift_rpm := 14350.0
@export var shift_duration := 0.075
@export var peak_power_watts := 560000.0
@export var peak_torque_nm := 455.0
@export var final_drive := 3.10
@export var gear_ratios := PackedFloat32Array([3.05, 2.34, 1.88, 1.56, 1.33, 1.16, 1.03, 0.91])
@export var auto_shift := true

@export_category("Brakes and steering")
@export var max_brake_torque := 5100.0
@export_range(0.45, 0.75, 0.01) var brake_front_bias := 0.60
@export var max_steer_low_speed := 0.42
@export var max_steer_high_speed := 0.095
@export var steering_response := 4.8
@export var steering_input_rise := 4.2
@export var steering_input_fall := 6.0

@export_category("Aerodynamics")
@export var drag_cd_area := 1.05
@export var lift_cl_area := 3.95
@export_range(0.35, 0.65, 0.01) var front_aero_balance := 0.46
@export var air_density := 1.225
@export var drs_drag_multiplier := 0.78
@export var drs_rear_downforce_multiplier := 0.68

@export_category("Assists")
@export var traction_control := false
@export var abs_enabled := false
@export var stability_assist := 0.0

func torque_at_rpm(value: float) -> float:
	var normalized := clampf(value / rev_limit_rpm, 0.0, 1.08)
	var rise := clampf(normalized / 0.58, 0.0, 1.0)
	var fall := 1.0 - maxf(0.0, normalized - 0.78) * 0.55
	return peak_torque_nm * (0.58 + 0.42 * rise) * fall
