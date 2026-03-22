extends SceneTree

func _init() -> void:
	var source_path := "res://assets/placeholders/app_icon_purple.svg"
	var target_path := "res://assets/placeholders/app_icon_purple_hd.png"
	var image := Image.new()
	var error := image.load(source_path)
	if error != OK:
		push_error("Failed to load SVG: %s" % error)
		quit(1)
		return
	image.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
	error = image.save_png(target_path)
	if error != OK:
		push_error("Failed to save PNG: %s" % error)
		quit(1)
		return
	print(target_path)
	quit(0)
