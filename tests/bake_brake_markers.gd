extends SceneTree
## Rebuild the three marker face textures with Godot's font rasterizer.
## godot --path . --script tests/bake_brake_markers.gd (requires a renderer).
func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/trackside")
	for metres in [50,100,150]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768,410)
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var paper := ColorRect.new()
		paper.color = Color("f4f4ee")
		paper.size = Vector2(768,410)
		viewport.add_child(paper)
		var label := Label.new()
		label.text = str(metres)
		label.size = Vector2(768,410)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var number_font := SystemFont.new()
		number_font.font_names = PackedStringArray(["Arial Black", "DejaVu Sans"])
		number_font.font_weight = 900
		label.add_theme_font_override("font",number_font)
		label.add_theme_font_size_override("font_size",320)
		label.add_theme_color_override("font_color",Color("111416"))
		viewport.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		var result := viewport.get_texture().get_image().save_png("res://assets/trackside/brake_%d.png" % metres)
		if result != OK:
			quit(1)
			return
		viewport.queue_free()
	print("Baked brake marker faces")
	quit()
