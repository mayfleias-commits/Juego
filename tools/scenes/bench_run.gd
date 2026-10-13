extends Node
## Ejecuta el modo benchmark desde la línea de comandos e imprime el resultado.
## xvfb-run godot --path . --rendering-driver opengl3 res://tools/scenes/bench_run.tscn -- --preset=bajo --seconds=10
func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	Settings.preset = args.get("preset", "medio")
	Settings._from_preset()
	if args.has("nolimit"):
		Settings.fps_limit = 0
	Settings.apply()
	var b := BenchMode.new()
	b.seconds = float(args.get("seconds", "10"))
	b.finished.connect(func(r):
		print(JSON.stringify(r))
		get_tree().quit())
	add_child(b)
