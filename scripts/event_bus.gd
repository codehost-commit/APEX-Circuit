extends Node
## Intentionally centralised events keep gameplay systems independent.

signal lap_completed(car: Node, lap: int, lap_time: float, valid: bool)
signal sector_completed(car: Node, sector: int, sector_time: float)
signal incident(car_a: Node, car_b: Node, severity: float, detail: String)
signal penalty_applied(car: Node, seconds: float, reason: String)
signal drs_changed(car: Node, open: bool)
signal classification_changed(rows: Array)
signal race_message(title: String, detail: String, duration: float)
signal start_lights_changed(lights: int, green: bool)
signal surface_changed(car: Node, surface: String)
signal session_started(mode: int)
signal session_finished(rows: Array)
signal lap_invalidated(car: Node, reason: String)
signal player_reset(car: Node)
