class_name BenchMode
extends Node
## Modo benchmark: recorrido de cámara sobre una ciudad grande en plena tormenta.
## Guarda los resultados en user://benchmark/<fecha>.json. Se usa también como
## mini benchmark de 5 s en el primer arranque.

signal finished(result: Dictionary)

var seconds := 20.0
var world: World
var frost: FrostLayer
var t := 0.0
var times: Array = []
var dc_max := 0
var tri_max := 0
var save_file := true
var mem_peak := 0.0
var _warm := 0

func _ready() -> void:
	var sim := DemoCity.build()
	world = World.new()
	add_child(world)
	world.setup(sim)
	frost = FrostLayer.new()
	add_child(frost)
	frost.set_cold(sim.outdoor(), true)
	world.camera_rig.input_enabled = false

## Si la app pasa a segundo plano (o se bloquea la ventana) la medición se reinicia:
## un cuadro de varios segundos arruinaría el promedio y, en el primer arranque,
## bajaría la calidad gráfica sin motivo.
func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED,
			NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		t = 0.0
		times.clear()
		dc_max = 0
		tri_max = 0
		_warm = 0

func _process(delta: float) -> void:
	_warm += 1
	if _warm < 5:
		return
	t += delta
	times.append(delta)
	dc_max = maxi(dc_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	tri_max = maxi(tri_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	mem_peak = maxf(mem_peak, SysMem.process_mb())
	var rig := world.camera_rig
	var k := t / seconds
	rig._t_yaw = k * TAU
	# Recorre todo el rango que permite la cámara del juego (zoom y ángulo), incluidos los extremos.
	rig._t_dist = lerpf(CameraRig.DIST_MIN, CameraRig.DIST_MAX, 0.5 + 0.5 * sin(k * TAU * 2.0))
	rig._t_pitch = lerpf(CameraRig.PITCH_MIN, CameraRig.PITCH_MAX, 0.5 + 0.5 * sin(k * TAU))
	rig._t_target = Vector3(sin(k * TAU) * 20.0, 0, cos(k * TAU) * 20.0)
	if t >= seconds:
		set_process(false)
		finished.emit(_report())

func _report() -> Dictionary:
	var sorted := times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0.0
	for x in sorted:
		total += x
	var avg_fps := n / maxf(0.001, total)
	var p99: float = sorted[int(n * 0.99)] if n > 0 else 0.0
	var worst: float = sorted[n - 1] if n > 0 else 0.0
	var mem: Dictionary = OS.get_memory_info()
	var win: Vector2i = get_window().size
	var scale3d: float = get_viewport().scaling_3d_scale
	var r := {
		"fecha": Time.get_datetime_string_from_system(),
		"preset": Settings.preset, "escala_render": Settings.render_scale,
		# Lo que de verdad rigió la medición (0 = sin límite), no lo que dice el ajuste.
		"limite_fps": Engine.max_fps, "limite_fps_ajuste": Settings.fps_limit,
		"vsync": _vsync_name(),
		"segundos": seconds, "cuadros": n,
		"fps_promedio": snappedf(avg_fps, 0.1), "fps_1pct_bajo": snappedf(1.0 / maxf(0.0001, p99), 0.1),
		"fps_minimo": snappedf(1.0 / maxf(0.0001, worst), 0.1),
		"draw_calls_max": dc_max, "triangulos_max": tri_max,
		"memoria_proceso_mb": snappedf(SysMem.process_mb(), 0.1),
		"memoria_pico_mb": snappedf(mem_peak, 0.1),
		"video_mb": snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"ram_sistema_mb": int(mem.get("physical", 0)) / 1048576,
		"gpu": RenderingServer.get_video_adapter_name(), "api": RenderingServer.get_video_adapter_api_version(),
		"so": OS.get_name(), "modelo": OS.get_model_name(), "nucleos_cpu": OS.get_processor_count(),
		"cpu": OS.get_processor_name(),
		# Tamaño real de la ventana (no el lógico de 1280x720) y la resolución 3D efectiva.
		"resolucion": "%dx%d" % [win.x, win.y],
		"resolucion_3d": "%dx%d" % [int(win.x * scale3d), int(win.y * scale3d)],
	}
	if save_file:
		DirAccess.make_dir_recursive_absolute("user://benchmark")
		var path := "user://benchmark/%s.json" % r["fecha"].replace(":", "-")
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(r, "  "))
			f.close()
		r["archivo"] = ProjectSettings.globalize_path(path)
	return r

func _vsync_name() -> String:
	match DisplayServer.window_get_vsync_mode():
		DisplayServer.VSYNC_DISABLED:
			return "desactivado"
		DisplayServer.VSYNC_ENABLED:
			return "activado"
		DisplayServer.VSYNC_ADAPTIVE:
			return "adaptativo"
		DisplayServer.VSYNC_MAILBOX:
			return "mailbox"
	return "?"
