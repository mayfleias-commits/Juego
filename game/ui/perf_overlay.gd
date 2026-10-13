class_name PerfOverlay
extends CanvasLayer
## Contador de FPS y memoria (F3 en PC; opción en el menú en celular).
var label: Label
var _acc := 0.0

func _ready() -> void:
	layer = 50
	label = Label.new()
	label.position = Vector2(8, 64)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.6))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	visible = Settings.show_fps

func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3:
		Settings.show_fps = not Settings.show_fps
		Settings.save_cfg()
		visible = Settings.show_fps

func _process(delta: float) -> void:
	visible = Settings.show_fps
	if not visible:
		return
	_acc += delta
	if _acc < 0.5:
		return
	_acc = 0.0
	var mem := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var vmem := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	label.text = "FPS %d  |  RAM %.0f MB  |  VRAM %.0f MB\nLlamadas %d  |  Triángulos %dk  |  %s" % [
		Engine.get_frames_per_second(), mem, vmem,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)) / 1000,
		Settings.PRESET_NAMES[Settings.preset]]
