extends Node3D
## Runtime composition is deliberate: the slice stays text-only until final art arrives.

func _ready() -> void:
	Engine.max_fps = RaceConfig.target_fps
	get_viewport().set_embedding_subwindows(false)
	print("APEX Circuit booted: Forward+ project, Jolt configured, game systems loading.")
