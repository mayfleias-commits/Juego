extends Node
## Captura de pantalla y métricas de render de una ciudad simulada.
## Uso: xvfb-run godot --path . --rendering-driver opengl3 res://tools/scenes/capture.tscn -- --day=30 --preset=medio --out=shot.png

var world: World
var frames := 0
var args := {}
var sim: Simulation
var fps_samples: Array = []
var dc_max := 0
var tri_max := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	Settings.preset = args.get("preset", "medio")
	Settings._from_preset()
	Settings.fps_limit = 0
	Settings.apply()
	Engine.max_fps = 0
	sim = Simulation.new()
	sim.new_game(int(args.get("seed", "1001")))
	var bot := BotCompetent.new()
	bot.setup(sim, int(args.get("seed", "1001")))
	var day := int(args.get("day", "20"))
	var hour := int(args.get("hour", "12"))
	while sim.st["status"] == "playing" and (sim.day() < day or sim.hour() != hour):
		bot.act()
		sim.step()
	world = World.new()
	add_child(world)
	world.setup(sim)
	if args.has("overlay"):
		world.set_overlay(int(args["overlay"]))
	world.camera_rig._t_dist = float(args.get("dist", "80"))
	world.camera_rig.dist = world.camera_rig._t_dist
	world.camera_rig._t_yaw = float(args.get("yaw", "0.7"))
	world.camera_rig.yaw = world.camera_rig._t_yaw
	world.camera_rig._t_pitch = float(args.get("pitch", "0.85"))
	world.camera_rig.pitch = world.camera_rig._t_pitch
	print("ciudad: día ", sim.day(), " pob ", sim.total_pop(), " edificios ", sim.st["buildings"].size(), " temp ", sim.outdoor())

func _process(_d: float) -> void:
	frames += 1
	if frames > 10:
		fps_samples.append(Engine.get_frames_per_second())
		dc_max = maxi(dc_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		tri_max = maxi(tri_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	if frames == int(args.get("frames", "40")):
		var img := get_viewport().get_texture().get_image()
		var out: String = args.get("out", "res://shot.png")
		img.save_png(out)
		print("draw_calls ", dc_max, " triangulos ", tri_max, " objetos ", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		print("memoria_estatica_MB ", Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, " video_MB ", Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		print("gpu ", RenderingServer.get_video_adapter_name())
		get_tree().quit()
